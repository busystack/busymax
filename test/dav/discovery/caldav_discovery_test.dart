import 'dart:convert';

import 'package:busymax/src/dav/dav_errors.dart';
import 'package:busymax/src/dav/dav_provider_profile.dart';
import 'package:busymax/src/dav/discovery/dav_discovery_models.dart';
import 'package:busymax/src/dav/discovery/dav_discovery_repository.dart';
import 'package:busymax/src/dav/discovery/dav_discovery_service.dart';
import 'package:busymax/src/dav/http/dav_http_transport.dart';
import 'package:busymax/src/dav/storage/dav_collection_capabilities.dart';
import 'package:busymax/src/dav/storage/dav_settings_repository.dart';
import 'package:busymax/src/features/calendar/data/calendar_repository.dart';
import 'package:busymax/src/db/app_database.dart';
import 'package:busymax/src/providers/busy_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  for (final aclStatus in [404, 403]) {
    test(
      'optional ACL $aclStatus is unknown and survives persistence',
      () async {
        final result = await _discover(aclStatus: aclStatus);
        final c = result.collections.single;
        expect(c.eventProjectionEnabled && c.taskProjectionEnabled, isTrue);
        expect(c.capabilities.permissionsKnown, isFalse);
        expect(c.capabilities.canWriteContent, isFalse);
        expect(c.capabilities.canAttemptUpdateTask, isTrue);
        expect(c.supportedCalendarData, [
          {'contentType': 'text/calendar', 'version': '2.0'},
        ]);
        final db = AppDatabase.memoryForTests();
        addTearDown(db.close);
        await db
            .into(db.accounts)
            .insert(
              AccountsCompanion.insert(
                id: 'caldav',
                provider: 'caldav',
                authority: 'https://example.test/',
                providerAccountId: 'user',
                credentialKind: 'caldav_password',
                createdAtUtc: 'now',
                updatedAtUtc: 'now',
              ),
            );
        await DavDiscoveryRepository(database: db)
            .commitSuccessfulInventory(result);
        final stored = await db.select(db.davCollections).getSingle();
        final rehydrated = collectionCapabilitiesFromStored(stored);
        expect(rehydrated.permissionsKnown, isFalse);
        expect(rehydrated.canRead, isTrue);
        expect(rehydrated.canWriteContent, isFalse);
        expect(rehydrated.canAttemptUpdateEvent, isTrue);
        expect(rehydrated.canAttemptUpdateTask, isTrue);
        expect(rehydrated.canWriteProperties, isFalse);
        final settings = (await DavSettingsRepository(database: db)
            .collectionById(stored.id))!;
        expect(settings.canRemoveCollection, isFalse);
        expect(settings.collectionRemovalPermissionKnown, isFalse);
        expect(settings.taskCapabilities.supportsListRename, isTrue);
        expect(settings.taskCapabilities.supportsListDelete, isTrue);
        final source = await db.select(db.calendarSources).getSingle();
        final sourceCapabilities = CalendarSourceEntity.fromRow(
          source,
          davCollection: stored,
        ).capabilities;
        expect(sourceCapabilities.canRenameCalendar, isTrue);
        expect(sourceCapabilities.canDeleteCalendar, isTrue);
        expect(
          jsonDecode(stored.safeDisplayMetadataJson!)['privilegesKnown'],
          'false',
        );
      },
    );
  }
  test('a successful empty ACL is explicit denial', () async {
    final c = (await _discover(aclStatus: 200)).collections.single;
    expect(c.capabilities.permissionsKnown, isTrue);
    expect(c.capabilities.isReadOnly, isTrue);
    expect(c.capabilities.canAttemptCreateEvent, isFalse);
  });
  test(
    'an explicit endpoint works when well-known is not configured',
    () async {
      final requests = <http.Request>[];
      final r = await _discover(requests: requests);
      expect(requests.first.url.path, '/.well-known/caldav');
      expect(requests[1].url.path, '/');
      expect(r.service.principalHref.path, '/principal/user/');
      expect(r.collections.single.hrefKey, '/home/team%2Fwork/');
    },
  );
  test(
    'a supplied installation is verified before origin well-known',
    () async {
      final requests = <http.Request>[];
      await _discover(
        server: 'https://example.test/install/dav.php/',
        requests: requests,
      );
      expect(requests.first.url.path, '/install/dav.php/');
      expect(requests.any((r) => r.url.path == '/.well-known/caldav'), isFalse);
    },
  );
  test(
    'an HTML well-known response falls back to the explicit endpoint',
    () async {
      final requests = <http.Request>[];
      final result = await _discover(requests: requests, wellKnownStatus: 200);
      expect(requests.take(2).map((r) => r.url.path), [
        '/.well-known/caldav',
        '/',
      ]);
      expect(result.collections, hasLength(1));
    },
  );
  for (final status in [401, 429, 500]) {
    test('well-known $status is not hidden by direct fallback', () async {
      final requests = <http.Request>[];
      await expectLater(
        _discover(requests: requests, wellKnownStatus: status),
        throwsA(isA<DavException>()),
      );
      expect(
        requests.every((r) => r.url.path == '/.well-known/caldav'),
        isTrue,
      );
    });
  }
  for (final components in ['VEVENT', 'VTODO', 'VEVENT,VTODO', 'VJOURNAL']) {
    test('respects advertised $components restrictions', () async {
      final property =
          '<c:supported-calendar-component-set>${components.split(',').map((v) => '<c:comp name="$v"/>').join()}</c:supported-calendar-component-set>';
      final c = (await _discover(extra: property)).collections.single;
      expect(c.eventProjectionEnabled, components.contains('VEVENT'));
      expect(c.taskProjectionEnabled, components.contains('VTODO'));
    });
  }
  for (final malformed in [
    '<c:supported-calendar-component-set/>',
    '<c:supported-calendar-data><c:calendar-data content-type=""/></c:supported-calendar-data>',
    '<d:current-user-privilege-set><d:privilege/></d:current-user-privilege-set>',
  ]) {
    test('rejects malformed advertised capability $malformed', () async {
      await expectLater(
        _discover(extra: malformed),
        throwsA(isA<DavException>()),
      );
    });
  }
  test(
    'property-level component denial cannot become unrestricted default',
    () async {
      await expectLater(
        _discover(deniedComponents: true),
        throwsA(
          isA<DavException>().having(
            (e) => e.code,
            'code',
            'DavCollectionPropertiesIncomplete',
          ),
        ),
      );
    },
  );
  test('unsupported advertised calendar data is not invented', () async {
    await expectLater(
      _discover(
        extra: '<c:supported-calendar-data><c:calendar-data content-type="application/calendar+json" version="2.0"/></c:supported-calendar-data>',
      ),
      throwsA(
        isA<DavException>().having(
          (e) => e.code,
          'code',
          'DavCalendarDataUnsupported',
        ),
      ),
    );
  });
  test(
    'RFC 4791 calendar-data attribute defaults apply alongside jCal',
    () async {
      final c = (await _discover(
        extra: '<c:supported-calendar-data><c:calendar-data/><c:calendar-data content-type="application/calendar+json"/></c:supported-calendar-data>',
      )).collections.single;
      expect(c.supportedCalendarData, [
        {'contentType': 'text/calendar', 'version': '2.0'},
        {'contentType': 'application/calendar+json', 'version': '2.0'},
      ]);
    },
  );
  test(
    'mandatory principal failure is not a successful empty inventory',
    () async {
      await expectLater(
        _discover(missingPrincipal: true),
        throwsA(isA<DavException>()),
      );
    },
  );
}

Future<DavDiscoveryResult> _discover({
  int aclStatus = 404,
  String extra = '',
  bool deniedComponents = false,
  String server = 'https://example.test/',
  bool missingPrincipal = false,
  int wellKnownStatus = 404,
  List<http.Request>? requests,
}) {
  final authority = Uri.parse(server);
  final profile = davProviderProfile(
    BusyProvider.caldav,
    caldavServer: authority,
  );
  final client = MockClient((request) async {
    requests?.add(request);
    if (request.url.path == '/.well-known/caldav') {
      return http.Response('<html>Server home</html>', wellKnownStatus);
    }
    if (request.method == 'OPTIONS') {
      return http.Response(
        '',
        200,
        headers: {
          'dav': 'calendar-access',
          'allow': 'OPTIONS, PROPFIND, REPORT, MKCALENDAR, MOVE',
        },
      );
    }
    String response(String path, String props, {String other = ''}) =>
        '<d:response><d:href>$path</d:href><d:propstat><d:prop>$props</d:prop><d:status>HTTP/1.1 200 OK</d:status></d:propstat>$other</d:response>';
    final body = request.url.path == '/principal/user/'
        ? response(
            request.url.path,
            '<c:calendar-home-set><d:href>/home/</d:href></c:calendar-home-set>',
          )
        : request.url.path == '/home/'
        ? response(
                '/home/',
                '<d:resourcetype><d:collection/></d:resourcetype>',
              ) +
              response(
                '/home/team%2Fwork/',
                '<d:resourcetype><d:collection/><c:calendar/></d:resourcetype>$extra${aclStatus == 200 ? '<d:current-user-privilege-set/>' : ''}',
                other:
                    '${aclStatus == 200 ? '' : '<d:propstat><d:prop><d:current-user-privilege-set/></d:prop><d:status>HTTP/1.1 $aclStatus Unavailable</d:status></d:propstat>'}${deniedComponents ? '<d:propstat><d:prop><c:supported-calendar-component-set/></d:prop><d:status>HTTP/1.1 403 Forbidden</d:status></d:propstat>' : ''}',
              )
        : response(
            request.url.path,
            missingPrincipal ? '' : '<d:current-user-principal><d:href>/principal/user/</d:href></d:current-user-principal>',
          );
    return http.Response(
      '<d:multistatus xmlns:d="DAV:" xmlns:c="urn:ietf:params:xml:ns:caldav">$body</d:multistatus>',
      207,
      headers: {'content-type': 'application/xml'},
    );
  });
  addTearDown(client.close);
  return DavDiscoveryService(
    transport: DavHttpTransport(
      client: client,
      profile: profile,
      accountAuthority: authority,
    ),
    profile: profile,
    accountAuthority: authority,
    accountId: 'caldav',
    credential: DavBasicCredential(username: 'user', password: 'secret'),
  ).discover(correlationId: 'generic-discovery');
}

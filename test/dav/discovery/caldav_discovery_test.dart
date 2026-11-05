import 'dart:convert';
import 'dart:io';

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
  test('100 collections probe with bounded concurrency and reuse durable method hints', () async {
    final now = DateTime.utc(2026, 11, 3);
    final requests = <http.Request>[];
    final timer = Stopwatch()..start();
    final cold = await _discover(
      collectionCount: 100,
      latency: const Duration(milliseconds: 40),
      requests: requests,
      now: now,
    );
    final coldMs = timer.elapsedMilliseconds;
    expect(cold.collections, hasLength(100));
    expect(
      requests.where(
        (r) =>
            r.method == 'OPTIONS' &&
            (r.url.path.startsWith('/home/') && r.url.path != '/home/'),
      ),
      hasLength(100),
    );
    final db = AppDatabase.memoryForTests();
    addTearDown(db.close);
    await db
        .into(db.accounts)
        .insert(
          AccountsCompanion.insert(
            id: 'caldav',
            provider: 'caldav',
            providerAccountId: 'user',
            authority: 'https://example.test/',
            credentialKind: 'caldav_password',
            createdAtUtc: 'now',
            updatedAtUtc: 'now',
          ),
        );
    final repo = DavDiscoveryRepository(database: db);
    await repo.commitSuccessfulInventory(cold);
    final cache = await repo.collectionMethodCache('caldav');
    expect(cache, hasLength(100));
    requests.clear();
    timer.reset();
    final warm = await _discover(
      collectionCount: 100,
      latency: const Duration(milliseconds: 40),
      methodCache: cache,
      requests: requests,
      now: now.add(const Duration(hours: 1)),
    );
    final warmMs = timer.elapsedMilliseconds;
    expect(warm.collections.every((c) => c.capabilities.supportsMove), isTrue);
    expect(
      requests.where(
        (r) =>
            r.method == 'OPTIONS' &&
            (r.url.path.startsWith('/home/') && r.url.path != '/home/'),
      ),
      isEmpty,
    );
    await repo.commitSuccessfulInventory(warm);
    expect(
      (await repo.collectionMethodCache('caldav')).values
          .every((v) => v.$1 == now),
      isTrue,
    );
    stdout.writeln(
      'DAV discovery benchmark: 100 collections; 40 ms/request; cold=$coldMs ms (100 method probes), warm=$warmMs ms (0 method probes); former sequential probes alone=4000 ms',
    );
    requests.clear();
    await _discover(
      collectionCount: 100,
      methodCache: cache,
      requests: requests,
      now: now.add(const Duration(hours: 25)),
    );
    expect(
      requests.where(
        (r) =>
            r.method == 'OPTIONS' &&
            (r.url.path.startsWith('/home/') && r.url.path != '/home/'),
      ),
      hasLength(100),
    );
  });

  for (final (methods, features, supported) in [
    ('PROPFIND, REPORT', 'calendar-access', false),
    ('PROPFIND, REPORT, MKCALENDAR', 'calendar-access', true),
    ('PROPFIND, REPORT, MKCOL', 'calendar-access, extended-mkcol', true),
    ('PROPFIND, REPORT, MKCOL', 'calendar-access', false),
  ]) {
    test(
      'persisted creation capability requires an advertised method: $methods; $features',
      () async {
        final result = await _discover(
          creationMethods: methods,
          serverFeatures: features,
        );
        final db = AppDatabase.memoryForTests();
        addTearDown(db.close);
        await db
            .into(db.accounts)
            .insert(
              AccountsCompanion.insert(
                id: 'caldav',
                provider: 'caldav',
                providerAccountId: 'user',
                authority: 'https://example.test/',
                credentialKind: 'caldav_password',
                createdAtUtc: 'now',
                updatedAtUtc: 'now',
              ),
            );
        await DavDiscoveryRepository(database: db)
            .commitSuccessfulInventory(result);
        final account = await db.select(db.accounts).getSingle();
        expect(
          jsonDecode(
            account.providerMetadataJson!,
          )['caldavCollectionCreationSupported'],
          supported,
        );
      },
    );
  }

  test(
    'optional method-probe server failure preserves readable discovery',
    () async {
      expect(
        (await _discover(collectionOptionsStatus: 503))
            .collections
            .single
            .capabilities
            .canRead,
        isTrue,
      );
    },
  );

  test(
    'collection OPTIONS advertises MOVE independently of its home',
    () async {
      final c = (await _discover(
        homeMove: false,
        collectionMove: true,
      )).collections.single;
      expect(c.capabilities.supportsMove, isTrue);
    },
  );
  test(
    'collection OPTIONS constrains MOVE even when its home allows it',
    () async {
      final c = (await _discover(collectionMove: false)).collections.single;
      expect(c.capabilities.supportsMove, isFalse);
    },
  );
  test('unsupported optional method probe does not invent MOVE or hide readable inventory', () async {
    final c = (await _discover(collectionOptionsStatus: 405))
        .collections
        .single;
    expect(c.capabilities.supportsMove, isFalse);
    expect(c.capabilities.canRead, isTrue);
  });
  test('method probe authentication failure remains authoritative', () async {
    await expectLater(
      _discover(collectionOptionsStatus: 401),
      throwsA(
        isA<DavException>().having(
          (e) => e.kind,
          'kind',
          DavErrorKind.authentication,
        ),
      ),
    );
  });
  test(
    'collection supported-method-set can advertise MOVE absent from its home',
    () async {
      final c = (await _discover(
        homeMove: false,
        extra: '<d:supported-method-set><d:supported-method name="MOVE"/></d:supported-method-set>',
      )).collections.single;
      expect(c.capabilities.supportsMove, isTrue);
    },
  );
  test(
    'explicit collection method set constrains a broader home Allow',
    () async {
      final c = (await _discover(
        extra: '<d:supported-method-set><d:supported-method name="PROPFIND"/></d:supported-method-set>',
      )).collections.single;
      expect(c.capabilities.supportsMove, isFalse);
    },
  );
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
    'origin discovery can independently select the other installation',
    () async {
      final other = await _discover(wellKnownStatus: 207);
      expect(other.service.principalHref.path, '/other/principal/');
      expect(other.service.calendarHomeHref.path, '/other/home/');
      expect(other.collections.single.requestUri.path, '/other/home/calendar/');
    },
  );

  for (final status in [200, 403, 404, 405, 410, 501]) {
    test(
      'explicit installation failure $status never selects another installation',
      () async {
        final requests = <http.Request>[];
        await expectLater(
          _discover(
            server: 'https://example.test/team/',
            explicitStatus: status,
            wellKnownStatus: 207,
            requests: requests,
          ),
          throwsA(isA<DavException>()),
        );
        expect(requests, hasLength(1));
        expect(requests.single.url.path, '/team/');
      },
    );
  }

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
  int? explicitStatus,
  String creationMethods = 'OPTIONS, PROPFIND, REPORT, MKCALENDAR',
  String serverFeatures = 'calendar-access',
  bool homeMove = true,
  bool? collectionMove,
  int collectionOptionsStatus = 200,
  List<http.Request>? requests,
  Map<String, (DateTime, bool)> methodCache = const {},
  int collectionCount = 1,
  Duration latency = Duration.zero,
  DateTime? now,
}) {
  final authority = Uri.parse(server);
  final profile = davProviderProfile(
    BusyProvider.caldav,
    caldavServer: authority,
  );
  final client = MockClient((request) async {
    requests?.add(request);
    if (latency > Duration.zero) await Future<void>.delayed(latency);
    if (request.url.path == '/team/' && explicitStatus != null) {
      return http.Response(
        '<html>Team installation unavailable</html>',
        explicitStatus,
      );
    }
    if (request.url.path == '/.well-known/caldav') {
      if (wellKnownStatus == 207) {
        return http.Response(
          '<d:multistatus xmlns:d="DAV:"><d:response><d:href>/.well-known/caldav</d:href><d:propstat><d:prop><d:current-user-principal><d:href>/other/principal/</d:href></d:current-user-principal></d:prop><d:status>HTTP/1.1 200 OK</d:status></d:propstat></d:response></d:multistatus>',
          207,
        );
      }
      return http.Response('<html>Server home</html>', wellKnownStatus);
    }
    if (request.method == 'OPTIONS') {
      final collection =
          request.url.path.startsWith('/home/') && request.url.path != '/home/';
      return http.Response(
        '',
        collection ? collectionOptionsStatus : 200,
        headers: {
          'dav': serverFeatures,
          'allow':
              '$creationMethods${(collection ? collectionMove ?? homeMove : homeMove) ? ', MOVE' : ''}',
        },
      );
    }
    String response(String path, String props, {String other = ''}) =>
        '<d:response><d:href>$path</d:href><d:propstat><d:prop>$props</d:prop><d:status>HTTP/1.1 200 OK</d:status></d:propstat>$other</d:response>';
    if (request.url.path.startsWith('/other/')) {
      final props = request.url.path == '/other/principal/'
          ? response(
              request.url.path,
              '<c:calendar-home-set><d:href>/other/home/</d:href></c:calendar-home-set>',
            )
          : response(
                  '/other/home/',
                  '<d:resourcetype><d:collection/></d:resourcetype>',
                ) +
                response(
                  '/other/home/calendar/',
                  '<d:resourcetype><d:collection/><c:calendar/></d:resourcetype><d:displayname>Other installation</d:displayname>',
                );
      return http.Response(
        '<d:multistatus xmlns:d="DAV:" xmlns:c="urn:ietf:params:xml:ns:caldav">$props</d:multistatus>',
        207,
      );
    }
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
              List.generate(
                collectionCount,
                (i) => response(
                  collectionCount == 1
                      ? '/home/team%2Fwork/'
                      : Uri(pathSegments: ['', 'home', 'collection-$i', ''])
                            .path,
                  '<d:resourcetype><d:collection/><c:calendar/></d:resourcetype>$extra${aclStatus == 200 ? '<d:current-user-privilege-set/>' : ''}',
                  other:
                      '${aclStatus == 200 ? '' : '<d:propstat><d:prop><d:current-user-privilege-set/></d:prop><d:status>HTTP/1.1 $aclStatus Unavailable</d:status></d:propstat>'}${deniedComponents ? '<d:propstat><d:prop><c:supported-calendar-component-set/></d:prop><d:status>HTTP/1.1 403 Forbidden</d:status></d:propstat>' : ''}',
                ),
              ).join()
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
    collectionMethodCache: methodCache,
    nowUtc: now == null ? null : () => now,
  ).discover(correlationId: 'generic-discovery');
}

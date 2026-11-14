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
import 'package:busymax/src/features/accounts/data/accounts_repository.dart';
import 'package:busymax/src/providers/busy_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  for (final (direct, overlap) in [
    (true, false),
    (false, false),
    (false, true),
  ]) {
    test(
      'discovers ${direct ? 'direct' : 'nested'} home calendars with overlap=$overlap, prefixes and encoded hrefs',
      () async {
        final requests = <String>[];
        final root = Uri.parse('https://example.test/install/dav/');
        String item(String href, String type) => _response(
          href,
          '<d:resourcetype><d:collection/>$type</d:resourcetype>'
          '<d:current-user-privilege-set><d:privilege><d:all/></d:privilege></d:current-user-privilege-set>',
        );
        final home = direct
            ? '/install/calendars/work%20team/'
            : '/install/calendars/';
        final child = '${home}nested/';
        final client = MockClient((request) async {
          if (request.method == 'OPTIONS') {
            return http.Response(
              '',
              200,
              headers: {
                'allow': 'PROPFIND, MKCALENDAR, MOVE',
                'dav': '1, calendar-access',
              },
            );
          }
          expect(request.headers['depth'], isNot('infinity'));
          requests.add(request.url.path);
          final contents = request.url.path == root.path
              ? _response(
                  root.path,
                  '<d:current-user-principal><d:href>/install/principal/</d:href></d:current-user-principal>',
                )
              : request.url.path == '/install/principal/'
              ? _response(
                  '/install/principal/',
                  '<c:calendar-home-set><d:href>$home</d:href>${!direct && overlap ? '<d:href>$child</d:href>' : ''}</c:calendar-home-set>',
                )
              : request.url.path == home
              ? item(home, direct ? '<c:calendar/>' : '') +
                    (direct ? '' : item(child, ''))
              : item(child, '') +
                    item('${child}team%2Fcalendar/', '<c:calendar/>');
          return http.Response(
            '<d:multistatus xmlns:d="DAV:" xmlns:c="urn:ietf:params:xml:ns:caldav">$contents</d:multistatus>',
            207,
          );
        });
        final profile = davProviderProfile(
          BusyProvider.caldav,
          caldavServer: root,
        );
        final result = await DavDiscoveryService(
          transport: DavHttpTransport(
            client: client,
            profile: profile,
            accountAuthority: root,
          ),
          profile: profile,
          accountAuthority: root,
          accountId: 'caldav',
          credential: DavBasicCredential(username: 'qa', password: 'synthetic'),
        ).discover(correlationId: 'nested-homes');
        expect(result.collections, hasLength(1));
        expect(
          result.collections.single.requestUri.path,
          direct ? home : '${child}team%2Fcalendar/',
        );
        expect(
          requests.where((path) => path == child),
          hasLength(direct ? 0 : 1),
        );
        if (direct) {
          expect(result.collections.single.parentPrivileges, isEmpty);
          expect(
            result.service.principalContexts.single.calendarHomeIsCalendar,
            isTrue,
          );
          final db = AppDatabase.memoryForTests();
          addTearDown(db.close);
          await db
              .into(db.accounts)
              .insert(
                AccountsCompanion.insert(
                  id: 'caldav',
                  provider: 'caldav',
                  providerAccountId: 'qa',
                  authority: root.toString(),
                  credentialKind: 'caldav_password',
                  createdAtUtc: 'now',
                  updatedAtUtc: 'now',
                ),
              );
          await DavDiscoveryRepository(database: db)
              .commitSuccessfulInventory(result);
          final account = await db.select(db.accounts).getSingle();
          expect(
            (jsonDecode(account.providerMetadataJson!)
                as Map)['caldavCollectionCreationSupported'],
            isFalse,
          );
        }
      },
    );
  }

  for (final failure in ['depth-limit', 'denied', 'cancelled']) {
    test(
      'bounded traversal $failure rejects partial inventory and retains persisted sources',
      () async {
        final directory = await Directory.systemTemp.createTemp(
          'busymax-discovery-',
        );
        addTearDown(() => directory.delete(recursive: true));
        final file = File('${directory.path}/qa.sqlite');
        var db = AppDatabase(NativeDatabase(file));
        await db
            .into(db.accounts)
            .insert(
              AccountsCompanion.insert(
                id: 'caldav',
                provider: 'caldav',
                providerAccountId: 'qa',
                authority: 'https://example.test/',
                credentialKind: 'caldav_password',
                createdAtUtc: 'now',
                updatedAtUtc: 'now',
              ),
            );
        await DavDiscoveryRepository(database: db)
            .commitSuccessfulInventory(await _discover());
        final before = (await db.select(db.davCollections).get())
            .map((r) => r.toJson())
            .toList();
        final sources = (await db.select(db.calendarSources).get())
            .map((r) => r.toJson())
            .toList();
        final lists = (await db.select(db.taskLists).get())
            .map((r) => r.toJson())
            .toList();
        final cancellation = DavCancellationToken();
        var requests = 0;
        final root = Uri.parse('https://example.test/install/dav/');
        final profile = davProviderProfile(
          BusyProvider.caldav,
          caldavServer: root,
        );
        final client = MockClient((request) async {
          if (request.method == 'OPTIONS') {
            return http.Response(
              '',
              200,
              headers: {'dav': '1, calendar-access'},
            );
          }
          requests++;
          String props(String path) => _response(
            path,
            '<d:resourcetype><d:collection/></d:resourcetype>',
          );
          final path = request.url.path;
          if (path.contains('nested') && failure == 'denied') {
            return http.Response('', 403);
          }
          if (path.contains('nested') && failure == 'cancelled') {
            cancellation.cancel();
          }
          final contents = path == root.path
              ? _response(
                  path,
                  '<d:current-user-principal><d:href>/install/principal/</d:href></d:current-user-principal>',
                )
              : path == '/install/principal/'
              ? _response(
                  path,
                  '<c:calendar-home-set><d:href>/install/calendars/</d:href></c:calendar-home-set>',
                )
              : props(path) + props('${path}nested/');
          return http.Response(
            '<d:multistatus xmlns:d="DAV:" xmlns:c="urn:ietf:params:xml:ns:caldav">$contents</d:multistatus>',
            207,
          );
        });
        await expectLater(() async {
          final result = await DavDiscoveryService(
            transport: DavHttpTransport(
              client: client,
              profile: profile,
              accountAuthority: root,
            ),
            profile: profile,
            accountAuthority: root,
            accountId: 'caldav',
            credential: DavBasicCredential(
              username: 'qa',
              password: 'synthetic',
            ),
          ).discover(correlationId: 'bounded', cancellationToken: cancellation);
          await DavDiscoveryRepository(database: db)
              .commitSuccessfulInventory(result);
        }(), throwsA(isA<DavException>()));
        expect(requests, lessThanOrEqualTo(12));
        await db.close();
        db = AppDatabase(NativeDatabase(file));
        expect(
          (await db.select(db.davCollections).get()).map((r) => r.toJson()),
          before,
        );
        expect(
          (await db.select(db.calendarSources).get()).map((r) => r.toJson()),
          sources,
        );
        expect(
          (await db.select(db.taskLists).get()).map((r) => r.toJson()),
          lists,
        );
        await db.close();
      },
    );
  }

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

  for (final (headers, expected) in [
    (<String, String>{}, DavCollectionCreationCapability.unknown),
    ({'allow': 'GET, PROPFIND'}, DavCollectionCreationCapability.unsupported),
    ({'allow': ''}, DavCollectionCreationCapability.unsupported),
    ({'allow': 'MKCALENDAR'}, DavCollectionCreationCapability.supported),
    (
      {'allow': 'MKCOL', 'dav': 'extended-mkcol'},
      DavCollectionCreationCapability.supported,
    ),
    ({'allow': 'MKCOL'}, DavCollectionCreationCapability.unsupported),
  ]) {
    test('discovery OPTIONS 405 respects Allow $headers', () async {
      final result = await _discover(
        targetCreationMethodsOnly: true,
        collectionOptionsStatus: 405,
        collectionOptionsHeaders: headers,
      );
      final context = result.service.principalContexts.single;
      expect(context.effectiveCollectionCreationCapability, expected);
      expect(
        DavPrincipalContext.fromJson(context.toJson())
            .effectiveCollectionCreationCapability,
        expected,
      );
      expect(result.collections, hasLength(1));
    });
  }

  for (final status in [200, 403, 404, 405, 501]) {
    for (final acl in ['all', 'read', 'unknown']) {
      test(
        'persisted unknown creation evidence separates target status=$status and parent ACL=$acl',
        () async {
          final result = await _discover(
            creationMethods: 'OPTIONS, PROPFIND',
            collectionOptionsStatus: status,
            homeAcl: acl == 'unknown'
                ? ''
                : '<d:current-user-privilege-set><d:privilege><d:$acl/></d:privilege></d:current-user-privilege-set>',
          );
          final context = result.service.principalContexts.single;
          final capability = status == 200 || status == 405
              ? DavCollectionCreationCapability.unsupported
              : status == 403
              ? DavCollectionCreationCapability.denied
              : DavCollectionCreationCapability.unknown;
          expect(context.effectiveCollectionCreationCapability, capability);
          expect(
            DavPrincipalContext.fromJson(context.toJson())
                .effectiveCollectionCreationCapability,
            capability,
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
          final account = AccountEntity.fromRow(
            await db.select(db.accounts).getSingle(),
          );
          expect(
            account.caldavCollectionCreationAvailable,
            capability == DavCollectionCreationCapability.unknown &&
                acl == 'all',
          );
        },
      );
    }
  }

  test('creation methods advertised only at an unused child are separate from home permissions', () async {
    final requests = <http.Request>[];
    final result = await _discover(
      targetCreationMethodsOnly: true,
      requests: requests,
    );
    final context = result.service.principalContexts.single;
    expect(context.advertisedCollectionCreationMethods, contains('MKCALENDAR'));
    expect(context.homePrivilegesKnown, isFalse);
    expect(
      requests.where(
        (r) => r.method == 'OPTIONS' && r.url.path.contains('busymax-options-'),
      ),
      hasLength(1),
    );
    expect(
      requests.any((r) => r.method == 'MKCALENDAR' || r.method == 'MKCOL'),
      isFalse,
    );
  });

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
  for (final status in [403, 404]) {
    test(
      'structured optional ACL error $status preserves readable calendar and unknown administration',
      () async {
        final result = await _discover(
          aclStatus: status,
          aclError: '<d:error><d:need-privileges><d:resource><d:href>/home/team%2Fwork/</d:href><d:privilege><d:read-current-user-privilege-set/></d:privilege></d:resource></d:need-privileges><x:unknown xmlns:x="urn:example:error"/></d:error>',
        );
        final calendar = result.collections.single;
        expect(calendar.capabilities.canRead, isTrue);
        expect(calendar.capabilities.permissionsKnown, isFalse);
        expect(calendar.capabilities.canWriteProperties, isFalse);
        expect(calendar.capabilities.canWriteContent, isFalse);
        expect(calendar.capabilities.canAddMembers, isFalse);
        expect(calendar.capabilities.canDeleteMembers, isFalse);
        expect(calendar.parentPrivileges, isEmpty);
        expect(
          result.service.principalContexts.single.homePrivilegesKnown,
          isFalse,
        );
      },
    );
  }
  for (final error in [
    '<d:error/>',
    '<d:error>not structured</d:error>',
    '<d:error><![CDATA[invalid text]]><d:need-privileges/></d:error>',
    '<d:error>mixed<d:need-privileges/></d:error>',
    '<d:error><d:need-privileges/></d:error><d:error><d:need-privileges/></d:error>',
    '<d:error><d:need-privileges/></d:error><d:status>HTTP/1.1 403 Forbidden</d:status>',
  ]) {
    test('rejects malformed optional property error $error', () async {
      await expectLater(
        _discover(aclError: error),
        throwsA(isA<DavException>()),
      );
    });
  }
  test('missing mandatory resource type remains incomplete', () async {
    await expectLater(
      _discover(resourceType: ''),
      throwsA(isA<DavException>()),
    );
  });
  test('resource-level failure remains incomplete', () async {
    await expectLater(
      _discover(
        resourceResponse: '<d:response><d:href>/home/team%2Fwork/</d:href><d:status>HTTP/1.1 403 Forbidden</d:status><d:error><d:need-privileges/></d:error></d:response>',
      ),
      throwsA(isA<DavException>()),
    );
  });
  for (final aclStatus in [404, 403]) {
    for (final ownerKnown in [false, true]) {
      test(
        'optional ACL $aclStatus survives persistence without assuming ownership; owner=$ownerKnown',
        () async {
          final result = await _discover(
            aclStatus: aclStatus,
            extra: ownerKnown
                ? '<d:owner><d:href>/principal/user/</d:href></d:owner>'
                : '',
          );
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
          expect(settings.taskCapabilities.supportsListDelete, ownerKnown);
          final source = await db.select(db.calendarSources).getSingle();
          final sourceCapabilities = CalendarSourceEntity.fromRow(
            source,
            davCollection: stored,
          ).capabilities;
          expect(sourceCapabilities.canRenameCalendar, isTrue);
          expect(sourceCapabilities.canDeleteCalendar, ownerKnown);
          expect(
            jsonDecode(stored.safeDisplayMetadataJson!)['privilegesKnown'],
            'false',
          );
        },
      );
    }
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
  test('HTML installation landing page accepts only a well-known redirect inside that installation', () async {
    final requests = <http.Request>[];
    final result = await _discover(
      server: 'https://example.test/team/',
      explicitStatus: 200,
      wellKnownRedirectPath: '/team/dav.php/',
      requests: requests,
    );
    expect(result.collections, isNotEmpty);
    expect(requests.take(3).map((r) => r.url.path), [
      '/team/',
      '/.well-known/caldav',
      '/team/dav.php/',
    ]);
    for (final other in ['/other/dav.php/', '/team-other/dav.php/']) {
      await expectLater(
        _discover(
          server: 'https://example.test/team/',
          explicitStatus: 200,
          wellKnownRedirectPath: other,
        ),
        throwsA(isA<DavException>()),
      );
    }
  });

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
        expect(requests, hasLength(status == 200 ? 2 : 1));
        expect(requests.first.url.path, '/team/');
      },
    );
  }

  test(
    'an HTML well-known response falls back to the explicit endpoint',
    () async {
      final requests = <http.Request>[];
      final result = await _discover(requests: requests, wellKnownStatus: 200);
      expect(requests.take(3).map((r) => r.url.path), [
        '/.well-known/caldav',
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
  for (final status in [301, 303, 307]) {
    test(
      'production discovery resolves well-known $status with HEAD before DAV',
      () async {
        final requests = <http.Request>[];
        final result = await _discover(
          requests: requests,
          wellKnownRedirectPath: '/dav/',
          wellKnownRedirectStatus: status,
        );
        expect(requests.take(3).map((r) => (r.method, r.url.path)), [
          ('HEAD', '/.well-known/caldav'),
          ('HEAD', '/dav/'),
          ('PROPFIND', '/dav/'),
        ]);
        expect(result.service.canonicalServiceUri.path, '/dav/');
        expect(result.service.principalHref.path, '/principal/user/');
        expect(result.service.calendarHomeHref.path, '/home/');
        expect(result.collections.single.hrefKey, '/home/team%2Fwork/');
      },
    );
  }
  test('production discovery follows multiple retrieval redirects inside installation', () async {
    final requests = <http.Request>[];
    final result = await _discover(
      server: 'https://example.test/team/',
      explicitStatus: 200,
      wellKnownRedirectPath: '/team/first/',
      wellKnownRedirectStatus: 303,
      redirects: {'/team/first/': (307, '../dav/')},
      requests: requests,
    );
    expect(result.service.canonicalServiceUri.path, '/team/dav/');
    expect(requests.take(5).map((r) => (r.method, r.url.path)), [
      ('PROPFIND', '/team/'),
      ('HEAD', '/.well-known/caldav'),
      ('HEAD', '/team/first/'),
      ('HEAD', '/team/dav/'),
      ('PROPFIND', '/team/dav/'),
    ]);
  });
  for (final scenario in [
    'loop',
    'limit',
    'cross-origin',
    'downgrade',
    'missing-location',
    'malformed-location',
    'cancelled',
  ]) {
    test(
      'production discovery rejects well-known $scenario before DAV or credential transfer',
      () async {
        final requests = <http.Request>[];
        final token = DavCancellationToken();
        final redirects = <String, (int, String?)>{
          '/.well-known/caldav': (
            303,
            switch (scenario) {
              'loop' => '/.well-known/caldav',
              'cross-origin' => 'https://other.test/dav/',
              'downgrade' => 'http://example.test/dav/',
              'missing-location' => null,
              'malformed-location' => 'https://[',
              _ => '/hop/0',
            },
          ),
          for (var i = 0; i < 7; i++) '/hop/$i': (307, '/hop/${i + 1}'),
        };
        await expectLater(
          _discover(
            requests: requests,
            redirects: redirects,
            cancellationToken: token,
            onRequest: (_) {
              if (scenario == 'cancelled') token.cancel();
            },
          ),
          throwsA(isA<DavException>()),
        );
        expect(requests.every((r) => r.method == 'HEAD'), isTrue);
        expect(
          requests.every((r) => r.url.origin == 'https://example.test'),
          isTrue,
        );
        expect(requests.length, lessThanOrEqualTo(6));
      },
    );
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
  String aclError = '',
  String resourceType =
      '<d:resourcetype><d:collection/><c:calendar/></d:resourcetype>',
  String? resourceResponse,
  String extra = '',
  String homeAcl = '',
  bool deniedComponents = false,
  String server = 'https://example.test/',
  bool missingPrincipal = false,
  int wellKnownStatus = 404,
  int? explicitStatus,
  String? wellKnownRedirectPath,
  int wellKnownRedirectStatus = 302,
  Map<String, (int, String?)> redirects = const {},
  DavCancellationToken? cancellationToken,
  void Function(http.Request)? onRequest,
  String creationMethods = 'OPTIONS, PROPFIND, REPORT, MKCALENDAR',
  bool targetCreationMethodsOnly = false,
  String serverFeatures = 'calendar-access',
  bool homeMove = true,
  bool? collectionMove,
  int collectionOptionsStatus = 200,
  Map<String, String>? collectionOptionsHeaders,
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
    onRequest?.call(request);
    if (redirects[request.url.path] case final hop?) {
      return http.Response(
        '',
        hop.$1,
        headers: {if (hop.$2 != null) 'location': hop.$2!},
      );
    }
    if (latency > Duration.zero) await Future<void>.delayed(latency);
    if (request.url.path == '/team/' && explicitStatus != null) {
      return http.Response(
        '<html>Team installation unavailable</html>',
        explicitStatus,
      );
    }
    if (request.url.path == '/.well-known/caldav') {
      if (wellKnownRedirectPath != null) {
        return http.Response(
          '',
          wellKnownRedirectStatus,
          headers: {'location': wellKnownRedirectPath},
        );
      }
      if (wellKnownStatus == 207) {
        return http.Response(
          '<d:multistatus xmlns:d="DAV:"><d:response><d:href>/.well-known/caldav</d:href><d:propstat><d:prop><d:current-user-principal><d:href>/other/principal/</d:href></d:current-user-principal></d:prop><d:status>HTTP/1.1 200 OK</d:status></d:propstat></d:response></d:multistatus>',
          207,
        );
      }
      return http.Response('<html>Server home</html>', wellKnownStatus);
    }
    if (request.method == 'HEAD') return http.Response('', 200);
    if (request.method == 'OPTIONS') {
      final collection =
          request.url.path.startsWith('/home/') && request.url.path != '/home/';
      return http.Response(
        '',
        collection ? collectionOptionsStatus : 200,
        headers: collection && collectionOptionsHeaders != null
            ? collectionOptionsHeaders
            : {
                'dav': serverFeatures,
                'allow':
                    '${targetCreationMethodsOnly && !request.url.path.contains('busymax-options-') ? 'OPTIONS, PROPFIND' : creationMethods}${(collection ? collectionMove ?? homeMove : homeMove) ? ', MOVE' : ''}',
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
                '<d:resourcetype><d:collection/></d:resourcetype>$homeAcl',
              ) +
              List.generate(
                collectionCount,
                (i) =>
                    resourceResponse ??
                    response(
                      collectionCount == 1
                          ? '/home/team%2Fwork/'
                          : Uri(pathSegments: ['', 'home', 'collection-$i', ''])
                                .path,
                      '$resourceType$extra${aclStatus == 200 ? '<d:current-user-privilege-set/>' : ''}',
                      other:
                          '${aclStatus == 200 ? '' : '<d:propstat><d:prop><d:current-user-privilege-set/></d:prop><d:status>HTTP/1.1 $aclStatus Unavailable</d:status>$aclError</d:propstat>'}${deniedComponents ? '<d:propstat><d:prop><c:supported-calendar-component-set/></d:prop><d:status>HTTP/1.1 403 Forbidden</d:status></d:propstat>' : ''}',
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
  ).discover(
    correlationId: 'generic-discovery',
    cancellationToken: cancellationToken,
  );
}

String _response(String href, String properties) =>
    '<d:response><d:href>$href</d:href><d:propstat><d:prop>$properties</d:prop><d:status>HTTP/1.1 200 OK</d:status></d:propstat></d:response>';

import 'dart:convert';

import 'package:busymax/src/core/secrets/secret_store.dart';
import 'package:busymax/src/dav/dav_errors.dart';
import 'package:busymax/src/dav/dav_provider_profile.dart';
import 'package:busymax/src/dav/ical/ical_document.dart';
import 'package:busymax/src/dav/mutation/dav_mutation_patch.dart';
import 'package:busymax/src/dav/mutation/dav_pending_operations.dart';
import 'package:busymax/src/dav/sync/dav_account_sync_engine.dart';
import 'package:busymax/src/db/app_database.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  late AppDatabase database;
  late InMemorySecretStore secrets;

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    secrets = InMemorySecretStore();
    await _seed(database, secrets);
  });

  tearDown(() => database.close());

  test(
    'account sequence syncs, conditionally replays, follows up, then pauses on 401',
    () async {
      var syncReports = 0;
      var unauthorized = false;
      String serverBody = _event('Initial');
      var serverEtag = '"v1"';
      final requests = <http.Request>[];
      final client = MockClient((request) async {
        requests.add(request);
        expect(request.headers['authorization'], startsWith('Basic '));
        if (unauthorized) return http.Response('', 401);
        if (request.method == 'REPORT' &&
            request.body.contains('sync-collection')) {
          syncReports += 1;
          if (syncReports == 1) {
            expect(request.body, contains('<d:sync-token></d:sync-token>'));
            return http.Response(
              _syncResponse(token: 'token-1', etag: serverEtag),
              207,
            );
          }
          if (syncReports == 2) {
            expect(
              request.body,
              contains('<d:sync-token>token-1</d:sync-token>'),
            );
            return http.Response(_syncResponse(token: 'token-2'), 207);
          }
          expect(
            request.body,
            contains('<d:sync-token>token-2</d:sync-token>'),
          );
          return http.Response(
            _syncResponse(token: 'token-3', etag: serverEtag),
            207,
          );
        }
        if (request.method == 'REPORT' &&
            request.body.contains('calendar-multiget')) {
          return http.Response(_multigetResponse(serverBody, serverEtag), 207);
        }
        if (request.method == 'PUT') {
          expect(request.headers['if-match'], '"v1"');
          serverBody = request.body;
          serverEtag = '"v2"';
          return http.Response('', 204);
        }
        if (request.method == 'GET') {
          return http.Response(
            serverBody,
            200,
            headers: {'etag': serverEtag, 'content-type': 'text/calendar'},
          );
        }
        fail('Unexpected ${request.method} ${request.url}');
      });
      final notificationObjects = <String>{};
      DavAccountSyncEngine engine() => DavAccountSyncEngine(
        database: database,
        secretStore: secrets,
        httpClient: client,
        accountId: 'account',
        policy: const DavAccountSyncPolicy(
          discoveryMaxAge: Duration(days: 30),
          inventoryMaxAge: Duration(days: 30),
        ),
        correlationIdFactory: () => 'safe-correlation',
        nowUtc: () => _now,
        rebuildNotifications: (accountId, ids) async {
          expect(accountId, 'account');
          notificationObjects.addAll(ids);
        },
      );

      final initial = await engine().synchronize();
      expect(initial.collectionsSynchronized, 1);
      expect(initial.discoveryRefreshed, isFalse);
      final raw = await database.select(database.davObjects).getSingle();
      expect(raw.rawIcsBody, serverBody);
      expect(raw.etag, '"v1"');
      expect(
        (await database.select(database.calendarEvents).getSingle()).title,
        'Initial',
      );
      expect(notificationObjects, {raw.id});

      await DavPendingOperationQueue(
        database: database,
        idFactory: () => 'pending-update',
        nowUtc: () => _now,
      ).enqueueUpdate(
        accountId: 'account',
        collectionId: 'collection',
        objectId: raw.id,
        patch: DavMutationPatch(
          target: const IcalComponentKey(
            componentType: 'VEVENT',
            uid: 'event@example.test',
          ),
          scope: DavMutationScope.object,
          operations: [DavPatchOperation.setText('SUMMARY', 'Offline edit')],
        ),
      );
      notificationObjects.clear();

      final replayed = await engine().synchronize();
      expect(replayed.pendingOperationsApplied, 1);
      expect(replayed.followUpCollectionsSynchronized, 1);
      expect(await database.select(database.pendingOps).get(), isEmpty);
      expect(serverBody, contains('SUMMARY:Offline edit'));
      expect(
        (await database.select(database.calendarEvents).getSingle()).title,
        'Offline edit',
      );
      expect(
        (await database.select(database.syncCursors).getSingle()).cursorValue,
        'token-3',
      );
      expect(notificationObjects, isNotEmpty);

      unauthorized = true;
      await expectLater(
        engine().synchronize(),
        throwsA(
          isA<DavAccountSyncException>().having(
            (error) => error.failures.single.kind,
            'failure kind',
            DavErrorKind.authentication,
          ),
        ),
      );
      expect(
        (await database.select(database.accounts).getSingle()).authState,
        'reauth_required',
      );
      expect(await database.select(database.davObjects).get(), hasLength(1));
      expect(
        (await database.select(database.calendarEvents).getSingle()).title,
        'Offline edit',
      );
      expect(
        requests.every((request) => !request.url.toString().contains('secret')),
        isTrue,
      );
    },
  );

  test(
    'missing credential marks reauthentication without deleting cache',
    () async {
      await secrets.deleteCredential('account');
      final engine = DavAccountSyncEngine(
        database: database,
        secretStore: secrets,
        httpClient: MockClient((_) async => http.Response('', 500)),
        accountId: 'account',
      );

      await expectLater(
        engine.synchronize(),
        throwsA(
          isA<DavException>().having(
            (error) => error.code,
            'code',
            'DavCredentialsRevoked',
          ),
        ),
      );
      expect(
        (await database.select(database.accounts).getSingle()).authState,
        'reauth_required',
      );
      expect(
        await database.select(database.davCollections).get(),
        hasLength(1),
      );
    },
  );

  test('credential mismatch maps to reauthentication-required', () async {
    await secrets.saveCredential(
      'account',
      AppleICloudSecretRecord(
        username: 'someone@example.test',
        appSpecificPassword: 'not-the-nextcloud-secret',
      ),
    );
    final engine = DavAccountSyncEngine(
      database: database,
      secretStore: secrets,
      httpClient: MockClient((_) async => http.Response('', 500)),
      accountId: 'account',
    );

    await expectLater(
      engine.synchronize(),
      throwsA(
        isA<DavException>().having(
          (error) => error.code,
          'code',
          'DavCredentialsRevoked',
        ),
      ),
    );
    expect(
      (await database.select(database.accounts).getSingle()).authState,
      'reauth_required',
    );
    expect(await database.select(database.davCollections).get(), hasLength(1));
  });

  test('locked credential store is temporary and preserves cache', () async {
    final engine = DavAccountSyncEngine(
      database: database,
      secretStore: _UnavailableSecretStore(),
      httpClient: MockClient((_) async => http.Response('', 500)),
      accountId: 'account',
    );

    await expectLater(
      engine.synchronize(),
      throwsA(
        isA<DavException>().having(
          (error) => error.code,
          'code',
          'DavCredentialStoreUnavailable',
        ),
      ),
    );
    expect(
      (await database.select(database.accounts).getSingle()).authState,
      'temporarily_unavailable',
    );
    expect(await database.select(database.davCollections).get(), hasLength(1));
  });
}

final class _UnavailableSecretStore extends InMemorySecretStore {
  @override
  Future<SecretRecord?> readCredential(String accountId) {
    throw const SecretStoreException(
      'SecretStoreUnavailable',
      secretStorageUnavailableMessage,
    );
  }
}

const _collectionHref = '/cloud/remote.php/dav/calendars/alex/work/';
const _eventHref = '${_collectionHref}event.ics';
final _now = DateTime.utc(2026, 8, 8, 12);

Future<void> _seed(AppDatabase database, InMemorySecretStore secrets) async {
  const now = '2026-08-08T12:00:00.000Z';
  await database
      .into(database.accounts)
      .insert(
        AccountsCompanion.insert(
          id: 'account',
          provider: 'nextcloud',
          authority: 'https://cloud.example.test/cloud',
          providerAccountId: 'alex',
          credentialKind: 'nextcloud_app_password',
          authState: const Value('signed_in'),
          createdAtUtc: now,
          updatedAtUtc: now,
        ),
      );
  await secrets.saveCredential(
    'account',
    NextcloudSecretRecord(
      canonicalServer: Uri.parse('https://cloud.example.test/cloud'),
      loginName: 'alex',
      appPassword: 'secret-app-password',
    ),
  );
  await database
      .into(database.davAccountServices)
      .insert(
        DavAccountServicesCompanion.insert(
          accountId: 'account',
          providerProfileVersion: const Value(davProviderProfileVersion),
          canonicalServiceUri:
              'https://cloud.example.test/cloud/remote.php/dav/',
          canonicalOrigin: 'https://cloud.example.test',
          principalHref: const Value(
            'https://cloud.example.test/cloud/remote.php/dav/principals/users/alex/',
          ),
          calendarHomeHref: const Value(
            'https://cloud.example.test/cloud/remote.php/dav/calendars/alex/',
          ),
          capabilitiesJson: const Value(
            '{"hasPrincipal":true,"hasCalendarHome":true}',
          ),
          discoveredAtUtc: now,
          lastValidatedAtUtc: const Value(now),
        ),
      );
  await database
      .into(database.davCollections)
      .insert(
        DavCollectionsCompanion.insert(
          id: 'collection',
          accountId: 'account',
          hrefKey: _collectionHref,
          requestUri: 'https://cloud.example.test$_collectionHref',
          displayName: 'Work',
          supportedComponentMask: const Value(3),
          supportedReportsJson: Value(
            jsonEncode([
              '{DAV:}sync-collection',
              '{urn:ietf:params:xml:ns:caldav}calendar-multiget',
            ]),
          ),
          currentUserPrivilegesJson: Value(
            jsonEncode(['{DAV:}read', '{DAV:}write']),
          ),
          readOnly: const Value(false),
          eventProjectionEnabled: const Value(true),
          taskProjectionEnabled: const Value(true),
          lastInventoryAtUtc: const Value(now),
          createdAtUtc: now,
          updatedAtUtc: now,
        ),
      );
  await database
      .into(database.calendarSources)
      .insert(
        CalendarSourcesCompanion.insert(
          id: 'dav-calendar-collection',
          accountId: 'account',
          provider: 'nextcloud',
          providerCalendarId: _collectionHref,
          davCollectionId: const Value('collection'),
          summary: 'Work',
          createdAtLocal: _now.millisecondsSinceEpoch,
          updatedAtLocal: _now.millisecondsSinceEpoch,
        ),
      );
  await database
      .into(database.taskLists)
      .insert(
        TaskListsCompanion.insert(
          accountId: 'account',
          id: 'dav-task-list-collection',
          davCollectionId: const Value('collection'),
          title: 'Work',
          rawJson: '{}',
          createdLocalAtUtc: now,
          updatedLocalAtUtc: now,
        ),
      );
}

String _syncResponse({required String token, String? etag}) =>
    '''<?xml version="1.0" encoding="utf-8"?>
<d:multistatus xmlns:d="DAV:">
  ${etag == null ? '' : '''<d:response>
    <d:href>$_eventHref</d:href>
    <d:propstat><d:prop><d:getetag>$etag</d:getetag></d:prop>
      <d:status>HTTP/1.1 200 OK</d:status></d:propstat>
  </d:response>'''}
  <d:sync-token>$token</d:sync-token>
</d:multistatus>''';

String _multigetResponse(String body, String etag) =>
    '''<?xml version="1.0" encoding="utf-8"?>
<d:multistatus xmlns:d="DAV:" xmlns:c="urn:ietf:params:xml:ns:caldav">
  <d:response>
    <d:href>$_eventHref</d:href>
    <d:propstat><d:prop>
      <d:getetag>$etag</d:getetag>
      <c:calendar-data content-type="text/calendar"><![CDATA[$body]]></c:calendar-data>
    </d:prop><d:status>HTTP/1.1 200 OK</d:status></d:propstat>
  </d:response>
</d:multistatus>''';

String _event(String summary) =>
    '''BEGIN:VCALENDAR\r
VERSION:2.0\r
PRODID:-//BusyMax Test//EN\r
BEGIN:VEVENT\r
UID:event@example.test\r
DTSTART:20260808T090000Z\r
DTEND:20260808T100000Z\r
SUMMARY:$summary\r
END:VEVENT\r
END:VCALENDAR\r
''';

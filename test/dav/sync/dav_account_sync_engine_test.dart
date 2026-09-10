import 'dart:convert';

import 'package:busymax/src/core/secrets/secret_store.dart';
import 'package:busymax/src/dav/dav_errors.dart';
import 'package:busymax/src/dav/dav_provider_profile.dart';
import 'package:busymax/src/dav/ical/ical_document.dart';
import 'package:busymax/src/dav/mutation/dav_mutation_patch.dart';
import 'package:busymax/src/dav/mutation/dav_pending_operations.dart';
import 'package:busymax/src/dav/storage/dav_object_repository.dart';
import 'package:busymax/src/dav/sync/dav_account_sync_engine.dart';
import 'package:busymax/src/db/app_database.dart';
import 'package:busymax/src/features/notifications/notification_schedule_service.dart';
import 'package:busymax/src/features/sync/pending_op_resolution_service.dart';
import 'package:busymax/src/providers/busy_provider.dart';
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
        if (request.method == 'OPTIONS') {
          return http.Response(
            '',
            200,
            headers: {'dav': '1, calendar-access, sync-collection'},
          );
        }
        if (request.method == 'PROPFIND') {
          if (request.body.contains('<d:current-user-principal/>')) {
            return _discoveryMultistatus(_currentPrincipalResponse);
          }
          if (request.body.contains('<c:calendar-home-set/>')) {
            return _discoveryMultistatus(_principalPropertiesResponse);
          }
          return _discoveryMultistatus(
            '''<d:multistatus xmlns:d="DAV:" xmlns:c="urn:ietf:params:xml:ns:caldav">
            <d:response><d:href>$_collectionHref</d:href><d:propstat><d:prop>
            <d:resourcetype><d:collection/><c:calendar/></d:resourcetype><d:displayname>Work</d:displayname>
            <d:current-user-privilege-set><d:privilege><d:read/></d:privilege><d:privilege><d:write/></d:privilege></d:current-user-privilege-set>
            <c:supported-calendar-component-set><c:comp name="VEVENT"/><c:comp name="VTODO"/></c:supported-calendar-component-set>
            <d:supported-report-set><d:supported-report><d:report><d:sync-collection/></d:report></d:supported-report>
            <d:supported-report><d:report><c:calendar-multiget/></d:report></d:supported-report></d:supported-report-set>
            </d:prop><d:status>HTTP/1.1 200 OK</d:status></d:propstat></d:response></d:multistatus>''',
          );
        }
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
      expect(replayed.discoveryRefreshed, isTrue);
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

  test(
    'Diagnostics retry completes a remotely moved task after source sync deletion',
    () async {
      await _seedDestination(database);
      const uid = 'partial-move-task@example.test';
      const sourceHref = '${_collectionHref}partial-move-task.ics';
      const destinationHref =
          '${_destinationCollectionHref}partial-move-task.ics';
      final sourceRaw = _taskWithParent(uid, 'Parented task');
      final objectRepository = DavObjectRepository(
        database: database,
        idFactory: () => 'source-object',
      );
      await objectRepository.commitConfirmedMutation(
        accountId: 'account',
        collectionId: 'collection',
        provider: BusyProvider.nextcloud,
        canonicalObject: _preparedMember(
          href: sourceHref,
          etag: '"source-1"',
          body: sourceRaw,
        ),
        completedAtUtc: _now,
      );
      final sourceObject = await (database.select(
        database.davObjects,
      )..where((row) => row.hrefKey.equals(sourceHref))).getSingle();
      final sourceTask = await (database.select(
        database.tasks,
      )..where((row) => row.davObjectId.equals(sourceObject.id))).getSingle();
      final operationId =
          await DavPendingOperationQueue(
            database: database,
            idFactory: () => 'pending-partial-move',
            nowUtc: () => _now,
          ).enqueueMove(
            accountId: 'account',
            sourceCollectionId: 'collection',
            destinationCollectionId: 'destination',
            objectId: sourceObject.id,
            localProjectionId: sourceTask.id,
            target: const IcalComponentKey(componentType: 'VTODO', uid: uid),
            postMovePatch: DavMutationPatch(
              target: const IcalComponentKey(componentType: 'VTODO', uid: uid),
              scope: DavMutationScope.object,
              operations: [DavPatchOperation.setTaskParent(null)],
            ),
          );

      var sourceExists = true;
      String? destinationRaw;
      var destinationEtag = '"destination-1"';
      var moves = 0;
      var destinationPatchPuts = 0;
      var destinationGets = 0;
      var token = 0;
      final requests = <String>[];
      addTearDown(() => printOnFailure(requests.join('\n')));
      final client = MockClient((request) async {
        requests.add('${request.method} ${request.url.path} ${request.body}');
        if (request.method == 'OPTIONS') {
          return http.Response(
            '',
            200,
            headers: {'dav': '1, calendar-access, sync-collection'},
          );
        }
        if (request.method == 'PROPFIND') {
          if (request.body.contains('<d:current-user-principal/>')) {
            return _discoveryMultistatus(_currentPrincipalResponse);
          }
          if (request.body.contains('<c:calendar-home-set/>')) {
            return _discoveryMultistatus(_principalPropertiesResponse);
          }
          return _discoveryMultistatus(_twoCollectionInventoryResponse);
        }
        if (request.method == 'REPORT' &&
            request.body.contains('sync-collection')) {
          token += 1;
          if (request.url.path == _collectionHref) {
            return http.Response(
              _syncMemberResponse(
                token: 'source-$token',
                href: sourceHref,
                etag: sourceExists ? '"source-1"' : null,
                deleted: !sourceExists,
              ),
              207,
            );
          }
          if (request.url.path == _destinationCollectionHref) {
            return http.Response(
              _syncMemberResponse(
                token: 'destination-$token',
                href: destinationHref,
                etag: destinationRaw == null ? null : destinationEtag,
              ),
              207,
            );
          }
        }
        if (request.method == 'REPORT' &&
            request.body.contains('calendar-multiget')) {
          if (request.url.path == _collectionHref && sourceExists) {
            return http.Response(
              _multigetMemberResponse(
                href: sourceHref,
                body: sourceRaw,
                etag: '"source-1"',
              ),
              207,
            );
          }
          if (request.url.path == _destinationCollectionHref &&
              destinationRaw != null) {
            return http.Response(
              _multigetMemberResponse(
                href: destinationHref,
                body: destinationRaw!,
                etag: destinationEtag,
              ),
              207,
            );
          }
        }
        if (request.method == 'MOVE') {
          moves += 1;
          expect(request.url.path, sourceHref);
          expect(request.headers['destination'], endsWith(destinationHref));
          expect(request.headers['if-match'], '"source-1"');
          sourceExists = false;
          destinationRaw = sourceRaw;
          return http.Response('', 204);
        }
        if (request.method == 'GET') {
          if (request.url.path == sourceHref && !sourceExists) {
            return http.Response('', 404);
          }
          if (request.url.path == destinationHref && destinationRaw != null) {
            destinationGets += 1;
            if (destinationGets == 2) {
              final synchronizedSource = await (database.select(
                database.davObjects,
              )..where((row) => row.id.equals(sourceObject.id))).getSingle();
              expect(synchronizedSource.serverDeleted, isTrue);
              expect(
                (await database.pendingOpsDao.getOp(operationId))?.id,
                operationId,
              );
            }
            return http.Response(
              destinationRaw!,
              200,
              headers: {
                'etag': destinationEtag,
                'content-type': 'text/calendar',
              },
            );
          }
        }
        if (request.method == 'PUT' && request.url.path == destinationHref) {
          destinationPatchPuts += 1;
          expect(request.headers['if-match'], destinationEtag);
          expect(request.body, isNot(contains('RELATED-TO')));
          if (destinationPatchPuts == 1) {
            return http.Response('Rejected', 415);
          }
          destinationRaw = request.body;
          destinationEtag = '"destination-2"';
          return http.Response('', 204);
        }
        fail('Unexpected ${request.method} ${request.url}');
      });
      var now = _now;
      DavAccountSyncEngine engine() => DavAccountSyncEngine(
        database: database,
        secretStore: secrets,
        httpClient: client,
        accountId: 'account',
        policy: const DavAccountSyncPolicy(
          discoveryMaxAge: Duration(days: 30),
          inventoryMaxAge: Duration(days: 30),
          maximumConcurrentCollections: 1,
        ),
        correlationIdFactory: () => 'partial-move-recovery',
        nowUtc: () => now,
      );

      final failedReplay = await engine().synchronize();
      expect(failedReplay.pendingOperationsApplied, 0);
      final failed = await database.pendingOpsDao.getOp(operationId);
      expect(failed?.state, 'failed');
      expect(failed?.retryClassification, davPartialMoveRetryClassification);
      expect(isDavPartiallyCompletedMove(failed!), isTrue);
      expect(moves, 1);
      expect(destinationPatchPuts, 1);

      now = now.add(const Duration(minutes: 1));
      await PendingOpResolutionService(
        database: database,
        accountId: 'account',
        syncCalendar: () async => fail('A task move must use task sync.'),
        syncTasks: () async {
          await engine().synchronize();
        },
        nowUtc: () => now,
      ).retryNow(operationId);

      expect(moves, 1);
      expect(destinationPatchPuts, 2);
      expect(destinationGets, 3);
      expect(await database.pendingOpsDao.getOp(operationId), null);
      expect(
        (await (database.select(
              database.davObjects,
            )..where((row) => row.id.equals(sourceObject.id))).getSingle())
            .serverDeleted,
        isTrue,
      );
      final destinationObject = await (database.select(
        database.davObjects,
      )..where((row) => row.hrefKey.equals(destinationHref))).getSingle();
      expect(destinationObject.collectionId, 'destination');
      expect(destinationObject.serverDeleted, isFalse);
      final tasks = await database.select(database.tasks).get();
      expect(tasks, hasLength(1));
      expect(tasks.single.davCollectionId, 'destination');
      expect(tasks.single.taskListId, 'dav-task-list-destination');
      expect(tasks.single.title, 'Parented task');
      expect(tasks.single.parentUid, null);
    },
  );

  test(
    'removed collection rebuilds reminders without object-level changes',
    () async {
      const eventId = 'nextcloud-event';
      await database
          .into(database.calendarEvents)
          .insert(
            CalendarEventsCompanion.insert(
              id: eventId,
              accountId: 'account',
              calendarSourceId: 'dav-calendar-collection',
              provider: 'nextcloud',
              providerCalendarId: _collectionHref,
              providerEventId: 'event@example.test',
              title: 'Removed event',
              startDateTime: const Value('2026-08-09T09:00:00.000Z'),
              startTimeZone: const Value('UTC'),
              endDateTime: const Value('2026-08-09T10:00:00.000Z'),
              endTimeZone: const Value('UTC'),
              createdAtLocal: _now.millisecondsSinceEpoch,
              updatedAtLocal: _now.millisecondsSinceEpoch,
            ),
          );
      await database
          .into(database.tasks)
          .insert(
            TasksCompanion.insert(
              accountId: 'account',
              taskListId: 'dav-task-list-collection',
              id: 'nextcloud-task',
              davCollectionId: const Value('collection'),
              title: 'Removed task',
              taskAlarmsJson: const Value(
                '[{"trigger":{"kind":"absolute",'
                '"dateTime":"2026-08-09T08:30:00.000Z"}}]',
              ),
              rawJson: '{}',
              createdLocalAtUtc: _now.toIso8601String(),
              updatedLocalAtUtc: _now.toIso8601String(),
            ),
          );
      await database.batch(
        (batch) => batch.insertAll(database.notificationSchedule, [
          for (final reminder in const [
            (
              id: 'event|nextcloud-event|display:30',
              sourceType: 'event',
              sourceId: eventId,
              title: 'Removed event',
            ),
            (
              id: 'task|account|dav-task-list-collection|nextcloud-task',
              sourceType: 'task',
              sourceId: 'nextcloud-task',
              title: 'Removed task',
            ),
          ])
            NotificationScheduleCompanion.insert(
              id: reminder.id,
              accountId: 'account',
              sourceType: reminder.sourceType,
              sourceId: reminder.sourceId,
              scheduledAtUtc: DateTime.utc(
                2026,
                8,
                9,
                8,
                30,
              ).millisecondsSinceEpoch,
              title: reminder.title,
              createdAtLocal: _now.millisecondsSinceEpoch,
              updatedAtLocal: _now.millisecondsSinceEpoch,
            ),
        ]),
      );
      var requestIndex = 0;
      final client = MockClient((request) async {
        final response = switch (requestIndex) {
          0 => http.Response(
            '',
            200,
            headers: {
              'dav': '1, 3, calendar-access, sync-collection',
              'allow': 'OPTIONS, PROPFIND, REPORT, GET, PUT, DELETE',
            },
          ),
          1 => _discoveryMultistatus(_currentPrincipalResponse),
          2 => _discoveryMultistatus(_principalPropertiesResponse),
          3 => _discoveryMultistatus(_emptyInventoryResponse),
          _ => throw StateError('Unexpected discovery request.'),
        };
        requestIndex += 1;
        return response;
      });
      var rebuildCalls = 0;
      final result = await DavAccountSyncEngine(
        database: database,
        secretStore: secrets,
        httpClient: client,
        accountId: 'account',
        correlationIdFactory: () => 'removed-collection',
        nowUtc: () => _now,
        rebuildNotifications: (accountId, affectedObjectIds) async {
          rebuildCalls += 1;
          expect(accountId, 'account');
          expect(affectedObjectIds, isEmpty);
          await NotificationScheduleService(
            database: database,
            nowUtc: () => _now,
          ).rebuildUpcomingNotifications(accountId);
        },
      ).synchronize(full: true);

      expect(requestIndex, 4);
      expect(result.discoveryRefreshed, isTrue);
      expect(result.affectedObjectIds, isEmpty);
      expect(rebuildCalls, 1);
      expect(
        (await database.select(database.calendarSources).getSingle()).isDeleted,
        isTrue,
      );
      expect(
        (await database.select(database.taskLists).getSingle()).serverMissing,
        isTrue,
      );
      expect(
        await database.select(database.notificationSchedule).get(),
        isEmpty,
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
const _destinationCollectionHref = '/cloud/remote.php/dav/calendars/alex/home/';
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

Future<void> _seedDestination(AppDatabase database) async {
  const now = '2026-08-08T12:00:00.000Z';
  await database
      .into(database.davCollections)
      .insert(
        DavCollectionsCompanion.insert(
          id: 'destination',
          accountId: 'account',
          hrefKey: _destinationCollectionHref,
          requestUri: 'https://cloud.example.test$_destinationCollectionHref',
          displayName: 'Home',
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
      .into(database.taskLists)
      .insert(
        TaskListsCompanion.insert(
          accountId: 'account',
          id: 'dav-task-list-destination',
          davCollectionId: const Value('destination'),
          title: 'Home',
          rawJson: '{}',
          createdLocalAtUtc: now,
          updatedLocalAtUtc: now,
        ),
      );
}

DavPreparedObject _preparedMember({
  required String href,
  required String etag,
  required String body,
}) => DavPreparedObject.parse(
  hrefKey: href,
  requestUri: Uri.parse('https://cloud.example.test$href'),
  etag: etag,
  contentType: 'text/calendar',
  rawIcsBody: body,
  maximumResourceBytes: 1024 * 1024,
);

String _syncMemberResponse({
  required String token,
  required String href,
  String? etag,
  bool deleted = false,
}) =>
    '''<?xml version="1.0" encoding="utf-8"?>
<d:multistatus xmlns:d="DAV:">
  ${deleted
        ? '''<d:response><d:href>$href</d:href>
    <d:status>HTTP/1.1 404 Not Found</d:status></d:response>'''
        : etag == null
        ? ''
        : '''<d:response>
    <d:href>$href</d:href><d:propstat><d:prop><d:getetag>$etag</d:getetag></d:prop>
      <d:status>HTTP/1.1 200 OK</d:status></d:propstat></d:response>'''}
  <d:sync-token>$token</d:sync-token>
</d:multistatus>''';

String _multigetMemberResponse({
  required String href,
  required String body,
  required String etag,
}) =>
    '''<?xml version="1.0" encoding="utf-8"?>
<d:multistatus xmlns:d="DAV:" xmlns:c="urn:ietf:params:xml:ns:caldav">
  <d:response><d:href>$href</d:href><d:propstat><d:prop>
    <d:getetag>$etag</d:getetag>
    <c:calendar-data content-type="text/calendar"><![CDATA[$body]]></c:calendar-data>
  </d:prop><d:status>HTTP/1.1 200 OK</d:status></d:propstat></d:response>
</d:multistatus>''';

String _taskWithParent(String uid, String summary) =>
    '''BEGIN:VCALENDAR\r
VERSION:2.0\r
PRODID:-//BusyMax Test//EN\r
BEGIN:VTODO\r
UID:$uid\r
SUMMARY:$summary\r
RELATED-TO:parent@example.test\r
DUE:20260809T120000Z\r
END:VTODO\r
END:VCALENDAR\r
''';

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

http.Response _discoveryMultistatus(String body) => http.Response(
  body,
  207,
  headers: {'content-type': 'application/xml; charset=utf-8'},
);

const _currentPrincipalResponse = '''<?xml version="1.0"?>
<d:multistatus xmlns:d="DAV:"><d:response>
 <d:href>/cloud/.well-known/caldav</d:href><d:propstat><d:prop>
  <d:current-user-principal><d:href>/cloud/remote.php/dav/principals/users/alex/</d:href></d:current-user-principal>
 </d:prop><d:status>HTTP/1.1 200 OK</d:status></d:propstat>
</d:response></d:multistatus>''';

const _principalPropertiesResponse = '''<?xml version="1.0"?>
<d:multistatus xmlns:d="DAV:" xmlns:c="urn:ietf:params:xml:ns:caldav">
 <d:response><d:href>/cloud/remote.php/dav/principals/users/alex/</d:href>
  <d:propstat><d:prop>
   <c:calendar-home-set><d:href>/cloud/remote.php/dav/calendars/alex/</d:href></c:calendar-home-set>
  </d:prop><d:status>HTTP/1.1 200 OK</d:status></d:propstat>
 </d:response>
</d:multistatus>''';

const _emptyInventoryResponse = '''<?xml version="1.0"?>
<d:multistatus xmlns:d="DAV:" xmlns:c="urn:ietf:params:xml:ns:caldav">
 <d:response><d:href>/cloud/remote.php/dav/calendars/alex/</d:href>
  <d:propstat><d:prop><d:resourcetype><d:collection/></d:resourcetype></d:prop>
  <d:status>HTTP/1.1 200 OK</d:status></d:propstat>
 </d:response>
</d:multistatus>''';

const _twoCollectionInventoryResponse =
    '''<?xml version="1.0"?>
<d:multistatus xmlns:d="DAV:" xmlns:c="urn:ietf:params:xml:ns:caldav">
 <d:response><d:href>$_collectionHref</d:href><d:propstat><d:prop>
  <d:resourcetype><d:collection/><c:calendar/></d:resourcetype>
  <d:displayname>Work</d:displayname>
  <d:current-user-privilege-set><d:privilege><d:read/></d:privilege>
   <d:privilege><d:write/></d:privilege></d:current-user-privilege-set>
  <c:supported-calendar-component-set><c:comp name="VEVENT"/><c:comp name="VTODO"/></c:supported-calendar-component-set>
  <d:supported-report-set><d:supported-report><d:report><d:sync-collection/></d:report></d:supported-report>
   <d:supported-report><d:report><c:calendar-multiget/></d:report></d:supported-report></d:supported-report-set>
 </d:prop><d:status>HTTP/1.1 200 OK</d:status></d:propstat></d:response>
 <d:response><d:href>$_destinationCollectionHref</d:href><d:propstat><d:prop>
  <d:resourcetype><d:collection/><c:calendar/></d:resourcetype>
  <d:displayname>Home</d:displayname>
  <d:current-user-privilege-set><d:privilege><d:read/></d:privilege>
   <d:privilege><d:write/></d:privilege></d:current-user-privilege-set>
  <c:supported-calendar-component-set><c:comp name="VEVENT"/><c:comp name="VTODO"/></c:supported-calendar-component-set>
  <d:supported-report-set><d:supported-report><d:report><d:sync-collection/></d:report></d:supported-report>
   <d:supported-report><d:report><c:calendar-multiget/></d:report></d:supported-report></d:supported-report-set>
 </d:prop><d:status>HTTP/1.1 200 OK</d:status></d:propstat></d:response>
</d:multistatus>''';

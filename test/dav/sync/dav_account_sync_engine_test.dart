import 'package:busymax/src/dav/mutation/dav_collection_administration.dart';
import 'package:busymax/src/app/app_bootstrap.dart';
import 'package:busymax/src/features/connectivity/network_connectivity_service.dart';
import 'package:busymax/src/features/notifications/notification_reconciler.dart';
import 'package:busymax/src/core/http/request_dispatch_exception.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:busymax/src/dav/discovery/dav_discovery_models.dart';

import 'dart:convert';
import 'dart:io';

import 'package:busymax/src/core/secrets/secret_store.dart';
import 'package:busymax/src/dav/dav_errors.dart';
import 'package:busymax/src/dav/dav_provider_profile.dart';
import 'package:busymax/src/dav/ical/ical_document.dart';
import 'package:busymax/src/dav/mutation/dav_conflict_repository.dart';
import 'package:busymax/src/dav/mutation/dav_conditional_mutation_service.dart';
import 'package:busymax/src/dav/mutation/dav_mutation_patch.dart';
import 'package:busymax/src/dav/mutation/dav_pending_operations.dart';
import 'package:busymax/src/dav/storage/dav_object_repository.dart';
import 'package:busymax/src/dav/sync/dav_account_sync_engine.dart';
import 'package:busymax/src/db/app_database.dart';
import 'package:busymax/src/features/notifications/notification_schedule_service.dart';
import 'package:busymax/src/features/notifications/desktop_notification_service.dart';
import 'package:busymax/src/features/notifications/notification_scheduler.dart';
import 'package:busymax/src/features/calendar/data/calendar_repository.dart';
import 'package:busymax/src/features/calendar/presentation/event_editor_draft.dart';
import 'package:busymax/src/features/sync/pending_op_resolution_service.dart';
import 'package:busymax/src/features/tasks/data/tasks_repository.dart';
import 'package:busymax/src/providers/busy_provider.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../../support/persistence_test_directory.dart';

void main() {
  late AppDatabase database;
  late InMemorySecretStore secrets;
  Directory? applicationDirectory;

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    secrets = InMemorySecretStore();
    await _seed(database, secrets);
  });

  tearDown(() async {
    await database.close();
    await applicationDirectory?.delete(recursive: true);
    applicationDirectory = null;
  });

  for (final provider in [BusyProvider.caldav, BusyProvider.nextcloud]) {
    for (final status in [403, 401]) {
      test(
        '$provider collection read $status isolates permissions but stops rejected credentials',
        () async {
          if (provider == BusyProvider.caldav) {
            await database
                .update(database.accounts)
                .write(
                  const AccountsCompanion(
                    provider: Value('caldav'),
                    credentialKind: Value('caldav_password'),
                  ),
                );
            await secrets.saveCredential(
              'account',
              CalDavSecretRecord(
                serviceAuthority: Uri.parse('https://cloud.example.test/cloud'),
                username: 'alex',
                password: 'password',
              ),
            );
          }
          await _seedDestination(database);
          var sequence = 0, writes = 0, token = 0;
          final bodies = <String, String>{};
          final queue = DavPendingOperationQueue(
            database: database,
            idFactory: () => 'scoped-${++sequence}',
            nowUtc: () => _now,
          );
          Future<String> create(String collection, String uid) =>
              queue.enqueueCreate(
                accountId: 'account',
                collectionId: collection,
                object: DavNewObject(
                  uid: uid,
                  initialMemberName: '$uid.ics',
                  rawIcs: _event(uid)
                      .replaceFirst('UID:event@example.test', 'UID:$uid'),
                  componentType: 'VEVENT',
                ),
              );
          final denied = await create('collection', 'denied');
          await create('destination', 'allowed');
          final original = await database.pendingOpsDao.getOp(denied);
          final client = MockClient((request) async {
            if (request.method == 'OPTIONS') {
              return http.Response(
                '',
                200,
                headers: {'dav': 'calendar-access, sync-collection'},
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
              if (request.url.path == _collectionHref) {
                return http.Response('', status);
              }
              final href =
                  bodies.keys.firstOrNull ??
                  '${_destinationCollectionHref}empty.ics';
              return http.Response(
                _syncMemberResponse(
                  token: 'urn:scoped:${++token}',
                  href: href,
                  etag: bodies.isEmpty ? null : '"created"',
                ),
                207,
              );
            }
            if (request.method == 'REPORT' &&
                request.body.contains('calendar-multiget')) {
              final href = bodies.keys.single;
              return http.Response(
                _multigetMemberResponse(
                  href: href,
                  body: bodies[href]!,
                  etag: '"created"',
                ),
                207,
              );
            }
            if (request.method == 'PUT') {
              expect(request.url.path, startsWith(_destinationCollectionHref));
              writes++;
              bodies[request.url.path] = request.body;
              return http.Response('', 201, headers: {'etag': '"created"'});
            }
            if (request.method == 'GET') {
              return http.Response(
                bodies[request.url.path]!,
                200,
                headers: {'etag': '"created"'},
              );
            }
            throw StateError('Unexpected ${request.method} ${request.url}');
          });
          addTearDown(client.close);
          await expectLater(
            DavAccountSyncEngine(
              database: database,
              secretStore: secrets,
              httpClient: client,
              accountId: 'account',
              nowUtc: () => _now,
            ).synchronize(full: true),
            throwsA(isA<DavAccountSyncException>()),
          );
          expect(writes, status == 403 ? 1 : 0);
          expect(await database.pendingOpsDao.getOp(denied), original);
          expect(
            await database.select(database.pendingOps).get(),
            hasLength(status == 403 ? 1 : 2),
          );
          final cursor = await DavObjectRepository(database: database)
              .cursor('collection');
          expect(cursor!.lastFailureCode, isNotNull);
          if (status == 403) {
            expect(
              (await database.select(database.davAccountServices).getSingle())
                  .lastDiscoveryErrorCode,
              isNull,
            );
            expect(
              (await DavObjectRepository(database: database)
                      .cursor('destination'))!
                  .lastFailureCode,
              isNull,
            );
          }
        },
      );
    }
  }

  test('blocked permission prompts ordinary discovery and preserves independent writes', () async {
    await database
        .update(database.accounts)
        .write(
          const AccountsCompanion(
            provider: Value('caldav'),
            credentialKind: Value('caldav_password'),
          ),
        );
    await database
        .update(database.calendarSources)
        .write(const CalendarSourcesCompanion(provider: Value('caldav')));
    await secrets.saveCredential(
      'account',
      CalDavSecretRecord(
        serviceAuthority: Uri.parse('https://cloud.example.test/cloud'),
        username: 'alex',
        password: 'password',
      ),
    );
    var restricted = false;
    var discoveries = 0;
    var writes = 0;
    var token = 0;
    String? remoteBody;
    String? remoteHref;
    final client = MockClient((request) async {
      if (request.method == 'OPTIONS') {
        return http.Response(
          '',
          200,
          headers: {'dav': '1, calendar-access, sync-collection'},
        );
      }
      if (request.method == 'PROPFIND') {
        if (request.body.contains('<d:current-user-principal/>')) {
          discoveries++;
          return _discoveryMultistatus(_currentPrincipalResponse);
        }
        if (request.body.contains('<c:calendar-home-set/>')) {
          return _discoveryMultistatus(_principalPropertiesResponse);
        }
        return _discoveryMultistatus(
          restricted
              ? _twoCollectionInventoryResponse.replaceFirst(
                  '<d:privilege><d:write/></d:privilege>',
                  '',
                )
              : _twoCollectionInventoryResponse,
        );
      }
      if (request.method == 'REPORT' &&
          request.body.contains('sync-collection')) {
        return http.Response(
          _syncMemberResponse(
            token: 'urn:isolated:${++token}',
            href: remoteHref ?? '${_destinationCollectionHref}empty.ics',
            etag:
                request.url.path == _destinationCollectionHref &&
                    remoteBody != null
                ? '"created"'
                : null,
          ),
          207,
        );
      }
      if (request.method == 'REPORT' &&
          request.body.contains('calendar-multiget')) {
        return http.Response(
          _multigetMemberResponse(
            href: remoteHref!,
            body: remoteBody!,
            etag: '"created"',
          ),
          207,
        );
      }
      if (request.method == 'PUT') {
        expect(request.url.path, startsWith(_destinationCollectionHref));
        writes++;
        remoteHref = request.url.path;
        remoteBody = request.body;
        return http.Response('', 201, headers: {'etag': '"created"'});
      }
      if (request.method == 'GET') {
        return http.Response(
          remoteBody!,
          200,
          headers: {'etag': '"created"', 'content-type': 'text/calendar'},
        );
      }
      fail('Unexpected ${request.method} ${request.url}');
    });
    addTearDown(client.close);
    final engine = DavAccountSyncEngine(
      database: database,
      secretStore: secrets,
      httpClient: client,
      accountId: 'account',
      nowUtc: () => _now,
    );
    await engine.synchronize(full: true);
    final collections = await database.select(database.davCollections).get();
    final source = collections.singleWhere((c) => c.hrefKey == _collectionHref);
    final destination = collections.singleWhere(
      (c) => c.hrefKey == _destinationCollectionHref,
    );
    var sequence = 0;
    final queue = DavPendingOperationQueue(
      database: database,
      idFactory: () => 'op-${++sequence}',
      nowUtc: () => _now,
    );
    Future<String> create(String collection, String uid) => queue.enqueueCreate(
      accountId: 'account',
      collectionId: collection,
      object: DavNewObject(
        uid: uid,
        initialMemberName: '$uid.ics',
        rawIcs: _event(uid).replaceFirst('UID:event@example.test', 'UID:$uid'),
        componentType: 'VEVENT',
      ),
    );
    await create(source.id, 'denied');
    await database
        .update(database.pendingOps)
        .write(
          const PendingOpsCompanion(
            state: Value('permission_blocked'),
            retryClassification: Value('permission'),
          ),
        );
    await database
        .update(database.accounts)
        .write(const AccountsCompanion(authState: Value('permission_changed')));
    final blocked = await database.select(database.pendingOps).getSingle();
    restricted = true;
    await create(destination.id, 'allowed');
    expect((await engine.synchronize()).pendingOperationsApplied, 1);
    expect(writes, 1);
    expect(await database.select(database.pendingOps).getSingle(), blocked);
    expect(
      (await database.select(database.accounts).getSingle()).authState,
      'permission_changed',
    );
    final before = discoveries;
    // Only the blocked operation remains and the cached inventory is fresh.
    await engine.synchronize();
    expect(discoveries, greaterThan(before));
    expect(writes, 1);
    expect(await database.select(database.pendingOps).getSingle(), blocked);
    expect(
      (await database.select(database.accounts).getSingle()).authState,
      'permission_changed',
    );
  });

  for (final failure in [
    'bind',
    'unsupported',
    'http403',
    'transient',
    'authentication',
  ]) {
    for (final throughApplication in [false, true]) {
      test(
        'collection creation $failure does not mask ordinary event/task synchronization; production=$throughApplication',
        () async {
          if (throughApplication) {
            applicationDirectory = await createPersistenceTestDirectory(
              'busymax-creation-feedback-',
            );
            await database.close();
            database = AppDatabase(
              NativeDatabase(File('${applicationDirectory!.path}/app.sqlite')),
            );
            await _seed(database, secrets);
          }
          await database
              .update(database.accounts)
              .write(
                const AccountsCompanion(
                  provider: Value('caldav'),
                  credentialKind: Value('caldav_password'),
                ),
              );
          await database
              .update(database.calendarSources)
              .write(const CalendarSourcesCompanion(provider: Value('caldav')));
          await secrets.saveCredential(
            'account',
            CalDavSecretRecord(
              serviceAuthority: Uri.parse('https://cloud.example.test/cloud'),
              username: 'alex',
              password: 'synthetic',
            ),
          );
          const operationId = 'fe56ed0d-c620-4134-9a79-560da6aee085';
          const home =
              'https://cloud.example.test/cloud/remote.php/dav/calendars/alex/';
          const target = '${home}busymax-$operationId/';
          await database
              .into(database.davCollectionCreations)
              .insert(
                DavCollectionCreationsCompanion.insert(
                  id: operationId,
                  accountId: 'account',
                  authority: 'https://cloud.example.test/cloud',
                  homeUri: home,
                  targetUri: target,
                  displayName: 'Pending',
                  componentsJson: '["VEVENT"]',
                  createdAtUtc: 'now',
                ),
              );
          if (throughApplication) {
            // Reopen the prepared operation before using the real application route.
            await database.close();
            database = AppDatabase(
              NativeDatabase(File('${applicationDirectory!.path}/app.sqlite')),
            );
          }
          var rounds = 0, writes = 0;
          final client = MockClient((request) async {
            final administration =
                (request.headers['x-busymax-correlation-id'] ?? '').startsWith(
                  'collection-',
                );
            if (request.method == 'OPTIONS') {
              if (administration && failure == 'transient') {
                return http.Response('', 503, headers: {'retry-after': '0'});
              }
              if (administration && failure == 'authentication') {
                return http.Response('', 401);
              }
              return http.Response(
                '',
                200,
                headers: {
                  'dav': administration && failure == 'unsupported'
                      ? '1'
                      : '1, calendar-access, sync-collection',
                  'allow': administration && failure == 'unsupported'
                      ? 'GET, PROPFIND'
                      : 'GET, PROPFIND, REPORT, MKCALENDAR',
                },
              );
            }
            if (request.method == 'PROPFIND') {
              if (request.url.toString() == target) {
                return http.Response('', 404);
              }
              if (request.body.contains('<d:current-user-principal/>')) {
                return _discoveryMultistatus(
                  _currentPrincipalResponse.replaceFirst(
                    '/cloud/.well-known/caldav',
                    request.url.path,
                  ),
                );
              }
              if (request.body.contains('<c:calendar-home-set/>')) {
                return _discoveryMultistatus(_principalPropertiesResponse);
              }
              if (request.url.toString() == home &&
                  request.headers['depth'] == '0') {
                return _discoveryMultistatus(
                  '<d:multistatus xmlns:d="DAV:"><d:response><d:href>$home</d:href><d:propstat><d:prop><d:resourcetype><d:collection/></d:resourcetype><d:current-user-privilege-set><d:privilege><d:${failure == 'bind' ? 'read' : 'bind'}/></d:privilege></d:current-user-privilege-set></d:prop><d:status>HTTP/1.1 200 OK</d:status></d:propstat></d:response></d:multistatus>',
                );
              }
              return _discoveryMultistatus(_singleCollectionInventoryResponse);
            }
            if (request.method == 'MKCALENDAR') {
              writes++;
              expect(failure, 'http403');
              return http.Response('', 403);
            }
            const todoHref = '${_collectionHref}task.ics';
            if (request.method == 'REPORT' &&
                request.body.contains('sync-collection')) {
              rounds++;
              String member(String href) =>
                  '<d:response><d:href>$href</d:href><d:propstat><d:prop><d:getetag>"v$rounds"</d:getetag></d:prop><d:status>HTTP/1.1 200 OK</d:status></d:propstat></d:response>';
              return _discoveryMultistatus(
                '<d:multistatus xmlns:d="DAV:">${member(_eventHref)}${member(todoHref)}<d:sync-token>urn:test:round-$rounds</d:sync-token></d:multistatus>',
              );
            }
            if (request.method == 'REPORT') {
              String member(String href, String body) =>
                  '<d:response><d:href>$href</d:href><d:propstat><d:prop><d:getetag>"v$rounds"</d:getetag><c:calendar-data><![CDATA[$body]]></c:calendar-data></d:prop><d:status>HTTP/1.1 200 OK</d:status></d:propstat></d:response>';
              final todo =
                  'BEGIN:VCALENDAR\r\nVERSION:2.0\r\nBEGIN:VTODO\r\nUID:task@example.test\r\nSUMMARY:Task $rounds\r\nEND:VTODO\r\nEND:VCALENDAR\r\n';
              return _discoveryMultistatus(
                '<d:multistatus xmlns:d="DAV:" xmlns:c="urn:ietf:params:xml:ns:caldav">${member(_eventHref, _event('Event $rounds'))}${member(todoHref, todo)}</d:multistatus>',
              );
            }
            throw StateError('Unexpected ${request.method} ${request.url}');
          });
          addTearDown(client.close);
          final engine = DavAccountSyncEngine(
            database: database,
            secretStore: secrets,
            httpClient: client,
            accountId: 'account',
            nowUtc: () => _now,
          );
          ProviderContainer application() => ProviderContainer(
            overrides: [
              databaseProvider.overrideWithValue(database),
              secretStoreProvider.overrideWithValue(secrets),
              baseHttpClientProvider.overrideWithValue(client),
              davAccountHttpClientProvider('account').overrideWithValue(client),
              networkConnectivityMonitorProvider.overrideWith((ref) {
                final monitor =
                    NetworkConnectivityMonitor.withoutPlatformObservation();
                ref.onDispose(monitor.dispose);
                return monitor;
              }),
              notificationReconcilerProvider.overrideWithValue(
                CallbackNotificationReconciler(() async {}),
              ),
            ],
          );
          ProviderContainer? container = throughApplication
              ? application()
              : null;
          addTearDown(() => container?.dispose());
          Future<void> runApplicationSync() => container!
              .read(accountSyncOperationsProvider)
              .syncAccount('account', full: false);
          if (failure == 'authentication') {
            await expectLater(
              throughApplication ? runApplicationSync() : engine.synchronize(),
              throwsA(
                predicate((error) {
                  final effective = resolveEffectiveSyncFailure(error!);
                  return effective is DavException &&
                      effective.kind == DavErrorKind.authentication;
                }),
              ),
            );
            expect(rounds, 0);
            expect(
              (await database
                      .select(database.davCollectionCreations)
                      .getSingle())
                  .state,
              'prepared',
            );
            expect(
              (await database.select(database.accounts).getSingle()).authState,
              'reauth_required',
            );
            return;
          }
          for (var iteration = 1; iteration <= 3; iteration++) {
            if (throughApplication) {
              await runApplicationSync();
              final activity = container!.read(accountSyncActivityProvider);
              expect(activity.failure('account', 'dav'), isNull);
              expect(activity.isRunning('account', 'dav'), isFalse);
              final notice = activity
                  .collectionCreationFailures('account')
                  .values
                  .single;
              expect(notice.operation.id, operationId);
              expect(notice.operation.displayName, 'Pending');
              expect(notice.pending, failure == 'transient');
              expect(
                notice.error.statusCode,
                failure == 'unsupported'
                    ? 405
                    : failure == 'transient'
                    ? 503
                    : 403,
              );
              expect(
                activity.collectionCreationFailures('other-account'),
                isEmpty,
              );
            } else {
              final result = await engine.synchronize();
              expect(result.collectionsSynchronized, 1);
              expect(
                result.collectionCreationFailures.length,
                failure == 'transient' || iteration == 1 ? 1 : 0,
              );
            }
            expect(
              (await database.select(database.calendarEvents).getSingle())
                  .title,
              'Event $iteration',
            );
            expect(
              (await database.select(database.tasks).getSingle()).title,
              'Task $iteration',
            );
            expect(
              (await database.select(database.davObjects).get())
                  .map((o) => o.etag)
                  .toSet(),
              {'"v$iteration"'},
            );
            expect(
              (await database.select(database.accounts).getSingle()).authState,
              'signed_in',
            );
            expect(
              (await database.select(database.syncCursors).getSingle())
                  .cursorValue,
              'urn:test:round-$iteration',
            );
            if (throughApplication && iteration == 1) {
              // Terminal rejections leave the recovery queue, but their feedback
              // must survive another process and another successful pull.
              container!.dispose();
              await database.close();
              database = AppDatabase(
                NativeDatabase(
                  File('${applicationDirectory!.path}/app.sqlite'),
                ),
              );
              container = application();
              expect(
                container
                    .read(accountSyncActivityProvider)
                    .collectionCreationFailures('account'),
                isEmpty,
              );
            }
          }
          final row = await database
              .select(database.davCollectionCreations)
              .getSingle();
          expect(row.state, failure == 'transient' ? 'prepared' : 'rejected');
          expect(row.lastErrorCode, isNotNull);
          expect(writes, failure == 'http403' ? 1 : 0);
        },
      );
    }
  }
  for (final component in ['VEVENT', 'VTODO']) {
    test(
      'rejection, successful $component retry, acknowledgment and production restart preserve the journal',
      () async {
        applicationDirectory = await createPersistenceTestDirectory(
          'busymax-notice-lifecycle-',
        );
        final file = File('${applicationDirectory!.path}/app.sqlite');
        await database.close();
        database = AppDatabase(NativeDatabase(file));
        await _seed(database, secrets);
        await database
            .update(database.accounts)
            .write(
              const AccountsCompanion(
                provider: Value('caldav'),
                credentialKind: Value('caldav_password'),
              ),
            );
        await database
            .update(database.calendarSources)
            .write(const CalendarSourcesCompanion(provider: Value('caldav')));
        await secrets.saveCredential(
          'account',
          CalDavSecretRecord(
            serviceAuthority: Uri.parse('https://cloud.example.test/cloud'),
            username: 'alex',
            password: 'synthetic',
          ),
        );
        final wire = _NoticeLifecycleWire(component);
        final client = MockClient(wire.handle);
        addTearDown(client.close);
        await database
            .into(database.davCollectionCreations)
            .insert(
              DavCollectionCreationsCompanion.insert(
                id: _NoticeLifecycleWire.operationA,
                accountId: 'account',
                authority: 'https://cloud.example.test/cloud',
                homeUri: _NoticeLifecycleWire.home,
                targetUri: _NoticeLifecycleWire.targetA,
                displayName: 'Recovered collection',
                componentsJson: '["$component"]',
                createdAtUtc: 'now',
              ),
            );
        await database.close();
        database = AppDatabase(NativeDatabase(file));
        ProviderContainer application() => ProviderContainer(
          overrides: [
            databaseProvider.overrideWithValue(database),
            secretStoreProvider.overrideWithValue(secrets),
            baseHttpClientProvider.overrideWithValue(client),
            davAccountHttpClientProvider('account').overrideWithValue(client),
            networkConnectivityMonitorProvider.overrideWith((ref) {
              final monitor =
                  NetworkConnectivityMonitor.withoutPlatformObservation();
              ref.onDispose(monitor.dispose);
              return monitor;
            }),
            notificationReconcilerProvider.overrideWithValue(
              CallbackNotificationReconciler(() async {}),
            ),
          ],
        );
        var container = application();
        addTearDown(() => container.dispose());
        Future<void> sync() => container
            .read(accountSyncOperationsProvider)
            .syncAccount('account', full: true);
        await sync();
        final rejected =
            await (database.select(database.davCollectionCreations)
                  ..where((r) => r.id.equals(_NoticeLifecycleWire.operationA)))
                .getSingle();
        expect(rejected.state, 'rejected');
        expect(rejected.lastErrorStatus, 403);
        expect(
          container
              .read(accountSyncActivityProvider)
              .collectionCreationFailures('account')
              .keys,
          [_NoticeLifecycleWire.operationA],
        );
        expect(wire.creationCalls, 0);
        wire.bindAllowed = true;
        await sync(); // Revalidate the repaired permissions without changing A.
        expect(
          await DavCollectionAdministration(
            database: database,
            secrets: secrets,
            client: client,
            accountId: 'account',
            creationIdFactory: () => _NoticeLifecycleWire.operationB,
            refresh: () async {},
            requireNetwork: () async {},
          ).create('Recovered collection', {component}),
          DavCollectionAdministrationOutcome.committed,
        );
        expect(wire.created, isTrue);
        expect(wire.creationCalls, 1);
        await sync();
        final journalBefore = {
          for (final row
              in await database.select(database.davCollectionCreations).get())
            row.id: row.toJson(),
        };
        expect(
          journalBefore[_NoticeLifecycleWire.operationB]!['state'],
          'committed',
        );
        expect(
          journalBefore[_NoticeLifecycleWire.operationA],
          rejected.toJson(),
        );
        // The matching name is not operation identity: B cannot silently rewrite A.
        expect(
          container
              .read(accountSyncActivityProvider)
              .collectionCreationFailures('account')
              .keys,
          [_NoticeLifecycleWire.operationA],
        );
        expect(
          await container.read(acknowledgeDavCollectionCreationNoticeProvider)(
            'account',
            _NoticeLifecycleWire.operationA,
          ),
          isTrue,
        );
        expect(
          container
              .read(accountSyncActivityProvider)
              .collectionCreationFailures('account'),
          isEmpty,
        );
        expect(
          container.read(accountSyncActivityProvider).failure('account', 'dav'),
          isNull,
        );
        expect(
          (await database
                  .select(database.davCollectionCreationAcknowledgments)
                  .getSingle())
              .operationId,
          _NoticeLifecycleWire.operationA,
        );
        await sync();
        container.dispose();
        await database.close();
        database = AppDatabase(NativeDatabase(file));
        container = application();
        await sync();
        expect(
          container
              .read(accountSyncActivityProvider)
              .collectionCreationFailures('account'),
          isEmpty,
        );
        expect(
          container.read(accountSyncActivityProvider).failure('account', 'dav'),
          isNull,
        );
        expect({
          for (final row
              in await database.select(database.davCollectionCreations).get())
            row.id: row.toJson(),
        }, journalBefore);
        expect(wire.creationCalls, 1);
        expect(
          (await database.select(database.calendarEvents).get()).any(
            (e) => e.title == 'Existing event',
          ),
          isTrue,
        );
        expect(
          (await database.select(database.tasks).get()).any(
            (t) => t.title == 'Existing task',
          ),
          isTrue,
        );
        expect(
          (await database.select(database.accounts).getSingle()).authState,
          'signed_in',
        );
      },
    );
  }
  for (final status in [401, 403]) {
    test(
      'generic pending work refreshes discovery before replay after HTTP $status',
      () async {
        await database
            .update(database.accounts)
            .write(
              const AccountsCompanion(
                provider: Value('caldav'),
                credentialKind: Value('caldav_password'),
              ),
            );
        await database
            .update(database.calendarSources)
            .write(const CalendarSourcesCompanion(provider: Value('caldav')));
        await secrets.saveCredential(
          'account',
          CalDavSecretRecord(
            serviceAuthority: Uri.parse('https://cloud.example.test/cloud'),
            username: 'alex',
            password: 'password',
          ),
        );
        await TasksRepository(
          database: database,
          accountId: 'account',
        ).createTask(
          'dav-task-list-collection',
          const TaskCreateInput(title: 'Must remain queued'),
        );
        final pending = await database.select(database.pendingOps).getSingle();
        final tasks = await database.select(database.tasks).get();
        final requests = <http.Request>[];
        final client = MockClient((request) async {
          requests.add(request);
          return http.Response('', status);
        });
        addTearDown(client.close);
        await expectLater(
          DavAccountSyncEngine(
            database: database,
            secretStore: secrets,
            httpClient: client,
            accountId: 'account',
            nowUtc: () => _now,
          ).synchronize(),
          throwsA(
            isA<DavException>().having(
              (e) => e.kind,
              'kind',
              status == 401
                  ? DavErrorKind.authentication
                  : DavErrorKind.authorization,
            ),
          ),
        );
        expect(requests, isNotEmpty);
        expect(requests.every((r) => r.method == 'PROPFIND'), isTrue);
        expect(await database.select(database.pendingOps).getSingle(), pending);
        expect(await database.select(database.tasks).get(), tasks);
        expect(
          await database.select(database.davCollections).get(),
          hasLength(1),
        );
      },
    );
  }

  test('account sequence syncs, conditionally replays, follows up, then pauses on 401', () async {
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
            _syncResponse(token: 'urn:test:token-1', etag: serverEtag),
            207,
          );
        }
        if (syncReports == 2) {
          expect(
            request.body,
            contains('<d:sync-token>urn:test:token-1</d:sync-token>'),
          );
          return http.Response(_syncResponse(token: 'urn:test:token-2'), 207);
        }
        expect(
          request.body,
          contains('<d:sync-token>urn:test:token-2</d:sync-token>'),
        );
        return http.Response(
          _syncResponse(token: 'urn:test:token-3', etag: serverEtag),
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
      'urn:test:token-3',
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
  });

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
    'Keep server reprojects a cached event conflict before unchanged sync',
    () async {
      final initialStart = DateTime.utc(2026, 8, 9, 9);
      final remoteStart = DateTime.utc(2026, 8, 9, 10);
      final server = _ConflictSyncServer(
        href: _eventHref,
        body: _eventWithReminder('Server title', startUtc: initialStart),
        etag: '"v1"',
      );
      final client = MockClient(server.handle);
      addTearDown(client.close);

      Future<void> rebuild(String accountId, Set<String> objectIds) async {
        expect(accountId, 'account');
        await NotificationScheduleService(
          database: database,
          nowUtc: () => _now,
        ).rebuildUpcomingNotifications(accountId);
      }

      DavAccountSyncEngine engine() => _conflictSyncEngine(
        database: database,
        secrets: secrets,
        client: client,
        rebuildNotifications: rebuild,
      );

      await engine().synchronize();
      final repository = CalendarRepository(
        database: database,
        now: () => _now,
        localTimeZone: 'UTC',
      );
      final initial = await database
          .select(database.calendarEvents)
          .getSingle();
      final detail = await repository.loadEventDetail(initial.id);
      await repository.updateLocalEvent(
        EventEditorDraft.fromEventDetail(detail!)
            .copyWith(title: 'Local title'),
      );
      expect(
        (await database.select(database.calendarEvents).getSingle()).title,
        'Local title',
      );

      server.setRemote(
        _eventWithReminder('Remote title', startUtc: remoteStart),
        '"v2"',
      );
      final conflicted = await engine().synchronize();
      expect(conflicted.conflictsCreated, 1);
      final object = await database.select(database.davObjects).getSingle();
      expect(object.rawIcsBody, contains('SUMMARY:Remote title'));
      final projectedLocal = await database
          .select(database.calendarEvents)
          .getSingle();
      expect(projectedLocal.title, 'Local title');
      expect(projectedLocal.syncStatus, 'pending');

      final conflict = await DavConflictRepository(database: database)
          .watchUnresolved()
          .first;
      final rebuiltObjects = <String>{};
      await DavConflictResolutionService(
        database: database,
        rebuildNotifications: (accountId, objectIds) async {
          rebuiltObjects.addAll(objectIds);
          await rebuild(accountId, objectIds);
        },
        nowUtc: () => _now,
      ).resolve(conflict.single.id, DavConflictResolution.keepServer);

      expect(rebuiltObjects, {object.id});
      expect(await database.select(database.pendingOps).get(), isEmpty);
      final accepted = await database
          .select(database.calendarEvents)
          .getSingle();
      expect(accepted.title, 'Remote title');
      expect(accepted.startDateTime, remoteStart.toIso8601String());
      expect(accepted.syncStatus, 'synced');
      final reminder = await database
          .select(database.notificationSchedule)
          .getSingle();
      expect(reminder.title, 'Remote title');
      expect(
        reminder.scheduledAtUtc,
        remoteStart
            .subtract(const Duration(minutes: 30))
            .millisecondsSinceEpoch,
      );

      await engine().synchronize();
      final afterUnchangedSync = await database
          .select(database.calendarEvents)
          .getSingle();
      expect(afterUnchangedSync.title, 'Remote title');
      expect(afterUnchangedSync.syncStatus, 'synced');
      expect(server.puts, 1);
    },
  );

  test(
    'Keep server reprojects a cached task conflict before unchanged sync',
    () async {
      final initialDue = DateTime.utc(2026, 8, 9, 12);
      final remoteDue = DateTime.utc(2026, 8, 9, 14);
      final server = _ConflictSyncServer(
        href: _eventHref,
        body: _taskWithReminder('Server task', dueUtc: initialDue),
        etag: '"v1"',
      );
      final client = MockClient(server.handle);
      addTearDown(client.close);

      Future<void> rebuild(String accountId, Set<String> objectIds) async {
        expect(accountId, 'account');
        await NotificationScheduleService(
          database: database,
          nowUtc: () => _now,
        ).rebuildUpcomingNotifications(accountId);
      }

      DavAccountSyncEngine engine() => _conflictSyncEngine(
        database: database,
        secrets: secrets,
        client: client,
        rebuildNotifications: rebuild,
      );

      await engine().synchronize();
      final initialTasks = await database.select(database.tasks).get();
      expect(initialTasks, hasLength(1));
      final initial = initialTasks.single;
      await TasksRepository(
        database: database,
        accountId: 'account',
        nowUtc: () => _now,
      ).updateTaskFull(
        'dav-task-list-collection',
        initial.id,
        const TaskPutInput({'title': 'Local task'}),
      );
      expect(
        (await database.select(database.tasks).getSingle()).title,
        'Local task',
      );

      server.setRemote(
        _taskWithReminder('Remote task', dueUtc: remoteDue),
        '"v2"',
      );
      final conflicted = await engine().synchronize();
      expect(conflicted.conflictsCreated, 1);
      final object = await database.select(database.davObjects).getSingle();
      expect(object.rawIcsBody, contains('SUMMARY:Remote task'));
      final projectedLocal = await database.select(database.tasks).getSingle();
      expect(projectedLocal.title, 'Local task');
      expect(projectedLocal.localDirty, isTrue);

      final conflict = await DavConflictRepository(database: database)
          .watchUnresolved()
          .first;
      final rebuiltObjects = <String>{};
      await DavConflictResolutionService(
        database: database,
        rebuildNotifications: (accountId, objectIds) async {
          rebuiltObjects.addAll(objectIds);
          await rebuild(accountId, objectIds);
        },
        nowUtc: () => _now,
      ).resolve(conflict.single.id, DavConflictResolution.keepServer);

      expect(rebuiltObjects, {object.id});
      expect(await database.select(database.pendingOps).get(), isEmpty);
      final accepted = await database.select(database.tasks).getSingle();
      expect(accepted.title, 'Remote task');
      expect(accepted.dueUtc, remoteDue.toIso8601String());
      expect(accepted.localDirty, isFalse);
      expect(accepted.pendingDelete, isFalse);
      expect(accepted.pendingMove, isFalse);
      final reminders = await database
          .select(database.notificationSchedule)
          .get();
      expect(reminders, hasLength(1));
      final reminder = reminders.single;
      expect(reminder.title, 'Remote task');
      expect(
        reminder.scheduledAtUtc,
        remoteDue.subtract(const Duration(minutes: 30)).millisecondsSinceEpoch,
      );

      await engine().synchronize();
      final afterUnchangedSync = await database
          .select(database.tasks)
          .getSingle();
      expect(afterUnchangedSync.title, 'Remote task');
      expect(afterUnchangedSync.localDirty, isFalse);
      expect(server.puts, 1);
    },
  );

  test('Diagnostics retry completes a remotely moved task after source sync deletion', () async {
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
              token: 'urn:test:source-$token',
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
              token: 'urn:test:destination-$token',
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
            headers: {'etag': destinationEtag, 'content-type': 'text/calendar'},
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
  });

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
        if (request.method == 'OPTIONS' && requestIndex > 0) {
          return http.Response('', 200, headers: {'dav': 'calendar-access'});
        }
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

  test('temporary DAV failure keeps cached reminders and recovery rebuilds after reconnect', () async {
    var clock = DateTime.utc(2026, 8, 8, 12);
    final initialBody = _eventWithReminder(
      'Cached appointment',
      startUtc: DateTime.utc(2026, 8, 9, 9),
    );
    final repository = DavObjectRepository(
      database: database,
      idFactory: () => 'reminder-object',
    );
    await repository.commitConfirmedMutation(
      accountId: 'account',
      collectionId: 'collection',
      provider: BusyProvider.nextcloud,
      canonicalObject: _preparedMember(
        href: _eventHref,
        etag: '"reminder-1"',
        body: initialBody,
      ),
      completedAtUtc: clock,
    );
    final scheduleService = NotificationScheduleService(
      database: database,
      nowUtc: () => clock,
    );
    await scheduleService.rebuildUpcomingNotifications('account');
    var scheduled = await database
        .select(database.notificationSchedule)
        .getSingle();
    expect(
      scheduled.scheduledAtUtc,
      DateTime.utc(2026, 8, 9, 8, 30).millisecondsSinceEpoch,
    );

    await expectLater(
      DavAccountSyncEngine(
        database: database,
        secretStore: _UnavailableSecretStore(),
        httpClient: MockClient((_) async => http.Response('', 500)),
        accountId: 'account',
        nowUtc: () => clock,
      ).synchronize(),
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
    expect(
      await database.select(database.notificationSchedule).get(),
      hasLength(1),
    );

    clock = DateTime.utc(2026, 8, 9, 8, 30);
    final notificationBackend = _ReminderRecordingBackend();
    final scheduler = NotificationScheduler(
      database: database,
      notifications: DesktopNotificationService(
        backend: notificationBackend,
        settings: AppSettings.defaults(),
        now: () => clock,
      ),
      nowUtc: () => clock,
    );
    await scheduler.checkNow();
    scheduler.stop();
    expect(notificationBackend.requests, hasLength(1));
    expect(notificationBackend.requests.single.title, 'Cached appointment');
    scheduled = await database
        .select(database.notificationSchedule)
        .getSingle();
    expect(scheduled.sentAtUtc, isNotNull);
    final consumedId = scheduled.id;

    final recoveredBody = _eventWithReminder(
      'Recovered appointment',
      startUtc: DateTime.utc(2026, 8, 10, 9),
    );
    var syncReports = 0;
    final recoveryClient = MockClient((request) async {
      if (request.method == 'REPORT' &&
          request.body.contains('sync-collection')) {
        syncReports += 1;
        return http.Response(
          _syncResponse(
            token: 'urn:test:recovered-$syncReports',
            etag: '"reminder-2"',
          ),
          207,
        );
      }
      if (request.method == 'REPORT' &&
          request.body.contains('calendar-multiget')) {
        return http.Response(
          _multigetResponse(recoveredBody, '"reminder-2"'),
          207,
        );
      }
      fail('Unexpected ${request.method} ${request.url}');
    });
    var rebuilds = 0;
    await DavAccountSyncEngine(
      database: database,
      secretStore: secrets,
      httpClient: recoveryClient,
      accountId: 'account',
      policy: const DavAccountSyncPolicy(
        discoveryMaxAge: Duration(days: 30),
        inventoryMaxAge: Duration(days: 30),
      ),
      nowUtc: () => clock,
      rebuildNotifications: (accountId, _) async {
        rebuilds += 1;
        expect(
          (await database.select(database.accounts).getSingle()).authState,
          'signed_in',
        );
        await scheduleService.rebuildUpcomingNotifications(accountId);
      },
    ).synchronize();

    expect(rebuilds, 1);
    final rebuilt = await database.select(database.notificationSchedule).get();
    final consumed = rebuilt.singleWhere((row) => row.id == consumedId);
    expect(consumed.sentAtUtc, isNotNull);
    expect(consumed.title, isEmpty);
    expect(await scheduleService.isReminderSourceEligible(consumed), isFalse);
    scheduled = rebuilt.singleWhere((row) => row.id != consumedId);
    expect(scheduled.title, 'Recovered appointment');
    expect(
      scheduled.scheduledAtUtc,
      DateTime.utc(2026, 8, 10, 8, 30).millisecondsSinceEpoch,
    );
    expect(scheduled.sentAtUtc, isNull);
    expect(scheduled.dismissedAtUtc, isNull);
    expect(scheduled.snoozedUntilUtc, isNull);
    expect(await scheduleService.isReminderSourceEligible(scheduled), isTrue);
    final restarted = NotificationScheduler(
      database: database,
      notifications: DesktopNotificationService(
        backend: notificationBackend,
        settings: AppSettings.defaults(),
        now: () => clock,
      ),
      nowUtc: () => clock,
    );
    addTearDown(restarted.stop);
    await restarted.checkNow();
    expect(notificationBackend.requests, hasLength(1));
    expect(
      notificationBackend.cancelledIds,
      contains(notificationBackend.requests.single.stableId),
    );
  });

  test(
    'restart reconciles an in-progress MOVE after source synchronization',
    () async {
      final temporaryDirectory = await createPersistenceTestDirectory(
        'busymax-dav-move-restart-',
      );
      final databaseFile = File('${temporaryDirectory.path}/busymax.sqlite');
      final previousDatabaseWarningSetting =
          driftRuntimeOptions.dontWarnAboutMultipleDatabases;
      driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
      var persistedDatabase = AppDatabase(NativeDatabase(databaseFile));
      final persistedSecrets = InMemorySecretStore();
      try {
        await _seed(persistedDatabase, persistedSecrets);
        await _seedDestination(persistedDatabase);
        const uid = 'interrupted-move-task@example.test';
        const sourceHref = '${_collectionHref}interrupted-move-task.ics';
        const destinationHref =
            '${_destinationCollectionHref}interrupted-move-task.ics';
        final sourceRaw = _taskWithParent(uid, 'Interrupted move');
        final repository = DavObjectRepository(
          database: persistedDatabase,
          idFactory: () => 'interrupted-source-object',
        );
        await repository.commitConfirmedMutation(
          accountId: 'account',
          collectionId: 'collection',
          provider: BusyProvider.nextcloud,
          canonicalObject: _preparedMember(
            href: sourceHref,
            etag: '"source-before-move"',
            body: sourceRaw,
          ),
          completedAtUtc: _now,
        );
        final sourceObject = await (persistedDatabase.select(
          persistedDatabase.davObjects,
        )..where((row) => row.hrefKey.equals(sourceHref))).getSingle();
        final sourceTask = await (persistedDatabase.select(
          persistedDatabase.tasks,
        )..where((row) => row.davObjectId.equals(sourceObject.id))).getSingle();
        final operationId =
            await DavPendingOperationQueue(
              database: persistedDatabase,
              idFactory: () => 'interrupted-move-operation',
              nowUtc: () => _now,
            ).enqueueMove(
              accountId: 'account',
              sourceCollectionId: 'collection',
              destinationCollectionId: 'destination',
              objectId: sourceObject.id,
              localProjectionId: sourceTask.id,
              target: const IcalComponentKey(componentType: 'VTODO', uid: uid),
              postMovePatch: DavMutationPatch(
                target: const IcalComponentKey(
                  componentType: 'VTODO',
                  uid: uid,
                ),
                scope: DavMutationScope.object,
                operations: [DavPatchOperation.setTaskParent(null)],
              ),
            );
        await (persistedDatabase.update(persistedDatabase.pendingOps)
              ..where((row) => row.id.equals(operationId)))
            .write(const PendingOpsCompanion(state: Value('in_progress')));
        final interrupted = await persistedDatabase.pendingOpsDao.getOp(
          operationId,
        );
        expect(interrupted?.state, 'in_progress');
        expect(interrupted?.attemptCount, 0);
        expect(
          interrupted?.requestJson,
          isNot(contains('moveMayHaveCompleted')),
        );

        await persistedDatabase.close();
        persistedDatabase = AppDatabase(NativeDatabase(databaseFile));
        var destinationRaw = sourceRaw;
        var destinationEtag = '"destination-before-patch"';
        var moves = 0;
        var destinationPatchPuts = 0;
        var token = 0;
        var verifiedSynchronizedTombstone = false;
        final requests = <String>[];
        final client = MockClient((request) async {
          requests.add('${request.method} ${request.url.path}');
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
                  token: 'urn:test:restart-source-$token',
                  href: sourceHref,
                  deleted: !request.body.contains(
                    '<d:sync-token></d:sync-token>',
                  ),
                ),
                207,
              );
            }
            if (request.url.path == _destinationCollectionHref) {
              return http.Response(
                _syncMemberResponse(
                  token: 'urn:test:restart-destination-$token',
                  href: destinationHref,
                  etag: destinationEtag,
                ),
                207,
              );
            }
          }
          if (request.method == 'REPORT' &&
              request.body.contains('calendar-multiget') &&
              request.url.path == _destinationCollectionHref) {
            return http.Response(
              _multigetMemberResponse(
                href: destinationHref,
                body: destinationRaw,
                etag: destinationEtag,
              ),
              207,
            );
          }
          if (request.method == 'MOVE') {
            moves += 1;
            return http.Response('', 412);
          }
          if (request.method == 'GET' && request.url.path == sourceHref) {
            return http.Response('', 404);
          }
          if (request.method == 'GET' && request.url.path == destinationHref) {
            if (!verifiedSynchronizedTombstone) {
              final synchronizedSource = await (persistedDatabase.select(
                persistedDatabase.davObjects,
              )..where((row) => row.id.equals(sourceObject.id))).getSingle();
              expect(synchronizedSource.serverDeleted, isTrue);
              expect(
                (await persistedDatabase.pendingOpsDao.getOp(operationId))?.id,
                operationId,
              );
              verifiedSynchronizedTombstone = true;
            }
            return http.Response(
              destinationRaw,
              200,
              headers: {
                'etag': destinationEtag,
                'content-type': 'text/calendar',
              },
            );
          }
          if (request.method == 'PUT' && request.url.path == destinationHref) {
            destinationPatchPuts += 1;
            expect(request.headers['if-match'], destinationEtag);
            expect(request.body, isNot(contains('RELATED-TO')));
            destinationRaw = request.body;
            destinationEtag = '"destination-after-patch"';
            return http.Response('', 204);
          }
          fail('Unexpected ${request.method} ${request.url}');
        });

        final result = await DavAccountSyncEngine(
          database: persistedDatabase,
          secretStore: persistedSecrets,
          httpClient: client,
          accountId: 'account',
          policy: const DavAccountSyncPolicy(
            discoveryMaxAge: Duration(days: 30),
            inventoryMaxAge: Duration(days: 30),
            maximumConcurrentCollections: 1,
          ),
          correlationIdFactory: () => 'restart-move-recovery',
          nowUtc: () => _now.add(const Duration(minutes: 1)),
        ).synchronize();

        expect(result.pendingOperationsApplied, 1);
        expect(verifiedSynchronizedTombstone, isTrue);
        expect(moves, 0);
        expect(destinationPatchPuts, 1);
        expect(await persistedDatabase.pendingOpsDao.getOp(operationId), null);
        final tasks = await persistedDatabase
            .select(persistedDatabase.tasks)
            .get();
        expect(tasks, hasLength(1));
        expect(tasks.single.taskListId, 'dav-task-list-destination');
        expect(tasks.single.parentUid, null);
      } finally {
        await persistedDatabase.close();
        await temporaryDirectory.delete(recursive: true);
        driftRuntimeOptions.dontWarnAboutMultipleDatabases =
            previousDatabaseWarningSetting;
      }
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

final class _ReminderRecordingBackend implements DesktopNotificationBackend {
  final requests = <BusyMaxNotificationRequest>[];
  final cancelledIds = <String>[];

  @override
  Future<void> notify(
    BusyMaxNotificationRequest request, {
    DesktopNotificationActionHandler? onAction,
  }) async {
    requests.add(request);
  }

  @override
  Future<void> cancel(String stableId) async => cancelledIds.add(stableId);

  @override
  Future<void> close() async {}
}

const _collectionHref = '/cloud/remote.php/dav/calendars/alex/work/';
const _destinationCollectionHref = '/cloud/remote.php/dav/calendars/alex/home/';
const _eventHref = '${_collectionHref}event.ics';
final _now = DateTime.utc(2026, 8, 8, 12);

DavAccountSyncEngine _conflictSyncEngine({
  required AppDatabase database,
  required InMemorySecretStore secrets,
  required http.Client client,
  required Future<void> Function(
    String accountId,
    Set<String> affectedObjectIds,
  )
  rebuildNotifications,
}) => DavAccountSyncEngine(
  database: database,
  secretStore: secrets,
  httpClient: client,
  accountId: 'account',
  policy: const DavAccountSyncPolicy(
    discoveryMaxAge: Duration(days: 30),
    inventoryMaxAge: Duration(days: 30),
  ),
  rebuildNotifications: rebuildNotifications,
  correlationIdFactory: () => 'cached-conflict',
  nowUtc: () => _now,
);

final class _ConflictSyncServer {
  _ConflictSyncServer({
    required this.href,
    required String body,
    required String etag,
  }) : _body = body,
       _etag = etag;

  final String href;
  String _body;
  String _etag;
  int syncReports = 0;
  int puts = 0;

  void setRemote(String body, String etag) {
    _body = body;
    _etag = etag;
  }

  Future<http.Response> handle(http.Request request) async {
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
      return _discoveryMultistatus(_singleCollectionInventoryResponse);
    }
    if (request.method == 'REPORT' &&
        request.body.contains('sync-collection')) {
      syncReports += 1;
      return http.Response(
        _syncMemberResponse(
          token: 'urn:test:conflict-$syncReports',
          href: href,
          etag: _etag,
        ),
        207,
      );
    }
    if (request.method == 'REPORT' &&
        request.body.contains('calendar-multiget')) {
      return http.Response(
        _multigetMemberResponse(href: href, body: _body, etag: _etag),
        207,
      );
    }
    if (request.method == 'PUT' && request.url.path == href) {
      puts += 1;
      return http.Response('', 412);
    }
    if (request.method == 'GET' && request.url.path == href) {
      return http.Response(
        _body,
        200,
        headers: {'etag': _etag, 'content-type': 'text/calendar'},
      );
    }
    fail('Unexpected ${request.method} ${request.url}');
  }
}

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
          capabilitiesSchemaVersion: const Value(davCapabilitiesSchemaVersion),
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

String _eventWithReminder(String summary, {required DateTime startUtc}) {
  final start = _icalUtc(startUtc);
  final end = _icalUtc(startUtc.add(const Duration(hours: 1)));
  return '''BEGIN:VCALENDAR\r
VERSION:2.0\r
PRODID:-//BusyMax Test//EN\r
BEGIN:VEVENT\r
UID:event@example.test\r
DTSTART:$start\r
DTEND:$end\r
SUMMARY:$summary\r
BEGIN:VALARM\r
ACTION:DISPLAY\r
TRIGGER:-PT30M\r
DESCRIPTION:$summary\r
END:VALARM\r
END:VEVENT\r
END:VCALENDAR\r
''';
}

String _taskWithReminder(String summary, {required DateTime dueUtc}) {
  final due = _icalUtc(dueUtc);
  return '''BEGIN:VCALENDAR\r
VERSION:2.0\r
PRODID:-//BusyMax Test//EN\r
BEGIN:VTODO\r
UID:event@example.test\r
DUE:$due\r
SUMMARY:$summary\r
BEGIN:VALARM\r
ACTION:DISPLAY\r
TRIGGER;RELATED=END:-PT30M\r
DESCRIPTION:$summary\r
END:VALARM\r
END:VTODO\r
END:VCALENDAR\r
''';
}

String _icalUtc(DateTime value) {
  final utc = value.toUtc();
  String two(int part) => part.toString().padLeft(2, '0');
  return '${utc.year.toString().padLeft(4, '0')}${two(utc.month)}'
      '${two(utc.day)}T${two(utc.hour)}${two(utc.minute)}'
      '${two(utc.second)}Z';
}

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

const _singleCollectionInventoryResponse =
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

final class _NoticeLifecycleWire {
  _NoticeLifecycleWire(this.component);
  final String component;
  static const operationA = 'fe56ed0d-c620-4134-9a79-560da6aee085';
  static const operationB = 'ca40c96b-63df-4c82-b182-f007d192d934';
  static const home =
      'https://cloud.example.test/cloud/remote.php/dav/calendars/alex/';
  static const targetA = '${home}busymax-$operationA/';
  static const targetB = '${home}busymax-$operationB/';
  bool bindAllowed = false, created = false;
  int creationCalls = 0, revision = 0;
  String get properties =>
      '<d:resourcetype><d:collection/><c:calendar/></d:resourcetype><d:displayname>Recovered collection</d:displayname><d:current-user-privilege-set><d:privilege><d:all/></d:privilege></d:current-user-privilege-set><c:supported-calendar-component-set><c:comp name="$component"/></c:supported-calendar-component-set><d:supported-report-set><d:supported-report><d:report><d:sync-collection/></d:report></d:supported-report></d:supported-report-set>';
  String entry(String uri, String properties) =>
      '<d:response><d:href>$uri</d:href><d:propstat><d:prop>$properties</d:prop><d:status>HTTP/1.1 200 OK</d:status></d:propstat></d:response>';
  http.Response multi(String body) => _discoveryMultistatus(
    '<d:multistatus xmlns:d="DAV:" xmlns:c="urn:ietf:params:xml:ns:caldav">$body</d:multistatus>',
  );
  Future<http.Response> handle(http.Request request) async {
    if (request.method == 'OPTIONS') {
      return http.Response(
        '',
        200,
        headers: {
          'dav': '1, calendar-access, sync-collection',
          'allow': 'GET, PROPFIND, REPORT, MKCALENDAR',
        },
      );
    }
    if (request.method == 'MKCALENDAR') {
      expect(bindAllowed, isTrue);
      expect(request.url.toString(), targetB);
      creationCalls++;
      created = true;
      return http.Response('', 201);
    }
    if (request.method == 'PROPFIND') {
      if (request.url.toString() == targetA) return http.Response('', 404);
      if (request.url.toString() == targetB) {
        return created
            ? multi(entry(targetB, properties))
            : http.Response('', 404);
      }
      if (request.body.contains('<d:current-user-principal/>')) {
        return _discoveryMultistatus(
          _currentPrincipalResponse.replaceFirst(
            '/cloud/.well-known/caldav',
            request.url.path,
          ),
        );
      }
      if (request.body.contains('<c:calendar-home-set/>')) {
        return _discoveryMultistatus(_principalPropertiesResponse);
      }
      if (request.url.toString() == home && request.headers['depth'] == '0') {
        return multi(
          entry(
            home,
            '<d:resourcetype><d:collection/></d:resourcetype><d:current-user-privilege-set><d:privilege><d:${bindAllowed ? 'all' : 'read'}/></d:privilege></d:current-user-privilege-set>',
          ),
        );
      }
      return _discoveryMultistatus(
        _singleCollectionInventoryResponse.replaceFirst(
          '</d:multistatus>',
          '${created ? entry(targetB, properties) : ''}</d:multistatus>',
        ),
      );
    }
    if (request.method == 'REPORT' &&
        request.body.contains('sync-collection')) {
      if (request.url.toString() == targetB) {
        return multi('<d:sync-token>urn:lifecycle:empty</d:sync-token>');
      }
      revision++;
      String member(String href) => entry(href, '<d:getetag>"v1"</d:getetag>');
      return multi(
        '${member(_eventHref)}${member('${_collectionHref}todo.ics')}<d:sync-token>urn:lifecycle:$revision</d:sync-token>',
      );
    }
    if (request.method == 'REPORT') {
      String member(String href, String body) => entry(
        href,
        '<d:getetag>"v1"</d:getetag><c:calendar-data><![CDATA[$body]]></c:calendar-data>',
      );
      return multi(
        '${member(_eventHref, _event('Existing event'))}${member('${_collectionHref}todo.ics', 'BEGIN:VCALENDAR\r\nVERSION:2.0\r\nBEGIN:VTODO\r\nUID:notice-task@example.test\r\nDTSTAMP:20261103T000000Z\r\nSUMMARY:Existing task\r\nEND:VTODO\r\nEND:VCALENDAR\r\n')}',
      );
    }
    throw StateError('Unexpected ${request.method} ${request.url}');
  }
}

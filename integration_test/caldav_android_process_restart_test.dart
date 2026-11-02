import 'dart:convert';
import 'dart:io';
import 'dart:async';

import 'package:busymax/src/android/android_background.dart';
import 'package:busymax/src/app/app_bootstrap.dart';
import 'package:busymax/src/dav/http/dav_account_http_client.dart';
import 'package:busymax/src/dav/mutation/dav_collection_administration.dart';
import 'package:busymax/src/features/connectivity/network_connectivity_service.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:busymax/src/features/tasks/data/tasks_repository.dart';
import 'package:busymax/src/features/calendar/presentation/event_editor_draft.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';

/// Run twice without clearing the isolated QA package. The first process exits
/// with queued edits; the second uses production SQLite, secure storage,
/// authorization recovery and native account gates to replay them.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const encoded = String.fromEnvironment('BUSYMAX_CALDAV_NATIVE_FIXTURE');
  testWidgets(
    'Android durable CalDAV credentials and work survive an actual process restart',
    (tester) async {
      await tester.runAsync(() async {
        final config = jsonDecode(utf8.decode(base64Decode(encoded))) as Map;
        final credentials = config['credentials'] as Map;
        final context = SecurityContext(withTrustedRoots: true)
          ..setTrustedCertificatesBytes(utf8.encode(config['ca'] as String));
        final connectivity =
            StreamController<List<ConnectivityResult>>.broadcast(sync: true);
        final network = NetworkConnectivityMonitor(
          checkConnectivity: () async => [ConnectivityResult.wifi],
          connectivityChanges: connectivity.stream,
        );
        await network.initialize();
        http.Client client() => ConnectivityAwareHttpClient(
          inner: IOClient(HttpClient(context: context)),
          requireNetwork: network.requireNetwork,
        );
        final phase = File(
          '${(await getApplicationSupportDirectory()).path}/caldav-process-restart-v1.json',
        );
        final runtime = await AndroidHeadlessRuntime.create(
          overridesForTesting: (_) => [
            networkConnectivityMonitorProvider.overrideWithValue(network),
            baseHttpClientProvider.overrideWith((ref) {
              final connection = client();
              ref.onDispose(connection.close);
              return connection;
            }),
            davAccountHttpClientProvider.overrideWith((ref, id) {
              final connection = DavAccountHttpClient(
                accountId: id,
                persistence: ref.read(authorizationPersistenceProvider),
                createClient: (_) => client(),
              );
              ref.onDispose(connection.close);
              return connection;
            }),
          ],
        );
        final db = runtime.database, providers = runtime.container;
        debugPrint('CalDAV native process: production runtime ready');
        final onboarding = providers.read(davAccountOnboardingServiceProvider);
        final secrets = providers.read(secretStoreProvider);
        Future<void> sync(String id, {bool full = true}) async {
          debugPrint('CalDAV native process: sync start');
          await providers.read(signedInSyncRunnerProvider)(id, full);
          debugPrint('CalDAV native process: sync complete');
        }

        DavCollectionAdministration admin(String id) =>
            DavCollectionAdministration(
              database: db,
              secrets: secrets,
              client: providers.read(davAccountHttpClientProvider(id)),
              accountId: id,
              refresh: () => sync(id, full: true),
              requireNetwork: () async {},
            );
        final independent = client();
        try {
          if (!await phase.exists()) {
            // Recover an interrupted preparation only inside this dedicated QA
            // package, validating ownership before deleting its disposable data.
            for (final account in await db.select(db.accounts).get()) {
              debugPrint(
                'CalDAV native process: cleaning interrupted preparation',
              );
              expect(account.provider, 'caldav');
              expect(account.providerAccountId, 'alice');
              expect(
                account.authority,
                anyOf(
                  'https://localhost:18443/',
                  'https://localhost:18444/dav.php/',
                ),
              );
              await sync(account.id, full: true);
              for (final c in (await db.select(db.davCollections).get()).where(
                (c) =>
                    c.accountId == account.id &&
                    c.displayName.startsWith('BusyMax native restart '),
              )) {
                await admin(account.id).remove(c.id);
              }
              await onboarding.removeAccount(account.id);
              debugPrint('CalDAV native process: cleanup complete');
            }
            expect(
              await db.select(db.accounts).get(),
              isEmpty,
              reason: 'Use the dedicated CalDAV QA package without unrelated accounts.',
            );
            final records = <Map<String, Object?>>[];
            for (final server in {
              'Radicale 3.8.1': 'https://localhost:18443/',
              'Baikal 0.12.1': 'https://localhost:18444/dav.php/',
            }.entries) {
              debugPrint('CalDAV native process: preparing ${server.key}');
              final id = (await onboarding.connectCalDav(
                serverUrl: server.value,
                username: 'alice',
                password: credentials['alice'] as String,
              )).accountId;
              await sync(id);
              final name =
                  'BusyMax native restart ${DateTime.now().microsecondsSinceEpoch}';
              expect(
                await admin(id).create(name, const {'VEVENT', 'VTODO'}),
                DavCollectionAdministrationOutcome.committed,
              );
              final collection = (await db.select(db.davCollections).get())
                  .singleWhere(
                    (c) => c.accountId == id && c.displayName == name,
                  );
              final list = (await db.select(db.taskLists).get()).singleWhere(
                (l) => l.davCollectionId == collection.id,
              );
              final tasks = providers.read(
                tasksRepositoryForAccountProvider(id),
              );
              final calendars = providers.read(calendarRepositoryProvider);
              final source = (await db.select(db.calendarSources).get())
                  .singleWhere((s) => s.davCollectionId == collection.id);
              await calendars.createLocalEvent(
                EventEditorDraft.newEvent(
                  accountId: id,
                  sourceId: source.id,
                  providerCalendarId: source.providerCalendarId,
                  start: DateTime(2027, 3, 14, 9),
                  end: DateTime(2027, 3, 14, 10),
                ).copyWith(title: 'Before actual event process restart'),
              );
              await tasks.createTask(
                list.id,
                const TaskCreateInput(title: 'Before actual process restart'),
              );
              await sync(id);
              final task = (await db.select(db.tasks).get()).singleWhere(
                (t) => t.davCollectionId == collection.id,
              );
              final event = (await db.select(db.calendarEvents).get())
                  .singleWhere((e) => e.davCollectionId == collection.id);
              records.add({
                'server': server.key,
                'id': id,
                'collection': collection.id,
                'task': task.id,
                'event': event.id,
                'list': list.id,
                'generation': await providers
                    .read(authorizationPersistenceProvider)
                    .generation(id),
              });
            }
            connectivity.add([ConnectivityResult.none]);
            debugPrint('CalDAV native process: offline queue preparation');
            expect(network.isOffline, isTrue);
            await Future<void>.delayed(const Duration(milliseconds: 300));
            for (final record in records) {
              final id = record['id'] as String;
              final calendars = providers.read(calendarRepositoryProvider);
              await calendars.updateLocalEvent(
                EventEditorDraft.fromEventDetail(
                  (await calendars.loadEventDetail(record['event'] as String))!,
                ).copyWith(title: 'After actual event process restart'),
              );
              await providers
                  .read(tasksRepositoryForAccountProvider(id))
                  .patchTask(
                    record['list'] as String,
                    record['task'] as String,
                    const TaskPatchInput({
                      'title': 'After actual process restart',
                    }),
                  );
            }
            expect((await db.select(db.pendingOps).get()).length, 4);
            await phase.writeAsString(jsonEncode(records), flush: true);
            debugPrint('BUSYMAX_CALDAV_PROCESS_PREPARED android both');
          } else {
            final records = (jsonDecode(await phase.readAsString()) as List)
                .cast<Map>();
            expect((await db.select(db.pendingOps).get()).length, 4);
            for (final record in records) {
              final id = record['id'] as String;
              expect(
                await providers
                    .read(authorizationPersistenceProvider)
                    .generation(id),
                record['generation'],
              );
              expect(await secrets.readCredential(id), isNotNull);
              await sync(id);
              final task = (await db.select(db.tasks).get()).singleWhere(
                (t) => t.id == record['task'],
              );
              expect(task.title, 'After actual process restart');
              final object = (await db.select(db.davObjects).get()).singleWhere(
                (o) => o.id == task.davObjectId,
              );
              final headers = {
                'authorization':
                    'Basic ${base64Encode(utf8.encode('alice:${credentials['alice']}'))}',
              };
              final event = (await db.select(db.calendarEvents).get())
                  .singleWhere((e) => e.id == record['event']);
              expect(event.title, 'After actual event process restart');
              final eventObject = (await db.select(db.davObjects).get())
                  .singleWhere((o) => o.id == event.davObjectId);
              final remoteEvent = await independent.get(
                Uri.parse(eventObject.requestUri),
                headers: headers,
              );
              expect(remoteEvent.statusCode, 200);
              expect(
                remoteEvent.body,
                contains('SUMMARY:After actual event process restart'),
              );
              final eventUpdate = await independent.put(
                Uri.parse(eventObject.requestUri),
                headers: {
                  ...headers,
                  'content-type': 'text/calendar',
                  'if-match': remoteEvent.headers['etag']!,
                },
                body: remoteEvent.body.replaceFirst(
                  'After actual event process restart',
                  'Independent event after native restart',
                ),
              );
              expect(eventUpdate.statusCode, anyOf(201, 204));
              final remote = await independent.get(
                Uri.parse(object.requestUri),
                headers: headers,
              );
              expect(remote.statusCode, 200);
              expect(
                remote.body,
                contains('SUMMARY:After actual process restart'),
              );
              final updated = await independent.put(
                Uri.parse(object.requestUri),
                headers: {
                  ...headers,
                  'content-type': 'text/calendar',
                  'if-match': remote.headers['etag']!,
                },
                body: remote.body.replaceFirst(
                  'After actual process restart',
                  'Independent after native restart',
                ),
              );
              expect(updated.statusCode, anyOf(201, 204));
              await sync(id);
              expect(
                (await db.select(db.calendarEvents).get())
                    .singleWhere((e) => e.id == event.id)
                    .title,
                'Independent event after native restart',
              );
              expect(
                (await db.select(db.tasks).get())
                    .singleWhere((t) => t.id == task.id)
                    .title,
                'Independent after native restart',
              );
              expect(
                await admin(id).remove(record['collection'] as String),
                DavCollectionAdministrationOutcome.committed,
              );
              await onboarding.removeAccount(id);
              expect(await secrets.readCredential(id), isNull);
              debugPrint(
                'BUSYMAX_CALDAV_PROCESS_PASS ${record['server']} android',
              );
            }
            expect(await db.select(db.accounts).get(), isEmpty);
            expect(await db.select(db.pendingOps).get(), isEmpty);
            await phase.delete();
          }
        } finally {
          independent.close();
          await runtime.dispose();
          await network.dispose();
          await connectivity.close();
        }
      });
    },
    skip: encoded.isEmpty || !Platform.isAndroid,
    timeout: const Timeout(Duration(minutes: 8)),
  );
}

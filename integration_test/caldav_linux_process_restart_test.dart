import 'dart:convert';
import 'dart:io';

import 'package:busymax/src/app/app_settings.dart';
import 'package:busymax/src/core/secrets/secret_store.dart';
import 'package:busymax/src/dav/dav_errors.dart';
import 'package:busymax/src/features/calendar/presentation/event_editor_draft.dart';
import 'package:busymax/src/features/tasks/data/tasks_repository.dart';
import 'package:busymax/src/features/notifications/desktop_notification_service.dart';
import 'package:busymax/src/platform/linux/linux_notification_backend.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:integration_test/integration_test.dart';

import '../test/dav/support/caldav_fixture.dart';
import '../test/dav/support/caldav_qa_targets.dart';
import 'support/caldav_native_secret_store.dart';

/// Run twice as distinct native Linux processes with the same fixture directory.
/// Production libsecret storage is used; only key names and the database path
/// are isolated. No normal BusyMax account data is opened.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Linux keyring, queued edits and collection operation IDs survive process restart',
    (tester) async {
      await tester.runAsync(() async {
        final root = Platform.environment['BUSYMAX_CALDAV_FIXTURE_DIR']!;
        final receipt = File('$root/linux-process-restart-v2.json');
        final previous = await receipt.exists()
            ? jsonDecode(await receipt.readAsString()) as Map<String, dynamic>
            : null;
        if (previous != null) expect(previous['pid'], isNot(pid));
        final records = <Map<String, Object?>>[];
        for (final server in calDavQaTargets.entries) {
          final uri = Uri.parse(server.value);
          final fault = _CreationResponseLoss();
          final secrets = SecureSecretStore(
            CalDavQaSecureStorage('busymax.qa.caldav.${uri.port}.'),
          );
          final f = CalDavFixture(
            uri,
            fixtureDirectory: root,
            secretStore: secrets,
            wrapAccountClient: (client) => _LossClient(client, fault),
          );
          if (previous == null) {
            await f.open();
            final list = (await f.database.select(f.database.taskLists).get())
                .singleWhere((l) => l.davCollectionId == f.collectionId);
            final source =
                (await f.database.select(f.database.calendarSources).get())
                    .singleWhere(
                      (s) => s.davCollectionId == f.eventCollectionId,
                    );
            await f.tasks.createTask(
              list.id,
              const TaskCreateInput(title: 'Linux keyring queued task'),
            );
            await f.calendars.createLocalEvent(
              EventEditorDraft.newEvent(
                accountId: f.id,
                sourceId: source.id,
                providerCalendarId: source.providerCalendarId,
                start: DateTime(2027, 3, 14, 9),
                end: DateTime(2027, 3, 14, 10),
              ).copyWith(title: 'Linux keyring queued event'),
            );
            fault.enabled = true;
            for (final component in ['VEVENT', 'VTODO']) {
              await expectLater(
                f.administration.create(
                  '${f.collectionName} restart $component',
                  {component},
                ),
                throwsA(
                  anyOf(isA<DavException>(), isA<http.ClientException>()),
                ),
              );
            }
            final operations = await f.database
                .select(f.database.davCollectionCreations)
                .get();
            final pending = operations
                .where((o) => o.state == 'dispatched')
                .toList();
            expect(pending, hasLength(2));
            expect(fault.committed, hasLength(2));
            expect(
              await f.database.select(f.database.pendingOps).get(),
              hasLength(2),
            );
            records.add({
              ...f.restartReceipt(),
              'server': server.key,
              'generation': await f.persistence.generation(f.id),
              'operations': pending
                  .map((o) => {'id': o.id, 'target': o.targetUri})
                  .toList(),
            });
            await f.suspendForProcessRestart();
          } else {
            final record = (previous['accounts'] as List)
                .cast<Map<String, dynamic>>()
                .singleWhere((r) => r['server'] == server.key);
            await f.restoreAfterProcessRestart(record);
            try {
              expect(
                await f.persistence.generation(f.id),
                record['generation'],
              );
              expect(
                await f.database.select(f.database.pendingOps).get(),
                hasLength(2),
              );
              await f.synchronize(full: true);
              expect(
                fault.dispatched,
                0,
                reason: 'Committed creation must reconcile by persisted ID without another MKCALENDAR.',
              );
              expect(
                await f.database.select(f.database.pendingOps).get(),
                isEmpty,
              );
              for (final operation
                  in (record['operations'] as List)
                      .cast<Map<String, dynamic>>()) {
                final saved =
                    (await f.database
                            .select(f.database.davCollectionCreations)
                            .get())
                        .singleWhere((o) => o.id == operation['id']);
                expect(saved.state, 'committed');
                expect(saved.targetUri, operation['target']);
                expect(
                  (await f.independentRequest(
                    'PROPFIND',
                    Uri.parse(saved.targetUri),
                    headers: const {'Depth': '0'},
                  )).statusCode,
                  207,
                );
                expect(
                  (await f.independentRequest(
                    'DELETE',
                    Uri.parse(saved.targetUri),
                  )).statusCode,
                  anyOf(200, 204),
                );
              }
              final task = (await f.database.select(f.database.tasks).get())
                  .singleWhere((t) => t.davCollectionId == f.collectionId);
              final event =
                  (await f.database.select(f.database.calendarEvents).get())
                      .singleWhere(
                        (e) => e.davCollectionId == f.eventCollectionId,
                      );
              for (final objectId in [task.davObjectId, event.davObjectId]) {
                final object =
                    (await f.database.select(f.database.davObjects).get())
                        .singleWhere((o) => o.id == objectId);
                expect(
                  (await f.independentRequest(
                    'GET',
                    Uri.parse(object.requestUri),
                  )).body,
                  contains('SUMMARY:Linux keyring queued'),
                );
              }
              final identity = File(
                '${f.directory.path}/native-notifications.json',
              );
              final backend = FreedesktopNotificationBackend(
                identityFile: identity,
              );
              try {
                await backend.probe();
                final notifications = DesktopNotificationService(
                  backend: backend,
                  settings: AppSettings.defaults(),
                );
                final taskKey = 'task|caldav-qa|${f.id}',
                    eventKey = 'event|caldav-qa|${f.id}';
                expect(
                  (await notifications.notifyTaskReminder(
                    task.title,
                    server.key,
                    stableId: taskKey,
                  )).status,
                  ReminderDeliveryStatus.delivered,
                );
                expect(
                  (await notifications.notifyEventReminder(
                    event.title,
                    server.key,
                    stableId: eventKey,
                  )).status,
                  ReminderDeliveryStatus.delivered,
                );
                final native = jsonDecode(await identity.readAsString()) as Map;
                expect((native['ids'] as Map).values, everyElement(isPositive));
                expect(
                  (native['ids'] as Map).keys,
                  containsAll([taskKey, eventKey]),
                );
                await backend.cancel(taskKey);
                await backend.cancel(eventKey);
              } finally {
                await backend.close();
              }
            } finally {
              await f.close();
            }
            expect(await secrets.readCredential(f.id), isNull);
            // ignore: avoid_print
            print(
              'BUSYMAX_CALDAV_LINUX_PROCESS_PASS ${server.key}; keyring+creation recovery+queue+native notification delivery',
            );
          }
        }
        if (previous == null) {
          await receipt.writeAsString(
            jsonEncode({'pid': pid, 'accounts': records}),
            flush: true,
          );
          // ignore: avoid_print
          print('BUSYMAX_CALDAV_LINUX_PROCESS_PREPARED pid=$pid');
        } else {
          await receipt.delete();
        }
      });
    },
    skip:
        !Platform.isLinux ||
        Platform.environment['BUSYMAX_CALDAV_NATIVE'] != '1',
  );
}

class _CreationResponseLoss {
  bool enabled = false;
  int dispatched = 0;
  final committed = <Uri>{};
}

class _LossClient extends http.BaseClient {
  _LossClient(this.delegate, this.fault);
  final http.Client delegate;
  final _CreationResponseLoss fault;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (fault.enabled && fault.committed.contains(request.url)) {
      throw http.ClientException('QA interruption after remote commit');
    }
    if (request.method == 'MKCALENDAR' || request.method == 'MKCOL') {
      fault.dispatched++;
      final response = await delegate.send(request);
      if (fault.enabled && response.statusCode == 201) {
        await response.stream.drain<void>();
        fault.committed.add(request.url);
        throw http.ClientException('QA lost creation response');
      }
      return response;
    }
    return delegate.send(request);
  }

  @override
  void close() => delegate.close();
}

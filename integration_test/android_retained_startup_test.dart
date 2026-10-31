// Run only in an explicitly isolated Android test installation. The host must
// force-stop after the prepared receipt, then relaunch the SAME retained APK.
// There is deliberately no cancelAll() or work re-registration on restart.
// This identical harness also compiles against the unchanged daee1df sources.
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'dart:isolate';

import 'package:busymax/src/android/android_app.dart';
import 'package:busymax/src/app/app_bootstrap.dart';
import 'package:busymax/src/android/android_background.dart';
import 'package:busymax/src/core/secrets/secret_store.dart';
import 'package:busymax/src/db/app_database.dart';
import 'package:busymax/src/features/notifications/notification_schedule_service.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart' show SqliteException;
import 'package:workmanager/workmanager.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const enabled = bool.fromEnvironment('BUSYMAX_RETAINED_STARTUP_QA');
  const build = String.fromEnvironment('BUSYMAX_RETAINED_STARTUP_BUILD');
  testWidgets('foreground startup with retained synchronization and refill', (
    tester,
  ) async {
    expect(Platform.isAndroid, isTrue);
    final support = await getApplicationSupportDirectory();
    final directory = Directory('${support.path}/retained-startup-qa');
    await directory.create(recursive: true);
    final prepared = File('${directory.path}/prepared.json');
    final restarting = await prepared.exists();
    final watch = Stopwatch()..start();
    Future<void> receipt(String name, Map<String, Object?> values) async {
      await File('${directory.path}/$name.json').writeAsString(
        jsonEncode({
          'build': build,
          'pid': pid,
          'isolate': developer.Service.getIsolateId(Isolate.current),
          'utc': DateTime.now().toUtc().toIso8601String(),
          'elapsedMicros': watch.elapsedMicroseconds,
          ...values,
        }),
        flush: true,
      );
    }

    await receipt('entry', {'restarting': restarting});
    Future<List<Map<String, Object?>>> inventory() async => [
      for (final name in [
        busyMaxPeriodicSyncUniqueName,
        busyMaxNotificationRefillUniqueName,
      ])
        await (() async {
          final info = await Workmanager().getWorkInfo(name);
          return <String, Object?>{
            'uniqueName': name,
            'state': info?.state.name,
            'isPeriodic': info?.isPeriodic,
            'taskName': info?.taskName,
            'lastFinishedAt': info?.lastFinishedAt?.toUtc().toIso8601String(),
          };
        })(),
    ];
    AndroidHeadlessRuntime? runtime;
    var completed = false;
    try {
      await receipt('inventory', {'nativeWork': await inventory()});
      if (restarting) {
        final previous = jsonDecode(await prepared.readAsString()) as Map;
        expect(pid, isNot(previous['pid']));
        expect(
          await Workmanager().isScheduledByUniqueName(
            busyMaxPeriodicSyncUniqueName,
          ),
          isTrue,
        );
        expect(
          await Workmanager().isScheduledByUniqueName(
            busyMaxNotificationRefillUniqueName,
          ),
          isTrue,
        );
      }
      await receipt('runtime-start', {});
      runtime = await AndroidHeadlessRuntime.create();
      await receipt('runtime-opened', {});
      final database = runtime.database;
      if (!restarting) {
        expect(await database.select(database.accounts).get(), isEmpty);
        final now = DateTime.now().toUtc();
        final alarm = now.add(const Duration(days: 7));
        final stamp = alarm
            .toIso8601String()
            .split('.')
            .first
            .replaceAll('-', '')
            .replaceAll(':', '');
        final alarms = jsonEncode([
          {
            'properties': [
              {'name': 'ACTION', 'value': 'DISPLAY', 'parameters': []},
              {
                'name': 'TRIGGER',
                'value': '${stamp}Z',
                'parameters': [
                  {
                    'name': 'VALUE',
                    'values': ['DATE-TIME'],
                    'wasQuoted': false,
                  },
                ],
              },
            ],
          },
        ]);
        final secrets = SecureSecretStore(
          runtime.container.read(secureStorageProvider),
        );
        for (var account = 0; account < 2; account++) {
          final id = 'nextcloud:retained-startup-$account';
          final authority = Uri.parse('https://localhost:${account + 1}/');
          await database
              .into(database.accounts)
              .insert(
                AccountsCompanion.insert(
                  id: id,
                  provider: 'nextcloud',
                  authority: authority.toString(),
                  providerAccountId: 'retained-startup-$account',
                  credentialKind: 'nextcloud_app_password',
                  authState: const Value('signed_in'),
                  createdAtUtc: now.toIso8601String(),
                  updatedAtUtc: now.toIso8601String(),
                ),
              );
          await secrets.saveCredential(
            id,
            NextcloudSecretRecord(
              canonicalServer: authority,
              loginName: 'synthetic',
              appPassword: 'synthetic-never-transmitted',
            ),
          );
          await database
              .into(database.taskLists)
              .insert(
                TaskListsCompanion.insert(
                  accountId: id,
                  id: 'cached-list-$account',
                  title: 'QA cached list',
                  rawJson: '{}',
                  createdLocalAtUtc: now.toIso8601String(),
                  updatedLocalAtUtc: now.toIso8601String(),
                ),
              );
          await database.batch((batch) {
            batch.insertAll(database.tasks, [
              for (var task = 0; task < 250; task++)
                TasksCompanion.insert(
                  accountId: id,
                  taskListId: 'cached-list-$account',
                  id: 'cached-task-$account-$task',
                  title: 'QA cached reminder',
                  taskAlarmsJson: task < 3
                      ? Value(alarms)
                      : const Value.absent(),
                  rawJson: '{}',
                  createdLocalAtUtc: now.toIso8601String(),
                  updatedLocalAtUtc: now.toIso8601String(),
                ),
            ]);
          });
          await NotificationScheduleService(
            database: database,
            preserveLifecycle: true,
          ).rebuildUpcomingNotifications(id);
        }
        final pragmas = <String, Object?>{};
        for (final name in ['journal_mode', 'busy_timeout', 'locking_mode']) {
          pragmas[name] = (await database.customSelect('PRAGMA $name').get())
              .map((row) => row.data)
              .toList();
        }
        await receipt('seeded', {
          'pragmas': pragmas,
          'accounts': 2,
          'tasks': 500,
        });
        expect(
          await database.select(database.notificationSchedule).get(),
          hasLength(6),
        );
        // Register the actual production periodic tasks and dispatcher only
        // AFTER seeding. The host stops this process at the receipt barrier,
        // retaining ENQUEUED/RUNNING work for foreground restart contention.
        // Production's five-minute flex makes a fresh first run due ten
        // minutes later. Use the full first window only in this fixture so
        // retained periodic work is actually due during the tested restart.
        // The dispatcher, names, interval, constraints and backoff stay real.
        await Workmanager().initialize(busyMaxWorkmanagerDispatcher);
        for (final sync in [true, false]) {
          await Workmanager().registerPeriodicTask(
            sync
                ? busyMaxPeriodicSyncUniqueName
                : busyMaxNotificationRefillUniqueName,
            sync
                ? busyMaxPeriodicSyncTaskName
                : busyMaxNotificationRefillTaskName,
            frequency: const Duration(minutes: 15),
            initialDelay: const Duration(seconds: 3),
            flexInterval: const Duration(minutes: 15),
            constraints: Constraints(
              networkType: sync
                  ? NetworkType.connected
                  : NetworkType.notRequired,
              requiresBatteryNotLow: true,
              requiresStorageNotLow: true,
            ),
            existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
            backoffPolicy: BackoffPolicy.exponential,
            backoffPolicyDelay: const Duration(minutes: 10),
            tag: sync ? 'busymax-sync' : 'busymax-notification-refill',
          );
        }
        await receipt('prepared', {'nativeWork': await inventory()});
        // A real host force-stop, not a successful test finalizer, ends phase 1.
        // This bound detects missing orchestration; it is not a SQLite retry.
        final deadline = DateTime.now().add(const Duration(seconds: 60));
        while (DateTime.now().isBefore(deadline)) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        fail('Host did not force-stop at the retained-work receipt barrier.');
      } else {
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: runtime.container,
            child: const AndroidBusyMaxApp(),
          ),
        );
        await tester.pumpAndSettle();
        await receipt('foreground-ready', {});
        // Observe retained native jobs without replacing them. Worker results
        // and SQL errors are independently captured by host logcat/VM sampling.
        expect(await database.select(database.accounts).get(), hasLength(2));
        expect(await database.select(database.tasks).get(), hasLength(500));
        expect(
          await Workmanager().isScheduledByUniqueName(
            busyMaxPeriodicSyncUniqueName,
          ),
          isTrue,
        );
        expect(
          await Workmanager().isScheduledByUniqueName(
            busyMaxNotificationRefillUniqueName,
          ),
          isTrue,
        );
        await receipt('verified', {'nativeWork': await inventory()});
        completed = true;
      }
    } catch (error, stack) {
      // Drift's remote error serializes the SQLite extended result code in
      // SqliteException(<extended code>). Preserve that code without importing
      // Drift's experimental remote protocol or changing its implementation.
      final serialized = RegExp(r'SqliteException\((\d+)\)')
          .firstMatch(error.toString());
      final extendedCode = error is SqliteException
          ? error.extendedResultCode
          : int.tryParse(serialized?.group(1) ?? '');
      await receipt('failure', {
        'type': error.runtimeType.toString(),
        if (extendedCode != null) ...{
          'sqliteResultCode': extendedCode & 0xff,
          'sqliteExtendedResultCode': extendedCode,
          'codeSource': error is SqliteException ? 'typed' : 'serialized',
        },
        if (error is SqliteException) ...{
          'operation': error.operation,
          'statement': error.causingStatement,
        },
        'error': error.toString(),
        'stack': stack.toString(),
      });
      rethrow;
    } finally {
      // Never cancel retained work to prepare or rescue the evaluated restart.
      // After a completed restart assertion, native jobs remain scheduled too.
      // The host removes this isolated test installation after all comparisons.
      if (completed && runtime != null) {
        await tester.pumpWidget(const SizedBox.shrink());
        await runtime.dispose();
      }
    }
  }, skip: !enabled);
}

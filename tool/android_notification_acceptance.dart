// Installs only as io.busystack.busymax.notificationqa. Synthetic data and
// commands exercise the real Material app, database, alarms and action entrypoint.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:busymax/src/android/android_app.dart';
import 'package:busymax/src/android/android_background.dart';
import 'package:busymax/src/app/app_bootstrap.dart';
import 'package:busymax/src/core/auth/oauth_models.dart';
import 'package:busymax/src/core/http/request_dispatch_exception.dart';
import 'package:busymax/src/db/app_database.dart';
import 'package:busymax/src/features/notifications/notification_schedule_service.dart';
import 'package:busymax/src/features/sync/account_sync_operations.dart';
import 'package:busymax/src/schedule/schedule_repository.dart';
import 'package:drift/drift.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final support = await getApplicationSupportDirectory();
  if (!Platform.isAndroid ||
      !support.path.contains('/io.busystack.busymax.notificationqa/')) {
    throw StateError(
      'This driver requires the isolated notification QA package.',
    );
  }
  final runtime = await AndroidHeadlessRuntime.create(
    overridesForTesting: (database) => [
      accountSyncOperationsProvider.overrideWithValue(
        const DisabledAccountSyncOperations(),
      ),
      allAccountsSyncRunnerProvider.overrideWithValue(() async {}),
      signedInSyncRunnerProvider.overrideWithValue((_, _) async {}),
      scheduleRepositoryProvider.overrideWithValue(
        ScheduleRepository(database, ensureCloudCoverage: (_, _) async => true),
      ),
    ],
  );
  final driver = _Driver(runtime, Directory('${support.path}/notification-qa'));
  await driver.start();
  // Only cloud transport is disabled for synthetic accounts. Presentation,
  // schedules, native alarms, permission handling and activation remain real.
  runApp(
    UncontrolledProviderScope(
      container: runtime.container,
      child: const AndroidBusyMaxApp(),
    ),
  );
}

class _Driver {
  _Driver(this.runtime, this.directory);
  final AndroidHeadlessRuntime runtime;
  final Directory directory;
  bool reading = false;
  AppDatabase get database => runtime.database;
  AppSettingsController get settings =>
      runtime.container.read(appSettingsControllerProvider.notifier);

  Future<void> record(
    Map<String, Object?> value,
  ) => File('${directory.path}/events.jsonl').writeAsString(
    '${jsonEncode({'at': DateTime.now().toUtc().toIso8601String(), ...value})}\n',
    mode: FileMode.append,
    flush: true,
  );

  Future<void> start() async {
    await Directory('${directory.path}/commands').create(recursive: true);
    for (final provider in ['google', 'microsoft']) {
      await database
          .into(database.accounts)
          .insert(
            AccountsCompanion.insert(
              id: 'qa-$provider',
              provider: provider,
              authority: 'https://qa.invalid',
              providerAccountId: 'notification-qa',
              credentialKind: 'oauth',
              authState: const Value('signed_in'),
              displayName: const Value('Notification QA'),
              createdAtUtc: '',
              updatedAtUtc: '',
            ),
            mode: InsertMode.insertOrIgnore,
          );
    }
    await database
        .into(database.calendarSources)
        .insertOnConflictUpdate(
          CalendarSourcesCompanion.insert(
            id: 'qa-calendar',
            accountId: 'qa-google',
            provider: 'google',
            providerCalendarId: 'calendar',
            summary: 'Teaching',
            createdAtLocal: 0,
            updatedAtLocal: 0,
          ),
        );
    await database
        .into(database.taskLists)
        .insertOnConflictUpdate(
          TaskListsCompanion.insert(
            accountId: 'qa-microsoft',
            id: 'qa-list',
            title: 'Work',
            rawJson: '{}',
            createdLocalAtUtc: '',
            updatedLocalAtUtc: '',
          ),
        );
    runtime.notifications.activations.listen((activation) {
      unawaited(
        record({
          'activation': activation.sourceType,
          'account': activation.accountId,
          'item': activation.itemId,
        }),
      );
    });
    Timer.periodic(
      const Duration(milliseconds: 300),
      (_) => unawaited(readCommands()),
    );
    await record({'state': 'ready'});
  }

  Future<void> readCommands() async {
    if (reading) return;
    reading = true;
    try {
      final files =
          Directory('${directory.path}/commands')
              .listSync()
              .whereType<File>()
              .where((file) => file.path.endsWith('.json'))
              .toList()
            ..sort((a, b) => a.path.compareTo(b.path));
      for (final file in files) {
        final command = (jsonDecode(await file.readAsString()) as Map)
            .cast<String, dynamic>();
        await file.rename('${file.path}.done');
        try {
          await apply(command);
          await runtime.notifications.reconcile();
          await snapshot();
        } on Object catch (error) {
          await record({
            'commandFailed': command['command'],
            'errorType': '${error.runtimeType}',
          });
        }
      }
    } finally {
      reading = false;
    }
  }

  Future<void> apply(Map<String, dynamic> command) async {
    final now = DateTime.now().toUtc();
    switch (command['command']) {
      case 'permission':
        await record({
          'permissionResult': await runtime.notifications
              .requestNotificationPermission(),
        });
      case 'exact':
        await record({
          'exactResult': await runtime.notifications
              .requestExactAlarmPermission(),
        });
      case 'event':
        final id = command['id'] as String? ?? 'qa-event';
        await database
            .into(database.calendarEvents)
            .insertOnConflictUpdate(
              CalendarEventsCompanion.insert(
                id: id,
                accountId: 'qa-google',
                calendarSourceId: 'qa-calendar',
                provider: 'google',
                providerCalendarId: 'calendar',
                providerEventId: id,
                title:
                    command['title'] as String? ??
                    'Basic French lesson · BusyMax QA',
                location: const Value('Contact: classroom & <lab> · العربية'),
                startDateTime: Value(
                  now
                      .add(
                        Duration(minutes: command['startMinutes'] as int? ?? 2),
                      )
                      .toIso8601String(),
                ),
                endDateTime: Value(
                  now.add(const Duration(hours: 1)).toIso8601String(),
                ),
                remindersJson: const Value(
                  '{"overrides":[{"method":"popup","minutes":5}]}',
                ),
                createdAtLocal: 0,
                updatedAtLocal: 0,
              ),
            );
        await NotificationScheduleService(database: database)
            .rebuildUpcomingNotifications('qa-google');
      case 'task':
        await database
            .into(database.tasks)
            .insertOnConflictUpdate(
              TasksCompanion.insert(
                accountId: 'qa-microsoft',
                taskListId: 'qa-list',
                id: 'qa-task',
                title: 'Location: QA report & review',
                dueUtc: Value(now.toIso8601String()),
                microsoftDueDateTime: Value(now.toIso8601String()),
                microsoftDueTimeZone: const Value('UTC'),
                microsoftIsReminderOn: const Value(true),
                microsoftReminderDateTime: Value(
                  now
                      .add(
                        Duration(
                          seconds: command['reminderSeconds'] as int? ?? 3,
                        ),
                      )
                      .toIso8601String(),
                ),
                microsoftReminderTimeZone: const Value('UTC'),
                rawJson: '{}',
                createdLocalAtUtc: '',
                updatedLocalAtUtc: '',
              ),
            );
        await NotificationScheduleService(database: database)
            .rebuildUpcomingNotifications('qa-microsoft');
      case 'complete':
        await (database.update(database.tasks)..where(
              (row) =>
                  row.accountId.equals('qa-microsoft') &
                  row.id.equals('qa-task'),
            ))
            .write(const TasksCompanion(status: Value('completed')));
      case 'private':
        await settings.setNotificationDetailLevel(
          NotificationDetailLevel.private,
        );
      case 'normal':
        await settings.setNotificationDetailLevel(
          NotificationDetailLevel.normal,
        );
      case 'locale':
        await settings.setLocaleTag(command['locale'] as String);
      case 'summary':
        await settings.setDueTodayNotificationTime('00:00');
        await settings.setNotifyDueToday(true);
      case 'disable-events':
        await settings.setNotifyEventReminders(false);
      case 'enable-events':
        await settings.setNotifyEventReminders(true);
      case 'sync-issue':
        final authorization =
            await (database.select(database.authorizationGenerations)
                  ..where((row) => row.accountId.equals('qa-microsoft')))
                .getSingleOrNull();
        await (database.update(
          database.accounts,
        )..where((row) => row.id.equals('qa-microsoft'))).write(
          const AccountsCompanion(authState: Value('reauth_required')),
        );
        await runtime.container
            .read(operationalNotificationCoordinatorProvider)
            .notifySyncFailure(
              AuthorizationScopedFailure(
                accountId: 'qa-microsoft',
                generation: authorization?.generation ?? 0,
                cause: const OAuthException(
                  'OAuthMissingToken',
                  'Reconnect required',
                ),
              ),
            );
      case 'conflict':
        await database
            .into(database.pendingOps)
            .insertOnConflictUpdate(
              PendingOpsCompanion.insert(
                id: 'qa-conflict',
                accountId: 'qa-microsoft',
                entityType: 'task',
                operation: 'patch',
                taskListId: const Value('qa-list'),
                taskId: const Value('qa-task'),
                requestJson: '{"title":"Synthetic local change"}',
                // Google/Microsoft replay protects blocked operations with a
                // terminal retry date; Diagnostics uses that same contract.
                state: const Value('pending'),
                nextAttemptAtUtc: Value(
                  DateTime.utc(9999, 12, 31).toIso8601String(),
                ),
                lastErrorCode: const Value('conflict'),
                createdAtUtc: now.toIso8601String(),
                updatedAtUtc: now.toIso8601String(),
              ),
            );
        await runtime.container
            .read(operationalNotificationCoordinatorProvider)
            .reconcile();
      case 'resolve-conflict':
        await (database.delete(
          database.pendingOps,
        )..where((row) => row.id.equals('qa-conflict'))).go();
        await runtime.container
            .read(operationalNotificationCoordinatorProvider)
            .reconcile();
      case 'recover-accounts':
        await database
            .update(database.accounts)
            .write(const AccountsCompanion(authState: Value('signed_in')));
        for (final id in ['qa-google', 'qa-microsoft']) {
          await runtime.container
              .read(operationalNotificationCoordinatorProvider)
              .clearAccountSyncFailure(id);
          await NotificationScheduleService(database: database)
              .rebuildUpcomingNotifications(id);
        }
      case 'snapshot':
        break;
      default:
        throw ArgumentError('Unknown QA command.');
    }
  }

  Future<void> snapshot() async {
    await runtime.notifications.refreshReadiness();
    final readiness = runtime.notifications.readiness.value;
    await record({
      'readiness': {
        'initialized': readiness.initialized,
        'notifications': readiness.notificationsAllowed,
        'reminders': readiness.remindersAllowed,
        'summaries': readiness.summariesAllowed,
        'status': readiness.statusAllowed,
        'exact': readiness.exactAlarms,
        'failed': readiness.failed,
      },
      'schedules': [
        for (final row
            in await database.select(database.notificationSchedule).get())
          {
            'id': row.id,
            'generation': row.generation,
            'sent': row.sentAtUtc,
            'dismissed': row.dismissedAtUtc,
            'snoozedUntil': row.snoozedUntilUtc,
            'expired': row.expiredAtUtc,
          },
      ],
    });
  }
}

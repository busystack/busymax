import 'package:intl/intl.dart';

import 'dart:async';
import 'dart:convert';

import 'package:busymax/src/app/app_settings.dart';
import 'package:busymax/src/core/auth/oauth_models.dart';
import 'package:busymax/src/core/http/request_dispatch_exception.dart';
import 'package:busymax/src/dav/ical/ical_task_alarm.dart';
import 'package:busymax/src/db/app_database.dart';
import 'package:busymax/src/features/notifications/desktop_notification_service.dart';
import 'package:busymax/src/features/notifications/notification_cancellation_queue.dart';
import 'package:busymax/src/features/notifications/notification_schedule_service.dart';
import 'package:busymax/src/features/notifications/notification_scheduler.dart';
import 'package:busymax/src/features/notifications/operational_notification_coordinator.dart';
import 'package:busymax/src/features/notifications/due_today_notification_scheduler.dart';
import 'package:busymax/src/schedule/schedule_repository.dart';
import 'package:busymax/src/schedule/schedule_filters.dart';
import 'package:busymax/src/features/tasks/domain/task_capabilities.dart';
import 'package:busymax/src/features/tasks/presentation/task_details_draft.dart';
import 'package:busymax/src/providers/busy_provider.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/recording_notification_backend.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase database;
  late RecordingNotificationBackend backend;
  late AppSettings settings;
  late DateTime now;
  late NotificationCancellationQueue cancellations;

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    backend = RecordingNotificationBackend();
    settings = AppSettings.defaults();
    now = DateTime.utc(2026, 6, 8, 8, 56);
    cancellations = NotificationCancellationQueue();
    await _account(database, 'a');
  });
  tearDown(() => database.close());

  DesktopNotificationService service() => DesktopNotificationService(
    backend: backend,
    settings: settings,
    now: () => now.toLocal(),
    cancellationQueue: cancellations,
    locale: const Locale('en'),
  );
  NotificationScheduleService schedules() =>
      NotificationScheduleService(database: database, nowUtc: () => now);
  NotificationScheduler scheduler() {
    final scheduler = NotificationScheduler(
      database: database,
      notifications: service(),
      nowUtc: () => now,
    );
    addTearDown(scheduler.stop);
    return scheduler;
  }

  test(
    'first import after the trigger delivers a still-upcoming occurrence',
    () async {
      await _event(database, offsets: [5]);
      await schedules().rebuildUpcomingNotifications('a');
      await scheduler().checkNow();
      expect(backend.requests.single.title, 'Basic French lesson');
      expect(
        backend.requests.single.body,
        contains(
          DateFormat.jm('en').format(DateTime.utc(2026, 6, 8, 9).toLocal()),
        ),
      );
      expect(
        backend.requests.single.body,
        contains('Contact: classroom & <lab>'),
      );
      expect(
        backend.requests.single.body,
        matches(RegExp(r'UTC[+−]\d{2}:\d{2}')),
      );
    },
  );

  test('several missed offsets consolidate durably to one catch-up', () async {
    await _event(database, offsets: [30, 10, 5]);
    await schedules().rebuildUpcomingNotifications('a');
    final initial = await database.select(database.notificationSchedule).get();
    expect(initial.where((row) => row.expiredAtUtc != null), hasLength(2));
    final runtime = scheduler();
    await runtime.checkNow();
    await schedules().rebuildUpcomingNotifications('a');
    await runtime.checkNow();
    expect(backend.requests, hasLength(1));
    expect(
      (await database.select(database.calendarEvents).getSingle()).isCancelled,
      isFalse,
    );
  });

  for (final delay in [const Duration(hours: 2), const Duration(days: 4)]) {
    test(
      'restart after $delay expires unsent rows without source mutation',
      () async {
        now = DateTime.utc(2026, 6, 8, 8);
        await _event(database, offsets: [30, 10, 5]);
        await schedules().rebuildUpcomingNotifications('a');
        now = DateTime.utc(2026, 6, 8, 9).add(delay);
        await schedules().rebuildUpcomingNotifications('a');
        await scheduler().checkNow();
        expect(backend.requests, isEmpty);
        expect(
          (await database.select(database.notificationSchedule).get()).every(
            (row) => row.expiredAtUtc != null,
          ),
          isTrue,
        );
        expect(
          await database.select(database.calendarEvents).get(),
          hasLength(1),
        );
      },
    );
  }

  test(
    'end-relative and absolute alarms remain intentional after event start',
    () async {
      await _account(database, 'dav', provider: BusyProvider.nextcloud);
      final alarms = [
        IcalTaskAlarm.displayRelative(
          const Duration(minutes: 15),
          relatedToDue: true,
        ),
        IcalTaskAlarm.displayAbsolute(DateTime.utc(2026, 6, 8, 11)),
      ];
      now = DateTime.utc(2026, 6, 8, 10, 16);
      await _event(
        database,
        account: 'dav',
        provider: 'nextcloud',
        alarms: alarms,
      );
      await schedules().rebuildUpcomingNotifications('dav');
      final runtime = scheduler();
      await runtime.checkNow();
      expect(backend.requests, hasLength(1));
      now = DateTime.utc(2026, 6, 8, 11, 1);
      await runtime.checkNow();
      expect(backend.requests, hasLength(2));
    },
  );

  test(
    'an explicit snooze past event end survives rebuilding and restart',
    () async {
      await _event(database, offsets: [5]);
      await schedules().rebuildUpcomingNotifications('a');
      final original = scheduler();
      await original.checkNow();
      now = DateTime.utc(2026, 6, 8, 11);
      await backend.invoke(0, 'snooze');
      original.stop();
      await schedules().rebuildUpcomingNotifications('a');
      now = now.add(const Duration(minutes: 10));
      await scheduler().checkNow();
      expect(backend.requests, hasLength(2));
    },
  );

  test(
    'privacy during a delayed native send withdraws the old content',
    () async {
      await _event(database, offsets: [5]);
      await schedules().rebuildUpcomingNotifications('a');
      backend.barrier = Completer<void>();
      final runtime = scheduler();
      final delivery = runtime.checkNow();
      await _until(() => backend.requests.isNotEmpty);
      settings = settings.copyWith(
        notificationDetailLevel: NotificationDetailLevel.private,
      );
      runtime.updateNotifications(service());
      backend.barrier!.complete();
      await delivery;
      expect(backend.activeIds, isEmpty);
      expect(backend.requests, hasLength(1));
      settings = settings.copyWith(
        notificationDetailLevel: NotificationDetailLevel.normal,
      );
      runtime.updateNotifications(service());
      await runtime.checkNow();
      expect(backend.requests, hasLength(1));
    },
  );

  test(
    'visible privacy cleanup retries after native cancellation failure',
    () async {
      await _event(database, offsets: [5]);
      await schedules().rebuildUpcomingNotifications('a');
      final runtime = scheduler();
      await runtime.checkNow();
      backend.cancellationFailuresRemaining = 1;
      settings = settings.copyWith(
        notificationDetailLevel: NotificationDetailLevel.private,
      );
      runtime.updateNotifications(service());
      await runtime.checkNow();
      await runtime.checkNow();
      await _until(() => backend.activeIds.isEmpty);
      expect(backend.activeIds, isEmpty);
      expect(backend.requests, hasLength(1));
    },
  );

  test('new private delivery stays visible across checks and unrelated settings changes', () async {
    settings = settings.copyWith(
      notificationDetailLevel: NotificationDetailLevel.private,
    );
    await _event(database, offsets: [5]);
    await schedules().rebuildUpcomingNotifications('a');
    final runtime = scheduler();
    await runtime.checkNow();
    final id = backend.requests.single.stableId;
    settings = settings.copyWith(
      themeModePreference: BusyMaxThemeModePreference.dark,
    );
    runtime.updateNotifications(service());
    await runtime.checkNow();
    await _until(() => backend.activeIds.contains(id));
    expect(backend.activeIds, {id});
    expect(backend.requests, hasLength(1));
    expect(backend.requests.single.body, isNot(contains('classroom')));
  });

  test('summary count and destination share all accounts and real deadlines, once per day', () async {
    await _account(database, 'b', provider: BusyProvider.microsoft);
    await _account(database, 'dav', provider: BusyProvider.nextcloud);
    for (final account in ['a', 'b', 'dav']) {
      await database
          .into(database.taskLists)
          .insert(
            TaskListsCompanion.insert(
              accountId: account,
              id: 'list-$account',
              title: 'Tasks',
              rawJson: '{}',
              createdLocalAtUtc: '',
              updatedLocalAtUtc: '',
            ),
          );
    }
    for (final (account, id, status, hidden, metadata) in [
      ('a', 'due-a', 'needsAction', false, '{}'),
      ('b', 'due-b', 'needsAction', false, '{}'),
      ('b', 'done', 'completed', false, '{}'),
      ('b', 'cancelled', 'cancelled', false, '{}'),
      ('b', 'hidden', 'needsAction', true, '{}'),
      (
        'dav',
        'start-only',
        'needsAction',
        false,
        '{"transport":"caldav","nativeStart":{"kind":"date","raw":"20260608"}}',
      ),
    ]) {
      await database
          .into(database.tasks)
          .insert(
            TasksCompanion.insert(
              accountId: account,
              taskListId: 'list-$account',
              id: id,
              title: id,
              dueUtc: const Value('2026-06-08'),
              status: Value(status),
              hidden: Value(hidden),
              providerMetadataJson: Value(metadata),
              rawJson: '{}',
              createdLocalAtUtc: '',
              updatedLocalAtUtc: '',
            ),
          );
    }
    now = DateTime(2026, 6, 8, 10).toUtc();
    settings = settings.copyWith(notifyDueToday: true);
    final summary = DueTodayNotificationScheduler(
      database: database,
      settings: () => settings,
      notifications: service,
      markNotified: (_) async {},
      now: () => now.toLocal(),
    );
    addTearDown(summary.stop);
    await summary.checkNow();
    expect(backend.requests.single.body, '2 tasks are due today.');
    expect(backend.requests.single.payload, {
      'notificationRoute': 'due-today',
      'date': '2026-06-08',
    });
    final destination = await ScheduleRepository(database).listAllTasks(
      filters: ScheduleFilters(
        includeCalendarEvents: false,
        notificationDeadline: DateTime(2026, 6, 8),
      ),
    );
    expect(destination.map((row) => row.id).toSet(), {'due-a', 'due-b'});
    await database
        .update(database.tasks)
        .write(const TasksCompanion(status: Value('completed')));
    await summary.checkNow();
    expect(backend.activeIds, isEmpty);
    await (database.update(database.tasks)
          ..where((row) => row.id.equals('due-a')))
        .write(const TasksCompanion(status: Value('needsAction')));
    await summary.checkNow();
    expect(backend.requests, hasLength(1));
  });

  for (final due in [null, '2026-06-08', '2026-06-07']) {
    test('new reminder default is future at 14:00 (due $due)', () {
      final value = TaskDetailsDraft.newReminderDefault(
        dueDate: due,
        timeZone: 'UTC',
        now: DateTime.utc(2026, 6, 8, 14),
      );
      expect(value.hour, 14);
      expect(value.minute, 10);
    });
  }
  test(
    'retired operational callbacks cannot reopen a closed database',
    () async {
      final retiredDatabase = AppDatabase.memoryForTests();
      final retired = OperationalNotificationCoordinator(
        database: retiredDatabase,
        settings: () => settings,
        transport: () =>
            throw StateError('A retired transport must not be read'),
      );
      retired.stop();
      await retiredDatabase.close();
      await retired.notifySyncFailure(
        const OAuthException('OAuthMissingToken', 'controlled'),
        accountId: 'a',
      );
      await retired.clearAccountSyncFailure('a');
      retired.settingsChanged(releaseDeferred: true);
      await retired.reconcile();
      expect(backend.requests, isEmpty);
    },
  );
  test('editor accepts the current minute but rejects a newly selected past minute', () {
    final draft = TaskDetailsDraft.forCreation(
      taskListId: 'list',
      provider: BusyProvider.microsoft,
      timeZone: 'UTC',
      reminder: DateTime.utc(2026, 6, 8, 14),
    );
    bool invalid(TaskDetailsDraft value) => value.hasNewPastReminder(
      capabilities: microsoftTaskCollectionCapabilities,
      localTimeZone: 'UTC',
      now: DateTime.utc(2026, 6, 8, 14, 0, 59),
    );
    expect(invalid(draft), isFalse);
    expect(invalid(draft.copyWith(microsoftReminderTime: '13:59')), isTrue);
  });

  for (final title in [
    'Basic French lesson',
    'Contact: 山田',
    'Location: <lab> & café',
    'Summary: اجتماع\nTomorrow',
  ]) {
    test('normal display text remains faithful: $title', () async {
      await service().notifyEventReminder(title, title);
      expect(backend.requests.single.title, title);
      expect(backend.requests.single.body, title);
      settings = settings.copyWith(
        notificationDetailLevel: NotificationDetailLevel.private,
      );
      await service().notifyTaskReminder(title, title);
      expect(backend.requests.last.title, isNot(contains(title)));
      expect(backend.requests.last.body, isNot(contains(title)));
    });
  }

  OperationalNotificationCoordinator coordinator() {
    final coordinator = OperationalNotificationCoordinator(
      database: database,
      settings: () => settings,
      now: () => now,
      transport: () => OperationalNotificationTransport(
        deliver: service().deliverOperationalIssue,
        cancel: service().cancelReminder,
      ),
    );
    addTearDown(coordinator.stop);
    return coordinator;
  }

  test('in-flight timeout is suppressed; per-account authentication issues deduplicate', () async {
    await _account(database, 'b');
    final runtime = coordinator();
    await runtime.notifySyncFailure(
      TimeoutException('transport timeout'),
      accountId: 'a',
    );
    expect(backend.requests, isEmpty);
    for (final id in ['a', 'a', 'b']) {
      await runtime.notifySyncFailure(
        const OAuthException('OAuthMissingToken', 'secret'),
        accountId: id,
      );
    }
    expect(backend.requests, hasLength(2));
    expect(backend.requests.map((row) => row.payload!['accountId']), [
      'a',
      'b',
    ]);
    expect(
      backend.requests.every((row) => !row.body.contains('secret')),
      isTrue,
    );
    await runtime.clearAccountSyncFailure('a');
    await runtime.notifySyncFailure(
      const OAuthException('OAuthMissingToken', 'secret'),
      accountId: 'a',
    );
    expect(backend.requests, hasLength(3));
  });

  test(
    'failed submission retries once due, and recovery cancels the opportunity',
    () async {
      final runtime = coordinator();
      backend.error = StateError('native unavailable');
      await runtime.notifySyncFailure(
        const OAuthException('OAuthMissingToken', 'secret'),
        accountId: 'a',
      );
      backend.error = null;
      await runtime.reconcile();
      expect(backend.requests, isEmpty);
      now = now.add(const Duration(minutes: 1));
      await runtime.reconcile();
      expect(backend.requests, hasLength(1));
      backend.error = StateError('native unavailable');
      await runtime.clearAccountSyncFailure('a');
      await runtime.notifySyncFailure(
        const OAuthException('OAuthMissingToken', 'secret'),
        accountId: 'a',
      );
      await runtime.clearAccountSyncFailure('a');
      backend.error = null;
      now = now.add(const Duration(minutes: 1));
      await runtime.reconcile();
      expect(backend.requests, hasLength(1));
    },
  );

  test(
    'reconnection invalidates a failed alert and late old authorization errors',
    () async {
      final runtime = coordinator();
      const error = AuthorizationScopedFailure(
        accountId: 'a',
        generation: 0,
        cause: OAuthException('OAuthMissingToken', 'secret'),
      );
      backend.error = StateError('native unavailable');
      await runtime.notifySyncFailure(error);
      // Explicit authorization replacement commits this generation with the
      // account. A successful network sync is not required for recovery.
      await database
          .into(database.authorizationGenerations)
          .insert(
            AuthorizationGenerationsCompanion.insert(
              accountId: 'a',
              generation: 1,
            ),
          );
      backend.error = null;
      now = now.add(const Duration(minutes: 1));
      await runtime.reconcile();
      expect(backend.requests, isEmpty);
      await runtime.notifySyncFailure(error);
      expect(backend.requests, isEmpty);
      await runtime.notifySyncFailure(
        const AuthorizationScopedFailure(
          accountId: 'a',
          generation: 1,
          cause: OAuthException('OAuthMissingToken', 'secret'),
        ),
      );
      expect(backend.requests, hasLength(1));
    },
  );

  test('authorization replacement during native submission withdraws the old issue', () async {
    final runtime = coordinator();
    backend.barrier = Completer<void>();
    final pending = runtime.notifySyncFailure(
      const AuthorizationScopedFailure(
        accountId: 'a',
        generation: 0,
        cause: OAuthException('OAuthMissingToken', 'secret'),
      ),
    );
    await _until(() => backend.requests.isNotEmpty);
    await database
        .into(database.authorizationGenerations)
        .insert(
          AuthorizationGenerationsCompanion.insert(
            accountId: 'a',
            generation: 1,
          ),
        );
    backend.barrier!.complete();
    await pending;
    expect(backend.activeIds, isEmpty);
  });

  for (final resolve in [false, true]) {
    test(
      'DAV unresolved conflict during quiet hours (resolve first: $resolve)',
      () async {
        settings = settings.copyWith(
          quietHoursEnabled: true,
          quietHoursStart: '22:00',
          quietHoursEnd: '07:00',
        );
        now = DateTime(2026, 6, 8, 23).toUtc();
        await database
            .into(database.pendingOps)
            .insert(
              PendingOpsCompanion.insert(
                id: 'dav-conflict',
                accountId: 'a',
                entityType: 'task',
                operation: 'patch',
                requestJson: '{}',
                state: const Value('conflict'),
                conflictState: const Value('unresolved'),
                createdAtUtc: '',
                updatedAtUtc: '',
              ),
            );
        final runtime = coordinator();
        await runtime.notifyConflict('raw provider content');
        expect(backend.requests, isEmpty);
        if (resolve) await database.delete(database.pendingOps).go();
        now = DateTime(2026, 6, 9, 7).toUtc();
        await runtime.reconcile();
        expect(backend.requests, hasLength(resolve ? 0 : 1));
        await runtime.reconcile();
        expect(backend.requests, hasLength(resolve ? 0 : 1));
        if (!resolve) {
          expect(backend.requests.single.payload, {
            'notificationRoute': 'conflict',
            'accountId': 'a',
          });
        }
      },
    );
  }
}

Future<void> _account(
  AppDatabase db,
  String id, {
  BusyProvider provider = BusyProvider.google,
}) async {
  await db
      .into(db.accounts)
      .insert(
        AccountsCompanion.insert(
          id: id,
          provider: provider.storageValue,
          authority: 'https://qa.invalid',
          providerAccountId: id,
          credentialKind: provider == BusyProvider.nextcloud
              ? 'nextcloud_app_password'
              : 'oauth',
          authState: const Value('signed_in'),
          createdAtUtc: '',
          updatedAtUtc: '',
        ),
      );
  await db
      .into(db.calendarSources)
      .insert(
        CalendarSourcesCompanion.insert(
          id: 'calendar-$id',
          accountId: id,
          provider: provider.storageValue,
          providerCalendarId: 'calendar',
          summary: 'Lessons',
          createdAtLocal: 0,
          updatedAtLocal: 0,
        ),
      );
}

Future<void> _event(
  AppDatabase db, {
  List<int> offsets = const [],
  String account = 'a',
  String provider = 'google',
  List<IcalTaskAlarm>? alarms,
}) async {
  await db
      .into(db.calendarEvents)
      .insert(
        CalendarEventsCompanion.insert(
          id: 'event-$account',
          accountId: account,
          calendarSourceId: 'calendar-$account',
          provider: provider,
          providerCalendarId: 'calendar',
          providerEventId: 'event',
          title: 'Basic French lesson',
          location: const Value('Contact: classroom & <lab>'),
          startDateTime: const Value('2026-06-08T09:00:00Z'),
          endDateTime: const Value('2026-06-08T10:00:00Z'),
          remindersJson: Value(
            jsonEncode(
              alarms == null
                  ? {
                      'overrides': [
                        for (final minutes in offsets)
                          {'method': 'popup', 'minutes': minutes},
                      ],
                    }
                  : {'alarms': alarms.map((alarm) => alarm.toJson()).toList()},
            ),
          ),
          createdAtLocal: 0,
          updatedAtLocal: 0,
        ),
      );
}

Future<void> _until(bool Function() condition) async {
  for (var i = 0; i < 200 && !condition(); i++) {
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  expect(condition(), isTrue);
}

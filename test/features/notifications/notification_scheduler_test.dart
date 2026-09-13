import 'dart:async';

import 'package:busymax/src/app/app_settings.dart';
import 'package:busymax/src/db/app_database.dart';
import 'package:busymax/src/features/notifications/desktop_notification_service.dart';
import 'package:busymax/src/features/notifications/notification_scheduler.dart';
import 'package:busymax/src/providers/busy_provider.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late _FakeNotificationBackend backend;
  late NotificationScheduler scheduler;
  late DateTime now;

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    backend = _FakeNotificationBackend();
    now = DateTime.utc(2026, 6, 8, 9);
    scheduler = NotificationScheduler(
      database: database,
      notifications: DesktopNotificationService(
        backend: backend,
        settings: AppSettings.defaults(),
      ),
      interval: const Duration(days: 1),
      nowUtc: () => now,
    );

    await database
        .into(database.accounts)
        .insert(
          AccountsCompanion.insert(
            id: 'microsoft:m',
            provider: BusyProvider.microsoft.storageValue,
            authority: 'https://login.microsoftonline.com/common',
            providerAccountId: 'm',
            credentialKind: 'oauth',
            authState: const Value('signed_in'),
            grantedScopes: const Value(''),
            createdAtUtc: '2026-06-08T00:00:00.000Z',
            updatedAtUtc: '2026-06-08T00:00:00.000Z',
          ),
        );
    await database
        .into(database.taskLists)
        .insert(
          TaskListsCompanion.insert(
            accountId: 'microsoft:m',
            id: 'list-1',
            title: 'Tasks',
            rawJson: '{}',
            createdLocalAtUtc: '',
            updatedLocalAtUtc: '',
          ),
        );
    for (final id in ['task-1', 'future-task']) {
      await database
          .into(database.tasks)
          .insert(
            TasksCompanion.insert(
              accountId: 'microsoft:m',
              taskListId: 'list-1',
              id: id,
              title: 'File report',
              rawJson: '{}',
              createdLocalAtUtc: '',
              updatedLocalAtUtc: '',
            ),
          );
    }
    await database
        .into(database.calendarSources)
        .insert(
          CalendarSourcesCompanion.insert(
            id: 'calendar',
            accountId: 'microsoft:m',
            provider: 'microsoft',
            providerCalendarId: 'calendar',
            summary: 'Calendar',
            createdAtLocal: 0,
            updatedAtLocal: 0,
          ),
        );
    await database
        .into(database.calendarEvents)
        .insert(
          CalendarEventsCompanion.insert(
            id: 'event-1',
            accountId: 'microsoft:m',
            calendarSourceId: 'calendar',
            provider: 'microsoft',
            providerCalendarId: 'calendar',
            providerEventId: 'event-1',
            title: 'Standup',
            createdAtLocal: 0,
            updatedAtLocal: 0,
          ),
        );
  });

  tearDown(() async {
    scheduler.stop();
    await database.close();
  });

  test(
    'cancellation failure retries without blocking an unrelated reminder',
    () async {
      await _insertDueTaskNotification(database, now);
      await scheduler.checkNow();
      final obsolete = backend.notifications.single.request.stableId;
      backend.cancellationError = StateError('notification center unavailable');
      await database.delete(database.notificationSchedule).go();
      await scheduler.checkNow();
      expect(backend.cancelledIds, isEmpty);
      expect(backend.cancellationAttempts, [obsolete]);
      await _insertDueTaskNotification(database, now);
      await scheduler.checkNow();
      expect(backend.notifications, hasLength(2));
      backend.cancellationError = null;
      await scheduler.checkNow();
      expect(backend.cancelledIds, [obsolete]);
      final attempts = backend.cancellationAttempts.length;
      await scheduler.checkNow();
      expect(backend.cancellationAttempts, hasLength(attempts));
    },
  );

  for (final status in ['completed', 'cancelled']) {
    test(
      'delivery revalidates a task changed to $status without a rebuild',
      () async {
        await _insertDueTaskNotification(database, now);
        await database
            .update(database.tasks)
            .write(TasksCompanion(status: Value(status)));
        await scheduler.checkNow();
        expect(backend.notifications, isEmpty);
        expect(
          await database.select(database.notificationSchedule).get(),
          isEmpty,
        );
      },
    );
  }

  test('delivery revalidates a cancelled event without a rebuild', () async {
    await database
        .into(database.notificationSchedule)
        .insert(
          NotificationScheduleCompanion.insert(
            id: 'event|event-1|5',
            accountId: 'microsoft:m',
            sourceType: 'event',
            sourceId: 'event-1',
            scheduledAtUtc: now.millisecondsSinceEpoch,
            title: 'Standup',
            createdAtLocal: 0,
            updatedAtLocal: 0,
          ),
        );
    await database
        .update(database.calendarEvents)
        .write(const CalendarEventsCompanion(isCancelled: Value(true)));
    await scheduler.checkNow();
    expect(backend.notifications, isEmpty);
    expect(await database.select(database.notificationSchedule).get(), isEmpty);
  });

  test('notifies when a due reminder is scheduled after startup', () async {
    scheduler.start();

    await database
        .into(database.notificationSchedule)
        .insert(
          NotificationScheduleCompanion.insert(
            id: 'task|microsoft:m|list-1|task-1',
            accountId: 'microsoft:m',
            sourceType: 'task',
            sourceId: 'task-1',
            scheduledAtUtc: DateTime.utc(2026, 6, 8, 9).millisecondsSinceEpoch,
            title: 'File report',
            createdAtLocal: 0,
            updatedAtLocal: 0,
          ),
        );

    await _waitUntil(() => backend.notifications.isNotEmpty);

    expect(backend.notifications.single.summary, 'File report');
    final rows = await database.select(database.notificationSchedule).get();
    expect(rows.single.sentAtUtc, isNotNull);
  });

  test('notifies at the next due time without waiting for polling', () async {
    final startedAt = DateTime.now();
    final baseNow = now;
    scheduler.stop();
    scheduler = NotificationScheduler(
      database: database,
      notifications: DesktopNotificationService(
        backend: backend,
        settings: AppSettings.defaults(),
      ),
      interval: const Duration(days: 1),
      nowUtc: () => baseNow.add(DateTime.now().difference(startedAt)),
    );
    scheduler.start();

    await database
        .into(database.notificationSchedule)
        .insert(
          NotificationScheduleCompanion.insert(
            id: 'task|microsoft:m|list-1|future-task',
            accountId: 'microsoft:m',
            sourceType: 'task',
            sourceId: 'future-task',
            scheduledAtUtc: baseNow
                .add(const Duration(milliseconds: 60))
                .millisecondsSinceEpoch,
            title: 'Future report',
            createdAtLocal: 0,
            updatedAtLocal: 0,
          ),
        );

    await _waitUntil(() => backend.notifications.isNotEmpty);

    expect(backend.notifications.single.summary, 'Future report');
  });

  test('notification activation receives due schedule row', () async {
    NotificationScheduleData? activatedRow;
    scheduler.stop();
    scheduler = NotificationScheduler(
      database: database,
      notifications: DesktopNotificationService(
        backend: backend,
        settings: AppSettings.defaults(),
      ),
      interval: const Duration(days: 1),
      nowUtc: () => now,
      onNotificationActivated: (row) async => activatedRow = row,
    );
    scheduler.start();

    await database
        .into(database.notificationSchedule)
        .insert(
          NotificationScheduleCompanion.insert(
            id: 'event|event-1|5',
            accountId: 'microsoft:m',
            sourceType: 'event',
            sourceId: 'event-1',
            scheduledAtUtc: DateTime.utc(2026, 6, 8, 9).millisecondsSinceEpoch,
            title: 'Standup',
            createdAtLocal: 0,
            updatedAtLocal: 0,
          ),
        );

    await _waitUntil(() => backend.notifications.isNotEmpty);
    await backend.notifications.single.invoke('default');

    expect(activatedRow?.id, 'event|event-1|5');
    expect(activatedRow?.sourceType, 'event');
    expect(activatedRow?.sourceId, 'event-1');
  });

  test('quiet hours defer a reminder without marking it sent', () async {
    var localNow = DateTime(2026, 6, 8, 9);
    now = localNow.toUtc();
    scheduler.stop();
    scheduler = NotificationScheduler(
      database: database,
      notifications: DesktopNotificationService(
        backend: backend,
        settings: AppSettings.defaults().copyWith(
          quietHoursEnabled: true,
          quietHoursStart: '08:00',
          quietHoursEnd: '10:00',
        ),
        now: () => localNow,
      ),
      interval: const Duration(days: 1),
      nowUtc: () => now,
    );
    await _insertDueTaskNotification(database, now);

    await scheduler.checkNow();

    var row = await database.select(database.notificationSchedule).getSingle();
    expect(backend.notifications, isEmpty);
    expect(row.sentAtUtc, null);

    localNow = DateTime(2026, 6, 8, 10);
    now = localNow.toUtc();
    await scheduler.checkNow();

    row = await database.select(database.notificationSchedule).getSingle();
    expect(backend.notifications, hasLength(1));
    expect(row.sentAtUtc, isNotNull);
  });

  test('disabled reminder setting keeps the reminder pending', () async {
    scheduler.stop();
    scheduler = NotificationScheduler(
      database: database,
      notifications: DesktopNotificationService(
        backend: backend,
        settings: AppSettings.defaults().copyWith(notifyTaskReminders: false),
      ),
      interval: const Duration(days: 1),
      nowUtc: () => now,
    );
    await _insertDueTaskNotification(database, now);

    await scheduler.checkNow();

    var row = await database.select(database.notificationSchedule).getSingle();
    expect(backend.notifications, isEmpty);
    expect(row.sentAtUtc, null);

    scheduler.stop();
    scheduler = NotificationScheduler(
      database: database,
      notifications: DesktopNotificationService(
        backend: backend,
        settings: AppSettings.defaults(),
      ),
      interval: const Duration(days: 1),
      nowUtc: () => now,
    );
    await scheduler.checkNow();

    row = await database.select(database.notificationSchedule).getSingle();
    expect(backend.notifications, hasLength(1));
    expect(row.sentAtUtc, isNotNull);
  });

  test(
    'notification backend failure retries without losing reminder',
    () async {
      backend.error = StateError('notification daemon unavailable');
      scheduler.stop();
      scheduler = NotificationScheduler(
        database: database,
        notifications: DesktopNotificationService(
          backend: backend,
          settings: AppSettings.defaults(),
          reminderFailureRetryDelay: const Duration(minutes: 5),
          now: () => now,
        ),
        interval: const Duration(days: 1),
        nowUtc: () => now,
      );
      await _insertDueTaskNotification(database, now);

      await scheduler.checkNow();

      var row = await database
          .select(database.notificationSchedule)
          .getSingle();
      expect(row.sentAtUtc, null);

      backend.error = null;
      now = now.add(const Duration(minutes: 4));
      await scheduler.checkNow();
      expect(backend.notifications, isEmpty);

      now = now.add(const Duration(minutes: 1));
      await scheduler.checkNow();
      row = await database.select(database.notificationSchedule).getSingle();
      expect(backend.notifications, hasLength(1));
      expect(row.sentAtUtc, isNotNull);
    },
  );

  test('snooze redelivers the reminder after ten minutes', () async {
    await _insertDueTaskNotification(database, now);

    await scheduler.checkNow();
    await backend.notifications.single.invoke('snooze');

    var row = await database.select(database.notificationSchedule).getSingle();
    expect(row.sentAtUtc, null);
    expect(
      row.snoozedUntilUtc,
      now.add(const Duration(minutes: 10)).millisecondsSinceEpoch,
    );

    now = now.add(const Duration(minutes: 9));
    await scheduler.checkNow();
    expect(backend.notifications, hasLength(1));

    now = now.add(const Duration(minutes: 1));
    await scheduler.checkNow();
    row = await database.select(database.notificationSchedule).getSingle();
    expect(backend.notifications, hasLength(2));
    expect(row.sentAtUtc, isNotNull);
    expect(row.snoozedUntilUtc, null);
  });

  test(
    'an immediate snooze action cannot be overwritten by delivery',
    () async {
      backend.actionBeforeReturn = 'snooze';
      await _insertDueTaskNotification(database, now);

      await scheduler.checkNow();

      final row = await database
          .select(database.notificationSchedule)
          .getSingle();
      expect(row.sentAtUtc, null);
      expect(
        row.snoozedUntilUtc,
        now.add(const Duration(minutes: 10)).millisecondsSinceEpoch,
      );
    },
  );

  test('dismiss prevents a delivered reminder from firing again', () async {
    await _insertDueTaskNotification(database, now);

    await scheduler.checkNow();
    final notification = backend.notifications.single;
    expect(notification.actions.map((action) => action.id), [
      'default',
      'snooze',
      'dismiss',
    ]);
    await notification.invoke('dismiss');

    final row = await database
        .select(database.notificationSchedule)
        .getSingle();
    expect(row.dismissedAtUtc, isNotNull);
    now = now.add(const Duration(hours: 1));
    await scheduler.checkNow();
    expect(backend.notifications, hasLength(1));
  });

  test('duplicate Windows activation is idempotent', () async {
    await _insertDueTaskNotification(database, now);
    await scheduler.checkNow();
    final row = await database
        .select(database.notificationSchedule)
        .getSingle();

    await scheduler.handleActivation(
      notificationScheduleId: row.id,
      notificationGeneration: row.generation,
      action: 'snooze',
    );
    final first = await database
        .select(database.notificationSchedule)
        .getSingle();
    expect(first.snoozedUntilUtc, isNotNull);
    now = now.add(const Duration(minutes: 1));
    await scheduler.handleActivation(
      notificationScheduleId: row.id,
      notificationGeneration: row.generation,
      action: 'snooze',
    );
    final duplicate = await database
        .select(database.notificationSchedule)
        .getSingle();

    expect(duplicate.snoozedUntilUtc, first.snoozedUntilUtc);
    expect(duplicate.updatedAtLocal, first.updatedAtLocal);
  });

  test('stop is terminal for visible callbacks and explicit checks', () async {
    await _insertDueTaskNotification(database, now);
    await scheduler.checkNow();
    final notification = backend.notifications.single;
    final before = await database
        .select(database.notificationSchedule)
        .getSingle();
    scheduler.stop();
    now = now.add(const Duration(days: 1));
    await notification.invoke('snooze');
    await notification.invoke('dismiss');
    scheduler.start();
    await scheduler.checkNow();
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(
      await database.select(database.notificationSchedule).getSingle(),
      before,
    );
    expect(backend.notifications, hasLength(1));
  });

  for (final changeGeneration in [false, true]) {
    test(
      'late delivery cannot mark a rescheduled reminder sent (generation=$changeGeneration)',
      () async {
        backend.deliveryBarrier = Completer<void>();
        await _insertDueTaskNotification(database, now);
        final checking = scheduler.checkNow();
        await _waitUntil(() => backend.notifications.isNotEmpty);
        final tomorrow = now.add(const Duration(days: 1));
        await database
            .update(database.notificationSchedule)
            .write(
              NotificationScheduleCompanion(
                scheduledAtUtc: Value(tomorrow.millisecondsSinceEpoch),
                generation: changeGeneration
                    ? const Value('tomorrow')
                    : const Value.absent(),
              ),
            );
        backend.deliveryBarrier!.complete();
        await checking;
        final row = await database
            .select(database.notificationSchedule)
            .getSingle();
        expect(row.sentAtUtc, isNull);
        expect(row.scheduledAtUtc, tomorrow.millisecondsSinceEpoch);
        expect(
          backend.cancelledIds,
          contains(backend.notifications.single.request.stableId),
        );
        now = tomorrow;
        await scheduler.checkNow();
        expect(backend.notifications, hasLength(2));
        expect(
          (await database.select(database.notificationSchedule).getSingle())
              .sentAtUtc,
          isNotNull,
        );
      },
    );
  }

  test(
    'stopped delivery cannot cancel or mark a replacement delivery',
    () async {
      final oldBarrier = Completer<void>();
      backend.deliveryBarrier = oldBarrier;
      await _insertDueTaskNotification(database, now);
      final retired = scheduler;
      final oldCheck = retired.checkNow();
      await _waitUntil(() => backend.notifications.isNotEmpty);
      retired.stop();
      backend.deliveryBarrier = null;
      scheduler = NotificationScheduler(
        database: database,
        notifications: DesktopNotificationService(
          backend: backend,
          settings: AppSettings.defaults(),
        ),
        nowUtc: () => now,
      );
      await scheduler.checkNow();
      final replacement = await database
          .select(database.notificationSchedule)
          .getSingle();
      oldBarrier.complete();
      await oldCheck;
      expect(
        await database.select(database.notificationSchedule).getSingle(),
        replacement,
      );
      expect(
        backend.cancelledIds,
        contains(backend.notifications.first.request.stableId),
      );
      expect(
        backend.cancelledIds,
        isNot(contains(backend.notifications.last.request.stableId)),
      );
      await retired.checkNow();
      expect(backend.notifications, hasLength(2));
    },
  );

  for (final action in ['dismiss', 'snooze', 'default']) {
    test(
      'old $action cannot affect a new delivery with the same schedule ID',
      () async {
        await _insertDueTaskNotification(database, now);
        await scheduler.checkNow();
        final old = backend.notifications.single;
        now = now.add(const Duration(days: 1));
        await database
            .update(database.notificationSchedule)
            .write(
              NotificationScheduleCompanion(
                scheduledAtUtc: Value(now.millisecondsSinceEpoch),
                generation: const Value('rescheduled'),
                sentAtUtc: const Value(null),
              ),
            );
        await scheduler.checkNow();
        final current = await database
            .select(database.notificationSchedule)
            .getSingle();
        expect(backend.cancelledIds, contains(old.request.stableId));
        await old.invoke(action);
        await scheduler.handleActivation(
          notificationScheduleId: current.id,
          notificationGeneration:
              old.request.payload!['notificationGeneration']!,
          action: action,
        );
        expect(
          await database.select(database.notificationSchedule).getSingle(),
          current,
        );
        expect(backend.notifications, hasLength(2));
        expect(
          backend.cancelledIds,
          isNot(contains(backend.notifications.last.request.stableId)),
        );
      },
    );
  }

  test(
    'removing a schedule cancels its displayed notification automatically',
    () async {
      await _insertDueTaskNotification(database, now);
      await scheduler.checkNow();
      scheduler.start();
      final old = backend.notifications.single;
      await database.delete(database.notificationSchedule).go();
      await _waitUntil(
        () => backend.cancelledIds.contains(old.request.stableId),
      );
      await old.invoke('snooze');
      expect(
        await database.select(database.notificationSchedule).get(),
        isEmpty,
      );
    },
  );

  test(
    'an old snooze cannot act on a reminder removed and recreated at the same time',
    () async {
      await _insertDueTaskNotification(database, now);
      await scheduler.checkNow();
      final old = backend.notifications.single;
      await database.delete(database.notificationSchedule).go();
      await _insertDueTaskNotification(database, now);
      await scheduler.checkNow();
      final current = await database
          .select(database.notificationSchedule)
          .getSingle();
      await old.invoke('snooze');
      expect(
        await database.select(database.notificationSchedule).getSingle(),
        current,
      );
    },
  );

  for (final quiet in [false, true]) {
    test('visible snooze uses updated settings (quiet=$quiet)', () async {
      await _insertDueTaskNotification(database, now);
      await scheduler.checkNow();
      final old = backend.notifications.single;
      scheduler.updateNotifications(
        DesktopNotificationService(
          backend: backend,
          settings: AppSettings.defaults().copyWith(
            notifyTaskReminders: quiet,
            quietHoursEnabled: quiet,
            quietHoursStart: '00:00',
            quietHoursEnd: '23:59',
          ),
          now: () => now,
        ),
      );
      await old.invoke('snooze');
      now = now.add(const Duration(minutes: 11));
      await scheduler.checkNow();
      expect(backend.notifications, hasLength(1));
      expect(
        (await database.select(database.notificationSchedule).getSingle())
            .sentAtUtc,
        isNull,
      );
    });
  }

  test(
    'settings changed during delivery apply to the remaining due reminders',
    () async {
      await _insertDueTaskNotification(database, now);
      final row = await database
          .select(database.notificationSchedule)
          .getSingle();
      await database
          .into(database.notificationSchedule)
          .insert(row.copyWith(id: 'second'));
      backend.deliveryBarrier = Completer<void>();
      final checking = scheduler.checkNow();
      await _waitUntil(() => backend.notifications.isNotEmpty);
      scheduler.updateNotifications(
        DesktopNotificationService(
          backend: backend,
          settings: AppSettings.defaults().copyWith(notifyTaskReminders: false),
        ),
      );
      backend.deliveryBarrier!.complete();
      await checking;
      expect(backend.notifications, hasLength(1));
      final rows = await database.select(database.notificationSchedule).get();
      expect(rows.where((row) => row.sentAtUtc == null), hasLength(1));
    },
  );

  test('does not notify for a signed-out account', () async {
    await database
        .into(database.accounts)
        .insert(
          AccountsCompanion.insert(
            id: 'google:g',
            provider: BusyProvider.google.storageValue,
            authority: 'https://accounts.google.com',
            providerAccountId: 'g',
            credentialKind: 'oauth',
            authState: const Value('signed_out'),
            grantedScopes: const Value(''),
            createdAtUtc: '2026-06-08T00:00:00.000Z',
            updatedAtUtc: '2026-06-08T00:00:00.000Z',
          ),
        );
    await database
        .into(database.notificationSchedule)
        .insert(
          NotificationScheduleCompanion.insert(
            id: 'event|google:g|event-1|5',
            accountId: 'google:g',
            sourceType: 'event',
            sourceId: 'event-1',
            scheduledAtUtc: now.millisecondsSinceEpoch,
            title: 'Private appointment',
            body: const Value('Private details'),
            createdAtLocal: 0,
            updatedAtLocal: 0,
          ),
        );

    await scheduler.checkNow();
    scheduler.stop();

    expect(backend.notifications, isEmpty);
  });
}

Future<void> _waitUntil(
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 1),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      fail('Timed out waiting for condition.');
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

Future<void> _insertDueTaskNotification(
  AppDatabase database,
  DateTime scheduledAt,
) {
  return database
      .into(database.notificationSchedule)
      .insert(
        NotificationScheduleCompanion.insert(
          id: 'task|microsoft:m|list-1|task-1',
          accountId: 'microsoft:m',
          sourceType: 'task',
          sourceId: 'task-1',
          scheduledAtUtc: scheduledAt.millisecondsSinceEpoch,
          title: 'File report',
          createdAtLocal: 0,
          updatedAtLocal: 0,
        ),
      );
}

class _FakeNotificationBackend implements DesktopNotificationBackend {
  final notifications = <_NotificationRecord>[];
  final cancelledIds = <String>[];
  final cancellationAttempts = <String>[];
  Object? cancellationError;
  Completer<void>? deliveryBarrier;
  Object? error;
  String? actionBeforeReturn;

  @override
  Future<void> notify(
    BusyMaxNotificationRequest request, {
    DesktopNotificationActionHandler? onAction,
  }) async {
    final failure = error;
    if (failure != null) throw failure;
    notifications.add(_NotificationRecord(request, onAction));
    await deliveryBarrier?.future;
    final immediateAction = actionBeforeReturn;
    if (immediateAction != null) {
      actionBeforeReturn = null;
      await onAction?.call(immediateAction, request.payload);
    }
  }

  @override
  Future<void> cancel(String stableId) async {
    cancellationAttempts.add(stableId);
    if (cancellationError != null) throw cancellationError!;
    cancelledIds.add(stableId);
  }

  @override
  Future<void> close() async {}
}

class _NotificationRecord {
  const _NotificationRecord(this.request, this.onAction);

  final BusyMaxNotificationRequest request;
  final DesktopNotificationActionHandler? onAction;

  String get summary => request.title;
  String get body => request.body;
  List<BusyMaxNotificationAction> get actions => request.actions;

  Future<void> invoke(String action) async {
    await onAction?.call(action, request.payload);
  }
}

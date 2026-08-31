import 'package:busymax/src/app/app_settings.dart';
import 'package:busymax/src/db/app_database.dart';
import 'package:busymax/src/features/notifications/desktop_notification_service.dart';
import 'package:busymax/src/features/notifications/notification_scheduler.dart';
import 'package:busymax/src/providers/busy_provider.dart';
import 'package:drift/drift.dart' hide isNotNull;
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
  });

  tearDown(() async {
    scheduler.stop();
    await database.close();
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
    final immediateAction = actionBeforeReturn;
    if (immediateAction != null) {
      actionBeforeReturn = null;
      await onAction?.call(immediateAction, request.payload);
    }
  }

  @override
  Future<void> cancel(String stableId) async {}

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

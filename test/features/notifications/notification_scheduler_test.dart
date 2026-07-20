import 'package:busymax/src/app/app_settings.dart';
import 'package:busymax/src/db/app_database.dart';
import 'package:busymax/src/features/notifications/desktop_notification_service.dart';
import 'package:busymax/src/features/notifications/notification_scheduler.dart';
import 'package:busymax/src/task_providers/task_provider.dart';
import 'package:desktop_notifications/desktop_notifications.dart';
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
            provider: Value(TaskProvider.microsoft.storageValue),
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
    await backend.notifications.single.onAction?.call('default');

    expect(activatedRow?.id, 'event|event-1|5');
    expect(activatedRow?.sourceType, 'event');
    expect(activatedRow?.sourceId, 'event-1');
  });

  test('does not notify for a signed-out account', () async {
    await database
        .into(database.accounts)
        .insert(
          AccountsCompanion.insert(
            id: 'google:g',
            provider: Value(TaskProvider.google.storageValue),
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

class _FakeNotificationBackend implements DesktopNotificationBackend {
  final notifications = <_NotificationRecord>[];

  @override
  Future<void> notify(
    String summary, {
    String body = '',
    List<NotificationHint> hints = const [],
    List<NotificationAction> actions = const [],
    DesktopNotificationActionHandler? onAction,
  }) async {
    notifications.add(_NotificationRecord(summary, body, actions, onAction));
  }

  @override
  Future<void> close() async {}
}

class _NotificationRecord {
  const _NotificationRecord(
    this.summary,
    this.body,
    this.actions,
    this.onAction,
  );

  final String summary;
  final String body;
  final List<NotificationAction> actions;
  final DesktopNotificationActionHandler? onAction;
}

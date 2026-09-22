import 'package:busymax/src/android/android_notifications.dart';
import 'package:busymax/src/app/app_settings.dart';
import 'package:busymax/src/core/time/stored_temporal_projection.dart';
import 'package:busymax/src/db/app_database.dart';
import 'package:busymax/src/providers/busy_provider.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/timezone.dart' as tz;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const platformChannel = MethodChannel('io.busystack.busymax/android');
  late AppDatabase database;
  late _StatefulNotificationPlugin plugin;
  late AppSettings settings;

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    plugin = _StatefulNotificationPlugin();
    settings = AppSettings.defaults().copyWith(notifyDueToday: false);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(platformChannel, (call) async {
          if (call.method == 'acquireAccountGate') return 'test-lease';
          return null;
        });
    await database
        .into(database.accounts)
        .insert(
          AccountsCompanion.insert(
            id: 'google:test',
            provider: BusyProvider.google.storageValue,
            authority: 'google',
            providerAccountId: 'test',
            credentialKind: 'oauth',
            authState: const Value('signed_in'),
            createdAtUtc: DateTime.now().toUtc().toIso8601String(),
            updatedAtUtc: DateTime.now().toUtc().toIso8601String(),
          ),
        );
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(platformChannel, null);
    await database.close();
  });

  AndroidNotificationService service({bool exact = false}) =>
      AndroidNotificationService(
        database: database,
        settings: () => settings,
        backend: plugin,
        exactAlarmCapability: () async => exact,
      );

  test(
    'reconciliation preserves a delivered notification still visible',
    () async {
      await _insertReminder(
        database,
        generation: 'generation-1',
        scheduledAt: DateTime.now().subtract(const Duration(hours: 1)),
      );
      await _insertMapping(
        database,
        generation: 'generation-1',
        platformId: 42,
        state: androidNotificationRegistrationState(
          settings: settings,
          exact: false,
        ),
      );
      plugin.activeIds.add(42);
      final notifications = service();
      await notifications.initialize(timeZoneId: 'America/Vancouver');

      await notifications.reconcile();

      expect(plugin.cancelledIds, isNot(contains(42)));
      expect(plugin.scheduledIds, isNot(contains(42)));
      expect(
        await database.select(database.androidNotificationMappings).get(),
        hasLength(1),
      );
    },
  );

  test('a stale active generation is canceled without reposting', () async {
    await _insertReminder(
      database,
      generation: 'generation-2',
      scheduledAt: DateTime.now().subtract(const Duration(hours: 1)),
    );
    await _insertMapping(
      database,
      generation: 'generation-1',
      platformId: 42,
      state: androidNotificationRegistrationState(
        settings: settings,
        exact: false,
      ),
    );
    plugin.activeIds.add(42);
    final notifications = service();
    await notifications.initialize(timeZoneId: 'Etc/UTC');

    await notifications.reconcile();

    expect(plugin.cancelledIds, contains(42));
    expect(plugin.scheduledIds, isEmpty);
    expect(
      await database.select(database.androidNotificationMappings).get(),
      isEmpty,
    );
  });

  test(
    'dismissed reminders are removed even when the old post is active',
    () async {
      await _insertReminder(
        database,
        generation: 'generation-1',
        scheduledAt: DateTime.now().subtract(const Duration(hours: 1)),
        dismissed: true,
      );
      await _insertMapping(
        database,
        generation: 'generation-1',
        platformId: 42,
        state: androidNotificationRegistrationState(
          settings: settings,
          exact: false,
        ),
      );
      plugin.activeIds.add(42);
      final notifications = service();
      await notifications.initialize(timeZoneId: 'Etc/UTC');

      await notifications.reconcile();

      expect(plugin.cancelledIds, contains(42));
      expect(
        await database.select(database.androidNotificationMappings).get(),
        isEmpty,
      );
    },
  );

  test('an overdue inexact alarm remains registered while pending', () async {
    final scheduledAt = DateTime.now().subtract(const Duration(minutes: 30));
    await _insertReminder(
      database,
      generation: 'generation-1',
      scheduledAt: scheduledAt,
    );
    final state = androidNotificationRegistrationState(
      settings: settings,
      exact: false,
      title: 'Visible meeting',
    );
    await _insertMapping(
      database,
      generation: 'generation-1',
      platformId: 42,
      state: state,
      scheduledAt: scheduledAt,
    );
    plugin.pendingIds.add(42);
    final notifications = service();
    await notifications.initialize(timeZoneId: 'America/Vancouver');

    await notifications.reconcile();

    expect(plugin.cancelledIds, isNot(contains(42)));
    expect(plugin.scheduledIds, isNot(contains(42)));
  });

  test('snooze generation schedules its future effective time', () async {
    final now = DateTime.now();
    await database
        .into(database.notificationSchedule)
        .insert(
          NotificationScheduleCompanion.insert(
            id: 'reminder-1',
            generation: const Value('generation-1:snooze'),
            accountId: 'google:test',
            sourceType: 'event',
            sourceId: 'event-1',
            scheduledAtUtc: now
                .subtract(const Duration(hours: 1))
                .millisecondsSinceEpoch,
            snoozedUntilUtc: Value(
              now.add(const Duration(hours: 1)).millisecondsSinceEpoch,
            ),
            title: 'Snoozed meeting',
            createdAtLocal: 0,
            updatedAtLocal: 0,
          ),
        );
    final notifications = service();
    await notifications.initialize(timeZoneId: 'America/Vancouver');

    await notifications.reconcile();

    expect(plugin.scheduledIds, hasLength(1));
    final mapping = await database
        .select(database.androidNotificationMappings)
        .getSingle();
    expect(mapping.generation, 'generation-1:snooze');
    expect(
      mapping.scheduledAtUtc,
      now.add(const Duration(hours: 1)).millisecondsSinceEpoch,
    );
  });

  test('quiet-hours deferral survives a second reconciliation', () async {
    final notifications = service();
    await notifications.initialize(timeZoneId: 'America/Vancouver');
    final today = tz.TZDateTime.now(tz.local);
    final requested = tz.TZDateTime(
      tz.local,
      today.year,
      today.month,
      today.day + 1,
      23,
    );
    settings = settings.copyWith(
      quietHoursEnabled: true,
      quietHoursStart: '22:00',
      quietHoursEnd: '07:00',
    );
    await _insertReminder(
      database,
      generation: 'generation-1',
      scheduledAt: requested,
    );

    await notifications.reconcile();
    final mapping = await database
        .select(database.androidNotificationMappings)
        .getSingle();
    expect(
      mapping.scheduledAtUtc,
      greaterThan(requested.millisecondsSinceEpoch),
    );
    final platformId = mapping.platformId;
    plugin.cancelledIds.clear();
    plugin.scheduled.clear();

    await notifications.reconcile();

    expect(plugin.cancelledIds, isNot(contains(platformId)));
    expect(plugin.scheduledIds, isNot(contains(platformId)));
  });

  test('content-only edits replace an unchanged pending reminder', () async {
    final scheduledAt = DateTime.now().add(const Duration(hours: 1));
    await _insertReminder(
      database,
      generation: 'generation-1',
      scheduledAt: scheduledAt,
    );
    final notifications = service();
    await notifications.initialize(timeZoneId: 'America/Vancouver');
    await notifications.reconcile();
    final mapping = await database
        .select(database.androidNotificationMappings)
        .getSingle();
    final platformId = mapping.platformId;
    plugin.cancelledIds.clear();
    plugin.scheduled.clear();

    await (database.update(
      database.notificationSchedule,
    )..where((table) => table.id.equals('reminder-1'))).write(
      const NotificationScheduleCompanion(
        title: Value('Renamed meeting'),
        body: Value('Updated location'),
      ),
    );
    await notifications.reconcile();

    expect(plugin.cancelledIds, contains(platformId));
    expect(plugin.scheduledIds, contains(platformId));
    final call = plugin.scheduled.single;
    expect(call.title, 'Renamed meeting');
    expect(call.body, 'Updated location');
    final updatedMapping = await database
        .select(database.androidNotificationMappings)
        .getSingle();
    expect(updatedMapping.generation, 'generation-1');
    expect(
      updatedMapping.state,
      androidNotificationRegistrationState(
        settings: settings,
        exact: false,
        title: 'Renamed meeting',
        body: 'Updated location',
      ),
    );
  });

  test(
    'overdue pending summary is replaced after privacy and precision change',
    () async {
      await _insertDueTodayTask(database);
      final dueTask = await database.select(database.tasks).getSingle();
      expect(taskDueAsLocal(dueTask), isNotNull);
      expect(taskDueAsLocal(dueTask)!.day, DateTime.now().day);
      final previousSettings = settings;
      final localDate = _today();
      await database
          .into(database.androidDailySummarySchedules)
          .insert(
            AndroidDailySummarySchedulesCompanion.insert(
              localDate: localDate,
              platformId: 0x425903,
              generation: 'old',
              scheduledAtUtc: DateTime.now()
                  .subtract(const Duration(hours: 1))
                  .millisecondsSinceEpoch,
              taskCount: 1,
              state: Value(
                androidNotificationRegistrationState(
                  settings: previousSettings,
                  exact: false,
                ),
              ),
              updatedAtUtc: 0,
            ),
          );
      plugin.pendingIds.add(0x425903);
      plugin.activeQueryFails = true;
      settings = settings.copyWith(
        notifyDueToday: true,
        notificationDetailLevel: NotificationDetailLevel.private,
      );
      final notifications = service(exact: true);
      await notifications.initialize(timeZoneId: 'America/Vancouver');

      await notifications.reconcile();

      expect(plugin.cancelledIds, contains(0x425903));
      expect(plugin.scheduledIds, contains(0x425903));
      final call = plugin.scheduled.lastWhere((value) => value.id == 0x425903);
      expect(call.body, isNull);
      expect(call.mode, AndroidScheduleMode.exactAllowWhileIdle);
      final row = await database
          .select(database.androidDailySummarySchedules)
          .getSingle();
      expect(
        row.state,
        androidNotificationRegistrationState(
          settings: settings,
          exact: true,
          title: const AndroidNotificationStrings().dueTodayTitle,
        ),
      );
    },
  );

  test('server-missing due-today task cancels the existing summary', () async {
    settings = settings.copyWith(notifyDueToday: true);
    final notifications = service();
    await notifications.initialize(timeZoneId: 'America/Vancouver');
    await _insertDueTodayTask(database);

    await notifications.reconcile();

    const summaryId = 0x425903;
    final scheduled = await database
        .select(database.androidDailySummarySchedules)
        .getSingle();
    expect(scheduled.taskCount, 1);
    expect(plugin.pendingIds, contains(summaryId));

    await database
        .update(database.tasks)
        .write(const TasksCompanion(serverMissing: Value(true)));
    plugin.cancelledIds.clear();
    plugin.scheduled.clear();

    await notifications.reconcile();

    expect(plugin.cancelledIds, contains(summaryId));
    expect(plugin.scheduledIds, isEmpty);
    expect(
      await database.select(database.androidDailySummarySchedules).get(),
      isEmpty,
    );
  });
}

Future<void> _insertReminder(
  AppDatabase database, {
  required String generation,
  required DateTime scheduledAt,
  bool dismissed = false,
}) => database
    .into(database.notificationSchedule)
    .insert(
      NotificationScheduleCompanion.insert(
        id: 'reminder-1',
        generation: Value(generation),
        accountId: 'google:test',
        sourceType: 'event',
        sourceId: 'event-1',
        scheduledAtUtc: scheduledAt.millisecondsSinceEpoch,
        title: 'Visible meeting',
        dismissedAtUtc: dismissed
            ? Value(DateTime.now().millisecondsSinceEpoch)
            : const Value.absent(),
        createdAtLocal: 0,
        updatedAtLocal: 0,
      ),
    );

Future<void> _insertMapping(
  AppDatabase database, {
  required String generation,
  required int platformId,
  required String state,
  DateTime? scheduledAt,
}) => database
    .into(database.androidNotificationMappings)
    .insert(
      AndroidNotificationMappingsCompanion.insert(
        scheduleId: 'reminder-1',
        generation: generation,
        platformId: platformId,
        scheduledAtUtc:
            (scheduledAt ?? DateTime.now().subtract(const Duration(hours: 1)))
                .millisecondsSinceEpoch,
        state: Value(state),
        updatedAtUtc: 0,
      ),
    );

Future<void> _insertDueTodayTask(AppDatabase database) async {
  await database
      .into(database.taskLists)
      .insert(
        TaskListsCompanion.insert(
          accountId: 'google:test',
          id: 'list-1',
          title: 'Tasks',
          rawJson: '{}',
          createdLocalAtUtc: '',
          updatedLocalAtUtc: '',
        ),
      );
  final today = DateTime.now();
  await database
      .into(database.tasks)
      .insert(
        TasksCompanion.insert(
          accountId: 'google:test',
          taskListId: 'list-1',
          id: 'task-1',
          title: 'Due today',
          dueUtc: Value(
            DateTime(today.year, today.month, today.day, 12).toIso8601String(),
          ),
          rawJson: '{}',
          createdLocalAtUtc: '',
          updatedLocalAtUtc: '',
        ),
      );
}

String _today() {
  final now = DateTime.now();
  return '${now.year.toString().padLeft(4, '0')}-'
      '${now.month.toString().padLeft(2, '0')}-'
      '${now.day.toString().padLeft(2, '0')}';
}

class _StatefulNotificationPlugin implements AndroidNotificationBackend {
  final Set<int> pendingIds = {};
  final Set<int> activeIds = {};
  final List<int> cancelledIds = [];
  final List<({int id, String? title, String? body, AndroidScheduleMode mode})>
  scheduled = [];
  bool activeQueryFails = false;

  Iterable<int> get scheduledIds => scheduled.map((value) => value.id);

  @override
  Future<bool?> initialize({
    required InitializationSettings settings,
    DidReceiveNotificationResponseCallback? onDidReceiveNotificationResponse,
    DidReceiveBackgroundNotificationResponseCallback?
    onDidReceiveBackgroundNotificationResponse,
  }) async => true;

  @override
  Future<NotificationAppLaunchDetails?>
  getNotificationAppLaunchDetails() async =>
      const NotificationAppLaunchDetails(false);

  @override
  Future<List<PendingNotificationRequest>>
  pendingNotificationRequests() async => [
    for (final id in pendingIds)
      PendingNotificationRequest(id, null, null, null),
  ];

  @override
  Future<List<ActiveNotification>> getActiveNotifications() async {
    if (activeQueryFails) throw StateError('active query unavailable');
    return [for (final id in activeIds) ActiveNotification(id: id)];
  }

  @override
  Future<void> cancel({required int id, String? tag}) async {
    cancelledIds.add(id);
    pendingIds.remove(id);
    activeIds.remove(id);
  }

  @override
  Future<void> zonedSchedule({
    required int id,
    required tz.TZDateTime scheduledDate,
    required NotificationDetails notificationDetails,
    required AndroidScheduleMode androidScheduleMode,
    String? title,
    String? body,
    String? payload,
    DateTimeComponents? matchDateTimeComponents,
  }) async {
    scheduled.add((
      id: id,
      title: title,
      body: body,
      mode: androidScheduleMode,
    ));
    pendingIds.add(id);
  }

  @override
  Future<void> show({
    required int id,
    String? title,
    String? body,
    required NotificationDetails notificationDetails,
  }) async {}

  @override
  Future<bool> requestNotificationPermission() async => true;

  @override
  Future<bool> requestExactAlarmPermission() async => true;

  @override
  Future<bool> canScheduleExactly() async => false;
}

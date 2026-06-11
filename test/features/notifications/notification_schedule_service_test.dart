import 'dart:convert';

import 'package:busymax/src/calendar_providers/calendar_sync_dto.dart';
import 'package:busymax/src/db/app_database.dart';
import 'package:busymax/src/features/calendar/data/calendar_repository.dart';
import 'package:busymax/src/features/calendar/presentation/event_editor_draft.dart';
import 'package:busymax/src/features/notifications/notification_schedule_service.dart';
import 'package:busymax/src/task_providers/task_provider.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late NotificationScheduleService service;

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    service = NotificationScheduleService(
      database: database,
      nowUtc: () => DateTime.utc(2026, 6, 8, 8),
    );
    await _insertAccount(
      database,
      id: 'google:g',
      provider: TaskProvider.google,
    );
    await _insertAccount(
      database,
      id: 'microsoft:m',
      provider: TaskProvider.microsoft,
    );
  });

  tearDown(() async {
    await database.close();
  });

  test('Google event popup reminder schedules notification', () async {
    await _upsertEvent(
      database,
      accountId: 'google:g',
      provider: TaskProvider.google,
      remindersJson: {
        'useDefault': false,
        'overrides': [
          {'method': 'popup', 'minutes': 10},
        ],
      },
    );

    await service.rebuildUpcomingEventNotifications('google:g');

    final rows = await database.select(database.notificationSchedule).get();
    expect(rows.single.sourceType, 'event');
    expect(
      rows.single.scheduledAtUtc,
      DateTime.utc(2026, 6, 8, 8, 50).millisecondsSinceEpoch,
    );
  });

  test('Microsoft event reminder schedules notification', () async {
    await _upsertEvent(
      database,
      accountId: 'microsoft:m',
      provider: TaskProvider.microsoft,
      remindersJson: {'isReminderOn': true, 'reminderMinutesBeforeStart': 30},
    );

    await service.rebuildUpcomingEventNotifications('microsoft:m');

    final rows = await database.select(database.notificationSchedule).get();
    expect(
      rows.single.scheduledAtUtc,
      DateTime.utc(2026, 6, 8, 8, 30).millisecondsSinceEpoch,
    );
  });

  test('Microsoft UTC event reminder uses event timezone', () async {
    await _upsertEvent(
      database,
      accountId: 'microsoft:m',
      provider: TaskProvider.microsoft,
      startDateTime: '2026-06-08T09:00:00',
      startTimeZone: 'UTC',
      remindersJson: {'isReminderOn': true, 'reminderMinutesBeforeStart': 30},
    );

    await service.rebuildUpcomingEventNotifications('microsoft:m');

    final rows = await database.select(database.notificationSchedule).get();
    expect(
      rows.single.scheduledAtUtc,
      DateTime.utc(2026, 6, 8, 8, 30).millisecondsSinceEpoch,
    );
  });

  test('Microsoft local event reminder keeps local wall time', () async {
    await _upsertEvent(
      database,
      accountId: 'microsoft:m',
      provider: TaskProvider.microsoft,
      startDateTime: '2026-06-08T09:00:00',
      startTimeZone: 'America/Vancouver',
      remindersJson: {'isReminderOn': true, 'reminderMinutesBeforeStart': 30},
    );

    await service.rebuildUpcomingEventNotifications('microsoft:m');

    final rows = await database.select(database.notificationSchedule).get();
    expect(
      rows.single.scheduledAtUtc,
      DateTime(2026, 6, 8, 8, 30).toUtc().millisecondsSinceEpoch,
    );
  });

  test('missed event reminder before event start fires immediately', () async {
    service = NotificationScheduleService(
      database: database,
      nowUtc: () => DateTime.utc(2026, 6, 8, 4, 21, 30),
    );
    await _upsertEvent(
      database,
      accountId: 'microsoft:m',
      provider: TaskProvider.microsoft,
      startDateTime: '2026-06-08T04:26:00.000Z',
      remindersJson: {'isReminderOn': true, 'reminderMinutesBeforeStart': 5},
    );

    await service.rebuildUpcomingEventNotifications('microsoft:m');

    final rows = await database.select(database.notificationSchedule).get();
    expect(
      rows.single.scheduledAtUtc,
      DateTime.utc(2026, 6, 8, 4, 21, 30).millisecondsSinceEpoch,
    );
  });

  test('missed event reminder after event start is not scheduled', () async {
    service = NotificationScheduleService(
      database: database,
      nowUtc: () => DateTime.utc(2026, 6, 8, 4, 26, 30),
    );
    await _upsertEvent(
      database,
      accountId: 'microsoft:m',
      provider: TaskProvider.microsoft,
      startDateTime: '2026-06-08T04:26:00.000Z',
      remindersJson: {'isReminderOn': true, 'reminderMinutesBeforeStart': 5},
    );

    await service.rebuildUpcomingEventNotifications('microsoft:m');

    expect(await database.select(database.notificationSchedule).get(), isEmpty);
  });

  test('local Microsoft event reminder wakes notification scheduler', () async {
    var schedulerCalls = 0;
    final repository = CalendarRepository(
      database: database,
      now: () => DateTime.utc(2026, 6, 8, 8),
      onNotificationScheduleChanged: () async => schedulerCalls += 1,
    );
    await repository.upsertSource(
      accountId: 'microsoft:m',
      source: const CalendarSourceDto(
        provider: TaskProvider.microsoft,
        providerCalendarId: 'cal-1',
        summary: 'Calendar',
      ),
    );

    await repository.createLocalEvent(
      EventEditorDraft.newEvent(
        accountId: 'microsoft:m',
        sourceId: 'microsoft:m|microsoft|cal-1',
        providerCalendarId: 'cal-1',
        start: DateTime.utc(2026, 6, 8, 9),
        end: DateTime.utc(2026, 6, 8, 10),
      ).copyWith(
        title: 'Standup',
        reminders: const {
          'isReminderOn': true,
          'reminderMinutesBeforeStart': 15,
        },
      ),
    );

    final rows = await database.select(database.notificationSchedule).get();
    expect(schedulerCalls, 1);
    expect(rows.single.sourceType, 'event');
    expect(
      rows.single.scheduledAtUtc,
      DateTime.utc(2026, 6, 8, 8, 45).millisecondsSinceEpoch,
    );
  });

  test('deleted event removes scheduled notification', () async {
    await _upsertEvent(
      database,
      accountId: 'google:g',
      provider: TaskProvider.google,
      remindersJson: {
        'overrides': [
          {'method': 'popup', 'minutes': 10},
        ],
      },
    );
    await service.rebuildUpcomingEventNotifications('google:g');
    await (database.update(database.calendarEvents)
          ..where((row) => row.accountId.equals('google:g')))
        .write(const CalendarEventsCompanion(isDeleted: Value(true)));

    await service.rebuildUpcomingEventNotifications('google:g');

    expect(await database.select(database.notificationSchedule).get(), isEmpty);
  });

  test('completed task removes scheduled task reminder', () async {
    await _insertTaskReminder(database, status: 'needsAction');
    await service.rebuildUpcomingTaskNotifications('microsoft:m');
    expect(
      await database.select(database.notificationSchedule).get(),
      hasLength(1),
    );

    await (database.update(database.tasks)
          ..where((row) => row.accountId.equals('microsoft:m')))
        .write(const TasksCompanion(status: Value('completed')));
    await service.rebuildUpcomingTaskNotifications('microsoft:m');

    expect(await database.select(database.notificationSchedule).get(), isEmpty);
  });
}

Future<void> _insertAccount(
  AppDatabase database, {
  required String id,
  required TaskProvider provider,
}) {
  return database
      .into(database.accounts)
      .insert(
        AccountsCompanion.insert(
          id: id,
          provider: Value(provider.storageValue),
          authState: const Value('signed_in'),
          grantedScopes: const Value(''),
          createdAtUtc: '2026-06-08T00:00:00.000Z',
          updatedAtUtc: '2026-06-08T00:00:00.000Z',
        ),
      );
}

Future<void> _upsertEvent(
  AppDatabase database, {
  required String accountId,
  required TaskProvider provider,
  required Object remindersJson,
  String startDateTime = '2026-06-08T09:00:00.000Z',
  String? startTimeZone,
}) async {
  final repository = CalendarRepository(database: database);
  await repository.upsertSource(
    accountId: accountId,
    source: CalendarSourceDto(
      provider: provider,
      providerCalendarId: 'cal-1',
      summary: 'Calendar',
    ),
  );
  await repository.upsertEvent(
    accountId: accountId,
    event: CalendarEventDto(
      provider: provider,
      providerCalendarId: 'cal-1',
      providerEventId: 'event-1',
      title: 'Standup',
      startDateTime: startDateTime,
      startTimeZone: startTimeZone,
      endDateTime: '2026-06-08T10:00:00.000Z',
      remindersJson: remindersJson,
      rawJson: {'id': 'event-1', 'subject': 'Standup'},
    ),
  );
}

Future<void> _insertTaskReminder(
  AppDatabase database, {
  required String status,
}) async {
  await database
      .into(database.taskLists)
      .insert(
        TaskListsCompanion.insert(
          accountId: 'microsoft:m',
          id: 'list-1',
          title: 'Tasks',
          rawJson: '{}',
          createdLocalAtUtc: '2026-06-08T00:00:00.000Z',
          updatedLocalAtUtc: '2026-06-08T00:00:00.000Z',
        ),
      );
  await database
      .into(database.tasks)
      .insert(
        TasksCompanion.insert(
          accountId: 'microsoft:m',
          taskListId: 'list-1',
          id: 'task-1',
          title: 'File report',
          status: Value(status),
          microsoftIsReminderOn: const Value(true),
          microsoftReminderDateTime: const Value('2026-06-08T09:15:00.000Z'),
          rawJson: jsonEncode({'id': 'task-1'}),
          createdLocalAtUtc: '2026-06-08T00:00:00.000Z',
          updatedLocalAtUtc: '2026-06-08T00:00:00.000Z',
        ),
      );
}

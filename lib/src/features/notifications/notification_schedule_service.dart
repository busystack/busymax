import 'dart:convert';

import 'package:drift/drift.dart';

import '../../db/app_database.dart';
import '../../task_providers/task_provider.dart';

class NotificationScheduleService {
  NotificationScheduleService({
    required AppDatabase database,
    DateTime Function()? nowUtc,
  }) : _database = database,
       _nowUtc = nowUtc ?? (() => DateTime.now().toUtc());

  final AppDatabase _database;
  final DateTime Function() _nowUtc;

  Future<void> rebuildUpcomingEventNotifications(String accountId) async {
    await (_database.delete(_database.notificationSchedule)..where(
          (row) =>
              row.accountId.equals(accountId) & row.sourceType.equals('event'),
        ))
        .go();

    final now = _nowUtc();
    final rows =
        await (_database.select(_database.calendarEvents)..where(
              (row) =>
                  row.accountId.equals(accountId) &
                  row.isDeleted.equals(false) &
                  row.isCancelled.equals(false),
            ))
            .get();
    for (final event in rows) {
      final start = _eventStart(event);
      if (start == null) {
        continue;
      }
      final reminders = _eventReminderMinutes(event);
      for (final minutes in reminders) {
        final scheduledAt = start.toUtc().subtract(Duration(minutes: minutes));
        if (scheduledAt.isBefore(now)) {
          continue;
        }
        await _upsertNotification(
          id: 'event|${event.id}|$minutes',
          accountId: accountId,
          sourceType: 'event',
          sourceId: event.id,
          scheduledAtUtc: scheduledAt,
          title: event.title,
          body: event.description ?? event.location,
        );
      }
    }
  }

  Future<void> rebuildUpcomingTaskNotifications(String accountId) async {
    await (_database.delete(_database.notificationSchedule)..where(
          (row) =>
              row.accountId.equals(accountId) & row.sourceType.equals('task'),
        ))
        .go();

    final now = _nowUtc();
    final rows =
        await (_database.select(_database.tasks)..where(
              (row) =>
                  row.accountId.equals(accountId) &
                  row.pendingDelete.equals(false),
            ))
            .get();
    for (final task in rows) {
      if (task.status == 'completed' || task.microsoftIsReminderOn != true) {
        continue;
      }
      final reminderAt = DateTime.tryParse(
        task.microsoftReminderDateTime ?? '',
      )?.toUtc();
      if (reminderAt == null || reminderAt.isBefore(now)) {
        continue;
      }
      await _upsertNotification(
        id: 'task|${task.accountId}|${task.taskListId}|${task.id}',
        accountId: accountId,
        sourceType: 'task',
        sourceId: task.id,
        scheduledAtUtc: reminderAt,
        title: task.title,
        body: task.notes ?? task.bodyContent,
      );
    }
  }

  Future<void> rebuildUpcomingNotifications(String accountId) async {
    await rebuildUpcomingEventNotifications(accountId);
    await rebuildUpcomingTaskNotifications(accountId);
  }

  Future<void> _upsertNotification({
    required String id,
    required String accountId,
    required String sourceType,
    required String sourceId,
    required DateTime scheduledAtUtc,
    required String title,
    String? body,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _database
        .into(_database.notificationSchedule)
        .insertOnConflictUpdate(
          NotificationScheduleCompanion.insert(
            id: id,
            accountId: accountId,
            sourceType: sourceType,
            sourceId: sourceId,
            scheduledAtUtc: scheduledAtUtc.millisecondsSinceEpoch,
            title: title,
            body: Value(body),
            createdAtLocal: now,
            updatedAtLocal: now,
          ),
        );
  }
}

DateTime? _eventStart(CalendarEvent event) {
  if (event.allDay) {
    return _parseDate(event.startDate);
  }
  return _parseDateTime(event.startDateTime, event.startTimeZone);
}

List<int> _eventReminderMinutes(CalendarEvent event) {
  final raw = event.remindersJson;
  if (raw == null || raw.isEmpty) {
    return const [];
  }
  final provider = TaskProviderParsing.fromStorageValue(event.provider);
  final decoded = jsonDecode(raw);
  if (provider == TaskProvider.microsoft && decoded is Map) {
    final map = decoded.cast<String, Object?>();
    final enabled = map['isReminderOn'] == true;
    final minutes = map['reminderMinutesBeforeStart'];
    return enabled && minutes is int ? [minutes] : const [];
  }
  if (provider == TaskProvider.google && decoded is Map) {
    final map = decoded.cast<String, Object?>();
    final overrides = map['overrides'];
    if (overrides is! List) {
      return const [];
    }
    return [
      for (final item in overrides)
        if (item is Map && item['method'] == 'popup' && item['minutes'] is int)
          item['minutes'] as int,
    ];
  }
  return const [];
}

DateTime? _parseDate(String? value) {
  if (value == null || value.length < 10) {
    return null;
  }
  return DateTime.tryParse('${value.substring(0, 10)}T00:00:00');
}

DateTime? _parseDateTime(String? value, String? timeZone) {
  final parsed = DateTime.tryParse(value ?? '');
  if (parsed == null || parsed.isUtc) {
    return parsed;
  }

  final normalizedZone = timeZone?.trim().toLowerCase();
  if (normalizedZone == 'utc' ||
      normalizedZone == 'etc/utc' ||
      normalizedZone == 'gmt' ||
      normalizedZone == 'etc/gmt') {
    return DateTime.utc(
      parsed.year,
      parsed.month,
      parsed.day,
      parsed.hour,
      parsed.minute,
      parsed.second,
      parsed.millisecond,
      parsed.microsecond,
    );
  }

  return parsed;
}

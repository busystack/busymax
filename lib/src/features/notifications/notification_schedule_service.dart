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
    final sourcesById = {
      for (final source in await (_database.select(
        _database.calendarSources,
      )..where((row) => row.accountId.equals(accountId))).get())
        source.id: source,
    };
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
      final reminders = _eventReminderMinutes(
        event,
        source: sourcesById[event.calendarSourceId],
      );
      for (final minutes in reminders) {
        final startUtc = start.toUtc();
        final reminderAt = startUtc.subtract(Duration(minutes: minutes));
        if (startUtc.isBefore(now) || startUtc.isAtSameMomentAs(now)) {
          continue;
        }
        final scheduledAt = reminderAt.isBefore(now) ? now : reminderAt;
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

List<int> _eventReminderMinutes(CalendarEvent event, {CalendarSource? source}) {
  final raw = event.remindersJson;
  if (raw == null || raw.isEmpty) {
    return const [];
  }
  final provider = TaskProviderParsing.fromStorageValue(event.provider);
  final decoded = _decodeJson(raw);
  if (provider == TaskProvider.microsoft && decoded is Map) {
    final map = decoded.cast<String, Object?>();
    final enabled = map['isReminderOn'] == true;
    final minutes = map['reminderMinutesBeforeStart'];
    return enabled && minutes is int ? [minutes] : const [];
  }
  if (provider == TaskProvider.google && decoded is Map) {
    final map = decoded.cast<String, Object?>();
    if (map['useDefault'] == true) {
      return _googleDefaultReminderMinutes(source);
    }
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

Object? _decodeJson(String raw) {
  try {
    return jsonDecode(raw);
  } on Object {
    return null;
  }
}

List<int> _googleDefaultReminderMinutes(CalendarSource? source) {
  final raw = source?.rawJson;
  if (raw == null || raw.isEmpty) {
    return const [];
  }

  final decoded = _decodeJson(raw);
  if (decoded is! Map) {
    return const [];
  }

  final reminders = decoded['defaultReminders'];
  if (reminders is! List) {
    return const [];
  }

  return [
    for (final item in reminders)
      if (item is Map && item['method'] == 'popup' && item['minutes'] is int)
        item['minutes'] as int,
  ];
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

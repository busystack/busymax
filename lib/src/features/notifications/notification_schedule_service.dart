import 'dart:convert';

import 'package:drift/drift.dart';

import '../../core/time/provider_date_time.dart';
import '../../db/app_database.dart';
import '../../task_providers/task_provider.dart';
import '../accounts/data/accounts_repository.dart';

class NotificationScheduleService {
  NotificationScheduleService({
    required AppDatabase database,
    DateTime Function()? nowUtc,
  }) : _database = database,
       _nowUtc = nowUtc ?? (() => DateTime.now().toUtc());

  final AppDatabase _database;
  final DateTime Function() _nowUtc;

  Future<void> rebuildUpcomingEventNotifications(String accountId) async {
    final now = _nowUtc();
    final notifications = <String, _PendingNotification>{};
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
        final id = 'event|${event.id}|$minutes';
        notifications[id] = _PendingNotification(
          id: id,
          accountId: accountId,
          sourceType: 'event',
          sourceId: event.id,
          scheduledAtUtc: reminderAt,
          title: event.title,
          body: event.description ?? event.location,
        );
      }
    }
    await _reconcileNotifications(
      accountId: accountId,
      sourceType: 'event',
      notifications: notifications.values,
    );
  }

  Future<void> rebuildUpcomingTaskNotifications(String accountId) async {
    final now = _nowUtc();
    final notifications = <String, _PendingNotification>{};
    final rows =
        await (_database.select(_database.tasks)..where(
              (row) =>
                  row.accountId.equals(accountId) &
                  row.pendingDelete.equals(false) &
                  row.serverMissing.equals(false) &
                  (row.deleted.isNull() | row.deleted.equals(false)) &
                  (row.hidden.isNull() | row.hidden.equals(false)),
            ))
            .get();
    for (final task in rows) {
      if (task.status == 'completed' || task.microsoftIsReminderOn != true) {
        continue;
      }
      final reminderAt = providerDateTimeAsUtcInstant(
        task.microsoftReminderDateTime,
        task.microsoftReminderTimeZone,
      );
      if (reminderAt == null || reminderAt.isBefore(now)) {
        continue;
      }
      final id = 'task|${task.accountId}|${task.taskListId}|${task.id}';
      notifications[id] = _PendingNotification(
        id: id,
        accountId: accountId,
        sourceType: 'task',
        sourceId: task.id,
        scheduledAtUtc: reminderAt,
        title: task.title,
        body: task.notes ?? task.bodyContent,
      );
    }
    await _reconcileNotifications(
      accountId: accountId,
      sourceType: 'task',
      notifications: notifications.values,
    );
  }

  Future<void> rebuildUpcomingNotifications(String accountId) async {
    await rebuildUpcomingEventNotifications(accountId);
    await rebuildUpcomingTaskNotifications(accountId);
  }

  Future<void> _reconcileNotifications({
    required String accountId,
    required String sourceType,
    required Iterable<_PendingNotification> notifications,
  }) async {
    final desired = {
      for (final notification in notifications) notification.id: notification,
    };
    await _database.transaction(() async {
      final account = await (_database.select(
        _database.accounts,
      )..where((row) => row.id.equals(accountId))).getSingleOrNull();
      if (account?.authState != accountAuthStateSignedIn) {
        await (_database.delete(_database.notificationSchedule)..where(
              (row) =>
                  row.accountId.equals(accountId) &
                  row.sourceType.equals(sourceType),
            ))
            .go();
        return;
      }

      final existing =
          await (_database.select(_database.notificationSchedule)..where(
                (row) =>
                    row.accountId.equals(accountId) &
                    row.sourceType.equals(sourceType),
              ))
              .get();
      final existingById = {for (final row in existing) row.id: row};
      final updatedAt = DateTime.now().millisecondsSinceEpoch;
      final now = _nowUtc().millisecondsSinceEpoch;

      for (final notification in desired.values) {
        final existingRow = existingById[notification.id];
        final scheduledAt = notification.scheduledAtUtc.millisecondsSinceEpoch;
        if (existingRow != null) {
          final resetLifecycle = _shouldResetLifecycle(
            existingRow,
            scheduledAtUtc: scheduledAt,
            nowUtc: now,
          );
          await (_database.update(_database.notificationSchedule)..where(
                (row) =>
                    row.id.equals(notification.id) &
                    row.accountId.equals(accountId),
              ))
              .write(
                NotificationScheduleCompanion(
                  sourceId: Value(notification.sourceId),
                  scheduledAtUtc: Value(scheduledAt),
                  title: Value(notification.title),
                  body: Value(notification.body),
                  sentAtUtc: resetLifecycle
                      ? const Value(null)
                      : const Value.absent(),
                  dismissedAtUtc: resetLifecycle
                      ? const Value(null)
                      : const Value.absent(),
                  snoozedUntilUtc: resetLifecycle
                      ? const Value(null)
                      : const Value.absent(),
                  updatedAtLocal: Value(updatedAt),
                ),
              );
          continue;
        }

        await _database
            .into(_database.notificationSchedule)
            .insert(
              NotificationScheduleCompanion.insert(
                id: notification.id,
                accountId: notification.accountId,
                sourceType: notification.sourceType,
                sourceId: notification.sourceId,
                scheduledAtUtc: scheduledAt,
                title: notification.title,
                body: Value(notification.body),
                createdAtLocal: updatedAt,
                updatedAtLocal: updatedAt,
              ),
            );
      }

      for (final row in existing) {
        if (desired.containsKey(row.id)) {
          continue;
        }
        await (_database.delete(
          _database.notificationSchedule,
        )..where((table) => table.id.equals(row.id))).go();
      }
    });
  }
}

bool _shouldResetLifecycle(
  NotificationScheduleData existing, {
  required int scheduledAtUtc,
  required int nowUtc,
}) {
  if (existing.scheduledAtUtc == scheduledAtUtc) {
    return false;
  }

  final alreadyHandled =
      existing.sentAtUtc != null || existing.dismissedAtUtc != null;
  final legacyPastDueReminder =
      alreadyHandled &&
      existing.scheduledAtUtc <= nowUtc &&
      scheduledAtUtc <= nowUtc;
  return !legacyPastDueReminder;
}

class _PendingNotification {
  const _PendingNotification({
    required this.id,
    required this.accountId,
    required this.sourceType,
    required this.sourceId,
    required this.scheduledAtUtc,
    required this.title,
    this.body,
  });

  final String id;
  final String accountId;
  final String sourceType;
  final String sourceId;
  final DateTime scheduledAtUtc;
  final String title;
  final String? body;
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

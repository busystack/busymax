import 'dart:convert';

import 'package:drift/drift.dart';

import '../../core/time/provider_date_time.dart';
import '../../dav/ical/ical_task_alarm.dart';
import '../../db/app_database.dart';
import 'package:busymax/src/providers/busy_provider.dart';
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
    final pendingIds = await _pendingNotificationIds(accountId, 'event');
    final sourcesById = {
      for (final source
          in await (_database.select(_database.calendarSources)..where(
                (row) =>
                    row.accountId.equals(accountId) &
                    row.remindersEnabled.equals(true) &
                    row.isDeleted.equals(false),
              ))
              .get())
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
      final source = sourcesById[event.calendarSourceId];
      if (source == null) {
        continue;
      }
      final startUtc = _eventStartUtc(event);
      if (startUtc == null) {
        continue;
      }
      final endUtc = _eventEndUtc(event);
      final reminders = _eventReminders(
        event,
        source: source,
        startUtc: startUtc,
        endUtc: endUtc,
      );
      for (final reminder in reminders) {
        final reminderAt = reminder.scheduledAtUtc;
        final id = 'event|${event.id}|${reminder.key}';
        if (!reminder.relevantUntilUtc.isAfter(now) &&
            !pendingIds.contains(id)) {
          continue;
        }
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
    final pendingIds = await _pendingNotificationIds(accountId, 'task');
    final account = await (_database.select(
      _database.accounts,
    )..where((row) => row.id.equals(accountId))).getSingleOrNull();
    final provider = account == null
        ? null
        : BusyProviderCodec.requireStorageValue(account.provider);
    final isDav =
        provider == BusyProvider.appleICloud ||
        provider == BusyProvider.nextcloud;
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
      if (task.status == 'completed') {
        continue;
      }
      final reminders = isDav
          ? _davTaskReminders(task)
          : _providerTaskReminders(task);
      final baseId = 'task|${task.accountId}|${task.taskListId}|${task.id}';
      for (final reminder in reminders) {
        final id = reminder.key == null ? baseId : '$baseId|${reminder.key}';
        if (reminder.scheduledAtUtc.isBefore(now) && !pendingIds.contains(id)) {
          continue;
        }
        notifications[id] = _PendingNotification(
          id: id,
          accountId: accountId,
          sourceType: 'task',
          sourceId: task.id,
          scheduledAtUtc: reminder.scheduledAtUtc,
          title: task.title,
          body: task.notes ?? task.bodyContent,
        );
      }
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

  Future<Set<String>> _pendingNotificationIds(
    String accountId,
    String sourceType,
  ) async {
    final rows =
        await (_database.select(_database.notificationSchedule)..where(
              (row) =>
                  row.accountId.equals(accountId) &
                  row.sourceType.equals(sourceType) &
                  row.sentAtUtc.isNull() &
                  row.dismissedAtUtc.isNull(),
            ))
            .get();
    return {for (final row in rows) row.id};
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

List<_TaskReminder> _providerTaskReminders(Task task) {
  if (task.microsoftIsReminderOn != true) return const [];
  final reminderAt = providerDateTimeAsUtcInstant(
    task.microsoftReminderDateTime,
    task.microsoftReminderTimeZone,
  );
  return reminderAt == null
      ? const []
      : [_TaskReminder(key: null, scheduledAtUtc: reminderAt)];
}

List<_TaskReminder> _davTaskReminders(Task task) {
  final startUtc = _davTaskTemporalUtc(task.providerMetadataJson, 'start');
  final dueUtc = _davTaskTemporalUtc(task.providerMetadataJson, 'due');
  List<IcalTaskAlarm> alarms;
  try {
    alarms = decodeIcalTaskAlarms(task.taskAlarmsJson);
  } on Object {
    alarms = const [];
  }
  final result = <_TaskReminder>[];
  var usesLegacyId = true;
  for (var index = 0; index < alarms.length; index += 1) {
    final alarm = alarms[index];
    if (alarm.action != 'DISPLAY' && alarm.action != 'AUDIO') continue;
    final reference = alarm.isRelatedToDue ? dueUtc : startUtc;
    final scheduledAt =
        alarm.absoluteUtc ??
        (alarm.relativeOffset == null || reference == null
            ? null
            : reference.add(alarm.relativeOffset!));
    if (scheduledAt == null) continue;
    final repeatInterval = alarm.repeatInterval;
    final repeatCount = repeatInterval == null ? 0 : alarm.repeatCount ?? 0;
    for (var repetition = 0; repetition <= repeatCount; repetition += 1) {
      result.add(
        _TaskReminder(
          key: usesLegacyId
              ? null
              : repetition == 0
              ? 'dav-$index'
              : 'dav-$index-repeat-$repetition',
          scheduledAtUtc: scheduledAt.add(
            (repeatInterval ?? Duration.zero) * repetition,
          ),
        ),
      );
      usesLegacyId = false;
    }
  }
  if (result.isNotEmpty) return result;
  return _providerTaskReminders(task);
}

DateTime? _davTaskTemporalUtc(String? metadataJson, String prefix) {
  if (metadataJson == null || metadataJson.isEmpty) return null;
  final decoded = _decodeJson(metadataJson);
  if (decoded is! Map) return null;
  final exact = decoded['${prefix}Utc'];
  if (exact is String) return DateTime.tryParse(exact)?.toUtc();
  final native =
      decoded['native${prefix[0].toUpperCase()}${prefix.substring(1)}'];
  if (native is! Map) return null;
  final raw = native['raw'];
  final kind = native['kind'];
  if (raw is! String || kind is! String) return null;
  final match = RegExp(
    r'^(\d{4})(\d{2})(\d{2})(?:T(\d{2})(\d{2})(\d{2})(?:Z)?)?$',
  ).firstMatch(raw);
  if (match == null) return null;
  int part(int index) => int.tryParse(match.group(index) ?? '') ?? 0;
  final wall = DateTime(part(1), part(2), part(3), part(4), part(5), part(6));
  if (kind == 'utcDateTime') {
    return DateTime.utc(
      wall.year,
      wall.month,
      wall.day,
      wall.hour,
      wall.minute,
      wall.second,
    );
  }
  if (kind == 'tzidDateTime') {
    final timeZoneId = native['timeZoneId'];
    final isoWall =
        '${wall.year.toString().padLeft(4, '0')}-'
        '${wall.month.toString().padLeft(2, '0')}-'
        '${wall.day.toString().padLeft(2, '0')}T'
        '${wall.hour.toString().padLeft(2, '0')}:'
        '${wall.minute.toString().padLeft(2, '0')}:'
        '${wall.second.toString().padLeft(2, '0')}';
    return providerDateTimeAsUtcInstant(isoWall, timeZoneId?.toString());
  }
  return wall.toUtc();
}

final class _TaskReminder {
  const _TaskReminder({required this.key, required this.scheduledAtUtc});

  final String? key;
  final DateTime scheduledAtUtc;
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

DateTime? _eventStartUtc(CalendarEvent event) {
  if (event.allDay) {
    return _parseDate(event.startDate)?.toUtc();
  }
  return _projectedUtc(event.rawJson, 'startUtc') ??
      providerDateTimeAsUtcInstant(event.startDateTime, event.startTimeZone);
}

DateTime? _eventEndUtc(CalendarEvent event) {
  if (event.allDay) {
    return _parseDate(event.endDate)?.toUtc();
  }
  return _projectedUtc(event.rawJson, 'endUtc') ??
      providerDateTimeAsUtcInstant(event.endDateTime, event.endTimeZone);
}

List<_EventReminder> _eventReminders(
  CalendarEvent event, {
  required DateTime startUtc,
  required DateTime? endUtc,
  CalendarSource? source,
}) {
  final raw = event.remindersJson;
  if (raw == null || raw.isEmpty) {
    return const [];
  }
  final provider = BusyProviderCodec.requireStorageValue(event.provider);
  final decoded = _decodeJson(raw);
  if (provider == BusyProvider.microsoft && decoded is Map) {
    final map = decoded.cast<String, Object?>();
    final enabled = map['isReminderOn'] == true;
    final minutes = map['reminderMinutesBeforeStart'];
    return enabled && minutes is int
        ? [
            _EventReminder(
              key: '$minutes',
              scheduledAtUtc: startUtc.subtract(Duration(minutes: minutes)),
              relevantUntilUtc: startUtc,
            ),
          ]
        : const [];
  }
  if (provider == BusyProvider.google && decoded is Map) {
    final map = decoded.cast<String, Object?>();
    if (map['useDefault'] == true) {
      return _minuteReminders(
        _googleDefaultReminderMinutes(source),
        startUtc: startUtc,
      );
    }
    final overrides = map['overrides'];
    if (overrides is! List) {
      return const [];
    }
    return _minuteReminders([
      for (final item in overrides)
        if (item is Map && item['method'] == 'popup' && item['minutes'] is int)
          item['minutes'] as int,
    ], startUtc: startUtc);
  }
  if ((provider == BusyProvider.appleICloud ||
          provider == BusyProvider.nextcloud ||
          provider == BusyProvider.webCal) &&
      decoded is Map) {
    return _davEventReminders(
      decoded.cast<String, Object?>(),
      startUtc: startUtc,
      endUtc: endUtc,
    );
  }
  return const [];
}

List<_EventReminder> _minuteReminders(
  Iterable<int> minutes, {
  required DateTime startUtc,
}) {
  return [
    for (final value in minutes.toSet())
      _EventReminder(
        key: '$value',
        scheduledAtUtc: startUtc.subtract(Duration(minutes: value)),
        relevantUntilUtc: startUtc,
      ),
  ];
}

List<_EventReminder> _davEventReminders(
  Map<String, Object?> reminderData, {
  required DateTime startUtc,
  required DateTime? endUtc,
}) {
  final rawAlarms = reminderData['alarms'];
  if (rawAlarms is List) {
    final result = <_EventReminder>[];
    for (var index = 0; index < rawAlarms.length; index += 1) {
      final rawAlarm = rawAlarms[index];
      if (rawAlarm is! Map) continue;
      try {
        final alarm = IcalTaskAlarm.fromJson(rawAlarm.cast<String, Object?>());
        if (alarm.action != 'DISPLAY' && alarm.action != 'AUDIO') continue;
        final absolute = alarm.absoluteUtc;
        final relative = alarm.relativeOffset;
        final reference = alarm.isRelatedToDue ? endUtc : startUtc;
        final scheduledAt =
            absolute ??
            (relative == null || reference == null
                ? null
                : reference.add(relative));
        if (scheduledAt != null) {
          final repeatInterval = alarm.repeatInterval;
          final repeatCount = repeatInterval == null
              ? 0
              : alarm.repeatCount ?? 0;
          for (var repetition = 0; repetition <= repeatCount; repetition += 1) {
            final repeatedAt = scheduledAt.add(
              (repeatInterval ?? Duration.zero) * repetition,
            );
            final referenceUntil = alarm.isRelatedToDue ? endUtc : startUtc;
            final relevantUntil =
                referenceUntil != null && referenceUntil.isAfter(repeatedAt)
                ? referenceUntil
                : repeatedAt;
            result.add(
              _EventReminder(
                key: repetition == 0
                    ? 'dav-$index'
                    : 'dav-$index-repeat-$repetition',
                scheduledAtUtc: repeatedAt.toUtc(),
                relevantUntilUtc: relevantUntil,
              ),
            );
          }
        }
      } on Object {
        // Unsupported alarms remain losslessly stored with the event.
      }
    }
    return result;
  }

  final legacyMinutes = reminderData['minutes'];
  if (legacyMinutes is! List) return const [];
  return [
    for (final value in legacyMinutes)
      if (value is int)
        _EventReminder(
          key: 'dav-minutes-$value',
          scheduledAtUtc: startUtc.subtract(Duration(minutes: value)),
          relevantUntilUtc: startUtc,
        ),
  ];
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

DateTime? _projectedUtc(String? rawJson, String key) {
  if (rawJson == null || rawJson.isEmpty) return null;
  final decoded = _decodeJson(rawJson);
  if (decoded is! Map) return null;
  final value = decoded[key];
  if (value is! String) return null;
  return DateTime.tryParse(value)?.toUtc();
}

final class _EventReminder {
  const _EventReminder({
    required this.key,
    required this.scheduledAtUtc,
    required this.relevantUntilUtc,
  });

  final String key;
  final DateTime scheduledAtUtc;
  final DateTime relevantUntilUtc;
}

import 'dart:convert';

import '../../dav/ical/ical_task_alarm.dart';
import '../../features/recurrence/domain/recurrence_rule.dart';
import '../../features/tasks/domain/task_capabilities.dart';
import '../../providers/busy_provider.dart';

Map<String, Object?> buildWindowsTaskCreateFields({
  required TaskCollectionCapabilities capability,
  required BusyProvider provider,
  required DateTime? due,
  required DateTime? start,
  required DateTime? reminder,
  required List<IcalTaskAlarm> alarms,
  required bool scheduledAllDay,
  required String timeZone,
  required RecurrenceRule recurrence,
  required String importance,
  required String status,
  required int priority,
  required int progress,
  required String location,
  required String taskUrl,
  required String classification,
  required bool pinned,
  required bool hideSubtasks,
  required bool hideCompletedSubtasks,
}) {
  final fields = <String, Object?>{};
  if (capability.supportsDueTime && due != null && !scheduledAllDay) {
    fields
      ..['microsoftDueDateTime'] = _providerDateTime(due, timeZone)
      ..['microsoftDueTimeZone'] = timeZone;
  }
  if (capability.supportsStartDateTime && start != null && !scheduledAllDay) {
    fields
      ..['microsoftStartDateTime'] = _providerDateTime(start, timeZone)
      ..['microsoftStartTimeZone'] = timeZone;
  }
  if (capability.supportsReminderDateTime &&
      !capability.supportsMultipleReminders) {
    fields['microsoftIsReminderOn'] = reminder != null;
    if (reminder != null) {
      fields
        ..['microsoftReminderDateTime'] = _providerDateTime(reminder, timeZone)
        ..['microsoftReminderTimeZone'] = timeZone;
    }
  }
  if (capability.supportsMultipleReminders && alarms.isNotEmpty) {
    fields['taskAlarms'] = [for (final alarm in alarms) alarm.toJson()];
  }
  if (capability.supportsRecurrence && recurrence.repeats) {
    fields['recurrence'] = provider == BusyProvider.nextcloud
        ? jsonDecode(recurrence.toJsonString())
        : _microsoftTaskRecurrence(recurrence.frequency, start ?? due!);
  }
  if (capability.supportsImportance && !capability.supportsIcalPriority) {
    fields['importance'] = importance;
  }
  if (capability.supportsTaskStatus && status.isNotEmpty) {
    fields['taskStatus'] = status;
  }
  if (capability.supportsIcalPriority) fields['icalPriority'] = priority;
  if (capability.supportsPercentComplete) fields['percentComplete'] = progress;
  if (capability.supportsLocation) fields['location'] = location.trim();
  if (capability.supportsUrl) fields['taskUrl'] = taskUrl.trim();
  if (capability.supportsClassification) {
    fields['taskClassification'] = classification;
  }
  if (capability.supportsPinning) fields['taskPinned'] = pinned;
  if (capability.supportsSubtaskVisibility) {
    fields
      ..['taskHideSubtasks'] = hideSubtasks
      ..['taskHideCompletedSubtasks'] = hideCompletedSubtasks;
  }
  return fields;
}

Map<String, Object?> _providerDateTime(DateTime value, String timeZone) => {
  'dateTime': value.toIso8601String(),
  'timeZone': timeZone,
};

Map<String, Object?> _microsoftTaskRecurrence(
  RecurrenceFrequency frequency,
  DateTime baseDate,
) => {
  'pattern': switch (frequency) {
    RecurrenceFrequency.daily => {'type': 'daily', 'interval': 1},
    RecurrenceFrequency.weekly => {
      'type': 'weekly',
      'interval': 1,
      'daysOfWeek': [_microsoftWeekday(baseDate.weekday)],
      'firstDayOfWeek': 'monday',
    },
    RecurrenceFrequency.monthly => {
      'type': 'absoluteMonthly',
      'interval': 1,
      'dayOfMonth': baseDate.day,
    },
    RecurrenceFrequency.yearly => {
      'type': 'absoluteYearly',
      'interval': 1,
      'dayOfMonth': baseDate.day,
      'month': baseDate.month,
    },
    RecurrenceFrequency.none => {'type': 'daily', 'interval': 1},
  },
  'range': {'type': 'noEnd', 'startDate': _dateOnly(baseDate)},
};

String _microsoftWeekday(int weekday) => switch (weekday) {
  DateTime.monday => 'monday',
  DateTime.tuesday => 'tuesday',
  DateTime.wednesday => 'wednesday',
  DateTime.thursday => 'thursday',
  DateTime.friday => 'friday',
  DateTime.saturday => 'saturday',
  _ => 'sunday',
};

String _dateOnly(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-'
    '${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')}';

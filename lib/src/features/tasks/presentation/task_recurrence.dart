import 'dart:convert';

import '../../../core/time/provider_date_time.dart';
import 'task_details_draft.dart';

/// The complete wall-clock reference used by Nextcloud's task recurrence.
/// DUE owns the occurrence identity when present; DTSTART is the fallback.
class TaskRecurrenceReference {
  const TaskRecurrenceReference({
    required this.dateTime,
    required this.allDay,
    required this.timeZone,
    this.isFloating,
  });

  final DateTime dateTime;
  final bool allDay;
  final String? timeZone;
  final bool? isFloating;

  bool get floating =>
      !allDay && (isFloating ?? (timeZone?.trim().isEmpty ?? true));
}

TaskRecurrenceReference? taskRecurrenceReference({
  String? dueDate,
  String? dueTime,
  String? dueTimeZone,
  String? startDate,
  String? startTime,
  String? startTimeZone,
  bool? floating,
}) {
  final useDue = DateTime.tryParse(dueDate ?? '') != null;
  final date = DateTime.tryParse((useDue ? dueDate : startDate) ?? '');
  if (date == null) return null;
  final time = useDue ? dueTime : startTime;
  final parts = time?.split(':');
  return TaskRecurrenceReference(
    dateTime: DateTime(
      date.year,
      date.month,
      date.day,
      parts == null ? 0 : int.tryParse(parts[0]) ?? 0,
      parts == null || parts.length < 2 ? 0 : int.tryParse(parts[1]) ?? 0,
      parts == null || parts.length < 3 ? 0 : int.tryParse(parts[2]) ?? 0,
    ),
    allDay: time == null,
    timeZone: time == null || floating == true
        ? null
        : useDue
        ? dueTimeZone
        : startTimeZone,
    isFloating: floating,
  );
}

/// The editor supplies a display zone even for a loaded floating value. Keep
/// that authored kind while its timing is untouched, just as ordinary Save
/// preserves the corresponding DTSTART/DUE properties.
TaskRecurrenceReference? taskDraftRecurrenceReference(
  TaskDetailsDraft draft, {
  required String localTimeZone,
}) {
  final useDue = DateTime.tryParse(draft.dueDate ?? '') != null;
  final observed = draft.observedTask;
  bool? floating;
  if (observed?.davCollectionId != null) {
    final initial = TaskDetailsDraft.fromTask(observed!, localTimeZone);
    final unchanged = useDue
        ? draft.dueDate == initial.dueDate &&
              draft.microsoftDueTime == initial.microsoftDueTime &&
              draft.microsoftDueTimeZone == initial.microsoftDueTimeZone
        : draft.microsoftStartDate == initial.microsoftStartDate &&
              draft.microsoftStartTime == initial.microsoftStartTime &&
              draft.microsoftStartTimeZone == initial.microsoftStartTimeZone;
    final value = useDue
        ? observed.microsoftDueDateTime
        : observed.microsoftStartDateTime;
    final zone = useDue
        ? observed.microsoftDueTimeZone
        : observed.microsoftStartTimeZone;
    if (unchanged &&
        value != null &&
        value.contains('T') &&
        (zone?.trim().isEmpty ?? true) &&
        !providerDateTimeIsInstant(value, zone)) {
      floating = true;
    }
  }
  return taskRecurrenceReference(
    dueDate: draft.dueDate,
    dueTime: draft.microsoftDueTime,
    dueTimeZone: draft.microsoftDueTimeZone,
    startDate: draft.microsoftStartDate,
    startTime: draft.microsoftStartTime,
    startTimeZone: draft.microsoftStartTimeZone,
    floating: floating,
  );
}

String? encodeSimpleTaskRecurrence(
  String type, {
  required DateTime? due,
  required DateTime? start,
  required bool dav,
}) {
  if (type == 'none') return null;
  final recurrenceStart = start ?? due ?? DateTime.now();
  if (dav) {
    final frequency = switch (type) {
      'daily' => 'DAILY',
      'weekly' => 'WEEKLY',
      'absoluteMonthly' => 'MONTHLY',
      'absoluteYearly' => 'YEARLY',
      _ => 'DAILY',
    };
    final parts = <String>['FREQ=$frequency', 'INTERVAL=1'];
    if (type == 'weekly') {
      parts.add('BYDAY=${_weekdayCode(recurrenceStart.weekday)}');
    } else if (type == 'absoluteMonthly') {
      parts.add('BYMONTHDAY=${recurrenceStart.day}');
    } else if (type == 'absoluteYearly') {
      parts
        ..add('BYMONTH=${recurrenceStart.month}')
        ..add('BYMONTHDAY=${recurrenceStart.day}');
    }
    return jsonEncode({
      'rules': [parts.join(';')],
      'dates': const <String>[],
      'excludedDates': const <String>[],
    });
  }
  final pattern = switch (type) {
    'daily' => {'type': 'daily', 'interval': 1},
    'weekly' => {
      'type': 'weekly',
      'interval': 1,
      'daysOfWeek': [_weekdayName(recurrenceStart.weekday)],
      'firstDayOfWeek': 'monday',
    },
    'absoluteMonthly' => {
      'type': 'absoluteMonthly',
      'interval': 1,
      'dayOfMonth': recurrenceStart.day,
    },
    'absoluteYearly' => {
      'type': 'absoluteYearly',
      'interval': 1,
      'dayOfMonth': recurrenceStart.day,
      'month': recurrenceStart.month,
    },
    _ => {'type': 'daily', 'interval': 1},
  };
  return jsonEncode({
    'pattern': pattern,
    'range': {
      'type': 'noEnd',
      'startDate': providerWallTimeIso8601String(recurrenceStart)
          .substring(0, 10),
    },
  });
}

String _weekdayCode(int weekday) => switch (weekday) {
  DateTime.monday => 'MO',
  DateTime.tuesday => 'TU',
  DateTime.wednesday => 'WE',
  DateTime.thursday => 'TH',
  DateTime.friday => 'FR',
  DateTime.saturday => 'SA',
  _ => 'SU',
};

String _weekdayName(int weekday) => switch (weekday) {
  DateTime.monday => 'monday',
  DateTime.tuesday => 'tuesday',
  DateTime.wednesday => 'wednesday',
  DateTime.thursday => 'thursday',
  DateTime.friday => 'friday',
  DateTime.saturday => 'saturday',
  _ => 'sunday',
};

import 'dart:convert';

import 'package:timezone/data/latest_all.dart' as time_zone_data;
import 'package:timezone/timezone.dart' as time_zone;

import '../../../core/time/provider_date_time.dart';
import '../../../dav/ical/ical_task_alarm.dart';
import '../../../google_tasks/api/google_tasks_json.dart';
import 'package:busymax/src/features/tasks/domain/task_capabilities.dart';
import '../data/tasks_repository.dart';

enum TaskScheduleIssue { none, dueBeforeStart, mixedTimeModes }

class TaskDetailsDraft {
  const TaskDetailsDraft({
    required this.taskListId,
    required this.taskId,
    required this.title,
    required this.notes,
    required this.dueDate,
    required this.microsoftDueTime,
    required this.microsoftDueTimeZone,
    required this.microsoftStartDate,
    required this.microsoftStartTime,
    required this.microsoftStartTimeZone,
    required this.microsoftReminderEnabled,
    required this.microsoftReminderDate,
    required this.microsoftReminderTime,
    required this.microsoftReminderTimeZone,
    required this.recurrenceJson,
    required this.importance,
    required this.categories,
    required this.icalPriority,
    required this.percentComplete,
    required this.taskStatus,
    required this.completedDate,
    required this.completedTime,
    required this.location,
    required this.taskUrl,
    required this.classification,
    required this.pinned,
    required this.hideSubtasks,
    required this.hideCompletedSubtasks,
    required this.alarms,
  });

  factory TaskDetailsDraft.fromTask(TaskEntity task, String localTimeZone) {
    return TaskDetailsDraft(
      taskListId: task.taskListId,
      taskId: task.id,
      title: task.title,
      notes: task.notes ?? '',
      dueDate: _dateOnly(task.dueUtc),
      microsoftDueTime: _providerTimePart(
        task.microsoftDueDateTime,
        task.microsoftDueTimeZone,
      ),
      microsoftDueTimeZone: _editorTimeZone(
        task.microsoftDueDateTime,
        task.microsoftDueTimeZone,
        localTimeZone,
      ),
      microsoftStartDate: _providerDatePart(
        task.microsoftStartDateTime,
        task.microsoftStartTimeZone,
      ),
      microsoftStartTime: _providerTimePart(
        task.microsoftStartDateTime,
        task.microsoftStartTimeZone,
      ),
      microsoftStartTimeZone: _editorTimeZone(
        task.microsoftStartDateTime,
        task.microsoftStartTimeZone,
        localTimeZone,
      ),
      microsoftReminderEnabled: task.microsoftIsReminderOn ?? false,
      microsoftReminderDate: _providerDatePart(
        task.microsoftReminderDateTime,
        task.microsoftReminderTimeZone,
      ),
      microsoftReminderTime: _providerTimePart(
        task.microsoftReminderDateTime,
        task.microsoftReminderTimeZone,
      ),
      microsoftReminderTimeZone: _editorTimeZone(
        task.microsoftReminderDateTime,
        task.microsoftReminderTimeZone,
        localTimeZone,
      ),
      recurrenceJson: task.recurrenceJson,
      importance: _importanceValue(task.importance),
      categories: _categories(task.categoriesJson),
      icalPriority: (task.icalPriority ?? 0).clamp(0, 9),
      percentComplete: (task.percentComplete ?? 0).clamp(0, 100),
      taskStatus: _icalStatus(task.providerStatus),
      completedDate: _localDatePart(task.completedUtc),
      completedTime: _localTimePart(task.completedUtc),
      location: task.taskLocation ?? '',
      taskUrl: task.taskUrl ?? '',
      classification: _classificationValue(task.taskClassification),
      pinned: task.taskPinned ?? false,
      hideSubtasks: task.taskHideSubtasks ?? false,
      hideCompletedSubtasks: task.taskHideCompletedSubtasks ?? false,
      alarms: decodeIcalTaskAlarms(task.taskAlarmsJson),
    );
  }

  final String taskListId;
  final String taskId;
  final String title;
  final String notes;
  final String? dueDate;
  final String? microsoftDueTime;
  final String? microsoftDueTimeZone;
  final String? microsoftStartDate;
  final String? microsoftStartTime;
  final String? microsoftStartTimeZone;
  final bool microsoftReminderEnabled;
  final String? microsoftReminderDate;
  final String? microsoftReminderTime;
  final String? microsoftReminderTimeZone;
  final String? recurrenceJson;
  final String importance;
  final List<String> categories;
  final int icalPriority;
  final int percentComplete;
  final String? taskStatus;
  final String? completedDate;
  final String? completedTime;
  final String location;
  final String taskUrl;
  final String classification;
  final bool pinned;
  final bool hideSubtasks;
  final bool hideCompletedSubtasks;
  final List<IcalTaskAlarm> alarms;

  bool get hasValidTaskUrl {
    final value = taskUrl.trim();
    if (value.isEmpty) return true;
    if (value.contains('\r') || value.contains('\n')) return false;
    final parsed = Uri.tryParse(value);
    return parsed != null && parsed.hasScheme;
  }

  DateTime? reminderReferenceUtc({
    required bool due,
    required String localTimeZone,
  }) {
    final date = DateTime.tryParse(
      due ? dueDate ?? '' : microsoftStartDate ?? '',
    );
    if (date == null) return null;
    final time = due ? microsoftDueTime : microsoftStartTime;
    final zone = due ? microsoftDueTimeZone : microsoftStartTimeZone;
    return _taskScheduleInstant(
      date,
      time ?? '00:00',
      time == null ? localTimeZone : zone ?? localTimeZone,
    );
  }

  TaskScheduleIssue get scheduleIssue {
    final due = DateTime.tryParse(dueDate ?? '');
    final start = DateTime.tryParse(microsoftStartDate ?? '');
    if (due == null || start == null) {
      return TaskScheduleIssue.none;
    }
    final dueHasTime = microsoftDueTime != null;
    final startHasTime = microsoftStartTime != null;
    if (dueHasTime != startHasTime) {
      return TaskScheduleIssue.mixedTimeModes;
    }
    if (!dueHasTime) {
      return _dateOnlyValue(due).isBefore(_dateOnlyValue(start))
          ? TaskScheduleIssue.dueBeforeStart
          : TaskScheduleIssue.none;
    }
    final dueInstant = _taskScheduleInstant(
      due,
      microsoftDueTime!,
      microsoftDueTimeZone,
    );
    final startInstant = _taskScheduleInstant(
      start,
      microsoftStartTime!,
      microsoftStartTimeZone,
    );
    if (dueInstant == null || startInstant == null) {
      return TaskScheduleIssue.none;
    }
    return dueInstant.isBefore(startInstant)
        ? TaskScheduleIssue.dueBeforeStart
        : TaskScheduleIssue.none;
  }

  bool hasSameValues(TaskDetailsDraft other) {
    return taskListId == other.taskListId &&
        taskId == other.taskId &&
        title == other.title &&
        notes == other.notes &&
        dueDate == other.dueDate &&
        microsoftDueTime == other.microsoftDueTime &&
        microsoftDueTimeZone == other.microsoftDueTimeZone &&
        microsoftStartDate == other.microsoftStartDate &&
        microsoftStartTime == other.microsoftStartTime &&
        microsoftStartTimeZone == other.microsoftStartTimeZone &&
        microsoftReminderEnabled == other.microsoftReminderEnabled &&
        microsoftReminderDate == other.microsoftReminderDate &&
        microsoftReminderTime == other.microsoftReminderTime &&
        microsoftReminderTimeZone == other.microsoftReminderTimeZone &&
        recurrenceJson == other.recurrenceJson &&
        importance == other.importance &&
        _sameStrings(categories, other.categories) &&
        icalPriority == other.icalPriority &&
        percentComplete == other.percentComplete &&
        taskStatus == other.taskStatus &&
        completedDate == other.completedDate &&
        completedTime == other.completedTime &&
        location == other.location &&
        taskUrl == other.taskUrl &&
        classification == other.classification &&
        pinned == other.pinned &&
        hideSubtasks == other.hideSubtasks &&
        hideCompletedSubtasks == other.hideCompletedSubtasks &&
        _sameAlarms(alarms, other.alarms);
  }

  bool differsFrom(
    TaskEntity task,
    TaskCollectionCapabilities capabilities, {
    required String localTimeZone,
  }) {
    if (taskListId != task.taskListId) {
      return true;
    }
    return toPatch(task, capabilities, localTimeZone: localTimeZone).isNotEmpty;
  }

  Map<String, Object?> toPatch(
    TaskEntity original,
    TaskCollectionCapabilities capabilities, {
    required String localTimeZone,
  }) {
    final fields = <String, Object?>{};

    if (title != original.title) {
      fields['title'] = title;
    }
    if (notes != (original.notes ?? '')) {
      fields['notes'] = notes;
    }

    final originalDueDate = _dateOnly(original.dueUtc);
    final dueChanged = dueDate != originalDueDate;
    if (dueChanged) {
      fields['due'] = dueDate;
    }
    if (capabilities.supportsDueTime) {
      final originalDueTime = _providerTimePart(
        original.microsoftDueDateTime,
        original.microsoftDueTimeZone,
      );
      final originalDueZone = _editorTimeZone(
        original.microsoftDueDateTime,
        original.microsoftDueTimeZone,
        localTimeZone,
      );
      final dueTimeChanged = microsoftDueTime != originalDueTime;
      final dueZoneChanged = microsoftDueTimeZone != originalDueZone;
      if (dueChanged || dueTimeChanged || dueZoneChanged) {
        final date = dueDate;
        if (date == null || date.isEmpty) {
          fields['microsoftDueDateTime'] = null;
        } else {
          fields['microsoftDueDateTime'] = _graphDateTime(
            date,
            microsoftDueTime,
            microsoftDueTimeZone ?? localTimeZone,
          );
        }
        fields['microsoftDueTimeZone'] = microsoftDueTimeZone ?? localTimeZone;
      }
    }

    if (capabilities.supportsStartDateTime) {
      _putDateTimePatch(
        fields,
        originalDateTime: original.microsoftStartDateTime,
        originalTimeZone: original.microsoftStartTimeZone ?? localTimeZone,
        date: microsoftStartDate,
        time: microsoftStartTime,
        timeZone: microsoftStartTimeZone ?? localTimeZone,
        dateTimeField: 'microsoftStartDateTime',
        timeZoneField: 'microsoftStartTimeZone',
      );
    }

    if (capabilities.supportsReminderDateTime) {
      final originalEnabled = original.microsoftIsReminderOn ?? false;
      final reminderChanged =
          microsoftReminderEnabled != originalEnabled ||
          microsoftReminderDate !=
              _providerDatePart(
                original.microsoftReminderDateTime,
                original.microsoftReminderTimeZone,
              ) ||
          microsoftReminderTime !=
              _providerTimePart(
                original.microsoftReminderDateTime,
                original.microsoftReminderTimeZone,
              ) ||
          (microsoftReminderTimeZone ?? localTimeZone) !=
              _editorTimeZone(
                original.microsoftReminderDateTime,
                original.microsoftReminderTimeZone,
                localTimeZone,
              );
      if (reminderChanged) {
        fields['microsoftIsReminderOn'] = microsoftReminderEnabled;
        if (!microsoftReminderEnabled) {
          fields['microsoftReminderDateTime'] = null;
        } else {
          fields['microsoftReminderDateTime'] = _graphDateTime(
            microsoftReminderDate ?? _todayDateOnly(),
            microsoftReminderTime ?? _currentTimeString(),
            microsoftReminderTimeZone ?? localTimeZone,
          );
        }
        fields['microsoftReminderTimeZone'] =
            microsoftReminderTimeZone ?? localTimeZone;
      }
    }

    if (capabilities.supportsRecurrence &&
        recurrenceJson != original.recurrenceJson) {
      fields['recurrence'] = recurrenceJson == null
          ? null
          : jsonDecode(recurrenceJson!);
    }
    if (capabilities.supportsImportance &&
        !capabilities.supportsIcalPriority &&
        importance != _importanceValue(original.importance)) {
      fields['importance'] = importance;
    }
    if (capabilities.supportsCategories &&
        !_sameStrings(categories, _categories(original.categoriesJson))) {
      fields['categories'] = categories;
    }
    if (capabilities.supportsIcalPriority &&
        icalPriority != (original.icalPriority ?? 0).clamp(0, 9)) {
      fields['icalPriority'] = icalPriority;
    }
    if (capabilities.supportsPercentComplete &&
        percentComplete != (original.percentComplete ?? 0).clamp(0, 100)) {
      fields['percentComplete'] = percentComplete;
    }
    if (capabilities.supportsTaskStatus &&
        taskStatus != _icalStatus(original.providerStatus)) {
      fields['taskStatus'] = taskStatus;
    }
    if (capabilities.supportsCompletedDateTime) {
      final desiredCompleted = _completedUtc(completedDate, completedTime);
      if (!_sameInstant(desiredCompleted, original.completedUtc)) {
        fields['completedAtUtc'] = desiredCompleted;
      }
    }
    if (capabilities.supportsLocation &&
        location != (original.taskLocation ?? '')) {
      fields['location'] = location;
    }
    if (capabilities.supportsUrl && taskUrl != (original.taskUrl ?? '')) {
      fields['taskUrl'] = taskUrl;
    }
    if (capabilities.supportsClassification &&
        capabilities.canUpdateClassification &&
        classification != _classificationValue(original.taskClassification)) {
      fields['taskClassification'] = classification;
    }
    if (capabilities.supportsPinning &&
        pinned != (original.taskPinned ?? false)) {
      fields['taskPinned'] = pinned;
    }
    if (capabilities.supportsSubtaskVisibility &&
        hideSubtasks != (original.taskHideSubtasks ?? false)) {
      fields['taskHideSubtasks'] = hideSubtasks;
    }
    if (capabilities.supportsSubtaskVisibility &&
        hideCompletedSubtasks !=
            (original.taskHideCompletedSubtasks ?? false)) {
      fields['taskHideCompletedSubtasks'] = hideCompletedSubtasks;
    }
    if (capabilities.supportsMultipleReminders &&
        !_sameAlarms(alarms, decodeIcalTaskAlarms(original.taskAlarmsJson))) {
      fields['taskAlarms'] = [for (final alarm in alarms) alarm.toJson()];
    }

    return fields;
  }

  TaskCreateInput toCreateInput(
    TaskCollectionCapabilities capabilities, {
    required String localTimeZone,
  }) {
    final baseline = TaskEntity(
      accountId: '',
      taskListId: taskListId,
      id: taskId,
      title: '',
      notes: '',
      status: 'needsAction',
      localDirty: false,
      pendingDelete: false,
      pendingMove: false,
      rawJson: '{}',
      updatedLocalAtUtc: '',
    );
    final fields = toPatch(
      baseline,
      capabilities,
      localTimeZone: localTimeZone,
    );
    final trimmedTitle = title.trim();
    fields['title'] = trimmedTitle;

    return TaskCreateInput(
      title: trimmedTitle,
      notes: notes.trim().isEmpty ? null : notes,
      dueUtc: dueDate == null ? null : DateTime.tryParse(dueDate!),
      categories: categories,
      fields: fields,
    );
  }

  TaskDetailsDraft copyWith({
    String? taskListId,
    String? title,
    String? notes,
    Object? dueDate = _unchanged,
    Object? microsoftDueTime = _unchanged,
    String? microsoftDueTimeZone,
    Object? microsoftStartDate = _unchanged,
    Object? microsoftStartTime = _unchanged,
    String? microsoftStartTimeZone,
    bool? microsoftReminderEnabled,
    Object? microsoftReminderDate = _unchanged,
    Object? microsoftReminderTime = _unchanged,
    String? microsoftReminderTimeZone,
    Object? recurrenceJson = _unchanged,
    String? importance,
    List<String>? categories,
    int? icalPriority,
    int? percentComplete,
    Object? taskStatus = _unchanged,
    Object? completedDate = _unchanged,
    Object? completedTime = _unchanged,
    String? location,
    String? taskUrl,
    String? classification,
    bool? pinned,
    bool? hideSubtasks,
    bool? hideCompletedSubtasks,
    List<IcalTaskAlarm>? alarms,
  }) {
    return TaskDetailsDraft(
      taskListId: taskListId ?? this.taskListId,
      taskId: taskId,
      title: title ?? this.title,
      notes: notes ?? this.notes,
      dueDate: dueDate == _unchanged ? this.dueDate : dueDate as String?,
      microsoftDueTime: microsoftDueTime == _unchanged
          ? this.microsoftDueTime
          : microsoftDueTime as String?,
      microsoftDueTimeZone: microsoftDueTimeZone ?? this.microsoftDueTimeZone,
      microsoftStartDate: microsoftStartDate == _unchanged
          ? this.microsoftStartDate
          : microsoftStartDate as String?,
      microsoftStartTime: microsoftStartTime == _unchanged
          ? this.microsoftStartTime
          : microsoftStartTime as String?,
      microsoftStartTimeZone:
          microsoftStartTimeZone ?? this.microsoftStartTimeZone,
      microsoftReminderEnabled:
          microsoftReminderEnabled ?? this.microsoftReminderEnabled,
      microsoftReminderDate: microsoftReminderDate == _unchanged
          ? this.microsoftReminderDate
          : microsoftReminderDate as String?,
      microsoftReminderTime: microsoftReminderTime == _unchanged
          ? this.microsoftReminderTime
          : microsoftReminderTime as String?,
      microsoftReminderTimeZone:
          microsoftReminderTimeZone ?? this.microsoftReminderTimeZone,
      recurrenceJson: recurrenceJson == _unchanged
          ? this.recurrenceJson
          : recurrenceJson as String?,
      importance: importance ?? this.importance,
      categories: categories ?? this.categories,
      icalPriority: icalPriority ?? this.icalPriority,
      percentComplete: percentComplete ?? this.percentComplete,
      taskStatus: taskStatus == _unchanged
          ? this.taskStatus
          : taskStatus as String?,
      completedDate: completedDate == _unchanged
          ? this.completedDate
          : completedDate as String?,
      completedTime: completedTime == _unchanged
          ? this.completedTime
          : completedTime as String?,
      location: location ?? this.location,
      taskUrl: taskUrl ?? this.taskUrl,
      classification: classification ?? this.classification,
      pinned: pinned ?? this.pinned,
      hideSubtasks: hideSubtasks ?? this.hideSubtasks,
      hideCompletedSubtasks:
          hideCompletedSubtasks ?? this.hideCompletedSubtasks,
      alarms: List.unmodifiable(alarms ?? this.alarms),
    );
  }
}

const _unchanged = Object();

var _taskScheduleTimeZonesInitialized = false;

DateTime _dateOnlyValue(DateTime value) =>
    DateTime.utc(value.year, value.month, value.day);

DateTime? _taskScheduleInstant(DateTime date, String time, String? timeZoneId) {
  final parts = time.split(':');
  if (parts.length < 2) {
    return null;
  }
  final hour = int.tryParse(parts[0]);
  final minute = int.tryParse(parts[1]);
  final second = parts.length > 2 ? int.tryParse(parts[2]) ?? 0 : 0;
  if (hour == null || minute == null) {
    return null;
  }
  if (!_taskScheduleTimeZonesInitialized) {
    time_zone_data.initializeTimeZones();
    _taskScheduleTimeZonesInitialized = true;
  }
  final requestedZone = timeZoneId?.trim();
  final normalizedZone = requestedZone == null || requestedZone.isEmpty
      ? 'Etc/UTC'
      : requestedZone == 'UTC'
      ? 'Etc/UTC'
      : requestedZone;
  try {
    return time_zone.TZDateTime(
      time_zone.getLocation(normalizedZone),
      date.year,
      date.month,
      date.day,
      hour,
      minute,
      second,
    ).toUtc();
  } on time_zone.LocationNotFoundException {
    return DateTime.utc(date.year, date.month, date.day, hour, minute, second);
  }
}

void _putDateTimePatch(
  Map<String, Object?> fields, {
  required String? originalDateTime,
  required String originalTimeZone,
  required String? date,
  required String? time,
  required String timeZone,
  required String dateTimeField,
  required String timeZoneField,
}) {
  final changed =
      date != _providerDatePart(originalDateTime, originalTimeZone) ||
      time != _providerTimePart(originalDateTime, originalTimeZone) ||
      timeZone != _editorTimeZone(originalDateTime, originalTimeZone, timeZone);
  if (!changed) {
    return;
  }

  if ((date == null || date.isEmpty) && (time == null || time.isEmpty)) {
    fields[dateTimeField] = null;
  } else {
    fields[dateTimeField] = _graphDateTime(
      date ?? _todayDateOnly(),
      time,
      timeZone,
    );
  }
  fields[timeZoneField] = timeZone;
}

String? _dateOnly(String? value) {
  if (value == null || value.length < 10) {
    return null;
  }
  return value.substring(0, 10);
}

String? _datePart(String? value) {
  if (value == null || value.length < 10) {
    return null;
  }
  return value.substring(0, 10);
}

String? _timePart(String? value) {
  if (value == null || value.isEmpty) {
    return null;
  }
  final separatorIndex = value.indexOf('T');
  if (separatorIndex < 0 || separatorIndex + 1 >= value.length) {
    return null;
  }
  final time = value.substring(separatorIndex + 1);
  if (time.length < 5) {
    return null;
  }
  return time.substring(0, 5);
}

String? _providerDatePart(String? value, String? timeZone) {
  final parsed = providerDateTimeAsLocal(value, timeZone);
  if (parsed == null) {
    return _datePart(value);
  }
  return encodeGoogleDateOnly(parsed);
}

String? _providerTimePart(String? value, String? timeZone) {
  if (value == null || !value.contains('T')) {
    return null;
  }
  final parsed = providerDateTimeAsLocal(value, timeZone);
  if (parsed == null) {
    return _timePart(value);
  }
  return '${parsed.hour.toString().padLeft(2, '0')}:'
      '${parsed.minute.toString().padLeft(2, '0')}';
}

String _editorTimeZone(
  String? value,
  String? providerTimeZone,
  String localTimeZone,
) {
  if (providerDateTimeIsInstant(value, providerTimeZone)) {
    return localTimeZone;
  }
  return providerTimeZone ?? localTimeZone;
}

Map<String, Object?> _graphDateTime(
  String date,
  String? time,
  String timeZone,
) {
  return {
    'dateTime': time == null ? date : '${date}T${_timeForGraph(time)}',
    'timeZone': timeZone,
  };
}

String _timeForGraph(String time) {
  if (time.length == 5) {
    return '$time:00';
  }
  return time.length >= 8 ? time.substring(0, 8) : time;
}

String _todayDateOnly() {
  return encodeGoogleDateOnly(DateTime.now());
}

String _currentTimeString() {
  final now = DateTime.now();
  return '${now.hour.toString().padLeft(2, '0')}:'
      '${now.minute.toString().padLeft(2, '0')}:00';
}

String _importanceValue(String? value) {
  return switch (value) {
    'low' || 'high' => value!,
    _ => 'normal',
  };
}

List<String> _categories(String? categoriesJson) {
  if (categoriesJson == null || categoriesJson.isEmpty) {
    return const [];
  }
  try {
    final decoded = jsonDecode(categoriesJson);
    if (decoded is List) {
      return decoded.map((item) => item.toString()).toList();
    }
  } on FormatException {
    return const [];
  }
  return const [];
}

bool _sameStrings(List<String> left, List<String> right) {
  if (left.length != right.length) {
    return false;
  }
  for (var index = 0; index < left.length; index += 1) {
    if (left[index] != right[index]) {
      return false;
    }
  }
  return true;
}

bool _sameAlarms(List<IcalTaskAlarm> left, List<IcalTaskAlarm> right) {
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index += 1) {
    if (left[index] != right[index]) return false;
  }
  return true;
}

String? _icalStatus(String? value) => switch (value?.toUpperCase()) {
  'NEEDS-ACTION' ||
  'IN-PROCESS' ||
  'COMPLETED' ||
  'CANCELLED' => value!.toUpperCase(),
  _ => null,
};

String _classificationValue(String? value) => switch (value?.toUpperCase()) {
  'PRIVATE' || 'CONFIDENTIAL' => value!.toUpperCase(),
  _ => 'PUBLIC',
};

String? _localDatePart(String? value) {
  final parsed = DateTime.tryParse(value ?? '');
  if (parsed == null) return null;
  final local = parsed.toLocal();
  return '${local.year.toString().padLeft(4, '0')}-'
      '${local.month.toString().padLeft(2, '0')}-'
      '${local.day.toString().padLeft(2, '0')}';
}

String? _localTimePart(String? value) {
  final parsed = DateTime.tryParse(value ?? '');
  if (parsed == null) return null;
  final local = parsed.toLocal();
  return '${local.hour.toString().padLeft(2, '0')}:'
      '${local.minute.toString().padLeft(2, '0')}';
}

String? _completedUtc(String? date, String? time) {
  if (date == null || date.isEmpty) return null;
  final parsed = DateTime.tryParse('${date}T${time ?? '00:00'}:00');
  return parsed?.toUtc().toIso8601String();
}

bool _sameInstant(String? left, String? right) {
  if (left == null || right == null) return left == right;
  final leftValue = DateTime.tryParse(left);
  final rightValue = DateTime.tryParse(right);
  if (leftValue == null || rightValue == null) return left == right;
  return leftValue.toUtc() == rightValue.toUtc();
}

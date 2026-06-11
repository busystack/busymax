import 'dart:convert';

import '../../../google_tasks/api/google_tasks_json.dart';
import '../../../task_providers/task_provider.dart';
import '../data/tasks_repository.dart';

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
  });

  factory TaskDetailsDraft.fromTask(TaskEntity task, String localTimeZone) {
    return TaskDetailsDraft(
      taskListId: task.taskListId,
      taskId: task.id,
      title: task.title,
      notes: task.notes ?? '',
      dueDate: _dateOnly(task.dueUtc),
      microsoftDueTime: _scheduleTimePart(task.microsoftDueDateTime),
      microsoftDueTimeZone: task.microsoftDueTimeZone ?? localTimeZone,
      microsoftStartDate: _datePart(task.microsoftStartDateTime),
      microsoftStartTime: _scheduleTimePart(task.microsoftStartDateTime),
      microsoftStartTimeZone: task.microsoftStartTimeZone ?? localTimeZone,
      microsoftReminderEnabled: task.microsoftIsReminderOn ?? false,
      microsoftReminderDate: _datePart(task.microsoftReminderDateTime),
      microsoftReminderTime: _timePart(task.microsoftReminderDateTime),
      microsoftReminderTimeZone:
          task.microsoftReminderTimeZone ?? localTimeZone,
      recurrenceJson: task.recurrenceJson,
      importance: _importanceValue(task.importance),
      categories: _categories(task.categoriesJson),
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
        _sameStrings(categories, other.categories);
  }

  bool differsFrom(
    TaskEntity task,
    TaskProviderCapabilities capabilities, {
    required String localTimeZone,
  }) {
    if (taskListId != task.taskListId) {
      return true;
    }
    return toPatch(task, capabilities, localTimeZone: localTimeZone).isNotEmpty;
  }

  Map<String, Object?> toPatch(
    TaskEntity original,
    TaskProviderCapabilities capabilities, {
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
      final originalDueTime = _scheduleTimePart(original.microsoftDueDateTime);
      final originalDueZone = original.microsoftDueTimeZone ?? localTimeZone;
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
              _datePart(original.microsoftReminderDateTime) ||
          microsoftReminderTime !=
              _timePart(original.microsoftReminderDateTime) ||
          (microsoftReminderTimeZone ?? localTimeZone) !=
              (original.microsoftReminderTimeZone ?? localTimeZone);
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
        importance != _importanceValue(original.importance)) {
      fields['importance'] = importance;
    }
    if (capabilities.supportsCategories &&
        !_sameStrings(categories, _categories(original.categoriesJson))) {
      fields['categories'] = categories;
    }

    return fields;
  }

  TaskCreateInput toCreateInput(
    TaskProviderCapabilities capabilities, {
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
    );
  }
}

const _unchanged = Object();

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
      date != _datePart(originalDateTime) ||
      time != _scheduleTimePart(originalDateTime) ||
      timeZone != originalTimeZone;
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

String? _scheduleTimePart(String? value) {
  return _timePart(value);
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

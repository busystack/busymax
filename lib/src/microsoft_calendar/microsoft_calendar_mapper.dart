import '../calendar_providers/calendar_colors.dart';
import '../calendar_providers/calendar_mutation.dart';
import '../calendar_providers/calendar_description.dart';
import '../calendar_providers/calendar_sync_dto.dart';
import '../task_providers/task_provider.dart';

CalendarSourceDto microsoftCalendarSourceFromJson(Map<String, Object?> json) {
  final canEdit = json['canEdit'];
  return CalendarSourceDto(
    provider: TaskProvider.microsoft,
    providerCalendarId: json['id']?.toString() ?? '',
    summary: json['name']?.toString().trim().isNotEmpty == true
        ? json['name']!.toString()
        : 'Calendar',
    primaryCalendar: json['isDefaultCalendar'] == true,
    selected: true,
    hidden: false,
    readOnly: canEdit is bool ? !canEdit : false,
    backgroundColor: calendarSourceBackgroundColorHex(
      provider: TaskProvider.microsoft,
      backgroundColor: json['hexColor']?.toString(),
      colorId: json['color']?.toString(),
    ),
    colorId: json['color']?.toString(),
    accessRole: canEdit is bool && canEdit ? 'writer' : 'reader',
    isDeleted: json['@removed'] != null,
    rawJson: json,
  );
}

CalendarEventDto microsoftCalendarEventFromJson(
  String calendarId,
  Map<String, Object?> json,
) {
  final start = _mapValue(json['start']);
  final end = _mapValue(json['end']);
  final location = _mapValue(json['location']);
  final body = _mapValue(json['body']);
  final isAllDay = json['isAllDay'] == true;
  final status = json['isCancelled'] == true ? 'cancelled' : null;
  return CalendarEventDto(
    provider: TaskProvider.microsoft,
    providerCalendarId: calendarId,
    providerEventId: json['id']?.toString() ?? '',
    providerRecurringEventId: json['seriesMasterId']?.toString(),
    providerOriginalStartKey: json['originalStart']?.toString(),
    etagOrChangeKey: json['changeKey']?.toString(),
    status: status,
    title: json['subject']?.toString().trim().isNotEmpty == true
        ? json['subject']!.toString()
        : '(No title)',
    description: calendarDescriptionDocumentFromBody(
      content: body['content']?.toString(),
      contentType: body['contentType']?.toString(),
    ).text,
    location: location['displayName']?.toString(),
    allDay: isAllDay,
    startDate: isAllDay ? _dateOnly(start['dateTime']) : null,
    startDateTime: start['dateTime']?.toString(),
    startTimeZone: start['timeZone']?.toString(),
    endDate: isAllDay ? _dateOnly(end['dateTime']) : null,
    endDateTime: end['dateTime']?.toString(),
    endTimeZone: end['timeZone']?.toString(),
    recurrenceJson: json['recurrence'],
    remindersJson: {
      'isReminderOn': json['isReminderOn'],
      'reminderMinutesBeforeStart': json['reminderMinutesBeforeStart'],
    },
    attendeesJson: json['attendees'],
    categoriesJson: json['categories'],
    organizerJson: json['organizer'],
    colorId: _firstCategory(json['categories']),
    colorHex: null,
    visibility: json['sensitivity']?.toString(),
    transparencyOrShowAs: json['showAs']?.toString(),
    eventType: json['type']?.toString(),
    webLink: json['webLink']?.toString(),
    conferenceJson: json['onlineMeeting'],
    attachmentsJson: json['hasAttachments'] == true ? const [] : null,
    isCancelled: json['isCancelled'] == true,
    isDeleted: json['@removed'] != null,
    createdAtServer: json['createdDateTime']?.toString(),
    updatedAtServer: json['lastModifiedDateTime']?.toString(),
    rawJson: json,
  );
}

Map<String, Object?> microsoftCalendarMutationToJson(
  CalendarMutation mutation,
) {
  return _compact({'name': mutation.summary});
}

Map<String, Object?> microsoftEventMutationToJson(
  CalendarEventMutation mutation,
) {
  final isAllDay = mutation.allDay == true;
  final startTimeZone = mutation.startTimeZone ?? 'UTC';
  final endTimeZone = mutation.endTimeZone ?? startTimeZone;
  return _compact({
    'subject': mutation.title,
    if (_bodyPatch(mutation) != null) 'body': _bodyPatch(mutation),
    if (mutation.location != null)
      'location': {'displayName': mutation.location},
    'isAllDay': mutation.allDay,
    if (_startDateTime(mutation) != null)
      'start': {
        'dateTime': _startDateTime(mutation),
        'timeZone': startTimeZone,
      },
    if (_endDateTime(mutation) != null)
      'end': {'dateTime': _endDateTime(mutation), 'timeZone': endTimeZone},
    'recurrence': mutation.recurrence,
    'attendees': mutation.attendees,
    'categories': mutation.categories,
    'importance': mutation.importance,
    'showAs': mutation.transparencyOrShowAs,
    'sensitivity': mutation.sensitivity ?? mutation.visibility,
    'responseRequested': mutation.responseRequested,
    'hideAttendees': mutation.hideAttendees,
    'allowNewTimeProposals': mutation.allowNewTimeProposals,
    if (mutation.reminders is Map) ..._reminderPatch(mutation.reminders!),
    if (isAllDay && mutation.reminders != null) 'isReminderOn': true,
    if (_onlineMeetingProvider(mutation.conference) != null)
      'onlineMeetingProvider': _onlineMeetingProvider(mutation.conference),
  });
}

Map<String, Object?>? _bodyPatch(CalendarEventMutation mutation) {
  final contentType = mutation.descriptionContentType?.toLowerCase();
  final html = mutation.descriptionHtml;
  if (contentType == 'html' || html != null) {
    return {
      'contentType': 'html',
      'content': html ?? escapeHtml(mutation.description ?? ''),
    };
  }
  if (mutation.description != null) {
    return {'contentType': 'text', 'content': mutation.description};
  }
  return null;
}

String? _onlineMeetingProvider(Object? conference) {
  if (conference is String && conference.trim().isNotEmpty) {
    return conference.trim();
  }
  return null;
}

Map<String, Object?> _reminderPatch(Object reminders) {
  if (reminders is! Map) {
    return const {};
  }
  final map = reminders.cast<String, Object?>();
  return _compact({
    'isReminderOn': map['isReminderOn'],
    'reminderMinutesBeforeStart': map['reminderMinutesBeforeStart'],
  });
}

String? _startDateTime(CalendarEventMutation mutation) {
  if (mutation.allDay == true && mutation.startDate != null) {
    return '${mutation.startDate}T00:00:00.0000000';
  }
  return mutation.startDateTime;
}

String? _endDateTime(CalendarEventMutation mutation) {
  if (mutation.allDay == true && mutation.endDate != null) {
    return '${mutation.endDate}T00:00:00.0000000';
  }
  return mutation.endDateTime;
}

Map<String, Object?> _mapValue(Object? value) {
  if (value is Map<String, Object?>) {
    return value;
  }
  if (value is Map) {
    return value.cast<String, Object?>();
  }
  return const {};
}

String? _firstCategory(Object? value) {
  if (value is List && value.isNotEmpty) {
    return value.first?.toString();
  }
  return null;
}

String? _dateOnly(Object? value) {
  final text = value?.toString();
  if (text == null || text.length < 10) {
    return null;
  }
  return text.substring(0, 10);
}

Map<String, Object?> _compact(Map<String, Object?> input) {
  return {
    for (final entry in input.entries)
      if (entry.value != null) entry.key: entry.value,
  };
}

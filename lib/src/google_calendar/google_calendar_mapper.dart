import 'dart:convert';

import '../calendar_providers/calendar_mutation.dart';
import '../calendar_providers/calendar_sync_dto.dart';
import '../task_providers/task_provider.dart';

CalendarSourceDto googleCalendarSourceFromJson(Map<String, Object?> json) {
  final accessRole = json['accessRole']?.toString();
  return CalendarSourceDto(
    provider: TaskProvider.google,
    providerCalendarId: json['id']?.toString() ?? '',
    summary: json['summary']?.toString().trim().isNotEmpty == true
        ? json['summary']!.toString()
        : 'Calendar',
    description: json['description']?.toString(),
    primaryCalendar: json['primary'] == true,
    selected: json['selected'] as bool? ?? true,
    hidden: json['hidden'] as bool? ?? false,
    readOnly: accessRole == 'reader' || accessRole == 'freeBusyReader',
    backgroundColor: json['backgroundColor']?.toString(),
    foregroundColor: json['foregroundColor']?.toString(),
    colorId: json['colorId']?.toString(),
    timeZone: json['timeZone']?.toString(),
    accessRole: accessRole,
    isDeleted: json['deleted'] == true,
    rawJson: json,
  );
}

CalendarEventDto googleCalendarEventFromJson(
  String calendarId,
  Map<String, Object?> json,
) {
  final start = _mapValue(json['start']);
  final end = _mapValue(json['end']);
  final originalStart = _mapValue(json['originalStartTime']);
  final startDate = start['date']?.toString();
  final status = json['status']?.toString();
  return CalendarEventDto(
    provider: TaskProvider.google,
    providerCalendarId: calendarId,
    providerEventId: json['id']?.toString() ?? '',
    providerRecurringEventId: json['recurringEventId']?.toString(),
    providerOriginalStartKey:
        originalStart['date']?.toString() ??
        originalStart['dateTime']?.toString(),
    etagOrChangeKey: json['etag']?.toString(),
    status: status,
    title: json['summary']?.toString().trim().isNotEmpty == true
        ? json['summary']!.toString()
        : '(No title)',
    description: json['description']?.toString(),
    location: json['location']?.toString(),
    allDay: startDate != null,
    startDate: startDate,
    startDateTime: start['dateTime']?.toString(),
    startTimeZone: start['timeZone']?.toString(),
    endDate: end['date']?.toString(),
    endDateTime: end['dateTime']?.toString(),
    endTimeZone: end['timeZone']?.toString(),
    recurrenceJson: json['recurrence'],
    remindersJson: json['reminders'],
    attendeesJson: json['attendees'],
    organizerJson: json['organizer'],
    creatorJson: json['creator'],
    colorId: json['colorId']?.toString(),
    visibility: json['visibility']?.toString(),
    transparencyOrShowAs: json['transparency']?.toString(),
    eventType: json['eventType']?.toString(),
    webLink: json['htmlLink']?.toString(),
    conferenceJson: json['conferenceData'],
    attachmentsJson: json['attachments'],
    isCancelled: status == 'cancelled',
    isDeleted: status == 'cancelled',
    createdAtServer: json['created']?.toString(),
    updatedAtServer: json['updated']?.toString(),
    rawJson: json,
  );
}

Map<String, Object?> googleCalendarMutationToJson(CalendarMutation mutation) {
  return _compact({
    'summary': mutation.summary,
    'description': mutation.description,
    'timeZone': mutation.timeZone,
  });
}

Map<String, Object?> googleCalendarListMutationToJson(
  CalendarMutation mutation,
) {
  return _compact({
    'summaryOverride': mutation.summary,
    'backgroundColor': mutation.backgroundColor,
    'foregroundColor': mutation.foregroundColor,
    'colorId': mutation.colorId,
  });
}

Map<String, Object?> googleEventMutationToJson(CalendarEventMutation mutation) {
  final allDay = mutation.allDay ?? mutation.startDate != null;
  final start = allDay
      ? _compact({'date': mutation.startDate})
      : _compact({
          'dateTime': mutation.startDateTime,
          'timeZone': mutation.startTimeZone,
        });
  final end = allDay
      ? _compact({'date': mutation.endDate})
      : _compact({
          'dateTime': mutation.endDateTime,
          'timeZone': mutation.endTimeZone,
        });

  return _compact({
    'summary': mutation.title,
    'description': mutation.description,
    'location': mutation.location,
    if (start.isNotEmpty) 'start': start,
    if (end.isNotEmpty) 'end': end,
    'recurrence': mutation.clearRecurrence
        ? const <Object?>[]
        : mutation.recurrence,
    'reminders': mutation.reminders,
    'attendees': mutation.clearAttendees
        ? const <Object?>[]
        : mutation.attendees,
    'colorId': mutation.colorId,
    'visibility': mutation.visibility,
    'transparency': mutation.transparencyOrShowAs,
    'conferenceData': mutation.conference,
  });
}

String jsonOrNull(Object? value) {
  if (value == null) {
    return '';
  }
  return jsonEncode(value);
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

Map<String, Object?> _compact(Map<String, Object?> input) {
  return {
    for (final entry in input.entries)
      if (entry.value != null) entry.key: entry.value,
  };
}

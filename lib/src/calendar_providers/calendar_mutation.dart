class CalendarMutation {
  const CalendarMutation({
    this.summary,
    this.description,
    this.timeZone,
    this.backgroundColor,
    this.foregroundColor,
    this.colorId,
  });

  final String? summary;
  final String? description;
  final String? timeZone;
  final String? backgroundColor;
  final String? foregroundColor;
  final String? colorId;
}

const calendarEventClearFieldsKey = '_clearFields';
const calendarEventRecurrenceField = 'recurrenceJson';
const calendarEventAttendeesField = 'attendeesJson';

class CalendarEventMutation {
  const CalendarEventMutation({
    this.title,
    this.description,
    this.descriptionContentType,
    this.descriptionHtml,
    this.location,
    this.allDay,
    this.startDate,
    this.startDateTime,
    this.startTimeZone,
    this.endDate,
    this.endDateTime,
    this.endTimeZone,
    this.recurrence,
    this.clearRecurrence = false,
    this.reminders,
    this.attendees,
    this.clearAttendees = false,
    this.colorId,
    this.visibility,
    this.transparencyOrShowAs,
    this.conference,
    this.categories,
    this.importance,
    this.sensitivity,
    this.responseRequested,
    this.hideAttendees,
    this.allowNewTimeProposals,
  });

  final String? title;
  final String? description;
  final String? descriptionContentType;
  final String? descriptionHtml;
  final String? location;
  final bool? allDay;
  final String? startDate;
  final String? startDateTime;
  final String? startTimeZone;
  final String? endDate;
  final String? endDateTime;
  final String? endTimeZone;
  final Object? recurrence;
  final bool clearRecurrence;
  final Object? reminders;
  final Object? attendees;
  final bool clearAttendees;
  final String? colorId;
  final String? visibility;
  final String? transparencyOrShowAs;
  final Object? conference;
  final List<String>? categories;
  final String? importance;
  final String? sensitivity;
  final bool? responseRequested;
  final bool? hideAttendees;
  final bool? allowNewTimeProposals;
}

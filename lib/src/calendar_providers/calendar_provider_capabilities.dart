class CalendarProviderCapabilities {
  const CalendarProviderCapabilities({
    required this.supportsCreateCalendar,
    required this.supportsDeleteCalendar,
    required this.supportsCalendarColor,
    required this.supportsEventColor,
    required this.supportsAllDayEvents,
    required this.supportsTimedEvents,
    required this.supportsRecurringEvents,
    required this.supportsEventReminders,
    required this.supportsAttendees,
    required this.supportsConferenceData,
    required this.supportsAttachments,
    required this.supportsFreeBusy,
    required this.supportsCalendarDelta,
    required this.supportsEventDelta,
  });

  final bool supportsCreateCalendar;
  final bool supportsDeleteCalendar;
  final bool supportsCalendarColor;
  final bool supportsEventColor;
  final bool supportsAllDayEvents;
  final bool supportsTimedEvents;
  final bool supportsRecurringEvents;
  final bool supportsEventReminders;
  final bool supportsAttendees;
  final bool supportsConferenceData;
  final bool supportsAttachments;
  final bool supportsFreeBusy;
  final bool supportsCalendarDelta;
  final bool supportsEventDelta;
}

const googleCalendarProviderCapabilities = CalendarProviderCapabilities(
  supportsCreateCalendar: true,
  supportsDeleteCalendar: true,
  supportsCalendarColor: true,
  supportsEventColor: true,
  supportsAllDayEvents: true,
  supportsTimedEvents: true,
  supportsRecurringEvents: true,
  supportsEventReminders: true,
  supportsAttendees: true,
  supportsConferenceData: true,
  supportsAttachments: true,
  supportsFreeBusy: true,
  supportsCalendarDelta: true,
  supportsEventDelta: true,
);

const microsoftCalendarProviderCapabilities = CalendarProviderCapabilities(
  supportsCreateCalendar: true,
  supportsDeleteCalendar: true,
  supportsCalendarColor: true,
  supportsEventColor: true,
  supportsAllDayEvents: true,
  supportsTimedEvents: true,
  supportsRecurringEvents: true,
  supportsEventReminders: true,
  supportsAttendees: true,
  supportsConferenceData: true,
  supportsAttachments: false,
  supportsFreeBusy: false,
  supportsCalendarDelta: false,
  supportsEventDelta: true,
);

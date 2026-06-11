import '../task_providers/task_provider.dart';

class CalendarSourceDto {
  const CalendarSourceDto({
    required this.provider,
    required this.providerCalendarId,
    required this.summary,
    this.description,
    this.primaryCalendar = false,
    this.selected = true,
    this.hidden = false,
    this.readOnly = false,
    this.backgroundColor,
    this.foregroundColor,
    this.colorId,
    this.timeZone,
    this.accessRole,
    this.isDeleted = false,
    this.rawJson = const {},
  });

  final BusyProvider provider;
  final String providerCalendarId;
  final String summary;
  final String? description;
  final bool primaryCalendar;
  final bool selected;
  final bool hidden;
  final bool readOnly;
  final String? backgroundColor;
  final String? foregroundColor;
  final String? colorId;
  final String? timeZone;
  final String? accessRole;
  final bool isDeleted;
  final Map<String, Object?> rawJson;
}

class CalendarEventDto {
  const CalendarEventDto({
    required this.provider,
    required this.providerCalendarId,
    required this.providerEventId,
    required this.title,
    this.providerRecurringEventId,
    this.providerOriginalStartKey,
    this.etagOrChangeKey,
    this.status,
    this.description,
    this.location,
    this.allDay = false,
    this.startDate,
    this.startDateTime,
    this.startTimeZone,
    this.endDate,
    this.endDateTime,
    this.endTimeZone,
    this.recurrenceJson,
    this.remindersJson,
    this.attendeesJson,
    this.categoriesJson,
    this.organizerJson,
    this.creatorJson,
    this.colorId,
    this.colorHex,
    this.visibility,
    this.transparencyOrShowAs,
    this.eventType,
    this.webLink,
    this.conferenceJson,
    this.attachmentsJson,
    this.isCancelled = false,
    this.isDeleted = false,
    this.createdAtServer,
    this.updatedAtServer,
    this.rawJson = const {},
  });

  final BusyProvider provider;
  final String providerCalendarId;
  final String providerEventId;
  final String? providerRecurringEventId;
  final String? providerOriginalStartKey;
  final String? etagOrChangeKey;
  final String? status;
  final String title;
  final String? description;
  final String? location;
  final bool allDay;
  final String? startDate;
  final String? startDateTime;
  final String? startTimeZone;
  final String? endDate;
  final String? endDateTime;
  final String? endTimeZone;
  final Object? recurrenceJson;
  final Object? remindersJson;
  final Object? attendeesJson;
  final Object? categoriesJson;
  final Object? organizerJson;
  final Object? creatorJson;
  final String? colorId;
  final String? colorHex;
  final String? visibility;
  final String? transparencyOrShowAs;
  final String? eventType;
  final String? webLink;
  final Object? conferenceJson;
  final Object? attachmentsJson;
  final bool isCancelled;
  final bool isDeleted;
  final String? createdAtServer;
  final String? updatedAtServer;
  final Map<String, Object?> rawJson;
}

class CalendarSyncPageDto {
  const CalendarSyncPageDto({
    required this.events,
    this.nextPageTokenOrUrl,
    this.nextSyncTokenOrDeltaLink,
    this.requiresFullSync = false,
  });

  final List<CalendarEventDto> events;
  final String? nextPageTokenOrUrl;
  final String? nextSyncTokenOrDeltaLink;
  final bool requiresFullSync;
}

class BusySlotDto {
  const BusySlotDto({
    required this.calendarId,
    required this.start,
    required this.end,
  });

  final String calendarId;
  final DateTime start;
  final DateTime end;
}

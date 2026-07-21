import '../task_providers/task_provider.dart';
import 'calendar_mutation.dart';
import 'calendar_provider_capabilities.dart';
import 'calendar_sync_dto.dart';

abstract interface class CloudCalendarClient {
  BusyProvider get provider;
  CalendarProviderCapabilities get capabilities;

  Future<List<CalendarSourceDto>> listCalendars();
  Future<CalendarSourceDto> createCalendar(CalendarMutation mutation);
  Future<CalendarSourceDto> updateCalendar(
    String calendarId,
    CalendarMutation mutation,
  );
  Future<void> deleteCalendar(String calendarId);

  Future<List<CalendarEventDto>> listEvents({
    required String calendarId,
    required DateTime rangeStart,
    required DateTime rangeEnd,
    String? pageTokenOrUrl,
  });

  Future<CalendarEventDto> createEvent({
    required String calendarId,
    required CalendarEventMutation mutation,
  });

  Future<CalendarEventDto> getEvent({
    required String calendarId,
    required String eventId,
  });

  Future<CalendarEventDto> updateEvent({
    required String calendarId,
    required String eventId,
    required CalendarEventMutation mutation,
  });

  Future<void> deleteEvent({
    required String calendarId,
    required String eventId,
  });

  Future<List<CalendarEventDto>> listEventInstances({
    required String calendarId,
    required String recurringEventId,
    required DateTime rangeStart,
    required DateTime rangeEnd,
  });

  Future<CalendarSyncPageDto> syncEvents({
    required String calendarId,
    required DateTime rangeStart,
    required DateTime rangeEnd,
    String? syncTokenOrDeltaLink,
    bool primaryCalendar = false,
  });

  Future<List<BusySlotDto>> freeBusy({
    required List<String> calendarIds,
    required DateTime rangeStart,
    required DateTime rangeEnd,
  });
}

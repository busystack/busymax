import 'package:busymax/src/providers/busy_provider.dart';
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
    CalendarGuestUpdatePolicy guestUpdatePolicy =
        CalendarGuestUpdatePolicy.send,
  });

  Future<CalendarEventDto> getEvent({
    required String calendarId,
    required String eventId,
  });

  Future<CalendarEventDto> updateEvent({
    required String calendarId,
    required String eventId,
    required CalendarEventMutation mutation,
    CalendarGuestUpdatePolicy guestUpdatePolicy =
        CalendarGuestUpdatePolicy.send,
  });

  Future<void> deleteEvent({
    required String calendarId,
    required String eventId,
    CalendarGuestUpdatePolicy guestUpdatePolicy =
        CalendarGuestUpdatePolicy.send,
  });

  Future<CalendarEventDto> moveEvent({
    required String sourceCalendarId,
    required String eventId,
    required String destinationCalendarId,
    CalendarGuestUpdatePolicy guestUpdatePolicy =
        CalendarGuestUpdatePolicy.send,
  });

  Future<CalendarEventDto?> respondToEvent({
    required String calendarId,
    required String eventId,
    required CalendarInvitationResponse response,
    String? attendeeEmail,
    bool sendResponse = true,
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

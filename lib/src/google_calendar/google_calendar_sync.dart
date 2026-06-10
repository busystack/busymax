import '../calendar_providers/calendar_sync_dto.dart';
import 'google_calendar_api_client.dart';

class GoogleCalendarSync {
  const GoogleCalendarSync(this.client);

  final GoogleCalendarApiClient client;

  Future<CalendarSyncPageDto> fullSyncWindow({
    required String calendarId,
    required DateTime now,
  }) {
    return client.syncEvents(
      calendarId: calendarId,
      rangeStart: now.subtract(const Duration(days: 365)),
      rangeEnd: now.add(const Duration(days: 365 * 2)),
    );
  }

  Future<CalendarSyncPageDto> incrementalSync({
    required String calendarId,
    required DateTime now,
    required String syncToken,
  }) {
    return client.syncEvents(
      calendarId: calendarId,
      rangeStart: now.subtract(const Duration(days: 365)),
      rangeEnd: now.add(const Duration(days: 365 * 2)),
      syncTokenOrDeltaLink: syncToken,
    );
  }
}

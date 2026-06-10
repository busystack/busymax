import '../calendar_providers/calendar_sync_dto.dart';
import 'microsoft_calendar_api_client.dart';

class MicrosoftCalendarSync {
  const MicrosoftCalendarSync(this.client);

  final MicrosoftCalendarApiClient client;

  Future<CalendarSyncPageDto> fullRefreshWindow({
    required String calendarId,
    required DateTime now,
  }) {
    return client.syncEvents(
      calendarId: calendarId,
      rangeStart: now.subtract(const Duration(days: 365)),
      rangeEnd: now.add(const Duration(days: 365 * 2)),
    );
  }
}

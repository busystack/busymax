import '../../../calendar_providers/calendar_sync_dto.dart';
import '../../../calendar_providers/cloud_calendar_client.dart';
import '../domain/event_editor_draft.dart';

Future<Map<String, FreeBusyCalendarResultDto>> loadCloudGuestAvailability({
  required Object? client,
  required EventEditorDraft draft,
  required String? calendarTimeZone,
}) async {
  final interval = draft.cloudAvailabilityInterval(
    calendarTimeZone: calendarTimeZone,
  );
  if (client == null || interval == null) {
    throw StateError('Availability is unavailable.');
  }
  final recipients = <String, String>{};
  for (final attendee in draft.attendees) {
    final email = attendee.email.trim();
    if (!attendee.self && !attendee.organizer && email.isNotEmpty) {
      recipients.putIfAbsent(eventAttendeeIdentity(email), () => email);
    }
  }
  if (recipients.isEmpty) return const {};
  final results = client is DetailedFreeBusyClient
      ? await client.freeBusyDetails(
          calendarIds: recipients.values.toList(),
          rangeStart: interval.start.toUtc(),
          rangeEnd: interval.end.toUtc(),
        )
      : const <FreeBusyCalendarResultDto>[];
  final byIdentity = {
    for (final row in results) eventAttendeeIdentity(row.calendarId): row,
  };
  return {
    for (final MapEntry(key: identity, value: email) in recipients.entries)
      email:
          byIdentity[identity] ??
          FreeBusyCalendarResultDto(
            calendarId: email,
            status: FreeBusyEvaluationStatus.missing,
          ),
  };
}

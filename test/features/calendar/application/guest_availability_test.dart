import 'package:busymax/src/calendar_providers/calendar_sync_dto.dart';
import 'package:busymax/src/calendar_providers/cloud_calendar_client.dart';
import 'package:busymax/src/features/calendar/application/guest_availability.dart';
import 'package:busymax/src/features/calendar/domain/event_editor_draft.dart';
import 'package:flutter_test/flutter_test.dart';

class _AvailabilityClient implements DetailedFreeBusyClient {
  @override
  Future<List<FreeBusyCalendarResultDto>> freeBusyDetails({
    required List<String> calendarIds,
    required DateTime rangeStart,
    required DateTime rangeEnd,
  }) async {
    expect(calendarIds, ['Ada@example.com', 'meera@example.com']);
    expect(rangeStart, DateTime.utc(2026, 11, 17, 9));
    expect(rangeEnd, DateTime.utc(2026, 11, 17, 10));
    return const [
      FreeBusyCalendarResultDto(
        calendarId: 'ada@example.com',
        status: FreeBusyEvaluationStatus.success,
      ),
    ];
  }
}

void main() {
  test('an omitted attendee has unknown availability across clients', () async {
    final draft =
        EventEditorDraft.newEvent(
          accountId: 'account',
          sourceId: 'calendar',
          providerCalendarId: 'provider-calendar',
          start: DateTime(2026, 11, 17, 9),
          end: DateTime(2026, 11, 17, 10),
        ).copyWith(
          startTimeZone: 'UTC',
          endTimeZone: 'UTC',
          attendees: const [
            EventAttendeeDraft(email: ' Ada@example.com '),
            EventAttendeeDraft(email: 'ada@example.com'),
            EventAttendeeDraft(email: 'meera@example.com'),
            EventAttendeeDraft(email: 'organizer@example.com', organizer: true),
          ],
        );

    final result = await loadCloudGuestAvailability(
      client: _AvailabilityClient(),
      draft: draft,
      calendarTimeZone: 'UTC',
    );
    expect(result['Ada@example.com']?.succeeded, isTrue);
    expect(
      result['meera@example.com']?.status,
      FreeBusyEvaluationStatus.missing,
    );
    expect(result['meera@example.com']?.succeeded, isFalse);
  });
}

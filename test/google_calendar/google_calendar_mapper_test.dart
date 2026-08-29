import 'package:busymax/src/calendar_providers/calendar_mutation.dart';
import 'package:busymax/src/google_calendar/google_calendar_mapper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Google calendar source maps data owner and personal name', () {
    final source = googleCalendarSourceFromJson({
      'id': 'shared@example.com',
      'summary': 'Team calendar',
      'summaryOverride': 'My team',
      'dataOwner': 'owner@example.com',
      'accessRole': 'reader',
    });

    expect(source.summary, 'My team');
    expect(source.dataOwner, 'owner@example.com');
    expect(source.readOnly, isTrue);
  });

  test('Google guest visibility maps from the shared hide-attendees field', () {
    expect(
      googleEventMutationToJson(
        const CalendarEventMutation(hideAttendees: true),
      )['guestsCanSeeOtherGuests'],
      isFalse,
    );
    expect(
      googleEventMutationToJson(
        const CalendarEventMutation(hideAttendees: false),
      )['guestsCanSeeOtherGuests'],
      isTrue,
    );
  });

  test('Google conference creation request is preserved', () {
    const conference = {
      'createRequest': {
        'requestId': 'request-1',
        'conferenceSolutionKey': {'type': 'hangoutsMeet'},
      },
    };

    expect(
      googleEventMutationToJson(
        const CalendarEventMutation(conference: conference),
      )['conferenceData'],
      conference,
    );
  });
}

import 'package:busymax/src/calendar_providers/calendar_create_identity.dart';
import 'package:busymax/src/calendar_providers/calendar_mutation.dart';
import 'package:busymax/src/google_calendar/google_calendar_mapper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Google event absence of attachment field is a loaded empty list', () {
    final event = googleCalendarEventFromJson('cal', {
      'id': 'event',
      'summary': 'Planning',
    });
    expect(event.attachmentsJson, isEmpty);
  });

  test('Google create identity is stable and uses the valid ID alphabet', () {
    final first = googleCalendarCreateEventId(
      '00112233-4455-6677-8899-aabbccddeeff',
    );
    final second = googleCalendarCreateEventId(
      '00112233-4455-6677-8899-aabbccddeeff',
    );

    expect(first, second);
    expect(first, matches(RegExp(r'^[0-9a-v]{5,1024}$')));
  });

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

  test('Google calendar-list visibility is writable independently', () {
    expect(
      googleCalendarListMutationToJson(const CalendarMutation(hidden: false)),
      {'hidden': false},
    );
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

  test('Google event create serializes the client-assigned event ID', () {
    expect(
      googleEventMutationToJson(
        const CalendarEventMutation(providerEventId: '0123456789abcdef'),
      )['id'],
      '0123456789abcdef',
    );
  });

  test('Google status properties survive unrelated event edits', () {
    const cases = {
      'focusTime': {
        'focusTimeProperties': {
          'autoDeclineMode': 'declineOnlyNewConflictingInvitations',
          'declineMessage': 'Heads down',
        },
      },
      'outOfOffice': {
        'outOfOfficeProperties': {
          'autoDeclineMode': 'declineAllConflictingInvitations',
        },
      },
      'workingLocation': {
        'workingLocationProperties': {'type': 'homeOffice'},
      },
    };
    for (final entry in cases.entries) {
      final body = googleEventMutationToJson(
        CalendarEventMutation(
          title: 'Updated',
          providerRaw: {'eventType': entry.key, ...entry.value},
        ),
      );
      expect(body['eventType'], entry.key);
      for (final property in entry.value.entries) {
        expect(body[property.key], property.value);
      }
    }
  });

  test(
    'Google status creation and targeted property edits use native fields',
    () {
      for (final (type, key, properties) in [
        (
          'focusTime',
          'focusTimeProperties',
          <String, Object?>{
            'autoDeclineMode': 'declineNone',
            'chatStatus': 'doNotDisturb',
          },
        ),
        (
          'outOfOffice',
          'outOfOfficeProperties',
          <String, Object?>{
            'autoDeclineMode': 'declineOnlyNewConflictingInvitations',
          },
        ),
        (
          'workingLocation',
          'workingLocationProperties',
          <String, Object?>{
            'type': 'customLocation',
            'customLocation': {'label': 'Site'},
          },
        ),
      ]) {
        final created = googleEventMutationToJson(
          CalendarEventMutation(
            eventType: type,
            googleStatusProperties: properties,
          ),
        );
        expect(created['eventType'], type);
        expect(created[key], properties);
        final edited = googleEventMutationToJson(
          CalendarEventMutation(
            googleStatusEventTypeContext: type,
            googleStatusProperties: properties,
          ),
        );
        expect(edited[key], properties);
        expect(edited, isNot(contains('eventType')));
      }
      expect(
        () => googleEventMutationToJson(
          const CalendarEventMutation(googleStatusProperties: {}),
        ),
        throwsFormatException,
      );
    },
  );
}

import 'dart:convert';

import 'package:busymax/src/calendar_providers/calendar_mutation.dart';
import 'package:busymax/src/microsoft_calendar/microsoft_calendar_api_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test(
    'event create, update, and delete use Microsoft Graph endpoints',
    () async {
      final requests = <http.Request>[];
      final client = _client((request) {
        requests.add(request);
        if (request.method == 'DELETE') {
          return http.Response('', 204);
        }
        return _json(_eventJson(id: 'event-1', subject: 'Planning'));
      });

      await client.createEvent(
        calendarId: 'cal-1',
        mutation: const CalendarEventMutation(
          title: 'Planning',
          allDay: false,
          startDateTime: '2026-06-10T09:00:00',
          endDateTime: '2026-06-10T10:00:00',
          reminders: {'isReminderOn': true, 'reminderMinutesBeforeStart': 15},
        ),
      );
      await client.updateEvent(
        calendarId: 'cal-1',
        eventId: 'event-1',
        mutation: const CalendarEventMutation(title: 'Renamed'),
      );
      await client.deleteEvent(calendarId: 'cal-1', eventId: 'event-1');

      expect(requests[0].method, 'POST');
      expect(requests[0].url.path, '/v1.0/me/calendars/cal-1/events');
      expect(jsonDecode(requests[0].body), {
        'subject': 'Planning',
        'isAllDay': false,
        'start': {'dateTime': '2026-06-10T09:00:00', 'timeZone': 'UTC'},
        'end': {'dateTime': '2026-06-10T10:00:00', 'timeZone': 'UTC'},
        'isReminderOn': true,
        'reminderMinutesBeforeStart': 15,
      });
      expect(requests[1].method, 'PATCH');
      expect(requests[1].url.path, '/v1.0/me/calendars/cal-1/events/event-1');
      expect(jsonDecode(requests[1].body), {'subject': 'Renamed'});
      expect(requests[2].method, 'DELETE');
      expect(requests[2].url.path, '/v1.0/me/calendars/cal-1/events/event-1');
    },
  );

  test('event update does not send raw onlineMeeting as provider', () async {
    late http.Request captured;
    final client = _client((request) {
      captured = request;
      return _json(_eventJson(id: 'event-1', subject: 'Edited'));
    });

    await client.updateEvent(
      calendarId: 'cal-1',
      eventId: 'event-1',
      mutation: const CalendarEventMutation(
        title: 'Edited',
        conference: {'joinUrl': 'https://teams.example/join'},
      ),
    );

    final body = jsonDecode(captured.body) as Map<String, Object?>;
    expect(body, {'subject': 'Edited'});
    expect(body, isNot(contains('onlineMeetingProvider')));
  });
}

MicrosoftCalendarApiClient _client(
  http.Response Function(http.Request request) handler,
) {
  return MicrosoftCalendarApiClient(
    httpClient: MockClient((request) async => handler(request)),
    baseUri: Uri.parse('https://graph.microsoft.com/v1.0'),
    responseTimeZone: 'UTC',
    authorizationHeaderProvider: () async => 'Bearer token',
  );
}

http.Response _json(Map<String, Object?> body) {
  return http.Response(
    jsonEncode(body),
    200,
    headers: {'Content-Type': 'application/json'},
  );
}

Map<String, Object?> _eventJson({required String id, required String subject}) {
  return {
    'id': id,
    'subject': subject,
    'isAllDay': false,
    'start': {'dateTime': '2026-06-10T09:00:00', 'timeZone': 'UTC'},
    'end': {'dateTime': '2026-06-10T10:00:00', 'timeZone': 'UTC'},
    'lastModifiedDateTime': '2026-06-10T00:00:00Z',
  };
}

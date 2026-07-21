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

  test(
    'primary initial sync uses delta view and preserves calendar identity',
    () async {
      late http.Request captured;
      const deltaLink =
          'https://graph.microsoft.com/v1.0/me/calendarView/delta?'
          r'$deltatoken=terminal-token';
      final client = _client((request) {
        captured = request;
        return _json({
          'value': [_eventJson(id: 'event-1', subject: 'Planning')],
          '@odata.deltaLink': deltaLink,
        });
      });

      final page = await client.syncEvents(
        calendarId: 'actual-calendar-id',
        rangeStart: DateTime.utc(2026, 6, 10, 8),
        rangeEnd: DateTime.utc(2026, 6, 11, 8),
        primaryCalendar: true,
      );

      expect(captured.method, 'GET');
      expect(captured.url.path, '/v1.0/me/calendarView/delta');
      expect(captured.url.queryParameters, {
        'startDateTime': '2026-06-10T08:00:00.000Z',
        'endDateTime': '2026-06-11T08:00:00.000Z',
      });
      expect(page.events.single.providerCalendarId, 'actual-calendar-id');
      expect(page.nextSyncTokenOrDeltaLink, deltaLink);
    },
  );

  test('non-primary initial sync uses ordinary per-calendar view', () async {
    late http.Request captured;
    final client = _client((request) {
      captured = request;
      return _json({'value': <Object?>[]});
    });

    final page = await client.syncEvents(
      calendarId: 'cal-2',
      rangeStart: DateTime.utc(2026, 6, 10, 8),
      rangeEnd: DateTime.utc(2026, 6, 11, 8),
      primaryCalendar: false,
    );

    expect(captured.method, 'GET');
    expect(captured.url.path, '/v1.0/me/calendars/cal-2/calendarView');
    expect(captured.url.queryParameters, {
      'startDateTime': '2026-06-10T08:00:00.000Z',
      'endDateTime': '2026-06-11T08:00:00.000Z',
    });
    expect(page.nextSyncTokenOrDeltaLink, isNull);
  });

  test(
    'incremental sync follows the saved opaque delta link exactly',
    () async {
      const savedDeltaLink =
          'https://graph.microsoft.com/v1.0/me/calendarView/delta?'
          r'$deltatoken=opaque%2Btoken%2Fvalue';
      const nextDeltaLink =
          'https://graph.microsoft.com/v1.0/me/calendarView/delta?'
          r'$deltatoken=next-token';
      late http.Request captured;
      final client = _client((request) {
        captured = request;
        return _json({'value': <Object?>[], '@odata.deltaLink': nextDeltaLink});
      });

      final page = await client.syncEvents(
        calendarId: 'actual-calendar-id',
        rangeStart: DateTime.utc(2030),
        rangeEnd: DateTime.utc(2031),
        syncTokenOrDeltaLink: savedDeltaLink,
        primaryCalendar: true,
      );

      expect(captured.url.toString(), savedDeltaLink);
      expect(page.nextSyncTokenOrDeltaLink, nextDeltaLink);
    },
  );

  test('delta tombstones map to deleted events', () async {
    final client = _client(
      (_) => _json({
        'value': [
          {
            'id': 'event-1',
            '@removed': {'reason': 'deleted'},
          },
        ],
      }),
    );

    final page = await client.syncEvents(
      calendarId: 'actual-calendar-id',
      rangeStart: DateTime.utc(2026, 6, 10),
      rangeEnd: DateTime.utc(2026, 6, 11),
      syncTokenOrDeltaLink:
          'https://graph.microsoft.com/v1.0/me/calendarView/delta?'
          r'$deltatoken=current',
      primaryCalendar: true,
    );

    expect(page.events.single.providerCalendarId, 'actual-calendar-id');
    expect(page.events.single.isDeleted, isTrue);
  });

  test('expired Microsoft delta state requests a full sync', () async {
    const scenarios = [
      (statusCode: 410, code: 'ErrorInvalidSyncState'),
      (statusCode: 400, code: 'syncStateNotFound'),
    ];

    for (final scenario in scenarios) {
      final client = _client(
        (_) => http.Response(
          jsonEncode({
            'error': {
              'code': scenario.code,
              'message': 'The sync state is no longer valid.',
            },
          }),
          scenario.statusCode,
          headers: {'Content-Type': 'application/json'},
        ),
      );

      final page = await client.syncEvents(
        calendarId: 'actual-calendar-id',
        rangeStart: DateTime.utc(2026, 6, 10),
        rangeEnd: DateTime.utc(2026, 6, 11),
        syncTokenOrDeltaLink:
            'https://graph.microsoft.com/v1.0/me/calendarView/delta?'
            r'$deltatoken=expired',
        primaryCalendar: true,
      );

      expect(
        page.requiresFullSync,
        isTrue,
        reason: '${scenario.statusCode}/${scenario.code}',
      );
      expect(page.events, isEmpty);
    }
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

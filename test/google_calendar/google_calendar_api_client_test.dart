import 'dart:convert';

import 'package:busymax/src/calendar_providers/calendar_mutation.dart';
import 'package:busymax/src/db/app_database.dart';
import 'package:busymax/src/features/sync/calendar_sync_engine.dart';
import 'package:busymax/src/google_calendar/google_calendar_api_client.dart';
import 'package:busymax/src/schedule/schedule_range.dart';
import 'package:busymax/src/schedule/schedule_repository.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('calendar RGB color updates the Google CalendarList entry', () async {
    late http.Request captured;
    final client = _client((request) {
      captured = request;
      return _json({
        'id': 'calendar@example.com',
        'summary': 'Work',
        'backgroundColor': '#3584e4',
        'foregroundColor': '#ffffff',
        'accessRole': 'owner',
      });
    });

    final source = await client.updateCalendar(
      'calendar@example.com',
      const CalendarMutation(
        backgroundColor: '#3584e4',
        foregroundColor: '#ffffff',
      ),
    );

    expect(captured.method, 'PATCH');
    expect(
      captured.url.path,
      '/calendar/v3/users/me/calendarList/calendar%40example.com',
    );
    expect(captured.url.queryParameters, {'colorRgbFormat': 'true'});
    expect(jsonDecode(captured.body), {
      'backgroundColor': '#3584e4',
      'foregroundColor': '#ffffff',
    });
    expect(source.backgroundColor, '#3584e4');
  });

  test('calendar rename updates the calendar resource', () async {
    late http.Request captured;
    final client = _client((request) {
      captured = request;
      return _json({'id': 'calendar@example.com', 'summary': 'Renamed'});
    });

    await client.updateCalendar(
      'calendar@example.com',
      const CalendarMutation(summary: 'Renamed'),
    );

    expect(captured.method, 'PATCH');
    expect(captured.url.path, '/calendar/v3/calendars/calendar%40example.com');
    expect(captured.url.queryParameters, isEmpty);
    expect(jsonDecode(captured.body), {'summary': 'Renamed'});
  });

  test('event mutations always send an explicit guest update policy', () async {
    final requests = <http.Request>[];
    final client = _client((request) {
      requests.add(request);
      if (request.method == 'DELETE') return http.Response('', 204);
      return _json(_googleEventJson());
    });

    await client.createEvent(
      calendarId: 'calendar@example.com',
      mutation: const CalendarEventMutation(title: 'Planning'),
    );
    await client.updateEvent(
      calendarId: 'calendar@example.com',
      eventId: 'event-1',
      mutation: const CalendarEventMutation(title: 'Updated'),
      guestUpdatePolicy: CalendarGuestUpdatePolicy.doNotSend,
    );
    await client.deleteEvent(
      calendarId: 'calendar@example.com',
      eventId: 'event-1',
      guestUpdatePolicy: CalendarGuestUpdatePolicy.doNotSend,
    );

    expect(requests[0].url.queryParameters['sendUpdates'], 'all');
    expect(requests[1].url.queryParameters['sendUpdates'], 'none');
    expect(requests[2].url.queryParameters['sendUpdates'], 'none');
    expect(requests[0].url.queryParameters['conferenceDataVersion'], '1');
    expect(requests[1].url.queryParameters['conferenceDataVersion'], '1');
    expect(jsonDecode(requests[1].body), {'summary': 'Updated'});
  });

  test('native event move sends destination and guest update policy', () async {
    late http.Request captured;
    final client = _client((request) {
      captured = request;
      return _json(_googleEventJson());
    });

    await client.moveEvent(
      sourceCalendarId: 'source@example.com',
      eventId: 'event-1',
      destinationCalendarId: 'destination@example.com',
      guestUpdatePolicy: CalendarGuestUpdatePolicy.doNotSend,
    );

    expect(captured.method, 'POST');
    expect(
      captured.url.path,
      '/calendar/v3/calendars/source%40example.com/events/event-1/move',
    );
    expect(captured.url.queryParameters, {
      'destination': 'destination@example.com',
      'sendUpdates': 'none',
    });
  });

  test('Google RSVP updates only the signed-in attendee response', () async {
    late http.Request captured;
    final client = _client((request) {
      captured = request;
      return _json(_googleEventJson());
    });

    await client.respondToEvent(
      calendarId: 'calendar@example.com',
      eventId: 'event-1',
      response: CalendarInvitationResponse.tentative,
      attendeeEmail: 'me@example.com',
    );

    expect(captured.method, 'PATCH');
    expect(captured.url.queryParameters['sendUpdates'], 'all');
    expect(jsonDecode(captured.body), {
      'attendeesOmitted': true,
      'attendees': [
        {'email': 'me@example.com', 'responseStatus': 'tentative'},
      ],
    });
  });

  test(
    'initial and token syncs request expanded recurring instances',
    () async {
      final requests = <http.Request>[];
      final client = _client((request) {
        requests.add(request);
        return _json({
          'items': <Object?>[],
          'nextSyncToken': requests.length == 1
              ? 'next-sync-token-1'
              : 'next-sync-token-2',
        });
      });
      final rangeStart = DateTime.utc(2026, 7, 1);
      final rangeEnd = DateTime.utc(2026, 8, 1);

      await client.syncEvents(
        calendarId: 'calendar@example.com',
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
      );
      await client.syncEvents(
        calendarId: 'calendar@example.com',
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
        syncTokenOrDeltaLink: 'next-sync-token-1',
      );

      expect(requests, hasLength(2));
      expect(requests[0].url.queryParameters, {
        'timeMin': '2026-07-01T00:00:00.000Z',
        'timeMax': '2026-08-01T00:00:00.000Z',
        'singleEvents': 'true',
        'showDeleted': 'true',
        'maxResults': '2500',
      });
      expect(requests[1].url.queryParameters, {
        'singleEvents': 'true',
        'showDeleted': 'true',
        'maxResults': '2500',
        'syncToken': 'next-sync-token-1',
      });
    },
  );

  test(
    'recurring instances synchronized by Google populate the schedule',
    () async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      await database
          .into(database.accounts)
          .insert(
            AccountsCompanion.insert(
              id: 'account',
              provider: 'google',
              authority: 'https://accounts.google.com',
              providerAccountId: 'google-account',
              credentialKind: 'oauth',
              authState: const Value('signed_in'),
              grantedScopes: const Value(''),
              createdAtUtc: '2026-07-01T00:00:00.000Z',
              updatedAtUtc: '2026-07-01T00:00:00.000Z',
            ),
          );
      late http.Request eventsRequest;
      final client = _client((request) {
        if (request.url.path == '/calendar/v3/users/me/calendarList') {
          return _json({
            'items': [
              {
                'id': 'calendar@example.com',
                'summary': 'Work',
                'primary': true,
                'selected': true,
                'accessRole': 'owner',
                'timeZone': 'America/Vancouver',
              },
            ],
          });
        }
        eventsRequest = request;
        final expandsInstances =
            request.url.queryParameters['singleEvents'] == 'true';
        return _json({
          'items': expandsInstances
              ? [_instance('instance-1', 14), _instance('instance-2', 21)]
              : [_recurringMaster()],
          'nextSyncToken': 'sync-token-1',
        });
      });

      await CalendarSyncEngine(
        database: database,
        client: client,
        accountId: 'account',
        nowUtc: () => DateTime.utc(2026, 7, 10),
      ).incrementalSync();

      expect(eventsRequest.url.queryParameters['singleEvents'], 'true');
      final rows = await database.select(database.calendarEvents).get();
      expect(rows, hasLength(2));
      expect(
        rows.map((row) => row.providerRecurringEventId),
        everyElement('series-1'),
      );
      expect(rows.map((row) => row.providerOriginalStartKey).toSet(), {
        '2026-07-14T09:00:00-07:00',
        '2026-07-21T09:00:00-07:00',
      });

      final schedule = await ScheduleRepository(database).listItems(
        range: ScheduleRange(
          start: DateTime(2026, 7, 13),
          end: DateTime(2026, 7, 22),
        ),
      );
      expect(schedule.map((item) => item.title), [
        'Weekly planning',
        'Weekly planning',
      ]);
      expect(schedule.map((item) => item.start), [
        DateTime.parse('2026-07-14T09:00:00-07:00').toLocal(),
        DateTime.parse('2026-07-21T09:00:00-07:00').toLocal(),
      ]);
    },
  );
}

GoogleCalendarApiClient _client(
  http.Response Function(http.Request request) handler,
) {
  return GoogleCalendarApiClient(
    httpClient: MockClient((request) async => handler(request)),
    baseUri: Uri.parse('https://www.googleapis.com'),
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

Map<String, Object?> _instance(String id, int day) {
  final dayValue = day.toString().padLeft(2, '0');
  final start = '2026-07-${dayValue}T09:00:00-07:00';
  return {
    'id': id,
    'status': 'confirmed',
    'summary': 'Weekly planning',
    'recurringEventId': 'series-1',
    'originalStartTime': {'dateTime': start, 'timeZone': 'America/Vancouver'},
    'start': {'dateTime': start, 'timeZone': 'America/Vancouver'},
    'end': {
      'dateTime': '2026-07-${dayValue}T10:00:00-07:00',
      'timeZone': 'America/Vancouver',
    },
    'updated': '2026-07-10T00:00:00Z',
  };
}

Map<String, Object?> _recurringMaster() {
  return {
    'id': 'series-1',
    'status': 'confirmed',
    'summary': 'Weekly planning',
    'recurrence': ['RRULE:FREQ=WEEKLY'],
    'start': {
      'dateTime': '2026-07-14T09:00:00-07:00',
      'timeZone': 'America/Vancouver',
    },
    'end': {
      'dateTime': '2026-07-14T10:00:00-07:00',
      'timeZone': 'America/Vancouver',
    },
    'updated': '2026-07-10T00:00:00Z',
  };
}

Map<String, Object?> _googleEventJson() {
  return {
    'id': 'event-1',
    'summary': 'Planning',
    'status': 'confirmed',
    'start': {'dateTime': '2026-07-14T09:00:00Z'},
    'end': {'dateTime': '2026-07-14T10:00:00Z'},
  };
}

import 'dart:convert';

import 'package:busymax/src/calendar_providers/calendar_sync_dto.dart';
import 'package:busymax/src/features/schedule/presentation/cloud_calendar_series_export.dart';
import 'package:busymax/src/google_calendar/google_calendar_api_client.dart';
import 'package:busymax/src/google_calendar/google_calendar_mapper.dart';
import 'package:busymax/src/ical/ical_ingestion.dart';
import 'package:busymax/src/microsoft_calendar/microsoft_calendar_api_client.dart';
import 'package:busymax/src/providers/busy_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('series export is offered only with an authoritative series path', () {
    expect(
      canExportAuthoritativeEventSeries(
        provider: BusyProvider.google,
        providerEventId: 'master',
        davCollectionId: null,
      ),
      isTrue,
    );
    expect(
      canExportAuthoritativeEventSeries(
        provider: BusyProvider.microsoft,
        providerEventId: null,
        davCollectionId: null,
      ),
      isFalse,
    );
    expect(
      canExportAuthoritativeEventSeries(
        provider: BusyProvider.nextcloud,
        providerEventId: null,
        davCollectionId: 'collection',
      ),
      isTrue,
    );
    expect(
      canExportAuthoritativeEventSeries(
        provider: BusyProvider.webCal,
        providerEventId: 'cached-event',
        davCollectionId: null,
      ),
      isFalse,
    );
  });

  test(
    'Google series export waits for every page and retains moved/cancelled instances',
    () async {
      final requests = <http.Request>[];
      final client = GoogleCalendarApiClient(
        httpClient: MockClient((request) async {
          requests.add(request);
          if (request.url.path.endsWith('/events/master')) {
            return http.Response(jsonEncode(_googleMaster), 200);
          }
          if (request.url.queryParameters['pageToken'] == 'second') {
            return http.Response(
              jsonEncode({
                'items': [_googleMoved, _googleCancelled],
              }),
              200,
            );
          }
          return http.Response(
            jsonEncode({
              'items': [_googleMaster],
              'nextPageToken': 'second',
            }),
            200,
          );
        }),
        baseUri: Uri.parse('https://www.googleapis.com'),
      );
      final data = await exportGoogleEventSeries(
        client: client,
        calendarId: 'primary',
        eventId: 'master',
        nowUtc: DateTime.utc(2026, 8, 1),
      );
      expect(
        requests.where((r) => r.url.queryParameters['pageToken'] == 'second'),
        hasLength(1),
      );
      expect(
        requests.where((r) => r.url.queryParameters['showDeleted'] == 'true'),
        hasLength(2),
      );
      expect(data, contains('UID:series@example.test'));
      expect(data, contains('RRULE:FREQ=DAILY;COUNT=3'));
      expect(
        data,
        contains('RECURRENCE-ID;TZID=America/Los_Angeles:20260831T090000'),
      );
      expect(data, contains('SUMMARY:Moved'));
      expect(data, contains('STATUS:CANCELLED'));
      expect(data, contains('BEGIN:VALARM'));
      expect(data, contains('ATTENDEE;ROLE=OPT-PARTICIPANT;PARTSTAT=ACCEPTED'));
      expect(data, contains('ATTACH:https://files.example.test/agenda.pdf'));
      final parsed = IcalIngestion.parseString(
        data,
        policy: IcalIngestionPolicy.fileImport,
      );
      expect(parsed.recurrenceSets.single.semantic.components, hasLength(3));
    },
  );

  test('Google later-page failure does not return a partial series', () async {
    final client = GoogleCalendarApiClient(
      httpClient: MockClient((request) async {
        if (request.url.path.endsWith('/events/master')) {
          return http.Response(jsonEncode(_googleMaster), 200);
        }
        if (request.url.queryParameters['pageToken'] == 'second') {
          return http.Response('later page failed', 503);
        }
        return http.Response(
          jsonEncode({
            'items': [_googleMaster],
            'nextPageToken': 'second',
          }),
          200,
        );
      }),
      baseUri: Uri.parse('https://www.googleapis.com'),
    );
    await expectLater(
      exportGoogleEventSeries(
        client: client,
        calendarId: 'primary',
        eventId: 'master',
        nowUtc: DateTime.utc(2026, 8, 1),
      ),
      throwsA(isA<Object>()),
    );
  });

  test(
    'Microsoft series export reads full exceptions and cancellation identities',
    () async {
      final requests = <http.Request>[];
      final client = MicrosoftCalendarApiClient(
        httpClient: MockClient((request) async {
          requests.add(request);
          if (request.url.queryParameters.containsKey(r'$expand')) {
            return http.Response(
              jsonEncode({
                'exceptionOccurrences': [
                  {'id': 'moved', 'subject': 'Moved'},
                ],
                'cancelledOccurrences': ['OID.master.2026-09-01'],
              }),
              200,
            );
          }
          if (request.url.path.endsWith('/events/moved')) {
            return http.Response(
              jsonEncode({
                ..._microsoftMaster,
                'id': 'moved',
                'type': 'exception',
                'seriesMasterId': 'master',
                'originalStart': '2026-08-31T16:00:00Z',
                'subject': 'Moved',
                'start': {
                  'dateTime': '2026-08-31T11:00:00',
                  'timeZone': 'Pacific Standard Time',
                },
                'end': {
                  'dateTime': '2026-08-31T12:00:00',
                  'timeZone': 'Pacific Standard Time',
                },
                'recurrence': null,
              }),
              200,
            );
          }
          return http.Response(jsonEncode(_microsoftMaster), 200);
        }),
        baseUri: Uri.parse('https://graph.microsoft.com/v1.0'),
        responseTimeZone: 'UTC',
      );
      final data = await exportMicrosoftEventSeries(
        client: client,
        calendarId: 'calendar',
        eventId: 'master',
        nowUtc: DateTime.utc(2026, 8, 1),
      );
      expect(
        requests.where((r) => r.url.path.endsWith('/events/moved')),
        hasLength(1),
      );
      expect(data, contains('RRULE:FREQ=DAILY;INTERVAL=1;COUNT=3'));
      expect(data, contains('SUMMARY:Moved'));
      expect(data, contains('STATUS:CANCELLED'));
      expect(
        IcalIngestion.parseString(
          data,
          policy: IcalIngestionPolicy.fileImport,
        ).recurrenceSets.single.semantic.components,
        hasLength(3),
      );
    },
  );

  test('series export refuses opaque provider IDs as iCalendar UIDs', () {
    expect(
      () => cloudSeriesToICalendar(
        master: const CalendarEventDto(
          provider: BusyProvider.google,
          providerCalendarId: 'primary',
          providerEventId: 'opaque',
          title: 'Meeting',
          startDate: '2026-08-30',
          endDate: '2026-08-31',
          allDay: true,
        ),
        exceptions: const [],
        nowUtc: DateTime.utc(2026, 8, 1),
      ),
      throwsFormatException,
    );
  });

  test(
    'series export retains calendar-default popup alarms only with authoritative settings',
    () async {
      final master = {
        ..._googleMaster,
        'reminders': {'useDefault': true},
      };
      final client = GoogleCalendarApiClient(
        httpClient: MockClient((request) async {
          if (request.url.path.endsWith('/events/master')) {
            return http.Response(jsonEncode(master), 200);
          }
          if (request.url.path.endsWith('/users/me/calendarList')) {
            return http.Response(
              jsonEncode({
                'items': [
                  {
                    'id': 'primary',
                    'summary': 'Primary',
                    'defaultReminders': [
                      {'method': 'popup', 'minutes': 5},
                    ],
                  },
                ],
              }),
              200,
            );
          }
          return http.Response(
            jsonEncode({
              'items': [master],
            }),
            200,
          );
        }),
        baseUri: Uri.parse('https://www.googleapis.com'),
      );
      final exported = await exportGoogleEventSeries(
        client: client,
        calendarId: 'primary',
        eventId: 'master',
        nowUtc: DateTime.utc(2026, 8, 1),
      );
      expect(exported, contains('TRIGGER:-PT5M'));
      expect(
        () => cloudSeriesToICalendar(
          master: googleCalendarEventFromJson('primary', master),
          exceptions: const [],
          nowUtc: DateTime.utc(2026, 8, 1),
        ),
        throwsFormatException,
      );
    },
  );

  test('series export rejects a floating cloud time without an event zone', () {
    expect(
      () => cloudSeriesToICalendar(
        master: const CalendarEventDto(
          provider: BusyProvider.google,
          providerCalendarId: 'primary',
          providerEventId: 'master',
          title: 'Floating',
          startDateTime: '2026-08-30T09:00:00',
          endDateTime: '2026-08-30T10:00:00',
          rawJson: {'iCalUID': 'floating@example.test'},
        ),
        exceptions: const [],
        nowUtc: DateTime.utc(2026, 8, 1),
      ),
      throwsFormatException,
    );
  });
}

const _googleMaster = <String, Object?>{
  'id': 'master',
  'iCalUID': 'series@example.test',
  'summary': 'Master',
  'start': {
    'dateTime': '2026-08-30T09:00:00-07:00',
    'timeZone': 'America/Los_Angeles',
  },
  'end': {
    'dateTime': '2026-08-30T10:00:00-07:00',
    'timeZone': 'America/Los_Angeles',
  },
  'recurrence': ['RRULE:FREQ=DAILY;COUNT=3'],
  'reminders': {
    'useDefault': false,
    'overrides': [
      {'method': 'popup', 'minutes': 10},
    ],
  },
  'attendees': [
    {
      'email': 'guest@example.test',
      'optional': true,
      'responseStatus': 'accepted',
    },
  ],
  'attachments': [
    {'fileUrl': 'https://files.example.test/agenda.pdf'},
  ],
};

const _googleMoved = <String, Object?>{
  'id': 'moved',
  'iCalUID': 'series@example.test',
  'recurringEventId': 'master',
  'originalStartTime': {'dateTime': '2026-08-31T09:00:00-07:00'},
  'summary': 'Moved',
  'start': {
    'dateTime': '2026-08-31T11:00:00-07:00',
    'timeZone': 'America/Los_Angeles',
  },
  'end': {
    'dateTime': '2026-08-31T12:00:00-07:00',
    'timeZone': 'America/Los_Angeles',
  },
};

const _googleCancelled = <String, Object?>{
  'id': 'cancelled',
  'iCalUID': 'series@example.test',
  'recurringEventId': 'master',
  'originalStartTime': {'dateTime': '2026-09-01T09:00:00-07:00'},
  'status': 'cancelled',
};

const _microsoftMaster = <String, Object?>{
  'id': 'master',
  'uid': 'series@example.test',
  'subject': 'Master',
  'type': 'seriesMaster',
  'start': {
    'dateTime': '2026-08-30T09:00:00',
    'timeZone': 'Pacific Standard Time',
  },
  'end': {
    'dateTime': '2026-08-30T10:00:00',
    'timeZone': 'Pacific Standard Time',
  },
  'recurrence': {
    'pattern': {'type': 'daily', 'interval': 1},
    'range': {
      'type': 'numbered',
      'startDate': '2026-08-30',
      'numberOfOccurrences': 3,
    },
  },
};

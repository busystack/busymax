import 'dart:convert';

import 'package:busymax/src/calendar_providers/calendar_sync_dto.dart';
import 'package:busymax/src/dav/ical/ical_semantics.dart';
import 'package:busymax/src/dav/ical/ical_timezone.dart';
import 'package:busymax/src/features/schedule/presentation/cloud_calendar_series_export.dart';
import 'package:busymax/src/google_calendar/google_calendar_api_client.dart';
import 'package:busymax/src/google_calendar/google_calendar_mapper.dart';
import 'package:busymax/src/ical/ical_ingestion.dart';
import 'package:busymax/src/microsoft_calendar/microsoft_calendar_api_client.dart';
import 'package:busymax/src/microsoft_calendar/microsoft_calendar_mapper.dart';
import 'package:busymax/src/providers/busy_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:timezone/data/latest_all.dart' as time_zone_data;
import 'package:timezone/timezone.dart' as tz;

void main() {
  // Resolve through the exported VTIMEZONE, not timezone's IANA fallback.
  DateTime exportedInstant(String data, String zone, DateTime wall) {
    final semantic = IcalIngestion.parseString(
      data,
      policy: IcalIngestionPolicy.fileImport,
    ).recurrenceSets.single.semantic;
    expect(
      semantic.timeZones.any(
        (component) => component.firstProperty('TZID')?.rawValue == zone,
      ),
      isTrue,
    );
    return IcalTimeZoneResolver.fromDocument(semantic).toUtc(
      IcalTemporalValue(
        rawValue: '',
        kind: IcalTemporalKind.tzidDateTime,
        localValue: wall,
        timeZoneId: zone,
      ),
    );
  }

  CalendarEventDto zonedMicrosoftSeries({
    required String zone,
    required String startUtc,
    required Map<String, Object?> range,
  }) => microsoftCalendarEventFromJson('calendar', {
    ..._microsoftMaster,
    'start': {'dateTime': startUtc, 'timeZone': 'UTC'},
    'end': {
      'dateTime': DateTime.parse(
        startUtc,
      ).add(const Duration(hours: 1)).toIso8601String(),
      'timeZone': 'UTC',
    },
    'recurrence': {
      'pattern': {'type': 'daily', 'interval': 1},
      'range': {...range, 'recurrenceTimeZone': zone},
    },
  });

  test('IANA 2025c Apia ending DST never invents later daylight', () {
    final data = cloudSeriesToICalendar(
      master: zonedMicrosoftSeries(
        zone: 'Pacific/Apia',
        startUtc: '2018-12-31T20:00:00',
        range: {'type': 'noEnd', 'startDate': '2019-01-01'},
      ),
      exceptions: const [],
      nowUtc: DateTime.utc(2026),
    );
    expect(data, contains('TZID:Pacific/Apia'));
    expect(data, contains('TZOFFSETTO:+1400'));
    expect(
      exportedInstant(data, 'Pacific/Apia', DateTime.utc(2022, 1, 15, 9)),
      DateTime.utc(2022, 1, 14, 20),
    );
    expect(
      exportedInstant(data, 'Pacific/Apia', DateTime.utc(2040, 1, 15, 9)),
      DateTime.utc(2040, 1, 14, 20),
    );
  });

  test('IANA 2025c finite Los Angeles COUNT and UNTIL reach 2038', () {
    time_zone_data.initializeTimeZones();
    expect(
      DateTime.fromMillisecondsSinceEpoch(
        tz.getLocation('America/Los_Angeles').transitionAt.last,
        isUtc: true,
      ).year,
      2037,
    );
    for (final range in [
      {
        'type': 'numbered',
        'startDate': '2030-01-01',
        'numberOfOccurrences': 3300,
      },
      {'type': 'endDate', 'startDate': '2030-01-01', 'endDate': '2038-12-31'},
    ]) {
      final data = cloudSeriesToICalendar(
        master: zonedMicrosoftSeries(
          zone: 'America/Los_Angeles',
          startUtc: '2030-01-01T17:00:00',
          range: range,
        ),
        exceptions: const [],
        nowUtc: DateTime.utc(2026),
      );
      expect(
        exportedInstant(
          data,
          'America/Los_Angeles',
          DateTime.utc(2038, 1, 15, 9),
        ),
        DateTime.utc(2038, 1, 15, 17),
      );
      expect(
        exportedInstant(
          data,
          'America/Los_Angeles',
          DateTime.utc(2038, 7, 15, 9),
        ),
        DateTime.utc(2038, 7, 15, 16),
      );
      final futureObservance = RegExp(
        r'DTSTART:2038[^\r\n]*\r\nTZOFFSETFROM:-0800\r\nTZOFFSETTO:-0700',
      ).firstMatch(data)!;
      final corrupted = data.replaceRange(
        futureObservance.start,
        futureObservance.end,
        futureObservance
            .group(0)!
            .replaceFirst('TZOFFSETTO:-0700', 'TZOFFSETTO:-0600'),
      );
      expect(corrupted, isNot(data));
      expect(
        exportedInstant(
          corrupted,
          'America/Los_Angeles',
          DateTime.utc(2038, 7, 15, 9),
        ),
        isNot(DateTime.utc(2038, 7, 15, 16)),
      );
    }
  });

  test('IANA 2025c open-ended DST and fixed offsets remain distinct', () {
    final losAngeles = cloudSeriesToICalendar(
      master: zonedMicrosoftSeries(
        zone: 'America/Los_Angeles',
        startUtc: '2030-01-01T17:00:00',
        range: {'type': 'noEnd', 'startDate': '2030-01-01'},
      ),
      exceptions: const [],
      nowUtc: DateTime.utc(2026),
    );
    expect(
      exportedInstant(
        losAngeles,
        'America/Los_Angeles',
        DateTime.utc(2040, 1, 15, 9),
      ),
      DateTime.utc(2040, 1, 15, 17),
    );
    expect(
      exportedInstant(
        losAngeles,
        'America/Los_Angeles',
        DateTime.utc(2040, 7, 15, 9),
      ),
      DateTime.utc(2040, 7, 15, 16),
    );
    final kolkata = cloudSeriesToICalendar(
      master: zonedMicrosoftSeries(
        zone: 'Asia/Kolkata',
        startUtc: '2030-01-01T03:30:00',
        range: {'type': 'noEnd', 'startDate': '2030-01-01'},
      ),
      exceptions: const [],
      nowUtc: DateTime.utc(2026),
    );
    expect(kolkata, isNot(contains('BEGIN:DAYLIGHT')));
    expect(
      exportedInstant(kolkata, 'Asia/Kolkata', DateTime.utc(2040, 7, 15, 9)),
      DateTime.utc(2040, 7, 15, 3, 30),
    );
  });

  test(
    'a series starting after the 2037 table keeps its authoritative wall time and UNTIL',
    () {
      final data = cloudSeriesToICalendar(
        master: zonedMicrosoftSeries(
          zone: 'America/Los_Angeles',
          startUtc: '2038-07-01T16:00:00',
          range: {
            'type': 'endDate',
            'startDate': '2038-07-01',
            'endDate': '2038-07-31',
          },
        ),
        exceptions: const [],
        nowUtc: DateTime.utc(2026),
      );
      expect(
        data,
        contains('DTSTART;TZID=America/Los_Angeles:20380701T090000'),
      );
      expect(data, contains('UNTIL=20380731T160000Z'));
      expect(
        exportedInstant(
          data,
          'America/Los_Angeles',
          DateTime.utc(2038, 7, 31, 9),
        ),
        DateTime.utc(2038, 7, 31, 16),
      );
    },
  );

  test('IANA 2025c all-year DST continuation stays constant', () {
    for (final zone in ['Africa/Casablanca', 'Africa/El_Aaiun']) {
      final openEnded = cloudSeriesToICalendar(
        master: zonedMicrosoftSeries(
          zone: zone,
          startUtc: '2026-01-01T08:00:00',
          range: {'type': 'noEnd', 'startDate': '2026-01-01'},
        ),
        exceptions: const [],
        nowUtc: DateTime.utc(2026),
      );
      // Historical Ramadan suspension remains represented before the TZif
      // continuation boundary.
      expect(
        exportedInstant(openEnded, zone, DateTime.utc(2026, 3, 1, 9)),
        DateTime.utc(2026, 3, 1, 9),
      );
      expect(
        exportedInstant(openEnded, zone, DateTime.utc(2026, 6, 1, 9)),
        DateTime.utc(2026, 6, 1, 8),
      );
      for (final wall in [
        DateTime.utc(2088, 1, 1, 9),
        DateTime.utc(2088, 6, 1, 9),
        DateTime.utc(2088, 12, 31, 9),
        DateTime.utc(2089, 1, 1, 9),
        DateTime.utc(2089, 6, 1, 9),
      ]) {
        expect(
          exportedInstant(openEnded, zone, wall),
          wall.subtract(const Duration(hours: 1)),
          reason: '$zone $wall must retain all-year daylight offset',
        );
      }
      expect(
        RegExp(
          r'DTSTART:208[89][^\r\n]*\r\nTZOFFSETFROM:\+0000\r\nTZOFFSETTO:\+0100|'
          r'DTSTART:208[89][^\r\n]*\r\nTZOFFSETFROM:\+0100\r\nTZOFFSETTO:\+0000',
        ).allMatches(openEnded),
        isEmpty,
      );

      final finite = cloudSeriesToICalendar(
        master: zonedMicrosoftSeries(
          zone: zone,
          startUtc: '2088-06-01T08:00:00',
          range: {
            'type': 'endDate',
            'startDate': '2088-06-01',
            'endDate': '2088-12-31',
          },
        ),
        exceptions: const [],
        nowUtc: DateTime.utc(2026),
      );
      expect(finite, contains('DTSTART;TZID=$zone:20880601T090000'));
      expect(finite, contains('UNTIL=20881231T080000Z'));
      expect(
        exportedInstant(finite, zone, DateTime.utc(2088, 6, 1, 9)),
        DateTime.utc(2088, 6, 1, 8),
      );
    }
  });
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
      expect(
        requests.where((r) => r.url.path.endsWith('/calendarList')),
        isEmpty,
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
                'start': {'dateTime': '2026-08-31T18:00:00', 'timeZone': 'UTC'},
                'end': {'dateTime': '2026-08-31T19:00:00', 'timeZone': 'UTC'},
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
      expect(
        data,
        contains('DTSTART;TZID=America/Los_Angeles:20260830T090000'),
      );
      expect(
        data,
        contains('RECURRENCE-ID;TZID=America/Los_Angeles:20260831T090000'),
      );
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

  test(
    'Microsoft series uses recurrence zone and emits a valid timed UNTIL',
    () {
      final master = microsoftCalendarEventFromJson('calendar', {
        ..._microsoftMaster,
        'start': {'dateTime': '2026-08-30T16:00:00', 'timeZone': 'UTC'},
        'end': {'dateTime': '2026-08-30T17:00:00', 'timeZone': 'UTC'},
        'recurrence': {
          'pattern': {'type': 'daily', 'interval': 1},
          'range': {
            'type': 'endDate',
            'startDate': '2026-08-30',
            'endDate': '2026-09-01',
            'recurrenceTimeZone': 'Pacific Standard Time',
          },
        },
      });
      final data = cloudSeriesToICalendar(
        master: master,
        exceptions: const [],
        nowUtc: DateTime.utc(2026, 8, 1),
      );
      expect(
        data,
        contains('DTSTART;TZID=America/Los_Angeles:20260830T090000'),
      );
      expect(data, contains('BEGIN:VTIMEZONE'));
      expect(data, contains('TZID:America/Los_Angeles'));
      expect(data, contains('UNTIL=20260901T160000Z'));
      expect(data, isNot(contains('UNTIL=20260901;')));
      time_zone_data.initializeTimeZones();
      final location = tz.getLocation('America/Los_Angeles');
      final until = DateTime.utc(2026, 9, 1, 16);
      final occurrences = [
        for (var day = 30; day <= 33; day++)
          tz.TZDateTime(location, 2026, 8, day, 9).toUtc(),
      ];
      expect(
        occurrences.take(3).every((instant) => !instant.isAfter(until)),
        isTrue,
      );
      expect(occurrences.last.isAfter(until), isTrue);
      final references = RegExp(
        r';TZID=([^:]+):',
      ).allMatches(data).map((match) => match.group(1)!).toSet();
      final definitions = RegExp(
        r'^TZID:([^\r\n]+)',
        multiLine: true,
      ).allMatches(data).map((match) => match.group(1)!).toSet();
      expect(definitions, containsAll(references));
    },
  );

  test(
    'Microsoft no-end series keeps wall time across DST in response UTC',
    () {
      final master = microsoftCalendarEventFromJson('calendar', {
        ..._microsoftMaster,
        'start': {'dateTime': '2026-10-31T16:00:00', 'timeZone': 'UTC'},
        'end': {'dateTime': '2026-10-31T17:00:00', 'timeZone': 'UTC'},
        'recurrence': {
          'pattern': {'type': 'daily', 'interval': 1},
          'range': {
            'type': 'noEnd',
            'startDate': '2026-10-31',
            'recurrenceTimeZone': 'Pacific Standard Time',
          },
        },
      });
      final data = cloudSeriesToICalendar(
        master: master,
        exceptions: const [],
        nowUtc: DateTime.utc(2026, 10, 1),
      );
      expect(
        data,
        contains('DTSTART;TZID=America/Los_Angeles:20261031T090000'),
      );
      expect(data, contains('RRULE:FREQ=DAILY;INTERVAL=1'));
      expect(data, isNot(contains('UNTIL=')));
      expect(data, contains('BEGIN:DAYLIGHT'));
      expect(data, contains('BEGIN:STANDARD'));
      expect(data, contains('TZOFFSETTO:-0700'));
      expect(data, contains('TZOFFSETTO:-0800'));
      time_zone_data.initializeTimeZones();
      final location = tz.getLocation('America/Los_Angeles');
      final match = RegExp(
        r'DTSTART;TZID=America/Los_Angeles:(\d{8})T(\d{6})',
      ).firstMatch(data)!;
      final date = match.group(1)!;
      final time = match.group(2)!;
      final year = int.parse(date.substring(0, 4));
      final month = int.parse(date.substring(4, 6));
      final day = int.parse(date.substring(6, 8));
      final hour = int.parse(time.substring(0, 2));
      expect(
        [
          for (var offset = 0; offset < 3; offset++)
            tz.TZDateTime(location, year, month, day + offset, hour).toUtc(),
        ],
        [
          DateTime.utc(2026, 10, 31, 16),
          DateTime.utc(2026, 11, 1, 17),
          DateTime.utc(2026, 11, 2, 17),
        ],
      );
      expect(
        RegExp(
          r'BEGIN:(?:STANDARD|DAYLIGHT)[\s\S]*?RRULE:FREQ=YEARLY',
        ).hasMatch(data),
        isTrue,
      );
    },
  );

  test('Microsoft all-day end-date series retains DATE UNTIL', () {
    final master = microsoftCalendarEventFromJson('calendar', {
      ..._microsoftMaster,
      'isAllDay': true,
      'start': {
        'dateTime': '2026-08-30T00:00:00',
        'timeZone': 'Pacific Standard Time',
      },
      'end': {
        'dateTime': '2026-08-31T00:00:00',
        'timeZone': 'Pacific Standard Time',
      },
      'recurrence': {
        'pattern': {'type': 'daily', 'interval': 1},
        'range': {
          'type': 'endDate',
          'startDate': '2026-08-30',
          'endDate': '2026-09-01',
          'recurrenceTimeZone': 'Pacific Standard Time',
        },
      },
    });
    final data = cloudSeriesToICalendar(
      master: master,
      exceptions: const [],
      nowUtc: DateTime.utc(2026, 8, 1),
    );
    expect(data, contains('DTSTART;VALUE=DATE:20260830'));
    expect(data, contains('RRULE:FREQ=DAILY;INTERVAL=1;UNTIL=20260901'));
  });

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

  test(
    'E Google exception defaults are fetched when master is explicit',
    () async {
      var defaultsReads = 0;
      final moved = {
        ..._googleMoved,
        'reminders': {'useDefault': true},
      };
      final client = GoogleCalendarApiClient(
        httpClient: MockClient((request) async {
          if (request.url.path.endsWith('/events/master')) {
            return http.Response(jsonEncode(_googleMaster), 200);
          }
          if (request.url.path.endsWith('/users/me/calendarList')) {
            defaultsReads++;
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
              'items': [_googleMaster, moved],
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
      expect(defaultsReads, 1);
      expect(RegExp(r'TRIGGER:-PT10M').allMatches(exported), hasLength(1));
      expect(RegExp(r'TRIGGER:-PT5M').allMatches(exported), hasLength(1));
    },
  );

  test('E missing required exception defaults fail explicitly', () async {
    final moved = {
      ..._googleMoved,
      'reminders': {'useDefault': true},
    };
    final client = GoogleCalendarApiClient(
      httpClient: MockClient((request) async {
        if (request.url.path.endsWith('/events/master')) {
          return http.Response(jsonEncode(_googleMaster), 200);
        }
        if (request.url.path.endsWith('/users/me/calendarList')) {
          return http.Response(
            jsonEncode({
              'items': [
                {'id': 'primary', 'summary': 'Primary'},
              ],
            }),
            200,
          );
        }
        return http.Response(
          jsonEncode({
            'items': [_googleMaster, moved],
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
      throwsA(isA<FormatException>()),
    );
  });

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
  'start': {'dateTime': '2026-08-30T16:00:00', 'timeZone': 'UTC'},
  'end': {'dateTime': '2026-08-30T17:00:00', 'timeZone': 'UTC'},
  'recurrence': {
    'pattern': {'type': 'daily', 'interval': 1},
    'range': {
      'type': 'numbered',
      'startDate': '2026-08-30',
      'numberOfOccurrences': 3,
      'recurrenceTimeZone': 'Pacific Standard Time',
    },
  },
};

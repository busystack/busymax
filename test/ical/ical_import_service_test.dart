import 'dart:convert';

import 'package:busymax/src/calendar_providers/calendar_mutation.dart';
import 'package:busymax/src/db/app_database.dart';
import 'package:busymax/src/features/calendar/data/calendar_repository.dart';
import 'package:busymax/src/features/sync/calendar_pending_ops_replayer.dart';
import 'package:busymax/src/google_calendar/google_calendar_api_client.dart';
import 'package:busymax/src/microsoft_calendar/microsoft_calendar_api_client.dart';
import 'package:busymax/src/ical/ical_import_service.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  late AppDatabase database;
  late CalendarRepository calendarRepository;
  late IcalImportService importService;
  late int notificationRebuilds;

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    notificationRebuilds = 0;
    calendarRepository = CalendarRepository(
      database: database,
      now: () => DateTime.utc(2026, 8, 29),
      onNotificationScheduleChanged: () async => notificationRebuilds += 1,
    );
    importService = IcalImportService(
      database: database,
      calendarRepository: calendarRepository,
    );
    await _seedAccountAndSource(database);
  });

  tearDown(() async => database.close());

  test(
    'preview performs no mutation and reports omitted scheduling fields',
    () {
      final preview = importService.parsePreview(
        utf8.encode(
          _calendar('''
METHOD:REQUEST
BEGIN:VEVENT
UID:invitation-copy
DTSTART:20260830T160000Z
DTEND:20260830T170000Z
SUMMARY:Meeting copy
ORGANIZER:mailto:organizer@example.test
ATTENDEE:mailto:guest@example.test
URL:https://meeting.example.test/join
ATTACH:https://files.example.test/agenda
END:VEVENT
'''),
        ),
      );

      expect(preview.eventCount, 1);
      expect(
        preview.fieldsThatWillBeOmitted,
        containsAll([
          'scheduling method',
          'attendees',
          'organizer',
          'URL',
          'attachments',
        ]),
      );
      expect(notificationRebuilds, 0);
    },
  );

  test(
    'queues a private offline copy once and records durable UID receipt',
    () async {
      final preview = importService.parsePreview(
        utf8.encode(
          _calendar('''
METHOD:REQUEST
BEGIN:VEVENT
UID:recurring-import
DTSTART:20260830T160000Z
DTEND:20260830T170000Z
SUMMARY:Imported series
DESCRIPTION:Description
LOCATION:Room 2
GEO:0;-123.12
RRULE:FREQ=WEEKLY;INTERVAL=2;COUNT=4;BYDAY=SU
CATEGORIES:One,Two
CLASS:PRIVATE
TRANSP:TRANSPARENT
ORGANIZER:mailto:organizer@example.test
ATTENDEE;ROLE=REQ-PARTICIPANT:mailto:guest@example.test
BEGIN:VALARM
ACTION:DISPLAY
TRIGGER:-PT10M
DESCRIPTION:Reminder
END:VALARM
END:VEVENT
'''),
        ),
      );
      final destination = (await importService.writableDestinations()).single;

      final report = await importService.importPreview(
        preview: preview,
        destination: destination,
      );

      expect(report.queued, 1);
      expect(report.duplicatesSkipped, 0);
      expect(report.unsupportedRecurrenceSets, isEmpty);
      expect(notificationRebuilds, 1);
      final event = await database.select(database.calendarEvents).getSingle();
      expect(event.title, 'Imported series');
      expect(event.location, 'Room 2');
      // Google has no native coordinate extension; the imported point remains
      // associated locally below instead of being invented in its payload.
      expect(event.locationLatitude, isNull);
      expect(event.locationLongitude, isNull);
      expect(event.attendeesJson, isNull);
      expect(event.organizerJson, '{"self":true}');
      expect(event.organizerJson, isNot(contains('organizer@example.test')));
      expect(event.conferenceJson, isNull);
      expect(event.syncStatus, 'pending');
      expect(event.recurrenceJson, isNotNull);
      final operation = await database.select(database.pendingOps).getSingle();
      final request = jsonDecode(operation.requestJson) as Map<String, Object?>;
      expect(request[calendarEventGuestUpdatePolicyKey], 'doNotSend');
      expect(request[calendarEventImportIcalUidKey], 'recurring-import');
      expect(request['attendeesJson'], isNull);
      expect(request, isNot(contains('organizer')));
      expect(request, isNot(contains('conferenceJson')));
      expect(
        (await database.select(database.icalImportReceipts).getSingle())
            .icalUid,
        'recurring-import',
      );
      final remembered = await database
          .select(database.locationResolutions)
          .getSingle();
      expect(remembered.latitude, 0);
      expect(remembered.longitude, -123.12);
      expect(remembered.source, 'ical');

      final repeated = await importService.importPreview(
        preview: preview,
        destination: destination,
      );
      expect(repeated.queued, 0);
      expect(repeated.duplicatesSkipped, 1);
      expect(
        await database.select(database.calendarEvents).get(),
        hasLength(1),
      );
      expect(await database.select(database.pendingOps).get(), hasLength(1));
      expect(notificationRebuilds, 1);
    },
  );

  test(
    'Google import replays through private-copy endpoint with iCalUID',
    () async {
      final preview = importService.parsePreview(
        utf8.encode(
          _calendar('''
BEGIN:VEVENT
UID:private-copy@example.test
DTSTART:20260830T160000Z
DTEND:20260830T170000Z
SUMMARY:Imported
ATTENDEE:mailto:guest@example.test
END:VEVENT
'''),
        ),
      );
      await importService.importPreview(
        preview: preview,
        destination: (await importService.writableDestinations()).single,
      );
      final requests = <http.Request>[];
      final client = GoogleCalendarApiClient(
        httpClient: MockClient((request) async {
          requests.add(request);
          if (request.method == 'GET') {
            return http.Response(jsonEncode({'items': <Object>[]}), 200);
          }
          return http.Response(
            jsonEncode({
              'id': 'provider-event-id',
              'iCalUID': 'private-copy@example.test',
              'summary': 'Imported',
              'start': {'dateTime': '2026-08-30T16:00:00Z'},
              'end': {'dateTime': '2026-08-30T17:00:00Z'},
            }),
            200,
          );
        }),
        baseUri: Uri.parse('https://www.googleapis.com'),
      );
      await CalendarPendingOpsReplayer(
        database: database,
        client: client,
        accountId: 'google-account',
        nowUtc: () => DateTime.utc(2026, 8, 29),
      ).replayDueOps();
      expect(requests.map((request) => request.method), ['GET', 'POST']);
      expect(
        requests.last.url.path,
        '/calendar/v3/calendars/primary/events/import',
      );
      expect(requests.last.url.queryParameters, {
        'supportsAttachments': 'true',
      });
      final body = jsonDecode(requests.last.body) as Map<String, Object?>;
      expect(body['iCalUID'], 'private-copy@example.test');
      expect(body, isNot(contains('id')));
      expect(body, isNot(contains('attendees')));
      expect(await database.select(database.pendingOps).get(), isEmpty);
      expect(
        (await database.select(database.calendarEvents).getSingle())
            .providerEventId,
        'provider-event-id',
      );
    },
  );

  test(
    'replays a moved recurrence exception without sending invitations',
    () async {
      final preview = importService.parsePreview(
        utf8.encode(
          _calendar('''
BEGIN:VEVENT
UID:with-exception
DTSTART:20260830T160000Z
DTEND:20260830T170000Z
SUMMARY:Master
RRULE:FREQ=DAILY;COUNT=2
END:VEVENT
BEGIN:VEVENT
UID:with-exception
RECURRENCE-ID:20260831T160000Z
DTSTART:20260831T180000Z
DTEND:20260831T190000Z
SUMMARY:Moved
END:VEVENT
'''),
        ),
      );

      final report = await importService.importPreview(
        preview: preview,
        destination: (await importService.writableDestinations()).single,
      );

      expect(report.queued, 1);
      expect(report.unsupportedRecurrenceSets, isEmpty);
      expect(await database.select(database.pendingOps).get(), hasLength(2));
      final requests = <http.Request>[];
      final client = GoogleCalendarApiClient(
        httpClient: MockClient((request) async {
          requests.add(request);
          if (request.method == 'GET' &&
              request.url.path.endsWith('/instances')) {
            return http.Response(
              jsonEncode({
                'items': [
                  {
                    'id': 'occurrence-1',
                    'recurringEventId': 'master-1',
                    'originalStartTime': {'dateTime': '2026-08-31T16:00:00Z'},
                    'start': {'dateTime': '2026-08-31T16:00:00Z'},
                    'end': {'dateTime': '2026-08-31T17:00:00Z'},
                  },
                ],
              }),
              200,
            );
          }
          if (request.method == 'GET') {
            return http.Response(jsonEncode({'items': <Object>[]}), 200);
          }
          return http.Response(
            jsonEncode({
              'id': request.method == 'POST' ? 'master-1' : 'occurrence-1',
              'recurringEventId': request.method == 'POST' ? null : 'master-1',
              'originalStartTime': request.method == 'POST'
                  ? null
                  : {'dateTime': '2026-08-31T16:00:00Z'},
              'summary': request.method == 'POST' ? 'Master' : 'Moved',
              'start': {
                'dateTime': request.method == 'POST'
                    ? '2026-08-30T16:00:00Z'
                    : '2026-08-31T18:00:00Z',
              },
              'end': {
                'dateTime': request.method == 'POST'
                    ? '2026-08-30T17:00:00Z'
                    : '2026-08-31T19:00:00Z',
              },
            }),
            200,
          );
        }),
        baseUri: Uri.parse('https://www.googleapis.com'),
      );
      final replayer = CalendarPendingOpsReplayer(
        database: database,
        client: client,
        accountId: 'google-account',
        nowUtc: () => DateTime.utc(2026, 8, 29),
      );
      await replayer.replayDueOps();
      await replayer.replayDueOps();
      expect(await database.select(database.pendingOps).get(), isEmpty);
      final patch = requests.singleWhere((r) => r.method == 'PATCH');
      expect(
        patch.url.path,
        '/calendar/v3/calendars/primary/events/occurrence-1',
      );
      expect(patch.url.queryParameters['sendUpdates'], 'none');
      expect((jsonDecode(patch.body) as Map)['summary'], 'Moved');
    },
  );

  test('Microsoft import replays a moved instance through Graph', () async {
    await database
        .into(database.accounts)
        .insert(
          AccountsCompanion.insert(
            id: 'microsoft-account',
            provider: 'microsoft',
            authority: 'https://login.microsoftonline.com',
            providerAccountId: 'user',
            credentialKind: 'oauth',
            authState: const Value('signed_in'),
            calendarsEnabled: const Value(true),
            tasksEnabled: const Value(false),
            grantedScopes: const Value('Calendars.ReadWrite'),
            createdAtUtc: _now,
            updatedAtUtc: _now,
          ),
        );
    await database
        .into(database.calendarSources)
        .insert(
          CalendarSourcesCompanion.insert(
            id: 'microsoft-account|microsoft|calendar',
            accountId: 'microsoft-account',
            provider: 'microsoft',
            providerCalendarId: 'calendar',
            summary: 'Calendar',
            accessRole: const Value('owner'),
            createdAtLocal: 1,
            updatedAtLocal: 1,
          ),
        );
    final preview = importService.parsePreview(
      utf8.encode(
        _calendar('''
BEGIN:VEVENT
UID:microsoft-series
DTSTART:20260830T160000Z
DTEND:20260830T170000Z
SUMMARY:Master
RRULE:FREQ=DAILY;COUNT=2
END:VEVENT
BEGIN:VEVENT
UID:microsoft-series
RECURRENCE-ID:20260831T160000Z
DTSTART:20260831T180000Z
DTEND:20260831T190000Z
SUMMARY:Moved
END:VEVENT
'''),
      ),
    );
    final destination = (await importService.writableDestinations())
        .singleWhere((source) => source.accountId == 'microsoft-account');
    final report = await importService.importPreview(
      preview: preview,
      destination: destination,
    );
    expect(report.queued, 1);
    final requests = <http.Request>[];
    Map<String, Object?> graphEvent(String id, String title, String start) => {
      'id': id,
      'subject': title,
      'start': {'dateTime': start, 'timeZone': 'UTC'},
      'end': {'dateTime': '2026-08-31T19:00:00', 'timeZone': 'UTC'},
    };
    final client = MicrosoftCalendarApiClient(
      httpClient: MockClient((request) async {
        requests.add(request);
        if (request.method == 'POST') {
          return http.Response(
            jsonEncode(
              graphEvent('master-ms', 'Master', '2026-08-30T16:00:00'),
            ),
            201,
          );
        }
        if (request.url.path.endsWith('/instances')) {
          return http.Response(
            jsonEncode({
              'value': [
                {
                  ...graphEvent(
                    'occurrence-ms',
                    'Master',
                    '2026-08-31T16:00:00',
                  ),
                  'seriesMasterId': 'master-ms',
                  'originalStart': '2026-08-31T16:00:00Z',
                  'occurrenceId': 'oid-ms',
                },
              ],
            }),
            200,
          );
        }
        if (request.url.queryParameters.containsKey(r'$expand')) {
          return http.Response(
            jsonEncode({
              ...graphEvent('master-ms', 'Master', '2026-08-30T16:00:00'),
              'exceptionOccurrences': <Object>[],
              'cancelledOccurrences': <Object>[],
            }),
            200,
          );
        }
        return http.Response(
          jsonEncode({
            ...graphEvent('occurrence-ms', 'Moved', '2026-08-31T18:00:00'),
            'seriesMasterId': 'master-ms',
            'originalStart': '2026-08-31T16:00:00Z',
          }),
          200,
        );
      }),
      baseUri: Uri.parse('https://graph.microsoft.com/v1.0'),
      responseTimeZone: 'UTC',
    );
    final replayer = CalendarPendingOpsReplayer(
      database: database,
      client: client,
      accountId: 'microsoft-account',
      nowUtc: () => DateTime.utc(2026, 8, 29),
    );
    await replayer.replayDueOps();
    await replayer.replayDueOps();
    expect(
      (await database.select(database.pendingOps).get()).where(
        (row) => row.accountId == 'microsoft-account',
      ),
      isEmpty,
    );
    final patch = requests.singleWhere((request) => request.method == 'PATCH');
    expect(patch.url.path, '/v1.0/me/calendars/calendar/events/occurrence-ms');
    expect((jsonDecode(patch.body) as Map)['subject'], 'Moved');
    expect(patch.body, isNot(contains('attendees')));
  });

  test('Google import persists a cancelled occurrence identity', () async {
    final preview = importService.parsePreview(
      utf8.encode(
        _calendar('''
BEGIN:VEVENT
UID:cancelled-series
DTSTART:20260830T160000Z
DTEND:20260830T170000Z
SUMMARY:Master
RRULE:FREQ=DAILY;COUNT=2
END:VEVENT
BEGIN:VEVENT
UID:cancelled-series
RECURRENCE-ID:20260831T160000Z
STATUS:CANCELLED
END:VEVENT
'''),
      ),
    );
    final report = await importService.importPreview(
      preview: preview,
      destination: (await importService.writableDestinations()).single,
    );
    expect(report.queued, 1);
    var deleted = false;
    final requests = <http.Request>[];
    final client = GoogleCalendarApiClient(
      httpClient: MockClient((request) async {
        requests.add(request);
        if (request.method == 'DELETE') {
          deleted = true;
          return http.Response('', 204);
        }
        if (request.url.path.endsWith('/instances')) {
          return http.Response(
            jsonEncode({
              'items': [
                {
                  'id': 'occurrence-2',
                  'recurringEventId': 'master-2',
                  'originalStartTime': {'dateTime': '2026-08-31T16:00:00Z'},
                  'status': deleted ? 'cancelled' : 'confirmed',
                  'start': {'dateTime': '2026-08-31T16:00:00Z'},
                  'end': {'dateTime': '2026-08-31T17:00:00Z'},
                },
              ],
            }),
            200,
          );
        }
        if (request.method == 'GET') {
          return http.Response(jsonEncode({'items': <Object>[]}), 200);
        }
        return http.Response(
          jsonEncode({
            'id': 'master-2',
            'summary': 'Master',
            'start': {'dateTime': '2026-08-30T16:00:00Z'},
            'end': {'dateTime': '2026-08-30T17:00:00Z'},
          }),
          200,
        );
      }),
      baseUri: Uri.parse('https://www.googleapis.com'),
    );
    final replayer = CalendarPendingOpsReplayer(
      database: database,
      client: client,
      accountId: 'google-account',
      nowUtc: () => DateTime.utc(2026, 8, 29),
    );
    await replayer.replayDueOps();
    await replayer.replayDueOps();
    expect(
      requests.where((request) => request.method == 'DELETE'),
      hasLength(1),
    );
    expect(await database.select(database.pendingOps).get(), isEmpty);
    final occurrence = (await database.select(database.calendarEvents).get())
        .singleWhere((row) => row.providerEventId == 'occurrence-2');
    expect(occurrence.isCancelled, isTrue);
    expect(occurrence.providerOriginalStartKey, '2026-08-31T16:00:00Z');
  });

  test(
    'skips an embedded custom timezone the destination cannot carry',
    () async {
      final preview = importService.parsePreview(
        utf8.encode(
          _calendar('''
BEGIN:VTIMEZONE
TZID:Custom/Office
BEGIN:STANDARD
DTSTART:19700101T000000
TZOFFSETFROM:-0800
TZOFFSETTO:-0800
END:STANDARD
END:VTIMEZONE
BEGIN:VEVENT
UID:custom-timezone
DTSTART;TZID=Custom/Office:20260830T090000
DTEND;TZID=Custom/Office:20260830T100000
SUMMARY:Custom zone event
END:VEVENT
'''),
        ),
      );

      final report = await importService.importPreview(
        preview: preview,
        destination: (await importService.writableDestinations()).single,
      );

      expect(report.queued, 0);
      expect(report.unsupportedRecurrenceSets, hasLength(1));
      expect(
        report.unsupportedRecurrenceSets.single.reason,
        contains('custom timezone'),
      );
      expect(await database.select(database.calendarEvents).get(), isEmpty);
      expect(await database.select(database.pendingOps).get(), isEmpty);
    },
  );

  test('validates cross-zone duration by represented instants', () async {
    final preview = importService.parsePreview(
      utf8.encode(
        _calendar('''
BEGIN:VEVENT
UID:cross-zone-order
DTSTART;TZID=Asia/Tokyo:20260830T230000
DTEND;TZID=America/Vancouver:20260830T080000
SUMMARY:Cross-zone event
END:VEVENT
'''),
      ),
    );

    final report = await importService.importPreview(
      preview: preview,
      destination: (await importService.writableDestinations()).single,
    );

    expect(report.queued, 1);
    expect(report.unsupportedRecurrenceSets, isEmpty);
    final event = await database.select(database.calendarEvents).getSingle();
    expect(event.startTimeZone, 'Asia/Tokyo');
    expect(event.endTimeZone, 'America/Vancouver');
  });

  test('writable destinations exclude read-only and WebCal sources', () async {
    await database
        .into(database.accounts)
        .insert(
          AccountsCompanion.insert(
            id: 'webcal-account-sub',
            provider: 'webcal',
            authority: 'https://feed.example.test',
            providerAccountId: 'fingerprint',
            credentialKind: 'webcal_subscription',
            authState: const Value('signed_in'),
            calendarsEnabled: const Value(true),
            tasksEnabled: const Value(false),
            grantedScopes: const Value(''),
            createdAtUtc: _now,
            updatedAtUtc: _now,
          ),
        );
    await database
        .into(database.calendarSources)
        .insert(
          CalendarSourcesCompanion.insert(
            id: 'webcal-calendar-sub',
            accountId: 'webcal-account-sub',
            provider: 'webcal',
            providerCalendarId: 'sub',
            summary: 'Subscription',
            readOnly: const Value(true),
            createdAtLocal: 1,
            updatedAtLocal: 1,
          ),
        );
    await database
        .into(database.calendarSources)
        .insert(
          CalendarSourcesCompanion.insert(
            id: 'read-only-google',
            accountId: 'google-account',
            provider: 'google',
            providerCalendarId: 'readonly',
            summary: 'Read only',
            readOnly: const Value(true),
            createdAtLocal: 1,
            updatedAtLocal: 1,
          ),
        );

    expect(
      (await importService.writableDestinations()).map((source) => source.id),
      ['google-account|google|primary'],
    );
  });
}

Future<void> _seedAccountAndSource(AppDatabase database) async {
  await database
      .into(database.accounts)
      .insert(
        AccountsCompanion.insert(
          id: 'google-account',
          provider: 'google',
          authority: 'https://accounts.google.com',
          providerAccountId: 'me@example.test',
          credentialKind: 'oauth',
          email: const Value('me@example.test'),
          authState: const Value('signed_in'),
          grantedScopes: const Value(''),
          createdAtUtc: _now,
          updatedAtUtc: _now,
        ),
      );
  await database
      .into(database.calendarSources)
      .insert(
        CalendarSourcesCompanion.insert(
          id: 'google-account|google|primary',
          accountId: 'google-account',
          provider: 'google',
          providerCalendarId: 'primary',
          summary: 'Calendar',
          accessRole: const Value('owner'),
          createdAtLocal: 1,
          updatedAtLocal: 1,
        ),
      );
}

const _now = '2026-08-29T00:00:00.000Z';

String _calendar(String body) =>
    '''BEGIN:VCALENDAR\r
VERSION:2.0\r
PRODID:-//BusyMax Import Test//EN\r
${body.trim().replaceAll('\n', '\r\n')}\r
END:VCALENDAR\r
''';

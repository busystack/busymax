import 'dart:convert';

import 'package:busymax/src/calendar_providers/calendar_mutation.dart';
import 'package:busymax/src/calendar_providers/cloud_calendar_client.dart';
import 'package:busymax/src/db/app_database.dart';
import 'package:busymax/src/features/calendar/data/calendar_repository.dart';
import 'package:busymax/src/features/schedule/presentation/cloud_calendar_series_export.dart';
import 'package:busymax/src/features/sync/calendar_pending_ops_replayer.dart';
import 'package:busymax/src/google_calendar/google_calendar_api_client.dart';
import 'package:busymax/src/microsoft_calendar/microsoft_calendar_api_client.dart';
import 'package:busymax/src/microsoft_calendar/microsoft_calendar_mapper.dart';
import 'package:busymax/src/providers/busy_provider.dart';
import 'package:busymax/src/ical/ical_import_service.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:timezone/data/latest_all.dart' as time_zone_data;

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
    'R1 exported Microsoft exception retains privacy, availability and categories in queued patch',
    () async {
      await _seedMicrosoftDestination(database);
      time_zone_data.initializeTimeZones();
      final master = microsoftCalendarEventFromJson('source-calendar', {
        'id': 'source-master',
        'uid': 'r1-series',
        'subject': 'Master',
        'type': 'seriesMaster',
        'sensitivity': 'normal',
        'showAs': 'busy',
        'categories': ['A'],
        'start': {'dateTime': '2026-08-30T16:00:00', 'timeZone': 'UTC'},
        'end': {'dateTime': '2026-08-30T17:00:00', 'timeZone': 'UTC'},
        'recurrence': {
          'pattern': {'type': 'daily', 'interval': 1},
          'range': {
            'type': 'numbered',
            'startDate': '2026-08-30',
            'numberOfOccurrences': 2,
            'recurrenceTimeZone': 'UTC',
          },
        },
      });
      final exception = microsoftCalendarEventFromJson('source-calendar', {
        'id': 'source-exception',
        'uid': 'r1-series',
        'seriesMasterId': 'source-master',
        'originalStart': '2026-08-31T16:00:00Z',
        'subject': 'Moved',
        'sensitivity': 'private',
        'showAs': 'free',
        'categories': ['B'],
        'start': {'dateTime': '2026-08-31T18:00:00', 'timeZone': 'UTC'},
        'end': {'dateTime': '2026-08-31T19:00:00', 'timeZone': 'UTC'},
      });
      final exported = cloudSeriesToICalendar(
        master: master,
        exceptions: [exception],
        nowUtc: DateTime.utc(2026, 8, 29),
      );
      expect(exported, contains('CLASS:PRIVATE'));
      expect(exported, contains('TRANSP:TRANSPARENT'));
      expect(exported, contains('CATEGORIES:B'));
      final preview = importService.parsePreview(utf8.encode(exported));
      final destination = (await importService.writableDestinations())
          .singleWhere((source) => source.accountId == 'microsoft-account');
      expect(
        (await importService.importPreview(
          preview: preview,
          destination: destination,
        )).queued,
        1,
      );
      final pending = await database.select(database.pendingOps).get();
      final request =
          jsonDecode(
                pending
                    .singleWhere(
                      (op) => op.operationType == 'event.importException',
                    )
                    .requestJson,
              )
              as Map;
      expect(request['sensitivity'], 'private');
      expect(request['transparencyOrShowAs'], 'free');
      expect(request['categoriesJson'], ['B']);
      final masterRemote = <String, Object?>{
        'id': 'imported-master',
        'uid': 'r1-series',
        'subject': 'Master',
        'type': 'seriesMaster',
        'sensitivity': 'normal',
        'showAs': 'busy',
        'categories': ['A'],
        'start': {'dateTime': '2026-08-30T16:00:00', 'timeZone': 'UTC'},
        'end': {'dateTime': '2026-08-30T17:00:00', 'timeZone': 'UTC'},
      };
      final occurrenceRemote = <String, Object?>{
        'id': 'imported-occurrence',
        'uid': 'r1-series',
        'seriesMasterId': 'imported-master',
        'originalStart': '2026-08-31T16:00:00Z',
        'occurrenceId': 'oid-r1',
        'subject': 'Master',
        'sensitivity': 'normal',
        'showAs': 'busy',
        'categories': ['A'],
        'start': {'dateTime': '2026-08-31T16:00:00', 'timeZone': 'UTC'},
        'end': {'dateTime': '2026-08-31T17:00:00', 'timeZone': 'UTC'},
      };
      final patches = <Map<String, Object?>>[];
      final client = MicrosoftCalendarApiClient(
        httpClient: MockClient((httpRequest) async {
          if (httpRequest.method == 'POST') {
            return http.Response(jsonEncode(masterRemote), 201);
          }
          if (httpRequest.url.path.endsWith('/instances')) {
            return http.Response(
              jsonEncode({
                'value': [occurrenceRemote],
              }),
              200,
            );
          }
          if (httpRequest.method == 'GET' &&
              httpRequest.url.queryParameters.containsKey(r'$expand')) {
            return http.Response(
              jsonEncode({
                ...masterRemote,
                'exceptionOccurrences': <Object>[],
                'cancelledOccurrences': <Object>[],
              }),
              200,
            );
          }
          if (httpRequest.method == 'PATCH') {
            final patch = (jsonDecode(httpRequest.body) as Map)
                .cast<String, Object?>();
            patches.add(patch);
            occurrenceRemote.addAll(patch);
          }
          return http.Response(jsonEncode(occurrenceRemote), 200);
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
      expect(patches, hasLength(1));
      expect(patches.single['sensitivity'], 'private');
      expect(patches.single['showAs'], 'free');
      expect(patches.single['categories'], ['B']);
      expect(masterRemote['sensitivity'], 'normal');
      expect(masterRemote['showAs'], 'busy');
      final reloaded = (await database.select(database.calendarEvents).get())
          .singleWhere(
            (event) => event.providerEventId == 'imported-occurrence',
          );
      expect(reloaded.visibility, 'private');
      expect(reloaded.transparencyOrShowAs, 'free');
      expect(jsonDecode(reloaded.categoriesJson!), ['B']);
    },
  );

  test(
    'R1 Google same-visibility exception retains transparency and omits categories',
    () async {
      final preview = importService.parsePreview(
        utf8.encode(
          _calendar('''
BEGIN:VEVENT
UID:r1-google
DTSTART:20260830T160000Z
DTEND:20260830T170000Z
SUMMARY:Master
RRULE:FREQ=DAILY;COUNT=3
CLASS:PRIVATE
TRANSP:TRANSPARENT
END:VEVENT
BEGIN:VEVENT
UID:r1-google
RECURRENCE-ID:20260831T160000Z
DTSTART:20260831T180000Z
DTEND:20260831T190000Z
SUMMARY:Override
CLASS:PRIVATE
TRANSP:OPAQUE
CATEGORIES:Do not import
END:VEVENT
BEGIN:VEVENT
UID:r1-google
RECURRENCE-ID:20260901T160000Z
DTSTART:20260901T160000Z
DTEND:20260901T170000Z
SUMMARY:Inherited
END:VEVENT
'''),
        ),
      );
      final report = await importService.importPreview(
        preview: preview,
        destination: (await importService.writableDestinations()).single,
      );
      expect(report.queued, 1);
      expect(report.fieldsIntentionallyOmitted, contains('categories'));
      final requests = (await database.select(database.pendingOps).get())
          .where((op) => op.operationType == 'event.importException')
          .map((op) => jsonDecode(op.requestJson) as Map)
          .toList();
      expect(requests, hasLength(2));
      expect(requests.first['sensitivity'], 'private');
      expect(requests.first['transparencyOrShowAs'], 'opaque');
      expect(requests.first, isNot(contains('categoriesJson')));
      expect(requests.last, isNot(contains('sensitivity')));
      expect(requests.last, isNot(contains('transparencyOrShowAs')));
    },
  );

  test(
    'D Google mixed recurrence privacy is rejected before creation',
    () async {
      for (final (masterClass, exceptionClass) in [
        ('PRIVATE', 'PUBLIC'),
        ('PUBLIC', 'PRIVATE'),
      ]) {
        final preview = importService.parsePreview(
          utf8.encode(
            _calendar('''
BEGIN:VEVENT
UID:d-google-$masterClass-$exceptionClass
DTSTART:20260830T160000Z
DTEND:20260830T170000Z
SUMMARY:Master
RRULE:FREQ=DAILY;COUNT=2
CLASS:$masterClass
END:VEVENT
BEGIN:VEVENT
UID:d-google-$masterClass-$exceptionClass
RECURRENCE-ID:20260831T160000Z
DTSTART:20260831T160000Z
DTEND:20260831T170000Z
CLASS:$exceptionClass
END:VEVENT
'''),
          ),
        );
        final report = await importService.importPreview(
          preview: preview,
          destination: (await importService.writableDestinations()).single,
        );
        expect(report.queued, 0);
        expect(report.unsupportedRecurrenceSets, isNotEmpty);
        expect(await database.select(database.pendingOps).get(), isEmpty);
      }
    },
  );

  test(
    'R1 unsupported exception classification rejects the set before master creation',
    () async {
      final preview = importService.parsePreview(
        utf8.encode(
          _calendar('''
BEGIN:VEVENT
UID:r1-unsupported
DTSTART:20260830T160000Z
DTEND:20260830T170000Z
SUMMARY:Master
RRULE:FREQ=DAILY;COUNT=2
END:VEVENT
BEGIN:VEVENT
UID:r1-unsupported
RECURRENCE-ID:20260831T160000Z
DTSTART:20260831T160000Z
DTEND:20260831T170000Z
CLASS:SECRET
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
      expect(await database.select(database.pendingOps).get(), isEmpty);
    },
  );

  for (final provider in [BusyProvider.google, BusyProvider.microsoft]) {
    test(
      'R2 $provider zero-minute master and exception alarms stay explicit',
      () async {
        if (provider == BusyProvider.microsoft) {
          await _seedMicrosoftDestination(database);
        }
        final preview = importService.parsePreview(
          utf8.encode(
            _calendar('''
BEGIN:VEVENT
UID:r2-zero-$provider
DTSTART:20260830T160000Z
DTEND:20260830T170000Z
SUMMARY:Master
RRULE:FREQ=DAILY;COUNT=2
BEGIN:VALARM
ACTION:DISPLAY
TRIGGER:-PT0M
END:VALARM
END:VEVENT
BEGIN:VEVENT
UID:r2-zero-$provider
RECURRENCE-ID:20260831T160000Z
DTSTART:20260831T180000Z
DTEND:20260831T190000Z
SUMMARY:Moved
BEGIN:VALARM
ACTION:DISPLAY
TRIGGER:PT0M
END:VALARM
END:VEVENT
'''),
          ),
        );
        expect(
          preview.fieldsThatWillBeOmitted,
          isNot(contains('unsupported alarms')),
        );
        final destination = (await importService.writableDestinations())
            .singleWhere((source) => source.provider == provider);
        expect(
          (await importService.importPreview(
            preview: preview,
            destination: destination,
          )).queued,
          1,
        );
        final requests = (await database.select(database.pendingOps).get())
            .map((op) => jsonDecode(op.requestJson) as Map)
            .toList();
        final expected = provider == BusyProvider.microsoft
            ? {'isReminderOn': true, 'reminderMinutesBeforeStart': 0}
            : {
                'useDefault': false,
                'overrides': [
                  {'method': 'popup', 'minutes': 0},
                ],
              };
        expect(requests.first['remindersJson'], expected);
        expect(requests.last['remindersJson'], expected);
        final isMicrosoft = provider == BusyProvider.microsoft;
        final masterRemote = <String, Object?>{
          'id': 'r2-master',
          if (isMicrosoft) 'subject': 'Master' else 'summary': 'Master',
          if (isMicrosoft)
            'type': 'seriesMaster'
          else
            'iCalUID': 'r2-zero-$provider',
          'start': isMicrosoft
              ? {'dateTime': '2026-08-30T16:00:00', 'timeZone': 'UTC'}
              : {'dateTime': '2026-08-30T16:00:00Z'},
          'end': isMicrosoft
              ? {'dateTime': '2026-08-30T17:00:00', 'timeZone': 'UTC'}
              : {'dateTime': '2026-08-30T17:00:00Z'},
        };
        final occurrenceRemote = <String, Object?>{
          'id': 'r2-occurrence',
          if (isMicrosoft)
            'seriesMasterId': 'r2-master'
          else
            'recurringEventId': 'r2-master',
          if (isMicrosoft)
            'originalStart': '2026-08-31T16:00:00Z'
          else
            'originalStartTime': {'dateTime': '2026-08-31T16:00:00Z'},
          if (isMicrosoft) 'subject': 'Master' else 'summary': 'Master',
          'start': isMicrosoft
              ? {'dateTime': '2026-08-31T16:00:00', 'timeZone': 'UTC'}
              : {'dateTime': '2026-08-31T16:00:00Z'},
          'end': isMicrosoft
              ? {'dateTime': '2026-08-31T17:00:00', 'timeZone': 'UTC'}
              : {'dateTime': '2026-08-31T17:00:00Z'},
          if (isMicrosoft) 'occurrenceId': 'r2-occurrence-id',
        };
        final patches = <Map<String, Object?>>[];
        final httpClient = MockClient((httpRequest) async {
          if (httpRequest.method == 'POST') {
            masterRemote.addAll(
              (jsonDecode(httpRequest.body) as Map).cast<String, Object?>(),
            );
            return http.Response(
              jsonEncode(masterRemote),
              isMicrosoft ? 201 : 200,
            );
          }
          if (httpRequest.url.path.endsWith('/instances')) {
            return http.Response(
              jsonEncode(
                isMicrosoft
                    ? {
                        'value': [occurrenceRemote],
                      }
                    : {
                        'items': [occurrenceRemote],
                      },
              ),
              200,
            );
          }
          if (httpRequest.method == 'GET' &&
              isMicrosoft &&
              httpRequest.url.queryParameters.containsKey(r'$expand')) {
            return http.Response(
              jsonEncode({
                ...masterRemote,
                'exceptionOccurrences': <Object>[],
                'cancelledOccurrences': <Object>[],
              }),
              200,
            );
          }
          if (httpRequest.method == 'GET' && !isMicrosoft) {
            return http.Response(jsonEncode({'items': <Object>[]}), 200);
          }
          if (httpRequest.method == 'PATCH') {
            final patch = (jsonDecode(httpRequest.body) as Map)
                .cast<String, Object?>();
            patches.add(patch);
            occurrenceRemote.addAll(patch);
          }
          return http.Response(jsonEncode(occurrenceRemote), 200);
        });
        final CloudCalendarClient client = isMicrosoft
            ? MicrosoftCalendarApiClient(
                httpClient: httpClient,
                baseUri: Uri.parse('https://graph.microsoft.com/v1.0'),
                responseTimeZone: 'UTC',
              )
            : GoogleCalendarApiClient(
                httpClient: httpClient,
                baseUri: Uri.parse('https://www.googleapis.com'),
              );
        final replayer = CalendarPendingOpsReplayer(
          database: database,
          client: client,
          accountId: destination.accountId,
          nowUtc: () => DateTime.utc(2026, 8, 29),
        );
        await replayer.replayDueOps();
        await replayer.replayDueOps();
        expect(patches, hasLength(1));
        if (isMicrosoft) {
          expect(patches.single['isReminderOn'], true);
          expect(patches.single['reminderMinutesBeforeStart'], 0);
          expect(masterRemote['isReminderOn'], true);
          expect(masterRemote['reminderMinutesBeforeStart'], 0);
        } else {
          expect(patches.single['reminders'], expected);
          expect(masterRemote['reminders'], expected);
        }
        final reloaded = (await database.select(database.calendarEvents).get())
            .singleWhere((event) => event.providerEventId == 'r2-occurrence');
        expect(jsonDecode(reloaded.remindersJson!), expected);
      },
    );
  }

  test(
    'R2 zero-offset alarms are supported without accepting after-start or end-relative alarms',
    () {
      IcalImportPreview previewFor(String trigger) =>
          importService.parsePreview(
            utf8.encode(
              _calendar('''
BEGIN:VEVENT
UID:r2-trigger
DTSTART:20260830T160000Z
DTEND:20260830T170000Z
SUMMARY:Alarm
BEGIN:VALARM
ACTION:DISPLAY
$trigger
END:VALARM
END:VEVENT
'''),
            ),
          );
      for (final trigger in [
        'TRIGGER:-PT0M',
        'TRIGGER:PT0M',
        'TRIGGER:-PT10M',
      ]) {
        expect(
          previewFor(trigger).fieldsThatWillBeOmitted,
          isNot(contains('unsupported alarms')),
        );
      }
      for (final trigger in [
        'TRIGGER:PT10M',
        'TRIGGER;RELATED=END:-PT0M',
        'TRIGGER:invalid',
      ]) {
        expect(
          previewFor(trigger).fieldsThatWillBeOmitted,
          contains('unsupported alarms'),
        );
      }
    },
  );

  test('Microsoft PUBLIC import replays as normal sensitivity', () async {
    await _seedMicrosoftDestination(database);
    time_zone_data.initializeTimeZones();
    final exported = cloudSeriesToICalendar(
      master: microsoftCalendarEventFromJson('source-calendar', {
        'id': 'source-series',
        'uid': 'public-import',
        'subject': 'Public import',
        'type': 'seriesMaster',
        'sensitivity': 'normal',
        'start': {'dateTime': '2026-08-30T16:00:00', 'timeZone': 'UTC'},
        'end': {'dateTime': '2026-08-30T17:00:00', 'timeZone': 'UTC'},
        'recurrence': {
          'pattern': {'type': 'daily', 'interval': 1},
          'range': {
            'type': 'numbered',
            'startDate': '2026-08-30',
            'numberOfOccurrences': 2,
            'recurrenceTimeZone': 'UTC',
          },
        },
      }),
      exceptions: const [],
      nowUtc: DateTime.utc(2026, 8, 29),
    );
    expect(exported, contains('CLASS:PUBLIC'));
    final preview = importService.parsePreview(utf8.encode(exported));
    final destination = (await importService.writableDestinations())
        .singleWhere((source) => source.accountId == 'microsoft-account');
    expect(
      (await importService.importPreview(
        preview: preview,
        destination: destination,
      )).queued,
      1,
    );
    final requests = <http.Request>[];
    final client = MicrosoftCalendarApiClient(
      httpClient: MockClient((request) async {
        requests.add(request);
        return http.Response(
          jsonEncode({
            'id': 'remote-public',
            'subject': 'Public import',
            'sensitivity': 'normal',
            'start': {'dateTime': '2026-08-30T16:00:00', 'timeZone': 'UTC'},
            'end': {'dateTime': '2026-08-30T17:00:00', 'timeZone': 'UTC'},
          }),
          201,
        );
      }),
      baseUri: Uri.parse('https://graph.microsoft.com/v1.0'),
      responseTimeZone: 'UTC',
    );
    await CalendarPendingOpsReplayer(
      database: database,
      client: client,
      accountId: 'microsoft-account',
      nowUtc: () => DateTime.utc(2026, 8, 29),
    ).replayDueOps();
    final post = requests.singleWhere((request) => request.method == 'POST');
    expect((jsonDecode(post.body) as Map)['sensitivity'], 'normal');
    final detail = (await calendarRepository.loadEventDetail(
      CalendarRepository.eventId(
        accountId: 'microsoft-account',
        provider: BusyProvider.microsoft,
        providerCalendarId: 'calendar',
        providerEventId: 'remote-public',
      ),
    ))!;
    expect(detail.visibility, 'normal');
  });

  for (final scenario in const [
    (classification: 'PRIVATE', expected: 'private'),
    (classification: 'CONFIDENTIAL', expected: 'confidential'),
    (classification: '', expected: null),
  ]) {
    test(
      'Microsoft ${scenario.classification.isEmpty ? 'absent' : scenario.classification} classification queues ${scenario.expected}',
      () async {
        await _seedMicrosoftDestination(database);
        final classification = scenario.classification.isEmpty
            ? ''
            : 'CLASS:${scenario.classification}\n';
        final preview = importService.parsePreview(
          utf8.encode(
            _calendar('''
BEGIN:VEVENT
UID:classification-${scenario.classification}
DTSTART:20260830T160000Z
DTEND:20260830T170000Z
SUMMARY:Classification
${classification}END:VEVENT
'''),
          ),
        );
        final destination = (await importService.writableDestinations())
            .singleWhere((source) => source.accountId == 'microsoft-account');
        expect(
          (await importService.importPreview(
            preview: preview,
            destination: destination,
          )).queued,
          1,
        );
        final request =
            jsonDecode(
                  (await database.select(database.pendingOps).get())
                      .single
                      .requestJson,
                )
                as Map;
        expect(request['sensitivity'], scenario.expected);
      },
    );
  }

  test(
    'Google PUBLIC classification keeps visibility and Microsoft rejects unknown',
    () async {
      final googlePreview = importService.parsePreview(
        utf8.encode(
          _calendar('''
BEGIN:VEVENT
UID:google-public
DTSTART:20260830T160000Z
DTEND:20260830T170000Z
SUMMARY:Google public
CLASS:PUBLIC
END:VEVENT
'''),
        ),
      );
      final google = (await importService.writableDestinations()).singleWhere(
        (source) => source.accountId == 'google-account',
      );
      expect(
        (await importService.importPreview(
          preview: googlePreview,
          destination: google,
        )).queued,
        1,
      );
      expect(
        jsonDecode(
          (await database.select(database.pendingOps).get()).single.requestJson,
        )['visibility'],
        'public',
      );
      await _seedMicrosoftDestination(database);
      final unsupported = importService.parsePreview(
        utf8.encode(
          _calendar('''
BEGIN:VEVENT
UID:unknown-class
DTSTART:20260830T160000Z
DTEND:20260830T170000Z
SUMMARY:Unknown
CLASS:SECRET
END:VEVENT
'''),
        ),
      );
      final microsoft = (await importService.writableDestinations())
          .singleWhere((source) => source.accountId == 'microsoft-account');
      final report = await importService.importPreview(
        preview: unsupported,
        destination: microsoft,
      );
      expect(report.queued, 0);
      expect(report.unsupportedRecurrenceSets, hasLength(1));
      expect((await database.select(database.pendingOps).get()), hasLength(1));
    },
  );

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
CLASS:PRIVATE
TRANSP:TRANSPARENT
END:VEVENT
BEGIN:VEVENT
UID:with-exception
RECURRENCE-ID:20260831T160000Z
DTSTART:20260831T180000Z
DTEND:20260831T190000Z
SUMMARY:Moved
CLASS:PRIVATE
TRANSP:OPAQUE
CATEGORIES:Not imported
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
      final remoteOccurrence = <String, Object?>{
        'id': 'occurrence-1',
        'recurringEventId': 'master-1',
        'originalStartTime': {'dateTime': '2026-08-31T16:00:00Z'},
        'start': {'dateTime': '2026-08-31T16:00:00Z'},
        'end': {'dateTime': '2026-08-31T17:00:00Z'},
        'visibility': 'private',
        'transparency': 'transparent',
      };
      final client = GoogleCalendarApiClient(
        httpClient: MockClient((request) async {
          requests.add(request);
          if (request.method == 'GET' &&
              request.url.path.endsWith('/instances')) {
            return http.Response(
              jsonEncode({
                'items': [remoteOccurrence],
              }),
              200,
            );
          }
          if (request.method == 'GET') {
            return http.Response(jsonEncode({'items': <Object>[]}), 200);
          }
          if (request.method == 'PATCH') {
            remoteOccurrence.addAll(
              (jsonDecode(request.body) as Map).cast<String, Object?>(),
            );
            return http.Response(jsonEncode(remoteOccurrence), 200);
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
      expect((jsonDecode(patch.body) as Map)['visibility'], 'private');
      expect((jsonDecode(patch.body) as Map)['transparency'], 'opaque');
      expect(patch.body, isNot(contains('categories')));
      final reloaded = (await database.select(database.calendarEvents).get())
          .singleWhere((event) => event.providerEventId == 'occurrence-1');
      expect(reloaded.visibility, 'private');
      expect(reloaded.transparencyOrShowAs, 'opaque');
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

  for (final scenario in const [
    (
      zone: 'Pacific Standard Time',
      master: '2026-08-30',
      original: '2026-08-31',
      moved: '2026-09-02',
      originalUtc: '2026-08-31T07:00:00Z',
      cancelled: false,
      transientPatchFailure: false,
    ),
    (
      zone: 'Tokyo Standard Time',
      master: '2026-08-30',
      original: '2026-08-31',
      moved: '2026-09-02',
      originalUtc: '2026-08-30T15:00:00Z',
      cancelled: false,
      transientPatchFailure: false,
    ),
    (
      zone: 'Pacific Standard Time',
      master: '2026-03-07',
      original: '2026-03-08',
      moved: '2026-03-10',
      originalUtc: '2026-03-08T08:00:00Z',
      cancelled: false,
      transientPatchFailure: false,
    ),
    (
      zone: 'Tokyo Standard Time',
      master: '2026-08-30',
      original: '2026-08-31',
      moved: '2026-08-31',
      originalUtc: '2026-08-30T15:00:00Z',
      cancelled: true,
      transientPatchFailure: false,
    ),
    (
      zone: 'Pacific Standard Time',
      master: '2026-08-30',
      original: '2026-08-31',
      moved: '2026-09-02',
      originalUtc: '2026-08-31T07:00:00Z',
      cancelled: false,
      transientPatchFailure: true,
    ),
  ]) {
    test(
      'Microsoft all-day import ${scenario.cancelled ? 'cancellation' : 'move'} matches Graph UTC originalStart in ${scenario.zone} on ${scenario.original}${scenario.transientPatchFailure ? ' after retry' : ''}',
      () async {
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
                timeZone: Value(scenario.zone),
                createdAtLocal: 1,
                updatedAtLocal: 1,
              ),
            );
        final masterEnd = DateTime.parse(
          scenario.master,
        ).add(const Duration(days: 1)).toIso8601String().substring(0, 10);
        final originalEnd = DateTime.parse(
          scenario.original,
        ).add(const Duration(days: 1)).toIso8601String().substring(0, 10);
        final movedEnd = DateTime.parse(
          scenario.moved,
        ).add(const Duration(days: 1)).toIso8601String().substring(0, 10);
        String basic(String date) => date.replaceAll('-', '');
        final preview = importService.parsePreview(
          utf8.encode(
            _calendar('''
BEGIN:VEVENT
UID:all-day-ms
DTSTART;VALUE=DATE:${basic(scenario.master)}
DTEND;VALUE=DATE:${basic(masterEnd)}
SUMMARY:Master
RRULE:FREQ=DAILY;COUNT=2
END:VEVENT
BEGIN:VEVENT
UID:all-day-ms
RECURRENCE-ID;VALUE=DATE:${basic(scenario.original)}
${scenario.cancelled ? 'STATUS:CANCELLED' : 'DTSTART;VALUE=DATE:${basic(scenario.moved)}\nDTEND;VALUE=DATE:${basic(movedEnd)}\nSUMMARY:Moved'}
END:VEVENT
'''),
          ),
        );
        final destination = (await importService.writableDestinations())
            .singleWhere((source) => source.accountId == 'microsoft-account');
        expect(
          (await importService.importPreview(
            preview: preview,
            destination: destination,
          )).queued,
          1,
        );
        final requests = <http.Request>[];
        Map<String, Object?> event(String id, String start) => {
          'id': id,
          'subject': 'Master',
          'isAllDay': true,
          'start': {'dateTime': start, 'timeZone': scenario.zone},
          'end': {
            'dateTime': '${originalEnd}T00:00:00',
            'timeZone': scenario.zone,
          },
        };
        final client = MicrosoftCalendarApiClient(
          httpClient: MockClient((request) async {
            requests.add(request);
            if (request.method == 'POST') {
              return http.Response(
                jsonEncode(event('master-ms', '${scenario.master}T00:00:00')),
                201,
              );
            }
            if (request.method == 'DELETE') {
              return http.Response('', 204);
            }
            if (request.method == 'PATCH' &&
                scenario.transientPatchFailure &&
                requests.where((entry) => entry.method == 'PATCH').length ==
                    1) {
              return http.Response('temporary failure', 503);
            }
            if (request.url.path.endsWith('/instances')) {
              return http.Response(
                jsonEncode({
                  'value': [
                    {
                      ...event(
                        'occurrence-ms',
                        '${scenario.original}T00:00:00',
                      ),
                      'seriesMasterId': 'master-ms',
                      'originalStart': scenario.originalUtc,
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
                  ...event('master-ms', '${scenario.master}T00:00:00'),
                  'exceptionOccurrences': <Object>[],
                  'cancelledOccurrences': <Object>[],
                }),
                200,
              );
            }
            return http.Response(
              jsonEncode({
                ...event('occurrence-ms', '${scenario.moved}T00:00:00'),
                'seriesMasterId': 'master-ms',
                'originalStart': scenario.originalUtc,
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
        if (scenario.transientPatchFailure) {
          final pending = await database.select(database.pendingOps).get();
          expect(pending, hasLength(1));
          await database.pendingOpsDao.retryNow(
            pending.single.id,
            DateTime.utc(2026, 8, 29),
          );
        }
        await replayer.replayDueOps();
        expect(
          requests.where((request) => request.method == 'PATCH'),
          hasLength(
            scenario.cancelled
                ? 0
                : scenario.transientPatchFailure
                ? 2
                : 1,
          ),
        );
        expect(
          requests.where((request) => request.method == 'DELETE'),
          hasLength(scenario.cancelled ? 1 : 0),
        );
        expect(
          requests.where((request) => request.method == 'POST'),
          hasLength(1),
        );
        expect(await database.select(database.pendingOps).get(), isEmpty);
      },
    );
  }

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

Future<void> _seedMicrosoftDestination(AppDatabase database) async {
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
}

const _now = '2026-08-29T00:00:00.000Z';

String _calendar(String body) =>
    '''BEGIN:VCALENDAR\r
VERSION:2.0\r
PRODID:-//BusyMax Import Test//EN\r
${body.trim().replaceAll('\n', '\r\n')}\r
END:VCALENDAR\r
''';

import 'dart:convert';

import 'package:busymax/src/calendar_providers/calendar_mutation.dart';
import 'package:busymax/src/db/app_database.dart';
import 'package:busymax/src/features/calendar/data/calendar_repository.dart';
import 'package:busymax/src/ical/ical_import_service.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

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
      expect(event.attendeesJson, isNull);
      expect(event.organizerJson, '{"self":true}');
      expect(event.organizerJson, isNot(contains('organizer@example.test')));
      expect(event.conferenceJson, isNull);
      expect(event.syncStatus, 'pending');
      expect(event.recurrenceJson, isNotNull);
      final operation = await database.select(database.pendingOps).getSingle();
      final request = jsonDecode(operation.requestJson) as Map<String, Object?>;
      expect(request[calendarEventGuestUpdatePolicyKey], 'doNotSend');
      expect(request['attendeesJson'], isNull);
      expect(request, isNot(contains('organizer')));
      expect(request, isNot(contains('conferenceJson')));
      expect(
        (await database.select(database.icalImportReceipts).getSingle())
            .icalUid,
        'recurring-import',
      );

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
    'skips a whole recurrence set rather than dropping an exception',
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

      expect(report.queued, 0);
      expect(report.unsupportedRecurrenceSets, hasLength(1));
      expect(report.unsupportedRecurrenceSets.single.uid, 'with-exception');
      expect(
        report.unsupportedRecurrenceSets.single.reason,
        contains('Detached'),
      );
      expect(await database.select(database.calendarEvents).get(), isEmpty);
      expect(await database.select(database.pendingOps).get(), isEmpty);
    },
  );

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
      ['google-calendar'],
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
          id: 'google-calendar',
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

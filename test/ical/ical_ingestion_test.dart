import 'dart:convert';

import 'package:busymax/src/dav/ical/ical_semantics.dart';
import 'package:busymax/src/ical/ical_event_projection.dart';
import 'package:busymax/src/ical/ical_ingestion.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('shared iCalendar ingestion', () {
    test('groups multiple UIDs and retains recurrence exceptions', () {
      final result = IcalIngestion.parseString(
        _calendar('''
BEGIN:VEVENT
UID:first
DTSTART:20260830T160000Z
DTEND:20260830T170000Z
RRULE:FREQ=DAILY;COUNT=2
SUMMARY:Master
END:VEVENT
BEGIN:VEVENT
UID:first
RECURRENCE-ID:20260831T160000Z
DTSTART:20260831T180000Z
DTEND:20260831T190000Z
SUMMARY:Moved occurrence
END:VEVENT
BEGIN:VEVENT
UID:second
DTSTART;VALUE=DATE:20260901
DTEND;VALUE=DATE:20260902
SUMMARY:All day
END:VEVENT
'''),
        policy: IcalIngestionPolicy.webCal,
      );

      expect(result.recurrenceSets.map((set) => set.uid), ['first', 'second']);
      expect(result.recurrenceSets.first.semantic.components, hasLength(2));
      expect(
        result.recurrenceSets.first.semantic.components.last.recurrenceIdKey,
        '20260831T160000Z',
      );
    });

    test('rejects duplicate logical components without choosing one', () {
      final source = _calendar('''
${_event('duplicate', 'First')}
${_event('duplicate', 'Second')}
''');

      expect(
        () => IcalIngestion.parseString(
          source,
          policy: IcalIngestionPolicy.webCal,
        ),
        throwsA(
          isA<IcalIngestionException>().having(
            (error) => error.code,
            'code',
            'IcalDuplicateLogicalComponent',
          ),
        ),
      );
      final imported = IcalIngestion.parseString(
        source,
        policy: IcalIngestionPolicy.fileImport,
      );
      expect(imported.recurrenceSets, isEmpty);
      expect(imported.rejectedEvents.single.uid, 'duplicate');
    });

    test('normalizes recurrence identifiers before duplicate detection', () {
      final source = _calendar('''
BEGIN:VEVENT
UID:duplicate-date
DTSTART;VALUE=DATE:20260830
DTEND;VALUE=DATE:20260831
RRULE:FREQ=DAILY;COUNT=2
SUMMARY:Master
END:VEVENT
BEGIN:VEVENT
UID:duplicate-date
RECURRENCE-ID:20260831
DTSTART;VALUE=DATE:20260831
DTEND;VALUE=DATE:20260901
SUMMARY:First exception
END:VEVENT
BEGIN:VEVENT
UID:duplicate-date
RECURRENCE-ID;VALUE=DATE:20260831
DTSTART;VALUE=DATE:20260831
DTEND;VALUE=DATE:20260901
SUMMARY:Duplicate exception
END:VEVENT
''');

      expect(
        () => IcalIngestion.parseString(
          source,
          policy: IcalIngestionPolicy.webCal,
        ),
        throwsA(
          isA<IcalIngestionException>().having(
            (error) => error.code,
            'code',
            'IcalDuplicateLogicalComponent',
          ),
        ),
      );
    });

    test('retains VTIMEZONE in every semantic recurrence set', () {
      final result = IcalIngestion.parseString(
        _calendar('''
BEGIN:VTIMEZONE
TZID:Custom/Office
BEGIN:STANDARD
DTSTART:19700101T000000
TZOFFSETFROM:-0800
TZOFFSETTO:-0800
TZNAME:PST
END:STANDARD
END:VTIMEZONE
BEGIN:VEVENT
UID:zoned
DTSTART;TZID=Custom/Office:20260830T090000
DTEND;TZID=Custom/Office:20260830T100000
SUMMARY:Zoned
END:VEVENT
'''),
        policy: IcalIngestionPolicy.webCal,
      );

      expect(
        result.recurrenceSets.single.semantic.document.calendarComponents.where(
          (component) => component.name == 'VTIMEZONE',
        ),
        hasLength(1),
      );
      final projected = IcalEventProjector().project(
        result.recurrenceSets.single,
        rangeStartUtc: DateTime.utc(2026, 8, 1),
        rangeEndUtc: DateTime.utc(2026, 9, 30),
        transport: 'webcal',
      );
      expect(projected.single.startTimeZone, 'Custom/Office');
      expect(
        (jsonDecode(projected.single.rawJson) as Map)['startUtc'],
        '2026-08-30T17:00:00.000Z',
      );
    });

    test('preserves UTC, floating, and all-day value semantics', () {
      final result = IcalIngestion.parseString(
        _calendar('''
${_event('utc', 'UTC')}
BEGIN:VEVENT
UID:floating
DTSTART:20260830T090000
DTEND:20260830T100000
SUMMARY:Floating
END:VEVENT
BEGIN:VEVENT
UID:date
DTSTART;VALUE=DATE:20260830
DTEND;VALUE=DATE:20260831
SUMMARY:Date
END:VEVENT
'''),
        policy: IcalIngestionPolicy.webCal,
      );
      final projections = [
        for (final set in result.recurrenceSets)
          ...IcalEventProjector().project(
            set,
            rangeStartUtc: DateTime.utc(2026, 8, 1),
            rangeEndUtc: DateTime.utc(2026, 9, 30),
            transport: 'webcal',
          ),
      ];

      final byUid = {for (final event in projections) event.uid: event};
      expect(byUid['utc']!.startTimeZone, 'UTC');
      expect(byUid['floating']!.startTimeZone, isNull);
      expect(byUid['floating']!.startDateTime, '2026-08-30T09:00:00');
      expect(byUid['date']!.allDay, isTrue);
      expect(byUid['date']!.startDate, '2026-08-30');
    });

    test('uses fail-fast WebCal and partial file-import policies', () {
      final source = _calendar('''
${_event('valid', 'Valid')}
BEGIN:VEVENT
DTSTART:20260830T160000Z
DTEND:20260830T170000Z
SUMMARY:Missing UID
END:VEVENT
''');

      expect(
        () => IcalIngestion.parseString(
          source,
          policy: IcalIngestionPolicy.webCal,
        ),
        throwsA(isA<IcalIngestionException>()),
      );
      final imported = IcalIngestion.parseString(
        source,
        policy: IcalIngestionPolicy.fileImport,
      );
      expect(imported.recurrenceSets.single.uid, 'valid');
      expect(imported.rejectedEvents, hasLength(1));
    });

    test('accepts a valid zero-event snapshot but rejects no components', () {
      final empty = IcalIngestion.parseString(
        _calendar('''
BEGIN:VTODO
UID:task
DTSTAMP:20260829T000000Z
SUMMARY:Not projected
END:VTODO
'''),
        policy: IcalIngestionPolicy.webCal,
      );
      expect(empty.recurrenceSets, isEmpty);
      expect(empty.unprojectedComponentTypes, contains('VTODO'));

      expect(
        () => IcalIngestion.parseString(
          'BEGIN:VCALENDAR\r\nVERSION:2.0\r\nPRODID:-//BusyMax Test//EN\r\nEND:VCALENDAR\r\n',
          policy: IcalIngestionPolicy.webCal,
        ),
        throwsA(
          isA<IcalIngestionException>().having(
            (error) => error.code,
            'code',
            'IcalCalendarHasNoComponents',
          ),
        ),
      );
    });

    test('enforces envelope, BOM, strict UTF-8, and size invariants', () {
      final bom = <int>[
        0xef,
        0xbb,
        0xbf,
        ...utf8.encode(_calendar(_event('bom', 'BOM'))),
      ];
      expect(
        IcalIngestion.parseBytes(
          bom,
          policy: IcalIngestionPolicy.webCal,
        ).recurrenceSets.single.uid,
        'bom',
      );
      expect(
        () => IcalIngestion.parseBytes([
          0xc3,
          0x28,
        ], policy: IcalIngestionPolicy.webCal),
        throwsA(
          isA<IcalIngestionException>().having(
            (error) => error.code,
            'code',
            'IcalInvalidUtf8',
          ),
        ),
      );
      expect(
        () => IcalIngestion.parseBytes(
          List.filled(icalIngestionDecodedBodyLimit + 1, 0x20),
          policy: IcalIngestionPolicy.webCal,
        ),
        throwsA(
          isA<IcalIngestionException>().having(
            (error) => error.code,
            'code',
            'IcalBodyTooLarge',
          ),
        ),
      );
    });

    test('sanitized snapshot removes secret-bearing properties', () {
      final secret = Uri.parse('https://example.test/private.ics?token=secret');
      final target = Uri.parse('https://cdn.example.test/current.ics?key=two');
      final result = IcalIngestion.parseString(
        _calendar('''
SOURCE:${secret.toString()}
BEGIN:VEVENT
UID:safe
DTSTART:20260830T160000Z
DTEND:20260830T170000Z
SUMMARY:Safe
DESCRIPTION;ALTREP="${secret.toString()}":Quoted
DESCRIPTION;ALTREP="https://cdn.example.test/current.ics?
 key=two":Folded
DESCRIPTION;ALTREP="${secret.toString()}^nprivate":Escaped
END:VEVENT
'''),
        policy: IcalIngestionPolicy.webCal,
      );
      final snapshot = sanitizedCanonicalSnapshot(
        result.document,
        secretUris: [secret, target],
      );

      expect(snapshot, isNot(contains(secret.toString())));
      expect(snapshot, isNot(contains(target.toString())));
      expect(snapshot, isNot(contains('ALTREP')));
      expect(snapshot, contains('UID:safe'));
    });

    test('existing DAV semantic parser keeps one-UID invariant', () {
      expect(
        () => IcalSemanticDocument.parse(
          _calendar('''
${_event('one', 'One')}
${_event('two', 'Two')}
'''),
        ),
        throwsA(anything),
      );
    });
  });
}

String _calendar(String components) =>
    '''BEGIN:VCALENDAR\r
VERSION:2.0\r
PRODID:-//BusyMax Test//EN\r
${components.trim().replaceAll('\n', '\r\n')}\r
END:VCALENDAR\r
''';

String _event(String uid, String summary) =>
    '''BEGIN:VEVENT
UID:$uid
DTSTART:20260830T160000Z
DTEND:20260830T170000Z
SUMMARY:$summary
END:VEVENT''';

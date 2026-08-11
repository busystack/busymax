import 'package:busymax/src/dav/dav_errors.dart';
import 'package:busymax/src/dav/ical/ical_recurrence.dart';
import 'package:busymax/src/dav/ical/ical_semantics.dart';
import 'package:busymax/src/dav/ical/ical_timezone.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('expands weekly recurrence with RDATE, EXDATE, and moved exception', () {
    final document = IcalSemanticDocument.parse('''BEGIN:VCALENDAR\r
VERSION:2.0\r
PRODID:-//BusyMax Test//EN\r
BEGIN:VEVENT\r
UID:weekly@example.test\r
DTSTART;TZID=America/Vancouver:20260803T090000\r
DTEND;TZID=America/Vancouver:20260803T100000\r
RRULE:FREQ=WEEKLY;COUNT=4;BYDAY=MO\r
RDATE;TZID=America/Vancouver:20260907T090000\r
EXDATE;TZID=America/Vancouver:20260810T090000\r
SUMMARY:Master\r
END:VEVENT\r
BEGIN:VEVENT\r
UID:weekly@example.test\r
RECURRENCE-ID;TZID=America/Vancouver:20260817T090000\r
DTSTART;TZID=America/Vancouver:20260818T110000\r
DTEND;TZID=America/Vancouver:20260818T123000\r
SUMMARY:Moved\r
END:VEVENT\r
END:VCALENDAR\r
''');

    final occurrences = IcalRecurrenceExpander().expand(
      document,
      rangeStartUtc: DateTime.utc(2026, 8),
      rangeEndUtc: DateTime.utc(2026, 10),
    );

    expect(occurrences.map((occurrence) => occurrence.start.rawValue), [
      '20260803T090000',
      '20260818T110000',
      '20260824T090000',
      '20260907T090000',
    ]);
    final moved = occurrences.singleWhere(
      (occurrence) => occurrence.isException,
    );
    expect(moved.recurrenceId.rawValue, '20260817T090000');
    expect(moved.end?.rawValue, '20260818T123000');
    expect(moved.summary, 'Moved');
  });

  test('preserves wall time across a TZID daylight-saving transition', () {
    final document = IcalSemanticDocument.parse(
      _eventWithRule(
        start: 'DTSTART;TZID=America/Vancouver:20260301T090000',
        end: 'DTEND;TZID=America/Vancouver:20260301T100000',
        rule: 'RRULE:FREQ=WEEKLY;COUNT=3',
      ),
    );

    final occurrences = IcalRecurrenceExpander().expand(
      document,
      rangeStartUtc: DateTime.utc(2026, 2, 28),
      rangeEndUtc: DateTime.utc(2026, 3, 20),
    );

    expect(occurrences.map((occurrence) => occurrence.start.rawValue), [
      '20260301T090000',
      '20260308T090000',
      '20260315T090000',
    ]);
    expect(occurrences.map((occurrence) => occurrence.end!.rawValue), [
      '20260301T100000',
      '20260308T100000',
      '20260315T100000',
    ]);
  });

  test('resolves an embedded custom VTIMEZONE across daylight saving', () {
    final document = IcalSemanticDocument.parse('''BEGIN:VCALENDAR\r
VERSION:2.0\r
PRODID:-//BusyMax Test//EN\r
BEGIN:VTIMEZONE\r
TZID:Custom/Pacific-Test\r
BEGIN:STANDARD\r
DTSTART:19701101T020000\r
RRULE:FREQ=YEARLY;BYMONTH=11;BYDAY=1SU\r
TZOFFSETFROM:-0700\r
TZOFFSETTO:-0800\r
END:STANDARD\r
BEGIN:DAYLIGHT\r
DTSTART:19700308T020000\r
RRULE:FREQ=YEARLY;BYMONTH=3;BYDAY=2SU\r
TZOFFSETFROM:-0800\r
TZOFFSETTO:-0700\r
END:DAYLIGHT\r
END:VTIMEZONE\r
BEGIN:VEVENT\r
UID:custom-zone@example.test\r
DTSTART;TZID=Custom/Pacific-Test:20260301T090000\r
DTEND;TZID=Custom/Pacific-Test:20260301T100000\r
RRULE:FREQ=WEEKLY;COUNT=3\r
SUMMARY:Custom zone\r
END:VEVENT\r
END:VCALENDAR\r
''');

    final occurrences = IcalRecurrenceExpander().expand(
      document,
      rangeStartUtc: DateTime.utc(2026, 2, 28),
      rangeEndUtc: DateTime.utc(2026, 3, 20),
    );
    final resolver = IcalTimeZoneResolver.fromDocument(document);

    expect(occurrences.map((occurrence) => occurrence.start.rawValue), [
      '20260301T090000',
      '20260308T090000',
      '20260315T090000',
    ]);
    expect(occurrences.map((occurrence) => resolver.toUtc(occurrence.start)), [
      DateTime.utc(2026, 3, 1, 17),
      DateTime.utc(2026, 3, 8, 16),
      DateTime.utc(2026, 3, 15, 16),
    ]);
  });

  test('does not guess an unresolved custom TZID', () {
    final document = IcalSemanticDocument.parse(
      _eventWithRule(
        start: 'DTSTART;TZID=Private/Unknown:20260301T090000',
        end: 'DTEND;TZID=Private/Unknown:20260301T100000',
        rule: 'RRULE:FREQ=WEEKLY;COUNT=2',
      ),
    );

    expect(
      () => IcalRecurrenceExpander().expand(
        document,
        rangeStartUtc: DateTime.utc(2026, 2, 28),
        rangeEndUtc: DateTime.utc(2026, 3, 20),
      ),
      throwsA(
        isA<DavException>().having(
          (error) => error.code,
          'code',
          'IcalUnknownTimeZone',
        ),
      ),
    );
  });

  test('supports monthly ordinal days and BYSETPOS', () {
    final document = IcalSemanticDocument.parse(
      _eventWithRule(
        start: 'DTSTART:20260130T090000Z',
        end: 'DTEND:20260130T100000Z',
        rule: 'RRULE:FREQ=MONTHLY;COUNT=4;BYDAY=MO,TU,WE,TH,FR;BYSETPOS=-1',
      ),
    );

    final occurrences = IcalRecurrenceExpander().expand(
      document,
      rangeStartUtc: DateTime.utc(2026),
      rangeEndUtc: DateTime.utc(2026, 6),
    );

    expect(occurrences.map((occurrence) => occurrence.start.rawValue), [
      '20260130T090000Z',
      '20260227T090000Z',
      '20260331T090000Z',
      '20260430T090000Z',
    ]);
  });

  test('supports yearly BYMONTH and ordinal BYDAY', () {
    final document = IcalSemanticDocument.parse(
      _eventWithRule(
        start: 'DTSTART:20261126T090000Z',
        end: 'DTEND:20261126T100000Z',
        rule: 'RRULE:FREQ=YEARLY;COUNT=3;BYMONTH=11;BYDAY=4TH',
      ),
    );

    final occurrences = IcalRecurrenceExpander().expand(
      document,
      rangeStartUtc: DateTime.utc(2026),
      rangeEndUtc: DateTime.utc(2029),
    );

    expect(occurrences.map((occurrence) => occurrence.start.rawValue), [
      '20261126T090000Z',
      '20271125T090000Z',
      '20281123T090000Z',
    ]);
  });

  test('all-day occurrence keeps DATE values and exclusive duration', () {
    final document = IcalSemanticDocument.parse(
      _eventWithRule(
        start: 'DTSTART;VALUE=DATE:20260808',
        end: 'DTEND;VALUE=DATE:20260810',
        rule: 'RRULE:FREQ=DAILY;COUNT=2',
      ),
    );

    final occurrences = IcalRecurrenceExpander().expand(
      document,
      rangeStartUtc: DateTime.utc(2026, 8, 8),
      rangeEndUtc: DateTime.utc(2026, 8, 12),
    );

    expect(occurrences.map((occurrence) => occurrence.start.rawValue), [
      '20260808',
      '20260809',
    ]);
    expect(occurrences.map((occurrence) => occurrence.end!.rawValue), [
      '20260810',
      '20260811',
    ]);
    expect(
      occurrences.every(
        (occurrence) => occurrence.start.kind == IcalTemporalKind.date,
      ),
      isTrue,
    );
  });

  test('cancelled exception is retained as an explicit occurrence state', () {
    final document = IcalSemanticDocument.parse('''BEGIN:VCALENDAR\r
VERSION:2.0\r
PRODID:-//BusyMax Test//EN\r
BEGIN:VEVENT\r
UID:cancelled@example.test\r
DTSTART:20260801T090000Z\r
DURATION:PT1H\r
RRULE:FREQ=DAILY;COUNT=2\r
SUMMARY:Master\r
END:VEVENT\r
BEGIN:VEVENT\r
UID:cancelled@example.test\r
RECURRENCE-ID:20260802T090000Z\r
STATUS:CANCELLED\r
END:VEVENT\r
END:VCALENDAR\r
''');

    final occurrences = IcalRecurrenceExpander().expand(
      document,
      rangeStartUtc: DateTime.utc(2026, 8),
      rangeEndUtc: DateTime.utc(2026, 8, 4),
    );

    expect(occurrences, hasLength(2));
    expect(occurrences.last.isCancelled, isTrue);
    expect(occurrences.last.start.rawValue, '20260802T090000Z');
    expect(occurrences.last.end?.rawValue, '20260802T100000Z');
  });

  test('bounds projection range, output, and malformed rule input', () {
    final document = IcalSemanticDocument.parse(
      _eventWithRule(
        start: 'DTSTART:20260101T000000Z',
        end: 'DTEND:20260101T000001Z',
        rule: 'RRULE:FREQ=SECONDLY',
      ),
    );
    final expander = IcalRecurrenceExpander(
      limits: const IcalRecurrenceLimits(
        maximumOccurrences: 5,
        maximumProjectionRange: Duration(days: 10),
      ),
    );

    expect(
      () => expander.expand(
        document,
        rangeStartUtc: DateTime.utc(2026),
        rangeEndUtc: DateTime.utc(2026, 1, 2),
      ),
      throwsA(
        isA<DavException>().having(
          (error) => error.code,
          'code',
          'IcalRecurrenceOccurrenceLimitExceeded',
        ),
      ),
    );
    expect(
      () => IcalSemanticDocument.parse(
        _eventWithRule(
          start: 'DTSTART:20260101T000000Z',
          end: 'DTEND:20260101T000001Z',
          rule: 'RRULE:FREQ=DAILY;BYMONTHDAY=0',
        ),
      ),
      returnsNormally,
    );
    expect(
      () => IcalRecurrenceExpander().expand(
        IcalSemanticDocument.parse(
          _eventWithRule(
            start: 'DTSTART:20260101T000000Z',
            end: 'DTEND:20260101T000001Z',
            rule: 'RRULE:FREQ=DAILY;BYMONTHDAY=0',
          ),
        ),
        rangeStartUtc: DateTime.utc(2026),
        rangeEndUtc: DateTime.utc(2026, 1, 2),
      ),
      throwsA(
        isA<DavException>().having(
          (error) => error.code,
          'code',
          'IcalInvalidRecurrenceRule',
        ),
      ),
    );
  });
}

String _eventWithRule({
  required String start,
  required String end,
  required String rule,
}) =>
    '''BEGIN:VCALENDAR\r
VERSION:2.0\r
PRODID:-//BusyMax Test//EN\r
BEGIN:VEVENT\r
UID:rule@example.test\r
$start\r
$end\r
$rule\r
SUMMARY:Rule\r
END:VEVENT\r
END:VCALENDAR\r
''';

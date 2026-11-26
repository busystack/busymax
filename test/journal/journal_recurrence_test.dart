import 'package:busymax/src/dav/ical/ical_recurrence.dart';
import 'package:busymax/src/dav/ical/ical_semantics.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  List<IcalOccurrence> occurrences(String components) =>
      IcalRecurrenceExpander().expand(
        IcalSemanticDocument.parse(
          'BEGIN:VCALENDAR\r\nVERSION:2.0\r\nPRODID:-//Journal QA//EN\r\n'
          '$components'
          'END:VCALENDAR\r\n',
        ),
        rangeStartUtc: DateTime.utc(2026, 11, 25),
        rangeEndUtc: DateTime.utc(2026, 12, 1),
      );

  const first = 'BEGIN:VJOURNAL\r\nUID:same\r\nDTSTAMP:20261125T000000Z\r\n';
  const last = 'END:VJOURNAL\r\n';

  test('old subdaily journal rules spend their budget inside the query', () {
    for (final (rule, rangeStart, rangeEnd, expected) in [
      (
        'FREQ=MINUTELY;BYHOUR=9;BYMINUTE=0',
        DateTime.utc(2026, 11),
        DateTime.utc(2026, 12),
        [for (var day = 1; day <= 30; day++) DateTime.utc(2026, 11, day, 9)],
      ),
      (
        'FREQ=SECONDLY;BYHOUR=9;BYMINUTE=0;BYSECOND=0',
        DateTime.utc(2026, 11, 27, 8),
        DateTime.utc(2026, 11, 27, 10),
        [DateTime.utc(2026, 11, 27, 9)],
      ),
      (
        'FREQ=HOURLY;BYHOUR=9',
        DateTime.utc(2026, 11, 27, 8),
        DateTime.utc(2026, 11, 27, 10),
        [DateTime.utc(2026, 11, 27, 9)],
      ),
    ]) {
      final document = IcalSemanticDocument.parse(
        'BEGIN:VCALENDAR\r\nVERSION:2.0\r\nPRODID:-//Journal QA//EN\r\n'
        '$first'
        'DTSTART:20240101T090000Z\r\nRRULE:$rule\r\n'
        '$last'
        'END:VCALENDAR\r\n',
      );
      expect(
        IcalRecurrenceExpander()
            .expand(document, rangeStartUtc: rangeStart, rangeEndUtc: rangeEnd)
            .map((instance) => instance.start.localValue),
        expected,
        reason: rule,
      );
    }
  });

  test('journal periods supply occurrence starts but no serialized end', () {
    final rows = occurrences(
      '$first'
      'DTSTART:20261125T090000Z\r\nRRULE:FREQ=DAILY;COUNT=2\r\n'
      'EXDATE:20261126T090000Z\r\n'
      'RDATE;VALUE=PERIOD:20261127T090000Z/PT2H,20261128T090000Z/20261128T110000Z\r\n'
      '$last',
    );
    expect(rows.map((row) => row.start.rawValue), [
      '20261125T090000Z',
      '20261127T090000Z',
      '20261128T090000Z',
    ]);
    expect(rows.map((row) => row.end), everyElement(isNull));
  });

  test('journal detached-only resources use effective start and stable recurrence ID', () {
    final rows = occurrences(
      '$first'
      'RECURRENCE-ID:20261125T090000Z\r\nDTSTART:20261129T140000Z\r\n$last'
      '$first'
      'RECURRENCE-ID:20261126T090000Z\r\n$last',
    );
    expect(rows, hasLength(1));
    expect(rows.single.recurrenceId.rawValue, '20261125T090000Z');
    expect(rows.single.start.rawValue, '20261129T140000Z');
    expect(rows.single.end, isNull);
  });
}

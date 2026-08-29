import 'package:busymax/src/dav/ical/ical_task_recurrence.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses and serializes the Nextcloud recurrence editor fields', () {
    final recurrence = IcalTaskRecurrence.fromJson(
      '''{"rules":["FREQ=YEARLY;INTERVAL=2;BYDAY=MO,TU,WE,TH,FR;BYMONTH=1,6;BYSETPOS=-1;COUNT=8"],"dates":["20260809"],"excludedDates":["20270809"]}''',
    );

    expect(recurrence.isSupported, isTrue);
    expect(recurrence.frequency, IcalTaskRecurrenceFrequency.yearly);
    expect(recurrence.interval, 2);
    expect(recurrence.byDay, ['MO', 'TU', 'WE', 'TH', 'FR']);
    expect(recurrence.byMonth, [1, 6]);
    expect(recurrence.bySetPosition, -1);
    expect(recurrence.count, 8);
    expect(recurrence.recurrenceDates, ['20260809']);
    expect(recurrence.exceptionDates, ['20270809']);
    expect(
      recurrence.toRrule(),
      'FREQ=YEARLY;INTERVAL=2;BYDAY=MO,TU,WE,TH,FR;BYMONTH=1,6;BYSETPOS=-1;COUNT=8',
    );
  });

  test('all-day and timed UNTIL values are inclusive wire values', () {
    const monthly = IcalTaskRecurrence(
      frequency: IcalTaskRecurrenceFrequency.monthly,
      interval: 1,
      byDay: [],
      byMonth: [],
      byMonthDay: [15],
      bySetPosition: null,
      count: null,
      untilRaw: null,
      recurrenceDates: [],
      exceptionDates: [],
      rawRules: [],
      isSupported: true,
    );

    expect(
      monthly.withUntilDate('2026-12-31', allDay: true).untilRaw,
      '20261231',
    );
    final timed = monthly.withUntilDate('2026-12-31', allDay: false);
    expect(timed.untilRaw, matches(RegExp(r'^\d{8}T\d{6}Z$')));
    expect(timed.untilDate, '2026-12-31');
    expect(
      monthly
          .withUntilDate(
            '2026-12-31',
            allDay: false,
            floating: true,
            baseDate: DateTime(2026, 6, 15, 9, 30),
          )
          .untilRaw,
      '20261231T093000',
    );
  });

  test('multiple or unknown rules remain opaque and are never rewritten', () {
    final multiple = IcalTaskRecurrence.fromJson(
      '''{"rules":["FREQ=DAILY","FREQ=WEEKLY"],"dates":[],"excludedDates":[]}''',
    );
    final unsupported = IcalTaskRecurrence.fromJson(
      '''{"rules":["FREQ=HOURLY;INTERVAL=3"],"dates":[],"excludedDates":[]}''',
    );

    expect(multiple.isSupported, isFalse);
    expect(multiple.rawRules, ['FREQ=DAILY', 'FREQ=WEEKLY']);
    expect(unsupported.isSupported, isFalse);
    expect(unsupported.rawRules, ['FREQ=HOURLY;INTERVAL=3']);
    expect(() => unsupported.toRrule(), throwsStateError);
  });

  test('invalid BYDAY ordinals are preserved as unsupported', () {
    final recurrence = IcalTaskRecurrence.fromJson(
      '''{"rules":["FREQ=MONTHLY;BYDAY=+MO"],"dates":[],"excludedDates":[]}''',
    );

    expect(recurrence.isSupported, isFalse);
    expect(recurrence.rawRules, ['FREQ=MONTHLY;BYDAY=+MO']);
  });

  test('normalizes the ordinal BYDAY form accepted by Nextcloud', () {
    final recurrence = IcalTaskRecurrence.fromJson(
      '''{"rules":["FREQ=MONTHLY;BYDAY=-1FR"],"dates":[],"excludedDates":[]}''',
    );

    expect(recurrence.isSupported, isTrue);
    expect(recurrence.byDay, ['FR']);
    expect(recurrence.bySetPosition, -1);
    expect(
      recurrence.toRrule(),
      'FREQ=MONTHLY;INTERVAL=1;BYDAY=FR;BYSETPOS=-1',
    );
  });

  test('fills omitted weekly and yearly values from the task base date', () {
    final weekly = IcalTaskRecurrence.fromJson(
      '''{"rules":["FREQ=WEEKLY"],"dates":[],"excludedDates":[]}''',
      baseDate: DateTime(2026, 8, 9),
    );
    final yearly = IcalTaskRecurrence.fromJson(
      '''{"rules":["FREQ=YEARLY"],"dates":[],"excludedDates":[]}''',
      baseDate: DateTime(2026, 8, 9),
    );

    expect(weekly.byDay, ['SU']);
    expect(yearly.byMonth, [8]);
    expect(yearly.byMonthDay, [9]);
  });

  test('preserves values outside the Nextcloud editor limits', () {
    const rules = [
      'FREQ=DAILY;BYDAY=MO',
      'FREQ=WEEKLY;INTERVAL=367;BYDAY=MO',
      'FREQ=MONTHLY;BYMONTHDAY=-1',
      'FREQ=MONTHLY;BYDAY=MO,TU;BYSETPOS=1',
      'FREQ=MONTHLY;BYDAY=MO;BYSETPOS=-3',
      'FREQ=YEARLY;BYMONTH=1;BYMONTHDAY=1;COUNT=3501',
    ];

    for (final rule in rules) {
      final recurrence = IcalTaskRecurrence.fromJson(
        '{"rules":["$rule"],"dates":[],"excludedDates":[]}',
        baseDate: DateTime(2026, 8, 9),
      );
      expect(recurrence.isSupported, isFalse, reason: rule);
      expect(recurrence.rawRules, [rule], reason: rule);
    }
  });
}

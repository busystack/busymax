import 'package:busymax/src/features/recurrence/domain/series_timing_change.dart';
import 'package:busymax/src/features/recurrence/domain/event_recurrence_codec.dart';
import 'package:busymax/src/dav/ical/ical_recurrence.dart';
import 'package:busymax/src/dav/ical/ical_semantics.dart';
import 'package:busymax/src/providers/busy_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  SeriesTimingChange plan(
    String rule,
    DateTime start,
    DateTime before,
    DateTime after, {
    BusyProvider provider = BusyProvider.google,
    bool allDay = false,
    String? zone = 'UTC',
  }) {
    final original = provider == BusyProvider.microsoft
        ? EventRecurrenceCodec.encode(
            provider,
            EventRecurrenceCodec.decode(BusyProvider.google, [
              'RRULE:$rule',
            ], baseDate: start),
            baseDate: start,
            allDay: allDay,
            timeZone: zone,
          )!
        : ['RRULE:$rule'];
    return SeriesTimingChange.plan(
      provider: provider,
      original: original,
      masterStart: start,
      occurrenceStart: before,
      desiredStart: after,
      allDay: allDay,
      originalTimeZone: zone,
      timeZone: zone,
    );
  }

  test(
    'weekly edit translates ordinary dates and survives its persisted request',
    () {
      for (final provider in [
        BusyProvider.google,
        BusyProvider.microsoft,
        BusyProvider.nextcloud,
        BusyProvider.appleICloud,
      ]) {
        final value = plan(
          'FREQ=WEEKLY;BYDAY=MO;COUNT=5',
          DateTime.utc(2026, 6, 1, 9),
          DateTime.utc(2026, 6, 8, 9),
          DateTime.utc(2026, 6, 9, 9),
          provider: provider,
        );
        expect(value.rule.byDay, ['TU']);
        expect(value.requiresConfirmation, isFalse);
        final restored = SeriesTimingChange.fromJson(value.toJson());
        expect(
          restored.mapOccurrence(DateTime.utc(2026, 6, 15, 9)),
          DateTime.utc(2026, 6, 16, 9),
        );
        expect(_expand(restored, DateTime.utc(2026, 7)), [
          DateTime.utc(2026, 6, 2, 9),
          DateTime.utc(2026, 6, 9, 9),
          DateTime.utc(2026, 6, 16, 9),
          DateTime.utc(2026, 6, 23, 9),
          DateTime.utc(2026, 6, 30, 9),
        ]);
      }
    },
  );
  test(
    'interval and multi-weekday phase survive wrapping the week boundary',
    () {
      final value = plan(
        'FREQ=WEEKLY;INTERVAL=2;BYDAY=FR,SU;WKST=MO;COUNT=6',
        DateTime.utc(2026, 6, 5, 9),
        DateTime.utc(2026, 6, 5, 9),
        DateTime.utc(2026, 6, 7, 9),
      );
      expect(value.rule.interval, 2);
      expect(value.rule.byDay, ['SU', 'TU']);
      expect(_expand(value, DateTime.utc(2026, 8)), [
        DateTime.utc(2026, 6, 7, 9),
        DateTime.utc(2026, 6, 9, 9),
        DateTime.utc(2026, 6, 21, 9),
        DateTime.utc(2026, 6, 23, 9),
        DateTime.utc(2026, 7, 5, 9),
        DateTime.utc(2026, 7, 7, 9),
      ]);
    },
  );
  test(
    'monthly ordinal reanchors within each month, rather than adding a day',
    () {
      final value = plan(
        'FREQ=MONTHLY;BYDAY=-1MO;COUNT=3',
        DateTime.utc(2026, 1, 26, 9),
        DateTime.utc(2026, 2, 23, 9),
        DateTime.utc(2026, 2, 24, 9),
      );
      expect(value.requiresConfirmation, isFalse);
      expect(value.rule.bySetPosition, -1);
      expect(_expand(value, DateTime.utc(2026, 4)), [
        DateTime.utc(2026, 1, 27, 9),
        DateTime.utc(2026, 2, 24, 9),
        DateTime.utc(2026, 3, 31, 9),
      ]);
    },
  );
  test('cross-month ordinal proposes its actual new position for approval', () {
    final value = plan(
      'FREQ=MONTHLY;BYDAY=-1MO;COUNT=3',
      DateTime.utc(2026, 8, 31, 9),
      DateTime.utc(2026, 8, 31, 9),
      DateTime.utc(2026, 9, 1, 9),
    );
    expect(value.requiresConfirmation, isTrue);
    expect(value.rule.bySetPosition, 1);
    expect(value.rule.byDay, ['TU']);
    expect(_expand(value, DateTime.utc(2026, 12)), [
      DateTime.utc(2026, 9, 1, 9),
      DateTime.utc(2026, 10, 6, 9),
      DateTime.utc(2026, 11, 3, 9),
    ]);
  });
  test('monthly 31st to 1st requires approval and preserves COUNT mode', () {
    final value = plan(
      'FREQ=MONTHLY;BYMONTHDAY=31;COUNT=4',
      DateTime.utc(2026, 1, 31, 9),
      DateTime.utc(2026, 1, 31, 9),
      DateTime.utc(2026, 2, 1, 9),
    );
    expect(value.requiresConfirmation, isTrue);
    expect(value.rule.count, 4);
    expect(value.rule.untilRaw, isNull);
    expect(_expand(value, DateTime.utc(2026, 9)), [
      DateTime.utc(2026, 2, 1, 9),
      DateTime.utc(2026, 3, 1, 9),
      DateTime.utc(2026, 4, 1, 9),
      DateTime.utc(2026, 5, 1, 9),
    ]);
    expect(value.containsNewOccurrence(DateTime.utc(2026, 6, 1, 9)), isFalse);
  });
  test('ordinary monthly date change retains its pattern type', () {
    final value = plan(
      'FREQ=MONTHLY;INTERVAL=2;BYMONTHDAY=5;COUNT=3',
      DateTime.utc(2026, 1, 5, 9),
      DateTime.utc(2026, 3, 5, 9),
      DateTime.utc(2026, 3, 6, 9),
    );
    expect(value.requiresConfirmation, isFalse);
    expect(value.rule.byMonthDay, [6]);
    expect(_expand(value, DateTime.utc(2026, 7)), [
      DateTime.utc(2026, 1, 6, 9),
      DateTime.utc(2026, 3, 6, 9),
      DateTime.utc(2026, 5, 6, 9),
    ]);
  });
  test(
    'time-only edit retains all recurrence dates, selectors and interval',
    () {
      final value = plan(
        'FREQ=MONTHLY;INTERVAL=2;BYDAY=-1MO;COUNT=3',
        DateTime.utc(2026, 1, 26, 9),
        DateTime.utc(2026, 3, 30, 9),
        DateTime.utc(2026, 3, 30, 11),
      );
      expect(value.requiresConfirmation, isFalse);
      expect(value.rule.byDay, ['MO']);
      expect(value.rule.bySetPosition, -1);
      expect(value.rule.interval, 2);
      expect(_expand(value, DateTime.utc(2026, 7)), [
        DateTime.utc(2026, 1, 26, 11),
        DateTime.utc(2026, 3, 30, 11),
        DateTime.utc(2026, 5, 25, 11),
      ]);
    },
  );
  test(
    'UNTIL date remains fixed and cannot silently drop the edited occurrence',
    () {
      final value = plan(
        'FREQ=WEEKLY;BYDAY=MO;UNTIL=20261231T090000Z',
        DateTime.utc(2026, 6, 1, 9),
        DateTime.utc(2026, 6, 8, 9),
        DateTime.utc(2026, 6, 9, 10),
      );
      expect(value.rule.untilDateFor(timeZone: 'UTC'), '2026-12-31');
      expect(value.rule.count, isNull);
      expect(
        () => plan(
          'FREQ=WEEKLY;BYDAY=MO;UNTIL=20260608T090000Z',
          DateTime.utc(2026, 6, 1, 9),
          DateTime.utc(2026, 6, 8, 9),
          DateTime.utc(2026, 6, 9, 9),
        ),
        throwsA(isA<SeriesTimingDecisionRequired>()),
      );
    },
  );
  test('all-day and Vancouver DST keep civil recurrence positions', () {
    for (final allDay in [false, true]) {
      final value = plan(
        'FREQ=WEEKLY;BYDAY=MO;COUNT=3',
        DateTime.utc(2026, 3, 2, allDay ? 0 : 9),
        DateTime.utc(2026, 3, 9, allDay ? 0 : 9),
        DateTime.utc(2026, 3, 10, allDay ? 0 : 9),
        allDay: allDay,
        zone: allDay ? null : 'America/Vancouver',
      );
      expect(
        value.mapOccurrence(DateTime.utc(2026, 3, 16, allDay ? 0 : 9)),
        DateTime.utc(2026, 3, 17, allDay ? 0 : 9),
      );
    }
  });
  test(
    'time-only edits retain an accepted negative month-day rule verbatim',
    () {
      final value = plan(
        'FREQ=MONTHLY;BYMONTHDAY=-1;COUNT=3',
        DateTime.utc(2026, 1, 31, 9),
        DateTime.utc(2026, 2, 28, 9),
        DateTime.utc(2026, 2, 28, 11),
      );
      expect(value.rule.isSupported, isFalse);
      expect(value.encode(['RRULE:FREQ=MONTHLY;BYMONTHDAY=-1;COUNT=3']), [
        'RRULE:FREQ=MONTHLY;BYMONTHDAY=-1;COUNT=3',
      ]);
      expect(
        value.mapOccurrence(DateTime.utc(2026, 3, 31, 9)),
        DateTime.utc(2026, 3, 31, 11),
      );
    },
  );
  test(
    'multi-date monthly proposal maps selectors without swapping exceptions',
    () {
      final value = plan(
        'FREQ=MONTHLY;BYMONTHDAY=5,20;COUNT=6',
        DateTime.utc(2026, 1, 5, 9),
        DateTime.utc(2026, 2, 20, 9),
        DateTime.utc(2026, 2, 2, 9),
      );
      expect(value.requiresConfirmation, isTrue);
      expect(value.rule.byMonthDay, unorderedEquals([5, 2]));
      expect(
        value.mapOccurrence(DateTime.utc(2026, 3, 20, 9)),
        DateTime.utc(2026, 3, 2, 9),
      );
      expect(
        value.mapOccurrence(DateTime.utc(2026, 3, 5, 9)),
        DateTime.utc(2026, 3, 5, 9),
      );
    },
  );
  for (final exclusion in [
    'EXDATE:20260615T160000Z',
    'EXDATE;TZID=America/Vancouver:20260615T090000',
    'EXDATE;VALUE=DATE:20260615',
  ]) {
    test(
      'cancellation identity reanchors without flattening RDATE ($exclusion)',
      () {
        final allDay = exclusion.contains('VALUE=DATE');
        final value = plan(
          'FREQ=WEEKLY;BYDAY=MO;COUNT=5',
          DateTime.utc(2026, 6, 1, allDay ? 0 : 9),
          DateTime.utc(2026, 6, 8, allDay ? 0 : 9),
          DateTime.utc(2026, 6, 9, allDay ? 0 : 9),
          allDay: allDay,
          zone: allDay ? null : 'America/Vancouver',
        );
        const extra = 'RDATE;VALUE=PERIOD:20260705T160000Z/PT3H';
        final encoded = (value.encode([
          'RRULE:FREQ=WEEKLY;BYDAY=MO;COUNT=5',
          exclusion,
          extra,
        ]) as List).cast<String>();
        expect(encoded, contains(extra));
        final actual = encoded.singleWhere((line) => line.startsWith('EXDATE'));
        expect(
          actual,
          contains(
            allDay
                ? '20260616'
                : exclusion.contains('TZID')
                ? '20260616T090000'
                : '20260616T160000Z',
          ),
        );
        expect(actual.contains('TZID'), exclusion.contains('TZID'));
      },
    );
  }
}

List<DateTime> _expand(SeriesTimingChange plan, DateTime end) {
  String wire(DateTime value) => value
      .toIso8601String()
      .replaceAll(RegExp('[-:]'), '')
      .replaceAll('.000', '');
  final start = plan.masterStart;
  final document = IcalSemanticDocument.parse(
    'BEGIN:VCALENDAR\r\nVERSION:2.0\r\nBEGIN:VEVENT\r\nUID:fixture\r\n'
    'DTSTART:${wire(start)}\r\nDTEND:${wire(start.add(const Duration(hours: 1)))}\r\n'
    'RRULE:${plan.rule.toRrule()}\r\nEND:VEVENT\r\nEND:VCALENDAR\r\n',
  );
  return IcalRecurrenceExpander()
      .expand(
        document,
        rangeStartUtc: start.subtract(const Duration(days: 1)),
        rangeEndUtc: end,
      )
      .map((occurrence) => occurrence.start.localValue)
      .toList();
}

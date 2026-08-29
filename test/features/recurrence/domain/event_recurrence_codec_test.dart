import 'package:busymax/src/features/recurrence/domain/event_recurrence_codec.dart';
import 'package:busymax/src/features/recurrence/domain/recurrence_rule.dart';
import 'package:busymax/src/providers/busy_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RFC 5545 recurrence', () {
    test('round-trips an every-two-weeks weekday set with a count', () {
      final rule = EventRecurrenceCodec.decode(BusyProvider.google, const [
        'RRULE:FREQ=WEEKLY;INTERVAL=2;BYDAY=MO,WE,FR;WKST=MO;COUNT=12',
      ], baseDate: DateTime(2026, 6, 8, 9));

      expect(rule.isSupported, isTrue);
      expect(rule.frequency, RecurrenceFrequency.weekly);
      expect(rule.interval, 2);
      expect(rule.byDay, ['MO', 'WE', 'FR']);
      expect(rule.count, 12);
      expect(
        EventRecurrenceCodec.encode(
          BusyProvider.google,
          rule,
          baseDate: DateTime(2026, 6, 8, 9),
          allDay: false,
          timeZone: 'America/Vancouver',
        ),
        const ['RRULE:FREQ=WEEKLY;INTERVAL=2;BYDAY=MO,WE,FR;WKST=MO;COUNT=12'],
      );
    });

    test('round-trips the second Tuesday through a timed UNTIL', () {
      final rule = EventRecurrenceCodec.decode(BusyProvider.nextcloud, const {
        'rules': [
          'FREQ=MONTHLY;INTERVAL=1;BYDAY=TU;BYSETPOS=2;'
              'UNTIL=20261209T170000Z',
        ],
        'dates': <String>[],
        'excludedDates': <String>[],
      }, baseDate: DateTime(2026, 6, 9, 9));

      expect(rule.isSupported, isTrue);
      expect(rule.byDay, ['TU']);
      expect(rule.bySetPosition, 2);
      expect(rule.untilDateFor(timeZone: 'America/Vancouver'), '2026-12-09');
      expect(
        EventRecurrenceCodec.encode(
          BusyProvider.nextcloud,
          rule,
          baseDate: DateTime(2026, 6, 9, 9),
          allDay: false,
          timeZone: 'America/Vancouver',
        ),
        const {
          'rules': [
            'FREQ=MONTHLY;INTERVAL=1;BYDAY=TU;BYSETPOS=2;'
                'UNTIL=20261209T170000Z',
          ],
          'dates': <String>[],
          'excludedDates': <String>[],
        },
      );
    });

    test('keeps recurrence sets with exception dates opaque', () {
      final rule = EventRecurrenceCodec.decode(BusyProvider.google, const [
        'RRULE:FREQ=WEEKLY;BYDAY=MO',
        'EXDATE:20260615T160000Z',
      ], baseDate: DateTime(2026, 6, 8, 9));

      expect(rule.isSupported, isFalse);
      expect(rule.rawRules, ['FREQ=WEEKLY;BYDAY=MO']);
      expect(rule.exceptionDates, ['EXDATE:20260615T160000Z']);
    });
  });

  group('Microsoft Graph recurrence', () {
    test('maps a biweekly weekday set ending after occurrences', () {
      final rule = RecurrenceRule.fromIcalendar(
        rules: const ['FREQ=WEEKLY;INTERVAL=2;BYDAY=MO,WE,FR;WKST=MO;COUNT=9'],
        baseDate: DateTime(2026, 6, 8, 9),
      );

      expect(
        EventRecurrenceCodec.encode(
          BusyProvider.microsoft,
          rule,
          baseDate: DateTime(2026, 6, 8, 9),
          allDay: false,
          timeZone: 'Pacific Standard Time',
        ),
        const {
          'pattern': {
            'type': 'weekly',
            'interval': 2,
            'daysOfWeek': ['monday', 'wednesday', 'friday'],
            'firstDayOfWeek': 'monday',
          },
          'range': {
            'type': 'numbered',
            'startDate': '2026-06-08',
            'numberOfOccurrences': 9,
          },
        },
      );
    });

    test('maps the second Tuesday ending on a date', () {
      const recurrence = {
        'pattern': {
          'type': 'relativeMonthly',
          'interval': 1,
          'daysOfWeek': ['tuesday'],
          'index': 'second',
        },
        'range': {
          'type': 'endDate',
          'startDate': '2026-06-09',
          'endDate': '2026-12-31',
          'recurrenceTimeZone': 'Pacific Standard Time',
        },
      };
      final rule = EventRecurrenceCodec.decode(
        BusyProvider.microsoft,
        recurrence,
        baseDate: DateTime(2026, 6, 9, 9),
      );

      expect(rule.isSupported, isTrue);
      expect(rule.frequency, RecurrenceFrequency.monthly);
      expect(rule.byDay, ['TU']);
      expect(rule.bySetPosition, 2);
      expect(rule.untilDate, '2026-12-31');
      expect(
        EventRecurrenceCodec.encode(
          BusyProvider.microsoft,
          rule,
          baseDate: DateTime(2026, 6, 9, 9),
          allDay: false,
          timeZone: 'Pacific Standard Time',
          original: recurrence,
        ),
        recurrence,
      );
    });

    test('rejects RFC shapes Graph cannot represent', () {
      final fifthTuesday = RecurrenceRule.fromIcalendar(
        rules: const ['FREQ=MONTHLY;INTERVAL=1;BYDAY=TU;BYSETPOS=5'],
        baseDate: DateTime(2026, 6, 9),
      );
      final multipleMonthDays = RecurrenceRule.fromIcalendar(
        rules: const ['FREQ=MONTHLY;INTERVAL=1;BYMONTHDAY=1,15'],
        baseDate: DateTime(2026, 6, 1),
      );

      expect(
        EventRecurrenceCodec.canEncode(BusyProvider.microsoft, fifthTuesday),
        isFalse,
      );
      expect(
        EventRecurrenceCodec.canEncode(
          BusyProvider.microsoft,
          multipleMonthDays,
        ),
        isFalse,
      );
    });

    test('requires the documented Graph range and calendar values', () {
      const missingStartDate = {
        'pattern': {
          'type': 'weekly',
          'interval': 1,
          'daysOfWeek': ['monday'],
          'firstDayOfWeek': 'monday',
        },
        'range': {'type': 'noEnd'},
      };
      const invalidEndDate = {
        'pattern': {
          'type': 'weekly',
          'interval': 1,
          'daysOfWeek': ['monday'],
          'firstDayOfWeek': 'monday',
        },
        'range': {
          'type': 'endDate',
          'startDate': '2026-06-08',
          'endDate': '2026-02-31',
        },
      };
      const invalidMonth = RecurrenceRule(
        frequency: RecurrenceFrequency.yearly,
        interval: 1,
        byDay: [],
        byMonth: [13],
        byMonthDay: [1],
        bySetPosition: null,
        count: null,
        untilRaw: null,
        recurrenceDates: [],
        exceptionDates: [],
        rawRules: [],
        isSupported: true,
      );

      expect(
        EventRecurrenceCodec.decode(
          BusyProvider.microsoft,
          missingStartDate,
          baseDate: DateTime(2026, 6, 8),
        ).isSupported,
        isFalse,
      );
      expect(
        EventRecurrenceCodec.decode(
          BusyProvider.microsoft,
          invalidEndDate,
          baseDate: DateTime(2026, 6, 8),
        ).isSupported,
        isFalse,
      );
      expect(
        EventRecurrenceCodec.canEncode(BusyProvider.microsoft, invalidMonth),
        isFalse,
      );
    });
  });
}

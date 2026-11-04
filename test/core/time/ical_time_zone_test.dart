import 'dart:convert';

import 'package:busymax/src/core/time/ical_time_zone.dart';
import 'package:busymax/src/dav/ical/ical_semantics.dart';
import 'package:busymax/src/dav/ical/ical_timezone.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final zone in ['Africa/Cairo', 'America/Santiago']) {
    test(
      '$zone has a compact exact definition across Gregorian leap/century boundaries',
      () {
        final raw =
            'BEGIN:VCALENDAR\r\nVERSION:2.0\r\n'
            '${icalTimeZoneLines(zone, firstYear: 2025).join('\r\n')}\r\n'
            'BEGIN:VEVENT\r\nUID:zone-test\r\nDTSTART;TZID=$zone:20261102T090000\r\n'
            'END:VEVENT\r\nEND:VCALENDAR\r\n';
        expect(utf8.encode(raw).length, lessThan(16000));
        expect(raw, isNot(contains('RDATE:')));
        final resolver = IcalTimeZoneResolver.fromDocument(
          IcalSemanticDocument.parse(raw),
        );
        // Compare transitions on both sides of the tzdata continuation boundary,
        // including Cairo's occasional Oct 31 24:00 -> Nov 1 transition.
        for (final year in [
          2026,
          2030,
          2037,
          2038,
          2040,
          2044,
          2099,
          2100,
          2104,
          2200,
          2400,
        ]) {
          final transitions = zone == 'Africa/Cairo'
              ? [
                  _lastWeekday(
                    year,
                    4,
                    DateTime.friday,
                  ).subtract(const Duration(hours: 2)),
                  _lastWeekday(year, 10, DateTime.thursday)
                      .add(const Duration(days: 1))
                      .subtract(const Duration(hours: 3)),
                ]
              : [
                  _firstWeekday(
                    year,
                    4,
                    DateTime.saturday,
                  ).add(const Duration(days: 1, hours: 3)),
                  _firstWeekday(
                    year,
                    9,
                    DateTime.saturday,
                  ).add(const Duration(days: 1, hours: 4)),
                ];
          for (final instant in [
            DateTime.utc(year, 1, 15, 12),
            DateTime.utc(year, 7, 15, 12),
            for (final at in transitions) ...[
              at.subtract(const Duration(seconds: 1)),
              at,
              at.add(const Duration(hours: 2)),
            ],
          ]) {
            final expected = ianaWallFromInstant(instant, zone);
            final actual = resolver.fromUtc(instant, zone);
            expect(
              [
                actual.year,
                actual.month,
                actual.day,
                actual.hour,
                actual.minute,
                actual.second,
              ],
              [
                expected.year,
                expected.month,
                expected.day,
                expected.hour,
                expected.minute,
                expected.second,
              ],
              reason: '$zone $instant',
            );
          }
          final instant = DateTime.utc(year, 6, 15, 12);
          final wall = ianaWallFromInstant(instant, zone);
          expect(
            resolver.toUtc(
              IcalTemporalValue(
                rawValue: '',
                kind: IcalTemporalKind.tzidDateTime,
                localValue: wall,
                timeZoneId: zone,
              ),
            ),
            instant,
          );
        }
      },
    );
  }

  for (final zone in ['Asia/Gaza', 'Asia/Hebron', 'America/Nuuk']) {
    test('$zone shifted transition clocks remain exact', () {
      final raw =
          'BEGIN:VCALENDAR\r\nVERSION:2.0\r\n'
          '${icalTimeZoneLines(zone, firstYear: 2025).join('\r\n')}\r\n'
          'BEGIN:VEVENT\r\nUID:zone-test\r\nDTSTART;TZID=$zone:20261102T090000\r\n'
          'END:VEVENT\r\nEND:VCALENDAR\r\n';
      final resolver = IcalTimeZoneResolver.fromDocument(
        IcalSemanticDocument.parse(raw),
      );
      for (final year in [2038, 2044, 2100]) {
        for (var month = 1; month <= 12; month++) {
          final instant = DateTime.utc(year, month, 28, 22);
          final actual = resolver.fromUtc(instant, zone);
          final expected = ianaWallFromInstant(instant, zone);
          expect(
            [actual.month, actual.day, actual.hour],
            [expected.month, expected.day, expected.hour],
          );
        }
      }
    });
  }
}

DateTime _firstWeekday(int year, int month, int weekday) {
  final first = DateTime.utc(year, month);
  return first.add(Duration(days: (weekday - first.weekday) % 7));
}

DateTime _lastWeekday(int year, int month, int weekday) {
  final last = DateTime.utc(year, month + 1, 0);
  return last.subtract(Duration(days: (last.weekday - weekday) % 7));
}

import 'package:busymax/src/l10n/app_locale.dart';
import 'package:busymax/src/l10n/time_format_scope.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  setUpAll(() => initializeDateFormatting());

  test('explicit formats ignore system clock changes', () {
    for (final system in [false, true]) {
      for (final preference in BusyMaxTimeFormatPreference.values) {
        expect(
          resolveBusyMax24HourClock(preference, systemUses24Hour: system),
          switch (preference) {
            BusyMaxTimeFormatPreference.system => system,
            BusyMaxTimeFormatPreference.twelveHour => false,
            BusyMaxTimeFormatPreference.twentyFourHour => true,
          },
        );
      }
    }
  });

  test('all 1440 clock values convert and round trip in every app locale', () {
    for (final option in busyMaxLocaleOptions) {
      final locale = option.tag;
      for (final use24Hour in [false, true]) {
        final format = BusyMaxTimeFormatter(
          locale: locale,
          use24Hour: use24Hour,
        );
        for (var minute = 0; minute < 1440; minute++) {
          final hour = minute ~/ 60;
          expect(
            canonicalHour(twelveHourComponent(hour), isPm: hour >= 12),
            hour,
          );
          final text = format.formatClock(hour, minute % 60);
          expect(parseBusyMaxClockInput(text, locale), (
            hour: hour,
            minute: minute % 60,
          ), reason: '$locale / $use24Hour / $minute / $text');
        }
      }
    }
  });

  test('English labels and forced German twelve-hour labels', () {
    const examples = {
      0: ('12:00 AM', '00:00'),
      5: ('12:05 AM', '00:05'),
      545: ('9:05 AM', '09:05'),
      720: ('12:00 PM', '12:00'),
      870: ('2:30 PM', '14:30'),
      1439: ('11:59 PM', '23:59'),
    };
    for (final entry in examples.entries) {
      for (final locale in ['en', 'de']) {
        expect(
          BusyMaxTimeFormatter(
            locale: locale,
            use24Hour: false,
          ).formatClock(entry.key ~/ 60, entry.key % 60),
          entry.value.$1,
        );
        expect(
          BusyMaxTimeFormatter(
            locale: locale,
            use24Hour: true,
          ).formatClock(entry.key ~/ 60, entry.key % 60),
          entry.value.$2,
        );
      }
    }
    expect(
      const BusyMaxTimeFormatter(
        locale: 'ar',
        use24Hour: false,
      ).formatClock(14, 30),
      contains('م'),
    );
    expect(
      const BusyMaxTimeFormatter(
        locale: 'fa',
        use24Hour: false,
      ).formatClock(14, 30),
      contains('۲'),
    );
    expect(parseBusyMaxClockInput('٢:٣٠ م', 'ar'), (hour: 14, minute: 30));
    final japanese = const BusyMaxTimeFormatter(locale: 'ja', use24Hour: false);
    expect(
      japanese.formatClock(14, 30).startsWith(japanese.periodLabel(true)),
      isTrue,
    );
  });

  test('strict original AM/PM components, whitespace and English case', () {
    for (final locale in ['en', 'de', 'ar', 'ja']) {
      for (final input in [
        '00:30 AM',
        '13:30 AM',
        '13:30 PM',
        '12:60 PM',
        '12:00 PM rubbish',
        '12:00 AM PM',
        '24:00',
        '',
      ]) {
        expect(
          parseBusyMaxClockInput(input, locale),
          isNull,
          reason: '$locale $input',
        );
      }
      for (final space in [' ', '\u00a0', '\u202f']) {
        expect(parseBusyMaxClockInput('12:00${space}am', locale), (
          hour: 0,
          minute: 0,
        ));
        expect(parseBusyMaxClockInput('12:00${space}pM', locale), (
          hour: 12,
          minute: 0,
        ));
      }
      expect(parseBusyMaxClockInput('14:30', locale), (hour: 14, minute: 30));
      expect(parseBusyMaxClockInput('2:30', locale), (hour: 2, minute: 30));
      expect(parseBusyMaxClockInput('9:5', locale), (hour: 9, minute: 5));
    }
  });

  test(
    'end-of-day boundary is distinct and formatting never converts zones',
    () {
      const twelve = BusyMaxTimeFormatter(locale: 'en', use24Hour: false);
      const twentyFour = BusyMaxTimeFormatter(locale: 'en', use24Hour: true);
      expect(
        twelve.scheduleBoundary(1440, endOfDayLabel: 'end of day'),
        '12:00 AM (end of day)',
      );
      expect(
        twentyFour.scheduleBoundary(1440, endOfDayLabel: 'end of day'),
        '24:00',
      );
      expect(
        twelve.scheduleBoundary(0, endOfDayLabel: 'end of day'),
        '12:00 AM',
      );
      expect(() => twelve.formatClock(24, 0), throwsArgumentError);
      expect(twelve.format(DateTime.utc(2026, 9, 13, 14, 30)), '2:30 PM');
      expect(
        twelve.compose(
          'unchanged date',
          DateTime(2026, 9, 13, 14, 30),
          (date, time) => '$date · $time',
        ),
        'unchanged date · 2:30 PM',
      );
    },
  );

  testWidgets('hour 24 layout boundary is midnight; scaled RTL rulers fit', (
    tester,
  ) async {
    late double width;
    await tester.pumpWidget(
      Localizations(
        locale: const Locale('ar'),
        delegates: const [DefaultWidgetsLocalizations.delegate],
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: BusyMaxTimeFormatScope(
              formatter: const BusyMaxTimeFormatter(
                locale: 'ar',
                use24Hour: false,
              ),
              child: Builder(
                builder: (context) {
                  expect(
                    formatClockTime(
                      context,
                      const TimeOfDay(hour: 24, minute: 0),
                    ),
                    const BusyMaxTimeFormatter(
                      locale: 'ar',
                      use24Hour: false,
                    ).formatClock(0, 0),
                  );
                  width = clockRulerWidth(
                    context,
                    const TextStyle(fontSize: 14),
                  );
                  return const SizedBox();
                },
              ),
            ),
          ),
        ),
      ),
    );
    expect(width, greaterThan(64));
  });
}

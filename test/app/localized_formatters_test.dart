import 'package:busymax/src/l10n/localized_formatters.dart';
import 'package:busymax/src/schedule/schedule_range.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  test('month headings follow standalone CLDR casing by locale', () async {
    const expectedJuly = <String, String>{
      'ar': 'يوليو',
      'de': 'Juli',
      'en': 'July',
      'es': 'Julio',
      'et': 'juuli',
      'fa': 'ژوئیه',
      'fi': 'heinäkuu',
      'fr': 'Juillet',
      'hi': 'जुलाई',
      'it': 'Luglio',
      'ja': '7月',
      'ko': '7월',
      'pt': 'julho',
      'ru': 'Июль',
      'vi': 'Tháng 7',
      'zh': '七月',
    };

    for (final entry in expectedJuly.entries) {
      await initializeDateFormatting(entry.key);
      expect(
        localizedMonthHeading(entry.key, DateTime(2026, 7)),
        entry.value,
        reason: entry.key,
      );
    }
  });

  test('schedule ranges localize each complete endpoint', () async {
    await initializeDateFormatting('de');
    final range = ScheduleRange(
      start: DateTime(2026, 7, 27),
      end: DateTime(2026, 8, 3),
    );

    expect(
      localizedScheduleRangeLabel('en', range),
      'Jul 27, 2026 – Aug 2, 2026',
    );
    expect(
      localizedScheduleRangeLabel('de', range),
      '27. Juli 2026 – 2. Aug. 2026',
    );
  });
}

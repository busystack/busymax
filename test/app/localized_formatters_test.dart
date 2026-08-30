import 'dart:io';

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

  test(
    'full day headings use heading context without global capitalization',
    () async {
      const expected = <String, String>{
        'ar': 'الاثنين، 7 سبتمبر 2026',
        'de': 'Montag, 7. September 2026',
        'en': 'Monday, September 7, 2026',
        'es': 'Lunes, 7 de septiembre de 2026',
        'et': 'esmaspäev, 7. september 2026',
        'fa': 'دوشنبه ۷ سپتامبر ۲۰۲۶',
        'fi': 'maanantai 7. syyskuuta 2026',
        'fr': 'Lundi 7 septembre 2026',
        'hi': 'सोमवार, 7 सितंबर 2026',
        'it': 'Lunedì 7 settembre 2026',
        'ja': '2026年9月7日月曜日',
        'ko': '2026년 9월 7일 월요일',
        'pt': 'Segunda-feira, 7 de setembro de 2026',
        'ru': 'Понедельник, 7 сентября 2026 г.',
        'vi': 'Thứ Hai, 7 tháng 9, 2026',
        'zh': '2026年9月7日星期一',
        'zh_Hans': '2026年9月7日星期一',
        'zh_Hant': '2026年9月7日星期一',
      };

      for (final entry in expected.entries) {
        await initializeDateFormatting(entry.key);
        expect(
          localizedDayHeading(entry.key, DateTime(2026, 9, 7)),
          entry.value,
          reason: entry.key,
        );
      }
    },
  );

  test('month-year headings use standalone month context', () async {
    const expected = <String, String>{
      'ar': 'سبتمبر 2026',
      'de': 'September 2026',
      'en': 'September 2026',
      'es': 'Septiembre de 2026',
      'et': 'september 2026',
      'fa': 'سپتامبر ۲۰۲۶',
      'fi': 'syyskuu 2026',
      'fr': 'Septembre 2026',
      'hi': 'सितंबर 2026',
      'it': 'Settembre 2026',
      'ja': '2026年9月',
      'ko': '2026년 9월',
      'pt': 'setembro de 2026',
      'ru': 'Сентябрь 2026 г.',
      'vi': 'tháng 9 năm 2026',
      'zh': '2026年9月',
      'zh_Hans': '2026年9月',
      'zh_Hant': '2026年9月',
    };

    for (final entry in expected.entries) {
      await initializeDateFormatting(entry.key);
      expect(
        localizedMonthYearHeading(entry.key, DateTime(2026, 9)),
        entry.value,
        reason: entry.key,
      );
    }
  });

  test(
    'standalone weekday and month labels use their own grammatical forms',
    () async {
      const expectedWeekdays = <String, (String, String)>{
        'ar': ('الاثنين', 'الاثنين'),
        'de': ('Montag', 'Mo'),
        'en': ('Monday', 'Mon'),
        'es': ('Lunes', 'Lun'),
        'et': ('esmaspäev', 'E'),
        'fa': ('دوشنبه', 'دوشنبه'),
        'fi': ('maanantai', 'ma'),
        'fr': ('Lundi', 'Lun.'),
        'hi': ('सोमवार', 'सोम'),
        'it': ('Lunedì', 'Lun'),
        'ja': ('月曜日', '月'),
        'ko': ('월요일', '월'),
        'pt': ('Segunda-feira', 'Seg.'),
        'ru': ('Понедельник', 'Пн'),
        'vi': ('Thứ Hai', 'Th 2'),
        'zh': ('星期一', '周一'),
        'zh_Hans': ('星期一', '周一'),
        'zh_Hant': ('星期一', '周一'),
      };
      const expectedMonths = <String, (String, String)>{
        'ar': ('سبتمبر', 'سبتمبر'),
        'de': ('September', 'Sep'),
        'en': ('September', 'Sep'),
        'es': ('Septiembre', 'Sept'),
        'et': ('september', 'september'),
        'fa': ('سپتامبر', 'سپتامبر'),
        'fi': ('syyskuu', 'syys'),
        'fr': ('Septembre', 'Sept.'),
        'hi': ('सितंबर', 'सित॰'),
        'it': ('Settembre', 'Set'),
        'ja': ('9月', '9月'),
        'ko': ('9월', '9월'),
        'pt': ('setembro', 'set.'),
        'ru': ('Сентябрь', 'Сент.'),
        'vi': ('Tháng 9', 'Tháng 9'),
        'zh': ('九月', '9月'),
        'zh_Hans': ('九月', '9月'),
        'zh_Hant': ('九月', '9月'),
      };

      for (final locale in expectedWeekdays.keys) {
        await initializeDateFormatting(locale);
        final weekday = expectedWeekdays[locale]!;
        final month = expectedMonths[locale]!;
        expect(
          localizedWeekdayLabel(locale, DateTime(2026, 9, 7)),
          weekday.$1,
          reason: '$locale full weekday',
        );
        expect(
          localizedWeekdayLabel(
            locale,
            DateTime(2026, 9, 7),
            abbreviated: true,
          ),
          weekday.$2,
          reason: '$locale abbreviated weekday',
        );
        expect(
          localizedMonthLabel(locale, DateTime(2026, 9)),
          month.$1,
          reason: '$locale full month',
        );
        expect(
          localizedMonthLabel(locale, DateTime(2026, 9), abbreviated: true),
          month.$2,
          reason: '$locale abbreviated month',
        );
      }
    },
  );

  test(
    'inline date names stay lowercase where locale data requires it',
    () async {
      for (final locale in ['es', 'fr', 'it', 'pt', 'ru', 'fi', 'et']) {
        await initializeDateFormatting(locale);
        final date = DateTime(2026, 9, 7);
        expect(
          localizedInlineWeekday(locale, date),
          isNot(contains(RegExp(r'^[A-ZÁÉÍÓÚÀÂÄÇÈÉÊËÎÏÔÖÙÛÜŸ]'))),
          reason: '$locale inline weekday',
        );
        expect(
          localizedInlineMonth(locale, date),
          isNot(contains(RegExp(r'^[A-ZÁÉÍÓÚÀÂÄÇÈÉÊËÎÏÔÖÙÛÜŸ]'))),
          reason: '$locale inline month',
        );
      }
    },
  );

  test('calendar heading widgets do not call DateFormat directly', () {
    const files = [
      'lib/src/features/schedule/presentation/schedule_toolbar.dart',
      'lib/src/features/schedule/presentation/schedule_workspace.dart',
      'lib/src/features/schedule/presentation/schedule_agenda_view.dart',
      'lib/src/features/schedule/presentation/schedule_more_popover.dart',
      'lib/src/features/schedule/presentation/calendar_day_semantics.dart',
      'lib/src/features/schedule/presentation/mini_calendar.dart',
      'lib/src/features/schedule/presentation/schedule_month_view.dart',
      'lib/src/features/schedule/presentation/schedule_day_week_view.dart',
      'lib/src/features/tasks/presentation/desktop_date_time_fields.dart',
    ];
    final forbidden = RegExp(r'DateFormat\.(?:yMMMMEEEEd|yMMMM|E|MMMM)\b');

    for (final path in files) {
      final source = File(path).readAsStringSync();
      expect(
        source,
        isNot(contains(forbidden)),
        reason: '$path must use localized_formatters.dart',
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

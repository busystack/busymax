import 'dart:convert';
import 'dart:io';

import 'package:busymax/l10n/generated/app_localizations.dart';
import 'package:busymax/l10n/generated/app_localizations_ar.dart';
import 'package:busymax/l10n/generated/app_localizations_fa.dart';
import 'package:busymax/src/l10n/app_locale.dart';
import 'package:busymax/src/features/recurrence/domain/recurrence_rule.dart';
import 'package:busymax/src/features/recurrence/presentation/recurrence_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('localized UI surfaces do not hardcode user-facing text', () {
    final failures = <String>[];

    for (final file in _productionUiDartFiles()) {
      final source = file.readAsStringSync();
      for (final pattern in _userFacingLiteralPatterns) {
        for (final match in pattern.allMatches(source)) {
          final literal = match.group(1)!;
          if (_isTechnicalLiteral(literal)) {
            continue;
          }
          failures.add(
            '${file.path}:${_lineForOffset(source, match.start)}: $literal',
          );
        }
      }
    }

    expect(failures, isEmpty, reason: failures.join('\n'));
  });

  test('translated ARB catalogs match the English template', () {
    final templateFile = File('lib/l10n/app_en.arb');
    final templateArb = _decodeArb(templateFile);
    final templateMessages = _messages(templateArb);
    const allowedEmptyTranslationKeys = {'repeatSummarySeparator'};
    final failures = <String>[];

    for (final file in _translatedArbFiles()) {
      final path = file.path;
      final messages = _messages(_decodeArb(file));
      final templateKeys = templateMessages.keys.toSet();
      final translatedKeys = messages.keys.toSet();

      for (final key
          in templateKeys.difference(translatedKeys).toList()..sort()) {
        failures.add('$path: missing message $key');
      }
      for (final key
          in translatedKeys.difference(templateKeys).toList()..sort()) {
        failures.add('$path: unexpected message $key');
      }
      for (final key in templateKeys.intersection(translatedKeys)) {
        final translation = messages[key]!;
        if (translation.trim().isEmpty &&
            !allowedEmptyTranslationKeys.contains(key)) {
          failures.add('$path: $key has an empty translation');
        }
        final declaredPlaceholders = _declaredPlaceholders(
          templateArb,
          key,
        ).toSet();
        for (final placeholder in declaredPlaceholders) {
          if (!translation.contains('{$placeholder')) {
            failures.add('$path: $key does not use {$placeholder}');
          }
        }
        for (final placeholder in _usedPlaceholders(translation)) {
          if (!declaredPlaceholders.contains(placeholder)) {
            failures.add('$path: $key adds {$placeholder}');
          }
        }
      }
    }

    expect(failures, isEmpty, reason: failures.join('\n'));
  });

  test('translated ARB catalogs do not silently copy English messages', () {
    final template = _decodeArb(File('lib/l10n/app_en.arb'));
    final templateMessages = _messages(template);
    const allowedIdenticalKeys = {
      'appTitle',
      'apacheLicenseName',
      'dateTimeDisplay',
      'etag',
      'formatBoldShortLabel',
      'formatItalicShortLabel',
      'formatUnderlineShortLabel',
      'googleProvider',
      'googleTasksApi',
      'googleTasksProvider',
      'id',
      'microsoftProvider',
      'microsoftTodoProvider',
      'nextcloudProvider',
      'appleICloudTasksProvider',
      'taskUrl',
      'repeatSummarySeparator',
      'repeatMonthDayValue',
      'repeatMonthDayListSeparator',
      'repeatYearlyMonthDayListStart',
      'repeatYearlyMonthListStart',
      'repeatYearlyMonthValue',
      'settingsSystem',
    };
    final failures = <String>[];

    for (final file in _translatedArbFiles()) {
      final messages = _messages(_decodeArb(file));
      for (final key in templateMessages.keys) {
        if (allowedIdenticalKeys.contains(key)) continue;
        if (messages[key] == templateMessages[key]) {
          failures.add('${file.path}: $key copies the English value');
        }
      }
    }

    expect(failures, isEmpty, reason: failures.join('\n'));
  });

  test('discard-changes action is distinct from cancel in every locale', () {
    for (final locale in AppLocalizations.supportedLocales) {
      final localizations = lookupAppLocalizations(locale);
      expect(
        localizations.discardChangesAction,
        isNot(localizations.cancel),
        reason:
            '${locale.toLanguageTag()} must not translate Discard as Cancel',
      );
    }

    expect(
      lookupAppLocalizations(const Locale('ru')).discardChangesAction,
      'Не сохранять',
    );
    expect(
      lookupAppLocalizations(const Locale('ru')).discardChanges,
      'Не сохранять изменения?',
    );
    expect(
      lookupAppLocalizations(const Locale('ru')).discardChangesConfirmation,
      'Несохранённые изменения этой задачи будут потеряны.',
    );
    expect(
      lookupAppLocalizations(const Locale('vi')).discardChangesAction,
      'Không lưu',
    );
  });

  test('Linux package metadata matches every translated catalog', () {
    final failures = _metadataTranslationFailures().toList();

    expect(failures, isEmpty, reason: failures.join('\n'));
  });

  test('Finnish is generated and exposed as a supported locale', () {
    const locale = Locale('fi');
    final localizations = lookupAppLocalizations(locale);

    expect(AppLocalizations.supportedLocales, contains(locale));
    expect(localizations.settings, 'Asetukset');
    expect(localizations.today, 'Tänään');
  });

  test('Estonian is generated and exposed as a supported locale', () {
    const locale = Locale('et');
    final localizations = lookupAppLocalizations(locale);

    expect(AppLocalizations.supportedLocales, contains(locale));
    expect(localizations.settings, 'Seaded');
    expect(localizations.today, 'Täna');
  });

  test('Russian is generated and exposed as a supported locale', () {
    const locale = Locale('ru');
    final localizations = lookupAppLocalizations(locale);

    expect(AppLocalizations.supportedLocales, contains(locale));
    expect(localizations.settings, 'Настройки');
    expect(localizations.today, 'Сегодня');
    expect(localizations.viewAgenda, 'Расписание');
    expect(localizations.currentLocale, 'Язык приложения');
  });

  test('package metadata uses reviewed product wording in every locale', () {
    final desktop = File(
      'linux/io.busystack.busymax.desktop',
    ).readAsStringSync();
    final metainfo = File(
      'linux/io.busystack.busymax.metainfo.xml',
    ).readAsStringSync();

    const summaries = <String, String>{
      'ar': 'مدير التقويم والمهام',
      'de': 'Kalender- und Aufgabenverwaltung',
      'es': 'Gestor de calendarios y tareas',
      'et': 'Kalendri- ja ülesannete haldur',
      'fa': 'مدیر تقویم و کارها',
      'fi': 'Kalenteri- ja tehtäväsovellus',
      'fr': 'Gestionnaire de calendriers et de tâches',
      'hi': 'कैलेंडर और कार्य प्रबंधक',
      'it': 'Gestore di calendari e attività',
      'ja': 'カレンダー・タスク管理アプリ',
      'ko': '캘린더와 할 일 관리',
      'pt': 'Gestor de calendário e tarefas',
      'ru': 'Календарь и планировщик задач',
      'vi': 'Trình quản lý lịch và công việc',
      'zh': '日历与任务管理工具',
      'zh_Hans': '日历与任务管理工具',
      'zh_Hant': '行事曆與待辦事項管理工具',
    };

    for (final entry in summaries.entries) {
      expect(
        desktop,
        contains('Comment[${entry.key}]=${entry.value}'),
        reason: 'desktop ${entry.key}',
      );
      final appStreamLocale = entry.key.replaceAll('_', '-');
      expect(
        metainfo,
        contains(
          '<summary xml:lang="$appStreamLocale">${entry.value}</summary>',
        ),
        reason: 'AppStream ${entry.key}',
      );
    }
    expect(
      '$desktop\n$metainfo',
      isNot(contains('Менеджер календаря и задач')),
    );
  });

  test('Portuguese is generated and exposed as a supported locale', () {
    const locale = Locale('pt');
    final localizations = lookupAppLocalizations(locale);

    expect(AppLocalizations.supportedLocales, contains(locale));
    expect(localizations.settings, 'Definições');
    expect(localizations.today, 'Hoje');
  });

  test(
    'reviewed Arabic conflict wording and Portuguese variant stay stable',
    () {
      final arabic = AppLocalizationsAr();
      expect(
        arabic.remoteChangedAt('14:30'),
        contains('تم التغيير على الخادم في:'),
      );

      final portuguese = lookupAppLocalizations(const Locale('pt'));
      expect(portuguese.settings, 'Definições');
      expect(portuguese.deleteTask, 'Eliminar tarefa');
      expect(portuguese.copyAndDelete, 'Copiar e eliminar');

      final portugueseArb = File(
        'lib/l10n/app_pt.arb',
      ).readAsStringSync().toLowerCase();
      for (final brazilianForm in [
        'excluído',
        'excluir',
        'compartilhada',
        'somente',
        'ele aparecerá',
      ]) {
        expect(
          portugueseArb,
          isNot(contains(brazilianForm)),
          reason: 'pt-PT must not reintroduce $brazilianForm',
        );
      }
    },
  );

  test('Hindi is generated and exposed as a supported locale', () {
    const locale = Locale('hi');
    final localizations = lookupAppLocalizations(locale);

    expect(AppLocalizations.supportedLocales, contains(locale));
    expect(localizations.settings, 'सेटिंग्स');
    expect(localizations.today, 'आज');
  });

  test('Italian is generated and exposed as a supported locale', () {
    const locale = Locale('it');
    final localizations = lookupAppLocalizations(locale);

    expect(AppLocalizations.supportedLocales, contains(locale));
    expect(localizations.settings, 'Impostazioni');
    expect(localizations.today, 'Oggi');
  });

  test('Japanese is generated and exposed as a supported locale', () {
    const locale = Locale('ja');
    final localizations = lookupAppLocalizations(locale);

    expect(AppLocalizations.supportedLocales, contains(locale));
    expect(localizations.settings, '設定');
    expect(localizations.today, '今日');
  });

  test('Korean is generated and exposed as a supported locale', () {
    const locale = Locale('ko');
    final localizations = lookupAppLocalizations(locale);

    expect(AppLocalizations.supportedLocales, contains(locale));
    expect(localizations.settings, '설정');
    expect(localizations.today, '오늘');
  });

  test('Vietnamese is generated and exposed as a supported locale', () {
    const locale = Locale('vi');
    final localizations = lookupAppLocalizations(locale);

    expect(AppLocalizations.supportedLocales, contains(locale));
    expect(localizations.settings, 'Cài đặt');
    expect(localizations.today, 'Hôm nay');
  });

  test('Arabic is generated and exposed as a supported locale', () {
    const locale = Locale('ar');
    final localizations = lookupAppLocalizations(locale);

    expect(AppLocalizations.supportedLocales, contains(locale));
    expect(localizations.settings, 'الإعدادات');
    expect(localizations.today, 'اليوم');
  });

  testWidgets('Arabic locale renders right to left', (tester) async {
    TextDirection? direction;

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ar'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) {
            direction = Directionality.of(context);
            return const SizedBox();
          },
        ),
      ),
    );

    expect(direction, TextDirection.rtl);
  });

  test('Persian is generated and exposed as a supported locale', () {
    const locale = Locale('fa');
    final localizations = lookupAppLocalizations(locale);

    expect(AppLocalizations.supportedLocales, contains(locale));
    expect(localizations.settings, 'تنظیمات');
    expect(localizations.today, 'امروز');
    expect(
      localizations.dueTodayNotificationBody(0),
      'امروز هیچ کاری سررسید ندارد.',
    );
  });

  testWidgets('Persian locale renders right to left', (tester) async {
    TextDirection? direction;

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('fa'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) {
            direction = Directionality.of(context);
            return const SizedBox();
          },
        ),
      ),
    );

    expect(direction, TextDirection.rtl);
  });

  test('RTL translations isolate dynamic content', () {
    const fsi = '\u2068';
    const pdi = '\u2069';
    final localizations = <AppLocalizations>[
      AppLocalizationsAr(),
      AppLocalizationsFa(),
    ];

    for (final l10n in localizations) {
      expect(
        l10n.exportedFile('exports/schedule-v2.ics'),
        contains('${fsi}exports/schedule-v2.ics$pdi'),
      );
      expect(l10n.feedbackSuccess('BM-12345'), contains('${fsi}BM-12345$pdi'));
      expect(
        l10n.dateTimeDisplay('2026-07-29', '14:30'),
        allOf(contains('${fsi}2026-07-29$pdi'), contains('${fsi}14:30$pdi')),
      );
    }
  });

  test(
    'RTL translations isolate dynamic values in confirmations and conflicts',
    () {
      const fsi = '\u2068';
      const pdi = '\u2069';
      final localizedValues = <AppLocalizations>[
        AppLocalizationsAr(),
        AppLocalizationsFa(),
      ];

      for (final l10n in localizedValues) {
        expect(
          l10n.removeAccountTitle('Acme (EU)'),
          contains('${fsi}Acme (EU)$pdi'),
        );
        expect(
          l10n.deleteListConfirmation('Inbox / 2026'),
          contains('${fsi}Inbox / 2026$pdi'),
        );
        expect(
          l10n.conflictNotificationBody('Meeting — 東京'),
          contains('${fsi}Meeting — 東京$pdi'),
        );
      }
    },
  );

  testWidgets('recurrence summaries use sentence-form localized grammar', (
    tester,
  ) async {
    const ordinalRule = RecurrenceRule(
      frequency: RecurrenceFrequency.monthly,
      interval: 1,
      byDay: ['MO'],
      byMonth: [],
      byMonthDay: [],
      bySetPosition: 1,
      count: null,
      untilRaw: null,
      recurrenceDates: [],
      exceptionDates: [],
      rawRules: [],
      isSupported: true,
    );
    const monthDaysRule = RecurrenceRule(
      frequency: RecurrenceFrequency.monthly,
      interval: 1,
      byDay: [],
      byMonth: [],
      byMonthDay: [1, 15],
      bySetPosition: null,
      count: null,
      untilRaw: null,
      recurrenceDates: [],
      exceptionDates: [],
      rawRules: [],
      isSupported: true,
    );
    const singleMonthDayRule = RecurrenceRule(
      frequency: RecurrenceFrequency.monthly,
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
    const yearlyMonthDayRule = RecurrenceRule(
      frequency: RecurrenceFrequency.yearly,
      interval: 1,
      byDay: [],
      byMonth: [9],
      byMonthDay: [15],
      bySetPosition: null,
      count: null,
      untilRaw: null,
      recurrenceDates: [],
      exceptionDates: [],
      rawRules: [],
      isSupported: true,
    );
    const yearlyOrdinalRule = RecurrenceRule(
      frequency: RecurrenceFrequency.yearly,
      interval: 1,
      byDay: ['MO'],
      byMonth: [9],
      byMonthDay: [],
      bySetPosition: 1,
      count: null,
      untilRaw: null,
      recurrenceDates: [],
      exceptionDates: [],
      rawRules: [],
      isSupported: true,
    );
    const yearlyMonthDaysRule = RecurrenceRule(
      frequency: RecurrenceFrequency.yearly,
      interval: 1,
      byDay: [],
      byMonth: [9],
      byMonthDay: [1, 15],
      bySetPosition: null,
      count: null,
      untilRaw: null,
      recurrenceDates: [],
      exceptionDates: [],
      rawRules: [],
      isSupported: true,
    );
    const yearlyMonthsMonthDayRule = RecurrenceRule(
      frequency: RecurrenceFrequency.yearly,
      interval: 1,
      byDay: [],
      byMonth: [9, 10],
      byMonthDay: [15],
      bySetPosition: null,
      count: null,
      untilRaw: null,
      recurrenceDates: [],
      exceptionDates: [],
      rawRules: [],
      isSupported: true,
    );
    const yearlyMonthsMonthDaysRule = RecurrenceRule(
      frequency: RecurrenceFrequency.yearly,
      interval: 1,
      byDay: [],
      byMonth: [9, 10],
      byMonthDay: [1, 15],
      bySetPosition: null,
      count: null,
      untilRaw: null,
      recurrenceDates: [],
      exceptionDates: [],
      rawRules: [],
      isSupported: true,
    );
    const yearlyMonthsOrdinalRule = RecurrenceRule(
      frequency: RecurrenceFrequency.yearly,
      interval: 1,
      byDay: ['MO'],
      byMonth: [9, 10],
      byMonthDay: [],
      bySetPosition: 1,
      count: null,
      untilRaw: null,
      recurrenceDates: [],
      exceptionDates: [],
      rawRules: [],
      isSupported: true,
    );
    const yearlyThreeMonthsAndDaysRule = RecurrenceRule(
      frequency: RecurrenceFrequency.yearly,
      interval: 1,
      byDay: [],
      byMonth: [8, 9, 10],
      byMonthDay: [1, 15, 20],
      bySetPosition: null,
      count: null,
      untilRaw: null,
      recurrenceDates: [],
      exceptionDates: [],
      rawRules: [],
      isSupported: true,
    );
    const yearlyMonthsOnlyRule = RecurrenceRule(
      frequency: RecurrenceFrequency.yearly,
      interval: 1,
      byDay: [],
      byMonth: [9, 10],
      byMonthDay: [],
      bySetPosition: null,
      count: null,
      untilRaw: null,
      recurrenceDates: [],
      exceptionDates: [],
      rawRules: [],
      isSupported: true,
    );

    Future<String> summary(Locale locale, RecurrenceRule rule) async {
      var value = '';
      await tester.pumpWidget(
        MaterialApp(
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) {
              value = recurrenceRuleSummary(context, rule);
              return const SizedBox();
            },
          ),
        ),
      );
      return value;
    }

    const expectedYearlySummaries = <String, List<String>>{
      'ar': [
        'سنويًا في يوم 15 من سبتمبر',
        'سنويًا في الأيام 1 و15 من سبتمبر',
        'سنويًا في يوم 15 من أشهر سبتمبر وأكتوبر',
        'سنويًا في الأيام 1 و15 من أشهر سبتمبر وأكتوبر',
        'سنويًا في أول يوم الاثنين من سبتمبر',
        'سنويًا في أول يوم الاثنين من أشهر سبتمبر وأكتوبر',
      ],
      'de': [
        'Jährlich am 15. Sept.',
        'Jährlich an den Tagen 1 und 15 im Sept.',
        'Jährlich jeweils am 15. in Sept. und Okt.',
        'Jährlich jeweils an den Tagen 1 und 15 in Sept. und Okt.',
        'Jährlich am ersten Montag im Sept.',
        'Jährlich jeweils am ersten Montag in Sept. und Okt.',
      ],
      'en': [
        'Yearly on Sep 15',
        'Yearly on days 1 and 15 of Sep',
        'Yearly on day 15 of Sep and Oct',
        'Yearly on days 1 and 15 of Sep and Oct',
        'Yearly on the first Monday of Sep',
        'Yearly on the first Monday of Sep and Oct',
      ],
      'es': [
        'Anual el día 15 de sept',
        'Anual los días 1 y 15 de sept',
        'Anual el día 15 de sept y oct',
        'Anual los días 1 y 15 de sept y oct',
        'Anual el primer lunes de sept',
        'Anual el primer lunes de sept y oct',
      ],
      'et': [
        'Iga aasta septembris 15. päeval',
        'Iga aasta septembris 1. ja 15. päeval',
        'Iga aasta septembris ja oktoobris 15. päeval',
        'Iga aasta septembris ja oktoobris 1. ja 15. päeval',
        'Iga aasta septembris: esimene esmaspäev',
        'Iga aasta septembris ja oktoobris: esimene esmaspäev',
      ],
      'fa': [
        'سالانه در روز ۱۵ ماه سپتامبر',
        'سالانه در روزهای ۱ و ۱۵ ماه سپتامبر',
        'سالانه در روز ۱۵ ماه‌های سپتامبر و اکتبر',
        'سالانه در روزهای ۱ و ۱۵ ماه‌های سپتامبر و اکتبر',
        'سالانه در اولین دوشنبه ماه سپتامبر',
        'سالانه در اولین دوشنبه ماه‌های سپتامبر و اکتبر',
      ],
      'fi': [
        'Vuosittain syyskuun 15. päivänä',
        'Vuosittain syyskuun päivinä 1 ja 15',
        'Vuosittain syyskuun ja lokakuun 15. päivänä',
        'Vuosittain syyskuun ja lokakuun päivinä 1 ja 15',
        'Vuosittain syyskuun ensimmäisenä maanantaina',
        'Vuosittain syyskuun ja lokakuun ensimmäisenä maanantaina',
      ],
      'fr': [
        'Annuel le 15 sept.',
        'Annuel les jours 1 et 15 de sept.',
        'Annuel le 15 de sept. et oct.',
        'Annuel les jours 1 et 15 de sept. et oct.',
        'Annuel le premier lundi de sept.',
        'Annuel le premier lundi de sept. et oct.',
      ],
      'hi': [
        'हर वर्ष सित॰ की 15 तारीख को',
        'हर वर्ष सित॰ की 1 और 15 तारीखों को',
        'हर वर्ष सित॰ और अक्तू॰ की 15 तारीख को',
        'हर वर्ष सित॰ और अक्तू॰ की 1 और 15 तारीखों को',
        'हर वर्ष सित॰ के पहले सोमवार को',
        'हर वर्ष सित॰ और अक्तू॰ के पहले सोमवार को',
      ],
      'it': [
        'Ogni anno il giorno 15 di set',
        'Ogni anno nei giorni 1 e 15 di set',
        'Ogni anno il giorno 15 di set e ott',
        'Ogni anno nei giorni 1 e 15 di set e ott',
        'Ogni anno il primo lunedì di set',
        'Ogni anno il primo lunedì di set e ott',
      ],
      'ja': [
        '毎年9月15日',
        '毎年9月の1日と15日',
        '毎年9月と10月の15日',
        '毎年9月と10月の1日と15日',
        '毎年9月の第1月曜日',
        '毎年9月と10月の第1月曜日',
      ],
      'ko': [
        '매년 9월 15일',
        '매년 9월의 1일과 15일',
        '매년 9월과 10월의 15일',
        '매년 9월과 10월의 1일과 15일',
        '매년 9월의 첫 번째 월요일',
        '매년 9월과 10월의 첫 번째 월요일',
      ],
      'pt': [
        'Anualmente no dia 15 de set.',
        'Anualmente nos dias 1 e 15 de set.',
        'Anualmente no dia 15 de set. e out.',
        'Anualmente nos dias 1 e 15 de set. e out.',
        'Anualmente na primeira ocorrência de segunda-feira de set.',
        'Anualmente na primeira ocorrência de segunda-feira de set. e out.',
      ],
      'ru': [
        'Ежегодно: сент., 15-го числа',
        'Ежегодно: сент., 1-го и 15-го числа',
        'Ежегодно: сент. и окт., 15-го числа',
        'Ежегодно: сент. и окт., 1-го и 15-го числа',
        'Ежегодно: сент., в первый понедельник',
        'Ежегодно: сент. и окт., в первый понедельник',
      ],
      'vi': [
        'Hằng năm vào ngày 15 thg 9',
        'Hằng năm vào các ngày 1 và 15 của thg 9',
        'Hằng năm vào ngày 15 của thg 9 và thg 10',
        'Hằng năm vào các ngày 1 và 15 của thg 9 và thg 10',
        'Hằng năm vào Thứ Hai đầu tiên của thg 9',
        'Hằng năm vào Thứ Hai đầu tiên của thg 9 và thg 10',
      ],
      'zh': [
        '每年9月15日',
        '每年9月的1日和15日',
        '每年9月和10月的15日',
        '每年9月和10月的1日和15日',
        '每年9月的第一个星期一',
        '每年9月和10月的第一个星期一',
      ],
      'zh-Hans': [
        '每年9月15日',
        '每年9月的1日和15日',
        '每年9月和10月的15日',
        '每年9月和10月的1日和15日',
        '每年9月的第一个星期一',
        '每年9月和10月的第一个星期一',
      ],
      'zh-Hant': [
        '每年9月15日',
        '每年9月的1日和15日',
        '每年9月和10月的15日',
        '每年9月和10月的1日和15日',
        '每年9月的第一個星期一',
        '每年9月和10月的第一個星期一',
      ],
    };

    for (final locale in AppLocalizations.supportedLocales) {
      final values = <String>[
        await summary(locale, yearlyMonthDayRule),
        await summary(locale, yearlyMonthDaysRule),
        await summary(locale, yearlyMonthsMonthDayRule),
        await summary(locale, yearlyMonthsMonthDaysRule),
        await summary(locale, yearlyOrdinalRule),
        await summary(locale, yearlyMonthsOrdinalRule),
      ];
      expect(
        values,
        expectedYearlySummaries[locale.toLanguageTag()],
        reason: locale.toLanguageTag(),
      );
    }
    expect(
      await summary(const Locale('en'), yearlyThreeMonthsAndDaysRule),
      'Yearly on days 1, 15 and 20 of Aug, Sep and Oct',
    );
    expect(
      await summary(const Locale('ja'), yearlyThreeMonthsAndDaysRule),
      '毎年8月、9月と10月の1日、15日と20日',
    );
    expect(
      await summary(const Locale('en'), yearlyMonthsOnlyRule),
      'Yearly in Sep and Oct',
    );
    expect(
      await summary(const Locale('et'), yearlyMonthsOnlyRule),
      'Iga aasta septembris ja oktoobris',
    );
    expect(
      await summary(const Locale('fi'), yearlyMonthsOnlyRule),
      'Vuosittain syyskuun ja lokakuun aikana',
    );

    expect(
      await summary(const Locale('de'), ordinalRule),
      'Monatlich am ersten Montag',
    );
    expect(await summary(const Locale('ja'), ordinalRule), '毎月第1月曜日');
    expect(await summary(const Locale('ja'), singleMonthDayRule), '毎月15日');
    expect(await summary(const Locale('ja'), monthDaysRule), '毎月1日、15日');
    expect(await summary(const Locale('ko'), singleMonthDayRule), '매월 15일');
    expect(await summary(const Locale('ko'), monthDaysRule), '매월 1일, 15일');
    expect(
      await summary(const Locale('et'), ordinalRule),
      'Iga kuu esimene esmaspäev',
    );
    expect(
      await summary(const Locale('ru'), monthDaysRule),
      'Ежемесячно в дни месяца 1-го и 15-го',
    );
    expect(
      await summary(const Locale('et'), singleMonthDayRule),
      'Iga kuu 15. päeval',
    );
    expect(
      await summary(const Locale('et'), monthDaysRule),
      'Iga kuu 1. ja 15. päeval',
    );
    expect(
      await summary(const Locale('hi'), singleMonthDayRule),
      'हर महीने के 15वें दिन',
    );
    expect(
      await summary(const Locale('hi'), ordinalRule),
      'हर महीने के पहले सोमवार को',
    );
    for (final locale in [
      const Locale('ja'),
      const Locale('ko'),
      const Locale('zh'),
      const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans'),
      const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
    ]) {
      final monthDays = await summary(locale, yearlyMonthDayRule);
      final ordinal = await summary(locale, yearlyOrdinalRule);
      if (locale.languageCode == 'ja') {
        expect(monthDays, '毎年9月15日');
        expect(ordinal, '毎年9月の第1月曜日');
      } else if (locale.languageCode == 'ko') {
        expect(monthDays, '매년 9월 15일');
        expect(ordinal, '매년 9월의 첫 번째 월요일');
      } else if (locale.scriptCode == 'Hant') {
        expect(monthDays, '每年9月15日');
        expect(ordinal, '每年9月的第一個星期一');
      } else {
        expect(monthDays, '每年9月15日');
        expect(ordinal, '每年9月的第一个星期一');
      }
    }
    final persianMonthDay = await summary(
      const Locale('fa'),
      singleMonthDayRule,
    );
    expect(persianMonthDay, contains('۱۵'));
    expect(persianMonthDay, isNot(contains('15')));
  });

  test('Persian dynamic numbers use Persian digits', () {
    const fsi = '\u2068';
    const pdi = '\u2069';
    final fa = AppLocalizationsFa();

    expect(fa.moreItems(12), contains('$fsi۱۲$pdi'));
    expect(fa.pendingOpAttempts(42), contains('$fsi۴۲$pdi'));
    expect(fa.weekNumberTooltip(27), contains('$fsi۲۷$pdi'));

    // package:intl intentionally uses Latin digits for the generic ar locale.
    expect(AppLocalizationsAr().moreItems(12), contains('${fsi}12$pdi'));
  });

  test('yearly recurrence month forms cover every month', () {
    const monthKeys = [
      'jan',
      'feb',
      'mar',
      'apr',
      'may',
      'jun',
      'jul',
      'aug',
      'sep',
      'oct',
      'nov',
      'dec',
    ];
    const estonian = [
      'jaanuaris',
      'veebruaris',
      'märtsis',
      'aprillis',
      'mais',
      'juunis',
      'juulis',
      'augustis',
      'septembris',
      'oktoobris',
      'novembris',
      'detsembris',
    ];
    const finnish = [
      'tammikuun',
      'helmikuun',
      'maaliskuun',
      'huhtikuun',
      'toukokuun',
      'kesäkuun',
      'heinäkuun',
      'elokuun',
      'syyskuun',
      'lokakuun',
      'marraskuun',
      'joulukuun',
    ];
    final et = lookupAppLocalizations(const Locale('et'));
    final fi = lookupAppLocalizations(const Locale('fi'));

    for (var index = 0; index < monthKeys.length; index += 1) {
      expect(
        et.repeatYearlyMonthValue('fallback', monthKeys[index]),
        estonian[index],
      );
      expect(
        fi.repeatYearlyMonthValue('fallback', monthKeys[index]),
        finnish[index],
      );
    }
    expect(
      lookupAppLocalizations(
        const Locale('en'),
      ).repeatYearlyMonthValue('Sep', 'sep'),
      'Sep',
    );
  });

  test('both Chinese scripts are generated and supported', () {
    const simplified = Locale.fromSubtags(
      languageCode: 'zh',
      scriptCode: 'Hans',
    );
    const traditional = Locale.fromSubtags(
      languageCode: 'zh',
      scriptCode: 'Hant',
    );

    expect(AppLocalizations.supportedLocales, contains(simplified));
    expect(AppLocalizations.supportedLocales, contains(traditional));
    expect(lookupAppLocalizations(simplified).settings, '设置');
    expect(lookupAppLocalizations(traditional).settings, '設定');
  });

  test('Chinese regions resolve to the appropriate script', () {
    const simplified = Locale.fromSubtags(
      languageCode: 'zh',
      scriptCode: 'Hans',
    );
    const traditional = Locale.fromSubtags(
      languageCode: 'zh',
      scriptCode: 'Hant',
    );

    expect(
      resolveBusyMaxLocale(
        const Locale('zh', 'CN'),
        AppLocalizations.supportedLocales,
      ),
      simplified,
    );
    expect(
      resolveBusyMaxLocale(
        const Locale('zh', 'TW'),
        AppLocalizations.supportedLocales,
      ),
      traditional,
    );
  });

  test('locale resolution considers every system preference', () {
    expect(
      resolveBusyMaxLocales(const [
        Locale('eo'),
        Locale('de', 'DE'),
      ], AppLocalizations.supportedLocales),
      const Locale('de'),
    );
  });

  test('unsupported locale lists deliberately fall back to English', () {
    expect(
      resolveBusyMaxLocales(const [
        Locale('eo'),
        Locale('kl'),
      ], AppLocalizations.supportedLocales),
      const Locale('en'),
    );
  });

  test('every selectable locale has a generated catalog', () {
    final generated = AppLocalizations.supportedLocales.toSet()
      ..remove(const Locale('zh'));
    final selectable = busyMaxLocaleOptions
        .map((option) => option.locale)
        .toSet();

    expect(selectable, generated);
  });
}

Iterable<File> _productionUiDartFiles() sync* {
  for (final entity in Directory('lib').listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) {
      continue;
    }
    if (entity.path.contains('/l10n/generated/')) {
      continue;
    }
    if (!entity.path.contains('/presentation/') &&
        !entity.path.contains('/src/app/')) {
      continue;
    }
    yield entity;
  }
}

Iterable<File> _translatedArbFiles() sync* {
  for (final entity in Directory('lib/l10n').listSync()) {
    if (entity is File &&
        entity.path.endsWith('.arb') &&
        !entity.path.endsWith('app_en.arb')) {
      yield entity;
    }
  }
}

Iterable<String> _metadataTranslationFailures() sync* {
  final targetLocales = <String>[
    for (final file in _translatedArbFiles())
      RegExp(r'app_([A-Za-z_]+)\.arb$').firstMatch(file.path)!.group(1)!,
  ]..sort();
  final desktop = File('linux/io.busystack.busymax.desktop').readAsStringSync();
  final metainfo = File(
    'linux/io.busystack.busymax.metainfo.xml',
  ).readAsStringSync();
  final snap = File('snap/snapcraft.yaml').readAsStringSync();

  if (!snap.contains('Snap Store listing translations are managed outside')) {
    yield 'snap/snapcraft.yaml: missing external translation note';
  }
  for (final locale in targetLocales) {
    final xmlLocale = locale.replaceAll('_', '-');
    if (!desktop.contains('Name[$locale]=')) {
      yield 'linux/io.busystack.busymax.desktop: missing Name[$locale]';
    }
    if (!desktop.contains('Comment[$locale]=')) {
      yield 'linux/io.busystack.busymax.desktop: missing Comment[$locale]';
    }
    if (!metainfo.contains('<name xml:lang="$xmlLocale">')) {
      yield 'linux/io.busystack.busymax.metainfo.xml: missing name for '
          '$xmlLocale';
    }
    if (!metainfo.contains('<summary xml:lang="$xmlLocale">')) {
      yield 'linux/io.busystack.busymax.metainfo.xml: missing summary for '
          '$xmlLocale';
    }
    if (!metainfo.contains('<p xml:lang="$xmlLocale">')) {
      yield 'linux/io.busystack.busymax.metainfo.xml: missing description for '
          '$xmlLocale';
    }
  }
}

final _userFacingLiteralPatterns = <RegExp>[
  RegExp(r"\bText\(\s*'([^']*[A-Za-z][^']*)'"),
  RegExp(r"\bSelectableText\(\s*'([^']*[A-Za-z][^']*)'"),
  RegExp(
    r"\b(?:title|subtitle|tooltip|label|message|description|semanticLabel|labelText|hintText|helperText):\s*'([^']*[A-Za-z][^']*)'",
  ),
];

bool _isTechnicalLiteral(String literal) {
  final interpolationStripped = literal.replaceAll(
    RegExp(r'\$\{[^}]*\}|\$[A-Za-z_][A-Za-z0-9_]*'),
    '',
  );
  return literal == 'BusyMax' ||
      literal == 'iCalendar' ||
      literal == 'Ubuntu' ||
      literal.startsWith(r'$') ||
      !RegExp(r'[A-Za-z]{3,}').hasMatch(interpolationStripped);
}

Map<String, Object?> _decodeArb(File file) {
  return (jsonDecode(file.readAsStringSync()) as Map).cast<String, Object?>();
}

Map<String, String> _messages(Map<String, Object?> arb) {
  return {
    for (final entry in arb.entries)
      if (!entry.key.startsWith('@') && entry.value is String)
        entry.key: entry.value! as String,
  };
}

Iterable<String> _declaredPlaceholders(
  Map<String, Object?> templateArb,
  String key,
) sync* {
  final metadata = templateArb['@$key'];
  if (metadata is! Map) {
    return;
  }
  final placeholders = metadata['placeholders'];
  if (placeholders is! Map) {
    return;
  }
  yield* placeholders.keys.cast<String>();
}

Iterable<String> _usedPlaceholders(String value) sync* {
  yield* _scanIcuPlaceholders(value);
}

Iterable<String> _scanIcuPlaceholders(String value) sync* {
  for (var index = 0; index < value.length;) {
    if (value[index] != '{') {
      index += 1;
      continue;
    }

    final closing = _matchingBrace(value, index);
    if (closing == -1) {
      index += 1;
      continue;
    }

    final body = value.substring(index + 1, closing);
    final nameMatch = RegExp(r'^\s*([A-Za-z][A-Za-z0-9_]*)').firstMatch(body);
    if (nameMatch != null) {
      final name = nameMatch.group(1)!;
      final remainder = body.substring(nameMatch.end).trimLeft();
      if (remainder.isEmpty || remainder.startsWith(',')) {
        yield name;
      }

      final selectMatch = RegExp(
        r'^\s*[A-Za-z][A-Za-z0-9_]*\s*,\s*select\s*,',
      ).firstMatch(body);
      if (selectMatch != null) {
        yield* _scanIcuSelectOptions(body.substring(selectMatch.end));
      } else if (remainder.startsWith(',')) {
        yield* _scanIcuPlaceholders(body.substring(nameMatch.end));
      }
    } else {
      yield* _scanIcuPlaceholders(body);
    }

    index = closing + 1;
  }
}

Iterable<String> _scanIcuSelectOptions(String value) sync* {
  for (var index = 0; index < value.length;) {
    while (index < value.length && value[index].trim().isEmpty) {
      index += 1;
    }
    if (index >= value.length) return;

    final optionMatch = RegExp(
      r'[A-Za-z][A-Za-z0-9_]*',
    ).matchAsPrefix(value, index);
    if (optionMatch == null) return;
    index = optionMatch.end;
    while (index < value.length && value[index].trim().isEmpty) {
      index += 1;
    }
    if (index >= value.length || value[index] != '{') return;

    final closing = _matchingBrace(value, index);
    if (closing == -1) return;
    yield* _scanIcuPlaceholders(value.substring(index + 1, closing));
    index = closing + 1;
  }
}

int _matchingBrace(String value, int opening) {
  var depth = 0;
  for (var index = opening; index < value.length; index += 1) {
    if (value[index] == '{') {
      depth += 1;
    } else if (value[index] == '}') {
      depth -= 1;
      if (depth == 0) return index;
    }
  }
  return -1;
}

int _lineForOffset(String source, int offset) {
  return '\n'.allMatches(source.substring(0, offset)).length + 1;
}

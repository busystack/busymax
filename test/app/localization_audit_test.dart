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
  final pattern = RegExp(r'\{([A-Za-z][A-Za-z0-9_]*)(?=,|\})');
  yield* pattern.allMatches(value).map((match) => match.group(1)!);
}

int _lineForOffset(String source, int offset) {
  return '\n'.allMatches(source.substring(0, offset)).length + 1;
}

import 'dart:convert';
import 'dart:io';

import 'package:busymax/l10n/generated/app_localizations.dart';
import 'package:busymax/src/l10n/locale_resolution.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('localized UI surfaces do not hardcode user-facing text', () {
    final failures = <String>[];

    for (final path in _auditedUiPaths) {
      final source = File(path).readAsStringSync();
      for (final match in _userFacingLiteralPattern.allMatches(source)) {
        final literal = match.group(1)!;
        if (_isTechnicalLiteral(literal)) {
          continue;
        }
        failures.add('$path:${_lineForOffset(source, match.start)}: $literal');
      }
    }

    expect(failures, isEmpty, reason: failures.join('\n'));
  });

  test('translated ARB catalogs match the English template', () {
    final templateFile = File('lib/l10n/app_en.arb');
    final templateArb = _decodeArb(templateFile);
    final templateMessages = _messages(templateArb);
    final failures = <String>[];

    for (final path in _translatedArbPaths) {
      final file = File(path);
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
        if (translation.trim().isEmpty) {
          failures.add('$path: $key has an empty translation');
        }
        for (final placeholder in _declaredPlaceholders(templateArb, key)) {
          if (!translation.contains('{$placeholder')) {
            failures.add('$path: $key does not use {$placeholder}');
          }
        }
      }
    }

    expect(failures, isEmpty, reason: failures.join('\n'));
  });

  test('Finnish is generated and exposed as a supported locale', () {
    const locale = Locale('fi');
    final localizations = lookupAppLocalizations(locale);

    expect(AppLocalizations.supportedLocales, contains(locale));
    expect(localizations.settings, 'Asetukset');
    expect(localizations.today, 'Tänään');
  });

  test('Russian is generated and exposed as a supported locale', () {
    const locale = Locale('ru');
    final localizations = lookupAppLocalizations(locale);

    expect(AppLocalizations.supportedLocales, contains(locale));
    expect(localizations.settings, 'Настройки');
    expect(localizations.today, 'Сегодня');
  });

  test('Portuguese is generated and exposed as a supported locale', () {
    const locale = Locale('pt');
    final localizations = lookupAppLocalizations(locale);

    expect(AppLocalizations.supportedLocales, contains(locale));
    expect(localizations.settings, 'Definições');
    expect(localizations.today, 'Hoje');
  });

  test('Hindi is generated and exposed as a supported locale', () {
    const locale = Locale('hi');
    final localizations = lookupAppLocalizations(locale);

    expect(AppLocalizations.supportedLocales, contains(locale));
    expect(localizations.settings, 'सेटिंग्स');
    expect(localizations.today, 'आज');
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
}

const _auditedUiPaths = <String>[
  'lib/src/features/settings/presentation/settings_screen.dart',
  'lib/src/features/auth/presentation/sign_in_screen.dart',
  'lib/src/features/calendar/presentation/event_description_editor.dart',
  'lib/src/features/calendar/presentation/event_editor.dart',
  'lib/src/features/schedule/presentation/mini_calendar.dart',
  'lib/src/features/schedule/presentation/schedule_day_week_view.dart',
  'lib/src/features/schedule/presentation/schedule_sidebar.dart',
];

const _translatedArbPaths = <String>[
  'lib/l10n/app_ar.arb',
  'lib/l10n/app_de.arb',
  'lib/l10n/app_es.arb',
  'lib/l10n/app_fa.arb',
  'lib/l10n/app_fi.arb',
  'lib/l10n/app_fr.arb',
  'lib/l10n/app_hi.arb',
  'lib/l10n/app_ja.arb',
  'lib/l10n/app_ko.arb',
  'lib/l10n/app_pt.arb',
  'lib/l10n/app_ru.arb',
  'lib/l10n/app_zh.arb',
  'lib/l10n/app_zh_Hans.arb',
  'lib/l10n/app_zh_Hant.arb',
];

final _userFacingLiteralPattern = RegExp(
  r"(?:\bText\(\s*|\b(?:title|subtitle|tooltip|label|message|description|semanticLabel|labelText|hintText|helperText):\s*)'([^']*[A-Za-z][^']*)'",
);

bool _isTechnicalLiteral(String literal) {
  return RegExp(r'^\$\{?[A-Za-z_]\w*(?:\.[A-Za-z_]\w*)*\}?$').hasMatch(literal);
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

int _lineForOffset(String source, int offset) {
  return '\n'.allMatches(source.substring(0, offset)).length + 1;
}

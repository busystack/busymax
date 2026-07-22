import 'dart:convert';
import 'dart:io';

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
  'lib/l10n/app_de.arb',
  'lib/l10n/app_es.arb',
  'lib/l10n/app_fr.arb',
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

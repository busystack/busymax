import 'package:intl/intl.dart';

enum BusyMaxTimeFormatPreference { system, twelveHour, twentyFourHour }

bool resolveBusyMax24HourClock(
  BusyMaxTimeFormatPreference preference, {
  required bool systemUses24Hour,
}) => switch (preference) {
  BusyMaxTimeFormatPreference.system => systemUses24Hour,
  BusyMaxTimeFormatPreference.twelveHour => false,
  BusyMaxTimeFormatPreference.twentyFourHour => true,
};

int twelveHourComponent(int hour) => (hour + 11) % 12 + 1;

int canonicalHour(int hour, {required bool isPm}) =>
    hour % 12 + (isPm ? 12 : 0);

// Explicit CLDR-style 12-hour patterns for BusyMax's supported languages.
// `j` is deliberately absent: it follows the locale's default clock.
// Keep period ordering and separators here, including in 24-hour locales.
const _twelveHourPatterns = {
  'ja': 'ah:mm',
  'zh': 'ah:mm',
  'ko': 'a h:mm',
  'fi': 'h.mm a',
};

/// A presentation snapshot. It never converts time zones or changes dates.
class BusyMaxTimeFormatter {
  const BusyMaxTimeFormatter({required this.locale, required this.use24Hour});

  final String locale;
  final bool use24Hour;

  String get twelveHourPattern =>
      _twelveHourPatterns[Intl.canonicalizedLocale(locale).split('_').first] ??
      'h:mm a';

  DateFormat get _clock =>
      (use24Hour
            ? DateFormat.Hm(locale)
            : DateFormat(twelveHourPattern, locale))
        ..useNativeDigits = true;

  String format(DateTime value) => _clock.format(value);

  String formatClock(int hour, int minute) {
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) {
      throw ArgumentError('An ordinary clock must be within 00:00–23:59');
    }
    return format(DateTime(2000, 1, 1, hour, minute));
  }

  String compose(
    String dateLabel,
    DateTime value,
    String Function(String date, String time) composeLabels,
  ) => composeLabels(dateLabel, format(value));

  String scheduleBoundary(int minutes, {required String endOfDayLabel}) {
    if (minutes == 1440) {
      return use24Hour ? '24:00' : '${formatClock(0, 0)} ($endOfDayLabel)';
    }
    return formatClock(minutes ~/ 60, minutes % 60);
  }

  String periodLabel(bool isPm) =>
      DateFormat('a', locale).format(DateTime(2000, 1, 1, isPm ? 12 : 0));

  String component(int value, {bool padded = true}) {
    final format = DateFormat(padded ? 'mm' : 'm', locale)
      ..useNativeDigits = true;
    return format.format(DateTime(2000, 1, 1, 0, value));
  }

  @override
  bool operator ==(Object other) =>
      other is BusyMaxTimeFormatter &&
      other.locale == locale &&
      other.use24Hour == use24Hour;

  @override
  int get hashCode => Object.hash(locale, use24Hour);
}

String normalizeTimeDigits(String input) {
  // ASCII, Arabic-Indic, Persian and Devanagari digits. No arbitrary case folding.
  return String.fromCharCodes(
    input.runes.map((rune) {
      for (final zero in [0x0660, 0x06f0, 0x0966]) {
        if (rune >= zero && rune <= zero + 9) return rune - zero + 0x30;
      }
      return rune;
    }),
  );
}

String _normalizeTimeInput(String input) => normalizeTimeDigits(input)
    .replaceAll(RegExp('[\u200e\u200f\u061c]'), '')
    .replaceAll(RegExp(r'\s|\u00a0|\u202f'), ' ')
    .replaceAll(RegExp(' +'), ' ')
    .trim();

/// User entry parsing, separate from canonical HH:mm storage parsing.
/// Validates the original components before converting a 12-hour value.
({int hour, int minute})? parseBusyMaxClockInput(String input, String locale) {
  var text = _normalizeTimeInput(input);
  if (text.isEmpty) return null;
  final formatter = BusyMaxTimeFormatter(locale: locale, use24Hour: false);
  bool? isPm;
  final periods = <(String, bool, bool)>[
    (_normalizeTimeInput(formatter.periodLabel(false)), false, false),
    (_normalizeTimeInput(formatter.periodLabel(true)), true, false),
    ('AM', false, true),
    ('PM', true, true),
  ]..sort((a, b) => b.$1.length.compareTo(a.$1.length));
  for (final (marker, pm, english) in periods) {
    final escaped = RegExp.escape(marker);
    final prefix = RegExp('^$escaped\\s*', caseSensitive: !english);
    final suffix = RegExp('\\s*$escaped\$', caseSensitive: !english);
    final match = prefix.firstMatch(text) ?? suffix.firstMatch(text);
    if (match != null) {
      isPm = pm;
      text = text.replaceRange(match.start, match.end, '').trim();
      break;
    }
  }
  // Accept canonical colon entry and the active locale's clock separator.
  final pattern = DateFormat.Hm(locale).pattern!;
  final separator =
      RegExp(r'H+([^Hm]+)m+').firstMatch(pattern)?.group(1) ?? ':';
  final match = RegExp(
    '^([0-9]{1,2})(?:${RegExp.escape(separator)}|:)([0-9]{1,2})\$',
  ).firstMatch(text);
  if (match == null) return null;
  var hour = int.parse(match.group(1)!);
  final minute = int.parse(match.group(2)!);
  if (minute > 59) return null;
  if (isPm != null) {
    if (hour < 1 || hour > 12) return null;
    hour = canonicalHour(hour, isPm: isPm);
  } else if (hour > 23) {
    return null;
  }
  return (hour: hour, minute: minute);
}

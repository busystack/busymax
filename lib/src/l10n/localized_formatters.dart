import 'package:intl/intl.dart';

import '../schedule/schedule_range.dart';

// `intl` exposes CLDR's middle-of-sentence month names, but does not apply
// CLDR contextTransforms. These supported locales request titlecase-firstword
// for wide standalone month names used as UI headings.
const _titleCasedStandaloneMonthLanguages = {'es', 'fr', 'it', 'ru'};

/// Formats a month used by itself as a calendar heading.
///
/// `LLLL` selects the standalone grammatical form. The casing transform is
/// separate because standalone grammar and standalone UI capitalization are
/// distinct concepts in CLDR.
String localizedMonthHeading(String locale, DateTime month) {
  final label = DateFormat.LLLL(locale).format(month);
  final language = Intl.canonicalizedLocale(locale).split('_').first;
  if (label.isEmpty ||
      !_titleCasedStandaloneMonthLanguages.contains(language)) {
    return label;
  }
  return '${label[0].toUpperCase()}${label.substring(1)}';
}

/// Formats a closed-open schedule range without assuming a month/day/year
/// ordering. Each endpoint is formatted as a complete localized date so the
/// result remains unambiguous in every supported locale.
String localizedScheduleRangeLabel(String locale, ScheduleRange range) {
  final end = range.end.subtract(const Duration(days: 1));
  final dateFormat = DateFormat.yMMMd(locale);
  return localizedRangeLabel(
    dateFormat.format(range.start),
    dateFormat.format(end),
  );
}

String localizedRangeLabel(String start, String end) => '$start – $end';

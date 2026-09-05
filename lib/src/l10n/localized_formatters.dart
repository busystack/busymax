import 'package:intl/intl.dart';

import '../schedule/schedule_range.dart';
import '../schedule/schedule_view_mode.dart';

// `intl` exposes CLDR's grammatical contexts, but does not apply CLDR
// contextTransforms. Capitalization is therefore applied only to the
// standalone UI contexts whose locale conventions require it.
const _titleCasedDayLanguages = {'es', 'fr', 'it', 'pt', 'ru'};
const _titleCasedMonthLanguages = {'es', 'fr', 'it', 'ru'};

String _languageCode(String locale) =>
    Intl.canonicalizedLocale(locale).split('_').first;

String _applyHeadingCase(
  String label,
  String locale,
  Set<String> titleCasedLanguages,
) {
  if (label.isEmpty || !titleCasedLanguages.contains(_languageCode(locale))) {
    return label;
  }
  return toBeginningOfSentenceCase(label, locale);
}

String _formatContextPattern(String pattern, String locale, DateTime value) {
  // intl treats bare known patterns such as EEEE and MMMM as adaptable
  // skeletons. The quoted marker makes this an explicit pattern so E/M use
  // format-context names rather than standalone c/L names.
  const marker = '|';
  final formatted = DateFormat("$pattern'$marker'", locale).format(value);
  return formatted.substring(0, formatted.length - marker.length);
}

/// Formats a complete date used as a standalone calendar-page heading.
String localizedDayHeading(String locale, DateTime day) {
  final formatWeekday = _formatContextPattern('EEEE', locale, day);
  final standaloneWeekday = localizedWeekdayLabel(locale, day);
  var label = DateFormat.yMMMMEEEEd(locale).format(day);
  final weekdayStart = label.indexOf(formatWeekday);
  if (weekdayStart >= 0 && formatWeekday != standaloneWeekday) {
    label = label.replaceRange(
      weekdayStart,
      weekdayStart + formatWeekday.length,
      standaloneWeekday,
    );
  }
  return _applyHeadingCase(label, locale, _titleCasedDayLanguages);
}

/// Formats a month and year used as a standalone calendar-page heading.
String localizedMonthYearHeading(String locale, DateTime month) {
  final label = DateFormat.yMMMM(locale).format(month);
  return _applyHeadingCase(label, locale, _titleCasedMonthLanguages);
}

/// Formats a month used by itself as a calendar heading.
///
/// `LLLL` selects the standalone grammatical form. The casing transform is
/// separate because standalone grammar and standalone UI capitalization are
/// distinct concepts in CLDR.
String localizedMonthHeading(String locale, DateTime month) {
  return localizedMonthLabel(locale, month);
}

/// Formats a standalone month label using the grammatical `L` form.
String localizedMonthLabel(
  String locale,
  DateTime month, {
  bool abbreviated = false,
}) {
  final label = (abbreviated ? DateFormat.LLL(locale) : DateFormat.LLLL(locale))
      .format(month);
  return _applyHeadingCase(label, locale, _titleCasedMonthLanguages);
}

/// Formats a standalone weekday label using the grammatical `c` form.
String localizedWeekdayLabel(
  String locale,
  DateTime day, {
  bool abbreviated = false,
}) {
  final label = _formatContextPattern(
    abbreviated ? 'ccc' : 'cccc',
    locale,
    day,
  );
  return _applyHeadingCase(label, locale, _titleCasedDayLanguages);
}

/// Formats a weekday name inside a sentence using the grammatical `E` form.
String localizedInlineWeekday(
  String locale,
  DateTime day, {
  bool abbreviated = false,
}) {
  return _formatContextPattern(abbreviated ? 'EEE' : 'EEEE', locale, day);
}

/// Formats a month name inside a sentence using the grammatical `M` form.
String localizedInlineMonth(
  String locale,
  DateTime month, {
  bool abbreviated = false,
}) {
  return _formatContextPattern(abbreviated ? 'MMM' : 'MMMM', locale, month);
}

/// Formats a number using the active locale's decimal digits.
String localizedNumber(String locale, num value) {
  return NumberFormat.decimalPattern(locale).format(value);
}

/// Formats the title shared by the Flutter and native schedule headers.
String localizedScheduleHeading(
  String locale,
  ScheduleViewMode mode,
  ScheduleRange range,
  DateTime selectedDate, {
  required String agendaLabel,
}) {
  return switch (mode) {
    ScheduleViewMode.day => localizedDayHeading(locale, selectedDate),
    ScheduleViewMode.month => localizedMonthYearHeading(locale, selectedDate),
    ScheduleViewMode.year => DateFormat.y(locale).format(selectedDate),
    ScheduleViewMode.agenda => agendaLabel,
    ScheduleViewMode.week => localizedScheduleRangeLabel(locale, range),
  };
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

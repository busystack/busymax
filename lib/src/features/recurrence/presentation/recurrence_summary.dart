import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

import '../../../l10n/l10n.dart';
import '../../../l10n/localized_formatters.dart';
import '../domain/recurrence_rule.dart';
import '../domain/event_recurrence_codec.dart';

String recurrenceRuleSummary(
  BuildContext context,
  RecurrenceRule recurrence, {
  String? timeZone,
  String Function(DateTime)? formatDate,
}) {
  if (!recurrence.repeats) return context.l10n.repeatNone;
  final l10n = context.l10n;
  if (recurrence.frequency == RecurrenceFrequency.yearly &&
      recurrence.bySetPosition != null &&
      recurrence.byMonth.length > 1) {
    return l10n.unsupportedRecurrencePreserved;
  }
  var summary = recurrence.interval == 1
      ? switch (recurrence.frequency) {
          RecurrenceFrequency.daily => l10n.repeatDaily,
          RecurrenceFrequency.weekly => l10n.repeatWeekly,
          RecurrenceFrequency.monthly => l10n.repeatMonthly,
          RecurrenceFrequency.yearly => l10n.repeatYearly,
          RecurrenceFrequency.none => l10n.repeatNone,
        }
      : switch (recurrence.frequency) {
          RecurrenceFrequency.daily => l10n.repeatEveryDays(
            recurrence.interval,
          ),
          RecurrenceFrequency.weekly => l10n.repeatEveryWeeks(
            recurrence.interval,
          ),
          RecurrenceFrequency.monthly => l10n.repeatEveryMonths(
            recurrence.interval,
          ),
          RecurrenceFrequency.yearly => l10n.repeatEveryYears(
            recurrence.interval,
          ),
          RecurrenceFrequency.none => l10n.repeatNone,
        };
  var yearlyMonthPlacedInSummary = false;
  if (recurrence.frequency == RecurrenceFrequency.weekly &&
      recurrence.byDay.isNotEmpty) {
    final dayValues = recurrence.byDay
        .map((day) => _localizedWeeklyDaySummary(context, day))
        .toList(growable: false);
    final days = _localizedRecurrenceList(
      dayValues,
      pair: l10n.repeatWeekdayListPair,
      start: l10n.repeatWeekdayListStart,
    );
    summary =
        '$summary${l10n.repeatSummarySeparator}${l10n.repeatOnDaysSummary(days)}';
  } else if ((recurrence.frequency == RecurrenceFrequency.monthly ||
          recurrence.frequency == RecurrenceFrequency.yearly) &&
      recurrence.byMonthDay.isNotEmpty) {
    final monthDayValues = recurrence.byMonthDay
        .map(
          (day) => l10n.repeatMonthDayValue(_localizedDayNumber(context, day)),
        )
        .toList(growable: false);
    if (recurrence.frequency == RecurrenceFrequency.yearly &&
        recurrence.byMonth.isNotEmpty) {
      final monthValues = recurrence.byMonth
          .map((month) => _localizedYearlyMonth(context, month))
          .toList(growable: false);
      final monthDays = _localizedRecurrenceList(
        monthDayValues,
        pair: l10n.repeatYearlyMonthDayListPair,
        start: l10n.repeatYearlyMonthDayListStart,
      );
      final months = _localizedRecurrenceList(
        monthValues,
        pair: l10n.repeatYearlyMonthListPair,
        start: l10n.repeatYearlyMonthListStart,
      );
      summary = switch ((monthValues.length, monthDayValues.length)) {
        (1, 1) => l10n.repeatYearlyOnMonthDaySummary(
          summary,
          monthValues.single,
          monthDayValues.single,
        ),
        (1, 2) => l10n.repeatYearlyOnTwoMonthDaysSummary(
          summary,
          monthValues.single,
          monthDayValues.first,
          monthDayValues.last,
        ),
        (1, _) => l10n.repeatYearlyOnMonthDaysSummary(
          summary,
          monthValues.single,
          monthDays,
        ),
        (2, 1) => l10n.repeatYearlyInTwoMonthsOnMonthDaySummary(
          summary,
          monthValues.first,
          monthValues.last,
          monthDayValues.single,
        ),
        (2, 2) => l10n.repeatYearlyInTwoMonthsOnTwoMonthDaysSummary(
          summary,
          monthValues.first,
          monthValues.last,
          monthDayValues.first,
          monthDayValues.last,
        ),
        (2, _) => l10n.repeatYearlyInTwoMonthsOnMonthDaysSummary(
          summary,
          monthValues.first,
          monthValues.last,
          monthDays,
        ),
        (_, 1) => l10n.repeatYearlyInMonthsOnMonthDaySummary(
          summary,
          months,
          monthDayValues.single,
        ),
        _ => l10n.repeatYearlyInMonthsOnMonthDaysSummary(
          summary,
          months,
          monthDays,
        ),
      };
      yearlyMonthPlacedInSummary = true;
    } else {
      final monthDays = _localizedRecurrenceList(
        monthDayValues,
        pair: l10n.repeatMonthDayListPair,
        start: l10n.repeatMonthDayListStart,
      );
      final monthDaysSummary = switch (monthDayValues.length) {
        1 => l10n.repeatOnMonthDaysSummary(monthDayValues.single),
        2 => l10n.repeatOnTwoMonthDaysSummary(
          monthDayValues.first,
          monthDayValues.last,
        ),
        _ => l10n.repeatOnMonthDaysSummaryMultiple(monthDays),
      };
      summary = '$summary${l10n.repeatSummarySeparator}$monthDaysSummary';
    }
  } else if (recurrence.bySetPosition case final position?) {
    final ordinalPosition = _ordinalPositionKey(position);
    final days = _localizedOrdinalDaySummary(
      context,
      recurrence.byDay,
      ordinalPosition,
    );
    if (recurrence.frequency == RecurrenceFrequency.yearly &&
        recurrence.byMonth.isNotEmpty) {
      final month = _localizedYearlyMonth(context, recurrence.byMonth.single);
      summary = l10n.repeatYearlyOnOrdinalSummary(
        summary,
        month,
        ordinalPosition,
        days,
      );
      yearlyMonthPlacedInSummary = true;
    } else {
      final ordinalSummary = l10n.repeatOnOrdinalSummary(ordinalPosition, days);
      summary = '$summary${l10n.repeatSummarySeparator}$ordinalSummary';
    }
  }
  if (recurrence.frequency == RecurrenceFrequency.yearly &&
      recurrence.byMonth.isNotEmpty &&
      !yearlyMonthPlacedInSummary) {
    final monthValues = recurrence.byMonth
        .map((month) => _localizedYearlyMonth(context, month))
        .toList(growable: false);
    final months = _localizedRecurrenceList(
      monthValues,
      pair: l10n.repeatYearlyMonthListPair,
      start: l10n.repeatYearlyMonthListStart,
    );
    summary = '$summary ${l10n.repeatInMonthsSummary(months)}';
  }
  if (recurrence.count != null) {
    return '$summary · ${l10n.repeatTimesSummary(recurrence.count!)}';
  }
  final until = recurrence.untilDateFor(timeZone: timeZone);
  if (until == null) return summary;
  final date = DateTime.tryParse(until);
  final label = date == null
      ? until
      : (formatDate ??
            DateFormat.yMMMd(Localizations.localeOf(context).toLanguageTag())
                .format)(date);
  return '$summary · ${l10n.repeatUntilSummary(label)}';
}

typedef _OrdinalDayChoice = ({String key, List<String> days});

const _ordinalDayChoices = <_OrdinalDayChoice>[
  (key: 'MO', days: ['MO']),
  (key: 'TU', days: ['TU']),
  (key: 'WE', days: ['WE']),
  (key: 'TH', days: ['TH']),
  (key: 'FR', days: ['FR']),
  (key: 'SA', days: ['SA']),
  (key: 'SU', days: ['SU']),
  (key: 'day', days: ['MO', 'TU', 'WE', 'TH', 'FR', 'SA', 'SU']),
  (key: 'weekday', days: ['MO', 'TU', 'WE', 'TH', 'FR']),
  (key: 'weekend', days: ['SA', 'SU']),
];

String _ordinalDayChoiceKey(List<String> days) {
  for (final choice in _ordinalDayChoices) {
    if (_sameDaySet(choice.days, days)) return choice.key;
  }
  return days.firstOrNull ?? 'MO';
}

DateTime? _weekdayDate(String day) {
  final index = rfcWeekdays.indexOf(day);
  if (index < 0) return null;
  return DateTime(2024, 1, 1 + index);
}

String _localizedInlineWeekday(BuildContext context, String day) {
  final date = _weekdayDate(day);
  if (date == null) return day;
  final locale = Localizations.localeOf(context).toLanguageTag();
  return localizedInlineWeekday(locale, date);
}

String _localizedDayNumber(BuildContext context, int day) {
  final locale = Localizations.localeOf(context).toLanguageTag();
  return localizedNumber(locale, day);
}

String _localizedRecurrenceList(
  List<String> values, {
  required String Function(String first, String second) pair,
  required String Function(String first, String rest) start,
}) {
  assert(values.isNotEmpty);
  if (values.length == 1) return values.single;

  var result = pair(values[values.length - 2], values.last);
  for (var index = values.length - 3; index >= 0; index -= 1) {
    result = start(values[index], result);
  }
  return result;
}

String _localizedInlineMonth(BuildContext context, int month) {
  if (month < 1 || month > 12) return '$month';
  final locale = Localizations.localeOf(context).toLanguageTag();
  return localizedInlineMonth(locale, DateTime(2024, month), abbreviated: true);
}

String _localizedYearlyMonth(BuildContext context, int month) {
  final localizedMonth = _localizedInlineMonth(context, month);
  return context.l10n.repeatYearlyMonthValue(
    localizedMonth,
    _recurrenceMonthKey(month),
  );
}

String _recurrenceMonthKey(int month) => switch (month) {
  1 => 'jan',
  2 => 'feb',
  3 => 'mar',
  4 => 'apr',
  5 => 'may',
  6 => 'jun',
  7 => 'jul',
  8 => 'aug',
  9 => 'sep',
  10 => 'oct',
  11 => 'nov',
  12 => 'dec',
  _ => 'other',
};

String _ordinalPositionKey(int value) => switch (value) {
  1 => 'first',
  2 => 'second',
  3 => 'third',
  4 => 'fourth',
  5 => 'fifth',
  -2 => 'secondToLast',
  -1 => 'last',
  _ => '$value',
};

String _localizedOrdinalDaySummary(
  BuildContext context,
  List<String> days,
  String ordinalPosition,
) {
  final dayKey = _ordinalDayChoiceKey(days);
  final ordinalDayKey = Localizations.localeOf(context).languageCode == 'pl'
      ? '$ordinalPosition$dayKey'
      : dayKey;
  if (days.length == 1) {
    return context.l10n.repeatOrdinalDaySummary(
      ordinalDayKey,
      _localizedInlineWeekday(context, days.single),
    );
  }
  if (dayKey == 'day' || dayKey == 'weekday' || dayKey == 'weekend') {
    return context.l10n.repeatOrdinalDaySummary(ordinalDayKey, '');
  }
  final dayValues = days
      .map((day) => _localizedInlineWeekday(context, day))
      .toList(growable: false);
  final localizedDays = _localizedRecurrenceList(
    dayValues,
    pair: context.l10n.repeatWeekdayListPair,
    start: context.l10n.repeatWeekdayListStart,
  );
  return context.l10n.repeatOrdinalDaySummary(ordinalDayKey, localizedDays);
}

String _localizedWeeklyDaySummary(BuildContext context, String day) {
  return context.l10n.repeatWeeklyDaySummary(
    day,
    _localizedInlineWeekday(context, day),
  );
}

bool _sameDaySet(List<String> left, List<String> right) {
  if (left.length != right.length) return false;
  final leftValues = {...left};
  return leftValues.length == left.length && leftValues.containsAll(right);
}

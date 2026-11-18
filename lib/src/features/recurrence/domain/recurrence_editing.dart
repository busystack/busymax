import 'event_recurrence_codec.dart' show rfcWeekdays;
import 'recurrence_rule.dart';

enum RecurrenceEnd { never, until, count }

extension RecurrenceEditing on RecurrenceRule {
  RecurrenceEnd get endMode => count != null
      ? RecurrenceEnd.count
      : untilRaw != null
      ? RecurrenceEnd.until
      : RecurrenceEnd.never;

  RecurrenceRule withFrequency(RecurrenceFrequency selection, DateTime start) {
    if (isSupported && selection == frequency) return this;
    if (selection == RecurrenceFrequency.none) {
      return const RecurrenceRule.none();
    }
    final editable = isSupported ? this : const RecurrenceRule.none();
    return editable.copyWith(
      frequency: selection,
      byDay: selection == RecurrenceFrequency.weekly
          ? [rfcWeekdays[start.weekday - 1]]
          : const [],
      byMonthDay:
          selection == RecurrenceFrequency.monthly ||
              selection == RecurrenceFrequency.yearly
          ? [start.day]
          : const [],
      byMonth: selection == RecurrenceFrequency.yearly
          ? [start.month]
          : const [],
      bySetPosition: null,
    );
  }

  RecurrenceRule withEndMode(
    RecurrenceEnd mode, {
    required DateTime baseDate,
    required bool allDay,
    required String? timeZone,
    required bool floating,
    required String defaultUntil,
    int defaultCount = 10,
  }) => switch (mode) {
    RecurrenceEnd.never => copyWith(count: null, untilRaw: null),
    RecurrenceEnd.count => copyWith(
      count: count ?? defaultCount,
      untilRaw: null,
    ),
    RecurrenceEnd.until => copyWith(count: null).withUntilDate(
      untilDateFor(timeZone: timeZone) ?? defaultUntil,
      allDay: allDay,
      floating: floating,
      baseDate: baseDate,
      timeZone: timeZone,
    ),
  };
}

/// Preserve the calendar date of a recurrence end when editing its start.
RecurrenceRule retimeRecurrenceEnd(
  RecurrenceRule rule, {
  required String? previousTimeZone,
  required DateTime start,
  required String? timeZone,
  required bool allDay,
  required bool floating,
}) {
  final until = rule.untilDateFor(timeZone: previousTimeZone);
  if (until == null) return rule;
  return rule.withUntilDate(
    until,
    baseDate: start,
    timeZone: timeZone,
    allDay: allDay,
    floating: floating,
  );
}

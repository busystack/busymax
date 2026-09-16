import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

import '../../../l10n/l10n.dart';
import '../../../l10n/time_format_scope.dart';
import '../../../schedule/schedule_item.dart';
import '../../../schedule/schedule_search_criteria.dart';
import '../../../schedule/schedule_search_match.dart';

/// The date that gives a search result its place in Agenda presentation.
///
/// Search date filters intentionally use a task's actual due value, while the
/// ordinary Schedule projection uses its scheduling start. Keep that
/// distinction in presentation so an already-matched task remains under the
/// date that caused it to match.
DateTime? scheduleSearchResultDisplayDate(ScheduleItem item) =>
    item is TaskScheduleItem ? item.due ?? item.start : item.start;

int compareScheduleSearchResultPresentation(
  ScheduleItem first,
  ScheduleItem second,
) {
  final firstDate = scheduleSearchResultDisplayDate(first);
  final secondDate = scheduleSearchResultDisplayDate(second);
  final dayComparison = _searchResultDay(
    firstDate,
  ).compareTo(_searchResultDay(secondDate));
  if (dayComparison != 0) return dayComparison;
  if (first.allDay != second.allDay) return first.allDay ? -1 : 1;
  final timeComparison = _searchResultDate(
    firstDate,
  ).compareTo(_searchResultDate(secondDate));
  if (timeComparison != 0) return timeComparison;
  if (first.kind != second.kind) {
    return first.kind == ScheduleItemKind.calendarEvent ? -1 : 1;
  }
  final titleComparison = first.title.toLowerCase().compareTo(
    second.title.toLowerCase(),
  );
  if (titleComparison != 0) return titleComparison;
  final accountComparison = first.accountId.compareTo(second.accountId);
  if (accountComparison != 0) return accountComparison;
  final sourceComparison = first.sourceId.compareTo(second.sourceId);
  if (sourceComparison != 0) return sourceComparison;
  return first.id.compareTo(second.id);
}

DateTime _searchResultDay(DateTime? value) => value == null
    ? DateTime(9999)
    : DateTime(value.year, value.month, value.day);

DateTime _searchResultDate(DateTime? value) => value ?? DateTime(9999);

String scheduleSearchResultText(
  BuildContext context,
  ScheduleItem item,
  ScheduleSearchCriteria criteria,
  String query,
) {
  final l = context.l10n;
  final locale = Localizations.localeOf(context).toLanguageTag();
  String date(DateTime value) => DateFormat.yMMMd(locale).format(value);
  String taskDate(DateTime value) {
    // A DAV task can have an all-day start and a separately timed due value.
    final hasTime =
        !item.allDay ||
        value.hour != 0 ||
        value.minute != 0 ||
        value.second != 0 ||
        value.millisecond != 0 ||
        value.microsecond != 0;
    return hasTime
        ? formatClockDateTime(context, value, date(value))
        : date(value);
  }

  final start = item.start;
  final time = item is TaskScheduleItem
      ? item.due != null
            ? '${l.dueDate}: ${taskDate(item.due!)}'
            : start != null
            ? '${l.startDate}: ${taskDate(start)}'
            : l.searchNoDueDate
      : start == null
      ? l.noDate
      : item.allDay
      ? '${date(start)} · ${l.allDay}'
      : formatClockDateTime(context, start, date(start));
  final snippet = scheduleMatchContext(
    item,
    query,
    location: criteria.location,
    person: criteria.person,
  );
  return [
    time,
    scheduleSearchSourceLabel(item),
    if (snippet != null) snippet,
  ].join(' · ');
}

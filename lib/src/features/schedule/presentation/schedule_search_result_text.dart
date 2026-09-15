import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

import '../../../l10n/l10n.dart';
import '../../../l10n/time_format_scope.dart';
import '../../../schedule/schedule_item.dart';
import '../../../schedule/schedule_search_criteria.dart';
import '../../../schedule/schedule_search_match.dart';

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

import 'package:flutter/foundation.dart';

import 'schedule_view_mode.dart';

enum ScheduleNavigationCause { adjacentPeriod, today, dateSelection }

@immutable
class ScheduleNavigationIntent {
  const ScheduleNavigationIntent({
    required this.cause,
    required this.target,
    required this.direction,
    required this.generation,
  });

  final ScheduleNavigationCause cause;
  final DateTime target;
  final int direction;
  final int generation;
}

/// Moves a civil date by a visible period. Year views may retain the selected
/// day when the renderer uses it as an anchor.
DateTime adjacentScheduleDate(
  DateTime date,
  ScheduleViewMode mode,
  int direction, {
  bool retainDayInYear = false,
}) => switch (mode) {
  ScheduleViewMode.day || ScheduleViewMode.agenda => DateTime(
    date.year,
    date.month,
    date.day + direction,
  ),
  ScheduleViewMode.week => DateTime(
    date.year,
    date.month,
    date.day + 7 * direction,
  ),
  ScheduleViewMode.month => DateTime(date.year, date.month + direction),
  ScheduleViewMode.year => DateTime(
    date.year + direction,
    date.month,
    retainDayInYear ? date.day : 1,
  ),
};

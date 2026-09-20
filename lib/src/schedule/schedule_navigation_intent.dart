import 'package:flutter/foundation.dart';

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

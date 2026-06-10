class ScheduleRange {
  const ScheduleRange({required this.start, required this.end});

  factory ScheduleRange.day(DateTime day) {
    final start = DateTime(day.year, day.month, day.day);
    return ScheduleRange(start: start, end: start.add(const Duration(days: 1)));
  }

  factory ScheduleRange.week(
    DateTime day, {
    int firstWeekday = DateTime.monday,
  }) {
    final date = DateTime(day.year, day.month, day.day);
    final offset = (date.weekday - firstWeekday) % DateTime.daysPerWeek;
    final start = date.subtract(Duration(days: offset));
    return ScheduleRange(start: start, end: start.add(const Duration(days: 7)));
  }

  factory ScheduleRange.month(
    DateTime day, {
    int firstWeekday = DateTime.monday,
  }) {
    final first = DateTime(day.year, day.month);
    final offset = (first.weekday - firstWeekday) % DateTime.daysPerWeek;
    final start = first.subtract(Duration(days: offset));
    final nextMonth = DateTime(day.year, day.month + 1);
    final trailing = (firstWeekday - nextMonth.weekday) % DateTime.daysPerWeek;
    final end = nextMonth.add(Duration(days: trailing));
    return ScheduleRange(start: start, end: end);
  }

  factory ScheduleRange.year(DateTime day) {
    final start = DateTime(day.year);
    return ScheduleRange(start: start, end: DateTime(day.year + 1));
  }

  final DateTime start;
  final DateTime end;

  bool contains(DateTime value) {
    return !value.isBefore(start) && value.isBefore(end);
  }
}

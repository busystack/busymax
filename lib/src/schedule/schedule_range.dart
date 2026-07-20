class ScheduleRange {
  const ScheduleRange({required this.start, required this.end});

  factory ScheduleRange.day(DateTime day) {
    final start = _addCalendarDays(day, 0);
    return ScheduleRange(start: start, end: _addCalendarDays(start, 1));
  }

  factory ScheduleRange.week(
    DateTime day, {
    int firstWeekday = DateTime.monday,
  }) {
    final date = _addCalendarDays(day, 0);
    final offset = (date.weekday - firstWeekday) % DateTime.daysPerWeek;
    final start = _addCalendarDays(date, -offset);
    return ScheduleRange(
      start: start,
      end: _addCalendarDays(start, DateTime.daysPerWeek),
    );
  }

  factory ScheduleRange.month(
    DateTime day, {
    int firstWeekday = DateTime.monday,
  }) {
    final first = DateTime(day.year, day.month);
    final offset = (first.weekday - firstWeekday) % DateTime.daysPerWeek;
    final start = _addCalendarDays(first, -offset);
    final nextMonth = DateTime(day.year, day.month + 1);
    final trailing = (firstWeekday - nextMonth.weekday) % DateTime.daysPerWeek;
    final end = _addCalendarDays(nextMonth, trailing);
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

DateTime _addCalendarDays(DateTime date, int days) {
  // A Duration day is always 24 elapsed hours, which is not a civil day at DST.
  return DateTime(date.year, date.month, date.day + days);
}

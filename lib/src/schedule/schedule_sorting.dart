import 'schedule_item.dart';

int compareScheduleItems(ScheduleItem a, ScheduleItem b) {
  final day = _dateOnly(a.start).compareTo(_dateOnly(b.start));
  if (day != 0) {
    return day;
  }
  if (a.allDay != b.allDay) {
    return a.allDay ? -1 : 1;
  }
  final time = _nullableDate(a.start).compareTo(_nullableDate(b.start));
  if (time != 0) {
    return time;
  }
  if (a.kind != b.kind) {
    return a.kind == ScheduleItemKind.calendarEvent ? -1 : 1;
  }
  return a.title.toLowerCase().compareTo(b.title.toLowerCase());
}

DateTime _dateOnly(DateTime? value) {
  if (value == null) {
    return DateTime(9999);
  }
  return DateTime(value.year, value.month, value.day);
}

DateTime _nullableDate(DateTime? value) => value ?? DateTime(9999);

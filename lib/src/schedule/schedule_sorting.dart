import 'schedule_item.dart';
import '../providers/busy_provider.dart';

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
  if (a is TaskScheduleItem && b is TaskScheduleItem) {
    // Establish a total scope order before applying provider sibling order.
    // Pairwise special-casing only tasks in the same list creates cycles.
    final account = a.accountId.compareTo(b.accountId);
    if (account != 0) return account;
    final list = a.sourceId.compareTo(b.sourceId);
    if (list != 0) return list;
    final parent = (a.parentId ?? '').compareTo(b.parentId ?? '');
    if (parent != 0) return parent;
    final int order;
    if (a.provider == BusyProvider.nextcloud) {
      order = (a.sortOrder ?? 0).compareTo(b.sortOrder ?? 0);
    } else {
      order = (a.position ?? '').compareTo(b.position ?? '');
    }
    if (order != 0) return order;
  }
  final title = a.title.toLowerCase().compareTo(b.title.toLowerCase());
  return title != 0 ? title : a.id.compareTo(b.id);
}

DateTime _dateOnly(DateTime? value) {
  if (value == null) {
    return DateTime(9999);
  }
  return DateTime(value.year, value.month, value.day);
}

DateTime _nullableDate(DateTime? value) => value ?? DateTime(9999);

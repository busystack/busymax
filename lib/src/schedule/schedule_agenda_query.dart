import 'schedule_projection.dart';
import 'schedule_filters.dart';
import 'schedule_item.dart';
import 'schedule_range.dart';
import 'schedule_repository.dart';

/// Agenda has three independently growing buckets. In particular, overdue
/// tasks must never be bounded by the calendar projection's start date.
class ScheduleAgendaPage {
  const ScheduleAgendaPage({
    required this.items,
    this.hasMoreOverdueTasks = false,
    this.hasMoreNoDateTasks = false,
  });

  final List<ScheduleItem> items;
  final bool hasMoreOverdueTasks;
  final bool hasMoreNoDateTasks;
}

Future<ScheduleAgendaPage> queryScheduleAgenda(
  ScheduleRepository repository, {
  required ScheduleRange range,
  required Set<String> sourceIds,
  required Set<ScheduleTaskListKey> taskListKeys,
  Set<String> journalSourceIds = const {},
  Set<String> accountIds = const {},
  bool includeEvents = true,
  bool includeTasks = true,
  bool includeJournals = true,
  int overdueLimit = 8,
  int noDateLimit = 8,
}) async {
  final taskFilters = ScheduleFilters(
    accountIds: accountIds,
    taskListKeys: taskListKeys,
    taskListFilterActive: true,
    includeTasks: includeTasks,
    taskCompletion: ScheduleTaskCompletion.all,
  );
  final pages = await Future.wait([
    repository.listItems(
      range: range,
      filters: ScheduleFilters(
        accountIds: accountIds,
        sourceIds: sourceIds,
        taskListKeys: taskListKeys,
        journalSourceIds: journalSourceIds,
        sourceFilterActive: true,
        taskListFilterActive: true,
        journalSourceFilterActive: true,
        includeCalendarEvents: includeEvents,
        includeTasks: includeTasks,
        includeJournals: includeJournals,
        taskCompletion: ScheduleTaskCompletion.all,
        showNoDateTasks: false,
      ),
    ),
    repository.listOverdueTasks(
      before: range.start,
      limit: overdueLimit,
      filters: ScheduleFilters(
        accountIds: accountIds,
        taskListKeys: taskListKeys,
        taskListFilterActive: true,
        includeTasks: includeTasks,
        taskCompletion: ScheduleTaskCompletion.open,
      ),
    ),
    repository.listNoDateTasks(limit: noDateLimit, filters: taskFilters),
  ]);
  final overdue = pages[1] as ScheduleTaskBucketPage;
  final noDate = pages[2] as ScheduleTaskBucketPage;
  return ScheduleAgendaPage(
    items: await repository.includeTaskAncestors([
      ...pages[0] as List<ScheduleItem>,
      ...overdue.items,
      ...noDate.items,
    ], filters: taskFilters),
    hasMoreOverdueTasks: overdue.hasMore,
    hasMoreNoDateTasks: noDate.hasMore,
  );
}

List<ScheduleItem> scheduleAgendaItems(
  List<ScheduleItem> items,
  ScheduleRange range,
) {
  final startDay = ScheduleProjection.day(range.start);
  return items.where((item) {
    final start = item.start;
    if (start == null) {
      return true;
    }
    if (item is CalendarScheduleItem) {
      return ScheduleProjection.intersects(item, range);
    }
    if (item is TaskScheduleItem) {
      final itemDay = ScheduleProjection.day(start);
      if (itemDay.isBefore(startDay)) {
        return !item.completed;
      }
      return start.isBefore(range.end);
    }
    return ScheduleProjection.intersects(item, range);
  }).toList();
}

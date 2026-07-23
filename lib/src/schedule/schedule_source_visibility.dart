import '../app/app_settings.dart';
import '../features/calendar/data/calendar_repository.dart';
import '../features/task_lists/data/task_lists_repository.dart';
import 'schedule_filters.dart';

class ScheduleSourceVisibility {
  const ScheduleSourceVisibility({
    required this.visibleCalendarSourceIds,
    required this.visibleTaskListKeys,
    required this.hasCalendarSources,
    required this.hasTaskLists,
  });

  factory ScheduleSourceVisibility.fromSources({
    required List<CalendarSourceEntity> calendarSources,
    required List<TaskListEntity> taskLists,
    required AppSettings settings,
  }) {
    return ScheduleSourceVisibility(
      visibleCalendarSourceIds: {
        for (final source in calendarSources)
          if (source.selected && !source.hidden && !source.isDeleted) source.id,
      },
      visibleTaskListKeys: {
        for (final list in taskLists)
          if (!list.pendingDelete &&
              settings.isTaskListVisibleInSchedule(list.accountId, list.id))
            ScheduleTaskListKey(accountId: list.accountId, taskListId: list.id),
      },
      hasCalendarSources: calendarSources.any((source) => !source.isDeleted),
      hasTaskLists: taskLists.any((list) => !list.pendingDelete),
    );
  }

  final Set<String> visibleCalendarSourceIds;
  final Set<ScheduleTaskListKey> visibleTaskListKeys;
  final bool hasCalendarSources;
  final bool hasTaskLists;
}

import '../app/app_settings.dart';
import '../features/calendar/data/calendar_repository.dart';
import '../features/task_lists/data/task_lists_repository.dart';
import 'schedule_filters.dart';
import 'schedule_search_criteria.dart';

bool isScheduleCalendarAvailable(CalendarSourceEntity source) =>
    !source.hidden && !source.isDeleted;

enum ScheduleAccountVisibility {
  visible,
  partial,
  noVisibleSources,
  hidden;

  factory ScheduleAccountVisibility.fromSources({
    required String accountId,
    required AppSettings settings,
    required Iterable<CalendarSourceEntity> calendars,
    required Iterable<TaskListEntity> taskLists,
    Set<String>? selectedCalendarIds,
  }) {
    if (!settings.isAccountVisibleInSchedule(accountId)) return hidden;
    final selections = [
      for (final calendar in calendars)
        if (isScheduleCalendarAvailable(calendar))
          selectedCalendarIds?.contains(calendar.id) ?? calendar.selected,
      for (final list in taskLists)
        if (!list.pendingDelete)
          settings.isTaskListVisibleInSchedule(list.accountId, list.id),
    ];
    if (selections.every((selected) => selected)) return visible;
    return selections.any((selected) => selected) ? partial : noVisibleSources;
  }
}

class ScheduleSourceVisibility {
  const ScheduleSourceVisibility({
    required this.visibleCalendarSourceIds,
    required this.visibleTaskListKeys,
    required this.hasCalendarSources,
    required this.hasTaskLists,
    this.accountHiddenCalendarIds = const {},
    this.hiddenAccountIds = const {},
  });

  factory ScheduleSourceVisibility.fromSources({
    required List<CalendarSourceEntity> calendarSources,
    required List<TaskListEntity> taskLists,
    required AppSettings settings,
  }) {
    final hiddenAccountIds = {
      for (final entry in settings.accountScheduleVisibility.entries)
        if (!entry.value) entry.key,
    };
    return ScheduleSourceVisibility(
      visibleCalendarSourceIds: {
        for (final source in calendarSources)
          if (source.selected &&
              isScheduleCalendarAvailable(source) &&
              !hiddenAccountIds.contains(source.accountId))
            source.id,
      },
      visibleTaskListKeys: {
        for (final list in taskLists)
          if (!list.pendingDelete &&
              !hiddenAccountIds.contains(list.accountId) &&
              settings.isTaskListVisibleInSchedule(list.accountId, list.id))
            ScheduleTaskListKey(accountId: list.accountId, taskListId: list.id),
      },
      hasCalendarSources: calendarSources.any((source) => !source.isDeleted),
      hasTaskLists: taskLists.any((list) => !list.pendingDelete),
      accountHiddenCalendarIds: {
        for (final source in calendarSources)
          if (hiddenAccountIds.contains(source.accountId)) source.id,
      },
      hiddenAccountIds: hiddenAccountIds,
    );
  }

  final Set<String> visibleCalendarSourceIds;
  final Set<ScheduleTaskListKey> visibleTaskListKeys;
  final bool hasCalendarSources;
  final bool hasTaskLists;
  final Set<String> accountHiddenCalendarIds;
  final Set<String> hiddenAccountIds;

  ScheduleSearchCriteria maskSearch(ScheduleSearchCriteria criteria) =>
      hiddenAccountIds.isEmpty
      ? criteria
      : criteria.copyWith(
          sourceIds: criteria.sourceIds.difference(accountHiddenCalendarIds),
          taskListKeys: {
            for (final key in criteria.taskListKeys)
              if (!hiddenAccountIds.contains(key.accountId)) key,
          },
        );
}

import '../app/app_settings.dart';
import '../db/app_database.dart' show DavCollection;
import '../features/calendar/data/calendar_repository.dart';
import '../features/task_lists/data/task_lists_repository.dart';
import '../providers/busy_provider.dart';
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
    Iterable<DavCollection> journals = const [],
  }) {
    if (!settings.isAccountVisibleInSchedule(accountId)) return hidden;
    final selections = [
      for (final calendar in calendars)
        if (isScheduleCalendarAvailable(calendar))
          selectedCalendarIds?.contains(calendar.id) ?? calendar.selected,
      for (final list in taskLists)
        if (!list.pendingDelete)
          settings.isTaskListVisibleInSchedule(list.accountId, list.id),
      for (final journal in journals) journal.journalsSelected,
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
    this.visibleJournalSourceIds = const {},
    this.accountHiddenJournalIds = const {},
  });

  factory ScheduleSourceVisibility.fromSources({
    required List<CalendarSourceEntity> calendarSources,
    required List<TaskListEntity> taskLists,
    required AppSettings settings,
    Iterable<DavCollection> journals = const [],
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
      visibleJournalSourceIds: {
        for (final source in journals)
          if (source.journalsSelected &&
              !hiddenAccountIds.contains(source.accountId))
            source.id,
        for (final source in calendarSources)
          if (source.provider == BusyProvider.webCal &&
              source.selected &&
              isScheduleCalendarAvailable(source) &&
              !hiddenAccountIds.contains(source.accountId))
            source.id,
      },
      accountHiddenJournalIds: {
        for (final source in journals)
          if (hiddenAccountIds.contains(source.accountId)) source.id,
        for (final source in calendarSources)
          if (hiddenAccountIds.contains(source.accountId)) source.id,
      },
    );
  }

  final Set<String> visibleCalendarSourceIds;
  final Set<ScheduleTaskListKey> visibleTaskListKeys;
  final bool hasCalendarSources;
  final bool hasTaskLists;
  final Set<String> accountHiddenCalendarIds;
  final Set<String> hiddenAccountIds;
  final Set<String> visibleJournalSourceIds;
  final Set<String> accountHiddenJournalIds;

  ScheduleSearchCriteria maskSearch(ScheduleSearchCriteria criteria) =>
      hiddenAccountIds.isEmpty
      ? criteria
      : criteria.copyWith(
          sourceIds: criteria.sourceIds.difference(accountHiddenCalendarIds),
          journalSourceIds: criteria.journalSourceIds.difference(
            accountHiddenJournalIds,
          ),
          taskListKeys: {
            for (final key in criteria.taskListKeys)
              if (!hiddenAccountIds.contains(key.accountId)) key,
          },
        );
}

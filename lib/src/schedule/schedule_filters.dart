enum ScheduleTaskCompletion { open, all, completed }

enum ScheduleTaskDueState { any, overdue, noDueDate }

enum ScheduleDatePresence { any, dated, undated }

class ScheduleTaskListKey {
  const ScheduleTaskListKey({
    required this.accountId,
    required this.taskListId,
  });

  final String accountId;
  final String taskListId;

  @override
  bool operator ==(Object other) {
    return other is ScheduleTaskListKey &&
        other.accountId == accountId &&
        other.taskListId == taskListId;
  }

  @override
  int get hashCode => Object.hash(accountId, taskListId);
}

class ScheduleFilters {
  const ScheduleFilters({
    this.accountIds = const {},
    this.sourceIds = const {},
    this.taskListKeys = const {},
    this.journalSourceIds = const {},
    this.sourceFilterActive = false,
    this.taskListFilterActive = false,
    this.journalSourceFilterActive = false,
    this.includeCalendarEvents = true,
    this.includeTasks = true,
    this.includeJournals = false,
    this.query = '',
    this.taskCompletion = ScheduleTaskCompletion.open,
    this.ignoreDateRange = false,
    this.useTaskDueDate = false,
    this.taskDueState = ScheduleTaskDueState.any,
    this.referenceDate,
    this.person = '',
    this.location = '',
    this.showNoDateTasks = true,
    this.datePresence = ScheduleDatePresence.any,
    this.notificationDeadline,
  });

  final Set<String> accountIds;
  final Set<String> sourceIds;
  final Set<ScheduleTaskListKey> taskListKeys;
  final Set<String> journalSourceIds;
  final bool sourceFilterActive;
  final bool taskListFilterActive;
  final bool journalSourceFilterActive;
  final bool includeCalendarEvents;
  final bool includeTasks;
  final bool includeJournals;
  final String query;
  final ScheduleTaskCompletion taskCompletion;

  /// Query every locally projected record without extending provider history.
  final bool ignoreDateRange;

  /// Only bounded queries with an event source need calendar range coverage.
  bool get requiresCalendarCoverage =>
      includeCalendarEvents &&
      !ignoreDateRange &&
      (!sourceFilterActive || sourceIds.isNotEmpty);

  /// Search dates describe due dates; normal Schedule dates describe scheduling.
  final bool useTaskDueDate;
  final ScheduleTaskDueState taskDueState;
  final DateTime? referenceDate;
  final String person;
  final String location;
  final bool showNoDateTasks;
  final ScheduleDatePresence datePresence;

  /// Temporary notification destination; ordinary browsing filters are retained.
  final DateTime? notificationDeadline;
}

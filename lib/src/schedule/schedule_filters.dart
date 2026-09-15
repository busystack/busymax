enum ScheduleTaskCompletion { open, all, completed }

enum ScheduleTaskDueState { any, overdue, noDueDate }

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
    this.sourceFilterActive = false,
    this.taskListFilterActive = false,
    this.includeCalendarEvents = true,
    this.includeTasks = true,
    this.query = '',
    this.taskCompletion = ScheduleTaskCompletion.open,
    this.ignoreDateRange = false,
    this.useTaskDueDate = false,
    this.taskDueState = ScheduleTaskDueState.any,
    this.referenceDate,
    this.person = '',
    this.location = '',
    this.showNoDateTasks = true,
  });

  final Set<String> accountIds;
  final Set<String> sourceIds;
  final Set<ScheduleTaskListKey> taskListKeys;
  final bool sourceFilterActive;
  final bool taskListFilterActive;
  final bool includeCalendarEvents;
  final bool includeTasks;
  final String query;
  final ScheduleTaskCompletion taskCompletion;

  /// Query every locally projected record without extending provider history.
  final bool ignoreDateRange;

  /// Search dates describe due dates; normal Schedule dates describe scheduling.
  final bool useTaskDueDate;
  final ScheduleTaskDueState taskDueState;
  final DateTime? referenceDate;
  final String person;
  final String location;
  final bool showNoDateTasks;
}

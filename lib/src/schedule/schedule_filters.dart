class ScheduleFilters {
  const ScheduleFilters({
    this.accountIds = const {},
    this.sourceIds = const {},
    this.taskListIds = const {},
    this.sourceFilterActive = false,
    this.taskListFilterActive = false,
    this.includeCalendarEvents = true,
    this.includeTasks = true,
    this.query = '',
    this.showCompletedTasks = false,
    this.showNoDateTasks = true,
  });

  final Set<String> accountIds;
  final Set<String> sourceIds;
  final Set<String> taskListIds;
  final bool sourceFilterActive;
  final bool taskListFilterActive;
  final bool includeCalendarEvents;
  final bool includeTasks;
  final String query;
  final bool showCompletedTasks;
  final bool showNoDateTasks;
}

import 'package:collection/collection.dart';

import 'schedule_filters.dart';
import 'schedule_range.dart';

enum ScheduleSearchType { all, events, tasks }

enum ScheduleSearchDate { any, today, tomorrow, thisWeek, custom }

/// One immutable snapshot of a temporary search session. Set contents have
/// value equality, so providers and caches invalidate for every criterion.
class ScheduleSearchCriteria {
  ScheduleSearchCriteria({
    this.type = ScheduleSearchType.all,
    this.date = ScheduleSearchDate.any,
    this.taskCompletion = ScheduleTaskCompletion.all,
    this.taskDueState = ScheduleTaskDueState.any,
    this.person = '',
    this.location = '',
    this.customStart,
    this.customEnd,
    required this.referenceDate,
    required this.firstWeekday,
    required Set<String> sourceIds,
    required Set<ScheduleTaskListKey> taskListKeys,
  }) : sourceIds = Set.unmodifiable(sourceIds),
       taskListKeys = Set.unmodifiable(taskListKeys);

  final ScheduleSearchType type;
  final ScheduleSearchDate date;
  final ScheduleTaskCompletion taskCompletion;
  final ScheduleTaskDueState taskDueState;
  final String person;
  final String location;
  final DateTime? customStart;
  final DateTime? customEnd;
  final DateTime referenceDate;
  final int firstWeekday;
  final Set<String> sourceIds;
  final Set<ScheduleTaskListKey> taskListKeys;
  bool get includesEvents => type != ScheduleSearchType.tasks;
  bool get includesTasks => type != ScheduleSearchType.events;
  bool get hasSources =>
      (includesEvents && sourceIds.isNotEmpty) ||
      (includesTasks && taskListKeys.isNotEmpty);

  ScheduleRange? get range => switch (date) {
    ScheduleSearchDate.any => null,
    ScheduleSearchDate.today => ScheduleRange.day(referenceDate),
    ScheduleSearchDate.tomorrow => ScheduleRange.day(
      DateTime(referenceDate.year, referenceDate.month, referenceDate.day + 1),
    ),
    ScheduleSearchDate.thisWeek => ScheduleRange.week(
      referenceDate,
      firstWeekday: firstWeekday,
    ),
    ScheduleSearchDate.custom => ScheduleRange(
      start: customStart ?? ScheduleRange.day(referenceDate).start,
      end: DateTime(
        (customEnd ?? referenceDate).year,
        (customEnd ?? referenceDate).month,
        (customEnd ?? referenceDate).day + 1,
      ),
    ),
  };

  ScheduleFilters filters(String query) => ScheduleFilters(
    query: query,
    sourceIds: sourceIds,
    taskListKeys: taskListKeys,
    sourceFilterActive: true,
    taskListFilterActive: true,
    includeCalendarEvents: includesEvents,
    includeTasks: includesTasks,
    ignoreDateRange: date == ScheduleSearchDate.any,
    useTaskDueDate: true,
    taskCompletion: taskCompletion,
    taskDueState: taskDueState,
    referenceDate: referenceDate,
    person: includesEvents ? person : '',
    location: location,
  );

  ScheduleSearchCriteria copyWith({
    ScheduleSearchType? type,
    ScheduleSearchDate? date,
    ScheduleTaskCompletion? taskCompletion,
    ScheduleTaskDueState? taskDueState,
    String? person,
    String? location,
    DateTime? customStart,
    DateTime? customEnd,
    int? firstWeekday,
    Set<String>? sourceIds,
    Set<ScheduleTaskListKey>? taskListKeys,
  }) => ScheduleSearchCriteria(
    type: type ?? this.type,
    date: date ?? this.date,
    taskCompletion: taskCompletion ?? this.taskCompletion,
    taskDueState: taskDueState ?? this.taskDueState,
    person: type == ScheduleSearchType.tasks ? '' : person ?? this.person,
    location: location ?? this.location,
    customStart: customStart ?? this.customStart,
    customEnd: customEnd ?? this.customEnd,
    referenceDate: referenceDate,
    firstWeekday: firstWeekday ?? this.firstWeekday,
    sourceIds: sourceIds ?? this.sourceIds,
    taskListKeys: taskListKeys ?? this.taskListKeys,
  );

  Object get _values => (
    type,
    date,
    taskCompletion,
    taskDueState,
    person,
    location,
    customStart,
    customEnd,
    referenceDate,
    firstWeekday,
  );
  @override
  bool operator ==(Object other) =>
      other is ScheduleSearchCriteria &&
      _values == other._values &&
      const SetEquality<String>().equals(sourceIds, other.sourceIds) &&
      const SetEquality<ScheduleTaskListKey>().equals(
        taskListKeys,
        other.taskListKeys,
      );
  @override
  int get hashCode => Object.hash(
    _values,
    const SetEquality<String>().hash(sourceIds),
    const SetEquality<ScheduleTaskListKey>().hash(taskListKeys),
  );
}

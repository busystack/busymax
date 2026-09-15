import '../../../../l10n/generated/app_localizations.dart';
import '../../../schedule/schedule_search_criteria.dart';
import '../../../schedule/schedule_filters.dart';

String searchTypeLabel(AppLocalizations l, ScheduleSearchType v) => switch (v) {
  ScheduleSearchType.all => l.all,
  ScheduleSearchType.events => l.calendarEvents,
  ScheduleSearchType.tasks => l.tasks,
};
String searchDateLabel(AppLocalizations l, ScheduleSearchDate v) => switch (v) {
  ScheduleSearchDate.any => l.searchAnyDate,
  ScheduleSearchDate.today => l.today,
  ScheduleSearchDate.tomorrow => l.tomorrow,
  ScheduleSearchDate.thisWeek => l.searchThisWeek,
  ScheduleSearchDate.custom => l.searchCustomRange,
};
String searchCompletionLabel(AppLocalizations l, ScheduleTaskCompletion v) =>
    switch (v) {
      ScheduleTaskCompletion.all => l.all,
      ScheduleTaskCompletion.open => l.openStatus,
      ScheduleTaskCompletion.completed => l.completed,
    };
String searchDueLabel(AppLocalizations l, ScheduleTaskDueState v) =>
    switch (v) {
      ScheduleTaskDueState.any => l.searchAnyDueState,
      ScheduleTaskDueState.overdue => l.overdue,
      ScheduleTaskDueState.noDueDate => l.searchNoDueDate,
    };

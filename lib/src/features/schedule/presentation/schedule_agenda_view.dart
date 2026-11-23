import '../../../ui/common/schedule/schedule_agenda_view.dart' as shared;
import 'schedule_linux_presentation.dart';

export '../../../ui/common/schedule/schedule_agenda_view.dart'
    hide ScheduleAgendaView;

class ScheduleAgendaView extends shared.ScheduleAgendaView {
  const ScheduleAgendaView({
    super.key,
    required super.range,
    required super.items,
    required super.onItemSelected,
    required super.onTaskCompletionChanged,
    super.onChecklistItemCompletionChanged,
    super.hasMoreOverdueTasks = false,
    super.hasMoreNoDateTasks = false,
    super.onLoadMore,
    super.onLoadMoreOverdue,
    super.onLoadMoreNoDate,
    super.onItemAnchorAvailable,
    super.searchCriteria,
    super.searchQuery = '',
    super.taskListMutationIntent,
    super.onTaskListMutationConsumed,
    super.emptyBuilder,
  }) : super(presentation: const LinuxSchedulePresentation());
}

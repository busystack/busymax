import '../../../ui/common/schedule/schedule_month_view.dart' as shared;
import 'schedule_linux_presentation.dart';
export '../../../ui/common/schedule/schedule_month_view.dart'
    hide ScheduleMonthView;

class ScheduleMonthView extends shared.ScheduleMonthView {
  const ScheduleMonthView({
    super.key,
    required super.range,
    required super.selectedDate,
    required super.items,
    required super.firstWeekday,
    required super.onDaySelected,
    required super.onCreateAtDay,
    required super.onItemSelected,
    required super.onTaskCompletionChanged,
    super.onReschedule,
  }) : super(presentation: const LinuxSchedulePresentation());
}

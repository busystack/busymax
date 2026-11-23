import '../../../ui/common/schedule/schedule_year_view.dart' as shared;
import 'schedule_linux_presentation.dart';

export '../../../ui/common/schedule/schedule_year_view.dart'
    hide ScheduleYearView;

class ScheduleYearView extends shared.ScheduleYearView {
  const ScheduleYearView({
    super.key,
    required super.selectedDate,
    required super.items,
    required super.firstWeekday,
    required super.onDaySelected,
    required super.onMonthSelected,
    required super.onWeekSelected,
    required super.onCreateAtDay,
    super.compact = false,
    super.backgroundColor,
  }) : super(presentation: const LinuxSchedulePresentation());
}

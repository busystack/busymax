import '../../../app/app_settings.dart';
import '../../../ui/common/schedule/schedule_day_week_view.dart' as shared;
import 'schedule_linux_presentation.dart';

export '../../../ui/common/schedule/schedule_day_week_view.dart'
    hide ScheduleDayWeekView;

class ScheduleDayWeekView extends shared.ScheduleDayWeekView {
  const ScheduleDayWeekView({
    super.key,
    required super.range,
    required super.selectedDate,
    required super.daysShowed,
    required super.items,
    required super.onDaySelected,
    required super.onEmptySlot,
    required super.onItemSelected,
    required super.onTaskCompletionChanged,
    super.dayStartMinute = defaultScheduleDayStartMinute,
    super.dayEndMinute = defaultScheduleDayEndMinute,
    super.onRangeCreated,
    super.onReschedule,
    super.navigationIntent,
  }) : super(presentation: const LinuxSchedulePresentation());
}

import '../../../ui/common/schedule/mini_calendar.dart' as shared;
import 'schedule_linux_presentation.dart';

export '../../../ui/common/schedule/mini_calendar.dart'
    hide MiniCalendar, YearMonthMiniCalendar, MiniCalendarGrid;

class MiniCalendar extends shared.MiniCalendar {
  const MiniCalendar({
    super.key,
    required super.selectedDate,
    required super.firstWeekday,
    super.items = const [],
    required super.onSelected,
    required super.onMonthSelected,
    required super.onYearSelected,
    required super.onWeekSelected,
  }) : super(presentation: const LinuxSchedulePresentation());
}

class YearMonthMiniCalendar extends shared.YearMonthMiniCalendar {
  const YearMonthMiniCalendar({
    super.key,
    required super.displayedMonth,
    required super.selectedDate,
    required super.firstWeekday,
    required super.markerColorsByDay,
    required super.onDaySelected,
    required super.onMonthSelected,
    required super.onWeekSelected,
    required super.onDayDoubleTap,
  }) : super(presentation: const LinuxSchedulePresentation());
}

class MiniCalendarGrid extends shared.MiniCalendarGrid {
  const MiniCalendarGrid({
    super.key,
    required super.displayedMonth,
    required super.selectedDate,
    required super.firstWeekday,
    required super.onDaySelected,
    super.markerColorsByDay = const {},
    super.highlightSelectedDateOutsideMonth = true,
    super.shrinkToFitHeight = false,
    super.onWeekSelected,
    super.onDayDoubleTap,
  }) : super(presentation: const LinuxSchedulePresentation());
}

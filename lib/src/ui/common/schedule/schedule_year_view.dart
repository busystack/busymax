import 'package:busymax/src/ui/common/flutter_material.dart';

import 'schedule_presentation.dart';
import '../../../app/busymax_surface_colors.dart';
import '../../../schedule/schedule_item.dart';
import 'mini_calendar.dart';

class ScheduleYearView extends StatelessWidget {
  const ScheduleYearView({
    super.key,
    this.presentation,
    required this.selectedDate,
    required this.items,
    required this.firstWeekday,
    required this.onDaySelected,
    required this.onMonthSelected,
    required this.onWeekSelected,
    required this.onCreateAtDay,
    this.compact = false,
    this.backgroundColor,
  });

  final SchedulePresentation? presentation;

  final DateTime selectedDate;
  final List<ScheduleItem> items;
  final int firstWeekday;
  final ValueChanged<DateTime> onDaySelected;
  final ValueChanged<DateTime> onMonthSelected;
  final ValueChanged<DateTime> onWeekSelected;
  final ValueChanged<DateTime> onCreateAtDay;
  final bool compact;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) => SchedulePresentationScope(
    presentation: presentation,
    child: Builder(builder: _build),
  );

  Widget _build(BuildContext context) {
    final markerColorsByDay = miniCalendarMarkerColorsForItems(context, items);
    return LayoutBuilder(
      builder: (context, constraints) {
        var columns = _columnCount(constraints.maxWidth, compact: compact);
        if (SchedulePresentation.of(context).touch) {
          final minimumWidth = miniCalendarMinimumReadableWidth(context);
          while (columns > 1 &&
              (constraints.maxWidth - ScheduleSpacing.md * (columns + 1)) /
                      columns <
                  minimumWidth) {
            columns--;
          }
        }
        final horizontalPadding = ScheduleSpacing.md * 2;
        final columnGaps = ScheduleSpacing.md * (columns - 1);
        final monthWidth =
            (constraints.maxWidth - horizontalPadding - columnGaps) / columns;

        return ColoredBox(
          color: backgroundColor ?? BusyMaxSurfaceColors.of(context).window,
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(ScheduleSpacing.md),
              child: Wrap(
                spacing: ScheduleSpacing.md,
                runSpacing: ScheduleSpacing.md,
                children: [
                  for (var index = 0; index < DateTime.monthsPerYear; index++)
                    SizedBox(
                      width: monthWidth,
                      child: ScheduleGroupedSurface(
                        child: YearMonthMiniCalendar(
                          displayedMonth: DateTime(
                            selectedDate.year,
                            index + 1,
                          ),
                          selectedDate: selectedDate,
                          firstWeekday: firstWeekday,
                          markerColorsByDay: markerColorsByDay,
                          onDaySelected: onDaySelected,
                          onMonthSelected: onMonthSelected,
                          onWeekSelected: onWeekSelected,
                          onDayDoubleTap: onCreateAtDay,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

int _columnCount(double width, {required bool compact}) {
  if (width >= 900) {
    return 4;
  }
  if (width >= 680) {
    return 3;
  }
  if (width >= 520) {
    return 2;
  }
  return 1;
}

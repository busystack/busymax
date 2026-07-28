import 'package:flutter/material.dart';

import '../../../app/busymax_design.dart';
import '../../../app/busymax_surface_colors.dart';
import '../../../schedule/schedule_item.dart';
import 'mini_calendar.dart';

class ScheduleYearView extends StatelessWidget {
  const ScheduleYearView({
    super.key,
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
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = _columnCount(constraints.maxWidth, compact: compact);
        final horizontalPadding = BusyMaxSpacing.md * 2;
        final columnGaps = BusyMaxSpacing.md * (columns - 1);
        final monthWidth =
            (constraints.maxWidth - horizontalPadding - columnGaps) / columns;

        return ColoredBox(
          color: backgroundColor ?? BusyMaxSurfaceColors.of(context).window,
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(BusyMaxSpacing.md),
              child: Wrap(
                spacing: BusyMaxSpacing.md,
                runSpacing: BusyMaxSpacing.md,
                children: [
                  for (var index = 0; index < DateTime.monthsPerYear; index++)
                    SizedBox(
                      width: monthWidth,
                      child: BusyMaxGroupedSurface(
                        child: MiniCalendar(
                          displayedMonth: DateTime(
                            selectedDate.year,
                            index + 1,
                          ),
                          selectedDate: selectedDate,
                          firstWeekday: firstWeekday,
                          items: items,
                          headerStyle: MiniCalendarHeaderStyle.monthLabel,
                          showDayHover: true,
                          weekNumbersInteractive: true,
                          onSelected: onDaySelected,
                          onMonthSelected: onMonthSelected,
                          onYearSelected: null,
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
  if (width >= 460) {
    return 2;
  }
  return compact && width >= 360 ? 2 : 1;
}

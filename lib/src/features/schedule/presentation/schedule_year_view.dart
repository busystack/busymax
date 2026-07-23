import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:yaru/yaru.dart';

import '../../../app/busymax_design.dart';
import '../../../app/busymax_surface_colors.dart';
import '../../../schedule/schedule_item.dart';
import '../../../schedule/schedule_projection.dart';
import 'calendar_day_semantics.dart';

class ScheduleYearView extends StatelessWidget {
  const ScheduleYearView({
    super.key,
    required this.selectedDate,
    required this.items,
    required this.firstWeekday,
    required this.onDaySelected,
    required this.onMonthSelected,
    required this.onCreateAtDay,
  });

  final DateTime selectedDate;
  final List<ScheduleItem> items;
  final int firstWeekday;
  final ValueChanged<DateTime> onDaySelected;
  final ValueChanged<DateTime> onMonthSelected;
  final ValueChanged<DateTime> onCreateAtDay;

  @override
  Widget build(BuildContext context) {
    final grouped = ScheduleProjection.groupByDay(items);
    final locale = Localizations.localeOf(context).toLanguageTag();

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = _columnCount(constraints.maxWidth);
        final horizontalPadding = BusyMaxSpacing.md * 2;
        final columnGaps = BusyMaxSpacing.md * (columns - 1);
        final monthWidth =
            (constraints.maxWidth - horizontalPadding - columnGaps) / columns;
        final monthHeight = _monthPanelHeight(monthWidth);

        return ColoredBox(
          color: Theme.of(context).colorScheme.surface,
          child: GridView.builder(
            padding: const EdgeInsets.all(BusyMaxSpacing.md),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              mainAxisSpacing: BusyMaxSpacing.md,
              crossAxisSpacing: BusyMaxSpacing.md,
              mainAxisExtent: monthHeight,
            ),
            itemCount: DateTime.monthsPerYear,
            itemBuilder: (context, index) {
              final month = DateTime(selectedDate.year, index + 1);
              return _YearMonthPanel(
                month: month,
                selectedDate: selectedDate,
                groupedItems: grouped,
                firstWeekday: firstWeekday,
                locale: locale,
                onDaySelected: onDaySelected,
                onMonthSelected: onMonthSelected,
                onCreateAtDay: onCreateAtDay,
              );
            },
          ),
        );
      },
    );
  }
}

class _YearMonthPanel extends StatelessWidget {
  const _YearMonthPanel({
    required this.month,
    required this.selectedDate,
    required this.groupedItems,
    required this.firstWeekday,
    required this.locale,
    required this.onDaySelected,
    required this.onMonthSelected,
    required this.onCreateAtDay,
  });

  final DateTime month;
  final DateTime selectedDate;
  final Map<DateTime, List<ScheduleItem>> groupedItems;
  final int firstWeekday;
  final String locale;
  final ValueChanged<DateTime> onDaySelected;
  final ValueChanged<DateTime> onMonthSelected;
  final ValueChanged<DateTime> onCreateAtDay;

  @override
  Widget build(BuildContext context) {
    return BusyMaxGroupedSurface(
      child: Column(
        children: [
          BusyMaxActionRow(
            title: DateFormat.MMMM(locale).format(month),
            trailing: const Icon(YaruIcons.pan_end, size: BusyMaxSizes.iconSm),
            onTap: () => onMonthSelected(month),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                BusyMaxSpacing.sm,
                0,
                BusyMaxSpacing.sm,
                BusyMaxSpacing.sm,
              ),
              child: _YearMonthGrid(
                month: month,
                selectedDate: selectedDate,
                groupedItems: groupedItems,
                firstWeekday: firstWeekday,
                locale: locale,
                onDaySelected: onDaySelected,
                onCreateAtDay: onCreateAtDay,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _YearMonthGrid extends StatelessWidget {
  const _YearMonthGrid({
    required this.month,
    required this.selectedDate,
    required this.groupedItems,
    required this.firstWeekday,
    required this.locale,
    required this.onDaySelected,
    required this.onCreateAtDay,
  });

  final DateTime month;
  final DateTime selectedDate;
  final Map<DateTime, List<ScheduleItem>> groupedItems;
  final int firstWeekday;
  final String locale;
  final ValueChanged<DateTime> onDaySelected;
  final ValueChanged<DateTime> onCreateAtDay;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final days = _monthCells(month, firstWeekday);

    return Column(
      children: [
        SizedBox(
          height: 18,
          child: Row(
            children: [
              for (final weekday in _weekdays(firstWeekday))
                Expanded(
                  child: Center(
                    child: Text(
                      DateFormat.E(locale).format(_weekdayDate(weekday)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: BusyMaxSpacing.xs),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final rowHeight = math.max(0.0, constraints.maxHeight / 6);
              return GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: DateTime.daysPerWeek,
                  mainAxisExtent: rowHeight,
                ),
                itemCount: days.length,
                itemBuilder: (context, index) {
                  final day = days[index];
                  if (day == null) {
                    return const SizedBox.shrink();
                  }
                  final key = ScheduleProjection.day(day);
                  return _YearDayCell(
                    day: day,
                    selected: DateUtils.isSameDay(day, selectedDate),
                    today: DateUtils.isSameDay(day, DateTime.now()),
                    items: groupedItems[key] ?? const [],
                    onSelected: () => onDaySelected(day),
                    onCreate: () => onCreateAtDay(day),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _YearDayCell extends StatelessWidget {
  const _YearDayCell({
    required this.day,
    required this.selected,
    required this.today,
    required this.items,
    required this.onSelected,
    required this.onCreate,
  });

  final DateTime day;
  final bool selected;
  final bool today;
  final List<ScheduleItem> items;
  final VoidCallback onSelected;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final surfaceColors = BusyMaxSurfaceColors.of(context);
    return BusyMaxCalendarDaySemantics(
      day: day,
      selected: selected,
      onTap: onSelected,
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxHeight <= 0) {
            return const SizedBox.shrink();
          }
          final canShowIndicators =
              items.isNotEmpty && constraints.maxHeight >= 24;
          final indicatorHeight = canShowIndicators ? 4.0 : 0.0;
          final markerSize = math.min(
            22.0,
            math.max(
              14.0,
              constraints.maxHeight -
                  indicatorHeight -
                  (canShowIndicators ? BusyMaxSpacing.xxs : 0),
            ),
          );
          final textColor = selected
              ? colorScheme.onPrimary
              : today
              ? surfaceColors.foreground
              : colorScheme.onSurface;
          final markerColor = selected
              ? colorScheme.primary
              : today
              ? surfaceColors.controlActive
              : Colors.transparent;

          return InkWell(
            borderRadius: BorderRadius.circular(BusyMaxRadius.headerButton),
            onTap: onSelected,
            onDoubleTap: onCreate,
            excludeFromSemantics: true,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  key: ValueKey('year-day-marker-${day.toIso8601String()}'),
                  width: markerSize,
                  height: markerSize,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: markerColor,
                    shape: BoxShape.circle,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        '${day.day}',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: textColor,
                          fontWeight: selected || today
                              ? FontWeight.w600
                              : null,
                        ),
                      ),
                    ),
                  ),
                ),
                if (canShowIndicators) ...[
                  const SizedBox(height: BusyMaxSpacing.xxs),
                  _YearDayIndicators(items: items, height: indicatorHeight),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _YearDayIndicators extends StatelessWidget {
  const _YearDayIndicators({required this.items, required this.height});

  final List<ScheduleItem> items;
  final double height;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return SizedBox(height: height);
    }
    final brightness = Theme.of(context).brightness;
    return SizedBox(
      height: height,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (final item in items.take(3))
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: ScheduleProjection.colorForItem(item, brightness),
                  shape: BoxShape.circle,
                ),
                child: const SizedBox.square(dimension: 4),
              ),
            ),
        ],
      ),
    );
  }
}

int _columnCount(double width) {
  if (width >= 1120) {
    return 4;
  }
  if (width >= 760) {
    return 3;
  }
  if (width >= 520) {
    return 2;
  }
  return 1;
}

double _monthPanelHeight(double width) {
  return width < 280 ? 276 : math.min(340, math.max(292, width * 0.72));
}

List<DateTime?> _monthCells(DateTime month, int firstWeekday) {
  final first = DateTime(month.year, month.month);
  final leading = (first.weekday - firstWeekday) % DateTime.daysPerWeek;
  final daysInMonth = DateUtils.getDaysInMonth(month.year, month.month);
  return [
    for (var index = 0; index < DateTime.daysPerWeek * 6; index++)
      if (index >= leading && index < leading + daysInMonth)
        DateTime(month.year, month.month, index - leading + 1)
      else
        null,
  ];
}

List<int> _weekdays(int firstWeekday) {
  return [
    for (var offset = 0; offset < DateTime.daysPerWeek; offset++)
      ((firstWeekday + offset - 1) % DateTime.daysPerWeek) + 1,
  ];
}

DateTime _weekdayDate(int weekday) {
  return DateTime(2024, 1, 1).add(Duration(days: weekday - 1));
}

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:yaru/yaru.dart';

import '../../../app/busymax_design.dart';
import '../../../schedule/schedule_item.dart';
import '../../../schedule/schedule_projection.dart';

class MiniCalendar extends StatelessWidget {
  const MiniCalendar({
    super.key,
    required this.selectedDate,
    required this.firstWeekday,
    this.items = const [],
    required this.onSelected,
    required this.onMonthSelected,
    required this.onYearSelected,
    required this.onWeekSelected,
  });

  final DateTime selectedDate;
  final int firstWeekday;
  final List<ScheduleItem> items;
  final ValueChanged<DateTime> onSelected;
  final ValueChanged<DateTime> onMonthSelected;
  final ValueChanged<DateTime> onYearSelected;
  final ValueChanged<DateTime> onWeekSelected;

  @override
  Widget build(BuildContext context) {
    final first = DateTime(selectedDate.year, selectedDate.month);
    final start = first.subtract(
      Duration(days: (first.weekday - firstWeekday) % DateTime.daysPerWeek),
    );
    final groupedItems = ScheduleProjection.groupByDay(items);
    final locale = Localizations.localeOf(context).toLanguageTag();
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        BusyMaxSpacing.headerInset,
        BusyMaxSpacing.headerInset,
        BusyMaxSpacing.headerInset,
        BusyMaxSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: _MiniCalendarStepper(
                  label: _monthName(selectedDate),
                  previousTooltip: 'Previous month',
                  nextTooltip: 'Next month',
                  onPrevious: () => onSelected(
                    DateTime(selectedDate.year, selectedDate.month - 1),
                  ),
                  onNext: () => onSelected(
                    DateTime(selectedDate.year, selectedDate.month + 1),
                  ),
                  labelTooltip: 'Open month',
                  onLabelPressed: () => onMonthSelected(first),
                ),
              ),
              const SizedBox(width: BusyMaxSpacing.sm),
              Expanded(
                child: _MiniCalendarStepper(
                  label: '${selectedDate.year}',
                  previousTooltip: 'Previous year',
                  nextTooltip: 'Next year',
                  onPrevious: () => onSelected(
                    DateTime(selectedDate.year - 1, selectedDate.month),
                  ),
                  onNext: () => onSelected(
                    DateTime(selectedDate.year + 1, selectedDate.month),
                  ),
                  labelTooltip: 'Open year',
                  onLabelPressed: () =>
                      onYearSelected(DateTime(selectedDate.year)),
                ),
              ),
            ],
          ),
          const SizedBox(height: BusyMaxSpacing.sm),
          LayoutBuilder(
            builder: (context, constraints) {
              final weekNumberExtent = math.min(
                BusyMaxSizes.miniCalendarWeekButton,
                constraints.maxWidth / (DateTime.daysPerWeek + 1),
              );
              final dayExtent =
                  math.max(0.0, constraints.maxWidth - weekNumberExtent) /
                  DateTime.daysPerWeek;
              const weekdayHeaderHeight = 18.0;
              return SizedBox(
                width: double.infinity,
                height: weekdayHeaderHeight + BusyMaxSpacing.xs + dayExtent * 6,
                child: Column(
                  children: [
                    SizedBox(
                      height: weekdayHeaderHeight,
                      child: Row(
                        children: [
                          SizedBox(width: weekNumberExtent),
                          for (final weekday in _weekdays(firstWeekday))
                            Expanded(
                              child: Center(
                                child: Text(
                                  DateFormat.E(
                                    locale,
                                  ).format(_weekdayDate(weekday)),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.labelSmall
                                      ?.copyWith(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSurfaceVariant,
                                      ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: BusyMaxSpacing.xs),
                    for (var row = 0; row < 6; row++)
                      SizedBox(
                        height: dayExtent,
                        child: _MiniCalendarWeekRow(
                          weekStart: start.add(
                            Duration(days: row * DateTime.daysPerWeek),
                          ),
                          weekNumberExtent: weekNumberExtent,
                          selectedMonth: selectedDate.month,
                          selectedYear: selectedDate.year,
                          groupedItems: groupedItems,
                          locale: locale,
                          onDaySelected: onSelected,
                          onWeekSelected: onWeekSelected,
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _MiniCalendarWeekRow extends StatelessWidget {
  const _MiniCalendarWeekRow({
    required this.weekStart,
    required this.weekNumberExtent,
    required this.selectedMonth,
    required this.selectedYear,
    required this.groupedItems,
    required this.locale,
    required this.onDaySelected,
    required this.onWeekSelected,
  });

  final DateTime weekStart;
  final double weekNumberExtent;
  final int selectedMonth;
  final int selectedYear;
  final Map<DateTime, List<ScheduleItem>> groupedItems;
  final String locale;
  final ValueChanged<DateTime> onDaySelected;
  final ValueChanged<DateTime> onWeekSelected;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: weekNumberExtent,
          child: _MiniCalendarWeekNumberButton(
            weekStart: weekStart,
            onSelected: onWeekSelected,
          ),
        ),
        for (var column = 0; column < DateTime.daysPerWeek; column++)
          Expanded(
            child: _MiniCalendarDayButton(
              day: weekStart.add(Duration(days: column)),
              selectedMonth: selectedMonth,
              selectedYear: selectedYear,
              groupedItems: groupedItems,
              locale: locale,
              onSelected: onDaySelected,
            ),
          ),
      ],
    );
  }
}

class _MiniCalendarWeekNumberButton extends StatelessWidget {
  const _MiniCalendarWeekNumberButton({
    required this.weekStart,
    required this.onSelected,
  });

  final DateTime weekStart;
  final ValueChanged<DateTime> onSelected;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final weekNumber = _isoWeekNumber(weekStart);
    return Center(
      child: Tooltip(
        message: 'Week $weekNumber',
        child: TextButton(
          onPressed: () => onSelected(weekStart),
          style:
              busyMaxHeaderIconButtonStyle(
                foregroundColor: colorScheme.onSurfaceVariant,
                backgroundColor: busyMaxHeaderButtonBackground(context),
                overlayColor: const WidgetStatePropertyAll(Colors.transparent),
              ).copyWith(
                fixedSize: const WidgetStatePropertyAll(
                  Size.square(BusyMaxSizes.miniCalendarWeekButton),
                ),
                minimumSize: const WidgetStatePropertyAll(
                  Size.square(BusyMaxSizes.miniCalendarWeekButton),
                ),
                maximumSize: const WidgetStatePropertyAll(
                  Size.square(BusyMaxSizes.miniCalendarWeekButton),
                ),
              ),
          child: Text(
            '$weekNumber',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.72),
            ),
          ),
        ),
      ),
    );
  }
}

class _MiniCalendarDayButton extends StatelessWidget {
  const _MiniCalendarDayButton({
    required this.day,
    required this.selectedMonth,
    required this.selectedYear,
    required this.groupedItems,
    required this.locale,
    required this.onSelected,
  });

  final DateTime day;
  final int selectedMonth;
  final int selectedYear;
  final Map<DateTime, List<ScheduleItem>> groupedItems;
  final String locale;
  final ValueChanged<DateTime> onSelected;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final today = _sameDay(day, DateTime.now());
    final currentMonth =
        selectedYear == DateTime.now().year &&
        selectedMonth == DateTime.now().month;
    final highlightToday = today && currentMonth;
    final items =
        groupedItems[ScheduleProjection.day(day)] ?? const <ScheduleItem>[];

    return Tooltip(
      message: DateFormat.yMMMMEEEEd(locale).format(day),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final canShowIndicators =
              items.isNotEmpty && constraints.maxHeight >= 28;
          final indicatorHeight = canShowIndicators ? 4.0 : 0.0;
          final markerSize = math.min(
            24.0,
            math.max(
              18.0,
              constraints.maxHeight -
                  indicatorHeight -
                  (canShowIndicators ? BusyMaxSpacing.xxs : 0),
            ),
          );
          return InkWell(
            onTap: () => onSelected(day),
            customBorder: const CircleBorder(),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox.square(
                  dimension: markerSize,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: highlightToday ? colorScheme.primary : null,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          '${day.day}',
                          style: TextStyle(
                            color: highlightToday
                                ? colorScheme.onPrimary
                                : day.month == selectedMonth
                                ? null
                                : colorScheme.onSurfaceVariant,
                            fontWeight: highlightToday ? FontWeight.w600 : null,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                if (canShowIndicators) ...[
                  const SizedBox(height: BusyMaxSpacing.xxs),
                  _MiniCalendarDayIndicators(
                    items: items,
                    height: indicatorHeight,
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _MiniCalendarDayIndicators extends StatelessWidget {
  const _MiniCalendarDayIndicators({required this.items, required this.height});

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

class _MiniCalendarStepper extends StatelessWidget {
  const _MiniCalendarStepper({
    required this.label,
    required this.previousTooltip,
    required this.nextTooltip,
    required this.onPrevious,
    required this.onNext,
    this.labelTooltip,
    this.onLabelPressed,
  });

  final String label;
  final String previousTooltip;
  final String nextTooltip;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final String? labelTooltip;
  final VoidCallback? onLabelPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        YaruIconButton(
          tooltip: previousTooltip,
          iconSize: BusyMaxSizes.headerIcon,
          icon: const Icon(YaruIcons.pan_start),
          onPressed: onPrevious,
          style: busyMaxHeaderIconButtonStyle(
            foregroundColor: colorScheme.onSurfaceVariant,
            backgroundColor: busyMaxHeaderButtonBackground(context),
            overlayColor: const WidgetStatePropertyAll(Colors.transparent),
          ),
        ),
        const SizedBox(width: BusyMaxSpacing.xs),
        Expanded(child: _label(context)),
        const SizedBox(width: BusyMaxSpacing.xs),
        YaruIconButton(
          tooltip: nextTooltip,
          iconSize: BusyMaxSizes.headerIcon,
          icon: const Icon(YaruIcons.pan_end),
          onPressed: onNext,
          style: busyMaxHeaderIconButtonStyle(
            foregroundColor: colorScheme.onSurfaceVariant,
            backgroundColor: busyMaxHeaderButtonBackground(context),
            overlayColor: const WidgetStatePropertyAll(Colors.transparent),
          ),
        ),
      ],
    );
  }

  Widget _label(BuildContext context) {
    final action = onLabelPressed;
    if (action == null) {
      return Text(
        label,
        textAlign: TextAlign.center,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: busyMaxSectionHeaderStyle(context),
      );
    }

    final colorScheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: labelTooltip ?? label,
      child: TextButton(
        onPressed: action,
        style: busyMaxHeaderTextButtonStyle(
          foregroundColor: colorScheme.onSurfaceVariant,
          backgroundColor: busyMaxHeaderButtonBackground(context),
          overlayColor: const WidgetStatePropertyAll(Colors.transparent),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: busyMaxSectionHeaderStyle(context),
        ),
      ),
    );
  }
}

String _monthName(DateTime date) {
  const months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  return months[date.month - 1];
}

bool _sameDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

int _isoWeekNumber(DateTime date) {
  final day = DateTime.utc(date.year, date.month, date.day);
  final thursday = day.add(Duration(days: DateTime.thursday - day.weekday));
  final firstWeekAnchor = DateTime.utc(thursday.year, 1, 4);
  final firstWeekStart = firstWeekAnchor.subtract(
    Duration(days: firstWeekAnchor.weekday - DateTime.monday),
  );
  return thursday.difference(firstWeekStart).inDays ~/ DateTime.daysPerWeek + 1;
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

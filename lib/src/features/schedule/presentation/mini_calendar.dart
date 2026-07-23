import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:yaru/yaru.dart';

import '../../../app/busymax_design.dart';
import '../../../app/busymax_surface_colors.dart';
import '../../../l10n/l10n.dart';
import '../../../schedule/schedule_item.dart';
import '../../../schedule/schedule_projection.dart';
import 'calendar_day_semantics.dart';

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
    final l10n = context.l10n;
    final first = DateTime(selectedDate.year, selectedDate.month);
    final start = _calendarStartForMonth(first, firstWeekday);
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
                  label: DateFormat.MMMM(locale).format(selectedDate),
                  previousTooltip: l10n.previousMonth,
                  nextTooltip: l10n.nextMonth,
                  onPrevious: () => onSelected(
                    DateTime(selectedDate.year, selectedDate.month - 1),
                  ),
                  onNext: () => onSelected(
                    DateTime(selectedDate.year, selectedDate.month + 1),
                  ),
                  labelTooltip: l10n.openMonthView,
                  onLabelPressed: () => onMonthSelected(first),
                ),
              ),
              const SizedBox(width: BusyMaxSpacing.sm),
              Expanded(
                child: _MiniCalendarStepper(
                  label: '${selectedDate.year}',
                  previousTooltip: l10n.previousYear,
                  nextTooltip: l10n.nextYear,
                  onPrevious: () => onSelected(
                    DateTime(selectedDate.year - 1, selectedDate.month),
                  ),
                  onNext: () => onSelected(
                    DateTime(selectedDate.year + 1, selectedDate.month),
                  ),
                  labelTooltip: l10n.openYearView,
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
                          weekStart: _addCalendarDays(
                            start,
                            row * DateTime.daysPerWeek,
                          ),
                          weekNumberExtent: weekNumberExtent,
                          selectedDate: selectedDate,
                          groupedItems: groupedItems,
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
    required this.selectedDate,
    required this.groupedItems,
    required this.onDaySelected,
    required this.onWeekSelected,
  });

  final DateTime weekStart;
  final double weekNumberExtent;
  final DateTime selectedDate;
  final Map<DateTime, List<ScheduleItem>> groupedItems;
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
              day: _addCalendarDays(weekStart, column),
              selectedDate: selectedDate,
              groupedItems: groupedItems,
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
        message: context.l10n.weekNumberTooltip(weekNumber),
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
    required this.selectedDate,
    required this.groupedItems,
    required this.onSelected,
  });

  final DateTime day;
  final DateTime selectedDate;
  final Map<DateTime, List<ScheduleItem>> groupedItems;
  final ValueChanged<DateTime> onSelected;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final surfaceColors = BusyMaxSurfaceColors.of(context);
    final selected = _sameDay(day, selectedDate);
    final today = _sameDay(day, DateTime.now());
    final inDisplayedMonth =
        day.year == selectedDate.year && day.month == selectedDate.month;
    final displayingCurrentMonth =
        selectedDate.year == DateTime.now().year &&
        selectedDate.month == DateTime.now().month;
    final highlightToday = today && displayingCurrentMonth;
    final items =
        groupedItems[ScheduleProjection.day(day)] ?? const <ScheduleItem>[];

    return BusyMaxCalendarDaySemantics(
      day: day,
      selected: selected,
      onTap: () => onSelected(day),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final canShowIndicators =
              items.isNotEmpty && constraints.maxHeight >= 28;
          final indicatorHeight = canShowIndicators ? 4.0 : 0.0;
          final availableMarkerExtent = math.min(
            constraints.maxWidth,
            constraints.maxHeight -
                indicatorHeight -
                (canShowIndicators ? BusyMaxSpacing.xxs : 0),
          );
          final markerSize = math.min(
            24.0,
            math.max(0.0, availableMarkerExtent),
          );
          return InkWell(
            onTap: () => onSelected(day),
            excludeFromSemantics: true,
            customBorder: const CircleBorder(),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox.square(
                  dimension: markerSize,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: selected
                          ? colorScheme.primary
                          : highlightToday
                          ? surfaceColors.controlActive
                          : null,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          '${day.day}',
                          style: TextStyle(
                            color: selected
                                ? colorScheme.onPrimary
                                : highlightToday
                                ? surfaceColors.foreground
                                : inDisplayedMonth
                                ? null
                                : colorScheme.onSurfaceVariant,
                            fontWeight: selected || highlightToday
                                ? FontWeight.w600
                                : null,
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact =
            constraints.maxWidth <
            BusyMaxSizes.headerIconButton * 2 + BusyMaxSpacing.xs * 2;
        if (compact) {
          return Row(
            children: [
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: _stepButton(
                    context,
                    colorScheme: colorScheme,
                    tooltip: previousTooltip,
                    icon: YaruIcons.pan_start,
                    onPressed: onPrevious,
                  ),
                ),
              ),
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: _stepButton(
                    context,
                    colorScheme: colorScheme,
                    tooltip: nextTooltip,
                    icon: YaruIcons.pan_end,
                    onPressed: onNext,
                  ),
                ),
              ),
            ],
          );
        }
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _stepButton(
              context,
              colorScheme: colorScheme,
              tooltip: previousTooltip,
              icon: YaruIcons.pan_start,
              onPressed: onPrevious,
            ),
            const SizedBox(width: BusyMaxSpacing.xs),
            Expanded(child: _label(context)),
            const SizedBox(width: BusyMaxSpacing.xs),
            _stepButton(
              context,
              colorScheme: colorScheme,
              tooltip: nextTooltip,
              icon: YaruIcons.pan_end,
              onPressed: onNext,
            ),
          ],
        );
      },
    );
  }

  Widget _stepButton(
    BuildContext context, {
    required ColorScheme colorScheme,
    required String tooltip,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return YaruIconButton(
      tooltip: tooltip,
      iconSize: BusyMaxSizes.headerIcon,
      icon: Icon(icon),
      onPressed: onPressed,
      style: busyMaxHeaderIconButtonStyle(
        foregroundColor: colorScheme.onSurfaceVariant,
        backgroundColor: busyMaxHeaderButtonBackground(context),
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
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

bool _sameDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

DateTime _calendarStartForMonth(DateTime first, int firstWeekday) {
  final monthWeekdayFromMonday = first.weekday - DateTime.monday;
  final firstWeekdayFromMonday = firstWeekday - DateTime.monday;
  final leadingDays =
      (monthWeekdayFromMonday - firstWeekdayFromMonday) % DateTime.daysPerWeek;
  return _addCalendarDays(first, -leadingDays);
}

DateTime _addCalendarDays(DateTime date, int days) {
  return DateTime(date.year, date.month, date.day + days);
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

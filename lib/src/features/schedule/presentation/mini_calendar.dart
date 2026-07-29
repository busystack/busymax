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

const _miniCalendarHeaderControlExtent = 28.0;
const _miniCalendarMonthControlFlex = 3;
const _miniCalendarYearControlFlex = 2;

/// Sidebar calendar with local month paging and schedule-view shortcuts.
class MiniCalendar extends StatefulWidget {
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
  State<MiniCalendar> createState() => _MiniCalendarState();
}

class _MiniCalendarState extends State<MiniCalendar> {
  late DateTime _displayedMonth;

  @override
  void initState() {
    super.initState();
    _displayedMonth = _monthOf(widget.selectedDate);
  }

  @override
  void didUpdateWidget(covariant MiniCalendar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_sameMonth(oldWidget.selectedDate, widget.selectedDate)) {
      _displayedMonth = _monthOf(widget.selectedDate);
    }
  }

  void _showMonth(DateTime month) {
    setState(() => _displayedMonth = _monthOf(month));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final visibleMonth = _displayedMonth;
    final first = DateTime(visibleMonth.year, visibleMonth.month);
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
                flex: _miniCalendarMonthControlFlex,
                child: _MiniCalendarStepper(
                  label: DateFormat.MMMM(locale).format(visibleMonth),
                  previousTooltip: l10n.previousMonth,
                  nextTooltip: l10n.nextMonth,
                  onPrevious: () => _showMonth(
                    DateTime(visibleMonth.year, visibleMonth.month - 1),
                  ),
                  onNext: () => _showMonth(
                    DateTime(visibleMonth.year, visibleMonth.month + 1),
                  ),
                  labelTooltip: l10n.openMonthView,
                  onLabelPressed: () => widget.onMonthSelected(first),
                ),
              ),
              const SizedBox(width: BusyMaxSpacing.sm),
              Expanded(
                flex: _miniCalendarYearControlFlex,
                child: _MiniCalendarStepper(
                  label: '${visibleMonth.year}',
                  previousTooltip: l10n.previousYear,
                  nextTooltip: l10n.nextYear,
                  onPrevious: () => _showMonth(
                    DateTime(visibleMonth.year - 1, visibleMonth.month),
                  ),
                  onNext: () => _showMonth(
                    DateTime(visibleMonth.year + 1, visibleMonth.month),
                  ),
                  labelTooltip: l10n.openYearView,
                  onLabelPressed: () =>
                      widget.onYearSelected(DateTime(visibleMonth.year)),
                ),
              ),
            ],
          ),
          const SizedBox(height: BusyMaxSpacing.sm),
          MiniCalendarGrid(
            displayedMonth: first,
            selectedDate: widget.selectedDate,
            firstWeekday: widget.firstWeekday,
            markerColorsByDay: miniCalendarMarkerColorsForItems(
              context,
              widget.items,
            ),
            onDaySelected: widget.onSelected,
            onWeekSelected: widget.onWeekSelected,
          ),
        ],
      ),
    );
  }
}

/// One fixed month used by each card in the year view.
class YearMonthMiniCalendar extends StatelessWidget {
  const YearMonthMiniCalendar({
    super.key,
    required this.displayedMonth,
    required this.selectedDate,
    required this.firstWeekday,
    required this.markerColorsByDay,
    required this.onDaySelected,
    required this.onMonthSelected,
    required this.onWeekSelected,
    required this.onDayDoubleTap,
  });

  final DateTime displayedMonth;
  final DateTime selectedDate;
  final int firstWeekday;
  final Map<DateTime, List<Color>> markerColorsByDay;
  final ValueChanged<DateTime> onDaySelected;
  final ValueChanged<DateTime> onMonthSelected;
  final ValueChanged<DateTime> onWeekSelected;
  final ValueChanged<DateTime> onDayDoubleTap;

  @override
  Widget build(BuildContext context) {
    final month = _monthOf(displayedMonth);
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
          _MiniCalendarHeaderLabel(
            label: DateFormat.yMMMM(locale).format(month),
            tooltip: context.l10n.openMonthView,
            onPressed: () => onMonthSelected(month),
          ),
          const SizedBox(height: BusyMaxSpacing.sm),
          MiniCalendarGrid(
            displayedMonth: month,
            selectedDate: selectedDate,
            firstWeekday: firstWeekday,
            markerColorsByDay: markerColorsByDay,
            onDaySelected: onDaySelected,
            onWeekSelected: onWeekSelected,
            onDayDoubleTap: onDayDoubleTap,
          ),
        ],
      ),
    );
  }
}

/// Shared stateless weekday, week-number, and day-cell matrix.
class MiniCalendarGrid extends StatelessWidget {
  const MiniCalendarGrid({
    super.key,
    required this.displayedMonth,
    required this.selectedDate,
    required this.firstWeekday,
    required this.onDaySelected,
    this.markerColorsByDay = const {},
    this.onWeekSelected,
    this.onDayDoubleTap,
  });

  final DateTime displayedMonth;
  final DateTime selectedDate;
  final int firstWeekday;
  final Map<DateTime, List<Color>> markerColorsByDay;
  final ValueChanged<DateTime> onDaySelected;
  final ValueChanged<DateTime>? onWeekSelected;
  final ValueChanged<DateTime>? onDayDoubleTap;

  @override
  Widget build(BuildContext context) {
    final month = _monthOf(displayedMonth);
    final start = _calendarStartForMonth(month, firstWeekday);
    final locale = Localizations.localeOf(context).toLanguageTag();
    return LayoutBuilder(
      builder: (context, constraints) {
        final maximumWeekNumberExtent = onWeekSelected == null
            ? _miniCalendarHeaderControlExtent - BusyMaxSpacing.headerInset
            : _miniCalendarHeaderControlExtent;
        final weekNumberExtent = math.min(
          maximumWeekNumberExtent,
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
                            DateFormat.E(locale).format(_weekdayDate(weekday)),
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
                    onWeekSelected: onWeekSelected,
                    selectedDate: selectedDate,
                    displayedMonth: month,
                    markerColorsByDay: markerColorsByDay,
                    onDaySelected: onDaySelected,
                    onDayDoubleTap: onDayDoubleTap,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

Map<DateTime, List<Color>> miniCalendarMarkerColorsForItems(
  BuildContext context,
  List<ScheduleItem> items,
) {
  final brightness = Theme.of(context).brightness;
  final groupedItems = ScheduleProjection.groupByDay(items);
  return {
    for (final entry in groupedItems.entries)
      entry.key: [
        for (final item in entry.value.take(3))
          ScheduleProjection.colorForItem(item, brightness),
      ],
  };
}

class _MiniCalendarWeekRow extends StatelessWidget {
  const _MiniCalendarWeekRow({
    required this.weekStart,
    required this.weekNumberExtent,
    required this.onWeekSelected,
    required this.selectedDate,
    required this.displayedMonth,
    required this.markerColorsByDay,
    required this.onDaySelected,
    required this.onDayDoubleTap,
  });

  final DateTime weekStart;
  final double weekNumberExtent;
  final ValueChanged<DateTime>? onWeekSelected;
  final DateTime selectedDate;
  final DateTime displayedMonth;
  final Map<DateTime, List<Color>> markerColorsByDay;
  final ValueChanged<DateTime> onDaySelected;
  final ValueChanged<DateTime>? onDayDoubleTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: weekNumberExtent,
          child: _MiniCalendarWeekNumberButton(
            weekStart: weekStart,
            buttonWidth: weekNumberExtent,
            onSelected: onWeekSelected,
          ),
        ),
        for (var column = 0; column < DateTime.daysPerWeek; column++)
          Expanded(
            child: _MiniCalendarDayButton(
              day: _addCalendarDays(weekStart, column),
              selectedDate: selectedDate,
              displayedMonth: displayedMonth,
              markerColorsByDay: markerColorsByDay,
              onSelected: onDaySelected,
              onDoubleTap: onDayDoubleTap,
            ),
          ),
      ],
    );
  }
}

class _MiniCalendarWeekNumberButton extends StatelessWidget {
  const _MiniCalendarWeekNumberButton({
    required this.weekStart,
    required this.buttonWidth,
    required this.onSelected,
  });

  final DateTime weekStart;
  final double buttonWidth;
  final ValueChanged<DateTime>? onSelected;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final weekNumber = _isoWeekNumber(weekStart);
    final label = Text(
      '$weekNumber',
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: colorScheme.onSurfaceVariant.withValues(alpha: 0.72),
      ),
    );
    return Center(
      child: Tooltip(
        message: context.l10n.weekNumberTooltip(weekNumber),
        child: onSelected == null
            ? SizedBox.square(
                dimension: buttonWidth,
                child: Center(child: label),
              )
            : TextButton(
                onPressed: () => onSelected!(weekStart),
                style:
                    busyMaxHeaderIconButtonStyle(
                      context,
                      foregroundColor: colorScheme.onSurfaceVariant,
                      backgroundColor: busyMaxSubtleButtonBackground(context),
                      overlayColor: const WidgetStatePropertyAll(
                        Colors.transparent,
                      ),
                    ).copyWith(
                      fixedSize: WidgetStatePropertyAll(
                        Size.square(buttonWidth),
                      ),
                      minimumSize: WidgetStatePropertyAll(
                        Size.square(buttonWidth),
                      ),
                      maximumSize: WidgetStatePropertyAll(
                        Size.square(buttonWidth),
                      ),
                    ),
                child: label,
              ),
      ),
    );
  }
}

class _MiniCalendarDayButton extends StatefulWidget {
  const _MiniCalendarDayButton({
    required this.day,
    required this.selectedDate,
    required this.displayedMonth,
    required this.markerColorsByDay,
    required this.onSelected,
    required this.onDoubleTap,
  });

  final DateTime day;
  final DateTime selectedDate;
  final DateTime displayedMonth;
  final Map<DateTime, List<Color>> markerColorsByDay;
  final ValueChanged<DateTime> onSelected;
  final ValueChanged<DateTime>? onDoubleTap;

  @override
  State<_MiniCalendarDayButton> createState() => _MiniCalendarDayButtonState();
}

class _MiniCalendarDayButtonState extends State<_MiniCalendarDayButton> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    final day = widget.day;
    final selectedDate = widget.selectedDate;
    final onSelected = widget.onSelected;
    final colorScheme = Theme.of(context).colorScheme;
    final surfaceColors = BusyMaxSurfaceColors.of(context);
    final selected = _sameDay(day, selectedDate);
    final today = _sameDay(day, DateTime.now());
    final inDisplayedMonth =
        day.year == widget.displayedMonth.year &&
        day.month == widget.displayedMonth.month;
    final displayingCurrentMonth =
        widget.displayedMonth.year == DateTime.now().year &&
        widget.displayedMonth.month == DateTime.now().month;
    final highlightToday = today && displayingCurrentMonth;
    final markerColors =
        widget.markerColorsByDay[_dayOf(day)] ?? const <Color>[];

    return BusyMaxCalendarDaySemantics(
      day: day,
      selected: selected,
      onTap: () => onSelected(day),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final canShowIndicators =
              markerColors.isNotEmpty && constraints.maxHeight >= 28;
          final indicatorHeight = canShowIndicators ? 4.0 : 0.0;
          final availableMarkerExtent = math.min(
            constraints.maxWidth,
            constraints.maxHeight -
                indicatorHeight -
                (canShowIndicators ? BusyMaxSpacing.xxs : 0),
          );
          final markerSize = math.min(
            25.5,
            math.max(0.0, availableMarkerExtent),
          );
          final hoverColor = Color.alphaBlend(
            surfaceColors.foreground.withValues(
              alpha: Theme.of(context).brightness == Brightness.light
                  ? 0.06
                  : 0.12,
            ),
            surfaceColors.card,
          );
          final hoveredMarkerSize = math.min(
            32.0,
            math.max(0.0, availableMarkerExtent),
          );
          final currentMarkerSize = _isHovering && !selected
              ? hoveredMarkerSize
              : markerSize;
          final backgroundColor = selected
              ? colorScheme.primary
              : highlightToday
              ? surfaceColors.controlActive
              : _isHovering
              ? hoverColor
              : Colors.transparent;

          return MouseRegion(
            onEnter: (_) => setState(() => _isHovering = true),
            onExit: (_) => setState(() => _isHovering = false),
            child: InkWell(
              onTap: () => onSelected(day),
              onDoubleTap: widget.onDoubleTap == null
                  ? null
                  : () => widget.onDoubleTap!(day),
              excludeFromSemantics: true,
              hoverColor: Colors.transparent,
              customBorder: const CircleBorder(),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox.square(
                    dimension: currentMarkerSize,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: backgroundColor,
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
                                  : colorScheme.onSurfaceVariant.withValues(
                                      alpha: 0.45,
                                    ),
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
                      colors: markerColors,
                      height: indicatorHeight,
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _MiniCalendarDayIndicators extends StatelessWidget {
  const _MiniCalendarDayIndicators({
    required this.colors,
    required this.height,
  });

  final List<Color> colors;
  final double height;

  @override
  Widget build(BuildContext context) {
    if (colors.isEmpty) {
      return SizedBox(height: height);
    }
    return SizedBox(
      height: height,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (final color in colors.take(3))
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1),
              child: DecoratedBox(
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
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
            _miniCalendarHeaderControlExtent * 2 + BusyMaxSpacing.xs * 2;
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
    return BusyMaxHeaderIconButton(
      tooltip: tooltip,
      iconSize: BusyMaxSizes.iconSm,
      icon: Icon(icon),
      onPressed: onPressed,
      foregroundColor: colorScheme.onSurfaceVariant,
      backgroundColor: busyMaxSubtleButtonBackground(context),
      overlayColor: const WidgetStatePropertyAll(Colors.transparent),
      fixedSize: const Size.square(_miniCalendarHeaderControlExtent),
      shape: const CircleBorder(),
    );
  }

  Widget _label(BuildContext context) {
    return _MiniCalendarHeaderLabel(
      label: label,
      tooltip: labelTooltip,
      onPressed: onLabelPressed,
    );
  }
}

class _MiniCalendarHeaderLabel extends StatelessWidget {
  const _MiniCalendarHeaderLabel({
    required this.label,
    this.tooltip,
    this.onPressed,
  });

  final String label;
  final String? tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final labelStyle = Theme.of(context).textTheme.labelMedium?.copyWith(
      color: colorScheme.onSurface,
      fontWeight: FontWeight.w600,
    );
    final labelWidget = Text(
      label,
      textAlign: TextAlign.center,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: labelStyle,
    );
    if (onPressed == null) {
      return SizedBox(
        height: _miniCalendarHeaderControlExtent,
        child: Center(child: labelWidget),
      );
    }

    return Tooltip(
      message: tooltip ?? label,
      child: TextButton(
        onPressed: onPressed,
        style:
            busyMaxHeaderTextButtonStyle(
              context,
              foregroundColor: colorScheme.onSurface,
              backgroundColor: busyMaxSubtleButtonBackground(context),
              overlayColor: const WidgetStatePropertyAll(Colors.transparent),
            ).copyWith(
              minimumSize: const WidgetStatePropertyAll(
                Size(
                  _miniCalendarHeaderControlExtent,
                  _miniCalendarHeaderControlExtent,
                ),
              ),
              maximumSize: const WidgetStatePropertyAll(
                Size(double.infinity, _miniCalendarHeaderControlExtent),
              ),
              padding: const WidgetStatePropertyAll(
                EdgeInsets.symmetric(horizontal: BusyMaxSpacing.headerInset),
              ),
            ),
        child: labelWidget,
      ),
    );
  }
}

bool _sameDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

bool _sameMonth(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month;
}

DateTime _monthOf(DateTime date) => DateTime(date.year, date.month);

DateTime _dayOf(DateTime date) => DateTime(date.year, date.month, date.day);

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

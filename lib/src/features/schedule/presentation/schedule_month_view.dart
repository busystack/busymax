import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:yaru/yaru.dart';

import '../../../app/busymax_design.dart';
import '../../../app/busymax_surface_colors.dart';
import '../../../l10n/l10n.dart';
import '../../../schedule/schedule_item.dart';
import '../../../schedule/schedule_projection.dart';
import '../../../schedule/schedule_range.dart';
import 'schedule_item_chip.dart';
import 'schedule_item_selection.dart';
import 'schedule_more_popover.dart';

class ScheduleMonthView extends StatelessWidget {
  const ScheduleMonthView({
    super.key,
    required this.range,
    required this.selectedDate,
    required this.items,
    required this.firstWeekday,
    required this.onDaySelected,
    required this.onCreateAtDay,
    required this.onItemSelected,
    required this.onTaskCompletionChanged,
  });

  final ScheduleRange range;
  final DateTime selectedDate;
  final List<ScheduleItem> items;
  final int firstWeekday;
  final ValueChanged<DateTime> onDaySelected;
  final ValueChanged<DateTime> onCreateAtDay;
  final ScheduleItemSelectionCallback onItemSelected;
  final void Function(TaskScheduleItem item, bool completed)
  onTaskCompletionChanged;

  @override
  Widget build(BuildContext context) {
    final days = _daysInRange(range);
    final rows = (days.length / DateTime.daysPerWeek).ceil();
    final locale = Localizations.localeOf(context).toLanguageTag();
    final month = DateTime(selectedDate.year, selectedDate.month);
    final grouped = ScheduleProjection.groupByDay(items);
    final theme = Theme.of(context);
    final border = theme.colorScheme.onSurface.withValues(
      alpha: theme.brightness == Brightness.dark ? 0.06 : 0.10,
    );

    return Column(
      children: [
        ColoredBox(
          color: theme.colorScheme.surface,
          child: SizedBox(
            height: 34,
            child: Row(
              children: [
                for (final weekday in _weekdays(firstWeekday))
                  Expanded(
                    child: Center(
                      child: Text(
                        DateFormat.E(locale).format(_weekdayDate(weekday)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final cellHeight = constraints.maxHeight / rows;
              return GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: DateTime.daysPerWeek,
                  mainAxisExtent: cellHeight,
                ),
                itemCount: days.length,
                itemBuilder: (context, index) {
                  final day = days[index];
                  final column = index % DateTime.daysPerWeek;
                  final row = index ~/ DateTime.daysPerWeek;
                  return DecoratedBox(
                    position: DecorationPosition.foreground,
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(color: border),
                        left: BorderSide(color: border),
                        right: column == DateTime.daysPerWeek - 1
                            ? BorderSide(color: border)
                            : BorderSide.none,
                        bottom: row == rows - 1
                            ? BorderSide(color: border)
                            : BorderSide.none,
                      ),
                    ),
                    child: _MonthDayCell(
                      day: day,
                      inCurrentMonth: day.month == month.month,
                      selected: DateUtils.isSameDay(day, selectedDate),
                      items: grouped[day] ?? const [],
                      onSelect: () => onDaySelected(day),
                      onCreate: () => onCreateAtDay(day),
                      onItemSelected: onItemSelected,
                      onTaskCompletionChanged: onTaskCompletionChanged,
                    ),
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

class _MonthDayCell extends StatelessWidget {
  const _MonthDayCell({
    required this.day,
    required this.inCurrentMonth,
    required this.selected,
    required this.items,
    required this.onSelect,
    required this.onCreate,
    required this.onItemSelected,
    required this.onTaskCompletionChanged,
  });

  final DateTime day;
  final bool inCurrentMonth;
  final bool selected;
  final List<ScheduleItem> items;
  final VoidCallback onSelect;
  final VoidCallback onCreate;
  final ScheduleItemSelectionCallback onItemSelected;
  final void Function(TaskScheduleItem item, bool completed)
  onTaskCompletionChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final surfaceColors = BusyMaxSurfaceColors.of(context);
    final today = DateUtils.isSameDay(day, DateTime.now());

    return Material(
      color: selected
          ? Color.alphaBlend(surfaceColors.control, colorScheme.surface)
          : colorScheme.surface,
      child: InkWell(
        onTap: onSelect,
        onDoubleTap: onCreate,
        child: LayoutBuilder(
          builder: (context, constraints) {
            const headerHeight = 24.0;
            const itemHeight = 22.0;
            const moreHeight = 24.0;
            const itemGap = BusyMaxSpacing.xs;
            final contentHeight = math.max(
              0.0,
              constraints.maxHeight - BusyMaxSpacing.xs * 2,
            );
            final availableRowsHeight = math.max(
              0.0,
              contentHeight - headerHeight - itemGap,
            );
            final rowSlots = (availableRowsHeight / (itemHeight + itemGap))
                .floor();
            final needsOverflowRow = items.length > rowSlots;
            final visibleCount = needsOverflowRow
                ? math.max(0, rowSlots - 1)
                : math.min(items.length, rowSlots);
            final visible = items.take(visibleCount).toList();
            final overflow = items.length - visible.length;
            final showOverflow =
                overflow > 0 && availableRowsHeight >= moreHeight;

            if (contentHeight < headerHeight + itemGap) {
              return Padding(
                padding: const EdgeInsets.all(BusyMaxSpacing.xs),
                child: Align(
                  alignment: AlignmentDirectional.topStart,
                  child: SizedBox(
                    width: 26,
                    height: contentHeight,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: AlignmentDirectional.topStart,
                      child: _MonthDayNumber(
                        day: day,
                        selected: selected,
                        today: today,
                        inCurrentMonth: inCurrentMonth,
                      ),
                    ),
                  ),
                ),
              );
            }

            return Padding(
              padding: const EdgeInsets.all(BusyMaxSpacing.xs),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      _MonthDayNumber(
                        day: day,
                        selected: selected,
                        today: today,
                        inCurrentMonth: inCurrentMonth,
                      ),
                      const Spacer(),
                      if (selected)
                        SizedBox.square(
                          dimension: 24,
                          child: YaruIconButton(
                            tooltip: context.l10n.create,
                            icon: const Icon(YaruIcons.plus, size: 16),
                            onPressed: onCreate,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: BusyMaxSpacing.xs),
                  for (final item in visible)
                    Padding(
                      padding: const EdgeInsets.only(bottom: BusyMaxSpacing.xs),
                      child: ScheduleItemChip(
                        item: item,
                        height: itemHeight,
                        compact: true,
                        onTap: (context, [globalPosition]) =>
                            onItemSelected(context, item, globalPosition),
                        onTaskCompletionChanged: item is TaskScheduleItem
                            ? (completed) =>
                                  onTaskCompletionChanged(item, completed)
                            : null,
                      ),
                    ),
                  if (showOverflow)
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: Builder(
                        builder: (anchorContext) => TextButton(
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            minimumSize: const Size(0, moreHeight),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          onPressed: () async {
                            final selection = await showScheduleMorePopover(
                              context: context,
                              anchorContext: anchorContext,
                              day: day,
                              items: items,
                              onTaskCompletionChanged: onTaskCompletionChanged,
                            );
                            if (selection == null ||
                                !context.mounted ||
                                !anchorContext.mounted) {
                              return;
                            }
                            onItemSelected(
                              anchorContext,
                              selection.item,
                              selection.anchorPoint,
                            );
                          },
                          child: Text(context.l10n.moreItems(overflow)),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _MonthDayNumber extends StatelessWidget {
  const _MonthDayNumber({
    required this.day,
    required this.selected,
    required this.today,
    required this.inCurrentMonth,
  });

  final DateTime day;
  final bool selected;
  final bool today;
  final bool inCurrentMonth;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final surfaceColors = BusyMaxSurfaceColors.of(context);
    return Container(
      width: 26,
      height: 22,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: selected
            ? surfaceColors.controlActive
            : today
            ? surfaceColors.controlActive
            : null,
        borderRadius: BorderRadius.circular(BusyMaxRadius.sm),
      ),
      child: Text(
        '${day.day}',
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: selected
              ? surfaceColors.foreground
              : today
              ? surfaceColors.foreground
              : inCurrentMonth
              ? colorScheme.onSurface
              : colorScheme.onSurfaceVariant.withValues(alpha: 0.55),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

List<DateTime> _daysInRange(ScheduleRange range) {
  final result = <DateTime>[];
  var cursor = range.start;
  while (cursor.isBefore(range.end)) {
    result.add(cursor);
    // Reconstruct local midnight so DST changes cannot shift or repeat a date.
    cursor = DateTime(cursor.year, cursor.month, cursor.day + 1);
  }
  return result;
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

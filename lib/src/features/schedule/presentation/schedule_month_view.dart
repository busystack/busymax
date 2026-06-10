import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:yaru/yaru.dart';

import '../../../app/busymax_design.dart';
import '../../../l10n/l10n.dart';
import '../../../schedule/schedule_item.dart';
import '../../../schedule/schedule_projection.dart';
import '../../../schedule/schedule_range.dart';
import 'schedule_item_chip.dart';
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
  final void Function(BuildContext context, ScheduleItem item) onItemSelected;
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
  final void Function(BuildContext context, ScheduleItem item) onItemSelected;
  final void Function(TaskScheduleItem item, bool completed)
  onTaskCompletionChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final today = DateUtils.isSameDay(day, DateTime.now());
    final visible = items.take(4).toList();
    final overflow = items.length - visible.length;

    return Material(
      color: selected
          ? Color.alphaBlend(
              colorScheme.primary.withValues(alpha: 0.06),
              colorScheme.surface,
            )
          : colorScheme.surface,
      child: InkWell(
        onTap: onSelect,
        onDoubleTap: onCreate,
        child: Padding(
          padding: const EdgeInsets.all(BusyMaxSpacing.xs),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 26,
                    height: 22,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: selected
                          ? colorScheme.primaryContainer
                          : today
                          ? colorScheme.primary
                          : null,
                      borderRadius: BorderRadius.circular(BusyMaxRadius.sm),
                    ),
                    child: Text(
                      '${day.day}',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: selected
                            ? colorScheme.onPrimaryContainer
                            : today
                            ? colorScheme.onPrimary
                            : inCurrentMonth
                            ? colorScheme.onSurface
                            : colorScheme.onSurfaceVariant.withValues(
                                alpha: 0.55,
                              ),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
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
                    height: 22,
                    compact: true,
                    onTap: (context) => onItemSelected(context, item),
                    onTaskCompletionChanged: item is TaskScheduleItem
                        ? (completed) =>
                              onTaskCompletionChanged(item, completed)
                        : null,
                  ),
                ),
              if (overflow > 0)
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: TextButton(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      minimumSize: const Size(0, 24),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: () => showScheduleMorePopover(
                      context: context,
                      day: day,
                      items: items,
                      onItemSelected: onItemSelected,
                      onTaskCompletionChanged: onTaskCompletionChanged,
                    ),
                    child: Text(context.l10n.moreItems(overflow)),
                  ),
                ),
            ],
          ),
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
    cursor = cursor.add(const Duration(days: 1));
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

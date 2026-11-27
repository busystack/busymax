import 'dart:math' as math;

import 'package:busymax/src/ui/common/flutter_material.dart';
import 'package:intl/intl.dart';

import 'schedule_presentation.dart';
import '../../../app/busymax_surface_colors.dart';
import '../../../l10n/l10n.dart';
import '../../../l10n/localized_formatters.dart';
import '../../../schedule/schedule_item.dart';
import '../../../schedule/schedule_projection.dart';
import '../../../schedule/schedule_range.dart';
import '../../../ui/common/schedule/schedule_interactions.dart';
import '../../../ui/common/schedule/schedule_preview_label.dart';
import '../../../features/schedule/presentation/calendar_day_semantics.dart';
import 'schedule_item_chip.dart';
import '../../../features/schedule/presentation/schedule_item_selection.dart';

typedef ScheduleDayCreateCallback = void Function(
  DateTime day, {
  BuildContext? anchorContext,
});

class ScheduleMonthView extends StatelessWidget {
  const ScheduleMonthView({
    super.key,
    this.presentation,
    required this.range,
    required this.selectedDate,
    required this.items,
    required this.firstWeekday,
    required this.onDaySelected,
    required this.onCreateAtDay,
    required this.onItemSelected,
    required this.onTaskCompletionChanged,
    this.onReschedule,
    this.onShowMore,
  });

  final SchedulePresentation? presentation;

  final Future<void> Function(BuildContext, DateTime, List<ScheduleItem>)?
  onShowMore;
  final ScheduleRange range;
  final DateTime selectedDate;
  final List<ScheduleItem> items;
  final int firstWeekday;
  final ValueChanged<DateTime> onDaySelected;
  final ScheduleDayCreateCallback onCreateAtDay;
  final ScheduleRescheduleCallback? onReschedule;
  final ScheduleItemSelectionCallback onItemSelected;
  final void Function(TaskScheduleItem item, bool completed)
  onTaskCompletionChanged;

  @override
  Widget build(BuildContext context) => SchedulePresentationScope(
    presentation: presentation,
    child: Builder(builder: _build),
  );

  Widget _build(BuildContext context) {
    final days = _daysInRange(range);
    final rows = (days.length / DateTime.daysPerWeek).ceil();
    final month = DateTime(selectedDate.year, selectedDate.month);
    final grouped = ScheduleProjection.groupByDay(
      items,
      visibleRange: range,
      repeatCalendarEvents: true,
    );
    final theme = Theme.of(context);
    final workspaceColor = BusyMaxSurfaceColors.of(context).window;
    final border = scheduleGridColor(context);

    return ScheduleInteractionRegion(
      touch: SchedulePresentation.of(context).touch,
      onReschedule: onReschedule,
      previewColor: theme.colorScheme.primary,
      previewBuilder: (context, interval, allDay) => Text(
        schedulePreviewLabel(context, interval, allDay),
        style: theme.textTheme.labelSmall,
      ),
      child: Column(
        children: [
          ColoredBox(
            color: workspaceColor,
            child: SizedBox(
              height: 34,
              child: Row(
                children: [
                  for (final weekday in _weekdays(firstWeekday))
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, cell) {
                          final locale = Localizations.localeOf(context)
                              .toLanguageTag();
                          final date = _weekdayDate(weekday);
                          final label = localizedWeekdayLabel(
                            locale,
                            date,
                            abbreviated: true,
                          );
                          final style = theme.textTheme.labelMedium!.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          );
                          final narrow =
                              SchedulePresentation.of(context).touch &&
                              _monthTextSize(context, style, label).width >
                                  cell.maxWidth;
                          return Center(
                            child: Text(
                              narrow
                                  ? DateFormat('EEEEE', locale).format(date)
                                  : label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: style,
                              semanticsLabel: localizedWeekdayLabel(
                                locale,
                                date,
                                abbreviated: false,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final touch = SchedulePresentation.of(context).touch;
                final dateHeight = math.max(
                  24.0,
                  _monthNumberSize(context).height,
                );
                final minimumCellHeight =
                    dateHeight +
                    _monthMoreHeight(context) +
                    16 +
                    (constraints.maxWidth / 7 < 68 ? 24 : 0);
                final cellHeight = touch
                    ? math.max(constraints.maxHeight / rows, minimumCellHeight)
                    : constraints.maxHeight / rows;
                return GridView.builder(
                  physics: touch && cellHeight * rows > constraints.maxHeight
                      ? const ClampingScrollPhysics()
                      : const NeverScrollableScrollPhysics(),
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
                        onCreate: (anchorContext) =>
                            onCreateAtDay(day, anchorContext: anchorContext),
                        onItemSelected: onItemSelected,
                        onTaskCompletionChanged: onTaskCompletionChanged,
                        onShowMore: onShowMore,
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
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
    this.onShowMore,
  });

  final Future<void> Function(BuildContext, DateTime, List<ScheduleItem>)?
  onShowMore;
  final DateTime day;
  final bool inCurrentMonth;
  final bool selected;
  final List<ScheduleItem> items;
  final VoidCallback onSelect;
  final ValueChanged<BuildContext> onCreate;
  final ScheduleItemSelectionCallback onItemSelected;
  final void Function(TaskScheduleItem item, bool completed)
  onTaskCompletionChanged;

  @override
  Widget build(BuildContext context) {
    final surfaceColors = BusyMaxSurfaceColors.of(context);
    final workspaceColor = surfaceColors.window;
    final today = DateUtils.isSameDay(day, DateTime.now());

    return ScheduleDateTarget(
      date: day,
      child: BusyMaxCalendarDaySemantics(
        day: day,
        selected: selected,
        onTap: onSelect,
        child: Material(
          color: selected
              ? Color.alphaBlend(surfaceColors.control, workspaceColor)
              : workspaceColor,
          child: InkWell(
            onTap: onSelect,
            onDoubleTap: SchedulePresentation.of(context).touch
                ? null
                : () => onCreate(context),
            onLongPress: SchedulePresentation.of(context).touch
                ? () => onCreate(context)
                : null,
            excludeFromSemantics: true,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final touch = SchedulePresentation.of(context).touch;
                final headerHeight = touch
                    ? math.max(24.0, _monthNumberSize(context).height) +
                          (selected && constraints.maxWidth < 68 ? 24 : 0)
                    : 24.0;
                final itemHeight = touch
                    ? math.max(
                        22.0,
                        _monthTextSize(
                              context,
                              Theme.of(context).textTheme.labelSmall!,
                              'Task',
                            ).height +
                            4,
                      )
                    : 22.0;
                final moreHeight = touch ? _monthMoreHeight(context) : 24.0;
                const itemGap = ScheduleSpacing.xs;
                final contentHeight = math.max(
                  0.0,
                  constraints.maxHeight - ScheduleSpacing.xs * 2,
                );
                final availableRowsHeight = math.max(
                  0.0,
                  contentHeight - headerHeight - itemGap,
                );
                final rowSlots = (availableRowsHeight / (itemHeight + itemGap))
                    .floor();
                final needsOverflowRow = items.length > rowSlots;
                final visibleCount = needsOverflowRow
                    ? math.max(
                        0,
                        ((availableRowsHeight - moreHeight - itemGap) /
                                (itemHeight + itemGap))
                            .floor(),
                      )
                    : math.min(items.length, rowSlots);
                final visible = items.take(visibleCount).toList();
                final overflow = items.length - visible.length;
                final showOverflow =
                    overflow > 0 && availableRowsHeight >= moreHeight;

                if (contentHeight < headerHeight + itemGap) {
                  return Padding(
                    padding: const EdgeInsets.all(ScheduleSpacing.xs),
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
                  padding: const EdgeInsets.all(ScheduleSpacing.xs),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          _MonthDayNumber(
                            day: day,
                            selected: selected,
                            today: today,
                            inCurrentMonth: inCurrentMonth,
                          ),
                          if (selected)
                            Builder(
                              builder: (anchorContext) => SizedBox.square(
                                dimension: 24,
                                child: ScheduleCreateButton(
                                  tooltip: context.l10n.create,
                                  icon: Icon(
                                    SchedulePresentation.of(context).createIcon,
                                    size: 16,
                                  ),
                                  onPressed: () => onCreate(anchorContext),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: ScheduleSpacing.xs),
                      for (final item in visible)
                        Padding(
                          padding: const EdgeInsets.only(
                            bottom: ScheduleSpacing.xs,
                          ),
                          child: ScheduleEventInteraction(
                            key: ValueKey(
                              'month-${item.accountId}-${item.sourceId}-${item.id}-$day',
                            ),
                            item: item,
                            representedDate: day,
                            dateOnly: true,
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
                        ),
                      if (showOverflow)
                        Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: Builder(
                            builder: (anchorContext) => TextButton(
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 2,
                                ),
                                minimumSize: Size(0, moreHeight),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              onPressed: () async {
                                if (onShowMore != null) {
                                  await onShowMore!(anchorContext, day, items);
                                } else {
                                  await SchedulePresentation.of(context)
                                      .showMore(
                                        anchorContext,
                                        day,
                                        items,
                                        onItemSelected,
                                        onTaskCompletionChanged,
                                      );
                                }
                              },
                              child: Text(
                                context.l10n.moreItems(overflow),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
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
      key: ValueKey('month-day-marker-${day.toIso8601String()}'),
      width: SchedulePresentation.of(context).touch
          ? _monthNumberSize(context).width
          : 26,
      height: SchedulePresentation.of(context).touch
          ? _monthNumberSize(context).height
          : 22,
      constraints: const BoxConstraints(minWidth: 26, minHeight: 22),
      padding: SchedulePresentation.of(context).touch
          ? const EdgeInsets.symmetric(horizontal: 3, vertical: 2)
          : null,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: selected
            ? colorScheme.primary
            : today
            ? surfaceColors.controlActive
            : null,
        borderRadius: BorderRadius.circular(ScheduleRadius.sm),
      ),
      child: Text(
        '${day.day}',
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: selected
              ? colorScheme.onPrimary
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

Size _monthTextSize(BuildContext context, TextStyle style, String text) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: Directionality.of(context),
    textScaler: MediaQuery.textScalerOf(context),
  )..layout();
  final size = painter.size;
  painter.dispose();
  return size;
}

Size _monthNumberSize(BuildContext context) {
  final size = _monthTextSize(
    context,
    Theme.of(context).textTheme.labelMedium!
        .copyWith(fontWeight: FontWeight.w600),
    '30',
  );
  return Size(math.max(26, size.width + 6), math.max(22, size.height + 4));
}

double _monthMoreHeight(BuildContext context) => math.max(
  24,
  _monthTextSize(
        context,
        Theme.of(context).textTheme.labelLarge!,
        'More',
      ).height +
      8,
);

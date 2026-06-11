import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:yaru/yaru.dart';

import '../../../app/busymax_design.dart';
import '../../../app/busymax_yaru_theme.dart';
import '../../../l10n/l10n.dart';
import '../../../schedule/schedule_item.dart';
import '../../../schedule/schedule_projection.dart';
import '../../../schedule/schedule_range.dart';
import 'schedule_event_block.dart';
import 'schedule_item_selection.dart';

class ScheduleAgendaView extends StatelessWidget {
  const ScheduleAgendaView({
    super.key,
    required this.range,
    required this.items,
    required this.onItemSelected,
    required this.onTaskCompletionChanged,
  });

  final ScheduleRange range;
  final List<ScheduleItem> items;
  final ScheduleItemSelectionCallback onItemSelected;
  final void Function(TaskScheduleItem item, bool completed)
  onTaskCompletionChanged;

  @override
  Widget build(BuildContext context) {
    final dated = items.where((item) => item.start != null).toList();
    final noDateTasks = ScheduleProjection.noDateTasks(items);
    final groups = ScheduleProjection.groupByDay(dated);
    final rangeStart = ScheduleProjection.day(range.start);
    final rangeEnd = ScheduleProjection.day(range.end);
    final days =
        groups.keys
            .where((day) => !day.isBefore(rangeStart) && day.isBefore(rangeEnd))
            .toList()
          ..sort();

    return ColoredBox(
      color: Theme.of(context).colorScheme.surface,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          BusyMaxSpacing.lg,
          BusyMaxSpacing.md,
          BusyMaxSpacing.lg,
          BusyMaxSpacing.xl,
        ),
        children: [
          for (final day in days)
            BusyMaxGroupedList(
              title: _dayLabel(context, day),
              filled: true,
              children: [
                for (final item in groups[day]!)
                  _AgendaRow(
                    item: item,
                    onTap: (context, [globalPosition]) =>
                        onItemSelected(context, item, globalPosition),
                    onTaskCompletionChanged: item is TaskScheduleItem
                        ? (completed) =>
                              onTaskCompletionChanged(item, completed)
                        : null,
                  ),
              ],
            ),
          if (noDateTasks.isNotEmpty)
            BusyMaxGroupedList(
              title: context.l10n.noDate,
              filled: true,
              children: [
                for (final item in noDateTasks)
                  _AgendaRow(
                    item: item,
                    onTap: (context, [globalPosition]) =>
                        onItemSelected(context, item, globalPosition),
                    onTaskCompletionChanged: item is TaskScheduleItem
                        ? (completed) =>
                              onTaskCompletionChanged(item, completed)
                        : null,
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _AgendaRow extends StatelessWidget {
  const _AgendaRow({
    required this.item,
    required this.onTap,
    this.onTaskCompletionChanged,
  });

  final ScheduleItem item;
  final ScheduleItemTapCallback onTap;
  final ValueChanged<bool>? onTaskCompletionChanged;

  @override
  Widget build(BuildContext context) {
    final task = item is TaskScheduleItem ? item as TaskScheduleItem : null;
    Offset? pointerDownPosition;

    return BusyMaxActionRow(
      title: item.title,
      titleWidget: _AgendaItemTitle(item: item),
      subtitleWidget: _AgendaItemSubtitle(item: item),
      leading: _AgendaItemMarker(item: item),
      trailing: task == null
          ? null
          : YaruCheckbox(
              value: task.completed,
              onChanged: onTaskCompletionChanged == null
                  ? null
                  : (value) => onTaskCompletionChanged!(value ?? false),
            ),
      onPointerDown: (position) => pointerDownPosition = position,
      onTap: () => onTap(context, pointerDownPosition),
    );
  }
}

class _AgendaItemMarker extends StatelessWidget {
  const _AgendaItemMarker({required this.item});

  final ScheduleItem item;

  @override
  Widget build(BuildContext context) {
    final color = ScheduleProjection.colorForItem(
      item,
      Theme.of(context).colorScheme.brightness,
    );
    final icon = item.kind == ScheduleItemKind.task
        ? YaruIcons.checkbox
        : YaruIcons.calendar;
    return Icon(icon, size: BusyMaxSizes.iconSm, color: color);
  }
}

class _AgendaItemTitle extends StatelessWidget {
  const _AgendaItemTitle({required this.item});

  final ScheduleItem item;

  @override
  Widget build(BuildContext context) {
    final task = item is TaskScheduleItem ? item as TaskScheduleItem : null;
    final colorScheme = Theme.of(context).colorScheme;
    return Text(
      item.title,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
        fontWeight: FontWeight.w600,
        decoration: task?.completed == true ? TextDecoration.lineThrough : null,
        color: task?.completed == true
            ? colorScheme.onSurfaceVariant
            : colorScheme.onSurface,
      ),
    );
  }
}

class _AgendaItemSubtitle extends StatelessWidget {
  const _AgendaItemSubtitle({required this.item});

  final ScheduleItem item;

  @override
  Widget build(BuildContext context) {
    final values = [
      scheduleTimeRange(context, item),
      ScheduleProjection.sourceLabelForScheduleItem(item),
    ].where((value) => value.trim().isNotEmpty).join(' - ');
    return Text(
      values,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: BusyMaxSurfaceColors.of(context).mutedForeground,
      ),
    );
  }
}

String _dayLabel(BuildContext context, DateTime day) {
  if (DateUtils.isSameDay(day, DateTime.now())) {
    return context.l10n.today;
  }
  if (DateUtils.isSameDay(day, DateTime.now().add(const Duration(days: 1)))) {
    return context.l10n.tomorrow;
  }
  final locale = Localizations.localeOf(context).toLanguageTag();
  return DateFormat.yMMMMEEEEd(locale).format(day);
}

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:yaru/yaru.dart';

import '../../../app/busymax_design.dart';
import '../../../app/busymax_yaru_theme.dart';
import '../../../l10n/l10n.dart';
import '../../../schedule/schedule_item.dart';
import '../../../schedule/schedule_projection.dart';
import '../../../schedule/schedule_range.dart';
import '../../../schedule/schedule_sorting.dart';
import 'schedule_event_block.dart';
import 'schedule_item_selection.dart';

class ScheduleAgendaView extends StatefulWidget {
  const ScheduleAgendaView({
    super.key,
    required this.range,
    required this.items,
    required this.onItemSelected,
    required this.onTaskCompletionChanged,
    this.hasMoreOverdueTasks = false,
    this.hasMoreNoDateTasks = false,
    this.onLoadMore,
    this.onLoadMoreOverdue,
    this.onLoadMoreNoDate,
    this.onItemAnchorAvailable,
  });

  final ScheduleRange range;
  final List<ScheduleItem> items;
  final ScheduleItemSelectionCallback onItemSelected;
  final void Function(TaskScheduleItem item, bool completed)
  onTaskCompletionChanged;
  final bool hasMoreOverdueTasks;
  final bool hasMoreNoDateTasks;
  final VoidCallback? onLoadMore;
  final VoidCallback? onLoadMoreOverdue;
  final VoidCallback? onLoadMoreNoDate;
  final ScheduleItemAnchorCallback? onItemAnchorAvailable;

  @override
  State<ScheduleAgendaView> createState() => _ScheduleAgendaViewState();
}

class _ScheduleAgendaViewState extends State<ScheduleAgendaView> {
  var _loadMoreArmed = true;

  @override
  void didUpdateWidget(covariant ScheduleAgendaView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.range.end != widget.range.end) {
      _loadMoreArmed = true;
    }
  }

  bool _handleScroll(ScrollNotification notification) {
    final onLoadMore = widget.onLoadMore;
    if (!_loadMoreArmed || onLoadMore == null) {
      return false;
    }
    if (notification.metrics.axis != Axis.vertical) {
      return false;
    }
    if (notification.metrics.extentAfter > 1) {
      return false;
    }
    _loadMoreArmed = false;
    onLoadMore();
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final dated = widget.items.where((item) => item.start != null).toList();
    final noDateTasks = ScheduleProjection.noDateTasks(widget.items);
    final groups = ScheduleProjection.groupByDay(dated);
    final rangeStart = ScheduleProjection.day(widget.range.start);
    final rangeEnd = ScheduleProjection.day(widget.range.end);
    final overdueTasks = dated.whereType<TaskScheduleItem>().where((item) {
      final start = item.start;
      return start != null &&
          !item.completed &&
          ScheduleProjection.day(start).isBefore(rangeStart);
    }).toList()..sort(compareScheduleItems);
    final days =
        groups.keys
            .where((day) => !day.isBefore(rangeStart) && day.isBefore(rangeEnd))
            .toList()
          ..sort();

    return NotificationListener<ScrollNotification>(
      onNotification: _handleScroll,
      child: ColoredBox(
        color: Theme.of(context).colorScheme.surface,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            BusyMaxSpacing.lg,
            BusyMaxSpacing.md,
            BusyMaxSpacing.lg,
            BusyMaxSpacing.xl,
          ),
          children: [
            if (overdueTasks.isNotEmpty)
              BusyMaxGroupedList(
                title: context.l10n.overdue,
                filled: true,
                children: [
                  for (final item in overdueTasks)
                    _AgendaRow(
                      item: item,
                      onAnchorAvailable: widget.onItemAnchorAvailable,
                      onTap: (context, [globalPosition]) =>
                          widget.onItemSelected(context, item, globalPosition),
                      onTaskCompletionChanged: (completed) =>
                          widget.onTaskCompletionChanged(item, completed),
                    ),
                  if (widget.hasMoreOverdueTasks &&
                      widget.onLoadMoreOverdue != null)
                    _AgendaLoadMoreRow(
                      title: context.l10n.agendaLoadMoreOverdue,
                      onTap: widget.onLoadMoreOverdue!,
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
                      onAnchorAvailable: widget.onItemAnchorAvailable,
                      onTap: (context, [globalPosition]) =>
                          widget.onItemSelected(context, item, globalPosition),
                      onTaskCompletionChanged: item is TaskScheduleItem
                          ? (completed) =>
                                widget.onTaskCompletionChanged(item, completed)
                          : null,
                    ),
                  if (widget.hasMoreNoDateTasks &&
                      widget.onLoadMoreNoDate != null)
                    _AgendaLoadMoreRow(
                      title: context.l10n.agendaLoadMoreNoDate,
                      onTap: widget.onLoadMoreNoDate!,
                    ),
                ],
              ),
            for (final day in days)
              BusyMaxGroupedList(
                title: _dayLabel(context, day),
                filled: true,
                children: [
                  for (final item in groups[day]!)
                    _AgendaRow(
                      item: item,
                      onAnchorAvailable: widget.onItemAnchorAvailable,
                      onTap: (context, [globalPosition]) =>
                          widget.onItemSelected(context, item, globalPosition),
                      onTaskCompletionChanged: item is TaskScheduleItem
                          ? (completed) =>
                                widget.onTaskCompletionChanged(item, completed)
                          : null,
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _AgendaLoadMoreRow extends StatelessWidget {
  const _AgendaLoadMoreRow({required this.title, required this.onTap});

  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return BusyMaxActionRow(
      title: title,
      leading: const Icon(YaruIcons.plus, size: BusyMaxSizes.iconSm),
      onTap: onTap,
    );
  }
}

class _AgendaRow extends StatelessWidget {
  const _AgendaRow({
    required this.item,
    required this.onTap,
    this.onAnchorAvailable,
    this.onTaskCompletionChanged,
  });

  final ScheduleItem item;
  final ScheduleItemTapCallback onTap;
  final ScheduleItemAnchorCallback? onAnchorAvailable;
  final ValueChanged<bool>? onTaskCompletionChanged;

  @override
  Widget build(BuildContext context) {
    final task = item is TaskScheduleItem ? item as TaskScheduleItem : null;
    Offset? pointerDownPosition;
    final onAnchorAvailable = this.onAnchorAvailable;
    if (onAnchorAvailable != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          onAnchorAvailable(item, context);
        }
      });
    }

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
    final isTask = item.kind == ScheduleItemKind.task;
    final color = isTask
        ? Theme.of(context).colorScheme.onSurfaceVariant
        : ScheduleProjection.colorForItem(
            item,
            Theme.of(context).colorScheme.brightness,
          );
    final icon = isTask ? YaruIcons.task_list : YaruIcons.calendar;
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

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:yaru/yaru.dart';

import '../../../app/busymax_design.dart';
import '../../../l10n/l10n.dart';
import '../../../schedule/schedule_item.dart';
import '../../../schedule/schedule_projection.dart';
import '../../../schedule/schedule_range.dart';
import 'schedule_event_block.dart';

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
  final void Function(BuildContext context, ScheduleItem item) onItemSelected;
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
          for (final day in days) ...[
            _AgendaDayHeader(day: day),
            const SizedBox(height: BusyMaxSpacing.sm),
            for (final item in groups[day]!)
              Padding(
                padding: const EdgeInsets.only(bottom: BusyMaxSpacing.sm),
                child: _AgendaRow(
                  item: item,
                  onTap: (context) => onItemSelected(context, item),
                  onTaskCompletionChanged: item is TaskScheduleItem
                      ? (completed) => onTaskCompletionChanged(item, completed)
                      : null,
                ),
              ),
            const SizedBox(height: BusyMaxSpacing.md),
          ],
          if (noDateTasks.isNotEmpty) ...[
            _AgendaPlainHeader(title: context.l10n.noDate),
            const SizedBox(height: BusyMaxSpacing.sm),
            for (final item in noDateTasks)
              Padding(
                padding: const EdgeInsets.only(bottom: BusyMaxSpacing.sm),
                child: _AgendaRow(
                  item: item,
                  onTap: (context) => onItemSelected(context, item),
                  onTaskCompletionChanged: item is TaskScheduleItem
                      ? (completed) => onTaskCompletionChanged(item, completed)
                      : null,
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _AgendaDayHeader extends StatelessWidget {
  const _AgendaDayHeader({required this.day});

  final DateTime day;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final today = DateUtils.isSameDay(day, DateTime.now());
    final label = _dayLabel(context, day);
    return Row(
      children: [
        Container(
          width: 34,
          height: 30,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: today ? colorScheme.primary : colorScheme.surface,
            borderRadius: BorderRadius.circular(BusyMaxRadius.sm),
            border: today
                ? null
                : Border.all(color: busyMaxPanelBorder(context)),
          ),
          child: Text(
            '${day.day}',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: today ? colorScheme.onPrimary : colorScheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: BusyMaxSpacing.sm),
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: busyMaxSectionHeaderStyle(context),
          ),
        ),
      ],
    );
  }
}

class _AgendaPlainHeader extends StatelessWidget {
  const _AgendaPlainHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(title, style: busyMaxSectionHeaderStyle(context));
  }
}

class _AgendaRow extends StatelessWidget {
  const _AgendaRow({
    required this.item,
    required this.onTap,
    this.onTaskCompletionChanged,
  });

  final ScheduleItem item;
  final ValueChanged<BuildContext> onTap;
  final ValueChanged<bool>? onTaskCompletionChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final color = ScheduleProjection.colorForItem(item, colorScheme.brightness);
    final task = item is TaskScheduleItem ? item as TaskScheduleItem : null;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(BusyMaxRadius.sm),
        onTap: () => onTap(context),
        child: Container(
          constraints: const BoxConstraints(minHeight: 52),
          padding: const EdgeInsets.all(BusyMaxSpacing.sm),
          decoration: BoxDecoration(
            color: Color.alphaBlend(
              color.withValues(
                alpha: item.kind == ScheduleItemKind.task ? 0.08 : 0.12,
              ),
              colorScheme.surface,
            ),
            borderRadius: BorderRadius.circular(BusyMaxRadius.sm),
            border: Border(left: BorderSide(color: color, width: 4)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 76,
                child: Text(
                  scheduleTimeRange(context, item),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: BusyMaxSpacing.sm),
              if (task != null) ...[
                YaruCheckbox(
                  value: task.completed,
                  onChanged: onTaskCompletionChanged == null
                      ? null
                      : (value) => onTaskCompletionChanged!(value ?? false),
                ),
                const SizedBox(width: BusyMaxSpacing.xs),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        decoration: task?.completed == true
                            ? TextDecoration.lineThrough
                            : null,
                        color: task?.completed == true
                            ? colorScheme.onSurfaceVariant
                            : colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      ScheduleProjection.sourceLabelForScheduleItem(item),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
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

import 'package:flutter/material.dart';

import 'schedule_presentation.dart';

import '../../../schedule/schedule_item.dart';
import 'schedule_event_block.dart';
import '../../../features/schedule/presentation/schedule_item_selection.dart';
import 'schedule_task_chip.dart';

class ScheduleItemChip extends StatelessWidget {
  const ScheduleItemChip({
    super.key,
    this.presentation,
    required this.item,
    required this.height,
    this.width,
    this.compact = true,
    this.onTap,
    this.onTaskCompletionChanged,
  });

  final SchedulePresentation? presentation;

  final ScheduleItem item;
  final double height;
  final double? width;
  final bool compact;
  final ScheduleItemTapCallback? onTap;
  final ValueChanged<bool>? onTaskCompletionChanged;

  @override
  Widget build(BuildContext context) => SchedulePresentationScope(
    presentation: presentation,
    child: Builder(builder: _build),
  );

  Widget _build(BuildContext context) {
    final item = this.item;
    if (item is TaskScheduleItem) {
      return ScheduleTaskChip(
        item: item,
        height: height,
        width: width,
        compact: compact,
        onTap: onTap,
        onCompletionChanged: onTaskCompletionChanged,
      );
    }
    return ScheduleEventBlock(
      item: item as CalendarScheduleItem,
      height: height,
      width: width,
      compact: compact,
      onTap: onTap,
    );
  }
}

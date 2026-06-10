import 'package:flutter/material.dart';

import '../../../schedule/schedule_item.dart';
import 'schedule_event_block.dart';
import 'schedule_task_chip.dart';

class ScheduleItemChip extends StatelessWidget {
  const ScheduleItemChip({
    super.key,
    required this.item,
    required this.height,
    this.width,
    this.compact = true,
    this.onTap,
    this.onTaskCompletionChanged,
  });

  final ScheduleItem item;
  final double height;
  final double? width;
  final bool compact;
  final ValueChanged<BuildContext>? onTap;
  final ValueChanged<bool>? onTaskCompletionChanged;

  @override
  Widget build(BuildContext context) {
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

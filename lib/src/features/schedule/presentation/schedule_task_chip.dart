import 'package:flutter/material.dart';
import 'package:yaru/yaru.dart';

import '../../../app/busymax_design.dart';
import '../../../app/busymax_surface_colors.dart';
import '../../../schedule/schedule_item.dart';
import '../../../schedule/schedule_projection.dart';
import 'schedule_event_block.dart';
import 'schedule_item_selection.dart';

class ScheduleTaskChip extends StatelessWidget {
  const ScheduleTaskChip({
    super.key,
    required this.item,
    required this.height,
    this.width,
    this.compact = false,
    this.onTap,
    this.onCompletionChanged,
  });

  final TaskScheduleItem item;
  final double height;
  final double? width;
  final bool compact;
  final ScheduleItemTapCallback? onTap;
  final ValueChanged<bool>? onCompletionChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final surfaceColors = BusyMaxSurfaceColors.of(context);
    final titleStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
      color: item.completed
          ? colorScheme.onSurfaceVariant
          : colorScheme.onSurface,
      fontWeight: FontWeight.w600,
      decoration: item.completed ? TextDecoration.lineThrough : null,
    );
    final details = [
      scheduleTimeRange(context, item),
      ScheduleProjection.sourceLabelForScheduleItem(item),
    ].join(' · ');
    final blockWidth = scheduleSafeBlockWidth(width);
    final blockHeight = scheduleSafeBlockHeight(height);
    final horizontalPadding = compact ? 5.0 : 8.0;
    final checkboxSize = compact ? 14.0 : 16.0;
    final contentWidth = blockWidth == null
        ? double.infinity
        : blockWidth - horizontalPadding * 2;
    final showContent = contentWidth >= 28;
    final showCheckbox = contentWidth >= checkboxSize + BusyMaxSpacing.xs + 24;

    Offset? pointerDownPosition;
    return Tooltip(
      message: '${item.title}\n$details',
      waitDuration: const Duration(milliseconds: 600),
      child: SizedBox(
        width: blockWidth,
        height: blockHeight,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(BusyMaxRadius.sm),
            onTapDown: onTap == null
                ? null
                : (details) => pointerDownPosition = details.globalPosition,
            onTap: onTap == null
                ? null
                : () => onTap!(context, pointerDownPosition),
            onSecondaryTapDown: onTap == null
                ? null
                : (details) => pointerDownPosition = details.globalPosition,
            onSecondaryTap: onTap == null
                ? null
                : () => onTap!(context, pointerDownPosition),
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: horizontalPadding,
                vertical: compact ? 1 : 5,
              ),
              decoration: BoxDecoration(
                color: surfaceColors.control,
                borderRadius: BorderRadius.circular(BusyMaxRadius.sm),
                border: Border(
                  left: BorderSide(color: surfaceColors.subtleBorder, width: 3),
                ),
              ),
              child: showContent
                  ? Row(
                      children: [
                        if (showCheckbox) ...[
                          SizedBox.square(
                            dimension: checkboxSize,
                            child: YaruCheckbox(
                              value: item.completed,
                              onChanged: onCompletionChanged == null
                                  ? null
                                  : (value) =>
                                        onCompletionChanged!(value ?? false),
                            ),
                          ),
                          const SizedBox(width: BusyMaxSpacing.xs),
                        ],
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                item.title,
                                maxLines: compact ? 1 : 2,
                                overflow: TextOverflow.ellipsis,
                                style: titleStyle,
                              ),
                            ],
                          ),
                        ),
                      ],
                    )
                  : const SizedBox.shrink(),
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../../app/busymax_design.dart';
import '../../../l10n/l10n.dart';
import '../../../schedule/schedule_item.dart';
import '../../../schedule/schedule_projection.dart';
import 'schedule_item_selection.dart';

class ScheduleEventBlock extends StatelessWidget {
  const ScheduleEventBlock({
    super.key,
    required this.item,
    required this.height,
    this.width,
    this.compact = false,
    this.onTap,
  });

  final CalendarScheduleItem item;
  final double height;
  final double? width;
  final bool compact;
  final ScheduleItemTapCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final color = ScheduleProjection.colorForItem(item, colorScheme.brightness);
    final background = Color.alphaBlend(
      color.withValues(alpha: compact || item.allDay ? 0.18 : 0.26),
      colorScheme.surface,
    );
    final blockHeight = scheduleSafeBlockHeight(height);
    final blockWidth = scheduleSafeBlockWidth(width);
    final dense = compact || blockHeight < 36;
    final verticalPadding = dense ? 2.0 : 5.0;
    final contentHeight = blockHeight - verticalPadding * 2;
    final timeRange = _timeRange(context);
    final showTime = !item.allDay && !dense && contentHeight >= 34;
    final titleMaxLines = showTime || contentHeight < 36 ? 1 : 2;
    final tooltipDetails = _tooltipDetails(context);

    Offset? pointerDownPosition;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: onTap == null
          ? null
          : (details) => pointerDownPosition = details.globalPosition,
      onTap: onTap == null ? null : () => onTap!(context, pointerDownPosition),
      child: Tooltip(
        message: tooltipDetails.isEmpty
            ? item.title
            : '${item.title}\n$tooltipDetails',
        waitDuration: const Duration(milliseconds: 600),
        child: SizedBox(
          width: blockWidth,
          height: blockHeight,
          child: Material(
            color: Colors.transparent,
            child: Container(
              clipBehavior: Clip.antiAlias,
              padding: EdgeInsets.symmetric(
                horizontal: dense ? 6 : 8,
                vertical: verticalPadding,
              ),
              decoration: BoxDecoration(
                color: background,
                borderRadius: BorderRadius.circular(BusyMaxRadius.sm),
                border: Border(left: BorderSide(color: color, width: 4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: showTime
                    ? MainAxisAlignment.spaceBetween
                    : MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.max,
                children: [
                  Flexible(
                    child: Text(
                      item.title,
                      maxLines: titleMaxLines,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ),
                  if (showTime && timeRange.isNotEmpty)
                    Text(
                      timeRange,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _tooltipDetails(BuildContext context) {
    final parts = <String>[
      if (!item.allDay && item.start != null) _timeRange(context),
      if (item.location != null && item.location!.isNotEmpty) item.location!,
      ScheduleProjection.sourceLabelForScheduleItem(item),
    ];
    return parts.join(' · ');
  }

  String _timeRange(BuildContext context) {
    final start = item.start;
    if (start == null) {
      return '';
    }
    final startText = _formatTime(context, start);
    final end = item.end;
    if (end == null) {
      return startText;
    }
    return '$startText-${_formatTime(context, end)}';
  }
}

double? scheduleSafeBlockWidth(double? width) {
  if (width == null || !width.isFinite) {
    return null;
  }
  return width < 0 ? 0 : width;
}

double scheduleSafeBlockHeight(double height) {
  if (!height.isFinite || height < 22) {
    return 22;
  }
  return height;
}

String scheduleTimeRange(BuildContext context, ScheduleItem item) {
  if (item.allDay) {
    return context.l10n.allDay;
  }
  final start = item.start;
  if (start == null) {
    return context.l10n.noDate;
  }
  final startText = _formatTime(context, start);
  final end = item.end;
  if (end == null) {
    return startText;
  }
  return '$startText-${_formatTime(context, end)}';
}

String _formatTime(BuildContext context, DateTime value) {
  return MaterialLocalizations.of(context).formatTimeOfDay(
    TimeOfDay.fromDateTime(value),
    alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
  );
}

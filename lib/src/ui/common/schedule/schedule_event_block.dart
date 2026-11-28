import 'package:busymax/src/l10n/time_format_scope.dart';
import 'package:busymax/src/ui/common/flutter_material.dart';
import 'package:flutter/services.dart';

import 'schedule_presentation.dart';
import '../../../app/busymax_surface_colors.dart';
import '../../../l10n/l10n.dart';
import '../../../schedule/schedule_item.dart';
import '../../../schedule/schedule_projection.dart';
import '../../../features/schedule/presentation/schedule_item_selection.dart';

class ScheduleEventBlock extends StatefulWidget {
  const ScheduleEventBlock({
    super.key,
    this.presentation,
    required this.item,
    required this.height,
    this.width,
    this.compact = false,
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
  State<ScheduleEventBlock> createState() => _ScheduleEventBlockState();
}

class _ScheduleEventBlockState extends State<ScheduleEventBlock> {
  static const _activationShortcuts = <ShortcutActivator, Intent>{
    SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
    SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
  };

  Offset? _pointerDownPosition;
  var _showFocusHighlight = false;
  var _hovered = false;

  @override
  Widget build(BuildContext context) => SchedulePresentationScope(
    presentation: widget.presentation,
    child: Builder(builder: _build),
  );

  Widget _build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final item = widget.item;
    final task = item is TaskScheduleItem ? item : null;
    final toggleTask = task?.capabilities.canEdit == true
        ? widget.onTaskCompletionChanged
        : null;
    final surfaceColors = BusyMaxSurfaceColors.of(context);
    final blockHeight = scheduleSafeBlockHeight(widget.height);
    final blockWidth = scheduleSafeBlockWidth(widget.width);
    final dense = widget.compact || blockHeight < 36;
    final verticalPadding = dense ? 2.0 : 5.0;
    final contentHeight = blockHeight - verticalPadding * 2;
    final timeRange = _timeRange(context);
    final showTime = !widget.item.allDay && !dense && contentHeight >= 34;
    final titleMaxLines = showTime || contentHeight < 36 ? 1 : 2;
    final tooltipDetails = _tooltipDetails(context);
    final interactive = widget.onTap != null;
    final focusBorder = BorderSide(color: colorScheme.primary, width: 2);
    final sourceAccent = ScheduleProjection.colorForItem(
      widget.item,
      colorScheme.brightness,
    );

    return Semantics(
      container: true,
      button: interactive,
      enabled: interactive,
      label: _semanticsLabel(context),
      onTap: interactive ? _activateWithoutPointer : null,
      excludeSemantics: task == null,
      child: FocusableActionDetector(
        enabled: interactive,
        mouseCursor: !interactive
            ? MouseCursor.defer
            : SystemMouseCursors.click,
        shortcuts: _activationShortcuts,
        actions: <Type, Action<Intent>>{
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              _activateWithoutPointer();
              return null;
            },
          ),
        },
        onShowFocusHighlight: (value) {
          if (_showFocusHighlight != value) {
            setState(() => _showFocusHighlight = value);
          }
        },
        onShowHoverHighlight: (value) {
          if (_hovered != value) setState(() => _hovered = value);
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: !interactive
              ? null
              : (details) => _pointerDownPosition = details.globalPosition,
          onTapCancel: !interactive ? null : () => _pointerDownPosition = null,
          onTap: interactive ? _activateFromPointer : null,
          onSecondaryTapDown: !interactive
              ? null
              : (details) => _pointerDownPosition = details.globalPosition,
          onSecondaryTap: interactive ? _activateFromPointer : null,
          child: Tooltip(
            triggerMode: SchedulePresentation.of(context).touch
                ? TooltipTriggerMode.manual
                : null,
            excludeFromSemantics: true,
            message: tooltipDetails.isEmpty
                ? widget.item.title
                : '${widget.item.title}\n$tooltipDetails',
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
                    color: _hovered
                        ? surfaceColors.controlActive
                        : surfaceColors.control,
                    borderRadius: BorderRadius.circular(ScheduleRadius.sm),
                    border: Border(
                      left: BorderSide(
                        color: _showFocusHighlight
                            ? colorScheme.primary
                            : sourceAccent,
                        width: 4,
                      ),
                      top: _showFocusHighlight ? focusBorder : BorderSide.none,
                      right: _showFocusHighlight
                          ? focusBorder
                          : BorderSide.none,
                      bottom: _showFocusHighlight
                          ? focusBorder
                          : BorderSide.none,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisAlignment: showTime
                        ? MainAxisAlignment.spaceBetween
                        : MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.max,
                    children: [
                      Flexible(
                        child: LayoutBuilder(
                          builder: (context, bounds) {
                            final iconSize = dense
                                ? 14.0
                                : ScheduleSizes.iconSm;
                            final showIcon = bounds.maxWidth >= iconSize;
                            return Row(
                              children: [
                                if (showIcon) ...[
                                  SizedBox.square(
                                    dimension: iconSize,
                                    child: task == null
                                        ? Icon(
                                            SchedulePresentation.of(context)
                                                .itemIcon(item),
                                            size: iconSize,
                                            color: sourceAccent,
                                          )
                                        : FittedBox(
                                            fit: BoxFit.scaleDown,
                                            child: ScheduleCheckbox(
                                              value: task.completed,
                                              onChanged: toggleTask == null
                                                  ? null
                                                  : (value) => toggleTask(
                                                      value ?? false,
                                                    ),
                                            ),
                                          ),
                                  ),
                                  if (bounds.maxWidth >=
                                      iconSize + ScheduleSpacing.xs)
                                    const SizedBox(width: ScheduleSpacing.xs),
                                ],
                                Expanded(
                                  child: Text(
                                    item.title.isEmpty &&
                                            item is JournalScheduleItem
                                        ? context.l10n.untitledJournal
                                        : item.title,
                                    maxLines: titleMaxLines,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(
                                          fontWeight: FontWeight.w600,
                                          color: task?.completed == true
                                              ? colorScheme.onSurfaceVariant
                                              : colorScheme.onSurface,
                                          decoration: task?.completed == true
                                              ? TextDecoration.lineThrough
                                              : null,
                                        ),
                                  ),
                                ),
                                if (bounds.maxWidth >= 60 &&
                                    (item is JournalScheduleItem &&
                                            item.recurring ||
                                        item is CalendarScheduleItem &&
                                            item.providerRecurringEventId !=
                                                null))
                                  Icon(
                                    SchedulePresentation.of(context)
                                        .recurrenceIcon,
                                    size: 12,
                                  ),
                              ],
                            );
                          },
                        ),
                      ),
                      if (showTime && timeRange.isNotEmpty)
                        Text(
                          timeRange,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(color: colorScheme.onSurfaceVariant),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _tooltipDetails(BuildContext context) {
    final event = widget.item;
    final parts = <String>[
      if (!widget.item.allDay && widget.item.start != null) _timeRange(context),
      if (event is CalendarScheduleItem && event.location?.isNotEmpty == true)
        event.location!,
      ScheduleProjection.sourceLabelForScheduleItem(widget.item),
    ];
    return parts.join(' · ');
  }

  String _semanticsLabel(BuildContext context) {
    final event = widget.item;
    return <String>[
      widget.item.title,
      scheduleTimeRange(context, widget.item),
      if (event is CalendarScheduleItem && event.location?.isNotEmpty == true)
        event.location!,
      ScheduleProjection.sourceLabelForScheduleItem(widget.item),
    ].where((part) => part.isNotEmpty).join(', ');
  }

  String _timeRange(BuildContext context) {
    final start = widget.item.start;
    if (start == null) {
      return '';
    }
    final startText = _formatTime(context, start);
    final end = widget.item.end;
    if (end == null) {
      return startText;
    }
    return '$startText-${_formatTime(context, end)}';
  }

  void _activateFromPointer() {
    final pointerDownPosition = _pointerDownPosition;
    _pointerDownPosition = null;
    widget.onTap?.call(context, pointerDownPosition);
  }

  void _activateWithoutPointer() {
    _pointerDownPosition = null;
    widget.onTap?.call(context);
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
  return formatClockTime(context, TimeOfDay.fromDateTime(value));
}

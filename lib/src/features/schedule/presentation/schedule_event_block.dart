import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/busymax_design.dart';
import '../../../app/busymax_surface_colors.dart';
import '../../../l10n/l10n.dart';
import '../../../schedule/schedule_item.dart';
import '../../../schedule/schedule_projection.dart';
import 'schedule_item_selection.dart';

class ScheduleEventBlock extends StatefulWidget {
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
  State<ScheduleEventBlock> createState() => _ScheduleEventBlockState();
}

class _ScheduleEventBlockState extends State<ScheduleEventBlock> {
  static const _activationShortcuts = <ShortcutActivator, Intent>{
    SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
    SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
  };

  Offset? _pointerDownPosition;
  var _showFocusHighlight = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
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
      excludeSemantics: true,
      child: FocusableActionDetector(
        enabled: interactive,
        mouseCursor: interactive ? SystemMouseCursors.click : MouseCursor.defer,
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
                    color: surfaceColors.control,
                    borderRadius: BorderRadius.circular(BusyMaxRadius.sm),
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
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: showTime
                        ? MainAxisAlignment.spaceBetween
                        : MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.max,
                    children: [
                      Flexible(
                        child: Text(
                          widget.item.title,
                          maxLines: titleMaxLines,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
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
    final parts = <String>[
      if (!widget.item.allDay && widget.item.start != null) _timeRange(context),
      if (widget.item.location != null && widget.item.location!.isNotEmpty)
        widget.item.location!,
      ScheduleProjection.sourceLabelForScheduleItem(widget.item),
    ];
    return parts.join(' · ');
  }

  String _semanticsLabel(BuildContext context) {
    return <String>[
      widget.item.title,
      scheduleTimeRange(context, widget.item),
      if (widget.item.location != null && widget.item.location!.isNotEmpty)
        widget.item.location!,
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
  return MaterialLocalizations.of(context).formatTimeOfDay(
    TimeOfDay.fromDateTime(value),
    alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
  );
}

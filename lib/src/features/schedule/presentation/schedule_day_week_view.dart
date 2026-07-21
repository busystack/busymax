import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:infinite_calendar_view/infinite_calendar_view.dart' as icv;
import 'package:intl/intl.dart';

import '../../../app/app_settings.dart';
import '../../../app/busymax_design.dart';
import '../../../app/busymax_surface_colors.dart';
import '../../../l10n/l10n.dart';
import '../../../schedule/schedule_item.dart';
import '../../../schedule/schedule_projection.dart';
import '../../../schedule/schedule_range.dart';
import 'schedule_event_block.dart';
import 'schedule_item_chip.dart';
import 'schedule_item_selection.dart';

const _fullDayBarDefaultHeight = 82.0;
const _fullDayBarMinHeight = 82.0;
const _fullDayBarMaxHeight = 260.0;
const _allDayResizeHandleHeight = 22.0;
const _timesIndicatorsWidth = 64.0;
const _defaultHeightPerMinute = 0.9;

class ScheduleDayWeekView extends StatefulWidget {
  const ScheduleDayWeekView({
    super.key,
    required this.range,
    required this.selectedDate,
    required this.daysShowed,
    required this.items,
    required this.onDaySelected,
    required this.onEmptySlot,
    required this.onItemSelected,
    required this.onTaskCompletionChanged,
    this.dayStartMinute = defaultScheduleDayStartMinute,
    this.dayEndMinute = defaultScheduleDayEndMinute,
  });

  final ScheduleRange range;
  final DateTime selectedDate;
  final int daysShowed;
  final List<ScheduleItem> items;
  final ValueChanged<DateTime> onDaySelected;
  final ValueChanged<DateTime> onEmptySlot;
  final ScheduleItemSelectionCallback onItemSelected;
  final void Function(TaskScheduleItem item, bool completed)
  onTaskCompletionChanged;
  final int dayStartMinute;
  final int dayEndMinute;

  @override
  State<ScheduleDayWeekView> createState() => _ScheduleDayWeekViewState();
}

class _ScheduleDayWeekViewState extends State<ScheduleDayWeekView> {
  late final icv.EventsController _controller;
  final _plannerKey = GlobalKey<icv.EventsPlannerState>();
  var _fullDayBarHeight = _fullDayBarDefaultHeight;
  var _heightPerMinute = _defaultHeightPerMinute;

  @override
  void initState() {
    super.initState();
    _controller = icv.EventsController();
    _jumpToVisibleDayStart();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reloadEvents();
  }

  @override
  void didUpdateWidget(covariant ScheduleDayWeekView oldWidget) {
    super.didUpdateWidget(oldWidget);
    _reloadEvents();
    if (oldWidget.daysShowed != widget.daysShowed ||
        !_sameDay(_plannerStartDate(oldWidget), _plannerStartDate(widget))) {
      _jumpToDate(_plannerStartDate(widget));
    }
    if (oldWidget.dayStartMinute != widget.dayStartMinute ||
        oldWidget.dayEndMinute != widget.dayEndMinute) {
      _jumpToVisibleDayStart();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final surfaceColors = BusyMaxSurfaceColors.of(context);
    final borderColor = busyMaxPanelBorder(context);
    final todayOverlayAlpha = widget.daysShowed == 1 ? 0.0 : 0.035;
    final todayColor = Color.alphaBlend(
      surfaceColors.controlActive.withValues(alpha: todayOverlayAlpha),
      colorScheme.surface,
    );
    final showFullDayBar = _hasRenderedFullDayEvents(context, widget);
    final fullDayBarHeight = showFullDayBar ? _fullDayBarHeight : 0.0;
    final daysHeaderHeight = widget.daysShowed == 1 ? 0.0 : 50.0;
    final visibleMinutes = _visibleMinuteRange(widget);

    final planner = icv.EventsPlanner(
      key: _plannerKey,
      controller: _controller,
      initialDate: _plannerStartDate(widget),
      daysShowed: widget.daysShowed,
      maxPreviousDays: 730,
      maxNextDays: 730,
      heightPerMinute: _heightPerMinute,
      initialVerticalScrollOffset: visibleMinutes.start * _heightPerMinute,
      daySeparationWidth: 1,
      dayEventsArranger: const icv.SideEventArranger(
        paddingLeft: 4,
        paddingRight: 4,
      ),
      onDayChange: (day) => widget.onDaySelected(_day(day)),
      daysHeaderParam: icv.DaysHeaderParam(
        daysHeaderHeight: widget.daysShowed == 1 ? 0 : 50,
        daysHeaderColor: colorScheme.surface,
        dayHeaderBuilder: (day, isToday) => widget.daysShowed == 1
            ? const SizedBox.shrink()
            : _PlannerDayHeader(day: day, isToday: isToday),
        topLeftCellBuilder: (_) => const SizedBox.shrink(),
      ),
      fullDayParam: icv.FullDayParam(
        fullDayEventsBarVisibility: showFullDayBar,
        fullDayEventsBarHeight: fullDayBarHeight,
        fullDayEventHeight: showFullDayBar ? 24 : 0,
        fullDayEventsBarLeftWidget: Center(
          child: Text(
            context.l10n.allDay,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        fullDayEventsBarDecoration: BoxDecoration(
          color: colorScheme.surface,
          border: Border(bottom: BorderSide(color: borderColor)),
        ),
        fullDayBackgroundColor: colorScheme.surface,
        fullDayEventsBuilder: (events, width) {
          return _FullDayScrollPane(
            events: events,
            height: fullDayBarHeight,
            width: width,
            onItemSelected: widget.onItemSelected,
            onTaskCompletionChanged: widget.onTaskCompletionChanged,
          );
        },
        fullDayEventBuilder: (event, width) {
          final group = _groupFrom(event);
          if (group != null) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: _SameSlotItemsStrip(
                items: group.items,
                height: 24,
                width: width,
                compact: true,
                onItemSelected: widget.onItemSelected,
                onTaskCompletionChanged: widget.onTaskCompletionChanged,
              ),
            );
          }
          final item = _itemFrom(event);
          if (item == null) {
            return const SizedBox.shrink();
          }
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: ScheduleItemChip(
              item: item,
              height: 24,
              width: width,
              compact: true,
              onTap: (context, [globalPosition]) =>
                  widget.onItemSelected(context, item, globalPosition),
              onTaskCompletionChanged: item is TaskScheduleItem
                  ? (completed) =>
                        widget.onTaskCompletionChanged(item, completed)
                  : null,
            ),
          );
        },
      ),
      dayParam: icv.DayParam(
        todayColor: todayColor,
        dayColor: colorScheme.surface,
        dayTopPadding: 8,
        dayBottomPadding: 16,
        onSlotMinutesRound: 15,
        onSlotTap: (_, _, roundDateTime) => widget.onEmptySlot(roundDateTime),
        dayCustomPainter: (heightPerMinute, isToday) => icv.LinesPainter(
          heightPerMinute: heightPerMinute,
          isToday: isToday,
          lineColor: borderColor,
          hourStrokeWidth: 0.7,
          halfStrokeWidth: 0.35,
          quarterStrokeWidth: 0,
          drawQuarterHour: false,
          drawVerticalLeftLine: true,
        ),
        dayEventBuilder: (event, height, width, heightPerMinute) {
          final group = _groupFrom(event);
          if (group != null) {
            return _SameSlotItemsStrip(
              items: group.items,
              height: height,
              width: width,
              compact: height < 36,
              onItemSelected: widget.onItemSelected,
              onTaskCompletionChanged: widget.onTaskCompletionChanged,
            );
          }
          final item = _itemFrom(event);
          if (item == null) {
            return const SizedBox.shrink();
          }
          return ScheduleItemChip(
            item: item,
            height: height,
            width: width,
            compact: height < 36,
            onTap: (context, [globalPosition]) =>
                widget.onItemSelected(context, item, globalPosition),
            onTaskCompletionChanged: item is TaskScheduleItem
                ? (completed) => widget.onTaskCompletionChanged(item, completed)
                : null,
          );
        },
      ),
      timesIndicatorsParam: icv.TimesIndicatorsParam(
        timesIndicatorsWidth: _timesIndicatorsWidth,
        timesIndicatorsHorizontalPadding: 6,
        timesIndicatorsCustomPainter: (heightPerMinute) => icv.HoursPainter(
          heightPerMinute: heightPerMinute,
          hourColor: colorScheme.onSurfaceVariant,
          halfHourColor: colorScheme.outline,
          quarterHourColor: colorScheme.outlineVariant,
          currentHourIndicatorColor: surfaceColors.mutedForeground,
          quarterHourMinHeightPerMinute: 100,
          textPainterBuilder: (time, defaultColor) => TextPainter(
            text: TextSpan(
              text: _formatHour(context, time),
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(color: defaultColor),
            ),
            textDirection: Directionality.of(context),
            textAlign: TextAlign.center,
          ),
        ),
      ),
      currentHourIndicatorParam: icv.CurrentHourIndicatorParam(
        currentHourIndicatorColor: surfaceColors.mutedForeground,
        currentHourIndicatorCustomPainter: (heightPerMinute, isToday) =>
            icv.TimeIndicatorPainter(
              heightPerMinute,
              isToday,
              surfaceColors.mutedForeground,
            ),
      ),
      offTimesParam: icv.OffTimesParam(
        offTimesAllDaysRanges: _offTimeRanges(
          startMinute: widget.dayStartMinute,
          endMinute: widget.dayEndMinute,
        ),
        offTimesColor: Color.alphaBlend(
          colorScheme.onSurface.withValues(alpha: 0.025),
          colorScheme.surface,
        ),
        offTimesAllDaysPainter:
            (column, day, isToday, heightPerMinute, ranges, color) =>
                icv.OffSetAllDaysPainter(
                  isToday,
                  heightPerMinute,
                  ranges,
                  color,
                  paintToday: true,
                ),
      ),
      pinchToZoomParam: icv.PinchToZoomParameters(
        pinchToZoomMinHeightPerMinute: 0.6,
        pinchToZoomMaxHeightPerMinute: 1.6,
        onZoomChange: (heightPerMinute) {
          setState(() => _heightPerMinute = heightPerMinute);
        },
      ),
    );
    if (!showFullDayBar) {
      return planner;
    }
    return Stack(
      clipBehavior: Clip.none,
      children: [
        planner,
        Positioned(
          top:
              daysHeaderHeight +
              fullDayBarHeight -
              _allDayResizeHandleHeight / 2,
          left: _timesIndicatorsWidth,
          right: 0,
          child: Center(
            child: _AllDayResizeHandle(
              onTap: _toggleFullDayBarHeight,
              onVerticalDragUpdate: (delta) {
                setState(() {
                  _fullDayBarHeight = (_fullDayBarHeight + delta)
                      .clamp(_fullDayBarMinHeight, _fullDayBarMaxHeight)
                      .toDouble();
                });
              },
            ),
          ),
        ),
      ],
    );
  }

  void _toggleFullDayBarHeight() {
    setState(() {
      _fullDayBarHeight = _fullDayBarHeight <= _fullDayBarDefaultHeight + 1
          ? 168.0
          : _fullDayBarDefaultHeight;
    });
  }

  void _reloadEvents() {
    final events = _ScheduleIcvEvent.fromItems(context, widget.items);
    _controller.updateCalendarData((calendarData) {
      calendarData.clearAll();
      calendarData.addEvents(events);
    });
  }

  void _jumpToDate(DateTime date) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _plannerKey.currentState?.jumpToDate(date);
    });
  }

  void _jumpToVisibleDayStart() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final visibleMinutes = _visibleMinuteRange(widget);
      _plannerKey.currentState?.updateVerticalScrollOffset(
        visibleMinutes.start * _heightPerMinute,
      );
    });
  }
}

DateTime _plannerStartDate(ScheduleDayWeekView widget) {
  return widget.daysShowed == 1
      ? _day(widget.selectedDate)
      : widget.range.start;
}

bool _sameDay(DateTime left, DateTime right) {
  return left.year == right.year &&
      left.month == right.month &&
      left.day == right.day;
}

({int start, int end}) _visibleMinuteRange(ScheduleDayWeekView widget) {
  var start = _validDayStartMinute(widget.dayStartMinute);
  var end = _validDayEndMinute(widget.dayEndMinute, start);
  final range = widget.range;

  for (final item in widget.items) {
    if (item.allDay || item.start == null) {
      continue;
    }
    final itemStart = item.start!;
    final itemEnd = item.end != null && item.end!.isAfter(itemStart)
        ? item.end!
        : itemStart.add(const Duration(minutes: 30));
    if (!itemStart.isBefore(range.end) || !itemEnd.isAfter(range.start)) {
      continue;
    }

    final firstDay = _day(
      itemStart.isAfter(range.start) ? itemStart : range.start,
    );
    final lastInstant = itemEnd.isBefore(range.end) ? itemEnd : range.end;
    final lastDay = _day(lastInstant);

    for (
      var day = firstDay;
      !day.isAfter(lastDay) && day.isBefore(range.end);
      day = day.add(const Duration(days: 1))
    ) {
      final nextDay = day.add(const Duration(days: 1));
      final segmentStart = itemStart.isAfter(day) ? itemStart : day;
      final segmentEnd = itemEnd.isBefore(nextDay) ? itemEnd : nextDay;
      if (!segmentStart.isBefore(segmentEnd)) {
        continue;
      }
      start = math.min(start, _minuteOfDay(segmentStart));
      end = math.max(end, _endMinuteOfDay(segmentEnd, day));
    }
  }

  return (
    start: start,
    end: math.max(start + 60, end).clamp(1, 24 * 60).toInt(),
  );
}

int _validDayStartMinute(int minute) {
  if (minute < 0 || minute >= 24 * 60) {
    return defaultScheduleDayStartMinute;
  }
  return minute;
}

int _validDayEndMinute(int minute, int startMinute) {
  if (minute <= startMinute || minute > 24 * 60) {
    return math.min(startMinute + 60, 24 * 60);
  }
  return minute;
}

int _minuteOfDay(DateTime value) => value.hour * 60 + value.minute;

int _endMinuteOfDay(DateTime value, DateTime day) {
  if (!value.isBefore(day.add(const Duration(days: 1)))) {
    return 24 * 60;
  }
  return _minuteOfDay(value);
}

List<icv.OffTimeRange> _offTimeRanges({
  required int startMinute,
  required int endMinute,
}) {
  final start = _validDayStartMinute(startMinute);
  final end = _validDayEndMinute(endMinute, start);
  return [
    if (start > 0)
      icv.OffTimeRange(
        const TimeOfDay(hour: 0, minute: 0),
        _timeOfDayFromMinute(start),
      ),
    if (end < 24 * 60)
      icv.OffTimeRange(
        _timeOfDayFromMinute(end),
        const TimeOfDay(hour: 24, minute: 0),
      ),
  ];
}

TimeOfDay _timeOfDayFromMinute(int minute) {
  if (minute >= 24 * 60) {
    return const TimeOfDay(hour: 24, minute: 0);
  }
  return TimeOfDay(hour: minute ~/ 60, minute: minute % 60);
}

class _PlannerDayHeader extends StatelessWidget {
  const _PlannerDayHeader({required this.day, required this.isToday});

  final DateTime day;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final surfaceColors = BusyMaxSurfaceColors.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(bottom: BorderSide(color: busyMaxPanelBorder(context))),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            DateFormat.E(locale).format(day),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Container(
            width: 28,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isToday ? surfaceColors.controlActive : null,
              borderRadius: BorderRadius.circular(BusyMaxRadius.sm),
            ),
            child: Text(
              '${day.day}',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: isToday
                    ? surfaceColors.foreground
                    : colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FullDayScrollPane extends StatefulWidget {
  const _FullDayScrollPane({
    required this.events,
    required this.height,
    required this.width,
    required this.onItemSelected,
    required this.onTaskCompletionChanged,
  });

  final List<icv.Event> events;
  final double height;
  final double width;
  final ScheduleItemSelectionCallback onItemSelected;
  final void Function(TaskScheduleItem item, bool completed)
  onTaskCompletionChanged;

  @override
  State<_FullDayScrollPane> createState() => _FullDayScrollPaneState();
}

class _FullDayScrollPaneState extends State<_FullDayScrollPane> {
  late final ScrollController _controller;

  @override
  void initState() {
    super.initState();
    _controller = ScrollController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const eventTopPadding = 2.0;
    final contentHeight = widget.events.length * (24 + eventTopPadding);
    final needsScroll = contentHeight > widget.height;
    return SizedBox(
      height: widget.height,
      width: widget.width,
      child: Scrollbar(
        controller: _controller,
        thumbVisibility: needsScroll,
        trackVisibility: false,
        thickness: 4,
        radius: const Radius.circular(999),
        child: SingleChildScrollView(
          key: const ValueKey('schedule-all-day-scroll'),
          controller: _controller,
          scrollDirection: Axis.vertical,
          physics: const ClampingScrollPhysics(),
          padding: const EdgeInsets.only(bottom: _allDayResizeHandleHeight),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              for (final event in widget.events)
                Padding(
                  padding: const EdgeInsets.only(top: eventTopPadding),
                  child: _FullDayEventTile(
                    event: event,
                    width: widget.width,
                    onItemSelected: widget.onItemSelected,
                    onTaskCompletionChanged: widget.onTaskCompletionChanged,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FullDayEventTile extends StatelessWidget {
  const _FullDayEventTile({
    required this.event,
    required this.width,
    required this.onItemSelected,
    required this.onTaskCompletionChanged,
  });

  final icv.Event event;
  final double width;
  final ScheduleItemSelectionCallback onItemSelected;
  final void Function(TaskScheduleItem item, bool completed)
  onTaskCompletionChanged;

  @override
  Widget build(BuildContext context) {
    final group = _groupFrom(event);
    if (group != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: _SameSlotItemsStrip(
          items: group.items,
          height: 24,
          width: width,
          compact: true,
          onItemSelected: onItemSelected,
          onTaskCompletionChanged: onTaskCompletionChanged,
        ),
      );
    }
    final item = _itemFrom(event);
    if (item == null) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: ScheduleItemChip(
        item: item,
        height: 24,
        width: width,
        compact: true,
        onTap: (context, [globalPosition]) =>
            onItemSelected(context, item, globalPosition),
        onTaskCompletionChanged: item is TaskScheduleItem
            ? (completed) => onTaskCompletionChanged(item, completed)
            : null,
      ),
    );
  }
}

class _AllDayResizeHandle extends StatelessWidget {
  const _AllDayResizeHandle({
    required this.onTap,
    required this.onVerticalDragUpdate,
  });

  final VoidCallback onTap;
  final ValueChanged<double> onVerticalDragUpdate;

  @override
  Widget build(BuildContext context) {
    final surfaceColors = BusyMaxSurfaceColors.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: 'Resize all-day panel',
      child: Semantics(
        button: true,
        label: 'Resize all-day panel',
        child: MouseRegion(
          cursor: SystemMouseCursors.resizeUpDown,
          child: GestureDetector(
            key: const ValueKey('schedule-all-day-resize-handle'),
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            onVerticalDragUpdate: (details) {
              onVerticalDragUpdate(details.delta.dy);
            },
            child: SizedBox(
              width: 68,
              height: _allDayResizeHandleHeight,
              child: Center(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: surfaceColors.control,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: busyMaxPanelBorder(context)),
                    boxShadow: [
                      BoxShadow(
                        color: BusyMaxShadow.floatingColor(context),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: SizedBox(
                    width: 52,
                    height: 16,
                    child: Icon(
                      Icons.drag_handle,
                      size: 18,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SameSlotItemsStrip extends StatefulWidget {
  const _SameSlotItemsStrip({
    required this.items,
    required this.height,
    required this.width,
    required this.compact,
    required this.onItemSelected,
    required this.onTaskCompletionChanged,
  });

  final List<ScheduleItem> items;
  final double height;
  final double width;
  final bool compact;
  final ScheduleItemSelectionCallback onItemSelected;
  final void Function(TaskScheduleItem item, bool completed)
  onTaskCompletionChanged;

  @override
  State<_SameSlotItemsStrip> createState() => _SameSlotItemsStripState();
}

class _SameSlotItemsStripState extends State<_SameSlotItemsStrip> {
  late final ScrollController _controller;

  @override
  void initState() {
    super.initState();
    _controller = ScrollController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final width = scheduleSafeBlockWidth(widget.width) ?? 0;
    final height = scheduleSafeBlockHeight(widget.height);
    final gap = widget.compact ? 3.0 : BusyMaxSpacing.xs;
    final minChipWidth = widget.compact ? 132.0 : 176.0;
    final visibleChipCount = math.min(widget.items.length, 2);
    final visibleWidth = width - (visibleChipCount - 1) * gap;
    final chipWidth = math.max(minChipWidth, visibleWidth / visibleChipCount);
    final needsScroll =
        widget.items.length * chipWidth + (widget.items.length - 1) * gap >
        width;

    return SizedBox(
      width: width,
      height: height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(BusyMaxRadius.sm),
        child: Scrollbar(
          controller: _controller,
          thumbVisibility: needsScroll,
          trackVisibility: false,
          thickness: 3,
          radius: const Radius.circular(999),
          child: SingleChildScrollView(
            controller: _controller,
            scrollDirection: Axis.horizontal,
            physics: const ClampingScrollPhysics(),
            child: Row(
              children: [
                for (var index = 0; index < widget.items.length; index++) ...[
                  ScheduleItemChip(
                    item: widget.items[index],
                    height: height,
                    width: chipWidth,
                    compact: widget.compact,
                    onTap: (context, [globalPosition]) => widget.onItemSelected(
                      context,
                      widget.items[index],
                      globalPosition,
                    ),
                    onTaskCompletionChanged:
                        widget.items[index] is TaskScheduleItem
                        ? (completed) => widget.onTaskCompletionChanged(
                            widget.items[index] as TaskScheduleItem,
                            completed,
                          )
                        : null,
                  ),
                  if (index != widget.items.length - 1) SizedBox(width: gap),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ScheduleIcvEvent {
  const _ScheduleIcvEvent._();

  static List<icv.Event> fromItems(
    BuildContext context,
    List<ScheduleItem> items,
  ) {
    final grouped = <String, List<({icv.Event event, ScheduleItem item})>>{};
    final ungrouped = <icv.Event>[];
    for (final item in items) {
      final event = fromItem(context, item);
      if (event == null) {
        continue;
      }
      if (event.isFullDay) {
        ungrouped.add(event);
        continue;
      }
      grouped
          .putIfAbsent(
            _slotKey(event),
            () => <({icv.Event event, ScheduleItem item})>[],
          )
          .add((event: event, item: item));
    }

    return [
      ...ungrouped,
      for (final entries in grouped.values)
        if (entries.length == 1)
          entries.single.event
        else
          entries.first.event.copyWith(
            title: entries.first.item.title,
            description: '${entries.length} items',
            data: _ScheduleSlotGroup([for (final entry in entries) entry.item]),
            eventType: _ScheduleSlotGroup,
          ),
    ];
  }

  static icv.Event? fromItem(BuildContext context, ScheduleItem item) {
    final start = item.start;
    if (start == null) {
      return null;
    }
    final color = ScheduleProjection.colorForItem(
      item,
      Theme.of(context).colorScheme.brightness,
    );
    if (item.allDay) {
      final startDay = _day(start);
      final endDay = item.end == null ? null : _day(item.end!);
      final inclusiveEnd = endDay?.subtract(const Duration(days: 1));
      final displayEnd = _endOfDay(
        inclusiveEnd != null && !inclusiveEnd.isBefore(startDay)
            ? inclusiveEnd
            : startDay,
      );
      return icv.Event(
        startTime: startDay,
        endTime: displayEnd,
        isFullDay: true,
        title: item.title,
        description: ScheduleProjection.sourceLabelForScheduleItem(item),
        color: color,
        textColor: _foregroundFor(color),
        data: item,
        eventType: item.kind,
      );
    }

    final end = item.end != null && item.end!.isAfter(start)
        ? item.end!
        : start.add(const Duration(minutes: 30));
    return icv.Event(
      startTime: start,
      endTime: end,
      title: item.title,
      description: ScheduleProjection.sourceLabelForScheduleItem(item),
      color: color,
      textColor: _foregroundFor(color),
      data: item,
      eventType: item.kind,
    );
  }
}

class _ScheduleSlotGroup {
  const _ScheduleSlotGroup(this.items);

  final List<ScheduleItem> items;
}

ScheduleItem? _itemFrom(icv.Event event) {
  return event.data is ScheduleItem ? event.data! as ScheduleItem : null;
}

_ScheduleSlotGroup? _groupFrom(icv.Event event) {
  return event.data is _ScheduleSlotGroup
      ? event.data! as _ScheduleSlotGroup
      : null;
}

String _slotKey(icv.Event event) {
  final end = event.endTime?.microsecondsSinceEpoch ?? -1;
  return [
    event.columnIndex,
    event.isFullDay,
    event.startTime.microsecondsSinceEpoch,
    end,
  ].join('|');
}

Color _foregroundFor(Color color) {
  return color.computeLuminance() > 0.54 ? Colors.black : Colors.white;
}

String _formatHour(BuildContext context, TimeOfDay value) {
  return MaterialLocalizations.of(context).formatTimeOfDay(
    TimeOfDay(hour: value.hour, minute: 0),
    alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
  );
}

DateTime _day(DateTime value) => DateTime(value.year, value.month, value.day);

DateTime _endOfDay(DateTime value) {
  final day = _day(value);
  return day
      .add(const Duration(days: 1))
      .subtract(const Duration(milliseconds: 1));
}

bool _hasRenderedFullDayEvents(
  BuildContext context,
  ScheduleDayWeekView widget,
) {
  final visibleStart = _plannerStartDate(widget);
  final visibleRange = ScheduleRange(
    start: visibleStart,
    end: visibleStart.add(Duration(days: widget.daysShowed)),
  );
  return widget.items.any((item) {
    final event = _ScheduleIcvEvent.fromItem(context, item);
    return event != null &&
        event.isFullDay &&
        _fullDayEventIntersectsRange(event, visibleRange);
  });
}

bool _fullDayEventIntersectsRange(icv.Event event, ScheduleRange range) {
  final start = _day(event.startTime);
  final inclusiveEnd = event.endTime == null ? start : _day(event.endTime!);
  final exclusiveEnd = inclusiveEnd.add(const Duration(days: 1));
  return start.isBefore(range.end) && exclusiveEnd.isAfter(range.start);
}

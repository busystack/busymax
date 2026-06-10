import 'package:flutter/material.dart';
import 'package:infinite_calendar_view/infinite_calendar_view.dart' as icv;
import 'package:intl/intl.dart';

import '../../../app/busymax_design.dart';
import '../../../l10n/l10n.dart';
import '../../../schedule/schedule_item.dart';
import '../../../schedule/schedule_projection.dart';
import '../../../schedule/schedule_range.dart';
import 'schedule_item_chip.dart';

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
  });

  final ScheduleRange range;
  final DateTime selectedDate;
  final int daysShowed;
  final List<ScheduleItem> items;
  final ValueChanged<DateTime> onDaySelected;
  final ValueChanged<DateTime> onEmptySlot;
  final void Function(BuildContext context, ScheduleItem item) onItemSelected;
  final void Function(TaskScheduleItem item, bool completed)
  onTaskCompletionChanged;

  @override
  State<ScheduleDayWeekView> createState() => _ScheduleDayWeekViewState();
}

class _ScheduleDayWeekViewState extends State<ScheduleDayWeekView> {
  late final icv.EventsController _controller;
  final _plannerKey = GlobalKey<icv.EventsPlannerState>();

  @override
  void initState() {
    super.initState();
    _controller = icv.EventsController();
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
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final borderColor = busyMaxPanelBorder(context);
    final todayOverlayAlpha = widget.daysShowed == 1 ? 0.0 : 0.035;
    final todayColor = Color.alphaBlend(
      colorScheme.primary.withValues(alpha: todayOverlayAlpha),
      colorScheme.surface,
    );
    final showFullDayBar = _hasRenderedFullDayEvents(context, widget);
    final fullDayBarHeight = showFullDayBar ? 82.0 : 0.0;

    return icv.EventsPlanner(
      key: _plannerKey,
      controller: _controller,
      initialDate: _plannerStartDate(widget),
      daysShowed: widget.daysShowed,
      maxPreviousDays: 730,
      maxNextDays: 730,
      heightPerMinute: 0.9,
      initialVerticalScrollOffset: 0.9 * 7 * 60,
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
        fullDayEventBuilder: (event, width) {
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
              onTap: (context) => widget.onItemSelected(context, item),
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
          final item = _itemFrom(event);
          if (item == null) {
            return const SizedBox.shrink();
          }
          return ScheduleItemChip(
            item: item,
            height: height,
            width: width,
            compact: height < 36,
            onTap: (context) => widget.onItemSelected(context, item),
            onTaskCompletionChanged: item is TaskScheduleItem
                ? (completed) => widget.onTaskCompletionChanged(item, completed)
                : null,
          );
        },
      ),
      timesIndicatorsParam: icv.TimesIndicatorsParam(
        timesIndicatorsWidth: 64,
        timesIndicatorsHorizontalPadding: 6,
        timesIndicatorsCustomPainter: (heightPerMinute) => icv.HoursPainter(
          heightPerMinute: heightPerMinute,
          hourColor: colorScheme.onSurfaceVariant,
          halfHourColor: colorScheme.outline,
          quarterHourColor: colorScheme.outlineVariant,
          currentHourIndicatorColor: colorScheme.primary,
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
        currentHourIndicatorColor: colorScheme.primary,
        currentHourIndicatorCustomPainter: (heightPerMinute, isToday) =>
            icv.TimeIndicatorPainter(
              heightPerMinute,
              isToday,
              colorScheme.primary,
            ),
      ),
      offTimesParam: icv.OffTimesParam(
        offTimesColor: Color.alphaBlend(
          colorScheme.onSurface.withValues(alpha: 0.025),
          colorScheme.surface,
        ),
      ),
      pinchToZoomParam: const icv.PinchToZoomParameters(
        pinchToZoomMinHeightPerMinute: 0.6,
        pinchToZoomMaxHeightPerMinute: 1.6,
      ),
    );
  }

  void _reloadEvents() {
    final events = widget.items
        .map((item) => _ScheduleIcvEvent.fromItem(context, item))
        .nonNulls
        .toList();
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

class _PlannerDayHeader extends StatelessWidget {
  const _PlannerDayHeader({required this.day, required this.isToday});

  final DateTime day;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
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
              color: isToday ? colorScheme.primary : null,
              borderRadius: BorderRadius.circular(BusyMaxRadius.sm),
            ),
            child: Text(
              '${day.day}',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: isToday ? colorScheme.onPrimary : colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScheduleIcvEvent {
  const _ScheduleIcvEvent._();

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

ScheduleItem? _itemFrom(icv.Event event) {
  return event.data is ScheduleItem ? event.data! as ScheduleItem : null;
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

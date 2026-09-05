import 'dart:math' as math;

import 'package:fluent_ui/fluent_ui.dart';
import 'package:infinite_calendar_view/infinite_calendar_view.dart' as icv;
import 'package:intl/intl.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../schedule/schedule_event_rescheduling.dart';
import '../../schedule/schedule_item.dart';
import '../../schedule/schedule_projection.dart';
import '../common/schedule/schedule_interactions.dart';
import '../common/schedule/schedule_planner_events.dart';
import '../common/schedule/schedule_preview_label.dart';

/// Fluent presentation of the shared planner data and desktop interactions.
/// Navigation, dialogs, and authoritative mutations remain in the page.
class WindowsScheduleDayWeekView extends StatefulWidget {
  const WindowsScheduleDayWeekView({
    super.key,
    required this.initialDate,
    required this.daysShowed,
    required this.items,
    required this.onOpen,
    required this.onSelectDate,
    required this.onVisibleDateChanged,
    required this.onEmptySlot,
    this.onRangeCreated,
    this.onReschedule,
    this.onTaskCompletionChanged,
    this.dayStartMinute = 420,
    this.dayEndMinute = 1320,
  });
  final DateTime initialDate;
  final int daysShowed;
  final List<ScheduleItem> items;
  final ValueChanged<ScheduleItem> onOpen;
  final ValueChanged<DateTime> onSelectDate;
  final ValueChanged<DateTime> onVisibleDateChanged;
  final ValueChanged<DateTime> onEmptySlot;
  final ValueChanged<ScheduleInterval>? onRangeCreated;
  final ScheduleRescheduleCallback? onReschedule;
  final void Function(TaskScheduleItem, bool)? onTaskCompletionChanged;
  final int dayStartMinute;
  final int dayEndMinute;
  @override
  State<WindowsScheduleDayWeekView> createState() =>
      _WindowsScheduleDayWeekViewState();
}

class _WindowsScheduleDayWeekViewState
    extends State<WindowsScheduleDayWeekView> {
  final _events = icv.EventsController();
  final _planner = GlobalKey<icv.EventsPlannerState>();
  final _interaction = GlobalKey<ScheduleInteractionRegionState>();
  double _heightPerMinute = .9;
  double _allDayHeight = 82;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reload();
  }

  @override
  void didUpdateWidget(covariant WindowsScheduleDayWeekView oldWidget) {
    super.didUpdateWidget(oldWidget);
    _reload();
    if (!_sameDay(oldWidget.initialDate, widget.initialDate)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !(_interaction.currentState?.active ?? false)) {
          _planner.currentState?.jumpToDate(widget.initialDate);
        }
      });
    }
  }

  void _reload() {
    final events = SchedulePlannerEvents.fromItems(
      widget.items,
      brightness: FluentTheme.of(context).brightness,
      groupLabel: AppLocalizations.of(context).scheduleItemCount,
    );
    _events.updateCalendarData((data) {
      data.clearAll();
      data.addEvents(events);
    });
  }

  @override
  void dispose() {
    _events.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final accent = theme.accentColor.defaultBrushFor(theme.brightness);
    final background = theme.scaffoldBackgroundColor;
    final grid = theme.resources.controlStrokeColorDefault;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final time = MediaQuery.alwaysUse24HourFormatOf(context)
        ? DateFormat.Hm(locale)
        : DateFormat.jm(locale);
    final hasAllDay = widget.items.any((item) => item.allDay);
    final bar = hasAllDay ? _allDayHeight : 0.0;
    final header = widget.daysShowed == 1 ? 0.0 : 50.0;
    final planner = icv.EventsPlanner(
      key: _planner,
      controller: _events,
      initialDate: widget.initialDate,
      textDirection: Directionality.of(context),
      daysShowed: widget.daysShowed,
      maxPreviousDays: 730,
      maxNextDays: 730,
      automaticAdjustHorizontalScrollToDay: false,
      heightPerMinute: _heightPerMinute,
      initialVerticalScrollOffset: widget.dayStartMinute * _heightPerMinute,
      daySeparationWidth: 1,
      dayEventsArranger: const SchedulePlannerEventArranger(),
      onDayChange: widget.onVisibleDateChanged,
      daysHeaderParam: icv.DaysHeaderParam(
        daysHeaderHeight: header,
        daysHeaderColor: background,
        topLeftCellBuilder: (_) => const SizedBox.shrink(),
        dayHeaderBuilder: (day, _) => header == 0
            ? const SizedBox.shrink()
            : SizedBox(
                height: 48,
                child: Center(
                  child: _sameDay(day, DateTime.now())
                      ? FilledButton(
                          onPressed: () => widget.onSelectDate(day),
                          child: Text(DateFormat.MMMEd(locale).format(day)),
                        )
                      : HyperlinkButton(
                          onPressed: () => widget.onSelectDate(day),
                          child: Text(DateFormat.MMMEd(locale).format(day)),
                        ),
                ),
              ),
      ),
      fullDayParam: icv.FullDayParam(
        showMultiDayEvents: false,
        fullDayEventsBarVisibility: hasAllDay,
        fullDayEventsBarHeight: bar,
        fullDayEventHeight: 24,
        fullDayBackgroundColor: background,
        fullDayEventsBarLeftWidget: Center(
          child: Text(
            AppLocalizations.of(context).allDay,
            style: theme.typography.caption,
          ),
        ),
        fullDayEventsBarDecoration: BoxDecoration(
          color: background,
          border: Border(bottom: BorderSide(color: grid)),
        ),
        fullDayEventsBuilder: (events, width) => SingleChildScrollView(
          key: const ValueKey('windows-all-day-scroll'),
          padding: const EdgeInsets.only(bottom: 16),
          child: Column(
            children: [
              for (final event in events)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: _tile(event, 24, width, locale),
                ),
            ],
          ),
        ),
      ),
      dayParam: icv.DayParam(
        dayColor: background,
        todayColor: background,
        dayTopPadding: 8,
        dayBottomPadding: 16,
        onSlotMinutesRound: 15,
        onSlotTap: (_, _, rounded) => widget.onEmptySlot(rounded),
        dayCustomPainter: (height, today) => icv.LinesPainter(
          heightPerMinute: height,
          isToday: today,
          lineColor: grid,
          hourStrokeWidth: .7,
          halfStrokeWidth: .35,
          quarterStrokeWidth: 0,
          drawQuarterHour: false,
          drawVerticalLeftLine: true,
        ),
        dayEventBuilder: (event, height, width, _) =>
            _tile(event, height, width, locale),
      ),
      timesIndicatorsParam: icv.TimesIndicatorsParam(
        timesIndicatorsWidth: 64,
        timesIndicatorsHorizontalPadding: 6,
        timesIndicatorsCustomPainter: (height) => icv.HoursPainter(
          heightPerMinute: height,
          hourColor: theme.inactiveColor,
          halfHourColor: theme.inactiveColor,
          quarterHourMinHeightPerMinute: 100,
          textPainterBuilder: (value, color) => TextPainter(
            text: TextSpan(
              text: time.format(DateTime(2000, 1, 1, value.hour, value.minute)),
              style: theme.typography.caption?.copyWith(color: color),
            ),
            textDirection: Directionality.of(context),
            textAlign: TextAlign.center,
          ),
        ),
      ),
      currentHourIndicatorParam: icv.CurrentHourIndicatorParam(
        currentHourIndicatorColor: accent,
        currentHourIndicatorCustomPainter: (height, today) =>
            icv.TimeIndicatorPainter(height, today, accent),
      ),
      pinchToZoomParam: icv.PinchToZoomParameters(
        pinchToZoomMinHeightPerMinute: .6,
        pinchToZoomMaxHeightPerMinute: 1.6,
        onZoomChange: (height) => setState(() => _heightPerMinute = height),
      ),
    );
    return ScheduleInteractionRegion(
      key: _interaction,
      coordinates: SchedulePlannerCoordinates(
        key: _planner,
        headerHeight: header,
        allDayHeight: bar,
      ),
      onReschedule: widget.onReschedule,
      onRangeCreated: widget.onRangeCreated,
      onEmptySlot: widget.onEmptySlot,
      previewColor: accent,
      previewBuilder: (context, interval, allDay) => Padding(
        padding: const EdgeInsets.all(4),
        child: Text(
          schedulePreviewLabel(context, interval, allDay),
          style: theme.typography.caption,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      child: Stack(
        children: [
          planner,
          if (hasAllDay)
            Positioned(
              top: header + bar - 8,
              left: 64,
              right: 0,
              child: Center(
                child: ScheduleInteractionBlocker(
                  child: MouseRegion(
                    cursor: SystemMouseCursors.resizeUpDown,
                    child: GestureDetector(
                      key: const ValueKey('windows-all-day-resize'),
                      behavior: HitTestBehavior.opaque,
                      onVerticalDragUpdate: (details) => setState(
                        () => _allDayHeight = (_allDayHeight + details.delta.dy)
                            .clamp(82.0, 260.0),
                      ),
                      child: SizedBox(
                        width: 48,
                        height: 16,
                        child: Center(
                          child: Container(
                            width: 24,
                            height: 3,
                            color: theme.inactiveColor,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _tile(icv.Event event, double height, double width, String locale) {
    final group = schedulePlannerGroup(event);
    final item = schedulePlannerItem(event);
    final items =
        group?.items ?? (item == null ? const <ScheduleItem>[] : [item]);
    final chipWidth = items.length <= 1
        ? width
        : math.max(132.0, width / math.min(items.length, 2) - 3);
    Widget chip(ScheduleItem item) => SizedBox(
      width: chipWidth,
      height: height,
      child: ScheduleEventInteraction(
        key: ValueKey(
          'windows-planner-${item.accountId}-${item.sourceId}-${item.id}-${event.startTime}',
        ),
        item: item,
        representedDate: event.startTime,
        dateOnly: event.isFullDay,
        child: _WindowsPlannerTile(
          item: item,
          height: height,
          onOpen: () => widget.onOpen(item),
          onCompleted:
              item is TaskScheduleItem && widget.onTaskCompletionChanged != null
              ? (value) => widget.onTaskCompletionChanged!(item, value)
              : null,
        ),
      ),
    );
    if (items.length == 1) return chip(items.single);
    return SizedBox(
      width: width,
      height: height,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final member in items)
              Padding(
                padding: const EdgeInsets.only(right: 3),
                child: chip(member),
              ),
          ],
        ),
      ),
    );
  }
}

class _WindowsPlannerTile extends StatelessWidget {
  const _WindowsPlannerTile({
    required this.item,
    required this.height,
    required this.onOpen,
    this.onCompleted,
  });
  final ScheduleItem item;
  final double height;
  final VoidCallback onOpen;
  final ValueChanged<bool>? onCompleted;
  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final color = ScheduleProjection.colorForItem(item, theme.brightness);
    final task = item is TaskScheduleItem ? item as TaskScheduleItem : null;
    return GestureDetector(
      onSecondaryTapUp: (_) => onOpen(),
      child: Button(
        onPressed: onOpen,
        style: ButtonStyle(
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 5, vertical: 1),
          ),
          backgroundColor: WidgetStatePropertyAll(color.withValues(alpha: .23)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (task != null && height >= 22)
              Padding(
                padding: const EdgeInsetsDirectional.only(end: 4),
                child: Checkbox(
                  checked: task.completed,
                  onChanged: task.capabilities.canEdit && onCompleted != null
                      ? (value) => onCompleted!(value ?? false)
                      : null,
                ),
              ),
            Expanded(
              child: Text(
                item.title,
                maxLines: height < 36 ? 1 : 3,
                overflow: TextOverflow.ellipsis,
                style: theme.typography.caption?.copyWith(
                  decoration: task?.completed == true
                      ? TextDecoration.lineThrough
                      : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

import 'package:busymax/src/ui/common/schedule/clock_hours_painter.dart';
import 'package:busymax/src/l10n/time_format_scope.dart';

import 'dart:math' as math;

import 'package:busymax/src/ui/common/flutter_material.dart';
import 'package:infinite_calendar_view/infinite_calendar_view.dart' as icv;

import '../../../app/app_settings.dart';
import 'schedule_presentation.dart';
import '../../../app/busymax_surface_colors.dart';
import '../../../l10n/l10n.dart';
import '../../../l10n/localized_formatters.dart';
import '../../../schedule/schedule_item.dart';
import '../../../schedule/schedule_event_rescheduling.dart';
import '../../../ui/common/schedule/schedule_interactions.dart';
import '../../../ui/common/schedule/schedule_preview_label.dart';
import '../../../ui/common/schedule/schedule_planner_events.dart';
import '../../../schedule/schedule_range.dart';
import '../../../schedule/schedule_navigation_intent.dart';
import 'schedule_event_block.dart';
import 'schedule_planner_accessibility.dart';
import 'schedule_item_chip.dart';
import '../../../features/schedule/presentation/schedule_item_selection.dart';

const _fullDayBarDefaultHeight = 82.0;
const _fullDayBarMinHeight = 82.0;
const _fullDayBarMaxHeight = 260.0;
const _allDayResizeHandleHeight = 22.0;
const _defaultHeightPerMinute = 0.9;

class ScheduleDayWeekView extends StatefulWidget {
  const ScheduleDayWeekView({
    super.key,
    this.presentation,
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
    this.onRangeCreated,
    this.onReschedule,
    this.navigationIntent,
  });

  final SchedulePresentation? presentation;

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
  final ValueChanged<ScheduleInterval>? onRangeCreated;
  final ScheduleRescheduleCallback? onReschedule;
  final ScheduleNavigationIntent? navigationIntent;

  @override
  State<ScheduleDayWeekView> createState() => _ScheduleDayWeekViewState();
}

class _ScheduleDayWeekViewState extends State<ScheduleDayWeekView> {
  late final icv.EventsController _controller;
  var _plannerKey = GlobalKey<icv.EventsPlannerState>();
  ({
    double width,
    double gutter,
    double minimumDay,
    int days,
    TextDirection direction,
  })?
  _plannerGeometry;
  bool _restoringPlannerGeometry = false;
  bool _plannerIsActive = true;
  final _interactionKey = GlobalKey<ScheduleInteractionRegionState>();
  var _fullDayBarHeight = _fullDayBarDefaultHeight;
  var _heightPerMinute = _defaultHeightPerMinute;
  int? _activeNavigationGeneration;
  bool _disableAnimations = false;
  bool _positionedForItems = false;
  bool _renderedAllDayVisible = false;
  bool _checkingVisibleDays = false;

  @override
  void initState() {
    super.initState();
    _controller = icv.EventsController();
    _positionedForItems = widget.items.isNotEmpty;
    _jumpToVisibleDayStart();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final wasActive = _plannerIsActive;
    _plannerIsActive = TickerMode.valuesOf(context).enabled;
    if (_plannerIsActive && !wasActive) {
      _jumpToDate(_plannerOriginDate(widget));
    }
    final disabled = MediaQuery.disableAnimationsOf(context);
    if (disabled != _disableAnimations) {
      _disableAnimations = disabled;
      if (disabled && _activeNavigationGeneration != null) {
        _settleNavigation(widget.navigationIntent);
      }
    }
    _reloadEvents();
  }

  @override
  void didUpdateWidget(covariant ScheduleDayWeekView oldWidget) {
    super.didUpdateWidget(oldWidget);
    _reloadEvents();
    if (!_positionedForItems && widget.items.isNotEmpty) {
      _positionedForItems = true;
      _jumpToVisibleDayStart();
    }
    if (oldWidget.daysShowed != widget.daysShowed ||
        !_sameDay(_plannerOriginDate(oldWidget), _plannerOriginDate(widget))) {
      final intent = widget.navigationIntent;
      if (intent != null &&
          intent.cause == ScheduleNavigationCause.adjacentPeriod &&
          intent.generation != oldWidget.navigationIntent?.generation) {
        _animateToDate(_plannerOriginDate(widget), intent);
      } else {
        _jumpToDate(_plannerOriginDate(widget));
      }
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
  Widget build(BuildContext context) => SchedulePresentationScope(
    presentation: widget.presentation,
    child: LayoutBuilder(builder: _build),
  );

  Widget _build(BuildContext context, BoxConstraints constraints) {
    final colorScheme = Theme.of(context).colorScheme;
    final surfaceColors = BusyMaxSurfaceColors.of(context);
    final workspaceColor = surfaceColors.window;
    final gridColor = scheduleGridColor(context);
    final todayOverlayAlpha = widget.daysShowed == 1 ? 0.0 : 0.035;
    final todayColor = Color.alphaBlend(
      surfaceColors.controlActive.withValues(alpha: todayOverlayAlpha),
      workspaceColor,
    );
    final showFullDayBar = _hasRenderedFullDayEvents(
      context,
      widget,
      visibleRange: _visiblePlannerRange(),
    );
    _renderedAllDayVisible = showFullDayBar;
    _checkVisibleDays();
    final touch = SchedulePresentation.of(context).touch;
    final fullDayBarHeight = showFullDayBar
        ? touch
              ? math.min(
                  _fullDayBarHeight,
                  math.max(48.0, constraints.maxHeight * .5),
                )
              : _fullDayBarHeight
        : 0.0;
    final daysHeaderHeight = widget.daysShowed == 1
        ? 0.0
        : touch
        ? math.max(
            50.0,
            _plannerTextSize(
                  context,
                  Theme.of(context).textTheme.labelSmall!,
                  'Wed',
                ).height +
                _plannerTextSize(
                  context,
                  Theme.of(context).textTheme.labelLarge!,
                  '30',
                ).height +
                8,
          )
        : 50.0;
    final minimumDayWidth = touch
        ? [
            48.0,
            for (var index = 0; index < 7; index++)
              _plannerTextSize(
                    context,
                    Theme.of(context).textTheme.labelSmall!,
                    localizedWeekdayLabel(
                      Localizations.localeOf(context).toLanguageTag(),
                      DateTime(2024, 1, index + 1),
                      abbreviated: true,
                    ),
                  ).width +
                  16,
          ].reduce(math.max)
        : 0.0;
    final visibleMinutes = _visibleMinuteRange(widget);
    final gutter = clockRulerWidth(
      context,
      Theme.of(context).textTheme.bodySmall ?? const TextStyle(),
    );
    final geometry = (
      width: constraints.maxWidth,
      gutter: gutter,
      minimumDay: minimumDayWidth,
      days: widget.daysShowed,
      direction: Directionality.of(context),
    );
    double? preservedVerticalOffset;
    if (_plannerGeometry != geometry && (_plannerGeometry != null || touch)) {
      // The upstream planner caches event arrangement by data, not by width.
      // Recreate its layout state on reflow, keeping the user's scroll context.
      final previous = _plannerKey.currentState;
      DateTime? visibleDay;
      var fraction = 0.0;
      if (previous != null) {
        if (previous.mainVerticalController.hasClients) {
          preservedVerticalOffset = previous.mainVerticalController.offset;
        }
        if (_plannerGeometry!.days == widget.daysShowed &&
            previous.mainHorizontalController.hasClients) {
          final offset = previous.mainHorizontalController.offset;
          final index = previous.dayWidthCalculator.indexForOffset(offset);
          final width = previous.dayWidthCalculator.widthForIndex(index);
          fraction = width == 0
              ? 0
              : (offset - previous.dayWidthCalculator.offsetForIndex(index)) /
                    width;
          visibleDay = DateTime(
            previous.initialDate.year,
            previous.initialDate.month,
            previous.initialDate.day +
                (previous.widget.textDirection == TextDirection.rtl
                    ? -index
                    : index),
          );
        }
      }
      if (_plannerGeometry?.direction != geometry.direction) {
        visibleDay = _plannerOriginDate(widget);
        fraction = 0;
      }
      _interactionKey.currentState?.cancel();
      _activeNavigationGeneration = null;
      _restoringPlannerGeometry = true;
      _plannerKey = GlobalKey<icv.EventsPlannerState>();
      {
        final targetDay = visibleDay ?? _plannerOriginDate(widget);
        final targetFraction = fraction;
        void restorePosition() {
          if (!mounted) {
            return;
          }
          final current = _plannerKey.currentState;
          if (current == null || !current.mainHorizontalController.hasClients) {
            _restoringPlannerGeometry = false;
            return;
          }
          final difference = _calendarDayDifference(
            current.initialDate,
            targetDay,
          );
          final index = current.widget.textDirection == TextDirection.rtl
              ? -difference
              : difference;
          current.mainHorizontalController.jumpTo(
            current.dayWidthCalculator.offsetForIndex(index) +
                targetFraction *
                    current.dayWidthCalculator.widthForIndex(index),
          );
        }

        WidgetsBinding.instance.addPostFrameCallback((_) {
          restorePosition();
          // The infinite scroll view also restores its initial position in a
          // child post-frame callback. Keep its temporary index out of the
          // workspace selection, then restore after that initialization.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            restorePosition();
            _restoringPlannerGeometry = false;
          });
          WidgetsBinding.instance.scheduleFrame();
        });
      }
    }
    _plannerGeometry = geometry;

    final planner = icv.EventsPlanner(
      key: _plannerKey,
      controller: _controller,
      textDirection: Directionality.of(context),
      automaticAdjustHorizontalScrollToDay: false,
      initialDate: _plannerOriginDate(widget),
      daysShowed: widget.daysShowed,
      dayWidthBuilder: touch && widget.daysShowed > 1
          ? (_, width) => math.max(width, minimumDayWidth)
          : null,
      maxPreviousDays: 730,
      maxNextDays: 730,
      heightPerMinute: _heightPerMinute,
      initialVerticalScrollOffset:
          preservedVerticalOffset ?? visibleMinutes.start * _heightPerMinute,
      daySeparationWidth: 1,
      dayEventsArranger: const SchedulePlannerEventArranger(),
      onDayChange: (day) {
        if (_plannerIsActive &&
            !_restoringPlannerGeometry &&
            _activeNavigationGeneration == null) {
          widget.onDaySelected(_day(day));
        }
      },
      daysHeaderParam: icv.DaysHeaderParam(
        daysHeaderHeight: daysHeaderHeight,
        daysHeaderColor: workspaceColor,
        dayHeaderBuilder: (day, isToday) => widget.daysShowed == 1
            ? const SizedBox.shrink()
            : _PlannerDayHeader(day: day, isToday: isToday),
        topLeftCellBuilder: (_) => const SizedBox.shrink(),
      ),
      fullDayParam: icv.FullDayParam(
        showMultiDayEvents: false,
        // Keep the zero-height bar mounted so its horizontal scroll position
        // stays synchronized while moving through days without all-day items.
        fullDayEventsBarVisibility: true,
        fullDayEventsBarHeight: fullDayBarHeight,
        fullDayEventHeight: showFullDayBar
            ? _plannerCompactItemHeight(context)
            : 0,
        fullDayEventsBarLeftWidget: Center(
          child: Text(
            context.l10n.allDay,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelSmall
                ?.copyWith(color: colorScheme.onSurfaceVariant),
          ),
        ),
        fullDayEventsBarDecoration: BoxDecoration(
          color: workspaceColor,
          border: Border(bottom: BorderSide(color: gridColor)),
        ),
        fullDayBackgroundColor: workspaceColor,
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
          final group = schedulePlannerGroup(event);
          if (group != null) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: _SameSlotItemsStrip(
                items: group.items,
                representedDate: event.startTime,
                height: _plannerCompactItemHeight(context),
                width: width,
                compact: true,
                onItemSelected: widget.onItemSelected,
                onTaskCompletionChanged: widget.onTaskCompletionChanged,
              ),
            );
          }
          final item = schedulePlannerItem(event);
          if (item == null) {
            return const SizedBox.shrink();
          }
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: _PlannerItemChip(
              item: item,
              representedDate: event.startTime,
              height: _plannerCompactItemHeight(context),
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
        dayColor: workspaceColor,
        dayTopPadding: 8,
        dayBottomPadding: 16,
        onSlotMinutesRound: 15,
        onSlotTap: (_, _, roundDateTime) => widget.onEmptySlot(roundDateTime),
        dayCustomPainter: (heightPerMinute, isToday) {
          final painter = icv.LinesPainter(
            heightPerMinute: heightPerMinute,
            isToday: isToday,
            lineColor: gridColor,
            hourStrokeWidth: 0.7,
            halfStrokeWidth: 0.35,
            quarterStrokeWidth: 0,
            drawQuarterHour: false,
            drawVerticalLeftLine: true,
          );
          return painter;
        },
        dayEventBuilder: (event, height, width, heightPerMinute) {
          final group = schedulePlannerGroup(event);
          if (group != null) {
            return _SameSlotItemsStrip(
              items: group.items,
              representedDate: event.startTime,
              height: height,
              width: width,
              compact: height < 36,
              onItemSelected: widget.onItemSelected,
              onTaskCompletionChanged: widget.onTaskCompletionChanged,
            );
          }
          final item = schedulePlannerItem(event);
          if (item == null) {
            return const SizedBox.shrink();
          }
          return _PlannerItemChip(
            item: item,
            representedDate: event.startTime,
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
        timesIndicatorsWidth: clockRulerWidth(
          context,
          Theme.of(context).textTheme.bodySmall ?? const TextStyle(),
        ),
        timesIndicatorsHorizontalPadding: 6,
        timesIndicatorsCustomPainter: (heightPerMinute) =>
            BusyMaxClockHoursPainter(
              heightPerMinute: heightPerMinute,
              hourColor: colorScheme.onSurfaceVariant,
              halfHourColor: colorScheme.outline,
              quarterHourColor: colorScheme.outlineVariant,
              currentHourIndicatorColor: surfaceColors.mutedForeground,
              quarterHourMinHeightPerMinute: 100,
              currentLabelSeparation: touch
                  ? _plannerTextSize(
                          context,
                          Theme.of(context).textTheme.labelSmall!,
                          _formatHour(
                            context,
                            const TimeOfDay(hour: 12, minute: 30),
                          ),
                        ).height +
                        4
                  : 10,
              textPainterBuilder: (time, defaultColor) => TextPainter(
                text: TextSpan(
                  text: _formatHour(context, time),
                  style: Theme.of(context).textTheme.labelSmall
                      ?.copyWith(color: defaultColor),
                ),
                textDirection: Directionality.of(context),
                textAlign: TextAlign.center,
                textScaler: MediaQuery.textScalerOf(context),
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
          workspaceColor,
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
    final coordinates = SchedulePlannerCoordinates(
      key: _plannerKey,
      headerHeight: daysHeaderHeight,
      allDayHeight: fullDayBarHeight,
      gutterWidth: gutter,
    );
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollUpdateNotification &&
            notification.metrics.axis == Axis.horizontal) {
          _checkVisibleDays();
        }
        if (notification is ScrollStartNotification &&
            notification.metrics.axis == Axis.horizontal &&
            notification.dragDetails != null) {
          _interruptNavigation();
        }
        return false;
      },
      child: ScheduleInteractionRegion(
        touch: SchedulePresentation.of(context).touch,
        key: _interactionKey,
        coordinates: coordinates,
        onRangeCreated: widget.onRangeCreated,
        onEmptySlot: widget.onEmptySlot,
        onReschedule: widget.onReschedule,
        previewColor: colorScheme.primary,
        previewBuilder: (context, interval, allDay) => Padding(
          padding: const EdgeInsets.all(4),
          child: Text(
            schedulePreviewLabel(context, interval, allDay),
            style: Theme.of(context).textTheme.labelSmall,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            if (touch)
              SchedulePlannerAccessibility(
                coordinates: coordinates,
                onItemSelected: widget.onItemSelected,
                onTaskCompletionChanged: widget.onTaskCompletionChanged,
                onEmptySlot: widget.onEmptySlot,
                onRangeCreated: widget.onRangeCreated,
                child: planner,
              )
            else
              planner,
            if (showFullDayBar)
              Positioned(
                top:
                    daysHeaderHeight +
                    fullDayBarHeight -
                    _allDayResizeHandleHeight / 2,
                left: clockRulerWidth(
                  context,
                  Theme.of(context).textTheme.bodySmall ?? const TextStyle(),
                ),
                right: 0,
                child: Center(
                  child: ScheduleInteractionBlocker(
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
              ),
          ],
        ),
      ),
    );
  }

  void _checkVisibleDays() {
    if (_checkingVisibleDays) {
      return;
    }
    _checkingVisibleDays = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkingVisibleDays = false;
      if (!mounted) {
        return;
      }
      final range = _visiblePlannerRange();
      if (range == null) return;
      final visible = _hasRenderedFullDayEvents(
        context,
        widget,
        visibleRange: range,
      );
      if (visible != _renderedAllDayVisible) {
        setState(() => _renderedAllDayVisible = visible);
      }
    });
  }

  DateTime _plannerOriginDate(ScheduleDayWeekView view) {
    // The upstream RTL planner counts days backwards from its origin, and
    // reports the chronological first day of a configured multi-day page.
    // Native Week therefore starts from the end of that same week.
    if ((view.presentation ?? SchedulePresentation.of(context)).touch &&
        Directionality.of(context) == TextDirection.rtl &&
        view.daysShowed > 1) {
      return _day(view.range.end.subtract(const Duration(days: 1)));
    }
    return _plannerStartDate(view);
  }

  ScheduleRange? _visiblePlannerRange() {
    final planner = _plannerKey.currentState;
    if (planner == null ||
        !planner.mainHorizontalController.hasClients ||
        planner.dayWidth <= 0) {
      return null;
    }
    final offset = planner.mainHorizontalController.offset;
    final first = planner.dayWidthCalculator.indexForOffset(offset);
    final last = planner.dayWidthCalculator.indexForOffset(
      offset +
          planner.width -
          planner.widget.timesIndicatorsParam.timesIndicatorsWidth -
          .01,
    );
    final a = planner.getDayFromIndex(first), b = planner.getDayFromIndex(last);
    final start = a.isBefore(b) ? a : b, end = a.isBefore(b) ? b : a;
    return ScheduleRange(
      start: _day(start),
      end: DateTime(end.year, end.month, end.day + 1),
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
    final events = SchedulePlannerEvents.fromItems(
      widget.items,
      brightness: Theme.of(context).brightness,
      groupLabel: context.l10n.scheduleItemCount,
    );
    _controller.updateCalendarData((calendarData) {
      calendarData.clearAll();
      calendarData.addEvents(events);
    });
  }

  void _jumpToDate(DateTime date) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || (_interactionKey.currentState?.active ?? false)) {
        return;
      }
      _plannerKey.currentState?.jumpToDate(date);
      // The planner reuses its stateful day cells while scrolling, but those
      // cells do not reload their cached events when their day changes. Notify
      // them again after the jump has rebuilt the cells for the destination.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _reloadEvents();
        }
      });
    });
  }

  void _animateToDate(DateTime date, ScheduleNavigationIntent intent) {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || (_interactionKey.currentState?.active ?? false)) {
        return;
      }
      final planner = _plannerKey.currentState;
      if (planner == null || !planner.mainHorizontalController.hasClients) {
        _jumpToDate(date);
        return;
      }
      _activeNavigationGeneration = intent.generation;
      final difference = _calendarDayDifference(planner.initialDate, date);
      final index = planner.widget.textDirection == TextDirection.rtl
          ? -difference
          : difference;
      final target = planner.dayWidthCalculator.offsetForIndex(index);
      if (_disableAnimations) {
        planner.mainHorizontalController.jumpTo(target);
        _finishNavigation(intent.generation);
        return;
      }
      final distance = (target - planner.mainHorizontalController.offset).abs();
      final page = planner.dayWidth * widget.daysShowed;
      final fraction = page <= 0 ? 1.0 : (distance / page).clamp(0.0, 1.0);
      if (fraction == 0) {
        _finishNavigation(intent.generation);
        return;
      }
      try {
        await planner.mainHorizontalController.animateTo(
          target,
          duration: BusyMaxMotion.calendarPeriod * fraction,
          curve: BusyMaxMotion.presentationCurve,
        );
      } finally {
        _finishNavigation(intent.generation);
      }
    });
  }

  void _settleNavigation(ScheduleNavigationIntent? intent) {
    if (intent == null) {
      return;
    }
    final planner = _plannerKey.currentState;
    if (planner == null || !planner.mainHorizontalController.hasClients) {
      return;
    }
    final difference = _calendarDayDifference(
      planner.initialDate,
      _plannerOriginDate(widget),
    );
    final index = planner.widget.textDirection == TextDirection.rtl
        ? -difference
        : difference;
    planner.mainHorizontalController.jumpTo(
      planner.dayWidthCalculator.offsetForIndex(index),
    );
    _finishNavigation(intent.generation);
  }

  void _interruptNavigation() {
    if (_activeNavigationGeneration == null) {
      return;
    }
    final controller = _plannerKey.currentState?.mainHorizontalController;
    if (controller?.hasClients ?? false) {
      controller!.jumpTo(controller.offset);
    }
    _activeNavigationGeneration = null;
  }

  void _finishNavigation(int generation) {
    if (!mounted || _activeNavigationGeneration != generation) {
      return;
    }
    _activeNavigationGeneration = null;
    // Destination day cells cache their events in the dependency. Refresh
    // after their dates have changed, preserving the existing correction.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _reloadEvents();
      }
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

int _calendarDayDifference(DateTime origin, DateTime target) => DateTime.utc(
  target.year,
  target.month,
  target.day,
).difference(DateTime.utc(origin.year, origin.month, origin.day)).inDays;

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
    if (item is JournalScheduleItem) {
      if (range.contains(itemStart)) {
        start = math.min(start, _minuteOfDay(itemStart));
        end = math.max(end, _minuteOfDay(itemStart) + 1);
      }
      continue;
    }
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
    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: surfaceColors.window,
        border: Border(bottom: BorderSide(color: scheduleGridColor(context))),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            localizedWeekdayLabel(
              Localizations.localeOf(context).toLanguageTag(),
              day,
              abbreviated: true,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Container(
            width: SchedulePresentation.of(context).touch
                ? math.max(
                    28,
                    _plannerTextSize(
                          context,
                          Theme.of(context).textTheme.labelLarge!,
                          '30',
                        ).width +
                        6,
                  )
                : 28,
            height: SchedulePresentation.of(context).touch
                ? math.max(
                    24,
                    _plannerTextSize(
                          context,
                          Theme.of(context).textTheme.labelLarge!,
                          '30',
                        ).height +
                        4,
                  )
                : 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isToday ? colorScheme.primary : null,
              borderRadius: BorderRadius.circular(ScheduleRadius.sm),
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
    final contentHeight =
        widget.events.length *
        (_plannerCompactItemHeight(context) + eventTopPadding);
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
    final group = schedulePlannerGroup(event);
    if (group != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: _SameSlotItemsStrip(
          items: group.items,
          representedDate: event.startTime,
          height: _plannerCompactItemHeight(context),
          width: width,
          compact: true,
          onItemSelected: onItemSelected,
          onTaskCompletionChanged: onTaskCompletionChanged,
        ),
      );
    }
    final item = schedulePlannerItem(event);
    if (item == null) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: _PlannerItemChip(
        item: item,
        representedDate: event.startTime,
        height: _plannerCompactItemHeight(context),
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
    final resizeLabel = context.l10n.resizeAllDayPanel;
    return Tooltip(
      message: resizeLabel,
      child: Semantics(
        button: true,
        label: resizeLabel,
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
                    border: Border.all(color: schedulePanelBorder(context)),
                    boxShadow: [
                      BoxShadow(
                        color: BusyMaxSurfaceColors.of(context).shade,
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
    required this.representedDate,
    required this.height,
    required this.width,
    required this.compact,
    required this.onItemSelected,
    required this.onTaskCompletionChanged,
  });

  final List<ScheduleItem> items;
  final DateTime representedDate;
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
    final gap = widget.compact ? 3.0 : ScheduleSpacing.xs;
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
        borderRadius: BorderRadius.circular(ScheduleRadius.sm),
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
                  _PlannerItemChip(
                    item: widget.items[index],
                    representedDate: widget.representedDate,
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

String _formatHour(BuildContext context, TimeOfDay value) {
  return formatClockTime(context, value);
}

DateTime _day(DateTime value) => DateTime(value.year, value.month, value.day);

bool _hasRenderedFullDayEvents(
  BuildContext context,
  ScheduleDayWeekView widget, {
  ScheduleRange? visibleRange,
}) {
  final visibleStart = _plannerStartDate(widget);
  final renderedRange =
      visibleRange ??
      ScheduleRange(
        start: visibleStart,
        end: visibleStart.add(Duration(days: widget.daysShowed)),
      );
  return widget.items.any((item) {
    final event = SchedulePlannerEvents.fromItem(
      item,
      Theme.of(context).brightness,
    );
    return event != null &&
        event.isFullDay &&
        _fullDayEventIntersectsRange(event, renderedRange);
  });
}

bool _fullDayEventIntersectsRange(icv.Event event, ScheduleRange range) {
  final start = _day(event.startTime);
  final inclusiveEnd = event.endTime == null ? start : _day(event.endTime!);
  final exclusiveEnd = inclusiveEnd.add(const Duration(days: 1));
  return start.isBefore(range.end) && exclusiveEnd.isAfter(range.start);
}

class _PlannerItemChip extends StatelessWidget {
  const _PlannerItemChip({
    required this.item,
    required this.representedDate,
    required this.height,
    required this.width,
    required this.compact,
    required this.onTap,
    this.onTaskCompletionChanged,
  });
  final ScheduleItem item;
  final DateTime representedDate;
  final double height;
  final double width;
  final bool compact;
  final void Function(BuildContext context, [Offset? globalPosition]) onTap;
  final ValueChanged<bool>? onTaskCompletionChanged;
  @override
  Widget build(BuildContext context) {
    ScheduleItemAnchorScope.register(context, item);
    return SizedBox(
      width: width,
      height: height,
      child: ScheduleEventInteraction(
        key: ValueKey(
          'planner-${item.accountId}-${item.sourceId}-${item.id}-${representedDate.toIso8601String()}',
        ),
        item: item,
        representedDate: representedDate,
        dateOnly: item.allDay,
        child: ScheduleItemChip(
          item: item,
          height: height,
          width: width,
          compact: compact,
          onTap: onTap,
          onTaskCompletionChanged: onTaskCompletionChanged,
        ),
      ),
    );
  }
}

Size _plannerTextSize(BuildContext context, TextStyle style, String text) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: Directionality.of(context),
    textScaler: MediaQuery.textScalerOf(context),
  )..layout();
  final size = painter.size;
  painter.dispose();
  return size;
}

double _plannerCompactItemHeight(BuildContext context) =>
    SchedulePresentation.of(context).touch
    ? math.max(
        24,
        _plannerTextSize(
              context,
              Theme.of(context).textTheme.bodySmall!,
              'Task',
            ).height +
            4,
      )
    : 24;

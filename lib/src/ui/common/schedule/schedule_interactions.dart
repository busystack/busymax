import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show ViewFocusEvent, ViewFocusState;

import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:infinite_calendar_view/infinite_calendar_view.dart' as icv;

import '../../../schedule/schedule_event_rescheduling.dart';
import '../../../schedule/schedule_item.dart';

typedef SchedulePreviewBuilder =
    Widget Function(
      BuildContext context,
      ScheduleInterval interval,
      bool allDay,
    );
typedef ScheduleRescheduleCallback =
    Future<void> Function(
      ScheduleRescheduleRequest request,
      bool Function() isActive,
    );

final class SchedulePointerTime {
  const SchedulePointerTime(this.wall, {this.dateOnly = false});
  final DateTime wall;
  final bool dateOnly;
}

/// Planner coordinates are read at every update, including scroll ticks. No
/// selected-date assumption, cached day width, or display event end is used.
final class SchedulePlannerCoordinates {
  const SchedulePlannerCoordinates({
    required this.key,
    required this.headerHeight,
    required this.allDayHeight,
    this.gutterWidth = 64,
    this.dayTopPadding = 8,
  });
  final GlobalKey<icv.EventsPlannerState> key;
  final double headerHeight;
  final double allDayHeight;
  final double gutterWidth;
  final double dayTopPadding;

  icv.EventsPlannerState? get planner => key.currentState;
  RenderBox? get box => key.currentContext?.findRenderObject() as RenderBox?;
  double get gridTop => headerHeight + allDayHeight;
  bool get rtl => planner?.widget.textDirection == TextDirection.rtl;

  SchedulePointerTime? at(Offset global) {
    final p = planner;
    final b = box;
    if (p == null ||
        b == null ||
        !b.hasSize ||
        !p.mainHorizontalController.hasClients ||
        !p.mainVerticalController.hasClients ||
        p.dayWidth <= 0) {
      return null;
    }
    final local = b.globalToLocal(global);
    final left = rtl ? 0.0 : gutterWidth;
    final right = b.size.width - (rtl ? gutterWidth : 0);
    if (local.dx < left ||
        local.dx >= right ||
        local.dy < headerHeight ||
        local.dy >= b.size.height) {
      return null;
    }
    final index =
        (((rtl ? right - local.dx : local.dx - left) +
                    p.mainHorizontalController.offset) /
                p.dayWidth)
            .floor();
    final day = p.getDayFromIndex(index);
    if (local.dy < gridTop) {
      return SchedulePointerTime(ScheduleTimeMath.date(day), dateOnly: true);
    }
    final minutes =
        ((local.dy -
                    gridTop +
                    p.mainVerticalController.offset -
                    dayTopPadding) /
                p.heightPerMinute)
            .clamp(0.0, 1440.0);
    return SchedulePointerTime(
      DateTime.utc(day.year, day.month, day.day).add(
        Duration(
          microseconds: (minutes * Duration.microsecondsPerMinute).round(),
        ),
      ),
    );
  }

  Iterable<Rect> rectangles(ScheduleInterval interval, bool allDay) sync* {
    final p = planner;
    final b = box;
    if (p == null ||
        b == null ||
        !b.hasSize ||
        !p.mainHorizontalController.hasClients ||
        !p.mainVerticalController.hasClients) {
      return;
    }
    final left = rtl ? 0.0 : gutterWidth;
    final offset = p.mainHorizontalController.offset;
    final first = (offset / p.dayWidth).floor();
    final last = ((offset + b.size.width - gutterWidth) / p.dayWidth).ceil();
    final start = allDay
        ? ScheduleTimeMath.civil(interval.start)
        : ScheduleTimeMath.civil(interval.start.toLocal());
    final end = allDay
        ? ScheduleTimeMath.civil(interval.end)
        : ScheduleTimeMath.civil(interval.end.toLocal());
    for (var index = first; index <= last; index++) {
      final value = p.getDayFromIndex(index);
      final day = DateTime.utc(value.year, value.month, value.day);
      final next = day.add(const Duration(days: 1));
      if (!start.isBefore(next) || !end.isAfter(day)) continue;
      final x = rtl
          ? b.size.width - gutterWidth - (index + 1) * p.dayWidth + offset
          : left + index * p.dayWidth - offset;
      if (allDay) {
        yield Rect.fromLTWH(
          x + 4,
          headerHeight + 2,
          p.dayWidth - 8,
          math.max(24, allDayHeight - 4),
        );
      } else {
        final a =
            (start.isBefore(day) ? day : start).difference(day).inMicroseconds /
            Duration.microsecondsPerMinute;
        final z =
            (end.isAfter(next) ? next : end).difference(day).inMicroseconds /
            Duration.microsecondsPerMinute;
        final y = gridTop + dayTopPadding - p.mainVerticalController.offset;
        final raw = Rect.fromLTWH(
          x + 4,
          y + a * p.heightPerMinute,
          p.dayWidth - 8,
          math.max(4, (z - a) * p.heightPerMinute),
        );
        final clipped = raw.intersect(
          Rect.fromLTRB(
            left,
            gridTop,
            b.size.width - (rtl ? gutterWidth : 0),
            b.size.height,
          ),
        );
        if (!clipped.isEmpty) yield clipped;
      }
    }
  }

  void scrollAt(Offset global) {
    final p = planner;
    final b = box;
    if (p == null || b == null || !b.hasSize) return;
    final at = b.globalToLocal(global);
    double velocity(double value, double low, double high) {
      const edge = 36.0;
      if (value < low || value > high) return 0;
      if (value < low + edge) return -math.min(14.0, (low + edge - value) / 2);
      if (value > high - edge) return math.min(14, (value - high + edge) / 2);
      return 0;
    }

    void step(ScrollController controller, double delta) {
      if (!controller.hasClients || delta == 0) return;
      final position = controller.position;
      final next = (position.pixels + delta).clamp(
        position.minScrollExtent,
        position.maxScrollExtent,
      );
      if (next != position.pixels) controller.jumpTo(next);
    }

    step(
      p.mainHorizontalController,
      (rtl ? -1 : 1) *
          velocity(
            at.dx,
            rtl ? 0 : gutterWidth,
            b.size.width - (rtl ? gutterWidth : 0),
          ),
    );
    if (at.dy >= gridTop) {
      step(p.mainVerticalController, velocity(at.dy, gridTop, b.size.height));
    }
  }
}

/// Identity and authoritative interval travel with the real item, not the
/// synthetic equal-slot group or the planner's clipped segment interval.
final class ScheduleEventDragData {
  ScheduleEventDragData(this.item, this.representedDate);
  final CalendarScheduleItem item;
  final DateTime representedDate;
  Offset? pointerDown;
  SchedulePointerTime? grab;
  Object? token;
  ScheduleInterval get original => ScheduleInterval(item.start!, item.end!);
}

class ScheduleInteractionRegion extends StatefulWidget {
  const ScheduleInteractionRegion({
    super.key,
    required this.child,
    required this.previewBuilder,
    required this.previewColor,
    this.coordinates,
    this.onReschedule,
    this.onRangeCreated,
    this.onEmptySlot,
  });
  final Widget child;
  final SchedulePlannerCoordinates? coordinates;
  final SchedulePreviewBuilder previewBuilder;
  final Color previewColor;
  final ScheduleRescheduleCallback? onReschedule;
  final ValueChanged<ScheduleInterval>? onRangeCreated;
  final ValueChanged<DateTime>? onEmptySlot;

  static ScheduleInteractionRegionState? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_InteractionScope>()?.state;
  @override
  State<ScheduleInteractionRegion> createState() =>
      ScheduleInteractionRegionState();
}

class ScheduleInteractionRegionState extends State<ScheduleInteractionRegion>
    with WidgetsBindingObserver {
  final changes = ValueNotifier(0);
  final timeMath = const ScheduleTimeMath();
  final _dates = <Object, ({RenderBox Function() box, DateTime day})>{};
  Object? _token;
  ScheduleEventDragData? _drag;
  ScheduleTimingAction _action = ScheduleTimingAction.move;
  SchedulePointerTime? _anchor;
  Offset? _pointer;
  ScheduleInterval? _preview;
  Timer? _scroll;
  bool _saving = false;
  bool get active => _token != null;
  bool get canMove => widget.onReschedule != null && !active;
  ScheduleInterval? get preview => _preview;
  bool get allDay => _drag?.item.allDay ?? false;
  bool owns(ScheduleEventDragData? data) =>
      active && data != null && identical(data.token, _token);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    HardwareKeyboard.instance.addHandler(_onKey);
  }

  bool _onKey(KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.escape &&
        active) {
      cancel();
      return true;
    }
    return false;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) cancel();
  }

  @override
  void didChangeViewFocus(ViewFocusEvent event) {
    if (event.state == ViewFocusState.unfocused) cancel();
  }

  @override
  void dispose() {
    _scroll?.cancel();
    _token = null;
    WidgetsBinding.instance.removeObserver(this);
    HardwareKeyboard.instance.removeHandler(_onKey);
    changes.dispose();
    super.dispose();
  }

  SchedulePointerTime? at(Offset global) {
    final planner = widget.coordinates;
    if (planner != null) return planner.at(global);
    for (final date in _dates.values) {
      final box = date.box();
      if (box.attached &&
          box.hasSize &&
          box.size.contains(box.globalToLocal(global))) {
        return SchedulePointerTime(date.day, dateOnly: true);
      }
    }
    return null;
  }

  bool begin(ScheduleEventDragData data, ScheduleTimingAction action) {
    if (active ||
        widget.onReschedule == null ||
        !data.item.canReschedule ||
        data.grab == null) {
      return false;
    }
    _token = data.token = Object();
    _drag = data;
    _action = action;
    _anchor = data.grab;
    _pointer = data.pointerDown;
    _preview = data.original;
    _startScroll();
    _notify();
    return true;
  }

  void beginSelection(Offset down) {
    if (active || widget.onRangeCreated == null) return;
    final value = at(down);
    if (value == null || value.dateOnly) return;
    _token = Object();
    _anchor = value;
    _pointer = down;
    _startScroll();
  }

  void _startScroll() {
    _scroll?.cancel();
    _scroll = Timer.periodic(const Duration(milliseconds: 16), (_) {
      if (!active || _saving || _pointer == null) return;
      widget.coordinates?.scrollAt(_pointer!);
      update(_pointer!);
    });
  }

  bool accepts(ScheduleEventDragData data, Offset global) =>
      !_saving && active && identical(data.token, _token) && _valid(at(global));

  bool _valid(SchedulePointerTime? point) {
    if (point == null) return false;
    if (_drag == null) return !point.dateOnly;
    if (allDay) return point.dateOnly;
    return _action == ScheduleTimingAction.move || !point.dateOnly;
  }

  void update(Offset global) {
    if (!active || _saving) return;
    _pointer = global;
    final point = at(global);
    if (!_valid(point)) {
      _preview = null;
    } else if (_drag case final drag?) {
      _preview = timeMath.change(
        original: drag.original,
        action: _action,
        anchor: _anchor!.wall,
        pointer: point!.wall,
        dateOnly: point.dateOnly,
        allDay: drag.item.allDay,
      );
    } else {
      _preview = timeMath.selection(_anchor!.wall, point!.wall);
    }
    _notify();
  }

  void accept(ScheduleEventDragData data, Offset global) {
    if (!accepts(data, global)) return;
    update(global);
    finish();
  }

  void finish() {
    if (!active || _saving) return;
    _scroll?.cancel();
    final interval = _preview;
    if (interval == null || _pointer == null || !_valid(at(_pointer!))) {
      cancel();
      return;
    }
    final drag = _drag;
    if (drag == null) {
      cancel();
      widget.onRangeCreated?.call(interval);
      return;
    }
    if (interval.sameAs(drag.original)) {
      cancel();
      return;
    }
    _saving = true;
    final token = _token;
    final request = ScheduleRescheduleRequest(
      item: drag.item,
      interval: interval,
      action: _action,
    );
    unawaited(
      Future.sync(
        () => widget.onReschedule?.call(
          request,
          () => mounted && identical(token, _token),
        ),
      ).whenComplete(() {
        if (mounted && identical(token, _token)) cancel();
      }),
    );
  }

  /// Drag-end is cleanup only. It must never act as an accepted drop.
  void dragEnded(ScheduleEventDragData data) {
    if (!_saving && identical(data.token, _token)) cancel();
  }

  void cancel() {
    _scroll?.cancel();
    _token = null;
    _drag = null;
    _anchor = null;
    _pointer = null;
    _preview = null;
    _saving = false;
    if (mounted) _notify();
  }

  void _notify() => changes.value++;

  bool _backgroundAllowed(PointerDownEvent event) {
    if (active || widget.onRangeCreated == null || widget.coordinates == null) {
      return false;
    }
    final point = at(event.position);
    if (point == null || point.dateOnly) return false;
    final box = widget.coordinates!.box!;
    final local = box.globalToLocal(event.position);
    if (local.dx > box.size.width - 14 || local.dy > box.size.height - 14) {
      return false;
    }
    final result = HitTestResult();
    RendererBinding.instance.hitTestInView(
      result,
      event.position,
      event.viewId,
    );
    return !result.path.any((entry) => entry.target is _InteractionBlockerBox);
  }

  @override
  Widget build(BuildContext context) {
    Widget body = DragTarget<ScheduleEventDragData>(
      onWillAcceptWithDetails: (details) =>
          !_saving &&
          details.data.item.canReschedule &&
          (!active || identical(details.data.token, _token)),
      onMove: (details) => update(details.offset),
      onAcceptWithDetails: (details) => accept(details.data, details.offset),
      builder: (context, candidates, rejected) => Stack(
        children: [
          widget.child,
          Positioned.fill(
            child: IgnorePointer(
              child: ListenableBuilder(
                listenable: changes,
                builder: (context, _) {
                  final interval = _preview;
                  if (interval == null || widget.coordinates == null) {
                    return const SizedBox.shrink();
                  }
                  final rects = widget.coordinates!.rectangles(
                    interval,
                    allDay,
                  );
                  return Stack(
                    clipBehavior: Clip.hardEdge,
                    children: [
                      for (final rect in rects)
                        Positioned.fromRect(
                          rect: rect,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: widget.previewColor.withValues(alpha: .25),
                              border: Border.all(color: widget.previewColor),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: ClipRect(
                              child: widget.previewBuilder(
                                context,
                                interval,
                                allDay,
                              ),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
    body = RawGestureDetector(
      gestures: {
        _GridSelectionGesture:
            GestureRecognizerFactoryWithHandlers<_GridSelectionGesture>(
              _GridSelectionGesture.new,
              (recognizer) => recognizer
                ..allowed = _backgroundAllowed
                ..started = beginSelection
                ..moved = update
                ..finished = finish
                ..cancelled = cancel
                ..clicked = (point) {
                  final time = at(point);
                  if (time != null && !time.dateOnly) {
                    widget.onEmptySlot?.call(timeMath.snap(time.wall));
                  }
                },
            ),
      },
      child: body,
    );
    return _InteractionScope(state: this, child: body);
  }
}

class _InteractionScope extends InheritedWidget {
  const _InteractionScope({required this.state, required super.child});
  final ScheduleInteractionRegionState state;
  @override
  bool updateShouldNotify(_InteractionScope oldWidget) =>
      state != oldWidget.state;
}

/// Marks real controls/events as ineligible origins for background selection.
class ScheduleInteractionBlocker extends SingleChildRenderObjectWidget {
  const ScheduleInteractionBlocker({super.key, required super.child});
  @override
  RenderObject createRenderObject(BuildContext context) =>
      _InteractionBlockerBox();
}

class _InteractionBlockerBox extends RenderProxyBox {
  @override
  bool hitTestSelf(Offset position) => true;
}

/// Eagerly claims primary mouse presses ONLY on verified grid background.
/// This deliberately arbitrates before the package's drag-enabled scrollables.
class _GridSelectionGesture extends OneSequenceGestureRecognizer {
  bool Function(PointerDownEvent)? allowed;
  ValueChanged<Offset>? started;
  ValueChanged<Offset>? moved;
  ValueChanged<Offset>? clicked;
  VoidCallback? finished;
  VoidCallback? cancelled;
  Offset? _down;
  int? _pointer;
  bool _dragging = false;
  @override
  bool isPointerAllowed(PointerDownEvent event) =>
      _pointer == null &&
      event.kind == PointerDeviceKind.mouse &&
      event.buttons == kPrimaryMouseButton &&
      (allowed?.call(event) ?? false) &&
      super.isPointerAllowed(event);
  @override
  void addAllowedPointer(PointerDownEvent event) {
    _pointer = event.pointer;
    _down = event.position;
    startTrackingPointer(event.pointer, event.transform);
    resolve(GestureDisposition.accepted);
  }

  @override
  void handleEvent(PointerEvent event) {
    if (event.pointer != _pointer) return;
    if (event is PointerMoveEvent) {
      if (!_dragging && (event.position - _down!).distance > kTouchSlop) {
        _dragging = true;
        started?.call(_down!);
      }
      if (_dragging) moved?.call(event.position);
    } else if (event is PointerUpEvent) {
      if (_dragging) {
        moved?.call(event.position);
        finished?.call();
      } else {
        clicked?.call(event.position);
      }
      stopTrackingPointer(event.pointer);
      _reset();
    } else if (event is PointerCancelEvent) {
      cancelled?.call();
      stopTrackingPointer(event.pointer);
      _reset();
    }
  }

  void _reset() {
    _down = null;
    _pointer = null;
    _dragging = false;
  }

  @override
  void rejectGesture(int pointer) {
    if (_pointer == pointer) {
      stopTrackingPointer(pointer);
      _reset();
    }
  }

  @override
  void didStopTrackingLastPointer(int pointer) {}
  @override
  String get debugDescription => 'calendar background range';
}

/// Wrap each actual event, including each member of an equal-time strip.
class ScheduleEventInteraction extends StatefulWidget {
  const ScheduleEventInteraction({
    super.key,
    required this.item,
    required this.representedDate,
    required this.child,
    this.dateOnly = false,
  });
  final ScheduleItem item;
  final DateTime representedDate;
  final bool dateOnly;
  final Widget child;
  @override
  State<ScheduleEventInteraction> createState() =>
      _ScheduleEventInteractionState();
}

class _ScheduleEventInteractionState extends State<ScheduleEventInteraction> {
  ScheduleEventDragData? _data;
  bool _ownsResize = false;

  @override
  void didUpdateWidget(covariant ScheduleEventInteraction oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item != widget.item &&
        !(ScheduleInteractionRegion.maybeOf(context)?.owns(_data) ?? false)) {
      _data = null;
    }
  }

  void _down(PointerDownEvent event, ScheduleInteractionRegionState region) {
    if (region.active ||
        event.buttons != kPrimaryMouseButton ||
        event.kind != PointerDeviceKind.mouse) {
      return;
    }
    final item = widget.item;
    if (item is! CalendarScheduleItem || !item.canReschedule) return;
    _data ??= ScheduleEventDragData(item, widget.representedDate);
    _data!
      ..pointerDown = event.position
      ..grab =
          region.at(event.position) ??
          SchedulePointerTime(
            widget.representedDate,
            dateOnly: widget.dateOnly,
          );
  }

  @override
  Widget build(BuildContext context) {
    final region = ScheduleInteractionRegion.maybeOf(context);
    final item = widget.item;
    if (region == null ||
        region.widget.onReschedule == null ||
        item is! CalendarScheduleItem ||
        !item.canReschedule) {
      return ScheduleInteractionBlocker(child: widget.child);
    }
    final data = _data ??= ScheduleEventDragData(item, widget.representedDate);
    final first =
        ScheduleTimeMath.dayDifference(widget.representedDate, item.start!) ==
        0;
    final last =
        ScheduleTimeMath.dayDifference(
          widget.representedDate,
          item.allDay
              ? ScheduleTimeMath.date(item.end!, -1)
              : item.end!.subtract(const Duration(microseconds: 1)),
        ) ==
        0;
    Widget handle(ScheduleTimingAction action) => MouseRegion(
      cursor: item.allDay
          ? SystemMouseCursors.resizeLeftRight
          : SystemMouseCursors.resizeUpDown,
      child: GestureDetector(
        key: ValueKey('schedule-${action.name}-${item.id}'),
        behavior: HitTestBehavior.opaque,
        supportedDevices: const {PointerDeviceKind.mouse},
        onPanStart: (details) {
          _ownsResize = _data != null && region.begin(_data!, action);
          if (_ownsResize) {
            region.update(details.globalPosition);
          }
        },
        onPanUpdate: (details) {
          if (_ownsResize && region.owns(_data)) {
            region.update(details.globalPosition);
          }
        },
        onPanEnd: (_) {
          if (_ownsResize && region.owns(_data)) region.finish();
          _ownsResize = false;
        },
        onPanCancel: () {
          if (_ownsResize && region.owns(_data)) region.cancel();
          _ownsResize = false;
        },
        child: SizedBox(
          width: item.allDay ? 8 : 32,
          height: item.allDay ? double.infinity : 8,
          child: Center(
            child: Container(
              width: item.allDay ? 2 : 18,
              height: item.allDay ? 12 : 2,
              color: region.widget.previewColor.withValues(alpha: .7),
            ),
          ),
        ),
      ),
    );
    return ScheduleInteractionBlocker(
      child: Listener(
        onPointerDown: (event) => _down(event, region),
        onPointerCancel: (_) {
          if (region.owns(_data)) region.cancel();
        },
        child: MouseRegion(
          cursor: SystemMouseCursors.move,
          child: Stack(
            fit: widget.dateOnly ? StackFit.loose : StackFit.expand,
            children: [
              Draggable<ScheduleEventDragData>(
                data: data,
                allowedButtonsFilter: (buttons) =>
                    buttons == kPrimaryMouseButton && region.canMove,
                maxSimultaneousDrags: region.canMove ? 1 : 0,
                dragAnchorStrategy: pointerDragAnchorStrategy,
                feedback: ListenableBuilder(
                  listenable: region.changes,
                  builder: (context, _) {
                    final interval = region.preview;
                    if (interval == null || region.widget.coordinates != null) {
                      return const SizedBox.shrink();
                    }
                    return SizedBox(
                      width: 220,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: region.widget.previewColor.withValues(
                            alpha: .3,
                          ),
                        ),
                        child: region.widget.previewBuilder(
                          context,
                          interval,
                          item.allDay,
                        ),
                      ),
                    );
                  },
                ),
                onDragStarted: () {
                  if (_data != null) {
                    region.begin(_data!, ScheduleTimingAction.move);
                  }
                },
                onDragUpdate: (details) {
                  if (region.owns(data)) region.update(details.globalPosition);
                },
                onDragEnd: (_) {
                  region.dragEnded(data);
                  _data = null;
                },
                childWhenDragging: Opacity(opacity: .4, child: widget.child),
                child: widget.child,
              ),
              if ((!widget.dateOnly || item.allDay) && first)
                Positioned(
                  top: 0,
                  left: item.allDay ? 0 : null,
                  right: item.allDay ? null : 2,
                  bottom: item.allDay ? 0 : null,
                  child: handle(ScheduleTimingAction.resizeStart),
                ),
              if ((!widget.dateOnly || item.allDay) && last)
                Positioned(
                  bottom: 0,
                  right: item.allDay ? 0 : 2,
                  top: item.allDay ? 0 : null,
                  child: handle(ScheduleTimingAction.resizeEnd),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class ScheduleDateTarget extends StatefulWidget {
  const ScheduleDateTarget({
    super.key,
    required this.date,
    required this.child,
  });
  final DateTime date;
  final Widget child;
  @override
  State<ScheduleDateTarget> createState() => _ScheduleDateTargetState();
}

class _ScheduleDateTargetState extends State<ScheduleDateTarget> {
  ScheduleInteractionRegionState? _region;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _region?._dates.remove(this);
    _region = ScheduleInteractionRegion.maybeOf(context);
    _register();
  }

  void _register() {
    _region?._dates[this] = (
      box: () => context.findRenderObject()! as RenderBox,
      day: widget.date,
    );
  }

  @override
  void didUpdateWidget(covariant ScheduleDateTarget oldWidget) {
    super.didUpdateWidget(oldWidget);
    _register();
  }

  @override
  void dispose() {
    _region?._dates.remove(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

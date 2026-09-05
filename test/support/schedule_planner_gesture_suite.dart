import 'dart:ui' show ViewFocusEvent, ViewFocusState, ViewFocusDirection;

import 'package:busymax/src/providers/busy_provider.dart';
import 'package:busymax/src/schedule/schedule_event_rescheduling.dart';
import 'package:busymax/src/schedule/schedule_item.dart';
import 'package:busymax/src/ui/common/schedule/schedule_interactions.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:infinite_calendar_view/infinite_calendar_view.dart' as icv;

class PlannerGestureScenario {
  PlannerGestureScenario({
    this.days = 1,
    this.rtl = false,
    List<ScheduleItem>? items,
  }) : items = items ?? [event()];
  static final day = DateTime(2026, 1, 12);
  final int days;
  final bool rtl;
  List<ScheduleItem> items;
  final edits = <ScheduleRescheduleRequest>[];
  final selections = <ScheduleInterval>[];
  final clicks = <DateTime>[];
  final opened = <ScheduleItem>[];
  final completed = <bool>[];
  Future<void> save(
    ScheduleRescheduleRequest request,
    bool Function() active,
  ) async {
    if (active()) edits.add(request);
  }

  static CalendarScheduleItem event({
    String id = 'drag-event',
    DateTime? start,
    DateTime? end,
    bool allDay = false,
    bool readOnly = false,
  }) => CalendarScheduleItem(
    id: id,
    accountId: 'nextcloud:a',
    sourceId: 'calendar',
    providerCalendarId: 'remote-calendar',
    provider: BusyProvider.nextcloud,
    title: id,
    allDay: allDay,
    start: start ?? DateTime(2026, 1, 12, 9),
    end: end ?? DateTime(2026, 1, 12, 10),
    capabilities: readOnly
        ? ScheduleItemCapabilities.readOnly
        : ScheduleItemCapabilities.editable,
  );
}

typedef PlannerHarnessBuilder =
    Widget Function(PlannerGestureScenario scenario);

void schedulePlannerGestureTests(
  String platform,
  PlannerHarnessBuilder harness,
) {
  Future<void> mount(
    WidgetTester tester,
    PlannerGestureScenario scenario,
  ) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });
    await tester.pumpWidget(harness(scenario));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 1));
  }

  Finder tile([String id = 'drag-event']) => find
      .byWidgetPredicate(
        (widget) => widget is ScheduleEventInteraction && widget.item.id == id,
      )
      .hitTestable();
  ScheduleInteractionRegionState region(WidgetTester tester) =>
      tester.state(find.byType(ScheduleInteractionRegion));
  icv.EventsPlannerState planner(WidgetTester tester) =>
      tester.state(find.byType(icv.EventsPlanner));
  Offset slot(WidgetTester tester, int minute, {int dayIndex = 0}) {
    final p = planner(tester);
    final c = region(tester).widget.coordinates!;
    return c.box!.localToGlobal(
      Offset(
        64 + (dayIndex + .55) * p.dayWidth - p.mainHorizontalController.offset,
        c.gridTop +
            8 +
            minute * p.heightPerMinute -
            p.mainVerticalController.offset,
      ),
    );
  }

  Future<TestGesture> begin(
    WidgetTester tester,
    Offset down,
    Offset target,
  ) async {
    final gesture = await tester.startGesture(
      down,
      kind: PointerDeviceKind.mouse,
    );
    await tester.pump();
    await gesture.moveTo(Offset.lerp(down, target, .55)!);
    await tester.pump();
    await gesture.moveTo(target);
    await tester.pump();
    return gesture;
  }

  Future<void> release(WidgetTester tester, TestGesture gesture) async {
    await gesture.up();
    // The pinned planner's double-tap recognizer holds ordinary child taps.
    await tester.pump(kDoubleTapTimeout + const Duration(milliseconds: 1));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 1));
  }

  testWidgets(
    '$platform mouse event move preserves grab offset and commits once',
    (tester) async {
      final scenario = PlannerGestureScenario();
      await mount(tester, scenario);
      final down = tester.getCenter(tile());
      final p = planner(tester);
      final before = p.mainVerticalController.offset;
      final gesture = await begin(
        tester,
        down,
        down + Offset(0, 60 * p.heightPerMinute),
      );
      expect(scenario.edits, isEmpty);
      expect(region(tester).preview?.start, DateTime(2026, 1, 12, 10));
      expect(
        p.mainVerticalController.offset,
        before,
        reason: 'event move must win against planner scrolling',
      );
      await release(tester, gesture);
      expect(scenario.edits, hasLength(1));
      expect(scenario.edits.single.interval.start, DateTime(2026, 1, 12, 10));
      expect(scenario.edits.single.interval.end, DateTime(2026, 1, 12, 11));
      expect(scenario.opened, isEmpty);
      expect(region(tester).active, isFalse);
      expect(tester.takeException(), isNull);
    },
  );

  for (final startBoundary in [true, false]) {
    testWidgets(
      '$platform mouse resizes ${startBoundary ? 'start' : 'end'} only',
      (tester) async {
        final scenario = PlannerGestureScenario();
        await mount(tester, scenario);
        final handle = find
            .byKey(
              ValueKey(
                'schedule-${startBoundary ? 'resizeStart' : 'resizeEnd'}-drag-event',
              ),
            )
            .hitTestable();
        final down = tester.getCenter(handle);
        final delta =
            (startBoundary ? -30 : 30) * planner(tester).heightPerMinute;
        final gesture = await begin(tester, down, down + Offset(0, delta));
        await release(tester, gesture);
        expect(scenario.edits, hasLength(1));
        expect(
          scenario.edits.single.interval.start,
          DateTime(2026, 1, 12, startBoundary ? 8 : 9, startBoundary ? 30 : 0),
        );
        expect(
          scenario.edits.single.interval.end,
          DateTime(2026, 1, 12, 10, startBoundary ? 0 : 30),
        );
      },
    );
  }
  testWidgets('$platform RTL movement follows rendered planner dates', (
    tester,
  ) async {
    final scenario = PlannerGestureScenario(days: 7, rtl: true);
    await mount(tester, scenario);
    final p = planner(tester);
    final down = tester.getCenter(tile());
    final target = down + Offset(-p.dayWidth, 30 * p.heightPerMinute);
    final expectedDate = region(tester).widget.coordinates!.at(target)!.wall;
    final gesture = await begin(tester, down, target);
    await release(tester, gesture);
    expect(scenario.edits, hasLength(1));
    expect(
      scenario.edits.single.interval.start,
      DateTime(expectedDate.year, expectedDate.month, expectedDate.day, 9, 30),
    );
  });
  testWidgets('$platform all-day panel resizing does not select a range', (
    tester,
  ) async {
    final scenario = PlannerGestureScenario(
      items: [
        PlannerGestureScenario.event(
          allDay: true,
          start: PlannerGestureScenario.day,
          end: DateTime(2026, 1, 13),
        ),
      ],
    );
    await mount(tester, scenario);
    final handle = find.byKey(
      ValueKey(
        platform == 'Linux'
            ? 'schedule-all-day-resize-handle'
            : 'windows-all-day-resize',
      ),
    );
    final down = tester.getCenter(handle);
    final before = region(tester).widget.coordinates!.gridTop;
    final gesture = await begin(tester, down, down + const Offset(0, 60));
    await release(tester, gesture);
    expect(
      region(tester).widget.coordinates!.gridTop,
      greaterThan(before + 20),
    );
    expect(scenario.selections, isEmpty);
    expect(scenario.edits, isEmpty);
  });
  for (final upwards in [false, true]) {
    testWidgets(
      '$platform background selection ${upwards ? 'upwards' : 'downwards'} wins scroll gesture',
      (tester) async {
        final scenario = PlannerGestureScenario(items: []);
        await mount(tester, scenario);
        final p = planner(tester);
        final before = p.mainVerticalController.offset;
        final a = slot(tester, 9 * 60);
        final b = slot(tester, 9 * 60 + 45);
        final gesture = await begin(tester, upwards ? b : a, upwards ? a : b);
        expect(scenario.selections, isEmpty);
        expect(p.mainVerticalController.offset, before);
        await release(tester, gesture);
        expect(scenario.selections, hasLength(1));
        expect(scenario.selections.single.start, DateTime(2026, 1, 12, 9));
        expect(scenario.selections.single.end, DateTime(2026, 1, 12, 9, 45));
        expect(scenario.clicks, isEmpty);
      },
    );
  }
  testWidgets('$platform range beginning at midnight stays exact', (
    tester,
  ) async {
    final scenario = PlannerGestureScenario(items: []);
    await mount(tester, scenario);
    planner(tester).mainVerticalController.jumpTo(0);
    await tester.pump();
    final gesture = await begin(tester, slot(tester, 0), slot(tester, 45));
    await release(tester, gesture);
    expect(scenario.selections.single.start, DateTime(2026, 1, 12));
    expect(scenario.selections.single.end, DateTime(2026, 1, 12, 0, 45));
  });
  for (final cancellation in ['escape', 'outside', 'pointer', 'focus']) {
    testWidgets('$platform $cancellation cancels without edit', (tester) async {
      final scenario = PlannerGestureScenario();
      await mount(tester, scenario);
      final down = tester.getCenter(tile());
      final gesture = await begin(tester, down, down + const Offset(0, 54));
      if (cancellation == 'escape') {
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await gesture.up();
      } else if (cancellation == 'pointer') {
        await gesture.cancel();
      } else if (cancellation == 'focus') {
        tester.binding.handleViewFocusChanged(
          ViewFocusEvent(
            viewId: tester.view.viewId,
            state: ViewFocusState.unfocused,
            direction: ViewFocusDirection.undefined,
          ),
        );
        await gesture.up();
      } else {
        await gesture.moveTo(const Offset(-40, -40));
        await gesture.up();
      }
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 1));
      expect(scenario.edits, isEmpty);
      expect(region(tester).active, isFalse);
    });
  }
  testWidgets('$platform readonly events do not offer editing gestures', (
    tester,
  ) async {
    final scenario = PlannerGestureScenario(
      items: [PlannerGestureScenario.event(readOnly: true)],
    );
    await mount(tester, scenario);
    expect(find.byType(Draggable<ScheduleEventDragData>), findsNothing);
    expect(
      find.byKey(const ValueKey('schedule-resizeStart-drag-event')),
      findsNothing,
    );
    final down = tester.getCenter(tile());
    final gesture = await begin(tester, down, down + const Offset(0, 54));
    await release(tester, gesture);
    expect(scenario.edits, isEmpty);
    expect(scenario.selections, isEmpty);
  });
  testWidgets('$platform ordinary event and background clicks survive', (
    tester,
  ) async {
    final scenario = PlannerGestureScenario();
    await mount(tester, scenario);
    final click = await tester.startGesture(
      tester.getCenter(tile()),
      kind: PointerDeviceKind.mouse,
    );
    await click.up();
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 1));
    final background = await tester.startGesture(
      slot(tester, 11 * 60),
      kind: PointerDeviceKind.mouse,
    );
    await background.up();
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 1));
    expect(scenario.opened, hasLength(1));
    expect(scenario.clicks, hasLength(1));
    expect(scenario.selections, isEmpty);
    expect(scenario.edits, isEmpty);
  });
  testWidgets('$platform secondary click opens the event without editing', (
    tester,
  ) async {
    final scenario = PlannerGestureScenario();
    await mount(tester, scenario);
    final gesture = await tester.startGesture(
      tester.getCenter(tile()),
      kind: PointerDeviceKind.mouse,
      buttons: kSecondaryMouseButton,
    );
    await release(tester, gesture);
    expect(scenario.opened, hasLength(1));
    expect(scenario.edits, isEmpty);
    expect(scenario.selections, isEmpty);
  });
  testWidgets('$platform equal-time strip moves only the grabbed event', (
    tester,
  ) async {
    final scenario = PlannerGestureScenario(
      items: [
        PlannerGestureScenario.event(),
        PlannerGestureScenario.event(id: 'neighbor'),
      ],
    );
    await mount(tester, scenario);
    final down = tester.getCenter(tile());
    final gesture = await begin(tester, down, down + const Offset(0, 54));
    await release(tester, gesture);
    expect(scenario.edits, hasLength(1));
    expect(scenario.edits.single.item.id, 'drag-event');
  });

  testWidgets(
    '$platform short event movement does not lengthen its real interval',
    (tester) async {
      final scenario = PlannerGestureScenario(
        items: [
          PlannerGestureScenario.event(
            start: DateTime(2026, 1, 12, 9, 7),
            end: DateTime(2026, 1, 12, 9, 12),
          ),
        ],
      );
      await mount(tester, scenario);
      final down = tester.getCenter(tile());
      final gesture = await begin(
        tester,
        down,
        down + Offset(0, 60 * planner(tester).heightPerMinute),
      );
      await release(tester, gesture);
      expect(
        scenario.edits.single.interval.duration,
        const Duration(minutes: 5),
      );
      expect(scenario.edits.single.interval.start, DateTime(2026, 1, 12, 10));
    },
  );

  testWidgets(
    '$platform no-op mouse gesture does not round an off-grid event',
    (tester) async {
      final scenario = PlannerGestureScenario(
        items: [
          PlannerGestureScenario.event(
            start: DateTime(2026, 1, 12, 9, 7),
            end: DateTime(2026, 1, 12, 10, 7),
          ),
        ],
      );
      await mount(tester, scenario);
      final down = tester.getCenter(tile());
      final gesture = await begin(tester, down, down + const Offset(0, 40));
      await gesture.moveTo(down);
      await release(tester, gesture);
      expect(scenario.edits, isEmpty);
    },
  );

  testWidgets(
    '$platform wheel zoom and nonzero horizontal scroll use actual planner coordinates',
    (tester) async {
      final scenario = PlannerGestureScenario(
        items: [
          PlannerGestureScenario.event(
            allDay: true,
            start: PlannerGestureScenario.day,
            end: DateTime(2026, 1, 13),
          ),
        ],
      );
      await mount(tester, scenario);
      final p = planner(tester);
      final originalZoom = p.heightPerMinute;
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();
      await tester.sendEventToBinding(
        PointerScrollEvent(
          position: slot(tester, 10 * 60),
          scrollDelta: const Offset(0, -120),
          kind: PointerDeviceKind.mouse,
        ),
      );
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
      expect(p.heightPerMinute, isNot(originalZoom));
      p.mainHorizontalController.jumpTo(-p.dayWidth);
      p.mainVerticalController.jumpTo(500 * p.heightPerMinute);
      await tester.pumpAndSettle();
      final a = slot(tester, 10 * 60, dayIndex: -1);
      final b = slot(tester, 11 * 60, dayIndex: -1);
      final gesture = await begin(tester, a, b);
      await release(tester, gesture);
      expect(scenario.selections.single.start, DateTime(2026, 1, 11, 10));
      expect(scenario.selections.single.end, DateTime(2026, 1, 11, 11));
    },
  );

  testWidgets('$platform active move survives event snapshot reload', (
    tester,
  ) async {
    final scenario = PlannerGestureScenario();
    await mount(tester, scenario);
    final down = tester.getCenter(tile());
    final gesture = await begin(tester, down, down + const Offset(0, 54));
    final interval = region(tester).preview!;
    scenario.items = [
      ...scenario.items,
      PlannerGestureScenario.event(
        id: 'newly-loaded',
        start: DateTime(2026, 1, 12, 15),
        end: DateTime(2026, 1, 12, 16),
      ),
    ];
    await tester.pumpWidget(harness(scenario));
    await tester.pump();
    expect(region(tester).preview!.sameAs(interval), isTrue);
    await release(tester, gesture);
    expect(scenario.edits, hasLength(1));
    expect(scenario.edits.single.interval.sameAs(interval), isTrue);
  });

  testWidgets(
    '$platform task checkbox stays outside range selection and dragging',
    (tester) async {
      final scenario = PlannerGestureScenario(
        items: [
          TaskScheduleItem(
            id: 'task-checkbox',
            accountId: 'account',
            provider: BusyProvider.google,
            sourceId: 'list',
            title: 'Complete me',
            completed: false,
            allDay: false,
            start: DateTime(2026, 1, 12, 9),
            end: DateTime(2026, 1, 12, 10),
          ),
        ],
      );
      await mount(tester, scenario);
      final checkbox = find
          .descendant(
            of: tile('task-checkbox'),
            matching: find.byWidgetPredicate(
              (widget) => {
                'Checkbox',
                'YaruCheckbox',
              }.contains(widget.runtimeType.toString()),
            ),
          )
          .first;
      final gesture = await tester.startGesture(
        tester.getCenter(checkbox),
        kind: PointerDeviceKind.mouse,
      );
      await tester.pump(const Duration(milliseconds: 50));
      await release(tester, gesture);
      expect(
        scenario.completed,
        [true],
        reason:
            'opened=${scenario.opened.length}, slots=${scenario.clicks.length}, box=${tester.getRect(checkbox)}',
      );
      expect(scenario.edits, isEmpty);
      expect(scenario.selections, isEmpty);
    },
  );

  for (final firstBoundary in [true, false]) {
    testWidgets(
      '$platform all-day ${firstBoundary ? 'start' : 'end'} boundary uses dates',
      (tester) async {
        final scenario = PlannerGestureScenario(
          days: 7,
          items: [
            PlannerGestureScenario.event(
              allDay: true,
              start: DateTime(2026, 1, 12),
              end: DateTime(2026, 1, 14),
            ),
          ],
        );
        await mount(tester, scenario);
        final handle = find
            .byKey(
              ValueKey(
                'schedule-${firstBoundary ? 'resizeStart' : 'resizeEnd'}-drag-event',
              ),
            )
            .hitTestable();
        expect(handle, findsOneWidget);
        final down = tester.getCenter(handle);
        final gesture = await begin(
          tester,
          down,
          down + Offset(planner(tester).dayWidth, 0),
        );
        await release(tester, gesture);
        expect(
          scenario.edits.single.interval.start,
          DateTime(2026, 1, firstBoundary ? 13 : 12),
        );
        expect(
          scenario.edits.single.interval.end,
          DateTime(2026, 1, firstBoundary ? 14 : 15),
        );
      },
    );
  }
  testWidgets('$platform all-day move keeps exclusive date interval', (
    tester,
  ) async {
    final scenario = PlannerGestureScenario(
      days: 7,
      items: [
        PlannerGestureScenario.event(
          allDay: true,
          start: DateTime(2026, 1, 12),
          end: DateTime(2026, 1, 14),
        ),
      ],
    );
    await mount(tester, scenario);
    final down = tester.getCenter(tile().first);
    final gesture = await begin(
      tester,
      down,
      down + Offset(planner(tester).dayWidth, 0),
    );
    await release(tester, gesture);
    expect(scenario.edits, hasLength(1));
    expect(scenario.edits.single.interval.start, DateTime(2026, 1, 13));
    expect(scenario.edits.single.interval.end, DateTime(2026, 1, 15));
  });
  testWidgets('$platform second-day segment shifts whole event', (
    tester,
  ) async {
    final scenario = PlannerGestureScenario(
      days: 7,
      items: [
        PlannerGestureScenario.event(
          start: DateTime(2026, 1, 12, 23),
          end: DateTime(2026, 1, 13, 10),
        ),
      ],
    );
    await mount(tester, scenario);
    final segment = find.byWidgetPredicate(
      (widget) =>
          widget is ScheduleEventInteraction &&
          widget.item.id == 'drag-event' &&
          widget.representedDate.day == 13,
    );
    final down = tester.getBottomLeft(segment) + const Offset(50, -20);
    final gesture = await begin(
      tester,
      down,
      down + Offset(planner(tester).dayWidth, 0),
    );
    await release(tester, gesture);
    expect(scenario.edits.single.interval.start, DateTime(2026, 1, 13, 23));
    expect(scenario.edits.single.interval.end, DateTime(2026, 1, 14, 10));
    expect(
      find.descendant(
        of: segment,
        matching: find.byKey(const ValueKey('schedule-resizeStart-drag-event')),
      ),
      findsNothing,
    );
  });
  testWidgets(
    '$platform edge scrolling recomputes stationary selection and stops on release',
    (tester) async {
      final scenario = PlannerGestureScenario(items: []);
      await mount(tester, scenario);
      final box = region(tester).widget.coordinates!.box!;
      final down = slot(tester, 10 * 60);
      final edge = box.localToGlobal(Offset(400, box.size.height - 20));
      final gesture = await begin(tester, down, edge);
      final initial = planner(tester).mainVerticalController.offset;
      final end = region(tester).preview!.end;
      await tester.pump(const Duration(milliseconds: 200));
      expect(
        planner(tester).mainVerticalController.offset,
        greaterThan(initial),
      );
      expect(region(tester).preview!.end.isAfter(end), isTrue);
      await release(tester, gesture);
      final stopped = planner(tester).mainVerticalController.offset;
      await tester.pump(const Duration(milliseconds: 200));
      expect(planner(tester).mainVerticalController.offset, stopped);
      expect(scenario.selections, hasLength(1));
    },
  );
}

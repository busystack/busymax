import 'package:flutter/semantics.dart';
import 'package:busymax/src/schedule/schedule_item.dart';
import 'package:busymax/src/providers/busy_provider.dart';
import 'package:busymax/src/schedule/schedule_range.dart';
import 'package:busymax/src/schedule/schedule_event_rescheduling.dart';
import 'package:busymax/src/ui/common/schedule/schedule_day_week_view.dart';
import 'package:busymax/src/ui/common/schedule/schedule_month_view.dart';
import 'package:busymax/src/ui/common/schedule/clock_hours_painter.dart';
import 'package:busymax/src/ui/common/schedule/schedule_interactions.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:infinite_calendar_view/infinite_calendar_view.dart' as icv;

import '../../support/schedule_planner_gesture_suite.dart';
import '../../test_localized_app.dart';

void main() {
  for (final action in ScheduleTimingAction.values) {
    testWidgets('narrow Month all-day ${action.name} retains its gesture', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(360, 800);
      addTearDown(tester.view.reset);
      final day = PlannerGestureScenario.day;
      final scenario = PlannerGestureScenario(
        items: [
          PlannerGestureScenario.event(
            allDay: true,
            start: day,
            end: day.add(const Duration(days: 1)),
          ),
        ],
      );
      await tester.pumpWidget(
        localizedTestApp(
          child: Scaffold(
            body: ScheduleMonthView(
              range: ScheduleRange.month(day, firstWeekday: DateTime.monday),
              selectedDate: day,
              items: scenario.items,
              firstWeekday: DateTime.monday,
              onDaySelected: (_) {},
              onCreateAtDay: (date, {anchorContext}) {},
              onReschedule: scenario.save,
              onItemSelected: (_, item, [position]) =>
                  scenario.opened.add(item),
              onTaskCompletionChanged: (_, value) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final event = find.byType(ScheduleEventInteraction);
      final source = action == ScheduleTimingAction.move
          ? event
          : find.byKey(ValueKey('schedule-${action.name}-drag-event'));
      final targetDay = day.add(
        Duration(days: action == ScheduleTimingAction.resizeStart ? -1 : 1),
      );
      final target = find.byWidgetPredicate(
        (w) => w is ScheduleDateTarget && w.date == targetDay,
      );
      final gesture = await tester.startGesture(tester.getCenter(source));
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
      await gesture.moveTo(tester.getCenter(target));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();
      expect(scenario.edits, hasLength(1));
      final edit = scenario.edits.single;
      expect(edit.action, action);
      expect(
        edit.interval.start,
        action == ScheduleTimingAction.resizeEnd ? day : targetDay,
      );
      expect(
        edit.interval.end,
        day.add(
          Duration(days: action == ScheduleTimingAction.resizeStart ? 1 : 2),
        ),
      );
      expect(scenario.opened, isEmpty);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });
  }

  testWidgets('changing text direction preserves the selected planner date', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);
    var direction = TextDirection.ltr;
    var selected = PlannerGestureScenario.day;
    final notifications = <DateTime>[];
    late StateSetter update;
    final scenario = PlannerGestureScenario();
    await tester.pumpWidget(
      localizedTestApp(
        child: StatefulBuilder(
          builder: (context, setState) {
            update = setState;
            return Directionality(
              textDirection: direction,
              child: Scaffold(
                body: ScheduleDayWeekView(
                  range: ScheduleRange.week(
                    selected,
                    firstWeekday: DateTime.monday,
                  ),
                  selectedDate: selected,
                  daysShowed: 7,
                  items: scenario.items,
                  onDaySelected: (day) {
                    notifications.add(day);
                    setState(() => selected = day);
                  },
                  onEmptySlot: (_) {},
                  onItemSelected: (_, item, [position]) {},
                  onTaskCompletionChanged: (_, value) {},
                ),
              ),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 1));
    expect(selected, PlannerGestureScenario.day);
    for (final next in [TextDirection.rtl, TextDirection.ltr]) {
      update(() => direction = next);
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 1));
      expect(selected, PlannerGestureScenario.day);
      final planner = tester.state<icv.EventsPlannerState>(
        find.byType(icv.EventsPlanner),
      );
      final visibleDates = List.generate(
        7,
        (index) => planner.getDayFromIndex(index),
      )..sort();
      expect(visibleDates.first, PlannerGestureScenario.day);
      expect(
        visibleDates.last,
        PlannerGestureScenario.day.add(const Duration(days: 6)),
      );
      expect(
        notifications.every((day) => day == PlannerGestureScenario.day),
        isTrue,
      );
    }
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets(
    'an inactive retained planner cannot replace workspace selection',
    (tester) async {
      final notifications = <DateTime>[];
      final scenario = PlannerGestureScenario();
      var active = true;
      late StateSetter update;
      await tester.pumpWidget(
        localizedTestApp(
          child: StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return TickerMode(
                enabled: active,
                child: Offstage(
                  offstage: !active,
                  child: Scaffold(
                    body: ScheduleDayWeekView(
                      range: ScheduleRange.week(
                        PlannerGestureScenario.day,
                        firstWeekday: DateTime.monday,
                      ),
                      selectedDate: PlannerGestureScenario.day,
                      daysShowed: 7,
                      items: scenario.items,
                      onDaySelected: notifications.add,
                      onEmptySlot: (_) {},
                      onItemSelected: (_, item, [position]) {},
                      onTaskCompletionChanged: (_, value) {},
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 1));
      final before = notifications.length;
      update(() => active = false);
      await tester.pumpAndSettle();
      final planner = tester.state<icv.EventsPlannerState>(
        find.byType(icv.EventsPlanner, skipOffstage: false),
      );
      planner.mainHorizontalController.jumpTo(
        planner.dayWidthCalculator.offsetForIndex(2),
      );
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 1));
      expect(notifications, hasLength(before));
      update(() => active = true);
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 1));
      expect(planner.mainHorizontalController.offset, closeTo(0, .01));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 1));
    },
  );

  testWidgets('planner reflow preserves time and fractional day scrolling', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 800);
    addTearDown(tester.view.reset);
    final scenario = PlannerGestureScenario();
    await tester.pumpWidget(
      localizedTestApp(
        child: Scaffold(
          body: ScheduleDayWeekView(
            range: ScheduleRange.week(
              PlannerGestureScenario.day,
              firstWeekday: DateTime.monday,
            ),
            selectedDate: PlannerGestureScenario.day,
            daysShowed: 7,
            items: scenario.items,
            onDaySelected: (_) {},
            onEmptySlot: scenario.clicks.add,
            onRangeCreated: scenario.selections.add,
            onReschedule: scenario.save,
            onItemSelected: (_, item, [position]) => scenario.opened.add(item),
            onTaskCompletionChanged: (_, value) =>
                scenario.completed.add(value),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 1));
    final before = tester.state<icv.EventsPlannerState>(
      find.byType(icv.EventsPlanner),
    );
    before.mainVerticalController.jumpTo(440);
    before.mainHorizontalController.jumpTo(
      before.dayWidthCalculator.widthForIndex(0) * .35,
    );
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 1));
    tester.view.physicalSize = const Size(320, 500);
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 1));
    final after = tester.state<icv.EventsPlannerState>(
      find.byType(icv.EventsPlanner),
    );
    expect(after.mainVerticalController.offset, closeTo(440, .1));
    expect(
      after.mainHorizontalController.offset /
          after.dayWidthCalculator.widthForIndex(0),
      closeTo(.35, .01),
    );
    expect(scenario.edits, isEmpty);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 1));
  });
  ScheduleInteractionRegionState region(WidgetTester tester) =>
      tester.state(find.byType(ScheduleInteractionRegion));

  Future<PlannerGestureScenario> mount(
    WidgetTester tester, {
    List<ScheduleItem>? items,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 800);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final scenario = PlannerGestureScenario(items: items);
    await tester.pumpWidget(
      localizedTestApp(
        child: Scaffold(
          body: ScheduleDayWeekView(
            range: ScheduleRange.day(PlannerGestureScenario.day),
            selectedDate: PlannerGestureScenario.day,
            daysShowed: 1,
            items: scenario.items,
            onDaySelected: (_) {},
            onEmptySlot: scenario.clicks.add,
            onRangeCreated: scenario.selections.add,
            onReschedule: scenario.save,
            onItemSelected: (_, item, [position]) => scenario.opened.add(item),
            onTaskCompletionChanged: (_, completed) =>
                scenario.completed.add(completed),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump(const Duration(milliseconds: 1));
    expect(region(tester).widget.touch, isTrue);
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });
    return scenario;
  }

  icv.EventsPlannerState planner(WidgetTester tester) =>
      tester.state(find.byType(icv.EventsPlanner));

  testWidgets('scaled clock labels reserve their actual painted height', (
    tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await mount(tester);
    final painter =
        planner(tester)
                .widget
                .timesIndicatorsParam
                .timesIndicatorsCustomPainter!(.9)
            as BusyMaxClockHoursPainter;
    const time = TimeOfDay(hour: 3, minute: 50);
    final label = painter.textPainterBuilder!(time, painter.hourColor)
      ..layout();
    final currentY = (time.hour * 60 + time.minute) * painter.heightPerMinute;
    expect(label.height, greaterThan(10));
    expect(
      painter.isHideByCurrentTime(time, currentY + label.height - 1),
      isTrue,
      reason: 'A nearby hour must not paint over the current-time label.',
    );
    expect(
      painter.isHideByCurrentTime(time, currentY + label.height + 5),
      isFalse,
    );
    label.dispose();
  });
  Offset slot(WidgetTester tester, int minute) {
    final p = planner(tester), c = region(tester).widget.coordinates!;
    return c.box!.localToGlobal(
      Offset(
        c.gutterWidth + p.dayWidth * .55,
        c.gridTop +
            c.dayTopPadding +
            minute * p.heightPerMinute -
            p.mainVerticalController.offset,
      ),
    );
  }

  Future<TestGesture> hold(WidgetTester tester, Offset point) async {
    final gesture = await tester.startGesture(
      point,
      kind: PointerDeviceKind.touch,
    );
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
    return gesture;
  }

  testWidgets(
    'assistive preview, completion and dated slot actions stay distinct',
    (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        final task = TaskScheduleItem(
          id: 'accessible-task',
          accountId: 'nextcloud:a',
          sourceId: 'tasks',
          provider: BusyProvider.nextcloud,
          title: 'Accessible task',
          completed: false,
          allDay: false,
          start: DateTime(2026, 1, 12, 10),
          end: DateTime(2026, 1, 12, 11),
        );
        final scenario = await mount(
          tester,
          items: [PlannerGestureScenario.event(), task],
        );
        void activate(Finder target) {
          final node = tester.getSemantics(target);
          node.owner!.performAction(node.id, SemanticsAction.tap);
        }

        activate(find.bySemanticsLabel(RegExp(r'^Accessible task ·')));
        await tester.pump();
        expect(scenario.opened, [task]);
        expect(scenario.completed, isEmpty);
        activate(find.bySemanticsLabel('Completed: Accessible task'));
        await tester.pump();
        expect(scenario.completed, [true]);
        expect(scenario.opened, [task]);
        activate(
          find.bySemanticsLabel(
            RegExp(r'^Create · Monday, January 12, 2026 · 11:00'),
          ),
        );
        await tester.pump();
        expect(scenario.clicks.single, DateTime(2026, 1, 12, 11));
        expect(scenario.edits, isEmpty);
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      } finally {
        semantics.dispose();
      }
    },
  );

  testWidgets('event tap opens preview without selecting or mutating', (
    tester,
  ) async {
    final scenario = await mount(tester);
    await tester.tap(
      find
          .byWidgetPredicate(
            (w) => w is ScheduleEventInteraction && w.item.id == 'drag-event',
          )
          .hitTestable(),
    );
    await tester.pump(kDoubleTapTimeout + const Duration(milliseconds: 20));
    await tester.pumpAndSettle();
    expect(scenario.opened.map((item) => item.id), ['drag-event']);
    expect(scenario.edits, isEmpty);
    expect(scenario.selections, isEmpty);
  });

  testWidgets('touch scroll does not select or reschedule', (tester) async {
    final scenario = await mount(tester);
    final before = planner(tester).mainVerticalController.offset;
    final gesture = await tester.startGesture(slot(tester, 11 * 60));
    await gesture.moveBy(const Offset(0, -45));
    await tester.pump();
    await gesture.moveBy(const Offset(0, -45));
    await gesture.up();
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 1));
    expect(planner(tester).mainVerticalController.offset, greaterThan(before));
    expect(scenario.edits, isEmpty);
    expect(scenario.selections, isEmpty);
  });
  testWidgets('held background range has preview then one interval', (
    tester,
  ) async {
    final scenario = await mount(tester);
    final gesture = await hold(tester, slot(tester, 11 * 60));
    await gesture.moveTo(slot(tester, 12 * 60));
    await tester.pump();
    expect(region(tester).preview, isNotNull);
    await gesture.up();
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 1));
    expect(scenario.selections, hasLength(1));
    expect(scenario.selections.single.start.hour, 11);
    expect(scenario.selections.single.end.hour, 12);
    expect(scenario.clicks, isEmpty);
  });
  testWidgets('held event moves through shared policy once', (tester) async {
    final scenario = await mount(tester);
    final tile = find
        .byWidgetPredicate(
          (widget) =>
              widget is ScheduleEventInteraction &&
              widget.item.id == 'drag-event',
        )
        .hitTestable();
    final down = tester.getCenter(tile);
    final gesture = await hold(tester, down);
    await gesture.moveTo(
      down + Offset(0, 60 * planner(tester).heightPerMinute),
    );
    await tester.pump();
    expect(region(tester).preview, isNotNull);
    await gesture.up();
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 1));
    expect(scenario.edits, hasLength(1));
    expect(scenario.edits.single.interval.start.hour, 10);
    expect(scenario.opened, isEmpty);
  });
  testWidgets('held end handle resizes without moving the start', (
    tester,
  ) async {
    final scenario = await mount(tester);
    final down = tester.getCenter(
      find.byKey(const ValueKey('schedule-resizeEnd-drag-event')),
    );
    final gesture = await hold(tester, down);
    await gesture.moveBy(Offset(0, 30 * planner(tester).heightPerMinute));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 1));
    expect(scenario.edits, hasLength(1));
    expect(scenario.edits.single.interval.start, scenario.items.single.start);
    expect(scenario.edits.single.interval.end.minute, 30);
  });
  testWidgets('pointer cancellation discards a held event preview', (
    tester,
  ) async {
    final scenario = await mount(tester);
    final down = slot(tester, 9 * 60 + 30);
    final gesture = await hold(tester, down);
    await gesture.moveBy(const Offset(0, 45));
    await tester.pump();
    await gesture.cancel();
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 1));
    expect(scenario.edits, isEmpty);
    expect(region(tester).active, isFalse);
  });
  testWidgets('two fingers zoom the planner without a visible zoom control', (
    tester,
  ) async {
    final scenario = await mount(tester);
    final before = planner(tester).heightPerMinute;
    final a = await tester.startGesture(slot(tester, 11 * 60), pointer: 1);
    final b = await tester.startGesture(slot(tester, 12 * 60), pointer: 2);
    await tester.pump();
    await a.moveBy(const Offset(0, -30));
    await b.moveBy(const Offset(0, 30));
    await tester.pump();
    await a.moveBy(const Offset(0, -10));
    await b.moveBy(const Offset(0, 10));
    await tester.pump();
    await a.up();
    await b.up();
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 1));
    expect(planner(tester).heightPerMinute, greaterThan(before));
    expect(find.byType(Slider), findsNothing);
    expect(scenario.edits, isEmpty);
    expect(scenario.selections, isEmpty);
    expect(tester.takeException(), isNull);
  });
}

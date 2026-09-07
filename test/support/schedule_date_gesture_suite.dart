import 'package:busymax/src/ui/common/schedule/schedule_interactions.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';

import 'schedule_planner_gesture_suite.dart';

void scheduleDateGestureTests(String platform, PlannerHarnessBuilder harness) {
  for (final cancellation in ['escape', 'outside', 'no-op', 'snapshot']) {
    testWidgets('$platform month $cancellation then successful drag', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1400, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final scenario = PlannerGestureScenario();
      await tester.pumpWidget(harness(scenario));
      await tester.pumpAndSettle();
      final tile = find.byWidgetPredicate(
        (widget) =>
            widget is ScheduleEventInteraction &&
            widget.item.id == 'drag-event' &&
            widget.representedDate.day == 12,
      );
      final target = find.byWidgetPredicate(
        (widget) =>
            widget is ScheduleDateTarget &&
            widget.date.day == 13 &&
            widget.date.month == 1,
      );
      ScheduleInteractionRegionState region() =>
          tester.state(find.byType(ScheduleInteractionRegion));
      Future<TestGesture> begin() async {
        final down = tester.getCenter(tile);
        final destination = tester.getCenter(target);
        final gesture = await tester.startGesture(
          down,
          kind: PointerDeviceKind.mouse,
        );
        await tester.pump();
        await gesture.moveTo(Offset.lerp(down, destination, .5)!);
        await tester.pump();
        await gesture.moveTo(destination);
        await tester.pump();
        return gesture;
      }

      final gesture = await begin();
      expect(region().active, isTrue);
      if (cancellation == 'snapshot') {
        scenario.items = [PlannerGestureScenario.event()];
        await tester.pumpWidget(harness(scenario));
        await tester.pump();
      }
      if (cancellation == 'no-op') {
        await gesture.moveTo(tester.getCenter(tile));
      } else if (cancellation == 'outside') {
        await gesture.moveTo(const Offset(-40, -40));
      } else {
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      }
      await gesture.up();
      await tester.pumpAndSettle();
      expect(scenario.edits, isEmpty);
      expect(region().active, isFalse);
      final next = await begin();
      await next.up();
      await tester.pumpAndSettle();
      expect(scenario.edits, hasLength(1));
      expect(scenario.edits.single.interval.start, DateTime(2026, 1, 13, 9));
      expect(scenario.edits.single.interval.end, DateTime(2026, 1, 13, 10));
      expect(region().active, isFalse);
      expect(tester.takeException(), isNull);
    });
  }
  for (final allDay in [false, true]) {
    testWidgets(
      '$platform month date move preserves ${allDay ? 'exclusive days' : 'displayed time and duration'}',
      (tester) async {
        tester.view.physicalSize = const Size(1400, 1100);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final start = DateTime(2026, 1, 12, allDay ? 0 : 14, allDay ? 0 : 37);
        final end = allDay
            ? DateTime(2026, 1, 14)
            : start.add(const Duration(minutes: 43));
        final scenario = PlannerGestureScenario(
          items: [
            PlannerGestureScenario.event(
              start: start,
              end: end,
              allDay: allDay,
            ),
          ],
        );
        await tester.pumpWidget(harness(scenario));
        await tester.pumpAndSettle();
        final tile = find.byWidgetPredicate(
          (widget) =>
              widget is ScheduleEventInteraction &&
              widget.item.id == 'drag-event' &&
              widget.representedDate.day == 12,
        );
        final target = find.byWidgetPredicate(
          (widget) =>
              widget is ScheduleDateTarget &&
              widget.date.day == 13 &&
              widget.date.month == 1,
        );
        final down = tester.getCenter(tile);
        final destination = tester.getCenter(target);
        final gesture = await tester.startGesture(
          down,
          kind: PointerDeviceKind.mouse,
        );
        await tester.pump();
        await gesture.moveTo(Offset.lerp(down, destination, .5)!);
        await tester.pump();
        await gesture.moveTo(destination);
        await tester.pump();
        expect(scenario.edits, isEmpty);
        await gesture.up();
        await tester.pumpAndSettle();
        expect(scenario.edits, hasLength(1));
        final interval = scenario.edits.single.interval;
        expect(interval.start, DateTime(2026, 1, 13, start.hour, start.minute));
        expect(
          interval.end,
          allDay
              ? DateTime(2026, 1, 15)
              : interval.start.add(const Duration(minutes: 43)),
        );
        expect(
          scenario.edits.single.item.accountId,
          scenario.items.single.accountId,
        );
        expect(
          scenario.edits.single.item.sourceId,
          scenario.items.single.sourceId,
        );
        expect(scenario.opened, isEmpty);
        expect(tester.takeException(), isNull);
      },
    );
  }
}

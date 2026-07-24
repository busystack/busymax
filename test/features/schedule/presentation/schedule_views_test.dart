import 'dart:io';
import 'dart:ui' as ui;

import 'package:busymax/src/app/busymax_design.dart';
import 'package:busymax/src/app/busymax_yaru_theme.dart';
import 'package:busymax/src/features/schedule/presentation/schedule_agenda_view.dart';
import 'package:busymax/src/features/schedule/presentation/schedule_anchored_popover.dart';
import 'package:busymax/src/features/schedule/presentation/schedule_day_week_view.dart';
import 'package:busymax/src/features/schedule/presentation/schedule_event_block.dart';
import 'package:busymax/src/features/schedule/presentation/schedule_item_chip.dart';
import 'package:busymax/src/features/schedule/presentation/schedule_item_details_popover.dart';
import 'package:busymax/src/features/schedule/presentation/schedule_item_exporter.dart';
import 'package:busymax/src/features/schedule/presentation/mini_calendar.dart';
import 'package:busymax/src/features/schedule/presentation/schedule_month_view.dart';
import 'package:busymax/src/features/schedule/presentation/schedule_year_view.dart';
import 'package:busymax/src/schedule/schedule_item.dart';
import 'package:busymax/src/schedule/schedule_range.dart';
import 'package:busymax/src/task_providers/task_provider.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:infinite_calendar_view/infinite_calendar_view.dart' as icv;
import 'package:yaru/yaru.dart';

import '../../../test_localized_app.dart';

void main() {
  testWidgets('day view uses package planner with custom BusyMax items', (
    tester,
  ) async {
    final selectedDate = DateTime(2026, 1, 15);

    await tester.pumpWidget(
      localizedTestApp(
        child: Scaffold(
          body: SizedBox(
            width: 1000,
            height: 720,
            child: ScheduleDayWeekView(
              range: ScheduleRange.day(selectedDate),
              selectedDate: selectedDate,
              daysShowed: 1,
              items: _itemsFor(selectedDate),
              onDaySelected: (_) {},
              onEmptySlot: (_) {},
              onItemSelected: (_, _, [_]) {},
              onTaskCompletionChanged: (_, _) {},
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(icv.EventsPlanner), findsOneWidget);
    expect(find.text('Design review', skipOffstage: false), findsOneWidget);
    expect(find.text('Submit report', skipOffstage: false), findsOneWidget);
    expect(find.byType(icv.EventsMonths), findsNothing);
    expect(find.byType(icv.EventsList), findsNothing);
  });

  testWidgets('day view applies configured display hours to planner scroll', (
    tester,
  ) async {
    final selectedDate = DateTime(2026, 1, 15);

    await tester.pumpWidget(
      localizedTestApp(
        child: Scaffold(
          body: SizedBox(
            width: 1000,
            height: 720,
            child: ScheduleDayWeekView(
              range: ScheduleRange.day(selectedDate),
              selectedDate: selectedDate,
              daysShowed: 1,
              dayStartMinute: 8 * 60,
              dayEndMinute: 18 * 60,
              items: _itemsFor(selectedDate),
              onDaySelected: (_) {},
              onEmptySlot: (_) {},
              onItemSelected: (_, _, [_]) {},
              onTaskCompletionChanged: (_, _) {},
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    final planner = tester.widget<icv.EventsPlanner>(
      find.byType(icv.EventsPlanner),
    );
    expect(planner.initialVerticalScrollOffset, 0.9 * 8 * 60);
    expect(planner.minVerticalScrollOffset, isNull);
    expect(planner.maxVerticalScrollOffset, isNull);
    expect(planner.offTimesParam.offTimesAllDaysRanges, hasLength(2));
    expect(planner.offTimesParam.offTimesAllDaysRanges.first.start.hour, 0);
    expect(planner.offTimesParam.offTimesAllDaysRanges.first.end.hour, 8);
    expect(planner.offTimesParam.offTimesAllDaysRanges.last.start.hour, 18);
    expect(planner.offTimesParam.offTimesAllDaysRanges.last.end.hour, 24);
    final painter =
        planner.offTimesParam.offTimesAllDaysPainter!(
              0,
              selectedDate,
              true,
              0.9,
              planner.offTimesParam.offTimesAllDaysRanges,
              Theme.of(
                tester.element(find.byType(ScheduleDayWeekView)),
              ).colorScheme.surface,
            )
            as icv.OffSetAllDaysPainter;
    expect(painter.paintToday, isTrue);
  });

  testWidgets('short overlapping event block does not overflow', (
    tester,
  ) async {
    final selectedDate = DateTime(2026, 1, 15);
    final item = _itemsFor(
      selectedDate,
    ).whereType<CalendarScheduleItem>().first;

    await tester.pumpWidget(
      localizedTestApp(
        child: Scaffold(
          body: Center(
            child: ScheduleEventBlock(item: item, width: 120, height: 22),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Design review'), findsOneWidget);
  });

  testWidgets('event block is semantically labeled and keyboard-activatable', (
    tester,
  ) async {
    final selectedDate = DateTime(2026, 1, 15);
    final item = _itemsFor(
      selectedDate,
    ).whereType<CalendarScheduleItem>().first;
    var activationCount = 0;
    Offset? activationPosition = Offset.zero;

    await tester.pumpWidget(
      localizedTestApp(
        alwaysUse24HourFormat: true,
        child: Scaffold(
          body: Center(
            child: ScheduleEventBlock(
              item: item,
              width: 180,
              height: 54,
              onTap: (_, [globalPosition]) {
                activationCount += 1;
                activationPosition = globalPosition;
              },
            ),
          ),
        ),
      ),
    );

    final eventSemantics = find.descendant(
      of: find.byType(ScheduleEventBlock),
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.label?.startsWith('Design review') == true,
      ),
    );
    expect(eventSemantics, findsOneWidget);
    final semantics = tester.widget<Semantics>(eventSemantics);
    expect(semantics.properties.button, isTrue);
    expect(semantics.properties.enabled, isTrue);
    expect(semantics.properties.label, contains('09:00-10:00'));
    expect(semantics.properties.label, contains('Work'));
    expect(semantics.properties.onTap, isNotNull);

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();

    final focusedSurface = find.descendant(
      of: find.byType(ScheduleEventBlock),
      matching: find.byWidgetPredicate((widget) {
        if (widget is! Container || widget.decoration is! BoxDecoration) {
          return false;
        }
        final border = (widget.decoration! as BoxDecoration).border;
        return border is Border && border.top.width == 2;
      }),
    );
    expect(focusedSurface, findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);

    expect(activationCount, 2);
    expect(activationPosition, isNull);
  });

  testWidgets('same-slot day items render in a horizontal strip', (
    tester,
  ) async {
    final selectedDate = DateTime(2026, 1, 15);

    await tester.pumpWidget(
      localizedTestApp(
        child: Scaffold(
          body: SizedBox(
            width: 320,
            height: 520,
            child: ScheduleDayWeekView(
              range: ScheduleRange.day(selectedDate),
              selectedDate: selectedDate,
              daysShowed: 1,
              items: _sameSlotItemsFor(selectedDate),
              onDaySelected: (_) {},
              onEmptySlot: (_) {},
              onItemSelected: (_, _, [_]) {},
              onTaskCompletionChanged: (_, _) {},
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(tester.takeException(), isNull);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is SingleChildScrollView &&
            widget.scrollDirection == Axis.horizontal,
      ),
      findsOneWidget,
    );
    expect(find.text('Design review', skipOffstage: false), findsOneWidget);
    expect(find.text('Pairing session', skipOffstage: false), findsOneWidget);
    expect(find.text('Submit report', skipOffstage: false), findsOneWidget);
  });

  testWidgets('all-day panel scrolls vertically and resizes from handle', (
    tester,
  ) async {
    final selectedDate = DateTime(2026, 1, 15);

    await tester.pumpWidget(
      localizedTestApp(
        child: Scaffold(
          body: SizedBox(
            width: 420,
            height: 520,
            child: ScheduleDayWeekView(
              range: ScheduleRange.day(selectedDate),
              selectedDate: selectedDate,
              daysShowed: 1,
              items: _manyAllDayItemsFor(selectedDate),
              onDaySelected: (_) {},
              onEmptySlot: (_) {},
              onItemSelected: (_, _, [_]) {},
              onTaskCompletionChanged: (_, _) {},
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    final allDayScroll = find.byKey(const ValueKey('schedule-all-day-scroll'));
    expect(tester.takeException(), isNull);
    expect(allDayScroll, findsOneWidget);
    expect(
      tester.widget<SingleChildScrollView>(allDayScroll).scrollDirection,
      Axis.vertical,
    );
    expect(find.text('All-day task 8', skipOffstage: false), findsOneWidget);

    final handle = find.byKey(const ValueKey('schedule-all-day-resize-handle'));
    expect(handle, findsOneWidget);
    final before = tester.getTopLeft(handle).dy;
    await tester.drag(handle, const Offset(0, 64));
    await tester.pumpAndSettle();
    final after = tester.getTopLeft(handle).dy;

    expect(after, greaterThan(before + 30));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'event and task chips tolerate negative and tiny planner widths',
    (tester) async {
      final selectedDate = DateTime(2026, 1, 15);
      final items = _itemsFor(selectedDate);
      final event = items.whereType<CalendarScheduleItem>().first;
      final task = items.whereType<TaskScheduleItem>().first;

      await tester.pumpWidget(
        localizedTestApp(
          child: Scaffold(
            body: Column(
              children: [
                ScheduleEventBlock(item: event, width: -331.6, height: 54),
                ScheduleItemChip(item: task, width: -331.6, height: 54),
                ScheduleItemChip(item: task, width: 33.5, height: 27),
              ],
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
    },
  );

  test('all-day bar uses rendered range and collapses without items', () {
    final source = File(
      'lib/src/features/schedule/presentation/schedule_day_week_view.dart',
    ).readAsStringSync();

    expect(
      source,
      contains(
        'final fullDayBarHeight = showFullDayBar ? _fullDayBarHeight : 0.0;',
      ),
    );
    expect(source, contains('fullDayEventsBarVisibility: showFullDayBar'));
    expect(source, contains('fullDayEventsBarHeight: fullDayBarHeight'));
    expect(source, contains('fullDayEventHeight: showFullDayBar ? 24 : 0'));
    expect(source, contains('fullDayEventsBuilder: (events, width)'));
    expect(source, contains("ValueKey('schedule-all-day-scroll')"));
    expect(source, contains("ValueKey('schedule-all-day-resize-handle')"));
    expect(source, contains('final displayEnd = _endOfDay('));
    expect(source, contains('endTime: displayEnd'));
    expect(source, contains('final visibleStart = _plannerStartDate(widget);'));
    expect(source, contains('final visibleRange = ScheduleRange('));
    expect(
      source,
      contains('end: visibleStart.add(Duration(days: widget.daysShowed))'),
    );
  });

  testWidgets('month view is a custom BusyMax grid with merged chips', (
    tester,
  ) async {
    final selectedDate = DateTime(2026, 1, 15);

    await tester.pumpWidget(
      localizedTestApp(
        child: Scaffold(
          body: SizedBox(
            width: 1000,
            height: 720,
            child: ScheduleMonthView(
              range: ScheduleRange.month(selectedDate),
              selectedDate: selectedDate,
              firstWeekday: DateTime.monday,
              items: _itemsFor(selectedDate),
              onDaySelected: (_) {},
              onCreateAtDay: (_) {},
              onItemSelected: (_, _, [_]) {},
              onTaskCompletionChanged: (_, _) {},
            ),
          ),
        ),
      ),
    );

    expect(find.byType(icv.EventsMonths), findsNothing);
    expect(find.text('Design review'), findsOneWidget);
    expect(find.text('Submit report'), findsOneWidget);
  });

  testWidgets('month and year days share accessible date semantics', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final selectedDate = DateTime(2026, 1, 15);
    DateTime? activatedDay;

    await tester.pumpWidget(
      localizedTestApp(
        child: Scaffold(
          body: SizedBox(
            width: 1000,
            height: 720,
            child: ScheduleMonthView(
              range: ScheduleRange.month(selectedDate),
              selectedDate: selectedDate,
              firstWeekday: DateTime.monday,
              items: const [],
              onDaySelected: (day) => activatedDay = day,
              onCreateAtDay: (_) {},
              onItemSelected: (_, _, [_]) {},
              onTaskCompletionChanged: (_, _) {},
            ),
          ),
        ),
      ),
    );

    var selectedDay = find.text('15');
    var selectedNode = tester.getSemantics(selectedDay);
    expect(selectedNode.flagsCollection.isSelected, ui.Tristate.isTrue);
    expect(selectedNode.label, contains('January 15, 2026'));
    var selectedMarker = tester.widget<Container>(
      find.byKey(
        ValueKey('month-day-marker-${selectedDate.toIso8601String()}'),
      ),
    );
    expect(
      (selectedMarker.decoration! as BoxDecoration).color,
      Theme.of(tester.element(selectedDay)).colorScheme.primary,
    );
    tester.semantics.tap(
      find.semantics.byPredicate((node) => node.id == selectedNode.id),
    );
    await tester.pump();
    expect(activatedDay, selectedDate);

    activatedDay = null;
    await tester.pumpWidget(
      localizedTestApp(
        child: Scaffold(
          body: SizedBox(
            width: 1000,
            height: 720,
            child: ScheduleYearView(
              selectedDate: selectedDate,
              firstWeekday: DateTime.monday,
              items: const [],
              onDaySelected: (day) => activatedDay = day,
              onMonthSelected: (_) {},
              onCreateAtDay: (_) {},
            ),
          ),
        ),
      ),
    );

    selectedDay = find.text('15').first;
    selectedNode = tester.getSemantics(selectedDay);
    expect(selectedNode.flagsCollection.isSelected, ui.Tristate.isTrue);
    expect(selectedNode.label, contains('January 15, 2026'));
    selectedMarker = tester.widget<Container>(
      find.byKey(ValueKey('year-day-marker-${selectedDate.toIso8601String()}')),
    );
    expect(
      (selectedMarker.decoration! as BoxDecoration).color,
      Theme.of(tester.element(selectedDay)).colorScheme.primary,
    );
    tester.semantics.tap(
      find.semantics.byPredicate((node) => node.id == selectedNode.id),
    );
    await tester.pump();
    expect(activatedDay, selectedDate);
    semantics.dispose();
  });

  testWidgets('month view avoids overflow in very short cells', (tester) async {
    final selectedDate = DateTime(2026, 1, 15);

    await tester.pumpWidget(
      localizedTestApp(
        child: Scaffold(
          body: SizedBox(
            width: 700,
            height: 120,
            child: ScheduleMonthView(
              range: ScheduleRange.month(selectedDate),
              selectedDate: selectedDate,
              firstWeekday: DateTime.monday,
              items: _sameSlotItemsFor(selectedDate),
              onDaySelected: (_) {},
              onCreateAtDay: (_) {},
              onItemSelected: (_, _, [_]) {},
              onTaskCompletionChanged: (_, _) {},
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('month More waits for dismissal and returns a stable anchor', (
    tester,
  ) async {
    final selectedDate = DateTime(2026, 1, 15);
    BuildContext? selectedAnchor;
    ScheduleItem? selectedItem;

    await tester.pumpWidget(
      localizedTestApp(
        child: Scaffold(
          body: SizedBox(
            width: 700,
            height: 720,
            child: ScheduleMonthView(
              range: ScheduleRange.month(selectedDate),
              selectedDate: selectedDate,
              firstWeekday: DateTime.monday,
              items: _manyAllDayItemsFor(selectedDate),
              onDaySelected: (_) {},
              onCreateAtDay: (_) {},
              onItemSelected: (anchor, item, [_]) {
                selectedAnchor = anchor;
                selectedItem = item;
              },
              onTaskCompletionChanged: (_, _) {},
            ),
          ),
        ),
      ),
    );

    final moreButton = find.ancestor(
      of: find.textContaining('more'),
      matching: find.byType(TextButton),
    );
    expect(moreButton, findsOneWidget);
    tester.widget<TextButton>(moreButton).onPressed!();
    await tester.pumpAndSettle();
    expect(find.byType(BusyMaxPopoverSurface), findsOneWidget);
    expect(find.byType(ListView), findsOneWidget);
    final popoverChips = find.descendant(
      of: find.byType(ListView),
      matching: find.byType(ScheduleItemChip),
    );
    expect(popoverChips, findsWidgets);
    await tester.tap(popoverChips.at(1));
    await tester.pumpAndSettle();

    expect(selectedItem?.id, 'all-day-task:1');
    expect(selectedAnchor, isNotNull);
    expect(selectedAnchor!.mounted, isTrue);
  });

  testWidgets('calendar schedule chip invokes calendar item tap', (
    tester,
  ) async {
    final selectedDate = DateTime(2026, 1, 15);
    ScheduleItem? selectedItem;
    Offset? pointerPosition;
    final event = _itemsFor(
      selectedDate,
    ).whereType<CalendarScheduleItem>().first;

    await tester.pumpWidget(
      localizedTestApp(
        child: Scaffold(
          body: Center(
            child: ScheduleItemChip(
              item: event,
              height: 34,
              onTap: (_, [globalPosition]) {
                selectedItem = event;
                pointerPosition = globalPosition;
              },
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byType(ScheduleEventBlock).first);

    expect(selectedItem, isA<CalendarScheduleItem>());
    expect(pointerPosition, isNotNull);

    selectedItem = null;
    pointerPosition = null;
    final center = tester.getCenter(find.byType(ScheduleEventBlock).first);
    final secondaryClick = await tester.createGesture(
      kind: PointerDeviceKind.mouse,
      buttons: kSecondaryMouseButton,
    );
    await secondaryClick.addPointer(location: center);
    await secondaryClick.down(center);
    await secondaryClick.up();

    expect(selectedItem, isA<CalendarScheduleItem>());
    expect(pointerPosition, center);
  });

  testWidgets('schedule item details popover offers export, edit, and delete', (
    tester,
  ) async {
    final selectedDate = DateTime(2026, 1, 15);
    final event = _itemsFor(
      selectedDate,
    ).whereType<CalendarScheduleItem>().first;
    Future<ScheduleItemDetailsAction?>? action;

    await tester.pumpWidget(
      localizedTestApp(
        child: Scaffold(
          body: Builder(
            builder: (context) {
              return TextButton(
                onPressed: () {
                  action = showScheduleItemDetailsPopover(
                    context: context,
                    anchorContext: context,
                    item: event,
                  );
                },
                child: const Text('Open details'),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open details'));
    await tester.pumpAndSettle();

    expect(find.text('Design review'), findsOneWidget);
    expect(find.byIcon(YaruIcons.share), findsOneWidget);
    expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
    expect(find.byIcon(YaruIcons.trash), findsOneWidget);
    expect(find.byIcon(YaruIcons.window_close), findsOneWidget);
    expect(find.text('Export'), findsNothing);
    expect(find.text('Edit event'), findsNothing);
    expect(find.text('Delete'), findsNothing);
    expect(find.byType(BusyMaxPopoverIconButton), findsNWidgets(4));

    final actionButtons = tester
        .widgetList<YaruIconButton>(
          find.descendant(
            of: find.byType(BusyMaxPopoverIconButton),
            matching: find.byType(YaruIconButton),
          ),
        )
        .toList();
    final actionSurfaces = tester
        .widgetList<Material>(
          find.descendant(
            of: find.byType(BusyMaxPopoverIconButton),
            matching: find.byWidgetPredicate(
              (widget) => widget is Material && widget.shape is CircleBorder,
            ),
          ),
        )
        .toList();
    final actionContext = tester.element(
      find.byType(BusyMaxPopoverIconButton).first,
    );
    final actionColors = BusyMaxSurfaceColors.of(actionContext);
    expect(actionSurfaces, hasLength(4));
    for (final button in actionButtons) {
      expect(button.iconSize, kYaruTitleBarItemHeight);
      expect(button.style, isNull);
    }
    for (final surface in actionSurfaces) {
      expect(surface.color, actionColors.control);
      expect(surface.shape, const CircleBorder());
      expect(surface.clipBehavior, Clip.antiAlias);
    }
    expect(
      tester.widget<Icon>(find.byIcon(YaruIcons.trash)).color,
      Theme.of(actionContext).colorScheme.error,
    );
    expect(
      tester.widget<Icon>(find.byIcon(YaruIcons.share)).color,
      actionColors.foreground,
    );

    final popoverSurfaceFinder = find.byWidgetPredicate(
      (widget) =>
          widget is PhysicalShape &&
          widget.elevation == BusyMaxElevation.tooltip,
    );
    final popoverSurface = tester.widget<PhysicalShape>(popoverSurfaceFinder);
    final popoverContext = tester.element(popoverSurfaceFinder);
    final popoverRoute = ModalRoute.of(popoverContext)!;
    expect(
      popoverRoute.traversalEdgeBehavior,
      TraversalEdgeBehavior.closedLoop,
    );
    expect(
      popoverRoute.directionalTraversalEdgeBehavior,
      TraversalEdgeBehavior.stop,
    );
    expect(
      popoverSurface.shadowColor,
      Theme.of(popoverContext).colorScheme.shadow,
    );
    expect(popoverSurface.shadowColor.a, 1);
    expect(
      popoverSurface.color,
      BusyMaxSurfaceColors.of(popoverContext).popover,
    );

    final editCenter = tester.getCenter(find.byIcon(Icons.edit_outlined));
    final deleteCenter = tester.getCenter(find.byIcon(YaruIcons.trash));
    final closeCenter = tester.getCenter(find.byIcon(YaruIcons.window_close));
    expect(editCenter.dx, lessThan(deleteCenter.dx));
    expect(deleteCenter.dx, lessThan(closeCenter.dx));

    await tester.tap(find.byIcon(YaruIcons.share));
    await tester.pumpAndSettle();

    expect(await action, ScheduleItemDetailsAction.export);
  });

  for (final brightness in Brightness.values) {
    testWidgets(
      'popover action paints a contained circle and strengthens it on hover '
      'in $brightness mode',
      (tester) async {
        final theme = BusyMaxYaruTheme.build(
          brightness: brightness,
          accentColor: const Color(0xFF3584E4),
        );
        final colors = theme.extension<BusyMaxSurfaceColors>()!;
        final boundaryKey = GlobalKey();

        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: Center(
              child: RepaintBoundary(
                key: boundaryKey,
                child: ColoredBox(
                  color: colors.popover,
                  child: SizedBox.square(
                    dimension: 50,
                    child: Center(
                      child: BusyMaxPopoverIconButton(
                        icon: YaruIcons.share,
                        tooltip: 'Export',
                        onPressed: () {},
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final restingPixels = await _capturePixels(tester, boundaryKey);
        final background = _pixelAt(restingPixels, x: 2, y: 2);
        final restingFace = _pixelAt(restingPixels, x: 25, y: 12);
        expect(restingFace, isNot(background));

        final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
        addTearDown(mouse.removePointer);
        await mouse.addPointer(location: Offset.zero);
        await mouse.moveTo(
          tester.getCenter(find.byType(BusyMaxPopoverIconButton)),
        );
        await tester.pumpAndSettle();

        final hoveredPixels = await _capturePixels(tester, boundaryKey);
        final hoveredBackground = _pixelAt(hoveredPixels, x: 2, y: 2);
        final hoveredFace = _pixelAt(hoveredPixels, x: 25, y: 12);
        expect(hoveredBackground, background);
        expect(hoveredFace, isNot(restingFace));
        expect(
          _luminanceDistance(hoveredFace, background),
          greaterThan(_luminanceDistance(restingFace, background)),
        );
      },
    );
  }

  testWidgets('direct details popover registers for native-header dismissal', (
    tester,
  ) async {
    final selectedDate = DateTime(2026, 1, 15);
    final event = _itemsFor(
      selectedDate,
    ).whereType<CalendarScheduleItem>().first;
    final controller = ScheduleAnchoredPopoverController();

    await tester.pumpWidget(
      localizedTestApp(
        child: ScheduleAnchoredPopoverScope(
          controller: controller,
          child: Scaffold(
            body: Builder(
              builder: (anchorContext) => TextButton(
                onPressed: () {
                  showScheduleItemDetailsPopover(
                    context: anchorContext,
                    anchorContext: anchorContext,
                    item: event,
                  );
                },
                child: const Text('Open coordinated details'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open coordinated details'));
    await tester.pumpAndSettle();
    expect(controller.isOpen, isTrue);

    final dismissal = controller.dismiss();
    await tester.pumpAndSettle();
    await dismissal;

    expect(controller.isOpen, isFalse);
    expect(find.byIcon(YaruIcons.window_close), findsNothing);
  });

  testWidgets('schedule item details popover delete button returns delete', (
    tester,
  ) async {
    final selectedDate = DateTime(2026, 1, 15);
    final event = _itemsFor(
      selectedDate,
    ).whereType<CalendarScheduleItem>().first;
    Future<ScheduleItemDetailsAction?>? action;

    await tester.pumpWidget(
      localizedTestApp(
        child: Scaffold(
          body: Builder(
            builder: (context) {
              return TextButton(
                onPressed: () {
                  action = showScheduleItemDetailsPopover(
                    context: context,
                    anchorContext: context,
                    item: event,
                  );
                },
                child: const Text('Open details'),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open details'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(YaruIcons.trash));
    await tester.pumpAndSettle();

    expect(await action, ScheduleItemDetailsAction.delete);
  });

  testWidgets('read-only event details omit mutation actions', (tester) async {
    final event = CalendarScheduleItem(
      id: 'event:read-only',
      accountId: 'google:g',
      provider: TaskProvider.google,
      sourceId: 'calendar:shared',
      providerCalendarId: 'shared',
      title: 'Shared calendar event',
      allDay: false,
      start: DateTime(2026, 1, 15, 9),
      end: DateTime(2026, 1, 15, 10),
      capabilities: ScheduleItemCapabilities.readOnly,
    );

    await tester.pumpWidget(
      localizedTestApp(
        child: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showScheduleItemDetailsPopover(
                context: context,
                anchorContext: context,
                item: event,
              ),
              child: const Text('Open details'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open details'));
    await tester.pumpAndSettle();

    expect(find.byIcon(YaruIcons.share), findsOneWidget);
    expect(find.byIcon(YaruIcons.window_close), findsOneWidget);
    expect(find.byIcon(Icons.edit_outlined), findsNothing);
    expect(find.byIcon(YaruIcons.trash), findsNothing);
  });

  testWidgets('details popover constrains long content without animation', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(480, 300);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final event = CalendarScheduleItem(
      id: 'event:long',
      accountId: 'google:g',
      provider: TaskProvider.google,
      sourceId: 'calendar:primary',
      providerCalendarId: 'primary',
      title: 'A detailed event with a deliberately long title for sizing',
      allDay: false,
      start: DateTime(2026, 1, 15, 9),
      end: DateTime(2026, 1, 15, 10),
      location: 'A long location that still belongs inside the popover',
      description: List.filled(20, 'Detailed agenda notes').join(' '),
      categories: List.generate(20, (index) => 'Category $index'),
    );

    await tester.pumpWidget(
      localizedTestApp(
        child: MediaQuery(
          data: const MediaQueryData(
            size: Size(480, 300),
            disableAnimations: true,
          ),
          child: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showScheduleItemDetailsPopover(
                  context: context,
                  anchorContext: context,
                  item: event,
                ),
                child: const Text('Open details'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open details'));
    await tester.pump();

    final popover = find.byWidgetPredicate(
      (widget) =>
          widget is PhysicalShape &&
          widget.elevation == BusyMaxElevation.tooltip,
    );
    expect(popover, findsOneWidget);
    expect(tester.getSize(popover).height, lessThanOrEqualTo(276));
    expect(find.byType(SingleChildScrollView), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('schedule item details popover shows categories', (tester) async {
    final selectedDate = DateTime(2026, 1, 15);
    final task = TaskScheduleItem(
      id: 'task:1',
      accountId: 'microsoft:m',
      provider: TaskProvider.microsoft,
      sourceId: 'tasks:inbox',
      title: 'Submit report',
      completed: false,
      allDay: true,
      start: selectedDate,
      end: selectedDate.add(const Duration(days: 1)),
      categories: const ['Home', 'Work'],
    );

    await tester.pumpWidget(
      localizedTestApp(
        child: Scaffold(
          body: Builder(
            builder: (context) {
              return TextButton(
                onPressed: () {
                  showScheduleItemDetailsPopover(
                    context: context,
                    anchorContext: context,
                    item: task,
                  );
                },
                child: const Text('Open details'),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open details'));
    await tester.pumpAndSettle();

    expect(find.text('Categories: Home, Work'), findsOneWidget);
  });

  testWidgets('schedule event details popover shows reminders and categories', (
    tester,
  ) async {
    final event = CalendarScheduleItem(
      id: 'event:1',
      accountId: 'microsoft:m',
      provider: TaskProvider.microsoft,
      sourceId: 'calendar:primary',
      providerCalendarId: 'cal-1',
      title: 'Design review',
      allDay: false,
      start: DateTime(2026, 1, 15, 9),
      end: DateTime(2026, 1, 15, 10),
      categories: const ['Blue category', 'Work'],
      reminderMinutesBeforeStart: const [10, 60],
    );

    await tester.pumpWidget(
      localizedTestApp(
        child: Scaffold(
          body: Builder(
            builder: (context) {
              return TextButton(
                onPressed: () {
                  showScheduleItemDetailsPopover(
                    context: context,
                    anchorContext: context,
                    item: event,
                  );
                },
                child: const Text('Open details'),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open details'));
    await tester.pumpAndSettle();

    expect(
      find.text('Reminder: 10 minutes before, 1 hour before'),
      findsOneWidget,
    );
    expect(find.text('Categories: Blue category, Work'), findsOneWidget);
  });

  testWidgets('event reminder details use locale-aware labels', (tester) async {
    final event = CalendarScheduleItem(
      id: 'event:localized-reminders',
      accountId: 'google:g',
      provider: TaskProvider.google,
      sourceId: 'calendar:primary',
      providerCalendarId: 'primary',
      title: 'Termin',
      allDay: false,
      start: DateTime(2026, 1, 15, 9),
      end: DateTime(2026, 1, 15, 10),
      reminderMinutesBeforeStart: const [0, 60, 1440],
    );

    await tester.pumpWidget(
      localizedTestApp(
        locale: const Locale('de'),
        child: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showScheduleItemDetailsPopover(
                context: context,
                anchorContext: context,
                item: event,
              ),
              child: const Text('Öffnen'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Öffnen'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Erinnerung: Zum Startzeitpunkt, 1 Stunde vorher, 1 Tag vorher',
      ),
      findsOneWidget,
    );
  });

  testWidgets('schedule task details popover shows reminder', (tester) async {
    final selectedDate = DateTime(2026, 1, 15);
    final task = TaskScheduleItem(
      id: 'task:1',
      accountId: 'microsoft:m',
      provider: TaskProvider.microsoft,
      sourceId: 'tasks:inbox',
      title: 'Submit report',
      completed: false,
      allDay: true,
      start: selectedDate,
      end: selectedDate.add(const Duration(days: 1)),
      reminder: DateTime(2026, 1, 15, 8, 30),
    );

    await tester.pumpWidget(
      localizedTestApp(
        child: Scaffold(
          body: Builder(
            builder: (context) {
              return TextButton(
                onPressed: () {
                  showScheduleItemDetailsPopover(
                    context: context,
                    anchorContext: context,
                    item: task,
                  );
                },
                child: const Text('Open details'),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open details'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Reminder:'), findsOneWidget);
    expect(find.textContaining('8:30'), findsOneWidget);
  });

  testWidgets('schedule item details popover anchors near click point', (
    tester,
  ) async {
    final selectedDate = DateTime(2026, 1, 15);
    final event = _itemsFor(
      selectedDate,
    ).whereType<CalendarScheduleItem>().first;

    await tester.pumpWidget(
      localizedTestApp(
        child: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: Builder(
              builder: (context) {
                return TextButton(
                  onPressed: () {
                    showScheduleItemDetailsPopover(
                      context: context,
                      anchorContext: context,
                      anchorPoint: const Offset(700, 120),
                      item: event,
                    );
                  },
                  child: const Text('Open details'),
                );
              },
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open details'));
    await tester.pumpAndSettle();

    final popover = find.byWidgetPredicate(
      (widget) =>
          widget is PhysicalShape &&
          widget.elevation == BusyMaxElevation.tooltip,
    );
    final topLeft = tester.getTopLeft(popover);

    expect(topLeft.dx, greaterThan(300));
    expect(topLeft.dy, greaterThan(100));
  });

  testWidgets('schedule item details popover shown above stays near click', (
    tester,
  ) async {
    final selectedDate = DateTime(2026, 1, 15);
    final event = _itemsFor(
      selectedDate,
    ).whereType<CalendarScheduleItem>().first;

    await tester.pumpWidget(
      localizedTestApp(
        child: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: Builder(
              builder: (context) {
                return TextButton(
                  onPressed: () {
                    showScheduleItemDetailsPopover(
                      context: context,
                      anchorContext: context,
                      anchorPoint: const Offset(700, 540),
                      item: event,
                    );
                  },
                  child: const Text('Open details'),
                );
              },
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open details'));
    await tester.pumpAndSettle();

    final popover = find.byWidgetPredicate(
      (widget) =>
          widget is PhysicalShape &&
          widget.elevation == BusyMaxElevation.tooltip,
    );
    final rect = tester.getRect(popover);

    expect(rect.bottom, greaterThan(500));
    expect(rect.bottom, lessThan(545));
  });

  testWidgets('schedule item details popover closes from empty space', (
    tester,
  ) async {
    final selectedDate = DateTime(2026, 1, 15);
    final event = _itemsFor(
      selectedDate,
    ).whereType<CalendarScheduleItem>().first;

    await tester.pumpWidget(
      localizedTestApp(
        child: Scaffold(
          body: Builder(
            builder: (context) {
              return TextButton(
                onPressed: () {
                  showScheduleItemDetailsPopover(
                    context: context,
                    anchorContext: context,
                    item: event,
                  );
                },
                child: const Text('Open details'),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open details'));
    await tester.pumpAndSettle();
    expect(find.text('Design review'), findsOneWidget);

    await tester.tapAt(const Offset(8, 8));
    await tester.pumpAndSettle();

    expect(find.text('Design review'), findsNothing);
  });

  test('schedule item export writes event and task iCalendar payloads', () {
    final event = CalendarScheduleItem(
      id: 'event:1',
      accountId: 'google:g',
      provider: TaskProvider.google,
      sourceId: 'calendar:primary',
      providerCalendarId: 'primary',
      title: 'Review, plan',
      allDay: false,
      start: DateTime.utc(2026, 1, 15, 16),
      end: DateTime.utc(2026, 1, 15, 17),
      location: 'Room 1',
      description: 'Line 1\nLine 2',
    );
    final task = TaskScheduleItem(
      id: 'task:1',
      accountId: 'microsoft:m',
      provider: TaskProvider.microsoft,
      sourceId: 'tasks:inbox',
      title: 'Submit report',
      completed: true,
      allDay: true,
      start: DateTime.utc(2026, 1, 16),
      notes: 'Done',
    );

    final eventPayload = scheduleItemToICalendar(
      event,
      nowUtc: DateTime.utc(2026, 1, 1),
    );
    final taskPayload = scheduleItemToICalendar(
      task,
      nowUtc: DateTime.utc(2026, 1, 1),
    );

    expect(eventPayload, contains('BEGIN:VEVENT'));
    expect(eventPayload, contains(r'SUMMARY:Review\, plan'));
    expect(eventPayload, contains('DTSTART:20260115T160000Z'));
    expect(eventPayload, contains('DTEND:20260115T170000Z'));
    expect(eventPayload, contains(r'DESCRIPTION:Line 1\nLine 2'));
    expect(taskPayload, contains('BEGIN:VTODO'));
    expect(taskPayload, contains('DUE;VALUE=DATE:20260116'));
    expect(taskPayload, contains('STATUS:COMPLETED'));
    expect(scheduleExportFileName(event), endsWith('.ics'));
  });

  test('month weekday header uses calendar surface background', () {
    final source = File(
      'lib/src/features/schedule/presentation/schedule_month_view.dart',
    ).readAsStringSync();

    expect(source, contains('ColoredBox('));
    expect(source, contains('color: theme.colorScheme.surface'));
  });

  testWidgets('agenda view is custom and keeps no-date tasks', (tester) async {
    final selectedDate = DateTime(2026, 1, 15);
    final yesterday = selectedDate.subtract(const Duration(days: 1));

    await tester.pumpWidget(
      localizedTestApp(
        child: Scaffold(
          body: SizedBox(
            width: 1000,
            height: 720,
            child: ScheduleAgendaView(
              range: ScheduleRange(
                start: selectedDate,
                end: selectedDate.add(const Duration(days: 7)),
              ),
              items: [
                CalendarScheduleItem(
                  id: 'event:past',
                  accountId: 'google:g',
                  provider: TaskProvider.google,
                  sourceId: 'calendar:primary',
                  providerCalendarId: 'primary',
                  title: 'Yesterday event',
                  allDay: false,
                  start: DateTime(
                    yesterday.year,
                    yesterday.month,
                    yesterday.day,
                    9,
                  ),
                  end: DateTime(
                    yesterday.year,
                    yesterday.month,
                    yesterday.day,
                    10,
                  ),
                  sourceName: 'Work',
                ),
                TaskScheduleItem(
                  id: 'task:overdue',
                  accountId: 'microsoft:m',
                  provider: TaskProvider.microsoft,
                  sourceId: 'tasks:inbox',
                  title: 'Pay invoice',
                  completed: false,
                  allDay: true,
                  start: yesterday,
                  sourceName: 'Inbox',
                ),
                TaskScheduleItem(
                  id: 'task:completed-overdue',
                  accountId: 'microsoft:m',
                  provider: TaskProvider.microsoft,
                  sourceId: 'tasks:inbox',
                  title: 'Completed old task',
                  completed: true,
                  allDay: true,
                  start: yesterday,
                  sourceName: 'Inbox',
                ),
                ..._itemsFor(selectedDate),
                const TaskScheduleItem(
                  id: 'task:no-date',
                  accountId: 'google:g',
                  provider: TaskProvider.google,
                  sourceId: 'tasks:inbox',
                  title: 'Plan someday',
                  completed: false,
                  allDay: true,
                  sourceName: 'Inbox',
                ),
              ],
              onItemSelected: (_, _, [_]) {},
              onTaskCompletionChanged: (_, _) {},
            ),
          ),
        ),
      ),
    );

    expect(find.byType(icv.EventsList), findsNothing);
    expect(find.text('Overdue'), findsOneWidget);
    expect(find.text('Pay invoice'), findsOneWidget);
    expect(find.text('Completed old task'), findsNothing);
    expect(find.text('Yesterday event'), findsNothing);
    expect(find.text('Design review'), findsOneWidget);
    expect(find.text('Submit report'), findsOneWidget);
    expect(find.text('No date'), findsOneWidget);
    expect(find.text('Plan someday'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Overdue')).dy,
      lessThan(tester.getTopLeft(find.text('No date')).dy),
    );
    expect(
      tester.getTopLeft(find.text('No date')).dy,
      lessThan(tester.getTopLeft(find.text('Design review')).dy),
    );
  });

  testWidgets('agenda view stays blank instead of showing empty-state card', (
    tester,
  ) async {
    final selectedDate = DateTime(2026, 1, 15);

    await tester.pumpWidget(
      localizedTestApp(
        child: Scaffold(
          body: SizedBox(
            width: 1000,
            height: 720,
            child: ScheduleAgendaView(
              range: ScheduleRange.week(selectedDate),
              items: const [],
              onItemSelected: (_, _, [_]) {},
              onTaskCompletionChanged: (_, _) {},
            ),
          ),
        ),
      ),
    );

    expect(find.text('No events or tasks'), findsNothing);
    expect(find.text('New event'), findsNothing);
    expect(find.text('New task'), findsNothing);
  });

  testWidgets('agenda view reports row anchors for command popovers', (
    tester,
  ) async {
    final selectedDate = DateTime(2026, 1, 15);
    final anchors = <String, BuildContext>{};

    await tester.pumpWidget(
      localizedTestApp(
        child: Scaffold(
          body: SizedBox(
            width: 1000,
            height: 720,
            child: ScheduleAgendaView(
              range: ScheduleRange.week(selectedDate),
              items: _itemsFor(selectedDate),
              onItemSelected: (_, _, [_]) {},
              onItemAnchorAvailable: (item, context) {
                anchors[item.id] = context;
              },
              onTaskCompletionChanged: (_, _) {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(anchors.keys, containsAll(['event:1', 'task:1']));
    final renderObject = anchors['event:1']!.findRenderObject();
    expect(renderObject, isA<RenderBox>());
    expect((renderObject! as RenderBox).hasSize, isTrue);
  });

  testWidgets('agenda view asks for more items at the bottom', (tester) async {
    final selectedDate = DateTime(2026, 1, 15);
    var loadMoreCount = 0;

    await tester.pumpWidget(
      localizedTestApp(
        child: Scaffold(
          body: SizedBox(
            width: 420,
            height: 360,
            child: ScheduleAgendaView(
              range: ScheduleRange(
                start: selectedDate,
                end: selectedDate.add(const Duration(days: 30)),
              ),
              items: [
                for (var index = 0; index < 45; index++)
                  TaskScheduleItem(
                    id: 'task:$index',
                    accountId: 'google:g',
                    provider: TaskProvider.google,
                    sourceId: 'tasks:inbox',
                    title: 'Task $index',
                    completed: false,
                    allDay: true,
                    start: selectedDate.add(Duration(days: index)),
                    sourceName: 'Inbox',
                  ),
              ],
              onLoadMore: () => loadMoreCount++,
              onItemSelected: (_, _, [_]) {},
              onTaskCompletionChanged: (_, _) {},
            ),
          ),
        ),
      ),
    );

    await tester.drag(find.byType(ListView), const Offset(0, -5000));
    await tester.pump();

    expect(loadMoreCount, 1);
  });

  testWidgets('agenda view renders load-more rows for bounded buckets', (
    tester,
  ) async {
    final selectedDate = DateTime(2026, 1, 15);
    var overdueLoads = 0;
    var noDateLoads = 0;

    await tester.pumpWidget(
      localizedTestApp(
        child: Scaffold(
          body: SizedBox(
            width: 640,
            height: 520,
            child: ScheduleAgendaView(
              range: ScheduleRange(
                start: selectedDate,
                end: selectedDate.add(const Duration(days: 30)),
              ),
              items: [
                TaskScheduleItem(
                  id: 'task:overdue',
                  accountId: 'google:g',
                  provider: TaskProvider.google,
                  sourceId: 'tasks:inbox',
                  title: 'Pay invoice',
                  completed: false,
                  allDay: true,
                  start: selectedDate.subtract(const Duration(days: 1)),
                  sourceName: 'Inbox',
                ),
                const TaskScheduleItem(
                  id: 'task:no-date',
                  accountId: 'google:g',
                  provider: TaskProvider.google,
                  sourceId: 'tasks:inbox',
                  title: 'Plan someday',
                  completed: false,
                  allDay: true,
                  sourceName: 'Inbox',
                ),
              ],
              hasMoreOverdueTasks: true,
              hasMoreNoDateTasks: true,
              onLoadMoreOverdue: () => overdueLoads += 1,
              onLoadMoreNoDate: () => noDateLoads += 1,
              onItemSelected: (_, _, [_]) {},
              onTaskCompletionChanged: (_, _) {},
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Load more overdue tasks'));
    await tester.tap(find.text('Load more no-date tasks'));

    expect(overdueLoads, 1);
    expect(noDateLoads, 1);
  });

  test('schedule presentation does not use banned package final UI', () {
    final files = Directory(
      'lib/src/features/schedule/presentation',
    ).listSync().whereType<File>();
    for (final file in files) {
      final source = file.readAsStringSync();
      expect(source, isNot(contains('EventsMonths')));
      expect(source, isNot(contains('EventsList')));
      expect(source, isNot(contains('DefaultDayEvent')));
    }
  });

  test('Today toolbar action preserves current display mode', () {
    final source = File(
      'lib/src/features/schedule/presentation/schedule_workspace.dart',
    ).readAsStringSync();

    expect(source, contains('onToday: _goToToday'));
    expect(source, contains('BusyMaxHeaderBarAction.today'));
    expect(
      source,
      isNot(contains('onToday: () => _selectScope(ScheduleScope.today)')),
    );
  });

  test('schedule workspace uses Flutter toolbar only as native fallback', () {
    final source = File(
      'lib/src/features/schedule/presentation/schedule_workspace.dart',
    ).readAsStringSync();

    expect(source, contains('linuxHeaderBarServiceProvider'));
    expect(source, contains('final showFallbackHeader'));
    expect(source, contains('if (showFallbackHeader)'));
    expect(source, contains('final headerBarState = BusyMaxHeaderBarState('));
    expect(source, contains('.claimSession()'));
    expect(source, contains('_headerBarSession.updateState(headerBarState)'));
    expect(source, contains('onMenuSelected: _handleFallbackToolbarMenu'));
  });

  test('native headerbar actions are wired to schedule commands', () {
    final source = File(
      'lib/src/features/schedule/presentation/schedule_workspace.dart',
    ).readAsStringSync();

    expect(source, contains('BusyMaxHeaderBarAction.previous'));
    expect(source, contains('BusyMaxHeaderBarAction.next'));
    expect(source, contains('BusyMaxHeaderBarAction.viewModeDay'));
    expect(source, contains('BusyMaxHeaderBarAction.viewModeWeek'));
    expect(source, contains('BusyMaxHeaderBarAction.viewModeMonth'));
    expect(source, contains('BusyMaxHeaderBarAction.viewModeYear'));
    expect(source, contains('BusyMaxHeaderBarAction.viewModeAgenda'));
    expect(source, contains('BusyMaxHeaderBarAction.refresh'));
    expect(source, contains('allAccountsSyncRunnerProvider'));
    expect(source, contains('context.l10n.allTasksRefreshed'));
    expect(source, contains('setScheduleViewMode(mode)'));
    expect(source, contains('settings.scheduleViewMode'));
    expect(source, contains('ScheduleEmptyState'));
    expect(source, isNot(contains('BusyMaxHeaderBarAction.newItem')));
    expect(source, isNot(contains('BusyMaxHeaderBarAction.openMenu')));
  });

  test('schedule workspace wires navigation and view keyboard shortcuts', () {
    final source = File(
      'lib/src/features/schedule/presentation/schedule_workspace.dart',
    ).readAsStringSync();

    expect(source, isNot(contains('HardwareKeyboard.instance.addHandler')));
    expect(source, contains('return Shortcuts('));
    expect(source, contains('_ScheduleShortcutAction(this)'));
    expect(source, contains('route != null && !route.isCurrent'));
    expect(source, contains('BusyMaxShortcutActivators.search:'));
    expect(source, contains('BusyMaxShortcutActivators.create:'));
    expect(source, contains('LogicalKeyboardKey.arrowRight'));
    expect(source, contains('_next();'));
    expect(source, contains('LogicalKeyboardKey.arrowLeft'));
    expect(source, contains('_previous();'));
    expect(source, isNot(contains('LogicalKeyboardKey.keyJ')));
    expect(source, isNot(contains('LogicalKeyboardKey.keyN')));
    expect(source, isNot(contains('LogicalKeyboardKey.keyK')));
    expect(source, isNot(contains('LogicalKeyboardKey.keyP')));
    expect(source, contains('LogicalKeyboardKey.keyE'));
    expect(source, isNot(contains('LogicalKeyboardKey.keyC')));
    expect(source, contains('_openNewEvent(_latestWritableSources'));
    expect(source, contains('LogicalKeyboardKey.keyT'));
    expect(source, contains('_openNewTask(_latestAccounts'));
    expect(
      source,
      contains('SingleActivator(LogicalKeyboardKey.keyT, shift: true)'),
    );
    expect(source, contains('_goToToday();'));
    expect(source, contains('LogicalKeyboardKey.digit1'));
    expect(source, contains('LogicalKeyboardKey.keyD'));
    expect(source, contains('_setMode(ScheduleViewMode.day)'));
    expect(source, contains('LogicalKeyboardKey.digit2'));
    expect(source, contains('LogicalKeyboardKey.keyW'));
    expect(source, contains('_setMode(ScheduleViewMode.week)'));
    expect(source, contains('LogicalKeyboardKey.digit3'));
    expect(source, contains('LogicalKeyboardKey.keyM'));
    expect(source, contains('_setMode(ScheduleViewMode.month)'));
    expect(source, contains('LogicalKeyboardKey.digit4'));
    expect(source, contains('LogicalKeyboardKey.keyY'));
    expect(source, contains('_setMode(ScheduleViewMode.year)'));
    expect(source, contains('LogicalKeyboardKey.digit0'));
    expect(source, contains('LogicalKeyboardKey.keyA'));
    expect(source, contains('_setMode(ScheduleViewMode.agenda)'));
    expect(source, contains('focusContext.widget is! EditableText'));
  });

  test('calendar event mutations request immediate account sync', () {
    final source = File(
      'lib/src/features/schedule/presentation/schedule_workspace.dart',
    ).readAsStringSync();

    expect(source, contains('calendarRepositoryProvider).updateLocalEvent'));
    expect(source, contains('_requestCalendarMutationSync(draft.accountId)'));
    expect(source, contains('.deleteLocalEvent(eventId)'));
    expect(source, contains('_requestCalendarMutationSync(accountId)'));
    expect(source, contains('accountSyncOperationsProvider'));
    expect(source, isNot(contains('signedInSyncRunnerProvider)(accountId')));
  });

  test('schedule item clicks route through details popover before edit', () {
    final source = File(
      'lib/src/features/schedule/presentation/schedule_workspace.dart',
    ).readAsStringSync();

    expect(source, contains('showScheduleItemDetailsPopover('));
    expect(source, contains('ScheduleItemDetailsAction.export'));
    expect(source, contains('ScheduleItemDetailsAction.edit'));
    expect(source, contains('ScheduleItemDetailsAction.delete'));
    expect(source, contains('exportScheduleItemWithSaveDialog(item)'));
    expect(source, isNot(contains('exportScheduleItemToDownloads(item)')));
    expect(source, contains('void _editItem('));
    expect(source, contains('Future<void> _deleteItem('));
    expect(source, contains('reminders: _eventRemindersForEdit('));
  });

  test('month overflow uses the shared anchored popover route', () {
    final month = File(
      'lib/src/features/schedule/presentation/schedule_month_view.dart',
    ).readAsStringSync();
    final more = File(
      'lib/src/features/schedule/presentation/schedule_more_popover.dart',
    ).readAsStringSync();

    expect(month, contains('anchorContext: anchorContext'));
    expect(
      more,
      contains('showScheduleAnchoredPopover<ScheduleMorePopoverSelection>('),
    );
    expect(more, contains('BusyMaxPopoverSurface('));
    expect(more, isNot(contains('showDialog<void>(')));
    expect(more, isNot(contains('Dialog(')));
  });

  test('schedule item details actions use the shared contained Yaru role', () {
    final design = File('lib/src/app/busymax_design.dart').readAsStringSync();
    final popover = File(
      'lib/src/features/schedule/presentation/schedule_item_details_popover.dart',
    ).readAsStringSync();

    expect(design, contains('class BusyMaxPopoverIconButton'));
    expect(design, contains('return Material('));
    expect(design, contains('shape: const CircleBorder()'));
    expect(design, contains('child: YaruIconButton('));
    expect(design, contains('iconSize: kYaruTitleBarItemHeight'));
    expect(design, contains('color: enabled ? colors.control'));
    expect(popover, contains('BusyMaxPopoverIconButton('));
    expect(popover, contains('destructive: true'));
    expect(popover, isNot(contains('backgroundColor:')));
    expect(popover, isNot(contains('foregroundColor:')));
    expect(popover, isNot(contains('hoverColor:')));
  });

  test(
    'schedule search renders query results instead of current range only',
    () {
      final workspace = File(
        'lib/src/features/schedule/presentation/schedule_workspace.dart',
      ).readAsStringSync();
      final agenda = File(
        'lib/src/features/schedule/presentation/schedule_agenda_view.dart',
      ).readAsStringSync();
      final repository = File(
        'lib/src/schedule/schedule_repository.dart',
      ).readAsStringSync();

      expect(
        workspace,
        contains('final searchHasQuery = _searchQuery.trim().isNotEmpty'),
      );
      expect(workspace, contains('_rangeForSearchResults(items, range)'));
      expect(workspace, contains('? ScheduleViewMode.agenda'));
      expect(
        repository,
        contains('final searching = filters.query.trim().isNotEmpty'),
      );
      expect(repository, contains('!searching && !_intersects'));
      expect(agenda, contains('groups.keys'));
      expect(agenda, contains('ColoredBox('));
      expect(agenda, contains('color: Theme.of(context).colorScheme.surface'));
      expect(agenda, isNot(contains('_daysInRange')));
    },
  );

  test('agenda list groups use the shared grouped row surface', () {
    final agenda = File(
      'lib/src/features/schedule/presentation/schedule_agenda_view.dart',
    ).readAsStringSync();
    final compactAgenda = File(
      'lib/src/features/schedule/presentation/compact_agenda_panel.dart',
    ).readAsStringSync();
    final design = File('lib/src/app/busymax_design.dart').readAsStringSync();

    expect(agenda, contains('BusyMaxGroupedList('));
    expect(compactAgenda, contains('BusyMaxGroupedList('));
    expect(agenda, isNot(contains('surfaceColor:')));
    expect(compactAgenda, isNot(contains('surfaceColor:')));
    expect(agenda, contains('ScheduleProjection.colorForItem'));
    expect(compactAgenda, contains('ScheduleProjection.colorForItem'));
    expect(
      agenda,
      contains('BusyMaxSurfaceColors.of(context).mutedForeground'),
    );
    expect(
      compactAgenda,
      contains('BusyMaxSurfaceColors.of(context).mutedForeground'),
    );
    expect(design, isNot(contains('final Color? surfaceColor;')));
    expect(design, isNot(contains('color: color ?? surfaceColors.control')));
    expect(design, contains('color: surfaceColors.groupedSurface'));
    expect(design, contains('BusyMaxShadow.physicalColor(context)'));
    expect(design, isNot(contains('lightSurfaceShadowMinimum')));
    expect(design, isNot(contains('class _BusyMaxRowTile')));
  });

  test('sidebar does not render redundant provider group titles', () {
    final sidebar = File(
      'lib/src/features/schedule/presentation/schedule_sidebar.dart',
    ).readAsStringSync();
    final nativeRunner = File(
      'linux/runner/my_application.cc',
    ).readAsStringSync();

    expect(nativeRunner, contains('header_sidebar_brand_box'));
    expect(nativeRunner, contains('gtk_label_new(kApplicationDisplayName)'));
    expect(nativeRunner, isNot(contains('busymax-sidebar-header')));
    expect(nativeRunner, isNot(contains('GtkWidget* brand_box')));
    expect(sidebar, isNot(contains('title: account.provider.displayName')));
    expect(sidebar, isNot(contains('YaruIcons.globe')));
    expect(sidebar, isNot(contains('Icons.account_circle_outlined')));
  });

  test('sidebar account rows are accordions', () {
    final sidebar = File(
      'lib/src/features/schedule/presentation/schedule_sidebar.dart',
    ).readAsStringSync();

    expect(sidebar, contains('class _AccountSourcesGroupState'));
    expect(sidebar, contains('var _expanded = true'));
    expect(sidebar, contains('class _AccountHeaderRow'));
    expect(sidebar, contains('AnimatedRotation'));
    expect(sidebar, contains('YaruIcons.pan_end'));
    expect(sidebar, contains('if (_expanded)'));
    expect(sidebar, isNot(contains('BusyMaxGroupedList(')));
    expect(sidebar, isNot(contains('hoverColor: Colors.transparent')));
  });

  test('mini calendar has separate month and year steppers', () {
    final source = File(
      'lib/src/features/schedule/presentation/mini_calendar.dart',
    ).readAsStringSync();

    expect(source, contains('class _MiniCalendarStepper'));
    expect(source, contains('required this.onMonthSelected'));
    expect(source, contains('required this.onYearSelected'));
    expect(source, contains('required this.onWeekSelected'));
    expect(source, contains('required this.firstWeekday'));
    expect(source, contains('_calendarStartForMonth(first, firstWeekday)'));
    expect(source, contains('monthWeekdayFromMonday'));
    expect(source, contains('firstWeekdayFromMonday'));
    expect(source, contains('_addCalendarDays('));
    expect(source, contains('row * DateTime.daysPerWeek'));
    expect(source, contains('_addCalendarDays(weekStart, column)'));
    expect(source, isNot(contains('weekStart.add(Duration(days: column))')));
    expect(source, contains('final weekNumberExtent = math.min'));
    expect(source, contains('constraints.maxWidth - weekNumberExtent'));
    expect(source, isNot(contains('final calendarWidth =')));
    expect(source, contains('class _MiniCalendarWeekRow'));
    expect(source, contains('class _MiniCalendarWeekNumberButton'));
    expect(source, contains('class _MiniCalendarDayButton'));
    expect(source, contains('class _MiniCalendarDayIndicators'));
    expect(
      source,
      contains('final groupedItems = ScheduleProjection.groupByDay(items)'),
    );
    expect(source, contains('DateFormat.E('));
    expect(source, contains('_weekdays(firstWeekday)'));
    expect(source, contains('ScheduleProjection.colorForItem'));
    expect(source, contains('height: dayExtent'));
    expect(source, contains('width: double.infinity'));
    expect(source, contains('crossAxisAlignment: CrossAxisAlignment.stretch'));
    expect(source, contains('SizedBox(width: weekNumberExtent)'));
    expect(
      source,
      contains('for (var column = 0; column < DateTime.daysPerWeek; column++)'),
    );
    expect(source, isNot(contains('GridView.builder')));
    expect(source, contains('const SizedBox(width: BusyMaxSpacing.xs)'));
    expect(
      source,
      contains('label: DateFormat.MMMM(locale).format(selectedDate)'),
    );
    expect(source, contains('BusyMaxSpacing.headerInset'));
    expect(
      source,
      isNot(contains('padding: const EdgeInsets.all(BusyMaxSpacing.md)')),
    );
    expect(source, contains('labelTooltip: l10n.openMonthView'));
    expect(source, contains('onMonthSelected(first)'));
    expect(source, contains('busyMaxHeaderTextButtonStyle'));
    expect(source, contains("label: '\${selectedDate.year}'"));
    expect(source, contains('labelTooltip: l10n.openYearView'));
    expect(source, contains('onYearSelected('));
    expect(source, isNot(contains('String _monthName(DateTime date)')));
    expect(
      source,
      isNot(contains("return '\${months[date.month - 1]} \${date.year}';")),
    );
    expect(source, contains('previousTooltip: l10n.previousMonth'));
    expect(source, contains('nextTooltip: l10n.nextMonth'));
    expect(source, contains('previousTooltip: l10n.previousYear'));
    expect(source, contains('nextTooltip: l10n.nextYear'));
    expect(source, contains('selectedDate.year - 1'));
    expect(source, contains('selectedDate.year + 1'));
    expect(source, contains('busyMaxHeaderIconButtonStyle'));
    expect(source, contains('miniCalendarWeekButton'));
    expect(source, contains('busyMaxHeaderButtonBackground(context)'));
    expect(source, isNot(contains('busyMaxSubtleButtonBackground(context)')));
    expect(source, contains('_isoWeekNumber'));
    expect(source, contains('DateTime.daysPerWeek'));
    expect(source, contains('TextButton('));
    expect(source, contains('context.l10n.weekNumberTooltip(weekNumber)'));
    expect(source, contains('onSelected(weekStart)'));
    expect(source, contains('BoxShape.circle'));
    expect(source, contains('customBorder: const CircleBorder()'));
    expect(source, contains('final markerSize = math.min'));
    expect(
      source,
      contains('final highlightToday = today && displayingCurrentMonth'),
    );
    expect(source, contains('color: selected'));
    expect(source, contains('selectedDate.year == DateTime.now().year'));
    expect(source, contains('selectedDate.month == DateTime.now().month'));
    expect(source, contains('final selected = _sameDay(day, selectedDate)'));
    expect(source, isNot(contains('YaruIcons.arrow_left')));
    expect(source, isNot(contains('YaruIcons.arrow_right')));
    expect(source, isNot(contains('BorderRadius.circular(BusyMaxRadius.sm)')));
  });

  testWidgets('mini calendar exposes and activates the selected day', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    DateTime? activatedDay;

    await tester.pumpWidget(
      localizedTestApp(
        child: Scaffold(
          body: SizedBox(
            width: 300,
            child: MiniCalendar(
              selectedDate: DateTime(2026, 1, 15),
              firstWeekday: DateTime.monday,
              onSelected: (day) => activatedDay = day,
              onMonthSelected: (_) {},
              onYearSelected: (_) {},
              onWeekSelected: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final selectedDay = find.text('15');
    final selectedSemantics = tester.getSemantics(selectedDay);
    expect(selectedSemantics.flagsCollection.isSelected, ui.Tristate.isTrue);
    expect(selectedSemantics.label, contains('January 15, 2026'));

    await tester.tap(selectedDay);
    expect(activatedDay, DateTime(2026, 1, 15));
    semantics.dispose();
  });

  testWidgets('mini calendar week number selects that week', (tester) async {
    DateTime? selectedWeek;

    await tester.pumpWidget(
      localizedTestApp(
        child: Scaffold(
          body: SizedBox(
            width: 300,
            child: MiniCalendar(
              selectedDate: DateTime(2026, 1, 15),
              firstWeekday: DateTime.monday,
              onSelected: (_) {},
              onMonthSelected: (_) {},
              onYearSelected: (_) {},
              onWeekSelected: (weekStart) => selectedWeek = weekStart,
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byTooltip('Week 3'));

    expect(selectedWeek, DateTime(2026, 1, 12));
  });

  testWidgets('mini calendar week number honors first weekday', (tester) async {
    DateTime? selectedWeek;

    await tester.pumpWidget(
      localizedTestApp(
        child: Scaffold(
          body: SizedBox(
            width: 300,
            child: MiniCalendar(
              selectedDate: DateTime(2026, 1, 15),
              firstWeekday: DateTime.sunday,
              onSelected: (_) {},
              onMonthSelected: (_) {},
              onYearSelected: (_) {},
              onWeekSelected: (weekStart) => selectedWeek = weekStart,
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byTooltip('Week 1'));

    expect(selectedWeek, DateTime(2026, 1, 4));
  });

  testWidgets(
    'mini calendar shows previous month day for Sunday-first Monday starts',
    (tester) async {
      await tester.pumpWidget(
        localizedTestApp(
          child: Scaffold(
            body: SizedBox(
              width: 300,
              child: MiniCalendar(
                selectedDate: DateTime(2027, 11, 1),
                firstWeekday: DateTime.sunday,
                onSelected: (_) {},
                onMonthSelected: (_) {},
                onYearSelected: (_) {},
                onWeekSelected: (_) {},
              ),
            ),
          ),
        ),
      );

      expect(find.text('31'), findsOneWidget);
      expect(find.byTooltip('Sunday, October 31, 2027'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byTooltip('Sunday, October 31, 2027'),
          matching: find.text('31'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byTooltip('Sunday, October 31, 2027'),
          matching: find.text('1'),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: find.byTooltip('Monday, November 1, 2027'),
          matching: find.text('1'),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('mini calendar advances dates across DST fallback days', (
    tester,
  ) async {
    await tester.pumpWidget(
      localizedTestApp(
        child: Scaffold(
          body: SizedBox(
            width: 300,
            child: MiniCalendar(
              selectedDate: DateTime(2026, 11, 1),
              firstWeekday: DateTime.sunday,
              onSelected: (_) {},
              onMonthSelected: (_) {},
              onYearSelected: (_) {},
              onWeekSelected: (_) {},
            ),
          ),
        ),
      ),
    );

    expect(
      find.descendant(
        of: find.byTooltip('Sunday, November 1, 2026'),
        matching: find.text('1'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byTooltip('Monday, November 2, 2026'),
        matching: find.text('2'),
      ),
      findsOneWidget,
    );
    expect(find.byTooltip('Monday, November 1, 2026'), findsNothing);
  });

  testWidgets('mini calendar keeps two-digit days inside narrow cells', (
    tester,
  ) async {
    await tester.pumpWidget(
      localizedTestApp(
        child: Scaffold(
          body: SizedBox(
            width: 128,
            child: MiniCalendar(
              selectedDate: DateTime(2027, 11, 1),
              firstWeekday: DateTime.sunday,
              onSelected: (_) {},
              onMonthSelected: (_) {},
              onYearSelected: (_) {},
              onWeekSelected: (_) {},
            ),
          ),
        ),
      ),
    );

    final sundayCell = tester.getRect(
      find.byTooltip('Sunday, October 31, 2027'),
    );
    final dayLabel = tester.getRect(find.text('31'));

    expect(dayLabel.left, greaterThanOrEqualTo(sundayCell.left - 0.1));
    expect(dayLabel.right, lessThanOrEqualTo(sundayCell.right + 0.1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('mini calendar month label selects that month', (tester) async {
    DateTime? selectedMonth;

    await tester.pumpWidget(
      localizedTestApp(
        child: Scaffold(
          body: SizedBox(
            width: 300,
            child: MiniCalendar(
              selectedDate: DateTime(2026, 5, 15),
              firstWeekday: DateTime.monday,
              onSelected: (_) {},
              onMonthSelected: (month) => selectedMonth = month,
              onYearSelected: (_) {},
              onWeekSelected: (_) {},
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byTooltip('Open month view'));

    expect(selectedMonth, DateTime(2026, 5));
  });

  testWidgets('mini calendar year label selects that year', (tester) async {
    DateTime? selectedYear;

    await tester.pumpWidget(
      localizedTestApp(
        child: Scaffold(
          body: SizedBox(
            width: 300,
            child: MiniCalendar(
              selectedDate: DateTime(2026, 5, 15),
              firstWeekday: DateTime.monday,
              onSelected: (_) {},
              onMonthSelected: (_) {},
              onYearSelected: (year) => selectedYear = year,
              onWeekSelected: (_) {},
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byTooltip('Open year view'));

    expect(selectedYear, DateTime(2026));
  });

  test('sidebar mini calendar opens day, month, year, and week modes', () {
    final sidebar = File(
      'lib/src/features/schedule/presentation/schedule_sidebar.dart',
    ).readAsStringSync();
    final workspace = File(
      'lib/src/features/schedule/presentation/schedule_workspace.dart',
    ).readAsStringSync();

    expect(sidebar, contains('required this.firstWeekday'));
    expect(sidebar, contains('firstWeekday: firstWeekday'));
    expect(workspace, contains('firstWeekday: _firstWeekday(context)'));
    expect(workspace, contains('final miniCalendarItemsFuture = ref'));
    expect(workspace, contains('ScheduleRange.month('));
    expect(workspace, contains('showNoDateTasks: false'));
    expect(workspace, contains('items: miniCalendarItems'));
    expect(sidebar, contains('required this.onMonthSelected'));
    expect(sidebar, contains('required this.onYearSelected'));
    expect(sidebar, contains('required this.onWeekSelected'));
    expect(sidebar, contains('onMonthSelected: onMonthSelected'));
    expect(sidebar, contains('onYearSelected: onYearSelected'));
    expect(sidebar, contains('onWeekSelected: onWeekSelected'));
    expect(workspace, contains('onDateSelected: _openDay'));
    expect(workspace, contains('onMonthSelected: _setMonth'));
    expect(workspace, contains('onYearSelected: _setYear'));
    expect(workspace, contains('onWeekSelected: _setWeek'));
    expect(workspace, contains('void _openDay(DateTime date)'));
    expect(workspace, contains('void _setMonth(DateTime month)'));
    expect(workspace, contains('void _setYear(DateTime year)'));
    expect(workspace, contains('void _setWeek(DateTime weekStart)'));
    expect(workspace, contains('_mode = ScheduleViewMode.day'));
    expect(workspace, contains('_mode = ScheduleViewMode.month'));
    expect(workspace, contains('_mode = ScheduleViewMode.year'));
    expect(workspace, contains('_mode = ScheduleViewMode.week'));
    expect(workspace, contains('setScheduleViewMode(ScheduleViewMode.day)'));
    expect(workspace, contains('setScheduleViewMode(ScheduleViewMode.month)'));
    expect(workspace, contains('setScheduleViewMode(ScheduleViewMode.year)'));
    expect(workspace, contains('setScheduleViewMode(ScheduleViewMode.week)'));
  });

  test('year view day clicks open day mode', () {
    final workspace = File(
      'lib/src/features/schedule/presentation/schedule_workspace.dart',
    ).readAsStringSync();

    expect(workspace, contains('required this.onYearDaySelected'));
    expect(workspace, contains('onYearDaySelected: _openDay'));
    expect(workspace, contains('onDaySelected: onYearDaySelected'));
  });

  test('sidebar source rows keep visibility actions on the right', () {
    final sidebar = File(
      'lib/src/features/schedule/presentation/schedule_sidebar.dart',
    ).readAsStringSync();

    expect(sidebar, contains('class _CompactSourceRow'));
    expect(sidebar, contains('class _SourceRowActions'));
    expect(sidebar, contains('class _SourceVisibilityButton'));
    expect(sidebar, contains('visibilityButton: _SourceVisibilityButton'));
    expect(sidebar, contains('menuButton: BusyMaxMenuButton'));
    expect(sidebar, contains('tooltip: context.l10n.options'));
    expect(sidebar, contains('value ? context.l10n.hide : context.l10n.show'));
    expect(sidebar, isNot(contains('tooltip: context.l10n.sourceCalendar')));
    expect(sidebar, isNot(contains('tooltip: context.l10n.sourceTaskList')));
    expect(sidebar, isNot(contains('? context.l10n.hideFromSchedule')));
    expect(sidebar, isNot(contains(': context.l10n.showInSchedule')));
    expect(sidebar, contains('minHeight: BusyMaxSizes.sidebarRowHeight'));
    expect(sidebar, contains('leading: _SourceDot'));
    expect(sidebar, contains('class _SourceDot'));
    expect(sidebar, contains('YaruIcons.checkmark'));
    expect(sidebar, contains('busyMaxSubtleButtonBackground(context)'));
    expect(sidebar, isNot(contains('YaruIcons.checkbox')));
    expect(sidebar, isNot(contains('InkWell(')));
    expect(sidebar, isNot(contains('_SourceVisibilityIndicator')));
  });

  test('schedule Create uses a native popover before refresh', () {
    final workspace = File(
      'lib/src/features/schedule/presentation/schedule_workspace.dart',
    ).readAsStringSync();
    final headerBar = File('linux/runner/my_application.cc').readAsStringSync();
    final headerService = File(
      'lib/src/platform/linux_header_bar_service.dart',
    ).readAsStringSync();
    final sidebar = File(
      'lib/src/features/schedule/presentation/schedule_sidebar.dart',
    ).readAsStringSync();
    final toolbar = File(
      'lib/src/features/schedule/presentation/schedule_toolbar.dart',
    ).readAsStringSync();

    expect(workspace, isNot(contains('floatingActionButtonLocation')));
    expect(workspace, isNot(contains('FloatingActionButton(')));
    expect(workspace, contains('BusyMaxHeaderBarAction.createEvent'));
    expect(workspace, contains('BusyMaxHeaderBarAction.createTask'));
    expect(workspace, contains('void _openCreateAtSelectedDate()'));
    expect(workspace, contains('_createMenuController.openForKeyboard()'));
    expect(
      headerService,
      isNot(contains("'create' => BusyMaxHeaderBarAction.create")),
    );
    expect(
      headerBar,
      contains('gtk_image_new_from_icon_name("list-add-symbolic"'),
    );
    expect(
      headerBar,
      contains(
        'g_menu_append(menu, self->header_create_event_label,\n'
        '                "header.create-event")',
      ),
    );
    expect(
      headerBar,
      contains(
        'g_menu_append(menu, self->header_create_task_label, '
        '"header.create-task")',
      ),
    );
    expect(headerBar, contains('gtk_menu_button_set_menu_model'));
    expect(headerBar, contains('g_simple_action_set_enabled'));
    expect(headerBar, contains('show_header_create_menu'));
    expect(headerService, contains("'showCreateMenu'"));
    expect(
      headerBar.indexOf(
        'gtk_box_pack_start(GTK_BOX(end_box), self->create_button',
      ),
      lessThan(
        headerBar.indexOf(
          'gtk_box_pack_start(GTK_BOX(end_box), self->refresh_button',
        ),
      ),
    );
    expect(sidebar, isNot(contains('context.l10n.create')));
    expect(sidebar, isNot(contains('PushButton.filled')));
    expect(toolbar, contains('tooltip: context.l10n.create'));
    expect(toolbar, contains('icon: const Icon(YaruIcons.plus)'));
    expect(toolbar, contains('tooltip: context.l10n.refreshAll'));
  });

  test('day and week today tint stays subtle', () {
    final source = File(
      'lib/src/features/schedule/presentation/schedule_day_week_view.dart',
    ).readAsStringSync();

    expect(
      source,
      contains(
        'final todayOverlayAlpha = widget.daysShowed == 1 ? 0.0 : 0.035',
      ),
    );
    expect(source, isNot(contains('alpha: 0.07')));
  });

  test('day mode removes weekday date header but keeps week headers', () {
    final source = File(
      'lib/src/features/schedule/presentation/schedule_day_week_view.dart',
    ).readAsStringSync();

    expect(
      source,
      contains('daysHeaderHeight: widget.daysShowed == 1 ? 0 : 50'),
    );
    expect(
      source,
      contains('widget.daysShowed == 1\n            ? const SizedBox.shrink()'),
    );
    expect(source, contains('_PlannerDayHeader(day: day, isToday: isToday)'));
  });

  test('schedule chips keep grid metadata out of inline text', () {
    final eventBlock = File(
      'lib/src/features/schedule/presentation/schedule_event_block.dart',
    ).readAsStringSync();
    final taskChip = File(
      'lib/src/features/schedule/presentation/schedule_task_chip.dart',
    ).readAsStringSync();

    expect(eventBlock, contains('showTime'));
    expect(eventBlock, contains('_tooltipDetails'));
    expect(eventBlock, isNot(contains('details,\n')));
    expect(taskChip, contains('Tooltip'));
    expect(taskChip, isNot(contains('if (!compact)')));
  });

  test('schedule item chips keep neutral surfaces with source accents', () {
    final eventBlock = File(
      'lib/src/features/schedule/presentation/schedule_event_block.dart',
    ).readAsStringSync();
    final taskChip = File(
      'lib/src/features/schedule/presentation/schedule_task_chip.dart',
    ).readAsStringSync();
    final projection = File(
      'lib/src/schedule/schedule_projection.dart',
    ).readAsStringSync();

    expect(eventBlock, contains('color: surfaceColors.control'));
    expect(eventBlock, contains('sourceAccent'));
    expect(taskChip, contains('color: surfaceColors.control'));
    expect(taskChip, contains('color: surfaceColors.divider'));
    expect(taskChip, contains('YaruCheckbox('));
    expect(taskChip, isNot(contains('selectedColor:')));
    expect(taskChip, isNot(contains('checkmarkColor:')));
    expect(taskChip, isNot(contains('YaruCheckboxTheme')));
    expect(eventBlock, isNot(contains('Color.alphaBlend(')));
    expect(taskChip, isNot(contains('Color.alphaBlend(')));
    expect(projection, contains('_colorFromHex(item.colorHex)'));
    expect(projection, contains('deterministicSourceColor(item.sourceId'));
    expect(projection, isNot(contains('0xff4d7fa8')));
    expect(projection, isNot(contains('0xff8db3d9')));
    expect(projection, isNot(contains('0xff326b88')));
    expect(projection, isNot(contains('0xff81b9d7')));
  });

  test('day and week planner jumps when selected date changes', () {
    final source = File(
      'lib/src/features/schedule/presentation/schedule_day_week_view.dart',
    ).readAsStringSync();

    expect(source, contains('final _plannerKey = GlobalKey'));
    expect(
      source,
      contains(
        '_controller = icv.EventsController();\n    _jumpToVisibleDayStart();',
      ),
    );
    expect(source, contains('_plannerKey.currentState?.jumpToDate(date)'));
    expect(source, contains('initialDate: _plannerStartDate(widget)'));
  });

  test(
    'day and week all-day bar and time gutter use rendered planner state',
    () {
      final source = File(
        'lib/src/features/schedule/presentation/schedule_day_week_view.dart',
      ).readAsStringSync();

      expect(source, contains('_hasRenderedFullDayEvents(context, widget)'));
      expect(source, contains('_ScheduleIcvEvent.fromItem(context, item)'));
      expect(source, contains('_fullDayEventIntersectsRange'));
      expect(source, isNot(contains('_allDayItemIntersectsRange')));
      expect(source, contains('textAlign: TextAlign.center'));
    },
  );

  test('month and year views support horizontal paging gestures', () {
    final source = File(
      'lib/src/features/schedule/presentation/schedule_workspace.dart',
    ).readAsStringSync();

    expect(source, contains('class _HorizontalSchedulePager'));
    expect(source, contains('onHorizontalDragEnd'));
    expect(
      source,
      contains('ScheduleViewMode.month => _HorizontalSchedulePager'),
    );
    expect(
      source,
      contains('ScheduleViewMode.year => _HorizontalSchedulePager'),
    );
    expect(
      source,
      isNot(contains('ScheduleViewMode.agenda => _HorizontalSchedulePager')),
    );
    expect(source, contains('ScheduleViewMode.agenda => ScheduleAgendaView'));
    expect(source, contains('onPrevious: onPrevious'));
    expect(source, contains('onNext: onNext'));
  });

  test('agenda range starts at today and grows while scrolling', () {
    final source = File(
      'lib/src/features/schedule/presentation/schedule_workspace.dart',
    ).readAsStringSync();
    final agendaSource = File(
      'lib/src/features/schedule/presentation/schedule_agenda_view.dart',
    ).readAsStringSync();

    expect(source, contains('static const _agendaInitialDays = 30'));
    expect(source, contains('static const _agendaPageDays = 30'));
    expect(source, contains('static const _agendaInitialTaskBucketLimit = 8'));
    expect(source, contains('static const _agendaTaskBucketPageSize = 8'));
    expect(source, contains('var _agendaLoadedDays = _agendaInitialDays'));
    expect(
      source,
      contains('var _agendaOverdueTaskLimit = _agendaInitialTaskBucketLimit'),
    );
    expect(
      source,
      contains('var _agendaNoDateTaskLimit = _agendaInitialTaskBucketLimit'),
    );
    expect(
      source,
      contains('ScheduleViewMode.agenda => _agendaRangeFromToday()'),
    );
    expect(source, contains('ScheduleRange _agendaRangeFromToday()'));
    expect(source, contains('final start = _day(DateTime.now())'));
    expect(
      source,
      contains('end: start.add(Duration(days: _agendaLoadedDays))'),
    );
    expect(source, contains('_selectedDate = _day(DateTime.now())'));
    expect(source, contains('void _loadMoreAgendaDays()'));
    expect(source, contains('_agendaLoadedDays += _agendaPageDays'));
    expect(source, contains('onLoadMore: onAgendaLoadMore'));
    expect(
      source,
      isNot(contains('ScheduleViewMode.agenda => ScheduleRange.week')),
    );
    expect(agendaSource, contains('notification.metrics.extentAfter > 1'));
    expect(source, isNot(contains('subtract(const Duration(days: 30))')));
    expect(source, contains('void _loadMoreAgendaOverdueTasks()'));
    expect(source, contains('void _loadMoreAgendaNoDateTasks()'));
    expect(source, isNot(contains('start: _day(_selectedDate)')));
    expect(
      source,
      isNot(
        contains(
          'end: _day(_selectedDate).add(Duration(days: _agendaLoadedDays))',
        ),
      ),
    );
  });

  test('explicit date commands open the day view, not agenda', () {
    final source = File(
      'lib/src/features/schedule/presentation/schedule_workspace.dart',
    ).readAsStringSync();

    expect(source, contains('void _openCommandDate(DateTime? date)'));
    expect(source, contains('_mode = ScheduleViewMode.day'));
    expect(source, contains('_lastSettingsMode = ScheduleViewMode.day'));
    expect(source, contains('.setScheduleViewMode(ScheduleViewMode.day)'));
  });

  test('agenda removes page controls from toolbar and native headerbar', () {
    final workspace = File(
      'lib/src/features/schedule/presentation/schedule_workspace.dart',
    ).readAsStringSync();
    final toolbar = File(
      'lib/src/features/schedule/presentation/schedule_toolbar.dart',
    ).readAsStringSync();
    final headerService = File(
      'lib/src/platform/linux_header_bar_service.dart',
    ).readAsStringSync();
    final nativeRunner = File(
      'linux/runner/my_application.cc',
    ).readAsStringSync();

    expect(
      toolbar,
      contains('final showPaging = mode != ScheduleViewMode.agenda'),
    );
    expect(toolbar, contains('if (showPaging)'));
    expect(
      toolbar,
      contains('ScheduleViewMode.agenda => context.l10n.viewAgenda'),
    );
    expect(
      workspace,
      contains('navigationVisible: _mode != ScheduleViewMode.agenda'),
    );
    expect(
      workspace,
      contains('_headerBarSession.updateState(headerBarState)'),
    );
    expect(headerService, contains('class BusyMaxHeaderBarState'));
    expect(headerService, contains('class LinuxHeaderBarSession'));
    expect(headerService, contains('Future<void> updateState('));
    expect(nativeRunner, contains('set_header_bar_state'));
    expect(nativeRunner, contains('set_header_navigation_visible'));
    expect(nativeRunner, contains('setNavigationVisible'));
  });

  test('agenda queries bounded buckets separately from dated items', () {
    final source = File(
      'lib/src/features/schedule/presentation/schedule_workspace.dart',
    ).readAsStringSync();

    expect(source, contains('Future<_ScheduleItemsResult> _scheduleItems'));
    expect(source, contains('final currentItems = repository.listItems'));
    expect(
      source,
      contains(
        'showNoDateTasks: searchHasQuery || _mode != ScheduleViewMode.agenda',
      ),
    );
    expect(
      source,
      contains('final overdueTasks = repository.listOverdueTasks'),
    );
    expect(source, contains('before: range.start'));
    expect(source, contains('limit: _agendaOverdueTaskLimit'));
    expect(source, contains('final noDateTasks = repository.listNoDateTasks'));
    expect(source, contains('limit: _agendaNoDateTaskLimit'));
    expect(source, contains('showCompletedTasks: false'));
    expect(source, contains('hasMoreOverdueTasks: overduePage.hasMore'));
    expect(source, contains('hasMoreNoDateTasks: noDatePage.hasMore'));
    expect(source, contains('List<ScheduleItem> _agendaItems'));
    expect(source, contains('if (item is CalendarScheduleItem)'));
    expect(
      source,
      contains('return ScheduleProjection.intersects(item, range);'),
    );
    expect(source, contains('if (item is TaskScheduleItem)'));
    expect(source, contains('return !item.completed;'));
  });

  test('agenda task markers use task list icons, not checkbox icons', () {
    final agenda = File(
      'lib/src/features/schedule/presentation/schedule_agenda_view.dart',
    ).readAsStringSync();
    final compactAgenda = File(
      'lib/src/features/schedule/presentation/compact_agenda_panel.dart',
    ).readAsStringSync();

    expect(agenda, contains('isTask ? YaruIcons.task_list'));
    expect(compactAgenda, contains('isTask ? YaruIcons.task_list'));
    expect(agenda, contains('YaruCheckbox('));
    expect(compactAgenda, contains('YaruCheckbox('));
    expect(agenda, isNot(contains('selectedColor:')));
    expect(compactAgenda, isNot(contains('selectedColor:')));
    expect(agenda, isNot(contains('checkmarkColor:')));
    expect(compactAgenda, isNot(contains('checkmarkColor:')));
    expect(agenda, isNot(contains('YaruCheckboxTheme')));
    expect(compactAgenda, isNot(contains('YaruCheckboxTheme')));
    expect(agenda, isNot(contains('YaruIcons.checkbox')));
    expect(compactAgenda, isNot(contains('YaruIcons.checkbox')));
  });

  test(
    'event editor receives calendar event time zones from schedule item',
    () {
      final workspace = File(
        'lib/src/features/schedule/presentation/schedule_workspace.dart',
      ).readAsStringSync();
      final scheduleItem = File(
        'lib/src/schedule/schedule_item.dart',
      ).readAsStringSync();
      final repository = File(
        'lib/src/schedule/schedule_repository.dart',
      ).readAsStringSync();

      expect(scheduleItem, contains('final String? startTimeZone;'));
      expect(scheduleItem, contains('final String? endTimeZone;'));
      expect(repository, contains('startTimeZone: event.startTimeZone'));
      expect(repository, contains('endTimeZone: event.endTimeZone'));
      expect(workspace, contains('startTimeZone: item.startTimeZone'));
      expect(workspace, contains('endTimeZone: item.endTimeZone'));
    },
  );

  test('year mode uses existing schedule primitives', () {
    final mode = File(
      'lib/src/schedule/schedule_view_mode.dart',
    ).readAsStringSync();
    final range = File(
      'lib/src/schedule/schedule_range.dart',
    ).readAsStringSync();
    final workspace = File(
      'lib/src/features/schedule/presentation/schedule_workspace.dart',
    ).readAsStringSync();
    final yearView = File(
      'lib/src/features/schedule/presentation/schedule_year_view.dart',
    ).readAsStringSync();

    expect(mode, contains('year'));
    expect(range, contains('factory ScheduleRange.year(DateTime day)'));
    expect(workspace, contains('ScheduleRange.year(_selectedDate)'));
    expect(workspace, contains('DateFormat.y(locale).format(selectedDate)'));
    expect(workspace, contains('ScheduleYearView('));
    expect(yearView, contains('ScheduleProjection.groupByDay(items)'));
    expect(yearView, contains('ScheduleProjection.colorForItem'));
    expect(yearView, contains('final monthWidth ='));
    expect(yearView, contains('_monthPanelHeight(monthWidth)'));
    expect(yearView, contains('mainAxisExtent: monthHeight'));
    expect(yearView, contains('ColoredBox('));
    expect(yearView, contains('color: Theme.of(context).colorScheme.surface'));
    expect(yearView, contains('double _monthPanelHeight(double width)'));
    expect(yearView, contains('BusyMaxGroupedSurface('));
    expect(yearView, isNot(contains('BusyMaxSurfaceColors.of(context).card')));
    expect(yearView, contains('BusyMaxActionRow('));
    expect(yearView, contains('class _YearMonthGrid'));
    expect(yearView, contains('mainAxisExtent: rowHeight'));
    expect(yearView, contains('final markerSize = math.min'));
    expect(yearView, contains('firstWeekday'));
    expect(yearView, contains('onMonthSelected(month)'));
    expect(yearView, isNot(contains('height: 142')));
    expect(yearView, isNot(contains('availableHeight')));
    expect(yearView, isNot(contains('borderColor')));
    expect(yearView, isNot(contains('RoundedRectangleBorder(')));
    expect(yearView, isNot(contains('TextButton(')));
  });

  test('month view uses visible full cell borders', () {
    final source = File(
      'lib/src/features/schedule/presentation/schedule_month_view.dart',
    ).readAsStringSync();

    expect(source, contains('colorScheme.onSurface.withValues'));
    expect(source, contains('Brightness.dark ? 0.06 : 0.10'));
    expect(source, contains('position: DecorationPosition.foreground'));
    expect(source, contains('left: BorderSide(color: border)'));
    expect(source, contains('bottom: row == rows - 1'));
  });
}

Future<({Uint8List bytes, int width})> _capturePixels(
  WidgetTester tester,
  GlobalKey key,
) async {
  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final image = (await tester.binding.runAsync<ui.Image>(boundary.toImage))!;
  try {
    final byteData = (await tester.binding.runAsync<ByteData?>(
      () => image.toByteData(format: ui.ImageByteFormat.rawStraightRgba),
    ))!;
    return (bytes: byteData.buffer.asUint8List(), width: image.width);
  } finally {
    image.dispose();
  }
}

Color _pixelAt(
  ({Uint8List bytes, int width}) pixels, {
  required int x,
  required int y,
}) {
  final offset = (y * pixels.width + x) * 4;
  return Color.fromARGB(
    pixels.bytes[offset + 3],
    pixels.bytes[offset],
    pixels.bytes[offset + 1],
    pixels.bytes[offset + 2],
  );
}

double _luminanceDistance(Color first, Color second) {
  return (first.computeLuminance() - second.computeLuminance()).abs();
}

List<ScheduleItem> _itemsFor(DateTime day) {
  return [
    CalendarScheduleItem(
      id: 'event:1',
      accountId: 'google:g',
      provider: TaskProvider.google,
      sourceId: 'calendar:primary',
      providerCalendarId: 'primary',
      title: 'Design review',
      allDay: false,
      start: DateTime(day.year, day.month, day.day, 9),
      end: DateTime(day.year, day.month, day.day, 10),
      colorHex: '#3584e4',
      sourceName: 'Work',
    ),
    TaskScheduleItem(
      id: 'task:1',
      accountId: 'microsoft:m',
      provider: TaskProvider.microsoft,
      sourceId: 'tasks:inbox',
      title: 'Submit report',
      completed: false,
      allDay: true,
      start: DateTime(day.year, day.month, day.day),
      end: DateTime(day.year, day.month, day.day + 1),
      sourceName: 'Inbox',
    ),
  ];
}

List<ScheduleItem> _sameSlotItemsFor(DateTime day) {
  final start = DateTime(day.year, day.month, day.day, 9);
  final end = DateTime(day.year, day.month, day.day, 10);
  return [
    CalendarScheduleItem(
      id: 'event:1',
      accountId: 'google:g',
      provider: TaskProvider.google,
      sourceId: 'calendar:primary',
      providerCalendarId: 'primary',
      title: 'Design review',
      allDay: false,
      start: start,
      end: end,
      colorHex: '#3584e4',
      sourceName: 'Work',
    ),
    CalendarScheduleItem(
      id: 'event:2',
      accountId: 'google:g',
      provider: TaskProvider.google,
      sourceId: 'calendar:primary',
      providerCalendarId: 'primary',
      title: 'Pairing session',
      allDay: false,
      start: start,
      end: end,
      colorHex: '#33d17a',
      sourceName: 'Work',
    ),
    TaskScheduleItem(
      id: 'task:1',
      accountId: 'microsoft:m',
      provider: TaskProvider.microsoft,
      sourceId: 'tasks:inbox',
      title: 'Submit report',
      completed: false,
      allDay: false,
      start: start,
      end: end,
      sourceName: 'Inbox',
    ),
    TaskScheduleItem(
      id: 'task:2',
      accountId: 'google:g',
      provider: TaskProvider.google,
      sourceId: 'tasks:inbox',
      title: 'Review notes',
      completed: false,
      allDay: false,
      start: start,
      end: end,
      sourceName: 'Inbox',
    ),
  ];
}

List<ScheduleItem> _manyAllDayItemsFor(DateTime day) {
  final start = DateTime(day.year, day.month, day.day);
  final end = start.add(const Duration(days: 1));
  return [
    for (var index = 0; index < 8; index++)
      TaskScheduleItem(
        id: 'all-day-task:$index',
        accountId: index.isEven ? 'google:g' : 'microsoft:m',
        provider: index.isEven ? TaskProvider.google : TaskProvider.microsoft,
        sourceId: 'tasks:inbox',
        title: 'All-day task ${index + 1}',
        completed: false,
        allDay: true,
        start: start,
        end: end,
        sourceName: 'Inbox',
      ),
  ];
}

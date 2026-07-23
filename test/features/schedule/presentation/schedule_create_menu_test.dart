import 'package:busymax/src/app/busymax_design.dart';
import 'package:busymax/src/features/schedule/presentation/schedule_create_menu.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../test_localized_app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('create chooser opens as an anchored menu popover', (
    tester,
  ) async {
    late BuildContext hostContext;
    late BuildContext anchorContext;
    await tester.pumpWidget(
      localizedTestApp(
        child: Scaffold(
          body: Builder(
            builder: (context) {
              hostContext = context;
              return Align(
                alignment: Alignment.topLeft,
                child: Padding(
                  padding: const EdgeInsets.all(80),
                  child: Builder(
                    builder: (context) {
                      anchorContext = context;
                      return const SizedBox.square(dimension: 32);
                    },
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );

    final result = showScheduleCreateMenu(
      context: hostContext,
      anchorContext: anchorContext,
      anchorPoint: const Offset(96, 96),
    );
    await tester.pumpAndSettle();

    expect(find.byType(Dialog), findsNothing);
    expect(find.byType(BusyMaxPopoverSurface), findsOneWidget);
    expect(find.byType(MenuItemButton), findsNWidgets(2));
    expect(find.text('Event'), findsOneWidget);
    expect(find.text('Task'), findsOneWidget);
    expect(
      tester.getRect(find.byType(BusyMaxPopoverSurface)).top,
      greaterThan(96),
    );
    final eventButton = tester.widget<MenuItemButton>(
      find.ancestor(
        of: find.text('Event'),
        matching: find.byType(MenuItemButton),
      ),
    );
    expect(eventButton.autofocus, isFalse);

    await tester.tap(find.text('Task'));
    await tester.pumpAndSettle();

    expect(await result, ScheduleCreateChoice.task);
  });

  testWidgets('create chooser disables unavailable creation kinds', (
    tester,
  ) async {
    late BuildContext hostContext;
    late BuildContext anchorContext;
    await tester.pumpWidget(
      localizedTestApp(
        child: Scaffold(
          body: Builder(
            builder: (context) {
              hostContext = context;
              return Center(
                child: Builder(
                  builder: (context) {
                    anchorContext = context;
                    return const SizedBox.square(dimension: 32);
                  },
                ),
              );
            },
          ),
        ),
      ),
    );

    final result = showScheduleCreateMenu(
      context: hostContext,
      anchorContext: anchorContext,
      canCreateEvent: false,
      canCreateTask: true,
    );
    await tester.pumpAndSettle();

    final eventButton = tester.widget<MenuItemButton>(
      find.ancestor(
        of: find.text('Event'),
        matching: find.byType(MenuItemButton),
      ),
    );
    final taskButton = tester.widget<MenuItemButton>(
      find.ancestor(
        of: find.text('Task'),
        matching: find.byType(MenuItemButton),
      ),
    );
    expect(eventButton.onPressed, isNull);
    expect(eventButton.autofocus, isFalse);
    expect(taskButton.onPressed, isNotNull);
    expect(taskButton.autofocus, isTrue);

    await tester.tap(find.text('Event'));
    await tester.pump();
    expect(find.byType(BusyMaxPopoverSurface), findsOneWidget);

    await tester.tap(find.text('Task'));
    await tester.pumpAndSettle();
    expect(await result, ScheduleCreateChoice.task);
  });

  testWidgets('keyboard chooser supports Escape and restores anchor focus', (
    tester,
  ) async {
    final focusNode = FocusNode();
    addTearDown(focusNode.dispose);
    late BuildContext hostContext;
    late BuildContext anchorContext;
    await tester.pumpWidget(
      localizedTestApp(
        child: Scaffold(
          body: Builder(
            builder: (context) {
              hostContext = context;
              return Builder(
                builder: (context) {
                  anchorContext = context;
                  return TextButton(
                    focusNode: focusNode,
                    onPressed: () {},
                    child: const Text('Anchor'),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
    focusNode.requestFocus();
    await tester.pump();

    final result = showScheduleCreateMenu(
      context: hostContext,
      anchorContext: anchorContext,
    );
    await tester.pumpAndSettle();

    final eventButton = tester.widget<MenuItemButton>(
      find.ancestor(
        of: find.text('Event'),
        matching: find.byType(MenuItemButton),
      ),
    );
    expect(eventButton.autofocus, isTrue);
    expect(focusNode.hasFocus, isFalse);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(await result, isNull);
    expect(find.byType(BusyMaxPopoverSurface), findsNothing);
    expect(focusNode.hasFocus, isTrue);
  });

  testWidgets('create chooser does not open without an available choice', (
    tester,
  ) async {
    late BuildContext hostContext;
    await tester.pumpWidget(
      localizedTestApp(
        child: Builder(
          builder: (context) {
            hostContext = context;
            return const SizedBox();
          },
        ),
      ),
    );

    final result = await showScheduleCreateMenu(
      context: hostContext,
      canCreateEvent: false,
      canCreateTask: false,
    );
    await tester.pump();

    expect(result, isNull);
    expect(find.byType(BusyMaxPopoverSurface), findsNothing);
  });

  test('single available creation kind is resolved for direct creation', () {
    expect(
      singleAvailableScheduleCreateChoice(
        canCreateEvent: true,
        canCreateTask: false,
      ),
      ScheduleCreateChoice.event,
    );
    expect(
      singleAvailableScheduleCreateChoice(
        canCreateEvent: false,
        canCreateTask: true,
      ),
      ScheduleCreateChoice.task,
    );
    expect(
      singleAvailableScheduleCreateChoice(
        canCreateEvent: true,
        canCreateTask: true,
      ),
      isNull,
    );
    expect(
      singleAvailableScheduleCreateChoice(
        canCreateEvent: false,
        canCreateTask: false,
      ),
      isNull,
    );
  });
}

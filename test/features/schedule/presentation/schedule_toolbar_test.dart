import 'package:busymax/src/features/schedule/presentation/schedule_toolbar.dart';
import 'package:busymax/src/schedule/schedule_range.dart';
import 'package:busymax/src/schedule/schedule_view_mode.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yaru/yaru.dart';

import '../../../test_localized_app.dart';

void main() {
  testWidgets('fallback toolbar exposes the complete shell command set', (
    tester,
  ) async {
    var sidebarToggles = 0;
    var searches = 0;
    var events = 0;
    var tasks = 0;
    ScheduleViewMode? selectedMode;
    ScheduleToolbarMenuAction? selectedMenuAction;

    await tester.pumpWidget(
      localizedTestApp(
        child: Scaffold(
          body: SizedBox(
            width: 1000,
            child: ScheduleToolbar(
              mode: ScheduleViewMode.week,
              range: ScheduleRange.week(DateTime(2026, 7, 22)),
              selectedDate: DateTime(2026, 7, 22),
              onToday: () {},
              onPrevious: () {},
              onNext: () {},
              onModeChanged: (value) => selectedMode = value,
              canCreateEvent: true,
              canCreateTask: true,
              onCreateEvent: () => events++,
              onCreateTask: () => tasks++,
              onRefresh: () {},
              canShowSidebar: true,
              sidebarVisible: true,
              onToggleSidebar: () => sidebarToggles++,
              onSearch: () => searches++,
              onMenuSelected: (value) => selectedMenuAction = value,
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byTooltip('Toggle Sidebar'));
    await tester.tap(find.byTooltip('Search'));
    expect(sidebarToggles, 1);
    expect(searches, 1);

    await tester.tap(find.byTooltip('Create'));
    await tester.pumpAndSettle();
    expect(find.text('Event'), findsOneWidget);
    expect(find.text('Task'), findsOneWidget);
    await tester.tap(find.text('Event'));
    await tester.pumpAndSettle();
    expect(events, 1);
    expect(tasks, 0);

    await tester.tap(find.byTooltip('Week'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Month'));
    await tester.pumpAndSettle();
    expect(selectedMode, ScheduleViewMode.month);

    await tester.tap(find.byTooltip('Main Menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    expect(selectedMenuAction, ScheduleToolbarMenuAction.settings);
  });

  testWidgets('compact fallback moves refresh into the main menu', (
    tester,
  ) async {
    var refreshes = 0;
    ScheduleToolbarMenuAction? selectedMenuAction;

    await tester.pumpWidget(
      localizedTestApp(
        child: Scaffold(
          body: SizedBox(
            width: 700,
            child: ScheduleToolbar(
              mode: ScheduleViewMode.agenda,
              range: ScheduleRange.day(DateTime(2026, 7, 22)),
              selectedDate: DateTime(2026, 7, 22),
              onToday: () {},
              onPrevious: () {},
              onNext: () {},
              onModeChanged: (_) {},
              canCreateEvent: true,
              canCreateTask: true,
              onCreateEvent: () {},
              onCreateTask: () {},
              onRefresh: () => refreshes++,
              onMenuSelected: (value) {
                selectedMenuAction = value;
                if (value == ScheduleToolbarMenuAction.refresh) {
                  refreshes++;
                }
              },
            ),
          ),
        ),
      ),
    );

    expect(find.byTooltip('Refresh all'), findsNothing);
    await tester.tap(find.byTooltip('Main Menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Refresh all'));
    await tester.pumpAndSettle();

    expect(selectedMenuAction, ScheduleToolbarMenuAction.refresh);
    expect(refreshes, 1);
  });

  testWidgets('create menu keeps equal choices neutral and capability-aware', (
    tester,
  ) async {
    var events = 0;
    var tasks = 0;

    await tester.pumpWidget(
      localizedTestApp(
        child: Scaffold(
          body: SizedBox(
            width: 1000,
            child: ScheduleToolbar(
              mode: ScheduleViewMode.week,
              range: ScheduleRange.week(DateTime(2026, 7, 22)),
              selectedDate: DateTime(2026, 7, 22),
              onToday: () {},
              onPrevious: () {},
              onNext: () {},
              onModeChanged: (_) {},
              canCreateEvent: false,
              canCreateTask: true,
              onCreateEvent: () => events++,
              onCreateTask: () => tasks++,
              onRefresh: () {},
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byTooltip('Create'));
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
    expect(taskButton.onPressed, isNotNull);
    expect(
      eventButton.style?.backgroundColor?.resolve({}),
      taskButton.style?.backgroundColor?.resolve({}),
    );
    expect(eventButton.style?.backgroundColor?.resolve({}), Colors.transparent);
    expect(taskButton.style?.backgroundColor?.resolve({}), Colors.transparent);

    await tester.tap(find.text('Task'));
    await tester.pumpAndSettle();
    expect(events, 0);
    expect(tasks, 1);
  });

  testWidgets('external controller opens the fallback create menu', (
    tester,
  ) async {
    final controller = MenuController();

    await tester.pumpWidget(
      localizedTestApp(
        child: Scaffold(
          body: SizedBox(
            width: 1000,
            child: ScheduleToolbar(
              mode: ScheduleViewMode.week,
              range: ScheduleRange.week(DateTime(2026, 7, 22)),
              selectedDate: DateTime(2026, 7, 22),
              onToday: () {},
              onPrevious: () {},
              onNext: () {},
              onModeChanged: (_) {},
              canCreateEvent: true,
              canCreateTask: true,
              onCreateEvent: () {},
              onCreateTask: () {},
              onRefresh: () {},
              createMenuController: controller,
            ),
          ),
        ),
      ),
    );

    controller.open();
    await tester.pumpAndSettle();

    expect(find.text('Event'), findsOneWidget);
    expect(find.text('Task'), findsOneWidget);

    final trigger = tester.widget<YaruIconButton>(
      find.ancestor(
        of: find.byTooltip('Create'),
        matching: find.byType(YaruIconButton),
      ),
    );
    final anchor = tester.widget<MenuAnchor>(
      find.ancestor(
        of: find.byTooltip('Create'),
        matching: find.byType(MenuAnchor),
      ),
    );
    expect(trigger.focusNode, isNotNull);
    expect(anchor.childFocusNode, same(trigger.focusNode));

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('Event'), findsNothing);
    expect(find.text('Task'), findsNothing);
  });

  testWidgets('create trigger disables when no creation kind is available', (
    tester,
  ) async {
    await tester.pumpWidget(
      localizedTestApp(
        child: Scaffold(
          body: SizedBox(
            width: 1000,
            child: ScheduleToolbar(
              mode: ScheduleViewMode.week,
              range: ScheduleRange.week(DateTime(2026, 7, 22)),
              selectedDate: DateTime(2026, 7, 22),
              onToday: () {},
              onPrevious: () {},
              onNext: () {},
              onModeChanged: (_) {},
              canCreateEvent: false,
              canCreateTask: false,
              onCreateEvent: () {},
              onCreateTask: () {},
              onRefresh: () {},
            ),
          ),
        ),
      ),
    );

    final trigger = tester.widget<YaruIconButton>(
      find.ancestor(
        of: find.byTooltip('Create'),
        matching: find.byType(YaruIconButton),
      ),
    );
    expect(trigger.onPressed, isNull);
    await tester.tap(find.byTooltip('Create'));
    await tester.pumpAndSettle();
    expect(find.text('Event'), findsNothing);
    expect(find.text('Task'), findsNothing);
  });
}

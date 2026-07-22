import 'package:busymax/src/features/schedule/presentation/schedule_toolbar.dart';
import 'package:busymax/src/schedule/schedule_range.dart';
import 'package:busymax/src/schedule/schedule_view_mode.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../test_localized_app.dart';

void main() {
  testWidgets('fallback toolbar exposes the complete shell command set', (
    tester,
  ) async {
    var sidebarToggles = 0;
    var searches = 0;
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
              canCreate: true,
              onCreate: () {},
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
              canCreate: true,
              onCreate: () {},
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
}

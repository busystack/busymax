import 'dart:async';

import 'package:busymax/l10n/generated/app_localizations.dart';
import 'package:busymax/src/android/presentation/android_schedule_screen.dart';
import 'package:busymax/src/app/app_bootstrap.dart';
import 'package:busymax/src/app/busymax_design.dart';
import 'package:busymax/src/calendar_providers/calendar_sync_dto.dart';
import 'package:busymax/src/db/app_database.dart';
import 'package:busymax/src/features/accounts/data/accounts_repository.dart';
import 'package:busymax/src/features/calendar/data/calendar_repository.dart';
import 'package:busymax/src/features/schedule/presentation/schedule_agenda_view.dart';
import 'package:busymax/src/features/schedule/presentation/schedule_month_view.dart';
import 'package:busymax/src/features/schedule/presentation/schedule_search_filters.dart';
import 'package:busymax/src/features/schedule/presentation/schedule_sidebar.dart';
import 'package:busymax/src/features/schedule/presentation/schedule_workspace.dart';
import 'package:busymax/src/features/task_lists/data/task_lists_repository.dart';
import 'package:busymax/src/features/tasks/data/tasks_repository.dart';
import 'package:busymax/src/l10n/week_preferences_scope.dart';
import 'package:busymax/src/providers/busy_provider.dart';
import 'package:busymax/src/schedule/schedule_filters.dart';
import 'package:busymax/src/schedule/schedule_repository.dart';
import 'package:busymax/src/schedule/schedule_range.dart';
import 'package:busymax/src/schedule/schedule_search_criteria.dart';
import 'package:busymax/src/schedule/schedule_view_mode.dart';
import 'package:busymax/src/ui/windows/windows_schedule_page.dart';
import 'package:busymax/src/ui/windows/windows_schedule_search_pane.dart';
import 'package:busymax/src/ui/windows/windows_schedule_source_pane.dart';
import 'package:drift/drift.dart' hide Column, isNull, isNotNull;
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:yaru/yaru.dart';
import 'package:busymax/src/android/presentation/android_schedule_search_filters.dart';
import 'package:busymax/src/features/connectivity/network_connectivity_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

import '../../../support/memory_settings_store.dart';
import '../../../test_localized_app.dart';

void main() {
  testWidgets(
    'Windows delayed normal query cannot rebuild the retained side as search',
    (tester) async {
      final normalRefresh = Completer<void>();
      final refreshStarted = Completer<void>();
      addTearDown(() {
        if (!normalRefresh.isCompleted) normalRefresh.complete();
      });
      var coverageCalls = 0;
      final fixture = await _mount(
        tester,
        'windows',
        ensureProjectionCoverage: (_) async {
          coverageCalls += 1;
          if (coverageCalls == 2) {
            refreshStarted.complete();
            await normalRefresh.future;
          }
        },
      );
      await tester.pumpAndSettle();
      final planner = find.byType(WindowsScheduleMonthView);
      final plannerScrollable = find
          .descendant(of: planner, matching: find.byType(Scrollable))
          .first;
      final originalPlannerState = tester.state<ScrollableState>(
        plannerScrollable,
      );

      final event = await fixture.db
          .select(fixture.db.calendarEvents)
          .getSingle();
      await (fixture.db.update(
        fixture.db.calendarEvents,
      )..where((row) => row.id.equals(event.id))).write(
        const CalendarEventsCompanion(title: Value('Refresh in progress')),
      );
      for (
        var attempt = 0;
        attempt < 20 && !refreshStarted.isCompleted;
        attempt++
      ) {
        await tester.pump(const Duration(milliseconds: 10));
        await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      }
      expect(refreshStarted.isCompleted, isTrue);
      await tester.pump();
      expect(
        tester
            .stateList<ScrollableState>(
              find.descendant(
                of: find.byType(WindowsScheduleMonthView),
                matching: find.byType(Scrollable),
              ),
            )
            .any((state) => identical(state, originalPlannerState)),
        isTrue,
        reason: 'starting a replacement query must retain the planner',
      );
      await _searchShortcut(tester);
      await tester.pumpAndSettle();
      expect(find.byType(WindowsScheduleSearchPane), findsOneWidget);
      expect(
        find.byType(WindowsScheduleMonthView, skipOffstage: false),
        findsOneWidget,
      );
      expect(
        tester
            .stateList<ScrollableState>(
              find.descendant(
                of: find.byType(WindowsScheduleMonthView, skipOffstage: false),
                matching: find.byType(Scrollable, skipOffstage: false),
                skipOffstage: false,
              ),
            )
            .any((state) => identical(state, originalPlannerState)),
        isTrue,
      );

      normalRefresh.complete();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));
      expect(
        tester
            .stateList<ScrollableState>(
              find.descendant(
                of: find.byType(WindowsScheduleMonthView, skipOffstage: false),
                matching: find.byType(Scrollable, skipOffstage: false),
                skipOffstage: false,
              ),
            )
            .any((state) => identical(state, originalPlannerState)),
        isTrue,
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byType(WindowsScheduleMonthView), findsOneWidget);
      expect(
        tester.state<ScrollableState>(plannerScrollable),
        same(originalPlannerState),
      );
    },
  );

  testWidgets(
    'Windows empty Agenda keeps Load more and reveals the following horizon',
    (tester) async {
      final eventDate = DateTime.now().add(const Duration(days: 40));
      await _mount(
        tester,
        'windows',
        scheduleMode: ScheduleViewMode.agenda,
        seedSearchItems: false,
        additionalEventDate: eventDate,
      );
      await tester.pumpAndSettle();

      expect(find.text('Following horizon meeting'), findsNothing);
      final loadMore = find.text('Load more agenda items');
      expect(loadMore, findsOneWidget);
      await tester.tap(loadMore);
      await tester.pumpAndSettle();

      expect(find.text('Following horizon meeting'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  for (final platform in ['linux', 'windows']) {
    testWidgets(
      '$platform search swaps sidebar, lists all local matches, keeps temporary sources and restores Month',
      (tester) async {
        final fixture = await _mount(tester, platform);
        await tester.pumpAndSettle();
        final normal = platform == 'linux'
            ? find.byType(ScheduleSidebar)
            : find.byType(WindowsScheduleSourcePane);
        expect(normal, findsOneWidget);
        await _searchShortcut(tester);
        expect(normal, findsNothing);
        final panelFinder = platform == 'linux'
            ? find.byType(ScheduleSearchFilters)
            : find.byType(WindowsScheduleSearchPane);
        expect(panelFinder, findsOneWidget);
        final list = find.byKey(
          ValueKey(
            platform == 'linux'
                ? 'schedule-search-results'
                : 'windows-search-results',
          ),
        );
        expect(list, findsOneWidget);
        expect(find.text('Far future review'), findsOneWidget);
        expect(find.text('No due task'), findsOneWidget);
        expect(
          find.text(DateFormat.yMMMMEEEEd('en').format(DateTime(2040, 2, 15))),
          findsOneWidget,
        );
        if (platform == 'linux') {
          expect(find.byType(BusyMaxSidebarSurface), findsOneWidget);
          expect(
            find.byKey(const ValueKey('linux-native-search-filter-spacer')),
            findsNothing,
          );
          expect(
            tester
                .widget<ScheduleAgendaView>(find.byType(ScheduleAgendaView))
                .searchCriteria,
            isNotNull,
          );
        }
        ScheduleSearchCriteria criteria() => platform == 'linux'
            ? tester.widget<ScheduleSearchFilters>(panelFinder).value
            : tester.widget<WindowsScheduleSearchPane>(panelFinder).value;
        void change(ScheduleSearchCriteria value) {
          if (platform == 'linux') {
            tester.widget<ScheduleSearchFilters>(panelFinder).onChanged(value);
          } else {
            tester
                .widget<WindowsScheduleSearchPane>(panelFinder)
                .onChanged(value);
          }
        }

        final initial = criteria();
        change(
          criteria().copyWith(
            type: ScheduleSearchType.tasks,
            taskCompletion: ScheduleTaskCompletion.open,
            taskDueState: ScheduleTaskDueState.overdue,
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Overdue task'), findsOneWidget);
        expect(find.text('Completed task'), findsNothing);
        expect(find.text('No due task'), findsNothing);
        expect(find.text('Far future review'), findsNothing);
        // Exercise the actual source switch, then verify repository/settings
        // stayed intact.
        final checkbox = platform == 'linux'
            ? find
                  .descendant(
                    of: panelFinder,
                    matching: find.byType(YaruSwitchListTile),
                  )
                  .first
            : find
                  .descendant(
                    of: panelFinder,
                    matching: find.byType(fluent.Checkbox),
                  )
                  .first;
        await tester.ensureVisible(checkbox);
        await tester.tap(checkbox);
        await tester.pumpAndSettle();
        expect(criteria().taskListKeys, isEmpty);
        expect(find.text('Overdue task'), findsNothing);
        expect(
          fixture.container
              .read(appSettingsControllerProvider)
              .isTaskListVisibleInSchedule('account', 'list'),
          isTrue,
        );
        expect(
          (await fixture.db.select(fixture.db.calendarSources).getSingle())
              .selected,
          isTrue,
        );
        if (platform == 'linux') {
          tester.widget<ScheduleSearchFilters>(panelFinder).onClear();
        } else {
          tester.widget<WindowsScheduleSearchPane>(panelFinder).onClear();
        }
        await tester.pumpAndSettle();
        expect(criteria(), initial);
        final calendarToggle = platform == 'linux'
            ? find
                  .descendant(
                    of: panelFinder,
                    matching: find.byType(YaruSwitchListTile),
                  )
                  .first
            : find
                  .descendant(
                    of: panelFinder,
                    matching: find.byType(fluent.Checkbox),
                  )
                  .first;
        await tester.ensureVisible(calendarToggle);
        await tester.tap(calendarToggle);
        await tester.pumpAndSettle();
        expect(criteria().sourceIds, isEmpty);
        expect(
          (await fixture.db.select(fixture.db.calendarSources).getSingle())
              .selected,
          isTrue,
        );
        expect(find.text('Far future review'), findsNothing);
        await tester.tap(calendarToggle);
        await tester.pumpAndSettle();

        change(
          criteria().copyWith(
            type: ScheduleSearchType.events,
            person: 'alex@example.com',
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Far future review'), findsOneWidget);
        change(
          criteria().copyWith(
            date: ScheduleSearchDate.custom,
            customStart: DateTime(2040, 2, 15),
            customEnd: DateTime(2040, 2, 15),
            location: 'office',
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Far future review'), findsOneWidget);
        change(
          criteria().copyWith(
            customStart: DateTime(2040, 2, 16),
            customEnd: DateTime(2040, 2, 16),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Far future review'), findsNothing);
        change(criteria().copyWith(date: ScheduleSearchDate.any));
        await tester.pumpAndSettle();
        // Clearing only the entry retains Person and the temporary scope.
        final entry = platform == 'linux'
            ? find.descendant(
                of: find.byType(BusyMaxSearchField),
                matching: find.byType(TextField),
              )
            : find
                  .descendant(
                    of: find.byType(fluent.TextBox),
                    matching: find.byType(EditableText),
                  )
                  .last;
        await tester.enterText(entry, 'unmatched');
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pumpAndSettle();
        expect(find.text('Far future review'), findsNothing);
        await tester.enterText(entry, '');
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pumpAndSettle();
        expect(criteria().person, 'alex@example.com');
        expect(find.text('Far future review'), findsOneWidget);
        await tester.tap(find.text('Far future review'));
        await tester.pumpAndSettle();
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
        expect(panelFinder, findsOneWidget);
        expect(criteria().person, 'alex@example.com');

        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
        expect(normal, findsOneWidget);
        expect(panelFinder, findsNothing);
        expect(
          platform == 'linux'
              ? find.byType(ScheduleMonthView)
              : find.byType(WindowsScheduleMonthView),
          findsOneWidget,
        );
        expect(
          fixture.container
              .read(appSettingsControllerProvider)
              .scheduleViewMode,
          ScheduleViewMode.month,
        );
        expect(tester.takeException(), isNull);
      },
    );
    testWidgets(
      '$platform narrow search opens full filters through sidebar action',
      (tester) async {
        await _mount(tester, platform, width: 650);
        await tester.pumpAndSettle();
        await _searchShortcut(tester);
        expect(
          platform == 'linux'
              ? find.byType(ScheduleSearchFilters).hitTestable()
              : find.byType(WindowsScheduleSearchPane).hitTestable(),
          findsNothing,
        );
        await tester.sendKeyEvent(LogicalKeyboardKey.f9);
        await tester.pumpAndSettle();
        expect(
          platform == 'linux'
              ? find.byType(ScheduleSearchFilters).hitTestable()
              : find.byType(WindowsScheduleSearchPane).hitTestable(),
          findsOneWidget,
        );
        if (platform == 'linux') {
          final visibleFilters = find
              .byType(ScheduleSearchFilters)
              .hitTestable();
          expect(find.byType(BusyMaxDialogShell), findsOneWidget);
          expect(
            find.byType(BusyMaxSidebarSurface).hitTestable(),
            findsNothing,
          );
          expect(
            tester.widget<ScheduleSearchFilters>(visibleFilters).sidebar,
            isFalse,
          );
          Navigator.of(tester.element(visibleFilters)).pop();
          await tester.pumpAndSettle();
          expect(find.byType(BusyMaxDialogShell), findsNothing);
          expect(
            find.byType(ScheduleSearchFilters).hitTestable(),
            findsNothing,
          );
          expect(
            find.byKey(const ValueKey('schedule-search-results')),
            findsOneWidget,
          );

          await tester.sendKeyEvent(LogicalKeyboardKey.f9);
          await tester.pumpAndSettle();
          expect(find.byType(BusyMaxDialogShell), findsOneWidget);
          tester.view.physicalSize = const Size(1280, 900);
          await tester.pumpAndSettle();
          expect(find.byType(BusyMaxDialogShell), findsNothing);
          expect(find.byType(ScheduleSearchFilters), findsOneWidget);
          expect(
            find.byType(BusyMaxSidebarSurface).hitTestable(),
            findsOneWidget,
          );
        }
        expect(
          find.text('Custom range'),
          findsNothing,
        ); // available through Date selection, no second semantics
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'Android tune switches from ordinary sources to temporary search filters and empty query lists results',
    (tester) async {
      final fixture = await _mount(tester, 'android', width: 480);
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.tune));
      await tester.pumpAndSettle();
      expect(find.byType(AndroidScheduleSearchFilters), findsNothing);
      expect(find.byType(CheckboxListTile), findsWidgets);
      Navigator.of(tester.element(find.byType(CheckboxListTile).first)).pop();
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.search));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('android-search-results')),
        findsOneWidget,
      );
      expect(find.text('Far future review'), findsOneWidget);
      expect(
        find.text(DateFormat.yMMMMEEEEd('en').format(DateTime(2040, 2, 15))),
        findsOneWidget,
      );
      await tester.tap(find.byIcon(Icons.tune));
      await tester.pumpAndSettle();
      final panel = find.byType(AndroidScheduleSearchFilters);
      expect(panel, findsOneWidget);
      var widget = tester.widget<AndroidScheduleSearchFilters>(panel);
      final calendarToggle = find
          .descendant(of: panel, matching: find.byType(CheckboxListTile))
          .first;
      await tester.ensureVisible(calendarToggle);
      await tester.tap(calendarToggle);
      await tester.pumpAndSettle();
      expect(
        tester.widget<AndroidScheduleSearchFilters>(panel).value.sourceIds,
        isEmpty,
      );
      expect(
        (await fixture.db.select(fixture.db.calendarSources).getSingle())
            .selected,
        isTrue,
      );
      await tester.tap(calendarToggle);
      await tester.pumpAndSettle();
      widget = tester.widget<AndroidScheduleSearchFilters>(panel);

      widget.onChanged(
        widget.value.copyWith(
          type: ScheduleSearchType.tasks,
          taskDueState: ScheduleTaskDueState.noDueDate,
        ),
      );
      await tester.pumpAndSettle();
      widget = tester.widget<AndroidScheduleSearchFilters>(panel);
      final checkbox = find
          .descendant(of: panel, matching: find.byType(CheckboxListTile))
          .first;
      await tester.ensureVisible(checkbox);
      await tester.tap(checkbox);
      await tester.pumpAndSettle();
      expect(
        tester.widget<AndroidScheduleSearchFilters>(panel).value.taskListKeys,
        isEmpty,
      );
      expect(
        fixture.container
            .read(appSettingsControllerProvider)
            .isTaskListVisibleInSchedule('account', 'list'),
        isTrue,
      );
      await tester.tap(checkbox);
      await tester.pumpAndSettle();
      Navigator.of(tester.element(panel)).pop();
      await tester.pumpAndSettle();
      expect(find.text('No due task'), findsOneWidget);
      expect(find.text('Overdue task'), findsNothing);
      expect(
        find.byKey(const ValueKey('android-search-results')),
        findsOneWidget,
      );
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('android-search-results')),
        findsNothing,
      );
      expect(
        fixture.container
            .read(appSettingsControllerProvider)
            .androidScheduleViewMode,
        ScheduleViewMode.month,
      );
      expect(
        (await fixture.db.select(fixture.db.calendarSources).getSingle())
            .selected,
        isTrue,
      );
      expect(tester.takeException(), isNull);
    },
  );

  for (final reducedMotion in [false, true]) {
    testWidgets('Android search restores focus after reopening'
        '${reducedMotion ? ' with reduced motion' : ''}', (tester) async {
      if (reducedMotion) {
        tester.binding.platformDispatcher.accessibilityFeaturesTestValue =
            const FakeAccessibilityFeatures(disableAnimations: true);
        addTearDown(
          tester.binding.platformDispatcher.clearAccessibilityFeaturesTestValue,
        );
      }
      await _mount(tester, 'android', width: 480);
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.search));
      await tester.pumpAndSettle();
      final firstField = tester.widget<TextField>(find.byType(TextField));
      final focusNode = firstField.focusNode!;
      expect(focusNode.hasFocus, isTrue);

      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();
      expect(focusNode.hasFocus, isFalse);

      await tester.tap(find.byIcon(Icons.search));
      await tester.pumpAndSettle();
      final reopenedField = tester.widget<TextField>(find.byType(TextField));
      expect(reopenedField.focusNode, same(focusNode));
      expect(focusNode.hasFocus, isTrue);
    });
  }

  testWidgets('closing Android search cancels its scheduled focus request', (
    tester,
  ) async {
    await _mount(tester, 'android', width: 480);
    await tester.pumpAndSettle();
    var closedBeforeFocus = false;
    tester.binding.addPostFrameCallback((_) {
      final close = find.widgetWithIcon(IconButton, Icons.close);
      if (close.evaluate().length != 1) return;
      closedBeforeFocus = true;
      tester.widget<IconButton>(close).onPressed!();
    });

    await tester.tap(find.byIcon(Icons.search));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(closedBeforeFocus, isTrue);
    expect(find.byIcon(Icons.search), findsOneWidget);
    final retainedField = tester.widget<TextField>(
      find.byType(TextField, skipOffstage: false),
    );
    expect(retainedField.focusNode!.hasFocus, isFalse);
  });

  testWidgets(
    'Android confirms an open date filter with the latest system weekday',
    (tester) async {
      final systemWeekday = ValueNotifier<int?>(DateTime.monday);
      addTearDown(systemWeekday.dispose);
      await _mount(tester, 'android', width: 480, systemWeekday: systemWeekday);
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.search));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.tune));
      await tester.pumpAndSettle();

      final panel = find.byType(AndroidScheduleSearchFilters);
      var filters = tester.widget<AndroidScheduleSearchFilters>(panel);
      filters.onChanged(
        filters.value.copyWith(
          date: ScheduleSearchDate.custom,
          customStart: filters.value.referenceDate,
          customEnd: filters.value.referenceDate,
        ),
      );
      await tester.pumpAndSettle();

      final startDate = find
          .descendant(of: panel, matching: find.byType(OutlinedButton))
          .first;
      await tester.ensureVisible(startDate);
      await tester.tap(startDate);
      await tester.pumpAndSettle();
      expect(find.byType(DatePickerDialog), findsOneWidget);

      systemWeekday.value = DateTime.sunday;
      await tester.pump();
      await tester.tap(find.text('OK').last);
      await tester.pumpAndSettle();

      filters = tester.widget<AndroidScheduleSearchFilters>(panel);
      expect(filters.value.firstWeekday, DateTime.sunday);
      filters.onChanged(
        filters.value.copyWith(date: ScheduleSearchDate.thisWeek),
      );
      await tester.pumpAndSettle();
      filters = tester.widget<AndroidScheduleSearchFilters>(panel);
      expect(filters.value.range?.start.weekday, DateTime.sunday);

      filters.onClear();
      await tester.pumpAndSettle();
      expect(
        tester.widget<AndroidScheduleSearchFilters>(panel).value.firstWeekday,
        DateTime.sunday,
      );
    },
  );

  testWidgets('Windows compact mini-calendar tracks an open system change', (
    tester,
  ) async {
    final systemWeekday = ValueNotifier<int?>(DateTime.monday);
    addTearDown(systemWeekday.dispose);
    await _mount(tester, 'windows', width: 650, systemWeekday: systemWeekday);
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.f9);
    await tester.pumpAndSettle();
    final pane = find.byType(WindowsScheduleSourcePane).hitTestable();
    expect(pane, findsOneWidget);
    expect(
      tester.widget<WindowsScheduleSourcePane>(pane).firstWeekday,
      DateTime.monday,
    );

    systemWeekday.value = DateTime.sunday;
    await tester.pump();

    expect(
      tester.widget<WindowsScheduleSourcePane>(pane).firstWeekday,
      DateTime.sunday,
    );
  });
}

Future<void> _searchShortcut(WidgetTester tester) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
  await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
  await tester.pumpAndSettle();
}

Future<({AppDatabase db, ProviderContainer container})> _mount(
  WidgetTester tester,
  String platform, {
  double width = 1280,
  ValueListenable<int?>? systemWeekday,
  Future<void> Function(ScheduleRange range)? ensureProjectionCoverage,
  ScheduleViewMode scheduleMode = ScheduleViewMode.month,
  bool seedSearchItems = true,
  DateTime? additionalEventDate,
}) async {
  tester.view
    ..physicalSize = Size(width, 900)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final db = AppDatabase.memoryForTests();
  final calendar = CalendarRepository(database: db);
  const now = '2026-01-01T00:00:00.000Z';
  await db
      .into(db.accounts)
      .insert(
        AccountsCompanion.insert(
          id: 'account',
          provider: 'google',
          authority: 'https://accounts.google.com',
          providerAccountId: 'alex',
          credentialKind: 'oauth',
          authState: const Value('signed_in'),
          email: const Value('alex@example.com'),
          createdAtUtc: now,
          updatedAtUtc: now,
        ),
      );
  await db.taskListsDao.upsertTaskList(
    TaskListsCompanion.insert(
      accountId: 'account',
      id: 'list',
      title: 'Work tasks',
      rawJson: '{}',
      createdLocalAtUtc: now,
      updatedLocalAtUtc: now,
    ),
  );
  await calendar.upsertSource(
    accountId: 'account',
    source: const CalendarSourceDto(
      provider: BusyProvider.google,
      providerCalendarId: 'calendar',
      summary: 'Work calendar',
    ),
  );
  if (seedSearchItems) {
    await calendar.upsertEvent(
      accountId: 'account',
      event: const CalendarEventDto(
        provider: BusyProvider.google,
        providerCalendarId: 'calendar',
        providerEventId: 'far',
        title: 'Far future review',
        allDay: true,
        startDate: '2040-02-15',
        endDate: '2040-02-16',
        location: 'Office',
        attendeesJson: [
          {'email': 'alex@example.com'},
        ],
      ),
    );
    for (final entry in [
      ('overdue', 'Overdue task', '2020-01-01', 'needsAction'),
      ('done', 'Completed task', '2020-01-01', 'completed'),
      ('undated', 'No due task', null, 'needsAction'),
    ]) {
      await db.tasksDao.upsertTask(
        TasksCompanion.insert(
          accountId: 'account',
          taskListId: 'list',
          id: entry.$1,
          title: entry.$2,
          dueUtc: Value(entry.$3),
          status: Value(entry.$4),
          taskLocation: const Value('Office'),
          rawJson: '{}',
          createdLocalAtUtc: now,
          updatedLocalAtUtc: now,
        ),
      );
    }
  }
  if (additionalEventDate != null) {
    final startDate = DateFormat('yyyy-MM-dd').format(additionalEventDate);
    final endDate = DateFormat(
      'yyyy-MM-dd',
    ).format(additionalEventDate.add(const Duration(days: 1)));
    await calendar.upsertEvent(
      accountId: 'account',
      event: CalendarEventDto(
        provider: BusyProvider.google,
        providerCalendarId: 'calendar',
        providerEventId: 'following-horizon',
        title: 'Following horizon meeting',
        allDay: true,
        startDate: startDate,
        endDate: endDate,
      ),
    );
  }
  final container = ProviderContainer(
    overrides: [
      networkAvailabilityProvider.overrideWith(
        (ref) => Stream.value(NetworkAvailability.online),
      ),
      databaseProvider.overrideWithValue(db),
      localTimeZoneProvider.overrideWithValue('UTC'),
      localSettingsStoreProvider.overrideWithValue(MemorySettingsStore()),
      initialAppSettingsProvider.overrideWithValue(
        AppSettings.defaults().copyWith(
          scheduleViewMode: scheduleMode,
          androidScheduleViewMode: ScheduleViewMode.month,
        ),
      ),
      accountsRepositoryProvider.overrideWithValue(
        AccountsRepository(database: db),
      ),
      calendarRepositoryProvider.overrideWithValue(calendar),
      scheduleRepositoryProvider.overrideWithValue(
        ScheduleRepository(
          db,
          ensureProjectionCoverage: ensureProjectionCoverage,
        ),
      ),
      taskListsRepositoryForAccountProvider.overrideWith(
        (ref, id) => TaskListsRepository(database: db, accountId: id),
      ),
      tasksRepositoryForAccountProvider.overrideWith(
        (ref, id) => TasksRepository(database: db, accountId: id),
      ),
    ],
  );
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    container.dispose();
    await db.close();
  });
  final platformApp = platform == 'windows'
      ? fluent.FluentApp(
          localizationsDelegates: const [AppLocalizations.delegate],
          supportedLocales: AppLocalizations.supportedLocales,
          home: const WindowsSchedulePage(),
        )
      : localizedTestApp(
          child: platform == 'linux'
              ? const ScheduleWorkspace()
              : const AndroidScheduleScreen(),
        );
  final app = systemWeekday == null
      ? platformApp
      : ValueListenableBuilder<int?>(
          valueListenable: systemWeekday,
          child: platformApp,
          builder: (context, value, child) => BusyMaxWeekPreferencesScope(
            preference: BusyMaxFirstDayOfWeekPreference.system,
            systemWeekday: value,
            platformLocaleTag: 'en-GB',
            child: child!,
          ),
        );
  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: app),
  );
  return (db: db, container: container);
}

import 'dart:async';

import 'package:busymax/l10n/generated/app_localizations.dart';
import 'package:busymax/src/android/presentation/android_schedule_screen.dart';
import 'package:busymax/src/android/presentation/android_schedule_search_filters.dart';
import 'package:busymax/src/app/app_bootstrap.dart';
import 'package:busymax/src/app/busymax_design.dart';
import 'package:busymax/src/app/busymax_yaru_theme.dart';
import 'package:busymax/src/calendar_providers/calendar_sync_dto.dart';
import 'package:busymax/src/db/app_database.dart';
import 'package:busymax/src/features/calendar/data/calendar_repository.dart';
import 'package:busymax/src/features/connectivity/network_connectivity_service.dart';
import 'package:busymax/src/features/schedule/presentation/schedule_day_week_view.dart'
    as linux;
import 'package:busymax/src/features/schedule/presentation/schedule_search_filters.dart';
import 'package:busymax/src/features/schedule/presentation/schedule_toolbar.dart';
import 'package:busymax/src/features/schedule/presentation/schedule_workspace.dart';
import 'package:busymax/src/features/sync/domain_sync_schedule.dart';
import 'package:busymax/src/features/sync/sync_request.dart';
import 'package:busymax/src/providers/busy_provider.dart';
import 'package:busymax/src/schedule/schedule_filters.dart';
import 'package:busymax/src/schedule/schedule_range.dart';
import 'package:busymax/src/schedule/schedule_repository.dart';
import 'package:busymax/src/schedule/schedule_search_criteria.dart';
import 'package:busymax/src/schedule/schedule_view_mode.dart';
import 'package:busymax/src/ui/common/schedule/schedule_day_week_view.dart';
import 'package:busymax/src/ui/windows/windows_schedule_day_week_view.dart';
import 'package:busymax/src/ui/windows/windows_schedule_page.dart';
import 'package:busymax/src/ui/windows/windows_schedule_search_pane.dart';
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:busymax/src/ui/common/flutter_material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yaru/yaru.dart';

import '../../../support/memory_settings_store.dart';
import '../../../test_localized_app.dart';

enum _Platform { linux, windows, android }

void main() {
  for (final platform in _Platform.values) {
    testWidgets(
      '${platform.name} warns only for incomplete displayed coverage',
      (tester) async {
        if (platform == _Platform.linux) {
          const windowChannel = MethodChannel('yaru_window');
          const windowEvents = EventChannel('yaru_window/events');
          final messenger = tester.binding.defaultBinaryMessenger;
          messenger.setMockMethodCallHandler(
            windowChannel,
            (call) async => call.method == 'state' ? <String, Object?>{} : null,
          );
          messenger.setMockStreamHandler(
            windowEvents,
            MockStreamHandler.inline(onListen: (_, _) {}),
          );
          addTearDown(() {
            messenger.setMockMethodCallHandler(windowChannel, null);
            messenger.setMockStreamHandler(windowEvents, null);
          });
        }
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = switch (platform) {
          _Platform.linux => const Size(680, 800),
          _Platform.windows => const Size(700, 800),
          _Platform.android => const Size(360, 800),
        };
        addTearDown(tester.view.reset);

        final db = AppDatabase.memoryForTests();
        final calls = <({ScheduleRange range, ScheduleFilters filters})>[];
        final syncRequests = <SyncRequest>[];
        final today = ScheduleRange.day(DateTime.now());
        var todayResult = Completer<bool>();
        final nextResult = Completer<bool>();
        var searchResult = Completer<bool>();
        final repository = ScheduleRepository(
          db,
          ensureCloudCoverage: (range, filters) {
            calls.add((range: range, filters: filters));
            if (filters.useTaskDueDate) return searchResult.future;
            if (range.end.difference(range.start) > const Duration(days: 2)) {
              return Future.value(true);
            }
            return (range.start == today.start ? todayResult : nextResult)
                .future;
          },
        );
        final container = ProviderContainer(
          overrides: [
            databaseProvider.overrideWithValue(db),
            initialAppSettingsProvider.overrideWithValue(
              AppSettings.defaults().copyWith(
                scheduleViewMode: ScheduleViewMode.day,
                androidScheduleViewMode: ScheduleViewMode.day,
              ),
            ),
            localSettingsStoreProvider.overrideWithValue(MemorySettingsStore()),
            networkConnectivityMonitorProvider.overrideWith((ref) {
              final monitor =
                  NetworkConnectivityMonitor.withoutPlatformObservation();
              ref.onDispose(monitor.dispose);
              return monitor;
            }),
            scheduleRepositoryProvider.overrideWithValue(repository),
            manualSyncRunnerProvider.overrideWithValue((
              scope, {
              strategy = SyncStrategy.ordinary,
            }) async {
              final request = (
                scope: scope,
                origin: SyncTrigger.manual,
                strategy: strategy,
              );
              syncRequests.add(request);
              return SyncOutcome(request, SyncDisposition.completed);
            }),
          ],
        );
        addTearDown(() async {
          await tester.pumpWidget(const SizedBox.shrink());
          container.dispose();
          await db.close();
        });
        await tester.runAsync(() async {
          await container
              .read(accountsRepositoryProvider)
              .upsertSignedInAccount(
                id: 'account',
                provider: BusyProvider.google,
                providerAccountId: 'test@example.test',
                displayName: 'Test account',
                grantedScopes: 'calendar',
              );
          final calendar = CalendarRepository(database: db);
          await calendar.upsertSource(
            accountId: 'account',
            source: const CalendarSourceDto(
              provider: BusyProvider.google,
              providerCalendarId: 'calendar',
              summary: 'Test calendar',
            ),
          );
          await calendar.upsertSource(
            accountId: 'account',
            source: const CalendarSourceDto(
              provider: BusyProvider.google,
              providerCalendarId: 'other',
              summary: 'Other calendar',
              selected: false,
            ),
          );
          await calendar.upsertEvent(
            accountId: 'account',
            event: CalendarEventDto(
              provider: BusyProvider.google,
              providerCalendarId: 'calendar',
              providerEventId: 'planning',
              title: 'Planning',
              allDay: true,
              startDate: today.start.toIso8601String().substring(0, 10),
              endDate: today.end.toIso8601String().substring(0, 10),
            ),
          );
        });
        final sourceId = CalendarRepository.sourceId(
          accountId: 'account',
          provider: BusyProvider.google,
          providerCalendarId: 'calendar',
        );
        final otherSourceId = CalendarRepository.sourceId(
          accountId: 'account',
          provider: BusyProvider.google,
          providerCalendarId: 'other',
        );
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: _app(platform),
          ),
        );
        await tester.pumpAndSettle();

        const label = 'Some events may be missing.';
        final warning = find.byKey(const ValueKey('schedule-coverage-warning'));
        final toolbar = find.byType(switch (platform) {
          _Platform.linux => ScheduleToolbar,
          _Platform.windows => fluent.PageHeader,
          _Platform.android => AppBar,
        });
        final calendar = find.byType(switch (platform) {
          _Platform.linux => linux.ScheduleDayWeekView,
          _Platform.windows => WindowsScheduleDayWeekView,
          _Platform.android => ScheduleDayWeekView,
        });
        final action = find.byKey(
          ValueKey(switch (platform) {
            _Platform.linux => 'schedule-search-button',
            _Platform.windows => 'windows-create-schedule-item',
            _Platform.android => 'android-workspace-menu',
          }),
        );
        List<Rect> bounds() => [
          toolbar,
          calendar,
          action,
          if (platform == _Platform.android) ...[
            find.byWidget(tester.widget<AppBar>(toolbar).title!),
            find.byTooltip('View'),
            _periodButton(platform, next: true),
          ],
        ].map(tester.getRect).toList();
        await _waitFor(tester, calendar);
        final normalBounds = bounds();
        expect(
          calls.where((call) => call.range.end == today.end).single.range.start,
          today.start,
        );
        expect(warning, findsNothing);
        expect(find.text('Planning'), findsWidgets);

        todayResult.complete(false);
        await _waitFor(tester, warning);
        expect(warning.hitTestable(), findsOneWidget);
        if (platform == _Platform.windows) {
          final tooltip = find.ancestor(
            of: warning,
            matching: find.byType(fluent.Tooltip),
          );
          expect(tester.widget<fluent.Tooltip>(tooltip).message, label);
        } else {
          expect(find.byTooltip(label), findsOneWidget);
        }
        final semantics = tester.ensureSemantics();
        try {
          await tester.pump();
          final data = tester.getSemantics(warning).getSemanticsData();
          expect(data.hasAction(SemanticsAction.tap), isTrue);
          expect([data.label, data.tooltip], contains(label));
        } finally {
          semantics.dispose();
        }
        expect(bounds(), normalBounds);
        expect(find.text('Planning'), findsWidgets);
        if (platform == _Platform.android) {
          expect(
            tester.getSize(warning).shortestSide,
            greaterThanOrEqualTo(48),
          );
        }

        await tester.tap(_periodButton(platform, next: true));
        await tester.pumpAndSettle();
        expect(calls.any((call) => call.range.start == today.end), isTrue);
        expect(warning, findsNothing);
        nextResult.complete(true);
        await tester.pumpAndSettle();
        expect(warning, findsNothing);
        await tester.tap(_periodButton(platform, next: false));
        await _waitFor(tester, warning);
        expect(warning, findsOneWidget);

        todayResult = Completer<bool>();
        await _retryWarning(tester, warning);
        expect(calls.last.range.start, today.start);
        expect(calls.last.range.end, today.end);
        expect(calls.last.filters.sourceIds, {sourceId});
        expect(calls.last.filters.sourceFilterActive, isTrue);
        expect(warning, findsNothing);
        todayResult.complete(true);
        await tester.pumpAndSettle();
        expect(warning, findsNothing);
        expect(bounds(), normalBounds);

        final settings = container.read(appSettingsControllerProvider.notifier);
        await settings.setAccountVisibleInSchedule(
          accountId: 'account',
          visible: false,
        );
        await tester.pumpAndSettle();
        expect(find.text('Planning'), findsNothing);
        expect(warning, findsNothing);
        await settings.setAccountVisibleInSchedule(
          accountId: 'account',
          visible: true,
        );
        await tester.pumpAndSettle();
        expect(find.text('Planning'), findsWidgets);

        final searchField = platform == _Platform.windows
            ? find.byType(fluent.TextBox)
            : find.descendant(of: toolbar, matching: find.byType(TextField));
        if (platform != _Platform.windows) {
          await tester.tap(
            platform == _Platform.linux ? action : find.byTooltip('Search'),
          );
          await tester.pumpAndSettle();
        }
        await tester.enterText(searchField, 'Planning');
        await tester.pumpAndSettle();
        expect(warning, findsNothing);
        if (platform == _Platform.windows) {
          final commands = tester.widget<fluent.CommandBar>(
            find.byType(fluent.CommandBar),
          );
          final filters = commands.primaryItems
              .whereType<fluent.CommandBarButton>()
              .singleWhere(
                (command) => (command.label as Text?)?.data == 'Filters',
              );
          filters.onPressed!();
        } else {
          await tester.tap(
            platform == _Platform.linux
                ? find.byKey(const ValueKey('schedule-search-filter-button'))
                : find.byTooltip('Filters'),
          );
        }
        await tester.pumpAndSettle();
        var panel = find.byType(switch (platform) {
          _Platform.linux => ScheduleSearchFilters,
          _Platform.windows => WindowsScheduleSearchPane,
          _Platform.android => AndroidScheduleSearchFilters,
        });
        if (platform != _Platform.android) {
          panel = find.descendant(
            of: find.byType(
              platform == _Platform.linux
                  ? BusyMaxDialogShell
                  : fluent.ContentDialog,
            ),
            matching: panel,
          );
        }
        final (criteria, update) = switch (tester.widget(panel)) {
          ScheduleSearchFilters(:final value, :final onChanged) => (
            value,
            onChanged,
          ),
          WindowsScheduleSearchPane(:final value, :final onChanged) => (
            value,
            onChanged,
          ),
          AndroidScheduleSearchFilters(:final value, :final onChanged) => (
            value,
            onChanged,
          ),
          final other => throw StateError(
            'Unexpected search filter panel: $other',
          ),
        };
        final bounded = criteria.copyWith(
          date: ScheduleSearchDate.thisWeek,
          type: ScheduleSearchType.events,
          location: 'Office',
          sourceIds: {otherSourceId},
        );
        update(bounded);
        Navigator.of(tester.element(panel)).pop();
        await tester.pumpAndSettle();
        final searchBounds = [toolbar, action].map(tester.getRect).toList();
        expect(warning, findsNothing);
        searchResult.complete(false);
        await tester.pumpAndSettle();
        expect(warning.hitTestable(), findsOneWidget);
        expect([toolbar, action].map(tester.getRect), searchBounds);
        if (platform == _Platform.android) {
          expect(
            tester.getSize(warning).shortestSide,
            greaterThanOrEqualTo(48),
          );
        }

        await settings.setAccountVisibleInSchedule(
          accountId: 'account',
          visible: false,
        );
        await tester.pumpAndSettle();
        expect(warning, findsNothing);
        await settings.setAccountVisibleInSchedule(
          accountId: 'account',
          visible: true,
        );
        await _waitFor(tester, warning);

        searchResult = Completer<bool>();
        await _retryWarning(tester, warning);
        final retry = calls.last;
        expect(retry.range.start, bounded.range!.start);
        expect(retry.range.end, bounded.range!.end);
        expect(retry.filters.sourceIds, {otherSourceId});
        expect(retry.filters.sourceFilterActive, isTrue);
        expect(retry.filters.query, 'Planning');
        expect(retry.filters.location, 'Office');
        expect(retry.filters.includeTasks, isFalse);
        expect(warning, findsNothing);
        searchResult.complete(true);
        await tester.pumpAndSettle();
        expect(warning, findsNothing);
        expect(syncRequests, isEmpty);
        if (platform == _Platform.android) {
          await tester.tap(action);
          await tester.pumpAndSettle();
          await tester.tap(find.text('Refresh all'));
          await tester.pumpAndSettle();
          expect(syncRequests.single.scope, allSyncScope);
          expect(syncRequests.single.strategy, SyncStrategy.ordinary);
          expect(warning, findsNothing);
        }
      },
    );
  }
}

Widget _app(_Platform platform) => switch (platform) {
  _Platform.windows => const fluent.FluentApp(
    locale: Locale('en'),
    localizationsDelegates: [AppLocalizations.delegate],
    supportedLocales: AppLocalizations.supportedLocales,
    home: WindowsSchedulePage(),
  ),
  _Platform.linux => localizedTestApp(
    theme: BusyMaxYaruTheme.build(
      brightness: Brightness.light,
      accentColor: YaruColors.orange,
    ),
    child: const ScheduleWorkspace(),
  ),
  _Platform.android => localizedTestApp(
    theme: ThemeData(platform: TargetPlatform.android),
    child: const AndroidScheduleScreen(),
  ),
};

Finder _periodButton(
  _Platform platform, {
  required bool next,
}) => switch (platform) {
  _Platform.linux => find.byKey(
    ValueKey(next ? 'schedule-next-button' : 'schedule-previous-button'),
  ),
  _Platform.windows => find.byTooltip(
    next
        ? 'Next week in week view, next month in month view, and so on'
        : 'Previous week in week view, previous month in month view, and so on',
  ),
  _Platform.android => find.byTooltip(next ? 'Next page' : 'Previous page'),
};

Future<void> _waitFor(WidgetTester tester, Finder target) async {
  for (var attempt = 0; attempt < 100 && target.evaluate().isEmpty; attempt++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 5)),
    );
    await tester.pump(const Duration(milliseconds: 30));
  }
  expect(target, findsOneWidget);
  await tester.pumpAndSettle();
}

Future<void> _retryWarning(WidgetTester tester, Finder warning) async {
  await tester.tap(warning);
  await tester.pumpAndSettle();
  expect(
    find.text('Some events could not be checked. Showing downloaded data.'),
    findsOneWidget,
  );
  await tester.tap(find.text('Retry'));
  await tester.pumpAndSettle();
}

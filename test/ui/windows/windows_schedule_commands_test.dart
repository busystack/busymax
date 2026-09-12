import 'package:busymax/src/features/connectivity/network_connectivity_service.dart';
import 'package:busymax/l10n/generated/app_localizations.dart';
import 'package:busymax/src/app/app_bootstrap.dart';
import 'package:busymax/src/calendar_providers/calendar_sync_dto.dart';
import 'package:busymax/src/db/app_database.dart';
import 'package:busymax/src/features/accounts/data/accounts_repository.dart';
import 'package:busymax/src/features/calendar/data/calendar_repository.dart';
import 'package:busymax/src/features/task_lists/data/task_lists_repository.dart';
import 'package:busymax/src/features/tasks/data/tasks_repository.dart';
import 'package:busymax/src/providers/busy_provider.dart';
import 'package:busymax/src/schedule/schedule_commands.dart';
import 'package:busymax/src/schedule/schedule_repository.dart';
import 'package:busymax/src/schedule/schedule_view_mode.dart';
import 'package:busymax/src/ui/windows/windows_schedule_day_week_view.dart';
import 'package:busymax/src/ui/windows/windows_schedule_page.dart';
import 'package:drift/drift.dart' show Value;
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/memory_settings_store.dart';

void main() {
  testWidgets(
    'a pending notification opens its exact event across date and visibility filters',
    (tester) async {
      final db = AppDatabase.memoryForTests();
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        await db.close();
      });
      final calendar = CalendarRepository(database: db);
      await _seed(db, calendar);
      final id = CalendarRepository.eventId(
        accountId: 'account',
        provider: BusyProvider.google,
        providerCalendarId: 'calendar',
        providerEventId: 'event',
      );
      final source = (await calendar.listVisibleSources(['account'])).single;
      final container = await _mount(
        tester,
        db,
        calendar,
        command: ScheduleWorkspaceCommand(
          ScheduleWorkspaceCommandKind.openCalendarEvent,
          1,
          date: DateTime(2030, 9, 15),
          accountId: 'account',
          sourceId: source.id,
          itemId: id,
        ),
      );
      await _until(tester, find.byType(ContentDialog));
      expect(
        find.descendant(
          of: find.byType(ContentDialog),
          matching: find.text('Target event'),
        ),
        findsOneWidget,
      );
      final planner = tester.widget<WindowsScheduleDayWeekView>(
        find.byType(WindowsScheduleDayWeekView),
      );
      expect(planner.initialDate, DateTime(2030, 9, 15));
      expect(container.read(scheduleWorkspaceCommandProvider), isNull);
      await tester.tap(find.text('Close').last);
      await tester.pumpAndSettle();
      container.read(scheduleWorkspaceCommandProvider.notifier).state =
          const ScheduleWorkspaceCommand(ScheduleWorkspaceCommandKind.today, 2);
      await tester.pumpAndSettle();
      final today = DateTime.now();
      final todayPlanner = tester.widget<WindowsScheduleDayWeekView>(
        find.byType(WindowsScheduleDayWeekView),
      );
      expect(
        todayPlanner.initialDate,
        DateTime(today.year, today.month, today.day),
      );
      expect(todayPlanner.daysShowed, 1);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'Schedule refreshes background edits with unchanged account/source identifiers',
    (tester) async {
      final db = AppDatabase.memoryForTests();
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        await db.close();
      });
      final calendar = CalendarRepository(database: db);
      await _seed(db, calendar, date: DateTime.now());
      await _mount(tester, db, calendar);
      await _until(tester, find.text('Target event'));
      await (db.update(db.calendarEvents)).write(
        const CalendarEventsCompanion(title: Value('Background update')),
      );
      await _until(tester, find.text('Background update'));
      expect(find.text('Target event'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'task notification remains pending until sync inserts the exact task',
    (tester) async {
      final db = AppDatabase.memoryForTests();
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        await db.close();
      });
      final calendar = CalendarRepository(database: db);
      await _seed(db, calendar);
      final container = await _mount(
        tester,
        db,
        calendar,
        command: const ScheduleWorkspaceCommand(
          ScheduleWorkspaceCommandKind.openTask,
          3,
          accountId: 'account',
          sourceId: 'list',
          itemId: 'late-task',
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(ContentDialog), findsNothing);
      await db.tasksDao.upsertTask(
        TasksCompanion.insert(
          accountId: 'account',
          taskListId: 'list',
          id: 'late-task',
          title: 'Synced notification task',
          status: const Value('completed'),
          rawJson: '{}',
          createdLocalAtUtc: _now,
          updatedLocalAtUtc: _now,
        ),
      );
      await _until(tester, find.byType(ContentDialog));
      expect(
        find.descendant(
          of: find.byType(ContentDialog),
          matching: find.text('Synced notification task'),
        ),
        findsOneWidget,
      );
      expect(container.read(scheduleWorkspaceCommandProvider), isNull);
      await tester.tap(find.text('Close').last);
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}

Future<ProviderContainer> _mount(
  WidgetTester tester,
  AppDatabase db,
  CalendarRepository calendar, {
  ScheduleWorkspaceCommand? command,
}) async {
  tester.view.physicalSize = const Size(1280, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final container = ProviderContainer(
    overrides: [
      databaseProvider.overrideWithValue(db),
      networkAvailabilityProvider.overrideWith(
        (ref) => Stream.value(NetworkAvailability.online),
      ),
      localTimeZoneProvider.overrideWithValue('UTC'),
      localSettingsStoreProvider.overrideWithValue(MemorySettingsStore()),
      initialAppSettingsProvider.overrideWithValue(
        AppSettings.defaults().copyWith(scheduleViewMode: ScheduleViewMode.day),
      ),
      accountsRepositoryProvider.overrideWithValue(
        AccountsRepository(database: db),
      ),
      calendarRepositoryProvider.overrideWithValue(calendar),
      scheduleRepositoryProvider.overrideWithValue(ScheduleRepository(db)),
      taskListsRepositoryForAccountProvider.overrideWith(
        (ref, id) => TaskListsRepository(database: db, accountId: id),
      ),
      tasksRepositoryForAccountProvider.overrideWith(
        (ref, id) => TasksRepository(database: db, accountId: id),
      ),
    ],
  );
  addTearDown(container.dispose);
  container.read(scheduleWorkspaceCommandProvider.notifier).state = command;
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: FluentApp(
        localizationsDelegates: const [AppLocalizations.delegate],
        supportedLocales: AppLocalizations.supportedLocales,
        home: const WindowsSchedulePage(),
      ),
    ),
  );
  return container;
}

Future<void> _seed(
  AppDatabase db,
  CalendarRepository calendar, {
  DateTime? date,
}) async {
  await db
      .into(db.accounts)
      .insert(
        AccountsCompanion.insert(
          id: 'account',
          provider: 'google',
          authority: 'https://accounts.google.com',
          providerAccountId: 'me@example.test',
          credentialKind: 'oauth',
          authState: const Value('signed_in'),
          createdAtUtc: _now,
          updatedAtUtc: _now,
        ),
      );
  await db.taskListsDao.upsertTaskList(
    TaskListsCompanion.insert(
      accountId: 'account',
      id: 'list',
      title: 'Tasks',
      rawJson: '{}',
      createdLocalAtUtc: _now,
      updatedLocalAtUtc: _now,
    ),
  );
  await calendar.upsertSource(
    accountId: 'account',
    source: const CalendarSourceDto(
      provider: BusyProvider.google,
      providerCalendarId: 'calendar',
      summary: 'Calendar',
    ),
  );
  final day = date ?? DateTime(2030, 9, 15);
  await calendar.upsertEvent(
    accountId: 'account',
    event: CalendarEventDto(
      provider: BusyProvider.google,
      providerCalendarId: 'calendar',
      providerEventId: 'event',
      title: 'Target event',
      allDay: true,
      startDate: day.toIso8601String().substring(0, 10),
      endDate: DateTime(
        day.year,
        day.month,
        day.day + 1,
      ).toIso8601String().substring(0, 10),
      updatedAtServer: _now,
    ),
  );
}

Future<void> _until(WidgetTester tester, Finder finder) async {
  for (var i = 0; i < 100 && finder.evaluate().isEmpty; i++) {
    await tester.pump(const Duration(milliseconds: 30));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 2)),
    );
  }
  expect(finder, findsWidgets);
  await tester.pumpAndSettle();
}

const _now = '2026-09-01T12:00:00Z';

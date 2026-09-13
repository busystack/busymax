import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:busymax/src/features/schedule/presentation/schedule_workspace.dart';
import 'package:busymax/src/schedule/schedule_scope.dart';
import 'package:busymax/src/platform/linux_header_bar_provider.dart';
import 'package:busymax/src/platform/linux_header_bar_service.dart';
import 'package:busymax/src/platform/common/desktop_services.dart';
import 'package:flutter/material.dart' as material;
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

import '../../test_localized_app.dart';
import '../../support/recording_notification_backend.dart';
import '../../support/memory_settings_store.dart';

void main() {
  for (final linux in [false, true]) {
    for (final filter in ['scope', 'search', 'hidden']) {
      testWidgets(
        '${linux ? 'Linux' : 'Windows'} reminder Open resolves local day and exact event with $filter filter',
        (tester) async {
          final db = AppDatabase.memoryForTests();
          addTearDown(() async {
            await tester.pumpWidget(const SizedBox.shrink());
            await db.close();
          });
          final calendar = CalendarRepository(database: db);
          await _seed(db, calendar);
          final event = await db.select(db.calendarEvents).getSingle();
          // Written September 16 in Tokyo is September 15 on UTC and Vancouver hosts.
          final year = DateTime.now().year;
          final instant = DateTime.utc(year, 9, 15, 15, 30);
          final local = instant.toLocal();
          expect(local.day, isNot(16));
          await db
              .update(db.calendarEvents)
              .write(
                CalendarEventsCompanion(
                  allDay: const Value(false),
                  startDate: const Value(null),
                  endDate: const Value(null),
                  startDateTime: Value('$year-09-16T00:30:00'),
                  endDateTime: Value('$year-09-16T01:30:00'),
                  startTimeZone: Value(
                    filter == 'hidden' ? 'Custom/Embedded' : 'Asia/Tokyo',
                  ),
                  endTimeZone: Value(
                    filter == 'hidden' ? 'Custom/Embedded' : 'Asia/Tokyo',
                  ),
                  description: const Value('Exact notification event details'),
                  rawJson: Value(
                    filter == 'hidden'
                        ? jsonEncode({
                            'startUtc': instant.toIso8601String(),
                            'endUtc': instant
                                .add(const Duration(hours: 1))
                                .toIso8601String(),
                          })
                        : '{}',
                  ),
                ),
              );
          if (filter == 'hidden') {
            await calendar.setSourceSelected(event.calendarSourceId, false);
          }
          final container = await _mount(
            tester,
            db,
            calendar,
            linux: linux,
            scope: filter == 'scope' ? ScheduleScope.tasks : ScheduleScope.all,
          );
          await tester.pumpAndSettle();
          if (filter == 'search') {
            if (linux) {
              await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
              await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
              await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
              await tester.pumpAndSettle();
              await tester.enterText(
                find.byType(material.TextField).first,
                'unrelated search',
              );
            } else {
              await tester.enterText(
                find.byType(TextBox).first,
                'unrelated search',
              );
            }
            await tester.pump(const Duration(milliseconds: 400));
            await tester.pumpAndSettle();
          }
          await db
              .into(db.notificationSchedule)
              .insert(
                NotificationScheduleCompanion.insert(
                  id: 'event-reminder',
                  accountId: 'account',
                  sourceType: 'event',
                  sourceId: event.id,
                  scheduledAtUtc: instant.millisecondsSinceEpoch,
                  sentAtUtc: const Value(1),
                  title: event.title,
                  createdAtLocal: 0,
                  updatedAtLocal: 0,
                ),
              );
          ScheduleWorkspaceCommand? received;
          final subscription = container.listen(
            scheduleWorkspaceCommandProvider,
            (_, command) {
              if (command != null) received = command;
            },
          );
          addTearDown(subscription.close);
          await container
              .read(notificationSchedulerProvider)
              .handleActivation(
                notificationScheduleId: 'event-reminder',
                action: 'open',
              );
          container.read(notificationSchedulerProvider).stop();
          expect(received?.date, local);
          expect(received?.itemId, event.id);
          await _until(
            tester,
            find.textContaining('Exact notification event details'),
          );
          expect(
            find.textContaining('Exact notification event details'),
            findsOneWidget,
          );
          if (!linux) {
            final planner = tester.widget<WindowsScheduleDayWeekView>(
              find.byType(WindowsScheduleDayWeekView),
            );
            expect(
              planner.initialDate,
              DateTime(local.year, local.month, local.day),
            );
          }
          expect(
            (await db.select(db.calendarSources).getSingle()).selected,
            filter != 'hidden',
          );
          if (linux && filter == 'hidden') {
            await tester.sendKeyEvent(LogicalKeyboardKey.escape);
            await tester.pumpAndSettle();
            expect(find.text('Target event'), findsNothing);
            expect(
              (await db.select(db.calendarSources).getSingle()).selected,
              isFalse,
            );
          }
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets(
    'Linux task reminder opens its exact all-day task from Events scope',
    (tester) async {
      final db = AppDatabase.memoryForTests();
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        await db.close();
      });
      final calendar = CalendarRepository(database: db);
      await _seed(db, calendar);
      final date = DateTime.now();
      await db.tasksDao.upsertTask(
        TasksCompanion.insert(
          accountId: 'account',
          taskListId: 'list',
          id: 'task-reminder-target',
          title: 'Target task',
          notes: const Value('Exact notification task details'),
          dueUtc: Value(date.toIso8601String().substring(0, 10)),
          status: const Value('needsAction'),
          rawJson: '{}',
          createdLocalAtUtc: _now,
          updatedLocalAtUtc: _now,
        ),
      );
      final container = await _mount(
        tester,
        db,
        calendar,
        linux: true,
        scope: ScheduleScope.events,
      );
      await tester.pumpAndSettle();
      expect(find.text('Target task'), findsNothing);
      await db
          .into(db.notificationSchedule)
          .insert(
            NotificationScheduleCompanion.insert(
              id: 'task-reminder',
              accountId: 'account',
              sourceType: 'task',
              sourceId: 'task-reminder-target',
              scheduledAtUtc: date.toUtc().millisecondsSinceEpoch,
              sentAtUtc: const Value(1),
              title: 'Target task',
              createdAtLocal: 0,
              updatedAtLocal: 0,
            ),
          );
      await container
          .read(notificationSchedulerProvider)
          .handleActivation(
            notificationScheduleId: 'task-reminder',
            action: 'open',
          );
      container.read(notificationSchedulerProvider).stop();
      await _until(tester, find.text('Exact notification task details'));
      expect(find.text('Exact notification task details'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

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
  bool linux = false,
  ScheduleScope scope = ScheduleScope.all,
}) async {
  tester.view.physicalSize = const Size(1280, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final headerBar = LinuxHeaderBarService(isLinux: false);
  addTearDown(headerBar.dispose);
  final container = ProviderContainer(
    overrides: [
      databaseProvider.overrideWithValue(db),
      linuxHeaderBarServiceProvider.overrideWithValue(headerBar),
      desktopWindowServiceProvider.overrideWithValue(
        const NoOpDesktopWindowService(),
      ),
      desktopNotificationBackendProvider.overrideWithValue(
        RecordingNotificationBackend(),
      ),
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
      child: linux
          ? localizedTestApp(child: ScheduleWorkspace(initialScope: scope))
          : FluentApp(
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

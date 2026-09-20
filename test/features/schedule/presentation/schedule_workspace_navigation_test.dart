import 'dart:io';

import 'package:busymax/src/app/app_bootstrap.dart';
import 'package:busymax/src/calendar_providers/calendar_sync_dto.dart';
import 'package:busymax/src/db/app_database.dart';
import 'package:busymax/src/features/accounts/data/accounts_repository.dart';
import 'package:busymax/src/features/calendar/data/calendar_repository.dart';
import 'package:busymax/src/features/schedule/presentation/schedule_day_week_view.dart';
import 'package:busymax/src/features/schedule/presentation/schedule_month_view.dart';
import 'package:busymax/src/features/schedule/presentation/schedule_workspace.dart';
import 'package:busymax/src/features/task_lists/data/task_lists_repository.dart';
import 'package:busymax/src/features/tasks/data/tasks_repository.dart';
import 'package:busymax/src/platform/linux_header_bar_service.dart';
import 'package:busymax/src/platform/linux_header_bar_provider.dart';
import 'package:busymax/src/providers/busy_provider.dart';
import 'package:busymax/src/schedule/schedule_scope.dart';
import 'package:drift/drift.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/process_time_zone.dart';
import '../../../test_localized_app.dart';

void main() {
  testWidgets(
    'previous and next day navigation render the destination all-day event',
    (tester) async {
      for (final scenario in [
        (start: DateTime(2026, 9, 13), next: true),
        (start: DateTime(2026, 9, 19), next: false),
      ]) {
        final harness = await _pumpWorkspace(
          tester,
          scenario.start,
          includeSeptemberBirthday: true,
        );
        await tester.sendKeyEvent(LogicalKeyboardKey.digit1);
        await tester.pumpAndSettle();

        for (var index = 0; index < 3; index++) {
          await _navigate(tester, next: scenario.next);
          await tester.pumpAndSettle();
        }

        final view = tester.widget<ScheduleDayWeekView>(
          find.byType(ScheduleDayWeekView),
        );
        expect(view.selectedDate, DateTime(2026, 9, 16));
        expect(
          view.items.map((item) => item.title),
          contains("Ildar's Birthday"),
        );
        expect(
          find.text("Ildar's Birthday", skipOffstage: false),
          findsOneWidget,
        );

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(milliseconds: 1));
        harness.headerBar.dispose();
        await harness.database.close();
      }
    },
  );

  testWidgets(
    'workspace month commands always select the adjacent month first',
    (tester) async {
      for (final scenario in <({DateTime start, bool next, DateTime expected})>[
        (start: DateTime(2026, 1, 31), next: true, expected: DateTime(2026, 2)),
        (
          start: DateTime(2026, 3, 31),
          next: false,
          expected: DateTime(2026, 2),
        ),
        (start: DateTime(2024, 2, 29), next: true, expected: DateTime(2024, 3)),
        (start: DateTime(2026, 12, 31), next: true, expected: DateTime(2027)),
      ]) {
        final harness = await _pumpWorkspace(tester, scenario.start);
        await tester.sendKeyEvent(LogicalKeyboardKey.digit3);
        await tester.pump();
        await _navigate(tester, next: scenario.next);
        final view = tester.widget<ScheduleMonthView>(
          find.byType(ScheduleMonthView),
        );
        expect(view.selectedDate, scenario.expected);
        expect(view.selectedDate.hour, 0);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(milliseconds: 1));
        harness.headerBar.dispose();
        await harness.database.close();
      }
    },
  );

  final supportsPosixTimeZones = Platform.isLinux || Platform.isMacOS;
  group(
    'workspace civil day and week commands across DST',
    skip: supportsPosixTimeZones
        ? false
        : 'This regression test requires POSIX setenv and tzset.',
    () {
      late ProcessTimeZone processTimeZone;
      setUpAll(() {
        processTimeZone = ProcessTimeZone()..set('America/Vancouver');
      });
      tearDownAll(() => processTimeZone.restore());

      for (final scenario in <({DateTime start, bool next, int days})>[
        (start: DateTime(2025, 3, 8), next: true, days: 1),
        (start: DateTime(2025, 3, 10), next: false, days: 1),
        (start: DateTime(2025, 11, 1), next: true, days: 1),
        (start: DateTime(2025, 11, 3), next: false, days: 1),
        (start: DateTime(2025, 3, 3), next: true, days: 7),
        (start: DateTime(2025, 11, 9), next: false, days: 7),
      ]) {
        testWidgets(
          '${scenario.days}-day command from ${scenario.start.toIso8601String()}',
          (tester) async {
            final harness = await _pumpWorkspace(tester, scenario.start);
            await tester.sendKeyEvent(
              scenario.days == 1
                  ? LogicalKeyboardKey.digit1
                  : LogicalKeyboardKey.digit2,
            );
            await tester.pump();
            await _navigate(tester, next: scenario.next);
            final view = tester.widget<ScheduleDayWeekView>(
              find.byType(ScheduleDayWeekView),
            );
            final direction = scenario.next ? 1 : -1;
            final expected = DateTime(
              scenario.start.year,
              scenario.start.month,
              scenario.start.day + direction * scenario.days,
            );
            expect(view.selectedDate, expected);
            expect(view.selectedDate.hour, 0);
            await tester.pumpWidget(const SizedBox.shrink());
            await tester.pump(const Duration(milliseconds: 1));
            harness.headerBar.dispose();
            await harness.database.close();
          },
        );
      }
    },
  );
}

Future<void> _navigate(WidgetTester tester, {required bool next}) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
  await tester.sendKeyEvent(
    next ? LogicalKeyboardKey.arrowRight : LogicalKeyboardKey.arrowLeft,
  );
  await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
  await tester.pump();
}

Future<({AppDatabase database, LinuxHeaderBarService headerBar})>
_pumpWorkspace(
  WidgetTester tester,
  DateTime initialDate, {
  bool includeSeptemberBirthday = false,
}) async {
  final database = AppDatabase.memoryForTests();
  await database
      .into(database.accounts)
      .insert(
        AccountsCompanion.insert(
          id: 'account',
          provider: 'google',
          authority: 'https://accounts.google.com',
          providerAccountId: 'account',
          credentialKind: 'oauth',
          authState: const Value('signed_in'),
          createdAtUtc: _now,
          updatedAtUtc: _now,
        ),
      );
  await database.taskListsDao.upsertTaskList(
    TaskListsCompanion.insert(
      accountId: 'account',
      id: 'list',
      title: 'Tasks',
      rawJson: '{}',
      createdLocalAtUtc: _now,
      updatedLocalAtUtc: _now,
    ),
  );
  if (includeSeptemberBirthday) {
    final calendar = CalendarRepository(database: database);
    await calendar.upsertSource(
      accountId: 'account',
      source: const CalendarSourceDto(
        provider: BusyProvider.google,
        providerCalendarId: 'birthdays',
        summary: 'Birthdays',
      ),
    );
    await calendar.upsertEvent(
      accountId: 'account',
      event: const CalendarEventDto(
        provider: BusyProvider.google,
        providerCalendarId: 'birthdays',
        providerEventId: 'birthday-2026',
        title: "Ildar's Birthday",
        allDay: true,
        startDate: '2026-09-16',
        endDate: '2026-09-17',
      ),
    );
  }
  const account = AccountEntity(
    id: 'account',
    provider: BusyProvider.google,
    authority: 'https://accounts.google.com',
    providerAccountId: 'account',
    authState: accountAuthStateSignedIn,
  );
  final headerBar = LinuxHeaderBarService(isLinux: false);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(database),
        accountsStreamProvider.overrideWith((ref) => Stream.value([account])),
        activeAccountProvider.overrideWithValue('account'),
        localTimeZoneProvider.overrideWithValue('America/Vancouver'),
        localSettingsStoreProvider.overrideWithValue(_MemorySettingsStore()),
        linuxHeaderBarServiceProvider.overrideWithValue(headerBar),
        taskListsRepositoryForAccountProvider.overrideWith(
          (ref, id) => TaskListsRepository(database: database, accountId: id),
        ),
        tasksRepositoryForAccountProvider.overrideWith(
          (ref, id) => TasksRepository(database: database, accountId: id),
        ),
      ],
      child: localizedTestApp(
        child: ScheduleWorkspace(
          initialScope: ScheduleScope.all,
          initialDate: initialDate,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return (database: database, headerBar: headerBar);
}

class _MemorySettingsStore implements LocalSettingsStore {
  @override
  Future<Map<String, Object?>> load() async => const {};

  @override
  Future<void> save(Map<String, Object?> json) async {}
}

const _now = '2026-06-04T00:00:00.000Z';

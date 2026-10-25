import 'package:busymax/l10n/generated/app_localizations.dart';
import 'package:busymax/src/app/app_bootstrap.dart';
import 'package:busymax/src/app/app_router.dart';
import 'package:busymax/src/db/app_database.dart';
import 'package:busymax/src/features/accounts/data/accounts_repository.dart';
import 'package:busymax/src/features/connectivity/network_connectivity_service.dart';
import 'package:busymax/src/features/schedule/presentation/schedule_agenda_view.dart';
import 'package:busymax/src/features/schedule/presentation/schedule_month_view.dart';
import 'package:busymax/src/features/schedule/presentation/schedule_sidebar.dart';
import 'package:busymax/src/features/schedule/presentation/schedule_toolbar.dart';
import 'package:busymax/src/features/schedule/presentation/schedule_workspace.dart';
import 'package:busymax/src/features/tasks/presentation/task_details_pane.dart';
import 'package:busymax/src/features/tasks/data/tasks_repository.dart';
import 'package:busymax/src/features/task_lists/data/task_lists_repository.dart';
import 'package:busymax/src/schedule/schedule_repository.dart';
import 'package:busymax/src/schedule/schedule_view_mode.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ubuntu_localizations/ubuntu_localizations.dart';
import 'package:yaru/yaru.dart';
import 'package:busymax/src/app/busymax_design.dart';

import '../../../support/memory_settings_store.dart';

void main() {
  testWidgets(
    'dated summary is focused, supports tasks, and restores ordinary search/view state',
    (tester) async {
      tester.view
        ..physicalSize = const Size(1400, 1000)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final database = AppDatabase.memoryForTests();
      addTearDown(database.close);
      for (final account in ['a', 'b']) {
        await database
            .into(database.accounts)
            .insert(
              AccountsCompanion.insert(
                id: account,
                provider: 'google',
                authority: 'https://qa.invalid',
                providerAccountId: account,
                credentialKind: 'oauth',
                authState: const Value('signed_in'),
                createdAtUtc: '',
                updatedAtUtc: '',
              ),
            );
        await database
            .into(database.taskLists)
            .insert(
              TaskListsCompanion.insert(
                accountId: account,
                id: 'list',
                title: 'Inbox',
                rawJson: '{}',
                createdLocalAtUtc: '',
                updatedLocalAtUtc: '',
              ),
            );
        for (final date in ['2026-06-08', '2026-06-09']) {
          await database
              .into(database.tasks)
              .insert(
                TasksCompanion.insert(
                  accountId: account,
                  taskListId: 'list',
                  id: '$account-$date',
                  title: 'Task $account $date',
                  dueUtc: Value(date),
                  rawJson: '{}',
                  createdLocalAtUtc: '',
                  updatedLocalAtUtc: '',
                ),
              );
        }
      }
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(database),
          localSettingsStoreProvider.overrideWithValue(MemorySettingsStore()),
          initialAppSettingsProvider.overrideWithValue(
            AppSettings.defaults().copyWith(
              scheduleViewMode: ScheduleViewMode.month,
            ),
          ),
          localTimeZoneProvider.overrideWithValue('Etc/UTC'),
          activeAccountProvider.overrideWithValue('a'),
          signedInSyncRunnerProvider.overrideWithValue((_, _) async {}),
          allAccountsSyncRunnerProvider.overrideWithValue(() async {}),
          networkAvailabilityProvider.overrideWith(
            (ref) => Stream.value(NetworkAvailability.online),
          ),
          tasksRepositoryForAccountProvider.overrideWith(
            (ref, id) => TasksRepository(database: database, accountId: id),
          ),
          taskListsRepositoryForAccountProvider.overrideWith(
            (ref, id) => TaskListsRepository(database: database, accountId: id),
          ),
          accountsStreamProvider.overrideWith(
            (ref) => AccountsRepository(database: database).watchAccounts(),
          ),
          scheduleRepositoryProvider.overrideWith(
            (ref) => ScheduleRepository(
              database,
              ensureCloudCoverage: (_, _) async => true,
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      final router = container.read(appRouterProvider);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            routerConfig: router,
            localizationsDelegates: const [
              ...AppLocalizations.localizationsDelegates,
              ...GlobalUbuntuLocalizations.delegates,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        ),
      );
      router.go('/schedule');
      await tester.pumpAndSettle();
      final normal = tester.state(find.byType(ScheduleWorkspace));
      final selected = tester
          .widget<ScheduleMonthView>(find.byType(ScheduleMonthView))
          .selectedDate;
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
      final search = find.descendant(
        of: find.byType(ScheduleToolbar),
        matching: find.byType(EditableText),
      );
      await tester.enterText(search, 'ordinary browsing query');
      await tester.pumpAndSettle();

      // A retained summary opened months later must still show its original day,
      // across accounts and independently of the underlying search/account state.
      final pushed = router.push<void>('/tasks?due=2026-06-08');
      await tester.pumpAndSettle();
      expect(find.text('Task a 2026-06-08'), findsOneWidget);
      expect(find.text('Task b 2026-06-08'), findsOneWidget);
      expect(find.text('Task a 2026-06-09'), findsNothing);
      expect(find.byType(ScheduleToolbar), findsNothing);
      expect(find.byType(ScheduleSidebar), findsNothing);
      for (final key in [
        LogicalKeyboardKey.digit1,
        LogicalKeyboardKey.digit3,
        LogicalKeyboardKey.keyT,
      ]) {
        await tester.sendKeyEvent(key);
      }
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
      expect(find.byType(EditableText), findsNothing);
      expect(find.byType(ScheduleAgendaView), findsOneWidget);
      expect(
        container.read(appSettingsControllerProvider).scheduleViewMode,
        ScheduleViewMode.month,
      );
      await tester.tap(find.text('Task b 2026-06-08'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byTooltip(lookupAppLocalizations(const Locale('en')).editTask),
      );
      await tester.pumpAndSettle();
      expect(find.byType(TaskDetailsPane), findsOneWidget);
      expect(
        tester.widget<TaskDetailsPane>(find.byType(TaskDetailsPane)).taskId,
        'b-2026-06-08',
      );
      // Close the item before closing the temporary results.
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      final taskRow = find.ancestor(
        of: find.text('Task a 2026-06-08'),
        matching: find.byType(BusyMaxActionRow),
      );
      await tester.tap(
        find.descendant(of: taskRow, matching: find.byType(YaruCheckbox)),
      );
      await tester.pumpAndSettle();
      final completed = await (database.select(
        database.tasks,
      )..where((row) => row.id.equals('a-2026-06-08'))).getSingle();
      expect(completed.status, 'completed');
      await tester.tap(
        find.byKey(const ValueKey('notification-summary-close')),
      );
      await tester.pumpAndSettle();
      await pushed;
      expect(tester.state(find.byType(ScheduleWorkspace)), same(normal));
      expect(
        tester
            .widget<EditableText>(
              find.descendant(
                of: find.byType(ScheduleToolbar),
                matching: find.byType(EditableText),
              ),
            )
            .controller
            .text,
        'ordinary browsing query',
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<ScheduleMonthView>(find.byType(ScheduleMonthView))
            .selectedDate,
        selected,
      );
      expect(
        container.read(appSettingsControllerProvider).scheduleViewMode,
        ScheduleViewMode.month,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}

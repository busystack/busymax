import 'dart:async';

import 'package:busymax/l10n/generated/app_localizations.dart';
import 'package:busymax/src/app/app_bootstrap.dart';
import 'package:busymax/src/db/app_database.dart';
import 'package:busymax/src/features/calendar/data/calendar_repository.dart';
import 'package:busymax/src/features/connectivity/network_connectivity_service.dart';
import 'package:busymax/src/features/task_lists/data/task_lists_repository.dart';
import 'package:busymax/src/features/tasks/data/tasks_repository.dart';
import 'package:busymax/src/schedule/schedule_repository.dart';
import 'package:busymax/src/ui/windows/windows_schedule_page.dart';
import 'package:busymax/src/ui/windows/windows_task_editor_dialog.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/dav_task_inventory_fixture.dart';
import '../../support/memory_settings_store.dart';

void main() {
  testWidgets(
    'same Windows workspace and editor follow persisted DAV privilege grants and revocations',
    (tester) async {
      final database = AppDatabase.memoryForTests();
      final inventory = DavTaskInventoryFixture(database);
      await inventory.seedAccount();
      await inventory.commit(writable: false);
      final list = await database.select(database.taskLists).getSingle();
      final collectionId = list.davCollectionId;
      final key = (accountId: list.accountId, taskListId: list.id);
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(database),
          localSettingsStoreProvider.overrideWithValue(MemorySettingsStore()),
          localTimeZoneProvider.overrideWithValue('UTC'),
          networkAvailabilityProvider.overrideWith(
            (ref) => Stream.value(NetworkAvailability.online),
          ),
          calendarRepositoryProvider.overrideWithValue(
            CalendarRepository(database: database),
          ),
          scheduleRepositoryProvider.overrideWithValue(
            ScheduleRepository(database),
          ),
          taskListsRepositoryForAccountProvider.overrideWith(
            (ref, id) => TaskListsRepository(database: database, accountId: id),
          ),
          tasksRepositoryForAccountProvider.overrideWith(
            (ref, id) => TasksRepository(database: database, accountId: id),
          ),
        ],
      );
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(milliseconds: 1));
        container.dispose();
        await database.close();
      });
      await container
          .read(appSettingsControllerProvider.notifier)
          .setTaskListVisibleInSchedule(
            accountId: list.accountId,
            taskListId: list.id,
            visible: false,
          );
      tester.view
        ..devicePixelRatio = 1
        ..physicalSize = const Size(1280, 900);
      addTearDown(tester.view.reset);
      // The probe invokes the production editor independently of command availability.
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: FluentApp(
            localizationsDelegates: const [AppLocalizations.delegate],
            supportedLocales: AppLocalizations.supportedLocales,
            home: Column(
              children: [
                const Expanded(child: WindowsSchedulePage()),
                Consumer(
                  builder: (context, ref, _) => Button(
                    onPressed: () => unawaited(
                      showWindowsTaskEditorDialog(
                        context,
                        ref,
                        initialAccountId: list.accountId,
                        initialTaskListId: list.id,
                      ),
                    ),
                    child: const Text('Check production editor'),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final workspace = tester.state(find.byType(WindowsSchedulePage));
      expect(
        container
            .read(davTaskCollectionCapabilitiesProvider(key))
            .requireValue!
            .canCreateTasks,
        isFalse,
      );
      expect((await _newTaskAction(tester)).onPressed, isNull);
      await _closeMenu(tester);

      await inventory.commit(writable: true);
      await tester.pumpAndSettle();
      expect((await _newTaskAction(tester)).onPressed, isNotNull);
      await tester.tap(find.text('New task'));
      await _waitForDialog(tester);
      expect(find.text('No task lists synced yet.'), findsNothing);
      final destination = tester
          .widget<ComboBox<TaskListEntity>>(
            find.byType(ComboBox<TaskListEntity>),
          )
          .value!;
      expect(
        (destination.accountId, destination.id),
        (list.accountId, list.id),
      );
      expect(
        container
            .read(davTaskCollectionCapabilitiesProvider(key))
            .requireValue!
            .canCreateTasks,
        isTrue,
      );
      await tester.tap(find.text('Cancel').last);
      await tester.pumpAndSettle();

      await inventory.commit(writable: false);
      await tester.pumpAndSettle();
      expect((await _newTaskAction(tester)).onPressed, isNull);
      await _closeMenu(tester);
      await tester.tap(find.text('Check production editor'));
      await _waitForDialog(tester);
      expect(find.text('No task lists synced yet.'), findsOneWidget);
      expect(find.byType(ComboBox<TaskListEntity>), findsNothing);
      await tester.tap(find.text('Close').last);
      await tester.pumpAndSettle();
      expect(tester.state(find.byType(WindowsSchedulePage)), same(workspace));
      expect(
        (await database.select(database.taskLists).getSingle()).davCollectionId,
        collectionId,
      );
      expect(
        container
            .read(appSettingsControllerProvider)
            .isTaskListVisibleInSchedule(list.accountId, list.id),
        isFalse,
      );
      expect(await database.select(database.tasks).get(), isEmpty);
    },
  );
}

Future<FlyoutListTile> _newTaskAction(WidgetTester tester) async {
  await tester.tap(find.byTooltip('See more'));
  await tester.pumpAndSettle();
  return tester.widget<FlyoutListTile>(
    find.ancestor(
      of: find.text('New task'),
      matching: find.byType(FlyoutListTile),
    ),
  );
}

Future<void> _closeMenu(WidgetTester tester) async {
  await tester.tapAt(const Offset(500, 700));
  await tester.pumpAndSettle();
}

Future<void> _waitForDialog(WidgetTester tester) async {
  for (
    var i = 0;
    i < 100 && find.byType(ContentDialog).evaluate().isEmpty;
    i++
  ) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 2)),
    );
    await tester.pump(const Duration(milliseconds: 30));
  }
  expect(find.byType(ContentDialog), findsOneWidget);
  await tester.pumpAndSettle();
}

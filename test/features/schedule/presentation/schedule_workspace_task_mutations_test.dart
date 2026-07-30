import 'package:busymax/src/app/app_bootstrap.dart';
import 'package:busymax/src/app/busymax_design.dart';
import 'package:busymax/src/db/app_database.dart';
import 'package:busymax/src/features/accounts/data/accounts_repository.dart';
import 'package:busymax/src/features/schedule/presentation/schedule_workspace.dart';
import 'package:busymax/src/features/task_lists/data/task_lists_repository.dart';
import 'package:busymax/src/features/tasks/data/tasks_repository.dart';
import 'package:busymax/src/platform/linux_header_bar_service.dart';
import 'package:busymax/src/platform/native_dialog_service.dart';
import 'package:busymax/src/platform/native_menu_service.dart';
import 'package:busymax/src/schedule/schedule_scope.dart';
import 'package:busymax/src/task_providers/task_provider.dart';
import 'package:drift/drift.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yaru/yaru.dart';

import '../../../test_localized_app.dart';

const _nativeDialogChannel = MethodChannel(nativeDialogChannelName);
const _nativeMenuChannel = MethodChannel(nativeMenuChannelName);

void main() {
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_nativeDialogChannel, (_) async => null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          _nativeMenuChannel,
          (_) async => throw MissingPluginException(),
        );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_nativeDialogChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_nativeMenuChannel, null);
  });

  testWidgets('creating a task from Schedule refreshes the visible items', (
    tester,
  ) async {
    final harness = await _pumpScheduleWorkspace(tester);

    expect(find.text('Created from Schedule'), findsNothing);

    await tester.tap(find.byTooltip('Create'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Task'));
    await tester.pumpAndSettle();

    final titleField = find.byWidgetPredicate(
      (widget) =>
          widget is TextField && widget.decoration?.labelText == 'Title',
    );
    expect(titleField, findsOneWidget);
    await tester.enterText(titleField, 'Created from Schedule');
    await tester.pump();
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();

    final tasks = await harness.database.tasksDao.listTasks(
      _accountId,
      _taskListId,
    );
    expect(tasks.map((task) => task.title), contains('Created from Schedule'));
    expect(find.text('Created from Schedule'), findsOneWidget);
  });

  testWidgets('task-list route defaults new tasks to that account and list', (
    tester,
  ) async {
    final harness = await _pumpScheduleWorkspace(
      tester,
      initialTaskAccountId: _accountId,
      initialTaskListId: _projectListId,
    );

    await tester.tap(find.byTooltip('Create'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Task'));
    await tester.pumpAndSettle();
    final titleField = find.byWidgetPredicate(
      (widget) =>
          widget is TextField && widget.decoration?.labelText == 'Title',
    );
    await tester.enterText(titleField, 'Created in Projects');
    await tester.pump();
    expect(
      tester
              .widget<BusyMaxEditorHeader>(find.byType(BusyMaxEditorHeader))
              .onSave ==
          null,
      isFalse,
    );
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();

    final allTasks = await harness.database
        .select(harness.database.tasks)
        .get();
    expect(allTasks, isNotEmpty);
    final createdTask = allTasks.single;
    expect(createdTask.title, 'Created in Projects');
    expect(createdTask.accountId, _accountId);
    expect(createdTask.taskListId, _projectListId);
  });

  testWidgets('completing a task from Schedule refreshes its checkbox', (
    tester,
  ) async {
    final harness = await _pumpScheduleWorkspace(
      tester,
      taskTitle: 'Complete from Schedule',
    );

    final taskRow = find.ancestor(
      of: find.text('Complete from Schedule'),
      matching: find.byType(InkWell),
    );
    final checkbox = find.descendant(
      of: taskRow.first,
      matching: find.byType(YaruCheckbox),
    );
    expect(checkbox, findsOneWidget);
    expect(tester.widget<YaruCheckbox>(checkbox).value, isFalse);

    await tester.tap(checkbox);
    await tester.pumpAndSettle();

    final task = (await harness.database.tasksDao.listTasks(
      _accountId,
      _taskListId,
    )).single;
    expect(task.status, 'completed');
    expect(tester.widget<YaruCheckbox>(checkbox).value, isTrue);
  });

  testWidgets('dirty deep-linked task confirms before Escape closes it', (
    tester,
  ) async {
    await _pumpScheduleWorkspace(
      tester,
      taskTitle: 'Opened from route',
      initialTaskAccountId: _accountId,
      initialTaskListId: _taskListId,
      initialTaskId: 'task-1',
    );

    expect(find.text('Edit Task'), findsOneWidget);
    expect(find.text('Opened from route'), findsWidgets);

    await tester.enterText(find.byType(TextField).first, 'Unsaved route edit');
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(find.text('Discard changes?'), findsOneWidget);
    await tester.tap(find.text('Cancel').last);
    await tester.pumpAndSettle();
    expect(find.text('Edit Task'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();

    expect(find.text('Edit Task'), findsNothing);
    expect(find.text('Opened from route'), findsOneWidget);
  });
}

Future<_ScheduleHarness> _pumpScheduleWorkspace(
  WidgetTester tester, {
  String? taskTitle,
  String? initialTaskAccountId,
  String? initialTaskListId,
  String? initialTaskId,
}) async {
  final database = AppDatabase.memoryForTests();
  addTearDown(database.close);
  await database
      .into(database.accounts)
      .insert(
        AccountsCompanion.insert(
          id: _accountId,
          provider: Value(TaskProvider.google.storageValue),
          displayName: const Value('Schedule test'),
          authState: const Value(accountAuthStateSignedIn),
          createdAtUtc: _nowUtc,
          updatedAtUtc: _nowUtc,
        ),
      );
  await database.taskListsDao.upsertTaskList(
    TaskListsCompanion.insert(
      accountId: _accountId,
      id: _taskListId,
      title: 'Inbox',
      rawJson: '{}',
      createdLocalAtUtc: _nowUtc,
      updatedLocalAtUtc: _nowUtc,
    ),
  );
  await database.taskListsDao.upsertTaskList(
    TaskListsCompanion.insert(
      accountId: _accountId,
      id: _projectListId,
      title: 'Projects',
      rawJson: '{}',
      createdLocalAtUtc: _nowUtc,
      updatedLocalAtUtc: _nowUtc,
    ),
  );
  if (taskTitle != null) {
    await database.tasksDao.upsertTask(
      TasksCompanion.insert(
        accountId: _accountId,
        taskListId: _taskListId,
        id: 'task-1',
        title: taskTitle,
        status: const Value('needsAction'),
        dueUtc: Value(_todayUtc()),
        rawJson: '{"id":"task-1","title":"$taskTitle"}',
        createdLocalAtUtc: _nowUtc,
        updatedLocalAtUtc: _nowUtc,
      ),
    );
  }

  final account = AccountEntity(
    id: _accountId,
    provider: TaskProvider.google,
    authState: accountAuthStateSignedIn,
    displayName: 'Schedule test',
  );
  final headerBarService = LinuxHeaderBarService(isLinux: false);
  addTearDown(headerBarService.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(database),
        accountsStreamProvider.overrideWith((ref) => Stream.value([account])),
        activeAccountProvider.overrideWithValue(_accountId),
        localTimeZoneProvider.overrideWithValue('UTC'),
        localSettingsStoreProvider.overrideWithValue(_MemorySettingsStore()),
        linuxHeaderBarServiceProvider.overrideWithValue(headerBarService),
        taskListsRepositoryForAccountProvider.overrideWith((ref, accountId) {
          return TaskListsRepository(database: database, accountId: accountId);
        }),
        tasksRepositoryForAccountProvider.overrideWith((ref, accountId) {
          return TasksRepository(database: database, accountId: accountId);
        }),
      ],
      child: localizedTestApp(
        child: ScheduleWorkspace(
          initialScope: ScheduleScope.tasks,
          initialTaskAccountId: initialTaskAccountId,
          initialTaskListId: initialTaskListId,
          initialTaskId: initialTaskId,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return _ScheduleHarness(database);
}

String _todayUtc() {
  final today = DateTime.now();
  return DateTime.utc(today.year, today.month, today.day).toIso8601String();
}

class _ScheduleHarness {
  const _ScheduleHarness(this.database);

  final AppDatabase database;
}

class _MemorySettingsStore implements LocalSettingsStore {
  @override
  Future<Map<String, Object?>> load() async => <String, Object?>{};

  @override
  Future<void> save(Map<String, Object?> json) async {}
}

const _accountId = 'google:schedule-test';
const _taskListId = 'inbox';
const _projectListId = 'projects';
const _nowUtc = '2026-07-19T00:00:00.000Z';

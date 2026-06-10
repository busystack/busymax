import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:desktop_notifications/desktop_notifications.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:busymax/src/app/app_bootstrap.dart';
import 'package:busymax/src/app/busymax_design.dart';
import 'package:busymax/src/db/app_database.dart';
import 'package:busymax/src/features/accounts/data/accounts_repository.dart';
import 'package:busymax/src/features/notifications/desktop_notification_service.dart';
import 'package:busymax/src/features/sync/sync_engine.dart';
import 'package:busymax/src/features/task_lists/data/task_lists_repository.dart';
import 'package:busymax/src/features/tasks/data/tasks_repository.dart';
import 'package:busymax/src/features/tasks/presentation/task_details_editor.dart';
import 'package:busymax/src/features/tasks/presentation/task_details_pane.dart';
import 'package:busymax/src/features/tasks/presentation/task_filters.dart';
import 'package:busymax/src/features/tasks/presentation/tasks_selection_state.dart';
import 'package:busymax/src/features/tasks/presentation/tasks_workspace.dart';
import 'package:busymax/src/features/tasks/presentation/task_tree_view.dart';
import 'package:busymax/src/google_tasks/api/google_tasks_api_client.dart';
import 'package:busymax/src/google_tasks/api/google_tasks_api_models.dart';
import 'package:busymax/src/task_providers/task_provider.dart';
import 'package:yaru/yaru.dart';
import '../../../test_localized_app.dart';

void main() {
  test(
    'All Tasks filter capabilities enable Google hidden and assigned filters',
    () async {
      final container = ProviderContainer(
        overrides: [
          accountsStreamProvider.overrideWith((ref) {
            return Stream.value([
              _accountEntity(id: 'google:g', provider: TaskProvider.google),
              _accountEntity(
                id: 'microsoft:m',
                provider: TaskProvider.microsoft,
              ),
            ]);
          }),
          selectedAccountCapabilitiesProvider.overrideWithValue(
            microsoftTaskProviderCapabilities,
          ),
        ],
      );
      addTearDown(container.dispose);
      container.read(allTasksModeProvider.notifier).state = true;
      await container.read(accountsStreamProvider.future);

      final capabilities = container.read(
        visibleTaskFilterCapabilitiesProvider,
      );

      expect(capabilities.supportsHiddenTasks, isTrue);
      expect(capabilities.supportsAssignedTasks, isTrue);
    },
  );

  test(
    'Microsoft-only All Tasks keeps hidden and assigned filters disabled',
    () async {
      final container = ProviderContainer(
        overrides: [
          accountsStreamProvider.overrideWith((ref) {
            return Stream.value([
              _accountEntity(
                id: 'microsoft:m',
                provider: TaskProvider.microsoft,
              ),
            ]);
          }),
          selectedAccountCapabilitiesProvider.overrideWithValue(
            googleTaskProviderCapabilities,
          ),
        ],
      );
      addTearDown(container.dispose);
      container.read(allTasksModeProvider.notifier).state = true;
      await container.read(accountsStreamProvider.future);

      final capabilities = container.read(
        visibleTaskFilterCapabilitiesProvider,
      );

      expect(capabilities.supportsHiddenTasks, isFalse);
      expect(capabilities.supportsAssignedTasks, isFalse);
    },
  );

  test(
    'List mode filter capabilities use the selected account capabilities',
    () {
      final container = ProviderContainer(
        overrides: [
          accountsStreamProvider.overrideWith((ref) {
            return Stream.value([
              _accountEntity(id: 'google:g', provider: TaskProvider.google),
            ]);
          }),
          selectedAccountCapabilitiesProvider.overrideWithValue(
            microsoftTaskProviderCapabilities,
          ),
        ],
      );
      addTearDown(container.dispose);
      container.read(allTasksModeProvider.notifier).state = false;

      final capabilities = container.read(
        visibleTaskFilterCapabilitiesProvider,
      );

      expect(capabilities.supportsHiddenTasks, isFalse);
      expect(capabilities.supportsAssignedTasks, isFalse);
      expect(capabilities.supportsDueTime, isTrue);
    },
  );

  testWidgets('All Tasks view shows tasks from Google and Microsoft accounts', (
    tester,
  ) async {
    _setWideViewport(tester);
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    await _insertAccount(
      database,
      id: 'google:g',
      provider: TaskProvider.google,
      displayName: 'Google User',
      email: 'google@example.com',
    );
    await _insertAccount(
      database,
      id: 'microsoft:m',
      provider: TaskProvider.microsoft,
      displayName: 'Microsoft User',
      email: 'microsoft@example.com',
    );
    await database.taskListsDao.upsertTaskList(
      _localTaskList(
        accountId: 'google:g',
        id: 'google-list',
        title: 'Google Inbox',
      ),
    );
    await database.taskListsDao.upsertTaskList(
      _localTaskList(
        accountId: 'microsoft:m',
        id: 'microsoft-list',
        title: 'Microsoft Tasks',
      ),
    );
    await database.tasksDao.upsertTask(
      _localTask(
        accountId: 'google:g',
        taskListId: 'google-list',
        id: 'google-task',
        title: 'Google task',
        dueUtc: Value(_dueUtcForDayOffset(0)),
        status: const Value('needsAction'),
      ),
    );
    await database.tasksDao.upsertTask(
      _localTask(
        accountId: 'microsoft:m',
        taskListId: 'microsoft-list',
        id: 'microsoft-task',
        title: 'Microsoft task',
        dueUtc: Value(_dueUtcForDayOffset(-1)),
        status: const Value('needsAction'),
      ),
    );

    final container = _workspaceContainer(database);
    addTearDown(container.dispose);
    await _pumpWorkspaceWithContainer(tester, container);

    final taskTree = find.byType(TaskTreeView);
    expect(find.text('All tasks'), findsWidgets);
    expect(
      find.descendant(of: taskTree, matching: find.text('Google Inbox')),
      findsNothing,
    );
    expect(
      find.descendant(of: taskTree, matching: find.text('Google User')),
      findsNothing,
    );
    expect(
      find.descendant(
        of: taskTree,
        matching: find.textContaining('Google · Google User · Google Inbox'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(of: taskTree, matching: find.text('Google task')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: taskTree, matching: find.text('Microsoft Tasks')),
      findsNothing,
    );
    expect(
      find.descendant(of: taskTree, matching: find.text('Microsoft User')),
      findsNothing,
    );
    expect(
      find.descendant(
        of: taskTree,
        matching: find.textContaining(
          'Microsoft · Microsoft User · Microsoft Tasks',
        ),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(of: taskTree, matching: find.text('Microsoft task')),
      findsOneWidget,
    );
    expect(
      tester
          .getTopLeft(
            find.descendant(
              of: taskTree,
              matching: find.text('Microsoft task'),
            ),
          )
          .dy,
      lessThan(
        tester
            .getTopLeft(
              find.descendant(of: taskTree, matching: find.text('Google task')),
            )
            .dy,
      ),
    );
    expect(find.text('Select or create a task list to begin.'), findsNothing);

    await _disposeWorkspace(tester);
  });

  testWidgets(
    'checking a Microsoft task queues and syncs the Microsoft account',
    (tester) async {
      _setWideViewport(tester);
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      await _seedTwoAccountWorkspace(database);
      final syncEngines = {
        'google:g': _FakeSyncEngine(),
        'microsoft:m': _FakeSyncEngine(),
      };

      final container = _workspaceContainerWithAccountSync(
        database,
        syncEngines,
      );
      addTearDown(container.dispose);
      await _pumpWorkspaceWithContainer(tester, container);

      await _tapTaskCheckbox(tester, 'Microsoft task');
      await _waitForQueuedMutationSync(tester);

      expect(syncEngines['microsoft:m']!.incrementalSyncCalls, 1);
      expect(syncEngines['google:g']!.incrementalSyncCalls, 0);
      expect(container.read(selectedAccountIdProvider), 'google:g');

      await _disposeWorkspace(tester);
    },
  );

  testWidgets('checking a Google task queues and syncs that Google account', (
    tester,
  ) async {
    _setWideViewport(tester);
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    await _seedTwoAccountWorkspace(database);
    final syncEngines = {
      'google:g': _FakeSyncEngine(),
      'microsoft:m': _FakeSyncEngine(),
    };

    final container = _workspaceContainerWithAccountSync(database, syncEngines);
    addTearDown(container.dispose);
    await _pumpWorkspaceWithContainer(tester, container);

    await _tapTaskCheckbox(tester, 'Google task');
    await _waitForQueuedMutationSync(tester);

    expect(syncEngines['google:g']!.incrementalSyncCalls, 1);
    expect(syncEngines['microsoft:m']!.incrementalSyncCalls, 0);

    await _disposeWorkspace(tester);
  });

  testWidgets('Refresh all in All Tasks mode syncs every signed-in account', (
    tester,
  ) async {
    _setWideViewport(tester);
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    await _seedTwoAccountWorkspace(database);
    final syncEngines = {
      'google:g': _FakeSyncEngine(),
      'microsoft:m': _FakeSyncEngine(),
    };

    final container = _workspaceContainerWithAccountSync(database, syncEngines);
    addTearDown(container.dispose);
    await _pumpWorkspaceWithContainer(tester, container);

    await tester.tap(find.byTooltip('Refresh all'));
    await tester.pumpAndSettle();

    expect(syncEngines['google:g']!.incrementalSyncCalls, 1);
    expect(syncEngines['microsoft:m']!.incrementalSyncCalls, 1);
    expect(find.text('All accounts refreshed.'), findsOneWidget);

    await _disposeWorkspace(tester);
  });

  testWidgets('Refresh all is enabled when signed-in accounts exist', (
    tester,
  ) async {
    _setWideViewport(tester);
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    await _seedTwoAccountWorkspace(database);
    final syncEngines = {
      'google:g': _FakeSyncEngine(),
      'microsoft:m': _FakeSyncEngine(),
    };

    final container = _workspaceContainerWithAccountSync(database, syncEngines);
    addTearDown(container.dispose);
    await _pumpWorkspaceWithContainer(tester, container);

    final onPressed = _toolbarActionOnPressed(
      tester,
      tooltip: 'Refresh all',
      label: 'Refresh all',
    );
    expect(onPressed == null, isFalse);

    await _disposeWorkspace(tester);
  });

  testWidgets('New task in All Tasks mode creates in chosen account/list', (
    tester,
  ) async {
    _setWideViewport(tester);
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    await _seedTwoAccountWorkspace(database);
    final syncEngines = {
      'google:g': _FakeSyncEngine(),
      'microsoft:m': _FakeSyncEngine(),
    };

    final container = _workspaceContainerWithAccountSync(database, syncEngines);
    addTearDown(container.dispose);
    await _pumpWorkspaceWithContainer(tester, container);

    final onPressed = _toolbarActionOnPressed(
      tester,
      tooltip: 'New task',
      label: 'New task',
    );
    expect(onPressed == null, isFalse);

    await tester.tap(find.byTooltip('New task'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Title'), 'All task');
    await tester.pump();
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();

    final created =
        await (database.select(database.tasks)..where(
              (row) =>
                  row.accountId.equals('google:g') &
                  row.taskListId.equals('google-list') &
                  row.title.equals('All task'),
            ))
            .get();
    expect(created, hasLength(1));

    await _disposeWorkspace(tester);
  });

  testWidgets('opening an aggregate task keeps all tasks visible', (
    tester,
  ) async {
    _setWideViewport(tester);
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    await _insertAccount(
      database,
      id: 'google:g',
      provider: TaskProvider.google,
      displayName: 'Google User',
      email: 'google@example.com',
    );
    await _insertAccount(
      database,
      id: 'microsoft:m',
      provider: TaskProvider.microsoft,
      displayName: 'Microsoft User',
      email: 'microsoft@example.com',
    );
    await database.taskListsDao.upsertTaskList(
      _localTaskList(
        accountId: 'google:g',
        id: 'google-list',
        title: 'Google Inbox',
      ),
    );
    await database.taskListsDao.upsertTaskList(
      _localTaskList(
        accountId: 'microsoft:m',
        id: 'microsoft-list',
        title: 'Microsoft Tasks',
      ),
    );
    await database.tasksDao.upsertTask(
      _localTask(
        accountId: 'google:g',
        taskListId: 'google-list',
        id: 'google-task',
        title: 'Google task',
        status: const Value('needsAction'),
      ),
    );
    await database.tasksDao.upsertTask(
      _localTask(
        accountId: 'microsoft:m',
        taskListId: 'microsoft-list',
        id: 'microsoft-task',
        title: 'Microsoft task',
        status: const Value('needsAction'),
      ),
    );

    final container = _workspaceContainer(database);
    addTearDown(container.dispose);
    await _pumpWorkspaceWithContainer(tester, container);

    await tester.tap(find.text('Microsoft task'));
    await tester.pumpAndSettle();

    expect(container.read(selectedAccountIdProvider), 'microsoft:m');
    expect(container.read(selectedTaskListIdProvider), 'microsoft-list');
    expect(container.read(selectedTaskIdProvider), 'microsoft-task');
    expect(container.read(allTasksModeProvider), isTrue);
    expect(find.byType(TaskDetailsPane), findsOneWidget);
    expect(find.byType(TaskDetailsEditor), findsOneWidget);
    final taskTree = find.byType(TaskTreeView);
    expect(
      find.descendant(of: taskTree, matching: find.text('Google task')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: taskTree, matching: find.text('Microsoft task')),
      findsOneWidget,
    );

    await _disposeWorkspace(tester);
  });

  testWidgets('wide workspace does not render persistent Task Details editor', (
    tester,
  ) async {
    _setWideViewport(tester);
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    await _seedTwoAccountWorkspace(database);

    final container = _workspaceContainer(database);
    addTearDown(container.dispose);
    container.read(selectedAccountIdProvider.notifier).state = 'google:g';
    container.read(selectedTaskListIdProvider.notifier).state = 'google-list';
    container.read(selectedTaskIdProvider.notifier).state = 'google-task';
    await _pumpWorkspaceWithContainer(tester, container);

    expect(find.byType(TaskDetailsPane), findsNothing);
    expect(find.byType(TaskDetailsEditor), findsNothing);

    await _disposeWorkspace(tester);
  });

  testWidgets(
    'wide workspace opens Task Details overlay only after task selection',
    (tester) async {
      _setWideViewport(tester);
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      await _seedTwoAccountWorkspace(database);

      final container = _workspaceContainer(database);
      addTearDown(container.dispose);
      await _pumpWorkspaceWithContainer(tester, container);

      expect(find.byType(TaskDetailsPane), findsNothing);
      expect(find.byType(TaskDetailsEditor), findsNothing);

      await tester.tap(find.text('Microsoft task'));
      await tester.pumpAndSettle();

      expect(find.byType(TaskDetailsPane), findsOneWidget);
      expect(find.byType(TaskDetailsEditor), findsOneWidget);
      expect(find.byType(ModalBarrier), findsWidgets);

      await _disposeWorkspace(tester);
    },
  );

  testWidgets('Task Details overlay is clamped around editor width', (
    tester,
  ) async {
    _setTallWideViewport(tester);
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    await _seedTwoAccountWorkspace(database);

    final container = _workspaceContainer(database);
    addTearDown(container.dispose);
    await _pumpWorkspaceWithContainer(tester, container);

    await tester.tap(find.text('Microsoft task'));
    await tester.pumpAndSettle();

    final paneSize = tester.getSize(find.byType(TaskDetailsPane));
    expect(paneSize.width, closeTo(BusyMaxSizes.compactDetailsWidth, 1));
    expect(paneSize.width, lessThan(tester.view.physicalSize.width));

    await _disposeWorkspace(tester);
  });

  testWidgets(
    'medium workspace does not show inspector button for selected task',
    (tester) async {
      _setMediumViewport(tester);
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      await _seedTwoAccountWorkspace(database);

      final container = _workspaceContainer(database);
      addTearDown(container.dispose);
      container.read(selectedAccountIdProvider.notifier).state = 'google:g';
      container.read(selectedTaskListIdProvider.notifier).state = 'google-list';
      container.read(selectedTaskIdProvider.notifier).state = 'google-task';
      await _pumpWorkspaceWithContainer(tester, container);

      expect(find.byTooltip('Task details'), findsNothing);
      expect(find.byType(TaskDetailsPane), findsNothing);
      expect(find.byType(TaskDetailsEditor), findsNothing);

      await _disposeWorkspace(tester);
    },
  );

  testWidgets('medium task selection opens Task Details overlay', (
    tester,
  ) async {
    _setMediumViewport(tester);
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    await _seedTwoAccountWorkspace(database);

    final container = _workspaceContainer(database);
    addTearDown(container.dispose);
    await _pumpWorkspaceWithContainer(tester, container);

    await tester.tap(find.text('Google task'));
    await tester.pumpAndSettle();

    expect(find.byType(TaskDetailsPane), findsOneWidget);
    expect(find.byType(TaskDetailsEditor), findsOneWidget);
    expect(find.byType(ModalBarrier), findsWidgets);

    await _disposeWorkspace(tester);
  });

  testWidgets('Escape closes medium Task Details overlay', (tester) async {
    _setMediumViewport(tester);
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    await _seedTwoAccountWorkspace(database);

    final container = _workspaceContainer(database);
    addTearDown(container.dispose);
    await _pumpWorkspaceWithContainer(tester, container);

    await tester.tap(find.text('Google task'));
    await tester.pumpAndSettle();
    expect(find.byType(TaskDetailsEditor), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(find.byType(TaskDetailsPane), findsNothing);
    expect(find.byType(TaskDetailsEditor), findsNothing);
    expect(container.read(selectedTaskIdProvider), 'google-task');

    await _disposeWorkspace(tester);
  });

  testWidgets(
    'saving All Tasks pane edits task account, not selected account',
    (tester) async {
      _setTallWideViewport(tester);
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      await _seedTwoAccountWorkspace(database);

      final container = _workspaceContainer(database);
      addTearDown(container.dispose);
      await _pumpWorkspaceWithContainer(tester, container);

      expect(container.read(selectedAccountIdProvider), 'google:g');

      await tester.tap(find.text('Microsoft task'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find
            .descendant(
              of: find.byType(TaskDetailsPane),
              matching: find.byType(TextField),
            )
            .first,
        'Renamed Microsoft',
      );
      await tester.pump();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      final microsoftTask =
          await (database.select(database.tasks)..where(
                (row) =>
                    row.accountId.equals('microsoft:m') &
                    row.id.equals('microsoft-task'),
              ))
              .getSingle();
      final googleTask =
          await (database.select(database.tasks)..where(
                (row) =>
                    row.accountId.equals('google:g') &
                    row.id.equals('google-task'),
              ))
              .getSingle();

      expect(microsoftTask.title, 'Renamed Microsoft');
      expect(googleTask.title, 'Google task');

      await _disposeWorkspace(tester);
    },
  );

  testWidgets('list-mode task opens details pane scoped to selected account', (
    tester,
  ) async {
    _setWideViewport(tester);
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    await _seedTwoAccountWorkspace(database);

    final container = _workspaceContainer(database);
    addTearDown(container.dispose);
    container.read(allTasksModeProvider.notifier).state = false;
    container.read(selectedAccountIdProvider.notifier).state = 'google:g';
    container.read(selectedTaskListIdProvider.notifier).state = 'google-list';
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: localizedTestApp(
          child: const TasksWorkspace(selectedListId: 'google-list'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Google task'));
    await tester.pumpAndSettle();

    expect(find.byType(TaskDetailsPane), findsOneWidget);
    expect(find.byType(TaskDetailsEditor), findsOneWidget);
    expect(container.read(selectedAccountIdProvider), 'google:g');
    expect(container.read(selectedTaskListIdProvider), 'google-list');
    expect(container.read(selectedTaskIdProvider), 'google-task');
    expect(container.read(allTasksModeProvider), isFalse);

    await _disposeWorkspace(tester);
  });

  testWidgets(
    'Refresh list invokes sync instead of task list metadata refresh',
    (tester) async {
      _setCompactViewport(tester);
      final syncEngine = _FakeSyncEngine();
      final listsRepository = _FakeTaskListsRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            taskListsRepositoryProvider.overrideWithValue(listsRepository),
            tasksRepositoryProvider.overrideWithValue(_FakeTasksRepository()),
            syncEngineProvider.overrideWithValue(syncEngine),
          ],
          child: localizedTestApp(
            child: const TasksWorkspace(selectedListId: 'list-1'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Refresh list'));
      await tester.pumpAndSettle();

      expect(syncEngine.incrementalSyncCalls, 1);
      expect(listsRepository.refreshTaskListCalls, 0);
      expect(find.text('List refreshed.'), findsOneWidget);
      await _disposeWorkspace(tester);
    },
  );

  testWidgets('Refresh list pulls remote completed task into local tree', (
    tester,
  ) async {
    _setCompactViewport(tester);
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    await _insertAccount(database);
    await database.taskListsDao.upsertTaskList(_localTaskList());
    await database.tasksDao.upsertTask(
      _localTask(status: const Value('needsAction')),
    );
    final apiClient = _FakeGoogleTasksApiClient()
      ..taskListsPages = [
        TaskListsPageDto(items: [_taskListDto('list-1')], rawJson: const {}),
      ]
      ..taskPages['list-1'] = [
        TasksPageDto(
          items: [
            TaskDto(
              id: 'task-2',
              title: 'Task 2',
              status: 'completed',
              completed: DateTime.utc(2026, 6, 4, 12),
              rawJson: const {
                'id': 'task-2',
                'title': 'Task 2',
                'status': 'completed',
                'completed': '2026-06-04T12:00:00.000Z',
              },
            ),
          ],
          rawJson: const {},
        ),
      ];

    await _pumpWorkspace(
      tester,
      database: database,
      syncEngine: SyncEngine(
        database: database,
        apiClient: apiClient,
        accountId: 'account',
        nowUtc: () => DateTime.utc(2026, 6, 4),
      ),
    );

    expect(find.text('Task 2'), findsOneWidget);
    expect(
      tester.widget<YaruCheckbox>(find.byType(YaruCheckbox)).value,
      isFalse,
    );

    await tester.tap(find.byTooltip('Refresh list'));
    await tester.pumpAndSettle();

    final task =
        await (database.select(database.tasks)..where(
              (row) =>
                  row.accountId.equals('account') &
                  row.taskListId.equals('list-1') &
                  row.id.equals('task-2'),
            ))
            .getSingle();
    expect(task.status, 'completed');
    expect(task.localDirty, isFalse);
    expect(apiClient.listTasksPageCalls, 1);
    expect(
      tester.widget<YaruCheckbox>(find.byType(YaruCheckbox)).value,
      isTrue,
    );
    await _disposeWorkspace(tester);
  });

  testWidgets('search filters tasks by title in list mode', (tester) async {
    _setCompactViewport(tester);
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    await _insertAccount(database);
    await database.taskListsDao.upsertTaskList(_localTaskList());
    await database.tasksDao.upsertTask(
      _localTask(
        id: 'task-alpha',
        title: 'Alpha plan',
        status: const Value('needsAction'),
      ),
    );
    await database.tasksDao.upsertTask(
      _localTask(
        id: 'task-beta',
        title: 'Beta task',
        status: const Value('needsAction'),
      ),
    );

    await _pumpWorkspace(
      tester,
      database: database,
      syncEngine: _FakeSyncEngine(),
    );

    await tester.enterText(find.byType(TextField).first, 'alpha');
    await tester.pumpAndSettle();

    expect(find.text('Alpha plan'), findsOneWidget);
    expect(find.text('Beta task'), findsNothing);
    await _disposeWorkspace(tester);
  });

  testWidgets('search filters tasks by notes and body in list mode', (
    tester,
  ) async {
    _setCompactViewport(tester);
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    await _insertAccount(database);
    await database.taskListsDao.upsertTaskList(_localTaskList());
    await database.tasksDao.upsertTask(
      _localTask(
        id: 'task-notes',
        title: 'General task',
        notes: const Value('Private note marker'),
        status: const Value('needsAction'),
      ),
    );
    await database.tasksDao.upsertTask(
      _localTask(
        id: 'task-body',
        title: 'Body task',
        bodyContent: const Value('Body marker'),
        status: const Value('needsAction'),
      ),
    );

    await _pumpWorkspace(
      tester,
      database: database,
      syncEngine: _FakeSyncEngine(),
    );

    await tester.enterText(find.byType(TextField).first, 'body marker');
    await tester.pumpAndSettle();

    expect(find.text('Body task'), findsOneWidget);
    expect(find.text('General task'), findsNothing);
    await _disposeWorkspace(tester);
  });

  testWidgets('search works in All Tasks mode and clearing restores rows', (
    tester,
  ) async {
    _setWideViewport(tester);
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    await _seedTwoAccountWorkspace(database);

    final container = _workspaceContainer(database);
    addTearDown(container.dispose);
    await _pumpWorkspaceWithContainer(tester, container);

    await tester.enterText(find.byType(TextField).first, 'microsoft');
    await tester.pumpAndSettle();

    expect(find.text('Microsoft task'), findsOneWidget);
    expect(find.text('Google task'), findsNothing);

    await tester.tap(find.byIcon(YaruIcons.edit_clear).first);
    await tester.pumpAndSettle();

    expect(find.text('Microsoft task'), findsOneWidget);
    expect(find.text('Google task'), findsOneWidget);
    await _disposeWorkspace(tester);
  });

  testWidgets('empty search results do not render boxed call to action', (
    tester,
  ) async {
    _setWideViewport(tester);
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    await _seedTwoAccountWorkspace(database);

    final container = _workspaceContainer(database);
    addTearDown(container.dispose);
    await _pumpWorkspaceWithContainer(tester, container);

    await tester.enterText(find.byType(TextField).first, 'no matching task');
    await tester.pumpAndSettle();

    final taskTree = find.byType(TaskTreeView);
    expect(
      find.descendant(of: taskTree, matching: find.byType(YaruInfoBox)),
      findsNothing,
    );
    expect(
      find.descendant(of: taskTree, matching: find.text('No tasks yet')),
      findsNothing,
    );
    expect(
      find.descendant(of: taskTree, matching: find.text('No tasks.')),
      findsOneWidget,
    );
    await _disposeWorkspace(tester);
  });

  testWidgets('All Tasks groups tasks by due bucket', (tester) async {
    _setWideViewport(tester);
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    await _seedTwoAccountWorkspace(database);

    final container = _workspaceContainer(database);
    addTearDown(container.dispose);
    await _pumpWorkspaceWithContainer(tester, container);

    expect(find.text('Overdue'), findsOneWidget);
    expect(find.text('Today'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Overdue')).dy,
      lessThan(tester.getTopLeft(find.text('Today')).dy),
    );
    await _disposeWorkspace(tester);
  });

  testWidgets(
    'All Tasks orders buckets and rows by due, title, source, and id',
    (tester) async {
      _setTallWideViewport(tester);
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      await _insertAccount(
        database,
        id: 'google:g',
        provider: TaskProvider.google,
        displayName: 'Google User',
        email: 'google@example.com',
      );
      await _insertAccount(
        database,
        id: 'microsoft:m',
        provider: TaskProvider.microsoft,
        displayName: 'Microsoft User',
        email: 'microsoft@example.com',
      );
      await database.taskListsDao.upsertTaskList(
        _localTaskList(
          accountId: 'google:g',
          id: 'google-list',
          title: 'Google Inbox',
        ),
      );
      await database.taskListsDao.upsertTaskList(
        _localTaskList(
          accountId: 'microsoft:m',
          id: 'microsoft-list',
          title: 'Microsoft Tasks',
        ),
      );
      await database.tasksDao.upsertTask(
        _localTask(
          accountId: 'google:g',
          taskListId: 'google-list',
          id: 'overdue',
          title: 'Overdue task',
          dueUtc: Value(_dueUtcForDayOffset(-1)),
          status: const Value('needsAction'),
        ),
      );
      await database.tasksDao.upsertTask(
        _localTask(
          accountId: 'microsoft:m',
          taskListId: 'microsoft-list',
          id: 'today-alpha',
          title: 'Alpha today',
          dueUtc: Value(_dueUtcForDayOffset(0)),
          status: const Value('needsAction'),
        ),
      );
      await database.tasksDao.upsertTask(
        _localTask(
          accountId: 'google:g',
          taskListId: 'google-list',
          id: 'today-same-a',
          title: 'Same today',
          dueUtc: Value(_dueUtcForDayOffset(0)),
          status: const Value('needsAction'),
        ),
      );
      await database.tasksDao.upsertTask(
        _localTask(
          accountId: 'google:g',
          taskListId: 'google-list',
          id: 'today-same-b',
          title: 'Same today',
          dueUtc: Value(_dueUtcForDayOffset(0)),
          status: const Value('needsAction'),
        ),
      );
      await database.tasksDao.upsertTask(
        _localTask(
          accountId: 'microsoft:m',
          taskListId: 'microsoft-list',
          id: 'today-same-microsoft',
          title: 'Same today',
          dueUtc: Value(_dueUtcForDayOffset(0)),
          status: const Value('needsAction'),
        ),
      );
      await database.tasksDao.upsertTask(
        _localTask(
          accountId: 'google:g',
          taskListId: 'google-list',
          id: 'tomorrow',
          title: 'Tomorrow task',
          dueUtc: Value(_dueUtcForDayOffset(1)),
          status: const Value('needsAction'),
        ),
      );
      await database.tasksDao.upsertTask(
        _localTask(
          accountId: 'microsoft:m',
          taskListId: 'microsoft-list',
          id: 'upcoming',
          title: 'Upcoming task',
          dueUtc: Value(_dueUtcForDayOffset(2)),
          status: const Value('needsAction'),
        ),
      );
      await database.tasksDao.upsertTask(
        _localTask(
          accountId: 'google:g',
          taskListId: 'google-list',
          id: 'no-date',
          title: 'No date task',
          status: const Value('needsAction'),
        ),
      );
      await database.tasksDao.upsertTask(
        _localTask(
          accountId: 'microsoft:m',
          taskListId: 'microsoft-list',
          id: 'completed',
          title: 'Completed task',
          dueUtc: Value(_dueUtcForDayOffset(-1)),
          status: const Value('completed'),
        ),
      );

      final container = _workspaceContainer(database);
      addTearDown(container.dispose);
      await _pumpWorkspaceWithContainer(tester, container);

      expect(
        _top(tester, find.text('Overdue')),
        lessThan(_top(tester, find.text('Today'))),
      );
      expect(
        _top(tester, find.text('Today')),
        lessThan(_top(tester, find.text('Tomorrow'))),
      );
      expect(
        _top(tester, find.text('Tomorrow')),
        lessThan(_top(tester, find.text('Upcoming'))),
      );
      expect(
        _top(tester, find.text('Upcoming')),
        lessThan(_top(tester, find.text('No date'))),
      );
      expect(
        _top(tester, find.text('No date')),
        lessThan(_top(tester, find.text('Completed'))),
      );
      expect(
        _top(tester, find.text('Completed')),
        lessThan(
          _top(
            tester,
            find.byKey(
              const ValueKey('task-row-microsoft:m/microsoft-list/completed'),
            ),
          ),
        ),
      );
      expect(
        find.textContaining('Google · Google User · Google Inbox'),
        findsWidgets,
      );
      expect(
        find.textContaining('Microsoft · Microsoft User · Microsoft Tasks'),
        findsWidgets,
      );
      expect(
        _rowTop(tester, 'microsoft:m', 'microsoft-list', 'today-alpha'),
        lessThan(_rowTop(tester, 'google:g', 'google-list', 'today-same-a')),
      );
      expect(
        _rowTop(tester, 'google:g', 'google-list', 'today-same-a'),
        lessThan(_rowTop(tester, 'google:g', 'google-list', 'today-same-b')),
      );
      expect(
        _rowTop(tester, 'google:g', 'google-list', 'today-same-b'),
        lessThan(
          _rowTop(
            tester,
            'microsoft:m',
            'microsoft-list',
            'today-same-microsoft',
          ),
        ),
      );

      await _disposeWorkspace(tester);
    },
  );

  testWidgets('Refresh failure is shown in a snackbar', (tester) async {
    _setCompactViewport(tester);
    final syncEngine = _FakeSyncEngine()..error = StateError('refresh failed');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          taskListsRepositoryProvider.overrideWithValue(
            _FakeTaskListsRepository(),
          ),
          tasksRepositoryProvider.overrideWithValue(_FakeTasksRepository()),
          syncEngineProvider.overrideWithValue(syncEngine),
        ],
        child: localizedTestApp(
          child: const TasksWorkspace(selectedListId: 'list-1'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Refresh list'));
    await tester.pumpAndSettle();

    expect(syncEngine.incrementalSyncCalls, 1);
    expect(find.textContaining('Refresh failed:'), findsOneWidget);
    expect(find.textContaining('refresh failed'), findsOneWidget);
    await _disposeWorkspace(tester);
  });

  testWidgets('Clear completed is enabled for Google capabilities', (
    tester,
  ) async {
    _setCompactViewport(tester);
    final tasksRepository = _FakeTasksRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          selectedAccountCapabilitiesProvider.overrideWithValue(
            googleTaskProviderCapabilities,
          ),
          taskListsRepositoryProvider.overrideWithValue(
            _FakeTaskListsRepository(),
          ),
          tasksRepositoryProvider.overrideWithValue(tasksRepository),
          syncEngineProvider.overrideWithValue(_FakeSyncEngine()),
        ],
        child: localizedTestApp(
          child: const TasksWorkspace(selectedListId: 'list-1'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Clear completed'));
    await tester.pumpAndSettle();

    expect(tasksRepository.clearCompletedCalls, ['list-1']);
    await _disposeWorkspace(tester);
  });

  testWidgets('Clear completed is hidden for Microsoft capabilities', (
    tester,
  ) async {
    _setCompactViewport(tester);
    final tasksRepository = _FakeTasksRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          selectedAccountCapabilitiesProvider.overrideWithValue(
            microsoftTaskProviderCapabilities,
          ),
          taskListsRepositoryProvider.overrideWithValue(
            _FakeTaskListsRepository(),
          ),
          tasksRepositoryProvider.overrideWithValue(tasksRepository),
          syncEngineProvider.overrideWithValue(_FakeSyncEngine()),
        ],
        child: localizedTestApp(
          child: const TasksWorkspace(selectedListId: 'list-1'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byTooltip('Clear completed'), findsNothing);

    expect(tasksRepository.clearCompletedCalls, isEmpty);
    await _disposeWorkspace(tester);
  });
}

void _setCompactViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(600, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

void _setMediumViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(900, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

void _setWideViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(1280, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

void _setTallWideViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(1280, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

Future<void> _disposeWorkspace(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(milliseconds: 1));
}

Future<void> _pumpWorkspace(
  WidgetTester tester, {
  required AppDatabase database,
  required SyncEngine syncEngine,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        taskListsRepositoryProvider.overrideWithValue(
          TaskListsRepository(database: database, accountId: 'account'),
        ),
        tasksRepositoryProvider.overrideWithValue(
          TasksRepository(database: database, accountId: 'account'),
        ),
        syncEngineProvider.overrideWithValue(syncEngine),
      ],
      child: localizedTestApp(
        child: const TasksWorkspace(selectedListId: 'list-1'),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

ProviderContainer _workspaceContainer(AppDatabase database) {
  final container = ProviderContainer(
    overrides: [
      databaseProvider.overrideWithValue(database),
      accountsStreamProvider.overrideWith((ref) {
        final query = database.select(database.accounts)
          ..where((row) => row.authState.equals('signed_in'));
        return query.watch().map(
          (rows) => rows.map(AccountEntity.fromRow).toList(),
        );
      }),
      taskListsRepositoryProvider.overrideWithValue(
        TaskListsRepository(database: database, accountId: 'google:g'),
      ),
      tasksRepositoryProvider.overrideWithValue(
        TasksRepository(database: database, accountId: 'google:g'),
      ),
      taskListsRepositoryForAccountProvider.overrideWith((ref, accountId) {
        return TaskListsRepository(database: database, accountId: accountId);
      }),
      tasksRepositoryForAccountProvider.overrideWith((ref, accountId) {
        return TasksRepository(database: database, accountId: accountId);
      }),
      syncEngineProvider.overrideWithValue(null),
      signedInSyncRunnerProvider.overrideWithValue((accountId, initial) async {
        return;
      }),
    ],
  );
  container.read(selectedAccountIdProvider.notifier).state = 'google:g';
  return container;
}

ProviderContainer _workspaceContainerWithAccountSync(
  AppDatabase database,
  Map<String, _FakeSyncEngine> syncEngines,
) {
  final apiClients = <String, _FakeGoogleTasksApiClient>{};
  final container = ProviderContainer(
    overrides: [
      databaseProvider.overrideWithValue(database),
      accountsStreamProvider.overrideWith((ref) {
        final query = database.select(database.accounts)
          ..where((row) => row.authState.equals('signed_in'));
        return query.watch().map(
          (rows) => rows.map(AccountEntity.fromRow).toList(),
        );
      }),
      tasksRepositoryProvider.overrideWithValue(
        TasksRepository(database: database, accountId: 'google:g'),
      ),
      syncEngineProvider.overrideWithValue(null),
      syncEngineForAccountFactoryProvider.overrideWithValue((accountId) {
        return syncEngines[accountId]!;
      }),
      googleTasksApiClientForAccountProvider.overrideWith((ref, accountId) {
        return apiClients.putIfAbsent(accountId, _FakeGoogleTasksApiClient.new);
      }),
      microsoftAsGoogleTasksApiClientForAccountProvider.overrideWith((
        ref,
        accountId,
      ) {
        return apiClients.putIfAbsent(accountId, _FakeGoogleTasksApiClient.new);
      }),
      desktopNotificationBackendProvider.overrideWithValue(
        _FakeNotificationBackend(),
      ),
      signedInSyncRunnerProvider.overrideWithValue((accountId, initial) async {
        return;
      }),
    ],
  );
  container.read(selectedAccountIdProvider.notifier).state = 'google:g';
  return container;
}

Future<void> _pumpWorkspaceWithContainer(
  WidgetTester tester,
  ProviderContainer container,
) async {
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: localizedTestApp(child: const TasksWorkspace()),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _tapTaskCheckbox(WidgetTester tester, String taskTitle) async {
  final tile = find.ancestor(
    of: find.text(taskTitle),
    matching: find.byType(YaruListTile),
  );
  await tester.tap(
    find.descendant(of: tile, matching: find.byType(YaruCheckbox)),
  );
  await tester.pump();
}

Future<void> _waitForQueuedMutationSync(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 350));
  await tester.pump();
}

VoidCallback? _toolbarActionOnPressed(
  WidgetTester tester, {
  required String tooltip,
  required String label,
}) {
  final iconButton = find.byWidgetPredicate(
    (widget) => widget is YaruIconButton && widget.tooltip == tooltip,
  );
  if (iconButton.evaluate().isNotEmpty) {
    return tester.widget<YaruIconButton>(iconButton).onPressed;
  }

  final button = find.ancestor(
    of: find.text(label),
    matching: find.byWidgetPredicate((widget) => widget is ButtonStyleButton),
  );
  return tester.widget<ButtonStyleButton>(button).onPressed;
}

double _top(WidgetTester tester, Finder finder) {
  return tester.getTopLeft(finder).dy;
}

double _rowTop(
  WidgetTester tester,
  String accountId,
  String taskListId,
  String taskId,
) {
  return _top(
    tester,
    find.byKey(ValueKey('task-row-$accountId/$taskListId/$taskId')),
  );
}

Future<void> _seedTwoAccountWorkspace(AppDatabase database) async {
  await _insertAccount(
    database,
    id: 'google:g',
    provider: TaskProvider.google,
    displayName: 'Google User',
    email: 'google@example.com',
  );
  await _insertAccount(
    database,
    id: 'microsoft:m',
    provider: TaskProvider.microsoft,
    displayName: 'Microsoft User',
    email: 'microsoft@example.com',
  );
  await database.taskListsDao.upsertTaskList(
    _localTaskList(
      accountId: 'google:g',
      id: 'google-list',
      title: 'Google Inbox',
    ),
  );
  await database.taskListsDao.upsertTaskList(
    _localTaskList(
      accountId: 'microsoft:m',
      id: 'microsoft-list',
      title: 'Microsoft Tasks',
    ),
  );
  await database.tasksDao.upsertTask(
    _localTask(
      accountId: 'google:g',
      taskListId: 'google-list',
      id: 'google-task',
      title: 'Google task',
      dueUtc: Value(_dueUtcForDayOffset(0)),
      status: const Value('needsAction'),
    ),
  );
  await database.tasksDao.upsertTask(
    _localTask(
      accountId: 'microsoft:m',
      taskListId: 'microsoft-list',
      id: 'microsoft-task',
      title: 'Microsoft task',
      dueUtc: Value(_dueUtcForDayOffset(-1)),
      status: const Value('needsAction'),
    ),
  );
}

String _dueUtcForDayOffset(int dayOffset) {
  final now = DateTime.now();
  final date = DateTime(
    now.year,
    now.month,
    now.day,
  ).add(Duration(days: dayOffset));
  final year = date.year.toString().padLeft(4, '0');
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '$year-$month-${day}T00:00:00.000Z';
}

Future<void> _insertAccount(
  AppDatabase database, {
  String id = 'account',
  TaskProvider provider = TaskProvider.google,
  String? displayName,
  String? email,
}) {
  return database
      .into(database.accounts)
      .insert(
        AccountsCompanion.insert(
          id: id,
          provider: Value(provider.storageValue),
          displayName: Value(displayName),
          email: Value(email),
          authState: const Value('signed_in'),
          createdAtUtc: _now,
          updatedAtUtc: _now,
        ),
      );
}

AccountEntity _accountEntity({
  required String id,
  required TaskProvider provider,
}) {
  return AccountEntity(id: id, provider: provider, authState: 'signed_in');
}

TaskListsCompanion _localTaskList({
  String accountId = 'account',
  String id = 'list-1',
  String title = 'Inbox',
}) {
  return TaskListsCompanion.insert(
    accountId: accountId,
    id: id,
    title: title,
    rawJson: '{}',
    createdLocalAtUtc: _now,
    updatedLocalAtUtc: _now,
  );
}

TasksCompanion _localTask({
  String accountId = 'account',
  String taskListId = 'list-1',
  String id = 'task-2',
  String title = 'Task 2',
  Value<String?> notes = const Value.absent(),
  Value<String?> bodyContent = const Value.absent(),
  Value<String?> dueUtc = const Value.absent(),
  required Value<String?> status,
}) {
  return TasksCompanion.insert(
    accountId: accountId,
    taskListId: taskListId,
    id: id,
    title: title,
    notes: notes,
    status: status,
    dueUtc: dueUtc,
    bodyContent: bodyContent,
    rawJson: '{"id":"$id","title":"$title"}',
    createdLocalAtUtc: _now,
    updatedLocalAtUtc: _now,
  );
}

TaskListDto _taskListDto(String id) {
  return TaskListDto(
    id: id,
    title: 'Inbox',
    rawJson: {'id': id, 'title': 'Inbox'},
  );
}

const _now = '2026-06-04T00:00:00.000Z';

class _FakeSyncEngine implements SyncEngine {
  var incrementalSyncCalls = 0;
  Object? error;

  @override
  Future<void> fullSync() async {}

  @override
  Future<void> incrementalSync() async {
    incrementalSyncCalls += 1;
    final failure = error;
    if (failure != null) {
      throw failure;
    }
  }
}

class _FakeTaskListsRepository implements TaskListsRepository {
  var refreshTaskListCalls = 0;

  @override
  Stream<List<TaskListEntity>> watchTaskLists() {
    return Stream.value(const [
      TaskListEntity(
        accountId: 'account',
        id: 'list-1',
        title: 'Inbox',
        localDirty: false,
        pendingDelete: false,
        rawJson: '{}',
      ),
    ]);
  }

  @override
  Stream<TaskListEntity?> watchTaskList(String id) {
    return Stream.value(
      const TaskListEntity(
        accountId: 'account',
        id: 'list-1',
        title: 'Inbox',
        localDirty: false,
        pendingDelete: false,
        rawJson: '{}',
      ),
    );
  }

  @override
  Future<void> refreshTaskList(String id) async {
    refreshTaskListCalls += 1;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeTasksRepository implements TasksRepository {
  final clearCompletedCalls = <String>[];

  @override
  Stream<List<TaskTreeNode>> watchTaskTree(
    String taskListId,
    TaskViewFilter filter,
  ) {
    return Stream.value(const <TaskTreeNode>[]);
  }

  @override
  Future<void> clearCompleted(String taskListId) async {
    clearCompletedCalls.add(taskListId);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeGoogleTasksApiClient implements GoogleTasksApiClient {
  var taskListsPages = <TaskListsPageDto>[];
  final taskPages = <String, List<TasksPageDto>>{};
  var listTasksPageCalls = 0;
  var _taskListPageIndex = 0;
  final _taskPageIndexes = <String, int>{};

  @override
  Future<TaskListsPageDto> listTaskListsPage({
    int maxResults = 1000,
    String? pageToken,
  }) async {
    return taskListsPages[_taskListPageIndex++];
  }

  @override
  Future<TasksPageDto> listTasksPage({
    required String taskListId,
    DateTime? completedMax,
    DateTime? completedMin,
    DateTime? dueMax,
    DateTime? dueMin,
    int maxResults = 100,
    String? pageToken,
    bool showCompleted = true,
    bool showDeleted = false,
    bool showHidden = false,
    DateTime? updatedMin,
    bool showAssigned = false,
  }) async {
    listTasksPageCalls += 1;
    final index = _taskPageIndexes.update(
      taskListId,
      (value) => value + 1,
      ifAbsent: () => 0,
    );
    return taskPages[taskListId]![index];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeNotificationBackend implements DesktopNotificationBackend {
  @override
  Future<void> close() async {}

  @override
  Future<void> notify(
    String summary, {
    String body = '',
    List<NotificationHint> hints = const [],
  }) async {}
}

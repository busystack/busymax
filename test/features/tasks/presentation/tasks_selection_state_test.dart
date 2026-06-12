import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:busymax/src/app/app_bootstrap.dart';
import 'package:busymax/src/features/accounts/data/accounts_repository.dart';
import 'package:busymax/src/features/task_lists/data/task_lists_repository.dart';
import 'package:busymax/src/features/task_lists/presentation/task_lists_sidebar.dart';
import 'package:busymax/src/features/tasks/data/tasks_repository.dart';
import 'package:busymax/src/features/tasks/presentation/task_details_pane.dart';
import 'package:busymax/src/features/tasks/presentation/tasks_selection_state.dart';
import 'package:busymax/src/features/tasks/presentation/tasks_workspace.dart';
import 'package:busymax/src/task_providers/task_provider.dart';
import 'package:yaru/yaru.dart';
import '../../../test_localized_app.dart';

void main() {
  testWidgets('clicking a task list updates selected list provider', (
    tester,
  ) async {
    final container = await _container();
    await _pumpSidebar(tester, container);

    await tester.tap(find.text('List A'));
    await tester.pump();

    expect(container.read(selectedTaskListIdProvider), 'list-a');
  });

  testWidgets('clicking a task list does not require GoRouter navigation', (
    tester,
  ) async {
    final container = await _container();
    await _pumpSidebar(tester, container);

    await tester.tap(find.text('List A'));
    await tester.pump();

    expect(tester.takeException(), isNull);
  });

  testWidgets('sidebar remains mounted after selecting a list', (tester) async {
    final container = await _container();
    await _pumpSidebar(tester, container);

    expect(find.byType(TaskListsSidebar), findsOneWidget);

    await tester.tap(
      find.descendant(
        of: find.byType(TaskListsSidebar),
        matching: find.text('List B'),
      ),
    );
    await tester.pump();

    expect(find.byType(TaskListsSidebar), findsOneWidget);
    expect(container.read(selectedTaskListIdProvider), 'list-b');
  });

  testWidgets('sidebar renders logo, All tasks row, and accounts header', (
    tester,
  ) async {
    final container = await _container();
    await _pumpSidebar(tester, container);

    expect(find.byType(Image), findsOneWidget);
    expect(find.text('Navigation'), findsNothing);
    expect(find.text('All tasks'), findsOneWidget);
    expect(find.text('Accounts'), findsOneWidget);
    expect(find.byTooltip('New list'), findsOneWidget);
  });

  testWidgets('sidebar header does not overflow when constrained', (
    tester,
  ) async {
    final container = await _container();
    await _pumpSidebar(tester, container, width: 220);

    expect(tester.takeException(), isNull);
  });

  testWidgets('sidebar renders open account accordion', (tester) async {
    final container = await _container(
      accounts: const [
        AccountEntity(
          id: 'google:a',
          provider: TaskProvider.google,
          authState: 'signed_in',
          displayName: 'Ada',
          email: 'ada@example.com',
        ),
      ],
    );
    await _pumpSidebar(tester, container);

    expect(find.text('Google Tasks'), findsOneWidget);
    expect(find.text('Ada · ada@example.com'), findsOneWidget);
    expect(find.text('List A'), findsOneWidget);
    expect(find.text('List B'), findsOneWidget);
    expect(find.byType(Card), findsNothing);
    expect(find.byTooltip('Switch account'), findsNothing);
    expect(find.text('Add Google account'), findsNothing);
  });

  testWidgets(
    'Google account header with no email uses stored account identity',
    (tester) async {
      final container = await _container(
        accounts: const [
          AccountEntity(
            id: 'google:a',
            provider: TaskProvider.google,
            authState: 'signed_in',
            providerAccountId: 'ada@gmail.com',
            displayName: 'Google',
          ),
        ],
      );
      await _pumpSidebar(tester, container);

      expect(find.text('Google Tasks'), findsOneWidget);
      expect(find.text('ada@gmail.com'), findsOneWidget);
      expect(find.text('Signed in'), findsNothing);
      expect(find.text('Google'), findsNothing);
    },
  );

  testWidgets('Google account header does not show generated account id', (
    tester,
  ) async {
    final container = await _container(
      accounts: const [
        AccountEntity(
          id: 'google-abc123',
          provider: TaskProvider.google,
          authState: 'signed_in',
          displayName: 'Google',
        ),
      ],
    );
    await _pumpSidebar(tester, container);

    expect(find.text('Google Tasks'), findsOneWidget);
    expect(find.text('google-abc123'), findsNothing);
    expect(find.text('Signed in'), findsOneWidget);
    expect(find.text('Google'), findsNothing);
  });

  testWidgets('Microsoft account header shows provider and account identity', (
    tester,
  ) async {
    final container = await _container(accounts: const [_microsoftAccount]);
    await _pumpSidebar(tester, container);

    expect(find.text('Microsoft To Do'), findsOneWidget);
    expect(find.text('Microsoft User · microsoft@example.com'), findsOneWidget);
    expect(find.text('Microsoft'), findsNothing);
  });

  testWidgets('account accordion collapses and expands task lists', (
    tester,
  ) async {
    final container = await _container();
    await _pumpSidebar(tester, container);

    expect(find.text('List A'), findsOneWidget);
    expect(find.text('List B'), findsOneWidget);

    await tester.tap(find.text('Google Tasks'));
    await tester.pumpAndSettle();

    expect(find.text('List A'), findsNothing);
    expect(find.text('List B'), findsNothing);

    await tester.tap(find.text('Google Tasks'));
    await tester.pumpAndSettle();

    expect(find.text('List A'), findsOneWidget);
    expect(find.text('List B'), findsOneWidget);
  });

  testWidgets('sidebar groups task lists under each account', (tester) async {
    final container = await _container(
      accounts: const [_googleAccount, _microsoftAccount],
      taskListsByAccount: const {
        'google:g': [_TaskListSeed(id: 'google-list', title: 'Google Inbox')],
        'microsoft:m': [
          _TaskListSeed(id: 'microsoft-list', title: 'Microsoft Tasks'),
        ],
      },
    );
    await _pumpSidebar(tester, container);

    expect(find.text('Google Tasks'), findsOneWidget);
    expect(find.text('Google User · google@example.com'), findsOneWidget);
    expect(find.text('Microsoft To Do'), findsOneWidget);
    expect(find.text('Microsoft User · microsoft@example.com'), findsOneWidget);
    expect(find.text('Google Inbox'), findsOneWidget);
    expect(find.text('Microsoft Tasks'), findsOneWidget);

    await tester.tap(find.text('Microsoft Tasks'));
    await tester.pump();

    expect(container.read(selectedAccountIdProvider), 'microsoft:m');
    expect(container.read(selectedTaskListIdProvider), 'microsoft-list');
  });

  testWidgets('clicking All tasks returns to All Tasks mode after a list', (
    tester,
  ) async {
    final container = await _container();
    await _pumpSidebar(tester, container);

    await tester.tap(find.text('List A'));
    await tester.pump();

    expect(container.read(allTasksModeProvider), isFalse);
    expect(container.read(selectedTaskListIdProvider), 'list-a');

    await tester.tap(find.text('All tasks'));
    await tester.pump();

    expect(container.read(allTasksModeProvider), isTrue);
    expect(container.read(selectedTaskListIdProvider), isNull);
    expect(container.read(selectedTaskIdProvider), isNull);
  });

  testWidgets('All Tasks row is selected when allTasksMode is true', (
    tester,
  ) async {
    final container = await _container();
    container.read(allTasksModeProvider.notifier).state = true;
    await _pumpSidebar(tester, container);

    final selectedTile = tester.widget<YaruSelectableContainer>(
      find.ancestor(
        of: find.text('All tasks'),
        matching: find.byType(YaruSelectableContainer),
      ),
    );

    expect(selectedTile.selected, isTrue);
  });

  testWidgets('entering All Tasks mode clears selected task and list', (
    tester,
  ) async {
    final container = await _container();
    container.read(allTasksModeProvider.notifier).state = false;
    container.read(selectedTaskListIdProvider.notifier).state = 'list-a';
    container.read(selectedTaskIdProvider.notifier).state = 'task-a';
    await _pumpSidebar(tester, container);

    await tester.tap(find.text('All tasks'));
    await tester.pump();

    expect(container.read(allTasksModeProvider), isTrue);
    expect(container.read(selectedTaskListIdProvider), isNull);
    expect(container.read(selectedTaskIdProvider), isNull);
  });

  testWidgets('sidebar selected list uses theme primary accent', (
    tester,
  ) async {
    final container = await _container();
    container.read(allTasksModeProvider.notifier).state = false;
    container.read(selectedTaskListIdProvider.notifier).state = 'list-a';
    await _pumpSidebar(tester, container);

    final selectedTile = tester.widget<YaruSelectableContainer>(
      find.ancestor(
        of: find.text('List A'),
        matching: find.byType(YaruSelectableContainer),
      ),
    );

    expect(selectedTile.selected, isTrue);
  });

  testWidgets('task panel updates for selected list', (tester) async {
    final container = await _container();
    await _pumpWorkspace(tester, container);

    expect(find.text('Task for List A'), findsOneWidget);
    expect(find.text('Task for List B'), findsOneWidget);

    await tester.tap(
      find.descendant(
        of: find.byType(TaskListsSidebar),
        matching: find.text('List B'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Task for List B'), findsOneWidget);
    expect(find.text('Task for List A'), findsNothing);
  });

  testWidgets('selecting a different list clears selected task', (
    tester,
  ) async {
    final container = await _container();
    container.read(selectedTaskListIdProvider.notifier).state = 'list-a';
    container.read(selectedTaskIdProvider.notifier).state = 'task-a';
    await _pumpSidebar(tester, container);

    await tester.tap(find.text('List B'));
    await tester.pump();

    expect(container.read(selectedTaskListIdProvider), 'list-b');
    expect(container.read(selectedTaskIdProvider), isNull);
  });

  testWidgets(
    'clicking a task updates selected task provider and shows details pane',
    (tester) async {
      final container = await _container();
      container.read(selectedTaskListIdProvider.notifier).state = 'list-a';
      container.read(allTasksModeProvider.notifier).state = false;
      await _pumpWorkspace(tester, container);

      await tester.tap(find.text('Task for List A'));
      await tester.pumpAndSettle();

      expect(container.read(selectedTaskIdProvider), 'task-a');
      expect(find.byType(TaskDetailsPane), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

Future<ProviderContainer> _container({
  List<AccountEntity> accounts = const [_defaultAccount],
  Map<String, List<_TaskListSeed>>? taskListsByAccount,
}) async {
  final taskLists =
      taskListsByAccount ??
      (accounts.isEmpty
          ? const <String, List<_TaskListSeed>>{}
          : _defaultTaskLists(accounts.first.id));
  final selectedAccountId = accounts.isEmpty ? '' : accounts.first.id;

  final container = ProviderContainer(
    overrides: [
      accountsStreamProvider.overrideWith((ref) => Stream.value(accounts)),
      taskListsRepositoryForAccountProvider.overrideWith((ref, accountId) {
        return _FakeTaskListsRepository(
          _taskListEntities(accountId, taskLists[accountId] ?? const []),
        );
      }),
      taskListsRepositoryProvider.overrideWithValue(
        _FakeTaskListsRepository(
          _taskListEntities(
            selectedAccountId,
            taskLists[selectedAccountId] ?? const [],
          ),
        ),
      ),
      tasksRepositoryProvider.overrideWithValue(_FakeTasksRepository()),
      tasksRepositoryForAccountProvider.overrideWith((ref, accountId) {
        return _FakeTasksRepository();
      }),
      syncEngineProvider.overrideWithValue(null),
      signedInSyncRunnerProvider.overrideWithValue((accountId, initial) async {
        return;
      }),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

Future<void> _pumpSidebar(
  WidgetTester tester,
  ProviderContainer container, {
  double? width,
}) async {
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: localizedTestApp(
        child: Scaffold(
          body: width == null
              ? const TaskListsSidebar()
              : SizedBox(width: width, child: const TaskListsSidebar()),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _pumpWorkspace(
  WidgetTester tester,
  ProviderContainer container,
) async {
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
  tester.view.physicalSize = const Size(1280, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: localizedTestApp(child: const TasksWorkspace()),
    ),
  );
  await tester.pumpAndSettle();
}

class _FakeTaskListsRepository implements TaskListsRepository {
  const _FakeTaskListsRepository(this.lists);

  final List<TaskListEntity> lists;

  @override
  Stream<List<TaskListEntity>> watchTaskLists() {
    return Stream.value(lists);
  }

  @override
  Stream<TaskListEntity?> watchTaskList(String id) {
    return watchTaskLists().map(
      (lists) => lists.where((list) => list.id == id).firstOrNull,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeTasksRepository implements TasksRepository {
  @override
  Stream<TaskEntity?> watchTask(String taskListId, String taskId) {
    return Stream.value(_taskForList(taskListId));
  }

  @override
  Stream<List<TaskTreeGroup>> watchAllTaskTreeGroups(
    List<String> accountIds,
    TaskViewFilter filter,
  ) {
    return Stream.value(const [
      TaskTreeGroup(
        accountId: 'account',
        accountLabel: 'Ada - ada@example.com',
        provider: TaskProvider.google,
        taskListId: 'list-a',
        taskListTitle: 'List A',
        nodes: [
          TaskTreeNode(
            task: TaskEntity(
              accountId: 'account',
              taskListId: 'list-a',
              id: 'task-a',
              title: 'Task for List A',
              localDirty: false,
              pendingDelete: false,
              pendingMove: false,
              rawJson: '{}',
              updatedLocalAtUtc: '2026-06-04T00:00:00.000Z',
              status: 'needsAction',
            ),
            children: [],
          ),
        ],
      ),
      TaskTreeGroup(
        accountId: 'account',
        accountLabel: 'Ada - ada@example.com',
        provider: TaskProvider.google,
        taskListId: 'list-b',
        taskListTitle: 'List B',
        nodes: [
          TaskTreeNode(
            task: TaskEntity(
              accountId: 'account',
              taskListId: 'list-b',
              id: 'task-b',
              title: 'Task for List B',
              localDirty: false,
              pendingDelete: false,
              pendingMove: false,
              rawJson: '{}',
              updatedLocalAtUtc: '2026-06-04T00:00:00.000Z',
              status: 'needsAction',
            ),
            children: [],
          ),
        ],
      ),
    ]);
  }

  @override
  Stream<List<TaskTreeNode>> watchTaskTree(
    String taskListId,
    TaskViewFilter filter,
  ) {
    return Stream.value([
      TaskTreeNode(task: _taskForList(taskListId), children: const []),
    ]);
  }

  @override
  Stream<List<String>> watchCategorySuggestions() {
    return Stream.value(const []);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

List<TaskListEntity> _taskListEntities(
  String accountId,
  List<_TaskListSeed> seeds,
) {
  return [
    for (final seed in seeds)
      TaskListEntity(
        accountId: accountId,
        id: seed.id,
        title: seed.title,
        localDirty: false,
        pendingDelete: false,
        rawJson: '{}',
      ),
  ];
}

Map<String, List<_TaskListSeed>> _defaultTaskLists(String accountId) {
  return {
    accountId: const [
      _TaskListSeed(id: 'list-a', title: 'List A'),
      _TaskListSeed(id: 'list-b', title: 'List B'),
    ],
  };
}

TaskEntity _taskForList(String taskListId) {
  final suffix = taskListId == 'list-b' ? 'B' : 'A';
  return TaskEntity(
    accountId: 'account',
    taskListId: taskListId,
    id: 'task-${suffix.toLowerCase()}',
    title: 'Task for List $suffix',
    localDirty: false,
    pendingDelete: false,
    pendingMove: false,
    rawJson: '{}',
    updatedLocalAtUtc: '2026-06-04T00:00:00.000Z',
    status: 'needsAction',
  );
}

class _TaskListSeed {
  const _TaskListSeed({required this.id, required this.title});

  final String id;
  final String title;
}

const _defaultAccount = AccountEntity(
  id: 'account',
  provider: TaskProvider.google,
  authState: 'signed_in',
  displayName: 'Ada',
  email: 'ada@example.com',
);

const _googleAccount = AccountEntity(
  id: 'google:g',
  provider: TaskProvider.google,
  authState: 'signed_in',
  displayName: 'Google User',
  email: 'google@example.com',
);

const _microsoftAccount = AccountEntity(
  id: 'microsoft:m',
  provider: TaskProvider.microsoft,
  authState: 'signed_in',
  displayName: 'Microsoft User',
  email: 'microsoft@example.com',
);

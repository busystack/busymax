import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:busymax/src/db/app_database.dart';
import 'package:busymax/src/features/sync/pending_mutation_sync_requester.dart';
import 'package:busymax/src/features/sync/sync_auth_error.dart';
import 'package:busymax/src/features/sync/sync_engine.dart';
import 'package:busymax/src/features/tasks/data/tasks_repository.dart';
import 'package:busymax/src/google_tasks/api/google_tasks_api_client.dart';
import 'package:busymax/src/google_tasks/api/google_tasks_api_models.dart';
import 'package:busymax/src/google_tasks/oauth/oauth_models.dart';

void main() {
  test('multiple rapid requests produce one sync call', () async {
    var syncCalls = 0;
    final requester = PendingMutationSyncRequester(
      sync: () async {
        syncCalls += 1;
      },
      debounce: const Duration(milliseconds: 10),
    );
    addTearDown(requester.dispose);

    requester.request();
    requester.request();
    requester.request();

    await Future<void>.delayed(const Duration(milliseconds: 30));

    expect(syncCalls, 1);
  });

  test(
    'request during running sync schedules one non-overlapping follow-up',
    () async {
      final completions = [Completer<void>(), Completer<void>()];
      var syncCalls = 0;
      var activeSyncs = 0;
      var maxActiveSyncs = 0;
      final requester = PendingMutationSyncRequester(
        sync: () async {
          final index = syncCalls;
          syncCalls += 1;
          activeSyncs += 1;
          if (activeSyncs > maxActiveSyncs) {
            maxActiveSyncs = activeSyncs;
          }
          await completions[index].future;
          activeSyncs -= 1;
        },
        debounce: Duration.zero,
      );
      addTearDown(requester.dispose);

      requester.request();
      await _waitFor(() => syncCalls == 1);

      requester.request();
      requester.request();
      expect(syncCalls, 1);

      completions.first.complete();
      await _waitFor(() => syncCalls == 2);
      expect(maxActiveSyncs, 1);

      completions[1].complete();
      await _waitFor(() => activeSyncs == 0);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(syncCalls, 2);
      expect(maxActiveSyncs, 1);
    },
  );

  test('sync exception is caught and does not escape request', () async {
    var syncCalls = 0;
    Object? zoneError;

    await runZonedGuarded<Future<void>>(
      () async {
        final requester = PendingMutationSyncRequester(
          sync: () async {
            syncCalls += 1;
            throw StateError('sync failed');
          },
          debounce: Duration.zero,
        );
        addTearDown(requester.dispose);

        requester.request();
        await _waitFor(() => syncCalls == 1);
        await Future<void>.delayed(Duration.zero);
      },
      (error, _) {
        zoneError = error;
      },
    );

    expect(syncCalls, 1);
    expect(zoneError, isNull);
  });

  test('sync exception calls notification callback', () async {
    final failures = <String>[];
    var syncCalls = 0;
    final requester = PendingMutationSyncRequester(
      sync: () async {
        syncCalls += 1;
        throw StateError('sync failed');
      },
      onSyncFailure: (message) async {
        failures.add(message);
      },
      debounce: Duration.zero,
    );
    addTearDown(requester.dispose);

    requester.request();
    await _waitFor(() => failures.isNotEmpty);

    expect(syncCalls, 1);
    expect(failures.single, contains('sync failed'));
  });

  test(
    'missing OAuth token calls error hook and reports reconnect message',
    () async {
      final errors = <Object>[];
      final failures = <String>[];
      final requester = PendingMutationSyncRequester(
        sync: () async {
          throw const OAuthException(
            'OAuthMissingToken',
            'No OAuth token is available for this account.',
          );
        },
        onSyncError: (error) async {
          errors.add(error);
        },
        onSyncFailure: (message) async {
          failures.add(message);
        },
        debounce: Duration.zero,
      );
      addTearDown(requester.dispose);

      requester.request();
      await _waitFor(() => failures.isNotEmpty);

      expect(errors.single, isA<OAuthException>());
      expect(failures.single, accountReconnectRequiredSyncMessage);
    },
  );

  test('created task is replayed through requester-triggered sync', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    await _insertAccount(database);
    await database.taskListsDao.upsertTaskList(_taskList());
    final apiClient = _FakeGoogleTasksApiClient()
      ..taskListsPages = [
        TaskListsPageDto(items: [_taskListDto('list-1')], rawJson: const {}),
      ]
      ..taskPages['list-1'] = [const TasksPageDto(items: [], rawJson: {})];
    final syncEngine = SyncEngine(
      database: database,
      apiClient: apiClient,
      accountId: 'account',
      nowUtc: () => DateTime.utc(2026, 6, 4),
    );
    final requester = PendingMutationSyncRequester(
      sync: syncEngine.incrementalSync,
      debounce: const Duration(milliseconds: 1),
    );
    addTearDown(requester.dispose);
    final repository = TasksRepository(
      database: database,
      accountId: 'account',
      onMutationQueued: requester.request,
      nowUtc: () => DateTime.utc(2026, 6, 4),
    );

    await repository.createTask(
      'list-1',
      const TaskCreateInput(title: 'Offline task'),
    );

    await _waitFor(() async {
      final runs = await database.syncRunsDao.recentRuns('account');
      return runs.isNotEmpty && runs.first.status == 'success';
    });

    final ops = await database.pendingOpsDao.pendingOpsForReplay(
      'account',
      DateTime.utc(2026, 6, 4, 1),
    );
    final tasks = await database.tasksDao.listTasks('account', 'list-1');

    expect(apiClient.calls, contains('create_task:Offline task'));
    expect(ops, isEmpty);
    expect(tasks.map((task) => task.id), contains('task-server'));
    expect(tasks.map((task) => task.id), isNot(contains(startsWith('local-'))));
    expect(
      tasks.singleWhere((task) => task.id == 'task-server').localDirty,
      isFalse,
    );
  });
}

Future<void> _waitFor(FutureOr<bool> Function() condition) async {
  final deadline = DateTime.now().add(const Duration(seconds: 2));
  while (DateTime.now().isBefore(deadline)) {
    if (await condition()) {
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  fail('Timed out waiting for condition.');
}

Future<void> _insertAccount(AppDatabase database) {
  return database
      .into(database.accounts)
      .insert(
        AccountsCompanion.insert(
          id: 'account',
          createdAtUtc: _now,
          updatedAtUtc: _now,
        ),
      );
}

TaskListsCompanion _taskList() {
  return TaskListsCompanion.insert(
    accountId: 'account',
    id: 'list-1',
    title: 'Inbox',
    rawJson: '{}',
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

class _FakeGoogleTasksApiClient implements GoogleTasksApiClient {
  var taskListsPages = <TaskListsPageDto>[];
  final taskPages = <String, List<TasksPageDto>>{};
  final calls = <String>[];
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
    final index = _taskPageIndexes.update(
      taskListId,
      (value) => value + 1,
      ifAbsent: () => 0,
    );
    return taskPages[taskListId]![index];
  }

  @override
  Future<TaskDto> createTask({
    required String taskListId,
    String? parentTaskId,
    String? previousSiblingTaskId,
    required TaskCreate create,
  }) async {
    calls.add('create_task:${create.fields['title']}');
    return TaskDto(
      id: 'task-server',
      title: create.fields['title']?.toString() ?? 'Task',
      rawJson: {'id': 'task-server', 'title': create.fields['title']},
    );
  }

  @override
  Future<void> clearCompletedTasks(String taskListId) =>
      throw UnimplementedError();

  @override
  Future<TaskListDto> createTaskList({required String title}) =>
      throw UnimplementedError();

  @override
  Future<void> deleteTask({
    required String taskListId,
    required String taskId,
  }) => throw UnimplementedError();

  @override
  Future<void> deleteTaskList(String taskListId) => throw UnimplementedError();

  @override
  Future<TaskDto> getTask({
    required String taskListId,
    required String taskId,
  }) => throw UnimplementedError();

  @override
  Future<TaskListDto> getTaskList(String taskListId) =>
      throw UnimplementedError();

  @override
  Future<TaskDto> moveTask({
    required String sourceTaskListId,
    required String taskId,
    String? parentTaskId,
    String? previousSiblingTaskId,
    String? destinationTaskListId,
  }) => throw UnimplementedError();

  @override
  Future<TaskDto> patchTask({
    required String taskListId,
    required String taskId,
    required TaskPatch patch,
  }) => throw UnimplementedError();

  @override
  Future<TaskListDto> patchTaskList(String taskListId, TaskListPatch patch) =>
      throw UnimplementedError();

  @override
  Future<TaskDto> updateTask({
    required String taskListId,
    required String taskId,
    required TaskPut replacement,
  }) => throw UnimplementedError();

  @override
  Future<TaskListDto> updateTaskList(
    String taskListId,
    TaskListPut replacement,
  ) => throw UnimplementedError();
}

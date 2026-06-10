import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:busymax/src/db/app_database.dart';
import 'package:busymax/src/features/sync/pending_op_resolution_service.dart';
import 'package:busymax/src/features/sync/sync_engine.dart';
import 'package:busymax/src/google_tasks/api/google_tasks_api_client.dart';
import 'package:busymax/src/google_tasks/api/google_tasks_api_error.dart';
import 'package:busymax/src/google_tasks/api/google_tasks_api_models.dart';

void main() {
  late AppDatabase database;
  late _FakeGoogleTasksApiClient apiClient;
  late _FakeSyncEngine syncEngine;
  late PendingOpResolutionService service;

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    apiClient = _FakeGoogleTasksApiClient();
    syncEngine = _FakeSyncEngine();
    service = PendingOpResolutionService(
      database: database,
      apiClient: apiClient,
      accountId: 'account',
      syncEngine: syncEngine,
      nowUtc: () => DateTime.utc(2026, 6, 4),
    );

    await _insertAccount(database);
    await database.taskListsDao.upsertTaskList(_localTaskList('list-1'));
  });

  tearDown(() async {
    await database.close();
  });

  test(
    'discard blocked task patch refreshes task and clears dirty flags',
    () async {
      apiClient.remoteTask = _taskDto('task-1', title: 'Remote task');
      await database.tasksDao.upsertTask(
        _localTask('task-1', localDirty: true, pendingMove: true),
      );
      await _enqueueBlockedOp(
        database,
        operation: 'patch_task',
        taskListId: 'list-1',
        taskId: 'task-1',
      );

      await service.discard('op-1');

      final task = (await database.tasksDao.listTasks(
        'account',
        'list-1',
      )).single;
      expect(task.title, 'Remote task');
      expect(task.localDirty, isFalse);
      expect(task.pendingDelete, isFalse);
      expect(task.pendingMove, isFalse);
      expect(await database.pendingOpsDao.getOp('op-1'), equals(null));
      expect(syncEngine.incrementalSyncCalls, 1);
    },
  );

  test(
    'discard blocked task delete with remote task present refreshes local row',
    () async {
      apiClient.remoteTask = _taskDto('task-1', title: 'Remote task');
      await database.tasksDao.upsertTask(
        _localTask('task-1', localDirty: true, pendingDelete: true),
      );
      await _enqueueBlockedOp(
        database,
        operation: 'delete_task',
        taskListId: 'list-1',
        taskId: 'task-1',
      );

      await service.discard('op-1');

      final task = (await database.tasksDao.listTasks(
        'account',
        'list-1',
      )).single;
      expect(task.title, 'Remote task');
      expect(task.localDirty, isFalse);
      expect(task.pendingDelete, isFalse);
      expect(await database.pendingOpsDao.getOp('op-1'), equals(null));
      expect(syncEngine.incrementalSyncCalls, 1);
    },
  );

  test(
    'discard blocked task delete with remote 404 deletes local row',
    () async {
      apiClient.getTaskError = const GoogleTasksApiError(
        statusCode: 404,
        message: 'Not found',
      );
      await database.tasksDao.upsertTask(
        _localTask('task-1', localDirty: true, pendingDelete: true),
      );
      await _enqueueBlockedOp(
        database,
        operation: 'delete_task',
        taskListId: 'list-1',
        taskId: 'task-1',
      );

      await service.discard('op-1');

      expect(await database.tasksDao.listTasks('account', 'list-1'), isEmpty);
      expect(await database.pendingOpsDao.getOp('op-1'), equals(null));
      expect(syncEngine.incrementalSyncCalls, 1);
    },
  );

  test(
    'discard blocked task-list patch refreshes list and clears dirty flags',
    () async {
      apiClient.remoteTaskList = _taskListDto('list-1', title: 'Remote list');
      await database.taskListsDao.upsertTaskList(
        _localTaskList('list-1', title: 'Local list', localDirty: true),
      );
      await _enqueueBlockedOp(
        database,
        entityType: 'task_list',
        operation: 'patch_task_list',
        taskListId: 'list-1',
      );

      await service.discard('op-1');

      final list = (await database.taskListsDao.listTaskLists(
        'account',
      )).single;
      expect(list.title, 'Remote list');
      expect(list.localDirty, isFalse);
      expect(list.pendingDelete, isFalse);
      expect(await database.pendingOpsDao.getOp('op-1'), equals(null));
      expect(syncEngine.incrementalSyncCalls, 1);
    },
  );

  test(
    'discard blocked task-list delete with remote 404 deletes local list',
    () async {
      apiClient.getTaskListError = const GoogleTasksApiError(
        statusCode: 404,
        message: 'Not found',
      );
      await database.taskListsDao.upsertTaskList(
        _localTaskList(
          'list-1',
          title: 'Local list',
          localDirty: true,
          pendingDelete: true,
        ),
      );
      await _enqueueBlockedOp(
        database,
        entityType: 'task_list',
        operation: 'delete_task_list',
        taskListId: 'list-1',
      );

      await service.discard('op-1');

      expect(await database.taskListsDao.listTaskLists('account'), isEmpty);
      expect(await database.pendingOpsDao.getOp('op-1'), equals(null));
      expect(syncEngine.incrementalSyncCalls, 1);
    },
  );

  test(
    'discard task patch with remote 500 keeps op and local dirty state',
    () async {
      apiClient.getTaskError = const GoogleTasksApiError(
        statusCode: 500,
        message: 'Server error',
      );
      await database.tasksDao.upsertTask(
        _localTask('task-1', localDirty: true),
      );
      await _enqueueBlockedOp(
        database,
        operation: 'patch_task',
        taskListId: 'list-1',
        taskId: 'task-1',
      );

      await expectLater(
        service.discard('op-1'),
        throwsA(isA<GoogleTasksApiError>()),
      );

      final task = (await database.tasksDao.listTasks(
        'account',
        'list-1',
      )).single;
      expect(task.localDirty, isTrue);
      expect(await database.pendingOpsDao.getOp('op-1'), isNot(equals(null)));
      expect(syncEngine.incrementalSyncCalls, 0);
    },
  );

  test(
    'discard task-list patch with remote 500 keeps op and local dirty state',
    () async {
      apiClient.getTaskListError = const GoogleTasksApiError(
        statusCode: 500,
        message: 'Server error',
      );
      await database.taskListsDao.upsertTaskList(
        _localTaskList('list-1', localDirty: true),
      );
      await _enqueueBlockedOp(
        database,
        entityType: 'task_list',
        operation: 'patch_task_list',
        taskListId: 'list-1',
      );

      await expectLater(
        service.discard('op-1'),
        throwsA(isA<GoogleTasksApiError>()),
      );

      final list = (await database.taskListsDao.listTaskLists(
        'account',
      )).single;
      expect(list.localDirty, isTrue);
      expect(await database.pendingOpsDao.getOp('op-1'), isNot(equals(null)));
      expect(syncEngine.incrementalSyncCalls, 0);
    },
  );

  test(
    'discard blocked cross-list move refreshes source and removes destination',
    () async {
      apiClient.remoteTask = _taskDto('task-1', title: 'Remote source task');
      await database.taskListsDao.upsertTaskList(_localTaskList('list-2'));
      await database.tasksDao.upsertTask(
        _localTask(
          'task-1',
          taskListId: 'list-2',
          localDirty: true,
          pendingMove: true,
        ),
      );
      await _enqueueBlockedOp(
        database,
        operation: 'move_task',
        taskListId: 'list-1',
        taskId: 'task-1',
        request: {'destinationTasklist': 'list-2'},
      );

      await service.discard('op-1');

      final sourceTasks = await database.tasksDao.listTasks(
        'account',
        'list-1',
      );
      final destinationTasks = await database.tasksDao.listTasks(
        'account',
        'list-2',
      );
      expect(sourceTasks.single.title, 'Remote source task');
      expect(sourceTasks.single.localDirty, isFalse);
      expect(sourceTasks.single.pendingMove, isFalse);
      expect(destinationTasks, isEmpty);
      expect(await database.pendingOpsDao.getOp('op-1'), equals(null));
      expect(syncEngine.incrementalSyncCalls, 1);
    },
  );

  test(
    'discard blocked cross-list move with remote 404 removes both rows',
    () async {
      apiClient.getTaskError = const GoogleTasksApiError(
        statusCode: 404,
        message: 'Not found',
      );
      await database.taskListsDao.upsertTaskList(_localTaskList('list-2'));
      await database.tasksDao.upsertTask(
        _localTask('task-1', taskListId: 'list-1', localDirty: true),
      );
      await database.tasksDao.upsertTask(
        _localTask(
          'task-1',
          taskListId: 'list-2',
          localDirty: true,
          pendingMove: true,
        ),
      );
      await _enqueueBlockedOp(
        database,
        operation: 'move_task',
        taskListId: 'list-1',
        taskId: 'task-1',
        request: {'destinationTasklist': 'list-2'},
      );

      await service.discard('op-1');

      expect(await database.tasksDao.listTasks('account', 'list-1'), isEmpty);
      expect(await database.tasksDao.listTasks('account', 'list-2'), isEmpty);
      expect(await database.pendingOpsDao.getOp('op-1'), equals(null));
      expect(syncEngine.incrementalSyncCalls, 1);
    },
  );

  test('discard blocked same-list move clears pendingMove', () async {
    apiClient.remoteTask = _taskDto('task-1', title: 'Remote task');
    await database.tasksDao.upsertTask(
      _localTask('task-1', localDirty: true, pendingMove: true),
    );
    await _enqueueBlockedOp(
      database,
      operation: 'move_task',
      taskListId: 'list-1',
      taskId: 'task-1',
      request: {'previous': 'task-0'},
    );

    await service.discard('op-1');

    final task = (await database.tasksDao.listTasks(
      'account',
      'list-1',
    )).single;
    expect(task.title, 'Remote task');
    expect(task.localDirty, isFalse);
    expect(task.pendingMove, isFalse);
    expect(await database.pendingOpsDao.getOp('op-1'), equals(null));
    expect(syncEngine.incrementalSyncCalls, 1);
  });
}

class _FakeGoogleTasksApiClient implements GoogleTasksApiClient {
  TaskDto? remoteTask;
  TaskListDto? remoteTaskList;
  GoogleTasksApiError? getTaskError;
  GoogleTasksApiError? getTaskListError;

  @override
  Future<TaskDto> getTask({
    required String taskListId,
    required String taskId,
  }) async {
    final error = getTaskError;
    if (error != null) {
      throw error;
    }
    return remoteTask ?? _taskDto(taskId);
  }

  @override
  Future<TaskListDto> getTaskList(String taskListId) async {
    final error = getTaskListError;
    if (error != null) {
      throw error;
    }
    return remoteTaskList ?? _taskListDto(taskListId);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeSyncEngine implements SyncEngine {
  var incrementalSyncCalls = 0;

  @override
  Future<void> fullSync() async {}

  @override
  Future<void> incrementalSync() async {
    incrementalSyncCalls += 1;
  }
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

TaskListsCompanion _localTaskList(
  String id, {
  String title = 'List',
  bool localDirty = false,
  bool pendingDelete = false,
}) {
  return TaskListsCompanion.insert(
    accountId: 'account',
    id: id,
    title: title,
    rawJson: '{"id":"$id","title":"$title"}',
    localDirty: Value(localDirty),
    pendingDelete: Value(pendingDelete),
    createdLocalAtUtc: _now,
    updatedLocalAtUtc: _now,
  );
}

TasksCompanion _localTask(
  String id, {
  String taskListId = 'list-1',
  bool localDirty = false,
  bool pendingDelete = false,
  bool pendingMove = false,
}) {
  return TasksCompanion.insert(
    accountId: 'account',
    taskListId: taskListId,
    id: id,
    title: 'Local task',
    rawJson: '{"id":"$id","title":"Local task"}',
    localDirty: Value(localDirty),
    pendingDelete: Value(pendingDelete),
    pendingMove: Value(pendingMove),
    createdLocalAtUtc: _now,
    updatedLocalAtUtc: _now,
  );
}

Future<void> _enqueueBlockedOp(
  AppDatabase database, {
  String entityType = 'task',
  required String operation,
  String? taskListId,
  String? taskId,
  Map<String, Object?> request = const {},
}) {
  return database.pendingOpsDao.enqueue(
    PendingOpsCompanion.insert(
      id: 'op-1',
      accountId: 'account',
      entityType: entityType,
      operation: operation,
      taskListId: Value(taskListId),
      taskId: Value(taskId),
      requestJson: jsonEncode(request),
      nextAttemptAtUtc: const Value('9999-12-31T00:00:00.000Z'),
      lastErrorCode: const Value('conflict'),
      createdAtUtc: _now,
      updatedAtUtc: _now,
    ),
  );
}

TaskDto _taskDto(String id, {String title = 'Task'}) {
  return TaskDto(id: id, title: title, rawJson: {'id': id, 'title': title});
}

TaskListDto _taskListDto(String id, {String title = 'List'}) {
  return TaskListDto(id: id, title: title, rawJson: {'id': id, 'title': title});
}

const _now = '2026-06-04T00:00:00.000Z';

import 'dart:convert';
import 'dart:math';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:busymax/src/db/app_database.dart';
import 'package:busymax/src/features/sync/pending_ops_replayer.dart';
import 'package:busymax/src/google_tasks/api/google_tasks_api_client.dart';
import 'package:busymax/src/google_tasks/api/google_tasks_api_error.dart';
import 'package:busymax/src/google_tasks/api/google_tasks_api_models.dart';

void main() {
  late AppDatabase database;
  late _FakeGoogleTasksApiClient apiClient;

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    apiClient = _FakeGoogleTasksApiClient();
    await _insertAccount(database);
    await database.taskListsDao.upsertTaskList(_taskList('list-1'));
  });

  tearDown(() async {
    await database.close();
  });

  test('replays all operation handlers and rewrites task temp IDs', () async {
    await database.taskListsDao.upsertTaskList(
      _taskList('local-tasklist-1', title: 'Temp'),
    );
    await database.tasksDao.upsertTask(
      _task('list-1', 'local-task-1', title: 'Draft'),
    );

    await _enqueue(
      database,
      id: '01',
      operation: 'create_task_list',
      entityType: 'task_list',
      taskListId: 'local-tasklist-1',
      localTempId: 'local-tasklist-1',
      request: {'title': 'Temp'},
    );
    await _enqueue(
      database,
      id: '02',
      operation: 'patch_task_list',
      entityType: 'task_list',
      taskListId: 'list-1',
      request: {'title': 'Patched'},
    );
    await _enqueue(
      database,
      id: '03',
      operation: 'update_task_list',
      entityType: 'task_list',
      taskListId: 'list-1',
      request: {'title': 'Updated'},
    );
    await _enqueue(
      database,
      id: '04',
      operation: 'create_task',
      taskListId: 'list-1',
      taskId: 'local-task-1',
      localTempId: 'local-task-1',
      request: {
        'body': {'title': 'Draft'},
      },
    );
    await _enqueue(
      database,
      id: '05',
      operation: 'patch_task',
      taskListId: 'list-1',
      taskId: 'local-task-1',
      request: {'title': 'Patched task'},
    );
    await _enqueue(
      database,
      id: '06',
      operation: 'update_task',
      taskListId: 'list-1',
      taskId: 'local-task-1',
      request: {'title': 'Updated task'},
    );
    await _enqueue(
      database,
      id: '07',
      operation: 'move_task',
      taskListId: 'list-1',
      taskId: 'local-task-1',
      request: {'previous': 'task-0'},
    );
    await _enqueue(
      database,
      id: '08',
      operation: 'delete_task',
      taskListId: 'list-1',
      taskId: 'local-task-1',
      request: const {},
    );
    await _enqueue(
      database,
      id: '09',
      operation: 'clear_completed_tasks',
      taskListId: 'list-1',
      request: const {},
    );
    await _enqueue(
      database,
      id: '10',
      operation: 'delete_task_list',
      entityType: 'task_list',
      taskListId: 'list-1',
      request: const {},
    );

    final applied = await PendingOpsReplayer(
      database: database,
      apiClient: apiClient,
      accountId: 'account',
      random: Random(0),
      nowUtc: () => DateTime.utc(2026, 6, 4),
    ).replayDueOps();

    expect(applied, 10);
    expect(
      await database.pendingOpsDao.pendingOpsForReplay('account', _later),
      isEmpty,
    );
    expect(apiClient.calls, [
      'create_task_list:Temp',
      'patch_task_list:list-1',
      'update_task_list:list-1',
      'create_task:list-1',
      'patch_task:task-server',
      'update_task:task-server',
      'move_task:task-server',
      'delete_task:task-server',
      'clear:list-1',
      'delete_task_list:list-1',
    ]);

    final lists = await database.taskListsDao.listTaskLists('account');
    expect(lists.map((list) => list.id), contains('list-server'));
    expect(lists.map((list) => list.id), isNot(contains('local-tasklist-1')));
  });

  test('404 delete is treated as success', () async {
    apiClient.deleteTaskError = const GoogleTasksApiError(
      statusCode: 404,
      message: 'Not found',
    );
    await database.tasksDao.upsertTask(_task('list-1', 'task-1'));
    await _enqueue(
      database,
      id: '01',
      operation: 'delete_task',
      taskListId: 'list-1',
      taskId: 'task-1',
      request: const {},
    );

    final applied = await PendingOpsReplayer(
      database: database,
      apiClient: apiClient,
      accountId: 'account',
      random: Random(0),
      nowUtc: () => DateTime.utc(2026, 6, 4),
    ).replayDueOps();

    expect(applied, 1);
    expect(await database.tasksDao.listTasks('account', 'list-1'), isEmpty);
    expect(
      await database.pendingOpsDao.pendingOpsForReplay('account', _later),
      isEmpty,
    );
  });

  test('leaves calendar operations untouched for calendar replay', () async {
    await _enqueue(
      database,
      id: '01',
      operation: 'patch',
      operationType: 'calendar.patch',
      entityType: 'calendar',
      request: {'summary': 'Renamed'},
    );
    await _enqueue(
      database,
      id: '02',
      operation: 'create',
      operationType: 'event.create',
      entityType: 'event',
      request: {'title': 'Planning'},
    );
    await _enqueue(
      database,
      id: '03',
      operation: 'delete',
      entityType: 'event',
      request: const {},
    );

    final applied = await PendingOpsReplayer(
      database: database,
      apiClient: apiClient,
      accountId: 'account',
      random: Random(0),
      nowUtc: () => DateTime.utc(2026, 6, 4),
    ).replayDueOps();

    final ops = await database.pendingOpsDao.pendingOpsForReplay(
      'account',
      _later,
    );
    expect(applied, 0);
    expect(apiClient.calls, isEmpty);
    expect(ops, hasLength(3));
    for (final op in ops) {
      expect(op.attemptCount, 0);
      expect(op.nextAttemptAtUtc, equals(null));
      expect(op.lastErrorCode, equals(null));
      expect(op.lastErrorMessage, equals(null));
    }
  });

  test('unknown task operation is still blocked', () async {
    await _enqueue(
      database,
      id: '01',
      operation: 'frob_task',
      request: const {},
    );

    final applied = await PendingOpsReplayer(
      database: database,
      apiClient: apiClient,
      accountId: 'account',
      random: Random(0),
      nowUtc: () => DateTime.utc(2026, 6, 4),
    ).replayDueOps();

    final op = await database.pendingOpsDao.getOp('01');
    expect(applied, 0);
    expect(apiClient.calls, isEmpty);
    expect(op!.lastErrorCode, 'unknown_operation');
    expect(op.nextAttemptAtUtc, startsWith('9999-12-31'));
  });

  test(
    'temp ID rewrite preserves request text that merely mentions ID',
    () async {
      await database.tasksDao.upsertTask(
        _task('list-1', 'local-task-1', title: 'Draft'),
      );
      await _enqueue(
        database,
        id: '01',
        operation: 'create_task',
        taskListId: 'list-1',
        taskId: 'local-task-1',
        localTempId: 'local-task-1',
        request: {
          'body': {'title': 'Draft'},
        },
      );
      await _enqueue(
        database,
        id: '02',
        operation: 'patch_task',
        taskListId: 'list-1',
        taskId: 'local-task-1',
        request: {
          'parent': 'local-task-1',
          'notes': 'Do not rewrite local-task-1 inside user text.',
        },
      );

      await PendingOpsReplayer(
        database: database,
        apiClient: apiClient,
        accountId: 'account',
        random: Random(0),
        nowUtc: () => DateTime.utc(2026, 6, 4),
      ).replayDueOps();

      expect(apiClient.taskPatchFields.single, {
        'parent': 'task-server',
        'notes': 'Do not rewrite local-task-1 inside user text.',
      });
    },
  );

  test('conflicting task patch is blocked before remote mutation', () async {
    apiClient.remoteTask = TaskDto(
      id: 'task-1',
      title: 'Remote title',
      updated: DateTime.utc(2026, 6, 4, 0, 10),
      rawJson: {'id': 'task-1', 'title': 'Remote title'},
    );
    await database.tasksDao.upsertTask(
      _task(
        'list-1',
        'task-1',
        title: 'Base title',
        updatedUtc: '2026-06-04T00:00:00.000Z',
      ),
    );
    await _enqueue(
      database,
      id: '01',
      operation: 'patch_task',
      taskListId: 'list-1',
      taskId: 'task-1',
      request: {'title': 'Local title'},
      baselineUpdatedUtc: '2026-06-04T00:00:00.000Z',
    );
    final conflicts = <String>[];

    final applied = await PendingOpsReplayer(
      database: database,
      apiClient: apiClient,
      accountId: 'account',
      random: Random(0),
      nowUtc: () => DateTime.utc(2026, 6, 4),
      onConflictBlocked: (summary) async {
        conflicts.add(summary);
      },
    ).replayDueOps();

    final op = await database.select(database.pendingOps).getSingle();
    expect(applied, 0);
    expect(apiClient.calls, isEmpty);
    expect(op.lastErrorCode, 'conflict');
    expect(op.nextAttemptAtUtc, startsWith('9999-12-31'));
    expect(conflicts.single, contains('Remote task changed fields'));
  });

  test('task conflict detection uses queued baseline JSON', () async {
    apiClient.remoteTask = TaskDto(
      id: 'task-1',
      title: 'Remote title',
      updated: DateTime.utc(2026, 6, 4, 0, 10),
      rawJson: {'id': 'task-1', 'title': 'Remote title'},
    );
    await database.tasksDao.upsertTask(
      _task(
        'list-1',
        'task-1',
        title: 'Remote title',
        updatedUtc: '2026-06-04T00:00:00.000Z',
        rawJson: jsonEncode({'id': 'task-1', 'title': 'Remote title'}),
      ),
    );
    await _enqueue(
      database,
      id: '01',
      operation: 'patch_task',
      taskListId: 'list-1',
      taskId: 'task-1',
      request: {'title': 'Local title'},
      baselineUpdatedUtc: '2026-06-04T00:00:00.000Z',
      baselineRawJson: jsonEncode({'id': 'task-1', 'title': 'Base title'}),
    );

    final applied = await PendingOpsReplayer(
      database: database,
      apiClient: apiClient,
      accountId: 'account',
      random: Random(0),
      nowUtc: () => DateTime.utc(2026, 6, 4),
    ).replayDueOps();

    final op = await database.select(database.pendingOps).getSingle();
    expect(applied, 0);
    expect(apiClient.calls, isEmpty);
    expect(op.lastErrorCode, 'conflict');
    expect(op.lastErrorMessage, contains('Remote task changed fields'));
  });

  test(
    'conflicting task list delete is blocked before remote mutation',
    () async {
      apiClient.remoteTaskList = _taskListDto(
        'list-1',
        title: 'Remote list',
        updated: DateTime.utc(2026, 6, 4, 0, 10),
      );
      await database.taskListsDao.upsertTaskList(
        _taskList(
          'list-1',
          title: 'Base list',
          updatedUtc: '2026-06-04T00:00:00.000Z',
        ),
      );
      await _enqueue(
        database,
        id: '01',
        operation: 'delete_task_list',
        entityType: 'task_list',
        taskListId: 'list-1',
        request: const {},
        baselineUpdatedUtc: '2026-06-04T00:00:00.000Z',
      );

      final applied = await PendingOpsReplayer(
        database: database,
        apiClient: apiClient,
        accountId: 'account',
        random: Random(0),
        nowUtc: () => DateTime.utc(2026, 6, 4),
      ).replayDueOps();

      final op = await database.select(database.pendingOps).getSingle();
      expect(applied, 0);
      expect(apiClient.calls, isEmpty);
      expect(op.lastErrorCode, 'conflict');
      expect(op.lastErrorMessage, contains('Remote task list changed'));
    },
  );

  test(
    'conflicting task list delete is blocked by child task change',
    () async {
      apiClient.remoteTasksPage = TasksPageDto(
        items: [_taskDto('task-1', updated: DateTime.utc(2026, 6, 4, 0, 10))],
        rawJson: const {},
      );
      await _enqueue(
        database,
        id: '01',
        operation: 'delete_task_list',
        entityType: 'task_list',
        taskListId: 'list-1',
        request: const {},
        baselineUpdatedUtc: '2026-06-04T00:00:00.000Z',
      );

      final applied = await PendingOpsReplayer(
        database: database,
        apiClient: apiClient,
        accountId: 'account',
        random: Random(0),
        nowUtc: () => DateTime.utc(2026, 6, 4),
      ).replayDueOps();

      final op = await database.select(database.pendingOps).getSingle();
      expect(applied, 0);
      expect(apiClient.calls, isEmpty);
      expect(op.lastErrorCode, 'conflict');
      expect(op.lastErrorMessage, contains('Remote task in list changed'));
    },
  );

  test('non-conflicting task list delete proceeds', () async {
    apiClient.remoteTasksPage = TasksPageDto(
      items: [_taskDto('task-1', updated: DateTime.utc(2026, 6, 3, 23, 59))],
      rawJson: const {},
    );
    await _enqueue(
      database,
      id: '01',
      operation: 'delete_task_list',
      entityType: 'task_list',
      taskListId: 'list-1',
      request: const {},
      baselineUpdatedUtc: '2026-06-04T00:00:00.000Z',
    );

    final applied = await PendingOpsReplayer(
      database: database,
      apiClient: apiClient,
      accountId: 'account',
      random: Random(0),
      nowUtc: () => DateTime.utc(2026, 6, 4),
    ).replayDueOps();

    expect(applied, 1);
    expect(apiClient.calls, ['delete_task_list:list-1']);
    expect(await database.select(database.pendingOps).get(), isEmpty);
  });

  test('conflicting task delete is blocked before remote mutation', () async {
    apiClient.remoteTask = _taskDto(
      'task-1',
      title: 'Remote task',
      updated: DateTime.utc(2026, 6, 4, 0, 10),
    );
    await database.tasksDao.upsertTask(
      _task(
        'list-1',
        'task-1',
        title: 'Base task',
        updatedUtc: '2026-06-04T00:00:00.000Z',
      ),
    );
    await _enqueue(
      database,
      id: '01',
      operation: 'delete_task',
      taskListId: 'list-1',
      taskId: 'task-1',
      request: const {},
      baselineUpdatedUtc: '2026-06-04T00:00:00.000Z',
    );

    final applied = await PendingOpsReplayer(
      database: database,
      apiClient: apiClient,
      accountId: 'account',
      random: Random(0),
      nowUtc: () => DateTime.utc(2026, 6, 4),
    ).replayDueOps();

    final op = await database.select(database.pendingOps).getSingle();
    expect(applied, 0);
    expect(apiClient.calls, isEmpty);
    expect(op.lastErrorCode, 'conflict');
    expect(op.lastErrorMessage, contains('Remote task changed'));
  });

  test('conflicting task move is blocked before remote mutation', () async {
    apiClient.remoteTask = _taskDto(
      'task-1',
      title: 'Remote task',
      updated: DateTime.utc(2026, 6, 4, 0, 10),
    );
    await database.tasksDao.upsertTask(
      _task(
        'list-1',
        'task-1',
        title: 'Base task',
        updatedUtc: '2026-06-04T00:00:00.000Z',
      ),
    );
    await _enqueue(
      database,
      id: '01',
      operation: 'move_task',
      taskListId: 'list-1',
      taskId: 'task-1',
      request: {'previous': 'task-0'},
      baselineUpdatedUtc: '2026-06-04T00:00:00.000Z',
    );

    final applied = await PendingOpsReplayer(
      database: database,
      apiClient: apiClient,
      accountId: 'account',
      random: Random(0),
      nowUtc: () => DateTime.utc(2026, 6, 4),
    ).replayDueOps();

    final op = await database.select(database.pendingOps).getSingle();
    expect(applied, 0);
    expect(apiClient.calls, isEmpty);
    expect(op.lastErrorCode, 'conflict');
    expect(op.lastErrorMessage, contains('Remote task changed'));
  });

  test(
    'conflicting clear completed is blocked before remote mutation',
    () async {
      apiClient.remoteTasksPage = TasksPageDto(
        items: [
          _taskDto(
            'task-1',
            status: 'completed',
            updated: DateTime.utc(2026, 6, 4, 0, 10),
          ),
        ],
        rawJson: const {},
      );
      await _enqueue(
        database,
        id: '01',
        operation: 'clear_completed_tasks',
        taskListId: 'list-1',
        request: const {},
        baselineUpdatedUtc: '2026-06-04T00:00:00.000Z',
      );

      final applied = await PendingOpsReplayer(
        database: database,
        apiClient: apiClient,
        accountId: 'account',
        random: Random(0),
        nowUtc: () => DateTime.utc(2026, 6, 4),
      ).replayDueOps();

      final op = await database.select(database.pendingOps).getSingle();
      expect(applied, 0);
      expect(apiClient.calls, isEmpty);
      expect(op.lastErrorCode, 'conflict');
      expect(op.lastErrorMessage, contains('Remote completed task changed'));
    },
  );

  test('retryable errors schedule backoff', () async {
    apiClient.patchTaskListError = const GoogleTasksApiError(
      statusCode: 500,
      message: 'Server error',
    );
    await _enqueue(
      database,
      id: '01',
      operation: 'patch_task_list',
      entityType: 'task_list',
      taskListId: 'list-1',
      request: {'title': 'Patched'},
    );

    final applied = await PendingOpsReplayer(
      database: database,
      apiClient: apiClient,
      accountId: 'account',
      random: Random(0),
      nowUtc: () => DateTime.utc(2026, 6, 4),
    ).replayDueOps();

    final op = await database.select(database.pendingOps).getSingle();
    expect(applied, 0);
    expect(op.attemptCount, 1);
    expect(op.lastErrorCode, '500');
    expect(op.nextAttemptAtUtc, isNot(equals(null)));
  });

  test('permanent errors block operation far in the future', () async {
    apiClient.patchTaskListError = const GoogleTasksApiError(
      statusCode: 400,
      message: 'Bad request',
    );
    await _enqueue(
      database,
      id: '01',
      operation: 'patch_task_list',
      entityType: 'task_list',
      taskListId: 'list-1',
      request: {'title': 'Patched'},
    );

    await PendingOpsReplayer(
      database: database,
      apiClient: apiClient,
      accountId: 'account',
      random: Random(0),
      nowUtc: () => DateTime.utc(2026, 6, 4),
    ).replayDueOps();

    final op = await database.select(database.pendingOps).getSingle();
    expect(op.attemptCount, 1);
    expect(op.lastErrorCode, '400');
    expect(op.nextAttemptAtUtc, startsWith('9999-12-31'));
  });

  test('unsupported provider operation is blocked during replay', () async {
    apiClient.clearCompletedError = const GoogleTasksApiError(
      statusCode: 400,
      code: 'unsupported_provider_operation',
      message: 'Clear completed is not supported.',
    );
    await _enqueue(
      database,
      id: '01',
      operation: 'clear_completed_tasks',
      taskListId: 'list-1',
      request: const {},
    );

    final applied = await PendingOpsReplayer(
      database: database,
      apiClient: apiClient,
      accountId: 'account',
      random: Random(0),
      nowUtc: () => DateTime.utc(2026, 6, 4),
    ).replayDueOps();

    final op = await database.select(database.pendingOps).getSingle();
    expect(applied, 0);
    expect(op.lastErrorCode, '400');
    expect(op.lastErrorMessage, contains('Clear completed'));
    expect(op.nextAttemptAtUtc, startsWith('9999-12-31'));
  });
}

class _FakeGoogleTasksApiClient implements GoogleTasksApiClient {
  final calls = <String>[];
  final taskPatchFields = <Map<String, Object?>>[];
  GoogleTasksApiError? patchTaskListError;
  GoogleTasksApiError? deleteTaskError;
  GoogleTasksApiError? clearCompletedError;
  TaskListDto? remoteTaskList;
  TaskDto? remoteTask;
  TasksPageDto remoteTasksPage = const TasksPageDto(items: [], rawJson: {});

  @override
  Future<TaskListDto> createTaskList({required String title}) async {
    calls.add('create_task_list:$title');
    return _taskListDto('list-server', title: title);
  }

  @override
  Future<TaskListDto> patchTaskList(
    String taskListId,
    TaskListPatch patch,
  ) async {
    final error = patchTaskListError;
    if (error != null) {
      throw error;
    }
    calls.add('patch_task_list:$taskListId');
    return _taskListDto(taskListId, title: patch.fields['title'].toString());
  }

  @override
  Future<TaskListDto> updateTaskList(
    String taskListId,
    TaskListPut replacement,
  ) async {
    calls.add('update_task_list:$taskListId');
    return _taskListDto(
      taskListId,
      title: replacement.fields['title'].toString(),
    );
  }

  @override
  Future<void> deleteTaskList(String taskListId) async {
    calls.add('delete_task_list:$taskListId');
  }

  @override
  Future<TaskDto> createTask({
    required String taskListId,
    String? parentTaskId,
    String? previousSiblingTaskId,
    required TaskCreate create,
  }) async {
    calls.add('create_task:$taskListId');
    return _taskDto('task-server', title: create.fields['title'].toString());
  }

  @override
  Future<TaskDto> patchTask({
    required String taskListId,
    required String taskId,
    required TaskPatch patch,
  }) async {
    taskPatchFields.add(patch.fields);
    calls.add('patch_task:$taskId');
    return _taskDto(taskId, title: patch.fields['title'].toString());
  }

  @override
  Future<TaskDto> updateTask({
    required String taskListId,
    required String taskId,
    required TaskPut replacement,
  }) async {
    calls.add('update_task:$taskId');
    return _taskDto(taskId, title: replacement.fields['title'].toString());
  }

  @override
  Future<void> deleteTask({
    required String taskListId,
    required String taskId,
  }) async {
    final error = deleteTaskError;
    if (error != null) {
      throw error;
    }
    calls.add('delete_task:$taskId');
  }

  @override
  Future<TaskDto> moveTask({
    required String sourceTaskListId,
    required String taskId,
    String? parentTaskId,
    String? previousSiblingTaskId,
    String? destinationTaskListId,
  }) async {
    calls.add('move_task:$taskId');
    return _taskDto(taskId, title: 'Moved');
  }

  @override
  Future<void> clearCompletedTasks(String taskListId) async {
    final error = clearCompletedError;
    if (error != null) {
      throw error;
    }
    calls.add('clear:$taskListId');
  }

  @override
  Future<TaskDto> getTask({
    required String taskListId,
    required String taskId,
  }) async {
    return remoteTask ?? _taskDto(taskId);
  }

  @override
  Future<TaskListDto> getTaskList(String taskListId) async {
    return remoteTaskList ?? _taskListDto(taskListId);
  }

  @override
  Future<TaskListsPageDto> listTaskListsPage({
    int maxResults = 1000,
    String? pageToken,
  }) => throw UnimplementedError();

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
    return remoteTasksPage;
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

TaskListsCompanion _taskList(
  String id, {
  String title = 'List',
  String? updatedUtc,
}) {
  return TaskListsCompanion.insert(
    accountId: 'account',
    id: id,
    title: title,
    updatedUtc: Value(updatedUtc),
    rawJson: jsonEncode({'id': id, 'title': title}),
    localDirty: Value(id.startsWith('local-')),
    createdLocalAtUtc: _now,
    updatedLocalAtUtc: _now,
  );
}

TasksCompanion _task(
  String taskListId,
  String id, {
  String title = 'Task',
  String? updatedUtc,
  String? rawJson,
}) {
  return TasksCompanion.insert(
    accountId: 'account',
    taskListId: taskListId,
    id: id,
    title: title,
    updatedUtc: Value(updatedUtc),
    rawJson: rawJson ?? jsonEncode({'id': id, 'title': title}),
    localDirty: Value(id.startsWith('local-')),
    localCreated: Value(id.startsWith('local-')),
    createdLocalAtUtc: _now,
    updatedLocalAtUtc: _now,
  );
}

Future<void> _enqueue(
  AppDatabase database, {
  required String id,
  required String operation,
  required Map<String, Object?> request,
  String entityType = 'task',
  String? operationType,
  String? taskListId,
  String? taskId,
  String? localTempId,
  String? baselineUpdatedUtc,
  String? baselineRawJson,
}) {
  return database.pendingOpsDao.enqueue(
    PendingOpsCompanion.insert(
      id: id,
      accountId: 'account',
      entityType: entityType,
      operation: operation,
      operationType: Value(operationType),
      taskListId: Value(taskListId),
      taskId: Value(taskId),
      localTempId: Value(localTempId),
      baselineUpdatedUtc: Value(baselineUpdatedUtc),
      baselineRawJson: Value(baselineRawJson),
      requestJson: jsonEncode(request),
      createdAtUtc: '2026-06-04T00:00:${id.padLeft(2, '0')}.000Z',
      updatedAtUtc: _now,
    ),
  );
}

TaskListDto _taskListDto(
  String id, {
  String title = 'List',
  DateTime? updated,
}) {
  return TaskListDto(
    id: id,
    title: title,
    updated: updated,
    rawJson: {
      'id': id,
      'title': title,
      if (updated != null) 'updated': updated.toIso8601String(),
    },
  );
}

TaskDto _taskDto(
  String id, {
  String title = 'Task',
  DateTime? updated,
  String? status,
}) {
  return TaskDto(
    id: id,
    title: title,
    updated: updated,
    status: status,
    rawJson: {
      'id': id,
      'title': title,
      if (updated != null) 'updated': updated.toIso8601String(),
      if (status != null) 'status': status,
    },
  );
}

const _now = '2026-06-04T00:00:00.000Z';
final _later = DateTime.utc(2026, 6, 4, 1);

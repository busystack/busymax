import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:busymax/src/db/app_database.dart';
import 'package:busymax/src/features/sync/pending_ops_replayer.dart';
import 'package:busymax/src/features/tasks/data/tasks_repository.dart';
import 'package:busymax/src/features/tasks/domain/task_remote_client.dart';
import 'package:busymax/src/google_tasks/api/google_tasks_api_error.dart';
import 'package:busymax/src/features/tasks/domain/task_remote_models.dart';
import 'package:busymax/src/features/tasks/domain/task_checklist_item.dart';
import 'package:busymax/src/microsoft_todo/api/microsoft_todo_api_client.dart';
import 'package:busymax/src/microsoft_todo/api/microsoft_todo_api_error.dart';
import 'package:busymax/src/microsoft_todo/api/microsoft_todo_api_models.dart';
import 'package:busymax/src/microsoft_todo/api/microsoft_todo_task_remote_client.dart';

void main() {
  late AppDatabase database;
  late _FakeTaskRemoteClient apiClient;

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    apiClient = _FakeTaskRemoteClient();
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

  test('concurrent replayers dispatch a queued task create once', () async {
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
    final createGate = Completer<void>();
    apiClient.createTaskGate = createGate;

    PendingOpsReplayer replayer() => PendingOpsReplayer(
      database: database,
      apiClient: apiClient,
      accountId: 'account',
      nowUtc: () => DateTime.utc(2026, 6, 4),
    );

    final first = replayer().replayDueOps();
    await _waitFor(() => apiClient.calls.length == 1);
    final second = replayer().replayDueOps();
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(apiClient.calls, ['create_task:list-1']);

    createGate.complete();
    expect(await first, 1);
    expect(await second, 0);
    expect(apiClient.calls, ['create_task:list-1']);
  });

  test('task edit waits while its creation is retrying', () async {
    final repository = TasksRepository(
      database: database,
      accountId: 'account',
      nowUtc: () => DateTime.utc(2026, 6, 4),
    );
    await repository.createTask(
      'list-1',
      const TaskCreateInput(title: 'Draft'),
    );
    final localTask = (await database.tasksDao.listTasks(
      'account',
      'list-1',
    )).single;
    await repository.patchTask(
      'list-1',
      localTask.id,
      const TaskPatchInput({'title': 'Edited offline'}),
    );
    apiClient.createTaskError = const GoogleTasksApiError(
      statusCode: 503,
      message: 'Temporarily unavailable',
    );

    final firstApplied = await PendingOpsReplayer(
      database: database,
      apiClient: apiClient,
      accountId: 'account',
      random: Random(0),
      nowUtc: () => DateTime.utc(2026, 6, 4, 1),
    ).replayDueOps();

    expect(firstApplied, 0);
    expect(apiClient.calls, ['create_task:list-1']);
    var operations = await database.select(database.pendingOps).get();
    final pendingCreate = operations.singleWhere(
      (operation) => operation.operation == 'create_task',
    );
    final pendingPatch = operations.singleWhere(
      (operation) => operation.operation == 'patch_task',
    );
    expect(pendingCreate.state, 'retry');
    expect(pendingCreate.attemptCount, 1);
    expect(pendingPatch.dependsOnOpId, pendingCreate.id);
    expect(pendingPatch.attemptCount, 0);

    apiClient.createTaskError = null;
    final secondApplied = await PendingOpsReplayer(
      database: database,
      apiClient: apiClient,
      accountId: 'account',
      random: Random(0),
      nowUtc: () => DateTime.utc(2026, 6, 5),
    ).replayDueOps();

    expect(secondApplied, 2);
    expect(apiClient.calls, [
      'create_task:list-1',
      'create_task:list-1',
      'patch_task:task-server',
    ]);
    expect(apiClient.taskPatchFields.single['title'], 'Edited offline');
    operations = await database.select(database.pendingOps).get();
    expect(operations, isEmpty);
  });

  test('deleting a task whose create is in flight queues after it', () async {
    final repository = TasksRepository(
      database: database,
      accountId: 'account',
      nowUtc: () => DateTime.utc(2026, 6, 4),
    );
    await repository.createTask(
      'list-1',
      const TaskCreateInput(title: 'Draft'),
    );
    final localTask = (await database.tasksDao.listTasks(
      'account',
      'list-1',
    )).single;
    final gate = Completer<void>();
    apiClient.createTaskGate = gate;
    final firstReplay = PendingOpsReplayer(
      database: database,
      apiClient: apiClient,
      accountId: 'account',
      nowUtc: () => DateTime.utc(2026, 6, 4, 1),
    ).replayDueOps();
    await _waitFor(() => apiClient.calls.isNotEmpty);

    await repository.deleteTask('list-1', localTask.id);

    var operations = await database.select(database.pendingOps).get();
    final create = operations.singleWhere(
      (operation) => operation.operation == 'create_task',
    );
    final delete = operations.singleWhere(
      (operation) => operation.operation == 'delete_task',
    );
    expect(create.state, 'in_progress');
    expect(delete.dependsOnOpId, create.id);

    gate.complete();
    expect(await firstReplay, 1);
    expect(
      await PendingOpsReplayer(
        database: database,
        apiClient: apiClient,
        accountId: 'account',
        nowUtc: () => DateTime.utc(2026, 6, 4, 2),
      ).replayDueOps(),
      1,
    );
    expect(apiClient.calls, ['create_task:list-1', 'delete_task:task-server']);
    operations = await database.select(database.pendingOps).get();
    expect(operations, isEmpty);
  });

  test('server ID rewrite revives a legacy blocked task edit', () async {
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
      request: {'title': 'Edited offline'},
    );
    await (database.update(
      database.pendingOps,
    )..where((row) => row.id.equals('02'))).write(
      const PendingOpsCompanion(
        state: Value('failed'),
        attemptCount: Value(1),
        nextAttemptAtUtc: Value('9999-12-31T00:00:00.000Z'),
        lastErrorCode: Value('400'),
        lastErrorMessage: Value('Invalid temporary task ID'),
      ),
    );

    expect(
      await PendingOpsReplayer(
        database: database,
        apiClient: apiClient,
        accountId: 'account',
        nowUtc: () => DateTime.utc(2026, 6, 4, 1),
      ).replayDueOps(),
      1,
    );

    final revived = await database.pendingOpsDao.getOp('02');
    expect(revived!.taskId, 'task-server');
    expect(revived.state, 'pending');
    expect(revived.nextAttemptAtUtc, equals(null));
    expect(revived.lastErrorCode, equals(null));
    expect(revived.lastErrorMessage, equals(null));
    expect(
      await PendingOpsReplayer(
        database: database,
        apiClient: apiClient,
        accountId: 'account',
        nowUtc: () => DateTime.utc(2026, 6, 4, 2),
      ).replayDueOps(),
      1,
    );
    expect(apiClient.calls, ['create_task:list-1', 'patch_task:task-server']);
    expect(await database.select(database.pendingOps).get(), isEmpty);
  });

  test('new task can move to another list before creation sync', () async {
    await database.taskListsDao.upsertTaskList(_taskList('list-2'));
    final repository = TasksRepository(
      database: database,
      accountId: 'account',
      nowUtc: () => DateTime.utc(2026, 6, 4),
    );
    await repository.createTask(
      'list-1',
      const TaskCreateInput(title: 'Draft'),
    );
    final localTask = (await database.tasksDao.listTasks(
      'account',
      'list-1',
    )).single;
    await repository.moveTask(
      TaskMoveInput(
        sourceTaskListId: 'list-1',
        taskId: localTask.id,
        destinationTaskListId: 'list-2',
      ),
    );

    expect(
      await PendingOpsReplayer(
        database: database,
        apiClient: apiClient,
        accountId: 'account',
        nowUtc: () => DateTime.utc(2026, 6, 4, 1),
      ).replayDueOps(),
      2,
    );

    expect(apiClient.calls, ['create_task:list-1', 'move_task:task-server']);
    expect(await database.tasksDao.listTasks('account', 'list-1'), isEmpty);
    final destination = await database.tasksDao.listTasks('account', 'list-2');
    expect(destination.single.id, 'task-server');
  });

  test(
    'Google subtask is moved under its parent after a root insert',
    () async {
      await database.tasksDao.upsertTask(_task('list-1', 'parent'));
      final repository = TasksRepository(
        database: database,
        accountId: 'account',
        apiClient: apiClient,
        nowUtc: () => DateTime.utc(2026, 6, 4),
      );
      await repository.createSubtask(
        taskListId: 'list-1',
        parentTaskId: 'parent',
        title: 'Child',
      );

      final applied = await PendingOpsReplayer(
        database: database,
        apiClient: apiClient,
        accountId: 'account',
        random: Random(0),
        nowUtc: () => DateTime.utc(2026, 6, 4, 1),
      ).replayDueOps();

      expect(applied, 2);
      expect(apiClient.calls, ['create_task:list-1', 'move_task:task-server']);
      expect(apiClient.createParentTaskIds, ['parent']);
      expect(apiClient.moveParentTaskIds, ['parent']);
      expect(await database.select(database.pendingOps).get(), isEmpty);
      final tasks = await database.tasksDao.listTasks('account', 'list-1');
      final child = tasks.singleWhere((task) => task.id == 'task-server');
      expect(child.parent, 'parent');
    },
  );

  test('failed Google subtask move retries without another insert', () async {
    await database.tasksDao.upsertTask(_task('list-1', 'parent'));
    final repository = TasksRepository(
      database: database,
      accountId: 'account',
      apiClient: apiClient,
      nowUtc: () => DateTime.utc(2026, 6, 4),
    );
    await repository.createSubtask(
      taskListId: 'list-1',
      parentTaskId: 'parent',
      title: 'Child',
    );
    apiClient.moveTaskError = const GoogleTasksApiError(
      statusCode: 503,
      message: 'Temporarily unavailable',
    );

    final firstApplied = await PendingOpsReplayer(
      database: database,
      apiClient: apiClient,
      accountId: 'account',
      random: Random(0),
      nowUtc: () => DateTime.utc(2026, 6, 4, 1),
    ).replayDueOps();

    expect(firstApplied, 1);
    var pending = await database.select(database.pendingOps).get();
    expect(pending, hasLength(1));
    expect(pending.single.operation, 'move_task');
    expect(pending.single.taskId, 'task-server');
    expect(apiClient.calls, ['create_task:list-1', 'move_task:task-server']);

    apiClient.moveTaskError = null;
    final secondApplied = await PendingOpsReplayer(
      database: database,
      apiClient: apiClient,
      accountId: 'account',
      random: Random(0),
      nowUtc: () => DateTime.utc(2026, 6, 4, 2),
    ).replayDueOps();

    expect(secondApplied, 1);
    pending = await database.select(database.pendingOps).get();
    expect(pending, isEmpty);
    expect(apiClient.calls, [
      'create_task:list-1',
      'move_task:task-server',
      'move_task:task-server',
    ]);
    final tasks = await database.tasksDao.listTasks('account', 'list-1');
    expect(
      tasks.singleWhere((task) => task.id == 'task-server').parent,
      'parent',
    );
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
    'back-to-back local task patches replay in order without self-conflict',
    () async {
      const baselineUpdatedUtc = '2026-06-04T00:00:00.000Z';
      final baselineRawJson = jsonEncode({
        'id': 'task-1',
        'title': 'Base title',
        'updated': baselineUpdatedUtc,
      });
      apiClient
        ..persistTaskPatches = true
        ..remoteTask = _taskDto(
          'task-1',
          title: 'Base title',
          updated: DateTime.parse(baselineUpdatedUtc),
        );
      await database.tasksDao.upsertTask(
        _task(
          'list-1',
          'task-1',
          title: 'Base title',
          updatedUtc: baselineUpdatedUtc,
          rawJson: baselineRawJson,
        ),
      );
      var localEdit = 0;
      final repository = TasksRepository(
        database: database,
        accountId: 'account',
        nowUtc: () => DateTime.utc(2026, 6, 4, 0, 0, ++localEdit),
      );

      await repository.patchTask(
        'list-1',
        'task-1',
        const TaskPatchInput({'title': 'First local title'}),
      );
      await repository.patchTask(
        'list-1',
        'task-1',
        const TaskPatchInput({'title': 'Second local title'}),
      );

      final queued = await database.pendingOpsDao.pendingOpsForReplay(
        'account',
        _later,
      );
      expect(queued, hasLength(2));
      expect(queued.first.dependsOnOpId, equals(null));
      expect(queued.last.dependsOnOpId, queued.first.id);
      expect(
        queued.map((op) => op.baselineRawJson),
        everyElement(baselineRawJson),
      );
      expect(
        queued.map((op) => op.baselineUpdatedUtc),
        everyElement(baselineUpdatedUtc),
      );

      final applied = await PendingOpsReplayer(
        database: database,
        apiClient: apiClient,
        accountId: 'account',
        random: Random(0),
        nowUtc: () => DateTime.utc(2026, 6, 4, 1),
      ).replayDueOps();

      expect(applied, 2);
      expect(apiClient.taskPatchFields.map((fields) => fields['title']), [
        'First local title',
        'Second local title',
      ]);
      expect(apiClient.remoteTask!.title, 'Second local title');
      expect(await database.select(database.pendingOps).get(), isEmpty);
      final local = await database.tasksDao.listTasks('account', 'list-1');
      expect(local.single.title, 'Second local title');
      expect(local.single.localDirty, isFalse);
    },
  );

  test(
    'earlier local patch does not hide a genuine conflict on a later field',
    () async {
      const baselineUpdatedUtc = '2026-06-04T00:00:00.000Z';
      final baselineRawJson = jsonEncode({
        'id': 'task-1',
        'title': 'Base title',
        'notes': 'Base notes',
        'updated': baselineUpdatedUtc,
      });
      apiClient.persistTaskPatches = true;
      await database.tasksDao.upsertTask(
        _task(
          'list-1',
          'task-1',
          title: 'Base title',
          updatedUtc: baselineUpdatedUtc,
          rawJson: baselineRawJson,
        ),
      );
      var localEdit = 0;
      final repository = TasksRepository(
        database: database,
        accountId: 'account',
        nowUtc: () => DateTime.utc(2026, 6, 4, 0, 0, ++localEdit),
      );
      await repository.patchTask(
        'list-1',
        'task-1',
        const TaskPatchInput({'title': 'Local title'}),
      );
      await repository.patchTask(
        'list-1',
        'task-1',
        const TaskPatchInput({'notes': 'Local notes'}),
      );
      apiClient.remoteTask = _taskDto(
        'task-1',
        title: 'Base title',
        notes: 'Remote notes',
        updated: DateTime.utc(2026, 6, 4, 0, 5),
      );

      final applied = await PendingOpsReplayer(
        database: database,
        apiClient: apiClient,
        accountId: 'account',
        random: Random(0),
        nowUtc: () => DateTime.utc(2026, 6, 4, 1),
      ).replayDueOps();

      expect(applied, 1);
      expect(apiClient.taskPatchFields, [
        {'title': 'Local title'},
      ]);
      expect(apiClient.remoteTask!.title, 'Local title');
      expect(apiClient.remoteTask!.notes, 'Remote notes');
      final pending = await database.select(database.pendingOps).getSingle();
      expect(pending.lastErrorCode, 'conflict');
      expect(pending.lastErrorMessage, contains('notes'));
      final local = await database.tasksDao.listTasks('account', 'list-1');
      expect(local.single.title, 'Local title');
      expect(local.single.notes, 'Local notes');
      expect(local.single.localDirty, isTrue);
    },
  );

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

  for (final statusCode in [400, 403, 404]) {
    test('Microsoft To Do $statusCode errors block operation', () async {
      final microsoftClient = _ThrowingMicrosoftTodoApiClient(
        updateTaskError: MicrosoftTodoApiError(
          statusCode: statusCode,
          code: 'permanent_error',
          message: 'Permanent Microsoft Graph error',
        ),
      );
      await _enqueue(
        database,
        id: '01',
        operation: 'patch_task',
        taskListId: 'list-1',
        taskId: 'task-1',
        request: {'title': 'Patched'},
      );

      final applied = await PendingOpsReplayer(
        database: database,
        apiClient: _microsoftAdapter(microsoftClient),
        accountId: 'account',
        random: Random(0),
        nowUtc: () => DateTime.utc(2026, 6, 4),
      ).replayDueOps();

      final op = await database.select(database.pendingOps).getSingle();
      expect(applied, 0);
      expect(op.attemptCount, 1);
      expect(op.lastErrorCode, '$statusCode');
      expect(op.lastErrorMessage, 'Permanent Microsoft Graph error');
      expect(op.nextAttemptAtUtc, startsWith('9999-12-31'));
    });
  }

  for (final statusCode in [429, 503]) {
    test('Microsoft To Do $statusCode errors schedule retry', () async {
      final microsoftClient = _ThrowingMicrosoftTodoApiClient(
        updateTaskError: MicrosoftTodoApiError(
          statusCode: statusCode,
          code: 'transient_error',
          message: 'Transient Microsoft Graph error',
        ),
      );
      final now = DateTime.utc(2026, 6, 4);
      await _enqueue(
        database,
        id: '01',
        operation: 'patch_task',
        taskListId: 'list-1',
        taskId: 'task-1',
        request: {'title': 'Patched'},
      );

      final applied = await PendingOpsReplayer(
        database: database,
        apiClient: _microsoftAdapter(microsoftClient),
        accountId: 'account',
        random: Random(0),
        nowUtc: () => now,
      ).replayDueOps();

      final op = await database.select(database.pendingOps).getSingle();
      expect(applied, 0);
      expect(op.attemptCount, 1);
      expect(op.lastErrorCode, '$statusCode');
      expect(op.lastErrorMessage, 'Transient Microsoft Graph error');
      expect(DateTime.parse(op.nextAttemptAtUtc!).isAfter(now), isTrue);
      expect(op.nextAttemptAtUtc, isNot(startsWith('9999-12-31')));
    });
  }

  test('Microsoft To Do 404 delete reconciles as success', () async {
    final microsoftClient = _ThrowingMicrosoftTodoApiClient(
      deleteTaskError: const MicrosoftTodoApiError(
        statusCode: 404,
        code: 'not_found',
        message: 'Microsoft To Do task was not found',
      ),
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
      apiClient: _microsoftAdapter(microsoftClient),
      accountId: 'account',
      random: Random(0),
      nowUtc: () => DateTime.utc(2026, 6, 4),
    ).replayDueOps();

    expect(applied, 1);
    expect(await database.select(database.pendingOps).get(), isEmpty);
    expect(await database.tasksDao.listTasks('account', 'list-1'), isEmpty);
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

  test(
    'replays checklist create and dependent patch against the server id',
    () async {
      final checklistClient = _ChecklistTaskRemoteClient();
      await database.tasksDao.upsertTask(
        _task(
          'list-1',
          'task-1',
          checklistItemsJson: jsonEncode([
            {'id': 'local-step', 'displayName': 'Step', 'isChecked': false},
          ]),
        ),
      );
      await _enqueue(
        database,
        id: '01',
        operation: 'create_task_checklist_item',
        entityType: 'task_checklist_item',
        taskListId: 'list-1',
        taskId: 'task-1',
        localTempId: 'local-step',
        request: {
          'checklistItemId': 'local-step',
          'body': {'displayName': 'Step', 'isChecked': false},
        },
      );
      await _enqueue(
        database,
        id: '02',
        operation: 'patch_task_checklist_item',
        entityType: 'task_checklist_item',
        taskListId: 'list-1',
        taskId: 'task-1',
        request: {
          'checklistItemId': 'local-step',
          'body': {'isChecked': true},
        },
      );

      final applied = await PendingOpsReplayer(
        database: database,
        apiClient: checklistClient,
        accountId: 'account',
        random: Random(0),
        nowUtc: () => DateTime.utc(2026, 6, 4),
      ).replayDueOps();

      final task = (await database.tasksDao.listTasks(
        'account',
        'list-1',
      )).single;
      final item = decodeTaskChecklistItems(
        task.microsoftChecklistItemsJson,
      ).single;
      expect(applied, 2);
      expect(checklistClient.checklistCalls, [
        'create:Step',
        'update:server-step:true',
      ]);
      expect(item.id, 'server-step');
      expect(item.completed, isTrue);
      expect(await database.select(database.pendingOps).get(), isEmpty);
    },
  );
}

MicrosoftTodoTaskRemoteClient _microsoftAdapter(MicrosoftTodoApiClient client) {
  return MicrosoftTodoTaskRemoteClient(
    client: client,
    defaultTimeZone: 'UTC',
    nowUtc: () => DateTime.utc(2026, 6, 4),
  );
}

class _ThrowingMicrosoftTodoApiClient implements MicrosoftTodoApiClient {
  _ThrowingMicrosoftTodoApiClient({this.updateTaskError, this.deleteTaskError});

  final MicrosoftTodoApiError? updateTaskError;
  final MicrosoftTodoApiError? deleteTaskError;

  @override
  Future<void> deleteTask({
    required String taskListId,
    required String taskId,
  }) async {
    final error = deleteTaskError;
    if (error != null) {
      throw error;
    }
  }

  @override
  Future<MicrosoftTodoTaskDto> updateTask({
    required String taskListId,
    required String taskId,
    required Map<String, Object?> patch,
  }) async {
    final error = updateTaskError;
    if (error != null) {
      throw error;
    }
    return MicrosoftTodoTaskDto(
      id: taskId,
      title: patch['title']?.toString(),
      categories: const [],
      rawJson: {'id': taskId, ...patch},
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeTaskRemoteClient implements TaskRemoteClient {
  final calls = <String>[];
  final taskPatchFields = <Map<String, Object?>>[];
  final createParentTaskIds = <String?>[];
  final moveParentTaskIds = <String?>[];
  GoogleTasksApiError? patchTaskListError;
  GoogleTasksApiError? createTaskError;
  GoogleTasksApiError? deleteTaskError;
  GoogleTasksApiError? clearCompletedError;
  GoogleTasksApiError? moveTaskError;
  TaskListDto? remoteTaskList;
  TaskDto? remoteTask;
  Completer<void>? createTaskGate;
  bool persistTaskPatches = false;
  int _taskPatchRevision = 0;
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
    createParentTaskIds.add(parentTaskId);
    await createTaskGate?.future;
    final error = createTaskError;
    if (error != null) throw error;
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
    final current = remoteTask;
    final dto = persistTaskPatches
        ? _taskDto(
            taskId,
            title: patch.fields.containsKey('title')
                ? patch.fields['title']?.toString() ?? ''
                : current?.title ?? '',
            notes: patch.fields.containsKey('notes')
                ? patch.fields['notes']?.toString()
                : current?.notes,
            updated: DateTime.utc(2026, 6, 4, 0, ++_taskPatchRevision + 5),
          )
        : _taskDto(taskId, title: patch.fields['title'].toString());
    if (persistTaskPatches) {
      remoteTask = dto;
    }
    return dto;
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
    moveParentTaskIds.add(parentTaskId);
    final error = moveTaskError;
    if (error != null) throw error;
    return _taskDto(taskId, title: 'Moved', parent: parentTaskId);
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

class _ChecklistTaskRemoteClient extends _FakeTaskRemoteClient
    implements TaskChecklistRemoteClient {
  final checklistCalls = <String>[];

  @override
  Future<TaskChecklistItemDto> createChecklistItem({
    required String taskListId,
    required String taskId,
    required String title,
    bool completed = false,
  }) async {
    checklistCalls.add('create:$title');
    return TaskChecklistItemDto(
      id: 'server-step',
      title: title,
      completed: completed,
      rawJson: {
        'id': 'server-step',
        'displayName': title,
        'isChecked': completed,
      },
    );
  }

  @override
  Future<TaskChecklistItemDto> updateChecklistItem({
    required String taskListId,
    required String taskId,
    required String checklistItemId,
    String? title,
    bool? completed,
  }) async {
    checklistCalls.add('update:$checklistItemId:$completed');
    return TaskChecklistItemDto(
      id: checklistItemId,
      title: title ?? 'Step',
      completed: completed ?? false,
      rawJson: {
        'id': checklistItemId,
        'displayName': title ?? 'Step',
        'isChecked': completed ?? false,
      },
    );
  }

  @override
  Future<void> deleteChecklistItem({
    required String taskListId,
    required String taskId,
    required String checklistItemId,
  }) async {
    checklistCalls.add('delete:$checklistItemId');
  }

  @override
  Future<TaskChecklistItemsPageDto> listChecklistItemsPage({
    required String taskListId,
    required String taskId,
    String? pageToken,
  }) async => const TaskChecklistItemsPageDto(items: [], rawJson: {});
}

Future<void> _insertAccount(AppDatabase database) {
  return database
      .into(database.accounts)
      .insert(
        AccountsCompanion.insert(
          id: 'account',
          provider: 'google',
          authority: 'https://accounts.google.com',
          providerAccountId: 'google-account',
          credentialKind: 'oauth',
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
  String? checklistItemsJson,
}) {
  return TasksCompanion.insert(
    accountId: 'account',
    taskListId: taskListId,
    id: id,
    title: title,
    updatedUtc: Value(updatedUtc),
    rawJson: rawJson ?? jsonEncode({'id': id, 'title': title}),
    microsoftChecklistItemsJson: Value(checklistItemsJson),
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
  String? notes,
  DateTime? updated,
  String? status,
  String? parent,
}) {
  return TaskDto(
    id: id,
    title: title,
    notes: notes,
    updated: updated,
    status: status,
    parent: parent,
    rawJson: {
      'id': id,
      'title': title,
      if (notes != null) 'notes': notes,
      if (updated != null) 'updated': updated.toIso8601String(),
      if (status != null) 'status': status,
      if (parent != null) 'parent': parent,
    },
  );
}

Future<void> _waitFor(bool Function() condition) async {
  final deadline = DateTime.now().add(const Duration(seconds: 2));
  while (DateTime.now().isBefore(deadline)) {
    if (condition()) return;
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  fail('Timed out waiting for condition.');
}

const _now = '2026-06-04T00:00:00.000Z';
final _later = DateTime.utc(2026, 6, 4, 1);

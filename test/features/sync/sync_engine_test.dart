import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:busymax/src/db/app_database.dart';
import 'package:busymax/src/features/sync/sync_engine.dart';
import 'package:busymax/src/google_tasks/api/google_tasks_api_client.dart';
import 'package:busymax/src/google_tasks/api/google_tasks_api_models.dart';

void main() {
  late AppDatabase database;
  late FakeGoogleTasksApiClient apiClient;

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    await _insertAccount(database);
    apiClient = FakeGoogleTasksApiClient();
  });

  tearDown(() async {
    await database.close();
  });

  test('full sync upserts task lists and tasks', () async {
    apiClient.taskListsPages = [
      TaskListsPageDto(items: [_taskListDto('list-1')], rawJson: const {}),
    ];
    apiClient.taskPages['list-1'] = [
      TasksPageDto(items: [_taskDto('task-1')], rawJson: const {}),
    ];

    await SyncEngine(
      database: database,
      apiClient: apiClient,
      accountId: 'account',
      nowUtc: () => DateTime.utc(2026, 6, 4),
    ).fullSync();

    final lists = await database.taskListsDao.listTaskLists('account');
    final tasks = await database.tasksDao.listTasks('account', 'list-1');
    final runs = await database.syncRunsDao.recentRuns('account');

    expect(lists.single.id, 'list-1');
    expect(tasks.single.id, 'task-1');
    expect(runs.single.status, 'success');
    expect(runs.single.taskListsSeen, 1);
    expect(runs.single.tasksSeen, 1);
  });

  test('full sync marks absent tasks server missing', () async {
    await database.taskListsDao.upsertTaskList(_localTaskList('list-1'));
    await database.tasksDao.upsertTask(_localTask('old-task'));
    apiClient.taskListsPages = [
      TaskListsPageDto(items: [_taskListDto('list-1')], rawJson: const {}),
    ];
    apiClient.taskPages['list-1'] = [
      const TasksPageDto(items: [], rawJson: {}),
    ];

    await SyncEngine(
      database: database,
      apiClient: apiClient,
      accountId: 'account',
      nowUtc: () => DateTime.utc(2026, 6, 4),
    ).fullSync();

    final tasks = await database.tasksDao.listTasks('account', 'list-1');

    expect(tasks.single.serverMissing, isTrue);
  });

  test('incremental sync uses updatedMin with two minute overlap', () async {
    await (database.update(
      database.accounts,
    )..where((row) => row.id.equals('account'))).write(
      const AccountsCompanion(
        lastSuccessfulSyncAtUtc: Value('2026-06-04T00:10:00.000Z'),
      ),
    );
    apiClient.taskListsPages = [
      TaskListsPageDto(items: [_taskListDto('list-1')], rawJson: const {}),
    ];
    apiClient.taskPages['list-1'] = [
      const TasksPageDto(items: [], rawJson: {}),
    ];

    await SyncEngine(
      database: database,
      apiClient: apiClient,
      accountId: 'account',
      nowUtc: () => DateTime.utc(2026, 6, 4),
    ).incrementalSync();

    expect(apiClient.lastUpdatedMin, DateTime.utc(2026, 6, 4, 0, 8));
  });

  test('full-refresh-only incremental sync does not send updatedMin', () async {
    await (database.update(
      database.accounts,
    )..where((row) => row.id.equals('account'))).write(
      const AccountsCompanion(
        lastSuccessfulSyncAtUtc: Value('2026-06-04T00:10:00.000Z'),
      ),
    );
    apiClient.taskListsPages = [
      TaskListsPageDto(items: [_taskListDto('list-1')], rawJson: const {}),
    ];
    apiClient.taskPages['list-1'] = [
      const TasksPageDto(items: [], rawJson: {}),
    ];

    await SyncEngine(
      database: database,
      apiClient: apiClient,
      accountId: 'account',
      fullRefreshOnly: true,
      nowUtc: () => DateTime.utc(2026, 6, 4),
    ).incrementalSync();

    expect(apiClient.lastUpdatedMin, null);
  });

  test(
    'full-refresh-only incremental sync follows list and task pages',
    () async {
      apiClient.taskListsPages = [
        TaskListsPageDto(
          items: [_taskListDto('list-1')],
          nextPageToken: 'list-next',
          rawJson: const {},
        ),
        TaskListsPageDto(items: [_taskListDto('list-2')], rawJson: const {}),
      ];
      apiClient.taskPages['list-1'] = [
        TasksPageDto(
          items: [_taskDto('task-1')],
          nextPageToken: 'task-next',
          rawJson: const {},
        ),
        TasksPageDto(items: [_taskDto('task-2')], rawJson: const {}),
      ];
      apiClient.taskPages['list-2'] = [
        TasksPageDto(items: [_taskDto('task-3')], rawJson: const {}),
      ];

      await SyncEngine(
        database: database,
        apiClient: apiClient,
        accountId: 'account',
        fullRefreshOnly: true,
        nowUtc: () => DateTime.utc(2026, 6, 4),
      ).incrementalSync();

      expect(apiClient.listPageTokens, [null, 'list-next']);
      expect(apiClient.taskPageTokens['list-1'], [null, 'task-next']);
      expect(apiClient.taskPageTokens['list-2'], [null]);
      expect(
        await database.taskListsDao.listTaskLists('account'),
        hasLength(2),
      );
      expect(
        await database.tasksDao.listTasks('account', 'list-1'),
        hasLength(2),
      );
    },
  );

  test('full-refresh-only sync pulls remote task changes', () async {
    await database.taskListsDao.upsertTaskList(_localTaskList('list-1'));
    await database.tasksDao.upsertTask(_localTask('task-1'));
    apiClient.taskListsPages = [
      TaskListsPageDto(items: [_taskListDto('list-1')], rawJson: const {}),
    ];
    apiClient.taskPages['list-1'] = [
      TasksPageDto(
        items: [
          TaskDto(
            id: 'task-1',
            title: 'Remote title',
            status: 'completed',
            rawJson: {
              'id': 'task-1',
              'title': 'Remote title',
              'status': 'completed',
              'dueDateTime': {
                'dateTime': '2026-06-06T14:30:00',
                'timeZone': 'America/Vancouver',
              },
            },
          ),
        ],
        rawJson: const {},
      ),
    ];

    await SyncEngine(
      database: database,
      apiClient: apiClient,
      accountId: 'account',
      fullRefreshOnly: true,
      nowUtc: () => DateTime.utc(2026, 6, 4),
    ).incrementalSync();

    final task = (await database.tasksDao.listTasks(
      'account',
      'list-1',
    )).single;
    expect(task.title, 'Remote title');
    expect(task.status, 'completed');
    expect(task.dueUtc, '2026-06-06');
    expect(task.microsoftDueDateTime, '2026-06-06T14:30:00');
    expect(task.microsoftDueTimeZone, 'America/Vancouver');
  });

  test('full-refresh-only sync marks missing rows server missing', () async {
    await database.taskListsDao.upsertTaskList(_localTaskList('missing-list'));
    await database.taskListsDao.upsertTaskList(_localTaskList('list-1'));
    await database.tasksDao.upsertTask(_localTask('old-task'));
    apiClient.taskListsPages = [
      TaskListsPageDto(items: [_taskListDto('list-1')], rawJson: const {}),
    ];
    apiClient.taskPages['list-1'] = [
      const TasksPageDto(items: [], rawJson: {}),
    ];

    await SyncEngine(
      database: database,
      apiClient: apiClient,
      accountId: 'account',
      fullRefreshOnly: true,
      nowUtc: () => DateTime.utc(2026, 6, 4),
    ).incrementalSync();

    final lists = await database.taskListsDao.listTaskLists('account');
    final tasks = await database.tasksDao.listTasks('account', 'list-1');
    expect(
      lists.singleWhere((list) => list.id == 'missing-list').serverMissing,
      isTrue,
    );
    expect(tasks.single.serverMissing, isTrue);
  });

  test('sync replays pending operations before pulling remote rows', () async {
    await database.taskListsDao.upsertTaskList(_localTaskList('list-1'));
    await database.tasksDao.upsertTask(_localTask('local-task-1'));
    await database.pendingOpsDao.enqueue(
      PendingOpsCompanion.insert(
        id: 'op-1',
        accountId: 'account',
        entityType: 'task',
        operation: 'create_task',
        taskListId: const Value('list-1'),
        taskId: const Value('local-task-1'),
        localTempId: const Value('local-task-1'),
        requestJson: jsonEncode({
          'body': {'title': 'Offline task'},
        }),
        createdAtUtc: _now,
        updatedAtUtc: _now,
      ),
    );
    apiClient.taskListsPages = [
      TaskListsPageDto(items: [_taskListDto('list-1')], rawJson: const {}),
    ];
    apiClient.taskPages['list-1'] = [
      const TasksPageDto(items: [], rawJson: {}),
    ];

    await SyncEngine(
      database: database,
      apiClient: apiClient,
      accountId: 'account',
      nowUtc: () => DateTime.utc(2026, 6, 4),
    ).fullSync();

    final runs = await database.syncRunsDao.recentRuns('account');
    final tasks = await database.tasksDao.listTasks('account', 'list-1');

    expect(apiClient.calls.first, 'create_task:Offline task');
    expect(runs.single.pendingOpsApplied, 1);
    expect(tasks.map((task) => task.id), contains('task-server'));
    expect(tasks.map((task) => task.id), isNot(contains('local-task-1')));
  });

  test('pull sync does not overwrite pending local task edits', () async {
    await database.taskListsDao.upsertTaskList(_localTaskList('list-1'));
    await database.tasksDao.upsertTask(
      _localTask('task-1', title: 'Local edited title', localDirty: true),
    );
    await database.pendingOpsDao.enqueue(
      PendingOpsCompanion.insert(
        id: 'op-1',
        accountId: 'account',
        entityType: 'task',
        operation: 'patch_task',
        taskListId: const Value('list-1'),
        taskId: const Value('task-1'),
        requestJson: jsonEncode({'title': 'Local edited title'}),
        createdAtUtc: _now,
        updatedAtUtc: _now,
      ),
    );
    apiClient.taskListsPages = [
      TaskListsPageDto(items: [_taskListDto('list-1')], rawJson: const {}),
    ];
    apiClient.taskPages['list-1'] = [
      TasksPageDto(
        items: [_taskDto('task-1', title: 'Old remote title')],
        rawJson: const {},
      ),
    ];

    await SyncEngine(
      database: database,
      apiClient: apiClient,
      accountId: 'account',
      nowUtc: () => DateTime.utc(2026, 6, 4),
    ).fullSync();

    final task = (await database.tasksDao.listTasks(
      'account',
      'list-1',
    )).single;
    final op = await database.pendingOpsDao.getOp('op-1');

    expect(task.title, 'Local edited title');
    expect(task.localDirty, isTrue);
    expect(op == null, isFalse);
    expect(op!.attemptCount, 1);
  });

  test('pull sync does not overwrite pending local task list edits', () async {
    await database.taskListsDao.upsertTaskList(
      _localTaskList('list-1', title: 'Local edited list', localDirty: true),
    );
    await database.pendingOpsDao.enqueue(
      PendingOpsCompanion.insert(
        id: 'op-1',
        accountId: 'account',
        entityType: 'task_list',
        operation: 'patch_task_list',
        taskListId: const Value('list-1'),
        requestJson: jsonEncode({'title': 'Local edited list'}),
        createdAtUtc: _now,
        updatedAtUtc: _now,
      ),
    );
    apiClient.taskListsPages = [
      TaskListsPageDto(
        items: [_taskListDto('list-1', title: 'Old remote list')],
        rawJson: const {},
      ),
    ];
    apiClient.taskPages['list-1'] = [
      const TasksPageDto(items: [], rawJson: {}),
    ];

    await SyncEngine(
      database: database,
      apiClient: apiClient,
      accountId: 'account',
      nowUtc: () => DateTime.utc(2026, 6, 4),
    ).fullSync();

    final list = (await database.taskListsDao.listTaskLists('account')).single;
    final op = await database.pendingOpsDao.getOp('op-1');

    expect(list.title, 'Local edited list');
    expect(list.localDirty, isTrue);
    expect(op == null, isFalse);
    expect(op!.attemptCount, 1);
  });
}

class FakeGoogleTasksApiClient implements GoogleTasksApiClient {
  var taskListsPages = <TaskListsPageDto>[];
  final taskPages = <String, List<TasksPageDto>>{};
  final calls = <String>[];
  final listPageTokens = <String?>[];
  final taskPageTokens = <String, List<String?>>{};
  DateTime? lastUpdatedMin;
  var _taskListPageIndex = 0;
  final _taskPageIndexes = <String, int>{};

  @override
  Future<TaskListsPageDto> listTaskListsPage({
    int maxResults = 1000,
    String? pageToken,
  }) async {
    listPageTokens.add(pageToken);
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
    lastUpdatedMin = updatedMin;
    taskPageTokens.putIfAbsent(taskListId, () => []).add(pageToken);
    final index = _taskPageIndexes.update(
      taskListId,
      (value) => value + 1,
      ifAbsent: () => 0,
    );
    return taskPages[taskListId]![index];
  }

  @override
  Future<void> clearCompletedTasks(String taskListId) =>
      throw UnimplementedError();

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

TaskListDto _taskListDto(String id, {String title = 'List'}) {
  return TaskListDto(id: id, title: title, rawJson: {'id': id, 'title': title});
}

TaskDto _taskDto(String id, {String title = 'Task'}) {
  return TaskDto(id: id, title: title, rawJson: {'id': id, 'title': title});
}

TaskListsCompanion _localTaskList(
  String id, {
  String title = 'Local list',
  bool localDirty = false,
}) {
  return TaskListsCompanion.insert(
    accountId: 'account',
    id: id,
    title: title,
    rawJson: '{}',
    localDirty: Value(localDirty),
    createdLocalAtUtc: _now,
    updatedLocalAtUtc: _now,
  );
}

TasksCompanion _localTask(
  String id, {
  String title = 'Local task',
  bool localDirty = false,
}) {
  return TasksCompanion.insert(
    accountId: 'account',
    taskListId: 'list-1',
    id: id,
    title: title,
    rawJson: '{}',
    localDirty: Value(localDirty),
    createdLocalAtUtc: _now,
    updatedLocalAtUtc: _now,
  );
}

const _now = '2026-06-04T00:00:00.000Z';

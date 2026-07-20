import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:busymax/src/db/app_database.dart';
import 'package:busymax/src/features/tasks/data/tasks_repository.dart';

void main() {
  late AppDatabase database;
  late TasksRepository repository;

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    await _insertAccount(database);
    await database.taskListsDao.upsertTaskList(_taskList());
    repository = TasksRepository(
      database: database,
      accountId: 'account',
      nowUtc: () => DateTime.utc(2026, 6, 4),
    );
  });

  tearDown(() async {
    await database.close();
  });

  test('createTask writes local task and queues create op', () async {
    var mutationQueuedCalls = 0;
    repository = _repository(
      database,
      onMutationQueued: () => mutationQueuedCalls += 1,
    );

    await repository.createTask(
      'list-1',
      TaskCreateInput(
        title: 'Task',
        notes: 'Notes',
        dueUtc: DateTime.utc(2026, 6, 5, 13, 30),
      ),
    );

    final tasks = await database.tasksDao.listTasks('account', 'list-1');
    final ops = await database.pendingOpsDao.pendingOpsForReplay(
      'account',
      DateTime.utc(2026, 6, 4, 1),
    );

    expect(tasks.single.id, startsWith('local-task-'));
    expect(tasks.single.title, 'Task');
    expect(tasks.single.dueUtc, '2026-06-05');
    expect(tasks.single.localDirty, isTrue);
    expect(ops.single.operation, 'create_task');
    expect((jsonDecode(ops.single.requestJson) as Map)['body'], {
      'title': 'Task',
      'notes': 'Notes',
      'due': '2026-06-05T00:00:00.000Z',
    });
    expect(mutationQueuedCalls, 1);
  });

  test('createTask writes and queues extended task fields', () async {
    await repository.createTask(
      'list-1',
      const TaskCreateInput(
        title: 'Task',
        fields: {
          'title': 'Task',
          'microsoftDueDateTime': {
            'dateTime': '2026-06-05T09:30:00',
            'timeZone': 'America/Vancouver',
          },
          'microsoftDueTimeZone': 'America/Vancouver',
          'microsoftReminderDateTime': {
            'dateTime': '2026-06-05T08:30:00',
            'timeZone': 'America/Vancouver',
          },
          'microsoftReminderTimeZone': 'America/Vancouver',
          'microsoftIsReminderOn': true,
          'recurrence': {
            'pattern': {'type': 'daily', 'interval': 1},
            'range': {'type': 'noEnd', 'startDate': '2026-06-05'},
          },
          'importance': 'high',
          'categories': ['Work'],
        },
      ),
    );

    final tasks = await database.tasksDao.listTasks('account', 'list-1');
    final ops = await database.pendingOpsDao.pendingOpsForReplay(
      'account',
      DateTime.utc(2026, 6, 4, 1),
    );
    final body = (jsonDecode(ops.single.requestJson) as Map)['body'] as Map;

    expect(tasks.single.microsoftDueDateTime, '2026-06-05T09:30:00');
    expect(tasks.single.microsoftDueTimeZone, 'America/Vancouver');
    expect(tasks.single.microsoftReminderDateTime, '2026-06-05T08:30:00');
    expect(tasks.single.microsoftReminderTimeZone, 'America/Vancouver');
    expect(tasks.single.microsoftIsReminderOn, isTrue);
    expect(tasks.single.importance, 'high');
    expect(jsonDecode(tasks.single.categoriesJson!), ['Work']);
    expect(body['microsoftDueDateTime'], {
      'dateTime': '2026-06-05T09:30:00',
      'timeZone': 'America/Vancouver',
    });
    expect(body['microsoftIsReminderOn'], isTrue);
    expect(body['importance'], 'high');
    expect(body['categories'], ['Work']);
  });

  test('patchTask updates local fields and queues patch op', () async {
    var mutationQueuedCalls = 0;
    repository = _repository(
      database,
      onMutationQueued: () => mutationQueuedCalls += 1,
    );
    await database.tasksDao.upsertTask(
      _task(
        id: 'task-1',
        position: '1',
        updatedUtc: const Value('2026-06-04T00:00:00.000Z'),
        rawJson: '{"id":"task-1","title":"Original"}',
      ),
    );

    await repository.patchTask(
      'list-1',
      'task-1',
      const TaskPatchInput({'title': 'Updated', 'status': 'completed'}),
    );

    final tasks = await database.tasksDao.listTasks('account', 'list-1');
    final ops = await database.pendingOpsDao.pendingOpsForReplay(
      'account',
      DateTime.utc(2026, 6, 4, 1),
    );

    expect(tasks.single.title, 'Updated');
    expect(tasks.single.status, 'completed');
    expect(tasks.single.localDirty, isTrue);
    expect(ops.single.operation, 'patch_task');
    expect(ops.single.baselineUpdatedUtc, '2026-06-04T00:00:00.000Z');
    expect(ops.single.baselineRawJson, '{"id":"task-1","title":"Original"}');
    expect(mutationQueuedCalls, 1);
  });

  test('patchTask rebuilds task reminders and notifies scheduler', () async {
    var schedulerCalls = 0;
    repository = _repository(
      database,
      onNotificationScheduleChanged: () async => schedulerCalls += 1,
    );
    await database.tasksDao.upsertTask(
      _task(
        id: 'task-1',
        position: '1',
        rawJson: '{"id":"task-1","title":"Original"}',
      ),
    );

    await repository.patchTask(
      'list-1',
      'task-1',
      const TaskPatchInput({
        'microsoftIsReminderOn': true,
        'microsoftReminderDateTime': {
          'dateTime': '2026-06-05T08:30:00',
          'timeZone': 'America/Vancouver',
        },
        'microsoftReminderTimeZone': 'America/Vancouver',
      }),
    );

    final rows = await database.select(database.notificationSchedule).get();

    expect(schedulerCalls, 1);
    expect(rows.single.sourceType, 'task');
    expect(rows.single.title, 'task-1');
    expect(
      rows.single.scheduledAtUtc,
      DateTime(2026, 6, 5, 8, 30).toUtc().millisecondsSinceEpoch,
    );
  });

  test('task mutations request sync after queuing pending ops', () async {
    var mutationQueuedCalls = 0;
    repository = _repository(
      database,
      onMutationQueued: () => mutationQueuedCalls += 1,
    );

    await database.tasksDao.upsertTask(_task(id: 'patch', position: '1'));
    await database.tasksDao.upsertTask(_task(id: 'update', position: '2'));
    await database.tasksDao.upsertTask(_task(id: 'delete', position: '3'));
    await database.tasksDao.upsertTask(_task(id: 'move', position: '4'));
    await database.tasksDao.upsertTask(
      _task(id: 'completed', position: '5', status: const Value('completed')),
    );

    await repository.patchTask(
      'list-1',
      'patch',
      const TaskPatchInput({'title': 'Patched'}),
    );
    await repository.updateTaskFull(
      'list-1',
      'update',
      TaskPutInput({'title': 'Updated'}),
    );
    await repository.deleteTask('list-1', 'delete');
    await repository.moveTask(
      const TaskMoveInput(sourceTaskListId: 'list-1', taskId: 'move'),
    );
    await repository.clearCompleted('list-1');

    final ops = await database.pendingOpsDao.pendingOpsForReplay(
      'account',
      DateTime.utc(2026, 6, 4, 1),
    );

    expect(mutationQueuedCalls, 5);
    expect(
      ops.map((op) => op.operation),
      containsAll([
        'patch_task',
        'update_task',
        'delete_task',
        'move_task',
        'clear_completed_tasks',
      ]),
    );
  });

  test('clearCompleted queues latest completed task baseline', () async {
    await database.tasksDao.upsertTask(
      _task(
        id: 'completed-older',
        position: '1',
        status: const Value('completed'),
        updatedUtc: const Value('2026-06-04T00:05:00.000Z'),
      ),
    );
    await database.tasksDao.upsertTask(
      _task(
        id: 'completed-newer',
        position: '2',
        status: const Value('completed'),
        updatedUtc: const Value('2026-06-04T00:10:00.000Z'),
      ),
    );
    await database.tasksDao.upsertTask(
      _task(
        id: 'active-newer',
        position: '3',
        status: const Value('needsAction'),
        updatedUtc: const Value('2026-06-04T00:20:00.000Z'),
      ),
    );

    await repository.clearCompleted('list-1');

    final ops = await database.pendingOpsDao.pendingOpsForReplay(
      'account',
      DateTime.utc(2026, 6, 4, 1),
    );

    expect(ops.single.operation, 'clear_completed_tasks');
    expect(ops.single.baselineUpdatedUtc, '2026-06-04T00:10:00.000Z');
  });

  test(
    'watchTaskTree filters hidden rows and sorts position as string',
    () async {
      await database.tasksDao.upsertTask(_task(id: 'task-2', position: '2'));
      await database.tasksDao.upsertTask(_task(id: 'task-10', position: '10'));
      await database.tasksDao.upsertTask(
        _task(id: 'hidden', position: '1', hidden: const Value(true)),
      );
      await database.tasksDao.upsertTask(
        _task(id: 'missing', position: '0', serverMissing: const Value(true)),
      );

      final tree = await repository
          .watchTaskTree('list-1', const TaskViewFilter())
          .first;

      expect(tree.map((node) => node.task.id), ['task-10', 'task-2']);
    },
  );
}

TasksRepository _repository(
  AppDatabase database, {
  void Function()? onMutationQueued,
  Future<void> Function()? onNotificationScheduleChanged,
}) {
  return TasksRepository(
    database: database,
    accountId: 'account',
    onMutationQueued: onMutationQueued,
    onNotificationScheduleChanged: onNotificationScheduleChanged,
    nowUtc: () => DateTime.utc(2026, 6, 4),
  );
}

Future<void> _insertAccount(AppDatabase database) {
  return database
      .into(database.accounts)
      .insert(
        AccountsCompanion.insert(
          id: 'account',
          authState: const Value('signed_in'),
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

TasksCompanion _task({
  required String id,
  required String position,
  Value<bool?> hidden = const Value.absent(),
  Value<bool> serverMissing = const Value.absent(),
  Value<String?> status = const Value.absent(),
  Value<String?> updatedUtc = const Value.absent(),
  String rawJson = '{}',
}) {
  return TasksCompanion.insert(
    accountId: 'account',
    taskListId: 'list-1',
    id: id,
    title: id,
    position: Value(position),
    hidden: hidden,
    serverMissing: serverMissing,
    status: status,
    updatedUtc: updatedUtc,
    rawJson: rawJson,
    createdLocalAtUtc: _now,
    updatedLocalAtUtc: _now,
  );
}

const _now = '2026-06-04T00:00:00.000Z';

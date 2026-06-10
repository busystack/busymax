import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3;
import 'package:busymax/src/features/task_lists/data/task_lists_repository.dart';
import 'package:busymax/src/features/tasks/data/tasks_repository.dart';
import 'package:busymax/src/db/app_database.dart';
import 'package:busymax/src/google_tasks/api/google_tasks_api_models.dart';

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await database.close();
  });

  test('opens schema version 4 and creates required indexes', () async {
    final version = await database
        .customSelect('PRAGMA user_version')
        .getSingle();
    final indexes = await database
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type = 'index' "
          "AND name LIKE 'idx_%' ORDER BY name",
        )
        .get();

    expect(version.data['user_version'], 4);
    expect(indexes.map((row) => row.data['name']).toSet(), {
      'idx_accounts_provider',
      'idx_accounts_provider_account',
      'idx_task_lists_account_title',
      'idx_task_lists_dirty',
      'idx_tasks_dirty',
      'idx_tasks_list_order',
      'idx_tasks_status_due',
      'idx_tasks_updated',
      'idx_calendar_events_dirty',
      'idx_calendar_events_provider_id',
      'idx_calendar_events_range',
      'idx_calendar_sources_provider_id',
      'idx_calendar_sources_visible',
      'idx_calendar_sync_states_scope',
      'idx_notification_schedule_due',
    });
  });

  test('upserts task lists and preserves raw JSON', () async {
    await _insertAccount(database);

    await database.taskListsDao.upsertTaskList(
      _taskList(id: 'list-1', title: 'Inbox', rawJson: '{"unknown":1}'),
    );
    await database.taskListsDao.upsertTaskList(
      _taskList(id: 'list-1', title: 'Renamed', rawJson: '{"unknown":2}'),
    );

    final lists = await database.taskListsDao.listTaskLists('account');

    expect(lists, hasLength(1));
    expect(lists.single.title, 'Renamed');
    expect(lists.single.rawJson, '{"unknown":2}');
  });

  test(
    'upserts tasks and orders tree rows by opaque position string',
    () async {
      await _insertAccount(database);
      await database.taskListsDao.upsertTaskList(_taskList(id: 'list-1'));

      await database.tasksDao.upsertTask(
        _task(id: 'task-2', position: '2', title: 'Second'),
      );
      await database.tasksDao.upsertTask(
        _task(id: 'task-10', position: '10', title: 'Tenth'),
      );

      final tasks = await database.tasksDao.listTasks('account', 'list-1');

      expect(tasks.map((task) => task.id), ['task-10', 'task-2']);
      expect(tasks.first.rawJson, '{"id":"task-10"}');
    },
  );

  test(
    'cascade deletes task lists and tasks when account is deleted',
    () async {
      await _insertAccount(database);
      await database.taskListsDao.upsertTaskList(_taskList(id: 'list-1'));
      await database.tasksDao.upsertTask(_task(id: 'task-1', position: '1'));

      await (database.delete(
        database.accounts,
      )..where((row) => row.id.equals('account'))).go();

      expect(await database.taskListsDao.listTaskLists('account'), isEmpty);
      expect(await database.tasksDao.listTasks('account', 'list-1'), isEmpty);
    },
  );

  test(
    'pending ops are returned in replay order and respect backoff',
    () async {
      await _insertAccount(database);
      await database.pendingOpsDao.enqueue(
        _pendingOp(id: 'later', createdAtUtc: '2026-06-04T00:01:00.000Z'),
      );
      await database.pendingOpsDao.enqueue(
        _pendingOp(id: 'first', createdAtUtc: '2026-06-04T00:00:00.000Z'),
      );
      await database.pendingOpsDao.enqueue(
        _pendingOp(
          id: 'backoff',
          createdAtUtc: '2026-06-04T00:00:30.000Z',
          nextAttemptAtUtc: const Value('2026-06-04T00:10:00.000Z'),
        ),
      );

      final ops = await database.pendingOpsDao.pendingOpsForReplay(
        'account',
        DateTime.utc(2026, 6, 4, 0, 5),
      );

      expect(ops.map((op) => op.id), ['first', 'later']);
    },
  );

  test('Microsoft list and task fields survive DTO upsert', () async {
    await _insertAccount(database);

    await database.taskListsDao.upsertTaskList(
      taskListFromDto(
        'account',
        const TaskListDto(
          id: 'ms-list',
          title: 'Tasks',
          rawJson: {
            'id': 'ms-list',
            'displayName': 'Tasks',
            'wellknownListName': 'defaultList',
            'isOwner': true,
            'isShared': false,
          },
        ),
        _now,
      ),
    );
    await database.tasksDao.upsertTask(
      taskFromDto(
        'account',
        'ms-list',
        const TaskDto(
          id: 'ms-task',
          title: 'Task',
          status: 'completed',
          rawJson: {
            'id': 'ms-task',
            'title': 'Task',
            'status': 'completed',
            'dueDateTime': {
              'dateTime': '2026-06-06T14:30:00',
              'timeZone': 'America/Vancouver',
            },
            'reminderDateTime': {
              'dateTime': '2026-06-06T09:00:00',
              'timeZone': 'America/Vancouver',
            },
            'startDateTime': {
              'dateTime': '2026-06-06T08:00:00',
              'timeZone': 'America/Vancouver',
            },
            'completedDateTime': {
              'dateTime': '2026-06-06T15:45:00',
              'timeZone': 'America/Vancouver',
            },
            'isReminderOn': true,
            'recurrence': {
              'pattern': {'type': 'weekly', 'interval': 1},
              'range': {'type': 'noEnd', 'startDate': '2026-06-06'},
            },
            'importance': 'high',
            'categories': ['Important'],
            'hasAttachments': true,
            'body': {'content': '<p>Notes</p>', 'contentType': 'html'},
          },
        ),
        _now,
      ),
    );

    final list = (await database.taskListsDao.listTaskLists('account')).single;
    final task = (await database.tasksDao.listTasks(
      'account',
      'ms-list',
    )).single;

    expect(list.providerListKind, 'defaultList');
    expect(list.isOwner, isTrue);
    expect(list.isShared, isFalse);
    expect(task.providerStatus, 'completed');
    expect(task.dueUtc, '2026-06-06');
    expect(task.microsoftDueDateTime, '2026-06-06T14:30:00');
    expect(task.microsoftDueTimeZone, 'America/Vancouver');
    expect(task.microsoftStartDateTime, '2026-06-06T08:00:00');
    expect(task.microsoftStartTimeZone, 'America/Vancouver');
    expect(task.microsoftReminderDateTime, '2026-06-06T09:00:00');
    expect(task.microsoftReminderTimeZone, 'America/Vancouver');
    expect(task.microsoftCompletedDateTime, '2026-06-06T15:45:00');
    expect(task.microsoftCompletedTimeZone, 'America/Vancouver');
    expect(task.completedUtc, null);
    expect(task.microsoftIsReminderOn, isTrue);
    expect(task.recurrenceJson, contains('weekly'));
    expect(task.importance, 'high');
    expect(task.categoriesJson, contains('Important'));
    expect(task.hasAttachments, isTrue);
    expect(task.bodyContentType, 'html');
  });

  test(
    'migration to v2 preserves pending ops with null baselineRawJson',
    () async {
      await database.close();

      final tempDir = await Directory.systemTemp.createTemp('busymax-db-test-');
      final file = File('${tempDir.path}/busymax.sqlite');
      final raw = sqlite3.sqlite3.open(file.path);
      try {
        raw.execute('''
        CREATE TABLE accounts (
          id TEXT NOT NULL PRIMARY KEY,
          display_name TEXT NULL,
          auth_state TEXT NOT NULL DEFAULT 'signed_out',
          granted_scopes TEXT NOT NULL DEFAULT '',
          created_at_utc TEXT NOT NULL,
          updated_at_utc TEXT NOT NULL,
          last_successful_sync_at_utc TEXT NULL,
          last_full_sync_at_utc TEXT NULL
        );
      ''');
        raw.execute('''
        CREATE TABLE pending_ops (
          id TEXT NOT NULL PRIMARY KEY,
          account_id TEXT NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
          entity_type TEXT NOT NULL,
          operation TEXT NOT NULL,
          task_list_id TEXT NULL,
          task_id TEXT NULL,
          local_temp_id TEXT NULL,
          depends_on_op_id TEXT NULL,
          request_json TEXT NOT NULL,
          baseline_updated_utc TEXT NULL,
          attempt_count INTEGER NOT NULL DEFAULT 0,
          next_attempt_at_utc TEXT NULL,
          last_error_code TEXT NULL,
          last_error_message TEXT NULL,
          created_at_utc TEXT NOT NULL,
          updated_at_utc TEXT NOT NULL
        );
      ''');
        raw.execute(
          'INSERT INTO accounts (id, created_at_utc, updated_at_utc) '
          "VALUES ('account', '$_now', '$_now')",
        );
        raw.execute(
          'INSERT INTO pending_ops '
          '(id, account_id, entity_type, operation, request_json, '
          'created_at_utc, updated_at_utc) '
          "VALUES ('op-1', 'account', 'task', 'patch_task', '{}', "
          "'$_now', '$_now')",
        );
        raw.execute('PRAGMA user_version = 1');
      } finally {
        raw.close();
      }

      database = AppDatabase(NativeDatabase(file));
      final version = await database
          .customSelect('PRAGMA user_version')
          .getSingle();
      final op = await database.pendingOpsDao.getOp('op-1');

      expect(version.data['user_version'], 4);
      expect(op, isNot(equals(null)));
      expect(op!.baselineRawJson, equals(null));

      await database.close();
      database = AppDatabase(NativeDatabase.memory());
      await tempDir.delete(recursive: true);
    },
  );
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

TaskListsCompanion _taskList({
  required String id,
  String title = 'Inbox',
  String rawJson = '{"id":"list-1"}',
}) {
  return TaskListsCompanion.insert(
    accountId: 'account',
    id: id,
    title: title,
    rawJson: rawJson,
    createdLocalAtUtc: _now,
    updatedLocalAtUtc: _now,
  );
}

TasksCompanion _task({
  required String id,
  required String position,
  String title = 'Task',
}) {
  return TasksCompanion.insert(
    accountId: 'account',
    taskListId: 'list-1',
    id: id,
    title: title,
    rawJson: '{"id":"$id"}',
    position: Value(position),
    createdLocalAtUtc: _now,
    updatedLocalAtUtc: _now,
  );
}

PendingOpsCompanion _pendingOp({
  required String id,
  required String createdAtUtc,
  Value<String?> nextAttemptAtUtc = const Value.absent(),
}) {
  return PendingOpsCompanion.insert(
    id: id,
    accountId: 'account',
    entityType: 'task',
    operation: 'patch_task',
    requestJson: '{}',
    createdAtUtc: createdAtUtc,
    updatedAtUtc: createdAtUtc,
    nextAttemptAtUtc: nextAttemptAtUtc,
  );
}

const _now = '2026-06-04T00:00:00.000Z';

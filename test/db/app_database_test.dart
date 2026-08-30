import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3;
import 'package:busymax/src/features/task_lists/data/task_lists_repository.dart';
import 'package:busymax/src/features/tasks/data/tasks_repository.dart';
import 'package:busymax/src/db/app_database.dart';
import 'package:busymax/src/db/migrations.dart';
import 'package:busymax/src/features/tasks/domain/task_remote_models.dart';

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await database.close();
  });

  test('opens schema version 13 and creates required indexes', () async {
    final version = await database
        .customSelect('PRAGMA user_version')
        .getSingle();
    final indexes = await database
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type = 'index' "
          "AND name LIKE 'idx_%' ORDER BY name",
        )
        .get();

    final taskColumns = await database
        .customSelect('PRAGMA table_info(tasks)')
        .get();
    final calendarSourceColumns = await database
        .customSelect('PRAGMA table_info(calendar_sources)')
        .get();
    final taskListColumns = await database
        .customSelect('PRAGMA table_info(task_lists)')
        .get();
    final webCalColumns = await database
        .customSelect('PRAGMA table_info(web_cal_subscriptions)')
        .get();

    expect(version.data['user_version'], 13);
    expect(
      taskColumns.map((row) => row.read<String>('name')),
      contains('microsoft_checklist_items_json'),
    );
    expect(
      calendarSourceColumns.map((row) => row.read<String>('name')),
      contains('reminders_enabled'),
    );
    expect(
      taskListColumns.map((row) => row.read<String>('name')),
      contains('reminders_enabled'),
    );
    expect(
      webCalColumns.map((row) => row.read<String>('name')),
      containsAll(['projection_range_start_utc', 'projection_range_end_utc']),
    );
    expect(indexes.map((row) => row.data['name']).toSet(), {
      'idx_accounts_provider',
      'idx_accounts_remote_identity',
      'idx_dav_collections_href',
      'idx_dav_collections_sync',
      'idx_dav_objects_href',
      'idx_dav_objects_projection',
      'idx_dav_components_logical_key',
      'idx_dav_components_uid',
      'idx_task_lists_account_title',
      'idx_task_lists_dirty',
      'idx_task_lists_dav_collection',
      'idx_tasks_dirty',
      'idx_tasks_list_order',
      'idx_tasks_status_due',
      'idx_tasks_updated',
      'idx_tasks_dav_component',
      'idx_calendar_events_dirty',
      'idx_calendar_events_provider_id',
      'idx_calendar_events_range',
      'idx_calendar_events_dav_occurrence',
      'idx_calendar_sources_provider_id',
      'idx_calendar_sources_visible',
      'idx_calendar_sources_dav_collection',
      'idx_sync_cursors_scope',
      'idx_pending_ops_dav_replay',
      'idx_notification_schedule_due',
      'idx_webcal_subscriptions_due',
    });
  });

  test('schema 10 migration preserves accounts and enables WebCal', () async {
    await database.close();
    final tempDir = await Directory.systemTemp.createTemp(
      'busymax-db-v10-test-',
    );
    final file = File('${tempDir.path}/busymax.sqlite');
    final schemaTenDatabase = AppDatabase(NativeDatabase(file));
    await _insertAccount(schemaTenDatabase);
    await schemaTenDatabase.close();

    final raw = sqlite3.sqlite3.open(file.path);
    try {
      raw.execute('DROP TABLE ical_import_receipts');
      raw.execute('DROP TABLE web_cal_subscriptions');
      raw.execute('PRAGMA user_version = 10');
    } finally {
      raw.close();
    }

    database = AppDatabase(NativeDatabase(file));
    final existing = await (database.select(
      database.accounts,
    )..where((row) => row.id.equals('account'))).getSingle();
    expect(existing.provider, 'google');
    expect(
      (await database.customSelect('PRAGMA user_version').getSingle())
          .read<int>('user_version'),
      13,
    );

    await database
        .into(database.accounts)
        .insert(
          AccountsCompanion.insert(
            id: 'webcal-account-subscription',
            provider: 'webcal',
            authority: 'https://calendar.example.test',
            providerAccountId: 'fingerprint',
            credentialKind: 'webcal_subscription',
            authState: const Value('signed_in'),
            calendarsEnabled: const Value(true),
            tasksEnabled: const Value(false),
            grantedScopes: const Value(''),
            createdAtUtc: _now,
            updatedAtUtc: _now,
          ),
        );
    expect(
      await database.customSelect('PRAGMA foreign_key_check').get(),
      isEmpty,
    );

    await database.close();
    database = AppDatabase(NativeDatabase.memory());
    await tempDir.delete(recursive: true);
  });

  test(
    'schema 11 migration enables task-list reminders without data loss',
    () async {
      await database.close();
      final tempDir = await Directory.systemTemp.createTemp(
        'busymax-db-v11-test-',
      );
      final file = File('${tempDir.path}/busymax.sqlite');
      final schemaElevenDatabase = AppDatabase(NativeDatabase(file));
      await _insertAccount(schemaElevenDatabase);
      await schemaElevenDatabase.taskListsDao.upsertTaskList(
        _taskList(id: 'list-1', title: 'Existing list'),
      );
      await schemaElevenDatabase.close();

      final raw = sqlite3.sqlite3.open(file.path);
      try {
        raw.execute('ALTER TABLE task_lists DROP COLUMN reminders_enabled');
        raw.execute('PRAGMA user_version = 11');
      } finally {
        raw.close();
      }

      database = AppDatabase(NativeDatabase(file));
      final version = await database
          .customSelect('PRAGMA user_version')
          .getSingle();
      final list = await (database.select(
        database.taskLists,
      )..where((row) => row.id.equals('list-1'))).getSingle();

      expect(version.read<int>('user_version'), 13);
      expect(list.title, 'Existing list');
      expect(list.remindersEnabled, isTrue);
      expect(
        await database.customSelect('PRAGMA foreign_key_check').get(),
        isEmpty,
      );

      await database.close();
      database = AppDatabase(NativeDatabase.memory());
      await tempDir.delete(recursive: true);
    },
  );

  test(
    'schema 12 migration adds WebCal coverage and account pair constraints',
    () async {
      await database.close();
      final tempDir = await Directory.systemTemp.createTemp(
        'busymax-db-v12-test-',
      );
      final file = File('${tempDir.path}/busymax.sqlite');
      final schemaTwelveDatabase = AppDatabase(NativeDatabase(file));
      await _insertAccount(schemaTwelveDatabase);
      await schemaTwelveDatabase.close();

      final raw = sqlite3.sqlite3.open(file.path);
      try {
        raw.execute(
          'ALTER TABLE web_cal_subscriptions '
          'DROP COLUMN projection_range_start_utc',
        );
        raw.execute(
          'ALTER TABLE web_cal_subscriptions '
          'DROP COLUMN projection_range_end_utc',
        );
        _removeProviderCredentialPairConstraint(raw);
        raw.execute('PRAGMA user_version = 12');
      } finally {
        raw.close();
      }

      database = AppDatabase(NativeDatabase(file));
      final columns = await database
          .customSelect('PRAGMA table_info(web_cal_subscriptions)')
          .get();
      expect(
        (await database.customSelect('PRAGMA user_version').getSingle())
            .read<int>('user_version'),
        13,
      );
      expect(
        columns.map((row) => row.read<String>('name')),
        containsAll(['projection_range_start_utc', 'projection_range_end_utc']),
      );
      await expectLater(
        database
            .into(database.accounts)
            .insert(
              AccountsCompanion.insert(
                id: 'invalid-pair',
                provider: 'google',
                authority: 'https://accounts.google.com',
                providerAccountId: 'invalid',
                credentialKind: 'webcal_subscription',
                createdAtUtc: _now,
                updatedAtUtc: _now,
              ),
            ),
        throwsA(anything),
      );
      expect(
        await database.customSelect('PRAGMA foreign_key_check').get(),
        isEmpty,
      );

      await database.close();
      database = AppDatabase(NativeDatabase.memory());
      await tempDir.delete(recursive: true);
    },
  );

  test(
    'schema 12 migration rejects a corrupt provider credential pair',
    () async {
      await database.close();
      final tempDir = await Directory.systemTemp.createTemp(
        'busymax-db-v12-corrupt-test-',
      );
      final file = File('${tempDir.path}/busymax.sqlite');
      final schemaTwelveDatabase = AppDatabase(NativeDatabase(file));
      await _insertAccount(schemaTwelveDatabase);
      await schemaTwelveDatabase.close();

      final raw = sqlite3.sqlite3.open(file.path);
      try {
        raw.execute('PRAGMA ignore_check_constraints = ON');
        raw.execute(
          "UPDATE accounts SET credential_kind = 'webcal_subscription' "
          "WHERE id = 'account'",
        );
        raw.execute('PRAGMA user_version = 12');
      } finally {
        raw.close();
      }

      database = AppDatabase(NativeDatabase(file));
      await expectLater(
        database.customSelect('SELECT 1').get(),
        throwsA(
          isA<BusyMaxMigrationException>().having(
            (error) => error.code,
            'code',
            'account_identity_invariant_failed',
          ),
        ),
      );

      await database.close();
      database = AppDatabase(NativeDatabase.memory());
      await tempDir.delete(recursive: true);
    },
  );

  test(
    'schema 9 migration adds calendar ownership columns without data loss',
    () async {
      await database.close();
      final tempDir = await Directory.systemTemp.createTemp(
        'busymax-db-v9-test-',
      );
      final file = File('${tempDir.path}/busymax.sqlite');
      final schemaNineDatabase = AppDatabase(NativeDatabase(file));
      await _insertAccount(schemaNineDatabase);
      await schemaNineDatabase
          .into(schemaNineDatabase.calendarSources)
          .insert(
            CalendarSourcesCompanion.insert(
              id: 'calendar',
              accountId: 'account',
              provider: 'google',
              providerCalendarId: 'shared@example.com',
              summary: 'Shared calendar',
              createdAtLocal: 1,
              updatedAtLocal: 1,
            ),
          );
      await schemaNineDatabase.close();

      final raw = sqlite3.sqlite3.open(file.path);
      try {
        raw.execute('ALTER TABLE calendar_sources DROP COLUMN data_owner');
        raw.execute('ALTER TABLE calendar_sources DROP COLUMN is_removable');
        raw.execute('PRAGMA user_version = 9');
      } finally {
        raw.close();
      }

      database = AppDatabase(NativeDatabase(file));
      final version = await database
          .customSelect('PRAGMA user_version')
          .getSingle();
      final columns = await database
          .customSelect('PRAGMA table_info(calendar_sources)')
          .get();
      final source = await (database.select(
        database.calendarSources,
      )..where((row) => row.id.equals('calendar'))).getSingle();

      expect(version.read<int>('user_version'), 13);
      expect(
        columns.map((row) => row.read<String>('name')),
        containsAll(['data_owner', 'is_removable']),
      );
      expect(source.summary, 'Shared calendar');
      expect(source.dataOwner, equals(null));
      expect(source.isRemovable, equals(null));
      expect(
        await database.customSelect('PRAGMA foreign_key_check').get(),
        isEmpty,
      );

      await database.close();
      database = AppDatabase(NativeDatabase.memory());
      await tempDir.delete(recursive: true);
    },
  );

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
    'production-like schema 5 fixture migrates both providers without loss',
    () async {
      await database.close();
      final fixture = await _openSchema5Fixture();
      database = fixture.database;

      final version = await database
          .customSelect('PRAGMA user_version')
          .getSingle();
      expect(version.read<int>('user_version'), 13);

      final accounts = await database.select(database.accounts).get();
      expect(accounts, hasLength(2));
      expect(
        accounts
            .map(
              (account) => (
                account.provider,
                account.authority,
                account.providerAccountId,
                account.credentialKind,
              ),
            )
            .toSet(),
        {
          ('google', 'https://accounts.google.com', 'g-sub', 'oauth'),
          (
            'microsoft',
            'https://login.microsoftonline.com/tenant-a',
            'm-sub',
            'oauth',
          ),
        },
      );

      final tasks = await database.select(database.tasks).get();
      expect(tasks, hasLength(3));
      expect(tasks.every((task) => task.taskLocation == null), isTrue);
      expect(tasks.every((task) => task.taskUrl == null), isTrue);
      expect(tasks.every((task) => task.taskClassification == null), isTrue);
      expect(tasks.every((task) => task.taskPinned == null), isTrue);
      expect(tasks.every((task) => task.taskAlarmsJson == null), isTrue);
      expect(
        tasks.singleWhere((task) => task.id == 'g-child').parent,
        'g-parent',
      );
      expect(
        tasks.singleWhere((task) => task.id == 'm-recurring').recurrenceJson,
        contains('weekly'),
      );
      expect(await database.select(database.taskLists).get(), hasLength(2));

      final pendingOps = await database.select(database.pendingOps).get();
      expect(pendingOps.map((op) => op.operationType).toSet(), {
        'create',
        'update',
        'delete',
      });
      expect(
        pendingOps.singleWhere((op) => op.id == 'op-update').baselineRawJson,
        contains('Recurring task'),
      );

      final events = await database.select(database.calendarEvents).get();
      expect(events, hasLength(2));
      expect(
        events.singleWhere((event) => event.id == 'g-event').recurrenceJson,
        contains('RRULE:FREQ=WEEKLY'),
      );
      final calendarSources = await database
          .select(database.calendarSources)
          .get();
      expect(calendarSources, hasLength(2));
      expect(
        calendarSources.every((source) => source.remindersEnabled),
        isTrue,
      );

      final cursors = await database.select(database.syncCursors).get();
      expect(cursors, hasLength(2));
      expect(
        cursors
            .map((cursor) => (cursor.cursorKind, cursor.cursorValue))
            .toSet(),
        {
          ('google_sync_token', 'g-token'),
          ('microsoft_delta_link', 'https://graph.example/delta-2'),
        },
      );
      expect(
        await database
            .customSelect(
              "SELECT name FROM sqlite_master WHERE name = 'calendar_sync_states'",
            )
            .getSingleOrNull(),
        equals(null),
      );

      expect(await database.select(database.davCollections).get(), isEmpty);
      expect(await database.select(database.davObjects).get(), isEmpty);
      expect(
        await database.customSelect('PRAGMA foreign_key_check').get(),
        isEmpty,
      );
      final accountColumns = await database
          .customSelect('PRAGMA table_info(accounts)')
          .get();
      final providerColumn = accountColumns.singleWhere(
        (row) => row.read<String>('name') == 'provider',
      );
      expect(providerColumn.data['dflt_value'], equals(null));
      expect(providerColumn.read<int>('notnull'), 1);

      await database.close();
      database = AppDatabase(NativeDatabase.memory());
      await fixture.directory.delete(recursive: true);
    },
  );

  test('schema 5 migration rejects an unsupported provider value', () async {
    await database.close();
    final fixture = await _openSchema5Fixture(
      prepare: (raw) {
        raw.execute(
          "UPDATE accounts SET provider = 'unsupported' "
          "WHERE id = 'google:g-sub'",
        );
      },
    );
    database = fixture.database;

    await expectLater(
      database.customSelect('PRAGMA user_version').getSingle(),
      throwsA(
        isA<BusyMaxMigrationException>().having(
          (error) => error.code,
          'code',
          'unsupported_provider_value',
        ),
      ),
    );

    await database.close();
    database = AppDatabase(NativeDatabase.memory());
    await fixture.directory.delete(recursive: true);
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

      expect(version.data['user_version'], 13);
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
          provider: 'google',
          authority: 'https://accounts.google.com',
          providerAccountId: 'google-account',
          credentialKind: 'oauth',
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

void _removeProviderCredentialPairConstraint(sqlite3.Database database) {
  final sql =
      database
              .select(
                "SELECT sql FROM sqlite_schema WHERE type = 'table' AND name = 'accounts'",
              )
              .single['sql']
          as String;
  const marker =
      "CHECK ((provider IN ('google', 'microsoft') AND credential_kind = 'oauth')";
  final start = sql.indexOf(marker);
  if (start < 0) {
    throw StateError('Provider credential constraint fixture not found.');
  }

  var quoted = false;
  var depth = 0;
  var opened = false;
  int? end;
  for (var index = start; index < sql.length; index += 1) {
    final character = sql[index];
    if (character == "'") {
      if (quoted && index + 1 < sql.length && sql[index + 1] == "'") {
        index += 1;
      } else {
        quoted = !quoted;
      }
      continue;
    }
    if (quoted) continue;
    if (character == '(') {
      opened = true;
      depth += 1;
    } else if (character == ')') {
      depth -= 1;
      if (opened && depth == 0) {
        end = index + 1;
        break;
      }
    }
  }
  if (end == null) {
    throw StateError('Provider credential constraint fixture is malformed.');
  }

  var removalStart = start;
  while (removalStart > 0 &&
      (sql[removalStart - 1] == ' ' || sql[removalStart - 1] == '\n')) {
    removalStart -= 1;
  }
  if (removalStart > 0 && sql[removalStart - 1] == ',') {
    removalStart -= 1;
  }
  final legacySql = sql.replaceRange(removalStart, end, '');
  database.execute('PRAGMA writable_schema = ON');
  try {
    database.execute(
      "UPDATE sqlite_schema SET sql = ? WHERE type = 'table' AND name = 'accounts'",
      [legacySql],
    );
  } finally {
    database.execute('PRAGMA writable_schema = OFF');
  }
  final schemaVersion =
      database.select('PRAGMA schema_version').single.values.first as int;
  database.execute('PRAGMA schema_version = ${schemaVersion + 1}');
}

Future<({AppDatabase database, Directory directory})> _openSchema5Fixture({
  void Function(sqlite3.Database raw)? prepare,
}) async {
  final directory = await Directory.systemTemp.createTemp(
    'busymax-schema5-fixture-',
  );
  final file = File('${directory.path}/busymax.sqlite');
  final raw = sqlite3.sqlite3.open(file.path);
  try {
    raw.execute(
      File('test/fixtures/schema_v5_production_like.sql').readAsStringSync(),
    );
    prepare?.call(raw);
  } finally {
    raw.close();
  }
  return (database: AppDatabase(NativeDatabase(file)), directory: directory);
}

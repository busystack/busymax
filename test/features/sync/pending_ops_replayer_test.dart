import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:busymax/src/features/notifications/notification_schedule_service.dart';
import 'package:busymax/src/features/notifications/notification_scheduler.dart';
import 'package:busymax/src/features/notifications/desktop_notification_service.dart';
import 'package:busymax/src/core/http/request_dispatch_exception.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:busymax/src/db/app_database.dart';
import 'package:busymax/src/features/sync/pending_ops_replayer.dart';
import 'package:busymax/src/features/sync/sync_engine.dart';
import 'package:busymax/src/features/task_lists/data/task_lists_repository.dart';
import 'package:busymax/src/app/app_settings.dart';
import 'package:busymax/src/schedule/schedule_sidebar_order.dart';
import 'package:busymax/src/features/tasks/data/tasks_repository.dart';
import 'package:busymax/src/features/tasks/domain/task_remote_client.dart';
import 'package:busymax/src/google_tasks/api/google_tasks_api_error.dart';
import 'package:busymax/src/features/tasks/domain/task_remote_models.dart';
import 'package:busymax/src/features/tasks/domain/task_checklist_item.dart';
import 'package:busymax/src/microsoft_todo/api/microsoft_todo_api_client.dart';
import 'package:busymax/src/microsoft_todo/api/microsoft_todo_api_error.dart';
import 'package:busymax/src/microsoft_todo/api/microsoft_todo_api_models.dart';
import 'package:busymax/src/microsoft_todo/api/microsoft_todo_task_remote_client.dart';

import '../../support/recording_notification_backend.dart';
import '../../support/memory_settings_store.dart';

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

  for (final lifecycle in ['snoozed', 'sent', 'dismissed']) {
    test(
      'actual create replay preserves $lifecycle reminder identity',
      () async {
        await database
            .update(database.accounts)
            .write(
              const AccountsCompanion(
                provider: Value('microsoft'),
                authState: Value('signed_in'),
              ),
            );
        var now = DateTime.utc(2026, 6, 8, 8, 59);
        final reminder = DateTime.utc(2026, 6, 8, 9);
        final repository = TasksRepository(
          database: database,
          accountId: 'account',
          nowUtc: () => now,
        );
        await repository.createTask(
          'list-1',
          TaskCreateInput(
            title: 'Offline reminder',
            fields: {
              'microsoftIsReminderOn': true,
              'microsoftReminderDateTime': reminder.toIso8601String(),
              'microsoftReminderTimeZone': 'UTC',
            },
          ),
        );
        final original = await database
            .select(database.notificationSchedule)
            .getSingle();
        apiClient.createdTask = TaskDto(
          id: 'task-server',
          title: 'Offline reminder',
          status: 'needsAction',
          rawJson: {
            'isReminderOn': true,
            'reminderDateTime': {
              'dateTime': reminder.toIso8601String(),
              'timeZone': 'UTC',
            },
          },
        );
        final backend = RecordingNotificationBackend();
        NotificationScheduleData? opened;
        final scheduler = NotificationScheduler(
          database: database,
          notifications: DesktopNotificationService(
            backend: backend,
            settings: AppSettings.defaults(),
          ),
          nowUtc: () => now,
          onNotificationActivated: (row) async => opened = row,
        );
        addTearDown(scheduler.stop);
        now = reminder;
        await scheduler.checkNow();
        expect(backend.requests, hasLength(1));
        if (lifecycle != 'sent') {
          await backend.invoke(
            0,
            lifecycle == 'snoozed' ? 'snooze' : 'dismiss',
          );
        }
        final before = await database
            .select(database.notificationSchedule)
            .getSingle();
        now = reminder.add(const Duration(minutes: 2));
        expect(
          await PendingOpsReplayer(
            database: database,
            apiClient: apiClient,
            accountId: 'account',
            nowUtc: () => now,
          ).replayDueOps(),
          1,
        );
        final replaced = await database
            .select(database.notificationSchedule)
            .getSingle();
        expect(replaced.id, original.id);
        expect(replaced.sourceId, 'task-server');
        expect(replaced.generation, before.generation);
        expect(replaced.snoozedUntilUtc, before.snoozedUntilUtc);
        expect(replaced.sentAtUtc, before.sentAtUtc);
        expect(replaced.dismissedAtUtc, before.dismissedAtUtc);
        expect(
          (await database.tasksDao.listTasks('account', 'list-1')).single.id,
          'task-server',
        );
        final schedules = NotificationScheduleService(
          database: database,
          nowUtc: () => now,
        );
        await schedules.rebuildUpcomingTaskNotifications('account');
        await scheduler.checkNow();
        expect(backend.requests, hasLength(1));
        if (lifecycle == 'sent') {
          await backend.invoke(0, 'default');
          expect(opened?.sourceId, 'task-server');
          expect(backend.cancelledIds, isEmpty);
        }
        now = reminder.add(const Duration(minutes: 10));
        await schedules.rebuildUpcomingTaskNotifications('account');
        await scheduler.checkNow();
        await scheduler.checkNow();
        expect(backend.requests, hasLength(lifecycle == 'snoozed' ? 2 : 1));
        if (lifecycle == 'snoozed') {
          expect(backend.requests.last.payload!['itemId'], 'task-server');
          expect(
            (await database.select(database.notificationSchedule).getSingle())
                .sentAtUtc,
            now.millisecondsSinceEpoch,
          );
        }
      },
    );
  }

  for (final throughEngine in [false, true]) {
    for (final failSettings in [false, true]) {
      test(
        'task list ID callback follows commit (engine=$throughEngine, failure=$failSettings)',
        () async {
          final settings = AppSettingsController(MemorySettingsStore());
          addTearDown(settings.dispose);
          await settings.registerSidebarIds(SidebarOrderSection.taskLists, [
            'before',
            'temp-list',
            'after',
            'list-server',
          ], accountId: 'account');
          await database.taskListsDao.upsertTaskList(
            _taskList('temp-list', title: 'Temp'),
          );
          await _enqueue(
            database,
            id: 'create-list',
            operation: 'create_task_list',
            entityType: 'task_list',
            taskListId: 'temp-list',
            localTempId: 'temp-list',
            request: {'title': 'Temp'},
          );
          var callbackCount = 0;
          var committed = false;
          Future<void> replaced(String oldId, String newId) async {
            callbackCount++;
            final ids = (await database.taskListsDao.listTaskLists(
              'account',
            )).map((list) => list.id);
            committed =
                oldId == 'temp-list' &&
                newId == 'list-server' &&
                !ids.contains(oldId) &&
                ids.contains(newId);
            await settings.replaceSidebarId(
              SidebarOrderSection.taskLists,
              oldId,
              newId,
              accountId: 'account',
            );
            if (failSettings) throw StateError('settings unavailable');
          }

          final replayer = PendingOpsReplayer(
            database: database,
            apiClient: apiClient,
            accountId: 'account',
            onTaskListIdReplaced: replaced,
            nowUtc: () => DateTime.utc(2026, 6, 4),
          );
          if (throughEngine) {
            await SyncEngine(
              database: database,
              apiClient: apiClient,
              accountId: 'account',
              onTaskListIdReplaced: replaced,
              nowUtc: () => DateTime.utc(2026, 6, 4),
            ).fullSync();
          } else {
            expect(await replayer.replayDueOps(), 1);
          }
          expect(committed, isTrue);
          expect(callbackCount, 1);
          expect(settings.state.sidebarOrder.taskListIdsByAccount['account'], [
            'before',
            'list-server',
            'after',
          ]);
          expect(await replayer.replayDueOps(), 0);
          expect(
            apiClient.calls.where(
              (call) => call.startsWith('create_task_list:'),
            ),
            ['create_task_list:Temp'],
          );
        },
      );
    }
  }

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

  test('task edit waits while a rate-limited creation is retrying', () async {
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
      statusCode: 429,
      message: 'Rate limited',
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

  test('task creation acknowledgment preserves a newer queued edit', () async {
    final repository = TasksRepository(
      database: database,
      accountId: 'account',
      nowUtc: () => DateTime.utc(2026, 6, 4),
    );
    await repository.createTask(
      'list-1',
      const TaskCreateInput(title: 'Draft'),
    );
    final temporary = (await database.tasksDao.listTasks(
      'account',
      'list-1',
    )).single;
    await repository.patchTask(
      'list-1',
      temporary.id,
      const TaskPatchInput({'title': 'Revised'}),
    );
    apiClient.patchTaskError = const GoogleTasksApiError(
      statusCode: 503,
      message: 'Temporary failure',
    );

    expect(
      await PendingOpsReplayer(
        database: database,
        apiClient: apiClient,
        accountId: 'account',
        random: Random(0),
        nowUtc: () => DateTime.utc(2026, 6, 4, 1),
      ).replayDueOps(),
      1,
    );

    final visible = (await database.tasksDao.listTasks(
      'account',
      'list-1',
    )).single;
    expect(visible.id, 'task-server');
    expect(visible.title, 'Revised');
    expect(visible.localDirty, isTrue);
    expect(
      (await database.select(database.pendingOps).get()).single.operation,
      'patch_task',
    );
  });

  test(
    'remote edit after creation conflicts with a delayed dependent patch',
    () async {
      final createdUpdated = DateTime.utc(2026, 6, 4, 0, 5);
      final createdTask = _taskDto(
        'task-server',
        title: 'Draft',
        updated: createdUpdated,
      );
      apiClient
        ..createdTask = createdTask
        ..remoteTask = createdTask
        ..patchTaskError = const GoogleTasksApiError(
          statusCode: 503,
          message: 'Temporary failure',
        );
      final repository = TasksRepository(
        database: database,
        accountId: 'account',
        nowUtc: () => DateTime.utc(2026, 6, 4),
      );
      await repository.createTask(
        'list-1',
        const TaskCreateInput(title: 'Draft'),
      );
      final temporary = (await database.tasksDao.listTasks(
        'account',
        'list-1',
      )).single;
      await repository.patchTask(
        'list-1',
        temporary.id,
        const TaskPatchInput({'title': 'Local title'}),
      );

      expect(
        await PendingOpsReplayer(
          database: database,
          apiClient: apiClient,
          accountId: 'account',
          random: Random(0),
          nowUtc: () => DateTime.utc(2026, 6, 4, 1),
        ).replayDueOps(),
        1,
      );

      var pending = await database.select(database.pendingOps).getSingle();
      expect(pending.operation, 'patch_task');
      expect(pending.state, 'pending');
      expect(pending.attemptCount, 1);
      expect(pending.nextAttemptAtUtc, isNot(equals(null)));
      expect(pending.lastErrorCode, '503');
      expect(pending.baselineUpdatedUtc, createdUpdated.toIso8601String());
      expect(jsonDecode(pending.baselineRawJson!)['title'], 'Draft');

      apiClient
        ..patchTaskError = null
        ..remoteTask = _taskDto(
          'task-server',
          title: 'Competing remote title',
          updated: DateTime.utc(2026, 6, 4, 0, 10),
        );

      expect(
        await PendingOpsReplayer(
          database: database,
          apiClient: apiClient,
          accountId: 'account',
          random: Random(0),
          nowUtc: () => DateTime.utc(2026, 6, 5),
        ).replayDueOps(),
        0,
      );

      pending = await database.select(database.pendingOps).getSingle();
      expect(pending.lastErrorCode, 'conflict');
      expect(pending.lastErrorMessage, contains('title'));
      expect(apiClient.taskPatchFields, isEmpty);
      expect(apiClient.remoteTask!.title, 'Competing remote title');
    },
  );

  for (final entity in ['task', 'task list']) {
    test(
      '$entity creation restart after identity persistence stays acknowledged',
      () async {
        final directory = await Directory.systemTemp.createTemp(
          'busymax-$entity-create-ack-',
        );
        final databaseFile = File('${directory.path}/busymax.sqlite');
        final previousDatabaseWarningSetting =
            driftRuntimeOptions.dontWarnAboutMultipleDatabases;
        driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
        final commitInterruption = _CommitInterruption();
        final interruptedDatabase = AppDatabase(
          NativeDatabase(databaseFile).interceptWith(commitInterruption),
        );
        AppDatabase? restartedDatabase;
        Future<int>? interruptedReplay;
        addTearDown(() async {
          commitInterruption.resume();
          await interruptedReplay;
          await restartedDatabase?.close();
          await interruptedDatabase.close();
          await directory.delete(recursive: true);
          driftRuntimeOptions.dontWarnAboutMultipleDatabases =
              previousDatabaseWarningSetting;
        });

        await _insertAccount(interruptedDatabase);
        await interruptedDatabase.taskListsDao.upsertTaskList(
          _taskList('list-1'),
        );
        if (entity == 'task') {
          await interruptedDatabase.tasksDao.upsertTask(
            _task('list-1', 'local-task-1', title: 'Draft'),
          );
          await _enqueue(
            interruptedDatabase,
            id: 'create',
            operation: 'create_task',
            taskListId: 'list-1',
            taskId: 'local-task-1',
            localTempId: 'local-task-1',
            request: {
              'body': {'title': 'Draft'},
            },
          );
        } else {
          await interruptedDatabase.taskListsDao.upsertTaskList(
            _taskList('local-list', title: 'Draft list'),
          );
          await _enqueue(
            interruptedDatabase,
            id: 'create',
            operation: 'create_task_list',
            entityType: 'task_list',
            taskListId: 'local-list',
            localTempId: 'local-list',
            request: {'title': 'Draft list'},
          );
        }

        final interruptedClient = _FakeTaskRemoteClient();
        commitInterruption.arm();
        interruptedReplay = PendingOpsReplayer(
          database: interruptedDatabase,
          apiClient: interruptedClient,
          accountId: 'account',
          nowUtc: () => DateTime.utc(2026, 6, 4),
        ).replayDueOps();
        await commitInterruption.commitReached.future;

        restartedDatabase = AppDatabase(NativeDatabase(databaseFile));
        final restartedClient = _FakeTaskRemoteClient();
        expect(
          await PendingOpsReplayer(
            database: restartedDatabase,
            apiClient: restartedClient,
            accountId: 'account',
            nowUtc: () => DateTime.utc(2026, 6, 4, 1),
          ).replayDueOps(),
          0,
        );

        expect(
          await restartedDatabase.pendingOpsDao.getOp('create'),
          equals(null),
        );
        expect(restartedClient.calls, isEmpty);
        if (entity == 'task') {
          final tasks = await restartedDatabase.tasksDao.listTasks(
            'account',
            'list-1',
          );
          expect(tasks.map((task) => task.id), ['task-server']);
          expect(interruptedClient.calls, ['create_task:list-1']);
        } else {
          final lists = await restartedDatabase.taskListsDao.listTaskLists(
            'account',
          );
          expect(lists.map((list) => list.id), contains('list-server'));
          expect(lists.map((list) => list.id), isNot(contains('local-list')));
          expect(interruptedClient.calls, ['create_task_list:Draft list']);
        }

        commitInterruption.resume();
        expect(await interruptedReplay, 1);
      },
    );
  }

  test('unknown task creation outcome is not submitted again', () async {
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
    apiClient.createTaskError = StateError('response was lost');

    final replayer = PendingOpsReplayer(
      database: database,
      apiClient: apiClient,
      accountId: 'account',
      random: Random(0),
      nowUtc: () => DateTime.utc(2026, 6, 4),
    );

    expect(await replayer.replayDueOps(), 0);
    final pending = await database.pendingOpsDao.getOp('01');
    expect(pending!.state, 'recovery_required');
    expect(pending.lastErrorCode, 'creation_outcome_unknown');
    expect(pending.nextAttemptAtUtc, startsWith('9999-12-31'));

    await database.pendingOpsDao.retryNow('01', DateTime.utc(2026, 6, 4));
    expect(await replayer.replayDueOps(), 0);
    final stillPending = await database.pendingOpsDao.getOp('01');
    expect(stillPending!.state, 'recovery_required');
    expect(stillPending.nextAttemptAtUtc, startsWith('9999-12-31'));
    expect(apiClient.calls, ['create_task:list-1']);
  });

  test('abandoned in-progress task creation is not submitted again', () async {
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
    await (database.update(database.pendingOps)
          ..where((row) => row.id.equals('01')))
        .write(const PendingOpsCompanion(state: Value('in_progress')));

    expect(
      await PendingOpsReplayer(
        database: database,
        apiClient: apiClient,
        accountId: 'account',
        nowUtc: () => DateTime.utc(2026, 6, 4),
      ).replayDueOps(),
      0,
    );

    final pending = await database.pendingOpsDao.getOp('01');
    expect(pending!.state, 'recovery_required');
    expect(pending.lastErrorCode, 'creation_outcome_unknown');
    expect(apiClient.calls, isEmpty);
  });

  test('unknown task-list creation outcome is not submitted again', () async {
    await database.taskListsDao.upsertTaskList(
      _taskList('local-list', title: 'Draft list'),
    );
    await _enqueue(
      database,
      id: '01',
      operation: 'create_task_list',
      entityType: 'task_list',
      taskListId: 'local-list',
      localTempId: 'local-list',
      request: {'title': 'Draft list'},
    );
    apiClient.createTaskListError = StateError('response was lost');

    final replayer = PendingOpsReplayer(
      database: database,
      apiClient: apiClient,
      accountId: 'account',
      nowUtc: () => DateTime.utc(2026, 6, 4),
    );
    expect(await replayer.replayDueOps(), 0);
    expect(await replayer.replayDueOps(), 0);

    final pending = await database.pendingOpsDao.getOp('01');
    expect(pending!.state, 'recovery_required');
    expect(apiClient.calls, ['create_task_list:Draft list']);
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
    'cross-list move orders an equal-timestamp edit and preserves projection',
    () async {
      await database.taskListsDao.upsertTaskList(_taskList('list-2'));
      await database.tasksDao.upsertTask(
        _task('list-1', 'task-1', title: 'Original'),
      );
      final repository = TasksRepository(
        database: database,
        accountId: 'account',
        nowUtc: () => DateTime.utc(2026, 6, 4),
      );
      await repository.moveTask(
        const TaskMoveInput(
          sourceTaskListId: 'list-1',
          taskId: 'task-1',
          destinationTaskListId: 'list-2',
        ),
      );
      await repository.patchTask(
        'list-2',
        'task-1',
        const TaskPatchInput({'title': 'Edited after move'}),
      );
      final queued = await database.select(database.pendingOps).get();
      final move = queued.singleWhere((op) => op.operation == 'move_task');
      final edit = queued.singleWhere((op) => op.operation == 'patch_task');
      expect(edit.dependsOnOpId, move.id);

      apiClient.moveTaskError = const GoogleTasksApiError(
        statusCode: 429,
        message: 'Rate limited',
      );
      expect(
        await PendingOpsReplayer(
          database: database,
          apiClient: apiClient,
          accountId: 'account',
          random: Random(0),
          nowUtc: () => DateTime.utc(2026, 6, 4, 1),
        ).replayDueOps(),
        0,
      );
      expect(apiClient.calls, ['move_task:task-1']);
      expect(
        (await database.tasksDao.listTasks('account', 'list-2')).single.title,
        'Edited after move',
      );

      apiClient.moveTaskError = null;
      expect(
        await PendingOpsReplayer(
          database: database,
          apiClient: apiClient,
          accountId: 'account',
          random: Random(0),
          nowUtc: () => DateTime.utc(2026, 6, 4, 2),
        ).replayDueOps(),
        2,
      );
      expect(apiClient.calls, [
        'move_task:task-1',
        'move_task:task-1',
        'patch_task:task-1',
      ]);
      expect(await database.tasksDao.listTasks('account', 'list-1'), isEmpty);
      final finalTask = (await database.tasksDao.listTasks(
        'account',
        'list-2',
      )).single;
      expect(finalTask.title, 'Edited after move');
      expect(finalTask.localDirty, isFalse);
    },
  );

  test(
    'three cross-list moves form one dependency chain before an edit',
    () async {
      await database.taskListsDao.upsertTaskList(_taskList('list-2'));
      await database.taskListsDao.upsertTaskList(_taskList('list-3'));
      await database.tasksDao.upsertTask(_task('list-1', 'task-1'));
      final repository = TasksRepository(
        database: database,
        accountId: 'account',
        nowUtc: () => DateTime.utc(2026, 6, 4),
      );
      await repository.moveTask(
        const TaskMoveInput(
          sourceTaskListId: 'list-1',
          taskId: 'task-1',
          destinationTaskListId: 'list-2',
        ),
      );
      await repository.moveTask(
        const TaskMoveInput(
          sourceTaskListId: 'list-2',
          taskId: 'task-1',
          destinationTaskListId: 'list-3',
        ),
      );
      await repository.patchTask(
        'list-3',
        'task-1',
        const TaskPatchInput({'title': 'Final title'}),
      );

      expect(
        await PendingOpsReplayer(
          database: database,
          apiClient: apiClient,
          accountId: 'account',
          nowUtc: () => DateTime.utc(2026, 6, 4, 1),
        ).replayDueOps(),
        3,
      );
      expect(apiClient.calls, [
        'move_task:task-1',
        'move_task:task-1',
        'patch_task:task-1',
      ]);
      expect(
        (await database.tasksDao.listTasks('account', 'list-3')).single.title,
        'Final title',
      );
    },
  );

  test(
    'remote edit after a move still conflicts with the dependent patch',
    () async {
      const baselineUpdated = '2026-06-04T00:00:00.000Z';
      final baselineRaw = jsonEncode({
        'id': 'task-1',
        'title': 'Base title',
        'updated': baselineUpdated,
      });
      await database.taskListsDao.upsertTaskList(_taskList('list-2'));
      await database.tasksDao.upsertTask(
        _task(
          'list-1',
          'task-1',
          title: 'Base title',
          updatedUtc: baselineUpdated,
          rawJson: baselineRaw,
        ),
      );
      apiClient
        ..remoteTask = _taskDto(
          'task-1',
          title: 'Base title',
          updated: DateTime.parse(baselineUpdated),
        )
        ..remoteTaskAfterMove = _taskDto(
          'task-1',
          title: 'Independent remote title',
          updated: DateTime.utc(2026, 6, 4, 0, 10),
        );
      final repository = TasksRepository(
        database: database,
        accountId: 'account',
        nowUtc: () => DateTime.utc(2026, 6, 4),
      );
      await repository.moveTask(
        const TaskMoveInput(
          sourceTaskListId: 'list-1',
          taskId: 'task-1',
          destinationTaskListId: 'list-2',
        ),
      );
      await repository.patchTask(
        'list-2',
        'task-1',
        const TaskPatchInput({'title': 'Local title'}),
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

      expect(apiClient.calls, ['move_task:task-1']);
      final pending = await database.select(database.pendingOps).getSingle();
      expect(pending.operation, 'patch_task');
      expect(pending.lastErrorCode, 'conflict');
      expect(pending.lastErrorMessage, contains('title'));
      expect(
        (await database.tasksDao.listTasks('account', 'list-2')).single.title,
        'Local title',
      );
    },
  );

  test(
    'remote edit conflicts with a patch between two cross-list moves',
    () async {
      const baselineUpdated = '2026-06-04T00:00:00.000Z';
      final baselineRaw = jsonEncode({
        'id': 'task-1',
        'title': 'Base title',
        'updated': baselineUpdated,
      });
      for (final listId in ['list-2', 'list-3']) {
        await database.taskListsDao.upsertTaskList(_taskList(listId));
      }
      await database.tasksDao.upsertTask(
        _task(
          'list-1',
          'task-1',
          title: 'Base title',
          updatedUtc: baselineUpdated,
          rawJson: baselineRaw,
        ),
      );
      apiClient
        ..remoteTask = _taskDto(
          'task-1',
          title: 'Base title',
          updated: DateTime.parse(baselineUpdated),
        )
        ..remoteTaskAfterMove = _taskDto(
          'task-1',
          title: 'Independent remote title',
          updated: DateTime.utc(2026, 6, 4, 0, 10),
        );
      final repository = TasksRepository(
        database: database,
        accountId: 'account',
        nowUtc: () => DateTime.utc(2026, 6, 4),
      );
      await repository.moveTask(
        const TaskMoveInput(
          sourceTaskListId: 'list-1',
          taskId: 'task-1',
          destinationTaskListId: 'list-2',
        ),
      );
      await repository.patchTask(
        'list-2',
        'task-1',
        const TaskPatchInput({'title': 'Local title'}),
      );
      await repository.moveTask(
        const TaskMoveInput(
          sourceTaskListId: 'list-2',
          taskId: 'task-1',
          destinationTaskListId: 'list-3',
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

      expect(apiClient.calls, ['move_task:task-1']);
      final pending = await database.select(database.pendingOps).get();
      final patch = pending.singleWhere(
        (operation) => operation.operation == 'patch_task',
      );
      final laterMove = pending.singleWhere(
        (operation) => operation.operation == 'move_task',
      );
      expect(patch.lastErrorCode, 'conflict');
      expect(patch.lastErrorMessage, contains('title'));
      expect(laterMove.dependsOnOpId, patch.id);
      expect(
        (await database.tasksDao.listTasks('account', 'list-3')).single.title,
        'Local title',
      );
      expect(apiClient.remoteTask!.title, 'Independent remote title');
    },
  );

  test(
    'delete remains blocked behind a permanently rejected cross-list move',
    () async {
      await database.taskListsDao.upsertTaskList(_taskList('list-2'));
      await database.tasksDao.upsertTask(_task('list-1', 'task-1'));
      final repository = TasksRepository(
        database: database,
        accountId: 'account',
        nowUtc: () => DateTime.utc(2026, 6, 4),
      );
      await repository.moveTask(
        const TaskMoveInput(
          sourceTaskListId: 'list-1',
          taskId: 'task-1',
          destinationTaskListId: 'list-2',
        ),
      );
      await repository.deleteTask('list-2', 'task-1');
      apiClient.moveTaskError = const GoogleTasksApiError(
        statusCode: 400,
        message: 'Rejected',
      );

      expect(
        await PendingOpsReplayer(
          database: database,
          apiClient: apiClient,
          accountId: 'account',
          nowUtc: () => DateTime.utc(2026, 6, 4, 1),
        ).replayDueOps(),
        0,
      );
      expect(apiClient.calls, ['move_task:task-1']);
      final operations = await database.select(database.pendingOps).get();
      final move = operations.singleWhere((op) => op.operation == 'move_task');
      final delete = operations.singleWhere(
        (op) => op.operation == 'delete_task',
      );
      expect(move.nextAttemptAtUtc, startsWith('9999-12-31'));
      expect(delete.dependsOnOpId, move.id);
    },
  );

  test('known pre-dispatch create failure remains safely retryable', () async {
    await database.tasksDao.upsertTask(
      _task('list-1', 'local-task-safe', title: 'Draft'),
    );
    await _enqueue(
      database,
      id: 'safe-create',
      operation: 'create_task',
      taskListId: 'list-1',
      taskId: 'local-task-safe',
      localTempId: 'local-task-safe',
      request: {
        'body': {'title': 'Draft'},
      },
    );
    apiClient.createTaskError = const KnownUnsentRequestException(
      kind: RequestPreDispatchFailureKind.authentication,
    );
    expect(
      await PendingOpsReplayer(
        database: database,
        apiClient: apiClient,
        accountId: 'account',
        random: Random(0),
        nowUtc: () => DateTime.utc(2026, 6, 4),
      ).replayDueOps(),
      0,
    );
    final retry = await database.pendingOpsDao.getOp('safe-create');
    expect(retry!.state, 'retry');
    expect(retry.lastErrorCode, 'authentication_failed_before_dispatch');

    apiClient.createTaskError = null;
    expect(
      await PendingOpsReplayer(
        database: database,
        apiClient: apiClient,
        accountId: 'account',
        nowUtc: () => DateTime.utc(2026, 6, 4, 2),
      ).replayDueOps(),
      1,
    );
    expect(
      apiClient.calls.where((call) => call == 'create_task:list-1'),
      hasLength(2),
    );
  });

  test(
    'equal-timestamp task-list renames replay in dependency order',
    () async {
      apiClient.persistTaskListPatches = true;
      apiClient.remoteTaskList = _taskListDto('list-1', title: 'A');
      await database.taskListsDao.upsertTaskList(
        _taskList('list-1', title: 'A'),
      );
      final repository = TaskListsRepository(
        database: database,
        accountId: 'account',
        nowUtc: () => DateTime.utc(2026, 6, 4),
      );
      await repository.renameTaskList('list-1', 'B');
      await repository.renameTaskList('list-1', 'C');
      final queued = await database.select(database.pendingOps).get();
      expect(queued, hasLength(2));
      expect(queued.last.dependsOnOpId, queued.first.id);

      expect(
        await PendingOpsReplayer(
          database: database,
          apiClient: apiClient,
          accountId: 'account',
          nowUtc: () => DateTime.utc(2026, 6, 4, 1),
        ).replayDueOps(),
        2,
      );
      expect(apiClient.taskListPatchTitles, ['B', 'C']);
      expect(apiClient.remoteTaskList!.title, 'C');
      final local = (await database.taskListsDao.listTaskLists(
        'account',
      )).single;
      expect(local.title, 'C');
      expect(local.localDirty, isFalse);
    },
  );

  test(
    'in-flight task-list rename response does not revert a newer title',
    () async {
      final started = Completer<void>();
      final gate = Completer<void>();
      apiClient
        ..persistTaskListPatches = true
        ..taskListPatchStarted = started
        ..taskListPatchGate = gate;
      final repository = TaskListsRepository(
        database: database,
        accountId: 'account',
        nowUtc: () => DateTime.utc(2026, 6, 4),
      );
      await repository.renameTaskList('list-1', 'B');
      final replay = PendingOpsReplayer(
        database: database,
        apiClient: apiClient,
        accountId: 'account',
        nowUtc: () => DateTime.utc(2026, 6, 4, 1),
      ).replayDueOps();
      await started.future;
      await repository.renameTaskList('list-1', 'C');
      gate.complete();
      expect(await replay, 1);
      expect(
        (await database.taskListsDao.listTaskLists('account')).single.title,
        'C',
      );
      apiClient.taskListPatchGate = null;
      expect(
        await PendingOpsReplayer(
          database: database,
          apiClient: apiClient,
          accountId: 'account',
          nowUtc: () => DateTime.utc(2026, 6, 4, 2),
        ).replayDueOps(),
        1,
      );
      expect(apiClient.remoteTaskList!.title, 'C');
    },
  );

  test(
    'dependent list rename waits through a retryable first rename',
    () async {
      final repository = TaskListsRepository(
        database: database,
        accountId: 'account',
        nowUtc: () => DateTime.utc(2026, 6, 4),
      );
      await repository.renameTaskList('list-1', 'B');
      await repository.renameTaskList('list-1', 'C');
      apiClient.patchTaskListError = const GoogleTasksApiError(
        statusCode: 429,
        message: 'Rate limited',
      );

      expect(
        await PendingOpsReplayer(
          database: database,
          apiClient: apiClient,
          accountId: 'account',
          random: Random(0),
          nowUtc: () => DateTime.utc(2026, 6, 4, 1),
        ).replayDueOps(),
        0,
      );
      expect(apiClient.taskListPatchTitles, isEmpty);
      expect(
        (await database.taskListsDao.listTaskLists('account')).single.title,
        'C',
      );

      apiClient.patchTaskListError = null;
      expect(
        await PendingOpsReplayer(
          database: database,
          apiClient: apiClient,
          accountId: 'account',
          nowUtc: () => DateTime.utc(2026, 6, 4, 2),
        ).replayDueOps(),
        2,
      );
      expect(apiClient.taskListPatchTitles, ['B', 'C']);
      expect(
        (await database.taskListsDao.listTaskLists('account')).single.title,
        'C',
      );
    },
  );

  test('task-list rename followed by full update replays in order', () async {
    final repository = TaskListsRepository(
      database: database,
      accountId: 'account',
      nowUtc: () => DateTime.utc(2026, 6, 4),
    );
    await repository.renameTaskList('list-1', 'B');
    await repository.updateTaskListFull(
      'list-1',
      const TaskListPut({'title': 'C'}),
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
    expect(apiClient.calls, [
      'patch_task_list:list-1',
      'update_task_list:list-1',
    ]);
    final local = (await database.taskListsDao.listTaskLists('account')).single;
    expect(local.title, 'C');
    expect(local.localDirty, isFalse);
  });

  for (final childChanged in [false, true]) {
    test(
      'rename then delete ${childChanged ? 'blocks' : 'succeeds'} for child cutoff',
      () async {
        final baseline = DateTime.utc(2026, 6, 4);
        final childEdit = baseline.add(const Duration(minutes: 5));
        final renameAcknowledged = baseline.add(const Duration(minutes: 10));
        await database.taskListsDao.upsertTaskList(
          _taskList(
            'list-1',
            title: 'A',
            updatedUtc: baseline.toIso8601String(),
          ),
        );
        apiClient
          ..persistTaskListPatches = true
          ..remoteTaskList = _taskListDto(
            'list-1',
            title: 'A',
            updated: baseline,
          )
          ..taskListPatchResultUpdated = renameAcknowledged
          ..remoteTasksPage = TasksPageDto(
            items: childChanged
                ? [_taskDto('child-1', updated: childEdit)]
                : const [],
            rawJson: const {},
          );
        final repository = TaskListsRepository(
          database: database,
          accountId: 'account',
          nowUtc: () => baseline,
        );
        await repository.renameTaskList('list-1', 'B');
        await repository.deleteTaskList('list-1');

        final applied = await PendingOpsReplayer(
          database: database,
          apiClient: apiClient,
          accountId: 'account',
          nowUtc: () => baseline.add(const Duration(hours: 1)),
        ).replayDueOps();

        expect(apiClient.taskListPageUpdatedMins, [baseline]);
        expect(
          apiClient.calls.where((call) => call == 'delete_task_list:list-1'),
          hasLength(childChanged ? 0 : 1),
        );
        expect(applied, childChanged ? 1 : 2);
        if (childChanged) {
          final delete = (await database.select(database.pendingOps).get())
              .singleWhere(
                (operation) => operation.operation == 'delete_task_list',
              );
          expect(delete.lastErrorCode, 'conflict');
          expect(
            delete.baselineUpdatedUtc,
            renameAcknowledged.toIso8601String(),
          );
          expect(
            jsonDecode(delete.requestJson),
            containsPair(
              '_busymaxChildTaskConflictBaselineUpdatedUtc',
              baseline.toIso8601String(),
            ),
          );
        }
      },
    );
  }

  for (final reminderValue in [false, true]) {
    test(
      'list creation preserves in-flight reminder value $reminderValue and rename',
      () async {
        final started = Completer<void>();
        final gate = Completer<void>();
        apiClient
          ..createTaskListStarted = started
          ..createTaskListGate = gate;
        final repository = TaskListsRepository(
          database: database,
          accountId: 'account',
          nowUtc: () => DateTime.utc(2026, 6, 4),
        );
        await repository.createTaskList('Temporary');
        final temporary = (await database.taskListsDao.listTaskLists(
          'account',
        )).singleWhere((list) => list.id.startsWith('local-tasklist-'));
        await repository.renameTaskList(temporary.id, 'Renamed');
        await database.tasksDao.upsertTask(
          TasksCompanion.insert(
            accountId: 'account',
            taskListId: temporary.id,
            id: 'task-in-temporary-list',
            title: 'Reminder task',
            status: const Value('needsAction'),
            microsoftIsReminderOn: const Value(true),
            microsoftReminderDateTime: const Value('2026-06-05T09:00:00.000Z'),
            microsoftReminderTimeZone: const Value('UTC'),
            rawJson: '{"id":"task-in-temporary-list"}',
            createdLocalAtUtc: _now,
            updatedLocalAtUtc: _now,
          ),
        );
        await repository.setRemindersEnabled(temporary.id, !reminderValue);

        final replay = PendingOpsReplayer(
          database: database,
          apiClient: apiClient,
          accountId: 'account',
          nowUtc: () => DateTime.utc(2026, 6, 4, 1),
        ).replayDueOps();
        await started.future;
        await repository.setRemindersEnabled(temporary.id, reminderValue);
        gate.complete();
        expect(await replay, 2);

        final lists = await database.taskListsDao.listTaskLists('account');
        expect(lists.any((list) => list.id == temporary.id), isFalse);
        final server = lists.singleWhere((list) => list.id == 'list-server');
        expect(server.remindersEnabled, reminderValue);
        expect(server.title, 'Renamed');
        expect(
          (await database.tasksDao.listTasks(
            'account',
            'list-server',
          )).single.id,
          'task-in-temporary-list',
        );
        await NotificationScheduleService(
          database: database,
          nowUtc: () => DateTime.utc(2026, 6, 4, 1),
        ).rebuildUpcomingTaskNotifications('account');
        expect(
          await database.select(database.notificationSchedule).get(),
          hasLength(reminderValue ? 1 : 0),
        );
      },
    );
  }

  test(
    'parent identity dependency does not leave the parent locally dirty',
    () async {
      final repository = TasksRepository(
        database: database,
        accountId: 'account',
        apiClient: apiClient,
        nowUtc: () => DateTime.utc(2026, 6, 4),
      );
      await repository.createTask(
        'list-1',
        const TaskCreateInput(title: 'Parent'),
      );
      final temporaryParent = (await database.tasksDao.listTasks(
        'account',
        'list-1',
      )).single;
      await repository.createSubtask(
        taskListId: 'list-1',
        parentTaskId: temporaryParent.id,
        title: 'Child',
      );
      apiClient.createdTasks.addAll([
        _taskDto('parent-server', title: 'Parent'),
        _taskDto('child-server', title: 'Child'),
      ]);

      expect(
        await PendingOpsReplayer(
          database: database,
          apiClient: apiClient,
          accountId: 'account',
          nowUtc: () => DateTime.utc(2026, 6, 4, 1),
        ).replayDueOps(),
        3,
      );
      var tasks = await database.tasksDao.listTasks('account', 'list-1');
      expect(tasks, hasLength(2));
      expect(tasks.map((task) => task.localDirty), everyElement(isFalse));
      expect(await database.select(database.pendingOps).get(), isEmpty);
      expect(apiClient.createParentTaskIds, [null, 'parent-server']);

      apiClient
        ..remoteTaskListsPage = TaskListsPageDto(
          items: [_taskListDto('list-1')],
          rawJson: const {},
        )
        ..remoteTasksPage = TasksPageDto(
          items: [
            _taskDto(
              'parent-server',
              title: 'Parent changed remotely',
              updated: DateTime.utc(2026, 6, 4, 2),
            ),
            _taskDto('child-server', title: 'Child', parent: 'parent-server'),
          ],
          rawJson: const {},
        );
      await SyncEngine(
        database: database,
        apiClient: apiClient,
        accountId: 'account',
        nowUtc: () => DateTime.utc(2026, 6, 4, 3),
      ).fullSync();
      tasks = await database.tasksDao.listTasks('account', 'list-1');
      expect(
        tasks.singleWhere((task) => task.id == 'parent-server').title,
        'Parent changed remotely',
      );
    },
  );

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

  for (final conflictCase in [
    (
      name: 'notes',
      field: 'notes',
      localValue: 'Local notes' as Object?,
      baseline: <String, Object?>{
        'body': {'content': '<p>Base notes</p>', 'contentType': 'html'},
      },
      current: <String, Object?>{
        'body': {'content': '<p>Remote notes</p>', 'contentType': 'html'},
      },
    ),
    (
      name: 'due date',
      field: 'microsoftDueDateTime',
      localValue: <String, Object?>{
        'dateTime': '2026-06-07T09:00:00',
        'timeZone': 'UTC',
      },
      baseline: <String, Object?>{
        'dueDateTime': {'dateTime': '2026-06-05T09:00:00', 'timeZone': 'UTC'},
      },
      current: <String, Object?>{
        'dueDateTime': {'dateTime': '2026-06-06T09:00:00', 'timeZone': 'UTC'},
      },
    ),
    (
      name: 'reminder date',
      field: 'microsoftReminderDateTime',
      localValue: <String, Object?>{
        'dateTime': '2026-06-07T08:00:00',
        'timeZone': 'UTC',
      },
      baseline: <String, Object?>{
        'reminderDateTime': {
          'dateTime': '2026-06-05T08:00:00',
          'timeZone': 'UTC',
        },
      },
      current: <String, Object?>{
        'reminderDateTime': {
          'dateTime': '2026-06-06T08:00:00',
          'timeZone': 'UTC',
        },
      },
    ),
    (
      name: 'reminder setting',
      field: 'microsoftIsReminderOn',
      localValue: true as Object?,
      baseline: <String, Object?>{'isReminderOn': false},
      current: <String, Object?>{'isReminderOn': true},
    ),
  ]) {
    test(
      'Microsoft ${conflictCase.name} overlap is blocked before mutation',
      () async {
        final baselineRaw = <String, Object?>{
          'id': 'task-1',
          'title': 'Task',
          'lastModifiedDateTime': '2026-06-04T00:00:00.000Z',
          ...conflictCase.baseline,
        };
        final remoteRaw = <String, Object?>{
          'id': 'task-1',
          'title': 'Task',
          'lastModifiedDateTime': '2026-06-04T00:10:00.000Z',
          ...conflictCase.current,
        };
        await database.tasksDao.upsertTask(
          _task(
            'list-1',
            'task-1',
            updatedUtc: '2026-06-04T00:00:00.000Z',
            rawJson: jsonEncode(baselineRaw),
          ),
        );
        await _enqueue(
          database,
          id: '01',
          operation: 'patch_task',
          taskListId: 'list-1',
          taskId: 'task-1',
          request: {conflictCase.field: conflictCase.localValue},
          baselineUpdatedUtc: '2026-06-04T00:00:00.000Z',
          baselineRawJson: jsonEncode(baselineRaw),
        );
        final graphClient = _ConflictMicrosoftTodoApiClient(remoteRaw);

        final applied = await PendingOpsReplayer(
          database: database,
          apiClient: _microsoftAdapter(graphClient),
          accountId: 'account',
          nowUtc: () => DateTime.utc(2026, 6, 4, 1),
        ).replayDueOps();

        final pending = await database.pendingOpsDao.getOp('01');
        expect(applied, 0);
        expect(graphClient.updateTaskCalls, 0);
        expect(pending!.lastErrorCode, 'conflict');
        expect(pending.lastErrorMessage, contains(conflictCase.field));
      },
    );
  }

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

  test('title notes title task patches replay without self-conflict', () async {
    const baselineUpdatedUtc = '2026-06-04T00:00:00.000Z';
    final baselineRawJson = jsonEncode({
      'id': 'task-1',
      'title': 'A',
      'notes': 'Base notes',
      'updated': baselineUpdatedUtc,
    });
    apiClient
      ..persistTaskPatches = true
      ..remoteTask = _taskDto(
        'task-1',
        title: 'A',
        notes: 'Base notes',
        updated: DateTime.parse(baselineUpdatedUtc),
      );
    await database.tasksDao.upsertTask(
      _task(
        'list-1',
        'task-1',
        title: 'A',
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
      const TaskPatchInput({'title': 'B'}),
    );
    await repository.patchTask(
      'list-1',
      'task-1',
      const TaskPatchInput({'notes': 'Local notes'}),
    );
    await repository.patchTask(
      'list-1',
      'task-1',
      const TaskPatchInput({'title': 'C'}),
    );

    final applied = await PendingOpsReplayer(
      database: database,
      apiClient: apiClient,
      accountId: 'account',
      random: Random(0),
      nowUtc: () => DateTime.utc(2026, 6, 4, 1),
    ).replayDueOps();

    expect(applied, 3);
    expect(apiClient.taskPatchFields, [
      {'title': 'B'},
      {'notes': 'Local notes'},
      {'title': 'C'},
    ]);
    expect(apiClient.remoteTask!.title, 'C');
    expect(await database.select(database.pendingOps).get(), isEmpty);
  });

  test(
    'title notes title task patches preserve a genuine remote title conflict',
    () async {
      const baselineUpdatedUtc = '2026-06-04T00:00:00.000Z';
      final baselineRawJson = jsonEncode({
        'id': 'task-1',
        'title': 'A',
        'notes': 'Base notes',
        'updated': baselineUpdatedUtc,
      });
      apiClient
        ..persistTaskPatches = true
        ..remoteTask = _taskDto(
          'task-1',
          title: 'A',
          notes: 'Base notes',
          updated: DateTime.parse(baselineUpdatedUtc),
        )
        ..remoteTaskAfterSecondPatch = _taskDto(
          'task-1',
          title: 'External title',
          notes: 'Local notes',
          updated: DateTime.utc(2026, 6, 4, 0, 8),
        );
      await database.tasksDao.upsertTask(
        _task(
          'list-1',
          'task-1',
          title: 'A',
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
        const TaskPatchInput({'title': 'B'}),
      );
      await repository.patchTask(
        'list-1',
        'task-1',
        const TaskPatchInput({'notes': 'Local notes'}),
      );
      await repository.patchTask(
        'list-1',
        'task-1',
        const TaskPatchInput({'title': 'C'}),
      );

      final applied = await PendingOpsReplayer(
        database: database,
        apiClient: apiClient,
        accountId: 'account',
        random: Random(0),
        nowUtc: () => DateTime.utc(2026, 6, 4, 1),
      ).replayDueOps();

      expect(applied, 2);
      expect(apiClient.taskPatchFields, [
        {'title': 'B'},
        {'notes': 'Local notes'},
      ]);
      expect(apiClient.remoteTask!.title, 'External title');
      final pending = await database.select(database.pendingOps).getSingle();
      expect(pending.lastErrorCode, 'conflict');
      expect(pending.lastErrorMessage, contains('title'));
    },
  );

  for (final dependentOperation in ['delete_task', 'move_task']) {
    final action = dependentOperation == 'delete_task' ? 'delete' : 'move';
    test(
      'existing task edit followed by $action does not self-conflict',
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
          const TaskPatchInput({'title': 'Local title'}),
        );
        if (dependentOperation == 'delete_task') {
          await repository.deleteTask('list-1', 'task-1');
        } else {
          await repository.moveTask(
            const TaskMoveInput(
              sourceTaskListId: 'list-1',
              taskId: 'task-1',
              previousSiblingTaskId: 'task-0',
            ),
          );
        }

        final queued = await database.pendingOpsDao.pendingOpsForReplay(
          'account',
          _later,
        );
        expect(queued, hasLength(2));
        final edit = queued.singleWhere(
          (operation) => operation.operation == 'patch_task',
        );
        final dependent = queued.singleWhere(
          (operation) => operation.operation == dependentOperation,
        );
        expect(dependent.dependsOnOpId, edit.id);

        final applied = await PendingOpsReplayer(
          database: database,
          apiClient: apiClient,
          accountId: 'account',
          random: Random(0),
          nowUtc: () => DateTime.utc(2026, 6, 4, 1),
        ).replayDueOps();

        expect(applied, 2);
        expect(await database.select(database.pendingOps).get(), isEmpty);
        expect(apiClient.calls, ['patch_task:task-1', '${action}_task:task-1']);
      },
    );
  }

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

  test(
    'deleting an in-flight checklist create queues a server delete',
    () async {
      final checklistClient = _ChecklistTaskRemoteClient();
      final repository = TasksRepository(
        database: database,
        accountId: 'account',
        apiClient: checklistClient,
        nowUtc: () => DateTime.utc(2026, 6, 4),
      );
      await database.tasksDao.upsertTask(_task('list-1', 'task-1'));
      await repository.createSubtask(
        taskListId: 'list-1',
        parentTaskId: 'task-1',
        title: 'Step',
      );
      final localItem = decodeTaskChecklistItems(
        (await database.tasksDao.listTasks(
          'account',
          'list-1',
        )).single.microsoftChecklistItemsJson,
      ).single;
      final gate = Completer<void>();
      checklistClient.createChecklistGate = gate;
      final replay = PendingOpsReplayer(
        database: database,
        apiClient: checklistClient,
        accountId: 'account',
        nowUtc: () => DateTime.utc(2026, 6, 4, 1),
      ).replayDueOps();
      await _waitFor(() => checklistClient.checklistCalls.isNotEmpty);

      await repository.deleteChecklistSubtask(
        taskListId: 'list-1',
        parentTaskId: 'task-1',
        checklistItemId: localItem.id,
      );
      final queued = await database.select(database.pendingOps).get();
      final create = queued.singleWhere(
        (operation) => operation.operation == 'create_task_checklist_item',
      );
      final delete = queued.singleWhere(
        (operation) => operation.operation == 'delete_task_checklist_item',
      );
      expect(create.state, 'in_progress');
      expect(delete.dependsOnOpId, create.id);

      gate.complete();
      expect(await replay, 1);
      final afterCreate = decodeTaskChecklistItems(
        (await database.tasksDao.listTasks(
          'account',
          'list-1',
        )).single.microsoftChecklistItemsJson,
      );
      expect(afterCreate, isEmpty);
      expect(
        await PendingOpsReplayer(
          database: database,
          apiClient: checklistClient,
          accountId: 'account',
          nowUtc: () => DateTime.utc(2026, 6, 4, 2),
        ).replayDueOps(),
        1,
      );
      expect(checklistClient.checklistCalls, [
        'create:Step',
        'delete:server-step',
      ]);
    },
  );

  test(
    'checklist claim invalidates a cancellation snapshot before its transaction',
    () async {
      final checklistClient = _ChecklistTaskRemoteClient();
      final deleteReached = Completer<void>();
      final releaseDelete = Completer<void>();
      final repository = TasksRepository(
        database: database,
        accountId: 'account',
        apiClient: checklistClient,
        nowUtc: () => DateTime.utc(2026, 6, 4),
        beforeChecklistDeleteTransaction: () async {
          deleteReached.complete();
          await releaseDelete.future;
        },
      );
      await database.tasksDao.upsertTask(_task('list-1', 'task-1'));
      await repository.createSubtask(
        taskListId: 'list-1',
        parentTaskId: 'task-1',
        title: 'Step',
      );
      final localItem = decodeTaskChecklistItems(
        (await database.tasksDao.listTasks(
          'account',
          'list-1',
        )).single.microsoftChecklistItemsJson,
      ).single;

      final deletion = repository.deleteChecklistSubtask(
        taskListId: 'list-1',
        parentTaskId: 'task-1',
        checklistItemId: localItem.id,
      );
      await deleteReached.future;
      final createGate = Completer<void>();
      checklistClient.createChecklistGate = createGate;
      final replay = PendingOpsReplayer(
        database: database,
        apiClient: checklistClient,
        accountId: 'account',
        nowUtc: () => DateTime.utc(2026, 6, 4, 1),
      ).replayDueOps();
      await _waitFor(() => checklistClient.checklistCalls.isNotEmpty);
      releaseDelete.complete();
      await deletion;

      final queued = await database.select(database.pendingOps).get();
      final create = queued.singleWhere(
        (operation) => operation.operation == 'create_task_checklist_item',
      );
      final delete = queued.singleWhere(
        (operation) => operation.operation == 'delete_task_checklist_item',
      );
      expect(create.state, 'in_progress');
      expect(delete.dependsOnOpId, create.id);

      createGate.complete();
      expect(await replay, 1);
      expect(
        await PendingOpsReplayer(
          database: database,
          apiClient: checklistClient,
          accountId: 'account',
          nowUtc: () => DateTime.utc(2026, 6, 4, 2),
        ).replayDueOps(),
        1,
      );
      expect(checklistClient.checklistCalls, [
        'create:Step',
        'delete:server-step',
      ]);
    },
  );

  test(
    'checklist deletion resolves a creation acknowledged before its transaction',
    () async {
      final checklistClient = _ChecklistTaskRemoteClient();
      final deleteReached = Completer<void>();
      final releaseDelete = Completer<void>();
      final repository = TasksRepository(
        database: database,
        accountId: 'account',
        apiClient: checklistClient,
        nowUtc: () => DateTime.utc(2026, 6, 4),
        beforeChecklistDeleteTransaction: () async {
          deleteReached.complete();
          await releaseDelete.future;
        },
      );
      await database.tasksDao.upsertTask(_task('list-1', 'task-1'));
      await repository.createSubtask(
        taskListId: 'list-1',
        parentTaskId: 'task-1',
        title: 'Step',
      );
      final localItem = decodeTaskChecklistItems(
        (await database.tasksDao.listTasks(
          'account',
          'list-1',
        )).single.microsoftChecklistItemsJson,
      ).single;

      final deletion = repository.deleteChecklistSubtask(
        taskListId: 'list-1',
        parentTaskId: 'task-1',
        checklistItemId: localItem.id,
      );
      await deleteReached.future;
      expect(
        await PendingOpsReplayer(
          database: database,
          apiClient: checklistClient,
          accountId: 'account',
          nowUtc: () => DateTime.utc(2026, 6, 4, 1),
        ).replayDueOps(),
        1,
      );
      expect(await database.select(database.pendingOps).get(), isEmpty);
      expect(
        decodeTaskChecklistItems(
          (await database.tasksDao.listTasks(
            'account',
            'list-1',
          )).single.microsoftChecklistItemsJson,
        ).single.id,
        'server-step',
      );

      releaseDelete.complete();
      await deletion;
      final pendingDelete = await database
          .select(database.pendingOps)
          .getSingle();
      expect(pendingDelete.operation, 'delete_task_checklist_item');
      expect(
        jsonDecode(pendingDelete.requestJson)['checklistItemId'],
        'server-step',
      );
      expect(
        decodeTaskChecklistItems(
          (await database.tasksDao.listTasks(
            'account',
            'list-1',
          )).single.microsoftChecklistItemsJson,
        ),
        isEmpty,
      );
      expect(
        await PendingOpsReplayer(
          database: database,
          apiClient: checklistClient,
          accountId: 'account',
          nowUtc: () => DateTime.utc(2026, 6, 4, 2),
        ).replayDueOps(),
        1,
      );
      expect(checklistClient.checklistCalls, [
        'create:Step',
        'delete:server-step',
      ]);
      expect(await database.select(database.pendingOps).get(), isEmpty);
    },
  );

  test(
    'checklist deletion accepts a temporary ID after creation is acknowledged',
    () async {
      final checklistClient = _ChecklistTaskRemoteClient();
      final repository = TasksRepository(
        database: database,
        accountId: 'account',
        apiClient: checklistClient,
        nowUtc: () => DateTime.utc(2026, 6, 4),
      );
      await database.tasksDao.upsertTask(_task('list-1', 'task-1'));
      await repository.createSubtask(
        taskListId: 'list-1',
        parentTaskId: 'task-1',
        title: 'Step',
      );
      final temporaryId = decodeTaskChecklistItems(
        (await database.tasksDao.listTasks(
          'account',
          'list-1',
        )).single.microsoftChecklistItemsJson,
      ).single.id;

      expect(
        await PendingOpsReplayer(
          database: database,
          apiClient: checklistClient,
          accountId: 'account',
          nowUtc: () => DateTime.utc(2026, 6, 4, 1),
        ).replayDueOps(),
        1,
      );
      final acknowledged = decodeTaskChecklistItems(
        (await database.tasksDao.listTasks(
          'account',
          'list-1',
        )).single.microsoftChecklistItemsJson,
      ).single;
      expect(acknowledged.id, 'server-step');
      expect(acknowledged.matchesIdentity(temporaryId), isTrue);

      await repository.deleteChecklistSubtask(
        taskListId: 'list-1',
        parentTaskId: 'task-1',
        checklistItemId: temporaryId,
      );

      final pendingDelete = await database
          .select(database.pendingOps)
          .getSingle();
      expect(pendingDelete.operation, 'delete_task_checklist_item');
      expect(
        jsonDecode(pendingDelete.requestJson)['checklistItemId'],
        'server-step',
      );
      expect(
        await PendingOpsReplayer(
          database: database,
          apiClient: checklistClient,
          accountId: 'account',
          nowUtc: () => DateTime.utc(2026, 6, 4, 2),
        ).replayDueOps(),
        1,
      );
      expect(checklistClient.checklistCalls, [
        'create:Step',
        'delete:server-step',
      ]);
      expect(await database.select(database.pendingOps).get(), isEmpty);
    },
  );

  test('unknown checklist creation outcome is not submitted again', () async {
    final checklistClient = _ChecklistTaskRemoteClient()
      ..createChecklistItemError = StateError('response was lost');
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

    final replayer = PendingOpsReplayer(
      database: database,
      apiClient: checklistClient,
      accountId: 'account',
      nowUtc: () => DateTime.utc(2026, 6, 4),
    );
    expect(await replayer.replayDueOps(), 0);
    expect(await replayer.replayDueOps(), 0);

    final pending = await database.pendingOpsDao.getOp('01');
    expect(pending!.state, 'recovery_required');
    expect(checklistClient.checklistCalls, ['create:Step']);
  });
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

class _ConflictMicrosoftTodoApiClient implements MicrosoftTodoApiClient {
  _ConflictMicrosoftTodoApiClient(Map<String, Object?> remoteTask)
    : remoteTask = MicrosoftTodoTaskDto.fromJson(remoteTask);

  final MicrosoftTodoTaskDto remoteTask;
  int updateTaskCalls = 0;

  @override
  Future<MicrosoftTodoTaskDto> getTask({
    required String taskListId,
    required String taskId,
  }) async => remoteTask;

  @override
  Future<MicrosoftTodoTaskDto> updateTask({
    required String taskListId,
    required String taskId,
    required Map<String, Object?> patch,
  }) async {
    updateTaskCalls += 1;
    return MicrosoftTodoTaskDto.fromJson({...remoteTask.rawJson, ...patch});
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _CommitInterruption extends QueryInterceptor {
  final commitReached = Completer<void>();
  final _resume = Completer<void>();
  var _armed = false;

  void arm() => _armed = true;

  void resume() {
    if (!_resume.isCompleted) _resume.complete();
  }

  @override
  Future<void> commitTransaction(TransactionExecutor inner) async {
    await super.commitTransaction(inner);
    if (!_armed) return;
    _armed = false;
    commitReached.complete();
    await _resume.future;
  }
}

class _FakeTaskRemoteClient implements TaskRemoteClient {
  TaskDto? createdTask;
  final List<TaskDto> createdTasks = [];
  final calls = <String>[];
  final taskPatchFields = <Map<String, Object?>>[];
  final createParentTaskIds = <String?>[];
  final moveParentTaskIds = <String?>[];
  final taskListPatchTitles = <String>[];
  GoogleTasksApiError? patchTaskListError;
  Object? createTaskListError;
  Object? createTaskError;
  Object? patchTaskError;
  GoogleTasksApiError? deleteTaskError;
  GoogleTasksApiError? clearCompletedError;
  GoogleTasksApiError? moveTaskError;
  TaskListDto? remoteTaskList;
  TaskDto? remoteTask;
  TaskDto? remoteTaskAfterSecondPatch;
  TaskDto? remoteTaskAfterMove;
  DateTime? taskListPatchResultUpdated;
  final taskListPageUpdatedMins = <DateTime?>[];
  Completer<void>? createTaskGate;
  Completer<void>? createTaskListStarted;
  Completer<void>? createTaskListGate;
  Completer<void>? taskListPatchStarted;
  Completer<void>? taskListPatchGate;
  bool persistTaskPatches = false;
  bool persistTaskListPatches = false;
  int _taskPatchRevision = 0;
  TasksPageDto remoteTasksPage = const TasksPageDto(items: [], rawJson: {});
  TaskListsPageDto remoteTaskListsPage = const TaskListsPageDto(
    items: [],
    rawJson: {},
  );

  @override
  Future<TaskListDto> createTaskList({required String title}) async {
    calls.add('create_task_list:$title');
    if (createTaskListStarted?.isCompleted == false) {
      createTaskListStarted!.complete();
    }
    await createTaskListGate?.future;
    final error = createTaskListError;
    if (error != null) throw error;
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
    final title = patch.fields['title'].toString();
    taskListPatchTitles.add(title);
    if (taskListPatchStarted?.isCompleted == false) {
      taskListPatchStarted!.complete();
    }
    await taskListPatchGate?.future;
    final result = _taskListDto(
      taskListId,
      title: title,
      updated: taskListPatchResultUpdated,
    );
    if (persistTaskListPatches) remoteTaskList = result;
    return result;
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
    return (createdTasks.isNotEmpty ? createdTasks.removeAt(0) : createdTask) ??
        _taskDto('task-server', title: create.fields['title'].toString());
  }

  @override
  Future<TaskDto> patchTask({
    required String taskListId,
    required String taskId,
    required TaskPatch patch,
  }) async {
    final error = patchTaskError;
    if (error != null) throw error;
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
      if (taskPatchFields.length == 2 && remoteTaskAfterSecondPatch != null) {
        remoteTask = remoteTaskAfterSecondPatch;
      }
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
    final result = _taskDto(taskId, title: 'Moved', parent: parentTaskId);
    final afterMove = remoteTaskAfterMove;
    if (afterMove != null) remoteTask = afterMove;
    return result;
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
  }) async => remoteTaskListsPage;

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
    taskListPageUpdatedMins.add(updatedMin);
    return remoteTasksPage;
  }
}

class _ChecklistTaskRemoteClient extends _FakeTaskRemoteClient
    implements TaskChecklistRemoteClient {
  final checklistCalls = <String>[];
  Object? createChecklistItemError;
  Completer<void>? createChecklistGate;

  @override
  Future<TaskChecklistItemDto> createChecklistItem({
    required String taskListId,
    required String taskId,
    required String title,
    bool completed = false,
  }) async {
    checklistCalls.add('create:$title');
    await createChecklistGate?.future;
    final error = createChecklistItemError;
    if (error != null) throw error;
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
          authState: const Value('signed_in'),
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

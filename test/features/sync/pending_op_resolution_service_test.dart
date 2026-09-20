import 'dart:async';
import 'dart:convert';

import 'package:busymax/src/calendar_providers/calendar_mutation.dart';
import 'package:busymax/src/calendar_providers/calendar_sync_dto.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:busymax/src/db/app_database.dart';
import 'package:busymax/src/features/calendar/data/calendar_repository.dart';
import 'package:busymax/src/features/calendar/presentation/event_editor_draft.dart';
import 'package:busymax/src/features/sync/pending_op_resolution_service.dart';
import 'package:busymax/src/features/sync/pending_ops_replayer.dart';
import 'package:busymax/src/features/tasks/domain/task_remote_client.dart';
import 'package:busymax/src/google_tasks/api/google_tasks_api_error.dart';
import 'package:busymax/src/features/tasks/domain/task_remote_models.dart';
import 'package:busymax/src/features/tasks/domain/task_checklist_item.dart';
import 'package:busymax/src/providers/busy_provider.dart';

void main() {
  late AppDatabase database;
  late _FakeTaskRemoteClient apiClient;
  late PendingOpResolutionService service;
  late int taskSyncCalls;
  late int calendarSyncCalls;

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    apiClient = _FakeTaskRemoteClient();
    taskSyncCalls = 0;
    calendarSyncCalls = 0;
    service = PendingOpResolutionService(
      database: database,
      apiClient: apiClient,
      accountId: 'account',
      syncTasks: () async => taskSyncCalls += 1,
      syncCalendar: () async => calendarSyncCalls += 1,
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
      expect(taskSyncCalls, 1);
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
      expect(taskSyncCalls, 1);
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
      expect(taskSyncCalls, 1);
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
      expect(taskSyncCalls, 1);
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
      expect(taskSyncCalls, 1);
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
      expect(taskSyncCalls, 0);
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
      expect(taskSyncCalls, 0);
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
      expect(taskSyncCalls, 1);
    },
  );

  test('discarding a cross-list move discards its dependent edits', () async {
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
    await _enqueueBlockedOp(
      database,
      id: 'dependent-edit',
      operation: 'patch_task',
      taskListId: 'list-2',
      taskId: 'task-1',
      dependsOnOpId: 'op-1',
      request: {'title': 'Destination edit'},
    );

    await service.discard('op-1');

    expect(await database.select(database.pendingOps).get(), isEmpty);
    expect(
      (await database.tasksDao.listTasks('account', 'list-1')).single.title,
      'Remote source task',
    );
    expect(await database.tasksDao.listTasks('account', 'list-2'), isEmpty);
  });

  test('discarding A to B to C removes every destination projection', () async {
    apiClient.remoteTask = _taskDto('task-1', title: 'Remote source task');
    await database.taskListsDao.upsertTaskList(_localTaskList('list-2'));
    await database.taskListsDao.upsertTaskList(_localTaskList('list-3'));
    await database.tasksDao.upsertTask(
      _localTask(
        'task-1',
        taskListId: 'list-3',
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
    await _enqueueBlockedOp(
      database,
      id: 'move-to-c',
      operation: 'move_task',
      taskListId: 'list-2',
      taskId: 'task-1',
      dependsOnOpId: 'op-1',
      request: {'destinationTasklist': 'list-3'},
    );

    await service.discard('op-1');

    final source = await database.tasksDao.listTasks('account', 'list-1');
    expect(source, hasLength(1));
    expect(source.single.title, 'Remote source task');
    expect(source.single.localDirty, isFalse);
    expect(await database.tasksDao.listTasks('account', 'list-2'), isEmpty);
    expect(await database.tasksDao.listTasks('account', 'list-3'), isEmpty);
    expect(await database.select(database.pendingOps).get(), isEmpty);
  });

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
      expect(taskSyncCalls, 1);
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
    expect(taskSyncCalls, 1);
  });

  test('discard blocked calendar removal restores the source', () async {
    await database
        .into(database.calendarSources)
        .insert(
          CalendarSourcesCompanion.insert(
            id: 'calendar-source',
            accountId: 'account',
            provider: 'google',
            providerCalendarId: 'calendar@example.com',
            summary: 'Calendar',
            hidden: const Value(true),
            isDeleted: const Value(true),
            createdAtLocal: 1,
            updatedAtLocal: 1,
          ),
        );
    await _enqueueBlockedOp(
      database,
      entityType: 'calendar',
      operation: 'delete',
      operationType: 'calendar.delete',
      calendarSourceId: 'calendar-source',
      request: const {calendarRemovalPreviousHiddenKey: false},
    );

    await service.discard('op-1');

    final source = await database.select(database.calendarSources).getSingle();
    expect(source.isDeleted, isFalse);
    expect(source.hidden, isFalse);
    expect(await database.pendingOpsDao.getOp('op-1'), equals(null));
    expect(calendarSyncCalls, 1);
    expect(taskSyncCalls, 0);
  });

  test(
    'discard blocked calendar creation removes its temporary source',
    () async {
      final repository = _calendarRepository(database);
      final sourceId = await repository.createLocalSource(
        accountId: 'account',
        summary: 'Temporary calendar',
      );
      final operation = await database.select(database.pendingOps).getSingle();
      await _blockOperation(database, operation.id);

      await service.discard(operation.id);

      expect(await database.select(database.calendarSources).get(), isEmpty);
      expect(await database.select(database.calendarEvents).get(), isEmpty);
      expect(await database.select(database.pendingOps).get(), isEmpty);
      expect(calendarSyncCalls, 0);
      expect(taskSyncCalls, 0);
      expect(sourceId, isNotEmpty);
    },
  );

  test(
    'discard blocked calendar creation removes dependent events and operations',
    () async {
      final repository = _calendarRepository(database);
      final sourceId = await repository.createLocalSource(
        accountId: 'account',
        summary: 'Temporary calendar',
      );
      final source = await database
          .select(database.calendarSources)
          .getSingle();
      await repository.createLocalEvent(
        EventEditorDraft.newEvent(
          accountId: 'account',
          sourceId: sourceId,
          providerCalendarId: source.providerCalendarId,
          start: DateTime.utc(2026, 6, 5, 9),
          end: DateTime.utc(2026, 6, 5, 10),
        ).copyWith(title: 'Dependent event'),
      );
      final operations = await database.select(database.pendingOps).get();
      final calendarCreate = operations.singleWhere(
        (operation) => operation.operationType == 'calendar.create',
      );
      final eventCreate = operations.singleWhere(
        (operation) => operation.operationType == 'event.create',
      );
      expect(eventCreate.dependsOnOpId, calendarCreate.id);
      await _blockOperation(database, calendarCreate.id);

      await service.discard(calendarCreate.id);

      expect(await database.select(database.calendarSources).get(), isEmpty);
      expect(await database.select(database.calendarEvents).get(), isEmpty);
      expect(await database.select(database.pendingOps).get(), isEmpty);
      expect(calendarSyncCalls, 0);
      expect(taskSyncCalls, 0);
    },
  );

  test('discard blocked calendar patch restores optimistic metadata', () async {
    final repository = _calendarRepository(database);
    await repository.upsertSource(
      accountId: 'account',
      source: const CalendarSourceDto(
        provider: BusyProvider.google,
        providerCalendarId: 'calendar@example.com',
        summary: 'Provider name',
        dataOwner: 'google-account@example.com',
        rawJson: {'id': 'calendar@example.com', 'summary': 'Provider name'},
      ),
    );
    const sourceId = 'account|google|calendar@example.com';
    await repository.renameLocalSource(sourceId, 'Optimistic name');
    final operation = await database.select(database.pendingOps).getSingle();
    await _blockOperation(database, operation.id);

    await service.discard(operation.id);

    final source = await database.select(database.calendarSources).getSingle();
    expect(source.summary, 'Provider name');
    expect(await database.select(database.pendingOps).get(), isEmpty);
    expect(calendarSyncCalls, 1);
    expect(taskSyncCalls, 0);
  });

  test('discard blocked event creation removes its local projection', () async {
    final repository = _calendarRepository(database);
    await repository.upsertSource(
      accountId: 'account',
      source: const CalendarSourceDto(
        provider: BusyProvider.google,
        providerCalendarId: 'calendar@example.com',
        summary: 'Calendar',
      ),
    );
    final sourceId = CalendarRepository.sourceId(
      accountId: 'account',
      provider: BusyProvider.google,
      providerCalendarId: 'calendar@example.com',
    );
    final operationId = await repository.createLocalEvent(
      EventEditorDraft.newEvent(
        accountId: 'account',
        sourceId: sourceId,
        providerCalendarId: 'calendar@example.com',
        start: DateTime.utc(2026, 6, 5, 9),
        end: DateTime.utc(2026, 6, 5, 10),
      ).copyWith(title: 'Unsent event'),
    );
    await _blockOperation(database, operationId);

    await service.discard(operationId);

    expect(await database.select(database.calendarEvents).get(), isEmpty);
    expect(await database.select(database.pendingOps).get(), isEmpty);
    expect(calendarSyncCalls, 0);
    expect(taskSyncCalls, 0);
  });

  test('discard blocked event patch restores its provider baseline', () async {
    final repository = _calendarRepository(database);
    await repository.upsertSource(
      accountId: 'account',
      source: const CalendarSourceDto(
        provider: BusyProvider.google,
        providerCalendarId: 'calendar@example.com',
        summary: 'Calendar',
      ),
    );
    await repository.upsertEvent(
      accountId: 'account',
      event: const CalendarEventDto(
        provider: BusyProvider.google,
        providerCalendarId: 'calendar@example.com',
        providerEventId: 'event-1',
        title: 'Provider title',
        startDateTime: '2026-06-05T09:00:00.000Z',
        startTimeZone: 'UTC',
        endDateTime: '2026-06-05T10:00:00.000Z',
        endTimeZone: 'UTC',
        organizerJson: {'self': true},
        updatedAtServer: '2026-06-04T00:00:00.000Z',
        rawJson: {
          'id': 'event-1',
          'summary': 'Provider title',
          'start': {'dateTime': '2026-06-05T09:00:00.000Z', 'timeZone': 'UTC'},
          'end': {'dateTime': '2026-06-05T10:00:00.000Z', 'timeZone': 'UTC'},
          'organizer': {'self': true},
          'updated': '2026-06-04T00:00:00.000Z',
        },
      ),
    );
    final event = await database.select(database.calendarEvents).getSingle();
    final detail = await repository.loadEventDetail(event.id);
    await repository.updateLocalEvent(
      EventEditorDraft.fromEventDetail(
        detail!,
      ).copyWith(title: 'Optimistic title'),
    );
    final operation = await database.select(database.pendingOps).getSingle();
    await _blockOperation(database, operation.id);

    await service.discard(operation.id);

    final restored = await database.select(database.calendarEvents).getSingle();
    expect(restored.title, 'Provider title');
    expect(restored.syncStatus, 'synced');
    expect(restored.isDeleted, isFalse);
    expect(await database.select(database.pendingOps).get(), isEmpty);
    expect(calendarSyncCalls, 1);
    expect(taskSyncCalls, 0);
  });

  test(
    'retry routes task synchronization through the shared callback',
    () async {
      var taskSyncCalls = 0;
      final coordinatedService = PendingOpResolutionService(
        database: database,
        accountId: 'account',
        syncTasks: () async => taskSyncCalls += 1,
        syncCalendar: () async => calendarSyncCalls += 1,
        nowUtc: () => DateTime.utc(2026, 6, 4),
      );
      await _enqueueBlockedOp(
        database,
        operation: 'patch_task',
        taskListId: 'list-1',
        taskId: 'task-1',
      );

      await coordinatedService.retryNow('op-1');

      expect(taskSyncCalls, 1);
      expect(calendarSyncCalls, 0);
    },
  );

  test('unknown-outcome task creation cannot be retried blindly', () async {
    await _enqueueBlockedOp(
      database,
      operation: 'create_task',
      taskListId: 'list-1',
      taskId: 'local-task-1',
      state: 'recovery_required',
    );

    await expectLater(
      service.retryNow('op-1'),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('cannot be retried safely'),
        ),
      ),
    );

    final pending = await database.pendingOpsDao.getOp('op-1');
    expect(pending!.state, 'recovery_required');
    expect(pending.nextAttemptAtUtc, startsWith('9999-12-31'));
    expect(taskSyncCalls, 0);
  });

  test(
    'discard uncertain task create removes dependent edit before replay',
    () async {
      const temporaryTaskId = 'local-task-1';
      await database.tasksDao.upsertTask(
        _localTask(temporaryTaskId, localDirty: true),
      );
      await _enqueueBlockedOp(
        database,
        id: 'create-task',
        operation: 'create_task',
        taskListId: 'list-1',
        taskId: temporaryTaskId,
        localTempId: temporaryTaskId,
        state: 'recovery_required',
        request: const {
          'body': {'title': 'Offline task'},
        },
      );
      await _enqueueBlockedOp(
        database,
        id: 'edit-task',
        operation: 'patch_task',
        taskListId: 'list-1',
        taskId: temporaryTaskId,
        dependsOnOpId: 'create-task',
        nextAttemptAtUtc: null,
        request: const {'title': 'Edited offline task'},
      );

      await service.discard('create-task');

      expect(await database.select(database.pendingOps).get(), isEmpty);
      expect(await database.tasksDao.listTasks('account', 'list-1'), isEmpty);
      expect(apiClient.getTaskIds, isEmpty);
      expect(taskSyncCalls, 1);

      final replayed = await PendingOpsReplayer(
        database: database,
        apiClient: apiClient,
        accountId: 'account',
        nowUtc: () => DateTime.utc(2026, 6, 4),
      ).replayDueOps();

      expect(replayed, 0);
      expect(apiClient.patchedTaskIds, isEmpty);
      expect(apiClient.getTaskIds, isEmpty);
    },
  );

  test(
    'discard uncertain task-list create removes its local chain before replay',
    () async {
      const temporaryTaskListId = 'local-tasklist-1';
      await database.taskListsDao.upsertTaskList(
        _localTaskList(
          temporaryTaskListId,
          title: 'Offline list',
          localDirty: true,
        ),
      );
      await database.tasksDao.upsertTask(
        _localTask(
          'local-child-task',
          taskListId: temporaryTaskListId,
          localDirty: true,
        ),
      );
      await _enqueueBlockedOp(
        database,
        id: 'create-list',
        entityType: 'task_list',
        operation: 'create_task_list',
        taskListId: temporaryTaskListId,
        localTempId: temporaryTaskListId,
        state: 'recovery_required',
        request: const {'title': 'Offline list'},
      );
      await _enqueueBlockedOp(
        database,
        id: 'edit-list',
        entityType: 'task_list',
        operation: 'patch_task_list',
        taskListId: temporaryTaskListId,
        dependsOnOpId: 'create-list',
        nextAttemptAtUtc: null,
        request: const {'title': 'Edited offline list'},
      );
      await _enqueueBlockedOp(
        database,
        id: 'create-child-task',
        operation: 'create_task',
        taskListId: temporaryTaskListId,
        taskId: 'local-child-task',
        localTempId: 'local-child-task',
        nextAttemptAtUtc: null,
        request: const {
          'body': {'title': 'Child task'},
        },
      );

      await service.discard('create-list');

      expect(await database.select(database.pendingOps).get(), isEmpty);
      expect(
        (await database.taskListsDao.listTaskLists(
          'account',
        )).map((taskList) => taskList.id),
        isNot(contains(temporaryTaskListId)),
      );
      expect(
        await database.tasksDao.listTasks('account', temporaryTaskListId),
        isEmpty,
      );
      expect(apiClient.getTaskListIds, isEmpty);
      expect(taskSyncCalls, 1);

      final replayed = await PendingOpsReplayer(
        database: database,
        apiClient: apiClient,
        accountId: 'account',
        nowUtc: () => DateTime.utc(2026, 6, 4),
      ).replayDueOps();

      expect(replayed, 0);
      expect(apiClient.patchedTaskListIds, isEmpty);
      expect(apiClient.createdTaskTaskListIds, isEmpty);
      expect(apiClient.getTaskListIds, isEmpty);
    },
  );

  test(
    'discard uncertain task-list create restores an old moved server task',
    () async {
      const temporaryTaskListId = 'local-tasklist-1';
      apiClient.remoteTask = TaskDto.fromJson(const {
        'id': 'existing-task',
        'title': 'Existing remote task',
        'updated': '2025-01-01T00:00:00.000Z',
      });
      await database.taskListsDao.upsertTaskList(
        _localTaskList(
          temporaryTaskListId,
          title: 'Offline list',
          localDirty: true,
        ),
      );
      await database.tasksDao.upsertTask(
        _localTask(
          'existing-task',
          taskListId: temporaryTaskListId,
          localDirty: true,
          pendingMove: true,
        ),
      );
      await _enqueueBlockedOp(
        database,
        id: 'create-list',
        entityType: 'task_list',
        operation: 'create_task_list',
        taskListId: temporaryTaskListId,
        localTempId: temporaryTaskListId,
        state: 'recovery_required',
        request: const {'title': 'Offline list'},
      );
      await _enqueueBlockedOp(
        database,
        id: 'move-existing-task',
        operation: 'move_task',
        taskListId: 'list-1',
        taskId: 'existing-task',
        request: const {'destinationTasklist': temporaryTaskListId},
      );

      await service.discard('create-list');

      final sourceTasks = await database.tasksDao.listTasks(
        'account',
        'list-1',
      );
      expect(sourceTasks, hasLength(1));
      expect(sourceTasks.single.title, 'Existing remote task');
      expect(sourceTasks.single.pendingMove, isFalse);
      expect(sourceTasks.single.localDirty, isFalse);
      expect(
        await database.tasksDao.listTasks('account', temporaryTaskListId),
        isEmpty,
      );
      expect(await database.select(database.pendingOps).get(), isEmpty);
      expect(apiClient.getTaskIds, ['existing-task']);
      expect(taskSyncCalls, 1);
    },
  );

  test(
    'discard uncertain checklist create removes its chain and merges all pages',
    () async {
      final localItems = [
        TaskChecklistItemEntity.fromJson(const {
          'id': 'local-step',
          'displayName': 'Uncertain',
          'isChecked': true,
        }),
        TaskChecklistItemEntity.fromJson(const {
          'id': 'server-sibling',
          'displayName': 'Sibling local edit',
          'isChecked': false,
        }),
      ];
      await database.tasksDao.upsertTask(
        _localTask(
          'task-1',
          localDirty: true,
          checklistItemsJson: encodeTaskChecklistItems(localItems),
        ),
      );
      apiClient.checklistPages = {
        null: const TaskChecklistItemsPageDto(
          items: [
            TaskChecklistItemDto(
              id: 'server-created',
              title: 'Uncertain',
              completed: false,
              rawJson: {},
            ),
          ],
          nextPageToken: 'page-2',
          rawJson: {},
        ),
        'page-2': const TaskChecklistItemsPageDto(
          items: [
            TaskChecklistItemDto(
              id: 'server-sibling',
              title: 'Sibling remote',
              completed: false,
              rawJson: {},
            ),
          ],
          rawJson: {},
        ),
      };
      await _enqueueBlockedOp(
        database,
        id: 'create-step',
        entityType: 'task_checklist_item',
        operation: 'create_task_checklist_item',
        taskListId: 'list-1',
        taskId: 'task-1',
        localTempId: 'local-step',
        state: 'recovery_required',
        request: const {
          'checklistItemId': 'local-step',
          'body': {'displayName': 'Uncertain', 'isChecked': false},
        },
      );
      await _enqueueBlockedOp(
        database,
        id: 'patch-step',
        entityType: 'task_checklist_item',
        operation: 'patch_task_checklist_item',
        taskListId: 'list-1',
        taskId: 'task-1',
        dependsOnOpId: 'create-step',
        request: const {
          'checklistItemId': 'local-step',
          'body': {'isChecked': true},
        },
      );
      await _enqueueBlockedOp(
        database,
        id: 'sibling-step',
        entityType: 'task_checklist_item',
        operation: 'patch_task_checklist_item',
        taskListId: 'list-1',
        taskId: 'task-1',
        request: const {
          'checklistItemId': 'server-sibling',
          'body': {'displayName': 'Sibling local edit'},
        },
      );

      await service.discard('create-step');

      expect(apiClient.checklistPageTokens, [null, 'page-2']);
      expect(await database.pendingOpsDao.getOp('create-step'), equals(null));
      expect(await database.pendingOpsDao.getOp('patch-step'), equals(null));
      expect(
        await database.pendingOpsDao.getOp('sibling-step'),
        isNot(equals(null)),
      );
      final parent = (await database.tasksDao.listTasks(
        'account',
        'list-1',
      )).single;
      expect(parent.title, 'Local task');
      expect(parent.localDirty, isTrue);
      final items = decodeTaskChecklistItems(
        parent.microsoftChecklistItemsJson,
      );
      expect(items.map((item) => item.id), [
        'server-created',
        'server-sibling',
      ]);
      expect(
        items.singleWhere((item) => item.id == 'server-sibling').title,
        'Sibling local edit',
      );
      expect(taskSyncCalls, 1);

      await service.discard('create-step');
      expect(apiClient.checklistPageTokens, [null, 'page-2']);
      expect(taskSyncCalls, 1);
    },
  );

  test(
    'failed checklist read keeps recovery operation and projection intact',
    () async {
      final projection = encodeTaskChecklistItems([
        TaskChecklistItemEntity.fromJson(const {
          'id': 'local-step',
          'displayName': 'Uncertain',
          'isChecked': false,
        }),
      ]);
      await database.tasksDao.upsertTask(
        _localTask('task-1', checklistItemsJson: projection),
      );
      apiClient.checklistError = const GoogleTasksApiError(
        statusCode: 503,
        message: 'Unavailable',
      );
      await _enqueueBlockedOp(
        database,
        id: 'create-step',
        entityType: 'task_checklist_item',
        operation: 'create_task_checklist_item',
        taskListId: 'list-1',
        taskId: 'task-1',
        localTempId: 'local-step',
        state: 'recovery_required',
        request: const {'checklistItemId': 'local-step'},
      );

      await expectLater(
        service.discard('create-step'),
        throwsA(isA<GoogleTasksApiError>()),
      );
      expect(
        await database.pendingOpsDao.getOp('create-step'),
        isNot(equals(null)),
      );
      expect(
        (await database.tasksDao.listTasks(
          'account',
          'list-1',
        )).single.microsoftChecklistItemsJson,
        projection,
      );
      expect(taskSyncCalls, 0);
    },
  );

  test(
    'discard when no checklist item was created removes only the exact account chain',
    () async {
      final localProjection = encodeTaskChecklistItems([
        TaskChecklistItemEntity.fromJson(const {
          'id': 'local-step',
          'displayName': 'Uncertain',
          'isChecked': true,
        }),
      ]);
      await database.tasksDao.upsertTask(
        _localTask('task-1', checklistItemsJson: localProjection),
      );
      await _enqueueBlockedOp(
        database,
        id: 'create-step',
        entityType: 'task_checklist_item',
        operation: 'create_task_checklist_item',
        taskListId: 'list-1',
        taskId: 'task-1',
        localTempId: 'local-step',
        state: 'recovery_required',
        request: const {'checklistItemId': 'local-step'},
      );
      await _enqueueBlockedOp(
        database,
        id: 'patch-step',
        entityType: 'task_checklist_item',
        operation: 'patch_task_checklist_item',
        taskListId: 'list-1',
        taskId: 'task-1',
        dependsOnOpId: 'create-step',
        request: const {
          'checklistItemId': 'local-step',
          'body': {'isChecked': true},
        },
      );

      await _insertAccount(database, accountId: 'other');
      await database.taskListsDao.upsertTaskList(
        _localTaskList('list-1', accountId: 'other'),
      );
      await database.tasksDao.upsertTask(
        _localTask(
          'task-1',
          accountId: 'other',
          checklistItemsJson: localProjection,
        ),
      );
      await _enqueueBlockedOp(
        database,
        id: 'other-create-step',
        accountId: 'other',
        entityType: 'task_checklist_item',
        operation: 'create_task_checklist_item',
        taskListId: 'list-1',
        taskId: 'task-1',
        localTempId: 'local-step',
        state: 'recovery_required',
        request: const {'checklistItemId': 'local-step'},
      );

      await service.discard('create-step');

      expect(apiClient.checklistPageTokens, [null]);
      expect(
        decodeTaskChecklistItems(
          (await database.tasksDao.listTasks(
            'account',
            'list-1',
          )).single.microsoftChecklistItemsJson,
        ),
        isEmpty,
      );
      expect(await database.pendingOpsDao.getOp('create-step'), equals(null));
      expect(await database.pendingOpsDao.getOp('patch-step'), equals(null));
      expect(
        await database.pendingOpsDao.getOp('other-create-step'),
        isNot(equals(null)),
      );
      expect(
        decodeTaskChecklistItems(
          (await database.tasksDao.listTasks(
            'other',
            'list-1',
          )).single.microsoftChecklistItemsJson,
        ).single.id,
        'local-step',
      );
    },
  );

  test('checklist discard remains serialized with replay', () async {
    final started = Completer<void>();
    final gate = Completer<void>();
    apiClient
      ..checklistReadStarted = started
      ..checklistReadGate = gate;
    await database.tasksDao.upsertTask(
      _localTask(
        'task-1',
        checklistItemsJson: encodeTaskChecklistItems([
          TaskChecklistItemEntity.fromJson(const {
            'id': 'local-step',
            'displayName': 'Uncertain',
            'isChecked': false,
          }),
        ]),
      ),
    );
    await _enqueueBlockedOp(
      database,
      id: 'create-step',
      entityType: 'task_checklist_item',
      operation: 'create_task_checklist_item',
      taskListId: 'list-1',
      taskId: 'task-1',
      localTempId: 'local-step',
      state: 'recovery_required',
      request: const {'checklistItemId': 'local-step'},
    );

    final discard = service.discard('create-step');
    await started.future;
    var replayCompleted = false;
    final replay =
        PendingOpsReplayer(
          database: database,
          apiClient: apiClient,
          accountId: 'account',
          nowUtc: () => DateTime.utc(2026, 6, 4),
        ).replayDueOps().then((value) {
          replayCompleted = true;
          return value;
        });
    await Future<void>.delayed(Duration.zero);
    expect(replayCompleted, isFalse);

    gate.complete();
    await discard;
    expect(await replay, 0);
    expect(await database.pendingOpsDao.getOp('create-step'), equals(null));
  });

  test(
    'retry routes event synchronization through the calendar callback',
    () async {
      var taskSyncCalls = 0;
      final coordinatedService = PendingOpResolutionService(
        database: database,
        accountId: 'account',
        syncTasks: () async => taskSyncCalls += 1,
        syncCalendar: () async => calendarSyncCalls += 1,
        nowUtc: () => DateTime.utc(2026, 6, 4),
      );
      await _enqueueBlockedOp(
        database,
        entityType: 'event',
        operation: 'patch',
        operationType: 'event.patch',
      );

      await coordinatedService.retryNow('op-1');

      expect(calendarSyncCalls, 1);
      expect(taskSyncCalls, 0);
    },
  );
}

class _FakeTaskRemoteClient
    implements TaskRemoteClient, TaskChecklistRemoteClient {
  TaskDto? remoteTask;
  TaskListDto? remoteTaskList;
  GoogleTasksApiError? getTaskError;
  GoogleTasksApiError? getTaskListError;
  GoogleTasksApiError? checklistError;
  Map<String?, TaskChecklistItemsPageDto> checklistPages = const {};
  final checklistPageTokens = <String?>[];
  final getTaskIds = <String>[];
  final getTaskListIds = <String>[];
  final patchedTaskIds = <String>[];
  final patchedTaskListIds = <String>[];
  final createdTaskTaskListIds = <String>[];
  Completer<void>? checklistReadStarted;
  Completer<void>? checklistReadGate;

  @override
  Future<TaskChecklistItemsPageDto> listChecklistItemsPage({
    required String taskListId,
    required String taskId,
    String? pageToken,
  }) async {
    checklistPageTokens.add(pageToken);
    if (checklistReadStarted?.isCompleted == false) {
      checklistReadStarted!.complete();
    }
    await checklistReadGate?.future;
    final error = checklistError;
    if (error != null) throw error;
    return checklistPages[pageToken] ??
        const TaskChecklistItemsPageDto(items: [], rawJson: {});
  }

  @override
  Future<TaskDto> getTask({
    required String taskListId,
    required String taskId,
  }) async {
    getTaskIds.add(taskId);
    final error = getTaskError;
    if (error != null) {
      throw error;
    }
    return remoteTask ?? _taskDto(taskId);
  }

  @override
  Future<TaskListDto> getTaskList(String taskListId) async {
    getTaskListIds.add(taskListId);
    final error = getTaskListError;
    if (error != null) {
      throw error;
    }
    return remoteTaskList ?? _taskListDto(taskListId);
  }

  @override
  Future<TaskDto> patchTask({
    required String taskListId,
    required String taskId,
    required TaskPatch patch,
  }) async {
    patchedTaskIds.add(taskId);
    return _taskDto(taskId, title: patch.fields['title']?.toString() ?? 'Task');
  }

  @override
  Future<TaskListDto> patchTaskList(
    String taskListId,
    TaskListPatch patch,
  ) async {
    patchedTaskListIds.add(taskListId);
    return _taskListDto(
      taskListId,
      title: patch.fields['title']?.toString() ?? 'List',
    );
  }

  @override
  Future<TaskDto> createTask({
    required String taskListId,
    String? parentTaskId,
    String? previousSiblingTaskId,
    required TaskCreate create,
  }) async {
    createdTaskTaskListIds.add(taskListId);
    return _taskDto(
      'created-task',
      title: create.fields['title']?.toString() ?? 'Task',
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> _insertAccount(
  AppDatabase database, {
  String accountId = 'account',
}) {
  return database
      .into(database.accounts)
      .insert(
        AccountsCompanion.insert(
          id: accountId,
          provider: 'google',
          authority: 'https://accounts.google.com',
          providerAccountId: 'google-$accountId',
          credentialKind: 'oauth',
          email: Value('google-$accountId@example.com'),
          createdAtUtc: _now,
          updatedAtUtc: _now,
        ),
      );
}

CalendarRepository _calendarRepository(AppDatabase database) {
  return CalendarRepository(
    database: database,
    now: () => DateTime.utc(2026, 6, 4),
  );
}

Future<void> _blockOperation(AppDatabase database, String operationId) {
  return database.pendingOpsDao.updateAttempt(
    id: operationId,
    attemptCount: 1,
    nextAttemptAtUtc: DateTime.utc(9999, 12, 31),
    lastErrorCode: 'provider_rejected',
    lastErrorMessage: 'Provider rejected the operation.',
  );
}

TaskListsCompanion _localTaskList(
  String id, {
  String accountId = 'account',
  String title = 'List',
  bool localDirty = false,
  bool pendingDelete = false,
}) {
  return TaskListsCompanion.insert(
    accountId: accountId,
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
  String accountId = 'account',
  String taskListId = 'list-1',
  bool localDirty = false,
  bool pendingDelete = false,
  bool pendingMove = false,
  String? checklistItemsJson,
}) {
  return TasksCompanion.insert(
    accountId: accountId,
    taskListId: taskListId,
    id: id,
    title: 'Local task',
    rawJson: '{"id":"$id","title":"Local task"}',
    localDirty: Value(localDirty),
    pendingDelete: Value(pendingDelete),
    pendingMove: Value(pendingMove),
    microsoftChecklistItemsJson: Value(checklistItemsJson),
    createdLocalAtUtc: _now,
    updatedLocalAtUtc: _now,
  );
}

Future<void> _enqueueBlockedOp(
  AppDatabase database, {
  String id = 'op-1',
  String accountId = 'account',
  String entityType = 'task',
  required String operation,
  String? operationType,
  String? taskListId,
  String? taskId,
  String? calendarSourceId,
  String state = 'pending',
  String? localTempId,
  String? dependsOnOpId,
  String? nextAttemptAtUtc = '9999-12-31T00:00:00.000Z',
  Map<String, Object?> request = const {},
}) {
  return database.pendingOpsDao.enqueue(
    PendingOpsCompanion.insert(
      id: id,
      accountId: accountId,
      entityType: entityType,
      operation: operation,
      operationType: Value(operationType),
      taskListId: Value(taskListId),
      taskId: Value(taskId),
      localTempId: Value(localTempId),
      dependsOnOpId: Value(dependsOnOpId),
      calendarSourceId: Value(calendarSourceId),
      requestJson: jsonEncode(request),
      state: Value(state),
      nextAttemptAtUtc: Value(nextAttemptAtUtc),
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

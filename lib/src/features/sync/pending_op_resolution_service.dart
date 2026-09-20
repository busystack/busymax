import 'dart:convert';

import 'package:drift/drift.dart';

import '../../calendar_providers/cloud_calendar_client.dart';
import '../../dav/mutation/dav_pending_operation_selection.dart';
import '../../dav/mutation/dav_pending_operations.dart';
import '../../db/app_database.dart';
import '../calendar/data/calendar_repository.dart';
import '../notifications/notification_schedule_service.dart';
import '../task_lists/data/task_lists_repository.dart';
import '../tasks/data/tasks_repository.dart';
import '../tasks/domain/task_remote_client.dart';
import '../tasks/domain/task_remote_error.dart';
import '../tasks/domain/task_checklist_item.dart';
import '../tasks/domain/task_remote_models.dart';
import 'pending_ops_replay_coordinator.dart';

class PendingOpResolutionService {
  PendingOpResolutionService({
    required AppDatabase database,
    TaskRemoteClient? apiClient,
    CloudCalendarClient? calendarClient,
    required String accountId,
    required Future<void> Function() syncTasks,
    required Future<void> Function() syncCalendar,
    Future<void> Function()? onNotificationScheduleChanged,
    DateTime Function()? nowUtc,
  }) : _database = database,
       _apiClient = apiClient,
       _calendarClient = calendarClient,
       _accountId = accountId,
       _syncTasks = syncTasks,
       _syncCalendar = syncCalendar,
       _onNotificationScheduleChanged = onNotificationScheduleChanged,
       _nowUtc = nowUtc ?? (() => DateTime.now().toUtc());

  final AppDatabase _database;
  final TaskRemoteClient? _apiClient;
  final CloudCalendarClient? _calendarClient;
  final String _accountId;
  final Future<void> Function() _syncTasks;
  final Future<void> Function() _syncCalendar;
  final Future<void> Function()? _onNotificationScheduleChanged;
  final DateTime Function() _nowUtc;

  Future<void> retryNow(String opId) async {
    final op = await _database.pendingOpsDao.getOp(opId);
    if (op == null) return;
    _requireOwnedOperation(op);
    if (op.state == 'recovery_required' && _isCreationOperation(op)) {
      throw StateError(
        'This creation cannot be retried safely because the provider may '
        'already have created the item. Check the provider, then discard this '
        'operation or resolve the duplicate manually.',
      );
    }
    if (isDavPendingOperation(op)) {
      await DavPendingOperationQueue(
        database: _database,
        nowUtc: _nowUtc,
      ).retryBlockedOperation(accountId: _accountId, operationId: op.id);
    } else {
      await _database.pendingOpsDao.retryNow(opId, _nowUtc());
    }
    await _syncAfterResolution(op);
  }

  bool _isCreationOperation(PendingOp op) {
    return op.operation == 'create_task_list' ||
        op.operation == 'create_task' ||
        op.operation == 'create_task_checklist_item' ||
        op.operationType == 'calendar.create' ||
        (op.entityType == 'calendar' && op.operation == 'create');
  }

  Future<void> discard(String opId) async {
    final op = await _database.pendingOpsDao.getOp(opId);
    if (op == null) {
      return;
    }
    _requireOwnedOperation(op);

    if (isDavPendingOperation(op)) {
      final partiallyCompletedMove = isDavPartiallyCompletedMove(op);
      final reconciliationStartedAtUtc = partiallyCompletedMove
          ? _nowUtc().toUtc()
          : null;
      if (partiallyCompletedMove) await _syncAfterResolution(op);
      final syncAfterDiscard =
          await DavPendingOperationQueue(
            database: _database,
            nowUtc: _nowUtc,
          ).discardBlockedOperation(
            accountId: _accountId,
            operationId: op.id,
            partialMoveReconciledAfterUtc: reconciliationStartedAtUtc,
          );
      await _rebuildNotificationSchedule();
      if (syncAfterDiscard && !partiallyCompletedMove) {
        await _syncAfterResolution(op);
      }
      return;
    }

    final isTaskOperation =
        op.entityType == 'task' ||
        op.entityType == 'task_list' ||
        op.entityType == 'task_checklist_item';
    final syncAfterDiscard = isTaskOperation
        ? await serializePendingOpsReplay(
            database: _database,
            accountId: _accountId,
            replay: () => _discardTaskOperation(op.id),
          )
        : await _discardUncoordinatedOperation(op);
    if (syncAfterDiscard) {
      // Synchronization uses the same non-reentrant account coordinator. The
      // callback must run only after the discard critical section is released.
      await _syncAfterResolution(op);
    }
  }

  Future<bool> _discardUncoordinatedOperation(PendingOp op) async {
    final syncAfterDiscard = await _refreshOrRemoveLocalState(op);
    await _database.pendingOpsDao.deleteOp(op.id);
    return syncAfterDiscard;
  }

  Future<bool> _discardTaskOperation(String opId) async {
    final current = await _database.pendingOpsDao.getOp(opId);
    if (current == null) return false;
    _requireOwnedOperation(current);
    if (current.operation == 'create_task_checklist_item') {
      return _discardUncertainChecklistCreation(current);
    }
    if (current.operation == 'create_task') {
      return _discardTaskCreation(current);
    }
    if (current.operation == 'create_task_list') {
      return _discardTaskListCreation(current);
    }
    final discardedIds = current.operation == 'move_task'
        ? await _dependentTaskOperationIds(current.id)
        : {current.id};
    if (current.operation == 'move_task') {
      return _discardMoveAndDependents(current, discardedIds);
    }
    final syncAfterDiscard = await _refreshOrRemoveLocalState(current);
    await (_database.delete(
      _database.pendingOps,
    )..where((row) => row.id.isIn(discardedIds))).go();
    return syncAfterDiscard;
  }

  Future<bool> _discardTaskCreation(PendingOp snapshot) async {
    final temporaryTaskId = snapshot.localTempId ?? snapshot.taskId;
    if (snapshot.taskListId == null ||
        temporaryTaskId == null ||
        temporaryTaskId.isEmpty) {
      throw StateError('The task creation recovery operation is incomplete.');
    }

    var discarded = false;
    await _database.transaction(() async {
      final current = await _database.pendingOpsDao.getOp(snapshot.id);
      if (current == null) return;
      if (current.accountId != _accountId ||
          current.operation != 'create_task' ||
          current.taskListId != snapshot.taskListId ||
          (current.localTempId ?? current.taskId) != temporaryTaskId) {
        throw StateError('The task creation recovery operation changed.');
      }

      final operations = await (_database.select(
        _database.pendingOps,
      )..where((row) => row.accountId.equals(_accountId))).get();
      final discardedIds = <String>{current.id};
      final discardedTaskIds = <String>{temporaryTaskId};
      var expanded = true;
      while (expanded) {
        expanded = false;
        for (final operation in operations) {
          if (discardedIds.contains(operation.id)) continue;
          final targetsDiscardedTask =
              (operation.entityType == 'task' ||
                  operation.entityType == 'task_checklist_item') &&
              (discardedTaskIds.contains(operation.taskId) ||
                  discardedTaskIds.contains(operation.localTempId));
          if (!targetsDiscardedTask &&
              !discardedIds.contains(operation.dependsOnOpId)) {
            continue;
          }
          discardedIds.add(operation.id);
          if (operation.operation == 'create_task') {
            final createdTaskId = operation.localTempId ?? operation.taskId;
            if (createdTaskId != null && discardedTaskIds.add(createdTaskId)) {
              expanded = true;
            }
          }
          expanded = true;
        }
      }

      await (_database.delete(
        _database.pendingOps,
      )..where((row) => row.id.isIn(discardedIds))).go();
      await (_database.delete(_database.tasks)..where(
            (row) =>
                row.accountId.equals(_accountId) &
                row.id.isIn(discardedTaskIds),
          ))
          .go();
      discarded = true;
    });
    return discarded;
  }

  Future<bool> _discardTaskListCreation(PendingOp snapshot) async {
    final temporaryTaskListId = snapshot.localTempId ?? snapshot.taskListId;
    if (temporaryTaskListId == null || temporaryTaskListId.isEmpty) {
      throw StateError(
        'The task-list creation recovery operation is incomplete.',
      );
    }

    final operations = await (_database.select(
      _database.pendingOps,
    )..where((row) => row.accountId.equals(_accountId))).get();
    final discardedIds = _taskListCreationDiscardedOperationIds(
      operations,
      rootOperationId: snapshot.id,
      temporaryTaskListId: temporaryTaskListId,
    );
    final locallyCreatedTaskIds = {
      for (final operation in operations)
        if (discardedIds.contains(operation.id) &&
            operation.operation == 'create_task')
          operation.localTempId ?? operation.taskId,
    }..remove(null);
    final movedServerTasks = <String, _MovedTaskRestoration>{};
    for (final operation in operations) {
      final taskId = operation.taskId;
      if (!discardedIds.contains(operation.id) ||
          operation.operation != 'move_task' ||
          taskId == null ||
          locallyCreatedTaskIds.contains(taskId) ||
          operation.taskListId == temporaryTaskListId ||
          _destinationTaskListId(operation) != temporaryTaskListId) {
        continue;
      }
      TaskDto? serverTask;
      try {
        serverTask = await _requiredTaskClient.getTask(
          taskListId: operation.taskListId!,
          taskId: taskId,
        );
      } on TaskRemoteError catch (error) {
        if (error.statusCode != 404) rethrow;
      }
      movedServerTasks[taskId] = _MovedTaskRestoration(
        sourceTaskListId: operation.taskListId!,
        serverTask: serverTask,
        discardedDestinationTaskListIds: {
          temporaryTaskListId,
          for (final discardedOperation in operations)
            if (discardedIds.contains(discardedOperation.id) &&
                discardedOperation.operation == 'move_task' &&
                discardedOperation.taskId == taskId &&
                _destinationTaskListId(discardedOperation) != null)
              _destinationTaskListId(discardedOperation)!,
        },
      );
    }

    var discarded = false;
    await _database.transaction(() async {
      final current = await _database.pendingOpsDao.getOp(snapshot.id);
      if (current == null) return;
      if (current.accountId != _accountId ||
          current.operation != 'create_task_list' ||
          (current.localTempId ?? current.taskListId) != temporaryTaskListId) {
        throw StateError('The task-list creation recovery operation changed.');
      }

      final currentOperations = await (_database.select(
        _database.pendingOps,
      )..where((row) => row.accountId.equals(_accountId))).get();
      final currentDiscardedIds = _taskListCreationDiscardedOperationIds(
        currentOperations,
        rootOperationId: current.id,
        temporaryTaskListId: temporaryTaskListId,
      );
      if (discardedIds.length != currentDiscardedIds.length ||
          !discardedIds.containsAll(currentDiscardedIds)) {
        throw StateError('The task-list creation recovery operation changed.');
      }

      await (_database.delete(
        _database.pendingOps,
      )..where((row) => row.id.isIn(currentDiscardedIds))).go();
      if (locallyCreatedTaskIds.isNotEmpty) {
        await (_database.delete(_database.tasks)..where(
              (row) =>
                  row.accountId.equals(_accountId) &
                  row.id.isIn(locallyCreatedTaskIds.cast<String>()),
            ))
            .go();
      }
      for (final MapEntry(key: taskId, value: restoration)
          in movedServerTasks.entries) {
        final taskListIdsToRemove = {
          ...restoration.discardedDestinationTaskListIds,
          if (restoration.serverTask == null) restoration.sourceTaskListId,
        };
        await (_database.delete(_database.tasks)..where(
              (row) =>
                  row.accountId.equals(_accountId) &
                  row.id.equals(taskId) &
                  row.taskListId.isIn(taskListIdsToRemove),
            ))
            .go();
        final serverTask = restoration.serverTask;
        if (serverTask != null) {
          await _database.tasksDao.upsertTask(
            taskFromDto(
              _accountId,
              restoration.sourceTaskListId,
              serverTask,
              _now(),
            ),
          );
        }
      }
      await _database.taskListsDao.deleteTaskList(
        _accountId,
        temporaryTaskListId,
      );
      discarded = true;
    });
    return discarded;
  }

  Set<String> _taskListCreationDiscardedOperationIds(
    List<PendingOp> operations, {
    required String rootOperationId,
    required String temporaryTaskListId,
  }) {
    final discardedIds = <String>{rootOperationId};
    var expanded = true;
    while (expanded) {
      expanded = false;
      for (final operation in operations) {
        if (discardedIds.contains(operation.id)) continue;
        final targetsDiscardedTaskList =
            operation.taskListId == temporaryTaskListId ||
            operation.localTempId == temporaryTaskListId ||
            (operation.operation == 'move_task' &&
                _destinationTaskListId(operation) == temporaryTaskListId);
        if (!targetsDiscardedTaskList &&
            !discardedIds.contains(operation.dependsOnOpId)) {
          continue;
        }
        discardedIds.add(operation.id);
        expanded = true;
      }
    }
    return discardedIds;
  }

  Future<Set<String>> _dependentTaskOperationIds(String rootId) async {
    final operations = await (_database.select(
      _database.pendingOps,
    )..where((row) => row.accountId.equals(_accountId))).get();
    final discarded = <String>{rootId};
    var changed = true;
    while (changed) {
      changed = false;
      for (final operation in operations) {
        if (discarded.contains(operation.id) ||
            !discarded.contains(operation.dependsOnOpId)) {
          continue;
        }
        discarded.add(operation.id);
        changed = true;
      }
    }
    return discarded;
  }

  Future<bool> _discardMoveAndDependents(
    PendingOp operation,
    Set<String> discardedIds,
  ) async {
    final sourceTaskListId = operation.taskListId!;
    final taskId = operation.taskId!;
    final discardedOperations = await (_database.select(
      _database.pendingOps,
    )..where((row) => row.id.isIn(discardedIds))).get();
    final destinationTaskListIds =
        {
          for (final discarded in discardedOperations)
            if (discarded.operation == 'move_task')
              _destinationTaskListId(discarded),
        }..removeWhere(
          (destination) =>
              destination == null || destination == sourceTaskListId,
        );
    TaskDto? serverTask;
    try {
      serverTask = await _requiredTaskClient.getTask(
        taskListId: sourceTaskListId,
        taskId: taskId,
      );
    } on TaskRemoteError catch (error) {
      if (error.statusCode != 404) rethrow;
    }

    await _database.transaction(() async {
      if (serverTask == null) {
        await _database.tasksDao.deleteTask(
          _accountId,
          sourceTaskListId,
          taskId,
        );
      } else {
        await _database.tasksDao.upsertTask(
          taskFromDto(_accountId, sourceTaskListId, serverTask, _now()),
        );
      }
      if (destinationTaskListIds.isNotEmpty) {
        await (_database.delete(_database.tasks)..where(
              (row) =>
                  row.accountId.equals(_accountId) &
                  row.id.equals(taskId) &
                  row.taskListId.isIn(destinationTaskListIds.cast<String>()),
            ))
            .go();
      }
      await (_database.delete(
        _database.pendingOps,
      )..where((row) => row.id.isIn(discardedIds))).go();
    });
    return true;
  }

  Future<bool> _discardUncertainChecklistCreation(PendingOp snapshot) async {
    final taskListId = snapshot.taskListId;
    final parentTaskId = snapshot.taskId;
    final temporaryItemId = _checklistItemId(snapshot);
    if (taskListId == null ||
        parentTaskId == null ||
        temporaryItemId == null ||
        temporaryItemId.isEmpty) {
      throw StateError('The checklist recovery operation is incomplete.');
    }

    final client = _requiredChecklistClient;
    final serverItems = <TaskChecklistItemDto>[];
    var parentMissing = false;
    String? pageToken;
    try {
      do {
        final page = await client.listChecklistItemsPage(
          taskListId: taskListId,
          taskId: parentTaskId,
          pageToken: pageToken,
        );
        serverItems.addAll(page.items);
        pageToken = page.nextPageToken;
      } while (pageToken != null && pageToken.isNotEmpty);
    } on TaskRemoteError catch (error) {
      if (error.statusCode != 404) rethrow;
      parentMissing = true;
    }

    var discarded = false;
    await _database.transaction(() async {
      final current = await _database.pendingOpsDao.getOp(snapshot.id);
      if (current == null) return;
      if (current.accountId != _accountId ||
          current.operation != 'create_task_checklist_item' ||
          current.taskListId != taskListId ||
          current.taskId != parentTaskId ||
          _checklistItemId(current) != temporaryItemId) {
        throw StateError('The checklist recovery operation changed.');
      }

      final operations =
          await (_database.select(_database.pendingOps)
                ..where(
                  (row) =>
                      row.accountId.equals(_accountId) &
                      row.entityType.equals('task_checklist_item') &
                      row.taskListId.equals(taskListId) &
                      row.taskId.equals(parentTaskId),
                )
                ..orderBy([
                  (row) => OrderingTerm.asc(row.createdAtUtc),
                  (row) => OrderingTerm.asc(row.updatedAtUtc),
                  (row) => OrderingTerm.asc(row.id),
                ]))
              .get();
      final discardedIds = <String>{current.id};
      var expanded = true;
      while (expanded) {
        expanded = false;
        for (final operation in operations) {
          if (discardedIds.contains(operation.id)) continue;
          if (discardedIds.contains(operation.dependsOnOpId) ||
              _checklistItemId(operation) == temporaryItemId) {
            discardedIds.add(operation.id);
            expanded = true;
          }
        }
      }
      final remaining = [
        for (final operation in operations)
          if (!discardedIds.contains(operation.id)) operation,
      ];

      if (parentMissing) {
        await _database.tasksDao.deleteTask(
          _accountId,
          taskListId,
          parentTaskId,
        );
      } else {
        final task =
            await (_database.select(_database.tasks)..where(
                  (row) =>
                      row.accountId.equals(_accountId) &
                      row.taskListId.equals(taskListId) &
                      row.id.equals(parentTaskId),
                ))
                .getSingleOrNull();
        if (task != null) {
          final localItems = decodeTaskChecklistItems(
            task.microsoftChecklistItemsJson,
          ).where((item) => item.id != temporaryItemId);
          final merged = mergeTaskChecklistProjection(
            serverItems: serverItems,
            localItems: localItems,
            pendingOperations: remaining,
          );
          await (_database.update(_database.tasks)..where(
                (row) =>
                    row.accountId.equals(_accountId) &
                    row.taskListId.equals(taskListId) &
                    row.id.equals(parentTaskId),
              ))
              .write(
                TasksCompanion(
                  microsoftChecklistItemsJson: Value(
                    encodeTaskChecklistItems(merged),
                  ),
                  updatedLocalAtUtc: Value(_now()),
                ),
              );
        }
      }
      await (_database.delete(
        _database.pendingOps,
      )..where((row) => row.id.isIn(discardedIds))).go();
      discarded = true;
    });
    return discarded;
  }

  Future<bool> _refreshOrRemoveLocalState(PendingOp op) async {
    if (op.entityType == 'calendar') {
      final repository = CalendarRepository(database: _database, now: _nowUtc);
      switch (_operationType(op)) {
        case 'calendar.create':
          await repository.discardPendingCalendarCreation(op);
          return false;
        case 'calendar.delete' || 'calendar.remove':
          await repository.restoreSourceAfterRemovalFailure(op);
          return true;
        case 'calendar.patch':
          await repository.restoreSourceAfterPatchDiscard(op);
          return true;
      }
      return false;
    }

    if (op.entityType == 'event') {
      final repository = CalendarRepository(database: _database, now: _nowUtc);
      if (_operationType(op) == 'event.create') {
        await repository.discardPendingEventCreation(op);
        return false;
      }
      await repository.restoreEventAfterMutationDiscard(
        op,
        fetchProviderEvent: _calendarClient == null
            ? null
            : ({required calendarId, required eventId}) => _calendarClient
                  .getEvent(calendarId: calendarId, eventId: eventId),
      );
      return true;
    }

    if (op.entityType == 'task' && op.taskListId != null && op.taskId != null) {
      if (op.operation == 'move_task') {
        await _refreshOrRemoveMovedTask(op);
        return true;
      }
      await _refreshOrRemoveTask(op.taskListId!, op.taskId!);
      return true;
    }

    if (op.entityType == 'task_list' && op.taskListId != null) {
      await _refreshOrRemoveTaskList(op.taskListId!);
      return true;
    }
    return false;
  }

  Future<void> _syncAfterResolution(PendingOp op) async {
    if (op.entityType == 'calendar' || op.entityType == 'event') {
      await _syncCalendar();
      return;
    }
    await _syncTasks();
  }

  Future<void> _rebuildNotificationSchedule() async {
    await NotificationScheduleService(
      database: _database,
      nowUtc: _nowUtc,
    ).rebuildUpcomingNotifications(_accountId);
    await _onNotificationScheduleChanged?.call();
  }

  TaskRemoteClient get _requiredTaskClient {
    return _apiClient ??
        (throw StateError('Task operation recovery is unavailable.'));
  }

  TaskChecklistRemoteClient get _requiredChecklistClient {
    final client = _requiredTaskClient;
    if (client is TaskChecklistRemoteClient) {
      return client as TaskChecklistRemoteClient;
    }
    throw StateError('Checklist operation recovery is unavailable.');
  }

  String? _checklistItemId(PendingOp op) {
    try {
      final request = (jsonDecode(op.requestJson) as Map)
          .cast<String, Object?>();
      return request['checklistItemId']?.toString() ?? op.localTempId;
    } on Object {
      return op.localTempId;
    }
  }

  Future<void> _refreshOrRemoveMovedTask(PendingOp op) async {
    final sourceTaskListId = op.taskListId!;
    final taskId = op.taskId!;
    final destinationTaskListId = _destinationTaskListId(op);

    try {
      final dto = await _requiredTaskClient.getTask(
        taskListId: sourceTaskListId,
        taskId: taskId,
      );
      await _database.tasksDao.upsertTask(
        taskFromDto(_accountId, sourceTaskListId, dto, _now()),
      );
      if (destinationTaskListId != null &&
          destinationTaskListId != sourceTaskListId) {
        await _database.tasksDao.deleteTask(
          _accountId,
          destinationTaskListId,
          taskId,
        );
      }
    } on TaskRemoteError catch (error) {
      if (error.statusCode != 404) {
        rethrow;
      }
      await _database.tasksDao.deleteTask(_accountId, sourceTaskListId, taskId);
      if (destinationTaskListId != null &&
          destinationTaskListId != sourceTaskListId) {
        await _database.tasksDao.deleteTask(
          _accountId,
          destinationTaskListId,
          taskId,
        );
      }
    }
  }

  Future<void> _refreshOrRemoveTask(String taskListId, String taskId) async {
    try {
      final dto = await _requiredTaskClient.getTask(
        taskListId: taskListId,
        taskId: taskId,
      );
      await _database.tasksDao.upsertTask(
        taskFromDto(_accountId, taskListId, dto, _now()),
      );
    } on TaskRemoteError catch (error) {
      if (error.statusCode != 404) {
        rethrow;
      }
      await _database.tasksDao.deleteTask(_accountId, taskListId, taskId);
    }
  }

  Future<void> _refreshOrRemoveTaskList(String taskListId) async {
    try {
      final dto = await _requiredTaskClient.getTaskList(taskListId);
      await _database.taskListsDao.upsertTaskList(
        taskListFromDto(_accountId, dto, _now()),
      );
    } on TaskRemoteError catch (error) {
      if (error.statusCode != 404) {
        rethrow;
      }
      await _database.taskListsDao.deleteTaskList(_accountId, taskListId);
    }
  }

  String? _destinationTaskListId(PendingOp op) {
    final request = (jsonDecode(op.requestJson) as Map).cast<String, Object?>();
    return request['destinationTasklist']?.toString();
  }

  String _operationType(PendingOp op) {
    return op.operationType ?? '${op.entityType}.${op.operation}';
  }

  void _requireOwnedOperation(PendingOp op) {
    if (op.accountId != _accountId) {
      throw StateError('The pending operation belongs to another account.');
    }
  }

  String _now() => _nowUtc().toIso8601String();
}

class _MovedTaskRestoration {
  const _MovedTaskRestoration({
    required this.sourceTaskListId,
    required this.serverTask,
    required this.discardedDestinationTaskListIds,
  });

  final String sourceTaskListId;
  final TaskDto? serverTask;
  final Set<String> discardedDestinationTaskListIds;
}

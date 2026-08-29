import 'dart:convert';

import '../../db/app_database.dart';
import '../calendar/data/calendar_repository.dart';
import '../task_lists/data/task_lists_repository.dart';
import '../tasks/data/tasks_repository.dart';
import '../tasks/domain/task_remote_client.dart';
import '../tasks/domain/task_remote_error.dart';
import 'sync_engine.dart';

class PendingOpResolutionService {
  PendingOpResolutionService({
    required AppDatabase database,
    TaskRemoteClient? apiClient,
    required String accountId,
    SyncEngine? syncEngine,
    Future<void> Function()? syncCalendar,
    DateTime Function()? nowUtc,
  }) : _database = database,
       _apiClient = apiClient,
       _accountId = accountId,
       _syncEngine = syncEngine,
       _syncCalendar = syncCalendar,
       _nowUtc = nowUtc ?? (() => DateTime.now().toUtc());

  final AppDatabase _database;
  final TaskRemoteClient? _apiClient;
  final String _accountId;
  final SyncEngine? _syncEngine;
  final Future<void> Function()? _syncCalendar;
  final DateTime Function() _nowUtc;

  Future<void> retryNow(String opId) async {
    final op = await _database.pendingOpsDao.getOp(opId);
    if (op == null) return;
    await _database.pendingOpsDao.retryNow(opId, _nowUtc());
    await _syncAfterResolution(op);
  }

  Future<void> discard(String opId) async {
    final op = await _database.pendingOpsDao.getOp(opId);
    if (op == null) {
      return;
    }

    final syncAfterDiscard = await _refreshOrRemoveLocalState(op);
    await _database.pendingOpsDao.deleteOp(op.id);
    if (syncAfterDiscard) {
      await _syncAfterResolution(op);
    }
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
    if (op.entityType == 'calendar') {
      final syncCalendar = _syncCalendar;
      if (syncCalendar != null) {
        await syncCalendar();
        return;
      }
    }
    final syncEngine = _syncEngine;
    if (syncEngine == null) {
      throw StateError(
        'No synchronization path is available for this operation.',
      );
    }
    await syncEngine.incrementalSync();
  }

  TaskRemoteClient get _requiredTaskClient {
    return _apiClient ??
        (throw StateError('Task operation recovery is unavailable.'));
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

  String _now() => _nowUtc().toIso8601String();
}

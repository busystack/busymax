import 'dart:convert';

import '../../db/app_database.dart';
import '../../google_tasks/api/google_tasks_api_client.dart';
import '../../google_tasks/api/google_tasks_api_error.dart';
import '../task_lists/data/task_lists_repository.dart';
import '../tasks/data/tasks_repository.dart';
import 'sync_engine.dart';

class PendingOpResolutionService {
  PendingOpResolutionService({
    required AppDatabase database,
    required GoogleTasksApiClient apiClient,
    required String accountId,
    required SyncEngine syncEngine,
    DateTime Function()? nowUtc,
  }) : _database = database,
       _apiClient = apiClient,
       _accountId = accountId,
       _syncEngine = syncEngine,
       _nowUtc = nowUtc ?? (() => DateTime.now().toUtc());

  final AppDatabase _database;
  final GoogleTasksApiClient _apiClient;
  final String _accountId;
  final SyncEngine _syncEngine;
  final DateTime Function() _nowUtc;

  Future<void> retryNow(String opId) async {
    await _database.pendingOpsDao.retryNow(opId, _nowUtc());
    await _syncEngine.incrementalSync();
  }

  Future<void> discard(String opId) async {
    final op = await _database.pendingOpsDao.getOp(opId);
    if (op == null) {
      return;
    }

    await _refreshOrRemoveLocalState(op);
    await _database.pendingOpsDao.deleteOp(op.id);
    await _syncEngine.incrementalSync();
  }

  Future<void> _refreshOrRemoveLocalState(PendingOp op) async {
    if (op.entityType == 'task' && op.taskListId != null && op.taskId != null) {
      if (op.operation == 'move_task') {
        await _refreshOrRemoveMovedTask(op);
        return;
      }
      await _refreshOrRemoveTask(op.taskListId!, op.taskId!);
      return;
    }

    if (op.entityType == 'task_list' && op.taskListId != null) {
      await _refreshOrRemoveTaskList(op.taskListId!);
    }
  }

  Future<void> _refreshOrRemoveMovedTask(PendingOp op) async {
    final sourceTaskListId = op.taskListId!;
    final taskId = op.taskId!;
    final destinationTaskListId = _destinationTaskListId(op);

    try {
      final dto = await _apiClient.getTask(
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
    } on GoogleTasksApiError catch (error) {
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
      final dto = await _apiClient.getTask(
        taskListId: taskListId,
        taskId: taskId,
      );
      await _database.tasksDao.upsertTask(
        taskFromDto(_accountId, taskListId, dto, _now()),
      );
    } on GoogleTasksApiError catch (error) {
      if (error.statusCode != 404) {
        rethrow;
      }
      await _database.tasksDao.deleteTask(_accountId, taskListId, taskId);
    }
  }

  Future<void> _refreshOrRemoveTaskList(String taskListId) async {
    try {
      final dto = await _apiClient.getTaskList(taskListId);
      await _database.taskListsDao.upsertTaskList(
        taskListFromDto(_accountId, dto, _now()),
      );
    } on GoogleTasksApiError catch (error) {
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

  String _now() => _nowUtc().toIso8601String();
}

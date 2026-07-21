import 'dart:convert';
import 'dart:math';

import 'package:drift/drift.dart';

import '../../db/app_database.dart';
import '../../google_tasks/api/google_tasks_api_client.dart';
import '../../google_tasks/api/google_tasks_api_error.dart';
import '../../google_tasks/api/google_tasks_api_models.dart';
import 'conflict_detector.dart';
import '../task_lists/data/task_lists_repository.dart';
import '../tasks/data/tasks_repository.dart';

class PendingOpsReplayer {
  PendingOpsReplayer({
    required AppDatabase database,
    required GoogleTasksApiClient apiClient,
    required String accountId,
    Future<void> Function(String summary)? onConflictBlocked,
    Random? random,
    DateTime Function()? nowUtc,
  }) : _database = database,
       _apiClient = apiClient,
       _accountId = accountId,
       _onConflictBlocked = onConflictBlocked,
       _random = random ?? Random.secure(),
       _nowUtc = nowUtc ?? (() => DateTime.now().toUtc());

  final AppDatabase _database;
  final GoogleTasksApiClient _apiClient;
  final String _accountId;
  final Future<void> Function(String summary)? _onConflictBlocked;
  final Random _random;
  final DateTime Function() _nowUtc;

  Future<int> replayDueOps() async {
    final ops = await _database.pendingOpsDao.pendingOpsForReplay(
      _accountId,
      _nowUtc(),
    );
    var applied = 0;

    for (final originalOp in ops) {
      final op = await _readOp(originalOp.id);
      if (op == null || !_isTaskOp(op)) {
        continue;
      }
      if (op.dependsOnOpId != null && await _opExists(op.dependsOnOpId!)) {
        continue;
      }

      try {
        await _replay(op);
        await _database.pendingOpsDao.deleteOp(op.id);
        applied += 1;
      } on GoogleTasksApiError catch (error) {
        if (_isSuccessfulMissingDelete(op, error)) {
          await _applyDeleteSideEffect(op);
          await _database.pendingOpsDao.deleteOp(op.id);
          applied += 1;
        } else if (_isRetryableStatus(error.statusCode)) {
          await _scheduleRetry(op, error.statusCode.toString(), error.message);
        } else {
          await _blockOp(op, error.statusCode.toString(), error.message);
        }
      } on _PendingOpBlocked {
        continue;
      } on Object catch (error) {
        await _scheduleRetry(
          op,
          error.runtimeType.toString(),
          error.toString(),
        );
      }
    }

    return applied;
  }

  bool _isTaskOp(PendingOp op) {
    return op.entityType == 'task' || op.entityType == 'task_list';
  }

  Future<void> _replay(PendingOp op) async {
    switch (op.operation) {
      case 'create_task_list':
        await _createTaskList(op);
      case 'patch_task_list':
        await _patchTaskList(op);
      case 'update_task_list':
        await _updateTaskList(op);
      case 'delete_task_list':
        await _deleteTaskList(op);
      case 'create_task':
        await _createTask(op);
      case 'patch_task':
        await _patchTask(op);
      case 'update_task':
        await _updateTask(op);
      case 'delete_task':
        await _deleteTask(op);
      case 'move_task':
        await _moveTask(op);
      case 'clear_completed_tasks':
        await _clearCompleted(op);
      default:
        await _blockOp(op, 'unknown_operation', op.operation);
        throw const _PendingOpBlocked();
    }
  }

  Future<void> _createTaskList(PendingOp op) async {
    final request = _request(op);
    final dto = await _apiClient.createTaskList(
      title: request['title']?.toString() ?? '',
    );
    final tempId = op.localTempId ?? op.taskListId;
    if (tempId == null) {
      await _database.taskListsDao.upsertTaskList(
        taskListFromDto(_accountId, dto, _now()),
      );
      return;
    }

    await _database.transaction(() async {
      await _database.taskListsDao.upsertTaskList(
        taskListFromDto(_accountId, dto, _now()),
      );
      await _database.customStatement(
        'UPDATE tasks SET task_list_id = ? WHERE account_id = ? '
        'AND task_list_id = ?',
        [dto.id, _accountId, tempId],
      );
      await _replacePendingReference(tempId, dto.id);
      await _database.taskListsDao.deleteTaskList(_accountId, tempId);
    });
  }

  Future<void> _patchTaskList(PendingOp op) async {
    await _ensureNoTaskListConflict(op, _request(op));
    final dto = await _apiClient.patchTaskList(
      op.taskListId!,
      TaskListPatch(_request(op)),
    );
    await _database.taskListsDao.upsertTaskList(
      taskListFromDto(_accountId, dto, _now()),
    );
  }

  Future<void> _updateTaskList(PendingOp op) async {
    await _ensureNoTaskListConflict(op, _request(op));
    final dto = await _apiClient.updateTaskList(
      op.taskListId!,
      TaskListPut(_request(op)),
    );
    await _database.taskListsDao.upsertTaskList(
      taskListFromDto(_accountId, dto, _now()),
    );
  }

  Future<void> _deleteTaskList(PendingOp op) async {
    await _ensureTaskListUnchanged(op, 'delete');
    await _ensureNoTaskInListChangedAfterBaseline(op, 'delete');
    await _apiClient.deleteTaskList(op.taskListId!);
    await _database.taskListsDao.deleteTaskList(_accountId, op.taskListId!);
  }

  Future<void> _createTask(PendingOp op) async {
    final request = _request(op);
    final body = (request['body'] as Map).cast<String, Object?>();
    final dto = await _apiClient.createTask(
      taskListId: op.taskListId!,
      parentTaskId: request['parent']?.toString(),
      previousSiblingTaskId: request['previous']?.toString(),
      create: TaskCreate.fields(body),
    );
    final tempId = op.localTempId ?? op.taskId;
    if (tempId == null) {
      await _database.tasksDao.upsertTask(
        taskFromDto(_accountId, op.taskListId!, dto, _now()),
      );
      return;
    }

    await _replaceLocalTaskId(
      taskListId: op.taskListId!,
      tempTaskId: tempId,
      serverTask: dto,
    );
  }

  Future<void> _patchTask(PendingOp op) async {
    await _ensureNoTaskConflict(op, _request(op));
    final dto = await _apiClient.patchTask(
      taskListId: op.taskListId!,
      taskId: op.taskId!,
      patch: TaskPatch.fields(_request(op)),
    );
    await _applyTaskEditResult(op, dto);
  }

  Future<void> _updateTask(PendingOp op) async {
    await _ensureNoTaskConflict(op, _request(op));
    final dto = await _apiClient.updateTask(
      taskListId: op.taskListId!,
      taskId: op.taskId!,
      replacement: TaskPut.fields(_request(op)),
    );
    await _applyTaskEditResult(op, dto);
  }

  Future<void> _applyTaskEditResult(PendingOp op, TaskDto serverTask) async {
    await _database.transaction(() async {
      final hasDependent = await _rebaseDependentTaskEdits(op, serverTask);
      if (hasDependent) {
        return;
      }
      await _database.tasksDao.upsertTask(
        taskFromDto(_accountId, op.taskListId!, serverTask, _now()),
      );
    });
  }

  Future<bool> _rebaseDependentTaskEdits(
    PendingOp completedOp,
    TaskDto serverTask,
  ) async {
    final dependents =
        await (_database.select(_database.pendingOps)..where(
              (row) =>
                  row.accountId.equals(_accountId) &
                  row.dependsOnOpId.equals(completedOp.id),
            ))
            .get();
    if (dependents.isEmpty) {
      return false;
    }

    final acknowledgedFields = _request(completedOp).keys;
    for (final dependent in dependents) {
      final baseline = _jsonObject(dependent.baselineRawJson ?? '{}');
      // Keep the original timestamp and untouched fields so a provider edit to
      // a different field is still detected by the dependent operation.
      for (final field in acknowledgedFields) {
        baseline[field] = serverTask.rawJson[field];
      }
      await (_database.update(
        _database.pendingOps,
      )..where((row) => row.id.equals(dependent.id))).write(
        PendingOpsCompanion(
          baselineRawJson: Value(jsonEncode(baseline)),
          updatedAtUtc: Value(_now()),
        ),
      );
    }
    return true;
  }

  Future<void> _deleteTask(PendingOp op) async {
    await _ensureTaskUnchanged(op, 'delete');
    await _apiClient.deleteTask(taskListId: op.taskListId!, taskId: op.taskId!);
    await _database.tasksDao.deleteTask(_accountId, op.taskListId!, op.taskId!);
  }

  Future<void> _moveTask(PendingOp op) async {
    await _ensureTaskUnchanged(op, 'move');
    final request = _request(op);
    final destinationTaskListId = request['destinationTasklist']?.toString();
    final targetTaskListId = destinationTaskListId ?? op.taskListId!;
    final dto = await _apiClient.moveTask(
      sourceTaskListId: op.taskListId!,
      taskId: op.taskId!,
      parentTaskId: request['parent']?.toString(),
      previousSiblingTaskId: request['previous']?.toString(),
      destinationTaskListId: destinationTaskListId,
    );
    await _database.transaction(() async {
      await _database.tasksDao.upsertTask(
        taskFromDto(_accountId, targetTaskListId, dto, _now()),
      );
      if (targetTaskListId != op.taskListId) {
        await _database.tasksDao.deleteTask(
          _accountId,
          op.taskListId!,
          op.taskId!,
        );
      }
    });
  }

  Future<void> _clearCompleted(PendingOp op) async {
    await _ensureNoCompletedTaskConflict(op);
    await _apiClient.clearCompletedTasks(op.taskListId!);
  }

  Future<void> _replaceLocalTaskId({
    required String taskListId,
    required String tempTaskId,
    required TaskDto serverTask,
  }) async {
    await _database.transaction(() async {
      await _database.tasksDao.upsertTask(
        taskFromDto(_accountId, taskListId, serverTask, _now()),
      );
      await _database.customStatement(
        'UPDATE tasks SET parent = ? WHERE account_id = ? AND parent = ?',
        [serverTask.id, _accountId, tempTaskId],
      );
      await _replacePendingReference(tempTaskId, serverTask.id);
      await _database.tasksDao.deleteTask(_accountId, taskListId, tempTaskId);
    });
  }

  Future<void> _replacePendingReference(
    String oldValue,
    String newValue,
  ) async {
    await _database.customStatement(
      'UPDATE pending_ops SET task_list_id = ? WHERE account_id = ? '
      'AND task_list_id = ?',
      [newValue, _accountId, oldValue],
    );
    await _database.customStatement(
      'UPDATE pending_ops SET task_id = ? WHERE account_id = ? AND task_id = ?',
      [newValue, _accountId, oldValue],
    );
    await _database.customStatement(
      'UPDATE pending_ops SET local_temp_id = ? WHERE account_id = ? '
      'AND local_temp_id = ?',
      [newValue, _accountId, oldValue],
    );

    final ops = await (_database.select(
      _database.pendingOps,
    )..where((row) => row.accountId.equals(_accountId))).get();
    for (final op in ops) {
      final request = _request(op);
      final rewritten = _replaceJsonReference(request, oldValue, newValue);
      final rewrittenJson = jsonEncode(rewritten);
      if (rewrittenJson == op.requestJson) {
        continue;
      }
      await (_database.update(
        _database.pendingOps,
      )..where((row) => row.id.equals(op.id))).write(
        PendingOpsCompanion(
          requestJson: Value(rewrittenJson),
          updatedAtUtc: Value(_now()),
        ),
      );
    }
  }

  Future<void> _applyDeleteSideEffect(PendingOp op) async {
    if (op.operation == 'delete_task_list' && op.taskListId != null) {
      await _database.taskListsDao.deleteTaskList(_accountId, op.taskListId!);
    }
    if (op.operation == 'delete_task' &&
        op.taskListId != null &&
        op.taskId != null) {
      await _database.tasksDao.deleteTask(
        _accountId,
        op.taskListId!,
        op.taskId!,
      );
    }
  }

  bool _isSuccessfulMissingDelete(PendingOp op, GoogleTasksApiError error) {
    return error.statusCode == 404 &&
        (op.operation == 'delete_task_list' || op.operation == 'delete_task');
  }

  bool _isRetryableStatus(int statusCode) {
    return statusCode == 429 || statusCode >= 500;
  }

  Future<void> _scheduleRetry(
    PendingOp op,
    String errorCode,
    String errorMessage,
  ) {
    final nextAttempt = _nextAttempt(op.attemptCount);
    return _database.pendingOpsDao.updateAttempt(
      id: op.id,
      attemptCount: op.attemptCount + 1,
      nextAttemptAtUtc: nextAttempt,
      lastErrorCode: errorCode,
      lastErrorMessage: errorMessage,
    );
  }

  Future<void> _blockOp(PendingOp op, String errorCode, String errorMessage) {
    return _database.pendingOpsDao.updateAttempt(
      id: op.id,
      attemptCount: op.attemptCount + 1,
      nextAttemptAtUtc: DateTime.utc(9999, 12, 31),
      lastErrorCode: errorCode,
      lastErrorMessage: errorMessage,
    );
  }

  DateTime _nextAttempt(int attemptCount) {
    final baseSeconds = min(pow(2, attemptCount).toInt(), 300);
    final jitterMs = _random.nextInt(max(baseSeconds * 500, 1));
    return _nowUtc().add(
      Duration(seconds: baseSeconds, milliseconds: jitterMs),
    );
  }

  Future<bool> _opExists(String id) async {
    return _readOp(id).then((op) => op != null);
  }

  Future<PendingOp?> _readOp(String id) async {
    final op = await (_database.select(
      _database.pendingOps,
    )..where((row) => row.id.equals(id))).getSingleOrNull();
    return op;
  }

  Map<String, Object?> _request(PendingOp op) {
    return (jsonDecode(op.requestJson) as Map).cast<String, Object?>();
  }

  Future<void> _ensureNoTaskListConflict(
    PendingOp op,
    Map<String, Object?> pendingFields,
  ) async {
    final baselineUpdatedUtc = _parseUtc(op.baselineUpdatedUtc);
    if (baselineUpdatedUtc == null || op.taskListId == null) {
      return;
    }

    final local =
        await (_database.select(_database.taskLists)..where(
              (row) =>
                  row.accountId.equals(_accountId) &
                  row.id.equals(op.taskListId!),
            ))
            .getSingleOrNull();
    if (local == null) {
      return;
    }

    final current = await _apiClient.getTaskList(op.taskListId!);
    final baselineJson = op.baselineRawJson == null
        ? _jsonObject(local.rawJson)
        : _jsonObject(op.baselineRawJson!);
    final conflict = const ConflictDetector().detect(
      entityType: 'task_list',
      entityId: op.taskListId!,
      localPendingFields: pendingFields,
      lastServerJson: baselineJson,
      currentServerJson: current.rawJson,
      baselineUpdatedUtc: baselineUpdatedUtc,
      currentUpdatedUtc: current.updated,
    );
    if (conflict.hasConflict) {
      await _blockConflict(
        op,
        'Remote task list changed fields: '
        '${conflict.changedFields.toList()..sort()}',
      );
    }
  }

  Future<void> _ensureNoTaskConflict(
    PendingOp op,
    Map<String, Object?> pendingFields,
  ) async {
    final baselineUpdatedUtc = _parseUtc(op.baselineUpdatedUtc);
    if (baselineUpdatedUtc == null ||
        op.taskListId == null ||
        op.taskId == null) {
      return;
    }

    final local =
        await (_database.select(_database.tasks)..where(
              (row) =>
                  row.accountId.equals(_accountId) &
                  row.taskListId.equals(op.taskListId!) &
                  row.id.equals(op.taskId!),
            ))
            .getSingleOrNull();
    if (local == null) {
      return;
    }

    final current = await _apiClient.getTask(
      taskListId: op.taskListId!,
      taskId: op.taskId!,
    );
    final baselineJson = op.baselineRawJson == null
        ? _jsonObject(local.rawJson)
        : _jsonObject(op.baselineRawJson!);
    final conflict = const ConflictDetector().detect(
      entityType: 'task',
      entityId: op.taskId!,
      localPendingFields: pendingFields,
      lastServerJson: baselineJson,
      currentServerJson: current.rawJson,
      baselineUpdatedUtc: baselineUpdatedUtc,
      currentUpdatedUtc: current.updated,
    );
    if (conflict.hasConflict) {
      await _blockConflict(
        op,
        'Remote task changed fields: ${conflict.changedFields.toList()..sort()}',
      );
    }
  }

  Future<void> _ensureTaskListUnchanged(PendingOp op, String action) async {
    final baselineUpdatedUtc = _parseUtc(op.baselineUpdatedUtc);
    if (baselineUpdatedUtc == null || op.taskListId == null) {
      return;
    }

    final current = await _apiClient.getTaskList(op.taskListId!);
    if (_remoteChangedAfterBaseline(current.updated, baselineUpdatedUtc)) {
      await _blockConflict(
        op,
        'Remote task list changed since local $action was queued.',
      );
    }
  }

  Future<void> _ensureTaskUnchanged(PendingOp op, String action) async {
    final baselineUpdatedUtc = _parseUtc(op.baselineUpdatedUtc);
    if (baselineUpdatedUtc == null ||
        op.taskListId == null ||
        op.taskId == null) {
      return;
    }

    final current = await _apiClient.getTask(
      taskListId: op.taskListId!,
      taskId: op.taskId!,
    );
    if (_remoteChangedAfterBaseline(current.updated, baselineUpdatedUtc)) {
      await _blockConflict(
        op,
        'Remote task changed since local $action was queued.',
      );
    }
  }

  Future<void> _ensureNoTaskInListChangedAfterBaseline(
    PendingOp op,
    String action,
  ) async {
    final baselineUpdatedUtc = _parseUtc(op.baselineUpdatedUtc);
    if (baselineUpdatedUtc == null || op.taskListId == null) {
      return;
    }

    String? pageToken;
    do {
      final page = await _apiClient.listTasksPage(
        taskListId: op.taskListId!,
        maxResults: 100,
        pageToken: pageToken,
        showCompleted: true,
        showDeleted: true,
        showHidden: true,
        showAssigned: true,
        updatedMin: baselineUpdatedUtc,
      );

      for (final task in page.items) {
        if (_remoteChangedAfterBaseline(task.updated, baselineUpdatedUtc)) {
          await _blockConflict(
            op,
            'Remote task in list changed since local $action was queued.',
          );
        }
      }

      pageToken = page.nextPageToken;
    } while (pageToken != null && pageToken.isNotEmpty);
  }

  Future<void> _ensureNoCompletedTaskConflict(PendingOp op) async {
    final baselineUpdatedUtc = _parseUtc(op.baselineUpdatedUtc);
    if (baselineUpdatedUtc == null || op.taskListId == null) {
      return;
    }

    String? pageToken;
    do {
      final page = await _apiClient.listTasksPage(
        taskListId: op.taskListId!,
        maxResults: 100,
        pageToken: pageToken,
        showCompleted: true,
        showDeleted: false,
        showHidden: true,
        showAssigned: true,
        updatedMin: baselineUpdatedUtc,
      );
      for (final task in page.items) {
        if (task.status == 'completed' &&
            _remoteChangedAfterBaseline(task.updated, baselineUpdatedUtc)) {
          await _blockConflict(
            op,
            'Remote completed task changed since clear-completed was queued.',
          );
        }
      }
      pageToken = page.nextPageToken;
    } while (pageToken != null && pageToken.isNotEmpty);
  }

  Future<void> _blockConflict(PendingOp op, String message) async {
    await _blockOp(op, 'conflict', message);
    await _onConflictBlocked?.call(message);
    throw const _PendingOpBlocked();
  }

  bool _remoteChangedAfterBaseline(DateTime? updatedUtc, DateTime baselineUtc) {
    return updatedUtc != null && updatedUtc.toUtc().isAfter(baselineUtc);
  }

  Map<String, Object?> _jsonObject(String rawJson) {
    return (jsonDecode(rawJson) as Map).cast<String, Object?>();
  }

  DateTime? _parseUtc(String? value) {
    if (value == null || value.isEmpty) {
      return null;
    }
    return DateTime.tryParse(value)?.toUtc();
  }

  String _now() => _nowUtc().toIso8601String();
}

const _pendingOpReferenceKeys = {
  'id',
  'parent',
  'previous',
  'taskId',
  'taskListId',
  'tasklist',
  'destinationTasklist',
};

Object? _replaceJsonReference(
  Object? value,
  String oldValue,
  String newValue, {
  String? key,
}) {
  if (value is String) {
    return _pendingOpReferenceKeys.contains(key) && value == oldValue
        ? newValue
        : value;
  }
  if (value is List) {
    return [
      for (final item in value)
        _replaceJsonReference(item, oldValue, newValue, key: key),
    ];
  }
  if (value is Map) {
    return {
      for (final entry in value.entries)
        entry.key: _replaceJsonReference(
          entry.value,
          oldValue,
          newValue,
          key: entry.key.toString(),
        ),
    };
  }
  return value;
}

class _PendingOpBlocked {
  const _PendingOpBlocked();
}

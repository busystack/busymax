import 'dart:convert';
import 'dart:math';

import 'package:collection/collection.dart';
import 'package:drift/drift.dart';

import '../../core/http/request_dispatch_exception.dart';
import '../../db/app_database.dart';
import '../tasks/domain/task_remote_client.dart';
import '../tasks/domain/task_remote_error.dart';
import '../tasks/domain/task_remote_models.dart';
import 'conflict_detector.dart';
import 'collection_id_replacement.dart';
import 'pending_ops_replay_coordinator.dart';
import '../task_lists/data/task_lists_repository.dart';
import '../tasks/data/tasks_repository.dart';
import '../tasks/domain/task_checklist_item.dart';

class PendingOpsReplayer {
  PendingOpsReplayer({
    required AppDatabase database,
    required TaskRemoteClient apiClient,
    required String accountId,
    Future<void> Function(String summary)? onConflictBlocked,
    CollectionIdReplacement? onTaskListIdReplaced,
    Random? random,
    DateTime Function()? nowUtc,
  }) : _database = database,
       _apiClient = apiClient,
       _accountId = accountId,
       _onConflictBlocked = onConflictBlocked,
       _onTaskListIdReplaced = onTaskListIdReplaced,
       _random = random ?? Random.secure(),
       _nowUtc = nowUtc ?? (() => DateTime.now().toUtc());

  final AppDatabase _database;
  final TaskRemoteClient _apiClient;
  final String _accountId;
  final Future<void> Function(String summary)? _onConflictBlocked;
  final CollectionIdReplacement? _onTaskListIdReplaced;
  final Random _random;
  final DateTime Function() _nowUtc;

  Future<int> replayDueOps() {
    return serializePendingOpsReplay(
      database: _database,
      accountId: _accountId,
      replay: _replayDueOps,
    );
  }

  Future<int> _replayDueOps() async {
    final ops = await _database.pendingOpsDao.pendingOpsForReplay(
      _accountId,
      _nowUtc(),
    );
    var applied = 0;
    final handledIds = <String>{};
    var madeProgress = true;

    while (madeProgress) {
      madeProgress = false;
      for (final originalOp in ops) {
        if (handledIds.contains(originalOp.id)) continue;
        final op = await _readOp(originalOp.id);
        if (op == null || !_isTaskOp(op)) {
          handledIds.add(originalOp.id);
          continue;
        }
        if (op.dependsOnOpId != null && await _opExists(op.dependsOnOpId!)) {
          continue;
        }
        if (_isCreationOp(op)) {
          if (op.state == 'in_progress') {
            await _blockUnknownCreationOutcome(
              op,
              'The app stopped before the result of this creation request '
              'was recorded. Check the provider before discarding the '
              'local operation.',
            );
            handledIds.add(op.id);
            madeProgress = true;
            continue;
          }
          if (op.state == 'recovery_required') {
            await _restoreUnknownCreationOutcomeBlock(op);
            handledIds.add(op.id);
            madeProgress = true;
            continue;
          }
          if (!await _claimCreation(op)) {
            continue;
          }
        }
        handledIds.add(op.id);
        madeProgress = true;

        try {
          await _replay(op);
          await _database.pendingOpsDao.deleteOp(op.id);
          applied += 1;
        } on RequestNotDispatchedException catch (error) {
          await _scheduleRetry(
            op,
            error.code,
            'The request was not sent and can be retried safely.',
          );
        } on TaskRemoteError catch (error) {
          if (_isSuccessfulMissingDelete(op, error)) {
            await _applyDeleteSideEffect(op);
            await _database.pendingOpsDao.deleteOp(op.id);
            applied += 1;
          } else if (_isCreationOp(op) &&
              _hasUnknownCreationOutcome(error.statusCode)) {
            await _blockUnknownCreationOutcome(op, error.message);
          } else if (_isRetryableStatus(error.statusCode)) {
            await _scheduleRetry(
              op,
              error.statusCode.toString(),
              error.message,
            );
          } else {
            await _blockOp(op, error.statusCode.toString(), error.message);
          }
        } on _PendingOpBlocked {
          continue;
        } on Object catch (error) {
          if (_isCreationOp(op)) {
            await _blockUnknownCreationOutcome(op, error.toString());
          } else {
            await _scheduleRetry(
              op,
              error.runtimeType.toString(),
              error.toString(),
            );
          }
        }
      }
    }

    return applied;
  }

  bool _isTaskOp(PendingOp op) {
    return op.entityType == 'task' ||
        op.entityType == 'task_list' ||
        op.entityType == 'task_checklist_item';
  }

  bool _isCreationOp(PendingOp op) {
    return op.operation == 'create_task_list' ||
        op.operation == 'create_task' ||
        op.operation == 'create_task_checklist_item';
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
      case 'create_task_checklist_item':
        await _createChecklistItem(op);
      case 'patch_task_checklist_item':
        await _patchChecklistItem(op);
      case 'delete_task_checklist_item':
        await _deleteChecklistItem(op);
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
      await _database.transaction(() async {
        await _database.taskListsDao.upsertTaskList(
          taskListFromDto(_accountId, dto, _now()),
        );
        await _database.pendingOpsDao.deleteOp(op.id);
      });
      return;
    }

    await _database.transaction(() async {
      final temporaryList =
          await (_database.select(_database.taskLists)..where(
                (row) =>
                    row.accountId.equals(_accountId) & row.id.equals(tempId),
              ))
              .getSingleOrNull();
      final hasDependent = await _rebaseDependentTaskListMutations(op, dto);
      await _database.taskListsDao.upsertTaskList(
        taskListFromDto(_accountId, dto, _now()),
      );
      if (temporaryList != null) {
        await (_database.update(_database.taskLists)..where(
              (row) => row.accountId.equals(_accountId) & row.id.equals(dto.id),
            ))
            .write(
              TaskListsCompanion(
                remindersEnabled: Value(temporaryList.remindersEnabled),
                title: hasDependent
                    ? Value(temporaryList.title)
                    : const Value.absent(),
                localDirty: hasDependent
                    ? const Value(true)
                    : const Value.absent(),
                pendingDelete: hasDependent
                    ? Value(temporaryList.pendingDelete)
                    : const Value.absent(),
                updatedLocalAtUtc: Value(_now()),
              ),
            );
      }
      await _database.customStatement(
        'UPDATE tasks SET task_list_id = ? WHERE account_id = ? '
        'AND task_list_id = ?',
        [dto.id, _accountId, tempId],
      );
      await _replacePendingReference(
        tempId,
        dto.id,
        completedCreateOpId: op.id,
      );
      await _database.taskListsDao.deleteTaskList(_accountId, tempId);
      // Commit the server identity and creation acknowledgement together.
      await _database.pendingOpsDao.deleteOp(op.id);
    });
    await notifyCollectionIdReplacement(_onTaskListIdReplaced, tempId, dto.id);
  }

  Future<void> _patchTaskList(PendingOp op) async {
    await _ensureNoTaskListConflict(op, _request(op));
    final dto = await _apiClient.patchTaskList(
      op.taskListId!,
      TaskListPatch(_request(op)),
    );
    await _applyTaskListEditResult(op, dto);
  }

  Future<void> _updateTaskList(PendingOp op) async {
    await _ensureNoTaskListConflict(op, _request(op));
    final dto = await _apiClient.updateTaskList(
      op.taskListId!,
      TaskListPut(_request(op)),
    );
    await _applyTaskListEditResult(op, dto);
  }

  Future<void> _applyTaskListEditResult(
    PendingOp op,
    TaskListDto serverList,
  ) async {
    await _database.transaction(() async {
      final local =
          await (_database.select(_database.taskLists)..where(
                (row) =>
                    row.accountId.equals(_accountId) &
                    row.id.equals(op.taskListId!),
              ))
              .getSingleOrNull();
      final hasDependent = await _rebaseDependentTaskListMutations(
        op,
        serverList,
      );
      if (hasDependent) return;
      await _database.taskListsDao.upsertTaskList(
        taskListFromDto(_accountId, serverList, _now()),
      );
      if (local != null) {
        await (_database.update(_database.taskLists)..where(
              (row) =>
                  row.accountId.equals(_accountId) &
                  row.id.equals(serverList.id),
            ))
            .write(
              TaskListsCompanion(
                remindersEnabled: Value(local.remindersEnabled),
              ),
            );
      }
    });
  }

  Future<bool> _rebaseDependentTaskListMutations(
    PendingOp completedOp,
    TaskListDto serverList,
  ) async {
    final dependents =
        await (_database.select(_database.pendingOps)..where(
              (row) =>
                  row.accountId.equals(_accountId) &
                  row.dependsOnOpId.equals(completedOp.id),
            ))
            .get();
    if (dependents.isEmpty) return false;

    final acknowledged = _normalizeTaskListConflictSnapshot(
      _request(completedOp),
    );
    final serverSnapshot = _normalizeTaskListConflictSnapshot(
      serverList.rawJson,
    );
    for (final dependent in dependents) {
      final dependentRequest = _request(dependent);
      if (dependent.operation == 'delete_task_list' &&
          !dependentRequest.containsKey(_childTaskConflictBaselineKey) &&
          dependent.baselineUpdatedUtc != null) {
        // A list mutation acknowledges list metadata only. Preserve the
        // original cutoff used to detect independent child-task changes.
        dependentRequest[_childTaskConflictBaselineKey] =
            dependent.baselineUpdatedUtc;
      }
      final baseline = _normalizeTaskListConflictSnapshot(
        _jsonObject(dependent.baselineRawJson ?? '{}'),
      );
      for (final field in acknowledged.keys) {
        baseline[field] = serverSnapshot[field];
      }
      await (_database.update(
        _database.pendingOps,
      )..where((row) => row.id.equals(dependent.id))).write(
        PendingOpsCompanion(
          requestJson: Value(jsonEncode(dependentRequest)),
          baselineRawJson: Value(jsonEncode(baseline)),
          baselineUpdatedUtc: serverList.updated == null
              ? const Value.absent()
              : Value(serverList.updated!.toUtc().toIso8601String()),
          updatedAtUtc: Value(_now()),
        ),
      );
    }
    return true;
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
      await _database.transaction(() async {
        await _database.tasksDao.upsertTask(
          taskFromDto(_accountId, op.taskListId!, dto, _now()),
        );
        await _database.pendingOpsDao.deleteOp(op.id);
      });
      return;
    }

    await _replaceLocalTaskId(
      taskListId: op.taskListId!,
      tempTaskId: tempId,
      serverTask: dto,
      completedCreateOpId: op.id,
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
      final hasDependent = await _rebaseDependentTaskMutations(op, serverTask);
      if (hasDependent) {
        return;
      }
      await _database.tasksDao.upsertTask(
        taskFromDto(_accountId, op.taskListId!, serverTask, _now()),
      );
    });
  }

  Future<bool> _rebaseDependentTaskMutations(
    PendingOp completedOp,
    TaskDto serverTask,
  ) async {
    final operations = await (_database.select(
      _database.pendingOps,
    )..where((row) => row.accountId.equals(_accountId))).get();
    final dependencyIds = <String>{completedOp.id};
    final dependents = <PendingOp>[];
    var foundDependent = true;
    while (foundDependent) {
      foundDependent = false;
      for (final candidate in operations) {
        if (dependencyIds.contains(candidate.id) ||
            !dependencyIds.contains(candidate.dependsOnOpId) ||
            !_mutatesSameTask(completedOp, candidate)) {
          continue;
        }
        dependencyIds.add(candidate.id);
        dependents.add(candidate);
        foundDependent = true;
      }
    }
    if (dependents.isEmpty) {
      return false;
    }

    final completedRequest = _request(completedOp);
    final acknowledgedFields = <String>{
      ...(completedOp.operation == 'create_task' &&
              completedRequest['body'] is Map
          ? (completedRequest['body'] as Map).keys.map((key) => key.toString())
          : completedRequest.keys),
    };
    if (acknowledgedFields.contains('status')) {
      acknowledgedFields.addAll({
        'completed',
        'microsoftCompletedDateTime',
        'microsoftCompletedTimeZone',
      });
    }
    if (acknowledgedFields.contains('due') ||
        acknowledgedFields.contains('microsoftDueDateTime')) {
      acknowledgedFields.addAll({
        'due',
        'microsoftDueDateTime',
        'microsoftDueTimeZone',
      });
    }
    if (completedOp.operation == 'move_task') {
      acknowledgedFields.addAll({'parent', 'position'});
    }
    final serverSnapshot = _normalizeTaskConflictSnapshot(serverTask.rawJson);
    for (final dependent in dependents) {
      final initializesServerBaseline =
          completedOp.operation == 'create_task' &&
          dependent.baselineUpdatedUtc == null;
      final baseline = initializesServerBaseline
          ? Map<String, Object?>.from(serverSnapshot)
          : _normalizeTaskConflictSnapshot(
              _jsonObject(dependent.baselineRawJson ?? '{}'),
            );
      final usesWholeTaskConflictBoundary =
          dependent.operation == 'move_task' ||
          dependent.operation == 'delete_task';
      if (!initializesServerBaseline) {
        // Keep the original timestamp and untouched fields so a provider edit
        // to a different field is still detected by a dependent field edit.
        for (final field in acknowledgedFields) {
          baseline[field] = serverSnapshot[field];
        }
      }
      await (_database.update(
        _database.pendingOps,
      )..where((row) => row.id.equals(dependent.id))).write(
        PendingOpsCompanion(
          baselineRawJson: Value(jsonEncode(baseline)),
          // Creation supplies the first server boundary for local-only edits.
          // Whole-task checks must also advance past an acknowledged write.
          baselineUpdatedUtc:
              initializesServerBaseline || usesWholeTaskConflictBoundary
              ? Value(serverTask.updated?.toUtc().toIso8601String())
              : const Value.absent(),
          updatedAtUtc: Value(_now()),
        ),
      );
    }
    return true;
  }

  bool _mutatesSameTask(PendingOp completed, PendingOp dependent) {
    final identities = {
      if (completed.taskId != null) completed.taskId!,
      if (completed.localTempId != null) completed.localTempId!,
    };
    if (dependent.entityType == 'task_checklist_item') {
      return identities.contains(dependent.taskId);
    }
    return dependent.entityType == 'task' &&
        (identities.contains(dependent.taskId) ||
            identities.contains(dependent.localTempId));
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
      final hasDependent = await _rebaseDependentTaskMutations(op, dto);
      if (hasDependent) {
        // The repository has already moved the visible projection to the tail
        // of the local chain. Applying this intermediate response would move
        // it backwards and erase later local edits.
        await _preserveDependentMoveProjection(op, targetTaskListId);
        return;
      }
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

  Future<void> _preserveDependentMoveProjection(
    PendingOp op,
    String targetTaskListId,
  ) async {
    final projectionTaskListId = await _dependentTaskProjectionListId(
      op,
      targetTaskListId,
    );
    if (projectionTaskListId == op.taskListId) return;
    final sourceTask =
        await (_database.select(_database.tasks)..where(
              (row) =>
                  row.accountId.equals(_accountId) &
                  row.taskListId.equals(op.taskListId!) &
                  row.id.equals(op.taskId!),
            ))
            .getSingleOrNull();
    if (sourceTask == null) return;
    final destinationTask =
        await (_database.select(_database.tasks)..where(
              (row) =>
                  row.accountId.equals(_accountId) &
                  row.taskListId.equals(projectionTaskListId) &
                  row.id.equals(op.taskId!),
            ))
            .getSingleOrNull();
    if (destinationTask == null) {
      await (_database.update(_database.tasks)..where(
            (row) =>
                row.accountId.equals(_accountId) &
                row.taskListId.equals(op.taskListId!) &
                row.id.equals(op.taskId!),
          ))
          .write(TasksCompanion(taskListId: Value(projectionTaskListId)));
      return;
    }
    await _database.tasksDao.deleteTask(_accountId, op.taskListId!, op.taskId!);
  }

  Future<String> _dependentTaskProjectionListId(
    PendingOp completedOp,
    String initialTaskListId,
  ) async {
    final operations = await (_database.select(
      _database.pendingOps,
    )..where((row) => row.accountId.equals(_accountId))).get();
    final dependencyIds = <String>{completedOp.id};
    var projectionTaskListId = initialTaskListId;
    var foundDependent = true;
    while (foundDependent) {
      foundDependent = false;
      for (final candidate in operations) {
        if (dependencyIds.contains(candidate.id) ||
            !dependencyIds.contains(candidate.dependsOnOpId) ||
            !_mutatesSameTask(completedOp, candidate)) {
          continue;
        }
        dependencyIds.add(candidate.id);
        foundDependent = true;
        final request = _request(candidate);
        projectionTaskListId = candidate.operation == 'move_task'
            ? request['destinationTasklist']?.toString() ??
                  candidate.taskListId ??
                  projectionTaskListId
            : candidate.taskListId ?? projectionTaskListId;
      }
    }
    return projectionTaskListId;
  }

  Future<void> _clearCompleted(PendingOp op) async {
    await _ensureNoCompletedTaskConflict(op);
    await _apiClient.clearCompletedTasks(op.taskListId!);
  }

  Future<void> _createChecklistItem(PendingOp op) async {
    final request = _request(op);
    final body = _requestBody(request);
    final item = await _checklistClient.createChecklistItem(
      taskListId: op.taskListId!,
      taskId: op.taskId!,
      title: body['displayName']?.toString() ?? '',
      completed: body['isChecked'] == true,
    );
    final localId = request['checklistItemId']?.toString() ?? op.localTempId;
    await _database.transaction(() async {
      await _replaceChecklistProjectionItem(
        taskListId: op.taskListId!,
        parentTaskId: op.taskId!,
        oldItemId: localId,
        item: taskChecklistItemFromDto(item),
      );
      if (localId != null) {
        await _replaceChecklistPendingReference(
          parentTaskId: op.taskId!,
          oldValue: localId,
          newValue: item.id,
        );
      }
      // Commit the server identity and creation acknowledgement together.
      await _database.pendingOpsDao.deleteOp(op.id);
    });
  }

  Future<void> _patchChecklistItem(PendingOp op) async {
    final request = _request(op);
    final body = _requestBody(request);
    final itemId = request['checklistItemId']?.toString();
    if (itemId == null || itemId.isEmpty) {
      throw const TaskRemoteError(
        statusCode: 400,
        code: 'invalid_checklist_item',
        message: 'The checklist item identifier is missing.',
      );
    }
    final item = await _checklistClient.updateChecklistItem(
      taskListId: op.taskListId!,
      taskId: op.taskId!,
      checklistItemId: itemId,
      title: body.containsKey('displayName')
          ? body['displayName']?.toString()
          : null,
      completed: body.containsKey('isChecked')
          ? body['isChecked'] == true
          : null,
    );
    await _replaceChecklistProjectionItem(
      taskListId: op.taskListId!,
      parentTaskId: op.taskId!,
      oldItemId: itemId,
      item: taskChecklistItemFromDto(item),
    );
  }

  Future<void> _deleteChecklistItem(PendingOp op) async {
    final itemId = _request(op)['checklistItemId']?.toString();
    if (itemId == null || itemId.isEmpty) {
      throw const TaskRemoteError(
        statusCode: 400,
        code: 'invalid_checklist_item',
        message: 'The checklist item identifier is missing.',
      );
    }
    await _checklistClient.deleteChecklistItem(
      taskListId: op.taskListId!,
      taskId: op.taskId!,
      checklistItemId: itemId,
    );
    await _removeChecklistProjectionItem(op, itemId);
  }

  TaskChecklistRemoteClient get _checklistClient {
    final client = _apiClient;
    if (client is TaskChecklistRemoteClient) {
      return client as TaskChecklistRemoteClient;
    }
    throw const TaskRemoteError(
      statusCode: 400,
      code: 'unsupported_provider_operation',
      message: 'This task provider does not expose checklist subtasks.',
    );
  }

  Map<String, Object?> _requestBody(Map<String, Object?> request) {
    final body = request['body'];
    if (body is Map) return body.cast<String, Object?>();
    return const {};
  }

  Future<void> _replaceChecklistProjectionItem({
    required String taskListId,
    required String parentTaskId,
    required String? oldItemId,
    required TaskChecklistItemEntity item,
  }) async {
    final task =
        await (_database.select(_database.tasks)..where(
              (row) =>
                  row.accountId.equals(_accountId) &
                  row.taskListId.equals(taskListId) &
                  row.id.equals(parentTaskId),
            ))
            .getSingleOrNull();
    if (task == null) return;
    final items = decodeTaskChecklistItems(task.microsoftChecklistItemsJson);
    final index = oldItemId == null
        ? -1
        : items.indexWhere((candidate) => candidate.id == oldItemId);
    if (index < 0) {
      final pendingDelete = oldItemId == null
          ? false
          : await _hasPendingChecklistDelete(
              parentTaskId: parentTaskId,
              checklistItemId: oldItemId,
            );
      if (!pendingDelete) items.add(item);
    } else {
      // Retain the temporary identity long enough for a local action that
      // started before this acknowledgement to resolve the new server item.
      var replacement = item.withLocalIdentityAlias(oldItemId);
      for (final alias in items[index].localIdentityAliases) {
        replacement = replacement.withLocalIdentityAlias(alias);
      }
      items[index] = replacement;
    }
    await (_database.update(_database.tasks)..where(
          (row) =>
              row.accountId.equals(_accountId) &
              row.taskListId.equals(taskListId) &
              row.id.equals(parentTaskId),
        ))
        .write(
          TasksCompanion(
            microsoftChecklistItemsJson: Value(encodeTaskChecklistItems(items)),
            updatedLocalAtUtc: Value(_now()),
          ),
        );
  }

  Future<void> _removeChecklistProjectionItem(
    PendingOp op,
    String itemId,
  ) async {
    final task =
        await (_database.select(_database.tasks)..where(
              (row) =>
                  row.accountId.equals(_accountId) &
                  row.taskListId.equals(op.taskListId!) &
                  row.id.equals(op.taskId!),
            ))
            .getSingleOrNull();
    if (task == null) return;
    final items = decodeTaskChecklistItems(task.microsoftChecklistItemsJson);
    items.removeWhere((item) => item.id == itemId);
    await (_database.update(_database.tasks)..where(
          (row) =>
              row.accountId.equals(_accountId) &
              row.taskListId.equals(op.taskListId!) &
              row.id.equals(op.taskId!),
        ))
        .write(
          TasksCompanion(
            microsoftChecklistItemsJson: Value(encodeTaskChecklistItems(items)),
            updatedLocalAtUtc: Value(_now()),
          ),
        );
  }

  Future<void> _replaceChecklistPendingReference({
    required String parentTaskId,
    required String oldValue,
    required String newValue,
  }) async {
    final operations =
        await (_database.select(_database.pendingOps)..where(
              (row) =>
                  row.accountId.equals(_accountId) &
                  row.entityType.equals('task_checklist_item') &
                  row.taskId.equals(parentTaskId),
            ))
            .get();
    for (final operation in operations) {
      final request = _request(operation);
      final rewritten = _replaceJsonReference(request, oldValue, newValue);
      await (_database.update(
        _database.pendingOps,
      )..where((row) => row.id.equals(operation.id))).write(
        PendingOpsCompanion(
          localTempId: operation.localTempId == oldValue
              ? Value(newValue)
              : const Value.absent(),
          requestJson: Value(jsonEncode(rewritten)),
          updatedAtUtc: Value(_now()),
        ),
      );
    }
  }

  Future<void> _replaceLocalTaskId({
    required String taskListId,
    required String tempTaskId,
    required TaskDto serverTask,
    required String completedCreateOpId,
  }) async {
    await _database.transaction(() async {
      final localTask =
          await (_database.select(_database.tasks)..where(
                (row) =>
                    row.accountId.equals(_accountId) &
                    row.id.equals(tempTaskId),
              ))
              .getSingleOrNull();
      final createOperation = await _database.pendingOpsDao.getOp(
        completedCreateOpId,
      );
      if (createOperation == null) {
        throw StateError('The task creation operation is unavailable.');
      }
      final hasDependent = await _rebaseDependentTaskMutations(
        createOperation,
        serverTask,
      );
      // A queued cross-list move has already relocated the temporary row.
      // Keep that visible projection in place while replacing its identity.
      final projectionTaskListId = localTask?.taskListId ?? taskListId;
      await _database.tasksDao.upsertTask(
        taskFromDto(_accountId, projectionTaskListId, serverTask, _now()),
      );
      if (localTask != null && hasDependent) {
        await (_database.update(_database.tasks)..where(
              (row) =>
                  row.accountId.equals(_accountId) &
                  row.taskListId.equals(projectionTaskListId) &
                  row.id.equals(serverTask.id),
            ))
            .write(_pendingLocalTaskProjection(localTask));
      } else if (localTask?.microsoftChecklistItemsJson != null) {
        await (_database.update(_database.tasks)..where(
              (row) =>
                  row.accountId.equals(_accountId) &
                  row.taskListId.equals(projectionTaskListId) &
                  row.id.equals(serverTask.id),
            ))
            .write(
              TasksCompanion(
                microsoftChecklistItemsJson: Value(
                  localTask!.microsoftChecklistItemsJson,
                ),
                updatedLocalAtUtc: Value(_now()),
              ),
            );
      }
      await _database.customStatement(
        'UPDATE tasks SET parent = ? WHERE account_id = ? AND parent = ?',
        [serverTask.id, _accountId, tempTaskId],
      );
      await _replacePendingReference(
        tempTaskId,
        serverTask.id,
        completedCreateOpId: completedCreateOpId,
      );
      // The schedule ID is also the identity of an already displayed toast.
      // Keep it and its lifecycle intact while retargeting actions atomically.
      await (_database.update(_database.notificationSchedule)..where(
            (row) =>
                row.accountId.equals(_accountId) &
                row.sourceType.equals('task') &
                row.sourceId.equals(tempTaskId),
          ))
          .write(NotificationScheduleCompanion(sourceId: Value(serverTask.id)));
      await _database.tasksDao.deleteTask(
        _accountId,
        localTask?.taskListId ?? taskListId,
        tempTaskId,
      );
      // Commit the server identity and creation acknowledgement together.
      await _database.pendingOpsDao.deleteOp(completedCreateOpId);
    });
  }

  TasksCompanion _pendingLocalTaskProjection(Task local) {
    return TasksCompanion(
      title: Value(local.title),
      parent: Value(local.parent),
      position: Value(local.position),
      notes: Value(local.notes),
      status: Value(local.status),
      dueUtc: Value(local.dueUtc),
      completedUtc: Value(local.completedUtc),
      providerStatus: Value(local.providerStatus),
      bodyContent: Value(local.bodyContent),
      bodyContentType: Value(local.bodyContentType),
      microsoftDueDateTime: Value(local.microsoftDueDateTime),
      microsoftDueTimeZone: Value(local.microsoftDueTimeZone),
      microsoftStartDateTime: Value(local.microsoftStartDateTime),
      microsoftStartTimeZone: Value(local.microsoftStartTimeZone),
      microsoftReminderDateTime: Value(local.microsoftReminderDateTime),
      microsoftReminderTimeZone: Value(local.microsoftReminderTimeZone),
      microsoftIsReminderOn: Value(local.microsoftIsReminderOn),
      microsoftCompletedDateTime: Value(local.microsoftCompletedDateTime),
      microsoftCompletedTimeZone: Value(local.microsoftCompletedTimeZone),
      microsoftChecklistItemsJson: Value(local.microsoftChecklistItemsJson),
      recurrenceJson: Value(local.recurrenceJson),
      importance: Value(local.importance),
      categoriesJson: Value(local.categoriesJson),
      deleted: Value(local.deleted),
      hidden: Value(local.hidden),
      localDirty: const Value(true),
      pendingDelete: Value(local.pendingDelete),
      pendingMove: Value(local.pendingMove),
      localCreated: const Value(false),
      createdLocalAtUtc: Value(local.createdLocalAtUtc),
      updatedLocalAtUtc: Value(local.updatedLocalAtUtc),
    );
  }

  Future<void> _replacePendingReference(
    String oldValue,
    String newValue, {
    required String completedCreateOpId,
  }) async {
    final ops = await (_database.select(
      _database.pendingOps,
    )..where((row) => row.accountId.equals(_accountId))).get();
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

    for (final op in ops) {
      final request = _request(op);
      final rewritten = _replaceJsonReference(request, oldValue, newValue);
      final rewrittenJson = jsonEncode(rewritten);
      final referenceChanged =
          op.taskListId == oldValue ||
          op.taskId == oldValue ||
          op.localTempId == oldValue ||
          rewrittenJson != op.requestJson;
      final unblock =
          op.id != completedCreateOpId &&
          referenceChanged &&
          op.state != 'recovery_required' &&
          op.lastErrorCode != 'creation_outcome_unknown' &&
          op.nextAttemptAtUtc?.startsWith('9999-12-31') == true;
      if (rewrittenJson == op.requestJson && !unblock) {
        continue;
      }
      await (_database.update(
        _database.pendingOps,
      )..where((row) => row.id.equals(op.id))).write(
        PendingOpsCompanion(
          requestJson: rewrittenJson == op.requestJson
              ? const Value.absent()
              : Value(rewrittenJson),
          state: unblock ? const Value('pending') : const Value.absent(),
          nextAttemptAtUtc: unblock ? const Value(null) : const Value.absent(),
          lastErrorCode: unblock ? const Value(null) : const Value.absent(),
          lastErrorMessage: unblock ? const Value(null) : const Value.absent(),
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
    if (op.operation == 'delete_task_checklist_item' &&
        op.taskListId != null &&
        op.taskId != null) {
      final itemId = _request(op)['checklistItemId']?.toString();
      if (itemId != null) {
        await _removeChecklistProjectionItem(op, itemId);
      }
    }
  }

  bool _isSuccessfulMissingDelete(PendingOp op, TaskRemoteError error) {
    return error.statusCode == 404 &&
        (op.operation == 'delete_task_list' ||
            op.operation == 'delete_task' ||
            op.operation == 'delete_task_checklist_item');
  }

  bool _isRetryableStatus(int statusCode) {
    return statusCode == 429 || statusCode >= 500;
  }

  Future<void> _scheduleRetry(
    PendingOp op,
    String errorCode,
    String errorMessage,
  ) async {
    final nextAttempt = _nextAttempt(op.attemptCount);
    await _database.pendingOpsDao.updateAttempt(
      id: op.id,
      attemptCount: op.attemptCount + 1,
      nextAttemptAtUtc: nextAttempt,
      lastErrorCode: errorCode,
      lastErrorMessage: errorMessage,
      state: _isCreationOp(op) ? 'retry' : null,
    );
  }

  Future<bool> _hasPendingChecklistDelete({
    required String parentTaskId,
    required String checklistItemId,
  }) async {
    final operations =
        await (_database.select(_database.pendingOps)..where(
              (row) =>
                  row.accountId.equals(_accountId) &
                  row.entityType.equals('task_checklist_item') &
                  row.taskId.equals(parentTaskId) &
                  row.operation.equals('delete_task_checklist_item'),
            ))
            .get();
    return operations.any(
      (operation) =>
          _request(operation)['checklistItemId']?.toString() == checklistItemId,
    );
  }

  Future<void> _blockOp(
    PendingOp op,
    String errorCode,
    String errorMessage,
  ) async {
    await _database.pendingOpsDao.updateAttempt(
      id: op.id,
      attemptCount: op.attemptCount + 1,
      nextAttemptAtUtc: DateTime.utc(9999, 12, 31),
      lastErrorCode: errorCode,
      lastErrorMessage: errorMessage,
      state: _isCreationOp(op) ? 'failed' : null,
    );
  }

  Future<void> _blockUnknownCreationOutcome(
    PendingOp op,
    String errorMessage,
  ) async {
    await _database.pendingOpsDao.updateAttempt(
      id: op.id,
      attemptCount: op.attemptCount + 1,
      nextAttemptAtUtc: DateTime.utc(9999, 12, 31),
      lastErrorCode: 'creation_outcome_unknown',
      lastErrorMessage:
          'The provider may already have created this item. Automatic replay '
          'was stopped to avoid a duplicate. $errorMessage',
      state: 'recovery_required',
    );
  }

  Future<void> _restoreUnknownCreationOutcomeBlock(PendingOp op) {
    return _database.pendingOpsDao.updateAttempt(
      id: op.id,
      attemptCount: op.attemptCount,
      nextAttemptAtUtc: DateTime.utc(9999, 12, 31),
      lastErrorCode: 'creation_outcome_unknown',
      lastErrorMessage:
          op.lastErrorMessage ??
          'The provider may already have created this item. Automatic replay '
              'was stopped to avoid a duplicate.',
      state: 'recovery_required',
    );
  }

  bool _hasUnknownCreationOutcome(int statusCode) {
    return statusCode == 408 || statusCode >= 500;
  }

  Future<bool> _claimCreation(PendingOp op) async {
    final query = _database.update(_database.pendingOps)
      ..where(
        (row) =>
            row.id.equals(op.id) &
            row.state.equals(op.state) &
            row.attemptCount.equals(op.attemptCount) &
            row.requestJson.equals(op.requestJson) &
            row.updatedAtUtc.equals(op.updatedAtUtc),
      );
    return await query.write(
          const PendingOpsCompanion(state: Value('in_progress')),
        ) ==
        1;
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
    if (op.taskListId == null) {
      return;
    }
    final compareWithoutRevision =
        baselineUpdatedUtc == null &&
        _apiClient is RevisionlessTaskListConflictClient;
    if (baselineUpdatedUtc == null && !compareWithoutRevision) return;

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
    final normalizedBaseline = _normalizeTaskListConflictSnapshot(baselineJson);
    final normalizedCurrent = _normalizeTaskListConflictSnapshot(
      current.rawJson,
    );
    final conflict = const ConflictDetector().detect(
      entityType: 'task_list',
      entityId: op.taskListId!,
      localPendingFields: pendingFields,
      lastServerJson: normalizedBaseline,
      currentServerJson: normalizedCurrent,
      baselineUpdatedUtc: baselineUpdatedUtc,
      currentUpdatedUtc: current.updated,
      compareWithoutRevision: compareWithoutRevision,
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

    final local = op.baselineRawJson == null
        ? await (_database.select(_database.tasks)..where(
                (row) =>
                    row.accountId.equals(_accountId) &
                    row.taskListId.equals(op.taskListId!) &
                    row.id.equals(op.taskId!),
              ))
              .getSingleOrNull()
        : null;
    if (op.baselineRawJson == null && local == null) return;

    final current = await _apiClient.getTask(
      taskListId: op.taskListId!,
      taskId: op.taskId!,
    );
    final baselineJson = op.baselineRawJson == null
        ? _jsonObject(local!.rawJson)
        : _jsonObject(op.baselineRawJson!);
    final normalizedBaseline = _normalizeTaskConflictSnapshot(baselineJson);
    final normalizedCurrent = _normalizeTaskConflictSnapshot(current.rawJson);
    final conflict = const ConflictDetector().detect(
      entityType: 'task',
      entityId: op.taskId!,
      localPendingFields: pendingFields,
      lastServerJson: normalizedBaseline,
      currentServerJson: normalizedCurrent,
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

  Map<String, Object?> _normalizeTaskConflictSnapshot(
    Map<String, Object?> snapshot,
  ) {
    final client = _apiClient;
    return client is TaskConflictSnapshotNormalizer
        ? (client as TaskConflictSnapshotNormalizer)
              .normalizeTaskConflictSnapshot(snapshot)
        : snapshot;
  }

  Map<String, Object?> _normalizeTaskListConflictSnapshot(
    Map<String, Object?> snapshot,
  ) {
    final client = _apiClient;
    return client is TaskConflictSnapshotNormalizer
        ? (client as TaskConflictSnapshotNormalizer)
              .normalizeTaskListConflictSnapshot(snapshot)
        : snapshot;
  }

  Future<void> _ensureTaskListUnchanged(PendingOp op, String action) async {
    final baselineUpdatedUtc = _parseUtc(op.baselineUpdatedUtc);
    if (op.taskListId == null) {
      return;
    }
    final compareWithoutRevision =
        baselineUpdatedUtc == null &&
        _apiClient is RevisionlessTaskListConflictClient;
    if (baselineUpdatedUtc == null && !compareWithoutRevision) return;

    final current = await _apiClient.getTaskList(op.taskListId!);
    final baselineRawJson = op.baselineRawJson;
    final contentChanged =
        compareWithoutRevision &&
        baselineRawJson != null &&
        !const DeepCollectionEquality().equals(
          _semanticTaskListConflictSnapshot(_jsonObject(baselineRawJson)),
          _semanticTaskListConflictSnapshot(current.rawJson),
        );
    final revisionChanged =
        baselineUpdatedUtc != null &&
        _remoteChangedAfterBaseline(current.updated, baselineUpdatedUtc);
    if (contentChanged || revisionChanged) {
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
    final baselineRawJson = op.baselineRawJson;
    final contentChanged =
        baselineRawJson != null &&
        !const DeepCollectionEquality().equals(
          _semanticTaskConflictSnapshot(_jsonObject(baselineRawJson)),
          _semanticTaskConflictSnapshot(current.rawJson),
        );
    final revisionChanged = _remoteChangedAfterBaseline(
      current.updated,
      baselineUpdatedUtc,
    );
    if (contentChanged || revisionChanged) {
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
    final request = _request(op);
    if (request.containsKey(_childTaskConflictBaselinesKey)) {
      await _ensureChildTaskSnapshotsUnchanged(op, action, request);
      return;
    }
    final childBaseline = request[_childTaskConflictBaselineKey]?.toString();
    final baselineUpdatedUtc =
        _parseUtc(childBaseline) ?? _parseUtc(op.baselineUpdatedUtc);
    if (baselineUpdatedUtc == null &&
        _apiClient is RevisionlessTaskListConflictClient) {
      await _blockConflict(
        op,
        'Remote tasks in this list cannot be verified against the local '
        '$action baseline.',
      );
    }
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

  Future<void> _ensureChildTaskSnapshotsUnchanged(
    PendingOp op,
    String action,
    Map<String, Object?> request,
  ) async {
    if (op.taskListId == null) return;
    final encodedBaselines = request[_childTaskConflictBaselinesKey];
    if (encodedBaselines is! Map) return;
    final baselines = <String, Map<String, Object?>>{
      for (final entry in encodedBaselines.entries)
        if (entry.value is Map)
          entry.key.toString(): (entry.value as Map).cast<String, Object?>(),
    };
    final currentTasks = <String, TaskDto>{};
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
      );
      for (final task in page.items) {
        currentTasks[task.id] = task;
      }
      pageToken = page.nextPageToken;
    } while (pageToken != null && pageToken.isNotEmpty);

    var changed = baselines.length != currentTasks.length;
    if (!changed) {
      for (final entry in baselines.entries) {
        final current = currentTasks[entry.key];
        if (current == null) {
          changed = true;
          break;
        }
        final baselineUpdatedUtc = _parseUtc(
          entry.value['updatedUtc']?.toString(),
        );
        final baselineRaw = entry.value['rawJson'];
        final revisionChanged =
            baselineUpdatedUtc != null &&
            _remoteChangedAfterBaseline(current.updated, baselineUpdatedUtc);
        final contentChanged =
            baselineRaw is Map &&
            !const DeepCollectionEquality().equals(
              _semanticTaskConflictSnapshot(
                baselineRaw.cast<String, Object?>(),
              ),
              _semanticTaskConflictSnapshot(current.rawJson),
            );
        if (revisionChanged || contentChanged) {
          changed = true;
          break;
        }
      }
    }
    if (changed) {
      await _blockConflict(
        op,
        'Remote task in list changed since local $action was queued.',
      );
    }
  }

  Map<String, Object?> _semanticTaskConflictSnapshot(
    Map<String, Object?> snapshot,
  ) {
    final semantic = Map<String, Object?>.from(
      _normalizeTaskConflictSnapshot(snapshot),
    );
    semantic.removeWhere((key, _) => _taskRevisionFields.contains(key));
    if (semantic.containsKey('notes')) semantic.remove('body');
    if (semantic.containsKey('microsoftDueDateTime')) {
      semantic.remove('dueDateTime');
    }
    if (semantic.containsKey('microsoftStartDateTime')) {
      semantic.remove('startDateTime');
    }
    if (semantic.containsKey('microsoftReminderDateTime')) {
      semantic.remove('reminderDateTime');
    }
    if (semantic.containsKey('microsoftCompletedDateTime')) {
      semantic.remove('completedDateTime');
    }
    if (semantic.containsKey('microsoftIsReminderOn')) {
      semantic.remove('isReminderOn');
    }
    return semantic;
  }

  Map<String, Object?> _semanticTaskListConflictSnapshot(
    Map<String, Object?> snapshot,
  ) {
    final semantic = Map<String, Object?>.from(
      _normalizeTaskListConflictSnapshot(snapshot),
    );
    semantic.removeWhere((key, _) => _taskListRevisionFields.contains(key));
    if (semantic.containsKey('title')) semantic.remove('displayName');
    return semantic;
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

const _childTaskConflictBaselineKey =
    '_busymaxChildTaskConflictBaselineUpdatedUtc';
const _childTaskConflictBaselinesKey = '_busymaxChildTaskConflictBaselines';

const _taskRevisionFields = {
  'etag',
  '@odata.etag',
  'updated',
  'lastModifiedDateTime',
  'bodyLastModifiedDateTime',
};

const _taskListRevisionFields = {
  'etag',
  '@odata.etag',
  'updated',
  'lastModifiedDateTime',
};

const _pendingOpReferenceKeys = {
  'id',
  'parent',
  'previous',
  'taskId',
  'taskListId',
  'tasklist',
  'destinationTasklist',
  'checklistItemId',
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

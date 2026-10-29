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
import 'domain_sync_schedule.dart';
import 'task_mutation_barrier.dart';
import '../task_lists/data/task_lists_repository.dart';
import '../tasks/data/tasks_repository.dart';
import '../tasks/domain/task_checklist_item.dart';
import '../tasks/domain/google_task_assignment_policy.dart';

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
    final policy = DomainSyncPolicy(_database, nowUtc: _nowUtc);
    await policy.checkCooldown(_accountId, SyncDomain.tasks);
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
        await policy.checkCooldown(_accountId, SyncDomain.tasks);
        if (handledIds.contains(originalOp.id)) continue;
        final op = await _readOp(originalOp.id);
        if (op == null || !_isTaskOp(op)) {
          handledIds.add(originalOp.id);
          continue;
        }
        if (op.dependsOnOpId != null && await _opExists(op.dependsOnOpId!)) {
          continue;
        }
        if (await _waitsForTaskMutationBarrier(op)) continue;
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
          if (_isReconcilableWrite(op) && op.state != 'in_progress') {
            // This attempt may have failed while reading a previous unknown
            // write's result. An unsent read does not retract that write.
            await (_database.update(_database.pendingOps)
                  ..where((row) => row.id.equals(op.id)))
                .write(const PendingOpsCompanion(state: Value('retry')));
          }
          await _scheduleRetry(
            op,
            error.code,
            'The request was not sent and can be retried safely.',
          );
          if (await policy.recordFailureCooldown(
            _accountId,
            SyncDomain.tasks,
            error,
          )) {
            rethrow;
          }
        } on TaskRemoteError catch (error) {
          if (_isSuccessfulMissingDelete(op, error)) {
            await _applyDeleteSideEffect(op);
            await _database.pendingOpsDao.deleteOp(op.id);
            applied += 1;
          } else if (_isCreationOp(op) &&
              _hasUnknownCreationOutcome(error.statusCode)) {
            await _blockUnknownCreationOutcome(op, error.message);
          } else if (error.retryable || _isRetryableStatus(error.statusCode)) {
            await _scheduleRetry(
              op,
              error.statusCode.toString(),
              error.message,
              retryAfter: error.retryAfter,
            );
          } else {
            await _blockOp(op, error.statusCode.toString(), error.message);
          }
          if (await policy.recordFailureCooldown(
            _accountId,
            SyncDomain.tasks,
            error,
          )) {
            rethrow;
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

  Future<bool> _waitsForTaskMutationBarrier(PendingOp op) async {
    if (op.operation != 'delete_task_list' &&
        op.operation != 'clear_completed_tasks') {
      return false;
    }
    final taskListId = op.taskListId;
    if (taskListId == null) return false;
    final operations = await (_database.select(
      _database.pendingOps,
    )..where((row) => row.accountId.equals(_accountId))).get();
    final capturedIds = _request(op)[taskBarrierOperationIdsKey];
    return operations.any(
      (candidate) =>
          candidate.id != op.id &&
          ((capturedIds is List && capturedIds.contains(candidate.id)) ||
              (taskOperationTouchesList(candidate, taskListId) &&
                  (op.operation != 'clear_completed_tasks' ||
                      candidate.operation != 'clear_completed_tasks'))),
    );
  }

  bool _isCreationOp(PendingOp op) {
    return op.operation == 'create_task_list' ||
        op.operation == 'create_task' ||
        op.operation == 'create_task_checklist_item';
  }

  bool _isReconcilableWrite(PendingOp op) =>
      op.operation == 'patch_task' ||
      op.operation == 'update_task' ||
      op.operation == 'patch_task_checklist_item';

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
            candidate.entityType != 'task_list') {
          continue;
        }
        dependencyIds.add(candidate.id);
        dependents.add(candidate);
        foundDependent = true;
      }
    }
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
      final initializesServerBaseline =
          completedOp.operation == 'create_task_list';
      final baseline = initializesServerBaseline
          ? Map<String, Object?>.from(serverSnapshot)
          : _normalizeTaskListConflictSnapshot(
              _jsonObject(dependent.baselineRawJson ?? '{}'),
            );
      if (!initializesServerBaseline) {
        for (final field in acknowledged.keys) {
          if (serverSnapshot.containsKey(field)) {
            baseline[field] = serverSnapshot[field];
          } else {
            baseline.remove(field);
          }
        }
      }
      await (_database.update(
        _database.pendingOps,
      )..where((row) => row.id.equals(dependent.id))).write(
        PendingOpsCompanion(
          requestJson: Value(jsonEncode(dependentRequest)),
          baselineRawJson: Value(jsonEncode(baseline)),
          baselineUpdatedUtc:
              !initializesServerBaseline && serverList.updated == null
              ? const Value.absent()
              : Value(serverList.updated?.toUtc().toIso8601String()),
          updatedAtUtc: Value(_now()),
        ),
      );
    }
    return true;
  }

  Future<void> _deleteTaskList(PendingOp op) async {
    await _ensureTaskListUnchanged(op, 'delete');
    await _ensureNoTaskInListChangedAfterBaseline(op, 'delete');
    if (await _waitsForTaskMutationBarrier(op)) {
      throw const _PendingOpBlocked();
    }
    await _apiClient.deleteTaskList(op.taskListId!);
    await _database.taskListsDao.deleteTaskList(_accountId, op.taskListId!);
  }

  Future<void> _createTask(PendingOp op) async {
    final request = _request(op);
    if (request['parent'] case final Object parentId) {
      final parentPolicy = await _googleAssignment(parentId.toString());
      if (parentPolicy?.isAssigned == true) {
        await _blockUnsupportedAssignedTask(op);
      }
      if (parentPolicy != null) {
        final remoteParent = await _apiClient.getTask(
          taskListId: op.taskListId!,
          taskId: parentId.toString(),
        );
        if (_remoteGoogleAssignment(remoteParent).isAssigned) {
          await _blockUnsupportedAssignedTask(op);
        }
      }
    }
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
        await _rebasePendingListDeletionChildBaselines(op, serverTask: dto);
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
    final request = _request(op);
    GoogleTaskAssignmentPolicy? assignment;
    if (request.containsKey('notes')) {
      assignment = await _googleAssignment(op.taskId!);
      if (assignment?.isFromDocument == true &&
          request['notes']?.toString().isNotEmpty == true) {
        await _blockUnsupportedAssignedTask(op);
      }
    }
    final current = await _ensureNoTaskConflict(op, request);
    if (current != null &&
        _taskPostconditionEstablished(op, current, request)) {
      await _applyTaskEditResult(op, current);
      return;
    }
    if (assignment != null && request['notes']?.toString().isNotEmpty == true) {
      final remote =
          current ??
          await _apiClient.getTask(
            taskListId: op.taskListId!,
            taskId: op.taskId!,
          );
      if (_remoteGoogleAssignment(remote).isFromDocument) {
        await _blockUnsupportedAssignedTask(op);
      }
    }
    final dto = await _dispatchTaskMutation(
      op,
      () => _apiClient.patchTask(
        taskListId: op.taskListId!,
        taskId: op.taskId!,
        patch: TaskPatch.fields(_request(op)),
      ),
    );
    await _applyTaskEditResult(op, dto);
  }

  Future<void> _updateTask(PendingOp op) async {
    final request = _request(op);
    GoogleTaskAssignmentPolicy? assignment;
    if (request.containsKey('notes')) {
      assignment = await _googleAssignment(op.taskId!);
      if (assignment?.isFromDocument == true &&
          request['notes']?.toString().isNotEmpty == true) {
        await _blockUnsupportedAssignedTask(op);
      }
    }
    final current = await _ensureNoTaskConflict(op, request);
    if (current != null &&
        _taskPostconditionEstablished(op, current, request)) {
      await _applyTaskEditResult(op, current);
      return;
    }
    if (assignment != null && request['notes']?.toString().isNotEmpty == true) {
      final remote =
          current ??
          await _apiClient.getTask(
            taskListId: op.taskListId!,
            taskId: op.taskId!,
          );
      if (_remoteGoogleAssignment(remote).isFromDocument) {
        await _blockUnsupportedAssignedTask(op);
      }
    }
    final dto = await _dispatchTaskMutation(
      op,
      () => _apiClient.updateTask(
        taskListId: op.taskListId!,
        taskId: op.taskId!,
        replacement: TaskPut.fields(_request(op)),
      ),
    );
    await _applyTaskEditResult(op, dto);
  }

  Future<void> _markTaskWriteDispatched(PendingOp op) async {
    await (_database.update(_database.pendingOps)
          ..where((row) => row.id.equals(op.id)))
        .write(const PendingOpsCompanion(state: Value('in_progress')));
  }

  Future<TaskDto> _dispatchTaskMutation(
    PendingOp op,
    Future<TaskDto> Function() mutation,
  ) async {
    await _markTaskWriteDispatched(op);
    try {
      return await mutation();
    } on TaskRemoteError catch (error) {
      if (error.statusCode == 429) {
        // Only a rejection of this mutation disproves its dispatch outcome.
        // A throttled reconciliation read must retain the earlier uncertainty.
        await (_database.update(_database.pendingOps)
              ..where((row) => row.id.equals(op.id)))
            .write(const PendingOpsCompanion(state: Value('retry')));
      }
      rethrow;
    }
  }

  Future<void> _applyTaskEditResult(PendingOp op, TaskDto serverTask) async {
    await _database.transaction(() async {
      final hasDependent = await _rebaseDependentTaskMutations(op, serverTask);
      await _rebasePendingListDeletionChildBaselines(
        op,
        serverTask: serverTask,
      );
      if (hasDependent) {
        await _database.pendingOpsDao.deleteOp(op.id);
        return;
      }
      await _database.tasksDao.upsertTask(
        taskFromDto(_accountId, op.taskListId!, serverTask, _now()),
      );
      await _database.pendingOpsDao.deleteOp(op.id);
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
    // Checklist operations need the parent's identity, but their baselines and
    // optimistic projection belong to the item. They do not protect stale
    // parent fields from an acknowledged task response. Keep traversing their
    // dependencies above, and rewrite their identities separately as before.
    final taskMutations = dependents
        .where((operation) => operation.entityType == 'task')
        .toList();
    if (taskMutations.isEmpty) {
      return false;
    }

    final serverSnapshot = _normalizeTaskConflictSnapshot(serverTask.rawJson);
    for (final dependent in taskMutations) {
      final initializesServerBaseline =
          completedOp.operation == 'create_task' &&
          dependent.baselineUpdatedUtc == null;
      final baseline = _rebaseAcknowledgedTaskSnapshot(
        completedOp,
        _jsonObject(dependent.baselineRawJson ?? '{}'),
        serverSnapshot,
        initialize: initializesServerBaseline,
      );
      final usesWholeTaskConflictBoundary =
          dependent.operation == 'move_task' ||
          dependent.operation == 'delete_task';
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

  Map<String, Object?> _rebaseAcknowledgedTaskSnapshot(
    PendingOp completedOp,
    Map<String, Object?> originalBaseline,
    Map<String, Object?> normalizedServerSnapshot, {
    bool initialize = false,
  }) {
    if (initialize) {
      return Map<String, Object?>.from(normalizedServerSnapshot);
    }

    final completedRequest = _request(completedOp);
    final requestedFields =
        completedOp.operation == 'create_task' &&
            completedRequest['body'] is Map
        ? (completedRequest['body'] as Map).keys.map((key) => key.toString())
        : completedRequest.keys;
    final acknowledgedFields = <String>{
      for (final field in requestedFields)
        if (!_taskOperationArgumentFields.contains(field)) field,
    };
    final baseline = _normalizeTaskConflictSnapshot(originalBaseline);

    void acknowledgeProviderFields(Iterable<String> fields) {
      for (final field in fields) {
        if (baseline.containsKey(field) ||
            normalizedServerSnapshot.containsKey(field)) {
          acknowledgedFields.add(field);
        }
      }
    }

    if (acknowledgedFields.contains('status')) {
      acknowledgeProviderFields({
        'completed',
        'microsoftCompletedDateTime',
        'microsoftCompletedTimeZone',
      });
    }
    if (acknowledgedFields.contains('due') ||
        acknowledgedFields.contains('microsoftDueDateTime')) {
      acknowledgeProviderFields({
        'due',
        'microsoftDueDateTime',
        'microsoftDueTimeZone',
      });
    }
    if (completedOp.operation == 'move_task') {
      acknowledgedFields.addAll({'parent', 'position'});
    }

    // Keep untouched fields at their original values so an independent
    // remote change remains visible to a later whole-task check. Missing
    // acknowledged values mean the provider cleared/omitted that field; do
    // not manufacture null aliases from another provider's schema.
    for (final field in acknowledgedFields) {
      if (normalizedServerSnapshot.containsKey(field)) {
        baseline[field] = normalizedServerSnapshot[field];
      } else {
        baseline.remove(field);
      }
    }
    return baseline;
  }

  Future<void> _rebasePendingListDeletionChildBaselines(
    PendingOp completedOp, {
    TaskDto? serverTask,
  }) async {
    await _rebasePendingClearCompletedBaselines(completedOp, serverTask);
    final sourceListId = completedOp.taskListId;
    final taskId = serverTask?.id ?? completedOp.taskId;
    if (sourceListId == null || taskId == null) return;

    final request = _request(completedOp);
    final destinationListId = completedOp.operation == 'move_task'
        ? request['destinationTasklist']?.toString() ?? sourceListId
        : sourceListId;
    final listDeletes =
        await (_database.select(_database.pendingOps)..where(
              (row) =>
                  row.accountId.equals(_accountId) &
                  row.entityType.equals('task_list') &
                  row.operation.equals('delete_task_list'),
            ))
            .get();

    for (final listDelete in listDeletes) {
      final deleteRequest = _request(listDelete);
      final encoded = deleteRequest[_childTaskConflictBaselinesKey];
      if (encoded is! Map) continue;
      final baselines = <String, Object?>{
        for (final entry in encoded.entries) entry.key.toString(): entry.value,
      };
      var changed = false;

      void removeTask() {
        changed = baselines.remove(taskId) != null || changed;
        final localId = completedOp.localTempId;
        if (localId != null) {
          changed = baselines.remove(localId) != null || changed;
        }
      }

      void putServerTask({required bool initialize}) {
        final task = serverTask;
        if (task == null) return;
        final existing = baselines[taskId];
        if (!initialize && existing is! Map) return;
        final existingEntry = existing is Map
            ? existing.cast<String, Object?>()
            : const <String, Object?>{};
        final baselineRaw = existingEntry['rawJson'];
        final normalizedServer = _normalizeTaskConflictSnapshot(task.rawJson);
        // An optimistic incoming move may already have an approved child
        // snapshot. Keep its untouched fields even when the move response
        // also contains an independent provider edit.
        final rebasedRaw =
            (initialize && existing is! Map) || baselineRaw is! Map
            ? Map<String, Object?>.from(normalizedServer)
            : _rebaseAcknowledgedTaskSnapshot(
                completedOp,
                baselineRaw.cast<String, Object?>(),
                normalizedServer,
              );
        baselines[taskId] = {
          'updatedUtc': task.updated?.toUtc().toIso8601String(),
          'rawJson': rebasedRaw,
        };
        changed = true;
      }

      final deletingSource = listDelete.taskListId == sourceListId;
      final deletingDestination = listDelete.taskListId == destinationListId;
      switch (completedOp.operation) {
        case 'create_task':
          if (deletingSource) putServerTask(initialize: true);
          break;
        case 'patch_task':
        case 'update_task':
          if (deletingSource) putServerTask(initialize: false);
          break;
        case 'delete_task':
          if (deletingSource) removeTask();
          break;
        case 'move_task':
          if (sourceListId == destinationListId) {
            if (deletingSource) putServerTask(initialize: false);
          } else {
            if (deletingSource) removeTask();
            if (deletingDestination) putServerTask(initialize: true);
          }
          break;
      }
      if (!changed) continue;
      deleteRequest[_childTaskConflictBaselinesKey] = baselines;
      await (_database.update(
        _database.pendingOps,
      )..where((row) => row.id.equals(listDelete.id))).write(
        PendingOpsCompanion(
          requestJson: Value(jsonEncode(deleteRequest)),
          updatedAtUtc: Value(_now()),
        ),
      );
    }
  }

  Future<void> _rebasePendingClearCompletedBaselines(
    PendingOp completed,
    TaskDto? serverTask,
  ) async {
    if (serverTask == null || completed.taskListId == null) return;
    final destinationListId = completed.operation == 'move_task'
        ? _request(completed)['destinationTasklist']?.toString() ??
              completed.taskListId!
        : completed.taskListId!;
    final clears =
        await (_database.select(_database.pendingOps)..where(
              (row) =>
                  row.accountId.equals(_accountId) &
                  (row.taskListId.equals(completed.taskListId!) |
                      row.taskListId.equals(destinationListId)) &
                  row.operation.equals('clear_completed_tasks'),
            ))
            .get();
    for (final clear in clears) {
      final request = _request(clear);
      final barriers = request[taskBarrierOperationIdsKey];
      if (barriers is! List || !barriers.contains(completed.id)) continue;
      final encoded = request[_completedTaskBaselinesKey];
      if (encoded is! Map) continue;
      final baselines = encoded.cast<String, Object?>();
      final originalId = completed.localTempId ?? completed.taskId;
      final entry = baselines[serverTask.id] ?? baselines[originalId];
      if (entry is! Map) continue;
      if (clear.taskListId != destinationListId) {
        // A captured move took this approved member out of the source list.
        // The destination never gains members that were absent at approval.
        baselines.remove(serverTask.id);
        baselines.remove(originalId);
      } else {
        final baselineRaw = entry['rawJson'];
        if (baselineRaw is! Map) continue;
        final normalizedServer = _normalizeTaskConflictSnapshot(
          serverTask.rawJson,
        );
        final rebased = _rebaseAcknowledgedTaskSnapshot(
          completed,
          baselineRaw.cast<String, Object?>(),
          normalizedServer,
          initialize: completed.operation == 'create_task',
        );
        if (originalId != serverTask.id) baselines.remove(originalId);
        baselines[serverTask.id] = {
          'updatedUtc': serverTask.updated?.toUtc().toIso8601String(),
          'rawJson': rebased,
        };
      }
      request[_completedTaskBaselinesKey] = baselines;
      await (_database.update(
        _database.pendingOps,
      )..where((row) => row.id.equals(clear.id))).write(
        PendingOpsCompanion(
          requestJson: Value(jsonEncode(request)),
          updatedAtUtc: Value(_now()),
        ),
      );
    }
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
    final current = await _ensureTaskUnchanged(op, 'delete');
    if (await _googleAssignment(op.taskId!) != null) {
      final remote =
          current ??
          await _apiClient.getTask(
            taskListId: op.taskListId!,
            taskId: op.taskId!,
          );
      if (_remoteGoogleAssignment(remote).isAssigned &&
          _request(op)['confirmedAssignedSourceDeletion'] != true) {
        await _blockUnsupportedAssignedTask(op);
      }
    }
    await _apiClient.deleteTask(taskListId: op.taskListId!, taskId: op.taskId!);
    await _database.transaction(() async {
      await _rebasePendingListDeletionChildBaselines(op);
      await _database.tasksDao.deleteTask(
        _accountId,
        op.taskListId!,
        op.taskId!,
      );
      await _database.pendingOpsDao.deleteOp(op.id);
    });
  }

  Future<void> _moveTask(PendingOp op) async {
    final request = _request(op);
    GoogleTaskAssignmentPolicy? childPolicy;
    if (request['parent'] case final Object parentId) {
      childPolicy = await _googleAssignment(op.taskId!);
      final parentPolicy = await _googleAssignment(parentId.toString());
      if (childPolicy?.isAssigned == true || parentPolicy?.isAssigned == true) {
        await _blockUnsupportedAssignedTask(op);
      }
    }
    final current = await _ensureTaskUnchanged(op, 'move');
    final destinationTaskListId = request['destinationTasklist']?.toString();
    final targetTaskListId = destinationTaskListId ?? op.taskListId!;
    final parentId = request['parent']?.toString();
    if (childPolicy != null && parentId != null && parentId.isNotEmpty) {
      final remoteChild =
          current ??
          await _apiClient.getTask(
            taskListId: op.taskListId!,
            taskId: op.taskId!,
          );
      final remoteParent = await _apiClient.getTask(
        taskListId: targetTaskListId,
        taskId: parentId,
      );
      if (_remoteGoogleAssignment(remoteChild).isAssigned ||
          _remoteGoogleAssignment(remoteParent).isAssigned) {
        await _blockUnsupportedAssignedTask(op);
      }
    }
    final dto = await _apiClient.moveTask(
      sourceTaskListId: op.taskListId!,
      taskId: op.taskId!,
      parentTaskId: request['parent']?.toString(),
      previousSiblingTaskId: request['previous']?.toString(),
      destinationTaskListId: destinationTaskListId,
    );
    await _database.transaction(() async {
      final hasDependent = await _rebaseDependentTaskMutations(op, dto);
      await _rebasePendingListDeletionChildBaselines(op, serverTask: dto);
      if (hasDependent) {
        // The repository has already moved the visible projection to the tail
        // of the local chain. Applying this intermediate response would move
        // it backwards and erase later local edits.
        await _preserveDependentMoveProjection(op, targetTaskListId);
        await _database.pendingOpsDao.deleteOp(op.id);
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
      await _database.pendingOpsDao.deleteOp(op.id);
    });
  }

  Future<GoogleTaskAssignmentPolicy?> _googleAssignment(String taskId) async {
    final account = await (_database.select(
      _database.accounts,
    )..where((row) => row.id.equals(_accountId))).getSingleOrNull();
    if (account?.provider != 'google') return null;
    final task =
        await (_database.select(_database.tasks)..where(
              (row) => row.accountId.equals(_accountId) & row.id.equals(taskId),
            ))
            .getSingleOrNull();
    return task == null
        ? const GoogleTaskAssignmentPolicy(
            isAssigned: false,
            isFromDocument: false,
          )
        : GoogleTaskAssignmentPolicy.fromJson(task.assignmentInfoJson);
  }

  GoogleTaskAssignmentPolicy _remoteGoogleAssignment(TaskDto task) =>
      GoogleTaskAssignmentPolicy.fromJson(
        task.assignmentInfo == null ? null : jsonEncode(task.assignmentInfo),
      );

  Future<Never> _blockUnsupportedAssignedTask(PendingOp op) async {
    await _blockOp(
      op,
      'unsupported_assigned_task',
      'This operation is not allowed for an assigned Google task.',
    );
    throw const _PendingOpBlocked();
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
    if (await _waitsForTaskMutationBarrier(op)) {
      throw const _PendingOpBlocked();
    }
    await _apiClient.clearCompletedTasks(op.taskListId!);
    final baselines = _request(op)[_completedTaskBaselinesKey];
    await _database.transaction(() async {
      if (baselines is Map) {
        await _rebasePendingListDeletionClearedChildren(op, baselines);
        final rows =
            await (_database.select(_database.tasks)..where(
                  (row) =>
                      row.accountId.equals(_accountId) &
                      row.taskListId.equals(op.taskListId!) &
                      row.id.isIn(baselines.keys.map((id) => id.toString())),
                ))
                .get();
        for (final task in rows) {
          final metadata = _jsonObject(task.providerMetadataJson ?? '{}');
          metadata[acknowledgedTaskHiddenEffectKey] = true;
          await (_database.update(_database.tasks)..where(
                (row) =>
                    row.accountId.equals(_accountId) &
                    row.taskListId.equals(op.taskListId!) &
                    row.id.equals(task.id),
              ))
              .write(
                TasksCompanion(
                  hidden: const Value(true),
                  rawJson: Value(
                    jsonEncode({..._jsonObject(task.rawJson), 'hidden': true}),
                  ),
                  providerMetadataJson: Value(jsonEncode(metadata)),
                ),
              );
        }
      }
      await _database.pendingOpsDao.deleteOp(op.id);
    });
  }

  Future<void> _rebasePendingListDeletionClearedChildren(
    PendingOp completed,
    Map approvedTasks,
  ) async {
    final deletes =
        await (_database.select(_database.pendingOps)..where(
              (row) =>
                  row.accountId.equals(_accountId) &
                  row.taskListId.equals(completed.taskListId!) &
                  row.operation.equals('delete_task_list'),
            ))
            .get();
    for (final deletion in deletes) {
      final request = _request(deletion);
      final barriers = request[taskBarrierOperationIdsKey];
      if (barriers is! List || !barriers.contains(completed.id)) continue;
      final encoded = request[_childTaskConflictBaselinesKey];
      if (encoded is! Map) continue;
      final children = encoded.cast<String, Object?>();
      var changed = false;
      for (final id in approvedTasks.keys.map((id) => id.toString())) {
        final entry = children[id];
        if (entry is! Map || entry['rawJson'] is! Map) continue;
        children[id] = {
          ...entry,
          'rawJson': {...entry['rawJson'] as Map, 'hidden': true},
          // Clear returns no task/revision. Its acknowledged hidden effect can
          // account for a revision advance only while every semantic field
          // still matches this approved snapshot.
          acknowledgedTaskHiddenEffectKey: true,
        };
        changed = true;
      }
      if (!changed) continue;
      request[_childTaskConflictBaselinesKey] = children;
      await (_database.update(
        _database.pendingOps,
      )..where((row) => row.id.equals(deletion.id))).write(
        PendingOpsCompanion(
          requestJson: Value(jsonEncode(request)),
          updatedAtUtc: Value(_now()),
        ),
      );
    }
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
      await _rebaseChecklistDependents(op, item, oldItemId: localId);
      await _overlayChecklistDependents(op);
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
    final current = await _ensureNoChecklistConflict(
      op,
      itemId,
      body.keys.toSet(),
    );
    if (current != null && _checklistPostconditionEstablished(op, current)) {
      await _applyChecklistEditResult(op, itemId, current);
      return;
    }
    await _markTaskWriteDispatched(op);
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
    await _applyChecklistEditResult(op, itemId, item);
  }

  Future<void> _applyChecklistEditResult(
    PendingOp op,
    String itemId,
    TaskChecklistItemDto item,
  ) async {
    await _database.transaction(() async {
      await _replaceChecklistProjectionItem(
        taskListId: op.taskListId!,
        parentTaskId: op.taskId!,
        oldItemId: itemId,
        item: taskChecklistItemFromDto(item),
      );
      await _rebaseChecklistDependents(op, item, oldItemId: itemId);
      await _overlayChecklistDependents(op);
      await _database.pendingOpsDao.deleteOp(op.id);
    });
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
    final current = await _ensureNoChecklistConflict(op, itemId, null);
    if (current != null) {
      await _checklistClient.deleteChecklistItem(
        taskListId: op.taskListId!,
        taskId: op.taskId!,
        checklistItemId: itemId,
      );
    }
    await _removeChecklistProjectionItem(op, itemId);
  }

  Future<TaskChecklistItemDto?> _ensureNoChecklistConflict(
    PendingOp op,
    String itemId,
    Set<String>? touchedFields,
  ) async {
    final baselineJson = op.baselineRawJson;
    if (baselineJson == null) {
      await _blockConflict(
        op,
        'The original checklist item cannot be verified. Local changes were retained.',
      );
    }
    TaskChecklistItemDto? current;
    String? pageToken;
    do {
      final page = await _checklistClient.listChecklistItemsPage(
        taskListId: op.taskListId!,
        taskId: op.taskId!,
        pageToken: pageToken,
      );
      current ??= page.items.firstWhereOrNull((item) => item.id == itemId);
      pageToken = page.nextPageToken;
    } while (pageToken != null && pageToken.isNotEmpty);
    if (current == null) {
      if (touchedFields == null) return null;
      await _blockConflict(
        op,
        'The remote checklist item was deleted. Local changes were retained.',
      );
    }
    final baseline = _checklistConflictSnapshot(_jsonObject(baselineJson));
    final actual = _checklistConflictSnapshot(
      taskChecklistItemFromDto(current).toJson(),
    );
    if (touchedFields != null &&
        _checklistPostconditionEstablished(op, current)) {
      return current;
    }
    final fields = touchedFields ?? {...baseline.keys, ...actual.keys};
    final changed =
        fields
            .where(
              (field) => !const DeepCollectionEquality().equals(
                baseline[field],
                actual[field],
              ),
            )
            .toList()
          ..sort();
    if (changed.isNotEmpty) {
      await _blockConflict(
        op,
        'Remote checklist item changed fields: $changed',
      );
    }
    return current;
  }

  bool _checklistPostconditionEstablished(
    PendingOp op,
    TaskChecklistItemDto current,
  ) {
    if (op.state != 'in_progress') return false;
    final body = _requestBody(_request(op));
    if (body.isEmpty) return false;
    // The adapter projects Graph's defaults and timestamp representations.
    // Only requested item fields establish this update; a matching sibling or
    // an unrelated provider change cannot acknowledge it.
    final actual = _checklistConflictSnapshot(
      taskChecklistItemFromDto(current).toJson(),
    );
    return body.entries.every(
      (entry) =>
          const DeepCollectionEquality().equals(entry.value, actual[entry.key]),
    );
  }

  Map<String, Object?> _checklistConflictSnapshot(
    Map<String, Object?> snapshot,
  ) => {
    for (final entry in snapshot.entries)
      if (entry.key != 'id' &&
          !entry.key.startsWith('_busymax') &&
          !entry.key.startsWith('@odata.') &&
          entry.value != null)
        entry.key: entry.value,
  };

  Future<void> _rebaseChecklistDependents(
    PendingOp completed,
    TaskChecklistItemDto server, {
    String? oldItemId,
  }) async {
    final operations =
        await (_database.select(_database.pendingOps)..where(
              (row) =>
                  row.accountId.equals(_accountId) &
                  row.entityType.equals('task_checklist_item') &
                  row.taskId.equals(completed.taskId!),
            ))
            .get();
    final completedIds = <String>{completed.id};
    var expanded = true;
    while (expanded) {
      expanded = false;
      for (final dependent in operations) {
        if (completedIds.contains(dependent.id) ||
            !completedIds.contains(dependent.dependsOnOpId)) {
          continue;
        }
        final itemId = _request(dependent)['checklistItemId']?.toString();
        if (itemId != server.id && itemId != oldItemId) continue;
        completedIds.add(dependent.id);
        expanded = true;
        final baseline = completed.operation == 'create_task_checklist_item'
            ? taskChecklistItemFromDto(server).toJson()
            : _jsonObject(dependent.baselineRawJson ?? '{}');
        if (completed.operation != 'create_task_checklist_item') {
          final actual = taskChecklistItemFromDto(server).toJson();
          final fields = _requestBody(_request(completed)).keys.toSet();
          if (fields.contains('isChecked')) fields.add('checkedDateTime');
          for (final field in fields) {
            if (actual.containsKey(field)) {
              baseline[field] = actual[field];
            } else {
              baseline.remove(field);
            }
          }
          baseline['id'] = server.id;
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
    }
  }

  Future<void> _overlayChecklistDependents(PendingOp completed) async {
    final task =
        await (_database.select(_database.tasks)..where(
              (row) =>
                  row.accountId.equals(_accountId) &
                  row.taskListId.equals(completed.taskListId!) &
                  row.id.equals(completed.taskId!),
            ))
            .getSingleOrNull();
    if (task == null) return;
    final remaining =
        await (_database.select(_database.pendingOps)
              ..where(
                (row) =>
                    row.accountId.equals(_accountId) &
                    row.entityType.equals('task_checklist_item') &
                    row.taskId.equals(completed.taskId!) &
                    row.id.equals(completed.id).not(),
              )
              ..orderBy([
                (row) => OrderingTerm.asc(row.createdAtUtc),
                (row) => OrderingTerm.asc(row.id),
              ]))
            .get();
    final local = decodeTaskChecklistItems(task.microsoftChecklistItemsJson);
    final merged = mergeTaskChecklistProjection(
      serverItems: [
        for (final item in local)
          TaskChecklistItemDto(
            id: item.id,
            title: item.title,
            completed: item.completed,
            rawJson: item.toJson(),
          ),
      ],
      localItems: local,
      pendingOperations: remaining,
    );
    await (_database.update(_database.tasks)..where(
          (row) =>
              row.accountId.equals(_accountId) &
              row.taskListId.equals(completed.taskListId!) &
              row.id.equals(completed.taskId!),
        ))
        .write(
          TasksCompanion(
            microsoftChecklistItemsJson: Value(
              encodeTaskChecklistItems(merged),
            ),
          ),
        );
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
      await _rebasePendingListDeletionChildBaselines(
        createOperation,
        serverTask: serverTask,
      );
      // A queued cross-list move has already relocated the temporary row.
      // Keep that visible projection in place while replacing its identity.
      final projectionTaskListId = localTask?.taskListId ?? taskListId;
      await _database.tasksDao.upsertTask(
        taskFromDto(_accountId, projectionTaskListId, serverTask, _now()),
      );
      final acknowledged =
          await (_database.select(_database.tasks)..where(
                (row) =>
                    row.accountId.equals(_accountId) &
                    row.taskListId.equals(projectionTaskListId) &
                    row.id.equals(serverTask.id),
              ))
              .getSingle();
      final metadata = <String, Object?>{
        if (localTask?.providerMetadataJson case final String encoded)
          ..._jsonObject(encoded),
        if (acknowledged.providerMetadataJson case final String encoded)
          ..._jsonObject(encoded),
      };
      final previousAliases = metadata['_busymaxTaskIdAliases'];
      metadata['_busymaxTaskIdAliases'] = <String>{
        if (previousAliases is List)
          for (final alias in previousAliases)
            if (alias is String && alias.isNotEmpty) alias,
        tempTaskId,
      }.toList();
      await (_database.update(_database.tasks)..where(
            (row) =>
                row.accountId.equals(_accountId) &
                row.taskListId.equals(projectionTaskListId) &
                row.id.equals(serverTask.id),
          ))
          .write(
            TasksCompanion(providerMetadataJson: Value(jsonEncode(metadata))),
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
      await _database.transaction(() async {
        await _rebasePendingListDeletionChildBaselines(op);
        await _database.tasksDao.deleteTask(
          _accountId,
          op.taskListId!,
          op.taskId!,
        );
      });
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
    String errorMessage, {
    Duration? retryAfter,
  }) async {
    var nextAttempt = _nextAttempt(op.attemptCount);
    if (retryAfter != null) {
      final providerNotBefore = _nowUtc().add(retryAfter);
      if (providerNotBefore.isAfter(nextAttempt)) {
        nextAttempt = providerNotBefore;
      }
    }
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
    // A denied reconciliation read cannot disprove an earlier write dispatch.
    // Retain that marker alongside blocked feedback and manual-retry timing.
    // A first rejected task mutation still has no uncertain prior attempt.
    await _database.pendingOpsDao.updateAttempt(
      id: op.id,
      attemptCount: op.attemptCount + 1,
      nextAttemptAtUtc: DateTime.utc(9999, 12, 31),
      lastErrorCode: errorCode,
      lastErrorMessage: errorMessage,
      state:
          _isCreationOp(op) ||
              ((op.operation == 'patch_task' ||
                      op.operation == 'update_task') &&
                  op.state != 'in_progress')
          ? 'failed'
          : null,
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

  Future<TaskDto?> _ensureNoTaskConflict(
    PendingOp op,
    Map<String, Object?> pendingFields,
  ) async {
    final baselineUpdatedUtc = _parseUtc(op.baselineUpdatedUtc);
    if (op.state == 'recovery_required') {
      await _blockUnknownRecurringCompletion(op);
    }
    if ((baselineUpdatedUtc == null && op.state != 'in_progress') ||
        op.taskListId == null ||
        op.taskId == null) {
      return null;
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
    if (op.baselineRawJson == null && local == null) return null;

    final current = await _apiClient.getTask(
      taskListId: op.taskListId!,
      taskId: op.taskId!,
    );
    final baselineJson = op.baselineRawJson == null
        ? _jsonObject(local!.rawJson)
        : _jsonObject(op.baselineRawJson!);
    final normalizedBaseline = _normalizeTaskConflictSnapshot(baselineJson);
    final normalizedCurrent = _normalizeTaskConflictSnapshot(current.rawJson);
    if (op.state == 'in_progress' &&
        pendingFields.containsKey('status') &&
        (current.rawJson['recurrence'] != null ||
            baselineJson['recurrence'] != null)) {
      await _blockUnknownRecurringCompletion(op);
    }
    if (_taskPostconditionEstablished(op, current, pendingFields)) {
      return current;
    }
    final conflict = const ConflictDetector().detect(
      entityType: 'task',
      entityId: op.taskId!,
      localPendingFields: pendingFields,
      lastServerJson: normalizedBaseline,
      currentServerJson: normalizedCurrent,
      baselineUpdatedUtc: baselineUpdatedUtc,
      currentUpdatedUtc: current.updated,
      compareWithoutRevision: baselineUpdatedUtc == null,
    );
    if (conflict.hasConflict) {
      await _blockConflict(
        op,
        'Remote task changed fields: ${conflict.changedFields.toList()..sort()}',
      );
    }
    return current;
  }

  Future<Never> _blockUnknownRecurringCompletion(PendingOp op) async {
    await _database.pendingOpsDao.updateAttempt(
      id: op.id,
      attemptCount: op.attemptCount,
      nextAttemptAtUtc: DateTime.utc(9999, 12, 31),
      lastErrorCode: 'completion_outcome_unknown',
      lastErrorMessage: 'The recurring completion may already have advanced its occurrence. Check the provider before resolving the specific occurrence.',
      state: 'recovery_required',
    );
    throw const _PendingOpBlocked();
  }

  bool _taskPostconditionEstablished(
    PendingOp op,
    TaskDto current,
    Map<String, Object?> pendingFields,
  ) {
    if (op.state != 'in_progress') return false;
    // A recurring completion can advance to another occurrence. Matching a
    // generic completion field cannot identify the occurrence that was sent.
    if (pendingFields.containsKey('status') &&
        (current.rawJson['recurrence'] != null ||
            _jsonObject(op.baselineRawJson ?? '{}')['recurrence'] != null)) {
      return false;
    }
    if (pendingFields.isEmpty) return false;
    final desired = _normalizeTaskConflictSnapshot(pendingFields);
    final actual = _normalizeTaskConflictSnapshot(current.rawJson);
    for (final field in pendingFields.keys) {
      if (_taskOperationArgumentFields.contains(field) ||
          field.startsWith('_busymax')) {
        continue;
      }
      final intended = desired[field];
      final observed = actual[field];
      if (field == 'notes' &&
          (intended == null || intended == '') &&
          (observed == null || observed == '')) {
        continue;
      }
      if (!const ConflictDetector().fieldValuesEqual(
        field,
        intended,
        observed,
      )) {
        return false;
      }
    }
    return true;
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

  Future<TaskDto?> _ensureTaskUnchanged(PendingOp op, String action) async {
    final baselineUpdatedUtc = _parseUtc(op.baselineUpdatedUtc);
    if (baselineUpdatedUtc == null ||
        op.taskListId == null ||
        op.taskId == null) {
      return null;
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
    return current;
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
        if (entry.value is Map &&
            ((entry.value as Map)['rawJson'] is! Map ||
                ((entry.value as Map)['rawJson'] as Map)['deleted'] != true))
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
        // Google deliberately returns deletion tombstones with showDeleted.
        // They are not live members of the list being approved for removal.
        if (task.deleted != true) currentTasks[task.id] = task;
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
        final acknowledgedClearRevision =
            entry.value[acknowledgedTaskHiddenEffectKey] == true &&
            current.hidden == true &&
            !contentChanged;
        if ((revisionChanged && !acknowledgedClearRevision) || contentChanged) {
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
    semantic.removeWhere(
      (key, _) =>
          _taskRevisionFields.contains(key) ||
          _taskOperationArgumentFields.contains(key) ||
          key.startsWith('@odata.') ||
          key.startsWith('_busymax'),
    );
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
    return _canonicalConflictMap(semantic);
  }

  Map<String, Object?> _semanticTaskListConflictSnapshot(
    Map<String, Object?> snapshot,
  ) {
    final semantic = Map<String, Object?>.from(
      _normalizeTaskListConflictSnapshot(snapshot),
    );
    semantic.removeWhere(
      (key, _) =>
          _taskListRevisionFields.contains(key) ||
          key.startsWith('@odata.') ||
          key.startsWith('_busymax'),
    );
    if (semantic.containsKey('title')) semantic.remove('displayName');
    return _canonicalConflictMap(semantic);
  }

  Map<String, Object?> _canonicalConflictMap(Map<String, Object?> value) {
    final result = <String, Object?>{};
    for (final entry in value.entries) {
      final canonical = _canonicalConflictValue(entry.value);
      if (canonical != null) result[entry.key] = canonical;
    }
    return result;
  }

  Object? _canonicalConflictValue(Object? value) {
    if (value is Map) {
      final nested = _canonicalConflictMap(value.cast<String, Object?>());
      return nested.isEmpty ? null : nested;
    }
    if (value is List) {
      return [for (final item in value) _canonicalConflictValue(item)];
    }
    return value;
  }

  Future<void> _ensureNoCompletedTaskConflict(PendingOp op) async {
    final captured = _request(op)[_completedTaskBaselinesKey];
    if (captured is Map && op.taskListId != null) {
      final current = <String, TaskDto>{};
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
        );
        for (final task in page.items) {
          if (task.status == 'completed' &&
              task.hidden != true &&
              task.deleted != true) {
            current[task.id] = task;
          }
        }
        pageToken = page.nextPageToken;
      } while (pageToken != null && pageToken.isNotEmpty);
      var changed = !const SetEquality<String>().equals(
        captured.keys.map((id) => id.toString()).toSet(),
        current.keys.toSet(),
      );
      if (!changed) {
        for (final entry in captured.entries) {
          final value = entry.value;
          final task = current[entry.key];
          if (value is! Map ||
              value['rawJson'] is! Map ||
              task == null ||
              _remoteChangedAfterBaseline(
                task.updated,
                _parseUtc(value['updatedUtc']?.toString()) ??
                    DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
              ) ||
              !const DeepCollectionEquality().equals(
                _semanticTaskConflictSnapshot(
                  (value['rawJson'] as Map).cast<String, Object?>(),
                ),
                _semanticTaskConflictSnapshot(task.rawJson),
              )) {
            changed = true;
            break;
          }
        }
      }
      if (changed) {
        await _blockConflict(
          op,
          'Remote completed tasks changed since clear-completed was approved.',
        );
      }
      return;
    }
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

  Future<Never> _blockConflict(PendingOp op, String message) async {
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
const _completedTaskBaselinesKey = '_busymaxCompletedTaskBaselines';

const _taskRevisionFields = {
  'etag',
  '@odata.etag',
  'updated',
  'lastModifiedDateTime',
  'bodyLastModifiedDateTime',
};

const _taskOperationArgumentFields = {
  'previous',
  'destinationTasklist',
  'taskListId',
  'tasklist',
  'checklistItemId',
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

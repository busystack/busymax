import 'sync_auth_error.dart';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../db/app_database.dart';
import '../notifications/notification_schedule_service.dart';
import '../task_lists/data/task_lists_repository.dart';
import '../tasks/data/tasks_repository.dart';
import '../tasks/domain/task_checklist_item.dart';
import '../tasks/domain/task_remote_client.dart';
import '../tasks/domain/task_remote_models.dart';
import 'pending_ops_replayer.dart';
import 'collection_id_replacement.dart';
import 'scoped_pending_replay.dart';
import 'sync_request.dart';

class SyncEngine {
  SyncEngine({
    required AppDatabase database,
    required TaskRemoteClient apiClient,
    required String accountId,
    bool fullRefreshOnly = false,
    Future<void> Function(String summary)? onConflictBlocked,
    CollectionIdReplacement? onTaskListIdReplaced,
    Uuid uuid = const Uuid(),
    DateTime Function()? nowUtc,
    CollectionActivity? trackCollection,
  }) : _database = database,
       _apiClient = apiClient,
       _accountId = accountId,
       _fullRefreshOnly = fullRefreshOnly,
       _onConflictBlocked = onConflictBlocked,
       _onTaskListIdReplaced = onTaskListIdReplaced,
       _uuid = uuid,
       _trackCollection = trackCollection,
       _nowUtc = nowUtc ?? (() => DateTime.now().toUtc());

  final AppDatabase _database;
  final TaskRemoteClient _apiClient;
  final String _accountId;
  final bool _fullRefreshOnly;
  final Future<void> Function(String summary)? _onConflictBlocked;
  final CollectionIdReplacement? _onTaskListIdReplaced;
  final Uuid _uuid;
  final CollectionActivity? _trackCollection;
  final _affectedCollectionIds = <String>{};
  Set<String> get affectedCollectionIds =>
      Set.unmodifiable(_affectedCollectionIds);

  final DateTime Function() _nowUtc;
  bool _remoteImportWroteData = false;
  bool get remoteImportWroteData => _remoteImportWroteData;

  Future<void> dispatchPendingWrites() async {
    try {
      await PendingOpsReplayer(
        database: _database,
        apiClient: _apiClient,
        accountId: _accountId,
        nowUtc: _nowUtc,
        onConflictBlocked: _onConflictBlocked,
        onTaskListIdReplaced: _onTaskListIdReplaced,
      ).replayDueOps();
    } finally {
      await maintainCachedReminders();
    }
  }

  Future<void> maintainCachedReminders() => NotificationScheduleService(
    database: _database,
    nowUtc: _nowUtc,
  ).rebuildUpcomingTaskNotifications(_accountId);

  Future<SyncDisposition> refreshList(
    String taskListId, {
    void Function(String)? onAffected,
    CollectionWriteActivity? trackWrite,
  }) async {
    _remoteImportWroteData = false;
    var id = taskListId;
    final initial = await _taskList(id);
    if (initial == null || initial.serverMissing) {
      return SyncDisposition.missing;
    }
    if (initial.pendingDelete) return SyncDisposition.disabled;
    var deferred = false;
    try {
      try {
        await PendingOpsReplayer(
          database: _database,
          apiClient: _apiClient,
          accountId: _accountId,
          nowUtc: _nowUtc,
          onConflictBlocked: _onConflictBlocked,
          onTaskListIdReplaced: (oldId, newId) async {
            if (id == oldId) id = newId;
            onAffected?.call(newId);
            await _onTaskListIdReplaced?.call(oldId, newId);
          },
        ).replayDueOps(
          taskListId: id,
          trackOperation: (op, work) {
            final ids = {
              ?op.taskListId,
              if (pendingReplayPayload(op)['destinationTasklist']
                  case final String destination)
                destination,
            };
            for (final id in ids) {
              onAffected?.call(id);
            }
            return trackWrite?.call(ids, work) ?? work();
          },
        );
      } on ScopedSyncDeferred {
        deferred = true;
      }
      final list = await _taskList(id);
      if (list == null || list.serverMissing) return SyncDisposition.missing;
      if (id.startsWith('local-tasklist-') ||
          (deferred && list.localDirty && list.lastSyncedAtUtc == null)) {
        return SyncDisposition.deferred;
      }
      // A metadata row does not prove that this list has a task baseline.
      // A complete snapshot also leaves the account-wide updatedMin untouched.
      onAffected?.call(id);
      final tasks = await _pullTasks(id, updatedMin: null);
      await _markMissingTasks({id: tasks});
      return deferred ? SyncDisposition.deferred : SyncDisposition.completed;
    } finally {
      await maintainCachedReminders();
    }
  }

  Future<TaskList?> _taskList(String id) =>
      (_database.select(_database.taskLists)..where(
            (row) => row.accountId.equals(_accountId) & row.id.equals(id),
          ))
          .getSingleOrNull();

  Future<void> fullSync() {
    return _runSync(mode: 'full', updatedMin: null, markMissingTasks: true);
  }

  Future<void> incrementalSync() async {
    if (_fullRefreshOnly) {
      // Microsoft To Do sync uses full refresh in this version. Graph delta
      // endpoints exist in the low-level client but are not used by app sync.
      await _runSync(
        mode: 'incremental',
        updatedMin: null,
        markMissingTasks: true,
      );
      return;
    }

    final lastSuccessfulRun = await _database.syncRunsDao.latestSuccessfulRun(
      _accountId,
    );
    // A completion-time checkpoint can skip changes made to an early list
    // while later lists are still being synchronized.
    final checkpoint = lastSuccessfulRun == null
        ? null
        : DateTime.parse(lastSuccessfulRun.startedAtUtc).toUtc();
    final updatedMin = checkpoint?.subtract(const Duration(minutes: 2));

    await _runSync(
      mode: 'incremental',
      updatedMin: updatedMin,
      markMissingTasks: false,
    );
  }

  Future<void> _runSync({
    required String mode,
    required DateTime? updatedMin,
    required bool markMissingTasks,
  }) async {
    _remoteImportWroteData = false;
    final runId = _uuid.v4();
    final startedAt = _now();
    await _database.syncRunsDao.insertRun(
      SyncRunsCompanion.insert(
        id: runId,
        accountId: _accountId,
        mode: mode,
        startedAtUtc: startedAt,
        status: 'running',
      ),
    );

    var taskListsSeen = 0;
    var tasksSeen = 0;
    var pendingOpsApplied = 0;
    try {
      try {
        pendingOpsApplied = await PendingOpsReplayer(
          database: _database,
          apiClient: _apiClient,
          accountId: _accountId,
          nowUtc: _nowUtc,
          onConflictBlocked: _onConflictBlocked,
          onTaskListIdReplaced: _onTaskListIdReplaced,
        ).replayDueOps();
        final listIds = await _pullTaskLists();
        await _reconcileTaskListMembership(listIds);
        taskListsSeen = listIds.length;
        for (final taskListId in listIds) {
          _affectedCollectionIds.add(taskListId);
          Future<void> pull() async {
            final taskIds = await _pullTasks(
              taskListId,
              updatedMin: updatedMin,
            );
            tasksSeen += taskIds.length;
            if (markMissingTasks) {
              await _markMissingTasks({taskListId: taskIds});
            }
          }

          final track = _trackCollection;
          if (track == null) {
            await pull();
          } else {
            await track(taskListId, pull);
          }
        }
      } finally {
        // Keep reminders consistent even when a later page or list fails.
        await NotificationScheduleService(
          database: _database,
          nowUtc: _nowUtc,
        ).rebuildUpcomingTaskNotifications(_accountId);
      }

      final finishedAt = _now();
      await _database.syncRunsDao.finishRun(
        id: runId,
        finishedAtUtc: DateTime.parse(finishedAt),
        status: 'success',
        taskListsSeen: taskListsSeen,
        tasksSeen: tasksSeen,
        pendingOpsApplied: pendingOpsApplied,
      );
    } on Object catch (error) {
      await _database.syncRunsDao.finishRun(
        id: runId,
        finishedAtUtc: _nowUtc(),
        status: 'failed',
        taskListsSeen: taskListsSeen,
        tasksSeen: tasksSeen,
        errorCode: syncFailureDiagnostic(error),
        errorMessage: syncFailureDiagnostic(error),
      );
      rethrow;
    }
  }

  Future<Set<String>> _pullTaskLists() async {
    final seen = <String>{};
    String? pageToken;
    do {
      final page = await _apiClient.listTaskListsPage(
        maxResults: 1000,
        pageToken: pageToken,
      );
      final now = _now();
      for (final item in page.items) {
        seen.add(item.id);
        await _database.transaction(() async {
          if (await _hasLocalPendingTaskListMutation(item.id)) return;
          await _database.taskListsDao.upsertTaskList(
            taskListFromDto(_accountId, item, now),
          );
          _remoteImportWroteData = true;
        });
      }
      pageToken = page.nextPageToken;
    } while (pageToken != null && pageToken.isNotEmpty);

    return seen;
  }

  Future<void> _pullChecklistItems(String taskListId, String taskId) async {
    final client = _apiClient as TaskChecklistRemoteClient;
    final serverItems = <TaskChecklistItemDto>[];
    String? pageToken;
    do {
      final page = await client.listChecklistItemsPage(
        taskListId: taskListId,
        taskId: taskId,
        pageToken: pageToken,
      );
      serverItems.addAll(page.items);
      pageToken = page.nextPageToken;
    } while (pageToken != null && pageToken.isNotEmpty);

    final task =
        await (_database.select(_database.tasks)..where(
              (row) =>
                  row.accountId.equals(_accountId) &
                  row.taskListId.equals(taskListId) &
                  row.id.equals(taskId),
            ))
            .getSingleOrNull();
    if (task == null) return;
    final pending =
        await (_database.select(_database.pendingOps)
              ..where(
                (row) =>
                    row.accountId.equals(_accountId) &
                    row.entityType.equals('task_checklist_item') &
                    row.taskListId.equals(taskListId) &
                    row.taskId.equals(taskId),
              )
              ..orderBy([
                (row) => OrderingTerm.asc(row.createdAtUtc),
                (row) => OrderingTerm.asc(row.updatedAtUtc),
              ]))
            .get();
    final merged = mergeTaskChecklistProjection(
      serverItems: serverItems,
      localItems: decodeTaskChecklistItems(task.microsoftChecklistItemsJson),
      pendingOperations: pending,
    );
    await (_database.update(_database.tasks)..where(
          (row) =>
              row.accountId.equals(_accountId) &
              row.taskListId.equals(taskListId) &
              row.id.equals(taskId),
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

  Future<Set<String>> _pullTasks(
    String taskListId, {
    required DateTime? updatedMin,
  }) async {
    final seen = <String>{};
    String? pageToken;
    do {
      final page = await _apiClient.listTasksPage(
        taskListId: taskListId,
        maxResults: 100,
        pageToken: pageToken,
        showCompleted: true,
        showDeleted: true,
        showHidden: true,
        showAssigned: true,
        updatedMin: updatedMin,
      );
      final now = _now();
      for (final item in page.items) {
        seen.add(item.id);
        await _database.transaction(() async {
          if (await _hasLocalPendingTaskMutation(taskListId, item.id)) return;
          await _database.tasksDao.upsertTask(
            taskFromDto(_accountId, taskListId, item, now),
          );
          _remoteImportWroteData = true;
        });
      }
      if (page.items.isNotEmpty) {
        // This page is already committed. Reconcile before any later task,
        // checklist, or list request so earlier alarms become due immediately.
        await NotificationScheduleService(
          database: _database,
          nowUtc: _nowUtc,
        ).rebuildUpcomingTaskNotifications(_accountId);
      }
      pageToken = page.nextPageToken;
    } while (pageToken != null && pageToken.isNotEmpty);

    if (_apiClient is TaskChecklistRemoteClient) {
      for (final taskId in seen) {
        await _pullChecklistItems(taskListId, taskId);
      }
    }

    return seen;
  }

  Future<bool> _hasLocalPendingTaskListMutation(String taskListId) async {
    final row =
        await (_database.select(_database.taskLists)..where(
              (row) =>
                  row.accountId.equals(_accountId) & row.id.equals(taskListId),
            ))
            .getSingleOrNull();
    return row != null && (row.localDirty || row.pendingDelete);
  }

  Future<bool> _hasLocalPendingTaskMutation(
    String taskListId,
    String taskId,
  ) async {
    final row =
        await (_database.select(_database.tasks)..where(
              (row) =>
                  row.accountId.equals(_accountId) &
                  row.taskListId.equals(taskListId) &
                  row.id.equals(taskId),
            ))
            .getSingleOrNull();
    if (row != null &&
        (row.localDirty ||
            row.pendingDelete ||
            row.pendingMove ||
            row.localCreated)) {
      return true;
    }
    // A cross-list move relocates the projection immediately. Its queued
    // source identity must remain protected while replay is blocked, including
    // each source in a dependent move chain. Never infer identity from a task
    // ID shared by otherwise unrelated lists or accounts.
    final move =
        await (_database.select(_database.pendingOps)
              ..where(
                (op) =>
                    op.accountId.equals(_accountId) &
                    op.operation.equals('move_task') &
                    op.taskListId.equals(taskListId) &
                    op.taskId.equals(taskId),
              )
              ..limit(1))
            .getSingleOrNull();
    return move != null;
  }

  Future<void> _reconcileTaskListMembership(Set<String> seenTaskListIds) async {
    await _database.transaction(() async {
      final lists = await _database.taskListsDao.listTaskLists(_accountId);
      for (final list in lists) {
        if (seenTaskListIds.contains(list.id)) {
          if (list.serverMissing) {
            _remoteImportWroteData = true;
            await (_database.update(_database.taskLists)..where(
                  (row) =>
                      row.accountId.equals(_accountId) & row.id.equals(list.id),
                ))
                .write(const TaskListsCompanion(serverMissing: Value(false)));
          }
          continue;
        }
        if (list.localDirty) continue;
        _remoteImportWroteData = true;
        await (_database.update(_database.taskLists)..where(
              (row) =>
                  row.accountId.equals(_accountId) & row.id.equals(list.id),
            ))
            .write(const TaskListsCompanion(serverMissing: Value(true)));
        await (_database.update(_database.tasks)..where(
              (row) =>
                  row.accountId.equals(_accountId) &
                  row.taskListId.equals(list.id) &
                  row.localDirty.equals(false),
            ))
            .write(const TasksCompanion(serverMissing: Value(true)));
      }
    });
  }

  Future<void> _markMissingTasks(
    Map<String, Set<String>> seenTaskIdsByList,
  ) async {
    await _database.transaction(() async {
      for (final entry in seenTaskIdsByList.entries) {
        final tasks = await _database.tasksDao.listTasks(_accountId, entry.key);
        for (final task in tasks) {
          if (entry.value.contains(task.id) ||
              task.localDirty ||
              await _hasLocalPendingTaskMutation(entry.key, task.id)) {
            continue;
          }
          await (_database.update(_database.tasks)..where(
                (row) =>
                    row.accountId.equals(_accountId) &
                    row.taskListId.equals(entry.key) &
                    row.id.equals(task.id) &
                    row.localDirty.equals(false),
              ))
              .write(const TasksCompanion(serverMissing: Value(true)));
        }
      }
    });
  }

  String _now() => _nowUtc().toIso8601String();
}

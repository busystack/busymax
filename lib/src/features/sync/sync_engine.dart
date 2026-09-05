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

class SyncEngine {
  SyncEngine({
    required AppDatabase database,
    required TaskRemoteClient apiClient,
    required String accountId,
    bool fullRefreshOnly = false,
    Future<void> Function(String summary)? onConflictBlocked,
    Uuid uuid = const Uuid(),
    DateTime Function()? nowUtc,
  }) : _database = database,
       _apiClient = apiClient,
       _accountId = accountId,
       _fullRefreshOnly = fullRefreshOnly,
       _onConflictBlocked = onConflictBlocked,
       _uuid = uuid,
       _nowUtc = nowUtc ?? (() => DateTime.now().toUtc());

  final AppDatabase _database;
  final TaskRemoteClient _apiClient;
  final String _accountId;
  final bool _fullRefreshOnly;
  final Future<void> Function(String summary)? _onConflictBlocked;
  final Uuid _uuid;
  final DateTime Function() _nowUtc;

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

    final account = await (_database.select(
      _database.accounts,
    )..where((row) => row.id.equals(_accountId))).getSingleOrNull();
    final lastSync = account?.lastSuccessfulSyncAtUtc == null
        ? null
        : DateTime.parse(account!.lastSuccessfulSyncAtUtc!).toUtc();
    final updatedMin = lastSync?.subtract(const Duration(minutes: 2));

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
      pendingOpsApplied = await PendingOpsReplayer(
        database: _database,
        apiClient: _apiClient,
        accountId: _accountId,
        nowUtc: _nowUtc,
        onConflictBlocked: _onConflictBlocked,
      ).replayDueOps();
      final listIds = await _pullTaskLists();
      await _reconcileTaskListMembership(listIds);
      taskListsSeen = listIds.length;
      final tasksByList = <String, Set<String>>{};
      for (final taskListId in listIds) {
        final taskIds = await _pullTasks(taskListId, updatedMin: updatedMin);
        tasksByList[taskListId] = taskIds;
        tasksSeen += taskIds.length;
      }

      if (markMissingTasks) {
        await _markMissingTasks(tasksByList);
      }
      await NotificationScheduleService(
        database: _database,
        nowUtc: _nowUtc,
      ).rebuildUpcomingTaskNotifications(_accountId);

      final finishedAt = _now();
      await _updateAccountSyncTimestamps(mode, finishedAt);
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
        errorCode: error.runtimeType.toString(),
        errorMessage: error.toString(),
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
        if (await _hasLocalPendingTaskListMutation(item.id)) {
          continue;
        }
        await _database.taskListsDao.upsertTaskList(
          taskListFromDto(_accountId, item, now),
        );
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
        if (await _hasLocalPendingTaskMutation(taskListId, item.id)) {
          continue;
        }
        await _database.tasksDao.upsertTask(
          taskFromDto(_accountId, taskListId, item, now),
        );
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
    return row != null &&
        (row.localDirty ||
            row.pendingDelete ||
            row.pendingMove ||
            row.localCreated);
  }

  Future<void> _reconcileTaskListMembership(Set<String> seenTaskListIds) async {
    final lists = await _database.taskListsDao.listTaskLists(_accountId);
    await _database.transaction(() async {
      for (final list in lists) {
        if (seenTaskListIds.contains(list.id)) {
          if (list.serverMissing) {
            await (_database.update(_database.taskLists)..where(
                  (row) =>
                      row.accountId.equals(_accountId) & row.id.equals(list.id),
                ))
                .write(const TaskListsCompanion(serverMissing: Value(false)));
          }
          continue;
        }
        if (list.localDirty) continue;
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
    for (final entry in seenTaskIdsByList.entries) {
      final seenTaskIds = entry.value;
      final tasks = await _database.tasksDao.listTasks(_accountId, entry.key);
      for (final task in tasks) {
        if (!seenTaskIds.contains(task.id) && !task.localDirty) {
          await (_database.update(_database.tasks)..where(
                (row) =>
                    row.accountId.equals(_accountId) &
                    row.taskListId.equals(entry.key) &
                    row.id.equals(task.id),
              ))
              .write(const TasksCompanion(serverMissing: Value(true)));
        }
      }
    }
  }

  Future<void> _updateAccountSyncTimestamps(String mode, String timestamp) {
    final update = _database.update(_database.accounts)
      ..where((row) => row.id.equals(_accountId));
    return update.write(
      AccountsCompanion(
        lastSuccessfulSyncAtUtc: Value(timestamp),
        lastFullSyncAtUtc: mode == 'full'
            ? Value(timestamp)
            : const Value.absent(),
        updatedAtUtc: Value(timestamp),
      ),
    );
  }

  String _now() => _nowUtc().toIso8601String();
}

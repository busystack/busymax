import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../db/app_database.dart';
import '../../google_tasks/api/google_tasks_api_client.dart';
import '../notifications/notification_schedule_service.dart';
import '../task_lists/data/task_lists_repository.dart';
import '../tasks/data/tasks_repository.dart';
import 'pending_ops_replayer.dart';

class SyncEngine {
  SyncEngine({
    required AppDatabase database,
    required GoogleTasksApiClient apiClient,
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
  final GoogleTasksApiClient _apiClient;
  final String _accountId;
  final bool _fullRefreshOnly;
  final Future<void> Function(String summary)? _onConflictBlocked;
  final Uuid _uuid;
  final DateTime Function() _nowUtc;

  Future<void> fullSync() {
    return _runSync(mode: 'full', updatedMin: null, markMissing: true);
  }

  Future<void> incrementalSync() async {
    if (_fullRefreshOnly) {
      // Microsoft To Do sync uses full refresh in this version. Graph delta
      // endpoints exist in the low-level client but are not used by app sync.
      await _runSync(mode: 'incremental', updatedMin: null, markMissing: true);
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
      markMissing: false,
    );
  }

  Future<void> _runSync({
    required String mode,
    required DateTime? updatedMin,
    required bool markMissing,
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
      taskListsSeen = listIds.length;
      final tasksByList = <String, Set<String>>{};
      for (final taskListId in listIds) {
        final taskIds = await _pullTasks(taskListId, updatedMin: updatedMin);
        tasksByList[taskListId] = taskIds;
        tasksSeen += taskIds.length;
      }

      if (markMissing) {
        await _markMissingRows(listIds, tasksByList);
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

  Future<void> _markMissingRows(
    Set<String> seenTaskListIds,
    Map<String, Set<String>> seenTaskIdsByList,
  ) async {
    final lists = await _database.taskListsDao.listTaskLists(_accountId);
    for (final list in lists) {
      if (!seenTaskListIds.contains(list.id) && !list.localDirty) {
        await (_database.update(_database.taskLists)..where(
              (row) =>
                  row.accountId.equals(_accountId) & row.id.equals(list.id),
            ))
            .write(const TaskListsCompanion(serverMissing: Value(true)));
      }
    }

    for (final list in lists) {
      final seenTaskIds = seenTaskIdsByList[list.id] ?? const <String>{};
      final tasks = await _database.tasksDao.listTasks(_accountId, list.id);
      for (final task in tasks) {
        if (!seenTaskIds.contains(task.id) && !task.localDirty) {
          await (_database.update(_database.tasks)..where(
                (row) =>
                    row.accountId.equals(_accountId) &
                    row.taskListId.equals(list.id) &
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

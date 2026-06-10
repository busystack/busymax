part of '../app_database.dart';

@DriftAccessor(tables: [SyncRuns])
class SyncRunsDao extends DatabaseAccessor<AppDatabase>
    with _$SyncRunsDaoMixin {
  SyncRunsDao(super.db);

  Future<void> insertRun(SyncRunsCompanion row) {
    return into(syncRuns).insert(row);
  }

  Future<void> finishRun({
    required String id,
    required DateTime finishedAtUtc,
    required String status,
    int? taskListsSeen,
    int? tasksSeen,
    int? pendingOpsApplied,
    String? errorCode,
    String? errorMessage,
  }) {
    final query = update(syncRuns)..where((row) => row.id.equals(id));
    return query.write(
      SyncRunsCompanion(
        finishedAtUtc: Value(finishedAtUtc.toIso8601String()),
        status: Value(status),
        taskListsSeen: taskListsSeen == null
            ? const Value.absent()
            : Value(taskListsSeen),
        tasksSeen: tasksSeen == null ? const Value.absent() : Value(tasksSeen),
        pendingOpsApplied: pendingOpsApplied == null
            ? const Value.absent()
            : Value(pendingOpsApplied),
        errorCode: Value(errorCode),
        errorMessage: Value(errorMessage),
      ),
    );
  }

  Future<List<SyncRun>> recentRuns(String accountId, {int limit = 50}) {
    final query = select(syncRuns)
      ..where((row) => row.accountId.equals(accountId))
      ..orderBy([(row) => OrderingTerm.desc(row.startedAtUtc)])
      ..limit(limit);
    return query.get();
  }
}

part of '../app_database.dart';

@DriftAccessor(tables: [PendingOps])
class PendingOpsDao extends DatabaseAccessor<AppDatabase>
    with _$PendingOpsDaoMixin {
  PendingOpsDao(super.db);

  Future<void> enqueue(PendingOpsCompanion row) {
    return into(pendingOps).insertOnConflictUpdate(row);
  }

  Future<List<PendingOp>> pendingOpsForReplay(
    String accountId,
    DateTime nowUtc,
  ) {
    final query = select(pendingOps)
      ..where(
        (row) =>
            row.accountId.equals(accountId) &
            (row.nextAttemptAtUtc.isNull() |
                row.nextAttemptAtUtc.isSmallerOrEqualValue(
                  nowUtc.toIso8601String(),
                )),
      )
      ..orderBy([(row) => OrderingTerm.asc(row.createdAtUtc)]);
    return query.get();
  }

  Future<void> deleteOp(String id) {
    final query = delete(pendingOps)..where((row) => row.id.equals(id));
    return query.go();
  }

  Future<PendingOp?> getOp(String id) {
    final query = select(pendingOps)..where((row) => row.id.equals(id));
    return query.getSingleOrNull();
  }

  Stream<List<PendingOp>> watchBlockedOps(String accountId) {
    final query = select(pendingOps)
      ..where(
        (row) =>
            row.accountId.equals(accountId) &
            row.nextAttemptAtUtc.isBiggerOrEqualValue('9999-12-31'),
      )
      ..orderBy([(row) => OrderingTerm.asc(row.createdAtUtc)]);
    return query.watch();
  }

  Future<void> retryNow(String id, DateTime nowUtc) {
    final query = update(pendingOps)..where((row) => row.id.equals(id));
    return query.write(
      PendingOpsCompanion(
        nextAttemptAtUtc: Value(nowUtc.toIso8601String()),
        lastErrorCode: const Value(null),
        lastErrorMessage: const Value(null),
        updatedAtUtc: Value(nowUtc.toIso8601String()),
      ),
    );
  }

  Future<void> updateAttempt({
    required String id,
    required int attemptCount,
    required DateTime nextAttemptAtUtc,
    String? lastErrorCode,
    String? lastErrorMessage,
  }) {
    final query = update(pendingOps)..where((row) => row.id.equals(id));
    return query.write(
      PendingOpsCompanion(
        attemptCount: Value(attemptCount),
        nextAttemptAtUtc: Value(nextAttemptAtUtc.toIso8601String()),
        lastErrorCode: Value(lastErrorCode),
        lastErrorMessage: Value(lastErrorMessage),
        updatedAtUtc: Value(DateTime.now().toUtc().toIso8601String()),
      ),
    );
  }
}

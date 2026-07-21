part of '../app_database.dart';

@DriftAccessor(tables: [TaskLists])
class TaskListsDao extends DatabaseAccessor<AppDatabase>
    with _$TaskListsDaoMixin {
  TaskListsDao(super.db);

  Stream<List<TaskList>> watchTaskLists(String accountId) {
    final query = select(taskLists)
      ..where(
        (row) =>
            row.accountId.equals(accountId) &
            row.pendingDelete.equals(false) &
            row.serverMissing.equals(false),
      )
      ..orderBy([(row) => OrderingTerm.asc(row.title)]);
    return query.watch();
  }

  Future<List<TaskList>> listTaskLists(String accountId) {
    final query = select(taskLists)
      ..where((row) => row.accountId.equals(accountId))
      ..orderBy([(row) => OrderingTerm.asc(row.title)]);
    return query.get();
  }

  Future<void> upsertTaskList(TaskListsCompanion row) {
    return into(taskLists).insertOnConflictUpdate(row);
  }

  Future<List<TaskList>> dirtyTaskLists(String accountId) {
    final query = select(taskLists)
      ..where(
        (row) =>
            row.accountId.equals(accountId) &
            (row.localDirty.equals(true) | row.pendingDelete.equals(true)),
      );
    return query.get();
  }

  Future<void> deleteTaskList(String accountId, String id) {
    final query = delete(taskLists)
      ..where((row) => row.accountId.equals(accountId) & row.id.equals(id));
    return query.go();
  }
}

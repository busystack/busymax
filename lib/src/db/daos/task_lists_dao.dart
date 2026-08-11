part of '../app_database.dart';

@DriftAccessor(tables: [TaskLists, DavCollections])
class TaskListsDao extends DatabaseAccessor<AppDatabase>
    with _$TaskListsDaoMixin {
  TaskListsDao(super.db);

  Stream<List<TaskList>> watchTaskLists(String accountId) {
    final query =
        select(taskLists).join([
            leftOuterJoin(
              davCollections,
              davCollections.id.equalsExp(taskLists.davCollectionId),
            ),
          ])
          ..where(
            taskLists.accountId.equals(accountId) &
                taskLists.pendingDelete.equals(false) &
                taskLists.serverMissing.equals(false) &
                (taskLists.davCollectionId.isNull() |
                    davCollections.tasksSelected.equals(true)),
          )
          ..orderBy([OrderingTerm.asc(taskLists.title)]);
    return query.watch().map(
      (rows) => [for (final row in rows) row.readTable(taskLists)],
    );
  }

  Future<List<TaskList>> listTaskLists(String accountId) {
    final query =
        select(taskLists).join([
            leftOuterJoin(
              davCollections,
              davCollections.id.equalsExp(taskLists.davCollectionId),
            ),
          ])
          ..where(
            taskLists.accountId.equals(accountId) &
                (taskLists.davCollectionId.isNull() |
                    davCollections.tasksSelected.equals(true)),
          )
          ..orderBy([OrderingTerm.asc(taskLists.title)]);
    return query.get().then(
      (rows) => [for (final row in rows) row.readTable(taskLists)],
    );
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

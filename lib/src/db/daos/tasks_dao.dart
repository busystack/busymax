part of '../app_database.dart';

@DriftAccessor(tables: [Accounts, TaskLists, Tasks])
class TasksDao extends DatabaseAccessor<AppDatabase> with _$TasksDaoMixin {
  TasksDao(super.db);

  Stream<List<Task>> watchTaskTree(String accountId, String taskListId) {
    final query = select(tasks)
      ..where(
        (row) =>
            row.accountId.equals(accountId) &
            row.taskListId.equals(taskListId) &
            row.pendingDelete.equals(false),
      )
      ..orderBy([
        (row) => OrderingTerm.asc(row.parent),
        (row) => OrderingTerm.asc(row.position),
        (row) => OrderingTerm.asc(row.title),
      ]);
    return query.watch();
  }

  Stream<List<TaskWithContextRow>> watchAllTaskTrees(List<String> accountIds) {
    if (accountIds.isEmpty) {
      return Stream.value(const []);
    }

    final query =
        select(tasks).join([
            innerJoin(
              taskLists,
              taskLists.accountId.equalsExp(tasks.accountId) &
                  taskLists.id.equalsExp(tasks.taskListId),
            ),
            innerJoin(accounts, accounts.id.equalsExp(tasks.accountId)),
          ])
          ..where(
            tasks.accountId.isIn(accountIds) &
                tasks.pendingDelete.equals(false) &
                taskLists.pendingDelete.equals(false) &
                accounts.authState.equals('signed_in'),
          )
          ..orderBy([
            OrderingTerm.asc(accounts.provider),
            OrderingTerm.asc(accounts.displayName),
            OrderingTerm.asc(accounts.email),
            OrderingTerm.asc(taskLists.title),
            OrderingTerm.asc(tasks.parent),
            OrderingTerm.asc(tasks.position),
            OrderingTerm.asc(tasks.title),
          ]);

    return query.watch().map((rows) {
      return [
        for (final row in rows)
          TaskWithContextRow(
            task: row.readTable(tasks),
            taskList: row.readTable(taskLists),
            account: row.readTable(accounts),
          ),
      ];
    });
  }

  Future<List<Task>> listTasks(String accountId, String taskListId) {
    final query = select(tasks)
      ..where(
        (row) =>
            row.accountId.equals(accountId) & row.taskListId.equals(taskListId),
      )
      ..orderBy([
        (row) => OrderingTerm.asc(row.parent),
        (row) => OrderingTerm.asc(row.position),
        (row) => OrderingTerm.asc(row.title),
      ]);
    return query.get();
  }

  Future<void> upsertTask(TasksCompanion row) {
    return into(tasks).insertOnConflictUpdate(row);
  }

  Future<List<Task>> dirtyTasks(String accountId) {
    final query = select(tasks)
      ..where(
        (row) =>
            row.accountId.equals(accountId) &
            (row.localDirty.equals(true) |
                row.pendingDelete.equals(true) |
                row.pendingMove.equals(true)),
      );
    return query.get();
  }

  Future<void> deleteTask(String accountId, String taskListId, String taskId) {
    final query = delete(tasks)
      ..where(
        (row) =>
            row.accountId.equals(accountId) &
            row.taskListId.equals(taskListId) &
            row.id.equals(taskId),
      );
    return query.go();
  }
}

class TaskWithContextRow {
  const TaskWithContextRow({
    required this.task,
    required this.taskList,
    required this.account,
  });

  final Task task;
  final TaskList taskList;
  final Account account;
}

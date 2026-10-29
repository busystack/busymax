import 'package:drift/drift.dart';

import '../../core/time/stored_temporal_projection.dart';
import '../../db/app_database.dart';
import '../accounts/data/accounts_repository.dart';

String notificationLocalDate(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

DateTime? parseNotificationDate(String? value) {
  if (value == null || !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) {
    return null;
  }
  final date = DateTime.tryParse(value);
  return date != null && notificationLocalDate(date) == value ? date : null;
}

DateTime dailySummaryTime(DateTime day, String time) {
  final parts = time.split(':');
  return DateTime(
    day.year,
    day.month,
    day.day,
    int.parse(parts[0]),
    int.parse(parts[1]),
  );
}

/// One application-wide summary: every eligible account, regardless of current
/// browsing selections. DUE is required for DAV; DTSTART is not a deadline.
Future<List<Task>> notificationTasksDueOn(
  AppDatabase database,
  DateTime date,
) async {
  final accounts =
      await (database.select(database.accounts)..where(
            (row) => row.authState.isIn(accountLocalReminderEligibleStates),
          ))
          .get();
  final ids = accounts.map((row) => row.id).toSet();
  final lists =
      await (database.select(database.taskLists)..where(
            (row) =>
                row.accountId.isIn(ids) &
                row.pendingDelete.equals(false) &
                row.serverMissing.equals(false),
          ))
          .get();
  final keys = {for (final list in lists) '${list.accountId}\u0000${list.id}'};
  final tasks =
      await (database.select(database.tasks)..where(
            (row) =>
                row.accountId.isIn(ids) &
                row.pendingDelete.equals(false) &
                row.serverMissing.equals(false) &
                (row.deleted.isNull() | row.deleted.equals(false)) &
                (row.hidden.isNull() | row.hidden.equals(false)),
          ))
          .get();
  final day = notificationLocalDate(date);
  return tasks.where((task) {
    if (!keys.contains('${task.accountId}\u0000${task.taskListId}') ||
        task.status == 'completed' ||
        task.status == 'cancelled') {
      return false;
    }
    final deadline = taskDeadlineAsLocal(task);
    return deadline != null && notificationLocalDate(deadline) == day;
  }).toList();
}

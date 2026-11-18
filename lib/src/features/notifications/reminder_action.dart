import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../db/app_database.dart';
import 'notification_schedule_service.dart';
import 'reminder_delivery_policy.dart';

enum ReminderNotificationAction { open, snooze, dismiss }

/// Applies an action to the current delivery, identified by its persisted
/// generation. The current source is resolved from storage, so a projection
/// ID change does not cause an action to affect an unrelated reminder.
Future<bool> applyReminderAction({
  required AppDatabase database,
  required String scheduleId,
  required String generation,
  required String accountId,
  required String sourceType,
  required ReminderNotificationAction action,
  required DateTime nowUtc,
  int? scheduledAtUtc,
  Duration snoozeDuration = defaultReminderSnoozeDuration,
}) {
  if (action == ReminderNotificationAction.open) return Future.value(false);
  return database.synchronizeNotifications(
    () => database.transaction(() async {
      final schedule = database.notificationSchedule;
      Expression<bool> matches($NotificationScheduleTable table) =>
          table.id.equals(scheduleId) &
          table.generation.equals(generation) &
          table.accountId.equals(accountId) &
          table.sourceType.equals(sourceType) &
          table.dismissedAtUtc.isNull() &
          table.expiredAtUtc.isNull() &
          (scheduledAtUtc == null
              ? const Constant(true)
              : table.scheduledAtUtc.equals(scheduledAtUtc));

      final row = await (database.select(
        schedule,
      )..where(matches)).getSingleOrNull();
      if (row == null ||
          !await NotificationScheduleService(
            database: database,
            nowUtc: () => nowUtc,
          ).validateAndReconcileReminder(row)) {
        return false;
      }
      final now = nowUtc.millisecondsSinceEpoch;
      final update = action == ReminderNotificationAction.snooze
          ? NotificationScheduleCompanion(
              generation: Value(const Uuid().v4()),
              sentAtUtc: const Value(null),
              deferredUntilUtc: const Value(null),
              snoozedUntilUtc: Value(now + snoozeDuration.inMilliseconds),
              updatedAtLocal: Value(now),
            )
          : NotificationScheduleCompanion(
              dismissedAtUtc: Value(now),
              deferredUntilUtc: const Value(null),
              snoozedUntilUtc: const Value(null),
              updatedAtLocal: Value(now),
            );
      return await (database.update(schedule)..where(matches)).write(update) !=
          0;
    }),
  );
}

import '../../db/app_database.dart';

/// Allows native registration and an ordinary scheduler tick to cross a trigger
/// instant. This is also the catch-up window for an alarm intentionally set at
/// or after its occurrence's end, and for an overdue explicit snooze.
const defaultReminderSnoozeDuration = Duration(minutes: 10);

const reminderRegistrationGrace = Duration(minutes: 10);

DateTime eventReminderExpiry(DateTime trigger, DateTime occurrenceEnd) {
  final registrationEnd = trigger.add(reminderRegistrationGrace);
  return occurrenceEnd.isAfter(registrationEnd)
      ? occurrenceEnd
      : registrationEnd;
}

/// An open task can still be acted on during the reminder's local calendar day.
/// Do not replay several days of historical task alarms on import or restart.
DateTime taskReminderExpiry(DateTime trigger) {
  final local = trigger.toLocal();
  final dayEnd = DateTime(local.year, local.month, local.day + 1).toUtc();
  final registrationEnd = trigger.add(reminderRegistrationGrace);
  return dayEnd.isAfter(registrationEnd) ? dayEnd : registrationEnd;
}

bool reminderHasExpired(NotificationScheduleData row, DateTime nowUtc) {
  if (row.dismissedAtUtc != null || row.expiredAtUtc != null) return true;
  final snooze = row.snoozedUntilUtc;
  if (snooze != null) {
    return nowUtc.millisecondsSinceEpoch >=
        snooze + reminderRegistrationGrace.inMilliseconds;
  }
  if (row.sentAtUtc != null) return false;
  return row.expiresAtUtc != null &&
      nowUtc.millisecondsSinceEpoch >= row.expiresAtUtc!;
}

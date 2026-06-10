import 'dart:async';

import 'package:drift/drift.dart';

import '../../db/app_database.dart';
import 'desktop_notification_service.dart';

class NotificationScheduler {
  NotificationScheduler({
    required AppDatabase database,
    required DesktopNotificationService notifications,
    Duration interval = const Duration(minutes: 1),
    DateTime Function()? nowUtc,
  }) : _database = database,
       _notifications = notifications,
       _interval = interval,
       _nowUtc = nowUtc ?? (() => DateTime.now().toUtc());

  final AppDatabase _database;
  final DesktopNotificationService _notifications;
  final Duration _interval;
  final DateTime Function() _nowUtc;
  Timer? _timer;

  void start() {
    _timer ??= Timer.periodic(_interval, (_) => unawaited(checkNow()));
    unawaited(checkNow());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> checkNow() async {
    final now = _nowUtc().millisecondsSinceEpoch;
    final rows =
        await (_database.select(_database.notificationSchedule)..where(
              (row) =>
                  row.scheduledAtUtc.isSmallerOrEqualValue(now) &
                  row.sentAtUtc.isNull() &
                  row.dismissedAtUtc.isNull(),
            ))
            .get();
    for (final row in rows) {
      if (row.sourceType == 'event') {
        await _notifications.notifyEventReminder(row.title, row.body);
      } else if (row.sourceType == 'task') {
        await _notifications.notifyTaskReminder(row.title, row.body);
      }
      await (_database.update(
        _database.notificationSchedule,
      )..where((table) => table.id.equals(row.id))).write(
        NotificationScheduleCompanion(
          sentAtUtc: Value(_nowUtc().millisecondsSinceEpoch),
          updatedAtLocal: Value(DateTime.now().millisecondsSinceEpoch),
        ),
      );
    }
  }
}

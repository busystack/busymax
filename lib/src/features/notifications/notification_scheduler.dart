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
  Timer? _dueTimer;
  StreamSubscription<List<NotificationScheduleData>>? _scheduleSubscription;
  var _checking = false;
  var _checkAgain = false;

  void start() {
    _timer ??= Timer.periodic(_interval, (_) => unawaited(checkNow()));
    _scheduleSubscription ??= _database
        .select(_database.notificationSchedule)
        .watch()
        .listen((_) => unawaited(_handleScheduleChanged()));
    unawaited(checkNow());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _dueTimer?.cancel();
    _dueTimer = null;
    unawaited(_scheduleSubscription?.cancel());
    _scheduleSubscription = null;
  }

  Future<void> _handleScheduleChanged() async {
    await checkNow();
  }

  Future<void> checkNow() async {
    if (_checking) {
      _checkAgain = true;
      return;
    }

    _checking = true;
    try {
      do {
        _checkAgain = false;
        await _checkDueNotifications();
      } while (_checkAgain);
      await _scheduleNextDueCheck();
    } finally {
      _checking = false;
    }
  }

  Future<void> _checkDueNotifications() async {
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

  Future<void> _scheduleNextDueCheck() async {
    _dueTimer?.cancel();
    _dueTimer = null;

    final next =
        await (_database.select(_database.notificationSchedule)
              ..where(
                (row) => row.sentAtUtc.isNull() & row.dismissedAtUtc.isNull(),
              )
              ..orderBy([(row) => OrderingTerm.asc(row.scheduledAtUtc)])
              ..limit(1))
            .getSingleOrNull();
    if (next == null) {
      return;
    }

    final now = _nowUtc().millisecondsSinceEpoch;
    final delay = Duration(
      milliseconds: (next.scheduledAtUtc - now).clamp(0, 2147483647),
    );
    _dueTimer = Timer(delay, () => unawaited(checkNow()));
  }
}

import 'dart:async';

import 'package:drift/drift.dart';

import '../../app/app_settings.dart';
import '../../db/app_database.dart';
import 'desktop_notification_service.dart';

/// Evaluates the active account's summary, preserving the app-wide once-per-day
/// preference. Task imports, local midnight, settings, and retries all enter the
/// same serialized path.
class DueTodayNotificationScheduler {
  DueTodayNotificationScheduler({
    required AppDatabase database,
    required AppSettings Function() settings,
    required String? Function() activeAccountId,
    required DesktopNotificationService Function() notifications,
    required Future<void> Function(String date) markNotified,
    bool Function(String accountId)? syncBlocksDelivery,
    Stream<String>? accountSyncChanges,
    DateTime Function()? now,
    Duration interval = const Duration(minutes: 1),
  }) : _database = database,
       _settings = settings,
       _activeAccountId = activeAccountId,
       _notifications = notifications,
       _markNotified = markNotified,
       _syncBlocksDelivery = syncBlocksDelivery ?? _neverBlocked,
       _accountSyncChanges = accountSyncChanges ?? const Stream<String>.empty(),
       _now = now ?? DateTime.now,
       _interval = interval;

  final AppDatabase _database;
  final AppSettings Function() _settings;
  final String? Function() _activeAccountId;
  final DesktopNotificationService Function() _notifications;
  final Future<void> Function(String date) _markNotified;
  final bool Function(String accountId) _syncBlocksDelivery;
  final Stream<String> _accountSyncChanges;
  final DateTime Function() _now;
  final Duration _interval;
  StreamSubscription<Set<TableUpdate>>? _taskSubscription;
  StreamSubscription<String>? _accountSyncSubscription;
  Timer? _clockTimer;
  Timer? _nextCheckTimer;
  DateTime? _retryAt;
  bool _running = false;
  bool _stopped = false;
  bool _checking = false;
  bool _checkAgain = false;
  int _inputRevision = 0;

  void start() {
    if (_stopped || _running) return;
    _running = true;
    _taskSubscription = _database
        .tableUpdates(TableUpdateQuery.onTable(_database.tasks))
        .listen((_) => unawaited(checkNow()));
    _accountSyncSubscription = _accountSyncChanges.listen((accountId) {
      if (accountId == _activeAccountId()) unawaited(checkNow());
    });
    // Also catches resume from suspension and system clock/time-zone changes.
    _clockTimer = Timer.periodic(_interval, (_) => unawaited(checkNow()));
    unawaited(checkNow());
  }

  void inputsChanged() {
    if (_stopped) return;
    _inputRevision++;
    _retryAt = null;
    unawaited(checkNow());
  }

  void stop() {
    _stopped = true;
    _running = false;
    _clockTimer?.cancel();
    _nextCheckTimer?.cancel();
    unawaited(_taskSubscription?.cancel());
    unawaited(_accountSyncSubscription?.cancel());
  }

  Future<void> checkNow() async {
    if (_stopped) return;
    if (_checking) {
      _checkAgain = true;
      return;
    }
    _checking = true;
    try {
      do {
        _checkAgain = false;
        await _evaluate();
      } while (!_stopped && _checkAgain);
    } finally {
      _checking = false;
      _scheduleNextCheck();
    }
  }

  Future<void> _evaluate() async {
    final now = _now();
    final today = _date(now);
    final settings = _settings();
    final accountId = _activeAccountId();
    if (!settings.notifyDueToday ||
        accountId == null ||
        _syncBlocksDelivery(accountId) ||
        settings.lastDueTodayNotificationDate == today ||
        (_retryAt != null && now.isBefore(_retryAt!))) {
      return;
    }
    final tasks =
        await (_database.select(_database.tasks)..where(
              (row) =>
                  row.accountId.equals(accountId) &
                  row.dueUtc.equals(today) &
                  row.pendingDelete.equals(false) &
                  row.serverMissing.equals(false) &
                  (row.deleted.isNull() | row.deleted.equals(false)) &
                  (row.hidden.isNull() | row.hidden.equals(false)),
            ))
            .get();
    if (_stopped) return;
    if (_activeAccountId() != accountId || _date(_now()) != today) {
      _checkAgain = true;
      return;
    }
    // Synchronization may have started while the task query was awaiting the
    // database. Its completion transition will trigger a fresh evaluation.
    if (_syncBlocksDelivery(accountId)) return;
    if (!_settings().notifyDueToday ||
        _settings().lastDueTodayNotificationDate == today) {
      return;
    }
    final count = tasks.where((task) => task.status != 'completed').length;
    if (count == 0) return;
    final revision = _inputRevision;
    final result = await _notifications().notifyDueToday(count);
    if (_stopped) return;
    if (result.status == ReminderDeliveryStatus.delivered) {
      _retryAt = null;
      await _markNotified(today);
    } else if (revision == _inputRevision) {
      _retryAt = result.retryAtUtc?.toLocal();
    }
  }

  void _scheduleNextCheck() {
    if (_stopped || !_running) return;
    _nextCheckTimer?.cancel();
    final now = _now();
    var next = DateTime(now.year, now.month, now.day + 1);
    final retryAt = _retryAt;
    if (retryAt != null && retryAt.isAfter(now) && retryAt.isBefore(next)) {
      next = retryAt;
    }
    // Timer truncates sub-millisecond durations. Round up so a midnight check
    // cannot run just before the date changes and skip the new day's summary.
    _nextCheckTimer = Timer(
      next.difference(now) + const Duration(milliseconds: 1),
      () {
        // A previous day's suppression must not defer the new day's summary.
        _retryAt = null;
        unawaited(checkNow());
      },
    );
  }

  String _date(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}

bool _neverBlocked(String _) => false;

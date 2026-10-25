import 'dart:async';

import 'package:drift/drift.dart';

import 'daily_summary_policy.dart';
import '../accounts/data/accounts_repository.dart';
import '../../app/app_settings.dart';
import '../../db/app_database.dart';
import 'desktop_notification_service.dart';

/// Evaluates the all-account summary with app-wide once-per-local-day history. Task imports, local midnight, settings, and retries all enter the
/// same serialized path.
class DueTodayNotificationScheduler {
  DueTodayNotificationScheduler({
    required AppDatabase database,
    required AppSettings Function() settings,
    required DesktopNotificationService Function() notifications,
    required Future<void> Function(String date) markNotified,
    FutureOr<bool> Function(String accountId)? syncBlocksDelivery,
    Stream<String>? accountSyncChanges,
    DateTime Function()? now,
    Duration interval = const Duration(minutes: 1),
  }) : _database = database,
       _settings = settings,
       _notifications = notifications,
       _markNotified = markNotified,
       _syncBlocksDelivery = syncBlocksDelivery ?? _neverBlocked,
       _accountSyncChanges = accountSyncChanges ?? const Stream<String>.empty(),
       _now = now ?? DateTime.now,
       _interval = interval;

  final AppDatabase _database;
  final AppSettings Function() _settings;
  final DesktopNotificationService Function() _notifications;
  final Future<void> Function(String date) _markNotified;
  final FutureOr<bool> Function(String accountId) _syncBlocksDelivery;
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
  Future<void>? _checkingFuture;
  bool _checkAgain = false;
  int _inputRevision = 0;
  AppSettings? _presentationSettings;
  String? _evaluatedDate;
  DesktopNotificationService? _cleanupService;

  void start() {
    if (_stopped || _running) return;
    _running = true;
    _taskSubscription = _database
        .tableUpdates(
          TableUpdateQuery.allOf([
            TableUpdateQuery.onTable(_database.tasks),
            TableUpdateQuery.onTable(_database.taskLists),
          ]),
        )
        .listen((_) => unawaited(checkNow()));
    _accountSyncSubscription = _accountSyncChanges.listen((accountId) {
      unawaited(checkNow());
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

  Future<void> checkNow() {
    if (_stopped) return Future<void>.value();
    if (_checking) {
      _checkAgain = true;
      return _checkingFuture ?? Future<void>.value();
    }
    return _checkingFuture = _checkLoop();
  }

  Future<void> _checkLoop() async {
    _checking = true;
    try {
      do {
        _checkAgain = false;
        await _evaluate();
      } while (!_stopped && _checkAgain);
    } finally {
      _checking = false;
      _checkingFuture = null;
      _scheduleNextCheck();
    }
  }

  Future<void> _evaluate() async {
    final now = _now();
    final today = _date(now);
    final settings = _settings();
    final previous = _presentationSettings;
    if (_cleanupService != null &&
        await _cleanupService!.cancelReminder('due-today')) {
      _cleanupService = null;
    }
    if (!settings.notifyDueToday ||
        previous == null &&
            settings.notificationDetailLevel ==
                NotificationDetailLevel.private ||
        previous != null &&
            (previous.notificationDetailLevel !=
                        settings.notificationDetailLevel &&
                    settings.notificationDetailLevel ==
                        NotificationDetailLevel.private ||
                previous.localeTag != settings.localeTag) ||
        _evaluatedDate != null && _evaluatedDate != today) {
      final notifications = _notifications();
      if (!await notifications.cancelReminder('due-today')) {
        _cleanupService = notifications;
      }
    }
    _presentationSettings = settings;
    _evaluatedDate = today;
    final accountIds =
        (await (_database.select(_database.accounts)..where(
                  (row) =>
                      row.authState.isIn(accountLocalReminderEligibleStates),
                ))
                .get())
            .map((row) => row.id)
            .toList();
    if (!settings.notifyDueToday ||
        accountIds.isEmpty ||
        now.isBefore(
          dailySummaryTime(now, settings.dueTodayNotificationTime),
        ) ||
        (_retryAt != null && now.isBefore(_retryAt!))) {
      return;
    }
    for (final id in accountIds) {
      if (await _syncBlocksDelivery(id)) return;
    }
    final tasks = await notificationTasksDueOn(_database, now);
    if (_stopped) return;
    if (_date(_now()) != today) {
      _checkAgain = true;
      return;
    }
    // Synchronization may have started while the task query was awaiting the
    // database. Its completion transition will trigger a fresh evaluation.
    for (final id in accountIds) {
      if (await _syncBlocksDelivery(id)) return;
    }
    if (!_settings().notifyDueToday) return;
    final count = tasks.length;
    if (count == 0) {
      await _notifications().cancelReminder('due-today');
      return;
    }
    if (_settings().lastDueTodayNotificationDate == today) return;
    if (await (_database.select(
          _database.dailySummaryHistory,
        )..where((row) => row.localDate.equals(today))).getSingleOrNull() !=
        null) {
      return;
    }
    final revision = _inputRevision;
    final notifications = _notifications();
    final result = await notifications.notifyDueToday(count, date: today);
    // A browsing/settings write during submission does not invalidate this
    // all-account snapshot. Withdrawing it would consume the day's opportunity
    // without leaving a post the user can open. Privacy/category/locale/date
    // changes still withdraw a submission that completed with stale content.
    final current = _stopped ? null : _settings();
    if (result.status == ReminderDeliveryStatus.delivered &&
        (current == null ||
            !current.notifyDueToday ||
            current.notificationDetailLevel ==
                    NotificationDetailLevel.private &&
                !notifications.isPrivate ||
            current.localeTag != notifications.presentationSettings.localeTag ||
            _date(_now()) != today)) {
      if (!await notifications.cancelReminder('due-today')) {
        _cleanupService = notifications;
      }
    }
    if (_stopped) return;
    if (result.status == ReminderDeliveryStatus.delivered) {
      _retryAt = null;
      await _database
          .into(_database.dailySummaryHistory)
          .insertOnConflictUpdate(
            DailySummaryHistoryCompanion.insert(
              localDate: today,
              consumedAtUtc: _now().toUtc().millisecondsSinceEpoch,
            ),
          );
      await _markNotified(today);
    } else if (revision == _inputRevision) {
      _retryAt = result.retryAtUtc?.toLocal();
    }
  }

  void _scheduleNextCheck() {
    if (_stopped || !_running) return;
    _nextCheckTimer?.cancel();
    final now = _now();
    var next = dailySummaryTime(now, _settings().dueTodayNotificationTime);
    if (!next.isAfter(now)) {
      next = dailySummaryTime(
        DateTime(now.year, now.month, now.day + 1),
        _settings().dueTodayNotificationTime,
      );
    }
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

FutureOr<bool> _neverBlocked(String _) => false;

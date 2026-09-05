import 'dart:async';

import 'package:drift/drift.dart';

import '../../db/app_database.dart';
import '../accounts/data/accounts_repository.dart';
import 'desktop_notification_service.dart';

const defaultReminderSnoozeDuration = Duration(minutes: 10);

class NotificationScheduler {
  NotificationScheduler({
    required AppDatabase database,
    required DesktopNotificationService notifications,
    Duration interval = const Duration(minutes: 1),
    DateTime Function()? nowUtc,
    Duration snoozeDuration = defaultReminderSnoozeDuration,
    Future<void> Function(NotificationScheduleData row)?
    onNotificationActivated,
  }) : _database = database,
       _notifications = notifications,
       _interval = interval,
       _nowUtc = nowUtc ?? (() => DateTime.now().toUtc()),
       _snoozeDuration = snoozeDuration,
       _onNotificationActivated = onNotificationActivated;

  final AppDatabase _database;
  final DesktopNotificationService _notifications;
  final Duration _interval;
  final DateTime Function() _nowUtc;
  final Duration _snoozeDuration;
  final Future<void> Function(NotificationScheduleData row)?
  _onNotificationActivated;
  Timer? _timer;
  Timer? _dueTimer;
  StreamSubscription<List<NotificationScheduleData>>? _scheduleSubscription;
  StreamSubscription<List<Account>>? _accountSubscription;
  var _checking = false;
  var _checkAgain = false;
  final Map<String, int> _deferredUntilUtc = {};
  final Set<String> _disabledNotificationIds = {};

  void start() {
    _timer ??= Timer.periodic(_interval, (_) => unawaited(checkNow()));
    _scheduleSubscription ??= _database
        .select(_database.notificationSchedule)
        .watch()
        .listen((_) => unawaited(_handleScheduleChanged()));
    _accountSubscription ??= _database
        .select(_database.accounts)
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
    unawaited(_accountSubscription?.cancel());
    _accountSubscription = null;
    _deferredUntilUtc.clear();
    _disabledNotificationIds.clear();
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
        await _scheduleNextDueCheck();
      } while (_checkAgain);
    } finally {
      _checking = false;
    }
  }

  Future<void> _checkDueNotifications() async {
    final now = _nowUtc().millisecondsSinceEpoch;
    final signedInAccountIds = await _signedInAccountIds();
    if (signedInAccountIds.isEmpty) {
      return;
    }
    final rows =
        await (_database.select(_database.notificationSchedule)..where(
              (row) =>
                  row.accountId.isIn(signedInAccountIds) &
                  row.sentAtUtc.isNull() &
                  row.dismissedAtUtc.isNull() &
                  ((row.snoozedUntilUtc.isNull() &
                          row.scheduledAtUtc.isSmallerOrEqualValue(now)) |
                      (row.snoozedUntilUtc.isNotNull() &
                          row.snoozedUntilUtc.isSmallerOrEqualValue(now))),
            ))
            .get();
    rows.sort(
      (left, right) =>
          _effectiveDueAtUtc(left).compareTo(_effectiveDueAtUtc(right)),
    );
    for (final row in rows) {
      if (_disabledNotificationIds.contains(row.id) ||
          _effectiveDueAtUtc(row) > now) {
        continue;
      }
      if (!await _isAccountSignedIn(row.accountId)) {
        continue;
      }
      final ReminderDeliveryResult result;
      if (row.sourceType == 'event') {
        result = await _notifications.notifyEventReminder(
          row.title,
          row.body,
          stableId: row.id,
          payload: _activationPayload(row),
          onAction: (action) => _handleReminderAction(row, action),
        );
      } else if (row.sourceType == 'task') {
        result = await _notifications.notifyTaskReminder(
          row.title,
          row.body,
          stableId: row.id,
          payload: _activationPayload(row),
          onAction: (action) => _handleReminderAction(row, action),
        );
      } else {
        continue;
      }
      switch (result.status) {
        case ReminderDeliveryStatus.delivered:
          _deferredUntilUtc.remove(row.id);
          _disabledNotificationIds.remove(row.id);
          await _markDeliveredUnlessActionAlreadyHandled(row);
        case ReminderDeliveryStatus.deferred:
        case ReminderDeliveryStatus.failed:
          final retryAt = result.retryAtUtc;
          if (retryAt != null) {
            _deferredUntilUtc[row.id] = retryAt.millisecondsSinceEpoch;
          }
        case ReminderDeliveryStatus.disabled:
          _disabledNotificationIds.add(row.id);
      }
    }
  }

  Map<String, String> _activationPayload(NotificationScheduleData row) => {
    'notificationScheduleId': row.id,
    'itemKind': row.sourceType,
    'accountId': row.accountId,
    'itemId': row.sourceId,
  };

  Future<void> _scheduleNextDueCheck() async {
    _dueTimer?.cancel();
    _dueTimer = null;

    final signedInAccountIds = await _signedInAccountIds();
    if (signedInAccountIds.isEmpty) {
      return;
    }
    final pending =
        await (_database.select(_database.notificationSchedule)..where(
              (row) =>
                  row.accountId.isIn(signedInAccountIds) &
                  row.sentAtUtc.isNull() &
                  row.dismissedAtUtc.isNull(),
            ))
            .get();
    final nextDueAt = pending
        .where((row) => !_disabledNotificationIds.contains(row.id))
        .map(_effectiveDueAtUtc)
        .fold<int?>(null, (earliest, value) {
          return earliest == null || value < earliest ? value : earliest;
        });
    if (nextDueAt == null) {
      return;
    }

    final now = _nowUtc().millisecondsSinceEpoch;
    final delay = Duration(
      milliseconds: (nextDueAt - now).clamp(0, 2147483647),
    );
    _dueTimer = Timer(delay, () => unawaited(checkNow()));
  }

  int _effectiveDueAtUtc(NotificationScheduleData row) {
    var dueAt = row.scheduledAtUtc;
    final snoozedUntil = row.snoozedUntilUtc;
    if (snoozedUntil != null && snoozedUntil > dueAt) {
      dueAt = snoozedUntil;
    }
    final deferredUntil = _deferredUntilUtc[row.id];
    if (deferredUntil != null && deferredUntil > dueAt) {
      dueAt = deferredUntil;
    }
    return dueAt;
  }

  Future<void> _markDeliveredUnlessActionAlreadyHandled(
    NotificationScheduleData deliveredRow,
  ) async {
    final current = await (_database.select(
      _database.notificationSchedule,
    )..where((table) => table.id.equals(deliveredRow.id))).getSingleOrNull();
    if (current == null || current.dismissedAtUtc != null) return;

    final now = _nowUtc().millisecondsSinceEpoch;
    final snoozedUntil = current.snoozedUntilUtc;
    if (snoozedUntil != null && snoozedUntil > now) return;

    await (_database.update(
      _database.notificationSchedule,
    )..where((table) => table.id.equals(deliveredRow.id))).write(
      NotificationScheduleCompanion(
        sentAtUtc: Value(now),
        snoozedUntilUtc: const Value(null),
        updatedAtLocal: Value(DateTime.now().millisecondsSinceEpoch),
      ),
    );
  }

  Future<void> _handleReminderAction(
    NotificationScheduleData row,
    ReminderNotificationAction action,
  ) async {
    switch (action) {
      case ReminderNotificationAction.open:
        await _onNotificationActivated?.call(row);
        return;
      case ReminderNotificationAction.snooze:
        final now = _nowUtc();
        await (_database.update(
          _database.notificationSchedule,
        )..where((table) => table.id.equals(row.id))).write(
          NotificationScheduleCompanion(
            sentAtUtc: const Value(null),
            dismissedAtUtc: const Value(null),
            snoozedUntilUtc: Value(
              now.add(_snoozeDuration).millisecondsSinceEpoch,
            ),
            updatedAtLocal: Value(DateTime.now().millisecondsSinceEpoch),
          ),
        );
      case ReminderNotificationAction.dismiss:
        await (_database.update(
          _database.notificationSchedule,
        )..where((table) => table.id.equals(row.id))).write(
          NotificationScheduleCompanion(
            dismissedAtUtc: Value(_nowUtc().millisecondsSinceEpoch),
            snoozedUntilUtc: const Value(null),
            updatedAtLocal: Value(DateTime.now().millisecondsSinceEpoch),
          ),
        );
    }
    _deferredUntilUtc.remove(row.id);
    _disabledNotificationIds.remove(row.id);
    await checkNow();
  }

  /// Routes a process-independent desktop activation through the same action
  /// path used for an in-process notification callback.
  Future<void> handleActivation({
    required String notificationScheduleId,
    required String action,
  }) async {
    final row =
        await (_database.select(_database.notificationSchedule)
              ..where((table) => table.id.equals(notificationScheduleId)))
            .getSingleOrNull();
    if (row == null) return;
    final parsedAction = switch (action) {
      'default' || 'open' => ReminderNotificationAction.open,
      'snooze' => ReminderNotificationAction.snooze,
      'dismiss' => ReminderNotificationAction.dismiss,
      _ => null,
    };
    if (parsedAction == null) return;

    // Snooze and dismiss are safe under duplicate Windows toast delivery.
    if (parsedAction == ReminderNotificationAction.dismiss &&
        row.dismissedAtUtc != null) {
      return;
    }
    if (parsedAction == ReminderNotificationAction.snooze &&
        row.snoozedUntilUtc != null &&
        row.snoozedUntilUtc! > _nowUtc().millisecondsSinceEpoch) {
      return;
    }
    await _handleReminderAction(row, parsedAction);
  }

  Future<List<String>> _signedInAccountIds() async {
    final accounts = await (_database.select(
      _database.accounts,
    )..where((row) => row.authState.equals(accountAuthStateSignedIn))).get();
    return [for (final account in accounts) account.id];
  }

  Future<bool> _isAccountSignedIn(String accountId) async {
    final account =
        await (_database.select(_database.accounts)..where(
              (row) =>
                  row.id.equals(accountId) &
                  row.authState.equals(accountAuthStateSignedIn),
            ))
            .getSingleOrNull();
    return account != null;
  }
}

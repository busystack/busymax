import 'dart:async';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../db/app_database.dart';
import '../accounts/data/accounts_repository.dart';
import 'desktop_notification_service.dart';
import 'notification_identity.dart';
import 'notification_schedule_service.dart';
import 'reminder_presentation.dart';

import 'reminder_delivery_policy.dart';
export 'reminder_delivery_policy.dart' show defaultReminderSnoozeDuration;

typedef ScheduledReminderActionHandler = Future<void> Function(
  NotificationScheduleData row,
  ReminderNotificationAction action,
);

class NotificationScheduler {
  NotificationScheduler({
    required AppDatabase database,
    required DesktopNotificationService notifications,
    Duration interval = const Duration(minutes: 1),
    DateTime Function()? nowUtc,
    Duration snoozeDuration = defaultReminderSnoozeDuration,
    Future<void> Function(NotificationScheduleData row)?
    onNotificationActivated,
    ScheduledReminderActionHandler? onReminderAction,
    Future<void> Function()? beforeCheck,
    Future<void> Function()? onUnavailable,
  }) : _database = database,
       _notifications = notifications,
       _interval = interval,
       _nowUtc = nowUtc ?? (() => DateTime.now().toUtc()),
       _snoozeDuration = snoozeDuration,
       _onNotificationActivated = onNotificationActivated,
       _onReminderAction = onReminderAction,
       _beforeCheck = beforeCheck,
       _onUnavailable = onUnavailable;

  final AppDatabase _database;
  DesktopNotificationService _notifications;
  final Duration _interval;
  final DateTime Function() _nowUtc;
  final Duration _snoozeDuration;
  final Future<void> Function(NotificationScheduleData row)?
  _onNotificationActivated;
  final ScheduledReminderActionHandler? _onReminderAction;
  final Future<void> Function()? _beforeCheck;
  final Future<void> Function()? _onUnavailable;
  Timer? _timer;
  Timer? _dueTimer;
  StreamSubscription<List<NotificationScheduleData>>? _scheduleSubscription;
  StreamSubscription<List<Account>>? _accountSubscription;
  var _running = false;
  var _stopped = false;
  var _checking = false;
  var _checkAgain = false;
  var _settingsRevision = 0;
  final Map<String, int> _deferredUntilUtc = {};
  final Set<String> _disabledNotificationIds = {};
  final Map<String, NotificationScheduleData> _knownSchedules = {};
  final Set<String> _withdrawSourceTypes = {};
  final Set<String> _withdrawnDeliveryIds = {};

  void start() {
    if (_stopped || _running) return;
    _running = true;
    _timer = Timer.periodic(_interval, (_) => unawaited(checkNow()));
    _scheduleSubscription = _database
        .select(_database.notificationSchedule)
        .watch()
        .listen((_) => unawaited(checkNow()));
    _accountSubscription = _database
        .select(_database.accounts)
        .watch()
        .listen((_) => unawaited(checkNow()));
    unawaited(checkNow());
  }

  /// Settings change without retiring the scheduler or its visible actions.
  void updateNotifications(DesktopNotificationService notifications) {
    if (_stopped) return;
    final previous = _notifications.presentationSettings;
    final next = notifications.presentationSettings;
    final privacyOrLocale =
        (previous.notificationDetailLevel != next.notificationDetailLevel &&
            notifications.isPrivate) ||
        previous.localeTag != next.localeTag;
    if (privacyOrLocale ||
        previous.notifyEventReminders && !next.notifyEventReminders) {
      _withdrawSourceTypes.add('event');
    }
    if (privacyOrLocale ||
        previous.notifyTaskReminders && !next.notifyTaskReminders) {
      _withdrawSourceTypes.add('task');
    }
    _notifications = notifications;
    _settingsRevision++;
    _deferredUntilUtc.clear();
    _disabledNotificationIds.clear();
    unawaited(
      _database
          .update(_database.notificationSchedule)
          .write(
            const NotificationScheduleCompanion(deferredUntilUtc: Value(null)),
          ),
    );
    unawaited(checkNow());
  }

  /// Terminal: neither callbacks nor work already awaiting delivery may rearm it.
  void stop() {
    _stopped = true;
    _running = false;
    _checkAgain = false;
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
    _knownSchedules.clear();
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
        await _beforeCheck?.call();
        if (_stopped) return;
        await _notifications.retryReminderCancellations();
        if (_stopped) return;
        await _cancelObsoleteNotifications();
        if (_stopped) return;
        await _checkDueNotifications();
        if (_stopped) return;
        await _scheduleNextDueCheck();
      } while (!_stopped && _checkAgain);
    } on Object {
      if (!_stopped) rethrow;
    } finally {
      _checking = false;
    }
  }

  // Watching the schedule also covers deletions outside schedule rebuilding,
  // including account cascades and local calendar/task mutations.
  Future<void> _cancelObsoleteNotifications() async {
    final rows = await _database.select(_database.notificationSchedule).get();
    if (_stopped) return;
    final current = {for (final row in rows) row.id: row};
    await _notifications.reconcileReminderIdentities({
      for (final row in rows)
        if (row.dismissedAtUtc == null && row.expiredAtUtc == null)
          _deliveryId(row),
    });
    for (final previous in _knownSchedules.values.toList()) {
      final row = current[previous.id];
      if (row == null ||
          row.generation != previous.generation ||
          row.scheduledAtUtc != previous.scheduledAtUtc ||
          (row.dismissedAtUtc != null && previous.dismissedAtUtc == null) ||
          row.expiredAtUtc != null) {
        final deliveryId = _deliveryId(previous);
        await _cancelReminder(deliveryId);
        if (_stopped) return;
        _deferredUntilUtc.remove(deliveryId);
        _disabledNotificationIds.remove(deliveryId);
      }
    }
    for (final row in rows) {
      if (row.sentAtUtc != null &&
          (_withdrawSourceTypes.contains(row.sourceType) ||
              !_notifications.allowsReminder(row.sourceType) ||
              _notifications.isPrivate && !row.sentPrivate) &&
          !_withdrawnDeliveryIds.contains(_deliveryId(row))) {
        if (await _notifications.cancelReminder(_deliveryId(row))) {
          _withdrawnDeliveryIds.add(_deliveryId(row));
        }
      }
    }
    _withdrawSourceTypes.clear();
    _knownSchedules
      ..clear()
      ..addAll(current);
  }

  Future<void> _checkDueNotifications() async {
    final now = _nowUtc().millisecondsSinceEpoch;
    final accountIds = await _reminderEligibleAccountIds();
    if (_stopped || accountIds.isEmpty) return;
    final rows =
        await (_database.select(_database.notificationSchedule)..where(
              (row) =>
                  row.accountId.isIn(accountIds) &
                  row.sentAtUtc.isNull() &
                  row.expiredAtUtc.isNull() &
                  row.dismissedAtUtc.isNull() &
                  ((row.snoozedUntilUtc.isNull() &
                          row.scheduledAtUtc.isSmallerOrEqualValue(now)) |
                      (row.snoozedUntilUtc.isNotNull() &
                          row.snoozedUntilUtc.isSmallerOrEqualValue(now))),
            ))
            .get();
    if (_stopped) return;
    rows.sort((a, b) => _effectiveDueAtUtc(a).compareTo(_effectiveDueAtUtc(b)));
    for (final pending in rows) {
      if (_stopped) return;
      if (_disabledNotificationIds.contains(_deliveryId(pending)) ||
          _effectiveDueAtUtc(pending) > now ||
          !const {'event', 'task'}.contains(pending.sourceType)) {
        continue;
      }
      final eligible = await _isAccountReminderEligible(pending.accountId);
      if (_stopped) return;
      if (!eligible) continue;
      final row = await _claimReminder(pending);
      if (_stopped) return;
      if (row == null) {
        await _cancelReminder(_deliveryId(pending));
        _checkAgain = true;
        continue;
      }
      _knownSchedules[row.id] = row;
      final deliveryId = _deliveryId(row);
      final notifications = _notifications;
      final settingsRevision = _settingsRevision;
      final presentation = await reminderPresentation(
        _database,
        row,
        notifications.presentationSettings,
      );
      if (_stopped) return;
      if (settingsRevision != _settingsRevision) {
        _checkAgain = true;
        continue;
      }
      Future<void> onAction(ReminderNotificationAction action) =>
          (_onReminderAction ?? handleReminderAction)(row, action);
      final result = row.sourceType == 'event'
          ? await notifications.notifyEventReminder(
              presentation.title,
              presentation.body,
              stableId: deliveryId,
              payload: _activationPayload(row),
              onAction: onAction,
            )
          : await notifications.notifyTaskReminder(
              presentation.title,
              presentation.body,
              stableId: deliveryId,
              payload: _activationPayload(row),
              onAction: onAction,
            );
      if (_stopped) {
        if (result.status == ReminderDeliveryStatus.delivered) {
          await notifications.cancelReminder(deliveryId);
        }
        return;
      }
      switch (result.status) {
        case ReminderDeliveryStatus.delivered:
          final marked = await _markDelivered(
            row,
            private: notifications.isPrivate,
          );
          if (!marked || settingsRevision != _settingsRevision) {
            await _cancelReminder(deliveryId);
          }
        case ReminderDeliveryStatus.deferred:
          await (_database.update(
            _database.notificationSchedule,
          )..where((table) => _pendingDelivery(table, row))).write(
            NotificationScheduleCompanion(
              deferredUntilUtc: Value(
                result.retryAtUtc?.millisecondsSinceEpoch,
              ),
            ),
          );
          final retryAt = result.retryAtUtc;
          if (settingsRevision == _settingsRevision && retryAt != null) {
            _deferredUntilUtc[deliveryId] = retryAt.millisecondsSinceEpoch;
          }
        case ReminderDeliveryStatus.failed:
          final retryAt = result.retryAtUtc;
          if (settingsRevision == _settingsRevision && retryAt != null) {
            _deferredUntilUtc[deliveryId] = retryAt.millisecondsSinceEpoch;
          }
        case ReminderDeliveryStatus.disabled:
          if (settingsRevision == _settingsRevision) {
            _disabledNotificationIds.add(deliveryId);
          }
      }
    }
  }

  Future<void> _cancelReminder(String deliveryId) async {
    await _notifications.cancelReminder(deliveryId);
  }

  Future<bool> _isReminderCurrent(NotificationScheduleData row) =>
      NotificationScheduleService(
        database: _database,
        nowUtc: _nowUtc,
      ).validateAndReconcileReminder(row);

  Future<NotificationScheduleData?> _claimReminder(
    NotificationScheduleData pending,
  ) => _database.transaction(() async {
    if (_stopped) return null;
    final reminderCurrent = await _isReminderCurrent(pending);
    if (_stopped || !reminderCurrent) return null;
    // Validation and claiming use one snapshot. Source changes committed
    // before this attempt cannot leave the old alarm eligible for delivery.
    final generation = const Uuid().v4();
    final claimed =
        await (_database.update(
          _database.notificationSchedule,
        )..where((table) => _pendingDelivery(table, pending))).write(
          NotificationScheduleCompanion(generation: Value(generation)),
        );
    return claimed == 0 ? null : pending.copyWith(generation: generation);
  });

  String _deliveryId(NotificationScheduleData row) =>
      notificationDeliveryId(row.id, row.generation);

  Map<String, String> _activationPayload(NotificationScheduleData row) => {
    'notificationScheduleId': row.id,
    'notificationGeneration': row.generation,
    'itemKind': row.sourceType,
    'accountId': row.accountId,
    'itemId': row.sourceId,
  };

  Future<void> _scheduleNextDueCheck() async {
    if (_stopped || !_running) return;
    _dueTimer?.cancel();
    _dueTimer = null;
    final accountIds = await _reminderEligibleAccountIds();
    if (_stopped || accountIds.isEmpty) return;
    final pending =
        await (_database.select(_database.notificationSchedule)..where(
              (row) =>
                  row.accountId.isIn(accountIds) &
                  row.sentAtUtc.isNull() &
                  row.expiredAtUtc.isNull() &
                  row.dismissedAtUtc.isNull(),
            ))
            .get();
    if (_stopped) return;
    final nextDueAt = pending
        .where((row) => !_disabledNotificationIds.contains(_deliveryId(row)))
        .map(_effectiveDueAtUtc)
        .fold<int?>(null, (earliest, value) {
          return earliest == null || value < earliest ? value : earliest;
        });
    if (nextDueAt == null) return;
    final delay = Duration(
      milliseconds: (nextDueAt - _nowUtc().millisecondsSinceEpoch).clamp(
        0,
        2147483647,
      ),
    );
    _dueTimer = Timer(delay, () => unawaited(checkNow()));
  }

  int _effectiveDueAtUtc(NotificationScheduleData row) {
    var dueAt = row.scheduledAtUtc;
    final snoozedUntil = row.snoozedUntilUtc;
    if (snoozedUntil != null && snoozedUntil > dueAt) dueAt = snoozedUntil;
    final deferredUntil = _deferredUntilUtc[_deliveryId(row)];
    if (deferredUntil != null && deferredUntil > dueAt) dueAt = deferredUntil;
    if (row.deferredUntilUtc != null && row.deferredUntilUtc! > dueAt) {
      dueAt = row.deferredUntilUtc!;
    }
    return dueAt;
  }

  Expression<bool> _sameDelivery(
    $NotificationScheduleTable table,
    NotificationScheduleData row,
  ) =>
      table.id.equals(row.id) &
      table.generation.equals(row.generation) &
      table.scheduledAtUtc.equals(row.scheduledAtUtc);

  Expression<bool> _pendingDelivery(
    $NotificationScheduleTable table,
    NotificationScheduleData row,
  ) =>
      _sameDelivery(table, row) &
      table.sentAtUtc.isNull() &
      table.expiredAtUtc.isNull() &
      table.dismissedAtUtc.isNull() &
      (row.snoozedUntilUtc == null
          ? table.snoozedUntilUtc.isNull()
          : table.snoozedUntilUtc.equals(row.snoozedUntilUtc!));

  Future<bool> _markDelivered(
    NotificationScheduleData row, {
    required bool private,
  }) => _database.transaction(() async {
    if (_stopped) return false;
    final reminderCurrent = await _isReminderCurrent(row);
    if (_stopped || !reminderCurrent) return false;
    // One conditional write: no lookup/update race with edits or actions.
    final updated =
        await (_database.update(
          _database.notificationSchedule,
        )..where((table) => _pendingDelivery(table, row))).write(
          NotificationScheduleCompanion(
            sentAtUtc: Value(_nowUtc().millisecondsSinceEpoch),
            sentPrivate: Value(private),
            snoozedUntilUtc: const Value(null),
            deferredUntilUtc: const Value(null),
            updatedAtLocal: Value(DateTime.now().millisecondsSinceEpoch),
          ),
        );
    return updated != 0;
  });

  Future<void> handleReminderAction(
    NotificationScheduleData row,
    ReminderNotificationAction action,
  ) async {
    if (_stopped) return;
    if (action == ReminderNotificationAction.open) {
      final current = await (_database.select(
        _database.notificationSchedule,
      )..where((table) => _sameDelivery(table, row))).getSingleOrNull();
      if (!_stopped &&
          current != null &&
          current.dismissedAtUtc == null &&
          current.expiredAtUtc == null) {
        await _onNotificationActivated?.call(current);
      } else if (!_stopped) {
        await _onUnavailable?.call();
      }
      return;
    }
    final updated =
        await (_database.update(_database.notificationSchedule)..where(
              (table) =>
                  _sameDelivery(table, row) &
                  table.dismissedAtUtc.isNull() &
                  table.expiredAtUtc.isNull(),
            ))
            .write(
              action == ReminderNotificationAction.snooze
                  ? NotificationScheduleCompanion(
                      generation: Value(const Uuid().v4()),
                      sentAtUtc: const Value(null),
                      deferredUntilUtc: const Value(null),
                      snoozedUntilUtc: Value(
                        _nowUtc().add(_snoozeDuration).millisecondsSinceEpoch,
                      ),
                      updatedAtLocal: Value(
                        DateTime.now().millisecondsSinceEpoch,
                      ),
                    )
                  : NotificationScheduleCompanion(
                      dismissedAtUtc: Value(_nowUtc().millisecondsSinceEpoch),
                      snoozedUntilUtc: const Value(null),
                      updatedAtLocal: Value(
                        DateTime.now().millisecondsSinceEpoch,
                      ),
                    ),
            );
    if (updated == 0) return;
    final deliveryId = _deliveryId(row);
    await _cancelReminder(deliveryId);
    _deferredUntilUtc.remove(deliveryId);
    _disabledNotificationIds.remove(deliveryId);
    await checkNow();
  }

  /// Warm and cold Windows activations use the persisted delivery generation.
  /// Legacy toasts can only act on schedules that have never been superseded.
  Future<void> handleActivation({
    required String notificationScheduleId,
    required String action,
    String notificationGeneration = 'legacy',
  }) async {
    if (_stopped) return;
    final row =
        await (_database.select(_database.notificationSchedule)..where(
              (table) =>
                  table.id.equals(notificationScheduleId) &
                  table.generation.equals(notificationGeneration),
            ))
            .getSingleOrNull();
    if (_stopped) return;
    if (row == null) {
      if (action == 'default' || action == 'open') await _onUnavailable?.call();
      return;
    }
    final parsedAction = switch (action) {
      'default' || 'open' => ReminderNotificationAction.open,
      'snooze' => ReminderNotificationAction.snooze,
      'dismiss' => ReminderNotificationAction.dismiss,
      _ => null,
    };
    if (parsedAction != null) await handleReminderAction(row, parsedAction);
  }

  Future<List<String>> _reminderEligibleAccountIds() async {
    final accounts =
        await (_database.select(_database.accounts)..where(
              (row) => row.authState.isIn(accountLocalReminderEligibleStates),
            ))
            .get();
    return [for (final account in accounts) account.id];
  }

  Future<bool> _isAccountReminderEligible(String accountId) async {
    final account =
        await (_database.select(_database.accounts)..where(
              (row) =>
                  row.id.equals(accountId) &
                  row.authState.isIn(accountLocalReminderEligibleStates),
            ))
            .getSingleOrNull();
    return account != null;
  }
}

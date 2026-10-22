import '../../core/auth/oauth_models.dart';
import '../../core/http/request_dispatch_exception.dart';

import 'dart:async';
import 'dart:ui';

import '../../../l10n/generated/app_localizations.dart';
import '../../app/app_settings.dart';
import '../../core/logging/redacting_logger.dart';
import '../../l10n/locale_resolution.dart';
import '../../platform/common/desktop_services.dart';
import '../sync/sync_failure_notification_policy.dart';
import 'desktop_notification_backend.dart';
import 'notification_cancellation_queue.dart';
import 'daily_summary_policy.dart';

export 'desktop_notification_backend.dart';

enum ReminderNotificationAction { open, snooze, dismiss }

enum ReminderDeliveryStatus { delivered, deferred, disabled, failed }

final class ReminderDeliveryResult {
  const ReminderDeliveryResult._(this.status, {this.retryAtUtc});

  const ReminderDeliveryResult.delivered()
    : this._(ReminderDeliveryStatus.delivered);

  const ReminderDeliveryResult.disabled()
    : this._(ReminderDeliveryStatus.disabled);

  const ReminderDeliveryResult.deferred(DateTime retryAtUtc)
    : this._(ReminderDeliveryStatus.deferred, retryAtUtc: retryAtUtc);

  const ReminderDeliveryResult.failed(DateTime retryAtUtc)
    : this._(ReminderDeliveryStatus.failed, retryAtUtc: retryAtUtc);

  final ReminderDeliveryStatus status;
  final DateTime? retryAtUtc;
}

typedef ReminderNotificationActionHandler = Future<void> Function(
  ReminderNotificationAction action,
);

class DesktopNotificationService {
  DesktopNotificationService({
    required DesktopNotificationBackend backend,
    required AppSettings settings,
    NotificationCancellationQueue? cancellationQueue,
    Locale? locale,
    this.onReconnectActivated,
    this.onRoutedNotification,
    this.onDeliveryStateChanged,
    this.deliveryAllowed,
    Duration syncFailureDebounce = const Duration(minutes: 5),
    Duration reminderFailureRetryDelay = const Duration(minutes: 1),
    DateTime Function()? now,
    Future<void> Function(DesktopNavigationDestination destination)?
    onDestinationActivated,
  }) : _backend = backend,
       _cancellations = cancellationQueue ?? NotificationCancellationQueue(),
       _settings = settings,
       _strings = locale == null
           ? NotificationStrings.forLocales(PlatformDispatcher.instance.locales)
           : NotificationStrings.forLocale(locale),
       _syncFailureDebounce = syncFailureDebounce,
       _reminderFailureRetryDelay = reminderFailureRetryDelay,
       _now = now ?? DateTime.now,
       _onDestinationActivated = onDestinationActivated;

  final DesktopNotificationBackend _backend;
  final NotificationCancellationQueue _cancellations;
  final AppSettings _settings;
  final NotificationStrings _strings;
  final Duration _syncFailureDebounce;
  final Duration _reminderFailureRetryDelay;
  final DateTime Function() _now;

  final Future<void> Function(DesktopNavigationDestination destination)?
  _onDestinationActivated;

  final Future<void> Function(String accountId)? onReconnectActivated;
  final Set<String> _reconnectFailures = {};
  final Future<void> Function(Map<String, String> payload)?
  onRoutedNotification;
  final void Function(bool succeeded)? onDeliveryStateChanged;
  final bool Function()? deliveryAllowed;

  DateTime? _lastSyncFailureAt;
  String? _lastSyncFailureBody;

  bool get isPrivate => !_showsNotificationDetails;
  AppSettings get presentationSettings => _settings;

  bool allowsReminder(String sourceType) => sourceType == 'event'
      ? _settings.notifyEventReminders
      : _settings.notifyTaskReminders;

  Future<void> notifySyncFailure(Object error, {String? accountId}) async {
    accountId ??= switch (error) {
      AuthorizationScopedFailure(:final accountId) => accountId,
      AuthorizationScopedOAuthException(:final accountId) => accountId,
      _ => null,
    };
    final disposition = syncFailureNotificationDisposition(error);
    final message = switch (disposition) {
      SyncFailureNotificationDisposition.suppressed => null,
      SyncFailureNotificationDisposition.reconnectRequired =>
        resolveEffectiveSyncFailure(error)
                is OAuthRegistrationUnavailableException
            ? _strings.googleReconnectRequired
            : _strings.reconnectRequired,
      SyncFailureNotificationDisposition.permissionChanged =>
        _strings.permissionChanged,
      SyncFailureNotificationDisposition.unsupportedProvider =>
        _strings.unsupportedProvider,
      SyncFailureNotificationDisposition.temporarilyUnavailable =>
        _strings.temporarilyUnavailable,
    };
    if (message == null || !_settings.notifySyncFailures || _isQuietHours()) {
      return;
    }
    if (disposition == SyncFailureNotificationDisposition.reconnectRequired &&
        _reconnectFailures.contains(accountId ?? 'unknown')) {
      return;
    }
    final body = _showsNotificationDetails
        ? _strings.syncFailureBody(message)
        : _strings.syncFailureBody(_strings.detailsHidden);
    final now = _now();
    if (disposition != SyncFailureNotificationDisposition.reconnectRequired &&
        _lastSyncFailureBody == body &&
        _lastSyncFailureAt != null &&
        now.difference(_lastSyncFailureAt!) < _syncFailureDebounce) {
      return;
    }
    final submitted = await _safeNotify(
      _strings.syncFailureTitle,
      body,
      BusyMaxNotificationCategory.networkError,
      stableId: accountId == null ? 'sync-failure' : 'sync-failure|$accountId',
      payload: {
        'notificationRoute': 'sync-failure',
        if (accountId != null) 'accountId': accountId,
      },
      onActivated: accountId == null || onReconnectActivated == null
          ? null
          : () => onReconnectActivated!(accountId!),
    );
    if (submitted) {
      _lastSyncFailureBody = body;
      _lastSyncFailureAt = now;
      if (disposition == SyncFailureNotificationDisposition.reconnectRequired) {
        _reconnectFailures.add(accountId ?? 'unknown');
      }
    }
  }

  void clearAccountSyncFailure(String accountId) =>
      _reconnectFailures.remove(accountId);

  /// Production operational delivery is reconciled and deduplicated by the
  /// durable coordinator. Only controlled messages cross this boundary.
  Future<ReminderDeliveryResult> deliverOperationalIssue(
    String kind,
    String? accountId,
    String revision,
    int count,
  ) async {
    if (kind == 'conflict'
        ? !_settings.notifyConflicts
        : !_settings.notifySyncFailures) {
      return const ReminderDeliveryResult.disabled();
    }
    final quietEnd = _quietHoursEndUtc();
    if (quietEnd != null) return ReminderDeliveryResult.deferred(quietEnd);
    final message = kind == 'conflict'
        ? _strings.blockedChanges
        : switch (revision) {
            'reconnectRequired' => _strings.reconnectRequired,
            'permissionChanged' => _strings.permissionChanged,
            'unsupportedProvider' => _strings.unsupportedProvider,
            _ => _strings.temporarilyUnavailable,
          };
    final delivered = await _safeNotify(
      kind == 'conflict' ? _strings.conflictTitle : _strings.syncFailureTitle,
      isPrivate ? _strings.detailsHidden : message,
      kind == 'conflict'
          ? BusyMaxNotificationCategory.conflict
          : BusyMaxNotificationCategory.networkError,
      stableId: accountId == null ? kind : '$kind|$accountId',
      payload: {
        'notificationRoute': kind,
        if (accountId != null) 'accountId': accountId,
      },
      private: isPrivate,
      transient: false,
    );
    return delivered
        ? const ReminderDeliveryResult.delivered()
        : ReminderDeliveryResult.failed(
            _now().add(_reminderFailureRetryDelay).toUtc(),
          );
  }

  Future<void> notifyConflict(String summary) async {
    if (!_settings.notifyConflicts || _isQuietHours()) {
      return;
    }
    final body = _showsNotificationDetails
        ? _strings.conflictBody(redactForLog(summary))
        : _strings.conflictBody(_strings.detailsHidden);
    await _safeNotify(
      _strings.conflictTitle,
      body,
      BusyMaxNotificationCategory.conflict,
      stableId: 'conflict',
      payload: const {'notificationRoute': 'conflict'},
    );
  }

  Future<ReminderDeliveryResult> notifyDueToday(
    int count, {
    String? date,
  }) async {
    if (!_settings.notifyDueToday || count <= 0) {
      return const ReminderDeliveryResult.disabled();
    }
    final quietHoursEnd = _quietHoursEndUtc();
    if (quietHoursEnd != null) {
      return ReminderDeliveryResult.deferred(quietHoursEnd);
    }
    final delivered = await _safeNotify(
      _strings.dueTodayTitle,
      isPrivate ? _strings.detailsHidden : _strings.dueTodayBody(count),
      BusyMaxNotificationCategory.reminder,
      stableId: 'due-today',
      payload: {
        'notificationRoute': 'due-today',
        'date': date ?? notificationLocalDate(_now()),
      },
      private: isPrivate,
      transient: false,
    );
    return delivered
        ? const ReminderDeliveryResult.delivered()
        : ReminderDeliveryResult.failed(
            _now().add(_reminderFailureRetryDelay).toUtc(),
          );
  }

  Future<bool> cancelReminder(String deliveryId) =>
      _cancellations.cancel(deliveryId, () => _backend.cancel(deliveryId));

  Future<void> retryReminderCancellations() => _cancellations.retry();

  Future<void> reconcileReminderIdentities(Set<String> validIds) async {
    final backend = _backend;
    if (backend is! DesktopNotificationIdentitySource) return;
    for (final id
        in await (backend as DesktopNotificationIdentitySource)
            .knownReminderDeliveryIds()) {
      if (!validIds.contains(id)) await cancelReminder(id);
    }
  }

  Future<ReminderDeliveryResult> notifyEventReminder(
    String title,
    String? body, {
    String stableId = 'event-reminder',
    Map<String, String>? payload,
    Future<void> Function()? onActivated,
    ReminderNotificationActionHandler? onAction,
  }) async {
    if (!_settings.notifyEventReminders) {
      return const ReminderDeliveryResult.disabled();
    }
    final quietHoursEnd = _quietHoursEndUtc();
    if (quietHoursEnd != null) {
      return ReminderDeliveryResult.deferred(quietHoursEnd);
    }
    final private = _usesPrivateReminderText;
    final delivered = await _safeNotify(
      private ? _strings.eventReminderTitle : _displayText(title),
      private
          ? _strings.detailsHidden
          : _nonEmpty(_displayText(body ?? ''), _strings.eventReminderBody),
      BusyMaxNotificationCategory.reminder,
      stableId: stableId,
      payload: payload,
      private: private,
      onActivated: onActivated,
      onReminderAction: onAction,
      transient: false,
    );
    return delivered
        ? const ReminderDeliveryResult.delivered()
        : ReminderDeliveryResult.failed(
            _now().add(_reminderFailureRetryDelay).toUtc(),
          );
  }

  Future<ReminderDeliveryResult> notifyTaskReminder(
    String title,
    String? body, {
    String stableId = 'task-reminder',
    Map<String, String>? payload,
    Future<void> Function()? onActivated,
    ReminderNotificationActionHandler? onAction,
  }) async {
    if (!_settings.notifyTaskReminders) {
      return const ReminderDeliveryResult.disabled();
    }
    final quietHoursEnd = _quietHoursEndUtc();
    if (quietHoursEnd != null) {
      return ReminderDeliveryResult.deferred(quietHoursEnd);
    }
    final private = _usesPrivateReminderText;
    final delivered = await _safeNotify(
      private ? _strings.taskReminderTitle : _displayText(title),
      private
          ? _strings.detailsHidden
          : _nonEmpty(_displayText(body ?? ''), _strings.taskReminderBody),
      BusyMaxNotificationCategory.reminder,
      stableId: stableId,
      payload: payload,
      private: private,
      onActivated: onActivated,
      onReminderAction: onAction,
      transient: false,
    );
    return delivered
        ? const ReminderDeliveryResult.delivered()
        : ReminderDeliveryResult.failed(
            _now().add(_reminderFailureRetryDelay).toUtc(),
          );
  }

  bool get _showsNotificationDetails =>
      _settings.notificationDetailLevel == NotificationDetailLevel.normal;

  bool get _usesPrivateReminderText => !_showsNotificationDetails;

  Future<bool> _safeNotify(
    String summary,
    String body,
    BusyMaxNotificationCategory category, {
    required String stableId,
    Map<String, String>? payload,
    bool private = false,
    Future<void> Function()? onActivated,
    ReminderNotificationActionHandler? onReminderAction,
    bool transient = true,
  }) async {
    try {
      if (deliveryAllowed?.call() == false) return false;
      final activation = DesktopActivation(
        kind: DesktopActivationKind.notification,
        action: 'default',
        payload: payload,
      );
      final destination = activation.notificationDestination;
      if (activation.isValid && destination != null) {
        onActivated ??= onRoutedNotification != null
            ? () => onRoutedNotification!(payload!)
            : () async => _onDestinationActivated?.call(destination);
      }
      final hasActions = onActivated != null || onReminderAction != null;
      await _backend.notify(
        BusyMaxNotificationRequest(
          stableId: stableId,
          title: summary,
          body: body,
          category: category,
          payload: payload,
          transient: transient,
          private: private,
          actions: !hasActions
              ? const []
              : [
                  BusyMaxNotificationAction('default', _strings.openAction),
                  if (onReminderAction != null)
                    BusyMaxNotificationAction('snooze', _strings.snoozeAction),
                  if (onReminderAction != null)
                    BusyMaxNotificationAction(
                      'dismiss',
                      _strings.dismissAction,
                    ),
                ],
        ),
        onAction: !hasActions
            ? null
            : (action, _) async {
                switch (action) {
                  case 'default':
                  case 'open':
                    if (onReminderAction != null) {
                      await onReminderAction(ReminderNotificationAction.open);
                    } else {
                      await onActivated?.call();
                    }
                  case 'snooze':
                    await onReminderAction?.call(
                      ReminderNotificationAction.snooze,
                    );
                  case 'dismiss':
                    await onReminderAction?.call(
                      ReminderNotificationAction.dismiss,
                    );
                }
              },
      );
      onDeliveryStateChanged?.call(true);
      return true;
    } on Object {
      // A desktop notification backend may be unavailable in tests or a
      // headless session.
      onDeliveryStateChanged?.call(false);
      return false;
    }
  }

  bool _isQuietHours() {
    return _quietHoursEndUtc() != null;
  }

  DateTime? _quietHoursEndUtc() {
    if (!_settings.quietHoursEnabled) {
      return null;
    }
    final start = _minutesOfDay(_settings.quietHoursStart);
    final end = _minutesOfDay(_settings.quietHoursEnd);
    if (start == null || end == null || start == end) {
      return null;
    }
    final now = _now();
    final current = now.hour * 60 + now.minute;
    final quiet = start < end
        ? current >= start && current < end
        : current >= start || current < end;
    if (!quiet) {
      return null;
    }
    var endDate = DateTime(now.year, now.month, now.day, end ~/ 60, end % 60);
    if (start > end && current >= start) {
      endDate = DateTime(now.year, now.month, now.day + 1, end ~/ 60, end % 60);
    }
    return endDate.toUtc();
  }

  int? _minutesOfDay(String text) {
    final parts = text.split(':');
    if (parts.length != 2) {
      return null;
    }
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null ||
        minute == null ||
        hour < 0 ||
        hour > 23 ||
        minute < 0 ||
        minute > 59) {
      return null;
    }
    return hour * 60 + minute;
  }

  String _nonEmpty(String value, String fallback) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? fallback : trimmed;
  }

  // Display text is user content. Credential/error redaction belongs to logs
  // and provider diagnostics; the native backend owns platform escaping.
  String _displayText(String value) => value.replaceAll('\u0000', '').trim();
}

class NotificationStrings {
  const NotificationStrings({
    required this.syncFailureTitle,
    required this.conflictTitle,
    required this.dueTodayTitle,
    required this.eventReminderTitle,
    required this.taskReminderTitle,
    required this.detailsHidden,
    required this.reconnectRequired,
    required this.googleReconnectRequired,
    required this.permissionChanged,
    required this.unsupportedProvider,
    required this.temporarilyUnavailable,
    required this.eventReminderBody,
    required this.taskReminderBody,
    required this.openAction,
    required this.snoozeAction,
    required this.dismissAction,
    required this.blockedChanges,
    required this.syncFailureBody,
    required this.conflictBody,
    required this.dueTodayBody,
  });

  factory NotificationStrings.forLocale(Locale locale) {
    return NotificationStrings.forLocales([locale]);
  }

  factory NotificationStrings.forLocales(List<Locale>? locales) {
    final supportedLocale = resolveBusyMaxLocales(
      locales,
      busyMaxSupportedLocales,
    );
    return NotificationStrings.fromLocalizations(
      lookupAppLocalizations(supportedLocale),
    );
  }

  factory NotificationStrings.fromLocalizations(AppLocalizations l10n) {
    return NotificationStrings(
      syncFailureTitle: l10n.syncFailureNotificationTitle,
      conflictTitle: l10n.conflictNotificationTitle,
      dueTodayTitle:
          '${l10n.dueTodayNotificationTitle} · ${l10n.dailySummaryScope}',
      eventReminderTitle: l10n.eventReminderNotificationTitle,
      taskReminderTitle: l10n.taskReminderNotificationTitle,
      detailsHidden: l10n.notificationDetailsHidden,
      reconnectRequired: l10n.davReauthenticationRequired,
      googleReconnectRequired: l10n.googleReconnectRequired,
      permissionChanged: l10n.davPermissionChanged,
      unsupportedProvider: l10n.davUnsupportedServer,
      temporarilyUnavailable: l10n.davTemporarilyUnavailable,
      eventReminderBody: l10n.eventReminderNotificationBody,
      taskReminderBody: l10n.taskReminderNotificationBody,
      openAction: l10n.notificationOpenAction,
      snoozeAction: l10n.notificationSnoozeAction,
      dismissAction: l10n.notificationDismissAction,
      blockedChanges: l10n.blockedPendingOperations,
      syncFailureBody: l10n.syncFailureNotificationBody,
      conflictBody: l10n.conflictNotificationBody,
      dueTodayBody: l10n.dueTodayNotificationBody,
    );
  }

  final String syncFailureTitle;
  final String conflictTitle;
  final String dueTodayTitle;
  final String eventReminderTitle;
  final String taskReminderTitle;
  final String detailsHidden;
  final String reconnectRequired;
  final String googleReconnectRequired;
  final String permissionChanged;
  final String unsupportedProvider;
  final String temporarilyUnavailable;
  final String eventReminderBody;
  final String taskReminderBody;
  final String openAction;
  final String snoozeAction;
  final String dismissAction;
  final String blockedChanges;
  final String Function(String message) syncFailureBody;
  final String Function(String summary) conflictBody;
  final String Function(int count) dueTodayBody;
}

import 'dart:async';
import 'dart:ui';

import 'package:desktop_notifications/desktop_notifications.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../app/app_settings.dart';
import '../../core/logging/redacting_logger.dart';
import '../../l10n/locale_resolution.dart';
import '../sync/sync_failure_notification_policy.dart';

typedef DesktopNotificationActionHandler = Future<void> Function(String action);

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

typedef ReminderNotificationActionHandler =
    Future<void> Function(ReminderNotificationAction action);

abstract class DesktopNotificationBackend {
  Future<void> notify(
    String summary, {
    String body = '',
    List<NotificationHint> hints = const [],
    List<NotificationAction> actions = const [],
    DesktopNotificationActionHandler? onAction,
  });

  Future<void> close();
}

class FreedesktopNotificationBackend implements DesktopNotificationBackend {
  FreedesktopNotificationBackend({NotificationsClient? client})
    : _client = client ?? NotificationsClient();

  final NotificationsClient _client;

  @override
  Future<void> notify(
    String summary, {
    String body = '',
    List<NotificationHint> hints = const [],
    List<NotificationAction> actions = const [],
    DesktopNotificationActionHandler? onAction,
  }) async {
    final notification = await _client.notify(
      summary,
      appName: 'BusyMax',
      appIcon: 'io.busystack.busymax',
      body: body,
      hints: hints,
      actions: actions,
    );
    if (onAction != null) {
      unawaited(
        notification.action
            .then(onAction)
            .catchError((Object _) => Future<void>.value()),
      );
    }
  }

  @override
  Future<void> close() => _client.close();
}

class DesktopNotificationService {
  DesktopNotificationService({
    required DesktopNotificationBackend backend,
    required AppSettings settings,
    Locale? locale,
    Duration syncFailureDebounce = const Duration(minutes: 5),
    Duration reminderFailureRetryDelay = const Duration(minutes: 1),
    DateTime Function()? now,
  }) : _backend = backend,
       _settings = settings,
       _strings = locale == null
           ? NotificationStrings.forLocales(PlatformDispatcher.instance.locales)
           : NotificationStrings.forLocale(locale),
       _syncFailureDebounce = syncFailureDebounce,
       _reminderFailureRetryDelay = reminderFailureRetryDelay,
       _now = now ?? DateTime.now;

  final DesktopNotificationBackend _backend;
  final AppSettings _settings;
  final NotificationStrings _strings;
  final Duration _syncFailureDebounce;
  final Duration _reminderFailureRetryDelay;
  final DateTime Function() _now;

  DateTime? _lastSyncFailureAt;
  String? _lastSyncFailureBody;

  Future<void> notifySyncFailure(Object error) async {
    final disposition = syncFailureNotificationDisposition(error);
    final message = switch (disposition) {
      SyncFailureNotificationDisposition.suppressed => null,
      SyncFailureNotificationDisposition.reconnectRequired =>
        _strings.reconnectRequired,
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
    final body = _showsNotificationDetails
        ? _strings.syncFailureBody(message)
        : _strings.syncFailureBody(_strings.detailsHidden);
    final now = _now();
    if (_lastSyncFailureBody == body &&
        _lastSyncFailureAt != null &&
        now.difference(_lastSyncFailureAt!) < _syncFailureDebounce) {
      return;
    }
    _lastSyncFailureBody = body;
    _lastSyncFailureAt = now;
    await _safeNotify(
      _strings.syncFailureTitle,
      body,
      NotificationCategory.networkError(),
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
      NotificationCategory.deviceError(),
    );
  }

  Future<void> notifyDueToday(int count) async {
    if (!_settings.notifyDueToday || count <= 0 || _isQuietHours()) {
      return;
    }
    await _safeNotify(
      _strings.dueTodayTitle,
      _strings.dueTodayBody(count),
      NotificationCategory.device(),
    );
  }

  Future<ReminderDeliveryResult> notifyEventReminder(
    String title,
    String? body, {
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
      private ? _strings.eventReminderTitle : redactForLog(title),
      private
          ? _strings.detailsHidden
          : _nonEmpty(redactForLog(body ?? ''), _strings.eventReminderBody),
      NotificationCategory.device(),
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
      private ? _strings.taskReminderTitle : redactForLog(title),
      private
          ? _strings.detailsHidden
          : _nonEmpty(redactForLog(body ?? ''), _strings.taskReminderBody),
      NotificationCategory.device(),
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
    NotificationCategory category, {
    Future<void> Function()? onActivated,
    ReminderNotificationActionHandler? onReminderAction,
    bool transient = true,
  }) async {
    try {
      final hasActions = onActivated != null || onReminderAction != null;
      await _backend.notify(
        summary,
        body: body,
        actions: !hasActions
            ? const []
            : [
                NotificationAction('default', _strings.openAction),
                if (onReminderAction != null)
                  NotificationAction('snooze', _strings.snoozeAction),
                if (onReminderAction != null)
                  NotificationAction('dismiss', _strings.dismissAction),
              ],
        onAction: !hasActions
            ? null
            : (action) async {
                switch (action) {
                  case 'default':
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
        hints: [
          NotificationHint.category(category),
          if (transient) NotificationHint.transient(),
        ],
      );
      return true;
    } on Object {
      // DBus notifications may be unavailable in tests or headless sessions.
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
      endDate = DateTime(
        now.year,
        now.month,
        now.day + 1,
        end ~/ 60,
        end % 60,
      );
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
    required this.permissionChanged,
    required this.unsupportedProvider,
    required this.temporarilyUnavailable,
    required this.eventReminderBody,
    required this.taskReminderBody,
    required this.openAction,
    required this.snoozeAction,
    required this.dismissAction,
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
      AppLocalizations.supportedLocales,
    );
    return NotificationStrings.fromLocalizations(
      lookupAppLocalizations(supportedLocale),
    );
  }

  factory NotificationStrings.fromLocalizations(AppLocalizations l10n) {
    return NotificationStrings(
      syncFailureTitle: l10n.syncFailureNotificationTitle,
      conflictTitle: l10n.conflictNotificationTitle,
      dueTodayTitle: l10n.dueTodayNotificationTitle,
      eventReminderTitle: l10n.eventReminderNotificationTitle,
      taskReminderTitle: l10n.taskReminderNotificationTitle,
      detailsHidden: l10n.notificationDetailsHidden,
      reconnectRequired: l10n.davReauthenticationRequired,
      permissionChanged: l10n.davPermissionChanged,
      unsupportedProvider: l10n.davUnsupportedServer,
      temporarilyUnavailable: l10n.davTemporarilyUnavailable,
      eventReminderBody: l10n.eventReminderNotificationBody,
      taskReminderBody: l10n.taskReminderNotificationBody,
      openAction: l10n.notificationOpenAction,
      snoozeAction: l10n.notificationSnoozeAction,
      dismissAction: l10n.notificationDismissAction,
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
  final String permissionChanged;
  final String unsupportedProvider;
  final String temporarilyUnavailable;
  final String eventReminderBody;
  final String taskReminderBody;
  final String openAction;
  final String snoozeAction;
  final String dismissAction;
  final String Function(String message) syncFailureBody;
  final String Function(String summary) conflictBody;
  final String Function(int count) dueTodayBody;
}

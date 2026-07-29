import 'dart:async';
import 'dart:ui';

import 'package:desktop_notifications/desktop_notifications.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../app/app_settings.dart';
import '../../core/logging/redacting_logger.dart';
import '../../l10n/locale_resolution.dart';

typedef DesktopNotificationActionHandler = Future<void> Function(String action);

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
    DateTime Function()? now,
  }) : _backend = backend,
       _settings = settings,
       _strings = NotificationStrings.forLocale(
         locale ?? PlatformDispatcher.instance.locale,
       ),
       _syncFailureDebounce = syncFailureDebounce,
       _now = now ?? DateTime.now;

  final DesktopNotificationBackend _backend;
  final AppSettings _settings;
  final NotificationStrings _strings;
  final Duration _syncFailureDebounce;
  final DateTime Function() _now;

  DateTime? _lastSyncFailureAt;
  String? _lastSyncFailureBody;

  Future<void> notifySyncFailure(String message) async {
    if (!_settings.notifySyncFailures || _isQuietHours()) {
      return;
    }

    final body = _showsNotificationDetails
        ? _strings.syncFailureBody(redactForLog(message))
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

  Future<void> notifyEventReminder(
    String title,
    String? body, {
    Future<void> Function()? onActivated,
  }) async {
    if (!_settings.notifyEventReminders || _isQuietHours()) {
      return;
    }
    final private = _usesPrivateReminderText;
    await _safeNotify(
      private ? _strings.eventReminderTitle : redactForLog(title),
      private
          ? _strings.detailsHidden
          : _nonEmpty(redactForLog(body ?? ''), _strings.eventReminderBody),
      NotificationCategory.device(),
      onActivated: onActivated,
      transient: false,
    );
  }

  Future<void> notifyTaskReminder(
    String title,
    String? body, {
    Future<void> Function()? onActivated,
  }) async {
    if (!_settings.notifyTaskReminders || _isQuietHours()) {
      return;
    }
    final private = _usesPrivateReminderText;
    await _safeNotify(
      private ? _strings.taskReminderTitle : redactForLog(title),
      private
          ? _strings.detailsHidden
          : _nonEmpty(redactForLog(body ?? ''), _strings.taskReminderBody),
      NotificationCategory.device(),
      onActivated: onActivated,
      transient: false,
    );
  }

  bool get _showsNotificationDetails =>
      _settings.notificationDetailLevel == NotificationDetailLevel.normal;

  bool get _usesPrivateReminderText => !_showsNotificationDetails;

  Future<void> _safeNotify(
    String summary,
    String body,
    NotificationCategory category, {
    Future<void> Function()? onActivated,
    bool transient = true,
  }) async {
    try {
      await _backend.notify(
        summary,
        body: body,
        actions: onActivated == null
            ? const []
            : [NotificationAction('default', _strings.openAction)],
        onAction: onActivated == null
            ? null
            : (action) async {
                if (action == 'default') {
                  await onActivated();
                }
              },
        hints: [
          NotificationHint.category(category),
          if (transient) NotificationHint.transient(),
        ],
      );
    } on Object {
      // DBus notifications may be unavailable in tests or headless sessions.
    }
  }

  bool _isQuietHours() {
    if (!_settings.quietHoursEnabled) {
      return false;
    }
    final start = _minutesOfDay(_settings.quietHoursStart);
    final end = _minutesOfDay(_settings.quietHoursEnd);
    if (start == null || end == null || start == end) {
      return false;
    }
    final now = _now();
    final current = now.hour * 60 + now.minute;
    if (start < end) {
      return current >= start && current < end;
    }
    return current >= start || current < end;
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
    required this.eventReminderBody,
    required this.taskReminderBody,
    required this.openAction,
    required this.syncFailureBody,
    required this.conflictBody,
    required this.dueTodayBody,
  });

  factory NotificationStrings.forLocale(Locale locale) {
    final supportedLocale = resolveBusyMaxLocale(
      locale,
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
      eventReminderBody: l10n.eventReminderNotificationBody,
      taskReminderBody: l10n.taskReminderNotificationBody,
      openAction: l10n.notificationOpenAction,
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
  final String eventReminderBody;
  final String taskReminderBody;
  final String openAction;
  final String Function(String message) syncFailureBody;
  final String Function(String summary) conflictBody;
  final String Function(int count) dueTodayBody;
}

import 'dart:async';
import 'dart:ui';

import 'package:desktop_notifications/desktop_notifications.dart';

import '../../app/app_settings.dart';
import '../../core/logging/redacting_logger.dart';

abstract class DesktopNotificationBackend {
  Future<void> notify(
    String summary, {
    String body = '',
    List<NotificationHint> hints = const [],
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
  }) {
    return _client.notify(
      summary,
      appName: 'BusyMax',
      appIcon: 'io.busystack.busymax',
      body: body,
      hints: hints,
    );
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

    final body = _settings.detailedNotifications
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
    final body = _settings.detailedNotifications
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

  Future<void> notifyEventReminder(String title, String? body) async {
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
    );
  }

  Future<void> notifyTaskReminder(String title, String? body) async {
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
    );
  }

  bool get _usesPrivateReminderText {
    return !_settings.detailedNotifications &&
        _settings.notificationDetailLevel == NotificationDetailLevel.private;
  }

  Future<void> _safeNotify(
    String summary,
    String body,
    NotificationCategory category,
  ) async {
    try {
      await _backend.notify(
        summary,
        body: body,
        hints: [
          NotificationHint.category(category),
          NotificationHint.transient(),
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
    required this.syncFailureBody,
    required this.conflictBody,
    required this.dueTodayBody,
  });

  factory NotificationStrings.forLocale(Locale locale) {
    return switch (locale.languageCode) {
      'de' => NotificationStrings.german,
      'fr' => NotificationStrings.french,
      'es' => NotificationStrings.spanish,
      _ => NotificationStrings.english,
    };
  }

  static final english = NotificationStrings(
    syncFailureTitle: 'BusyMax sync failed',
    conflictTitle: 'BusyMax sync conflict',
    dueTodayTitle: 'Tasks due today',
    eventReminderTitle: 'Event reminder',
    taskReminderTitle: 'Task reminder',
    detailsHidden: 'Details are hidden by privacy settings.',
    eventReminderBody: 'Event starts soon.',
    taskReminderBody: 'Task is due soon.',
    syncFailureBody: (message) => 'Background sync failed. $message',
    conflictBody: (summary) => 'A pending local change was blocked. $summary',
    dueTodayBody: (count) =>
        count == 1 ? 'One task is due today.' : '$count tasks are due today.',
  );

  static final german = NotificationStrings(
    syncFailureTitle: 'BusyMax-Synchronisierung fehlgeschlagen',
    conflictTitle: 'BusyMax-Synchronisierungskonflikt',
    dueTodayTitle: 'Heute fällige Aufgaben',
    eventReminderTitle: 'Terminerinnerung',
    taskReminderTitle: 'Aufgabenerinnerung',
    detailsHidden:
        'Details werden durch Datenschutzeinstellungen ausgeblendet.',
    eventReminderBody: 'Der Termin beginnt bald.',
    taskReminderBody: 'Die Aufgabe ist bald fällig.',
    syncFailureBody: (message) =>
        'Hintergrundsynchronisierung fehlgeschlagen. $message',
    conflictBody: (summary) =>
        'Eine ausstehende lokale Änderung wurde blockiert. $summary',
    dueTodayBody: (count) => count == 1
        ? 'Eine Aufgabe ist heute fällig.'
        : '$count Aufgaben sind heute fällig.',
  );

  static final french = NotificationStrings(
    syncFailureTitle: 'Échec de la synchronisation BusyMax',
    conflictTitle: 'Conflit de synchronisation BusyMax',
    dueTodayTitle: 'Tâches dues aujourd’hui',
    eventReminderTitle: 'Rappel d’événement',
    taskReminderTitle: 'Rappel de tâche',
    detailsHidden:
        'Les détails sont masqués par les paramètres de confidentialité.',
    eventReminderBody: 'L’événement commence bientôt.',
    taskReminderBody: 'La tâche arrive bientôt à échéance.',
    syncFailureBody: (message) =>
        'La synchronisation en arrière-plan a échoué. $message',
    conflictBody: (summary) =>
        'Une modification locale en attente a été bloquée. $summary',
    dueTodayBody: (count) => count == 1
        ? 'Une tâche est due aujourd’hui.'
        : '$count tâches sont dues aujourd’hui.',
  );

  static final spanish = NotificationStrings(
    syncFailureTitle: 'Falló la sincronización de BusyMax',
    conflictTitle: 'Conflicto de sincronización de BusyMax',
    dueTodayTitle: 'Tareas que vencen hoy',
    eventReminderTitle: 'Recordatorio de evento',
    taskReminderTitle: 'Recordatorio de tarea',
    detailsHidden:
        'Los detalles están ocultos por la configuración de privacidad.',
    eventReminderBody: 'El evento empieza pronto.',
    taskReminderBody: 'La tarea vence pronto.',
    syncFailureBody: (message) =>
        'Falló la sincronización en segundo plano. $message',
    conflictBody: (summary) => 'Se bloqueó un cambio local pendiente. $summary',
    dueTodayBody: (count) =>
        count == 1 ? 'Una tarea vence hoy.' : '$count tareas vencen hoy.',
  );

  final String syncFailureTitle;
  final String conflictTitle;
  final String dueTodayTitle;
  final String eventReminderTitle;
  final String taskReminderTitle;
  final String detailsHidden;
  final String eventReminderBody;
  final String taskReminderBody;
  final String Function(String message) syncFailureBody;
  final String Function(String summary) conflictBody;
  final String Function(int count) dueTodayBody;
}

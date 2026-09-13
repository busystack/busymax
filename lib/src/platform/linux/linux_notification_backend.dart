import 'dart:async';

import 'package:desktop_notifications/desktop_notifications.dart';

import '../../features/notifications/desktop_notification_backend.dart';

final class FreedesktopNotificationBackend
    implements DesktopNotificationBackend {
  FreedesktopNotificationBackend({NotificationsClient? client})
    : _client = client ?? NotificationsClient();

  final NotificationsClient _client;
  final Map<String, Notification> _notifications = {};
  List<String>? _capabilities;

  @override
  Future<void> notify(
    BusyMaxNotificationRequest request, {
    DesktopNotificationActionHandler? onAction,
  }) async {
    final capabilities = _capabilities ??= await _client.getCapabilities();
    final previous = _notifications[request.stableId];
    final notification = await _client.notify(
      request.title,
      appName: 'BusyMax',
      appIcon: 'io.busystack.busymax',
      body: capabilities.contains('body-markup')
          ? _escapeMarkup(request.body)
          : request.body,
      replacesId: previous?.id ?? 0,
      hints: [
        NotificationHint.category(_category(request.category)),
        if (request.transient) NotificationHint.transient(),
      ],
      actions: [
        for (final action in request.actions)
          NotificationAction(action.id, action.label),
      ],
    );
    _notifications[request.stableId] = notification;
    unawaited(
      notification.closeReason
          .then((_) {
            _forgetIfCurrent(request.stableId, notification);
          })
          .catchError((Object _) {}),
    );
    if (onAction != null) {
      unawaited(
        notification.action
            .then((action) => onAction(action, request.payload))
            .catchError((Object _) => Future<void>.value()),
      );
    }
  }

  NotificationCategory _category(BusyMaxNotificationCategory category) {
    return switch (category) {
      BusyMaxNotificationCategory.networkError =>
        NotificationCategory.networkError(),
      BusyMaxNotificationCategory.conflict =>
        NotificationCategory.deviceError(),
      _ => NotificationCategory.device(),
    };
  }

  @override
  Future<void> cancel(String stableId) async {
    final notification = _notifications[stableId];
    if (notification == null) return;
    await notification.close();
    _forgetIfCurrent(stableId, notification);
  }

  void _forgetIfCurrent(String stableId, Notification notification) {
    if (identical(_notifications[stableId], notification)) {
      _notifications.remove(stableId);
    }
  }

  String _escapeMarkup(String text) => text
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;');

  @override
  Future<void> close() => _client.close();
}

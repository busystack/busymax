import 'dart:async';

import 'package:desktop_notifications/desktop_notifications.dart';

import '../../features/notifications/desktop_notification_backend.dart';

final class FreedesktopNotificationBackend
    implements DesktopNotificationBackend {
  FreedesktopNotificationBackend({NotificationsClient? client})
    : _client = client ?? NotificationsClient();

  final NotificationsClient _client;
  final Map<String, Notification> _notifications = {};

  @override
  Future<void> notify(
    BusyMaxNotificationRequest request, {
    DesktopNotificationActionHandler? onAction,
  }) async {
    final previous = _notifications[request.stableId];
    final notification = await _client.notify(
      request.title,
      appName: 'BusyMax',
      appIcon: 'io.busystack.busymax',
      body: request.body,
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
    final notification = _notifications.remove(stableId);
    await notification?.close();
  }

  @override
  Future<void> close() => _client.close();
}

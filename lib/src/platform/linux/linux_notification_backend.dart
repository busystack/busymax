import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:desktop_notifications/desktop_notifications.dart';
import 'package:dbus/dbus.dart';
import 'package:path_provider/path_provider.dart';

import '../../features/notifications/desktop_notification_backend.dart';

final class FreedesktopNotificationBackend
    implements DesktopNotificationBackend, DesktopNotificationIdentitySource {
  FreedesktopNotificationBackend({
    NotificationsClient? client,
    DBusClient? bus,
    File? identityFile,
    Future<String> Function()? serverIdentity,
  }) : _providedClient = client,
       _bus = client == null ? bus ?? DBusClient.session() : null,
       _persistent = client == null || identityFile != null,
       _identityFile = identityFile,
       _serverIdentity = serverIdentity;

  final NotificationsClient? _providedClient;
  final DBusClient? _bus;
  late final NotificationsClient _client =
      _providedClient ?? NotificationsClient(bus: _bus!);
  final Map<String, Notification> _notifications = {};
  List<String>? _capabilities;
  final bool _persistent;
  File? _identityFile;
  final Future<String> Function()? _serverIdentity;
  String? _session;
  final _nativeIds = <String, int>{};
  Future<void> _writes = Future<void>.value();

  Future<void> probe() async {
    _capabilities = await _client.getCapabilities();
    await _restoreIdentities();
  }

  @override
  Future<Set<String>> knownReminderDeliveryIds() async {
    await _restoreIdentities();
    return _nativeIds.keys
        .where((id) => id.startsWith('event|') || id.startsWith('task|'))
        .toSet();
  }

  Future<void> _restoreIdentities() async {
    if (!_persistent) return;
    String session;
    if (_serverIdentity != null) {
      session = await _serverIdentity();
    } else {
      final bus = _bus ?? DBusClient.session();
      try {
        final owner = await bus.getNameOwner('org.freedesktop.Notifications');
        if (owner == null) throw StateError('Notification server unavailable.');
        session = '${await bus.getId()}|$owner';
      } finally {
        if (_bus == null) await bus.close();
      }
    }
    if (_session == session) return;
    // Capabilities belong to the verified server owner, just like numeric IDs.
    if (_session != null) _capabilities = null;
    _nativeIds.clear();
    _notifications.clear();
    _identityFile ??= File(
      '${(await getApplicationSupportDirectory()).path}/linux_notification_ids.json',
    );
    if (await _identityFile!.exists()) {
      final json = jsonDecode(
        await _identityFile!.readAsString(),
      ) as Map<String, dynamic>;
      if (json['session'] == session) {
        final ids = (json['ids'] as Map).cast<String, int>();
        if (ids.values.any((id) => id <= 0 || id > 0xffffffff)) {
          throw const FormatException('Invalid notification identity.');
        }
        _nativeIds.addAll(ids);
      }
    }
    _session = session;
  }

  Future<void> _persistIdentities() {
    if (!_persistent) return Future<void>.value();
    final operation = _writes.catchError((Object _) {}).then((_) async {
      final file = _identityFile!;
      await file.parent.create(recursive: true);
      final temporary = File('${file.path}.tmp');
      await temporary.writeAsString(
        jsonEncode({'session': _session, 'ids': _nativeIds}),
        flush: true,
      );
      await temporary.rename(file.path);
    });
    _writes = operation;
    return operation;
  }

  @override
  Future<void> notify(
    BusyMaxNotificationRequest request, {
    DesktopNotificationActionHandler? onAction,
  }) async {
    await _restoreIdentities();
    final capabilities = _capabilities ??= await _client.getCapabilities();
    final previous = _notifications[request.stableId];
    final notification = await _client.notify(
      request.title,
      appName: 'BusyMax',
      appIcon: 'io.busystack.busymax',
      body: capabilities.contains('body-markup')
          ? _escapeMarkup(request.body)
          : request.body,
      replacesId: previous?.id ?? _nativeIds[request.stableId] ?? 0,
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
    _nativeIds[request.stableId] = notification.id;
    await _persistIdentities();
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
    await _restoreIdentities();
    final nativeId = _nativeIds[stableId];
    final notification =
        _notifications[stableId] ??
        (nativeId == null ? null : Notification(_client, nativeId));
    if (notification == null) return;
    if (_bus != null && _serverIdentity == null) {
      // Address the verified unique owner. If the server restarts between the
      // identity check and CloseNotification, its replacement must not receive
      // an old numeric ID that may now belong to another application.
      final object = DBusRemoteObject(
        _bus,
        name: _session!.split('|').last,
        path: DBusObjectPath('/org/freedesktop/Notifications'),
      );
      await object.callMethod(
        'org.freedesktop.Notifications',
        'CloseNotification',
        [DBusUint32(notification.id)],
        replySignature: DBusSignature(''),
      );
    } else {
      await notification.close();
    }
    _forgetIfCurrent(stableId, notification);
    _nativeIds.remove(stableId);
    await _persistIdentities();
  }

  void _forgetIfCurrent(String stableId, Notification notification) {
    if (identical(_notifications[stableId], notification)) {
      _notifications.remove(stableId);
      _nativeIds.remove(stableId);
      unawaited(_persistIdentities().catchError((Object _) {}));
    }
  }

  String _escapeMarkup(String text) => text
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;');

  @override
  Future<void> close() async {
    await _client.close();
    await _bus?.close();
  }
}

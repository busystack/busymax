import 'dart:convert';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../features/notifications/desktop_notification_backend.dart';
import '../common/desktop_services.dart';

const busyMaxToastActivatorClsid = '7B854A6D-8B2A-45A5-B998-1F51EC5A81D7';
const busyMaxNotificationActivationServerArgument =
    '----AppNotificationActivationServer';
const busyMaxNotificationForwarderArgument = '--busymax-notification-forwarder';

final class WindowsNotificationBackend implements DesktopNotificationBackend {
  WindowsNotificationBackend._({
    required FlutterLocalNotificationsPlugin plugin,
    required void Function(DesktopActivation activation) onActivation,
  }) : _plugin = plugin,
       _onActivation = onActivation;

  static Future<WindowsNotificationBackend> create({
    required String appUserModelId,
    required void Function(DesktopActivation activation) onActivation,
    FlutterLocalNotificationsPlugin? plugin,
  }) async {
    if (appUserModelId.trim().isEmpty) {
      throw ArgumentError.value(
        appUserModelId,
        'appUserModelId',
        'A stable AUMID is required for Windows notifications.',
      );
    }
    final notifications = plugin ?? FlutterLocalNotificationsPlugin();
    late final WindowsNotificationBackend backend;
    backend = WindowsNotificationBackend._(
      plugin: notifications,
      onActivation: onActivation,
    );
    await notifications.initialize(
      settings: InitializationSettings(
        windows: WindowsInitializationSettings(
          appName: 'BusyMax',
          appUserModelId: appUserModelId,
          guid: busyMaxToastActivatorClsid,
        ),
      ),
      onDidReceiveNotificationResponse: backend._handleResponse,
    );
    final launch = await notifications.getNotificationAppLaunchDetails();
    if (launch?.didNotificationLaunchApp ?? false) {
      backend._handleResponse(launch!.notificationResponse!);
    }
    return backend;
  }

  final FlutterLocalNotificationsPlugin _plugin;
  final void Function(DesktopActivation activation) _onActivation;

  @override
  Future<void> notify(
    BusyMaxNotificationRequest request, {
    DesktopNotificationActionHandler? onAction,
  }) async {
    const permittedPayloadKeys = {
      'notificationScheduleId',
      'itemKind',
      'accountId',
      'sourceId',
      'itemId',
    };
    final requestPayload = request.payload ?? const <String, String>{};
    if (request.stableId.isEmpty ||
        request.stableId.length > 2048 ||
        request.actions.any(
          (action) => !const {
            'default',
            'open',
            'snooze',
            'dismiss',
          }.contains(action.id),
        ) ||
        requestPayload.entries.any(
          (entry) =>
              !permittedPayloadKeys.contains(entry.key) ||
              entry.value.isEmpty ||
              entry.value.length > 2048,
        )) {
      throw ArgumentError(
        'Windows notification activation data must contain only bounded '
        'BusyMax identifiers.',
      );
    }
    final payload = <String, Object?>{
      'version': 1,
      ...requestPayload,
      'stableId': request.stableId,
    };
    await _plugin.show(
      id: _notificationId(request.stableId),
      title: request.title,
      body: request.body,
      payload: jsonEncode(payload),
      notificationDetails: NotificationDetails(
        windows: WindowsNotificationDetails(
          actions: request.actions
              .map(
                (action) => WindowsAction(
                  content: action.label,
                  // Windows supplies the selected action's arguments instead
                  // of the toast's root launch value. Include the opaque
                  // identifiers in every action so warm and cold activation
                  // use the same idempotent route.
                  arguments: jsonEncode({...payload, 'action': action.id}),
                ),
              )
              .toList(growable: false),
        ),
      ),
    );
  }

  void _handleResponse(NotificationResponse response) {
    final parsed = _decodePayload(response.payload);
    if (parsed == null) return;
    final stableId = parsed.remove('stableId');
    if (stableId == null || stableId != parsed['notificationScheduleId']) {
      return;
    }
    final encodedAction = parsed.remove('action');
    final action =
        response.notificationResponseType ==
            NotificationResponseType.notificationDismissed
        ? 'dismiss'
        : encodedAction ?? 'default';
    final activation = DesktopActivation(
      kind: DesktopActivationKind.notification,
      action: action,
      payload: parsed,
    );
    if (!activation.isValid) return;
    // Warm and cold responses deliberately use the same idempotent activation
    // router. Calling an in-memory closure here as well would process snooze or
    // dismiss twice in the warm-process case.
    _onActivation(activation);
  }

  Map<String, String>? _decodePayload(String? encoded) {
    if (encoded == null ||
        encoded.length > DesktopActivation.maximumEncodedBytes) {
      return null;
    }
    try {
      final decoded = jsonDecode(encoded);
      if (decoded is! Map || decoded['version'] != 1) return null;
      final values = <String, String>{};
      for (final entry in decoded.entries) {
        if (entry.key == 'version') continue;
        if (entry.key is! String || entry.value is! String) return null;
        values[entry.key as String] = entry.value as String;
      }
      return values;
    } on FormatException {
      return null;
    }
  }

  @override
  Future<void> cancel(String stableId) async {
    await _plugin.cancel(id: _notificationId(stableId));
  }

  @override
  Future<void> close() async {
    _plugin
        .resolvePlatformSpecificImplementation<
          FlutterLocalNotificationsWindows
        >()
        ?.dispose();
  }
}

int _notificationId(String stableId) {
  var hash = 0x811c9dc5;
  for (final byte in utf8.encode(stableId)) {
    hash = ((hash ^ byte) * 0x01000193) & 0x7fffffff;
  }
  return hash;
}

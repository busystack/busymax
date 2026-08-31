import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../features/notifications/desktop_notification_backend.dart';
import '../common/desktop_services.dart';
import 'windows_notification_id_store.dart';
import 'windows_window_service.dart';

const busyMaxToastActivatorClsid = '7B854A6D-8B2A-45A5-B998-1F51EC5A81D7';
const busyMaxNotificationActivationServerArgument =
    '----AppNotificationActivationServer';
const busyMaxNotificationForwarderArgument = '--busymax-notification-forwarder';

final class WindowsNotificationBackend implements DesktopNotificationBackend {
  WindowsNotificationBackend._({
    required WindowsNotificationPluginAdapter plugin,
    required void Function(DesktopActivation activation) onActivation,
    required WindowsNotificationIdStore? idStore,
  }) : _plugin = plugin,
       _onActivation = onActivation,
       _idStore = idStore;

  static Future<bool> hasPackageIdentity({
    MethodChannel channel = const MethodChannel(windowsDesktopChannelName),
  }) async {
    try {
      return await channel.invokeMethod<bool>('hasPackageIdentity') ?? false;
    } on MissingPluginException {
      return false;
    }
  }

  static Future<WindowsNotificationBackend> create({
    required String appUserModelId,
    required void Function(DesktopActivation activation) onActivation,
    WindowsNotificationPluginAdapter? plugin,
    WindowsNotificationIdStore? idStore,
    bool activationForwarderOnly = false,
  }) async {
    if (appUserModelId.trim().isEmpty) {
      throw ArgumentError.value(
        appUserModelId,
        'appUserModelId',
        'A stable AUMID is required for Windows notifications.',
      );
    }
    WindowsNotificationIdStore? notificationIds;
    if (!activationForwarderOnly) {
      notificationIds =
          idStore ?? await WindowsNotificationIdStore.openDefault();
      await notificationIds.initialize();
    }
    final notifications =
        plugin ??
        FlutterWindowsNotificationPluginAdapter(
          FlutterLocalNotificationsPlugin(),
        );
    late final WindowsNotificationBackend backend;
    backend = WindowsNotificationBackend._(
      plugin: notifications,
      onActivation: onActivation,
      idStore: notificationIds,
    );
    try {
      final initialized = await notifications.initialize(
        settings: InitializationSettings(
          windows: WindowsInitializationSettings(
            appName: 'BusyMax',
            appUserModelId: appUserModelId,
            guid: busyMaxToastActivatorClsid,
          ),
        ),
        onDidReceiveNotificationResponse: backend._handleResponse,
      );
      if (initialized != true) {
        throw const WindowsNotificationInitializationException(
          'toast-registration-failed',
        );
      }
      final launch = await notifications.getNotificationAppLaunchDetails();
      if (launch?.didNotificationLaunchApp ?? false) {
        final response = launch?.notificationResponse;
        if (response == null) {
          throw const WindowsNotificationInitializationException(
            'cold-activation-invalid',
          );
        }
        backend._handleResponse(response);
      }
    } on WindowsNotificationInitializationException {
      rethrow;
    } on Object {
      throw const WindowsNotificationInitializationException(
        'initialization-failed',
      );
    }
    return backend;
  }

  final WindowsNotificationPluginAdapter _plugin;
  final void Function(DesktopActivation activation) _onActivation;
  final WindowsNotificationIdStore? _idStore;

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
    final idStore = _idStore;
    if (idStore == null) {
      throw StateError(
        'The notification activation forwarder cannot display notifications.',
      );
    }
    final notificationId = await idStore.idFor(request.stableId);
    await _plugin.show(
      id: notificationId,
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
    final idStore = _idStore;
    if (idStore == null) {
      throw StateError(
        'The notification activation forwarder cannot cancel notifications.',
      );
    }
    await _plugin.cancel(id: await idStore.idFor(stableId));
  }

  @override
  Future<void> close() async {
    await _plugin.dispose();
  }
}

abstract interface class WindowsNotificationPluginAdapter {
  Future<bool?> initialize({
    required InitializationSettings settings,
    DidReceiveNotificationResponseCallback? onDidReceiveNotificationResponse,
  });

  Future<NotificationAppLaunchDetails?> getNotificationAppLaunchDetails();

  Future<void> show({
    required int id,
    String? title,
    String? body,
    NotificationDetails? notificationDetails,
    String? payload,
  });

  Future<void> cancel({required int id});

  Future<void> dispose();
}

final class FlutterWindowsNotificationPluginAdapter
    implements WindowsNotificationPluginAdapter {
  FlutterWindowsNotificationPluginAdapter(this.plugin);

  final FlutterLocalNotificationsPlugin plugin;

  @override
  Future<bool?> initialize({
    required InitializationSettings settings,
    DidReceiveNotificationResponseCallback? onDidReceiveNotificationResponse,
  }) => plugin.initialize(
    settings: settings,
    onDidReceiveNotificationResponse: onDidReceiveNotificationResponse,
  );

  @override
  Future<NotificationAppLaunchDetails?> getNotificationAppLaunchDetails() =>
      plugin.getNotificationAppLaunchDetails();

  @override
  Future<void> show({
    required int id,
    String? title,
    String? body,
    NotificationDetails? notificationDetails,
    String? payload,
  }) => plugin.show(
    id: id,
    title: title,
    body: body,
    notificationDetails: notificationDetails,
    payload: payload,
  );

  @override
  Future<void> cancel({required int id}) => plugin.cancel(id: id);

  @override
  Future<void> dispose() async {
    plugin
        .resolvePlatformSpecificImplementation<
          FlutterLocalNotificationsWindows
        >()
        ?.dispose();
  }
}

final class WindowsNotificationInitializationException implements Exception {
  const WindowsNotificationInitializationException(this.code);

  final String code;
}

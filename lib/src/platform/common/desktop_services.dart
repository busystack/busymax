import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:flutter/foundation.dart';

const busyMaxStartMinimizedArgument = '--start-minimized';

abstract interface class DesktopWindowService {
  Future<void> setHideOnClose(bool enabled);

  Future<void> hideWindow();

  Future<void> showWindow();

  Future<void> quitApp();

  Future<bool> isWindowVisible();
}

abstract interface class DesktopTrayService {
  bool get isAvailable;

  Future<bool> start();

  Future<void> refresh();

  Future<void> stop();
}

enum DesktopAutostartState {
  enabled,
  disabled,
  disabledByUser,
  disabledByPolicy,
  unavailable,
}

abstract interface class DesktopAutostartService {
  Future<DesktopAutostartState> state();

  Future<void> setEnabled(bool enabled);
}

enum DesktopActivationKind {
  normalLaunch,
  startMinimized,
  icsFile,
  webCal,
  notification,
}

@immutable
final class DesktopActivation {
  const DesktopActivation({
    required this.kind,
    this.value,
    this.action,
    this.payload,
  });

  static const maximumEncodedBytes = 16 * 1024;

  final DesktopActivationKind kind;
  final String? value;
  final String? action;
  final Map<String, String>? payload;

  bool get requiresVisibleWindow => switch (kind) {
    DesktopActivationKind.startMinimized => false,
    DesktopActivationKind.notification =>
      action == 'default' || action == 'open',
    _ => true,
  };

  Map<String, Object?> toJson() => {
    'version': 1,
    'kind': kind.name,
    if (value != null) 'value': value,
    if (action != null) 'action': action,
    if (payload != null) 'payload': payload,
  };

  String encode() => jsonEncode(toJson());

  static DesktopActivation? tryDecode(String encoded) {
    if (utf8.encode(encoded).length > maximumEncodedBytes) return null;
    try {
      final decoded = jsonDecode(encoded);
      if (decoded is! Map<String, Object?> || decoded['version'] != 1) {
        return null;
      }
      final kindName = decoded['kind'];
      if (kindName is! String) return null;
      final kind = DesktopActivationKind.values
          .where((candidate) => candidate.name == kindName)
          .firstOrNull;
      if (kind == null) return null;
      final allowedKeys = switch (kind) {
        DesktopActivationKind.normalLaunch ||
        DesktopActivationKind.startMinimized => const {'version', 'kind'},
        DesktopActivationKind.icsFile ||
        DesktopActivationKind.webCal => const {'version', 'kind', 'value'},
        DesktopActivationKind.notification => const {
          'version',
          'kind',
          'action',
          'payload',
        },
      };
      if (decoded.keys.any((key) => !allowedKeys.contains(key))) return null;
      final value = decoded['value'];
      final action = decoded['action'];
      final rawPayload = decoded['payload'];
      if (value != null && value is! String ||
          action != null && action is! String ||
          rawPayload != null && rawPayload is! Map) {
        return null;
      }
      Map<String, String>? payload;
      if (rawPayload != null) {
        payload = {};
        for (final MapEntry(:key, :value)
            in (rawPayload as Map<Object?, Object?>).entries) {
          if (key is! String || value is! String) return null;
          if (key.length > 64 || value.length > 2048) return null;
          payload[key] = value;
        }
      }
      final activation = DesktopActivation(
        kind: kind,
        value: value as String?,
        action: action as String?,
        payload: payload,
      );
      return activation.isValid ? activation : null;
    } on FormatException {
      return null;
    }
  }

  bool get isValid {
    switch (kind) {
      case DesktopActivationKind.normalLaunch:
      case DesktopActivationKind.startMinimized:
        return value == null && action == null && payload == null;
      case DesktopActivationKind.icsFile:
        final path = value;
        return path != null &&
            path.isNotEmpty &&
            path.length <= 32767 &&
            path.toLowerCase().endsWith('.ics') &&
            !path.contains('\u0000');
      case DesktopActivationKind.webCal:
        final uri = Uri.tryParse(value ?? '');
        return uri != null &&
            uri.scheme.toLowerCase() == 'webcal' &&
            uri.host.isNotEmpty &&
            uri.userInfo.isEmpty &&
            !uri.hasFragment;
      case DesktopActivationKind.notification:
        const permittedActions = {'default', 'open', 'snooze', 'dismiss'};
        const permittedPayloadKeys = {
          'notificationScheduleId',
          'itemKind',
          'accountId',
          'sourceId',
          'itemId',
        };
        return permittedActions.contains(action) &&
            payload != null &&
            payload!.containsKey('notificationScheduleId') &&
            payload!.entries.every(
              (entry) =>
                  permittedPayloadKeys.contains(entry.key) &&
                  entry.value.isNotEmpty &&
                  entry.value.length <= 2048,
            );
    }
  }
}

abstract interface class DesktopActivationService {
  Stream<DesktopActivation> get activations;

  Future<void> initialize();

  Future<void> dispose();
}

final class NoOpDesktopActivationService implements DesktopActivationService {
  const NoOpDesktopActivationService();

  @override
  Stream<DesktopActivation> get activations => const Stream.empty();

  @override
  Future<void> dispose() async {}

  @override
  Future<void> initialize() async {}
}

enum DesktopNavigationDestination { schedule, tasks, settings, signIn }

@immutable
final class DesktopNavigationRequest {
  const DesktopNavigationRequest(this.destination);

  final DesktopNavigationDestination destination;
}

abstract interface class DesktopNavigationService {
  Stream<DesktopNavigationRequest> get requests;

  void open(DesktopNavigationDestination destination);
}

final class QueuedDesktopNavigationService implements DesktopNavigationService {
  QueuedDesktopNavigationService();

  final _requests = StreamController<DesktopNavigationRequest>.broadcast();

  @override
  Stream<DesktopNavigationRequest> get requests => _requests.stream;

  @override
  void open(DesktopNavigationDestination destination) {
    _requests.add(DesktopNavigationRequest(destination));
  }

  Future<void> dispose() => _requests.close();
}

abstract interface class SystemAppearanceSource {
  Color? get accentColor;

  Brightness get brightness;

  bool get highContrast;

  Stream<void> get changes;
}

abstract interface class LocalTimeZoneSource {
  /// A non-sensitive technical diagnostic when the source had to fall back.
  String? get diagnostic;

  Future<String> currentIanaTimeZone();
}

final class FixedLocalTimeZoneSource implements LocalTimeZoneSource {
  const FixedLocalTimeZoneSource(this.timeZone);

  final String timeZone;

  @override
  String? get diagnostic => null;

  @override
  Future<String> currentIanaTimeZone() async => timeZone;
}

final class UnavailableDesktopAutostartService
    implements DesktopAutostartService {
  const UnavailableDesktopAutostartService();

  @override
  Future<DesktopAutostartState> state() async {
    return DesktopAutostartState.unavailable;
  }

  @override
  Future<void> setEnabled(bool enabled) {
    throw UnsupportedError('Launch at login is unavailable in this build.');
  }
}

final class NoOpDesktopWindowService implements DesktopWindowService {
  const NoOpDesktopWindowService();

  @override
  Future<void> hideWindow() async {}

  @override
  Future<bool> isWindowVisible() async => true;

  @override
  Future<void> quitApp() async {}

  @override
  Future<void> setHideOnClose(bool enabled) async {}

  @override
  Future<void> showWindow() async {}
}

import 'package:flutter/foundation.dart';

enum DesktopNotificationReadinessState {
  initializing,
  available,
  unavailableUnpackaged,
  failedInstalledPackage,
}

@immutable
final class DesktopNotificationReadiness {
  const DesktopNotificationReadiness(
    this.state, {
    this.diagnosticCode,
    this.permissionGranted,
    this.deliveryFailed = false,
  });

  const DesktopNotificationReadiness.initializing()
    : this(DesktopNotificationReadinessState.initializing);

  final DesktopNotificationReadinessState state;
  final String? diagnosticCode;

  /// Unknown when native APIs cannot establish OS permission. Even true does
  /// not establish whether Do Not Disturb allowed a banner or sound.
  final bool? permissionGranted;
  final bool deliveryFailed;

  bool get canNotify =>
      state == DesktopNotificationReadinessState.available &&
      permissionGranted != false &&
      !deliveryFailed;
}

typedef DesktopNotificationActionHandler = Future<void> Function(
  String action,
  Map<String, String>? payload,
);

enum BusyMaxNotificationCategory {
  general,
  reminder,
  synchronization,
  conflict,
  networkError,
}

@immutable
final class BusyMaxNotificationAction {
  const BusyMaxNotificationAction(this.id, this.label);

  final String id;
  final String label;
}

@immutable
final class BusyMaxNotificationRequest {
  const BusyMaxNotificationRequest({
    required this.stableId,
    required this.title,
    this.body = '',
    this.category = BusyMaxNotificationCategory.general,
    this.payload,
    this.actions = const [],
    this.transient = true,
    this.private = false,
  });

  final String stableId;
  final String title;
  final String body;
  final BusyMaxNotificationCategory category;
  final Map<String, String>? payload;
  final List<BusyMaxNotificationAction> actions;
  final bool transient;
  final bool private;
}

abstract interface class DesktopNotificationBackend {
  Future<void> notify(
    BusyMaxNotificationRequest request, {
    DesktopNotificationActionHandler? onAction,
  });

  Future<void> cancel(String stableId);

  Future<void> close();
}

/// Native identities are retained independently of source rows so deletion while
/// BusyMax was stopped can still withdraw notifications on the next launch.
abstract interface class DesktopNotificationIdentitySource {
  Future<Set<String>> knownReminderDeliveryIds();
}

final class DisabledDesktopNotificationBackend
    implements DesktopNotificationBackend {
  const DisabledDesktopNotificationBackend();

  @override
  Future<void> cancel(String stableId) async {}

  @override
  Future<void> close() async {}

  @override
  Future<void> notify(
    BusyMaxNotificationRequest request, {
    DesktopNotificationActionHandler? onAction,
  }) async {
    throw UnsupportedError('Desktop notifications are unavailable.');
  }
}

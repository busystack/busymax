import 'dart:io';

import '../../features/connectivity/network_connectivity_service.dart';

typedef ObservedConnectivityMonitorFactory =
    NetworkConnectivityMonitor Function();

/// Avoids NetworkManager's system D-Bus API inside a strictly confined Snap.
NetworkConnectivityMonitor createLinuxNetworkConnectivityMonitor({
  Map<String, String>? environment,
  ObservedConnectivityMonitorFactory? observedMonitorFactory,
}) {
  final runtimeEnvironment = environment ?? Platform.environment;
  final snapPath = runtimeEnvironment['SNAP']?.trim();
  if (snapPath != null && snapPath.isNotEmpty) {
    return NetworkConnectivityMonitor.withoutPlatformObservation();
  }
  return (observedMonitorFactory ?? NetworkConnectivityMonitor.new)();
}

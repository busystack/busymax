import 'dart:async';

import 'package:busymax/src/features/connectivity/network_connectivity_service.dart';
import 'package:busymax/src/platform/linux/linux_network_connectivity_monitor.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'Snap runtime does not construct the platform connectivity backend',
    () async {
      var platformFactoryCalls = 0;
      final monitor = createLinuxNetworkConnectivityMonitor(
        environment: const {'SNAP': '/snap/busymax/current'},
        observedMonitorFactory: () {
          platformFactoryCalls += 1;
          throw StateError('NetworkManager must not be accessed in a Snap');
        },
      );
      addTearDown(monitor.dispose);

      await monitor.initialize();

      expect(platformFactoryCalls, 0);
      expect(monitor.availability, NetworkAvailability.unknown);
      expect(await monitor.canUseNetwork(), isTrue);
    },
  );

  test(
    'unpackaged Linux runtime retains platform connectivity monitoring',
    () async {
      final changes = StreamController<List<ConnectivityResult>>.broadcast();
      final observedMonitor = NetworkConnectivityMonitor(
        checkConnectivity: () async => [ConnectivityResult.none],
        connectivityChanges: changes.stream,
      );
      var platformFactoryCalls = 0;
      final monitor = createLinuxNetworkConnectivityMonitor(
        environment: const {},
        observedMonitorFactory: () {
          platformFactoryCalls += 1;
          return observedMonitor;
        },
      );
      addTearDown(() async {
        await monitor.dispose();
        await changes.close();
      });

      await monitor.initialize();

      expect(platformFactoryCalls, 1);
      expect(monitor, same(observedMonitor));
      expect(monitor.availability, NetworkAvailability.offline);
    },
  );
}

import 'dart:async';

import 'package:busymax/src/core/http/terminating_http_client.dart';
import 'package:busymax/src/features/connectivity/network_connectivity_service.dart';
import 'package:busymax/src/features/sync/account_sync_operations.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

void main() {
  group('NetworkConnectivityMonitor', () {
    test('uses the initial platform state', () async {
      final changes = StreamController<List<ConnectivityResult>>.broadcast();
      final monitor = NetworkConnectivityMonitor(
        checkConnectivity: () async => [ConnectivityResult.none],
        connectivityChanges: changes.stream,
      );
      addTearDown(() async {
        await monitor.dispose();
        await changes.close();
      });

      await monitor.initialize();

      expect(monitor.availability, NetworkAvailability.offline);
      expect(monitor.canUseNetwork(), completion(isFalse));
      expect(
        monitor.requireNetwork(),
        throwsA(isA<NetworkUnavailableException>()),
      );
    });

    test('does not let a stale initial check replace a newer event', () async {
      final check = Completer<List<ConnectivityResult>>();
      final changes = StreamController<List<ConnectivityResult>>.broadcast(
        sync: true,
      );
      final monitor = NetworkConnectivityMonitor(
        checkConnectivity: () => check.future,
        connectivityChanges: changes.stream,
      );
      addTearDown(() async {
        await monitor.dispose();
        await changes.close();
      });

      final initialization = monitor.initialize();
      changes.add([ConnectivityResult.wifi]);
      check.complete([ConnectivityResult.none]);
      await initialization;

      expect(monitor.availability, NetworkAvailability.online);
    });

    test('watch does not lose an event during initialization', () async {
      final check = Completer<List<ConnectivityResult>>();
      final changes = StreamController<List<ConnectivityResult>>.broadcast(
        sync: true,
      );
      final monitor = NetworkConnectivityMonitor(
        checkConnectivity: () => check.future,
        connectivityChanges: changes.stream,
      );
      addTearDown(() async {
        await monitor.dispose();
        await changes.close();
      });
      final observed = <NetworkAvailability>[];
      final subscription = monitor.watch().listen(observed.add);
      addTearDown(subscription.cancel);

      changes.add([ConnectivityResult.wifi]);
      check.complete([ConnectivityResult.none]);
      await Future<void>.delayed(Duration.zero);

      expect(observed, [NetworkAvailability.online]);
    });

    test('emits only availability changes', () async {
      final changes = StreamController<List<ConnectivityResult>>.broadcast(
        sync: true,
      );
      final monitor = NetworkConnectivityMonitor(
        checkConnectivity: () async => [ConnectivityResult.wifi],
        connectivityChanges: changes.stream,
      );
      addTearDown(() async {
        await monitor.dispose();
        await changes.close();
      });
      await monitor.initialize();
      final observed = <NetworkAvailability>[];
      final subscription = monitor.changes.listen(observed.add);
      addTearDown(subscription.cancel);

      changes.add([ConnectivityResult.ethernet]);
      changes.add([ConnectivityResult.none]);
      changes.add([ConnectivityResult.none]);
      changes.add([ConnectivityResult.wifi]);
      await Future<void>.delayed(Duration.zero);

      expect(observed, [
        NetworkAvailability.offline,
        NetworkAvailability.online,
      ]);
    });

    test('dispose cancels an in-flight initial-check timeout', () async {
      final check = Completer<List<ConnectivityResult>>();
      final changes = StreamController<List<ConnectivityResult>>.broadcast();
      final monitor = NetworkConnectivityMonitor(
        checkConnectivity: () => check.future,
        connectivityChanges: changes.stream,
      );

      final initialization = monitor.initialize();
      await monitor.dispose();
      await initialization;
      await changes.close();

      expect(monitor.availability, NetworkAvailability.unknown);
    });
  });

  test(
    'reconnect coordinator synchronizes once per restored connection',
    () async {
      final changes = StreamController<List<ConnectivityResult>>.broadcast(
        sync: true,
      );
      final monitor = NetworkConnectivityMonitor(
        checkConnectivity: () async => [ConnectivityResult.none],
        connectivityChanges: changes.stream,
      );
      await monitor.initialize();
      var syncCalls = 0;
      final coordinator = NetworkReconnectSyncCoordinator(
        monitor: monitor,
        synchronize: () async {
          syncCalls += 1;
        },
      );
      coordinator.start();
      addTearDown(() async {
        await coordinator.dispose();
        await monitor.dispose();
        await changes.close();
      });

      changes.add([ConnectivityResult.wifi]);
      changes.add([ConnectivityResult.ethernet]);
      await Future<void>.delayed(Duration.zero);
      expect(syncCalls, 1);

      changes.add([ConnectivityResult.none]);
      changes.add([ConnectivityResult.wifi]);
      await Future<void>.delayed(Duration.zero);
      expect(syncCalls, 2);
    },
  );

  test(
    'connectivity-aware HTTP client rejects requests before transport',
    () async {
      var transportCalls = 0;
      final inner = _RecordingHttpClient(() => transportCalls += 1);
      final client = ConnectivityAwareHttpClient(
        inner: inner,
        requireNetwork: () async {
          throw const NetworkUnavailableException();
        },
      );
      addTearDown(client.close);

      expect(
        client.get(Uri.parse('https://example.test')),
        throwsA(isA<NetworkUnavailableException>()),
      );
      await Future<void>.delayed(Duration.zero);
      expect(transportCalls, 0);
    },
  );

  test('connectivity wrapper preserves terminating dispatch', () async {
    final inner = _RecordingTerminatingHttpClient();
    final client = ConnectivityAwareHttpClient(
      inner: inner,
      requireNetwork: () async {},
    );
    addTearDown(client.close);
    final terminate = Completer<void>();

    final response = await client.sendTerminating(
      http.Request('GET', Uri.parse('https://example.test')),
      terminate: terminate.future,
      connectionTimeout: const Duration(seconds: 7),
    );

    expect(response.statusCode, 204);
    expect(inner.terminatingCalls, 1);
    expect(inner.connectionTimeout, const Duration(seconds: 7));
    expect(inner.terminate, same(terminate.future));
  });

  test(
    'connectivity-aware account sync rejects every sync entry point',
    () async {
      final inner = _RecordingAccountSyncOperations();
      final operations = ConnectivityAwareAccountSyncOperations(
        inner: inner,
        requireNetwork: () async {
          throw const NetworkUnavailableException();
        },
      );

      await expectLater(
        operations.syncAccount('account', full: false),
        throwsA(isA<NetworkUnavailableException>()),
      );
      await expectLater(
        operations.syncTasks('account', full: false),
        throwsA(isA<NetworkUnavailableException>()),
      );
      await expectLater(
        operations.syncCalendar('account', full: false),
        throwsA(isA<NetworkUnavailableException>()),
      );
      expect(inner.calls, isEmpty);
    },
  );
}

final class _RecordingHttpClient extends http.BaseClient {
  _RecordingHttpClient(this.onSend);

  final void Function() onSend;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    onSend();
    return http.StreamedResponse(const Stream<List<int>>.empty(), 204);
  }
}

final class _RecordingTerminatingHttpClient extends http.BaseClient
    implements TerminatingHttpClient {
  var terminatingCalls = 0;
  Duration? connectionTimeout;
  Future<void>? terminate;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    return http.StreamedResponse(const Stream<List<int>>.empty(), 204);
  }

  @override
  Future<http.StreamedResponse> sendTerminating(
    http.BaseRequest request, {
    required Future<void> terminate,
    required Duration connectionTimeout,
  }) async {
    terminatingCalls += 1;
    this.terminate = terminate;
    this.connectionTimeout = connectionTimeout;
    return http.StreamedResponse(const Stream<List<int>>.empty(), 204);
  }
}

final class _RecordingAccountSyncOperations implements AccountSyncOperations {
  final calls = <String>[];

  @override
  Future<void> syncAccount(String accountId, {required bool full}) async {
    calls.add('account');
  }

  @override
  Future<void> syncCalendar(String accountId, {required bool full}) async {
    calls.add('calendar');
  }

  @override
  Future<void> syncTasks(String accountId, {required bool full}) async {
    calls.add('tasks');
  }
}

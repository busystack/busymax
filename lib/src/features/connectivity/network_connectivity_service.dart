import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';

import '../../core/logging/redacting_logger.dart';

enum NetworkAvailability { unknown, online, offline }

final class NetworkUnavailableException implements Exception {
  const NetworkUnavailableException();

  @override
  String toString() => 'NetworkUnavailableException';
}

typedef ConnectivityCheck = Future<List<ConnectivityResult>> Function();

final class NetworkConnectivityMonitor {
  NetworkConnectivityMonitor({
    Connectivity? connectivity,
    ConnectivityCheck? checkConnectivity,
    Stream<List<ConnectivityResult>>? connectivityChanges,
    this.initialCheckTimeout = const Duration(seconds: 5),
  }) {
    final platform = connectivity ?? Connectivity();
    _checkConnectivity = checkConnectivity ?? platform.checkConnectivity;
    _connectivityChanges =
        connectivityChanges ?? platform.onConnectivityChanged;
  }

  final Duration initialCheckTimeout;
  late final ConnectivityCheck _checkConnectivity;
  late final Stream<List<ConnectivityResult>> _connectivityChanges;
  final _changes = StreamController<NetworkAvailability>.broadcast(sync: true);
  final _logger = RedactingLogger(Logger('NetworkConnectivityMonitor'));

  StreamSubscription<List<ConnectivityResult>>? _subscription;
  Future<void>? _initialization;
  Timer? _initialCheckTimer;
  Completer<List<ConnectivityResult>?>? _initialCheckCompleter;
  NetworkAvailability _availability = NetworkAvailability.unknown;
  var _observationVersion = 0;
  var _disposed = false;

  NetworkAvailability get availability => _availability;

  bool get isOffline => _availability == NetworkAvailability.offline;

  Stream<NetworkAvailability> get changes => _changes.stream;

  Future<void> initialize() {
    return _initialization ??= _initialize();
  }

  Stream<NetworkAvailability> watch() {
    late final StreamController<NetworkAvailability> controller;
    StreamSubscription<NetworkAvailability>? subscription;
    var cancelled = false;
    controller = StreamController<NetworkAvailability>(
      sync: true,
      onListen: () {
        subscription = changes.listen(controller.add);
        unawaited(
          initialize().then((_) {
            if (!cancelled) {
              controller.add(_availability);
            }
          }),
        );
      },
      onCancel: () {
        cancelled = true;
        return subscription?.cancel();
      },
    );
    return controller.stream.distinct();
  }

  Future<bool> canUseNetwork() async {
    await initialize();
    return !isOffline;
  }

  Future<void> requireNetwork() async {
    if (!await canUseNetwork()) {
      throw const NetworkUnavailableException();
    }
  }

  Future<void> _initialize() async {
    if (_disposed) {
      return;
    }

    try {
      _subscription = _connectivityChanges.listen(
        (results) {
          _observationVersion += 1;
          _setAvailability(_availabilityFor(results));
        },
        onError: (Object error, StackTrace stackTrace) {
          _observationVersion += 1;
          _logger.warning('Connectivity updates unavailable: $error');
          _setAvailability(NetworkAvailability.unknown);
        },
        onDone: () {
          if (!_disposed) {
            _observationVersion += 1;
            _setAvailability(NetworkAvailability.unknown);
          }
        },
      );
    } on Object catch (error) {
      _logger.warning('Connectivity updates unavailable: $error');
    }

    final versionBeforeCheck = _observationVersion;
    try {
      final results = await _runInitialCheck();
      if (results == null) {
        return;
      }
      if (!_disposed && _observationVersion == versionBeforeCheck) {
        _setAvailability(_availabilityFor(results));
      }
    } on Object catch (error) {
      _logger.warning('Initial connectivity check unavailable: $error');
      if (!_disposed && _observationVersion == versionBeforeCheck) {
        _setAvailability(NetworkAvailability.unknown);
      }
    }
  }

  Future<List<ConnectivityResult>?> _runInitialCheck() {
    final completer = Completer<List<ConnectivityResult>?>();
    _initialCheckCompleter = completer;
    _initialCheckTimer = Timer(initialCheckTimeout, () {
      if (!completer.isCompleted) {
        completer.complete();
      }
    });
    Future<List<ConnectivityResult>>.sync(_checkConnectivity).then(
      (results) {
        if (!completer.isCompleted) {
          completer.complete(results);
        }
      },
      onError: (Object error, StackTrace stackTrace) {
        if (!completer.isCompleted) {
          completer.completeError(error, stackTrace);
        }
      },
    );
    return completer.future.whenComplete(() {
      _initialCheckTimer?.cancel();
      _initialCheckTimer = null;
      if (identical(_initialCheckCompleter, completer)) {
        _initialCheckCompleter = null;
      }
    });
  }

  void _setAvailability(NetworkAvailability value) {
    if (_disposed || value == _availability) {
      return;
    }
    _availability = value;
    _changes.add(value);
  }

  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    _disposed = true;
    _initialCheckTimer?.cancel();
    _initialCheckTimer = null;
    final initialCheck = _initialCheckCompleter;
    if (initialCheck != null && !initialCheck.isCompleted) {
      initialCheck.complete();
    }
    await _subscription?.cancel();
    await _changes.close();
  }
}

final class ConnectivityAwareHttpClient extends http.BaseClient {
  ConnectivityAwareHttpClient({
    required http.Client inner,
    required Future<void> Function() requireNetwork,
  }) : _inner = inner,
       _requireNetwork = requireNetwork;

  final http.Client _inner;
  final Future<void> Function() _requireNetwork;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    await _requireNetwork();
    return _inner.send(request);
  }

  @override
  void close() {
    _inner.close();
  }
}

final class NetworkReconnectSyncCoordinator {
  NetworkReconnectSyncCoordinator({
    required NetworkConnectivityMonitor monitor,
    required Future<void> Function() synchronize,
  }) : _monitor = monitor,
       _synchronize = synchronize;

  final NetworkConnectivityMonitor _monitor;
  final Future<void> Function() _synchronize;
  final _logger = RedactingLogger(Logger('NetworkReconnectSyncCoordinator'));

  StreamSubscription<NetworkAvailability>? _subscription;
  var _wasOffline = false;

  void start() {
    if (_subscription != null) {
      return;
    }
    _wasOffline = _monitor.isOffline;
    _subscription = _monitor.changes.listen(_handleAvailability);
    unawaited(_monitor.initialize());
  }

  void _handleAvailability(NetworkAvailability availability) {
    switch (availability) {
      case NetworkAvailability.offline:
        _wasOffline = true;
        return;
      case NetworkAvailability.online:
        if (_wasOffline) {
          _wasOffline = false;
          unawaited(_synchronizeAfterReconnect());
        }
        return;
      case NetworkAvailability.unknown:
        return;
    }
  }

  Future<void> _synchronizeAfterReconnect() async {
    try {
      await _synchronize();
    } on Object catch (error) {
      _logger.warning('Reconnect synchronization failed: $error');
    }
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
  }
}

NetworkAvailability _availabilityFor(List<ConnectivityResult> results) {
  if (results.isEmpty) {
    return NetworkAvailability.unknown;
  }
  return results.any((result) => result != ConnectivityResult.none)
      ? NetworkAvailability.online
      : NetworkAvailability.offline;
}

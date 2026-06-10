import 'dart:async';

import 'package:logging/logging.dart';

import '../../core/logging/redacting_logger.dart';

class PendingMutationSyncRequester {
  PendingMutationSyncRequester({
    required Future<void> Function() sync,
    Future<void> Function(String message)? onSyncFailure,
    Duration debounce = const Duration(milliseconds: 300),
  }) : _sync = sync,
       _onSyncFailure = onSyncFailure,
       _debounce = debounce;

  final Future<void> Function() _sync;
  final Future<void> Function(String message)? _onSyncFailure;
  final Duration _debounce;
  final RedactingLogger _logger = RedactingLogger(
    Logger('PendingMutationSyncRequester'),
  );

  Timer? _debounceTimer;
  var _disposed = false;
  var _running = false;
  var _runAgain = false;

  void request() {
    if (_disposed) {
      return;
    }
    if (_running) {
      _runAgain = true;
      return;
    }

    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounce, () {
      _debounceTimer = null;
      _startSync();
    });
  }

  void dispose() {
    _disposed = true;
    _runAgain = false;
    _debounceTimer?.cancel();
    _debounceTimer = null;
  }

  void _startSync() {
    if (_disposed) {
      return;
    }
    if (_running) {
      _runAgain = true;
      return;
    }

    _running = true;
    unawaited(_runSync());
  }

  Future<void> _runSync() async {
    try {
      await _sync();
    } on Object catch (error) {
      _logger.warning('Pending mutation sync failed: $error');
      await _onSyncFailure?.call(error.toString());
    } finally {
      _running = false;
      if (!_disposed && _runAgain) {
        _runAgain = false;
        _startSync();
      }
    }
  }
}

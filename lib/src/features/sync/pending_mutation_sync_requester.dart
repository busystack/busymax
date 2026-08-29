import 'dart:async';

import 'package:logging/logging.dart';

import '../../core/logging/redacting_logger.dart';

class PendingMutationSyncRequester {
  PendingMutationSyncRequester({
    required Future<void> Function() sync,
    Future<void> Function(Object error)? onSyncFailure,
    Future<void> Function(Object error)? onSyncError,
    Future<bool> Function()? canSync,
    Duration debounce = const Duration(milliseconds: 300),
  }) : _sync = sync,
       _onSyncFailure = onSyncFailure,
       _onSyncError = onSyncError,
       _canSync = canSync ?? _allowSync,
       _debounce = debounce;

  final Future<void> Function() _sync;
  final Future<void> Function(Object error)? _onSyncFailure;
  final Future<void> Function(Object error)? _onSyncError;
  final Future<bool> Function() _canSync;
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
      if (!await _canSync()) {
        return;
      }
      await _sync();
    } on Object catch (error) {
      _logger.warning('Pending mutation sync failed: $error');
      try {
        await _onSyncError?.call(error);
      } on Object {
        // Preserve notification delivery for the original sync failure.
      }
      await _onSyncFailure?.call(error);
    } finally {
      _running = false;
      if (!_disposed && _runAgain) {
        _runAgain = false;
        _startSync();
      }
    }
  }
}

Future<bool> _allowSync() async => true;

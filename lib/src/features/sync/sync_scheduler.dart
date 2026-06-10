import 'dart:async';

import 'sync_engine.dart';

class SyncScheduler {
  SyncScheduler({
    required SyncEngine syncEngine,
    Future<void> Function(String message)? onSyncFailure,
    this.interval = const Duration(minutes: 15),
  }) : _syncEngine = syncEngine,
       _onSyncFailure = onSyncFailure;

  final SyncEngine _syncEngine;
  final Future<void> Function(String message)? _onSyncFailure;
  final Duration interval;
  Timer? _timer;

  void start() {
    stop();
    if (interval == Duration.zero) {
      return;
    }
    _timer = Timer.periodic(interval, (_) {
      unawaited(_runSync());
    });
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _runSync() async {
    try {
      await _syncEngine.incrementalSync();
    } on Object catch (error) {
      await _onSyncFailure?.call(error.toString());
    }
  }
}

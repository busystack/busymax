import 'dart:async';

import 'sync_engine.dart';

class SyncScheduler {
  SyncScheduler({
    required SyncEngine syncEngine,
    Future<void> Function(Object error)? onSyncFailure,
    Future<bool> Function()? canSync,
    this.interval = const Duration(minutes: 15),
  }) : _syncEngine = syncEngine,
       _onSyncFailure = onSyncFailure,
       _canSync = canSync ?? _allowSync;

  final SyncEngine _syncEngine;
  final Future<void> Function(Object error)? _onSyncFailure;
  final Future<bool> Function() _canSync;
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
      if (!await _canSync()) {
        return;
      }
      await _syncEngine.incrementalSync();
    } on Object catch (error) {
      await _onSyncFailure?.call(error);
    }
  }
}

Future<bool> _allowSync() async => true;

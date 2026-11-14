import 'package:logging/logging.dart';

import 'dart:async';

import 'package:busymax_android_platform/busymax_android_platform.dart';

/// The existing engine-owned native semaphore covers the entire notification
/// decision, allocation, submission and persistence. Engine detachment or a
/// stopped worker releases its lease. Only nested work in this async operation
/// may reuse it; a second runtime must acquire its own lease and read afresh.
final class AndroidNotificationGate {
  AndroidNotificationGate(this.platform);
  final BusyMaxAndroidPlatform platform;
  static final _zoneKey = Object();
  final _pending = <Future<void>>{};

  Future<void> drain() async {
    // Wait only for this runtime's submitted work. Acquiring a new global
    // lease here would block cleanup behind an unrelated engine.
    while (_pending.isNotEmpty) {
      await Future.wait(_pending.toList());
    }
  }

  Future<T> run<T>(Future<T> Function() operation) async {
    // This completion signal tracks ownership without attaching an error
    // handler to the returned operation: unobserved failures remain visible.
    final completion = Completer<void>();
    _pending.add(completion.future);
    try {
      return await _run(operation);
    } finally {
      _pending.remove(completion.future);
      completion.complete();
    }
  }

  Future<T> _run<T>(Future<T> Function() operation) async {
    final held = Zone.current[_zoneKey] as _HeldNotificationGate?;
    if (held != null && held.active && identical(held.platform, platform)) {
      return operation();
    }
    // Native traces show a finite 25-second reconcile under concurrent
    // writers. Three runtime owners can queue at startup; an account's usual
    // 30-second lease budget must not truncate this shared notification work.
    final lease = await platform.acquireAccountGate(
      '__notifications__',
      timeout: const Duration(seconds: 90),
    );
    final owner = _HeldNotificationGate(platform);
    Object? failure;
    try {
      return await runZoned(operation, zoneValues: {_zoneKey: owner});
    } catch (error) {
      failure = error;
      rethrow;
    } finally {
      owner.active = false;
      try {
        await platform.releaseAccountGate(lease);
      } catch (_) {
        if (failure == null) rethrow;
        Logger('AndroidNotificationGate')
            .warning('Native lease release failed after an operation failure.');
      }
    }
  }
}

final class _HeldNotificationGate {
  _HeldNotificationGate(this.platform);
  final BusyMaxAndroidPlatform platform;
  bool active = true;
}

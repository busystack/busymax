import 'dart:async';

import 'package:busymax_android_platform/busymax_android_platform.dart';

/// The existing engine-owned native semaphore covers the entire notification
/// decision, allocation, submission and persistence. Engine detachment or a
/// stopped worker releases its lease. Only nested work in this async operation
/// may reuse it; a second runtime must acquire its own lease and read afresh.
final class AndroidNotificationGate {
  const AndroidNotificationGate(this.platform);
  final BusyMaxAndroidPlatform platform;
  static final _zoneKey = Object();

  Future<T> run<T>(Future<T> Function() operation) async {
    final held = Zone.current[_zoneKey] as _HeldNotificationGate?;
    if (held != null && held.active && identical(held.platform, platform)) {
      return operation();
    }
    final lease = await platform.acquireAccountGate('__notifications__');
    final owner = _HeldNotificationGate(platform);
    try {
      return await runZoned(operation, zoneValues: {_zoneKey: owner});
    } finally {
      owner.active = false;
      await platform.releaseAccountGate(lease);
    }
  }
}

final class _HeldNotificationGate {
  _HeldNotificationGate(this.platform);
  final BusyMaxAndroidPlatform platform;
  bool active = true;
}

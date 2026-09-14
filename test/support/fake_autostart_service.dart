import 'dart:async';

import 'package:busymax/src/platform/common/desktop_services.dart';

class FakeAutostartService implements DesktopAutostartService {
  DesktopAutostartState current = DesktopAutostartState.disabled;
  Object? readError;
  Object? writeError;
  Completer<void>? readBarrier;
  Completer<void>? writeBarrier;
  int reads = 0;
  final writes = <bool>[];

  @override
  Future<DesktopAutostartState> state() async {
    reads++;
    await readBarrier?.future;
    if (readError case final error?) throw error;
    return current;
  }

  @override
  Future<void> setEnabled(bool enabled) async {
    writes.add(enabled);
    await writeBarrier?.future;
    if (writeError case final error?) throw error;
    current = enabled
        ? DesktopAutostartState.enabled
        : DesktopAutostartState.disabled;
  }
}

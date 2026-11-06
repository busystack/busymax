import 'dart:async';

import 'package:logging/logging.dart';

/// One runtime owns exactly these resources, including during failed creation.
/// Closing one owner never releases another engine's native leases.
final class AndroidRuntimeResources {
  final _cleanup = <FutureOr<void> Function()>[];
  Future<void>? _closing;

  T own<T>(T value, FutureOr<void> Function(T) dispose) {
    if (_closing != null) {
      throw StateError('Runtime resources already closing.');
    }
    _cleanup.add(() => dispose(value));
    return value;
  }

  Future<void> close({bool preserveFailure = false}) async {
    try {
      await (_closing ??= _close());
    } catch (_) {
      if (!preserveFailure) rethrow;
    }
  }

  Future<void> _close() async {
    Object? first;
    StackTrace? trace;
    for (final dispose in _cleanup.reversed) {
      try {
        await dispose();
      } catch (error, stack) {
        first ??= error;
        trace ??= stack;
        // Do not include credentials, provider errors or certificate text.
        Logger('AndroidRuntime').warning('A runtime resource failed to close.');
      }
    }
    _cleanup.clear();
    if (first != null) Error.throwWithStackTrace(first, trace!);
  }
}

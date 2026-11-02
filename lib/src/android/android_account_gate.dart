import 'package:logging/logging.dart';
import 'package:busymax_android_platform/busymax_android_platform.dart';

import '../features/sync/account_sync_operations.dart';

final class AndroidCrossEngineAccountGate
    implements SharedCrossEngineAccountGate {
  const AndroidCrossEngineAccountGate(this._platform);

  final BusyMaxAndroidPlatform _platform;

  @override
  Future<T> run<T>(String accountId, Future<T> Function() operation) =>
      _run(accountId, operation, false);

  @override
  Future<T> runShared<T>(String accountId, Future<T> Function() operation) =>
      _run(accountId, operation, true);

  Future<T> _run<T>(
    String accountId,
    Future<T> Function() operation,
    bool shared,
  ) async {
    final lease = await _platform.acquireAccountGate(
      accountId,
      shared: shared,
      timeout: accountId.startsWith('authorization:')
          // Readers own at most two minutes of active HTTP work. Allow
          // bounded cleanup time before failing an exclusive writer.
          ? const Duration(seconds: 150)
          : const Duration(seconds: 30),
    );
    Object? failure;
    try {
      return await operation();
    } catch (error) {
      failure = error;
      rethrow;
    } finally {
      try {
        await _platform.releaseAccountGate(lease);
      } catch (_) {
        if (failure == null) rethrow;
        Logger('AndroidAccountGate')
            .warning('Native lease release failed after an operation failure.');
      }
    }
  }
}

import 'package:logging/logging.dart';
import 'package:busymax_android_platform/busymax_android_platform.dart';

import '../features/sync/account_sync_operations.dart';

final class AndroidCrossEngineAccountGate implements CrossEngineAccountGate {
  const AndroidCrossEngineAccountGate(this._platform);

  final BusyMaxAndroidPlatform _platform;

  @override
  Future<T> run<T>(String accountId, Future<T> Function() operation) async {
    final lease = await _platform.acquireAccountGate(accountId);
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

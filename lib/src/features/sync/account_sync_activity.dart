import 'package:flutter/foundation.dart';

/// Current-process outcomes are separate from durable successful pull times.
/// A deferred pull never manufactures a new successful synchronization date.
final class AccountSyncActivity extends ChangeNotifier {
  final _running = <(String, String), int>{};
  final _failures = <(String, String), Object>{};
  bool _disposed = false;

  bool isRunning(String id, String domain) => (_running[(id, domain)] ?? 0) > 0;
  Object? failure(String id, String domain) => _failures[(id, domain)];

  Future<T> run<T>(
    String id,
    String domain,
    Future<T> Function() work, {
    bool Function()? clearFailureOnSuccess,
  }) async {
    final key = (id, domain);
    _running.update(key, (count) => count + 1, ifAbsent: () => 1);
    _notify();
    try {
      final result = await work();
      // Dispatching queued writes alone does not confirm that a failed pull
      // recovered. The caller knows whether a fresh pull actually completed.
      if (clearFailureOnSuccess?.call() ?? true) {
        _failures.remove(key);
      }
      return result;
    } on Object catch (error) {
      _failures[key] = error;
      rethrow;
    } finally {
      final count = (_running[key] ?? 1) - 1;
      if (count == 0) {
        _running.remove(key);
      } else {
        _running[key] = count;
      }
      _notify();
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

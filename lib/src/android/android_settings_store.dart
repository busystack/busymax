import 'package:busymax_android_platform/busymax_android_platform.dart';

import '../app/app_settings.dart';
import 'android_account_gate.dart';

/// Uses a different, short-lived gate from notification reconciliation. Never
/// hold this gate while requesting notification work: reconciliation reads the
/// policy under its notification gate, then briefly acquires this one.
final class AndroidSettingsStore implements AtomicLocalSettingsStore {
  AndroidSettingsStore({
    LocalSettingsStore? store,
    BusyMaxAndroidPlatform? platform,
  }) : _store = store ?? const JsonFileLocalSettingsStore(),
       _platform = platform ?? BusyMaxAndroidPlatform.instance;
  final LocalSettingsStore _store;
  final BusyMaxAndroidPlatform _platform;

  Future<T> _locked<T>(Future<T> Function() operation) =>
      AndroidCrossEngineAccountGate(_platform)
          .run('__notification_settings__', operation);

  @override
  Future<Map<String, Object?>> load() => _locked(_store.load);

  @override
  Future<void> save(Map<String, Object?> json) async {
    await _locked(() => _store.save(json));
    await _platform.notifyDataChanged();
  }

  @override
  Future<Map<String, Object?>> update(
    Map<String, Object?> Function(Map<String, Object?>) mutation,
  ) async {
    final result = await _locked(() async {
      final updated = mutation(await _store.load());
      await _store.save(updated);
      return updated;
    });
    await _platform.notifyDataChanged();
    return result;
  }
}

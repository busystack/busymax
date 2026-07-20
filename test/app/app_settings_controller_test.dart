import 'dart:async';

import 'package:busymax/src/app/app_settings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a preference changed during loading is not overwritten', () async {
    final store = _DelayedLoadSettingsStore();
    final controller = AppSettingsController(store);

    final save = controller.setThemeModePreference(
      BusyMaxThemeModePreference.dark,
    );
    expect(
      controller.state.themeModePreference,
      BusyMaxThemeModePreference.dark,
    );

    store.completeLoad(<String, Object?>{
      'themeModePreference': BusyMaxThemeModePreference.light.name,
      'notifyConflicts': false,
    });
    await save.timeout(const Duration(seconds: 1));
    await Future<void>.delayed(Duration.zero);

    expect(
      controller.state.themeModePreference,
      BusyMaxThemeModePreference.dark,
    );
    expect(controller.state.notifyConflicts, isFalse);
    expect(
      store.persisted['themeModePreference'],
      BusyMaxThemeModePreference.dark.name,
    );
    expect(store.persisted['notifyConflicts'], isFalse);
  });

  test('overlapping saves cannot persist in reverse order', () async {
    final store = _OutOfOrderSettingsStore();
    final controller = AppSettingsController(store);
    await Future<void>.delayed(Duration.zero);

    final first = controller.setThemeModePreference(
      BusyMaxThemeModePreference.dark,
    );
    final second = controller.setThemeModePreference(
      BusyMaxThemeModePreference.light,
    );

    await Future<void>.delayed(Duration.zero);
    store.releaseFirstSave();
    await Future.wait([first, second]).timeout(const Duration(seconds: 1));

    expect(
      controller.state.themeModePreference,
      BusyMaxThemeModePreference.light,
    );
    expect(
      store.persisted['themeModePreference'],
      BusyMaxThemeModePreference.light.name,
    );
  });

  test(
    'a failed save does not prevent later preferences from persisting',
    () async {
      final store = _FailFirstSaveSettingsStore();
      final controller = AppSettingsController(store);
      await Future<void>.delayed(Duration.zero);

      await controller
          .setThemeModePreference(BusyMaxThemeModePreference.dark)
          .timeout(const Duration(seconds: 1));
      await controller
          .setThemeModePreference(BusyMaxThemeModePreference.light)
          .timeout(const Duration(seconds: 1));

      expect(store.saveCount, 2);
      expect(
        controller.state.themeModePreference,
        BusyMaxThemeModePreference.light,
      );
      expect(
        store.persisted['themeModePreference'],
        BusyMaxThemeModePreference.light.name,
      );
    },
  );
}

class _DelayedLoadSettingsStore implements LocalSettingsStore {
  final _load = Completer<Map<String, Object?>>();
  Map<String, Object?> persisted = <String, Object?>{};

  void completeLoad(Map<String, Object?> json) {
    _load.complete(Map<String, Object?>.from(json));
  }

  @override
  Future<Map<String, Object?>> load() => _load.future;

  @override
  Future<void> save(Map<String, Object?> json) async {
    persisted = Map<String, Object?>.from(json);
  }
}

class _OutOfOrderSettingsStore implements LocalSettingsStore {
  final _firstSaveGate = Completer<void>();
  var _saveCount = 0;
  Map<String, Object?> persisted = <String, Object?>{};

  void releaseFirstSave() {
    _firstSaveGate.complete();
  }

  @override
  Future<Map<String, Object?>> load() async => <String, Object?>{};

  @override
  Future<void> save(Map<String, Object?> json) async {
    _saveCount += 1;
    if (_saveCount == 1) {
      await _firstSaveGate.future;
    }
    persisted = Map<String, Object?>.from(json);
  }
}

class _FailFirstSaveSettingsStore implements LocalSettingsStore {
  var saveCount = 0;
  Map<String, Object?> persisted = <String, Object?>{};

  @override
  Future<Map<String, Object?>> load() async => <String, Object?>{};

  @override
  Future<void> save(Map<String, Object?> json) async {
    saveCount += 1;
    if (saveCount == 1) {
      throw StateError('settings storage unavailable');
    }
    persisted = Map<String, Object?>.from(json);
  }
}

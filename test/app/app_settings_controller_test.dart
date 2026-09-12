import 'dart:async';

import 'package:busymax/src/app/app_settings.dart';
import 'package:busymax/src/schedule/schedule_sidebar_order.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/memory_settings_store.dart';

void main() {
  test(
    'save failure is reported without losing changes and retry clears it',
    () async {
      final store = _FailFirstSaveSettingsStore();
      final failures = <bool>[];
      final controller = AppSettingsController(
        store,
        onPersistenceChanged: failures.add,
      );
      addTearDown(controller.dispose);
      await controller.ready;
      await controller.setThemeModePreference(BusyMaxThemeModePreference.dark);
      expect(failures, [true]);
      expect(
        controller.state.themeModePreference,
        BusyMaxThemeModePreference.dark,
      );
      await controller.retrySave();
      expect(failures, [true, false]);
      expect(store.persisted['themeModePreference'], 'dark');
    },
  );
  test(
    'sidebar snapshots wait for settings and preserve the first sequence',
    () async {
      final store = _DelayedLoadSettingsStore();
      final controller = AppSettingsController(store);
      addTearDown(controller.dispose);
      final first = controller.registerSidebarIds(
        SidebarOrderSection.accounts,
        ['a', 'b', 'c'],
      );
      final second = controller.registerSidebarIds(
        SidebarOrderSection.accounts,
        ['c', 'b', 'a', 'd'],
      );
      expect(controller.state.sidebarOrder.accountIds, isEmpty);
      store.completeLoad({
        'sidebarOrder': ScheduleSidebarOrder(accountIds: ['b', 'a']).toJson(),
      });
      await Future.wait([first, second]);
      expect(controller.state.sidebarOrder.accountIds, ['b', 'a', 'c', 'd']);
      expect(AppSettings.fromJson(store.persisted).sidebarOrder.accountIds, [
        'b',
        'a',
        'c',
        'd',
      ]);
    },
  );

  test(
    'sidebar movement is adjacent, queued, isolated and restart persistent',
    () async {
      final store = MemorySettingsStore();
      final controller = AppSettingsController(store);
      addTearDown(controller.dispose);
      await controller.ready;
      for (final section in SidebarOrderSection.values) {
        final accountId =
            section == SidebarOrderSection.calendars ||
                section == SidebarOrderSection.taskLists
            ? 'account'
            : null;
        await controller.registerSidebarIds(section, [
          'a',
          'b',
          'c',
        ], accountId: accountId);
        final first = controller.moveSidebarItem(section, 'c', -1, [
          'a',
          'b',
          'c',
        ], accountId: accountId);
        expect(
          controller.state.sidebarOrder.sequence(section, accountId: accountId),
          ['a', 'c', 'b'],
        );
        final second = controller.moveSidebarItem(section, 'c', -1, [
          'a',
          'b',
          'c',
        ], accountId: accountId);
        await Future.wait([first, second]);
        await controller.registerSidebarIds(section, [
          'b',
          'a',
          'c',
          'd',
        ], accountId: accountId);
        await controller.moveSidebarItem(section, 'c', -1, [
          'a',
          'b',
          'c',
          'd',
        ], accountId: accountId);
        await controller.moveSidebarItem(section, 'd', 1, [
          'a',
          'b',
          'c',
          'd',
        ], accountId: accountId);
        expect(
          controller.state.sidebarOrder.sequence(section, accountId: accountId),
          ['c', 'a', 'b', 'd'],
        );
        // Absent rows are omitted; the next present row is the adjacent sibling.
        await controller.moveSidebarItem(section, 'c', 1, [
          'c',
          'b',
        ], accountId: accountId);
        expect(
          controller.state.sidebarOrder.apply(
            section,
            ['d', 'b', 'c'],
            (id) => id,
            accountId: accountId,
          ),
          ['b', 'c', 'd'],
        );
      }
      await controller.registerSidebarIds(SidebarOrderSection.taskLists, [
        'b',
        'a',
      ], accountId: 'other');
      expect(controller.state.sidebarOrder.taskListIdsByAccount['other'], [
        'b',
        'a',
      ]);
      final saveCount = store.saves;
      await controller.registerSidebarIds(SidebarOrderSection.taskLists, [
        'a',
        'b',
      ], accountId: 'other');
      expect(store.saves, saveCount);
      final restarted = AppSettingsController(store);
      addTearDown(restarted.dispose);
      await restarted.ready;
      expect(
        restarted.state.sidebarOrder.toJson(),
        controller.state.sidebarOrder.toJson(),
      );
    },
  );

  test(
    'ID replacement retains temporary position and removes server duplicates',
    () async {
      final store = MemorySettingsStore();
      final controller = AppSettingsController(store);
      addTearDown(controller.dispose);
      for (final section in [
        SidebarOrderSection.calendars,
        SidebarOrderSection.taskLists,
      ]) {
        await controller.registerSidebarIds(section, [
          'server',
          'a',
          'temp',
          'b',
        ], accountId: 'account');
        await controller.registerSidebarIds(section, [
          'temp',
          'server',
        ], accountId: 'other');
        final original = controller.state.sidebarOrder;
        await controller.replaceSidebarId(
          section,
          'temp',
          'server',
          accountId: 'account',
        );
        expect(
          controller.state.sidebarOrder.sequence(section, accountId: 'account'),
          ['a', 'server', 'b'],
        );
        expect(
          controller.state.sidebarOrder.sequence(section, accountId: 'other'),
          ['temp', 'server'],
        );
        expect(original.sequence(section, accountId: 'account'), [
          'server',
          'a',
          'temp',
          'b',
        ]);
        expect(
          AppSettings.fromJson(store.value).sidebarOrder.toJson(),
          controller.state.sidebarOrder.toJson(),
        );
      }
    },
  );

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

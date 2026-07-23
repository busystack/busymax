import 'package:busymax/src/app/app_settings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'notification detail level is the only persisted runtime setting',
    () async {
      final store = _MemorySettingsStore();
      final controller = AppSettingsController(store);
      addTearDown(controller.dispose);
      await controller.ready;

      await controller.setNotificationDetailLevel(
        NotificationDetailLevel.private,
      );

      expect(
        controller.state.notificationDetailLevel,
        NotificationDetailLevel.private,
      );
      expect(store.value['notificationDetailLevel'], 'private');
      expect(store.value, isNot(contains('detailedNotifications')));
    },
  );

  test(
    'legacy notification privacy data migrates without overriding new data',
    () {
      final currentFormatWins = AppSettings.fromJson(const {
        'detailedNotifications': true,
        'notificationDetailLevel': 'private',
      });
      final legacyDetailed = AppSettings.fromJson(const {
        'detailedNotifications': true,
      });
      final legacyPrivate = AppSettings.fromJson(const {
        'detailedNotifications': false,
      });

      expect(
        currentFormatWins.notificationDetailLevel,
        NotificationDetailLevel.private,
      );
      expect(
        legacyDetailed.notificationDetailLevel,
        NotificationDetailLevel.normal,
      );
      expect(
        legacyPrivate.notificationDetailLevel,
        NotificationDetailLevel.private,
      );
    },
  );

  test('quiet hours persist only normalized, distinct times', () async {
    final store = _MemorySettingsStore();
    final first = AppSettingsController(store);
    addTearDown(first.dispose);
    await first.ready;

    await first.setQuietHoursStart('21:5');
    await first.setQuietHoursEnd('6:45');
    expect(first.state.quietHoursStart, '21:05');
    expect(first.state.quietHoursEnd, '06:45');

    await first.setQuietHoursStart('invalid');
    await first.setQuietHoursEnd('21:05');
    expect(first.state.quietHoursStart, '21:05');
    expect(first.state.quietHoursEnd, '06:45');

    final second = AppSettingsController(store);
    addTearDown(second.dispose);
    await second.ready;
    expect(second.state.quietHoursStart, '21:05');
    expect(second.state.quietHoursEnd, '06:45');
  });

  test('invalid persisted quiet-hour ranges fall back safely', () {
    final invalidFormat = AppSettings.fromJson(const {
      'quietHoursStart': '25:00',
      'quietHoursEnd': 'not-a-time',
    });
    final equalRange = AppSettings.fromJson(const {
      'quietHoursStart': '08:00',
      'quietHoursEnd': '08:00',
    });

    expect(invalidFormat.quietHoursStart, '22:00');
    expect(invalidFormat.quietHoursEnd, '07:00');
    expect(equalRange.quietHoursStart, '22:00');
    expect(equalRange.quietHoursEnd, '07:00');
  });

  test('tray-dependent preferences remain internally consistent', () async {
    final controller = AppSettingsController(_MemorySettingsStore());
    addTearDown(controller.dispose);
    await controller.ready;

    await controller.setShowTrayIcon(false);
    expect(controller.state.showTrayIcon, isFalse);
    expect(controller.state.runInBackgroundWhenClosed, isFalse);
    expect(controller.state.startMinimizedToTray, isFalse);

    await controller.setRunInBackgroundWhenClosed(true);
    expect(controller.state.showTrayIcon, isTrue);
    expect(controller.state.runInBackgroundWhenClosed, isTrue);

    await controller.setShowTrayIcon(false);
    await controller.setStartMinimizedToTray(true);
    expect(controller.state.showTrayIcon, isTrue);
    expect(controller.state.startMinimizedToTray, isTrue);
  });

  test(
    'legacy background preferences retain a recoverable tray entry point',
    () {
      final migrated = AppSettings.fromJson(const {
        'showTrayIcon': false,
        'runInBackgroundWhenClosed': true,
      });

      expect(migrated.showTrayIcon, isTrue);
      expect(migrated.runInBackgroundWhenClosed, isTrue);
    },
  );

  test(
    'preloaded settings are available before the first provider frame',
    () async {
      final store = _MemorySettingsStore()
        ..value = <String, Object?>{'themeModePreference': 'dark'};
      final initialSettings = await loadInitialAppSettings(store);
      final controller = AppSettingsController(
        store,
        initialSettings: initialSettings,
      );
      addTearDown(controller.dispose);

      expect(
        controller.state.themeModePreference,
        BusyMaxThemeModePreference.dark,
      );
      await controller.ready;
      expect(
        controller.state.themeModePreference,
        BusyMaxThemeModePreference.dark,
      );
    },
  );

  test('preloading malformed settings falls back to defaults', () async {
    final settings = await loadInitialAppSettings(_ThrowingSettingsStore());

    expect(settings.themeModePreference, BusyMaxThemeModePreference.system);
  });
}

class _MemorySettingsStore implements LocalSettingsStore {
  Map<String, Object?> value = <String, Object?>{};

  @override
  Future<Map<String, Object?>> load() async => value;

  @override
  Future<void> save(Map<String, Object?> json) async {
    value = Map<String, Object?>.from(json);
  }
}

class _ThrowingSettingsStore implements LocalSettingsStore {
  @override
  Future<Map<String, Object?>> load() => Future.error(const FormatException());

  @override
  Future<void> save(Map<String, Object?> json) async {}
}

import 'dart:async';

import 'package:busymax/l10n/generated/app_localizations.dart';
import 'package:busymax/src/app/app_bootstrap.dart';
import 'package:busymax/src/platform/common/desktop_services.dart';
import 'package:busymax/src/ui/windows/windows_desktop_runtime.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/memory_settings_store.dart';

void main() {
  for (final initiallyShowTray in [false, true]) {
    testWidgets(
      'changing Start minimized after normal launch keeps the window open (tray=$initiallyShowTray)',
      (tester) async {
        final window = _Window();
        final tray = _Tray();
        final container = await _pumpRuntime(
          tester,
          window,
          tray,
          showTray: initiallyShowTray,
        );
        await container
            .read(appSettingsControllerProvider.notifier)
            .setStartMinimizedToTray(true);
        await tester.pumpAndSettle();
        expect(tray.isAvailable, isTrue);
        expect(window.hides, 0);
        expect(window.visible, isTrue);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  testWidgets(
    'minimized launch allows removing tray and restores the window first',
    (tester) async {
      final calls = <String>[];
      final window = _Window(calls: calls);
      final tray = _Tray(calls: calls);
      final container = await _pumpRuntime(
        tester,
        window,
        tray,
        minimized: true,
      );
      expect(window.hides, 1);
      expect(window.visible, isFalse);
      calls.clear();
      await container
          .read(appSettingsControllerProvider.notifier)
          .setShowTrayIcon(false);
      await tester.pumpAndSettle();
      expect(tray.isAvailable, isFalse);
      expect(window.visible, isTrue);
      expect(window.hideOnClose, isFalse);
      expect(calls.indexOf('show'), lessThan(calls.indexOf('stop')));
      await container
          .read(appSettingsControllerProvider.notifier)
          .setShowTrayIcon(true);
      await tester.pumpAndSettle();
      expect(window.hides, 1);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'launch tray survives unrelated changes until tray preferences change',
    (tester) async {
      final window = _Window();
      final tray = _Tray();
      final container = await _pumpRuntime(
        tester,
        window,
        tray,
        minimized: true,
        showTray: false,
      );
      expect(window.visible, isFalse);
      expect(tray.isAvailable, isTrue);
      final controller = container.read(appSettingsControllerProvider.notifier);
      await controller.setThemeModePreference(BusyMaxThemeModePreference.dark);
      await tester.pumpAndSettle();
      expect(tray.isAvailable, isTrue);
      await controller.setShowTrayIcon(true);
      await tester.pumpAndSettle();
      await controller.setShowTrayIcon(false);
      await tester.pumpAndSettle();
      expect(window.visible, isTrue);
      expect(tray.isAvailable, isFalse);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('tray disabled during delayed startup cannot strand the window', (
    tester,
  ) async {
    final window = _Window();
    final tray = _Tray()..startBarrier = Completer<void>();
    final container = await _pumpRuntime(tester, window, tray, minimized: true);
    await container
        .read(appSettingsControllerProvider.notifier)
        .setShowTrayIcon(false);
    await tester.pump();
    tray.startBarrier!.complete();
    await tester.pumpAndSettle();
    expect(window.visible, isTrue);
    expect(window.hides, 0);
    expect(tray.isAvailable, isFalse);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('failed tray startup leaves a minimized launch visible', (
    tester,
  ) async {
    final window = _Window();
    final tray = _Tray()..canStart = false;
    await _pumpRuntime(tester, window, tray, minimized: true);
    expect(window.visible, isTrue);
    expect(window.hides, 0);
    expect(window.hideOnClose, isFalse);
    await tester.pumpWidget(const SizedBox());
  });
}

Future<ProviderContainer> _pumpRuntime(
  WidgetTester tester,
  _Window window,
  _Tray tray, {
  bool minimized = false,
  bool showTray = true,
}) async {
  final settings = AppSettings.defaults().copyWith(
    showTrayIcon: showTray,
    runInBackgroundWhenClosed: showTray,
  );
  final container = ProviderContainer(
    overrides: [
      localSettingsStoreProvider.overrideWithValue(
        MemorySettingsStore(settings.toJson()),
      ),
      desktopWindowServiceProvider.overrideWithValue(window),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: FluentApp(
        localizationsDelegates: const [AppLocalizations.delegate],
        supportedLocales: AppLocalizations.supportedLocales,
        home: WindowsDesktopRuntime(
          startMinimizedAtLaunch: minimized,
          trayService: tray,
          child: const SizedBox(),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

class _Window implements DesktopWindowService {
  _Window({List<String>? calls}) : calls = calls ?? [];
  final List<String> calls;
  bool visible = true;
  bool hideOnClose = false;
  int hides = 0;
  @override
  Future<void> hideWindow() async {
    visible = false;
    hides++;
  }

  @override
  Future<void> showWindow() async {
    visible = true;
    calls.add('show');
  }

  @override
  Future<bool> isWindowVisible() async => visible;
  @override
  Future<void> setHideOnClose(bool enabled) async {
    hideOnClose = enabled;
  }

  @override
  Future<void> quitApp() async {}
}

class _Tray implements DesktopTrayService {
  _Tray({List<String>? calls}) : calls = calls ?? [];
  final List<String> calls;
  bool canStart = true;
  Completer<void>? startBarrier;
  @override
  bool isAvailable = false;
  @override
  Future<bool> start() async {
    await startBarrier?.future;
    return isAvailable = canStart;
  }

  @override
  Future<void> refresh() async {}
  @override
  Future<void> stop() async {
    calls.add('stop');
    isAvailable = false;
  }
}

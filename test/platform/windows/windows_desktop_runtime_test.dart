import 'dart:async';

import 'package:busymax/l10n/generated/app_localizations.dart';
import 'package:busymax/src/app/app_bootstrap.dart';
import 'package:busymax/src/platform/common/desktop_services.dart';
import 'package:busymax/src/ui/windows/windows_desktop_runtime.dart';
import 'package:busymax/src/l10n/time_format_scope.dart';
import 'package:busymax/src/features/tray/domain/tray_presentation.dart';
import 'package:busymax/src/features/connectivity/network_connectivity_service.dart';
import 'package:busymax/src/features/accounts/data/accounts_repository.dart';
import 'package:busymax/src/features/sync/all_accounts_sync_scheduler.dart';
import 'package:busymax/src/platform/windows/windows_tray_service.dart';
import 'package:busymax/src/providers/busy_provider.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/memory_settings_store.dart';

void main() {
  testWidgets(
    'unchanged locale and changed clock immediately refresh actual tray labels',
    (tester) async {
      final window = _Window();
      final tray = _FormattingTray();
      final container = ProviderContainer(
        overrides: [
          localSettingsStoreProvider.overrideWithValue(MemorySettingsStore()),
          desktopWindowServiceProvider.overrideWithValue(window),
        ],
      );
      addTearDown(container.dispose);
      final controller = container.read(appSettingsControllerProvider.notifier);
      await controller.setTimeFormatPreference(
        BusyMaxTimeFormatPreference.twelveHour,
      );
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: FluentApp(
            locale: const Locale('en'),
            localizationsDelegates: const [AppLocalizations.delegate],
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (context, child) => Consumer(
              builder: (context, ref, _) => BusyMaxTimeFormatScope(
                formatter: BusyMaxTimeFormatter(
                  locale: 'en',
                  use24Hour: resolveBusyMax24HourClock(
                    ref
                        .watch(appSettingsControllerProvider)
                        .timeFormatPreference,
                    systemUses24Hour: false,
                  ),
                ),
                child: child!,
              ),
            ),
            home: WindowsDesktopRuntime(
              startMinimizedAtLaunch: false,
              trayServiceFactory: (loader) {
                tray.loader = loader;
                return tray;
              },
              loadPresentation: () async => BusyMaxTrayPresentation(
                connectivity: NetworkAvailability.online,
                synchronizationRunning: false,
                lastSuccessfulSynchronizationUtc: null,
                incompleteTasksDueToday: 0,
                canCreateEvent: true,
                canCreateTask: true,
                hasSyncEligibleAccount: true,
                notificationDetailLevel: NotificationDetailLevel.normal,
                localNow: DateTime(2026, 9, 13),
                events: [
                  BusyMaxTrayEventEntry(
                    eventId: 'event',
                    accountId: 'account',
                    calendarSourceId: 'calendar',
                    title: 'Meeting',
                    start: DateTime(2026, 9, 13, 14, 30),
                    end: null,
                    allDay: false,
                  ),
                ],
              ),
              child: const SizedBox(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tray.labels.last, '2:30 PM · Meeting');
      final before = tray.labels.length;
      await controller.setTimeFormatPreference(
        BusyMaxTimeFormatPreference.twentyFourHour,
      );
      await tester.pumpAndSettle();
      expect(tray.labels.length, greaterThan(before));
      expect(tray.labels.last, '14:30 · Meeting');
      await controller.setTimeFormatPreference(
        BusyMaxTimeFormatPreference.twelveHour,
      );
      await tester.pumpAndSettle();
      expect(tray.labels.last, '2:30 PM · Meeting');
      await tester.pumpWidget(const SizedBox());
    },
  );
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

  testWidgets('tray sync continues after an account failure and refreshes', (
    tester,
  ) async {
    final synced = <String>[];
    final failures = <Object>[];
    final failure = StateError('first account failed');
    final scheduler = AllAccountsSyncScheduler(
      listSyncEligibleAccounts: () async => [_account('a'), _account('b')],
      syncAccount: (accountId) async {
        synced.add(accountId);
        if (accountId == 'a') throw failure;
      },
      onSyncFailure: (error) async => failures.add(error),
      interval: Duration.zero,
    );
    addTearDown(scheduler.dispose);
    final tray = _Tray();
    await _pumpRuntime(
      tester,
      _Window(),
      tray,
      syncScheduler: scheduler,
      interactiveRunner: () async =>
          throw StateError('interactive runner used'),
    );
    final beforeRefresh = tray.refreshes;

    await tester
        .state<WindowsDesktopRuntimeState>(find.byType(WindowsDesktopRuntime))
        .handleTrayCommand(WindowsTrayCommand.synchronize);

    expect(synced, ['a', 'b']);
    expect(failures, [same(failure)]);
    expect(tray.refreshes, beforeRefresh + 1);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}

Future<ProviderContainer> _pumpRuntime(
  WidgetTester tester,
  _Window window,
  _Tray tray, {
  bool minimized = false,
  bool showTray = true,
  AllAccountsSyncScheduler? syncScheduler,
  Future<void> Function()? interactiveRunner,
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
      if (syncScheduler != null)
        syncSchedulerProvider.overrideWithValue(syncScheduler),
      if (interactiveRunner != null)
        allAccountsSyncRunnerProvider.overrideWithValue(interactiveRunner),
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

class _FormattingTray extends _Tray {
  late Future<BusyMaxTrayMenuPresentation> Function() loader;
  final labels = <String>[];
  @override
  Future<void> refresh() async =>
      labels.add((await loader()).eventRows.single.label);
}

class _Tray implements DesktopTrayService {
  _Tray({List<String>? calls}) : calls = calls ?? [];
  final List<String> calls;
  bool canStart = true;
  Completer<void>? startBarrier;
  int refreshes = 0;
  @override
  bool isAvailable = false;
  @override
  Future<bool> start() async {
    await startBarrier?.future;
    return isAvailable = canStart;
  }

  @override
  Future<void> refresh() async {
    refreshes++;
  }

  @override
  Future<void> stop() async {
    calls.add('stop');
    isAvailable = false;
  }
}

AccountEntity _account(String id) => AccountEntity(
  id: id,
  provider: BusyProvider.google,
  authority: 'https://accounts.google.com',
  providerAccountId: id,
  authState: accountAuthStateSignedIn,
);

import 'dart:async';
import 'dart:ui' show ViewFocusEvent, ViewFocusState, ViewFocusDirection;

import 'package:busymax/l10n/generated/app_localizations.dart';
import 'package:busymax/src/app/app_bootstrap.dart';
import 'package:busymax/src/platform/common/desktop_services.dart';
import 'package:busymax/src/ui/windows/windows_settings_page.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_autostart_service.dart';
import '../../support/memory_settings_store.dart';

void main() {
  testWidgets('Windows Settings reports unsaved preferences and retries', (
    tester,
  ) async {
    final store = FailingMemorySettingsStore();
    final container = _container(FakeAutostartService(), settingsStore: store);
    addTearDown(container.dispose);
    await _pumpSettings(tester, container);
    final trayToggle = find
        .byWidgetPredicate((widget) => widget is ToggleSwitch && widget.checked)
        .first;
    await tester.ensureVisible(trayToggle);
    await tester.tap(trayToggle);
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Could not save settings. Your changes may be lost when BusyMax restarts.',
      ),
      findsOneWidget,
    );
    expect(container.read(appSettingsPersistenceFailedProvider), isTrue);
    store.failSaves = false;
    await tester.ensureVisible(find.text('Retry'));
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(container.read(appSettingsPersistenceFailedProvider), isFalse);
    expect(store.value['runInBackgroundWhenClosed'], isFalse);
  });

  for (final state in DesktopAutostartState.values) {
    testWidgets('Windows Settings presents ${state.name} accurately', (
      tester,
    ) async {
      final service = FakeAutostartService()..current = state;
      final container = _container(service);
      addTearDown(container.dispose);
      await _pumpSettings(tester, container);
      final toggle = tester.widget<ToggleSwitch>(_switch);
      expect(toggle.checked, state.isEnabled);
      expect(toggle.onChanged == null, !state.canChange);
      if (state == DesktopAutostartState.enabledByPolicy) {
        expect(
          find.text(
            'Startup is enabled by your administrator and cannot be changed here.',
          ),
          findsOneWidget,
        );
        expect(
          await container.read(launchAtLoginEnabledProvider.future),
          isTrue,
        );
      }
    });
  }

  testWidgets(
    'Windows Settings refreshes disabledByUser after external change',
    (tester) async {
      final service = FakeAutostartService()
        ..current = DesktopAutostartState.disabledByUser;
      final container = _container(service);
      addTearDown(container.dispose);
      await _pumpSettings(tester, container);
      expect(tester.widget<ToggleSwitch>(_switch).onChanged, isNull);
      service.current = DesktopAutostartState.enabled;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(tester.widget<ToggleSwitch>(_switch).checked, isTrue);
      expect(tester.widget<ToggleSwitch>(_switch).onChanged, isNotNull);
      service.current = DesktopAutostartState.disabled;
      tester.binding.handleViewFocusChanged(
        ViewFocusEvent(
          viewId: tester.view.viewId,
          state: ViewFocusState.focused,
          direction: ViewFocusDirection.undefined,
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.widget<ToggleSwitch>(_switch).checked, isFalse);
      await tester.pumpWidget(const SizedBox());
      service.current = DesktopAutostartState.enabled;
      await _pumpSettings(tester, container);
      expect(tester.widget<ToggleSwitch>(_switch).checked, isTrue);
    },
  );

  testWidgets(
    'Windows startup toggle blocks overlapping writes and refreshes both ways',
    (tester) async {
      final service = FakeAutostartService();
      final container = _container(service);
      addTearDown(container.dispose);
      await _pumpSettings(tester, container);
      service.writeBarrier = Completer<void>();
      await tester.ensureVisible(_switch);
      await tester.tap(_switch);
      await tester.tap(_switch);
      await tester.pump();
      expect(service.writes, [true]);
      expect(find.byType(ProgressRing), findsWidgets);
      service.writeBarrier!.complete();
      await tester.pumpAndSettle();
      expect(tester.widget<ToggleSwitch>(_switch).checked, isTrue);
      await tester.tap(_switch);
      await tester.pumpAndSettle();
      expect(tester.widget<ToggleSwitch>(_switch).checked, isFalse);
      expect(service.writes, [true, false]);
    },
  );

  testWidgets('Windows startup read failure offers retry', (tester) async {
    final service = FakeAutostartService()
      ..readError = StateError('read failed');
    final container = _container(service);
    addTearDown(container.dispose);
    await _pumpSettings(tester, container);
    expect(
      find.text('Could not determine the launch-at-login state.'),
      findsOneWidget,
    );
    expect(_switch, findsNothing);
    service.readError = null;
    await tester.ensureVisible(find.text('Retry'));
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(tester.widget<ToggleSwitch>(_switch).onChanged, isNotNull);
  });
}

final _switch = find.byKey(const ValueKey('launch-at-login-switch'));

ProviderContainer _container(
  FakeAutostartService service, {
  LocalSettingsStore? settingsStore,
}) => ProviderContainer(
  overrides: [
    desktopAutostartServiceProvider.overrideWithValue(service),
    localSettingsStoreProvider.overrideWithValue(
      settingsStore ?? MemorySettingsStore(),
    ),
    accountManagementStreamProvider.overrideWith(
      (ref) => Stream.value(const []),
    ),
    calendarSourcesStreamProvider.overrideWith((ref) => Stream.value(const [])),
    webCalSubscriptionsProvider.overrideWith((ref) => Stream.value(const [])),
  ],
);

Future<void> _pumpSettings(
  WidgetTester tester,
  ProviderContainer container,
) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(1200, 1200);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const FluentApp(
        localizationsDelegates: [AppLocalizations.delegate],
        supportedLocales: AppLocalizations.supportedLocales,
        home: WindowsSettingsPage(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

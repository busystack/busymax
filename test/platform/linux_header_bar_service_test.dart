import 'dart:async';
import 'dart:io';

import 'package:busymax/src/platform/linux_header_bar_service.dart';
import 'package:busymax/src/schedule/schedule_view_mode.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _scheduleHeaderState = BusyMaxHeaderBarState(
  title: 'July 2026',
  viewMode: ScheduleViewMode.month,
  canRefresh: true,
  canCreate: true,
  searchActive: false,
  canShowSidebar: true,
  sidebarVisible: true,
  navigationVisible: true,
  scheduleControlsVisible: true,
  backVisible: false,
);

const _settingsHeaderState = BusyMaxHeaderBarState(
  title: 'Settings',
  viewMode: ScheduleViewMode.month,
  canRefresh: false,
  canCreate: false,
  searchActive: false,
  canShowSidebar: true,
  sidebarVisible: true,
  navigationVisible: false,
  scheduleControlsVisible: false,
  backVisible: true,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('sends application-wide state to the native headerbar', () async {
    const channel = MethodChannel('busymax_test/headerbar_updates');
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          if (call.method == 'initialize') {
            return true;
          }
          return null;
        });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    final service = LinuxHeaderBarService(channel: channel, isLinux: true);
    addTearDown(service.dispose);
    final session = service.claimSession();
    addTearDown(session.dispose);

    await service.initialize();
    await service.setLocalizedLabels(
      const BusyMaxHeaderBarLabels(
        today: 'Today',
        day: 'Day',
        week: 'Week',
        month: 'Month',
        year: 'Year',
        agenda: 'Agenda',
        search: 'Search',
        create: 'Create',
        refresh: 'Refresh',
        menu: 'Menu',
        previous: 'Previous',
        next: 'Next',
        sidebar: 'Toggle Sidebar',
        back: 'Back',
        settings: 'Settings',
        keyboardShortcuts: 'Keyboard Shortcuts',
        aboutBusyMax: 'About BusyMax',
      ),
    );
    await service.setSidebarWidth(300);
    await session.setOnboardingControls(
      visible: true,
      canGoBack: false,
      canContinue: true,
      backLabel: 'Back',
      continueLabel: 'Continue',
    );
    await service.setModalBarrierVisible(true);
    await service.setTheme(
      const BusyMaxHeaderBarTheme(
        preferDark: true,
        windowBackgroundColor: Color(0xFF18181B),
        backgroundColor: Color(0xFF1D1D20),
        sidebarBackgroundColor: Color(0xFF2E2E32),
        foregroundColor: Color(0xFFFFFFFF),
        mutedForegroundColor: Color.fromRGBO(255, 255, 255, 0.70),
        disabledForegroundColor: Color.fromRGBO(255, 255, 255, 0.38),
        controlColor: Color.fromRGBO(255, 255, 255, 0.10),
        controlHoverColor: Color.fromRGBO(255, 255, 255, 0.14),
        controlActiveColor: Color.fromRGBO(255, 255, 255, 0.18),
        accentColor: Color(0xFF2E7D32),
        accentForegroundColor: Color(0xFFFFFFFF),
        popoverBackgroundColor: Color(0xFF36363A),
        borderColor: Color.fromRGBO(0, 0, 6, 0.75),
        shadeColor: Color.fromRGBO(0, 0, 6, 0.25),
        modalBarrierColor: Color.fromRGBO(0, 0, 0, 0.32),
      ),
    );

    expect(service.isAvailable, isTrue);
    expect(
      calls.map((call) => call.method),
      containsAllInOrder([
        'initialize',
        'setLocalizedLabels',
        'setSidebarWidth',
        'setOnboardingControls',
        'setModalBarrierVisible',
        'setTheme',
      ]),
    );
    expect(calls[1].arguments, containsPair('today', 'Today'));
    expect(calls[1].arguments, containsPair('year', 'Year'));
    expect(calls[1].arguments, containsPair('create', 'Create'));
    expect(calls[1].arguments, containsPair('menu', 'Menu'));
    expect(calls[1].arguments, containsPair('sidebar', 'Toggle Sidebar'));
    expect(calls[1].arguments, containsPair('back', 'Back'));
    expect(calls[1].arguments, containsPair('settings', 'Settings'));
    expect(
      calls[1].arguments,
      containsPair('keyboardShortcuts', 'Keyboard Shortcuts'),
    );
    expect(calls[1].arguments, containsPair('aboutBusyMax', 'About BusyMax'));
    expect(calls[2].arguments, 300);
    expect(calls[3].arguments, containsPair('visible', true));
    expect(calls[3].arguments, containsPair('canContinue', true));
    expect(calls[3].arguments, containsPair('continueLabel', 'Continue'));
    expect(calls.last.arguments, containsPair('preferDark', true));
    expect(calls.last.arguments, containsPair('backgroundColor', '#1D1D20'));
    expect(
      calls.last.arguments,
      containsPair('windowBackgroundColor', '#18181B'),
    );
    expect(
      calls.last.arguments,
      containsPair('sidebarBackgroundColor', '#2E2E32'),
    );
    expect(
      calls.last.arguments,
      containsPair('controlHoverColor', 'rgba(255,255,255,0.14)'),
    );
    expect(
      calls.last.arguments,
      containsPair('controlActiveColor', 'rgba(255,255,255,0.18)'),
    );
    expect(calls.last.arguments, containsPair('accentColor', '#2E7D32'));
    expect(
      calls.last.arguments,
      containsPair('accentForegroundColor', '#FFFFFF'),
    );
  });

  test('serializes CSS colors for native headerbar', () {
    expect(busyMaxCssColor(const Color(0xFF1D1D20)), '#1D1D20');
    expect(
      busyMaxCssColor(const Color.fromRGBO(255, 255, 255, 0.08)),
      'rgba(255,255,255,0.08)',
    );
    expect(
      busyMaxCssColor(const Color.fromRGBO(0, 0, 6, 0.38)),
      'rgba(0,0,6,0.38)',
    );
  });

  test(
    'sends complete header state atomically and diffs equal state',
    () async {
      const channel = MethodChannel('busymax_test/headerbar_atomic_state');
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            return call.method == 'initialize' ? true : null;
          });
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null);
      });

      final service = LinuxHeaderBarService(channel: channel, isLinux: true);
      addTearDown(service.dispose);
      final session = service.claimSession();
      addTearDown(session.dispose);
      const state = BusyMaxHeaderBarState(
        title: 'July 2026',
        viewMode: ScheduleViewMode.month,
        canRefresh: true,
        canCreate: false,
        searchActive: true,
        canShowSidebar: false,
        sidebarVisible: false,
        navigationVisible: true,
        scheduleControlsVisible: true,
        backVisible: false,
      );

      await service.initialize();
      await session.updateState(state);
      await session.updateState(state.copyWith());
      await session.updateState(state.copyWith(title: 'August 2026'));

      expect(calls.map((call) => call.method), [
        'initialize',
        'setState',
        'setState',
      ]);
      expect(calls[1].arguments, <String, Object>{
        'schemaVersion': BusyMaxHeaderBarState.schemaVersion,
        'title': 'July 2026',
        'viewMode': 'month',
        'canRefresh': true,
        'canCreate': false,
        'searchActive': true,
        'canShowSidebar': false,
        'sidebarVisible': false,
        'navigationVisible': true,
        'scheduleControlsVisible': true,
        'backVisible': false,
      });
      expect(calls[2].arguments, containsPair('title', 'August 2026'));
    },
  );

  test('shares in-flight initialization before applying state', () async {
    const channel = MethodChannel('busymax_test/headerbar_shared_initialize');
    final calls = <MethodCall>[];
    final initialization = Completer<bool>();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          if (call.method == 'initialize') {
            return initialization.future;
          }
          return null;
        });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    final service = LinuxHeaderBarService(channel: channel, isLinux: true);
    addTearDown(service.dispose);
    final session = service.claimSession();
    addTearDown(session.dispose);

    final firstInitialization = service.initialize();
    final stateUpdate = session.updateState(_settingsHeaderState);
    await pumpEventQueue(times: 1);

    expect(calls.where((call) => call.method == 'initialize'), hasLength(1));
    expect(calls.where((call) => call.method == 'setState'), isEmpty);

    initialization.complete(true);
    await Future.wait([firstInitialization, stateUpdate]);

    expect(calls.where((call) => call.method == 'setState'), hasLength(1));
    expect(service.isAvailable, isTrue);
  });

  test('only the active route session can publish header state', () async {
    const channel = MethodChannel('busymax_test/headerbar_route_ownership');
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return call.method == 'initialize' ? true : null;
        });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    final service = LinuxHeaderBarService(channel: channel, isLinux: true);
    addTearDown(service.dispose);
    final scheduleSession = service.claimSession();
    addTearDown(scheduleSession.dispose);
    await scheduleSession.updateState(_scheduleHeaderState);

    final settingsSession = service.claimSession();
    addTearDown(settingsSession.dispose);
    await settingsSession.updateState(_settingsHeaderState);

    await scheduleSession.updateState(
      _scheduleHeaderState.copyWith(title: 'Stale schedule update'),
      force: true,
    );
    scheduleSession.dispose();
    await settingsSession.updateState(_settingsHeaderState.copyWith());
    await settingsSession.updateState(
      _settingsHeaderState.copyWith(title: 'Preferences'),
    );

    final stateCalls = calls
        .where((call) => call.method == 'setState')
        .toList();
    expect(stateCalls, hasLength(3));
    expect(stateCalls[0].arguments, containsPair('title', 'July 2026'));
    expect(stateCalls[1].arguments, containsPair('title', 'Settings'));
    expect(stateCalls[2].arguments, containsPair('title', 'Preferences'));
    expect(
      stateCalls.skip(1).map((call) => call.arguments),
      everyElement(containsPair('backVisible', true)),
    );
  });

  test('closing the active session restores the covered route', () async {
    const channel = MethodChannel('busymax_test/headerbar_route_restore');
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return call.method == 'initialize' ? true : null;
        });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    final service = LinuxHeaderBarService(channel: channel, isLinux: true);
    addTearDown(service.dispose);
    final scheduleSession = service.claimSession();
    addTearDown(scheduleSession.dispose);
    await scheduleSession.updateState(_scheduleHeaderState);

    final settingsSession = service.claimSession();
    addTearDown(settingsSession.dispose);
    await settingsSession.updateState(_settingsHeaderState);
    await scheduleSession.updateState(
      _scheduleHeaderState.copyWith(title: 'Updated schedule'),
    );

    expect(scheduleSession.isAvailable, isTrue);
    settingsSession.dispose();
    await pumpEventQueue();

    final stateCalls = calls
        .where((call) => call.method == 'setState')
        .toList();
    expect(stateCalls, hasLength(3));
    expect(
      stateCalls.last.arguments,
      containsPair('title', 'Updated schedule'),
    );
    expect(stateCalls.last.arguments, containsPair('backVisible', false));
    expect(
      stateCalls.last.arguments,
      containsPair('scheduleControlsVisible', true),
    );
  });

  test('native actions belong exclusively to the active session', () async {
    final service = LinuxHeaderBarService(
      channel: const MethodChannel('busymax_test/headerbar_owned_actions'),
      isLinux: false,
    );
    addTearDown(service.dispose);
    final scheduleSession = service.claimSession();
    addTearDown(scheduleSession.dispose);
    final scheduleActions = <BusyMaxHeaderBarAction>[];
    final scheduleSubscription = scheduleSession.actions.listen(
      scheduleActions.add,
    );
    addTearDown(scheduleSubscription.cancel);

    final settingsSession = service.claimSession();
    addTearDown(settingsSession.dispose);
    final settingsActions = <BusyMaxHeaderBarAction>[];
    final settingsSubscription = settingsSession.actions.listen(
      settingsActions.add,
    );
    addTearDown(settingsSubscription.cancel);

    await service.handleNativeMethodCall(const MethodCall('aboutBusyMax'));
    await pumpEventQueue();

    expect(scheduleActions, isEmpty);
    expect(settingsActions, [BusyMaxHeaderBarAction.aboutBusyMax]);

    settingsSession.dispose();
    await service.handleNativeMethodCall(const MethodCall('back'));
    await pumpEventQueue();

    expect(scheduleActions, [BusyMaxHeaderBarAction.back]);
    expect(settingsActions, [BusyMaxHeaderBarAction.aboutBusyMax]);
  });

  test('native header controls keep visible keyboard focus indicators', () {
    final source = File('linux/runner/my_application.cc').readAsStringSync();

    expect(source, contains('button.busymax-header-view-mode-button:focus {"'));
    expect(source, contains('button.busymax-header-popover-row:focus {"'));
    expect(source, contains('"box-shadow: inset 0 0 0 2px %s;"'));
  });

  test('native sidebar availability is separate from expanded state', () {
    final source = File('linux/runner/my_application.cc').readAsStringSync();

    expect(source, contains('gboolean header_bar_can_show_sidebar;'));
    expect(source, contains('"canShowSidebar"'));
    expect(
      source,
      contains(
        'schedule_controls_visible &&\n'
        '                         self->header_bar_can_show_sidebar',
      ),
    );
    expect(source, contains('strcmp(method, "setState") == 0'));
  });

  test('native headerbar methods emit Dart actions', () async {
    final service = LinuxHeaderBarService(
      channel: const MethodChannel('busymax_test/headerbar_actions'),
      isLinux: false,
    );
    addTearDown(service.dispose);
    final session = service.claimSession();
    addTearDown(session.dispose);

    final nextAction = session.actions.take(5).toList();
    await service.handleNativeMethodCall(const MethodCall('create'));
    await service.handleNativeMethodCall(const MethodCall('continueSetup'));
    await service.handleNativeMethodCall(const MethodCall('settings'));
    await service.handleNativeMethodCall(const MethodCall('keyboardShortcuts'));
    await service.handleNativeMethodCall(const MethodCall('aboutBusyMax'));

    expect(await nextAction, [
      BusyMaxHeaderBarAction.create,
      BusyMaxHeaderBarAction.continueSetup,
      BusyMaxHeaderBarAction.settings,
      BusyMaxHeaderBarAction.keyboardShortcuts,
      BusyMaxHeaderBarAction.aboutBusyMax,
    ]);
  });

  test(
    'can force native onboarding controls cleanup past cached state',
    () async {
      const channel = MethodChannel('busymax_test/headerbar_onboarding_force');
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            if (call.method == 'initialize') {
              return true;
            }
            return null;
          });
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null);
      });

      final service = LinuxHeaderBarService(channel: channel, isLinux: true);
      addTearDown(service.dispose);
      final session = service.claimSession();
      addTearDown(session.dispose);

      await service.initialize();
      await session.setOnboardingControls(
        visible: false,
        canGoBack: false,
        canContinue: false,
        backLabel: '',
        continueLabel: '',
      );
      await session.setOnboardingControls(
        visible: false,
        canGoBack: false,
        canContinue: false,
        backLabel: '',
        continueLabel: '',
      );
      await session.setOnboardingControls(
        visible: false,
        canGoBack: false,
        canContinue: false,
        backLabel: '',
        continueLabel: '',
        force: true,
      );

      final onboardingCalls = calls
          .where((call) => call.method == 'setOnboardingControls')
          .toList();
      expect(onboardingCalls, hasLength(2));
      expect(onboardingCalls.last.arguments, containsPair('visible', false));
    },
  );

  test('missing native channel disables service without throwing', () async {
    final service = LinuxHeaderBarService(
      channel: const MethodChannel('busymax_test/headerbar_missing'),
      isLinux: true,
    );
    addTearDown(service.dispose);

    await service.initialize();

    expect(service.isAvailable, isFalse);
  });
}

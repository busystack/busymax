import 'dart:io';

import 'package:busymax/src/platform/linux_header_bar_service.dart';
import 'package:busymax/src/schedule/schedule_view_mode.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('sends schedule range and state updates to native headerbar', () async {
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

    await service.initialize();
    await service.setTitleRange('Jun 7-13, 2026');
    await service.setViewMode(ScheduleViewMode.week);
    await service.setCanRefresh(true);
    await service.setCanCreate(true);
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
    await service.setSearchActive(false);
    await service.setSidebarVisible(true);
    await service.setNavigationVisible(false);
    await service.setBackVisible(false);
    await service.setOnboardingControls(
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
        'setTitleRange',
        'setViewMode',
        'setCanRefresh',
        'setCanCreate',
        'setLocalizedLabels',
        'setSidebarWidth',
        'setSearchActive',
        'setSidebarVisible',
        'setNavigationVisible',
        'setBackVisible',
        'setOnboardingControls',
        'setModalBarrierVisible',
        'setTheme',
      ]),
    );
    expect(calls[1].arguments, 'Jun 7-13, 2026');
    expect(calls[2].arguments, 'week');
    expect(calls[5].arguments, containsPair('today', 'Today'));
    expect(calls[5].arguments, containsPair('year', 'Year'));
    expect(calls[5].arguments, containsPair('create', 'Create'));
    expect(calls[5].arguments, containsPair('menu', 'Menu'));
    expect(calls[5].arguments, containsPair('sidebar', 'Toggle Sidebar'));
    expect(calls[5].arguments, containsPair('back', 'Back'));
    expect(calls[5].arguments, containsPair('settings', 'Settings'));
    expect(
      calls[5].arguments,
      containsPair('keyboardShortcuts', 'Keyboard Shortcuts'),
    );
    expect(calls[5].arguments, containsPair('aboutBusyMax', 'About BusyMax'));
    expect(calls[6].arguments, 300);
    expect(calls[9].arguments, false);
    expect(calls[11].arguments, containsPair('visible', true));
    expect(calls[11].arguments, containsPair('canContinue', true));
    expect(calls[11].arguments, containsPair('continueLabel', 'Continue'));
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
      await service.updateState(state);
      await service.updateState(state.copyWith());
      await service.updateState(state.copyWith(title: 'August 2026'));

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

  test('legacy changes invalidate the cached atomic state', () async {
    const channel = MethodChannel('busymax_test/headerbar_state_compatibility');
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
    const state = BusyMaxHeaderBarState(
      title: 'Schedule',
      viewMode: ScheduleViewMode.week,
      canRefresh: true,
      canCreate: true,
      searchActive: false,
      canShowSidebar: true,
      sidebarVisible: true,
      navigationVisible: true,
      scheduleControlsVisible: true,
      backVisible: false,
    );

    await service.initialize();
    await service.updateState(state);
    await service.setCanShowSidebar(false);
    await service.setSidebarVisible(true);
    await service.updateState(state);

    expect(calls.map((call) => call.method), [
      'initialize',
      'setState',
      'setCanShowSidebar',
      'setSidebarVisible',
      'setState',
    ]);
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

    final nextAction = service.actions.take(5).toList();
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

      await service.initialize();
      await service.setOnboardingControls(
        visible: false,
        canGoBack: false,
        canContinue: false,
        backLabel: '',
        continueLabel: '',
      );
      await service.setOnboardingControls(
        visible: false,
        canGoBack: false,
        canContinue: false,
        backLabel: '',
        continueLabel: '',
      );
      await service.setOnboardingControls(
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
    await service.setTitleRange('Settings');

    expect(service.isAvailable, isFalse);
  });
}

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
  canCreateEvent: true,
  canCreateTask: true,
  searchActive: false,
  searchQuery: '',
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
  canCreateEvent: false,
  canCreateTask: false,
  searchActive: false,
  searchQuery: '',
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
        createEvent: 'Event',
        createTask: 'Task',
        refresh: 'Refresh',
        menu: 'Menu',
        previous: 'Previous',
        next: 'Next',
        sidebar: 'Toggle Sidebar',
        back: 'Back',
        settings: 'Settings',
        keyboardShortcuts: 'Keyboard Shortcuts',
        reportIssue: 'Report an issue',
        aboutBusyMax: 'About BusyMax',
      ),
    );
    await service.setSidebarWidth(300);
    await service.setTextDirection(TextDirection.rtl);
    await session.setOnboardingControls(
      visible: true,
      canGoBack: false,
      canContinue: true,
      backLabel: 'Back',
      continueLabel: 'Continue',
    );
    await service.setModalBarrierDepth(2);
    await service.setTheme(
      const BusyMaxHeaderBarTheme(
        preferDark: true,
        highContrast: false,
        windowBackgroundColor: Color(0xFF18181B),
        backgroundColor: Color(0xFF1D1D20),
        sidebarBackgroundColor: Color(0xFF2E2E32),
        foregroundColor: Color(0xFFFFFFFF),
        sidebarBorderColor: Color.fromRGBO(0, 0, 6, 0.75),
        popoverBackgroundColor: Color(0xFF36363A),
        menuHoverColor: Color.fromRGBO(255, 255, 255, 0.14),
        popoverShadowColor: Color.fromRGBO(0, 0, 0, 0.3),
        dialogBackgroundColor: Color(0xFF36363A),
        dialogOutlineColor: Color.fromRGBO(255, 255, 255, 0.07),
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
        'setTextDirection',
        'setOnboardingControls',
        'setModalBarrierDepth',
        'setTheme',
      ]),
    );
    expect(calls[1].arguments, containsPair('today', 'Today'));
    expect(calls[1].arguments, containsPair('year', 'Year'));
    expect(calls[1].arguments, containsPair('create', 'Create'));
    expect(calls[1].arguments, containsPair('createEvent', 'Event'));
    expect(calls[1].arguments, containsPair('createTask', 'Task'));
    expect(calls[1].arguments, containsPair('menu', 'Menu'));
    expect(calls[1].arguments, containsPair('sidebar', 'Toggle Sidebar'));
    expect(calls[1].arguments, containsPair('back', 'Back'));
    expect(calls[1].arguments, containsPair('settings', 'Settings'));
    expect(
      calls[1].arguments,
      containsPair('keyboardShortcuts', 'Keyboard Shortcuts'),
    );
    expect(calls[1].arguments, containsPair('reportIssue', 'Report an issue'));
    expect(calls[1].arguments, containsPair('aboutBusyMax', 'About BusyMax'));
    expect(calls[2].arguments, 300);
    expect(calls[3].arguments, 'rtl');
    expect(calls[4].arguments, containsPair('visible', true));
    expect(calls[4].arguments, containsPair('canContinue', true));
    expect(calls[4].arguments, containsPair('continueLabel', 'Continue'));
    expect(
      calls[4].arguments,
      containsPair('contentWidth', busyMaxOnboardingContentMaxWidth),
    );
    expect(calls[5].arguments, 2);
    expect(
      calls.last.arguments,
      equals({
        'preferDark': true,
        'highContrast': false,
        'windowBackgroundColor': '#18181B',
        'backgroundColor': '#1D1D20',
        'sidebarBackgroundColor': '#2E2E32',
        'foregroundColor': '#FFFFFF',
        'sidebarBorderColor': 'rgba(0,0,6,0.75)',
        'popoverBackgroundColor': '#36363A',
        'menuHoverColor': 'rgba(255,255,255,0.14)',
        'popoverShadowColor': 'rgba(0,0,0,0.30)',
        'dialogBackgroundColor': '#36363A',
        'dialogOutlineColor': 'rgba(255,255,255,0.07)',
        'modalBarrierColor': 'rgba(0,0,0,0.32)',
      }),
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

  test('native bridge failures degrade without blocking Flutter UI', () async {
    const channel = MethodChannel('busymax_test/headerbar_platform_failure');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'initialize') {
            return true;
          }
          throw PlatformException(code: 'native_failure');
        });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });
    final service = LinuxHeaderBarService(channel: channel, isLinux: true);
    addTearDown(service.dispose);

    await service.initialize();
    expect(service.isAvailable, isTrue);

    await service.setModalBarrierDepth(1);
    expect(service.isAvailable, isFalse);
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
        canCreateEvent: false,
        canCreateTask: true,
        searchActive: true,
        searchQuery: 'planning',
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
        'canCreateEvent': false,
        'canCreateTask': true,
        'searchActive': true,
        'searchQuery': 'planning',
        'canShowSidebar': false,
        'sidebarVisible': false,
        'navigationVisible': true,
        'scheduleControlsVisible': true,
        'backVisible': false,
      });
      expect(calls[2].arguments, containsPair('title', 'August 2026'));
      expect(state.canCreate, isTrue);
      expect(BusyMaxHeaderBarState.schemaVersion, 3);
    },
  );

  test(
    'only the active route session can open the native Create menu',
    () async {
      const channel = MethodChannel('busymax_test/headerbar_create_menu');
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            if (call.method == 'initialize' ||
                call.method == 'showCreateMenu') {
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
      final scheduleSession = service.claimSession();
      addTearDown(scheduleSession.dispose);
      final coveredSession = service.claimSession();
      addTearDown(coveredSession.dispose);

      expect(await scheduleSession.showCreateMenu(), isFalse);
      expect(await coveredSession.showCreateMenu(), isTrue);
      expect(
        calls.where((call) => call.method == 'showCreateMenu'),
        hasLength(1),
      );
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
      _scheduleHeaderState.copyWith(
        title: 'Updated schedule',
        searchActive: true,
        searchQuery: 'meeting',
      ),
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
    expect(stateCalls.last.arguments, containsPair('searchActive', true));
    expect(stateCalls.last.arguments, containsPair('searchQuery', 'meeting'));
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

  test(
    'native search events belong exclusively to the active session',
    () async {
      final service = LinuxHeaderBarService(
        channel: const MethodChannel('busymax_test/headerbar_owned_search'),
        isLinux: false,
      );
      addTearDown(service.dispose);
      final coveredSession = service.claimSession();
      addTearDown(coveredSession.dispose);
      final coveredEvents = <BusyMaxHeaderBarSearchEvent>[];
      final coveredSubscription = coveredSession.searchEvents.listen(
        coveredEvents.add,
      );
      addTearDown(coveredSubscription.cancel);

      final activeSession = service.claimSession();
      addTearDown(activeSession.dispose);
      final activeEvents = <BusyMaxHeaderBarSearchEvent>[];
      final activeSubscription = activeSession.searchEvents.listen(
        activeEvents.add,
      );
      addTearDown(activeSubscription.cancel);

      await service.handleNativeMethodCall(
        const MethodCall('searchQueryChanged', 'planning'),
      );
      await service.handleNativeMethodCall(
        const MethodCall('searchFocusChanged', true),
      );
      await service.handleNativeMethodCall(const MethodCall('searchCleared'));
      await service.handleNativeMethodCall(
        const MethodCall('searchEscapePressed'),
      );
      await service.handleNativeMethodCall(
        const MethodCall('searchQueryChanged', 42),
      );
      await service.handleNativeMethodCall(
        const MethodCall('searchFocusChanged', 'yes'),
      );
      await pumpEventQueue();

      expect(coveredEvents, isEmpty);
      expect(activeEvents, hasLength(4));
      expect(
        (activeEvents[0] as BusyMaxHeaderBarSearchQueryChanged).query,
        'planning',
      );
      expect(
        (activeEvents[1] as BusyMaxHeaderBarSearchFocusChanged).focused,
        isTrue,
      );
      expect(activeEvents[2], isA<BusyMaxHeaderBarSearchCleared>());
      expect(activeEvents[3], isA<BusyMaxHeaderBarSearchEscapePressed>());
    },
  );

  test('only the active route session can focus native search', () async {
    const channel = MethodChannel('busymax_test/headerbar_focus_search');
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          if (call.method == 'initialize' || call.method == 'focusSearch') {
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
    final coveredSession = service.claimSession();
    addTearDown(coveredSession.dispose);
    final activeSession = service.claimSession();
    addTearDown(activeSession.dispose);

    expect(await coveredSession.focusSearch(), isFalse);
    expect(await activeSession.focusSearch(), isTrue);
    expect(calls.where((call) => call.method == 'focusSearch'), hasLength(1));
  });

  test('native search uses responsive GTK geometry with a scoped Yaru shim', () {
    final source = File('linux/runner/my_application.cc').readAsStringSync();
    final geometryCssStart = source.indexOf(
      'g_autofree gchar* native_search_geometry_css =',
    );
    final geometryCssEnd = source.indexOf(
      'g_autofree gchar* native_menu_state_css =',
      geometryCssStart,
    );

    expect(source, contains('gtk_search_entry_new()'));
    expect(
      source,
      contains(
        'gtk_widget_set_halign(self->header_title_box, GTK_ALIGN_FILL);',
      ),
    );
    expect(
      source,
      contains(
        'gtk_stack_set_hhomogeneous(GTK_STACK(self->header_title_stack), FALSE)',
      ),
    );
    expect(
      source,
      contains('gtk_entry_set_max_width_chars(GTK_ENTRY(self->search_entry),'),
    );
    expect(
      source,
      contains('gtk_widget_set_halign(self->search_entry, GTK_ALIGN_FILL);'),
    );
    expect(
      source,
      contains('gtk_widget_set_hexpand(self->search_entry, TRUE);'),
    );
    expect(
      source,
      isNot(contains('gtk_widget_set_size_request(self->search_entry')),
    );
    expect(source, contains('"busymax-header-search-entry"'));
    expect(
      source,
      contains(
        'gtk_style_context_add_class(gtk_widget_get_style_context(self->search_entry),',
      ),
    );
    expect(source, contains('kHeaderSearchEntryStyleClass'));

    expect(geometryCssStart, isNonNegative);
    expect(geometryCssEnd, greaterThan(geometryCssStart));
    final geometryCss = source.substring(geometryCssStart, geometryCssEnd);
    expect(geometryCss, contains('use_legacy_yaru_compatibility'));
    expect(geometryCss, contains('"entry.search.%s {"'));
    expect(geometryCss, contains('"border-radius: 9px;"'));
    expect(geometryCss, contains('kHeaderSearchEntryStyleClass'));
    expect(geometryCss, isNot(contains('background')));
    expect(geometryCss, isNot(contains('border-color')));
    expect(geometryCss, isNot(contains('"border:')));
    expect(geometryCss, isNot(contains('box-shadow')));
    expect(geometryCss, isNot(contains('padding')));
    expect(geometryCss, isNot(contains('min-height')));
    expect(geometryCss, isNot(contains('#')));
    expect(geometryCss, isNot(contains('rgba(')));
    expect(
      source,
      contains(
        'const gboolean use_legacy_yaru_compatibility =\n'
        '      !self->header_bar_high_contrast &&',
      ),
    );
  });

  test('focused native search text wins delayed Dart snapshots', () {
    final source = File('linux/runner/my_application.cc').readAsStringSync();
    final stateSetter = RegExp(
      r'static void set_header_search_state[\s\S]*?'
      r'(?=^static void set_header_view_mode)',
      multiLine: true,
    ).firstMatch(source)?.group(0);

    expect(source, contains('enum class HeaderSearchQueryUpdateDisposition'));
    expect(
      source,
      contains('resolve_header_search_query_update(false, true, true)'),
    );
    expect(
      source,
      contains('resolve_header_search_query_update(false, true, false)'),
    );
    expect(
      source,
      contains('HeaderSearchQueryUpdateDisposition::kPreserveNativeText'),
    );
    expect(
      source,
      contains(
        'A newer focused native edit must survive a delayed Dart snapshot',
      ),
    );
    expect(source, contains('native_entry_has_authority'));
    expect(source, isNot(contains('echoes_last_native_query')));

    expect(stateSetter, isNotNull);
    final queryOffset = stateSetter!.indexOf(
      'set_header_search_query(self, query, effective_active);',
    );
    final activationOffset = stateSetter.indexOf(
      'self->header_search_active = effective_active;',
    );
    expect(queryOffset, isNonNegative);
    expect(activationOffset, greaterThan(queryOffset));
  });

  test('native header menus delegate row focus modality to GTK', () {
    final source = File('linux/runner/my_application.cc').readAsStringSync();

    expect(source, contains('gtk_menu_button_new()'));
    expect(source, contains('gtk_menu_button_set_menu_model'));
    expect(source, contains('g_menu_item_set_action_and_target'));
    expect(source, contains('g_simple_action_new_stateful'));
    expect(source, contains('GTK_STYLE_CLASS_FLAT'));
    expect(source, isNot(contains('GTK_STYLE_CLASS_SUGGESTED_ACTION')));
    expect(source, contains('kHeaderOnboardingTextButtonStyleClass'));
    expect(
      source,
      isNot(contains('button.busymax-header-view-mode-button:focus {"')),
    );
    expect(source, isNot(contains('"box-shadow: inset 0 0 0 2px %s;"')));
    expect(source, isNot(contains('outline-style: none')));
    expect(source, isNot(contains('transition: none')));
    expect(source, isNot(contains('popover.busymax-header-popover')));
    expect(source, contains('kNativePopoverStyleClass'));
    expect(source, contains('style_header_menu_popover(GTK_WIDGET(popover))'));
    expect(source, isNot(contains('tooltip.background')));
    expect(source, isNot(contains('button.busymax-header-popover-row')));
    expect(source, isNot(contains('busymax-keyboard-focus')));
    expect(source, isNot(contains('gtk_window_get_focus_visible')));
    expect(source, isNot(contains('configure_header_popover_row')));
    expect(source, isNot(contains('header_popover_row_key_press_cb')));
    expect(source, isNot(contains('header_popover_row_button_press_cb')));
    expect(source, isNot(contains('gtk_widget_set_can_focus(row, FALSE)')));
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

    final nextAction = session.actions.take(7).toList();
    await service.handleNativeMethodCall(const MethodCall('createEvent'));
    await service.handleNativeMethodCall(const MethodCall('createTask'));
    await service.handleNativeMethodCall(const MethodCall('continueSetup'));
    await service.handleNativeMethodCall(const MethodCall('settings'));
    await service.handleNativeMethodCall(const MethodCall('keyboardShortcuts'));
    await service.handleNativeMethodCall(const MethodCall('reportIssue'));
    await service.handleNativeMethodCall(const MethodCall('aboutBusyMax'));

    expect(await nextAction, [
      BusyMaxHeaderBarAction.createEvent,
      BusyMaxHeaderBarAction.createTask,
      BusyMaxHeaderBarAction.continueSetup,
      BusyMaxHeaderBarAction.settings,
      BusyMaxHeaderBarAction.keyboardShortcuts,
      BusyMaxHeaderBarAction.reportIssue,
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

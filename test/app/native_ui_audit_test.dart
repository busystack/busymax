import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('native Ubuntu UI source audit', () {
    test('does not add or import libadwaita', () {
      final files = [
        File('pubspec.yaml'),
        ..._dartFilesIn('lib'),
        ..._dartFilesIn('test'),
      ];

      for (final file in files) {
        final source = file.readAsStringSync();
        expect(
          source,
          isNot(contains('package:${'libadwaita'}')),
          reason: '${file.path} must not import libadwaita.',
        );
      }

      final pubspec = File('pubspec.yaml').readAsStringSync();
      expect(
        pubspec,
        isNot(contains('${'libadwaita'}:')),
        reason: 'pubspec.yaml must not depend on libadwaita.',
      );
    });

    test(
      'main window delegates four-corner clipping and window states to Handy',
      () {
        final source = File(
          'linux/runner/my_application.cc',
        ).readAsStringSync();
        final linuxCmake = File('linux/CMakeLists.txt').readAsStringSync();
        final runnerCmake = File(
          'linux/runner/CMakeLists.txt',
        ).readAsStringSync();
        final workflow = File(
          '.github/workflows/flutter-linux.yml',
        ).readAsStringSync();
        final snapcraft = File('snap/snapcraft.yaml').readAsStringSync();
        final app = File('lib/src/app/busymax_app.dart').readAsStringSync();
        final activateStart = source.indexOf(
          'static void my_application_activate(GApplication* application)',
        );
        final activateEnd = source.indexOf(
          'static void my_application_startup(GApplication* application)',
          activateStart,
        );

        expect(activateStart, isNonNegative);
        expect(activateEnd, greaterThan(activateStart));
        final activateBody = source.substring(activateStart, activateEnd);

        expect(source, contains('#include <handy.h>'));
        expect(source, contains('hdy_init()'));
        expect(activateBody, contains('hdy_application_window_new('));
        expect(activateBody, isNot(contains('gtk_application_window_new(')));
        expect(activateBody, isNot(contains('hdy_window_handle_new()')));
        expect(activateBody, isNot(contains('gtk_window_set_titlebar(')));
        expect(
          linuxCmake,
          contains(
            'pkg_check_modules(HANDY REQUIRED IMPORTED_TARGET libhandy-1)',
          ),
        );
        expect(
          runnerCmake,
          contains(
            'target_link_libraries(\${BINARY_NAME} PRIVATE PkgConfig::HANDY)',
          ),
        );
        expect(workflow, contains('libhandy-1-dev'));
        expect(snapcraft, contains('- libhandy-1-0'));

        // Handy owns the theme radius, state transitions, input region, and
        // child crop. BusyMax must not reintroduce a second window-shaping
        // implementation in GTK or Flutter.
        expect(source, isNot(contains('gdk_window_shape_combine_region')));
        expect(source, isNot(contains('create_rounded_window_region')));
        expect(source, isNot(contains('configure_rounded_window_shape')));
        expect(source, isNot(contains('CAIRO_OPERATOR_CLEAR')));
        expect(source, isNot(contains('kNativeWindowRadius')));
        expect(activateBody, isNot(contains('"unified"')));
        expect(app, isNot(contains('_BusyMaxWindowCornerClip')));
      },
    );

    test('Yaru GTK3 compatibility replaces legacy decoration rings', () {
      final source = File('linux/runner/my_application.cc').readAsStringSync();
      final themeGateStart = source.indexOf(
        'static gboolean current_gtk_theme_uses_legacy_yaru_shadow()',
      );
      final refreshStart = source.indexOf(
        'static void refresh_native_surface_css(MyApplication* self)',
      );
      final refreshEnd = source.indexOf(
        'static void set_native_surface_theme(',
        refreshStart,
      );

      expect(themeGateStart, isNonNegative);
      expect(refreshStart, greaterThan(themeGateStart));
      expect(refreshEnd, greaterThan(refreshStart));

      final themeGate = source.substring(themeGateStart, refreshStart);
      final refresh = source.substring(refreshStart, refreshEnd);
      final compatibilityStart = refresh.indexOf(
        'g_autofree gchar* decoration_css =',
      );
      final compatibilityEnd = refresh.indexOf(
        'g_autofree gchar* css =',
        compatibilityStart,
      );

      expect(themeGate, contains('gtk_settings_get_default()'));
      expect(themeGate, contains('"gtk-theme-name"'));
      expect(themeGate, contains('g_ascii_strdown(theme_name, -1)'));
      expect(themeGate, contains('g_strcmp0(normalized, "yaru")'));
      expect(themeGate, contains('g_str_has_prefix(normalized, "yaru-")'));
      expect(themeGate, contains('strstr(normalized, "highcontrast")'));
      expect(compatibilityStart, isNonNegative);
      expect(compatibilityEnd, greaterThan(compatibilityStart));

      final compatibility = refresh.substring(
        compatibilityStart,
        compatibilityEnd,
      );

      expect(refresh, contains('!self->native_surface_high_contrast'));
      expect(refresh, contains('current_gtk_theme_uses_legacy_yaru_shadow()'));
      expect(
        compatibility,
        contains('box-shadow: 0 3px 9px 1px rgba(0,0,0,0.5);'),
      );
      expect(compatibility, contains('box-shadow: 0 3px 9px 1px transparent,'));
      expect(compatibility, contains('0 2px 6px 2px rgba(0,0,0,0.2);'));
      expect(compatibility, contains('not(.solid-csd)'));
      expect(compatibility, contains('not(.maximized)'));
      expect(compatibility, contains('not(.fullscreen)'));
      expect(compatibility, contains('.tiled-top'));
      expect(compatibility, contains('.tiled-right'));
      expect(compatibility, contains('.tiled-bottom'));
      expect(compatibility, contains('.tiled-left'));
      expect(compatibility, contains('0 0 0 1px rgba(0,0,0,0.05);'));
      expect(compatibility, isNot(contains('rgba(0,0,0,0.65)')));
      expect(compatibility, isNot(contains('rgba(0,0,0,0.75)')));
      expect(compatibility, isNot(contains('border-radius')));
      expect(compatibility, isNot(contains('gdk_window_shape_combine_region')));
    });

    test(
      'Task Details, Settings, and main Agenda use BusyMax Yaru row patterns',
      () {
        final settings = File(
          'lib/src/features/settings/presentation/settings_screen.dart',
        ).readAsStringSync();
        final diagnostics = File(
          'lib/src/features/diagnostics/presentation/diagnostics_screen.dart',
        ).readAsStringSync();
        final router = File('lib/src/app/app_router.dart').readAsStringSync();
        final design = File(
          'lib/src/app/busymax_design.dart',
        ).readAsStringSync();
        final dateTimeFields = File(
          'lib/src/features/tasks/presentation/desktop_date_time_fields.dart',
        ).readAsStringSync();
        final newTaskDialog = File(
          'lib/src/features/tasks/presentation/new_task_dialog.dart',
        ).readAsStringSync();
        final scheduleAgenda = File(
          'lib/src/features/schedule/presentation/schedule_agenda_view.dart',
        ).readAsStringSync();

        expect(design, contains('YaruScrollViewUndershoot.builder('));
        expect(design, contains('endUndershoot: false'));
        expect(design, contains('Color busyMaxModalBarrierColor'));
        expect(design, contains('decoration: ShapeDecoration('));
        expect(design, contains('BusyMaxShadow.nativePopoverShadowsFor('));
        expect(design, contains('ShapeBorderClipper(shape: shape)'));
        expect(design, isNot(contains('_BusyMaxPopoverShadowPainter')));
        expect(design, isNot(contains('return PhysicalShape(')));
        expect(design, isNot(contains('lightSurfaceShadowMinimum')));
        expect(design, contains('final bool filled;'));
        expect(design, contains('BusyMaxSurfaceColors.of(context)'));
        expect(design, contains('surfaceColors.card'));
        expect(design, contains('CardTheme.of(context)'));
        expect(design, contains('surfaceColors.control'));
        expect(design, contains('YaruListTile.square('));
        expect(design, isNot(contains('class _BusyMaxRowTile')));
        final calendarRowStart = design.indexOf(
          'class BusyMaxCalendarValueRow',
        );
        final calendarRowEnd = design.indexOf(
          'class BusyMaxCalendarNotesCard',
          calendarRowStart,
        );
        expect(calendarRowStart, isNonNegative);
        expect(calendarRowEnd, greaterThan(calendarRowStart));
        final calendarRow = design.substring(calendarRowStart, calendarRowEnd);
        expect(calendarRow, contains('required this.entry'));
        expect(calendarRow, isNot(contains('TextField(')));

        expect(settings, contains('BusyMaxClamp'));
        expect(settings, contains('BusyMaxGroupedList'));
        expect(settings, contains('BusyMaxActionRow'));
        expect(settings, contains('BusyMaxComboRow'));
        expect(settings, contains('BusyMaxSwitchRow'));
        expect(settings, contains('class _SettingsSidebar'));
        expect(settings, contains('enum SettingsPage'));
        expect(settings, contains('filled: true'));
        expect(settings, contains('DiagnosticsPanel(scrollable: false)'));
        expect(settings, isNot(contains("context.go('/diagnostics')")));
        expect(diagnostics, contains('class DiagnosticsPanel'));
        expect(diagnostics, isNot(contains('class DiagnosticsScreen')));
        expect(diagnostics, isNot(contains('Scaffold(')));
        expect(router, isNot(contains("path: '/diagnostics'")));
        expect(router, isNot(contains('DiagnosticsScreen')));
        expect(settings, contains('SettingsPage.system'));
        expect(settings, contains('l10n.forceFullResync'));
        expect(settings, contains('l10n.forceFullResyncDescription'));
        expect(settings, contains('l10n.currentLocale'));
        expect(settings, isNot(contains('SettingsPage.sync')));
        expect(settings, isNot(contains('SettingsPage.appearance')));
        expect(settings, isNot(contains('SettingsPage.localization')));
        expect(settings, isNot(contains('l10n.themeFamily')));
        expect(settings, contains('LinuxPageFrame('));
        expect(settings, contains('_SettingsHeader('));
        expect(settings, contains('onBack: _goBack'));
        expect(settings, contains('sidebarAvailable: showSidebar'));
        expect(settings, contains('sidebarExpanded: true'));
        expect(settings, isNot(contains('LinuxHeaderBarSession')));
        expect(newTaskDialog, contains('showBusyMaxModalEditorDialog'));
        expect(newTaskDialog, contains('TaskDetailsEditor'));
        expect(newTaskDialog, isNot(contains('BusyMaxDialogShell')));

        expect(scheduleAgenda, contains('BusyMaxGroupedList'));
        expect(scheduleAgenda, contains('BusyMaxActionRow'));
        expect(scheduleAgenda, isNot(contains('scheduleAgendaRowBackground')));
        expect(scheduleAgenda, isNot(contains('surfaceColor:')));
        expect(scheduleAgenda, contains('ScheduleProjection.colorForItem'));
        expect(scheduleAgenda, contains('leading: _AgendaItemMarker'));
        expect(scheduleAgenda, isNot(contains('class _AgendaDayHeader')));
        expect(scheduleAgenda, isNot(contains('class _AgendaPlainHeader')));

        expect(dateTimeFields, contains('MiniCalendarGrid('));
        expect(dateTimeFields, isNot(contains('ScheduleItem')));
        expect(
          dateTimeFields,
          contains('onDaySelected: (date) => _setSelectedDate'),
        );
        expect(
          'busyMaxGroupedTextFieldDecoration'.allMatches(dateTimeFields).length,
          greaterThanOrEqualTo(2),
        );
        expect(dateTimeFields, contains('parseDesktopTimeInput'));
        expect(dateTimeFields, isNot(contains('_withoutFloatingEntryLabel')));
        expect(dateTimeFields, isNot(contains('_BusyMaxTimeTextEntry')));
        expect(dateTimeFields, isNot(contains('YaruDateTimeEntry')));
        expect(dateTimeFields, isNot(contains('YaruTimeEntry(')));
        expect(dateTimeFields, isNot(contains('YaruTimeEntryController')));
        expect(dateTimeFields, isNot(contains("'Enter date'")));
        expect(dateTimeFields, isNot(contains("'Enter time'")));
        expect(dateTimeFields, isNot(contains('fontSize: 0')));
        expect(dateTimeFields, isNot(contains('showDatePicker')));
        expect(dateTimeFields, isNot(contains('showTimePicker')));
      },
    );

    test('tray DBus menu labels come from its injected presentation', () {
      final source = File(
        'lib/src/platform/busymax_tray_service.dart',
      ).readAsStringSync();
      final logo = File('assets/branding/busymax-logo.svg').readAsStringSync();

      expect(source, contains('BusyMaxTrayMenuPresentation presentation'));
      expect(source, contains('buildBusyMaxTrayMenu'));
      expect(source, contains('label: presentation.showBusyMaxLabel'));
      expect(source, contains('label: presentation.todayLabel'));
      expect(source, contains('static const orderedChildren'));
      expect(source, contains('busyMaxApplicationId'));
      expect(source, contains('io.busystack.busymax'));
      expect(source, contains('assets/branding/busymax-logo.svg'));
      expect(logo, contains('width="512" height="512"'));
      expect(logo, contains('viewBox="106 108 300 300"'));
      expect(logo, isNot(contains('viewBox="254 120 232 272"')));
      expect(source, isNot(contains("iconName: 'busymax-symbolic'")));
      expect(source, isNot(contains("label: 'Show BusyMax'")));
      expect(source, isNot(contains("label: 'Today'")));
      expect(source, isNot(contains("label: 'New event'")));
      expect(source, isNot(contains("label: 'New task'")));
      expect(source, isNot(contains("label: 'Sync now'")));
      expect(source, isNot(contains("label: 'Settings'")));
      expect(source, isNot(contains("label: 'Quit BusyMax'")));
    });

    test('main calendar window starts at the intended desktop size', () {
      final source = File('linux/runner/my_application.cc').readAsStringSync();

      expect(source, contains('kMainWindowDefaultWidth = 1280'));
      expect(source, contains('kMainWindowDefaultHeight = 720'));
      expect(source, contains('gtk_window_set_default_size'));
    });

    test('startup defers native presentation until the app frame is ready', () {
      final source = File('lib/main_linux.dart').readAsStringSync();
      final deferFrame = source.indexOf('binding.deferFirstFrame();');
      final firstRunApp = source.indexOf('runApp(');
      final firstAllowFrame = source.indexOf('binding.allowFirstFrame();');

      expect(deferFrame, isNonNegative);
      expect(firstRunApp, greaterThan(deferFrame));
      expect(firstAllowFrame, greaterThan(firstRunApp));
      expect('binding.allowFirstFrame();'.allMatches(source), hasLength(1));
    });

    test('snap uses portal-backed secret storage without keyring plug', () {
      final snapcraft = File('snap/snapcraft.yaml').readAsStringSync();
      final linuxMain = File('lib/main_linux.dart').readAsStringSync();
      final portalStore = File(
        'lib/src/core/secrets/portal_encrypted_secret_store.dart',
      ).readAsStringSync();

      expect(snapcraft, contains('- desktop'));
      expect(snapcraft, contains('- x11'));
      expect(snapcraft, contains('GDK_BACKEND: wayland,x11'));
      expect(snapcraft, contains('SECRET_BACKEND: file'));
      expect(snapcraft, isNot(contains('password-manager-service')));
      expect(linuxMain, contains('PortalEncryptedSecretStore'));
      expect(portalStore, contains('org.freedesktop.portal.Secret'));
      expect(portalStore, contains('RetrieveSecret'));
      expect(portalStore, contains('AesGcm.with256bits'));
      expect(portalStore, contains('Hkdf(hmac: Hmac.sha256()'));
    });

    test('tray Agenda action reuses the main application window', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      final runner = File('linux/runner/my_application.cc').readAsStringSync();
      final linuxMain = File('linux/runner/main.cc').readAsStringSync();
      final app = File('lib/src/app/busymax_app.dart').readAsStringSync();
      final commands = File(
        'lib/src/schedule/schedule_commands.dart',
      ).readAsStringSync();
      final workspace = File(
        'lib/src/features/schedule/presentation/schedule_workspace.dart',
      ).readAsStringSync();

      expect(linuxMain, contains('gdk_set_allowed_backends("wayland,x11")'));
      expect(pubspec, isNot(contains('desktop_multi_window:')));
      expect(pubspec, isNot(contains('screen_retriever:')));
      expect(pubspec, isNot(contains('window_manager:')));
      expect(runner, isNot(contains('desktop_multi_window')));
      expect(runner, isNot(contains('compact_agenda')));
      expect(app, contains('Future<void> _openMainAgenda('));
      expect(app, contains('await windowService.showWindow();'));
      expect(app, contains('ScheduleWorkspaceCommandKind.agenda'));
      expect(app, contains("ref.read(appRouterProvider).go('/schedule')"));
      expect(commands, contains('agenda,'));
      expect(workspace, contains('case ScheduleWorkspaceCommandKind.agenda:'));
      expect(
        workspace,
        contains(
          '_setMode(ScheduleViewMode.agenda, agendaDate: command.date);',
        ),
      );
    });

    test('one Flutter view owns the main header and full-height sidebar', () {
      final runner = File('linux/runner/my_application.cc').readAsStringSync();
      final frame = File(
        'lib/src/app/linux/linux_page_frame.dart',
      ).readAsStringSync();
      final schedule = File(
        'lib/src/features/schedule/presentation/schedule_workspace.dart',
      ).readAsStringSync();
      final settings = File(
        'lib/src/features/settings/presentation/settings_screen.dart',
      ).readAsStringSync();
      final signIn = File(
        'lib/src/features/auth/presentation/sign_in_screen.dart',
      ).readAsStringSync();
      final activateStart = runner.indexOf(
        'static void my_application_activate(GApplication* application)',
      );
      final activateEnd = runner.indexOf(
        'static void my_application_startup(GApplication* application)',
        activateStart,
      );
      final activate = runner.substring(activateStart, activateEnd);

      expect('fl_view_new('.allMatches(activate), hasLength(1));
      expect(activate, contains('gtk_container_add(GTK_CONTAINER(window)'));
      expect(activate, isNot(contains('hdy_header_bar_new')));
      expect(activate, isNot(contains('hdy_window_handle_new')));
      expect(activate, isNot(contains('gtk_window_set_titlebar')));
      expect(runner, isNot(contains('create_busymax_titlebar_handle')));
      expect(runner, isNot(contains('header_bar_sidebar_width')));
      expect(frame, contains('class LinuxPageFrame'));
      expect(frame, contains("ValueKey('linux-sidebar-viewport')"));
      expect(frame, contains('width: BusyMaxSizes.sidebarWidth'));
      expect(frame, contains('final presentedWidth'));
      expect(frame, contains('Row('));
      expect(schedule, contains('LinuxPageFrame('));
      expect(settings, contains('LinuxPageFrame('));
      expect(signIn, contains('LinuxPageFrame('));
      for (final source in [schedule, settings, signIn]) {
        expect(source, isNot(contains('LinuxHeaderBarSession')));
      }
    });

    test('top-level Linux header triggers use semantic GTK icon assets', () {
      final style = File(
        'lib/src/app/linux/linux_header_style.dart',
      ).readAsStringSync();
      final toolbar = File(
        'lib/src/features/schedule/presentation/schedule_toolbar.dart',
      ).readAsStringSync();
      final workspace = File(
        'lib/src/features/schedule/presentation/schedule_workspace.dart',
      ).readAsStringSync();
      final settings = File(
        'lib/src/features/settings/presentation/settings_screen.dart',
      ).readAsStringSync();
      final presentationStart = toolbar.indexOf(
        'final class _ScheduleViewPresentation',
      );
      expect(presentationStart, isNonNegative);
      final topLevelToolbar = toolbar.substring(0, presentationStart);
      final settingsHeaderStart = settings.indexOf('class _SettingsHeader');
      final settingsHeaderEnd = settings.indexOf(
        'class _SettingsPageLayout',
        settingsHeaderStart,
      );
      expect(settingsHeaderStart, isNonNegative);
      expect(settingsHeaderEnd, greaterThan(settingsHeaderStart));
      final settingsHeader = settings.substring(
        settingsHeaderStart,
        settingsHeaderEnd,
      );

      expect(style, contains('class BusyMaxGtkHeaderIcon'));
      expect(style, contains('BusyMaxLinuxHeaderStyle.symbolicIconSize'));
      expect(style, isNot(contains('BusyMaxLinuxHeaderGlyphs')));
      expect(style, isNot(contains('YaruIcons.')));
      expect(toolbar, isNot(contains('_modeHeaderIcon')));
      expect(toolbar, isNot(contains('_modeMenuIcon')));
      expect(toolbar, contains('resolvedNativeHeaderIconName('));
      for (final forbidden in const [
        'Icons.calendar_view_day_outlined',
        'Icons.view_week_outlined',
        'Icons.calendar_view_month',
        'Icons.calendar_today_outlined',
        'Icons.view_agenda_outlined',
        'YaruIcons.plus',
        'YaruIcons.view_more',
      ]) {
        expect(
          topLevelToolbar,
          isNot(contains(forbidden)),
          reason: 'Top-level Schedule header must not use $forbidden.',
        );
      }
      expect(workspace, isNot(contains('icon: const Icon(Icons.filter_list)')));
      expect(workspace, isNot(contains('BusyMaxLinuxHeaderGlyphs')));
      expect(settingsHeader, isNot(contains('Icon(')));
      expect(settingsHeader, isNot(contains('BusyMaxLinuxHeaderGlyphs')));
    });

    test('schedule Search retains one Flutter header architecture', () {
      final toolbar = File(
        'lib/src/features/schedule/presentation/schedule_toolbar.dart',
      ).readAsStringSync();
      final workspace = File(
        'lib/src/features/schedule/presentation/schedule_workspace.dart',
      ).readAsStringSync();
      final iconService = File(
        'lib/src/platform/gtk_header_icon_service.dart',
      ).readAsStringSync();
      final runner = File('linux/runner/my_application.cc').readAsStringSync();
      final nativeIcons = File(
        'linux/runner/gtk_header_icons.cc',
      ).readAsStringSync();

      expect(workspace, contains('final header = ScheduleToolbar('));
      expect(workspace, isNot(contains("'schedule-search-close-button'")));
      expect(
        workspace,
        isNot(contains("'schedule-search-titlebar-drag-area'")),
      );
      expect(toolbar, contains('title: BusyMaxBinaryPresentation('));
      expect(toolbar, contains('alternateActive: searchActive'));
      expect(toolbar, contains('selected: searchActive'));
      expect(toolbar, contains('BusyMaxLinuxHeaderSearchField('));
      expect(toolbar, isNot(contains('BusyMaxLinuxHeaderIcon.close')));
      expect(iconService, contains("'allowMissing': icon.allowMissing"));
      expect(
        runner,
        contains('fl_value_lookup_string(request, "allowMissing")'),
      );
      expect(nativeIcons, contains('if (!allow_missing)'));
    });

    test('native GTK window preferences notify and clean up safely', () {
      final runner = File('linux/runner/my_application.cc').readAsStringSync();
      final helper = File(
        'linux/runner/gtk_window_preferences.cc',
      ).readAsStringSync();
      for (final property in [
        'gtk-decoration-layout',
        'gtk-titlebar-double-click',
        'gtk-titlebar-middle-click',
        'gtk-titlebar-right-click',
      ]) {
        expect(helper, contains('"$property"'));
        expect(helper, contains('"notify::$property"'));
      }
      expect(helper, contains('BusyMaxGtkWindowPreferencesWatcher::Read'));
      expect(helper, contains('BusyMaxGtkWindowPreferencesWatcher::Start'));
      expect(helper, contains('BusyMaxGtkWindowPreferencesWatcher::Stop'));
      expect(helper, contains('g_signal_handler_disconnect'));
      expect(runner, contains('gtk_window_preferences_listen_cb'));
      expect(runner, contains('send_gtk_window_preferences_event('));
      expect(runner, contains('gtk_window_preferences_cancel_cb'));
      expect(runner, contains('self->gtk_window_preferences->Stop();'));
      expect(
        runner,
        contains('g_clear_object(&self->gtk_window_preferences_event_channel)'),
      );
    });

    test('Linux content menus use native GTK popup menus on mapped host', () {
      final runner = File('linux/runner/my_application.cc').readAsStringSync();
      final service = File(
        'lib/src/platform/native_menu_service.dart',
      ).readAsStringSync();
      final start = runner.indexOf('constexpr char kNativeMenuActionNamespace');
      final end = runner.indexOf('static void respond_success', start);

      expect(start, isNonNegative);
      expect(end, greaterThan(start));
      final nativeMenu = runner.substring(start, end);
      final disposeStart = nativeMenu.indexOf(
        'static void native_menu_session_dispose',
      );
      final disposeEnd = nativeMenu.indexOf(
        'static gboolean native_menu_cleanup_idle_cb',
        disposeStart,
      );
      expect(disposeStart, isNonNegative);
      expect(disposeEnd, greaterThan(disposeStart));
      final dispose = nativeMenu.substring(disposeStart, disposeEnd);

      expect(runner, contains('"busymax/native_menus"'));
      expect(nativeMenu, isNot(contains('struct NativeMenuHostWidgets')));
      expect(nativeMenu, isNot(contains('gtk_event_box_set_above_child(')));
      expect(nativeMenu, isNot(contains('input_layer')));
      expect(nativeMenu, isNot(contains('menu_layer')));
      expect(nativeMenu, contains('GMenu* model;'));
      expect(nativeMenu, contains('GSimpleActionGroup* action_group;'));
      expect(nativeMenu, contains('GtkWidget* menu;'));
      expect(nativeMenu, contains('g_simple_action_new_stateful('));
      expect(nativeMenu, contains('g_menu_item_set_action_and_target_value('));
      expect(nativeMenu, contains('g_menu_item_set_icon(item, icon)'));
      expect(nativeMenu, contains('set_menu_item_accelerator(item, shortcut)'));
      expect(nativeMenu, contains('gtk_menu_new_from_model('));
      expect(
        nativeMenu,
        contains(
          'gtk_menu_attach_to_widget(GTK_MENU(session->menu), data->view',
        ),
      );
      expect(nativeMenu, contains('GTK_IS_MENU(session->menu)'));
      expect(
        nativeMenu,
        contains(
          'gtk_widget_insert_action_group(\n'
          '      data->view, kNativeMenuActionNamespace',
        ),
      );
      expect(
        nativeMenu,
        contains(
          'gtk_widget_translate_coordinates(\n'
          '          data->view, toplevel, anchor.x, anchor.y',
        ),
      );
      expect(nativeMenu, contains('gtk_menu_popup_at_rect('));
      expect(nativeMenu, contains('rect_window, &window_anchor'));
      expect(nativeMenu, contains('GDK_GRAVITY_SOUTH_WEST'));
      expect(nativeMenu, contains('GDK_GRAVITY_NORTH_WEST'));
      expect(nativeMenu, contains('GDK_ANCHOR_FLIP_Y'));
      expect(nativeMenu, contains('GDK_ANCHOR_SLIDE'));
      expect(nativeMenu, contains('GDK_ANCHOR_RESIZE'));
      expect(nativeMenu, contains('native_menu_deactivate_cb'));
      expect(
        nativeMenu,
        contains('"deactivate", G_CALLBACK(native_menu_deactivate_cb)'),
      );
      expect(nativeMenu, contains('gtk_menu_shell_deactivate('));
      expect(nativeMenu, contains('native_menu_action_activated_cb'));
      expect(nativeMenu, contains('native_menu_selection_activated_cb'));
      expect(nativeMenu, isNot(contains('gtk_button_new()')));
      expect(nativeMenu, isNot(contains('gtk_radio_button_new(')));
      expect(nativeMenu, isNot(contains('gtk_toggle_button_new()')));
      expect(nativeMenu, isNot(contains('gtk_drawing_area_new()')));
      expect(nativeMenu, isNot(contains('gtk_cell_renderer_render(')));
      expect(nativeMenu, isNot(contains('native_menu_item_clicked_cb')));
      expect(nativeMenu, isNot(contains('"object-select-symbolic"')));
      expect(nativeMenu, isNot(contains('"radio-symbolic"')));
      expect(nativeMenu, isNot(contains('"radio-checked-symbolic"')));
      expect(
        nativeMenu,
        contains(
          'gtk_menu_shell_select_first(GTK_MENU_SHELL(session->menu), TRUE)',
        ),
      );
      expect(
        nativeMenu,
        contains('gtk_menu_shell_deselect(GTK_MENU_SHELL(session->menu))'),
      );
      expect(nativeMenu, isNot(contains('gtk_overlay_add_overlay(')));
      expect(nativeMenu, isNot(contains('gtk_fixed_move(')));
      expect(nativeMenu, isNot(contains('gtk_menu_button_new()')));
      expect(nativeMenu, isNot(contains('gtk_menu_button_set_menu_model(')));
      expect(nativeMenu, isNot(contains('gtk_menu_button_get_popup(')));
      expect(nativeMenu, isNot(contains('gtk_popover_new_from_model(')));
      expect(nativeMenu, isNot(contains('gtk_menu_button_set_popover(')));
      expect(nativeMenu, isNot(contains('gtk_menu_button_get_popover(')));
      expect(nativeMenu, isNot(contains('gtk_popover_')));
      expect(nativeMenu, isNot(contains('GTK_IS_MODEL_BUTTON')));
      expect(nativeMenu, isNot(contains('style_native_popover')));
      expect(nativeMenu, isNot(contains('add_model_button_presentation')));
      expect(nativeMenu, isNot(contains('ensure_native_menu_hover_tracking')));
      expect(nativeMenu, isNot(contains('GTK_STATE_FLAG_PRELIGHT')));
      expect(nativeMenu, isNot(contains('gtk_widget_set_state_flags')));
      expect(nativeMenu, isNot(contains('gdk_display_flush')));
      expect(nativeMenu, isNot(contains('wl_display_')));
      expect(nativeMenu, contains('g_object_ref(G_OBJECT(method_call))'));
      expect(nativeMenu, isNot(contains('gtk_popover_bind_model(')));
      expect(
        dispose,
        contains('gtk_menu_shell_deactivate(GTK_MENU_SHELL(session->menu))'),
      );
      expect(dispose, contains('gtk_menu_detach(GTK_MENU(session->menu))'));
      expect(dispose, contains('kNativeMenuActionNamespace, nullptr'));
      expect(dispose, isNot(contains('gtk_widget_destroy(session->menu)')));
      expect(dispose, contains('g_clear_object(&session->menu)'));
      final deactivateIndex = dispose.indexOf('gtk_menu_shell_deactivate(');
      final detachIndex = dispose.indexOf('gtk_menu_detach(');
      final respondIndex = dispose.indexOf('native_menu_session_respond(');
      final freeIndex = dispose.indexOf('g_free(session)');
      expect(deactivateIndex, isNonNegative);
      expect(detachIndex, isNonNegative);
      expect(respondIndex, isNonNegative);
      expect(freeIndex, isNonNegative);
      expect(deactivateIndex, lessThan(detachIndex));
      expect(detachIndex, lessThan(respondIndex));
      expect(respondIndex, lessThan(freeIndex));
      expect(
        'native_menu_session_respond('.allMatches(nativeMenu),
        hasLength(2),
      );
      expect(
        nativeMenu,
        contains('g_idle_add_full(\n        G_PRIORITY_DEFAULT_IDLE'),
      );
      expect(nativeMenu, isNot(contains('"unmap"')));
      expect(nativeMenu, isNot(contains('gtk_dialog_run(')));
      expect(nativeMenu, isNot(contains('gtk_menu_new(')));
      expect(nativeMenu, isNot(contains('gtk_widget_override')));
      expect(
        service,
        contains("const nativeMenuChannelName = 'busymax/native_menus'"),
      );
      expect(service, contains("invokeMethod<int>('show'"));
      expect(service, contains("invokeMethod<bool>('dismiss'"));
      expect(service, contains('on MissingPluginException'));
      expect(service, contains('on PlatformException'));
    });

    test('confirmations use the shared app dialog surface', () {
      final runner = File('linux/runner/my_application.cc').readAsStringSync();
      final dialogs = File(
        'lib/src/app/busymax_dialogs.dart',
      ).readAsStringSync();
      final design = File('lib/src/app/busymax_design.dart').readAsStringSync();
      final confirmStart = design.indexOf('class BusyMaxConfirmDialog');
      final confirmBody = design.substring(confirmStart);

      expect(runner, contains('"busymax/native_dialogs"'));
      expect(runner, isNot(contains('gtk_message_dialog_new(')));
      expect(runner, isNot(contains('handle_native_confirmation')));
      expect(runner, isNot(contains('strcmp(method, "confirm")')));
      expect(runner, contains('register_native_dialogs(self, view, window)'));
      expect(runner, isNot(contains('register_native_dialogs_for_subwindow')));
      expect(runner, contains('g_object_add_weak_pointer'));
      expect(runner, contains('native_dialog_handler_data_free'));
      expect(
        runner,
        isNot(contains('native_dialog_method_call_cb, g_object_ref(window)')),
      );
      expect(dialogs, isNot(contains('NativeDialogService')));
      expect(confirmBody, contains('return BusyMaxDialogShell('));
      expect(confirmBody, isNot(contains('return AlertDialog(')));
    });

    test('Linux DAV feature dialogs reuse BusyMax presentation', () {
      final collection = File(
        'lib/src/dav/presentation/nextcloud_collection_dialog.dart',
      ).readAsStringSync();
      final scheduling = File(
        'lib/src/dav/presentation/nextcloud_scheduling_dialog.dart',
      ).readAsStringSync();
      final accounts = File(
        'lib/src/dav/auth/dav_account_dialogs.dart',
      ).readAsStringSync();
      final settings = File(
        'lib/src/features/settings/presentation/settings_screen.dart',
      ).readAsStringSync();
      final importFlow = File(
        'lib/src/features/calendar/presentation/ical_import_flow.dart',
      ).readAsStringSync();

      for (final source in [collection, scheduling]) {
        expect(source, contains('showBusyMaxModalDialog<void>('));
        expect(source, contains('BusyMaxDialogShell('));
        expect(source, isNot(contains('showDialog<')));
        expect(source, isNot(contains('AlertDialog(')));
      }
      expect(collection, contains('BusyMaxEditorHeader('));
      expect(collection, contains('showBusyMaxConfirm('));
      expect(scheduling, contains('showBusyMaxConfirm('));

      expect(accounts, contains('BusyMaxGroupedList('));
      expect(accounts, contains('busyMaxGroupedTextFieldDecoration('));
      expect(accounts, contains("Key('nextcloud-server-field')"));
      expect(accounts, contains("Key('apple-account-email-field')"));

      final subscriptionStart = settings.indexOf('class _WebCalAddDialog');
      final subscriptionEnd = settings.indexOf(
        'String _refreshModeLabel',
        subscriptionStart,
      );
      final subscription = settings.substring(
        subscriptionStart,
        subscriptionEnd,
      );
      expect(subscription, contains('BusyMaxGroupedList('));
      expect(subscription, contains('busyMaxGroupedTextFieldDecoration('));
      expect(subscription, contains('BusyMaxComboRow<WebCalRefreshMode>('));

      final previewStart = importFlow.indexOf('class _IcalImportPreviewDialog');
      final previewEnd = importFlow.indexOf(
        'class _IcalImportReportDialog',
        previewStart,
      );
      final preview = importFlow.substring(previewStart, previewEnd);
      expect(preview, contains('YaruCheckboxListTile('));
      expect(preview, isNot(contains('\n          CheckboxListTile(')));
    });

    test(
      'schedule search filters use BusyMax rows without a dedicated native subsystem',
      () {
        final runner = File(
          'linux/runner/my_application.cc',
        ).readAsStringSync();
        final workspace = File(
          'lib/src/features/schedule/presentation/schedule_workspace.dart',
        ).readAsStringSync();
        final filters = File(
          'lib/src/features/schedule/presentation/schedule_search_filters.dart',
        ).readAsStringSync();

        expect(runner, isNot(contains('native_schedule_search_filters')));
        expect(runner, isNot(contains('NativeScheduleFilter')));
        expect(runner, isNot(contains('content_overlay')));
        expect(
          File(
            'lib/src/platform/linux_schedule_search_filter_service.dart',
          ).existsSync(),
          isFalse,
        );
        expect(
          File(
            'test/platform/linux_schedule_search_filter_service_test.dart',
          ).existsSync(),
          isFalse,
        );

        expect(filters, contains('BusyMaxSidebarSurface('));
        expect(filters, contains('BusyMaxGroupedList('));
        expect(filters, contains('BusyMaxComboRow<'));
        expect(filters, contains('BusyMaxSwitchRow('));
        expect(filters, contains('BusyMaxActionRow('));
        expect(filters, contains('DesktopDateValueRow('));
        expect(filters, contains('busyMaxGroupedTextFieldDecoration('));
        expect(workspace, contains('ScheduleSearchFilters('));
        expect(workspace, contains('showBusyMaxModalDialog<void>('));
        expect(workspace, contains('BusyMaxDialogShell('));
        expect(workspace, isNot(contains('linux-native-search-filter-spacer')));
      },
    );

    test('timezone selection uses native GTK and Handy controls on Linux', () {
      final runner = File('linux/runner/my_application.cc').readAsStringSync();
      final service = File(
        'lib/src/platform/native_dialog_service.dart',
      ).readAsStringSync();
      final selector = File(
        'lib/src/features/tasks/presentation/time_zone_selection_dialog.dart',
      ).readAsStringSync();

      expect(runner, contains('strcmp(method, "selectTimeZone") == 0'));
      expect(runner, contains('gtk_search_entry_new()'));
      expect(runner, contains('hdy_window_new()'));
      expect(runner, contains('hdy_header_bar_new()'));
      expect(runner, contains('hdy_preferences_group_new()'));
      expect(runner, contains('hdy_action_row_new()'));
      expect(
        runner,
        contains(
          'hdy_header_bar_set_decoration_layout(HDY_HEADER_BAR(header_bar), '
          '":close")',
        ),
      );
      final selectorStart = runner.indexOf(
        'static void handle_native_time_zone_selection',
      );
      final selectorEnd = runner.indexOf(
        'struct NativeDialogHandlerData',
        selectorStart,
      );
      expect(selectorStart, isNonNegative);
      expect(selectorEnd, greaterThan(selectorStart));
      final nativeSelector = runner.substring(selectorStart, selectorEnd);
      expect(nativeSelector, isNot(contains('gtk_dialog_new_with_buttons(')));
      expect(nativeSelector, isNot(contains('gtk_dialog_run(')));
      expect(nativeSelector, contains('g_main_loop_run(loop)'));
      expect(
        nativeSelector,
        contains(
          'gtk_window_present_with_time(GTK_WINDOW(window), GDK_CURRENT_TIME)',
        ),
      );
      expect(
        nativeSelector,
        contains('gtk_window_set_skip_taskbar_hint(GTK_WINDOW(window), TRUE)'),
      );
      expect(
        nativeSelector,
        contains('gtk_window_set_skip_pager_hint(GTK_WINDOW(window), TRUE)'),
      );
      expect(
        nativeSelector,
        isNot(contains('gtk_window_set_application(GTK_WINDOW(window)')),
      );
      expect(
        nativeSelector,
        contains(
          'G_CALLBACK(native_time_zone_parent_is_active_notify_cb), window',
        ),
      );
      expect(nativeSelector, isNot(contains('header_focus_transient_window')));
      expect(
        nativeSelector,
        contains('gtk_window_set_transient_for(GTK_WINDOW(window), parent)'),
      );
      expect(
        nativeSelector,
        contains('gtk_window_set_modal(GTK_WINDOW(window), TRUE)'),
      );
      expect(
        runner,
        contains('static void native_time_zone_parent_is_active_notify_cb('),
      );
      final activationCallbackStart = runner.indexOf(
        'static void native_time_zone_parent_is_active_notify_cb(',
      );
      final activationCallbackEnd = runner.indexOf(
        'static void rebuild_native_time_zone_results(',
        activationCallbackStart,
      );
      final activationCallback = runner.substring(
        activationCallbackStart,
        activationCallbackEnd,
      );
      expect(activationCallback, contains('g_idle_add_full('));
      expect(
        activationCallback,
        contains('native_time_zone_present_after_parent_activation_cb'),
      );
      expect(
        activationCallback,
        isNot(contains('gtk_window_present_with_time(')),
      );
      final deferredActivationStart = runner.indexOf(
        'static gboolean '
        'native_time_zone_present_after_parent_activation_cb(',
      );
      final deferredActivationEnd = activationCallbackStart;
      final deferredActivation = runner.substring(
        deferredActivationStart,
        deferredActivationEnd,
      );
      expect(deferredActivation, contains('!gtk_window_is_active(parent)'));
      expect(deferredActivation, contains('gtk_window_is_active(window)'));
      expect(
        deferredActivation,
        contains('gtk_window_present_with_time(window, GDK_CURRENT_TIME)'),
      );
      expect(runner, contains('kNativeTimeZoneDialogContentHeight'));
      expect(runner, contains('kNativeTimeZoneDialogStyleClass'));
      expect(runner, contains('kNativeTimeZoneGroupStyleClass'));
      expect(runner, contains('kNativeTimeZoneRowStyleClass'));
      expect(runner, contains('native_time_zone_option_match_rank'));
      expect(runner, contains('compare_native_time_zone_options'));
      expect(runner, contains('g_ptr_array_sort_with_data'));
      expect(runner, contains('parse_native_grouped_list_style'));
      expect(runner, contains('create_native_grouped_list_provider'));
      expect(
        runner,
        contains('gtk_scrolled_window_set_propagate_natural_width'),
      );
      expect(runner, contains('gtk_scrolled_window_set_max_content_width'));
      expect(
        runner,
        contains('hdy_action_row_set_title_lines(HDY_ACTION_ROW(row), 1)'),
      );
      expect(
        runner,
        contains('hdy_action_row_set_subtitle_lines(HDY_ACTION_ROW(row), 1)'),
      );
      expect(
        nativeSelector,
        contains(
          'gtk_widget_set_margin_start(\n'
          '      results, grouped_list_style.section_horizontal_padding)',
        ),
      );
      expect(
        nativeSelector,
        contains(
          'gtk_widget_set_margin_end(\n'
          '      results, grouped_list_style.section_horizontal_padding)',
        ),
      );
      expect(service, contains("invokeMethod<String>('selectTimeZone'"));
      expect(service, contains('class NativeGroupedListStyle'));
      expect(
        service,
        contains("'groupedListStyle': groupedListStyle.toMessage()"),
      );
      expect(selector, contains('NativeDialogService().selectTimeZone('));
      expect(selector, contains('BusyMaxGroupedList('));
      expect(selector, contains('parentRole: BusyMaxSurfaceRole.dialog'));
      expect(selector, contains('dividerColor: surfaceColors.cardShade'));
      expect(selector, contains('busyMaxRowHoverColor(context)'));
      expect(selector, contains('radius: BusyMaxRadius.md.round()'));
      expect(
        selector,
        contains('sectionTopSpacing: BusyMaxSpacing.lg.round()'),
      );
      expect(
        selector,
        contains('sectionHorizontalPadding: BusyMaxSpacing.xs.round()'),
      );
      expect(
        selector,
        contains('titleBottomSpacing: BusyMaxSpacing.sm.round()'),
      );
    });

    test('application activation presents only the application window', () {
      final runner = File('linux/runner/my_application.cc').readAsStringSync();
      final restoreStart = runner.indexOf('static void restore_main_window');
      final restoreEnd = runner.indexOf(
        'static void window_method_call_cb',
        restoreStart,
      );

      expect(restoreStart, isNonNegative);
      expect(restoreEnd, greaterThan(restoreStart));

      final restore = runner.substring(restoreStart, restoreEnd);
      expect(
        restore,
        contains(
          'gtk_window_present_with_time(self->main_window, GDK_CURRENT_TIME)',
        ),
      );
      expect(restore, isNot(contains('gtk_application_get_windows')));
      expect(restore, isNot(contains('gtk_window_present(self->main_window)')));
    });

    test(
      'text prompts reuse the shared Yaru grouped form without native reinvention',
      () {
        final runner = File(
          'linux/runner/my_application.cc',
        ).readAsStringSync();
        final service = File(
          'lib/src/platform/native_dialog_service.dart',
        ).readAsStringSync();
        final dialogs = File(
          'lib/src/app/busymax_dialogs.dart',
        ).readAsStringSync();
        final design = File(
          'lib/src/app/busymax_design.dart',
        ).readAsStringSync();
        final nativeDialogsStart = runner.indexOf('static void respond_bool(');
        final nativeDialogsEnd = runner.indexOf(
          'struct NativeTimeZoneOption',
          nativeDialogsStart,
        );
        final promptStart = design.indexOf('class BusyMaxPromptDialog');
        final promptEnd = design.indexOf(
          'class BusyMaxConfirmDialog',
          promptStart,
        );

        expect(nativeDialogsStart, isNonNegative);
        expect(nativeDialogsEnd, greaterThan(nativeDialogsStart));
        final nativeDialogs = runner.substring(
          nativeDialogsStart,
          nativeDialogsEnd,
        );
        expect(nativeDialogs, isNot(contains('handle_native_prompt')));
        expect(nativeDialogs, isNot(contains('respond_native_prompt')));
        expect(nativeDialogs, isNot(contains('gtk_entry_new()')));
        expect(nativeDialogs, isNot(contains('gtk_dialog_new_with_buttons(')));
        expect(nativeDialogs, isNot(contains('gtk_message_dialog_new(')));
        expect(runner, isNot(contains('strcmp(method, "confirm")')));
        expect(runner, isNot(contains('strcmp(method, "prompt")')));

        expect(service, isNot(contains('NativeTextPromptResult')));
        expect(service, isNot(contains('Future<NativeTextPromptResult>')));
        expect(service, isNot(contains('invokeMapMethod<String, Object?>')));
        expect(service, isNot(contains("'prompt'")));
        expect(service, contains('on MissingPluginException'));
        expect(service, contains('on PlatformException'));
        expect(dialogs, isNot(contains('nativeDialogService.prompt(')));
        expect(dialogs, contains('showBusyMaxModalDialog<String>('));
        expect(dialogs, contains('BusyMaxPromptDialog('));

        expect(promptStart, isNonNegative);
        expect(promptEnd, greaterThan(promptStart));
        final prompt = design.substring(promptStart, promptEnd);
        expect(prompt, contains('BusyMaxDialogShell('));
        expect(prompt, contains('header: BusyMaxEditorHeader('));
        expect(prompt, isNot(contains('actions: [')));
        expect(prompt, isNot(contains('BusyMaxDialogTitleBar(')));
        expect(prompt, contains('BusyMaxGroupedList('));
        expect(prompt, contains('filled: true'));
        expect(prompt, contains('YaruListTile.square('));
        expect(prompt, contains('busyMaxGroupedTextFieldDecoration('));
        expect(prompt, contains('TextEditingController('));
        expect(prompt, contains('_canSubmit ? _submit : null'));
        expect(prompt, contains('onFieldSubmitted: (_) => _submit()'));
        expect(
          design,
          contains('header ?? BusyMaxDialogTitleBar(title: Text(title))'),
        );
        expect(prompt, isNot(contains('maxWidth:')));
        expect(prompt, isNot(contains('InputDecoration(')));
        expect(prompt, isNot(contains('AlertDialog(')));
      },
    );

    test('modal editors use the semantic window role with themed geometry', () {
      final design = File('lib/src/app/busymax_design.dart').readAsStringSync();
      final start = design.indexOf('class BusyMaxModalEditorSurface');
      final end = design.indexOf('class BusyMaxInlineBadge', start);
      expect(start, isNonNegative);
      expect(end, greaterThan(start));
      final surface = design.substring(start, end);

      expect(surface, contains('return BusyMaxSurfaceScope('));
      expect(surface, contains('role: BusyMaxSurfaceRole.window'));
      expect(surface, contains('child: Dialog('));
      expect(surface, contains('Theme.of(context).scaffoldBackgroundColor'));
      expect(surface, contains('backgroundColor: editorSurface'));
      expect(surface, contains('surfaceTintColor: editorSurface'));
      expect(surface, isNot(contains('floatingBorder')));
      expect(surface, isNot(contains('BorderSide(')));
      expect(surface, isNot(contains('BusyMaxElevation')));
      expect(surface, isNot(contains('Color(0x')));
    });

    test('dialog shells preserve the shared themed shape and perimeter', () {
      final design = File('lib/src/app/busymax_design.dart').readAsStringSync();
      final start = design.indexOf('class BusyMaxDialogShell');
      final end = design.indexOf('class BusyMaxConfirmDialog', start);
      expect(start, isNonNegative);
      expect(end, greaterThan(start));
      final shell = design.substring(start, end);

      expect(shell, contains('child: Dialog('));
      expect(shell, contains('clipBehavior: Clip.antiAlias'));
      expect(shell, isNot(contains('shape: RoundedRectangleBorder(')));
      expect(shell, isNot(contains('ClipRRect(')));
      expect(shell, isNot(contains('BorderSide(')));
    });

    test(
      'retained native surfaces are themed without a native main header',
      () {
        final source = File(
          'linux/runner/my_application.cc',
        ).readAsStringSync();
        final start = source.indexOf('static void refresh_native_surface_css');
        final end = source.indexOf(
          'static void set_native_surface_theme',
          start,
        );

        expect(start, isNonNegative);
        expect(end, greaterThan(start));
        final nativeSurfaceCss = source.substring(start, end);
        expect(nativeSurfaceCss, contains('kNativeDialogStyleClass'));
        expect(nativeSurfaceCss, contains('kNativeTimeZoneDialogStyleClass'));
        expect(nativeSurfaceCss, contains('tooltip'));
        expect(nativeSurfaceCss, contains('window#busymax-window'));
        expect(nativeSurfaceCss, isNot(contains('busymax-titlebar')));
        expect(nativeSurfaceCss, isNot(contains('busymax-header-control')));
        expect(source, isNot(contains('refresh_header_bar_css')));
        expect(source, isNot(contains('kHeaderControlStyleClass')));
        expect(source, contains('native_surface_css_provider'));
        expect(
          source,
          contains('g_clear_object(&self->native_surface_css_provider)'),
        );
      },
    );

    test('native GTK theme sampling does not export fake disabled colors', () {
      final source = File('linux/runner/my_application.cc').readAsStringSync();

      expect(
        source,
        isNot(
          contains(
            'set_theme_color(result, "disabledForeground", &muted_foreground_color)',
          ),
        ),
      );
      expect(
        source,
        isNot(
          contains(
            'set_theme_color(result, "disabledControl", &control_color)',
          ),
        ),
      );
    });

    test('native GTK font settings are streamed to Flutter', () {
      final source = File('linux/runner/my_application.cc').readAsStringSync();

      expect(source, contains('kGtkFontSettingsEventChannel'));
      expect(source, contains('io.busystack.busymax/gtk_font_settings'));
      expect(
        source,
        contains('FlEventChannel* gtk_font_settings_event_channel'),
      );
      expect(source, contains('gtk_font_settings_signal_id'));
      expect(source, contains('gtk_font_settings_listen_cb'));
      expect(source, contains('gtk_font_settings_cancel_cb'));
      expect(source, contains('notify::gtk-font-name'));
      expect(source, contains('send_gtk_font_settings_event'));
      expect(source, contains('fl_event_channel_send'));
      expect(source, contains('disconnect_gtk_font_settings_signal'));
      expect(source, contains('g_signal_handler_disconnect'));
      expect(
        source,
        contains('g_clear_object(&self->gtk_font_settings_event_channel)'),
      );
    });

    test(
      'native GTK theme colors and retained-surface styles stay separate',
      () {
        final source = File(
          'linux/runner/my_application.cc',
        ).readAsStringSync();
        final nativeStyle = File(
          'lib/src/platform/native_style.dart',
        ).readAsStringSync();
        final gtkFontService = File(
          'lib/src/platform/gtk_font_service.dart',
        ).readAsStringSync();
        final app = File('lib/src/app/busymax_app.dart').readAsStringSync();
        final main = File('lib/main_linux.dart').readAsStringSync();

        expect(source, contains('kGtkThemeColorsEventChannel'));
        expect(source, contains('io.busystack.busymax/gtk_theme_colors'));
        expect(
          source,
          contains('FlEventChannel* gtk_theme_colors_event_channel'),
        );
        expect(source, contains('gtk_theme_colors_listen_cb'));
        expect(source, contains('gtk_theme_colors_cancel_cb'));
        expect(source, contains('notify::gtk-theme-name'));
        expect(source, contains('notify::gtk-application-prefer-dark-theme'));
        expect(source, contains('send_gtk_theme_colors_event'));
        expect(source, contains('connect_gtk_theme_colors_signals'));
        expect(source, contains('disconnect_gtk_theme_colors_signals'));
        final notifyStart = source.indexOf(
          'static void gtk_theme_colors_notify_cb(',
        );
        final listenStart = source.indexOf(
          'static FlMethodErrorResponse* gtk_theme_colors_listen_cb(',
        );
        final cancelStart = source.indexOf(
          'static FlMethodErrorResponse* gtk_theme_colors_cancel_cb(',
        );
        final registerStart = source.indexOf(
          'static void register_gtk_settings_channel(',
        );
        final startupStart = source.indexOf(
          'static void my_application_startup(GApplication* application)',
        );
        final shutdownStart = source.indexOf(
          'static void my_application_shutdown(GApplication* application)',
        );
        expect(notifyStart, isNonNegative);
        expect(listenStart, greaterThan(notifyStart));
        expect(cancelStart, greaterThan(listenStart));
        expect(registerStart, greaterThan(cancelStart));
        expect(startupStart, greaterThan(registerStart));
        expect(shutdownStart, greaterThan(startupStart));
        final notify = source.substring(notifyStart, listenStart);
        final cancel = source.substring(cancelStart, registerStart);
        final startup = source.substring(startupStart, shutdownStart);
        expect(notify, contains('refresh_native_surface_css(self)'));
        expect(notify, contains('send_gtk_theme_colors_event(self)'));
        expect(cancel, isNot(contains('disconnect_gtk_theme_colors_signals')));
        expect(startup, contains('connect_gtk_theme_colors_signals('));
        expect(
          source,
          contains('g_clear_object(&self->gtk_theme_colors_event_channel)'),
        );
        expect(nativeStyle, contains("'setNativeSurfaceTheme'"));
        expect(nativeStyle, isNot(contains('preferDark')));
        expect(app, isNot(contains('preferDark: theme.brightness')));
        expect(app, isNot(contains('popoverShadowColor:')));
        expect(
          app,
          isNot(contains('BusyMaxAlpha.nativeHeaderMenuShadowOpacity')),
        );
        expect(source, contains('static void set_gtk_theme_preference'));
        expect(
          source,
          contains('"gtk-application-prefer-dark-theme", prefer_dark'),
        );
        expect(
          source,
          isNot(contains('g_object_set(settings, "gtk-theme-name"')),
        );
        expect(
          source,
          isNot(contains('g_object_set(settings, "gtk-icon-theme-name"')),
        );
        expect(source, isNot(contains('gtk_icon_theme_set_custom_theme')));
        expect(source, contains('theme_selected_bg_color'));
        expect(source, contains('set_theme_color(result, "accent"'));
        expect(source, contains('set_theme_color(result, "accentForeground"'));
        expect(source, contains('set_theme_color(result, "divider"'));
        expect(source, contains('set_theme_color(result, "cardShade"'));
        expect(source, contains('set_theme_color(result, "floatingBorder"'));
        expect(
          source,
          contains('lookup_context_color(window_context, "card_shade_color"'),
        );
        expect(
          source,
          contains(
            'lookup_context_color(window_context, "popover_border_color"',
          ),
        );
        expect(
          source,
          contains(
            'lookup_context_color(window_context, "floating_border_color"',
          ),
        );
        expect(source, isNot(contains('sample_widget_border_color(')));
        expect(
          source,
          contains('gtk_separator_new(GTK_ORIENTATION_HORIZONTAL)'),
        );
        expect(source, contains('sample_widget_background(separator'));
        expect(source, isNot(contains('divider_color.alpha *=')));
        expect(source, contains('GTK_STYLE_CLASS_DIM_LABEL'));
        expect(source, contains('"opacity", &opacity'));
        expect(source, contains('"setGtkThemePreference"'));
        expect(source, contains('set_gtk_theme_preference(fl_method_bool_arg'));
        expect(gtkFontService, contains('final Color? accent;'));
        expect(
          gtkFontService,
          contains("accent: _parseColor(value['accent'])"),
        );
        expect(gtkFontService, contains('final Color? accentForeground;'));
        expect(
          app,
          contains(
            'gtkThemeColors?.accent ?? ubuntuAccentColor ?? systemColor.accent',
          ),
        );
        expect(source, contains('setNativeSurfaceTheme'));
        expect(source, contains('set_native_surface_theme(self, args)'));
        expect(source, isNot(contains('prefer_dark_gtk_theme')));
        expect(source, isNot(contains('set_gtk_theme_preference(TRUE)')));
        final initialThemeStart = main.indexOf(
          'await _applyInitialNativeSurfaceTheme(',
        );
        final runAppStart = main.indexOf('runApp(');
        expect(initialThemeStart, isNonNegative);
        expect(runAppStart, greaterThan(initialThemeStart));
        expect(main, contains('busyMaxNativeSurfaceThemeFor('));
        expect(main, contains('NativeSurfaceStyleService().setTheme('));
      },
    );

    test('app code does not bypass centralized typography', () {
      final matches = <String>[];
      for (final file in _dartFilesIn('lib')) {
        final lines = file.readAsLinesSync();
        final path = _normalizedPath(file);
        for (var index = 0; index < lines.length; index++) {
          final line = lines[index];
          final location = '$path:${index + 1}';
          if (line.contains('fontFamily:') &&
              !path.endsWith('lib/src/app/busymax_yaru_theme.dart') &&
              !path.endsWith('lib/src/app/windows/windows_busymax_app.dart')) {
            matches.add('$location: $line');
          }
          if (line.contains('fontSize:') &&
              !_isAllowedFontSizeException(file, line)) {
            matches.add('$location: $line');
          }
          if (line.contains('GoogleFonts') || line.contains('Roboto')) {
            matches.add('$location: $line');
          }
        }
      }

      final pubspec = File('pubspec.yaml').readAsStringSync();
      expect(pubspec, isNot(contains('GoogleFonts')));
      expect(pubspec, isNot(contains('Roboto')));
      expect(pubspec, isNot(contains('fonts:')));
      expect(matches, isEmpty);
    });

    test('BusyMax text theme does not override Yaru weights globally', () {
      final source = File(
        'lib/src/app/busymax_yaru_theme.dart',
      ).readAsStringSync();
      final start = source.indexOf('static TextTheme _busyMaxTextTheme');
      final end = source.indexOf('\n}\n\nclass _TextStyleNormalizer', start);

      expect(start, isNonNegative);
      expect(end, isNonNegative);
      final body = source.substring(start, end);
      expect(body, isNot(contains('fontWeight:')));
      expect(body, contains('base.copyWith('));
      expect(source, isNot(contains('return TextTheme(')));
    });

    test('shared menus prefer native GTK with one Yaru-themed fallback', () {
      final source = File('lib/src/app/busymax_design.dart').readAsStringSync();
      final menuStart = source.indexOf(
        'Future<BusyMaxMenuSelection<T>?> showBusyMaxMenu',
      );
      final triggerStart = source.indexOf(
        'typedef BusyMaxMenuTriggerBuilder',
        menuStart,
      );
      final menuBody = source.substring(menuStart, triggerStart);
      final fallbackStart = menuBody.indexOf(
        'Future<int?> _showBusyMaxFlutterMenu',
      );
      final fallbackEnd = menuBody.indexOf(
        'Widget _busyMaxFallbackMenuEntry',
        fallbackStart,
      );
      final fallbackBody = menuBody.substring(fallbackStart, fallbackEnd);

      expect(source, contains('class BusyMaxMenuButton'));
      expect(source, contains('class BusyMaxMenuEntry'));
      expect(menuBody, contains('nativeMenuService.show('));
      expect(menuBody, contains('if (nativeResult.available)'));
      expect(menuBody, contains('_showBusyMaxFlutterMenu('));
      expect(fallbackBody, contains('final selection = showMenu<int>('));
      expect(fallbackBody, contains('return await selection;'));
      expect(fallbackBody, contains('session._releaseFallbackRoute();'));
      expect(fallbackBody, contains('_BusyMaxPopupMenuItem<int>('));
      expect(fallbackBody, contains('extends PopupMenuItem<T>'));
      expect(fallbackBody, contains('super.build(context)'));
      expect(fallbackBody, contains('hoverColor: widget.hoverColor'));
      expect(fallbackBody, contains('YaruRadio<int>('));
      expect(fallbackBody, contains('inMutuallyExclusiveGroup: true'));
      expect(fallbackBody, isNot(contains('YaruCheckedPopupMenuItem')));
      expect(fallbackBody, isNot(contains('MenuAnchor(')));
      expect(fallbackBody, isNot(contains('MenuItemButton(')));
      expect(fallbackBody, isNot(contains('DropdownMenu(')));
      expect(fallbackBody, isNot(contains('shape:')));
      expect(fallbackBody, isNot(contains('color:')));
      expect(fallbackBody, isNot(contains('elevation:')));
      expect(fallbackBody, isNot(contains('constraints:')));
    });

    test('form combo is a native-style row using the shared menu adapter', () {
      final source = File('lib/src/app/busymax_design.dart').readAsStringSync();
      final rowStart = source.indexOf('class BusyMaxComboRow');
      final rowEnd = source.indexOf('class BusyMaxSwitchRow');

      expect(rowStart, isNonNegative);
      expect(rowEnd, greaterThan(rowStart));

      final rowBody = source.substring(rowStart, rowEnd);
      expect(rowBody, contains('BusyMaxMenuButton<T>('));
      expect(rowBody, contains('BusyMaxMenuEntry('));
      expect(rowBody, contains('selected: value == selected'));
      expect(rowBody, contains('triggerBuilder:'));
      expect(rowBody, contains('trigger.anchor('));
      expect(rowBody, contains('YaruListTile.square('));
      expect(rowBody, contains('onTap: trigger.onPressed'));
      expect(rowBody, contains('focusNode: trigger.focusNode'));
      expect(rowBody, contains('YaruIcons.pan_down'));
      expect(rowBody, isNot(contains('YaruIcons.pan_up')));
      expect(rowBody, isNot(contains('BusyMaxPushButton.standard(')));
      expect(rowBody, isNot(contains('ButtonStyleButton')));
      expect(rowBody, isNot(contains('DropdownMenu')));
      expect(rowBody, isNot(contains('DropdownMenuEntry')));
      expect(rowBody, isNot(contains('YaruPopupMenuButton')));
      expect(rowBody, isNot(contains('PopupMenuItem')));
      expect(rowBody, isNot(contains('OutlinedButton(')));
      expect(rowBody, isNot(contains('BusyMaxElevation')));
      expect(rowBody, isNot(contains('opacity: 0.6')));
    });

    test('boxed-list rows use the dedicated native card-shade role', () {
      final source = File('lib/src/app/busymax_design.dart').readAsStringSync();
      final start = source.indexOf('class _BusyMaxGroupedListSurface');
      final end = source.indexOf('typedef BusyMaxRowActivationCallback', start);

      expect(start, isNonNegative);
      expect(end, greaterThan(start));
      final body = source.substring(start, end);
      expect(body, contains('color: surfaceColors.cardShade'));
      expect(body, isNot(contains('color: surfaceColors.divider')));
    });

    // Mode selection, keyboard interaction, scaling and native Yaru controls
    // are exercised by busymax_grouped_surface_test.dart. Layout syntax is
    // deliberately not a contract: responsive measurements may be necessary.

    test('feature code avoids raw Material controls with Yaru replacements', () {
      final files = [
        ..._dartFilesIn('lib/src/app'),
        ..._dartFilesIn('lib/src/features'),
      ];

      for (final file in files) {
        final lines = file.readAsLinesSync();
        final path = _normalizedPath(file);
        for (var index = 0; index < lines.length; index++) {
          final line = lines[index];
          final location = '$path:${index + 1}';
          final isSharedConfirmationFallback =
              path.endsWith('lib/src/app/busymax_design.dart') &&
              line.contains('return AlertDialog(');
          expect(
            line.contains('AlertDialog'),
            isSharedConfirmationFallback,
            reason: location,
          );
          expect(
            line,
            isNot(contains('DropdownButtonFormField')),
            reason: location,
          );
          expect(
            _hasRawDropdownMenu(line),
            isFalse,
            reason: '$location should use BusyMaxComboRow.',
          );
          expect(
            _hasRawMenuItemButton(line),
            isFalse,
            reason: '$location should use BusyMaxMenuEntry.',
          );
          expect(line, isNot(contains('ToggleButtons(')), reason: location);
          expect(line, isNot(contains('SegmentedButton(')), reason: location);
          expect(_hasRawMenuAnchor(file, line), isFalse, reason: location);
          expect(
            _hasRawPopupMenuButton(line),
            isFalse,
            reason: '$location should use BusyMaxMenuButton.',
          );
          expect(
            _hasRawPopupMenuEntry(file, line),
            isFalse,
            reason:
                '$location should use BusyMaxMenuEntry through BusyMaxMenuButton.',
          );
          expect(
            _hasRawCheckbox(line),
            isFalse,
            reason: '$location should use YaruCheckbox.',
          );
          expect(
            _hasRawSwitch(line),
            isFalse,
            reason: '$location should use YaruSwitch/YaruSwitchListTile.',
          );
          expect(line, isNot(contains('AppBar(')), reason: location);
          expect(line, isNot(contains('TextButton.icon')), reason: location);
          expect(
            _hasRawIconButton(file, line),
            isFalse,
            reason: '$location should use YaruIconButton.',
          );
        }
      }
    });
  });
}

Iterable<File> _dartFilesIn(String path) sync* {
  final directory = Directory(path);
  if (!directory.existsSync()) {
    return;
  }
  for (final entity in directory.listSync(recursive: true)) {
    if (entity is File && entity.path.endsWith('.dart')) {
      yield entity;
    }
  }
}

bool _hasRawPopupMenuButton(String line) {
  return line.contains('PopupMenuButton') &&
      !line.contains('BusyMaxMenuButton');
}

bool _hasRawDropdownMenu(String line) {
  return RegExp(r'\bDropdownMenu(?:<[^>]+>)?\s*\(').hasMatch(line);
}

bool _hasRawMenuItemButton(String line) {
  return RegExp(r'\bMenuItemButton(?:<[^>]+>)?\s*\(').hasMatch(line);
}

bool _hasRawPopupMenuEntry(File file, String line) {
  if (_normalizedPath(file).endsWith('lib/src/app/busymax_design.dart')) {
    return false;
  }
  return line.contains('PopupMenuItem') ||
      line.contains('YaruCheckedPopupMenuItem');
}

bool _hasRawMenuAnchor(File file, String line) {
  if (_normalizedPath(file).endsWith('lib/src/app/busymax_design.dart')) {
    return false;
  }
  return RegExp(r'\bMenuAnchor\s*\(').hasMatch(line);
}

bool _hasRawCheckbox(String line) {
  return line.contains('Checkbox(') && !line.contains('YaruCheckbox(');
}

bool _hasRawSwitch(String line) {
  return line.contains('Switch(') && !line.contains('YaruSwitch(');
}

bool _hasRawIconButton(File file, String line) {
  if (_normalizedPath(file).endsWith('lib/src/app/busymax_design.dart')) {
    return false;
  }
  return line.contains('IconButton(') &&
      !line.contains('YaruIconButton(') &&
      !line.contains('BusyMaxHeaderIconButton(') &&
      !line.contains('BusyMaxLinuxHeaderIconButton(') &&
      !line.contains('BusyMaxPopoverIconButton(');
}

bool _isAllowedFontSizeException(File file, String line) {
  final path = _normalizedPath(file);
  if (path.endsWith('lib/src/app/busymax_yaru_theme.dart')) {
    return true;
  }
  if (path.endsWith('lib/src/app/busymax_app.dart') &&
      line.contains('theme.tooltipTheme.textStyle?.fontSize')) {
    return true;
  }
  return path.endsWith(
        'lib/src/features/tasks/presentation/desktop_date_time_fields.dart',
      ) &&
      line.contains('fontSize: 0');
}

String _normalizedPath(File file) => file.path.replaceAll('\\', '/');

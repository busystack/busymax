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
      'Task Details, Settings, and Agenda use BusyMax Yaru row patterns',
      () {
        final taskDetails = File(
          'lib/src/features/tasks/presentation/task_details_editor.dart',
        ).readAsStringSync();
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
        final compactAgenda = File(
          'lib/src/features/schedule/presentation/compact_agenda_panel.dart',
        ).readAsStringSync();

        expect(design, contains('class BusyMaxClamp'));
        expect(design, contains('class BusyMaxGroupedList'));
        expect(design, contains('class BusyMaxActionRow'));
        expect(design, contains('class BusyMaxComboRow'));
        expect(design, contains('class _BusyMaxRowTile'));
        expect(design, contains('class BusyMaxSwitchRow'));
        expect(design, contains('class BusyMaxDialogShell'));
        expect(design, contains('class BusyMaxModalEditorSurface'));
        expect(design, contains('Color busyMaxModalBarrierColor'));
        expect(design, contains('abstract final class BusyMaxElevation'));
        expect(design, contains('elevation: BusyMaxElevation.surface'));
        expect(
          design,
          contains('shadowColor: BusyMaxShadow.floatingColor(context)'),
        );
        expect(design, contains('final bool filled;'));
        expect(design, contains('BusyMaxSurfaceColors.of(context)'));
        expect(design, contains('surfaceColors.card'));
        expect(design, contains('surfaceColors.control'));
        expect(design, contains('color: surfaceColors.control'));
        expect(design, contains('highlightColor: surfaceColors.controlActive'));
        expect(design, isNot(contains('YaruTileList(children: children)')));
        expect(design, isNot(contains('YaruListTile.square')));

        expect(taskDetails, contains('BusyMaxClamp'));
        expect(taskDetails, contains('BusyMaxGroupedList'));
        expect(taskDetails, contains('BusyMaxActionRow'));
        expect(taskDetails, contains('BusyMaxComboRow'));

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
        expect(settings, contains('l10n.manualFullSync'));
        expect(settings, contains('l10n.currentLocale'));
        expect(settings, isNot(contains('SettingsPage.sync')));
        expect(settings, isNot(contains('SettingsPage.appearance')));
        expect(settings, isNot(contains('SettingsPage.localization')));
        expect(settings, isNot(contains('l10n.themeFamily')));
        expect(settings, contains('setBackVisible(true)'));
        expect(settings, contains('setSidebarVisible(true)'));
        expect(newTaskDialog, contains('showBusyMaxModalEditorDialog'));
        expect(newTaskDialog, contains('TaskDetailsEditor'));
        expect(newTaskDialog, isNot(contains('BusyMaxDialogShell')));

        expect(scheduleAgenda, contains('BusyMaxGroupedList'));
        expect(scheduleAgenda, contains('BusyMaxActionRow'));
        expect(scheduleAgenda, isNot(contains('scheduleAgendaRowBackground')));
        expect(scheduleAgenda, isNot(contains('surfaceColor:')));
        expect(
          scheduleAgenda,
          isNot(contains('ScheduleProjection.colorForItem')),
        );
        expect(scheduleAgenda, isNot(contains('class _AgendaDayHeader')));
        expect(scheduleAgenda, isNot(contains('class _AgendaPlainHeader')));

        expect(compactAgenda, contains('BusyMaxGroupedList'));
        expect(compactAgenda, contains('BusyMaxActionRow'));
        expect(compactAgenda, isNot(contains('scheduleAgendaRowBackground')));
        expect(
          compactAgenda,
          isNot(contains('ScheduleProjection.colorForItem')),
        );

        expect(dateTimeFields, contains('YaruDateTimeEntry'));
        expect(dateTimeFields, contains('_BusyMaxTimeTextEntry'));
        expect(dateTimeFields, contains('parseTimeInput'));
        expect(dateTimeFields, isNot(contains('showDatePicker')));
        expect(dateTimeFields, isNot(contains('showTimePicker')));
      },
    );

    test('tray DBus menu labels come from injected labels', () {
      final source = File(
        'lib/src/platform/busymax_tray_service.dart',
      ).readAsStringSync();
      final logo = File('assets/branding/busymax-logo.svg').readAsStringSync();

      expect(source, contains('class BusyMaxTrayLabels'));
      expect(source, contains('buildBusyMaxTrayMenu'));
      expect(source, contains('busyMaxApplicationId'));
      expect(source, contains('io.busystack.busymax'));
      expect(source, contains('assets/branding/busymax-logo.svg'));
      expect(logo, contains('width="512" height="512"'));
      expect(logo, contains('viewBox="106 108 300 300"'));
      expect(logo, isNot(contains('viewBox="254 120 232 272"')));
      expect(source, isNot(contains('BusyMaxTrayAgendaSnapshot')));
      expect(source, isNot(contains('BusyMaxTrayAgendaEntry')));
      expect(source, isNot(contains('_buildAgendaSubmenuItems')));
      expect(source, isNot(contains('busyMaxTrayAgendaSlotCount')));
      expect(source, isNot(contains("iconName: 'busymax-symbolic'")));
      expect(source, isNot(contains("label: 'Show BusyMax'")));
      expect(source, isNot(contains("label: 'Today'")));
      expect(source, isNot(contains("label: 'New event'")));
      expect(source, isNot(contains("label: 'New task'")));
      expect(source, isNot(contains("label: 'Sync now'")));
      expect(source, isNot(contains("label: 'Settings'")));
      expect(source, isNot(contains("label: 'Quit BusyMax'")));
    });

    test('snap uses portal-backed secret storage without keyring plug', () {
      final snapcraft = File('snap/snapcraft.yaml').readAsStringSync();
      final bootstrap = File(
        'lib/src/app/app_bootstrap.dart',
      ).readAsStringSync();
      final portalStore = File(
        'lib/src/google_tasks/oauth/portal_encrypted_oauth_token_store.dart',
      ).readAsStringSync();

      expect(snapcraft, contains('- desktop'));
      expect(snapcraft, contains('- x11'));
      expect(snapcraft, contains('GDK_BACKEND: wayland,x11'));
      expect(snapcraft, contains('SECRET_BACKEND: file'));
      expect(snapcraft, isNot(contains('password-manager-service')));
      expect(bootstrap, contains('PortalEncryptedOAuthTokenStore'));
      expect(portalStore, contains('org.freedesktop.portal.Secret'));
      expect(portalStore, contains('RetrieveSecret'));
      expect(portalStore, contains('AesGcm.with256bits'));
      expect(portalStore, contains('Hkdf(hmac: Hmac.sha256()'));
    });

    test('compact agenda uses a separate desktop window', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      final runner = File('linux/runner/my_application.cc').readAsStringSync();
      final linuxMain = File('linux/runner/main.cc').readAsStringSync();
      final tray = File(
        'lib/src/platform/busymax_tray_service.dart',
      ).readAsStringSync();
      final router = File('lib/src/app/app_router.dart').readAsStringSync();
      final main = File('lib/main.dart').readAsStringSync();
      final compactApp = File(
        'lib/src/features/schedule/presentation/compact_agenda_app.dart',
      ).readAsStringSync();
      final compactPanel = File(
        'lib/src/features/schedule/presentation/compact_agenda_panel.dart',
      ).readAsStringSync();
      final compactWindowService = File(
        'lib/src/platform/compact_agenda_window_service.dart',
      ).readAsStringSync();

      expect(pubspec, contains('desktop_multi_window:'));
      expect(pubspec, contains('window_manager:'));
      expect(linuxMain, contains('gdk_set_allowed_backends("wayland,x11")'));
      expect(
        runner,
        contains('desktop_multi_window_plugin_set_window_created_callback'),
      );
      expect(runner, contains('configure_compact_agenda_subwindow'));
      expect(runner, contains('install_compact_agenda_window_css'));
      expect(runner, contains('io.busystack.busymax/compact_agenda_window'));
      expect(runner, contains('kCompactAgendaPanelWidth = 420'));
      expect(runner, contains('kCompactAgendaWindowShadowMargin = 32'));
      expect(
        runner,
        contains('gtk_window_resize(window, kCompactAgendaWindowWidth'),
      );
      expect(runner, contains('move_compact_agenda_window_if_supported'));
      expect(runner, contains('GDK_IS_X11_DISPLAY(display)'));
      expect(runner, contains('gtk_window_move(window, x, y)'));
      expect(runner, contains('"skipped-non-x11"'));
      expect(
        runner,
        contains('gtk_window_set_gravity(window, GDK_GRAVITY_NORTH_EAST)'),
      );
      expect(runner, contains('BusyMax compact agenda positioning: phase=%s'));
      expect(runner, contains('apply_compact_agenda_geometry'));
      expect(
        runner,
        contains(
          'gtk_window_set_type_hint(window, GDK_WINDOW_TYPE_HINT_UTILITY)',
        ),
      );
      expect(
        runner,
        contains('gtk_window_set_skip_taskbar_hint(window, TRUE)'),
      );
      expect(runner, contains('gtk_window_set_skip_pager_hint(window, TRUE)'));
      expect(runner, contains('gtk_window_set_keep_above(window, TRUE)'));
      expect(runner, contains('register_compact_gtk_settings_channel'));
      expect(
        runner,
        contains('register_native_date_time_picker_for_subwindow'),
      );
      expect(runner, contains('window#busymax-compact-agenda-window'));
      expect(runner, contains('gtk_window_get_titlebar(window)'));
      expect(runner, contains('gtk_widget_hide(titlebar)'));
      expect(runner, contains('gtk_window_set_decorated(window, FALSE)'));
      expect(
        runner,
        contains('gtk_widget_set_size_request(GTK_WIDGET(window)'),
      );
      expect(runner, contains('gtk_widget_set_size_request(GTK_WIDGET(view)'));
      expect(
        runner,
        isNot(contains('gtk_window_set_titlebar(window, nullptr)')),
      );
      expect(tray, contains('return _onOpenAgenda();'));
      expect(tray, isNot(contains('BusyMaxTrayAgendaMenu')));
      expect(tray, isNot(contains('BusyMaxTrayAgendaEntry')));
      expect(tray, isNot(contains('onOpenAgendaEntry')));
      expect(tray, contains('id: _busyMaxTrayAgendaMenuId'));
      expect(router, isNot(contains('/tray-agenda')));
      expect(compactApp, isNot(contains('linux_header_bar_service.dart')));
      expect(compactApp, contains('gtk_font_service.dart'));
      expect(compactApp, contains('gtkFontSettingsProvider'));
      expect(compactApp, contains('gtkThemeColorsProvider'));
      expect(compactApp, isNot(contains('syncSchedulerProvider')));
      expect(compactApp, isNot(contains('notificationSchedulerProvider')));
      expect(compactApp, isNot(contains('dueTodayNotificationProvider')));
      expect(compactApp, contains('const _compactAgendaPanelWidth = 420.0'));
      expect(compactApp, contains('const _compactAgendaPanelHeight = 680.0'));
      expect(compactApp, contains('BusyMaxShadow.windowMargin'));
      expect(
        compactApp,
        contains('io.busystack.busymax/compact_agenda_window'),
      );
      expect(
        compactApp,
        contains('_compactAgendaWindowChannel.invokeMethod<bool>'),
      );
      expect(compactApp, contains('unawaited(_destroyWindow());'));
      expect(compactApp, contains('Future<void> _clearWindowMethodHandler()'));
      expect(compactApp, contains('Compact agenda positioning: event='));
      expect(
        compactApp,
        contains('await windowManager.setSize(_compactAgendaWindowSize)'),
      );
      expect(compactApp, contains('await windowManager.setBounds('));
      expect(compactApp, isNot(contains('windowManager.setPosition(')));
      expect(
        compactApp,
        contains('final shownNatively = await _showNativeWindow(position);'),
      );
      expect(compactApp, isNot(contains('void onWindowBlur()')));
      expect(compactApp, isNot(contains('_hideAfterBlurDelay')));
      expect(compactPanel, contains('ClipRRect'));
      expect(compactPanel, contains('BusyMaxRadius.window'));
      expect(compactPanel, contains('BusyMaxShadow.windowShadowsFor'));
      expect(compactWindowService, contains('getPrimaryDisplay()'));
      expect(compactWindowService, contains('getCursorScreenPoint()'));
      expect(compactWindowService, contains('getAllDisplays()'));
      expect(compactWindowService, contains('_compactAgendaWindowFrameWidth'));
      expect(compactWindowService, contains('_compactAgendaWindowFrameHeight'));
      expect(compactWindowService, contains('_clampWindowPositionToWorkArea'));
      expect(compactWindowService, contains('raw_x='));
      expect(compactWindowService, contains('final_x='));
      expect(
        compactWindowService,
        contains(
          'workarea.right -\n'
          '        _compactAgendaWindowFrameWidth -\n'
          '        _compactAgendaPanelScreenGap',
        ),
      );
      expect(
        compactWindowService,
        isNot(contains('panelTop - _compactAgendaWindowShadowMargin')),
      );
      expect(compactWindowService, isNot(contains('controller.show()')));
      expect(main, isNot(contains('waitUntilReadyToShow')));
      expect(main, isNot(contains('await windowManager.show();')));
    });

    test('native headerbar keeps sidebar top branded and aligned', () {
      final source = File('linux/runner/my_application.cc').readAsStringSync();
      final signIn = File(
        'lib/src/features/auth/presentation/sign_in_screen.dart',
      ).readAsStringSync();
      final schedule = File(
        'lib/src/features/schedule/presentation/schedule_workspace.dart',
      ).readAsStringSync();
      final headerBarSource = source.substring(
        0,
        source.indexOf('static void install_compact_agenda_window_css'),
      );

      expect(source, isNot(contains('GtkWidget* brand_box')));
      expect(
        source,
        isNot(
          contains('gtk_container_set_border_width(GTK_CONTAINER(brand_box)'),
        ),
      );
      expect(source, isNot(contains('create_header_logo()')));
      expect(source, contains('header_sidebar_brand_box'));
      expect(source, contains('header_title_balance_spacer'));
      expect(source, contains('header_title_box'));
      expect(source, contains('kHeaderWindowControlsBalanceWidth'));
      expect(source, contains('kHeaderOnboardingContentWidth'));
      expect(source, contains('kHeaderOnboardingSideWidth'));
      expect(source, contains('onboarding_back_slot'));
      expect(source, contains('onboarding_back_button'));
      expect(source, contains('onboarding_continue_slot'));
      expect(source, contains('onboarding_continue_button'));
      expect(source, contains('"continueSetup"'));
      expect(source, contains('set_header_onboarding_controls'));
      expect(signIn, contains('await _clearOnboardingHeaderBar();'));
      expect(signIn, contains('Future<void> _clearOnboardingHeaderBar()'));
      expect(signIn, contains('var _finishingSetup = false;'));
      expect(signIn, contains('var _headerBarUpdateGeneration = 0;'));
      expect(signIn, contains('if (_finishingSetup)'));
      expect(signIn, contains('generation != _headerBarUpdateGeneration'));
      expect(signIn, contains('_headerBarUpdateGeneration++;'));
      expect(signIn, contains('force: true'));
      expect(schedule, contains('if (service.isAvailable)'));
      expect(schedule, contains('service.setOnboardingControls('));
      expect(schedule, contains('force: true'));
      expect(
        source,
        contains(
          'gtk_header_bar_pack_start(header_bar, self->header_title_balance_spacer)',
        ),
      );
      expect(source, contains('update_header_title_balance_spacer'));
      expect(source, contains('update_header_title_box_geometry'));
      expect(source, contains('self->header_onboarding_controls_visible'));
      expect(
        source,
        contains(
          'gtk_widget_set_size_request(self->header_title_box, width, -1)',
        ),
      );
      expect(
        source,
        contains(
          'gtk_header_bar_set_custom_title(header_bar, self->header_title_box)',
        ),
      );
      expect(
        source,
        contains(
          'gtk_label_set_xalign(GTK_LABEL(self->header_title_label), 0.5)',
        ),
      );
      expect(source, isNot(contains('header_brand_logo')));
      expect(source, contains('header_brand_label'));
      expect(source, contains('settings_menu_button'));
      expect(source, contains('settings_menu'));
      expect(source, contains('create_header_settings_item(self, "settings"'));
      expect(
        source,
        contains('create_header_settings_item(self, "aboutBusyMax"'),
      );
      expect(source, isNot(contains('settingsAccounts')));
      expect(source, isNot(contains('settingsDiagnostics')));
      expect(source, contains('gtk_label_new(kApplicationDisplayName)'));
      expect(source, contains('GtkWidget* titlebar_box;'));
      expect(source, contains('busymax-titlebar'));
      expect(
        source,
        contains(
          'gtk_box_pack_start(GTK_BOX(self->titlebar_box),\n'
          '                     self->header_sidebar_brand_box',
        ),
      );
      expect(
        source,
        contains(
          'gtk_box_pack_start(GTK_BOX(self->titlebar_box), GTK_WIDGET(header_bar)',
        ),
      );
      expect(source, contains('gtk_window_set_titlebar(window, titlebar)'));
      expect(
        source,
        isNot(
          contains(
            'gtk_header_bar_pack_start(header_bar, self->header_sidebar_brand_box)',
          ),
        ),
      );
      expect(source, isNot(contains('busymax-sidebar-header')));
      expect(source, isNot(contains('sidebar_visible_toggle_button')));
      expect(source, contains('GtkWidget* back_button;'));
      expect(source, contains('set_header_back_visible'));
      expect(source, contains('setBackVisible'));
      expect(
        source,
        contains('connect_header_bar_action(self, self->back_button, "back")'),
      );
      expect(source, contains('sidebar_collapsed_toggle_button'));
      expect(source, contains('header_bar_sidebar_width'));
      expect(source, contains('header_bar_sidebar_visible'));
      expect(source, contains('header_sidebar_effective_width'));
      expect(source, contains('update_header_sidebar_brand_geometry'));
      expect(source, contains('kHeaderMainContentStartInset'));
      expect(
        source,
        contains(
          'constexpr gint kHeaderSidebarContentInset = kHeaderButtonSpacing;',
        ),
      );
      expect(
        source,
        contains(
          'constexpr gint kHeaderMainContentStartInset = '
          'kHeaderSidebarContentInset;',
        ),
      );
      expect(
        source,
        contains(
          'gtk_widget_set_margin_start(self->header_start_box,\n'
          '                              kHeaderMainContentStartInset)',
        ),
      );
      expect(source, contains('padding-left: 0;'));
      expect(source, contains('kHeaderWindowRadius'));
      expect(source, contains('border-top-left-radius: %dpx;'));
      expect(source, contains('border-top-right-radius: %dpx;'));
      final mainWindowCssStart = source.indexOf('"window#busymax-window,"');
      final mainWindowDecorationCssStart = source.indexOf(
        '"window#busymax-window decoration,"',
        mainWindowCssStart,
      );
      final mainWindowCss = source.substring(
        mainWindowCssStart,
        mainWindowDecorationCssStart,
      );
      expect(mainWindowCss, contains('"background-color: %s;"'));
      expect(
        source,
        contains('self->main_window_transparent_backing ? "transparent"'),
      );
      expect(
        source,
        contains(
          'g_signal_connect(window, "draw", G_CALLBACK(clear_transparent_window_cb)',
        ),
      );
      expect(source, contains('clear_transparent_window_cb'));
      expect(source, contains('CAIRO_OPERATOR_CLEAR'));
      expect(
        source,
        contains('gtk_widget_set_name(GTK_WIDGET(window), "busymax-window")'),
      );
      expect(source, contains('window#busymax-window decoration,'));
      expect(source, contains('window#busymax-window decoration:backdrop'));
      expect(source, contains('"box-shadow: 0 3px 18px 2px %s;"'));
      expect(source, contains('window_css_background_color, shade_color'));
      expect(source, contains('"outline: none;"'));
      expect(
        source,
        contains('gtk_widget_set_app_paintable(GTK_WIDGET(window), TRUE)'),
      );
      expect(source, contains('configure_rounded_window_shape'));
      expect(source, contains('create_rounded_window_region'));
      expect(source, contains('gdk_window_shape_combine_region'));
      expect(source, contains('GDK_WINDOW_STATE_MAXIMIZED'));
      expect(source, contains('GDK_WINDOW_STATE_FULLSCREEN'));
      expect(source, isNot(contains('kHeaderSidebarEdgeCompensation')));
      expect(source, isNot(contains('-kHeaderSidebarEdgeCompensation')));
      expect(source, isNot(contains('linear-gradient(to right')));
      expect(source, isNot(contains('GtkWidget* sidebar_toggle_button;')));
      expect(source, isNot(contains('self->sidebar_toggle_button')));
      expect(source, contains('constexpr gint kHeaderButtonRadius = 8;'));
      expect(source, contains('border-radius: %dpx;'));
      expect(source, contains('tooltip.background'));
      expect(source, contains('tooltip > box'));
      expect(source, contains('tooltip label'));
      expect(source, contains('margin: 0;'));
      expect(source, contains('min-height: 0;'));
      expect(source, contains('"box-shadow: 0 5px 18px 2px %s;"'));
      expect(source, contains('kHeaderTooltipVerticalPadding'));
      expect(source, contains('kHeaderTooltipHorizontalPadding'));
      expect(
        source,
        contains('constexpr gint kHeaderTooltipVerticalPadding = 5;'),
      );
      expect(
        source,
        contains('constexpr gint kHeaderTooltipHorizontalPadding = 8;'),
      );
      expect(source, contains('padding: %dpx %dpx;'));
      expect(source, contains('border-color: transparent;'));
      expect(source, contains('border-width: 0;'));
      expect(source, contains('outline-style: none;'));
      expect(source, contains('busymax-brand-action-button'));
      expect(source, contains('button.busymax-brand-action-button,'));
      expect(source, contains('button.busymax-brand-action-button:hover'));
      expect(source, contains('busymax-sidebar-toggle'));
      expect(source, contains('busymax-header-button'));
      expect(source, contains('busymax-header-icon-button'));
      expect(
        source,
        contains(
          'gtk_widget_set_size_request(button, kHeaderButtonHeight,\n'
          '                              kHeaderButtonHeight)',
        ),
      );
      expect(
        source,
        contains('gtk_widget_set_valign(button, GTK_ALIGN_CENTER)'),
      );
      expect(
        source,
        contains('gtk_widget_set_valign(brand_center_box, GTK_ALIGN_CENTER)'),
      );
      expect(
        source,
        contains(
          '.busymax-titlebar button.busymax-header-view-mode-button:hover',
        ),
      );
      expect(source, contains('transition: none;'));
      expect(source, contains('gtk_popover_new(nullptr)'));
      expect(source, contains('gtk_popover_set_position'));
      expect(source, contains('GTK_POS_BOTTOM'));
      expect(source, contains('create_header_popover_box'));
      expect(source, contains('gtk_popover_popdown'));
      expect(source, contains('gtk_menu_button_new()'));
      expect(source, contains('gtk_menu_button_set_use_popover'));
      expect(source, contains('gtk_menu_button_set_popover'));
      expect(source, contains('close_header_menu_button'));
      expect(source, contains('gtk_toggle_button_set_active'));
      expect(source, isNot(contains('popdown_header_popover')));
      expect(source, isNot(contains('gtk_popover_set_relative_to')));
      expect(source, isNot(contains('gtk_popover_popup')));
      expect(source, isNot(contains('"busymax-popover-open"')));
      expect(source, isNot(contains('header_popover_is_open')));
      expect(source, isNot(contains('set_header_popover_open')));
      expect(source, isNot(contains('header_popover_closed_cb')));
      expect(source, isNot(contains('g_signal_connect(popover, "closed"')));
      expect(source, isNot(contains('popup_header_menu')));
      expect(source, isNot(contains('gtk_widget_get_mapped(popup)')));
      expect(source, isNot(contains('gtk_widget_get_visible(popup)')));
      expect(source, contains('"busymax-header-popover"'));
      expect(source, contains('header_bar_popover_background_color'));
      expect(source, contains('"popoverBackgroundColor"'));
      expect(source, contains('"busymax-header-popover-row"'));
      expect(source, contains('kHeaderPopoverRowSpacing'));
      expect(
        source,
        contains(
          'gtk_box_new(GTK_ORIENTATION_VERTICAL, kHeaderPopoverRowSpacing)',
        ),
      );
      expect(source, contains('button.busymax-header-popover-row:focus'));
      expect(source, contains('"object-select-symbolic"'));
      expect(source, contains('gtk_widget_set_opacity(check_widget'));
      expect(source, isNot(contains('gtk_model_button_new()')));
      expect(source, isNot(contains('gtk_check_menu_item_new')));
      expect(source, isNot(contains('GTK_BUTTON_ROLE_CHECK')));
      expect(source, isNot(contains('GTK_BUTTON_ROLE_NORMAL')));
      expect(source, isNot(contains('g_object_set(item, "text"')));
      expect(source, isNot(contains('g_object_set(item, "active"')));
      expect(
        source,
        contains('gtk_box_pack_start(GTK_BOX(view_mode_menu_box)'),
      );
      expect(source, contains('gtk_box_pack_start(GTK_BOX(settings_menu_box)'));
      expect(source, isNot(contains('.busymax-header-menu,')));
      expect(source, isNot(contains('menu.background.busymax-header-menu')));
      expect(source, isNot(contains('menuitem.busymax-header-view-mode-item')));
      expect(source, isNot(contains('menuitem.busymax-header-settings-item')));
      expect(source, isNot(contains('"*:hover {"')));
      expect(source, isNot(contains('busymax-header-view-mode-popover')));
      expect(source, isNot(contains('busymax-header-settings-popover')));
      expect(source, isNot(contains('box-shadow: 0 8px 24px')));
      expect(
        source,
        isNot(
          contains(
            'headerbar.busymax-flat-headerbar combobox.busymax-header-combo button.combo,',
          ),
        ),
      );
      expect(source, isNot(contains('combobox.busymax-header-combo menu,')));
      expect(source, isNot(contains('combobox.busymax-header-combo button {')));
      expect(source, contains('background-color: transparent;'));
      expect(source, contains('padding-left: 0;'));
      expect(source, contains('kHeaderButtonHeight'));
      expect(source, contains('kHeaderButtonSpacing'));
      expect(source, contains('kHeaderMenuPadding = kHeaderButtonSpacing'));
      expect(source, isNot(contains('padding: 4px;')));
      expect(source, contains('setLocalizedLabels'));
      expect(source, contains('setSidebarWidth'));
      expect(source, contains('setTheme'));
      expect(source, contains('setModalBarrierVisible'));
      expect(source, contains('busymax-modal-barrier'));
      expect(source, contains('gtk_widget_set_sensitive(self->titlebar_box'));
      expect(source, isNot(contains('setBackgroundColor')));
      expect(source, isNot(contains('setSidebarBackgroundColor')));
      expect(source, contains('is_css_rgba_color'));
      expect(source, contains('is_css_color_token'));
      expect(source, contains('header_bar_foreground_color'));
      expect(source, contains('header_bar_muted_foreground_color'));
      expect(source, contains('header_bar_disabled_foreground_color'));
      expect(source, contains('header_bar_control_hover_color'));
      expect(source, contains('header_bar_popover_background_color'));
      expect(source, contains('header_bar_border_color'));
      expect(source, contains('header_bar_shade_color'));
      expect(source, contains('header_bar_accent_color'));
      expect(source, contains('header_bar_accent_foreground_color'));
      expect(source, isNot(contains('kHeaderMenuFallbackBackgroundColor')));
      expect(source, isNot(contains('kHeaderMenuFallbackForegroundColor')));
      expect(source, contains('GTK_STYLE_CLASS_FLAT'));
      expect(source, isNot(contains('GTK_STYLE_CLASS_LINKED')));
      expect(source, isNot(contains('gtk_check_menu_item_new_with_label')));
      expect(source, isNot(contains('gtk_check_menu_item_set_active')));
      expect(
        source,
        isNot(contains('menuitem.busymax-header-view-mode-item:checked')),
      );
      expect(source, isNot(contains('busymax-header-view-mode-item-active')));
      expect(source, contains('create_header_popup_window'));
      expect(source, contains('busymax-header-primary-button'));
      expect(source, contains('fl_lookup_string_arg(args, "accentColor")'));
      expect(
        source,
        contains('fl_lookup_string_arg(args, "accentForegroundColor")'),
      );
      expect(source, isNot(contains('gtk_menu_new()')));
      expect(source, isNot(contains('gtk_menu_popup_at_widget')));
      expect(source, isNot(contains('gtk_menu_shell_append')));
      expect(source, isNot(contains('gtk_menu_popdown')));
      expect(
        headerBarSource,
        isNot(contains('gtk_window_set_skip_taskbar_hint')),
      );
      expect(
        headerBarSource,
        isNot(contains('gtk_window_set_skip_pager_hint')),
      );
      expect(source, isNot(contains('create_header_popup_box')));
      expect(source, isNot(contains('draw_header_popup_background_cb')));
      expect(source, isNot(contains('gtk_event_box_new()')));
      expect(source, isNot(contains('gtk_widget_set_app_paintable(popup')));
      expect(headerBarSource, isNot(contains('gtk_window_move')));
      expect(source, isNot(contains('override_header_menu_colors')));
      expect(source, isNot(contains('GTK_STYLE_PROVIDER_PRIORITY_USER')));
      expect(source, isNot(contains('add_header_menu_provider_to_widget')));
      expect(source, isNot(contains('gtk_widget_get_toplevel(menu)')));
      expect(source, contains('busymax-application'));
      expect(source, isNot(contains('gtk_widget_override_background_color')));
      expect(
        source,
        isNot(contains('gtk_popover_new(self->view_mode_button)')),
      );
      expect(source, contains('GtkWidget* view_mode_button;'));
      expect(source, contains('GtkWidget* view_mode_menu;'));
      expect(source, contains('GtkWidget* flutter_view;'));
      expect(source, contains('focus_flutter_view'));
      expect(source, contains('gtk_widget_grab_focus(self->flutter_view)'));
      expect(source, contains('track_widget_pointer(&self->flutter_view'));
      expect(source, contains('clear_widget_pointer(&self->flutter_view)'));
      expect(source, contains('kGtkSettingsChannel'));
      expect(source, contains('io.busystack.busymax/gtk_settings'));
      expect(source, contains('getGtkFont'));
      expect(source, contains('getGtkThemeColors'));
      expect(source, contains('kGtkThemeColorsEventChannel'));
      expect(source, contains('io.busystack.busymax/gtk_theme_colors'));
      expect(source, contains('notify::gtk-theme-name'));
      expect(source, contains('notify::gtk-application-prefer-dark-theme'));
      expect(source, contains('get_gtk_theme_colors'));
      expect(source, contains('lookup_context_color'));
      expect(source, contains('theme_bg_color'));
      expect(source, contains('theme_base_color'));
      expect(source, contains('GTK_STYLE_CLASS_SIDEBAR'));
      expect(source, contains('GTK_STYLE_CLASS_VIEW'));
      expect(source, contains('gtk_style_context_get_property'));
      expect(source, contains('"background-color"'));
      expect(source, isNot(contains('gtk_style_context_get_background_color')));
      expect(source, contains('parse_gtk_font_name'));
      expect(source, contains('gtk-font-name'));
      expect(source, contains('pango_font_description_from_string'));
      expect(source, contains('pango_font_description_get_family'));
      expect(source, contains('PANGO_SCALE'));
      expect(source, contains('register_gtk_settings_channel'));
      expect(source, isNot(contains('GtkWidget* day_button;')));
      expect(source, isNot(contains('GtkWidget* week_button;')));
      expect(source, isNot(contains('GtkWidget* month_button;')));
      expect(source, isNot(contains('GtkWidget* year_button;')));
      expect(source, isNot(contains('GtkWidget* agenda_button;')));
      expect(source, isNot(contains('create_header_text_button("Today"')));
      expect(source, isNot(contains('create_header_toggle_text_button("Day"')));
      expect(
        source,
        isNot(contains('create_header_toggle_text_button("Week"')),
      );
      expect(
        source,
        isNot(contains('create_header_toggle_text_button("Month"')),
      );
      expect(
        source,
        isNot(contains('create_header_toggle_text_button("Year"')),
      );
      expect(
        source,
        isNot(contains('create_header_toggle_text_button("Agenda"')),
      );
      expect(source, contains('create_header_view_mode_item(self, "year"'));
      expect(source, contains('return "viewModeYear"'));
      expect(source, contains('list-add-symbolic'));
      expect(
        source,
        contains(
          'connect_header_bar_action(self, self->create_button, "create")',
        ),
      );
      expect(source, contains('open-menu-symbolic'));
      expect(source, contains('create_header_settings_item'));
      expect(
        source,
        contains('button.busymax-header-button.busymax-sidebar-toggle:checked'),
      );
      expect(source, isNot(contains('"newItem"')));
      expect(source, isNot(contains('"openMenu"')));
    });

    test('native headerbar colors use semantic Dart payload fields', () {
      final source = File('linux/runner/my_application.cc').readAsStringSync();
      final barrierBackgroundStart = source.indexOf(
        '".busymax-titlebar.busymax-modal-barrier,"',
      );
      final barrierBackgroundEnd = source.indexOf(
        '".busymax-titlebar button.busymax-header-button,"',
        barrierBackgroundStart,
      );
      final barrierStart = source.indexOf(
        '".busymax-titlebar.busymax-modal-barrier label,"',
      );
      final barrierEnd = source.indexOf(
        '".busymax-titlebar button.busymax-header-icon-button {"',
        barrierStart,
      );

      expect(source, contains('"busymax-header-title"'));
      expect(source, contains('".busymax-titlebar .busymax-header-title {"'));
      expect(source, contains('"border: 1px solid %s;"'));
      expect(source, contains('"box-shadow: 0 6px 18px %s;"'));
      expect(source, contains('muted_foreground_color'));
      expect(
        source,
        contains('kDefaultHeaderBarBackgroundColor[] = "#1D1D20"'),
      );
      expect(
        source,
        contains('kDefaultHeaderBarSidebarBackgroundColor[] = "#2E2E32"'),
      );
      expect(source, contains('set_flutter_view_background_color'));
      expect(source, contains('header_bar_window_background_color'));
      expect(source, contains('"windowBackgroundColor"'));
      expect(
        source,
        contains('css_color_or(self->header_bar_window_background_color,'),
      );
      expect(
        source,
        isNot(contains('gdk_rgba_parse(&background_color, "#00000000")')),
      );
      expect(barrierBackgroundStart, isNonNegative);
      expect(barrierBackgroundEnd, isNonNegative);
      final barrierBackgroundCss = source.substring(
        barrierBackgroundStart,
        barrierBackgroundEnd,
      );
      expect(barrierBackgroundCss, contains('"background-color: %s;"'));
      expect(
        barrierBackgroundCss,
        contains('"headerbar.busymax-flat-headerbar:backdrop {"'),
      );
      expect(
        source,
        contains(
          'sidebar_background_color, modal_barrier_color, modal_barrier_color',
        ),
      );
      expect(barrierStart, isNonNegative);
      expect(barrierEnd, isNonNegative);
      final barrierCss = source.substring(barrierStart, barrierEnd);
      expect(barrierCss, contains('"color: %s;"'));
      expect(barrierCss, isNot(contains('rgba(255,255,255,0.38)')));
    });

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

    test('native GTK theme colors are streamed to Flutter', () {
      final source = File('linux/runner/my_application.cc').readAsStringSync();
      final headerBarService = File(
        'lib/src/platform/linux_header_bar_service.dart',
      ).readAsStringSync();
      final gtkFontService = File(
        'lib/src/platform/gtk_font_service.dart',
      ).readAsStringSync();
      final app = File('lib/src/app/busymax_app.dart').readAsStringSync();
      final compactApp = File(
        'lib/src/features/schedule/presentation/compact_agenda_app.dart',
      ).readAsStringSync();

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
      expect(source, contains('disconnect_gtk_theme_colors_signals'));
      expect(
        source,
        contains('g_clear_object(&self->gtk_theme_colors_event_channel)'),
      );
      expect(headerBarService, contains('required this.preferDark'));
      expect(headerBarService, contains("'preferDark': preferDark"));
      expect(
        app,
        contains(
          'final preferDark = Theme.of(context).brightness == Brightness.dark',
        ),
      );
      expect(app, contains('preferDark: preferDark'));
      expect(source, contains('static void set_gtk_theme_preference'));
      expect(
        source,
        contains('"gtk-application-prefer-dark-theme", prefer_dark'),
      );
      expect(source, contains('yaru_theme_name_for_preference'));
      expect(source, contains('available_gtk_theme_for_preference'));
      expect(source, contains('available_icon_theme_for_preference'));
      expect(source, contains('g_str_has_suffix(theme_name, "-dark")'));
      expect(source, contains('theme_selected_bg_color'));
      expect(source, contains('set_theme_color(result, "accent"'));
      expect(gtkFontService, contains('final Color? accent;'));
      expect(
        gtkFontService,
        contains("accent: _parseColor(value['accent'] as String?)"),
      );
      expect(
        app,
        contains(
          'ubuntuAccentColor ?? gtkThemeColors?.accent ?? systemColor.accent',
        ),
      );
      expect(
        compactApp,
        contains(
          'ubuntuAccentColor ?? gtkThemeColors?.accent ?? systemColor.accent',
        ),
      );
      expect(source, contains('gtk_icon_theme_set_custom_theme'));
      expect(source, contains('fl_lookup_optional_bool_arg'));
      expect(
        source,
        contains('fl_lookup_optional_bool_arg(args, "preferDark"'),
      );
      expect(source, contains('set_gtk_theme_preference(prefer_dark);'));
      expect(source, isNot(contains('prefer_dark_gtk_theme')));
      expect(source, isNot(contains('set_gtk_theme_preference(TRUE)')));
    });

    test('app code does not bypass centralized typography', () {
      final matches = <String>[];
      for (final file in _dartFilesIn('lib')) {
        final lines = file.readAsLinesSync();
        for (var index = 0; index < lines.length; index++) {
          final line = lines[index];
          final location = '${file.path}:${index + 1}';
          if (line.contains('fontFamily:') &&
              !file.path.endsWith('lib/src/app/busymax_yaru_theme.dart')) {
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

    test('shared menu button has no nested hover background', () {
      final source = File('lib/src/app/busymax_design.dart').readAsStringSync();

      expect(source, contains('class BusyMaxMenuButton'));
      expect(source, contains('class BusyMaxMenuEntry'));
      expect(source, contains('busyMaxDropdownMenuStyle'));
      expect(source, contains('busyMaxDropdownMenuItemStyle'));
      expect(source, contains('builder: (context, controller, child)'));
      expect(
        source,
        contains('side: const WidgetStatePropertyAll(BorderSide.none)'),
      );
      expect(
        source,
        contains(
          'surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent)',
        ),
      );
      expect(source, isNot(contains('_BusyMaxPopupMenuTrigger')));
      expect(source, isNot(contains('MouseRegion(')));
      expect(source, isNot(contains('AnimatedContainer(')));
      expect(
        source,
        isNot(contains('context.findRenderObject() as RenderBox')),
      );
    });

    test('feature code avoids raw Material controls with Yaru replacements', () {
      final files = [
        ..._dartFilesIn('lib/src/app'),
        ..._dartFilesIn('lib/src/features'),
      ];

      for (final file in files) {
        final lines = file.readAsLinesSync();
        for (var index = 0; index < lines.length; index++) {
          final line = lines[index];
          final location = '${file.path}:${index + 1}';
          expect(line, isNot(contains('AlertDialog')), reason: location);
          expect(
            line,
            isNot(contains('DropdownButtonFormField')),
            reason: location,
          );
          expect(_hasRawMenuAnchor(file, line), isFalse, reason: location);
          expect(
            _hasRawPopupMenuButton(file, line),
            isFalse,
            reason: '$location should use BusyMaxMenuButton/MenuButtonBuilder.',
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
            _hasRawIconButton(line),
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

bool _hasRawPopupMenuButton(File file, String line) {
  return line.contains('PopupMenuButton') &&
      !line.contains('YaruPopupMenuButton') &&
      !line.contains('BusyMaxMenuButton');
}

bool _hasRawPopupMenuEntry(File file, String line) {
  if (file.path.endsWith('lib/src/app/busymax_design.dart')) {
    return false;
  }
  return line.contains('PopupMenuItem') ||
      line.contains('YaruCheckedPopupMenuItem');
}

bool _hasRawMenuAnchor(File file, String line) {
  if (file.path.endsWith('lib/src/app/busymax_design.dart')) {
    return false;
  }
  return line.contains('MenuAnchor');
}

bool _hasRawCheckbox(String line) {
  return line.contains('Checkbox(') && !line.contains('YaruCheckbox(');
}

bool _hasRawSwitch(String line) {
  return line.contains('Switch(') && !line.contains('YaruSwitch(');
}

bool _hasRawIconButton(String line) {
  return line.contains('IconButton(') && !line.contains('YaruIconButton(');
}

bool _isAllowedFontSizeException(File file, String line) {
  if (file.path.endsWith('lib/src/app/busymax_yaru_theme.dart')) {
    return true;
  }
  return file.path.endsWith(
        'lib/src/features/tasks/presentation/desktop_date_time_fields.dart',
      ) &&
      line.contains('fontSize: 0');
}

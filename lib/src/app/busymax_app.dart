import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:system_theme/system_theme.dart';
import 'package:ubuntu_localizations/ubuntu_localizations.dart';

import '../platform/busymax_tray_service.dart';
import '../platform/gtk_font_service.dart';
import '../platform/linux_header_bar_configuration_synchronizer.dart';
import '../platform/linux_header_bar_service.dart';
import '../platform/linux_window_service.dart';
import '../platform/main_window_command_bridge.dart';
import 'app_bootstrap.dart';
import 'app_router.dart';
import 'busymax_keyboard_shortcuts_dialog.dart';
import 'busymax_shortcuts.dart';
import '../../l10n/generated/app_localizations.dart';
import 'busymax_yaru_theme.dart';
import 'busymax_design.dart';
import 'system_accent.dart';
import 'app_theme.dart';

typedef BusyMaxTrayServiceFactory =
    BusyMaxTrayService Function({
      required LinuxWindowService windowService,
      required BusyMaxTrayLabels labels,
      required Future<void> Function() onOpenAgenda,
      Future<void> Function()? onBeforeQuit,
    });

class BusyMaxApp extends ConsumerStatefulWidget {
  const BusyMaxApp({super.key, this.trayServiceFactory});

  @visibleForTesting
  final BusyMaxTrayServiceFactory? trayServiceFactory;

  @override
  ConsumerState<BusyMaxApp> createState() => _BusyMaxAppState();
}

class _BusyMaxAppState extends ConsumerState<BusyMaxApp> {
  BusyMaxTrayService? _trayService;
  bool? _lastHideOnClose;
  bool? _lastTrayEnabled;
  bool _startMinimizedHandled = false;
  bool _settingsReady = false;
  late final BusyMaxHeaderBarConfigurationSynchronizer
  _headerBarConfigurationSynchronizer;

  @override
  void initState() {
    super.initState();
    _headerBarConfigurationSynchronizer =
        BusyMaxHeaderBarConfigurationSynchronizer(
          ref.read(linuxHeaderBarServiceProvider),
        );
    unawaited(_waitForSettings());
  }

  @override
  void dispose() {
    _headerBarConfigurationSynchronizer.dispose();
    final tray = _trayService;
    if (tray != null) {
      unawaited(tray.stop());
    }
    super.dispose();
  }

  Future<void> _waitForSettings() async {
    await ref.read(appSettingsControllerProvider.notifier).ready;
    if (!mounted) {
      return;
    }
    setState(() => _settingsReady = true);
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);
    final settings = ref.watch(appSettingsControllerProvider);
    final ubuntuAccentColor = ref
        .watch(ubuntuSystemAccentColorProvider)
        .valueOrNull;
    final gtkFont = ref.watch(gtkFontSettingsProvider).valueOrNull;
    final gtkThemeColors = ref.watch(gtkThemeColorsProvider).valueOrNull;
    ref.watch(syncSchedulerProvider);
    ref.watch(notificationSchedulerProvider);
    ref.watch(dueTodayNotificationProvider);

    return SystemThemeBuilder(
      builder: (context, systemColor) {
        final accentColor =
            gtkThemeColors?.accent ?? ubuntuAccentColor ?? systemColor.accent;
        return MaterialApp.router(
          title: 'BusyMax',
          debugShowCheckedModeBanner: false,
          theme: buildBusyMaxTheme(
            brightness: Brightness.light,
            accentColor: accentColor,
            family: settings.themeFamily,
            gtkFontFamily: gtkFont?.family,
            gtkFontSize: gtkFont?.size,
            gtkThemeColors: gtkThemeColors,
          ),
          darkTheme: buildBusyMaxTheme(
            brightness: Brightness.dark,
            accentColor: accentColor,
            family: settings.themeFamily,
            gtkFontFamily: gtkFont?.family,
            gtkFontSize: gtkFont?.size,
            gtkThemeColors: gtkThemeColors,
          ),
          highContrastTheme: buildBusyMaxTheme(
            brightness: Brightness.light,
            accentColor: accentColor,
            family: settings.themeFamily,
            gtkFontFamily: gtkFont?.family,
            gtkFontSize: gtkFont?.size,
            gtkThemeColors: gtkThemeColors,
            highContrast: true,
          ),
          highContrastDarkTheme: buildBusyMaxTheme(
            brightness: Brightness.dark,
            accentColor: accentColor,
            family: settings.themeFamily,
            gtkFontFamily: gtkFont?.family,
            gtkFontSize: gtkFont?.size,
            gtkThemeColors: gtkThemeColors,
            highContrast: true,
          ),
          themeMode: settings.themeMode,
          localizationsDelegates: const [
            ...AppLocalizations.localizationsDelegates,
            ...GlobalUbuntuLocalizations.delegates,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) {
            final l10n = AppLocalizations.of(context);
            _configureNativeHeaderBarTheme(context);
            _configureBackgroundServices(
              ref,
              settings,
              BusyMaxTrayLabels(
                openBusyMax: l10n.compactAgendaOpenBusyMax,
                agenda: l10n.viewAgenda,
                quitBusyMax: l10n.exit,
              ),
            );
            return Shortcuts(
              shortcuts: const {
                BusyMaxShortcutActivators.keyboardShortcuts:
                    _KeyboardShortcutsIntent(),
                BusyMaxShortcutActivators.settings: _OpenSettingsIntent(),
              },
              child: Actions(
                actions: {
                  _KeyboardShortcutsIntent:
                      CallbackAction<_KeyboardShortcutsIntent>(
                        onInvoke: (intent) {
                          final navigatorContext =
                              rootNavigatorKey.currentContext;
                          if (navigatorContext != null) {
                            unawaited(
                              showBusyMaxKeyboardShortcutsDialog(
                                navigatorContext,
                                headerBarService: ref.read(
                                  linuxHeaderBarServiceProvider,
                                ),
                              ),
                            );
                          }
                          return null;
                        },
                      ),
                  _OpenSettingsIntent: CallbackAction<_OpenSettingsIntent>(
                    onInvoke: (intent) {
                      if (router.state.uri.path != '/settings') {
                        unawaited(router.push<void>('/settings'));
                      }
                      return null;
                    },
                  ),
                },
                child: MainWindowCommandBridge(
                  child: ColoredBox(
                    color: BusyMaxSurfaceColors.of(context).window,
                    child: child ?? const SizedBox.shrink(),
                  ),
                ),
              ),
            );
          },
          routerConfig: router,
        );
      },
    );
  }

  void _configureNativeHeaderBarTheme(BuildContext context) {
    final colors = BusyMaxSurfaceColors.of(context);
    final l10n = AppLocalizations.of(context);
    final materialL10n = MaterialLocalizations.of(context);
    final modalBarrierColor = busyMaxModalBarrierColor(context);
    final preferDark = Theme.of(context).brightness == Brightness.dark;
    final labels = BusyMaxHeaderBarLabels(
      today: l10n.today,
      day: l10n.viewDay,
      week: l10n.viewWeek,
      month: l10n.viewMonth,
      year: l10n.viewYear,
      agenda: l10n.viewAgenda,
      search: materialL10n.searchFieldLabel,
      create: l10n.create,
      createEvent: l10n.createEventAtTime,
      createTask: l10n.createTaskAtDate,
      refresh: l10n.refreshAll,
      menu: l10n.mainMenu,
      previous: materialL10n.previousPageTooltip,
      next: materialL10n.nextPageTooltip,
      sidebar: l10n.toggleSidebar,
      back: materialL10n.backButtonTooltip,
      settings: l10n.settings,
      keyboardShortcuts: l10n.keyboardShortcuts,
      aboutBusyMax: l10n.aboutBusyMax,
    );
    _headerBarConfigurationSynchronizer.schedule(
      BusyMaxHeaderBarConfiguration(
        labels: labels,
        sidebarWidth: BusyMaxSizes.sidebarWidth,
        theme: BusyMaxHeaderBarTheme(
          preferDark: preferDark,
          windowBackgroundColor: colors.window,
          // This header is deliberately borderless and visually continuous
          // with the main pane, so it uses the flat header role.
          backgroundColor: colors.headerbarFlat,
          sidebarBackgroundColor: colors.sidebar,
          foregroundColor: colors.foreground,
          sidebarBorderColor: colors.sidebarBorder,
          modalBarrierColor: modalBarrierColor,
        ),
      ),
    );
  }

  void _configureBackgroundServices(
    WidgetRef ref,
    AppSettings settings,
    BusyMaxTrayLabels labels,
  ) {
    if (!_settingsReady) {
      return;
    }

    final windowService = ref.read(linuxWindowServiceProvider);
    if (ref.read(buildConfigProvider).useFakeProviderData) {
      _lastTrayEnabled = false;
      _setHideOnClose(windowService, false);
      final tray = _trayService;
      if (tray != null) {
        unawaited(tray.stop());
      }
      return;
    }

    final trayEnabled =
        settings.showTrayIcon ||
        settings.runInBackgroundWhenClosed ||
        settings.startMinimizedToTray;
    _setHideOnClose(
      windowService,
      settings.runInBackgroundWhenClosed &&
          trayEnabled &&
          (_trayService?.available ?? false),
    );
    if (_trayService != null) {
      unawaited(_trayService!.updateLabels(labels));
    }
    if (_lastTrayEnabled == trayEnabled) {
      return;
    }
    _lastTrayEnabled = trayEnabled;
    final compactAgendaWindows = ref.read(compactAgendaWindowServiceProvider);
    final tray = _trayService ??= _createTrayService(
      windowService: windowService,
      labels: labels,
      onOpenAgenda: compactAgendaWindows.toggle,
      onBeforeQuit: compactAgendaWindows.closeIfOpen,
    );
    if (trayEnabled) {
      unawaited(
        _startTray(
          tray,
          windowService,
          startMinimizedToTray: settings.startMinimizedToTray,
        ),
      );
    } else {
      _setHideOnClose(windowService, false);
      unawaited(tray.stop());
    }
  }

  BusyMaxTrayService _createTrayService({
    required LinuxWindowService windowService,
    required BusyMaxTrayLabels labels,
    required Future<void> Function() onOpenAgenda,
    Future<void> Function()? onBeforeQuit,
  }) {
    final factory = widget.trayServiceFactory;
    if (factory != null) {
      return factory(
        windowService: windowService,
        labels: labels,
        onOpenAgenda: onOpenAgenda,
        onBeforeQuit: onBeforeQuit,
      );
    }
    return BusyMaxTrayService(
      windowService: windowService,
      labels: labels,
      onOpenAgenda: onOpenAgenda,
      onBeforeQuit: onBeforeQuit,
    );
  }

  void _setHideOnClose(LinuxWindowService windowService, bool enabled) {
    if (_lastHideOnClose == enabled) {
      return;
    }
    _lastHideOnClose = enabled;
    unawaited(windowService.setHideOnClose(enabled));
  }

  Future<void> _startTray(
    BusyMaxTrayService tray,
    LinuxWindowService windowService, {
    required bool startMinimizedToTray,
  }) async {
    await tray.start();
    if (!mounted) {
      await tray.stop();
      return;
    }

    final latestSettings = ref.read(appSettingsControllerProvider);
    final trayStillEnabled =
        latestSettings.showTrayIcon ||
        latestSettings.runInBackgroundWhenClosed ||
        latestSettings.startMinimizedToTray;
    if (!trayStillEnabled) {
      _setHideOnClose(windowService, false);
      await tray.stop();
      return;
    }
    _setHideOnClose(
      windowService,
      latestSettings.runInBackgroundWhenClosed && tray.available,
    );
    if (!startMinimizedToTray || _startMinimizedHandled || !tray.available) {
      return;
    }
    _startMinimizedHandled = true;
    await windowService.hideWindow();
  }
}

class _KeyboardShortcutsIntent extends Intent {
  const _KeyboardShortcutsIntent();
}

class _OpenSettingsIntent extends Intent {
  const _OpenSettingsIntent();
}

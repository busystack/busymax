import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:system_theme/system_theme.dart';
import 'package:ubuntu_localizations/ubuntu_localizations.dart';

import '../platform/busymax_tray_service.dart';
import '../platform/gtk_font_service.dart';
import '../platform/linux_header_bar_service.dart';
import '../platform/linux_window_service.dart';
import '../platform/main_window_command_bridge.dart';
import 'app_bootstrap.dart';
import 'app_router.dart';
import '../../l10n/generated/app_localizations.dart';
import 'busymax_yaru_theme.dart';
import 'busymax_design.dart';
import 'system_accent.dart';
import 'app_theme.dart';

class BusyMaxApp extends ConsumerStatefulWidget {
  const BusyMaxApp({super.key});

  @override
  ConsumerState<BusyMaxApp> createState() => _BusyMaxAppState();
}

class _BusyMaxAppState extends ConsumerState<BusyMaxApp> {
  BusyMaxTrayService? _trayService;
  bool? _lastHideOnClose;
  bool? _lastTrayEnabled;
  bool _startMinimizedHandled = false;

  @override
  void dispose() {
    final tray = _trayService;
    if (tray != null) {
      unawaited(tray.stop());
    }
    super.dispose();
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
        final accentColor = ubuntuAccentColor ?? systemColor.accent;

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
          themeMode: settings.themeMode,
          localizationsDelegates: const [
            ...AppLocalizations.localizationsDelegates,
            ...GlobalUbuntuLocalizations.delegates,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) {
            final l10n = AppLocalizations.of(context);
            _configureNativeHeaderBarTheme(context, ref);
            _configureBackgroundServices(
              ref,
              settings,
              BusyMaxTrayLabels(
                openBusyMax: l10n.compactAgendaOpenBusyMax,
                agenda: l10n.viewAgenda,
                quitBusyMax: l10n.exit,
              ),
            );
            return MainWindowCommandBridge(
              child: _BusyMaxWindowCornerClip(
                child: child ?? const SizedBox.shrink(),
              ),
            );
          },
          routerConfig: router,
        );
      },
    );
  }

  void _configureNativeHeaderBarTheme(BuildContext context, WidgetRef ref) {
    final colors = BusyMaxSurfaceColors.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    final materialL10n = MaterialLocalizations.of(context);
    final modalBarrierColor = Theme.of(
      context,
    ).colorScheme.scrim.withValues(alpha: 0.32);
    final labels = BusyMaxHeaderBarLabels(
      today: l10n.today,
      day: l10n.viewDay,
      week: l10n.viewWeek,
      month: l10n.viewMonth,
      year: l10n.viewYear,
      agenda: l10n.viewAgenda,
      search: materialL10n.searchFieldLabel,
      refresh: l10n.refreshAll,
      menu: l10n.mainMenu,
      previous: materialL10n.previousPageTooltip,
      next: materialL10n.nextPageTooltip,
      sidebar: l10n.toggleSidebar,
      back: materialL10n.backButtonTooltip,
      settings: l10n.settings,
      aboutBusyMax: l10n.aboutBusyMax,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final service = ref.read(linuxHeaderBarServiceProvider);
      unawaited(() async {
        await service.initialize();
        await service.setLocalizedLabels(labels);
        await service.setSidebarWidth(BusyMaxSizes.sidebarWidth);
        await service.setTheme(
          BusyMaxHeaderBarTheme(
            windowBackgroundColor: colors.window,
            backgroundColor: colors.view,
            sidebarBackgroundColor: colors.sidebar,
            foregroundColor: colors.foreground,
            mutedForegroundColor: colors.mutedForeground,
            disabledForegroundColor: colors.disabledForeground,
            controlColor: colors.control,
            controlHoverColor: colors.controlHover,
            controlActiveColor: colors.controlActive,
            accentColor: colorScheme.primary,
            accentForegroundColor: colorScheme.onPrimary,
            popoverBackgroundColor: colors.popover,
            borderColor: colors.border,
            shadeColor: colors.shade,
            modalBarrierColor: modalBarrierColor,
          ),
        );
      }());
    });
  }

  void _configureBackgroundServices(
    WidgetRef ref,
    AppSettings settings,
    BusyMaxTrayLabels labels,
  ) {
    final windowService = ref.read(linuxWindowServiceProvider);

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
    final tray = _trayService ??= BusyMaxTrayService(
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
          runInBackgroundWhenClosed: settings.runInBackgroundWhenClosed,
          startMinimizedToTray: settings.startMinimizedToTray,
        ),
      );
    } else {
      _setHideOnClose(windowService, false);
      unawaited(tray.stop());
    }
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
    required bool runInBackgroundWhenClosed,
    required bool startMinimizedToTray,
  }) async {
    await tray.start();
    if (!mounted) {
      return;
    }
    _setHideOnClose(windowService, runInBackgroundWhenClosed && tray.available);
    if (!startMinimizedToTray || _startMinimizedHandled || !tray.available) {
      return;
    }
    _startMinimizedHandled = true;
    await windowService.hideWindow();
  }
}

class _BusyMaxWindowCornerClip extends StatelessWidget {
  const _BusyMaxWindowCornerClip({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(
        bottom: Radius.circular(BusyMaxRadius.window),
      ),
      clipBehavior: Clip.antiAliasWithSaveLayer,
      child: ColoredBox(
        color: BusyMaxSurfaceColors.of(context).window,
        child: child,
      ),
    );
  }
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:system_theme/system_theme.dart';
import 'package:ubuntu_localizations/ubuntu_localizations.dart';

import '../platform/busymax_tray_service.dart';
import '../features/tray/domain/tray_presentation.dart';
import '../features/tray/domain/tray_presentation_formatter.dart';
import '../platform/gtk_font_service.dart';
import '../platform/linux_header_bar_configuration_synchronizer.dart';
import '../platform/linux_header_bar_provider.dart';
import '../platform/linux_header_bar_service.dart';
import '../platform/common/desktop_services.dart';
import '../l10n/locale_resolution.dart';
import '../schedule/schedule_commands.dart';
import 'app_bootstrap.dart';
import 'app_router.dart';
import 'busymax_keyboard_shortcuts_dialog.dart';
import 'busymax_shortcuts.dart';
import '../../l10n/generated/app_localizations.dart';
import 'busymax_yaru_theme.dart';
import 'busymax_design.dart';
import 'system_accent.dart';
import 'app_theme.dart';
import '../features/settings/presentation/settings_screen.dart';
import '../features/calendar/presentation/ical_import_flow.dart';

typedef BusyMaxTrayServiceFactory =
    BusyMaxTrayService Function(BusyMaxTrayServiceConfiguration configuration);

BusyMaxHeaderBarTheme busyMaxHeaderBarThemeFor(
  ThemeData theme, {
  required bool highContrast,
}) {
  final colors = theme.extension<BusyMaxSurfaceColors>()!;
  return BusyMaxHeaderBarTheme(
    preferDark: theme.brightness == Brightness.dark,
    highContrast: highContrast,
    windowBackgroundColor: colors.window,
    // This header is deliberately borderless and visually continuous with
    // the main workspace, so both use the window surface role.
    backgroundColor: colors.window,
    sidebarBackgroundColor: colors.sidebar,
    foregroundColor: colors.foreground,
    sidebarBorderColor: colors.sidebarBorder,
    dialogBackgroundColor: colors.dialog,
    dialogOutlineColor: colors.dialogOutline,
    modalBarrierColor: colors.shade,
    tooltip: BusyMaxHeaderBarTooltipTheme(
      backgroundColor: BusyMaxTooltipStyle.background,
      foregroundColor: BusyMaxTooltipStyle.foreground,
      borderColor: BusyMaxTooltipStyle.border,
      borderRadius: BusyMaxRadius.tooltip,
      fontSize: theme.tooltipTheme.textStyle?.fontSize ?? 14,
      horizontalPadding: BusyMaxSpacing.tooltipHorizontal,
      verticalPadding: BusyMaxSpacing.tooltipVertical,
      minimumHeight: BusyMaxSizes.tooltipMinHeight,
    ),
  );
}

class LinuxBusyMaxApp extends ConsumerStatefulWidget {
  const LinuxBusyMaxApp({
    super.key,
    this.trayServiceFactory,
    this.startMinimizedAtLaunch = false,
  });

  @visibleForTesting
  final BusyMaxTrayServiceFactory? trayServiceFactory;
  final bool startMinimizedAtLaunch;

  @override
  ConsumerState<LinuxBusyMaxApp> createState() => _BusyMaxAppState();
}

class BusyMaxApp extends LinuxBusyMaxApp {
  const BusyMaxApp({
    super.key,
    super.trayServiceFactory,
    super.startMinimizedAtLaunch,
  });
}

class _BusyMaxAppState extends ConsumerState<LinuxBusyMaxApp> {
  BusyMaxTrayService? _trayService;
  bool? _lastHideOnClose;
  bool? _lastTrayEnabled;
  bool _startMinimizedHandled = false;
  bool _settingsReady = false;
  var _scheduleCommandSequence = 0;
  BusyMaxTrayPresentationFormatter? _trayPresentationFormatter;
  StreamSubscription<DesktopActivation>? _externalOpenSubscription;
  StreamSubscription<DesktopNavigationRequest>? _navigationSubscription;
  Future<void> _externalOpenTail = Future<void>.value();
  late final BusyMaxHeaderBarConfigurationSynchronizer
  _headerBarConfigurationSynchronizer;

  @override
  void initState() {
    super.initState();
    _headerBarConfigurationSynchronizer =
        BusyMaxHeaderBarConfigurationSynchronizer(
          ref.read(linuxHeaderBarServiceProvider),
        );
    _externalOpenSubscription = ref
        .read(desktopActivationServiceProvider)
        .activations
        .listen((request) {
          _externalOpenTail = _externalOpenTail
              .catchError((Object _) {})
              .then((_) => _handleExternalCalendarOpen(request));
        });
    _navigationSubscription = ref
        .read(desktopNavigationServiceProvider)
        .requests
        .listen(_handleNavigationRequest);
    unawaited(_waitForSettings());
  }

  @override
  void dispose() {
    _headerBarConfigurationSynchronizer.dispose();
    unawaited(_externalOpenSubscription?.cancel());
    unawaited(_navigationSubscription?.cancel());
    final tray = _trayService;
    if (tray != null) {
      unawaited(tray.stop());
    }
    super.dispose();
  }

  Future<void> _handleExternalCalendarOpen(DesktopActivation request) async {
    if (!mounted) return;
    final router = ref.read(appRouterProvider);
    switch (request.kind) {
      case DesktopActivationKind.webCal:
        router.go('/settings?page=accounts');
      case DesktopActivationKind.icsFile:
        final session = ref.read(authSessionControllerProvider);
        router.go(session.isSignedIn ? '/schedule' : '/settings?page=accounts');
      case DesktopActivationKind.normalLaunch:
      case DesktopActivationKind.startMinimized:
      case DesktopActivationKind.notification:
        return;
    }
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    final dialogContext = rootNavigatorKey.currentContext;
    if (dialogContext == null || !dialogContext.mounted) return;
    switch (request.kind) {
      case DesktopActivationKind.webCal:
        await showAddCalendarSubscriptionFlow(
          dialogContext,
          ref,
          initialUrl: request.value!,
        );
      case DesktopActivationKind.icsFile:
        await showIcsImportFlow(dialogContext, ref, filePath: request.value!);
      case DesktopActivationKind.normalLaunch:
      case DesktopActivationKind.startMinimized:
      case DesktopActivationKind.notification:
        return;
    }
  }

  void _handleNavigationRequest(DesktopNavigationRequest request) {
    if (!mounted) return;
    final router = ref.read(appRouterProvider);
    router.go(switch (request.destination) {
      DesktopNavigationDestination.schedule => '/schedule',
      DesktopNavigationDestination.tasks => '/tasks',
      DesktopNavigationDestination.settings => '/settings',
      DesktopNavigationDestination.signIn => '/sign-in',
    });
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
    ref.watch(networkAvailabilityProvider);
    ref.watch(syncSchedulerProvider);
    ref.watch(syncSchedulerRunningProvider);
    ref.watch(networkReconnectSyncCoordinatorProvider);
    ref.watch(notificationSchedulerProvider);
    ref.watch(dueTodayNotificationProvider);

    return SystemThemeBuilder(
      builder: (context, systemColor) {
        final accentColor =
            gtkThemeColors?.accent ?? ubuntuAccentColor ?? systemColor.accent;
        return MaterialApp.router(
          onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
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
          locale: settings.locale,
          localizationsDelegates: const [
            ...AppLocalizations.localizationsDelegates,
            ...GlobalUbuntuLocalizations.delegates,
          ],
          localeListResolutionCallback: resolveBusyMaxLocales,
          supportedLocales: busyMaxSupportedLocales,
          builder: (context, child) {
            final l10n = AppLocalizations.of(context);
            final material = MaterialLocalizations.of(context);
            final alwaysUse24HourFormat = MediaQuery.alwaysUse24HourFormatOf(
              context,
            );
            final trayFormatter = BusyMaxTrayPresentationFormatter(
              BusyMaxTrayPresentationStrings(
                showBusyMax: l10n.trayShowBusyMax,
                newEvent: l10n.trayNewEvent,
                newTask: l10n.trayNewTask,
                today: l10n.trayToday,
                allDay: l10n.trayAllDay,
                now: l10n.trayNow,
                calendarEvent: l10n.trayCalendarEvent,
                untitledEvent: l10n.trayUntitledEvent,
                nothingElseToday: l10n.trayNothingElseToday,
                openTodayAgenda: l10n.trayOpenTodayAgenda,
                syncNow: l10n.traySyncNow,
                syncing: l10n.traySyncing,
                notConnected: l10n.trayNotConnected,
                notYetSynced: l10n.trayNotYetSynced,
                settings: l10n.traySettings,
                quitBusyMax: l10n.trayQuitBusyMax,
                offline: l10n.networkOffline,
                offlineDescription: l10n.networkOfflineDescription,
                formatTime: (value) => material.formatTimeOfDay(
                  TimeOfDay.fromDateTime(value),
                  alwaysUse24HourFormat: alwaysUse24HourFormat,
                ),
                tasksDueToday: l10n.trayTasksDueToday,
                lastSyncedJustNow: l10n.trayLastSyncedJustNow,
                lastSyncedMinutesAgo: l10n.trayLastSyncedMinutesAgo,
                lastSyncedHoursAgo: l10n.trayLastSyncedHoursAgo,
                lastSyncedDaysAgo: l10n.trayLastSyncedDaysAgo,
              ),
            );
            _trayPresentationFormatter = trayFormatter;
            _configureNativeHeaderBarTheme(context);
            _configureBackgroundServices(ref, settings, trayFormatter);
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
                child: ColoredBox(
                  color: BusyMaxSurfaceColors.of(context).window,
                  child: child ?? const SizedBox.shrink(),
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
    final l10n = AppLocalizations.of(context);
    final materialL10n = MaterialLocalizations.of(context);
    final theme = Theme.of(context);
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
      showSidebarPanel: l10n.showSidebar,
      hideSidebarPanel: l10n.hideSidebar,
      back: materialL10n.backButtonTooltip,
      settings: l10n.settings,
      keyboardShortcuts: l10n.keyboardShortcuts,
      reportIssue: l10n.reportAnIssue,
      aboutBusyMax: l10n.aboutBusyMax,
      todayShortcut: BusyMaxShortcutLabels.today,
      dayShortcut: BusyMaxShortcutLabels.dayView,
      weekShortcut: BusyMaxShortcutLabels.weekView,
      monthShortcut: BusyMaxShortcutLabels.monthView,
      yearShortcut: BusyMaxShortcutLabels.yearView,
      agendaShortcut: BusyMaxShortcutLabels.agendaView,
      searchShortcut: BusyMaxShortcutLabels.search,
      sidebarShortcut: BusyMaxShortcutLabels.sidebar,
      createEventShortcut: BusyMaxShortcutLabels.newEvent,
      createTaskShortcut: BusyMaxShortcutLabels.newTask,
      previousShortcut: BusyMaxShortcutLabels.previousPeriod,
      nextShortcut: BusyMaxShortcutLabels.nextPeriod,
      settingsShortcut: BusyMaxShortcutLabels.settings,
      keyboardShortcutsShortcut: BusyMaxShortcutLabels.keyboardShortcuts,
    );
    _headerBarConfigurationSynchronizer.schedule(
      BusyMaxHeaderBarConfiguration(
        labels: labels,
        sidebarWidth: BusyMaxSizes.sidebarWidth,
        textDirection: Directionality.of(context),
        theme: busyMaxHeaderBarThemeFor(
          theme,
          highContrast: MediaQuery.highContrastOf(context),
        ),
      ),
    );
  }

  void _configureBackgroundServices(
    WidgetRef ref,
    AppSettings settings,
    BusyMaxTrayPresentationFormatter trayFormatter,
  ) {
    if (!_settingsReady) {
      return;
    }

    final windowService = ref.read(desktopWindowServiceProvider);
    final trayEnabled =
        settings.showTrayIcon ||
        settings.runInBackgroundWhenClosed ||
        settings.startMinimizedToTray ||
        widget.startMinimizedAtLaunch;
    _setHideOnClose(
      windowService,
      settings.runInBackgroundWhenClosed &&
          trayEnabled &&
          (_trayService?.available ?? false),
    );
    if (_trayService != null) {
      unawaited(_trayService!.refreshPresentation());
    }
    if (_lastTrayEnabled == trayEnabled) {
      return;
    }
    _lastTrayEnabled = trayEnabled;
    final tray = _trayService ??= _createTrayService(
      windowService: windowService,
      formatter: trayFormatter,
      settings: settings,
    );
    unawaited(tray.refreshPresentation());
    if (trayEnabled) {
      unawaited(
        _startTray(
          tray,
          windowService,
          startMinimizedToTray:
              settings.startMinimizedToTray || widget.startMinimizedAtLaunch,
        ),
      );
    } else {
      _setHideOnClose(windowService, false);
      unawaited(tray.stop());
    }
  }

  BusyMaxTrayService _createTrayService({
    required DesktopWindowService windowService,
    required BusyMaxTrayPresentationFormatter formatter,
    required AppSettings settings,
  }) {
    final initialPresentation = formatter.format(
      BusyMaxTrayPresentation(
        connectivity: ref.read(networkConnectivityMonitorProvider).availability,
        synchronizationRunning: ref.read(syncSchedulerProvider).isRunning,
        lastSuccessfulSynchronizationUtc: null,
        events: const [],
        incompleteTasksDueToday: 0,
        canCreateEvent: false,
        canCreateTask: false,
        hasSyncEligibleAccount: false,
        notificationDetailLevel: settings.notificationDetailLevel,
        localNow: DateTime.now(),
      ),
    );
    final configuration = BusyMaxTrayServiceConfiguration(
      initialPresentation: initialPresentation,
      loadPresentation: _loadTrayPresentation,
      actions: BusyMaxTrayActions(
        showBusyMax: windowService.showWindow,
        newEvent: () => _openTrayNewEvent(windowService),
        newTask: () => _openTrayNewTask(windowService),
        openEvent: (event) => _openTrayEvent(windowService, event),
        openTasksDueToday: () => _openTrayTasksDueToday(windowService),
        openTodayAgenda: () => _openMainAgenda(windowService),
        synchronize: () => ref.read(syncSchedulerProvider).runNow(),
        openSettings: () => _openTraySettings(windowService),
        quitBusyMax: windowService.quitApp,
      ),
    );
    final factory = widget.trayServiceFactory;
    if (factory != null) {
      return factory(configuration);
    }
    return BusyMaxTrayService(configuration: configuration);
  }

  Future<BusyMaxTrayMenuPresentation> _loadTrayPresentation() async {
    final formatter = _trayPresentationFormatter;
    if (formatter == null) {
      throw StateError('Tray localization is not ready.');
    }
    final presentation = await ref.read(trayPresentationServiceProvider).load();
    return formatter.format(presentation);
  }

  Future<void> _openTrayNewEvent(DesktopWindowService windowService) async {
    await windowService.showWindow();
    ref.read(appRouterProvider).go('/schedule');
    _issueScheduleCommand(ScheduleWorkspaceCommandKind.newEvent);
  }

  Future<void> _openTrayNewTask(DesktopWindowService windowService) async {
    await windowService.showWindow();
    ref.read(appRouterProvider).go('/tasks');
    _issueScheduleCommand(ScheduleWorkspaceCommandKind.newTask);
  }

  Future<void> _openTrayEvent(
    DesktopWindowService windowService,
    BusyMaxTrayEventEntry event,
  ) async {
    await windowService.showWindow();
    ref.read(appRouterProvider).go('/schedule');
    _issueScheduleCommand(
      ScheduleWorkspaceCommandKind.openCalendarEvent,
      date: event.start,
      accountId: event.accountId,
      sourceId: event.calendarSourceId,
      itemId: event.eventId,
    );
  }

  Future<void> _openTrayTasksDueToday(
    DesktopWindowService windowService,
  ) async {
    await windowService.showWindow();
    ref.read(appRouterProvider).go('/tasks');
    _issueScheduleCommand(
      ScheduleWorkspaceCommandKind.agenda,
      date: DateTime.now(),
    );
  }

  Future<void> _openTraySettings(DesktopWindowService windowService) async {
    await windowService.showWindow();
    ref.read(appRouterProvider).go('/settings');
  }

  Future<void> _openMainAgenda(DesktopWindowService windowService) async {
    await windowService.showWindow();
    ref.read(appRouterProvider).go('/schedule');
    _issueScheduleCommand(
      ScheduleWorkspaceCommandKind.agenda,
      date: DateTime.now(),
    );
  }

  void _issueScheduleCommand(
    ScheduleWorkspaceCommandKind kind, {
    DateTime? date,
    String? accountId,
    String? sourceId,
    String? itemId,
  }) {
    ref
        .read(scheduleWorkspaceCommandProvider.notifier)
        .state = ScheduleWorkspaceCommand(
      kind,
      ++_scheduleCommandSequence,
      date: date,
      accountId: accountId,
      sourceId: sourceId,
      itemId: itemId,
    );
  }

  void _setHideOnClose(DesktopWindowService windowService, bool enabled) {
    if (_lastHideOnClose == enabled) {
      return;
    }
    _lastHideOnClose = enabled;
    unawaited(windowService.setHideOnClose(enabled));
  }

  Future<void> _startTray(
    BusyMaxTrayService tray,
    DesktopWindowService windowService, {
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
        latestSettings.startMinimizedToTray ||
        widget.startMinimizedAtLaunch;
    if (!trayStillEnabled) {
      _setHideOnClose(windowService, false);
      await tray.stop();
      return;
    }
    _setHideOnClose(
      windowService,
      latestSettings.runInBackgroundWhenClosed && tray.available,
    );
    if (!startMinimizedToTray || _startMinimizedHandled) {
      return;
    }
    _startMinimizedHandled = true;
    if (tray.available) {
      await windowService.hideWindow();
    } else {
      await windowService.showWindow();
    }
  }
}

class _KeyboardShortcutsIntent extends Intent {
  const _KeyboardShortcutsIntent();
}

class _OpenSettingsIntent extends Intent {
  const _OpenSettingsIntent();
}

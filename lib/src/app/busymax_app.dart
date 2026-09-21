import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:system_theme/system_theme.dart';
import 'package:ubuntu_localizations/ubuntu_localizations.dart';

import '../platform/busymax_tray_service.dart';
import '../features/tray/domain/tray_presentation.dart';
import '../features/tray/domain/tray_presentation_formatter.dart';
import '../platform/gtk_font_service.dart';
import '../platform/gtk_animation_settings_service.dart';
import '../platform/linux_first_weekday_source.dart';
import '../platform/native_style.dart';
import '../platform/common/desktop_services.dart';
import '../l10n/locale_resolution.dart';
import '../l10n/time_format_scope.dart';
import '../l10n/week_preferences_scope.dart';
import '../schedule/schedule_commands.dart';
import 'app_bootstrap.dart';
import 'desktop_startup_policy.dart';
import 'app_router.dart';
import 'busymax_keyboard_shortcuts_dialog.dart';
import 'busymax_shortcuts.dart';
import 'busymax_window_close.dart';
import '../../l10n/generated/app_localizations.dart';
import 'busymax_yaru_theme.dart';
import 'busymax_design.dart';
import 'system_accent.dart';
import 'app_theme.dart';
import 'linux/linux_window_host.dart';
import '../features/settings/presentation/settings_screen.dart';
import '../features/calendar/presentation/ical_import_flow.dart';
import '../core/logging/redacting_logger.dart';
import 'common/desktop_calendar_open_readiness.dart';

typedef BusyMaxTrayServiceFactory =
    BusyMaxTrayService Function(BusyMaxTrayServiceConfiguration configuration);

BusyMaxNativeSurfaceTheme busyMaxNativeSurfaceThemeFor(
  ThemeData theme, {
  required bool highContrast,
}) {
  final colors = theme.extension<BusyMaxSurfaceColors>()!;
  return BusyMaxNativeSurfaceTheme(
    highContrast: highContrast,
    windowBackgroundColor: colors.window,
    dialogBackgroundColor: colors.dialog,
    dialogOutlineColor: colors.dialogOutline,
    tooltipBackgroundColor: BusyMaxTooltipStyle.background,
    tooltipForegroundColor: BusyMaxTooltipStyle.foreground,
    tooltipBorderColor: BusyMaxTooltipStyle.border,
    tooltipRadius: BusyMaxRadius.tooltip,
    tooltipFontSize: theme.tooltipTheme.textStyle?.fontSize ?? 14,
    tooltipHorizontalPadding: BusyMaxSpacing.tooltipHorizontal,
    tooltipVerticalPadding: BusyMaxSpacing.tooltipVertical,
    tooltipMinimumHeight: BusyMaxSizes.tooltipMinHeight,
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
  final _logger = RedactingLogger(Logger('LinuxBusyMaxApp'));
  final _calendarOpenReadiness = DesktopCalendarOpenReadiness();
  final _windowCloseCoordinator = BusyMaxWindowCloseCoordinator();
  late final BusyMaxSystemFirstWeekdayController _firstWeekdayController;
  BusyMaxTrayService? _trayService;
  bool? _lastHideOnClose;
  bool? _lastTrayEnabled;
  late final _startupPolicy = DesktopStartupPolicy(
    startMinimizedAtLaunch: widget.startMinimizedAtLaunch,
  );
  bool _backgroundConfigurationRunning = false;
  bool _backgroundConfigurationPending = false;
  bool _settingsReady = false;
  var _scheduleCommandSequence = 0;
  BusyMaxTrayPresentationFormatter? _trayPresentationFormatter;
  StreamSubscription<DesktopActivation>? _externalOpenSubscription;
  StreamSubscription<DesktopNavigationRequest>? _navigationSubscription;
  Future<void> _externalOpenTail = Future<void>.value();
  BusyMaxNativeSurfaceTheme? _nativeSurfaceTheme;
  var _nativeSurfaceThemeRevision = 0;
  Future<void>? _quitRequest;

  @override
  void initState() {
    super.initState();
    _firstWeekdayController = BusyMaxSystemFirstWeekdayController(
      const LinuxFirstWeekdaySource(),
    )..addListener(_weekPreferenceChanged);
    _externalOpenSubscription = ref
        .read(desktopActivationServiceProvider)
        .activations
        .listen((request) {
          final operation = _externalOpenTail.then(
            (_) => _handleExternalCalendarOpen(request),
          );
          _externalOpenTail = operation.catchError((Object error) {
            _logger.warning(
              'Calendar-open operation failed (${error.runtimeType}).',
            );
          });
        });
    _navigationSubscription = ref
        .read(desktopNavigationServiceProvider)
        .requests
        .listen(_handleNavigationRequest);
    unawaited(_waitForSettings());
  }

  @override
  void dispose() {
    _calendarOpenReadiness.dispose();
    _firstWeekdayController
      ..removeListener(_weekPreferenceChanged)
      ..dispose();
    _nativeSurfaceThemeRevision += 1;
    unawaited(_externalOpenSubscription?.cancel());
    unawaited(_navigationSubscription?.cancel());
    final tray = _trayService;
    if (tray != null) {
      unawaited(tray.stop());
    }
    super.dispose();
  }

  void _weekPreferenceChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _handleExternalCalendarOpen(DesktopActivation request) async {
    if (request.kind != DesktopActivationKind.webCal &&
        request.kind != DesktopActivationKind.icsFile) {
      return;
    }
    if (!mounted || !_calendarOpenReadiness.isActive) return;
    if (!await _calendarOpenReadiness.waitFor(
      ref.read(appSettingsControllerProvider.notifier).ready,
    )) {
      return;
    }
    if (!mounted || !_calendarOpenReadiness.isActive) return;
    final settings = ref.read(appSettingsControllerProvider);
    if (settings.firstDayOfWeekPreference ==
            BusyMaxFirstDayOfWeekPreference.system &&
        !_firstWeekdayController.isInitialized) {
      if (!await _calendarOpenReadiness.waitFor(
        _firstWeekdayController.ready,
      )) {
        return;
      }
    }
    if (!mounted || !_calendarOpenReadiness.isActive) return;

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
    final dialogContext = await _calendarOpenReadiness.waitForRootNavigator(
      rootNavigatorKey,
    );
    if (!mounted ||
        dialogContext == null ||
        !dialogContext.mounted ||
        !_calendarOpenReadiness.isUsableRootNavigator(
          rootNavigatorKey,
          dialogContext,
        )) {
      return;
    }
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
    final gtkAnimationsEnabled =
        ref.watch(gtkAnimationsEnabledProvider).valueOrNull ?? true;
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
            final clock = BusyMaxTimeFormatter(
              locale: Localizations.localeOf(context).toLanguageTag(),
              use24Hour: resolveBusyMax24HourClock(
                settings.timeFormatPreference,
                systemUses24Hour: MediaQuery.alwaysUse24HourFormatOf(context),
              ),
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
                formatTime: clock.format,
                tasksDueToday: l10n.trayTasksDueToday,
                lastSyncedJustNow: l10n.trayLastSyncedJustNow,
                lastSyncedMinutesAgo: l10n.trayLastSyncedMinutesAgo,
                lastSyncedHoursAgo: l10n.trayLastSyncedHoursAgo,
                lastSyncedDaysAgo: l10n.trayLastSyncedDaysAgo,
              ),
            );
            _trayPresentationFormatter = trayFormatter;
            _configureNativeSurfaceTheme(context);
            _configureBackgroundServices(ref, settings, trayFormatter);
            return LinuxApplicationMediaQuery(
              alwaysUse24HourFormat: clock.use24Hour,
              gtkAnimationsEnabled: gtkAnimationsEnabled,
              child: LinuxWindowHost(
                closeCoordinator: _windowCloseCoordinator,
                child: Shortcuts(
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
                      child: BusyMaxTimeFormatScope(
                        formatter: clock,
                        child: BusyMaxWeekPreferencesScope(
                          preference: settings.firstDayOfWeekPreference,
                          systemWeekday: _firstWeekdayController.value,
                          platformLocaleTag: WidgetsBinding
                              .instance
                              .platformDispatcher
                              .locale
                              .toLanguageTag(),
                          child: BusyMaxWeekPreferencesStartupGate(
                            preference: settings.firstDayOfWeekPreference,
                            systemValueInitialized:
                                _firstWeekdayController.isInitialized,
                            child: child ?? const SizedBox.shrink(),
                          ),
                        ),
                      ),
                    ),
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

  void _configureNativeSurfaceTheme(BuildContext context) {
    final theme = Theme.of(context);
    final value = busyMaxNativeSurfaceThemeFor(
      theme,
      highContrast: MediaQuery.highContrastOf(context),
    );
    if (_nativeSurfaceTheme == value) return;
    _nativeSurfaceTheme = value;
    final revision = ++_nativeSurfaceThemeRevision;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || revision != _nativeSurfaceThemeRevision) return;
      unawaited(const NativeSurfaceStyleService().setTheme(value));
    });
  }

  void _configureBackgroundServices(
    WidgetRef ref,
    AppSettings settings,
    BusyMaxTrayPresentationFormatter trayFormatter,
  ) {
    if (!_settingsReady) {
      return;
    }
    if (_backgroundConfigurationRunning) {
      _backgroundConfigurationPending = true;
      return;
    }
    unawaited(_applyBackgroundServices(settings, trayFormatter));
  }

  Future<void> _applyBackgroundServices(
    AppSettings settings,
    BusyMaxTrayPresentationFormatter trayFormatter,
  ) async {
    _backgroundConfigurationRunning = true;
    try {
      final windowService = ref.read(desktopWindowServiceProvider);
      final trayEnabled = _startupPolicy.needsTray(settings);
      final startMinimized = _startupPolicy.takeStartMinimized(settings);
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
        await _startTray(
          tray,
          windowService,
          startMinimizedToTray: startMinimized,
        );
      } else {
        _setHideOnClose(windowService, false);
        if (!await windowService.isWindowVisible()) {
          await windowService.showWindow();
        }
        await tray.stop();
      }
    } finally {
      _backgroundConfigurationRunning = false;
      if (_backgroundConfigurationPending && mounted) {
        _backgroundConfigurationPending = false;
        _configureBackgroundServices(
          ref,
          ref.read(appSettingsControllerProvider),
          trayFormatter,
        );
      }
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
        quitBusyMax: () => _requestQuit(windowService),
      ),
    );
    final factory = widget.trayServiceFactory;
    if (factory != null) {
      return factory(configuration);
    }
    return BusyMaxTrayService(configuration: configuration);
  }

  Future<BusyMaxTrayMenuPresentation> _loadTrayPresentation() async {
    if (_trayPresentationFormatter == null) {
      throw StateError('Tray localization is not ready.');
    }
    final presentation = await ref.read(trayPresentationServiceProvider).load();
    return _trayPresentationFormatter!.format(presentation);
  }

  Future<void> _openTrayNewEvent(DesktopWindowService windowService) async {
    await windowService.showWindow();
    ref.read(appRouterProvider).go('/schedule');
    _issueScheduleCommand(ScheduleWorkspaceCommandKind.newEvent);
  }

  Future<void> _requestQuit(DesktopWindowService windowService) {
    final pending = _quitRequest;
    if (pending != null) return pending;
    final request = _performQuitRequest(windowService);
    _quitRequest = request;
    return request.whenComplete(() {
      if (identical(_quitRequest, request)) {
        _quitRequest = null;
      }
    });
  }

  Future<void> _performQuitRequest(DesktopWindowService windowService) async {
    if (_windowCloseCoordinator.hasActiveHandler) {
      await windowService.showWindow();
    }
    if (await _windowCloseCoordinator.requestClose()) {
      await windowService.quitApp();
    }
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
    final trayStillEnabled = _startupPolicy.needsTray(latestSettings);
    if (!trayStillEnabled) {
      _setHideOnClose(windowService, false);
      await windowService.showWindow();
      await tray.stop();
      return;
    }
    _setHideOnClose(
      windowService,
      latestSettings.runInBackgroundWhenClosed && tray.available,
    );
    if (!startMinimizedToTray) {
      return;
    }
    if (tray.available) {
      await windowService.hideWindow();
    } else {
      await windowService.showWindow();
    }
  }
}

/// Applies BusyMax's effective Linux platform policy without discarding any
/// inherited display or accessibility metrics.
@visibleForTesting
class LinuxApplicationMediaQuery extends StatelessWidget {
  const LinuxApplicationMediaQuery({
    super.key,
    required this.alwaysUse24HourFormat,
    required this.gtkAnimationsEnabled,
    required this.child,
  });

  final bool alwaysUse24HourFormat;
  final bool gtkAnimationsEnabled;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(
        alwaysUse24HourFormat: alwaysUse24HourFormat,
        disableAnimations:
            MediaQuery.disableAnimationsOf(context) || !gtkAnimationsEnabled,
      ),
      child: child,
    );
  }
}

class _KeyboardShortcutsIntent extends Intent {
  const _KeyboardShortcutsIntent();
}

class _OpenSettingsIntent extends Intent {
  const _OpenSettingsIntent();
}

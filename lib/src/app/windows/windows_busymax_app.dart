import 'dart:async';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../features/auth/data/auth_repository.dart';
import '../../l10n/locale_resolution.dart';
import '../../l10n/time_format_scope.dart';
import '../../l10n/week_preferences_scope.dart';
import '../../platform/windows/windows_clock_preference.dart';
import '../../platform/windows/windows_first_weekday_source.dart';
import '../../platform/common/desktop_services.dart';
import '../../ui/windows/windows_schedule_page.dart';
import '../../ui/windows/windows_settings_page.dart';
import '../../ui/windows/windows_sign_in_page.dart';
import '../../ui/windows/windows_tasks_page.dart';
import '../../ui/windows/windows_workspace_shell.dart';
import '../../ui/windows/windows_desktop_runtime.dart';
import '../../ui/windows/windows_calendar_activation_flows.dart';
import '../app_bootstrap.dart';

final windowsRootNavigatorKey = GlobalKey<NavigatorState>();

final windowsAppRouter = GoRouter(
  navigatorKey: windowsRootNavigatorKey,
  initialLocation: '/',
  routes: [
    GoRoute(path: '/', builder: (_, _) => const _WindowsHomeGate()),
    GoRoute(
      path: '/sign-in',
      builder: (_, state) => WindowsSignInPage(
        addingAccount: state.uri.queryParameters['add'] == 'true',
      ),
    ),
    GoRoute(
      path: '/schedule',
      builder: (_, _) => const WindowsWorkspaceShell(
        destination: WindowsWorkspaceDestination.schedule,
        child: WindowsSchedulePage(),
      ),
    ),
    GoRoute(
      path: '/tasks',
      builder: (_, _) => const WindowsWorkspaceShell(
        destination: WindowsWorkspaceDestination.tasks,
        child: WindowsTasksPage(),
      ),
    ),
    GoRoute(
      path: '/settings',
      builder: (_, _) => const WindowsWorkspaceShell(
        destination: WindowsWorkspaceDestination.settings,
        child: WindowsSettingsPage(),
      ),
    ),
  ],
);

class WindowsBusyMaxApp extends ConsumerStatefulWidget {
  const WindowsBusyMaxApp({super.key, this.startMinimizedAtLaunch = false});

  final bool startMinimizedAtLaunch;

  @override
  ConsumerState<WindowsBusyMaxApp> createState() => _WindowsBusyMaxAppState();
}

class _WindowsBusyMaxAppState extends ConsumerState<WindowsBusyMaxApp>
    with WidgetsBindingObserver {
  StreamSubscription<DesktopActivation>? _activationSubscription;
  StreamSubscription<DesktopNavigationRequest>? _navigationSubscription;
  StreamSubscription<void>? _appearanceSubscription;
  late final WindowsClockPreference _clockPreference;
  late final BusyMaxSystemFirstWeekdayController _firstWeekdayController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _clockPreference = WindowsClockPreference()..addListener(_platformChanged);
    _firstWeekdayController = BusyMaxSystemFirstWeekdayController(
      WindowsFirstWeekdaySource(),
    )..addListener(_platformChanged);
    _activationSubscription = ref
        .read(desktopActivationServiceProvider)
        .activations
        .listen(_handleActivation);
    _navigationSubscription = ref
        .read(desktopNavigationServiceProvider)
        .requests
        .listen(_handleNavigation);
    _appearanceSubscription = ref
        .read(systemAppearanceSourceProvider)
        .changes
        .listen((_) => _platformChanged());
  }

  @override
  void didChangeAccessibilityFeatures() => _platformChanged();

  @override
  void didChangePlatformBrightness() => _platformChanged();

  void _platformChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _handleActivation(DesktopActivation activation) async {
    if (!activation.isValid) return;
    if (activation.requiresVisibleWindow) {
      await ref.read(desktopWindowServiceProvider).showWindow();
    }
    switch (activation.kind) {
      case DesktopActivationKind.normalLaunch:
        windowsAppRouter.go('/');
      case DesktopActivationKind.startMinimized:
        return;
      case DesktopActivationKind.icsFile:
        windowsAppRouter.go('/schedule');
        await WidgetsBinding.instance.endOfFrame;
        final context = windowsRootNavigatorKey.currentContext;
        if (context != null && context.mounted) {
          await showWindowsIcsImportFlow(
            context,
            ref,
            filePath: activation.value,
          );
        }
      case DesktopActivationKind.webCal:
        windowsAppRouter.go('/settings');
        await WidgetsBinding.instance.endOfFrame;
        final context = windowsRootNavigatorKey.currentContext;
        if (context != null && context.mounted) {
          await showWindowsWebCalSubscriptionFlow(
            context,
            ref,
            initialUrl: activation.value,
          );
        }
      case DesktopActivationKind.notification:
        final destination = activation.notificationDestination;
        if (destination != null) {
          _handleNavigation(DesktopNavigationRequest(destination));
          return;
        }
        final scheduleId = activation.payload?['notificationScheduleId'];
        if (scheduleId == null) return;
        await ref
            .read(notificationSchedulerProvider)
            .handleActivation(
              notificationScheduleId: scheduleId,
              notificationGeneration:
                  activation.payload?['notificationGeneration'] ?? 'legacy',
              action: activation.action!,
            );
        if (activation.action == 'default' || activation.action == 'open') {
          windowsAppRouter.go('/schedule');
        }
    }
  }

  void _handleNavigation(DesktopNavigationRequest request) {
    windowsAppRouter.go(switch (request.destination) {
      DesktopNavigationDestination.schedule => '/schedule',
      DesktopNavigationDestination.tasks => '/tasks',
      DesktopNavigationDestination.settings => '/settings',
      DesktopNavigationDestination.signIn => '/sign-in',
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _clockPreference.dispose();
    _firstWeekdayController
      ..removeListener(_platformChanged)
      ..dispose();
    unawaited(_activationSubscription?.cancel());
    unawaited(_navigationSubscription?.cancel());
    unawaited(_appearanceSubscription?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(notificationSchedulerProvider);
    ref.watch(dueTodayNotificationProvider);
    final settings = ref.watch(appSettingsControllerProvider);
    final dispatcher = WidgetsBinding.instance.platformDispatcher;
    final appearance = ref.watch(systemAppearanceSourceProvider);
    final highContrast = appearance.highContrast;
    final reducedMotion = dispatcher.accessibilityFeatures.disableAnimations;
    final accentColor = appearance.accentColor?.toAccentColor();
    FluentThemeData theme(Brightness brightness) {
      final background = brightness == Brightness.dark
          ? Colors.black
          : Colors.white;
      final foreground = brightness == Brightness.dark
          ? Colors.white
          : Colors.black;
      return FluentThemeData(
        brightness: brightness,
        accentColor: highContrast ? foreground.toAccentColor() : accentColor,
        activeColor: highContrast ? background : null,
        inactiveColor: highContrast ? foreground : null,
        typography: _windowsTypography(brightness),
        scaffoldBackgroundColor: highContrast ? background : null,
        cardColor: highContrast ? background : null,
        menuColor: highContrast ? background : null,
        shadowColor: highContrast ? foreground : null,
        fasterAnimationDuration: reducedMotion ? Duration.zero : null,
        fastAnimationDuration: reducedMotion ? Duration.zero : null,
        mediumAnimationDuration: reducedMotion ? Duration.zero : null,
        slowAnimationDuration: reducedMotion ? Duration.zero : null,
      );
    }

    return FluentApp.router(
      title: 'BusyMax',
      debugShowCheckedModeBanner: false,
      routerConfig: windowsAppRouter,
      theme: theme(Brightness.light),
      darkTheme: theme(Brightness.dark),
      themeMode: settings.themeMode,
      locale: settings.locale,
      // FluentApp appends Fluent and framework delegates. BusyMax adds only
      // its generated delegate here; Ubuntu delegates remain Linux-only.
      localizationsDelegates: const [AppLocalizations.delegate],
      localeListResolutionCallback: resolveBusyMaxLocales,
      supportedLocales: busyMaxSupportedLocales,
      builder: (context, child) {
        final clock = BusyMaxTimeFormatter(
          locale: Localizations.localeOf(context).toLanguageTag(),
          use24Hour: resolveBusyMax24HourClock(
            settings.timeFormatPreference,
            systemUses24Hour:
                _clockPreference.value ??
                MediaQuery.alwaysUse24HourFormatOf(context),
          ),
        );
        return BusyMaxTimeFormatScope(
          formatter: clock,
          child: BusyMaxWeekPreferencesScope(
            preference: settings.firstDayOfWeekPreference,
            systemWeekday: _firstWeekdayController.value,
            platformLocaleTag: WidgetsBinding.instance.platformDispatcher.locale
                .toLanguageTag(),
            child: MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(alwaysUse24HourFormat: clock.use24Hour),
              child: WindowsDesktopRuntime(
                startMinimizedAtLaunch: widget.startMinimizedAtLaunch,
                child: child ?? const SizedBox.shrink(),
              ),
            ),
          ),
        );
      },
    );
  }
}

Typography _windowsTypography(Brightness brightness) {
  final defaults = Typography.fromBrightness(brightness: brightness);
  TextStyle? windowsFont(TextStyle? style) => style?.copyWith(
    fontFamily: 'Segoe UI Variable',
    fontFamilyFallback: const ['Segoe UI'],
  );
  return Typography.raw(
    display: windowsFont(defaults.display),
    titleLarge: windowsFont(defaults.titleLarge),
    title: windowsFont(defaults.title),
    subtitle: windowsFont(defaults.subtitle),
    bodyLarge: windowsFont(defaults.bodyLarge),
    bodyStrong: windowsFont(defaults.bodyStrong),
    body: windowsFont(defaults.body),
    caption: windowsFont(defaults.caption),
  );
}

class _WindowsHomeGate extends ConsumerWidget {
  const _WindowsHomeGate();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authSessionControllerProvider);
    return switch (session.status) {
      AuthSessionStatus.loading => const Center(child: ProgressRing()),
      AuthSessionStatus.signedIn => const WindowsWorkspaceShell(
        destination: WindowsWorkspaceDestination.schedule,
        child: WindowsSchedulePage(),
      ),
      _ => const WindowsSignInPage(),
    };
  }
}

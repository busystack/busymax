import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:system_theme/system_theme.dart';
import 'package:logging/logging.dart';

import 'src/app/app_bootstrap.dart';
import 'src/app/windows/windows_busymax_app.dart';
import 'src/config/build_config.dart';
import 'src/core/logging/redacting_logger.dart';
import 'src/core/secrets/secret_store.dart';
import 'src/demo/demo_profile.dart';
import 'src/features/notifications/desktop_notification_backend.dart';
import 'src/platform/common/desktop_services.dart';
import 'src/platform/windows/windows_activation_service.dart';
import 'src/platform/windows/windows_autostart_service.dart';
import 'src/platform/windows/windows_notification_backend.dart';
import 'src/platform/windows/windows_secret_storage_presentation.dart';
import 'src/platform/windows/windows_system_appearance_source.dart';
import 'src/platform/windows/windows_time_zone_source.dart';
import 'src/platform/windows/windows_window_service.dart';

Future<void> main(List<String> arguments) async {
  final binding = WidgetsFlutterBinding.ensureInitialized();
  binding.deferFirstFrame();
  // Platform initialization failures must be captured, but only through the
  // repository's redacting logger.
  configureLogging();
  final buildConfig = BuildConfig.fromEnvironment();
  if (arguments.contains(busyMaxNotificationForwarderArgument)) {
    await _runNotificationActivationForwarder(buildConfig);
    return;
  }
  final LocalSettingsStore settingsStore;
  if (buildConfig.useFakeProviderData) {
    final settings = busyMaxDemoSettings(buildConfig.demoTheme);
    settingsStore = InMemoryLocalSettingsStore(settings.toJson());
  } else {
    settingsStore = const JsonFileLocalSettingsStore();
  }

  await SystemTheme.accentColor.load();
  final initialSettings = await loadInitialAppSettings(settingsStore);
  final timeZoneSource = WindowsLocalTimeZoneSource();
  final localTimeZone = await timeZoneSource.currentIanaTimeZone();
  final activationService = WindowsActivationService();
  await activationService.initialize();
  final appearanceSource = WindowsSystemAppearanceSource();
  DesktopNotificationBackend notificationBackend =
      const DisabledDesktopNotificationBackend();
  DesktopNotificationReadiness? notificationReadiness;
  bool packaged;
  try {
    packaged = await WindowsNotificationBackend.hasPackageIdentity();
  } on Object {
    packaged = false;
    final installedFailure = buildConfig.windowsStoreMode;
    notificationReadiness = DesktopNotificationReadiness(
      installedFailure
          ? DesktopNotificationReadinessState.failedInstalledPackage
          : DesktopNotificationReadinessState.unavailableUnpackaged,
      diagnosticCode: 'windows-notifications/package-identity-query-failed',
    );
    Logger(
      'busymax.windows.notifications',
    ).severe('Windows notification package identity could not be queried.');
  }
  if (notificationReadiness != null) {
    // The failed identity probe above already selected the only safe backend.
  } else if (!packaged) {
    final installedFailure = buildConfig.windowsStoreMode;
    notificationReadiness = DesktopNotificationReadiness(
      installedFailure
          ? DesktopNotificationReadinessState.failedInstalledPackage
          : DesktopNotificationReadinessState.unavailableUnpackaged,
      diagnosticCode: installedFailure
          ? 'windows-notifications/package-identity-missing'
          : 'windows-notifications/unpackaged',
    );
    final logger = Logger('busymax.windows.notifications');
    if (installedFailure) {
      logger.severe(
        'Windows notification package identity is missing from a Store build.',
      );
    } else {
      logger.warning(
        'Windows notifications are unavailable without package identity.',
      );
    }
  } else if (buildConfig.windowsAppUserModelId.trim().isEmpty) {
    notificationReadiness = const DesktopNotificationReadiness(
      DesktopNotificationReadinessState.failedInstalledPackage,
      diagnosticCode: 'windows-notifications/aumid-missing',
    );
    Logger(
      'busymax.windows.notifications',
    ).severe('Windows notification initialization failed: AUMID is missing.');
  } else {
    try {
      notificationBackend = await WindowsNotificationBackend.create(
        appUserModelId: buildConfig.windowsAppUserModelId,
        onActivation: activationService.accept,
      );
      notificationReadiness = const DesktopNotificationReadiness(
        DesktopNotificationReadinessState.available,
      );
    } on WindowsNotificationInitializationException catch (error) {
      notificationReadiness = DesktopNotificationReadiness(
        DesktopNotificationReadinessState.failedInstalledPackage,
        diagnosticCode: 'windows-notifications/${error.code}',
      );
      Logger(
        'busymax.windows.notifications',
      ).severe('Windows notification initialization failed: ${error.code}.');
      notificationBackend = const DisabledDesktopNotificationBackend();
    } on Object {
      notificationReadiness = const DesktopNotificationReadiness(
        DesktopNotificationReadinessState.failedInstalledPackage,
        diagnosticCode: 'windows-notifications/initialization-failed',
      );
      Logger(
        'busymax.windows.notifications',
      ).severe('Windows notification initialization failed.');
      notificationBackend = const DisabledDesktopNotificationBackend();
    }
  }

  final overrides = <Override>[
    buildConfigProvider.overrideWithValue(buildConfig),
    localSettingsStoreProvider.overrideWithValue(settingsStore),
    secretStoreProvider.overrideWith(
      (ref) => SecureSecretStore(
        ref.watch(secureStorageProvider),
        presentation: windowsSecretStoragePresentation,
      ),
    ),
    initialAppSettingsProvider.overrideWithValue(initialSettings),
    desktopWindowServiceProvider.overrideWithValue(
      const WindowsWindowService(),
    ),
    desktopAutostartServiceProvider.overrideWithValue(
      const WindowsAutostartService(),
    ),
    desktopActivationServiceProvider.overrideWith((ref) {
      ref.onDispose(() => unawaited(activationService.dispose()));
      return activationService;
    }),
    desktopNotificationBackendProvider.overrideWith((ref) {
      ref.onDispose(() => unawaited(notificationBackend.close()));
      return notificationBackend;
    }),
    desktopNotificationReadinessProvider.overrideWith(
      (ref) => notificationReadiness!,
    ),
    systemAppearanceSourceProvider.overrideWith((ref) {
      ref.onDispose(() => unawaited(appearanceSource.dispose()));
      return appearanceSource;
    }),
    localTimeZoneSourceProvider.overrideWithValue(timeZoneSource),
    localTimeZoneProvider.overrideWithValue(localTimeZone),
  ];
  final demoProfile = buildConfig.useFakeProviderData
      ? await BusyMaxDemoProfile.create()
      : null;

  runApp(
    ProviderScope(
      overrides: [...overrides, ...?demoProfile?.overrides],
      child: WindowsBusyMaxApp(
        startMinimizedAtLaunch:
            arguments.contains(busyMaxStartMinimizedArgument) ||
            arguments.contains(busyMaxNotificationActivationServerArgument),
      ),
    ),
  );
  binding.allowFirstFrame();
}

Future<void> _runNotificationActivationForwarder(
  BuildConfig buildConfig,
) async {
  final logger = Logger('busymax.windows.notification_forwarder');
  final completed = Completer<void>();
  var finishing = false;
  WindowsNotificationBackend? backend;
  Timer? activationTimeout;
  const windowService = WindowsWindowService();

  Future<void> reportFailure() async {
    try {
      await windowService.reportNotificationActivationFailure();
    } on Object {
      logger.severe('Notification activation failure could not be displayed.');
    }
  }

  Future<void> finish([DesktopActivation? activation]) async {
    if (finishing) return;
    finishing = true;
    activationTimeout?.cancel();
    try {
      if (activation != null) {
        final forwarded = await forwardWindowsActivationToPrimary(activation);
        if (!forwarded) {
          logger.severe('Notification activation forwarding failed.');
          exitCode = 75;
          await reportFailure();
        }
      }
      await backend?.close();
    } finally {
      if (!completed.isCompleted) completed.complete();
      await windowService.quitApp();
    }
  }

  final bool packaged;
  try {
    packaged = await WindowsNotificationBackend.hasPackageIdentity();
  } on Object {
    logger.severe('Notification package identity could not be queried.');
    exitCode = 70;
    await reportFailure();
    await finish();
    return;
  }
  if (!packaged) {
    logger.severe(
      'Notification activation cannot run without package identity.',
    );
    exitCode = 78;
    await reportFailure();
    await finish();
    return;
  }
  if (buildConfig.windowsAppUserModelId.trim().isEmpty) {
    logger.severe('Notification activation cannot run without an AUMID.');
    exitCode = 78;
    await reportFailure();
    await finish();
    return;
  }
  try {
    backend = await WindowsNotificationBackend.create(
      appUserModelId: buildConfig.windowsAppUserModelId,
      onActivation: (activation) => unawaited(finish(activation)),
      activationForwarderOnly: true,
    );
  } on WindowsNotificationInitializationException catch (error) {
    logger.severe(
      'Notification activation initialization failed: ${error.code}.',
    );
    exitCode = 70;
    await reportFailure();
    await finish();
    return;
  } on Object {
    logger.severe('Notification activation initialization failed.');
    exitCode = 70;
    await reportFailure();
    await finish();
    return;
  }
  activationTimeout = Timer(const Duration(seconds: 15), () {
    logger.severe('Notification activation timed out.');
    exitCode = 75;
    unawaited(() async {
      await reportFailure();
      await finish();
    }());
  });
  await completed.future;
  activationTimeout.cancel();
}

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:system_theme/system_theme.dart';

import 'src/app/app_bootstrap.dart';
import 'src/app/windows/windows_busymax_app.dart';
import 'src/config/build_config.dart';
import 'src/core/logging/redacting_logger.dart';
import 'src/demo/demo_profile.dart';
import 'src/features/notifications/desktop_notification_backend.dart';
import 'src/platform/common/desktop_services.dart';
import 'src/platform/windows/windows_activation_service.dart';
import 'src/platform/windows/windows_autostart_service.dart';
import 'src/platform/windows/windows_notification_backend.dart';
import 'src/platform/windows/windows_system_appearance_source.dart';
import 'src/platform/windows/windows_time_zone_source.dart';
import 'src/platform/windows/windows_window_service.dart';

Future<void> main(List<String> arguments) async {
  final binding = WidgetsFlutterBinding.ensureInitialized();
  binding.deferFirstFrame();
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
  if (buildConfig.windowsAppUserModelId.trim().isNotEmpty) {
    try {
      notificationBackend = await WindowsNotificationBackend.create(
        appUserModelId: buildConfig.windowsAppUserModelId,
        onActivation: activationService.accept,
      );
    } on Object {
      notificationBackend = const DisabledDesktopNotificationBackend();
    }
  }
  configureLogging();

  final overrides = <Override>[
    buildConfigProvider.overrideWithValue(buildConfig),
    localSettingsStoreProvider.overrideWithValue(settingsStore),
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
  final completed = Completer<void>();
  var finishing = false;
  WindowsNotificationBackend? backend;

  Future<void> finish([DesktopActivation? activation]) async {
    if (finishing) return;
    finishing = true;
    try {
      if (activation != null) {
        await forwardWindowsActivationToPrimary(activation);
      }
      await backend?.close();
    } finally {
      if (!completed.isCompleted) completed.complete();
      await const WindowsWindowService().quitApp();
    }
  }

  if (buildConfig.windowsAppUserModelId.trim().isEmpty) {
    await finish();
    return;
  }
  try {
    backend = await WindowsNotificationBackend.create(
      appUserModelId: buildConfig.windowsAppUserModelId,
      onActivation: (activation) => unawaited(finish(activation)),
    );
  } on Object {
    await finish();
    return;
  }
  final timeout = Timer(const Duration(seconds: 15), () => unawaited(finish()));
  await completed.future;
  timeout.cancel();
}

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:system_theme/system_theme.dart';

import 'src/app/app_bootstrap.dart';
import 'src/app/app_theme.dart';
import 'src/app/busymax_app.dart';
import 'src/config/build_config.dart';
import 'src/core/logging/redacting_logger.dart';
import 'src/core/secrets/portal_encrypted_secret_store.dart';
import 'src/core/time/linux_gweather_location_source.dart';
import 'src/core/time/local_time_zone.dart';
import 'src/core/time/time_zone_catalog.dart';
import 'src/demo/demo_profile.dart';
import 'src/platform/common/desktop_services.dart';
import 'src/platform/external_calendar_open_service.dart';
import 'src/platform/gtk_font_service.dart';
import 'src/platform/linux/linux_notification_backend.dart';
import 'src/platform/linux_autostart_service.dart';
import 'src/platform/linux_header_bar_service.dart';
import 'src/platform/linux_window_service.dart';

Future<void> main(List<String> arguments) async {
  final binding = WidgetsFlutterBinding.ensureInitialized();
  binding.deferFirstFrame();
  final buildConfig = BuildConfig.fromEnvironment();
  final LocalSettingsStore settingsStore;
  if (buildConfig.useFakeProviderData) {
    final settings = busyMaxDemoSettings(buildConfig.demoTheme);
    settingsStore = InMemoryLocalSettingsStore(settings.toJson());
  } else {
    settingsStore = const JsonFileLocalSettingsStore();
  }

  BusyMaxTimeZoneCatalog.configureSystemLocationLoader(
    loadLinuxSystemTimeZoneLocations,
  );
  const timeZoneSource = LinuxLocalTimeZoneSource();
  final localTimeZone = await timeZoneSource.currentIanaTimeZone();
  final activationService = ExternalCalendarOpenService();
  await activationService.initialize();

  final systemAccentFuture = SystemTheme.accentColor.load();
  final initialGtkFontFuture = const GtkFontService().getGtkFont();
  final initialAppSettingsFuture = loadInitialAppSettings(settingsStore);
  final initialAppSettings = await initialAppSettingsFuture;
  final gtkThemeService = const GtkThemeService();
  await gtkThemeService.setPreferDark(
    switch (initialAppSettings.themeModePreference) {
      BusyMaxThemeModePreference.system => null,
      BusyMaxThemeModePreference.light => false,
      BusyMaxThemeModePreference.dark => true,
    },
  );
  final desktopSettings = await Future.wait<Object?>([
    systemAccentFuture,
    initialGtkFontFuture,
    gtkThemeService.getGtkThemeColors(),
  ]);
  configureLogging();

  final initialGtkFont = desktopSettings[1] as GtkFontSettings?;
  final initialGtkThemeColors = desktopSettings[2] as GtkThemeColors?;
  await _applyInitialNativeHeaderBarTheme(
    settings: initialAppSettings,
    gtkFont: initialGtkFont,
    gtkThemeColors: initialGtkThemeColors,
  );

  final overrides = <Override>[
    buildConfigProvider.overrideWithValue(buildConfig),
    localSettingsStoreProvider.overrideWithValue(settingsStore),
    initialAppSettingsProvider.overrideWithValue(initialAppSettings),
    initialGtkFontSettingsProvider.overrideWithValue(initialGtkFont),
    initialGtkThemeColorsProvider.overrideWithValue(initialGtkThemeColors),
    desktopWindowServiceProvider.overrideWithValue(const LinuxWindowService()),
    desktopAutostartServiceProvider.overrideWith(
      (ref) => LinuxAutostartService(),
    ),
    desktopActivationServiceProvider.overrideWith((ref) {
      ref.onDispose(() => unawaited(activationService.dispose()));
      return activationService;
    }),
    desktopNotificationBackendProvider.overrideWith((ref) {
      final backend = FreedesktopNotificationBackend();
      ref.onDispose(() => unawaited(backend.close()));
      return backend;
    }),
    localTimeZoneSourceProvider.overrideWithValue(timeZoneSource),
    localTimeZoneProvider.overrideWithValue(localTimeZone),
    if (Platform.environment['SNAP']?.isNotEmpty ?? false)
      secretStoreProvider.overrideWith((ref) => PortalEncryptedSecretStore()),
  ];
  final demoProfile = buildConfig.useFakeProviderData
      ? await BusyMaxDemoProfile.create()
      : null;
  final applicationOverrides = [...overrides, ...?demoProfile?.overrides];

  runApp(
    ProviderScope(
      overrides: applicationOverrides,
      child: LinuxBusyMaxApp(
        startMinimizedAtLaunch: arguments.contains(
          busyMaxStartMinimizedArgument,
        ),
      ),
    ),
  );
  binding.allowFirstFrame();
}

Future<void> _applyInitialNativeHeaderBarTheme({
  required AppSettings settings,
  required GtkFontSettings? gtkFont,
  required GtkThemeColors? gtkThemeColors,
}) async {
  final platformDispatcher = WidgetsBinding.instance.platformDispatcher;
  final brightness = switch (settings.themeModePreference) {
    BusyMaxThemeModePreference.system => platformDispatcher.platformBrightness,
    BusyMaxThemeModePreference.light => Brightness.light,
    BusyMaxThemeModePreference.dark => Brightness.dark,
  };
  final highContrast = platformDispatcher.accessibilityFeatures.highContrast;
  final theme = buildBusyMaxTheme(
    brightness: brightness,
    accentColor: gtkThemeColors?.accent ?? SystemTheme.accentColor.accent,
    family: settings.themeFamily,
    gtkFontFamily: gtkFont?.family,
    gtkFontSize: gtkFont?.size,
    gtkThemeColors: gtkThemeColors,
    highContrast: highContrast,
  );
  final headerBarService = LinuxHeaderBarService();
  try {
    await headerBarService.initialize();
    await headerBarService.setTheme(
      busyMaxHeaderBarThemeFor(theme, highContrast: highContrast),
    );
  } finally {
    headerBarService.dispose();
  }
}

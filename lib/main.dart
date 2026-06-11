import 'dart:async';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:system_theme/system_theme.dart';
import 'package:window_manager/window_manager.dart';

import 'src/app/app_bootstrap.dart';
import 'src/app/busymax_app.dart';
import 'src/config/build_config.dart';
import 'src/core/logging/redacting_logger.dart';
import 'src/features/schedule/presentation/compact_agenda_app.dart';
import 'src/platform/busymax_window_args.dart';

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemTheme.accentColor.load();
  configureLogging();

  final windowController = await WindowController.fromCurrentEngine();
  final windowArgs = BusyMaxWindowArgs.parse(windowController.arguments);
  final overrides = [
    buildConfigProvider.overrideWithValue(BuildConfig.fromEnvironment()),
  ];

  switch (windowArgs.kind) {
    case BusyMaxWindowKind.main:
      runApp(
        ProviderScope(overrides: overrides, child: const BusyMaxApp()),
      );
    case BusyMaxWindowKind.compactAgenda:
      await configureCompactAgendaNativeWindow();
      runApp(
        ProviderScope(
          overrides: overrides,
          child: BusyMaxCompactAgendaApp(windowController: windowController),
        ),
      );
  }
}

Future<void> configureCompactAgendaNativeWindow() async {
  await windowManager.ensureInitialized();

  const size = Size(420, 680);
  const options = WindowOptions(
    size: size,
    minimumSize: Size(360, 520),
    maximumSize: Size(480, 840),
    center: false,
    backgroundColor: Colors.transparent,
    skipTaskbar: true,
    title: 'BusyMax Agenda',
    titleBarStyle: TitleBarStyle.hidden,
    windowButtonVisibility: false,
  );

  await windowManager.waitUntilReadyToShow(options, () {
    unawaited(() async {
      await windowManager.setPreventClose(true);
      await windowManager.setResizable(false);
      await windowManager.setAlignment(Alignment.topRight);
      await windowManager.show();
      await windowManager.focus();
    }());
  });
}

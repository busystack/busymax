import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:system_theme/system_theme.dart';
import 'package:window_manager/window_manager.dart';

import 'src/app/app_bootstrap.dart';
import 'src/app/busymax_app.dart';
import 'src/config/build_config.dart';
import 'src/core/logging/redacting_logger.dart';
import 'src/features/schedule/application/compact_agenda_data.dart';
import 'src/features/schedule/presentation/compact_agenda_app.dart';
import 'src/platform/main_window_command_client.dart';
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
      runApp(ProviderScope(overrides: overrides, child: const BusyMaxApp()));
    case BusyMaxWindowKind.compactAgenda:
      await configureCompactAgendaNativeWindow();
      runApp(
        ProviderScope(
          overrides: [
            ...overrides,
            compactAgendaDataLoaderProvider.overrideWithValue(
              (ref, query) =>
                  const MainWindowCommandClient().compactAgendaSnapshot(query),
            ),
          ],
          child: BusyMaxCompactAgendaApp(
            windowController: windowController,
            windowArgs: windowArgs,
          ),
        ),
      );
  }
}

Future<void> configureCompactAgendaNativeWindow() async {
  await windowManager.ensureInitialized();
}

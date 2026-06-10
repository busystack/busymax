import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:system_theme/system_theme.dart';

import 'src/app/app_bootstrap.dart';
import 'src/app/busymax_app.dart';
import 'src/config/build_config.dart';
import 'src/core/logging/redacting_logger.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemTheme.accentColor.load();
  configureLogging();

  runApp(
    ProviderScope(
      overrides: [
        buildConfigProvider.overrideWithValue(BuildConfig.fromEnvironment()),
      ],
      child: const BusyMaxApp(),
    ),
  );
}

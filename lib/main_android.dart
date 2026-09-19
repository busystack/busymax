import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import 'src/android/android_app.dart';
import 'src/android/android_background.dart';

Future<void> main(List<String> arguments) async {
  WidgetsFlutterBinding.ensureInitialized();
  Logger.root.level = Level.INFO;
  Logger.root.onRecord.listen((record) {
    // Provider tokens and credentials are never included in these messages.
    debugPrint('${record.level.name}: ${record.loggerName}: ${record.message}');
  });
  final runtime = await AndroidHeadlessRuntime.create();
  await configureBusyMaxWorkmanager();
  unawaited(runtime.notifications.reconcile());
  runApp(
    UncontrolledProviderScope(
      container: runtime.container,
      child: const AndroidBusyMaxApp(),
    ),
  );
}

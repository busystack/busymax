import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  await testMain();
  if (BindingBase.debugBindingType() == null) return;
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  for (final channel in const [
    MethodChannel('io.busystack.busymax/gtk_settings'),
    MethodChannel('busymax/windows_weekday'),
  ]) {
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'getFirstWeekday') return null;
      return null;
    });
  }
}

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../test/platform/android/android_settings_sync_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('native Android Settings shows shared refresh outcomes', (
    tester,
  ) async {
    expect(Platform.isAndroid, isTrue);
    expect(const bool.fromEnvironment('BUSYMAX_SYNC_STATUS_QA'), isTrue);
    await verifyAndroidAccountRefreshStatus(tester, useDeviceViewport: true);
  });
}

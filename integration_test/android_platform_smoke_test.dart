import 'package:busymax_android_platform/busymax_android_platform.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Android native bridge exposes device settings', (tester) async {
    final platform = BusyMaxAndroidPlatform.instance;

    expect(await platform.currentTimeZoneId(), isNotEmpty);
    expect(await platform.uses24HourFormat(), isA<bool>());
    expect(await platform.googleAuthorizationAvailable(), isA<bool>());
    expect(await platform.microsoftAuthorizationAvailable(), isA<bool>());
  });
}

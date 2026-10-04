import 'package:integration_test/integration_test.dart';
import '../test/features/settings/presentation/settings_screen_test.dart'
    show registerSettingsAuthorizationCancellationRegressions;
import 'native_registration_storage_test.dart' as storage;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  registerSettingsAuthorizationCancellationRegressions();
  storage.main();
}

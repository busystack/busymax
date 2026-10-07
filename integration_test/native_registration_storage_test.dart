import 'dart:io';

import 'package:busymax/src/config/build_config.dart';
import 'package:busymax/src/core/auth/oauth_models.dart';
import 'package:busymax/src/core/auth/oauth_registration.dart';
import 'package:busymax/src/core/auth/registration_staging.dart';
import 'package:busymax/src/core/secrets/secret_store.dart';
import 'package:busymax/src/providers/busy_provider.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('native secure storage preserves registration on routine refresh', (
    tester,
  ) async {
    final store = SecureSecretStore(const FlutterSecureStorage());
    final id =
        'busymax-disposable-native-fixture:${DateTime.now().microsecondsSinceEpoch}';
    addTearDown(() => store.deleteCredential(id));
    final tokens = OAuthTokenSet(
      accessToken: 'synthetic-access',
      refreshToken: 'synthetic-refresh',
      expiresAtUtc: DateTime.utc(2040),
      tokenType: 'Bearer',
      scopes: const {'openid'},
    );
    await store
        .saveCredential(
          id,
          GoogleDesktopCredential(
            registration: const GoogleDesktopRegistration(
              clientId: 'fixture.apps.googleusercontent.com',
              projectId: 'fixture-project',
            ),
            tokenSet: tokens,
            subject: 'synthetic-subject',
            generation: 3,
            transitionEligible: false,
          ),
        )
        .timeout(const Duration(seconds: 30));
    await store
        .saveOAuthTokenSet(
          id,
          BusyProvider.google,
          tokens.copyWith(refreshToken: 'synthetic-rotated'),
        )
        .timeout(const Duration(seconds: 30));
    final read =
        await store.readCredential(id).timeout(const Duration(seconds: 30))
            as GoogleDesktopCredential;
    expect(read.generation, 3);
    expect(read.registration.clientId, 'fixture.apps.googleusercontent.com');
    expect(read.tokenSet.refreshToken, 'synthetic-rotated');
  });
  testWidgets('native file selection imports and consumes Desktop JSON', (
    tester,
  ) async {
    final fixture = Platform.environment['BUSYMAX_NATIVE_IMPORT_FIXTURE'];
    final staging = RegistrationStaging(BuildConfig.fromEnvironment());
    addTearDown(staging.dispose);
    final selected = await staging
        .selectGoogle(initialDirectory: File(fixture!).parent.path)
        .timeout(const Duration(minutes: 2));
    expect(selected, isNotNull);
    expect(selected!.summary.projectId, 'fixture-project');
    final registration = staging.consume(selected) as GoogleDesktopRegistration;
    expect(registration.clientId, 'fixture.apps.googleusercontent.com');
    expect(File(fixture).existsSync(), true);
  }, skip: Platform.environment['BUSYMAX_NATIVE_IMPORT_FIXTURE'] == null);
}

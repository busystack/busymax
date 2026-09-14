import 'package:busymax/src/android/android_authorization.dart';
import 'package:busymax/src/config/build_config.dart';
import 'package:busymax/src/core/auth/oauth_models.dart';
import 'package:busymax/src/core/secrets/secret_store.dart';
import 'package:busymax/src/google_tasks/api/google_tasks_api_surface.dart';
import 'package:busymax/src/features/sync/sync_auth_error.dart';
import 'package:busymax/src/providers/busy_provider.dart';
import 'package:busymax_android_platform/busymax_android_platform.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('busymax.test.authorization');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  AndroidAuthorizationBroker broker(InMemorySecretStore store) =>
      AndroidAuthorizationBroker(
        platform: BusyMaxAndroidPlatform(methodChannel: channel),
        httpClient: MockClient((_) async => throw UnimplementedError()),
        secretStore: store,
        config: BuildConfig.forAndroid(),
      );

  test(
    'silent Google authorization does not invent requested grants',
    () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        expect(call.method, 'authorizeGoogleSilent');
        return <String, Object?>{
          'accessToken': 'token',
          'nativeAccountId': 'native',
          'scopes': <String>[googleTasksReadWriteScope],
        };
      });

      await expectLater(
        broker(
          InMemorySecretStore(),
        ).authorizationHeader(BusyProvider.google, 'google:account'),
        throwsA(
          isA<OAuthException>().having(
            (error) => error.code,
            'code',
            'OAuthMissingToken',
          ),
        ),
      );
    },
  );

  test('sync classifier defensively recognizes native reconnect errors', () {
    expect(
      isMissingOAuthTokenError(
        PlatformException(code: 'android/auth-interaction-required'),
      ),
      isTrue,
    );
  });

  test(
    'interaction-required native error uses reconnect domain error',
    () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        throw PlatformException(
          code: 'android/auth-interaction-required',
          message: 'Native detail',
        );
      });

      await expectLater(
        broker(
          InMemorySecretStore(),
        ).authorizationHeader(BusyProvider.microsoft, 'microsoft:account'),
        throwsA(
          isA<OAuthException>().having(
            (error) => error.code,
            'code',
            'MicrosoftOAuthMissingToken',
          ),
        ),
      );
    },
  );

  test('local Google removal clears the native account binding', () async {
    final calls = <MethodCall>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return null;
    });
    final store = InMemorySecretStore();
    await store.setActiveAccountId('google:account');

    await broker(store).clearLocalSession(accountId: 'google:account');

    final removal = calls.singleWhere(
      (call) => call.method == 'removeAuthorization',
    );
    expect(removal.arguments, containsPair('accountId', 'google:account'));
    expect(removal.arguments, containsPair('revoke', false));
  });
}

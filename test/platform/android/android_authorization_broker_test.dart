import 'package:busymax/src/android/android_authorization.dart';
import 'package:busymax/src/config/build_config.dart';
import 'package:busymax/src/core/auth/oauth_models.dart';
import 'package:busymax/src/core/secrets/secret_store.dart';
import 'package:busymax/src/google_tasks/api/google_tasks_api_surface.dart';
import 'package:busymax/src/google_calendar/google_calendar_api_client.dart';
import 'package:busymax/src/features/sync/sync_auth_error.dart';
import 'package:busymax/src/providers/busy_provider.dart';
import 'package:busymax_android_platform/busymax_android_platform.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:http/http.dart' as http;
import 'package:busymax/src/core/http/shared_graph_transport.dart';

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

  for (final claims in <String?>[
    null,
    '{"access_token":{"example":{"essential":true}}}',
  ]) {
    test(
      'an intervening Microsoft ${claims == null ? 'scope' : 'claims variant'} cannot consume a rejected request refresh',
      () async {
        final nativeCalls = <Map<Object?, Object?>>[];
        final cache = <String, String>{};
        messenger.setMockMethodCallHandler(channel, (call) async {
          final arguments = Map<Object?, Object?>.from(call.arguments as Map);
          nativeCalls.add(arguments);
          final contacts = (arguments['scopes'] as List).any(
            (scope) => scope.toString().endsWith('Contacts.Read'),
          );
          final key =
              '${contacts ? 'contacts' : 'ordinary'}${arguments['claims'] == null ? '' : '-claims'}';
          final cacheKey = '${arguments['accountId']}/$key';
          if (arguments['forceRefresh'] == true) cache[cacheKey] = 'fresh-$key';
          return {
            'accessToken': cache[cacheKey] ?? 'rejected-$key',
            'nativeAccountId': 'native',
            'scopes': [
              'User.Read',
              'Tasks.ReadWrite',
              'Calendars.ReadWrite',
              if (contacts) 'Contacts.Read',
            ],
          };
        });
        final auth = broker(InMemorySecretStore());
        final headers = <String?>[];
        final transport = BusyMaxGraphTransport(
          httpClient: MockClient((request) async {
            headers.add(request.headers['authorization']);
            return http.Response(
              headers.length == 1
                  ? '{"error":{"code":"InvalidAuthenticationToken","message":"Rejected"}}'
                  : '{}',
              headers.length == 1 ? 401 : 200,
            );
          }),
          authorizationHeader: (_) => auth.microsoftContactsAuthorizationHeader(
            'microsoft:account',
            claims: claims,
          ),
          recoverUnauthorized: () async {
            await auth.recoverUnauthorized(
              BusyProvider.microsoft,
              'microsoft:account',
            );
            await auth.authorizationHeader(
              BusyProvider.microsoft,
              'microsoft:other',
            );
            expect(nativeCalls.last['forceRefresh'], isFalse);
            if (claims == null) {
              await auth.authorizationHeader(
                BusyProvider.microsoft,
                'microsoft:account',
              );
            } else {
              await auth.microsoftContactsAuthorizationHeader(
                'microsoft:account',
              );
            }
          },
        );
        expect(
          (await transport.request(
            'GET',
            Uri.parse('https://graph.microsoft.com/v1.0/me/contacts'),
          )).statusCode,
          200,
        );
        final requestedKey = 'contacts${claims == null ? '' : '-claims'}';
        expect(headers, [
          'Bearer rejected-$requestedKey',
          'Bearer fresh-$requestedKey',
        ]);
        expect(nativeCalls.last['forceRefresh'], isTrue);
        await auth.microsoftContactsAuthorizationHeader(
          'microsoft:account',
          claims: claims,
        );
        expect(nativeCalls.last['forceRefresh'], isFalse);
      },
    );
  }

  for (final rejectRetry in [false, true]) {
    test(
      'Microsoft 401 forces the native acquisition used by the bounded retry ($rejectRetry)',
      () async {
        var cachedToken = 'rejected';
        final calls = <MethodCall>[];
        messenger.setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          if ((call.arguments as Map)['forceRefresh'] == true) {
            cachedToken = 'fresh';
          }
          return {
            'accessToken': cachedToken,
            'nativeAccountId': 'native',
            'scopes': ['User.Read', 'Tasks.ReadWrite', 'Calendars.ReadWrite'],
          };
        });
        final auth = broker(InMemorySecretStore());
        final headers = <String?>[];
        final transport = BusyMaxGraphTransport(
          httpClient: MockClient((request) async {
            headers.add(request.headers['authorization']);
            if (headers.length == 1 || rejectRetry) {
              return http.Response(
                '{"error":{"code":"InvalidAuthenticationToken","message":"Rejected"}}',
                401,
              );
            }
            return http.Response('{}', 200);
          }),
          authorizationHeader: (_) => auth.authorizationHeader(
            BusyProvider.microsoft,
            'microsoft:account',
          ),
          recoverUnauthorized: () => auth.recoverUnauthorized(
            BusyProvider.microsoft,
            'microsoft:account',
          ),
        );
        expect(
          (await transport.request(
            'GET',
            Uri.parse('https://graph.microsoft.com/v1.0/me'),
          )).statusCode,
          rejectRetry ? 401 : 200,
        );
        expect(headers, ['Bearer rejected', 'Bearer fresh']);
        expect(
          calls.where(
            (call) => (call.arguments as Map)['forceRefresh'] == true,
          ),
          hasLength(1),
        );
        await auth.authorizationHeader(
          BusyProvider.microsoft,
          'microsoft:account',
        );
        expect((calls.last.arguments as Map)['forceRefresh'], isNot(true));
      },
    );
  }

  test(
    'Google 401 invalidates the rejected native token before retry',
    () async {
      var token = 'rejected-google';
      final calls = <MethodCall>[];
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        if (call.method == 'clearRejectedGoogleToken') {
          expect((call.arguments as Map)['token'], 'rejected-google');
          token = 'fresh-google';
          return null;
        }
        expect(call.method, 'authorizeGoogleSilent');
        return {
          'accessToken': token,
          'nativeAccountId': 'native',
          'scopes': [googleTasksReadWriteScope, googleCalendarReadWriteScope],
        };
      });
      final auth = broker(InMemorySecretStore());
      final headers = <String?>[];
      final client = GoogleCalendarApiClient(
        httpClient: MockClient((request) async {
          headers.add(request.headers['authorization']);
          return http.Response(
            headers.length == 1 ? '{"error":{"code":401}}' : '{"items":[]}',
            headers.length == 1 ? 401 : 200,
          );
        }),
        baseUri: Uri.parse('https://www.googleapis.com'),
        authorizationHeaderProvider: () =>
            auth.authorizationHeader(BusyProvider.google, 'google:account'),
        unauthorizedRefreshProvider: () =>
            auth.recoverUnauthorized(BusyProvider.google, 'google:account'),
      );
      expect(await client.listCalendars(), isEmpty);
      expect(headers, ['Bearer rejected-google', 'Bearer fresh-google']);
      expect(
        calls.where((call) => call.method == 'clearRejectedGoogleToken'),
        hasLength(1),
      );
    },
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
        broker(InMemorySecretStore())
            .authorizationHeader(BusyProvider.google, 'google:account'),
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
        broker(InMemorySecretStore())
            .authorizationHeader(BusyProvider.microsoft, 'microsoft:account'),
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

  test('optional Outlook category header requires the grant even with an opaque token', () async {
    var includeCategory = false;
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'authorizeMicrosoftSilent');
      expect(
        (call.arguments as Map)['scopes'],
        contains('MailboxSettings.Read'),
      );
      return <String, Object?>{
        'accessToken': 'opaque-token-value',
        'nativeAccountId': 'native',
        'scopes': <String>[
          'User.Read',
          'Tasks.ReadWrite',
          'Calendars.ReadWrite',
          if (includeCategory) 'MailboxSettings.Read',
        ],
      };
    });
    final subject = broker(InMemorySecretStore());
    await expectLater(
      subject.microsoftCategoryAuthorizationHeader('microsoft:account'),
      throwsA(isA<OAuthException>()),
    );
    includeCategory = true;
    expect(
      await subject.microsoftCategoryAuthorizationHeader('microsoft:account'),
      'Bearer opaque-token-value',
    );
  });
}

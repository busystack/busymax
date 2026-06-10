import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:logging/logging.dart';
import 'package:busymax/src/config/build_config.dart';
import 'package:busymax/src/google_tasks/api/google_tasks_api_surface.dart';
import 'package:busymax/src/google_tasks/oauth/oauth_loopback_flow.dart';
import 'package:busymax/src/google_tasks/oauth/oauth_models.dart';
import 'package:busymax/src/google_tasks/oauth/oauth_service.dart';
import 'package:busymax/src/google_tasks/oauth/oauth_token_store.dart';

void main() {
  test('fetchUserInfo reads Google profile from OpenID userinfo', () async {
    late http.Request captured;
    final service = OAuthService(
      config: _config,
      httpClient: MockClient((request) async {
        captured = request;
        return http.Response(
          jsonEncode({
            'sub': 'google-subject',
            'name': 'Google User',
            'email': 'google@example.com',
          }),
          200,
        );
      }),
      tokenStore: InMemoryOAuthTokenStore(),
      loopbackFlow: OAuthLoopbackFlow(),
      nowUtc: () => DateTime.utc(2026, 6, 4),
    );

    final userInfo = await service.fetchUserInfo(
      OAuthTokenSet(
        accessToken: 'access-token',
        expiresAtUtc: DateTime.utc(2026, 6, 4, 1),
        tokenType: 'Bearer',
        scopes: Set<String>.of(googleBusyMaxOAuthScopes),
      ),
    );

    expect(captured.url.host, 'openidconnect.googleapis.com');
    expect(captured.url.path, '/v1/userinfo');
    expect(captured.headers['Authorization'], 'Bearer access-token');
    expect(userInfo?.subject, 'google-subject');
    expect(userInfo?.name, 'Google User');
    expect(userInfo?.email, 'google@example.com');
  });

  test(
    'token exchange without configured client secret does not send client_secret',
    () async {
      late http.Request captured;
      final service = OAuthService(
        config: _config,
        httpClient: MockClient((request) async {
          captured = request;
          return http.Response(
            jsonEncode({
              'access_token': 'access',
              'refresh_token': 'refresh',
              'expires_in': 3600,
              'scope': 'https://www.googleapis.com/auth/tasks',
              'token_type': 'Bearer',
            }),
            200,
          );
        }),
        tokenStore: InMemoryOAuthTokenStore(),
        loopbackFlow: OAuthLoopbackFlow(),
        nowUtc: () => DateTime.utc(2026, 6, 4),
      );

      final tokenSet = await service.exchangeAuthorizationCode(
        code: 'code',
        codeVerifier: 'verifier',
        redirectUri: 'http://127.0.0.1:1234/',
      );

      expect(
        captured.headers['Content-Type'],
        'application/x-www-form-urlencoded',
      );
      expect(Uri.splitQueryString(captured.body), {
        'client_id': 'client-id',
        'code': 'code',
        'code_verifier': 'verifier',
        'grant_type': 'authorization_code',
        'redirect_uri': 'http://127.0.0.1:1234/',
      });
      expect(captured.body, isNot(contains('client_secret')));
      expect(tokenSet.refreshToken, 'refresh');
    },
  );

  test(
    'token exchange uses fallback scopes when response omits scope',
    () async {
      final service = OAuthService(
        config: _config,
        httpClient: MockClient((request) async {
          return http.Response(
            jsonEncode({
              'access_token': 'access',
              'refresh_token': 'refresh',
              'expires_in': 3600,
              'token_type': 'Bearer',
            }),
            200,
          );
        }),
        tokenStore: InMemoryOAuthTokenStore(),
        loopbackFlow: OAuthLoopbackFlow(),
        nowUtc: () => DateTime.utc(2026, 6, 4),
      );

      final tokenSet = await service.exchangeAuthorizationCode(
        code: 'code',
        codeVerifier: 'verifier',
        redirectUri: 'http://127.0.0.1:1234/',
        fallbackScopeText:
            '$googleTasksReadWriteScope $googleCalendarReadWriteScope',
      );

      expect(tokenSet.scopes, {
        googleTasksReadWriteScope,
        googleCalendarReadWriteScope,
      });
    },
  );

  test(
    'Google sign-in requests incremental auth and does not assume missing granted scopes',
    () async {
      final tokenStore = InMemoryOAuthTokenStore();
      final loopbackFlow = _FakeOAuthLoopbackFlow(
        callback: const OAuthCallbackResult(code: 'code', scope: null),
      );
      final service = OAuthService(
        config: _config,
        httpClient: MockClient((request) async {
          return http.Response(
            jsonEncode({
              'access_token': 'access',
              'refresh_token': 'refresh',
              'expires_in': 3600,
              'token_type': 'Bearer',
            }),
            200,
          );
        }),
        tokenStore: tokenStore,
        loopbackFlow: loopbackFlow,
        nowUtc: () => DateTime.utc(2026, 6, 4),
      );

      final result = await service.signIn();
      final storedTokenSet = await tokenStore.readTokenSet(result.accountId);

      expect(loopbackFlow.extraAuthorizationParameters, {
        'include_granted_scopes': 'true',
      });
      expect(result.tokenSet.scopes, isEmpty);
      expect(storedTokenSet?.scopes, isEmpty);
    },
  );

  test(
    'Google sign-in uses callback granted scopes when token response omits scope',
    () async {
      final loopbackFlow = _FakeOAuthLoopbackFlow(
        callback: const OAuthCallbackResult(
          code: 'code',
          scope: '$googleTasksReadWriteScope $googleCalendarReadWriteScope',
        ),
      );
      final service = OAuthService(
        config: _config,
        httpClient: MockClient((request) async {
          return http.Response(
            jsonEncode({
              'access_token': 'access',
              'refresh_token': 'refresh',
              'expires_in': 3600,
              'token_type': 'Bearer',
            }),
            200,
          );
        }),
        tokenStore: InMemoryOAuthTokenStore(),
        loopbackFlow: loopbackFlow,
        nowUtc: () => DateTime.utc(2026, 6, 4),
      );

      final result = await service.signIn();

      expect(result.tokenSet.scopes, {
        googleTasksReadWriteScope,
        googleCalendarReadWriteScope,
      });
    },
  );

  test(
    'token exchange with configured client secret sends client_secret',
    () async {
      late http.Request captured;
      final service = OAuthService(
        config: _configWithClientSecret('desktop-secret'),
        httpClient: MockClient((request) async {
          captured = request;
          return http.Response(
            jsonEncode({
              'access_token': 'access',
              'refresh_token': 'refresh',
              'expires_in': 3600,
              'scope': 'https://www.googleapis.com/auth/tasks',
              'token_type': 'Bearer',
            }),
            200,
          );
        }),
        tokenStore: InMemoryOAuthTokenStore(),
        loopbackFlow: OAuthLoopbackFlow(),
        nowUtc: () => DateTime.utc(2026, 6, 4),
      );

      await service.exchangeAuthorizationCode(
        code: 'code',
        codeVerifier: 'verifier',
        redirectUri: 'http://127.0.0.1:1234/',
      );

      expect(
        Uri.splitQueryString(captured.body)['client_secret'],
        'desktop-secret',
      );
    },
  );

  test('token exchange logs secret presence without exposing value', () async {
    final records = <LogRecord>[];
    final previousLevel = Logger.root.level;
    Logger.root.level = Level.INFO;
    final subscription = Logger.root.onRecord.listen((record) {
      if (record.loggerName == 'OAuthService') {
        records.add(record);
      }
    });
    addTearDown(() async {
      Logger.root.level = previousLevel;
      await subscription.cancel();
    });

    final service = OAuthService(
      config: _configWithClientSecret('desktop-secret'),
      httpClient: MockClient((request) async {
        return http.Response(
          jsonEncode({
            'access_token': 'access',
            'refresh_token': 'refresh',
            'expires_in': 3600,
            'scope': 'https://www.googleapis.com/auth/tasks',
            'token_type': 'Bearer',
          }),
          200,
        );
      }),
      tokenStore: InMemoryOAuthTokenStore(),
      loopbackFlow: OAuthLoopbackFlow(),
      nowUtc: () => DateTime.utc(2026, 6, 4),
    );

    await service.exchangeAuthorizationCode(
      code: 'code',
      codeVerifier: 'verifier',
      redirectUri: 'http://127.0.0.1:1234/',
    );

    final logText = records.map((record) => record.message).join('\n');
    expect(logText, contains('has_client_secret=true'));
    expect(logText, isNot(contains('desktop-secret')));
  });

  test('token endpoint 400 JSON body is surfaced without secrets', () async {
    final service = OAuthService(
      config: _config,
      httpClient: MockClient((request) async {
        return http.Response(
          jsonEncode({
            'error': 'invalid_grant',
            'error_description': 'Bad Request',
          }),
          400,
        );
      }),
      tokenStore: InMemoryOAuthTokenStore(),
      loopbackFlow: OAuthLoopbackFlow(),
      nowUtc: () => DateTime.utc(2026, 6, 4),
    );

    await expectLater(
      service.exchangeAuthorizationCode(
        code: 'auth-code-secret',
        codeVerifier: 'verifier-secret',
        redirectUri: 'http://127.0.0.1:1234/',
      ),
      throwsA(
        isA<OAuthException>()
            .having((error) => error.code, 'code', 'OAuthTokenExchangeFailed')
            .having(
              (error) => error.message,
              'message',
              contains('invalid_grant'),
            )
            .having(
              (error) => error.message,
              'message',
              contains('Bad Request'),
            )
            .having(
              (error) => error.message,
              'message',
              isNot(contains('auth-code-secret')),
            )
            .having(
              (error) => error.message,
              'message',
              isNot(contains('verifier-secret')),
            ),
      ),
    );
  });

  test('token endpoint 400 non-JSON body is controlled and redacted', () async {
    final service = OAuthService(
      config: _config,
      httpClient: MockClient((request) async {
        return http.Response(
          'Bad Request code=auth-code-secret code_verifier=verifier-secret',
          400,
        );
      }),
      tokenStore: InMemoryOAuthTokenStore(),
      loopbackFlow: OAuthLoopbackFlow(),
      nowUtc: () => DateTime.utc(2026, 6, 4),
    );

    await expectLater(
      service.exchangeAuthorizationCode(
        code: 'auth-code-secret',
        codeVerifier: 'verifier-secret',
        redirectUri: 'http://127.0.0.1:1234/',
      ),
      throwsA(
        isA<OAuthException>()
            .having((error) => error.code, 'code', 'OAuthTokenExchangeFailed')
            .having(
              (error) => error.message,
              'message',
              contains('Google token exchange failed with HTTP 400'),
            )
            .having(
              (error) => error.message,
              'message',
              contains('code=[REDACTED]'),
            )
            .having(
              (error) => error.message,
              'message',
              contains('code_verifier=[REDACTED]'),
            )
            .having(
              (error) => error.message,
              'message',
              isNot(contains('auth-code-secret')),
            )
            .having(
              (error) => error.message,
              'message',
              isNot(contains('verifier-secret')),
            ),
      ),
    );
  });

  test('missing client secret error has desktop client guidance', () async {
    final service = OAuthService(
      config: _config,
      httpClient: MockClient((request) async {
        return http.Response(
          jsonEncode({
            'error': 'invalid_request',
            'error_description': 'client_secret is missing',
          }),
          400,
        );
      }),
      tokenStore: InMemoryOAuthTokenStore(),
      loopbackFlow: OAuthLoopbackFlow(),
      nowUtc: () => DateTime.utc(2026, 6, 4),
    );

    await expectLater(
      service.exchangeAuthorizationCode(
        code: 'code',
        codeVerifier: 'verifier',
        redirectUri: 'http://127.0.0.1:1234/',
      ),
      throwsA(
        isA<OAuthException>()
            .having((error) => error.code, 'code', 'OAuthTokenExchangeFailed')
            .having(
              (error) => error.message,
              'message',
              'This Google Desktop OAuth client requires a client secret. '
                  'Re-run BusyMax with GOOGLE_OAUTH_CLIENT_SECRET set from '
                  'the same Desktop OAuth client credentials.',
            ),
      ),
    );
  });

  test('missing code verifier fails before POST', () async {
    var posted = false;
    final service = OAuthService(
      config: _config,
      httpClient: MockClient((request) async {
        posted = true;
        return http.Response('{}', 200);
      }),
      tokenStore: InMemoryOAuthTokenStore(),
      loopbackFlow: OAuthLoopbackFlow(),
      nowUtc: () => DateTime.utc(2026, 6, 4),
    );

    await expectLater(
      service.exchangeAuthorizationCode(
        code: 'code',
        codeVerifier: '',
        redirectUri: 'http://127.0.0.1:1234/',
      ),
      throwsA(
        isA<OAuthException>().having(
          (error) => error.code,
          'code',
          'OAuthTokenExchangeInvalidRequest',
        ),
      ),
    );
    expect(posted, isFalse);
  });

  test('missing client ID fails before POST', () async {
    var posted = false;
    final service = OAuthService(
      config: _configWithClientId(''),
      httpClient: MockClient((request) async {
        posted = true;
        return http.Response('{}', 200);
      }),
      tokenStore: InMemoryOAuthTokenStore(),
      loopbackFlow: OAuthLoopbackFlow(),
      nowUtc: () => DateTime.utc(2026, 6, 4),
    );

    await expectLater(
      service.exchangeAuthorizationCode(
        code: 'code',
        codeVerifier: 'verifier',
        redirectUri: 'http://127.0.0.1:1234/',
      ),
      throwsA(
        isA<OAuthException>().having(
          (error) => error.code,
          'code',
          'OAuthMissingClientId',
        ),
      ),
    );
    expect(posted, isFalse);
  });

  test('non-loopback redirect URI fails before POST', () async {
    var posted = false;
    final service = OAuthService(
      config: _config,
      httpClient: MockClient((request) async {
        posted = true;
        return http.Response('{}', 200);
      }),
      tokenStore: InMemoryOAuthTokenStore(),
      loopbackFlow: OAuthLoopbackFlow(),
      nowUtc: () => DateTime.utc(2026, 6, 4),
    );

    await expectLater(
      service.exchangeAuthorizationCode(
        code: 'code',
        codeVerifier: 'verifier',
        redirectUri: 'https://example.com/oauth',
      ),
      throwsA(
        isA<OAuthException>().having(
          (error) => error.code,
          'code',
          'OAuthTokenExchangeInvalidRequest',
        ),
      ),
    );
    expect(posted, isFalse);
  });

  test(
    'refresh body is form encoded and keeps existing refresh token',
    () async {
      late http.Request captured;
      final service = OAuthService(
        config: _config,
        httpClient: MockClient((request) async {
          captured = request;
          return http.Response(
            jsonEncode({
              'access_token': 'new-access',
              'expires_in': 3600,
              'scope': 'https://www.googleapis.com/auth/tasks',
              'token_type': 'Bearer',
            }),
            200,
          );
        }),
        tokenStore: InMemoryOAuthTokenStore(),
        loopbackFlow: OAuthLoopbackFlow(),
        nowUtc: () => DateTime.utc(2026, 6, 4),
      );

      final tokenSet = await service.refreshToken(
        const OAuthTokenSetFixture().tokenSet,
      );

      expect(Uri.splitQueryString(captured.body), {
        'client_id': 'client-id',
        'grant_type': 'refresh_token',
        'refresh_token': 'refresh',
      });
      expect(captured.body, isNot(contains('client_secret')));
      expect(tokenSet.refreshToken, 'refresh');
    },
  );

  test('refresh response without scope preserves existing scopes', () async {
    final current = const OAuthTokenSetFixture().tokenSet.copyWith(
      scopes: {googleTasksReadWriteScope, googleCalendarReadWriteScope},
    );
    final service = OAuthService(
      config: _config,
      httpClient: MockClient((request) async {
        return http.Response(
          jsonEncode({
            'access_token': 'new-access',
            'expires_in': 3600,
            'token_type': 'Bearer',
          }),
          200,
        );
      }),
      tokenStore: InMemoryOAuthTokenStore(),
      loopbackFlow: OAuthLoopbackFlow(),
      nowUtc: () => DateTime.utc(2026, 6, 4),
    );

    final tokenSet = await service.refreshToken(current);

    expect(tokenSet.scopes, current.scopes);
  });

  test(
    'refresh token with configured client secret sends client_secret',
    () async {
      late http.Request captured;
      final service = OAuthService(
        config: _configWithClientSecret('desktop-secret'),
        httpClient: MockClient((request) async {
          captured = request;
          return http.Response(
            jsonEncode({
              'access_token': 'new-access',
              'expires_in': 3600,
              'scope': 'https://www.googleapis.com/auth/tasks',
              'token_type': 'Bearer',
            }),
            200,
          );
        }),
        tokenStore: InMemoryOAuthTokenStore(),
        loopbackFlow: OAuthLoopbackFlow(),
        nowUtc: () => DateTime.utc(2026, 6, 4),
      );

      await service.refreshToken(const OAuthTokenSetFixture().tokenSet);

      expect(
        Uri.splitQueryString(captured.body)['client_secret'],
        'desktop-secret',
      );
    },
  );

  test('signOutAccount clears only requested Google account', () async {
    final tokenStore = InMemoryOAuthTokenStore();
    await tokenStore.saveTokenSet(
      'google-a',
      const OAuthTokenSetFixture().tokenSet,
    );
    await tokenStore.saveTokenSet(
      'google-b',
      const OAuthTokenSetFixture().tokenSet.copyWith(accessToken: 'access-b'),
    );
    await tokenStore.setActiveAccountId('google-b');
    final service = OAuthService(
      config: _config,
      httpClient: MockClient((request) async => http.Response('', 200)),
      tokenStore: tokenStore,
      loopbackFlow: OAuthLoopbackFlow(),
    );

    await service.signOutAccount('google-a');

    expect(await tokenStore.readTokenSet('google-a'), isNull);
    expect(await tokenStore.readTokenSet('google-b'), isNotNull);
    expect(await tokenStore.readActiveAccountId(), 'google-b');
  });

  test(
    'revokeAndSignOutAccount clears only requested Google account',
    () async {
      final tokenStore = InMemoryOAuthTokenStore();
      await tokenStore.saveTokenSet(
        'google-a',
        const OAuthTokenSetFixture().tokenSet,
      );
      await tokenStore.saveTokenSet(
        'google-b',
        const OAuthTokenSetFixture().tokenSet.copyWith(accessToken: 'access-b'),
      );
      await tokenStore.saveTokenSet(
        'microsoft:m',
        const OAuthTokenSetFixture().tokenSet.copyWith(
          accessToken: 'ms-access',
        ),
      );
      await tokenStore.setActiveAccountId('google-b');
      late http.Request captured;
      final service = OAuthService(
        config: _config,
        httpClient: MockClient((request) async {
          captured = request;
          return http.Response('', 200);
        }),
        tokenStore: tokenStore,
        loopbackFlow: OAuthLoopbackFlow(),
      );

      await service.revokeAndSignOutAccount('google-a');

      expect(captured.url.queryParameters['token'], 'refresh');
      expect(await tokenStore.readTokenSet('google-a'), isNull);
      expect(await tokenStore.readTokenSet('google-b'), isNotNull);
      expect(await tokenStore.readTokenSet('microsoft:m'), isNotNull);
      expect(await tokenStore.readActiveAccountId(), 'google-b');
    },
  );

  test('refresh 400 clears only account being refreshed', () async {
    final tokenStore = InMemoryOAuthTokenStore();
    await tokenStore.saveTokenSet(
      'google-a',
      const OAuthTokenSetFixture().tokenSet,
    );
    await tokenStore.saveTokenSet(
      'google-b',
      const OAuthTokenSetFixture().tokenSet.copyWith(accessToken: 'access-b'),
    );
    await tokenStore.saveTokenSet(
      'microsoft:m',
      const OAuthTokenSetFixture().tokenSet.copyWith(accessToken: 'ms-access'),
    );
    await tokenStore.setActiveAccountId('google-b');
    final service = OAuthService(
      config: _config,
      httpClient: MockClient((request) async {
        return http.Response(
          jsonEncode({
            'error': 'invalid_grant',
            'error_description': 'Token expired',
          }),
          400,
        );
      }),
      tokenStore: tokenStore,
      loopbackFlow: OAuthLoopbackFlow(),
    );

    await expectLater(
      service.refreshTokenForAccount('google-a'),
      throwsA(isA<OAuthException>()),
    );

    expect(await tokenStore.readTokenSet('google-a'), isNull);
    expect(await tokenStore.readTokenSet('google-b'), isNotNull);
    expect(await tokenStore.readTokenSet('microsoft:m'), isNotNull);
    expect(await tokenStore.readActiveAccountId(), 'google-b');
  });

  test('refresh endpoint 400 JSON body is surfaced without secrets', () async {
    final service = OAuthService(
      config: _config,
      httpClient: MockClient((request) async {
        return http.Response(
          jsonEncode({
            'error': 'invalid_grant',
            'error_description': 'Token expired',
          }),
          400,
        );
      }),
      tokenStore: InMemoryOAuthTokenStore(),
      loopbackFlow: OAuthLoopbackFlow(),
      nowUtc: () => DateTime.utc(2026, 6, 4),
    );

    await expectLater(
      service.refreshToken(
        const OAuthTokenSetFixture().tokenSet.copyWith(
          refreshToken: 'refresh-secret-token',
        ),
      ),
      throwsA(
        isA<OAuthException>()
            .having((error) => error.code, 'code', 'OAuthRefreshFailed')
            .having(
              (error) => error.message,
              'message',
              contains('invalid_grant'),
            )
            .having(
              (error) => error.message,
              'message',
              contains('Token expired'),
            )
            .having(
              (error) => error.message,
              'message',
              isNot(contains('refresh-secret-token')),
            ),
      ),
    );
  });
}

const _config = BuildConfig(
  googleOAuthClientId: 'client-id',
  googleOAuthClientSecret: '',
  apiBaseUrl: 'https://tasks.googleapis.com',
  oauthAuthorizationEndpoint: 'https://accounts.google.com/o/oauth2/v2/auth',
  oauthTokenEndpoint: 'https://oauth2.googleapis.com/token',
  oauthRevocationEndpoint: 'https://oauth2.googleapis.com/revoke',
);

BuildConfig _configWithClientId(String clientId) {
  return BuildConfig(
    googleOAuthClientId: clientId,
    googleOAuthClientSecret: '',
    apiBaseUrl: 'https://tasks.googleapis.com',
    oauthAuthorizationEndpoint: 'https://accounts.google.com/o/oauth2/v2/auth',
    oauthTokenEndpoint: 'https://oauth2.googleapis.com/token',
    oauthRevocationEndpoint: 'https://oauth2.googleapis.com/revoke',
  );
}

BuildConfig _configWithClientSecret(String clientSecret) {
  return BuildConfig(
    googleOAuthClientId: 'client-id',
    googleOAuthClientSecret: clientSecret,
    apiBaseUrl: 'https://tasks.googleapis.com',
    oauthAuthorizationEndpoint: 'https://accounts.google.com/o/oauth2/v2/auth',
    oauthTokenEndpoint: 'https://oauth2.googleapis.com/token',
    oauthRevocationEndpoint: 'https://oauth2.googleapis.com/revoke',
  );
}

class OAuthTokenSetFixture {
  const OAuthTokenSetFixture();

  OAuthTokenSet get tokenSet => OAuthTokenSet(
    accessToken: 'access',
    refreshToken: 'refresh',
    expiresAtUtc: DateTime.utc(2026, 6, 4, 1),
    tokenType: 'Bearer',
    scopes: const {'https://www.googleapis.com/auth/tasks'},
  );
}

class _FakeOAuthLoopbackFlow extends OAuthLoopbackFlow {
  _FakeOAuthLoopbackFlow({required this.callback});

  final OAuthCallbackResult callback;
  Map<String, String>? extraAuthorizationParameters;

  @override
  Future<OAuthLoopbackResult> start({
    required Uri authorizationEndpoint,
    required String clientId,
    required String scope,
    String redirectHost = '127.0.0.1',
    String signInCancelledMessage = 'Google sign-in was cancelled.',
    String callbackNotReceivedMessage = googleSignInCallbackNotReceivedMessage,
    String serverStartFailureMessage =
        'Could not start the local Google sign-in callback listener.',
    String browserLaunchFailureMessage =
        'Could not open the browser for Google sign-in.',
    Map<String, String> extraAuthorizationParameters = const {},
    String? loginHint,
  }) async {
    this.extraAuthorizationParameters = extraAuthorizationParameters;
    return OAuthLoopbackResult(
      callback: callback,
      redirectUri: 'http://127.0.0.1:1234/',
      codeVerifier: 'verifier',
    );
  }
}

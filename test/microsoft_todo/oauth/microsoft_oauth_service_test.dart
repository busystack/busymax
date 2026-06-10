import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:busymax/src/config/build_config.dart';
import 'package:busymax/src/google_tasks/oauth/oauth_loopback_flow.dart';
import 'package:busymax/src/google_tasks/oauth/oauth_models.dart';
import 'package:busymax/src/google_tasks/oauth/oauth_token_store.dart';
import 'package:busymax/src/microsoft_todo/oauth/microsoft_oauth_service.dart';

void main() {
  test('authorization URL uses Microsoft public desktop OAuth parameters', () {
    final uri = buildAuthorizationUri(
      authorizationEndpoint: Uri.https(
        'login.microsoftonline.com',
        '/common/oauth2/v2.0/authorize',
      ),
      clientId: 'microsoft-client-id',
      redirectUri: 'http://localhost:4321/',
      scope: microsoftTodoOAuthScopes,
      codeChallenge: 'challenge',
      state: 'state-value',
      extraParameters: const {
        'response_mode': 'query',
        'prompt': 'select_account',
      },
    );

    expect(
      uri.toString(),
      startsWith('https://login.microsoftonline.com/common/oauth2/v2.0/'),
    );
    expect(uri.queryParameters['client_id'], 'microsoft-client-id');
    expect(uri.queryParameters['redirect_uri'], 'http://localhost:4321/');
    expect(uri.queryParameters['response_type'], 'code');
    expect(uri.queryParameters['response_mode'], 'query');
    expect(uri.queryParameters['scope'], microsoftTodoOAuthScopes);
    expect(uri.queryParameters['state'], 'state-value');
    expect(uri.queryParameters['code_challenge'], 'challenge');
    expect(uri.queryParameters['code_challenge_method'], 'S256');
    expect(uri.queryParameters['prompt'], 'select_account');
  });

  test('token exchange does not send client_secret', () async {
    late http.Request captured;
    final service = _service((request) async {
      captured = request;
      return _tokenResponse();
    });

    final tokenSet = await service.exchangeAuthorizationCode(
      code: 'auth-code',
      codeVerifier: 'verifier',
      redirectUri: 'http://localhost:4321/',
    );

    final body = Uri.splitQueryString(captured.body);
    expect(captured.url.toString(), contains('/common/oauth2/v2.0/token'));
    expect(body['client_id'], 'microsoft-client-id');
    expect(body['code'], 'auth-code');
    expect(body['code_verifier'], 'verifier');
    expect(body['redirect_uri'], 'http://localhost:4321/');
    expect(body['grant_type'], 'authorization_code');
    expect(body.containsKey('client_secret'), isFalse);
    expect(tokenSet.refreshToken, 'refresh');
  });

  test('refresh does not send client_secret and sends scopes', () async {
    late http.Request captured;
    final service = _service((request) async {
      captured = request;
      return _tokenResponse();
    });

    await service.refreshToken(
      OAuthTokenSet(
        accessToken: 'access',
        refreshToken: 'refresh',
        expiresAtUtc: DateTime.utc(2026, 6, 6),
        tokenType: 'Bearer',
        scopes: const {},
      ),
    );

    final body = Uri.splitQueryString(captured.body);
    expect(body['client_id'], 'microsoft-client-id');
    expect(body['grant_type'], 'refresh_token');
    expect(body['refresh_token'], 'refresh');
    expect(body['scope'], microsoftTodoOAuthScopes);
    expect(body.containsKey('client_secret'), isFalse);
  });

  test(
    'token endpoint 400 surfaces sanitized Microsoft OAuth exception',
    () async {
      final service = _service((request) async {
        return http.Response(
          jsonEncode({
            'error': 'invalid_grant',
            'error_description': 'Bad Request code=secret-code',
          }),
          400,
        );
      });

      await expectLater(
        service.exchangeAuthorizationCode(
          code: 'secret-code',
          codeVerifier: 'secret-verifier',
          redirectUri: 'http://localhost:4321/',
        ),
        throwsA(
          isA<OAuthException>()
              .having(
                (error) => error.code,
                'code',
                'MicrosoftOAuthTokenExchangeFailed',
              )
              .having(
                (error) => error.message,
                'message',
                contains('invalid_grant'),
              )
              .having(
                (error) => error.message,
                'message',
                isNot(contains('secret-verifier')),
              ),
        ),
      );
    },
  );
}

MicrosoftOAuthService _service(
  Future<http.Response> Function(http.Request request) handler,
) {
  return MicrosoftOAuthService(
    config: const BuildConfig(
      googleOAuthClientId: '',
      googleOAuthClientSecret: '',
      microsoftOAuthClientId: 'microsoft-client-id',
      apiBaseUrl: 'https://tasks.googleapis.com',
      oauthAuthorizationEndpoint:
          'https://accounts.google.com/o/oauth2/v2/auth',
      oauthTokenEndpoint: 'https://oauth2.googleapis.com/token',
      oauthRevocationEndpoint: 'https://oauth2.googleapis.com/revoke',
    ),
    httpClient: MockClient(handler),
    tokenStore: InMemoryOAuthTokenStore(),
    loopbackFlow: OAuthLoopbackFlow(authorizationLauncher: (_) async => true),
    nowUtc: () => DateTime.utc(2026, 6, 6),
  );
}

http.Response _tokenResponse() {
  return http.Response(
    jsonEncode({
      'access_token': 'access',
      'refresh_token': 'refresh',
      'expires_in': 3600,
      'token_type': 'Bearer',
      'scope': microsoftTodoOAuthScopes,
    }),
    200,
    headers: {'Content-Type': 'application/json'},
  );
}

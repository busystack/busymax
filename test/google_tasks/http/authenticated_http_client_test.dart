import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:busymax/src/config/build_config.dart';
import 'package:busymax/src/google_tasks/http/authenticated_http_client.dart';
import 'package:busymax/src/google_tasks/oauth/oauth_loopback_flow.dart';
import 'package:busymax/src/google_tasks/oauth/oauth_models.dart';
import 'package:busymax/src/google_tasks/oauth/oauth_service.dart';
import 'package:busymax/src/google_tasks/oauth/oauth_token_store.dart';

void main() {
  test('attaches bearer authorization header', () async {
    late String? authorization;
    final store = InMemoryOAuthTokenStore();
    await store.saveTokenSet('account', _tokenSet('access'));
    await store.setActiveAccountId('account');

    final client = AuthenticatedHttpClient(
      inner: MockClient((request) async {
        authorization = request.headers[authorizationHeaderName];
        return http.Response('{}', 200);
      }),
      oAuthService: _service(
        store,
        MockClient((request) async {
          fail('refresh should not be called');
        }),
      ),
      nowUtc: () => DateTime.utc(2026, 6, 4),
    );

    await client.get(Uri.parse('https://tasks.googleapis.com/tasks/v1'));

    expect(authorization, 'Bearer access');
  });

  test('refreshes once after 401 and retries original request', () async {
    final store = InMemoryOAuthTokenStore();
    await store.saveTokenSet('account', _tokenSet('old-access'));
    await store.setActiveAccountId('account');

    var apiCalls = 0;
    final apiClient = MockClient((request) async {
      apiCalls += 1;
      if (apiCalls == 1) {
        expect(request.headers[authorizationHeaderName], 'Bearer old-access');
        return http.Response('{}', 401);
      }
      expect(request.headers[authorizationHeaderName], 'Bearer new-access');
      return http.Response('{}', 200);
    });
    final tokenClient = MockClient((request) async {
      return http.Response(
        jsonEncode({
          'access_token': 'new-access',
          'expires_in': 3600,
          'scope': 'https://www.googleapis.com/auth/tasks',
          'token_type': 'Bearer',
        }),
        200,
      );
    });

    final client = AuthenticatedHttpClient(
      inner: apiClient,
      oAuthService: _service(store, tokenClient),
      nowUtc: () => DateTime.utc(2026, 6, 4),
    );

    final response = await client.get(
      Uri.parse('https://tasks.googleapis.com/tasks/v1'),
    );

    expect(response.statusCode, 200);
    expect(apiCalls, 2);
  });
}

OAuthService _service(OAuthTokenStore store, http.Client tokenClient) {
  return OAuthService(
    config: const BuildConfig(
      googleOAuthClientId: 'client-id',
      googleOAuthClientSecret: '',
      apiBaseUrl: 'https://tasks.googleapis.com',
      oauthAuthorizationEndpoint:
          'https://accounts.google.com/o/oauth2/v2/auth',
      oauthTokenEndpoint: 'https://oauth2.googleapis.com/token',
      oauthRevocationEndpoint: 'https://oauth2.googleapis.com/revoke',
    ),
    httpClient: tokenClient,
    tokenStore: store,
    loopbackFlow: OAuthLoopbackFlow(),
    nowUtc: () => DateTime.utc(2026, 6, 4),
  );
}

OAuthTokenSet _tokenSet(String accessToken) {
  return OAuthTokenSet(
    accessToken: accessToken,
    refreshToken: 'refresh',
    expiresAtUtc: DateTime.utc(2026, 6, 4, 1),
    tokenType: 'Bearer',
    scopes: const {'https://www.googleapis.com/auth/tasks'},
  );
}

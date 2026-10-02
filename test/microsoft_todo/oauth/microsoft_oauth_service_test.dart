import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:busymax/src/config/build_config.dart';
import 'package:busymax/src/google_tasks/oauth/oauth_loopback_flow.dart';
import 'package:busymax/src/core/auth/oauth_models.dart';
import 'package:busymax/src/core/secrets/secret_store.dart';
import 'package:busymax/src/microsoft_todo/oauth/microsoft_oauth_service.dart';
import 'package:busymax/src/providers/busy_provider.dart';

void main() {
  test(
    'short Graph optional scopes authorize their existing account',
    () async {
      final store = InMemorySecretStore();
      final service = MicrosoftOAuthService(
        config: _config,
        httpClient: MockClient(
          (_) async => throw StateError('No HTTP expected'),
        ),
        tokenStore: store,
        loopbackFlow: OAuthLoopbackFlow(
          authorizationLauncher: (_) async => false,
        ),
        nowUtc: () => DateTime.utc(2026, 6, 6),
      );
      await store.saveOAuthTokenSet(
        'microsoft:user',
        BusyProvider.microsoft,
        OAuthTokenSet(
          accessToken: 'short-access',
          refreshToken: 'refresh',
          expiresAtUtc: DateTime.utc(2026, 6, 7),
          tokenType: 'Bearer',
          scopes: const {
            'User.Read',
            'Tasks.ReadWrite',
            'Calendars.ReadWrite',
            'Calendars.ReadWrite.Shared',
            'MailboxSettings.Read',
          },
        ),
      );
      expect(
        await service.sharedCalendarAuthorizationHeaderForAccount(
          'microsoft:user',
        ),
        'Bearer short-access',
      );
      expect(
        await service.categoryAuthorizationHeaderForAccount('microsoft:user'),
        'Bearer short-access',
      );
      await service.authorizeSharedCalendarAccess('microsoft:user');
      await service.authorizeCategoryAccess('microsoft:user');
      expect(
        (await store.readOAuthTokenSet(
          'microsoft:user',
          BusyProvider.microsoft,
        ))!.accessToken,
        'short-access',
      );
    },
  );

  test(
    'short optional grants are requested on refresh but loss is honored',
    () async {
      late http.Request captured;
      final service = _service((request) async {
        captured = request;
        return http.Response(
          jsonEncode({
            'access_token': 'renewed',
            'expires_in': 3600,
            'scope': 'User.Read Tasks.ReadWrite Calendars.ReadWrite',
          }),
          200,
        );
      });
      final token = await service.refreshToken(
        OAuthTokenSet(
          accessToken: 'old',
          refreshToken: 'keep-refresh',
          expiresAtUtc: DateTime.utc(2026, 6, 6),
          tokenType: 'Bearer',
          scopes: const {
            'User.Read',
            'Tasks.ReadWrite',
            'Calendars.ReadWrite',
            'Calendars.ReadWrite.Shared',
            'MailboxSettings.Read',
          },
        ),
      );
      final requested = Uri.splitQueryString(captured.body)['scope']!;
      expect(requested, contains(microsoftSharedCalendarScope));
      expect(requested, contains(microsoftCategoryScope));
      expect(token.refreshToken, 'keep-refresh');
      expect(token.scopes, isNot(contains('Calendars.ReadWrite.Shared')));
      expect(token.scopes, isNot(contains('MailboxSettings.Read')));
    },
  );
  for (final optional in [
    microsoftSharedCalendarScope,
    microsoftCategoryScope,
  ]) {
    test(
      'desktop consent accepts short and mixed Graph grants for $optional',
      () async {
        final store = InMemorySecretStore();
        final flow = _ConsentFlow();
        final prior = optional == microsoftSharedCalendarScope
            ? microsoftCategoryScope
            : microsoftSharedCalendarScope;
        final priorShort = prior.substring(
          'https://graph.microsoft.com/'.length,
        );
        final optionalShort = optional.substring(
          'https://graph.microsoft.com/'.length,
        );
        await store.saveOAuthTokenSet(
          'microsoft:user',
          BusyProvider.microsoft,
          OAuthTokenSet(
            accessToken: 'old',
            refreshToken: 'old-refresh',
            expiresAtUtc: DateTime.utc(2026, 6, 7),
            tokenType: 'Bearer',
            scopes: {
              'User.Read',
              'Tasks.ReadWrite',
              'Calendars.ReadWrite',
              priorShort,
            },
          ),
        );
        final service = MicrosoftOAuthService(
          config: _config,
          httpClient: MockClient(
            (request) async => request.method == 'GET'
                ? http.Response(jsonEncode({'id': 'user'}), 200)
                : http.Response(
                    jsonEncode({
                      'access_token': 'consented',
                      'expires_in': 3600,
                      'scope':
                          'User.Read https://graph.microsoft.com/Tasks.ReadWrite '
                          'Calendars.ReadWrite $optionalShort $priorShort',
                    }),
                    200,
                  ),
          ),
          tokenStore: store,
          loopbackFlow: flow,
          nowUtc: () => DateTime.utc(2026, 6, 6),
        );
        if (optional == microsoftSharedCalendarScope) {
          await service.authorizeSharedCalendarAccess('microsoft:user');
        } else {
          await service.authorizeCategoryAccess('microsoft:user');
        }
        expect(flow.requestedScope, contains(optional));
        expect(flow.requestedScope, contains(prior));
        final saved = (await store.readOAuthTokenSet(
          'microsoft:user',
          BusyProvider.microsoft,
        ))!;
        expect(saved.accessToken, 'consented');
        expect(saved.refreshToken, 'old-refresh');
        expect(saved.scopes, containsAll([optionalShort, priorShort]));
      },
    );
  }

  test(
    'wrong-resource optional scopes do not authorize Graph access',
    () async {
      final store = InMemorySecretStore();
      await store.saveOAuthTokenSet(
        'microsoft:user',
        BusyProvider.microsoft,
        OAuthTokenSet(
          accessToken: 'wrong',
          refreshToken: 'refresh',
          expiresAtUtc: DateTime.utc(2026, 6, 7),
          tokenType: 'Bearer',
          scopes: const {
            'https://example.test/Calendars.ReadWrite.Shared',
            'https://example.test/MailboxSettings.Read',
          },
        ),
      );
      final service = MicrosoftOAuthService(
        config: _config,
        httpClient: MockClient(
          (_) async => throw StateError('No HTTP expected'),
        ),
        tokenStore: store,
        loopbackFlow: _ConsentFlow(),
        nowUtc: () => DateTime.utc(2026, 6, 6),
      );
      await expectLater(
        service.sharedCalendarAuthorizationHeaderForAccount('microsoft:user'),
        throwsA(isA<OAuthException>()),
      );
      await expectLater(
        service.categoryAuthorizationHeaderForAccount('microsoft:user'),
        throwsA(isA<OAuthException>()),
      );
    },
  );

  for (final optional in [
    microsoftSharedCalendarScope,
    microsoftCategoryScope,
  ]) {
    for (final denial in [
      'cancelled',
      'wrong account',
      'missing grant',
      'wrong resource',
    ]) {
      test('$optional $denial leaves the existing token intact', () async {
        final store = InMemorySecretStore();
        final previous = OAuthTokenSet(
          accessToken: 'working-access',
          refreshToken: 'working-refresh',
          expiresAtUtc: DateTime.utc(2026, 6, 7),
          tokenType: 'Bearer',
          scopes: const {'User.Read', 'Tasks.ReadWrite', 'Calendars.ReadWrite'},
        );
        await store.saveOAuthTokenSet(
          'microsoft:user',
          BusyProvider.microsoft,
          previous,
        );
        final flow = _ConsentFlow(
          error: denial == 'cancelled'
              ? const OAuthException('Cancelled', 'Consent cancelled')
              : null,
        );
        final service = MicrosoftOAuthService(
          config: _config,
          httpClient: MockClient((request) async {
            if (request.method == 'GET') {
              return http.Response(
                jsonEncode({
                  'id': denial == 'wrong account' ? 'other' : 'user',
                }),
                200,
              );
            }
            return http.Response(
              jsonEncode({
                'access_token': 'candidate-access',
                'expires_in': 3600,
                'scope': denial == 'missing grant'
                    ? 'User.Read Tasks.ReadWrite Calendars.ReadWrite'
                    : denial == 'wrong resource'
                    ? 'User.Read Tasks.ReadWrite Calendars.ReadWrite '
                          'https://example.test/${optional.substring('https://graph.microsoft.com/'.length)}'
                    : 'User.Read Tasks.ReadWrite Calendars.ReadWrite '
                          '${optional.substring('https://graph.microsoft.com/'.length)}',
              }),
              200,
            );
          }),
          tokenStore: store,
          loopbackFlow: flow,
          nowUtc: () => DateTime.utc(2026, 6, 6),
        );
        await expectLater(
          optional == microsoftSharedCalendarScope
              ? service.authorizeSharedCalendarAccess('microsoft:user')
              : service.authorizeCategoryAccess('microsoft:user'),
          throwsA(isA<OAuthException>()),
        );
        final saved = (await store.readOAuthTokenSet(
          'microsoft:user',
          BusyProvider.microsoft,
        ))!;
        expect(saved.accessToken, 'working-access');
        expect(saved.refreshToken, 'working-refresh');
        expect(saved.scopes, previous.scopes);
      });
    }
  }

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
    'shared-calendar refresh retains optional scope and ordinary account token',
    () async {
      late http.Request captured;
      final service = _service((request) async {
        captured = request;
        return http.Response(
          jsonEncode({
            'access_token': 'renewed',
            'refresh_token': 'refresh',
            'expires_in': 3600,
            'token_type': 'Bearer',
            'scope': '$microsoftTodoOAuthScopes $microsoftSharedCalendarScope',
          }),
          200,
        );
      });
      final token = await service.refreshToken(
        OAuthTokenSet(
          accessToken: 'access',
          refreshToken: 'refresh',
          expiresAtUtc: DateTime.utc(2026, 6, 6),
          tokenType: 'Bearer',
          scopes: const {microsoftSharedCalendarScope},
        ),
      );
      expect(
        Uri.splitQueryString(captured.body)['scope'],
        contains(microsoftSharedCalendarScope),
      );
      expect(token.scopes, contains(microsoftSharedCalendarScope));
    },
  );

  test(
    'owner-context header refuses a token without optional consent',
    () async {
      final store = InMemorySecretStore();
      final service = MicrosoftOAuthService(
        config: _config,
        httpClient: MockClient(
          (_) async => throw StateError('No request expected'),
        ),
        tokenStore: store,
        loopbackFlow: OAuthLoopbackFlow(
          authorizationLauncher: (_) async => true,
        ),
        nowUtc: () => DateTime.utc(2026, 6, 6),
      );
      await store.saveOAuthTokenSet(
        'microsoft:user',
        BusyProvider.microsoft,
        OAuthTokenSet(
          accessToken: 'ordinary',
          refreshToken: 'refresh',
          expiresAtUtc: DateTime.utc(2026, 6, 7),
          tokenType: 'Bearer',
          scopes: const {'https://graph.microsoft.com/Calendars.ReadWrite'},
        ),
      );
      expect(
        await service.authorizationHeaderForAccount('microsoft:user'),
        'Bearer ordinary',
      );
      await expectLater(
        service.sharedCalendarAuthorizationHeaderForAccount('microsoft:user'),
        throwsA(isA<OAuthException>()),
      );
      await expectLater(
        service.categoryAuthorizationHeaderForAccount('microsoft:user'),
        throwsA(isA<OAuthException>()),
      );
    },
  );

  test(
    'category consent remains account-scoped and survives refresh scope selection',
    () async {
      late http.Request captured;
      final service = _service((request) async {
        captured = request;
        return http.Response(
          jsonEncode({
            'access_token': 'renewed',
            'refresh_token': 'refresh',
            'expires_in': 3600,
            'token_type': 'Bearer',
            'scope': '$microsoftTodoOAuthScopes $microsoftCategoryScope',
          }),
          200,
        );
      });
      final token = await service.refreshToken(
        OAuthTokenSet(
          accessToken: 'access',
          refreshToken: 'refresh',
          expiresAtUtc: DateTime.utc(2026, 6, 6),
          tokenType: 'Bearer',
          scopes: const {microsoftCategoryScope},
        ),
      );
      expect(
        Uri.splitQueryString(captured.body)['scope'],
        contains(microsoftCategoryScope),
      );
      expect(token.scopes, contains(microsoftCategoryScope));
    },
  );

  test('refresh failure preserves the token endpoint status', () async {
    final service = _service((request) async {
      return http.Response(
        jsonEncode({
          'error': 'temporarily_unavailable',
          'error_description': 'Try again later.',
        }),
        503,
      );
    });

    await expectLater(
      service.refreshToken(
        OAuthTokenSet(
          accessToken: 'access',
          refreshToken: 'refresh',
          expiresAtUtc: DateTime.utc(2026, 6, 6),
          tokenType: 'Bearer',
          scopes: const {},
        ),
      ),
      throwsA(
        isA<OAuthRefreshException>()
            .having((error) => error.statusCode, 'statusCode', 503)
            .having(
              (error) => error.code,
              'code',
              'MicrosoftOAuthRefreshFailed',
            ),
      ),
    );
  });

  test('refresh completion cannot restore a removed credential', () async {
    final store = InMemorySecretStore();
    final started = Completer<void>();
    final release = Completer<void>();
    final service = MicrosoftOAuthService(
      config: _config,
      httpClient: MockClient((request) async {
        started.complete();
        await release.future;
        return _tokenResponse();
      }),
      tokenStore: store,
      loopbackFlow: OAuthLoopbackFlow(authorizationLauncher: (_) async => true),
      nowUtc: () => DateTime.utc(2026, 6, 6),
    );
    final original = OAuthTokenSet(
      accessToken: 'old-access',
      refreshToken: 'old-refresh',
      expiresAtUtc: DateTime.utc(2026, 6, 6),
      tokenType: 'Bearer',
      scopes: const {'User.Read'},
    );
    await store.saveOAuthTokenSet(
      'microsoft:user-1',
      BusyProvider.microsoft,
      original,
    );

    final refresh = service.refreshTokenForAccount('microsoft:user-1');
    await started.future;
    await service.signOutAccount('microsoft:user-1');
    release.complete();

    await expectLater(refresh, throwsA(isA<OAuthException>()));
    expect(await store.readCredential('microsoft:user-1'), isNull);
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
    config: _config,
    httpClient: MockClient(handler),
    tokenStore: InMemorySecretStore(),
    loopbackFlow: OAuthLoopbackFlow(authorizationLauncher: (_) async => true),
    nowUtc: () => DateTime.utc(2026, 6, 6),
  );
}

const _config = BuildConfig(
  googleOAuthClientId: '',
  googleOAuthClientSecret: '',
  microsoftOAuthClientId: 'microsoft-client-id',
  apiBaseUrl: 'https://tasks.googleapis.com',
  oauthAuthorizationEndpoint: 'https://accounts.google.com/o/oauth2/v2/auth',
  oauthTokenEndpoint: 'https://oauth2.googleapis.com/token',
  oauthRevocationEndpoint: 'https://oauth2.googleapis.com/revoke',
);

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

class _ConsentFlow extends OAuthLoopbackFlow {
  _ConsentFlow({this.error}) : super(authorizationLauncher: (_) async => false);

  String? requestedScope;
  final OAuthException? error;

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
    requestedScope = scope;
    if (error case final failure?) throw failure;
    return const OAuthLoopbackResult(
      callback: OAuthCallbackResult(code: 'code', scope: null),
      redirectUri: 'http://localhost:4321/',
      codeVerifier: 'verifier',
    );
  }
}

import 'dart:convert';
import 'dart:io';

import 'package:busymax/src/core/auth/authorization_attempt.dart';
import 'package:busymax/src/core/auth/authorization_persistence.dart';
import 'package:busymax/src/core/auth/oauth_models.dart';
import 'package:busymax/src/core/auth/registration_file_reader.dart';
import 'package:busymax/src/core/auth/registration_staging.dart';
import 'package:busymax/src/core/secrets/secret_store.dart';
import 'package:busymax/src/db/app_database.dart';
import 'package:busymax/src/google_tasks/api/google_tasks_api_surface.dart';
import 'package:busymax/src/google_tasks/oauth/oauth_loopback_flow.dart';
import 'package:busymax/src/google_tasks/oauth/oauth_service.dart';
import 'package:busymax/src/microsoft_todo/oauth/microsoft_oauth_service.dart';
import 'package:file_selector/file_selector.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'desktop_registration_config.dart';

// Production services and persistence with synthetic provider replies only.
// Used through real Settings callers; this never opens a live authorization.
class DesktopConnectionFixture {
  DesktopConnectionFixture(this.database, RegistrationFileReader reader) {
    persistence = AuthorizationPersistence(
      database: database,
      secrets: secrets,
    );
    staging = RegistrationStaging(
      config,
      fileReader: reader,
      filePicker: () async => XFile(
        File('test/fixtures/oauth/desktop_synthetic.json').absolute.path,
      ),
    );
    final httpClient = MockClient((request) async {
      if (request.method == 'GET') {
        return http.Response(
          jsonEncode(
            request.url.host == 'graph.microsoft.com'
                ? {'id': 'fixture-user', 'displayName': 'Synthetic account'}
                : {'sub': 'fixture-user', 'email': 'fixture@example.invalid'},
          ),
          200,
        );
      }
      final client = Uri.splitQueryString(request.body)['client_id'];
      return http.Response(
        jsonEncode({
          'access_token': 'synthetic-access',
          'refresh_token': 'synthetic-refresh',
          'expires_in': 3600,
          'scope': request.url.host == 'login.microsoftonline.com'
              ? flow.scope
              : googleBusyMaxOAuthScope,
          if (request.url.host == 'login.microsoftonline.com')
            'id_token':
                'header.${base64UrlEncode(utf8.encode(jsonEncode({'tid': '11111111-1111-1111-1111-111111111111', 'aud': client})))}.signature',
        }),
        200,
      );
    });
    google = OAuthService(
      config: config,
      httpClient: httpClient,
      tokenStore: secrets,
      loopbackFlow: flow,
      registrations: staging,
      persistence: persistence,
    );
    microsoft = MicrosoftOAuthService(
      config: config,
      httpClient: httpClient,
      tokenStore: secrets,
      loopbackFlow: flow,
      registrations: staging,
      persistence: persistence,
    );
  }
  final AppDatabase database;
  final config = syntheticDesktopConfig();
  final secrets = InMemorySecretStore();
  final flow = _FixtureBrowser();
  late final AuthorizationPersistence persistence;
  late final RegistrationStaging staging;
  late final OAuthService google;
  late final MicrosoftOAuthService microsoft;
}

class _FixtureBrowser extends OAuthLoopbackFlow {
  _FixtureBrowser() : super(authorizationLauncher: (_) async => false);
  final clients = <String>[];
  String scope = '';
  @override
  Future<OAuthLoopbackResult> start({
    required Uri authorizationEndpoint,
    required String clientId,
    required String scope,
    String redirectHost = '127.0.0.1',
    String signInCancelledMessage = '',
    String callbackNotReceivedMessage = '',
    String serverStartFailureMessage = '',
    String browserLaunchFailureMessage = '',
    Map<String, String> extraAuthorizationParameters = const {},
    String? loginHint,
    AuthorizationAttempt? attempt,
  }) async {
    attempt?.check();
    clients.add(clientId);
    this.scope = scope;
    return OAuthLoopbackResult(
      callback: OAuthCallbackResult(code: 'synthetic-code', scope: scope),
      redirectUri: 'http://$redirectHost:4321/',
      codeVerifier: 'synthetic-verifier',
    );
  }
}

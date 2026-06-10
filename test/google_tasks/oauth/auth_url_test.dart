import 'package:flutter_test/flutter_test.dart';
import 'package:busymax/src/google_tasks/oauth/oauth_loopback_flow.dart';

void main() {
  test('authorization URL contains exactly required parameters', () {
    final uri = buildAuthorizationUri(
      authorizationEndpoint: Uri.parse(
        'https://accounts.google.com/o/oauth2/v2/auth',
      ),
      clientId: 'client-id',
      redirectUri: 'http://127.0.0.1:12345/',
      scope: googleTasksOAuthScope,
      codeChallenge: 'challenge',
      state: 'state',
    );

    expect(uri.scheme, 'https');
    expect(uri.host, 'accounts.google.com');
    expect(uri.path, '/o/oauth2/v2/auth');
    expect(uri.queryParameters, {
      'client_id': 'client-id',
      'redirect_uri': 'http://127.0.0.1:12345/',
      'response_type': 'code',
      'scope': googleTasksOAuthScope,
      'code_challenge': 'challenge',
      'code_challenge_method': 'S256',
      'state': 'state',
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:busymax/src/config/build_config.dart';

void main() {
  test('fromEnvironment uses Google endpoint defaults', () {
    final config = BuildConfig.fromEnvironment();

    expect(config.googleOAuthClientSecret, '');
    expect(config.googleApiBaseUrl, 'https://www.googleapis.com');
    expect(config.apiBaseUrl, 'https://www.googleapis.com');
    expect(config.feedbackEndpoint, 'https://busystack.org/api/feedback');
    expect(
      config.oauthAuthorizationEndpoint,
      'https://accounts.google.com/o/oauth2/v2/auth',
    );
    expect(config.oauthTokenEndpoint, 'https://oauth2.googleapis.com/token');
    expect(
      config.oauthRevocationEndpoint,
      'https://oauth2.googleapis.com/revoke',
    );
  });

  test('missing client id has developer run command', () {
    const config = BuildConfig(
      googleOAuthClientId: '',
      googleOAuthClientSecret: '',
      googleApiBaseUrl: 'https://www.googleapis.com',
      oauthAuthorizationEndpoint:
          'https://accounts.google.com/o/oauth2/v2/auth',
      oauthTokenEndpoint: 'https://oauth2.googleapis.com/token',
      oauthRevocationEndpoint: 'https://oauth2.googleapis.com/revoke',
    );

    expect(config.hasGoogleOAuthClientId, isFalse);
    expect(config.missingClientIdMessage, contains('flutter run -d linux'));
  });
}

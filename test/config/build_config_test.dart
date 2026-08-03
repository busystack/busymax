import 'package:flutter_test/flutter_test.dart';
import 'package:busymax/src/config/build_config.dart';

void main() {
  test('fromEnvironment uses Google endpoint defaults', () {
    final config = BuildConfig.fromEnvironment();

    expect(config.googleOAuthClientSecret, '');
    expect(config.googleApiBaseUrl, 'https://www.googleapis.com');
    expect(config.apiBaseUrl, 'https://www.googleapis.com');
    expect(config.feedbackEndpoint, 'https://busystack.org/api/feedback');
    expect(config.useFakeProviderData, isFalse);
    expect(config.demoTheme, BusyMaxDemoTheme.system);
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

  test('demo mode is never enabled in release builds', () {
    expect(busyMaxDemoModeEnabled(requested: true, releaseMode: false), isTrue);
    expect(busyMaxDemoModeEnabled(requested: true, releaseMode: true), isFalse);
    expect(
      busyMaxDemoModeEnabled(requested: false, releaseMode: false),
      isFalse,
    );
  });

  test('demo mode exposes only its local Google account flow', () {
    const config = BuildConfig(
      googleOAuthClientId: '',
      googleOAuthClientSecret: '',
      microsoftOAuthClientId: 'real-microsoft-client',
      oauthAuthorizationEndpoint: 'https://example.test/authorize',
      oauthTokenEndpoint: 'https://example.test/token',
      oauthRevocationEndpoint: 'https://example.test/revoke',
      useFakeProviderData: true,
      demoTheme: BusyMaxDemoTheme.dark,
    );

    expect(config.hasGoogleOAuthClientId, isTrue);
    expect(config.hasMicrosoftOAuthClientId, isFalse);
    expect(config.hasAnyProviderConfigured, isTrue);
    expect(config.demoTheme, BusyMaxDemoTheme.dark);
  });

  test('demo theme parser is tolerant and defaults to system', () {
    expect(parseBusyMaxDemoTheme('LIGHT'), BusyMaxDemoTheme.light);
    expect(parseBusyMaxDemoTheme(' dark '), BusyMaxDemoTheme.dark);
    expect(parseBusyMaxDemoTheme('invalid'), BusyMaxDemoTheme.system);
    expect(parseBusyMaxDemoTheme(''), BusyMaxDemoTheme.system);
  });
}

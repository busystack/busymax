import 'package:flutter/foundation.dart';

class BuildConfig {
  const BuildConfig({
    required this.googleOAuthClientId,
    required this.googleOAuthClientSecret,
    this.microsoftOAuthClientId = '',
    this.microsoftOAuthAuthorityTenant = 'common',
    this.microsoftGraphBaseUrl = 'https://graph.microsoft.com/v1.0',
    this.googleApiBaseUrl = 'https://www.googleapis.com',
    String? apiBaseUrl,
    required this.oauthAuthorizationEndpoint,
    required this.oauthTokenEndpoint,
    required this.oauthRevocationEndpoint,
  }) : apiBaseUrl = apiBaseUrl ?? googleApiBaseUrl;

  factory BuildConfig.fromEnvironment() => const BuildConfig(
    googleOAuthClientId: String.fromEnvironment('GOOGLE_OAUTH_CLIENT_ID'),
    googleOAuthClientSecret: String.fromEnvironment(
      'GOOGLE_OAUTH_CLIENT_SECRET',
    ),
    microsoftOAuthClientId: String.fromEnvironment('MICROSOFT_OAUTH_CLIENT_ID'),
    microsoftOAuthAuthorityTenant: String.fromEnvironment(
      'MICROSOFT_OAUTH_AUTHORITY_TENANT',
      defaultValue: 'common',
    ),
    microsoftGraphBaseUrl: String.fromEnvironment(
      'MICROSOFT_GRAPH_BASE_URL',
      defaultValue: 'https://graph.microsoft.com/v1.0',
    ),
    googleApiBaseUrl: String.fromEnvironment(
      'GOOGLE_API_BASE_URL',
      defaultValue: 'https://www.googleapis.com',
    ),
    oauthAuthorizationEndpoint: String.fromEnvironment(
      'GOOGLE_OAUTH_AUTHORIZATION_ENDPOINT',
      defaultValue: 'https://accounts.google.com/o/oauth2/v2/auth',
    ),
    oauthTokenEndpoint: String.fromEnvironment(
      'GOOGLE_OAUTH_TOKEN_ENDPOINT',
      defaultValue: 'https://oauth2.googleapis.com/token',
    ),
    oauthRevocationEndpoint: String.fromEnvironment(
      'GOOGLE_OAUTH_REVOCATION_ENDPOINT',
      defaultValue: 'https://oauth2.googleapis.com/revoke',
    ),
  );

  final String googleOAuthClientId;
  final String googleOAuthClientSecret;
  final String microsoftOAuthClientId;
  final String microsoftOAuthAuthorityTenant;
  final String microsoftGraphBaseUrl;
  final String googleApiBaseUrl;
  final String apiBaseUrl;
  final String oauthAuthorizationEndpoint;
  final String oauthTokenEndpoint;
  final String oauthRevocationEndpoint;

  bool get hasGoogleOAuthClientId => googleOAuthClientId.trim().isNotEmpty;
  bool get hasMicrosoftOAuthClientId =>
      microsoftOAuthClientId.trim().isNotEmpty;
  bool get hasAnyProviderConfigured =>
      hasGoogleOAuthClientId || hasMicrosoftOAuthClientId;

  String get missingClientIdMessage {
    if (kReleaseMode) {
      return 'BusyMax is not configured for sign-in. '
          'Please install an official build.';
    }

    return 'Missing provider configuration. Run with at least one provider:\n'
        'flutter run -d linux '
        '--dart-define=GOOGLE_OAUTH_CLIENT_ID=<desktop-client-id> '
        '--dart-define=GOOGLE_OAUTH_CLIENT_SECRET=<desktop-client-secret> '
        '--dart-define=MICROSOFT_OAUTH_CLIENT_ID=<public-client-id>';
  }

  String get missingMicrosoftClientIdMessage {
    return 'Microsoft sign-in is not configured. '
        'Set MICROSOFT_OAUTH_CLIENT_ID.';
  }
}

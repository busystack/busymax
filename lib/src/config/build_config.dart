import 'package:flutter/foundation.dart';

enum BusyMaxDemoTheme { system, light, dark }

class BuildConfig {
  const BuildConfig({
    required this.googleOAuthClientId,
    required this.googleOAuthClientSecret,
    this.microsoftOAuthClientId = '',
    this.microsoftOAuthAuthorityTenant = 'common',
    this.microsoftGraphBaseUrl = 'https://graph.microsoft.com/v1.0',
    this.googleApiBaseUrl = 'https://www.googleapis.com',
    this.feedbackEndpoint = 'https://busystack.org/api/feedback',
    this.privacyPolicyUrl = '',
    this.supportUrl = '',
    this.homepageUrl = 'https://busystack.org',
    this.windowsAppUserModelId = '',
    this.windowsPackageVersion = '',
    this.windowsStoreMode = false,
    String? apiBaseUrl,
    required this.oauthAuthorizationEndpoint,
    required this.oauthTokenEndpoint,
    required this.oauthRevocationEndpoint,
    this.useFakeProviderData = false,
    this.demoTheme = BusyMaxDemoTheme.system,
  }) : apiBaseUrl = apiBaseUrl ?? googleApiBaseUrl;

  factory BuildConfig.fromEnvironment() {
    const fakeProviderDataRequested = bool.fromEnvironment('BUSYMAX_FAKE_DATA');
    final useFakeProviderData = busyMaxDemoModeEnabled(
      requested: fakeProviderDataRequested,
      releaseMode: kReleaseMode,
    );
    return BuildConfig(
      googleOAuthClientId: const String.fromEnvironment(
        'GOOGLE_OAUTH_CLIENT_ID',
      ),
      googleOAuthClientSecret: const String.fromEnvironment(
        'GOOGLE_OAUTH_CLIENT_SECRET',
      ),
      microsoftOAuthClientId: const String.fromEnvironment(
        'MICROSOFT_OAUTH_CLIENT_ID',
      ),
      microsoftOAuthAuthorityTenant: const String.fromEnvironment(
        'MICROSOFT_OAUTH_AUTHORITY_TENANT',
        defaultValue: 'common',
      ),
      microsoftGraphBaseUrl: const String.fromEnvironment(
        'MICROSOFT_GRAPH_BASE_URL',
        defaultValue: 'https://graph.microsoft.com/v1.0',
      ),
      googleApiBaseUrl: const String.fromEnvironment(
        'GOOGLE_API_BASE_URL',
        defaultValue: 'https://www.googleapis.com',
      ),
      feedbackEndpoint: const String.fromEnvironment(
        'BUSYSTACK_FEEDBACK_ENDPOINT',
        defaultValue: 'https://busystack.org/api/feedback',
      ),
      privacyPolicyUrl: const String.fromEnvironment(
        'BUSYMAX_PRIVACY_POLICY_URL',
      ),
      supportUrl: const String.fromEnvironment('BUSYMAX_SUPPORT_URL'),
      homepageUrl: const String.fromEnvironment(
        'BUSYMAX_HOMEPAGE_URL',
        defaultValue: 'https://busystack.org',
      ),
      windowsAppUserModelId: const String.fromEnvironment(
        'BUSYMAX_WINDOWS_AUMID',
      ),
      windowsPackageVersion: const String.fromEnvironment(
        'BUSYMAX_MSIX_VERSION',
      ),
      windowsStoreMode: const bool.fromEnvironment(
        'BUSYMAX_WINDOWS_STORE_MODE',
      ),
      oauthAuthorizationEndpoint: const String.fromEnvironment(
        'GOOGLE_OAUTH_AUTHORIZATION_ENDPOINT',
        defaultValue: 'https://accounts.google.com/o/oauth2/v2/auth',
      ),
      oauthTokenEndpoint: const String.fromEnvironment(
        'GOOGLE_OAUTH_TOKEN_ENDPOINT',
        defaultValue: 'https://oauth2.googleapis.com/token',
      ),
      oauthRevocationEndpoint: const String.fromEnvironment(
        'GOOGLE_OAUTH_REVOCATION_ENDPOINT',
        defaultValue: 'https://oauth2.googleapis.com/revoke',
      ),
      useFakeProviderData: useFakeProviderData,
      demoTheme: useFakeProviderData
          ? parseBusyMaxDemoTheme(
              const String.fromEnvironment(
                'BUSYMAX_FAKE_THEME',
                defaultValue: 'system',
              ),
            )
          : BusyMaxDemoTheme.system,
    );
  }

  final String googleOAuthClientId;
  final String googleOAuthClientSecret;
  final String microsoftOAuthClientId;
  final String microsoftOAuthAuthorityTenant;
  final String microsoftGraphBaseUrl;
  final String googleApiBaseUrl;
  final String feedbackEndpoint;
  final String privacyPolicyUrl;
  final String supportUrl;
  final String homepageUrl;
  final String windowsAppUserModelId;
  final String windowsPackageVersion;
  final bool windowsStoreMode;
  final String apiBaseUrl;
  final String oauthAuthorizationEndpoint;
  final String oauthTokenEndpoint;
  final String oauthRevocationEndpoint;
  final bool useFakeProviderData;
  final BusyMaxDemoTheme demoTheme;

  bool get hasGoogleOAuthClientId =>
      useFakeProviderData || googleOAuthClientId.trim().isNotEmpty;
  bool get hasMicrosoftOAuthClientId =>
      !useFakeProviderData && microsoftOAuthClientId.trim().isNotEmpty;
  bool get hasAppleICloudProvider => !useFakeProviderData;
  bool get hasNextcloudProvider => !useFakeProviderData;
  bool get hasAnyProviderConfigured =>
      hasGoogleOAuthClientId ||
      hasMicrosoftOAuthClientId ||
      hasAppleICloudProvider ||
      hasNextcloudProvider;

  String get missingClientIdMessage {
    if (kReleaseMode) {
      return 'BusyMax is not configured for sign-in. '
          'Please install an official build.';
    }

    return 'Missing provider configuration. Run the platform entrypoint with '
        'at least one provider:\n'
        '--dart-define=GOOGLE_OAUTH_CLIENT_ID=<desktop-client-id> '
        '--dart-define=GOOGLE_OAUTH_CLIENT_SECRET=<desktop-client-secret> '
        '--dart-define=MICROSOFT_OAUTH_CLIENT_ID=<public-client-id>';
  }

  String get missingMicrosoftClientIdMessage {
    return 'Microsoft sign-in is not configured. '
        'Set MICROSOFT_OAUTH_CLIENT_ID.';
  }
}

@visibleForTesting
bool busyMaxDemoModeEnabled({
  required bool requested,
  required bool releaseMode,
}) {
  return requested && !releaseMode;
}

BusyMaxDemoTheme parseBusyMaxDemoTheme(String value) {
  return switch (value.trim().toLowerCase()) {
    'light' => BusyMaxDemoTheme.light,
    'dark' => BusyMaxDemoTheme.dark,
    _ => BusyMaxDemoTheme.system,
  };
}

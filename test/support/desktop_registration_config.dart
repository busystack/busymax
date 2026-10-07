import 'package:busymax/src/config/build_config.dart';

// Synthetic values used only by tests. Never include these in official packages.
BuildConfig syntheticDesktopConfig({bool managed = true, bool later = false}) =>
    BuildConfig(
      googleOAuthClientId: 'original.apps.googleusercontent.com',
      googleOAuthClientSecret: '',
      microsoftOAuthClientId: '22222222-2222-2222-2222-222222222222',
      busyMaxGoogleOAuthClientId: managed
          ? '${later ? 'later' : 'managed'}.apps.googleusercontent.com'
          : '',
      busyMaxGoogleOAuthClientSecret: managed ? 'synthetic-public-secret' : '',
      busyMaxGoogleOAuthProjectId: managed ? 'synthetic-managed-project' : '',
      busyMaxMicrosoftOAuthClientId: managed
          ? later
                ? '55555555-5555-5555-5555-555555555555'
                : '44444444-4444-4444-4444-444444444444'
          : '',
      busyMaxMicrosoftOAuthAuthorityTenant: managed ? 'organizations' : '',
      oauthAuthorizationEndpoint:
          'https://accounts.google.com/o/oauth2/v2/auth',
      oauthTokenEndpoint: 'https://oauth2.googleapis.com/token',
      oauthRevocationEndpoint: 'https://oauth2.googleapis.com/revoke',
    );

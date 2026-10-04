import '../../l10n/generated/app_localizations.dart';
import '../core/auth/oauth_registration.dart';
import '../core/auth/registration_setup_controller.dart';
import '../providers/busy_provider.dart';

/// Desktop guide copy and selectable values shared by the native dialogs.
/// The widgets and scroll area remain owned by each platform.
typedef RegistrationGuideStep = ({
  String heading,
  String body,
  String? values,
  String? valuesLabel,
  bool copyAll,
  String? linkLabel,
  String? link,
});

extension RegistrationSetupContent on AppLocalizations {
  String registrationAudienceLabel(MicrosoftAudience value) => switch (value) {
    MicrosoftAudience.personalAndOrganizations => registrationBothAudience,
    MicrosoftAudience.organizations => registrationOrganizationAudience,
    MicrosoftAudience.personal => registrationPersonalAudience,
    MicrosoftAudience.tenant => registrationTenantAudience,
  };

  String? registrationSetupError(RegistrationSetupController setup) {
    if (setup.expired) return registrationExpired;
    return switch (setup.errorCode) {
      null => null,
      'OAuthRetiringRegistration' => registrationOwnProjectRequired,
      'OAuthSetupFailed' => registrationSetupFailed,
      _ =>
        setup.provider == BusyProvider.google
            ? registrationGoogleImportFailed
            : oauthRegistrationRejected,
    };
  }

  List<RegistrationGuideStep> registrationDesktopSteps(BusyProvider provider) =>
      provider == BusyProvider.google
      ? [
          (
            heading: registrationGoogleProject,
            body: registrationGuideGoogleProject,
            values: null,
            valuesLabel: null,
            copyAll: false,
            linkLabel: registrationOpenGoogleConsole,
            link: 'https://console.cloud.google.com/',
          ),
          (
            heading: registrationEnableApis,
            body: registrationGuideGoogleApis,
            values: null,
            valuesLabel: null,
            copyAll: false,
            linkLabel: registrationOpenApiLibrary,
            link: 'https://console.cloud.google.com/apis/library',
          ),
          (
            heading: registrationConsentScreen,
            body: registrationGuideGoogleAudience,
            values: 'BusyMax',
            valuesLabel: registrationAppName,
            copyAll: false,
            linkLabel: registrationOpenBranding,
            link: 'https://console.cloud.google.com/auth/branding',
          ),
          (
            heading: registrationPermissions,
            body: registrationGuideGooglePermissions,
            values:
                'openid\nemail\nprofile\n'
                'https://www.googleapis.com/auth/tasks\n'
                'https://www.googleapis.com/auth/calendar',
            valuesLabel: registrationScopes,
            copyAll: true,
            linkLabel: registrationOpenDataAccess,
            link: 'https://console.cloud.google.com/auth/scopes',
          ),
          (
            heading: registrationDesktopClient,
            body: registrationGuideGoogleClient,
            values: null,
            valuesLabel: null,
            copyAll: false,
            linkLabel: registrationOpenClients,
            link: 'https://console.cloud.google.com/auth/clients',
          ),
        ]
      : [
          (
            heading: registrationMicrosoftApp,
            body: registrationGuideMicrosoftApp,
            values: 'BusyMax',
            valuesLabel: registrationAppName,
            copyAll: false,
            linkLabel: registrationOpenEntra,
            link: 'https://entra.microsoft.com/',
          ),
          (
            heading: registrationAudience,
            body: registrationGuideMicrosoftAudience,
            values: null,
            valuesLabel: null,
            copyAll: false,
            linkLabel: null,
            link: null,
          ),
          (
            heading: registrationDesktopClient,
            body: registrationGuideMicrosoftRedirect,
            values: 'http://localhost',
            valuesLabel: registrationRedirectUri,
            copyAll: false,
            linkLabel: registrationOpenEntraAuthentication,
            link:
                'https://entra.microsoft.com/#view/Microsoft_AAD_RegisteredApps/ApplicationsListBlade',
          ),
          (
            heading: registrationPermissions,
            body: registrationGuideMicrosoftPermissions,
            values:
                'User.Read\nTasks.ReadWrite\nCalendars.ReadWrite\n'
                'openid\nprofile\nemail\noffline_access',
            valuesLabel: registrationScopes,
            copyAll: true,
            linkLabel: registrationOpenEntraPermissions,
            link:
                'https://entra.microsoft.com/#view/Microsoft_AAD_RegisteredApps/ApplicationsListBlade',
          ),
          (
            heading: registrationConnect,
            body: registrationGuideMicrosoftConnect,
            values: null,
            valuesLabel: null,
            copyAll: false,
            linkLabel: null,
            link: null,
          ),
        ];
}

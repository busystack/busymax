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
      'OAuthSharedUnavailable' => registrationSharedUnavailable,
      _ =>
        setup.provider == BusyProvider.google
            ? registrationGoogleImportFailed
            : oauthRegistrationRejected,
    };
  }

  String registrationConfigurationTitle(
    BusyProvider provider,
    DesktopConnectionMethod method,
  ) => provider == BusyProvider.microsoft
      ? registrationMicrosoftCustom
      : method == DesktopConnectionMethod.googleWorkspace
      ? registrationWorkspace
      : registrationGoogleCustom;

  String registrationInstructionsTitle(
    BusyProvider provider,
    DesktopConnectionMethod method,
  ) => provider == BusyProvider.microsoft
      ? registrationMicrosoftSetupInstructions
      : method == DesktopConnectionMethod.googleWorkspace
      ? registrationWorkspaceSetupInstructions
      : registrationGoogleSetupInstructions;

  List<RegistrationGuideStep> registrationDesktopSteps(
    BusyProvider provider, {
    DesktopConnectionMethod method = DesktopConnectionMethod.custom,
  }) {
    RegistrationGuideStep step(
      String heading,
      String body, {
      String? values,
      String? valuesLabel,
      bool copyAll = false,
      String? linkLabel,
      String? link,
    }) => (
      heading: heading,
      body: body,
      values: values,
      valuesLabel: valuesLabel,
      copyAll: copyAll,
      linkLabel: linkLabel,
      link: link,
    );
    if (provider == BusyProvider.google) {
      final workspace = method == DesktopConnectionMethod.googleWorkspace;
      return [
        step(
          registrationGoogleProject,
          workspace
              ? registrationGuideWorkspaceProject
              : registrationGuideGoogleProject,
          linkLabel: registrationOpenGoogleConsole,
          link: workspace
              ? 'https://console.cloud.google.com/cloud-resource-manager'
              : 'https://console.cloud.google.com/',
        ),
        step(
          registrationEnableApis,
          registrationGuideGoogleApis,
          linkLabel: registrationOpenApiLibrary,
          link: 'https://console.cloud.google.com/apis/library',
        ),
        step(
          registrationConsentScreen,
          workspace
              ? registrationGuideWorkspaceAudience
              : registrationGuideGoogleAudience,
          values: 'BusyMax',
          valuesLabel: registrationAppName,
          linkLabel: registrationOpenBranding,
          link: 'https://console.cloud.google.com/auth/branding',
        ),
        if (!workspace)
          step(
            registrationBranding,
            registrationGuideGoogleBranding,
            values: 'https://busystack.org/privacy-busymax',
            valuesLabel: privacy,
            linkLabel: registrationOpenBranding,
            link: 'https://console.cloud.google.com/auth/branding',
          ),
        step(
          registrationPermissions,
          workspace
              ? registrationGuideWorkspacePermissions
              : registrationGuideGooglePermissions,
          values:
              'openid\nemail\nprofile\n'
              'https://www.googleapis.com/auth/tasks\n'
              'https://www.googleapis.com/auth/calendar',
          valuesLabel: registrationScopes,
          copyAll: true,
          linkLabel: registrationOpenDataAccess,
          link: 'https://console.cloud.google.com/auth/scopes',
        ),
        if (!workspace)
          step(
            registrationPublishing,
            registrationGuideGooglePublishing,
            linkLabel: registrationOpenAudience,
            link: 'https://console.cloud.google.com/auth/audience',
          ),
        step(
          registrationDesktopClient,
          registrationGuideGoogleClient,
          linkLabel: registrationOpenClients,
          link: 'https://console.cloud.google.com/auth/clients',
        ),
      ];
    }
    return [
      step(
        registrationMicrosoftApp,
        registrationGuideMicrosoftApp,
        values: 'BusyMax',
        valuesLabel: registrationAppName,
        linkLabel: registrationOpenEntra,
        link: 'https://entra.microsoft.com/',
      ),
      step(registrationAudience, registrationGuideMicrosoftAudience),
      step(
        registrationDesktopClient,
        registrationGuideMicrosoftRedirect,
        values: 'http://localhost',
        valuesLabel: registrationRedirectUri,
        linkLabel: registrationOpenEntraAuthentication,
        link:
            'https://entra.microsoft.com/#view/Microsoft_AAD_RegisteredApps/ApplicationsListBlade',
      ),
      step(
        registrationPermissions,
        '$registrationGuideMicrosoftPermissions\n\n$registrationGuideMicrosoftOptionalPermissions',
        values:
            'User.Read\nTasks.ReadWrite\nCalendars.ReadWrite\n'
            'openid\nprofile\nemail\noffline_access',
        valuesLabel: registrationScopes,
        copyAll: true,
        linkLabel: registrationOpenEntraPermissions,
        link:
            'https://entra.microsoft.com/#view/Microsoft_AAD_RegisteredApps/ApplicationsListBlade',
      ),
      step(registrationConnect, registrationGuideMicrosoftConnect),
    ];
  }
}

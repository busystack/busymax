import '../../l10n/generated/app_localizations.dart';
import '../core/auth/oauth_registration.dart';

extension RegistrationDescription on AppLocalizations {
  String registrationDescription(RegistrationSummary summary) => [
    switch (summary.origin) {
      RegistrationOrigin.userProvided => registrationUserOwned,
      RegistrationOrigin.retiringShared => registrationShared,
      RegistrationOrigin.nativeGoogleAndroid => registrationNativeGoogle,
    },
    if (summary.origin != RegistrationOrigin.nativeGoogleAndroid)
      registrationSummary(summary.clientId),
    if (summary.projectId != null)
      '$registrationGoogleProject: ${summary.projectId}',
    if (summary.authority != null)
      '$registrationAudience: ${summary.authority}',
  ].join('\n');
}

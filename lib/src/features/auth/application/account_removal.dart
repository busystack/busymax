import '../../../dav/auth/dav_account_onboarding_service.dart';
import '../../../providers/busy_provider.dart';
import '../data/auth_repository.dart';

enum AccountRemovalOutcome {
  removed,
  googleRevocationFailed,
  davRevocationFailed,
}

Future<AccountRemovalOutcome> removeBusyMaxAccount({
  required String accountId,
  required BusyProvider provider,
  required bool revokeGoogleAuthorization,
  required AuthRepository Function() auth,
  required DavAccountOnboardingService Function() dav,
  required Future<void> Function() resetScheduleVisibility,
  Future<AccountRemovalResult> Function(
    Future<AccountRemovalResult> Function(),
  )?
  guardOAuthRemoval,
}) async {
  if (provider.isDav) {
    final result = await dav().removeAccount(accountId);
    await resetScheduleVisibility();
    return result.remoteRevocationAttempted && !result.remoteRevocationSucceeded
        ? AccountRemovalOutcome.davRevocationFailed
        : AccountRemovalOutcome.removed;
  }
  Future<AccountRemovalResult> remove() => auth().removeAccount(
    accountId: accountId,
    revokeAuthorization: revokeGoogleAuthorization,
  );
  final result = await (guardOAuthRemoval == null
      ? remove()
      : guardOAuthRemoval(remove));
  await resetScheduleVisibility();
  return result.authorizationRevocationFailed
      ? AccountRemovalOutcome.googleRevocationFailed
      : AccountRemovalOutcome.removed;
}

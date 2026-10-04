import '../../l10n/generated/app_localizations.dart';
import '../core/auth/oauth_models.dart';
import '../core/secrets/secret_store.dart';
import '../features/auth/data/auth_repository.dart';

/// Recovery comes from safe typed classifications, never provider descriptions.
String localizedAuthorizationError(AppLocalizations l10n, Object error) {
  if (error is AccountRemovalPersistenceException) {
    return l10n.oauthRevokedRemovalIncomplete;
  }
  if (error is SecretStoreException) return l10n.oauthSecureStorageUnavailable;
  if (error is OAuthException) {
    return localizedOAuthFailure(
      l10n,
      error.classification,
      authErrorMessage(error),
    );
  }
  return authErrorMessage(error);
}

String localizedOAuthFailure(
  AppLocalizations l10n,
  OAuthFailureKind? kind,
  String fallback,
) => switch (kind) {
  OAuthFailureKind.configuration => l10n.oauthRegistrationRejected,
  OAuthFailureKind.authorizationCode => l10n.oauthAuthorizationCodeUnusable,
  OAuthFailureKind.permission => l10n.oauthPermissionRefused,
  OAuthFailureKind.throttled => l10n.oauthProviderThrottled,
  OAuthFailureKind.temporary => l10n.oauthProviderTemporaryFailure,
  OAuthFailureKind.timeout => l10n.oauthAuthorizationTimedOut,
  OAuthFailureKind.wrongAccount => l10n.oauthWrongAccount,
  OAuthFailureKind.storage => l10n.oauthSecureStorageUnavailable,
  _ => fallback,
};

String localizedAccountRemovalError(AppLocalizations l10n, Object error) =>
    error is AccountRemovalPersistenceException
    ? l10n.oauthRevokedRemovalIncomplete
    : l10n.removeAccountFailed;

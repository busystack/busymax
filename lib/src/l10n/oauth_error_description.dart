import '../features/sync/sync_failure_notification_policy.dart';
import '../core/http/request_dispatch_exception.dart';
import '../features/sync/sync_auth_error.dart';
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
  OAuthFailureKind.registrationUnavailable ||
  OAuthFailureKind.expiredGrant => l10n.accountReconnectRequired,
  OAuthFailureKind.identityUnverified => l10n.googleIdentityUnverified,
  OAuthFailureKind.clientRejected => l10n.oauthRegistrationRejected,
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

String localizedSyncFailureMessage(
  AppLocalizations l10n,
  Object error, {
  String? networkUnavailableMessage,
}) {
  final effective = resolveEffectiveSyncFailure(error);
  if (isOAuthReconnectRequiredError(effective) ||
      effective is AccountNotSyncEligibleException &&
          effective.needsReconnect) {
    return l10n.accountReconnectRequired;
  }
  final disposition = syncFailureNotificationDisposition(effective);
  if (disposition == SyncFailureNotificationDisposition.reconnectRequired) {
    return l10n.accountReconnectRequired;
  }
  if (disposition == SyncFailureNotificationDisposition.permissionChanged &&
      effective is! OAuthException) {
    return l10n.davPermissionChanged;
  }
  if (effective is OAuthException) {
    return localizedOAuthFailure(
      l10n,
      effective.classification,
      l10n.oauthProviderTemporaryFailure,
    );
  }
  return syncFailureMessage(
    error,
    networkUnavailableMessage:
        networkUnavailableMessage ?? l10n.networkOfflineTryAgain,
  );
}

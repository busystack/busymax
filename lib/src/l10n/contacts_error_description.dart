import '../dav/trust/nextcloud_http_client_factory.dart';

import 'package:busystack_contacts/busystack_contacts.dart';

import '../../l10n/generated/app_localizations.dart';
import '../core/auth/oauth_models.dart';
import '../core/secrets/secret_store.dart';
import 'oauth_error_description.dart';

String localizedContactsError(AppLocalizations l10n, Object error) {
  if (error is NextcloudCertificateException) {
    return l10n.certificateFailure(error.failure.name);
  }
  if (error is OAuthException || error is SecretStoreException) {
    return localizedAuthorizationError(l10n, error);
  }
  if (error is ContactsException) {
    if (error.code.contains('NextcloudCertificate')) {
      return l10n.certificateFailure(
        error.code.split('NextcloudCertificate').last,
      );
    }
    return error.code.startsWith('oauth:')
        ? localizedContactsStatus(l10n, error.code)
        : _failure(l10n, error.kind.name);
  }
  return l10n.contactsSyncFailed;
}

String localizedContactsStatus(AppLocalizations l10n, String code) {
  if (code.contains('NextcloudCertificate')) {
    return l10n.certificateFailure(code.split('NextcloudCertificate').last);
  }
  if (code.startsWith('oauth:')) {
    final kind = OAuthFailureKind.values
        .where((kind) => kind.name == code.substring(6))
        .firstOrNull;
    return localizedOAuthFailure(l10n, kind, l10n.contactsSyncFailed);
  }
  if (code.startsWith('contacts:')) return _failure(l10n, code.split(':')[1]);
  if (code == 'reconnect-required' || code == 'linked-parent-removed') {
    return l10n.accountReconnectRequired;
  }
  return l10n.contactsSyncFailed;
}

String _failure(AppLocalizations l10n, String kind) => switch (kind) {
  'authentication' => l10n.accountReconnectRequired,
  'permission' => l10n.oauthPermissionRefused,
  'offline' => l10n.networkOfflineTryAgain,
  'throttled' => l10n.oauthProviderThrottled,
  'validation' => l10n.invalidCollectionValue,
  'unknownOutcome' => l10n.nextcloudRefreshPending,
  _ => l10n.contactsSyncFailed,
};

import '../../l10n/generated/app_localizations.dart';
import '../core/secrets/secret_store.dart';
import '../dav/dav_errors.dart';
import '../dav/nextcloud/nextcloud_collection_service.dart';

String? localizedNextcloudFieldError(
  AppLocalizations l10n,
  NextcloudCollectionValidation? reason,
) => switch (reason) {
  NextcloudCollectionValidation.required => l10n.requiredField,
  NextcloudCollectionValidation.color => l10n.invalidCollectionColor,
  NextcloudCollectionValidation.order => l10n.invalidCollectionOrder,
  NextcloudCollectionValidation.timezone => l10n.invalidCollectionTimezone,
  NextcloudCollectionValidation.value => l10n.invalidCollectionValue,
  null => null,
};

String localizedNextcloudCollectionError(
  AppLocalizations l10n,
  Object? error,
) => switch (error) {
  NextcloudCollectionValidationException() => l10n.invalidCollectionValue,
  SecretStoreException() => l10n.oauthSecureStorageUnavailable,
  DavException(kind: DavErrorKind.authentication) =>
    l10n.accountReconnectRequired,
  DavException(kind: DavErrorKind.authorization) =>
    l10n.nextcloudOperationDenied,
  DavException(
    kind: DavErrorKind.network ||
        DavErrorKind.timeout ||
        DavErrorKind.server ||
        DavErrorKind.tls,
  ) =>
    l10n.nextcloudServerUnavailable,
  DavException(kind: DavErrorKind.unknownOutcome) =>
    l10n.nextcloudRefreshPending,
  DavException() => l10n.nextcloudUnsupported,
  _ => l10n.operationFailed,
};

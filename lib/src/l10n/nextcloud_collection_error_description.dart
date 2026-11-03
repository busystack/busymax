import '../../l10n/generated/app_localizations.dart';
import '../core/secrets/secret_store.dart';
import '../dav/dav_errors.dart';
import '../dav/nextcloud/nextcloud_collection_service.dart';
import '../dav/nextcloud/nextcloud_dav_context.dart';

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
  NextcloudRefreshPending() => l10n.nextcloudRefreshPending,
  DavRefreshPending() => l10n.davRefreshPending,
  DavException(code: 'DavCollectionCreationPending') =>
    l10n.davCollectionCreationPending,
  DavException(code: 'DavCollectionOutcomeUnknown') =>
    l10n.nextcloudOutcomeUnknown,
  DavException(
    code: 'DavDiscoveryRequired' ||
        'DavIncompleteInventory' ||
        'DavTrashNotDiscovered',
  ) =>
    l10n.nextcloudDiscoveryRequired,
  DavException(
    code: 'DavTrashUnsupported' ||
        'DavFederatedSchedulingUnsupported' ||
        'DavUnsupportedServer',
  ) =>
    l10n.nextcloudUnsupported,
  DavException(kind: DavErrorKind.tls, :final code) =>
    code.startsWith('NextcloudCertificate')
        ? l10n.certificateFailure(code.substring('NextcloudCertificate'.length))
        : l10n.reviewServerCertificate,
  DavException(kind: DavErrorKind.authentication) =>
    l10n.accountReconnectRequired,
  DavException(kind: DavErrorKind.authorization) =>
    l10n.nextcloudOperationDenied,
  DavException(
    kind: DavErrorKind.network || DavErrorKind.timeout || DavErrorKind.server,
  ) =>
    l10n.nextcloudServerUnavailable,
  DavException(kind: DavErrorKind.unknownOutcome) =>
    l10n.nextcloudOutcomeUnknown,
  DavException(
    kind: DavErrorKind.conflict ||
        DavErrorKind.preconditionFailed ||
        DavErrorKind.uidConflict,
  ) =>
    l10n.nextcloudConflict,
  DavException(kind: DavErrorKind.notFound) => l10n.nextcloudItemUnavailable,
  DavException() => l10n.operationFailed,
  _ => l10n.operationFailed,
};

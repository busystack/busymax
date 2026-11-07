import '../../l10n/generated/app_localizations.dart';
import '../core/secrets/secret_store.dart';
import '../dav/dav_errors.dart';

/// Provider-neutral feedback for standards-based CalDAV collection operations.
String localizedDavCollectionError(
  AppLocalizations l10n,
  Object? error,
) => switch (error) {
  SecretStoreException() => l10n.oauthSecureStorageUnavailable,
  DavException(code: 'DavCollectionRemovalPartial') =>
    l10n.davCollectionRemovalPartial,
  DavRefreshPending() => l10n.davRefreshPending,
  DavException(code: 'DavCollectionCreationPending') =>
    l10n.davCollectionCreationPending,
  DavException(code: 'DavCollectionOutcomeUnknown') ||
  DavException(
    kind: DavErrorKind.unknownOutcome,
  ) => l10n.nextcloudOutcomeUnknown,
  DavException(statusCode: 507) => l10n.davInsufficientStorage,
  DavException(
    code: 'DavCollectionPropertyUnsupported' || 'DavCollectionPropertyRejected',
  ) =>
    l10n.davCollectionPropertyRejected,
  DavException(code: 'DavCollectionCreationUnsupported') ||
  DavException(statusCode: 405) ||
  DavException(
    kind: DavErrorKind.unsupportedComponent,
  ) => l10n.nextcloudUnsupported,
  DavException(code: 'DavCollectionCreationInvalid') =>
    l10n.invalidCollectionValue,
  DavException(code: 'DavDiscoveryRequired') =>
    l10n.davCollectionDiscoveryRequired,
  DavException(kind: DavErrorKind.tls) => l10n.reviewServerCertificate,
  DavException(kind: DavErrorKind.authentication) =>
    l10n.accountReconnectRequired,
  DavException(kind: DavErrorKind.authorization) =>
    l10n.davCollectionCreationDenied,
  DavException(
    kind: DavErrorKind.network ||
        DavErrorKind.timeout ||
        DavErrorKind.server ||
        DavErrorKind.rateLimited,
  ) =>
    l10n.davTemporarilyUnavailable,
  DavException(
    kind: DavErrorKind.conflict ||
        DavErrorKind.preconditionFailed ||
        DavErrorKind.uidConflict,
  ) =>
    l10n.nextcloudConflict,
  DavException(kind: DavErrorKind.notFound) => l10n.nextcloudItemUnavailable,
  _ => l10n.operationFailed,
};

import 'package:busymax/l10n/generated/app_localizations_en.dart';
import 'package:busymax/src/dav/dav_errors.dart';
import 'package:busymax/src/dav/nextcloud/nextcloud_dav_context.dart';
import 'package:busymax/src/l10n/nextcloud_collection_error_description.dart';
import 'package:busymax/src/l10n/dav_collection_error_description.dart';
import 'package:busymax/src/l10n/oauth_error_description.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final l10n = AppLocalizationsEn();
  String describe(Object error) =>
      localizedNextcloudCollectionError(l10n, error);
  test('CalDAV committed, pending and uncertain outcomes stay distinct from Nextcloud', () {
    expect(
      describe(const NextcloudRefreshPending()),
      l10n.nextcloudRefreshPending,
    );
    for (final describe in [
      (Object e) => localizedNextcloudCollectionError(l10n, e),
      (Object e) => localizedSyncFailureMessage(l10n, e),
    ]) {
      expect(describe(const DavRefreshPending()), l10n.davRefreshPending);
      expect(describe(const DavRefreshPending()), isNot(contains('Nextcloud')));

      final pending = nextcloudOperationError(
        409,
        'DavCollectionCreationPending',
      );
      expect(describe(pending), l10n.davCollectionCreationPending);
      expect(describe(pending), isNot(l10n.davRefreshPending));
      expect(
        describe(nextcloudOperationError(409, 'DavCollectionOutcomeUnknown')),
        l10n.nextcloudOutcomeUnknown,
      );
    }
  });
  test(
    'generic CalDAV collection failures use neutral, status-specific wording',
    () {
      final errors = [
        (
          nextcloudOperationError(507, 'DavCollectionCreationFailed'),
          l10n.davInsufficientStorage,
        ),
        (
          nextcloudOperationError(507, 'DavCollectionPropertyRejected'),
          l10n.davInsufficientStorage,
        ),
        (
          nextcloudOperationError(403, 'DavCollectionPropertyUnsupported'),
          l10n.davCollectionPropertyRejected,
        ),
        (
          nextcloudOperationError(403, 'DavPermissionDenied'),
          l10n.davCollectionCreationDenied,
        ),
        (
          nextcloudOperationError(405, 'DavCollectionCreationUnsupported'),
          l10n.nextcloudUnsupported,
        ),
        (
          nextcloudOperationError(409, 'DavDiscoveryRequired'),
          l10n.davCollectionDiscoveryRequired,
        ),
        (
          nextcloudOperationError(503, 'DavCollectionCreationFailed'),
          l10n.davTemporarilyUnavailable,
        ),
        (
          nextcloudOperationError(409, 'DavCollectionOutcomeUnknown'),
          l10n.nextcloudOutcomeUnknown,
        ),
      ];
      for (final (error, expected) in errors) {
        expect(localizedDavCollectionError(l10n, error), expected);
        expect(
          localizedDavCollectionError(l10n, error),
          isNot(contains('Nextcloud')),
        );
      }
      final unavailable = nextcloudOperationError(
        503,
        'DavCollectionCreationFailed',
      );
      expect(describe(unavailable), l10n.nextcloudServerUnavailable);
      expect(
        describe(nextcloudOperationError(507, 'DavCollectionCreationFailed')),
        l10n.davInsufficientStorage,
      );
    },
  );

  test('discovery, permission, conflict and unsupported remain distinct', () {
    expect(
      describe(nextcloudOperationError(409, 'DavDiscoveryRequired')),
      l10n.nextcloudDiscoveryRequired,
    );
    expect(
      describe(nextcloudOperationError(403, 'DavSharingDenied')),
      l10n.nextcloudOperationDenied,
    );
    expect(
      describe(nextcloudOperationError(409, 'DavTrashRestoreFailed')),
      l10n.nextcloudConflict,
    );
    expect(
      describe(nextcloudOperationError(405, 'DavTrashUnsupported')),
      l10n.nextcloudUnsupported,
    );
    expect(
      describe(nextcloudOperationError(409, 'DavTrashRestoreFailed')),
      isNot(l10n.nextcloudUnsupported),
    );
  });
  test(
    'an uncertain mutation is never described as committed awaiting refresh',
    () {
      final error = nextcloudOperationError(409, 'DavTrashOutcomeUnknown');
      expect(error.kind, DavErrorKind.unknownOutcome);
      expect(describe(error), l10n.nextcloudOutcomeUnknown);
      expect(
        describe(const NextcloudRefreshPending()),
        l10n.nextcloudRefreshPending,
      );
    },
  );
  test(
    'authentication and certificate failures retain their recovery actions',
    () {
      expect(
        describe(nextcloudOperationError(401, 'DavAuthRejected')),
        l10n.accountReconnectRequired,
      );
      expect(
        describe(
          const DavException(
            kind: DavErrorKind.tls,
            code: 'DavTlsFailure',
            safeMessage: 'TLS failure',
          ),
        ),
        l10n.reviewServerCertificate,
      );
      expect(
        describe(
          nextcloudOperationError(502, 'NextcloudFederationResponseInvalid'),
        ),
        isNot(l10n.nextcloudUnsupported),
      );
    },
  );
}

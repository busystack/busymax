import 'dart:async';

import '../../../core/auth/authorization_attempt.dart';
import '../../../core/auth/oauth_models.dart';
import '../../../dav/dav_errors.dart';
import '../data/auth_repository.dart';

bool accountConnectionWasCancelled(Object error) =>
    error is OAuthException &&
        error.classification == OAuthFailureKind.cancelled ||
    error is DavException && error.kind == DavErrorKind.cancelled;

/// Once authorization has committed, reconciliation and sync can report their
/// own failures without sending the user back through authorization.
Future<void> finishAccountConnection({
  required String accountId,
  required AuthorizationCancellation cancellation,
  required AuthSessionController session,
  required Future<void> Function() synchronize,
  required void Function(Object error) onFollowUpFailure,
  bool waitForSync = false,
}) async {
  cancellation.committed();

  Future<void> sync() async {
    try {
      await synchronize();
    } on Object catch (error) {
      onFollowUpFailure(error);
    }
  }

  final syncing = sync();
  try {
    await session.reconcileConnectedAccount(accountId);
  } on Object catch (error) {
    onFollowUpFailure(error);
  }
  if (waitForSync) {
    await syncing;
  } else {
    unawaited(syncing);
  }
}

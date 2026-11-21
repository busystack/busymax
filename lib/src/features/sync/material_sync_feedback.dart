import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_bootstrap.dart';
import '../../l10n/l10n.dart';
import '../settings/presentation/account_settings_feedback.dart';
import 'account_recovery_feedback.dart';
import 'sync_failure_notification_policy.dart';
import 'sync_request.dart';

/// Routes explicit user actions through shared synchronization. A retained
/// failure can be inspected and retried from the same contextual action.
Future<void> refreshFromMaterial(
  BuildContext context,
  WidgetRef ref,
  SyncScope scope, {
  bool inspectFailure = true,
  VoidCallback? openRecovery,
}) async {
  final runner = ref.read(manualSyncRunnerProvider);
  if (inspectFailure) {
    final activity = ref.read(accountSyncActivityProvider);
    if (activity.busy(scope)) return;
    final prior = activity.outcome(scope);
    final error = prior?.error ?? activity.resourceFailure(scope);
    if (prior != null || error != null) {
      if ((error, scope.accountId) case (
        final Object error,
        final String accountId,
      )) {
        if (syncFailureNotificationDisposition(error) ==
            SyncFailureNotificationDisposition.reconnectRequired) {
          await showAccountSyncFailure(
            context,
            ref,
            accountId,
            error,
            openRecovery: openRecovery,
          );
          return;
        }
      }
      final l10n = context.l10n;
      final retry = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(l10n.cachedSyncError),
          content: Text(
            error == null
                ? switch (prior?.disposition) {
                    SyncDisposition.missing => l10n.collectionsUnavailable,
                    SyncDisposition.disabled => l10n.off,
                    _ => l10n.cachedSyncError,
                  }
                : AccountSettingsFeedback.fromError(l10n, error).message,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(l10n.cancel),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(l10n.retry),
            ),
          ],
        ),
      );
      if (retry != true) return;
    }
  }
  final result = await runner(scope);
  if (!context.mounted) return;
  if ((result.error, scope.accountId) case (
    final Object error,
    final String accountId,
  )) {
    if (syncFailureNotificationDisposition(error) ==
        SyncFailureNotificationDisposition.reconnectRequired) {
      await showAccountSyncFailure(
        context,
        ref,
        accountId,
        error,
        openRecovery: openRecovery,
      );
    }
  }
}

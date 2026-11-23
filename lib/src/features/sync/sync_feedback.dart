import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_bootstrap.dart';
import '../../l10n/l10n.dart';
import '../../l10n/sync_outcome_description.dart';
import '../settings/presentation/account_settings_feedback.dart';
import 'account_recovery_feedback.dart';
import 'sync_failure_notification_policy.dart';
import 'sync_request.dart';

/// Routes explicit user actions through shared synchronization. A retained
/// failure can be inspected and retried from the same contextual action.
Future<void> refreshWithFeedback(
  BuildContext context,
  WidgetRef ref,
  SyncScope scope, {
  bool inspectFailure = true,
  VoidCallback? openRecovery,
  required Future<bool?> Function(BuildContext, String, String?) confirmRetry,
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
      final title = syncOutcomeDescription(l10n, prior?.disposition);
      final retry = await confirmRetry(
        context,
        title,
        error == null
            ? null
            : AccountSettingsFeedback.fromError(l10n, error).message,
      );
      if (retry != true || !context.mounted) return;
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

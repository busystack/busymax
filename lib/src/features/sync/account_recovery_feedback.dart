import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/app_bootstrap.dart';
import '../../core/http/request_dispatch_exception.dart';
import '../../l10n/l10n.dart';
import '../../l10n/oauth_error_description.dart';
import '../../providers/busy_provider.dart';
import 'sync_failure_notification_policy.dart';

/// A deliberate recovery action selects the actual account and opens its flow.
Future<void> showAccountSyncFailure(
  BuildContext context,
  WidgetRef ref,
  String accountId,
  Object error, {
  VoidCallback? openRecovery,
}) async {
  final reconnect =
      syncFailureNotificationDisposition(error) ==
      SyncFailureNotificationDisposition.reconnectRequired;
  final account = await ref
      .read(accountsRepositoryProvider)
      .accountById(accountId);
  if (reconnect && account?.needsReconnect != true) {
    await ref
        .read(authRepositoryProvider)
        .markReconnectRequired(
          accountId,
          authorizationGeneration: failureAuthorizationGeneration(
            error,
            accountId,
          ),
        );
  }
  if (!context.mounted) return;
  final l10n = context.l10n;
  final google = account?.provider == BusyProvider.google;
  final router = GoRouter.maybeOf(context);
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        reconnect && google
            ? l10n.googleReconnectRequired
            : localizedSyncFailureMessage(l10n, error),
      ),
      action:
          !reconnect ||
              account == null ||
              (router == null && openRecovery == null)
          ? null
          : SnackBarAction(
              label: google
                  ? l10n.reconnectGoogleAccount
                  : l10n.reconnectAccount,
              onPressed:
                  openRecovery ??
                  () => router!.go(
                    Uri(
                      path: '/settings',
                      queryParameters: {
                        'page': 'accounts',
                        'reconnect': accountId,
                      },
                    ).toString(),
                  ),
            ),
    ),
  );
}

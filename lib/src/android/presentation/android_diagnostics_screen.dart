import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_bootstrap.dart';
import '../../core/logging/redacting_logger.dart';
import '../../db/app_database.dart';
import '../../l10n/l10n.dart';
import '../../providers/busy_provider.dart';
import '../android_background.dart';
import '../android_notifications.dart';

class AndroidDiagnosticsScreen extends ConsumerWidget {
  const AndroidDiagnosticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accounts = ref.watch(accountsStreamProvider).valueOrNull ?? const [];
    final labels = {
      for (final account in accounts) account.id: account.displayLabel,
    };
    final redact = ref
        .watch(appSettingsControllerProvider)
        .redactTaskContentInDiagnostics;
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.diagnostics)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 40),
        children: [
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.notifications_outlined),
                  title: Text(context.l10n.reminders),
                  subtitle: Text(
                    ref
                        .read(androidNotificationServiceProvider)
                        .precisionDiagnostic,
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.sync),
                  title: Text(context.l10n.sync),
                  subtitle: Text(context.l10n.davCachedOfflineNotice),
                  onTap: () => unawaited(enqueueImmediateBusyMaxSync()),
                ),
              ],
            ),
          ),
          for (final account in accounts)
            Card(
              child: ListTile(
                leading: const Icon(Icons.account_circle_outlined),
                title: Text(account.displayLabel),
                subtitle: Text(
                  '${account.provider.displayName} · ${account.authState}'
                  '${account.lastSuccessfulSyncAtUtc == null ? '' : '\n${account.lastSuccessfulSyncAtUtc!.toLocal()}'}',
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
            child: Text(
              context.l10n.blockedPendingOperations,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          StreamBuilder<List<PendingOp>>(
            stream: ref
                .watch(databaseProvider)
                .pendingOpsDao
                .watchAllBlockedOps(),
            builder: (context, snapshot) {
              final operations = snapshot.data ?? const <PendingOp>[];
              if (operations.isEmpty) {
                return ListTile(
                  leading: const Icon(Icons.check_circle_outline),
                  title: Text(context.l10n.noBlockedPendingOperations),
                );
              }
              return Column(
                children: [
                  for (final operation in operations)
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.report_problem_outlined),
                        title: Text(
                          '${operation.entityType}: ${operation.operation}',
                        ),
                        subtitle: Text(
                          [
                            labels[operation.accountId] ?? operation.accountId,
                            if (operation.taskListId != null)
                              context.l10n.pendingOpListId(
                                operation.taskListId!,
                              ),
                            context.l10n.pendingOpAttempts(
                              operation.attemptCount,
                            ),
                            if (operation.lastErrorCode != null)
                              operation.lastErrorCode!,
                            if (operation.lastErrorMessage != null)
                              redact
                                  ? redactForLog(operation.lastErrorMessage)
                                  : operation.lastErrorMessage!,
                          ].join('\n'),
                        ),
                        isThreeLine: true,
                        trailing: PopupMenuButton<String>(
                          onSelected: (action) => unawaited(
                            _resolve(context, ref, operation, action),
                          ),
                          itemBuilder: (context) => [
                            PopupMenuItem(
                              value: 'retry',
                              child: Text(context.l10n.retry),
                            ),
                            PopupMenuItem(
                              value: 'discard',
                              child: Text(context.l10n.discard),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _resolve(
    BuildContext context,
    WidgetRef ref,
    PendingOp operation,
    String action,
  ) async {
    final service = ref.read(
      pendingOpResolutionServiceForAccountProvider(operation.accountId),
    );
    try {
      if (action == 'retry') {
        await service.retryNow(operation.id);
      } else {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(context.l10n.discardPendingOperation),
            content: Text(context.l10n.discardPendingOperationConfirmation),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: Text(context.l10n.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: Text(context.l10n.discard),
              ),
            ],
          ),
        );
        if (confirmed != true) return;
        await service.discard(operation.id);
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              action == 'retry'
                  ? context.l10n.retryCompleted
                  : context.l10n.pendingOperationDiscarded,
            ),
          ),
        );
      }
    } on Object catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(redactForLog(error))));
      }
    }
  }
}

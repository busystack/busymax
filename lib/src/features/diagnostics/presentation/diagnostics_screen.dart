import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yaru/yaru.dart';

import '../../../app/app_bootstrap.dart';
import '../../../app/busymax_dialogs.dart';
import '../../../app/busymax_design.dart';
import '../../../core/logging/redacting_logger.dart';
import '../../../db/app_database.dart';
import '../../../google_tasks/api/google_tasks_api_surface.dart';
import '../../../google_tasks/api/tasks_discovery_revision.dart';
import '../../../l10n/l10n.dart';
import '../../sync/pending_op_resolution_service.dart';

class DiagnosticsPanel extends ConsumerWidget {
  const DiagnosticsPanel({super.key, this.scrollable = true});

  final bool scrollable;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final methods = implementedGoogleTasksMethods.toList()..sort();
    final accountId = ref.watch(activeAccountProvider);
    final database = ref.watch(databaseProvider);
    final resolutionService = ref.watch(pendingOpResolutionServiceProvider);
    final settings = ref.watch(appSettingsControllerProvider);
    final l10n = context.l10n;

    final children = [
      Text(l10n.googleTasksApi, style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 8),
      SelectableText(l10n.discoveryRevision(googleTasksDiscoveryRevision)),
      const SizedBox(height: 20),
      Text(
        l10n.implementedMethods,
        style: Theme.of(context).textTheme.titleMedium,
      ),
      const SizedBox(height: 8),
      YaruTileList(
        children: [
          for (final method in methods)
            YaruListTile(
              leading: const Icon(Icons.api),
              title: Text(method),
              subtitle: Text(
                method.endsWith('.list') || method.endsWith('.get')
                    ? l10n.supportsTasksScopes
                    : l10n.requiresTasksScope,
              ),
            ),
        ],
      ),
      const SizedBox(height: 20),
      Text(
        l10n.blockedPendingOperations,
        style: Theme.of(context).textTheme.titleMedium,
      ),
      const SizedBox(height: 8),
      if (accountId == null)
        Text(l10n.signInToInspectPendingOperations)
      else
        StreamBuilder<List<PendingOp>>(
          stream: database.pendingOpsDao.watchBlockedOps(accountId),
          builder: (context, snapshot) {
            final ops = snapshot.data ?? const <PendingOp>[];
            if (ops.isEmpty) {
              return Text(l10n.noBlockedPendingOperations);
            }
            return YaruTileList(
              children: [
                for (final op in ops)
                  _BlockedPendingOpTile(
                    op: op,
                    resolutionService: resolutionService,
                    redactDetails: settings.redactTaskContentInDiagnostics,
                  ),
              ],
            );
          },
        ),
    ];

    if (!scrollable) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      );
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: kYaruPagePadding),
      children: children,
    );
  }
}

enum _PendingOpAction { retry, discard }

class _BlockedPendingOpTile extends StatelessWidget {
  const _BlockedPendingOpTile({
    required this.op,
    required this.resolutionService,
    required this.redactDetails,
  });

  final PendingOp op;
  final PendingOpResolutionService? resolutionService;
  final bool redactDetails;

  @override
  Widget build(BuildContext context) {
    final error = [
      if (op.lastErrorCode != null) op.lastErrorCode,
      if (op.lastErrorMessage != null)
        redactDetails ? redactForLog(op.lastErrorMessage) : op.lastErrorMessage,
    ].join(' - ');
    final l10n = context.l10n;

    return YaruListTile(
      leading: const Icon(Icons.report_problem_outlined),
      title: Text('${op.entityType}: ${op.operation}'),
      subtitle: Text(
        [
          if (op.taskListId != null) l10n.pendingOpListId(op.taskListId!),
          if (op.taskId != null) l10n.pendingOpTaskId(op.taskId!),
          l10n.pendingOpAttempts(op.attemptCount),
          if (error.isNotEmpty) error,
        ].join('\n'),
      ),
      trailing: BusyMaxMenuButton<_PendingOpAction>(
        tooltip: l10n.operationActions,
        onSelected: (action) {
          unawaited(_handleAction(context, action));
        },
        entries: [
          BusyMaxMenuEntry(
            value: _PendingOpAction.retry,
            label: l10n.retry,
            icon: YaruIcons.refresh,
          ),
          BusyMaxMenuEntry(
            value: _PendingOpAction.discard,
            label: l10n.discard,
            icon: YaruIcons.trash,
            destructive: true,
          ),
        ],
      ),
    );
  }

  Future<void> _handleAction(
    BuildContext context,
    _PendingOpAction action,
  ) async {
    switch (action) {
      case _PendingOpAction.retry:
        await _retryNow(context);
        break;
      case _PendingOpAction.discard:
        await _discard(context);
        break;
    }
  }

  Future<void> _retryNow(BuildContext context) async {
    try {
      final service = resolutionService;
      if (service == null) {
        return;
      }
      await service.retryNow(op.id);
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.retryCompleted)));
    } on Object catch (error) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(redactForLog(error.toString()))));
    }
  }

  Future<void> _discard(BuildContext context) async {
    final confirmed = await showBusyMaxConfirm(
      context,
      title: context.l10n.discardPendingOperation,
      message: context.l10n.discardPendingOperationConfirmation,
      confirmLabel: context.l10n.discard,
    );
    if (!confirmed) {
      return;
    }

    try {
      final service = resolutionService;
      if (service == null) {
        return;
      }
      await service.discard(op.id);
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.pendingOperationDiscarded)),
      );
    } on Object catch (error) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(redactForLog(error.toString()))));
    }
  }
}

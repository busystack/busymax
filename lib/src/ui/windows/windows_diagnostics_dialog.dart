import 'dart:io';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../app/app_bootstrap.dart';
import '../../core/logging/redacting_logger.dart';
import '../../dav/mutation/dav_conflict_repository.dart';
import '../../db/app_database.dart';
import '../../google_tasks/api/google_tasks_api_surface.dart';
import '../../google_tasks/api/tasks_discovery_revision.dart';
import '../../features/sync/pending_op_resolution_service.dart';
import '../common/busymax_glyph.dart';
import 'windows_busymax_glyphs.dart';

Future<void> showWindowsDiagnosticsDialog(BuildContext context, WidgetRef ref) {
  return showDialog<void>(
    context: context,
    builder: (context) => const _WindowsDiagnosticsDialog(),
  );
}

class _WindowsDiagnosticsDialog extends ConsumerWidget {
  const _WindowsDiagnosticsDialog();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final methods = implementedGoogleTasksMethods.toList()..sort();
    final accountId = ref.watch(activeAccountProvider);
    final settings = ref.watch(appSettingsControllerProvider);
    final timeZone = ref.watch(localTimeZoneProvider);
    final timeZoneDiagnostic = ref
        .watch(localTimeZoneSourceProvider)
        .diagnostic;
    final notificationReadiness = ref.watch(
      desktopNotificationReadinessProvider,
    );
    final trayDiagnostic = ref.watch(desktopTrayDiagnosticProvider);
    return ContentDialog(
      title: Text(l10n.diagnostics),
      constraints: const BoxConstraints(maxWidth: 760, maxHeight: 700),
      content: ListView(
        children: [
          SelectableText(Platform.operatingSystemVersion),
          SelectableText(timeZone),
          if (timeZoneDiagnostic != null) SelectableText(timeZoneDiagnostic),
          SelectableText(
            'windows-notifications/${notificationReadiness.state.name}',
          ),
          if (notificationReadiness.diagnosticCode case final code?)
            SelectableText(code),
          if (trayDiagnostic != null)
            SelectableText('windows-tray/$trayDiagnostic'),
          const SizedBox(height: 16),
          Text(
            l10n.googleTasksApi,
            style: FluentTheme.of(context).typography.subtitle,
          ),
          const SizedBox(height: 4),
          SelectableText(l10n.discoveryRevision(googleTasksDiscoveryRevision)),
          const SizedBox(height: 12),
          Expander(
            header: Text(l10n.implementedMethods),
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final method in methods)
                  ListTile(
                    leading: Icon(
                      windowsBusyMaxGlyph(BusyMaxGlyph.diagnostics),
                    ),
                    title: SelectableText(method),
                    subtitle: Text(
                      method.endsWith('.list') || method.endsWith('.get')
                          ? l10n.supportsTasksScopes
                          : l10n.requiresTasksScope,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            l10n.blockedPendingOperations,
            style: FluentTheme.of(context).typography.subtitle,
          ),
          const SizedBox(height: 8),
          WindowsBlockedPendingOperations(
            redactDetails: settings.redactTaskContentInDiagnostics,
          ),
          if (accountId != null) ...[
            const SizedBox(height: 16),
            WindowsDavConflictReview(accountId: accountId),
          ],
        ],
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.close),
        ),
      ],
    );
  }
}

/// Account-wide blocked-operation recovery used by Windows Diagnostics.
///
/// Operations can belong to a connected account other than the one selected
/// in the sidebar, so both listing and resolution are keyed by each row's own
/// account identity.
class WindowsBlockedPendingOperations extends ConsumerWidget {
  const WindowsBlockedPendingOperations({
    required this.redactDetails,
    super.key,
  });

  final bool redactDetails;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final database = ref.watch(databaseProvider);
    final accounts = ref.watch(accountsStreamProvider).valueOrNull ?? const [];
    final accountLabels = {
      for (final account in accounts) account.id: account.selectorLabel,
    };
    return StreamBuilder<List<PendingOp>>(
      stream: database.pendingOpsDao.watchAllBlockedOps(),
      builder: (context, snapshot) {
        final operations = snapshot.data ?? const <PendingOp>[];
        if (operations.isEmpty) {
          return Text(
            accounts.isEmpty
                ? l10n.signInToInspectPendingOperations
                : l10n.noBlockedPendingOperations,
          );
        }
        return Column(
          children: [
            for (final operation in operations)
              _PendingOperationTile(
                operation: operation,
                accountLabel:
                    accountLabels[operation.accountId] ?? operation.accountId,
                resolutionService: ref.watch(
                  pendingOpResolutionServiceForAccountProvider(
                    operation.accountId,
                  ),
                ),
                redactDetails: redactDetails,
              ),
          ],
        );
      },
    );
  }
}

/// Fluent conflict review used by Windows Diagnostics.
///
/// Generic pending-operation recovery intentionally cannot resolve DAV
/// conflicts. Keeping this view on the shared conflict repository ensures the
/// Windows composition exposes the same guarded choices as other platforms.
class WindowsDavConflictReview extends ConsumerWidget {
  const WindowsDavConflictReview({required this.accountId, super.key});

  final String accountId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final conflicts = ref.watch(davConflictsStreamProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.syncConflicts,
          style: FluentTheme.of(context).typography.subtitle,
        ),
        const SizedBox(height: 8),
        conflicts.when(
          loading: () => const Align(
            alignment: Alignment.centerLeft,
            child: ProgressRing(),
          ),
          error: (_, _) => Text(l10n.conflictResolutionFailed),
          data: (allConflicts) {
            final accountConflicts = [
              for (final conflict in allConflicts)
                if (conflict.accountId == accountId) conflict,
            ];
            if (accountConflicts.isEmpty) {
              return Text(l10n.noBlockedPendingOperations);
            }
            return Column(
              children: [
                for (final conflict in accountConflicts)
                  ListTile(
                    key: ValueKey('windows-dav-conflict-${conflict.id}'),
                    leading: Icon(windowsBusyMaxGlyph(BusyMaxGlyph.warning)),
                    title: Text(conflict.itemTitle),
                    subtitle: Text(
                      [
                        '${conflict.collectionName} · '
                            '${conflict.accountLabel}',
                        l10n.localPendingEdit(conflict.localEditSummary),
                      ].join('\n'),
                    ),
                    trailing: Button(
                      key: ValueKey(
                        'windows-review-dav-conflict-${conflict.id}',
                      ),
                      onPressed: () => _review(context, ref, conflict),
                      child: Text(l10n.operationActions),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  Future<void> _review(
    BuildContext context,
    WidgetRef ref,
    DavConflictEntity conflict,
  ) async {
    final l10n = AppLocalizations.of(context);
    final resolution = await showDialog<DavConflictResolution>(
      context: context,
      builder: (dialogContext) => ContentDialog(
        title: Text(l10n.syncConflicts),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(conflict.itemTitle),
            const SizedBox(height: 8),
            Text('${conflict.collectionName} · ${conflict.accountLabel}'),
            const SizedBox(height: 4),
            Text(l10n.localPendingEdit(conflict.localEditSummary)),
          ],
        ),
        actions: [
          Button(
            key: const ValueKey('windows-cancel-dav-conflict'),
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(l10n.cancel),
          ),
          if (conflict.canKeepServer)
            Button(
              key: const ValueKey('windows-keep-server-version'),
              onPressed: () => Navigator.pop(
                dialogContext,
                DavConflictResolution.keepServer,
              ),
              child: Text(l10n.keepServerVersion),
            ),
          if (conflict.canReapplyLocal)
            Button(
              key: const ValueKey('windows-reapply-local-change'),
              onPressed: () => Navigator.pop(
                dialogContext,
                DavConflictResolution.reapplyLocal,
              ),
              child: Text(l10n.reapplyLocalChange),
            ),
          if (conflict.canDuplicate)
            FilledButton(
              key: const ValueKey('windows-duplicate-local-item'),
              onPressed: () => Navigator.pop(
                dialogContext,
                DavConflictResolution.duplicateLocal,
              ),
              child: Text(l10n.duplicateLocalItem),
            ),
        ],
      ),
    );
    if (resolution == null || !context.mounted) return;
    final service = ref.read(davConflictResolutionServiceProvider);
    final sync = ref.read(accountSyncOperationsProvider);
    try {
      await service.resolve(conflict.id, resolution);
      await sync.syncAccount(conflict.accountId, full: false);
    } on Object catch (error) {
      if (!context.mounted) return;
      await _showResolutionFailure(context, error);
    }
  }

  Future<void> _showResolutionFailure(BuildContext context, Object error) {
    final l10n = AppLocalizations.of(context);
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => ContentDialog(
        title: Text(l10n.conflictResolutionFailed),
        content: Text(redactForLog('$error')),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(l10n.close),
          ),
        ],
      ),
    );
  }
}

class _PendingOperationTile extends StatelessWidget {
  const _PendingOperationTile({
    required this.operation,
    required this.accountLabel,
    required this.resolutionService,
    required this.redactDetails,
  });

  final PendingOp operation;
  final String accountLabel;
  final PendingOpResolutionService resolutionService;
  final bool redactDetails;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final error = [
      if (operation.lastErrorCode != null) operation.lastErrorCode,
      if (operation.lastErrorMessage != null)
        redactDetails
            ? redactForLog(operation.lastErrorMessage)
            : operation.lastErrorMessage,
    ].join(' - ');
    return ListTile(
      key: ValueKey('windows-blocked-pending-op-${operation.id}'),
      leading: Icon(windowsBusyMaxGlyph(BusyMaxGlyph.warning)),
      title: Text('${operation.entityType}: ${operation.operation}'),
      subtitle: Text(
        [
          '${l10n.account}: $accountLabel',
          if (operation.taskListId != null)
            l10n.pendingOpListId(operation.taskListId!),
          if (operation.taskId != null) l10n.pendingOpTaskId(operation.taskId!),
          l10n.pendingOpAttempts(operation.attemptCount),
          if (error.isNotEmpty) error,
        ].join('\n'),
      ),
      trailing: Tooltip(
        message: l10n.operationActions,
        child: DropDownButton(
          title: Icon(windowsBusyMaxGlyph(BusyMaxGlyph.more)),
          items: [
            MenuFlyoutItem(
              leading: Icon(windowsBusyMaxGlyph(BusyMaxGlyph.refresh)),
              text: Text(l10n.retry),
              onPressed: () => _retry(context),
            ),
            MenuFlyoutItem(
              leading: Icon(windowsBusyMaxGlyph(BusyMaxGlyph.delete)),
              text: Text(l10n.discard),
              onPressed: () => _discard(context),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _retry(BuildContext context) async {
    try {
      await resolutionService.retryNow(operation.id);
      if (context.mounted) {
        await _showResult(context, AppLocalizations.of(context).retryCompleted);
      }
    } on Object catch (error) {
      if (context.mounted) await _showResult(context, redactForLog('$error'));
    }
  }

  Future<void> _discard(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => ContentDialog(
        title: Text(l10n.discardPendingOperation),
        content: Text(l10n.discardPendingOperationConfirmation),
        actions: [
          Button(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.discard),
          ),
        ],
      ),
    );
    if (!(confirmed ?? false)) return;
    try {
      await resolutionService.discard(operation.id);
      if (context.mounted) {
        await _showResult(
          context,
          AppLocalizations.of(context).pendingOperationDiscarded,
        );
      }
    } on Object catch (error) {
      if (context.mounted) await _showResult(context, redactForLog('$error'));
    }
  }

  Future<void> _showResult(BuildContext context, String message) {
    return showDialog<void>(
      context: context,
      builder: (context) => ContentDialog(
        content: Text(message),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context).close),
          ),
        ],
      ),
    );
  }
}

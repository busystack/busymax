import 'dart:io';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../app/app_bootstrap.dart';
import '../../core/logging/redacting_logger.dart';
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
    final database = ref.watch(databaseProvider);
    final settings = ref.watch(appSettingsControllerProvider);
    final resolutionService = ref.watch(pendingOpResolutionServiceProvider);
    final timeZone = ref.watch(localTimeZoneProvider);
    final timeZoneDiagnostic = ref
        .watch(localTimeZoneSourceProvider)
        .diagnostic;
    return ContentDialog(
      title: Text(l10n.diagnostics),
      constraints: const BoxConstraints(maxWidth: 760, maxHeight: 700),
      content: ListView(
        children: [
          SelectableText(Platform.operatingSystemVersion),
          SelectableText(timeZone),
          if (timeZoneDiagnostic != null) SelectableText(timeZoneDiagnostic),
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
          if (accountId == null)
            Text(l10n.signInToInspectPendingOperations)
          else
            StreamBuilder<List<PendingOp>>(
              stream: database.pendingOpsDao.watchBlockedOps(accountId),
              builder: (context, snapshot) {
                final operations = snapshot.data ?? const <PendingOp>[];
                if (operations.isEmpty) {
                  return Text(l10n.noBlockedPendingOperations);
                }
                return Column(
                  children: [
                    for (final operation in operations)
                      _PendingOperationTile(
                        operation: operation,
                        resolutionService: resolutionService,
                        redactDetails: settings.redactTaskContentInDiagnostics,
                      ),
                  ],
                );
              },
            ),
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

class _PendingOperationTile extends StatelessWidget {
  const _PendingOperationTile({
    required this.operation,
    required this.resolutionService,
    required this.redactDetails,
  });

  final PendingOp operation;
  final PendingOpResolutionService? resolutionService;
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
      leading: Icon(windowsBusyMaxGlyph(BusyMaxGlyph.warning)),
      title: Text('${operation.entityType}: ${operation.operation}'),
      subtitle: Text(
        [
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
      final service = resolutionService;
      if (service == null) return;
      await service.retryNow(operation.id);
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
      final service = resolutionService;
      if (service == null) return;
      await service.discard(operation.id);
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

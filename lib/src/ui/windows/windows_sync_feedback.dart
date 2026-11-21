import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../app/app_bootstrap.dart';
import '../../features/settings/presentation/account_settings_feedback.dart';
import '../../features/sync/sync_request.dart';
import '../../l10n/sync_outcome_description.dart';

Future<void> refreshWindowsScope(
  BuildContext context,
  WidgetRef ref,
  SyncScope scope,
) async {
  final activity = ref.read(accountSyncActivityProvider);
  if (activity.busy(scope)) return;
  final runner = ref.read(manualSyncRunnerProvider);
  final prior = activity.outcome(scope);
  final error = prior?.error ?? activity.resourceFailure(scope);
  if (prior != null || error != null) {
    final l10n = AppLocalizations.of(context);
    final feedback = error == null
        ? null
        : AccountSettingsFeedback.fromError(l10n, error);
    final router = GoRouter.maybeOf(context);
    final reconnect =
        feedback?.recovery == AccountSettingsRecovery.reconnect &&
        scope.accountId != null;
    final settings =
        router != null &&
        (reconnect || feedback?.recovery == AccountSettingsRecovery.revalidate);
    final retry = await showDialog<bool>(
      context: context,
      builder: (context) => ContentDialog(
        title: Text(syncOutcomeDescription(l10n, prior?.disposition)),
        content: feedback == null ? null : Text(feedback.message),
        actions: [
          Button(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.close),
          ),
          if (settings)
            Button(
              onPressed: () {
                Navigator.pop(context);
                router.go(
                  Uri(
                    path: '/settings',
                    queryParameters: {
                      'page': 'accounts',
                      if (reconnect) 'reconnect': scope.accountId!,
                    },
                  ).toString(),
                );
              },
              child: Text(reconnect ? l10n.reconnectAccount : l10n.settings),
            ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.retry),
          ),
        ],
      ),
    );
    if (retry != true) return;
  }
  await runner(scope);
}

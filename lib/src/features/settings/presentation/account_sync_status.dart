import 'package:drift/drift.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/app_bootstrap.dart';
import '../../../l10n/l10n.dart';
import '../../../providers/busy_provider.dart';
import '../../accounts/data/accounts_repository.dart';
import '../../accounts/domain/account_connection_state.dart';
import '../../sync/sync_request.dart';

enum AccountRefreshStatus {
  reconnect,
  permissions,
  unsupported,
  refreshing,
  partial,
  failed,
  deferred,
  loading,
  neverRefreshed,
  refreshed,
}

typedef AccountSyncStatus = ({
  AccountRefreshStatus status,
  DateTime? lastRefreshed,
  bool hasPendingChanges,
  bool hasFailedChanges,
  bool hasInventoryLoadFailure,
});

final _accountPendingChangesProvider = StreamProvider.autoDispose
    .family<({bool queued, bool failed}), String>((ref, accountId) {
      final database = ref.watch(databaseProvider);
      final ops = database.pendingOps;
      // Cloud replayers can leave a failed write in the pending state.
      final failed =
          ops.lastErrorCode.isNotNull() |
          ops.lastError.isNotNull() |
          ops.conflictState.equals('unresolved') |
          ops.state.isIn(const [
            'failed',
            'conflict',
            'auth_blocked',
            'permission_blocked',
          ]);
      return (database.selectOnly(ops)
            ..addColumns([failed])
            ..where(ops.accountId.equals(accountId))
            ..groupBy([failed]))
          .watch()
          .map(
            (rows) => (
              queued: rows.any((row) => row.read(failed) != true),
              failed: rows.any((row) => row.read(failed) == true),
            ),
          )
          .distinct();
    });

/// The account's latest outcome, verified completion, and queued changes
/// answer different questions. A historical success remains visible after a
/// partial refresh and pending writes are read from the durable replay queue.
final accountSyncStatusProvider = Provider.autoDispose
    .family<AccountSyncStatus, AccountEntity>((ref, account) {
      final id = account.id;
      final activity = ref.watch(accountSyncActivityProvider);
      final history = ref.watch(accountDomainSyncTimesProvider(id));
      final lastRefreshed = history.valueOrNull?[accountRefreshHistoryKey];
      final latest = activity.outcome(accountSyncScope(id))?.disposition;
      final pending = ref.watch(_accountPendingChangesProvider(id));
      final hasFailedChanges = pending.valueOrNull?.failed == true;
      final sources = ref.watch(calendarSourcesStreamProvider);
      final taskLists = account.isTaskCapable
          ? ref.watch(scheduleTaskListsForAccountProvider(id))
          : null;
      final discovery = account.provider.isDav
          ? ref.watch(davAccountDiscoveryProvider(id))
          : null;
      final collections = account.provider.isDav
          ? ref.watch(davCollectionsStreamProvider)
          : null;
      final unavailable =
          sources.valueOrNull?.any(
                (source) =>
                    source.accountId == id &&
                    source.accessRole == 'unavailable',
              ) ==
              true ||
          collections?.valueOrNull?.any(
                (collection) =>
                    collection.accountId == id &&
                    collection.syncErrorCode != null,
              ) ==
              true ||
          discovery?.valueOrNull?.lastDiscoveryErrorCode != null;
      final inventoryLoadFailed =
          sources.hasError ||
          taskLists?.hasError == true ||
          discovery?.hasError == true ||
          collections?.hasError == true;
      final failed =
          activity.accountHasFailure(id) ||
          hasFailedChanges ||
          unavailable ||
          pending.hasError ||
          inventoryLoadFailed ||
          history.hasError;
      final status = switch (account.connectionState) {
        AccountConnectionState.reauthenticationRequired =>
          AccountRefreshStatus.reconnect,
        AccountConnectionState.permissionChanged =>
          AccountRefreshStatus.permissions,
        AccountConnectionState.unsupportedServerProfile =>
          AccountRefreshStatus.unsupported,
        _ when activity.accountRunning(id) => AccountRefreshStatus.refreshing,
        _ when latest == SyncDisposition.partial =>
          AccountRefreshStatus.partial,
        _ when failed => AccountRefreshStatus.failed,
        _ when latest == SyncDisposition.deferred =>
          AccountRefreshStatus.deferred,
        AccountConnectionState.temporarilyUnavailable =>
          AccountRefreshStatus.failed,
        _ when history.isLoading && lastRefreshed == null =>
          AccountRefreshStatus.loading,
        _ when lastRefreshed == null => AccountRefreshStatus.neverRefreshed,
        _ => AccountRefreshStatus.refreshed,
      };
      return (
        status: status,
        lastRefreshed: lastRefreshed,
        hasPendingChanges: pending.valueOrNull?.queued == true,
        hasFailedChanges: hasFailedChanges,
        hasInventoryLoadFailure: inventoryLoadFailed,
      );
    });

extension AccountSyncStatusPresentation on AccountSyncStatus {
  bool get needsAttention => switch (status) {
    AccountRefreshStatus.reconnect ||
    AccountRefreshStatus.permissions ||
    AccountRefreshStatus.unsupported ||
    AccountRefreshStatus.partial ||
    AccountRefreshStatus.failed => true,
    _ => false,
  };

  String label(BuildContext context) {
    final l10n = context.l10n;
    final verified = lastRefreshed;
    final failureMessage = hasFailedChanges
        ? l10n.syncFailedLocalChanges
        : hasInventoryLoadFailure
        ? l10n.collectionsLoadFailed
        : l10n.accountSyncProblem;
    return [
      if (status != AccountRefreshStatus.refreshed)
        switch (status) {
          AccountRefreshStatus.reconnect => l10n.accountReconnectRequired,
          AccountRefreshStatus.permissions => l10n.davPermissionChanged,
          AccountRefreshStatus.unsupported => l10n.davUnsupportedServer,
          AccountRefreshStatus.refreshing => l10n.traySyncing,
          AccountRefreshStatus.partial => l10n.syncPartiallyCompleted,
          AccountRefreshStatus.failed => failureMessage,
          AccountRefreshStatus.deferred => l10n.syncDeferred,
          AccountRefreshStatus.loading => l10n.collectionsLoading,
          AccountRefreshStatus.neverRefreshed => l10n.syncNotYetRefreshed,
          AccountRefreshStatus.refreshed => '',
        },
      if (verified != null)
        l10n.syncLastRefreshed(
          DateFormat.yMMMd(Localizations.localeOf(context).toLanguageTag())
              .add_jm()
              .format(verified.toLocal()),
        ),
      if (hasFailedChanges && status != AccountRefreshStatus.failed)
        l10n.syncFailedLocalChanges,
      if (hasInventoryLoadFailure &&
          (status != AccountRefreshStatus.failed || hasFailedChanges))
        l10n.collectionsLoadFailed,
      if (hasPendingChanges) l10n.syncPendingChanges,
    ].join('\n');
  }
}

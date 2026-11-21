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
});

final _accountPendingChangesProvider = StreamProvider.autoDispose
    .family<bool, String>((ref, accountId) {
      final database = ref.watch(databaseProvider);
      return (database.select(database.pendingOps)
            ..where((row) => row.accountId.equals(accountId))
            ..limit(1))
          .watch()
          .map((rows) => rows.isNotEmpty)
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
      final pending =
          ref.watch(_accountPendingChangesProvider(id)).valueOrNull ?? false;
      final sources = ref.watch(calendarSourcesStreamProvider);
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
      final failed =
          activity.accountHasFailure(id) ||
          unavailable ||
          sources.hasError ||
          history.hasError ||
          discovery?.hasError == true ||
          collections?.hasError == true;
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
        hasPendingChanges: pending,
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
    return [
      if (status != AccountRefreshStatus.refreshed)
        switch (status) {
          AccountRefreshStatus.reconnect => l10n.accountReconnectRequired,
          AccountRefreshStatus.permissions => l10n.davPermissionChanged,
          AccountRefreshStatus.unsupported => l10n.davUnsupportedServer,
          AccountRefreshStatus.refreshing => l10n.traySyncing,
          AccountRefreshStatus.partial => l10n.syncPartiallyCompleted,
          AccountRefreshStatus.failed => l10n.accountSyncProblem,
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
      if (hasPendingChanges) l10n.syncPendingChanges,
    ].join('\n');
  }
}

import '../../db/app_database.dart';
import 'account_sync_operations.dart';

final Expando<AccountSyncCoordinator> _coordinators =
    Expando<AccountSyncCoordinator>('pending-operation replay coordinators');

/// Prevents independently-created replayers from dispatching pending writes
/// concurrently for the same database and account.
Future<T> serializePendingOpsReplay<T>({
  required AppDatabase database,
  required String accountId,
  required Future<T> Function() replay,
}) {
  final coordinator = _coordinators[database] ??= AccountSyncCoordinator();
  return coordinator.run(accountId, replay);
}

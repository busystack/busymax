import 'domain_sync_schedule.dart';

enum SyncScopeKind {
  all,
  account,
  calendar,
  tasks,
  calendarSource,
  taskList,
  subscription,
  davCollection,
}

typedef SyncScope = ({
  SyncScopeKind kind,
  String? accountId,
  String? resourceId,
});

SyncScope accountSyncScope(String id) =>
    (kind: SyncScopeKind.account, accountId: id, resourceId: null);
SyncScope calendarSyncScope(String account, String source) => (
  kind: SyncScopeKind.calendarSource,
  accountId: account,
  resourceId: source,
);
SyncScope taskListSyncScope(String account, String list) =>
    (kind: SyncScopeKind.taskList, accountId: account, resourceId: list);
SyncScope davCollectionSyncScope(String account, String collection) => (
  kind: SyncScopeKind.davCollection,
  accountId: account,
  resourceId: collection,
);
const allSyncScope = (
  kind: SyncScopeKind.all,
  accountId: null as String?,
  resourceId: null as String?,
);

enum SyncStrategy { ordinary, fullRecovery }

typedef SyncRequest = ({
  SyncScope scope,
  SyncTrigger origin,
  SyncStrategy strategy,
});

enum SyncDisposition {
  completed,
  partial,
  failed,
  deferred,
  disabled,
  missing,
  cancelled,
}

final class SyncOutcome {
  SyncOutcome(
    this.request,
    this.disposition, {
    Iterable<SyncScope> affected = const [],
    Iterable<SyncOutcome> children = const [],
    this.error,
  }) : affected = Set.unmodifiable(affected),
       children = List.unmodifiable(children);

  final SyncRequest request;
  final SyncDisposition disposition;
  final Set<SyncScope> affected;
  final List<SyncOutcome> children;
  final Object? error;
}

final class ScopedSyncDeferred implements Exception {
  const ScopedSyncDeferred();
}

typedef CollectionActivity = Future<void> Function(
  String id,
  Future<void> Function() work,
);

typedef CollectionWriteActivity = Future<void> Function(
  Set<String> ids,
  Future<void> Function() work,
);

const accountRefreshHistoryKey = 'account_refresh';

SyncDisposition summarizeSyncOutcomes(Iterable<SyncOutcome> outcomes) {
  final states = outcomes.map((outcome) => outcome.disposition).toSet()
    ..remove(SyncDisposition.disabled);
  if (states.isEmpty) return SyncDisposition.disabled;
  if (states.length == 1) return states.single;
  if (states.contains(SyncDisposition.completed) ||
      states.contains(SyncDisposition.partial)) {
    return SyncDisposition.partial;
  }
  return states.contains(SyncDisposition.failed)
      ? SyncDisposition.failed
      : SyncDisposition.deferred;
}

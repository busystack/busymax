import 'dart:async';

import '../../providers/busy_provider.dart';

typedef AccountSyncAction =
    Future<void> Function(String accountId, {required bool full});
typedef AccountProvider = Future<BusyProvider> Function(String accountId);
typedef IncompleteTaskImportLoader = Future<Set<String>> Function();
typedef IncompleteTaskImportWriter =
    Future<void> Function(String accountId, bool incomplete);

abstract interface class AccountSyncOperations {
  Future<void> syncAccount(String accountId, {required bool full});

  Future<void> syncTasks(String accountId, {required bool full});

  Future<void> syncCalendar(String accountId, {required bool full});
}

/// Serializes synchronization for each account while allowing different
/// accounts to synchronize independently.
///
/// The returned future belongs to the submitted operation, so callers retain
/// their own success or failure result even when they were queued behind a
/// different synchronization trigger.
final class AccountSyncCoordinator {
  AccountSyncCoordinator({
    IncompleteTaskImportLoader? restoreIncompleteTaskImports,
    IncompleteTaskImportWriter? persistTaskImportIncomplete,
  }) : _restoreIncompleteTaskImports =
           restoreIncompleteTaskImports ?? _restoreNoIncompleteTaskImports,
       _persistTaskImportIncomplete =
           persistTaskImportIncomplete ?? _doNotPersistTaskImportState {
    _restoration = _restoreTaskImportState();
  }

  final Map<String, Future<void>> _accountTails = {};
  final Map<String, int> _activeCounts = <String, int>{};
  final Map<String, int> _activeTaskImportCounts = <String, int>{};
  final Set<String> _taskImportFailed = <String>{};
  final Set<String> _incompleteTaskImports = <String>{};
  final StreamController<String> _runningChanges =
      StreamController<String>.broadcast(sync: true);
  final IncompleteTaskImportLoader _restoreIncompleteTaskImports;
  final IncompleteTaskImportWriter _persistTaskImportIncomplete;
  late final Future<void> _restoration;

  bool isRunning(String accountId) => (_activeCounts[accountId] ?? 0) > 0;

  Future<bool> blocksDueToday(String accountId) async {
    await _restoration;
    return isRunning(accountId) ||
        (_activeTaskImportCounts[accountId] ?? 0) > 0 ||
        _incompleteTaskImports.contains(accountId);
  }

  Stream<String> get runningChanges => _runningChanges.stream;

  /// Records whether an operation that actually imports tasks completed.
  /// A failed import durably leaves its account blocked until a later task
  /// import succeeds, because rows written before the failure remain in the
  /// local cache.
  Future<T> trackTaskImport<T>(
    String accountId,
    Future<T> Function() import,
  ) async {
    await _restoration;
    if ((_activeTaskImportCounts[accountId] ?? 0) == 0) {
      _incompleteTaskImports.add(accountId);
      await _persistTaskImportIncomplete(accountId, true);
    }
    _activeTaskImportCounts.update(
      accountId,
      (count) => count + 1,
      ifAbsent: () => 1,
    );
    if (!_runningChanges.isClosed) _runningChanges.add(accountId);
    try {
      return await import();
    } on Object {
      _taskImportFailed.add(accountId);
      rethrow;
    } finally {
      final remaining = (_activeTaskImportCounts[accountId] ?? 1) - 1;
      if (remaining == 0) {
        _activeTaskImportCounts.remove(accountId);
        if (!_taskImportFailed.remove(accountId)) {
          await _persistTaskImportIncomplete(accountId, false);
          _incompleteTaskImports.remove(accountId);
        }
      } else {
        _activeTaskImportCounts[accountId] = remaining;
      }
      if (!_runningChanges.isClosed) _runningChanges.add(accountId);
    }
  }

  Future<void> _restoreTaskImportState() async {
    _incompleteTaskImports.addAll(await _restoreIncompleteTaskImports());
  }

  Future<T> run<T>(String accountId, Future<T> Function() operation) async {
    final wasIdle = !isRunning(accountId);
    _activeCounts.update(accountId, (count) => count + 1, ifAbsent: () => 1);
    if (wasIdle && !_runningChanges.isClosed) {
      _runningChanges.add(accountId);
    }
    final previous = _accountTails[accountId];
    final release = Completer<void>();
    final tail = release.future;
    _accountTails[accountId] = tail;

    if (previous != null) {
      await previous;
    }
    try {
      return await operation();
    } finally {
      release.complete();
      if (identical(_accountTails[accountId], tail)) {
        _accountTails.remove(accountId);
      }
      final remaining = (_activeCounts[accountId] ?? 1) - 1;
      if (remaining == 0) {
        _activeCounts.remove(accountId);
        if (!_runningChanges.isClosed) _runningChanges.add(accountId);
      } else {
        _activeCounts[accountId] = remaining;
      }
    }
  }

  Future<void> dispose() => _runningChanges.close();
}

Future<Set<String>> _restoreNoIncompleteTaskImports() async => const {};

Future<void> _doNotPersistTaskImportState(String _, bool _) async {}

/// Routes every synchronization entry point through one account-scoped gate.
final class CoordinatedAccountSyncOperations implements AccountSyncOperations {
  const CoordinatedAccountSyncOperations({
    required AccountSyncOperations inner,
    required AccountSyncCoordinator coordinator,
  }) : _inner = inner,
       _coordinator = coordinator;

  final AccountSyncOperations _inner;
  final AccountSyncCoordinator _coordinator;

  @override
  Future<void> syncAccount(String accountId, {required bool full}) {
    return _coordinator.run(
      accountId,
      () => _inner.syncAccount(accountId, full: full),
    );
  }

  @override
  Future<void> syncCalendar(String accountId, {required bool full}) {
    return _coordinator.run(
      accountId,
      () => _inner.syncCalendar(accountId, full: full),
    );
  }

  @override
  Future<void> syncTasks(String accountId, {required bool full}) {
    return _coordinator.run(
      accountId,
      () => _inner.syncTasks(accountId, full: full),
    );
  }
}

final class ConnectivityAwareAccountSyncOperations
    implements AccountSyncOperations {
  const ConnectivityAwareAccountSyncOperations({
    required AccountSyncOperations inner,
    required Future<void> Function() requireNetwork,
  }) : _inner = inner,
       _requireNetwork = requireNetwork;

  final AccountSyncOperations _inner;
  final Future<void> Function() _requireNetwork;

  @override
  Future<void> syncAccount(String accountId, {required bool full}) async {
    await _requireNetwork();
    await _inner.syncAccount(accountId, full: full);
  }

  @override
  Future<void> syncCalendar(String accountId, {required bool full}) async {
    await _requireNetwork();
    await _inner.syncCalendar(accountId, full: full);
  }

  @override
  Future<void> syncTasks(String accountId, {required bool full}) async {
    await _requireNetwork();
    await _inner.syncTasks(accountId, full: full);
  }
}

final class DelegatingAccountSyncOperations implements AccountSyncOperations {
  const DelegatingAccountSyncOperations({
    required AccountSyncAction syncTasks,
    required AccountSyncAction syncCalendar,
  }) : _syncTasks = syncTasks,
       _syncCalendar = syncCalendar;

  final AccountSyncAction _syncTasks;
  final AccountSyncAction _syncCalendar;

  @override
  Future<void> syncAccount(String accountId, {required bool full}) async {
    await syncTasks(accountId, full: full);
    await syncCalendar(accountId, full: full);
  }

  @override
  Future<void> syncTasks(String accountId, {required bool full}) {
    return _syncTasks(accountId, full: full);
  }

  @override
  Future<void> syncCalendar(String accountId, {required bool full}) {
    return _syncCalendar(accountId, full: full);
  }
}

final class DisabledAccountSyncOperations implements AccountSyncOperations {
  const DisabledAccountSyncOperations();

  @override
  Future<void> syncAccount(String accountId, {required bool full}) async {}

  @override
  Future<void> syncTasks(String accountId, {required bool full}) async {}

  @override
  Future<void> syncCalendar(String accountId, {required bool full}) async {}
}

final class RoutingAccountSyncOperations implements AccountSyncOperations {
  const RoutingAccountSyncOperations({
    required AccountProvider providerForAccount,
    required AccountSyncAction syncDav,
    required AccountSyncAction syncWebCal,
    required AccountSyncAction syncTasksRest,
    required AccountSyncAction syncCalendarRest,
  }) : _providerForAccount = providerForAccount,
       _syncDav = syncDav,
       _syncWebCal = syncWebCal,
       _syncTasksRest = syncTasksRest,
       _syncCalendarRest = syncCalendarRest;

  final AccountProvider _providerForAccount;
  final AccountSyncAction _syncDav;
  final AccountSyncAction _syncWebCal;
  final AccountSyncAction _syncTasksRest;
  final AccountSyncAction _syncCalendarRest;

  @override
  Future<void> syncAccount(String accountId, {required bool full}) async {
    switch (await _providerForAccount(accountId)) {
      case BusyProvider.appleICloud:
      case BusyProvider.nextcloud:
        await _syncDav(accountId, full: full);
      case BusyProvider.webCal:
        await _syncWebCal(accountId, full: full);
      case BusyProvider.google:
      case BusyProvider.microsoft:
        await _syncTasksRest(accountId, full: full);
        await _syncCalendarRest(accountId, full: full);
    }
  }

  @override
  Future<void> syncCalendar(String accountId, {required bool full}) async {
    switch (await _providerForAccount(accountId)) {
      case BusyProvider.appleICloud:
      case BusyProvider.nextcloud:
        await _syncDav(accountId, full: full);
      case BusyProvider.webCal:
        await _syncWebCal(accountId, full: full);
      case BusyProvider.google:
      case BusyProvider.microsoft:
        await _syncCalendarRest(accountId, full: full);
    }
  }

  @override
  Future<void> syncTasks(String accountId, {required bool full}) async {
    switch (await _providerForAccount(accountId)) {
      case BusyProvider.appleICloud:
      case BusyProvider.nextcloud:
        await _syncDav(accountId, full: full);
      case BusyProvider.webCal:
        return;
      case BusyProvider.google:
      case BusyProvider.microsoft:
        await _syncTasksRest(accountId, full: full);
    }
  }
}

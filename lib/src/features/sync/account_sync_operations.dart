typedef AccountSyncAction =
    Future<void> Function(String accountId, {required bool full});
typedef AccountUsesDav = Future<bool> Function(String accountId);

abstract interface class AccountSyncOperations {
  Future<void> syncAccount(String accountId, {required bool full});

  Future<void> syncTasks(String accountId, {required bool full});

  Future<void> syncCalendar(String accountId, {required bool full});
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
    required AccountUsesDav usesDav,
    required AccountSyncAction syncDav,
    required AccountSyncAction syncTasksRest,
    required AccountSyncAction syncCalendarRest,
  }) : _usesDav = usesDav,
       _syncDav = syncDav,
       _syncTasksRest = syncTasksRest,
       _syncCalendarRest = syncCalendarRest;

  final AccountUsesDav _usesDav;
  final AccountSyncAction _syncDav;
  final AccountSyncAction _syncTasksRest;
  final AccountSyncAction _syncCalendarRest;

  @override
  Future<void> syncAccount(String accountId, {required bool full}) async {
    if (await _usesDav(accountId)) {
      await _syncDav(accountId, full: full);
      return;
    }
    await _syncTasksRest(accountId, full: full);
    await _syncCalendarRest(accountId, full: full);
  }

  @override
  Future<void> syncCalendar(String accountId, {required bool full}) async {
    if (await _usesDav(accountId)) {
      await _syncDav(accountId, full: full);
      return;
    }
    await _syncCalendarRest(accountId, full: full);
  }

  @override
  Future<void> syncTasks(String accountId, {required bool full}) async {
    if (await _usesDav(accountId)) {
      await _syncDav(accountId, full: full);
      return;
    }
    await _syncTasksRest(accountId, full: full);
  }
}

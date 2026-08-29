import '../../providers/busy_provider.dart';

typedef AccountSyncAction =
    Future<void> Function(String accountId, {required bool full});
typedef AccountProvider = Future<BusyProvider> Function(String accountId);

abstract interface class AccountSyncOperations {
  Future<void> syncAccount(String accountId, {required bool full});

  Future<void> syncTasks(String accountId, {required bool full});

  Future<void> syncCalendar(String accountId, {required bool full});
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

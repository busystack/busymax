import 'dart:async';

import '../accounts/data/accounts_repository.dart';

class AllAccountsSyncScheduler {
  AllAccountsSyncScheduler({
    required Future<List<AccountEntity>> Function() listSyncEligibleAccounts,
    required Future<void> Function(String accountId) syncAccount,
    required Future<void> Function(Object error) onSyncFailure,
    Future<void> Function(String accountId, Object error)? onAccountSyncFailure,
    Future<bool> Function()? canSync,
    Duration interval = const Duration(minutes: 15),
  }) : _listSyncEligibleAccounts = listSyncEligibleAccounts,
       _syncAccount = syncAccount,
       _onSyncFailure = onSyncFailure,
       _onAccountSyncFailure = onAccountSyncFailure,
       _canSync = canSync ?? _allowSync,
       _interval = interval;

  final Future<List<AccountEntity>> Function() _listSyncEligibleAccounts;
  final Future<void> Function(String accountId) _syncAccount;
  final Future<void> Function(Object error) _onSyncFailure;
  final Future<void> Function(String accountId, Object error)?
  _onAccountSyncFailure;
  final Future<bool> Function() _canSync;
  final Duration _interval;
  final _runningChanges = StreamController<bool>.broadcast(sync: true);
  Timer? _timer;
  bool _running = false;
  Future<void>? _activeRun;
  Completer<void>? _continuation;

  Duration get interval => _interval;
  bool get isRunning => _running;

  Stream<bool> watchRunning() async* {
    yield _running;
    yield* _runningChanges.stream;
  }

  void start() {
    stop();
    if (_interval == Duration.zero) {
      return;
    }
    _timer = Timer.periodic(_interval, (_) {
      unawaited(runNow());
    });
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> dispose() async {
    stop();
    await _runningChanges.close();
  }

  Future<void> runNow() {
    if (_activeRun != null) {
      return (_continuation ??= Completer<void>()).future;
    }
    final completion = Completer<void>();
    _activeRun = completion.future;
    _running = true;
    if (!_runningChanges.isClosed) _runningChanges.add(true);
    unawaited(_drain(completion));
    return completion.future;
  }

  Future<void> _drain(Completer<void> completion) async {
    var pass = completion;
    while (true) {
      try {
        if (await _canSync()) {
          await runAllSyncEligibleAccountSync(
            listSyncEligibleAccounts: _listSyncEligibleAccounts,
            syncAccount: _syncAccount,
            onSyncFailure: _onSyncFailure,
            onAccountSyncFailure: _onAccountSyncFailure,
          );
        }
        pass.complete();
      } on Object catch (error, stack) {
        pass.completeError(error, stack);
      }
      final next = _continuation;
      _continuation = null;
      if (next == null) break;
      pass = next;
      _activeRun = pass.future;
    }
    _activeRun = null;
    _running = false;
    if (!_runningChanges.isClosed) _runningChanges.add(false);
  }
}

Future<bool> _allowSync() async => true;

Future<void> runAllSyncEligibleAccountSync({
  required Future<List<AccountEntity>> Function() listSyncEligibleAccounts,
  required Future<void> Function(String accountId) syncAccount,
  required Future<void> Function(Object error) onSyncFailure,
  Future<void> Function(String accountId, Object error)? onAccountSyncFailure,
  bool rethrowFirstFailure = false,
}) async {
  final accounts = await listSyncEligibleAccounts();
  final failures = await Future.wait(
    accounts.map((account) async {
      try {
        await syncAccount(account.id);
        return null;
      } on Object catch (error, stackTrace) {
        try {
          await onAccountSyncFailure?.call(account.id, error);
        } on Object {
          // Keep the original failure and allow other accounts to synchronize.
        }
        try {
          await onSyncFailure(error);
        } on Object {
          // A notification failure must not discard the synchronization result.
        }
        return (error, stackTrace);
      }
    }),
  );
  if ((rethrowFirstFailure, failures.nonNulls.firstOrNull) case (
    true,
    (final error, final stack),
  )) {
    Error.throwWithStackTrace(error, stack);
  }
}

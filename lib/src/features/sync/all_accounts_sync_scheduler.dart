import 'dart:async';

import '../accounts/data/accounts_repository.dart';

class AllAccountsSyncScheduler {
  AllAccountsSyncScheduler({
    required Future<List<AccountEntity>> Function() listSignedInAccounts,
    required Future<void> Function(String accountId) syncAccount,
    required Future<void> Function(Object error) onSyncFailure,
    Future<void> Function(String accountId, Object error)? onAccountSyncFailure,
    Future<bool> Function()? canSync,
    Duration interval = const Duration(minutes: 15),
  }) : _listSignedInAccounts = listSignedInAccounts,
       _syncAccount = syncAccount,
       _onSyncFailure = onSyncFailure,
       _onAccountSyncFailure = onAccountSyncFailure,
       _canSync = canSync ?? _allowSync,
       _interval = interval;

  final Future<List<AccountEntity>> Function() _listSignedInAccounts;
  final Future<void> Function(String accountId) _syncAccount;
  final Future<void> Function(Object error) _onSyncFailure;
  final Future<void> Function(String accountId, Object error)?
  _onAccountSyncFailure;
  final Future<bool> Function() _canSync;
  final Duration _interval;
  Timer? _timer;
  bool _running = false;
  bool _runAgain = false;

  Duration get interval => _interval;

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
    _runAgain = false;
  }

  Future<void> runNow() async {
    if (_running) {
      _runAgain = true;
      return;
    }
    _running = true;
    try {
      do {
        _runAgain = false;
        if (!await _canSync()) {
          return;
        }
        await runAllSignedInAccountSync(
          listSignedInAccounts: _listSignedInAccounts,
          syncAccount: _syncAccount,
          onSyncFailure: _onSyncFailure,
          onAccountSyncFailure: _onAccountSyncFailure,
        );
      } while (_runAgain);
    } finally {
      _running = false;
    }
  }
}

Future<bool> _allowSync() async => true;

Future<void> runAllSignedInAccountSync({
  required Future<List<AccountEntity>> Function() listSignedInAccounts,
  required Future<void> Function(String accountId) syncAccount,
  required Future<void> Function(Object error) onSyncFailure,
  Future<void> Function(String accountId, Object error)? onAccountSyncFailure,
}) async {
  final accounts = await listSignedInAccounts();
  for (final account in accounts) {
    try {
      await syncAccount(account.id);
    } on Object catch (error) {
      try {
        await onAccountSyncFailure?.call(account.id, error);
      } on Object {
        // Preserve the original failure for centralized notification policy
        // and continue synchronizing the remaining accounts.
      }
      await onSyncFailure(error);
    }
  }
}

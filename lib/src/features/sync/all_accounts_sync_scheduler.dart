import 'dart:async';

import '../accounts/data/accounts_repository.dart';
import 'sync_auth_error.dart';

class AllAccountsSyncScheduler {
  AllAccountsSyncScheduler({
    required Future<List<AccountEntity>> Function() listSignedInAccounts,
    required Future<void> Function(String accountId) syncAccount,
    required Future<void> Function(String message) onSyncFailure,
    Future<void> Function(String accountId, Object error)? onAccountSyncFailure,
    Duration interval = const Duration(minutes: 15),
  }) : _listSignedInAccounts = listSignedInAccounts,
       _syncAccount = syncAccount,
       _onSyncFailure = onSyncFailure,
       _onAccountSyncFailure = onAccountSyncFailure,
       _interval = interval;

  final Future<List<AccountEntity>> Function() _listSignedInAccounts;
  final Future<void> Function(String accountId) _syncAccount;
  final Future<void> Function(String message) _onSyncFailure;
  final Future<void> Function(String accountId, Object error)?
  _onAccountSyncFailure;
  final Duration _interval;
  Timer? _timer;
  bool _running = false;

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
  }

  Future<void> runNow() async {
    if (_running) {
      return;
    }
    _running = true;
    try {
      await runAllSignedInAccountSync(
        listSignedInAccounts: _listSignedInAccounts,
        syncAccount: _syncAccount,
        onSyncFailure: _onSyncFailure,
        onAccountSyncFailure: _onAccountSyncFailure,
      );
    } finally {
      _running = false;
    }
  }
}

Future<void> runAllSignedInAccountSync({
  required Future<List<AccountEntity>> Function() listSignedInAccounts,
  required Future<void> Function(String accountId) syncAccount,
  required Future<void> Function(String message) onSyncFailure,
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
        // Keep the original sync failure path moving so other accounts still
        // sync and the user still sees the actionable notification.
      }
      await onSyncFailure(syncFailureMessage(error));
    }
  }
}

import 'dart:async';

import 'package:busymax/src/core/auth/oauth_models.dart';
import 'package:busymax/src/features/accounts/data/accounts_repository.dart';
import 'package:busymax/src/features/sync/all_accounts_sync_scheduler.dart';
import 'package:busymax/src/features/sync/sync_engine.dart';
import 'package:busymax/src/features/sync/sync_scheduler.dart';
import 'package:busymax/src/providers/busy_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('scheduler preserves the background sync failure', () async {
    final failure = StateError('background failed');
    final failures = <Object>[];
    final scheduler = SyncScheduler(
      syncEngine: _FailingSyncEngine(failure),
      interval: const Duration(milliseconds: 1),
      onSyncFailure: (error) async {
        failures.add(error);
      },
    );

    scheduler.start();
    addTearDown(scheduler.stop);

    await _waitFor(() => failures.isNotEmpty);
    expect(failures.first, same(failure));
  });

  test('periodic all-account scheduler syncs all signed-in accounts', () async {
    final synced = <String>[];
    final scheduler = AllAccountsSyncScheduler(
      listSyncEligibleAccounts: () async => [_account('a'), _account('b')],
      syncAccount: (accountId) async {
        synced.add(accountId);
      },
      onSyncFailure: (_) async {},
      interval: const Duration(milliseconds: 1),
    );

    scheduler.start();
    addTearDown(scheduler.dispose);

    await _waitFor(() => synced.length >= 2);
    expect(synced.take(2), ['a', 'b']);
  });

  test('periodic sync does not call providers while offline', () async {
    final engine = _RecordingSyncEngine();
    final scheduler = SyncScheduler(
      syncEngine: engine,
      canSync: () async => false,
      interval: const Duration(milliseconds: 1),
    );
    scheduler.start();
    addTearDown(scheduler.stop);

    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(engine.incrementalSyncCalls, 0);
  });

  test('all-account sync does not enumerate accounts while offline', () async {
    var listCalls = 0;
    final scheduler = AllAccountsSyncScheduler(
      listSyncEligibleAccounts: () async {
        listCalls += 1;
        return [_account('a')];
      },
      syncAccount: (_) async {},
      onSyncFailure: (_) async {},
      canSync: () async => false,
      interval: Duration.zero,
    );
    addTearDown(scheduler.dispose);

    await scheduler.runNow();

    expect(listCalls, 0);
  });

  test('all-account sync failure does not stop other accounts', () async {
    final synced = <String>[];
    final failure = StateError('a failed');
    final failures = <Object>[];

    await runAllSyncEligibleAccountSync(
      listSyncEligibleAccounts: () async => [_account('a'), _account('b')],
      syncAccount: (accountId) async {
        synced.add(accountId);
        if (accountId == 'a') {
          throw failure;
        }
      },
      onSyncFailure: (error) async {
        failures.add(error);
      },
    );

    expect(synced, ['a', 'b']);
    expect(failures.single, same(failure));
  });

  test('missing OAuth token is preserved for both failure callbacks', () async {
    final synced = <String>[];
    final authFailures = <String>[];
    const failure = OAuthException(
      'OAuthMissingToken',
      'No OAuth token is available for this account.',
    );
    final failures = <Object>[];

    await runAllSyncEligibleAccountSync(
      listSyncEligibleAccounts: () async => [_account('a'), _account('b')],
      syncAccount: (accountId) async {
        synced.add(accountId);
        if (accountId == 'a') {
          throw failure;
        }
      },
      onAccountSyncFailure: (accountId, error) async {
        authFailures.add('$accountId:$error');
      },
      onSyncFailure: (error) async {
        failures.add(error);
      },
    );

    expect(synced, ['a', 'b']);
    expect(authFailures.single, contains('a:OAuthMissingToken'));
    expect(failures.single, same(failure));
  });

  test('all-account scheduler does not run overlapping syncs', () async {
    var active = 0;
    var maxActive = 0;
    var starts = 0;
    final release = Completer<void>();
    final scheduler = AllAccountsSyncScheduler(
      listSyncEligibleAccounts: () async => [_account('a')],
      syncAccount: (_) async {
        starts += 1;
        active += 1;
        maxActive = maxActive < active ? active : maxActive;
        await release.future;
        active -= 1;
      },
      onSyncFailure: (_) async {},
      interval: const Duration(milliseconds: 1),
    );

    scheduler.start();
    addTearDown(scheduler.dispose);

    await _waitFor(() => starts == 1);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(starts, 1);
    expect(maxActive, 1);
    release.complete();
  });

  test('all-account scheduler exposes its read-only running state', () async {
    final release = Completer<void>();
    final states = <bool>[];
    final scheduler = AllAccountsSyncScheduler(
      listSyncEligibleAccounts: () async => [_account('a')],
      syncAccount: (_) => release.future,
      onSyncFailure: (_) async {},
      interval: Duration.zero,
    );
    final subscription = scheduler.watchRunning().listen(states.add);
    addTearDown(() async {
      await subscription.cancel();
      await scheduler.dispose();
    });

    await _waitFor(() => states.isNotEmpty);
    final run = scheduler.runNow();
    await _waitFor(() => scheduler.isRunning && states.contains(true));
    release.complete();
    await run;

    expect(scheduler.isRunning, isFalse);
    expect(states, [false, true, false]);
  });
}

class _FailingSyncEngine implements SyncEngine {
  _FailingSyncEngine(this.failure);

  final Object failure;

  @override
  Future<void> incrementalSync() async {
    throw failure;
  }

  @override
  Future<void> fullSync() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _RecordingSyncEngine implements SyncEngine {
  var incrementalSyncCalls = 0;

  @override
  Future<void> incrementalSync() async {
    incrementalSyncCalls += 1;
  }

  @override
  Future<void> fullSync() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> _waitFor(bool Function() condition) async {
  final deadline = DateTime.now().add(const Duration(seconds: 2));
  while (DateTime.now().isBefore(deadline)) {
    if (condition()) {
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  fail('Timed out waiting for condition.');
}

AccountEntity _account(String id) {
  return AccountEntity(
    id: id,
    provider: BusyProvider.google,
    authority: 'https://accounts.google.com',
    providerAccountId: id,
    authState: 'signed_in',
  );
}

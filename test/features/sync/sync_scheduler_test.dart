import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:busymax/src/features/accounts/data/accounts_repository.dart';
import 'package:busymax/src/features/sync/all_accounts_sync_scheduler.dart';
import 'package:busymax/src/features/sync/sync_engine.dart';
import 'package:busymax/src/features/sync/sync_scheduler.dart';
import 'package:busymax/src/task_providers/task_provider.dart';

void main() {
  test('scheduler reports background sync failure', () async {
    final failures = <String>[];
    final scheduler = SyncScheduler(
      syncEngine: _FailingSyncEngine(),
      interval: const Duration(milliseconds: 1),
      onSyncFailure: (message) async {
        failures.add(message);
      },
    );

    scheduler.start();
    addTearDown(scheduler.stop);

    await _waitFor(() => failures.isNotEmpty);
    expect(failures.first, contains('background failed'));
  });

  test('periodic all-account scheduler syncs all signed-in accounts', () async {
    final synced = <String>[];
    final scheduler = AllAccountsSyncScheduler(
      listSignedInAccounts: () async => [_account('a'), _account('b')],
      syncAccount: (accountId) async {
        synced.add(accountId);
      },
      onSyncFailure: (_) async {},
      interval: const Duration(milliseconds: 1),
    );

    scheduler.start();
    addTearDown(scheduler.stop);

    await _waitFor(() => synced.length >= 2);
    expect(synced.take(2), ['a', 'b']);
  });

  test('all-account sync failure does not stop other accounts', () async {
    final synced = <String>[];
    final failures = <String>[];

    await runAllSignedInAccountSync(
      listSignedInAccounts: () async => [_account('a'), _account('b')],
      syncAccount: (accountId) async {
        synced.add(accountId);
        if (accountId == 'a') {
          throw StateError('a failed');
        }
      },
      onSyncFailure: (message) async {
        failures.add(message);
      },
    );

    expect(synced, ['a', 'b']);
    expect(failures.single, contains('a failed'));
  });

  test('all-account scheduler does not run overlapping syncs', () async {
    var active = 0;
    var maxActive = 0;
    var starts = 0;
    final release = Completer<void>();
    final scheduler = AllAccountsSyncScheduler(
      listSignedInAccounts: () async => [_account('a')],
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
    addTearDown(scheduler.stop);

    await _waitFor(() => starts == 1);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(starts, 1);
    expect(maxActive, 1);
    release.complete();
  });
}

class _FailingSyncEngine implements SyncEngine {
  @override
  Future<void> incrementalSync() async {
    throw StateError('background failed');
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
    provider: TaskProvider.google,
    authState: 'signed_in',
  );
}

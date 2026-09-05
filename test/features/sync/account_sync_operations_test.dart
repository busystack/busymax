import 'dart:async';

import 'package:busymax/src/features/sync/account_sync_operations.dart';
import 'package:busymax/src/providers/busy_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'routes providers explicitly and never creates a WebCal task sync',
    () async {
      var provider = BusyProvider.webCal;
      final calls = <String>[];
      final operations = RoutingAccountSyncOperations(
        providerForAccount: (_) async => provider,
        syncDav: (_, {required full}) async => calls.add('dav:$full'),
        syncWebCal: (_, {required full}) async => calls.add('webcal:$full'),
        syncTasksRest: (_, {required full}) async => calls.add('tasks:$full'),
        syncCalendarRest: (_, {required full}) async =>
            calls.add('calendar:$full'),
      );

      await operations.syncAccount('account', full: false);
      await operations.syncCalendar('account', full: true);
      await operations.syncTasks('account', full: true);
      expect(calls, ['webcal:false', 'webcal:true']);

      calls.clear();
      provider = BusyProvider.nextcloud;
      await operations.syncAccount('account', full: false);
      expect(calls, ['dav:false']);

      calls.clear();
      provider = BusyProvider.google;
      await operations.syncAccount('account', full: true);
      expect(calls, ['tasks:true', 'calendar:true']);
    },
  );

  test('serializes every sync entry point for the same account', () async {
    final inner = _BlockingAccountSyncOperations();
    final operations = CoordinatedAccountSyncOperations(
      inner: inner,
      coordinator: AccountSyncCoordinator(),
    );

    final tasks = operations.syncTasks('account', full: false);
    await _waitFor(() => inner.calls.length == 1);
    final calendar = operations.syncCalendar('account', full: false);
    final account = operations.syncAccount('account', full: true);
    await Future<void>.delayed(Duration.zero);

    expect(inner.calls, ['tasks:account:false']);

    inner.releases[0].complete();
    await _waitFor(() => inner.calls.length == 2);
    expect(inner.calls, ['tasks:account:false', 'calendar:account:false']);

    inner.releases[1].complete();
    await _waitFor(() => inner.calls.length == 3);
    expect(inner.calls, [
      'tasks:account:false',
      'calendar:account:false',
      'account:account:true',
    ]);

    inner.releases[2].complete();
    await Future.wait([tasks, calendar, account]);
    expect(inner.maxActive, 1);
  });

  test('allows different accounts to synchronize concurrently', () async {
    final inner = _BlockingAccountSyncOperations();
    final operations = CoordinatedAccountSyncOperations(
      inner: inner,
      coordinator: AccountSyncCoordinator(),
    );

    final first = operations.syncTasks('first', full: false);
    final second = operations.syncCalendar('second', full: false);
    await _waitFor(() => inner.calls.length == 2);

    expect(inner.calls, ['tasks:first:false', 'calendar:second:false']);
    expect(inner.maxActive, 2);

    for (final release in inner.releases) {
      release.complete();
    }
    await Future.wait([first, second]);
  });

  test('a failed sync does not poison later work for the account', () async {
    final coordinator = AccountSyncCoordinator();
    final releaseFailure = Completer<void>();
    final failure = StateError('sync failed');
    var secondRan = false;

    final first = coordinator.run<void>('account', () async {
      await releaseFailure.future;
      throw failure;
    });
    final firstExpectation = expectLater(first, throwsA(same(failure)));
    final second = coordinator.run<void>('account', () async {
      secondRan = true;
    });

    expect(secondRan, isFalse);
    releaseFailure.complete();
    await firstExpectation;
    await second;

    expect(secondRan, isTrue);
  });
}

final class _BlockingAccountSyncOperations implements AccountSyncOperations {
  final calls = <String>[];
  final releases = <Completer<void>>[];
  var active = 0;
  var maxActive = 0;

  @override
  Future<void> syncAccount(String accountId, {required bool full}) {
    return _record('account:$accountId:$full');
  }

  @override
  Future<void> syncCalendar(String accountId, {required bool full}) {
    return _record('calendar:$accountId:$full');
  }

  @override
  Future<void> syncTasks(String accountId, {required bool full}) {
    return _record('tasks:$accountId:$full');
  }

  Future<void> _record(String call) async {
    final release = Completer<void>();
    calls.add(call);
    releases.add(release);
    active += 1;
    if (active > maxActive) maxActive = active;
    await release.future;
    active -= 1;
  }
}

Future<void> _waitFor(bool Function() condition) async {
  final deadline = DateTime.now().add(const Duration(seconds: 2));
  while (DateTime.now().isBefore(deadline)) {
    if (condition()) return;
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  fail('Timed out waiting for condition.');
}

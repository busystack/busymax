import 'package:busymax/src/features/sync/sync_request.dart';
import 'package:busymax/src/features/sync/domain_sync_schedule.dart';

import 'dart:async';

import 'package:busymax/src/features/sync/account_sync_activity.dart';
import 'package:busymax/src/features/sync/account_sync_operations.dart';
import 'package:busymax/src/providers/busy_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('partial account refresh resolves only the completed domain', () async {
    final activity = AccountSyncActivity();
    addTearDown(activity.dispose);
    SyncRequest request(SyncScopeKind kind) => (
      scope: (kind: kind, accountId: 'account', resourceId: null),
      origin: SyncTrigger.manual,
      strategy: SyncStrategy.ordinary,
    );
    final calendar = request(SyncScopeKind.calendar);
    final tasks = request(SyncScopeKind.tasks);
    final account = request(SyncScopeKind.account);
    final calendarFailure = StateError('Calendar failed');
    final taskFailure = StateError('Tasks failed');
    Future<void> record(SyncOutcome outcome) => activity.request(
      outcome.request,
      (start) => start(() async => outcome),
    );

    await record(
      SyncOutcome(calendar, SyncDisposition.failed, error: calendarFailure),
    );
    await record(
      SyncOutcome(tasks, SyncDisposition.failed, error: taskFailure),
    );
    await record(
      SyncOutcome(
        account,
        SyncDisposition.partial,
        children: [
          SyncOutcome(calendar, SyncDisposition.completed),
          SyncOutcome(tasks, SyncDisposition.deferred),
        ],
      ),
    );
    expect(activity.outcome(calendar.scope), isNull);
    expect(activity.outcome(tasks.scope)?.error, same(taskFailure));
    expect(
      activity.outcome(account.scope)?.disposition,
      SyncDisposition.partial,
    );
    expect(activity.accountHasFailure('account'), isTrue);

    await record(
      SyncOutcome(
        account,
        SyncDisposition.completed,
        children: [
          SyncOutcome(calendar, SyncDisposition.completed),
          SyncOutcome(tasks, SyncDisposition.completed),
        ],
      ),
    );
    expect(activity.outcome(tasks.scope), isNull);
    expect(activity.accountNeedsAttention('account'), isFalse);
  });

  test(
    'joins only matching requests and waits for each account continuation',
    () async {
      final coordinator = AccountSyncCoordinator();
      addTearDown(coordinator.dispose);
      final starts = <SyncRequest>[];
      final releases = <SyncRequest, Completer<void>>{};
      final entered = <SyncRequest, Completer<void>>{};
      final operations = RequestAccountSyncOperations(
        (request) => coordinator.run(request.scope.accountId!, () async {
          starts.add(request);
          entered.putIfAbsent(request, Completer<void>.new).complete();
          await (releases[request] = Completer<void>()).future;
          return SyncOutcome(request, SyncDisposition.completed);
        }),
      );
      SyncRequest target(String id, SyncStrategy strategy) => (
        scope: calendarSyncScope('account', id),
        origin: SyncTrigger.manual,
        strategy: strategy,
      );
      final a = target('a', SyncStrategy.ordinary);
      final b = target('b', SyncStrategy.ordinary);
      final full = target('a', SyncStrategy.fullRecovery);
      final first = operations.execute(a);
      expect(identical(first, operations.execute(a)), isTrue);
      final second = operations.execute(b);
      final recovery = operations.execute(full);
      expect(starts, [a]);
      releases[a]!.complete();
      expect((await first).request, a);
      await entered.putIfAbsent(b, Completer<void>.new).future;
      expect(starts, [a, b]);
      releases[b]!.complete();
      expect((await second).request, b);
      await entered.putIfAbsent(full, Completer<void>.new).future;
      expect(starts, [a, b, full]);
      releases[full]!.complete();
      expect((await recovery).request, full);
      expect(coordinator.isRunning('account'), isFalse);
    },
  );

  test('failed pull with no imported data retains eligible cached reminder delivery', () async {
    final coordinator = AccountSyncCoordinator();
    await expectLater(
      coordinator.trackTaskImport<void>('account', () async {
        throw StateError('quota before any writes');
      }, changedOnFailure: () => false),
      throwsStateError,
    );
    expect(await coordinator.blocksDueToday('account'), false);
    await expectLater(
      coordinator.trackTaskImport<void>('account', () async {
        throw StateError('partial import');
      }),
      throwsStateError,
    );
    await expectLater(
      coordinator.trackTaskImport<void>('account', () async {
        throw StateError('quota');
      }, changedOnFailure: () => false),
      throwsStateError,
    );
    expect(await coordinator.blocksDueToday('account'), true);
    await coordinator.dispose();
  });

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

  test('running lifecycle remains active across queued account work', () async {
    final coordinator = AccountSyncCoordinator();
    addTearDown(coordinator.dispose);
    final changes = <String>[];
    final subscription = coordinator.runningChanges.listen(changes.add);
    addTearDown(subscription.cancel);
    final firstRelease = Completer<void>();
    final secondRelease = Completer<void>();

    final first = coordinator.run<void>('account', () => firstRelease.future);
    final second = coordinator.run<void>('account', () => secondRelease.future);

    expect(coordinator.isRunning('account'), isTrue);
    expect(coordinator.isRunning('other'), isFalse);
    expect(changes, ['account']);

    firstRelease.complete();
    await first;
    expect(coordinator.isRunning('account'), isTrue);
    expect(changes, ['account']);

    secondRelease.complete();
    await second;
    expect(coordinator.isRunning('account'), isFalse);
    expect(changes, ['account', 'account']);
  });

  test(
    'failed task import remains blocked until a task import succeeds',
    () async {
      final incompleteAccounts = <String>{};
      AccountSyncCoordinator createCoordinator() => AccountSyncCoordinator(
        restoreIncompleteTaskImports: () async => Set.of(incompleteAccounts),
        persistTaskImportIncomplete: (accountId, incomplete) async {
          if (incomplete) {
            incompleteAccounts.add(accountId);
          } else {
            incompleteAccounts.remove(accountId);
          }
        },
      );

      var coordinator = createCoordinator();
      final failure = StateError('task page failed');

      await expectLater(
        coordinator.run<void>('account', () async => throw failure),
        throwsA(same(failure)),
      );
      expect(await coordinator.blocksDueToday('account'), isFalse);

      await expectLater(
        coordinator.trackTaskImport<void>('account', () async => throw failure),
        throwsA(same(failure)),
      );

      expect(coordinator.isRunning('account'), isFalse);
      expect(await coordinator.blocksDueToday('account'), isTrue);
      expect(incompleteAccounts, {'account'});

      await coordinator.dispose();
      coordinator = createCoordinator();
      addTearDown(coordinator.dispose);
      expect(await coordinator.blocksDueToday('account'), isTrue);

      await coordinator.run<void>('account', () async {});
      expect(await coordinator.blocksDueToday('account'), isTrue);

      await coordinator.trackTaskImport<void>(
        'account',
        () async {},
        coversAccount: false,
      );
      expect(await coordinator.blocksDueToday('account'), isTrue);
      expect(incompleteAccounts, {'account'});
      await coordinator.trackTaskImport<void>('account', () async {});
      expect(await coordinator.blocksDueToday('account'), isFalse);
      expect(incompleteAccounts, isEmpty);
    },
  );
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

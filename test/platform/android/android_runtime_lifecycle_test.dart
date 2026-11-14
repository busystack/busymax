import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart'
    show
        QueryInterceptor,
        QueryExecutor,
        TransactionExecutor,
        Value,
        ApplyInterceptor;

import 'package:busymax/src/android/android_background.dart';
import 'package:busymax/src/android/android_notifications.dart';
import 'package:busymax/src/android/android_notification_gate.dart';
import 'package:busymax/src/android/android_account_gate.dart';
import 'package:busymax/src/android/android_runtime_resources.dart';
import 'package:busymax/src/app/app_settings.dart';
import 'package:busymax/src/db/app_database.dart';
import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:busymax_android_platform/busymax_android_platform.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;

final _qaNotificationOperation = Object();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('io.busystack.busymax/android');
  final leases = <String, String>{};
  final leaseOperations = <String, Object?>{};
  final changed = <Completer<void>>[];
  var serial = 0, releaseAll = 0, dataChanges = 0;
  var failRelease = false, failDuplicateAcquire = false;
  var rejectNotificationAcquisition = false;
  setUp(() {
    leases.clear();
    leaseOperations.clear();
    serial = 0;
    dataChanges = 0;
    releaseAll = 0;
    failRelease = false;
    failDuplicateAcquire = false;
    rejectNotificationAcquisition = false;
    FlutterSecureStorage.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          final args = call.arguments as Map?;
          switch (call.method) {
            case 'notifyDataChanged':
              dataChanges++;
              return null;
            case 'acquireAccountGate':
              final key = args!['accountId'] as String;
              if (rejectNotificationAcquisition && key == '__notifications__') {
                throw StateError(
                  'Idle disposal must not acquire another lease.',
                );
              }
              final operation = Zone.current[_qaNotificationOperation];
              // A separate coordinator operation must queue, like the native
              // Semaphore.tryAcquire. Reacquiring THIS operation's held lease
              // must still fail immediately: that is the regression under test.
              if (failDuplicateAcquire &&
                  operation != null &&
                  leases.entries.any(
                    (entry) =>
                        entry.value == key &&
                        identical(leaseOperations[entry.key], operation),
                  )) {
                throw StateError('Non-reentrant native acquisition: $key');
              }
              while (leases.containsValue(key)) {
                final wake = Completer<void>();
                changed.add(wake);
                await wake.future;
              }
              final id = 'lease-${++serial}';
              leases[id] = key;
              leaseOperations[id] = operation;
              return id;
            case 'releaseAccountGate':
              leases.remove(args!['leaseId']);
              leaseOperations.remove(args['leaseId']);
              for (final wake in changed.toList()) {
                if (!wake.isCompleted) wake.complete();
              }
              changed.clear();
              if (failRelease) {
                throw PlatformException(code: 'release-ack-failed');
              }
              return null;
            case 'releaseOwnedAccountGates':
              releaseAll++;
              return null;
            case 'currentTimeZoneId':
              return 'Etc/UTC';
            case 'uses24HourFormat':
              return true;
            case 'notificationCapabilities':
              return {
                'notifications': true,
                'reminders': true,
                'summaries': true,
                'status': true,
              };
            default:
              return null;
          }
        });
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  for (final notificationFailure in [false, true]) {
    test(
      'background foreground notification survives reminder failure=$notificationFailure',
      () async {
        final succeeded = await completeAndroidBackgroundRefresh(
          reconcileNotifications: () async {
            if (notificationFailure) {
              throw StateError('Reminder refresh failed');
            }
          },
        );
        expect(dataChanges, 1);
        expect(succeeded, !notificationFailure);
      },
    );
  }

  test(
    'cleanup attempts every resource once and preserves initialization failure',
    () async {
      final scope = AndroidRuntimeResources();
      final order = <int>[];
      scope.own(1, (v) {
        order.add(v);
      });
      scope.own(2, (v) {
        order.add(v);
        throw StateError('cleanup');
      });
      scope.own(3, (v) {
        order.add(v);
      });
      await scope.close(preserveFailure: true);
      await scope.close(preserveFailure: true);
      expect(order, [3, 2, 1]);
      await expectLater(scope.close(), throwsStateError);
    },
  );

  for (final notification in [true, false]) {
    test(
      'lease release cannot mask the original failure: notification=$notification',
      () async {
        leases['foreign'] = 'another-engine';
        final original = StateError('operation');
        failRelease = true;
        final platform = BusyMaxAndroidPlatform.instance;
        final future = notification
            ? AndroidNotificationGate(platform)
                  .run<void>(() async => throw original)
            : AndroidCrossEngineAccountGate(platform)
                  .run<void>('one', () async => throw original);
        await expectLater(future, throwsA(same(original)));
        expect(leases, {'foreign': 'another-engine'});
        expect(releaseAll, 0);
        failRelease = false;
        await AndroidNotificationGate(platform).run(() async {});
        expect(leases, {'foreign': 'another-engine'});
      },
    );
  }

  test(
    'idle notification disposal cannot wait on or release a foreign lease',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      final service = AndroidNotificationService(
        database: db,
        settings: AppSettings.defaults,
        backend: _Backend(),
      );
      leases['foreign'] = '__notifications__';
      rejectNotificationAcquisition = true;
      await service.dispose();
      await service.dispose();
      expect(leases, {'foreign': '__notifications__'});
      expect(serial, 0);
      expect(releaseAll, 0);
      await db.close();
    },
  );

  test(
    'draining this runtime waits for its work but not another queued runtime',
    () async {
      final platform = BusyMaxAndroidPlatform.instance;
      final gate = AndroidNotificationGate(platform);
      final entered = Completer<void>(), release = Completer<void>();
      final foreignEntered = Completer<void>(),
          foreignRelease = Completer<void>();
      final work = gate.run(() async {
        entered.complete();
        await release.future;
      });
      await entered.future;
      final foreign = AndroidNotificationGate(platform).run(() async {
        foreignEntered.complete();
        await foreignRelease.future;
      });
      var drained = false;
      final drain = gate.drain().then((_) {
        drained = true;
      });
      await Future<void>.delayed(Duration.zero);
      expect(drained, isFalse);
      release.complete();
      await foreignEntered.future;
      await drain;
      expect(drained, isTrue);
      expect(leases.values, contains('__notifications__'));
      foreignRelease.complete();
      await Future.wait([work, foreign]);
      expect(leases, isEmpty);
    },
  );

  test(
    'ownership tracking does not consume an unobserved operation failure',
    () async {
      final original = StateError('unobserved operation');
      final gate = AndroidNotificationGate(BusyMaxAndroidPlatform.instance);
      Object? observed;
      runZonedGuarded(
        () {
          unawaited(gate.run<void>(() async => throw original));
        },
        (error, _) {
          observed = error;
        },
      );
      await gate.drain();
      await Future<void>.delayed(Duration.zero);
      expect(observed, same(original));
      expect(leases, isEmpty);
    },
  );

  test(
    'allocation failure closes the database before a client exists',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      await db.customSelect('SELECT 1').get();
      final original = StateError('client allocation');
      await expectLater(
        AndroidHeadlessRuntime.create(
          databaseForTesting: () => db,
          httpClientForTesting: () => throw original,
          settingsForTesting: _Settings(),
        ),
        throwsA(same(original)),
      );
      await expectLater(db.customSelect('SELECT 1').get(), throwsStateError);
      expect(leases, isEmpty);
    },
  );

  test(
    'backend failure drains notifications and closes every allocated resource',
    () async {
      final original = StateError('native initialization');
      final db = AppDatabase(NativeDatabase.memory());
      final client = _Client(throwOnClose: true);
      await expectLater(
        AndroidHeadlessRuntime.create(
          databaseForTesting: () => db,
          httpClientForTesting: () => client,
          notificationBackendForTesting: _Backend(
            initializationFailure: original,
          ),
          settingsForTesting: _Settings(),
        ),
        throwsA(same(original)),
      );
      expect(client.closed, isTrue);
      await expectLater(db.customSelect('SELECT 1').get(), throwsStateError);
      expect(leases, isEmpty);
    },
  );

  test('successful runtime shutdown reports cleanup failure after closing database', () async {
    final db = AppDatabase(NativeDatabase.memory());
    final client = _Client(throwOnClose: true);
    final runtime = await AndroidHeadlessRuntime.create(
      databaseForTesting: () => db,
      httpClientForTesting: () => client,
      notificationBackendForTesting: _Backend(),
      settingsForTesting: _Settings(),
    );
    await expectLater(runtime.dispose(), throwsStateError);
    await expectLater(db.customSelect('SELECT 1').get(), throwsStateError);
    expect(leases, isEmpty);
    expect(releaseAll, 0);
  });

  for (final action in [
    androidNotificationActionSnooze,
    androidNotificationActionDismiss,
  ]) {
    test(
      'reminder action acquires the notification gate before SQL and reuses it: $action',
      () async {
        failDuplicateAcquire = true;
        var checkOrder = false;
        final gate = AndroidNotificationGate(BusyMaxAndroidPlatform.instance);
        final db = AppDatabase(
          NativeDatabase.memory().interceptWith(
            _TransactionOrder(() {
              if (checkOrder) {
                expect(
                  leases.entries.any(
                    (entry) =>
                        entry.value == '__notifications__' &&
                        identical(
                          leaseOperations[entry.key],
                          Zone.current[_qaNotificationOperation],
                        ),
                  ),
                  isTrue,
                  reason: 'This operation must own the notification lease before SQL begins.',
                );
              }
            }),
          ),
          notificationSynchronization: gate.run,
        );
        final backend = _Backend();
        final runtime = await AndroidHeadlessRuntime.create(
          databaseForTesting: () => db,
          notificationBackendForTesting: backend,
          settingsForTesting: _Settings(),
        );
        addTearDown(runtime.dispose);
        final now = DateTime.now().toUtc();
        await db
            .into(db.accounts)
            .insert(
              AccountsCompanion.insert(
                id: 'google:action',
                provider: 'google',
                authority: 'google',
                providerAccountId: 'action',
                credentialKind: 'oauth',
                authState: const Value('signed_in'),
                createdAtUtc: now.toIso8601String(),
                updatedAtUtc: now.toIso8601String(),
              ),
            );
        await db
            .into(db.notificationSchedule)
            .insert(
              NotificationScheduleCompanion.insert(
                id: 'qa-reminder',
                accountId: 'google:action',
                sourceType: 'task',
                sourceId: 'removed-task',
                scheduledAtUtc: now.millisecondsSinceEpoch,
                title: 'QA reminder',
                createdAtLocal: now.millisecondsSinceEpoch,
                updatedAtLocal: now.millisecondsSinceEpoch,
              ),
            );
        final stale = await db.select(db.notificationSchedule).getSingle();
        await runZoned(() async {
          checkOrder = true;
          const activation = AndroidReminderActivation(
            scheduleId: 'qa-reminder',
            generation: 'legacy',
            sourceType: 'task',
            accountId: 'google:action',
            itemId: 'removed-task',
          );
          expect(
            await applyAndroidReminderAction(
              database: db,
              activation: activation,
              actionId: action,
              nowUtc: now,
            ),
            isFalse,
          );
          expect(await db.select(db.notificationSchedule).get(), isEmpty);
          // Recreate the same stale native activation to exercise the actual
          // registered foreground callback, including its nested validation.
          await gate.run(
            () => db
                .into(db.notificationSchedule)
                .insert(stale.toCompanion(true)),
          );
          final callback =
              backend.onResponse!
                  as Future<void> Function(NotificationResponse);
          await callback(
            NotificationResponse(
              notificationResponseType:
                  NotificationResponseType.selectedNotificationAction,
              actionId: action,
              payload: jsonEncode({
                'v': 1,
                'schedule': 'qa-reminder',
                'generation': 'legacy',
                'type': 'task',
                'account': 'google:action',
                'source': 'removed-task',
              }),
            ),
          );
          // Both entry points must reject and remove a stale source schedule.
          expect(await db.select(db.notificationSchedule).get(), isEmpty);
        }, zoneValues: {_qaNotificationOperation: Object()});
        await runtime.dispose();
        expect(leases, isEmpty);
      },
    );
  }

  for (final afterContainer in [false, true]) {
    test(
      'failed initialization closes allocated resources; subsequent startup works: container=$afterContainer',
      () async {
        final original = StateError('initialization');
        var containerClosed = 0;
        final ownedProvider = Provider<int>((ref) {
          ref.onDispose(() => containerClosed++);
          return 1;
        });
        final db = AppDatabase(NativeDatabase.memory());
        final client = _Client(throwOnClose: true);
        final backend = _Backend();
        await expectLater(
          AndroidHeadlessRuntime.create(
            databaseForTesting: () => db,
            httpClientForTesting: () => client,
            notificationBackendForTesting: backend,
            settingsForTesting: _Settings(),
            overridesForTesting: (_) {
              if (!afterContainer) throw original;
              return [];
            },
            afterObservationForTesting: (container) async {
              container.read(ownedProvider);
              expect(backend.observed, isTrue);
              expect(leases.values, contains('__notifications__'));
              throw original;
            },
          ),
          throwsA(same(original)),
        );
        expect(client.closed, isTrue);
        expect(containerClosed, afterContainer ? 1 : 0);
        await expectLater(db.customSelect('SELECT 1').get(), throwsStateError);
        expect(leases, isEmpty);
        expect(releaseAll, 0);
        final next = await AndroidHeadlessRuntime.create(
          databaseForTesting: () => AppDatabase(NativeDatabase.memory()),
          notificationBackendForTesting: _Backend(),
          settingsForTesting: _Settings(),
        );
        await next.dispose();
        await next.dispose();
        expect(leases, isEmpty);
      },
    );
  }
}

class _Client extends http.BaseClient {
  _Client({this.throwOnClose = false});
  final bool throwOnClose;
  bool closed = false;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      throw UnsupportedError('No networking in this lifecycle test.');
  @override
  void close() {
    closed = true;
    if (throwOnClose) throw StateError('close');
  }
}

class _Settings implements LocalSettingsStore {
  @override
  Future<Map<String, Object?>> load() async => {};
  @override
  Future<void> save(Map<String, Object?> json) async {}
}

class _Backend implements AndroidNotificationBackend {
  _Backend({this.initializationFailure});
  final Object? initializationFailure;
  bool observed = false;
  DidReceiveNotificationResponseCallback? onResponse;
  @override
  Future<bool?> initialize({
    required InitializationSettings settings,
    DidReceiveNotificationResponseCallback? onDidReceiveNotificationResponse,
    DidReceiveBackgroundNotificationResponseCallback?
    onDidReceiveBackgroundNotificationResponse,
  }) async {
    onResponse = onDidReceiveNotificationResponse;
    if (initializationFailure case final failure?) throw failure;
    return true;
  }

  @override
  Future<NotificationAppLaunchDetails?>
  getNotificationAppLaunchDetails() async => null;
  @override
  Future<List<PendingNotificationRequest>> pendingNotificationRequests() async {
    observed = true;
    return [];
  }

  @override
  Future<List<ActiveNotification>> getActiveNotifications() async {
    observed = true;
    return [];
  }

  @override
  Future<bool> canScheduleExactly() async => true;
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError(invocation.memberName.toString());
}

class _TransactionOrder extends QueryInterceptor {
  _TransactionOrder(this.check);
  final void Function() check;
  @override
  TransactionExecutor beginTransaction(QueryExecutor parent) {
    check();
    return parent.beginTransaction();
  }
}

import 'dart:async';

import 'package:busymax/src/app/app_settings.dart';
import 'package:busymax/src/db/app_database.dart';
import 'package:busymax/src/features/notifications/desktop_notification_service.dart';
import 'package:busymax/src/features/notifications/due_today_notification_scheduler.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/recording_notification_backend.dart';

void main() {
  late AppDatabase database;
  late AppSettings settings;
  late RecordingNotificationBackend backend;
  late DueTodayNotificationScheduler scheduler;
  late DateTime now;
  late DateTime Function() clock;
  late Duration retryDelay;
  late List<String> markedDates;
  String? accountId;

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    settings = AppSettings.defaults().copyWith(notifyDueToday: true);
    backend = RecordingNotificationBackend();
    now = DateTime(2026, 6, 8, 9);
    clock = () => now;
    retryDelay = const Duration(minutes: 1);
    markedDates = [];
    accountId = 'account';
    await database
        .into(database.accounts)
        .insert(
          AccountsCompanion.insert(
            id: 'account',
            provider: 'google',
            authority: 'https://accounts.google.com',
            providerAccountId: 'account',
            credentialKind: 'oauth',
            authState: const Value('signed_in'),
            createdAtUtc: '',
            updatedAtUtc: '',
          ),
        );
    await database
        .into(database.taskLists)
        .insert(
          TaskListsCompanion.insert(
            accountId: 'account',
            id: 'list',
            title: 'Tasks',
            rawJson: '{}',
            createdLocalAtUtc: '',
            updatedLocalAtUtc: '',
          ),
        );
    scheduler = DueTodayNotificationScheduler(
      database: database,
      settings: () => settings,
      activeAccountId: () => accountId,
      notifications: () => DesktopNotificationService(
        backend: backend,
        settings: settings,
        now: () => clock(),
        reminderFailureRetryDelay: retryDelay,
      ),
      markNotified: (date) async {
        markedDates.add(date);
        settings = settings.copyWith(lastDueTodayNotificationDate: date);
        scheduler.inputsChanged();
      },
      now: () => clock(),
      interval: const Duration(days: 1),
    );
  });

  tearDown(() async {
    scheduler.stop();
    await database.close();
  });

  test(
    'synchronizing tasks into an empty cache triggers the summary',
    () async {
      scheduler.start();
      await scheduler.checkNow();
      expect(backend.requests, isEmpty);
      await _insertTask(database, 'one', '2026-06-08');
      await _waitUntil(() => markedDates.isNotEmpty);
      expect(markedDates, ['2026-06-08']);
      await _insertTask(database, 'two', '2026-06-08');
      await scheduler.checkNow();
      expect(backend.requests, hasLength(1));
    },
  );

  test(
    'local midnight evaluates the new date without settings or task changes',
    () async {
      await _insertTask(database, 'tomorrow', '2026-06-09');
      settings = settings.copyWith(lastDueTodayNotificationDate: '2026-06-08');
      final started = DateTime.now();
      final base = DateTime(2026, 6, 8, 23, 59, 59, 200);
      clock = () => base.add(DateTime.now().difference(started));
      scheduler.start();
      await _waitUntil(() => markedDates.isNotEmpty);
      expect(markedDates, ['2026-06-09']);
      expect(backend.requests, hasLength(1));
    },
  );

  test(
    'quiet hours preserve eligibility and automatically deliver at their end',
    () async {
      await _insertTask(database, 'one', '2026-06-08');
      settings = settings.copyWith(
        quietHoursEnabled: true,
        quietHoursStart: '08:00',
        quietHoursEnd: '10:00',
      );
      final started = DateTime.now();
      final base = DateTime(2026, 6, 8, 9, 59, 59, 200);
      clock = () => base.add(DateTime.now().difference(started));
      await scheduler.checkNow();
      expect(backend.requests, isEmpty);
      expect(markedDates, isEmpty);
      expect(settings.lastDueTodayNotificationDate, null);
      scheduler.start();
      await _waitUntil(() => markedDates.isNotEmpty);
      expect(markedDates, ['2026-06-08']);
      expect(backend.requests, hasLength(1));
    },
  );

  test(
    'backend failure remains unrecorded and retries automatically',
    () async {
      await _insertTask(database, 'one', '2026-06-08');
      backend.error = StateError('unavailable');
      retryDelay = const Duration(milliseconds: 100);
      final started = DateTime.now();
      final base = now;
      clock = () => base.add(DateTime.now().difference(started));
      await scheduler.checkNow();
      expect(backend.attempts, 1);
      expect(markedDates, isEmpty);
      backend.error = null;
      scheduler.start();
      await _waitUntil(() => markedDates.isNotEmpty);
      expect(backend.attempts, 2);
      expect(markedDates, ['2026-06-08']);
    },
  );

  test(
    'concurrent task and settings triggers produce only one successful summary',
    () async {
      await _insertTask(database, 'one', '2026-06-08');
      backend.barrier = Completer<void>();
      final checking = scheduler.checkNow();
      await _waitUntil(() => backend.requests.isNotEmpty);
      scheduler.inputsChanged();
      await _insertTask(database, 'two', '2026-06-08');
      await scheduler.checkNow();
      backend.barrier!.complete();
      await checking;
      expect(backend.requests, hasLength(1));
      expect(markedDates, ['2026-06-08']);
    },
  );

  test('enabling due today evaluates existing tasks immediately', () async {
    await _insertTask(database, 'one', '2026-06-08');
    settings = settings.copyWith(notifyDueToday: false);
    await scheduler.checkNow();
    expect(backend.requests, isEmpty);
    settings = settings.copyWith(notifyDueToday: true);
    scheduler.inputsChanged();
    await _waitUntil(() => markedDates.isNotEmpty);
    expect(backend.requests, hasLength(1));
  });

  test('selecting an account evaluates existing tasks immediately', () async {
    await _insertTask(database, 'one', '2026-06-08');
    accountId = null;
    await scheduler.checkNow();
    expect(backend.requests, isEmpty);
    accountId = 'account';
    scheduler.inputsChanged();
    await _waitUntil(() => markedDates.isNotEmpty);
    expect(backend.requests, hasLength(1));
  });

  test(
    'stopping during delivery prevents later settings writes or timers',
    () async {
      await _insertTask(database, 'one', '2026-06-08');
      backend.barrier = Completer<void>();
      final checking = scheduler.checkNow();
      await _waitUntil(() => backend.requests.isNotEmpty);
      scheduler.stop();
      backend.barrier!.complete();
      await checking;
      scheduler.start();
      scheduler.inputsChanged();
      await scheduler.checkNow();
      expect(markedDates, isEmpty);
      expect(backend.requests, hasLength(1));
    },
  );
}

Future<void> _insertTask(AppDatabase database, String id, String date) async {
  await database
      .into(database.tasks)
      .insert(
        TasksCompanion.insert(
          accountId: 'account',
          taskListId: 'list',
          id: id,
          title: 'Task',
          status: const Value('needsAction'),
          dueUtc: Value(date),
          rawJson: '{}',
          createdLocalAtUtc: '',
          updatedLocalAtUtc: '',
        ),
      );
}

Future<void> _waitUntil(bool Function() condition) async {
  final deadline = DateTime.now().add(const Duration(seconds: 3));
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) fail('Timed out waiting for summary');
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

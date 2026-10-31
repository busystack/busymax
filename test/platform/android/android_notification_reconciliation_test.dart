import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:busymax/src/features/notifications/reminder_presentation.dart';
import 'package:busymax/src/features/notifications/notification_schedule_service.dart';
import 'package:busymax/src/features/calendar/data/calendar_repository.dart';
import 'package:busymax/src/features/task_lists/data/task_lists_repository.dart';
import 'package:busymax/src/android/android_notifications.dart';
import 'package:busymax/src/app/app_settings.dart';
import 'package:busymax/src/core/auth/oauth_models.dart';
import 'package:busymax/src/android/android_settings_store.dart';
import 'package:busymax/src/features/notifications/operational_notification_coordinator.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:busymax/src/core/time/stored_temporal_projection.dart';
import 'package:busymax/src/dav/storage/dav_object_repository.dart';
import 'package:busymax/src/db/app_database.dart';
import 'package:busymax/src/providers/busy_provider.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../support/persistence_test_directory.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const platformChannel = MethodChannel('io.busystack.busymax/android');
  late AppDatabase database;
  late _StatefulNotificationPlugin plugin;
  late AppSettings settings;
  late Map<String, bool> capabilities;
  late _NativeGates gates;
  final directories = <Directory>[];

  setUp(() async {
    capabilities = {
      'notifications': true,
      'reminders': true,
      'summaries': true,
      'status': true,
    };
    database = AppDatabase(NativeDatabase.memory());
    plugin = _StatefulNotificationPlugin();
    settings = AppSettings.defaults().copyWith(notifyDueToday: false);
    gates = _NativeGates();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(platformChannel, (call) async {
          if (call.method == 'acquireAccountGate') {
            return gates.acquire(
              (call.arguments as Map)['accountId'] as String,
            );
          }
          if (call.method == 'releaseAccountGate') {
            gates.release((call.arguments as Map)['leaseId'] as String);
            return null;
          }
          if (call.method == 'notificationCapabilities') return capabilities;
          return null;
        });
    await database
        .into(database.accounts)
        .insert(
          AccountsCompanion.insert(
            id: 'google:test',
            provider: BusyProvider.google.storageValue,
            authority: 'google',
            providerAccountId: 'test',
            credentialKind: 'oauth',
            authState: const Value('signed_in'),
            createdAtUtc: DateTime.now().toUtc().toIso8601String(),
            updatedAtUtc: DateTime.now().toUtc().toIso8601String(),
          ),
        );
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(platformChannel, null);
    await database.close();
    for (final directory in directories) {
      await directory.delete(recursive: true);
    }
    directories.clear();
  });

  AndroidNotificationService service({
    bool exact = false,
    DateTime Function()? clock,
  }) => AndroidNotificationService(
    database: database,
    settings: () => settings,
    backend: plugin,
    exactAlarmCapability: () async => exact,
    now: clock,
  );

  Future<AppDatabase> shareDatabase(
    Directory directory, {
    QueryInterceptor? interceptor,
  }) async {
    final account = await database.select(database.accounts).getSingle();
    await database.close();
    final file = File('${directory.path}/busymax.sqlite');
    database = AppDatabase(NativeDatabase(file));
    await database.into(database.accounts).insert(account.toCompanion(true));
    final native = NativeDatabase(file);
    final peer = AppDatabase(
      interceptor == null ? native : native.interceptWith(interceptor),
    );
    await peer.select(peer.accounts).get();
    addTearDown(peer.close);
    return peer;
  }

  for (final change in [
    'private',
    'events-disabled',
    'tasks-disabled',
    'locale',
    'quiet-hours',
  ]) {
    for (final duringRegistration in [false, true]) {
      test(
        'independent old runtime cannot restore $change (native call in flight: $duringRegistration)',
        () async {
          final directory = await createPersistenceTestDirectory(
            'busymax-policy-',
          );
          directories.add(directory);
          final peer = await shareDatabase(directory);
          final disk = _DiskSettingsStore(
            File('${directory.path}/settings.json'),
          );
          final store = AndroidSettingsStore(store: disk);
          await store.save(settings.toJson());
          ProviderContainer runtime() => ProviderContainer(
            overrides: [
              localSettingsStoreProvider.overrideWithValue(store),
              initialAppSettingsProvider.overrideWithValue(
                AppSettings.fromJson(jsonDecode(disk.file.readAsStringSync())),
              ),
            ],
          );
          final old = runtime();
          final foreground = runtime();
          addTearDown(old.dispose);
          addTearDown(foreground.dispose);
          final now = DateTime.utc(2026, 6, 8, 8, 56);
          if (change == 'tasks-disabled') {
            await database
                .update(database.accounts)
                .write(const AccountsCompanion(provider: Value('microsoft')));
            await _insertDueTodayTask(database, localDay: now.toLocal());
            await database
                .update(database.tasks)
                .write(
                  TasksCompanion(
                    microsoftIsReminderOn: const Value(true),
                    microsoftReminderDateTime: Value(
                      now.add(const Duration(minutes: 20)).toIso8601String(),
                    ),
                    microsoftReminderTimeZone: const Value('UTC'),
                  ),
                );
            await NotificationScheduleService(
              database: database,
              nowUtc: () => now,
            ).rebuildUpcomingNotifications('google:test');
          } else {
            await _insertReminder(
              database,
              scheduledAt: now.add(const Duration(minutes: 20)),
              generation: 'policy',
            );
          }
          AndroidNotificationService notifications(ProviderContainer context) =>
              AndroidNotificationService(
                database: identical(context, old) ? peer : database,
                settings: () => context.read(appSettingsControllerProvider),
                policyStore: store,
                backend: plugin,
                now: () => now,
              );
          final older = notifications(old);
          final newer = notifications(foreground);
          await older.initialize(timeZoneId: 'Etc/UTC');
          await newer.initialize(timeZoneId: 'Etc/UTC');
          Future<void>? pending;
          if (duringRegistration) {
            plugin.registrationBarrier = Completer<void>();
            pending = older.reconcile();
            await plugin.registrationStarted.future;
          }
          final controller = foreground.read(
            appSettingsControllerProvider.notifier,
          );
          switch (change) {
            case 'private':
              await controller.setNotificationDetailLevel(
                NotificationDetailLevel.private,
              );
            case 'events-disabled':
              await controller.setNotifyEventReminders(false);
            case 'tasks-disabled':
              await controller.setNotifyTaskReminders(false);
            case 'locale':
              await controller.setLocaleTag('de');
            case 'quiet-hours':
              await controller.setQuietHoursStart('08:00');
              await controller.setQuietHoursEnd('10:00');
              await controller.setQuietHoursEnabled(true);
          }
          if (duringRegistration) {
            if (change == 'private') plugin.cancellationFailuresRemaining = 1;
            plugin.registrationBarrier!.complete();
            if (change == 'private') {
              await expectLater(pending!, throwsStateError);
            } else {
              await pending;
            }
          }
          await newer.reconcile();
          // A stale engine saving an unrelated preference must rebase its write
          // too, instead of putting Normal/enabled policy back on disk.
          await old
              .read(appSettingsControllerProvider.notifier)
              .setThemeModePreference(BusyMaxThemeModePreference.dark);
          await older.reconcile();
          final requests = plugin.scheduled
              .where((row) => plugin.pendingIds.contains(row.id))
              .toList();
          if (change.endsWith('disabled')) {
            expect(plugin.pendingIds, isEmpty);
          } else {
            expect(requests, isNotEmpty);
            final last = requests.last;
            if (change == 'private') {
              expect(last.title, isNot('Visible meeting'));
              expect(last.body, isNull);
            } else if (change == 'locale') {
              expect(
                last.details.android!.actions!.first.title,
                AndroidNotificationStrings.forSettings(
                  foreground.read(appSettingsControllerProvider),
                ).open,
              );
            } else {
              expect(last.date.hour, 10);
            }
          }
        },
      );
    }
  }

  test('two operational coordinators submit one revision and recovery removes every native ID', () async {
    final directory = await createPersistenceTestDirectory(
      'busymax-operational-',
    );
    directories.add(directory);
    final peer = await shareDatabase(directory);
    await database
        .into(database.notificationIssues)
        .insert(
          NotificationIssuesCompanion.insert(
            id: 'sync-failure|google:test',
            accountId: const Value('google:test'),
            kind: 'sync-failure',
            revision: 'reconnectRequired:0',
          ),
        );
    final first = service();
    final second = AndroidNotificationService(
      database: peer,
      settings: () => settings,
      backend: plugin,
    );
    await first.initialize(timeZoneId: 'Etc/UTC');
    await second.initialize(timeZoneId: 'Etc/UTC');
    OperationalNotificationCoordinator coordinator(
      AndroidNotificationService notifications,
    ) {
      final value = OperationalNotificationCoordinator(
        database: identical(notifications, first) ? database : peer,
        settings: () => settings,
        transport: () => OperationalNotificationTransport(
          deliver: notifications.deliverOperationalIssue,
          cancel: notifications.cancelOperationalIssue,
          synchronize: notifications.synchronize,
          readSettings: notifications.currentSettings,
        ),
      );
      addTearDown(value.stop);
      return value;
    }

    final a = coordinator(first);
    final b = coordinator(second);
    plugin.showBarrier = Completer<void>();
    final one = a.reconcile();
    await plugin.showStarted.future;
    final queued = Completer<void>();
    gates.onQueued = () {
      if (!queued.isCompleted) queued.complete();
    };
    final two = b.reconcile();
    await queued.future;
    plugin.showBarrier!.complete();
    await Future.wait([one, two]);
    expect(plugin.shown, hasLength(1));
    expect(plugin.activeIds, hasLength(1));
    await a.clearAccountSyncFailure('google:test');
    expect(plugin.activeIds, isEmpty);
  });

  test(
    'same-issue ID allocation is shared even when a second lookup was paused',
    () async {
      final directory = await createPersistenceTestDirectory(
        'busymax-allocation-',
      );
      directories.add(directory);
      final lookup = _PauseIssueLookup();
      final peer = await shareDatabase(directory, interceptor: lookup);
      await database
          .into(database.notificationIssues)
          .insert(
            NotificationIssuesCompanion.insert(
              id: 'sync-failure|google:test',
              accountId: const Value('google:test'),
              kind: 'sync-failure',
              revision: 'reconnectRequired:0',
            ),
          );
      final a = service();
      final b = AndroidNotificationService(
        database: peer,
        settings: () => settings,
        backend: plugin,
      );
      await a.initialize(timeZoneId: 'Etc/UTC');
      await b.initialize(timeZoneId: 'Etc/UTC');
      OperationalNotificationCoordinator coordinator(
        AppDatabase db,
        AndroidNotificationService notifications,
      ) {
        final value = OperationalNotificationCoordinator(
          database: db,
          settings: () => settings,
          transport: () => OperationalNotificationTransport(
            deliver: notifications.deliverOperationalIssue,
            cancel: notifications.cancelOperationalIssue,
            synchronize: notifications.synchronize,
            readSettings: notifications.currentSettings,
          ),
        );
        addTearDown(value.stop);
        return value;
      }

      final first = coordinator(database, a);
      final second = coordinator(peer, b);
      lookup.armed = true;
      final pendingB = second.reconcile();
      await lookup.entered.future;
      final queued = Completer<void>();
      gates.onQueued = () {
        if (!queued.isCompleted) queued.complete();
      };
      final pendingA = first.reconcile();
      // On the old implementation A can finish while B holds a stale null-ID
      // snapshot. With serialization, A waits before it reads eligibility.
      await Future.any([pendingA, queued.future]);
      lookup.release.complete();
      await Future.wait([pendingA, pendingB]);
      expect(plugin.shown, hasLength(1));
      final issue = await database
          .select(database.notificationIssues)
          .getSingle();
      expect(plugin.activeIds, {issue.nativeId});
      await first.clearAccountSyncFailure('google:test');
      expect(plugin.activeIds, isEmpty);
    },
  );

  test('reminder IDs share the operational namespace', () async {
    final now = DateTime.utc(2026, 6, 8, 8, 56);
    await _insertReminder(
      database,
      scheduledAt: now.add(const Duration(minutes: 5)),
      generation: 'collision',
    );
    final collision = allocateAndroidNotificationId('event|event-1|5', {});
    await database
        .into(database.notificationIssues)
        .insert(
          NotificationIssuesCompanion.insert(
            id: 'sync-failure|google:test',
            accountId: const Value('google:test'),
            kind: 'sync-failure',
            revision: 'reconnectRequired:0',
            nativeId: Value(collision),
          ),
        );
    final runtime = service(clock: () => now);
    await runtime.initialize(timeZoneId: 'Etc/UTC');
    await runtime.reconcile();
    expect(plugin.scheduled.single.id, isNot(collision));
  });

  for (final task in [false, true]) {
    test(
      'source toggle observes an Android post before sent history was recorded (task: $task)',
      () async {
        final now = DateTime.now().toUtc();
        if (task) {
          await database
              .update(database.accounts)
              .write(const AccountsCompanion(provider: Value('microsoft')));
          await _insertDueTodayTask(database, localDay: now.toLocal());
          await database
              .update(database.tasks)
              .write(
                TasksCompanion(
                  microsoftIsReminderOn: const Value(true),
                  microsoftReminderDateTime: Value(
                    now.subtract(const Duration(minutes: 1)).toIso8601String(),
                  ),
                  microsoftReminderTimeZone: const Value('UTC'),
                ),
              );
          await NotificationScheduleService(
            database: database,
            nowUtc: () => now,
          ).rebuildUpcomingNotifications('google:test');
        } else {
          await _insertReminder(
            database,
            scheduledAt: now.subtract(const Duration(minutes: 1)),
            generation: 'unobserved',
          );
        }
        final runtime = service(clock: () => now);
        await runtime.initialize(timeZoneId: 'Etc/UTC');
        await runtime.reconcile();
        final original = await database
            .select(database.notificationSchedule)
            .getSingle();
        final nativeId = plugin.scheduled.single.id;
        plugin.pendingIds.remove(nativeId);
        plugin.activeIds.add(nativeId);
        expect(original.sentAtUtc, isNull);
        Future<void> toggle(bool enabled) => task
            ? TaskListsRepository(
                database: database,
                accountId: 'google:test',
                nowUtc: () => now,
              ).setRemindersEnabled('list-1', enabled)
            : CalendarRepository(
                database: database,
                now: () => now,
              ).setSourceRemindersEnabled('calendar', enabled);
        await toggle(false);
        if (task) {
          plugin.cancellationFailuresRemaining = 1;
          await expectLater(runtime.reconcile(), throwsStateError);
          expect(
            (await database
                    .select(database.androidNotificationMappings)
                    .getSingle())
                .state,
            startsWith('withdrawing:'),
          );
        } else {
          await runtime.reconcile();
        }
        final consumed = await database
            .select(database.notificationSchedule)
            .getSingle();
        expect(consumed.sentAtUtc, isNotNull);
        await toggle(true);
        await runtime.reconcile();
        expect(plugin.activeIds, isEmpty);
        expect(plugin.scheduled, hasLength(1));
        expect(
          (await database.select(database.notificationSchedule).getSingle())
              .generation,
          original.generation,
        );
      },
    );
  }

  test(
    'concurrent issue reports share one durable revision and native identity',
    () async {
      final directory = await createPersistenceTestDirectory(
        'busymax-reports-',
      );
      directories.add(directory);
      final peer = await shareDatabase(directory);
      final a = service();
      final b = AndroidNotificationService(
        database: peer,
        settings: () => settings,
        backend: plugin,
      );
      await a.initialize(timeZoneId: 'Etc/UTC');
      await b.initialize(timeZoneId: 'Etc/UTC');
      OperationalNotificationCoordinator coordinator(
        AppDatabase db,
        AndroidNotificationService notifications,
      ) {
        final value = OperationalNotificationCoordinator(
          database: db,
          settings: () => settings,
          transport: () => OperationalNotificationTransport(
            deliver: notifications.deliverOperationalIssue,
            cancel: notifications.cancelOperationalIssue,
            synchronize: notifications.synchronize,
            readSettings: notifications.currentSettings,
          ),
        );
        addTearDown(value.stop);
        return value;
      }

      final first = coordinator(database, a);
      final second = coordinator(peer, b);
      await Future.wait([
        first.notifySyncFailure(
          const OAuthException('OAuthMissingToken', 'controlled'),
          accountId: 'google:test',
        ),
        second.notifySyncFailure(
          const OAuthException('OAuthMissingToken', 'controlled'),
          accountId: 'google:test',
        ),
      ]);
      expect(plugin.shown, hasLength(1));
      expect(plugin.activeIds, {
        (await database.select(database.notificationIssues).getSingle())
            .nativeId,
      });
      await second.clearAccountSyncFailure('google:test');
      expect(plugin.activeIds, isEmpty);
    },
  );

  test('operational interrupted persistence observes an active post without posting again', () async {
    await database
        .into(database.notificationIssues)
        .insert(
          NotificationIssuesCompanion.insert(
            id: 'sync-failure|google:test',
            accountId: const Value('google:test'),
            kind: 'sync-failure',
            revision: 'reconnectRequired:0',
          ),
        );
    final native = service();
    await native.initialize(timeZoneId: 'Etc/UTC');
    await native.deliverOperationalIssue(
      'sync-failure',
      'google:test',
      'reconnectRequired:0',
      1,
    );
    final runtime = OperationalNotificationCoordinator(
      database: database,
      settings: () => settings,
      transport: () => OperationalNotificationTransport(
        deliver: native.deliverOperationalIssue,
        cancel: native.cancelOperationalIssue,
        synchronize: native.synchronize,
        readSettings: native.currentSettings,
      ),
    );
    addTearDown(runtime.stop);
    await runtime.reconcile();
    expect(plugin.shown, hasLength(1));
    expect(
      (await database.select(database.notificationIssues).getSingle())
          .submittedRevision,
      'reconnectRequired:0',
    );
    // A known consumed post, including a later swipe, stays consumed.
    plugin.activeIds.clear();
    await runtime.reconcile();
    expect(plugin.shown, hasLength(1));
    await runtime.clearAccountSyncFailure('google:test');
    await runtime.notifySyncFailure(
      const OAuthException('OAuthMissingToken', 'controlled'),
      accountId: 'google:test',
    );
    expect(plugin.shown, hasLength(2));
  });

  test('background action identity survives task ID replacement and duplicate callbacks', () async {
    final now = DateTime.utc(2026, 6, 8, 8, 56);
    await database
        .update(database.accounts)
        .write(const AccountsCompanion(provider: Value('microsoft')));
    await _insertDueTodayTask(database, localDay: now.toLocal());
    await database
        .update(database.tasks)
        .write(
          TasksCompanion(
            microsoftIsReminderOn: const Value(true),
            microsoftReminderDateTime: Value(
              now.subtract(const Duration(minutes: 1)).toIso8601String(),
            ),
            microsoftReminderTimeZone: const Value('UTC'),
          ),
        );
    await NotificationScheduleService(
      database: database,
      nowUtc: () => now,
    ).rebuildUpcomingNotifications('google:test');
    final original = await database
        .select(database.notificationSchedule)
        .getSingle();
    // Replay transfers sourceId but retains delivery identity. A visible
    // notification's payload still contains the previous local item ID.
    await database
        .update(database.tasks)
        .write(const TasksCompanion(id: Value('server-task')));
    await database
        .update(database.notificationSchedule)
        .write(
          const NotificationScheduleCompanion(sourceId: Value('server-task')),
        );
    final old = AndroidReminderActivation(
      scheduleId: original.id,
      generation: original.generation,
      sourceType: 'task',
      accountId: original.accountId,
      itemId: 'task-1',
    );
    expect(
      await applyAndroidReminderAction(
        database: database,
        activation: old,
        actionId: androidNotificationActionSnooze,
        nowUtc: now,
      ),
      isTrue,
    );
    expect(
      await applyAndroidReminderAction(
        database: database,
        activation: old,
        actionId: androidNotificationActionSnooze,
        nowUtc: now,
      ),
      isFalse,
    );
    final snoozed = await database
        .select(database.notificationSchedule)
        .getSingle();
    expect(
      snoozed.snoozedUntilUtc,
      now.add(const Duration(minutes: 10)).millisecondsSinceEpoch,
    );
    final current = AndroidReminderActivation(
      scheduleId: snoozed.id,
      generation: snoozed.generation,
      sourceType: 'task',
      accountId: snoozed.accountId,
      itemId: 'server-task',
    );
    expect(
      await applyAndroidReminderAction(
        database: database,
        activation: current,
        actionId: androidNotificationActionDismiss,
        nowUtc: now,
      ),
      isTrue,
    );
    expect(
      await applyAndroidReminderAction(
        database: database,
        activation: current,
        actionId: androidNotificationActionDismiss,
        nowUtc: now,
      ),
      isFalse,
    );
    final task = await database.select(database.tasks).getSingle();
    expect(task.id, 'server-task');
    expect(task.status, isNot('completed'));
    expect(task.pendingDelete, isFalse);
  });

  test(
    'cold body Open validates a consumed native post without reviving delivery',
    () async {
      final now = DateTime.utc(2026, 6, 8, 8, 56);
      await _insertReminder(
        database,
        scheduledAt: now.subtract(const Duration(minutes: 1)),
        generation: 'opened',
      );
      await database
          .update(database.notificationSchedule)
          .write(
            NotificationScheduleCompanion(
              dismissedAtUtc: Value(now.millisecondsSinceEpoch),
            ),
          );
      final row = await database
          .select(database.notificationSchedule)
          .getSingle();
      final source = NotificationScheduleService(
        database: database,
        nowUtc: () => now,
      );
      expect(
        await source.validateAndReconcileReminder(row, forOpen: true),
        isTrue,
      );
      final consumed = await database
          .select(database.notificationSchedule)
          .getSingle();
      expect(consumed.dismissedAtUtc, row.dismissedAtUtc);
      expect(await source.validateAndReconcileReminder(consumed), isFalse);
      await database
          .update(database.calendarEvents)
          .write(const CalendarEventsCompanion(isDeleted: Value(true)));
      expect(
        await source.validateAndReconcileReminder(consumed, forOpen: true),
        isFalse,
      );
    },
  );

  for (final kind in [
    'start-only',
    'due-only',
    'start-and-due',
    'floating',
    'zoned',
    'completed',
    'cancelled',
  ]) {
    test(
      'Android summary uses the real DAV deadline and lifecycle ($kind)',
      () async {
        settings = settings.copyWith(notifyDueToday: true);
        final notifications = service();
        await notifications.initialize(timeZoneId: 'Etc/UTC');
        final today = _today().replaceAll('-', '');
        final localDay = DateTime.parse(_today());
        final tomorrow = DateTime(
          localDay.year,
          localDay.month,
          localDay.day + 1,
        ).toIso8601String().substring(0, 10).replaceAll('-', '');
        final eligible = ![
          'start-only',
          'completed',
          'cancelled',
        ].contains(kind);
        const href = '/dav/work/';
        await database
            .into(database.accounts)
            .insert(
              AccountsCompanion.insert(
                id: 'dav:test',
                provider: 'nextcloud',
                authority: 'https://qa.example.test',
                providerAccountId: 'test',
                credentialKind: 'nextcloud_app_password',
                authState: const Value('signed_in'),
                createdAtUtc: '',
                updatedAtUtc: '',
              ),
            );
        await database
            .into(database.davCollections)
            .insert(
              DavCollectionsCompanion.insert(
                id: 'dav-work',
                accountId: 'dav:test',
                displayName: 'Work',
                hrefKey: href,
                requestUri: 'https://qa.example.test$href',
                supportedComponentMask: const Value(2),
                taskProjectionEnabled: const Value(true),
                createdAtUtc: '',
                updatedAtUtc: '',
              ),
            );
        await database.taskListsDao.upsertTaskList(
          TaskListsCompanion.insert(
            accountId: 'dav:test',
            id: 'dav-task-list-dav-work',
            title: 'Work',
            davCollectionId: const Value('dav-work'),
            rawJson: '{}',
            createdLocalAtUtc: '',
            updatedLocalAtUtc: '',
          ),
        );
        const objectHref = '${href}task.ics';
        final raw = [
          'BEGIN:VCALENDAR',
          'VERSION:2.0',
          'PRODID:-//BusyMax Test//EN',
          'BEGIN:VTODO',
          'UID:deadline-test',
          'SUMMARY:Scheduled',
          if (kind == 'floating')
            'DTSTART:${today}T080000'
          else if (kind == 'zoned')
            'DTSTART;TZID=Pacific/Kiritimati:${tomorrow}T000000'
          else if (kind != 'due-only')
            'DTSTART;VALUE=DATE:$today',
          if (kind == 'floating')
            'DUE:${today}T090000'
          else if (kind == 'zoned')
            'DUE;TZID=Pacific/Kiritimati:${tomorrow}T003000'
          else if (kind != 'start-only')
            'DUE;VALUE=DATE:$today',
          if (kind == 'completed') ...[
            'STATUS:COMPLETED',
            'PERCENT-COMPLETE:100',
            'COMPLETED:${today}T000000Z',
          ],
          if (kind == 'cancelled') 'STATUS:CANCELLED',
          'END:VTODO',
          'END:VCALENDAR',
          '',
        ].join('\r\n');
        await DavObjectRepository(database: database).commit(
          DavCollectionCommit(
            accountId: 'dav:test',
            collectionId: 'dav-work',
            provider: BusyProvider.nextcloud,
            objects: [
              DavPreparedObject.parse(
                hrefKey: objectHref,
                requestUri: Uri.parse('https://qa.example.test$objectHref'),
                etag: '"one"',
                contentType: 'text/calendar',
                rawIcsBody: raw,
              ),
            ],
            deletedHrefKeys: const {},
            completeMembership: true,
            membershipHrefKeys: const {objectHref},
            finalCursorKind: 'dav_sync_token',
            finalCursorValue: 'one',
            baselineGeneration: 1,
            completedAtUtc: DateTime.now().toUtc(),
            projectionRangeStartUtc: DateTime.utc(localDay.year),
            projectionRangeEndUtc: DateTime.utc(localDay.year + 1),
          ),
        );
        expect(
          (await database.select(database.tasks).getSingle()).dueUtc,
          isNotNull,
        );
        await notifications.reconcile();
        expect(
          await database.select(database.androidDailySummarySchedules).get(),
          hasLength(eligible ? 1 : 0),
        );
      },
    );
  }

  test(
    'reconciliation preserves a delivered notification still visible',
    () async {
      await _insertReminder(
        database,
        generation: 'generation-1',
        scheduledAt: DateTime.now().subtract(const Duration(hours: 1)),
      );
      await _insertMapping(
        database,
        generation: 'generation-1',
        platformId: 42,
        state: androidNotificationRegistrationState(
          settings: settings,
          exact: false,
        ),
      );
      plugin.activeIds.add(42);
      final notifications = service();
      await notifications.initialize(timeZoneId: 'America/Vancouver');

      await notifications.reconcile();

      expect(plugin.cancelledIds, isNot(contains(42)));
      expect(plugin.scheduledIds, isNot(contains(42)));
      expect(
        await database.select(database.androidNotificationMappings).get(),
        hasLength(1),
      );
    },
  );

  test(
    'account recovery does not replay a post first observed while ineligible',
    () async {
      await _insertReminder(
        database,
        generation: 'observed',
        scheduledAt: DateTime.now().subtract(const Duration(minutes: 1)),
      );
      await _insertMapping(
        database,
        generation: 'observed',
        platformId: 42,
        state: androidNotificationRegistrationState(
          settings: settings,
          exact: false,
        ),
      );
      plugin.activeIds.add(42);
      await database
          .update(database.accounts)
          .write(const AccountsCompanion(authState: Value('reauth_required')));
      final notifications = service();
      await notifications.initialize(timeZoneId: 'America/Vancouver');
      await notifications.reconcile();
      expect(
        (await database.select(database.notificationSchedule).getSingle())
            .sentAtUtc,
        isNotNull,
      );
      expect(plugin.activeIds, isEmpty);
      await database
          .update(database.accounts)
          .write(const AccountsCompanion(authState: Value('signed_in')));
      await notifications.reconcile();
      expect(plugin.scheduled, isEmpty);
      expect(plugin.activeIds, isEmpty);
    },
  );

  test(
    'a stale active generation is replaced by its relevant current delivery',
    () async {
      await _insertReminder(
        database,
        generation: 'generation-2',
        scheduledAt: DateTime.now().subtract(const Duration(hours: 1)),
      );
      await _insertMapping(
        database,
        generation: 'generation-1',
        platformId: 42,
        state: androidNotificationRegistrationState(
          settings: settings,
          exact: false,
        ),
      );
      plugin.activeIds.add(42);
      final notifications = service();
      await notifications.initialize(timeZoneId: 'Etc/UTC');

      await notifications.reconcile();

      expect(plugin.cancelledIds, contains(42));
      expect(plugin.scheduledIds, hasLength(1));
      expect(
        await database.select(database.androidNotificationMappings).get(),
        hasLength(1),
      );
    },
  );

  test(
    'dismissed reminders are removed even when the old post is active',
    () async {
      await _insertReminder(
        database,
        generation: 'generation-1',
        scheduledAt: DateTime.now().subtract(const Duration(hours: 1)),
        dismissed: true,
      );
      await _insertMapping(
        database,
        generation: 'generation-1',
        platformId: 42,
        state: androidNotificationRegistrationState(
          settings: settings,
          exact: false,
        ),
      );
      plugin.activeIds.add(42);
      final notifications = service();
      await notifications.initialize(timeZoneId: 'Etc/UTC');

      await notifications.reconcile();

      expect(plugin.cancelledIds, contains(42));
      expect(
        await database.select(database.androidNotificationMappings).get(),
        isEmpty,
      );
    },
  );

  test('an overdue inexact alarm remains registered while pending', () async {
    final scheduledAt = DateTime.now().subtract(const Duration(minutes: 30));
    await _insertReminder(
      database,
      generation: 'generation-1',
      scheduledAt: scheduledAt,
    );
    final state = await _reminderState(database, settings);
    await _insertMapping(
      database,
      generation: 'generation-1',
      platformId: 42,
      state: state,
      scheduledAt: scheduledAt,
    );
    plugin.pendingIds.add(42);
    final notifications = service();
    await notifications.initialize(timeZoneId: 'America/Vancouver');

    await notifications.reconcile();

    expect(plugin.cancelledIds, isNot(contains(42)));
    expect(plugin.scheduledIds, isNot(contains(42)));
  });

  test('snooze generation schedules its future effective time', () async {
    final now = DateTime.now();
    await _insertReminder(
      database,
      generation: 'generation-1:snooze',
      scheduledAt: now.subtract(const Duration(hours: 1)),
    );
    await database
        .update(database.notificationSchedule)
        .write(
          NotificationScheduleCompanion(
            snoozedUntilUtc: Value(
              now.add(const Duration(hours: 1)).millisecondsSinceEpoch,
            ),
          ),
        );
    final notifications = service();
    await notifications.initialize(timeZoneId: 'America/Vancouver');

    await notifications.reconcile();

    expect(plugin.scheduledIds, hasLength(1));
    final mapping = await database
        .select(database.androidNotificationMappings)
        .getSingle();
    expect(mapping.generation, 'generation-1:snooze');
    expect(
      mapping.scheduledAtUtc,
      now.add(const Duration(hours: 1)).millisecondsSinceEpoch,
    );
  });

  test('quiet-hours deferral survives a second reconciliation', () async {
    final notifications = service();
    await notifications.initialize(timeZoneId: 'America/Vancouver');
    final today = tz.TZDateTime.now(tz.local);
    final requested = tz.TZDateTime(
      tz.local,
      today.year,
      today.month,
      today.day + 1,
      23,
    );
    settings = settings.copyWith(
      quietHoursEnabled: true,
      quietHoursStart: '22:00',
      quietHoursEnd: '07:00',
    );
    await _insertReminder(
      database,
      generation: 'generation-1',
      scheduledAt: requested,
    );

    await notifications.reconcile();
    final mapping = await database
        .select(database.androidNotificationMappings)
        .getSingle();
    expect(
      mapping.scheduledAtUtc,
      greaterThan(requested.millisecondsSinceEpoch),
    );
    final platformId = mapping.platformId;
    plugin.cancelledIds.clear();
    plugin.scheduled.clear();

    await notifications.reconcile();

    expect(plugin.cancelledIds, isNot(contains(platformId)));
    expect(plugin.scheduledIds, isNot(contains(platformId)));
  });

  test('content-only edits replace an unchanged pending reminder', () async {
    final scheduledAt = DateTime.now().add(const Duration(hours: 1));
    await _insertReminder(
      database,
      generation: 'generation-1',
      scheduledAt: scheduledAt,
    );
    final notifications = service();
    await notifications.initialize(timeZoneId: 'America/Vancouver');
    await notifications.reconcile();
    final mapping = await database
        .select(database.androidNotificationMappings)
        .getSingle();
    final platformId = mapping.platformId;
    plugin.cancelledIds.clear();
    plugin.scheduled.clear();

    await database
        .update(database.calendarEvents)
        .write(
          const CalendarEventsCompanion(
            title: Value('Renamed meeting'),
            location: Value('Updated location'),
          ),
        );
    await notifications.reconcile();

    expect(plugin.cancelledIds, contains(platformId));
    expect(plugin.scheduledIds, contains(platformId));
    final call = plugin.scheduled.single;
    expect(call.title, 'Renamed meeting');
    expect(call.body, contains('Updated location'));
    final updatedMapping = await database
        .select(database.androidNotificationMappings)
        .getSingle();
    expect(updatedMapping.generation, 'generation-1');
    expect(updatedMapping.state, await _reminderState(database, settings));
  });

  for (final restart in [false, true]) {
    for (final disableAccounts in [false, true]) {
      test(
        'future summary can be restored after ${disableAccounts ? 'eligibility loss' : 'disable'} (restart $restart)',
        () async {
          final directory = await createPersistenceTestDirectory(
            'busymax-summary-',
          );
          directories.add(directory);
          final account = await database.select(database.accounts).getSingle();
          await database.close();
          database = AppDatabase(
            NativeDatabase(File('${directory.path}/busymax.sqlite')),
          );
          await database
              .into(database.accounts)
              .insert(account.toCompanion(true));
          var clock = DateTime.utc(2026, 6, 8, 15); // 08:00 Vancouver.
          settings = settings.copyWith(
            notifyDueToday: true,
            dueTodayNotificationTime: '09:00',
          );
          var notifications = service(clock: () => clock);
          await notifications.initialize(timeZoneId: 'America/Vancouver');
          await _insertDueTodayTask(
            database,
            localDay: tz.TZDateTime.from(clock, tz.local),
          );
          await notifications.reconcile();
          const id = 0x425903;
          expect(plugin.scheduled, hasLength(1));
          expect(plugin.pendingIds, {id});
          expect(plugin.scheduled.single.date.hour, 9);
          if (disableAccounts) {
            await database
                .update(database.accounts)
                .write(const AccountsCompanion(authState: Value('signed_out')));
          } else {
            settings = settings.copyWith(notifyDueToday: false);
          }
          await notifications.reconcile();
          expect(plugin.cancelledIds, contains(id));
          expect(plugin.pendingIds, isEmpty);
          if (restart) {
            await database.close();
            database = AppDatabase(
              NativeDatabase(File('${directory.path}/busymax.sqlite')),
            );
            notifications = service(clock: () => clock);
            await notifications.initialize(timeZoneId: 'America/Vancouver');
          }
          clock = clock.add(const Duration(minutes: 5));
          // Restoration reads current tasks, time and privacy rather than the withdrawn payload.
          await database
              .update(database.tasks)
              .write(const TasksCompanion(title: Value('Current task')));
          final task = await database.select(database.tasks).getSingle();
          await database
              .into(database.tasks)
              .insert(task.copyWith(id: 'new-task'));
          settings = settings.copyWith(
            notifyDueToday: true,
            dueTodayNotificationTime: '09:15',
            notificationDetailLevel: NotificationDetailLevel.private,
          );
          if (disableAccounts) {
            await database
                .update(database.accounts)
                .write(const AccountsCompanion(authState: Value('signed_in')));
          }
          await notifications.reconcile();
          await notifications.reconcile();
          expect(plugin.scheduled, hasLength(2));
          expect(plugin.pendingIds, {id});
          final restored = plugin.scheduled.last;
          expect(restored.id, id);
          expect(restored.date.hour, 9);
          expect(restored.date.minute, 15);
          expect(restored.date.location.name, 'America/Vancouver');
          expect(restored.body, isNull);
          expect(plugin.shown, isEmpty);
          final row = await database
              .select(database.androidDailySummarySchedules)
              .getSingle();
          expect(row.taskCount, 2);
          expect(row.state, startsWith('scheduled:v3:private:'));
        },
      );
    }
  }

  for (final afterRemoval in [false, true]) {
    test(
      'future summary cancellation recovers after native failure (removed $afterRemoval)',
      () async {
        final clock = DateTime.utc(2026, 6, 8, 15);
        settings = settings.copyWith(
          notifyDueToday: true,
          dueTodayNotificationTime: '09:00',
        );
        final notifications = service(clock: () => clock);
        await notifications.initialize(timeZoneId: 'America/Vancouver');
        await _insertDueTodayTask(
          database,
          localDay: tz.TZDateTime.from(clock, tz.local),
        );
        await notifications.reconcile();
        settings = settings.copyWith(notifyDueToday: false);
        if (afterRemoval) {
          plugin.cancellationFailuresAfterRemoval = 1;
        } else {
          plugin.cancellationFailuresRemaining = 1;
        }
        await expectLater(notifications.reconcile(), throwsStateError);
        expect(
          (await database
                  .select(database.androidDailySummarySchedules)
                  .getSingle())
              .state,
          'withdrawing:pending',
        );
        settings = settings.copyWith(notifyDueToday: true);
        final restarted = service(
          clock: () => clock.add(const Duration(minutes: 5)),
        );
        await restarted.initialize(timeZoneId: 'America/Vancouver');
        await restarted.reconcile();
        await restarted.reconcile();
        expect(plugin.scheduled, hasLength(2));
        expect(plugin.pendingIds, {0x425903});
        expect(plugin.shown, isEmpty);
      },
    );
  }

  test(
    'consumed summary remains suppressed through disable and re-enable',
    () async {
      var clock = DateTime.utc(2026, 6, 8, 15);
      settings = settings.copyWith(
        notifyDueToday: true,
        dueTodayNotificationTime: '09:00',
      );
      final notifications = service(clock: () => clock);
      await notifications.initialize(timeZoneId: 'America/Vancouver');
      await _insertDueTodayTask(
        database,
        localDay: tz.TZDateTime.from(clock, tz.local),
      );
      await notifications.reconcile();
      clock = clock.add(const Duration(hours: 2));
      plugin.pendingIds
          .clear(); // Delivered and dismissed before reconciliation.
      await notifications.reconcile();
      expect(
        (await database
                .select(database.androidDailySummarySchedules)
                .getSingle())
            .state,
        'consumed',
      );
      settings = settings.copyWith(notifyDueToday: false);
      await notifications.reconcile();
      settings = settings.copyWith(notifyDueToday: true);
      await notifications.reconcile();
      expect(plugin.scheduled, hasLength(1));
      expect(plugin.pendingIds, isEmpty);
      expect(plugin.shown, isEmpty);
    },
  );

  test(
    'overdue pending summary is replaced after privacy and precision change',
    () async {
      final notifications = service(exact: true);
      await notifications.initialize(timeZoneId: 'America/Vancouver');
      await _insertDueTodayTask(database);
      final dueTask = await database.select(database.tasks).getSingle();
      expect(taskDueAsLocal(dueTask), isNotNull);
      expect(taskDueAsLocal(dueTask)!.day, tz.TZDateTime.now(tz.local).day);
      final previousSettings = settings;
      final localDate = _today();
      await database
          .into(database.androidDailySummarySchedules)
          .insert(
            AndroidDailySummarySchedulesCompanion.insert(
              localDate: localDate,
              platformId: 0x425903,
              generation: 'old',
              scheduledAtUtc: DateTime.now()
                  .subtract(const Duration(hours: 1))
                  .millisecondsSinceEpoch,
              taskCount: 1,
              state: Value(
                androidNotificationRegistrationState(
                  settings: previousSettings,
                  exact: false,
                ),
              ),
              updatedAtUtc: 0,
            ),
          );
      plugin.pendingIds.add(0x425903);
      plugin.activeQueryFails = true;
      settings = settings.copyWith(
        notifyDueToday: true,
        notificationDetailLevel: NotificationDetailLevel.private,
      );
      await notifications.reconcile();

      expect(plugin.cancelledIds, contains(0x425903));
      expect(plugin.scheduledIds, contains(0x425903));
      final call = plugin.scheduled.lastWhere((value) => value.id == 0x425903);
      expect(call.body, isNull);
      expect(call.mode, AndroidScheduleMode.exactAllowWhileIdle);
      final row = await database
          .select(database.androidDailySummarySchedules)
          .getSingle();
      expect(row.state, startsWith('scheduled:v3:private:exact:'));
    },
  );

  test('server-missing due-today task cancels the existing summary', () async {
    settings = settings.copyWith(notifyDueToday: true);
    final notifications = service();
    await notifications.initialize(timeZoneId: 'America/Vancouver');
    await _insertDueTodayTask(database);

    await notifications.reconcile();

    const summaryId = 0x425903;
    final scheduled = await database
        .select(database.androidDailySummarySchedules)
        .getSingle();
    expect(scheduled.taskCount, 1);
    expect(plugin.pendingIds, contains(summaryId));

    await database
        .update(database.tasks)
        .write(const TasksCompanion(serverMissing: Value(true)));
    plugin.cancelledIds.clear();
    plugin.scheduled.clear();

    await notifications.reconcile();

    expect(plugin.cancelledIds, contains(summaryId));
    expect(plugin.scheduledIds, isEmpty);
    expect(
      await database.select(database.androidDailySummarySchedules).get(),
      isEmpty,
    );
  });
  test(
    'first discovery after trigger keeps a still-upcoming Android reminder',
    () async {
      final clock = DateTime.utc(2026, 6, 8, 8, 56);
      await _insertReminder(
        database,
        generation: 'late-import',
        scheduledAt: clock.subtract(const Duration(minutes: 1)),
      );
      final notifications = service(clock: () => clock);
      await notifications.initialize(timeZoneId: 'Etc/UTC');
      await notifications.reconcile();
      expect(plugin.scheduled, hasLength(1));
      expect(
        plugin.scheduled.single.date.toUtc(),
        clock.add(const Duration(seconds: 1)),
      );
      await notifications.reconcile();
      expect(plugin.scheduled, hasLength(1));
    },
  );

  test(
    'native registration can cross the trigger instant without loss',
    () async {
      var clock = DateTime.utc(2026, 6, 8, 8, 54, 59);
      final trigger = clock.add(const Duration(seconds: 1));
      await _insertReminder(
        database,
        generation: 'crossing',
        scheduledAt: trigger,
      );
      final notifications = service(clock: () => clock);
      await notifications.initialize(timeZoneId: 'Etc/UTC');
      plugin.beforePendingQuery = () =>
          clock = trigger.add(const Duration(seconds: 1));
      await notifications.reconcile();
      expect(plugin.scheduled, hasLength(1));
      expect(plugin.scheduled.single.date.toUtc().isAfter(clock), isTrue);
    },
  );

  test(
    'permission and channel readiness remain separate from exact alarms',
    () async {
      final notifications = service(exact: true);
      await notifications.initialize(timeZoneId: 'Etc/UTC');
      await _insertReminder(
        database,
        generation: 'permission',
        scheduledAt: DateTime.now().add(const Duration(hours: 1)),
      );
      capabilities['notifications'] = false;
      plugin.permissionGranted = false;
      expect(await notifications.requestNotificationPermission(), isFalse);
      await notifications.reconcile();
      expect(notifications.readiness.value.exactAlarms, isTrue);
      expect(notifications.readiness.value.remindersReady, isFalse);
      expect(plugin.scheduled, isEmpty);
      expect(
        await database.select(database.notificationSchedule).get(),
        hasLength(1),
      );
      capabilities['notifications'] = true;
      capabilities['reminders'] = false;
      plugin.permissionGranted = true;
      expect(await notifications.requestNotificationPermission(), isTrue);
      expect(notifications.readiness.value.notificationsAllowed, isTrue);
      expect(notifications.readiness.value.remindersReady, isFalse);
      capabilities['reminders'] = true;
      await notifications.reconcile();
      expect(notifications.readiness.value.remindersReady, isTrue);
      expect(plugin.scheduled, hasLength(1));
    },
  );

  test('privacy withdraws visible details despite active-query failure and retries cancellation', () async {
    await _insertReminder(
      database,
      generation: 'visible-private',
      scheduledAt: DateTime.now().subtract(const Duration(minutes: 1)),
    );
    await _insertMapping(
      database,
      generation: 'visible-private',
      platformId: 42,
      state: await _reminderState(database, settings),
    );
    plugin.activeIds.add(42);
    plugin.activeQueryFails = true;
    plugin.cancellationFailuresRemaining = 1;
    final notifications = service();
    await notifications.initialize(timeZoneId: 'Etc/UTC');
    settings = settings.copyWith(
      notificationDetailLevel: NotificationDetailLevel.private,
    );
    await expectLater(notifications.reconcile(), throwsStateError);
    expect(
      (await database.select(database.androidNotificationMappings).getSingle())
          .state,
      startsWith('withdrawing:'),
    );
    plugin.activeQueryFails = false;
    await notifications.reconcile();
    expect(plugin.activeIds, isEmpty);
    expect(plugin.scheduled, isEmpty);
    settings = settings.copyWith(
      notificationDetailLevel: NotificationDetailLevel.normal,
    );
    await notifications.reconcile();
    expect(plugin.scheduled, isEmpty);
  });

  for (final activeQueryFails in [false, true]) {
    for (final cancellationFailure in [
      'none',
      'before removal',
      'after removal',
    ]) {
      test(
        'privacy during delayed registration preserves an overdue inexact alarm that has not fired (active query fails: $activeQueryFails; cancellation failure: $cancellationFailure)',
        () async {
          final clock = DateTime.now();
          AppDatabase? peer;
          if (cancellationFailure != 'none') {
            final directory = await createPersistenceTestDirectory(
              'busymax-private-replacement-',
            );
            directories.add(directory);
            peer = await shareDatabase(directory);
          }
          await _insertReminder(
            database,
            generation: 'privacy-race',
            scheduledAt: clock.subtract(const Duration(minutes: 1)),
          );
          plugin.registrationBarrier = Completer<void>();
          plugin.activeQueryFails = activeQueryFails;
          var notifications = service(clock: () => clock);
          await notifications.initialize(timeZoneId: 'Etc/UTC');
          final registering = notifications.reconcile();
          await plugin.registrationStarted.future;
          settings = settings.copyWith(
            notificationDetailLevel: NotificationDetailLevel.private,
          );
          if (cancellationFailure == 'before removal') {
            plugin.cancellationFailuresRemaining = 1;
          } else if (cancellationFailure == 'after removal') {
            plugin.cancellationFailuresAfterRemoval = 1;
          }
          plugin.registrationBarrier!.complete();
          if (cancellationFailure == 'none') {
            await registering;
          } else {
            await expectLater(registering, throwsStateError);
            expect(
              (await peer!.select(peer.androidNotificationMappings).getSingle())
                  .state,
              startsWith('replacing:'),
            );
            expect(
              (await peer.select(peer.notificationSchedule).getSingle())
                  .sentAtUtc,
              isNull,
            );
            // A new service/SQLite connection recovers the durable replacement
            // decision, including interruption after native removal took effect.
            notifications = AndroidNotificationService(
              database: peer,
              settings: () => settings,
              backend: plugin,
              exactAlarmCapability: () async => false,
              now: () => clock,
            );
            await notifications.initialize(timeZoneId: 'Etc/UTC');
            await notifications.reconcile();
          }
          expect(plugin.scheduled, hasLength(2));
          expect(plugin.pendingIds, {plugin.scheduled.last.id});
          expect(plugin.scheduled.last.id, plugin.scheduled.first.id);
          expect(plugin.scheduled.last.body, isNull);
          expect(plugin.scheduled.last.details.android!.silent, isTrue);
          expect(
            (await database.select(database.notificationSchedule).getSingle())
                .sentAtUtc,
            isNull,
          );
          final nativeId = plugin.scheduled.last.id;
          expect(plugin.cancelledIds, contains(nativeId));
          final mapping = await database
              .select(database.androidNotificationMappings)
              .getSingle();
          expect(mapping.platformId, nativeId);
          expect(mapping.generation, 'privacy-race');
          expect(mapping.state, startsWith('scheduled:v3:private:'));
          await notifications.reconcile();
          expect(plugin.scheduled, hasLength(2));
          expect(plugin.pendingIds, {nativeId});
          plugin.activeQueryFails = false;
          await notifications.reconcile();
          expect(plugin.scheduled, hasLength(2));
          expect(
            (await database.select(database.notificationSchedule).getSingle())
                .sentAtUtc,
            isNull,
          );
          plugin.pendingIds.clear();
          plugin.activeIds.add(plugin.scheduled.last.id);
          await notifications.reconcile();
          expect(
            (await database.select(database.notificationSchedule).getSingle())
                .sentAtUtc,
            isNotNull,
          );
        },
      );
    }
  }

  for (final scenario in [
    (
      historyUnavailable: false,
      delivered: false,
      activeOnRecovery: false,
      channelBlocked: false,
    ),
    (
      historyUnavailable: true,
      delivered: false,
      activeOnRecovery: false,
      channelBlocked: false,
    ),
    (
      historyUnavailable: false,
      delivered: false,
      activeOnRecovery: true,
      channelBlocked: false,
    ),
    (
      historyUnavailable: false,
      delivered: true,
      activeOnRecovery: false,
      channelBlocked: false,
    ),
    (
      historyUnavailable: true,
      delivered: true,
      activeOnRecovery: false,
      channelBlocked: false,
    ),
    (
      historyUnavailable: false,
      delivered: false,
      activeOnRecovery: false,
      channelBlocked: true,
    ),
    (
      historyUnavailable: true,
      delivered: false,
      activeOnRecovery: false,
      channelBlocked: true,
    ),
  ]) {
    test(
      'disabled-category withdrawal retry preserves replacement meaning $scenario',
      () async {
        final directory = await createPersistenceTestDirectory(
          'busymax-withdrawal-',
        );
        directories.add(directory);
        final peer = await shareDatabase(directory);
        final clock = DateTime.utc(2026, 6, 8, 8, 56);
        await _insertReminder(
          database,
          generation: 'withdrawal-race',
          scheduledAt: clock.subtract(const Duration(minutes: 1)),
        );
        plugin.activeQueryFails = scenario.historyUnavailable;
        plugin.registrationBarrier = Completer<void>();
        // Cancellation #1 removes the newly registered alarm. Cleanup's second
        // cancellation fails after persisting its outer withdrawal obligation.
        plugin.cancellationFailureAttempts.add(2);
        if (scenario.delivered) {
          plugin.beforePendingQuery = () {
            if (plugin.pendingIds.isNotEmpty) {
              plugin.activeIds.addAll(plugin.pendingIds);
              plugin.pendingIds.clear();
            }
          };
        }
        final original = service(clock: () => clock);
        await original.initialize(timeZoneId: 'Etc/UTC');
        final registering = original.reconcile();
        await plugin.registrationStarted.future;
        settings = settings.copyWith(notifyEventReminders: false);
        plugin.registrationBarrier!.complete();
        await expectLater(registering, throwsStateError);
        plugin.beforePendingQuery = null;

        expect(plugin.scheduled, hasLength(1));
        final nativeId = plugin.scheduled.single.id;
        expect(plugin.cancelledIds, [nativeId, nativeId]);
        expect(plugin.pendingIds, isEmpty);
        expect(plugin.activeIds, isEmpty);
        final withdrawing = await peer
            .select(peer.androidNotificationMappings)
            .getSingle();
        expect(withdrawing.platformId, nativeId);
        expect(withdrawing.generation, 'withdrawal-race');
        expect(
          withdrawing.state,
          startsWith(
            scenario.delivered
                ? 'withdrawing:registering:'
                : 'withdrawing:replacing:scheduled:',
          ),
        );
        final beforeRecovery = await peer
            .select(peer.notificationSchedule)
            .getSingle();
        expect(
          beforeRecovery.sentAtUtc,
          scenario.delivered ? isNotNull : isNull,
        );
        expect(beforeRecovery.dismissedAtUtc, isNull);

        settings = settings.copyWith(notifyEventReminders: true);
        if (scenario.activeOnRecovery) plugin.activeIds.add(nativeId);
        final restarted = AndroidNotificationService(
          database: peer,
          settings: () => settings,
          backend: plugin,
          exactAlarmCapability: () async => false,
          now: () => clock,
        );
        await restarted.initialize(timeZoneId: 'Etc/UTC');
        if (scenario.channelBlocked) {
          capabilities['reminders'] = false;
          await restarted.reconcile();
          expect(plugin.scheduled, hasLength(1));
          expect(restarted.readiness.value.remindersReady, isFalse);
          final blocked = await peer
              .select(peer.notificationSchedule)
              .getSingle();
          expect(blocked.sentAtUtc, isNull);
          expect(blocked.dismissedAtUtc, isNull);
          capabilities['reminders'] = true;
        }
        await restarted.reconcile();
        expect(restarted.readiness.value.remindersReady, isTrue);
        final consumed = scenario.delivered || scenario.activeOnRecovery;
        var row = await peer.select(peer.notificationSchedule).getSingle();
        expect(row.generation, 'withdrawal-race');
        expect(row.sentAtUtc, consumed ? isNotNull : isNull);
        if (!consumed) expect(row.dismissedAtUtc, isNull);
        expect(plugin.scheduled, hasLength(consumed ? 1 : 2));
        expect(plugin.pendingIds, consumed ? isEmpty : equals({nativeId}));
        if (!consumed) {
          final replacement = await peer
              .select(peer.androidNotificationMappings)
              .getSingle();
          expect(replacement.platformId, nativeId);
          expect(replacement.generation, withdrawing.generation);
          expect(replacement.state, startsWith('scheduled:v3:normal:'));
          expect(plugin.scheduled.last.id, nativeId);
          expect(plugin.scheduled.last.payload, plugin.scheduled.first.payload);
        }
        await restarted.reconcile();
        plugin.activeQueryFails = false;
        await restarted.reconcile();
        expect(plugin.scheduled, hasLength(consumed ? 1 : 2));
        row = await peer.select(peer.notificationSchedule).getSingle();
        if (!consumed) {
          expect(row.sentAtUtc, isNull);
          expect(row.dismissedAtUtc, isNull);
          plugin.pendingIds.clear();
          plugin.activeIds.add(nativeId);
          await restarted.reconcile();
          expect(
            (await peer.select(peer.notificationSchedule).getSingle())
                .sentAtUtc,
            isNotNull,
          );
          expect(plugin.scheduled, hasLength(2));
        }
        final source = await peer.select(peer.calendarEvents).getSingle();
        expect(source.isCancelled, isFalse);
        expect(source.isDeleted, isFalse);
      },
    );
  }

  test(
    'a visible summary changes count and privacy silently without a new alarm',
    () async {
      settings = settings.copyWith(
        notifyDueToday: true,
        dueTodayNotificationTime: '00:00',
      );
      final notifications = service();
      await notifications.initialize(timeZoneId: 'America/Vancouver');
      await _insertDueTodayTask(database);
      await notifications.reconcile();
      plugin.pendingIds.remove(0x425903);
      plugin.activeIds.add(0x425903);
      final task = await database.select(database.tasks).getSingle();
      await database
          .into(database.tasks)
          .insert(task.copyWith(id: 'second-task'));
      await notifications.reconcile();
      expect(plugin.scheduled, hasLength(1));
      expect(plugin.shown.single.body, contains('2'));
      expect(plugin.shown.single.details.android!.silent, isTrue);
      expect(plugin.shown.single.details.android!.onlyAlertOnce, isTrue);
      settings = settings.copyWith(
        notificationDetailLevel: NotificationDetailLevel.private,
      );
      await notifications.reconcile();
      expect(plugin.shown.last.body, isNull);
      expect(plugin.shown.last.details.android!.silent, isTrue);
      await database
          .update(database.tasks)
          .write(const TasksCompanion(status: Value('completed')));
      await notifications.reconcile();
      expect(plugin.activeIds, isEmpty);
      await database
          .update(database.tasks)
          .write(const TasksCompanion(status: Value('needsAction')));
      await notifications.reconcile();
      expect(plugin.scheduled, hasLength(1));
    },
  );

  test(
    'summary time and local timezone changes reschedule a pending summary',
    () async {
      final day = DateTime.now().toUtc();
      var clock = DateTime.utc(day.year, day.month, day.day, 14);
      settings = settings.copyWith(
        notifyDueToday: true,
        dueTodayNotificationTime: '23:30',
      );
      final notifications = service(clock: () => clock);
      await notifications.initialize(timeZoneId: 'America/Vancouver');
      await _insertDueTodayTask(
        database,
        localDay: tz.TZDateTime.from(clock, tz.local),
      );
      await notifications.reconcile();
      expect(plugin.scheduled.single.date.hour, 23);
      settings = settings.copyWith(dueTodayNotificationTime: '23:45');
      await notifications.reconcile();
      expect(plugin.scheduled.last.date.minute, 45);
      final previousUtc = plugin.scheduled.last.date.toUtc();
      await notifications.initialize(timeZoneId: 'Asia/Tokyo');
      await notifications.reconcile();
      expect(plugin.scheduled.last.date.toUtc(), isNot(previousUtc));
      expect(plugin.scheduled.last.date.hour, 23);
      expect(plugin.scheduled.last.date.minute, 45);
      clock = clock.add(const Duration(minutes: 1));
    },
  );

  test(
    'native identity survives account deletion until cancellation succeeds',
    () async {
      await _insertReminder(
        database,
        generation: 'removed-account',
        scheduledAt: DateTime.now().add(const Duration(hours: 1)),
      );
      final notifications = service();
      await notifications.initialize(timeZoneId: 'Etc/UTC');
      await notifications.reconcile();
      final id = plugin.scheduled.single.id;
      await database.delete(database.accounts).go();
      expect(
        await database.select(database.androidNotificationMappings).get(),
        hasLength(1),
      );
      plugin.cancellationFailuresRemaining = 1;
      await expectLater(notifications.reconcile(), throwsStateError);
      expect(
        await database.select(database.androidNotificationMappings).get(),
        hasLength(1),
      );
      await notifications.reconcile();
      expect(plugin.cancelledIds, contains(id));
      expect(
        await database.select(database.androidNotificationMappings).get(),
        isEmpty,
      );
    },
  );

  test(
    'German background-action construction keeps localized ten-minute actions',
    () async {
      settings = settings.copyWith(localeTag: 'de');
      final clock = DateTime.now().toUtc();
      await _insertReminder(
        database,
        generation: 'german',
        scheduledAt: clock.subtract(const Duration(minutes: 1)),
      );
      final row = await database
          .select(database.notificationSchedule)
          .getSingle();
      expect(
        await applyAndroidReminderAction(
          database: database,
          activation: AndroidReminderActivation(
            scheduleId: row.id,
            generation: row.generation,
            sourceType: row.sourceType,
            accountId: row.accountId,
            itemId: row.sourceId,
          ),
          actionId: androidNotificationActionSnooze,
          nowUtc: clock,
        ),
        isTrue,
      );
      final restarted = service(clock: () => clock);
      await restarted.initialize(timeZoneId: 'Etc/UTC');
      await restarted.reconcile();
      final labels = plugin.scheduled.single.details.android!.actions!
          .map((action) => action.title)
          .toList();
      expect(labels, ['Öffnen', 'In 10 Minuten erinnern', 'Schließen']);
    },
  );
}

Future<void> _insertReminder(
  AppDatabase database, {
  required String generation,
  required DateTime scheduledAt,
  bool dismissed = false,
}) async {
  await database
      .into(database.calendarSources)
      .insertOnConflictUpdate(
        CalendarSourcesCompanion.insert(
          id: 'calendar',
          accountId: 'google:test',
          provider: 'google',
          providerCalendarId: 'calendar',
          summary: 'Calendar',
          createdAtLocal: 0,
          updatedAtLocal: 0,
        ),
      );
  await database
      .into(database.calendarEvents)
      .insertOnConflictUpdate(
        CalendarEventsCompanion.insert(
          id: 'event-1',
          accountId: 'google:test',
          calendarSourceId: 'calendar',
          provider: 'google',
          providerCalendarId: 'calendar',
          providerEventId: 'event-1',
          title: 'Visible meeting',
          startDateTime: Value(
            scheduledAt
                .toUtc()
                .add(const Duration(minutes: 5))
                .toIso8601String(),
          ),
          endDateTime: Value(
            scheduledAt
                .toUtc()
                .add(const Duration(hours: 12))
                .toIso8601String(),
          ),
          remindersJson: Value(
            jsonEncode({
              'overrides': [
                {'method': 'popup', 'minutes': 5},
              ],
            }),
          ),
          createdAtLocal: 0,
          updatedAtLocal: 0,
        ),
      );
  await database
      .into(database.notificationSchedule)
      .insert(
        NotificationScheduleCompanion.insert(
          id: 'event|event-1|5',
          generation: Value(generation),
          accountId: 'google:test',
          sourceType: 'event',
          sourceId: 'event-1',
          scheduledAtUtc: scheduledAt.millisecondsSinceEpoch,
          title: 'Visible meeting',
          dismissedAtUtc: dismissed
              ? Value(DateTime.now().millisecondsSinceEpoch)
              : const Value.absent(),
          createdAtLocal: 0,
          updatedAtLocal: 0,
        ),
      );
}

Future<String> _reminderState(
  AppDatabase database,
  AppSettings settings, {
  bool exact = false,
}) async {
  final row = await database.select(database.notificationSchedule).getSingle();
  final presentation = await reminderPresentation(database, row, settings);
  return androidNotificationRegistrationState(
    settings: settings,
    exact: exact,
    title: presentation.title,
    body: presentation.body,
    actionLabels: [
      AndroidNotificationStrings.forSettings(settings).open,
      AndroidNotificationStrings.forSettings(settings).snooze,
      AndroidNotificationStrings.forSettings(settings).dismiss,
    ],
  );
}

Future<void> _insertMapping(
  AppDatabase database, {
  required String generation,
  required int platformId,
  required String state,
  DateTime? scheduledAt,
}) => database
    .into(database.androidNotificationMappings)
    .insert(
      AndroidNotificationMappingsCompanion.insert(
        scheduleId: 'event|event-1|5',
        generation: generation,
        platformId: platformId,
        scheduledAtUtc:
            (scheduledAt ?? DateTime.now().subtract(const Duration(hours: 1)))
                .millisecondsSinceEpoch,
        state: Value(state),
        updatedAtUtc: 0,
      ),
    );

Future<void> _insertDueTodayTask(
  AppDatabase database, {
  DateTime? localDay,
}) async {
  await database
      .into(database.taskLists)
      .insert(
        TaskListsCompanion.insert(
          accountId: 'google:test',
          id: 'list-1',
          title: 'Tasks',
          rawJson: '{}',
          createdLocalAtUtc: '',
          updatedLocalAtUtc: '',
        ),
      );
  // Match the service's configured date, not the host runner's timezone.
  final today = localDay ?? tz.TZDateTime.now(tz.local);
  await database
      .into(database.tasks)
      .insert(
        TasksCompanion.insert(
          accountId: 'google:test',
          taskListId: 'list-1',
          id: 'task-1',
          title: 'Due today',
          dueUtc: Value(
            DateTime(today.year, today.month, today.day, 12).toIso8601String(),
          ),
          rawJson: '{}',
          createdLocalAtUtc: '',
          updatedLocalAtUtc: '',
        ),
      );
}

String _today() {
  final now = tz.TZDateTime.now(tz.local);
  return '${now.year.toString().padLeft(4, '0')}-'
      '${now.month.toString().padLeft(2, '0')}-'
      '${now.day.toString().padLeft(2, '0')}';
}

class _StatefulNotificationPlugin implements AndroidNotificationBackend {
  final Set<int> pendingIds = {};
  final Set<int> activeIds = {};
  final List<int> cancelledIds = [];
  final List<
    ({
      int id,
      String? title,
      String? body,
      AndroidScheduleMode mode,
      tz.TZDateTime date,
      NotificationDetails details,
      String? payload,
    })
  >
  scheduled = [];
  final List<
    ({
      int id,
      String? title,
      String? body,
      NotificationDetails details,
      String? payload,
    })
  >
  shown = [];
  int cancellationFailuresRemaining = 0;
  int cancellationFailuresAfterRemoval = 0;
  final cancellationFailureAttempts = <int>{};
  bool permissionGranted = true;
  Completer<void>? registrationBarrier;
  Completer<void>? showBarrier;
  final registrationStarted = Completer<void>();
  final showStarted = Completer<void>();
  void Function()? beforePendingQuery;
  bool activeQueryFails = false;

  Iterable<int> get scheduledIds => scheduled.map((value) => value.id);

  @override
  Future<bool?> initialize({
    required InitializationSettings settings,
    DidReceiveNotificationResponseCallback? onDidReceiveNotificationResponse,
    DidReceiveBackgroundNotificationResponseCallback?
    onDidReceiveBackgroundNotificationResponse,
  }) async => true;

  @override
  Future<NotificationAppLaunchDetails?>
  getNotificationAppLaunchDetails() async =>
      const NotificationAppLaunchDetails(false);

  @override
  Future<List<PendingNotificationRequest>> pendingNotificationRequests() async {
    beforePendingQuery?.call();
    return [
      for (final id in pendingIds)
        PendingNotificationRequest(id, null, null, null),
    ];
  }

  @override
  Future<List<ActiveNotification>> getActiveNotifications() async {
    if (activeQueryFails) throw StateError('active query unavailable');
    return [for (final id in activeIds) ActiveNotification(id: id)];
  }

  @override
  Future<void> cancel({required int id, String? tag}) async {
    cancelledIds.add(id);
    if (cancellationFailureAttempts.remove(cancelledIds.length)) {
      throw StateError('cancel failed on requested attempt');
    }
    if (cancellationFailuresRemaining > 0) {
      cancellationFailuresRemaining--;
      throw StateError('cancel failed');
    }
    pendingIds.remove(id);
    activeIds.remove(id);
    if (cancellationFailuresAfterRemoval > 0) {
      cancellationFailuresAfterRemoval--;
      throw StateError('interrupted after native cancellation');
    }
  }

  @override
  Future<void> zonedSchedule({
    required int id,
    required tz.TZDateTime scheduledDate,
    required NotificationDetails notificationDetails,
    required AndroidScheduleMode androidScheduleMode,
    String? title,
    String? body,
    String? payload,
    DateTimeComponents? matchDateTimeComponents,
  }) async {
    scheduled.add((
      id: id,
      title: title,
      body: body,
      mode: androidScheduleMode,
      date: scheduledDate,
      details: notificationDetails,
      payload: payload,
    ));
    if (!registrationStarted.isCompleted) {
      registrationStarted.complete();
    }
    await registrationBarrier?.future;
    pendingIds.add(id);
  }

  @override
  Future<void> show({
    required int id,
    String? title,
    String? body,
    required NotificationDetails notificationDetails,
    String? payload,
  }) async {
    shown.add((
      id: id,
      title: title,
      body: body,
      details: notificationDetails,
      payload: payload,
    ));
    if (!showStarted.isCompleted) {
      showStarted.complete();
    }
    await showBarrier?.future;
    activeIds.add(id);
  }

  @override
  Future<bool> requestNotificationPermission() async => permissionGranted;

  @override
  Future<bool> requestExactAlarmPermission() async => true;

  @override
  Future<bool> canScheduleExactly() async => false;
}

class _DiskSettingsStore implements LocalSettingsStore {
  _DiskSettingsStore(this.file);
  final File file;
  @override
  Future<Map<String, Object?>> load() async =>
      (jsonDecode(await file.readAsString()) as Map).cast<String, Object?>();
  @override
  Future<void> save(Map<String, Object?> json) async {
    final temporary = File('${file.path}.tmp');
    await temporary.writeAsString(jsonEncode(json), flush: true);
    await temporary.rename(file.path);
  }
}

class _NativeGates {
  final _tails = <String, Future<void>>{};
  final _leases = <String, Completer<void>>{};
  int _next = 0;
  void Function()? onQueued;
  Future<String> acquire(String key) async {
    final previous = _tails[key];
    final release = Completer<void>();
    final id = 'lease-${_next++}';
    _tails[key] = release.future;
    _leases[id] = release;
    if (previous != null) {
      if (key == '__notifications__') onQueued?.call();
      await previous;
    }
    return id;
  }

  void release(String id) => _leases.remove(id)!.complete();
}

class _PauseIssueLookup extends QueryInterceptor {
  bool armed = false;
  final entered = Completer<void>();
  final release = Completer<void>();
  @override
  Future<List<Map<String, Object?>>> runSelect(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) async {
    final result = await executor.runSelect(statement, args);
    if (armed &&
        statement.contains('notification_issues') &&
        args.contains('sync-failure|google:test') &&
        result.singleOrNull?['native_id'] == null) {
      armed = false;
      entered.complete();
      await release.future;
    }
    return result;
  }
}

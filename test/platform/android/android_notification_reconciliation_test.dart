import 'dart:async';
import 'dart:convert';

import 'package:busymax/src/features/notifications/reminder_presentation.dart';
import 'package:busymax/src/features/notifications/notification_schedule_service.dart';
import 'package:busymax/src/android/android_notifications.dart';
import 'package:busymax/src/app/app_settings.dart';
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const platformChannel = MethodChannel('io.busystack.busymax/android');
  late AppDatabase database;
  late _StatefulNotificationPlugin plugin;
  late AppSettings settings;
  late Map<String, bool> capabilities;

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
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(platformChannel, (call) async {
          if (call.method == 'acquireAccountGate') return 'test-lease';
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

  test('privacy during delayed registration consumes an overdue post without another alert', () async {
    final clock = DateTime.now();
    await _insertReminder(
      database,
      generation: 'privacy-race',
      scheduledAt: clock.subtract(const Duration(minutes: 1)),
    );
    plugin.registrationBarrier = Completer<void>();
    final notifications = service(clock: () => clock);
    await notifications.initialize(timeZoneId: 'Etc/UTC');
    final registering = notifications.reconcile();
    await _until(() => plugin.scheduled.isNotEmpty);
    settings = settings.copyWith(
      notificationDetailLevel: NotificationDetailLevel.private,
    );
    plugin.registrationBarrier!.complete();
    await registering;
    expect(plugin.scheduled, hasLength(1));
    expect(plugin.pendingIds, isEmpty);
    expect(
      (await database.select(database.notificationSchedule).getSingle())
          .sentAtUtc,
      isNotNull,
    );
  });

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
  bool permissionGranted = true;
  Completer<void>? registrationBarrier;
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
    if (cancellationFailuresRemaining > 0) {
      cancellationFailuresRemaining--;
      throw StateError('cancel failed');
    }
    pendingIds.remove(id);
    activeIds.remove(id);
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
  }

  @override
  Future<bool> requestNotificationPermission() async => permissionGranted;

  @override
  Future<bool> requestExactAlarmPermission() async => true;

  @override
  Future<bool> canScheduleExactly() async => false;
}

Future<void> _until(bool Function() condition) async {
  for (var i = 0; i < 200 && !condition(); i++) {
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  expect(condition(), isTrue);
}

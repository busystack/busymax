// Native acceptance driver. It uses a marked, isolated QA database and the
// production schedule/service/backend. It never opens the user's profile.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:busymax/src/app/app_settings.dart';
import 'package:busymax/src/app/app_theme.dart';
import 'package:busymax/src/db/app_database.dart';
import 'package:busymax/src/features/notifications/desktop_notification_service.dart';
import 'package:busymax/src/features/notifications/notification_cancellation_queue.dart';
import 'package:busymax/src/features/notifications/notification_schedule_service.dart';
import 'package:busymax/src/features/notifications/notification_scheduler.dart';
import 'package:busymax/src/platform/linux/linux_notification_backend.dart';
import 'package:busymax/src/platform/linux_window_service.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';

const _profile = String.fromEnvironment('BUSYMAX_NOTIFICATION_QA_PROFILE');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!Platform.isLinux || _profile.isEmpty) {
    throw StateError('An isolated QA profile is required.');
  }
  final directory = Directory(_profile).absolute;
  final marker = File('${directory.path}/notification-qa-profile');
  if (await directory.exists() && !await marker.exists()) {
    throw StateError('Refusing an unmarked profile.');
  }
  await directory.create(recursive: true);
  await marker.writeAsString(
    'BusyMax synthetic native notification acceptance\n',
  );
  final driver = _Driver(directory);
  await driver.start();
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildBusyMaxTheme(
        brightness: Brightness.light,
        accentColor: Colors.orange,
      ),
      home: const Scaffold(
        body: Center(
          child: Text(
            'BusyMax native notification acceptance\nIsolated synthetic profile',
          ),
        ),
      ),
    ),
  );
}

class _Driver {
  _Driver(this.directory);
  final Directory directory;
  late final AppDatabase database;
  late final _NativeRecorder backend;
  late final NotificationScheduler scheduler;
  final cancellations = NotificationCancellationQueue();
  var settings = AppSettings.defaults();
  var offset = Duration.zero;
  final consumed = <String>{};
  bool reading = false;
  DateTime now() => DateTime.now().toUtc().add(offset);

  DesktopNotificationService service() => DesktopNotificationService(
    backend: backend,
    settings: settings,
    locale: settings.locale ?? const Locale('en'),
    cancellationQueue: cancellations,
    now: () => now().toLocal(),
  );

  Future<void> record(
    Map<String, Object?> event,
  ) => File('${directory.path}/events.jsonl').writeAsString(
    '${jsonEncode({'at': DateTime.now().toUtc().toIso8601String(), ...event})}\n',
    mode: FileMode.append,
    flush: true,
  );

  Future<void> start() async {
    database = AppDatabase(NativeDatabase(File('${directory.path}/qa.sqlite')));
    final preferences = File('${directory.path}/settings.json');
    if (await preferences.exists()) {
      settings = AppSettings.fromJson(
        (jsonDecode(await preferences.readAsString()) as Map)
            .cast<String, Object?>(),
      );
    }
    backend = _NativeRecorder(
      FreedesktopNotificationBackend(
        identityFile: File('${directory.path}/native-ids.json'),
      ),
      record,
    );
    await backend.native.probe();
    for (final provider in ['google', 'microsoft']) {
      await database
          .into(database.accounts)
          .insertOnConflictUpdate(
            AccountsCompanion.insert(
              id: 'qa-$provider',
              provider: provider,
              authority: 'https://qa.invalid',
              providerAccountId: 'native-qa',
              credentialKind: 'oauth',
              authState: const Value('signed_in'),
              displayName: const Value('Native QA'),
              createdAtUtc: '',
              updatedAtUtc: '',
            ),
          );
    }
    await database
        .into(database.calendarSources)
        .insertOnConflictUpdate(
          CalendarSourcesCompanion.insert(
            id: 'qa-calendar',
            accountId: 'qa-google',
            provider: 'google',
            providerCalendarId: 'calendar',
            summary: 'Teaching',
            createdAtLocal: 0,
            updatedAtLocal: 0,
          ),
        );
    await database
        .into(database.taskLists)
        .insertOnConflictUpdate(
          TaskListsCompanion.insert(
            accountId: 'qa-microsoft',
            id: 'qa-list',
            title: 'Work',
            rawJson: '{}',
            createdLocalAtUtc: '',
            updatedLocalAtUtc: '',
          ),
        );
    scheduler = NotificationScheduler(
      database: database,
      notifications: service(),
      nowUtc: now,
      onNotificationActivated: (row) async {
        await const LinuxWindowService().showWindow();
        await record({'action': 'open', 'source': row.sourceId});
      },
      onReminderAction: (row, action) async {
        await scheduler.handleReminderAction(row, action);
        if (action != ReminderNotificationAction.open) {
          await record({'action': action.name, 'source': row.sourceId});
        }
      },
    );
    scheduler.start();
    await Directory('${directory.path}/commands').create();
    Timer.periodic(
      const Duration(milliseconds: 250),
      (_) => unawaited(readCommands()),
    );
    await record({'state': 'ready'});
  }

  Future<void> readCommands() async {
    if (reading) return;
    reading = true;
    try {
      final commands =
          Directory('${directory.path}/commands')
              .listSync()
              .whereType<File>()
              .where((file) => file.path.endsWith('.json'))
              .toList()
            ..sort((a, b) => a.path.compareTo(b.path));
      for (final file in commands) {
        if (consumed.contains(file.path)) continue;
        final command =
            jsonDecode(await file.readAsString()) as Map<String, dynamic>;
        consumed.add(file.path);
        await file.rename('${file.path}.done');
        await apply(command);
        await snapshot();
      }
    } finally {
      reading = false;
    }
  }

  Future<void> apply(Map<String, dynamic> command) async {
    switch (command['command']) {
      case 'event':
        final id = command['id'] as String? ?? 'qa-event';
        await database
            .into(database.calendarEvents)
            .insertOnConflictUpdate(
              CalendarEventsCompanion.insert(
                id: id,
                accountId: 'qa-google',
                calendarSourceId: 'qa-calendar',
                provider: 'google',
                providerCalendarId: 'calendar',
                providerEventId: id,
                title: 'Basic French lesson · BusyMax QA',
                location: const Value('Contact: classroom & <lab> · العربية'),
                startDateTime: Value(
                  now().add(const Duration(minutes: 2)).toIso8601String(),
                ),
                endDateTime: Value(
                  now().add(const Duration(hours: 1)).toIso8601String(),
                ),
                remindersJson: const Value(
                  '{"overrides":[{"method":"popup","minutes":5}]}',
                ),
                createdAtLocal: 0,
                updatedAtLocal: 0,
              ),
            );
        await NotificationScheduleService(
          database: database,
          nowUtc: now,
        ).rebuildUpcomingNotifications('qa-google');
      case 'task':
        await database
            .into(database.tasks)
            .insertOnConflictUpdate(
              TasksCompanion.insert(
                accountId: 'qa-microsoft',
                taskListId: 'qa-list',
                id: 'qa-task',
                title: 'Location: QA report & review',
                dueUtc: Value(now().toIso8601String()),
                microsoftDueDateTime: Value(now().toIso8601String()),
                microsoftDueTimeZone: const Value('UTC'),
                microsoftIsReminderOn: const Value(true),
                microsoftReminderDateTime: Value(
                  now().subtract(const Duration(seconds: 5)).toIso8601String(),
                ),
                microsoftReminderTimeZone: const Value('UTC'),
                rawJson: '{}',
                createdLocalAtUtc: '',
                updatedLocalAtUtc: '',
              ),
            );
        await NotificationScheduleService(
          database: database,
          nowUtc: now,
        ).rebuildUpcomingNotifications('qa-microsoft');
      case 'private':
        settings = settings.copyWith(
          notificationDetailLevel: NotificationDetailLevel.private,
        );
        scheduler.updateNotifications(service());
      case 'normal':
        settings = settings.copyWith(
          notificationDetailLevel: NotificationDetailLevel.normal,
        );
        scheduler.updateNotifications(service());
      case 'locale':
        settings = settings.copyWith(localeTag: command['locale'] as String);
        scheduler.updateNotifications(service());
      case 'advance':
        offset += Duration(minutes: command['minutes'] as int);
      case 'quit':
        scheduler.stop();
        await record({'state': 'quit'});
        await backend.close();
        await database.close();
        exit(0);
      case 'snapshot':
        break;
      default:
        throw ArgumentError('Unknown QA command.');
    }
    await File('${directory.path}/settings.json')
        .writeAsString(jsonEncode(settings.toJson()), flush: true);
    await scheduler.checkNow();
  }

  Future<void> snapshot() async {
    await record({
      'schedules': [
        for (final row
            in await database.select(database.notificationSchedule).get())
          {
            'id': row.id,
            'generation': row.generation,
            'sent': row.sentAtUtc,
            'dismissed': row.dismissedAtUtc,
            'snoozedUntil': row.snoozedUntilUtc,
            'expired': row.expiredAtUtc,
          },
      ],
    });
  }
}

class _NativeRecorder
    implements DesktopNotificationBackend, DesktopNotificationIdentitySource {
  _NativeRecorder(this.native, this.record);
  final FreedesktopNotificationBackend native;
  final Future<void> Function(Map<String, Object?>) record;
  @override
  Future<void> notify(
    BusyMaxNotificationRequest request, {
    DesktopNotificationActionHandler? onAction,
  }) async {
    await native.notify(request, onAction: onAction);
    await record({
      'submitted': request.stableId,
      'private': request.private,
      'title': request.title,
      'body': request.body,
    });
  }

  @override
  Future<Set<String>> knownReminderDeliveryIds() =>
      native.knownReminderDeliveryIds();
  @override
  Future<void> cancel(String id) async {
    await native.cancel(id);
    await record({'cancelled': id});
  }

  @override
  Future<void> close() => native.close();
}

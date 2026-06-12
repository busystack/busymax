import 'dart:convert';

import 'package:drift/drift.dart';

import '../calendar_providers/calendar_mutation.dart';
import '../calendar_providers/calendar_provider_capabilities.dart';
import '../calendar_providers/calendar_sync_dto.dart';
import '../calendar_providers/cloud_calendar_client.dart';
import '../db/app_database.dart';
import '../features/calendar/data/calendar_repository.dart';
import '../features/sync/calendar_sync_engine.dart';
import '../features/sync/sync_engine.dart';
import '../google_tasks/api/google_tasks_api_client.dart';
import '../google_tasks/api/google_tasks_api_models.dart';
import '../google_tasks/api/google_tasks_api_surface.dart';
import '../google_tasks/oauth/oauth_models.dart';
import '../google_tasks/oauth/oauth_service.dart';
import '../task_providers/task_provider.dart';

const screenshotFakeGoogleAccountId = 'google:screenshot-google';
const screenshotFakeMicrosoftAccountId = 'microsoft:screenshot-microsoft';

Future<AppDatabase> openScreenshotFakeDataDatabase({DateTime? now}) async {
  final database = AppDatabase.memoryForTests();
  await seedScreenshotFakeData(database, now: now);
  return database;
}

Future<void> seedScreenshotFakeData(
  AppDatabase database, {
  DateTime? now,
}) async {
  final base = _day(now ?? DateTime.now());
  final nowUtc = base.toUtc().toIso8601String();
  final nowLocal = base.millisecondsSinceEpoch;
  final calendarRepository = CalendarRepository(database: database);

  await database.transaction(() async {
    await _seedAccounts(database, nowUtc);
    await _seedTaskLists(database, nowUtc);
    await _seedTasks(database, base, nowUtc);
  });

  for (final source in _calendarSources) {
    await calendarRepository.upsertSource(
      accountId: source.accountId,
      source: CalendarSourceDto(
        provider: source.provider,
        providerCalendarId: source.id,
        summary: source.summary,
        description: source.description,
        primaryCalendar: source.primaryCalendar,
        selected: true,
        hidden: false,
        readOnly: false,
        backgroundColor: source.backgroundColor,
        foregroundColor: '#ffffff',
        timeZone: 'America/Vancouver',
        accessRole: 'owner',
        rawJson: {
          'id': source.id,
          'summary': source.summary,
          'description': source.description,
          'backgroundColor': source.backgroundColor,
          'foregroundColor': '#ffffff',
          'defaultReminders': [
            {'method': 'popup', 'minutes': 10},
          ],
        },
      ),
    );
  }

  for (final event in _calendarEvents(base, nowUtc)) {
    await calendarRepository.upsertEvent(
      accountId: event.accountId,
      event: event.dto,
    );
  }

  await database.batch((batch) {
    batch.deleteWhere(
      database.pendingOps,
      (row) => row.accountId.isIn([
        screenshotFakeGoogleAccountId,
        screenshotFakeMicrosoftAccountId,
      ]),
    );
    batch.insertAllOnConflictUpdate(database.calendarColors, [
      CalendarColorsCompanion.insert(
        provider: TaskProvider.google.storageValue,
        colorType: 'calendar',
        colorId: 'screenshot-blue',
        background: '#1a73e8',
        foreground: const Value('#ffffff'),
        rawJson: const Value('{}'),
      ),
      CalendarColorsCompanion.insert(
        provider: TaskProvider.microsoft.storageValue,
        colorType: 'calendar',
        colorId: 'screenshot-purple',
        background: '#7b1fa2',
        foreground: const Value('#ffffff'),
        rawJson: const Value('{}'),
      ),
    ]);
  });

  await database
      .into(database.notificationSchedule)
      .insertOnConflictUpdate(
        NotificationScheduleCompanion.insert(
          id: 'screenshot-reminder',
          accountId: screenshotFakeMicrosoftAccountId,
          sourceType: 'task',
          sourceId: 'ms-task-my-day-1',
          scheduledAtUtc: base
              .add(const Duration(hours: 8, minutes: 45))
              .toUtc()
              .millisecondsSinceEpoch,
          title: 'Review launch notes',
          body: const Value('Screenshot demo reminder'),
          createdAtLocal: nowLocal,
          updatedAtLocal: nowLocal,
        ),
      );
}

SyncEngine screenshotNoOpSyncEngine({
  required AppDatabase database,
  required String accountId,
}) {
  return _ScreenshotNoOpSyncEngine(database: database, accountId: accountId);
}

CalendarSyncEngine screenshotNoOpCalendarSyncEngine({
  required AppDatabase database,
  required String accountId,
  required BusyProvider provider,
}) {
  return _ScreenshotNoOpCalendarSyncEngine(
    database: database,
    accountId: accountId,
    provider: provider,
  );
}

OAuthGateway screenshotFakeOAuthGateway() {
  return const _ScreenshotFakeOAuthGateway();
}

Future<void> _seedAccounts(AppDatabase database, String nowUtc) async {
  await database
      .into(database.accounts)
      .insertOnConflictUpdate(
        AccountsCompanion.insert(
          id: screenshotFakeGoogleAccountId,
          provider: Value(TaskProvider.google.storageValue),
          providerAccountId: const Value('fake-google-user'),
          displayName: const Value('Alex Rivera'),
          email: const Value('alex.rivera@example.com'),
          providerMetadataJson: Value(
            _json({'picture': null, 'source': 'screenshot-fake-data'}),
          ),
          grantedScopes: const Value(
            'https://www.googleapis.com/auth/tasks '
            'https://www.googleapis.com/auth/calendar',
          ),
          authState: const Value('signed_in'),
          createdAtUtc: nowUtc,
          updatedAtUtc: nowUtc,
        ),
      );
  await database
      .into(database.accounts)
      .insertOnConflictUpdate(
        AccountsCompanion.insert(
          id: screenshotFakeMicrosoftAccountId,
          provider: Value(TaskProvider.microsoft.storageValue),
          providerAccountId: const Value('fake-microsoft-user'),
          displayName: const Value('Jordan Lee'),
          email: const Value('jordan.lee@example.com'),
          tenantId: const Value('fake-tenant'),
          providerMetadataJson: Value(
            _json({
              'userPrincipalName': 'jordan.lee@example.com',
              'source': 'screenshot-fake-data',
            }),
          ),
          grantedScopes: const Value(
            'https://graph.microsoft.com/User.Read '
            'https://graph.microsoft.com/Tasks.ReadWrite '
            'https://graph.microsoft.com/Calendars.ReadWrite',
          ),
          authState: const Value('signed_in'),
          createdAtUtc: nowUtc,
          updatedAtUtc: nowUtc,
        ),
      );
}

Future<void> _seedTaskLists(AppDatabase database, String nowUtc) async {
  for (final list in _taskLists) {
    await database.taskListsDao.upsertTaskList(
      TaskListsCompanion.insert(
        accountId: list.accountId,
        id: list.id,
        kind: const Value('tasks#taskList'),
        etag: Value('"fake-${list.id}"'),
        title: list.title,
        updatedUtc: Value(nowUtc),
        rawJson: _json({
          'id': list.id,
          'title': list.title,
          if (list.providerListKind != null)
            'wellknownListName': list.providerListKind,
          'isOwner': true,
          'isShared': false,
        }),
        providerListKind: Value(list.providerListKind),
        isOwner: const Value(true),
        isShared: const Value(false),
        providerMetadataJson: Value(
          _json({
            if (list.providerListKind != null)
              'wellknownListName': list.providerListKind,
            'source': 'screenshot-fake-data',
          }),
        ),
        lastSyncedAtUtc: Value(nowUtc),
        createdLocalAtUtc: nowUtc,
        updatedLocalAtUtc: nowUtc,
      ),
    );
  }
}

Future<void> _seedTasks(
  AppDatabase database,
  DateTime base,
  String nowUtc,
) async {
  for (final task in _tasks(base)) {
    final completed = task.completed
        ? base.subtract(const Duration(days: 1))
        : null;
    await database.tasksDao.upsertTask(
      TasksCompanion.insert(
        accountId: task.accountId,
        taskListId: task.taskListId,
        id: task.id,
        kind: const Value('tasks#task'),
        etag: Value('"fake-${task.id}"'),
        title: task.title,
        updatedUtc: Value(nowUtc),
        parent: Value(task.parentId),
        position: Value(task.position),
        notes: Value(task.notes),
        status: Value(task.completed ? 'completed' : 'needsAction'),
        dueUtc: Value(task.due == null ? null : _date(task.due!)),
        completedUtc: Value(completed?.toUtc().toIso8601String()),
        providerStatus: Value(task.providerStatus),
        bodyContent: Value(task.bodyContent),
        bodyContentType: Value(task.bodyContent == null ? null : 'text'),
        microsoftDueDateTime: Value(task.microsoftDueDateTime),
        microsoftDueTimeZone: Value(task.microsoftTimeZone),
        microsoftStartDateTime: Value(task.microsoftStartDateTime),
        microsoftStartTimeZone: Value(task.microsoftTimeZone),
        microsoftReminderDateTime: Value(task.microsoftReminderDateTime),
        microsoftReminderTimeZone: Value(task.microsoftTimeZone),
        microsoftIsReminderOn: Value(task.microsoftReminderDateTime != null),
        microsoftCompletedDateTime: Value(completed?.toIso8601String()),
        microsoftCompletedTimeZone: Value(
          completed == null ? null : 'America/Vancouver',
        ),
        importance: Value(task.importance),
        categoriesJson: Value(
          task.categories.isEmpty ? null : jsonEncode(task.categories),
        ),
        rawJson: _json(task.rawJson),
        deleted: const Value(false),
        hidden: const Value(false),
        webViewLink: const Value('https://example.com/busymax-demo-task'),
        lastSyncedAtUtc: Value(nowUtc),
        createdLocalAtUtc: nowUtc,
        updatedLocalAtUtc: nowUtc,
      ),
    );
  }
}

List<_CalendarEventSeed> _calendarEvents(DateTime base, String nowUtc) {
  return [
    _CalendarEventSeed.timed(
      accountId: screenshotFakeGoogleAccountId,
      provider: TaskProvider.google,
      calendarId: 'g-work',
      eventId: 'g-work-standup',
      title: 'Team standup',
      day: base,
      hour: 9,
      minute: 15,
      duration: const Duration(minutes: 30),
      location: 'Meeting room 2A',
      description: 'Daily project check-in with the core team.',
      colorHex: '#1a73e8',
      nowUtc: nowUtc,
    ),
    _CalendarEventSeed.timed(
      accountId: screenshotFakeGoogleAccountId,
      provider: TaskProvider.google,
      calendarId: 'g-work',
      eventId: 'g-work-planning',
      title: 'Product planning',
      day: base,
      hour: 11,
      duration: const Duration(minutes: 75),
      location: 'Video call',
      description: 'Review roadmap items and launch sequencing.',
      colorHex: '#1a73e8',
      nowUtc: nowUtc,
    ),
    _CalendarEventSeed.timed(
      accountId: screenshotFakeMicrosoftAccountId,
      provider: TaskProvider.microsoft,
      calendarId: 'm-projects',
      eventId: 'm-projects-review',
      title: 'Design review',
      day: base,
      hour: 14,
      duration: const Duration(minutes: 60),
      location: 'Studio room',
      description: 'Finalize visual treatment for screenshot assets.',
      colorHex: '#7b1fa2',
      categories: const ['Launch'],
      nowUtc: nowUtc,
    ),
    _CalendarEventSeed.timed(
      accountId: screenshotFakeMicrosoftAccountId,
      provider: TaskProvider.microsoft,
      calendarId: 'm-projects',
      eventId: 'm-projects-focus',
      title: 'Focus block',
      day: base,
      hour: 16,
      duration: const Duration(minutes: 90),
      location: 'Desk',
      description: 'Quiet work on demo polish.',
      colorHex: '#7b1fa2',
      categories: const ['Focus'],
      nowUtc: nowUtc,
    ),
    _CalendarEventSeed.allDay(
      accountId: screenshotFakeGoogleAccountId,
      provider: TaskProvider.google,
      calendarId: 'g-family',
      eventId: 'g-family-school',
      title: 'School planning day',
      day: base.add(const Duration(days: 1)),
      colorHex: '#0b8043',
      nowUtc: nowUtc,
    ),
    _CalendarEventSeed.timed(
      accountId: screenshotFakeMicrosoftAccountId,
      provider: TaskProvider.microsoft,
      calendarId: 'm-travel',
      eventId: 'm-travel-train',
      title: 'Train to client visit',
      day: base.add(const Duration(days: 2)),
      hour: 8,
      minute: 30,
      duration: const Duration(minutes: 45),
      location: 'Central Station',
      description: 'Buffer time included before the workshop.',
      colorHex: '#d97706',
      categories: const ['Travel'],
      nowUtc: nowUtc,
    ),
    _CalendarEventSeed.timed(
      accountId: screenshotFakeGoogleAccountId,
      provider: TaskProvider.google,
      calendarId: 'g-work',
      eventId: 'g-work-retro',
      title: 'Sprint retrospective',
      day: base.add(const Duration(days: 4)),
      hour: 10,
      duration: const Duration(minutes: 60),
      location: 'Meeting room 1B',
      description: 'Capture wins, risks, and follow-up owners.',
      colorHex: '#1a73e8',
      nowUtc: nowUtc,
    ),
  ];
}

List<_TaskSeed> _tasks(DateTime base) {
  final today = base;
  final tomorrow = base.add(const Duration(days: 1));
  final nextWeek = base.add(const Duration(days: 6));

  return [
    _TaskSeed.google(
      accountId: screenshotFakeGoogleAccountId,
      taskListId: 'g-inbox',
      id: 'g-task-inbox-1',
      title: 'Draft screenshot captions',
      due: today,
      notes: 'Use neutral examples and no customer names.',
      position: '0001',
    ),
    _TaskSeed.google(
      accountId: screenshotFakeGoogleAccountId,
      taskListId: 'g-launch',
      id: 'g-task-launch-1',
      title: 'Prepare launch checklist',
      due: tomorrow,
      notes: 'Confirm calendar, tasks, and settings views are covered.',
      position: '0001',
    ),
    _TaskSeed.google(
      accountId: screenshotFakeGoogleAccountId,
      taskListId: 'g-launch',
      id: 'g-task-launch-1a',
      title: 'Export calendar view',
      due: tomorrow,
      notes: 'Capture week view with both providers visible.',
      parentId: 'g-task-launch-1',
      position: '0001.1',
    ),
    _TaskSeed.google(
      accountId: screenshotFakeGoogleAccountId,
      taskListId: 'g-personal',
      id: 'g-task-personal-1',
      title: 'Book weekend groceries',
      due: base.add(const Duration(days: 2)),
      notes: 'Example personal task for screenshot balance.',
      position: '0001',
    ),
    _TaskSeed.google(
      accountId: screenshotFakeGoogleAccountId,
      taskListId: 'g-inbox',
      id: 'g-task-inbox-done',
      title: 'Archive old demo notes',
      completed: true,
      notes: 'Completed item to show progress state.',
      position: '0009',
    ),
    _TaskSeed.microsoft(
      accountId: screenshotFakeMicrosoftAccountId,
      taskListId: 'm-my-day',
      id: 'ms-task-my-day-1',
      title: 'Review launch notes',
      start: today.add(const Duration(hours: 8)),
      due: today.add(const Duration(hours: 17)),
      reminder: today.add(const Duration(hours: 8, minutes: 45)),
      bodyContent: 'Check copy, assets, and the final screenshot sequence.',
      categories: const ['Launch'],
      importance: 'high',
      position: '0001',
    ),
    _TaskSeed.microsoft(
      accountId: screenshotFakeMicrosoftAccountId,
      taskListId: 'm-client',
      id: 'ms-task-client-1',
      title: 'Send client agenda',
      start: tomorrow.add(const Duration(hours: 10)),
      due: tomorrow.add(const Duration(hours: 12)),
      reminder: tomorrow.add(const Duration(hours: 9, minutes: 30)),
      bodyContent: 'Share agenda and prep notes before the workshop.',
      categories: const ['Client'],
      importance: 'normal',
      position: '0002',
    ),
    _TaskSeed.microsoft(
      accountId: screenshotFakeMicrosoftAccountId,
      taskListId: 'm-client',
      id: 'ms-task-client-2',
      title: 'Clean sample dataset',
      due: nextWeek.add(const Duration(hours: 15)),
      bodyContent: 'Replace sensitive labels with neutral placeholder values.',
      categories: const ['Data'],
      importance: 'high',
      position: '0003',
    ),
    _TaskSeed.microsoft(
      accountId: screenshotFakeMicrosoftAccountId,
      taskListId: 'm-home',
      id: 'ms-task-home-1',
      title: 'Plan dinner',
      bodyContent: 'No-date task for the agenda backlog.',
      categories: const ['Personal'],
      importance: 'low',
      position: '0001',
    ),
  ];
}

const _taskLists = [
  _TaskListSeed(
    accountId: screenshotFakeGoogleAccountId,
    id: 'g-inbox',
    title: 'Inbox',
  ),
  _TaskListSeed(
    accountId: screenshotFakeGoogleAccountId,
    id: 'g-launch',
    title: 'Launch Plan',
  ),
  _TaskListSeed(
    accountId: screenshotFakeGoogleAccountId,
    id: 'g-personal',
    title: 'Personal',
  ),
  _TaskListSeed(
    accountId: screenshotFakeMicrosoftAccountId,
    id: 'm-my-day',
    title: 'My Day',
    providerListKind: 'defaultList',
  ),
  _TaskListSeed(
    accountId: screenshotFakeMicrosoftAccountId,
    id: 'm-client',
    title: 'Client Work',
  ),
  _TaskListSeed(
    accountId: screenshotFakeMicrosoftAccountId,
    id: 'm-home',
    title: 'Home',
  ),
];

const _calendarSources = [
  _CalendarSourceSeed(
    accountId: screenshotFakeGoogleAccountId,
    provider: TaskProvider.google,
    id: 'g-work',
    summary: 'Work',
    description: 'Fake Google work calendar',
    backgroundColor: '#1a73e8',
    primaryCalendar: true,
  ),
  _CalendarSourceSeed(
    accountId: screenshotFakeGoogleAccountId,
    provider: TaskProvider.google,
    id: 'g-family',
    summary: 'Family',
    description: 'Fake Google family calendar',
    backgroundColor: '#0b8043',
  ),
  _CalendarSourceSeed(
    accountId: screenshotFakeMicrosoftAccountId,
    provider: TaskProvider.microsoft,
    id: 'm-projects',
    summary: 'Projects',
    description: 'Fake Microsoft project calendar',
    backgroundColor: '#7b1fa2',
    primaryCalendar: true,
  ),
  _CalendarSourceSeed(
    accountId: screenshotFakeMicrosoftAccountId,
    provider: TaskProvider.microsoft,
    id: 'm-travel',
    summary: 'Travel',
    description: 'Fake Microsoft travel calendar',
    backgroundColor: '#d97706',
  ),
];

class _TaskListSeed {
  const _TaskListSeed({
    required this.accountId,
    required this.id,
    required this.title,
    this.providerListKind,
  });

  final String accountId;
  final String id;
  final String title;
  final String? providerListKind;
}

class _TaskSeed {
  const _TaskSeed._({
    required this.accountId,
    required this.taskListId,
    required this.id,
    required this.title,
    required this.position,
    this.due,
    this.notes,
    this.parentId,
    this.completed = false,
    this.providerStatus,
    this.bodyContent,
    this.microsoftStartDateTime,
    this.microsoftDueDateTime,
    this.microsoftReminderDateTime,
    this.microsoftTimeZone,
    this.categories = const [],
    this.importance,
  });

  factory _TaskSeed.google({
    required String accountId,
    required String taskListId,
    required String id,
    required String title,
    required String position,
    DateTime? due,
    String? notes,
    String? parentId,
    bool completed = false,
  }) {
    return _TaskSeed._(
      accountId: accountId,
      taskListId: taskListId,
      id: id,
      title: title,
      due: due,
      notes: notes,
      parentId: parentId,
      completed: completed,
      providerStatus: completed ? 'completed' : 'needsAction',
      position: position,
    );
  }

  factory _TaskSeed.microsoft({
    required String accountId,
    required String taskListId,
    required String id,
    required String title,
    required String position,
    DateTime? start,
    DateTime? due,
    DateTime? reminder,
    String? bodyContent,
    List<String> categories = const [],
    String? importance,
  }) {
    return _TaskSeed._(
      accountId: accountId,
      taskListId: taskListId,
      id: id,
      title: title,
      due: due,
      providerStatus: 'notStarted',
      bodyContent: bodyContent,
      microsoftStartDateTime: start?.toIso8601String(),
      microsoftDueDateTime: due?.toIso8601String(),
      microsoftReminderDateTime: reminder?.toIso8601String(),
      microsoftTimeZone: 'America/Vancouver',
      categories: categories,
      importance: importance,
      position: position,
    );
  }

  final String accountId;
  final String taskListId;
  final String id;
  final String title;
  final String position;
  final DateTime? due;
  final String? notes;
  final String? parentId;
  final bool completed;
  final String? providerStatus;
  final String? bodyContent;
  final String? microsoftStartDateTime;
  final String? microsoftDueDateTime;
  final String? microsoftReminderDateTime;
  final String? microsoftTimeZone;
  final List<String> categories;
  final String? importance;
  Map<String, Object?> get rawJson {
    return {
      'id': id,
      'title': title,
      'status': providerStatus,
      if (notes != null) 'notes': notes,
      if (due != null) 'due': _date(due!),
      if (bodyContent != null)
        'body': {'contentType': 'text', 'content': bodyContent},
      if (microsoftStartDateTime != null)
        'startDateTime': {
          'dateTime': microsoftStartDateTime,
          'timeZone': microsoftTimeZone,
        },
      if (microsoftDueDateTime != null)
        'dueDateTime': {
          'dateTime': microsoftDueDateTime,
          'timeZone': microsoftTimeZone,
        },
      if (microsoftReminderDateTime != null)
        'reminderDateTime': {
          'dateTime': microsoftReminderDateTime,
          'timeZone': microsoftTimeZone,
        },
      if (microsoftReminderDateTime != null) 'isReminderOn': true,
      if (categories.isNotEmpty) 'categories': categories,
      if (importance != null) 'importance': importance,
    };
  }
}

class _CalendarSourceSeed {
  const _CalendarSourceSeed({
    required this.accountId,
    required this.provider,
    required this.id,
    required this.summary,
    required this.description,
    required this.backgroundColor,
    this.primaryCalendar = false,
  });

  final String accountId;
  final BusyProvider provider;
  final String id;
  final String summary;
  final String description;
  final String backgroundColor;
  final bool primaryCalendar;
}

class _CalendarEventSeed {
  _CalendarEventSeed._({
    required this.accountId,
    required this.provider,
    required this.calendarId,
    required this.eventId,
    required this.title,
    required this.allDay,
    required this.start,
    required this.end,
    required this.description,
    required this.location,
    required this.colorHex,
    required this.categories,
    required this.nowUtc,
  });

  factory _CalendarEventSeed.timed({
    required String accountId,
    required BusyProvider provider,
    required String calendarId,
    required String eventId,
    required String title,
    required DateTime day,
    required int hour,
    required Duration duration,
    required String colorHex,
    required String nowUtc,
    int minute = 0,
    String? description,
    String? location,
    List<String> categories = const [],
  }) {
    final start = DateTime(day.year, day.month, day.day, hour, minute);
    return _CalendarEventSeed._(
      accountId: accountId,
      provider: provider,
      calendarId: calendarId,
      eventId: eventId,
      title: title,
      allDay: false,
      start: start,
      end: start.add(duration),
      description: description,
      location: location,
      colorHex: colorHex,
      categories: categories,
      nowUtc: nowUtc,
    );
  }

  factory _CalendarEventSeed.allDay({
    required String accountId,
    required BusyProvider provider,
    required String calendarId,
    required String eventId,
    required String title,
    required DateTime day,
    required String colorHex,
    required String nowUtc,
  }) {
    return _CalendarEventSeed._(
      accountId: accountId,
      provider: provider,
      calendarId: calendarId,
      eventId: eventId,
      title: title,
      allDay: true,
      start: _day(day),
      end: _day(day).add(const Duration(days: 1)),
      description: null,
      location: null,
      colorHex: colorHex,
      categories: const [],
      nowUtc: nowUtc,
    );
  }

  final String accountId;
  final BusyProvider provider;
  final String calendarId;
  final String eventId;
  final String title;
  final bool allDay;
  final DateTime start;
  final DateTime end;
  final String? description;
  final String? location;
  final String colorHex;
  final List<String> categories;
  final String nowUtc;

  CalendarEventDto get dto {
    return CalendarEventDto(
      provider: provider,
      providerCalendarId: calendarId,
      providerEventId: eventId,
      etagOrChangeKey: '"fake-$eventId"',
      status: 'confirmed',
      title: title,
      description: description,
      location: location,
      allDay: allDay,
      startDate: allDay ? _date(start) : null,
      startDateTime: allDay ? null : start.toIso8601String(),
      startTimeZone: allDay ? null : 'America/Vancouver',
      endDate: allDay ? _date(end) : null,
      endDateTime: allDay ? null : end.toIso8601String(),
      endTimeZone: allDay ? null : 'America/Vancouver',
      remindersJson: provider == TaskProvider.microsoft
          ? {'isReminderOn': true, 'reminderMinutesBeforeStart': 15}
          : {
              'useDefault': false,
              'overrides': [
                {'method': 'popup', 'minutes': 10},
              ],
            },
      attendeesJson: [
        {
          'email': 'teammate.one@example.com',
          'displayName': 'Teammate One',
          'responseStatus': 'accepted',
        },
        {
          'email': 'teammate.two@example.com',
          'displayName': 'Teammate Two',
          'responseStatus': 'needsAction',
        },
      ],
      categoriesJson: categories.isEmpty ? null : categories,
      organizerJson: {
        'email': accountId == screenshotFakeGoogleAccountId
            ? 'alex.rivera@example.com'
            : 'jordan.lee@example.com',
        'displayName': accountId == screenshotFakeGoogleAccountId
            ? 'Alex Rivera'
            : 'Jordan Lee',
      },
      creatorJson: {
        'email': 'busymax-demo@example.com',
        'displayName': 'BusyMax Demo',
      },
      colorHex: colorHex,
      transparencyOrShowAs: 'busy',
      eventType: 'default',
      webLink: 'https://example.com/busymax-demo-event',
      createdAtServer: nowUtc,
      updatedAtServer: nowUtc,
      rawJson: {
        'id': eventId,
        'subject': title,
        'summary': title,
        'bodyPreview': description,
        if (provider == TaskProvider.microsoft)
          'body': {'contentType': 'text', 'content': description},
      },
    );
  }
}

class _ScreenshotNoOpSyncEngine extends SyncEngine {
  _ScreenshotNoOpSyncEngine({required super.database, required super.accountId})
    : super(apiClient: const _ScreenshotNoOpTasksClient());

  @override
  Future<void> fullSync() async {}

  @override
  Future<void> incrementalSync() async {}
}

class _ScreenshotFakeOAuthGateway implements OAuthGateway {
  const _ScreenshotFakeOAuthGateway();

  @override
  Future<String?> get activeAccountId async => null;

  @override
  Future<void> cancelSignIn() async {}

  @override
  Future<void> clearLocalSession({String? accountId}) async {}

  @override
  Future<GoogleUserInfo?> fetchUserInfo(OAuthTokenSet tokenSet) async {
    return const GoogleUserInfo(
      subject: 'fake-google-user',
      name: 'Alex Rivera',
      email: 'alex.rivera@example.com',
      rawJson: {
        'sub': 'fake-google-user',
        'name': 'Alex Rivera',
        'email': 'alex.rivera@example.com',
      },
    );
  }

  @override
  Future<OAuthTokenSet?> readActiveTokenSet() async => null;

  @override
  Future<void> revokeAndSignOut() async {}

  @override
  Future<void> revokeAndSignOutAccount(String accountId) async {}

  @override
  Future<OAuthTokenSet> refreshActiveToken() async => _fakeGoogleTokenSet();

  @override
  Future<OAuthSignInResult> signIn({String? loginHint}) async {
    return OAuthSignInResult(
      accountId: screenshotFakeGoogleAccountId,
      tokenSet: _fakeGoogleTokenSet(),
    );
  }

  @override
  Future<void> signOut() async {}

  @override
  Future<void> signOutAccount(String accountId) async {}

  OAuthTokenSet _fakeGoogleTokenSet() {
    return OAuthTokenSet(
      accessToken: 'fake-access-token',
      refreshToken: 'fake-refresh-token',
      expiresAtUtc: DateTime.utc(2099),
      tokenType: 'Bearer',
      scopes: const {googleTasksReadWriteScope, googleCalendarReadWriteScope},
    );
  }
}

class _ScreenshotNoOpCalendarSyncEngine extends CalendarSyncEngine {
  _ScreenshotNoOpCalendarSyncEngine({
    required super.database,
    required super.accountId,
    required BusyProvider provider,
  }) : super(client: _ScreenshotNoOpCalendarClient(provider));

  @override
  Future<void> fullSync() async {}

  @override
  Future<void> incrementalSync() async {}
}

class _ScreenshotNoOpTasksClient implements GoogleTasksApiClient {
  const _ScreenshotNoOpTasksClient();

  @override
  Future<void> clearCompletedTasks(String taskListId) async {}

  @override
  Future<TaskDto> createTask({
    required String taskListId,
    String? parentTaskId,
    String? previousSiblingTaskId,
    required TaskCreate create,
  }) async {
    return _taskDto('fake-created-task', create.fields['title']?.toString());
  }

  @override
  Future<TaskListDto> createTaskList({required String title}) async {
    return _taskListDto('fake-created-list', title);
  }

  @override
  Future<void> deleteTask({
    required String taskListId,
    required String taskId,
  }) async {}

  @override
  Future<void> deleteTaskList(String taskListId) async {}

  @override
  Future<TaskDto> getTask({
    required String taskListId,
    required String taskId,
  }) async {
    return _taskDto(taskId, 'Fake task');
  }

  @override
  Future<TaskListDto> getTaskList(String taskListId) async {
    return _taskListDto(taskListId, 'Fake list');
  }

  @override
  Future<TaskListsPageDto> listTaskListsPage({
    int maxResults = 1000,
    String? pageToken,
  }) async {
    return const TaskListsPageDto(items: [], rawJson: {'items': []});
  }

  @override
  Future<TasksPageDto> listTasksPage({
    required String taskListId,
    DateTime? completedMax,
    DateTime? completedMin,
    DateTime? dueMax,
    DateTime? dueMin,
    int maxResults = 100,
    String? pageToken,
    bool showCompleted = true,
    bool showDeleted = false,
    bool showHidden = false,
    DateTime? updatedMin,
    bool showAssigned = false,
  }) async {
    return const TasksPageDto(items: [], rawJson: {'items': []});
  }

  @override
  Future<TaskDto> moveTask({
    required String sourceTaskListId,
    required String taskId,
    String? parentTaskId,
    String? previousSiblingTaskId,
    String? destinationTaskListId,
  }) async {
    return _taskDto(taskId, 'Fake task');
  }

  @override
  Future<TaskDto> patchTask({
    required String taskListId,
    required String taskId,
    required TaskPatch patch,
  }) async {
    return _taskDto(taskId, patch.fields['title']?.toString());
  }

  @override
  Future<TaskListDto> patchTaskList(
    String taskListId,
    TaskListPatch patch,
  ) async {
    return _taskListDto(taskListId, patch.fields['title']?.toString());
  }

  @override
  Future<TaskDto> updateTask({
    required String taskListId,
    required String taskId,
    required TaskPut replacement,
  }) async {
    return _taskDto(taskId, replacement.fields['title']?.toString());
  }

  @override
  Future<TaskListDto> updateTaskList(
    String taskListId,
    TaskListPut replacement,
  ) async {
    return _taskListDto(taskListId, replacement.fields['title']?.toString());
  }

  TaskListDto _taskListDto(String id, String? title) {
    final raw = {'id': id, 'title': title ?? 'Fake list'};
    return TaskListDto(id: id, title: title ?? 'Fake list', rawJson: raw);
  }

  TaskDto _taskDto(String id, String? title) {
    final raw = {
      'id': id,
      'title': title ?? 'Fake task',
      'status': 'needsAction',
    };
    return TaskDto(
      id: id,
      title: title ?? 'Fake task',
      status: 'needsAction',
      rawJson: raw,
    );
  }
}

class _ScreenshotNoOpCalendarClient implements CloudCalendarClient {
  const _ScreenshotNoOpCalendarClient(this.provider);

  @override
  final BusyProvider provider;

  @override
  CalendarProviderCapabilities get capabilities {
    return provider == TaskProvider.microsoft
        ? microsoftCalendarProviderCapabilities
        : googleCalendarProviderCapabilities;
  }

  @override
  Future<CalendarSourceDto> createCalendar(CalendarMutation mutation) async {
    return CalendarSourceDto(
      provider: provider,
      providerCalendarId: 'fake-created-calendar',
      summary: mutation.summary ?? 'Fake calendar',
    );
  }

  @override
  Future<CalendarEventDto> createEvent({
    required String calendarId,
    required CalendarEventMutation mutation,
  }) async {
    return _event(calendarId, 'fake-created-event', mutation.title);
  }

  @override
  Future<void> deleteCalendar(String calendarId) async {}

  @override
  Future<void> deleteEvent({
    required String calendarId,
    required String eventId,
  }) async {}

  @override
  Future<List<BusySlotDto>> freeBusy({
    required List<String> calendarIds,
    required DateTime rangeStart,
    required DateTime rangeEnd,
  }) async {
    return const [];
  }

  @override
  Future<CalendarEventDto> getEvent({
    required String calendarId,
    required String eventId,
  }) async {
    return _event(calendarId, eventId, 'Fake event');
  }

  @override
  Future<List<CalendarSourceDto>> listCalendars() async {
    return const [];
  }

  @override
  Future<List<CalendarEventDto>> listEventInstances({
    required String calendarId,
    required String recurringEventId,
    required DateTime rangeStart,
    required DateTime rangeEnd,
  }) async {
    return const [];
  }

  @override
  Future<List<CalendarEventDto>> listEvents({
    required String calendarId,
    required DateTime rangeStart,
    required DateTime rangeEnd,
    String? pageTokenOrUrl,
  }) async {
    return const [];
  }

  @override
  Future<CalendarSyncPageDto> syncEvents({
    required String calendarId,
    required DateTime rangeStart,
    required DateTime rangeEnd,
    String? syncTokenOrDeltaLink,
  }) async {
    return const CalendarSyncPageDto(events: []);
  }

  @override
  Future<CalendarSourceDto> updateCalendar(
    String calendarId,
    CalendarMutation mutation,
  ) async {
    return CalendarSourceDto(
      provider: provider,
      providerCalendarId: calendarId,
      summary: mutation.summary ?? 'Fake calendar',
    );
  }

  @override
  Future<CalendarEventDto> updateEvent({
    required String calendarId,
    required String eventId,
    required CalendarEventMutation mutation,
  }) async {
    return _event(calendarId, eventId, mutation.title);
  }

  CalendarEventDto _event(String calendarId, String eventId, String? title) {
    return CalendarEventDto(
      provider: provider,
      providerCalendarId: calendarId,
      providerEventId: eventId,
      title: title ?? 'Fake event',
    );
  }
}

DateTime _day(DateTime value) => DateTime(value.year, value.month, value.day);

String _date(DateTime value) {
  return [
    value.year.toString().padLeft(4, '0'),
    value.month.toString().padLeft(2, '0'),
    value.day.toString().padLeft(2, '0'),
  ].join('-');
}

String _json(Object? value) => jsonEncode(value);

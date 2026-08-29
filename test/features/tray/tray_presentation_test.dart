import 'package:busymax/src/app/app_settings.dart';
import 'package:busymax/src/core/secrets/secret_store.dart';
import 'package:busymax/src/features/accounts/data/accounts_repository.dart';
import 'package:busymax/src/features/calendar/data/calendar_repository.dart';
import 'package:busymax/src/features/connectivity/network_connectivity_service.dart';
import 'package:busymax/src/features/task_lists/data/task_lists_repository.dart';
import 'package:busymax/src/features/tray/data/tray_presentation_service.dart';
import 'package:busymax/src/features/tray/domain/tray_presentation.dart';
import 'package:busymax/src/features/tray/domain/tray_presentation_formatter.dart';
import 'package:busymax/src/providers/busy_provider.dart';
import 'package:busymax/src/schedule/schedule_filters.dart';
import 'package:busymax/src/schedule/schedule_item.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 8, 29, 10);

  test('projects all-day, ongoing, later, and missing-end events', () {
    final presentation = _project(
      now: now,
      scheduleItems: [
        _event('all-day', start: DateTime(2026, 8, 29), allDay: true),
        _event(
          'ended',
          start: DateTime(2026, 8, 29, 8),
          end: DateTime(2026, 8, 29, 9),
        ),
        _event(
          'ongoing',
          start: DateTime(2026, 8, 29, 9, 30),
          end: DateTime(2026, 8, 29, 10, 30),
        ),
        _event('missing-end-past', start: DateTime(2026, 8, 29, 9, 45)),
        _event('later', start: DateTime(2026, 8, 29, 11)),
        _event('missing-end-future', start: DateTime(2026, 8, 29, 12)),
      ],
    );

    expect(presentation.events.map((event) => event.eventId), [
      'all-day',
      'ongoing',
      'later',
    ]);
  });

  test('preserves schedule ordering and limits event rows to three', () {
    final presentation = _project(
      now: now,
      scheduleItems: [
        _event('z-first', start: DateTime(2026, 8, 29, 10, 5)),
        _event('a-second', start: DateTime(2026, 8, 29, 10, 10)),
        _event('third', start: DateTime(2026, 8, 29, 10, 15)),
        _event('fourth', start: DateTime(2026, 8, 29, 10, 20)),
      ],
    );

    expect(presentation.events.map((event) => event.eventId), [
      'z-first',
      'a-second',
      'third',
    ]);
  });

  test('hidden and deselected calendars are excluded defensively', () {
    final presentation = _project(
      now: now,
      calendarSources: [
        _source(id: 'visible'),
        _source(id: 'hidden', hidden: true),
        _source(id: 'deselected', selected: false),
      ],
      scheduleItems: [
        _event('visible-event', sourceId: 'visible', start: now),
        _event('hidden-event', sourceId: 'hidden', start: now),
        _event('deselected-event', sourceId: 'deselected', start: now),
      ],
    );

    expect(presentation.events.single.eventId, 'visible-event');
  });

  test('task summary respects visibility, completion, and no-date state', () {
    const visibleKey = ScheduleTaskListKey(
      accountId: 'account',
      taskListId: 'visible-list',
    );
    final presentation = _project(
      now: now,
      taskLists: const [
        TaskListEntity(
          accountId: 'account',
          id: 'visible-list',
          title: 'Visible',
          localDirty: false,
          pendingDelete: false,
          rawJson: '{}',
        ),
        TaskListEntity(
          accountId: 'account',
          id: 'hidden-list',
          title: 'Hidden',
          localDirty: false,
          pendingDelete: false,
          rawJson: '{}',
        ),
      ],
      settings: AppSettings.defaults().copyWith(
        taskListScheduleVisibility: const {'account::hidden-list': false},
      ),
      writableTaskListKeys: {visibleKey},
      scheduleItems: [
        _task('due', sourceId: 'visible-list', start: now),
        _task('done', sourceId: 'visible-list', start: now, completed: true),
        _task('no-date', sourceId: 'visible-list'),
        _task('hidden', sourceId: 'hidden-list', start: now),
      ],
    );

    expect(presentation.incompleteTasksDueToday, 1);
    expect(presentation.canCreateTask, isTrue);
  });

  test('read-only WebCal events display without enabling creation', () {
    final presentation = _project(
      now: now,
      accounts: [_account(provider: BusyProvider.webCal)],
      calendarSources: [
        _source(
          provider: BusyProvider.webCal,
          readOnly: true,
          accountId: 'account',
        ),
      ],
      scheduleItems: [
        _event('webcal-event', provider: BusyProvider.webCal, start: now),
      ],
    );

    expect(presentation.events.single.eventId, 'webcal-event');
    expect(presentation.canCreateEvent, isFalse);
  });

  test('visible capability models control quick creation', () {
    const taskKey = ScheduleTaskListKey(
      accountId: 'account',
      taskListId: 'tasks',
    );
    final presentation = _project(
      now: now,
      calendarSources: [_source()],
      taskLists: const [
        TaskListEntity(
          accountId: 'account',
          id: 'tasks',
          title: 'Tasks',
          localDirty: false,
          pendingDelete: false,
          rawJson: '{}',
        ),
      ],
      writableTaskListKeys: {taskKey},
    );

    expect(presentation.canCreateEvent, isTrue);
    expect(presentation.canCreateTask, isTrue);
  });

  test('uses the least fresh successful account synchronization', () {
    final presentation = _project(
      now: now,
      accounts: [
        _account(lastSync: DateTime.utc(2026, 8, 29, 9, 50)),
        _account(id: 'second', lastSync: DateTime.utc(2026, 8, 29, 8)),
      ],
    );
    expect(
      presentation.lastSuccessfulSynchronizationUtc,
      DateTime.utc(2026, 8, 29, 8),
    );

    final neverSynced = _project(
      now: now,
      accounts: [
        _account(lastSync: DateTime.utc(2026, 8, 29, 9)),
        _account(id: 'second'),
      ],
    );
    expect(neverSynced.lastSuccessfulSynchronizationUtc, isNull);
  });

  test('formats all-day, ongoing, future, fallback, and sanitized labels', () {
    final presentation = _project(
      now: now,
      scheduleItems: [
        _event(
          'all-day',
          title: ' Release\n\u0007 freeze ',
          start: DateTime(2026, 8, 29),
          allDay: true,
        ),
        _event(
          'ongoing',
          title: '',
          start: DateTime(2026, 8, 29, 9),
          end: DateTime(2026, 8, 29, 11),
        ),
        _event(
          'future',
          title: List.filled(120, 'x').join(),
          start: DateTime(2026, 8, 29, 10, 30),
        ),
      ],
    );
    final menu = _formatter.format(presentation);

    expect(menu.eventRows[0].label, 'All day · Release freeze');
    expect(menu.eventRows[1].label, 'Now · Untitled event');
    expect(menu.eventRows[2].label, startsWith('10:30 · '));
    expect(menu.eventRows[2].label, endsWith('…'));
    expect(menu.eventRows[2].label.runes.length, 100);
  });

  test('private detail removes every event title', () {
    final presentation = _project(
      now: now,
      settings: AppSettings.defaults().copyWith(
        notificationDetailLevel: NotificationDetailLevel.private,
      ),
      scheduleItems: [
        _event(
          'all-day',
          title: 'All-day secret',
          start: DateTime(2026, 8, 29),
          allDay: true,
        ),
        _event(
          'ongoing',
          title: 'Ongoing secret',
          start: DateTime(2026, 8, 29, 9),
          end: DateTime(2026, 8, 29, 11),
        ),
      ],
    );
    final labels = _formatter
        .format(presentation)
        .eventRows
        .map((row) => row.label)
        .toList();

    expect(labels, ['All day · Calendar event', 'Now · Calendar event']);
    expect(labels.join(' '), isNot(contains('secret')));
  });

  test('normal Unicode event titles are preserved', () {
    final menu = _formatter.format(
      _project(
        now: now,
        scheduleItems: [_event('unicode', title: 'Réunion 東京', start: now)],
      ),
    );

    expect(menu.eventRows.single.label, '10:00 · Réunion 東京');
  });

  test('formats singular, plural, and empty Today states', () {
    final one = _formatter.format(
      _project(
        now: now,
        scheduleItems: [_task('one', start: now)],
      ),
    );
    final many = _formatter.format(
      _project(
        now: now,
        scheduleItems: [
          _task('one', start: now),
          _task('two', start: now),
          _task('three', start: now),
        ],
      ),
    );
    final empty = _formatter.format(_project(now: now));

    expect(one.taskSummaryLabel, '1 task due today');
    expect(many.taskSummaryLabel, '3 tasks due today');
    expect(empty.showEmptyState, isTrue);
    expect(empty.emptyStateLabel, 'Nothing else today');
  });

  test('formats synchronization status precedence and relative time', () {
    BusyMaxTrayMenuPresentation format({
      NetworkAvailability connectivity = NetworkAvailability.online,
      bool syncing = false,
      List<AccountEntity>? accounts,
    }) => _formatter.format(
      _project(
        now: now,
        connectivity: connectivity,
        synchronizationRunning: syncing,
        accounts:
            accounts ??
            [
              _account(
                lastSync: now.toUtc().subtract(const Duration(minutes: 5)),
              ),
            ],
      ),
    );

    expect(
      format(
        connectivity: NetworkAvailability.offline,
        syncing: true,
      ).synchronizationStatusLabel,
      'Offline — Changes will sync when connected.',
    );
    expect(format(syncing: true).synchronizationStatusLabel, 'Syncing…');
    expect(format(accounts: []).synchronizationStatusLabel, 'Not connected');
    expect(
      format(accounts: [_account()]).synchronizationStatusLabel,
      'Not yet synced',
    );
    expect(format().synchronizationStatusLabel, 'Last synced 5 minutes ago');
    expect(
      format(connectivity: NetworkAvailability.offline).canSynchronize,
      isFalse,
    );
    expect(format(syncing: true).canSynchronize, isFalse);
    expect(format(accounts: []).canSynchronize, isFalse);
    expect(format().canSynchronize, isTrue);
  });
}

BusyMaxTrayPresentation _project({
  required DateTime now,
  List<AccountEntity>? accounts,
  List<CalendarSourceEntity>? calendarSources,
  List<TaskListEntity>? taskLists,
  List<ScheduleItem> scheduleItems = const [],
  Set<ScheduleTaskListKey> writableTaskListKeys = const {},
  AppSettings? settings,
  NetworkAvailability connectivity = NetworkAvailability.online,
  bool synchronizationRunning = false,
}) {
  return projectBusyMaxTrayPresentation(
    accounts: accounts ?? [_account()],
    calendarSources: calendarSources ?? [_source()],
    taskLists:
        taskLists ??
        const [
          TaskListEntity(
            accountId: 'account',
            id: 'visible-list',
            title: 'Visible',
            localDirty: false,
            pendingDelete: false,
            rawJson: '{}',
          ),
        ],
    scheduleItems: scheduleItems,
    writableTaskListKeys: writableTaskListKeys,
    settings: settings ?? AppSettings.defaults(),
    connectivity: connectivity,
    synchronizationRunning: synchronizationRunning,
    now: now,
  );
}

AccountEntity _account({
  String id = 'account',
  BusyProvider provider = BusyProvider.google,
  DateTime? lastSync,
}) {
  return AccountEntity(
    id: id,
    provider: provider,
    authority: 'https://example.test',
    providerAccountId: id,
    credentialKind: provider == BusyProvider.webCal
        ? CredentialKind.webCalSubscription
        : CredentialKind.oauth,
    authState: accountAuthStateSignedIn,
    lastSuccessfulSyncAtUtc: lastSync,
  );
}

CalendarSourceEntity _source({
  String id = 'calendar',
  String accountId = 'account',
  BusyProvider provider = BusyProvider.google,
  bool selected = true,
  bool hidden = false,
  bool readOnly = false,
}) {
  return CalendarSourceEntity(
    id: id,
    accountId: accountId,
    provider: provider,
    providerCalendarId: id,
    summary: id,
    selected: selected,
    hidden: hidden,
    readOnly: readOnly,
    isDeleted: false,
  );
}

CalendarScheduleItem _event(
  String id, {
  String accountId = 'account',
  String sourceId = 'calendar',
  BusyProvider provider = BusyProvider.google,
  String? title,
  required DateTime start,
  DateTime? end,
  bool allDay = false,
}) {
  return CalendarScheduleItem(
    id: id,
    accountId: accountId,
    provider: provider,
    sourceId: sourceId,
    providerCalendarId: sourceId,
    title: title ?? id,
    allDay: allDay,
    start: start,
    end: end,
  );
}

TaskScheduleItem _task(
  String id, {
  String sourceId = 'visible-list',
  DateTime? start,
  bool completed = false,
}) {
  return TaskScheduleItem(
    id: id,
    accountId: 'account',
    provider: BusyProvider.google,
    sourceId: sourceId,
    title: id,
    completed: completed,
    allDay: true,
    start: start,
  );
}

final _formatter = BusyMaxTrayPresentationFormatter(
  BusyMaxTrayPresentationStrings(
    showBusyMax: 'Show BusyMax',
    newEvent: 'New event…',
    newTask: 'New task…',
    today: 'Today',
    allDay: 'All day',
    now: 'Now',
    calendarEvent: 'Calendar event',
    untitledEvent: 'Untitled event',
    nothingElseToday: 'Nothing else today',
    openTodayAgenda: 'Open today’s agenda',
    syncNow: 'Sync now',
    syncing: 'Syncing…',
    notConnected: 'Not connected',
    notYetSynced: 'Not yet synced',
    settings: 'Settings',
    quitBusyMax: 'Quit BusyMax',
    offline: 'Offline',
    offlineDescription: 'Changes will sync when connected.',
    formatTime: (value) =>
        '${value.hour.toString().padLeft(2, '0')}:'
        '${value.minute.toString().padLeft(2, '0')}',
    tasksDueToday: (count) =>
        count == 1 ? '1 task due today' : '$count tasks due today',
    lastSyncedJustNow: 'Last synced just now',
    lastSyncedMinutesAgo: (count) =>
        'Last synced $count minute${count == 1 ? '' : 's'} ago',
    lastSyncedHoursAgo: (count) =>
        'Last synced $count hour${count == 1 ? '' : 's'} ago',
    lastSyncedDaysAgo: (count) =>
        'Last synced $count day${count == 1 ? '' : 's'} ago',
  ),
);

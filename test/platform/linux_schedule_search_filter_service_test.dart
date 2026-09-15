import 'package:busymax/src/platform/linux_schedule_search_filter_service.dart';
import 'package:busymax/src/schedule/schedule_filters.dart';
import 'package:busymax/src/schedule/schedule_search_criteria.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('busymax_test/native_schedule_filters');

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('serializes complete localized presentation state', () async {
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return call.method == 'initialize' ? true : null;
        });
    final service = LinuxScheduleSearchFilterService(
      channel: channel,
      isLinux: true,
    );
    addTearDown(service.dispose);
    final session = service.claimSession();
    addTearDown(session.dispose);

    final criteria = ScheduleSearchCriteria(
      type: ScheduleSearchType.tasks,
      date: ScheduleSearchDate.custom,
      taskCompletion: ScheduleTaskCompletion.completed,
      taskDueState: ScheduleTaskDueState.noDueDate,
      person: 'Taylor',
      location: 'Office',
      customStart: DateTime(2026, 9, 12),
      customEnd: DateTime(2026, 9, 15),
      referenceDate: DateTime(2026, 9, 10),
      firstWeekday: DateTime.monday,
      sourceIds: {'calendar-b'},
      taskListKeys: {
        const ScheduleTaskListKey(accountId: 'account-a', taskListId: 'list-b'),
      },
    );
    await session.updateState(
      LinuxScheduleSearchFilterState(
        active: true,
        sidebarVisible: true,
        sidebarWidth: 300,
        criteria: criteria,
        labels: _labels,
        accounts: const [
          LinuxScheduleSearchFilterAccount(id: 'account-a', label: 'Alex'),
        ],
        calendarSources: const [
          LinuxScheduleSearchFilterCalendarSource(
            id: 'calendar-b',
            accountId: 'account-a',
            title: 'Work',
            selected: true,
          ),
        ],
        taskLists: const [
          LinuxScheduleSearchFilterTaskList(
            accountId: 'account-a',
            taskListId: 'list-b',
            title: 'Tasks',
            selected: true,
          ),
        ],
      ),
    );

    final state =
        calls.singleWhere((call) => call.method == 'setState').arguments
            as Map<Object?, Object?>;
    expect(state, containsPair('schemaVersion', 1));
    expect(state, containsPair('active', true));
    expect(state['labels'], containsPair('searchFilters', 'Search filters'));
    expect(state['labels'], containsPair('noDueDate', 'No due date'));
    expect(
      state['calendarSources'],
      contains(containsPair('id', 'calendar-b')),
    );
    expect(
      state['taskLists'],
      contains(
        allOf(
          containsPair('accountId', 'account-a'),
          containsPair('taskListId', 'list-b'),
        ),
      ),
    );
    final serializedCriteria = state['criteria'] as Map<Object?, Object?>;
    expect(serializedCriteria, containsPair('type', 'tasks'));
    expect(serializedCriteria, containsPair('date', 'custom'));
    expect(serializedCriteria, containsPair('taskCompletion', 'completed'));
    expect(serializedCriteria, containsPair('taskDueState', 'noDueDate'));
    expect(serializedCriteria, containsPair('customStart', '2026-09-12'));
    expect(serializedCriteria, containsPair('customEnd', '2026-09-15'));
    expect(
      serializedCriteria['taskListKeys'],
      contains(
        allOf(
          containsPair('accountId', 'account-a'),
          containsPair('taskListId', 'list-b'),
        ),
      ),
    );
  });

  test(
    'dispatches native criteria, source, clear, and dismiss events',
    () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            channel,
            (call) async => call.method == 'initialize' ? true : null,
          );
      final service = LinuxScheduleSearchFilterService(
        channel: channel,
        isLinux: true,
      );
      addTearDown(service.dispose);
      final session = service.claimSession();
      addTearDown(session.dispose);
      await session.initialize();
      final events = <LinuxScheduleSearchFilterEvent>[];
      final subscription = session.events.listen(events.add);
      addTearDown(subscription.cancel);

      for (final call in const <MethodCall>[
        MethodCall('typeChanged', 'events'),
        MethodCall('dateChanged', 'tomorrow'),
        MethodCall('taskCompletionChanged', 'open'),
        MethodCall('taskDueStateChanged', 'overdue'),
        MethodCall('personChanged', 'Taylor'),
        MethodCall('locationChanged', 'Office'),
        MethodCall('customStartChanged', '2026-09-12'),
        MethodCall('customEndChanged', '2026-09-15'),
        MethodCall('calendarSourceToggled', {
          'sourceId': 'calendar-b',
          'selected': false,
        }),
        MethodCall('taskListToggled', {
          'accountId': 'account-a',
          'taskListId': 'list-b',
          'selected': true,
        }),
        MethodCall('clearFilters'),
        MethodCall('dismissSearch'),
      ]) {
        await service.handleNativeMethodCall(call);
      }
      await Future<void>.delayed(Duration.zero);

      expect(events[0], isA<LinuxScheduleSearchTypeChanged>());
      expect(events[1], isA<LinuxScheduleSearchDateChanged>());
      expect(events[2], isA<LinuxScheduleSearchTaskCompletionChanged>());
      expect(events[3], isA<LinuxScheduleSearchTaskDueStateChanged>());
      expect((events[4] as LinuxScheduleSearchPersonChanged).value, 'Taylor');
      expect((events[5] as LinuxScheduleSearchLocationChanged).value, 'Office');
      expect(
        (events[6] as LinuxScheduleSearchCustomStartChanged).value,
        DateTime(2026, 9, 12),
      );
      expect(
        (events[7] as LinuxScheduleSearchCustomEndChanged).value,
        DateTime(2026, 9, 15),
      );
      final source = events[8] as LinuxScheduleSearchCalendarSourceToggled;
      expect(source.sourceId, 'calendar-b');
      expect(source.selected, isFalse);
      final taskList = events[9] as LinuxScheduleSearchTaskListToggled;
      expect(taskList.key.accountId, 'account-a');
      expect(taskList.key.taskListId, 'list-b');
      expect(taskList.selected, isTrue);
      expect(events[10], isA<LinuxScheduleSearchClearRequested>());
      expect(events[11], isA<LinuxScheduleSearchDismissRequested>());
    },
  );

  test('only the current, available session receives native events', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          channel,
          (call) async => call.method == 'initialize' ? true : null,
        );
    final service = LinuxScheduleSearchFilterService(
      channel: channel,
      isLinux: true,
    );
    addTearDown(service.dispose);
    final stale = service.claimSession();
    final current = service.claimSession();
    final staleEvents = <LinuxScheduleSearchFilterEvent>[];
    final currentEvents = <LinuxScheduleSearchFilterEvent>[];
    stale.events.listen(staleEvents.add);
    current.events.listen(currentEvents.add);
    await current.initialize();

    await service.handleNativeMethodCall(
      const MethodCall('personChanged', 'Current'),
    );
    await Future<void>.delayed(Duration.zero);
    expect(staleEvents, isEmpty);
    expect(currentEvents, hasLength(1));

    current.dispose();
    stale.dispose();
    await service.handleNativeMethodCall(
      const MethodCall('locationChanged', 'Ignored'),
    );
    await Future<void>.delayed(Duration.zero);
    expect(staleEvents, isEmpty);
    expect(currentEvents, hasLength(1));
  });

  test('an unavailable bridge cannot dispatch into its session', () async {
    final service = LinuxScheduleSearchFilterService(
      channel: channel,
      isLinux: false,
    );
    addTearDown(service.dispose);
    final session = service.claimSession();
    final events = <LinuxScheduleSearchFilterEvent>[];
    session.events.listen(events.add);
    await session.initialize();

    await service.handleNativeMethodCall(
      const MethodCall('personChanged', 'Ignored'),
    );
    await Future<void>.delayed(Duration.zero);

    expect(service.isAvailable, isFalse);
    expect(events, isEmpty);
  });
}

const _labels = LinuxScheduleSearchFilterLabels(
  searchFilters: 'Search filters',
  type: 'Type',
  all: 'All',
  events: 'Events',
  tasks: 'Tasks',
  date: 'Date',
  anyDate: 'Any date',
  today: 'Today',
  tomorrow: 'Tomorrow',
  thisWeek: 'This week',
  customRange: 'Custom range',
  startDate: 'Start date',
  endDate: 'End date',
  taskStatus: 'Task status',
  open: 'Open',
  completed: 'Completed',
  taskDue: 'Task due',
  anyDueState: 'Any due state',
  overdue: 'Overdue',
  noDueDate: 'No due date',
  person: 'Person',
  location: 'Location',
  sources: 'Sources',
  clearFilters: 'Clear filters',
  noSources: 'No search sources selected',
  close: 'Close',
  cancel: 'Cancel',
  ok: 'OK',
);

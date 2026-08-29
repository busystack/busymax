import '../../../app/app_settings.dart';
import '../../../schedule/schedule_filters.dart';
import '../../../schedule/schedule_item.dart';
import '../../../schedule/schedule_range.dart';
import '../../../schedule/schedule_repository.dart';
import '../../../schedule/schedule_source_visibility.dart';
import '../../accounts/data/accounts_repository.dart';
import '../../calendar/data/calendar_repository.dart';
import '../../connectivity/network_connectivity_service.dart';
import '../../task_lists/data/task_lists_repository.dart';
import '../domain/tray_presentation.dart';

typedef TrayTaskListsLoader =
    Future<List<TaskListEntity>> Function(AccountEntity account);
typedef TrayTaskListWriteCheck =
    Future<bool> Function(AccountEntity account, TaskListEntity taskList);

final class BusyMaxTrayPresentationService {
  const BusyMaxTrayPresentationService({
    required AccountsRepository accountsRepository,
    required CalendarRepository calendarRepository,
    required ScheduleRepository scheduleRepository,
    required TrayTaskListsLoader listTaskLists,
    required TrayTaskListWriteCheck canCreateTask,
    required AppSettings Function() settings,
    required NetworkAvailability Function() connectivity,
    required bool Function() synchronizationRunning,
    DateTime Function()? now,
  }) : _accountsRepository = accountsRepository,
       _calendarRepository = calendarRepository,
       _scheduleRepository = scheduleRepository,
       _listTaskLists = listTaskLists,
       _canCreateTask = canCreateTask,
       _settings = settings,
       _connectivity = connectivity,
       _synchronizationRunning = synchronizationRunning,
       _now = now ?? DateTime.now;

  final AccountsRepository _accountsRepository;
  final CalendarRepository _calendarRepository;
  final ScheduleRepository _scheduleRepository;
  final TrayTaskListsLoader _listTaskLists;
  final TrayTaskListWriteCheck _canCreateTask;
  final AppSettings Function() _settings;
  final NetworkAvailability Function() _connectivity;
  final bool Function() _synchronizationRunning;
  final DateTime Function() _now;

  Future<BusyMaxTrayPresentation> load() async {
    final now = _now();
    final accounts = await _accountsRepository.watchAccounts().first;
    final accountIds = accounts.map((account) => account.id).toList();
    final sources = await _calendarRepository
        .watchSourcesForAccounts(accountIds)
        .first;
    final taskLists = <TaskListEntity>[];
    for (final account in accounts.where((account) => account.isTaskCapable)) {
      taskLists.addAll(await _listTaskLists(account));
    }
    final settings = _settings();
    final visibility = ScheduleSourceVisibility.fromSources(
      calendarSources: sources,
      taskLists: taskLists,
      settings: settings,
    );
    final items = await _scheduleRepository.listItems(
      range: ScheduleRange.day(now),
      filters: ScheduleFilters(
        accountIds: accountIds.toSet(),
        sourceIds: visibility.visibleCalendarSourceIds,
        taskListKeys: visibility.visibleTaskListKeys,
        sourceFilterActive: true,
        taskListFilterActive: true,
        showCompletedTasks: false,
        showNoDateTasks: false,
      ),
    );
    final writableTaskLists = <ScheduleTaskListKey>{};
    final accountsById = {for (final account in accounts) account.id: account};
    for (final taskList in taskLists) {
      final key = ScheduleTaskListKey(
        accountId: taskList.accountId,
        taskListId: taskList.id,
      );
      if (!visibility.visibleTaskListKeys.contains(key)) continue;
      final account = accountsById[taskList.accountId];
      if (account != null && await _canCreateTask(account, taskList)) {
        writableTaskLists.add(key);
      }
    }
    return projectBusyMaxTrayPresentation(
      accounts: accounts,
      calendarSources: sources,
      taskLists: taskLists,
      scheduleItems: items,
      writableTaskListKeys: writableTaskLists,
      settings: settings,
      connectivity: _connectivity(),
      synchronizationRunning: _synchronizationRunning(),
      now: now,
    );
  }
}

BusyMaxTrayPresentation projectBusyMaxTrayPresentation({
  required List<AccountEntity> accounts,
  required List<CalendarSourceEntity> calendarSources,
  required List<TaskListEntity> taskLists,
  required List<ScheduleItem> scheduleItems,
  required Set<ScheduleTaskListKey> writableTaskListKeys,
  required AppSettings settings,
  required NetworkAvailability connectivity,
  required bool synchronizationRunning,
  required DateTime now,
}) {
  final visibility = ScheduleSourceVisibility.fromSources(
    calendarSources: calendarSources,
    taskLists: taskLists,
    settings: settings,
  );
  final eventEntries = <BusyMaxTrayEventEntry>[];
  var taskCount = 0;
  for (final item in scheduleItems) {
    if (item is CalendarScheduleItem) {
      if (eventEntries.length >= 3 ||
          !visibility.visibleCalendarSourceIds.contains(item.sourceId)) {
        continue;
      }
      final start = item.start;
      if (start == null || !_trayEventIsRelevant(item, now)) continue;
      eventEntries.add(
        BusyMaxTrayEventEntry(
          eventId: item.id,
          accountId: item.accountId,
          calendarSourceId: item.sourceId,
          title: item.title,
          start: start,
          end: item.end,
          allDay: item.allDay,
        ),
      );
      continue;
    }
    if (item is TaskScheduleItem &&
        !item.completed &&
        item.start != null &&
        visibility.visibleTaskListKeys.contains(
          ScheduleTaskListKey(
            accountId: item.accountId,
            taskListId: item.sourceId,
          ),
        )) {
      taskCount += 1;
    }
  }

  final visibleWritableTaskList = writableTaskListKeys.any(
    visibility.visibleTaskListKeys.contains,
  );
  final syncEligible = accounts.where((account) => account.isSyncEligible);
  DateTime? oldestSuccessfulSync;
  var allAccountsHaveSynchronized = true;
  var hasSyncEligibleAccount = false;
  for (final account in syncEligible) {
    hasSyncEligibleAccount = true;
    final synchronizedAt = account.lastSuccessfulSyncAtUtc;
    if (synchronizedAt == null) {
      allAccountsHaveSynchronized = false;
      continue;
    }
    if (oldestSuccessfulSync == null ||
        synchronizedAt.isBefore(oldestSuccessfulSync)) {
      oldestSuccessfulSync = synchronizedAt;
    }
  }
  return BusyMaxTrayPresentation(
    connectivity: connectivity,
    synchronizationRunning: synchronizationRunning,
    lastSuccessfulSynchronizationUtc: allAccountsHaveSynchronized
        ? oldestSuccessfulSync
        : null,
    events: List.unmodifiable(eventEntries),
    incompleteTasksDueToday: taskCount,
    canCreateEvent: calendarSources.any(
      (source) =>
          visibility.visibleCalendarSourceIds.contains(source.id) &&
          source.capabilities.canCreateEvents,
    ),
    canCreateTask: visibleWritableTaskList,
    hasSyncEligibleAccount: hasSyncEligibleAccount,
    notificationDetailLevel: settings.notificationDetailLevel,
    localNow: now,
  );
}

bool _trayEventIsRelevant(CalendarScheduleItem event, DateTime now) {
  if (event.allDay) return true;
  final start = event.start;
  if (start == null) return false;
  final end = event.end;
  if (end == null) return !start.isBefore(now);
  return end.isAfter(now);
}

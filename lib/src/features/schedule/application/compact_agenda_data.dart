import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_bootstrap.dart';
import '../../../schedule/schedule_filters.dart';
import '../../../schedule/schedule_item.dart';
import '../../../schedule/schedule_range.dart';
import '../../../schedule/schedule_sorting.dart';
import '../../../schedule/schedule_source_visibility.dart';
import '../../task_lists/data/task_lists_repository.dart';
import 'compact_agenda_sections.dart';

const compactAgendaInitialDays = 30;
const compactAgendaPageDays = 30;
const compactAgendaSqliteBusyRetryDelays = [
  Duration(milliseconds: 120),
  Duration(milliseconds: 240),
  Duration(milliseconds: 480),
];

typedef CompactAgendaDataLoader =
    Future<CompactAgendaData> Function(Ref ref, CompactAgendaQuery query);
typedef CompactAgendaRetryDelay = Future<void> Function(Duration duration);

final compactAgendaDataLoaderProvider = Provider<CompactAgendaDataLoader>(
  (ref) => loadCompactAgendaDataFromRepositories,
);

final compactAgendaDataProvider = FutureProvider.autoDispose<CompactAgendaData>(
  (ref) {
    return ref.watch(
      compactAgendaDataForQueryProvider(CompactAgendaQuery.initial).future,
    );
  },
);

final compactAgendaDataForQueryProvider = FutureProvider.autoDispose
    .family<CompactAgendaData, CompactAgendaQuery>((ref, query) {
      return loadCompactAgendaDataWithRetry(ref, query);
    });

Future<CompactAgendaData> loadCompactAgendaDataWithRetry(
  Ref ref,
  CompactAgendaQuery query, {
  CompactAgendaDataLoader? loader,
  List<Duration> retryDelays = compactAgendaSqliteBusyRetryDelays,
  CompactAgendaRetryDelay delay = _compactAgendaDelay,
}) async {
  final CompactAgendaDataLoader load =
      loader ?? ref.read(compactAgendaDataLoaderProvider);
  for (var attempt = 0; ; attempt += 1) {
    try {
      return await load(ref, query);
    } on Object catch (error) {
      if (!_isSqliteBusy(error) || attempt >= retryDelays.length) {
        rethrow;
      }
      await delay(retryDelays[attempt]);
    }
  }
}

Future<CompactAgendaData> loadCompactAgendaDataFromRepositories(
  Ref ref,
  CompactAgendaQuery query,
) async {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final days = query.futureDays < 1
      ? compactAgendaInitialDays
      : query.futureDays;
  final end = today.add(Duration(days: days));
  final range = ScheduleRange(start: today, end: end);

  CompactAgendaData empty({
    required bool hasSignedInAccounts,
    required bool hasSources,
  }) {
    return CompactAgendaData(
      today: today,
      range: range,
      items: const [],
      hasMoreOverdueTasks: false,
      hasMoreNoDateTasks: false,
      hasSignedInAccounts: hasSignedInAccounts,
      hasSources: hasSources,
      generatedAt: now,
    );
  }

  final accounts = await ref
      .read(accountsRepositoryProvider)
      .listSignedInAccounts();
  if (accounts.isEmpty) {
    return empty(hasSignedInAccounts: false, hasSources: false);
  }

  final accountIds = accounts.map((account) => account.id).toSet();
  final calendarSources = await ref
      .read(calendarRepositoryProvider)
      .listVisibleSources(accountIds.toList());
  final taskLists = <TaskListEntity>[];
  for (final account in accounts) {
    taskLists.addAll(
      await ref
          .read(taskListsRepositoryForAccountProvider(account.id))
          .listTaskLists(),
    );
  }

  final visibility = ScheduleSourceVisibility.fromSources(
    calendarSources: calendarSources,
    taskLists: taskLists,
    settings: ref.read(appSettingsControllerProvider),
  );
  final hasSources =
      visibility.visibleCalendarSourceIds.isNotEmpty ||
      visibility.visibleTaskListIds.isNotEmpty;
  if (!hasSources) {
    return empty(hasSignedInAccounts: true, hasSources: false);
  }

  final repository = ref.read(scheduleRepositoryProvider);
  final datedItemsFuture = repository.listItems(
    range: range,
    filters: ScheduleFilters(
      accountIds: accountIds,
      sourceIds: visibility.visibleCalendarSourceIds,
      taskListIds: visibility.visibleTaskListIds,
      sourceFilterActive: true,
      taskListFilterActive: true,
      includeCalendarEvents: true,
      includeTasks: true,
      showCompletedTasks: false,
      showNoDateTasks: false,
    ),
  );
  final overdueTasksFuture = repository.listOverdueTasks(
    before: today,
    limit: query.overdueLimit,
    filters: ScheduleFilters(
      accountIds: accountIds,
      taskListIds: visibility.visibleTaskListIds,
      taskListFilterActive: true,
      includeTasks: true,
      showCompletedTasks: false,
    ),
  );
  final noDateTasksFuture = repository.listNoDateTasks(
    limit: query.noDateLimit,
    filters: ScheduleFilters(
      accountIds: accountIds,
      taskListIds: visibility.visibleTaskListIds,
      taskListFilterActive: true,
      includeTasks: true,
      showCompletedTasks: false,
    ),
  );
  final datedItems = await datedItemsFuture;
  final overdueTasks = await overdueTasksFuture;
  final noDateTasks = await noDateTasksFuture;
  final rawItems = [...datedItems, ...overdueTasks.items, ...noDateTasks.items];

  final items = rawItems.where((item) {
    final start = item.start;
    if (start == null) {
      return item is TaskScheduleItem && !item.completed;
    }
    if (item is CalendarScheduleItem) {
      return !start.isBefore(today) && start.isBefore(end);
    }
    if (item is TaskScheduleItem) {
      return !item.completed && start.isBefore(end);
    }
    return false;
  }).toList()..sort(compareScheduleItems);

  return CompactAgendaData(
    today: today,
    range: range,
    items: items,
    hasMoreOverdueTasks: overdueTasks.hasMore,
    hasMoreNoDateTasks: noDateTasks.hasMore,
    hasSignedInAccounts: true,
    hasSources: true,
    generatedAt: now,
  );
}

class CompactAgendaData {
  const CompactAgendaData({
    required this.today,
    required this.range,
    required this.items,
    required this.hasMoreOverdueTasks,
    required this.hasMoreNoDateTasks,
    required this.hasSignedInAccounts,
    required this.hasSources,
    required this.generatedAt,
  });

  final DateTime today;
  final ScheduleRange range;
  final List<ScheduleItem> items;
  final bool hasMoreOverdueTasks;
  final bool hasMoreNoDateTasks;
  final bool hasSignedInAccounts;
  final bool hasSources;
  final DateTime generatedAt;
}

class CompactAgendaQuery {
  const CompactAgendaQuery({
    required this.futureDays,
    required this.overdueLimit,
    required this.noDateLimit,
  });

  static const initial = CompactAgendaQuery(
    futureDays: compactAgendaInitialDays,
    overdueLimit: compactAgendaInitialOverdueLimit,
    noDateLimit: compactAgendaInitialNoDateLimit,
  );

  final int futureDays;
  final int overdueLimit;
  final int noDateLimit;

  @override
  bool operator ==(Object other) {
    return other is CompactAgendaQuery &&
        other.futureDays == futureDays &&
        other.overdueLimit == overdueLimit &&
        other.noDateLimit == noDateLimit;
  }

  @override
  int get hashCode => Object.hash(futureDays, overdueLimit, noDateLimit);
}

Future<void> _compactAgendaDelay(Duration duration) {
  return Future<void>.delayed(duration);
}

bool _isSqliteBusy(Object error) {
  final message = error.toString().toLowerCase();
  return message.contains('database is locked') ||
      message.contains('sqlite_busy') ||
      message.contains('sqlite exception(5)') ||
      message.contains('sqliteexception(5)');
}

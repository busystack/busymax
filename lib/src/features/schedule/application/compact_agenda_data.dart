import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_bootstrap.dart';
import '../../../schedule/schedule_filters.dart';
import '../../../schedule/schedule_item.dart';
import '../../../schedule/schedule_range.dart';
import '../../../schedule/schedule_sorting.dart';
import '../../../schedule/schedule_source_visibility.dart';
import '../../task_lists/data/task_lists_repository.dart';

final compactAgendaDataProvider = FutureProvider.autoDispose<CompactAgendaData>(
  (ref) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final end = today.add(const Duration(days: 7));
    final queryStart = today.subtract(const Duration(days: 30));
    final range = ScheduleRange(start: today, end: end);

    CompactAgendaData empty({
      required bool hasSignedInAccounts,
      required bool hasSources,
    }) {
      return CompactAgendaData(
        today: today,
        range: range,
        items: const [],
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

    final rawItems = await ref
        .read(scheduleRepositoryProvider)
        .listItems(
          range: ScheduleRange(start: queryStart, end: end),
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

    final items = rawItems.where((item) {
      final start = item.start;
      if (start == null) {
        return false;
      }
      if (item is CalendarScheduleItem) {
        return !start.isBefore(today) && start.isBefore(end);
      }
      if (item is TaskScheduleItem) {
        return !item.completed && start.isBefore(end);
      }
      return false;
    }).toList()
      ..sort(compareScheduleItems);

    return CompactAgendaData(
      today: today,
      range: range,
      items: items,
      hasSignedInAccounts: true,
      hasSources: true,
      generatedAt: now,
    );
  },
);

class CompactAgendaData {
  const CompactAgendaData({
    required this.today,
    required this.range,
    required this.items,
    required this.hasSignedInAccounts,
    required this.hasSources,
    required this.generatedAt,
  });

  final DateTime today;
  final ScheduleRange range;
  final List<ScheduleItem> items;
  final bool hasSignedInAccounts;
  final bool hasSources;
  final DateTime generatedAt;
}

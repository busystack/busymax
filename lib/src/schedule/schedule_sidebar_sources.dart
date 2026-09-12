import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/app_bootstrap.dart';
import '../features/calendar/data/calendar_repository.dart';
import '../features/task_lists/data/task_lists_repository.dart';
import 'schedule_sidebar_order.dart';

final sidebarCalendarSourcesProvider = StreamProvider.autoDispose
    .family<List<CalendarSourceEntity>, String>(
      (ref, accountId) => ref
          .watch(calendarRepositoryProvider)
          .watchSourcesForAccounts([accountId]),
    );

final sidebarTaskListsProvider = StreamProvider.autoDispose
    .family<List<TaskListEntity>, String>(
      (ref, accountId) => ref
          .watch(taskListsRepositoryForAccountProvider(accountId))
          .watchTaskLists(),
    );

final sidebarSubscriptionSourcesProvider =
    StreamProvider.autoDispose<List<CalendarSourceEntity>>((ref) {
      final accounts =
          ref.watch(accountsStreamProvider).valueOrNull ?? const [];
      return ref.watch(calendarRepositoryProvider).watchSourcesForAccounts([
        for (final account in accounts)
          if (account.isSubscription) account.id,
      ]);
    });

/// Calendar sources that belong in a desktop schedule sidebar.
///
/// Provider-hidden sources remain cached so they can reappear if the provider
/// makes them visible again, but they are not actionable schedule sources and
/// must not be presented as locally togglable rows.
List<CalendarSourceEntity> calendarSourcesShownInSidebar(
  Iterable<CalendarSourceEntity> sources, {
  String? accountId,
}) => [
  for (final source in sources)
    if ((accountId == null || source.accountId == accountId) &&
        !source.hidden &&
        !source.isDeleted)
      source,
];

/// Kept alive by the sidebar, independently of expanded or visible rows.
final sidebarOrderRegistrationProvider = Provider.autoDispose<void>((ref) {
  final controller = ref.watch(appSettingsControllerProvider.notifier);
  final accounts = ref.watch(accountsStreamProvider);
  ref.listen(accountsStreamProvider, (_, snapshot) {
    if (snapshot case AsyncData(value: final items)) {
      unawaited(
        controller.registerSidebarIds(
          SidebarOrderSection.accounts,
          items.map((account) => account.id),
        ),
      );
    }
  }, fireImmediately: true);
  for (final account in accounts.valueOrNull ?? const []) {
    ref.listen(sidebarCalendarSourcesProvider(account.id), (_, snapshot) {
      if (snapshot case AsyncData(value: final items)) {
        unawaited(
          controller.registerSidebarIds(
            SidebarOrderSection.calendars,
            items.map((source) => source.id),
            accountId: account.id,
          ),
        );
      }
    }, fireImmediately: true);
    if (!account.isSubscription) {
      ref.listen(sidebarTaskListsProvider(account.id), (_, snapshot) {
        if (snapshot case AsyncData(value: final items)) {
          unawaited(
            controller.registerSidebarIds(
              SidebarOrderSection.taskLists,
              items.map((list) => list.id),
              accountId: account.id,
            ),
          );
        }
      }, fireImmediately: true);
    }
  }
  ref.listen(sidebarSubscriptionSourcesProvider, (_, snapshot) {
    if (snapshot case AsyncData(value: final items)) {
      unawaited(
        controller.registerSidebarIds(
          SidebarOrderSection.subscriptions,
          items.map((source) => source.id),
        ),
      );
    }
  }, fireImmediately: true);
});

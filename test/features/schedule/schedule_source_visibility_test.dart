import 'package:busymax/src/app/app_settings.dart';
import 'package:busymax/src/features/calendar/data/calendar_repository.dart';
import 'package:busymax/src/features/task_lists/data/task_lists_repository.dart';
import 'package:busymax/src/providers/busy_provider.dart';
import 'package:busymax/src/schedule/schedule_filters.dart';
import 'package:busymax/src/schedule/schedule_search_criteria.dart';
import 'package:busymax/src/schedule/schedule_source_visibility.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('account mask covers new sources and temporary search selections', () {
    final calendars = [
      _source('existing'),
      _source('individual', selected: false),
      _source('provider-hidden', hidden: true),
      _source('deleted', deleted: true),
      _source('newly-discovered'),
      _source('other', accountId: 'account-b'),
    ];
    const lists = [
      TaskListEntity(
        accountId: 'account-a',
        id: 'inbox',
        title: 'Inbox A',
        localDirty: false,
        pendingDelete: false,
        rawJson: '{}',
      ),
      TaskListEntity(
        accountId: 'account-b',
        id: 'inbox',
        title: 'Inbox B',
        localDirty: false,
        pendingDelete: false,
        rawJson: '{}',
      ),
    ];
    const inboxA = ScheduleTaskListKey(
      accountId: 'account-a',
      taskListId: 'inbox',
    );
    const inboxB = ScheduleTaskListKey(
      accountId: 'account-b',
      taskListId: 'inbox',
    );
    final settings = AppSettings.defaults();
    final masked = ScheduleSourceVisibility.fromSources(
      calendarSources: calendars,
      taskLists: lists,
      settings: settings.copyWith(
        accountScheduleVisibility: {'account-a': false},
      ),
    );
    expect(masked.visibleCalendarSourceIds, {'other'});
    expect(masked.visibleTaskListKeys, {inboxB});
    expect(masked.hasCalendarSources, isTrue);
    expect(masked.hasTaskLists, isTrue);
    final criteria = ScheduleSearchCriteria(
      referenceDate: DateTime(2026, 10),
      firstWeekday: DateTime.monday,
      sourceIds: {'individual', 'newly-discovered', 'other'},
      taskListKeys: {inboxA, inboxB},
    );
    expect(masked.maskSearch(criteria).sourceIds, {'other'});
    expect(masked.maskSearch(criteria).taskListKeys, {inboxB});
    final restored = ScheduleSourceVisibility.fromSources(
      calendarSources: calendars,
      taskLists: lists,
      settings: settings,
    );
    expect(restored.visibleCalendarSourceIds, {
      'existing',
      'newly-discovered',
      'other',
    });
    expect(restored.visibleTaskListKeys, {inboxA, inboxB});
    expect(restored.maskSearch(criteria), criteria);
  });

  test('equal task-list IDs retain per-account schedule visibility', () {
    const accountAInbox = ScheduleTaskListKey(
      accountId: 'account-a',
      taskListId: 'inbox',
    );
    const accountBInbox = ScheduleTaskListKey(
      accountId: 'account-b',
      taskListId: 'inbox',
    );
    final visibility = ScheduleSourceVisibility.fromSources(
      calendarSources: const [],
      taskLists: const [
        TaskListEntity(
          accountId: 'account-a',
          id: 'inbox',
          title: 'Inbox A',
          localDirty: false,
          pendingDelete: false,
          rawJson: '{}',
        ),
        TaskListEntity(
          accountId: 'account-b',
          id: 'inbox',
          title: 'Inbox B',
          localDirty: false,
          pendingDelete: false,
          rawJson: '{}',
        ),
      ],
      settings: AppSettings.defaults().copyWith(
        taskListScheduleVisibility: const {'account-a::inbox': false},
      ),
    );

    expect(visibility.visibleTaskListKeys, isNot(contains(accountAInbox)));
    expect(visibility.visibleTaskListKeys, contains(accountBInbox));
  });
}

CalendarSourceEntity _source(
  String id, {
  String accountId = 'account-a',
  bool selected = true,
  bool hidden = false,
  bool deleted = false,
}) => CalendarSourceEntity(
  id: id,
  accountId: accountId,
  provider: BusyProvider.google,
  providerCalendarId: id,
  summary: id,
  selected: selected,
  hidden: hidden,
  readOnly: false,
  isDeleted: deleted,
);

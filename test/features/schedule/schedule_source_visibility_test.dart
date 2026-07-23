import 'package:busymax/src/app/app_settings.dart';
import 'package:busymax/src/features/task_lists/data/task_lists_repository.dart';
import 'package:busymax/src/schedule/schedule_filters.dart';
import 'package:busymax/src/schedule/schedule_source_visibility.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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

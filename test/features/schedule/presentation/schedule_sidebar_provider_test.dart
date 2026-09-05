import 'package:busymax/src/features/accounts/data/accounts_repository.dart';
import 'package:busymax/src/features/calendar/data/calendar_repository.dart';
import 'package:busymax/src/features/schedule/presentation/schedule_sidebar.dart';
import 'package:busymax/src/features/task_lists/data/task_lists_repository.dart';
import 'package:busymax/src/providers/busy_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../test_localized_app.dart';

void main() {
  testWidgets('sidebar task-list labels map every provider explicitly', (
    tester,
  ) async {
    late List<String> labels;
    await tester.pumpWidget(
      localizedTestApp(
        child: Builder(
          builder: (context) {
            labels = [
              for (final entry in <(BusyProvider, String)>[
                (BusyProvider.google, 'Google list'),
                (BusyProvider.microsoft, 'Microsoft list'),
                (BusyProvider.appleICloud, 'Apple list'),
                (BusyProvider.nextcloud, 'Project Tasks'),
              ])
                scheduleTaskListLabel(
                  context,
                  _account(entry.$1),
                  _taskList(_account(entry.$1).id, entry.$2),
                ),
            ];
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(labels, [
      'Google Tasks · Google list',
      'Microsoft To Do · Microsoft list',
      'Apple iCloud · Apple list',
      'Nextcloud Tasks · Project Tasks',
    ]);
    expect(labels.last, isNot(contains('Microsoft To Do')));
  });

  test('provider links never fall through to a different provider', () {
    final google = _account(BusyProvider.google);
    final microsoft = _account(BusyProvider.microsoft);
    final apple = _account(BusyProvider.appleICloud);
    final nextcloud = _account(BusyProvider.nextcloud);

    expect(
      scheduleCalendarProviderWebUri(
        google,
        _calendarSource(google, providerCalendarId: 'calendar-id'),
      ),
      Uri.parse('https://calendar.google.com/calendar/u/0/r?cid=calendar-id'),
    );
    expect(
      scheduleTaskProviderWebUri(google),
      Uri.parse('https://tasks.google.com/'),
    );
    expect(
      scheduleCalendarProviderWebUri(microsoft, _calendarSource(microsoft)),
      Uri.parse('https://outlook.live.com/calendar/0/view/month'),
    );
    expect(
      scheduleTaskProviderWebUri(microsoft),
      Uri.parse('https://to-do.office.com/tasks/'),
    );
    expect(
      scheduleCalendarProviderWebUri(apple, _calendarSource(apple)),
      isNull,
    );
    expect(scheduleTaskProviderWebUri(apple), isNull);
    expect(
      scheduleCalendarProviderWebUri(nextcloud, _calendarSource(nextcloud)),
      Uri.parse('https://cloud.example.test/nextcloud'),
    );
    expect(
      scheduleTaskProviderWebUri(nextcloud),
      Uri.parse('https://cloud.example.test/nextcloud'),
    );
  });

  test('Nextcloud provider links reject mismatched or unsafe account data', () {
    final nextcloud = _account(BusyProvider.nextcloud);
    final mismatchedSource = _calendarSource(_account(BusyProvider.google));
    const unsafeAccount = AccountEntity(
      id: 'nextcloud:unsafe',
      provider: BusyProvider.nextcloud,
      authority: 'https://user@cloud.example.test',
      providerAccountId: 'unsafe',
      authState: accountAuthStateSignedIn,
    );

    expect(scheduleCalendarProviderWebUri(nextcloud, mismatchedSource), isNull);
    expect(scheduleTaskProviderWebUri(unsafeAccount), isNull);
  });
}

AccountEntity _account(BusyProvider provider) {
  final id = '${provider.storageValue}:account';
  return AccountEntity(
    id: id,
    provider: provider,
    authority: switch (provider) {
      BusyProvider.google => 'https://accounts.google.com',
      BusyProvider.microsoft => 'https://login.microsoftonline.com/common',
      BusyProvider.appleICloud => 'https://caldav.icloud.com',
      BusyProvider.nextcloud => 'https://cloud.example.test/nextcloud',
      BusyProvider.webCal => 'https://calendar.example.test',
    },
    providerAccountId: 'account',
    authState: accountAuthStateSignedIn,
  );
}

TaskListEntity _taskList(String accountId, String title) {
  return TaskListEntity(
    accountId: accountId,
    id: 'list',
    title: title,
    localDirty: false,
    pendingDelete: false,
    rawJson: '{}',
  );
}

CalendarSourceEntity _calendarSource(
  AccountEntity account, {
  String providerCalendarId = 'calendar',
}) {
  return CalendarSourceEntity(
    id: 'source',
    accountId: account.id,
    provider: account.provider,
    providerCalendarId: providerCalendarId,
    summary: 'Calendar',
    selected: true,
    hidden: false,
    readOnly: false,
    isDeleted: false,
  );
}

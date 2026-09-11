import 'package:busymax/src/features/accounts/data/accounts_repository.dart';
import 'package:busymax/src/features/calendar/data/calendar_repository.dart';
import 'package:busymax/src/features/schedule/presentation/schedule_sidebar.dart';
import 'package:busymax/src/providers/busy_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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

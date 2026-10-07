import 'dart:async';
import 'package:busymax/src/app/app_bootstrap.dart';
import 'package:busymax/src/db/app_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../test_localized_app.dart';
import '../../../support/memory_settings_store.dart';
import 'package:busymax/src/features/accounts/data/accounts_repository.dart';
import 'package:busymax/src/features/calendar/data/calendar_repository.dart';
import 'package:busymax/src/features/schedule/presentation/schedule_sidebar.dart';
import 'package:busymax/src/providers/busy_provider.dart';
import 'package:busymax/src/schedule/schedule_sidebar_sources.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'sidebar tracks resolved authentication inventory and subscriptions',
    (tester) async {
      final database = AppDatabase.memoryForTests();
      addTearDown(database.close);
      final inventory = StreamController<List<AccountEntity>>();
      addTearDown(inventory.close);
      var opened = 0;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(database),
            accountsStreamProvider.overrideWith((ref) => inventory.stream),
            localSettingsStoreProvider.overrideWithValue(MemorySettingsStore()),
          ],
          child: localizedTestApp(
            child: Align(
              child: SizedBox(
                width: 300,
                child: ScheduleSidebar(
                  selectedDate: DateTime(2026, 10, 3),
                  firstWeekday: DateTime.monday,
                  items: const [],
                  onDateSelected: (_) {},
                  onMonthSelected: (_) {},
                  onYearSelected: (_) {},
                  onWeekSelected: (_) {},
                  onAddAccount: () => opened++,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Add account'), findsNothing);
      inventory.addError(StateError('account read failed'));
      await tester.pumpAndSettle();
      expect(find.text('Add account'), findsNothing);
      inventory.add(const []);
      await tester.pumpAndSettle();
      expect(find.text('Add account'), findsOneWidget);
      await tester.tap(find.text('Add account'));
      expect(opened, 1);
      inventory.add([_account(BusyProvider.google)]);
      await tester.pumpAndSettle();
      expect(find.text('Add account'), findsNothing);
      inventory.add(const []);
      await tester.pumpAndSettle();
      expect(find.text('Add account'), findsOneWidget);
      inventory.add([_account(BusyProvider.webCal)]);
      await tester.pumpAndSettle();
      expect(find.text('Add account'), findsOneWidget);
      expect(find.text('Subscriptions'), findsOneWidget);
      inventory.add([_account(BusyProvider.appleICloud)]);
      await tester.pumpAndSettle();
      expect(find.text('Add account'), findsNothing);
      inventory.add([
        _account(
          BusyProvider.microsoft,
          authState: accountAuthStateReauthRequired,
        ),
      ]);
      await tester.pumpAndSettle();
      expect(find.text('Add account'), findsNothing);
      inventory.addError(StateError('failed after inventory loaded'));
      await tester.pumpAndSettle();
      expect(find.text('Add account'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
  );

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

  test('desktop sidebars exclude provider-hidden and deleted calendars', () {
    final google = _account(BusyProvider.google);
    final microsoft = _account(BusyProvider.microsoft);

    final shown = calendarSourcesShownInSidebar([
      _calendarSource(google, id: 'visible'),
      _calendarSource(google, id: 'hidden', hidden: true),
      _calendarSource(google, id: 'deleted', isDeleted: true),
      _calendarSource(microsoft, id: 'other-account'),
    ], accountId: google.id);

    expect(shown.map((source) => source.id), ['visible']);
  });
}

AccountEntity _account(
  BusyProvider provider, {
  String authState = accountAuthStateSignedIn,
}) {
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
    authState: authState,
  );
}

CalendarSourceEntity _calendarSource(
  AccountEntity account, {
  String id = 'source',
  String providerCalendarId = 'calendar',
  bool hidden = false,
  bool isDeleted = false,
}) {
  return CalendarSourceEntity(
    id: id,
    accountId: account.id,
    provider: account.provider,
    providerCalendarId: providerCalendarId,
    summary: 'Calendar',
    selected: true,
    hidden: hidden,
    readOnly: false,
    isDeleted: isDeleted,
  );
}

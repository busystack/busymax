import 'package:busymax/l10n/generated/app_localizations.dart';
import 'package:busymax/src/app/app_bootstrap.dart';
import 'package:busymax/src/features/accounts/data/accounts_repository.dart';
import 'package:busymax/src/features/calendar/data/calendar_repository.dart';
import 'package:busymax/src/features/connectivity/network_connectivity_service.dart';
import 'package:busymax/src/providers/busy_provider.dart';
import 'package:busymax/src/ui/windows/windows_schedule_source_pane.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('calendar source exposes Fluent collection actions', (
    tester,
  ) async {
    final monitor = NetworkConnectivityMonitor(
      checkConnectivity: () async => const [ConnectivityResult.wifi],
      connectivityChanges: const Stream.empty(),
    );
    addTearDown(monitor.dispose);
    const account = AccountEntity(
      id: 'account-1',
      provider: BusyProvider.google,
      authority: 'https://accounts.google.com',
      providerAccountId: 'owner@example.test',
      authState: accountAuthStateSignedIn,
      displayName: 'Personal',
    );
    const source = CalendarSourceEntity(
      id: 'calendar-1',
      accountId: 'account-1',
      provider: BusyProvider.google,
      providerCalendarId: 'work@example.test',
      summary: 'Work calendar',
      selected: true,
      hidden: false,
      readOnly: false,
      isDeleted: false,
      dataOwner: 'owner@example.test',
      authenticatedAccountEmail: 'owner@example.test',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          networkConnectivityMonitorProvider.overrideWithValue(monitor),
        ],
        child: FluentApp(
          localizationsDelegates: const [AppLocalizations.delegate],
          supportedLocales: AppLocalizations.supportedLocales,
          home: SizedBox(
            width: 360,
            height: 720,
            child: WindowsScheduleSourcePane(
              selectedDate: DateTime(2026, 8, 31),
              accounts: const [account],
              calendarSources: const [source],
              taskLists: const [],
              visibleCalendarSourceIds: const {'calendar-1'},
              visibleTaskListKeys: const {},
              onDateSelected: (_) {},
              onCalendarVisibilityChanged: (_, _) {},
              onTaskListVisibilityChanged: (_, _) {},
              onSourcesChanged: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Work calendar'), findsOneWidget);
    expect(find.byType(DropDownButton), findsNWidgets(2));

    await tester.tap(find.byType(DropDownButton).last);
    await tester.pumpAndSettle();

    expect(find.text('Event reminders — On'), findsOneWidget);
    expect(find.text('Calendar color'), findsOneWidget);
    expect(find.text('Rename'), findsOneWidget);
    expect(find.text('Delete'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

import 'package:busymax/l10n/generated/app_localizations.dart';
import 'package:busymax/src/app/app_bootstrap.dart';
import 'package:busymax/src/features/accounts/data/accounts_repository.dart';
import 'package:busymax/src/features/calendar/data/calendar_repository.dart';
import 'package:busymax/src/features/connectivity/network_connectivity_service.dart';
import 'package:busymax/src/providers/busy_provider.dart';
import 'package:busymax/src/schedule/schedule_sidebar_order.dart';
import 'package:busymax/src/features/task_lists/data/task_lists_repository.dart';
import 'package:busymax/src/ui/common/busymax_glyph.dart';
import 'package:busymax/src/ui/windows/windows_busymax_glyphs.dart';
import 'package:busymax/src/ui/windows/windows_schedule_source_pane.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/memory_settings_store.dart';

void main() {
  for (final saved in [
    ['s1', 'a', 's2', 'b'],
    ['s1', 's2', 'b', 'a'],
  ]) {
    testWidgets('Fluent partitions and reorders saved account groups $saved', (
      tester,
    ) async {
      final store = MemorySettingsStore({
        'sidebarOrder': ScheduleSidebarOrder(accountIds: saved).toJson(),
      });
      final accounts = [
        _account('s1', BusyProvider.webCal),
        _account('a', BusyProvider.google),
        _account('s2', BusyProvider.webCal),
        _account('b', BusyProvider.microsoft),
      ];
      await _pumpPane(tester, store, accounts, const [], const []);
      accounts.add(_account('new', BusyProvider.nextcloud));
      await _pumpPane(tester, store, accounts, const [], const []);
      final authIds = [...saved.where((id) => !id.startsWith('s')), 'new'];
      void checkOrder(List<String> auth, List<String> subs) {
        _expectRows(tester, [
          for (final id in [...auth, ...subs]) ('schedule-account', id),
        ]);
        final heading = tester.getTopLeft(find.text('Subscriptions')).dy;
        for (final id in auth) {
          expect(
            tester.getTopLeft(_row(('schedule-account', id))).dy,
            lessThan(heading),
          );
        }
        for (final id in subs) {
          expect(
            tester.getTopLeft(_row(('schedule-account', id))).dy,
            greaterThan(heading),
          );
        }
        expect(find.text('Subscriptions'), findsOneWidget);
        expect(find.text('Add account'), findsNothing);
      }

      MenuFlyoutItem movement(String id, String label) => tester
          .widget<DropDownButton>(
            find.descendant(
              of: _row(('schedule-account', id)),
              matching: find.byType(DropDownButton),
            ),
          )
          .items
          .whereType<MenuFlyoutItem>()
          .singleWhere((item) => (item.text as Text).data == label);
      checkOrder(authIds, ['s1', 's2']);
      expect(movement(authIds.first, 'Move up').onPressed, isNull);
      expect(movement('new', 'Move down').onPressed, isNull);
      expect(movement('s1', 'Move up').onPressed, isNull);
      expect(movement('s2', 'Move down').onPressed, isNull);
      await tester.tap(
        find.descendant(
          of: _row(('schedule-account', authIds.first)),
          matching: find.byType(DropDownButton),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Move down').last);
      await tester.pumpAndSettle();
      final moved = [authIds[1], authIds[0], 'new'];
      checkOrder(moved, ['s1', 's2']);
      await tester.tap(
        find.descendant(
          of: _row(('schedule-account', 's2')),
          matching: find.byType(DropDownButton),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Move up').last);
      await tester.pumpAndSettle();
      checkOrder(moved, ['s2', 's1']);
      await tester.pumpWidget(const SizedBox.shrink());
      await _pumpPane(tester, store, accounts, const [], const []);
      checkOrder(moved, ['s2', 's1']);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets(
    'Fluent Add account uses resolved inventory and keeps subscription identity',
    (tester) async {
      var opened = 0;
      await _pumpPane(
        tester,
        MemorySettingsStore(),
        const [],
        const [],
        const [],
        onAddAccount: () => opened++,
      );
      expect(find.text('Add account'), findsOneWidget);
      await tester.tap(find.text('Add account'));
      expect(opened, 1);
      await _pumpPane(
        tester,
        MemorySettingsStore(),
        const [],
        const [],
        const [],
        accountInventoryResolved: false,
      );
      expect(find.text('Add account'), findsNothing);
      await _pumpPane(
        tester,
        MemorySettingsStore(),
        [_account('webcal', BusyProvider.webCal)],
        const [],
        const [],
      );
      expect(find.text('Add account'), findsOneWidget);
      expect(find.text('Subscriptions'), findsOneWidget);
      for (final provider in [BusyProvider.appleICloud, BusyProvider.google]) {
        await _pumpPane(
          tester,
          MemorySettingsStore(),
          [
            _account(
              'configured',
              provider,
              authState: accountAuthStateReauthRequired,
            ),
          ],
          const [],
          const [],
        );
        expect(find.text('Add account'), findsNothing);
      }
    },
  );

  testWidgets(
    'Fluent source rows use distinct type icons and actual collection titles',
    (tester) async {
      final store = MemorySettingsStore();
      final account = _account('account', BusyProvider.google);
      await _pumpPane(
        tester,
        store,
        [account],
        [
          _calendar(
            account.id,
            'calendar',
            title: 'Work',
            backgroundColor: '#123456',
          ),
        ],
        [_list(account.id, 'tasks', title: 'Work')],
      );

      final calendarRow = _row(('schedule-calendar', account.id, 'calendar'));
      final taskListRow = _row(('schedule-task-list', account.id, 'tasks'));
      final calendarIcon = tester.widget<Icon>(
        find.descendant(
          of: calendarRow,
          matching: find.byIcon(windowsBusyMaxGlyph(BusyMaxGlyph.calendar)),
        ),
      );

      expect(calendarIcon.color, const Color(0xff123456));
      expect(
        find.descendant(
          of: taskListRow,
          matching: find.byIcon(windowsBusyMaxGlyph(BusyMaxGlyph.task)),
        ),
        findsOneWidget,
      );
      expect(find.text('Work'), findsNWidgets(2));
      expect(find.textContaining('Google Tasks ·'), findsNothing);
      expect(find.text('Calendars'), findsNothing);
      expect(find.text('Task lists'), findsNothing);
    },
  );

  testWidgets(
    'Fluent menus move siblings locally, retain state and persist across restart',
    (tester) async {
      final store = MemorySettingsStore();
      final accounts = [
        _account('a', BusyProvider.appleICloud),
        _account('b', BusyProvider.google),
      ];
      final calendars = [
        _calendar('a', 'c1'),
        _calendar('a', 'c2'),
        _calendar('b', 'c3'),
      ];
      final lists = [_list('a', 'l1'), _list('a', 'l2'), _list('b', 'l1')];
      await _pumpPane(tester, store, accounts, calendars, lists);
      DropDownButton menu(Object key) => tester.widget(
        find.descendant(of: _row(key), matching: find.byType(DropDownButton)),
      );
      MenuFlyoutItem entry(Object key, String label) => menu(key).items
          .whereType<MenuFlyoutItem>()
          .singleWhere((item) => (item.text as Text).data == label);
      const firstCalendar = ('schedule-calendar', 'a', 'c1');
      const lastCalendar = ('schedule-calendar', 'a', 'c2');
      expect(entry(firstCalendar, 'Move up').onPressed, isNull);
      expect(entry(lastCalendar, 'Move down').onPressed, isNull);
      expect(menu(('schedule-account', 'a')).items, hasLength(2));
      final originalElement = tester.element(
        find.byKey(const ValueKey(lastCalendar)),
      );
      await tester.tap(
        find.descendant(
          of: find.byKey(const ValueKey(lastCalendar)),
          matching: find.byType(DropDownButton),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Move up'));
      await tester.pumpAndSettle();
      _expectRows(tester, [
        lastCalendar,
        firstCalendar,
        ('schedule-calendar', 'b', 'c3'),
      ]);
      expect(
        tester.element(find.byKey(const ValueKey(lastCalendar))),
        same(originalElement),
      );
      expect(
        tester
            .widget<Checkbox>(
              find.descendant(
                of: find.byKey(const ValueKey(lastCalendar)),
                matching: find.byType(Checkbox),
              ),
            )
            .checked,
        isFalse,
      );
      entry(('schedule-task-list', 'a', 'l2'), 'Move up').onPressed!();
      await tester.pumpAndSettle();
      _expectRows(tester, [
        ('schedule-task-list', 'a', 'l2'),
        ('schedule-task-list', 'a', 'l1'),
        ('schedule-task-list', 'b', 'l1'),
      ]);
      expect(
        entry(('schedule-task-list', 'b', 'l1'), 'Move down').onPressed,
        isNull,
      );
      expect(entry(('schedule-account', 'a'), 'Move up').onPressed, isNull);
      entry(('schedule-account', 'a'), 'Move down').onPressed!();
      await tester.pumpAndSettle();
      _expectRows(tester, [
        ('schedule-account', 'b'),
        ('schedule-account', 'a'),
      ]);
      await tester.pumpWidget(const SizedBox.shrink());
      await _pumpPane(tester, store, accounts, calendars, lists);
      _expectRows(tester, [
        ('schedule-account', 'b'),
        ('schedule-account', 'a'),
      ]);
      _expectRows(tester, [lastCalendar, firstCalendar]);
      _expectRows(tester, [
        ('schedule-task-list', 'a', 'l2'),
        ('schedule-task-list', 'a', 'l1'),
      ]);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Fluent ordering survives rename, additions, missing and hidden sources and replacement',
    (tester) async {
      final store = MemorySettingsStore();
      final accounts = [_account('a', BusyProvider.google)];
      await _pumpPane(
        tester,
        store,
        accounts,
        [_calendar('a', 'c2'), _calendar('a', 'c1')],
        [_list('a', 'l2'), _list('a', 'l1')],
      );
      await _pumpPane(
        tester,
        store,
        accounts,
        [
          _calendar('a', 'c1', title: 'Renamed'),
          _calendar('a', 'c2'),
          _calendar('a', 'c3'),
        ],
        [_list('a', 'l1'), _list('a', 'l2'), _list('a', 'l3')],
      );
      _expectRows(tester, [
        ('schedule-calendar', 'a', 'c2'),
        ('schedule-calendar', 'a', 'c1'),
        ('schedule-calendar', 'a', 'c3'),
      ]);
      _expectRows(tester, [
        ('schedule-task-list', 'a', 'l2'),
        ('schedule-task-list', 'a', 'l1'),
        ('schedule-task-list', 'a', 'l3'),
      ]);
      expect(find.text('Renamed'), findsOneWidget);
      await _pumpPane(
        tester,
        store,
        accounts,
        [_calendar('a', 'c3'), _calendar('a', 'c2', hidden: true)],
        [_list('a', 'l3'), _list('a', 'l2')],
      );
      expect(
        find.byKey(const ValueKey(('schedule-calendar', 'a', 'c1'))),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey(('schedule-calendar', 'a', 'c2'))),
        findsNothing,
      );
      _expectRows(tester, [
        ('schedule-task-list', 'a', 'l2'),
        ('schedule-task-list', 'a', 'l3'),
      ]);
      final controller = ProviderScope.containerOf(
        tester.element(find.byType(WindowsScheduleSourcePane)),
      ).read(appSettingsControllerProvider.notifier);
      controller.replaceSidebarId(
        SidebarOrderSection.calendars,
        'c2',
        'server',
        accountId: 'a',
      );
      controller.replaceSidebarId(
        SidebarOrderSection.taskLists,
        'l2',
        'server',
        accountId: 'a',
      );
      await _pumpPane(
        tester,
        store,
        accounts,
        [_calendar('a', 'c3'), _calendar('a', 'server')],
        [_list('a', 'l3'), _list('a', 'server')],
      );
      _expectRows(tester, [
        ('schedule-calendar', 'a', 'server'),
        ('schedule-calendar', 'a', 'c3'),
      ]);
      _expectRows(tester, [
        ('schedule-task-list', 'a', 'server'),
        ('schedule-task-list', 'a', 'l3'),
      ]);
      expect(tester.takeException(), isNull);
    },
  );

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
          localSettingsStoreProvider.overrideWithValue(MemorySettingsStore()),
          networkConnectivityMonitorProvider.overrideWithValue(monitor),
        ],
        child: FluentApp(
          localizationsDelegates: const [AppLocalizations.delegate],
          supportedLocales: AppLocalizations.supportedLocales,
          home: SizedBox(
            width: 360,
            height: 720,
            child: WindowsScheduleSourcePane(
              firstWeekday: DateTime.monday,
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

Future<void> _pumpPane(
  WidgetTester tester,
  MemorySettingsStore store,
  List<AccountEntity> accounts,
  List<CalendarSourceEntity> calendars,
  List<TaskListEntity> lists, {
  VoidCallback? onAddAccount,
  bool accountInventoryResolved = true,
}) async {
  tester.view.physicalSize = const Size(900, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final monitor = NetworkConnectivityMonitor(
    checkConnectivity: () async => const [ConnectivityResult.none],
    connectivityChanges: const Stream.empty(),
  );
  addTearDown(monitor.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        localSettingsStoreProvider.overrideWithValue(store),
        networkConnectivityMonitorProvider.overrideWithValue(monitor),
      ],
      child: FluentApp(
        localizationsDelegates: const [AppLocalizations.delegate],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 360,
            height: 1100,
            child: WindowsScheduleSourcePane(
              firstWeekday: DateTime.monday,
              selectedDate: DateTime(2026, 9, 5),
              accounts: accounts,
              onAddAccount: onAddAccount,
              accountInventoryResolved: accountInventoryResolved,
              calendarSources: calendars,
              taskLists: lists,
              visibleCalendarSourceIds: const {},
              visibleTaskListKeys: const {},
              onDateSelected: (_) {},
              onCalendarVisibilityChanged: (_, _) =>
                  fail('Movement changed visibility'),
              onTaskListVisibilityChanged: (_, _) =>
                  fail('Movement changed visibility'),
              onSourcesChanged: () => fail('Movement requested a refresh'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Finder _row(Object value) => find.byWidgetPredicate(
  (widget) =>
      widget.key is ValueKey && (widget.key! as ValueKey).value == value,
);

void _expectRows(WidgetTester tester, List<Object> keys) {
  for (var index = 1; index < keys.length; index++) {
    expect(
      tester.getTopLeft(_row(keys[index - 1])).dy,
      lessThan(tester.getTopLeft(_row(keys[index])).dy),
    );
  }
}

AccountEntity _account(
  String id,
  BusyProvider provider, {
  String authState = accountAuthStateSignedIn,
}) => AccountEntity(
  id: id,
  provider: provider,
  authority: 'https://example.test',
  providerAccountId: id,
  authState: authState,
  displayName: id,
);

CalendarSourceEntity _calendar(
  String accountId,
  String id, {
  String? title,
  bool hidden = false,
  String? backgroundColor,
}) => CalendarSourceEntity(
  id: id,
  accountId: accountId,
  provider: BusyProvider.google,
  providerCalendarId: id,
  summary: title ?? id,
  selected: false,
  hidden: hidden,
  readOnly: true,
  isDeleted: false,
  backgroundColor: backgroundColor,
);

TaskListEntity _list(String accountId, String id, {String? title}) =>
    TaskListEntity(
      accountId: accountId,
      id: id,
      title: title ?? id,
      localDirty: false,
      pendingDelete: false,
      rawJson: '{}',
    );

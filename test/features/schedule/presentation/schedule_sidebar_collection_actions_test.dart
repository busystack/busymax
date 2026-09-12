import 'dart:async';

import 'package:busymax/src/app/app_bootstrap.dart';
import 'package:busymax/src/schedule/schedule_sidebar_order.dart';
import 'package:busymax/src/schedule/schedule_sidebar_sources.dart';
import 'package:busymax/src/app/busymax_design.dart';
import 'package:busymax/src/app/busymax_yaru_theme.dart';
import 'package:busymax/src/features/accounts/data/accounts_repository.dart';
import 'package:busymax/src/features/calendar/data/calendar_repository.dart';
import 'package:busymax/src/features/calendar/data/calendar_collection_creation_service.dart';
import 'package:busymax/src/features/connectivity/network_connectivity_service.dart';
import 'package:busymax/src/features/schedule/presentation/schedule_sidebar.dart';
import 'package:busymax/src/features/task_lists/data/task_lists_repository.dart';
import 'package:busymax/src/platform/native_menu_service.dart';
import 'package:busymax/src/providers/busy_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yaru/yaru.dart';

import '../../../test_localized_app.dart';
import '../../../support/memory_settings_store.dart';

const _nativeMenuChannel = MethodChannel(nativeMenuChannelName);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          _nativeMenuChannel,
          (_) async => throw MissingPluginException(),
        );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_nativeMenuChannel, null);
  });

  testWidgets(
    'source rows use type icons and task lists keep their actual titles',
    (tester) async {
      final account = _account(BusyProvider.google, id: 'account');
      await _pumpSidebar(
        tester,
        [account],
        calendarSources: [
          _calendar(
            account.id,
            'calendar',
            title: 'Work',
            backgroundColor: '#123456',
          ),
        ],
        taskLists: [_list(account.id, 'tasks', title: 'Work')],
        networkAvailability: NetworkAvailability.offline,
      );

      final calendarRow = _row(('schedule-calendar', account.id, 'calendar'));
      final taskListRow = _row(('schedule-task-list', account.id, 'tasks'));
      final calendarIcon = tester.widget<Icon>(
        find.descendant(
          of: calendarRow,
          matching: find.byIcon(YaruIcons.calendar),
        ),
      );

      expect(calendarIcon.color, const Color(0xff123456));
      expect(
        find.descendant(
          of: taskListRow,
          matching: find.byIcon(YaruIcons.task_list),
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
    'sidebar moves adjacent siblings locally and restores order after restart',
    (tester) async {
      final store = MemorySettingsStore();
      final accounts = [
        _account(BusyProvider.appleICloud, id: 'a'),
        _account(BusyProvider.google, id: 'b'),
      ];
      final calendars = [
        _calendar('a', 'c1'),
        _calendar('a', 'c2'),
        _calendar('b', 'c3'),
      ];
      final lists = [_list('a', 'l1'), _list('a', 'l2'), _list('b', 'l1')];
      await _pumpSidebar(
        tester,
        accounts,
        calendarSources: calendars,
        taskLists: lists,
        settingsStore: store,
        height: 1100,
        networkAvailability: NetworkAvailability.offline,
      );
      BusyMaxMenuButton<String> calendarMenu(String id) =>
          tester.widget(find.byKey(ValueKey(('calendar-options', id))));
      expect(
        calendarMenu(
          'c1',
        ).entries.singleWhere((entry) => entry.value == 'move-up').enabled,
        isFalse,
      );
      expect(
        calendarMenu(
          'c2',
        ).entries.singleWhere((entry) => entry.value == 'move-down').enabled,
        isFalse,
      );
      final beforeElement = tester.element(
        find.byKey(const ValueKey(('schedule-calendar', 'a', 'c2'))),
      );
      await tester.tap(find.byKey(const ValueKey(('calendar-options', 'c2'))));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Move up'));
      await tester.pumpAndSettle();
      _expectRows(tester, [
        ('schedule-calendar', 'a', 'c2'),
        ('schedule-calendar', 'a', 'c1'),
        ('schedule-calendar', 'b', 'c3'),
      ]);
      expect(
        tester.element(
          find.byKey(const ValueKey(('schedule-calendar', 'a', 'c2'))),
        ),
        same(beforeElement),
      );
      final taskMenu = tester.widget<BusyMaxMenuButton<String>>(
        find.byKey(const ValueKey(('task-list-options', 'a', 'l2'))),
      );
      taskMenu.onSelected('move-up');
      await tester.pumpAndSettle();
      _expectRows(tester, [
        ('schedule-task-list', 'a', 'l2'),
        ('schedule-task-list', 'a', 'l1'),
        ('schedule-task-list', 'b', 'l1'),
      ]);
      await tester.tap(find.byKey(const ValueKey(('account-collapse', 'a'))));
      await tester.pumpAndSettle();
      final header = tester
          .widget<BusyMaxMenuButton<AccountHeaderCollectionAction>>(
            find.byKey(const ValueKey(('account-collection-options', 'a'))),
          );
      expect(
        header.entries
            .singleWhere(
              (entry) => entry.value == AccountHeaderCollectionAction.moveDown,
            )
            .enabled,
        isTrue,
      );
      header.onSelected(AccountHeaderCollectionAction.moveDown);
      await tester.pumpAndSettle();
      _expectRows(tester, [
        ('schedule-account', 'b'),
        ('schedule-account', 'a'),
      ]);
      expect(
        find.byKey(const ValueKey(('schedule-calendar', 'a', 'c2'))),
        findsNothing,
      );
      expect(
        AppSettings.fromJson(
          store.value,
        ).isTaskListVisibleInSchedule('a', 'l2'),
        isTrue,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await _pumpSidebar(
        tester,
        accounts.reversed.toList(),
        calendarSources: calendars.reversed.toList(),
        taskLists: lists.reversed.toList(),
        settingsStore: store,
        height: 1100,
      );
      _expectRows(tester, [
        ('schedule-account', 'b'),
        ('schedule-account', 'a'),
      ]);
      _expectRows(tester, [
        ('schedule-calendar', 'a', 'c2'),
        ('schedule-calendar', 'a', 'c1'),
      ]);
      _expectRows(tester, [
        ('schedule-task-list', 'a', 'l2'),
        ('schedule-task-list', 'a', 'l1'),
      ]);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'collapsed accounts register snapshots and survive rename, sync, removals and ID replacement',
    (tester) async {
      final calendars =
          StreamController<List<CalendarSourceEntity>>.broadcast();
      final lists = StreamController<List<TaskListEntity>>.broadcast();
      addTearDown(calendars.close);
      addTearDown(lists.close);
      final store = MemorySettingsStore();
      await _pumpSidebar(
        tester,
        [_account(BusyProvider.google, id: 'a')],
        calendarSnapshots: calendars.stream,
        taskSnapshots: lists.stream,
        settingsStore: store,
      );
      await tester.tap(find.byKey(const ValueKey(('account-collapse', 'a'))));
      await tester.pumpAndSettle();
      calendars.add([_calendar('a', 'c2'), _calendar('a', 'c1')]);
      lists.add([_list('a', 'l2'), _list('a', 'l1')]);
      await tester.pumpAndSettle();
      expect(
        AppSettings.fromJson(
          store.value,
        ).sidebarOrder.calendarSourceIdsByAccount['a'],
        ['c2', 'c1'],
      );
      expect(
        AppSettings.fromJson(
          store.value,
        ).sidebarOrder.taskListIdsByAccount['a'],
        ['l2', 'l1'],
      );
      calendars.add([
        _calendar('a', 'c1', title: 'Renamed'),
        _calendar('a', 'c2'),
        _calendar('a', 'c3'),
      ]);
      lists.add([_list('a', 'l1'), _list('a', 'l2'), _list('a', 'l3')]);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey(('account-collapse', 'a'))));
      await tester.pumpAndSettle();
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
      final controller = ProviderScope.containerOf(
        tester.element(find.byType(ScheduleSidebar)),
      ).read(appSettingsControllerProvider.notifier);
      unawaited(
        controller.replaceSidebarId(
          SidebarOrderSection.calendars,
          'c2',
          'server',
          accountId: 'a',
        ),
      );
      unawaited(
        controller.replaceSidebarId(
          SidebarOrderSection.taskLists,
          'l2',
          'server',
          accountId: 'a',
        ),
      );
      calendars.add([_calendar('a', 'c3'), _calendar('a', 'server')]);
      lists.add([_list('a', 'l3'), _list('a', 'server')]);
      await tester.pumpAndSettle();
      _expectRows(tester, [
        ('schedule-calendar', 'a', 'server'),
        ('schedule-calendar', 'a', 'c3'),
      ]);
      _expectRows(tester, [
        ('schedule-task-list', 'a', 'server'),
        ('schedule-task-list', 'a', 'l3'),
      ]);
      expect(find.text('Renamed'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'subscription rows move within the existing subscriptions section',
    (tester) async {
      await _pumpSidebar(
        tester,
        [_account(BusyProvider.webCal, id: 'feed')],
        calendarSources: [
          _calendar('feed', 's1', provider: BusyProvider.webCal),
          _calendar('feed', 's2', provider: BusyProvider.webCal),
        ],
      );
      final menu = tester.widget<BusyMaxMenuButton<String>>(
        find.byKey(const ValueKey(('subscription-options', 's2'))),
      );
      expect(
        menu.entries.singleWhere((entry) => entry.value == 'move-down').enabled,
        isFalse,
      );
      menu.onSelected('move-up');
      await tester.pumpAndSettle();
      _expectRows(tester, [
        ('subscription-source', 's2'),
        ('subscription-source', 's1'),
      ]);
      expect(find.text('Subscriptions'), findsOneWidget);
      expect(
        find.byKey(const ValueKey(('schedule-account', 'feed'))),
        findsNothing,
      );
    },
  );

  testWidgets('Google, Microsoft, and Nextcloud headers expose both actions', (
    tester,
  ) async {
    for (final provider in [
      BusyProvider.google,
      BusyProvider.microsoft,
      BusyProvider.nextcloud,
    ]) {
      await _pumpSidebar(tester, [_account(provider)]);

      expect(find.byTooltip('Options'), findsOneWidget);
      await tester.tap(find.byTooltip('Options'));
      await tester.pumpAndSettle();
      expect(find.text('New calendar…'), findsOneWidget);
      expect(find.text('New task list…'), findsOneWidget);

      await tester.tapAt(const Offset(790, 790));
      await tester.pumpAndSettle();
    }
  });

  testWidgets(
    'same-email accounts use provider-derived indicators and semantics',
    (tester) async {
      final semantics = tester.ensureSemantics();
      const email = 'shared@example.test';
      await _pumpSidebar(tester, [
        _account(
          BusyProvider.google,
          id: 'google-shared',
          displayName: 'Shared account',
          email: email,
        ),
        _account(
          BusyProvider.microsoft,
          id: 'microsoft-shared',
          displayName: 'Shared account',
          email: email,
        ),
        _account(
          BusyProvider.nextcloud,
          id: 'nextcloud-shared',
          displayName: 'Shared account',
          email: email,
        ),
      ]);

      for (final expected in const [
        ('google-shared', 'G', 'Google'),
        ('microsoft-shared', 'M', 'Microsoft'),
        ('nextcloud-shared', 'N', 'Nextcloud'),
      ]) {
        final indicator = find.byKey(
          ValueKey(('account-provider-indicator', expected.$1)),
        );
        expect(indicator, findsOneWidget);
        expect(
          find.descendant(of: indicator, matching: find.text(expected.$2)),
          findsOneWidget,
        );
        expect(
          tester
              .widget<Tooltip>(
                find.descendant(of: indicator, matching: find.byType(Tooltip)),
              )
              .message,
          expected.$3,
        );
        expect(
          find.bySemanticsLabel('${expected.$3}, Shared account, $email'),
          findsOneWidget,
        );
      }
      semantics.dispose();
    },
  );

  testWidgets('Nextcloud uses its server host when email is unavailable', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await _pumpSidebar(tester, [
      _account(
        BusyProvider.nextcloud,
        id: 'nextcloud-custom-port',
        authority:
            'https://cloud.example.test:8443/nextcloud/index.php?token=secret',
        displayName: 'albert',
      ),
      _account(
        BusyProvider.nextcloud,
        id: 'nextcloud-default-port',
        authority: 'https://work.example.test:443/nextcloud',
        displayName: 'work-user',
      ),
    ]);

    expect(find.text('cloud.example.test:8443'), findsOneWidget);
    expect(find.text('work.example.test'), findsOneWidget);
    expect(find.textContaining('/nextcloud'), findsNothing);
    expect(find.textContaining('token=secret'), findsNothing);
    expect(
      find.bySemanticsLabel('Nextcloud, albert, cloud.example.test:8443'),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel('Nextcloud, work-user, work.example.test'),
      findsOneWidget,
    );
    semantics.dispose();
  });

  testWidgets(
    'provider indicator stays visible with truncated text in both themes',
    (tester) async {
      for (final brightness in [Brightness.light, Brightness.dark]) {
        final theme = BusyMaxYaruTheme.build(
          brightness: brightness,
          accentColor: const Color(0xFFE95464),
        );
        const accountId = 'google-long';
        const displayName =
            'A very long account display name that must be truncated';
        const email = 'a-very-long-address-for-sidebar@example.test';
        await _pumpSidebar(
          tester,
          [
            _account(
              BusyProvider.google,
              id: accountId,
              displayName: displayName,
              email: email,
            ),
          ],
          theme: theme,
          width: 240,
        );

        final indicator = find.byKey(
          const ValueKey(('account-provider-indicator', accountId)),
        );
        final indicatorRect = tester.getRect(indicator);
        expect(indicatorRect.size, const Size.square(16));
        expect(indicatorRect.left, greaterThanOrEqualTo(0));
        expect(indicatorRect.right, lessThanOrEqualTo(240));
        final decoration =
            tester
                    .widget<DecoratedBox>(
                      find.descendant(
                        of: indicator,
                        matching: find.byType(DecoratedBox),
                      ),
                    )
                    .decoration
                as BoxDecoration;
        final indicatorContext = tester.element(indicator);
        final colorScheme = Theme.of(indicatorContext).colorScheme;
        expect(decoration.shape, BoxShape.circle);
        expect(decoration.color, colorScheme.surfaceContainerHighest);
        final letter = tester.widget<Text>(
          find.descendant(of: indicator, matching: find.text('G')),
        );
        expect(letter.style?.color, colorScheme.onSurface);

        final name = tester.widget<Text>(find.text(displayName));
        final address = tester.widget<Text>(find.text(email));
        expect(name.maxLines, 1);
        expect(name.overflow, TextOverflow.ellipsis);
        expect(address.maxLines, 1);
        expect(address.overflow, TextOverflow.ellipsis);
        final nameRect = tester.getRect(find.text(displayName));
        final addressRect = tester.getRect(find.text(email));
        expect(nameRect.top, lessThan(addressRect.top));
        expect(nameRect.left, closeTo(addressRect.left, 0.01));
        expect(addressRect.right, lessThan(indicatorRect.left));
        expect(addressRect.center.dy, closeTo(indicatorRect.center.dy, 0.01));

        await tester.tap(
          find.byKey(const ValueKey(('account-collapse', accountId))),
        );
        await tester.pumpAndSettle();
        expect(indicator, findsOneWidget);
        expect(tester.getRect(indicator).size, const Size.square(16));
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets('Apple receives local ordering without creation actions', (
    tester,
  ) async {
    await _pumpSidebar(tester, [_account(BusyProvider.appleICloud)]);

    expect(find.byTooltip('Options'), findsOneWidget);
    final menu = tester
        .widget<BusyMaxMenuButton<AccountHeaderCollectionAction>>(
          find.byKey(
            const ValueKey((
              'account-collection-options',
              'apple_icloud-account',
            )),
          ),
        );
    expect(menu.entries.map((entry) => entry.label), ['Move up', 'Move down']);
    expect(menu.entries.every((entry) => !entry.enabled), isTrue);
    expect(find.text('No calendars synced yet.'), findsOneWidget);
    expect(find.text('No task lists synced yet.'), findsOneWidget);
  });

  testWidgets('WebCal is not rendered as a normal provider account group', (
    tester,
  ) async {
    await _pumpSidebar(tester, [_account(BusyProvider.webCal)]);

    expect(find.text('Subscriptions'), findsOneWidget);
    expect(find.text('WebCal account'), findsNothing);
    expect(find.byTooltip('Options'), findsNothing);
  });

  testWidgets('Options remains available while collapsed and does not toggle', (
    tester,
  ) async {
    const accountId = 'google-account';
    await _pumpSidebar(tester, [_account(BusyProvider.google, id: accountId)]);

    expect(find.text('No calendars synced yet.'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey(('account-collapse', accountId))),
    );
    await tester.pumpAndSettle();
    expect(find.text('No calendars synced yet.'), findsNothing);
    expect(find.byTooltip('Options'), findsOneWidget);

    await tester.tap(find.byTooltip('Options'));
    await tester.pumpAndSettle();
    expect(find.text('New calendar…'), findsOneWidget);
    expect(find.text('No calendars synced yet.'), findsNothing);
  });

  testWidgets('creation actions stay in the header for empty accounts', (
    tester,
  ) async {
    await _pumpSidebar(tester, [_account(BusyProvider.google)]);

    expect(find.text('No calendars synced yet.'), findsOneWidget);
    expect(find.text('No task lists synced yet.'), findsOneWidget);
    expect(
      find.byKey(const ValueKey(('new-calendar', 'google-account'))),
      findsNothing,
    );
    expect(find.text('New calendar'), findsNothing);
    expect(find.text('New task list'), findsNothing);

    await tester.tap(find.byTooltip('Options'));
    await tester.pumpAndSettle();
    expect(find.text('New calendar…'), findsOneWidget);
    expect(find.text('New task list…'), findsOneWidget);
  });

  testWidgets('service switches omit only the disabled collection action', (
    tester,
  ) async {
    await _pumpSidebar(tester, [
      _account(
        BusyProvider.google,
        calendarsEnabled: false,
        tasksEnabled: true,
      ),
    ]);

    await tester.tap(find.byTooltip('Options'));
    await tester.pumpAndSettle();
    expect(find.text('New calendar…'), findsNothing);
    expect(find.text('New task list…'), findsOneWidget);
  });

  testWidgets('offline Nextcloud keeps actions visible but disabled', (
    tester,
  ) async {
    await _pumpSidebar(tester, [
      _account(BusyProvider.nextcloud),
    ], networkAvailability: NetworkAvailability.offline);
    final menu = tester
        .widget<BusyMaxMenuButton<AccountHeaderCollectionAction>>(
          find.byKey(
            const ValueKey(('account-collection-options', 'nextcloud-account')),
          ),
        );

    expect(menu.entries, hasLength(5));
    expect(menu.entries.every((entry) => !entry.enabled), isTrue);
  });

  testWidgets('active creation disables repeat activation and runs once', (
    tester,
  ) async {
    final creationService = _FakeCalendarCollectionCreationService();
    await _pumpSidebar(tester, [
      _account(BusyProvider.google),
    ], creationService: creationService);

    await tester.tap(find.byTooltip('Options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('New calendar…'));
    await tester.pumpAndSettle();

    final menu = tester
        .widget<BusyMaxMenuButton<AccountHeaderCollectionAction>>(
          find.byKey(
            const ValueKey(('account-collection-options', 'google-account')),
          ),
        );
    expect(
      menu.entries
          .singleWhere(
            (entry) => entry.value == AccountHeaderCollectionAction.newCalendar,
          )
          .enabled,
      isFalse,
    );

    await tester.enterText(find.byType(TextField), 'One calendar');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(creationService.titles, ['One calendar']);
  });

  testWidgets('header Options supports keyboard activation', (tester) async {
    await _pumpSidebar(tester, [_account(BusyProvider.google)]);
    final menuFinder = find.byKey(
      const ValueKey(('account-collection-options', 'google-account')),
    );
    final focusFinder = find
        .descendant(of: menuFinder, matching: find.byType(Focus))
        .first;
    tester.widget<Focus>(focusFinder).focusNode?.requestFocus();
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    expect(find.text('New calendar…'), findsOneWidget);
    expect(find.text('New task list…'), findsOneWidget);
  });

  testWidgets('account-header controls follow RTL without overlap', (
    tester,
  ) async {
    await _pumpSidebar(tester, [
      _account(BusyProvider.google),
    ], locale: const Locale('ar'));
    final options = find.byKey(
      const ValueKey(('account-collection-options', 'google-account')),
    );
    final collapse = find.byKey(
      const ValueKey(('account-collapse', 'google-account')),
    );

    expect(Directionality.of(tester.element(options)), TextDirection.rtl);
    expect(tester.getRect(options).overlaps(tester.getRect(collapse)), isFalse);
  });

  testWidgets('calendar reminder actions show their current state', (
    tester,
  ) async {
    await _pumpSidebar(
      tester,
      [_account(BusyProvider.google)],
      calendarSources: const [
        CalendarSourceEntity(
          id: 'reminders-on',
          accountId: 'google-account',
          provider: BusyProvider.google,
          providerCalendarId: 'on',
          summary: 'Reminders on',
          selected: true,
          remindersEnabled: true,
          hidden: false,
          readOnly: false,
          isDeleted: false,
        ),
        CalendarSourceEntity(
          id: 'reminders-off',
          accountId: 'google-account',
          provider: BusyProvider.google,
          providerCalendarId: 'off',
          summary: 'Reminders off',
          selected: true,
          remindersEnabled: false,
          hidden: false,
          readOnly: false,
          isDeleted: false,
        ),
      ],
    );

    final enabledEntry = tester
        .widget<BusyMaxMenuButton<String>>(
          find.byKey(const ValueKey(('calendar-options', 'reminders-on'))),
        )
        .entries
        .singleWhere((entry) => entry.value == 'toggle-reminders');
    expect(enabledEntry.label, 'Event reminders — On');
    expect(enabledEntry.icon, Icons.notifications_outlined);
    expect(enabledEntry.role, BusyMaxMenuEntryRole.command);
    expect(enabledEntry.selected, isFalse);

    final disabledEntry = tester
        .widget<BusyMaxMenuButton<String>>(
          find.byKey(const ValueKey(('calendar-options', 'reminders-off'))),
        )
        .entries
        .singleWhere((entry) => entry.value == 'toggle-reminders');
    expect(disabledEntry.label, 'Event reminders — Off');
    expect(disabledEntry.icon, Icons.notifications_off_outlined);
    expect(disabledEntry.role, BusyMaxMenuEntryRole.command);
    expect(disabledEntry.selected, isFalse);
  });

  testWidgets('task-list reminder actions show their current state', (
    tester,
  ) async {
    await _pumpSidebar(
      tester,
      [_account(BusyProvider.google)],
      taskLists: const [
        TaskListEntity(
          accountId: 'google-account',
          id: 'reminders-on',
          title: 'Reminders on',
          localDirty: false,
          pendingDelete: false,
          rawJson: '{}',
        ),
        TaskListEntity(
          accountId: 'google-account',
          id: 'reminders-off',
          title: 'Reminders off',
          localDirty: false,
          pendingDelete: false,
          rawJson: '{}',
          remindersEnabled: false,
        ),
      ],
    );

    final enabledEntry = tester
        .widget<BusyMaxMenuButton<String>>(
          find.byKey(
            const ValueKey((
              'task-list-options',
              'google-account',
              'reminders-on',
            )),
          ),
        )
        .entries
        .singleWhere((entry) => entry.value == 'toggle-reminders');
    expect(enabledEntry.label, 'Task reminders — On');
    expect(enabledEntry.icon, Icons.notifications_outlined);
    expect(enabledEntry.role, BusyMaxMenuEntryRole.command);
    expect(enabledEntry.selected, isFalse);

    final disabledEntry = tester
        .widget<BusyMaxMenuButton<String>>(
          find.byKey(
            const ValueKey((
              'task-list-options',
              'google-account',
              'reminders-off',
            )),
          ),
        )
        .entries
        .singleWhere((entry) => entry.value == 'toggle-reminders');
    expect(disabledEntry.label, 'Task reminders — Off');
    expect(disabledEntry.icon, Icons.notifications_off_outlined);
    expect(disabledEntry.role, BusyMaxMenuEntryRole.command);
    expect(disabledEntry.selected, isFalse);
  });
}

Future<void> _pumpSidebar(
  WidgetTester tester,
  List<AccountEntity> accounts, {
  CalendarCollectionCreator? creationService,
  Locale locale = const Locale('en'),
  NetworkAvailability? networkAvailability,
  List<CalendarSourceEntity> calendarSources = const [],
  List<TaskListEntity> taskLists = const [],
  ThemeData? theme,
  double width = 320,
  double height = 800,
  MemorySettingsStore? settingsStore,
  Stream<List<CalendarSourceEntity>>? calendarSnapshots,
  Stream<List<TaskListEntity>>? taskSnapshots,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(900, 1200);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        localSettingsStoreProvider.overrideWithValue(
          settingsStore ?? MemorySettingsStore(),
        ),
        accountsStreamProvider.overrideWith((ref) => Stream.value(accounts)),
        if (networkAvailability != null)
          networkAvailabilityProvider.overrideWith(
            (ref) => Stream.value(networkAvailability),
          ),
        calendarRepositoryProvider.overrideWithValue(
          _CalendarSourcesRepository(calendarSources),
        ),
        taskListsRepositoryForAccountProvider.overrideWith(
          (ref, accountId) => _TaskListsRepository(
            taskLists.where((list) => list.accountId == accountId).toList(),
          ),
        ),
        if (calendarSnapshots != null)
          sidebarCalendarSourcesProvider.overrideWith(
            (ref, accountId) => calendarSnapshots.map(
              (sources) => sources
                  .where((source) => source.accountId == accountId)
                  .toList(),
            ),
          ),
        if (taskSnapshots != null)
          sidebarTaskListsProvider.overrideWith(
            (ref, accountId) => taskSnapshots.map(
              (lists) =>
                  lists.where((list) => list.accountId == accountId).toList(),
            ),
          ),
        if (creationService != null)
          calendarCollectionCreationServiceProvider.overrideWithValue(
            creationService,
          ),
      ],
      child: localizedTestApp(
        locale: locale,
        theme: theme,
        child: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: width,
            height: height,
            child: ScheduleSidebar(
              selectedDate: DateTime(2026, 8, 29),
              firstWeekday: DateTime.monday,
              items: const [],
              onDateSelected: (_) {},
              onMonthSelected: (_) {},
              onYearSelected: (_) {},
              onWeekSelected: (_) {},
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

CalendarSourceEntity _calendar(
  String accountId,
  String id, {
  String? title,
  BusyProvider provider = BusyProvider.google,
  String? backgroundColor,
}) => CalendarSourceEntity(
  id: id,
  accountId: accountId,
  provider: provider,
  providerCalendarId: id,
  summary: title ?? id,
  selected: false,
  hidden: false,
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

final class _CalendarSourcesRepository implements CalendarRepository {
  const _CalendarSourcesRepository(this.sources);

  final List<CalendarSourceEntity> sources;

  @override
  Stream<List<CalendarSourceEntity>> watchSourcesForAccounts(
    List<String> accountIds,
  ) => Stream.value([
    for (final source in sources)
      if (accountIds.contains(source.accountId)) source,
  ]);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _TaskListsRepository implements TaskListsRepository {
  const _TaskListsRepository(this.lists);

  final List<TaskListEntity> lists;

  @override
  Stream<List<TaskListEntity>> watchTaskLists() => Stream.value(lists);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _FakeCalendarCollectionCreationService
    implements CalendarCollectionCreator {
  final titles = <String>[];

  @override
  Future<CalendarCollectionCreationResult> createCalendar({
    required String accountId,
    required String title,
  }) async {
    titles.add(title);
    return const CalendarCollectionCreationResult(
      outcome: CalendarCollectionCreationOutcome.queued,
    );
  }
}

AccountEntity _account(
  BusyProvider provider, {
  String? id,
  bool calendarsEnabled = true,
  bool tasksEnabled = true,
  String? displayName,
  String? email,
  String authority = 'https://example.test',
}) => AccountEntity(
  id: id ?? '${provider.storageValue}-account',
  provider: provider,
  authority: authority,
  providerAccountId: 'identity',
  displayName:
      displayName ??
      (provider == BusyProvider.webCal
          ? 'WebCal account'
          : provider.displayName),
  email: email,
  authState: accountAuthStateSignedIn,
  calendarsEnabled: calendarsEnabled,
  tasksEnabled: tasksEnabled,
);

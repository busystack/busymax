import 'package:busymax/src/app/app_bootstrap.dart';
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

import '../../../test_localized_app.dart';

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
        expect(indicatorRect.size, const Size.square(24));
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
        expect(
          tester.getTopLeft(find.text(displayName)).dy,
          lessThan(tester.getTopLeft(find.text(email)).dy),
        );

        await tester.tap(
          find.byKey(const ValueKey(('account-collapse', accountId))),
        );
        await tester.pumpAndSettle();
        expect(indicator, findsOneWidget);
        expect(tester.getRect(indicator).size, const Size.square(24));
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets('Apple has no empty collection Options menu', (tester) async {
    await _pumpSidebar(tester, [_account(BusyProvider.appleICloud)]);

    expect(find.byTooltip('Options'), findsNothing);
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

    expect(menu.entries, hasLength(2));
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
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(900, 1200);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        accountsStreamProvider.overrideWith((ref) => Stream.value(accounts)),
        if (networkAvailability != null)
          networkAvailabilityProvider.overrideWith(
            (ref) => Stream.value(networkAvailability),
          ),
        calendarRepositoryProvider.overrideWithValue(
          _CalendarSourcesRepository(calendarSources),
        ),
        taskListsRepositoryForAccountProvider.overrideWith(
          (ref, accountId) => _TaskListsRepository(taskLists),
        ),
        if (creationService != null)
          calendarCollectionCreationServiceProvider.overrideWithValue(
            creationService,
          ),
      ],
      child: localizedTestApp(
        locale: locale,
        theme: theme,
        child: SizedBox(
          width: width,
          height: 800,
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
  );
  await tester.pumpAndSettle();
}

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
}) => AccountEntity(
  id: id ?? '${provider.storageValue}-account',
  provider: provider,
  authority: 'https://example.test',
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

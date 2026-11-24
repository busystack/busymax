import 'package:busymax/src/platform/gtk_animation_settings_service.dart';
import 'package:go_router/go_router.dart';
import 'package:busymax/l10n/generated/app_localizations.dart';
import 'package:busymax/src/features/sync/sync_request.dart';

import 'dart:async';
import 'dart:ui' show PointerDeviceKind, Tristate;

import 'package:busymax/src/dav/dav_errors.dart';
import 'package:busymax/src/dav/nextcloud/nextcloud_dav_context.dart';
import 'package:busymax/l10n/generated/app_localizations_en.dart';

import 'package:busymax/src/app/app_bootstrap.dart';
import 'package:busymax/src/schedule/schedule_sidebar_order.dart';
import 'package:busymax/src/schedule/schedule_sidebar_sources.dart';
import 'package:busymax/src/app/busymax_design.dart';
import 'package:busymax/src/calendar_providers/calendar_sync_dto.dart';
import 'package:busymax/src/db/app_database.dart';
import 'package:busymax/src/schedule/schedule_sidebar_visibility_icon.dart';
import 'package:busymax/src/schedule/schedule_source_visibility.dart';
import 'package:busymax/src/app/busymax_yaru_theme.dart';
import 'package:busymax/src/features/accounts/data/accounts_repository.dart';
import 'package:busymax/src/features/auth/data/auth_repository.dart';
import 'package:busymax/src/features/calendar/data/calendar_repository.dart';
import 'package:busymax/src/features/calendar/data/calendar_collection_creation_service.dart';
import 'package:busymax/src/features/connectivity/network_connectivity_service.dart';
import 'package:busymax/src/features/schedule/presentation/schedule_sidebar.dart';
import 'package:busymax/src/features/sync/account_sync_operations.dart';
import 'package:busymax/src/core/auth/oauth_models.dart';
import 'package:busymax/src/core/http/request_dispatch_exception.dart';
import 'package:busymax/src/features/task_lists/data/task_lists_repository.dart';
import 'package:busymax/src/platform/native_menu_service.dart';
import 'package:busymax/src/providers/busy_provider.dart';
import 'package:busymax/src/ui/common/flutter_material.dart';
import 'package:flutter/rendering.dart';
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
    'generic shared task list removal is disabled even without a DAV binding',
    (tester) async {
      final account = _account(BusyProvider.caldav, id: 'account');
      await _pumpSidebar(
        tester,
        [account],
        taskLists: [
          TaskListEntity(
            accountId: account.id,
            id: 'tasks',
            title: 'Shared',
            isShared: true,
            localDirty: false,
            pendingDelete: false,
            rawJson: '{}',
          ),
        ],
      );
      final menu = tester.widget<BusyMaxMenuButton<String>>(
        find.byKey(const ValueKey(('task-list-options', 'account', 'tasks'))),
      );
      expect(
        menu.entries.singleWhere((e) => e.value == 'delete').enabled,
        isFalse,
      );
      menu.onSelected('delete');
      await tester.pumpAndSettle();
      expect(find.text('Unshare'), findsNothing);
    },
  );

  testWidgets(
    'Linux delete retains and explains a partially removed collection',
    (tester) async {
      final account = _account(BusyProvider.caldav);
      final source = CalendarSourceEntity(
        id: 'partial-calendar',
        accountId: account.id,
        provider: BusyProvider.caldav,
        providerCalendarId: 'partial-calendar',
        davCollectionId: 'partial-calendar',
        summary: 'Surviving collection',
        selected: true,
        hidden: false,
        readOnly: false,
        isDeleted: false,
        davEffectivePermissions: const {
          'ownerHref': 'https://example.test/principals/qa/',
          'principalHref': 'https://example.test/principals/qa/',
          'parentPrivileges': ['{DAV:}unbind'],
        },
      );
      final repository = _PartialRemovalRepository([source]);
      await _pumpSidebar(
        tester,
        [account],
        calendarSources: [source],
        calendarRepository: repository,
      );
      final menu = tester.widget<BusyMaxMenuButton<String>>(
        find.byKey(const ValueKey(('calendar-options', 'partial-calendar'))),
      );
      expect(
        menu.entries.singleWhere((e) => e.value == 'delete').enabled,
        isTrue,
      );
      menu.onSelected('delete');
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(ElevatedButton, AppLocalizationsEn().delete).last,
      );
      await tester.pumpAndSettle();
      expect(repository.calls, 1);
      expect(
        find.textContaining(AppLocalizationsEn().davCollectionRemovalPartial),
        findsOneWidget,
      );
      expect(find.text('Surviving collection'), findsWidgets);
    },
  );

  for (final nextcloud in [false, true]) {
    testWidgets(
      'calendar rename refresh message retains the correct provider; Nextcloud=$nextcloud',
      (tester) async {
        final provider = nextcloud
            ? BusyProvider.nextcloud
            : BusyProvider.caldav;
        final account = _account(provider);
        final source = CalendarSourceEntity(
          id: 'c',
          accountId: account.id,
          provider: provider,
          davEffectivePermissions: const {'canWriteProperties': true},
          providerCalendarId: 'c',
          summary: 'Work',
          selected: true,
          hidden: false,
          readOnly: false,
          isDeleted: false,
        );
        final repository = _RefreshPendingCalendarRepository([
          source,
        ], nextcloud);
        await _pumpSidebar(
          tester,
          [account],
          calendarSources: [source],
          calendarRepository: repository,
        );
        final menu = tester.widget<BusyMaxMenuButton<String>>(
          find.byKey(const ValueKey(('calendar-options', 'c'))),
        );
        expect(
          menu.entries.singleWhere((e) => e.value == 'rename').enabled,
          isTrue,
        );
        menu.onSelected('rename');
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), 'Changed');
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pumpAndSettle();
        expect(repository.calls, 1);
        final l10n = AppLocalizationsEn();
        expect(
          find.text(
            nextcloud ? l10n.nextcloudRefreshPending : l10n.davRefreshPending,
          ),
          findsOneWidget,
        );
        expect(find.textContaining('Could not'), findsNothing);
        if (!nextcloud) {
          expect(find.textContaining('saved on Nextcloud'), findsNothing);
        }
        expect(tester.takeException(), isNull);
      },
    );
  }
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

  for (final motion in [true, false]) {
    testWidgets(
      'calendar synchronization restores the row quietly with GTK animations $motion',
      (tester) async {
        final account = _account(BusyProvider.google, id: 'account');
        final source = _calendar(
          account.id,
          'calendar',
          backgroundColor: '#123456',
        );
        await _pumpSidebar(
          tester,
          [account],
          calendarSources: [source],
          gtkAnimations: motion,
        );
        final row = _row(('schedule-calendar', account.id, source.id));
        final original = tester.getRect(row);
        final scope = calendarSyncScope(account.id, source.id);
        final container = ProviderScope.containerOf(tester.element(row));
        final activity = container.read(accountSyncActivityProvider.notifier);
        final release = Completer<void>();
        final active = activity.resource([scope], () => release.future);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 180));
        final rotation = find.descendant(
          of: row,
          matching: find.byType(RotationTransition),
        );
        expect(rotation, motion ? findsOneWidget : findsNothing);
        final icon = tester.widget<Icon>(
          find.descendant(of: row, matching: find.byIcon(YaruIcons.calendar)),
        );
        expect(icon.color, const Color(0xff123456));
        expect(tester.getRect(row), original);
        final accountIcon = _row(('account-visibility', account.id));
        final provider = _row(('account-provider-indicator', account.id));
        expect(provider, findsOneWidget);
        final controls = [
          provider,
          _row(('account-collapse', account.id)),
          _row(('account-collection-options', account.id)),
        ].map(tester.getRect).toList();
        final accountRotation = find.descendant(
          of: accountIcon,
          matching: find.byType(RotationTransition),
        );
        expect(accountRotation, motion ? findsOneWidget : findsNothing);
        await tester.tap(accountIcon);
        await tester.pump();
        expect(activity.busy(scope), isTrue);
        expect(
          tester.widget<ScheduleSidebarVisibilityIcon>(accountIcon).visible,
          isFalse,
        );
        expect(
          controls,
          [
            provider,
            _row(('account-collapse', account.id)),
            _row(('account-collection-options', account.id)),
          ].map(tester.getRect).toList(),
        );
        if (motion) {
          await tester.tap(_row(('account-collapse', account.id)));
          await tester.pump();
          expect(rotation, findsNothing);
          expect(accountRotation, findsOneWidget);
          await tester.tap(_row(('account-collapse', account.id)));
          await tester.pump(const Duration(milliseconds: 250));
        }
        release.complete();
        await active;
        await tester.pumpAndSettle();
        expect(rotation, findsNothing);
        expect(
          find.descendant(of: row, matching: find.byIcon(YaruIcons.calendar)),
          findsOneWidget,
        );
        expect(find.byType(SnackBar), findsNothing);
        expect(tester.getRect(row), original);
        await expectLater(
          activity.resource<void>([
            scope,
          ], () async => throw StateError('fixture failure')),
          throwsStateError,
        );
        await tester.pumpAndSettle();
        expect(
          find.descendant(of: row, matching: find.byIcon(YaruIcons.warning)),
          findsOneWidget,
        );
        expect(
          find.descendant(of: row, matching: find.byIcon(YaruIcons.calendar)),
          findsOneWidget,
        );
        expect(tester.getRect(row), original);
      },
    );
  }

  testWidgets('offscreen collections do not keep the sync ring rotating', (
    tester,
  ) async {
    final account = _account(BusyProvider.google, id: 'a');
    await _pumpSidebar(
      tester,
      [account],
      calendarSources: [
        for (var i = 0; i < 25; i++) _calendar('a', 'source-$i'),
      ],
      height: 420,
      gtkAnimations: true,
    );
    final icon = _row(('calendar-visibility', 'source-0'));
    final ring = find.descendant(
      of: icon,
      matching: find.byType(RotationTransition),
    );
    final container = ProviderScope.containerOf(tester.element(icon));
    final activity = container.read(accountSyncActivityProvider.notifier);
    final release = Completer<void>();
    final scope = calendarSyncScope('a', 'source-0');
    final pending = activity.resource([scope], () => release.future);
    await tester.pump();
    await tester.pump();
    expect(ring, findsOneWidget);
    final scrollable = tester.state<ScrollableState>(
      find
          .descendant(
            of: find.byType(ListView).first,
            matching: find.byType(Scrollable),
          )
          .first,
    );
    scrollable.position.jumpTo(240);
    await tester.pump();
    await tester.pump();
    expect(activity.executing(scope), isTrue);
    expect(ring, findsNothing);
    scrollable.position.jumpTo(0);
    await tester.pump();
    await tester.pump();
    expect(ring, findsOneWidget);
    release.complete();
    await pending;
    await tester.pumpAndSettle();
    expect(ring, findsNothing);
  });

  testWidgets('eligible calendar refresh dispatches synchronization', (
    tester,
  ) async {
    final account = _account(BusyProvider.google, id: 'account');
    final accounts = _MutableAccountsRepository(account);
    final sync = _RecordingAccountSyncOperations();
    addTearDown(accounts.dispose);

    await _pumpSidebar(
      tester,
      [account],
      accountSnapshots: accounts.watchAccounts(),
      accountsRepository: accounts,
      authRepository: _ReconnectRecordingAuthRepository(accounts),
      syncOperations: sync,
      calendarSources: [_calendar(account.id, 'calendar')],
    );

    final menu = tester.widget<BusyMaxMenuButton<String>>(
      find.byKey(const ValueKey(('calendar-options', 'calendar'))),
    );
    expect(
      menu.entries.singleWhere((entry) => entry.value == 'refresh').enabled,
      isTrue,
    );
    menu.onSelected('refresh');
    await tester.pumpAndSettle();

    expect(
      sync.requests.single.scope,
      calendarSyncScope(account.id, 'calendar'),
    );
    expect(sync.calendarCalls, 1);
  });

  testWidgets(
    'calendar refresh invalid_grant requires reconnect and blocks retry',
    (tester) async {
      final account = _account(BusyProvider.google, id: 'account');
      final accounts = _MutableAccountsRepository(account);
      final auth = _ReconnectRecordingAuthRepository(accounts);
      final sync = _RecordingAccountSyncOperations(
        calendarError: _wrappedInvalidGrant,
      );
      addTearDown(accounts.dispose);

      await _pumpSidebar(
        tester,
        [account],
        accountSnapshots: accounts.watchAccounts(),
        accountsRepository: accounts,
        authRepository: auth,
        syncOperations: sync,
        recoveryRouter: true,
        calendarSources: [_calendar(account.id, 'calendar')],
      );

      var menu = tester.widget<BusyMaxMenuButton<String>>(
        find.byKey(const ValueKey(('calendar-options', 'calendar'))),
      );
      menu.onSelected('refresh');
      await tester.pumpAndSettle();

      expect(sync.calendarCalls, 1);
      expect(auth.markedAccountIds, ['account']);
      expect(accounts.account.needsReconnect, isTrue);
      expect(
        find.text(
          'Your Google account needs to be reconnected to resume calendar and task synchronization.',
        ),
        findsOneWidget,
      );
      expect(find.text('Reconnect Google account'), findsOneWidget);
      menu = tester.widget<BusyMaxMenuButton<String>>(
        find.byKey(const ValueKey(('calendar-options', 'calendar'))),
      );
      final refresh = menu.entries.singleWhere(
        (entry) => entry.value == 'refresh',
      );
      expect(refresh.enabled, isFalse);
      expect(refresh.tooltip, 'This account needs to be reconnected.');

      expect(sync.calendarCalls, 1);
      await tester.tap(find.text('Reconnect Google account'));
      await tester.pumpAndSettle();
      expect(find.text('Reconnect account account'), findsOneWidget);
    },
  );

  testWidgets(
    'task-list refresh invalid_grant requires reconnect and blocks retry',
    (tester) async {
      final account = _account(BusyProvider.google, id: 'account');
      final accounts = _MutableAccountsRepository(account);
      final auth = _ReconnectRecordingAuthRepository(accounts);
      final sync = _RecordingAccountSyncOperations(
        taskError: _wrappedInvalidGrant,
      );
      addTearDown(accounts.dispose);

      await _pumpSidebar(
        tester,
        [account],
        accountSnapshots: accounts.watchAccounts(),
        accountsRepository: accounts,
        authRepository: auth,
        syncOperations: sync,
        recoveryRouter: true,
        taskLists: [_list(account.id, 'tasks')],
      );

      var menu = tester.widget<BusyMaxMenuButton<String>>(
        find.byKey(const ValueKey(('task-list-options', 'account', 'tasks'))),
      );
      menu.onSelected('refresh');
      await tester.pumpAndSettle();

      expect(
        sync.requests.single.scope,
        taskListSyncScope(account.id, 'tasks'),
      );
      expect(sync.taskCalls, 1);
      expect(auth.markedAccountIds, ['account']);
      expect(accounts.account.needsReconnect, isTrue);
      expect(
        find.text(
          'Your Google account needs to be reconnected to resume calendar and task synchronization.',
        ),
        findsOneWidget,
      );
      expect(find.text('Reconnect Google account'), findsOneWidget);
      menu = tester.widget<BusyMaxMenuButton<String>>(
        find.byKey(const ValueKey(('task-list-options', 'account', 'tasks'))),
      );
      expect(
        menu.entries.singleWhere((entry) => entry.value == 'refresh').enabled,
        isFalse,
      );

      expect(sync.taskCalls, 1);
      await tester.tap(find.text('Reconnect Google account'));
      await tester.pumpAndSettle();
      expect(find.text('Reconnect account account'), findsOneWidget);
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
        calendarMenu('c1').entries
            .singleWhere((entry) => entry.value == 'move-up')
            .enabled,
        isFalse,
      );
      expect(
        calendarMenu('c2').entries
            .singleWhere((entry) => entry.value == 'move-down')
            .enabled,
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
        find
            .byKey(const ValueKey(('schedule-calendar', 'a', 'c2')))
            .hitTestable(),
        findsNothing,
      );
      expect(
        AppSettings.fromJson(store.value)
            .isTaskListVisibleInSchedule('a', 'l2'),
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
        AppSettings.fromJson(store.value)
            .sidebarOrder
            .calendarSourceIdsByAccount['a'],
        ['c2', 'c1'],
      );
      expect(
        AppSettings.fromJson(store.value)
            .sidebarOrder
            .taskListIdsByAccount['a'],
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
          find.bySemanticsLabel('Hide account, ${expected.$3}, Shared account'),
          findsOneWidget,
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
        displayName: 'fixture',
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
      find.bySemanticsLabel('Nextcloud, fixture, cloud.example.test:8443'),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel('Nextcloud, work-user, work.example.test'),
      findsOneWidget,
    );
    semantics.dispose();
  });

  testWidgets(
    'sidebar hover surfaces stay inset and aligned with long names and during sync',
    (tester) async {
      for (final (brightness, width) in [
        (Brightness.light, 300.0),
        (Brightness.dark, 240.0),
      ]) {
        final theme = BusyMaxYaruTheme.build(
          brightness: brightness,
          accentColor: const Color(0xFFE95464),
        );
        const accountId = 'google-long';
        const displayName =
            'A very long account display name that must be truncated';
        const email = 'a-very-long-address-for-sidebar@example.test';
        const calendarName = 'A long calendar name that must also truncate';
        const taskName = 'A long task list name that must also truncate';
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
          calendarSources: [
            _calendar(accountId, 'calendar', title: calendarName),
          ],
          taskLists: [_list(accountId, 'tasks', title: taskName)],
          theme: theme,
          width: width,
          alignment: Alignment.topCenter,
          gtkAnimations: true,
        );

        final indicator = find.byKey(
          const ValueKey(('account-provider-indicator', accountId)),
        );
        final sidebar = tester.getRect(find.byType(ScheduleSidebar));
        final indicatorRect = tester.getRect(indicator);
        expect(indicatorRect.size, const Size.square(16));
        expect(indicatorRect.left, greaterThanOrEqualTo(sidebar.left));
        expect(indicatorRect.right, lessThanOrEqualTo(sidebar.right));
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
        expect(indicatorRect.right, lessThan(nameRect.left));
        expect(
          nameRect.expandToInclude(addressRect).center.dy,
          closeTo(indicatorRect.center.dy, 0.01),
        );
        final leadingButtons = [
          _row(('account-visibility', accountId)),
          _row(('calendar-visibility', 'calendar')),
          _row(('task-list-visibility', accountId, 'tasks')),
        ].map(_sidebarButtonSurface).toList();
        for (final leading in leadingButtons) {
          final bounds = tester.getRect(leading);
          expect(bounds.size, const Size.square(32));
          expect(bounds.left - sidebar.left, closeTo(8, 1));
          expect(bounds.center.dx, indicatorRect.center.dx);
        }
        for (final glyph in [YaruIcons.calendar, YaruIcons.task_list]) {
          expect(
            tester.getCenter(find.byIcon(glyph)).dx,
            indicatorRect.center.dx,
          );
        }
        for (final label in [
          find.text(displayName),
          find.text(calendarName),
          find.text(taskName),
        ]) {
          expect(tester.widget<Text>(label).overflow, TextOverflow.ellipsis);
          expect(
            tester.renderObject<RenderParagraph>(label).didExceedMaxLines,
            isTrue,
          );
          expect(tester.getTopLeft(label).dx, nameRect.left);
        }
        expect(nameRect.left - tester.getRect(leadingButtons.first).right, 8);
        final optionsButtons = [
          _row(('account-collection-options', accountId)),
          _row(('calendar-options', 'calendar')),
          _row(('task-list-options', accountId, 'tasks')),
        ].map(_sidebarButtonSurface).toList();
        final accountMenu = optionsButtons.first;
        final collapse = _sidebarButtonSurface(
          _row(('account-collapse', accountId)),
        );
        for (final menu in optionsButtons) {
          final bounds = tester.getRect(menu);
          expect(bounds.size, const Size.square(32));
          expect(sidebar.right - bounds.right, closeTo(8, 1));
          expect(bounds.center.dx, tester.getCenter(accountMenu).dx);
        }
        expect(
          tester.getRect(accountMenu).left - tester.getRect(collapse).right,
          4,
        );

        final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
        await mouse.addPointer(location: sidebar.topRight);
        for (final button in [...leadingButtons, ...optionsButtons]) {
          final bounds = tester.getRect(button);
          await mouse.moveTo(bounds.center);
          await tester.pump();
          await tester.pump(BusyMaxMotion.fast);
          final hoverSurface = find.descendant(
            of: button,
            matching: find.byType(PhysicalShape),
          );
          final shape = tester.widget<PhysicalShape>(hoverSurface);
          expect(
            shape.color,
            colorScheme.onSurfaceVariant.withValues(alpha: 0.08),
          );
          final box = tester.getRect(hoverSurface);
          final paintBounds = shape.clipper
              .getClip(box.size)
              .getBounds()
              .shift(box.topLeft);
          expect(paintBounds, bounds);
        }
        await mouse.removePointer();
        await tester.pump();

        final controls = [...leadingButtons, collapse, ...optionsButtons];
        final idleBounds = controls.map(tester.getRect).toList();
        final release = Completer<void>();
        final activity = ProviderScope.containerOf(tester.element(indicator))
            .read(accountSyncActivityProvider.notifier);
        final running = activity.resource([
          calendarSyncScope(accountId, 'calendar'),
        ], () => release.future);
        try {
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 180));
          for (final button in leadingButtons.take(2)) {
            expect(
              find.descendant(
                of: button,
                matching: find.byType(RotationTransition),
              ),
              findsOneWidget,
            );
          }
          expect(controls.map(tester.getRect), idleBounds);
        } finally {
          release.complete();
          await running;
        }
        await tester.pumpAndSettle();

        final menuBounds = tester.getRect(accountMenu);
        await tester.tapAt(Offset(menuBounds.right - 2, menuBounds.center.dy));
        await tester.pumpAndSettle();
        expect(find.text('Account settings'), findsOneWidget);
        await tester.tapAt(const Offset(790, 790));
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const ValueKey(('account-collapse', accountId))),
        );
        await tester.pumpAndSettle();
        expect(indicator, findsOneWidget);
        expect(tester.getRect(indicator).size, const Size.square(16));
        expect(tester.getRect(leadingButtons.first), idleBounds.first);
        expect(tester.getRect(accountMenu), menuBounds);
        await tester.tap(collapse);
        await tester.pumpAndSettle();
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
    expect(menu.entries.map((entry) => entry.label), [
      'Refresh account',
      'Account settings',
      'Move up',
      'Move down',
    ]);
    expect(
      menu.entries
          .where((entry) => entry.label.startsWith('Move'))
          .every((entry) => !entry.enabled),
      isTrue,
    );
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
    expect(find.text('No calendars synced yet.').hitTestable(), findsNothing);
    expect(find.byTooltip('Options'), findsOneWidget);

    await tester.tap(find.byTooltip('Options'));
    await tester.pumpAndSettle();
    expect(find.text('New calendar…'), findsOneWidget);
    expect(find.text('No calendars synced yet.').hitTestable(), findsNothing);
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

    expect(menu.entries, hasLength(7));
    expect(
      menu.entries.where((entry) => entry.enabled).map((entry) => entry.value),
      [AccountHeaderCollectionAction.settings],
    );
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
    await _pumpSidebar(
      tester,
      [_account(BusyProvider.google)],
      calendarSources: [_calendar('google-account', 'calendar')],
      locale: const Locale('ar'),
    );
    final options = _sidebarButtonSurface(
      _row(('account-collection-options', 'google-account')),
    );
    final collapse = _sidebarButtonSurface(
      _row(('account-collapse', 'google-account')),
    );

    expect(Directionality.of(tester.element(options)), TextDirection.rtl);
    final provider = _sidebarButtonSurface(
      _row(('account-visibility', 'google-account')),
    );
    final calendar = _sidebarButtonSurface(
      _row(('calendar-visibility', 'calendar')),
    );
    final calendarOptions = _sidebarButtonSurface(
      _row(('calendar-options', 'calendar')),
    );
    final sidebar = tester.getRect(find.byType(ScheduleSidebar));
    expect(tester.getRect(collapse).left - tester.getRect(options).right, 4);
    expect(tester.getRect(options).left - sidebar.left, closeTo(8, 1));
    expect(sidebar.right - tester.getRect(provider).right, closeTo(8, 1));
    expect(tester.getCenter(calendar).dx, tester.getCenter(provider).dx);
    expect(tester.getCenter(calendarOptions).dx, tester.getCenter(options).dx);
    expect(
      tester.getCenter(provider).dx,
      greaterThan(tester.getCenter(collapse).dx),
    );
  });

  testWidgets(
    'visibility icons preserve local preferences and disabled children across reload',
    (tester) async {
      final database = AppDatabase.memoryForTests();
      addTearDown(database.close);
      final calendar = CalendarRepository(database: database);
      final account = _account(BusyProvider.google, id: 'a');
      final other = _account(BusyProvider.google, id: 'b');
      final store = MemorySettingsStore();
      final sources = [
        for (final account in [account, other]) (account, 'personal', false),
        (account, 'provider-hidden', true),
      ];
      await tester.runAsync(() async {
        final accounts = AccountsRepository(database: database);
        for (final entry in [account, other]) {
          await accounts.upsertSignedInAccount(
            id: entry.id,
            provider: entry.provider,
            providerAccountId: entry.id,
            grantedScopes: 'calendar tasks',
          );
        }
        for (final (owner, id, hidden) in sources) {
          await calendar.upsertSource(
            accountId: owner.id,
            source: CalendarSourceDto(
              provider: owner.provider,
              providerCalendarId: id,
              summary: id,
              hidden: hidden,
              backgroundColor: '#123456',
            ),
          );
        }
      });
      Future<void> mount() => _pumpSidebar(
        tester,
        [account, other],
        calendarRepository: calendar,
        taskLists: [_list('a', 'tasks')],
        settingsStore: store,
      );
      String sourceId(String accountId, String id) =>
          CalendarRepository.sourceId(
            accountId: accountId,
            provider: BusyProvider.google,
            providerCalendarId: id,
          );
      final accountIcon = _row(('account-visibility', 'a'));
      final personal = _row(('calendar-visibility', sourceId('a', 'personal')));
      final unrelated = _row((
        'calendar-visibility',
        sourceId('b', 'personal'),
      ));
      final tasks = _row(('task-list-visibility', 'a', 'tasks'));
      ScheduleSidebarVisibilityIcon icon(Finder finder) =>
          tester.widget(finder);
      await mount();
      expect(
        icon(accountIcon).accountVisibility,
        ScheduleAccountVisibility.visible,
      );
      expect(
        _row(('calendar-visibility', sourceId('a', 'provider-hidden'))),
        findsNothing,
      );
      expect(icon(personal).actionLabel, 'Hide calendar');
      final semantics = tester.ensureSemantics();
      try {
        Tristate toggled() => tester
            .getSemantics(personal)
            .getSemanticsData()
            .flagsCollection
            .isToggled;
        await tester.pump();
        expect(toggled(), Tristate.isTrue);
        final glyph = find.descendant(
          of: personal,
          matching: find.byIcon(YaruIcons.calendar),
        );
        Focus.of(tester.element(glyph)).requestFocus();
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        expect(toggled(), Tristate.isFalse);
      } finally {
        semantics.dispose();
      }
      expect(icon(personal).actionLabel, 'Show calendar');
      expect((icon(personal).icon as Icon).color, const Color(0xff123456));
      expect(
        tester
            .widgetList<Opacity>(
              find.descendant(of: personal, matching: find.byType(Opacity)),
            )
            .map((widget) => widget.opacity),
        contains(0.4),
      );
      expect(
        icon(accountIcon).accountVisibility,
        ScheduleAccountVisibility.partial,
      );
      await tester.tap(personal);
      await tester.pumpAndSettle();
      expect(icon(personal).visible, isTrue);

      await tester.tap(tasks);
      await tester.pumpAndSettle();
      expect(icon(tasks).actionLabel, 'Show task list');
      await tester.tap(accountIcon);
      await tester.pumpAndSettle();
      expect(
        icon(accountIcon).accountVisibility,
        ScheduleAccountVisibility.hidden,
      );
      expect(icon(accountIcon).actionLabel, 'Show account');
      expect(icon(personal).onPressed, isNull);
      expect(
        icon(tasks).actionLabel,
        'Show the account to change collection visibility',
      );
      expect(icon(unrelated).visible, isTrue);
      await tester.tap(_row(('account-collapse', 'a')));
      await tester.pumpAndSettle();
      expect(personal.hitTestable(), findsNothing);
      expect(icon(accountIcon).visible, isFalse);

      await tester.pumpWidget(const SizedBox.shrink());
      await mount();
      expect(icon(accountIcon).visible, isFalse);
      expect(icon(personal).visible, isFalse);
      await tester.tap(accountIcon);
      await tester.pumpAndSettle();
      expect(icon(personal).visible, isTrue);
      expect(icon(tasks).visible, isFalse);
      await tester.tap(personal);
      await tester.pumpAndSettle();
      expect(
        icon(accountIcon).accountVisibility,
        ScheduleAccountVisibility.noVisibleSources,
      );
      expect(icon(accountIcon).actionLabel, 'Hide account');
      expect(icon(tasks).onPressed, isNotNull);
      await tester.tap(tasks);
      await tester.pumpAndSettle();
      expect(icon(tasks).actionLabel, 'Hide task list');
    },
  );

  testWidgets('native sidebar menus send GTK icons and account group breaks', (
    tester,
  ) async {
    List<dynamic>? entries;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_nativeMenuChannel, (call) async {
          if (call.method == 'show') {
            entries =
                (call.arguments as Map<Object?, Object?>)['entries']
                    as List<dynamic>;
          }
          return null;
        });
    final account = _account(BusyProvider.nextcloud);
    await _pumpSidebar(
      tester,
      [account],
      calendarSources: [
        _calendar(account.id, 'work', provider: account.provider),
      ],
      taskLists: [_list(account.id, 'tasks')],
    );
    Future<Map<String, Map<dynamic, dynamic>>> open(Object rowKey) async {
      await tester.tap(_row(rowKey));
      await tester.pumpAndSettle();
      return {
        for (final entry in entries!.cast<Map>())
          entry['label'] as String: entry,
      };
    }

    final accountMenu = await open(('account-collection-options', account.id));
    expect(accountMenu['New calendar…']?['icon'], 'appointment-new-symbolic');
    expect(
      accountMenu['New task list…']?['icon'],
      'busymax-task-list-add-symbolic',
    );
    expect(
      accountMenu['Account settings']?['icon'],
      'preferences-system-symbolic',
    );
    expect(accountMenu['Refresh account']?['separatorBefore'], isTrue);
    expect(accountMenu['Move up']?['separatorBefore'], isTrue);
    for (final menu in [
      accountMenu,
      await open(('calendar-options', 'work')),
      await open(('task-list-options', account.id, 'tasks')),
    ]) {
      expect(menu['Move up']?['icon'], 'go-up-symbolic');
      expect(menu['Move down']?['icon'], 'go-down-symbolic');
    }
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
  CalendarRepository? calendarRepository,
  Locale locale = const Locale('en'),
  NetworkAvailability? networkAvailability,
  List<CalendarSourceEntity> calendarSources = const [],
  List<TaskListEntity> taskLists = const [],
  ThemeData? theme,
  double width = 320,
  double height = 800,
  Alignment alignment = Alignment.topLeft,
  MemorySettingsStore? settingsStore,
  Stream<List<CalendarSourceEntity>>? calendarSnapshots,
  Stream<List<TaskListEntity>>? taskSnapshots,
  Stream<List<AccountEntity>>? accountSnapshots,
  AccountsRepository? accountsRepository,
  AuthRepository? authRepository,
  AccountSyncOperations? syncOperations,
  bool recoveryRouter = false,
  bool? gtkAnimations,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(900, 1200);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  final sidebar = Scaffold(
    body: Align(
      alignment: alignment,
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
  );
  final router = !recoveryRouter
      ? null
      : GoRouter(
          routes: [
            GoRoute(path: '/', builder: (_, _) => sidebar),
            GoRoute(
              path: '/settings',
              builder: (_, state) => Scaffold(
                body: Text(
                  'Reconnect account ${state.uri.queryParameters['reconnect']}',
                ),
              ),
            ),
          ],
        );
  if (router != null) addTearDown(router.dispose);
  final root = router == null
      ? localizedTestApp(child: sidebar, locale: locale, theme: theme)
      : MaterialApp.router(
          routerConfig: router,
          locale: locale,
          theme: theme,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
        );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        if (gtkAnimations != null)
          gtkAnimationsEnabledProvider.overrideWith(
            (ref) => Stream.value(gtkAnimations),
          ),
        authorizationGenerationReaderProvider.overrideWithValue((_) async => 0),
        localSettingsStoreProvider.overrideWithValue(
          settingsStore ?? MemorySettingsStore(),
        ),
        accountsStreamProvider.overrideWith(
          (ref) => accountSnapshots ?? Stream.value(accounts),
        ),
        if (accountsRepository != null)
          accountsRepositoryProvider.overrideWithValue(accountsRepository),
        if (authRepository != null)
          authRepositoryProvider.overrideWithValue(authRepository),
        if (syncOperations != null)
          accountSyncOperationsProvider.overrideWithValue(syncOperations),
        if (networkAvailability != null)
          networkAvailabilityProvider.overrideWith(
            (ref) => Stream.value(networkAvailability),
          ),
        calendarRepositoryProvider.overrideWithValue(
          calendarRepository ?? _CalendarSourcesRepository(calendarSources),
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
      child: root,
    ),
  );
  await tester.pumpAndSettle();
}

Finder _row(Object value) => find.byWidgetPredicate(
  (widget) =>
      widget.key is ValueKey && (widget.key! as ValueKey).value == value,
);

Finder _sidebarButtonSurface(Finder control) => find.descendant(
  of: find.descendant(of: control, matching: find.byType(IconButton)),
  matching: find.byWidgetPredicate(
    (widget) => widget is Material && widget.shape is RoundedRectangleBorder,
  ),
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

class _CalendarSourcesRepository implements CalendarRepository {
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
  String authState = accountAuthStateSignedIn,
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
  authState: authState,
  calendarsEnabled: calendarsEnabled,
  tasksEnabled: tasksEnabled,
);

const _wrappedInvalidGrant = KnownUnsentRequestException(
  kind: RequestPreDispatchFailureKind.authentication,
  cause: OAuthRefreshException(
    'OAuthRefreshFailed',
    'Provider refresh failed.',
    statusCode: 400,
    oauthError: 'invalid_grant',
  ),
);

final class _RecordingAccountSyncOperations
    implements ScopedAccountSyncOperations {
  _RecordingAccountSyncOperations({this.calendarError, this.taskError});

  final Object? calendarError;
  final Object? taskError;
  int calendarCalls = 0;
  int taskCalls = 0;
  final requests = <SyncRequest>[];

  @override
  Future<SyncOutcome> execute(SyncRequest request) async {
    requests.add(request);
    final error = switch (request.scope.kind) {
      SyncScopeKind.calendarSource => calendarError,
      SyncScopeKind.taskList => taskError,
      _ => null,
    };
    if (request.scope.kind == SyncScopeKind.calendarSource) calendarCalls++;
    if (request.scope.kind == SyncScopeKind.taskList) taskCalls++;
    return SyncOutcome(
      request,
      error == null ? SyncDisposition.completed : SyncDisposition.failed,
      error: error,
    );
  }

  @override
  Future<void> syncAccount(String accountId, {required bool full}) async {}

  @override
  Future<void> syncCalendar(String accountId, {required bool full}) async {
    calendarCalls += 1;
    if (calendarError case final error?) throw error;
  }

  @override
  Future<void> syncTasks(String accountId, {required bool full}) async {
    taskCalls += 1;
    if (taskError case final error?) throw error;
  }
}

final class _MutableAccountsRepository implements AccountsRepository {
  _MutableAccountsRepository(this.account);

  AccountEntity account;
  final _changes = StreamController<List<AccountEntity>>.broadcast();

  @override
  Stream<List<AccountEntity>> watchAccounts() async* {
    yield [account];
    yield* _changes.stream;
  }

  void requireReconnect() {
    account = _account(
      account.provider,
      id: account.id,
      displayName: account.displayName,
      email: account.email,
      authority: account.authority,
      calendarsEnabled: account.calendarsEnabled,
      tasksEnabled: account.tasksEnabled,
      authState: accountAuthStateReauthRequired,
    );
    _changes.add([account]);
  }

  Future<void> dispose() => _changes.close();

  @override
  Future<AccountEntity?> accountById(String accountId) async =>
      account.id == accountId ? account : null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _ReconnectRecordingAuthRepository implements AuthRepository {
  _ReconnectRecordingAuthRepository(this.accounts);

  final _MutableAccountsRepository accounts;
  final markedAccountIds = <String>[];

  @override
  Future<void> markReconnectRequired(
    String accountId, {
    int? authorizationGeneration,
  }) async {
    markedAccountIds.add(accountId);
    accounts.requireReconnect();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _RefreshPendingCalendarRepository
    extends _CalendarSourcesRepository {
  _RefreshPendingCalendarRepository(super.sources, this.nextcloud);
  final bool nextcloud;
  int calls = 0;
  @override
  Future<void> renameLocalSource(String sourceId, String summary) async {
    calls++;
    if (nextcloud) throw const NextcloudRefreshPending();
    throw const DavRefreshPending();
  }
}

final class _PartialRemovalRepository extends _CalendarSourcesRepository {
  _PartialRemovalRepository(super.sources);
  int calls = 0;
  @override
  Future<void> deleteLocalSource(String id) async {
    calls++;
    throw const DavException(
      kind: DavErrorKind.conflict,
      code: 'DavCollectionRemovalPartial',
      safeMessage: 'fixture',
    );
  }
}

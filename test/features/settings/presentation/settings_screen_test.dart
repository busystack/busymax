import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:yaru/yaru.dart';
import 'package:busymax/src/app/app_bootstrap.dart';
import 'package:busymax/src/app/busymax_design.dart';
import 'package:busymax/src/app/busymax_yaru_theme.dart';
import 'package:busymax/src/config/build_config.dart';
import 'package:busymax/src/features/accounts/data/accounts_repository.dart';
import 'package:busymax/src/features/auth/data/auth_repository.dart';
import 'package:busymax/src/features/settings/presentation/settings_screen.dart';
import 'package:busymax/src/features/sync/sync_auth_error.dart';
import 'package:busymax/src/platform/gtk_font_service.dart';
import 'package:busymax/src/features/task_lists/data/task_lists_repository.dart';
import 'package:busymax/src/features/tasks/presentation/desktop_date_time_fields.dart';
import 'package:busymax/src/task_providers/task_provider.dart';
import 'package:busymax/l10n/generated/app_localizations.dart';
import 'package:ubuntu_localizations/ubuntu_localizations.dart';

import '../../../test_localized_app.dart';

void main() {
  testWidgets('Settings removes the selected Microsoft account', (
    tester,
  ) async {
    final auth = _FakeAuthRepository();
    final container = _container(
      selectedAccountId: 'microsoft:m',
      authRepository: auth,
      accounts: const [_googleAccount, _microsoftAccount],
    );
    addTearDown(container.dispose);

    await _pumpSettings(tester, container);

    await _openAccountRemovalDialog(tester);
    expect(find.byKey(const Key('revoke-google-authorization')), findsNothing);
    await tester.tap(find.byKey(const Key('confirm-account-removal')));
    await tester.pumpAndSettle();

    expect(auth.removalCalls, [
      const _AccountRemovalCall('microsoft:m', revokeAuthorization: false),
    ]);
    expect(container.read(selectedAccountIdProvider), 'google:g');
  });

  testWidgets('Settings keeps Google revocation opt-in', (tester) async {
    final auth = _FakeAuthRepository();
    final container = _container(
      selectedAccountId: 'google:g',
      authRepository: auth,
      accounts: const [_googleAccount, _microsoftAccount],
    );
    addTearDown(container.dispose);

    await _pumpSettings(tester, container);

    await _openAccountRemovalDialog(tester);
    final revoke = find.byKey(const Key('revoke-google-authorization'));
    expect(revoke, findsOneWidget);
    expect(tester.widget<YaruCheckboxListTile>(revoke).value, isFalse);
    await tester.tap(revoke);
    await tester.pump();
    await tester.tap(find.byKey(const Key('confirm-account-removal')));
    await tester.pumpAndSettle();

    expect(auth.removalCalls, [
      const _AccountRemovalCall('google:g', revokeAuthorization: true),
    ]);
    expect(container.read(selectedAccountIdProvider), 'microsoft:m');
  });

  testWidgets('Settings cancels account removal without mutation', (
    tester,
  ) async {
    final auth = _FakeAuthRepository();
    final container = _container(
      selectedAccountId: 'google:g',
      authRepository: auth,
      accounts: const [_googleAccount, _microsoftAccount],
    );
    addTearDown(container.dispose);

    await _pumpSettings(tester, container);

    await _openAccountRemovalDialog(tester);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(auth.removalCalls, isEmpty);
    expect(container.read(selectedAccountIdProvider), 'google:g');
  });

  testWidgets('Settings exposes one clear account-removal action', (
    tester,
  ) async {
    final container = _container(
      selectedAccountId: 'google:g',
      authRepository: _FakeAuthRepository(),
      accounts: const [_googleAccount],
    );
    addTearDown(container.dispose);

    await _pumpSettings(tester, container);

    expect(find.text('Remove account…'), findsOneWidget);
    expect(
      find.text(
        'Stop syncing and remove this account’s data from this device.',
      ),
      findsOneWidget,
    );
    expect(find.text('Sign out this account'), findsNothing);
    expect(find.text('Disconnect this account'), findsNothing);
    expect(find.text('Delete local data for this account'), findsNothing);
  });

  testWidgets('Settings reports a local account-removal failure in place', (
    tester,
  ) async {
    final auth = _FakeAuthRepository()
      ..removeError = StateError('local cleanup failed');
    final container = _container(
      selectedAccountId: 'google:g',
      authRepository: auth,
      accounts: const [_googleAccount, _microsoftAccount],
    );
    addTearDown(container.dispose);

    await _pumpSettings(tester, container);
    await _openAccountRemovalDialog(tester);
    await tester.tap(find.byKey(const Key('confirm-account-removal')));
    await tester.pumpAndSettle();

    expect(container.read(selectedAccountIdProvider), 'google:g');
    expect(
      find.text('Could not finish removing the account. Try again.'),
      findsOneWidget,
    );
  });

  testWidgets('Settings prevents duplicate account-removal submission', (
    tester,
  ) async {
    final removal = Completer<AccountRemovalResult>();
    final auth = _FakeAuthRepository()..removalCompleter = removal;
    final container = _container(
      selectedAccountId: 'google:g',
      authRepository: auth,
      accounts: const [_googleAccount, _microsoftAccount],
    );
    addTearDown(container.dispose);

    await _pumpSettings(tester, container);
    await _openAccountRemovalDialog(tester);
    await tester.tap(find.byKey(const Key('confirm-account-removal')));
    await tester.pump();

    expect(auth.removalCalls, hasLength(1));
    expect(find.text('Removing account…'), findsOneWidget);
    await tester.tap(find.text('Removing account…'), warnIfMissed: false);
    await tester.pump();
    expect(auth.removalCalls, hasLength(1));

    removal.complete(
      const AccountRemovalResult(
        authorizationRevocationStatus:
            AccountAuthorizationRevocationStatus.notRequested,
      ),
    );
    await tester.pumpAndSettle();
    expect(container.read(selectedAccountIdProvider), 'microsoft:m');
  });

  testWidgets('Settings reports partial Google revocation failure', (
    tester,
  ) async {
    final auth = _FakeAuthRepository()
      ..removalResult = const AccountRemovalResult(
        authorizationRevocationStatus:
            AccountAuthorizationRevocationStatus.failed,
      );
    final container = _container(
      selectedAccountId: 'google:g',
      authRepository: auth,
      accounts: const [_googleAccount, _microsoftAccount],
    );
    addTearDown(container.dispose);

    await _pumpSettings(tester, container);
    await _openAccountRemovalDialog(tester);
    await tester.tap(find.byKey(const Key('revoke-google-authorization')));
    await tester.tap(find.byKey(const Key('confirm-account-removal')));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'The account was removed from this device, but BusyMax could not '
        'revoke Google access. You can revoke it from your Google Account.',
      ),
      findsOneWidget,
    );
    expect(container.read(selectedAccountIdProvider), 'microsoft:m');
  });

  testWidgets('Settings shows reconnect-required account state', (
    tester,
  ) async {
    final container = _container(
      selectedAccountId: 'google:g',
      authRepository: _FakeAuthRepository(),
      accounts: const [_reconnectRequiredGoogleAccount],
    );
    addTearDown(container.dispose);

    await _pumpSettings(tester, container);

    expect(find.text(accountReconnectRequiredActionLabel), findsOneWidget);
    expect(find.text(accountReconnectRequiredSyncMessage), findsOneWidget);
    expect(find.text('New list'), findsNothing);
    expect(find.text('Remove account…'), findsOneWidget);

    await _openAccountRemovalDialog(tester);
    expect(find.byKey(const Key('revoke-google-authorization')), findsNothing);
  });

  testWidgets('Settings exposes add account actions', (tester) async {
    final container = _container(
      selectedAccountId: 'google:g',
      authRepository: _FakeAuthRepository(),
      accounts: const [_googleAccount],
      buildConfig: _configuredBuildConfig,
    );
    addTearDown(container.dispose);

    await _pumpSettings(tester, container);

    expect(find.text('Add Google account'), findsOneWidget);
    expect(find.text('Add Microsoft account'), findsOneWidget);
  });

  testWidgets('Settings sidebar separates settings pages', (tester) async {
    final container = _container(
      selectedAccountId: 'google:g',
      authRepository: _FakeAuthRepository(),
      accounts: const [_googleAccount],
      buildConfig: _configuredBuildConfig,
      activeAccountIdOverride: null,
    );
    addTearDown(container.dispose);

    await _pumpSettings(tester, container, logicalSize: const Size(1000, 700));

    expect(find.text('Add Google account'), findsOneWidget);
    expect(find.text('Theme'), findsNothing);
    expect(find.text('Appearance'), findsNothing);
    expect(find.text('Localization'), findsNothing);
    expect(find.text('Sync'), findsNothing);

    await tester.tap(find.text('Schedule'));
    await tester.pumpAndSettle();

    expect(find.text('Day starts at'), findsOneWidget);
    expect(find.text('Day ends at'), findsOneWidget);
    expect(find.text('Add Google account'), findsNothing);

    await tester.tap(find.text('System'));
    await tester.pumpAndSettle();

    expect(find.text('Theme'), findsOneWidget);
    expect(find.text('Current locale'), findsOneWidget);
    expect(find.text('Manual full sync'), findsOneWidget);
    expect(find.text('Theme family'), findsNothing);
    expect(find.text('Add Google account'), findsNothing);
  });

  testWidgets('Settings content uses the native view surface', (tester) async {
    final container = _container(
      selectedAccountId: 'google:g',
      authRepository: _FakeAuthRepository(),
      accounts: const [_googleAccount],
      buildConfig: _configuredBuildConfig,
      activeAccountIdOverride: null,
    );
    addTearDown(container.dispose);

    const gtkColors = GtkThemeColors(
      brightness: Brightness.light,
      window: Color(0xFFF0F1F2),
      view: Color(0xFFFFFFFF),
      sidebar: Color(0xFFE5E6E7),
    );
    final theme = BusyMaxYaruTheme.build(
      brightness: Brightness.light,
      accentColor: YaruColors.orange,
      gtkThemeColors: gtkColors,
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: localizedTestApp(
          child: Theme(data: theme, child: const SettingsScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    expect(scaffold.backgroundColor, gtkColors.view);
    expect(scaffold.backgroundColor, isNot(gtkColors.window));
  });

  testWidgets('Settings uses Yaru master-detail rows with selected semantics', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final container = _container(
      selectedAccountId: 'google:g',
      authRepository: _FakeAuthRepository(),
      accounts: const [_googleAccount],
    );
    addTearDown(container.dispose);

    await _pumpSettings(tester, container, logicalSize: const Size(1000, 700));

    expect(find.byType(BusyMaxSidebarNavigation), findsOneWidget);
    expect(
      find.byType(YaruMasterTile),
      findsNWidgets(SettingsPage.values.length),
    );
    expect(find.byType(YaruNavigationRail), findsNothing);
    expect(find.byType(BusyMaxSidebarSurface), findsOneWidget);
    final accountsTile = tester.widget<BusyMaxSidebarNavigationTile>(
      find.byKey(const ValueKey('settings-navigation-accounts')),
    );
    final scheduleTile = tester.widget<BusyMaxSidebarNavigationTile>(
      find.byKey(const ValueKey('settings-navigation-schedule')),
    );
    expect(accountsTile.selected, isTrue);
    expect(scheduleTile.selected, isFalse);
    expect(
      tester
          .getSemantics(
            find.byKey(const ValueKey('settings-navigation-accounts')),
          )
          .flagsCollection
          .isSelected,
      ui.Tristate.isTrue,
    );
    expect(
      tester
          .getSemantics(
            find.byKey(const ValueKey('settings-navigation-schedule')),
          )
          .flagsCollection
          .isSelected,
      ui.Tristate.isFalse,
    );

    await tester.tap(find.text('Schedule'));
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<BusyMaxSidebarNavigationTile>(
            find.byKey(const ValueKey('settings-navigation-schedule')),
          )
          .selected,
      isTrue,
    );
    expect(
      tester
          .getSemantics(
            find.byKey(const ValueKey('settings-navigation-schedule')),
          )
          .flagsCollection
          .isSelected,
      ui.Tristate.isTrue,
    );
    semantics.dispose();
  });

  testWidgets('Diagnostics stays inside Settings shell', (tester) async {
    final container = _container(
      selectedAccountId: 'google:g',
      authRepository: _FakeAuthRepository(),
      accounts: const [_googleAccount],
      buildConfig: _configuredBuildConfig,
      activeAccountIdOverride: null,
    );
    addTearDown(container.dispose);

    await _pumpSettings(tester, container, logicalSize: const Size(1000, 700));

    await tester.tap(find.text('Diagnostics'));
    await tester.pumpAndSettle();

    expect(find.text('Google Tasks API'), findsOneWidget);
    expect(find.text('Accounts'), findsOneWidget);
    expect(find.text('System'), findsOneWidget);
    expect(find.text('Add Google account'), findsNothing);

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('Settings uses single-pane navigation at narrow widths', (
    tester,
  ) async {
    final container = _container(
      selectedAccountId: 'google:g',
      authRepository: _FakeAuthRepository(),
      accounts: const [_googleAccount],
      buildConfig: _configuredBuildConfig,
      activeAccountIdOverride: null,
    );
    addTearDown(container.dispose);

    await _pumpSettings(tester, container, logicalSize: const Size(640, 700));

    expect(find.text('Accounts'), findsWidgets);
    expect(find.text('Schedule'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('settings-page-selector')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Schedule'));
    await tester.pumpAndSettle();

    expect(find.text('Day starts at'), findsOneWidget);
    expect(find.text('Day ends at'), findsOneWidget);
  });

  testWidgets('Settings narrow layout supports large text', (tester) async {
    final container = _container(
      selectedAccountId: 'google:g',
      authRepository: _FakeAuthRepository(),
      accounts: const [_googleAccount],
    );
    addTearDown(container.dispose);

    await _pumpSettings(
      tester,
      container,
      logicalSize: const Size(640, 700),
      textScaler: const TextScaler.linear(2),
    );

    expect(
      find.byKey(const ValueKey('settings-page-selector')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Quiet-hour times are exposed and follow the master switch', (
    tester,
  ) async {
    final container = _container(
      selectedAccountId: 'google:g',
      authRepository: _FakeAuthRepository(),
      accounts: const [_googleAccount],
    );
    addTearDown(container.dispose);

    await _pumpSettings(tester, container, logicalSize: const Size(1000, 800));
    await tester.tap(find.text('Notifications'));
    await tester.pumpAndSettle();

    expect(find.text('Quiet hours start'), findsOneWidget);
    expect(find.text('Quiet hours end'), findsOneWidget);
    var timeRows = tester.widgetList<DesktopTimeValueRow>(
      find.byType(DesktopTimeValueRow),
    );
    expect(timeRows.every((row) => !row.enabled), isTrue);

    await tester.ensureVisible(find.text('Quiet hours'));
    await tester.tap(find.text('Quiet hours'));
    await tester.pumpAndSettle();

    timeRows = tester.widgetList<DesktopTimeValueRow>(
      find.byType(DesktopTimeValueRow),
    );
    expect(timeRows.every((row) => row.enabled), isTrue);
  });

  test('Schedule display hours persist and keep a valid range', () async {
    final store = _MemorySettingsStore();
    final first = AppSettingsController(store);
    await Future<void>.delayed(Duration.zero);

    await first.setScheduleDayStartMinute(9 * 60);
    await first.setScheduleDayEndMinute(18 * 60);

    final second = AppSettingsController(store);
    await Future<void>.delayed(Duration.zero);

    expect(second.state.scheduleDayStartMinute, 9 * 60);
    expect(second.state.scheduleDayEndMinute, 18 * 60);

    await second.setScheduleDayStartMinute(23 * 60);

    expect(second.state.scheduleDayStartMinute, 23 * 60);
    expect(second.state.scheduleDayEndMinute, 24 * 60);
  });

  testWidgets('Settings creates a new list for the account card', (
    tester,
  ) async {
    final googleLists = _FakeTaskListsRepository();
    final microsoftLists = _FakeTaskListsRepository();
    final container = _container(
      selectedAccountId: 'google:g',
      authRepository: _FakeAuthRepository(),
      accounts: const [_googleAccount, _microsoftAccount],
      buildConfig: _configuredBuildConfig,
      taskListRepositories: {
        'google:g': googleLists,
        'microsoft:m': microsoftLists,
      },
    );
    addTearDown(container.dispose);

    await _pumpSettings(tester, container);

    final newListButtons = find.text('New list');
    expect(newListButtons, findsNWidgets(2));

    await tester.ensureVisible(newListButtons.at(1));
    await tester.tap(newListButtons.at(1));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Client work');
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();

    expect(googleLists.createdTitles, isEmpty);
    expect(microsoftLists.createdTitles, ['Client work']);
    expect(container.read(selectedAccountIdProvider), 'google:g');
  });

  testWidgets('Settings lists accounts without account switching controls', (
    tester,
  ) async {
    final container = _container(
      selectedAccountId: 'google:g',
      authRepository: _FakeAuthRepository(),
      accounts: const [_googleAccount, _microsoftAccount],
      buildConfig: _configuredBuildConfig,
    );
    addTearDown(container.dispose);

    await _pumpSettings(tester, container);

    expect(find.text('Google Tasks'), findsOneWidget);
    expect(find.text('Google User · google@example.com'), findsOneWidget);
    expect(find.text('Microsoft To Do'), findsOneWidget);
    expect(find.text('Microsoft User · microsoft@example.com'), findsOneWidget);
    expect(find.text('Current account'), findsNothing);
    expect(find.text('Switch account'), findsNothing);
    expect(find.text('Fluent UI'), findsNothing);
    expect(container.read(selectedAccountIdProvider), 'google:g');
  });

  testWidgets('Settings back button returns to schedule', (tester) async {
    final container = _container(
      selectedAccountId: 'google:g',
      authRepository: _FakeAuthRepository(),
      accounts: const [_googleAccount],
    );
    addTearDown(container.dispose);

    await _pumpRoutedSettings(tester, container);

    await container
        .read(linuxHeaderBarServiceProvider)
        .handleNativeMethodCall(const MethodCall('back'));
    await tester.pumpAndSettle();

    expect(find.text('schedule route'), findsOneWidget);
  });

  testWidgets('Settings back returns to the route that opened it', (
    tester,
  ) async {
    final container = _container(
      selectedAccountId: 'google:g',
      authRepository: _FakeAuthRepository(),
      accounts: const [_googleAccount],
    );
    addTearDown(container.dispose);

    final router = await _pumpRoutedSettings(
      tester,
      container,
      initialLocation: '/tasks',
    );
    unawaited(router.push('/settings'));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsScreen), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('settings-page-selector')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Notifications'));
    await tester.pumpAndSettle();
    expect(router.state.uri.queryParameters['page'], 'notifications');

    await container
        .read(linuxHeaderBarServiceProvider)
        .handleNativeMethodCall(const MethodCall('back'));
    await tester.pumpAndSettle();

    expect(find.text('tasks route'), findsOneWidget);
  });

  testWidgets('Removing last account routes to sign in cleanly', (
    tester,
  ) async {
    final auth = _FakeAuthRepository();
    final container = _container(
      selectedAccountId: 'google:g',
      authRepository: auth,
      accounts: const [_googleAccount],
    );
    addTearDown(container.dispose);

    await _pumpRoutedSettings(tester, container);

    await _openAccountRemovalDialog(tester);
    await tester.tap(find.byKey(const Key('confirm-account-removal')));
    await tester.pumpAndSettle();

    expect(auth.removalCalls, [
      const _AccountRemovalCall('google:g', revokeAuthorization: false),
    ]);
    expect(container.read(selectedAccountIdProvider), isNull);
    expect(find.text('sign in route'), findsOneWidget);
  });
}

Future<void> _openAccountRemovalDialog(WidgetTester tester) async {
  await tester.tap(find.text('Remove account…').first);
  await tester.pumpAndSettle();
  expect(find.textContaining('from BusyMax?'), findsOneWidget);
}

ProviderContainer _container({
  required String selectedAccountId,
  required _FakeAuthRepository authRepository,
  required List<AccountEntity> accounts,
  BuildConfig buildConfig = _emptyBuildConfig,
  Map<String, _FakeTaskListsRepository>? taskListRepositories,
  String? activeAccountIdOverride = _useDefaultActiveAccountId,
}) {
  return ProviderContainer(
    overrides: [
      authRepositoryProvider.overrideWithValue(authRepository),
      accountsRepositoryProvider.overrideWithValue(
        _FakeAccountsRepository(accounts),
      ),
      accountsStreamProvider.overrideWith((ref) => Stream.value(accounts)),
      accountManagementStreamProvider.overrideWith(
        (ref) => Stream.value(accounts),
      ),
      selectedAccountIdProvider.overrideWith((ref) => selectedAccountId),
      if (activeAccountIdOverride != _useDefaultActiveAccountId)
        activeAccountProvider.overrideWithValue(activeAccountIdOverride),
      localSettingsStoreProvider.overrideWithValue(_MemorySettingsStore()),
      syncEngineProvider.overrideWithValue(null),
      buildConfigProvider.overrideWithValue(buildConfig),
      taskListsRepositoryForAccountProvider.overrideWith((ref, accountId) {
        return taskListRepositories?[accountId] ?? _FakeTaskListsRepository();
      }),
    ],
  );
}

const _useDefaultActiveAccountId = '__busymax_default_active_account__';

Future<void> _pumpSettings(
  WidgetTester tester,
  ProviderContainer container, {
  Size? logicalSize,
  TextScaler? textScaler,
}) async {
  if (logicalSize != null) {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = logicalSize;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
  }
  final settings = textScaler == null
      ? const SettingsScreen()
      : Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: textScaler),
            child: const SettingsScreen(),
          ),
        );
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: localizedTestApp(child: settings),
    ),
  );
  await tester.pumpAndSettle();
}

Future<GoRouter> _pumpRoutedSettings(
  WidgetTester tester,
  ProviderContainer container, {
  String initialLocation = '/settings',
}) async {
  final router = GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(path: '/settings', builder: (_, _) => const SettingsScreen()),
      GoRoute(
        path: '/schedule',
        builder: (_, _) => const Text('schedule route'),
      ),
      GoRoute(path: '/tasks', builder: (_, _) => const Text('tasks route')),
      GoRoute(path: '/sign-in', builder: (_, _) => const Text('sign in route')),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        locale: const Locale('en'),
        localizationsDelegates: const [
          ...AppLocalizations.localizationsDelegates,
          ...GlobalUbuntuLocalizations.delegates,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}

class _FakeAuthRepository implements AuthRepository {
  final removalCalls = <_AccountRemovalCall>[];
  AccountRemovalResult removalResult = const AccountRemovalResult(
    authorizationRevocationStatus:
        AccountAuthorizationRevocationStatus.notRequested,
  );
  Completer<AccountRemovalResult>? removalCompleter;
  Object? removeError;

  @override
  Future<AccountRemovalResult> removeAccount({
    required String accountId,
    bool revokeAuthorization = false,
  }) async {
    removalCalls.add(
      _AccountRemovalCall(accountId, revokeAuthorization: revokeAuthorization),
    );
    final error = removeError;
    if (error != null) {
      throw error;
    }
    final completer = removalCompleter;
    return completer == null ? removalResult : completer.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _AccountRemovalCall {
  const _AccountRemovalCall(
    this.accountId, {
    required this.revokeAuthorization,
  });

  final String accountId;
  final bool revokeAuthorization;

  @override
  bool operator ==(Object other) {
    return other is _AccountRemovalCall &&
        other.accountId == accountId &&
        other.revokeAuthorization == revokeAuthorization;
  }

  @override
  int get hashCode => Object.hash(accountId, revokeAuthorization);
}

class _FakeAccountsRepository implements AccountsRepository {
  const _FakeAccountsRepository(this.accounts);

  final List<AccountEntity> accounts;

  @override
  Future<List<AccountEntity>> listSignedInAccounts() async => accounts;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeTaskListsRepository implements TaskListsRepository {
  final createdTitles = <String>[];

  @override
  Future<void> createTaskList(String title) async {
    createdTitles.add(title);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MemorySettingsStore implements LocalSettingsStore {
  Map<String, Object?> value = {};

  @override
  Future<Map<String, Object?>> load() async => value;

  @override
  Future<void> save(Map<String, Object?> json) async {
    value = json;
  }
}

const _googleAccount = AccountEntity(
  id: 'google:g',
  provider: TaskProvider.google,
  displayName: 'Google User',
  email: 'google@example.com',
  authState: 'signed_in',
);

const _microsoftAccount = AccountEntity(
  id: 'microsoft:m',
  provider: TaskProvider.microsoft,
  displayName: 'Microsoft User',
  email: 'microsoft@example.com',
  authState: 'signed_in',
);

const _reconnectRequiredGoogleAccount = AccountEntity(
  id: 'google:g',
  provider: TaskProvider.google,
  displayName: 'Google User',
  email: 'google@example.com',
  authState: accountAuthStateReauthRequired,
);

const _emptyBuildConfig = BuildConfig(
  googleOAuthClientId: '',
  googleOAuthClientSecret: '',
  microsoftOAuthClientId: '',
  apiBaseUrl: 'https://tasks.googleapis.com',
  oauthAuthorizationEndpoint: 'https://accounts.google.com/o/oauth2/v2/auth',
  oauthTokenEndpoint: 'https://oauth2.googleapis.com/token',
  oauthRevocationEndpoint: 'https://oauth2.googleapis.com/revoke',
);

const _configuredBuildConfig = BuildConfig(
  googleOAuthClientId: 'google-client',
  googleOAuthClientSecret: '',
  microsoftOAuthClientId: 'microsoft-client',
  apiBaseUrl: 'https://tasks.googleapis.com',
  oauthAuthorizationEndpoint: 'https://accounts.google.com/o/oauth2/v2/auth',
  oauthTokenEndpoint: 'https://oauth2.googleapis.com/token',
  oauthRevocationEndpoint: 'https://oauth2.googleapis.com/revoke',
);

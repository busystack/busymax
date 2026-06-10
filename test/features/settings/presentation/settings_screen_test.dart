import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:busymax/src/app/app_bootstrap.dart';
import 'package:busymax/src/config/build_config.dart';
import 'package:busymax/src/features/accounts/data/accounts_repository.dart';
import 'package:busymax/src/features/auth/data/auth_repository.dart';
import 'package:busymax/src/features/settings/presentation/settings_screen.dart';
import 'package:busymax/src/features/task_lists/data/task_lists_repository.dart';
import 'package:busymax/src/features/tasks/presentation/tasks_selection_state.dart';
import 'package:busymax/src/task_providers/task_provider.dart';
import 'package:busymax/l10n/generated/app_localizations.dart';
import 'package:ubuntu_localizations/ubuntu_localizations.dart';

import '../../../test_localized_app.dart';

void main() {
  testWidgets('Settings sign out passes selected account id', (tester) async {
    final auth = _FakeAuthRepository();
    final container = _container(
      selectedAccountId: 'microsoft:m',
      authRepository: auth,
      accounts: const [_googleAccount, _microsoftAccount],
    );
    addTearDown(container.dispose);

    await _pumpSettings(tester, container);

    await tester.tap(find.text('Sign out this account').first);
    await tester.pumpAndSettle();

    expect(auth.signOutAccountIds, ['microsoft:m']);
    expect(container.read(selectedAccountIdProvider), 'google:g');
    expect(container.read(selectedTaskListIdProvider), isNull);
    expect(container.read(selectedTaskIdProvider), isNull);
  });

  testWidgets('Settings disconnect passes selected account id', (tester) async {
    final auth = _FakeAuthRepository();
    final container = _container(
      selectedAccountId: 'google:g',
      authRepository: auth,
      accounts: const [_googleAccount, _microsoftAccount],
    );
    addTearDown(container.dispose);

    await _pumpSettings(tester, container);

    await tester.tap(find.text('Disconnect this account').first);
    await tester.pumpAndSettle();

    expect(auth.revokedAccountIds, ['google:g']);
    expect(container.read(selectedAccountIdProvider), 'microsoft:m');
  });

  testWidgets('Settings delete local data passes selected account id', (
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

    await tester.tap(find.text('Delete local data for this account').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete').last);
    await tester.pumpAndSettle();

    expect(auth.deletedAccountIds, ['google:g']);
    expect(container.read(selectedAccountIdProvider), 'microsoft:m');
  });

  testWidgets('Settings labels are provider-neutral', (tester) async {
    final container = _container(
      selectedAccountId: 'google:g',
      authRepository: _FakeAuthRepository(),
      accounts: const [_googleAccount],
    );
    addTearDown(container.dispose);

    await _pumpSettings(tester, container);

    expect(find.text('Sign out this account'), findsOneWidget);
    expect(find.text('Disconnect this account'), findsOneWidget);
    expect(find.text('Delete local data for this account'), findsOneWidget);
    expect(find.text('Revoke Google authorization'), findsNothing);
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

    await _pumpSettings(tester, container);

    expect(find.text('Add Google account'), findsOneWidget);
    expect(find.text('Theme'), findsNothing);
    expect(find.text('Appearance'), findsNothing);
    expect(find.text('Localization'), findsNothing);
    expect(find.text('Sync'), findsNothing);

    await tester.tap(find.text('System'));
    await tester.pumpAndSettle();

    expect(find.text('Theme'), findsOneWidget);
    expect(find.text('Current locale'), findsOneWidget);
    expect(find.text('Manual full sync'), findsOneWidget);
    expect(find.text('Theme family'), findsNothing);
    expect(find.text('Add Google account'), findsNothing);
  });

  test('Settings sidebar items have native-feeling side padding', () {
    final source = File(
      'lib/src/features/settings/presentation/settings_screen.dart',
    ).readAsStringSync();

    expect(source, contains('const SizedBox(width: BusyMaxSpacing.md)'));
    expect(
      source,
      isNot(
        contains(
          'const SizedBox(width: BusyMaxSpacing.xs),\n                Icon(',
        ),
      ),
    );
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

    await _pumpSettings(tester, container);

    await tester.tap(find.text('Diagnostics'));
    await tester.pumpAndSettle();

    expect(find.text('Google Tasks API'), findsOneWidget);
    expect(find.text('Accounts'), findsOneWidget);
    expect(find.text('System'), findsOneWidget);
    expect(find.text('Add Google account'), findsNothing);

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
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

    await tester.tap(find.text('Sign out this account').first);
    await tester.pumpAndSettle();

    expect(auth.signOutAccountIds, ['google:g']);
    expect(container.read(selectedAccountIdProvider), isNull);
    expect(find.text('sign in route'), findsOneWidget);
  });
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
  ProviderContainer container,
) async {
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: localizedTestApp(child: const SettingsScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _pumpRoutedSettings(
  WidgetTester tester,
  ProviderContainer container,
) async {
  final router = GoRouter(
    initialLocation: '/settings',
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
}

class _FakeAuthRepository implements AuthRepository {
  final signOutAccountIds = <String>[];
  final revokedAccountIds = <String>[];
  final deletedAccountIds = <String>[];

  @override
  Future<void> signOut({String? accountId}) async {
    signOutAccountIds.add(accountId ?? '');
  }

  @override
  Future<void> revokeAndSignOut({String? accountId}) async {
    revokedAccountIds.add(accountId ?? '');
  }

  @override
  Future<void> deleteLocalAccountData({String? accountId}) async {
    deletedAccountIds.add(accountId ?? '');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
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

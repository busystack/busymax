import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:busymax/src/app/app_bootstrap.dart';
import 'package:busymax/src/app/busymax_app.dart';
import 'package:busymax/src/config/build_config.dart';
import 'package:busymax/src/db/app_database.dart';
import 'package:busymax/src/features/accounts/data/accounts_repository.dart';
import 'package:busymax/src/features/auth/data/auth_repository.dart';
import 'package:busymax/src/features/schedule/presentation/schedule_workspace.dart';
import 'package:busymax/src/features/settings/presentation/settings_screen.dart';
import 'package:busymax/src/features/sync/sync_auth_error.dart';
import 'package:busymax/src/google_tasks/api/google_tasks_api_surface.dart';
import 'package:busymax/src/google_tasks/oauth/oauth_models.dart';
import 'package:busymax/src/google_tasks/oauth/oauth_service.dart';
import 'package:busymax/src/google_tasks/oauth/oauth_token_store.dart';
import 'package:busymax/src/platform/linux_header_bar_service.dart';
import 'package:busymax/src/schedule/schedule_scope.dart';
import 'package:busymax/src/task_providers/task_provider.dart';

void main() {
  late AppDatabase database;
  late _FakeOAuthGateway oAuth;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    oAuth = _FakeOAuthGateway();
  });

  tearDown(() async {
    await database.close();
  });

  testWidgets('signed-out app shows sign-in route', (tester) async {
    await _pumpApp(tester, database: database, oAuth: oAuth);

    await tester.pumpAndSettle();

    expect(find.text('Connect accounts'), findsOneWidget);
    expect(
      find.text(
        'Connect Google and Microsoft accounts to sync calendars and tasks.',
      ),
      findsOneWidget,
    );
    expect(
      find.text(
        'On the Google permission screen, select both Calendar and Tasks permissions.',
      ),
      findsOneWidget,
    );
    expect(
      find.textContaining('Add all Google and Microsoft accounts'),
      findsNothing,
    );
    expect(find.text('Add Google account'), findsOneWidget);
    expect(find.text('Add Microsoft account'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Add Google account')).dy,
      lessThan(tester.getTopLeft(find.text('Add Microsoft account')).dy),
    );
    expect(find.text('Google'), findsNothing);
    expect(find.text('Microsoft To Do'), findsNothing);
    expect(find.text('Accounts'), findsNothing);
    expect(find.textContaining('sync tasks'), findsNothing);
    expect(find.text('Tasks'), findsNothing);
    await _disposeApp(tester);
  });

  test('setup provider actions use BusyMax row patterns', () {
    final source = File(
      'lib/src/features/auth/presentation/sign_in_screen.dart',
    ).readAsStringSync();
    final start = source.indexOf('class _ProviderSignInButton');
    final end = source.indexOf('class _OnboardingFooter');
    final providerButton = source.substring(start, end);

    expect(providerButton, contains('BusyMaxGroupedList'));
    expect(providerButton, contains('BusyMaxActionRow'));
    expect(providerButton, isNot(contains('BusyMaxPushButton')));
    expect(providerButton, isNot(contains('FilledButton')));
    expect(providerButton, isNot(contains('ElevatedButton')));
    expect(providerButton, isNot(contains('OutlinedButton')));
  });

  testWidgets('missing Google permissions shows retry guidance', (
    tester,
  ) async {
    oAuth.nextTokenSet = _tokenSet(scopes: {googleTasksReadWriteScope});
    await _pumpApp(tester, database: database, oAuth: oAuth);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add Google account'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Google Calendar and Google Tasks permissions are required. Please try again and select both checkboxes.',
      ),
      findsOneWidget,
    );
    expect(await database.select(database.accounts).get(), isEmpty);
    await _disposeApp(tester);
  });

  testWidgets('successful sign-in waits for user to finish onboarding', (
    tester,
  ) async {
    await _pumpApp(tester, database: database, oAuth: oAuth);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add Google account'));
    await tester.pumpAndSettle();

    final account = await database.select(database.accounts).getSingle();
    expect(account.authState, 'signed_in');
    expect(account.grantedScopes, googleBusyMaxOAuthScopes.join(' '));
    expect(find.text('Choose system settings'), findsNothing);
    expect(find.byType(ScheduleWorkspace), findsNothing);
    expect(find.text('Accounts'), findsOneWidget);
    expect(find.text('Albert Busy'), findsOneWidget);
    expect(find.text('albert@example.com'), findsOneWidget);

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(find.text('Choose system settings'), findsOneWidget);
    expect(find.text('Notification detail level'), findsOneWidget);
    expect(find.text('Detailed notification text'), findsNothing);

    await tester.tap(find.text('Finish setup'));
    await tester.pumpAndSettle();

    expect(find.byType(ScheduleWorkspace), findsOneWidget);
    expect(find.text('Today'), findsOneWidget);
    await _disposeApp(tester);
  });

  testWidgets('Tasks navigation stays on schedule calendar surface', (
    tester,
  ) async {
    await _pumpApp(tester, database: database, oAuth: oAuth);
    await tester.pumpAndSettle();

    await _completeOnboardingWithGoogle(tester);

    expect(find.byType(ScheduleWorkspace), findsOneWidget);

    GoRouter.of(tester.element(find.byType(ScheduleWorkspace))).go('/tasks');
    await tester.pumpAndSettle();

    expect(find.byType(ScheduleWorkspace), findsOneWidget);

    final accountId = (await database.select(database.accounts).getSingle()).id;
    await database.taskListsDao.upsertTaskList(
      TaskListsCompanion.insert(
        accountId: accountId,
        id: 'list-1',
        title: 'Route list',
        rawJson: '{}',
        createdLocalAtUtc: '2026-06-04T00:00:00.000Z',
        updatedLocalAtUtc: '2026-06-04T00:00:00.000Z',
      ),
    );
    await database.tasksDao.upsertTask(
      TasksCompanion.insert(
        accountId: accountId,
        taskListId: 'list-1',
        id: 'task-1',
        title: 'Route task',
        status: const Value('needsAction'),
        rawJson: '{}',
        createdLocalAtUtc: '2026-06-04T00:00:00.000Z',
        updatedLocalAtUtc: '2026-06-04T00:00:00.000Z',
      ),
    );
    final router = GoRouter.of(tester.element(find.byType(ScheduleWorkspace)));
    router.go(
      Uri(
        pathSegments: ['', 'tasks', accountId, 'list-1', 'task-1'],
      ).toString(),
    );
    await tester.pumpAndSettle();

    final deepLinkedWorkspace = tester.widget<ScheduleWorkspace>(
      find.byType(ScheduleWorkspace),
    );
    expect(deepLinkedWorkspace.initialScope, ScheduleScope.tasks);
    expect(deepLinkedWorkspace.initialTaskAccountId, accountId);
    expect(deepLinkedWorkspace.initialTaskListId, 'list-1');
    expect(deepLinkedWorkspace.initialTaskId, 'task-1');
    expect(find.text('Edit Task'), findsOneWidget);

    final routedWorkspaceState = tester.state(find.byType(ScheduleWorkspace));
    final titleField = find.byType(TextField).first;
    await tester.enterText(titleField, 'Unsaved route title');
    await tester.pump();
    router.go(
      Uri(
        pathSegments: ['', 'tasks', accountId, 'list-1', 'missing-task'],
      ).toString(),
    );
    await tester.pump();
    expect(
      tester.state(find.byType(ScheduleWorkspace)),
      same(routedWorkspaceState),
    );
    await tester.pumpAndSettle();

    expect(find.text('Discard changes?'), findsOneWidget);
    await tester.tap(find.text('Cancel').last);
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.pathSegments, [
      'tasks',
      accountId,
      'list-1',
      'task-1',
    ]);
    expect(find.text('Edit Task'), findsOneWidget);

    router.go(Uri(pathSegments: ['', 'tasks', accountId, 'list-1']).toString());
    await tester.pumpAndSettle();
    expect(find.text('Discard changes?'), findsOneWidget);
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();

    expect(router.routeInformationProvider.value.uri.pathSegments, [
      'tasks',
      accountId,
      'list-1',
    ]);
    expect(find.text('Edit Task'), findsNothing);
    await _disposeApp(tester);
  });

  testWidgets('callback failure shows friendly message', (tester) async {
    oAuth.signInError = const OAuthException(
      'OAuthCallbackTimeout',
      'raw timeout',
    );
    await _pumpApp(tester, database: database, oAuth: oAuth);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add Google account'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Google sign-in callback was not received by BusyMax. Try signing in '
        'again. If the browser opened an old tab, close it and start sign-in '
        'again.',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('HttpException'), findsNothing);
    expect(find.textContaining('raw timeout'), findsNothing);
    await _disposeApp(tester);
  });

  testWidgets('secure storage failure shows friendly message', (tester) async {
    oAuth.signInError = PlatformException(
      code: 'KeyringLocked',
      message: 'raw keyring message',
    );
    await _pumpApp(tester, database: database, oAuth: oAuth);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add Google account'));
    await tester.pumpAndSettle();

    expect(find.text(secureTokenStorageUnavailableMessage), findsOneWidget);
    expect(find.textContaining('PlatformException'), findsNothing);
    expect(find.textContaining('raw keyring message'), findsNothing);
    await _disposeApp(tester);
  });

  testWidgets('sign-in button is disabled while signing in', (tester) async {
    oAuth.signInCompleter = Completer<OAuthSignInResult>();
    await _pumpApp(tester, database: database, oAuth: oAuth);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add Google account'));
    await tester.pump();

    expect(find.text('Waiting for Google sign-in...'), findsOneWidget);
    expect(find.text('Waiting for Microsoft sign-in...'), findsNothing);
    expect(oAuth.signInCalls, 1);

    await tester.tap(
      find.text('Waiting for Google sign-in...'),
      warnIfMissed: false,
    );
    await tester.pump();
    expect(oAuth.signInCalls, 1);

    oAuth.signInCompleter!.complete(
      OAuthSignInResult(accountId: 'account-1', tokenSet: _tokenSet()),
    );
    await tester.pumpAndSettle();
    expect(find.byType(ScheduleWorkspace), findsNothing);
    expect(find.text('Continue'), findsOneWidget);
    await _disposeApp(tester);
  });

  testWidgets(
    'adding an account keeps Settings open during and after cancellation',
    (tester) async {
      await _insertAccount(
        database,
        id: 'google:existing',
        provider: TaskProvider.google,
      );
      oAuth.signInCompleter = Completer<OAuthSignInResult>();
      await _pumpApp(tester, database: database, oAuth: oAuth);
      await tester.pumpAndSettle();
      await _openSettings(tester);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(SettingsScreen)),
      );

      await tester.tap(find.text('Add Google account'));
      await tester.pump();

      final sessionWhileConnecting = container.read(
        authSessionControllerProvider,
      );
      final settingsStayedOpen = find.byType(SettingsScreen).evaluate().length;

      oAuth.signInCompleter!.completeError(
        const OAuthException('OAuthSignInCancelled', 'Sign-in cancelled.'),
      );
      await tester.pumpAndSettle();

      expect(oAuth.signInCalls, 1);
      expect(settingsStayedOpen, 1);
      _expectExistingSessionSignedIn(sessionWhileConnecting, 'google:existing');
      expect(find.byType(SettingsScreen), findsOneWidget);
      expect(find.text('Connect accounts'), findsNothing);
      _expectExistingSessionSignedIn(
        container.read(authSessionControllerProvider),
        'google:existing',
      );
      expect(
        (await database.select(database.accounts).getSingle()).authState,
        accountAuthStateSignedIn,
      );
      await _disposeApp(tester);
    },
  );

  testWidgets(
    'successful account add syncs the new account without replacing session',
    (tester) async {
      await _insertAccount(
        database,
        id: 'microsoft:existing',
        provider: TaskProvider.microsoft,
      );
      final syncCalls = <({String accountId, bool initial})>[];
      await _pumpApp(
        tester,
        database: database,
        oAuth: oAuth,
        onSignedIn: (accountId, initial) async {
          syncCalls.add((accountId: accountId, initial: initial));
        },
      );
      await tester.pumpAndSettle();
      syncCalls.clear();
      await _openSettings(tester);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(SettingsScreen)),
      );

      await tester.tap(find.text('Add Google account'));
      await tester.pumpAndSettle();

      expect(oAuth.signInCalls, 1);
      expect(syncCalls, [(accountId: 'account-1', initial: true)]);
      _expectExistingSessionSignedIn(
        container.read(authSessionControllerProvider),
        'microsoft:existing',
      );
      expect(find.byType(SettingsScreen), findsOneWidget);
      expect(find.text('Connect accounts'), findsNothing);
      final accounts = await database.select(database.accounts).get();
      expect(
        accounts
            .where((account) => account.authState == accountAuthStateSignedIn)
            .map((account) => account.id),
        containsAll(['microsoft:existing', 'account-1']),
      );
      await _disposeApp(tester);
    },
  );

  testWidgets(
    'account add failure stays in Settings and preserves the session',
    (tester) async {
      await _insertAccount(
        database,
        id: 'microsoft:existing',
        provider: TaskProvider.microsoft,
      );
      oAuth.signInError = const OAuthException(
        'OAuthCallbackTimeout',
        'raw timeout',
      );
      await _pumpApp(tester, database: database, oAuth: oAuth);
      await tester.pumpAndSettle();
      await _openSettings(tester);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(SettingsScreen)),
      );

      await tester.tap(find.text('Add Google account'));
      await tester.pumpAndSettle();

      expect(oAuth.signInCalls, 1);
      expect(find.byType(SettingsScreen), findsOneWidget);
      expect(
        find.text(
          'Google sign-in callback was not received by BusyMax. Try signing '
          'in again. If the browser opened an old tab, close it and start '
          'sign-in again.',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('raw timeout'), findsNothing);
      _expectExistingSessionSignedIn(
        container.read(authSessionControllerProvider),
        'microsoft:existing',
      );
      expect(
        (await database.select(database.accounts).getSingle()).authState,
        accountAuthStateSignedIn,
      );
      await _disposeApp(tester);
    },
  );

  testWidgets(
    'reconnecting an account keeps the existing session and Settings route',
    (tester) async {
      await _insertAccount(
        database,
        id: 'microsoft:existing',
        provider: TaskProvider.microsoft,
      );
      await _insertAccount(
        database,
        id: 'google:reconnect',
        provider: TaskProvider.google,
        authState: accountAuthStateReauthRequired,
      );
      oAuth.signInCompleter = Completer<OAuthSignInResult>();
      await _pumpApp(tester, database: database, oAuth: oAuth);
      await tester.pumpAndSettle();
      await _openSettings(tester);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(SettingsScreen)),
      );

      await tester.tap(find.text(accountReconnectRequiredActionLabel));
      await tester.pump();

      final sessionWhileReconnecting = container.read(
        authSessionControllerProvider,
      );
      final settingsStayedOpen = find.byType(SettingsScreen).evaluate().length;

      oAuth.signInCompleter!.completeError(
        const OAuthException('OAuthSignInCancelled', 'Sign-in cancelled.'),
      );
      await tester.pumpAndSettle();

      expect(oAuth.signInCalls, 1);
      expect(settingsStayedOpen, 1);
      _expectExistingSessionSignedIn(
        sessionWhileReconnecting,
        'microsoft:existing',
      );
      expect(find.byType(SettingsScreen), findsOneWidget);
      expect(find.text('Connect accounts'), findsNothing);
      _expectExistingSessionSignedIn(
        container.read(authSessionControllerProvider),
        'microsoft:existing',
      );
      final accounts = await database.select(database.accounts).get();
      expect(
        accounts
            .singleWhere((account) => account.id == 'microsoft:existing')
            .authState,
        accountAuthStateSignedIn,
      );
      await _disposeApp(tester);
    },
  );
}

Future<void> _completeOnboardingWithGoogle(WidgetTester tester) async {
  await tester.tap(find.text('Add Google account'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Continue'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Finish setup'));
  await tester.pumpAndSettle();
}

Future<void> _disposeApp(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(milliseconds: 1));
}

Future<void> _openSettings(WidgetTester tester) async {
  final schedule = find.byType(ScheduleWorkspace);
  expect(schedule, findsOneWidget);
  GoRouter.of(tester.element(schedule)).go('/settings');
  await tester.pumpAndSettle();
  expect(find.byType(SettingsScreen), findsOneWidget);
}

void _expectExistingSessionSignedIn(
  AuthSessionState session,
  String accountId,
) {
  expect(session.status, AuthSessionStatus.signedIn);
  expect(session.accountId, accountId);
}

Future<void> _insertAccount(
  AppDatabase database, {
  required String id,
  required TaskProvider provider,
  String authState = accountAuthStateSignedIn,
}) {
  return database
      .into(database.accounts)
      .insert(
        AccountsCompanion.insert(
          id: id,
          provider: Value(provider.storageValue),
          authState: Value(authState),
          displayName: Value(provider.displayName),
          createdAtUtc: '2026-06-04T00:00:00.000Z',
          updatedAtUtc: '2026-06-04T00:00:00.000Z',
        ),
      );
}

Future<void> _pumpApp(
  WidgetTester tester, {
  required AppDatabase database,
  required _FakeOAuthGateway oAuth,
  SignedInSyncRunner? onSignedIn,
}) {
  return tester.pumpWidget(
    ProviderScope(
      overrides: [
        buildConfigProvider.overrideWithValue(_configuredBuildConfig),
        databaseProvider.overrideWithValue(database),
        authRepositoryProvider.overrideWithValue(
          AuthRepository(
            oAuth: oAuth,
            database: database,
            nowUtc: () => DateTime.utc(2026, 6, 4),
          ),
        ),
        signedInSyncRunnerProvider.overrideWithValue(
          onSignedIn ?? (accountId, initial) async {},
        ),
        syncEngineProvider.overrideWithValue(null),
        linuxHeaderBarServiceProvider.overrideWith((ref) {
          final service = LinuxHeaderBarService(isLinux: false);
          ref.onDispose(service.dispose);
          return service;
        }),
      ],
      child: const BusyMaxApp(),
    ),
  );
}

class _FakeOAuthGateway implements OAuthGateway {
  String? activeId;
  Object? signInError;
  Completer<OAuthSignInResult>? signInCompleter;
  OAuthTokenSet nextTokenSet = _tokenSet();
  var signInCalls = 0;

  @override
  Future<String?> get activeAccountId async => activeId;

  @override
  Future<void> cancelSignIn() async {}

  @override
  Future<OAuthTokenSet?> readActiveTokenSet() async {
    if (activeId == null) {
      return null;
    }
    return nextTokenSet;
  }

  @override
  Future<GoogleUserInfo?> fetchUserInfo(OAuthTokenSet tokenSet) async {
    return const GoogleUserInfo(
      subject: 'google-user-1',
      name: 'Albert Busy',
      email: 'albert@example.com',
      rawJson: {
        'sub': 'google-user-1',
        'name': 'Albert Busy',
        'email': 'albert@example.com',
      },
    );
  }

  @override
  Future<OAuthTokenSet> refreshActiveToken() async => nextTokenSet;

  @override
  Future<void> revokeAndSignOutAccount(String accountId) async {
    if (activeId == accountId) {
      activeId = null;
    }
  }

  @override
  Future<void> revokeAuthorization(String accountId) async {}

  @override
  Future<void> clearLocalSession({String? accountId}) async {
    activeId = null;
  }

  @override
  Future<OAuthSignInResult> signIn({String? loginHint}) async {
    signInCalls += 1;
    final error = signInError;
    if (error != null) {
      throw error;
    }
    final completer = signInCompleter;
    if (completer != null) {
      final result = await completer.future;
      activeId = result.accountId;
      return result;
    }
    activeId = 'account-1';
    return OAuthSignInResult(accountId: 'account-1', tokenSet: nextTokenSet);
  }
}

OAuthTokenSet _tokenSet({Set<String>? scopes}) {
  return OAuthTokenSet(
    accessToken: 'access',
    refreshToken: 'refresh',
    expiresAtUtc: DateTime.utc(2026, 6, 4, 1),
    tokenType: 'Bearer',
    scopes: scopes ?? Set<String>.of(googleBusyMaxOAuthScopes),
  );
}

const _configuredBuildConfig = BuildConfig(
  googleOAuthClientId: 'client-id',
  googleOAuthClientSecret: '',
  googleApiBaseUrl: 'https://www.googleapis.com',
  oauthAuthorizationEndpoint: 'https://accounts.google.com/o/oauth2/v2/auth',
  oauthTokenEndpoint: 'https://oauth2.googleapis.com/token',
  oauthRevocationEndpoint: 'https://oauth2.googleapis.com/revoke',
);

import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:busymax/src/app/app_bootstrap.dart';
import 'package:busymax/src/app/busymax_app.dart';
import 'package:busymax/src/config/build_config.dart';
import 'package:busymax/src/db/app_database.dart';
import 'package:busymax/src/features/auth/data/auth_repository.dart';
import 'package:busymax/src/features/schedule/presentation/schedule_workspace.dart';
import 'package:busymax/src/features/tasks/presentation/tasks_workspace.dart';
import 'package:busymax/src/google_tasks/api/google_tasks_api_surface.dart';
import 'package:busymax/src/google_tasks/oauth/oauth_models.dart';
import 'package:busymax/src/google_tasks/oauth/oauth_service.dart';

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
    expect(find.text('Signed in'), findsOneWidget);
    expect(find.text('Albert Busy'), findsOneWidget);
    expect(find.text('albert@example.com'), findsOneWidget);

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(find.text('Choose system settings'), findsOneWidget);

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
    expect(find.byType(TasksWorkspace), findsNothing);

    GoRouter.of(tester.element(find.byType(ScheduleWorkspace))).go('/tasks');
    await tester.pumpAndSettle();

    expect(find.byType(ScheduleWorkspace), findsOneWidget);
    expect(find.byType(TasksWorkspace), findsNothing);
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

Future<void> _pumpApp(
  WidgetTester tester, {
  required AppDatabase database,
  required _FakeOAuthGateway oAuth,
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
          (accountId, initial) async {},
        ),
        syncEngineProvider.overrideWithValue(null),
      ],
      child: const BusyMaxApp(),
    ),
  );
}

class _FakeOAuthGateway implements OAuthGateway {
  String? activeId;
  OAuthException? signInError;
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
  Future<void> signOutAccount(String accountId) async {
    if (activeId == accountId) {
      activeId = null;
    }
  }

  @override
  Future<void> signOut() async {
    activeId = null;
  }

  @override
  Future<void> revokeAndSignOutAccount(String accountId) async {
    if (activeId == accountId) {
      activeId = null;
    }
  }

  @override
  Future<void> revokeAndSignOut() async {
    activeId = null;
  }

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

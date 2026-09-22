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
import 'package:busymax/src/app/app_router.dart';
import 'package:busymax/src/app/busymax_app.dart';
import 'package:busymax/src/app/busymax_design.dart';
import 'package:busymax/src/app/linux/linux_header_style.dart';
import 'package:busymax/src/config/build_config.dart';
import 'package:busymax/src/db/app_database.dart';
import 'package:busymax/src/features/accounts/data/accounts_repository.dart';
import 'package:busymax/src/features/auth/data/auth_repository.dart';
import 'package:busymax/src/features/schedule/presentation/schedule_workspace.dart';
import 'package:busymax/src/features/settings/presentation/settings_screen.dart';
import 'package:busymax/src/features/sync/sync_auth_error.dart';
import 'package:busymax/src/google_tasks/api/google_tasks_api_surface.dart';
import 'package:busymax/src/core/auth/oauth_models.dart';
import 'package:busymax/src/google_tasks/oauth/oauth_service.dart';
import 'package:busymax/src/core/secrets/secret_store.dart';
import 'package:busymax/src/platform/native_dialog_service.dart';
import 'package:busymax/src/schedule/schedule_scope.dart';
import 'package:busymax/src/providers/busy_provider.dart';

const _nativeDialogChannel = MethodChannel(nativeDialogChannelName);

void main() {
  late AppDatabase database;
  late _FakeOAuthGateway oAuth;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    oAuth = _FakeOAuthGateway();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_nativeDialogChannel, (_) async => null);
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_nativeDialogChannel, null);
    await database.close();
  });

  testWidgets('signed-out app shows sign-in route', (tester) async {
    await _pumpApp(tester, database: database, oAuth: oAuth);

    await tester.pumpAndSettle();

    expect(find.text('Connect accounts'), findsOneWidget);
    expect(
      find.text('Connect calendars and tasks from one of these providers.'),
      findsOneWidget,
    );
    expect(
      find.text(
        'On the Google permission screen, select both Calendar and Tasks permissions.',
      ),
      findsOneWidget,
    );
    expect(find.text('Add Google account'), findsOneWidget);
    expect(find.text('Add Microsoft account'), findsOneWidget);
    expect(find.text('Add Apple iCloud Calendar account'), findsOneWidget);
    expect(find.text('Add Nextcloud account'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Add Google account')).dy,
      lessThan(tester.getTopLeft(find.text('Add Microsoft account')).dy),
    );
    expect(
      tester.getTopLeft(find.text('Add Microsoft account')).dy,
      lessThan(
        tester.getTopLeft(find.text('Add Apple iCloud Calendar account')).dy,
      ),
    );
    expect(
      tester.getTopLeft(find.text('Add Apple iCloud Calendar account')).dy,
      lessThan(tester.getTopLeft(find.text('Add Nextcloud account')).dy),
    );
    expect(find.text('Google'), findsNothing);
    expect(find.text('Microsoft To Do'), findsNothing);
    expect(find.text('Accounts'), findsNothing);
    expect(find.textContaining('sync tasks'), findsNothing);
    expect(find.text('Tasks'), findsNothing);
    await _disposeApp(tester);
  });

  testWidgets('onboarding content and actions share one responsive rail', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1000, 720);
    addTearDown(tester.view.reset);

    await _pumpApp(tester, database: database, oAuth: oAuth);
    await tester.pumpAndSettle();

    void expectAlignedActions({
      required double expectedRailWidth,
      required bool enoughRoomForCenteredHeader,
    }) {
      final rail = tester.getRect(
        find.byKey(const ValueKey('onboarding-content-rail')),
      );
      final back = tester.getRect(
        find.byKey(const ValueKey('onboarding-back-button')),
      );
      final continueButton = tester.getRect(
        find.byKey(const ValueKey('onboarding-continue-button')),
      );

      expect(rail.width, closeTo(expectedRailWidth, 0.01));
      if (enoughRoomForCenteredHeader) {
        expect(back.left, closeTo(rail.left, 0.01));
        expect(continueButton.right, closeTo(rail.right, 0.01));
      } else {
        expect(back.left, lessThanOrEqualTo(rail.left));
        expect(continueButton.right, lessThan(rail.right));
      }
    }

    expectAlignedActions(
      expectedRailWidth: 480,
      enoughRoomForCenteredHeader: true,
    );
    final headerTitle = find.byKey(const ValueKey('onboarding-header-title'));
    final header = find.byType(BusyMaxLinuxHeaderLayout);
    expect(
      tester.getRect(headerTitle).center.dx,
      closeTo(tester.getRect(header).center.dx, .01),
    );
    final headerText = tester.widget<Text>(
      find.descendant(of: headerTitle, matching: find.byType(Text)),
    );
    final bodyStyle = Theme.of(
      tester.element(headerTitle),
    ).textTheme.bodyMedium;
    expect(headerText.style?.fontSize, bodyStyle?.fontSize);
    expect(headerText.style?.fontWeight, FontWeight.bold);
    expect(
      tester
          .getSize(find.byKey(const ValueKey('onboarding-back-button')))
          .height,
      BusyMaxSizes.headerIconButton,
    );
    expect(
      tester
          .getSize(find.byKey(const ValueKey('onboarding-continue-button')))
          .height,
      BusyMaxSizes.headerIconButton,
    );
    final back = tester.widget<FilledButton>(
      find.descendant(
        of: find.byKey(const ValueKey('onboarding-back-button')),
        matching: find.byType(FilledButton),
      ),
    );
    final continueButton = tester.widget<ElevatedButton>(
      find.descendant(
        of: find.byKey(const ValueKey('onboarding-continue-button')),
        matching: find.byType(ElevatedButton),
      ),
    );
    expect(back.onPressed, null);
    expect(continueButton.onPressed, null);

    tester.view.physicalSize = const Size(420, 720);
    await tester.pumpAndSettle();

    expectAlignedActions(
      expectedRailWidth: 380,
      enoughRoomForCenteredHeader: false,
    );
    expect(tester.takeException(), null);
    await _disposeApp(tester);
  });

  testWidgets('system settings cards retain their complete shadow gutter', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1000, 720);
    addTearDown(tester.view.reset);

    await _pumpApp(tester, database: database, oAuth: oAuth);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add Google account'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    final viewport = tester.getRect(
      find.byKey(const ValueKey('onboarding-scroll-viewport')),
    );
    final rail = tester.getRect(
      find.byKey(const ValueKey('onboarding-content-rail')),
    );
    expect(viewport.width, rail.width + BusyMaxSpacing.sm * 2);
    expect(rail.left - viewport.left, BusyMaxSpacing.sm);
    expect(viewport.right - rail.right, BusyMaxSpacing.sm);

    final cards = find.byType(BusyMaxGroupedSurface);
    expect(cards, findsNWidgets(3));
    for (final card in cards.evaluate()) {
      final rect = tester.getRect(find.byWidget(card.widget));
      expect(rect.left, rail.left);
      expect(rect.right, rail.right);
      expect(rect.left, greaterThan(viewport.left));
      expect(rect.right, lessThan(viewport.right));
    }
    expect(tester.takeException(), null);
    await _disposeApp(tester);
  });

  test('setup provider actions use BusyMax row patterns', () {
    final source = File(
      'lib/src/features/auth/presentation/sign_in_screen.dart',
    ).readAsStringSync();
    final start = source.indexOf('class _ProviderSignInButton');
    final end = source.indexOf('class _OnboardingHeader');
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
    expect(find.text('Test User'), findsOneWidget);
    expect(find.text('user@example.com'), findsOneWidget);
    expect(
      tester
          .widget<ElevatedButton>(
            find.descendant(
              of: find.byKey(const ValueKey('onboarding-continue-button')),
              matching: find.byType(ElevatedButton),
            ),
          )
          .onPressed,
      isNot(null),
    );

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(find.text('Choose system settings'), findsOneWidget);
    expect(find.text('Finish setup'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.descendant(
              of: find.byKey(const ValueKey('onboarding-back-button')),
              matching: find.byType(FilledButton),
            ),
          )
          .onPressed,
      isNot(null),
    );
    expect(find.text('Notification detail level'), findsOneWidget);
    expect(find.text('Detailed notification text'), findsNothing);

    await tester.tap(find.text('Finish setup'));
    await tester.pumpAndSettle();

    expect(find.byType(ScheduleWorkspace), findsOneWidget);
    expect(find.byTooltip('Today (Shift+T)'), findsOneWidget);
    await _disposeApp(tester);
  });

  testWidgets('Alt+Left follows onboarding Back availability', (tester) async {
    await _pumpApp(tester, database: database, oAuth: oAuth);
    await tester.pumpAndSettle();

    await _sendAltLeft(tester);
    expect(find.text('Connect accounts'), findsOneWidget);

    await tester.tap(find.text('Add Google account'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Choose system settings'), findsOneWidget);

    await _sendAltLeft(tester);
    expect(find.text('Connect accounts'), findsOneWidget);
    expect(find.text('Choose system settings'), findsNothing);
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

    expect(find.text(secretStorageUnavailableMessage), findsOneWidget);
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

  testWidgets('Settings enters and exits without a page transition', (
    tester,
  ) async {
    await _insertAccount(
      database,
      id: 'google:existing',
      provider: BusyProvider.google,
    );
    await _pumpApp(tester, database: database, oAuth: oAuth);
    await tester.pumpAndSettle();

    final router = GoRouter.of(tester.element(find.byType(ScheduleWorkspace)));
    unawaited(router.push<void>('/settings'));
    await tester.pump();

    final settings = find.byType(SettingsScreen);
    expect(settings, findsOneWidget);
    final settingsRoute = ModalRoute.of(tester.element(settings))!;
    expect(settingsRoute.transitionDuration, Duration.zero);
    expect(settingsRoute.reverseTransitionDuration, Duration.zero);

    router.pop();
    await tester.pump();

    expect(settings, findsNothing);
    expect(find.byType(ScheduleWorkspace), findsOneWidget);
    await _disposeApp(tester);
  });

  testWidgets('auth refresh preserves router, navigator, and Settings URI', (
    tester,
  ) async {
    await _insertAccount(
      database,
      id: 'google:existing',
      provider: BusyProvider.google,
    );
    await _pumpApp(tester, database: database, oAuth: oAuth);
    await tester.pumpAndSettle();
    await _openSettings(tester);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(SettingsScreen)),
    );
    final router = container.read(appRouterProvider);
    final navigator = rootNavigatorKey.currentState;

    await container.read(authSessionControllerProvider.notifier).load();
    await tester.pumpAndSettle();

    expect(container.read(appRouterProvider), same(router));
    expect(rootNavigatorKey.currentState, same(navigator));
    expect(router.routeInformationProvider.value.uri.path, '/settings');
    expect(
      router.routeInformationProvider.value.uri.queryParameters['page'],
      'accounts',
    );
    expect(find.byType(SettingsScreen), findsOneWidget);
    expect(find.byType(ScheduleWorkspace), findsNothing);
    await _disposeApp(tester);
  });

  testWidgets('provider teardown disposes its GoRouter', (tester) async {
    await _insertAccount(
      database,
      id: 'google:existing',
      provider: BusyProvider.google,
    );
    await _pumpApp(tester, database: database, oAuth: oAuth);
    await tester.pumpAndSettle();

    final context = tester.element(find.byType(ScheduleWorkspace));
    final container = ProviderScope.containerOf(context);
    final router = container.read(appRouterProvider);
    final routeInformationProvider = router.routeInformationProvider;

    await _disposeApp(tester);

    expect(
      () => routeInformationProvider.addListener(() {}),
      throwsFlutterError,
    );
  });

  testWidgets('WebCal refresh preserves router and Settings URI', (
    tester,
  ) async {
    await _insertAccount(
      database,
      id: 'google:existing',
      provider: BusyProvider.google,
    );
    await _pumpApp(tester, database: database, oAuth: oAuth);
    await tester.pumpAndSettle();
    await _openSettings(tester);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(SettingsScreen)),
    );
    final router = container.read(appRouterProvider);
    final navigator = rootNavigatorKey.currentState;

    container.invalidate(webCalSubscriptionsProvider);
    await tester.pumpAndSettle();

    expect(container.read(appRouterProvider), same(router));
    expect(rootNavigatorKey.currentState, same(navigator));
    expect(router.routeInformationProvider.value.uri.path, '/settings');
    expect(find.byType(SettingsScreen), findsOneWidget);
    expect(find.byType(ScheduleWorkspace), findsNothing);
    await _disposeApp(tester);
  });

  testWidgets('removing one of two accounts keeps real Settings route', (
    tester,
  ) async {
    await _insertAccount(
      database,
      id: 'google:remove',
      provider: BusyProvider.google,
    );
    await _insertAccount(
      database,
      id: 'microsoft:remain',
      provider: BusyProvider.microsoft,
    );
    await _pumpApp(tester, database: database, oAuth: oAuth);
    await tester.pumpAndSettle();
    await _openSettings(tester);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(SettingsScreen)),
    );
    final router = container.read(appRouterProvider);

    await tester.tap(find.text('Remove account…').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm-account-removal')));
    await tester.pumpAndSettle();

    final accounts = await database.select(database.accounts).get();
    expect(accounts.map((account) => account.id), ['microsoft:remain']);
    expect(container.read(selectedAccountIdProvider), 'microsoft:remain');
    expect(container.read(appRouterProvider), same(router));
    expect(router.routeInformationProvider.value.uri.path, '/settings');
    expect(find.byType(SettingsScreen), findsOneWidget);
    expect(find.byType(ScheduleWorkspace), findsNothing);
    await _disposeApp(tester);
  });

  testWidgets(
    'removing an account from pushed Settings preserves return history',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1200, 850);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      await _insertAccount(
        database,
        id: 'google:remove',
        provider: BusyProvider.google,
      );
      await _insertAccount(
        database,
        id: 'microsoft:remain',
        provider: BusyProvider.microsoft,
      );
      await _pumpApp(tester, database: database, oAuth: oAuth);
      await tester.pumpAndSettle();

      final workspaceFinder = find.byType(
        ScheduleWorkspace,
        skipOffstage: false,
      );
      final workspaceState = tester.state(workspaceFinder);
      final workspaceRoute = ModalRoute.of(workspaceState.context)!;
      final container = ProviderScope.containerOf(workspaceState.context);
      final router = container.read(appRouterProvider);
      final navigator = rootNavigatorKey.currentState;
      expect(workspaceRoute.isCurrent, isTrue);

      unawaited(router.push<void>('/settings'));
      await tester.pumpAndSettle();
      expect(workspaceFinder, findsOneWidget);
      expect(find.byType(ScheduleWorkspace), findsNothing);
      expect(workspaceRoute.isCurrent, isFalse);
      await tester.tap(
        find.byKey(const ValueKey('settings-navigation-accounts')),
      );
      await tester.pumpAndSettle();

      final settingsFinder = find.byType(SettingsScreen);
      final settingsState = tester.state(settingsFinder);
      final settingsUri = GoRouterState.of(tester.element(settingsFinder)).uri;
      expect(settingsUri.path, '/settings');
      expect(settingsUri.queryParameters['page'], 'accounts');

      await tester.tap(find.text('Remove account…').first);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('confirm-account-removal')));
      await tester.pumpAndSettle();

      final accounts = await database.select(database.accounts).get();
      expect(accounts.map((account) => account.id), ['microsoft:remain']);
      expect(container.read(selectedAccountIdProvider), 'microsoft:remain');
      expect(container.read(appRouterProvider), same(router));
      expect(rootNavigatorKey.currentState, same(navigator));
      expect(tester.state(settingsFinder), same(settingsState));
      final retainedSettingsUri = GoRouterState.of(
        tester.element(settingsFinder),
      ).uri;
      expect(retainedSettingsUri.path, '/settings');
      expect(retainedSettingsUri.queryParameters['page'], 'accounts');
      expect(workspaceFinder, findsOneWidget);
      expect(find.byType(ScheduleWorkspace), findsNothing);
      expect(workspaceRoute.isCurrent, isFalse);
      expect(router.canPop(), isTrue);

      await _sendAltLeft(tester);

      expect(settingsFinder, findsNothing);
      expect(workspaceFinder, findsOneWidget);
      expect(tester.state(workspaceFinder), same(workspaceState));
      expect(workspaceRoute.isCurrent, isTrue);
      expect(router.routeInformationProvider.value.uri.path, '/schedule');
      expect(router.canPop(), isFalse);
      await _disposeApp(tester);
    },
  );

  testWidgets(
    'adding an account keeps Settings open during and after cancellation',
    (tester) async {
      await _insertAccount(
        database,
        id: 'google:existing',
        provider: BusyProvider.google,
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
        provider: BusyProvider.microsoft,
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
        provider: BusyProvider.microsoft,
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
        provider: BusyProvider.microsoft,
      );
      await _insertAccount(
        database,
        id: 'google:reconnect',
        provider: BusyProvider.google,
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

Future<void> _sendAltLeft(WidgetTester tester) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
  await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowLeft);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowLeft);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
  await tester.pumpAndSettle();
}

Future<void> _disposeApp(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(milliseconds: 1));
}

Future<void> _openSettings(WidgetTester tester) async {
  final schedule = find.byType(ScheduleWorkspace);
  expect(schedule, findsOneWidget);
  GoRouter.of(tester.element(schedule)).go('/settings?page=accounts');
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
  required BusyProvider provider,
  String authState = accountAuthStateSignedIn,
}) {
  return database
      .into(database.accounts)
      .insert(
        AccountsCompanion.insert(
          id: id,
          provider: provider.storageValue,
          authority: provider == BusyProvider.microsoft
              ? 'https://login.microsoftonline.com/common'
              : 'https://accounts.google.com',
          providerAccountId: id,
          credentialKind: 'oauth',
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
      name: 'Test User',
      email: 'user@example.com',
      rawJson: {
        'sub': 'google-user-1',
        'name': 'Test User',
        'email': 'user@example.com',
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

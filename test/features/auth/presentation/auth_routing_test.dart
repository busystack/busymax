import '../../../support/desktop_connection_fixture.dart';
import 'package:busymax/src/dav/auth/dav_account_onboarding_service.dart';
import 'package:busymax/src/dav/auth/nextcloud_login_flow_v2.dart';
import 'package:busymax/src/dav/discovery/dav_discovery_models.dart';
import 'package:busymax/src/providers/provider_capabilities.dart';
import 'package:busymax/src/microsoft_todo/oauth/microsoft_oauth_service.dart';
import 'package:busymax/src/microsoft_todo/api/microsoft_todo_api_models.dart';
import 'package:busymax/src/platform/common/desktop_services.dart';
import '../../../support/desktop_activation_fixture.dart';
import '../../../support/memory_settings_store.dart';
import 'package:busymax/src/platform/busymax_tray_service.dart';
import 'package:busymax/src/webcal/webcal_http_client.dart';
import 'package:busymax/src/webcal/webcal_subscription_service.dart';
import 'package:busymax/src/core/auth/authorization_attempt.dart';
import 'package:busymax/src/core/auth/registration_file_reader.dart';
import '../../../support/native_registration_reader_fixture.dart';
import 'dart:convert';
import 'package:busymax/src/core/auth/authorization_persistence.dart';
import 'package:busymax/src/core/auth/oauth_registration.dart';
import 'package:busymax/src/core/auth/registration_staging.dart';
import 'package:busymax/src/google_tasks/oauth/oauth_loopback_flow.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'dart:async';
import 'dart:io';
import 'package:busymax/src/features/connectivity/network_connectivity_service.dart';
import 'package:file_selector_platform_interface/file_selector_platform_interface.dart';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:busymax/src/app/app_bootstrap.dart';
import 'package:busymax/src/app/app_router.dart';
import 'package:busymax/src/app/busymax_app.dart';
import 'package:busymax/src/config/build_config.dart';
import 'package:busymax/src/db/app_database.dart' hide AuthorizationCommit;
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
late RegistrationFileReader _nativeReader;

void main() {
  late AppDatabase database;
  late _FakeOAuthGateway oAuth;
  setUpAll(() async {
    _nativeReader = await buildNativeRegistrationReader();
  });

  setUp(() async {
    for (final name in [
      'io.busystack.busymax/gtk_theme_colors',
      'io.busystack.busymax/gtk_font_settings',
      'yaru_window',
      'yaru_window/events',
    ]) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            MethodChannel(name),
            (_) async => name == 'yaru_window' ? <String, Object?>{} : null,
          );
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(MethodChannel(name), null),
      );
    }
    final previousSelector = FileSelectorPlatform.instance;
    final directory = await Directory.systemTemp.createTemp(
      'busymax-widget-registration-',
    );
    final selected = File('${directory.path}/desktop.json');
    await selected.writeAsString(
      '{"installed":{"client_id":"fixture.apps.googleusercontent.com","project_id":"fixture-project"}}',
    );
    FileSelectorPlatform.instance = _RegistrationFileSelector(selected.path);
    addTearDown(() async {
      FileSelectorPlatform.instance = previousSelector;
      await directory.delete(recursive: true);
    });
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

  for (final choice in [
    (BusyProvider.google, DesktopConnectionMethod.busyMax),
    (BusyProvider.google, DesktopConnectionMethod.googleWorkspace),
    (BusyProvider.google, DesktopConnectionMethod.custom),
    (BusyProvider.microsoft, DesktopConnectionMethod.busyMax),
    (BusyProvider.microsoft, DesktopConnectionMethod.custom),
  ]) {
    testWidgets('Settings connects ${choice.$1} through ${choice.$2}', (
      tester,
    ) async {
      final (provider, method) = choice;
      final fixture = DesktopConnectionFixture(database, _nativeReader);
      addTearDown(fixture.staging.dispose);
      await _pumpApp(
        tester,
        database: database,
        oAuth: fixture.google,
        microsoftOAuth: fixture.microsoft,
        secrets: fixture.secrets,
        persistence: fixture.persistence,
        staging: fixture.staging,
      );
      for (
        var i = 0;
        i < 20 && find.byType(ScheduleWorkspace).evaluate().isEmpty;
        i++
      ) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await tester.pumpAndSettle();
      }
      await _openSettings(tester);
      await tester.ensureVisible(
        find.text('Add ${provider.displayName} account'),
      );
      await tester.tap(find.text('Add ${provider.displayName} account'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('registration-authorize')),
        findsNothing,
      );
      if (method == DesktopConnectionMethod.busyMax) {
        await tester.tap(find.byKey(const ValueKey('registration-busymax')));
      } else {
        await tester.tap(
          find.byKey(
            ValueKey(
              'registration-${method == DesktopConnectionMethod.googleWorkspace ? 'workspace' : 'custom'}',
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('registration-guide')));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('registration-authorize')),
          findsNothing,
        );
        await _sendAltLeft(tester);
        expect(find.byType(SettingsScreen), findsOneWidget);
        if (provider == BusyProvider.google) {
          await tester.runAsync(() async {
            await (tester
                    .widget<FilledButton>(
                      find.byKey(const ValueKey('registration-import')),
                    )
                    .onPressed
                as dynamic)();
          });
        } else {
          await tester.enterText(
            find.byKey(const ValueKey('registration-client-id')),
            '33333333-3333-3333-3333-333333333333',
          );
        }
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('registration-authorize')));
      }
      final id = '${provider.storageValue}:fixture-user';
      for (var i = 0; i < 40; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await tester.pumpAndSettle();
        if (await tester.runAsync(() => fixture.secrets.readCredential(id)) !=
            null) {
          break;
        }
      }
      final record =
          await tester.runAsync(() => fixture.secrets.readCredential(id))
              as BoundOAuthSecretRecord;
      expect(
        record.registration.summary().origin,
        method == DesktopConnectionMethod.busyMax
            ? RegistrationOrigin.busyMaxManaged
            : RegistrationOrigin.userProvided,
      );
      expect(fixture.flow.clients.single, record.registration.clientId);
      expect(
        find.byKey(const ValueKey('registration-methods-dialog')),
        findsNothing,
      );
      expect(find.byType(SettingsScreen), findsOneWidget);
      if (method == DesktopConnectionMethod.custom) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Connect'));
        await tester.tap(find.text('Connect'));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('registration-methods-dialog')),
          findsNothing,
        );
        for (var i = 0; i < 40; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 10)),
          );
          await tester.pumpAndSettle();
          if (await tester.runAsync(() => fixture.persistence.generation(id)) ==
              2) {
            break;
          }
        }
        expect(fixture.flow.clients, [
          record.registration.clientId,
          record.registration.clientId,
        ]);
        await tester.ensureVisible(find.text('Replace registration'));
        await tester.tap(find.text('Replace registration'));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('registration-methods-dialog')),
          findsOneWidget,
        );
        await tester.tap(find.byKey(const ValueKey('registration-close')));
        await tester.pumpAndSettle();
        expect(fixture.flow.clients, hasLength(2));
        expect(
          await tester.runAsync(() => fixture.persistence.generation(id)),
          2,
        );
        await tester.tap(find.text('Replace registration'));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('registration-busymax')));
        for (var i = 0; i < 40; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 10)),
          );
          await tester.pumpAndSettle();
          if (await tester.runAsync(() => fixture.persistence.generation(id)) ==
              3) {
            break;
          }
        }
        final replaced =
            await tester.runAsync(() => fixture.secrets.readCredential(id))
                as BoundOAuthSecretRecord;
        expect(replaced.generation, 3);
        expect(replaced.subject, record.subject);
        expect(
          replaced.registration.summary().origin,
          RegistrationOrigin.busyMaxManaged,
        );
        expect(fixture.flow.clients.last, replaced.registration.clientId);
        expect(
          await tester.runAsync(
            () => (database.select(database.accounts)).get(),
          ),
          hasLength(1),
        );
        expect(find.byType(SettingsScreen), findsOneWidget);
      }
      await _disposeApp(tester);
    });
  }

  testWidgets(
    'retirement is account-specific; cancelled migration retries and survives restart',
    (tester) async {
      final secrets = InMemorySecretStore();
      final persistence = AuthorizationPersistence(
        database: database,
        secrets: secrets,
      );
      final staging = RegistrationStaging(
        _configuredBuildConfig,
        fileReader: _nativeReader,
      );
      addTearDown(staging.dispose);
      final flow = _MigrationBrowserFlow();
      final google = OAuthService(
        config: _configuredBuildConfig,
        tokenStore: secrets,
        registrations: staging,
        persistence: persistence,
        loopbackFlow: flow,
        httpClient: MockClient(
          (request) async => http.Response(
            jsonEncode(
              request.method == 'GET'
                  ? {
                      'sub': 'google:existing',
                      'email': 'fixture@example.invalid',
                    }
                  : {
                      'access_token': 'synthetic-access',
                      'refresh_token': 'synthetic-refresh',
                      'expires_in': 3600,
                      'scope': googleBusyMaxOAuthScope,
                    },
            ),
            200,
          ),
        ),
      );
      await _insertAccount(
        database,
        id: 'google:existing',
        provider: BusyProvider.google,
      );
      await _insertAccount(
        database,
        id: 'microsoft:existing',
        provider: BusyProvider.microsoft,
      );
      final records = <String, SecretRecord>{
        'google:existing': GoogleDesktopCredential(
          registration: const GoogleDesktopRegistration(
            clientId: 'shared.apps.googleusercontent.com',
            projectId: 'fixture-shared',
            origin: RegistrationOrigin.retiringShared,
          ),
          tokenSet: _tokenSet(),
          subject: 'google:existing',
          generation: 1,
          transitionEligible: true,
        ),
        'microsoft:existing': MicrosoftDesktopCredential(
          registration: MicrosoftPublicRegistration(
            clientId: '22222222-2222-2222-2222-222222222222',
            audience: MicrosoftAudience.personalAndOrganizations,
            origin: RegistrationOrigin.retiringShared,
          ),
          tokenSet: _tokenSet(),
          subject: 'microsoft:existing',
          tenantId: '11111111-1111-1111-1111-111111111111',
          generation: 1,
          transitionEligible: true,
        ),
      };
      await tester.runAsync(() async {
        for (final entry in records.entries) {
          await secrets.saveCredential(entry.key, entry.value);
          await database
              .into(database.oAuthTransitionAccounts)
              .insert(
                OAuthTransitionAccountsCompanion.insert(accountId: entry.key),
              );
          await database
              .into(database.authorizationGenerations)
              .insert(
                AuthorizationGenerationsCompanion.insert(
                  accountId: entry.key,
                  generation: 1,
                ),
              );
          await database
              .into(database.accountAuthorizations)
              .insert(
                AccountAuthorizationsCompanion.insert(
                  accountId: entry.key,
                  generation: 1,
                  summaryJson: '{}',
                ),
              );
        }
      });
      await _pumpApp(
        tester,
        database: database,
        oAuth: google,
        secrets: secrets,
        persistence: persistence,
        staging: staging,
      );
      await tester.pumpAndSettle();
      await _openSettings(tester);
      expect(find.text('Migrate now'), findsNWidgets(2));
      await tester.ensureVisible(find.text('Migrate now').first);
      await tester.tap(find.text('Migrate now').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel').last);
      await tester.pumpAndSettle();
      expect(find.text('Migrate now'), findsNWidgets(2));
      expect(flow.clients, isEmpty);
      await tester.tap(find.text('Migrate now').first);
      await tester.pumpAndSettle();
      await _validateAndAuthorizeGoogleSetup(tester);
      await tester.pumpAndSettle();
      expect(flow.clients, ['fixture.apps.googleusercontent.com']);
      for (var attempt = 0; attempt < 30; attempt++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await tester.pump();
        if (await tester.runAsync(
              () => persistence.generation('google:existing'),
            ) ==
            2) {
          break;
        }
      }
      await tester.pumpAndSettle();
      expect(find.text('Migrate now'), findsOneWidget);
      expect(
        (await tester.runAsync(() => secrets.readCredential('google:existing')))
            as GoogleDesktopCredential,
        isA<GoogleDesktopCredential>().having(
          (r) => r.registration.origin,
          'origin',
          RegistrationOrigin.userProvided,
        ),
      );
      expect(
        await tester.runAsync(
          () => secrets.readCredential('google:google:existing'),
        ),
        isNull,
      );
      await _disposeApp(tester);
      await _pumpApp(
        tester,
        database: database,
        oAuth: google,
        secrets: secrets,
        persistence: persistence,
        staging: staging,
      );
      await tester.pumpAndSettle();
      await _openSettings(tester);
      expect(find.text('Migrate now'), findsOneWidget);
      expect(find.textContaining('User-provided registration'), findsOneWidget);
      await _disposeApp(tester);
    },
  );

  for (final provider in [
    BusyProvider.microsoft,
    BusyProvider.appleICloud,
    BusyProvider.nextcloud,
  ]) {
    for (final existing in [false, true]) {
      testWidgets(
        'Settings reconciles persisted $provider connection with existing=$existing before sync completes',
        (tester) async {
          if (existing) {
            await _insertAccount(
              database,
              id: 'google:existing',
              provider: BusyProvider.google,
            );
          }
          final secrets = InMemorySecretStore();
          final dav = _controlledDavService(database, secrets);
          final syncing = Completer<void>();
          final calls = <({String accountId, bool initial})>[];
          await _pumpApp(
            tester,
            database: database,
            oAuth: oAuth,
            secrets: secrets,
            davService: dav,
            microsoftOAuth: _ControlledMicrosoftGateway(),
            onSignedIn: (accountId, initial) async {
              calls.add((accountId: accountId, initial: initial));
              if (initial) await syncing.future;
            },
          );
          await tester.pumpAndSettle();
          calls.clear();
          await _openSettings(tester);
          await _connectControlledProvider(tester, provider);
          for (
            var attempt = 0;
            attempt < 40 && !calls.any((call) => call.initial);
            attempt++
          ) {
            await tester.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 5)),
            );
            await tester.pump(const Duration(milliseconds: 100));
          }
          await tester.pumpAndSettle();
          final rows = (await tester.runAsync(
            () => database.select(database.accounts).get(),
          ))!;
          expect(
            rows,
            hasLength(existing ? 2 : 1),
            reason: tester
                .widgetList<Text>(find.byType(Text))
                .map((text) => text.data)
                .join(' | '),
          );
          final connected = rows.singleWhere(
            (row) => row.id != 'google:existing',
          );
          expect(connected.authState, accountAuthStateSignedIn);
          final container = ProviderScope.containerOf(
            tester.element(find.byType(SettingsScreen)),
          );
          _expectExistingSessionSignedIn(
            container.read(authSessionControllerProvider),
            existing ? 'google:existing' : connected.id,
          );
          expect(calls, [(accountId: connected.id, initial: true)]);
          expect(syncing.isCompleted, isFalse);
          expect(find.byType(SettingsScreen), findsOneWidget);
          syncing.complete();
          await tester.pumpAndSettle();
          await _disposeApp(tester);
        },
      );
    }
  }

  for (final cancelled in [true, false]) {
    testWidgets(
      'unsuccessful first connection preserves session with cancelled=$cancelled',
      (tester) async {
        oAuth.signInError = OAuthException(
          cancelled ? 'OAuthSignInCancelled' : 'OAuthTokenExchangeFailed',
          'Controlled unsuccessful connection',
        );
        final calls = <({String accountId, bool initial})>[];
        await _pumpApp(
          tester,
          database: database,
          oAuth: oAuth,
          onSignedIn: (accountId, initial) async =>
              calls.add((accountId: accountId, initial: initial)),
        );
        await tester.pumpAndSettle();
        final container = ProviderScope.containerOf(
          tester.element(find.byType(ScheduleWorkspace)),
        );
        final original = container.read(authSessionControllerProvider);
        await _authorizeGoogleSetup(tester);
        await tester.pumpAndSettle();
        expect(container.read(authSessionControllerProvider), same(original));
        expect(original.isSignedIn, isFalse);
        expect(
          (await tester.runAsync(
            () => database.select(database.accounts).get(),
          ))!,
          isEmpty,
        );
        expect(calls, isEmpty);
        expect(find.byType(SettingsScreen), findsOneWidget);
        await _sendAltLeft(tester);
        expect(find.byType(ScheduleWorkspace), findsOneWidget);
        expect(find.text('Add account'), findsOneWidget);
        await _disposeApp(tester);
      },
    );
  }
  testWidgets(
    'successful Settings reconnection syncs only that account and preserves session',
    (tester) async {
      await _insertAccount(
        database,
        id: 'microsoft:existing',
        provider: BusyProvider.microsoft,
      );
      await _insertAccount(
        database,
        id: 'account-1',
        provider: BusyProvider.google,
        authState: accountAuthStateReauthRequired,
      );
      final calls = <({String accountId, bool initial})>[];
      await _pumpApp(
        tester,
        database: database,
        oAuth: oAuth,
        onSignedIn: (accountId, initial) async =>
            calls.add((accountId: accountId, initial: initial)),
      );
      await tester.pumpAndSettle();
      await _openSettings(tester);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(SettingsScreen)),
      );
      final original = container.read(authSessionControllerProvider);
      calls.clear();
      await tester.tap(find.text(accountReconnectRequiredActionLabel));
      await tester.pumpAndSettle();
      final rows = (await tester.runAsync(
        () => database.select(database.accounts).get(),
      ))!;
      expect(
        rows.singleWhere((row) => row.id == 'account-1').authState,
        accountAuthStateSignedIn,
      );
      expect(container.read(authSessionControllerProvider), same(original));
      expect(original.accountId, 'microsoft:existing');
      expect(calls, [(accountId: 'account-1', initial: true)]);
      expect(find.byType(SettingsScreen), findsOneWidget);
      await _disposeApp(tester);
    },
  );

  testWidgets('first Settings connection updates session before ICS activation', (
    tester,
  ) async {
    final activations = TestDesktopActivationService();
    addTearDown(activations.dispose);
    late Directory directory;
    await tester.runAsync(() async {
      directory = await Directory.systemTemp.createTemp(
        'busymax-session-activation-',
      );
    });
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/fixture.ics');
    await tester.runAsync(
      () => file.writeAsString(
        'BEGIN:VCALENDAR\r\nVERSION:2.0\r\nPRODID:-//BusyMax Fixture//EN\r\nBEGIN:VEVENT\r\nUID:fixture-activation\r\nDTSTAMP:20261004T000000Z\r\nDTSTART:20301004T090000Z\r\nDTEND:20301004T100000Z\r\nSUMMARY:Controlled activation\r\nEND:VEVENT\r\nEND:VCALENDAR\r\n',
      ),
    );
    await _pumpApp(
      tester,
      database: database,
      oAuth: oAuth,
      activations: activations,
      settings: AppSettings.defaults().copyWith(
        firstDayOfWeekPreference: BusyMaxFirstDayOfWeekPreference.monday,
        showTrayIcon: false,
        runInBackgroundWhenClosed: false,
      ),
    );
    await tester.pumpAndSettle();
    await _authorizeGoogleSetup(tester);
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(SettingsScreen)),
    );
    _expectExistingSessionSignedIn(
      container.read(authSessionControllerProvider),
      'account-1',
    );
    activations.add(
      DesktopActivation(kind: DesktopActivationKind.icsFile, value: file.path),
    );
    for (
      var attempt = 0;
      attempt < 30 &&
          container.read(appRouterProvider).state.uri.path != '/schedule';
      attempt++
    ) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump(const Duration(milliseconds: 20));
    }
    expect(container.read(appRouterProvider).state.uri.path, '/schedule');
    expect(find.byType(SettingsScreen), findsNothing);
    await tester.pumpAndSettle();
    await _disposeApp(tester);
  });

  testWidgets('signed-out startup opens calendar and Accounts from sidebar', (
    tester,
  ) async {
    await _pumpApp(tester, database: database, oAuth: oAuth);
    await tester.pumpAndSettle();
    expect(find.byType(ScheduleWorkspace), findsOneWidget);
    expect(find.text('Add account'), findsOneWidget);
    final workspace = tester.state(find.byType(ScheduleWorkspace));
    final router = GoRouter.of(workspace.context);
    expect(router.routeInformationProvider.value.uri.path, '/schedule');
    await tester.tap(find.byKey(const ValueKey('schedule-add-account')));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsScreen), findsOneWidget);
    expect(router.canPop(), isTrue);
    expect(
      GoRouterState.of(
        tester.element(find.byType(SettingsScreen)),
      ).uri.queryParameters['page'],
      'accounts',
    );
    for (final label in [
      'Add Google account',
      'Add Microsoft account',
      'Add Apple iCloud Calendar account',
      'Add Nextcloud account',
      'Add calendar subscription',
    ]) {
      expect(find.text(label), findsOneWidget);
    }
    expect(
      find.text(
        'On the Google permission screen, select both Calendar and Tasks permissions.',
      ),
      findsOneWidget,
    );
    await _sendAltLeft(tester);
    expect(tester.state(find.byType(ScheduleWorkspace)), same(workspace));
    expect(find.text('Add account'), findsOneWidget);
    await _disposeApp(tester);
  });

  testWidgets('subscription-only workspace and final unsubscribe stay usable', (
    tester,
  ) async {
    final subscriptions = WebCalSubscriptionService(
      database: database,
      secretStore: InMemorySecretStore(),
      httpTransport: _FixtureCalendarTransport(),
    );
    await tester.runAsync(
      () => subscriptions.addSubscription(
        subscriptionUrl: 'https://calendar.example.test/feed.ics',
        localName: 'Subscribed calendar',
      ),
    );
    await _pumpApp(
      tester,
      database: database,
      oAuth: oAuth,
      subscriptionService: subscriptions,
    );
    await tester.pumpAndSettle();
    expect(find.byType(ScheduleWorkspace), findsOneWidget);
    expect(find.text('Add account'), findsOneWidget);
    expect(find.text('Subscriptions'), findsOneWidget);
    expect(find.textContaining('Subscribed calendar'), findsOneWidget);
    expect(oAuth.signInCalls, 0);
    await tester.tap(find.text('Add account'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Unsubscribe'));
    await tester.tap(find.text('Unsubscribe'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Unsubscribe').last);
    await tester.pumpAndSettle();
    expect(find.byType(SettingsScreen), findsOneWidget);
    expect(
      (await tester.runAsync(() => database.select(database.accounts).get()))!,
      isEmpty,
    );
    await _sendAltLeft(tester);
    expect(find.byType(ScheduleWorkspace), findsOneWidget);
    expect(find.text('Add account'), findsOneWidget);
    expect(find.byKey(const ValueKey('schedule-week-planner')), findsOneWidget);
    await _disposeApp(tester);
  });

  testWidgets('account-free task routes preserve workspace identity', (
    tester,
  ) async {
    await _pumpApp(tester, database: database, oAuth: oAuth);
    await tester.pumpAndSettle();
    final router = GoRouter.of(tester.element(find.byType(ScheduleWorkspace)));
    router.go('/tasks');
    await tester.pumpAndSettle();
    final taskState = tester.state(find.byType(ScheduleWorkspace));
    router.go('/tasks/missing/list/task');
    await tester.pumpAndSettle();
    expect(tester.state(find.byType(ScheduleWorkspace)), same(taskState));
    expect(
      router.routeInformationProvider.value.uri.path,
      '/tasks/missing/list/task',
    );
    await _disposeApp(tester);
  });

  test('Settings provider actions use BusyMax row patterns', () {
    final source = File(
      'lib/src/features/settings/presentation/settings_screen.dart',
    ).readAsStringSync();
    final section = source.substring(
      source.indexOf('class _AccountManagementSection'),
      source.indexOf('class _AccountSettingsGroup'),
    );
    expect(section, contains('BusyMaxGroupedList'));
    expect(section, contains('BusyMaxActionRow'));
    expect(section, contains('l10n.googlePermissionsConsentNotice'));
  });

  testWidgets('missing Google permissions shows retry guidance', (
    tester,
  ) async {
    oAuth.nextTokenSet = _tokenSet(scopes: {googleTasksReadWriteScope});
    await _pumpApp(tester, database: database, oAuth: oAuth);
    await tester.pumpAndSettle();

    await _authorizeGoogleSetup(tester);
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Google Calendar and Google Tasks permissions are required. Please try again and select both checkboxes.',
      ),
      findsOneWidget,
    );
    expect(
      (await tester.runAsync(() => database.select(database.accounts).get()))!,
      isEmpty,
    );
    await _disposeApp(tester);
  });

  testWidgets('successful connection stays in Settings until normal Back', (
    tester,
  ) async {
    await _pumpApp(tester, database: database, oAuth: oAuth);
    await tester.pumpAndSettle();
    await _authorizeGoogleSetup(tester);
    await tester.pumpAndSettle();
    final account = (await tester.runAsync(
      () => database.select(database.accounts).getSingle(),
    ))!;
    expect(account.authState, 'signed_in');
    expect(account.grantedScopes, googleBusyMaxOAuthScopes.join(' '));
    final container = ProviderScope.containerOf(
      tester.element(find.byType(SettingsScreen)),
    );
    _expectExistingSessionSignedIn(
      container.read(authSessionControllerProvider),
      account.id,
    );
    expect(find.byType(SettingsScreen), findsOneWidget);
    expect(find.byType(ScheduleWorkspace), findsNothing);
    expect(find.textContaining('user@example.com'), findsOneWidget);
    await _sendAltLeft(tester);
    expect(find.byType(ScheduleWorkspace), findsOneWidget);
    expect(find.text('Add account'), findsNothing);
    await _disposeApp(tester);
  });

  testWidgets(
    'final-account removal keeps Settings and returns to empty calendar',
    (tester) async {
      await _insertAccount(
        database,
        id: 'google:last',
        provider: BusyProvider.google,
      );
      await _pumpApp(tester, database: database, oAuth: oAuth);
      await tester.pumpAndSettle();
      final workspace = tester.state(find.byType(ScheduleWorkspace));
      unawaited(
        GoRouter.of(workspace.context).push<void>('/settings?page=accounts'),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Remove account…'));
      await tester.tap(find.text('Remove account…'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('confirm-account-removal')));
      await tester.pumpAndSettle();
      expect(find.byType(SettingsScreen), findsOneWidget);
      await _sendAltLeft(tester);
      expect(tester.state(find.byType(ScheduleWorkspace)), same(workspace));
      expect(find.text('Add account'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('schedule-week-planner')),
        findsOneWidget,
      );
      await _disposeApp(tester);
    },
  );

  testWidgets('Alt+Left returns from Accounts without connecting', (
    tester,
  ) async {
    await _pumpApp(tester, database: database, oAuth: oAuth);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add account'));
    await tester.pumpAndSettle();
    await _sendAltLeft(tester);
    expect(find.byType(ScheduleWorkspace), findsOneWidget);
    expect(find.text('Add account'), findsOneWidget);
    await _disposeApp(tester);
  });

  testWidgets('Tasks navigation stays on schedule calendar surface', (
    tester,
  ) async {
    await _pumpApp(tester, database: database, oAuth: oAuth);
    await tester.pumpAndSettle();

    await _connectGoogleThroughSettings(tester);

    expect(find.byType(ScheduleWorkspace), findsOneWidget);

    GoRouter.of(tester.element(find.byType(ScheduleWorkspace))).go('/tasks');
    await tester.pumpAndSettle();

    expect(find.byType(ScheduleWorkspace), findsOneWidget);

    final accountId = ((await tester.runAsync(
      () => database.select(database.accounts).getSingle(),
    ))!).id;
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

    await _authorizeGoogleSetup(tester);
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Authorization timed out. Try again; select a fresh configuration if it was imported.',
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

    await _authorizeGoogleSetup(tester);
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

    await _authorizeGoogleSetup(tester);
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
    expect(find.byType(SettingsScreen), findsOneWidget);
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

    final accounts = (await tester.runAsync(
      () => database.select(database.accounts).get(),
    ))!;
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

      final accounts = (await tester.runAsync(
        () => database.select(database.accounts).get(),
      ))!;
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

      await _authorizeGoogleSetup(tester);
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
        (await tester.runAsync(
          () => database.select(database.accounts).getSingle(),
        ))!.authState,
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

      await _authorizeGoogleSetup(tester);
      await tester.pumpAndSettle();

      expect(oAuth.signInCalls, 1);
      expect(syncCalls, [(accountId: 'account-1', initial: true)]);
      _expectExistingSessionSignedIn(
        container.read(authSessionControllerProvider),
        'microsoft:existing',
      );
      expect(find.byType(SettingsScreen), findsOneWidget);
      expect(find.text('Connect accounts'), findsNothing);
      final accounts = (await tester.runAsync(
        () => database.select(database.accounts).get(),
      ))!;
      expect(
        accounts
            .where((account) => account.authState == accountAuthStateSignedIn)
            .map((account) => account.id),
        containsAll(['microsoft:existing', 'account-1']),
      );
      await _disposeApp(tester);
    },
  );

  testWidgets('account add failure stays in Settings and preserves the session', (
    tester,
  ) async {
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

    await _authorizeGoogleSetup(tester);
    await tester.pumpAndSettle();

    expect(oAuth.signInCalls, 1);
    expect(find.byType(SettingsScreen), findsOneWidget);
    expect(
      find.text(
        'Authorization timed out. Try again; select a fresh configuration if it was imported.',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('raw timeout'), findsNothing);
    _expectExistingSessionSignedIn(
      container.read(authSessionControllerProvider),
      'microsoft:existing',
    );
    expect(
      (await tester.runAsync(
        () => database.select(database.accounts).getSingle(),
      ))!.authState,
      accountAuthStateSignedIn,
    );
    await _disposeApp(tester);
  });

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
      final accounts = (await tester.runAsync(
        () => database.select(database.accounts).get(),
      ))!;
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

Future<void> _connectGoogleThroughSettings(WidgetTester tester) async {
  await _authorizeGoogleSetup(tester);
  await tester.pumpAndSettle();
  await _sendAltLeft(tester);
}

Future<void> _sendAltLeft(WidgetTester tester) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
  await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowLeft);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowLeft);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
  await tester.pumpAndSettle();
}

Future<void> _disposeApp(WidgetTester tester) async {
  // Mock gateways do not consume registration handles like production OAuth.
  ProviderScope.containerOf(
    tester.element(find.byType(BusyMaxApp)),
  ).read(registrationStagingProvider).cancel();
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
  return TestWidgetsFlutterBinding.instance.runAsync(() async {
    await database
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
  });
}

Future<void> _pumpApp(
  WidgetTester tester, {
  required AppDatabase database,
  required OAuthGateway oAuth,
  SecretStore? secrets,
  AuthorizationPersistence? persistence,
  RegistrationStaging? staging,
  SignedInSyncRunner? onSignedIn,
  WebCalSubscriptionService? subscriptionService,
  DavAccountOnboardingService? davService,
  MicrosoftOAuthGateway? microsoftOAuth,
  DesktopActivationService? activations,
  AppSettings? settings,
}) {
  final registrationStaging =
      staging ??
      RegistrationStaging(_configuredBuildConfig, fileReader: _nativeReader);
  if (staging == null) addTearDown(registrationStaging.dispose);
  return tester.pumpWidget(
    ProviderScope(
      overrides: [
        buildConfigProvider.overrideWithValue(registrationStaging.config),
        networkConnectivityMonitorProvider.overrideWithValue(
          NetworkConnectivityMonitor.withoutPlatformObservation(),
        ),
        databaseProvider.overrideWithValue(database),
        localSettingsStoreProvider.overrideWithValue(MemorySettingsStore()),
        initialAppSettingsProvider.overrideWithValue(
          settings ??
              AppSettings.defaults().copyWith(
                runInBackgroundWhenClosed: false,
                showTrayIcon: false,
                startMinimizedToTray: false,
              ),
        ),
        if (activations != null)
          desktopActivationServiceProvider.overrideWithValue(activations),
        if (davService != null)
          davAccountOnboardingServiceProvider.overrideWithValue(davService),
        if (subscriptionService != null)
          webCalSubscriptionServiceProvider.overrideWithValue(
            subscriptionService,
          ),
        registrationStagingProvider.overrideWithValue(registrationStaging),
        if (secrets != null) secretStoreProvider.overrideWithValue(secrets),
        if (persistence != null)
          authorizationPersistenceProvider.overrideWithValue(persistence),
        applicationOAuthGatewayProvider.overrideWithValue(oAuth),
        authRepositoryProvider.overrideWithValue(
          AuthRepository(
            oAuth: oAuth,
            microsoftOAuth: microsoftOAuth,
            database: database,
            authorizationPersistence: persistence,
            nowUtc: () => DateTime.utc(2026, 6, 4),
          ),
        ),
        signedInSyncRunnerProvider.overrideWithValue(
          onSignedIn ?? (accountId, initial) async {},
        ),
      ],
      child: BusyMaxApp(trayServiceFactory: _RoutingTrayService.new),
    ),
  );
}

class _RoutingTrayService extends BusyMaxTrayService {
  _RoutingTrayService(BusyMaxTrayServiceConfiguration configuration)
    : super(configuration: configuration);

  @override
  Future<void> start() async {}

  @override
  Future<void> stop() async {}

  @override
  Future<bool> refreshPresentation() async => true;
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

class _RegistrationFileSelector extends FileSelectorPlatform {
  _RegistrationFileSelector(this.path);
  final String path;
  @override
  Future<XFile?> openFile({
    List<XTypeGroup>? acceptedTypeGroups,
    String? initialDirectory,
    String? confirmButtonText,
  }) async => XFile(path);
}

Future<void> _authorizeGoogleSetup(WidgetTester tester) async {
  if (find.byType(SettingsScreen).evaluate().isEmpty) {
    await tester.tap(find.byKey(const ValueKey('schedule-add-account')));
    await tester.pumpAndSettle();
  }
  await tester.ensureVisible(find.text('Add Google account'));
  await tester.tap(find.text('Add Google account'));
  await tester.pumpAndSettle();
  await _validateAndAuthorizeGoogleSetup(tester);
}

Future<void> _validateAndAuthorizeGoogleSetup(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('registration-custom')));
  await tester.pumpAndSettle();
  await tester.runAsync(() async {
    final action = tester
        .widget<FilledButton>(find.byKey(const ValueKey('registration-import')))
        .onPressed;
    expect(action, isNotNull);
    await (action as dynamic)();
  });
  await tester.pumpAndSettle();
  final button = tester.widget<ElevatedButton>(
    find.byKey(const ValueKey('registration-authorize')),
  );
  expect(button.onPressed, isNotNull);
  await tester.tap(find.byKey(const ValueKey('registration-authorize')));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 250));
  await tester.pump();
}

class _MigrationBrowserFlow extends OAuthLoopbackFlow {
  _MigrationBrowserFlow() : super(authorizationLauncher: (_) async => false);
  final clients = <String>[];
  @override
  Future<OAuthLoopbackResult> start({
    required Uri authorizationEndpoint,
    required String clientId,
    required String scope,
    String redirectHost = '127.0.0.1',
    String signInCancelledMessage = '',
    String callbackNotReceivedMessage = '',
    String serverStartFailureMessage = '',
    String browserLaunchFailureMessage = '',
    Map<String, String> extraAuthorizationParameters = const {},
    String? loginHint,
    AuthorizationAttempt? attempt,
  }) async {
    clients.add(clientId);
    return OAuthLoopbackResult(
      callback: OAuthCallbackResult(code: 'synthetic-code', scope: scope),
      redirectUri: 'http://127.0.0.1:4321/',
      codeVerifier: 'synthetic-verifier',
    );
  }
}

final class _FixtureCalendarTransport implements WebCalHttpTransport {
  @override
  Future<WebCalHttpResponse> get(
    Uri uri, {
    WebCalHttpValidators validators = const WebCalHttpValidators(),
    Uri? validatorTarget,
  }) async => WebCalHttpResponse(
    statusCode: 200,
    finalUri: uri,
    body: Uint8List.fromList(
      utf8.encode(
        'BEGIN:VCALENDAR\r\nVERSION:2.0\r\nPRODID:-//BusyMax Test//EN\r\nBEGIN:VEVENT\r\nUID:subscription-event\r\nDTSTAMP:20261003T000000Z\r\nDTSTART:20261003T090000Z\r\nDTEND:20261003T100000Z\r\nSUMMARY:Subscribed event\r\nEND:VEVENT\r\nEND:VCALENDAR\r\n',
      ),
    ),
    etag: null,
    lastModified: null,
    contentType: 'text/calendar',
    conditionalRequestSent: false,
  );
}

Future<void> _connectControlledProvider(
  WidgetTester tester,
  BusyProvider provider,
) async {
  final label = switch (provider) {
    BusyProvider.microsoft => 'Add Microsoft account',
    BusyProvider.appleICloud => 'Add Apple iCloud Calendar account',
    BusyProvider.nextcloud => 'Add Nextcloud account',
    _ => throw StateError('Unsupported fixture provider'),
  };
  await tester.ensureVisible(find.text(label));
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
  if (provider == BusyProvider.microsoft) {
    await tester.tap(find.byKey(const ValueKey('registration-custom')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('registration-client-id')),
      '11111111-1111-1111-1111-111111111111',
    );
    await tester.pumpAndSettle();
    final connect = tester.widget<ElevatedButton>(
      find.byKey(const ValueKey('registration-authorize')),
    );
    expect(connect.onPressed, isNotNull);
    await tester.tap(find.byKey(const ValueKey('registration-authorize')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump();
    return;
  }
  if (provider == BusyProvider.appleICloud) {
    await tester.enterText(
      find.byKey(const Key('apple-account-email-field')),
      'fixture@example.test',
    );
    await tester.enterText(
      find.byKey(const Key('apple-app-specific-password-field')),
      'abcd-efgh-ijkl-mnop',
    );
  } else {
    await tester.enterText(
      find.byKey(const Key('nextcloud-server-field')),
      'https://cloud.example.test/',
    );
  }
  await tester.tap(find.text('Connect').last);
  for (var attempt = 0; attempt < 15; attempt++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 5)),
    );
    await tester.pump();
  }
}

class _ControlledMicrosoftGateway implements MicrosoftOAuthGateway {
  @override
  Future<MicrosoftOAuthSignInResult> signInWithMicrosoft() async =>
      MicrosoftOAuthSignInResult(
        accountId: 'microsoft:new',
        tokenSet: _tokenSet(
          scopes: Set.of(microsoftTodoOAuthScopes.split(' ')),
        ),
        user: const MicrosoftTodoUserDto(
          id: 'new',
          rawJson: {},
          displayName: 'Microsoft fixture',
        ),
      );
  @override
  Future<void> cancelSignIn() async {}
  @override
  Future<void> signOutAccount(String accountId) async {}
}

DavAccountOnboardingService _controlledDavService(
  AppDatabase database,
  InMemorySecretStore secrets,
) => DavAccountOnboardingService(
  database: database,
  secretStore: secrets,
  idFactory: () => 'fixture',
  nextcloudLoginFlow: NextcloudLoginFlowV2(
    client: MockClient(
      (request) async => http.Response(
        jsonEncode(
          request.url.path.endsWith('/poll')
              ? {
                  'server': 'https://cloud.example.test/',
                  'loginName': 'fixture',
                  'appPassword': 'abcd-efgh-ijkl-mnop',
                }
              : {
                  'poll': {
                    'token': 'fixture',
                    'endpoint': 'https://cloud.example.test/login/v2/poll',
                  },
                  'login': 'https://cloud.example.test/login/v2/browser',
                },
        ),
        200,
      ),
    ),
    browserLauncher: (_) async => true,
    delay: (_) async {},
  ),
  discover:
      ({
        required accountId,
        required provider,
        required accountAuthority,
        required credential,
        cancellationToken,
      }) async => DavDiscoveryResult(
        accountId: accountId,
        provider: provider,
        service: DavServiceDiscovery(
          canonicalServiceUri: accountAuthority,
          canonicalOrigin: accountAuthority.replace(path: ''),
          principalHref: accountAuthority.resolve('/principals/fixture/'),
          calendarHomeHref: accountAuthority.resolve('/calendars/fixture/'),
          calendarUserAddresses: const [],
          scheduleInboxHref: null,
          scheduleOutboxHref: null,
          capabilities: const AccountServiceCapabilities(
            hasPrincipal: true,
            hasCalendarHome: true,
          ),
          discoveredAtUtc: DateTime.utc(2026, 10, 4),
          lastValidatedAtUtc: DateTime.utc(2026, 10, 4),
          providerProfileVersion: 1,
        ),
        collections: const [],
      ),
);

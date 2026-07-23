import 'package:busymax/src/app/app_bootstrap.dart';
import 'package:busymax/src/config/build_config.dart';
import 'package:busymax/src/demo/demo_profile.dart';
import 'package:busymax/src/demo/demo_seed.dart';
import 'package:busymax/src/features/auth/data/auth_repository.dart';
import 'package:busymax/src/features/feedback/data/feedback_submission.dart';
import 'package:busymax/src/features/schedule/application/compact_agenda_data.dart';
import 'package:busymax/src/features/sync/account_sync_operations.dart';
import 'package:busymax/src/google_tasks/oauth/oauth_token_store.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('demo settings are isolated and disable background effects', () async {
    final settings = busyMaxDemoSettings(BusyMaxDemoTheme.dark);
    final store = InMemoryLocalSettingsStore(settings.toJson());

    expect(settings.themeModePreference, BusyMaxThemeModePreference.dark);
    expect(settings.runInBackgroundWhenClosed, isFalse);
    expect(settings.showTrayIcon, isFalse);
    expect(settings.startMinimizedToTray, isFalse);
    expect(settings.notifySyncFailures, isFalse);
    expect(settings.notifyConflicts, isFalse);
    expect(settings.notifyDueToday, isFalse);
    expect(settings.notifyEventReminders, isFalse);
    expect(settings.notifyTaskReminders, isFalse);

    final loaded = await loadInitialAppSettings(store);
    expect(loaded.themeModePreference, BusyMaxThemeModePreference.dark);
    await store.save(
      loaded
          .copyWith(themeModePreference: BusyMaxThemeModePreference.light)
          .toJson(),
    );
    expect(
      store.snapshot['themeModePreference'],
      BusyMaxThemeModePreference.light.name,
    );
  });

  test('demo provider graph remains local and owns its database', () async {
    final profile = await BusyMaxDemoProfile.create(
      now: DateTime(2026, 7, 23, 10),
    );
    final settings = busyMaxDemoSettings(BusyMaxDemoTheme.system);
    final settingsStore = InMemoryLocalSettingsStore(settings.toJson());
    final container = ProviderContainer(
      overrides: [
        buildConfigProvider.overrideWithValue(_demoConfig),
        localSettingsStoreProvider.overrideWithValue(settingsStore),
        initialAppSettingsProvider.overrideWithValue(settings),
        ...profile.overrides,
      ],
    );

    final database = container.read(databaseProvider);
    expect(database, same(profile.database));
    expect(
      await database
          .select(database.accounts)
          .getSingle()
          .then((account) => account.id),
      busyMaxDemoAccountId,
    );
    final compactAgenda = await container.read(
      compactAgendaDataProvider.future,
    );
    expect(
      compactAgenda.items.map((item) => item.title),
      contains('Product planning'),
    );

    final authState = await container
        .read(authRepositoryProvider)
        .loadSession();
    expect(authState.status, AuthSessionStatus.signedIn);
    expect(authState.accountId, busyMaxDemoAccountId);
    expect(
      container.read(applicationOAuthGatewayProvider),
      isA<DemoOAuthGateway>(),
    );
    expect(container.read(applicationMicrosoftOAuthServiceProvider), isNull);
    expect(
      container.read(oAuthTokenStoreProvider),
      isA<InMemoryOAuthTokenStore>(),
    );
    expect(
      container.read(
        taskRemoteApiClientForAccountProvider(busyMaxDemoAccountId),
      ),
      isNull,
    );

    final sync = container.read(accountSyncOperationsProvider);
    expect(sync, isA<DisabledAccountSyncOperations>());
    await sync.syncAccount(busyMaxDemoAccountId, full: true);
    await sync.syncTasks(busyMaxDemoAccountId, full: false);
    await sync.syncCalendar(busyMaxDemoAccountId, full: false);

    expect(
      container.read(desktopNotificationBackendProvider),
      isA<DemoDesktopNotificationBackend>(),
    );
    final feedbackReceipt = await container
        .read(feedbackSubmissionServiceProvider)
        .submit(_feedback);
    expect(feedbackReceipt.id, 'demo-demo-submission');
    expect(
      container
          .read(baseHttpClientProvider)
          .get(Uri.parse('https://example.test')),
      throwsA(isA<StateError>()),
    );

    container.dispose();
    await Future<void>.delayed(Duration.zero);
    expect(
      database.select(database.accounts).get(),
      throwsA(isA<StateError>()),
    );
  });

  test('demo OAuth never needs an external authorization flow', () async {
    final gateway = DemoOAuthGateway();

    final result = await gateway.signIn();

    expect(result.accountId, busyMaxDemoAccountId);
    expect(await gateway.activeAccountId, busyMaxDemoAccountId);
    expect(await gateway.readActiveTokenSet(), isNotNull);
    expect(
      (await gateway.fetchUserInfo(result.tokenSet))?.email,
      'alex@example.com',
    );

    await gateway.revokeAndSignOutAccount(busyMaxDemoAccountId);
    expect(await gateway.activeAccountId, isNull);
  });
}

const _demoConfig = BuildConfig(
  googleOAuthClientId: '',
  googleOAuthClientSecret: '',
  oauthAuthorizationEndpoint: 'https://example.test/authorize',
  oauthTokenEndpoint: 'https://example.test/token',
  oauthRevocationEndpoint: 'https://example.test/revoke',
  useFakeProviderData: true,
);

const _feedback = FeedbackSubmission(
  submissionId: 'demo-submission',
  appVersion: '1.0.0',
  buildNumber: '1',
  category: FeedbackCategory.usability,
  subject: 'Demo feedback',
  message: 'This remains inside the local demo profile.',
  replyEmail: null,
);

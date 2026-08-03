import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:busymax/src/app/app_bootstrap.dart';
import 'package:busymax/src/config/build_config.dart';
import 'package:busymax/src/db/app_database.dart';
import 'package:busymax/src/features/accounts/data/accounts_repository.dart';
import 'package:busymax/src/features/auth/data/auth_repository.dart';
import 'package:busymax/src/google_tasks/api/google_tasks_api_surface.dart';
import 'package:busymax/src/google_tasks/oauth/oauth_models.dart';
import 'package:busymax/src/google_tasks/oauth/oauth_service.dart';
import 'package:busymax/src/task_providers/task_provider.dart';

void main() {
  test('repositories are not created without an active account', () async {
    final database = AppDatabase(NativeDatabase.memory());
    final container = _container(
      database: database,
      oAuth: _FakeOAuthGateway(),
    );
    addTearDown(() async {
      container.dispose();
      await database.close();
    });

    await container.read(authSessionControllerProvider.notifier).load();

    expect(container.read(activeAccountProvider), isNull);
    expect(container.read(taskListsRepositoryProvider), isNull);
    expect(container.read(tasksRepositoryProvider), isNull);
  });

  test('repositories are created after session sign-in', () async {
    final database = AppDatabase(NativeDatabase.memory());
    final container = _container(
      database: database,
      oAuth: _FakeOAuthGateway(),
    );
    addTearDown(() async {
      container.dispose();
      await database.close();
    });

    await container.read(authSessionControllerProvider.notifier).signIn();

    expect(container.read(activeAccountProvider), 'account-1');
    expect(container.read(taskListsRepositoryProvider), isNotNull);
    expect(container.read(tasksRepositoryProvider), isNotNull);
  });

  test('sign-in starts initial sync without circular provider reads', () async {
    final database = AppDatabase(NativeDatabase.memory());
    final syncCalls = <_SyncCall>[];
    final container = _container(
      database: database,
      oAuth: _FakeOAuthGateway(),
      signedInSyncRunner: (accountId, initial) async {
        syncCalls.add(_SyncCall(accountId, initial));
      },
    );
    addTearDown(() async {
      container.dispose();
      await database.close();
    });

    final controller = container.read(authSessionControllerProvider.notifier);
    await controller.load();
    await _flushAsync();

    await controller.signIn();
    await _flushAsync();

    final state = container.read(authSessionControllerProvider);
    expect(state.status, AuthSessionStatus.signedIn);
    expect(state.accountId, 'account-1');
    expect(syncCalls, hasLength(1));
    expect(syncCalls.single.accountId, 'account-1');
    expect(syncCalls.single.initial, isTrue);
  });

  test(
    'loaded session starts incremental sync without circular provider reads',
    () async {
      final database = AppDatabase(NativeDatabase.memory());
      await _seedSignedInGoogleAccount(database);
      final syncStarted = Completer<void>();
      final syncCalls = <_SyncCall>[];
      final container = _container(
        database: database,
        oAuth: _FakeOAuthGateway(),
        signedInSyncRunner: (accountId, initial) async {
          syncCalls.add(_SyncCall(accountId, initial));
          if (!syncStarted.isCompleted) {
            syncStarted.complete();
          }
        },
      );
      addTearDown(() async {
        container.dispose();
        await database.close();
      });

      container.read(authSessionControllerProvider);
      await syncStarted.future.timeout(const Duration(seconds: 1));
      await _flushAsync();

      final state = container.read(authSessionControllerProvider);
      expect(state.status, AuthSessionStatus.signedIn);
      expect(syncCalls, hasLength(1));
      expect(syncCalls.single.accountId, 'account-1');
      expect(syncCalls.single.initial, isFalse);
    },
  );

  test('sign-in keeps signed-in state when sync runner fails', () async {
    final database = AppDatabase(NativeDatabase.memory());
    var syncCalls = 0;
    final container = _container(
      database: database,
      oAuth: _FakeOAuthGateway(),
      signedInSyncRunner: (accountId, initial) async {
        syncCalls += 1;
        throw StateError('sync failed');
      },
    );
    addTearDown(() async {
      container.dispose();
      await database.close();
    });

    Object? zoneError;
    await runZonedGuarded<Future<void>>(
      () async {
        final controller = container.read(
          authSessionControllerProvider.notifier,
        );
        await controller.load();
        await _flushAsync();

        await controller.signIn();
        await _flushAsync();
      },
      (error, _) {
        zoneError = error;
      },
    );

    final state = container.read(authSessionControllerProvider);
    expect(zoneError, isNull);
    expect(syncCalls, 1);
    expect(state.status, AuthSessionStatus.signedIn);
    expect(state.accountId, 'account-1');
  });

  test(
    'loaded session marks account reconnect required when startup sync has no token',
    () async {
      final database = AppDatabase(NativeDatabase.memory());
      await _seedSignedInGoogleAccount(database);
      final syncStarted = Completer<void>();
      final container = _container(
        database: database,
        oAuth: _FakeOAuthGateway(),
        signedInSyncRunner: (accountId, initial) async {
          if (!syncStarted.isCompleted) {
            syncStarted.complete();
          }
          throw const OAuthException(
            'OAuthMissingToken',
            'No OAuth token is available for this account.',
          );
        },
      );
      addTearDown(() async {
        container.dispose();
        await database.close();
      });

      Object? zoneError;
      await runZonedGuarded<Future<void>>(
        () async {
          container.read(authSessionControllerProvider);
          await syncStarted.future.timeout(const Duration(seconds: 1));
          await _flushAsync();
          await _flushAsync();
        },
        (error, _) {
          zoneError = error;
        },
      );

      final state = container.read(authSessionControllerProvider);
      final account = await database.select(database.accounts).getSingle();
      expect(zoneError, isNull);
      expect(state.status, AuthSessionStatus.signedOut);
      expect(account.authState, accountAuthStateReauthRequired);
    },
  );
}

Future<void> _seedSignedInGoogleAccount(AppDatabase database) {
  return AccountsRepository(
    database: database,
    nowUtc: () => DateTime.utc(2026, 6, 4),
  ).upsertSignedInAccount(
    id: 'account-1',
    provider: TaskProvider.google,
    grantedScopes: googleBusyMaxOAuthScopes.join(' '),
  );
}

ProviderContainer _container({
  required AppDatabase database,
  required _FakeOAuthGateway oAuth,
  SignedInSyncRunner? signedInSyncRunner,
}) {
  return ProviderContainer(
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
        signedInSyncRunner ?? (accountId, initial) async {},
      ),
    ],
  );
}

Future<void> _flushAsync() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

class _SyncCall {
  const _SyncCall(this.accountId, this.initial);

  final String accountId;
  final bool initial;
}

class _FakeOAuthGateway implements OAuthGateway {
  String? activeId;

  @override
  Future<String?> get activeAccountId async => activeId;

  @override
  Future<void> cancelSignIn() async {}

  @override
  Future<OAuthTokenSet?> readActiveTokenSet() async {
    if (activeId == null) {
      return null;
    }
    return _tokenSet();
  }

  @override
  Future<GoogleUserInfo?> fetchUserInfo(OAuthTokenSet tokenSet) async => null;

  @override
  Future<OAuthTokenSet> refreshActiveToken() async => _tokenSet();

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
    activeId = 'account-1';
    return OAuthSignInResult(accountId: 'account-1', tokenSet: _tokenSet());
  }
}

OAuthTokenSet _tokenSet() {
  return OAuthTokenSet(
    accessToken: 'access',
    refreshToken: 'refresh',
    expiresAtUtc: DateTime.utc(2026, 6, 4, 1),
    tokenType: 'Bearer',
    scopes: Set<String>.of(googleBusyMaxOAuthScopes),
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

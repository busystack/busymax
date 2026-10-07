import '../../../core/auth/authorization_transition_test.dart'
    show Harness, owned, tokens;
import 'dart:async';

import 'package:busymax/src/core/auth/authorization_persistence.dart';
import 'package:busymax/src/core/auth/oauth_registration.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:busymax/src/config/build_config.dart';
import 'package:busymax/src/db/app_database.dart';
import 'package:busymax/src/dav/dav_errors.dart';
import 'package:busymax/src/features/accounts/data/accounts_repository.dart';
import 'package:busymax/src/features/auth/data/auth_repository.dart';
import 'package:busymax/src/google_tasks/api/google_tasks_api_surface.dart';
import 'package:busymax/src/google_tasks/oauth/oauth_loopback_flow.dart';
import 'package:busymax/src/core/auth/oauth_models.dart';
import 'package:busymax/src/google_tasks/oauth/oauth_service.dart';
import 'package:busymax/src/core/secrets/secret_store.dart';
import 'package:busymax/src/microsoft_todo/oauth/microsoft_oauth_service.dart';
import 'package:busymax/src/microsoft_todo/api/microsoft_todo_api_models.dart';
import 'package:busymax/src/providers/busy_provider.dart';

void main() {
  late AppDatabase database;
  late FakeOAuthGateway oAuth;
  late AuthRepository repository;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    oAuth = FakeOAuthGateway();
    repository = AuthRepository(
      oAuth: oAuth,
      database: database,
      nowUtc: () => DateTime.utc(2026, 6, 4),
    );
  });

  tearDown(() async {
    await database.close();
  });

  for (final shared in [false, true]) {
    test('removal rejects a late real Google refresh shared=$shared', () async {
      final h = Harness();
      addTearDown(() async {
        h.staging.dispose();
        await h.db.close();
      });
      await h.seed();
      if (!shared) {
        await h.persistence.commit(
          accountId: 'opaque',
          expectedGeneration: 1,
          candidate: GoogleDesktopCredential(
            registration: owned,
            tokenSet: tokens(),
            subject: 'subject',
            generation: 2,
            transitionEligible: false,
          ),
          requireExisting: true,
          persistAccount: () async {},
        );
      }
      final started = Completer<void>(), release = Completer<void>();
      h.beforeRequest = (request) async {
        if (request.url.path == '/token') {
          started.complete();
          await release.future;
        }
        return null;
      };
      final refresh = h.google.refreshTokenForAccount('opaque');
      final rejected = expectLater(
        refresh,
        throwsA(
          isA<OAuthException>().having(
            (e) => e.classification,
            'stale refresh',
            OAuthFailureKind.stale,
          ),
        ),
      );
      await started.future;
      final result = await h.repository.removeAccount(
        accountId: 'opaque',
        revokeAuthorization: true,
      );
      expect(
        result.authorizationRevocationStatus,
        AccountAuthorizationRevocationStatus.succeeded,
      );
      expect(
        Uri.splitQueryString(h.requests.last.body)['token'],
        'working-refresh',
      );
      release.complete();
      await rejected;
      expect(await h.secrets.readCredential('opaque'), isNull);
      expect(await h.accounts.accountById('opaque'), isNull);
      expect(await h.persistence.run('opaque', () async => true), isTrue);
    });
  }
  for (final shared in [false, true]) {
    test(
      'post-deletion cleanup failure reports irreversible state shared=$shared',
      () async {
        final h = Harness();
        addTearDown(() async {
          h.staging.dispose();
          await h.db.close();
        });
        await h.seed();
        if (!shared) {
          await h.persistence.commit(
            accountId: 'opaque',
            expectedGeneration: 1,
            candidate: GoogleDesktopCredential(
              registration: owned,
              tokenSet: tokens(),
              subject: 'subject',
              generation: 2,
              transitionEligible: false,
            ),
            requireExisting: true,
            persistAccount: () async {},
          );
        }
        var failCleanup = true;
        final persistence = AuthorizationPersistence(
          database: h.db,
          secrets: h.secrets,
          onRemovalCommitted: (id, snapshot) async {
            if (failCleanup) {
              throw const SecretStoreException(
                'injected',
                'Synthetic cleanup failure.',
              );
            }
          },
        );
        final requests = <http.Request>[];
        final google = OAuthService(
          config: BuildConfig.fromEnvironment(),
          tokenStore: h.secrets,
          persistence: persistence,
          loopbackFlow: OAuthLoopbackFlow(),
          httpClient: MockClient((request) async {
            requests.add(request);
            return http.Response('', 200);
          }),
        );
        final repository = AuthRepository(
          oAuth: google,
          database: h.db,
          authorizationPersistence: persistence,
        );
        await expectLater(
          repository.removeAccount(
            accountId: 'opaque',
            revokeAuthorization: true,
          ),
          throwsA(
            isA<AccountRemovalPersistenceException>()
                .having(
                  (e) => e.remoteAuthorizationRevoked,
                  'remote grant was revoked',
                  true,
                )
                .having(
                  (e) => e.message,
                  'no false local rollback claim',
                  isNot(contains('preserved')),
                ),
          ),
        );
        expect(requests.map((r) => r.url.path), ['/revoke']);
        expect(
          Uri.splitQueryString(requests.single.body)['token'],
          'working-refresh',
        );
        expect(await h.accounts.accountById('opaque'), isNull);
        expect(await h.secrets.readCredential('opaque'), isNull);
        expect(await persistence.generation('opaque'), shared ? 2 : 3);
        expect(
          await h.db.select(h.db.authorizationCommits).get(),
          hasLength(1),
        );
        failCleanup = false;
        await persistence.recover();
        expect(await h.db.select(h.db.authorizationCommits).get(), isEmpty);
        expect(await h.secrets.readCredential('opaque'), isNull);
        expect(
          (await repository.removeAccount(accountId: 'opaque')).alreadyRemoved,
          isTrue,
        );
        expect(await persistence.run('opaque', () async => true), isTrue);
      },
    );
  }
  test(
    'successful remote revocation followed by failed local removal reports actual state',
    () async {
      final h = Harness();
      addTearDown(() async {
        h.staging.dispose();
        await h.db.close();
      });
      await h.seed();
      await h.db.customStatement(
        "CREATE TRIGGER refuse_delete BEFORE DELETE ON accounts BEGIN SELECT RAISE(ABORT, 'injected'); END",
      );
      await expectLater(
        h.repository.removeAccount(
          accountId: 'opaque',
          revokeAuthorization: true,
        ),
        throwsA(
          isA<AccountRemovalPersistenceException>().having(
            (e) => e.remoteAuthorizationRevoked,
            'remote side effect remains',
            true,
          ),
        ),
      );
      expect(h.requests.where((r) => r.url.path == '/revoke'), hasLength(1));
      expect(await h.accounts.accountById('opaque'), isNotNull);
      await h.persistence.recover();
      expect(
        await h.persistence.readCurrentCredential('opaque'),
        isA<GoogleDesktopCredential>(),
      );
      await h.db.customStatement('DROP TRIGGER refuse_delete');
      await h.repository.removeAccount(accountId: 'opaque');
      expect(await h.secrets.readCredential('opaque'), isNull);
    },
  );
  test(
    'legacy selected record is revoked without refresh or issuer discovery',
    () async {
      final h = Harness();
      addTearDown(() async {
        h.staging.dispose();
        await h.db.close();
      });
      await h.seed();
      await h.secrets.saveCredential(
        'opaque',
        OAuthSecretRecord(provider: BusyProvider.google, tokenSet: tokens()),
      );
      await h.repository.removeAccount(
        accountId: 'opaque',
        revokeAuthorization: true,
      );
      expect(h.requests.map((r) => r.url.path).toList(), ['/revoke']);
      expect(await h.secrets.readCredential('opaque'), isNull);
    },
  );
  for (final shared in [false, true]) {
    for (final outcome in ['success', 'failure', 'timeout', 'local-only']) {
      test(
        'production Google removal $outcome shared=$shared releases its boundary',
        () async {
          final secrets = InMemorySecretStore();
          final persistence = AuthorizationPersistence(
            database: database,
            secrets: secrets,
          );
          for (final id in ['selected', 'other']) {
            await AccountsRepository(database: database).upsertSignedInAccount(
              id: id,
              provider: BusyProvider.google,
              providerAccountId: id,
              grantedScopes: googleBusyMaxOAuthScope,
            );
            await persistence.commit(
              accountId: id,
              expectedGeneration: 0,
              requireExisting: true,
              candidate: GoogleDesktopCredential(
                registration: GoogleDesktopRegistration(
                  clientId: '$id.apps.googleusercontent.com',
                  projectId: 'fixture',
                  origin: shared
                      ? RegistrationOrigin.retiringShared
                      : RegistrationOrigin.userProvided,
                ),
                subject: id,
                generation: 1,
                transitionEligible: shared,
                tokenSet: _tokenSet().copyWith(
                  refreshToken: '$id-refresh',
                  expiresAtUtc: DateTime.utc(2040),
                ),
              ),
              persistAccount: () async {},
            );
          }
          if (shared) {
            await database
                .into(database.oAuthTransitionAccounts)
                .insert(
                  OAuthTransitionAccountsCompanion.insert(
                    accountId: 'selected',
                  ),
                );
          }
          await secrets.setActiveAccountId('other');
          final requests = <http.Request>[];
          final service = OAuthService(
            config: BuildConfig.fromEnvironment(),
            tokenStore: secrets,
            persistence: persistence,
            loopbackFlow: OAuthLoopbackFlow(),
            authorizationRevocationTimeout: const Duration(milliseconds: 10),
            httpClient: MockClient((request) async {
              requests.add(request);
              if (outcome == 'timeout') {
                return Completer<http.Response>().future;
              }
              return http.Response('', outcome == 'failure' ? 503 : 200);
            }),
          );
          final realRepository = AuthRepository(
            oAuth: service,
            database: database,
            authorizationPersistence: persistence,
          );
          final result = await realRepository
              .removeAccount(
                accountId: 'selected',
                revokeAuthorization: outcome != 'local-only',
              )
              .timeout(const Duration(seconds: 1));
          expect(result.authorizationRevocationStatus, switch (outcome) {
            'success' => AccountAuthorizationRevocationStatus.succeeded,
            'local-only' => AccountAuthorizationRevocationStatus.notRequested,
            _ => AccountAuthorizationRevocationStatus.failed,
          });
          expect(requests.length, outcome == 'local-only' ? 0 : 1);
          if (requests.isNotEmpty) {
            expect(
              requests.single.url,
              Uri.https('oauth2.googleapis.com', '/revoke'),
            );
            expect(
              Uri.splitQueryString(requests.single.body)['token'],
              'selected-refresh',
            );
          }
          expect(
            await AccountsRepository(
              database: database,
            ).accountById('selected'),
            isNull,
          );
          expect(await secrets.readCredential('selected'), isNull);
          expect(await persistence.generation('selected'), 2);
          expect(
            await database.select(database.authorizationCommits).get(),
            isEmpty,
          );
          expect(
            (await realRepository.removeAccount(
              accountId: 'selected',
            )).alreadyRemoved,
            true,
          );
          expect(
            await persistence.readCurrentCredential('other'),
            isA<GoogleDesktopCredential>(),
          );
          expect(
            await service.authorizationHeaderForAccount('other'),
            'Bearer access',
          );
          await persistence.run('selected', () async {});
        },
      );
    }
  }

  test('DAV authentication failures expose only their safe message', () {
    const error = DavException(
      kind: DavErrorKind.authentication,
      code: 'NextcloudLoginFlowStartRejected',
      safeMessage: 'Nextcloud could not start browser authorization.',
      statusCode: 401,
    );

    expect(
      authErrorMessage(error),
      'Nextcloud could not start browser authorization.',
    );
  });

  test('successful sign-in upserts signed-in account row', () async {
    final state = await repository.signIn();

    final account = await database.select(database.accounts).getSingle();

    expect(state, isA<AuthSessionState>());
    expect(state.accountId, 'account-1');
    expect(account.id, 'account-1');
    expect(account.authState, 'signed_in');
    expect(account.grantedScopes, googleBusyMaxOAuthScopes.join(' '));
  });

  test(
    'successful Google sign-in stores userinfo display name and email',
    () async {
      oAuth.nextUserInfo = const GoogleUserInfo(
        subject: 'google-subject',
        name: 'Google User',
        email: 'google@example.com',
        rawJson: {
          'sub': 'google-subject',
          'name': 'Google User',
          'email': 'google@example.com',
        },
      );

      await repository.signIn();

      final account = await database.select(database.accounts).getSingle();
      expect(account.providerAccountId, 'google-subject');
      expect(account.displayName, 'Google User');
      expect(account.email, 'google@example.com');
      expect(account.providerMetadataJson, contains('Google User'));
    },
  );

  test('sign-in accepts granted Tasks and Calendar API scopes', () async {
    oAuth.nextTokenSet = _tokenSet(
      scopes: {googleTasksReadWriteScope, googleCalendarReadWriteScope},
    );

    final state = await repository.signIn();

    final account = await database.select(database.accounts).getSingle();
    expect(state.accountId, 'account-1');
    expect(account.authState, 'signed_in');
    expect(account.grantedScopes, contains(googleTasksReadWriteScope));
    expect(account.grantedScopes, contains(googleCalendarReadWriteScope));
    expect(oAuth.revoked, isFalse);
  });

  test(
    'sign-in without required write scope rejects without destructive cleanup',
    () async {
      oAuth.nextTokenSet = _tokenSet(scopes: {googleTasksReadOnlyScope});

      await expectLater(repository.signIn(), throwsA(isA<OAuthException>()));

      expect(oAuth.revoked, isFalse);
      expect(oAuth.revokedAccountId, null);
      expect(await database.select(database.accounts).get(), isEmpty);
    },
  );

  for (final qualified in [false, true]) {
    test(
      'Microsoft sign-in accepts ${qualified ? 'qualified' : 'unqualified'} Graph scopes',
      () async {
        final microsoftOAuth = _FakeMicrosoftOAuthService()
          ..nextTokenSet = _tokenSet(
            scopes: {
              if (qualified)
                'https://graph.microsoft.com/User.Read'
              else
                'User.Read',
              if (qualified)
                'https://graph.microsoft.com/Tasks.ReadWrite'
              else
                'Tasks.ReadWrite',
              if (qualified)
                'https://graph.microsoft.com/Calendars.ReadWrite'
              else
                'Calendars.ReadWrite',
            },
          );
        repository = AuthRepository(
          oAuth: oAuth,
          database: database,
          microsoftOAuth: microsoftOAuth,
          nowUtc: () => DateTime.utc(2026, 6, 4),
        );

        final state = await repository.signInWithMicrosoft();

        expect(state.accountId, 'microsoft:user-1');
        expect(microsoftOAuth.signOutAccountIds, isEmpty);
      },
    );
  }

  test('Microsoft sign-in rejects a genuinely missing permission', () async {
    final microsoftOAuth = _FakeMicrosoftOAuthService()
      ..nextTokenSet = _tokenSet(scopes: {'User.Read', 'Tasks.ReadWrite'});
    repository = AuthRepository(
      oAuth: oAuth,
      database: database,
      microsoftOAuth: microsoftOAuth,
      nowUtc: () => DateTime.utc(2026, 6, 4),
    );

    await expectLater(
      repository.signInWithMicrosoft(),
      throwsA(
        isA<OAuthException>().having(
          (error) => error.code,
          'code',
          'MicrosoftOAuthMissingRequiredScope',
        ),
      ),
    );
    expect(microsoftOAuth.signOutAccountIds, isEmpty);
  });

  test('revocation failure does not mask missing-scope guidance', () async {
    oAuth.nextTokenSet = _tokenSet(scopes: {googleTasksReadOnlyScope});
    oAuth.revokeAndSignOutError = StateError('revocation unavailable');

    await expectLater(
      repository.signIn(),
      throwsA(
        isA<OAuthException>().having(
          (error) => error.code,
          'code',
          'OAuthMissingRequiredScope',
        ),
      ),
    );

    expect(oAuth.revoked, isFalse);
    expect(oAuth.revokedAccountId, null);
    expect(await database.select(database.accounts).get(), isEmpty);
  });

  test(
    'loadSession does not touch token storage on signed-out startup',
    () async {
      final state = await repository.loadSession();

      expect(state.status, AuthSessionStatus.signedOut);
      expect(oAuth.activeAccountIdReads, 0);
      expect(oAuth.readActiveTokenSetCalls, 0);
    },
  );

  test(
    'loadSession trusts signed-in account rows without reading tokens',
    () async {
      await _insertAccount(database, 'account-1', BusyProvider.google);
      oAuth.activeId = 'account-1';
      oAuth.nextTokenSet = _tokenSet(scopes: {googleTasksReadOnlyScope});

      final state = await repository.loadSession();

      expect(state.status, AuthSessionStatus.signedIn);
      expect(state.accountId, 'account-1');
      expect(oAuth.activeAccountIdReads, 0);
      expect(oAuth.readActiveTokenSetCalls, 0);
      expect(oAuth.revoked, isFalse);
    },
  );

  test(
    'markReconnectRequired keeps account row visible but not syncable',
    () async {
      await _insertAccount(database, 'google:g', BusyProvider.google);
      oAuth.activeId = 'google:g';

      await repository.markReconnectRequired('google:g');

      final account = await database.select(database.accounts).getSingle();
      final accountsRepository = AccountsRepository(database: database);
      final signedInAccounts = await accountsRepository.listSignedInAccounts();
      final visibleAccounts = await accountsRepository
          .watchVisibleAccounts()
          .first;

      expect(oAuth.clearedAccountId, null);
      expect(account.authState, accountAuthStateReauthRequired);
      expect(signedInAccounts, isEmpty);
      expect(visibleAccounts.single.needsReconnect, isTrue);
    },
  );

  test('successful Google reconnect reuses the account row', () async {
    await _insertAccount(
      database,
      'account-1',
      BusyProvider.google,
      authState: accountAuthStateReauthRequired,
    );

    final state = await repository.signIn();

    final accounts = await database.select(database.accounts).get();
    expect(state.accountId, 'account-1');
    expect(accounts, hasLength(1));
    expect(accounts.single.id, 'account-1');
    expect(accounts.single.authState, accountAuthStateSignedIn);
    expect(oAuth.clearedAccountId, null);
  });

  test('markReconnectRequired removes only target notifications', () async {
    await _insertAccount(database, 'google-a', BusyProvider.google);
    await _insertAccount(database, 'google-b', BusyProvider.google);
    await _insertNotification(database, 'google-a');
    await _insertNotification(database, 'google-b');

    await repository.markReconnectRequired('google-a');

    final notifications = await database
        .select(database.notificationSchedule)
        .get();
    expect(
      notifications.map((row) => row.accountId),
      containsAll(['google-a', 'google-b']),
    );
  });

  test(
    'markReconnectRequired selects credential storage by provider',
    () async {
      final microsoftOAuth = _FakeMicrosoftOAuthService();
      repository = AuthRepository(
        oAuth: oAuth,
        database: database,
        microsoftOAuth: microsoftOAuth,
        nowUtc: () => DateTime.utc(2026, 6, 4),
      );
      const opaqueAccountId = 'opaque-account-id';
      await _insertAccount(database, opaqueAccountId, BusyProvider.microsoft);

      await repository.markReconnectRequired(opaqueAccountId);

      expect(microsoftOAuth.signOutAccountIds, isEmpty);
      expect(oAuth.clearedAccountId, null);
    },
  );

  test('removeAccount removes only the selected Google account', () async {
    final microsoftOAuth = _FakeMicrosoftOAuthService();
    repository = AuthRepository(
      oAuth: oAuth,
      database: database,
      microsoftOAuth: microsoftOAuth,
      nowUtc: () => DateTime.utc(2026, 6, 4),
    );
    await _insertAccount(database, 'google-a', BusyProvider.google);
    await _insertAccount(database, 'microsoft:m', BusyProvider.microsoft);
    await _insertNotification(database, 'google-a');
    await _insertNotification(database, 'microsoft:m');

    final result = await repository.removeAccount(accountId: 'google-a');

    final accounts = await database.select(database.accounts).get();
    final notifications = await database
        .select(database.notificationSchedule)
        .get();
    expect(
      result.authorizationRevocationStatus,
      AccountAuthorizationRevocationStatus.notRequested,
    );
    expect(oAuth.clearedAccountId, 'google-a');
    expect(oAuth.revoked, isFalse);
    expect(microsoftOAuth.signOutAccountIds, isEmpty);
    expect(accounts.map((account) => account.id), ['microsoft:m']);
    expect(notifications.map((row) => row.accountId), ['microsoft:m']);
  });

  test(
    'removeAccount clears Microsoft credentials without Google revocation',
    () async {
      final microsoftOAuth = _FakeMicrosoftOAuthService();
      repository = AuthRepository(
        oAuth: oAuth,
        database: database,
        microsoftOAuth: microsoftOAuth,
        nowUtc: () => DateTime.utc(2026, 6, 4),
      );
      await _insertAccount(database, 'google:g', BusyProvider.google);
      await _insertAccount(database, 'microsoft:m', BusyProvider.microsoft);

      final result = await repository.removeAccount(
        accountId: 'microsoft:m',
        revokeAuthorization: true,
      );

      final accounts = await database.select(database.accounts).get();
      expect(
        result.authorizationRevocationStatus,
        AccountAuthorizationRevocationStatus.notRequested,
      );
      expect(oAuth.revoked, isFalse);
      expect(oAuth.clearedAccountId, null);
      expect(microsoftOAuth.signOutAccountIds, ['microsoft:m']);
      expect(accounts.map((account) => account.id), ['google:g']);
    },
  );

  test(
    'removeAccount can revoke Google authorization before local cleanup',
    () async {
      await repository.signIn();

      final result = await repository.removeAccount(
        accountId: 'account-1',
        revokeAuthorization: true,
      );

      expect(await database.select(database.accounts).get(), isEmpty);
      expect(
        result.authorizationRevocationStatus,
        AccountAuthorizationRevocationStatus.succeeded,
      );
      expect(oAuth.revokedAccountId, 'account-1');
      expect(oAuth.clearedAccountId, 'account-1');
    },
  );

  test(
    'removeAccount reports revocation failure but still removes locally',
    () async {
      await repository.signIn();
      oAuth.revocationError = const OAuthException(
        'OAuthRevocationFailed',
        'offline',
      );

      final result = await repository.removeAccount(
        accountId: 'account-1',
        revokeAuthorization: true,
      );

      expect(result.authorizationRevocationFailed, isTrue);
      expect(oAuth.clearedAccountId, 'account-1');
      expect(await database.select(database.accounts).get(), isEmpty);
    },
  );

  test('removeAccount cascades pending offline operations', () async {
    await _insertAccount(database, 'google-a', BusyProvider.google);
    await database
        .into(database.pendingOps)
        .insert(
          PendingOpsCompanion.insert(
            id: 'pending-1',
            accountId: 'google-a',
            entityType: 'task',
            operation: 'patch_task',
            requestJson: '{}',
            createdAtUtc: '2026-06-04T00:00:00.000Z',
            updatedAtUtc: '2026-06-04T00:00:00.000Z',
          ),
        );

    await repository.removeAccount(accountId: 'google-a');

    expect(await database.select(database.pendingOps).get(), isEmpty);
  });

  test(
    'removeAccount keeps local data when credential cleanup fails',
    () async {
      await repository.signIn();
      oAuth.clearError = const OAuthException(
        'SecureStorageFailure',
        'unavailable',
      );

      await expectLater(
        repository.removeAccount(accountId: 'account-1'),
        throwsA(isA<OAuthException>()),
      );

      expect(await database.select(database.accounts).get(), hasLength(1));
    },
  );

  test('removeAccount is idempotent when the row is already absent', () async {
    final result = await repository.removeAccount(accountId: 'missing');

    expect(result.alreadyRemoved, isTrue);
    expect(oAuth.clearedAccountId, null);
  });
}

class FakeOAuthGateway implements OAuthGateway {
  var revoked = false;
  String? revokedAccountId;
  String? clearedAccountId;
  Object? revocationError;
  Object? revokeAndSignOutError;
  Object? clearError;
  String? activeId;
  var activeAccountIdReads = 0;
  var readActiveTokenSetCalls = 0;
  OAuthTokenSet nextTokenSet = _tokenSet();
  GoogleUserInfo? nextUserInfo;

  @override
  Future<String?> get activeAccountId async {
    activeAccountIdReads += 1;
    return activeId;
  }

  @override
  Future<void> cancelSignIn() async {}

  @override
  Future<OAuthTokenSet?> readActiveTokenSet() async {
    readActiveTokenSetCalls += 1;
    if (activeId == null) {
      return null;
    }
    return nextTokenSet;
  }

  @override
  Future<GoogleUserInfo?> fetchUserInfo(OAuthTokenSet tokenSet) async {
    return nextUserInfo;
  }

  @override
  Future<OAuthTokenSet> refreshActiveToken() async => nextTokenSet;

  @override
  Future<void> revokeAndSignOutAccount(String accountId) async {
    revoked = true;
    revokedAccountId = accountId;
    if (activeId == accountId) {
      activeId = null;
    }
    final error = revokeAndSignOutError;
    if (error != null) {
      throw error;
    }
  }

  @override
  Future<void> revokeAuthorization(String accountId) async {
    final error = revocationError;
    if (error != null) {
      throw error;
    }
    revoked = true;
    revokedAccountId = accountId;
  }

  @override
  Future<void> clearLocalSession({String? accountId}) async {
    final error = clearError;
    if (error != null) {
      throw error;
    }
    clearedAccountId = accountId;
    if (accountId == null || activeId == accountId) {
      activeId = null;
    }
  }

  @override
  Future<OAuthSignInResult> signIn({String? loginHint}) async {
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

Future<void> _insertAccount(
  AppDatabase database,
  String id,
  BusyProvider provider, {
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
          createdAtUtc: '2026-06-04T00:00:00.000Z',
          updatedAtUtc: '2026-06-04T00:00:00.000Z',
        ),
      );
}

Future<void> _insertNotification(AppDatabase database, String accountId) {
  return database
      .into(database.notificationSchedule)
      .insert(
        NotificationScheduleCompanion.insert(
          id: 'event|$accountId|event-1|5',
          accountId: accountId,
          sourceType: 'event',
          sourceId: 'event-1',
          scheduledAtUtc: DateTime.utc(2026, 6, 8, 9).millisecondsSinceEpoch,
          title: 'Private $accountId reminder',
          body: const Value('Private reminder details'),
          createdAtLocal: 0,
          updatedAtLocal: 0,
        ),
      );
}

class _FakeMicrosoftOAuthService extends MicrosoftOAuthService {
  _FakeMicrosoftOAuthService()
    : super(
        config: _config,
        httpClient: MockClient((request) async => http.Response('', 200)),
        tokenStore: InMemorySecretStore(),
        loopbackFlow: OAuthLoopbackFlow(),
      );

  final signOutAccountIds = <String>[];
  OAuthTokenSet nextTokenSet = _tokenSet();

  @override
  Future<MicrosoftOAuthSignInResult> signInWithMicrosoft() async {
    return MicrosoftOAuthSignInResult(
      accountId: 'microsoft:user-1',
      tokenSet: nextTokenSet,
      user: const MicrosoftTodoUserDto(
        id: 'user-1',
        displayName: 'Microsoft User',
        mail: 'user@example.test',
        rawJson: {'id': 'user-1'},
      ),
    );
  }

  @override
  Future<void> signOutAccount(String accountId) async {
    signOutAccountIds.add(accountId);
  }
}

const _config = BuildConfig(
  googleOAuthClientId: 'client-id',
  googleOAuthClientSecret: '',
  googleApiBaseUrl: 'https://www.googleapis.com',
  oauthAuthorizationEndpoint: 'https://accounts.google.com/o/oauth2/v2/auth',
  oauthTokenEndpoint: 'https://oauth2.googleapis.com/token',
  oauthRevocationEndpoint: 'https://oauth2.googleapis.com/revoke',
);

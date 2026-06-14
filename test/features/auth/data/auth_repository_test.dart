import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:busymax/src/config/build_config.dart';
import 'package:busymax/src/db/app_database.dart';
import 'package:busymax/src/features/auth/data/auth_repository.dart';
import 'package:busymax/src/google_tasks/api/google_tasks_api_surface.dart';
import 'package:busymax/src/google_tasks/oauth/oauth_loopback_flow.dart';
import 'package:busymax/src/google_tasks/oauth/oauth_models.dart';
import 'package:busymax/src/google_tasks/oauth/oauth_service.dart';
import 'package:busymax/src/google_tasks/oauth/oauth_token_store.dart';
import 'package:busymax/src/microsoft_todo/oauth/microsoft_oauth_service.dart';
import 'package:busymax/src/task_providers/task_provider.dart';

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

  test('sign-in without required write scope revokes and fails', () async {
    oAuth.nextTokenSet = _tokenSet(scopes: {googleTasksReadOnlyScope});

    await expectLater(repository.signIn(), throwsA(isA<OAuthException>()));

    expect(oAuth.revoked, isTrue);
    expect(oAuth.revokedAccountId, 'account-1');
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
      await _insertAccount(database, 'account-1', TaskProvider.google);
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

  test('revokeAndSignOut marks account signed out', () async {
    await repository.signIn();

    await repository.revokeAndSignOut();

    final account = await database.select(database.accounts).getSingle();
    expect(account.authState, 'signed_out');
    expect(oAuth.revoked, isTrue);
    expect(oAuth.revokedAccountId, 'account-1');
  });

  test('signOut marks account signed out without revoking', () async {
    await repository.signIn();

    await repository.signOut();

    final account = await database.select(database.accounts).getSingle();
    expect(account.authState, 'signed_out');
    expect(oAuth.signedOut, isTrue);
    expect(oAuth.signedOutAccountId, 'account-1');
    expect(oAuth.revoked, isFalse);
  });

  test('signOut Google account does not sign out Microsoft account', () async {
    final microsoftOAuth = _FakeMicrosoftOAuthService();
    repository = AuthRepository(
      oAuth: oAuth,
      database: database,
      microsoftOAuth: microsoftOAuth,
      nowUtc: () => DateTime.utc(2026, 6, 4),
    );
    await _insertAccount(database, 'google-a', TaskProvider.google);
    await _insertAccount(database, 'microsoft:m', TaskProvider.microsoft);

    await repository.signOut(accountId: 'google-a');

    final accounts = await database.select(database.accounts).get();
    expect(oAuth.signedOutAccountId, 'google-a');
    expect(microsoftOAuth.signOutAccountIds, isEmpty);
    expect(_authState(accounts, 'google-a'), 'signed_out');
    expect(_authState(accounts, 'microsoft:m'), 'signed_in');
  });

  test('signOut Microsoft account does not sign out Google account', () async {
    final microsoftOAuth = _FakeMicrosoftOAuthService();
    repository = AuthRepository(
      oAuth: oAuth,
      database: database,
      microsoftOAuth: microsoftOAuth,
      nowUtc: () => DateTime.utc(2026, 6, 4),
    );
    await _insertAccount(database, 'google:g', TaskProvider.google);
    await _insertAccount(database, 'microsoft:m', TaskProvider.microsoft);

    await repository.signOut(accountId: 'microsoft:m');

    final accounts = await database.select(database.accounts).get();
    expect(oAuth.signedOut, isFalse);
    expect(microsoftOAuth.signOutAccountIds, ['microsoft:m']);
    expect(_authState(accounts, 'google:g'), 'signed_in');
    expect(_authState(accounts, 'microsoft:m'), 'signed_out');
  });

  test('deleteLocalAccountData removes account row and local tokens', () async {
    await repository.signIn();

    await repository.deleteLocalAccountData(accountId: 'account-1');

    expect(await database.select(database.accounts).get(), isEmpty);
    expect(oAuth.signedOutAccountId, 'account-1');
  });

  test('deleteLocalAccountData removes only target account row', () async {
    await repository.signIn();
    await database
        .into(database.accounts)
        .insert(
          AccountsCompanion.insert(
            id: 'account-2',
            createdAtUtc: '2026-06-04T00:00:00.000Z',
            updatedAtUtc: '2026-06-04T00:00:00.000Z',
            authState: const Value('signed_in'),
          ),
        );

    await repository.deleteLocalAccountData(accountId: 'account-1');

    final accounts = await database.select(database.accounts).get();
    expect(accounts.map((account) => account.id), ['account-2']);
    expect(oAuth.signedOutAccountId, 'account-1');
  });

  test('revoking Google account does not sign out Microsoft account', () async {
    final microsoftOAuth = _FakeMicrosoftOAuthService();
    repository = AuthRepository(
      oAuth: oAuth,
      database: database,
      microsoftOAuth: microsoftOAuth,
      nowUtc: () => DateTime.utc(2026, 6, 4),
    );
    await _insertAccount(database, 'google-a', TaskProvider.google);
    await _insertAccount(database, 'google-b', TaskProvider.google);
    await _insertAccount(database, 'microsoft:m', TaskProvider.microsoft);

    await repository.revokeAndSignOut(accountId: 'google-a');

    final accounts = await database.select(database.accounts).get();
    expect(oAuth.revokedAccountId, 'google-a');
    expect(microsoftOAuth.signOutAccountIds, isEmpty);
    expect(_authState(accounts, 'google-a'), 'signed_out');
    expect(_authState(accounts, 'google-b'), 'signed_in');
    expect(_authState(accounts, 'microsoft:m'), 'signed_in');
  });

  test('revoking Microsoft account does not revoke Google account', () async {
    final microsoftOAuth = _FakeMicrosoftOAuthService();
    repository = AuthRepository(
      oAuth: oAuth,
      database: database,
      microsoftOAuth: microsoftOAuth,
      nowUtc: () => DateTime.utc(2026, 6, 4),
    );
    await _insertAccount(database, 'google:g', TaskProvider.google);
    await _insertAccount(database, 'microsoft:m', TaskProvider.microsoft);

    await repository.revokeAndSignOut(accountId: 'microsoft:m');

    final accounts = await database.select(database.accounts).get();
    expect(oAuth.revoked, isFalse);
    expect(microsoftOAuth.signOutAccountIds, ['microsoft:m']);
    expect(_authState(accounts, 'google:g'), 'signed_in');
    expect(_authState(accounts, 'microsoft:m'), 'signed_out');
  });
}

class FakeOAuthGateway implements OAuthGateway {
  var revoked = false;
  var signedOut = false;
  String? revokedAccountId;
  String? signedOutAccountId;
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
  Future<void> signOutAccount(String accountId) async {
    signedOut = true;
    signedOutAccountId = accountId;
    if (activeId == accountId) {
      activeId = null;
    }
  }

  @override
  Future<void> signOut() async {
    signedOut = true;
    activeId = null;
  }

  @override
  Future<void> revokeAndSignOutAccount(String accountId) async {
    revoked = true;
    revokedAccountId = accountId;
    if (activeId == accountId) {
      activeId = null;
    }
  }

  @override
  Future<void> revokeAndSignOut() async {
    revoked = true;
    activeId = null;
  }

  @override
  Future<void> clearLocalSession({String? accountId}) async {
    activeId = null;
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
  TaskProvider provider,
) {
  return database
      .into(database.accounts)
      .insert(
        AccountsCompanion.insert(
          id: id,
          provider: Value(provider.storageValue),
          authState: const Value('signed_in'),
          createdAtUtc: '2026-06-04T00:00:00.000Z',
          updatedAtUtc: '2026-06-04T00:00:00.000Z',
        ),
      );
}

String _authState(List<Account> accounts, String id) {
  return accounts.singleWhere((account) => account.id == id).authState;
}

class _FakeMicrosoftOAuthService extends MicrosoftOAuthService {
  _FakeMicrosoftOAuthService()
    : super(
        config: _config,
        httpClient: MockClient((request) async => http.Response('', 200)),
        tokenStore: InMemoryOAuthTokenStore(),
        loopbackFlow: OAuthLoopbackFlow(),
      );

  final signOutAccountIds = <String>[];

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

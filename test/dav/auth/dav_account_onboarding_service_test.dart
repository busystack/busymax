import 'dart:convert';

import 'package:busymax/src/core/secrets/secret_store.dart';
import 'package:busymax/src/dav/auth/dav_account_onboarding_service.dart';
import 'package:busymax/src/dav/auth/nextcloud_login_flow_v2.dart';
import 'package:busymax/src/dav/dav_errors.dart';
import 'package:busymax/src/dav/discovery/dav_discovery_models.dart';
import 'package:busymax/src/db/app_database.dart';
import 'package:busymax/src/providers/busy_provider.dart';
import 'package:busymax/src/providers/provider_capabilities.dart';
import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  late AppDatabase database;
  late InMemorySecretStore secrets;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    secrets = InMemorySecretStore();
  });

  tearDown(() => database.close());

  test(
    'Apple discovery completes before trimmed opaque secret is stored',
    () async {
      var discoveryCalled = false;
      final service = DavAccountOnboardingService(
        database: database,
        secretStore: secrets,
        nextcloudLoginFlow: _unusedLoginFlow(),
        idFactory: () => 'apple-id',
        discover:
            ({
              required accountId,
              required provider,
              required accountAuthority,
              required credential,
              cancellationToken,
            }) async {
              discoveryCalled = true;
              expect(await secrets.readCredential(accountId), isNull);
              expect(provider, BusyProvider.appleICloud);
              expect(accountAuthority, Uri.parse('https://caldav.icloud.com'));
              expect(credential.username, 'Person@Example.test');
              expect(credential.password, 'abcd-efgh-ijkl-mnop');
              return _discovery(accountId, provider, accountAuthority);
            },
      );

      final result = await service.connectAppleICloud(
        email: '  Person@Example.test  ',
        appSpecificPassword: '  abcd-efgh-ijkl-mnop  ',
      );

      expect(discoveryCalled, isTrue);
      expect(result.accountId, 'apple_icloud:apple-id');
      final stored = await secrets.readCredential(result.accountId);
      expect(stored, isA<AppleICloudSecretRecord>());
      final apple = stored! as AppleICloudSecretRecord;
      expect(apple.username, 'Person@Example.test');
      expect(apple.appSpecificPassword, 'abcd-efgh-ijkl-mnop');
      expect(apple.toString(), isNot(contains(apple.appSpecificPassword)));
      final account = await database.select(database.accounts).getSingle();
      expect(account.provider, 'apple_icloud');
      expect(account.providerAccountId, 'person@example.test');
      expect(account.tasksEnabled, isFalse);
      expect(account.authState, 'signed_in');
      expect(
        await database.select(database.davAccountServices).get(),
        hasLength(1),
      );
    },
  );

  test('failed discovery leaves no account or credential', () async {
    final service = DavAccountOnboardingService(
      database: database,
      secretStore: secrets,
      nextcloudLoginFlow: _unusedLoginFlow(),
      idFactory: () => 'failed-id',
      discover:
          ({
            required accountId,
            required provider,
            required accountAuthority,
            required credential,
            cancellationToken,
          }) async => throw const DavException(
            kind: DavErrorKind.authentication,
            code: 'DavAuthRejected',
            safeMessage: 'Credential rejected.',
          ),
    );

    await expectLater(
      service.connectAppleICloud(
        email: 'person@example.test',
        appSpecificPassword: 'bad-password',
      ),
      throwsA(isA<DavException>()),
    );
    expect(await database.select(database.accounts).get(), isEmpty);
    expect(await secrets.readCredential('apple_icloud:failed-id'), isNull);
  });

  test(
    'Nextcloud stores returned canonical server, login name, and app password',
    () async {
      var requests = 0;
      final flow = NextcloudLoginFlowV2(
        client: MockClient((request) async {
          requests += 1;
          if (requests == 1) {
            return http.Response(
              jsonEncode({
                'poll': {
                  'token': 'temporary-token',
                  'endpoint':
                      'https://entered.example.test/cloud/login/v2/poll',
                },
                'login':
                    'https://entered.example.test/cloud/login/v2/flow/browser',
              }),
              200,
            );
          }
          return http.Response(
            jsonEncode({
              'server': 'https://canonical.example.test/cloud/',
              'loginName': 'canonical-user',
              'appPassword': 'generated-app-password',
            }),
            200,
          );
        }),
        browserLauncher: (_) async => true,
        delay: (_) async {},
      );
      final service = DavAccountOnboardingService(
        database: database,
        secretStore: secrets,
        nextcloudLoginFlow: flow,
        idFactory: () => 'nextcloud-id',
        discover:
            ({
              required accountId,
              required provider,
              required accountAuthority,
              required credential,
              cancellationToken,
            }) async {
              expect(provider, BusyProvider.nextcloud);
              expect(
                accountAuthority,
                Uri.parse('https://canonical.example.test/cloud'),
              );
              expect(credential.username, 'canonical-user');
              expect(credential.password, 'generated-app-password');
              expect(await secrets.readCredential(accountId), isNull);
              return _discovery(accountId, provider, accountAuthority);
            },
      );

      final result = await service.connectNextcloud(
        enteredServer: 'entered.example.test/cloud',
      );

      final account = await database.select(database.accounts).getSingle();
      expect(account.authority, 'https://canonical.example.test/cloud');
      expect(account.providerAccountId, 'canonical-user');
      expect(account.tasksEnabled, isTrue);
      final credential =
          await secrets.readCredential(result.accountId)
              as NextcloudSecretRecord;
      expect(
        credential.canonicalServer,
        Uri.parse('https://canonical.example.test/cloud'),
      );
      expect(credential.loginName, 'canonical-user');
      expect(credential.appPassword, 'generated-app-password');
      expect(credential.toString(), isNot(contains('generated-app-password')));
    },
  );

  test(
    'Nextcloud reconnect replaces only the verified credential and preserves local state',
    () async {
      final initialService = DavAccountOnboardingService(
        database: database,
        secretStore: secrets,
        nextcloudLoginFlow: _successfulLoginFlow(appPassword: 'old-password'),
        idFactory: () => 'nextcloud-id',
        discover:
            ({
              required accountId,
              required provider,
              required accountAuthority,
              required credential,
              cancellationToken,
            }) async => _discovery(accountId, provider, accountAuthority),
      );
      final connected = await initialService.connectNextcloud(
        enteredServer: 'cloud.example.test',
      );
      await _insertNextcloudLocalState(database, connected.accountId);
      await _markPendingAuthenticationBlocked(database);

      var verifiedBeforeReplacement = false;
      final reconnectService = DavAccountOnboardingService(
        database: database,
        secretStore: secrets,
        nextcloudLoginFlow: _successfulLoginFlow(appPassword: 'new-password'),
        discover:
            ({
              required accountId,
              required provider,
              required accountAuthority,
              required credential,
              cancellationToken,
            }) async {
              final stored =
                  await secrets.readCredential(accountId)
                      as NextcloudSecretRecord;
              expect(stored.appPassword, 'old-password');
              expect(credential.password, 'new-password');
              verifiedBeforeReplacement = true;
              return _discovery(accountId, provider, accountAuthority);
            },
      );

      final reconnected = await reconnectService.reconnectNextcloud(
        accountId: connected.accountId,
        enteredServer: 'cloud.example.test',
      );

      expect(verifiedBeforeReplacement, isTrue);
      expect(reconnected.accountId, connected.accountId);
      final stored =
          await secrets.readCredential(connected.accountId)
              as NextcloudSecretRecord;
      expect(stored.appPassword, 'new-password');
      expect(await database.select(database.accounts).get(), hasLength(1));
      expect(await database.select(database.taskLists).get(), hasLength(1));
      final pending = await database.select(database.pendingOps).getSingle();
      expect(pending.state, 'pending');
      expect(pending.retryClassification, 'credential_replaced');
      expect(pending.attemptCount, 0);
      expect(pending.nextAttemptAtUtc, isNull);
      expect(pending.lastErrorCode, isNull);
      expect(
        (await database.select(database.accounts).getSingle()).authState,
        'signed_in',
      );
    },
  );

  test(
    'Nextcloud reconnect rejects a different identity without touching local state',
    () async {
      final initialService = DavAccountOnboardingService(
        database: database,
        secretStore: secrets,
        nextcloudLoginFlow: _successfulLoginFlow(appPassword: 'old-password'),
        idFactory: () => 'nextcloud-id',
        discover:
            ({
              required accountId,
              required provider,
              required accountAuthority,
              required credential,
              cancellationToken,
            }) async => _discovery(accountId, provider, accountAuthority),
      );
      final connected = await initialService.connectNextcloud(
        enteredServer: 'cloud.example.test',
      );
      await _insertNextcloudLocalState(database, connected.accountId);
      await _markPendingAuthenticationBlocked(database);
      var discoveryCalled = false;
      final reconnectService = DavAccountOnboardingService(
        database: database,
        secretStore: secrets,
        nextcloudLoginFlow: _successfulLoginFlow(
          loginName: 'different-user',
          appPassword: 'untrusted-password',
        ),
        discover:
            ({
              required accountId,
              required provider,
              required accountAuthority,
              required credential,
              cancellationToken,
            }) async {
              discoveryCalled = true;
              return _discovery(accountId, provider, accountAuthority);
            },
      );

      await expectLater(
        reconnectService.reconnectNextcloud(
          accountId: connected.accountId,
          enteredServer: 'cloud.example.test',
        ),
        throwsA(
          isA<DavException>().having(
            (error) => error.code,
            'code',
            'DavNextcloudReconnectIdentityMismatch',
          ),
        ),
      );

      expect(discoveryCalled, isFalse);
      final stored =
          await secrets.readCredential(connected.accountId)
              as NextcloudSecretRecord;
      expect(stored.appPassword, 'old-password');
      expect(await database.select(database.accounts).get(), hasLength(1));
      expect(await database.select(database.taskLists).get(), hasLength(1));
      final pending = await database.select(database.pendingOps).getSingle();
      expect(pending.state, 'auth_blocked');
      expect(pending.nextAttemptAtUtc, startsWith('9999-12-31'));
    },
  );

  test(
    'failed Nextcloud reconnect discovery preserves the old credential and local state',
    () async {
      final initialService = DavAccountOnboardingService(
        database: database,
        secretStore: secrets,
        nextcloudLoginFlow: _successfulLoginFlow(appPassword: 'old-password'),
        idFactory: () => 'nextcloud-id',
        discover:
            ({
              required accountId,
              required provider,
              required accountAuthority,
              required credential,
              cancellationToken,
            }) async => _discovery(accountId, provider, accountAuthority),
      );
      final connected = await initialService.connectNextcloud(
        enteredServer: 'cloud.example.test',
      );
      await _insertNextcloudLocalState(database, connected.accountId);
      await _markPendingAuthenticationBlocked(database);
      final reconnectService = DavAccountOnboardingService(
        database: database,
        secretStore: secrets,
        nextcloudLoginFlow: _successfulLoginFlow(appPassword: 'new-password'),
        discover:
            ({
              required accountId,
              required provider,
              required accountAuthority,
              required credential,
              cancellationToken,
            }) async => throw const DavException(
              kind: DavErrorKind.authentication,
              code: 'DavAuthRejected',
              safeMessage: 'Credential rejected.',
            ),
      );

      await expectLater(
        reconnectService.reconnectNextcloud(
          accountId: connected.accountId,
          enteredServer: 'cloud.example.test',
        ),
        throwsA(
          isA<DavException>().having(
            (error) => error.code,
            'code',
            'DavAuthRejected',
          ),
        ),
      );

      final stored =
          await secrets.readCredential(connected.accountId)
              as NextcloudSecretRecord;
      expect(stored.appPassword, 'old-password');
      expect(await database.select(database.accounts).get(), hasLength(1));
      expect(await database.select(database.taskLists).get(), hasLength(1));
      final pending = await database.select(database.pendingOps).getSingle();
      expect(pending.state, 'auth_blocked');
      expect(pending.nextAttemptAtUtc, startsWith('9999-12-31'));
    },
  );

  test('Apple replacement validates before replacing the old secret', () async {
    var discoveryCount = 0;
    late String accountId;
    final service = DavAccountOnboardingService(
      database: database,
      secretStore: secrets,
      nextcloudLoginFlow: _unusedLoginFlow(),
      idFactory: () => 'apple-id',
      discover:
          ({
            required String accountId,
            required provider,
            required accountAuthority,
            required credential,
            cancellationToken,
          }) async {
            discoveryCount += 1;
            if (discoveryCount == 2) {
              final stillOld = await secrets.readCredential(accountId);
              expect(
                (stillOld! as AppleICloudSecretRecord).appSpecificPassword,
                'old-password',
              );
              expect(credential.password, 'new-password-with-hyphens');
            }
            return _discovery(accountId, provider, accountAuthority);
          },
    );
    accountId = (await service.connectAppleICloud(
      email: 'person@example.test',
      appSpecificPassword: 'old-password',
    )).accountId;
    await database
        .into(database.pendingOps)
        .insert(
          PendingOpsCompanion.insert(
            id: 'apple-auth-blocked',
            accountId: accountId,
            provider: const Value('apple_icloud'),
            entityType: 'event',
            operation: 'dav_update',
            operationType: const Value('dav.update'),
            requestJson: '{}',
            state: const Value('auth_blocked'),
            retryClassification: const Value('authentication'),
            attemptCount: const Value(1),
            nextAttemptAtUtc: const Value('9999-12-31T23:59:59.999Z'),
            lastErrorCode: const Value('DavCredentialsRevoked'),
            createdAtUtc: '2026-08-08T12:00:00.000Z',
            updatedAtUtc: '2026-08-08T12:00:00.000Z',
          ),
        );

    await service.replaceAppleAppSpecificPassword(
      accountId: accountId,
      appSpecificPassword: '  new-password-with-hyphens  ',
    );

    final replacement =
        await secrets.readCredential(accountId) as AppleICloudSecretRecord;
    expect(replacement.appSpecificPassword, 'new-password-with-hyphens');
    final pending = await database.select(database.pendingOps).getSingle();
    expect(pending.state, 'pending');
    expect(pending.nextAttemptAtUtc, isNull);
  });

  test(
    'Apple local removal deletes the credential, cache, and pending work',
    () async {
      final service = DavAccountOnboardingService(
        database: database,
        secretStore: secrets,
        nextcloudLoginFlow: _unusedLoginFlow(),
        idFactory: () => 'apple-remove-id',
        discover:
            ({
              required accountId,
              required provider,
              required accountAuthority,
              required credential,
              cancellationToken,
            }) async => _discovery(accountId, provider, accountAuthority),
      );
      final connected = await service.connectAppleICloud(
        email: 'person@example.test',
        appSpecificPassword: 'app-specific-password',
      );
      await database
          .into(database.pendingOps)
          .insert(
            PendingOpsCompanion.insert(
              id: 'apple-pending-removal',
              accountId: connected.accountId,
              provider: const Value('apple_icloud'),
              entityType: 'event',
              operation: 'dav_create',
              operationType: const Value('dav.create'),
              requestJson: '{}',
              createdAtUtc: '2026-08-08T12:00:00.000Z',
              updatedAtUtc: '2026-08-08T12:00:00.000Z',
            ),
          );

      final result = await service.removeAccount(connected.accountId);

      expect(result.remoteRevocationAttempted, isFalse);
      expect(await secrets.readCredential(connected.accountId), isNull);
      expect(await secrets.readActiveAccountId(), isNull);
      expect(await database.select(database.accounts).get(), isEmpty);
      expect(await database.select(database.davAccountServices).get(), isEmpty);
      expect(await database.select(database.pendingOps).get(), isEmpty);
    },
  );

  test(
    'remote revocation failure never prevents complete local removal',
    () async {
      final service = DavAccountOnboardingService(
        database: database,
        secretStore: secrets,
        nextcloudLoginFlow: _successfulLoginFlow(),
        idFactory: () => 'nextcloud-id',
        discover:
            ({
              required accountId,
              required provider,
              required accountAuthority,
              required credential,
              cancellationToken,
            }) async => _discovery(accountId, provider, accountAuthority),
        nextcloudCredentialRevoker:
            ({required accountId, required credential}) async {
              throw const DavException(
                kind: DavErrorKind.network,
                code: 'RevocationOffline',
                safeMessage: 'Offline.',
              );
            },
      );
      final connected = await service.connectNextcloud(
        enteredServer: 'cloud.example.test',
      );
      await database
          .into(database.pendingOps)
          .insert(
            PendingOpsCompanion.insert(
              id: 'pending',
              accountId: connected.accountId,
              provider: const Value('nextcloud'),
              entityType: 'event',
              operation: 'dav_create',
              operationType: const Value('dav.create'),
              requestJson: '{}',
              createdAtUtc: '2026-08-08T12:00:00.000Z',
              updatedAtUtc: '2026-08-08T12:00:00.000Z',
            ),
          );

      final result = await service.removeAccount(connected.accountId);

      expect(result.remoteRevocationAttempted, isTrue);
      expect(result.remoteRevocationSucceeded, isFalse);
      expect(result.remoteFailureCode, 'RevocationOffline');
      expect(await secrets.readCredential(connected.accountId), isNull);
      expect(await secrets.readActiveAccountId(), isNull);
      expect(await database.select(database.accounts).get(), isEmpty);
      expect(await database.select(database.davAccountServices).get(), isEmpty);
      expect(await database.select(database.pendingOps).get(), isEmpty);
    },
  );
}

NextcloudLoginFlowV2 _unusedLoginFlow() => NextcloudLoginFlowV2(
  client: MockClient((_) async => http.Response('', 500)),
  browserLauncher: (_) async => false,
);

NextcloudLoginFlowV2 _successfulLoginFlow({
  String server = 'https://cloud.example.test/',
  String loginName = 'alex',
  String appPassword = 'app-password',
}) {
  var call = 0;
  return NextcloudLoginFlowV2(
    client: MockClient((_) async {
      call += 1;
      return call == 1
          ? http.Response(
              jsonEncode({
                'poll': {
                  'token': 'token',
                  'endpoint': 'https://cloud.example.test/login/v2/poll',
                },
                'login': 'https://cloud.example.test/login/v2/flow/browser',
              }),
              200,
            )
          : http.Response(
              jsonEncode({
                'server': server,
                'loginName': loginName,
                'appPassword': appPassword,
              }),
              200,
            );
    }),
    browserLauncher: (_) async => true,
    delay: (_) async {},
  );
}

Future<void> _insertNextcloudLocalState(
  AppDatabase database,
  String accountId,
) async {
  const now = '2026-08-08T12:00:00.000Z';
  await database
      .into(database.taskLists)
      .insert(
        TaskListsCompanion.insert(
          accountId: accountId,
          id: 'cached-list',
          title: 'Cached list',
          rawJson: '{}',
          createdLocalAtUtc: now,
          updatedLocalAtUtc: now,
        ),
      );
  await database
      .into(database.pendingOps)
      .insert(
        PendingOpsCompanion.insert(
          id: 'pending-reconnect',
          accountId: accountId,
          provider: const Value('nextcloud'),
          entityType: 'task',
          operation: 'dav_update',
          operationType: const Value('dav.update'),
          requestJson: '{}',
          createdAtUtc: now,
          updatedAtUtc: now,
        ),
      );
}

Future<void> _markPendingAuthenticationBlocked(AppDatabase database) async {
  await database
      .update(database.pendingOps)
      .write(
        const PendingOpsCompanion(
          state: Value('auth_blocked'),
          retryClassification: Value('authentication'),
          attemptCount: Value(1),
          nextAttemptAtUtc: Value('9999-12-31T23:59:59.999Z'),
          lastErrorCode: Value('DavCredentialsRevoked'),
          lastErrorMessage: Value('The DAV credential was rejected.'),
        ),
      );
}

DavDiscoveryResult _discovery(
  String accountId,
  BusyProvider provider,
  Uri authority,
) => DavDiscoveryResult(
  accountId: accountId,
  provider: provider,
  service: DavServiceDiscovery(
    canonicalServiceUri: authority,
    canonicalOrigin: authority.replace(path: ''),
    principalHref: authority.resolve('/principals/user/'),
    calendarHomeHref: authority.resolve('/calendars/user/'),
    calendarUserAddresses: const [],
    scheduleInboxHref: null,
    scheduleOutboxHref: null,
    capabilities: const AccountServiceCapabilities(
      hasPrincipal: true,
      hasCalendarHome: true,
    ),
    discoveredAtUtc: DateTime.utc(2026, 8, 8, 12),
    lastValidatedAtUtc: DateTime.utc(2026, 8, 8, 12),
    providerProfileVersion: 1,
  ),
  collections: const [],
);

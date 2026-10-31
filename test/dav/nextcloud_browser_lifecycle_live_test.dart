import 'dart:io';
import 'dart:convert';

import 'package:busymax/src/core/auth/authorization_persistence.dart';
import 'package:busymax/src/core/secrets/secret_store.dart';
import 'package:busymax/src/dav/auth/dav_account_onboarding_service.dart';
import 'package:busymax/src/dav/auth/nextcloud_app_password_revoker.dart';
import 'package:busymax/src/dav/auth/nextcloud_login_flow_v2.dart';
import 'package:busymax/src/dav/dav_errors.dart';
import 'package:busymax/src/dav/dav_provider_profile.dart';
import 'package:busymax/src/dav/discovery/dav_discovery_service.dart';
import 'package:busymax/src/dav/http/dav_http_transport.dart';
import 'package:busymax/src/dav/trust/nextcloud_certificate.dart';
import 'package:busymax/src/dav/trust/nextcloud_http_client_factory.dart';
import 'package:busymax/src/dav/trust/nextcloud_trust_policy.dart';
import 'package:busymax/src/db/app_database.dart';
import 'package:busymax/src/features/accounts/data/accounts_repository.dart';
import 'package:busymax/src/providers/account_authority.dart';
import 'package:busymax/src/providers/busy_provider.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import '../support/persistence_test_directory.dart';

/// External browser driver must use ordinary certificate validation and its
/// own explicitly provisioned profile. No HttpOverrides or mocked DAV responses.
void main() {
  final enabled =
      Platform.environment['BUSYMAX_NEXTCLOUD_BROWSER_LIFECYCLE'] == '1';
  test(
    'browser authorization, reconnect, revalidation, restart and captured removal',
    () async {
      String env(String key) =>
          Platform.environment['BUSYMAX_NEXTCLOUD_LOGIN_LIVE_$key']!;
      final authority = Uri.parse(
        normalizeNextcloudServerAuthority(env('URL')),
      );
      final material = NextcloudCertificate.import(
        File(env('TLS_CERT')).readAsBytesSync(),
      );
      final mode = env('TRUST_MODE') == 'private_ca'
          ? NextcloudTrustMode.privateCa
          : NextcloudTrustMode.pinnedLeaf;
      final directory = await createPersistenceTestDirectory(
        'busymax-browser-lifecycle-',
      );
      final path = File('${directory.path}/accounts.sqlite');
      var database = AppDatabase(NativeDatabase(path));
      final secrets = InMemorySecretStore();
      final factory = NextcloudHttpClientFactory(requireNetwork: () async {});
      final unused = http.Client();
      addTearDown(() async {
        factory.close();
        unused.close();
        await database.close();
        await directory.delete(recursive: true);
      });
      var browserLaunches = 0, reviews = 0;
      final flow = NextcloudLoginFlowV2(
        client: unused,
        pollInterval: const Duration(milliseconds: 100),
        browserLauncher: (uri) async {
          browserLaunches++;
          final result = await Process.run(
            Platform.environment['BUSYMAX_NEXTCLOUD_BROWSER_DRIVER']!,
            [uri.toString()],
          );
          if (result.exitCode != 0) {
            throw StateError(
              'Disposable browser authorization failed: ${result.stderr}',
            );
          }
          return true;
        },
      );
      NextcloudTrustPolicy approve(
        String owner, {
        String generation = 'browser-fixture',
      }) => NextcloudTrustPolicy.approve(
        owner: owner,
        installation: authority,
        mode: mode,
        certificates: material,
        generation: generation,
      );
      DavAccountOnboardingService service() {
        final persistence = AuthorizationPersistence(
          database: database,
          secrets: secrets,
        );
        persistence.observeNextcloudInvalidation(factory.invalidate);
        final accounts = AccountsRepository(database: database);
        return DavAccountOnboardingService(
          database: database,
          secretStore: secrets,
          authorizationPersistence: persistence,
          nextcloudClients: factory,
          nextcloudLoginFlow: flow,
          discover: ({
            required accountId,
            required provider,
            required accountAuthority,
            required credential,
            cancellationToken,
          }) => throw StateError('Unscoped Nextcloud discovery is forbidden.'),
          nextcloudDiscovery: (record, generation, existing) =>
              ({
                required accountId,
                required provider,
                required accountAuthority,
                required credential,
                cancellationToken,
              }) async {
                final client = factory.create(
                  owner: accountId,
                  authority: accountAuthority,
                  policy: record.trustPolicy,
                );
                final profile = davProviderProfile(
                  BusyProvider.nextcloud,
                  nextcloudServer: accountAuthority,
                );
                try {
                  return await DavDiscoveryService(
                    transport: DavHttpTransport(
                      client: client,
                      profile: profile,
                      accountAuthority: accountAuthority,
                    ),
                    profile: profile,
                    accountAuthority: accountAuthority,
                    accountId: accountId,
                    credential: credential,
                  ).discover(
                    correlationId: 'real-browser-discovery',
                    cancellationToken: cancellationToken,
                  );
                } finally {
                  client.close();
                }
              },
          nextcloudCredentialRevoker:
              ({required accountId, required credential}) async {
                expect(await accounts.accountById(accountId), isNull);
                expect(await secrets.readCredential(accountId), isNull);
                final client = factory.create(
                  owner: accountId,
                  authority: credential.canonicalServer,
                  policy: credential.trustPolicy,
                );
                final profile = davProviderProfile(
                  BusyProvider.nextcloud,
                  nextcloudServer: credential.canonicalServer,
                );
                try {
                  await NextcloudAppPasswordRevoker(
                    transport: DavHttpTransport(
                      client: client,
                      profile: profile,
                      accountAuthority: authority,
                    ),
                  ).revoke(
                    accountId: accountId,
                    credential: credential,
                    correlationId: 'real-browser-post-removal-revoke',
                  );
                } finally {
                  client.close();
                }
              },
        );
      }

      var onboarding = service();
      await expectLater(
        onboarding.connectNextcloud(
          enteredServer: authority.toString(),
          reviewCertificate: (_, _) async => null,
        ),
        throwsA(isA<NextcloudCertificateException>()),
      );
      expect(browserLaunches, 0);
      expect(await database.select(database.accounts).get(), isEmpty);
      final cancelled = DavCancellationToken();
      await expectLater(
        onboarding.connectNextcloud(
          enteredServer: authority.toString(),
          cancellationToken: cancelled,
          reviewCertificate: (_, owner) async {
            cancelled.cancel();
            return approve(owner);
          },
        ),
        throwsA(
          isA<DavException>().having(
            (e) => e.kind,
            'kind',
            DavErrorKind.cancelled,
          ),
        ),
      );
      expect(browserLaunches, 0);
      expect(await database.select(database.accounts).get(), isEmpty);
      final connected = await onboarding.connectNextcloud(
        enteredServer: authority.toString(),
        reviewCertificate: (challenge, owner) async {
          reviews++;
          expect(challenge.observed, isNotNull);
          expect(await database.select(database.accounts).get(), isEmpty);
          return approve(owner);
        },
      );
      expect(reviews, 1);
      expect(browserLaunches, 1);
      final id = connected.accountId;
      final accepted =
          await secrets.readCredential(id) as NextcloudSecretRecord;
      expect(accepted.trustPolicy!.owner, id);
      await onboarding.revalidateAccount(id);
      await onboarding.reconnectNextcloud(
        accountId: id,
        enteredServer: authority.toString(),
        reviewCertificate: (_, _) =>
            throw StateError('Reconnect must retain approved policy.'),
      );
      expect(browserLaunches, 2);
      final persistence = AuthorizationPersistence(
        database: database,
        secrets: secrets,
      );
      final generation = await persistence.generation(id);
      await expectLater(
        onboarding.replaceNextcloudTrust(
          accountId: id,
          expectedGeneration: generation - 1,
          policy: approve(id),
        ),
        throwsA(
          isA<DavException>().having(
            (e) => e.code,
            'code',
            'NextcloudStaleCertificateApproval',
          ),
        ),
      );
      await expectLater(
        onboarding.replaceNextcloudTrust(
          accountId: id,
          expectedGeneration: generation,
          policy: null,
        ),
        throwsA(isA<NextcloudCertificateException>()),
      );
      expect(
        (await secrets.readCredential(
          id,
        ) as NextcloudSecretRecord).trustPolicy!.mode,
        mode,
      );
      await onboarding.replaceNextcloudTrust(
        accountId: id,
        expectedGeneration: generation,
        policy: approve(id, generation: 'explicit-reviewed-replacement'),
      );
      final controlDriver =
          Platform.environment['BUSYMAX_NEXTCLOUD_FIXTURE_CONTROL']!;
      Future<Map<String, dynamic>> control(
        String action, [
        String? certificate,
      ]) async {
        final result = await Process.run('python3', [
          controlDriver,
          action,
          if (certificate != null) certificate,
        ]);
        expect(result.exitCode, 0);
        return (jsonDecode(result.stdout as String) as Map)
            .cast<String, dynamic>();
      }

      final cached = await database.select(database.davCollections).get();
      await control(
        'change',
        mode == NextcloudTrustMode.privateCa ? 'renewed' : 'self-renewed',
      );
      if (mode == NextcloudTrustMode.privateCa) {
        await onboarding.revalidateAccount(id);
        expect(
          (await secrets.readCredential(id) as NextcloudSecretRecord)
              .trustPolicy!
              .certificates
              .single
              .fingerprint,
          material.single.fingerprint,
        );
      } else {
        final before = (await control('counts'))['appRequests'];
        await expectLater(
          onboarding.revalidateAccount(id),
          throwsA(
            isA<NextcloudCertificateException>().having(
              (e) => e.failure,
              'failure',
              NextcloudCertificateFailure.pinMismatch,
            ),
          ),
        );
        expect((await control('counts'))['appRequests'], before);
        expect(
          (await database.select(database.davCollections).get()).map(
            (c) => c.id,
          ),
          cached.map((c) => c.id),
        );
        final next = NextcloudCertificate.import(
          File('${File(env('TLS_CERT')).parent.path}/self-renewed.pem')
              .readAsBytesSync(),
        );
        await onboarding.replaceNextcloudTrust(
          accountId: id,
          expectedGeneration: await persistence.generation(id),
          policy: NextcloudTrustPolicy.approve(
            owner: id,
            installation: authority,
            mode: mode,
            certificates: next,
            generation: 'explicit-new-leaf-review',
          ),
        );
      }
      final durable = (await secrets.readCredential(
        id,
      ) as NextcloudSecretRecord).trustPolicy!.toJson();
      await control('offline');
      await expectLater(
        onboarding.revalidateAccount(id),
        throwsA(
          isA<DavException>().having(
            (e) => e.kind,
            'kind',
            DavErrorKind.network,
          ),
        ),
      );
      expect(
        (await secrets.readCredential(id) as NextcloudSecretRecord).trustPolicy!
            .toJson(),
        durable,
      );
      await control('online');
      await onboarding.revalidateAccount(id);
      await database.close();
      database = AppDatabase(NativeDatabase(path));
      onboarding = service();
      await AuthorizationPersistence(
        database: database,
        secrets: secrets,
      ).recover();
      await onboarding.revalidateAccount(id);
      final captured =
          await secrets.readCredential(id) as NextcloudSecretRecord;
      final removed = await onboarding.removeAccount(id);
      expect(removed.remoteRevocationAttempted, isTrue);
      expect(removed.remoteRevocationSucceeded, isTrue);
      final client = factory.create(
        owner: id,
        authority: authority,
        policy: captured.trustPolicy,
      );
      addTearDown(client.close);
      final profile = davProviderProfile(
        BusyProvider.nextcloud,
        nextcloudServer: authority,
      );
      await expectLater(
        DavDiscoveryService(
          transport: DavHttpTransport(
            client: client,
            profile: profile,
            accountAuthority: authority,
          ),
          profile: profile,
          accountAuthority: authority,
          accountId: id,
          credential: DavBasicCredential(
            username: captured.loginName,
            password: captured.appPassword,
          ),
        ).discover(correlationId: 'verify-real-browser-revocation'),
        throwsA(
          isA<DavException>().having(
            (e) => e.kind,
            'kind',
            DavErrorKind.authentication,
          ),
        ),
      );
      expect(await database.select(database.accounts).get(), isEmpty);
      expect(
        await database.select(database.authorizationCommits).get(),
        isEmpty,
      );
    },
    skip: enabled ? false : 'Needs an isolated HTTPS Nextcloud server and a normally validating external browser driver.',
    timeout: const Timeout(Duration(minutes: 4)),
  );
}

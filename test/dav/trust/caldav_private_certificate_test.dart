import 'dart:convert';
import 'dart:io';

import 'package:busymax/src/app/app_bootstrap.dart';
import 'package:busymax/src/core/auth/authorization_persistence.dart';
import 'package:busymax/src/core/secrets/secret_store.dart';
import 'package:busymax/src/dav/auth/dav_account_onboarding_service.dart';
import 'package:busymax/src/dav/auth/nextcloud_login_flow_v2.dart';
import 'package:busymax/src/dav/discovery/dav_discovery_models.dart';
import 'package:busymax/src/dav/trust/nextcloud_certificate.dart';
import 'package:busymax/src/dav/trust/nextcloud_http_client_factory.dart';
import 'package:busymax/src/dav/trust/nextcloud_trust_policy.dart';
import 'package:busymax/src/db/app_database.dart';
import 'package:busymax/src/features/connectivity/network_connectivity_service.dart';
import 'package:busymax/src/providers/busy_provider.dart';
import 'package:busymax/src/providers/provider_capabilities.dart';
import 'package:busymax/src/ui/common/nextcloud_certificate_review.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import '../../helpers/nextcloud_tls_fixture.dart';

void main() {
  late NextcloudTlsFixture tls;
  setUpAll(() async => tls = await NextcloudTlsFixture.create());
  tearDownAll(() => tls.dispose());

  for (final mode in [
    NextcloudTrustMode.privateCa,
    NextcloudTrustMode.pinnedLeaf,
  ]) {
    test(
      '$mode: approval, durable policy, password replacement, revocation and removal',
      () async {
        final directory = await Directory.systemTemp.createTemp(
          'caldav-trust-db-',
        );
        addTearDown(() => directory.delete(recursive: true));
        var db = AppDatabase(
          NativeDatabase(File('${directory.path}/account.sqlite')),
        );
        final secrets = InMemorySecretStore();
        final factory = NextcloudHttpClientFactory(requireNetwork: () async {});
        addTearDown(factory.close);
        var requests = 0;
        final server = await tls.serve(
          mode == NextcloudTrustMode.privateCa ? 'leaf' : 'self',
        );
        addTearDown(() => server.close(force: true));
        final authority = Uri.parse(
          'https://localhost:${server.port}/dav%20service/',
        );
        var expectedPassword = ' untouched password ';
        server.listen((request) async {
          requests++;
          expect(
            request.headers.value('authorization'),
            'Basic ${base64Encode(utf8.encode('user:$expectedPassword'))}',
          );
          await request.drain<void>();
          request.response.write('authenticated');
          await request.response.close();
        });
        DavAccountOnboardingService service() => DavAccountOnboardingService(
          database: db,
          secretStore: secrets,
          nextcloudLoginFlow: NextcloudLoginFlowV2(client: http.Client()),
          discover: ({
            required accountId,
            required provider,
            required accountAuthority,
            required credential,
            cancellationToken,
          }) async => throw StateError('Unscoped discovery forbidden'),
          caldavDiscovery: (record, generation, existing) =>
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
                  caldavService: true,
                );
                try {
                  final response = await client.get(
                    accountAuthority,
                    headers: {
                      'authorization':
                          'Basic ${base64Encode(utf8.encode('${credential.username}:${credential.password}'))}',
                    },
                  );
                  expect(response.statusCode, 200);
                } finally {
                  client.close();
                }
                return _inventory(accountId, accountAuthority);
              },
        );
        var reviews = 0;
        final result = await service().connectCalDav(
          serverUrl: '$authority',
          username: 'user',
          password: expectedPassword,
          reviewCertificate: (challenge, owner) async {
            reviews++;
            expect(
              requests,
              0,
              reason: 'No HTTP or credentials before approval',
            );
            if (mode == NextcloudTrustMode.pinnedLeaf) {
              return reviewNextcloudCertificate(challenge, owner, (data) async {
                expect(data.canApprove, isTrue);
                expect(
                  data.certificates.single.fingerprint,
                  challenge.observed!.fingerprint,
                );
                return CertificateReviewAction.approve;
              }, caldavService: true);
            }
            return NextcloudTrustPolicy.approve(
              owner: owner,
              installation: authority,
              mode: mode,
              caldavService: true,
              certificates: NextcloudCertificate.import(
                File(tls.path('ca.pem')).readAsBytesSync(),
              ),
              generation: 'approved-ca',
            );
          },
        );
        expect(reviews, 1);
        expect(requests, 1);
        final id = result.accountId;
        var persistence = AuthorizationPersistence(
          database: db,
          secrets: secrets,
        );
        final record =
            await persistence.readCurrentCredential(id) as CalDavSecretRecord;
        record.trustPolicy!.requireScope(id, authority);
        expect(record.trustPolicy!.installation, authority);
        expect(
          () => record.trustPolicy!.requireScope('unrelated', authority),
          throwsFormatException,
        );
        expect(
          () => record.trustPolicy!.requireScope(
            id,
            authority.replace(path: '/dav service'),
          ),
          throwsFormatException,
        );
        final serialized =
            jsonDecode(jsonEncode(record.toJson())) as Map<String, dynamic>;
        await secrets.saveCredential(id, SecretRecord.fromJson(serialized));
        await db.close();
        db = AppDatabase(
          NativeDatabase(File('${directory.path}/account.sqlite')),
        );
        addTearDown(() => db.close());
        persistence = AuthorizationPersistence(database: db, secrets: secrets);
        await service().revalidateAccount(id);
        expect(requests, 2);
        expectedPassword = 'replacement';
        await service().replaceCalDavPassword(
          accountId: id,
          password: expectedPassword,
        );
        expect(
          (await persistence.readCurrentCredential(
            id,
          ) as CalDavSecretRecord).trustPolicy!.generation,
          record.trustPolicy!.generation,
        );
        final network = NetworkConnectivityMonitor.withoutPlatformObservation();
        final providers = ProviderContainer(
          overrides: [
            databaseProvider.overrideWithValue(db),
            secretStoreProvider.overrideWithValue(secrets),
            authorizationPersistenceProvider.overrideWithValue(persistence),
            networkConnectivityMonitorProvider.overrideWithValue(network),
          ],
        );
        addTearDown(providers.dispose);
        final client = providers.read(davAccountHttpClientProvider(id));
        expect(
          (await client.get(
            authority,
            headers: {
              'authorization':
                  'Basic ${base64Encode(utf8.encode('user:$expectedPassword'))}',
            },
          )).statusCode,
          200,
        );
        final before = requests;
        await expectLater(
          client.get(authority.replace(host: '127.0.0.1')),
          throwsA(anything),
        );
        expect(requests, before);
        await service().replaceCalDavTrust(
          accountId: id,
          expectedGeneration: await persistence.generation(id),
          policy: null,
        );
        await expectLater(
          client.get(authority),
          throwsA(isA<NextcloudCertificateException>()),
        );
        expect(requests, before);
        expect(
          (await persistence.readCurrentCredential(
            id,
          ) as CalDavSecretRecord).trustPolicy,
          isNull,
        );
        await expectLater(
          service().replaceCalDavTrust(
            accountId: id,
            expectedGeneration: 1,
            policy: record.trustPolicy,
          ),
          throwsA(anything),
        );
        await service().removeAccount(id);
        expect(await secrets.readCredential(id), isNull);
        expect(await db.select(db.accounts).get(), isEmpty);
      },
    );
  }

  test('rejection and foreign approval never persist a credential or dispatch HTTP', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final secrets = InMemorySecretStore();
    final factory = NextcloudHttpClientFactory(requireNetwork: () async {});
    addTearDown(factory.close);
    final server = await tls.serve('self');
    addTearDown(() => server.close(force: true));
    var requests = 0;
    server.listen((request) async {
      requests++;
      await request.response.close();
    });
    final authority = Uri.parse('https://localhost:${server.port}/');
    final service = DavAccountOnboardingService(
      database: db,
      secretStore: secrets,
      nextcloudLoginFlow: NextcloudLoginFlowV2(client: http.Client()),
      discover: ({
        required accountId,
        required provider,
        required accountAuthority,
        required credential,
        cancellationToken,
      }) async => throw StateError('unscoped'),
      caldavDiscovery: (record, generation, existing) =>
          ({
            required accountId,
            required provider,
            required accountAuthority,
            required credential,
            cancellationToken,
          }) async {
            final client = factory.create(
              owner: accountId,
              authority: authority,
              policy: record.trustPolicy,
              caldavService: true,
            );
            try {
              await client.get(authority);
            } finally {
              client.close();
            }
            return _inventory(accountId, authority);
          },
    );
    await expectLater(
      service.connectCalDav(
        serverUrl: '$authority',
        username: 'user',
        password: 'secret',
        reviewCertificate: (challenge, owner) => reviewNextcloudCertificate(
          challenge,
          owner,
          (_) async => CertificateReviewAction.reject,
          caldavService: true,
        ),
      ),
      throwsA(isA<NextcloudCertificateException>()),
    );
    await expectLater(
      service.connectCalDav(
        serverUrl: '$authority',
        username: 'user',
        password: 'secret',
        reviewCertificate: (challenge, owner) async =>
            NextcloudTrustPolicy.approve(
              owner: 'another account',
              installation: authority,
              caldavService: true,
              mode: NextcloudTrustMode.pinnedLeaf,
              certificates: [challenge.observed!],
              generation: 'foreign',
            ),
      ),
      throwsFormatException,
    );
    expect(requests, 0);
    expect(await db.select(db.accounts).get(), isEmpty);
  });

  test('certificate approval cannot cross provider boundaries', () {
    final authority = Uri.parse('https://localhost/dav/');
    final factory = NextcloudHttpClientFactory(requireNetwork: () async {});
    addTearDown(factory.close);
    for (final caldav in [true, false]) {
      final policy = NextcloudTrustPolicy.approve(
        owner: 'account',
        installation: authority,
        caldavService: caldav,
        mode: NextcloudTrustMode.privateCa,
        certificates: NextcloudCertificate.import(
          File(tls.path('ca.pem')).readAsBytesSync(),
        ),
        generation: 'provider-scope',
      );
      expect(
        () => factory.create(
          owner: 'account',
          authority: authority,
          policy: policy,
          caldavService: !caldav,
        ),
        throwsA(isA<NextcloudCertificateException>()),
      );
    }
  });

  test('malformed configured CalDAV policy remains explicit across secure-record decoding', () {
    final record = CalDavSecretRecord(
      serviceAuthority: Uri.parse('https://localhost/dav/'),
      username: 'user',
      password: 'password',
    ).toJson()..['trustPolicy'] = null;
    final decoded = SecretRecord.fromJson(record) as CalDavSecretRecord;
    expect(decoded.trustPolicy!.mode, NextcloudTrustMode.invalidConfiguration);
    expect(
      () => decoded.trustPolicy!.requireScope('user', decoded.serviceAuthority),
      throwsFormatException,
    );
  });
}

DavDiscoveryResult _inventory(String id, Uri authority) => DavDiscoveryResult(
  accountId: id,
  provider: BusyProvider.caldav,
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
    discoveredAtUtc: DateTime.now().toUtc(),
    lastValidatedAtUtc: DateTime.now().toUtc(),
    providerProfileVersion: 1,
  ),
  collections: const [],
);

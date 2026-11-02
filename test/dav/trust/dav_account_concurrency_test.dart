import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:busymax/src/core/auth/authorization_persistence.dart';
import 'package:busymax/src/core/secrets/secret_store.dart';
import 'package:busymax/src/dav/http/dav_account_http_client.dart';
import 'package:busymax/src/dav/http/dav_http_transport.dart';
import 'package:busymax/src/dav/dav_errors.dart';
import 'package:busymax/src/dav/dav_provider_profile.dart';
import 'package:busymax/src/providers/busy_provider.dart';
import 'package:busymax/src/dav/trust/nextcloud_certificate.dart';
import 'package:busymax/src/dav/trust/nextcloud_http_client_factory.dart';
import 'package:busymax/src/dav/trust/nextcloud_trust_policy.dart';
import 'package:busymax/src/db/app_database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import '../../helpers/nextcloud_tls_fixture.dart';

void main() {
  late NextcloudTlsFixture tls;
  late AppDatabase db;
  late InMemorySecretStore secrets;
  late AuthorizationPersistence persistence;
  late NextcloudHttpClientFactory factory;
  late HttpServer server;
  late Uri endpoint;
  final clients = <DavAccountHttpClient>[];
  final requests = <HttpRequest>[];
  late Future<void> Function(HttpRequest) handle;
  late Completer<void> arrived;
  var target = 1;

  NextcloudSecretRecord record(String owner, [String password = 'synthetic']) =>
      NextcloudSecretRecord(
        canonicalServer: endpoint,
        loginName: 'fixture',
        appPassword: password,
        trustPolicy: NextcloudTrustPolicy.approve(
          owner: owner,
          installation: endpoint,
          mode: NextcloudTrustMode.pinnedLeaf,
          certificates: [
            NextcloudCertificate.import(
              File(tls.path('self.pem')).readAsBytesSync(),
            ).single,
          ],
          generation: 'fixture',
        ),
      );
  DavAccountHttpClient client(
    String id, {
    Duration lifetime = const Duration(minutes: 2),
    Duration acquisitionTimeout = const Duration(minutes: 2),
  }) {
    final value = DavAccountHttpClient(
      accountId: id,
      persistence: persistence,
      maximumLifetime: lifetime,
      acquisitionTimeout: acquisitionTimeout,
      createClient: (credential) {
        final value = credential as NextcloudSecretRecord;
        return factory.create(
          owner: id,
          authority: value.canonicalServer,
          policy: value.trustPolicy,
        );
      },
    );
    clients.add(value);
    return value;
  }

  setUpAll(() async => tls = await NextcloudTlsFixture.create());
  tearDownAll(() => tls.dispose());
  setUp(() async {
    db = AppDatabase.memoryForTests();
    secrets = InMemorySecretStore();
    persistence = AuthorizationPersistence(database: db, secrets: secrets);
    factory = NextcloudHttpClientFactory(requireNetwork: () async {});
    server = await tls.serve('self');
    endpoint = Uri.parse('https://localhost:${server.port}/nextcloud');
    requests.clear();
    target = 1;
    arrived = Completer<void>();
    handle = (request) async {
      request.response.write('ok');
      await request.response.close();
    };
    server.listen((request) async {
      requests.add(request);
      if (requests.length == target && !arrived.isCompleted) arrived.complete();
      try {
        await request.drain<void>();
        await handle(request);
      } on Object {
        /* client termination */
      }
    });
    await secrets.saveCredential('one', record('one'));
    await secrets.saveCredential('two', record('two'));
  });
  tearDown(() async {
    for (final value in clients) {
      value.close();
    }
    clients.clear();
    factory.close();
    await server.close(force: true);
    await db.close();
  });

  test(
    'four requests overlap for one account before any response is released',
    () async {
      final release = Completer<void>();
      target = 4;
      handle = (request) async {
        await release.future;
        request.response.write('ok');
        await request.response.close();
      };
      final scoped = client('one');
      final operations = [for (var i = 0; i < 4; i++) scoped.get(endpoint)];
      await arrived.future.timeout(const Duration(seconds: 5));
      expect(requests, hasLength(4));
      release.complete();
      expect(
        (await Future.wait(operations)).map((r) => r.body),
        everyElement('ok'),
      );
    },
  );

  test('a waiting account writer does not block another account', () async {
    final release = Completer<void>();
    handle = (request) async {
      if (request.uri.query == 'slow') await release.future;
      request.response.write('ok');
      await request.response.close();
    };
    final slow = client('one').get(endpoint.replace(query: 'slow'));
    await arrived.future;
    var written = false;
    final writer = persistence.run('one', () async {
      written = true;
    });
    expect((await client('two').get(endpoint)).body, 'ok');
    expect(written, false);
    release.complete();
    await slow;
    await writer;
    expect(written, true);
  });

  test('replacement drains old transmission and rejects stale credentials before send', () async {
    final release = Completer<void>();
    handle = (request) async {
      await release.future;
      request.response.write('ok');
      await request.response.close();
    };
    final scoped = client('one');
    final first = scoped.get(endpoint);
    await arrived.future;
    final writer = persistence.run('one', () async {
      factory.invalidate('one');
      await secrets.saveCredential('one', record('one', 'replacement'));
      await persistence.invalidate('one');
    });
    release.complete();
    await first;
    await writer;
    await expectLater(
      scoped.get(
        endpoint,
        headers: {
          'authorization':
              'Basic ${base64Encode(utf8.encode('fixture:synthetic'))}',
        },
      ),
      throwsA(isA<SecretStoreException>()),
    );
    expect(requests, hasLength(1));
    expect(
      (await scoped.get(
        endpoint,
        headers: {
          'authorization':
              'Basic ${base64Encode(utf8.encode('fixture:replacement'))}',
        },
      )).statusCode,
      200,
    );
    expect(requests, hasLength(2));
  });

  test(
    'same-secret policy replacement rejects a stale action before transmission',
    () async {
      await persistence.run('one', () => persistence.invalidate('one'));
      await expectLater(
        client('one').post(
          endpoint,
          headers: {davAuthorizationGenerationHeader: '0'},
          body: 'mutation',
        ),
        throwsA(isA<SecretStoreException>()),
      );
      expect(requests, isEmpty);
      expect(
        (await client('one').get(
          endpoint,
          headers: {davAuthorizationGenerationHeader: '1'},
        )).statusCode,
        200,
      );
      expect(
        requests.single.headers.value(davAuthorizationGenerationHeader),
        isNull,
      );
    },
  );

  test(
    'pin replacement cannot reuse a socket accepted by the old generation',
    () async {
      final scoped = client('one');
      expect((await scoped.get(endpoint)).statusCode, 200);
      final port = server.port;
      await server.close(force: true);
      server = await tls.serve('self-renewed', port: port);
      var renewedRequests = 0;
      server.listen((request) async {
        renewedRequests++;
        request.response.write('renewed');
        await request.response.close();
      });
      // The previous leaf rejects the renewed server before any HTTP.
      await expectLater(
        scoped.get(endpoint),
        throwsA(isA<NextcloudCertificateException>()),
      );
      expect(renewedRequests, 0);
      await persistence.run('one', () async {
        factory.invalidate('one');
        await secrets.saveCredential(
          'one',
          NextcloudSecretRecord(
            canonicalServer: endpoint,
            loginName: 'fixture',
            appPassword: 'synthetic',
            trustPolicy: NextcloudTrustPolicy.approve(
              owner: 'one',
              installation: endpoint,
              mode: NextcloudTrustMode.pinnedLeaf,
              certificates: [
                NextcloudCertificate.import(
                  File(tls.path('self-renewed.pem')).readAsBytesSync(),
                ).single,
              ],
              generation: 'renewed',
            ),
          ),
        );
        await persistence.invalidate('one');
      });
      expect((await scoped.get(endpoint)).body, 'renewed');
      expect(renewedRequests, 1);
    },
  );

  for (final mode in ['abandoned', 'cancelled', 'disposed', 'stalled']) {
    test('$mode response releases removal lease without replay', () async {
      final hold = Completer<void>();
      handle = (request) async {
        request.response.write('first');
        await request.response.flush();
        await hold.future;
      };
      final scoped = client('one', lifetime: const Duration(milliseconds: 250));
      final response = await scoped.send(http.Request('GET', endpoint));
      Future<void>? consumption;
      if (mode == 'cancelled') {
        final subscription = response.stream.listen((_) {});
        await subscription.cancel();
      } else if (mode == 'disposed') {
        scoped.close();
        consumption = expectLater(
          response.stream.drain<void>(),
          throwsA(isA<http.RequestAbortedException>()),
        );
      } else if (mode == 'stalled') {
        consumption = expectLater(
          response.stream.drain<void>(),
          throwsA(isA<TimeoutException>()),
        );
      }
      await persistence
          .run('one', () async {
            await secrets.deleteCredential('one');
            await persistence.invalidate('one');
          })
          .timeout(const Duration(seconds: 3));
      if (mode == 'abandoned') {
        await expectLater(
          response.stream.drain<void>(),
          throwsA(isA<TimeoutException>()),
        );
      }
      await consumption;
      await expectLater(
        scoped.get(endpoint),
        throwsA(
          anyOf(isA<SecretStoreException>(), isA<http.ClientException>()),
        ),
      );
      expect(requests, hasLength(1));
      hold.complete();
    });
  }

  test(
    'queued authorization leaves a fresh active TLS response budget',
    () async {
      final entered = Completer<void>();
      final release = Completer<void>();
      final writer = persistence.run('one', () async {
        entered.complete();
        await release.future;
      });
      await entered.future;
      handle = (request) async {
        await Future<void>.delayed(const Duration(milliseconds: 200));
        request.response.write('slow response');
        await request.response.close();
      };
      final scoped = client('one', lifetime: const Duration(milliseconds: 500));
      final pending = scoped.get(endpoint);
      await Future<void>.delayed(const Duration(milliseconds: 700));
      expect(requests, isEmpty);
      release.complete();
      await writer;
      expect((await pending).body, 'slow response');
      expect(requests, hasLength(1));
    },
  );

  test(
    'expired authorization acquisition cannot transmit after writer release',
    () async {
      final entered = Completer<void>();
      final release = Completer<void>();
      final writer = persistence.run('one', () async {
        entered.complete();
        await release.future;
      });
      await entered.future;
      final scoped = client(
        'one',
        acquisitionTimeout: const Duration(milliseconds: 75),
      );
      await expectLater(
        scoped.post(endpoint, body: 'mutation'),
        throwsA(isA<TimeoutException>()),
      );
      release.complete();
      await writer;
      await persistence.run('one', () async {});
      expect(requests, isEmpty);
    },
  );

  test(
    'DAV operation deadline terminates a leased TLS mutation without replay',
    () async {
      final release = Completer<void>();
      handle = (request) async {
        await release.future;
        request.response.write('late response');
        await request.response.close();
      };
      final transport = DavHttpTransport(
        client: client('one'),
        profile: davProviderProfile(
          BusyProvider.nextcloud,
          nextcloudServer: endpoint,
        ),
        accountAuthority: endpoint,
        limits: const DavTransportLimits(
          operationTimeout: Duration(milliseconds: 250),
        ),
      );
      try {
        await expectLater(
          transport.send(
            DavRequest(
              method: 'MOVE',
              uri: endpoint,
              accountId: 'one',
              correlationId: 'fixture',
            ),
            credential: DavBasicCredential(
              username: 'fixture',
              password: 'synthetic',
            ),
          ),
          throwsA(
            isA<DavException>().having(
              (e) => e.kind,
              'operation deadline',
              DavErrorKind.timeout,
            ),
          ),
        );
        await persistence
            .run('one', () async {})
            .timeout(const Duration(seconds: 2));
        expect(requests, hasLength(1));
      } finally {
        release.complete();
      }
    },
  );

  test(
    'simultaneous dispatched failures release all readers without replay',
    () async {
      target = 4;
      handle = (request) async {
        await arrived.future;
        (await request.response.detachSocket()).destroy();
      };
      final scoped = client('one');
      await Future.wait([
        for (var i = 0; i < 4; i++)
          expectLater(
            scoped.post(endpoint, body: 'mutation'),
            throwsA(isA<http.ClientException>()),
          ),
      ]);
      await persistence
          .run('one', () async {})
          .timeout(const Duration(seconds: 2));
      expect(requests, hasLength(4));
    },
  );
}

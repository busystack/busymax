import 'package:busymax/src/core/auth/authorization_persistence.dart';
import 'package:busymax/src/db/app_database.dart';
import 'package:busymax/src/features/sync/account_sync_operations.dart';
import 'package:busymax/src/dav/trust/nextcloud_account_http_client.dart';
import 'package:busymax/src/dav/trust/nextcloud_leased_http_client.dart';
import 'package:drift/native.dart';
import 'package:asn1lib/asn1lib.dart';

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:busymax/src/core/http/terminating_http_client.dart';
import 'package:busymax/src/core/secrets/secret_store.dart';
import 'package:busymax/src/dav/dav_errors.dart';
import 'package:busymax/src/dav/dav_provider_profile.dart';
import 'package:busymax/src/dav/http/dav_http_transport.dart';
import 'package:busymax/src/dav/trust/nextcloud_certificate.dart';
import 'package:busymax/src/dav/trust/nextcloud_http_client_factory.dart';
import 'package:busymax/src/dav/trust/nextcloud_trust_policy.dart';
import 'package:busymax/src/providers/busy_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import '../../helpers/nextcloud_tls_fixture.dart';

void main() {
  late NextcloudTlsFixture fixture;
  late NextcloudHttpClientFactory factory;
  final servers = <HttpServer>[];
  late Uri endpoint;
  var received = 0;
  Future<HttpServer> serve(String cert, {int port = 0}) async {
    final server = await fixture.serve(cert, port: port);
    servers.add(server);
    endpoint = Uri.parse('https://localhost:${server.port}/nextcloud');
    server.listen((request) async {
      received++;
      await request.drain<void>();
      request.response.write('ok');
      await request.response.close();
    });
    return server;
  }

  NextcloudCertificate cert(String name) => NextcloudCertificate.import(
    File(fixture.path('$name.pem')).readAsBytesSync(),
  ).single;
  NextcloudTrustPolicy policy(
    NextcloudTrustMode mode,
    String name, {
    String owner = 'one',
  }) => NextcloudTrustPolicy.approve(
    owner: owner,
    installation: endpoint,
    mode: mode,
    certificates: [cert(name)],
    generation: 'synthetic-generation',
  );
  http.Client client([NextcloudTrustPolicy? policy, String owner = 'one']) =>
      factory.create(owner: owner, authority: endpoint, policy: policy);
  Matcher failure(NextcloudCertificateFailure value) =>
      isA<NextcloudCertificateException>().having(
        (error) => error.failure,
        'failure',
        value,
      );

  setUpAll(() async {
    fixture = await NextcloudTlsFixture.create();
  });
  tearDownAll(() => fixture.dispose());
  setUp(() {
    received = 0;
    factory = NextcloudHttpClientFactory(requireNetwork: () async {});
  });
  tearDown(() async {
    factory.close();
    for (final server in servers) {
      await server.close(force: true);
    }
    servers.clear();
  });

  test(
    'no approval delivers no HTTP headers or body, challenge is eligible',
    () async {
      await serve('self');
      await expectLater(
        client().post(
          endpoint,
          headers: {'authorization': 'synthetic'},
          body: 'test',
        ),
        throwsA(failure(NextcloudCertificateFailure.approvalRequired)),
      );
      expect(received, 0);
    },
  );
  test('approved exact self-signed leaf works with ordinary and terminating clients', () async {
    await serve('self');
    final accepted = client(policy(NextcloudTrustMode.pinnedLeaf, 'self'));
    expect((await accepted.get(endpoint)).body, 'ok');
    final terminate = Completer<void>();
    final response = await (accepted as TerminatingHttpClient).sendTerminating(
      http.Request('POST', endpoint)..body = 'synthetic',
      terminate: terminate.future,
      connectionTimeout: const Duration(seconds: 2),
    );
    await response.stream.drain<void>();
    terminate.complete();
    expect(received, 2);
  });
  test(
    'same-key renewed leaf and CA-signed replacement never bypass active pin',
    () async {
      var server = await serve('self');
      final pin = policy(NextcloudTrustMode.pinnedLeaf, 'self');
      expect((await client(pin).get(endpoint)).statusCode, 200);
      final port = server.port;
      await server.close(force: true);
      server = await serve('self-renewed', port: port);
      await expectLater(
        client(pin).put(endpoint, body: 'test'),
        throwsA(failure(NextcloudCertificateFailure.pinMismatch)),
      );
      await server.close(force: true);
      await serve('leaf', port: port);
      // This replacement validates normally when its CA is explicitly trusted.
      expect(
        (await client(policy(NextcloudTrustMode.privateCa, 'ca')).get(endpoint))
            .statusCode,
        200,
      );
      await expectLater(
        client(pin).get(endpoint),
        throwsA(failure(NextcloudCertificateFailure.pinMismatch)),
      );
      expect(received, 2);
    },
  );
  test('private CA permits leaf renewal; unapproved account on same origin stays rejected', () async {
    final server = await serve('leaf');
    final ca = policy(NextcloudTrustMode.privateCa, 'ca');
    expect((await client(ca).get(endpoint)).statusCode, 200);
    await expectLater(
      client(null, 'two').get(endpoint),
      throwsA(isA<NextcloudCertificateException>()),
    );
    final port = server.port;
    await server.close(force: true);
    await serve('renewed', port: port);
    expect((await client(ca).get(endpoint)).statusCode, 200);
    expect(received, 2);
  });
  test(
    'approval is bound to owner, exact host, port and installation',
    () async {
      await serve('self');
      final pin = policy(NextcloudTrustMode.pinnedLeaf, 'self');
      expect(
        () => client(pin, 'two'),
        throwsA(failure(NextcloudCertificateFailure.invalidPolicy)),
      );
      expect(
        () => factory.create(
          owner: 'one',
          authority: endpoint.replace(port: endpoint.port + 1),
          policy: pin,
        ),
        throwsA(failure(NextcloudCertificateFailure.invalidPolicy)),
      );
      expect(
        () => factory.create(
          owner: 'one',
          authority: endpoint.replace(path: '/other'),
          policy: pin,
        ),
        throwsA(failure(NextcloudCertificateFailure.invalidPolicy)),
      );
      await expectLater(
        client(pin).get(endpoint.replace(host: '127.0.0.1')),
        throwsA(isA<DavException>()),
      );
      await expectLater(
        client(pin).get(endpoint.replace(scheme: 'http')),
        throwsA(isA<DavException>()),
      );
      expect(received, 0);
    },
  );
  test('credential and versioned trust survive round trip; malformed policies fail closed', () async {
    await serve('self');
    final record = NextcloudSecretRecord(
      canonicalServer: endpoint,
      loginName: 'synthetic',
      appPassword: 'synthetic',
      trustPolicy: policy(NextcloudTrustMode.pinnedLeaf, 'self'),
    );
    final restored = SecretRecord.fromJson(
      jsonDecode(jsonEncode(record.toJson())) as Map<String, Object?>,
    ) as NextcloudSecretRecord;
    expect((await client(restored.trustPolicy).get(endpoint)).statusCode, 200);
    for (final broken in [
      null,
      {},
      {'version': 2},
      {...record.trustPolicy!.toJson(), 'certificates': []},
    ]) {
      final invalid = SecretRecord.fromJson({
        ...record.toJson(),
        'trustPolicy': broken,
      }) as NextcloudSecretRecord;
      expect(
        invalid.trustPolicy!.mode,
        NextcloudTrustMode.invalidConfiguration,
      );
      expect(
        () => client(invalid.trustPolicy),
        throwsA(failure(NextcloudCertificateFailure.invalidPolicy)),
      );
      final again =
          SecretRecord.fromJson(invalid.toJson()) as NextcloudSecretRecord;
      expect(again.toJson(), invalid.toJson());
    }
    expect(
      (SecretRecord.fromJson(
        NextcloudSecretRecord(
          canonicalServer: endpoint,
          loginName: 'old',
          appPassword: 'synthetic',
        ).toJson(),
      ) as NextcloudSecretRecord).trustPolicy,
      isNull,
    );
  });
  test('SAN-only identity: DNS, IP, wildcard and CN-only cases', () {
    expect(cert('self').matchesHost('localhost'), isTrue);
    expect(cert('self').matchesHost('127.0.0.1'), isTrue);
    expect(cert('self').matchesHost('::1'), isTrue);
    expect(cert('dns-ip').matchesHost('127.0.0.1'), isFalse);
    expect(cert('cn-only').matchesHost('localhost'), isFalse);
    expect(cert('wildcard').matchesHost('one.example.test'), isTrue);
    expect(cert('wildcard').matchesHost('two.one.example.test'), isFalse);
    expect(cert('wildcard').matchesHost('example.test'), isFalse);
  });
  test(
    'unprocessed critical extensions cannot be imported or bypass a stored pin',
    () async {
      await serve('critical');
      expect(
        () => policy(NextcloudTrustMode.pinnedLeaf, 'critical'),
        throwsFormatException,
      );
      expect(
        () => policy(NextcloudTrustMode.privateCa, 'critical-ca'),
        throwsFormatException,
      );
      await expectLater(
        client().get(endpoint),
        throwsA(failure(NextcloudCertificateFailure.ineligible)),
      );
      await serve('policy-leaf');
      // The maintained parser recognizes these extensions, but this boundary
      // does not implement their critical policy/constraint semantics.
      expect(
        () => policy(NextcloudTrustMode.privateCa, 'constraints-ca'),
        throwsFormatException,
      );
      expect(
        () => policy(NextcloudTrustMode.pinnedLeaf, 'policy-leaf'),
        throwsFormatException,
      );
      // Establish the upstream trust-anchor behavior using a real TLS socket.
      // Native acceptance alone cannot replace application eligibility checks.
      final socket = await SecureSocket.connect(
        endpoint.host,
        endpoint.port,
        context: SecurityContext(withTrustedRoots: false)
          ..setTrustedCertificates(fixture.path('policy-leaf.pem')),
      );
      socket.destroy();
      // A configured record with matching DER/hash still cannot bypass checks.
      final baseline = policy(NextcloudTrustMode.pinnedLeaf, 'self').toJson();
      final observed = cert('policy-leaf');
      final saved = NextcloudTrustPolicy.fromJson({
        ...baseline,
        'certificates': [
          {'der': base64.encode(observed.der), 'sha256': observed.fingerprint},
        ],
      });
      expect(
        () => client(saved),
        throwsA(failure(NextcloudCertificateFailure.ineligible)),
      );
      expect(received, 0);
    },
  );
  test('reject expired, wrong-host, CA leaf, malformed containers and private keys', () async {
    await serve('self');
    for (final name in ['expired', 'wrong', 'cn-only', 'ca']) {
      expect(
        () => policy(NextcloudTrustMode.pinnedLeaf, name),
        throwsFormatException,
      );
    }
    expect(
      () => policy(NextcloudTrustMode.privateCa, 'self'),
      throwsFormatException,
    );
    expect(
      () => policy(NextcloudTrustMode.privateCa, 'purpose-ca'),
      throwsFormatException,
    );
    expect(
      () => cert('self').validateTime(DateTime.utc(2000)),
      throwsFormatException,
    );
    for (final bytes in [
      <int>[],
      [1, 2, 3],
      List<int>.filled(65537, 1),
      File(fixture.path('server.key')).readAsBytesSync(),
    ]) {
      expect(() => NextcloudCertificate.import(bytes), throwsFormatException);
    }
    final ec = cert('ec');
    expect(
      () => ec.validateServer('localhost', selfSigned: true),
      returnsNormally,
    );
  });
  test(
    'rejected mutations remain TLS failures through shared DAV transport',
    () async {
      await serve('self');
      final transport = DavHttpTransport(
        client: client(),
        profile: davProviderProfile(
          BusyProvider.nextcloud,
          nextcloudServer: endpoint,
        ),
        accountAuthority: endpoint,
      );
      await expectLater(
        transport.send(
          DavRequest(
            method: 'PUT',
            uri: endpoint,
            accountId: 'one',
            correlationId: 'synthetic',
            bodyBytes: null,
          ),
          credential: DavBasicCredential(
            username: 'synthetic',
            password: 'synthetic',
          ),
        ),
        throwsA(failure(NextcloudCertificateFailure.approvalRequired)),
      );
      expect(received, 0);
    },
  );
  test(
    'invalidating one account closes its clients without closing another',
    () async {
      await serve('self');
      final one = client(policy(NextcloudTrustMode.pinnedLeaf, 'self'));
      final two = client(
        policy(NextcloudTrustMode.pinnedLeaf, 'self', owner: 'two'),
        'two',
      );
      factory.invalidate('one');
      await expectLater(
        one.get(endpoint),
        throwsA(isA<http.ClientException>()),
      );
      expect((await two.get(endpoint)).statusCode, 200);
    },
  );
  test(
    'certificate changed after observation cannot receive a request',
    () async {
      final server = await serve('self');
      final observed = await factory.observe(endpoint);
      final pin = NextcloudTrustPolicy.approve(
        owner: 'one',
        installation: endpoint,
        mode: NextcloudTrustMode.pinnedLeaf,
        certificates: [observed],
        generation: 'observed',
      );
      final port = server.port;
      await server.close(force: true);
      await serve('self-renewed', port: port);
      await expectLater(
        client(pin).post(endpoint, body: 'synthetic'),
        throwsA(failure(NextcloudCertificateFailure.pinMismatch)),
      );
      expect(received, 0);
    },
  );
  test('IP SAN works only with explicit IP endpoint approval', () async {
    await serve('self');
    endpoint = endpoint.replace(host: '127.0.0.1');
    expect(
      (await client(policy(NextcloudTrustMode.pinnedLeaf, 'self'))
              .get(endpoint))
          .statusCode,
      200,
    );
  });
  test(
    'expired stored pins and tampered self signatures fail before dispatch',
    () async {
      await serve('self');
      final valid = policy(NextcloudTrustMode.pinnedLeaf, 'self');
      final expired = cert('expired');
      final restored = NextcloudTrustPolicy.fromJson({
        ...valid.toJson(),
        'certificates': [
          {'der': base64.encode(expired.der), 'sha256': expired.fingerprint},
        ],
      });
      expect(
        () => client(restored),
        throwsA(failure(NextcloudCertificateFailure.expired)),
      );
      final bytes = cert('self').der.toList();
      bytes[bytes.length - 1] ^= 1;
      expect(
        () =>
            NextcloudCertificate.der(bytes)
                .validateServer('localhost', selfSigned: true),
        throwsFormatException,
      );
      // An otherwise correct RSA signature must not be accepted when the
      // certificate declares ECDSA. Re-sign modified TBS bytes using OpenSSL.
      final original =
          ASN1Parser(Uint8List.fromList(cert('self').der)).nextObject()
              as ASN1Sequence;
      final originalTbs = original.elements.first as ASN1Sequence;
      final algorithm = ASN1Sequence()
        ..add(ASN1ObjectIdentifier.fromComponents([1, 2, 840, 10045, 4, 3, 2]));
      final modifiedTbs = ASN1Sequence();
      for (var i = 0; i < originalTbs.elements.length; i++) {
        modifiedTbs.add(i == 2 ? algorithm : originalTbs.elements[i]);
      }
      await File(fixture.path('mismatched-tbs.der'))
          .writeAsBytes(modifiedTbs.encodedBytes);
      await fixture.openssl([
        'dgst',
        '-sha256',
        '-sign',
        'server.key',
        '-out',
        'mismatched-signature.bin',
        'mismatched-tbs.der',
      ]);
      final mismatched = ASN1Sequence()
        ..add(modifiedTbs)
        ..add(algorithm)
        ..add(
          ASN1BitString(
            await File(fixture.path('mismatched-signature.bin')).readAsBytes(),
          ),
        );
      expect(
        () =>
            NextcloudCertificate.der(mismatched.encodedBytes)
                .validateServer('localhost', selfSigned: true),
        throwsFormatException,
      );
      expect(received, 0);
    },
  );
  test('stalled handshakes terminate promptly', () async {
    final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final sockets = <Socket>[];
    final accepted = Completer<void>();
    server.listen((socket) {
      sockets.add(socket);
      socket.listen((_) {}, onError: (_) {});
      if (!accepted.isCompleted) accepted.complete();
    });
    endpoint = Uri.parse('https://localhost:${server.port}/nextcloud');
    final selected = client(
      policy(NextcloudTrustMode.pinnedLeaf, 'self'),
    ) as TerminatingHttpClient;
    final terminate = Completer<void>();
    final request = selected.sendTerminating(
      http.Request('PUT', endpoint),
      terminate: terminate.future,
      connectionTimeout: const Duration(seconds: 10),
    );
    final rejected = expectLater(request, throwsA(anything));
    await accepted.future.timeout(const Duration(seconds: 2));
    terminate.complete();
    await rejected.timeout(const Duration(seconds: 2));
    for (final socket in sockets) {
      socket.destroy();
    }
    await server.close();
  });
  test(
    'actual post-dispatch TLS socket loss retains unknown mutation outcome',
    () async {
      final server = await fixture.serve('self');
      servers.add(server);
      endpoint = Uri.parse('https://localhost:${server.port}/nextcloud');
      server.listen((request) async {
        received++;
        await request.drain<void>();
        final socket = await request.response.detachSocket(writeHeaders: false);
        socket.destroy();
      });
      final transport = DavHttpTransport(
        client: client(policy(NextcloudTrustMode.pinnedLeaf, 'self')),
        profile: davProviderProfile(
          BusyProvider.nextcloud,
          nextcloudServer: endpoint,
        ),
        accountAuthority: endpoint,
      );
      await expectLater(
        transport.send(
          DavRequest(
            method: 'PUT',
            uri: endpoint,
            accountId: 'one',
            correlationId: 'synthetic',
          ),
          credential: DavBasicCredential(
            username: 'synthetic',
            password: 'synthetic',
          ),
        ),
        throwsA(
          isA<DavException>().having(
            (e) => e.kind,
            'kind',
            DavErrorKind.unknownOutcome,
          ),
        ),
      );
      expect(received, 1);
    },
  );
  test(
    'saved-account authorization lease lasts through response consumption',
    () async {
      await serve('self');
      final database = AppDatabase(NativeDatabase.memory());
      final secrets = InMemorySecretStore();
      final persistence = AuthorizationPersistence(
        database: database,
        secrets: secrets,
      );
      await secrets.saveCredential(
        'one',
        NextcloudSecretRecord(
          canonicalServer: endpoint,
          loginName: 'synthetic',
          appPassword: 'synthetic',
          trustPolicy: policy(NextcloudTrustMode.pinnedLeaf, 'self'),
        ),
      );
      final standard = http.Client();
      final scoped = NextcloudAccountHttpClient(
        accountId: 'one',
        persistence: persistence,
        factory: factory,
        standardClient: standard,
      );
      try {
        final abort = Completer<void>();
        final response = await scoped.send(
          http.AbortableRequest('GET', endpoint, abortTrigger: abort.future),
        );
        var changed = false;
        final replacement = persistence.run('one', () async {
          changed = true;
        });
        await Future<void>.delayed(const Duration(milliseconds: 10));
        expect(changed, isFalse);
        await response.stream.drain<void>();
        abort.complete();
        await replacement;
        expect(changed, isTrue);
      } finally {
        standard.close();
        await database.close();
      }
    },
  );
  test('contacts generation lease drains reads before replacement', () async {
    await serve('self');
    final coordinator = AccountSyncCoordinator();
    var generation = 1;
    final leased = NextcloudLeasedHttpClient(
      delegate: client(policy(NextcloudTrustMode.pinnedLeaf, 'self')),
      runLease: (work) => coordinator.run('contacts:one', work),
      validate: () async {
        if (generation != 1) throw http.ClientException('stale binding');
      },
    );
    try {
      final abort = Completer<void>();
      final response = await leased.send(
        http.AbortableRequest('GET', endpoint, abortTrigger: abort.future),
      );
      final replacement = coordinator.run('contacts:one', () async {
        generation = 2;
      });
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(generation, 1);
      await response.stream.drain<void>();
      abort.complete();
      await replacement;
      await expectLater(
        leased.get(endpoint),
        throwsA(isA<http.ClientException>()),
      );
      expect(received, 1);
    } finally {
      leased.close();
      await coordinator.dispose();
    }
  });
  test(
    'cancellation while waiting for a contacts lease cannot dispatch later',
    () async {
      await serve('self');
      final coordinator = AccountSyncCoordinator();
      final entered = Completer<void>();
      final release = Completer<void>();
      final holding = coordinator.run('contacts:one', () async {
        entered.complete();
        await release.future;
      });
      await entered.future;
      final leased = NextcloudLeasedHttpClient(
        delegate: client(policy(NextcloudTrustMode.pinnedLeaf, 'self')),
        runLease: (work) => coordinator.run('contacts:one', work),
        validate: () async {},
      );
      final terminate = Completer<void>();
      final rejected = expectLater(
        leased.send(
          http.AbortableRequest(
            'PUT',
            endpoint,
            abortTrigger: terminate.future,
          ),
        ),
        throwsA(isA<http.RequestAbortedException>()),
      );
      terminate.complete();
      await Future<void>.delayed(Duration.zero);
      release.complete();
      await holding;
      await rejected;
      expect(received, 0);
      leased.close();
      await coordinator.dispose();
    },
  );
  for (final entry in {
    'wrong-leaf': NextcloudCertificateFailure.hostnameMismatch,
    'cn-only-leaf': NextcloudCertificateFailure.hostnameMismatch,
    'expired-leaf': NextcloudCertificateFailure.expired,
    'future-leaf': NextcloudCertificateFailure.notYetValid,
    'self': NextcloudCertificateFailure.verificationFailed,
  }.entries) {
    test(
      'real CA handshake rejects ${entry.key} before HTTP dispatch',
      () async {
        await serve(entry.key);
        final ca = policy(NextcloudTrustMode.privateCa, 'ca');
        await expectLater(
          client(ca).post(
            endpoint,
            headers: {'authorization': 'synthetic'},
            body: 'synthetic',
          ),
          throwsA(failure(entry.value)),
        );
        expect(received, 0);
      },
    );
  }
  test(
    'certificate import bounds and cancels changing/unknown-length streams',
    () async {
      var parts = 0;
      var cancelled = false;
      Stream<List<int>> source() async* {
        try {
          for (var index = 0; index < 10; index++) {
            parts++;
            yield List<int>.filled(32768, 0);
          }
        } finally {
          cancelled = true;
        }
      }

      await expectLater(
        NextcloudCertificate.importStream(source()),
        throwsFormatException,
      );
      expect(parts, 3);
      expect(cancelled, isTrue);
    },
  );
  test(
    'bounded certificate stream preserves the imported DER identity',
    () async {
      final imported = await NextcloudCertificate.importStream(
        Stream.value(File(fixture.path('ca.pem')).readAsBytesSync()),
      );
      expect(imported.single.fingerprint, cert('ca').fingerprint);
      expect(() => imported.single.validateCa(), returnsNormally);
    },
  );
}

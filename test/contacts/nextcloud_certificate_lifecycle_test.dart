import 'dart:convert';
import 'dart:io';

import 'package:busystack_contacts/busystack_contacts.dart';
import 'package:busymax/src/db/app_database.dart';
import 'package:busymax/src/dav/trust/nextcloud_certificate.dart';
import 'package:busymax/src/dav/trust/nextcloud_http_client_factory.dart';
import 'package:busymax/src/dav/trust/nextcloud_trust_policy.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import '../helpers/nextcloud_tls_fixture.dart';
import '../support/contacts_fixture.dart';
import '../support/dav_contacts_fixture.dart';
import '../support/persistence_test_directory.dart';

void main() {
  late NextcloudTlsFixture tls;
  late HttpServer server;
  late Uri endpoint;
  late DavFixture dav;
  final dispatched = <String?>[];
  late NextcloudHttpClientFactory clients;

  NextcloudCertificate certificate(String name) =>
      NextcloudCertificate.import(File(tls.path('$name.pem')).readAsBytesSync())
          .single;
  NextcloudTrustPolicy pin(String id, {bool expired = false}) {
    final approved = NextcloudTrustPolicy.approve(
      owner: 'contacts:$id',
      installation: endpoint,
      mode: NextcloudTrustMode.pinnedLeaf,
      certificates: [certificate('self')],
      generation: 'synthetic-policy-generation',
    );
    if (!expired) return approved;
    final old = certificate('expired');
    return NextcloudTrustPolicy.fromJson({
      ...approved.toJson(),
      'certificates': [
        {'der': base64.encode(old.der), 'sha256': old.fingerprint},
      ],
    });
  }

  ContactsFixture controller(
    AppDatabase database, {
    NextcloudHttpClientFactory? factory,
    Future<String?> Function(String)? read,
  }) {
    final f = ContactsFixture(
      database,
      realDav: true,
      nextcloudClients: factory,
      readDavSecret: read,
    );
    f.respondDav = dav.respond;
    addTearDown(f.controller.close);
    return f;
  }

  Future<ContactAccount> seed(ContactsFixture f) =>
      f.controller.addCardDavContactsOnly(
        id: 'nextcloud-private',
        label: 'Disposable Nextcloud contacts',
        server: endpoint,
        username: 'synthetic-user',
        password: 'synthetic-app-password',
      );

  Map<String, dynamic> config(ContactsFixture f, ContactAccount account) => {
    ...(jsonDecode(f.davSecrets[account.id]!) as Map).cast<String, dynamic>(),
    'nextcloud': true,
    'authorizationGeneration': account.generation,
    'trustPolicy': pin(account.id).toJson(),
  };
  Future<List<Map<String, dynamic>>> cache(ContactsFixture f) async =>
      (await f.store.read((tx) => tx.contacts()))
          .map((c) => c.toJson())
          .toList();
  Future<void> paused(ContactsFixture f, String id, String code) async {
    final account = await f.store.read((tx) => tx.account(id));
    expect(account!.enabled, isTrue);
    expect(account.errorCode, endsWith(code));
    await expectLater(
      f.controller.synchronizeAccount(id),
      throwsA(isA<ContactsException>().having((e) => e.code, 'code', code)),
    );
    expect(
      (await f.store.read((tx) => tx.account(id)))!.errorCode,
      endsWith(code),
    );
  }

  setUpAll(() async {
    tls = await NextcloudTlsFixture.create();
    server = await tls.serve('self');
    endpoint = Uri.parse('https://localhost:${server.port}/nextcloud/');
    server.listen((request) async {
      dispatched.add(request.headers.value(HttpHeaders.authorizationHeader));
      final incoming = http.Request(
        request.method,
        endpoint.resolveUri(request.uri),
      )..bodyBytes = await request.fold<List<int>>([], (a, b) => a..addAll(b));
      request.headers.forEach(
        (name, values) => incoming.headers[name] = values.join(','),
      );
      final response = await dav.respond(incoming);
      request.response.statusCode = response.statusCode;
      response.headers.forEach(request.response.headers.set);
      request.response.add(response.bodyBytes);
      await request.response.close();
    });
  });
  tearDownAll(() async {
    await server.close(force: true);
    await tls.dispose();
  });
  setUp(() {
    dav = DavFixture();
    dispatched.clear();
    clients = NextcloudHttpClientFactory(requireNetwork: () async {});
    addTearDown(clients.close);
  });

  test('direct expired-certificate failure during provider recreation stays reviewable', () async {
    final database = AppDatabase.memoryForTests();
    addTearDown(database.close);
    final f = controller(database, factory: clients);
    final account = await seed(f);
    final cached = await cache(f);
    final record = config(f, account)
      ..['authorizationGeneration'] = account.generation + 1
      ..['trustPolicy'] = pin(account.id, expired: true).toJson();
    f.davSecrets[account.id] = jsonEncode(record);
    await f.store.write(
      (tx) => tx.putAccount(account.copy(generation: account.generation + 1)),
    );
    final ordinaryRequests = f.requests.length;
    await expectLater(
      f.controller.synchronizeAccount(account.id),
      throwsA(
        isA<NextcloudCertificateException>().having(
          (e) => e.failure,
          'failure',
          NextcloudCertificateFailure.expired,
        ),
      ),
    );
    await paused(f, account.id, 'NextcloudCertificateexpired');
    expect(await cache(f), cached);
    expect(f.requests.length, ordinaryRequests);
    expect(dispatched, isEmpty);
  });

  test('startup, disk restart and explicit recovery retain expired-pin state and cached contacts', () async {
    final directory = await createPersistenceTestDirectory(
      'contacts-private-certificate-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/contacts.sqlite');
    final firstDb = AppDatabase(NativeDatabase(file));
    final first = controller(firstDb);
    final account = await seed(first);
    final cached = await cache(first);
    final encoded = jsonEncode(
      config(first, account)
        ..['trustPolicy'] = pin(account.id, expired: true).toJson(),
    );
    await first.controller.close();
    await firstDb.close();

    var reads = 0;
    final secondDb = AppDatabase(NativeDatabase(file));
    final second = controller(
      secondDb,
      factory: clients,
      read: (_) async {
        reads++;
        return encoded;
      },
    );
    await second.controller.start();
    await paused(second, account.id, 'NextcloudCertificateexpired');
    expect(
      reads,
      1,
    ); // Failed construction is never retried by synchronization.
    expect(await cache(second), cached);
    expect(second.requests, isEmpty);
    await second.controller.close();
    await secondDb.close();

    final thirdDb = AppDatabase(NativeDatabase(file));
    addTearDown(thirdDb.close);
    late ContactsFixture third;
    reads = 0;
    third = controller(
      thirdDb,
      factory: clients,
      read: (id) async {
        reads++;
        return third.davSecrets[id];
      },
    );
    third.davSecrets[account.id] = encoded;
    await third.controller.start();
    await paused(third, account.id, 'NextcloudCertificateexpired');
    expect(reads, 0); // Known review state prevents binding even after restart.
    expect(await cache(third), cached);
    expect(dispatched, isEmpty);
    expect(await third.controller.suggestAttendees('one'), isNotEmpty);

    await third.controller.replacePrivateTrust(
      account.id,
      account.generation,
      pin(account.id),
    );
    await third.controller.synchronizeAccount(account.id);
    final recovered = await third.store.read((tx) => tx.account(account.id));
    expect(recovered!.errorCode, isNull);
    expect(recovered.generation, account.generation + 1);
    expect(dispatched, isNotEmpty);
    final expected =
        'Basic ${base64.encode(utf8.encode('synthetic-user:synthetic-app-password'))}';
    expect(dispatched.every((header) => header == expected), isTrue);
    expect(
      third.requests,
      isEmpty,
    ); // Recovery also uses the scoped TLS client.
  });

  test('explicit replacement repairs a malformed policy without dropping to standard HTTPS', () async {
    final database = AppDatabase.memoryForTests();
    addTearDown(database.close);
    final initial = controller(database);
    final account = await seed(initial);
    final cached = await cache(initial);
    final encoded = jsonEncode(
      config(initial, account)..['trustPolicy'] = null,
    );
    await initial.controller.close();
    final f = controller(database, factory: clients);
    f.davSecrets[account.id] = encoded;
    await f.controller.start();
    await paused(f, account.id, 'NextcloudCertificateinvalidPolicy');
    expect(
      (await f.controller.privateTrustSnapshot(account.id)).$2!.mode,
      NextcloudTrustMode.invalidConfiguration,
    );
    expect(await cache(f), cached);
    expect(dispatched, isEmpty);
    await f.controller.replacePrivateTrust(
      account.id,
      account.generation,
      pin(account.id),
    );
    await f.controller.synchronizeAccount(account.id);
    expect(
      (await f.store.read((tx) => tx.account(account.id)))!.errorCode,
      isNull,
    );
    expect(
      (await f.controller.privateTrustSnapshot(account.id)).$2!.mode,
      NextcloudTrustMode.pinnedLeaf,
    );
    expect(dispatched, isNotEmpty);
    expect(f.requests, isEmpty);
  });

  final malformed = <String, void Function(Map<String, dynamic>)>{
    'missing Nextcloud marker': (m) => m.remove('nextcloud'),
    'false Nextcloud marker': (m) => m['nextcloud'] = false,
    'null Nextcloud marker': (m) => m['nextcloud'] = null,
    'string Nextcloud marker': (m) => m['nextcloud'] = 'true',
    'numeric Nextcloud marker': (m) => m['nextcloud'] = 1,
    'missing authorization generation': (m) =>
        m.remove('authorizationGeneration'),
    'string authorization generation': (m) =>
        m['authorizationGeneration'] = '0',
    'negative authorization generation': (m) =>
        m['authorizationGeneration'] = -1,
    'mismatched generation without recovery snapshot': (m) =>
        m['authorizationGeneration'] = 1,
    'malformed previous trust metadata': (m) {
      m['_previous'] = {...m, 'nextcloud': false};
      m['authorizationGeneration'] = 1;
    },
    'unsupported envelope version': (m) => m['version'] = 2,
    'null private policy': (m) => m['trustPolicy'] = null,
    'unsupported policy version': (m) => m['trustPolicy'] = {'version': 2},
    'private metadata with stripped policy and marker': (m) {
      m.remove('trustPolicy');
      m.remove('nextcloud');
    },
  };
  for (final entry in malformed.entries) {
    test(
      '${entry.key} fails closed across startup/restart and permits local removal',
      () async {
        final database = AppDatabase.memoryForTests();
        addTearDown(database.close);
        final initial = controller(database);
        final account = await seed(initial);
        final cached = await cache(initial);
        final record = config(initial, account);
        entry.value(record);
        final encoded = jsonEncode(record);
        await initial.controller.close();

        for (var restart = 0; restart < 2; restart++) {
          final f = controller(database, factory: clients);
          f.davSecrets[account.id] = encoded;
          await f.controller.start();
          await paused(f, account.id, 'NextcloudCertificateinvalidPolicy');
          expect(await cache(f), cached);
          expect(f.requests, isEmpty);
          expect(dispatched, isEmpty);
          if (restart == 1) {
            await f.controller.removeContactsAccount(account.id);
            expect(await f.store.read((tx) => tx.account(account.id)), isNull);
            expect(f.davSecrets, isEmpty);
          }
          await f.controller.close();
        }
      },
    );
  }

  test(
    'a configured private policy cannot use an unavailable scoped factory',
    () async {
      final database = AppDatabase.memoryForTests();
      addTearDown(database.close);
      final initial = controller(database);
      final account = await seed(initial);
      final encoded = jsonEncode(config(initial, account));
      await initial.controller.close();
      final restarted = controller(database);
      restarted.davSecrets[account.id] = encoded;
      await restarted.controller.start();
      await paused(restarted, account.id, 'NextcloudCertificateinvalidPolicy');
      expect(restarted.requests, isEmpty);
      expect(dispatched, isEmpty);
    },
  );
}

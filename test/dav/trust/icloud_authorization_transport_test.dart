import 'dart:async';
import 'dart:io';

import 'package:busymax/src/core/auth/authorization_persistence.dart';
import 'package:busymax/src/core/http/native_terminating_http_client.dart';
import 'package:busymax/src/core/secrets/secret_store.dart';
import 'package:busymax/src/dav/http/dav_account_http_client.dart';
import 'package:busymax/src/db/app_database.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/nextcloud_tls_fixture.dart';

void main() {
  late AppDatabase db;
  late InMemorySecretStore secrets;
  late AuthorizationPersistence persistence;
  late DavAccountHttpClient client;
  setUp(() async {
    db = AppDatabase.memoryForTests();
    secrets = InMemorySecretStore();
    persistence = AuthorizationPersistence(database: db, secrets: secrets);
    await secrets.saveCredential(
      'icloud',
      AppleICloudSecretRecord(
        username: 'fixture@example.test',
        appSpecificPassword: 'synthetic',
      ),
    );
    client = DavAccountHttpClient(
      accountId: 'icloud',
      persistence: persistence,
      createClient: (record) {
        expect(record, isA<AppleICloudSecretRecord>());
        // Exact production iCloud selection: standard native HTTP, no trust policy.
        return NativeTerminatingHttpClient();
      },
    );
  });
  tearDown(() async {
    client.close();
    await db.close();
  });

  test('ordinary platform HTTPS rejects a Nextcloud private leaf', () async {
    final tls = await NextcloudTlsFixture.create();
    final server = await tls.serve('self');
    var received = 0;
    server.listen((r) {
      received++;
      r.response.close();
    });
    try {
      await expectLater(
        client.get(Uri.parse('https://localhost:${server.port}/')),
        throwsA(anything),
      );
      expect(received, 0);
      await persistence
          .run('icloud', () async {})
          .timeout(const Duration(seconds: 2));
    } finally {
      await server.close(force: true);
      await tls.dispose();
    }
  });

  test('ordinary requests overlap and removal drains the iCloud authorization', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final both = Completer<void>();
    final release = Completer<void>();
    var received = 0;
    server.listen((r) async {
      received++;
      if (received == 2) both.complete();
      await release.future;
      r.response.write('ok');
      await r.response.close();
    });
    // HTTP is confined to this loopback transport fixture. Production DAV still
    // enforces iCloud HTTPS and destination/redirect restrictions before send.
    final uri = Uri.parse('http://127.0.0.1:${server.port}/');
    try {
      final operations = [client.get(uri), client.get(uri)];
      await both.future.timeout(const Duration(seconds: 3));
      var removed = false;
      final removal = persistence.run('icloud', () async {
        await secrets.deleteCredential('icloud');
        removed = true;
      });
      expect(removed, false);
      release.complete();
      await Future.wait(operations);
      await removal;
      await expectLater(client.get(uri), throwsA(isA<SecretStoreException>()));
      expect(received, 2);
    } finally {
      if (!release.isCompleted) release.complete();
      await server.close(force: true);
    }
  });
}

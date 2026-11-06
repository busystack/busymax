import 'dart:convert';
import 'dart:io';

import 'package:busymax/src/dav/trust/nextcloud_certificate.dart';
import 'package:busymax/src/dav/trust/nextcloud_http_client_factory.dart';
import 'package:busymax/src/dav/trust/nextcloud_trust_policy.dart';
import 'package:busymax/src/db/app_database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import '../helpers/nextcloud_tls_fixture.dart';
import '../support/contacts_fixture.dart';
import '../support/dav_contacts_fixture.dart';

void main() {
  late NextcloudTlsFixture tls;
  setUpAll(() async {
    tls = await NextcloudTlsFixture.create();
  });
  tearDownAll(() => tls.dispose());

  for (final decision in ['approve', 'reject', 'wrong-scope', 'cancel']) {
    test('contacts-only canonical certificate review: $decision', () async {
      final login = await tls.serve('self');
      final canonical = await tls.serve('self-renewed');
      addTearDown(() => login.close(force: true));
      addTearDown(() => canonical.close(force: true));
      final entered = Uri.parse('https://localhost:${login.port}/nextcloud');
      final destination = Uri.parse(
        'https://localhost:${canonical.port}/nextcloud',
      );
      final clients = NextcloudHttpClientFactory(
        requireNetwork: () async {},
        findProxy: (_) => 'DIRECT',
      );
      addTearDown(clients.close);
      final f = ContactsFixture(
        AppDatabase.memoryForTests(),
        realDav: true,
        nextcloudClients: clients,
      );
      addTearDown(f.close);
      final dav = DavFixture();
      var canonicalReviewed = false;
      final owners = <String>[];
      final fingerprints = <String>[];
      login.listen((request) async {
        expect(request.headers.value('authorization'), isNull);
        await request.drain<void>();
        request.response.headers.contentType = ContentType.json;
        request.response.write(
          jsonEncode(
            request.uri.path.endsWith('/index.php/login/v2')
                ? {
                    'login': entered.resolve('/nextcloud/browser').toString(),
                    'poll': {
                      'token': 'synthetic',
                      'endpoint': entered.resolve('/nextcloud/poll').toString(),
                    },
                  }
                : {
                    'server': destination.toString(),
                    'loginName': 'u',
                    'appPassword': 'synthetic',
                  },
          ),
        );
        await request.response.close();
      });
      canonical.listen((request) async {
        expect(canonicalReviewed, isTrue);
        expect(decision, 'approve');
        final adapted = http.Request(
          request.method,
          destination.resolve(request.uri.toString()),
        );
        request.headers.forEach(
          (name, values) => adapted.headers[name] = values.join(','),
        );
        adapted.body = await utf8.decoder.bind(request).join();
        final response = await dav.respond(adapted);
        request.response.statusCode = response.statusCode;
        response.headers.forEach(request.response.headers.set);
        request.response.add(response.bodyBytes);
        await request.response.close();
      });
      final enrollment = f.controller.addNextcloudContactsOnly(
        id: 'private',
        label: 'Private contacts',
        server: entered,
        reviewCanonicalServer: (original, returned) async {
          expect(original, entered);
          expect(returned, destination);
          return true;
        },
        reviewCertificate: (challenge, owner) async {
          owners.add(owner);
          fingerprints.add(challenge.observed!.fingerprint);
          expect(f.davSecrets, isEmpty);
          expect(await f.store.read((tx) => tx.account('private')), isNull);
          if (owners.length == 2) {
            expect(challenge.endpoint, destination);
            expect(dav.requests, isEmpty);
            canonicalReviewed = true;
            if (decision == 'reject') return null;
            if (decision == 'cancel') f.controller.cancelEnrollment('private');
          } else {
            expect(challenge.endpoint, entered);
          }
          return NextcloudTrustPolicy.approve(
            owner: owner,
            installation: owners.length == 2 && decision == 'wrong-scope'
                ? entered
                : challenge.endpoint,
            mode: NextcloudTrustMode.pinnedLeaf,
            certificates: [
              NextcloudCertificate.import(
                File(
                  tls.path(
                    owners.length == 1 ? 'self.pem' : 'self-renewed.pem',
                  ),
                ).readAsBytesSync(),
              ).single,
            ],
            generation: 'synthetic-${owners.length}',
          );
        },
      );
      if (decision == 'approve') {
        expect((await enrollment).enabled, isTrue);
        final stored = jsonDecode(f.davSecrets['private']!) as Map;
        final policy = NextcloudTrustPolicy.fromJson(stored['trustPolicy']);
        policy.requireScope('contacts:private', destination);
        expect(policy.certificates.single.fingerprint, fingerprints.last);
        expect(
          () => policy.requireScope('contacts:private', entered),
          throwsFormatException,
        );
        expect(dav.requests, isNotEmpty);
      } else {
        await expectLater(enrollment, throwsA(isA<Object>()));
        expect(f.davSecrets, isEmpty);
        expect(await f.store.read((tx) => tx.account('private')), isNull);
        expect(dav.requests, isEmpty);
      }
      expect(owners, hasLength(2));
      expect(owners.first, isNot(owners.last));
      expect(fingerprints.first, isNot(fingerprints.last));
    });
  }
}

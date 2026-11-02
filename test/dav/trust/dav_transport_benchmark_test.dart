import 'dart:io';

import 'package:busymax/src/core/auth/authorization_persistence.dart';
import 'package:busymax/src/core/http/authorization_leased_http_client.dart';
import 'package:busymax/src/core/secrets/secret_store.dart';
import 'package:busymax/src/dav/http/dav_account_http_client.dart';
import 'package:busymax/src/dav/trust/nextcloud_certificate.dart';
import 'package:busymax/src/dav/trust/nextcloud_http_client_factory.dart';
import 'package:busymax/src/dav/trust/nextcloud_trust_policy.dart';
import 'package:busymax/src/db/app_database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import '../../helpers/nextcloud_tls_fixture.dart';

/// Opt-in real TLS transport comparison. This measures the HTTP ownership
/// boundary, not full synchronization or live Nextcloud interoperability.
void main() {
  test(
    'compare direct, exclusive and shared leases under four concurrent DAV operations',
    () async {
      final tls = await NextcloudTlsFixture.create();
      final db = AppDatabase.memoryForTests();
      final secrets = InMemorySecretStore();
      final persistence = AuthorizationPersistence(
        database: db,
        secrets: secrets,
      );
      final factory = NextcloudHttpClientFactory(requireNetwork: () async {});
      final server = await tls.serve('self');
      final uri = Uri.parse('https://localhost:${server.port}/');
      final policy = NextcloudTrustPolicy.approve(
        owner: 'fixture',
        installation: uri,
        mode: NextcloudTrustMode.pinnedLeaf,
        certificates: [
          NextcloudCertificate.import(
            File(tls.path('self.pem')).readAsBytesSync(),
          ).single,
        ],
        generation: 'fixture',
      );
      await secrets.saveCredential(
        'fixture',
        NextcloudSecretRecord(
          canonicalServer: uri,
          loginName: 'fixture',
          appPassword: 'synthetic',
          trustPolicy: policy,
        ),
      );
      final calendar =
          'BEGIN:VCALENDAR\r\n${List.generate(5000, (i) => 'BEGIN:VEVENT\r\nUID:event-$i\r\nSUMMARY:Synthetic meeting $i\r\nEND:VEVENT\r\n').join()}END:VCALENDAR\r\n';
      final tasks =
          'BEGIN:VCALENDAR\r\n${List.generate(500, (i) => 'BEGIN:VTODO\r\nUID:task-$i\r\nSUMMARY:Synthetic task $i\r\nEND:VTODO\r\n').join()}END:VCALENDAR\r\n';
      var active = 0, peak = 0;
      server.listen((r) async {
        active++;
        if (active > peak) peak = active;
        try {
          await r.drain<void>();
          await Future<void>.delayed(const Duration(milliseconds: 40));
          r.response.write(r.uri.path.contains('calendar') ? calendar : tasks);
          await r.response.close();
        } finally {
          active--;
        }
      });
      http.Client raw() =>
          factory.create(owner: 'fixture', authority: uri, policy: policy);
      final shared = DavAccountHttpClient(
        accountId: 'fixture',
        persistence: persistence,
        createClient: (_) => raw(),
      );
      try {
        for (final mode in ['direct', 'exclusive', 'shared']) {
          peak = 0;
          final timer = Stopwatch()..start();
          // Four calendar batches, eight task-list paths and simultaneous mutations,
          // bounded to the shared DAV per-account concurrency of four.
          for (var batch = 0; batch < 4; batch++) {
            await Future.wait([
              for (var i = 0; i < 4; i++)
                () async {
                  final http.Client client = mode == 'shared'
                      ? shared
                      : mode == 'exclusive'
                      ? AuthorizationLeasedHttpClient(
                          delegate: raw(),
                          runLease: (work) => persistence.run('fixture', work),
                          validate: () async {},
                        )
                      : raw();
                  try {
                    final response = i == 3
                        ? await client.post(
                            uri.resolve('mutation'),
                            body: 'synthetic',
                          )
                        : await client.get(
                            uri.resolve(
                              i == 0 ? 'calendar' : 'task-list-$batch-$i',
                            ),
                          );
                    expect(response.statusCode, 200);
                  } finally {
                    if (!identical(client, shared)) client.close();
                  }
                }(),
            ]);
          }
          stdout.writeln(
            'DAV TLS benchmark $mode: ${timer.elapsedMilliseconds} ms; peak=$peak; 16 requests',
          );
          expect(peak, mode == 'exclusive' ? 1 : 4);
        }
      } finally {
        shared.close();
        factory.close();
        await server.close(force: true);
        await db.close();
        await tls.dispose();
      }
    },
    skip: Platform.environment['BUSYMAX_DAV_BENCHMARK'] != '1'
        ? 'Opt-in comparative transport benchmark.'
        : false,
  );
}

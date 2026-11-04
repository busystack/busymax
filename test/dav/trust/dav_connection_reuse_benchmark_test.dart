import 'dart:async';
import 'dart:io';

import 'package:busymax/src/core/auth/authorization_persistence.dart';
import 'package:busymax/src/core/http/native_terminating_http_client.dart';
import 'package:busymax/src/core/http/terminating_http_client.dart';
import 'package:busymax/src/core/secrets/secret_store.dart';
import 'package:busymax/src/dav/http/dav_account_http_client.dart';
import 'package:busymax/src/dav/trust/nextcloud_certificate.dart';
import 'package:busymax/src/dav/trust/nextcloud_http_client_factory.dart';
import 'package:busymax/src/dav/trust/nextcloud_trust_policy.dart';
import 'package:busymax/src/db/app_database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

import '../../helpers/nextcloud_tls_fixture.dart';

// Compares v0.3.2's terminating native request path (42f3f7b) with
// the reviewed per-request account lifecycle and its replacement. A shared
// IOClient is included separately as a connection-reuse reference. This is a synthetic DAV request
// workload, not a complete app/server synchronization benchmark.
void main() {
  test(
    'compare DAV connection lifecycles with 40 ms simulated network RTT',
    () async {
      final tls = await NextcloudTlsFixture.create();
      final db = AppDatabase.memoryForTests();
      final secrets = InMemorySecretStore();
      final persistence = AuthorizationPersistence(
        database: db,
        secrets: secrets,
      );
      final server = await tls.serve('self');
      final relay = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final sockets = <Socket>[];
      relay.listen((downstream) async {
        final upstream = await Socket.connect('localhost', server.port);
        sockets.addAll([downstream, upstream]);
        Stream<List<int>> delayed(Socket socket) =>
            socket.asyncMap((chunk) async {
              await Future<void>.delayed(const Duration(milliseconds: 20));
              return chunk;
            });
        unawaited(
          upstream.addStream(delayed(downstream)).catchError((Object _) {}),
        );
        unawaited(
          downstream.addStream(delayed(upstream)).catchError((Object _) {}),
        );
      });
      final uri = Uri.parse(
        'https://localhost:${relay.port}/nextcloud/remote.php/dav/',
      );
      final ports = <int>{};
      var received = 0;
      server.listen((request) async {
        received++;
        ports.add(request.connectionInfo!.remotePort);
        await request.drain<void>();
        request.response.headers.contentType = ContentType('text', 'calendar');
        request.response.write(
          'BEGIN:VCALENDAR\r\nVERSION:2.0\r\nBEGIN:VEVENT\r\nUID:synthetic\r\nDTSTART:20261103T120000Z\r\nSUMMARY:Synthetic\r\nEND:VEVENT\r\nEND:VCALENDAR\r\n',
        );
        await request.response.close();
      });
      final factory = NextcloudHttpClientFactory(requireNetwork: () async {});
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
      DavAccountHttpClient account({required bool reuse}) =>
          DavAccountHttpClient(
            accountId: 'fixture',
            persistence: persistence,
            createClient: (_) => factory.create(
              owner: 'fixture',
              authority: uri,
              policy: policy,
              reuseConnections: reuse,
            ),
          );
      final baseline = IOClient(
        HttpClient(
          context: SecurityContext(withTrustedRoots: false)
            ..setTrustedCertificates(tls.path('self.pem')),
        ),
      );
      final original = NativeTerminatingHttpClient(
        nativeClientFactory: () => HttpClient(
          context: SecurityContext(withTrustedRoots: false)
            ..setTrustedCertificates(tls.path('self.pem')),
        ),
      );
      final pooled = account(reuse: true);
      try {
        for (final mode in [
          'shared-io-reference',
          'v0.3.2-terminating-path',
          'reviewed-per-request',
          'pooled-account',
        ]) {
          ports.clear();
          received = 0;
          final timer = Stopwatch()..start();
          for (var i = 0; i < 50; i++) {
            final http.Client client = mode == 'reviewed-per-request'
                ? account(reuse: false)
                : mode == 'pooled-account'
                ? pooled
                : mode == 'v0.3.2-terminating-path'
                ? original
                : baseline;
            try {
              final stop = Completer<void>();
              final request = http.Request(
                'GET',
                uri.resolve('synthetic-$i.ics'),
              );
              late http.Response response;
              try {
                response = await http.Response.fromStream(
                  await (client is TerminatingHttpClient
                      ? client.sendTerminating(
                          request,
                          terminate: stop.future,
                          connectionTimeout: const Duration(seconds: 15),
                        )
                      : client.send(request)),
                );
              } finally {
                stop.complete();
              }
              expect(response.statusCode, 200);
              expect(response.body, contains('UID:synthetic'));
            } finally {
              if (mode == 'reviewed-per-request') client.close();
            }
          }
          expect(received, 50);
          expect(
            ports,
            hasLength(
              mode == 'reviewed-per-request' ||
                      mode == 'v0.3.2-terminating-path'
                  ? 50
                  : 1,
            ),
          );
          stdout.writeln(
            'DAV reuse benchmark $mode: ${timer.elapsedMilliseconds} ms; TLS connections=${ports.length}; 50 requests; simulated RTT=40 ms',
          );
        }
      } finally {
        pooled.close();
        original.close();
        baseline.close();
        factory.close();
        await relay.close();
        for (final socket in sockets) {
          socket.destroy();
        }
        await server.close(force: true);
        await db.close();
        await tls.dispose();
      }
    },
    skip: Platform.environment['BUSYMAX_DAV_BENCHMARK'] != '1'
        ? 'Opt-in TLS latency benchmark.'
        : false,
  );
}

import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

// Real handshakes on the bundled Dart runtime. All keys are generated under
// the OS temporary directory and deleted; no system trust store is changed.
void main() {
  test(
    'connectionFactory enforces the leaf before handing TLS to HTTP',
    () async {
      final directory = await Directory.systemTemp.createTemp('busymax-tls-');
      Future<void> openssl(List<String> arguments) async {
        final result = await Process.run(
          'openssl',
          arguments,
          workingDirectory: directory.path,
        );
        expect(result.exitCode, 0, reason: '${result.stderr}');
      }

      HttpServer? server;
      final clients = <HttpClient>[];
      try {
        await openssl([
          'req',
          '-x509',
          '-newkey',
          'rsa:2048',
          '-nodes',
          '-sha256',
          '-keyout',
          'key.pem',
          '-out',
          'first.pem',
          '-days',
          '2',
          '-subj',
          '/CN=localhost',
          '-addext',
          'subjectAltName=DNS:localhost',
          '-addext',
          'basicConstraints=critical,CA:FALSE',
        ]);
        await openssl([
          'req',
          '-x509',
          '-key',
          'key.pem',
          '-sha256',
          '-out',
          'renewed.pem',
          '-days',
          '2',
          '-set_serial',
          '2',
          '-subj',
          '/CN=localhost',
          '-addext',
          'subjectAltName=DNS:localhost',
          '-addext',
          'basicConstraints=critical,CA:FALSE',
        ]);
        String path(String name) => '${directory.path}/$name';
        var requests = 0;
        Future<void> serve(String certificate, {int port = 0}) async {
          final context = SecurityContext()
            ..useCertificateChain(path(certificate))
            ..usePrivateKey(path('key.pem'));
          server = await HttpServer.bindSecure('localhost', port, context);
          server!.listen((request) async {
            requests++;
            await request.drain<void>();
            request.response.write('ok');
            await request.response.close();
          });
        }

        await serve('first.pem');
        final port = server!.port;
        final endpoint = Uri.parse('https://localhost:$port/');
        final context = SecurityContext(withTrustedRoots: false)
          ..setTrustedCertificates(path('first.pem'));
        String? approved;
        HttpClient client({required bool approve}) {
          final client = HttpClient(context: context);
          client.connectionFactory = (uri, proxyHost, proxyPort) async {
            final task = await SecureSocket.startConnect(
              uri.host,
              uri.port,
              context: context,
            );
            return ConnectionTask.fromSocket(
              task.socket.then((socket) {
                final fingerprint = sha256
                    .convert(socket.peerCertificate!.der)
                    .toString();
                if (approve) approved = fingerprint;
                if (approved != fingerprint) {
                  socket.destroy();
                  throw const HandshakeException('pin mismatch');
                }
                return socket;
              }),
              task.cancel,
            );
          };
          clients.add(client);
          return client;
        }

        // No pin approval: even authenticated HTTP headers cannot be sent.
        await expectLater(
          client(approve: false).postUrl(endpoint),
          throwsA(isA<HandshakeException>()),
        );
        expect(requests, 0);
        final request = await client(approve: true).postUrl(endpoint);
        request.headers.set('authorization', 'synthetic-test-only');
        request.write('synthetic-body');
        await (await request.close()).drain<void>();
        expect(requests, 1);

        for (final client in clients) {
          client.close(force: true);
        }
        await server!.close(force: true);
        await serve('renewed.pem', port: port);
        // Same private key and subject: native trust alone can accept renewal.
        // The exact DER check still rejects before HTTP sees the socket.
        await expectLater(
          client(approve: false).postUrl(endpoint),
          throwsA(isA<HandshakeException>()),
        );
        expect(requests, 1);
      } finally {
        for (final client in clients) {
          client.close(force: true);
        }
        await server?.close(force: true);
        await directory.delete(recursive: true);
      }
    },
  );
}

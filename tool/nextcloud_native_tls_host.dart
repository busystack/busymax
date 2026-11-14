import 'dart:convert';
import 'dart:io';
import 'dart:math';

import '../test/helpers/nextcloud_tls_fixture.dart';

/// Disposable native-engine acceptance peer. Bindings are loopback only;
/// Android reaches them with adb reverse. The control channel carries no
/// account credentials. Public certificates, ports and a random control nonce
/// are written outside source for --dart-define-from-file.
Future<void> main(List<String> args) async {
  if (args.length != 1) throw ArgumentError('Provide a temporary bundle path.');
  final fixture = await NextcloudTlsFixture.create();
  final nonce = base64Url.encode(
    List.generate(32, (_) => Random.secure().nextInt(256)),
  );
  final servers = <String, HttpServer>{};
  final counts = <String, int>{'pin': 0, 'ca': 0};
  final ports = <String, int>{};
  Future<void> serve(String slot, String certificate) async {
    await servers.remove(slot)?.close(force: true);
    final server = await fixture.serve(certificate, port: ports[slot] ?? 0);
    servers[slot] = server;
    ports[slot] = server.port;
    server.listen((request) async {
      counts[slot] = counts[slot]! + 1;
      await request.drain<void>();
      request.response.write('accepted-synthetic-request');
      await request.response.close();
    });
  }

  await serve('pin', 'self');
  await serve('ca', 'leaf');
  final control = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  control.listen((request) async {
    if (request.uri.queryParameters['nonce'] != nonce) {
      request.response.statusCode = 403;
    } else {
      final slot = request.uri.queryParameters['slot'];
      final certificate = request.uri.queryParameters['certificate'];
      if (request.uri.path == '/change' &&
          {'pin', 'ca'}.contains(slot) &&
          {
            'self',
            'self-renewed',
            'leaf',
            'renewed',
            'expired',
            'wrong-leaf',
          }.contains(certificate)) {
        await serve(slot!, certificate!);
      } else if (request.uri.path != '/counts') {
        request.response.statusCode = 400;
      }
      request.response.write(jsonEncode(counts));
    }
    await request.response.close();
  });
  final bundle = {
    'control': 'http://localhost:${control.port}',
    'nonce': nonce,
    'pin': 'https://localhost:${ports['pin']}/nextcloud',
    'ca': 'https://localhost:${ports['ca']}/nextcloud',
    'certificates': {
      for (final name in ['ca', 'self', 'self-renewed'])
        name: File(fixture.path('$name.pem')).readAsStringSync(),
    },
  };
  await File(args.single).writeAsString(
    jsonEncode({
      'BUSYMAX_NATIVE_TLS_FIXTURE': base64.encode(
        utf8.encode(jsonEncode(bundle)),
      ),
    }),
  );
  stdout.writeln(
    'Native TLS peer ready; reverse ports ${[control.port, ...ports.values].join(',')}.',
  );
  Future<void> close() async {
    await control.close(force: true);
    for (final server in servers.values) {
      await server.close(force: true);
    }
    await fixture.dispose();
    exit(0);
  }

  if (!Platform.isWindows) {
    ProcessSignal.sigterm.watch().listen((_) => close());
  }
  ProcessSignal.sigint.watch().listen((_) => close());
}

import 'dart:async';
import 'dart:io';

import 'package:busymax/src/core/http/native_terminating_http_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

void main() {
  test(
    'a pooled lane cancels a stalled connection at its connection deadline',
    () async {
      var cancelled = false;
      final client = NativeTerminatingHttpClient(
        reuseConnections: true,
        nativeClientFactory: () => HttpClient()
          ..findProxy = ((_) => 'DIRECT')
          ..connectionFactory = (uri, host, port) async =>
              ConnectionTask.fromSocket(Completer<Socket>().future, () {
                cancelled = true;
              }),
      );
      addTearDown(client.close);
      await expectLater(
        client
            .sendTerminating(
              http.Request('GET', Uri.parse('http://stalled.test/')),
              terminate: Completer<void>().future,
              connectionTimeout: const Duration(milliseconds: 40),
            )
            .timeout(const Duration(seconds: 1)),
        throwsA(
          isA<SocketException>().having(
            (e) => e.message,
            'connection timeout',
            contains('timed out'),
          ),
        ),
      );
      expect(cancelled, isTrue);
    },
  );

  test('connection deadline allows slow responses and keeps the completed socket reusable', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    final ports = <int>[];
    server.listen((request) async {
      ports.add(request.connectionInfo!.remotePort);
      await Future<void>.delayed(const Duration(milliseconds: 100));
      request.response.write('ok');
      await request.response.close();
    });
    final client = NativeTerminatingHttpClient(reuseConnections: true);
    addTearDown(client.close);
    final uri = Uri.parse('http://127.0.0.1:${server.port}/');
    for (var i = 0; i < 2; i++) {
      final stop = Completer<void>();
      final response = await client.sendTerminating(
        http.Request('GET', uri),
        terminate: stop.future,
        connectionTimeout: const Duration(milliseconds: 50),
      );
      expect(await response.stream.bytesToString(), 'ok');
      stop.complete();
    }
    expect(ports.toSet(), hasLength(1));
  });
}

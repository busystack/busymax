import 'dart:async';
import 'dart:io';

import 'package:busymax/src/core/http/native_terminating_http_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

void main() {
  test('retiring connections preserves an in-flight response and validates a fresh lane', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final finish = Completer<void>();
    addTearDown(() async {
      if (!finish.isCompleted) finish.complete();
      await server.close(force: true);
    });
    final ports = <int>{};
    server.listen((request) async {
      ports.add(request.connectionInfo!.remotePort);
      await request.drain<void>();
      if (request.uri.path == '/first') {
        request.response.write('first');
        await request.response.flush();
        await finish.future;
        request.response.write('done');
      } else {
        request.response.write('second');
      }
      await request.response.close();
    });
    final client = NativeTerminatingHttpClient();
    addTearDown(client.close);
    final origin = Uri.parse('http://127.0.0.1:${server.port}/');
    final first = await client.send(
      http.Request('GET', origin.resolve('first')),
    );
    final body = first.stream.bytesToString();
    client.retireConnections();
    expect((await client.get(origin.resolve('second'))).body, 'second');
    finish.complete();
    expect(await body, 'firstdone');
    expect(ports, hasLength(2));
  });

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
      await request.drain<void>();
      request.response
        ..persistentConnection = true
        ..contentLength = 2;
      await Future<void>.delayed(const Duration(milliseconds: 100));
      request.response.write('ok');
      await request.response.close();
    });
    final client = NativeTerminatingHttpClient(
      reuseConnections: true,
      // The default native limit is unlimited. In Dart 3.13.4 on Windows,
      // response completion can precede return of its socket to the idle pool;
      // an immediate next request may open another socket even with IOClient.
      // Bound this sequential fixture to one connection so it tests reuse and
      // termination after body completion, without relying on idle-pool timing.
      nativeClientFactory: () => HttpClient()
        ..findProxy = ((_) => 'DIRECT')
        ..maxConnectionsPerHost = 1,
    );
    addTearDown(client.close);
    final uri = Uri.parse('http://127.0.0.1:${server.port}/');
    for (var i = 0; i < 2; i++) {
      final stop = Completer<void>();
      final response = await client.sendTerminating(
        http.Request('GET', uri),
        terminate: stop.future,
        connectionTimeout: const Duration(milliseconds: 50),
      );
      expect(response.persistentConnection, isTrue);
      expect(response.contentLength, 2);
      expect(await response.stream.bytesToString(), 'ok');
      stop.complete();
    }
    expect(ports.toSet(), hasLength(1));
  });
}

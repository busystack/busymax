import 'dart:async';

import 'package:busymax/src/core/http/destination_checked_http_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  final uri = Uri.parse('https://qa.example.test/dav/');

  test(
    'cancelling pending destination check never dispatches after later grant',
    () async {
      final check = Completer<void>();
      final cancel = Completer<void>();
      var dispatched = 0;
      final client = DestinationCheckedHttpClient(
        MockClient((_) async {
          dispatched++;
          return http.Response('ok', 200);
        }),
        (_) => check.future,
        closeInner: true,
      );
      addTearDown(client.close);
      final response = client.sendTerminating(
        http.Request('GET', uri),
        terminate: cancel.future,
        connectionTimeout: const Duration(seconds: 1),
      );
      final rejected = expectLater(
        response,
        throwsA(isA<http.RequestAbortedException>()),
      );
      cancel.complete();
      await rejected;
      check.complete();
      await Future<void>.delayed(Duration.zero);
      expect(dispatched, 0);
    },
  );

  test('revocation after UI preflight blocks retained request and later grant recovers', () async {
    var granted = true, dispatched = 0;
    final client = DestinationCheckedHttpClient(
      MockClient((_) async {
        dispatched++;
        return http.Response('ok', 200);
      }),
      (_) async {
        if (!granted) throw const _PermissionDenied();
      },
      closeInner: true,
    );
    addTearDown(client.close);
    // The foreground flow observed permission, then it changed before send.
    expect(granted, isTrue);
    granted = false;
    await expectLater(client.get(uri), throwsA(isA<_PermissionDenied>()));
    expect(dispatched, 0);
    granted = true;
    expect((await client.get(uri)).body, 'ok');
    expect(dispatched, 1);
  });

  test('closing one checked binding preserves a shared transport for another account', () async {
    final check = Completer<void>();
    var dispatched = 0;
    final shared = MockClient((_) async {
      dispatched++;
      return http.Response('ok', 200);
    });
    addTearDown(shared.close);
    final first = DestinationCheckedHttpClient(
      shared,
      (_) => check.future,
      closeInner: false,
    );
    final second = DestinationCheckedHttpClient(
      shared,
      (_) async {},
      closeInner: false,
    );
    addTearDown(second.close);
    final response = first.get(uri);
    final rejected = expectLater(
      response,
      throwsA(isA<http.ClientException>()),
    );
    first.close();
    check.complete();
    await rejected;
    expect(dispatched, 0);
    expect((await second.get(uri)).body, 'ok');
    expect(dispatched, 1);
  });
}

final class _PermissionDenied implements Exception {
  const _PermissionDenied();
}

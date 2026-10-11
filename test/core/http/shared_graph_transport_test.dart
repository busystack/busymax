import 'dart:convert';

import 'package:busystack_graph/busystack_graph.dart';
import 'package:busymax/src/core/http/shared_graph_transport.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';

void main() {
  final now = DateTime.utc(2026, 10, 11);
  final delays = <Duration, String>{
    const Duration(seconds: 17): '17',
    const Duration(seconds: 16, microseconds: 999999): '17',
    const Duration(seconds: 17, microseconds: 1): '18',
    Duration.zero: '0',
    const Duration(microseconds: -1): '0',
    const Duration(seconds: -2): '0',
  };
  for (final entry in delays.entries) {
    test(
      'Graph Retry-After rounds ${entry.key} up without adding a second',
      () async {
        var requests = 0;
        final adapter = BusyMaxGraphTransport(
          httpClient: MockClient((_) async {
            requests++;
            throw GraphException(
              GraphFailure.throttled,
              'TooManyRequests',
              statusCode: 429,
              retryAt: now.add(entry.key),
              retryAfterProvided: true,
              requestRejected: true,
            );
          }),
          authorizationHeader: (_) async => 'Bearer fixture',
          nowUtc: () => now,
        );
        addTearDown(adapter.close);
        final response = await adapter.request(
          'POST',
          Uri.parse('https://graph.microsoft.com/v1.0/me/events'),
        );
        expect(response.statusCode, 429);
        expect(response.headers['retry-after'], entry.value);
        expect(
          (jsonDecode(response.body) as Map)['error']['code'],
          'TooManyRequests',
        );
        expect(
          requests,
          1,
          reason: 'The shared pipeline must not retry a write.',
        );
      },
    );
  }
  test(
    'Graph fallback retry deadline does not invent a server retry hint',
    () async {
      final adapter = BusyMaxGraphTransport(
        httpClient: MockClient(
          (_) async => throw GraphException(
            GraphFailure.throttled,
            'TooManyRequests',
            statusCode: 429,
            retryAt: now.add(const Duration(seconds: 30)),
            requestRejected: true,
          ),
        ),
        authorizationHeader: (_) async => 'Bearer fixture',
        nowUtc: () => now,
      );
      addTearDown(adapter.close);
      final response = await adapter.request(
        'GET',
        Uri.parse('https://graph.microsoft.com/v1.0/me/events'),
      );
      expect(response.statusCode, 429);
      expect(response.headers, isNot(contains('retry-after')));
    },
  );
}

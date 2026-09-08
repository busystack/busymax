import 'dart:async';
import 'dart:convert';

import 'package:busymax/src/features/maps/data/geoapify_client.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'parses result metadata, ignores malformed rows, and limits to five',
    () async {
      late Uri requested;
      final rows = <Object?>[
        {
          'formatted': '1 Main Street, Example City',
          'name': 'Example Hall',
          'lat': 49.2,
          'lon': -123.1,
          'result_type': 'amenity',
          'housenumber': '1',
          'street': 'Main Street',
          'city': 'Example City',
          'postcode': 'A1A 1A1',
          'country': 'Canada',
          'datasource': {'attribution': '© OpenStreetMap contributors'},
        },
        {'formatted': 'Broken', 'lat': 'not-a-number', 'lon': 1},
        for (var index = 0; index < 7; index++)
          {
            'formatted': 'Area $index',
            'lat': index,
            'lon': index,
            'result_type': 'city',
          },
      ];
      final client = GeoapifyClient(
        client: _Client((request) async {
          requested = request.url;
          return _jsonResponse({'results': rows});
        }),
        apiKey: 'test-key',
        canUseNetwork: () async => true,
      );

      final results = await client.search(' café & hall ', language: 'fr-CA');

      expect(requested.host, 'api.geoapify.com');
      expect(requested.path, '/v1/geocode/autocomplete');
      expect(requested.queryParameters['text'], 'café & hall');
      expect(requested.queryParameters['limit'], '5');
      expect(requested.queryParameters['lang'], 'fr');
      expect(results, hasLength(5));
      expect(results.first.name, 'Example Hall');
      expect(results.first.formattedAddress, '1 Main Street, Example City');
      expect(results.first.resultType, 'amenity');
      expect(results.first.address, {
        'street': '1 Main Street',
        'city': 'Example City',
        'postalCode': 'A1A 1A1',
        'countryOrRegion': 'Canada',
      });
      expect(results.first.approximate, isFalse);
      expect(results[1].approximate, isTrue);
    },
  );

  test(
    'falls back to a non-empty place name when formatted is empty',
    () async {
      final client = GeoapifyClient(
        client: _Client(
          (_) async => _jsonResponse({
            'results': [
              {'formatted': '', 'name': 'Named point', 'lat': 0, 'lon': 0},
            ],
          }),
        ),
        apiKey: 'test-key',
        canUseNetwork: () async => true,
      );

      final results = await client.search('point', language: 'en');
      expect(results.single.label, 'Named point');
      expect(results.single.formattedAddress, isNull);
    },
  );

  test('reports unconfigured and offline without issuing a request', () async {
    var requests = 0;
    final transport = _Client((_) async {
      requests++;
      return _jsonResponse({'results': const []});
    });
    final unconfigured = GeoapifyClient(
      client: transport,
      apiKey: '',
      canUseNetwork: () async => true,
    );
    final offline = GeoapifyClient(
      client: transport,
      apiKey: 'test-key',
      canUseNetwork: () async => false,
    );

    await expectLater(
      unconfigured.search('place', language: 'en'),
      throwsA(
        isA<LocationLookupException>().having(
          (error) => error.status,
          'status',
          LocationLookupStatus.unconfigured,
        ),
      ),
    );
    await expectLater(
      offline.search('place', language: 'en'),
      throwsA(
        isA<LocationLookupException>().having(
          (error) => error.status,
          'status',
          LocationLookupStatus.offline,
        ),
      ),
    );
    expect(requests, 0);
  });

  test('honors retry-after without generating a request loop', () async {
    var now = DateTime.utc(2026, 1, 1);
    var requests = 0;
    final client = GeoapifyClient(
      client: _Client((_) async {
        requests++;
        return http.StreamedResponse(
          const Stream<List<int>>.empty(),
          429,
          headers: {'retry-after': '30'},
        );
      }),
      apiKey: 'test-key',
      canUseNetwork: () async => true,
      now: () => now,
    );

    for (var attempt = 0; attempt < 2; attempt++) {
      await expectLater(
        client.search('place', language: 'en'),
        throwsA(
          isA<LocationLookupException>().having(
            (error) => error.status,
            'status',
            LocationLookupStatus.rateLimited,
          ),
        ),
      );
    }
    expect(requests, 1);
    now = now.add(const Duration(seconds: 31));
    await expectLater(
      client.search('place', language: 'en'),
      throwsA(anything),
    );
    expect(requests, 2);
  });

  test('rejects malformed and oversized bodies while reading', () async {
    final malformed = GeoapifyClient(
      client: _Client((_) async => _bytesResponse(utf8.encode('[]'))),
      apiKey: 'test-key',
      canUseNetwork: () async => true,
    );
    await expectLater(
      malformed.search('place', language: 'en'),
      throwsA(isA<LocationLookupException>()),
    );

    final oversized = GeoapifyClient(
      client: _Client(
        (_) async => http.StreamedResponse(
          Stream.fromIterable([
            List<int>.filled(700000, 32),
            List<int>.filled(400000, 32),
          ]),
          200,
        ),
      ),
      apiKey: 'test-key',
      canUseNetwork: () async => true,
    );
    await expectLater(
      oversized.search('place', language: 'en'),
      throwsA(isA<LocationLookupException>()),
    );
  });

  test(
    'cancellation invalidates a response without closing shared transport',
    () async {
      final gate = Completer<void>();
      final transport = _Client((_) async {
        await gate.future;
        return _jsonResponse({
          'results': [
            {'formatted': 'Late', 'lat': 1, 'lon': 2},
          ],
        });
      });
      final client = GeoapifyClient(
        client: transport,
        apiKey: 'test-key',
        canUseNetwork: () async => true,
      );
      final cancellation = LocationRequestCancellation();
      final pending = client.search(
        'place',
        language: 'en',
        cancellation: cancellation,
      );
      cancellation.cancel();
      gate.complete();

      expect(await pending, isEmpty);
      expect(transport.closed, isFalse);
    },
  );

  test('cancellation and timeout stop response-body reading', () async {
    final bodies = <StreamController<List<int>>>[];
    final client = GeoapifyClient(
      client: _Client((_) async {
        final body = StreamController<List<int>>();
        bodies.add(body);
        return http.StreamedResponse(body.stream, 200);
      }),
      apiKey: 'test-key',
      canUseNetwork: () async => true,
      timeout: const Duration(milliseconds: 20),
    );
    final cancellation = LocationRequestCancellation();
    final cancelled = client.search(
      'cancelled place',
      language: 'en',
      cancellation: cancellation,
    );
    await Future<void>.delayed(Duration.zero);
    cancellation.cancel();
    expect(await cancelled, isEmpty);

    await expectLater(
      client.search('timed out place', language: 'en'),
      throwsA(
        isA<LocationLookupException>().having(
          (error) => error.status,
          'status',
          LocationLookupStatus.failed,
        ),
      ),
    );
    for (final body in bodies) {
      await body.close();
    }
  });
}

http.StreamedResponse _jsonResponse(Object value) =>
    _bytesResponse(utf8.encode(jsonEncode(value)));

http.StreamedResponse _bytesResponse(List<int> value) =>
    http.StreamedResponse(Stream.value(value), 200);

final class _Client extends http.BaseClient {
  _Client(this.handler);
  final Future<http.StreamedResponse> Function(http.BaseRequest request)
  handler;
  bool closed = false;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      handler(request);

  @override
  void close() {
    closed = true;
  }
}

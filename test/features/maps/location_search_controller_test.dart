import 'dart:async';
import 'dart:convert';

import 'package:busymax/src/features/maps/application/location_search_controller.dart';
import 'package:busymax/src/features/maps/data/geoapify_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

void main() {
  test('debounces input and does not search during IME composition', () async {
    var requests = 0;
    final controller = LocationSearchController(
      _client((_) async {
        requests++;
        return _results('Found', 1, 2);
      }),
      debounce: const Duration(milliseconds: 10),
    );
    addTearDown(controller.dispose);

    controller.search('par', language: 'en');
    controller.search('park', language: 'en');
    controller.search('park composing', language: 'en', composing: true);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(requests, 0);

    controller.search('park', language: 'en');
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(requests, 1);
    expect(controller.status, LocationLookupStatus.results);
  });

  test(
    'short automatic input is ignored but explicit forward search runs',
    () async {
      final paths = <String>[];
      final controller = LocationSearchController(
        _client((request) async {
          paths.add(request.url.path);
          return _results('BC', 49, -123);
        }),
        debounce: Duration.zero,
      );
      addTearDown(controller.dispose);

      controller.search('BC', language: 'en');
      await Future<void>.delayed(Duration.zero);
      expect(paths, isEmpty);

      controller.search(
        'BC',
        language: 'en',
        submit: true,
        autocomplete: false,
      );
      await _until(() => controller.status == LocationLookupStatus.results);
      expect(paths, ['/v1/geocode/search']);
    },
  );

  test(
    'a newer response wins even when an older response arrives later',
    () async {
      final first = Completer<http.StreamedResponse>();
      final second = Completer<http.StreamedResponse>();
      final controller = LocationSearchController(
        _client(
          (request) => request.url.queryParameters['text'] == 'first'
              ? first.future
              : second.future,
        ),
        debounce: Duration.zero,
      );
      addTearDown(controller.dispose);

      controller.search('first', language: 'en');
      await Future<void>.delayed(Duration.zero);
      controller.search('second', language: 'en');
      await Future<void>.delayed(Duration.zero);
      second.complete(_results('Second result', 2, 2));
      await _until(() => controller.results.isNotEmpty);
      first.complete(_results('Obsolete result', 1, 1));
      await Future<void>.delayed(Duration.zero);

      expect(controller.results.single.label, 'Second result');
    },
  );

  test(
    'clear and dispose cancel pending work and prevent restoration',
    () async {
      final gate = Completer<http.StreamedResponse>();
      final controller = LocationSearchController(
        _client((_) => gate.future),
        debounce: Duration.zero,
      );
      controller.search('place', language: 'en');
      await Future<void>.delayed(Duration.zero);
      controller.clear();
      gate.complete(_results('Late result', 1, 1));
      await Future<void>.delayed(Duration.zero);
      expect(controller.status, LocationLookupStatus.idle);
      expect(controller.results, isEmpty);
      controller.dispose();
    },
  );

  for (final state in [
    LocationLookupStatus.unconfigured,
    LocationLookupStatus.offline,
    LocationLookupStatus.rateLimited,
    LocationLookupStatus.failed,
  ]) {
    test('exposes ${state.name} state', () async {
      final now = DateTime.utc(2026);
      var first = true;
      final client = switch (state) {
        LocationLookupStatus.unconfigured => GeoapifyClient(
          client: _Transport((_) async => _results('unused', 0, 0)),
          apiKey: '',
          canUseNetwork: () async => true,
        ),
        LocationLookupStatus.offline => GeoapifyClient(
          client: _Transport((_) async => _results('unused', 0, 0)),
          apiKey: 'key',
          canUseNetwork: () async => false,
        ),
        LocationLookupStatus.rateLimited => GeoapifyClient(
          client: _Transport((_) async {
            if (first) {
              first = false;
              return http.StreamedResponse(
                const Stream<List<int>>.empty(),
                429,
                headers: {'retry-after': '60'},
              );
            }
            return _results('unused', 0, 0);
          }),
          apiKey: 'key',
          canUseNetwork: () async => true,
          now: () => now,
        ),
        _ => GeoapifyClient(
          client: _Transport(
            (_) async =>
                http.StreamedResponse(const Stream<List<int>>.empty(), 500),
          ),
          apiKey: 'key',
          canUseNetwork: () async => true,
        ),
      };
      final controller = LocationSearchController(client);
      addTearDown(controller.dispose);
      controller.search('place', language: 'en', submit: true);
      await _until(() => controller.status != LocationLookupStatus.loading);
      expect(controller.status, state);
    });
  }

  test('distinguishes an empty successful response', () async {
    final controller = LocationSearchController(
      _client((_) async => _emptyResults()),
    );
    addTearDown(controller.dispose);
    controller.search('place', language: 'en', submit: true);
    await _until(() => controller.status == LocationLookupStatus.empty);
    expect(controller.results, isEmpty);
  });
}

GeoapifyClient _client(
  Future<http.StreamedResponse> Function(http.BaseRequest request) handler,
) => GeoapifyClient(
  client: _Transport(handler),
  apiKey: 'key',
  canUseNetwork: () async => true,
);

http.StreamedResponse _results(String label, num lat, num lon) =>
    http.StreamedResponse(
      Stream.value(
        utf8.encode(
          jsonEncode({
            'results': [
              {'formatted': label, 'lat': lat, 'lon': lon},
            ],
          }),
        ),
      ),
      200,
    );

http.StreamedResponse _emptyResults() => http.StreamedResponse(
  Stream.value(utf8.encode(jsonEncode({'results': const []}))),
  200,
);

Future<void> _until(bool Function() condition) async {
  for (var attempt = 0; attempt < 100 && !condition(); attempt++) {
    await Future<void>.delayed(const Duration(milliseconds: 1));
  }
  expect(condition(), isTrue);
}

final class _Transport extends http.BaseClient {
  _Transport(this.handler);
  final Future<http.StreamedResponse> Function(http.BaseRequest request)
  handler;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      handler(request);
}

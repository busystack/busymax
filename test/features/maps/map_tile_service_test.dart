import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:busymax/src/features/maps/data/map_tile_service.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('accepts a valid image and returns its bounded bytes', () async {
    final png = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
    );
    var failures = 0;
    final transport = _Transport(
      (_) async => http.StreamedResponse(
        Stream.value(png),
        200,
        headers: {'cache-control': 'public, max-age=3600'},
        contentLength: png.length,
      ),
    );
    final client = MapTileClient(
      transport,
      canUseNetwork: () async => true,
      onFailure: () => failures++,
    );
    addTearDown(client.close);

    final response = await client.send(http.Request('GET', _tileUri));
    expect(await response.stream.toBytes(), png);
    expect(response.headers['cache-control'], 'public, max-age=3600');
    expect(failures, 0);
  });

  test(
    'rejects corrupt and oversized images with one stable failure',
    () async {
      var failures = 0;
      var oversized = false;
      final client = MapTileClient(
        _Transport((_) async {
          if (oversized) {
            return http.StreamedResponse(
              Stream.fromIterable([
                List<int>.filled(6, 0),
                List<int>.filled(6, 0),
              ]),
              200,
            );
          }
          return http.StreamedResponse(Stream.value([1, 2, 3]), 200);
        }),
        canUseNetwork: () async => true,
        onFailure: () => failures++,
        maximumResponseBytes: 10,
        timeout: const Duration(milliseconds: 100),
      );
      addTearDown(client.close);

      await expectLater(
        client.send(http.Request('GET', _tileUri)),
        throwsA(isA<MapTileException>()),
      );
      oversized = true;
      await expectLater(
        client.send(http.Request('GET', _tileUri)),
        throwsA(isA<MapTileException>()),
      );
      expect(failures, 1);
    },
  );

  test(
    'times out total body reading and suppresses errors after disposal',
    () async {
      var failures = 0;
      final body = StreamController<List<int>>();
      final transport = _Transport(
        (_) async => http.StreamedResponse(body.stream, 200),
      );
      final client = MapTileClient(
        transport,
        canUseNetwork: () async => true,
        onFailure: () => failures++,
        timeout: const Duration(milliseconds: 10),
      );

      await expectLater(
        client.send(http.Request('GET', _tileUri)),
        throwsA(isA<MapTileException>()),
      );
      expect(failures, 1);
      client.close();
      expect(transport.closed, isTrue);
      await expectLater(
        client.send(http.Request('GET', _tileUri)),
        throwsA(isA<MapTileException>()),
      );
      expect(failures, 1);
      await body.close();
    },
  );

  test('disposal cancels an in-flight tile body without waiting', () async {
    final body = StreamController<List<int>>();
    final client = MapTileClient(
      _Transport((_) async => http.StreamedResponse(body.stream, 200)),
      canUseNetwork: () async => true,
      onFailure: () {},
      timeout: const Duration(minutes: 1),
    );
    final pending = client.send(http.Request('GET', _tileUri));
    await Future<void>.delayed(Duration.zero);

    client.close();

    await expectLater(pending, throwsA(isA<MapTileException>()));
    await body.close();
  });

  test('rate limit blocks retries until the injected clock advances', () async {
    var now = DateTime.utc(2026);
    var requests = 0;
    final client = MapTileClient(
      _Transport((_) async {
        requests++;
        return http.StreamedResponse(
          const Stream<List<int>>.empty(),
          429,
          headers: {'retry-after': '30'},
        );
      }),
      canUseNetwork: () async => true,
      onFailure: () {},
      now: () => now,
    );
    addTearDown(client.close);

    for (var attempt = 0; attempt < 2; attempt++) {
      await expectLater(
        client.send(http.Request('GET', _tileUri)),
        throwsA(isA<MapTileException>()),
      );
    }
    expect(requests, 1);
    now = now.add(const Duration(seconds: 31));
    await expectLater(
      client.send(http.Request('GET', _tileUri)),
      throwsA(isA<MapTileException>()),
    );
    expect(requests, 2);
  });

  test('cache keys exclude credentials but separate style and resolution', () {
    const base = 'https://maps.geoapify.com/v1/tile/osm-bright/4/2/3';
    expect(
      mapTileCacheKey('$base.png?apiKey=first'),
      mapTileCacheKey('$base.png?apiKey=second'),
    );
    expect(
      mapTileCacheKey('$base.png?apiKey=first'),
      isNot(mapTileCacheKey('$base@2x.png?apiKey=first')),
    );
    expect(
      mapTileCacheKey('$base.png?apiKey=first'),
      isNot(
        mapTileCacheKey(
          'https://maps.geoapify.com/v1/tile/dark-matter/4/2/3.png?apiKey=first',
        ),
      ),
    );
  });

  test('built-in cache reuses a tile across credential changes', () async {
    final directory = await Directory.systemTemp.createTemp(
      'busymax-map-cache-',
    );
    final cache = BuiltInMapCachingProvider.getOrCreateInstance(
      cacheDirectory: directory.path,
      maxCacheSize: 100 * 1024 * 1024,
      tileKeyGenerator: mapTileCacheKey,
    );
    addTearDown(() => cache.destroy(deleteCache: true));
    final bytes = Uint8List.fromList(
      base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
      ),
    );
    const first =
        'https://maps.geoapify.com/v1/tile/osm-bright/4/2/3@2x.png?apiKey=first';
    const second =
        'https://maps.geoapify.com/v1/tile/osm-bright/4/2/3@2x.png?apiKey=second';
    await cache.putTile(
      url: first,
      metadata: CachedMapTileMetadata(
        staleAt: DateTime.now().add(const Duration(hours: 1)),
        lastModified: null,
        etag: null,
      ),
      bytes: bytes,
    );

    CachedMapTile? loaded;
    for (var attempt = 0; attempt < 100 && loaded == null; attempt++) {
      loaded = await cache.getTile(second);
      if (loaded == null) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
    }
    expect(loaded?.bytes, bytes);
    expect(loaded?.metadata.staleAt.isAfter(DateTime.now()), isTrue);
  });

  test('tile provider owns only its dedicated map transport', () async {
    final transport = _Transport(
      (_) async => http.StreamedResponse(const Stream.empty(), 304),
    );
    final client = MapTileClient(
      transport,
      canUseNetwork: () async => true,
      onFailure: () {},
    );
    final provider = BusyMaxMapTileProvider(
      client: client,
      cache: const DisabledMapCachingProvider(),
    );

    await provider.dispose();
    expect(transport.closed, isTrue);
  });
}

final _tileUri = Uri.parse(
  'https://maps.geoapify.com/v1/tile/osm-bright/4/2/3.png?apiKey=test',
);

final class _Transport extends http.BaseClient {
  _Transport(this.handler);
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

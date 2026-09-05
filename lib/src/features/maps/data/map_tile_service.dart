import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

/// Map-only transport. Never receives account authorization or shares the
/// synchronization client. Errors intentionally contain no request URL.
final class MapTileClient extends http.BaseClient {
  MapTileClient(this.inner, {required this.canUseNetwork, required this.onFailure});
  final http.Client inner;
  final Future<bool> Function() canUseNetwork;
  final VoidCallback onFailure;
  DateTime? _retryAfter;
  bool _closed = false;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    try {
      if (_closed || _retryAfter?.isAfter(DateTime.now()) == true || !await canUseNetwork()) throw const MapTileException();
      final response = await inner.send(request).timeout(const Duration(seconds: 8));
      if (response.statusCode == 429) {
        final seconds = int.tryParse(response.headers['retry-after'] ?? '') ?? 60;
        _retryAfter = DateTime.now().add(Duration(seconds: seconds.clamp(1, 3600)));
      }
      if (response.statusCode != 200 && response.statusCode != 304) throw const MapTileException();
      final bytes = await response.stream.toBytes().timeout(const Duration(seconds: 8));
      if (bytes.length > 4 * 1024 * 1024) throw const MapTileException();
      if (response.statusCode == 200) {
        // Do not admit corrupt responses into the persistent tile cache.
        final codec = await ui.instantiateImageCodec(Uint8List.fromList(bytes));
        codec.dispose();
      }
      return http.StreamedResponse(Stream.value(bytes), response.statusCode, headers: response.headers, contentLength: bytes.length);
    } on Object {
      if (!_closed) onFailure();
      throw const MapTileException();
    }
  }
  @override
  void close() { _closed = true; inner.close(); }
}

final class MapTileException implements Exception {
  const MapTileException();
  @override
  String toString() => 'Map tiles unavailable';
}

Future<MapCachingProvider> createMapTileCache() async {
  try {
    final directory = await getApplicationCacheDirectory();
    return BuiltInMapCachingProvider.getOrCreateInstance(
      cacheDirectory: path.join(directory.path, 'maps'),
      maxCacheSize: 100 * 1024 * 1024,
      // Keys must not contain credentials. Styles and retina paths stay distinct.
      tileKeyGenerator: (url) => BuiltInMapCachingProvider.uuidTileKeyGenerator(Uri.parse(url).replace(query: '').toString()),
    );
  } on Object {
    return const DisabledMapCachingProvider();
  }
}

/// Owns its dedicated client; disposal cannot close the account transport.
final class BusyMaxMapTileProvider extends NetworkTileProvider {
  BusyMaxMapTileProvider({required MapTileClient client, required MapCachingProvider cache}) : _client = client, super(httpClient: client, cachingProvider: cache, silenceExceptions: true);
  final MapTileClient _client;
  @override
  Future<void> dispose() async { _client.close(); await super.dispose(); }
}

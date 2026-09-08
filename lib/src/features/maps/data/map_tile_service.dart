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
  MapTileClient(
    this.inner, {
    required this.canUseNetwork,
    required this.onFailure,
    this.timeout = const Duration(seconds: 8),
    this.maximumResponseBytes = 4 * 1024 * 1024,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;
  final http.Client inner;
  final Future<bool> Function() canUseNetwork;
  final VoidCallback onFailure;
  final Duration timeout;
  final int maximumResponseBytes;
  final DateTime Function() _now;
  DateTime? _retryAfter;
  bool _closed = false;
  bool _failureReported = false;
  final _closedSignal = Completer<void>();
  final Set<VoidCallback> _cancelBodyReads = {};
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    try {
      if (_closed ||
          _retryAfter?.isAfter(_now()) == true ||
          !await canUseNetwork()) {
        throw const MapTileException();
      }
      final response = await Future.any<http.StreamedResponse>([
        inner.send(request),
        _closedSignal.future.then((_) => throw const MapTileException()),
      ]).timeout(timeout);
      if (response.statusCode == 429) {
        final seconds =
            int.tryParse(response.headers['retry-after'] ?? '') ?? 60;
        _retryAfter = _now().add(Duration(seconds: seconds.clamp(1, 3600)));
      }
      if (response.statusCode != 200 && response.statusCode != 304) {
        throw const MapTileException();
      }
      if ((response.contentLength ?? 0) > maximumResponseBytes) {
        throw const MapTileException();
      }
      final bytes = await _readResponseBody(response.stream);
      if (response.statusCode == 200) {
        // Do not admit corrupt responses into the persistent tile cache.
        final codec = await ui
            .instantiateImageCodec(Uint8List.fromList(bytes))
            .timeout(timeout);
        codec.dispose();
      }
      return http.StreamedResponse(
        Stream.value(bytes),
        response.statusCode,
        headers: response.headers,
        contentLength: bytes.length,
      );
    } on Object {
      if (!_closed && !_failureReported) {
        _failureReported = true;
        onFailure();
      }
      throw const MapTileException();
    }
  }

  Future<List<int>> _readResponseBody(Stream<List<int>> stream) {
    final completer = Completer<List<int>>();
    final bytes = <int>[];
    Timer? timer;
    late final StreamSubscription<List<int>> subscription;

    void fail(Object error, [StackTrace? stackTrace]) {
      if (completer.isCompleted) return;
      timer?.cancel();
      unawaited(subscription.cancel());
      completer.completeError(error, stackTrace);
    }

    subscription = stream.listen(
      (chunk) {
        if (bytes.length + chunk.length > maximumResponseBytes) {
          fail(const MapTileException());
          return;
        }
        bytes.addAll(chunk);
      },
      onError: fail,
      onDone: () {
        if (completer.isCompleted) return;
        timer?.cancel();
        completer.complete(bytes);
      },
      cancelOnError: true,
    );
    timer = Timer(
      timeout,
      () => fail(TimeoutException('Map tile body read timed out')),
    );
    void cancelRead() => fail(const MapTileException());
    _cancelBodyReads.add(cancelRead);
    unawaited(
      completer.future.then<void>(
        (_) => _cancelBodyReads.remove(cancelRead),
        onError: (Object _, StackTrace _) {
          _cancelBodyReads.remove(cancelRead);
        },
      ),
    );
    return completer.future;
  }

  @override
  void close() {
    if (_closed) return;
    _closed = true;
    _closedSignal.complete();
    for (final cancel in _cancelBodyReads.toList()) {
      cancel();
    }
    inner.close();
  }
}

final class MapTileException implements Exception {
  const MapTileException();
  @override
  String toString() => 'Map tiles unavailable';
}

String mapTileCacheKey(
  String url,
) => BuiltInMapCachingProvider.uuidTileKeyGenerator(
  // Search credentials never influence cached content identity. The path keeps
  // style, z/x/y, and native @2x resolution distinct.
  Uri.parse(url).replace(query: '').toString(),
);

Future<MapCachingProvider> createMapTileCache() async {
  try {
    final directory = await getApplicationCacheDirectory();
    return BuiltInMapCachingProvider.getOrCreateInstance(
      cacheDirectory: path.join(directory.path, 'maps'),
      maxCacheSize: 100 * 1024 * 1024,
      // Keys must not contain credentials. Styles and retina paths stay distinct.
      tileKeyGenerator: mapTileCacheKey,
    );
  } on Object {
    return const DisabledMapCachingProvider();
  }
}

/// Owns its dedicated client; disposal cannot close the account transport.
final class BusyMaxMapTileProvider extends NetworkTileProvider {
  BusyMaxMapTileProvider({
    required MapTileClient client,
    required MapCachingProvider cache,
  }) : _client = client,
       super(
         httpClient: client,
         cachingProvider: cache,
         silenceExceptions: true,
       );
  final MapTileClient _client;
  @override
  Future<void> dispose() async {
    _client.close();
    await super.dispose();
  }
}

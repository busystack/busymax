import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../domain/geographic_point.dart';
import '../domain/location_result.dart';

enum LocationLookupStatus {
  idle,
  loading,
  results,
  empty,
  offline,
  unconfigured,
  rateLimited,
  failed,
}

final class LocationLookupException implements Exception {
  const LocationLookupException(this.status);
  final LocationLookupStatus status;
  @override
  String toString() => 'Location lookup: ${status.name}';
}

final class LocationRequestCancellation {
  final _cancelled = Completer<void>();
  Future<void> get future => _cancelled.future;
  bool get cancelled => _cancelled.isCompleted;
  void cancel() {
    if (!cancelled) _cancelled.complete();
  }
}

/// Unauthenticated mapping transport, independent of all calendar clients.
/// The composition root owns [client]; individual searches never close it.
final class GeoapifyClient {
  GeoapifyClient({
    required http.Client client,
    required this.apiKey,
    required this.canUseNetwork,
    DateTime Function()? now,
    this.timeout = const Duration(seconds: 8),
  }) : _client = client,
       _now = now ?? DateTime.now;
  final http.Client _client;
  final String apiKey;
  final Future<bool> Function() canUseNetwork;
  final DateTime Function() _now;
  final Duration timeout;
  DateTime? _retryAfter;
  bool get configured => apiKey.trim().isNotEmpty;

  Future<List<LocationResult>> search(
    String text, {
    required String language,
    bool autocomplete = true,
    LocationRequestCancellation? cancellation,
  }) async {
    if (text.trim().isEmpty) return const [];
    if (!configured) {
      throw const LocationLookupException(LocationLookupStatus.unconfigured);
    }
    if (_retryAfter?.isAfter(_now()) == true) {
      throw const LocationLookupException(LocationLookupStatus.rateLimited);
    }
    if (!await canUseNetwork()) {
      throw const LocationLookupException(LocationLookupStatus.offline);
    }
    final token = cancellation ?? LocationRequestCancellation();
    if (token.cancelled) return const [];
    final uri = Uri.https(
      'api.geoapify.com',
      '/v1/geocode/${autocomplete ? 'autocomplete' : 'search'}',
      {
        'text': text.trim(),
        'format': 'json',
        'limit': '5',
        'apiKey': apiKey,
        if (RegExp(
          r'^[a-z]{2}$',
        ).hasMatch(language.split(RegExp('[-_]')).first.toLowerCase()))
          'lang': language.split(RegExp('[-_]')).first.toLowerCase(),
      },
    );
    try {
      final response =
          await (() async {
            final send = _client.send(
              http.AbortableRequest('GET', uri, abortTrigger: token.future)
                ..headers['Accept'] = 'application/json',
            );
            final stream = await Future.any<http.StreamedResponse>([
              send,
              token.future.then((_) => throw const _LocationRequestCancelled()),
            ]);
            if (stream.statusCode == 429) {
              final seconds =
                  int.tryParse(stream.headers['retry-after'] ?? '') ?? 60;
              _retryAfter = _now().add(
                Duration(seconds: seconds.clamp(1, 3600)),
              );
              token.cancel();
              throw const LocationLookupException(
                LocationLookupStatus.rateLimited,
              );
            }
            if (stream.statusCode != 200) {
              token.cancel();
              throw const LocationLookupException(LocationLookupStatus.failed);
            }
            final bytes = await _readBoundedBody(stream.stream, token);
            return jsonDecode(utf8.decode(bytes));
          })().timeout(
            timeout,
            onTimeout: () {
              token.cancel();
              throw const LocationLookupException(LocationLookupStatus.failed);
            },
          );
      if (token.cancelled) return const [];
      if (response is! Map || response['results'] is! List) {
        throw const LocationLookupException(LocationLookupStatus.failed);
      }
      final results = <LocationResult>[];
      for (final value in response['results'] as List) {
        if (value is! Map) continue;
        final point = GeographicPoint.tryParse(
          latitude: value['lat'],
          longitude: value['lon'],
        );
        final formatted = value['formatted']?.toString().trim();
        final name = value['name']?.toString().trim();
        final label = formatted?.isNotEmpty == true
            ? formatted!
            : name?.isNotEmpty == true
            ? name!
            : '';
        if (point == null || label.isEmpty) continue;
        final datasource = value['datasource'];
        final suppliedAttribution = datasource is Map
            ? datasource['attribution']?.toString()
            : null;
        results.add(
          LocationResult(
            label: label,
            point: point,
            name: name?.isNotEmpty == true ? name : null,
            formattedAddress: formatted?.isNotEmpty == true ? formatted : null,
            resultType: value['result_type']?.toString() ?? '',
            address: Map.unmodifiable({
              if (value['street'] != null)
                'street': [
                  value['housenumber'],
                  value['street'],
                ].whereType<String>().join(' '),
              for (final (target, source) in [
                ('city', 'city'),
                ('state', 'state'),
                ('postalCode', 'postcode'),
                ('countryOrRegion', 'country'),
              ])
                if (value[source] is String) target: value[source] as String,
            }),
            attribution: suppliedAttribution == null
                ? 'Powered by Geoapify | © OpenStreetMap contributors'
                : 'Powered by Geoapify | $suppliedAttribution',
          ),
        );
        if (results.length == 5) break;
      }
      return List.unmodifiable(results);
    } on LocationLookupException {
      rethrow;
    } on http.RequestAbortedException {
      return const [];
    } on _LocationRequestCancelled {
      return const [];
    } on Object {
      throw const LocationLookupException(LocationLookupStatus.failed);
    }
  }

  Future<List<int>> _readBoundedBody(
    Stream<List<int>> stream,
    LocationRequestCancellation token,
  ) {
    final completer = Completer<List<int>>();
    final bytes = <int>[];
    late final StreamSubscription<List<int>> subscription;

    void fail(Object error, [StackTrace? stackTrace]) {
      if (completer.isCompleted) return;
      unawaited(subscription.cancel());
      completer.completeError(error, stackTrace);
    }

    subscription = stream.listen(
      (chunk) {
        if (bytes.length + chunk.length > 1024 * 1024) {
          fail(const LocationLookupException(LocationLookupStatus.failed));
          return;
        }
        bytes.addAll(chunk);
      },
      onError: fail,
      onDone: () {
        if (!completer.isCompleted) completer.complete(bytes);
      },
      cancelOnError: true,
    );
    unawaited(
      token.future.then((_) => fail(const _LocationRequestCancelled())),
    );
    return completer.future;
  }
}

final class _LocationRequestCancelled implements Exception {
  const _LocationRequestCancelled();
}

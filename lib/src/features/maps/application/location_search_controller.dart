import 'dart:async';
import 'package:flutter/foundation.dart';

import '../data/geoapify_client.dart';
import '../domain/location_result.dart';

final class LocationSearchController extends ChangeNotifier {
  LocationSearchController(
    this.client, {
    this.debounce = const Duration(milliseconds: 300),
  });
  final GeoapifyClient client;
  final Duration debounce;
  LocationLookupStatus status = LocationLookupStatus.idle;
  List<LocationResult> results = const [];
  Timer? _timer;
  LocationRequestCancellation? _request;
  var _generation = 0;
  var _disposed = false;

  /// Called for user input only, never initialization or provider projection.
  void search(
    String text, {
    required String language,
    bool composing = false,
    bool submit = false,
    bool autocomplete = true,
  }) {
    clear();
    if (composing ||
        text.trim().isEmpty ||
        (!submit && text.trim().runes.length < 3)) {
      return;
    }
    final generation = _generation;
    Future<void> run() async {
      if (_disposed || generation != _generation) return;
      final request = _request = LocationRequestCancellation();
      status = LocationLookupStatus.loading;
      notifyListeners();
      try {
        final found = await client.search(
          text,
          language: language,
          autocomplete: autocomplete,
          cancellation: request,
        );
        if (_disposed || generation != _generation) return;
        results = found;
        status = found.isEmpty
            ? LocationLookupStatus.empty
            : LocationLookupStatus.results;
      } on LocationLookupException catch (error) {
        if (_disposed || generation != _generation) return;
        status = error.status;
      }
      if (!_disposed && generation == _generation) notifyListeners();
    }

    if (submit) {
      unawaited(run());
    } else {
      _timer = Timer(debounce, run);
    }
  }

  void clear() {
    _generation++;
    _timer?.cancel();
    _request?.cancel();
    results = const [];
    status = LocationLookupStatus.idle;
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    clear();
    super.dispose();
  }
}

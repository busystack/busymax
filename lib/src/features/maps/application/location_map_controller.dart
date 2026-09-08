import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/geoapify_client.dart';
import '../domain/geographic_point.dart';
import '../domain/location_result.dart';
import 'location_destination_resolver.dart';

final class LocationMapController extends ChangeNotifier {
  LocationMapController({
    required this.client,
    required this.resolver,
    required this.location,
    required this.locationChange,
    this.nativePoint,
    this.identity,
    this.language = 'en',
  });

  final GeoapifyClient client;
  final LocationDestinationResolver resolver;
  final String location;
  final LocationChange locationChange;
  final GeographicPoint? nativePoint;
  final LocationItemIdentity? identity;
  final String language;

  LocationLookupStatus status = LocationLookupStatus.loading;
  LocationResult? destination;
  LocationResult? chosenSelection;
  List<LocationResult> choices = const [];
  bool tileFailure = false;
  LocationRequestCancellation? _request;
  bool _disposed = false;

  Future<void> load() async {
    _request?.cancel();
    final request = _request = LocationRequestCancellation();
    status = LocationLookupStatus.loading;
    choices = const [];
    _notify();
    final known = await resolver.knownDestination(
      location: location,
      change: locationChange,
      nativePoint: nativePoint,
      identity: identity,
    );
    if (_disposed || request.cancelled || request != _request) return;
    if (known != null) {
      destination = known;
      status = client.configured
          ? LocationLookupStatus.results
          : LocationLookupStatus.unconfigured;
      _notify();
      return;
    }
    if (location.trim().isEmpty) {
      status = LocationLookupStatus.empty;
      _notify();
      return;
    }
    try {
      final found = await client.search(
        location,
        language: language,
        autocomplete: false,
        cancellation: request,
      );
      if (_disposed || request.cancelled || request != _request) return;
      if (found.length == 1) {
        destination = found.single;
        status = LocationLookupStatus.results;
      } else {
        choices = found;
        status = found.isEmpty
            ? LocationLookupStatus.empty
            : LocationLookupStatus.results;
      }
    } on LocationLookupException catch (error) {
      if (_disposed || request.cancelled || request != _request) return;
      status = error.status;
    }
    _notify();
  }

  void choose(LocationResult result) {
    _request?.cancel();
    chosenSelection = result;
    destination = result;
    choices = const [];
    status = client.configured
        ? LocationLookupStatus.results
        : LocationLookupStatus.unconfigured;
    _notify();
  }

  void reportTileFailure() {
    if (tileFailure || _disposed) return;
    tileFailure = true;
    notifyListeners();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _request?.cancel();
    super.dispose();
  }
}

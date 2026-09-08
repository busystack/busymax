import '../data/location_resolution_repository.dart';
import '../domain/geographic_point.dart';
import '../domain/location_result.dart';

/// Resolves only already-known destinations. Network lookup is an explicit UI
/// action and remains separate so opening ordinary details never sends data.
final class LocationDestinationResolver {
  const LocationDestinationResolver(this.repository);

  final LocationResolutionRepository repository;

  Future<LocationResult?> knownDestination({
    required String location,
    required LocationChange change,
    GeographicPoint? nativePoint,
    LocationItemIdentity? identity,
  }) async {
    if (change.changed) return change.selection;
    if (nativePoint != null) {
      return LocationResult(
        label: location.trim().isEmpty
            ? nativePoint.directionsValue
            : location.trim(),
        point: nativePoint,
        resultType: 'provider',
        source: 'provider',
        attribution: '',
      );
    }
    if (identity == null) return null;
    return repository.load(identity, location);
  }
}

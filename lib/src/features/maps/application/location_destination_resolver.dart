import '../data/location_resolution_repository.dart';
import '../domain/geographic_point.dart';
import '../domain/location_result.dart';
import 'external_location_launcher.dart';

/// Resolves a destination strictly from the saved item snapshot.
///
/// This class performs no network lookup and makes no persistence writes.
final class LocationDestinationResolver {
  const LocationDestinationResolver(this.repository);

  final LocationResolutionRepository repository;

  Future<ExternalLocationDestination?> resolveSaved({
    required String location,
    GeographicPoint? nativePoint,
    LocationItemIdentity? identity,
  }) async {
    final link = completeHttpLocationUri(location);
    if (link != null) return ExternalLocationDestination.link(link);
    if (nativePoint != null) {
      return ExternalLocationDestination.coordinates(nativePoint);
    }
    if (identity != null) {
      try {
        final remembered = await repository.load(identity, location);
        if (remembered != null) {
          return ExternalLocationDestination.coordinates(remembered.point);
        }
      } on Object {
        // Provider-native points and text remain useful if local supplemental
        // storage is temporarily unavailable.
      }
    }
    if (location.trim().isEmpty) return null;
    return ExternalLocationDestination.text(location);
  }
}

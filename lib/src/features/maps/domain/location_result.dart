import 'package:collection/collection.dart';
import 'geographic_point.dart';

/// A deliberately small projection, never the original search response.
final class LocationResult {
  const LocationResult({
    required this.label,
    required this.point,
    this.resultType = '',
    this.address = const {},
    this.attribution = 'Powered by Geoapify | © OpenStreetMap contributors',
    this.source = 'geoapify',
  });
  final String label;
  final GeographicPoint point;
  final String resultType;
  final Map<String, String> address;
  final String source;
  final String attribution;
  bool get approximate => !{'building', 'amenity'}.contains(resultType);
  Map<String, Object?> get microsoftLocation => {
    'displayName': label,
    'coordinates': point.toJson(),
    'address': {
      for (final key in [
        'street',
        'city',
        'state',
        'postalCode',
        'countryOrRegion',
      ])
        if (address[key]?.isNotEmpty == true) key: address[key],
    },
  };
  @override
  bool operator ==(Object other) =>
      other is LocationResult &&
      label == other.label &&
      point == other.point &&
      source == other.source &&
      attribution == other.attribution &&
      resultType == other.resultType &&
      const MapEquality<String, String>().equals(address, other.address);
  @override
  int get hashCode => Object.hash(
    label,
    point,
    source,
    attribution,
    resultType,
    const MapEquality<String, String>().hash(address),
  );
}

/// Distinguishes no edit from a replacement (including same-label pins) and
/// explicit removal. This value stays in drafts until a local save succeeds.
final class LocationChange {
  const LocationChange.unchanged() : changed = false, selection = null;
  const LocationChange.replace(this.selection) : changed = true;
  const LocationChange.clear() : changed = true, selection = null;
  final bool changed;
  final LocationResult? selection;
  @override
  bool operator ==(Object other) =>
      other is LocationChange &&
      changed == other.changed &&
      selection == other.selection;
  @override
  int get hashCode => Object.hash(changed, selection);
}

enum LocationItemKind { event, task }

final class LocationItemIdentity {
  const LocationItemIdentity({
    required this.kind,
    required this.accountId,
    required this.sourceId,
    required this.itemId,
  });
  final LocationItemKind kind;
  final String accountId;
  final String sourceId;
  final String itemId;
  @override
  bool operator ==(Object other) =>
      other is LocationItemIdentity &&
      kind == other.kind &&
      accountId == other.accountId &&
      sourceId == other.sourceId &&
      itemId == other.itemId;
  @override
  int get hashCode => Object.hash(kind, accountId, sourceId, itemId);
}

Uri googleMapsDirectionsUri({
  required String location,
  GeographicPoint? point,
}) => Uri.https('www.google.com', '/maps/dir/', {
  'api': '1',
  'destination': point?.directionsValue ?? location,
});

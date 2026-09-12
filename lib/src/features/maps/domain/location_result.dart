import 'package:collection/collection.dart';
import 'geographic_point.dart';

/// Coordinate metadata retained for imports, copies, and existing records.
final class LocationResult {
  const LocationResult({
    required this.label,
    required this.point,
    this.address = const {},
    this.attribution = '',
    this.source = 'provider',
  });
  final String label;
  final GeographicPoint point;

  final Map<String, String> address;
  final String source;
  final String attribution;
  @override
  bool operator ==(Object other) =>
      other is LocationResult &&
      label == other.label &&
      point == other.point &&
      source == other.source &&
      attribution == other.attribution &&
      const MapEquality<String, String>().equals(address, other.address);
  @override
  int get hashCode => Object.hash(
    label,
    point,
    source,
    attribution,
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

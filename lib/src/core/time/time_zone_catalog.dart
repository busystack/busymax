import 'package:flutter/foundation.dart';
import 'package:timezone/data/latest.dart' as time_zone_data;
import 'package:timezone/timezone.dart' as time_zone;

@immutable
class BusyMaxTimeZoneLocation {
  const BusyMaxTimeZoneLocation({
    required this.id,
    required this.region,
    required this.name,
    required this.code,
    required this.offset,
  });

  final String id;
  final String region;
  final String name;
  final String code;
  final Duration offset;

  String get displayLabel => '$id ($code)';

  bool matches(String query) {
    final normalized = query.trim().toLowerCase();
    return normalized.isEmpty ||
        id.toLowerCase().contains(normalized) ||
        region.toLowerCase().contains(normalized) ||
        name.toLowerCase().contains(normalized) ||
        code.toLowerCase().contains(normalized);
  }
}

abstract final class BusyMaxTimeZoneCatalog {
  static List<BusyMaxTimeZoneLocation>? _locations;

  static List<BusyMaxTimeZoneLocation> get locations {
    return _locations ??= _buildLocations();
  }

  static BusyMaxTimeZoneLocation location(String id) {
    final normalized = id == 'UTC' ? 'Etc/UTC' : id;
    return locations.firstWhere(
      (location) => location.id == normalized,
      orElse: () {
        final parts = normalized.split('/');
        return BusyMaxTimeZoneLocation(
          id: normalized,
          region: _readableSegment(parts.first),
          name: parts.skip(1).map(_readableSegment).join(' / '),
          code: normalized,
          offset: Duration.zero,
        );
      },
    );
  }

  static List<BusyMaxTimeZoneLocation> search(String query, {int limit = 80}) {
    if (query.trim().isEmpty) {
      return const [];
    }
    return locations
        .where((location) => location.matches(query))
        .take(limit)
        .toList();
  }

  static List<BusyMaxTimeZoneLocation> _buildLocations() {
    time_zone_data.initializeTimeZones();
    final instant = DateTime.now().millisecondsSinceEpoch;
    final locations = <BusyMaxTimeZoneLocation>[
      const BusyMaxTimeZoneLocation(
        id: 'Etc/UTC',
        region: 'UTC',
        name: 'UTC',
        code: 'UTC',
        offset: Duration.zero,
      ),
    ];

    for (final entry in time_zone.timeZoneDatabase.locations.entries) {
      final id = entry.key;
      if (!_isUserFacingLocation(id)) {
        continue;
      }
      final parts = id.split('/');
      final zone = entry.value.timeZone(instant);
      locations.add(
        BusyMaxTimeZoneLocation(
          id: id,
          region: _readableSegment(parts.first),
          name: parts.skip(1).map(_readableSegment).join(' / '),
          code: zone.abbreviation,
          offset: zone.offset,
        ),
      );
    }

    locations.sort((a, b) {
      if (a.id == 'Etc/UTC') {
        return -1;
      }
      if (b.id == 'Etc/UTC') {
        return 1;
      }
      final regionOrder = a.region.compareTo(b.region);
      return regionOrder != 0 ? regionOrder : a.name.compareTo(b.name);
    });
    return List.unmodifiable(locations);
  }

  static bool _isUserFacingLocation(String id) {
    return id.contains('/') &&
        id != 'Etc/UTC' &&
        !id.startsWith('Etc/') &&
        !id.startsWith('SystemV/') &&
        !id.startsWith('US/');
  }

  static String _readableSegment(String value) {
    return value.replaceAll('_', ' ');
  }
}

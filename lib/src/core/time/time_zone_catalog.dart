import 'package:flutter/foundation.dart' show immutable, visibleForTesting;
import 'package:timezone/data/latest_all.dart' as time_zone_data;
import 'package:timezone/timezone.dart' as time_zone;

import 'linux_gweather_location_source.dart';

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

@immutable
class BusyMaxTimeZoneSearchResult {
  const BusyMaxTimeZoneSearchResult({
    required this.location,
    required this.name,
    this.englishName,
    this.countryCode,
  });

  final BusyMaxTimeZoneLocation location;
  final String name;
  final String? englishName;
  final String? countryCode;

  String get title => '$name (${location.code})';

  String get subtitle {
    final country = countryCode;
    return country == null ? location.id : '${location.id} - $country';
  }

  String get searchText => <String>{
    name,
    if (englishName != null) englishName!,
    if (countryCode != null) countryCode!,
    if (englishName == null) ...[
      location.id,
      location.region,
      location.name,
      location.code,
    ],
  }.join('\n');
}

abstract final class BusyMaxTimeZoneCatalog {
  static List<BusyMaxTimeZoneLocation>? _locations;
  static Map<String, BusyMaxTimeZoneLocation>? _locationsById;
  static List<BusyMaxSystemTimeZoneLocation>? _systemLocations;
  static Future<List<BusyMaxSystemTimeZoneLocation>>? _systemLocationLoad;
  static List<BusyMaxTimeZoneSearchResult>? _locationSearchOptions;

  static List<BusyMaxTimeZoneLocation> get locations {
    return _locations ??= _buildLocations();
  }

  static BusyMaxTimeZoneLocation location(String id) {
    final normalized = id == 'UTC' ? 'Etc/UTC' : id;
    final knownLocation = _locationMap[normalized];
    if (knownLocation != null) {
      return knownLocation;
    }
    final parts = normalized.split('/');
    return BusyMaxTimeZoneLocation(
      id: normalized,
      region: _readableSegment(parts.first),
      name: parts.skip(1).map(_readableSegment).join(' / '),
      code: normalized,
      offset: Duration.zero,
    );
  }

  static List<BusyMaxTimeZoneLocation> search(String query) {
    if (query.trim().isEmpty) {
      return const [];
    }
    return locations.where((location) => location.matches(query)).toList();
  }

  static bool get isLocationSearchReady => _systemLocations != null;

  static Future<void> prepareLocationSearch() async {
    final load = _systemLocationLoad ??= loadLinuxSystemTimeZoneLocations();
    _systemLocations ??= await load;
  }

  static Future<List<BusyMaxTimeZoneSearchResult>> searchLocations(
    String query,
  ) async {
    await prepareLocationSearch();
    return searchPreparedLocations(query);
  }

  static List<BusyMaxTimeZoneSearchResult> get preparedLocationOptions {
    return _locationSearchOptions ??= _buildLocationSearchOptions();
  }

  static List<BusyMaxTimeZoneSearchResult> searchPreparedLocations(
    String query,
  ) {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) {
      return const [];
    }

    final results = <BusyMaxTimeZoneSearchResult>[];
    final seen = <String>{};

    if (normalized.length >= 2) {
      for (final systemLocation
          in _systemLocations ?? const <BusyMaxSystemTimeZoneLocation>[]) {
        if (!systemLocation.matches(normalized)) {
          continue;
        }
        final result = BusyMaxTimeZoneSearchResult(
          location: location(systemLocation.timeZoneId),
          name: systemLocation.name,
          englishName: systemLocation.englishName,
          countryCode: systemLocation.countryCode,
        );
        if (seen.add(_resultKey(result))) {
          results.add(result);
        }
      }
    }

    for (final timeZoneLocation in search(query)) {
      final result = BusyMaxTimeZoneSearchResult(
        location: timeZoneLocation,
        name: timeZoneLocation.name,
      );
      if (seen.add(_resultKey(result))) {
        results.add(result);
      }
    }

    results.sort((a, b) {
      final matchOrder = _matchRank(
        a,
        normalized,
      ).compareTo(_matchRank(b, normalized));
      if (matchOrder != 0) {
        return matchOrder;
      }
      final regionOrder = a.location.region.compareTo(b.location.region);
      if (regionOrder != 0) {
        return regionOrder;
      }
      final nameOrder = a.name.compareTo(b.name);
      return nameOrder != 0
          ? nameOrder
          : a.location.id.compareTo(b.location.id);
    });
    return results;
  }

  static Map<String, BusyMaxTimeZoneLocation> get _locationMap {
    return _locationsById ??= {
      for (final location in locations) location.id: location,
    };
  }

  static String _resultKey(BusyMaxTimeZoneSearchResult result) {
    return '${result.location.id}\u0000${result.name.toLowerCase()}';
  }

  static int _matchRank(
    BusyMaxTimeZoneSearchResult result,
    String normalizedQuery,
  ) {
    final names = <String>{
      result.name.toLowerCase(),
      if (result.englishName != null) result.englishName!.toLowerCase(),
    };
    if (names.contains(normalizedQuery)) {
      return 0;
    }
    if (names.any((name) => name.startsWith(normalizedQuery))) {
      return 1;
    }
    if (names.any((name) => name.contains(normalizedQuery))) {
      return 2;
    }
    return 3;
  }

  static List<BusyMaxTimeZoneSearchResult> _buildLocationSearchOptions() {
    final results = <BusyMaxTimeZoneSearchResult>[];
    final seen = <String>{};

    for (final systemLocation
        in _systemLocations ?? const <BusyMaxSystemTimeZoneLocation>[]) {
      final result = BusyMaxTimeZoneSearchResult(
        location: location(systemLocation.timeZoneId),
        name: systemLocation.name,
        englishName: systemLocation.englishName,
        countryCode: systemLocation.countryCode,
      );
      if (seen.add(_resultKey(result))) {
        results.add(result);
      }
    }

    for (final timeZoneLocation in locations) {
      final result = BusyMaxTimeZoneSearchResult(
        location: timeZoneLocation,
        name: timeZoneLocation.name,
      );
      if (seen.add(_resultKey(result))) {
        results.add(result);
      }
    }

    results.sort((a, b) {
      final regionOrder = a.location.region.compareTo(b.location.region);
      if (regionOrder != 0) {
        return regionOrder;
      }
      final nameOrder = a.name.compareTo(b.name);
      return nameOrder != 0
          ? nameOrder
          : a.location.id.compareTo(b.location.id);
    });
    return List.unmodifiable(results);
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
        !id.startsWith('SystemV/');
  }

  static String _readableSegment(String value) {
    return value.replaceAll('_', ' ');
  }

  @visibleForTesting
  static void setSystemLocationsForTesting(
    List<BusyMaxSystemTimeZoneLocation>? locations,
  ) {
    _systemLocations = locations == null ? null : List.unmodifiable(locations);
    _locationSearchOptions = null;
    _systemLocationLoad = locations == null
        ? null
        : Future.value(_systemLocations);
  }
}

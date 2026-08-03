import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/foundation.dart';

@immutable
class BusyMaxSystemTimeZoneLocation {
  const BusyMaxSystemTimeZoneLocation({
    required this.name,
    required this.englishName,
    required this.countryCode,
    required this.timeZoneId,
  });

  final String name;
  final String englishName;
  final String? countryCode;
  final String timeZoneId;

  bool matches(String normalizedQuery) {
    return name.toLowerCase().contains(normalizedQuery) ||
        englishName.toLowerCase().contains(normalizedQuery);
  }
}

Future<List<BusyMaxSystemTimeZoneLocation>>
loadLinuxSystemTimeZoneLocations() async {
  if (!Platform.isLinux) {
    return const [];
  }

  try {
    return await Isolate.run(_loadGWeatherLocations);
  } on Object {
    // libgweather is an optional runtime integration. The IANA catalog remains
    // available when the library or its location database is not installed.
    return const [];
  }
}

List<BusyMaxSystemTimeZoneLocation> _loadGWeatherLocations() {
  final api = _GWeatherApi();
  final world = api.getWorld();
  if (world == nullptr) {
    return const [];
  }

  final locations = <BusyMaxSystemTimeZoneLocation>[];
  try {
    _collectCities(api, world, locations);
  } finally {
    api.unref(world.cast<Void>());
  }

  locations.sort((a, b) {
    final nameOrder = a.name.compareTo(b.name);
    if (nameOrder != 0) {
      return nameOrder;
    }
    final countryOrder = (a.countryCode ?? '').compareTo(b.countryCode ?? '');
    return countryOrder != 0
        ? countryOrder
        : a.timeZoneId.compareTo(b.timeZoneId);
  });
  return List.unmodifiable(locations);
}

void _collectCities(
  _GWeatherApi api,
  Pointer<_GWeatherLocation> parent,
  List<BusyMaxSystemTimeZoneLocation> locations,
) {
  var child = nullptr.cast<_GWeatherLocation>();
  while (true) {
    child = api.nextChild(parent, child);
    if (child == nullptr) {
      return;
    }

    if (api.getLevel(child) == _GWeatherLocationLevel.city) {
      final name = _readUtf8(api.getName(child));
      final englishName = _readUtf8(api.getEnglishName(child));
      final timeZoneId = _readUtf8(api.getTimeZoneId(child));
      if (name != null && englishName != null && timeZoneId != null) {
        locations.add(
          BusyMaxSystemTimeZoneLocation(
            name: name,
            englishName: englishName,
            countryCode: _readUtf8(api.getCountryCode(child)),
            timeZoneId: timeZoneId,
          ),
        );
      }
      continue;
    }

    _collectCities(api, child, locations);
  }
}

String? _readUtf8(Pointer<Void> value) {
  if (value == nullptr) {
    return null;
  }

  final bytes = value.cast<Uint8>();
  var length = 0;
  while (length < 65536 && (bytes + length).value != 0) {
    length += 1;
  }
  if (length == 0 || length == 65536) {
    return null;
  }
  return utf8.decode(bytes.asTypedList(length), allowMalformed: true);
}

abstract final class _GWeatherLocationLevel {
  static const city = 4;
}

final class _GWeatherLocation extends Opaque {}

typedef _GetWorldNative = Pointer<_GWeatherLocation> Function();
typedef _GetWorldDart = Pointer<_GWeatherLocation> Function();
typedef _NextChildNative =
    Pointer<_GWeatherLocation> Function(
      Pointer<_GWeatherLocation>,
      Pointer<_GWeatherLocation>,
    );
typedef _NextChildDart =
    Pointer<_GWeatherLocation> Function(
      Pointer<_GWeatherLocation>,
      Pointer<_GWeatherLocation>,
    );
typedef _GetLevelNative = Int32 Function(Pointer<_GWeatherLocation>);
typedef _GetLevelDart = int Function(Pointer<_GWeatherLocation>);
typedef _GetStringNative = Pointer<Void> Function(Pointer<_GWeatherLocation>);
typedef _GetStringDart = Pointer<Void> Function(Pointer<_GWeatherLocation>);
typedef _UnrefNative = Void Function(Pointer<Void>);
typedef _UnrefDart = void Function(Pointer<Void>);

final class _GWeatherApi {
  _GWeatherApi() {
    final library = DynamicLibrary.open('libgweather-4.so.0');
    final gObjectLibrary = DynamicLibrary.open('libgobject-2.0.so.0');

    getWorld = library.lookupFunction<_GetWorldNative, _GetWorldDart>(
      'gweather_location_get_world',
    );
    nextChild = library.lookupFunction<_NextChildNative, _NextChildDart>(
      'gweather_location_next_child',
    );
    getLevel = library.lookupFunction<_GetLevelNative, _GetLevelDart>(
      'gweather_location_get_level',
    );
    getName = library.lookupFunction<_GetStringNative, _GetStringDart>(
      'gweather_location_get_name',
    );
    getEnglishName = library.lookupFunction<_GetStringNative, _GetStringDart>(
      'gweather_location_get_english_name',
    );
    getCountryCode = library.lookupFunction<_GetStringNative, _GetStringDart>(
      'gweather_location_get_country',
    );
    getTimeZoneId = library.lookupFunction<_GetStringNative, _GetStringDart>(
      'gweather_location_get_timezone_str',
    );
    unref = gObjectLibrary.lookupFunction<_UnrefNative, _UnrefDart>(
      'g_object_unref',
    );
  }

  late final _GetWorldDart getWorld;
  late final _NextChildDart nextChild;
  late final _GetLevelDart getLevel;
  late final _GetStringDart getName;
  late final _GetStringDart getEnglishName;
  late final _GetStringDart getCountryCode;
  late final _GetStringDart getTimeZoneId;
  late final _UnrefDart unref;
}

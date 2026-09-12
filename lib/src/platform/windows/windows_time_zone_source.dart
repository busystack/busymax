import '../../core/time/windows_time_zone_ids.dart';
export '../../core/time/windows_time_zone_ids.dart' show windowsToIanaTimeZones;

import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:flutter/services.dart';
import 'package:logging/logging.dart';
import 'package:timezone/data/latest_all.dart' as time_zone_data;
import 'package:timezone/timezone.dart' as time_zone;

import '../common/desktop_services.dart';

/// Reads the current Windows zone and normalizes it to the IANA identifiers
/// used by BusyMax and package:timezone.
final class WindowsLocalTimeZoneSource implements LocalTimeZoneSource {
  WindowsLocalTimeZoneSource({Future<TimezoneInfo> Function()? load})
    : _load = load ?? FlutterTimezone.getLocalTimezone;

  final Future<TimezoneInfo> Function() _load;
  final _logger = Logger('busymax.windows.timezone');
  String? _lastUnrecognizedIdentifier;
  String? _lastFailureCode;

  String? get lastUnrecognizedIdentifier => _lastUnrecognizedIdentifier;

  @override
  String? get diagnostic {
    final failureCode = _lastFailureCode;
    if (failureCode != null) {
      return 'local-time-zone/$failureCode; fallback=Etc/UTC';
    }
    final identifier = _lastUnrecognizedIdentifier;
    return identifier == null
        ? null
        : 'local-time-zone/unrecognized=$identifier; fallback=Etc/UTC';
  }

  @override
  Future<String> currentIanaTimeZone() async {
    try {
      final result = await _load();
      final identifier = result.identifier.trim();
      time_zone_data.initializeTimeZones();
      if (time_zone.timeZoneDatabase.locations.containsKey(identifier)) {
        _lastUnrecognizedIdentifier = null;
        _lastFailureCode = null;
        return identifier == 'UTC' ? 'Etc/UTC' : identifier;
      }
      final mapped = windowsToIanaTimeZones[identifier];
      if (mapped != null) {
        _lastUnrecognizedIdentifier = null;
        _lastFailureCode = null;
        return mapped;
      }
      _lastUnrecognizedIdentifier =
          identifier.length <= 128 &&
              RegExp(r'^[A-Za-z0-9_+./ -]+$').hasMatch(identifier)
          ? identifier
          : '<invalid>';
      _lastFailureCode = null;
      _logger.warning('Unrecognized Windows time zone; using Etc/UTC.');
    } on PlatformException catch (error) {
      const permittedCodes = {
        'windows-timezone-query-failed',
        'windows-timezone-key-invalid',
        'windows-region-unavailable',
        'windows-region-empty',
        'windows-region-encoding-failed',
        'icu-timezone-mapping-failed',
        'icu-timezone-mapping-missing',
        'icu-timezone-mapping-too-long',
        'icu-timezone-encoding-failed',
        'timezone-native-api-unavailable',
      };
      _lastUnrecognizedIdentifier = null;
      _lastFailureCode = permittedCodes.contains(error.code)
          ? error.code
          : 'unavailable';
      _logger.warning('Windows time zone is unavailable; using Etc/UTC.');
    } on Object {
      _lastUnrecognizedIdentifier = null;
      _lastFailureCode = 'unavailable';
      _logger.warning('Windows time zone is unavailable; using Etc/UTC.');
    }
    return 'Etc/UTC';
  }
}

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

/// Stable CLDR-compatible primary-zone mappings for Windows identifiers. The
/// plugin normally returns IANA on current Windows releases; this table covers
/// native Windows IDs returned by older plugin/OS combinations without guessing.
const windowsToIanaTimeZones = <String, String>{
  'Dateline Standard Time': 'Etc/GMT+12',
  'UTC-11': 'Etc/GMT+11',
  'Aleutian Standard Time': 'America/Adak',
  'Hawaiian Standard Time': 'Pacific/Honolulu',
  'Alaskan Standard Time': 'America/Anchorage',
  'Pacific Standard Time': 'America/Los_Angeles',
  'US Mountain Standard Time': 'America/Phoenix',
  'Mountain Standard Time': 'America/Denver',
  'Central Standard Time': 'America/Chicago',
  'Eastern Standard Time': 'America/New_York',
  'Atlantic Standard Time': 'America/Halifax',
  'Newfoundland Standard Time': 'America/St_Johns',
  'SA Eastern Standard Time': 'America/Cayenne',
  'Greenland Standard Time': 'America/Nuuk',
  'UTC': 'Etc/UTC',
  'GMT Standard Time': 'Europe/London',
  'W. Europe Standard Time': 'Europe/Berlin',
  'Central Europe Standard Time': 'Europe/Budapest',
  'Romance Standard Time': 'Europe/Paris',
  'FLE Standard Time': 'Europe/Kyiv',
  'Turkey Standard Time': 'Europe/Istanbul',
  'Israel Standard Time': 'Asia/Jerusalem',
  'Egypt Standard Time': 'Africa/Cairo',
  'South Africa Standard Time': 'Africa/Johannesburg',
  'Russian Standard Time': 'Europe/Moscow',
  'Arabian Standard Time': 'Asia/Dubai',
  'Iran Standard Time': 'Asia/Tehran',
  'Afghanistan Standard Time': 'Asia/Kabul',
  'Pakistan Standard Time': 'Asia/Karachi',
  'India Standard Time': 'Asia/Kolkata',
  'Nepal Standard Time': 'Asia/Kathmandu',
  'Bangladesh Standard Time': 'Asia/Dhaka',
  'Myanmar Standard Time': 'Asia/Yangon',
  'SE Asia Standard Time': 'Asia/Bangkok',
  'China Standard Time': 'Asia/Shanghai',
  'Tokyo Standard Time': 'Asia/Tokyo',
  'Korea Standard Time': 'Asia/Seoul',
  'AUS Central Standard Time': 'Australia/Darwin',
  'AUS Eastern Standard Time': 'Australia/Sydney',
  'Tasmania Standard Time': 'Australia/Hobart',
  'West Pacific Standard Time': 'Pacific/Port_Moresby',
  'New Zealand Standard Time': 'Pacific/Auckland',
  'Chatham Islands Standard Time': 'Pacific/Chatham',
  'Tonga Standard Time': 'Pacific/Tongatapu',
};

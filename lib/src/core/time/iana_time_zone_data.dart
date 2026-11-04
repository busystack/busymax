import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:timezone/timezone.dart' as tz;

import 'iana_data_2026f.dart';
export 'iana_data_2026f.dart'
    show ianaTimeZoneVersion, ianaTimeZoneSourceSha256;

bool _initialized = false;

/// All application projections, recurrence, reminders and exports share this
/// verified IANA release. The official timezone package remains unmodified;
/// its public database loader accepts the newer official IANA snapshot.
void initializeTimeZones() {
  if (_initialized) return;
  tz.initializeDatabase(
    Uint8List.fromList(gzip.decode(base64Decode(ianaTimeZoneData))),
  );
  _initialized = true;
}

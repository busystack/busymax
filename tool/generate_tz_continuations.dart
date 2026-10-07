// Generates the POSIX continuation rules omitted by timezone's compiled TZF.
// Input must be zoneinfo compiled with `zic -b fat` from IANA tzdata 2025c's
// rearguard.zi, matching timezone 0.11.1's latest_all data.
import 'dart:convert';
import 'dart:io';

import 'package:timezone/data/latest_all.dart' as timezone_data;
import 'package:timezone/timezone.dart' as tz;

void main(List<String> arguments) {
  if (arguments.length != 2) {
    throw ArgumentError(
      'Usage: dart run tool/generate_tz_continuations.dart '
      '<zoneinfo directory> <output Dart file>',
    );
  }
  timezone_data.initializeTimeZones();
  final root = Directory(arguments[0]);
  final rules = <String, String>{};
  for (final entity in root.listSync(recursive: true, followLinks: false)) {
    if (entity is! File) continue;
    final name = entity.path.substring(root.path.length + 1);
    if (!tz.timeZoneDatabase.locations.containsKey(name)) continue;
    final bytes = entity.readAsBytesSync();
    if (bytes.last != 10) throw FormatException('Missing TZif footer: $name');
    final previous = bytes.lastIndexOf(10, bytes.length - 2);
    if (previous < 0) throw FormatException('Missing TZif footer: $name');
    final rule = ascii.decode(bytes.sublist(previous + 1, bytes.length - 1));
    if (rule.isEmpty) throw FormatException('Empty TZif footer: $name');
    rules[name] = rule;
  }
  final missing = tz.timeZoneDatabase.locations.keys.toSet()
    ..removeAll(rules.keys);
  if (missing.isNotEmpty) throw FormatException('Missing zones: $missing');
  final sorted = rules.keys.toList()..sort();
  String dartString(String value) {
    if (value.contains("'") || value.contains(r'$') || value.contains('\\')) {
      throw FormatException('Unsupported TZif footer character.');
    }
    return "'$value'";
  }

  final out = StringBuffer()
    ..writeln('// Generated from IANA tzdata2025c rearguard.zi (zic -b fat).')
    ..writeln(
      '// Source: https://data.iana.org/time-zones/releases/tzdata2025c.tar.gz',
    )
    ..writeln(
      '// SHA-256: 4aa79e4effee53fc4029ffe5f6ebe97937282ebcdf386d5d2da91ce84142f957',
    )
    ..writeln('// Run tool/generate_tz_continuations.dart to reproduce.')
    ..writeln('const tzContinuations2025c = <String, String>{');
  for (final name in sorted) {
    out.writeln('  ${dartString(name)}: ${dartString(rules[name]!)},');
  }
  out.writeln('};');
  File(arguments[1]).writeAsStringSync(out.toString());
}

// Generates the POSIX continuation rules omitted by timezone's compiled TZF.
// Both inputs must come from the same IANA 2026f rearguard.zi compilation.
// Run tool/refresh_time_zone_data.py to verify and regenerate both artifacts.
import 'dart:convert';
import 'dart:io';

import 'package:timezone/timezone.dart' as tz;

void main(List<String> arguments) {
  if (arguments.length != 3) {
    throw ArgumentError(
      'Usage: dart run tool/generate_tz_continuations.dart '
      '<zoneinfo directory> <all.tzf> <output Dart file>',
    );
  }
  tz.initializeDatabase(File(arguments[1]).readAsBytesSync());
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
    ..writeln('// Generated from IANA tzdata2026f rearguard.zi (zic -b fat).')
    ..writeln(
      '// Source: https://data.iana.org/time-zones/releases/tzdata2026f.tar.gz',
    )
    ..writeln(
      '// SHA-256: 01b4a91cec5167ed48c11e8ab78f2048cead78ce94b0cafcad0ae8c5a3044d3d',
    )
    ..writeln('// Run tool/generate_tz_continuations.dart to reproduce.')
    ..writeln("const tzContinuationVersion = '2026f';")
    ..writeln('const tzContinuations2026f = <String, String>{');
  for (final name in sorted) {
    out.writeln('  ${dartString(name)}: ${dartString(rules[name]!)},');
  }
  out.writeln('};');
  File(arguments[2]).writeAsStringSync(out.toString());
}

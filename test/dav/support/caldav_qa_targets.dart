import 'dart:convert';
import 'dart:io';

/// Deployment-only test configuration. All targets use the same production
/// generic CalDAV provider and protocol paths.
const _allCalDavQaTargets = {
  'Radicale 3.9.0': 'https://localhost:18443/',
  'Baikal 0.13.0': 'https://localhost:18444/dav.php/',
  'BusyStack 0.1.0': 'https://localhost:18448/dav/',
};

/// Explicit partial runs retain all three pinned defaults. Selection is only
/// test configuration; it never changes application/provider capabilities.
Map<String, String> selectCalDavQaTargets(String selected) {
  if (selected.trim().isEmpty) return _allCalDavQaTargets;
  const aliases = {
    'radicale': 'Radicale 3.9.0',
    'baikal': 'Baikal 0.13.0',
    'busystack': 'BusyStack 0.1.0',
  };
  final names = selected.split(',').map((value) => value.trim()).toSet();
  if (names.any((name) => !aliases.containsKey(name))) {
    throw ArgumentError(
      'Select only radicale, baikal or busystack QA targets.',
    );
  }
  return Map.unmodifiable({
    for (final entry in _allCalDavQaTargets.entries)
      if (names.any((name) => aliases[name] == entry.key))
        entry.key: entry.value,
  });
}

final calDavQaTargets = selectCalDavQaTargets(
  Platform.environment['BUSYMAX_CALDAV_QA_TARGETS'] ??
      const String.fromEnvironment('BUSYMAX_CALDAV_QA_TARGETS'),
);

bool calDavQaSupportsMixed(Uri endpoint) =>
    endpoint.origin !=
    Uri.parse(_allCalDavQaTargets['BusyStack 0.1.0']!).origin;

Future<Map<String, dynamic>> calDavQaCredentials(
  Uri endpoint, {
  String directory = 'test/interop/caldav/.runtime',
}) async {
  final filename =
      endpoint.origin ==
          Uri.parse(_allCalDavQaTargets['BusyStack 0.1.0']!).origin
      ? 'busystack-credentials.json'
      : 'credentials.json';
  return jsonDecode(await File('$directory/$filename').readAsString())
      as Map<String, dynamic>;
}

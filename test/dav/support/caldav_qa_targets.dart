import 'dart:convert';
import 'dart:io';

/// Deployment-only test configuration. All targets use the same production
/// generic CalDAV provider and protocol paths.
const calDavQaTargets = {
  'Radicale 3.9.0': 'https://localhost:18443/',
  'Baikal 0.13.0': 'https://localhost:18444/dav.php/',
  'BusyStack 0.1.0': 'https://localhost:18448/dav/',
};

bool calDavQaSupportsMixed(Uri endpoint) =>
    endpoint.origin != Uri.parse(calDavQaTargets['BusyStack 0.1.0']!).origin;

Future<Map<String, dynamic>> calDavQaCredentials(
  Uri endpoint, {
  String directory = 'test/interop/caldav/.runtime',
}) async {
  final filename =
      endpoint.origin == Uri.parse(calDavQaTargets['BusyStack 0.1.0']!).origin
      ? 'busystack-credentials.json'
      : 'credentials.json';
  return jsonDecode(await File('$directory/$filename').readAsString())
      as Map<String, dynamic>;
}

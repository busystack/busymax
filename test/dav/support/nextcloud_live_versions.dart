import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

/// Only called inside opted-in live tests. App versions are operator-recorded
/// from the QA installation, since reading its installed apps may require
/// administrator access that a calendar app password should not receive.
Future<void> recordNextcloudLiveVersions(
  http.Client client,
  Uri installationRoot,
) async {
  String appVersion(String name) {
    final value = Platform.environment['BUSYMAX_NEXTCLOUD_QA_${name}_VERSION'];
    if (value == null ||
        !RegExp(r'^\d+\.\d+\.\d+(?:[.+-][a-zA-Z0-9.-]+)?$').hasMatch(value)) {
      throw StateError(
        'Record the installed $name version in BUSYMAX_NEXTCLOUD_QA_${name}_VERSION before live testing.',
      );
    }
    return value;
  }

  final calendar = appVersion('CALENDAR'), tasks = appVersion('TASKS');
  final root = installationRoot.replace(
    path: installationRoot.path.endsWith('/')
        ? installationRoot.path
        : '${installationRoot.path}/',
  );
  final response = await client
      .get(root.resolve('status.php'))
      .timeout(const Duration(seconds: 15));
  expect(response.statusCode, 200);
  final status = jsonDecode(response.body) as Map;
  final server = status['versionstring'];
  expect(server, matches(RegExp(r'^\d+\.\d+\.\d+(?:[.+-][a-zA-Z0-9.-]+)?$')));
  // These values are version-only; never print URLs, account names or payloads.
  stdout.writeln(
    'Nextcloud QA versions: Server=$server; Calendar=$calendar; Tasks=$tasks; OS=${Platform.operatingSystem}',
  );
}

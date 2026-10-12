import 'dart:convert';
import 'dart:io';

import 'package:busymax/src/config/desktop_oauth_configuration.dart';

/// Official local Linux builds require the intended managed Google client.
/// Never print configuration values: they may contain protected client secrets.
void main(List<String> args) {
  Map<String, Object?> values;
  if (args.isEmpty) {
    values = Platform.environment;
  } else if (args.length == 2 && args.first == '--config') {
    try {
      values = (jsonDecode(File(args.last).readAsStringSync()) as Map)
          .cast<String, Object?>();
    } on Object {
      stderr.writeln(
        'Cannot read a JSON object from the release configuration.',
      );
      exitCode = 1;
      return;
    }
  } else {
    stderr.writeln(
      'Usage: dart run tool/check_desktop_oauth_config.dart '
      '[--config <dart-defines.json>]',
    );
    exitCode = 64;
    return;
  }
  String value(String key) =>
      values[key] is String ? values[key] as String : '';
  var missing = false;
  const syntheticCiValues = {
    'managed.apps.googleusercontent.com',
    'later.apps.googleusercontent.com',
    'fixture.apps.googleusercontent.com',
    'original.apps.googleusercontent.com',
    'owned.apps.googleusercontent.com',
    'synthetic-public-secret',
    'synthetic-managed-project',
    '11111111-1111-1111-1111-111111111111',
    '33333333-3333-3333-3333-333333333333',
    '55555555-5555-5555-5555-555555555555',

    'busymax-ci-managed.apps.googleusercontent.com',
    'synthetic-ci-public-secret',
    'busymax-ci-managed',
    '44444444-4444-4444-4444-444444444444',
    'busymax-ci-original.apps.googleusercontent.com',
    '22222222-2222-2222-2222-222222222222',
  };
  if (const [
    'BUSYMAX_GOOGLE_OAUTH_CLIENT_ID',
    'BUSYMAX_GOOGLE_OAUTH_CLIENT_SECRET',
    'BUSYMAX_GOOGLE_OAUTH_PROJECT_ID',
    'BUSYMAX_MICROSOFT_OAUTH_CLIENT_ID',
    'GOOGLE_OAUTH_CLIENT_ID',
    'GOOGLE_OAUTH_CLIENT_SECRET',
    'GOOGLE_OAUTH_PROJECT_ID',
    'MICROSOFT_OAUTH_CLIENT_ID',
  ].any((key) => syntheticCiValues.contains(value(key).trim()))) {
    stderr.writeln(
      'Synthetic CI registrations cannot be used in an official release.',
    );
    missing = true;
  }
  if (!validGoogleDesktopConfiguration(
    clientId: value('BUSYMAX_GOOGLE_OAUTH_CLIENT_ID'),
    clientSecret: value('BUSYMAX_GOOGLE_OAUTH_CLIENT_SECRET'),
    projectId: value('BUSYMAX_GOOGLE_OAUTH_PROJECT_ID'),
  )) {
    stderr.writeln(
      'External prerequisite: Google production Desktop client ID, '
      'client secret and truthful project ID are missing or invalid. '
      'The owner must also complete publishing, branding and any required '
      'scope approval/verification before enabling Connect with BusyMax.',
    );
    missing = true;
  }
  for (final key in [
    'MICROSOFT_OAUTH_CLIENT_ID',
    'BUSYMAX_MICROSOFT_OAUTH_CLIENT_ID',
  ]) {
    if (values.containsKey(key) &&
        !validMicrosoftDesktopConfiguration(clientId: value(key))) {
      stderr.writeln(
        'Supplied Microsoft public client configuration is invalid.',
      );
      missing = true;
    }
  }
  // Original Google values are optional, never a substitute for managed values.
  if (values.containsKey('GOOGLE_OAUTH_CLIENT_ID') &&
      !RegExp(r'^[A-Za-z0-9_-]+\.apps\.googleusercontent\.com$')
          .hasMatch(value('GOOGLE_OAUTH_CLIENT_ID').trim())) {
    stderr.writeln('Supplied original Google client configuration is invalid.');
    missing = true;
  }
  for (final key in [
    'GOOGLE_OAUTH_CLIENT_SECRET',
    'GOOGLE_OAUTH_PROJECT_ID',
    'MICROSOFT_OAUTH_AUTHORITY_TENANT',
  ]) {
    if (values.containsKey(key) && value(key).trim().isEmpty) {
      stderr.writeln(
        'Supplied optional registration configuration is incomplete.',
      );
      missing = true;
    }
  }
  if (values.containsKey('MICROSOFT_OAUTH_AUTHORITY_TENANT') &&
      !{
        'common',
        'consumers',
        'organizations',
      }.contains(value('MICROSOFT_OAUTH_AUTHORITY_TENANT')) &&
      !validMicrosoftDesktopConfiguration(
        clientId: value('MICROSOFT_OAUTH_AUTHORITY_TENANT'),
      )) {
    stderr.writeln('Supplied Microsoft authority configuration is invalid.');
    missing = true;
  }
  if (values.containsKey('GOOGLE_OAUTH_PROJECT_ID') &&
      !RegExp(r'^[a-z][a-z0-9-]{4,62}[a-z0-9]$')
          .hasMatch(value('GOOGLE_OAUTH_PROJECT_ID'))) {
    stderr.writeln('Supplied original Google project metadata is invalid.');
    missing = true;
  }
  if ((values.containsKey('GOOGLE_OAUTH_CLIENT_SECRET') ||
          values.containsKey('GOOGLE_OAUTH_PROJECT_ID')) &&
      !values.containsKey('GOOGLE_OAUTH_CLIENT_ID')) {
    stderr.writeln('Supplied original Google configuration is incomplete.');
    missing = true;
  }
  if (value('GOOGLE_OAUTH_CLIENT_ID').isNotEmpty &&
      value('GOOGLE_OAUTH_CLIENT_ID').trim() ==
          value('BUSYMAX_GOOGLE_OAUTH_CLIENT_ID').trim()) {
    stderr.writeln(
      'The active Google registration must not be substituted for the retiring registration.',
    );
    missing = true;
  }
  if (value('BUSYMAX_PRIVACY_POLICY_URL') !=
      'https://busystack.org/privacy-busymax') {
    stderr.writeln(
      'BusyStack-owned production configuration must use '
      'https://busystack.org/privacy-busymax for its product privacy policy.',
    );
    missing = true;
  }
  if (missing) {
    exitCode = 1;
  } else {
    stdout.writeln(
      'Desktop registration values are syntactically complete. '
      'Provider publishing, verification and consent still require owner review.',
    );
  }
}

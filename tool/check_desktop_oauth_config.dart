import 'dart:convert';
import 'dart:io';

import 'package:busymax/src/config/desktop_oauth_configuration.dart';

/// Official desktop builds must explicitly supply both recommended clients.
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
  if (!validMicrosoftDesktopConfiguration(
    clientId: value('BUSYMAX_MICROSOFT_OAUTH_CLIENT_ID'),
    authorityTenant: value('BUSYMAX_MICROSOFT_OAUTH_AUTHORITY_TENANT'),
  )) {
    stderr.writeln(
      'External prerequisite: Microsoft production public app ID '
      'and explicit supported-account authority are missing or invalid. '
      'The owner must configure the desktop redirect, delegated permissions '
      'and applicable consent before enabling Connect with BusyMax.',
    );
    missing = true;
  }
  if (value('GOOGLE_OAUTH_CLIENT_ID').trim().isEmpty ||
      value('MICROSOFT_OAUTH_CLIENT_ID').trim().isEmpty) {
    stderr.writeln(
      'Protected original registration IDs must be retained '
      'separately for existing account bindings. Do not substitute the new '
      'production registrations for these values.',
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

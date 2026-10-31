import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../test/dav/trust/nextcloud_private_tls_test.dart' as tls;

/// Executes production TLS construction in the native Linux Flutter engine.
/// No BusyMax profile, account database or platform trust store is opened.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  if (!Platform.isLinux) {
    test(
      'Linux native TLS acceptance',
      () {},
      skip:
          'This target uses a host OpenSSL executable for disposable fixtures.',
    );
    return;
  }
  tls.main();
}

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../test/dav/trust/nextcloud_private_tls_test.dart' as tls;
import '../test/dav/trust/dav_account_concurrency_test.dart' as concurrency;
import '../test/dav/trust/icloud_authorization_transport_test.dart' as icloud;

/// Native Windows runtime qualification, using disposable loopback fixtures.
/// Requires an unmodified OpenSSL executable in PATH, without user trust edits.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  if (!Platform.isWindows) {
    test('Windows native transport acceptance', () {}, skip: 'Windows only.');
    return;
  }
  tls.main();
  concurrency.main();
  icloud.main();
}

import 'dart:io';

import 'package:busymax/src/dav/trust/nextcloud_certificate.dart';
import 'package:busymax/src/dav/trust/nextcloud_http_client_factory.dart';
import 'package:busymax/src/dav/trust/nextcloud_trust_policy.dart';
import 'package:http/http.dart' as http;

/// Explicit approval of disposable live-fixture material. This uses production
/// TLS construction; it never changes a user profile or platform trust store.
http.Client nextcloudLiveClient({
  required Uri authority,
  required String prefix,
  required String identity,
  bool allowInsecureLoopbackForTesting = false,
}) {
  final mode = Platform.environment['${prefix}_TRUST_MODE'] ?? 'standard';
  if (allowInsecureLoopbackForTesting &&
      mode == 'standard' &&
      authority.scheme == 'http' &&
      const {'localhost', '127.0.0.1', '::1'}.contains(authority.host)) {
    return http.Client(); // Preserve the existing explicit test-only facility.
  }
  NextcloudTrustPolicy? policy;
  if (mode != 'standard') {
    final path = Platform.environment['${prefix}_TLS_CERT'];
    if (path == null || path.isEmpty) {
      throw StateError(
        'Private live TLS needs an explicit certificate fixture.',
      );
    }
    final file = File(path);
    if (file.lengthSync() > NextcloudCertificate.maximumBytes) {
      throw StateError('Oversized TLS fixture.');
    }
    policy = NextcloudTrustPolicy.approve(
      owner: identity,
      installation: authority,
      mode: switch (mode) {
        'private_ca' => NextcloudTrustMode.privateCa,
        'pinned_leaf' => NextcloudTrustMode.pinnedLeaf,
        _ => throw StateError('Unsupported live trust mode.'),
      },
      certificates: NextcloudCertificate.import(file.readAsBytesSync()),
      generation: 'disposable-live-fixture',
    );
  }
  return NextcloudHttpClientFactory(requireNetwork: () async {})
      .create(owner: identity, authority: authority, policy: policy);
}

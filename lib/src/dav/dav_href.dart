import 'package:busystack_dav/busystack_dav.dart' as shared;

import '../providers/busy_provider.dart';
import 'dav_errors.dart';
import 'dav_provider_profile.dart';

Uri resolveDavHref({
  required String href,
  required Uri responseRequestUri,
  required DavProviderProfile profile,
  required Uri accountAuthority,
  String? correlationId,
}) => shared.resolveDavHref(
  href: href,
  responseRequestUri: responseRequestUri,
  profile: sharedDavProviderProfile(profile),
  accountAuthority: accountAuthority,
  correlationId: correlationId,
);

/// Returns the stable account-relative DAV identity without decoding or
/// re-encoding percent-escaped reserved path octets. iCloud shard hosts are
/// intentionally excluded; Nextcloud authority is already part of account
/// identity.
String normalizedDavHrefKey(BusyProvider provider, Uri requestUri) {
  if (requestUri.path.isEmpty || !requestUri.path.startsWith('/')) {
    throw const DavException(
      kind: DavErrorKind.protocol,
      code: 'DavHrefMissingAbsolutePath',
      safeMessage: 'A DAV resource did not have an absolute path.',
    );
  }
  return shared.normalizedDavHrefKey(requestUri);
}

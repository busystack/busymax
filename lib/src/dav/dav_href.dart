import '../providers/busy_provider.dart';
import 'dav_errors.dart';
import 'dav_provider_profile.dart';

Uri resolveDavHref({
  required String href,
  required Uri responseRequestUri,
  required DavProviderProfile profile,
  required Uri accountAuthority,
  String? correlationId,
}) {
  final source = href.trim();
  if (source.isEmpty) {
    throw _invalidHref(correlationId);
  }
  late final Uri resolved;
  try {
    resolved = responseRequestUri.resolve(source);
  } on FormatException {
    throw _invalidHref(correlationId);
  }
  if (resolved.userInfo.isNotEmpty ||
      resolved.hasFragment ||
      resolved.hasQuery ||
      !profile.isTrustedCredentialDestination(
        resolved,
        accountAuthority: accountAuthority,
      )) {
    throw _invalidHref(correlationId);
  }
  return resolved;
}

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
  return requestUri.path;
}

DavException _invalidHref(String? correlationId) => DavException(
  kind: DavErrorKind.redirectRejected,
  code: 'DavHrefDestinationRejected',
  safeMessage: 'The DAV server returned an unsafe resource location.',
  correlationId: correlationId,
);

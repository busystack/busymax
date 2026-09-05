import '../providers/busy_provider.dart';

const davProviderProfileVersion = 2;

final class DavProviderProfile {
  const DavProviderProfile({
    required this.provider,
    required this.bootstrapUri,
    required this.calendarEnabled,
    required this.tasksEnabled,
    required this.allowCollectionMutations,
    required this.allowSchedulingMutations,
    required this.allowMove,
    this.allowInsecureLoopbackForTesting = false,
  });

  final BusyProvider provider;
  final Uri bootstrapUri;
  final bool calendarEnabled;
  final bool tasksEnabled;
  final bool allowCollectionMutations;
  final bool allowSchedulingMutations;
  final bool allowMove;
  final bool allowInsecureLoopbackForTesting;

  bool isTrustedCredentialDestination(
    Uri destination, {
    required Uri accountAuthority,
  }) {
    if (!_isSafeHttpsUri(destination) &&
        !(allowInsecureLoopbackForTesting &&
            _isInsecureLoopbackUri(destination))) {
      return false;
    }
    return switch (provider) {
      BusyProvider.appleICloud => _isApprovedICloudHost(destination.host),
      BusyProvider.nextcloud =>
        _sameOrigin(destination, accountAuthority) &&
            _preservesInstallationPath(destination, accountAuthority),
      BusyProvider.google ||
      BusyProvider.microsoft ||
      BusyProvider.webCal => false,
    };
  }
}

bool _isInsecureLoopbackUri(Uri uri) =>
    uri.scheme.toLowerCase() == 'http' &&
    (uri.host == '127.0.0.1' || uri.host == '::1' || uri.host == 'localhost') &&
    uri.userInfo.isEmpty &&
    !uri.hasFragment;

DavProviderProfile davProviderProfile(
  BusyProvider provider, {
  Uri? nextcloudServer,
}) => switch (provider) {
  BusyProvider.appleICloud => DavProviderProfile(
    provider: provider,
    bootstrapUri: Uri.parse('https://caldav.icloud.com/'),
    calendarEnabled: true,
    tasksEnabled: false,
    allowCollectionMutations: false,
    allowSchedulingMutations: false,
    allowMove: false,
  ),
  BusyProvider.nextcloud => DavProviderProfile(
    provider: provider,
    bootstrapUri:
        nextcloudServer ??
        (throw ArgumentError.value(
          nextcloudServer,
          'nextcloudServer',
          'Nextcloud requires the canonical Login Flow v2 server.',
        )),
    calendarEnabled: true,
    tasksEnabled: true,
    allowCollectionMutations: true,
    allowSchedulingMutations: false,
    allowMove: true,
  ),
  BusyProvider.google ||
  BusyProvider.microsoft ||
  BusyProvider.webCal => throw ArgumentError.value(
    provider,
    'provider',
    'The provider does not use the DAV transport.',
  ),
};

Uri davWellKnownUri(DavProviderProfile profile) {
  final bootstrap = profile.bootstrapUri;
  if (profile.provider == BusyProvider.appleICloud) {
    return bootstrap.replace(
      path: '/.well-known/caldav',
      query: null,
      fragment: null,
    );
  }
  final basePath = bootstrap.path.endsWith('/')
      ? bootstrap.path
      : '${bootstrap.path}/';
  return bootstrap.replace(
    path: '$basePath.well-known/caldav',
    query: null,
    fragment: null,
  );
}

bool _isSafeHttpsUri(Uri uri) =>
    uri.scheme.toLowerCase() == 'https' &&
    uri.host.isNotEmpty &&
    uri.userInfo.isEmpty &&
    !uri.hasFragment;

bool _sameOrigin(Uri left, Uri right) =>
    left.scheme.toLowerCase() == right.scheme.toLowerCase() &&
    left.host.toLowerCase() == right.host.toLowerCase() &&
    left.port == right.port;

bool _preservesInstallationPath(Uri destination, Uri authority) {
  var basePath = authority.path;
  if (basePath.isEmpty || basePath == '/') {
    return true;
  }
  while (basePath.endsWith('/')) {
    basePath = basePath.substring(0, basePath.length - 1);
  }
  return destination.path == basePath ||
      destination.path.startsWith('$basePath/');
}

bool _isApprovedICloudHost(String value) {
  final host = value.toLowerCase();
  return host == 'caldav.icloud.com' ||
      RegExp(r'^p[0-9]+-caldav[.]icloud[.]com$').hasMatch(host);
}

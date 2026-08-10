import 'busy_provider.dart';

const googleAccountAuthority = 'https://accounts.google.com';
const appleICloudAccountAuthority = 'https://caldav.icloud.com';
const microsoftAuthorityOrigin = 'https://login.microsoftonline.com';

final class InvalidAccountAuthorityException implements FormatException {
  const InvalidAccountAuthorityException(this.reason, [this.source]);

  final String reason;

  @override
  final String? source;

  @override
  String get message => reason;

  @override
  int? get offset => null;
}

String normalizeProviderAccountId(BusyProvider provider, String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) {
    throw const InvalidAccountAuthorityException(
      'The provider account identifier must not be empty.',
    );
  }
  return switch (provider) {
    BusyProvider.appleICloud => trimmed.toLowerCase(),
    BusyProvider.google ||
    BusyProvider.microsoft ||
    BusyProvider.nextcloud => trimmed,
  };
}

String normalizeAccountAuthority(
  BusyProvider provider, {
  String? authority,
  String? tenantId,
}) {
  return switch (provider) {
    BusyProvider.google => googleAccountAuthority,
    BusyProvider.microsoft => _microsoftAuthority(tenantId ?? authority),
    BusyProvider.appleICloud => appleICloudAccountAuthority,
    BusyProvider.nextcloud => normalizeNextcloudServerAuthority(
      authority ??
          (throw const InvalidAccountAuthorityException(
            'Nextcloud requires the canonical server returned by Login Flow v2.',
          )),
    ),
  };
}

String normalizeNextcloudServerAuthority(String value) {
  final trimmed = value.trim();
  final parsed = Uri.tryParse(trimmed);
  if (parsed == null ||
      parsed.scheme.toLowerCase() != 'https' ||
      parsed.host.isEmpty ||
      parsed.userInfo.isNotEmpty ||
      parsed.hasQuery ||
      parsed.hasFragment) {
    throw InvalidAccountAuthorityException(
      'Nextcloud must return an HTTPS server URL without user information, query, or fragment.',
      value,
    );
  }

  var path = parsed.path;
  while (path.length > 1 && path.endsWith('/')) {
    path = path.substring(0, path.length - 1);
  }
  return Uri(
    scheme: 'https',
    host: parsed.host.toLowerCase(),
    port: parsed.hasPort && parsed.port != 443 ? parsed.port : null,
    path: path == '/' ? '' : path,
  ).toString();
}

String _microsoftAuthority(String? tenantIdOrAuthority) {
  final value = tenantIdOrAuthority?.trim();
  if (value == null || value.isEmpty) {
    return '$microsoftAuthorityOrigin/common';
  }
  final uri = Uri.tryParse(value);
  if (uri != null && uri.hasScheme) {
    if (uri.scheme.toLowerCase() != 'https' ||
        uri.host.toLowerCase() != 'login.microsoftonline.com' ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment) {
      throw InvalidAccountAuthorityException(
        'Microsoft authority must use the Microsoft login origin.',
        value,
      );
    }
    final tenant = uri.pathSegments
        .where((part) => part.isNotEmpty)
        .firstOrNull;
    return '$microsoftAuthorityOrigin/${(tenant ?? 'common').toLowerCase()}';
  }
  return '$microsoftAuthorityOrigin/${value.toLowerCase()}';
}

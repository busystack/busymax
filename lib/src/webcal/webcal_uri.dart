import 'dart:convert';

import 'package:crypto/crypto.dart';

final class WebCalUriException implements FormatException {
  const WebCalUriException(this.code);

  final String code;

  @override
  String get message => 'The calendar subscription URL is not valid.';

  @override
  int? get offset => null;

  @override
  String? get source => null;
}

final class NormalizedWebCalUri {
  const NormalizedWebCalUri._({
    required this.uri,
    required this.credentialUri,
    required this.safeOrigin,
    required this.fingerprint,
  });

  final Uri uri;
  final String credentialUri;
  final Uri safeOrigin;
  final String fingerprint;
}

NormalizedWebCalUri normalizeWebCalUri(String input) {
  final trimmed = input.trim();
  final parsed = Uri.tryParse(trimmed);
  if (parsed == null) throw const WebCalUriException('WebCalUriMalformed');
  final scheme = parsed.scheme.toLowerCase();
  if (scheme != 'https' && scheme != 'webcal') {
    throw const WebCalUriException('WebCalUriSchemeNotAllowed');
  }
  if (parsed.host.isEmpty || parsed.userInfo.isNotEmpty || parsed.hasFragment) {
    throw const WebCalUriException('WebCalUriAuthorityNotAllowed');
  }
  final authorityStart = trimmed.indexOf('://') + 3;
  final tailStart = _authorityEnd(trimmed, authorityStart);
  final authority = trimmed.substring(authorityStart, tailStart);
  final explicitPortText = _explicitPortText(authority);
  final explicitPort = explicitPortText == null
      ? null
      : int.tryParse(explicitPortText);
  if (explicitPortText != null &&
      (explicitPort == null || explicitPort < 1 || explicitPort > 65535)) {
    throw const WebCalUriException('WebCalUriAuthorityNotAllowed');
  }
  final normalizedAuthority = parsed.host.contains(':')
      ? '[${parsed.host.toLowerCase()}]'
      : parsed.host.toLowerCase();
  final normalizedText =
      'https://$normalizedAuthority'
      '${explicitPort == null ? '' : ':$explicitPort'}'
      '${trimmed.substring(tailStart)}';
  final normalized = Uri.parse(normalizedText);
  final safeOrigin = Uri(
    scheme: 'https',
    host: normalized.host.toLowerCase(),
    port: normalized.hasPort && normalized.port != 443 ? normalized.port : null,
  );
  return NormalizedWebCalUri._(
    uri: normalized,
    credentialUri: normalizedText,
    safeOrigin: safeOrigin,
    fingerprint: webCalTextFingerprint(normalizedText),
  );
}

String webCalUriFingerprint(Uri uri) =>
    sha256.convert(utf8.encode(uri.toString())).toString();

String webCalTextFingerprint(String uri) =>
    sha256.convert(utf8.encode(uri)).toString();

int _authorityEnd(String value, int start) {
  for (var index = start; index < value.length; index += 1) {
    final code = value.codeUnitAt(index);
    if (code == 0x2f || code == 0x3f || code == 0x23) return index;
  }
  return value.length;
}

String? _explicitPortText(String authority) {
  if (authority.startsWith('[')) {
    final end = authority.indexOf(']');
    if (end < 0 || end == authority.length - 1) return null;
    if (authority.codeUnitAt(end + 1) != 0x3a) return null;
    return authority.substring(end + 2);
  }
  final separator = authority.lastIndexOf(':');
  return separator < 0 ? null : authority.substring(separator + 1);
}

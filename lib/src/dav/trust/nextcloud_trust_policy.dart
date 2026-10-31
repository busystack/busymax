import 'dart:convert';

import '../../providers/account_authority.dart';
import 'nextcloud_certificate.dart';

enum NextcloudTrustMode { privateCa, pinnedLeaf, invalidConfiguration }

/// Immutable, versioned approval owned by one credential. Absence means
/// standard HTTPS. Invalid configured policies must never mean absence.
final class NextcloudTrustPolicy {
  NextcloudTrustPolicy._({
    required this.owner,
    required this.installation,
    required this.mode,
    required this.certificates,
    required this.approvedAt,
    required this.generation,
    this.invalidRecord,
  });
  final String owner;
  final Uri installation;
  final NextcloudTrustMode mode;
  final List<NextcloudCertificate> certificates;
  final DateTime approvedAt;
  final String generation;
  final Map<String, Object?>? invalidRecord;

  factory NextcloudTrustPolicy.approve({
    required String owner,
    required Uri installation,
    required NextcloudTrustMode mode,
    required List<NextcloudCertificate> certificates,
    required String generation,
  }) {
    final normalized = Uri.parse(
      normalizeNextcloudServerAuthority(installation.toString()),
    );
    if (mode == NextcloudTrustMode.invalidConfiguration ||
        installation.scheme != 'https' ||
        owner.isEmpty ||
        generation.isEmpty ||
        certificates.isEmpty ||
        certificates.length > 8 ||
        (mode == NextcloudTrustMode.pinnedLeaf && certificates.length != 1)) {
      throw const FormatException('Invalid private certificate policy.');
    }
    for (final cert in certificates) {
      if (mode == NextcloudTrustMode.privateCa) {
        cert.validateCa();
      } else {
        cert.validateServer(normalized.host, selfSigned: true);
      }
    }
    return NextcloudTrustPolicy._(
      owner: owner,
      installation: normalized,
      mode: mode,
      certificates: List.unmodifiable(certificates),
      approvedAt: DateTime.now().toUtc(),
      generation: generation,
    );
  }

  NextcloudTrustPolicy bind(String accountId) => NextcloudTrustPolicy._(
    owner: accountId,
    installation: installation,
    mode: mode,
    certificates: certificates,
    approvedAt: approvedAt,
    generation: generation,
    invalidRecord: invalidRecord,
  );

  void requireScope(String accountId, Uri authority) {
    if (mode == NextcloudTrustMode.invalidConfiguration ||
        owner != accountId ||
        installation.toString() !=
            normalizeNextcloudServerAuthority(authority.toString())) {
      throw const FormatException(
        'Private certificate approval belongs to another account or installation.',
      );
    }
  }

  bool permitsOrigin(Uri uri) =>
      uri.scheme == 'https' &&
      uri.userInfo.isEmpty &&
      uri.host.toLowerCase() == installation.host &&
      uri.port == installation.port;

  Map<String, Object?> toJson() =>
      invalidRecord ??
      {
        'version': 1,
        'owner': owner,
        'installation': installation.toString(),
        'mode': mode.name,
        'generation': generation,
        'approvedAt': approvedAt.toIso8601String(),
        'certificates': [
          for (final cert in certificates)
            {'der': base64.encode(cert.der), 'sha256': cert.fingerprint},
        ],
      };

  factory NextcloudTrustPolicy.fromJson(Object? input) {
    try {
      final json = (input as Map).cast<String, Object?>();
      if (json['version'] != 1) throw const FormatException();
      final mode = NextcloudTrustMode.values.byName(json['mode'] as String);
      if (mode == NextcloudTrustMode.invalidConfiguration) {
        throw const FormatException();
      }
      final entries = json['certificates'] as List;
      if (entries.isEmpty || entries.length > 8) throw const FormatException();
      final certificates = entries
          .map((e) {
            final encoded = (e as Map)['der'] as String;
            if (encoded.length > NextcloudCertificate.maximumBytes * 2) {
              throw const FormatException();
            }
            final cert = NextcloudCertificate.der(base64.decode(encoded));
            if (cert.fingerprint != e['sha256']) throw const FormatException();
            return cert;
          })
          .toList(growable: false);
      final installation = Uri.parse(json['installation'] as String);
      final owner = json['owner'] as String;
      final generation = json['generation'] as String;
      // Expired material remains readable for review/removal. It is rejected
      // when constructing the connection, never silently dropped on load.
      if (owner.isEmpty ||
          generation.isEmpty ||
          installation.scheme != 'https' ||
          normalizeNextcloudServerAuthority(installation.toString()) !=
              installation.toString() ||
          (mode == NextcloudTrustMode.pinnedLeaf && certificates.length != 1)) {
        throw const FormatException();
      }
      return NextcloudTrustPolicy._(
        owner: owner,
        installation: installation,
        mode: mode,
        certificates: List.unmodifiable(certificates),
        generation: generation,
        approvedAt: DateTime.parse(json['approvedAt'] as String).toUtc(),
      );
    } on Object {
      // Retain an explicit invalid state for journal rollback, inspection and
      // local-first account removal. It can never construct a TLS client or
      // enroll automatically; only explicit validated replacement can repair it.
      return NextcloudTrustPolicy._(
        owner: '',
        installation: Uri(),
        mode: NextcloudTrustMode.invalidConfiguration,
        certificates: const [],
        approvedAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
        generation: '',
        invalidRecord: Map.unmodifiable(
          input is Map<String, Object?>
              ? input
              : <String, Object?>{'version': 0, 'invalid': true},
        ),
      );
    }
  }
}

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:asn1lib/asn1lib.dart';
import 'package:crypto/crypto.dart';
import 'package:pointycastle/export.dart' as pc;
import 'package:x509/x509.dart' as x509;

/// Bounded parsed certificate data. Native TLS remains responsible for chain
/// validation; this class supplies import eligibility and RFC 9525 SAN policy.
final class NextcloudCertificate {
  NextcloudCertificate._(this.der, this._parsed);
  static const maximumBytes = 64 * 1024;
  final Uint8List der;
  final x509.X509Certificate _parsed;

  factory NextcloudCertificate.der(List<int> input) {
    if (input.isEmpty || input.length > maximumBytes) {
      throw const FormatException('Invalid certificate size.');
    }
    try {
      final bytes = Uint8List.fromList(input);
      final parser = ASN1Parser(Uint8List.fromList(bytes));
      final sequence = parser.nextObject() as ASN1Sequence;
      if (parser.hasNext() ||
          sequence.encodedBytes.length != bytes.length ||
          sequence.elements.length != 3) {
        throw const FormatException();
      }
      return NextcloudCertificate._(
        bytes.asUnmodifiableView(),
        x509.X509Certificate.fromAsn1(sequence),
      );
    } on Object {
      throw const FormatException(
        'Malformed or unsupported X.509 certificate.',
      );
    }
  }

  static List<NextcloudCertificate> import(List<int> input) {
    if (input.isEmpty || input.length > maximumBytes) {
      throw const FormatException('Certificate import is empty or too large.');
    }
    // Only a DER certificate or an exact PEM certificate bundle is supported.
    // Never pass arbitrary containers or private keys to a trust-store API.
    if (input.first == 0x30) return [NextcloudCertificate.der(input)];
    final source = utf8.decode(input, allowMalformed: false).trim();
    if (source.contains('PRIVATE KEY')) {
      throw const FormatException('Private keys must not be imported.');
    }
    final expression = RegExp(
      r'-----BEGIN CERTIFICATE-----\s*([A-Za-z0-9+/=\s]+?)\s*-----END CERTIFICATE-----',
    );
    final matches = expression.allMatches(source).toList();
    if (matches.isEmpty ||
        matches.length > 8 ||
        source.replaceAll(expression, '').trim().isNotEmpty) {
      throw const FormatException('Use X.509 PEM or DER certificates only.');
    }
    return List.unmodifiable(
      matches.map(
        (match) => NextcloudCertificate.der(
          base64.decode(match[1]!.replaceAll(RegExp(r'\s'), '')),
        ),
      ),
    );
  }

  /// Bounds the read itself, including files that grow after selection or
  /// providers whose reported length changes. Oversize input cancels the stream.
  static Future<List<NextcloudCertificate>> importStream(
    Stream<List<int>> source,
  ) async {
    final bytes = BytesBuilder(copy: false);
    await for (final chunk in source) {
      if (bytes.length + chunk.length > maximumBytes) {
        throw const FormatException('Certificate import is too large.');
      }
      bytes.add(chunk);
    }
    return import(bytes.takeBytes());
  }

  String get fingerprint => sha256.convert(der).toString();
  String get pem =>
      '-----BEGIN CERTIFICATE-----\n${base64.encode(der)}\n-----END CERTIFICATE-----\n';
  DateTime get notBefore => _parsed.tbsCertificate.validity!.notBefore.toUtc();
  DateTime get notAfter => _parsed.tbsCertificate.validity!.notAfter.toUtc();
  String get subject => _name(_parsed.tbsCertificate.subject!);
  String get issuer => _name(_parsed.tbsCertificate.issuer!);
  static String safeText(String value) => String.fromCharCodes(
    value.runes
        .where(
          (r) =>
              r >= 0x20 &&
              r != 0x7f &&
              r != 0xad &&
              r != 0x61c &&
              r != 0xfeff &&
              !(r >= 0x80 && r <= 0x9f) &&
              !(r >= 0x200b && r <= 0x200f) &&
              !(r >= 0x2028 && r <= 0x202e) &&
              !(r >= 0x2060 && r <= 0x206f),
        )
        .take(512),
  );
  static String _name(x509.Name value) => safeText(
    value.names
        .map(
          (rdn) => rdn.entries
              .map((e) => '${e.key?.nodes.join('.')}=${e.value}')
              .join(', '),
        )
        .join(', '),
  );
  Iterable<x509.Extension> get _extensions =>
      _parsed.tbsCertificate.extensions ?? const [];
  T? _extension<T>(String oid) {
    final found = _extensions
        .where((e) => e.extnId.nodes.join('.') == oid)
        .toList();
    if (found.length > 1) {
      throw const FormatException('Duplicate X.509 extension.');
    }
    return found.isEmpty ? null : found.single.extnValue as T;
  }

  /// Validity is checked explicitly, including when a self-signed leaf is
  /// supplied to native TLS as an account-local trust anchor.
  void validateTime([DateTime? now]) {
    final instant = (now ?? DateTime.now()).toUtc();
    if (instant.isBefore(notBefore)) {
      throw const FormatException('certificate-not-yet-valid');
    }
    if (!instant.isBefore(notAfter)) {
      throw const FormatException('certificate-expired');
    }
  }

  void validateAlgorithms() {
    final oid = _parsed.signatureAlgorithm.algorithm.nodes.join('.');
    if (_parsed.tbsCertificate.signature?.algorithm.nodes.join('.') != oid) {
      throw const FormatException(
        'Inconsistent certificate signature algorithms.',
      );
    }
    if (!const {
      '1.2.840.113549.1.1.11',
      '1.2.840.113549.1.1.12',
      '1.2.840.113549.1.1.13',
      '1.2.840.10045.4.3.2',
      '1.2.840.10045.4.3.3',
      '1.2.840.10045.4.3.4',
    }.contains(oid)) {
      throw const FormatException(
        'Unsupported certificate signature algorithm.',
      );
    }
    final key = _parsed.publicKey;
    if (key is x509.RsaPublicKey &&
        key.modulus.bitLength >= 2048 &&
        key.modulus.bitLength <= 8192 &&
        key.exponent >= BigInt.from(65537)) {
      return;
    }
    if (key is x509.EcPublicKey &&
        {
          x509.curves.p256,
          x509.curves.p384,
          x509.curves.p521,
        }.contains(key.curve)) {
      return;
    }
    throw const FormatException('Unsupported or weak certificate public key.');
  }

  void validateCa() {
    _validateExtensions();
    validateTime();
    validateAlgorithms();
    if (_extension<x509.BasicConstraints>('2.5.29.19')?.cA != true ||
        _extension<x509.KeyUsage>('2.5.29.15')?.keyCertSign != true) {
      throw const FormatException(
        'Certificate is not a signing certificate authority.',
      );
    }
    final eku = _extension<x509.ExtendedKeyUsage>('2.5.29.37');
    if (eku != null &&
        !eku.ids.any((id) => id.nodes.join('.') == '1.3.6.1.5.5.7.3.1')) {
      throw const FormatException(
        'Certificate authority does not permit TLS server authentication.',
      );
    }
  }

  void validateServer(String host, {bool selfSigned = false}) {
    if (selfSigned) _validateExtensions();
    validateTime();
    validateAlgorithms();
    if (!matchesHost(host)) {
      throw const FormatException('certificate-hostname-mismatch');
    }
    final usage = _extension<x509.KeyUsage>('2.5.29.15');
    if (usage != null && !usage.digitalSignature) {
      throw const FormatException(
        'Certificate does not permit server signatures.',
      );
    }
    final eku = _extension<x509.ExtendedKeyUsage>('2.5.29.37');
    if (eku != null &&
        !eku.ids.any((id) => id.nodes.join('.') == '1.3.6.1.5.5.7.3.1')) {
      throw const FormatException(
        'Certificate does not permit TLS server authentication.',
      );
    }
    if (selfSigned) {
      if (_extension<x509.BasicConstraints>('2.5.29.19')?.cA == true ||
          !_verifySelfSignature()) {
        throw const FormatException(
          'Use a self-signed server leaf, or import the private CA.',
        );
      }
    }
  }

  void _validateExtensions() {
    final seen = <String>{};
    for (final extension in _extensions) {
      final oid = extension.extnId.nodes.join('.');
      if (!seen.add(oid)) {
        throw const FormatException('Duplicate X.509 extension.');
      }
      // Native validation may skip critical-extension checks for an imported
      // trust anchor, including a pinned leaf. Only import critical extensions
      // whose semantics this boundary and native server validation enforce.
      if (extension.isCritical &&
          !const {
            '2.5.29.15',
            '2.5.29.17',
            '2.5.29.19',
            '2.5.29.37',
          }.contains(oid)) {
        throw const FormatException('Unsupported critical X.509 extension.');
      }
    }
  }

  bool matchesHost(String host) {
    final names = _extension<x509.GeneralNames>('2.5.29.17')?.names ?? const [];
    final address = InternetAddress.tryParse(host);
    for (final name in names) {
      if (address != null && name.choice == 7) {
        final bytes = (name.contents as ASN1OctetString).octets;
        if (base64.encode(bytes) == base64.encode(address.rawAddress)) {
          return true;
        }
      } else if (address == null && name.choice == 2) {
        final dns = (name.contents as ASN1IA5String).stringValue.toLowerCase();
        final target = host.toLowerCase();
        final suffix = dns.startsWith('*.') ? dns.substring(2) : dns;
        if (!_validDnsName(suffix) || !_validDnsName(target)) continue;
        if (!dns.contains('*') && dns == target) return true;
        if (dns.startsWith('*.') &&
            !dns.substring(2).contains('*') &&
            dns.split('.').length >= 3 &&
            target.split('.').length == dns.split('.').length &&
            target.substring(target.indexOf('.') + 1) == dns.substring(2)) {
          return true;
        }
      }
    }
    return false; // RFC 9525 deliberately excludes Common Name fallback.
  }

  static bool _validDnsName(String name) =>
      name.length <= 253 &&
      name
          .split('.')
          .every(
            (label) =>
                RegExp(r'^[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?$')
                    .hasMatch(label),
          );

  bool _verifySelfSignature() {
    // Use original encoded TBSCertificate bytes, never a reserialized model.
    final tbs =
        (ASN1Parser(Uint8List.fromList(der)).nextObject() as ASN1Sequence)
                .elements
                .first
            as ASN1Sequence;
    final offset = tbs.elements.first.tag == 0xa0 ? 1 : 0;
    if (base64.encode(tbs.elements[offset + 2].encodedBytes) !=
        base64.encode(tbs.elements[offset + 4].encodedBytes)) {
      return false;
    }
    final oid = _parsed.signatureAlgorithm.algorithm.nodes.join('.');
    final digest = switch (oid) {
      '1.2.840.113549.1.1.11' || '1.2.840.10045.4.3.2' => 'SHA-256',
      '1.2.840.113549.1.1.12' || '1.2.840.10045.4.3.3' => 'SHA-384',
      '1.2.840.113549.1.1.13' || '1.2.840.10045.4.3.4' => 'SHA-512',
      _ => throw const FormatException('Unsupported self signature.'),
    };
    final key = _parsed.publicKey;
    final signature = Uint8List.fromList(_parsed.signatureValue!);
    if (key is x509.RsaPublicKey) {
      if (!oid.startsWith('1.2.840.113549.1.1.')) return false;
      final verifier = pc.Signer('$digest/RSA')
        ..init(
          false,
          pc.PublicKeyParameter<pc.RSAPublicKey>(
            pc.RSAPublicKey(key.modulus, key.exponent),
          ),
        );
      return verifier.verifySignature(
        tbs.encodedBytes,
        pc.RSASignature(signature),
      );
    }
    if (key is x509.EcPublicKey) {
      if (!oid.startsWith('1.2.840.10045.4.3.')) return false;
      final curve = pc.ECDomainParameters(
        key.curve == x509.curves.p256
            ? 'secp256r1'
            : key.curve == x509.curves.p384
            ? 'secp384r1'
            : 'secp521r1',
      );
      final verifier = pc.Signer('$digest/ECDSA')
        ..init(
          false,
          pc.PublicKeyParameter<pc.ECPublicKey>(
            pc.ECPublicKey(
              curve.curve.createPoint(key.xCoordinate, key.yCoordinate),
              curve,
            ),
          ),
        );
      final values = (ASN1Parser(signature).nextObject() as ASN1Sequence)
          .elements
          .cast<ASN1Integer>();
      return verifier.verifySignature(
        tbs.encodedBytes,
        pc.ECSignature(
          values.first.valueAsBigInteger,
          values.last.valueAsBigInteger,
        ),
      );
    }
    return false;
  }
}

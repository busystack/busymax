import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

class PkcePair {
  const PkcePair({required this.codeVerifier, required this.codeChallenge});

  final String codeVerifier;
  final String codeChallenge;
}

PkcePair generatePkcePair({Random? random}) {
  final secureRandom = random ?? Random.secure();
  final bytes = List<int>.generate(64, (_) => secureRandom.nextInt(256));
  final verifier = _base64UrlNoPadding(bytes);

  if (verifier.length < 43 || verifier.length > 128) {
    throw StateError('Generated PKCE verifier length is invalid.');
  }

  return PkcePair(
    codeVerifier: verifier,
    codeChallenge: codeChallengeForVerifier(verifier),
  );
}

String codeChallengeForVerifier(String verifier) {
  if (verifier.length < 43 || verifier.length > 128) {
    throw ArgumentError.value(verifier.length, 'verifier.length');
  }

  final digest = sha256.convert(ascii.encode(verifier));
  return _base64UrlNoPadding(digest.bytes);
}

String generateOAuthState({Random? random}) {
  final secureRandom = random ?? Random.secure();
  final bytes = List<int>.generate(32, (_) => secureRandom.nextInt(256));
  return _base64UrlNoPadding(bytes);
}

String _base64UrlNoPadding(List<int> bytes) {
  return base64UrlEncode(bytes).replaceAll('=', '');
}

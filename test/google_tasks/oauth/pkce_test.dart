import 'package:flutter_test/flutter_test.dart';
import 'package:busymax/src/google_tasks/oauth/pkce.dart';

void main() {
  test('PKCE challenge matches known S256 vector', () {
    const verifier = 'dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk';

    expect(
      codeChallengeForVerifier(verifier),
      'E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM',
    );
  });

  test('PKCE verifier is URL-safe and has valid length', () {
    final pair = generatePkcePair();

    expect(pair.codeVerifier.length, inInclusiveRange(43, 128));
    expect(pair.codeVerifier, matches(RegExp(r'^[A-Za-z0-9_-]+$')));
    expect(pair.codeChallenge, matches(RegExp(r'^[A-Za-z0-9_-]+$')));
  });
}

import 'package:busymax/src/webcal/webcal_uri.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('normalizes WebCal without changing credential components', () {
    final normalized = normalizeWebCalUri(
      '  webcal://Example.COM:8443/path%2Fcalendar?b=2&a=one%20two  ',
    );

    expect(
      normalized.uri.toString(),
      'https://example.com:8443/path%2Fcalendar?b=2&a=one%20two',
    );
    expect(normalized.safeOrigin.toString(), 'https://example.com:8443');
    expect(normalized.fingerprint, webCalUriFingerprint(normalized.uri));
  });

  test('default HTTPS port is omitted only from the safe origin', () {
    final normalized = normalizeWebCalUri(
      'https://example.test:443/calendar?token=private',
    );

    expect(normalized.credentialUri, contains(':443/calendar'));
    expect(normalized.safeOrigin.toString(), 'https://example.test');
  });

  for (final invalid in [
    'http://example.test/calendar',
    'ftp://example.test/calendar',
    'https://user:secret@example.test/calendar',
    'https://example.test/calendar#fragment',
    'webcal:calendar',
    'https://example.test:not-a-port/feed',
    'https://example.test:70000/feed',
  ]) {
    test('rejects $invalid', () {
      expect(
        () => normalizeWebCalUri(invalid),
        throwsA(isA<FormatException>()),
      );
    });
  }

  test('fingerprints distinguish exact normalized subscription targets', () {
    final first = normalizeWebCalUri('webcal://example.test/feed?a=1&b=2');
    final second = normalizeWebCalUri('https://example.test/feed?b=2&a=1');
    expect(first.fingerprint, isNot(second.fingerprint));
  });
}

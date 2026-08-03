import 'package:busymax/src/core/logging/redacting_logger.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

void main() {
  test('redacts OAuth and bearer secrets', () {
    final redacted = redactForLog(
      'Authorization: Bearer abc access_token=one refresh_token=two '
      'code=three code_verifier=four client_secret=five '
      '"client_secret":"six" client_secret: seven',
    );

    expect(redacted, isNot(contains('abc')));
    expect(redacted, isNot(contains('one')));
    expect(redacted, isNot(contains('two')));
    expect(redacted, isNot(contains('three')));
    expect(redacted, isNot(contains('four')));
    expect(redacted, isNot(contains('five')));
    expect(redacted, isNot(contains('six')));
    expect(redacted, isNot(contains('seven')));
    expect(redacted, contains('[REDACTED]'));
  });

  test('redacts a generic revocation token from a failed request URI', () {
    final error = http.ClientException(
      'Connection failed',
      Uri.parse(
        'https://oauth.example.test/revoke'
        '?token=refresh-secret&reason=account-removal',
      ),
    );

    final redacted = redactForLog(
      'Google authorization revocation failed: $error',
    );

    expect(redacted, isNot(contains('refresh-secret')));
    expect(redacted, contains('?token=[REDACTED]'));
    expect(redacted, contains('reason=account-removal'));
  });

  test('does not redact generic token text outside a URL query', () {
    const message = 'The parser returned token=identifier in normal prose.';

    expect(redactForLog(message), message);
  });
}

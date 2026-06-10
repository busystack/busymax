import 'package:flutter_test/flutter_test.dart';
import 'package:busymax/src/core/logging/redacting_logger.dart';

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
}

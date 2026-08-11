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

  test(
    'redacts DAV Basic credentials, app passwords, cookies, and userinfo',
    () {
      final redacted = redactForLog(
        'Authorization: Basic YWxleDphcHAtc2VjcmV0, '
        '{"appPassword":"nextcloud-secret",'
        '"appSpecificPassword":"apple-secret",'
        '"pollToken":"poll-secret",'
        '"login":"https://cloud.test/login/private"} '
        'Cookie: session=cookie-secret\n'
        'https://alex:password-secret@cloud.test/path',
      );

      for (final secret in const [
        'YWxleDphcHAtc2VjcmV0',
        'nextcloud-secret',
        'apple-secret',
        'poll-secret',
        '/login/private',
        'cookie-secret',
        'alex:password-secret',
      ]) {
        expect(redacted, isNot(contains(secret)));
      }
      expect(redacted, contains('Basic [REDACTED]'));
    },
  );

  test('redacts bodies, HREFs, and iCalendar user content', () {
    final redacted = redactForLog(
      'requestBody=private-payload '
      'href=/remote.php/dav/calendars/alex/private/event.ics\n'
      'BEGIN:VEVENT\n'
      'SUMMARY:Private title\n'
      'DESCRIPTION:Private notes\n'
      'ATTENDEE;CN=Private Person:mailto:person@example.test\n'
      'LOCATION:Private place\n'
      'END:VEVENT',
    );

    for (final content in const [
      'private-payload',
      '/remote.php/dav/calendars/alex/private/event.ics',
      'Private title',
      'Private notes',
      'person@example.test',
      'Private place',
    ]) {
      expect(redacted, isNot(contains(content)));
    }
  });

  test('redacts credential-like URL query parameters only by value', () {
    final redacted = redactForLog(
      'https://cloud.test/callback?app_password=secret-one'
      '&ticket=secret-two&safe=value',
    );

    expect(redacted, contains('app_password=[REDACTED]'));
    expect(redacted, contains('ticket=[REDACTED]'));
    expect(redacted, contains('safe=value'));
    expect(redacted, isNot(contains('secret-one')));
    expect(redacted, isNot(contains('secret-two')));
  });
}

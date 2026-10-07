import 'package:flutter_test/flutter_test.dart';
import 'package:busymax/src/google_tasks/oauth/oauth_loopback_flow.dart';
import 'package:busymax/src/core/auth/oauth_models.dart';

void main() {
  for (final entry in {
    'access_denied': OAuthFailureKind.permission,
    'invalid_client': OAuthFailureKind.configuration,
    'invalid_scope': OAuthFailureKind.configuration,
    'temporarily_unavailable': OAuthFailureKind.temporary,
    'server_error': OAuthFailureKind.temporary,
    'secret-unknown-provider-value': OAuthFailureKind.temporary,
  }.entries) {
    test('validated callback ${entry.key} retains actionable classification', () {
      expect(
        () => parseOAuthCallback(
          Uri.parse(
            'http://127.0.0.1:4567/?state=same&error=${entry.key}&error_description=secret-description',
          ),
          expectedState: 'same',
          expectedPort: 4567,
        ),
        throwsA(
          isA<OAuthException>()
              .having((e) => e.classification, 'classification', entry.value)
              .having(
                (e) => e.toString().contains('secret-'),
                'secret redaction',
                false,
              ),
        ),
      );
    });
  }
  test('callback parser accepts code and validates state', () {
    final callback = parseOAuthCallback(
      Uri.parse('http://127.0.0.1:4567/?state=same&code=code&scope=tasks'),
      expectedState: 'same',
      expectedPort: 4567,
      hostHeader: '127.0.0.1:4567',
    );

    expect(callback.code, 'code');
    expect(callback.scope, 'tasks');
  });

  test('callback parser rejects state mismatch', () {
    expect(
      () => parseOAuthCallback(
        Uri.parse('http://127.0.0.1:4567/?state=wrong&code=code'),
        expectedState: 'same',
        expectedPort: 4567,
        hostHeader: '127.0.0.1:4567',
      ),
      throwsA(isA<OAuthException>()),
    );
  });

  test('callback parser rejects non-loopback host header', () {
    expect(
      () => parseOAuthCallback(
        Uri.parse('http://127.0.0.1:4567/?state=same&code=code'),
        expectedState: 'same',
        expectedPort: 4567,
        hostHeader: '0.0.0.0:4567',
      ),
      throwsA(isA<OAuthException>()),
    );
  });
}

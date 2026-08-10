import 'dart:convert';

import 'package:busymax/src/core/secrets/secret_store.dart';
import 'package:busymax/src/dav/auth/nextcloud_app_password_revoker.dart';
import 'package:busymax/src/dav/dav_errors.dart';
import 'package:busymax/src/dav/dav_provider_profile.dart';
import 'package:busymax/src/dav/http/dav_http_transport.dart';
import 'package:busymax/src/providers/busy_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  final credential = NextcloudSecretRecord(
    canonicalServer: Uri.parse('https://cloud.example.test/nextcloud'),
    loginName: 'alex',
    appPassword: 'app-secret',
  );

  test(
    'uses the documented endpoint, current Basic credential, and OCS header',
    () async {
      late http.Request captured;
      final revoker = NextcloudAppPasswordRevoker(
        transport: _transport(
          MockClient((request) async {
            captured = request;
            return http.Response('', 204);
          }),
        ),
      );

      await revoker.revoke(
        accountId: 'nextcloud:alex',
        credential: credential,
        correlationId: 'revoke-1',
      );

      expect(captured.method, 'DELETE');
      expect(
        captured.url,
        Uri.parse(
          'https://cloud.example.test/nextcloud/ocs/v2.php/core/apppassword',
        ),
      );
      expect(captured.headers['ocs-apirequest'], 'true');
      expect(captured.headers['accept'], 'application/json');
      final authorization = captured.headers['authorization']!;
      expect(authorization, startsWith('Basic '));
      expect(
        utf8.decode(base64Decode(authorization.substring('Basic '.length))),
        'alex:app-secret',
      );
    },
  );

  for (final expectation in const [
    (status: 401, kind: DavErrorKind.authentication),
    (status: 403, kind: DavErrorKind.authorization),
    (status: 409, kind: DavErrorKind.protocol),
    (status: 503, kind: DavErrorKind.server),
  ]) {
    test('maps ${expectation.status} and never retries revocation', () async {
      var calls = 0;
      final revoker = NextcloudAppPasswordRevoker(
        transport: _transport(
          MockClient((_) async {
            calls += 1;
            return http.Response('', expectation.status);
          }),
        ),
      );

      await expectLater(
        revoker.revoke(
          accountId: 'nextcloud:alex',
          credential: credential,
          correlationId: 'revoke-error',
        ),
        throwsA(
          isA<DavException>()
              .having((error) => error.kind, 'kind', expectation.kind)
              .having(
                (error) => error.code,
                'code',
                'NextcloudAppPasswordRevocationFailed',
              )
              .having(
                (error) => error.statusCode,
                'statusCode',
                expectation.status,
              )
              .having(
                (error) => error.correlationId,
                'correlationId',
                'revoke-error',
              ),
        ),
      );
      expect(calls, 1);
    });
  }
}

DavHttpTransport _transport(http.Client client) => DavHttpTransport(
  client: client,
  profile: davProviderProfile(
    BusyProvider.nextcloud,
    nextcloudServer: Uri.parse('https://cloud.example.test/nextcloud'),
  ),
  accountAuthority: Uri.parse('https://cloud.example.test/nextcloud'),
  delay: (_) async {},
);

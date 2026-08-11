import '../../core/secrets/secret_store.dart';
import '../dav_errors.dart';
import '../http/dav_http_transport.dart';

final class NextcloudAppPasswordRevoker {
  const NextcloudAppPasswordRevoker({required DavHttpTransport transport})
    : _transport = transport;

  final DavHttpTransport _transport;

  Future<void> revoke({
    required String accountId,
    required NextcloudSecretRecord credential,
    required String correlationId,
  }) async {
    final endpoint = _appendPath(
      credential.canonicalServer,
      'ocs/v2.php/core/apppassword',
    );
    final response = await _transport.send(
      DavRequest(
        method: 'DELETE',
        uri: endpoint,
        accountId: accountId,
        correlationId: correlationId,
        headers: const {'ocs-apirequest': 'true', 'accept': 'application/json'},
        retryClass: DavRetryClass.never,
      ),
      credential: DavBasicCredential(
        username: credential.loginName,
        password: credential.appPassword,
      ),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw DavException(
        kind: response.statusCode == 401
            ? DavErrorKind.authentication
            : response.statusCode == 403
            ? DavErrorKind.authorization
            : response.statusCode >= 500
            ? DavErrorKind.server
            : DavErrorKind.protocol,
        code: 'NextcloudAppPasswordRevocationFailed',
        safeMessage: 'The Nextcloud app password could not be revoked.',
        statusCode: response.statusCode,
        correlationId: correlationId,
        retryAfter: parseDavRetryAfter(response.headers['retry-after']),
      );
    }
  }
}

Uri _appendPath(Uri base, String suffix) {
  final path = base.path.isEmpty
      ? '/$suffix'
      : '${base.path.endsWith('/') ? base.path : '${base.path}/'}$suffix';
  return base.replace(path: path, query: null, fragment: null);
}

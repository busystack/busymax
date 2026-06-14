import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:dbus/dbus.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;

import '../../core/logging/redacting_logger.dart';
import 'oauth_models.dart';
import 'oauth_token_store.dart';

const _encryptedTokenStoreVersion = 1;

class PortalEncryptedOAuthTokenStore implements OAuthTokenStore {
  PortalEncryptedOAuthTokenStore({
    SecretPortalClient? portalClient,
    File? storageFile,
    RedactingLogger? logger,
  }) : _portalClient = portalClient ?? XdgSecretPortalClient(),
       _storageFile = storageFile ?? _defaultStorageFile(),
       _logger =
           logger ?? RedactingLogger(Logger('PortalEncryptedOAuthTokenStore'));

  final SecretPortalClient _portalClient;
  final File _storageFile;
  final RedactingLogger _logger;
  final AesGcm _cipher = AesGcm.with256bits();
  final Hkdf _kdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);
  PortalSecret? _cachedSecret;
  var _loggedRuntime = false;

  static const _activeAccountKey = SecureOAuthTokenStore.activeAccountKey;
  static const _kdfInfo = 'io.busystack.busymax.oauth-token-store.v1';

  @override
  Future<String?> readActiveAccountId() => _read(_activeAccountKey);

  @override
  Future<OAuthTokenSet?> readTokenSet(String accountId) async {
    final accessToken = await _read(_key(accountId, 'access_token'));
    final expiresAtText = await _read(_key(accountId, 'expires_at_utc'));
    if (accessToken == null || expiresAtText == null) {
      return null;
    }

    final refreshToken = await _read(_key(accountId, 'refresh_token'));
    final tokenType = await _read(_key(accountId, 'token_type'));
    final scopeText = await _read(_key(accountId, 'scope'));
    final idToken = await _read(_key(accountId, 'id_token'));

    return OAuthTokenSet(
      accessToken: accessToken,
      refreshToken: refreshToken,
      idToken: idToken,
      expiresAtUtc: DateTime.parse(expiresAtText).toUtc(),
      tokenType: tokenType ?? 'Bearer',
      scopes: (scopeText ?? '')
          .split(RegExp(r'\s+'))
          .where((scope) => scope.isNotEmpty)
          .toSet(),
    );
  }

  @override
  Future<void> saveTokenSet(String accountId, OAuthTokenSet tokenSet) async {
    final values = await _readAll('write');
    values[_key(accountId, 'access_token')] = tokenSet.accessToken;
    if (tokenSet.refreshToken != null) {
      values[_key(accountId, 'refresh_token')] = tokenSet.refreshToken!;
    }
    if (tokenSet.idToken != null) {
      values[_key(accountId, 'id_token')] = tokenSet.idToken!;
    }
    values[_key(accountId, 'expires_at_utc')] = tokenSet.expiresAtUtc
        .toUtc()
        .toIso8601String();
    values[_key(accountId, 'token_type')] = tokenSet.tokenType;
    values[_key(accountId, 'scope')] = tokenSet.scopes.join(' ');
    await _writeAll(values, 'write');
  }

  @override
  Future<void> setActiveAccountId(String accountId) {
    return _write(_activeAccountKey, accountId);
  }

  @override
  Future<void> clearTokenSet(String accountId) async {
    final values = await _readAll('delete');
    final beforeLength = values.length;
    values.remove(_key(accountId, 'access_token'));
    values.remove(_key(accountId, 'refresh_token'));
    values.remove(_key(accountId, 'id_token'));
    values.remove(_key(accountId, 'expires_at_utc'));
    values.remove(_key(accountId, 'token_type'));
    values.remove(_key(accountId, 'scope'));
    if (values.length == beforeLength) {
      return;
    }
    await _writeAll(values, 'delete');
  }

  @override
  Future<void> clearActiveAccount() {
    return _delete(_activeAccountKey);
  }

  Future<String?> _read(String key) async {
    final values = await _readAll('read');
    return values[key];
  }

  Future<void> _write(String key, String value) async {
    final values = await _readAll('write');
    values[key] = value;
    await _writeAll(values, 'write');
  }

  Future<void> _delete(String key) async {
    final values = await _readAll('delete');
    if (!values.containsKey(key)) {
      return;
    }
    values.remove(key);
    await _writeAll(values, 'delete');
  }

  Future<Map<String, String>> _readAll(String operation) async {
    _logRuntime();
    if (!await _storageFile.exists()) {
      return {};
    }

    try {
      final envelope = _asStringObjectMap(
        jsonDecode(await _storageFile.readAsString()),
      );
      final secret = await _retrieveSecret(
        operation,
        token: envelope['portal_token'],
      );
      final salt = _decodeRequired(envelope, 'salt');
      final key = await _deriveKey(secret.bytes, salt);
      final box = SecretBox(
        _decodeRequired(envelope, 'ciphertext'),
        nonce: _decodeRequired(envelope, 'nonce'),
        mac: Mac(_decodeRequired(envelope, 'mac')),
      );
      final clearBytes = await _cipher.decrypt(box, secretKey: key);
      return _asStringMap(jsonDecode(utf8.decode(clearBytes)));
    } on Object catch (error) {
      if (error is OAuthException) {
        rethrow;
      }
      throw _storageException(operation, error);
    }
  }

  Future<void> _writeAll(Map<String, String> values, String operation) async {
    _logRuntime();
    try {
      await _storageFile.parent.create(recursive: true);
      final existing = await _readEnvelopeIfPresent();
      final salt = existing == null
          ? _randomBytes(16)
          : _decodeRequired(existing, 'salt');
      final secret = await _retrieveSecret(
        operation,
        token: existing?['portal_token'],
      );
      final key = await _deriveKey(secret.bytes, salt);
      final nonce = _cipher.newNonce();
      final box = await _cipher.encrypt(
        utf8.encode(jsonEncode(values)),
        secretKey: key,
        nonce: nonce,
      );
      final envelope = <String, Object?>{
        'version': _encryptedTokenStoreVersion,
        'cipher': 'aes-256-gcm',
        'kdf': 'hkdf-sha256',
        'salt': base64Encode(salt),
        'nonce': base64Encode(box.nonce),
        'ciphertext': base64Encode(box.cipherText),
        'mac': base64Encode(box.mac.bytes),
        if (secret.token != null && secret.token!.isNotEmpty)
          'portal_token': secret.token,
      };
      final tempFile = File('${_storageFile.path}.tmp');
      await tempFile.writeAsString(jsonEncode(envelope), flush: true);
      await tempFile.rename(_storageFile.path);
    } on Object catch (error) {
      if (error is OAuthException) {
        rethrow;
      }
      throw _storageException(operation, error);
    }
  }

  Future<Map<String, String>?> _readEnvelopeIfPresent() async {
    if (!await _storageFile.exists()) {
      return null;
    }
    return _asStringObjectMap(jsonDecode(await _storageFile.readAsString()));
  }

  Future<PortalSecret> _retrieveSecret(
    String operation, {
    String? token,
  }) async {
    final cached = _cachedSecret;
    if (cached != null) {
      return cached;
    }
    try {
      final secret = await _portalClient.retrieveSecret(token: token);
      _cachedSecret = secret;
      _logger.info(
        'Secure token storage portal retrieve succeeded: '
        'operation=$operation snap=${_isRunningInSnap()} '
        'secret_backend=${_secretBackendLabel()} has_portal_token=${secret.token != null}',
      );
      return secret;
    } on Object catch (error) {
      throw _storageException('portal.retrieveSecret/$operation', error);
    }
  }

  Future<SecretKeyData> _deriveKey(List<int> secret, List<int> salt) {
    return _kdf.deriveKey(
      secretKey: SecretKey(secret),
      nonce: salt,
      info: utf8.encode(_kdfInfo),
    );
  }

  void _logRuntime() {
    if (_loggedRuntime) {
      return;
    }
    _loggedRuntime = true;
    _logger.info(
      'Secure token storage runtime: backend=xdg-secret-portal-file '
      'snap=${_isRunningInSnap()} secret_backend=${_secretBackendLabel()}',
    );
  }

  OAuthException _storageException(String operation, Object error) {
    _logger.warning(
      'Secure token storage $operation failed: '
      '${sanitizedSecureStorageError(error)}',
    );
    if (error is OAuthException) {
      return error;
    }
    return const OAuthException(
      'OAuthSecureStorageUnavailable',
      secureTokenStorageUnavailableMessage,
    );
  }

  String _key(String accountId, String name) =>
      'busymax.oauth.$accountId.$name';
}

abstract interface class SecretPortalClient {
  Future<PortalSecret> retrieveSecret({String? token});
}

class PortalSecret {
  const PortalSecret({required this.bytes, this.token});

  final List<int> bytes;
  final String? token;
}

class XdgSecretPortalClient implements SecretPortalClient {
  XdgSecretPortalClient({DBusClient? client, Duration? timeout})
    : _client = client,
      _timeout = timeout ?? const Duration(minutes: 2);

  final DBusClient? _client;
  final Duration _timeout;

  @override
  Future<PortalSecret> retrieveSecret({String? token}) async {
    final ownsClient = _client == null;
    final client = _client ?? DBusClient.session();
    Directory? tempDir;
    RandomAccessFile? fd;
    try {
      await client.listNames();
      final handleToken = _requestToken();
      final sender = _portalSenderName(client.uniqueName);
      final expectedPath = DBusObjectPath(
        '/org/freedesktop/portal/desktop/request/$sender/$handleToken',
      );
      final requestObject = DBusRemoteObject(
        client,
        name: 'org.freedesktop.portal.Desktop',
        path: expectedPath,
      );
      final responseFuture = DBusRemoteObjectSignalStream(
        object: requestObject,
        interface: 'org.freedesktop.portal.Request',
        name: 'Response',
        signature: DBusSignature('ua{sv}'),
      ).first.timeout(_timeout);

      tempDir = await Directory.systemTemp.createTemp('busymax-secret-portal-');
      final secretFile = File(p.join(tempDir.path, 'secret'));
      fd = await secretFile.open(mode: FileMode.write);

      final portalObject = DBusRemoteObject(
        client,
        name: 'org.freedesktop.portal.Desktop',
        path: DBusObjectPath('/org/freedesktop/portal/desktop'),
      );
      final options = <String, DBusValue>{
        'handle_token': DBusString(handleToken),
        if (token != null && token.isNotEmpty) 'token': DBusString(token),
      };
      final response = await portalObject.callMethod(
        'org.freedesktop.portal.Secret',
        'RetrieveSecret',
        [
          DBusUnixFd(ResourceHandle.fromFile(fd)),
          DBusDict.stringVariant(options),
        ],
        replySignature: DBusSignature('o'),
      );
      final returnedPath = response.returnValues[0].asObjectPath();
      final DBusSignal signal;
      if (returnedPath.value == expectedPath.value) {
        signal = await responseFuture;
      } else {
        unawaited(
          responseFuture.catchError(
            (Object _) => DBusSignal(
              sender: null,
              path: expectedPath,
              interface: 'org.freedesktop.portal.Request',
              name: 'Response',
            ),
          ),
        );
        signal = await DBusRemoteObjectSignalStream(
          object: DBusRemoteObject(
            client,
            name: 'org.freedesktop.portal.Desktop',
            path: returnedPath,
          ),
          interface: 'org.freedesktop.portal.Request',
          name: 'Response',
          signature: DBusSignature('ua{sv}'),
        ).first.timeout(_timeout);
      }

      final responseCode = signal.values[0].asUint32();
      final results = signal.values[1].asStringVariantDict();
      if (responseCode == 1) {
        throw const SecretPortalException(
          code: 'PortalUserCancelled',
          message: 'The Secret portal request was cancelled.',
        );
      }
      if (responseCode != 0) {
        throw SecretPortalException(
          code: 'PortalResponse$responseCode',
          message: 'The Secret portal did not return a secret.',
        );
      }

      await fd.close();
      fd = null;
      final secretBytes = await secretFile.readAsBytes();
      if (secretBytes.isEmpty) {
        throw const SecretPortalException(
          code: 'PortalEmptySecret',
          message: 'The Secret portal returned an empty secret.',
        );
      }
      return PortalSecret(
        bytes: secretBytes,
        token: results['token']?.asString(),
      );
    } finally {
      await fd?.close();
      await tempDir?.delete(recursive: true);
      if (ownsClient) {
        await client.close();
      }
    }
  }
}

class SecretPortalException implements Exception {
  const SecretPortalException({required this.code, required this.message});

  final String code;
  final String message;

  @override
  String toString() => '$code: $message';
}

String sanitizedSecureStorageError(Object error) {
  if (error is DBusMethodResponseException) {
    return 'domain=dbus code=${error.errorName} '
        'message=${_sanitize(error.response.values.isEmpty ? '' : error.response.values.first.toNative())}';
  }
  if (error is SecretPortalException) {
    return 'domain=org.freedesktop.portal.Secret code=${error.code} '
        'message=${_sanitize(error.message)}';
  }
  if (error is FormatException) {
    return 'domain=dart code=FormatException message=${_sanitize(error.message)}';
  }
  if (error is SecretBoxAuthenticationError) {
    return 'domain=cryptography code=SecretBoxAuthenticationError '
        'message=encrypted token store authentication failed';
  }
  return 'domain=dart code=${error.runtimeType} message=${_sanitize(error)}';
}

File _defaultStorageFile() {
  final dataHome =
      Platform.environment['XDG_DATA_HOME'] ??
      p.join(Platform.environment['HOME'] ?? '.', '.local', 'share');
  return File(p.join(dataHome, 'busymax', 'oauth-tokens.v1.json'));
}

Map<String, String> _asStringMap(Object? value) {
  if (value is! Map) {
    throw const FormatException('Encrypted token store payload is not a map.');
  }
  return value.map((key, value) {
    if (key is! String || value is! String) {
      throw const FormatException(
        'Encrypted token store payload has invalid entries.',
      );
    }
    return MapEntry(key, value);
  });
}

Map<String, String> _asStringObjectMap(Object? value) {
  if (value is! Map) {
    throw const FormatException('Encrypted token store envelope is not a map.');
  }
  final version = value['version'];
  if (version != _encryptedTokenStoreVersion) {
    throw FormatException(
      'Unsupported encrypted token store version $version.',
    );
  }
  return value.map((key, value) {
    if (key is! String) {
      throw const FormatException(
        'Encrypted token store envelope has invalid keys.',
      );
    }
    return MapEntry(key, value?.toString() ?? '');
  });
}

List<int> _decodeRequired(Map<String, String> envelope, String key) {
  final value = envelope[key];
  if (value == null || value.isEmpty) {
    throw FormatException('Encrypted token store missing $key.');
  }
  return base64Decode(value);
}

List<int> _randomBytes(int length) {
  final random = Random.secure();
  return List<int>.generate(length, (_) => random.nextInt(256));
}

String _requestToken() {
  final bytes = _randomBytes(16);
  final hex = bytes
      .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
      .join();
  return 'busymax_$hex';
}

String generatePortalRequestTokenForTesting() => _requestToken();

String _portalSenderName(String uniqueName) {
  final trimmed = uniqueName.startsWith(':')
      ? uniqueName.substring(1)
      : uniqueName;
  return trimmed.replaceAll('.', '_');
}

bool _isRunningInSnap() => Platform.environment['SNAP']?.isNotEmpty ?? false;

String _secretBackendLabel() {
  final backend = Platform.environment['SECRET_BACKEND'];
  if (backend == null || backend.isEmpty) {
    return '<unset>';
  }
  if (backend == 'file') {
    return 'file';
  }
  return '<set>';
}

String _sanitize(Object? value) {
  final text = redactForLog(value);
  return text.replaceAll(RegExp(r'\s+'), ' ').trim();
}

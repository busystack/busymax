import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:dbus/dbus.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;
import 'package:posix/posix.dart' show chmod;

import '../../providers/busy_provider.dart';
import '../auth/oauth_models.dart';
import '../logging/redacting_logger.dart';
import 'secret_store.dart';

const _encryptedTokenStoreVersion = 1;

class PortalEncryptedSecretStore implements SecretStore {
  PortalEncryptedSecretStore({
    SecretPortalClient? portalClient,
    File? storageFile,
    RedactingLogger? logger,
  }) : _portalClient = portalClient ?? XdgSecretPortalClient(),
       _storageFile = storageFile ?? _defaultStorageFile(),
       _logger =
           logger ?? RedactingLogger(Logger('PortalEncryptedSecretStore'));

  final SecretPortalClient _portalClient;
  final File _storageFile;
  final RedactingLogger _logger;
  final AesGcm _cipher = AesGcm.with256bits();
  final Hkdf _kdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);
  PortalSecret? _cachedSecret;
  var _loggedRuntime = false;

  static const _activeAccountKey = SecureSecretStore.activeAccountKey;
  static const _legacyActiveAccountKey =
      SecureSecretStore.legacyActiveAccountKey;
  static const _kdfInfo = 'io.busystack.busymax.oauth-token-store.v1';

  @override
  Future<String?> readActiveAccountId() async {
    final current = await _read(_activeAccountKey);
    if (current != null) {
      return current;
    }
    final legacy = await _read(_legacyActiveAccountKey);
    if (legacy == null) {
      return null;
    }
    await _write(_activeAccountKey, legacy);
    if (await _read(_activeAccountKey) != legacy) {
      throw const SecretStoreException(
        'SecretStoreMigrationVerificationFailed',
        'The active account secret migration could not be verified.',
      );
    }
    await _delete(_legacyActiveAccountKey);
    return legacy;
  }

  @override
  Future<SecretRecord?> readCredential(String accountId) async {
    final serialized = await _read(_credentialKey(accountId));
    if (serialized == null) {
      return null;
    }
    return _decodePortalCredential(serialized);
  }

  @override
  Future<void> saveCredential(String accountId, SecretRecord credential) async {
    final values = await _readAll('write');
    values[_credentialKey(accountId)] = jsonEncode(credential.toJson());
    await _writeAll(values, 'write');
  }

  @override
  Future<void> setActiveAccountId(String accountId) {
    return _write(_activeAccountKey, accountId);
  }

  @override
  Future<void> deleteCredential(String accountId) async {
    final values = await _readAll('delete');
    if (values.remove(_credentialKey(accountId)) == null) {
      return;
    }
    await _writeAll(values, 'delete');
  }

  @override
  Future<bool> migrateLegacyOAuthCredential(
    String accountId,
    BusyProvider provider,
  ) async {
    if (provider != BusyProvider.google && provider != BusyProvider.microsoft) {
      return false;
    }
    final values = await _readAll('migrate');
    if (values.containsKey(_credentialKey(accountId))) {
      return false;
    }
    final accessToken = values[_legacyKey(accountId, 'access_token')];
    final expiresAt = values[_legacyKey(accountId, 'expires_at_utc')];
    if (accessToken == null || expiresAt == null) {
      return false;
    }
    final record = OAuthSecretRecord(
      provider: provider,
      tokenSet: OAuthTokenSet(
        accessToken: accessToken,
        refreshToken: values[_legacyKey(accountId, 'refresh_token')],
        idToken: values[_legacyKey(accountId, 'id_token')],
        expiresAtUtc: DateTime.parse(expiresAt).toUtc(),
        tokenType: values[_legacyKey(accountId, 'token_type')] ?? 'Bearer',
        scopes: (values[_legacyKey(accountId, 'scope')] ?? '')
            .split(RegExp(r'\s+'))
            .where((scope) => scope.isNotEmpty)
            .toSet(),
      ),
    );
    values[_credentialKey(accountId)] = jsonEncode(record.toJson());
    await _writeAll(values, 'migrate-write');
    final verified = await readOAuthTokenSet(accountId, provider);
    if (verified == null || verified.accessToken != accessToken) {
      throw const SecretStoreException(
        'SecretStoreMigrationVerificationFailed',
        'The OAuth credential migration could not be verified.',
      );
    }
    final migrated = await _readAll('migrate-delete');
    for (final name in _legacyOAuthFieldNames) {
      migrated.remove(_legacyKey(accountId, name));
    }
    await _writeAll(migrated, 'migrate-delete');
    return true;
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
      await _restrictExistingStoragePermissions();
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
      if (error is SecretStoreException) {
        rethrow;
      }
      throw _storageException(operation, error);
    }
  }

  Future<void> _writeAll(Map<String, String> values, String operation) async {
    _logRuntime();
    try {
      await _storageFile.parent.create(recursive: true);
      _restrictPermissions(_storageFile.parent.path, '700');
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
      final tempType = await FileSystemEntity.type(
        tempFile.path,
        followLinks: false,
      );
      if (tempType == FileSystemEntityType.notFound) {
        await tempFile.create(exclusive: true);
      } else if (tempType != FileSystemEntityType.file) {
        throw FileSystemException(
          'The encrypted credential temporary path is not a regular file.',
          tempFile.path,
        );
      }
      _restrictPermissions(tempFile.path, '600');
      await tempFile.writeAsString(jsonEncode(envelope), flush: true);
      await tempFile.rename(_storageFile.path);
      _restrictPermissions(_storageFile.path, '600');
    } on Object catch (error) {
      if (error is SecretStoreException) {
        rethrow;
      }
      throw _storageException(operation, error);
    }
  }

  Future<Map<String, String>?> _readEnvelopeIfPresent() async {
    if (!await _storageFile.exists()) {
      return null;
    }
    await _restrictExistingStoragePermissions();
    return _asStringObjectMap(jsonDecode(await _storageFile.readAsString()));
  }

  Future<void> _restrictExistingStoragePermissions() async {
    final type = await FileSystemEntity.type(
      _storageFile.path,
      followLinks: false,
    );
    if (type != FileSystemEntityType.file) {
      throw FileSystemException(
        'The encrypted credential path is not a regular file.',
        _storageFile.path,
      );
    }
    _restrictPermissions(_storageFile.parent.path, '700');
    _restrictPermissions(_storageFile.path, '600');
  }

  void _restrictPermissions(String path, String permissions) {
    if (Platform.isLinux || Platform.isMacOS) {
      chmod(path, permissions);
    }
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
        'Secure credential storage portal retrieve succeeded: '
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
      'Secure credential storage runtime: backend=xdg-secret-portal-file '
      'snap=${_isRunningInSnap()} secret_backend=${_secretBackendLabel()}',
    );
  }

  SecretStoreException _storageException(String operation, Object error) {
    _logger.warning(
      'Secure credential storage $operation failed: '
      '${sanitizedSecureStorageError(error)}',
    );
    if (error is SecretStoreException) {
      return error;
    }
    return const SecretStoreException(
      'SecretStoreUnavailable',
      secretStorageUnavailableMessage,
    );
  }

  String _credentialKey(String accountId) => 'busymax.secret.$accountId.v1';

  String _legacyKey(String accountId, String name) =>
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

SecretRecord _decodePortalCredential(String serialized) {
  try {
    final decoded = jsonDecode(serialized);
    if (decoded is! Map) {
      throw const SecretStoreCorruptException(
        'The encrypted credential record is not a JSON object.',
      );
    }
    return SecretRecord.fromJson(decoded.cast<String, Object?>());
  } on SecretStoreException {
    rethrow;
  } on Object catch (error) {
    throw SecretStoreCorruptException(
      'The encrypted credential record could not be decoded '
      '(${error.runtimeType}).',
    );
  }
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

const _legacyOAuthFieldNames = <String>[
  'access_token',
  'refresh_token',
  'id_token',
  'expires_at_utc',
  'token_type',
  'scope',
];

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

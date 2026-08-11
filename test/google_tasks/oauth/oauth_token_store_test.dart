import 'dart:io';
import 'dart:convert';

import 'package:busymax/src/core/auth/oauth_models.dart';
import 'package:busymax/src/core/secrets/secret_store.dart';
import 'package:busymax/src/core/secrets/portal_encrypted_secret_store.dart';
import 'package:busymax/src/providers/busy_provider.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:posix/posix.dart' show chmod;

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp(
      'busymax-token-store-test-',
    );
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test(
    'secure storage platform failures become typed secret-store errors',
    () async {
      final store = SecureSecretStore(
        _ThrowingSecureStorage(
          PlatformException(
            code: 'KeyringLocked',
            message: 'raw keyring message',
          ),
        ),
      );

      await expectLater(
        store.readActiveAccountId(),
        throwsA(
          isA<SecretStoreException>()
              .having((error) => error.code, 'code', 'SecretStoreUnavailable')
              .having(
                (error) => error.message,
                'message',
                secretStorageUnavailableMessage,
              ),
        ),
      );
    },
  );

  test(
    'credential records are versioned, typed, and redacted in diagnostics',
    () {
      final records = <SecretRecord>[
        OAuthSecretRecord(provider: BusyProvider.google, tokenSet: _tokenSet()),
        AppleICloudSecretRecord(
          username: 'User@Example.com',
          appSpecificPassword: 'abcd-efgh-ijkl-mnop',
        ),
        NextcloudSecretRecord(
          canonicalServer: Uri.parse('https://cloud.example.test/nextcloud'),
          loginName: 'alex',
          appPassword: 'nextcloud-app-secret',
        ),
      ];

      for (final record in records) {
        final json = record.toJson();
        expect(json['schemaVersion'], secretRecordSchemaVersion);
        final restored = SecretRecord.fromJson(
          (jsonDecode(jsonEncode(json)) as Map).cast<String, Object?>(),
        );
        expect(restored.runtimeType, record.runtimeType);
        expect(restored.provider, record.provider);
        expect(restored.kind, record.kind);
        expect(record.toString(), contains('[REDACTED]'));
        expect(record.toString(), isNot(contains('access-secret')));
        expect(record.toString(), isNot(contains('abcd-efgh')));
        expect(record.toString(), isNot(contains('nextcloud-app-secret')));
      }
    },
  );

  test('typed reads reject a credential from another provider', () async {
    final store = InMemorySecretStore();
    await store.saveOAuthTokenSet(
      'account-1',
      BusyProvider.google,
      _tokenSet(),
    );

    await expectLater(
      store.readOAuthTokenSet('account-1', BusyProvider.microsoft),
      throwsA(
        isA<SecretStoreCredentialMismatchException>().having(
          (error) => error.actualProvider,
          'actualProvider',
          BusyProvider.google,
        ),
      ),
    );
  });

  test('legacy OAuth keys are deleted only after verified migration', () async {
    final storage = _MemorySecureStorage({
      'busymax.oauth.account-1.access_token': 'legacy-access',
      'busymax.oauth.account-1.refresh_token': 'legacy-refresh',
      'busymax.oauth.account-1.expires_at_utc': '2026-08-08T01:00:00.000Z',
      'busymax.oauth.account-1.token_type': 'Bearer',
      'busymax.oauth.account-1.scope': 'scope-a scope-b',
      SecureSecretStore.legacyActiveAccountKey: 'account-1',
    });
    final store = SecureSecretStore(storage);

    expect(
      await store.migrateLegacyOAuthCredential(
        'account-1',
        BusyProvider.google,
      ),
      isTrue,
    );
    final tokenSet = await store.readOAuthTokenSet(
      'account-1',
      BusyProvider.google,
    );
    expect(tokenSet?.accessToken, 'legacy-access');
    expect(tokenSet?.refreshToken, 'legacy-refresh');
    expect(tokenSet?.scopes, {'scope-a', 'scope-b'});
    expect(
      storage.values.keys,
      isNot(contains('busymax.oauth.account-1.access_token')),
    );
    expect(storage.values.keys, contains('busymax.secret.account-1.v1'));

    expect(await store.readActiveAccountId(), 'account-1');
    expect(
      storage.values.keys,
      isNot(contains(SecureSecretStore.legacyActiveAccountKey)),
    );
    expect(storage.values[SecureSecretStore.activeAccountKey], 'account-1');
  });

  test(
    'portal encrypted secret store does not write plaintext credentials',
    () async {
      final storageFile = File('${tempDir.path}/oauth-tokens.v1.json');
      final portal = _FakeSecretPortalClient(
        const PortalSecret(bytes: _secretBytes, token: 'portal-token'),
      );
      final store = PortalEncryptedSecretStore(
        portalClient: portal,
        storageFile: storageFile,
      );
      final tokenSet = _tokenSet();

      await store.saveOAuthTokenSet('account-1', BusyProvider.google, tokenSet);
      await store.setActiveAccountId('account-1');

      final rawFile = await storageFile.readAsString();
      expect(rawFile, isNot(contains('access-secret')));
      expect(rawFile, isNot(contains('refresh-secret')));
      expect(rawFile, isNot(contains('id-secret')));
      expect(rawFile, contains('ciphertext'));
      expect(rawFile, contains('portal-token'));
      expect((await storageFile.stat()).mode & 0x1ff, 0x180);
      expect((await storageFile.parent.stat()).mode & 0x1ff, 0x1c0);

      chmod(storageFile.path, '664');
      chmod(storageFile.parent.path, '775');

      final restoredStore = PortalEncryptedSecretStore(
        portalClient: _FakeSecretPortalClient(
          const PortalSecret(bytes: _secretBytes, token: 'portal-token'),
        ),
        storageFile: storageFile,
      );

      expect(await restoredStore.readActiveAccountId(), 'account-1');
      final restored = await restoredStore.readOAuthTokenSet(
        'account-1',
        BusyProvider.google,
      );
      expect(restored?.accessToken, 'access-secret');
      expect(restored?.refreshToken, 'refresh-secret');
      expect(restored?.idToken, 'id-secret');
      expect(restored?.scopes, {'scope-a', 'scope-b'});
      expect((await storageFile.stat()).mode & 0x1ff, 0x180);
      expect((await storageFile.parent.stat()).mode & 0x1ff, 0x1c0);
    },
  );

  test('portal encrypted token store maps portal failures', () async {
    final store = PortalEncryptedSecretStore(
      portalClient: _ThrowingSecretPortalClient(
        const SecretPortalException(
          code: 'PortalUserCancelled',
          message: 'The Secret portal request was cancelled.',
        ),
      ),
      storageFile: File('${tempDir.path}/oauth-tokens.v1.json'),
    );

    await expectLater(
      store.setActiveAccountId('account-1'),
      throwsA(
        isA<SecretStoreException>()
            .having((error) => error.code, 'code', 'SecretStoreUnavailable')
            .having(
              (error) => error.message,
              'message',
              secretStorageUnavailableMessage,
            ),
      ),
    );
  });

  test('portal request tokens are valid D-Bus path elements', () {
    final validPathElement = RegExp(r'^[A-Za-z_][A-Za-z0-9_]*$');

    for (var i = 0; i < 128; i += 1) {
      final token = generatePortalRequestTokenForTesting();

      expect(token, matches(validPathElement));
    }
  });

  test('portal request tokens never contain hyphens', () {
    for (var i = 0; i < 128; i += 1) {
      final token = generatePortalRequestTokenForTesting();

      expect(token, isNot(contains('-')));
    }
  });
}

const _secretBytes = <int>[
  1,
  2,
  3,
  4,
  5,
  6,
  7,
  8,
  9,
  10,
  11,
  12,
  13,
  14,
  15,
  16,
  17,
  18,
  19,
  20,
  21,
  22,
  23,
  24,
  25,
  26,
  27,
  28,
  29,
  30,
  31,
  32,
];

OAuthTokenSet _tokenSet() {
  return OAuthTokenSet(
    accessToken: 'access-secret',
    refreshToken: 'refresh-secret',
    idToken: 'id-secret',
    expiresAtUtc: DateTime.utc(2026, 6, 4, 1),
    tokenType: 'Bearer',
    scopes: {'scope-a', 'scope-b'},
  );
}

class _FakeSecretPortalClient implements SecretPortalClient {
  const _FakeSecretPortalClient(this.secret);

  final PortalSecret secret;

  @override
  Future<PortalSecret> retrieveSecret({String? token}) async => secret;
}

class _ThrowingSecretPortalClient implements SecretPortalClient {
  const _ThrowingSecretPortalClient(this.error);

  final Object error;

  @override
  Future<PortalSecret> retrieveSecret({String? token}) async {
    throw error;
  }
}

class _ThrowingSecureStorage extends FlutterSecureStorage {
  const _ThrowingSecureStorage(this.error);

  final PlatformException error;

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    throw error;
  }

  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    throw error;
  }

  @override
  Future<void> delete({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    throw error;
  }
}

class _MemorySecureStorage extends FlutterSecureStorage {
  _MemorySecureStorage(Map<String, String> initial) : values = {...initial};

  final Map<String, String> values;

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async => values[key];

  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (value == null) {
      values.remove(key);
    } else {
      values[key] = value;
    }
  }

  @override
  Future<void> delete({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    values.remove(key);
  }
}

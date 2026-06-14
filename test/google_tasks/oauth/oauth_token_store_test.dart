import 'dart:io';

import 'package:busymax/src/google_tasks/oauth/oauth_models.dart';
import 'package:busymax/src/google_tasks/oauth/oauth_token_store.dart';
import 'package:busymax/src/google_tasks/oauth/portal_encrypted_oauth_token_store.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

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
    'secure storage platform failures become OAuth storage errors',
    () async {
      final store = SecureOAuthTokenStore(
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
          isA<OAuthException>()
              .having(
                (error) => error.code,
                'code',
                'OAuthSecureStorageUnavailable',
              )
              .having(
                (error) => error.message,
                'message',
                secureTokenStorageUnavailableMessage,
              ),
        ),
      );
    },
  );

  test(
    'portal encrypted token store does not write plaintext tokens',
    () async {
      final storageFile = File('${tempDir.path}/oauth-tokens.v1.json');
      final portal = _FakeSecretPortalClient(
        const PortalSecret(bytes: _secretBytes, token: 'portal-token'),
      );
      final store = PortalEncryptedOAuthTokenStore(
        portalClient: portal,
        storageFile: storageFile,
      );
      final tokenSet = _tokenSet();

      await store.saveTokenSet('account-1', tokenSet);
      await store.setActiveAccountId('account-1');

      final rawFile = await storageFile.readAsString();
      expect(rawFile, isNot(contains('access-secret')));
      expect(rawFile, isNot(contains('refresh-secret')));
      expect(rawFile, isNot(contains('id-secret')));
      expect(rawFile, contains('ciphertext'));
      expect(rawFile, contains('portal-token'));

      final restoredStore = PortalEncryptedOAuthTokenStore(
        portalClient: _FakeSecretPortalClient(
          const PortalSecret(bytes: _secretBytes, token: 'portal-token'),
        ),
        storageFile: storageFile,
      );

      expect(await restoredStore.readActiveAccountId(), 'account-1');
      final restored = await restoredStore.readTokenSet('account-1');
      expect(restored?.accessToken, 'access-secret');
      expect(restored?.refreshToken, 'refresh-secret');
      expect(restored?.idToken, 'id-secret');
      expect(restored?.scopes, {'scope-a', 'scope-b'});
    },
  );

  test('portal encrypted token store maps portal failures', () async {
    final store = PortalEncryptedOAuthTokenStore(
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
        isA<OAuthException>()
            .having(
              (error) => error.code,
              'code',
              'OAuthSecureStorageUnavailable',
            )
            .having(
              (error) => error.message,
              'message',
              secureTokenStorageUnavailableMessage,
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

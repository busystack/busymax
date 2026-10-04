import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:logging/logging.dart';

import '../../providers/busy_provider.dart';
import '../../providers/account_authority.dart';
import '../auth/oauth_models.dart';
import '../auth/oauth_registration.dart';
import '../logging/redacting_logger.dart';

const secretRecordSchemaVersion = 1;

enum CredentialKind {
  oauth,
  appleAppSpecificPassword,
  nextcloudAppPassword,
  webCalSubscription,
}

extension CredentialKindValue on CredentialKind {
  String get storageValue => switch (this) {
    CredentialKind.oauth => 'oauth',
    CredentialKind.appleAppSpecificPassword => 'apple_app_specific_password',
    CredentialKind.nextcloudAppPassword => 'nextcloud_app_password',
    CredentialKind.webCalSubscription => 'webcal_subscription',
  };
}

CredentialKind credentialKindForProvider(BusyProvider provider) =>
    switch (provider) {
      BusyProvider.google || BusyProvider.microsoft => CredentialKind.oauth,
      BusyProvider.appleICloud => CredentialKind.appleAppSpecificPassword,
      BusyProvider.nextcloud => CredentialKind.nextcloudAppPassword,
      BusyProvider.webCal => CredentialKind.webCalSubscription,
    };

bool credentialKindMatchesProvider(
  BusyProvider provider,
  CredentialKind kind,
) => credentialKindForProvider(provider) == kind;

CredentialKind _credentialKindFromSecretStorage(Object? value) =>
    switch (value) {
      'oauth' => CredentialKind.oauth,
      'apple_app_specific_password' => CredentialKind.appleAppSpecificPassword,
      'nextcloud_app_password' => CredentialKind.nextcloudAppPassword,
      'webcal_subscription' => CredentialKind.webCalSubscription,
      _ => throw SecretStoreCorruptException('Unsupported credential kind.'),
    };

sealed class SecretRecord {
  const SecretRecord({required this.provider, required this.kind});

  final BusyProvider provider;
  final CredentialKind kind;

  Map<String, Object?> toJson();

  static SecretRecord fromJson(Map<String, Object?> json) {
    if (json['schemaVersion'] == 2) {
      try {
        if (json['representation'] == 'google_android_v1' ||
            json['representation'] == 'microsoft_android_v1') {
          return _decodeNativeOAuth(json);
        }
        return _decodeBoundOAuth(json);
      } on SecretStoreCorruptException {
        rethrow;
      } on Object {
        throw const SecretStoreCorruptException(
          'Invalid bound credential representation.',
        );
      }
    }
    if (json['schemaVersion'] != secretRecordSchemaVersion) {
      throw SecretStoreCorruptException(
        'Unsupported credential schema version.',
      );
    }
    final provider = BusyProviderCodec.requireStorageValue(
      json['provider']?.toString(),
    );
    final kind = _credentialKindFromSecretStorage(json['kind']);
    if (!credentialKindMatchesProvider(provider, kind)) {
      throw const SecretStoreCorruptException(
        'The credential provider and kind do not match.',
      );
    }
    return switch (kind) {
      CredentialKind.oauth => OAuthSecretRecord(
        provider: provider,
        tokenSet: OAuthTokenSet(
          accessToken: _requiredSecretString(json, 'accessToken'),
          refreshToken: _optionalSecretString(json, 'refreshToken'),
          idToken: _optionalSecretString(json, 'idToken'),
          expiresAtUtc: DateTime.parse(
            _requiredSecretString(json, 'expiresAtUtc'),
          ).toUtc(),
          tokenType: _requiredSecretString(json, 'tokenType'),
          scopes: _stringList(json['scopes']).toSet(),
        ),
      ),
      CredentialKind.appleAppSpecificPassword => AppleICloudSecretRecord(
        username: _requiredSecretString(json, 'username'),
        appSpecificPassword: _requiredSecretString(json, 'appSpecificPassword'),
      ),
      CredentialKind.nextcloudAppPassword => NextcloudSecretRecord(
        canonicalServer: Uri.parse(
          _requiredSecretString(json, 'canonicalServer'),
        ),
        loginName: _requiredSecretString(json, 'loginName'),
        appPassword: _requiredSecretString(json, 'appPassword'),
      ),
      CredentialKind.webCalSubscription => WebCalSecretRecord(
        normalizedSubscriptionUri: _requiredSecretString(
          json,
          'normalizedSubscriptionUri',
        ),
        validatorTargetUri: switch (_optionalSecretString(
          json,
          'validatorTargetUri',
        )) {
          final value? => Uri.parse(value),
          null => null,
        },
      ),
    };
  }

  @override
  String toString() =>
      '$runtimeType(provider: ${provider.storageValue}, secret: [REDACTED])';
}

class OAuthSecretRecord extends SecretRecord {
  OAuthSecretRecord({required super.provider, required this.tokenSet})
    : super(kind: CredentialKind.oauth) {
    if (!credentialKindMatchesProvider(provider, kind)) {
      throw const SecretStoreCorruptException(
        'OAuth credentials require a Google or Microsoft provider.',
      );
    }
  }

  final OAuthTokenSet tokenSet;

  @override
  Map<String, Object?> toJson() => {
    'schemaVersion': secretRecordSchemaVersion,
    'kind': kind.storageValue,
    'provider': provider.storageValue,
    'accessToken': tokenSet.accessToken,
    if (tokenSet.refreshToken != null) 'refreshToken': tokenSet.refreshToken,
    if (tokenSet.idToken != null) 'idToken': tokenSet.idToken,
    'expiresAtUtc': tokenSet.expiresAtUtc.toUtc().toIso8601String(),
    'tokenType': tokenSet.tokenType,
    'scopes': tokenSet.scopes.toList()..sort(),
  };
}

/// Desktop credential versions retain the issuing client and verified identity.
sealed class BoundOAuthSecretRecord extends OAuthSecretRecord {
  BoundOAuthSecretRecord({
    required super.provider,
    required super.tokenSet,
    required this.subject,
    required this.generation,
    required this.transitionEligible,
  });
  final String subject;
  final int generation;
  final bool transitionEligible;
  OAuthRegistration get registration;
  BoundOAuthSecretRecord withTokens(OAuthTokenSet tokens);
  Map<String, Object?> get bindingJson;
  @override
  Map<String, Object?> toJson() => {
    ...super.toJson(),
    'schemaVersion': 2,
    'representation': provider == BusyProvider.google
        ? 'google_desktop_v1'
        : 'microsoft_desktop_v1',
    'subject': subject,
    'generation': generation,
    'transitionEligible': transitionEligible,
    ...bindingJson,
  };
}

final class GoogleDesktopCredential extends BoundOAuthSecretRecord {
  GoogleDesktopCredential({
    required this.registration,
    required super.tokenSet,
    required super.subject,
    required super.generation,
    required super.transitionEligible,
  }) : super(provider: BusyProvider.google);
  @override
  final GoogleDesktopRegistration registration;
  @override
  GoogleDesktopCredential withTokens(OAuthTokenSet tokens) =>
      GoogleDesktopCredential(
        registration: registration,
        tokenSet: tokens,
        subject: subject,
        generation: generation,
        transitionEligible: transitionEligible,
      );
  @override
  Map<String, Object?> get bindingJson => {
    'clientId': registration.clientId,
    if (registration.clientSecret != null)
      'clientSecret': registration.clientSecret,
    'projectId': registration.projectId,
    'origin': registration.origin.name,
  };
}

final class MicrosoftDesktopCredential extends BoundOAuthSecretRecord {
  MicrosoftDesktopCredential({
    required this.registration,
    required this.tenantId,
    required super.tokenSet,
    required super.subject,
    required super.generation,
    required super.transitionEligible,
  }) : super(provider: BusyProvider.microsoft);
  @override
  final MicrosoftPublicRegistration registration;
  final String tenantId;
  @override
  MicrosoftDesktopCredential withTokens(OAuthTokenSet tokens) =>
      MicrosoftDesktopCredential(
        registration: registration,
        tenantId: tenantId,
        tokenSet: tokens,
        subject: subject,
        generation: generation,
        transitionEligible: transitionEligible,
      );
  @override
  Map<String, Object?> get bindingJson => {
    'clientId': registration.clientId,
    'audience': registration.audience.name,
    if (registration.tenantId != null)
      'configuredTenantId': registration.tenantId,
    'tenantId': tenantId,
    'origin': registration.origin.name,
  };
}

SecretRecord _decodeBoundOAuth(Map<String, Object?> json) {
  _requireTypedBinding(json, native: false);
  final legacy =
      SecretRecord.fromJson({...json, 'schemaVersion': 1}) as OAuthSecretRecord;
  final subject = _requiredSecretString(json, 'subject');
  final generation = json['generation'];
  final eligible = json['transitionEligible'];
  if (generation is! int || generation < 0 || eligible is! bool) {
    throw const SecretStoreCorruptException('Invalid authorization binding.');
  }
  final origin = RegistrationOrigin.values
      .where((v) => v.name == json['origin'])
      .firstOrNull;
  if (origin == null || origin == RegistrationOrigin.nativeGoogleAndroid) {
    throw const SecretStoreCorruptException(
      'Invalid desktop registration origin.',
    );
  }
  final clientId = _requiredSecretString(json, 'clientId');
  if (json['representation'] == 'google_desktop_v1' &&
      legacy.provider == BusyProvider.google) {
    if (!RegExp(
      r'^[A-Za-z0-9_-]+\.apps\.googleusercontent\.com$',
    ).hasMatch(clientId)) {
      throw const SecretStoreCorruptException('Invalid Google client binding.');
    }
    return GoogleDesktopCredential(
      registration: GoogleDesktopRegistration(
        clientId: clientId,
        clientSecret: _optionalSecretString(json, 'clientSecret'),
        projectId: _requiredSecretString(json, 'projectId'),
        origin: origin,
      ),
      tokenSet: legacy.tokenSet,
      subject: subject,
      generation: generation,
      transitionEligible: eligible,
    );
  }
  if (json['representation'] == 'microsoft_desktop_v1' &&
      legacy.provider == BusyProvider.microsoft) {
    final audience = MicrosoftAudience.values
        .where((v) => v.name == json['audience'])
        .firstOrNull;
    final tenantId = _requiredSecretString(json, 'tenantId');
    if (audience == null || !isUuid(tenantId)) {
      throw const SecretStoreCorruptException(
        'Invalid Microsoft tenant binding.',
      );
    }
    return MicrosoftDesktopCredential(
      registration: MicrosoftPublicRegistration(
        clientId: clientId,
        audience: audience,
        tenantId: _optionalSecretString(json, 'configuredTenantId'),
        origin: origin,
      ),
      tenantId: tenantId,
      tokenSet: legacy.tokenSet,
      subject: subject,
      generation: generation,
      transitionEligible: eligible,
    );
  }
  throw const SecretStoreCorruptException(
    'Unsupported OAuth credential representation.',
  );
}

/// Native cache ownership stays in GIS/MSAL. These contain no native tokens.
sealed class NativeOAuthCredential extends SecretRecord {
  const NativeOAuthCredential({
    required super.provider,
    required this.nativeAccountId,
    required this.subject,
    required this.generation,
    required this.username,
  }) : super(kind: CredentialKind.oauth);
  final String nativeAccountId;
  final String subject;
  final int generation;
  final String? username;
  RegistrationSummary get summary;
  Map<String, Object?> get nativeBinding;
  @override
  Map<String, Object?> toJson() => {
    'schemaVersion': 2,
    'kind': 'oauth',
    'provider': provider.storageValue,
    'representation': provider == BusyProvider.google
        ? 'google_android_v1'
        : 'microsoft_android_v1',
    'nativeAccountId': nativeAccountId,
    'subject': subject,
    'generation': generation,
    if (username != null) 'username': username,
    ...nativeBinding,
  };
}

final class GoogleAndroidCredential extends NativeOAuthCredential {
  const GoogleAndroidCredential({
    required super.nativeAccountId,
    required super.subject,
    required super.generation,
    super.username,
  }) : super(provider: BusyProvider.google);
  @override
  RegistrationSummary get summary => const RegistrationSummary(
    provider: BusyProvider.google,
    platform: AuthenticationPlatform.android,
    origin: RegistrationOrigin.nativeGoogleAndroid,
    clientId: 'native-google-android',
  );
  @override
  Map<String, Object?> get nativeBinding => const {};
}

final class MicrosoftAndroidCredential extends NativeOAuthCredential {
  const MicrosoftAndroidCredential({
    required this.registration,
    required this.tenantId,
    required this.authority,
    required this.transitionEligible,
    required super.nativeAccountId,
    required super.subject,
    required super.generation,
    super.username,
  }) : super(provider: BusyProvider.microsoft);
  final MicrosoftPublicRegistration registration;
  final String tenantId;
  final String authority;
  final bool transitionEligible;
  @override
  RegistrationSummary get summary =>
      registration.summary(transitionEligible: transitionEligible);
  @override
  Map<String, Object?> get nativeBinding => {
    'clientId': registration.clientId,
    'audience': registration.audience.name,
    'configuredTenantId': registration.tenantId,
    'tenantId': tenantId,
    'authority': authority,
    'origin': registration.origin.name,
    'transitionEligible': transitionEligible,
  };
}

SecretRecord _decodeNativeOAuth(Map<String, Object?> json) {
  _requireTypedBinding(json, native: true);
  final nativeId = _requiredSecretString(json, 'nativeAccountId');
  final subject = _requiredSecretString(json, 'subject');
  final generation = json['generation'];
  if (json['kind'] != 'oauth' || generation is! int || generation < 0) {
    throw const SecretStoreCorruptException('Invalid native binding version.');
  }
  if (json['representation'] == 'google_android_v1' &&
      json['provider'] == 'google') {
    return GoogleAndroidCredential(
      nativeAccountId: nativeId,
      subject: subject,
      generation: generation,
      username: _optionalSecretString(json, 'username'),
    );
  }
  if (json['representation'] == 'microsoft_android_v1' &&
      json['provider'] == 'microsoft') {
    final tenant = _requiredSecretString(json, 'tenantId');
    final authority = Uri.tryParse(_requiredSecretString(json, 'authority'));
    if (!isUuid(tenant) ||
        json['transitionEligible'] is! bool ||
        json['origin'] == RegistrationOrigin.nativeGoogleAndroid.name ||
        authority?.scheme != 'https' ||
        authority?.host != 'login.microsoftonline.com' ||
        authority!.userInfo.isNotEmpty) {
      throw const SecretStoreCorruptException('Invalid native tenant binding.');
    }
    return MicrosoftAndroidCredential(
      registration: MicrosoftPublicRegistration(
        clientId: _requiredSecretString(json, 'clientId'),
        audience: MicrosoftAudience.values.byName(
          _requiredSecretString(json, 'audience'),
        ),
        tenantId: _optionalSecretString(json, 'configuredTenantId'),
        platform: AuthenticationPlatform.android,
        origin: RegistrationOrigin.values.byName(
          _requiredSecretString(json, 'origin'),
        ),
      ),
      tenantId: tenant,
      authority: _requiredSecretString(json, 'authority'),
      transitionEligible: json['transitionEligible'] as bool,
      nativeAccountId: nativeId,
      subject: subject,
      generation: generation,
      username: _optionalSecretString(json, 'username'),
    );
  }
  throw const SecretStoreCorruptException('Invalid native provider binding.');
}

void _requireTypedBinding(Map<String, Object?> json, {required bool native}) {
  final required = native
      ? ['nativeAccountId', 'subject']
      : [
          'accessToken',
          'tokenType',
          'expiresAtUtc',
          'clientId',
          'subject',
          'origin',
        ];
  for (final key in required) {
    if (json[key] is! String || (json[key] as String).isEmpty) {
      throw const SecretStoreCorruptException(
        'Invalid bound credential field.',
      );
    }
  }
  for (final key in [
    'refreshToken',
    'idToken',
    'clientSecret',
    'username',
    'configuredTenantId',
  ]) {
    if (json[key] != null && json[key] is! String) {
      throw const SecretStoreCorruptException(
        'Invalid optional bound credential field.',
      );
    }
  }
  if (!native &&
      (json['scopes'] is! List ||
          (json['scopes'] as List).any((v) => v is! String))) {
    throw const SecretStoreCorruptException('Invalid credential scopes.');
  }
}

final class AppleICloudSecretRecord extends SecretRecord {
  AppleICloudSecretRecord({
    required String username,
    required String appSpecificPassword,
  }) : username = username.trim(),
       appSpecificPassword = appSpecificPassword.trim(),
       super(
         provider: BusyProvider.appleICloud,
         kind: CredentialKind.appleAppSpecificPassword,
       ) {
    if (this.username.isEmpty || this.appSpecificPassword.isEmpty) {
      throw const SecretStoreCorruptException(
        'Apple iCloud credentials must not be empty.',
      );
    }
  }

  final String username;
  final String appSpecificPassword;

  @override
  Map<String, Object?> toJson() => {
    'schemaVersion': secretRecordSchemaVersion,
    'kind': kind.storageValue,
    'provider': provider.storageValue,
    'username': username,
    'appSpecificPassword': appSpecificPassword,
  };
}

final class NextcloudSecretRecord extends SecretRecord {
  NextcloudSecretRecord({
    required Uri canonicalServer,
    required String loginName,
    required String appPassword,
  }) : canonicalServer = Uri.parse(
         normalizeNextcloudServerAuthority(canonicalServer.toString()),
       ),
       loginName = loginName.trim(),
       appPassword = appPassword.trim(),
       super(
         provider: BusyProvider.nextcloud,
         kind: CredentialKind.nextcloudAppPassword,
       ) {
    if (canonicalServer.scheme != 'https' ||
        canonicalServer.host.isEmpty ||
        canonicalServer.userInfo.isNotEmpty ||
        this.loginName.isEmpty ||
        this.appPassword.isEmpty) {
      throw const SecretStoreCorruptException(
        'Nextcloud credentials contain an invalid server or empty value.',
      );
    }
  }

  final Uri canonicalServer;
  final String loginName;
  final String appPassword;

  @override
  Map<String, Object?> toJson() => {
    'schemaVersion': secretRecordSchemaVersion,
    'kind': kind.storageValue,
    'provider': provider.storageValue,
    'canonicalServer': canonicalServer.toString(),
    'loginName': loginName,
    'appPassword': appPassword,
  };
}

final class WebCalSecretRecord extends SecretRecord {
  WebCalSecretRecord({
    required this.normalizedSubscriptionUri,
    this.validatorTargetUri,
  }) : super(
         provider: BusyProvider.webCal,
         kind: CredentialKind.webCalSubscription,
       ) {
    _requireSafeSubscriptionUri(Uri.parse(normalizedSubscriptionUri));
    final target = validatorTargetUri;
    if (target != null) _requireSafeSubscriptionUri(target);
  }

  final String normalizedSubscriptionUri;
  final Uri? validatorTargetUri;

  @override
  Map<String, Object?> toJson() => {
    'schemaVersion': secretRecordSchemaVersion,
    'kind': kind.storageValue,
    'provider': provider.storageValue,
    'normalizedSubscriptionUri': normalizedSubscriptionUri,
    if (validatorTargetUri != null)
      'validatorTargetUri': validatorTargetUri.toString(),
  };

  WebCalSecretRecord copyWithValidatorTarget(Uri? value) => WebCalSecretRecord(
    normalizedSubscriptionUri: normalizedSubscriptionUri,
    validatorTargetUri: value,
  );
}

void _requireSafeSubscriptionUri(Uri value) {
  if (value.scheme != 'https' ||
      value.host.isEmpty ||
      value.userInfo.isNotEmpty ||
      value.hasFragment) {
    throw const SecretStoreCorruptException(
      'A WebCal credential contains an invalid subscription URI.',
    );
  }
}

abstract interface class SecretStore {
  Future<String?> readActiveAccountId();
  Future<void> setActiveAccountId(String accountId);
  Future<void> clearActiveAccount();
  Future<SecretRecord?> readCredential(String accountId);
  Future<void> saveCredential(String accountId, SecretRecord credential);
  Future<void> deleteCredential(String accountId);

  /// Performs the one-time legacy OAuth key migration for an existing account.
  /// Returns true only when legacy values were replaced and then deleted.
  Future<bool> migrateLegacyOAuthCredential(
    String accountId,
    BusyProvider provider,
  );
}

extension OAuthSecretStoreAccess on SecretStore {
  Future<OAuthTokenSet?> readOAuthTokenSet(
    String accountId,
    BusyProvider expectedProvider,
  ) async {
    final credential = await readCredential(accountId);
    if (credential == null) {
      return null;
    }
    if (credential case OAuthSecretRecord(
      provider: final provider,
      tokenSet: final tokenSet,
    ) when provider == expectedProvider) {
      return tokenSet;
    }
    throw SecretStoreCredentialMismatchException(
      accountId: accountId,
      expectedProvider: expectedProvider,
      actualProvider: credential.provider,
      actualKind: credential.kind,
    );
  }

  Future<void> saveOAuthTokenSet(
    String accountId,
    BusyProvider provider,
    OAuthTokenSet tokenSet,
  ) async {
    final current = await readCredential(accountId);
    if (current is NativeOAuthCredential) {
      throw const SecretStoreCorruptException(
        'Native cache credentials cannot be replaced by desktop tokens.',
      );
    }
    if (current is BoundOAuthSecretRecord) {
      if (current.provider != provider) {
        throw const SecretStoreCorruptException(
          'Credential provider mismatch.',
        );
      }
      await saveCredential(accountId, current.withTokens(tokenSet));
      return;
    }
    await saveCredential(
      accountId,
      OAuthSecretRecord(provider: provider, tokenSet: tokenSet),
    );
  }
}

class SecretStoragePresentation {
  const SecretStoragePresentation({
    required this.backendDomain,
    required this.runtimeBackend,
    required this.unavailableMessage,
  });

  static const generic = SecretStoragePresentation(
    backendDomain: 'busymax.secure_storage',
    runtimeBackend: 'platform-credential-storage',
    unavailableMessage:
        'Secure credential storage is temporarily unavailable. Check your '
        'operating system credential storage and try again.',
  );

  final String backendDomain;
  final String runtimeBackend;
  final String unavailableMessage;
}

class SecureSecretStore implements SecretStore {
  SecureSecretStore(
    this._storage, {
    RedactingLogger? logger,
    this.presentation = SecretStoragePresentation.generic,
  }) : _logger = logger ?? RedactingLogger(Logger('SecureSecretStore'));

  final FlutterSecureStorage _storage;
  final RedactingLogger _logger;
  final SecretStoragePresentation presentation;
  var _loggedRuntime = false;

  static const activeAccountKey = 'busymax.secret.active_account_id';
  static const legacyActiveAccountKey = 'busymax.oauth.active_account_id';

  @override
  Future<String?> readActiveAccountId() async {
    final current = await _read(activeAccountKey);
    if (current != null) {
      return current;
    }
    final legacy = await _read(legacyActiveAccountKey);
    if (legacy == null) {
      return null;
    }
    await _write(activeAccountKey, legacy);
    if (await _read(activeAccountKey) != legacy) {
      throw const SecretStoreException(
        'SecretStoreMigrationVerificationFailed',
        'The active account secret migration could not be verified.',
      );
    }
    await _delete(legacyActiveAccountKey);
    return legacy;
  }

  @override
  Future<SecretRecord?> readCredential(String accountId) async {
    final serialized = await _read(_credentialKey(accountId));
    if (serialized == null) {
      return null;
    }
    return _decodeCredential(serialized);
  }

  @override
  Future<void> saveCredential(String accountId, SecretRecord credential) async {
    await _write(_credentialKey(accountId), jsonEncode(credential.toJson()));
  }

  @override
  Future<void> setActiveAccountId(String accountId) {
    return _write(activeAccountKey, accountId);
  }

  @override
  Future<void> deleteCredential(String accountId) {
    return _delete(_credentialKey(accountId));
  }

  @override
  Future<void> clearActiveAccount() => _delete(activeAccountKey);

  @override
  Future<bool> migrateLegacyOAuthCredential(
    String accountId,
    BusyProvider provider,
  ) async {
    if (provider != BusyProvider.google && provider != BusyProvider.microsoft) {
      return false;
    }
    if (await readCredential(accountId) != null) {
      return false;
    }
    final accessToken = await _read(_legacyKey(accountId, 'access_token'));
    final expiresAtText = await _read(_legacyKey(accountId, 'expires_at_utc'));
    if (accessToken == null || expiresAtText == null) {
      return false;
    }
    final tokenSet = OAuthTokenSet(
      accessToken: accessToken,
      refreshToken: await _read(_legacyKey(accountId, 'refresh_token')),
      idToken: await _read(_legacyKey(accountId, 'id_token')),
      expiresAtUtc: DateTime.parse(expiresAtText).toUtc(),
      tokenType: await _read(_legacyKey(accountId, 'token_type')) ?? 'Bearer',
      scopes: (await _read(_legacyKey(accountId, 'scope')) ?? '')
          .split(RegExp(r'\s+'))
          .where((scope) => scope.isNotEmpty)
          .toSet(),
    );
    await saveOAuthTokenSet(accountId, provider, tokenSet);
    final verified = await readOAuthTokenSet(accountId, provider);
    if (verified == null || verified.accessToken != tokenSet.accessToken) {
      throw const SecretStoreException(
        'SecretStoreMigrationVerificationFailed',
        'The OAuth credential migration could not be verified.',
      );
    }
    await _deleteLegacyOAuthKeys(accountId);
    return true;
  }

  String _credentialKey(String accountId) => 'busymax.secret.$accountId.v1';

  String _legacyKey(String accountId, String name) =>
      'busymax.oauth.$accountId.$name';

  Future<void> _deleteLegacyOAuthKeys(String accountId) async {
    for (final name in _legacyOAuthFieldNames) {
      await _delete(_legacyKey(accountId, name));
    }
  }

  Future<String?> _read(String key) async {
    _logRuntime();
    try {
      return await _storage.read(key: key);
    } on PlatformException catch (error) {
      throw _secureStorageException('read', error);
    }
  }

  Future<void> _write(String key, String? value) async {
    _logRuntime();
    try {
      await _storage.write(key: key, value: value);
    } on PlatformException catch (error) {
      throw _secureStorageException('write', error);
    }
  }

  Future<void> _delete(String key) async {
    _logRuntime();
    try {
      await _storage.delete(key: key);
    } on PlatformException catch (error) {
      throw _secureStorageException('delete', error);
    }
  }

  void _logRuntime() {
    if (_loggedRuntime) {
      return;
    }
    _loggedRuntime = true;
    _logger.info(
      'Secret storage runtime: backend=${presentation.runtimeBackend}',
    );
  }

  SecretStoreException _secureStorageException(
    String operation,
    PlatformException error,
  ) {
    _logger.warning(
      'Secret storage $operation failed: '
      '${sanitizedFlutterSecureStorageError(error, backendDomain: presentation.backendDomain)}',
    );
    return SecretStoreException(
      'SecretStoreUnavailable',
      presentation.unavailableMessage,
    );
  }
}

class InMemorySecretStore implements SecretStore {
  final _credentials = <String, SecretRecord>{};
  String? _activeAccountId;

  @override
  Future<void> clearActiveAccount() async => _activeAccountId = null;

  @override
  Future<void> deleteCredential(String accountId) async {
    _credentials.remove(accountId);
  }

  @override
  Future<bool> migrateLegacyOAuthCredential(
    String accountId,
    BusyProvider provider,
  ) async => false;

  @override
  Future<String?> readActiveAccountId() async => _activeAccountId;

  @override
  Future<SecretRecord?> readCredential(String accountId) async =>
      _credentials[accountId];

  @override
  Future<void> saveCredential(String accountId, SecretRecord credential) async {
    _credentials[accountId] = credential;
  }

  @override
  Future<void> setActiveAccountId(String accountId) async {
    _activeAccountId = accountId;
  }
}

class SecretStoreException implements Exception {
  const SecretStoreException(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => '$code: $message';
}

class SecretStoreCorruptException extends SecretStoreException {
  const SecretStoreCorruptException(String message)
    : super('SecretStoreCorrupt', message);
}

class SecretStoreCredentialMismatchException extends SecretStoreException {
  SecretStoreCredentialMismatchException({
    required this.accountId,
    required this.expectedProvider,
    required this.actualProvider,
    required this.actualKind,
  }) : super(
         'SecretStoreCredentialMismatch',
         'The stored credential does not match the requested account provider.',
       );

  final String accountId;
  final BusyProvider expectedProvider;
  final BusyProvider actualProvider;
  final CredentialKind actualKind;
}

const secretStorageUnavailableMessage =
    'Secure credential storage is temporarily unavailable. Check your operating system credential storage and try again.';

String sanitizedFlutterSecureStorageError(
  PlatformException error, {
  String backendDomain = 'busymax.secure_storage',
}) {
  String safeIdentifier(String value, String fallback) {
    final normalized = value.trim();
    return normalized.length <= 96 &&
            RegExp(r'^[A-Za-z0-9_.-]+$').hasMatch(normalized)
        ? normalized
        : fallback;
  }

  // Platform messages and details are intentionally omitted. Backends may
  // include key names, paths, or credential-provider output in those fields.
  final domain = safeIdentifier(backendDomain, 'busymax.secure_storage');
  final code = safeIdentifier(error.code, 'backend-error');
  return 'domain=$domain code=$code '
      'details_type=${error.details.runtimeType}';
}

SecretRecord _decodeCredential(String serialized) {
  try {
    final decoded = jsonDecode(serialized);
    if (decoded is! Map) {
      throw const SecretStoreCorruptException(
        'The credential record is not a JSON object.',
      );
    }
    return SecretRecord.fromJson(decoded.cast<String, Object?>());
  } on SecretStoreException {
    rethrow;
  } on Object catch (error) {
    throw SecretStoreCorruptException(
      'The credential record could not be decoded (${error.runtimeType}).',
    );
  }
}

String _requiredSecretString(Map<String, Object?> json, String key) {
  final value = json[key]?.toString();
  if (value == null || value.isEmpty) {
    throw SecretStoreCorruptException('Credential record is missing $key.');
  }
  return value;
}

String? _optionalSecretString(Map<String, Object?> json, String key) {
  final value = json[key]?.toString();
  return value == null || value.isEmpty ? null : value;
}

List<String> _stringList(Object? value) {
  if (value is! List) {
    return const [];
  }
  return value.map((entry) => entry.toString()).toList(growable: false);
}

const _legacyOAuthFieldNames = <String>[
  'access_token',
  'refresh_token',
  'id_token',
  'expires_at_utc',
  'token_type',
  'scope',
];

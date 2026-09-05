import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../db/app_database.dart';
import '../domain/account_connection_state.dart';
import 'package:busymax/src/providers/busy_provider.dart';
import 'package:busymax/src/core/secrets/secret_store.dart';
import 'package:busymax/src/providers/account_authority.dart';

const accountAuthStateSignedIn = 'signed_in';
const accountAuthStateReauthRequired = 'reauth_required';
const accountAuthStateTemporarilyUnavailable = 'temporarily_unavailable';
const accountAuthStatePermissionChanged = 'permission_changed';
const accountAuthStateUnsupportedServer = 'unsupported_server_profile';

const accountCachedAvailableStates = <String>[
  accountAuthStateSignedIn,
  accountAuthStateReauthRequired,
  accountAuthStateTemporarilyUnavailable,
  accountAuthStatePermissionChanged,
  accountAuthStateUnsupportedServer,
];

class AccountEntity {
  const AccountEntity({
    required this.id,
    required this.provider,
    required this.authority,
    required this.providerAccountId,
    this.credentialKind = CredentialKind.oauth,
    this.providerProfileVersion = 1,
    required this.authState,
    this.displayName,
    this.email,
    this.tenantId,
    this.providerMetadataJson,
    this.calendarsEnabled = true,
    this.tasksEnabled = true,
    this.lastSuccessfulSyncAtUtc,
    this.lastFullSyncAtUtc,
  });

  factory AccountEntity.fromRow(Account row) {
    final provider = BusyProviderCodec.requireStorageValue(row.provider);
    final credentialKind = _credentialKindFromStorage(row.credentialKind);
    if (!credentialKindMatchesProvider(provider, credentialKind)) {
      throw const SecretStoreCorruptException(
        'Stored account provider and credential kind do not match.',
      );
    }
    return AccountEntity(
      id: row.id,
      provider: provider,
      authority: row.authority,
      providerAccountId: row.providerAccountId,
      credentialKind: credentialKind,
      providerProfileVersion: row.providerProfileVersion,
      displayName: row.displayName,
      email: row.email,
      tenantId: row.tenantId,
      providerMetadataJson: row.providerMetadataJson,
      calendarsEnabled: row.calendarsEnabled,
      tasksEnabled: row.tasksEnabled,
      lastSuccessfulSyncAtUtc: DateTime.tryParse(
        row.lastSuccessfulSyncAtUtc ?? '',
      )?.toUtc(),
      lastFullSyncAtUtc: DateTime.tryParse(
        row.lastFullSyncAtUtc ?? '',
      )?.toUtc(),
      authState: row.authState,
    );
  }

  final String id;
  final BusyProvider provider;
  final String authority;
  final String providerAccountId;
  final CredentialKind credentialKind;
  final int providerProfileVersion;
  final String? displayName;
  final String? email;
  final String? tenantId;
  final String? providerMetadataJson;
  final bool calendarsEnabled;
  final bool tasksEnabled;
  final DateTime? lastSuccessfulSyncAtUtc;
  final DateTime? lastFullSyncAtUtc;
  final String authState;

  AccountConnectionState get connectionState =>
      AccountConnectionStateCodec.parse(authState);

  bool get isSignedIn => authState == accountAuthStateSignedIn;
  bool get isSubscription => provider == BusyProvider.webCal;
  bool get isAuthenticationAccount => !isSubscription;
  bool get isTaskCapable =>
      !isSubscription && tasksEnabled && provider != BusyProvider.appleICloud;
  bool get isScheduleVisible => calendarsEnabled;
  bool get isSyncEligible =>
      authState == accountAuthStateSignedIn ||
      authState == accountAuthStateTemporarilyUnavailable;
  bool get needsReconnect => authState == accountAuthStateReauthRequired;
  bool get hasConnectionIssue => authState != accountAuthStateSignedIn;

  String get displayLabel {
    final name = displayName?.trim();
    if (name != null && name.isNotEmpty) {
      return name;
    }
    final address = email?.trim();
    if (address != null && address.isNotEmpty) {
      return address;
    }
    return provider.displayName;
  }

  String? get secondaryLabel {
    final address = email?.trim();
    if (address == null || address.isEmpty || address == displayLabel) {
      return null;
    }
    return address;
  }

  String get selectorLabel {
    final providerLabel = provider.displayName;
    final identity = _selectorIdentity;
    if (identity == null ||
        identity.toLowerCase() == providerLabel.toLowerCase()) {
      return providerLabel;
    }
    return '$providerLabel · $identity';
  }

  String? get _selectorIdentity {
    final address = _trimmedAccountValue(email);
    if (address != null) return address;
    final name = _trimmedAccountValue(displayName);
    if (provider != BusyProvider.nextcloud) return name;
    final uri = Uri.tryParse(authority);
    final host = uri == null || uri.host.isEmpty
        ? null
        : uri.hasPort
        ? '${uri.host}:${uri.port}'
        : uri.host;
    if (name == null) return host;
    return host == null ? name : '$name · $host';
  }
}

String? _trimmedAccountValue(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}

class AccountsRepository {
  AccountsRepository({
    required AppDatabase database,
    DateTime Function()? nowUtc,
  }) : _database = database,
       _nowUtc = nowUtc ?? (() => DateTime.now().toUtc());

  final AppDatabase _database;
  final DateTime Function() _nowUtc;

  Stream<List<AccountEntity>> watchAccounts() {
    final query = _database.select(_database.accounts)
      ..where((row) => row.authState.isIn(accountCachedAvailableStates))
      ..orderBy([
        (row) => OrderingTerm.asc(row.provider),
        (row) => OrderingTerm.asc(row.displayName),
        (row) => OrderingTerm.asc(row.email),
      ]);
    return query.watch().map(
      (rows) => rows.map(AccountEntity.fromRow).toList(),
    );
  }

  Stream<List<AccountEntity>> watchVisibleAccounts() {
    final query = _database.select(_database.accounts)
      ..where(
        (row) =>
            row.authState.isIn([...accountCachedAvailableStates]) &
            row.provider.equals(BusyProvider.webCal.storageValue).not(),
      )
      ..orderBy([
        (row) => OrderingTerm.asc(row.provider),
        (row) => OrderingTerm.asc(row.displayName),
        (row) => OrderingTerm.asc(row.email),
      ]);
    return query.watch().map(
      (rows) => rows.map(AccountEntity.fromRow).toList(),
    );
  }

  Future<List<AccountEntity>> listSignedInAccounts() async {
    final query = _database.select(_database.accounts)
      ..where(
        (row) =>
            row.authState.equals(accountAuthStateSignedIn) &
            row.provider.equals(BusyProvider.webCal.storageValue).not(),
      )
      ..orderBy([
        (row) => OrderingTerm.asc(row.provider),
        (row) => OrderingTerm.asc(row.displayName),
        (row) => OrderingTerm.asc(row.email),
      ]);
    final rows = await query.get();
    return rows.map(AccountEntity.fromRow).toList();
  }

  Future<List<AccountEntity>> listSyncEligibleAccounts() async {
    final query = _database.select(_database.accounts)
      ..where(
        (row) => row.authState.isIn(const [
          accountAuthStateSignedIn,
          accountAuthStateTemporarilyUnavailable,
        ]),
      )
      ..orderBy([
        (row) => OrderingTerm.asc(row.provider),
        (row) => OrderingTerm.asc(row.displayName),
        (row) => OrderingTerm.asc(row.email),
      ]);
    return (await query.get()).map(AccountEntity.fromRow).toList();
  }

  Future<List<AccountEntity>> listVisibleAccounts() async {
    final query = _database.select(_database.accounts)
      ..where(
        (row) =>
            row.authState.isIn(accountCachedAvailableStates) &
            row.provider.equals(BusyProvider.webCal.storageValue).not(),
      )
      ..orderBy([
        (row) => OrderingTerm.asc(row.provider),
        (row) => OrderingTerm.asc(row.displayName),
        (row) => OrderingTerm.asc(row.email),
      ]);
    return (await query.get()).map(AccountEntity.fromRow).toList();
  }

  Future<AccountEntity?> accountById(String accountId) async {
    final row = await (_database.select(
      _database.accounts,
    )..where((account) => account.id.equals(accountId))).getSingleOrNull();
    return row == null ? null : AccountEntity.fromRow(row);
  }

  Future<void> upsertSignedInAccount({
    required String id,
    required BusyProvider provider,
    required String grantedScopes,
    String? providerAccountId,
    String? authority,
    CredentialKind? credentialKind,
    int providerProfileVersion = 1,
    String? displayName,
    String? email,
    String? tenantId,
    bool calendarsEnabled = true,
    bool tasksEnabled = true,
    Map<String, Object?>? providerMetadata,
  }) async {
    final now = _now();
    final normalizedAuthority = normalizeAccountAuthority(
      provider,
      authority: authority,
      tenantId: tenantId,
    );
    final normalizedProviderAccountId = normalizeProviderAccountId(
      provider,
      providerAccountId ?? id,
    );
    final resolvedCredentialKind =
        credentialKind ?? credentialKindForProvider(provider);
    if (!credentialKindMatchesProvider(provider, resolvedCredentialKind)) {
      throw ArgumentError.value(
        resolvedCredentialKind,
        'credentialKind',
        'The credential kind does not match the account provider.',
      );
    }
    final existing = await (_database.select(
      _database.accounts,
    )..where((account) => account.id.equals(id))).getSingleOrNull();
    final companion = AccountsCompanion(
      provider: Value(provider.storageValue),
      authority: Value(normalizedAuthority),
      providerAccountId: Value(normalizedProviderAccountId),
      credentialKind: Value(resolvedCredentialKind.storageValue),
      providerProfileVersion: Value(providerProfileVersion),
      displayName: Value(displayName),
      email: Value(email),
      tenantId: Value(tenantId),
      calendarsEnabled: Value(calendarsEnabled),
      tasksEnabled: Value(tasksEnabled),
      providerMetadataJson: Value(
        providerMetadata == null ? null : jsonEncode(providerMetadata),
      ),
      authState: const Value(accountAuthStateSignedIn),
      grantedScopes: Value(grantedScopes),
      updatedAtUtc: Value(now),
    );

    if (existing == null) {
      await _database
          .into(_database.accounts)
          .insert(
            AccountsCompanion.insert(
              id: id,
              createdAtUtc: now,
              updatedAtUtc: now,
              provider: provider.storageValue,
              authority: normalizedAuthority,
              providerAccountId: normalizedProviderAccountId,
              credentialKind: resolvedCredentialKind.storageValue,
              providerProfileVersion: Value(providerProfileVersion),
              displayName: Value(displayName),
              email: Value(email),
              tenantId: Value(tenantId),
              calendarsEnabled: Value(calendarsEnabled),
              tasksEnabled: Value(tasksEnabled),
              providerMetadataJson: Value(
                providerMetadata == null ? null : jsonEncode(providerMetadata),
              ),
              authState: const Value(accountAuthStateSignedIn),
              grantedScopes: Value(grantedScopes),
            ),
          );
      return;
    }

    await (_database.update(
      _database.accounts,
    )..where((account) => account.id.equals(id))).write(companion);
  }

  Future<void> markReconnectRequired(String accountId) {
    return setConnectionState(
      accountId,
      AccountConnectionState.reauthenticationRequired,
    );
  }

  Future<void> setConnectionState(
    String accountId,
    AccountConnectionState state,
  ) {
    return (_database.update(
      _database.accounts,
    )..where((account) => account.id.equals(accountId))).write(
      AccountsCompanion(
        authState: Value(state.storageValue),
        updatedAtUtc: Value(_now()),
      ),
    );
  }

  Future<void> deleteAccount(String accountId) {
    return (_database.delete(
      _database.accounts,
    )..where((account) => account.id.equals(accountId))).go();
  }

  String _now() => _nowUtc().toIso8601String();
}

CredentialKind _credentialKindFromStorage(String value) => switch (value) {
  'oauth' => CredentialKind.oauth,
  'apple_app_specific_password' => CredentialKind.appleAppSpecificPassword,
  'nextcloud_app_password' => CredentialKind.nextcloudAppPassword,
  'webcal_subscription' => CredentialKind.webCalSubscription,
  _ => throw SecretStoreCorruptException(
    'Unsupported stored credential kind for account metadata.',
  ),
};

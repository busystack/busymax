import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../db/app_database.dart';
import '../../../task_providers/task_provider.dart';

class AccountEntity {
  const AccountEntity({
    required this.id,
    required this.provider,
    required this.authState,
    this.providerAccountId,
    this.displayName,
    this.email,
    this.tenantId,
    this.providerMetadataJson,
    this.calendarsEnabled = true,
    this.tasksEnabled = true,
  });

  factory AccountEntity.fromRow(Account row) {
    return AccountEntity(
      id: row.id,
      provider: TaskProviderParsing.fromStorageValue(row.provider),
      providerAccountId: row.providerAccountId,
      displayName: row.displayName,
      email: row.email,
      tenantId: row.tenantId,
      providerMetadataJson: row.providerMetadataJson,
      calendarsEnabled: row.calendarsEnabled,
      tasksEnabled: row.tasksEnabled,
      authState: row.authState,
    );
  }

  final String id;
  final TaskProvider provider;
  final String? providerAccountId;
  final String? displayName;
  final String? email;
  final String? tenantId;
  final String? providerMetadataJson;
  final bool calendarsEnabled;
  final bool tasksEnabled;
  final String authState;

  bool get isSignedIn => authState == 'signed_in';

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
      ..where((row) => row.authState.equals('signed_in'))
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
      ..where((row) => row.authState.equals('signed_in'))
      ..orderBy([
        (row) => OrderingTerm.asc(row.provider),
        (row) => OrderingTerm.asc(row.displayName),
        (row) => OrderingTerm.asc(row.email),
      ]);
    final rows = await query.get();
    return rows.map(AccountEntity.fromRow).toList();
  }

  Future<AccountEntity?> accountById(String accountId) async {
    final row = await (_database.select(
      _database.accounts,
    )..where((account) => account.id.equals(accountId))).getSingleOrNull();
    return row == null ? null : AccountEntity.fromRow(row);
  }

  Future<void> upsertSignedInAccount({
    required String id,
    required TaskProvider provider,
    required String grantedScopes,
    String? providerAccountId,
    String? displayName,
    String? email,
    String? tenantId,
    bool calendarsEnabled = true,
    bool tasksEnabled = true,
    Map<String, Object?>? providerMetadata,
  }) async {
    final now = _now();
    final existing = await (_database.select(
      _database.accounts,
    )..where((account) => account.id.equals(id))).getSingleOrNull();
    final companion = AccountsCompanion(
      provider: Value(provider.storageValue),
      providerAccountId: Value(providerAccountId),
      displayName: Value(displayName),
      email: Value(email),
      tenantId: Value(tenantId),
      calendarsEnabled: Value(calendarsEnabled),
      tasksEnabled: Value(tasksEnabled),
      providerMetadataJson: Value(
        providerMetadata == null ? null : jsonEncode(providerMetadata),
      ),
      authState: const Value('signed_in'),
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
              provider: Value(provider.storageValue),
              providerAccountId: Value(providerAccountId),
              displayName: Value(displayName),
              email: Value(email),
              tenantId: Value(tenantId),
              calendarsEnabled: Value(calendarsEnabled),
              tasksEnabled: Value(tasksEnabled),
              providerMetadataJson: Value(
                providerMetadata == null ? null : jsonEncode(providerMetadata),
              ),
              authState: const Value('signed_in'),
              grantedScopes: Value(grantedScopes),
            ),
          );
      return;
    }

    await (_database.update(
      _database.accounts,
    )..where((account) => account.id.equals(id))).write(companion);
  }

  Future<void> markSignedOut(String accountId) {
    return (_database.update(
      _database.accounts,
    )..where((account) => account.id.equals(accountId))).write(
      AccountsCompanion(
        authState: const Value('signed_out'),
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

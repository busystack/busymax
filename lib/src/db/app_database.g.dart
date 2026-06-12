// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $AccountsTable extends Accounts with TableInfo<$AccountsTable, Account> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AccountsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _providerMeta = const VerificationMeta(
    'provider',
  );
  @override
  late final GeneratedColumn<String> provider = GeneratedColumn<String>(
    'provider',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('google'),
  );
  static const VerificationMeta _providerAccountIdMeta = const VerificationMeta(
    'providerAccountId',
  );
  @override
  late final GeneratedColumn<String> providerAccountId =
      GeneratedColumn<String>(
        'provider_account_id',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _displayNameMeta = const VerificationMeta(
    'displayName',
  );
  @override
  late final GeneratedColumn<String> displayName = GeneratedColumn<String>(
    'display_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _emailMeta = const VerificationMeta('email');
  @override
  late final GeneratedColumn<String> email = GeneratedColumn<String>(
    'email',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _tenantIdMeta = const VerificationMeta(
    'tenantId',
  );
  @override
  late final GeneratedColumn<String> tenantId = GeneratedColumn<String>(
    'tenant_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _accountAvatarUrlMeta = const VerificationMeta(
    'accountAvatarUrl',
  );
  @override
  late final GeneratedColumn<String> accountAvatarUrl = GeneratedColumn<String>(
    'account_avatar_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _providerMetadataJsonMeta =
      const VerificationMeta('providerMetadataJson');
  @override
  late final GeneratedColumn<String> providerMetadataJson =
      GeneratedColumn<String>(
        'provider_metadata_json',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _authStateMeta = const VerificationMeta(
    'authState',
  );
  @override
  late final GeneratedColumn<String> authState = GeneratedColumn<String>(
    'auth_state',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('signed_out'),
  );
  static const VerificationMeta _calendarsEnabledMeta = const VerificationMeta(
    'calendarsEnabled',
  );
  @override
  late final GeneratedColumn<bool> calendarsEnabled = GeneratedColumn<bool>(
    'calendars_enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("calendars_enabled" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _tasksEnabledMeta = const VerificationMeta(
    'tasksEnabled',
  );
  @override
  late final GeneratedColumn<bool> tasksEnabled = GeneratedColumn<bool>(
    'tasks_enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("tasks_enabled" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _grantedScopesMeta = const VerificationMeta(
    'grantedScopes',
  );
  @override
  late final GeneratedColumn<String> grantedScopes = GeneratedColumn<String>(
    'granted_scopes',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _createdAtUtcMeta = const VerificationMeta(
    'createdAtUtc',
  );
  @override
  late final GeneratedColumn<String> createdAtUtc = GeneratedColumn<String>(
    'created_at_utc',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtUtcMeta = const VerificationMeta(
    'updatedAtUtc',
  );
  @override
  late final GeneratedColumn<String> updatedAtUtc = GeneratedColumn<String>(
    'updated_at_utc',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastSuccessfulSyncAtUtcMeta =
      const VerificationMeta('lastSuccessfulSyncAtUtc');
  @override
  late final GeneratedColumn<String> lastSuccessfulSyncAtUtc =
      GeneratedColumn<String>(
        'last_successful_sync_at_utc',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _lastFullSyncAtUtcMeta = const VerificationMeta(
    'lastFullSyncAtUtc',
  );
  @override
  late final GeneratedColumn<String> lastFullSyncAtUtc =
      GeneratedColumn<String>(
        'last_full_sync_at_utc',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    provider,
    providerAccountId,
    displayName,
    email,
    tenantId,
    accountAvatarUrl,
    providerMetadataJson,
    authState,
    calendarsEnabled,
    tasksEnabled,
    grantedScopes,
    createdAtUtc,
    updatedAtUtc,
    lastSuccessfulSyncAtUtc,
    lastFullSyncAtUtc,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'accounts';
  @override
  VerificationContext validateIntegrity(
    Insertable<Account> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('provider')) {
      context.handle(
        _providerMeta,
        provider.isAcceptableOrUnknown(data['provider']!, _providerMeta),
      );
    }
    if (data.containsKey('provider_account_id')) {
      context.handle(
        _providerAccountIdMeta,
        providerAccountId.isAcceptableOrUnknown(
          data['provider_account_id']!,
          _providerAccountIdMeta,
        ),
      );
    }
    if (data.containsKey('display_name')) {
      context.handle(
        _displayNameMeta,
        displayName.isAcceptableOrUnknown(
          data['display_name']!,
          _displayNameMeta,
        ),
      );
    }
    if (data.containsKey('email')) {
      context.handle(
        _emailMeta,
        email.isAcceptableOrUnknown(data['email']!, _emailMeta),
      );
    }
    if (data.containsKey('tenant_id')) {
      context.handle(
        _tenantIdMeta,
        tenantId.isAcceptableOrUnknown(data['tenant_id']!, _tenantIdMeta),
      );
    }
    if (data.containsKey('account_avatar_url')) {
      context.handle(
        _accountAvatarUrlMeta,
        accountAvatarUrl.isAcceptableOrUnknown(
          data['account_avatar_url']!,
          _accountAvatarUrlMeta,
        ),
      );
    }
    if (data.containsKey('provider_metadata_json')) {
      context.handle(
        _providerMetadataJsonMeta,
        providerMetadataJson.isAcceptableOrUnknown(
          data['provider_metadata_json']!,
          _providerMetadataJsonMeta,
        ),
      );
    }
    if (data.containsKey('auth_state')) {
      context.handle(
        _authStateMeta,
        authState.isAcceptableOrUnknown(data['auth_state']!, _authStateMeta),
      );
    }
    if (data.containsKey('calendars_enabled')) {
      context.handle(
        _calendarsEnabledMeta,
        calendarsEnabled.isAcceptableOrUnknown(
          data['calendars_enabled']!,
          _calendarsEnabledMeta,
        ),
      );
    }
    if (data.containsKey('tasks_enabled')) {
      context.handle(
        _tasksEnabledMeta,
        tasksEnabled.isAcceptableOrUnknown(
          data['tasks_enabled']!,
          _tasksEnabledMeta,
        ),
      );
    }
    if (data.containsKey('granted_scopes')) {
      context.handle(
        _grantedScopesMeta,
        grantedScopes.isAcceptableOrUnknown(
          data['granted_scopes']!,
          _grantedScopesMeta,
        ),
      );
    }
    if (data.containsKey('created_at_utc')) {
      context.handle(
        _createdAtUtcMeta,
        createdAtUtc.isAcceptableOrUnknown(
          data['created_at_utc']!,
          _createdAtUtcMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_createdAtUtcMeta);
    }
    if (data.containsKey('updated_at_utc')) {
      context.handle(
        _updatedAtUtcMeta,
        updatedAtUtc.isAcceptableOrUnknown(
          data['updated_at_utc']!,
          _updatedAtUtcMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_updatedAtUtcMeta);
    }
    if (data.containsKey('last_successful_sync_at_utc')) {
      context.handle(
        _lastSuccessfulSyncAtUtcMeta,
        lastSuccessfulSyncAtUtc.isAcceptableOrUnknown(
          data['last_successful_sync_at_utc']!,
          _lastSuccessfulSyncAtUtcMeta,
        ),
      );
    }
    if (data.containsKey('last_full_sync_at_utc')) {
      context.handle(
        _lastFullSyncAtUtcMeta,
        lastFullSyncAtUtc.isAcceptableOrUnknown(
          data['last_full_sync_at_utc']!,
          _lastFullSyncAtUtcMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Account map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Account(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      provider: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}provider'],
      )!,
      providerAccountId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}provider_account_id'],
      ),
      displayName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}display_name'],
      ),
      email: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}email'],
      ),
      tenantId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tenant_id'],
      ),
      accountAvatarUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}account_avatar_url'],
      ),
      providerMetadataJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}provider_metadata_json'],
      ),
      authState: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}auth_state'],
      )!,
      calendarsEnabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}calendars_enabled'],
      )!,
      tasksEnabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}tasks_enabled'],
      )!,
      grantedScopes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}granted_scopes'],
      )!,
      createdAtUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_at_utc'],
      )!,
      updatedAtUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}updated_at_utc'],
      )!,
      lastSuccessfulSyncAtUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_successful_sync_at_utc'],
      ),
      lastFullSyncAtUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_full_sync_at_utc'],
      ),
    );
  }

  @override
  $AccountsTable createAlias(String alias) {
    return $AccountsTable(attachedDatabase, alias);
  }
}

class Account extends DataClass implements Insertable<Account> {
  final String id;
  final String provider;
  final String? providerAccountId;
  final String? displayName;
  final String? email;
  final String? tenantId;
  final String? accountAvatarUrl;
  final String? providerMetadataJson;
  final String authState;
  final bool calendarsEnabled;
  final bool tasksEnabled;
  final String grantedScopes;
  final String createdAtUtc;
  final String updatedAtUtc;
  final String? lastSuccessfulSyncAtUtc;
  final String? lastFullSyncAtUtc;
  const Account({
    required this.id,
    required this.provider,
    this.providerAccountId,
    this.displayName,
    this.email,
    this.tenantId,
    this.accountAvatarUrl,
    this.providerMetadataJson,
    required this.authState,
    required this.calendarsEnabled,
    required this.tasksEnabled,
    required this.grantedScopes,
    required this.createdAtUtc,
    required this.updatedAtUtc,
    this.lastSuccessfulSyncAtUtc,
    this.lastFullSyncAtUtc,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['provider'] = Variable<String>(provider);
    if (!nullToAbsent || providerAccountId != null) {
      map['provider_account_id'] = Variable<String>(providerAccountId);
    }
    if (!nullToAbsent || displayName != null) {
      map['display_name'] = Variable<String>(displayName);
    }
    if (!nullToAbsent || email != null) {
      map['email'] = Variable<String>(email);
    }
    if (!nullToAbsent || tenantId != null) {
      map['tenant_id'] = Variable<String>(tenantId);
    }
    if (!nullToAbsent || accountAvatarUrl != null) {
      map['account_avatar_url'] = Variable<String>(accountAvatarUrl);
    }
    if (!nullToAbsent || providerMetadataJson != null) {
      map['provider_metadata_json'] = Variable<String>(providerMetadataJson);
    }
    map['auth_state'] = Variable<String>(authState);
    map['calendars_enabled'] = Variable<bool>(calendarsEnabled);
    map['tasks_enabled'] = Variable<bool>(tasksEnabled);
    map['granted_scopes'] = Variable<String>(grantedScopes);
    map['created_at_utc'] = Variable<String>(createdAtUtc);
    map['updated_at_utc'] = Variable<String>(updatedAtUtc);
    if (!nullToAbsent || lastSuccessfulSyncAtUtc != null) {
      map['last_successful_sync_at_utc'] = Variable<String>(
        lastSuccessfulSyncAtUtc,
      );
    }
    if (!nullToAbsent || lastFullSyncAtUtc != null) {
      map['last_full_sync_at_utc'] = Variable<String>(lastFullSyncAtUtc);
    }
    return map;
  }

  AccountsCompanion toCompanion(bool nullToAbsent) {
    return AccountsCompanion(
      id: Value(id),
      provider: Value(provider),
      providerAccountId: providerAccountId == null && nullToAbsent
          ? const Value.absent()
          : Value(providerAccountId),
      displayName: displayName == null && nullToAbsent
          ? const Value.absent()
          : Value(displayName),
      email: email == null && nullToAbsent
          ? const Value.absent()
          : Value(email),
      tenantId: tenantId == null && nullToAbsent
          ? const Value.absent()
          : Value(tenantId),
      accountAvatarUrl: accountAvatarUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(accountAvatarUrl),
      providerMetadataJson: providerMetadataJson == null && nullToAbsent
          ? const Value.absent()
          : Value(providerMetadataJson),
      authState: Value(authState),
      calendarsEnabled: Value(calendarsEnabled),
      tasksEnabled: Value(tasksEnabled),
      grantedScopes: Value(grantedScopes),
      createdAtUtc: Value(createdAtUtc),
      updatedAtUtc: Value(updatedAtUtc),
      lastSuccessfulSyncAtUtc: lastSuccessfulSyncAtUtc == null && nullToAbsent
          ? const Value.absent()
          : Value(lastSuccessfulSyncAtUtc),
      lastFullSyncAtUtc: lastFullSyncAtUtc == null && nullToAbsent
          ? const Value.absent()
          : Value(lastFullSyncAtUtc),
    );
  }

  factory Account.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Account(
      id: serializer.fromJson<String>(json['id']),
      provider: serializer.fromJson<String>(json['provider']),
      providerAccountId: serializer.fromJson<String?>(
        json['providerAccountId'],
      ),
      displayName: serializer.fromJson<String?>(json['displayName']),
      email: serializer.fromJson<String?>(json['email']),
      tenantId: serializer.fromJson<String?>(json['tenantId']),
      accountAvatarUrl: serializer.fromJson<String?>(json['accountAvatarUrl']),
      providerMetadataJson: serializer.fromJson<String?>(
        json['providerMetadataJson'],
      ),
      authState: serializer.fromJson<String>(json['authState']),
      calendarsEnabled: serializer.fromJson<bool>(json['calendarsEnabled']),
      tasksEnabled: serializer.fromJson<bool>(json['tasksEnabled']),
      grantedScopes: serializer.fromJson<String>(json['grantedScopes']),
      createdAtUtc: serializer.fromJson<String>(json['createdAtUtc']),
      updatedAtUtc: serializer.fromJson<String>(json['updatedAtUtc']),
      lastSuccessfulSyncAtUtc: serializer.fromJson<String?>(
        json['lastSuccessfulSyncAtUtc'],
      ),
      lastFullSyncAtUtc: serializer.fromJson<String?>(
        json['lastFullSyncAtUtc'],
      ),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'provider': serializer.toJson<String>(provider),
      'providerAccountId': serializer.toJson<String?>(providerAccountId),
      'displayName': serializer.toJson<String?>(displayName),
      'email': serializer.toJson<String?>(email),
      'tenantId': serializer.toJson<String?>(tenantId),
      'accountAvatarUrl': serializer.toJson<String?>(accountAvatarUrl),
      'providerMetadataJson': serializer.toJson<String?>(providerMetadataJson),
      'authState': serializer.toJson<String>(authState),
      'calendarsEnabled': serializer.toJson<bool>(calendarsEnabled),
      'tasksEnabled': serializer.toJson<bool>(tasksEnabled),
      'grantedScopes': serializer.toJson<String>(grantedScopes),
      'createdAtUtc': serializer.toJson<String>(createdAtUtc),
      'updatedAtUtc': serializer.toJson<String>(updatedAtUtc),
      'lastSuccessfulSyncAtUtc': serializer.toJson<String?>(
        lastSuccessfulSyncAtUtc,
      ),
      'lastFullSyncAtUtc': serializer.toJson<String?>(lastFullSyncAtUtc),
    };
  }

  Account copyWith({
    String? id,
    String? provider,
    Value<String?> providerAccountId = const Value.absent(),
    Value<String?> displayName = const Value.absent(),
    Value<String?> email = const Value.absent(),
    Value<String?> tenantId = const Value.absent(),
    Value<String?> accountAvatarUrl = const Value.absent(),
    Value<String?> providerMetadataJson = const Value.absent(),
    String? authState,
    bool? calendarsEnabled,
    bool? tasksEnabled,
    String? grantedScopes,
    String? createdAtUtc,
    String? updatedAtUtc,
    Value<String?> lastSuccessfulSyncAtUtc = const Value.absent(),
    Value<String?> lastFullSyncAtUtc = const Value.absent(),
  }) => Account(
    id: id ?? this.id,
    provider: provider ?? this.provider,
    providerAccountId: providerAccountId.present
        ? providerAccountId.value
        : this.providerAccountId,
    displayName: displayName.present ? displayName.value : this.displayName,
    email: email.present ? email.value : this.email,
    tenantId: tenantId.present ? tenantId.value : this.tenantId,
    accountAvatarUrl: accountAvatarUrl.present
        ? accountAvatarUrl.value
        : this.accountAvatarUrl,
    providerMetadataJson: providerMetadataJson.present
        ? providerMetadataJson.value
        : this.providerMetadataJson,
    authState: authState ?? this.authState,
    calendarsEnabled: calendarsEnabled ?? this.calendarsEnabled,
    tasksEnabled: tasksEnabled ?? this.tasksEnabled,
    grantedScopes: grantedScopes ?? this.grantedScopes,
    createdAtUtc: createdAtUtc ?? this.createdAtUtc,
    updatedAtUtc: updatedAtUtc ?? this.updatedAtUtc,
    lastSuccessfulSyncAtUtc: lastSuccessfulSyncAtUtc.present
        ? lastSuccessfulSyncAtUtc.value
        : this.lastSuccessfulSyncAtUtc,
    lastFullSyncAtUtc: lastFullSyncAtUtc.present
        ? lastFullSyncAtUtc.value
        : this.lastFullSyncAtUtc,
  );
  Account copyWithCompanion(AccountsCompanion data) {
    return Account(
      id: data.id.present ? data.id.value : this.id,
      provider: data.provider.present ? data.provider.value : this.provider,
      providerAccountId: data.providerAccountId.present
          ? data.providerAccountId.value
          : this.providerAccountId,
      displayName: data.displayName.present
          ? data.displayName.value
          : this.displayName,
      email: data.email.present ? data.email.value : this.email,
      tenantId: data.tenantId.present ? data.tenantId.value : this.tenantId,
      accountAvatarUrl: data.accountAvatarUrl.present
          ? data.accountAvatarUrl.value
          : this.accountAvatarUrl,
      providerMetadataJson: data.providerMetadataJson.present
          ? data.providerMetadataJson.value
          : this.providerMetadataJson,
      authState: data.authState.present ? data.authState.value : this.authState,
      calendarsEnabled: data.calendarsEnabled.present
          ? data.calendarsEnabled.value
          : this.calendarsEnabled,
      tasksEnabled: data.tasksEnabled.present
          ? data.tasksEnabled.value
          : this.tasksEnabled,
      grantedScopes: data.grantedScopes.present
          ? data.grantedScopes.value
          : this.grantedScopes,
      createdAtUtc: data.createdAtUtc.present
          ? data.createdAtUtc.value
          : this.createdAtUtc,
      updatedAtUtc: data.updatedAtUtc.present
          ? data.updatedAtUtc.value
          : this.updatedAtUtc,
      lastSuccessfulSyncAtUtc: data.lastSuccessfulSyncAtUtc.present
          ? data.lastSuccessfulSyncAtUtc.value
          : this.lastSuccessfulSyncAtUtc,
      lastFullSyncAtUtc: data.lastFullSyncAtUtc.present
          ? data.lastFullSyncAtUtc.value
          : this.lastFullSyncAtUtc,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Account(')
          ..write('id: $id, ')
          ..write('provider: $provider, ')
          ..write('providerAccountId: $providerAccountId, ')
          ..write('displayName: $displayName, ')
          ..write('email: $email, ')
          ..write('tenantId: $tenantId, ')
          ..write('accountAvatarUrl: $accountAvatarUrl, ')
          ..write('providerMetadataJson: $providerMetadataJson, ')
          ..write('authState: $authState, ')
          ..write('calendarsEnabled: $calendarsEnabled, ')
          ..write('tasksEnabled: $tasksEnabled, ')
          ..write('grantedScopes: $grantedScopes, ')
          ..write('createdAtUtc: $createdAtUtc, ')
          ..write('updatedAtUtc: $updatedAtUtc, ')
          ..write('lastSuccessfulSyncAtUtc: $lastSuccessfulSyncAtUtc, ')
          ..write('lastFullSyncAtUtc: $lastFullSyncAtUtc')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    provider,
    providerAccountId,
    displayName,
    email,
    tenantId,
    accountAvatarUrl,
    providerMetadataJson,
    authState,
    calendarsEnabled,
    tasksEnabled,
    grantedScopes,
    createdAtUtc,
    updatedAtUtc,
    lastSuccessfulSyncAtUtc,
    lastFullSyncAtUtc,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Account &&
          other.id == this.id &&
          other.provider == this.provider &&
          other.providerAccountId == this.providerAccountId &&
          other.displayName == this.displayName &&
          other.email == this.email &&
          other.tenantId == this.tenantId &&
          other.accountAvatarUrl == this.accountAvatarUrl &&
          other.providerMetadataJson == this.providerMetadataJson &&
          other.authState == this.authState &&
          other.calendarsEnabled == this.calendarsEnabled &&
          other.tasksEnabled == this.tasksEnabled &&
          other.grantedScopes == this.grantedScopes &&
          other.createdAtUtc == this.createdAtUtc &&
          other.updatedAtUtc == this.updatedAtUtc &&
          other.lastSuccessfulSyncAtUtc == this.lastSuccessfulSyncAtUtc &&
          other.lastFullSyncAtUtc == this.lastFullSyncAtUtc);
}

class AccountsCompanion extends UpdateCompanion<Account> {
  final Value<String> id;
  final Value<String> provider;
  final Value<String?> providerAccountId;
  final Value<String?> displayName;
  final Value<String?> email;
  final Value<String?> tenantId;
  final Value<String?> accountAvatarUrl;
  final Value<String?> providerMetadataJson;
  final Value<String> authState;
  final Value<bool> calendarsEnabled;
  final Value<bool> tasksEnabled;
  final Value<String> grantedScopes;
  final Value<String> createdAtUtc;
  final Value<String> updatedAtUtc;
  final Value<String?> lastSuccessfulSyncAtUtc;
  final Value<String?> lastFullSyncAtUtc;
  final Value<int> rowid;
  const AccountsCompanion({
    this.id = const Value.absent(),
    this.provider = const Value.absent(),
    this.providerAccountId = const Value.absent(),
    this.displayName = const Value.absent(),
    this.email = const Value.absent(),
    this.tenantId = const Value.absent(),
    this.accountAvatarUrl = const Value.absent(),
    this.providerMetadataJson = const Value.absent(),
    this.authState = const Value.absent(),
    this.calendarsEnabled = const Value.absent(),
    this.tasksEnabled = const Value.absent(),
    this.grantedScopes = const Value.absent(),
    this.createdAtUtc = const Value.absent(),
    this.updatedAtUtc = const Value.absent(),
    this.lastSuccessfulSyncAtUtc = const Value.absent(),
    this.lastFullSyncAtUtc = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AccountsCompanion.insert({
    required String id,
    this.provider = const Value.absent(),
    this.providerAccountId = const Value.absent(),
    this.displayName = const Value.absent(),
    this.email = const Value.absent(),
    this.tenantId = const Value.absent(),
    this.accountAvatarUrl = const Value.absent(),
    this.providerMetadataJson = const Value.absent(),
    this.authState = const Value.absent(),
    this.calendarsEnabled = const Value.absent(),
    this.tasksEnabled = const Value.absent(),
    this.grantedScopes = const Value.absent(),
    required String createdAtUtc,
    required String updatedAtUtc,
    this.lastSuccessfulSyncAtUtc = const Value.absent(),
    this.lastFullSyncAtUtc = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       createdAtUtc = Value(createdAtUtc),
       updatedAtUtc = Value(updatedAtUtc);
  static Insertable<Account> custom({
    Expression<String>? id,
    Expression<String>? provider,
    Expression<String>? providerAccountId,
    Expression<String>? displayName,
    Expression<String>? email,
    Expression<String>? tenantId,
    Expression<String>? accountAvatarUrl,
    Expression<String>? providerMetadataJson,
    Expression<String>? authState,
    Expression<bool>? calendarsEnabled,
    Expression<bool>? tasksEnabled,
    Expression<String>? grantedScopes,
    Expression<String>? createdAtUtc,
    Expression<String>? updatedAtUtc,
    Expression<String>? lastSuccessfulSyncAtUtc,
    Expression<String>? lastFullSyncAtUtc,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (provider != null) 'provider': provider,
      if (providerAccountId != null) 'provider_account_id': providerAccountId,
      if (displayName != null) 'display_name': displayName,
      if (email != null) 'email': email,
      if (tenantId != null) 'tenant_id': tenantId,
      if (accountAvatarUrl != null) 'account_avatar_url': accountAvatarUrl,
      if (providerMetadataJson != null)
        'provider_metadata_json': providerMetadataJson,
      if (authState != null) 'auth_state': authState,
      if (calendarsEnabled != null) 'calendars_enabled': calendarsEnabled,
      if (tasksEnabled != null) 'tasks_enabled': tasksEnabled,
      if (grantedScopes != null) 'granted_scopes': grantedScopes,
      if (createdAtUtc != null) 'created_at_utc': createdAtUtc,
      if (updatedAtUtc != null) 'updated_at_utc': updatedAtUtc,
      if (lastSuccessfulSyncAtUtc != null)
        'last_successful_sync_at_utc': lastSuccessfulSyncAtUtc,
      if (lastFullSyncAtUtc != null) 'last_full_sync_at_utc': lastFullSyncAtUtc,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AccountsCompanion copyWith({
    Value<String>? id,
    Value<String>? provider,
    Value<String?>? providerAccountId,
    Value<String?>? displayName,
    Value<String?>? email,
    Value<String?>? tenantId,
    Value<String?>? accountAvatarUrl,
    Value<String?>? providerMetadataJson,
    Value<String>? authState,
    Value<bool>? calendarsEnabled,
    Value<bool>? tasksEnabled,
    Value<String>? grantedScopes,
    Value<String>? createdAtUtc,
    Value<String>? updatedAtUtc,
    Value<String?>? lastSuccessfulSyncAtUtc,
    Value<String?>? lastFullSyncAtUtc,
    Value<int>? rowid,
  }) {
    return AccountsCompanion(
      id: id ?? this.id,
      provider: provider ?? this.provider,
      providerAccountId: providerAccountId ?? this.providerAccountId,
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      tenantId: tenantId ?? this.tenantId,
      accountAvatarUrl: accountAvatarUrl ?? this.accountAvatarUrl,
      providerMetadataJson: providerMetadataJson ?? this.providerMetadataJson,
      authState: authState ?? this.authState,
      calendarsEnabled: calendarsEnabled ?? this.calendarsEnabled,
      tasksEnabled: tasksEnabled ?? this.tasksEnabled,
      grantedScopes: grantedScopes ?? this.grantedScopes,
      createdAtUtc: createdAtUtc ?? this.createdAtUtc,
      updatedAtUtc: updatedAtUtc ?? this.updatedAtUtc,
      lastSuccessfulSyncAtUtc:
          lastSuccessfulSyncAtUtc ?? this.lastSuccessfulSyncAtUtc,
      lastFullSyncAtUtc: lastFullSyncAtUtc ?? this.lastFullSyncAtUtc,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (provider.present) {
      map['provider'] = Variable<String>(provider.value);
    }
    if (providerAccountId.present) {
      map['provider_account_id'] = Variable<String>(providerAccountId.value);
    }
    if (displayName.present) {
      map['display_name'] = Variable<String>(displayName.value);
    }
    if (email.present) {
      map['email'] = Variable<String>(email.value);
    }
    if (tenantId.present) {
      map['tenant_id'] = Variable<String>(tenantId.value);
    }
    if (accountAvatarUrl.present) {
      map['account_avatar_url'] = Variable<String>(accountAvatarUrl.value);
    }
    if (providerMetadataJson.present) {
      map['provider_metadata_json'] = Variable<String>(
        providerMetadataJson.value,
      );
    }
    if (authState.present) {
      map['auth_state'] = Variable<String>(authState.value);
    }
    if (calendarsEnabled.present) {
      map['calendars_enabled'] = Variable<bool>(calendarsEnabled.value);
    }
    if (tasksEnabled.present) {
      map['tasks_enabled'] = Variable<bool>(tasksEnabled.value);
    }
    if (grantedScopes.present) {
      map['granted_scopes'] = Variable<String>(grantedScopes.value);
    }
    if (createdAtUtc.present) {
      map['created_at_utc'] = Variable<String>(createdAtUtc.value);
    }
    if (updatedAtUtc.present) {
      map['updated_at_utc'] = Variable<String>(updatedAtUtc.value);
    }
    if (lastSuccessfulSyncAtUtc.present) {
      map['last_successful_sync_at_utc'] = Variable<String>(
        lastSuccessfulSyncAtUtc.value,
      );
    }
    if (lastFullSyncAtUtc.present) {
      map['last_full_sync_at_utc'] = Variable<String>(lastFullSyncAtUtc.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AccountsCompanion(')
          ..write('id: $id, ')
          ..write('provider: $provider, ')
          ..write('providerAccountId: $providerAccountId, ')
          ..write('displayName: $displayName, ')
          ..write('email: $email, ')
          ..write('tenantId: $tenantId, ')
          ..write('accountAvatarUrl: $accountAvatarUrl, ')
          ..write('providerMetadataJson: $providerMetadataJson, ')
          ..write('authState: $authState, ')
          ..write('calendarsEnabled: $calendarsEnabled, ')
          ..write('tasksEnabled: $tasksEnabled, ')
          ..write('grantedScopes: $grantedScopes, ')
          ..write('createdAtUtc: $createdAtUtc, ')
          ..write('updatedAtUtc: $updatedAtUtc, ')
          ..write('lastSuccessfulSyncAtUtc: $lastSuccessfulSyncAtUtc, ')
          ..write('lastFullSyncAtUtc: $lastFullSyncAtUtc, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TaskListsTable extends TaskLists
    with TableInfo<$TaskListsTable, TaskList> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TaskListsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _accountIdMeta = const VerificationMeta(
    'accountId',
  );
  @override
  late final GeneratedColumn<String> accountId = GeneratedColumn<String>(
    'account_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES accounts (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _etagMeta = const VerificationMeta('etag');
  @override
  late final GeneratedColumn<String> etag = GeneratedColumn<String>(
    'etag',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedUtcMeta = const VerificationMeta(
    'updatedUtc',
  );
  @override
  late final GeneratedColumn<String> updatedUtc = GeneratedColumn<String>(
    'updated_utc',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _selfLinkMeta = const VerificationMeta(
    'selfLink',
  );
  @override
  late final GeneratedColumn<String> selfLink = GeneratedColumn<String>(
    'self_link',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _rawJsonMeta = const VerificationMeta(
    'rawJson',
  );
  @override
  late final GeneratedColumn<String> rawJson = GeneratedColumn<String>(
    'raw_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _providerListKindMeta = const VerificationMeta(
    'providerListKind',
  );
  @override
  late final GeneratedColumn<String> providerListKind = GeneratedColumn<String>(
    'provider_list_kind',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isOwnerMeta = const VerificationMeta(
    'isOwner',
  );
  @override
  late final GeneratedColumn<bool> isOwner = GeneratedColumn<bool>(
    'is_owner',
    aliasedName,
    true,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_owner" IN (0, 1))',
    ),
  );
  static const VerificationMeta _isSharedMeta = const VerificationMeta(
    'isShared',
  );
  @override
  late final GeneratedColumn<bool> isShared = GeneratedColumn<bool>(
    'is_shared',
    aliasedName,
    true,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_shared" IN (0, 1))',
    ),
  );
  static const VerificationMeta _deltaLinkMeta = const VerificationMeta(
    'deltaLink',
  );
  @override
  late final GeneratedColumn<String> deltaLink = GeneratedColumn<String>(
    'delta_link',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _providerMetadataJsonMeta =
      const VerificationMeta('providerMetadataJson');
  @override
  late final GeneratedColumn<String> providerMetadataJson =
      GeneratedColumn<String>(
        'provider_metadata_json',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _serverMissingMeta = const VerificationMeta(
    'serverMissing',
  );
  @override
  late final GeneratedColumn<bool> serverMissing = GeneratedColumn<bool>(
    'server_missing',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("server_missing" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _localDirtyMeta = const VerificationMeta(
    'localDirty',
  );
  @override
  late final GeneratedColumn<bool> localDirty = GeneratedColumn<bool>(
    'local_dirty',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("local_dirty" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _pendingDeleteMeta = const VerificationMeta(
    'pendingDelete',
  );
  @override
  late final GeneratedColumn<bool> pendingDelete = GeneratedColumn<bool>(
    'pending_delete',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("pending_delete" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _lastSyncedAtUtcMeta = const VerificationMeta(
    'lastSyncedAtUtc',
  );
  @override
  late final GeneratedColumn<String> lastSyncedAtUtc = GeneratedColumn<String>(
    'last_synced_at_utc',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdLocalAtUtcMeta = const VerificationMeta(
    'createdLocalAtUtc',
  );
  @override
  late final GeneratedColumn<String> createdLocalAtUtc =
      GeneratedColumn<String>(
        'created_local_at_utc',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _updatedLocalAtUtcMeta = const VerificationMeta(
    'updatedLocalAtUtc',
  );
  @override
  late final GeneratedColumn<String> updatedLocalAtUtc =
      GeneratedColumn<String>(
        'updated_local_at_utc',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  @override
  List<GeneratedColumn> get $columns => [
    accountId,
    id,
    kind,
    etag,
    title,
    updatedUtc,
    selfLink,
    rawJson,
    providerListKind,
    isOwner,
    isShared,
    deltaLink,
    providerMetadataJson,
    serverMissing,
    localDirty,
    pendingDelete,
    lastSyncedAtUtc,
    createdLocalAtUtc,
    updatedLocalAtUtc,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'task_lists';
  @override
  VerificationContext validateIntegrity(
    Insertable<TaskList> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('account_id')) {
      context.handle(
        _accountIdMeta,
        accountId.isAcceptableOrUnknown(data['account_id']!, _accountIdMeta),
      );
    } else if (isInserting) {
      context.missing(_accountIdMeta);
    }
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    }
    if (data.containsKey('etag')) {
      context.handle(
        _etagMeta,
        etag.isAcceptableOrUnknown(data['etag']!, _etagMeta),
      );
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('updated_utc')) {
      context.handle(
        _updatedUtcMeta,
        updatedUtc.isAcceptableOrUnknown(data['updated_utc']!, _updatedUtcMeta),
      );
    }
    if (data.containsKey('self_link')) {
      context.handle(
        _selfLinkMeta,
        selfLink.isAcceptableOrUnknown(data['self_link']!, _selfLinkMeta),
      );
    }
    if (data.containsKey('raw_json')) {
      context.handle(
        _rawJsonMeta,
        rawJson.isAcceptableOrUnknown(data['raw_json']!, _rawJsonMeta),
      );
    } else if (isInserting) {
      context.missing(_rawJsonMeta);
    }
    if (data.containsKey('provider_list_kind')) {
      context.handle(
        _providerListKindMeta,
        providerListKind.isAcceptableOrUnknown(
          data['provider_list_kind']!,
          _providerListKindMeta,
        ),
      );
    }
    if (data.containsKey('is_owner')) {
      context.handle(
        _isOwnerMeta,
        isOwner.isAcceptableOrUnknown(data['is_owner']!, _isOwnerMeta),
      );
    }
    if (data.containsKey('is_shared')) {
      context.handle(
        _isSharedMeta,
        isShared.isAcceptableOrUnknown(data['is_shared']!, _isSharedMeta),
      );
    }
    if (data.containsKey('delta_link')) {
      context.handle(
        _deltaLinkMeta,
        deltaLink.isAcceptableOrUnknown(data['delta_link']!, _deltaLinkMeta),
      );
    }
    if (data.containsKey('provider_metadata_json')) {
      context.handle(
        _providerMetadataJsonMeta,
        providerMetadataJson.isAcceptableOrUnknown(
          data['provider_metadata_json']!,
          _providerMetadataJsonMeta,
        ),
      );
    }
    if (data.containsKey('server_missing')) {
      context.handle(
        _serverMissingMeta,
        serverMissing.isAcceptableOrUnknown(
          data['server_missing']!,
          _serverMissingMeta,
        ),
      );
    }
    if (data.containsKey('local_dirty')) {
      context.handle(
        _localDirtyMeta,
        localDirty.isAcceptableOrUnknown(data['local_dirty']!, _localDirtyMeta),
      );
    }
    if (data.containsKey('pending_delete')) {
      context.handle(
        _pendingDeleteMeta,
        pendingDelete.isAcceptableOrUnknown(
          data['pending_delete']!,
          _pendingDeleteMeta,
        ),
      );
    }
    if (data.containsKey('last_synced_at_utc')) {
      context.handle(
        _lastSyncedAtUtcMeta,
        lastSyncedAtUtc.isAcceptableOrUnknown(
          data['last_synced_at_utc']!,
          _lastSyncedAtUtcMeta,
        ),
      );
    }
    if (data.containsKey('created_local_at_utc')) {
      context.handle(
        _createdLocalAtUtcMeta,
        createdLocalAtUtc.isAcceptableOrUnknown(
          data['created_local_at_utc']!,
          _createdLocalAtUtcMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_createdLocalAtUtcMeta);
    }
    if (data.containsKey('updated_local_at_utc')) {
      context.handle(
        _updatedLocalAtUtcMeta,
        updatedLocalAtUtc.isAcceptableOrUnknown(
          data['updated_local_at_utc']!,
          _updatedLocalAtUtcMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_updatedLocalAtUtcMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {accountId, id};
  @override
  TaskList map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TaskList(
      accountId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}account_id'],
      )!,
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      ),
      etag: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}etag'],
      ),
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      updatedUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}updated_utc'],
      ),
      selfLink: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}self_link'],
      ),
      rawJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}raw_json'],
      )!,
      providerListKind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}provider_list_kind'],
      ),
      isOwner: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_owner'],
      ),
      isShared: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_shared'],
      ),
      deltaLink: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}delta_link'],
      ),
      providerMetadataJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}provider_metadata_json'],
      ),
      serverMissing: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}server_missing'],
      )!,
      localDirty: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}local_dirty'],
      )!,
      pendingDelete: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}pending_delete'],
      )!,
      lastSyncedAtUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_synced_at_utc'],
      ),
      createdLocalAtUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_local_at_utc'],
      )!,
      updatedLocalAtUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}updated_local_at_utc'],
      )!,
    );
  }

  @override
  $TaskListsTable createAlias(String alias) {
    return $TaskListsTable(attachedDatabase, alias);
  }
}

class TaskList extends DataClass implements Insertable<TaskList> {
  final String accountId;
  final String id;
  final String? kind;
  final String? etag;
  final String title;
  final String? updatedUtc;
  final String? selfLink;
  final String rawJson;
  final String? providerListKind;
  final bool? isOwner;
  final bool? isShared;
  final String? deltaLink;
  final String? providerMetadataJson;
  final bool serverMissing;
  final bool localDirty;
  final bool pendingDelete;
  final String? lastSyncedAtUtc;
  final String createdLocalAtUtc;
  final String updatedLocalAtUtc;
  const TaskList({
    required this.accountId,
    required this.id,
    this.kind,
    this.etag,
    required this.title,
    this.updatedUtc,
    this.selfLink,
    required this.rawJson,
    this.providerListKind,
    this.isOwner,
    this.isShared,
    this.deltaLink,
    this.providerMetadataJson,
    required this.serverMissing,
    required this.localDirty,
    required this.pendingDelete,
    this.lastSyncedAtUtc,
    required this.createdLocalAtUtc,
    required this.updatedLocalAtUtc,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['account_id'] = Variable<String>(accountId);
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || kind != null) {
      map['kind'] = Variable<String>(kind);
    }
    if (!nullToAbsent || etag != null) {
      map['etag'] = Variable<String>(etag);
    }
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || updatedUtc != null) {
      map['updated_utc'] = Variable<String>(updatedUtc);
    }
    if (!nullToAbsent || selfLink != null) {
      map['self_link'] = Variable<String>(selfLink);
    }
    map['raw_json'] = Variable<String>(rawJson);
    if (!nullToAbsent || providerListKind != null) {
      map['provider_list_kind'] = Variable<String>(providerListKind);
    }
    if (!nullToAbsent || isOwner != null) {
      map['is_owner'] = Variable<bool>(isOwner);
    }
    if (!nullToAbsent || isShared != null) {
      map['is_shared'] = Variable<bool>(isShared);
    }
    if (!nullToAbsent || deltaLink != null) {
      map['delta_link'] = Variable<String>(deltaLink);
    }
    if (!nullToAbsent || providerMetadataJson != null) {
      map['provider_metadata_json'] = Variable<String>(providerMetadataJson);
    }
    map['server_missing'] = Variable<bool>(serverMissing);
    map['local_dirty'] = Variable<bool>(localDirty);
    map['pending_delete'] = Variable<bool>(pendingDelete);
    if (!nullToAbsent || lastSyncedAtUtc != null) {
      map['last_synced_at_utc'] = Variable<String>(lastSyncedAtUtc);
    }
    map['created_local_at_utc'] = Variable<String>(createdLocalAtUtc);
    map['updated_local_at_utc'] = Variable<String>(updatedLocalAtUtc);
    return map;
  }

  TaskListsCompanion toCompanion(bool nullToAbsent) {
    return TaskListsCompanion(
      accountId: Value(accountId),
      id: Value(id),
      kind: kind == null && nullToAbsent ? const Value.absent() : Value(kind),
      etag: etag == null && nullToAbsent ? const Value.absent() : Value(etag),
      title: Value(title),
      updatedUtc: updatedUtc == null && nullToAbsent
          ? const Value.absent()
          : Value(updatedUtc),
      selfLink: selfLink == null && nullToAbsent
          ? const Value.absent()
          : Value(selfLink),
      rawJson: Value(rawJson),
      providerListKind: providerListKind == null && nullToAbsent
          ? const Value.absent()
          : Value(providerListKind),
      isOwner: isOwner == null && nullToAbsent
          ? const Value.absent()
          : Value(isOwner),
      isShared: isShared == null && nullToAbsent
          ? const Value.absent()
          : Value(isShared),
      deltaLink: deltaLink == null && nullToAbsent
          ? const Value.absent()
          : Value(deltaLink),
      providerMetadataJson: providerMetadataJson == null && nullToAbsent
          ? const Value.absent()
          : Value(providerMetadataJson),
      serverMissing: Value(serverMissing),
      localDirty: Value(localDirty),
      pendingDelete: Value(pendingDelete),
      lastSyncedAtUtc: lastSyncedAtUtc == null && nullToAbsent
          ? const Value.absent()
          : Value(lastSyncedAtUtc),
      createdLocalAtUtc: Value(createdLocalAtUtc),
      updatedLocalAtUtc: Value(updatedLocalAtUtc),
    );
  }

  factory TaskList.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TaskList(
      accountId: serializer.fromJson<String>(json['accountId']),
      id: serializer.fromJson<String>(json['id']),
      kind: serializer.fromJson<String?>(json['kind']),
      etag: serializer.fromJson<String?>(json['etag']),
      title: serializer.fromJson<String>(json['title']),
      updatedUtc: serializer.fromJson<String?>(json['updatedUtc']),
      selfLink: serializer.fromJson<String?>(json['selfLink']),
      rawJson: serializer.fromJson<String>(json['rawJson']),
      providerListKind: serializer.fromJson<String?>(json['providerListKind']),
      isOwner: serializer.fromJson<bool?>(json['isOwner']),
      isShared: serializer.fromJson<bool?>(json['isShared']),
      deltaLink: serializer.fromJson<String?>(json['deltaLink']),
      providerMetadataJson: serializer.fromJson<String?>(
        json['providerMetadataJson'],
      ),
      serverMissing: serializer.fromJson<bool>(json['serverMissing']),
      localDirty: serializer.fromJson<bool>(json['localDirty']),
      pendingDelete: serializer.fromJson<bool>(json['pendingDelete']),
      lastSyncedAtUtc: serializer.fromJson<String?>(json['lastSyncedAtUtc']),
      createdLocalAtUtc: serializer.fromJson<String>(json['createdLocalAtUtc']),
      updatedLocalAtUtc: serializer.fromJson<String>(json['updatedLocalAtUtc']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'accountId': serializer.toJson<String>(accountId),
      'id': serializer.toJson<String>(id),
      'kind': serializer.toJson<String?>(kind),
      'etag': serializer.toJson<String?>(etag),
      'title': serializer.toJson<String>(title),
      'updatedUtc': serializer.toJson<String?>(updatedUtc),
      'selfLink': serializer.toJson<String?>(selfLink),
      'rawJson': serializer.toJson<String>(rawJson),
      'providerListKind': serializer.toJson<String?>(providerListKind),
      'isOwner': serializer.toJson<bool?>(isOwner),
      'isShared': serializer.toJson<bool?>(isShared),
      'deltaLink': serializer.toJson<String?>(deltaLink),
      'providerMetadataJson': serializer.toJson<String?>(providerMetadataJson),
      'serverMissing': serializer.toJson<bool>(serverMissing),
      'localDirty': serializer.toJson<bool>(localDirty),
      'pendingDelete': serializer.toJson<bool>(pendingDelete),
      'lastSyncedAtUtc': serializer.toJson<String?>(lastSyncedAtUtc),
      'createdLocalAtUtc': serializer.toJson<String>(createdLocalAtUtc),
      'updatedLocalAtUtc': serializer.toJson<String>(updatedLocalAtUtc),
    };
  }

  TaskList copyWith({
    String? accountId,
    String? id,
    Value<String?> kind = const Value.absent(),
    Value<String?> etag = const Value.absent(),
    String? title,
    Value<String?> updatedUtc = const Value.absent(),
    Value<String?> selfLink = const Value.absent(),
    String? rawJson,
    Value<String?> providerListKind = const Value.absent(),
    Value<bool?> isOwner = const Value.absent(),
    Value<bool?> isShared = const Value.absent(),
    Value<String?> deltaLink = const Value.absent(),
    Value<String?> providerMetadataJson = const Value.absent(),
    bool? serverMissing,
    bool? localDirty,
    bool? pendingDelete,
    Value<String?> lastSyncedAtUtc = const Value.absent(),
    String? createdLocalAtUtc,
    String? updatedLocalAtUtc,
  }) => TaskList(
    accountId: accountId ?? this.accountId,
    id: id ?? this.id,
    kind: kind.present ? kind.value : this.kind,
    etag: etag.present ? etag.value : this.etag,
    title: title ?? this.title,
    updatedUtc: updatedUtc.present ? updatedUtc.value : this.updatedUtc,
    selfLink: selfLink.present ? selfLink.value : this.selfLink,
    rawJson: rawJson ?? this.rawJson,
    providerListKind: providerListKind.present
        ? providerListKind.value
        : this.providerListKind,
    isOwner: isOwner.present ? isOwner.value : this.isOwner,
    isShared: isShared.present ? isShared.value : this.isShared,
    deltaLink: deltaLink.present ? deltaLink.value : this.deltaLink,
    providerMetadataJson: providerMetadataJson.present
        ? providerMetadataJson.value
        : this.providerMetadataJson,
    serverMissing: serverMissing ?? this.serverMissing,
    localDirty: localDirty ?? this.localDirty,
    pendingDelete: pendingDelete ?? this.pendingDelete,
    lastSyncedAtUtc: lastSyncedAtUtc.present
        ? lastSyncedAtUtc.value
        : this.lastSyncedAtUtc,
    createdLocalAtUtc: createdLocalAtUtc ?? this.createdLocalAtUtc,
    updatedLocalAtUtc: updatedLocalAtUtc ?? this.updatedLocalAtUtc,
  );
  TaskList copyWithCompanion(TaskListsCompanion data) {
    return TaskList(
      accountId: data.accountId.present ? data.accountId.value : this.accountId,
      id: data.id.present ? data.id.value : this.id,
      kind: data.kind.present ? data.kind.value : this.kind,
      etag: data.etag.present ? data.etag.value : this.etag,
      title: data.title.present ? data.title.value : this.title,
      updatedUtc: data.updatedUtc.present
          ? data.updatedUtc.value
          : this.updatedUtc,
      selfLink: data.selfLink.present ? data.selfLink.value : this.selfLink,
      rawJson: data.rawJson.present ? data.rawJson.value : this.rawJson,
      providerListKind: data.providerListKind.present
          ? data.providerListKind.value
          : this.providerListKind,
      isOwner: data.isOwner.present ? data.isOwner.value : this.isOwner,
      isShared: data.isShared.present ? data.isShared.value : this.isShared,
      deltaLink: data.deltaLink.present ? data.deltaLink.value : this.deltaLink,
      providerMetadataJson: data.providerMetadataJson.present
          ? data.providerMetadataJson.value
          : this.providerMetadataJson,
      serverMissing: data.serverMissing.present
          ? data.serverMissing.value
          : this.serverMissing,
      localDirty: data.localDirty.present
          ? data.localDirty.value
          : this.localDirty,
      pendingDelete: data.pendingDelete.present
          ? data.pendingDelete.value
          : this.pendingDelete,
      lastSyncedAtUtc: data.lastSyncedAtUtc.present
          ? data.lastSyncedAtUtc.value
          : this.lastSyncedAtUtc,
      createdLocalAtUtc: data.createdLocalAtUtc.present
          ? data.createdLocalAtUtc.value
          : this.createdLocalAtUtc,
      updatedLocalAtUtc: data.updatedLocalAtUtc.present
          ? data.updatedLocalAtUtc.value
          : this.updatedLocalAtUtc,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TaskList(')
          ..write('accountId: $accountId, ')
          ..write('id: $id, ')
          ..write('kind: $kind, ')
          ..write('etag: $etag, ')
          ..write('title: $title, ')
          ..write('updatedUtc: $updatedUtc, ')
          ..write('selfLink: $selfLink, ')
          ..write('rawJson: $rawJson, ')
          ..write('providerListKind: $providerListKind, ')
          ..write('isOwner: $isOwner, ')
          ..write('isShared: $isShared, ')
          ..write('deltaLink: $deltaLink, ')
          ..write('providerMetadataJson: $providerMetadataJson, ')
          ..write('serverMissing: $serverMissing, ')
          ..write('localDirty: $localDirty, ')
          ..write('pendingDelete: $pendingDelete, ')
          ..write('lastSyncedAtUtc: $lastSyncedAtUtc, ')
          ..write('createdLocalAtUtc: $createdLocalAtUtc, ')
          ..write('updatedLocalAtUtc: $updatedLocalAtUtc')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    accountId,
    id,
    kind,
    etag,
    title,
    updatedUtc,
    selfLink,
    rawJson,
    providerListKind,
    isOwner,
    isShared,
    deltaLink,
    providerMetadataJson,
    serverMissing,
    localDirty,
    pendingDelete,
    lastSyncedAtUtc,
    createdLocalAtUtc,
    updatedLocalAtUtc,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TaskList &&
          other.accountId == this.accountId &&
          other.id == this.id &&
          other.kind == this.kind &&
          other.etag == this.etag &&
          other.title == this.title &&
          other.updatedUtc == this.updatedUtc &&
          other.selfLink == this.selfLink &&
          other.rawJson == this.rawJson &&
          other.providerListKind == this.providerListKind &&
          other.isOwner == this.isOwner &&
          other.isShared == this.isShared &&
          other.deltaLink == this.deltaLink &&
          other.providerMetadataJson == this.providerMetadataJson &&
          other.serverMissing == this.serverMissing &&
          other.localDirty == this.localDirty &&
          other.pendingDelete == this.pendingDelete &&
          other.lastSyncedAtUtc == this.lastSyncedAtUtc &&
          other.createdLocalAtUtc == this.createdLocalAtUtc &&
          other.updatedLocalAtUtc == this.updatedLocalAtUtc);
}

class TaskListsCompanion extends UpdateCompanion<TaskList> {
  final Value<String> accountId;
  final Value<String> id;
  final Value<String?> kind;
  final Value<String?> etag;
  final Value<String> title;
  final Value<String?> updatedUtc;
  final Value<String?> selfLink;
  final Value<String> rawJson;
  final Value<String?> providerListKind;
  final Value<bool?> isOwner;
  final Value<bool?> isShared;
  final Value<String?> deltaLink;
  final Value<String?> providerMetadataJson;
  final Value<bool> serverMissing;
  final Value<bool> localDirty;
  final Value<bool> pendingDelete;
  final Value<String?> lastSyncedAtUtc;
  final Value<String> createdLocalAtUtc;
  final Value<String> updatedLocalAtUtc;
  final Value<int> rowid;
  const TaskListsCompanion({
    this.accountId = const Value.absent(),
    this.id = const Value.absent(),
    this.kind = const Value.absent(),
    this.etag = const Value.absent(),
    this.title = const Value.absent(),
    this.updatedUtc = const Value.absent(),
    this.selfLink = const Value.absent(),
    this.rawJson = const Value.absent(),
    this.providerListKind = const Value.absent(),
    this.isOwner = const Value.absent(),
    this.isShared = const Value.absent(),
    this.deltaLink = const Value.absent(),
    this.providerMetadataJson = const Value.absent(),
    this.serverMissing = const Value.absent(),
    this.localDirty = const Value.absent(),
    this.pendingDelete = const Value.absent(),
    this.lastSyncedAtUtc = const Value.absent(),
    this.createdLocalAtUtc = const Value.absent(),
    this.updatedLocalAtUtc = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TaskListsCompanion.insert({
    required String accountId,
    required String id,
    this.kind = const Value.absent(),
    this.etag = const Value.absent(),
    required String title,
    this.updatedUtc = const Value.absent(),
    this.selfLink = const Value.absent(),
    required String rawJson,
    this.providerListKind = const Value.absent(),
    this.isOwner = const Value.absent(),
    this.isShared = const Value.absent(),
    this.deltaLink = const Value.absent(),
    this.providerMetadataJson = const Value.absent(),
    this.serverMissing = const Value.absent(),
    this.localDirty = const Value.absent(),
    this.pendingDelete = const Value.absent(),
    this.lastSyncedAtUtc = const Value.absent(),
    required String createdLocalAtUtc,
    required String updatedLocalAtUtc,
    this.rowid = const Value.absent(),
  }) : accountId = Value(accountId),
       id = Value(id),
       title = Value(title),
       rawJson = Value(rawJson),
       createdLocalAtUtc = Value(createdLocalAtUtc),
       updatedLocalAtUtc = Value(updatedLocalAtUtc);
  static Insertable<TaskList> custom({
    Expression<String>? accountId,
    Expression<String>? id,
    Expression<String>? kind,
    Expression<String>? etag,
    Expression<String>? title,
    Expression<String>? updatedUtc,
    Expression<String>? selfLink,
    Expression<String>? rawJson,
    Expression<String>? providerListKind,
    Expression<bool>? isOwner,
    Expression<bool>? isShared,
    Expression<String>? deltaLink,
    Expression<String>? providerMetadataJson,
    Expression<bool>? serverMissing,
    Expression<bool>? localDirty,
    Expression<bool>? pendingDelete,
    Expression<String>? lastSyncedAtUtc,
    Expression<String>? createdLocalAtUtc,
    Expression<String>? updatedLocalAtUtc,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (accountId != null) 'account_id': accountId,
      if (id != null) 'id': id,
      if (kind != null) 'kind': kind,
      if (etag != null) 'etag': etag,
      if (title != null) 'title': title,
      if (updatedUtc != null) 'updated_utc': updatedUtc,
      if (selfLink != null) 'self_link': selfLink,
      if (rawJson != null) 'raw_json': rawJson,
      if (providerListKind != null) 'provider_list_kind': providerListKind,
      if (isOwner != null) 'is_owner': isOwner,
      if (isShared != null) 'is_shared': isShared,
      if (deltaLink != null) 'delta_link': deltaLink,
      if (providerMetadataJson != null)
        'provider_metadata_json': providerMetadataJson,
      if (serverMissing != null) 'server_missing': serverMissing,
      if (localDirty != null) 'local_dirty': localDirty,
      if (pendingDelete != null) 'pending_delete': pendingDelete,
      if (lastSyncedAtUtc != null) 'last_synced_at_utc': lastSyncedAtUtc,
      if (createdLocalAtUtc != null) 'created_local_at_utc': createdLocalAtUtc,
      if (updatedLocalAtUtc != null) 'updated_local_at_utc': updatedLocalAtUtc,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TaskListsCompanion copyWith({
    Value<String>? accountId,
    Value<String>? id,
    Value<String?>? kind,
    Value<String?>? etag,
    Value<String>? title,
    Value<String?>? updatedUtc,
    Value<String?>? selfLink,
    Value<String>? rawJson,
    Value<String?>? providerListKind,
    Value<bool?>? isOwner,
    Value<bool?>? isShared,
    Value<String?>? deltaLink,
    Value<String?>? providerMetadataJson,
    Value<bool>? serverMissing,
    Value<bool>? localDirty,
    Value<bool>? pendingDelete,
    Value<String?>? lastSyncedAtUtc,
    Value<String>? createdLocalAtUtc,
    Value<String>? updatedLocalAtUtc,
    Value<int>? rowid,
  }) {
    return TaskListsCompanion(
      accountId: accountId ?? this.accountId,
      id: id ?? this.id,
      kind: kind ?? this.kind,
      etag: etag ?? this.etag,
      title: title ?? this.title,
      updatedUtc: updatedUtc ?? this.updatedUtc,
      selfLink: selfLink ?? this.selfLink,
      rawJson: rawJson ?? this.rawJson,
      providerListKind: providerListKind ?? this.providerListKind,
      isOwner: isOwner ?? this.isOwner,
      isShared: isShared ?? this.isShared,
      deltaLink: deltaLink ?? this.deltaLink,
      providerMetadataJson: providerMetadataJson ?? this.providerMetadataJson,
      serverMissing: serverMissing ?? this.serverMissing,
      localDirty: localDirty ?? this.localDirty,
      pendingDelete: pendingDelete ?? this.pendingDelete,
      lastSyncedAtUtc: lastSyncedAtUtc ?? this.lastSyncedAtUtc,
      createdLocalAtUtc: createdLocalAtUtc ?? this.createdLocalAtUtc,
      updatedLocalAtUtc: updatedLocalAtUtc ?? this.updatedLocalAtUtc,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (accountId.present) {
      map['account_id'] = Variable<String>(accountId.value);
    }
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (etag.present) {
      map['etag'] = Variable<String>(etag.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (updatedUtc.present) {
      map['updated_utc'] = Variable<String>(updatedUtc.value);
    }
    if (selfLink.present) {
      map['self_link'] = Variable<String>(selfLink.value);
    }
    if (rawJson.present) {
      map['raw_json'] = Variable<String>(rawJson.value);
    }
    if (providerListKind.present) {
      map['provider_list_kind'] = Variable<String>(providerListKind.value);
    }
    if (isOwner.present) {
      map['is_owner'] = Variable<bool>(isOwner.value);
    }
    if (isShared.present) {
      map['is_shared'] = Variable<bool>(isShared.value);
    }
    if (deltaLink.present) {
      map['delta_link'] = Variable<String>(deltaLink.value);
    }
    if (providerMetadataJson.present) {
      map['provider_metadata_json'] = Variable<String>(
        providerMetadataJson.value,
      );
    }
    if (serverMissing.present) {
      map['server_missing'] = Variable<bool>(serverMissing.value);
    }
    if (localDirty.present) {
      map['local_dirty'] = Variable<bool>(localDirty.value);
    }
    if (pendingDelete.present) {
      map['pending_delete'] = Variable<bool>(pendingDelete.value);
    }
    if (lastSyncedAtUtc.present) {
      map['last_synced_at_utc'] = Variable<String>(lastSyncedAtUtc.value);
    }
    if (createdLocalAtUtc.present) {
      map['created_local_at_utc'] = Variable<String>(createdLocalAtUtc.value);
    }
    if (updatedLocalAtUtc.present) {
      map['updated_local_at_utc'] = Variable<String>(updatedLocalAtUtc.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TaskListsCompanion(')
          ..write('accountId: $accountId, ')
          ..write('id: $id, ')
          ..write('kind: $kind, ')
          ..write('etag: $etag, ')
          ..write('title: $title, ')
          ..write('updatedUtc: $updatedUtc, ')
          ..write('selfLink: $selfLink, ')
          ..write('rawJson: $rawJson, ')
          ..write('providerListKind: $providerListKind, ')
          ..write('isOwner: $isOwner, ')
          ..write('isShared: $isShared, ')
          ..write('deltaLink: $deltaLink, ')
          ..write('providerMetadataJson: $providerMetadataJson, ')
          ..write('serverMissing: $serverMissing, ')
          ..write('localDirty: $localDirty, ')
          ..write('pendingDelete: $pendingDelete, ')
          ..write('lastSyncedAtUtc: $lastSyncedAtUtc, ')
          ..write('createdLocalAtUtc: $createdLocalAtUtc, ')
          ..write('updatedLocalAtUtc: $updatedLocalAtUtc, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TasksTable extends Tasks with TableInfo<$TasksTable, Task> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TasksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _accountIdMeta = const VerificationMeta(
    'accountId',
  );
  @override
  late final GeneratedColumn<String> accountId = GeneratedColumn<String>(
    'account_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES accounts (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _taskListIdMeta = const VerificationMeta(
    'taskListId',
  );
  @override
  late final GeneratedColumn<String> taskListId = GeneratedColumn<String>(
    'task_list_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _etagMeta = const VerificationMeta('etag');
  @override
  late final GeneratedColumn<String> etag = GeneratedColumn<String>(
    'etag',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedUtcMeta = const VerificationMeta(
    'updatedUtc',
  );
  @override
  late final GeneratedColumn<String> updatedUtc = GeneratedColumn<String>(
    'updated_utc',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _selfLinkMeta = const VerificationMeta(
    'selfLink',
  );
  @override
  late final GeneratedColumn<String> selfLink = GeneratedColumn<String>(
    'self_link',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _parentMeta = const VerificationMeta('parent');
  @override
  late final GeneratedColumn<String> parent = GeneratedColumn<String>(
    'parent',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _positionMeta = const VerificationMeta(
    'position',
  );
  @override
  late final GeneratedColumn<String> position = GeneratedColumn<String>(
    'position',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _dueUtcMeta = const VerificationMeta('dueUtc');
  @override
  late final GeneratedColumn<String> dueUtc = GeneratedColumn<String>(
    'due_utc',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _completedUtcMeta = const VerificationMeta(
    'completedUtc',
  );
  @override
  late final GeneratedColumn<String> completedUtc = GeneratedColumn<String>(
    'completed_utc',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _providerStatusMeta = const VerificationMeta(
    'providerStatus',
  );
  @override
  late final GeneratedColumn<String> providerStatus = GeneratedColumn<String>(
    'provider_status',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _bodyContentMeta = const VerificationMeta(
    'bodyContent',
  );
  @override
  late final GeneratedColumn<String> bodyContent = GeneratedColumn<String>(
    'body_content',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _bodyContentTypeMeta = const VerificationMeta(
    'bodyContentType',
  );
  @override
  late final GeneratedColumn<String> bodyContentType = GeneratedColumn<String>(
    'body_content_type',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _microsoftDueDateTimeMeta =
      const VerificationMeta('microsoftDueDateTime');
  @override
  late final GeneratedColumn<String> microsoftDueDateTime =
      GeneratedColumn<String>(
        'microsoft_due_date_time',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _microsoftDueTimeZoneMeta =
      const VerificationMeta('microsoftDueTimeZone');
  @override
  late final GeneratedColumn<String> microsoftDueTimeZone =
      GeneratedColumn<String>(
        'microsoft_due_time_zone',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _microsoftStartDateTimeMeta =
      const VerificationMeta('microsoftStartDateTime');
  @override
  late final GeneratedColumn<String> microsoftStartDateTime =
      GeneratedColumn<String>(
        'microsoft_start_date_time',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _microsoftStartTimeZoneMeta =
      const VerificationMeta('microsoftStartTimeZone');
  @override
  late final GeneratedColumn<String> microsoftStartTimeZone =
      GeneratedColumn<String>(
        'microsoft_start_time_zone',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _microsoftReminderDateTimeMeta =
      const VerificationMeta('microsoftReminderDateTime');
  @override
  late final GeneratedColumn<String> microsoftReminderDateTime =
      GeneratedColumn<String>(
        'microsoft_reminder_date_time',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _microsoftReminderTimeZoneMeta =
      const VerificationMeta('microsoftReminderTimeZone');
  @override
  late final GeneratedColumn<String> microsoftReminderTimeZone =
      GeneratedColumn<String>(
        'microsoft_reminder_time_zone',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _microsoftIsReminderOnMeta =
      const VerificationMeta('microsoftIsReminderOn');
  @override
  late final GeneratedColumn<bool> microsoftIsReminderOn =
      GeneratedColumn<bool>(
        'microsoft_is_reminder_on',
        aliasedName,
        true,
        type: DriftSqlType.bool,
        requiredDuringInsert: false,
        defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("microsoft_is_reminder_on" IN (0, 1))',
        ),
      );
  static const VerificationMeta _microsoftCompletedDateTimeMeta =
      const VerificationMeta('microsoftCompletedDateTime');
  @override
  late final GeneratedColumn<String> microsoftCompletedDateTime =
      GeneratedColumn<String>(
        'microsoft_completed_date_time',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _microsoftCompletedTimeZoneMeta =
      const VerificationMeta('microsoftCompletedTimeZone');
  @override
  late final GeneratedColumn<String> microsoftCompletedTimeZone =
      GeneratedColumn<String>(
        'microsoft_completed_time_zone',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _recurrenceJsonMeta = const VerificationMeta(
    'recurrenceJson',
  );
  @override
  late final GeneratedColumn<String> recurrenceJson = GeneratedColumn<String>(
    'recurrence_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _importanceMeta = const VerificationMeta(
    'importance',
  );
  @override
  late final GeneratedColumn<String> importance = GeneratedColumn<String>(
    'importance',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _categoriesJsonMeta = const VerificationMeta(
    'categoriesJson',
  );
  @override
  late final GeneratedColumn<String> categoriesJson = GeneratedColumn<String>(
    'categories_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _hasAttachmentsMeta = const VerificationMeta(
    'hasAttachments',
  );
  @override
  late final GeneratedColumn<bool> hasAttachments = GeneratedColumn<bool>(
    'has_attachments',
    aliasedName,
    true,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("has_attachments" IN (0, 1))',
    ),
  );
  static const VerificationMeta _providerMetadataJsonMeta =
      const VerificationMeta('providerMetadataJson');
  @override
  late final GeneratedColumn<String> providerMetadataJson =
      GeneratedColumn<String>(
        'provider_metadata_json',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _deletedMeta = const VerificationMeta(
    'deleted',
  );
  @override
  late final GeneratedColumn<bool> deleted = GeneratedColumn<bool>(
    'deleted',
    aliasedName,
    true,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("deleted" IN (0, 1))',
    ),
  );
  static const VerificationMeta _hiddenMeta = const VerificationMeta('hidden');
  @override
  late final GeneratedColumn<bool> hidden = GeneratedColumn<bool>(
    'hidden',
    aliasedName,
    true,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("hidden" IN (0, 1))',
    ),
  );
  static const VerificationMeta _linksJsonMeta = const VerificationMeta(
    'linksJson',
  );
  @override
  late final GeneratedColumn<String> linksJson = GeneratedColumn<String>(
    'links_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _webViewLinkMeta = const VerificationMeta(
    'webViewLink',
  );
  @override
  late final GeneratedColumn<String> webViewLink = GeneratedColumn<String>(
    'web_view_link',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _assignmentInfoJsonMeta =
      const VerificationMeta('assignmentInfoJson');
  @override
  late final GeneratedColumn<String> assignmentInfoJson =
      GeneratedColumn<String>(
        'assignment_info_json',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _rawJsonMeta = const VerificationMeta(
    'rawJson',
  );
  @override
  late final GeneratedColumn<String> rawJson = GeneratedColumn<String>(
    'raw_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _serverMissingMeta = const VerificationMeta(
    'serverMissing',
  );
  @override
  late final GeneratedColumn<bool> serverMissing = GeneratedColumn<bool>(
    'server_missing',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("server_missing" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _localDirtyMeta = const VerificationMeta(
    'localDirty',
  );
  @override
  late final GeneratedColumn<bool> localDirty = GeneratedColumn<bool>(
    'local_dirty',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("local_dirty" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _pendingDeleteMeta = const VerificationMeta(
    'pendingDelete',
  );
  @override
  late final GeneratedColumn<bool> pendingDelete = GeneratedColumn<bool>(
    'pending_delete',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("pending_delete" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _pendingMoveMeta = const VerificationMeta(
    'pendingMove',
  );
  @override
  late final GeneratedColumn<bool> pendingMove = GeneratedColumn<bool>(
    'pending_move',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("pending_move" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _localCreatedMeta = const VerificationMeta(
    'localCreated',
  );
  @override
  late final GeneratedColumn<bool> localCreated = GeneratedColumn<bool>(
    'local_created',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("local_created" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _syncBaseUpdatedUtcMeta =
      const VerificationMeta('syncBaseUpdatedUtc');
  @override
  late final GeneratedColumn<String> syncBaseUpdatedUtc =
      GeneratedColumn<String>(
        'sync_base_updated_utc',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _lastSyncedAtUtcMeta = const VerificationMeta(
    'lastSyncedAtUtc',
  );
  @override
  late final GeneratedColumn<String> lastSyncedAtUtc = GeneratedColumn<String>(
    'last_synced_at_utc',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdLocalAtUtcMeta = const VerificationMeta(
    'createdLocalAtUtc',
  );
  @override
  late final GeneratedColumn<String> createdLocalAtUtc =
      GeneratedColumn<String>(
        'created_local_at_utc',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _updatedLocalAtUtcMeta = const VerificationMeta(
    'updatedLocalAtUtc',
  );
  @override
  late final GeneratedColumn<String> updatedLocalAtUtc =
      GeneratedColumn<String>(
        'updated_local_at_utc',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  @override
  List<GeneratedColumn> get $columns => [
    accountId,
    taskListId,
    id,
    kind,
    etag,
    title,
    updatedUtc,
    selfLink,
    parent,
    position,
    notes,
    status,
    dueUtc,
    completedUtc,
    providerStatus,
    bodyContent,
    bodyContentType,
    microsoftDueDateTime,
    microsoftDueTimeZone,
    microsoftStartDateTime,
    microsoftStartTimeZone,
    microsoftReminderDateTime,
    microsoftReminderTimeZone,
    microsoftIsReminderOn,
    microsoftCompletedDateTime,
    microsoftCompletedTimeZone,
    recurrenceJson,
    importance,
    categoriesJson,
    hasAttachments,
    providerMetadataJson,
    deleted,
    hidden,
    linksJson,
    webViewLink,
    assignmentInfoJson,
    rawJson,
    serverMissing,
    localDirty,
    pendingDelete,
    pendingMove,
    localCreated,
    syncBaseUpdatedUtc,
    lastSyncedAtUtc,
    createdLocalAtUtc,
    updatedLocalAtUtc,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'tasks';
  @override
  VerificationContext validateIntegrity(
    Insertable<Task> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('account_id')) {
      context.handle(
        _accountIdMeta,
        accountId.isAcceptableOrUnknown(data['account_id']!, _accountIdMeta),
      );
    } else if (isInserting) {
      context.missing(_accountIdMeta);
    }
    if (data.containsKey('task_list_id')) {
      context.handle(
        _taskListIdMeta,
        taskListId.isAcceptableOrUnknown(
          data['task_list_id']!,
          _taskListIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_taskListIdMeta);
    }
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    }
    if (data.containsKey('etag')) {
      context.handle(
        _etagMeta,
        etag.isAcceptableOrUnknown(data['etag']!, _etagMeta),
      );
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('updated_utc')) {
      context.handle(
        _updatedUtcMeta,
        updatedUtc.isAcceptableOrUnknown(data['updated_utc']!, _updatedUtcMeta),
      );
    }
    if (data.containsKey('self_link')) {
      context.handle(
        _selfLinkMeta,
        selfLink.isAcceptableOrUnknown(data['self_link']!, _selfLinkMeta),
      );
    }
    if (data.containsKey('parent')) {
      context.handle(
        _parentMeta,
        parent.isAcceptableOrUnknown(data['parent']!, _parentMeta),
      );
    }
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
      );
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('due_utc')) {
      context.handle(
        _dueUtcMeta,
        dueUtc.isAcceptableOrUnknown(data['due_utc']!, _dueUtcMeta),
      );
    }
    if (data.containsKey('completed_utc')) {
      context.handle(
        _completedUtcMeta,
        completedUtc.isAcceptableOrUnknown(
          data['completed_utc']!,
          _completedUtcMeta,
        ),
      );
    }
    if (data.containsKey('provider_status')) {
      context.handle(
        _providerStatusMeta,
        providerStatus.isAcceptableOrUnknown(
          data['provider_status']!,
          _providerStatusMeta,
        ),
      );
    }
    if (data.containsKey('body_content')) {
      context.handle(
        _bodyContentMeta,
        bodyContent.isAcceptableOrUnknown(
          data['body_content']!,
          _bodyContentMeta,
        ),
      );
    }
    if (data.containsKey('body_content_type')) {
      context.handle(
        _bodyContentTypeMeta,
        bodyContentType.isAcceptableOrUnknown(
          data['body_content_type']!,
          _bodyContentTypeMeta,
        ),
      );
    }
    if (data.containsKey('microsoft_due_date_time')) {
      context.handle(
        _microsoftDueDateTimeMeta,
        microsoftDueDateTime.isAcceptableOrUnknown(
          data['microsoft_due_date_time']!,
          _microsoftDueDateTimeMeta,
        ),
      );
    }
    if (data.containsKey('microsoft_due_time_zone')) {
      context.handle(
        _microsoftDueTimeZoneMeta,
        microsoftDueTimeZone.isAcceptableOrUnknown(
          data['microsoft_due_time_zone']!,
          _microsoftDueTimeZoneMeta,
        ),
      );
    }
    if (data.containsKey('microsoft_start_date_time')) {
      context.handle(
        _microsoftStartDateTimeMeta,
        microsoftStartDateTime.isAcceptableOrUnknown(
          data['microsoft_start_date_time']!,
          _microsoftStartDateTimeMeta,
        ),
      );
    }
    if (data.containsKey('microsoft_start_time_zone')) {
      context.handle(
        _microsoftStartTimeZoneMeta,
        microsoftStartTimeZone.isAcceptableOrUnknown(
          data['microsoft_start_time_zone']!,
          _microsoftStartTimeZoneMeta,
        ),
      );
    }
    if (data.containsKey('microsoft_reminder_date_time')) {
      context.handle(
        _microsoftReminderDateTimeMeta,
        microsoftReminderDateTime.isAcceptableOrUnknown(
          data['microsoft_reminder_date_time']!,
          _microsoftReminderDateTimeMeta,
        ),
      );
    }
    if (data.containsKey('microsoft_reminder_time_zone')) {
      context.handle(
        _microsoftReminderTimeZoneMeta,
        microsoftReminderTimeZone.isAcceptableOrUnknown(
          data['microsoft_reminder_time_zone']!,
          _microsoftReminderTimeZoneMeta,
        ),
      );
    }
    if (data.containsKey('microsoft_is_reminder_on')) {
      context.handle(
        _microsoftIsReminderOnMeta,
        microsoftIsReminderOn.isAcceptableOrUnknown(
          data['microsoft_is_reminder_on']!,
          _microsoftIsReminderOnMeta,
        ),
      );
    }
    if (data.containsKey('microsoft_completed_date_time')) {
      context.handle(
        _microsoftCompletedDateTimeMeta,
        microsoftCompletedDateTime.isAcceptableOrUnknown(
          data['microsoft_completed_date_time']!,
          _microsoftCompletedDateTimeMeta,
        ),
      );
    }
    if (data.containsKey('microsoft_completed_time_zone')) {
      context.handle(
        _microsoftCompletedTimeZoneMeta,
        microsoftCompletedTimeZone.isAcceptableOrUnknown(
          data['microsoft_completed_time_zone']!,
          _microsoftCompletedTimeZoneMeta,
        ),
      );
    }
    if (data.containsKey('recurrence_json')) {
      context.handle(
        _recurrenceJsonMeta,
        recurrenceJson.isAcceptableOrUnknown(
          data['recurrence_json']!,
          _recurrenceJsonMeta,
        ),
      );
    }
    if (data.containsKey('importance')) {
      context.handle(
        _importanceMeta,
        importance.isAcceptableOrUnknown(data['importance']!, _importanceMeta),
      );
    }
    if (data.containsKey('categories_json')) {
      context.handle(
        _categoriesJsonMeta,
        categoriesJson.isAcceptableOrUnknown(
          data['categories_json']!,
          _categoriesJsonMeta,
        ),
      );
    }
    if (data.containsKey('has_attachments')) {
      context.handle(
        _hasAttachmentsMeta,
        hasAttachments.isAcceptableOrUnknown(
          data['has_attachments']!,
          _hasAttachmentsMeta,
        ),
      );
    }
    if (data.containsKey('provider_metadata_json')) {
      context.handle(
        _providerMetadataJsonMeta,
        providerMetadataJson.isAcceptableOrUnknown(
          data['provider_metadata_json']!,
          _providerMetadataJsonMeta,
        ),
      );
    }
    if (data.containsKey('deleted')) {
      context.handle(
        _deletedMeta,
        deleted.isAcceptableOrUnknown(data['deleted']!, _deletedMeta),
      );
    }
    if (data.containsKey('hidden')) {
      context.handle(
        _hiddenMeta,
        hidden.isAcceptableOrUnknown(data['hidden']!, _hiddenMeta),
      );
    }
    if (data.containsKey('links_json')) {
      context.handle(
        _linksJsonMeta,
        linksJson.isAcceptableOrUnknown(data['links_json']!, _linksJsonMeta),
      );
    }
    if (data.containsKey('web_view_link')) {
      context.handle(
        _webViewLinkMeta,
        webViewLink.isAcceptableOrUnknown(
          data['web_view_link']!,
          _webViewLinkMeta,
        ),
      );
    }
    if (data.containsKey('assignment_info_json')) {
      context.handle(
        _assignmentInfoJsonMeta,
        assignmentInfoJson.isAcceptableOrUnknown(
          data['assignment_info_json']!,
          _assignmentInfoJsonMeta,
        ),
      );
    }
    if (data.containsKey('raw_json')) {
      context.handle(
        _rawJsonMeta,
        rawJson.isAcceptableOrUnknown(data['raw_json']!, _rawJsonMeta),
      );
    } else if (isInserting) {
      context.missing(_rawJsonMeta);
    }
    if (data.containsKey('server_missing')) {
      context.handle(
        _serverMissingMeta,
        serverMissing.isAcceptableOrUnknown(
          data['server_missing']!,
          _serverMissingMeta,
        ),
      );
    }
    if (data.containsKey('local_dirty')) {
      context.handle(
        _localDirtyMeta,
        localDirty.isAcceptableOrUnknown(data['local_dirty']!, _localDirtyMeta),
      );
    }
    if (data.containsKey('pending_delete')) {
      context.handle(
        _pendingDeleteMeta,
        pendingDelete.isAcceptableOrUnknown(
          data['pending_delete']!,
          _pendingDeleteMeta,
        ),
      );
    }
    if (data.containsKey('pending_move')) {
      context.handle(
        _pendingMoveMeta,
        pendingMove.isAcceptableOrUnknown(
          data['pending_move']!,
          _pendingMoveMeta,
        ),
      );
    }
    if (data.containsKey('local_created')) {
      context.handle(
        _localCreatedMeta,
        localCreated.isAcceptableOrUnknown(
          data['local_created']!,
          _localCreatedMeta,
        ),
      );
    }
    if (data.containsKey('sync_base_updated_utc')) {
      context.handle(
        _syncBaseUpdatedUtcMeta,
        syncBaseUpdatedUtc.isAcceptableOrUnknown(
          data['sync_base_updated_utc']!,
          _syncBaseUpdatedUtcMeta,
        ),
      );
    }
    if (data.containsKey('last_synced_at_utc')) {
      context.handle(
        _lastSyncedAtUtcMeta,
        lastSyncedAtUtc.isAcceptableOrUnknown(
          data['last_synced_at_utc']!,
          _lastSyncedAtUtcMeta,
        ),
      );
    }
    if (data.containsKey('created_local_at_utc')) {
      context.handle(
        _createdLocalAtUtcMeta,
        createdLocalAtUtc.isAcceptableOrUnknown(
          data['created_local_at_utc']!,
          _createdLocalAtUtcMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_createdLocalAtUtcMeta);
    }
    if (data.containsKey('updated_local_at_utc')) {
      context.handle(
        _updatedLocalAtUtcMeta,
        updatedLocalAtUtc.isAcceptableOrUnknown(
          data['updated_local_at_utc']!,
          _updatedLocalAtUtcMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_updatedLocalAtUtcMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {accountId, taskListId, id};
  @override
  Task map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Task(
      accountId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}account_id'],
      )!,
      taskListId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}task_list_id'],
      )!,
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      ),
      etag: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}etag'],
      ),
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      updatedUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}updated_utc'],
      ),
      selfLink: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}self_link'],
      ),
      parent: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}parent'],
      ),
      position: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}position'],
      ),
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      ),
      dueUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}due_utc'],
      ),
      completedUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}completed_utc'],
      ),
      providerStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}provider_status'],
      ),
      bodyContent: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}body_content'],
      ),
      bodyContentType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}body_content_type'],
      ),
      microsoftDueDateTime: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}microsoft_due_date_time'],
      ),
      microsoftDueTimeZone: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}microsoft_due_time_zone'],
      ),
      microsoftStartDateTime: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}microsoft_start_date_time'],
      ),
      microsoftStartTimeZone: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}microsoft_start_time_zone'],
      ),
      microsoftReminderDateTime: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}microsoft_reminder_date_time'],
      ),
      microsoftReminderTimeZone: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}microsoft_reminder_time_zone'],
      ),
      microsoftIsReminderOn: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}microsoft_is_reminder_on'],
      ),
      microsoftCompletedDateTime: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}microsoft_completed_date_time'],
      ),
      microsoftCompletedTimeZone: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}microsoft_completed_time_zone'],
      ),
      recurrenceJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}recurrence_json'],
      ),
      importance: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}importance'],
      ),
      categoriesJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}categories_json'],
      ),
      hasAttachments: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}has_attachments'],
      ),
      providerMetadataJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}provider_metadata_json'],
      ),
      deleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}deleted'],
      ),
      hidden: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}hidden'],
      ),
      linksJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}links_json'],
      ),
      webViewLink: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}web_view_link'],
      ),
      assignmentInfoJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}assignment_info_json'],
      ),
      rawJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}raw_json'],
      )!,
      serverMissing: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}server_missing'],
      )!,
      localDirty: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}local_dirty'],
      )!,
      pendingDelete: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}pending_delete'],
      )!,
      pendingMove: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}pending_move'],
      )!,
      localCreated: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}local_created'],
      )!,
      syncBaseUpdatedUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sync_base_updated_utc'],
      ),
      lastSyncedAtUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_synced_at_utc'],
      ),
      createdLocalAtUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_local_at_utc'],
      )!,
      updatedLocalAtUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}updated_local_at_utc'],
      )!,
    );
  }

  @override
  $TasksTable createAlias(String alias) {
    return $TasksTable(attachedDatabase, alias);
  }
}

class Task extends DataClass implements Insertable<Task> {
  final String accountId;
  final String taskListId;
  final String id;
  final String? kind;
  final String? etag;
  final String title;
  final String? updatedUtc;
  final String? selfLink;
  final String? parent;
  final String? position;
  final String? notes;
  final String? status;
  final String? dueUtc;
  final String? completedUtc;
  final String? providerStatus;
  final String? bodyContent;
  final String? bodyContentType;
  final String? microsoftDueDateTime;
  final String? microsoftDueTimeZone;
  final String? microsoftStartDateTime;
  final String? microsoftStartTimeZone;
  final String? microsoftReminderDateTime;
  final String? microsoftReminderTimeZone;
  final bool? microsoftIsReminderOn;
  final String? microsoftCompletedDateTime;
  final String? microsoftCompletedTimeZone;
  final String? recurrenceJson;
  final String? importance;
  final String? categoriesJson;
  final bool? hasAttachments;
  final String? providerMetadataJson;
  final bool? deleted;
  final bool? hidden;
  final String? linksJson;
  final String? webViewLink;
  final String? assignmentInfoJson;
  final String rawJson;
  final bool serverMissing;
  final bool localDirty;
  final bool pendingDelete;
  final bool pendingMove;
  final bool localCreated;
  final String? syncBaseUpdatedUtc;
  final String? lastSyncedAtUtc;
  final String createdLocalAtUtc;
  final String updatedLocalAtUtc;
  const Task({
    required this.accountId,
    required this.taskListId,
    required this.id,
    this.kind,
    this.etag,
    required this.title,
    this.updatedUtc,
    this.selfLink,
    this.parent,
    this.position,
    this.notes,
    this.status,
    this.dueUtc,
    this.completedUtc,
    this.providerStatus,
    this.bodyContent,
    this.bodyContentType,
    this.microsoftDueDateTime,
    this.microsoftDueTimeZone,
    this.microsoftStartDateTime,
    this.microsoftStartTimeZone,
    this.microsoftReminderDateTime,
    this.microsoftReminderTimeZone,
    this.microsoftIsReminderOn,
    this.microsoftCompletedDateTime,
    this.microsoftCompletedTimeZone,
    this.recurrenceJson,
    this.importance,
    this.categoriesJson,
    this.hasAttachments,
    this.providerMetadataJson,
    this.deleted,
    this.hidden,
    this.linksJson,
    this.webViewLink,
    this.assignmentInfoJson,
    required this.rawJson,
    required this.serverMissing,
    required this.localDirty,
    required this.pendingDelete,
    required this.pendingMove,
    required this.localCreated,
    this.syncBaseUpdatedUtc,
    this.lastSyncedAtUtc,
    required this.createdLocalAtUtc,
    required this.updatedLocalAtUtc,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['account_id'] = Variable<String>(accountId);
    map['task_list_id'] = Variable<String>(taskListId);
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || kind != null) {
      map['kind'] = Variable<String>(kind);
    }
    if (!nullToAbsent || etag != null) {
      map['etag'] = Variable<String>(etag);
    }
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || updatedUtc != null) {
      map['updated_utc'] = Variable<String>(updatedUtc);
    }
    if (!nullToAbsent || selfLink != null) {
      map['self_link'] = Variable<String>(selfLink);
    }
    if (!nullToAbsent || parent != null) {
      map['parent'] = Variable<String>(parent);
    }
    if (!nullToAbsent || position != null) {
      map['position'] = Variable<String>(position);
    }
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    if (!nullToAbsent || status != null) {
      map['status'] = Variable<String>(status);
    }
    if (!nullToAbsent || dueUtc != null) {
      map['due_utc'] = Variable<String>(dueUtc);
    }
    if (!nullToAbsent || completedUtc != null) {
      map['completed_utc'] = Variable<String>(completedUtc);
    }
    if (!nullToAbsent || providerStatus != null) {
      map['provider_status'] = Variable<String>(providerStatus);
    }
    if (!nullToAbsent || bodyContent != null) {
      map['body_content'] = Variable<String>(bodyContent);
    }
    if (!nullToAbsent || bodyContentType != null) {
      map['body_content_type'] = Variable<String>(bodyContentType);
    }
    if (!nullToAbsent || microsoftDueDateTime != null) {
      map['microsoft_due_date_time'] = Variable<String>(microsoftDueDateTime);
    }
    if (!nullToAbsent || microsoftDueTimeZone != null) {
      map['microsoft_due_time_zone'] = Variable<String>(microsoftDueTimeZone);
    }
    if (!nullToAbsent || microsoftStartDateTime != null) {
      map['microsoft_start_date_time'] = Variable<String>(
        microsoftStartDateTime,
      );
    }
    if (!nullToAbsent || microsoftStartTimeZone != null) {
      map['microsoft_start_time_zone'] = Variable<String>(
        microsoftStartTimeZone,
      );
    }
    if (!nullToAbsent || microsoftReminderDateTime != null) {
      map['microsoft_reminder_date_time'] = Variable<String>(
        microsoftReminderDateTime,
      );
    }
    if (!nullToAbsent || microsoftReminderTimeZone != null) {
      map['microsoft_reminder_time_zone'] = Variable<String>(
        microsoftReminderTimeZone,
      );
    }
    if (!nullToAbsent || microsoftIsReminderOn != null) {
      map['microsoft_is_reminder_on'] = Variable<bool>(microsoftIsReminderOn);
    }
    if (!nullToAbsent || microsoftCompletedDateTime != null) {
      map['microsoft_completed_date_time'] = Variable<String>(
        microsoftCompletedDateTime,
      );
    }
    if (!nullToAbsent || microsoftCompletedTimeZone != null) {
      map['microsoft_completed_time_zone'] = Variable<String>(
        microsoftCompletedTimeZone,
      );
    }
    if (!nullToAbsent || recurrenceJson != null) {
      map['recurrence_json'] = Variable<String>(recurrenceJson);
    }
    if (!nullToAbsent || importance != null) {
      map['importance'] = Variable<String>(importance);
    }
    if (!nullToAbsent || categoriesJson != null) {
      map['categories_json'] = Variable<String>(categoriesJson);
    }
    if (!nullToAbsent || hasAttachments != null) {
      map['has_attachments'] = Variable<bool>(hasAttachments);
    }
    if (!nullToAbsent || providerMetadataJson != null) {
      map['provider_metadata_json'] = Variable<String>(providerMetadataJson);
    }
    if (!nullToAbsent || deleted != null) {
      map['deleted'] = Variable<bool>(deleted);
    }
    if (!nullToAbsent || hidden != null) {
      map['hidden'] = Variable<bool>(hidden);
    }
    if (!nullToAbsent || linksJson != null) {
      map['links_json'] = Variable<String>(linksJson);
    }
    if (!nullToAbsent || webViewLink != null) {
      map['web_view_link'] = Variable<String>(webViewLink);
    }
    if (!nullToAbsent || assignmentInfoJson != null) {
      map['assignment_info_json'] = Variable<String>(assignmentInfoJson);
    }
    map['raw_json'] = Variable<String>(rawJson);
    map['server_missing'] = Variable<bool>(serverMissing);
    map['local_dirty'] = Variable<bool>(localDirty);
    map['pending_delete'] = Variable<bool>(pendingDelete);
    map['pending_move'] = Variable<bool>(pendingMove);
    map['local_created'] = Variable<bool>(localCreated);
    if (!nullToAbsent || syncBaseUpdatedUtc != null) {
      map['sync_base_updated_utc'] = Variable<String>(syncBaseUpdatedUtc);
    }
    if (!nullToAbsent || lastSyncedAtUtc != null) {
      map['last_synced_at_utc'] = Variable<String>(lastSyncedAtUtc);
    }
    map['created_local_at_utc'] = Variable<String>(createdLocalAtUtc);
    map['updated_local_at_utc'] = Variable<String>(updatedLocalAtUtc);
    return map;
  }

  TasksCompanion toCompanion(bool nullToAbsent) {
    return TasksCompanion(
      accountId: Value(accountId),
      taskListId: Value(taskListId),
      id: Value(id),
      kind: kind == null && nullToAbsent ? const Value.absent() : Value(kind),
      etag: etag == null && nullToAbsent ? const Value.absent() : Value(etag),
      title: Value(title),
      updatedUtc: updatedUtc == null && nullToAbsent
          ? const Value.absent()
          : Value(updatedUtc),
      selfLink: selfLink == null && nullToAbsent
          ? const Value.absent()
          : Value(selfLink),
      parent: parent == null && nullToAbsent
          ? const Value.absent()
          : Value(parent),
      position: position == null && nullToAbsent
          ? const Value.absent()
          : Value(position),
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
      status: status == null && nullToAbsent
          ? const Value.absent()
          : Value(status),
      dueUtc: dueUtc == null && nullToAbsent
          ? const Value.absent()
          : Value(dueUtc),
      completedUtc: completedUtc == null && nullToAbsent
          ? const Value.absent()
          : Value(completedUtc),
      providerStatus: providerStatus == null && nullToAbsent
          ? const Value.absent()
          : Value(providerStatus),
      bodyContent: bodyContent == null && nullToAbsent
          ? const Value.absent()
          : Value(bodyContent),
      bodyContentType: bodyContentType == null && nullToAbsent
          ? const Value.absent()
          : Value(bodyContentType),
      microsoftDueDateTime: microsoftDueDateTime == null && nullToAbsent
          ? const Value.absent()
          : Value(microsoftDueDateTime),
      microsoftDueTimeZone: microsoftDueTimeZone == null && nullToAbsent
          ? const Value.absent()
          : Value(microsoftDueTimeZone),
      microsoftStartDateTime: microsoftStartDateTime == null && nullToAbsent
          ? const Value.absent()
          : Value(microsoftStartDateTime),
      microsoftStartTimeZone: microsoftStartTimeZone == null && nullToAbsent
          ? const Value.absent()
          : Value(microsoftStartTimeZone),
      microsoftReminderDateTime:
          microsoftReminderDateTime == null && nullToAbsent
          ? const Value.absent()
          : Value(microsoftReminderDateTime),
      microsoftReminderTimeZone:
          microsoftReminderTimeZone == null && nullToAbsent
          ? const Value.absent()
          : Value(microsoftReminderTimeZone),
      microsoftIsReminderOn: microsoftIsReminderOn == null && nullToAbsent
          ? const Value.absent()
          : Value(microsoftIsReminderOn),
      microsoftCompletedDateTime:
          microsoftCompletedDateTime == null && nullToAbsent
          ? const Value.absent()
          : Value(microsoftCompletedDateTime),
      microsoftCompletedTimeZone:
          microsoftCompletedTimeZone == null && nullToAbsent
          ? const Value.absent()
          : Value(microsoftCompletedTimeZone),
      recurrenceJson: recurrenceJson == null && nullToAbsent
          ? const Value.absent()
          : Value(recurrenceJson),
      importance: importance == null && nullToAbsent
          ? const Value.absent()
          : Value(importance),
      categoriesJson: categoriesJson == null && nullToAbsent
          ? const Value.absent()
          : Value(categoriesJson),
      hasAttachments: hasAttachments == null && nullToAbsent
          ? const Value.absent()
          : Value(hasAttachments),
      providerMetadataJson: providerMetadataJson == null && nullToAbsent
          ? const Value.absent()
          : Value(providerMetadataJson),
      deleted: deleted == null && nullToAbsent
          ? const Value.absent()
          : Value(deleted),
      hidden: hidden == null && nullToAbsent
          ? const Value.absent()
          : Value(hidden),
      linksJson: linksJson == null && nullToAbsent
          ? const Value.absent()
          : Value(linksJson),
      webViewLink: webViewLink == null && nullToAbsent
          ? const Value.absent()
          : Value(webViewLink),
      assignmentInfoJson: assignmentInfoJson == null && nullToAbsent
          ? const Value.absent()
          : Value(assignmentInfoJson),
      rawJson: Value(rawJson),
      serverMissing: Value(serverMissing),
      localDirty: Value(localDirty),
      pendingDelete: Value(pendingDelete),
      pendingMove: Value(pendingMove),
      localCreated: Value(localCreated),
      syncBaseUpdatedUtc: syncBaseUpdatedUtc == null && nullToAbsent
          ? const Value.absent()
          : Value(syncBaseUpdatedUtc),
      lastSyncedAtUtc: lastSyncedAtUtc == null && nullToAbsent
          ? const Value.absent()
          : Value(lastSyncedAtUtc),
      createdLocalAtUtc: Value(createdLocalAtUtc),
      updatedLocalAtUtc: Value(updatedLocalAtUtc),
    );
  }

  factory Task.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Task(
      accountId: serializer.fromJson<String>(json['accountId']),
      taskListId: serializer.fromJson<String>(json['taskListId']),
      id: serializer.fromJson<String>(json['id']),
      kind: serializer.fromJson<String?>(json['kind']),
      etag: serializer.fromJson<String?>(json['etag']),
      title: serializer.fromJson<String>(json['title']),
      updatedUtc: serializer.fromJson<String?>(json['updatedUtc']),
      selfLink: serializer.fromJson<String?>(json['selfLink']),
      parent: serializer.fromJson<String?>(json['parent']),
      position: serializer.fromJson<String?>(json['position']),
      notes: serializer.fromJson<String?>(json['notes']),
      status: serializer.fromJson<String?>(json['status']),
      dueUtc: serializer.fromJson<String?>(json['dueUtc']),
      completedUtc: serializer.fromJson<String?>(json['completedUtc']),
      providerStatus: serializer.fromJson<String?>(json['providerStatus']),
      bodyContent: serializer.fromJson<String?>(json['bodyContent']),
      bodyContentType: serializer.fromJson<String?>(json['bodyContentType']),
      microsoftDueDateTime: serializer.fromJson<String?>(
        json['microsoftDueDateTime'],
      ),
      microsoftDueTimeZone: serializer.fromJson<String?>(
        json['microsoftDueTimeZone'],
      ),
      microsoftStartDateTime: serializer.fromJson<String?>(
        json['microsoftStartDateTime'],
      ),
      microsoftStartTimeZone: serializer.fromJson<String?>(
        json['microsoftStartTimeZone'],
      ),
      microsoftReminderDateTime: serializer.fromJson<String?>(
        json['microsoftReminderDateTime'],
      ),
      microsoftReminderTimeZone: serializer.fromJson<String?>(
        json['microsoftReminderTimeZone'],
      ),
      microsoftIsReminderOn: serializer.fromJson<bool?>(
        json['microsoftIsReminderOn'],
      ),
      microsoftCompletedDateTime: serializer.fromJson<String?>(
        json['microsoftCompletedDateTime'],
      ),
      microsoftCompletedTimeZone: serializer.fromJson<String?>(
        json['microsoftCompletedTimeZone'],
      ),
      recurrenceJson: serializer.fromJson<String?>(json['recurrenceJson']),
      importance: serializer.fromJson<String?>(json['importance']),
      categoriesJson: serializer.fromJson<String?>(json['categoriesJson']),
      hasAttachments: serializer.fromJson<bool?>(json['hasAttachments']),
      providerMetadataJson: serializer.fromJson<String?>(
        json['providerMetadataJson'],
      ),
      deleted: serializer.fromJson<bool?>(json['deleted']),
      hidden: serializer.fromJson<bool?>(json['hidden']),
      linksJson: serializer.fromJson<String?>(json['linksJson']),
      webViewLink: serializer.fromJson<String?>(json['webViewLink']),
      assignmentInfoJson: serializer.fromJson<String?>(
        json['assignmentInfoJson'],
      ),
      rawJson: serializer.fromJson<String>(json['rawJson']),
      serverMissing: serializer.fromJson<bool>(json['serverMissing']),
      localDirty: serializer.fromJson<bool>(json['localDirty']),
      pendingDelete: serializer.fromJson<bool>(json['pendingDelete']),
      pendingMove: serializer.fromJson<bool>(json['pendingMove']),
      localCreated: serializer.fromJson<bool>(json['localCreated']),
      syncBaseUpdatedUtc: serializer.fromJson<String?>(
        json['syncBaseUpdatedUtc'],
      ),
      lastSyncedAtUtc: serializer.fromJson<String?>(json['lastSyncedAtUtc']),
      createdLocalAtUtc: serializer.fromJson<String>(json['createdLocalAtUtc']),
      updatedLocalAtUtc: serializer.fromJson<String>(json['updatedLocalAtUtc']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'accountId': serializer.toJson<String>(accountId),
      'taskListId': serializer.toJson<String>(taskListId),
      'id': serializer.toJson<String>(id),
      'kind': serializer.toJson<String?>(kind),
      'etag': serializer.toJson<String?>(etag),
      'title': serializer.toJson<String>(title),
      'updatedUtc': serializer.toJson<String?>(updatedUtc),
      'selfLink': serializer.toJson<String?>(selfLink),
      'parent': serializer.toJson<String?>(parent),
      'position': serializer.toJson<String?>(position),
      'notes': serializer.toJson<String?>(notes),
      'status': serializer.toJson<String?>(status),
      'dueUtc': serializer.toJson<String?>(dueUtc),
      'completedUtc': serializer.toJson<String?>(completedUtc),
      'providerStatus': serializer.toJson<String?>(providerStatus),
      'bodyContent': serializer.toJson<String?>(bodyContent),
      'bodyContentType': serializer.toJson<String?>(bodyContentType),
      'microsoftDueDateTime': serializer.toJson<String?>(microsoftDueDateTime),
      'microsoftDueTimeZone': serializer.toJson<String?>(microsoftDueTimeZone),
      'microsoftStartDateTime': serializer.toJson<String?>(
        microsoftStartDateTime,
      ),
      'microsoftStartTimeZone': serializer.toJson<String?>(
        microsoftStartTimeZone,
      ),
      'microsoftReminderDateTime': serializer.toJson<String?>(
        microsoftReminderDateTime,
      ),
      'microsoftReminderTimeZone': serializer.toJson<String?>(
        microsoftReminderTimeZone,
      ),
      'microsoftIsReminderOn': serializer.toJson<bool?>(microsoftIsReminderOn),
      'microsoftCompletedDateTime': serializer.toJson<String?>(
        microsoftCompletedDateTime,
      ),
      'microsoftCompletedTimeZone': serializer.toJson<String?>(
        microsoftCompletedTimeZone,
      ),
      'recurrenceJson': serializer.toJson<String?>(recurrenceJson),
      'importance': serializer.toJson<String?>(importance),
      'categoriesJson': serializer.toJson<String?>(categoriesJson),
      'hasAttachments': serializer.toJson<bool?>(hasAttachments),
      'providerMetadataJson': serializer.toJson<String?>(providerMetadataJson),
      'deleted': serializer.toJson<bool?>(deleted),
      'hidden': serializer.toJson<bool?>(hidden),
      'linksJson': serializer.toJson<String?>(linksJson),
      'webViewLink': serializer.toJson<String?>(webViewLink),
      'assignmentInfoJson': serializer.toJson<String?>(assignmentInfoJson),
      'rawJson': serializer.toJson<String>(rawJson),
      'serverMissing': serializer.toJson<bool>(serverMissing),
      'localDirty': serializer.toJson<bool>(localDirty),
      'pendingDelete': serializer.toJson<bool>(pendingDelete),
      'pendingMove': serializer.toJson<bool>(pendingMove),
      'localCreated': serializer.toJson<bool>(localCreated),
      'syncBaseUpdatedUtc': serializer.toJson<String?>(syncBaseUpdatedUtc),
      'lastSyncedAtUtc': serializer.toJson<String?>(lastSyncedAtUtc),
      'createdLocalAtUtc': serializer.toJson<String>(createdLocalAtUtc),
      'updatedLocalAtUtc': serializer.toJson<String>(updatedLocalAtUtc),
    };
  }

  Task copyWith({
    String? accountId,
    String? taskListId,
    String? id,
    Value<String?> kind = const Value.absent(),
    Value<String?> etag = const Value.absent(),
    String? title,
    Value<String?> updatedUtc = const Value.absent(),
    Value<String?> selfLink = const Value.absent(),
    Value<String?> parent = const Value.absent(),
    Value<String?> position = const Value.absent(),
    Value<String?> notes = const Value.absent(),
    Value<String?> status = const Value.absent(),
    Value<String?> dueUtc = const Value.absent(),
    Value<String?> completedUtc = const Value.absent(),
    Value<String?> providerStatus = const Value.absent(),
    Value<String?> bodyContent = const Value.absent(),
    Value<String?> bodyContentType = const Value.absent(),
    Value<String?> microsoftDueDateTime = const Value.absent(),
    Value<String?> microsoftDueTimeZone = const Value.absent(),
    Value<String?> microsoftStartDateTime = const Value.absent(),
    Value<String?> microsoftStartTimeZone = const Value.absent(),
    Value<String?> microsoftReminderDateTime = const Value.absent(),
    Value<String?> microsoftReminderTimeZone = const Value.absent(),
    Value<bool?> microsoftIsReminderOn = const Value.absent(),
    Value<String?> microsoftCompletedDateTime = const Value.absent(),
    Value<String?> microsoftCompletedTimeZone = const Value.absent(),
    Value<String?> recurrenceJson = const Value.absent(),
    Value<String?> importance = const Value.absent(),
    Value<String?> categoriesJson = const Value.absent(),
    Value<bool?> hasAttachments = const Value.absent(),
    Value<String?> providerMetadataJson = const Value.absent(),
    Value<bool?> deleted = const Value.absent(),
    Value<bool?> hidden = const Value.absent(),
    Value<String?> linksJson = const Value.absent(),
    Value<String?> webViewLink = const Value.absent(),
    Value<String?> assignmentInfoJson = const Value.absent(),
    String? rawJson,
    bool? serverMissing,
    bool? localDirty,
    bool? pendingDelete,
    bool? pendingMove,
    bool? localCreated,
    Value<String?> syncBaseUpdatedUtc = const Value.absent(),
    Value<String?> lastSyncedAtUtc = const Value.absent(),
    String? createdLocalAtUtc,
    String? updatedLocalAtUtc,
  }) => Task(
    accountId: accountId ?? this.accountId,
    taskListId: taskListId ?? this.taskListId,
    id: id ?? this.id,
    kind: kind.present ? kind.value : this.kind,
    etag: etag.present ? etag.value : this.etag,
    title: title ?? this.title,
    updatedUtc: updatedUtc.present ? updatedUtc.value : this.updatedUtc,
    selfLink: selfLink.present ? selfLink.value : this.selfLink,
    parent: parent.present ? parent.value : this.parent,
    position: position.present ? position.value : this.position,
    notes: notes.present ? notes.value : this.notes,
    status: status.present ? status.value : this.status,
    dueUtc: dueUtc.present ? dueUtc.value : this.dueUtc,
    completedUtc: completedUtc.present ? completedUtc.value : this.completedUtc,
    providerStatus: providerStatus.present
        ? providerStatus.value
        : this.providerStatus,
    bodyContent: bodyContent.present ? bodyContent.value : this.bodyContent,
    bodyContentType: bodyContentType.present
        ? bodyContentType.value
        : this.bodyContentType,
    microsoftDueDateTime: microsoftDueDateTime.present
        ? microsoftDueDateTime.value
        : this.microsoftDueDateTime,
    microsoftDueTimeZone: microsoftDueTimeZone.present
        ? microsoftDueTimeZone.value
        : this.microsoftDueTimeZone,
    microsoftStartDateTime: microsoftStartDateTime.present
        ? microsoftStartDateTime.value
        : this.microsoftStartDateTime,
    microsoftStartTimeZone: microsoftStartTimeZone.present
        ? microsoftStartTimeZone.value
        : this.microsoftStartTimeZone,
    microsoftReminderDateTime: microsoftReminderDateTime.present
        ? microsoftReminderDateTime.value
        : this.microsoftReminderDateTime,
    microsoftReminderTimeZone: microsoftReminderTimeZone.present
        ? microsoftReminderTimeZone.value
        : this.microsoftReminderTimeZone,
    microsoftIsReminderOn: microsoftIsReminderOn.present
        ? microsoftIsReminderOn.value
        : this.microsoftIsReminderOn,
    microsoftCompletedDateTime: microsoftCompletedDateTime.present
        ? microsoftCompletedDateTime.value
        : this.microsoftCompletedDateTime,
    microsoftCompletedTimeZone: microsoftCompletedTimeZone.present
        ? microsoftCompletedTimeZone.value
        : this.microsoftCompletedTimeZone,
    recurrenceJson: recurrenceJson.present
        ? recurrenceJson.value
        : this.recurrenceJson,
    importance: importance.present ? importance.value : this.importance,
    categoriesJson: categoriesJson.present
        ? categoriesJson.value
        : this.categoriesJson,
    hasAttachments: hasAttachments.present
        ? hasAttachments.value
        : this.hasAttachments,
    providerMetadataJson: providerMetadataJson.present
        ? providerMetadataJson.value
        : this.providerMetadataJson,
    deleted: deleted.present ? deleted.value : this.deleted,
    hidden: hidden.present ? hidden.value : this.hidden,
    linksJson: linksJson.present ? linksJson.value : this.linksJson,
    webViewLink: webViewLink.present ? webViewLink.value : this.webViewLink,
    assignmentInfoJson: assignmentInfoJson.present
        ? assignmentInfoJson.value
        : this.assignmentInfoJson,
    rawJson: rawJson ?? this.rawJson,
    serverMissing: serverMissing ?? this.serverMissing,
    localDirty: localDirty ?? this.localDirty,
    pendingDelete: pendingDelete ?? this.pendingDelete,
    pendingMove: pendingMove ?? this.pendingMove,
    localCreated: localCreated ?? this.localCreated,
    syncBaseUpdatedUtc: syncBaseUpdatedUtc.present
        ? syncBaseUpdatedUtc.value
        : this.syncBaseUpdatedUtc,
    lastSyncedAtUtc: lastSyncedAtUtc.present
        ? lastSyncedAtUtc.value
        : this.lastSyncedAtUtc,
    createdLocalAtUtc: createdLocalAtUtc ?? this.createdLocalAtUtc,
    updatedLocalAtUtc: updatedLocalAtUtc ?? this.updatedLocalAtUtc,
  );
  Task copyWithCompanion(TasksCompanion data) {
    return Task(
      accountId: data.accountId.present ? data.accountId.value : this.accountId,
      taskListId: data.taskListId.present
          ? data.taskListId.value
          : this.taskListId,
      id: data.id.present ? data.id.value : this.id,
      kind: data.kind.present ? data.kind.value : this.kind,
      etag: data.etag.present ? data.etag.value : this.etag,
      title: data.title.present ? data.title.value : this.title,
      updatedUtc: data.updatedUtc.present
          ? data.updatedUtc.value
          : this.updatedUtc,
      selfLink: data.selfLink.present ? data.selfLink.value : this.selfLink,
      parent: data.parent.present ? data.parent.value : this.parent,
      position: data.position.present ? data.position.value : this.position,
      notes: data.notes.present ? data.notes.value : this.notes,
      status: data.status.present ? data.status.value : this.status,
      dueUtc: data.dueUtc.present ? data.dueUtc.value : this.dueUtc,
      completedUtc: data.completedUtc.present
          ? data.completedUtc.value
          : this.completedUtc,
      providerStatus: data.providerStatus.present
          ? data.providerStatus.value
          : this.providerStatus,
      bodyContent: data.bodyContent.present
          ? data.bodyContent.value
          : this.bodyContent,
      bodyContentType: data.bodyContentType.present
          ? data.bodyContentType.value
          : this.bodyContentType,
      microsoftDueDateTime: data.microsoftDueDateTime.present
          ? data.microsoftDueDateTime.value
          : this.microsoftDueDateTime,
      microsoftDueTimeZone: data.microsoftDueTimeZone.present
          ? data.microsoftDueTimeZone.value
          : this.microsoftDueTimeZone,
      microsoftStartDateTime: data.microsoftStartDateTime.present
          ? data.microsoftStartDateTime.value
          : this.microsoftStartDateTime,
      microsoftStartTimeZone: data.microsoftStartTimeZone.present
          ? data.microsoftStartTimeZone.value
          : this.microsoftStartTimeZone,
      microsoftReminderDateTime: data.microsoftReminderDateTime.present
          ? data.microsoftReminderDateTime.value
          : this.microsoftReminderDateTime,
      microsoftReminderTimeZone: data.microsoftReminderTimeZone.present
          ? data.microsoftReminderTimeZone.value
          : this.microsoftReminderTimeZone,
      microsoftIsReminderOn: data.microsoftIsReminderOn.present
          ? data.microsoftIsReminderOn.value
          : this.microsoftIsReminderOn,
      microsoftCompletedDateTime: data.microsoftCompletedDateTime.present
          ? data.microsoftCompletedDateTime.value
          : this.microsoftCompletedDateTime,
      microsoftCompletedTimeZone: data.microsoftCompletedTimeZone.present
          ? data.microsoftCompletedTimeZone.value
          : this.microsoftCompletedTimeZone,
      recurrenceJson: data.recurrenceJson.present
          ? data.recurrenceJson.value
          : this.recurrenceJson,
      importance: data.importance.present
          ? data.importance.value
          : this.importance,
      categoriesJson: data.categoriesJson.present
          ? data.categoriesJson.value
          : this.categoriesJson,
      hasAttachments: data.hasAttachments.present
          ? data.hasAttachments.value
          : this.hasAttachments,
      providerMetadataJson: data.providerMetadataJson.present
          ? data.providerMetadataJson.value
          : this.providerMetadataJson,
      deleted: data.deleted.present ? data.deleted.value : this.deleted,
      hidden: data.hidden.present ? data.hidden.value : this.hidden,
      linksJson: data.linksJson.present ? data.linksJson.value : this.linksJson,
      webViewLink: data.webViewLink.present
          ? data.webViewLink.value
          : this.webViewLink,
      assignmentInfoJson: data.assignmentInfoJson.present
          ? data.assignmentInfoJson.value
          : this.assignmentInfoJson,
      rawJson: data.rawJson.present ? data.rawJson.value : this.rawJson,
      serverMissing: data.serverMissing.present
          ? data.serverMissing.value
          : this.serverMissing,
      localDirty: data.localDirty.present
          ? data.localDirty.value
          : this.localDirty,
      pendingDelete: data.pendingDelete.present
          ? data.pendingDelete.value
          : this.pendingDelete,
      pendingMove: data.pendingMove.present
          ? data.pendingMove.value
          : this.pendingMove,
      localCreated: data.localCreated.present
          ? data.localCreated.value
          : this.localCreated,
      syncBaseUpdatedUtc: data.syncBaseUpdatedUtc.present
          ? data.syncBaseUpdatedUtc.value
          : this.syncBaseUpdatedUtc,
      lastSyncedAtUtc: data.lastSyncedAtUtc.present
          ? data.lastSyncedAtUtc.value
          : this.lastSyncedAtUtc,
      createdLocalAtUtc: data.createdLocalAtUtc.present
          ? data.createdLocalAtUtc.value
          : this.createdLocalAtUtc,
      updatedLocalAtUtc: data.updatedLocalAtUtc.present
          ? data.updatedLocalAtUtc.value
          : this.updatedLocalAtUtc,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Task(')
          ..write('accountId: $accountId, ')
          ..write('taskListId: $taskListId, ')
          ..write('id: $id, ')
          ..write('kind: $kind, ')
          ..write('etag: $etag, ')
          ..write('title: $title, ')
          ..write('updatedUtc: $updatedUtc, ')
          ..write('selfLink: $selfLink, ')
          ..write('parent: $parent, ')
          ..write('position: $position, ')
          ..write('notes: $notes, ')
          ..write('status: $status, ')
          ..write('dueUtc: $dueUtc, ')
          ..write('completedUtc: $completedUtc, ')
          ..write('providerStatus: $providerStatus, ')
          ..write('bodyContent: $bodyContent, ')
          ..write('bodyContentType: $bodyContentType, ')
          ..write('microsoftDueDateTime: $microsoftDueDateTime, ')
          ..write('microsoftDueTimeZone: $microsoftDueTimeZone, ')
          ..write('microsoftStartDateTime: $microsoftStartDateTime, ')
          ..write('microsoftStartTimeZone: $microsoftStartTimeZone, ')
          ..write('microsoftReminderDateTime: $microsoftReminderDateTime, ')
          ..write('microsoftReminderTimeZone: $microsoftReminderTimeZone, ')
          ..write('microsoftIsReminderOn: $microsoftIsReminderOn, ')
          ..write('microsoftCompletedDateTime: $microsoftCompletedDateTime, ')
          ..write('microsoftCompletedTimeZone: $microsoftCompletedTimeZone, ')
          ..write('recurrenceJson: $recurrenceJson, ')
          ..write('importance: $importance, ')
          ..write('categoriesJson: $categoriesJson, ')
          ..write('hasAttachments: $hasAttachments, ')
          ..write('providerMetadataJson: $providerMetadataJson, ')
          ..write('deleted: $deleted, ')
          ..write('hidden: $hidden, ')
          ..write('linksJson: $linksJson, ')
          ..write('webViewLink: $webViewLink, ')
          ..write('assignmentInfoJson: $assignmentInfoJson, ')
          ..write('rawJson: $rawJson, ')
          ..write('serverMissing: $serverMissing, ')
          ..write('localDirty: $localDirty, ')
          ..write('pendingDelete: $pendingDelete, ')
          ..write('pendingMove: $pendingMove, ')
          ..write('localCreated: $localCreated, ')
          ..write('syncBaseUpdatedUtc: $syncBaseUpdatedUtc, ')
          ..write('lastSyncedAtUtc: $lastSyncedAtUtc, ')
          ..write('createdLocalAtUtc: $createdLocalAtUtc, ')
          ..write('updatedLocalAtUtc: $updatedLocalAtUtc')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    accountId,
    taskListId,
    id,
    kind,
    etag,
    title,
    updatedUtc,
    selfLink,
    parent,
    position,
    notes,
    status,
    dueUtc,
    completedUtc,
    providerStatus,
    bodyContent,
    bodyContentType,
    microsoftDueDateTime,
    microsoftDueTimeZone,
    microsoftStartDateTime,
    microsoftStartTimeZone,
    microsoftReminderDateTime,
    microsoftReminderTimeZone,
    microsoftIsReminderOn,
    microsoftCompletedDateTime,
    microsoftCompletedTimeZone,
    recurrenceJson,
    importance,
    categoriesJson,
    hasAttachments,
    providerMetadataJson,
    deleted,
    hidden,
    linksJson,
    webViewLink,
    assignmentInfoJson,
    rawJson,
    serverMissing,
    localDirty,
    pendingDelete,
    pendingMove,
    localCreated,
    syncBaseUpdatedUtc,
    lastSyncedAtUtc,
    createdLocalAtUtc,
    updatedLocalAtUtc,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Task &&
          other.accountId == this.accountId &&
          other.taskListId == this.taskListId &&
          other.id == this.id &&
          other.kind == this.kind &&
          other.etag == this.etag &&
          other.title == this.title &&
          other.updatedUtc == this.updatedUtc &&
          other.selfLink == this.selfLink &&
          other.parent == this.parent &&
          other.position == this.position &&
          other.notes == this.notes &&
          other.status == this.status &&
          other.dueUtc == this.dueUtc &&
          other.completedUtc == this.completedUtc &&
          other.providerStatus == this.providerStatus &&
          other.bodyContent == this.bodyContent &&
          other.bodyContentType == this.bodyContentType &&
          other.microsoftDueDateTime == this.microsoftDueDateTime &&
          other.microsoftDueTimeZone == this.microsoftDueTimeZone &&
          other.microsoftStartDateTime == this.microsoftStartDateTime &&
          other.microsoftStartTimeZone == this.microsoftStartTimeZone &&
          other.microsoftReminderDateTime == this.microsoftReminderDateTime &&
          other.microsoftReminderTimeZone == this.microsoftReminderTimeZone &&
          other.microsoftIsReminderOn == this.microsoftIsReminderOn &&
          other.microsoftCompletedDateTime == this.microsoftCompletedDateTime &&
          other.microsoftCompletedTimeZone == this.microsoftCompletedTimeZone &&
          other.recurrenceJson == this.recurrenceJson &&
          other.importance == this.importance &&
          other.categoriesJson == this.categoriesJson &&
          other.hasAttachments == this.hasAttachments &&
          other.providerMetadataJson == this.providerMetadataJson &&
          other.deleted == this.deleted &&
          other.hidden == this.hidden &&
          other.linksJson == this.linksJson &&
          other.webViewLink == this.webViewLink &&
          other.assignmentInfoJson == this.assignmentInfoJson &&
          other.rawJson == this.rawJson &&
          other.serverMissing == this.serverMissing &&
          other.localDirty == this.localDirty &&
          other.pendingDelete == this.pendingDelete &&
          other.pendingMove == this.pendingMove &&
          other.localCreated == this.localCreated &&
          other.syncBaseUpdatedUtc == this.syncBaseUpdatedUtc &&
          other.lastSyncedAtUtc == this.lastSyncedAtUtc &&
          other.createdLocalAtUtc == this.createdLocalAtUtc &&
          other.updatedLocalAtUtc == this.updatedLocalAtUtc);
}

class TasksCompanion extends UpdateCompanion<Task> {
  final Value<String> accountId;
  final Value<String> taskListId;
  final Value<String> id;
  final Value<String?> kind;
  final Value<String?> etag;
  final Value<String> title;
  final Value<String?> updatedUtc;
  final Value<String?> selfLink;
  final Value<String?> parent;
  final Value<String?> position;
  final Value<String?> notes;
  final Value<String?> status;
  final Value<String?> dueUtc;
  final Value<String?> completedUtc;
  final Value<String?> providerStatus;
  final Value<String?> bodyContent;
  final Value<String?> bodyContentType;
  final Value<String?> microsoftDueDateTime;
  final Value<String?> microsoftDueTimeZone;
  final Value<String?> microsoftStartDateTime;
  final Value<String?> microsoftStartTimeZone;
  final Value<String?> microsoftReminderDateTime;
  final Value<String?> microsoftReminderTimeZone;
  final Value<bool?> microsoftIsReminderOn;
  final Value<String?> microsoftCompletedDateTime;
  final Value<String?> microsoftCompletedTimeZone;
  final Value<String?> recurrenceJson;
  final Value<String?> importance;
  final Value<String?> categoriesJson;
  final Value<bool?> hasAttachments;
  final Value<String?> providerMetadataJson;
  final Value<bool?> deleted;
  final Value<bool?> hidden;
  final Value<String?> linksJson;
  final Value<String?> webViewLink;
  final Value<String?> assignmentInfoJson;
  final Value<String> rawJson;
  final Value<bool> serverMissing;
  final Value<bool> localDirty;
  final Value<bool> pendingDelete;
  final Value<bool> pendingMove;
  final Value<bool> localCreated;
  final Value<String?> syncBaseUpdatedUtc;
  final Value<String?> lastSyncedAtUtc;
  final Value<String> createdLocalAtUtc;
  final Value<String> updatedLocalAtUtc;
  final Value<int> rowid;
  const TasksCompanion({
    this.accountId = const Value.absent(),
    this.taskListId = const Value.absent(),
    this.id = const Value.absent(),
    this.kind = const Value.absent(),
    this.etag = const Value.absent(),
    this.title = const Value.absent(),
    this.updatedUtc = const Value.absent(),
    this.selfLink = const Value.absent(),
    this.parent = const Value.absent(),
    this.position = const Value.absent(),
    this.notes = const Value.absent(),
    this.status = const Value.absent(),
    this.dueUtc = const Value.absent(),
    this.completedUtc = const Value.absent(),
    this.providerStatus = const Value.absent(),
    this.bodyContent = const Value.absent(),
    this.bodyContentType = const Value.absent(),
    this.microsoftDueDateTime = const Value.absent(),
    this.microsoftDueTimeZone = const Value.absent(),
    this.microsoftStartDateTime = const Value.absent(),
    this.microsoftStartTimeZone = const Value.absent(),
    this.microsoftReminderDateTime = const Value.absent(),
    this.microsoftReminderTimeZone = const Value.absent(),
    this.microsoftIsReminderOn = const Value.absent(),
    this.microsoftCompletedDateTime = const Value.absent(),
    this.microsoftCompletedTimeZone = const Value.absent(),
    this.recurrenceJson = const Value.absent(),
    this.importance = const Value.absent(),
    this.categoriesJson = const Value.absent(),
    this.hasAttachments = const Value.absent(),
    this.providerMetadataJson = const Value.absent(),
    this.deleted = const Value.absent(),
    this.hidden = const Value.absent(),
    this.linksJson = const Value.absent(),
    this.webViewLink = const Value.absent(),
    this.assignmentInfoJson = const Value.absent(),
    this.rawJson = const Value.absent(),
    this.serverMissing = const Value.absent(),
    this.localDirty = const Value.absent(),
    this.pendingDelete = const Value.absent(),
    this.pendingMove = const Value.absent(),
    this.localCreated = const Value.absent(),
    this.syncBaseUpdatedUtc = const Value.absent(),
    this.lastSyncedAtUtc = const Value.absent(),
    this.createdLocalAtUtc = const Value.absent(),
    this.updatedLocalAtUtc = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TasksCompanion.insert({
    required String accountId,
    required String taskListId,
    required String id,
    this.kind = const Value.absent(),
    this.etag = const Value.absent(),
    required String title,
    this.updatedUtc = const Value.absent(),
    this.selfLink = const Value.absent(),
    this.parent = const Value.absent(),
    this.position = const Value.absent(),
    this.notes = const Value.absent(),
    this.status = const Value.absent(),
    this.dueUtc = const Value.absent(),
    this.completedUtc = const Value.absent(),
    this.providerStatus = const Value.absent(),
    this.bodyContent = const Value.absent(),
    this.bodyContentType = const Value.absent(),
    this.microsoftDueDateTime = const Value.absent(),
    this.microsoftDueTimeZone = const Value.absent(),
    this.microsoftStartDateTime = const Value.absent(),
    this.microsoftStartTimeZone = const Value.absent(),
    this.microsoftReminderDateTime = const Value.absent(),
    this.microsoftReminderTimeZone = const Value.absent(),
    this.microsoftIsReminderOn = const Value.absent(),
    this.microsoftCompletedDateTime = const Value.absent(),
    this.microsoftCompletedTimeZone = const Value.absent(),
    this.recurrenceJson = const Value.absent(),
    this.importance = const Value.absent(),
    this.categoriesJson = const Value.absent(),
    this.hasAttachments = const Value.absent(),
    this.providerMetadataJson = const Value.absent(),
    this.deleted = const Value.absent(),
    this.hidden = const Value.absent(),
    this.linksJson = const Value.absent(),
    this.webViewLink = const Value.absent(),
    this.assignmentInfoJson = const Value.absent(),
    required String rawJson,
    this.serverMissing = const Value.absent(),
    this.localDirty = const Value.absent(),
    this.pendingDelete = const Value.absent(),
    this.pendingMove = const Value.absent(),
    this.localCreated = const Value.absent(),
    this.syncBaseUpdatedUtc = const Value.absent(),
    this.lastSyncedAtUtc = const Value.absent(),
    required String createdLocalAtUtc,
    required String updatedLocalAtUtc,
    this.rowid = const Value.absent(),
  }) : accountId = Value(accountId),
       taskListId = Value(taskListId),
       id = Value(id),
       title = Value(title),
       rawJson = Value(rawJson),
       createdLocalAtUtc = Value(createdLocalAtUtc),
       updatedLocalAtUtc = Value(updatedLocalAtUtc);
  static Insertable<Task> custom({
    Expression<String>? accountId,
    Expression<String>? taskListId,
    Expression<String>? id,
    Expression<String>? kind,
    Expression<String>? etag,
    Expression<String>? title,
    Expression<String>? updatedUtc,
    Expression<String>? selfLink,
    Expression<String>? parent,
    Expression<String>? position,
    Expression<String>? notes,
    Expression<String>? status,
    Expression<String>? dueUtc,
    Expression<String>? completedUtc,
    Expression<String>? providerStatus,
    Expression<String>? bodyContent,
    Expression<String>? bodyContentType,
    Expression<String>? microsoftDueDateTime,
    Expression<String>? microsoftDueTimeZone,
    Expression<String>? microsoftStartDateTime,
    Expression<String>? microsoftStartTimeZone,
    Expression<String>? microsoftReminderDateTime,
    Expression<String>? microsoftReminderTimeZone,
    Expression<bool>? microsoftIsReminderOn,
    Expression<String>? microsoftCompletedDateTime,
    Expression<String>? microsoftCompletedTimeZone,
    Expression<String>? recurrenceJson,
    Expression<String>? importance,
    Expression<String>? categoriesJson,
    Expression<bool>? hasAttachments,
    Expression<String>? providerMetadataJson,
    Expression<bool>? deleted,
    Expression<bool>? hidden,
    Expression<String>? linksJson,
    Expression<String>? webViewLink,
    Expression<String>? assignmentInfoJson,
    Expression<String>? rawJson,
    Expression<bool>? serverMissing,
    Expression<bool>? localDirty,
    Expression<bool>? pendingDelete,
    Expression<bool>? pendingMove,
    Expression<bool>? localCreated,
    Expression<String>? syncBaseUpdatedUtc,
    Expression<String>? lastSyncedAtUtc,
    Expression<String>? createdLocalAtUtc,
    Expression<String>? updatedLocalAtUtc,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (accountId != null) 'account_id': accountId,
      if (taskListId != null) 'task_list_id': taskListId,
      if (id != null) 'id': id,
      if (kind != null) 'kind': kind,
      if (etag != null) 'etag': etag,
      if (title != null) 'title': title,
      if (updatedUtc != null) 'updated_utc': updatedUtc,
      if (selfLink != null) 'self_link': selfLink,
      if (parent != null) 'parent': parent,
      if (position != null) 'position': position,
      if (notes != null) 'notes': notes,
      if (status != null) 'status': status,
      if (dueUtc != null) 'due_utc': dueUtc,
      if (completedUtc != null) 'completed_utc': completedUtc,
      if (providerStatus != null) 'provider_status': providerStatus,
      if (bodyContent != null) 'body_content': bodyContent,
      if (bodyContentType != null) 'body_content_type': bodyContentType,
      if (microsoftDueDateTime != null)
        'microsoft_due_date_time': microsoftDueDateTime,
      if (microsoftDueTimeZone != null)
        'microsoft_due_time_zone': microsoftDueTimeZone,
      if (microsoftStartDateTime != null)
        'microsoft_start_date_time': microsoftStartDateTime,
      if (microsoftStartTimeZone != null)
        'microsoft_start_time_zone': microsoftStartTimeZone,
      if (microsoftReminderDateTime != null)
        'microsoft_reminder_date_time': microsoftReminderDateTime,
      if (microsoftReminderTimeZone != null)
        'microsoft_reminder_time_zone': microsoftReminderTimeZone,
      if (microsoftIsReminderOn != null)
        'microsoft_is_reminder_on': microsoftIsReminderOn,
      if (microsoftCompletedDateTime != null)
        'microsoft_completed_date_time': microsoftCompletedDateTime,
      if (microsoftCompletedTimeZone != null)
        'microsoft_completed_time_zone': microsoftCompletedTimeZone,
      if (recurrenceJson != null) 'recurrence_json': recurrenceJson,
      if (importance != null) 'importance': importance,
      if (categoriesJson != null) 'categories_json': categoriesJson,
      if (hasAttachments != null) 'has_attachments': hasAttachments,
      if (providerMetadataJson != null)
        'provider_metadata_json': providerMetadataJson,
      if (deleted != null) 'deleted': deleted,
      if (hidden != null) 'hidden': hidden,
      if (linksJson != null) 'links_json': linksJson,
      if (webViewLink != null) 'web_view_link': webViewLink,
      if (assignmentInfoJson != null)
        'assignment_info_json': assignmentInfoJson,
      if (rawJson != null) 'raw_json': rawJson,
      if (serverMissing != null) 'server_missing': serverMissing,
      if (localDirty != null) 'local_dirty': localDirty,
      if (pendingDelete != null) 'pending_delete': pendingDelete,
      if (pendingMove != null) 'pending_move': pendingMove,
      if (localCreated != null) 'local_created': localCreated,
      if (syncBaseUpdatedUtc != null)
        'sync_base_updated_utc': syncBaseUpdatedUtc,
      if (lastSyncedAtUtc != null) 'last_synced_at_utc': lastSyncedAtUtc,
      if (createdLocalAtUtc != null) 'created_local_at_utc': createdLocalAtUtc,
      if (updatedLocalAtUtc != null) 'updated_local_at_utc': updatedLocalAtUtc,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TasksCompanion copyWith({
    Value<String>? accountId,
    Value<String>? taskListId,
    Value<String>? id,
    Value<String?>? kind,
    Value<String?>? etag,
    Value<String>? title,
    Value<String?>? updatedUtc,
    Value<String?>? selfLink,
    Value<String?>? parent,
    Value<String?>? position,
    Value<String?>? notes,
    Value<String?>? status,
    Value<String?>? dueUtc,
    Value<String?>? completedUtc,
    Value<String?>? providerStatus,
    Value<String?>? bodyContent,
    Value<String?>? bodyContentType,
    Value<String?>? microsoftDueDateTime,
    Value<String?>? microsoftDueTimeZone,
    Value<String?>? microsoftStartDateTime,
    Value<String?>? microsoftStartTimeZone,
    Value<String?>? microsoftReminderDateTime,
    Value<String?>? microsoftReminderTimeZone,
    Value<bool?>? microsoftIsReminderOn,
    Value<String?>? microsoftCompletedDateTime,
    Value<String?>? microsoftCompletedTimeZone,
    Value<String?>? recurrenceJson,
    Value<String?>? importance,
    Value<String?>? categoriesJson,
    Value<bool?>? hasAttachments,
    Value<String?>? providerMetadataJson,
    Value<bool?>? deleted,
    Value<bool?>? hidden,
    Value<String?>? linksJson,
    Value<String?>? webViewLink,
    Value<String?>? assignmentInfoJson,
    Value<String>? rawJson,
    Value<bool>? serverMissing,
    Value<bool>? localDirty,
    Value<bool>? pendingDelete,
    Value<bool>? pendingMove,
    Value<bool>? localCreated,
    Value<String?>? syncBaseUpdatedUtc,
    Value<String?>? lastSyncedAtUtc,
    Value<String>? createdLocalAtUtc,
    Value<String>? updatedLocalAtUtc,
    Value<int>? rowid,
  }) {
    return TasksCompanion(
      accountId: accountId ?? this.accountId,
      taskListId: taskListId ?? this.taskListId,
      id: id ?? this.id,
      kind: kind ?? this.kind,
      etag: etag ?? this.etag,
      title: title ?? this.title,
      updatedUtc: updatedUtc ?? this.updatedUtc,
      selfLink: selfLink ?? this.selfLink,
      parent: parent ?? this.parent,
      position: position ?? this.position,
      notes: notes ?? this.notes,
      status: status ?? this.status,
      dueUtc: dueUtc ?? this.dueUtc,
      completedUtc: completedUtc ?? this.completedUtc,
      providerStatus: providerStatus ?? this.providerStatus,
      bodyContent: bodyContent ?? this.bodyContent,
      bodyContentType: bodyContentType ?? this.bodyContentType,
      microsoftDueDateTime: microsoftDueDateTime ?? this.microsoftDueDateTime,
      microsoftDueTimeZone: microsoftDueTimeZone ?? this.microsoftDueTimeZone,
      microsoftStartDateTime:
          microsoftStartDateTime ?? this.microsoftStartDateTime,
      microsoftStartTimeZone:
          microsoftStartTimeZone ?? this.microsoftStartTimeZone,
      microsoftReminderDateTime:
          microsoftReminderDateTime ?? this.microsoftReminderDateTime,
      microsoftReminderTimeZone:
          microsoftReminderTimeZone ?? this.microsoftReminderTimeZone,
      microsoftIsReminderOn:
          microsoftIsReminderOn ?? this.microsoftIsReminderOn,
      microsoftCompletedDateTime:
          microsoftCompletedDateTime ?? this.microsoftCompletedDateTime,
      microsoftCompletedTimeZone:
          microsoftCompletedTimeZone ?? this.microsoftCompletedTimeZone,
      recurrenceJson: recurrenceJson ?? this.recurrenceJson,
      importance: importance ?? this.importance,
      categoriesJson: categoriesJson ?? this.categoriesJson,
      hasAttachments: hasAttachments ?? this.hasAttachments,
      providerMetadataJson: providerMetadataJson ?? this.providerMetadataJson,
      deleted: deleted ?? this.deleted,
      hidden: hidden ?? this.hidden,
      linksJson: linksJson ?? this.linksJson,
      webViewLink: webViewLink ?? this.webViewLink,
      assignmentInfoJson: assignmentInfoJson ?? this.assignmentInfoJson,
      rawJson: rawJson ?? this.rawJson,
      serverMissing: serverMissing ?? this.serverMissing,
      localDirty: localDirty ?? this.localDirty,
      pendingDelete: pendingDelete ?? this.pendingDelete,
      pendingMove: pendingMove ?? this.pendingMove,
      localCreated: localCreated ?? this.localCreated,
      syncBaseUpdatedUtc: syncBaseUpdatedUtc ?? this.syncBaseUpdatedUtc,
      lastSyncedAtUtc: lastSyncedAtUtc ?? this.lastSyncedAtUtc,
      createdLocalAtUtc: createdLocalAtUtc ?? this.createdLocalAtUtc,
      updatedLocalAtUtc: updatedLocalAtUtc ?? this.updatedLocalAtUtc,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (accountId.present) {
      map['account_id'] = Variable<String>(accountId.value);
    }
    if (taskListId.present) {
      map['task_list_id'] = Variable<String>(taskListId.value);
    }
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (etag.present) {
      map['etag'] = Variable<String>(etag.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (updatedUtc.present) {
      map['updated_utc'] = Variable<String>(updatedUtc.value);
    }
    if (selfLink.present) {
      map['self_link'] = Variable<String>(selfLink.value);
    }
    if (parent.present) {
      map['parent'] = Variable<String>(parent.value);
    }
    if (position.present) {
      map['position'] = Variable<String>(position.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (dueUtc.present) {
      map['due_utc'] = Variable<String>(dueUtc.value);
    }
    if (completedUtc.present) {
      map['completed_utc'] = Variable<String>(completedUtc.value);
    }
    if (providerStatus.present) {
      map['provider_status'] = Variable<String>(providerStatus.value);
    }
    if (bodyContent.present) {
      map['body_content'] = Variable<String>(bodyContent.value);
    }
    if (bodyContentType.present) {
      map['body_content_type'] = Variable<String>(bodyContentType.value);
    }
    if (microsoftDueDateTime.present) {
      map['microsoft_due_date_time'] = Variable<String>(
        microsoftDueDateTime.value,
      );
    }
    if (microsoftDueTimeZone.present) {
      map['microsoft_due_time_zone'] = Variable<String>(
        microsoftDueTimeZone.value,
      );
    }
    if (microsoftStartDateTime.present) {
      map['microsoft_start_date_time'] = Variable<String>(
        microsoftStartDateTime.value,
      );
    }
    if (microsoftStartTimeZone.present) {
      map['microsoft_start_time_zone'] = Variable<String>(
        microsoftStartTimeZone.value,
      );
    }
    if (microsoftReminderDateTime.present) {
      map['microsoft_reminder_date_time'] = Variable<String>(
        microsoftReminderDateTime.value,
      );
    }
    if (microsoftReminderTimeZone.present) {
      map['microsoft_reminder_time_zone'] = Variable<String>(
        microsoftReminderTimeZone.value,
      );
    }
    if (microsoftIsReminderOn.present) {
      map['microsoft_is_reminder_on'] = Variable<bool>(
        microsoftIsReminderOn.value,
      );
    }
    if (microsoftCompletedDateTime.present) {
      map['microsoft_completed_date_time'] = Variable<String>(
        microsoftCompletedDateTime.value,
      );
    }
    if (microsoftCompletedTimeZone.present) {
      map['microsoft_completed_time_zone'] = Variable<String>(
        microsoftCompletedTimeZone.value,
      );
    }
    if (recurrenceJson.present) {
      map['recurrence_json'] = Variable<String>(recurrenceJson.value);
    }
    if (importance.present) {
      map['importance'] = Variable<String>(importance.value);
    }
    if (categoriesJson.present) {
      map['categories_json'] = Variable<String>(categoriesJson.value);
    }
    if (hasAttachments.present) {
      map['has_attachments'] = Variable<bool>(hasAttachments.value);
    }
    if (providerMetadataJson.present) {
      map['provider_metadata_json'] = Variable<String>(
        providerMetadataJson.value,
      );
    }
    if (deleted.present) {
      map['deleted'] = Variable<bool>(deleted.value);
    }
    if (hidden.present) {
      map['hidden'] = Variable<bool>(hidden.value);
    }
    if (linksJson.present) {
      map['links_json'] = Variable<String>(linksJson.value);
    }
    if (webViewLink.present) {
      map['web_view_link'] = Variable<String>(webViewLink.value);
    }
    if (assignmentInfoJson.present) {
      map['assignment_info_json'] = Variable<String>(assignmentInfoJson.value);
    }
    if (rawJson.present) {
      map['raw_json'] = Variable<String>(rawJson.value);
    }
    if (serverMissing.present) {
      map['server_missing'] = Variable<bool>(serverMissing.value);
    }
    if (localDirty.present) {
      map['local_dirty'] = Variable<bool>(localDirty.value);
    }
    if (pendingDelete.present) {
      map['pending_delete'] = Variable<bool>(pendingDelete.value);
    }
    if (pendingMove.present) {
      map['pending_move'] = Variable<bool>(pendingMove.value);
    }
    if (localCreated.present) {
      map['local_created'] = Variable<bool>(localCreated.value);
    }
    if (syncBaseUpdatedUtc.present) {
      map['sync_base_updated_utc'] = Variable<String>(syncBaseUpdatedUtc.value);
    }
    if (lastSyncedAtUtc.present) {
      map['last_synced_at_utc'] = Variable<String>(lastSyncedAtUtc.value);
    }
    if (createdLocalAtUtc.present) {
      map['created_local_at_utc'] = Variable<String>(createdLocalAtUtc.value);
    }
    if (updatedLocalAtUtc.present) {
      map['updated_local_at_utc'] = Variable<String>(updatedLocalAtUtc.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TasksCompanion(')
          ..write('accountId: $accountId, ')
          ..write('taskListId: $taskListId, ')
          ..write('id: $id, ')
          ..write('kind: $kind, ')
          ..write('etag: $etag, ')
          ..write('title: $title, ')
          ..write('updatedUtc: $updatedUtc, ')
          ..write('selfLink: $selfLink, ')
          ..write('parent: $parent, ')
          ..write('position: $position, ')
          ..write('notes: $notes, ')
          ..write('status: $status, ')
          ..write('dueUtc: $dueUtc, ')
          ..write('completedUtc: $completedUtc, ')
          ..write('providerStatus: $providerStatus, ')
          ..write('bodyContent: $bodyContent, ')
          ..write('bodyContentType: $bodyContentType, ')
          ..write('microsoftDueDateTime: $microsoftDueDateTime, ')
          ..write('microsoftDueTimeZone: $microsoftDueTimeZone, ')
          ..write('microsoftStartDateTime: $microsoftStartDateTime, ')
          ..write('microsoftStartTimeZone: $microsoftStartTimeZone, ')
          ..write('microsoftReminderDateTime: $microsoftReminderDateTime, ')
          ..write('microsoftReminderTimeZone: $microsoftReminderTimeZone, ')
          ..write('microsoftIsReminderOn: $microsoftIsReminderOn, ')
          ..write('microsoftCompletedDateTime: $microsoftCompletedDateTime, ')
          ..write('microsoftCompletedTimeZone: $microsoftCompletedTimeZone, ')
          ..write('recurrenceJson: $recurrenceJson, ')
          ..write('importance: $importance, ')
          ..write('categoriesJson: $categoriesJson, ')
          ..write('hasAttachments: $hasAttachments, ')
          ..write('providerMetadataJson: $providerMetadataJson, ')
          ..write('deleted: $deleted, ')
          ..write('hidden: $hidden, ')
          ..write('linksJson: $linksJson, ')
          ..write('webViewLink: $webViewLink, ')
          ..write('assignmentInfoJson: $assignmentInfoJson, ')
          ..write('rawJson: $rawJson, ')
          ..write('serverMissing: $serverMissing, ')
          ..write('localDirty: $localDirty, ')
          ..write('pendingDelete: $pendingDelete, ')
          ..write('pendingMove: $pendingMove, ')
          ..write('localCreated: $localCreated, ')
          ..write('syncBaseUpdatedUtc: $syncBaseUpdatedUtc, ')
          ..write('lastSyncedAtUtc: $lastSyncedAtUtc, ')
          ..write('createdLocalAtUtc: $createdLocalAtUtc, ')
          ..write('updatedLocalAtUtc: $updatedLocalAtUtc, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PendingOpsTable extends PendingOps
    with TableInfo<$PendingOpsTable, PendingOp> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PendingOpsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _accountIdMeta = const VerificationMeta(
    'accountId',
  );
  @override
  late final GeneratedColumn<String> accountId = GeneratedColumn<String>(
    'account_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES accounts (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _providerMeta = const VerificationMeta(
    'provider',
  );
  @override
  late final GeneratedColumn<String> provider = GeneratedColumn<String>(
    'provider',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _entityTypeMeta = const VerificationMeta(
    'entityType',
  );
  @override
  late final GeneratedColumn<String> entityType = GeneratedColumn<String>(
    'entity_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _operationMeta = const VerificationMeta(
    'operation',
  );
  @override
  late final GeneratedColumn<String> operation = GeneratedColumn<String>(
    'operation',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _operationTypeMeta = const VerificationMeta(
    'operationType',
  );
  @override
  late final GeneratedColumn<String> operationType = GeneratedColumn<String>(
    'operation_type',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _taskListIdMeta = const VerificationMeta(
    'taskListId',
  );
  @override
  late final GeneratedColumn<String> taskListId = GeneratedColumn<String>(
    'task_list_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _taskIdMeta = const VerificationMeta('taskId');
  @override
  late final GeneratedColumn<String> taskId = GeneratedColumn<String>(
    'task_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _calendarSourceIdMeta = const VerificationMeta(
    'calendarSourceId',
  );
  @override
  late final GeneratedColumn<String> calendarSourceId = GeneratedColumn<String>(
    'calendar_source_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _providerCalendarIdMeta =
      const VerificationMeta('providerCalendarId');
  @override
  late final GeneratedColumn<String> providerCalendarId =
      GeneratedColumn<String>(
        'provider_calendar_id',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _eventIdMeta = const VerificationMeta(
    'eventId',
  );
  @override
  late final GeneratedColumn<String> eventId = GeneratedColumn<String>(
    'event_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _localTempIdMeta = const VerificationMeta(
    'localTempId',
  );
  @override
  late final GeneratedColumn<String> localTempId = GeneratedColumn<String>(
    'local_temp_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _dependsOnOpIdMeta = const VerificationMeta(
    'dependsOnOpId',
  );
  @override
  late final GeneratedColumn<String> dependsOnOpId = GeneratedColumn<String>(
    'depends_on_op_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _requestJsonMeta = const VerificationMeta(
    'requestJson',
  );
  @override
  late final GeneratedColumn<String> requestJson = GeneratedColumn<String>(
    'request_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _baselineUpdatedUtcMeta =
      const VerificationMeta('baselineUpdatedUtc');
  @override
  late final GeneratedColumn<String> baselineUpdatedUtc =
      GeneratedColumn<String>(
        'baseline_updated_utc',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _baselineRawJsonMeta = const VerificationMeta(
    'baselineRawJson',
  );
  @override
  late final GeneratedColumn<String> baselineRawJson = GeneratedColumn<String>(
    'baseline_raw_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _attemptCountMeta = const VerificationMeta(
    'attemptCount',
  );
  @override
  late final GeneratedColumn<int> attemptCount = GeneratedColumn<int>(
    'attempt_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _nextAttemptAtUtcMeta = const VerificationMeta(
    'nextAttemptAtUtc',
  );
  @override
  late final GeneratedColumn<String> nextAttemptAtUtc = GeneratedColumn<String>(
    'next_attempt_at_utc',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastErrorCodeMeta = const VerificationMeta(
    'lastErrorCode',
  );
  @override
  late final GeneratedColumn<String> lastErrorCode = GeneratedColumn<String>(
    'last_error_code',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastErrorMessageMeta = const VerificationMeta(
    'lastErrorMessage',
  );
  @override
  late final GeneratedColumn<String> lastErrorMessage = GeneratedColumn<String>(
    'last_error_message',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _stateMeta = const VerificationMeta('state');
  @override
  late final GeneratedColumn<String> state = GeneratedColumn<String>(
    'state',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('pending'),
  );
  static const VerificationMeta _lastErrorMeta = const VerificationMeta(
    'lastError',
  );
  @override
  late final GeneratedColumn<String> lastError = GeneratedColumn<String>(
    'last_error',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtUtcMeta = const VerificationMeta(
    'createdAtUtc',
  );
  @override
  late final GeneratedColumn<String> createdAtUtc = GeneratedColumn<String>(
    'created_at_utc',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtUtcMeta = const VerificationMeta(
    'updatedAtUtc',
  );
  @override
  late final GeneratedColumn<String> updatedAtUtc = GeneratedColumn<String>(
    'updated_at_utc',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    accountId,
    provider,
    entityType,
    operation,
    operationType,
    taskListId,
    taskId,
    calendarSourceId,
    providerCalendarId,
    eventId,
    localTempId,
    dependsOnOpId,
    requestJson,
    baselineUpdatedUtc,
    baselineRawJson,
    attemptCount,
    nextAttemptAtUtc,
    lastErrorCode,
    lastErrorMessage,
    state,
    lastError,
    createdAtUtc,
    updatedAtUtc,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'pending_ops';
  @override
  VerificationContext validateIntegrity(
    Insertable<PendingOp> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('account_id')) {
      context.handle(
        _accountIdMeta,
        accountId.isAcceptableOrUnknown(data['account_id']!, _accountIdMeta),
      );
    } else if (isInserting) {
      context.missing(_accountIdMeta);
    }
    if (data.containsKey('provider')) {
      context.handle(
        _providerMeta,
        provider.isAcceptableOrUnknown(data['provider']!, _providerMeta),
      );
    }
    if (data.containsKey('entity_type')) {
      context.handle(
        _entityTypeMeta,
        entityType.isAcceptableOrUnknown(data['entity_type']!, _entityTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_entityTypeMeta);
    }
    if (data.containsKey('operation')) {
      context.handle(
        _operationMeta,
        operation.isAcceptableOrUnknown(data['operation']!, _operationMeta),
      );
    } else if (isInserting) {
      context.missing(_operationMeta);
    }
    if (data.containsKey('operation_type')) {
      context.handle(
        _operationTypeMeta,
        operationType.isAcceptableOrUnknown(
          data['operation_type']!,
          _operationTypeMeta,
        ),
      );
    }
    if (data.containsKey('task_list_id')) {
      context.handle(
        _taskListIdMeta,
        taskListId.isAcceptableOrUnknown(
          data['task_list_id']!,
          _taskListIdMeta,
        ),
      );
    }
    if (data.containsKey('task_id')) {
      context.handle(
        _taskIdMeta,
        taskId.isAcceptableOrUnknown(data['task_id']!, _taskIdMeta),
      );
    }
    if (data.containsKey('calendar_source_id')) {
      context.handle(
        _calendarSourceIdMeta,
        calendarSourceId.isAcceptableOrUnknown(
          data['calendar_source_id']!,
          _calendarSourceIdMeta,
        ),
      );
    }
    if (data.containsKey('provider_calendar_id')) {
      context.handle(
        _providerCalendarIdMeta,
        providerCalendarId.isAcceptableOrUnknown(
          data['provider_calendar_id']!,
          _providerCalendarIdMeta,
        ),
      );
    }
    if (data.containsKey('event_id')) {
      context.handle(
        _eventIdMeta,
        eventId.isAcceptableOrUnknown(data['event_id']!, _eventIdMeta),
      );
    }
    if (data.containsKey('local_temp_id')) {
      context.handle(
        _localTempIdMeta,
        localTempId.isAcceptableOrUnknown(
          data['local_temp_id']!,
          _localTempIdMeta,
        ),
      );
    }
    if (data.containsKey('depends_on_op_id')) {
      context.handle(
        _dependsOnOpIdMeta,
        dependsOnOpId.isAcceptableOrUnknown(
          data['depends_on_op_id']!,
          _dependsOnOpIdMeta,
        ),
      );
    }
    if (data.containsKey('request_json')) {
      context.handle(
        _requestJsonMeta,
        requestJson.isAcceptableOrUnknown(
          data['request_json']!,
          _requestJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_requestJsonMeta);
    }
    if (data.containsKey('baseline_updated_utc')) {
      context.handle(
        _baselineUpdatedUtcMeta,
        baselineUpdatedUtc.isAcceptableOrUnknown(
          data['baseline_updated_utc']!,
          _baselineUpdatedUtcMeta,
        ),
      );
    }
    if (data.containsKey('baseline_raw_json')) {
      context.handle(
        _baselineRawJsonMeta,
        baselineRawJson.isAcceptableOrUnknown(
          data['baseline_raw_json']!,
          _baselineRawJsonMeta,
        ),
      );
    }
    if (data.containsKey('attempt_count')) {
      context.handle(
        _attemptCountMeta,
        attemptCount.isAcceptableOrUnknown(
          data['attempt_count']!,
          _attemptCountMeta,
        ),
      );
    }
    if (data.containsKey('next_attempt_at_utc')) {
      context.handle(
        _nextAttemptAtUtcMeta,
        nextAttemptAtUtc.isAcceptableOrUnknown(
          data['next_attempt_at_utc']!,
          _nextAttemptAtUtcMeta,
        ),
      );
    }
    if (data.containsKey('last_error_code')) {
      context.handle(
        _lastErrorCodeMeta,
        lastErrorCode.isAcceptableOrUnknown(
          data['last_error_code']!,
          _lastErrorCodeMeta,
        ),
      );
    }
    if (data.containsKey('last_error_message')) {
      context.handle(
        _lastErrorMessageMeta,
        lastErrorMessage.isAcceptableOrUnknown(
          data['last_error_message']!,
          _lastErrorMessageMeta,
        ),
      );
    }
    if (data.containsKey('state')) {
      context.handle(
        _stateMeta,
        state.isAcceptableOrUnknown(data['state']!, _stateMeta),
      );
    }
    if (data.containsKey('last_error')) {
      context.handle(
        _lastErrorMeta,
        lastError.isAcceptableOrUnknown(data['last_error']!, _lastErrorMeta),
      );
    }
    if (data.containsKey('created_at_utc')) {
      context.handle(
        _createdAtUtcMeta,
        createdAtUtc.isAcceptableOrUnknown(
          data['created_at_utc']!,
          _createdAtUtcMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_createdAtUtcMeta);
    }
    if (data.containsKey('updated_at_utc')) {
      context.handle(
        _updatedAtUtcMeta,
        updatedAtUtc.isAcceptableOrUnknown(
          data['updated_at_utc']!,
          _updatedAtUtcMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_updatedAtUtcMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PendingOp map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PendingOp(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      accountId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}account_id'],
      )!,
      provider: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}provider'],
      ),
      entityType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity_type'],
      )!,
      operation: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}operation'],
      )!,
      operationType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}operation_type'],
      ),
      taskListId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}task_list_id'],
      ),
      taskId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}task_id'],
      ),
      calendarSourceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}calendar_source_id'],
      ),
      providerCalendarId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}provider_calendar_id'],
      ),
      eventId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}event_id'],
      ),
      localTempId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}local_temp_id'],
      ),
      dependsOnOpId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}depends_on_op_id'],
      ),
      requestJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}request_json'],
      )!,
      baselineUpdatedUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}baseline_updated_utc'],
      ),
      baselineRawJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}baseline_raw_json'],
      ),
      attemptCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}attempt_count'],
      )!,
      nextAttemptAtUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}next_attempt_at_utc'],
      ),
      lastErrorCode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_error_code'],
      ),
      lastErrorMessage: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_error_message'],
      ),
      state: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}state'],
      )!,
      lastError: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_error'],
      ),
      createdAtUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_at_utc'],
      )!,
      updatedAtUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}updated_at_utc'],
      )!,
    );
  }

  @override
  $PendingOpsTable createAlias(String alias) {
    return $PendingOpsTable(attachedDatabase, alias);
  }
}

class PendingOp extends DataClass implements Insertable<PendingOp> {
  final String id;
  final String accountId;
  final String? provider;
  final String entityType;
  final String operation;
  final String? operationType;
  final String? taskListId;
  final String? taskId;
  final String? calendarSourceId;
  final String? providerCalendarId;
  final String? eventId;
  final String? localTempId;
  final String? dependsOnOpId;
  final String requestJson;
  final String? baselineUpdatedUtc;
  final String? baselineRawJson;
  final int attemptCount;
  final String? nextAttemptAtUtc;
  final String? lastErrorCode;
  final String? lastErrorMessage;
  final String state;
  final String? lastError;
  final String createdAtUtc;
  final String updatedAtUtc;
  const PendingOp({
    required this.id,
    required this.accountId,
    this.provider,
    required this.entityType,
    required this.operation,
    this.operationType,
    this.taskListId,
    this.taskId,
    this.calendarSourceId,
    this.providerCalendarId,
    this.eventId,
    this.localTempId,
    this.dependsOnOpId,
    required this.requestJson,
    this.baselineUpdatedUtc,
    this.baselineRawJson,
    required this.attemptCount,
    this.nextAttemptAtUtc,
    this.lastErrorCode,
    this.lastErrorMessage,
    required this.state,
    this.lastError,
    required this.createdAtUtc,
    required this.updatedAtUtc,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['account_id'] = Variable<String>(accountId);
    if (!nullToAbsent || provider != null) {
      map['provider'] = Variable<String>(provider);
    }
    map['entity_type'] = Variable<String>(entityType);
    map['operation'] = Variable<String>(operation);
    if (!nullToAbsent || operationType != null) {
      map['operation_type'] = Variable<String>(operationType);
    }
    if (!nullToAbsent || taskListId != null) {
      map['task_list_id'] = Variable<String>(taskListId);
    }
    if (!nullToAbsent || taskId != null) {
      map['task_id'] = Variable<String>(taskId);
    }
    if (!nullToAbsent || calendarSourceId != null) {
      map['calendar_source_id'] = Variable<String>(calendarSourceId);
    }
    if (!nullToAbsent || providerCalendarId != null) {
      map['provider_calendar_id'] = Variable<String>(providerCalendarId);
    }
    if (!nullToAbsent || eventId != null) {
      map['event_id'] = Variable<String>(eventId);
    }
    if (!nullToAbsent || localTempId != null) {
      map['local_temp_id'] = Variable<String>(localTempId);
    }
    if (!nullToAbsent || dependsOnOpId != null) {
      map['depends_on_op_id'] = Variable<String>(dependsOnOpId);
    }
    map['request_json'] = Variable<String>(requestJson);
    if (!nullToAbsent || baselineUpdatedUtc != null) {
      map['baseline_updated_utc'] = Variable<String>(baselineUpdatedUtc);
    }
    if (!nullToAbsent || baselineRawJson != null) {
      map['baseline_raw_json'] = Variable<String>(baselineRawJson);
    }
    map['attempt_count'] = Variable<int>(attemptCount);
    if (!nullToAbsent || nextAttemptAtUtc != null) {
      map['next_attempt_at_utc'] = Variable<String>(nextAttemptAtUtc);
    }
    if (!nullToAbsent || lastErrorCode != null) {
      map['last_error_code'] = Variable<String>(lastErrorCode);
    }
    if (!nullToAbsent || lastErrorMessage != null) {
      map['last_error_message'] = Variable<String>(lastErrorMessage);
    }
    map['state'] = Variable<String>(state);
    if (!nullToAbsent || lastError != null) {
      map['last_error'] = Variable<String>(lastError);
    }
    map['created_at_utc'] = Variable<String>(createdAtUtc);
    map['updated_at_utc'] = Variable<String>(updatedAtUtc);
    return map;
  }

  PendingOpsCompanion toCompanion(bool nullToAbsent) {
    return PendingOpsCompanion(
      id: Value(id),
      accountId: Value(accountId),
      provider: provider == null && nullToAbsent
          ? const Value.absent()
          : Value(provider),
      entityType: Value(entityType),
      operation: Value(operation),
      operationType: operationType == null && nullToAbsent
          ? const Value.absent()
          : Value(operationType),
      taskListId: taskListId == null && nullToAbsent
          ? const Value.absent()
          : Value(taskListId),
      taskId: taskId == null && nullToAbsent
          ? const Value.absent()
          : Value(taskId),
      calendarSourceId: calendarSourceId == null && nullToAbsent
          ? const Value.absent()
          : Value(calendarSourceId),
      providerCalendarId: providerCalendarId == null && nullToAbsent
          ? const Value.absent()
          : Value(providerCalendarId),
      eventId: eventId == null && nullToAbsent
          ? const Value.absent()
          : Value(eventId),
      localTempId: localTempId == null && nullToAbsent
          ? const Value.absent()
          : Value(localTempId),
      dependsOnOpId: dependsOnOpId == null && nullToAbsent
          ? const Value.absent()
          : Value(dependsOnOpId),
      requestJson: Value(requestJson),
      baselineUpdatedUtc: baselineUpdatedUtc == null && nullToAbsent
          ? const Value.absent()
          : Value(baselineUpdatedUtc),
      baselineRawJson: baselineRawJson == null && nullToAbsent
          ? const Value.absent()
          : Value(baselineRawJson),
      attemptCount: Value(attemptCount),
      nextAttemptAtUtc: nextAttemptAtUtc == null && nullToAbsent
          ? const Value.absent()
          : Value(nextAttemptAtUtc),
      lastErrorCode: lastErrorCode == null && nullToAbsent
          ? const Value.absent()
          : Value(lastErrorCode),
      lastErrorMessage: lastErrorMessage == null && nullToAbsent
          ? const Value.absent()
          : Value(lastErrorMessage),
      state: Value(state),
      lastError: lastError == null && nullToAbsent
          ? const Value.absent()
          : Value(lastError),
      createdAtUtc: Value(createdAtUtc),
      updatedAtUtc: Value(updatedAtUtc),
    );
  }

  factory PendingOp.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PendingOp(
      id: serializer.fromJson<String>(json['id']),
      accountId: serializer.fromJson<String>(json['accountId']),
      provider: serializer.fromJson<String?>(json['provider']),
      entityType: serializer.fromJson<String>(json['entityType']),
      operation: serializer.fromJson<String>(json['operation']),
      operationType: serializer.fromJson<String?>(json['operationType']),
      taskListId: serializer.fromJson<String?>(json['taskListId']),
      taskId: serializer.fromJson<String?>(json['taskId']),
      calendarSourceId: serializer.fromJson<String?>(json['calendarSourceId']),
      providerCalendarId: serializer.fromJson<String?>(
        json['providerCalendarId'],
      ),
      eventId: serializer.fromJson<String?>(json['eventId']),
      localTempId: serializer.fromJson<String?>(json['localTempId']),
      dependsOnOpId: serializer.fromJson<String?>(json['dependsOnOpId']),
      requestJson: serializer.fromJson<String>(json['requestJson']),
      baselineUpdatedUtc: serializer.fromJson<String?>(
        json['baselineUpdatedUtc'],
      ),
      baselineRawJson: serializer.fromJson<String?>(json['baselineRawJson']),
      attemptCount: serializer.fromJson<int>(json['attemptCount']),
      nextAttemptAtUtc: serializer.fromJson<String?>(json['nextAttemptAtUtc']),
      lastErrorCode: serializer.fromJson<String?>(json['lastErrorCode']),
      lastErrorMessage: serializer.fromJson<String?>(json['lastErrorMessage']),
      state: serializer.fromJson<String>(json['state']),
      lastError: serializer.fromJson<String?>(json['lastError']),
      createdAtUtc: serializer.fromJson<String>(json['createdAtUtc']),
      updatedAtUtc: serializer.fromJson<String>(json['updatedAtUtc']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'accountId': serializer.toJson<String>(accountId),
      'provider': serializer.toJson<String?>(provider),
      'entityType': serializer.toJson<String>(entityType),
      'operation': serializer.toJson<String>(operation),
      'operationType': serializer.toJson<String?>(operationType),
      'taskListId': serializer.toJson<String?>(taskListId),
      'taskId': serializer.toJson<String?>(taskId),
      'calendarSourceId': serializer.toJson<String?>(calendarSourceId),
      'providerCalendarId': serializer.toJson<String?>(providerCalendarId),
      'eventId': serializer.toJson<String?>(eventId),
      'localTempId': serializer.toJson<String?>(localTempId),
      'dependsOnOpId': serializer.toJson<String?>(dependsOnOpId),
      'requestJson': serializer.toJson<String>(requestJson),
      'baselineUpdatedUtc': serializer.toJson<String?>(baselineUpdatedUtc),
      'baselineRawJson': serializer.toJson<String?>(baselineRawJson),
      'attemptCount': serializer.toJson<int>(attemptCount),
      'nextAttemptAtUtc': serializer.toJson<String?>(nextAttemptAtUtc),
      'lastErrorCode': serializer.toJson<String?>(lastErrorCode),
      'lastErrorMessage': serializer.toJson<String?>(lastErrorMessage),
      'state': serializer.toJson<String>(state),
      'lastError': serializer.toJson<String?>(lastError),
      'createdAtUtc': serializer.toJson<String>(createdAtUtc),
      'updatedAtUtc': serializer.toJson<String>(updatedAtUtc),
    };
  }

  PendingOp copyWith({
    String? id,
    String? accountId,
    Value<String?> provider = const Value.absent(),
    String? entityType,
    String? operation,
    Value<String?> operationType = const Value.absent(),
    Value<String?> taskListId = const Value.absent(),
    Value<String?> taskId = const Value.absent(),
    Value<String?> calendarSourceId = const Value.absent(),
    Value<String?> providerCalendarId = const Value.absent(),
    Value<String?> eventId = const Value.absent(),
    Value<String?> localTempId = const Value.absent(),
    Value<String?> dependsOnOpId = const Value.absent(),
    String? requestJson,
    Value<String?> baselineUpdatedUtc = const Value.absent(),
    Value<String?> baselineRawJson = const Value.absent(),
    int? attemptCount,
    Value<String?> nextAttemptAtUtc = const Value.absent(),
    Value<String?> lastErrorCode = const Value.absent(),
    Value<String?> lastErrorMessage = const Value.absent(),
    String? state,
    Value<String?> lastError = const Value.absent(),
    String? createdAtUtc,
    String? updatedAtUtc,
  }) => PendingOp(
    id: id ?? this.id,
    accountId: accountId ?? this.accountId,
    provider: provider.present ? provider.value : this.provider,
    entityType: entityType ?? this.entityType,
    operation: operation ?? this.operation,
    operationType: operationType.present
        ? operationType.value
        : this.operationType,
    taskListId: taskListId.present ? taskListId.value : this.taskListId,
    taskId: taskId.present ? taskId.value : this.taskId,
    calendarSourceId: calendarSourceId.present
        ? calendarSourceId.value
        : this.calendarSourceId,
    providerCalendarId: providerCalendarId.present
        ? providerCalendarId.value
        : this.providerCalendarId,
    eventId: eventId.present ? eventId.value : this.eventId,
    localTempId: localTempId.present ? localTempId.value : this.localTempId,
    dependsOnOpId: dependsOnOpId.present
        ? dependsOnOpId.value
        : this.dependsOnOpId,
    requestJson: requestJson ?? this.requestJson,
    baselineUpdatedUtc: baselineUpdatedUtc.present
        ? baselineUpdatedUtc.value
        : this.baselineUpdatedUtc,
    baselineRawJson: baselineRawJson.present
        ? baselineRawJson.value
        : this.baselineRawJson,
    attemptCount: attemptCount ?? this.attemptCount,
    nextAttemptAtUtc: nextAttemptAtUtc.present
        ? nextAttemptAtUtc.value
        : this.nextAttemptAtUtc,
    lastErrorCode: lastErrorCode.present
        ? lastErrorCode.value
        : this.lastErrorCode,
    lastErrorMessage: lastErrorMessage.present
        ? lastErrorMessage.value
        : this.lastErrorMessage,
    state: state ?? this.state,
    lastError: lastError.present ? lastError.value : this.lastError,
    createdAtUtc: createdAtUtc ?? this.createdAtUtc,
    updatedAtUtc: updatedAtUtc ?? this.updatedAtUtc,
  );
  PendingOp copyWithCompanion(PendingOpsCompanion data) {
    return PendingOp(
      id: data.id.present ? data.id.value : this.id,
      accountId: data.accountId.present ? data.accountId.value : this.accountId,
      provider: data.provider.present ? data.provider.value : this.provider,
      entityType: data.entityType.present
          ? data.entityType.value
          : this.entityType,
      operation: data.operation.present ? data.operation.value : this.operation,
      operationType: data.operationType.present
          ? data.operationType.value
          : this.operationType,
      taskListId: data.taskListId.present
          ? data.taskListId.value
          : this.taskListId,
      taskId: data.taskId.present ? data.taskId.value : this.taskId,
      calendarSourceId: data.calendarSourceId.present
          ? data.calendarSourceId.value
          : this.calendarSourceId,
      providerCalendarId: data.providerCalendarId.present
          ? data.providerCalendarId.value
          : this.providerCalendarId,
      eventId: data.eventId.present ? data.eventId.value : this.eventId,
      localTempId: data.localTempId.present
          ? data.localTempId.value
          : this.localTempId,
      dependsOnOpId: data.dependsOnOpId.present
          ? data.dependsOnOpId.value
          : this.dependsOnOpId,
      requestJson: data.requestJson.present
          ? data.requestJson.value
          : this.requestJson,
      baselineUpdatedUtc: data.baselineUpdatedUtc.present
          ? data.baselineUpdatedUtc.value
          : this.baselineUpdatedUtc,
      baselineRawJson: data.baselineRawJson.present
          ? data.baselineRawJson.value
          : this.baselineRawJson,
      attemptCount: data.attemptCount.present
          ? data.attemptCount.value
          : this.attemptCount,
      nextAttemptAtUtc: data.nextAttemptAtUtc.present
          ? data.nextAttemptAtUtc.value
          : this.nextAttemptAtUtc,
      lastErrorCode: data.lastErrorCode.present
          ? data.lastErrorCode.value
          : this.lastErrorCode,
      lastErrorMessage: data.lastErrorMessage.present
          ? data.lastErrorMessage.value
          : this.lastErrorMessage,
      state: data.state.present ? data.state.value : this.state,
      lastError: data.lastError.present ? data.lastError.value : this.lastError,
      createdAtUtc: data.createdAtUtc.present
          ? data.createdAtUtc.value
          : this.createdAtUtc,
      updatedAtUtc: data.updatedAtUtc.present
          ? data.updatedAtUtc.value
          : this.updatedAtUtc,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PendingOp(')
          ..write('id: $id, ')
          ..write('accountId: $accountId, ')
          ..write('provider: $provider, ')
          ..write('entityType: $entityType, ')
          ..write('operation: $operation, ')
          ..write('operationType: $operationType, ')
          ..write('taskListId: $taskListId, ')
          ..write('taskId: $taskId, ')
          ..write('calendarSourceId: $calendarSourceId, ')
          ..write('providerCalendarId: $providerCalendarId, ')
          ..write('eventId: $eventId, ')
          ..write('localTempId: $localTempId, ')
          ..write('dependsOnOpId: $dependsOnOpId, ')
          ..write('requestJson: $requestJson, ')
          ..write('baselineUpdatedUtc: $baselineUpdatedUtc, ')
          ..write('baselineRawJson: $baselineRawJson, ')
          ..write('attemptCount: $attemptCount, ')
          ..write('nextAttemptAtUtc: $nextAttemptAtUtc, ')
          ..write('lastErrorCode: $lastErrorCode, ')
          ..write('lastErrorMessage: $lastErrorMessage, ')
          ..write('state: $state, ')
          ..write('lastError: $lastError, ')
          ..write('createdAtUtc: $createdAtUtc, ')
          ..write('updatedAtUtc: $updatedAtUtc')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    accountId,
    provider,
    entityType,
    operation,
    operationType,
    taskListId,
    taskId,
    calendarSourceId,
    providerCalendarId,
    eventId,
    localTempId,
    dependsOnOpId,
    requestJson,
    baselineUpdatedUtc,
    baselineRawJson,
    attemptCount,
    nextAttemptAtUtc,
    lastErrorCode,
    lastErrorMessage,
    state,
    lastError,
    createdAtUtc,
    updatedAtUtc,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PendingOp &&
          other.id == this.id &&
          other.accountId == this.accountId &&
          other.provider == this.provider &&
          other.entityType == this.entityType &&
          other.operation == this.operation &&
          other.operationType == this.operationType &&
          other.taskListId == this.taskListId &&
          other.taskId == this.taskId &&
          other.calendarSourceId == this.calendarSourceId &&
          other.providerCalendarId == this.providerCalendarId &&
          other.eventId == this.eventId &&
          other.localTempId == this.localTempId &&
          other.dependsOnOpId == this.dependsOnOpId &&
          other.requestJson == this.requestJson &&
          other.baselineUpdatedUtc == this.baselineUpdatedUtc &&
          other.baselineRawJson == this.baselineRawJson &&
          other.attemptCount == this.attemptCount &&
          other.nextAttemptAtUtc == this.nextAttemptAtUtc &&
          other.lastErrorCode == this.lastErrorCode &&
          other.lastErrorMessage == this.lastErrorMessage &&
          other.state == this.state &&
          other.lastError == this.lastError &&
          other.createdAtUtc == this.createdAtUtc &&
          other.updatedAtUtc == this.updatedAtUtc);
}

class PendingOpsCompanion extends UpdateCompanion<PendingOp> {
  final Value<String> id;
  final Value<String> accountId;
  final Value<String?> provider;
  final Value<String> entityType;
  final Value<String> operation;
  final Value<String?> operationType;
  final Value<String?> taskListId;
  final Value<String?> taskId;
  final Value<String?> calendarSourceId;
  final Value<String?> providerCalendarId;
  final Value<String?> eventId;
  final Value<String?> localTempId;
  final Value<String?> dependsOnOpId;
  final Value<String> requestJson;
  final Value<String?> baselineUpdatedUtc;
  final Value<String?> baselineRawJson;
  final Value<int> attemptCount;
  final Value<String?> nextAttemptAtUtc;
  final Value<String?> lastErrorCode;
  final Value<String?> lastErrorMessage;
  final Value<String> state;
  final Value<String?> lastError;
  final Value<String> createdAtUtc;
  final Value<String> updatedAtUtc;
  final Value<int> rowid;
  const PendingOpsCompanion({
    this.id = const Value.absent(),
    this.accountId = const Value.absent(),
    this.provider = const Value.absent(),
    this.entityType = const Value.absent(),
    this.operation = const Value.absent(),
    this.operationType = const Value.absent(),
    this.taskListId = const Value.absent(),
    this.taskId = const Value.absent(),
    this.calendarSourceId = const Value.absent(),
    this.providerCalendarId = const Value.absent(),
    this.eventId = const Value.absent(),
    this.localTempId = const Value.absent(),
    this.dependsOnOpId = const Value.absent(),
    this.requestJson = const Value.absent(),
    this.baselineUpdatedUtc = const Value.absent(),
    this.baselineRawJson = const Value.absent(),
    this.attemptCount = const Value.absent(),
    this.nextAttemptAtUtc = const Value.absent(),
    this.lastErrorCode = const Value.absent(),
    this.lastErrorMessage = const Value.absent(),
    this.state = const Value.absent(),
    this.lastError = const Value.absent(),
    this.createdAtUtc = const Value.absent(),
    this.updatedAtUtc = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PendingOpsCompanion.insert({
    required String id,
    required String accountId,
    this.provider = const Value.absent(),
    required String entityType,
    required String operation,
    this.operationType = const Value.absent(),
    this.taskListId = const Value.absent(),
    this.taskId = const Value.absent(),
    this.calendarSourceId = const Value.absent(),
    this.providerCalendarId = const Value.absent(),
    this.eventId = const Value.absent(),
    this.localTempId = const Value.absent(),
    this.dependsOnOpId = const Value.absent(),
    required String requestJson,
    this.baselineUpdatedUtc = const Value.absent(),
    this.baselineRawJson = const Value.absent(),
    this.attemptCount = const Value.absent(),
    this.nextAttemptAtUtc = const Value.absent(),
    this.lastErrorCode = const Value.absent(),
    this.lastErrorMessage = const Value.absent(),
    this.state = const Value.absent(),
    this.lastError = const Value.absent(),
    required String createdAtUtc,
    required String updatedAtUtc,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       accountId = Value(accountId),
       entityType = Value(entityType),
       operation = Value(operation),
       requestJson = Value(requestJson),
       createdAtUtc = Value(createdAtUtc),
       updatedAtUtc = Value(updatedAtUtc);
  static Insertable<PendingOp> custom({
    Expression<String>? id,
    Expression<String>? accountId,
    Expression<String>? provider,
    Expression<String>? entityType,
    Expression<String>? operation,
    Expression<String>? operationType,
    Expression<String>? taskListId,
    Expression<String>? taskId,
    Expression<String>? calendarSourceId,
    Expression<String>? providerCalendarId,
    Expression<String>? eventId,
    Expression<String>? localTempId,
    Expression<String>? dependsOnOpId,
    Expression<String>? requestJson,
    Expression<String>? baselineUpdatedUtc,
    Expression<String>? baselineRawJson,
    Expression<int>? attemptCount,
    Expression<String>? nextAttemptAtUtc,
    Expression<String>? lastErrorCode,
    Expression<String>? lastErrorMessage,
    Expression<String>? state,
    Expression<String>? lastError,
    Expression<String>? createdAtUtc,
    Expression<String>? updatedAtUtc,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (accountId != null) 'account_id': accountId,
      if (provider != null) 'provider': provider,
      if (entityType != null) 'entity_type': entityType,
      if (operation != null) 'operation': operation,
      if (operationType != null) 'operation_type': operationType,
      if (taskListId != null) 'task_list_id': taskListId,
      if (taskId != null) 'task_id': taskId,
      if (calendarSourceId != null) 'calendar_source_id': calendarSourceId,
      if (providerCalendarId != null)
        'provider_calendar_id': providerCalendarId,
      if (eventId != null) 'event_id': eventId,
      if (localTempId != null) 'local_temp_id': localTempId,
      if (dependsOnOpId != null) 'depends_on_op_id': dependsOnOpId,
      if (requestJson != null) 'request_json': requestJson,
      if (baselineUpdatedUtc != null)
        'baseline_updated_utc': baselineUpdatedUtc,
      if (baselineRawJson != null) 'baseline_raw_json': baselineRawJson,
      if (attemptCount != null) 'attempt_count': attemptCount,
      if (nextAttemptAtUtc != null) 'next_attempt_at_utc': nextAttemptAtUtc,
      if (lastErrorCode != null) 'last_error_code': lastErrorCode,
      if (lastErrorMessage != null) 'last_error_message': lastErrorMessage,
      if (state != null) 'state': state,
      if (lastError != null) 'last_error': lastError,
      if (createdAtUtc != null) 'created_at_utc': createdAtUtc,
      if (updatedAtUtc != null) 'updated_at_utc': updatedAtUtc,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PendingOpsCompanion copyWith({
    Value<String>? id,
    Value<String>? accountId,
    Value<String?>? provider,
    Value<String>? entityType,
    Value<String>? operation,
    Value<String?>? operationType,
    Value<String?>? taskListId,
    Value<String?>? taskId,
    Value<String?>? calendarSourceId,
    Value<String?>? providerCalendarId,
    Value<String?>? eventId,
    Value<String?>? localTempId,
    Value<String?>? dependsOnOpId,
    Value<String>? requestJson,
    Value<String?>? baselineUpdatedUtc,
    Value<String?>? baselineRawJson,
    Value<int>? attemptCount,
    Value<String?>? nextAttemptAtUtc,
    Value<String?>? lastErrorCode,
    Value<String?>? lastErrorMessage,
    Value<String>? state,
    Value<String?>? lastError,
    Value<String>? createdAtUtc,
    Value<String>? updatedAtUtc,
    Value<int>? rowid,
  }) {
    return PendingOpsCompanion(
      id: id ?? this.id,
      accountId: accountId ?? this.accountId,
      provider: provider ?? this.provider,
      entityType: entityType ?? this.entityType,
      operation: operation ?? this.operation,
      operationType: operationType ?? this.operationType,
      taskListId: taskListId ?? this.taskListId,
      taskId: taskId ?? this.taskId,
      calendarSourceId: calendarSourceId ?? this.calendarSourceId,
      providerCalendarId: providerCalendarId ?? this.providerCalendarId,
      eventId: eventId ?? this.eventId,
      localTempId: localTempId ?? this.localTempId,
      dependsOnOpId: dependsOnOpId ?? this.dependsOnOpId,
      requestJson: requestJson ?? this.requestJson,
      baselineUpdatedUtc: baselineUpdatedUtc ?? this.baselineUpdatedUtc,
      baselineRawJson: baselineRawJson ?? this.baselineRawJson,
      attemptCount: attemptCount ?? this.attemptCount,
      nextAttemptAtUtc: nextAttemptAtUtc ?? this.nextAttemptAtUtc,
      lastErrorCode: lastErrorCode ?? this.lastErrorCode,
      lastErrorMessage: lastErrorMessage ?? this.lastErrorMessage,
      state: state ?? this.state,
      lastError: lastError ?? this.lastError,
      createdAtUtc: createdAtUtc ?? this.createdAtUtc,
      updatedAtUtc: updatedAtUtc ?? this.updatedAtUtc,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (accountId.present) {
      map['account_id'] = Variable<String>(accountId.value);
    }
    if (provider.present) {
      map['provider'] = Variable<String>(provider.value);
    }
    if (entityType.present) {
      map['entity_type'] = Variable<String>(entityType.value);
    }
    if (operation.present) {
      map['operation'] = Variable<String>(operation.value);
    }
    if (operationType.present) {
      map['operation_type'] = Variable<String>(operationType.value);
    }
    if (taskListId.present) {
      map['task_list_id'] = Variable<String>(taskListId.value);
    }
    if (taskId.present) {
      map['task_id'] = Variable<String>(taskId.value);
    }
    if (calendarSourceId.present) {
      map['calendar_source_id'] = Variable<String>(calendarSourceId.value);
    }
    if (providerCalendarId.present) {
      map['provider_calendar_id'] = Variable<String>(providerCalendarId.value);
    }
    if (eventId.present) {
      map['event_id'] = Variable<String>(eventId.value);
    }
    if (localTempId.present) {
      map['local_temp_id'] = Variable<String>(localTempId.value);
    }
    if (dependsOnOpId.present) {
      map['depends_on_op_id'] = Variable<String>(dependsOnOpId.value);
    }
    if (requestJson.present) {
      map['request_json'] = Variable<String>(requestJson.value);
    }
    if (baselineUpdatedUtc.present) {
      map['baseline_updated_utc'] = Variable<String>(baselineUpdatedUtc.value);
    }
    if (baselineRawJson.present) {
      map['baseline_raw_json'] = Variable<String>(baselineRawJson.value);
    }
    if (attemptCount.present) {
      map['attempt_count'] = Variable<int>(attemptCount.value);
    }
    if (nextAttemptAtUtc.present) {
      map['next_attempt_at_utc'] = Variable<String>(nextAttemptAtUtc.value);
    }
    if (lastErrorCode.present) {
      map['last_error_code'] = Variable<String>(lastErrorCode.value);
    }
    if (lastErrorMessage.present) {
      map['last_error_message'] = Variable<String>(lastErrorMessage.value);
    }
    if (state.present) {
      map['state'] = Variable<String>(state.value);
    }
    if (lastError.present) {
      map['last_error'] = Variable<String>(lastError.value);
    }
    if (createdAtUtc.present) {
      map['created_at_utc'] = Variable<String>(createdAtUtc.value);
    }
    if (updatedAtUtc.present) {
      map['updated_at_utc'] = Variable<String>(updatedAtUtc.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PendingOpsCompanion(')
          ..write('id: $id, ')
          ..write('accountId: $accountId, ')
          ..write('provider: $provider, ')
          ..write('entityType: $entityType, ')
          ..write('operation: $operation, ')
          ..write('operationType: $operationType, ')
          ..write('taskListId: $taskListId, ')
          ..write('taskId: $taskId, ')
          ..write('calendarSourceId: $calendarSourceId, ')
          ..write('providerCalendarId: $providerCalendarId, ')
          ..write('eventId: $eventId, ')
          ..write('localTempId: $localTempId, ')
          ..write('dependsOnOpId: $dependsOnOpId, ')
          ..write('requestJson: $requestJson, ')
          ..write('baselineUpdatedUtc: $baselineUpdatedUtc, ')
          ..write('baselineRawJson: $baselineRawJson, ')
          ..write('attemptCount: $attemptCount, ')
          ..write('nextAttemptAtUtc: $nextAttemptAtUtc, ')
          ..write('lastErrorCode: $lastErrorCode, ')
          ..write('lastErrorMessage: $lastErrorMessage, ')
          ..write('state: $state, ')
          ..write('lastError: $lastError, ')
          ..write('createdAtUtc: $createdAtUtc, ')
          ..write('updatedAtUtc: $updatedAtUtc, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SyncRunsTable extends SyncRuns with TableInfo<$SyncRunsTable, SyncRun> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncRunsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _accountIdMeta = const VerificationMeta(
    'accountId',
  );
  @override
  late final GeneratedColumn<String> accountId = GeneratedColumn<String>(
    'account_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES accounts (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _providerMeta = const VerificationMeta(
    'provider',
  );
  @override
  late final GeneratedColumn<String> provider = GeneratedColumn<String>(
    'provider',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _modeMeta = const VerificationMeta('mode');
  @override
  late final GeneratedColumn<String> mode = GeneratedColumn<String>(
    'mode',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startedAtUtcMeta = const VerificationMeta(
    'startedAtUtc',
  );
  @override
  late final GeneratedColumn<String> startedAtUtc = GeneratedColumn<String>(
    'started_at_utc',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _finishedAtUtcMeta = const VerificationMeta(
    'finishedAtUtc',
  );
  @override
  late final GeneratedColumn<String> finishedAtUtc = GeneratedColumn<String>(
    'finished_at_utc',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _taskListsSeenMeta = const VerificationMeta(
    'taskListsSeen',
  );
  @override
  late final GeneratedColumn<int> taskListsSeen = GeneratedColumn<int>(
    'task_lists_seen',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _tasksSeenMeta = const VerificationMeta(
    'tasksSeen',
  );
  @override
  late final GeneratedColumn<int> tasksSeen = GeneratedColumn<int>(
    'tasks_seen',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _pendingOpsAppliedMeta = const VerificationMeta(
    'pendingOpsApplied',
  );
  @override
  late final GeneratedColumn<int> pendingOpsApplied = GeneratedColumn<int>(
    'pending_ops_applied',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _errorCodeMeta = const VerificationMeta(
    'errorCode',
  );
  @override
  late final GeneratedColumn<String> errorCode = GeneratedColumn<String>(
    'error_code',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _errorMessageMeta = const VerificationMeta(
    'errorMessage',
  );
  @override
  late final GeneratedColumn<String> errorMessage = GeneratedColumn<String>(
    'error_message',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    accountId,
    provider,
    mode,
    startedAtUtc,
    finishedAtUtc,
    status,
    taskListsSeen,
    tasksSeen,
    pendingOpsApplied,
    errorCode,
    errorMessage,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_runs';
  @override
  VerificationContext validateIntegrity(
    Insertable<SyncRun> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('account_id')) {
      context.handle(
        _accountIdMeta,
        accountId.isAcceptableOrUnknown(data['account_id']!, _accountIdMeta),
      );
    } else if (isInserting) {
      context.missing(_accountIdMeta);
    }
    if (data.containsKey('provider')) {
      context.handle(
        _providerMeta,
        provider.isAcceptableOrUnknown(data['provider']!, _providerMeta),
      );
    }
    if (data.containsKey('mode')) {
      context.handle(
        _modeMeta,
        mode.isAcceptableOrUnknown(data['mode']!, _modeMeta),
      );
    } else if (isInserting) {
      context.missing(_modeMeta);
    }
    if (data.containsKey('started_at_utc')) {
      context.handle(
        _startedAtUtcMeta,
        startedAtUtc.isAcceptableOrUnknown(
          data['started_at_utc']!,
          _startedAtUtcMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_startedAtUtcMeta);
    }
    if (data.containsKey('finished_at_utc')) {
      context.handle(
        _finishedAtUtcMeta,
        finishedAtUtc.isAcceptableOrUnknown(
          data['finished_at_utc']!,
          _finishedAtUtcMeta,
        ),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('task_lists_seen')) {
      context.handle(
        _taskListsSeenMeta,
        taskListsSeen.isAcceptableOrUnknown(
          data['task_lists_seen']!,
          _taskListsSeenMeta,
        ),
      );
    }
    if (data.containsKey('tasks_seen')) {
      context.handle(
        _tasksSeenMeta,
        tasksSeen.isAcceptableOrUnknown(data['tasks_seen']!, _tasksSeenMeta),
      );
    }
    if (data.containsKey('pending_ops_applied')) {
      context.handle(
        _pendingOpsAppliedMeta,
        pendingOpsApplied.isAcceptableOrUnknown(
          data['pending_ops_applied']!,
          _pendingOpsAppliedMeta,
        ),
      );
    }
    if (data.containsKey('error_code')) {
      context.handle(
        _errorCodeMeta,
        errorCode.isAcceptableOrUnknown(data['error_code']!, _errorCodeMeta),
      );
    }
    if (data.containsKey('error_message')) {
      context.handle(
        _errorMessageMeta,
        errorMessage.isAcceptableOrUnknown(
          data['error_message']!,
          _errorMessageMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SyncRun map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncRun(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      accountId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}account_id'],
      )!,
      provider: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}provider'],
      ),
      mode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mode'],
      )!,
      startedAtUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}started_at_utc'],
      )!,
      finishedAtUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}finished_at_utc'],
      ),
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      taskListsSeen: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}task_lists_seen'],
      )!,
      tasksSeen: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}tasks_seen'],
      )!,
      pendingOpsApplied: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}pending_ops_applied'],
      )!,
      errorCode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}error_code'],
      ),
      errorMessage: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}error_message'],
      ),
    );
  }

  @override
  $SyncRunsTable createAlias(String alias) {
    return $SyncRunsTable(attachedDatabase, alias);
  }
}

class SyncRun extends DataClass implements Insertable<SyncRun> {
  final String id;
  final String accountId;
  final String? provider;
  final String mode;
  final String startedAtUtc;
  final String? finishedAtUtc;
  final String status;
  final int taskListsSeen;
  final int tasksSeen;
  final int pendingOpsApplied;
  final String? errorCode;
  final String? errorMessage;
  const SyncRun({
    required this.id,
    required this.accountId,
    this.provider,
    required this.mode,
    required this.startedAtUtc,
    this.finishedAtUtc,
    required this.status,
    required this.taskListsSeen,
    required this.tasksSeen,
    required this.pendingOpsApplied,
    this.errorCode,
    this.errorMessage,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['account_id'] = Variable<String>(accountId);
    if (!nullToAbsent || provider != null) {
      map['provider'] = Variable<String>(provider);
    }
    map['mode'] = Variable<String>(mode);
    map['started_at_utc'] = Variable<String>(startedAtUtc);
    if (!nullToAbsent || finishedAtUtc != null) {
      map['finished_at_utc'] = Variable<String>(finishedAtUtc);
    }
    map['status'] = Variable<String>(status);
    map['task_lists_seen'] = Variable<int>(taskListsSeen);
    map['tasks_seen'] = Variable<int>(tasksSeen);
    map['pending_ops_applied'] = Variable<int>(pendingOpsApplied);
    if (!nullToAbsent || errorCode != null) {
      map['error_code'] = Variable<String>(errorCode);
    }
    if (!nullToAbsent || errorMessage != null) {
      map['error_message'] = Variable<String>(errorMessage);
    }
    return map;
  }

  SyncRunsCompanion toCompanion(bool nullToAbsent) {
    return SyncRunsCompanion(
      id: Value(id),
      accountId: Value(accountId),
      provider: provider == null && nullToAbsent
          ? const Value.absent()
          : Value(provider),
      mode: Value(mode),
      startedAtUtc: Value(startedAtUtc),
      finishedAtUtc: finishedAtUtc == null && nullToAbsent
          ? const Value.absent()
          : Value(finishedAtUtc),
      status: Value(status),
      taskListsSeen: Value(taskListsSeen),
      tasksSeen: Value(tasksSeen),
      pendingOpsApplied: Value(pendingOpsApplied),
      errorCode: errorCode == null && nullToAbsent
          ? const Value.absent()
          : Value(errorCode),
      errorMessage: errorMessage == null && nullToAbsent
          ? const Value.absent()
          : Value(errorMessage),
    );
  }

  factory SyncRun.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncRun(
      id: serializer.fromJson<String>(json['id']),
      accountId: serializer.fromJson<String>(json['accountId']),
      provider: serializer.fromJson<String?>(json['provider']),
      mode: serializer.fromJson<String>(json['mode']),
      startedAtUtc: serializer.fromJson<String>(json['startedAtUtc']),
      finishedAtUtc: serializer.fromJson<String?>(json['finishedAtUtc']),
      status: serializer.fromJson<String>(json['status']),
      taskListsSeen: serializer.fromJson<int>(json['taskListsSeen']),
      tasksSeen: serializer.fromJson<int>(json['tasksSeen']),
      pendingOpsApplied: serializer.fromJson<int>(json['pendingOpsApplied']),
      errorCode: serializer.fromJson<String?>(json['errorCode']),
      errorMessage: serializer.fromJson<String?>(json['errorMessage']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'accountId': serializer.toJson<String>(accountId),
      'provider': serializer.toJson<String?>(provider),
      'mode': serializer.toJson<String>(mode),
      'startedAtUtc': serializer.toJson<String>(startedAtUtc),
      'finishedAtUtc': serializer.toJson<String?>(finishedAtUtc),
      'status': serializer.toJson<String>(status),
      'taskListsSeen': serializer.toJson<int>(taskListsSeen),
      'tasksSeen': serializer.toJson<int>(tasksSeen),
      'pendingOpsApplied': serializer.toJson<int>(pendingOpsApplied),
      'errorCode': serializer.toJson<String?>(errorCode),
      'errorMessage': serializer.toJson<String?>(errorMessage),
    };
  }

  SyncRun copyWith({
    String? id,
    String? accountId,
    Value<String?> provider = const Value.absent(),
    String? mode,
    String? startedAtUtc,
    Value<String?> finishedAtUtc = const Value.absent(),
    String? status,
    int? taskListsSeen,
    int? tasksSeen,
    int? pendingOpsApplied,
    Value<String?> errorCode = const Value.absent(),
    Value<String?> errorMessage = const Value.absent(),
  }) => SyncRun(
    id: id ?? this.id,
    accountId: accountId ?? this.accountId,
    provider: provider.present ? provider.value : this.provider,
    mode: mode ?? this.mode,
    startedAtUtc: startedAtUtc ?? this.startedAtUtc,
    finishedAtUtc: finishedAtUtc.present
        ? finishedAtUtc.value
        : this.finishedAtUtc,
    status: status ?? this.status,
    taskListsSeen: taskListsSeen ?? this.taskListsSeen,
    tasksSeen: tasksSeen ?? this.tasksSeen,
    pendingOpsApplied: pendingOpsApplied ?? this.pendingOpsApplied,
    errorCode: errorCode.present ? errorCode.value : this.errorCode,
    errorMessage: errorMessage.present ? errorMessage.value : this.errorMessage,
  );
  SyncRun copyWithCompanion(SyncRunsCompanion data) {
    return SyncRun(
      id: data.id.present ? data.id.value : this.id,
      accountId: data.accountId.present ? data.accountId.value : this.accountId,
      provider: data.provider.present ? data.provider.value : this.provider,
      mode: data.mode.present ? data.mode.value : this.mode,
      startedAtUtc: data.startedAtUtc.present
          ? data.startedAtUtc.value
          : this.startedAtUtc,
      finishedAtUtc: data.finishedAtUtc.present
          ? data.finishedAtUtc.value
          : this.finishedAtUtc,
      status: data.status.present ? data.status.value : this.status,
      taskListsSeen: data.taskListsSeen.present
          ? data.taskListsSeen.value
          : this.taskListsSeen,
      tasksSeen: data.tasksSeen.present ? data.tasksSeen.value : this.tasksSeen,
      pendingOpsApplied: data.pendingOpsApplied.present
          ? data.pendingOpsApplied.value
          : this.pendingOpsApplied,
      errorCode: data.errorCode.present ? data.errorCode.value : this.errorCode,
      errorMessage: data.errorMessage.present
          ? data.errorMessage.value
          : this.errorMessage,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncRun(')
          ..write('id: $id, ')
          ..write('accountId: $accountId, ')
          ..write('provider: $provider, ')
          ..write('mode: $mode, ')
          ..write('startedAtUtc: $startedAtUtc, ')
          ..write('finishedAtUtc: $finishedAtUtc, ')
          ..write('status: $status, ')
          ..write('taskListsSeen: $taskListsSeen, ')
          ..write('tasksSeen: $tasksSeen, ')
          ..write('pendingOpsApplied: $pendingOpsApplied, ')
          ..write('errorCode: $errorCode, ')
          ..write('errorMessage: $errorMessage')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    accountId,
    provider,
    mode,
    startedAtUtc,
    finishedAtUtc,
    status,
    taskListsSeen,
    tasksSeen,
    pendingOpsApplied,
    errorCode,
    errorMessage,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncRun &&
          other.id == this.id &&
          other.accountId == this.accountId &&
          other.provider == this.provider &&
          other.mode == this.mode &&
          other.startedAtUtc == this.startedAtUtc &&
          other.finishedAtUtc == this.finishedAtUtc &&
          other.status == this.status &&
          other.taskListsSeen == this.taskListsSeen &&
          other.tasksSeen == this.tasksSeen &&
          other.pendingOpsApplied == this.pendingOpsApplied &&
          other.errorCode == this.errorCode &&
          other.errorMessage == this.errorMessage);
}

class SyncRunsCompanion extends UpdateCompanion<SyncRun> {
  final Value<String> id;
  final Value<String> accountId;
  final Value<String?> provider;
  final Value<String> mode;
  final Value<String> startedAtUtc;
  final Value<String?> finishedAtUtc;
  final Value<String> status;
  final Value<int> taskListsSeen;
  final Value<int> tasksSeen;
  final Value<int> pendingOpsApplied;
  final Value<String?> errorCode;
  final Value<String?> errorMessage;
  final Value<int> rowid;
  const SyncRunsCompanion({
    this.id = const Value.absent(),
    this.accountId = const Value.absent(),
    this.provider = const Value.absent(),
    this.mode = const Value.absent(),
    this.startedAtUtc = const Value.absent(),
    this.finishedAtUtc = const Value.absent(),
    this.status = const Value.absent(),
    this.taskListsSeen = const Value.absent(),
    this.tasksSeen = const Value.absent(),
    this.pendingOpsApplied = const Value.absent(),
    this.errorCode = const Value.absent(),
    this.errorMessage = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SyncRunsCompanion.insert({
    required String id,
    required String accountId,
    this.provider = const Value.absent(),
    required String mode,
    required String startedAtUtc,
    this.finishedAtUtc = const Value.absent(),
    required String status,
    this.taskListsSeen = const Value.absent(),
    this.tasksSeen = const Value.absent(),
    this.pendingOpsApplied = const Value.absent(),
    this.errorCode = const Value.absent(),
    this.errorMessage = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       accountId = Value(accountId),
       mode = Value(mode),
       startedAtUtc = Value(startedAtUtc),
       status = Value(status);
  static Insertable<SyncRun> custom({
    Expression<String>? id,
    Expression<String>? accountId,
    Expression<String>? provider,
    Expression<String>? mode,
    Expression<String>? startedAtUtc,
    Expression<String>? finishedAtUtc,
    Expression<String>? status,
    Expression<int>? taskListsSeen,
    Expression<int>? tasksSeen,
    Expression<int>? pendingOpsApplied,
    Expression<String>? errorCode,
    Expression<String>? errorMessage,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (accountId != null) 'account_id': accountId,
      if (provider != null) 'provider': provider,
      if (mode != null) 'mode': mode,
      if (startedAtUtc != null) 'started_at_utc': startedAtUtc,
      if (finishedAtUtc != null) 'finished_at_utc': finishedAtUtc,
      if (status != null) 'status': status,
      if (taskListsSeen != null) 'task_lists_seen': taskListsSeen,
      if (tasksSeen != null) 'tasks_seen': tasksSeen,
      if (pendingOpsApplied != null) 'pending_ops_applied': pendingOpsApplied,
      if (errorCode != null) 'error_code': errorCode,
      if (errorMessage != null) 'error_message': errorMessage,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SyncRunsCompanion copyWith({
    Value<String>? id,
    Value<String>? accountId,
    Value<String?>? provider,
    Value<String>? mode,
    Value<String>? startedAtUtc,
    Value<String?>? finishedAtUtc,
    Value<String>? status,
    Value<int>? taskListsSeen,
    Value<int>? tasksSeen,
    Value<int>? pendingOpsApplied,
    Value<String?>? errorCode,
    Value<String?>? errorMessage,
    Value<int>? rowid,
  }) {
    return SyncRunsCompanion(
      id: id ?? this.id,
      accountId: accountId ?? this.accountId,
      provider: provider ?? this.provider,
      mode: mode ?? this.mode,
      startedAtUtc: startedAtUtc ?? this.startedAtUtc,
      finishedAtUtc: finishedAtUtc ?? this.finishedAtUtc,
      status: status ?? this.status,
      taskListsSeen: taskListsSeen ?? this.taskListsSeen,
      tasksSeen: tasksSeen ?? this.tasksSeen,
      pendingOpsApplied: pendingOpsApplied ?? this.pendingOpsApplied,
      errorCode: errorCode ?? this.errorCode,
      errorMessage: errorMessage ?? this.errorMessage,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (accountId.present) {
      map['account_id'] = Variable<String>(accountId.value);
    }
    if (provider.present) {
      map['provider'] = Variable<String>(provider.value);
    }
    if (mode.present) {
      map['mode'] = Variable<String>(mode.value);
    }
    if (startedAtUtc.present) {
      map['started_at_utc'] = Variable<String>(startedAtUtc.value);
    }
    if (finishedAtUtc.present) {
      map['finished_at_utc'] = Variable<String>(finishedAtUtc.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (taskListsSeen.present) {
      map['task_lists_seen'] = Variable<int>(taskListsSeen.value);
    }
    if (tasksSeen.present) {
      map['tasks_seen'] = Variable<int>(tasksSeen.value);
    }
    if (pendingOpsApplied.present) {
      map['pending_ops_applied'] = Variable<int>(pendingOpsApplied.value);
    }
    if (errorCode.present) {
      map['error_code'] = Variable<String>(errorCode.value);
    }
    if (errorMessage.present) {
      map['error_message'] = Variable<String>(errorMessage.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncRunsCompanion(')
          ..write('id: $id, ')
          ..write('accountId: $accountId, ')
          ..write('provider: $provider, ')
          ..write('mode: $mode, ')
          ..write('startedAtUtc: $startedAtUtc, ')
          ..write('finishedAtUtc: $finishedAtUtc, ')
          ..write('status: $status, ')
          ..write('taskListsSeen: $taskListsSeen, ')
          ..write('tasksSeen: $tasksSeen, ')
          ..write('pendingOpsApplied: $pendingOpsApplied, ')
          ..write('errorCode: $errorCode, ')
          ..write('errorMessage: $errorMessage, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CalendarSourcesTable extends CalendarSources
    with TableInfo<$CalendarSourcesTable, CalendarSource> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CalendarSourcesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _accountIdMeta = const VerificationMeta(
    'accountId',
  );
  @override
  late final GeneratedColumn<String> accountId = GeneratedColumn<String>(
    'account_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES accounts (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _providerMeta = const VerificationMeta(
    'provider',
  );
  @override
  late final GeneratedColumn<String> provider = GeneratedColumn<String>(
    'provider',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _providerCalendarIdMeta =
      const VerificationMeta('providerCalendarId');
  @override
  late final GeneratedColumn<String> providerCalendarId =
      GeneratedColumn<String>(
        'provider_calendar_id',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _summaryMeta = const VerificationMeta(
    'summary',
  );
  @override
  late final GeneratedColumn<String> summary = GeneratedColumn<String>(
    'summary',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _primaryCalendarMeta = const VerificationMeta(
    'primaryCalendar',
  );
  @override
  late final GeneratedColumn<bool> primaryCalendar = GeneratedColumn<bool>(
    'primary_calendar',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("primary_calendar" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _selectedMeta = const VerificationMeta(
    'selected',
  );
  @override
  late final GeneratedColumn<bool> selected = GeneratedColumn<bool>(
    'selected',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("selected" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _hiddenMeta = const VerificationMeta('hidden');
  @override
  late final GeneratedColumn<bool> hidden = GeneratedColumn<bool>(
    'hidden',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("hidden" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _readOnlyMeta = const VerificationMeta(
    'readOnly',
  );
  @override
  late final GeneratedColumn<bool> readOnly = GeneratedColumn<bool>(
    'read_only',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("read_only" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _backgroundColorMeta = const VerificationMeta(
    'backgroundColor',
  );
  @override
  late final GeneratedColumn<String> backgroundColor = GeneratedColumn<String>(
    'background_color',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _foregroundColorMeta = const VerificationMeta(
    'foregroundColor',
  );
  @override
  late final GeneratedColumn<String> foregroundColor = GeneratedColumn<String>(
    'foreground_color',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _colorIdMeta = const VerificationMeta(
    'colorId',
  );
  @override
  late final GeneratedColumn<String> colorId = GeneratedColumn<String>(
    'color_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _timeZoneMeta = const VerificationMeta(
    'timeZone',
  );
  @override
  late final GeneratedColumn<String> timeZone = GeneratedColumn<String>(
    'time_zone',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _accessRoleMeta = const VerificationMeta(
    'accessRole',
  );
  @override
  late final GeneratedColumn<String> accessRole = GeneratedColumn<String>(
    'access_role',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isDeletedMeta = const VerificationMeta(
    'isDeleted',
  );
  @override
  late final GeneratedColumn<bool> isDeleted = GeneratedColumn<bool>(
    'is_deleted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_deleted" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _rawJsonMeta = const VerificationMeta(
    'rawJson',
  );
  @override
  late final GeneratedColumn<String> rawJson = GeneratedColumn<String>(
    'raw_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtLocalMeta = const VerificationMeta(
    'createdAtLocal',
  );
  @override
  late final GeneratedColumn<int> createdAtLocal = GeneratedColumn<int>(
    'created_at_local',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtLocalMeta = const VerificationMeta(
    'updatedAtLocal',
  );
  @override
  late final GeneratedColumn<int> updatedAtLocal = GeneratedColumn<int>(
    'updated_at_local',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    accountId,
    provider,
    providerCalendarId,
    summary,
    description,
    primaryCalendar,
    selected,
    hidden,
    readOnly,
    backgroundColor,
    foregroundColor,
    colorId,
    timeZone,
    accessRole,
    isDeleted,
    rawJson,
    createdAtLocal,
    updatedAtLocal,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'calendar_sources';
  @override
  VerificationContext validateIntegrity(
    Insertable<CalendarSource> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('account_id')) {
      context.handle(
        _accountIdMeta,
        accountId.isAcceptableOrUnknown(data['account_id']!, _accountIdMeta),
      );
    } else if (isInserting) {
      context.missing(_accountIdMeta);
    }
    if (data.containsKey('provider')) {
      context.handle(
        _providerMeta,
        provider.isAcceptableOrUnknown(data['provider']!, _providerMeta),
      );
    } else if (isInserting) {
      context.missing(_providerMeta);
    }
    if (data.containsKey('provider_calendar_id')) {
      context.handle(
        _providerCalendarIdMeta,
        providerCalendarId.isAcceptableOrUnknown(
          data['provider_calendar_id']!,
          _providerCalendarIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_providerCalendarIdMeta);
    }
    if (data.containsKey('summary')) {
      context.handle(
        _summaryMeta,
        summary.isAcceptableOrUnknown(data['summary']!, _summaryMeta),
      );
    } else if (isInserting) {
      context.missing(_summaryMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    }
    if (data.containsKey('primary_calendar')) {
      context.handle(
        _primaryCalendarMeta,
        primaryCalendar.isAcceptableOrUnknown(
          data['primary_calendar']!,
          _primaryCalendarMeta,
        ),
      );
    }
    if (data.containsKey('selected')) {
      context.handle(
        _selectedMeta,
        selected.isAcceptableOrUnknown(data['selected']!, _selectedMeta),
      );
    }
    if (data.containsKey('hidden')) {
      context.handle(
        _hiddenMeta,
        hidden.isAcceptableOrUnknown(data['hidden']!, _hiddenMeta),
      );
    }
    if (data.containsKey('read_only')) {
      context.handle(
        _readOnlyMeta,
        readOnly.isAcceptableOrUnknown(data['read_only']!, _readOnlyMeta),
      );
    }
    if (data.containsKey('background_color')) {
      context.handle(
        _backgroundColorMeta,
        backgroundColor.isAcceptableOrUnknown(
          data['background_color']!,
          _backgroundColorMeta,
        ),
      );
    }
    if (data.containsKey('foreground_color')) {
      context.handle(
        _foregroundColorMeta,
        foregroundColor.isAcceptableOrUnknown(
          data['foreground_color']!,
          _foregroundColorMeta,
        ),
      );
    }
    if (data.containsKey('color_id')) {
      context.handle(
        _colorIdMeta,
        colorId.isAcceptableOrUnknown(data['color_id']!, _colorIdMeta),
      );
    }
    if (data.containsKey('time_zone')) {
      context.handle(
        _timeZoneMeta,
        timeZone.isAcceptableOrUnknown(data['time_zone']!, _timeZoneMeta),
      );
    }
    if (data.containsKey('access_role')) {
      context.handle(
        _accessRoleMeta,
        accessRole.isAcceptableOrUnknown(data['access_role']!, _accessRoleMeta),
      );
    }
    if (data.containsKey('is_deleted')) {
      context.handle(
        _isDeletedMeta,
        isDeleted.isAcceptableOrUnknown(data['is_deleted']!, _isDeletedMeta),
      );
    }
    if (data.containsKey('raw_json')) {
      context.handle(
        _rawJsonMeta,
        rawJson.isAcceptableOrUnknown(data['raw_json']!, _rawJsonMeta),
      );
    }
    if (data.containsKey('created_at_local')) {
      context.handle(
        _createdAtLocalMeta,
        createdAtLocal.isAcceptableOrUnknown(
          data['created_at_local']!,
          _createdAtLocalMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_createdAtLocalMeta);
    }
    if (data.containsKey('updated_at_local')) {
      context.handle(
        _updatedAtLocalMeta,
        updatedAtLocal.isAcceptableOrUnknown(
          data['updated_at_local']!,
          _updatedAtLocalMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_updatedAtLocalMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CalendarSource map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CalendarSource(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      accountId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}account_id'],
      )!,
      provider: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}provider'],
      )!,
      providerCalendarId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}provider_calendar_id'],
      )!,
      summary: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}summary'],
      )!,
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      ),
      primaryCalendar: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}primary_calendar'],
      )!,
      selected: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}selected'],
      )!,
      hidden: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}hidden'],
      )!,
      readOnly: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}read_only'],
      )!,
      backgroundColor: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}background_color'],
      ),
      foregroundColor: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}foreground_color'],
      ),
      colorId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}color_id'],
      ),
      timeZone: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}time_zone'],
      ),
      accessRole: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}access_role'],
      ),
      isDeleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_deleted'],
      )!,
      rawJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}raw_json'],
      ),
      createdAtLocal: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at_local'],
      )!,
      updatedAtLocal: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at_local'],
      )!,
    );
  }

  @override
  $CalendarSourcesTable createAlias(String alias) {
    return $CalendarSourcesTable(attachedDatabase, alias);
  }
}

class CalendarSource extends DataClass implements Insertable<CalendarSource> {
  final String id;
  final String accountId;
  final String provider;
  final String providerCalendarId;
  final String summary;
  final String? description;
  final bool primaryCalendar;
  final bool selected;
  final bool hidden;
  final bool readOnly;
  final String? backgroundColor;
  final String? foregroundColor;
  final String? colorId;
  final String? timeZone;
  final String? accessRole;
  final bool isDeleted;
  final String? rawJson;
  final int createdAtLocal;
  final int updatedAtLocal;
  const CalendarSource({
    required this.id,
    required this.accountId,
    required this.provider,
    required this.providerCalendarId,
    required this.summary,
    this.description,
    required this.primaryCalendar,
    required this.selected,
    required this.hidden,
    required this.readOnly,
    this.backgroundColor,
    this.foregroundColor,
    this.colorId,
    this.timeZone,
    this.accessRole,
    required this.isDeleted,
    this.rawJson,
    required this.createdAtLocal,
    required this.updatedAtLocal,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['account_id'] = Variable<String>(accountId);
    map['provider'] = Variable<String>(provider);
    map['provider_calendar_id'] = Variable<String>(providerCalendarId);
    map['summary'] = Variable<String>(summary);
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    map['primary_calendar'] = Variable<bool>(primaryCalendar);
    map['selected'] = Variable<bool>(selected);
    map['hidden'] = Variable<bool>(hidden);
    map['read_only'] = Variable<bool>(readOnly);
    if (!nullToAbsent || backgroundColor != null) {
      map['background_color'] = Variable<String>(backgroundColor);
    }
    if (!nullToAbsent || foregroundColor != null) {
      map['foreground_color'] = Variable<String>(foregroundColor);
    }
    if (!nullToAbsent || colorId != null) {
      map['color_id'] = Variable<String>(colorId);
    }
    if (!nullToAbsent || timeZone != null) {
      map['time_zone'] = Variable<String>(timeZone);
    }
    if (!nullToAbsent || accessRole != null) {
      map['access_role'] = Variable<String>(accessRole);
    }
    map['is_deleted'] = Variable<bool>(isDeleted);
    if (!nullToAbsent || rawJson != null) {
      map['raw_json'] = Variable<String>(rawJson);
    }
    map['created_at_local'] = Variable<int>(createdAtLocal);
    map['updated_at_local'] = Variable<int>(updatedAtLocal);
    return map;
  }

  CalendarSourcesCompanion toCompanion(bool nullToAbsent) {
    return CalendarSourcesCompanion(
      id: Value(id),
      accountId: Value(accountId),
      provider: Value(provider),
      providerCalendarId: Value(providerCalendarId),
      summary: Value(summary),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
      primaryCalendar: Value(primaryCalendar),
      selected: Value(selected),
      hidden: Value(hidden),
      readOnly: Value(readOnly),
      backgroundColor: backgroundColor == null && nullToAbsent
          ? const Value.absent()
          : Value(backgroundColor),
      foregroundColor: foregroundColor == null && nullToAbsent
          ? const Value.absent()
          : Value(foregroundColor),
      colorId: colorId == null && nullToAbsent
          ? const Value.absent()
          : Value(colorId),
      timeZone: timeZone == null && nullToAbsent
          ? const Value.absent()
          : Value(timeZone),
      accessRole: accessRole == null && nullToAbsent
          ? const Value.absent()
          : Value(accessRole),
      isDeleted: Value(isDeleted),
      rawJson: rawJson == null && nullToAbsent
          ? const Value.absent()
          : Value(rawJson),
      createdAtLocal: Value(createdAtLocal),
      updatedAtLocal: Value(updatedAtLocal),
    );
  }

  factory CalendarSource.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CalendarSource(
      id: serializer.fromJson<String>(json['id']),
      accountId: serializer.fromJson<String>(json['accountId']),
      provider: serializer.fromJson<String>(json['provider']),
      providerCalendarId: serializer.fromJson<String>(
        json['providerCalendarId'],
      ),
      summary: serializer.fromJson<String>(json['summary']),
      description: serializer.fromJson<String?>(json['description']),
      primaryCalendar: serializer.fromJson<bool>(json['primaryCalendar']),
      selected: serializer.fromJson<bool>(json['selected']),
      hidden: serializer.fromJson<bool>(json['hidden']),
      readOnly: serializer.fromJson<bool>(json['readOnly']),
      backgroundColor: serializer.fromJson<String?>(json['backgroundColor']),
      foregroundColor: serializer.fromJson<String?>(json['foregroundColor']),
      colorId: serializer.fromJson<String?>(json['colorId']),
      timeZone: serializer.fromJson<String?>(json['timeZone']),
      accessRole: serializer.fromJson<String?>(json['accessRole']),
      isDeleted: serializer.fromJson<bool>(json['isDeleted']),
      rawJson: serializer.fromJson<String?>(json['rawJson']),
      createdAtLocal: serializer.fromJson<int>(json['createdAtLocal']),
      updatedAtLocal: serializer.fromJson<int>(json['updatedAtLocal']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'accountId': serializer.toJson<String>(accountId),
      'provider': serializer.toJson<String>(provider),
      'providerCalendarId': serializer.toJson<String>(providerCalendarId),
      'summary': serializer.toJson<String>(summary),
      'description': serializer.toJson<String?>(description),
      'primaryCalendar': serializer.toJson<bool>(primaryCalendar),
      'selected': serializer.toJson<bool>(selected),
      'hidden': serializer.toJson<bool>(hidden),
      'readOnly': serializer.toJson<bool>(readOnly),
      'backgroundColor': serializer.toJson<String?>(backgroundColor),
      'foregroundColor': serializer.toJson<String?>(foregroundColor),
      'colorId': serializer.toJson<String?>(colorId),
      'timeZone': serializer.toJson<String?>(timeZone),
      'accessRole': serializer.toJson<String?>(accessRole),
      'isDeleted': serializer.toJson<bool>(isDeleted),
      'rawJson': serializer.toJson<String?>(rawJson),
      'createdAtLocal': serializer.toJson<int>(createdAtLocal),
      'updatedAtLocal': serializer.toJson<int>(updatedAtLocal),
    };
  }

  CalendarSource copyWith({
    String? id,
    String? accountId,
    String? provider,
    String? providerCalendarId,
    String? summary,
    Value<String?> description = const Value.absent(),
    bool? primaryCalendar,
    bool? selected,
    bool? hidden,
    bool? readOnly,
    Value<String?> backgroundColor = const Value.absent(),
    Value<String?> foregroundColor = const Value.absent(),
    Value<String?> colorId = const Value.absent(),
    Value<String?> timeZone = const Value.absent(),
    Value<String?> accessRole = const Value.absent(),
    bool? isDeleted,
    Value<String?> rawJson = const Value.absent(),
    int? createdAtLocal,
    int? updatedAtLocal,
  }) => CalendarSource(
    id: id ?? this.id,
    accountId: accountId ?? this.accountId,
    provider: provider ?? this.provider,
    providerCalendarId: providerCalendarId ?? this.providerCalendarId,
    summary: summary ?? this.summary,
    description: description.present ? description.value : this.description,
    primaryCalendar: primaryCalendar ?? this.primaryCalendar,
    selected: selected ?? this.selected,
    hidden: hidden ?? this.hidden,
    readOnly: readOnly ?? this.readOnly,
    backgroundColor: backgroundColor.present
        ? backgroundColor.value
        : this.backgroundColor,
    foregroundColor: foregroundColor.present
        ? foregroundColor.value
        : this.foregroundColor,
    colorId: colorId.present ? colorId.value : this.colorId,
    timeZone: timeZone.present ? timeZone.value : this.timeZone,
    accessRole: accessRole.present ? accessRole.value : this.accessRole,
    isDeleted: isDeleted ?? this.isDeleted,
    rawJson: rawJson.present ? rawJson.value : this.rawJson,
    createdAtLocal: createdAtLocal ?? this.createdAtLocal,
    updatedAtLocal: updatedAtLocal ?? this.updatedAtLocal,
  );
  CalendarSource copyWithCompanion(CalendarSourcesCompanion data) {
    return CalendarSource(
      id: data.id.present ? data.id.value : this.id,
      accountId: data.accountId.present ? data.accountId.value : this.accountId,
      provider: data.provider.present ? data.provider.value : this.provider,
      providerCalendarId: data.providerCalendarId.present
          ? data.providerCalendarId.value
          : this.providerCalendarId,
      summary: data.summary.present ? data.summary.value : this.summary,
      description: data.description.present
          ? data.description.value
          : this.description,
      primaryCalendar: data.primaryCalendar.present
          ? data.primaryCalendar.value
          : this.primaryCalendar,
      selected: data.selected.present ? data.selected.value : this.selected,
      hidden: data.hidden.present ? data.hidden.value : this.hidden,
      readOnly: data.readOnly.present ? data.readOnly.value : this.readOnly,
      backgroundColor: data.backgroundColor.present
          ? data.backgroundColor.value
          : this.backgroundColor,
      foregroundColor: data.foregroundColor.present
          ? data.foregroundColor.value
          : this.foregroundColor,
      colorId: data.colorId.present ? data.colorId.value : this.colorId,
      timeZone: data.timeZone.present ? data.timeZone.value : this.timeZone,
      accessRole: data.accessRole.present
          ? data.accessRole.value
          : this.accessRole,
      isDeleted: data.isDeleted.present ? data.isDeleted.value : this.isDeleted,
      rawJson: data.rawJson.present ? data.rawJson.value : this.rawJson,
      createdAtLocal: data.createdAtLocal.present
          ? data.createdAtLocal.value
          : this.createdAtLocal,
      updatedAtLocal: data.updatedAtLocal.present
          ? data.updatedAtLocal.value
          : this.updatedAtLocal,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CalendarSource(')
          ..write('id: $id, ')
          ..write('accountId: $accountId, ')
          ..write('provider: $provider, ')
          ..write('providerCalendarId: $providerCalendarId, ')
          ..write('summary: $summary, ')
          ..write('description: $description, ')
          ..write('primaryCalendar: $primaryCalendar, ')
          ..write('selected: $selected, ')
          ..write('hidden: $hidden, ')
          ..write('readOnly: $readOnly, ')
          ..write('backgroundColor: $backgroundColor, ')
          ..write('foregroundColor: $foregroundColor, ')
          ..write('colorId: $colorId, ')
          ..write('timeZone: $timeZone, ')
          ..write('accessRole: $accessRole, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('rawJson: $rawJson, ')
          ..write('createdAtLocal: $createdAtLocal, ')
          ..write('updatedAtLocal: $updatedAtLocal')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    accountId,
    provider,
    providerCalendarId,
    summary,
    description,
    primaryCalendar,
    selected,
    hidden,
    readOnly,
    backgroundColor,
    foregroundColor,
    colorId,
    timeZone,
    accessRole,
    isDeleted,
    rawJson,
    createdAtLocal,
    updatedAtLocal,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CalendarSource &&
          other.id == this.id &&
          other.accountId == this.accountId &&
          other.provider == this.provider &&
          other.providerCalendarId == this.providerCalendarId &&
          other.summary == this.summary &&
          other.description == this.description &&
          other.primaryCalendar == this.primaryCalendar &&
          other.selected == this.selected &&
          other.hidden == this.hidden &&
          other.readOnly == this.readOnly &&
          other.backgroundColor == this.backgroundColor &&
          other.foregroundColor == this.foregroundColor &&
          other.colorId == this.colorId &&
          other.timeZone == this.timeZone &&
          other.accessRole == this.accessRole &&
          other.isDeleted == this.isDeleted &&
          other.rawJson == this.rawJson &&
          other.createdAtLocal == this.createdAtLocal &&
          other.updatedAtLocal == this.updatedAtLocal);
}

class CalendarSourcesCompanion extends UpdateCompanion<CalendarSource> {
  final Value<String> id;
  final Value<String> accountId;
  final Value<String> provider;
  final Value<String> providerCalendarId;
  final Value<String> summary;
  final Value<String?> description;
  final Value<bool> primaryCalendar;
  final Value<bool> selected;
  final Value<bool> hidden;
  final Value<bool> readOnly;
  final Value<String?> backgroundColor;
  final Value<String?> foregroundColor;
  final Value<String?> colorId;
  final Value<String?> timeZone;
  final Value<String?> accessRole;
  final Value<bool> isDeleted;
  final Value<String?> rawJson;
  final Value<int> createdAtLocal;
  final Value<int> updatedAtLocal;
  final Value<int> rowid;
  const CalendarSourcesCompanion({
    this.id = const Value.absent(),
    this.accountId = const Value.absent(),
    this.provider = const Value.absent(),
    this.providerCalendarId = const Value.absent(),
    this.summary = const Value.absent(),
    this.description = const Value.absent(),
    this.primaryCalendar = const Value.absent(),
    this.selected = const Value.absent(),
    this.hidden = const Value.absent(),
    this.readOnly = const Value.absent(),
    this.backgroundColor = const Value.absent(),
    this.foregroundColor = const Value.absent(),
    this.colorId = const Value.absent(),
    this.timeZone = const Value.absent(),
    this.accessRole = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.rawJson = const Value.absent(),
    this.createdAtLocal = const Value.absent(),
    this.updatedAtLocal = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CalendarSourcesCompanion.insert({
    required String id,
    required String accountId,
    required String provider,
    required String providerCalendarId,
    required String summary,
    this.description = const Value.absent(),
    this.primaryCalendar = const Value.absent(),
    this.selected = const Value.absent(),
    this.hidden = const Value.absent(),
    this.readOnly = const Value.absent(),
    this.backgroundColor = const Value.absent(),
    this.foregroundColor = const Value.absent(),
    this.colorId = const Value.absent(),
    this.timeZone = const Value.absent(),
    this.accessRole = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.rawJson = const Value.absent(),
    required int createdAtLocal,
    required int updatedAtLocal,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       accountId = Value(accountId),
       provider = Value(provider),
       providerCalendarId = Value(providerCalendarId),
       summary = Value(summary),
       createdAtLocal = Value(createdAtLocal),
       updatedAtLocal = Value(updatedAtLocal);
  static Insertable<CalendarSource> custom({
    Expression<String>? id,
    Expression<String>? accountId,
    Expression<String>? provider,
    Expression<String>? providerCalendarId,
    Expression<String>? summary,
    Expression<String>? description,
    Expression<bool>? primaryCalendar,
    Expression<bool>? selected,
    Expression<bool>? hidden,
    Expression<bool>? readOnly,
    Expression<String>? backgroundColor,
    Expression<String>? foregroundColor,
    Expression<String>? colorId,
    Expression<String>? timeZone,
    Expression<String>? accessRole,
    Expression<bool>? isDeleted,
    Expression<String>? rawJson,
    Expression<int>? createdAtLocal,
    Expression<int>? updatedAtLocal,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (accountId != null) 'account_id': accountId,
      if (provider != null) 'provider': provider,
      if (providerCalendarId != null)
        'provider_calendar_id': providerCalendarId,
      if (summary != null) 'summary': summary,
      if (description != null) 'description': description,
      if (primaryCalendar != null) 'primary_calendar': primaryCalendar,
      if (selected != null) 'selected': selected,
      if (hidden != null) 'hidden': hidden,
      if (readOnly != null) 'read_only': readOnly,
      if (backgroundColor != null) 'background_color': backgroundColor,
      if (foregroundColor != null) 'foreground_color': foregroundColor,
      if (colorId != null) 'color_id': colorId,
      if (timeZone != null) 'time_zone': timeZone,
      if (accessRole != null) 'access_role': accessRole,
      if (isDeleted != null) 'is_deleted': isDeleted,
      if (rawJson != null) 'raw_json': rawJson,
      if (createdAtLocal != null) 'created_at_local': createdAtLocal,
      if (updatedAtLocal != null) 'updated_at_local': updatedAtLocal,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CalendarSourcesCompanion copyWith({
    Value<String>? id,
    Value<String>? accountId,
    Value<String>? provider,
    Value<String>? providerCalendarId,
    Value<String>? summary,
    Value<String?>? description,
    Value<bool>? primaryCalendar,
    Value<bool>? selected,
    Value<bool>? hidden,
    Value<bool>? readOnly,
    Value<String?>? backgroundColor,
    Value<String?>? foregroundColor,
    Value<String?>? colorId,
    Value<String?>? timeZone,
    Value<String?>? accessRole,
    Value<bool>? isDeleted,
    Value<String?>? rawJson,
    Value<int>? createdAtLocal,
    Value<int>? updatedAtLocal,
    Value<int>? rowid,
  }) {
    return CalendarSourcesCompanion(
      id: id ?? this.id,
      accountId: accountId ?? this.accountId,
      provider: provider ?? this.provider,
      providerCalendarId: providerCalendarId ?? this.providerCalendarId,
      summary: summary ?? this.summary,
      description: description ?? this.description,
      primaryCalendar: primaryCalendar ?? this.primaryCalendar,
      selected: selected ?? this.selected,
      hidden: hidden ?? this.hidden,
      readOnly: readOnly ?? this.readOnly,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      foregroundColor: foregroundColor ?? this.foregroundColor,
      colorId: colorId ?? this.colorId,
      timeZone: timeZone ?? this.timeZone,
      accessRole: accessRole ?? this.accessRole,
      isDeleted: isDeleted ?? this.isDeleted,
      rawJson: rawJson ?? this.rawJson,
      createdAtLocal: createdAtLocal ?? this.createdAtLocal,
      updatedAtLocal: updatedAtLocal ?? this.updatedAtLocal,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (accountId.present) {
      map['account_id'] = Variable<String>(accountId.value);
    }
    if (provider.present) {
      map['provider'] = Variable<String>(provider.value);
    }
    if (providerCalendarId.present) {
      map['provider_calendar_id'] = Variable<String>(providerCalendarId.value);
    }
    if (summary.present) {
      map['summary'] = Variable<String>(summary.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (primaryCalendar.present) {
      map['primary_calendar'] = Variable<bool>(primaryCalendar.value);
    }
    if (selected.present) {
      map['selected'] = Variable<bool>(selected.value);
    }
    if (hidden.present) {
      map['hidden'] = Variable<bool>(hidden.value);
    }
    if (readOnly.present) {
      map['read_only'] = Variable<bool>(readOnly.value);
    }
    if (backgroundColor.present) {
      map['background_color'] = Variable<String>(backgroundColor.value);
    }
    if (foregroundColor.present) {
      map['foreground_color'] = Variable<String>(foregroundColor.value);
    }
    if (colorId.present) {
      map['color_id'] = Variable<String>(colorId.value);
    }
    if (timeZone.present) {
      map['time_zone'] = Variable<String>(timeZone.value);
    }
    if (accessRole.present) {
      map['access_role'] = Variable<String>(accessRole.value);
    }
    if (isDeleted.present) {
      map['is_deleted'] = Variable<bool>(isDeleted.value);
    }
    if (rawJson.present) {
      map['raw_json'] = Variable<String>(rawJson.value);
    }
    if (createdAtLocal.present) {
      map['created_at_local'] = Variable<int>(createdAtLocal.value);
    }
    if (updatedAtLocal.present) {
      map['updated_at_local'] = Variable<int>(updatedAtLocal.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CalendarSourcesCompanion(')
          ..write('id: $id, ')
          ..write('accountId: $accountId, ')
          ..write('provider: $provider, ')
          ..write('providerCalendarId: $providerCalendarId, ')
          ..write('summary: $summary, ')
          ..write('description: $description, ')
          ..write('primaryCalendar: $primaryCalendar, ')
          ..write('selected: $selected, ')
          ..write('hidden: $hidden, ')
          ..write('readOnly: $readOnly, ')
          ..write('backgroundColor: $backgroundColor, ')
          ..write('foregroundColor: $foregroundColor, ')
          ..write('colorId: $colorId, ')
          ..write('timeZone: $timeZone, ')
          ..write('accessRole: $accessRole, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('rawJson: $rawJson, ')
          ..write('createdAtLocal: $createdAtLocal, ')
          ..write('updatedAtLocal: $updatedAtLocal, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CalendarEventsTable extends CalendarEvents
    with TableInfo<$CalendarEventsTable, CalendarEvent> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CalendarEventsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _accountIdMeta = const VerificationMeta(
    'accountId',
  );
  @override
  late final GeneratedColumn<String> accountId = GeneratedColumn<String>(
    'account_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES accounts (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _calendarSourceIdMeta = const VerificationMeta(
    'calendarSourceId',
  );
  @override
  late final GeneratedColumn<String> calendarSourceId = GeneratedColumn<String>(
    'calendar_source_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES calendar_sources (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _providerMeta = const VerificationMeta(
    'provider',
  );
  @override
  late final GeneratedColumn<String> provider = GeneratedColumn<String>(
    'provider',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _providerCalendarIdMeta =
      const VerificationMeta('providerCalendarId');
  @override
  late final GeneratedColumn<String> providerCalendarId =
      GeneratedColumn<String>(
        'provider_calendar_id',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _providerEventIdMeta = const VerificationMeta(
    'providerEventId',
  );
  @override
  late final GeneratedColumn<String> providerEventId = GeneratedColumn<String>(
    'provider_event_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _providerRecurringEventIdMeta =
      const VerificationMeta('providerRecurringEventId');
  @override
  late final GeneratedColumn<String> providerRecurringEventId =
      GeneratedColumn<String>(
        'provider_recurring_event_id',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _providerOriginalStartKeyMeta =
      const VerificationMeta('providerOriginalStartKey');
  @override
  late final GeneratedColumn<String> providerOriginalStartKey =
      GeneratedColumn<String>(
        'provider_original_start_key',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _etagOrChangeKeyMeta = const VerificationMeta(
    'etagOrChangeKey',
  );
  @override
  late final GeneratedColumn<String> etagOrChangeKey = GeneratedColumn<String>(
    'etag_or_change_key',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _locationMeta = const VerificationMeta(
    'location',
  );
  @override
  late final GeneratedColumn<String> location = GeneratedColumn<String>(
    'location',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _allDayMeta = const VerificationMeta('allDay');
  @override
  late final GeneratedColumn<bool> allDay = GeneratedColumn<bool>(
    'all_day',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("all_day" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _startDateMeta = const VerificationMeta(
    'startDate',
  );
  @override
  late final GeneratedColumn<String> startDate = GeneratedColumn<String>(
    'start_date',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _startDateTimeMeta = const VerificationMeta(
    'startDateTime',
  );
  @override
  late final GeneratedColumn<String> startDateTime = GeneratedColumn<String>(
    'start_date_time',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _startTimeZoneMeta = const VerificationMeta(
    'startTimeZone',
  );
  @override
  late final GeneratedColumn<String> startTimeZone = GeneratedColumn<String>(
    'start_time_zone',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _endDateMeta = const VerificationMeta(
    'endDate',
  );
  @override
  late final GeneratedColumn<String> endDate = GeneratedColumn<String>(
    'end_date',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _endDateTimeMeta = const VerificationMeta(
    'endDateTime',
  );
  @override
  late final GeneratedColumn<String> endDateTime = GeneratedColumn<String>(
    'end_date_time',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _endTimeZoneMeta = const VerificationMeta(
    'endTimeZone',
  );
  @override
  late final GeneratedColumn<String> endTimeZone = GeneratedColumn<String>(
    'end_time_zone',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _recurrenceJsonMeta = const VerificationMeta(
    'recurrenceJson',
  );
  @override
  late final GeneratedColumn<String> recurrenceJson = GeneratedColumn<String>(
    'recurrence_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _remindersJsonMeta = const VerificationMeta(
    'remindersJson',
  );
  @override
  late final GeneratedColumn<String> remindersJson = GeneratedColumn<String>(
    'reminders_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _attendeesJsonMeta = const VerificationMeta(
    'attendeesJson',
  );
  @override
  late final GeneratedColumn<String> attendeesJson = GeneratedColumn<String>(
    'attendees_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _categoriesJsonMeta = const VerificationMeta(
    'categoriesJson',
  );
  @override
  late final GeneratedColumn<String> categoriesJson = GeneratedColumn<String>(
    'categories_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _organizerJsonMeta = const VerificationMeta(
    'organizerJson',
  );
  @override
  late final GeneratedColumn<String> organizerJson = GeneratedColumn<String>(
    'organizer_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _creatorJsonMeta = const VerificationMeta(
    'creatorJson',
  );
  @override
  late final GeneratedColumn<String> creatorJson = GeneratedColumn<String>(
    'creator_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _colorIdMeta = const VerificationMeta(
    'colorId',
  );
  @override
  late final GeneratedColumn<String> colorId = GeneratedColumn<String>(
    'color_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _colorHexMeta = const VerificationMeta(
    'colorHex',
  );
  @override
  late final GeneratedColumn<String> colorHex = GeneratedColumn<String>(
    'color_hex',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _visibilityMeta = const VerificationMeta(
    'visibility',
  );
  @override
  late final GeneratedColumn<String> visibility = GeneratedColumn<String>(
    'visibility',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _transparencyOrShowAsMeta =
      const VerificationMeta('transparencyOrShowAs');
  @override
  late final GeneratedColumn<String> transparencyOrShowAs =
      GeneratedColumn<String>(
        'transparency_or_show_as',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _eventTypeMeta = const VerificationMeta(
    'eventType',
  );
  @override
  late final GeneratedColumn<String> eventType = GeneratedColumn<String>(
    'event_type',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _webLinkMeta = const VerificationMeta(
    'webLink',
  );
  @override
  late final GeneratedColumn<String> webLink = GeneratedColumn<String>(
    'web_link',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _conferenceJsonMeta = const VerificationMeta(
    'conferenceJson',
  );
  @override
  late final GeneratedColumn<String> conferenceJson = GeneratedColumn<String>(
    'conference_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _attachmentsJsonMeta = const VerificationMeta(
    'attachmentsJson',
  );
  @override
  late final GeneratedColumn<String> attachmentsJson = GeneratedColumn<String>(
    'attachments_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isCancelledMeta = const VerificationMeta(
    'isCancelled',
  );
  @override
  late final GeneratedColumn<bool> isCancelled = GeneratedColumn<bool>(
    'is_cancelled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_cancelled" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _isDeletedMeta = const VerificationMeta(
    'isDeleted',
  );
  @override
  late final GeneratedColumn<bool> isDeleted = GeneratedColumn<bool>(
    'is_deleted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_deleted" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _rawJsonMeta = const VerificationMeta(
    'rawJson',
  );
  @override
  late final GeneratedColumn<String> rawJson = GeneratedColumn<String>(
    'raw_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtServerMeta = const VerificationMeta(
    'createdAtServer',
  );
  @override
  late final GeneratedColumn<String> createdAtServer = GeneratedColumn<String>(
    'created_at_server',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _updatedAtServerMeta = const VerificationMeta(
    'updatedAtServer',
  );
  @override
  late final GeneratedColumn<String> updatedAtServer = GeneratedColumn<String>(
    'updated_at_server',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtLocalMeta = const VerificationMeta(
    'createdAtLocal',
  );
  @override
  late final GeneratedColumn<int> createdAtLocal = GeneratedColumn<int>(
    'created_at_local',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtLocalMeta = const VerificationMeta(
    'updatedAtLocal',
  );
  @override
  late final GeneratedColumn<int> updatedAtLocal = GeneratedColumn<int>(
    'updated_at_local',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _syncStatusMeta = const VerificationMeta(
    'syncStatus',
  );
  @override
  late final GeneratedColumn<String> syncStatus = GeneratedColumn<String>(
    'sync_status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('synced'),
  );
  static const VerificationMeta _baselineRawJsonMeta = const VerificationMeta(
    'baselineRawJson',
  );
  @override
  late final GeneratedColumn<String> baselineRawJson = GeneratedColumn<String>(
    'baseline_raw_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    accountId,
    calendarSourceId,
    provider,
    providerCalendarId,
    providerEventId,
    providerRecurringEventId,
    providerOriginalStartKey,
    etagOrChangeKey,
    status,
    title,
    description,
    location,
    allDay,
    startDate,
    startDateTime,
    startTimeZone,
    endDate,
    endDateTime,
    endTimeZone,
    recurrenceJson,
    remindersJson,
    attendeesJson,
    categoriesJson,
    organizerJson,
    creatorJson,
    colorId,
    colorHex,
    visibility,
    transparencyOrShowAs,
    eventType,
    webLink,
    conferenceJson,
    attachmentsJson,
    isCancelled,
    isDeleted,
    rawJson,
    createdAtServer,
    updatedAtServer,
    createdAtLocal,
    updatedAtLocal,
    syncStatus,
    baselineRawJson,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'calendar_events';
  @override
  VerificationContext validateIntegrity(
    Insertable<CalendarEvent> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('account_id')) {
      context.handle(
        _accountIdMeta,
        accountId.isAcceptableOrUnknown(data['account_id']!, _accountIdMeta),
      );
    } else if (isInserting) {
      context.missing(_accountIdMeta);
    }
    if (data.containsKey('calendar_source_id')) {
      context.handle(
        _calendarSourceIdMeta,
        calendarSourceId.isAcceptableOrUnknown(
          data['calendar_source_id']!,
          _calendarSourceIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_calendarSourceIdMeta);
    }
    if (data.containsKey('provider')) {
      context.handle(
        _providerMeta,
        provider.isAcceptableOrUnknown(data['provider']!, _providerMeta),
      );
    } else if (isInserting) {
      context.missing(_providerMeta);
    }
    if (data.containsKey('provider_calendar_id')) {
      context.handle(
        _providerCalendarIdMeta,
        providerCalendarId.isAcceptableOrUnknown(
          data['provider_calendar_id']!,
          _providerCalendarIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_providerCalendarIdMeta);
    }
    if (data.containsKey('provider_event_id')) {
      context.handle(
        _providerEventIdMeta,
        providerEventId.isAcceptableOrUnknown(
          data['provider_event_id']!,
          _providerEventIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_providerEventIdMeta);
    }
    if (data.containsKey('provider_recurring_event_id')) {
      context.handle(
        _providerRecurringEventIdMeta,
        providerRecurringEventId.isAcceptableOrUnknown(
          data['provider_recurring_event_id']!,
          _providerRecurringEventIdMeta,
        ),
      );
    }
    if (data.containsKey('provider_original_start_key')) {
      context.handle(
        _providerOriginalStartKeyMeta,
        providerOriginalStartKey.isAcceptableOrUnknown(
          data['provider_original_start_key']!,
          _providerOriginalStartKeyMeta,
        ),
      );
    }
    if (data.containsKey('etag_or_change_key')) {
      context.handle(
        _etagOrChangeKeyMeta,
        etagOrChangeKey.isAcceptableOrUnknown(
          data['etag_or_change_key']!,
          _etagOrChangeKeyMeta,
        ),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    }
    if (data.containsKey('location')) {
      context.handle(
        _locationMeta,
        location.isAcceptableOrUnknown(data['location']!, _locationMeta),
      );
    }
    if (data.containsKey('all_day')) {
      context.handle(
        _allDayMeta,
        allDay.isAcceptableOrUnknown(data['all_day']!, _allDayMeta),
      );
    }
    if (data.containsKey('start_date')) {
      context.handle(
        _startDateMeta,
        startDate.isAcceptableOrUnknown(data['start_date']!, _startDateMeta),
      );
    }
    if (data.containsKey('start_date_time')) {
      context.handle(
        _startDateTimeMeta,
        startDateTime.isAcceptableOrUnknown(
          data['start_date_time']!,
          _startDateTimeMeta,
        ),
      );
    }
    if (data.containsKey('start_time_zone')) {
      context.handle(
        _startTimeZoneMeta,
        startTimeZone.isAcceptableOrUnknown(
          data['start_time_zone']!,
          _startTimeZoneMeta,
        ),
      );
    }
    if (data.containsKey('end_date')) {
      context.handle(
        _endDateMeta,
        endDate.isAcceptableOrUnknown(data['end_date']!, _endDateMeta),
      );
    }
    if (data.containsKey('end_date_time')) {
      context.handle(
        _endDateTimeMeta,
        endDateTime.isAcceptableOrUnknown(
          data['end_date_time']!,
          _endDateTimeMeta,
        ),
      );
    }
    if (data.containsKey('end_time_zone')) {
      context.handle(
        _endTimeZoneMeta,
        endTimeZone.isAcceptableOrUnknown(
          data['end_time_zone']!,
          _endTimeZoneMeta,
        ),
      );
    }
    if (data.containsKey('recurrence_json')) {
      context.handle(
        _recurrenceJsonMeta,
        recurrenceJson.isAcceptableOrUnknown(
          data['recurrence_json']!,
          _recurrenceJsonMeta,
        ),
      );
    }
    if (data.containsKey('reminders_json')) {
      context.handle(
        _remindersJsonMeta,
        remindersJson.isAcceptableOrUnknown(
          data['reminders_json']!,
          _remindersJsonMeta,
        ),
      );
    }
    if (data.containsKey('attendees_json')) {
      context.handle(
        _attendeesJsonMeta,
        attendeesJson.isAcceptableOrUnknown(
          data['attendees_json']!,
          _attendeesJsonMeta,
        ),
      );
    }
    if (data.containsKey('categories_json')) {
      context.handle(
        _categoriesJsonMeta,
        categoriesJson.isAcceptableOrUnknown(
          data['categories_json']!,
          _categoriesJsonMeta,
        ),
      );
    }
    if (data.containsKey('organizer_json')) {
      context.handle(
        _organizerJsonMeta,
        organizerJson.isAcceptableOrUnknown(
          data['organizer_json']!,
          _organizerJsonMeta,
        ),
      );
    }
    if (data.containsKey('creator_json')) {
      context.handle(
        _creatorJsonMeta,
        creatorJson.isAcceptableOrUnknown(
          data['creator_json']!,
          _creatorJsonMeta,
        ),
      );
    }
    if (data.containsKey('color_id')) {
      context.handle(
        _colorIdMeta,
        colorId.isAcceptableOrUnknown(data['color_id']!, _colorIdMeta),
      );
    }
    if (data.containsKey('color_hex')) {
      context.handle(
        _colorHexMeta,
        colorHex.isAcceptableOrUnknown(data['color_hex']!, _colorHexMeta),
      );
    }
    if (data.containsKey('visibility')) {
      context.handle(
        _visibilityMeta,
        visibility.isAcceptableOrUnknown(data['visibility']!, _visibilityMeta),
      );
    }
    if (data.containsKey('transparency_or_show_as')) {
      context.handle(
        _transparencyOrShowAsMeta,
        transparencyOrShowAs.isAcceptableOrUnknown(
          data['transparency_or_show_as']!,
          _transparencyOrShowAsMeta,
        ),
      );
    }
    if (data.containsKey('event_type')) {
      context.handle(
        _eventTypeMeta,
        eventType.isAcceptableOrUnknown(data['event_type']!, _eventTypeMeta),
      );
    }
    if (data.containsKey('web_link')) {
      context.handle(
        _webLinkMeta,
        webLink.isAcceptableOrUnknown(data['web_link']!, _webLinkMeta),
      );
    }
    if (data.containsKey('conference_json')) {
      context.handle(
        _conferenceJsonMeta,
        conferenceJson.isAcceptableOrUnknown(
          data['conference_json']!,
          _conferenceJsonMeta,
        ),
      );
    }
    if (data.containsKey('attachments_json')) {
      context.handle(
        _attachmentsJsonMeta,
        attachmentsJson.isAcceptableOrUnknown(
          data['attachments_json']!,
          _attachmentsJsonMeta,
        ),
      );
    }
    if (data.containsKey('is_cancelled')) {
      context.handle(
        _isCancelledMeta,
        isCancelled.isAcceptableOrUnknown(
          data['is_cancelled']!,
          _isCancelledMeta,
        ),
      );
    }
    if (data.containsKey('is_deleted')) {
      context.handle(
        _isDeletedMeta,
        isDeleted.isAcceptableOrUnknown(data['is_deleted']!, _isDeletedMeta),
      );
    }
    if (data.containsKey('raw_json')) {
      context.handle(
        _rawJsonMeta,
        rawJson.isAcceptableOrUnknown(data['raw_json']!, _rawJsonMeta),
      );
    }
    if (data.containsKey('created_at_server')) {
      context.handle(
        _createdAtServerMeta,
        createdAtServer.isAcceptableOrUnknown(
          data['created_at_server']!,
          _createdAtServerMeta,
        ),
      );
    }
    if (data.containsKey('updated_at_server')) {
      context.handle(
        _updatedAtServerMeta,
        updatedAtServer.isAcceptableOrUnknown(
          data['updated_at_server']!,
          _updatedAtServerMeta,
        ),
      );
    }
    if (data.containsKey('created_at_local')) {
      context.handle(
        _createdAtLocalMeta,
        createdAtLocal.isAcceptableOrUnknown(
          data['created_at_local']!,
          _createdAtLocalMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_createdAtLocalMeta);
    }
    if (data.containsKey('updated_at_local')) {
      context.handle(
        _updatedAtLocalMeta,
        updatedAtLocal.isAcceptableOrUnknown(
          data['updated_at_local']!,
          _updatedAtLocalMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_updatedAtLocalMeta);
    }
    if (data.containsKey('sync_status')) {
      context.handle(
        _syncStatusMeta,
        syncStatus.isAcceptableOrUnknown(data['sync_status']!, _syncStatusMeta),
      );
    }
    if (data.containsKey('baseline_raw_json')) {
      context.handle(
        _baselineRawJsonMeta,
        baselineRawJson.isAcceptableOrUnknown(
          data['baseline_raw_json']!,
          _baselineRawJsonMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CalendarEvent map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CalendarEvent(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      accountId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}account_id'],
      )!,
      calendarSourceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}calendar_source_id'],
      )!,
      provider: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}provider'],
      )!,
      providerCalendarId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}provider_calendar_id'],
      )!,
      providerEventId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}provider_event_id'],
      )!,
      providerRecurringEventId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}provider_recurring_event_id'],
      ),
      providerOriginalStartKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}provider_original_start_key'],
      ),
      etagOrChangeKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}etag_or_change_key'],
      ),
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      ),
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      ),
      location: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}location'],
      ),
      allDay: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}all_day'],
      )!,
      startDate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}start_date'],
      ),
      startDateTime: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}start_date_time'],
      ),
      startTimeZone: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}start_time_zone'],
      ),
      endDate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}end_date'],
      ),
      endDateTime: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}end_date_time'],
      ),
      endTimeZone: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}end_time_zone'],
      ),
      recurrenceJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}recurrence_json'],
      ),
      remindersJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reminders_json'],
      ),
      attendeesJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}attendees_json'],
      ),
      categoriesJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}categories_json'],
      ),
      organizerJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}organizer_json'],
      ),
      creatorJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}creator_json'],
      ),
      colorId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}color_id'],
      ),
      colorHex: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}color_hex'],
      ),
      visibility: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}visibility'],
      ),
      transparencyOrShowAs: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}transparency_or_show_as'],
      ),
      eventType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}event_type'],
      ),
      webLink: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}web_link'],
      ),
      conferenceJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}conference_json'],
      ),
      attachmentsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}attachments_json'],
      ),
      isCancelled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_cancelled'],
      )!,
      isDeleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_deleted'],
      )!,
      rawJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}raw_json'],
      ),
      createdAtServer: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_at_server'],
      ),
      updatedAtServer: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}updated_at_server'],
      ),
      createdAtLocal: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at_local'],
      )!,
      updatedAtLocal: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at_local'],
      )!,
      syncStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sync_status'],
      )!,
      baselineRawJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}baseline_raw_json'],
      ),
    );
  }

  @override
  $CalendarEventsTable createAlias(String alias) {
    return $CalendarEventsTable(attachedDatabase, alias);
  }
}

class CalendarEvent extends DataClass implements Insertable<CalendarEvent> {
  final String id;
  final String accountId;
  final String calendarSourceId;
  final String provider;
  final String providerCalendarId;
  final String providerEventId;
  final String? providerRecurringEventId;
  final String? providerOriginalStartKey;
  final String? etagOrChangeKey;
  final String? status;
  final String title;
  final String? description;
  final String? location;
  final bool allDay;
  final String? startDate;
  final String? startDateTime;
  final String? startTimeZone;
  final String? endDate;
  final String? endDateTime;
  final String? endTimeZone;
  final String? recurrenceJson;
  final String? remindersJson;
  final String? attendeesJson;
  final String? categoriesJson;
  final String? organizerJson;
  final String? creatorJson;
  final String? colorId;
  final String? colorHex;
  final String? visibility;
  final String? transparencyOrShowAs;
  final String? eventType;
  final String? webLink;
  final String? conferenceJson;
  final String? attachmentsJson;
  final bool isCancelled;
  final bool isDeleted;
  final String? rawJson;
  final String? createdAtServer;
  final String? updatedAtServer;
  final int createdAtLocal;
  final int updatedAtLocal;
  final String syncStatus;
  final String? baselineRawJson;
  const CalendarEvent({
    required this.id,
    required this.accountId,
    required this.calendarSourceId,
    required this.provider,
    required this.providerCalendarId,
    required this.providerEventId,
    this.providerRecurringEventId,
    this.providerOriginalStartKey,
    this.etagOrChangeKey,
    this.status,
    required this.title,
    this.description,
    this.location,
    required this.allDay,
    this.startDate,
    this.startDateTime,
    this.startTimeZone,
    this.endDate,
    this.endDateTime,
    this.endTimeZone,
    this.recurrenceJson,
    this.remindersJson,
    this.attendeesJson,
    this.categoriesJson,
    this.organizerJson,
    this.creatorJson,
    this.colorId,
    this.colorHex,
    this.visibility,
    this.transparencyOrShowAs,
    this.eventType,
    this.webLink,
    this.conferenceJson,
    this.attachmentsJson,
    required this.isCancelled,
    required this.isDeleted,
    this.rawJson,
    this.createdAtServer,
    this.updatedAtServer,
    required this.createdAtLocal,
    required this.updatedAtLocal,
    required this.syncStatus,
    this.baselineRawJson,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['account_id'] = Variable<String>(accountId);
    map['calendar_source_id'] = Variable<String>(calendarSourceId);
    map['provider'] = Variable<String>(provider);
    map['provider_calendar_id'] = Variable<String>(providerCalendarId);
    map['provider_event_id'] = Variable<String>(providerEventId);
    if (!nullToAbsent || providerRecurringEventId != null) {
      map['provider_recurring_event_id'] = Variable<String>(
        providerRecurringEventId,
      );
    }
    if (!nullToAbsent || providerOriginalStartKey != null) {
      map['provider_original_start_key'] = Variable<String>(
        providerOriginalStartKey,
      );
    }
    if (!nullToAbsent || etagOrChangeKey != null) {
      map['etag_or_change_key'] = Variable<String>(etagOrChangeKey);
    }
    if (!nullToAbsent || status != null) {
      map['status'] = Variable<String>(status);
    }
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    if (!nullToAbsent || location != null) {
      map['location'] = Variable<String>(location);
    }
    map['all_day'] = Variable<bool>(allDay);
    if (!nullToAbsent || startDate != null) {
      map['start_date'] = Variable<String>(startDate);
    }
    if (!nullToAbsent || startDateTime != null) {
      map['start_date_time'] = Variable<String>(startDateTime);
    }
    if (!nullToAbsent || startTimeZone != null) {
      map['start_time_zone'] = Variable<String>(startTimeZone);
    }
    if (!nullToAbsent || endDate != null) {
      map['end_date'] = Variable<String>(endDate);
    }
    if (!nullToAbsent || endDateTime != null) {
      map['end_date_time'] = Variable<String>(endDateTime);
    }
    if (!nullToAbsent || endTimeZone != null) {
      map['end_time_zone'] = Variable<String>(endTimeZone);
    }
    if (!nullToAbsent || recurrenceJson != null) {
      map['recurrence_json'] = Variable<String>(recurrenceJson);
    }
    if (!nullToAbsent || remindersJson != null) {
      map['reminders_json'] = Variable<String>(remindersJson);
    }
    if (!nullToAbsent || attendeesJson != null) {
      map['attendees_json'] = Variable<String>(attendeesJson);
    }
    if (!nullToAbsent || categoriesJson != null) {
      map['categories_json'] = Variable<String>(categoriesJson);
    }
    if (!nullToAbsent || organizerJson != null) {
      map['organizer_json'] = Variable<String>(organizerJson);
    }
    if (!nullToAbsent || creatorJson != null) {
      map['creator_json'] = Variable<String>(creatorJson);
    }
    if (!nullToAbsent || colorId != null) {
      map['color_id'] = Variable<String>(colorId);
    }
    if (!nullToAbsent || colorHex != null) {
      map['color_hex'] = Variable<String>(colorHex);
    }
    if (!nullToAbsent || visibility != null) {
      map['visibility'] = Variable<String>(visibility);
    }
    if (!nullToAbsent || transparencyOrShowAs != null) {
      map['transparency_or_show_as'] = Variable<String>(transparencyOrShowAs);
    }
    if (!nullToAbsent || eventType != null) {
      map['event_type'] = Variable<String>(eventType);
    }
    if (!nullToAbsent || webLink != null) {
      map['web_link'] = Variable<String>(webLink);
    }
    if (!nullToAbsent || conferenceJson != null) {
      map['conference_json'] = Variable<String>(conferenceJson);
    }
    if (!nullToAbsent || attachmentsJson != null) {
      map['attachments_json'] = Variable<String>(attachmentsJson);
    }
    map['is_cancelled'] = Variable<bool>(isCancelled);
    map['is_deleted'] = Variable<bool>(isDeleted);
    if (!nullToAbsent || rawJson != null) {
      map['raw_json'] = Variable<String>(rawJson);
    }
    if (!nullToAbsent || createdAtServer != null) {
      map['created_at_server'] = Variable<String>(createdAtServer);
    }
    if (!nullToAbsent || updatedAtServer != null) {
      map['updated_at_server'] = Variable<String>(updatedAtServer);
    }
    map['created_at_local'] = Variable<int>(createdAtLocal);
    map['updated_at_local'] = Variable<int>(updatedAtLocal);
    map['sync_status'] = Variable<String>(syncStatus);
    if (!nullToAbsent || baselineRawJson != null) {
      map['baseline_raw_json'] = Variable<String>(baselineRawJson);
    }
    return map;
  }

  CalendarEventsCompanion toCompanion(bool nullToAbsent) {
    return CalendarEventsCompanion(
      id: Value(id),
      accountId: Value(accountId),
      calendarSourceId: Value(calendarSourceId),
      provider: Value(provider),
      providerCalendarId: Value(providerCalendarId),
      providerEventId: Value(providerEventId),
      providerRecurringEventId: providerRecurringEventId == null && nullToAbsent
          ? const Value.absent()
          : Value(providerRecurringEventId),
      providerOriginalStartKey: providerOriginalStartKey == null && nullToAbsent
          ? const Value.absent()
          : Value(providerOriginalStartKey),
      etagOrChangeKey: etagOrChangeKey == null && nullToAbsent
          ? const Value.absent()
          : Value(etagOrChangeKey),
      status: status == null && nullToAbsent
          ? const Value.absent()
          : Value(status),
      title: Value(title),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
      location: location == null && nullToAbsent
          ? const Value.absent()
          : Value(location),
      allDay: Value(allDay),
      startDate: startDate == null && nullToAbsent
          ? const Value.absent()
          : Value(startDate),
      startDateTime: startDateTime == null && nullToAbsent
          ? const Value.absent()
          : Value(startDateTime),
      startTimeZone: startTimeZone == null && nullToAbsent
          ? const Value.absent()
          : Value(startTimeZone),
      endDate: endDate == null && nullToAbsent
          ? const Value.absent()
          : Value(endDate),
      endDateTime: endDateTime == null && nullToAbsent
          ? const Value.absent()
          : Value(endDateTime),
      endTimeZone: endTimeZone == null && nullToAbsent
          ? const Value.absent()
          : Value(endTimeZone),
      recurrenceJson: recurrenceJson == null && nullToAbsent
          ? const Value.absent()
          : Value(recurrenceJson),
      remindersJson: remindersJson == null && nullToAbsent
          ? const Value.absent()
          : Value(remindersJson),
      attendeesJson: attendeesJson == null && nullToAbsent
          ? const Value.absent()
          : Value(attendeesJson),
      categoriesJson: categoriesJson == null && nullToAbsent
          ? const Value.absent()
          : Value(categoriesJson),
      organizerJson: organizerJson == null && nullToAbsent
          ? const Value.absent()
          : Value(organizerJson),
      creatorJson: creatorJson == null && nullToAbsent
          ? const Value.absent()
          : Value(creatorJson),
      colorId: colorId == null && nullToAbsent
          ? const Value.absent()
          : Value(colorId),
      colorHex: colorHex == null && nullToAbsent
          ? const Value.absent()
          : Value(colorHex),
      visibility: visibility == null && nullToAbsent
          ? const Value.absent()
          : Value(visibility),
      transparencyOrShowAs: transparencyOrShowAs == null && nullToAbsent
          ? const Value.absent()
          : Value(transparencyOrShowAs),
      eventType: eventType == null && nullToAbsent
          ? const Value.absent()
          : Value(eventType),
      webLink: webLink == null && nullToAbsent
          ? const Value.absent()
          : Value(webLink),
      conferenceJson: conferenceJson == null && nullToAbsent
          ? const Value.absent()
          : Value(conferenceJson),
      attachmentsJson: attachmentsJson == null && nullToAbsent
          ? const Value.absent()
          : Value(attachmentsJson),
      isCancelled: Value(isCancelled),
      isDeleted: Value(isDeleted),
      rawJson: rawJson == null && nullToAbsent
          ? const Value.absent()
          : Value(rawJson),
      createdAtServer: createdAtServer == null && nullToAbsent
          ? const Value.absent()
          : Value(createdAtServer),
      updatedAtServer: updatedAtServer == null && nullToAbsent
          ? const Value.absent()
          : Value(updatedAtServer),
      createdAtLocal: Value(createdAtLocal),
      updatedAtLocal: Value(updatedAtLocal),
      syncStatus: Value(syncStatus),
      baselineRawJson: baselineRawJson == null && nullToAbsent
          ? const Value.absent()
          : Value(baselineRawJson),
    );
  }

  factory CalendarEvent.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CalendarEvent(
      id: serializer.fromJson<String>(json['id']),
      accountId: serializer.fromJson<String>(json['accountId']),
      calendarSourceId: serializer.fromJson<String>(json['calendarSourceId']),
      provider: serializer.fromJson<String>(json['provider']),
      providerCalendarId: serializer.fromJson<String>(
        json['providerCalendarId'],
      ),
      providerEventId: serializer.fromJson<String>(json['providerEventId']),
      providerRecurringEventId: serializer.fromJson<String?>(
        json['providerRecurringEventId'],
      ),
      providerOriginalStartKey: serializer.fromJson<String?>(
        json['providerOriginalStartKey'],
      ),
      etagOrChangeKey: serializer.fromJson<String?>(json['etagOrChangeKey']),
      status: serializer.fromJson<String?>(json['status']),
      title: serializer.fromJson<String>(json['title']),
      description: serializer.fromJson<String?>(json['description']),
      location: serializer.fromJson<String?>(json['location']),
      allDay: serializer.fromJson<bool>(json['allDay']),
      startDate: serializer.fromJson<String?>(json['startDate']),
      startDateTime: serializer.fromJson<String?>(json['startDateTime']),
      startTimeZone: serializer.fromJson<String?>(json['startTimeZone']),
      endDate: serializer.fromJson<String?>(json['endDate']),
      endDateTime: serializer.fromJson<String?>(json['endDateTime']),
      endTimeZone: serializer.fromJson<String?>(json['endTimeZone']),
      recurrenceJson: serializer.fromJson<String?>(json['recurrenceJson']),
      remindersJson: serializer.fromJson<String?>(json['remindersJson']),
      attendeesJson: serializer.fromJson<String?>(json['attendeesJson']),
      categoriesJson: serializer.fromJson<String?>(json['categoriesJson']),
      organizerJson: serializer.fromJson<String?>(json['organizerJson']),
      creatorJson: serializer.fromJson<String?>(json['creatorJson']),
      colorId: serializer.fromJson<String?>(json['colorId']),
      colorHex: serializer.fromJson<String?>(json['colorHex']),
      visibility: serializer.fromJson<String?>(json['visibility']),
      transparencyOrShowAs: serializer.fromJson<String?>(
        json['transparencyOrShowAs'],
      ),
      eventType: serializer.fromJson<String?>(json['eventType']),
      webLink: serializer.fromJson<String?>(json['webLink']),
      conferenceJson: serializer.fromJson<String?>(json['conferenceJson']),
      attachmentsJson: serializer.fromJson<String?>(json['attachmentsJson']),
      isCancelled: serializer.fromJson<bool>(json['isCancelled']),
      isDeleted: serializer.fromJson<bool>(json['isDeleted']),
      rawJson: serializer.fromJson<String?>(json['rawJson']),
      createdAtServer: serializer.fromJson<String?>(json['createdAtServer']),
      updatedAtServer: serializer.fromJson<String?>(json['updatedAtServer']),
      createdAtLocal: serializer.fromJson<int>(json['createdAtLocal']),
      updatedAtLocal: serializer.fromJson<int>(json['updatedAtLocal']),
      syncStatus: serializer.fromJson<String>(json['syncStatus']),
      baselineRawJson: serializer.fromJson<String?>(json['baselineRawJson']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'accountId': serializer.toJson<String>(accountId),
      'calendarSourceId': serializer.toJson<String>(calendarSourceId),
      'provider': serializer.toJson<String>(provider),
      'providerCalendarId': serializer.toJson<String>(providerCalendarId),
      'providerEventId': serializer.toJson<String>(providerEventId),
      'providerRecurringEventId': serializer.toJson<String?>(
        providerRecurringEventId,
      ),
      'providerOriginalStartKey': serializer.toJson<String?>(
        providerOriginalStartKey,
      ),
      'etagOrChangeKey': serializer.toJson<String?>(etagOrChangeKey),
      'status': serializer.toJson<String?>(status),
      'title': serializer.toJson<String>(title),
      'description': serializer.toJson<String?>(description),
      'location': serializer.toJson<String?>(location),
      'allDay': serializer.toJson<bool>(allDay),
      'startDate': serializer.toJson<String?>(startDate),
      'startDateTime': serializer.toJson<String?>(startDateTime),
      'startTimeZone': serializer.toJson<String?>(startTimeZone),
      'endDate': serializer.toJson<String?>(endDate),
      'endDateTime': serializer.toJson<String?>(endDateTime),
      'endTimeZone': serializer.toJson<String?>(endTimeZone),
      'recurrenceJson': serializer.toJson<String?>(recurrenceJson),
      'remindersJson': serializer.toJson<String?>(remindersJson),
      'attendeesJson': serializer.toJson<String?>(attendeesJson),
      'categoriesJson': serializer.toJson<String?>(categoriesJson),
      'organizerJson': serializer.toJson<String?>(organizerJson),
      'creatorJson': serializer.toJson<String?>(creatorJson),
      'colorId': serializer.toJson<String?>(colorId),
      'colorHex': serializer.toJson<String?>(colorHex),
      'visibility': serializer.toJson<String?>(visibility),
      'transparencyOrShowAs': serializer.toJson<String?>(transparencyOrShowAs),
      'eventType': serializer.toJson<String?>(eventType),
      'webLink': serializer.toJson<String?>(webLink),
      'conferenceJson': serializer.toJson<String?>(conferenceJson),
      'attachmentsJson': serializer.toJson<String?>(attachmentsJson),
      'isCancelled': serializer.toJson<bool>(isCancelled),
      'isDeleted': serializer.toJson<bool>(isDeleted),
      'rawJson': serializer.toJson<String?>(rawJson),
      'createdAtServer': serializer.toJson<String?>(createdAtServer),
      'updatedAtServer': serializer.toJson<String?>(updatedAtServer),
      'createdAtLocal': serializer.toJson<int>(createdAtLocal),
      'updatedAtLocal': serializer.toJson<int>(updatedAtLocal),
      'syncStatus': serializer.toJson<String>(syncStatus),
      'baselineRawJson': serializer.toJson<String?>(baselineRawJson),
    };
  }

  CalendarEvent copyWith({
    String? id,
    String? accountId,
    String? calendarSourceId,
    String? provider,
    String? providerCalendarId,
    String? providerEventId,
    Value<String?> providerRecurringEventId = const Value.absent(),
    Value<String?> providerOriginalStartKey = const Value.absent(),
    Value<String?> etagOrChangeKey = const Value.absent(),
    Value<String?> status = const Value.absent(),
    String? title,
    Value<String?> description = const Value.absent(),
    Value<String?> location = const Value.absent(),
    bool? allDay,
    Value<String?> startDate = const Value.absent(),
    Value<String?> startDateTime = const Value.absent(),
    Value<String?> startTimeZone = const Value.absent(),
    Value<String?> endDate = const Value.absent(),
    Value<String?> endDateTime = const Value.absent(),
    Value<String?> endTimeZone = const Value.absent(),
    Value<String?> recurrenceJson = const Value.absent(),
    Value<String?> remindersJson = const Value.absent(),
    Value<String?> attendeesJson = const Value.absent(),
    Value<String?> categoriesJson = const Value.absent(),
    Value<String?> organizerJson = const Value.absent(),
    Value<String?> creatorJson = const Value.absent(),
    Value<String?> colorId = const Value.absent(),
    Value<String?> colorHex = const Value.absent(),
    Value<String?> visibility = const Value.absent(),
    Value<String?> transparencyOrShowAs = const Value.absent(),
    Value<String?> eventType = const Value.absent(),
    Value<String?> webLink = const Value.absent(),
    Value<String?> conferenceJson = const Value.absent(),
    Value<String?> attachmentsJson = const Value.absent(),
    bool? isCancelled,
    bool? isDeleted,
    Value<String?> rawJson = const Value.absent(),
    Value<String?> createdAtServer = const Value.absent(),
    Value<String?> updatedAtServer = const Value.absent(),
    int? createdAtLocal,
    int? updatedAtLocal,
    String? syncStatus,
    Value<String?> baselineRawJson = const Value.absent(),
  }) => CalendarEvent(
    id: id ?? this.id,
    accountId: accountId ?? this.accountId,
    calendarSourceId: calendarSourceId ?? this.calendarSourceId,
    provider: provider ?? this.provider,
    providerCalendarId: providerCalendarId ?? this.providerCalendarId,
    providerEventId: providerEventId ?? this.providerEventId,
    providerRecurringEventId: providerRecurringEventId.present
        ? providerRecurringEventId.value
        : this.providerRecurringEventId,
    providerOriginalStartKey: providerOriginalStartKey.present
        ? providerOriginalStartKey.value
        : this.providerOriginalStartKey,
    etagOrChangeKey: etagOrChangeKey.present
        ? etagOrChangeKey.value
        : this.etagOrChangeKey,
    status: status.present ? status.value : this.status,
    title: title ?? this.title,
    description: description.present ? description.value : this.description,
    location: location.present ? location.value : this.location,
    allDay: allDay ?? this.allDay,
    startDate: startDate.present ? startDate.value : this.startDate,
    startDateTime: startDateTime.present
        ? startDateTime.value
        : this.startDateTime,
    startTimeZone: startTimeZone.present
        ? startTimeZone.value
        : this.startTimeZone,
    endDate: endDate.present ? endDate.value : this.endDate,
    endDateTime: endDateTime.present ? endDateTime.value : this.endDateTime,
    endTimeZone: endTimeZone.present ? endTimeZone.value : this.endTimeZone,
    recurrenceJson: recurrenceJson.present
        ? recurrenceJson.value
        : this.recurrenceJson,
    remindersJson: remindersJson.present
        ? remindersJson.value
        : this.remindersJson,
    attendeesJson: attendeesJson.present
        ? attendeesJson.value
        : this.attendeesJson,
    categoriesJson: categoriesJson.present
        ? categoriesJson.value
        : this.categoriesJson,
    organizerJson: organizerJson.present
        ? organizerJson.value
        : this.organizerJson,
    creatorJson: creatorJson.present ? creatorJson.value : this.creatorJson,
    colorId: colorId.present ? colorId.value : this.colorId,
    colorHex: colorHex.present ? colorHex.value : this.colorHex,
    visibility: visibility.present ? visibility.value : this.visibility,
    transparencyOrShowAs: transparencyOrShowAs.present
        ? transparencyOrShowAs.value
        : this.transparencyOrShowAs,
    eventType: eventType.present ? eventType.value : this.eventType,
    webLink: webLink.present ? webLink.value : this.webLink,
    conferenceJson: conferenceJson.present
        ? conferenceJson.value
        : this.conferenceJson,
    attachmentsJson: attachmentsJson.present
        ? attachmentsJson.value
        : this.attachmentsJson,
    isCancelled: isCancelled ?? this.isCancelled,
    isDeleted: isDeleted ?? this.isDeleted,
    rawJson: rawJson.present ? rawJson.value : this.rawJson,
    createdAtServer: createdAtServer.present
        ? createdAtServer.value
        : this.createdAtServer,
    updatedAtServer: updatedAtServer.present
        ? updatedAtServer.value
        : this.updatedAtServer,
    createdAtLocal: createdAtLocal ?? this.createdAtLocal,
    updatedAtLocal: updatedAtLocal ?? this.updatedAtLocal,
    syncStatus: syncStatus ?? this.syncStatus,
    baselineRawJson: baselineRawJson.present
        ? baselineRawJson.value
        : this.baselineRawJson,
  );
  CalendarEvent copyWithCompanion(CalendarEventsCompanion data) {
    return CalendarEvent(
      id: data.id.present ? data.id.value : this.id,
      accountId: data.accountId.present ? data.accountId.value : this.accountId,
      calendarSourceId: data.calendarSourceId.present
          ? data.calendarSourceId.value
          : this.calendarSourceId,
      provider: data.provider.present ? data.provider.value : this.provider,
      providerCalendarId: data.providerCalendarId.present
          ? data.providerCalendarId.value
          : this.providerCalendarId,
      providerEventId: data.providerEventId.present
          ? data.providerEventId.value
          : this.providerEventId,
      providerRecurringEventId: data.providerRecurringEventId.present
          ? data.providerRecurringEventId.value
          : this.providerRecurringEventId,
      providerOriginalStartKey: data.providerOriginalStartKey.present
          ? data.providerOriginalStartKey.value
          : this.providerOriginalStartKey,
      etagOrChangeKey: data.etagOrChangeKey.present
          ? data.etagOrChangeKey.value
          : this.etagOrChangeKey,
      status: data.status.present ? data.status.value : this.status,
      title: data.title.present ? data.title.value : this.title,
      description: data.description.present
          ? data.description.value
          : this.description,
      location: data.location.present ? data.location.value : this.location,
      allDay: data.allDay.present ? data.allDay.value : this.allDay,
      startDate: data.startDate.present ? data.startDate.value : this.startDate,
      startDateTime: data.startDateTime.present
          ? data.startDateTime.value
          : this.startDateTime,
      startTimeZone: data.startTimeZone.present
          ? data.startTimeZone.value
          : this.startTimeZone,
      endDate: data.endDate.present ? data.endDate.value : this.endDate,
      endDateTime: data.endDateTime.present
          ? data.endDateTime.value
          : this.endDateTime,
      endTimeZone: data.endTimeZone.present
          ? data.endTimeZone.value
          : this.endTimeZone,
      recurrenceJson: data.recurrenceJson.present
          ? data.recurrenceJson.value
          : this.recurrenceJson,
      remindersJson: data.remindersJson.present
          ? data.remindersJson.value
          : this.remindersJson,
      attendeesJson: data.attendeesJson.present
          ? data.attendeesJson.value
          : this.attendeesJson,
      categoriesJson: data.categoriesJson.present
          ? data.categoriesJson.value
          : this.categoriesJson,
      organizerJson: data.organizerJson.present
          ? data.organizerJson.value
          : this.organizerJson,
      creatorJson: data.creatorJson.present
          ? data.creatorJson.value
          : this.creatorJson,
      colorId: data.colorId.present ? data.colorId.value : this.colorId,
      colorHex: data.colorHex.present ? data.colorHex.value : this.colorHex,
      visibility: data.visibility.present
          ? data.visibility.value
          : this.visibility,
      transparencyOrShowAs: data.transparencyOrShowAs.present
          ? data.transparencyOrShowAs.value
          : this.transparencyOrShowAs,
      eventType: data.eventType.present ? data.eventType.value : this.eventType,
      webLink: data.webLink.present ? data.webLink.value : this.webLink,
      conferenceJson: data.conferenceJson.present
          ? data.conferenceJson.value
          : this.conferenceJson,
      attachmentsJson: data.attachmentsJson.present
          ? data.attachmentsJson.value
          : this.attachmentsJson,
      isCancelled: data.isCancelled.present
          ? data.isCancelled.value
          : this.isCancelled,
      isDeleted: data.isDeleted.present ? data.isDeleted.value : this.isDeleted,
      rawJson: data.rawJson.present ? data.rawJson.value : this.rawJson,
      createdAtServer: data.createdAtServer.present
          ? data.createdAtServer.value
          : this.createdAtServer,
      updatedAtServer: data.updatedAtServer.present
          ? data.updatedAtServer.value
          : this.updatedAtServer,
      createdAtLocal: data.createdAtLocal.present
          ? data.createdAtLocal.value
          : this.createdAtLocal,
      updatedAtLocal: data.updatedAtLocal.present
          ? data.updatedAtLocal.value
          : this.updatedAtLocal,
      syncStatus: data.syncStatus.present
          ? data.syncStatus.value
          : this.syncStatus,
      baselineRawJson: data.baselineRawJson.present
          ? data.baselineRawJson.value
          : this.baselineRawJson,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CalendarEvent(')
          ..write('id: $id, ')
          ..write('accountId: $accountId, ')
          ..write('calendarSourceId: $calendarSourceId, ')
          ..write('provider: $provider, ')
          ..write('providerCalendarId: $providerCalendarId, ')
          ..write('providerEventId: $providerEventId, ')
          ..write('providerRecurringEventId: $providerRecurringEventId, ')
          ..write('providerOriginalStartKey: $providerOriginalStartKey, ')
          ..write('etagOrChangeKey: $etagOrChangeKey, ')
          ..write('status: $status, ')
          ..write('title: $title, ')
          ..write('description: $description, ')
          ..write('location: $location, ')
          ..write('allDay: $allDay, ')
          ..write('startDate: $startDate, ')
          ..write('startDateTime: $startDateTime, ')
          ..write('startTimeZone: $startTimeZone, ')
          ..write('endDate: $endDate, ')
          ..write('endDateTime: $endDateTime, ')
          ..write('endTimeZone: $endTimeZone, ')
          ..write('recurrenceJson: $recurrenceJson, ')
          ..write('remindersJson: $remindersJson, ')
          ..write('attendeesJson: $attendeesJson, ')
          ..write('categoriesJson: $categoriesJson, ')
          ..write('organizerJson: $organizerJson, ')
          ..write('creatorJson: $creatorJson, ')
          ..write('colorId: $colorId, ')
          ..write('colorHex: $colorHex, ')
          ..write('visibility: $visibility, ')
          ..write('transparencyOrShowAs: $transparencyOrShowAs, ')
          ..write('eventType: $eventType, ')
          ..write('webLink: $webLink, ')
          ..write('conferenceJson: $conferenceJson, ')
          ..write('attachmentsJson: $attachmentsJson, ')
          ..write('isCancelled: $isCancelled, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('rawJson: $rawJson, ')
          ..write('createdAtServer: $createdAtServer, ')
          ..write('updatedAtServer: $updatedAtServer, ')
          ..write('createdAtLocal: $createdAtLocal, ')
          ..write('updatedAtLocal: $updatedAtLocal, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('baselineRawJson: $baselineRawJson')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    accountId,
    calendarSourceId,
    provider,
    providerCalendarId,
    providerEventId,
    providerRecurringEventId,
    providerOriginalStartKey,
    etagOrChangeKey,
    status,
    title,
    description,
    location,
    allDay,
    startDate,
    startDateTime,
    startTimeZone,
    endDate,
    endDateTime,
    endTimeZone,
    recurrenceJson,
    remindersJson,
    attendeesJson,
    categoriesJson,
    organizerJson,
    creatorJson,
    colorId,
    colorHex,
    visibility,
    transparencyOrShowAs,
    eventType,
    webLink,
    conferenceJson,
    attachmentsJson,
    isCancelled,
    isDeleted,
    rawJson,
    createdAtServer,
    updatedAtServer,
    createdAtLocal,
    updatedAtLocal,
    syncStatus,
    baselineRawJson,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CalendarEvent &&
          other.id == this.id &&
          other.accountId == this.accountId &&
          other.calendarSourceId == this.calendarSourceId &&
          other.provider == this.provider &&
          other.providerCalendarId == this.providerCalendarId &&
          other.providerEventId == this.providerEventId &&
          other.providerRecurringEventId == this.providerRecurringEventId &&
          other.providerOriginalStartKey == this.providerOriginalStartKey &&
          other.etagOrChangeKey == this.etagOrChangeKey &&
          other.status == this.status &&
          other.title == this.title &&
          other.description == this.description &&
          other.location == this.location &&
          other.allDay == this.allDay &&
          other.startDate == this.startDate &&
          other.startDateTime == this.startDateTime &&
          other.startTimeZone == this.startTimeZone &&
          other.endDate == this.endDate &&
          other.endDateTime == this.endDateTime &&
          other.endTimeZone == this.endTimeZone &&
          other.recurrenceJson == this.recurrenceJson &&
          other.remindersJson == this.remindersJson &&
          other.attendeesJson == this.attendeesJson &&
          other.categoriesJson == this.categoriesJson &&
          other.organizerJson == this.organizerJson &&
          other.creatorJson == this.creatorJson &&
          other.colorId == this.colorId &&
          other.colorHex == this.colorHex &&
          other.visibility == this.visibility &&
          other.transparencyOrShowAs == this.transparencyOrShowAs &&
          other.eventType == this.eventType &&
          other.webLink == this.webLink &&
          other.conferenceJson == this.conferenceJson &&
          other.attachmentsJson == this.attachmentsJson &&
          other.isCancelled == this.isCancelled &&
          other.isDeleted == this.isDeleted &&
          other.rawJson == this.rawJson &&
          other.createdAtServer == this.createdAtServer &&
          other.updatedAtServer == this.updatedAtServer &&
          other.createdAtLocal == this.createdAtLocal &&
          other.updatedAtLocal == this.updatedAtLocal &&
          other.syncStatus == this.syncStatus &&
          other.baselineRawJson == this.baselineRawJson);
}

class CalendarEventsCompanion extends UpdateCompanion<CalendarEvent> {
  final Value<String> id;
  final Value<String> accountId;
  final Value<String> calendarSourceId;
  final Value<String> provider;
  final Value<String> providerCalendarId;
  final Value<String> providerEventId;
  final Value<String?> providerRecurringEventId;
  final Value<String?> providerOriginalStartKey;
  final Value<String?> etagOrChangeKey;
  final Value<String?> status;
  final Value<String> title;
  final Value<String?> description;
  final Value<String?> location;
  final Value<bool> allDay;
  final Value<String?> startDate;
  final Value<String?> startDateTime;
  final Value<String?> startTimeZone;
  final Value<String?> endDate;
  final Value<String?> endDateTime;
  final Value<String?> endTimeZone;
  final Value<String?> recurrenceJson;
  final Value<String?> remindersJson;
  final Value<String?> attendeesJson;
  final Value<String?> categoriesJson;
  final Value<String?> organizerJson;
  final Value<String?> creatorJson;
  final Value<String?> colorId;
  final Value<String?> colorHex;
  final Value<String?> visibility;
  final Value<String?> transparencyOrShowAs;
  final Value<String?> eventType;
  final Value<String?> webLink;
  final Value<String?> conferenceJson;
  final Value<String?> attachmentsJson;
  final Value<bool> isCancelled;
  final Value<bool> isDeleted;
  final Value<String?> rawJson;
  final Value<String?> createdAtServer;
  final Value<String?> updatedAtServer;
  final Value<int> createdAtLocal;
  final Value<int> updatedAtLocal;
  final Value<String> syncStatus;
  final Value<String?> baselineRawJson;
  final Value<int> rowid;
  const CalendarEventsCompanion({
    this.id = const Value.absent(),
    this.accountId = const Value.absent(),
    this.calendarSourceId = const Value.absent(),
    this.provider = const Value.absent(),
    this.providerCalendarId = const Value.absent(),
    this.providerEventId = const Value.absent(),
    this.providerRecurringEventId = const Value.absent(),
    this.providerOriginalStartKey = const Value.absent(),
    this.etagOrChangeKey = const Value.absent(),
    this.status = const Value.absent(),
    this.title = const Value.absent(),
    this.description = const Value.absent(),
    this.location = const Value.absent(),
    this.allDay = const Value.absent(),
    this.startDate = const Value.absent(),
    this.startDateTime = const Value.absent(),
    this.startTimeZone = const Value.absent(),
    this.endDate = const Value.absent(),
    this.endDateTime = const Value.absent(),
    this.endTimeZone = const Value.absent(),
    this.recurrenceJson = const Value.absent(),
    this.remindersJson = const Value.absent(),
    this.attendeesJson = const Value.absent(),
    this.categoriesJson = const Value.absent(),
    this.organizerJson = const Value.absent(),
    this.creatorJson = const Value.absent(),
    this.colorId = const Value.absent(),
    this.colorHex = const Value.absent(),
    this.visibility = const Value.absent(),
    this.transparencyOrShowAs = const Value.absent(),
    this.eventType = const Value.absent(),
    this.webLink = const Value.absent(),
    this.conferenceJson = const Value.absent(),
    this.attachmentsJson = const Value.absent(),
    this.isCancelled = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.rawJson = const Value.absent(),
    this.createdAtServer = const Value.absent(),
    this.updatedAtServer = const Value.absent(),
    this.createdAtLocal = const Value.absent(),
    this.updatedAtLocal = const Value.absent(),
    this.syncStatus = const Value.absent(),
    this.baselineRawJson = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CalendarEventsCompanion.insert({
    required String id,
    required String accountId,
    required String calendarSourceId,
    required String provider,
    required String providerCalendarId,
    required String providerEventId,
    this.providerRecurringEventId = const Value.absent(),
    this.providerOriginalStartKey = const Value.absent(),
    this.etagOrChangeKey = const Value.absent(),
    this.status = const Value.absent(),
    required String title,
    this.description = const Value.absent(),
    this.location = const Value.absent(),
    this.allDay = const Value.absent(),
    this.startDate = const Value.absent(),
    this.startDateTime = const Value.absent(),
    this.startTimeZone = const Value.absent(),
    this.endDate = const Value.absent(),
    this.endDateTime = const Value.absent(),
    this.endTimeZone = const Value.absent(),
    this.recurrenceJson = const Value.absent(),
    this.remindersJson = const Value.absent(),
    this.attendeesJson = const Value.absent(),
    this.categoriesJson = const Value.absent(),
    this.organizerJson = const Value.absent(),
    this.creatorJson = const Value.absent(),
    this.colorId = const Value.absent(),
    this.colorHex = const Value.absent(),
    this.visibility = const Value.absent(),
    this.transparencyOrShowAs = const Value.absent(),
    this.eventType = const Value.absent(),
    this.webLink = const Value.absent(),
    this.conferenceJson = const Value.absent(),
    this.attachmentsJson = const Value.absent(),
    this.isCancelled = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.rawJson = const Value.absent(),
    this.createdAtServer = const Value.absent(),
    this.updatedAtServer = const Value.absent(),
    required int createdAtLocal,
    required int updatedAtLocal,
    this.syncStatus = const Value.absent(),
    this.baselineRawJson = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       accountId = Value(accountId),
       calendarSourceId = Value(calendarSourceId),
       provider = Value(provider),
       providerCalendarId = Value(providerCalendarId),
       providerEventId = Value(providerEventId),
       title = Value(title),
       createdAtLocal = Value(createdAtLocal),
       updatedAtLocal = Value(updatedAtLocal);
  static Insertable<CalendarEvent> custom({
    Expression<String>? id,
    Expression<String>? accountId,
    Expression<String>? calendarSourceId,
    Expression<String>? provider,
    Expression<String>? providerCalendarId,
    Expression<String>? providerEventId,
    Expression<String>? providerRecurringEventId,
    Expression<String>? providerOriginalStartKey,
    Expression<String>? etagOrChangeKey,
    Expression<String>? status,
    Expression<String>? title,
    Expression<String>? description,
    Expression<String>? location,
    Expression<bool>? allDay,
    Expression<String>? startDate,
    Expression<String>? startDateTime,
    Expression<String>? startTimeZone,
    Expression<String>? endDate,
    Expression<String>? endDateTime,
    Expression<String>? endTimeZone,
    Expression<String>? recurrenceJson,
    Expression<String>? remindersJson,
    Expression<String>? attendeesJson,
    Expression<String>? categoriesJson,
    Expression<String>? organizerJson,
    Expression<String>? creatorJson,
    Expression<String>? colorId,
    Expression<String>? colorHex,
    Expression<String>? visibility,
    Expression<String>? transparencyOrShowAs,
    Expression<String>? eventType,
    Expression<String>? webLink,
    Expression<String>? conferenceJson,
    Expression<String>? attachmentsJson,
    Expression<bool>? isCancelled,
    Expression<bool>? isDeleted,
    Expression<String>? rawJson,
    Expression<String>? createdAtServer,
    Expression<String>? updatedAtServer,
    Expression<int>? createdAtLocal,
    Expression<int>? updatedAtLocal,
    Expression<String>? syncStatus,
    Expression<String>? baselineRawJson,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (accountId != null) 'account_id': accountId,
      if (calendarSourceId != null) 'calendar_source_id': calendarSourceId,
      if (provider != null) 'provider': provider,
      if (providerCalendarId != null)
        'provider_calendar_id': providerCalendarId,
      if (providerEventId != null) 'provider_event_id': providerEventId,
      if (providerRecurringEventId != null)
        'provider_recurring_event_id': providerRecurringEventId,
      if (providerOriginalStartKey != null)
        'provider_original_start_key': providerOriginalStartKey,
      if (etagOrChangeKey != null) 'etag_or_change_key': etagOrChangeKey,
      if (status != null) 'status': status,
      if (title != null) 'title': title,
      if (description != null) 'description': description,
      if (location != null) 'location': location,
      if (allDay != null) 'all_day': allDay,
      if (startDate != null) 'start_date': startDate,
      if (startDateTime != null) 'start_date_time': startDateTime,
      if (startTimeZone != null) 'start_time_zone': startTimeZone,
      if (endDate != null) 'end_date': endDate,
      if (endDateTime != null) 'end_date_time': endDateTime,
      if (endTimeZone != null) 'end_time_zone': endTimeZone,
      if (recurrenceJson != null) 'recurrence_json': recurrenceJson,
      if (remindersJson != null) 'reminders_json': remindersJson,
      if (attendeesJson != null) 'attendees_json': attendeesJson,
      if (categoriesJson != null) 'categories_json': categoriesJson,
      if (organizerJson != null) 'organizer_json': organizerJson,
      if (creatorJson != null) 'creator_json': creatorJson,
      if (colorId != null) 'color_id': colorId,
      if (colorHex != null) 'color_hex': colorHex,
      if (visibility != null) 'visibility': visibility,
      if (transparencyOrShowAs != null)
        'transparency_or_show_as': transparencyOrShowAs,
      if (eventType != null) 'event_type': eventType,
      if (webLink != null) 'web_link': webLink,
      if (conferenceJson != null) 'conference_json': conferenceJson,
      if (attachmentsJson != null) 'attachments_json': attachmentsJson,
      if (isCancelled != null) 'is_cancelled': isCancelled,
      if (isDeleted != null) 'is_deleted': isDeleted,
      if (rawJson != null) 'raw_json': rawJson,
      if (createdAtServer != null) 'created_at_server': createdAtServer,
      if (updatedAtServer != null) 'updated_at_server': updatedAtServer,
      if (createdAtLocal != null) 'created_at_local': createdAtLocal,
      if (updatedAtLocal != null) 'updated_at_local': updatedAtLocal,
      if (syncStatus != null) 'sync_status': syncStatus,
      if (baselineRawJson != null) 'baseline_raw_json': baselineRawJson,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CalendarEventsCompanion copyWith({
    Value<String>? id,
    Value<String>? accountId,
    Value<String>? calendarSourceId,
    Value<String>? provider,
    Value<String>? providerCalendarId,
    Value<String>? providerEventId,
    Value<String?>? providerRecurringEventId,
    Value<String?>? providerOriginalStartKey,
    Value<String?>? etagOrChangeKey,
    Value<String?>? status,
    Value<String>? title,
    Value<String?>? description,
    Value<String?>? location,
    Value<bool>? allDay,
    Value<String?>? startDate,
    Value<String?>? startDateTime,
    Value<String?>? startTimeZone,
    Value<String?>? endDate,
    Value<String?>? endDateTime,
    Value<String?>? endTimeZone,
    Value<String?>? recurrenceJson,
    Value<String?>? remindersJson,
    Value<String?>? attendeesJson,
    Value<String?>? categoriesJson,
    Value<String?>? organizerJson,
    Value<String?>? creatorJson,
    Value<String?>? colorId,
    Value<String?>? colorHex,
    Value<String?>? visibility,
    Value<String?>? transparencyOrShowAs,
    Value<String?>? eventType,
    Value<String?>? webLink,
    Value<String?>? conferenceJson,
    Value<String?>? attachmentsJson,
    Value<bool>? isCancelled,
    Value<bool>? isDeleted,
    Value<String?>? rawJson,
    Value<String?>? createdAtServer,
    Value<String?>? updatedAtServer,
    Value<int>? createdAtLocal,
    Value<int>? updatedAtLocal,
    Value<String>? syncStatus,
    Value<String?>? baselineRawJson,
    Value<int>? rowid,
  }) {
    return CalendarEventsCompanion(
      id: id ?? this.id,
      accountId: accountId ?? this.accountId,
      calendarSourceId: calendarSourceId ?? this.calendarSourceId,
      provider: provider ?? this.provider,
      providerCalendarId: providerCalendarId ?? this.providerCalendarId,
      providerEventId: providerEventId ?? this.providerEventId,
      providerRecurringEventId:
          providerRecurringEventId ?? this.providerRecurringEventId,
      providerOriginalStartKey:
          providerOriginalStartKey ?? this.providerOriginalStartKey,
      etagOrChangeKey: etagOrChangeKey ?? this.etagOrChangeKey,
      status: status ?? this.status,
      title: title ?? this.title,
      description: description ?? this.description,
      location: location ?? this.location,
      allDay: allDay ?? this.allDay,
      startDate: startDate ?? this.startDate,
      startDateTime: startDateTime ?? this.startDateTime,
      startTimeZone: startTimeZone ?? this.startTimeZone,
      endDate: endDate ?? this.endDate,
      endDateTime: endDateTime ?? this.endDateTime,
      endTimeZone: endTimeZone ?? this.endTimeZone,
      recurrenceJson: recurrenceJson ?? this.recurrenceJson,
      remindersJson: remindersJson ?? this.remindersJson,
      attendeesJson: attendeesJson ?? this.attendeesJson,
      categoriesJson: categoriesJson ?? this.categoriesJson,
      organizerJson: organizerJson ?? this.organizerJson,
      creatorJson: creatorJson ?? this.creatorJson,
      colorId: colorId ?? this.colorId,
      colorHex: colorHex ?? this.colorHex,
      visibility: visibility ?? this.visibility,
      transparencyOrShowAs: transparencyOrShowAs ?? this.transparencyOrShowAs,
      eventType: eventType ?? this.eventType,
      webLink: webLink ?? this.webLink,
      conferenceJson: conferenceJson ?? this.conferenceJson,
      attachmentsJson: attachmentsJson ?? this.attachmentsJson,
      isCancelled: isCancelled ?? this.isCancelled,
      isDeleted: isDeleted ?? this.isDeleted,
      rawJson: rawJson ?? this.rawJson,
      createdAtServer: createdAtServer ?? this.createdAtServer,
      updatedAtServer: updatedAtServer ?? this.updatedAtServer,
      createdAtLocal: createdAtLocal ?? this.createdAtLocal,
      updatedAtLocal: updatedAtLocal ?? this.updatedAtLocal,
      syncStatus: syncStatus ?? this.syncStatus,
      baselineRawJson: baselineRawJson ?? this.baselineRawJson,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (accountId.present) {
      map['account_id'] = Variable<String>(accountId.value);
    }
    if (calendarSourceId.present) {
      map['calendar_source_id'] = Variable<String>(calendarSourceId.value);
    }
    if (provider.present) {
      map['provider'] = Variable<String>(provider.value);
    }
    if (providerCalendarId.present) {
      map['provider_calendar_id'] = Variable<String>(providerCalendarId.value);
    }
    if (providerEventId.present) {
      map['provider_event_id'] = Variable<String>(providerEventId.value);
    }
    if (providerRecurringEventId.present) {
      map['provider_recurring_event_id'] = Variable<String>(
        providerRecurringEventId.value,
      );
    }
    if (providerOriginalStartKey.present) {
      map['provider_original_start_key'] = Variable<String>(
        providerOriginalStartKey.value,
      );
    }
    if (etagOrChangeKey.present) {
      map['etag_or_change_key'] = Variable<String>(etagOrChangeKey.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (location.present) {
      map['location'] = Variable<String>(location.value);
    }
    if (allDay.present) {
      map['all_day'] = Variable<bool>(allDay.value);
    }
    if (startDate.present) {
      map['start_date'] = Variable<String>(startDate.value);
    }
    if (startDateTime.present) {
      map['start_date_time'] = Variable<String>(startDateTime.value);
    }
    if (startTimeZone.present) {
      map['start_time_zone'] = Variable<String>(startTimeZone.value);
    }
    if (endDate.present) {
      map['end_date'] = Variable<String>(endDate.value);
    }
    if (endDateTime.present) {
      map['end_date_time'] = Variable<String>(endDateTime.value);
    }
    if (endTimeZone.present) {
      map['end_time_zone'] = Variable<String>(endTimeZone.value);
    }
    if (recurrenceJson.present) {
      map['recurrence_json'] = Variable<String>(recurrenceJson.value);
    }
    if (remindersJson.present) {
      map['reminders_json'] = Variable<String>(remindersJson.value);
    }
    if (attendeesJson.present) {
      map['attendees_json'] = Variable<String>(attendeesJson.value);
    }
    if (categoriesJson.present) {
      map['categories_json'] = Variable<String>(categoriesJson.value);
    }
    if (organizerJson.present) {
      map['organizer_json'] = Variable<String>(organizerJson.value);
    }
    if (creatorJson.present) {
      map['creator_json'] = Variable<String>(creatorJson.value);
    }
    if (colorId.present) {
      map['color_id'] = Variable<String>(colorId.value);
    }
    if (colorHex.present) {
      map['color_hex'] = Variable<String>(colorHex.value);
    }
    if (visibility.present) {
      map['visibility'] = Variable<String>(visibility.value);
    }
    if (transparencyOrShowAs.present) {
      map['transparency_or_show_as'] = Variable<String>(
        transparencyOrShowAs.value,
      );
    }
    if (eventType.present) {
      map['event_type'] = Variable<String>(eventType.value);
    }
    if (webLink.present) {
      map['web_link'] = Variable<String>(webLink.value);
    }
    if (conferenceJson.present) {
      map['conference_json'] = Variable<String>(conferenceJson.value);
    }
    if (attachmentsJson.present) {
      map['attachments_json'] = Variable<String>(attachmentsJson.value);
    }
    if (isCancelled.present) {
      map['is_cancelled'] = Variable<bool>(isCancelled.value);
    }
    if (isDeleted.present) {
      map['is_deleted'] = Variable<bool>(isDeleted.value);
    }
    if (rawJson.present) {
      map['raw_json'] = Variable<String>(rawJson.value);
    }
    if (createdAtServer.present) {
      map['created_at_server'] = Variable<String>(createdAtServer.value);
    }
    if (updatedAtServer.present) {
      map['updated_at_server'] = Variable<String>(updatedAtServer.value);
    }
    if (createdAtLocal.present) {
      map['created_at_local'] = Variable<int>(createdAtLocal.value);
    }
    if (updatedAtLocal.present) {
      map['updated_at_local'] = Variable<int>(updatedAtLocal.value);
    }
    if (syncStatus.present) {
      map['sync_status'] = Variable<String>(syncStatus.value);
    }
    if (baselineRawJson.present) {
      map['baseline_raw_json'] = Variable<String>(baselineRawJson.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CalendarEventsCompanion(')
          ..write('id: $id, ')
          ..write('accountId: $accountId, ')
          ..write('calendarSourceId: $calendarSourceId, ')
          ..write('provider: $provider, ')
          ..write('providerCalendarId: $providerCalendarId, ')
          ..write('providerEventId: $providerEventId, ')
          ..write('providerRecurringEventId: $providerRecurringEventId, ')
          ..write('providerOriginalStartKey: $providerOriginalStartKey, ')
          ..write('etagOrChangeKey: $etagOrChangeKey, ')
          ..write('status: $status, ')
          ..write('title: $title, ')
          ..write('description: $description, ')
          ..write('location: $location, ')
          ..write('allDay: $allDay, ')
          ..write('startDate: $startDate, ')
          ..write('startDateTime: $startDateTime, ')
          ..write('startTimeZone: $startTimeZone, ')
          ..write('endDate: $endDate, ')
          ..write('endDateTime: $endDateTime, ')
          ..write('endTimeZone: $endTimeZone, ')
          ..write('recurrenceJson: $recurrenceJson, ')
          ..write('remindersJson: $remindersJson, ')
          ..write('attendeesJson: $attendeesJson, ')
          ..write('categoriesJson: $categoriesJson, ')
          ..write('organizerJson: $organizerJson, ')
          ..write('creatorJson: $creatorJson, ')
          ..write('colorId: $colorId, ')
          ..write('colorHex: $colorHex, ')
          ..write('visibility: $visibility, ')
          ..write('transparencyOrShowAs: $transparencyOrShowAs, ')
          ..write('eventType: $eventType, ')
          ..write('webLink: $webLink, ')
          ..write('conferenceJson: $conferenceJson, ')
          ..write('attachmentsJson: $attachmentsJson, ')
          ..write('isCancelled: $isCancelled, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('rawJson: $rawJson, ')
          ..write('createdAtServer: $createdAtServer, ')
          ..write('updatedAtServer: $updatedAtServer, ')
          ..write('createdAtLocal: $createdAtLocal, ')
          ..write('updatedAtLocal: $updatedAtLocal, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('baselineRawJson: $baselineRawJson, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CalendarEventAttendeesTable extends CalendarEventAttendees
    with TableInfo<$CalendarEventAttendeesTable, CalendarEventAttendee> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CalendarEventAttendeesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _calendarEventIdMeta = const VerificationMeta(
    'calendarEventId',
  );
  @override
  late final GeneratedColumn<String> calendarEventId = GeneratedColumn<String>(
    'calendar_event_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES calendar_events (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _emailMeta = const VerificationMeta('email');
  @override
  late final GeneratedColumn<String> email = GeneratedColumn<String>(
    'email',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _displayNameMeta = const VerificationMeta(
    'displayName',
  );
  @override
  late final GeneratedColumn<String> displayName = GeneratedColumn<String>(
    'display_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _responseStatusMeta = const VerificationMeta(
    'responseStatus',
  );
  @override
  late final GeneratedColumn<String> responseStatus = GeneratedColumn<String>(
    'response_status',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _optionalMeta = const VerificationMeta(
    'optional',
  );
  @override
  late final GeneratedColumn<bool> optional = GeneratedColumn<bool>(
    'optional',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("optional" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _organizerMeta = const VerificationMeta(
    'organizer',
  );
  @override
  late final GeneratedColumn<bool> organizer = GeneratedColumn<bool>(
    'organizer',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("organizer" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _selfMeta = const VerificationMeta('self');
  @override
  late final GeneratedColumn<bool> self = GeneratedColumn<bool>(
    'self',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("self" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _rawJsonMeta = const VerificationMeta(
    'rawJson',
  );
  @override
  late final GeneratedColumn<String> rawJson = GeneratedColumn<String>(
    'raw_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    calendarEventId,
    email,
    displayName,
    responseStatus,
    optional,
    organizer,
    self,
    rawJson,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'calendar_event_attendees';
  @override
  VerificationContext validateIntegrity(
    Insertable<CalendarEventAttendee> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('calendar_event_id')) {
      context.handle(
        _calendarEventIdMeta,
        calendarEventId.isAcceptableOrUnknown(
          data['calendar_event_id']!,
          _calendarEventIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_calendarEventIdMeta);
    }
    if (data.containsKey('email')) {
      context.handle(
        _emailMeta,
        email.isAcceptableOrUnknown(data['email']!, _emailMeta),
      );
    } else if (isInserting) {
      context.missing(_emailMeta);
    }
    if (data.containsKey('display_name')) {
      context.handle(
        _displayNameMeta,
        displayName.isAcceptableOrUnknown(
          data['display_name']!,
          _displayNameMeta,
        ),
      );
    }
    if (data.containsKey('response_status')) {
      context.handle(
        _responseStatusMeta,
        responseStatus.isAcceptableOrUnknown(
          data['response_status']!,
          _responseStatusMeta,
        ),
      );
    }
    if (data.containsKey('optional')) {
      context.handle(
        _optionalMeta,
        optional.isAcceptableOrUnknown(data['optional']!, _optionalMeta),
      );
    }
    if (data.containsKey('organizer')) {
      context.handle(
        _organizerMeta,
        organizer.isAcceptableOrUnknown(data['organizer']!, _organizerMeta),
      );
    }
    if (data.containsKey('self')) {
      context.handle(
        _selfMeta,
        self.isAcceptableOrUnknown(data['self']!, _selfMeta),
      );
    }
    if (data.containsKey('raw_json')) {
      context.handle(
        _rawJsonMeta,
        rawJson.isAcceptableOrUnknown(data['raw_json']!, _rawJsonMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CalendarEventAttendee map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CalendarEventAttendee(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      calendarEventId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}calendar_event_id'],
      )!,
      email: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}email'],
      )!,
      displayName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}display_name'],
      ),
      responseStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}response_status'],
      ),
      optional: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}optional'],
      )!,
      organizer: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}organizer'],
      )!,
      self: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}self'],
      )!,
      rawJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}raw_json'],
      ),
    );
  }

  @override
  $CalendarEventAttendeesTable createAlias(String alias) {
    return $CalendarEventAttendeesTable(attachedDatabase, alias);
  }
}

class CalendarEventAttendee extends DataClass
    implements Insertable<CalendarEventAttendee> {
  final String id;
  final String calendarEventId;
  final String email;
  final String? displayName;
  final String? responseStatus;
  final bool optional;
  final bool organizer;
  final bool self;
  final String? rawJson;
  const CalendarEventAttendee({
    required this.id,
    required this.calendarEventId,
    required this.email,
    this.displayName,
    this.responseStatus,
    required this.optional,
    required this.organizer,
    required this.self,
    this.rawJson,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['calendar_event_id'] = Variable<String>(calendarEventId);
    map['email'] = Variable<String>(email);
    if (!nullToAbsent || displayName != null) {
      map['display_name'] = Variable<String>(displayName);
    }
    if (!nullToAbsent || responseStatus != null) {
      map['response_status'] = Variable<String>(responseStatus);
    }
    map['optional'] = Variable<bool>(optional);
    map['organizer'] = Variable<bool>(organizer);
    map['self'] = Variable<bool>(self);
    if (!nullToAbsent || rawJson != null) {
      map['raw_json'] = Variable<String>(rawJson);
    }
    return map;
  }

  CalendarEventAttendeesCompanion toCompanion(bool nullToAbsent) {
    return CalendarEventAttendeesCompanion(
      id: Value(id),
      calendarEventId: Value(calendarEventId),
      email: Value(email),
      displayName: displayName == null && nullToAbsent
          ? const Value.absent()
          : Value(displayName),
      responseStatus: responseStatus == null && nullToAbsent
          ? const Value.absent()
          : Value(responseStatus),
      optional: Value(optional),
      organizer: Value(organizer),
      self: Value(self),
      rawJson: rawJson == null && nullToAbsent
          ? const Value.absent()
          : Value(rawJson),
    );
  }

  factory CalendarEventAttendee.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CalendarEventAttendee(
      id: serializer.fromJson<String>(json['id']),
      calendarEventId: serializer.fromJson<String>(json['calendarEventId']),
      email: serializer.fromJson<String>(json['email']),
      displayName: serializer.fromJson<String?>(json['displayName']),
      responseStatus: serializer.fromJson<String?>(json['responseStatus']),
      optional: serializer.fromJson<bool>(json['optional']),
      organizer: serializer.fromJson<bool>(json['organizer']),
      self: serializer.fromJson<bool>(json['self']),
      rawJson: serializer.fromJson<String?>(json['rawJson']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'calendarEventId': serializer.toJson<String>(calendarEventId),
      'email': serializer.toJson<String>(email),
      'displayName': serializer.toJson<String?>(displayName),
      'responseStatus': serializer.toJson<String?>(responseStatus),
      'optional': serializer.toJson<bool>(optional),
      'organizer': serializer.toJson<bool>(organizer),
      'self': serializer.toJson<bool>(self),
      'rawJson': serializer.toJson<String?>(rawJson),
    };
  }

  CalendarEventAttendee copyWith({
    String? id,
    String? calendarEventId,
    String? email,
    Value<String?> displayName = const Value.absent(),
    Value<String?> responseStatus = const Value.absent(),
    bool? optional,
    bool? organizer,
    bool? self,
    Value<String?> rawJson = const Value.absent(),
  }) => CalendarEventAttendee(
    id: id ?? this.id,
    calendarEventId: calendarEventId ?? this.calendarEventId,
    email: email ?? this.email,
    displayName: displayName.present ? displayName.value : this.displayName,
    responseStatus: responseStatus.present
        ? responseStatus.value
        : this.responseStatus,
    optional: optional ?? this.optional,
    organizer: organizer ?? this.organizer,
    self: self ?? this.self,
    rawJson: rawJson.present ? rawJson.value : this.rawJson,
  );
  CalendarEventAttendee copyWithCompanion(
    CalendarEventAttendeesCompanion data,
  ) {
    return CalendarEventAttendee(
      id: data.id.present ? data.id.value : this.id,
      calendarEventId: data.calendarEventId.present
          ? data.calendarEventId.value
          : this.calendarEventId,
      email: data.email.present ? data.email.value : this.email,
      displayName: data.displayName.present
          ? data.displayName.value
          : this.displayName,
      responseStatus: data.responseStatus.present
          ? data.responseStatus.value
          : this.responseStatus,
      optional: data.optional.present ? data.optional.value : this.optional,
      organizer: data.organizer.present ? data.organizer.value : this.organizer,
      self: data.self.present ? data.self.value : this.self,
      rawJson: data.rawJson.present ? data.rawJson.value : this.rawJson,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CalendarEventAttendee(')
          ..write('id: $id, ')
          ..write('calendarEventId: $calendarEventId, ')
          ..write('email: $email, ')
          ..write('displayName: $displayName, ')
          ..write('responseStatus: $responseStatus, ')
          ..write('optional: $optional, ')
          ..write('organizer: $organizer, ')
          ..write('self: $self, ')
          ..write('rawJson: $rawJson')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    calendarEventId,
    email,
    displayName,
    responseStatus,
    optional,
    organizer,
    self,
    rawJson,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CalendarEventAttendee &&
          other.id == this.id &&
          other.calendarEventId == this.calendarEventId &&
          other.email == this.email &&
          other.displayName == this.displayName &&
          other.responseStatus == this.responseStatus &&
          other.optional == this.optional &&
          other.organizer == this.organizer &&
          other.self == this.self &&
          other.rawJson == this.rawJson);
}

class CalendarEventAttendeesCompanion
    extends UpdateCompanion<CalendarEventAttendee> {
  final Value<String> id;
  final Value<String> calendarEventId;
  final Value<String> email;
  final Value<String?> displayName;
  final Value<String?> responseStatus;
  final Value<bool> optional;
  final Value<bool> organizer;
  final Value<bool> self;
  final Value<String?> rawJson;
  final Value<int> rowid;
  const CalendarEventAttendeesCompanion({
    this.id = const Value.absent(),
    this.calendarEventId = const Value.absent(),
    this.email = const Value.absent(),
    this.displayName = const Value.absent(),
    this.responseStatus = const Value.absent(),
    this.optional = const Value.absent(),
    this.organizer = const Value.absent(),
    this.self = const Value.absent(),
    this.rawJson = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CalendarEventAttendeesCompanion.insert({
    required String id,
    required String calendarEventId,
    required String email,
    this.displayName = const Value.absent(),
    this.responseStatus = const Value.absent(),
    this.optional = const Value.absent(),
    this.organizer = const Value.absent(),
    this.self = const Value.absent(),
    this.rawJson = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       calendarEventId = Value(calendarEventId),
       email = Value(email);
  static Insertable<CalendarEventAttendee> custom({
    Expression<String>? id,
    Expression<String>? calendarEventId,
    Expression<String>? email,
    Expression<String>? displayName,
    Expression<String>? responseStatus,
    Expression<bool>? optional,
    Expression<bool>? organizer,
    Expression<bool>? self,
    Expression<String>? rawJson,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (calendarEventId != null) 'calendar_event_id': calendarEventId,
      if (email != null) 'email': email,
      if (displayName != null) 'display_name': displayName,
      if (responseStatus != null) 'response_status': responseStatus,
      if (optional != null) 'optional': optional,
      if (organizer != null) 'organizer': organizer,
      if (self != null) 'self': self,
      if (rawJson != null) 'raw_json': rawJson,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CalendarEventAttendeesCompanion copyWith({
    Value<String>? id,
    Value<String>? calendarEventId,
    Value<String>? email,
    Value<String?>? displayName,
    Value<String?>? responseStatus,
    Value<bool>? optional,
    Value<bool>? organizer,
    Value<bool>? self,
    Value<String?>? rawJson,
    Value<int>? rowid,
  }) {
    return CalendarEventAttendeesCompanion(
      id: id ?? this.id,
      calendarEventId: calendarEventId ?? this.calendarEventId,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      responseStatus: responseStatus ?? this.responseStatus,
      optional: optional ?? this.optional,
      organizer: organizer ?? this.organizer,
      self: self ?? this.self,
      rawJson: rawJson ?? this.rawJson,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (calendarEventId.present) {
      map['calendar_event_id'] = Variable<String>(calendarEventId.value);
    }
    if (email.present) {
      map['email'] = Variable<String>(email.value);
    }
    if (displayName.present) {
      map['display_name'] = Variable<String>(displayName.value);
    }
    if (responseStatus.present) {
      map['response_status'] = Variable<String>(responseStatus.value);
    }
    if (optional.present) {
      map['optional'] = Variable<bool>(optional.value);
    }
    if (organizer.present) {
      map['organizer'] = Variable<bool>(organizer.value);
    }
    if (self.present) {
      map['self'] = Variable<bool>(self.value);
    }
    if (rawJson.present) {
      map['raw_json'] = Variable<String>(rawJson.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CalendarEventAttendeesCompanion(')
          ..write('id: $id, ')
          ..write('calendarEventId: $calendarEventId, ')
          ..write('email: $email, ')
          ..write('displayName: $displayName, ')
          ..write('responseStatus: $responseStatus, ')
          ..write('optional: $optional, ')
          ..write('organizer: $organizer, ')
          ..write('self: $self, ')
          ..write('rawJson: $rawJson, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CalendarEventRemindersTable extends CalendarEventReminders
    with TableInfo<$CalendarEventRemindersTable, CalendarEventReminder> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CalendarEventRemindersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _calendarEventIdMeta = const VerificationMeta(
    'calendarEventId',
  );
  @override
  late final GeneratedColumn<String> calendarEventId = GeneratedColumn<String>(
    'calendar_event_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES calendar_events (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _providerMeta = const VerificationMeta(
    'provider',
  );
  @override
  late final GeneratedColumn<String> provider = GeneratedColumn<String>(
    'provider',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _methodMeta = const VerificationMeta('method');
  @override
  late final GeneratedColumn<String> method = GeneratedColumn<String>(
    'method',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _minutesBeforeMeta = const VerificationMeta(
    'minutesBefore',
  );
  @override
  late final GeneratedColumn<int> minutesBefore = GeneratedColumn<int>(
    'minutes_before',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _absoluteTimeMeta = const VerificationMeta(
    'absoluteTime',
  );
  @override
  late final GeneratedColumn<String> absoluteTime = GeneratedColumn<String>(
    'absolute_time',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _enabledMeta = const VerificationMeta(
    'enabled',
  );
  @override
  late final GeneratedColumn<bool> enabled = GeneratedColumn<bool>(
    'enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("enabled" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _rawJsonMeta = const VerificationMeta(
    'rawJson',
  );
  @override
  late final GeneratedColumn<String> rawJson = GeneratedColumn<String>(
    'raw_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    calendarEventId,
    provider,
    method,
    minutesBefore,
    absoluteTime,
    enabled,
    rawJson,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'calendar_event_reminders';
  @override
  VerificationContext validateIntegrity(
    Insertable<CalendarEventReminder> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('calendar_event_id')) {
      context.handle(
        _calendarEventIdMeta,
        calendarEventId.isAcceptableOrUnknown(
          data['calendar_event_id']!,
          _calendarEventIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_calendarEventIdMeta);
    }
    if (data.containsKey('provider')) {
      context.handle(
        _providerMeta,
        provider.isAcceptableOrUnknown(data['provider']!, _providerMeta),
      );
    } else if (isInserting) {
      context.missing(_providerMeta);
    }
    if (data.containsKey('method')) {
      context.handle(
        _methodMeta,
        method.isAcceptableOrUnknown(data['method']!, _methodMeta),
      );
    }
    if (data.containsKey('minutes_before')) {
      context.handle(
        _minutesBeforeMeta,
        minutesBefore.isAcceptableOrUnknown(
          data['minutes_before']!,
          _minutesBeforeMeta,
        ),
      );
    }
    if (data.containsKey('absolute_time')) {
      context.handle(
        _absoluteTimeMeta,
        absoluteTime.isAcceptableOrUnknown(
          data['absolute_time']!,
          _absoluteTimeMeta,
        ),
      );
    }
    if (data.containsKey('enabled')) {
      context.handle(
        _enabledMeta,
        enabled.isAcceptableOrUnknown(data['enabled']!, _enabledMeta),
      );
    }
    if (data.containsKey('raw_json')) {
      context.handle(
        _rawJsonMeta,
        rawJson.isAcceptableOrUnknown(data['raw_json']!, _rawJsonMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CalendarEventReminder map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CalendarEventReminder(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      calendarEventId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}calendar_event_id'],
      )!,
      provider: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}provider'],
      )!,
      method: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}method'],
      ),
      minutesBefore: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}minutes_before'],
      ),
      absoluteTime: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}absolute_time'],
      ),
      enabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}enabled'],
      )!,
      rawJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}raw_json'],
      ),
    );
  }

  @override
  $CalendarEventRemindersTable createAlias(String alias) {
    return $CalendarEventRemindersTable(attachedDatabase, alias);
  }
}

class CalendarEventReminder extends DataClass
    implements Insertable<CalendarEventReminder> {
  final String id;
  final String calendarEventId;
  final String provider;
  final String? method;
  final int? minutesBefore;
  final String? absoluteTime;
  final bool enabled;
  final String? rawJson;
  const CalendarEventReminder({
    required this.id,
    required this.calendarEventId,
    required this.provider,
    this.method,
    this.minutesBefore,
    this.absoluteTime,
    required this.enabled,
    this.rawJson,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['calendar_event_id'] = Variable<String>(calendarEventId);
    map['provider'] = Variable<String>(provider);
    if (!nullToAbsent || method != null) {
      map['method'] = Variable<String>(method);
    }
    if (!nullToAbsent || minutesBefore != null) {
      map['minutes_before'] = Variable<int>(minutesBefore);
    }
    if (!nullToAbsent || absoluteTime != null) {
      map['absolute_time'] = Variable<String>(absoluteTime);
    }
    map['enabled'] = Variable<bool>(enabled);
    if (!nullToAbsent || rawJson != null) {
      map['raw_json'] = Variable<String>(rawJson);
    }
    return map;
  }

  CalendarEventRemindersCompanion toCompanion(bool nullToAbsent) {
    return CalendarEventRemindersCompanion(
      id: Value(id),
      calendarEventId: Value(calendarEventId),
      provider: Value(provider),
      method: method == null && nullToAbsent
          ? const Value.absent()
          : Value(method),
      minutesBefore: minutesBefore == null && nullToAbsent
          ? const Value.absent()
          : Value(minutesBefore),
      absoluteTime: absoluteTime == null && nullToAbsent
          ? const Value.absent()
          : Value(absoluteTime),
      enabled: Value(enabled),
      rawJson: rawJson == null && nullToAbsent
          ? const Value.absent()
          : Value(rawJson),
    );
  }

  factory CalendarEventReminder.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CalendarEventReminder(
      id: serializer.fromJson<String>(json['id']),
      calendarEventId: serializer.fromJson<String>(json['calendarEventId']),
      provider: serializer.fromJson<String>(json['provider']),
      method: serializer.fromJson<String?>(json['method']),
      minutesBefore: serializer.fromJson<int?>(json['minutesBefore']),
      absoluteTime: serializer.fromJson<String?>(json['absoluteTime']),
      enabled: serializer.fromJson<bool>(json['enabled']),
      rawJson: serializer.fromJson<String?>(json['rawJson']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'calendarEventId': serializer.toJson<String>(calendarEventId),
      'provider': serializer.toJson<String>(provider),
      'method': serializer.toJson<String?>(method),
      'minutesBefore': serializer.toJson<int?>(minutesBefore),
      'absoluteTime': serializer.toJson<String?>(absoluteTime),
      'enabled': serializer.toJson<bool>(enabled),
      'rawJson': serializer.toJson<String?>(rawJson),
    };
  }

  CalendarEventReminder copyWith({
    String? id,
    String? calendarEventId,
    String? provider,
    Value<String?> method = const Value.absent(),
    Value<int?> minutesBefore = const Value.absent(),
    Value<String?> absoluteTime = const Value.absent(),
    bool? enabled,
    Value<String?> rawJson = const Value.absent(),
  }) => CalendarEventReminder(
    id: id ?? this.id,
    calendarEventId: calendarEventId ?? this.calendarEventId,
    provider: provider ?? this.provider,
    method: method.present ? method.value : this.method,
    minutesBefore: minutesBefore.present
        ? minutesBefore.value
        : this.minutesBefore,
    absoluteTime: absoluteTime.present ? absoluteTime.value : this.absoluteTime,
    enabled: enabled ?? this.enabled,
    rawJson: rawJson.present ? rawJson.value : this.rawJson,
  );
  CalendarEventReminder copyWithCompanion(
    CalendarEventRemindersCompanion data,
  ) {
    return CalendarEventReminder(
      id: data.id.present ? data.id.value : this.id,
      calendarEventId: data.calendarEventId.present
          ? data.calendarEventId.value
          : this.calendarEventId,
      provider: data.provider.present ? data.provider.value : this.provider,
      method: data.method.present ? data.method.value : this.method,
      minutesBefore: data.minutesBefore.present
          ? data.minutesBefore.value
          : this.minutesBefore,
      absoluteTime: data.absoluteTime.present
          ? data.absoluteTime.value
          : this.absoluteTime,
      enabled: data.enabled.present ? data.enabled.value : this.enabled,
      rawJson: data.rawJson.present ? data.rawJson.value : this.rawJson,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CalendarEventReminder(')
          ..write('id: $id, ')
          ..write('calendarEventId: $calendarEventId, ')
          ..write('provider: $provider, ')
          ..write('method: $method, ')
          ..write('minutesBefore: $minutesBefore, ')
          ..write('absoluteTime: $absoluteTime, ')
          ..write('enabled: $enabled, ')
          ..write('rawJson: $rawJson')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    calendarEventId,
    provider,
    method,
    minutesBefore,
    absoluteTime,
    enabled,
    rawJson,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CalendarEventReminder &&
          other.id == this.id &&
          other.calendarEventId == this.calendarEventId &&
          other.provider == this.provider &&
          other.method == this.method &&
          other.minutesBefore == this.minutesBefore &&
          other.absoluteTime == this.absoluteTime &&
          other.enabled == this.enabled &&
          other.rawJson == this.rawJson);
}

class CalendarEventRemindersCompanion
    extends UpdateCompanion<CalendarEventReminder> {
  final Value<String> id;
  final Value<String> calendarEventId;
  final Value<String> provider;
  final Value<String?> method;
  final Value<int?> minutesBefore;
  final Value<String?> absoluteTime;
  final Value<bool> enabled;
  final Value<String?> rawJson;
  final Value<int> rowid;
  const CalendarEventRemindersCompanion({
    this.id = const Value.absent(),
    this.calendarEventId = const Value.absent(),
    this.provider = const Value.absent(),
    this.method = const Value.absent(),
    this.minutesBefore = const Value.absent(),
    this.absoluteTime = const Value.absent(),
    this.enabled = const Value.absent(),
    this.rawJson = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CalendarEventRemindersCompanion.insert({
    required String id,
    required String calendarEventId,
    required String provider,
    this.method = const Value.absent(),
    this.minutesBefore = const Value.absent(),
    this.absoluteTime = const Value.absent(),
    this.enabled = const Value.absent(),
    this.rawJson = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       calendarEventId = Value(calendarEventId),
       provider = Value(provider);
  static Insertable<CalendarEventReminder> custom({
    Expression<String>? id,
    Expression<String>? calendarEventId,
    Expression<String>? provider,
    Expression<String>? method,
    Expression<int>? minutesBefore,
    Expression<String>? absoluteTime,
    Expression<bool>? enabled,
    Expression<String>? rawJson,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (calendarEventId != null) 'calendar_event_id': calendarEventId,
      if (provider != null) 'provider': provider,
      if (method != null) 'method': method,
      if (minutesBefore != null) 'minutes_before': minutesBefore,
      if (absoluteTime != null) 'absolute_time': absoluteTime,
      if (enabled != null) 'enabled': enabled,
      if (rawJson != null) 'raw_json': rawJson,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CalendarEventRemindersCompanion copyWith({
    Value<String>? id,
    Value<String>? calendarEventId,
    Value<String>? provider,
    Value<String?>? method,
    Value<int?>? minutesBefore,
    Value<String?>? absoluteTime,
    Value<bool>? enabled,
    Value<String?>? rawJson,
    Value<int>? rowid,
  }) {
    return CalendarEventRemindersCompanion(
      id: id ?? this.id,
      calendarEventId: calendarEventId ?? this.calendarEventId,
      provider: provider ?? this.provider,
      method: method ?? this.method,
      minutesBefore: minutesBefore ?? this.minutesBefore,
      absoluteTime: absoluteTime ?? this.absoluteTime,
      enabled: enabled ?? this.enabled,
      rawJson: rawJson ?? this.rawJson,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (calendarEventId.present) {
      map['calendar_event_id'] = Variable<String>(calendarEventId.value);
    }
    if (provider.present) {
      map['provider'] = Variable<String>(provider.value);
    }
    if (method.present) {
      map['method'] = Variable<String>(method.value);
    }
    if (minutesBefore.present) {
      map['minutes_before'] = Variable<int>(minutesBefore.value);
    }
    if (absoluteTime.present) {
      map['absolute_time'] = Variable<String>(absoluteTime.value);
    }
    if (enabled.present) {
      map['enabled'] = Variable<bool>(enabled.value);
    }
    if (rawJson.present) {
      map['raw_json'] = Variable<String>(rawJson.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CalendarEventRemindersCompanion(')
          ..write('id: $id, ')
          ..write('calendarEventId: $calendarEventId, ')
          ..write('provider: $provider, ')
          ..write('method: $method, ')
          ..write('minutesBefore: $minutesBefore, ')
          ..write('absoluteTime: $absoluteTime, ')
          ..write('enabled: $enabled, ')
          ..write('rawJson: $rawJson, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CalendarSyncStatesTable extends CalendarSyncStates
    with TableInfo<$CalendarSyncStatesTable, CalendarSyncState> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CalendarSyncStatesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _accountIdMeta = const VerificationMeta(
    'accountId',
  );
  @override
  late final GeneratedColumn<String> accountId = GeneratedColumn<String>(
    'account_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES accounts (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _calendarSourceIdMeta = const VerificationMeta(
    'calendarSourceId',
  );
  @override
  late final GeneratedColumn<String> calendarSourceId = GeneratedColumn<String>(
    'calendar_source_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES calendar_sources (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _providerMeta = const VerificationMeta(
    'provider',
  );
  @override
  late final GeneratedColumn<String> provider = GeneratedColumn<String>(
    'provider',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _syncKindMeta = const VerificationMeta(
    'syncKind',
  );
  @override
  late final GeneratedColumn<String> syncKind = GeneratedColumn<String>(
    'sync_kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _rangeStartMeta = const VerificationMeta(
    'rangeStart',
  );
  @override
  late final GeneratedColumn<String> rangeStart = GeneratedColumn<String>(
    'range_start',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _rangeEndMeta = const VerificationMeta(
    'rangeEnd',
  );
  @override
  late final GeneratedColumn<String> rangeEnd = GeneratedColumn<String>(
    'range_end',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _googleSyncTokenMeta = const VerificationMeta(
    'googleSyncToken',
  );
  @override
  late final GeneratedColumn<String> googleSyncToken = GeneratedColumn<String>(
    'google_sync_token',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _microsoftDeltaLinkMeta =
      const VerificationMeta('microsoftDeltaLink');
  @override
  late final GeneratedColumn<String> microsoftDeltaLink =
      GeneratedColumn<String>(
        'microsoft_delta_link',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _lastFullSyncAtMeta = const VerificationMeta(
    'lastFullSyncAt',
  );
  @override
  late final GeneratedColumn<int> lastFullSyncAt = GeneratedColumn<int>(
    'last_full_sync_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastIncrementalSyncAtMeta =
      const VerificationMeta('lastIncrementalSyncAt');
  @override
  late final GeneratedColumn<int> lastIncrementalSyncAt = GeneratedColumn<int>(
    'last_incremental_sync_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastErrorMeta = const VerificationMeta(
    'lastError',
  );
  @override
  late final GeneratedColumn<String> lastError = GeneratedColumn<String>(
    'last_error',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _rawStateJsonMeta = const VerificationMeta(
    'rawStateJson',
  );
  @override
  late final GeneratedColumn<String> rawStateJson = GeneratedColumn<String>(
    'raw_state_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    accountId,
    calendarSourceId,
    provider,
    syncKind,
    rangeStart,
    rangeEnd,
    googleSyncToken,
    microsoftDeltaLink,
    lastFullSyncAt,
    lastIncrementalSyncAt,
    lastError,
    rawStateJson,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'calendar_sync_states';
  @override
  VerificationContext validateIntegrity(
    Insertable<CalendarSyncState> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('account_id')) {
      context.handle(
        _accountIdMeta,
        accountId.isAcceptableOrUnknown(data['account_id']!, _accountIdMeta),
      );
    } else if (isInserting) {
      context.missing(_accountIdMeta);
    }
    if (data.containsKey('calendar_source_id')) {
      context.handle(
        _calendarSourceIdMeta,
        calendarSourceId.isAcceptableOrUnknown(
          data['calendar_source_id']!,
          _calendarSourceIdMeta,
        ),
      );
    }
    if (data.containsKey('provider')) {
      context.handle(
        _providerMeta,
        provider.isAcceptableOrUnknown(data['provider']!, _providerMeta),
      );
    } else if (isInserting) {
      context.missing(_providerMeta);
    }
    if (data.containsKey('sync_kind')) {
      context.handle(
        _syncKindMeta,
        syncKind.isAcceptableOrUnknown(data['sync_kind']!, _syncKindMeta),
      );
    } else if (isInserting) {
      context.missing(_syncKindMeta);
    }
    if (data.containsKey('range_start')) {
      context.handle(
        _rangeStartMeta,
        rangeStart.isAcceptableOrUnknown(data['range_start']!, _rangeStartMeta),
      );
    }
    if (data.containsKey('range_end')) {
      context.handle(
        _rangeEndMeta,
        rangeEnd.isAcceptableOrUnknown(data['range_end']!, _rangeEndMeta),
      );
    }
    if (data.containsKey('google_sync_token')) {
      context.handle(
        _googleSyncTokenMeta,
        googleSyncToken.isAcceptableOrUnknown(
          data['google_sync_token']!,
          _googleSyncTokenMeta,
        ),
      );
    }
    if (data.containsKey('microsoft_delta_link')) {
      context.handle(
        _microsoftDeltaLinkMeta,
        microsoftDeltaLink.isAcceptableOrUnknown(
          data['microsoft_delta_link']!,
          _microsoftDeltaLinkMeta,
        ),
      );
    }
    if (data.containsKey('last_full_sync_at')) {
      context.handle(
        _lastFullSyncAtMeta,
        lastFullSyncAt.isAcceptableOrUnknown(
          data['last_full_sync_at']!,
          _lastFullSyncAtMeta,
        ),
      );
    }
    if (data.containsKey('last_incremental_sync_at')) {
      context.handle(
        _lastIncrementalSyncAtMeta,
        lastIncrementalSyncAt.isAcceptableOrUnknown(
          data['last_incremental_sync_at']!,
          _lastIncrementalSyncAtMeta,
        ),
      );
    }
    if (data.containsKey('last_error')) {
      context.handle(
        _lastErrorMeta,
        lastError.isAcceptableOrUnknown(data['last_error']!, _lastErrorMeta),
      );
    }
    if (data.containsKey('raw_state_json')) {
      context.handle(
        _rawStateJsonMeta,
        rawStateJson.isAcceptableOrUnknown(
          data['raw_state_json']!,
          _rawStateJsonMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CalendarSyncState map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CalendarSyncState(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      accountId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}account_id'],
      )!,
      calendarSourceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}calendar_source_id'],
      ),
      provider: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}provider'],
      )!,
      syncKind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sync_kind'],
      )!,
      rangeStart: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}range_start'],
      ),
      rangeEnd: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}range_end'],
      ),
      googleSyncToken: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}google_sync_token'],
      ),
      microsoftDeltaLink: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}microsoft_delta_link'],
      ),
      lastFullSyncAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_full_sync_at'],
      ),
      lastIncrementalSyncAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_incremental_sync_at'],
      ),
      lastError: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_error'],
      ),
      rawStateJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}raw_state_json'],
      ),
    );
  }

  @override
  $CalendarSyncStatesTable createAlias(String alias) {
    return $CalendarSyncStatesTable(attachedDatabase, alias);
  }
}

class CalendarSyncState extends DataClass
    implements Insertable<CalendarSyncState> {
  final String id;
  final String accountId;
  final String? calendarSourceId;
  final String provider;
  final String syncKind;
  final String? rangeStart;
  final String? rangeEnd;
  final String? googleSyncToken;
  final String? microsoftDeltaLink;
  final int? lastFullSyncAt;
  final int? lastIncrementalSyncAt;
  final String? lastError;
  final String? rawStateJson;
  const CalendarSyncState({
    required this.id,
    required this.accountId,
    this.calendarSourceId,
    required this.provider,
    required this.syncKind,
    this.rangeStart,
    this.rangeEnd,
    this.googleSyncToken,
    this.microsoftDeltaLink,
    this.lastFullSyncAt,
    this.lastIncrementalSyncAt,
    this.lastError,
    this.rawStateJson,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['account_id'] = Variable<String>(accountId);
    if (!nullToAbsent || calendarSourceId != null) {
      map['calendar_source_id'] = Variable<String>(calendarSourceId);
    }
    map['provider'] = Variable<String>(provider);
    map['sync_kind'] = Variable<String>(syncKind);
    if (!nullToAbsent || rangeStart != null) {
      map['range_start'] = Variable<String>(rangeStart);
    }
    if (!nullToAbsent || rangeEnd != null) {
      map['range_end'] = Variable<String>(rangeEnd);
    }
    if (!nullToAbsent || googleSyncToken != null) {
      map['google_sync_token'] = Variable<String>(googleSyncToken);
    }
    if (!nullToAbsent || microsoftDeltaLink != null) {
      map['microsoft_delta_link'] = Variable<String>(microsoftDeltaLink);
    }
    if (!nullToAbsent || lastFullSyncAt != null) {
      map['last_full_sync_at'] = Variable<int>(lastFullSyncAt);
    }
    if (!nullToAbsent || lastIncrementalSyncAt != null) {
      map['last_incremental_sync_at'] = Variable<int>(lastIncrementalSyncAt);
    }
    if (!nullToAbsent || lastError != null) {
      map['last_error'] = Variable<String>(lastError);
    }
    if (!nullToAbsent || rawStateJson != null) {
      map['raw_state_json'] = Variable<String>(rawStateJson);
    }
    return map;
  }

  CalendarSyncStatesCompanion toCompanion(bool nullToAbsent) {
    return CalendarSyncStatesCompanion(
      id: Value(id),
      accountId: Value(accountId),
      calendarSourceId: calendarSourceId == null && nullToAbsent
          ? const Value.absent()
          : Value(calendarSourceId),
      provider: Value(provider),
      syncKind: Value(syncKind),
      rangeStart: rangeStart == null && nullToAbsent
          ? const Value.absent()
          : Value(rangeStart),
      rangeEnd: rangeEnd == null && nullToAbsent
          ? const Value.absent()
          : Value(rangeEnd),
      googleSyncToken: googleSyncToken == null && nullToAbsent
          ? const Value.absent()
          : Value(googleSyncToken),
      microsoftDeltaLink: microsoftDeltaLink == null && nullToAbsent
          ? const Value.absent()
          : Value(microsoftDeltaLink),
      lastFullSyncAt: lastFullSyncAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastFullSyncAt),
      lastIncrementalSyncAt: lastIncrementalSyncAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastIncrementalSyncAt),
      lastError: lastError == null && nullToAbsent
          ? const Value.absent()
          : Value(lastError),
      rawStateJson: rawStateJson == null && nullToAbsent
          ? const Value.absent()
          : Value(rawStateJson),
    );
  }

  factory CalendarSyncState.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CalendarSyncState(
      id: serializer.fromJson<String>(json['id']),
      accountId: serializer.fromJson<String>(json['accountId']),
      calendarSourceId: serializer.fromJson<String?>(json['calendarSourceId']),
      provider: serializer.fromJson<String>(json['provider']),
      syncKind: serializer.fromJson<String>(json['syncKind']),
      rangeStart: serializer.fromJson<String?>(json['rangeStart']),
      rangeEnd: serializer.fromJson<String?>(json['rangeEnd']),
      googleSyncToken: serializer.fromJson<String?>(json['googleSyncToken']),
      microsoftDeltaLink: serializer.fromJson<String?>(
        json['microsoftDeltaLink'],
      ),
      lastFullSyncAt: serializer.fromJson<int?>(json['lastFullSyncAt']),
      lastIncrementalSyncAt: serializer.fromJson<int?>(
        json['lastIncrementalSyncAt'],
      ),
      lastError: serializer.fromJson<String?>(json['lastError']),
      rawStateJson: serializer.fromJson<String?>(json['rawStateJson']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'accountId': serializer.toJson<String>(accountId),
      'calendarSourceId': serializer.toJson<String?>(calendarSourceId),
      'provider': serializer.toJson<String>(provider),
      'syncKind': serializer.toJson<String>(syncKind),
      'rangeStart': serializer.toJson<String?>(rangeStart),
      'rangeEnd': serializer.toJson<String?>(rangeEnd),
      'googleSyncToken': serializer.toJson<String?>(googleSyncToken),
      'microsoftDeltaLink': serializer.toJson<String?>(microsoftDeltaLink),
      'lastFullSyncAt': serializer.toJson<int?>(lastFullSyncAt),
      'lastIncrementalSyncAt': serializer.toJson<int?>(lastIncrementalSyncAt),
      'lastError': serializer.toJson<String?>(lastError),
      'rawStateJson': serializer.toJson<String?>(rawStateJson),
    };
  }

  CalendarSyncState copyWith({
    String? id,
    String? accountId,
    Value<String?> calendarSourceId = const Value.absent(),
    String? provider,
    String? syncKind,
    Value<String?> rangeStart = const Value.absent(),
    Value<String?> rangeEnd = const Value.absent(),
    Value<String?> googleSyncToken = const Value.absent(),
    Value<String?> microsoftDeltaLink = const Value.absent(),
    Value<int?> lastFullSyncAt = const Value.absent(),
    Value<int?> lastIncrementalSyncAt = const Value.absent(),
    Value<String?> lastError = const Value.absent(),
    Value<String?> rawStateJson = const Value.absent(),
  }) => CalendarSyncState(
    id: id ?? this.id,
    accountId: accountId ?? this.accountId,
    calendarSourceId: calendarSourceId.present
        ? calendarSourceId.value
        : this.calendarSourceId,
    provider: provider ?? this.provider,
    syncKind: syncKind ?? this.syncKind,
    rangeStart: rangeStart.present ? rangeStart.value : this.rangeStart,
    rangeEnd: rangeEnd.present ? rangeEnd.value : this.rangeEnd,
    googleSyncToken: googleSyncToken.present
        ? googleSyncToken.value
        : this.googleSyncToken,
    microsoftDeltaLink: microsoftDeltaLink.present
        ? microsoftDeltaLink.value
        : this.microsoftDeltaLink,
    lastFullSyncAt: lastFullSyncAt.present
        ? lastFullSyncAt.value
        : this.lastFullSyncAt,
    lastIncrementalSyncAt: lastIncrementalSyncAt.present
        ? lastIncrementalSyncAt.value
        : this.lastIncrementalSyncAt,
    lastError: lastError.present ? lastError.value : this.lastError,
    rawStateJson: rawStateJson.present ? rawStateJson.value : this.rawStateJson,
  );
  CalendarSyncState copyWithCompanion(CalendarSyncStatesCompanion data) {
    return CalendarSyncState(
      id: data.id.present ? data.id.value : this.id,
      accountId: data.accountId.present ? data.accountId.value : this.accountId,
      calendarSourceId: data.calendarSourceId.present
          ? data.calendarSourceId.value
          : this.calendarSourceId,
      provider: data.provider.present ? data.provider.value : this.provider,
      syncKind: data.syncKind.present ? data.syncKind.value : this.syncKind,
      rangeStart: data.rangeStart.present
          ? data.rangeStart.value
          : this.rangeStart,
      rangeEnd: data.rangeEnd.present ? data.rangeEnd.value : this.rangeEnd,
      googleSyncToken: data.googleSyncToken.present
          ? data.googleSyncToken.value
          : this.googleSyncToken,
      microsoftDeltaLink: data.microsoftDeltaLink.present
          ? data.microsoftDeltaLink.value
          : this.microsoftDeltaLink,
      lastFullSyncAt: data.lastFullSyncAt.present
          ? data.lastFullSyncAt.value
          : this.lastFullSyncAt,
      lastIncrementalSyncAt: data.lastIncrementalSyncAt.present
          ? data.lastIncrementalSyncAt.value
          : this.lastIncrementalSyncAt,
      lastError: data.lastError.present ? data.lastError.value : this.lastError,
      rawStateJson: data.rawStateJson.present
          ? data.rawStateJson.value
          : this.rawStateJson,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CalendarSyncState(')
          ..write('id: $id, ')
          ..write('accountId: $accountId, ')
          ..write('calendarSourceId: $calendarSourceId, ')
          ..write('provider: $provider, ')
          ..write('syncKind: $syncKind, ')
          ..write('rangeStart: $rangeStart, ')
          ..write('rangeEnd: $rangeEnd, ')
          ..write('googleSyncToken: $googleSyncToken, ')
          ..write('microsoftDeltaLink: $microsoftDeltaLink, ')
          ..write('lastFullSyncAt: $lastFullSyncAt, ')
          ..write('lastIncrementalSyncAt: $lastIncrementalSyncAt, ')
          ..write('lastError: $lastError, ')
          ..write('rawStateJson: $rawStateJson')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    accountId,
    calendarSourceId,
    provider,
    syncKind,
    rangeStart,
    rangeEnd,
    googleSyncToken,
    microsoftDeltaLink,
    lastFullSyncAt,
    lastIncrementalSyncAt,
    lastError,
    rawStateJson,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CalendarSyncState &&
          other.id == this.id &&
          other.accountId == this.accountId &&
          other.calendarSourceId == this.calendarSourceId &&
          other.provider == this.provider &&
          other.syncKind == this.syncKind &&
          other.rangeStart == this.rangeStart &&
          other.rangeEnd == this.rangeEnd &&
          other.googleSyncToken == this.googleSyncToken &&
          other.microsoftDeltaLink == this.microsoftDeltaLink &&
          other.lastFullSyncAt == this.lastFullSyncAt &&
          other.lastIncrementalSyncAt == this.lastIncrementalSyncAt &&
          other.lastError == this.lastError &&
          other.rawStateJson == this.rawStateJson);
}

class CalendarSyncStatesCompanion extends UpdateCompanion<CalendarSyncState> {
  final Value<String> id;
  final Value<String> accountId;
  final Value<String?> calendarSourceId;
  final Value<String> provider;
  final Value<String> syncKind;
  final Value<String?> rangeStart;
  final Value<String?> rangeEnd;
  final Value<String?> googleSyncToken;
  final Value<String?> microsoftDeltaLink;
  final Value<int?> lastFullSyncAt;
  final Value<int?> lastIncrementalSyncAt;
  final Value<String?> lastError;
  final Value<String?> rawStateJson;
  final Value<int> rowid;
  const CalendarSyncStatesCompanion({
    this.id = const Value.absent(),
    this.accountId = const Value.absent(),
    this.calendarSourceId = const Value.absent(),
    this.provider = const Value.absent(),
    this.syncKind = const Value.absent(),
    this.rangeStart = const Value.absent(),
    this.rangeEnd = const Value.absent(),
    this.googleSyncToken = const Value.absent(),
    this.microsoftDeltaLink = const Value.absent(),
    this.lastFullSyncAt = const Value.absent(),
    this.lastIncrementalSyncAt = const Value.absent(),
    this.lastError = const Value.absent(),
    this.rawStateJson = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CalendarSyncStatesCompanion.insert({
    required String id,
    required String accountId,
    this.calendarSourceId = const Value.absent(),
    required String provider,
    required String syncKind,
    this.rangeStart = const Value.absent(),
    this.rangeEnd = const Value.absent(),
    this.googleSyncToken = const Value.absent(),
    this.microsoftDeltaLink = const Value.absent(),
    this.lastFullSyncAt = const Value.absent(),
    this.lastIncrementalSyncAt = const Value.absent(),
    this.lastError = const Value.absent(),
    this.rawStateJson = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       accountId = Value(accountId),
       provider = Value(provider),
       syncKind = Value(syncKind);
  static Insertable<CalendarSyncState> custom({
    Expression<String>? id,
    Expression<String>? accountId,
    Expression<String>? calendarSourceId,
    Expression<String>? provider,
    Expression<String>? syncKind,
    Expression<String>? rangeStart,
    Expression<String>? rangeEnd,
    Expression<String>? googleSyncToken,
    Expression<String>? microsoftDeltaLink,
    Expression<int>? lastFullSyncAt,
    Expression<int>? lastIncrementalSyncAt,
    Expression<String>? lastError,
    Expression<String>? rawStateJson,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (accountId != null) 'account_id': accountId,
      if (calendarSourceId != null) 'calendar_source_id': calendarSourceId,
      if (provider != null) 'provider': provider,
      if (syncKind != null) 'sync_kind': syncKind,
      if (rangeStart != null) 'range_start': rangeStart,
      if (rangeEnd != null) 'range_end': rangeEnd,
      if (googleSyncToken != null) 'google_sync_token': googleSyncToken,
      if (microsoftDeltaLink != null)
        'microsoft_delta_link': microsoftDeltaLink,
      if (lastFullSyncAt != null) 'last_full_sync_at': lastFullSyncAt,
      if (lastIncrementalSyncAt != null)
        'last_incremental_sync_at': lastIncrementalSyncAt,
      if (lastError != null) 'last_error': lastError,
      if (rawStateJson != null) 'raw_state_json': rawStateJson,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CalendarSyncStatesCompanion copyWith({
    Value<String>? id,
    Value<String>? accountId,
    Value<String?>? calendarSourceId,
    Value<String>? provider,
    Value<String>? syncKind,
    Value<String?>? rangeStart,
    Value<String?>? rangeEnd,
    Value<String?>? googleSyncToken,
    Value<String?>? microsoftDeltaLink,
    Value<int?>? lastFullSyncAt,
    Value<int?>? lastIncrementalSyncAt,
    Value<String?>? lastError,
    Value<String?>? rawStateJson,
    Value<int>? rowid,
  }) {
    return CalendarSyncStatesCompanion(
      id: id ?? this.id,
      accountId: accountId ?? this.accountId,
      calendarSourceId: calendarSourceId ?? this.calendarSourceId,
      provider: provider ?? this.provider,
      syncKind: syncKind ?? this.syncKind,
      rangeStart: rangeStart ?? this.rangeStart,
      rangeEnd: rangeEnd ?? this.rangeEnd,
      googleSyncToken: googleSyncToken ?? this.googleSyncToken,
      microsoftDeltaLink: microsoftDeltaLink ?? this.microsoftDeltaLink,
      lastFullSyncAt: lastFullSyncAt ?? this.lastFullSyncAt,
      lastIncrementalSyncAt:
          lastIncrementalSyncAt ?? this.lastIncrementalSyncAt,
      lastError: lastError ?? this.lastError,
      rawStateJson: rawStateJson ?? this.rawStateJson,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (accountId.present) {
      map['account_id'] = Variable<String>(accountId.value);
    }
    if (calendarSourceId.present) {
      map['calendar_source_id'] = Variable<String>(calendarSourceId.value);
    }
    if (provider.present) {
      map['provider'] = Variable<String>(provider.value);
    }
    if (syncKind.present) {
      map['sync_kind'] = Variable<String>(syncKind.value);
    }
    if (rangeStart.present) {
      map['range_start'] = Variable<String>(rangeStart.value);
    }
    if (rangeEnd.present) {
      map['range_end'] = Variable<String>(rangeEnd.value);
    }
    if (googleSyncToken.present) {
      map['google_sync_token'] = Variable<String>(googleSyncToken.value);
    }
    if (microsoftDeltaLink.present) {
      map['microsoft_delta_link'] = Variable<String>(microsoftDeltaLink.value);
    }
    if (lastFullSyncAt.present) {
      map['last_full_sync_at'] = Variable<int>(lastFullSyncAt.value);
    }
    if (lastIncrementalSyncAt.present) {
      map['last_incremental_sync_at'] = Variable<int>(
        lastIncrementalSyncAt.value,
      );
    }
    if (lastError.present) {
      map['last_error'] = Variable<String>(lastError.value);
    }
    if (rawStateJson.present) {
      map['raw_state_json'] = Variable<String>(rawStateJson.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CalendarSyncStatesCompanion(')
          ..write('id: $id, ')
          ..write('accountId: $accountId, ')
          ..write('calendarSourceId: $calendarSourceId, ')
          ..write('provider: $provider, ')
          ..write('syncKind: $syncKind, ')
          ..write('rangeStart: $rangeStart, ')
          ..write('rangeEnd: $rangeEnd, ')
          ..write('googleSyncToken: $googleSyncToken, ')
          ..write('microsoftDeltaLink: $microsoftDeltaLink, ')
          ..write('lastFullSyncAt: $lastFullSyncAt, ')
          ..write('lastIncrementalSyncAt: $lastIncrementalSyncAt, ')
          ..write('lastError: $lastError, ')
          ..write('rawStateJson: $rawStateJson, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CalendarColorsTable extends CalendarColors
    with TableInfo<$CalendarColorsTable, CalendarColor> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CalendarColorsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _providerMeta = const VerificationMeta(
    'provider',
  );
  @override
  late final GeneratedColumn<String> provider = GeneratedColumn<String>(
    'provider',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _colorTypeMeta = const VerificationMeta(
    'colorType',
  );
  @override
  late final GeneratedColumn<String> colorType = GeneratedColumn<String>(
    'color_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _colorIdMeta = const VerificationMeta(
    'colorId',
  );
  @override
  late final GeneratedColumn<String> colorId = GeneratedColumn<String>(
    'color_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _backgroundMeta = const VerificationMeta(
    'background',
  );
  @override
  late final GeneratedColumn<String> background = GeneratedColumn<String>(
    'background',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _foregroundMeta = const VerificationMeta(
    'foreground',
  );
  @override
  late final GeneratedColumn<String> foreground = GeneratedColumn<String>(
    'foreground',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _rawJsonMeta = const VerificationMeta(
    'rawJson',
  );
  @override
  late final GeneratedColumn<String> rawJson = GeneratedColumn<String>(
    'raw_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    provider,
    colorType,
    colorId,
    background,
    foreground,
    rawJson,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'calendar_colors';
  @override
  VerificationContext validateIntegrity(
    Insertable<CalendarColor> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('provider')) {
      context.handle(
        _providerMeta,
        provider.isAcceptableOrUnknown(data['provider']!, _providerMeta),
      );
    } else if (isInserting) {
      context.missing(_providerMeta);
    }
    if (data.containsKey('color_type')) {
      context.handle(
        _colorTypeMeta,
        colorType.isAcceptableOrUnknown(data['color_type']!, _colorTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_colorTypeMeta);
    }
    if (data.containsKey('color_id')) {
      context.handle(
        _colorIdMeta,
        colorId.isAcceptableOrUnknown(data['color_id']!, _colorIdMeta),
      );
    } else if (isInserting) {
      context.missing(_colorIdMeta);
    }
    if (data.containsKey('background')) {
      context.handle(
        _backgroundMeta,
        background.isAcceptableOrUnknown(data['background']!, _backgroundMeta),
      );
    } else if (isInserting) {
      context.missing(_backgroundMeta);
    }
    if (data.containsKey('foreground')) {
      context.handle(
        _foregroundMeta,
        foreground.isAcceptableOrUnknown(data['foreground']!, _foregroundMeta),
      );
    }
    if (data.containsKey('raw_json')) {
      context.handle(
        _rawJsonMeta,
        rawJson.isAcceptableOrUnknown(data['raw_json']!, _rawJsonMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {provider, colorType, colorId};
  @override
  CalendarColor map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CalendarColor(
      provider: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}provider'],
      )!,
      colorType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}color_type'],
      )!,
      colorId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}color_id'],
      )!,
      background: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}background'],
      )!,
      foreground: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}foreground'],
      ),
      rawJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}raw_json'],
      ),
    );
  }

  @override
  $CalendarColorsTable createAlias(String alias) {
    return $CalendarColorsTable(attachedDatabase, alias);
  }
}

class CalendarColor extends DataClass implements Insertable<CalendarColor> {
  final String provider;
  final String colorType;
  final String colorId;
  final String background;
  final String? foreground;
  final String? rawJson;
  const CalendarColor({
    required this.provider,
    required this.colorType,
    required this.colorId,
    required this.background,
    this.foreground,
    this.rawJson,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['provider'] = Variable<String>(provider);
    map['color_type'] = Variable<String>(colorType);
    map['color_id'] = Variable<String>(colorId);
    map['background'] = Variable<String>(background);
    if (!nullToAbsent || foreground != null) {
      map['foreground'] = Variable<String>(foreground);
    }
    if (!nullToAbsent || rawJson != null) {
      map['raw_json'] = Variable<String>(rawJson);
    }
    return map;
  }

  CalendarColorsCompanion toCompanion(bool nullToAbsent) {
    return CalendarColorsCompanion(
      provider: Value(provider),
      colorType: Value(colorType),
      colorId: Value(colorId),
      background: Value(background),
      foreground: foreground == null && nullToAbsent
          ? const Value.absent()
          : Value(foreground),
      rawJson: rawJson == null && nullToAbsent
          ? const Value.absent()
          : Value(rawJson),
    );
  }

  factory CalendarColor.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CalendarColor(
      provider: serializer.fromJson<String>(json['provider']),
      colorType: serializer.fromJson<String>(json['colorType']),
      colorId: serializer.fromJson<String>(json['colorId']),
      background: serializer.fromJson<String>(json['background']),
      foreground: serializer.fromJson<String?>(json['foreground']),
      rawJson: serializer.fromJson<String?>(json['rawJson']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'provider': serializer.toJson<String>(provider),
      'colorType': serializer.toJson<String>(colorType),
      'colorId': serializer.toJson<String>(colorId),
      'background': serializer.toJson<String>(background),
      'foreground': serializer.toJson<String?>(foreground),
      'rawJson': serializer.toJson<String?>(rawJson),
    };
  }

  CalendarColor copyWith({
    String? provider,
    String? colorType,
    String? colorId,
    String? background,
    Value<String?> foreground = const Value.absent(),
    Value<String?> rawJson = const Value.absent(),
  }) => CalendarColor(
    provider: provider ?? this.provider,
    colorType: colorType ?? this.colorType,
    colorId: colorId ?? this.colorId,
    background: background ?? this.background,
    foreground: foreground.present ? foreground.value : this.foreground,
    rawJson: rawJson.present ? rawJson.value : this.rawJson,
  );
  CalendarColor copyWithCompanion(CalendarColorsCompanion data) {
    return CalendarColor(
      provider: data.provider.present ? data.provider.value : this.provider,
      colorType: data.colorType.present ? data.colorType.value : this.colorType,
      colorId: data.colorId.present ? data.colorId.value : this.colorId,
      background: data.background.present
          ? data.background.value
          : this.background,
      foreground: data.foreground.present
          ? data.foreground.value
          : this.foreground,
      rawJson: data.rawJson.present ? data.rawJson.value : this.rawJson,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CalendarColor(')
          ..write('provider: $provider, ')
          ..write('colorType: $colorType, ')
          ..write('colorId: $colorId, ')
          ..write('background: $background, ')
          ..write('foreground: $foreground, ')
          ..write('rawJson: $rawJson')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    provider,
    colorType,
    colorId,
    background,
    foreground,
    rawJson,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CalendarColor &&
          other.provider == this.provider &&
          other.colorType == this.colorType &&
          other.colorId == this.colorId &&
          other.background == this.background &&
          other.foreground == this.foreground &&
          other.rawJson == this.rawJson);
}

class CalendarColorsCompanion extends UpdateCompanion<CalendarColor> {
  final Value<String> provider;
  final Value<String> colorType;
  final Value<String> colorId;
  final Value<String> background;
  final Value<String?> foreground;
  final Value<String?> rawJson;
  final Value<int> rowid;
  const CalendarColorsCompanion({
    this.provider = const Value.absent(),
    this.colorType = const Value.absent(),
    this.colorId = const Value.absent(),
    this.background = const Value.absent(),
    this.foreground = const Value.absent(),
    this.rawJson = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CalendarColorsCompanion.insert({
    required String provider,
    required String colorType,
    required String colorId,
    required String background,
    this.foreground = const Value.absent(),
    this.rawJson = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : provider = Value(provider),
       colorType = Value(colorType),
       colorId = Value(colorId),
       background = Value(background);
  static Insertable<CalendarColor> custom({
    Expression<String>? provider,
    Expression<String>? colorType,
    Expression<String>? colorId,
    Expression<String>? background,
    Expression<String>? foreground,
    Expression<String>? rawJson,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (provider != null) 'provider': provider,
      if (colorType != null) 'color_type': colorType,
      if (colorId != null) 'color_id': colorId,
      if (background != null) 'background': background,
      if (foreground != null) 'foreground': foreground,
      if (rawJson != null) 'raw_json': rawJson,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CalendarColorsCompanion copyWith({
    Value<String>? provider,
    Value<String>? colorType,
    Value<String>? colorId,
    Value<String>? background,
    Value<String?>? foreground,
    Value<String?>? rawJson,
    Value<int>? rowid,
  }) {
    return CalendarColorsCompanion(
      provider: provider ?? this.provider,
      colorType: colorType ?? this.colorType,
      colorId: colorId ?? this.colorId,
      background: background ?? this.background,
      foreground: foreground ?? this.foreground,
      rawJson: rawJson ?? this.rawJson,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (provider.present) {
      map['provider'] = Variable<String>(provider.value);
    }
    if (colorType.present) {
      map['color_type'] = Variable<String>(colorType.value);
    }
    if (colorId.present) {
      map['color_id'] = Variable<String>(colorId.value);
    }
    if (background.present) {
      map['background'] = Variable<String>(background.value);
    }
    if (foreground.present) {
      map['foreground'] = Variable<String>(foreground.value);
    }
    if (rawJson.present) {
      map['raw_json'] = Variable<String>(rawJson.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CalendarColorsCompanion(')
          ..write('provider: $provider, ')
          ..write('colorType: $colorType, ')
          ..write('colorId: $colorId, ')
          ..write('background: $background, ')
          ..write('foreground: $foreground, ')
          ..write('rawJson: $rawJson, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ScheduleItemOverridesTable extends ScheduleItemOverrides
    with TableInfo<$ScheduleItemOverridesTable, ScheduleItemOverride> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ScheduleItemOverridesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _accountIdMeta = const VerificationMeta(
    'accountId',
  );
  @override
  late final GeneratedColumn<String> accountId = GeneratedColumn<String>(
    'account_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES accounts (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _sourceTypeMeta = const VerificationMeta(
    'sourceType',
  );
  @override
  late final GeneratedColumn<String> sourceType = GeneratedColumn<String>(
    'source_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceIdMeta = const VerificationMeta(
    'sourceId',
  );
  @override
  late final GeneratedColumn<String> sourceId = GeneratedColumn<String>(
    'source_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _overrideJsonMeta = const VerificationMeta(
    'overrideJson',
  );
  @override
  late final GeneratedColumn<String> overrideJson = GeneratedColumn<String>(
    'override_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtLocalMeta = const VerificationMeta(
    'createdAtLocal',
  );
  @override
  late final GeneratedColumn<int> createdAtLocal = GeneratedColumn<int>(
    'created_at_local',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtLocalMeta = const VerificationMeta(
    'updatedAtLocal',
  );
  @override
  late final GeneratedColumn<int> updatedAtLocal = GeneratedColumn<int>(
    'updated_at_local',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    accountId,
    sourceType,
    sourceId,
    overrideJson,
    createdAtLocal,
    updatedAtLocal,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'schedule_item_overrides';
  @override
  VerificationContext validateIntegrity(
    Insertable<ScheduleItemOverride> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('account_id')) {
      context.handle(
        _accountIdMeta,
        accountId.isAcceptableOrUnknown(data['account_id']!, _accountIdMeta),
      );
    } else if (isInserting) {
      context.missing(_accountIdMeta);
    }
    if (data.containsKey('source_type')) {
      context.handle(
        _sourceTypeMeta,
        sourceType.isAcceptableOrUnknown(data['source_type']!, _sourceTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceTypeMeta);
    }
    if (data.containsKey('source_id')) {
      context.handle(
        _sourceIdMeta,
        sourceId.isAcceptableOrUnknown(data['source_id']!, _sourceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceIdMeta);
    }
    if (data.containsKey('override_json')) {
      context.handle(
        _overrideJsonMeta,
        overrideJson.isAcceptableOrUnknown(
          data['override_json']!,
          _overrideJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_overrideJsonMeta);
    }
    if (data.containsKey('created_at_local')) {
      context.handle(
        _createdAtLocalMeta,
        createdAtLocal.isAcceptableOrUnknown(
          data['created_at_local']!,
          _createdAtLocalMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_createdAtLocalMeta);
    }
    if (data.containsKey('updated_at_local')) {
      context.handle(
        _updatedAtLocalMeta,
        updatedAtLocal.isAcceptableOrUnknown(
          data['updated_at_local']!,
          _updatedAtLocalMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_updatedAtLocalMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ScheduleItemOverride map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ScheduleItemOverride(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      accountId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}account_id'],
      )!,
      sourceType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_type'],
      )!,
      sourceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_id'],
      )!,
      overrideJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}override_json'],
      )!,
      createdAtLocal: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at_local'],
      )!,
      updatedAtLocal: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at_local'],
      )!,
    );
  }

  @override
  $ScheduleItemOverridesTable createAlias(String alias) {
    return $ScheduleItemOverridesTable(attachedDatabase, alias);
  }
}

class ScheduleItemOverride extends DataClass
    implements Insertable<ScheduleItemOverride> {
  final String id;
  final String accountId;
  final String sourceType;
  final String sourceId;
  final String overrideJson;
  final int createdAtLocal;
  final int updatedAtLocal;
  const ScheduleItemOverride({
    required this.id,
    required this.accountId,
    required this.sourceType,
    required this.sourceId,
    required this.overrideJson,
    required this.createdAtLocal,
    required this.updatedAtLocal,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['account_id'] = Variable<String>(accountId);
    map['source_type'] = Variable<String>(sourceType);
    map['source_id'] = Variable<String>(sourceId);
    map['override_json'] = Variable<String>(overrideJson);
    map['created_at_local'] = Variable<int>(createdAtLocal);
    map['updated_at_local'] = Variable<int>(updatedAtLocal);
    return map;
  }

  ScheduleItemOverridesCompanion toCompanion(bool nullToAbsent) {
    return ScheduleItemOverridesCompanion(
      id: Value(id),
      accountId: Value(accountId),
      sourceType: Value(sourceType),
      sourceId: Value(sourceId),
      overrideJson: Value(overrideJson),
      createdAtLocal: Value(createdAtLocal),
      updatedAtLocal: Value(updatedAtLocal),
    );
  }

  factory ScheduleItemOverride.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ScheduleItemOverride(
      id: serializer.fromJson<String>(json['id']),
      accountId: serializer.fromJson<String>(json['accountId']),
      sourceType: serializer.fromJson<String>(json['sourceType']),
      sourceId: serializer.fromJson<String>(json['sourceId']),
      overrideJson: serializer.fromJson<String>(json['overrideJson']),
      createdAtLocal: serializer.fromJson<int>(json['createdAtLocal']),
      updatedAtLocal: serializer.fromJson<int>(json['updatedAtLocal']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'accountId': serializer.toJson<String>(accountId),
      'sourceType': serializer.toJson<String>(sourceType),
      'sourceId': serializer.toJson<String>(sourceId),
      'overrideJson': serializer.toJson<String>(overrideJson),
      'createdAtLocal': serializer.toJson<int>(createdAtLocal),
      'updatedAtLocal': serializer.toJson<int>(updatedAtLocal),
    };
  }

  ScheduleItemOverride copyWith({
    String? id,
    String? accountId,
    String? sourceType,
    String? sourceId,
    String? overrideJson,
    int? createdAtLocal,
    int? updatedAtLocal,
  }) => ScheduleItemOverride(
    id: id ?? this.id,
    accountId: accountId ?? this.accountId,
    sourceType: sourceType ?? this.sourceType,
    sourceId: sourceId ?? this.sourceId,
    overrideJson: overrideJson ?? this.overrideJson,
    createdAtLocal: createdAtLocal ?? this.createdAtLocal,
    updatedAtLocal: updatedAtLocal ?? this.updatedAtLocal,
  );
  ScheduleItemOverride copyWithCompanion(ScheduleItemOverridesCompanion data) {
    return ScheduleItemOverride(
      id: data.id.present ? data.id.value : this.id,
      accountId: data.accountId.present ? data.accountId.value : this.accountId,
      sourceType: data.sourceType.present
          ? data.sourceType.value
          : this.sourceType,
      sourceId: data.sourceId.present ? data.sourceId.value : this.sourceId,
      overrideJson: data.overrideJson.present
          ? data.overrideJson.value
          : this.overrideJson,
      createdAtLocal: data.createdAtLocal.present
          ? data.createdAtLocal.value
          : this.createdAtLocal,
      updatedAtLocal: data.updatedAtLocal.present
          ? data.updatedAtLocal.value
          : this.updatedAtLocal,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ScheduleItemOverride(')
          ..write('id: $id, ')
          ..write('accountId: $accountId, ')
          ..write('sourceType: $sourceType, ')
          ..write('sourceId: $sourceId, ')
          ..write('overrideJson: $overrideJson, ')
          ..write('createdAtLocal: $createdAtLocal, ')
          ..write('updatedAtLocal: $updatedAtLocal')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    accountId,
    sourceType,
    sourceId,
    overrideJson,
    createdAtLocal,
    updatedAtLocal,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ScheduleItemOverride &&
          other.id == this.id &&
          other.accountId == this.accountId &&
          other.sourceType == this.sourceType &&
          other.sourceId == this.sourceId &&
          other.overrideJson == this.overrideJson &&
          other.createdAtLocal == this.createdAtLocal &&
          other.updatedAtLocal == this.updatedAtLocal);
}

class ScheduleItemOverridesCompanion
    extends UpdateCompanion<ScheduleItemOverride> {
  final Value<String> id;
  final Value<String> accountId;
  final Value<String> sourceType;
  final Value<String> sourceId;
  final Value<String> overrideJson;
  final Value<int> createdAtLocal;
  final Value<int> updatedAtLocal;
  final Value<int> rowid;
  const ScheduleItemOverridesCompanion({
    this.id = const Value.absent(),
    this.accountId = const Value.absent(),
    this.sourceType = const Value.absent(),
    this.sourceId = const Value.absent(),
    this.overrideJson = const Value.absent(),
    this.createdAtLocal = const Value.absent(),
    this.updatedAtLocal = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ScheduleItemOverridesCompanion.insert({
    required String id,
    required String accountId,
    required String sourceType,
    required String sourceId,
    required String overrideJson,
    required int createdAtLocal,
    required int updatedAtLocal,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       accountId = Value(accountId),
       sourceType = Value(sourceType),
       sourceId = Value(sourceId),
       overrideJson = Value(overrideJson),
       createdAtLocal = Value(createdAtLocal),
       updatedAtLocal = Value(updatedAtLocal);
  static Insertable<ScheduleItemOverride> custom({
    Expression<String>? id,
    Expression<String>? accountId,
    Expression<String>? sourceType,
    Expression<String>? sourceId,
    Expression<String>? overrideJson,
    Expression<int>? createdAtLocal,
    Expression<int>? updatedAtLocal,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (accountId != null) 'account_id': accountId,
      if (sourceType != null) 'source_type': sourceType,
      if (sourceId != null) 'source_id': sourceId,
      if (overrideJson != null) 'override_json': overrideJson,
      if (createdAtLocal != null) 'created_at_local': createdAtLocal,
      if (updatedAtLocal != null) 'updated_at_local': updatedAtLocal,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ScheduleItemOverridesCompanion copyWith({
    Value<String>? id,
    Value<String>? accountId,
    Value<String>? sourceType,
    Value<String>? sourceId,
    Value<String>? overrideJson,
    Value<int>? createdAtLocal,
    Value<int>? updatedAtLocal,
    Value<int>? rowid,
  }) {
    return ScheduleItemOverridesCompanion(
      id: id ?? this.id,
      accountId: accountId ?? this.accountId,
      sourceType: sourceType ?? this.sourceType,
      sourceId: sourceId ?? this.sourceId,
      overrideJson: overrideJson ?? this.overrideJson,
      createdAtLocal: createdAtLocal ?? this.createdAtLocal,
      updatedAtLocal: updatedAtLocal ?? this.updatedAtLocal,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (accountId.present) {
      map['account_id'] = Variable<String>(accountId.value);
    }
    if (sourceType.present) {
      map['source_type'] = Variable<String>(sourceType.value);
    }
    if (sourceId.present) {
      map['source_id'] = Variable<String>(sourceId.value);
    }
    if (overrideJson.present) {
      map['override_json'] = Variable<String>(overrideJson.value);
    }
    if (createdAtLocal.present) {
      map['created_at_local'] = Variable<int>(createdAtLocal.value);
    }
    if (updatedAtLocal.present) {
      map['updated_at_local'] = Variable<int>(updatedAtLocal.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ScheduleItemOverridesCompanion(')
          ..write('id: $id, ')
          ..write('accountId: $accountId, ')
          ..write('sourceType: $sourceType, ')
          ..write('sourceId: $sourceId, ')
          ..write('overrideJson: $overrideJson, ')
          ..write('createdAtLocal: $createdAtLocal, ')
          ..write('updatedAtLocal: $updatedAtLocal, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $NotificationScheduleTable extends NotificationSchedule
    with TableInfo<$NotificationScheduleTable, NotificationScheduleData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $NotificationScheduleTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _accountIdMeta = const VerificationMeta(
    'accountId',
  );
  @override
  late final GeneratedColumn<String> accountId = GeneratedColumn<String>(
    'account_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES accounts (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _sourceTypeMeta = const VerificationMeta(
    'sourceType',
  );
  @override
  late final GeneratedColumn<String> sourceType = GeneratedColumn<String>(
    'source_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceIdMeta = const VerificationMeta(
    'sourceId',
  );
  @override
  late final GeneratedColumn<String> sourceId = GeneratedColumn<String>(
    'source_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _scheduledAtUtcMeta = const VerificationMeta(
    'scheduledAtUtc',
  );
  @override
  late final GeneratedColumn<int> scheduledAtUtc = GeneratedColumn<int>(
    'scheduled_at_utc',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bodyMeta = const VerificationMeta('body');
  @override
  late final GeneratedColumn<String> body = GeneratedColumn<String>(
    'body',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sentAtUtcMeta = const VerificationMeta(
    'sentAtUtc',
  );
  @override
  late final GeneratedColumn<int> sentAtUtc = GeneratedColumn<int>(
    'sent_at_utc',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _dismissedAtUtcMeta = const VerificationMeta(
    'dismissedAtUtc',
  );
  @override
  late final GeneratedColumn<int> dismissedAtUtc = GeneratedColumn<int>(
    'dismissed_at_utc',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _snoozedUntilUtcMeta = const VerificationMeta(
    'snoozedUntilUtc',
  );
  @override
  late final GeneratedColumn<int> snoozedUntilUtc = GeneratedColumn<int>(
    'snoozed_until_utc',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtLocalMeta = const VerificationMeta(
    'createdAtLocal',
  );
  @override
  late final GeneratedColumn<int> createdAtLocal = GeneratedColumn<int>(
    'created_at_local',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtLocalMeta = const VerificationMeta(
    'updatedAtLocal',
  );
  @override
  late final GeneratedColumn<int> updatedAtLocal = GeneratedColumn<int>(
    'updated_at_local',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    accountId,
    sourceType,
    sourceId,
    scheduledAtUtc,
    title,
    body,
    sentAtUtc,
    dismissedAtUtc,
    snoozedUntilUtc,
    createdAtLocal,
    updatedAtLocal,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'notification_schedule';
  @override
  VerificationContext validateIntegrity(
    Insertable<NotificationScheduleData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('account_id')) {
      context.handle(
        _accountIdMeta,
        accountId.isAcceptableOrUnknown(data['account_id']!, _accountIdMeta),
      );
    } else if (isInserting) {
      context.missing(_accountIdMeta);
    }
    if (data.containsKey('source_type')) {
      context.handle(
        _sourceTypeMeta,
        sourceType.isAcceptableOrUnknown(data['source_type']!, _sourceTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceTypeMeta);
    }
    if (data.containsKey('source_id')) {
      context.handle(
        _sourceIdMeta,
        sourceId.isAcceptableOrUnknown(data['source_id']!, _sourceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceIdMeta);
    }
    if (data.containsKey('scheduled_at_utc')) {
      context.handle(
        _scheduledAtUtcMeta,
        scheduledAtUtc.isAcceptableOrUnknown(
          data['scheduled_at_utc']!,
          _scheduledAtUtcMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_scheduledAtUtcMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('body')) {
      context.handle(
        _bodyMeta,
        body.isAcceptableOrUnknown(data['body']!, _bodyMeta),
      );
    }
    if (data.containsKey('sent_at_utc')) {
      context.handle(
        _sentAtUtcMeta,
        sentAtUtc.isAcceptableOrUnknown(data['sent_at_utc']!, _sentAtUtcMeta),
      );
    }
    if (data.containsKey('dismissed_at_utc')) {
      context.handle(
        _dismissedAtUtcMeta,
        dismissedAtUtc.isAcceptableOrUnknown(
          data['dismissed_at_utc']!,
          _dismissedAtUtcMeta,
        ),
      );
    }
    if (data.containsKey('snoozed_until_utc')) {
      context.handle(
        _snoozedUntilUtcMeta,
        snoozedUntilUtc.isAcceptableOrUnknown(
          data['snoozed_until_utc']!,
          _snoozedUntilUtcMeta,
        ),
      );
    }
    if (data.containsKey('created_at_local')) {
      context.handle(
        _createdAtLocalMeta,
        createdAtLocal.isAcceptableOrUnknown(
          data['created_at_local']!,
          _createdAtLocalMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_createdAtLocalMeta);
    }
    if (data.containsKey('updated_at_local')) {
      context.handle(
        _updatedAtLocalMeta,
        updatedAtLocal.isAcceptableOrUnknown(
          data['updated_at_local']!,
          _updatedAtLocalMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_updatedAtLocalMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  NotificationScheduleData map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return NotificationScheduleData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      accountId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}account_id'],
      )!,
      sourceType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_type'],
      )!,
      sourceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_id'],
      )!,
      scheduledAtUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}scheduled_at_utc'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      body: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}body'],
      ),
      sentAtUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sent_at_utc'],
      ),
      dismissedAtUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}dismissed_at_utc'],
      ),
      snoozedUntilUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}snoozed_until_utc'],
      ),
      createdAtLocal: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at_local'],
      )!,
      updatedAtLocal: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at_local'],
      )!,
    );
  }

  @override
  $NotificationScheduleTable createAlias(String alias) {
    return $NotificationScheduleTable(attachedDatabase, alias);
  }
}

class NotificationScheduleData extends DataClass
    implements Insertable<NotificationScheduleData> {
  final String id;
  final String accountId;
  final String sourceType;
  final String sourceId;
  final int scheduledAtUtc;
  final String title;
  final String? body;
  final int? sentAtUtc;
  final int? dismissedAtUtc;
  final int? snoozedUntilUtc;
  final int createdAtLocal;
  final int updatedAtLocal;
  const NotificationScheduleData({
    required this.id,
    required this.accountId,
    required this.sourceType,
    required this.sourceId,
    required this.scheduledAtUtc,
    required this.title,
    this.body,
    this.sentAtUtc,
    this.dismissedAtUtc,
    this.snoozedUntilUtc,
    required this.createdAtLocal,
    required this.updatedAtLocal,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['account_id'] = Variable<String>(accountId);
    map['source_type'] = Variable<String>(sourceType);
    map['source_id'] = Variable<String>(sourceId);
    map['scheduled_at_utc'] = Variable<int>(scheduledAtUtc);
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || body != null) {
      map['body'] = Variable<String>(body);
    }
    if (!nullToAbsent || sentAtUtc != null) {
      map['sent_at_utc'] = Variable<int>(sentAtUtc);
    }
    if (!nullToAbsent || dismissedAtUtc != null) {
      map['dismissed_at_utc'] = Variable<int>(dismissedAtUtc);
    }
    if (!nullToAbsent || snoozedUntilUtc != null) {
      map['snoozed_until_utc'] = Variable<int>(snoozedUntilUtc);
    }
    map['created_at_local'] = Variable<int>(createdAtLocal);
    map['updated_at_local'] = Variable<int>(updatedAtLocal);
    return map;
  }

  NotificationScheduleCompanion toCompanion(bool nullToAbsent) {
    return NotificationScheduleCompanion(
      id: Value(id),
      accountId: Value(accountId),
      sourceType: Value(sourceType),
      sourceId: Value(sourceId),
      scheduledAtUtc: Value(scheduledAtUtc),
      title: Value(title),
      body: body == null && nullToAbsent ? const Value.absent() : Value(body),
      sentAtUtc: sentAtUtc == null && nullToAbsent
          ? const Value.absent()
          : Value(sentAtUtc),
      dismissedAtUtc: dismissedAtUtc == null && nullToAbsent
          ? const Value.absent()
          : Value(dismissedAtUtc),
      snoozedUntilUtc: snoozedUntilUtc == null && nullToAbsent
          ? const Value.absent()
          : Value(snoozedUntilUtc),
      createdAtLocal: Value(createdAtLocal),
      updatedAtLocal: Value(updatedAtLocal),
    );
  }

  factory NotificationScheduleData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return NotificationScheduleData(
      id: serializer.fromJson<String>(json['id']),
      accountId: serializer.fromJson<String>(json['accountId']),
      sourceType: serializer.fromJson<String>(json['sourceType']),
      sourceId: serializer.fromJson<String>(json['sourceId']),
      scheduledAtUtc: serializer.fromJson<int>(json['scheduledAtUtc']),
      title: serializer.fromJson<String>(json['title']),
      body: serializer.fromJson<String?>(json['body']),
      sentAtUtc: serializer.fromJson<int?>(json['sentAtUtc']),
      dismissedAtUtc: serializer.fromJson<int?>(json['dismissedAtUtc']),
      snoozedUntilUtc: serializer.fromJson<int?>(json['snoozedUntilUtc']),
      createdAtLocal: serializer.fromJson<int>(json['createdAtLocal']),
      updatedAtLocal: serializer.fromJson<int>(json['updatedAtLocal']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'accountId': serializer.toJson<String>(accountId),
      'sourceType': serializer.toJson<String>(sourceType),
      'sourceId': serializer.toJson<String>(sourceId),
      'scheduledAtUtc': serializer.toJson<int>(scheduledAtUtc),
      'title': serializer.toJson<String>(title),
      'body': serializer.toJson<String?>(body),
      'sentAtUtc': serializer.toJson<int?>(sentAtUtc),
      'dismissedAtUtc': serializer.toJson<int?>(dismissedAtUtc),
      'snoozedUntilUtc': serializer.toJson<int?>(snoozedUntilUtc),
      'createdAtLocal': serializer.toJson<int>(createdAtLocal),
      'updatedAtLocal': serializer.toJson<int>(updatedAtLocal),
    };
  }

  NotificationScheduleData copyWith({
    String? id,
    String? accountId,
    String? sourceType,
    String? sourceId,
    int? scheduledAtUtc,
    String? title,
    Value<String?> body = const Value.absent(),
    Value<int?> sentAtUtc = const Value.absent(),
    Value<int?> dismissedAtUtc = const Value.absent(),
    Value<int?> snoozedUntilUtc = const Value.absent(),
    int? createdAtLocal,
    int? updatedAtLocal,
  }) => NotificationScheduleData(
    id: id ?? this.id,
    accountId: accountId ?? this.accountId,
    sourceType: sourceType ?? this.sourceType,
    sourceId: sourceId ?? this.sourceId,
    scheduledAtUtc: scheduledAtUtc ?? this.scheduledAtUtc,
    title: title ?? this.title,
    body: body.present ? body.value : this.body,
    sentAtUtc: sentAtUtc.present ? sentAtUtc.value : this.sentAtUtc,
    dismissedAtUtc: dismissedAtUtc.present
        ? dismissedAtUtc.value
        : this.dismissedAtUtc,
    snoozedUntilUtc: snoozedUntilUtc.present
        ? snoozedUntilUtc.value
        : this.snoozedUntilUtc,
    createdAtLocal: createdAtLocal ?? this.createdAtLocal,
    updatedAtLocal: updatedAtLocal ?? this.updatedAtLocal,
  );
  NotificationScheduleData copyWithCompanion(
    NotificationScheduleCompanion data,
  ) {
    return NotificationScheduleData(
      id: data.id.present ? data.id.value : this.id,
      accountId: data.accountId.present ? data.accountId.value : this.accountId,
      sourceType: data.sourceType.present
          ? data.sourceType.value
          : this.sourceType,
      sourceId: data.sourceId.present ? data.sourceId.value : this.sourceId,
      scheduledAtUtc: data.scheduledAtUtc.present
          ? data.scheduledAtUtc.value
          : this.scheduledAtUtc,
      title: data.title.present ? data.title.value : this.title,
      body: data.body.present ? data.body.value : this.body,
      sentAtUtc: data.sentAtUtc.present ? data.sentAtUtc.value : this.sentAtUtc,
      dismissedAtUtc: data.dismissedAtUtc.present
          ? data.dismissedAtUtc.value
          : this.dismissedAtUtc,
      snoozedUntilUtc: data.snoozedUntilUtc.present
          ? data.snoozedUntilUtc.value
          : this.snoozedUntilUtc,
      createdAtLocal: data.createdAtLocal.present
          ? data.createdAtLocal.value
          : this.createdAtLocal,
      updatedAtLocal: data.updatedAtLocal.present
          ? data.updatedAtLocal.value
          : this.updatedAtLocal,
    );
  }

  @override
  String toString() {
    return (StringBuffer('NotificationScheduleData(')
          ..write('id: $id, ')
          ..write('accountId: $accountId, ')
          ..write('sourceType: $sourceType, ')
          ..write('sourceId: $sourceId, ')
          ..write('scheduledAtUtc: $scheduledAtUtc, ')
          ..write('title: $title, ')
          ..write('body: $body, ')
          ..write('sentAtUtc: $sentAtUtc, ')
          ..write('dismissedAtUtc: $dismissedAtUtc, ')
          ..write('snoozedUntilUtc: $snoozedUntilUtc, ')
          ..write('createdAtLocal: $createdAtLocal, ')
          ..write('updatedAtLocal: $updatedAtLocal')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    accountId,
    sourceType,
    sourceId,
    scheduledAtUtc,
    title,
    body,
    sentAtUtc,
    dismissedAtUtc,
    snoozedUntilUtc,
    createdAtLocal,
    updatedAtLocal,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is NotificationScheduleData &&
          other.id == this.id &&
          other.accountId == this.accountId &&
          other.sourceType == this.sourceType &&
          other.sourceId == this.sourceId &&
          other.scheduledAtUtc == this.scheduledAtUtc &&
          other.title == this.title &&
          other.body == this.body &&
          other.sentAtUtc == this.sentAtUtc &&
          other.dismissedAtUtc == this.dismissedAtUtc &&
          other.snoozedUntilUtc == this.snoozedUntilUtc &&
          other.createdAtLocal == this.createdAtLocal &&
          other.updatedAtLocal == this.updatedAtLocal);
}

class NotificationScheduleCompanion
    extends UpdateCompanion<NotificationScheduleData> {
  final Value<String> id;
  final Value<String> accountId;
  final Value<String> sourceType;
  final Value<String> sourceId;
  final Value<int> scheduledAtUtc;
  final Value<String> title;
  final Value<String?> body;
  final Value<int?> sentAtUtc;
  final Value<int?> dismissedAtUtc;
  final Value<int?> snoozedUntilUtc;
  final Value<int> createdAtLocal;
  final Value<int> updatedAtLocal;
  final Value<int> rowid;
  const NotificationScheduleCompanion({
    this.id = const Value.absent(),
    this.accountId = const Value.absent(),
    this.sourceType = const Value.absent(),
    this.sourceId = const Value.absent(),
    this.scheduledAtUtc = const Value.absent(),
    this.title = const Value.absent(),
    this.body = const Value.absent(),
    this.sentAtUtc = const Value.absent(),
    this.dismissedAtUtc = const Value.absent(),
    this.snoozedUntilUtc = const Value.absent(),
    this.createdAtLocal = const Value.absent(),
    this.updatedAtLocal = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  NotificationScheduleCompanion.insert({
    required String id,
    required String accountId,
    required String sourceType,
    required String sourceId,
    required int scheduledAtUtc,
    required String title,
    this.body = const Value.absent(),
    this.sentAtUtc = const Value.absent(),
    this.dismissedAtUtc = const Value.absent(),
    this.snoozedUntilUtc = const Value.absent(),
    required int createdAtLocal,
    required int updatedAtLocal,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       accountId = Value(accountId),
       sourceType = Value(sourceType),
       sourceId = Value(sourceId),
       scheduledAtUtc = Value(scheduledAtUtc),
       title = Value(title),
       createdAtLocal = Value(createdAtLocal),
       updatedAtLocal = Value(updatedAtLocal);
  static Insertable<NotificationScheduleData> custom({
    Expression<String>? id,
    Expression<String>? accountId,
    Expression<String>? sourceType,
    Expression<String>? sourceId,
    Expression<int>? scheduledAtUtc,
    Expression<String>? title,
    Expression<String>? body,
    Expression<int>? sentAtUtc,
    Expression<int>? dismissedAtUtc,
    Expression<int>? snoozedUntilUtc,
    Expression<int>? createdAtLocal,
    Expression<int>? updatedAtLocal,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (accountId != null) 'account_id': accountId,
      if (sourceType != null) 'source_type': sourceType,
      if (sourceId != null) 'source_id': sourceId,
      if (scheduledAtUtc != null) 'scheduled_at_utc': scheduledAtUtc,
      if (title != null) 'title': title,
      if (body != null) 'body': body,
      if (sentAtUtc != null) 'sent_at_utc': sentAtUtc,
      if (dismissedAtUtc != null) 'dismissed_at_utc': dismissedAtUtc,
      if (snoozedUntilUtc != null) 'snoozed_until_utc': snoozedUntilUtc,
      if (createdAtLocal != null) 'created_at_local': createdAtLocal,
      if (updatedAtLocal != null) 'updated_at_local': updatedAtLocal,
      if (rowid != null) 'rowid': rowid,
    });
  }

  NotificationScheduleCompanion copyWith({
    Value<String>? id,
    Value<String>? accountId,
    Value<String>? sourceType,
    Value<String>? sourceId,
    Value<int>? scheduledAtUtc,
    Value<String>? title,
    Value<String?>? body,
    Value<int?>? sentAtUtc,
    Value<int?>? dismissedAtUtc,
    Value<int?>? snoozedUntilUtc,
    Value<int>? createdAtLocal,
    Value<int>? updatedAtLocal,
    Value<int>? rowid,
  }) {
    return NotificationScheduleCompanion(
      id: id ?? this.id,
      accountId: accountId ?? this.accountId,
      sourceType: sourceType ?? this.sourceType,
      sourceId: sourceId ?? this.sourceId,
      scheduledAtUtc: scheduledAtUtc ?? this.scheduledAtUtc,
      title: title ?? this.title,
      body: body ?? this.body,
      sentAtUtc: sentAtUtc ?? this.sentAtUtc,
      dismissedAtUtc: dismissedAtUtc ?? this.dismissedAtUtc,
      snoozedUntilUtc: snoozedUntilUtc ?? this.snoozedUntilUtc,
      createdAtLocal: createdAtLocal ?? this.createdAtLocal,
      updatedAtLocal: updatedAtLocal ?? this.updatedAtLocal,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (accountId.present) {
      map['account_id'] = Variable<String>(accountId.value);
    }
    if (sourceType.present) {
      map['source_type'] = Variable<String>(sourceType.value);
    }
    if (sourceId.present) {
      map['source_id'] = Variable<String>(sourceId.value);
    }
    if (scheduledAtUtc.present) {
      map['scheduled_at_utc'] = Variable<int>(scheduledAtUtc.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (body.present) {
      map['body'] = Variable<String>(body.value);
    }
    if (sentAtUtc.present) {
      map['sent_at_utc'] = Variable<int>(sentAtUtc.value);
    }
    if (dismissedAtUtc.present) {
      map['dismissed_at_utc'] = Variable<int>(dismissedAtUtc.value);
    }
    if (snoozedUntilUtc.present) {
      map['snoozed_until_utc'] = Variable<int>(snoozedUntilUtc.value);
    }
    if (createdAtLocal.present) {
      map['created_at_local'] = Variable<int>(createdAtLocal.value);
    }
    if (updatedAtLocal.present) {
      map['updated_at_local'] = Variable<int>(updatedAtLocal.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('NotificationScheduleCompanion(')
          ..write('id: $id, ')
          ..write('accountId: $accountId, ')
          ..write('sourceType: $sourceType, ')
          ..write('sourceId: $sourceId, ')
          ..write('scheduledAtUtc: $scheduledAtUtc, ')
          ..write('title: $title, ')
          ..write('body: $body, ')
          ..write('sentAtUtc: $sentAtUtc, ')
          ..write('dismissedAtUtc: $dismissedAtUtc, ')
          ..write('snoozedUntilUtc: $snoozedUntilUtc, ')
          ..write('createdAtLocal: $createdAtLocal, ')
          ..write('updatedAtLocal: $updatedAtLocal, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $AccountsTable accounts = $AccountsTable(this);
  late final $TaskListsTable taskLists = $TaskListsTable(this);
  late final $TasksTable tasks = $TasksTable(this);
  late final $PendingOpsTable pendingOps = $PendingOpsTable(this);
  late final $SyncRunsTable syncRuns = $SyncRunsTable(this);
  late final $CalendarSourcesTable calendarSources = $CalendarSourcesTable(
    this,
  );
  late final $CalendarEventsTable calendarEvents = $CalendarEventsTable(this);
  late final $CalendarEventAttendeesTable calendarEventAttendees =
      $CalendarEventAttendeesTable(this);
  late final $CalendarEventRemindersTable calendarEventReminders =
      $CalendarEventRemindersTable(this);
  late final $CalendarSyncStatesTable calendarSyncStates =
      $CalendarSyncStatesTable(this);
  late final $CalendarColorsTable calendarColors = $CalendarColorsTable(this);
  late final $ScheduleItemOverridesTable scheduleItemOverrides =
      $ScheduleItemOverridesTable(this);
  late final $NotificationScheduleTable notificationSchedule =
      $NotificationScheduleTable(this);
  late final TaskListsDao taskListsDao = TaskListsDao(this as AppDatabase);
  late final TasksDao tasksDao = TasksDao(this as AppDatabase);
  late final PendingOpsDao pendingOpsDao = PendingOpsDao(this as AppDatabase);
  late final SyncRunsDao syncRunsDao = SyncRunsDao(this as AppDatabase);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    accounts,
    taskLists,
    tasks,
    pendingOps,
    syncRuns,
    calendarSources,
    calendarEvents,
    calendarEventAttendees,
    calendarEventReminders,
    calendarSyncStates,
    calendarColors,
    scheduleItemOverrides,
    notificationSchedule,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'accounts',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('task_lists', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'accounts',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('tasks', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'accounts',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('pending_ops', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'accounts',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('sync_runs', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'accounts',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('calendar_sources', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'accounts',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('calendar_events', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'calendar_sources',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('calendar_events', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'calendar_events',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [
        TableUpdate('calendar_event_attendees', kind: UpdateKind.delete),
      ],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'calendar_events',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [
        TableUpdate('calendar_event_reminders', kind: UpdateKind.delete),
      ],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'accounts',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('calendar_sync_states', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'calendar_sources',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('calendar_sync_states', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'accounts',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('schedule_item_overrides', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'accounts',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('notification_schedule', kind: UpdateKind.delete)],
    ),
  ]);
}

typedef $$AccountsTableCreateCompanionBuilder =
    AccountsCompanion Function({
      required String id,
      Value<String> provider,
      Value<String?> providerAccountId,
      Value<String?> displayName,
      Value<String?> email,
      Value<String?> tenantId,
      Value<String?> accountAvatarUrl,
      Value<String?> providerMetadataJson,
      Value<String> authState,
      Value<bool> calendarsEnabled,
      Value<bool> tasksEnabled,
      Value<String> grantedScopes,
      required String createdAtUtc,
      required String updatedAtUtc,
      Value<String?> lastSuccessfulSyncAtUtc,
      Value<String?> lastFullSyncAtUtc,
      Value<int> rowid,
    });
typedef $$AccountsTableUpdateCompanionBuilder =
    AccountsCompanion Function({
      Value<String> id,
      Value<String> provider,
      Value<String?> providerAccountId,
      Value<String?> displayName,
      Value<String?> email,
      Value<String?> tenantId,
      Value<String?> accountAvatarUrl,
      Value<String?> providerMetadataJson,
      Value<String> authState,
      Value<bool> calendarsEnabled,
      Value<bool> tasksEnabled,
      Value<String> grantedScopes,
      Value<String> createdAtUtc,
      Value<String> updatedAtUtc,
      Value<String?> lastSuccessfulSyncAtUtc,
      Value<String?> lastFullSyncAtUtc,
      Value<int> rowid,
    });

final class $$AccountsTableReferences
    extends BaseReferences<_$AppDatabase, $AccountsTable, Account> {
  $$AccountsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$TaskListsTable, List<TaskList>>
  _taskListsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.taskLists,
    aliasName: $_aliasNameGenerator(db.accounts.id, db.taskLists.accountId),
  );

  $$TaskListsTableProcessedTableManager get taskListsRefs {
    final manager = $$TaskListsTableTableManager(
      $_db,
      $_db.taskLists,
    ).filter((f) => f.accountId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_taskListsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$TasksTable, List<Task>> _tasksRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.tasks,
    aliasName: $_aliasNameGenerator(db.accounts.id, db.tasks.accountId),
  );

  $$TasksTableProcessedTableManager get tasksRefs {
    final manager = $$TasksTableTableManager(
      $_db,
      $_db.tasks,
    ).filter((f) => f.accountId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_tasksRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$PendingOpsTable, List<PendingOp>>
  _pendingOpsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.pendingOps,
    aliasName: $_aliasNameGenerator(db.accounts.id, db.pendingOps.accountId),
  );

  $$PendingOpsTableProcessedTableManager get pendingOpsRefs {
    final manager = $$PendingOpsTableTableManager(
      $_db,
      $_db.pendingOps,
    ).filter((f) => f.accountId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_pendingOpsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$SyncRunsTable, List<SyncRun>> _syncRunsRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.syncRuns,
    aliasName: $_aliasNameGenerator(db.accounts.id, db.syncRuns.accountId),
  );

  $$SyncRunsTableProcessedTableManager get syncRunsRefs {
    final manager = $$SyncRunsTableTableManager(
      $_db,
      $_db.syncRuns,
    ).filter((f) => f.accountId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_syncRunsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$CalendarSourcesTable, List<CalendarSource>>
  _calendarSourcesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.calendarSources,
    aliasName: $_aliasNameGenerator(
      db.accounts.id,
      db.calendarSources.accountId,
    ),
  );

  $$CalendarSourcesTableProcessedTableManager get calendarSourcesRefs {
    final manager = $$CalendarSourcesTableTableManager(
      $_db,
      $_db.calendarSources,
    ).filter((f) => f.accountId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _calendarSourcesRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$CalendarEventsTable, List<CalendarEvent>>
  _calendarEventsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.calendarEvents,
    aliasName: $_aliasNameGenerator(
      db.accounts.id,
      db.calendarEvents.accountId,
    ),
  );

  $$CalendarEventsTableProcessedTableManager get calendarEventsRefs {
    final manager = $$CalendarEventsTableTableManager(
      $_db,
      $_db.calendarEvents,
    ).filter((f) => f.accountId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_calendarEventsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$CalendarSyncStatesTable, List<CalendarSyncState>>
  _calendarSyncStatesRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.calendarSyncStates,
        aliasName: $_aliasNameGenerator(
          db.accounts.id,
          db.calendarSyncStates.accountId,
        ),
      );

  $$CalendarSyncStatesTableProcessedTableManager get calendarSyncStatesRefs {
    final manager = $$CalendarSyncStatesTableTableManager(
      $_db,
      $_db.calendarSyncStates,
    ).filter((f) => f.accountId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _calendarSyncStatesRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<
    $ScheduleItemOverridesTable,
    List<ScheduleItemOverride>
  >
  _scheduleItemOverridesRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.scheduleItemOverrides,
        aliasName: $_aliasNameGenerator(
          db.accounts.id,
          db.scheduleItemOverrides.accountId,
        ),
      );

  $$ScheduleItemOverridesTableProcessedTableManager
  get scheduleItemOverridesRefs {
    final manager = $$ScheduleItemOverridesTableTableManager(
      $_db,
      $_db.scheduleItemOverrides,
    ).filter((f) => f.accountId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _scheduleItemOverridesRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<
    $NotificationScheduleTable,
    List<NotificationScheduleData>
  >
  _notificationScheduleRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.notificationSchedule,
        aliasName: $_aliasNameGenerator(
          db.accounts.id,
          db.notificationSchedule.accountId,
        ),
      );

  $$NotificationScheduleTableProcessedTableManager
  get notificationScheduleRefs {
    final manager = $$NotificationScheduleTableTableManager(
      $_db,
      $_db.notificationSchedule,
    ).filter((f) => f.accountId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _notificationScheduleRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$AccountsTableFilterComposer
    extends Composer<_$AppDatabase, $AccountsTable> {
  $$AccountsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get provider => $composableBuilder(
    column: $table.provider,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get providerAccountId => $composableBuilder(
    column: $table.providerAccountId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get email => $composableBuilder(
    column: $table.email,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tenantId => $composableBuilder(
    column: $table.tenantId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get accountAvatarUrl => $composableBuilder(
    column: $table.accountAvatarUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get providerMetadataJson => $composableBuilder(
    column: $table.providerMetadataJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get authState => $composableBuilder(
    column: $table.authState,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get calendarsEnabled => $composableBuilder(
    column: $table.calendarsEnabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get tasksEnabled => $composableBuilder(
    column: $table.tasksEnabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get grantedScopes => $composableBuilder(
    column: $table.grantedScopes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdAtUtc => $composableBuilder(
    column: $table.createdAtUtc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get updatedAtUtc => $composableBuilder(
    column: $table.updatedAtUtc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastSuccessfulSyncAtUtc => $composableBuilder(
    column: $table.lastSuccessfulSyncAtUtc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastFullSyncAtUtc => $composableBuilder(
    column: $table.lastFullSyncAtUtc,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> taskListsRefs(
    Expression<bool> Function($$TaskListsTableFilterComposer f) f,
  ) {
    final $$TaskListsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.taskLists,
      getReferencedColumn: (t) => t.accountId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TaskListsTableFilterComposer(
            $db: $db,
            $table: $db.taskLists,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> tasksRefs(
    Expression<bool> Function($$TasksTableFilterComposer f) f,
  ) {
    final $$TasksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.tasks,
      getReferencedColumn: (t) => t.accountId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TasksTableFilterComposer(
            $db: $db,
            $table: $db.tasks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> pendingOpsRefs(
    Expression<bool> Function($$PendingOpsTableFilterComposer f) f,
  ) {
    final $$PendingOpsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.pendingOps,
      getReferencedColumn: (t) => t.accountId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PendingOpsTableFilterComposer(
            $db: $db,
            $table: $db.pendingOps,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> syncRunsRefs(
    Expression<bool> Function($$SyncRunsTableFilterComposer f) f,
  ) {
    final $$SyncRunsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.syncRuns,
      getReferencedColumn: (t) => t.accountId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SyncRunsTableFilterComposer(
            $db: $db,
            $table: $db.syncRuns,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> calendarSourcesRefs(
    Expression<bool> Function($$CalendarSourcesTableFilterComposer f) f,
  ) {
    final $$CalendarSourcesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.calendarSources,
      getReferencedColumn: (t) => t.accountId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CalendarSourcesTableFilterComposer(
            $db: $db,
            $table: $db.calendarSources,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> calendarEventsRefs(
    Expression<bool> Function($$CalendarEventsTableFilterComposer f) f,
  ) {
    final $$CalendarEventsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.calendarEvents,
      getReferencedColumn: (t) => t.accountId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CalendarEventsTableFilterComposer(
            $db: $db,
            $table: $db.calendarEvents,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> calendarSyncStatesRefs(
    Expression<bool> Function($$CalendarSyncStatesTableFilterComposer f) f,
  ) {
    final $$CalendarSyncStatesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.calendarSyncStates,
      getReferencedColumn: (t) => t.accountId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CalendarSyncStatesTableFilterComposer(
            $db: $db,
            $table: $db.calendarSyncStates,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> scheduleItemOverridesRefs(
    Expression<bool> Function($$ScheduleItemOverridesTableFilterComposer f) f,
  ) {
    final $$ScheduleItemOverridesTableFilterComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.scheduleItemOverrides,
          getReferencedColumn: (t) => t.accountId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$ScheduleItemOverridesTableFilterComposer(
                $db: $db,
                $table: $db.scheduleItemOverrides,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<bool> notificationScheduleRefs(
    Expression<bool> Function($$NotificationScheduleTableFilterComposer f) f,
  ) {
    final $$NotificationScheduleTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.notificationSchedule,
      getReferencedColumn: (t) => t.accountId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$NotificationScheduleTableFilterComposer(
            $db: $db,
            $table: $db.notificationSchedule,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$AccountsTableOrderingComposer
    extends Composer<_$AppDatabase, $AccountsTable> {
  $$AccountsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get provider => $composableBuilder(
    column: $table.provider,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get providerAccountId => $composableBuilder(
    column: $table.providerAccountId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get email => $composableBuilder(
    column: $table.email,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tenantId => $composableBuilder(
    column: $table.tenantId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get accountAvatarUrl => $composableBuilder(
    column: $table.accountAvatarUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get providerMetadataJson => $composableBuilder(
    column: $table.providerMetadataJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get authState => $composableBuilder(
    column: $table.authState,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get calendarsEnabled => $composableBuilder(
    column: $table.calendarsEnabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get tasksEnabled => $composableBuilder(
    column: $table.tasksEnabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get grantedScopes => $composableBuilder(
    column: $table.grantedScopes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdAtUtc => $composableBuilder(
    column: $table.createdAtUtc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get updatedAtUtc => $composableBuilder(
    column: $table.updatedAtUtc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastSuccessfulSyncAtUtc => $composableBuilder(
    column: $table.lastSuccessfulSyncAtUtc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastFullSyncAtUtc => $composableBuilder(
    column: $table.lastFullSyncAtUtc,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AccountsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AccountsTable> {
  $$AccountsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get provider =>
      $composableBuilder(column: $table.provider, builder: (column) => column);

  GeneratedColumn<String> get providerAccountId => $composableBuilder(
    column: $table.providerAccountId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get email =>
      $composableBuilder(column: $table.email, builder: (column) => column);

  GeneratedColumn<String> get tenantId =>
      $composableBuilder(column: $table.tenantId, builder: (column) => column);

  GeneratedColumn<String> get accountAvatarUrl => $composableBuilder(
    column: $table.accountAvatarUrl,
    builder: (column) => column,
  );

  GeneratedColumn<String> get providerMetadataJson => $composableBuilder(
    column: $table.providerMetadataJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get authState =>
      $composableBuilder(column: $table.authState, builder: (column) => column);

  GeneratedColumn<bool> get calendarsEnabled => $composableBuilder(
    column: $table.calendarsEnabled,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get tasksEnabled => $composableBuilder(
    column: $table.tasksEnabled,
    builder: (column) => column,
  );

  GeneratedColumn<String> get grantedScopes => $composableBuilder(
    column: $table.grantedScopes,
    builder: (column) => column,
  );

  GeneratedColumn<String> get createdAtUtc => $composableBuilder(
    column: $table.createdAtUtc,
    builder: (column) => column,
  );

  GeneratedColumn<String> get updatedAtUtc => $composableBuilder(
    column: $table.updatedAtUtc,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lastSuccessfulSyncAtUtc => $composableBuilder(
    column: $table.lastSuccessfulSyncAtUtc,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lastFullSyncAtUtc => $composableBuilder(
    column: $table.lastFullSyncAtUtc,
    builder: (column) => column,
  );

  Expression<T> taskListsRefs<T extends Object>(
    Expression<T> Function($$TaskListsTableAnnotationComposer a) f,
  ) {
    final $$TaskListsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.taskLists,
      getReferencedColumn: (t) => t.accountId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TaskListsTableAnnotationComposer(
            $db: $db,
            $table: $db.taskLists,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> tasksRefs<T extends Object>(
    Expression<T> Function($$TasksTableAnnotationComposer a) f,
  ) {
    final $$TasksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.tasks,
      getReferencedColumn: (t) => t.accountId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TasksTableAnnotationComposer(
            $db: $db,
            $table: $db.tasks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> pendingOpsRefs<T extends Object>(
    Expression<T> Function($$PendingOpsTableAnnotationComposer a) f,
  ) {
    final $$PendingOpsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.pendingOps,
      getReferencedColumn: (t) => t.accountId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PendingOpsTableAnnotationComposer(
            $db: $db,
            $table: $db.pendingOps,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> syncRunsRefs<T extends Object>(
    Expression<T> Function($$SyncRunsTableAnnotationComposer a) f,
  ) {
    final $$SyncRunsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.syncRuns,
      getReferencedColumn: (t) => t.accountId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SyncRunsTableAnnotationComposer(
            $db: $db,
            $table: $db.syncRuns,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> calendarSourcesRefs<T extends Object>(
    Expression<T> Function($$CalendarSourcesTableAnnotationComposer a) f,
  ) {
    final $$CalendarSourcesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.calendarSources,
      getReferencedColumn: (t) => t.accountId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CalendarSourcesTableAnnotationComposer(
            $db: $db,
            $table: $db.calendarSources,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> calendarEventsRefs<T extends Object>(
    Expression<T> Function($$CalendarEventsTableAnnotationComposer a) f,
  ) {
    final $$CalendarEventsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.calendarEvents,
      getReferencedColumn: (t) => t.accountId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CalendarEventsTableAnnotationComposer(
            $db: $db,
            $table: $db.calendarEvents,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> calendarSyncStatesRefs<T extends Object>(
    Expression<T> Function($$CalendarSyncStatesTableAnnotationComposer a) f,
  ) {
    final $$CalendarSyncStatesTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.calendarSyncStates,
          getReferencedColumn: (t) => t.accountId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$CalendarSyncStatesTableAnnotationComposer(
                $db: $db,
                $table: $db.calendarSyncStates,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<T> scheduleItemOverridesRefs<T extends Object>(
    Expression<T> Function($$ScheduleItemOverridesTableAnnotationComposer a) f,
  ) {
    final $$ScheduleItemOverridesTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.scheduleItemOverrides,
          getReferencedColumn: (t) => t.accountId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$ScheduleItemOverridesTableAnnotationComposer(
                $db: $db,
                $table: $db.scheduleItemOverrides,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<T> notificationScheduleRefs<T extends Object>(
    Expression<T> Function($$NotificationScheduleTableAnnotationComposer a) f,
  ) {
    final $$NotificationScheduleTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.notificationSchedule,
          getReferencedColumn: (t) => t.accountId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$NotificationScheduleTableAnnotationComposer(
                $db: $db,
                $table: $db.notificationSchedule,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$AccountsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AccountsTable,
          Account,
          $$AccountsTableFilterComposer,
          $$AccountsTableOrderingComposer,
          $$AccountsTableAnnotationComposer,
          $$AccountsTableCreateCompanionBuilder,
          $$AccountsTableUpdateCompanionBuilder,
          (Account, $$AccountsTableReferences),
          Account,
          PrefetchHooks Function({
            bool taskListsRefs,
            bool tasksRefs,
            bool pendingOpsRefs,
            bool syncRunsRefs,
            bool calendarSourcesRefs,
            bool calendarEventsRefs,
            bool calendarSyncStatesRefs,
            bool scheduleItemOverridesRefs,
            bool notificationScheduleRefs,
          })
        > {
  $$AccountsTableTableManager(_$AppDatabase db, $AccountsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AccountsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AccountsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AccountsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> provider = const Value.absent(),
                Value<String?> providerAccountId = const Value.absent(),
                Value<String?> displayName = const Value.absent(),
                Value<String?> email = const Value.absent(),
                Value<String?> tenantId = const Value.absent(),
                Value<String?> accountAvatarUrl = const Value.absent(),
                Value<String?> providerMetadataJson = const Value.absent(),
                Value<String> authState = const Value.absent(),
                Value<bool> calendarsEnabled = const Value.absent(),
                Value<bool> tasksEnabled = const Value.absent(),
                Value<String> grantedScopes = const Value.absent(),
                Value<String> createdAtUtc = const Value.absent(),
                Value<String> updatedAtUtc = const Value.absent(),
                Value<String?> lastSuccessfulSyncAtUtc = const Value.absent(),
                Value<String?> lastFullSyncAtUtc = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AccountsCompanion(
                id: id,
                provider: provider,
                providerAccountId: providerAccountId,
                displayName: displayName,
                email: email,
                tenantId: tenantId,
                accountAvatarUrl: accountAvatarUrl,
                providerMetadataJson: providerMetadataJson,
                authState: authState,
                calendarsEnabled: calendarsEnabled,
                tasksEnabled: tasksEnabled,
                grantedScopes: grantedScopes,
                createdAtUtc: createdAtUtc,
                updatedAtUtc: updatedAtUtc,
                lastSuccessfulSyncAtUtc: lastSuccessfulSyncAtUtc,
                lastFullSyncAtUtc: lastFullSyncAtUtc,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String> provider = const Value.absent(),
                Value<String?> providerAccountId = const Value.absent(),
                Value<String?> displayName = const Value.absent(),
                Value<String?> email = const Value.absent(),
                Value<String?> tenantId = const Value.absent(),
                Value<String?> accountAvatarUrl = const Value.absent(),
                Value<String?> providerMetadataJson = const Value.absent(),
                Value<String> authState = const Value.absent(),
                Value<bool> calendarsEnabled = const Value.absent(),
                Value<bool> tasksEnabled = const Value.absent(),
                Value<String> grantedScopes = const Value.absent(),
                required String createdAtUtc,
                required String updatedAtUtc,
                Value<String?> lastSuccessfulSyncAtUtc = const Value.absent(),
                Value<String?> lastFullSyncAtUtc = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AccountsCompanion.insert(
                id: id,
                provider: provider,
                providerAccountId: providerAccountId,
                displayName: displayName,
                email: email,
                tenantId: tenantId,
                accountAvatarUrl: accountAvatarUrl,
                providerMetadataJson: providerMetadataJson,
                authState: authState,
                calendarsEnabled: calendarsEnabled,
                tasksEnabled: tasksEnabled,
                grantedScopes: grantedScopes,
                createdAtUtc: createdAtUtc,
                updatedAtUtc: updatedAtUtc,
                lastSuccessfulSyncAtUtc: lastSuccessfulSyncAtUtc,
                lastFullSyncAtUtc: lastFullSyncAtUtc,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$AccountsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                taskListsRefs = false,
                tasksRefs = false,
                pendingOpsRefs = false,
                syncRunsRefs = false,
                calendarSourcesRefs = false,
                calendarEventsRefs = false,
                calendarSyncStatesRefs = false,
                scheduleItemOverridesRefs = false,
                notificationScheduleRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (taskListsRefs) db.taskLists,
                    if (tasksRefs) db.tasks,
                    if (pendingOpsRefs) db.pendingOps,
                    if (syncRunsRefs) db.syncRuns,
                    if (calendarSourcesRefs) db.calendarSources,
                    if (calendarEventsRefs) db.calendarEvents,
                    if (calendarSyncStatesRefs) db.calendarSyncStates,
                    if (scheduleItemOverridesRefs) db.scheduleItemOverrides,
                    if (notificationScheduleRefs) db.notificationSchedule,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (taskListsRefs)
                        await $_getPrefetchedData<
                          Account,
                          $AccountsTable,
                          TaskList
                        >(
                          currentTable: table,
                          referencedTable: $$AccountsTableReferences
                              ._taskListsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$AccountsTableReferences(
                                db,
                                table,
                                p0,
                              ).taskListsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.accountId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (tasksRefs)
                        await $_getPrefetchedData<
                          Account,
                          $AccountsTable,
                          Task
                        >(
                          currentTable: table,
                          referencedTable: $$AccountsTableReferences
                              ._tasksRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$AccountsTableReferences(
                                db,
                                table,
                                p0,
                              ).tasksRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.accountId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (pendingOpsRefs)
                        await $_getPrefetchedData<
                          Account,
                          $AccountsTable,
                          PendingOp
                        >(
                          currentTable: table,
                          referencedTable: $$AccountsTableReferences
                              ._pendingOpsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$AccountsTableReferences(
                                db,
                                table,
                                p0,
                              ).pendingOpsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.accountId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (syncRunsRefs)
                        await $_getPrefetchedData<
                          Account,
                          $AccountsTable,
                          SyncRun
                        >(
                          currentTable: table,
                          referencedTable: $$AccountsTableReferences
                              ._syncRunsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$AccountsTableReferences(
                                db,
                                table,
                                p0,
                              ).syncRunsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.accountId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (calendarSourcesRefs)
                        await $_getPrefetchedData<
                          Account,
                          $AccountsTable,
                          CalendarSource
                        >(
                          currentTable: table,
                          referencedTable: $$AccountsTableReferences
                              ._calendarSourcesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$AccountsTableReferences(
                                db,
                                table,
                                p0,
                              ).calendarSourcesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.accountId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (calendarEventsRefs)
                        await $_getPrefetchedData<
                          Account,
                          $AccountsTable,
                          CalendarEvent
                        >(
                          currentTable: table,
                          referencedTable: $$AccountsTableReferences
                              ._calendarEventsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$AccountsTableReferences(
                                db,
                                table,
                                p0,
                              ).calendarEventsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.accountId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (calendarSyncStatesRefs)
                        await $_getPrefetchedData<
                          Account,
                          $AccountsTable,
                          CalendarSyncState
                        >(
                          currentTable: table,
                          referencedTable: $$AccountsTableReferences
                              ._calendarSyncStatesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$AccountsTableReferences(
                                db,
                                table,
                                p0,
                              ).calendarSyncStatesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.accountId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (scheduleItemOverridesRefs)
                        await $_getPrefetchedData<
                          Account,
                          $AccountsTable,
                          ScheduleItemOverride
                        >(
                          currentTable: table,
                          referencedTable: $$AccountsTableReferences
                              ._scheduleItemOverridesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$AccountsTableReferences(
                                db,
                                table,
                                p0,
                              ).scheduleItemOverridesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.accountId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (notificationScheduleRefs)
                        await $_getPrefetchedData<
                          Account,
                          $AccountsTable,
                          NotificationScheduleData
                        >(
                          currentTable: table,
                          referencedTable: $$AccountsTableReferences
                              ._notificationScheduleRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$AccountsTableReferences(
                                db,
                                table,
                                p0,
                              ).notificationScheduleRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.accountId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$AccountsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AccountsTable,
      Account,
      $$AccountsTableFilterComposer,
      $$AccountsTableOrderingComposer,
      $$AccountsTableAnnotationComposer,
      $$AccountsTableCreateCompanionBuilder,
      $$AccountsTableUpdateCompanionBuilder,
      (Account, $$AccountsTableReferences),
      Account,
      PrefetchHooks Function({
        bool taskListsRefs,
        bool tasksRefs,
        bool pendingOpsRefs,
        bool syncRunsRefs,
        bool calendarSourcesRefs,
        bool calendarEventsRefs,
        bool calendarSyncStatesRefs,
        bool scheduleItemOverridesRefs,
        bool notificationScheduleRefs,
      })
    >;
typedef $$TaskListsTableCreateCompanionBuilder =
    TaskListsCompanion Function({
      required String accountId,
      required String id,
      Value<String?> kind,
      Value<String?> etag,
      required String title,
      Value<String?> updatedUtc,
      Value<String?> selfLink,
      required String rawJson,
      Value<String?> providerListKind,
      Value<bool?> isOwner,
      Value<bool?> isShared,
      Value<String?> deltaLink,
      Value<String?> providerMetadataJson,
      Value<bool> serverMissing,
      Value<bool> localDirty,
      Value<bool> pendingDelete,
      Value<String?> lastSyncedAtUtc,
      required String createdLocalAtUtc,
      required String updatedLocalAtUtc,
      Value<int> rowid,
    });
typedef $$TaskListsTableUpdateCompanionBuilder =
    TaskListsCompanion Function({
      Value<String> accountId,
      Value<String> id,
      Value<String?> kind,
      Value<String?> etag,
      Value<String> title,
      Value<String?> updatedUtc,
      Value<String?> selfLink,
      Value<String> rawJson,
      Value<String?> providerListKind,
      Value<bool?> isOwner,
      Value<bool?> isShared,
      Value<String?> deltaLink,
      Value<String?> providerMetadataJson,
      Value<bool> serverMissing,
      Value<bool> localDirty,
      Value<bool> pendingDelete,
      Value<String?> lastSyncedAtUtc,
      Value<String> createdLocalAtUtc,
      Value<String> updatedLocalAtUtc,
      Value<int> rowid,
    });

final class $$TaskListsTableReferences
    extends BaseReferences<_$AppDatabase, $TaskListsTable, TaskList> {
  $$TaskListsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $AccountsTable _accountIdTable(_$AppDatabase db) =>
      db.accounts.createAlias(
        $_aliasNameGenerator(db.taskLists.accountId, db.accounts.id),
      );

  $$AccountsTableProcessedTableManager get accountId {
    final $_column = $_itemColumn<String>('account_id')!;

    final manager = $$AccountsTableTableManager(
      $_db,
      $_db.accounts,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_accountIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$TaskListsTableFilterComposer
    extends Composer<_$AppDatabase, $TaskListsTable> {
  $$TaskListsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get etag => $composableBuilder(
    column: $table.etag,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get updatedUtc => $composableBuilder(
    column: $table.updatedUtc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get selfLink => $composableBuilder(
    column: $table.selfLink,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get rawJson => $composableBuilder(
    column: $table.rawJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get providerListKind => $composableBuilder(
    column: $table.providerListKind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isOwner => $composableBuilder(
    column: $table.isOwner,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isShared => $composableBuilder(
    column: $table.isShared,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deltaLink => $composableBuilder(
    column: $table.deltaLink,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get providerMetadataJson => $composableBuilder(
    column: $table.providerMetadataJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get serverMissing => $composableBuilder(
    column: $table.serverMissing,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get localDirty => $composableBuilder(
    column: $table.localDirty,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get pendingDelete => $composableBuilder(
    column: $table.pendingDelete,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastSyncedAtUtc => $composableBuilder(
    column: $table.lastSyncedAtUtc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdLocalAtUtc => $composableBuilder(
    column: $table.createdLocalAtUtc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get updatedLocalAtUtc => $composableBuilder(
    column: $table.updatedLocalAtUtc,
    builder: (column) => ColumnFilters(column),
  );

  $$AccountsTableFilterComposer get accountId {
    final $$AccountsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.accountId,
      referencedTable: $db.accounts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AccountsTableFilterComposer(
            $db: $db,
            $table: $db.accounts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TaskListsTableOrderingComposer
    extends Composer<_$AppDatabase, $TaskListsTable> {
  $$TaskListsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get etag => $composableBuilder(
    column: $table.etag,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get updatedUtc => $composableBuilder(
    column: $table.updatedUtc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get selfLink => $composableBuilder(
    column: $table.selfLink,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get rawJson => $composableBuilder(
    column: $table.rawJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get providerListKind => $composableBuilder(
    column: $table.providerListKind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isOwner => $composableBuilder(
    column: $table.isOwner,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isShared => $composableBuilder(
    column: $table.isShared,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deltaLink => $composableBuilder(
    column: $table.deltaLink,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get providerMetadataJson => $composableBuilder(
    column: $table.providerMetadataJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get serverMissing => $composableBuilder(
    column: $table.serverMissing,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get localDirty => $composableBuilder(
    column: $table.localDirty,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get pendingDelete => $composableBuilder(
    column: $table.pendingDelete,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastSyncedAtUtc => $composableBuilder(
    column: $table.lastSyncedAtUtc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdLocalAtUtc => $composableBuilder(
    column: $table.createdLocalAtUtc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get updatedLocalAtUtc => $composableBuilder(
    column: $table.updatedLocalAtUtc,
    builder: (column) => ColumnOrderings(column),
  );

  $$AccountsTableOrderingComposer get accountId {
    final $$AccountsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.accountId,
      referencedTable: $db.accounts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AccountsTableOrderingComposer(
            $db: $db,
            $table: $db.accounts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TaskListsTableAnnotationComposer
    extends Composer<_$AppDatabase, $TaskListsTable> {
  $$TaskListsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get etag =>
      $composableBuilder(column: $table.etag, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get updatedUtc => $composableBuilder(
    column: $table.updatedUtc,
    builder: (column) => column,
  );

  GeneratedColumn<String> get selfLink =>
      $composableBuilder(column: $table.selfLink, builder: (column) => column);

  GeneratedColumn<String> get rawJson =>
      $composableBuilder(column: $table.rawJson, builder: (column) => column);

  GeneratedColumn<String> get providerListKind => $composableBuilder(
    column: $table.providerListKind,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isOwner =>
      $composableBuilder(column: $table.isOwner, builder: (column) => column);

  GeneratedColumn<bool> get isShared =>
      $composableBuilder(column: $table.isShared, builder: (column) => column);

  GeneratedColumn<String> get deltaLink =>
      $composableBuilder(column: $table.deltaLink, builder: (column) => column);

  GeneratedColumn<String> get providerMetadataJson => $composableBuilder(
    column: $table.providerMetadataJson,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get serverMissing => $composableBuilder(
    column: $table.serverMissing,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get localDirty => $composableBuilder(
    column: $table.localDirty,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get pendingDelete => $composableBuilder(
    column: $table.pendingDelete,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lastSyncedAtUtc => $composableBuilder(
    column: $table.lastSyncedAtUtc,
    builder: (column) => column,
  );

  GeneratedColumn<String> get createdLocalAtUtc => $composableBuilder(
    column: $table.createdLocalAtUtc,
    builder: (column) => column,
  );

  GeneratedColumn<String> get updatedLocalAtUtc => $composableBuilder(
    column: $table.updatedLocalAtUtc,
    builder: (column) => column,
  );

  $$AccountsTableAnnotationComposer get accountId {
    final $$AccountsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.accountId,
      referencedTable: $db.accounts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AccountsTableAnnotationComposer(
            $db: $db,
            $table: $db.accounts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TaskListsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TaskListsTable,
          TaskList,
          $$TaskListsTableFilterComposer,
          $$TaskListsTableOrderingComposer,
          $$TaskListsTableAnnotationComposer,
          $$TaskListsTableCreateCompanionBuilder,
          $$TaskListsTableUpdateCompanionBuilder,
          (TaskList, $$TaskListsTableReferences),
          TaskList,
          PrefetchHooks Function({bool accountId})
        > {
  $$TaskListsTableTableManager(_$AppDatabase db, $TaskListsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TaskListsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TaskListsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TaskListsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> accountId = const Value.absent(),
                Value<String> id = const Value.absent(),
                Value<String?> kind = const Value.absent(),
                Value<String?> etag = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String?> updatedUtc = const Value.absent(),
                Value<String?> selfLink = const Value.absent(),
                Value<String> rawJson = const Value.absent(),
                Value<String?> providerListKind = const Value.absent(),
                Value<bool?> isOwner = const Value.absent(),
                Value<bool?> isShared = const Value.absent(),
                Value<String?> deltaLink = const Value.absent(),
                Value<String?> providerMetadataJson = const Value.absent(),
                Value<bool> serverMissing = const Value.absent(),
                Value<bool> localDirty = const Value.absent(),
                Value<bool> pendingDelete = const Value.absent(),
                Value<String?> lastSyncedAtUtc = const Value.absent(),
                Value<String> createdLocalAtUtc = const Value.absent(),
                Value<String> updatedLocalAtUtc = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TaskListsCompanion(
                accountId: accountId,
                id: id,
                kind: kind,
                etag: etag,
                title: title,
                updatedUtc: updatedUtc,
                selfLink: selfLink,
                rawJson: rawJson,
                providerListKind: providerListKind,
                isOwner: isOwner,
                isShared: isShared,
                deltaLink: deltaLink,
                providerMetadataJson: providerMetadataJson,
                serverMissing: serverMissing,
                localDirty: localDirty,
                pendingDelete: pendingDelete,
                lastSyncedAtUtc: lastSyncedAtUtc,
                createdLocalAtUtc: createdLocalAtUtc,
                updatedLocalAtUtc: updatedLocalAtUtc,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String accountId,
                required String id,
                Value<String?> kind = const Value.absent(),
                Value<String?> etag = const Value.absent(),
                required String title,
                Value<String?> updatedUtc = const Value.absent(),
                Value<String?> selfLink = const Value.absent(),
                required String rawJson,
                Value<String?> providerListKind = const Value.absent(),
                Value<bool?> isOwner = const Value.absent(),
                Value<bool?> isShared = const Value.absent(),
                Value<String?> deltaLink = const Value.absent(),
                Value<String?> providerMetadataJson = const Value.absent(),
                Value<bool> serverMissing = const Value.absent(),
                Value<bool> localDirty = const Value.absent(),
                Value<bool> pendingDelete = const Value.absent(),
                Value<String?> lastSyncedAtUtc = const Value.absent(),
                required String createdLocalAtUtc,
                required String updatedLocalAtUtc,
                Value<int> rowid = const Value.absent(),
              }) => TaskListsCompanion.insert(
                accountId: accountId,
                id: id,
                kind: kind,
                etag: etag,
                title: title,
                updatedUtc: updatedUtc,
                selfLink: selfLink,
                rawJson: rawJson,
                providerListKind: providerListKind,
                isOwner: isOwner,
                isShared: isShared,
                deltaLink: deltaLink,
                providerMetadataJson: providerMetadataJson,
                serverMissing: serverMissing,
                localDirty: localDirty,
                pendingDelete: pendingDelete,
                lastSyncedAtUtc: lastSyncedAtUtc,
                createdLocalAtUtc: createdLocalAtUtc,
                updatedLocalAtUtc: updatedLocalAtUtc,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$TaskListsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({accountId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (accountId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.accountId,
                                referencedTable: $$TaskListsTableReferences
                                    ._accountIdTable(db),
                                referencedColumn: $$TaskListsTableReferences
                                    ._accountIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$TaskListsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TaskListsTable,
      TaskList,
      $$TaskListsTableFilterComposer,
      $$TaskListsTableOrderingComposer,
      $$TaskListsTableAnnotationComposer,
      $$TaskListsTableCreateCompanionBuilder,
      $$TaskListsTableUpdateCompanionBuilder,
      (TaskList, $$TaskListsTableReferences),
      TaskList,
      PrefetchHooks Function({bool accountId})
    >;
typedef $$TasksTableCreateCompanionBuilder =
    TasksCompanion Function({
      required String accountId,
      required String taskListId,
      required String id,
      Value<String?> kind,
      Value<String?> etag,
      required String title,
      Value<String?> updatedUtc,
      Value<String?> selfLink,
      Value<String?> parent,
      Value<String?> position,
      Value<String?> notes,
      Value<String?> status,
      Value<String?> dueUtc,
      Value<String?> completedUtc,
      Value<String?> providerStatus,
      Value<String?> bodyContent,
      Value<String?> bodyContentType,
      Value<String?> microsoftDueDateTime,
      Value<String?> microsoftDueTimeZone,
      Value<String?> microsoftStartDateTime,
      Value<String?> microsoftStartTimeZone,
      Value<String?> microsoftReminderDateTime,
      Value<String?> microsoftReminderTimeZone,
      Value<bool?> microsoftIsReminderOn,
      Value<String?> microsoftCompletedDateTime,
      Value<String?> microsoftCompletedTimeZone,
      Value<String?> recurrenceJson,
      Value<String?> importance,
      Value<String?> categoriesJson,
      Value<bool?> hasAttachments,
      Value<String?> providerMetadataJson,
      Value<bool?> deleted,
      Value<bool?> hidden,
      Value<String?> linksJson,
      Value<String?> webViewLink,
      Value<String?> assignmentInfoJson,
      required String rawJson,
      Value<bool> serverMissing,
      Value<bool> localDirty,
      Value<bool> pendingDelete,
      Value<bool> pendingMove,
      Value<bool> localCreated,
      Value<String?> syncBaseUpdatedUtc,
      Value<String?> lastSyncedAtUtc,
      required String createdLocalAtUtc,
      required String updatedLocalAtUtc,
      Value<int> rowid,
    });
typedef $$TasksTableUpdateCompanionBuilder =
    TasksCompanion Function({
      Value<String> accountId,
      Value<String> taskListId,
      Value<String> id,
      Value<String?> kind,
      Value<String?> etag,
      Value<String> title,
      Value<String?> updatedUtc,
      Value<String?> selfLink,
      Value<String?> parent,
      Value<String?> position,
      Value<String?> notes,
      Value<String?> status,
      Value<String?> dueUtc,
      Value<String?> completedUtc,
      Value<String?> providerStatus,
      Value<String?> bodyContent,
      Value<String?> bodyContentType,
      Value<String?> microsoftDueDateTime,
      Value<String?> microsoftDueTimeZone,
      Value<String?> microsoftStartDateTime,
      Value<String?> microsoftStartTimeZone,
      Value<String?> microsoftReminderDateTime,
      Value<String?> microsoftReminderTimeZone,
      Value<bool?> microsoftIsReminderOn,
      Value<String?> microsoftCompletedDateTime,
      Value<String?> microsoftCompletedTimeZone,
      Value<String?> recurrenceJson,
      Value<String?> importance,
      Value<String?> categoriesJson,
      Value<bool?> hasAttachments,
      Value<String?> providerMetadataJson,
      Value<bool?> deleted,
      Value<bool?> hidden,
      Value<String?> linksJson,
      Value<String?> webViewLink,
      Value<String?> assignmentInfoJson,
      Value<String> rawJson,
      Value<bool> serverMissing,
      Value<bool> localDirty,
      Value<bool> pendingDelete,
      Value<bool> pendingMove,
      Value<bool> localCreated,
      Value<String?> syncBaseUpdatedUtc,
      Value<String?> lastSyncedAtUtc,
      Value<String> createdLocalAtUtc,
      Value<String> updatedLocalAtUtc,
      Value<int> rowid,
    });

final class $$TasksTableReferences
    extends BaseReferences<_$AppDatabase, $TasksTable, Task> {
  $$TasksTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $AccountsTable _accountIdTable(_$AppDatabase db) => db.accounts
      .createAlias($_aliasNameGenerator(db.tasks.accountId, db.accounts.id));

  $$AccountsTableProcessedTableManager get accountId {
    final $_column = $_itemColumn<String>('account_id')!;

    final manager = $$AccountsTableTableManager(
      $_db,
      $_db.accounts,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_accountIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$TasksTableFilterComposer extends Composer<_$AppDatabase, $TasksTable> {
  $$TasksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get taskListId => $composableBuilder(
    column: $table.taskListId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get etag => $composableBuilder(
    column: $table.etag,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get updatedUtc => $composableBuilder(
    column: $table.updatedUtc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get selfLink => $composableBuilder(
    column: $table.selfLink,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get parent => $composableBuilder(
    column: $table.parent,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dueUtc => $composableBuilder(
    column: $table.dueUtc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get completedUtc => $composableBuilder(
    column: $table.completedUtc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get providerStatus => $composableBuilder(
    column: $table.providerStatus,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get bodyContent => $composableBuilder(
    column: $table.bodyContent,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get bodyContentType => $composableBuilder(
    column: $table.bodyContentType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get microsoftDueDateTime => $composableBuilder(
    column: $table.microsoftDueDateTime,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get microsoftDueTimeZone => $composableBuilder(
    column: $table.microsoftDueTimeZone,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get microsoftStartDateTime => $composableBuilder(
    column: $table.microsoftStartDateTime,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get microsoftStartTimeZone => $composableBuilder(
    column: $table.microsoftStartTimeZone,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get microsoftReminderDateTime => $composableBuilder(
    column: $table.microsoftReminderDateTime,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get microsoftReminderTimeZone => $composableBuilder(
    column: $table.microsoftReminderTimeZone,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get microsoftIsReminderOn => $composableBuilder(
    column: $table.microsoftIsReminderOn,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get microsoftCompletedDateTime => $composableBuilder(
    column: $table.microsoftCompletedDateTime,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get microsoftCompletedTimeZone => $composableBuilder(
    column: $table.microsoftCompletedTimeZone,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get recurrenceJson => $composableBuilder(
    column: $table.recurrenceJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get importance => $composableBuilder(
    column: $table.importance,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get categoriesJson => $composableBuilder(
    column: $table.categoriesJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get hasAttachments => $composableBuilder(
    column: $table.hasAttachments,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get providerMetadataJson => $composableBuilder(
    column: $table.providerMetadataJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get deleted => $composableBuilder(
    column: $table.deleted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get hidden => $composableBuilder(
    column: $table.hidden,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get linksJson => $composableBuilder(
    column: $table.linksJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get webViewLink => $composableBuilder(
    column: $table.webViewLink,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get assignmentInfoJson => $composableBuilder(
    column: $table.assignmentInfoJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get rawJson => $composableBuilder(
    column: $table.rawJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get serverMissing => $composableBuilder(
    column: $table.serverMissing,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get localDirty => $composableBuilder(
    column: $table.localDirty,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get pendingDelete => $composableBuilder(
    column: $table.pendingDelete,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get pendingMove => $composableBuilder(
    column: $table.pendingMove,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get localCreated => $composableBuilder(
    column: $table.localCreated,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get syncBaseUpdatedUtc => $composableBuilder(
    column: $table.syncBaseUpdatedUtc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastSyncedAtUtc => $composableBuilder(
    column: $table.lastSyncedAtUtc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdLocalAtUtc => $composableBuilder(
    column: $table.createdLocalAtUtc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get updatedLocalAtUtc => $composableBuilder(
    column: $table.updatedLocalAtUtc,
    builder: (column) => ColumnFilters(column),
  );

  $$AccountsTableFilterComposer get accountId {
    final $$AccountsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.accountId,
      referencedTable: $db.accounts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AccountsTableFilterComposer(
            $db: $db,
            $table: $db.accounts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TasksTableOrderingComposer
    extends Composer<_$AppDatabase, $TasksTable> {
  $$TasksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get taskListId => $composableBuilder(
    column: $table.taskListId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get etag => $composableBuilder(
    column: $table.etag,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get updatedUtc => $composableBuilder(
    column: $table.updatedUtc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get selfLink => $composableBuilder(
    column: $table.selfLink,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get parent => $composableBuilder(
    column: $table.parent,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dueUtc => $composableBuilder(
    column: $table.dueUtc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get completedUtc => $composableBuilder(
    column: $table.completedUtc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get providerStatus => $composableBuilder(
    column: $table.providerStatus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get bodyContent => $composableBuilder(
    column: $table.bodyContent,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get bodyContentType => $composableBuilder(
    column: $table.bodyContentType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get microsoftDueDateTime => $composableBuilder(
    column: $table.microsoftDueDateTime,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get microsoftDueTimeZone => $composableBuilder(
    column: $table.microsoftDueTimeZone,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get microsoftStartDateTime => $composableBuilder(
    column: $table.microsoftStartDateTime,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get microsoftStartTimeZone => $composableBuilder(
    column: $table.microsoftStartTimeZone,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get microsoftReminderDateTime => $composableBuilder(
    column: $table.microsoftReminderDateTime,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get microsoftReminderTimeZone => $composableBuilder(
    column: $table.microsoftReminderTimeZone,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get microsoftIsReminderOn => $composableBuilder(
    column: $table.microsoftIsReminderOn,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get microsoftCompletedDateTime => $composableBuilder(
    column: $table.microsoftCompletedDateTime,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get microsoftCompletedTimeZone => $composableBuilder(
    column: $table.microsoftCompletedTimeZone,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get recurrenceJson => $composableBuilder(
    column: $table.recurrenceJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get importance => $composableBuilder(
    column: $table.importance,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get categoriesJson => $composableBuilder(
    column: $table.categoriesJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get hasAttachments => $composableBuilder(
    column: $table.hasAttachments,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get providerMetadataJson => $composableBuilder(
    column: $table.providerMetadataJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get deleted => $composableBuilder(
    column: $table.deleted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get hidden => $composableBuilder(
    column: $table.hidden,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get linksJson => $composableBuilder(
    column: $table.linksJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get webViewLink => $composableBuilder(
    column: $table.webViewLink,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get assignmentInfoJson => $composableBuilder(
    column: $table.assignmentInfoJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get rawJson => $composableBuilder(
    column: $table.rawJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get serverMissing => $composableBuilder(
    column: $table.serverMissing,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get localDirty => $composableBuilder(
    column: $table.localDirty,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get pendingDelete => $composableBuilder(
    column: $table.pendingDelete,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get pendingMove => $composableBuilder(
    column: $table.pendingMove,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get localCreated => $composableBuilder(
    column: $table.localCreated,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get syncBaseUpdatedUtc => $composableBuilder(
    column: $table.syncBaseUpdatedUtc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastSyncedAtUtc => $composableBuilder(
    column: $table.lastSyncedAtUtc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdLocalAtUtc => $composableBuilder(
    column: $table.createdLocalAtUtc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get updatedLocalAtUtc => $composableBuilder(
    column: $table.updatedLocalAtUtc,
    builder: (column) => ColumnOrderings(column),
  );

  $$AccountsTableOrderingComposer get accountId {
    final $$AccountsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.accountId,
      referencedTable: $db.accounts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AccountsTableOrderingComposer(
            $db: $db,
            $table: $db.accounts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TasksTableAnnotationComposer
    extends Composer<_$AppDatabase, $TasksTable> {
  $$TasksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get taskListId => $composableBuilder(
    column: $table.taskListId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get etag =>
      $composableBuilder(column: $table.etag, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get updatedUtc => $composableBuilder(
    column: $table.updatedUtc,
    builder: (column) => column,
  );

  GeneratedColumn<String> get selfLink =>
      $composableBuilder(column: $table.selfLink, builder: (column) => column);

  GeneratedColumn<String> get parent =>
      $composableBuilder(column: $table.parent, builder: (column) => column);

  GeneratedColumn<String> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get dueUtc =>
      $composableBuilder(column: $table.dueUtc, builder: (column) => column);

  GeneratedColumn<String> get completedUtc => $composableBuilder(
    column: $table.completedUtc,
    builder: (column) => column,
  );

  GeneratedColumn<String> get providerStatus => $composableBuilder(
    column: $table.providerStatus,
    builder: (column) => column,
  );

  GeneratedColumn<String> get bodyContent => $composableBuilder(
    column: $table.bodyContent,
    builder: (column) => column,
  );

  GeneratedColumn<String> get bodyContentType => $composableBuilder(
    column: $table.bodyContentType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get microsoftDueDateTime => $composableBuilder(
    column: $table.microsoftDueDateTime,
    builder: (column) => column,
  );

  GeneratedColumn<String> get microsoftDueTimeZone => $composableBuilder(
    column: $table.microsoftDueTimeZone,
    builder: (column) => column,
  );

  GeneratedColumn<String> get microsoftStartDateTime => $composableBuilder(
    column: $table.microsoftStartDateTime,
    builder: (column) => column,
  );

  GeneratedColumn<String> get microsoftStartTimeZone => $composableBuilder(
    column: $table.microsoftStartTimeZone,
    builder: (column) => column,
  );

  GeneratedColumn<String> get microsoftReminderDateTime => $composableBuilder(
    column: $table.microsoftReminderDateTime,
    builder: (column) => column,
  );

  GeneratedColumn<String> get microsoftReminderTimeZone => $composableBuilder(
    column: $table.microsoftReminderTimeZone,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get microsoftIsReminderOn => $composableBuilder(
    column: $table.microsoftIsReminderOn,
    builder: (column) => column,
  );

  GeneratedColumn<String> get microsoftCompletedDateTime => $composableBuilder(
    column: $table.microsoftCompletedDateTime,
    builder: (column) => column,
  );

  GeneratedColumn<String> get microsoftCompletedTimeZone => $composableBuilder(
    column: $table.microsoftCompletedTimeZone,
    builder: (column) => column,
  );

  GeneratedColumn<String> get recurrenceJson => $composableBuilder(
    column: $table.recurrenceJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get importance => $composableBuilder(
    column: $table.importance,
    builder: (column) => column,
  );

  GeneratedColumn<String> get categoriesJson => $composableBuilder(
    column: $table.categoriesJson,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get hasAttachments => $composableBuilder(
    column: $table.hasAttachments,
    builder: (column) => column,
  );

  GeneratedColumn<String> get providerMetadataJson => $composableBuilder(
    column: $table.providerMetadataJson,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get deleted =>
      $composableBuilder(column: $table.deleted, builder: (column) => column);

  GeneratedColumn<bool> get hidden =>
      $composableBuilder(column: $table.hidden, builder: (column) => column);

  GeneratedColumn<String> get linksJson =>
      $composableBuilder(column: $table.linksJson, builder: (column) => column);

  GeneratedColumn<String> get webViewLink => $composableBuilder(
    column: $table.webViewLink,
    builder: (column) => column,
  );

  GeneratedColumn<String> get assignmentInfoJson => $composableBuilder(
    column: $table.assignmentInfoJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get rawJson =>
      $composableBuilder(column: $table.rawJson, builder: (column) => column);

  GeneratedColumn<bool> get serverMissing => $composableBuilder(
    column: $table.serverMissing,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get localDirty => $composableBuilder(
    column: $table.localDirty,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get pendingDelete => $composableBuilder(
    column: $table.pendingDelete,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get pendingMove => $composableBuilder(
    column: $table.pendingMove,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get localCreated => $composableBuilder(
    column: $table.localCreated,
    builder: (column) => column,
  );

  GeneratedColumn<String> get syncBaseUpdatedUtc => $composableBuilder(
    column: $table.syncBaseUpdatedUtc,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lastSyncedAtUtc => $composableBuilder(
    column: $table.lastSyncedAtUtc,
    builder: (column) => column,
  );

  GeneratedColumn<String> get createdLocalAtUtc => $composableBuilder(
    column: $table.createdLocalAtUtc,
    builder: (column) => column,
  );

  GeneratedColumn<String> get updatedLocalAtUtc => $composableBuilder(
    column: $table.updatedLocalAtUtc,
    builder: (column) => column,
  );

  $$AccountsTableAnnotationComposer get accountId {
    final $$AccountsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.accountId,
      referencedTable: $db.accounts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AccountsTableAnnotationComposer(
            $db: $db,
            $table: $db.accounts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TasksTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TasksTable,
          Task,
          $$TasksTableFilterComposer,
          $$TasksTableOrderingComposer,
          $$TasksTableAnnotationComposer,
          $$TasksTableCreateCompanionBuilder,
          $$TasksTableUpdateCompanionBuilder,
          (Task, $$TasksTableReferences),
          Task,
          PrefetchHooks Function({bool accountId})
        > {
  $$TasksTableTableManager(_$AppDatabase db, $TasksTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TasksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TasksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TasksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> accountId = const Value.absent(),
                Value<String> taskListId = const Value.absent(),
                Value<String> id = const Value.absent(),
                Value<String?> kind = const Value.absent(),
                Value<String?> etag = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String?> updatedUtc = const Value.absent(),
                Value<String?> selfLink = const Value.absent(),
                Value<String?> parent = const Value.absent(),
                Value<String?> position = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<String?> status = const Value.absent(),
                Value<String?> dueUtc = const Value.absent(),
                Value<String?> completedUtc = const Value.absent(),
                Value<String?> providerStatus = const Value.absent(),
                Value<String?> bodyContent = const Value.absent(),
                Value<String?> bodyContentType = const Value.absent(),
                Value<String?> microsoftDueDateTime = const Value.absent(),
                Value<String?> microsoftDueTimeZone = const Value.absent(),
                Value<String?> microsoftStartDateTime = const Value.absent(),
                Value<String?> microsoftStartTimeZone = const Value.absent(),
                Value<String?> microsoftReminderDateTime = const Value.absent(),
                Value<String?> microsoftReminderTimeZone = const Value.absent(),
                Value<bool?> microsoftIsReminderOn = const Value.absent(),
                Value<String?> microsoftCompletedDateTime =
                    const Value.absent(),
                Value<String?> microsoftCompletedTimeZone =
                    const Value.absent(),
                Value<String?> recurrenceJson = const Value.absent(),
                Value<String?> importance = const Value.absent(),
                Value<String?> categoriesJson = const Value.absent(),
                Value<bool?> hasAttachments = const Value.absent(),
                Value<String?> providerMetadataJson = const Value.absent(),
                Value<bool?> deleted = const Value.absent(),
                Value<bool?> hidden = const Value.absent(),
                Value<String?> linksJson = const Value.absent(),
                Value<String?> webViewLink = const Value.absent(),
                Value<String?> assignmentInfoJson = const Value.absent(),
                Value<String> rawJson = const Value.absent(),
                Value<bool> serverMissing = const Value.absent(),
                Value<bool> localDirty = const Value.absent(),
                Value<bool> pendingDelete = const Value.absent(),
                Value<bool> pendingMove = const Value.absent(),
                Value<bool> localCreated = const Value.absent(),
                Value<String?> syncBaseUpdatedUtc = const Value.absent(),
                Value<String?> lastSyncedAtUtc = const Value.absent(),
                Value<String> createdLocalAtUtc = const Value.absent(),
                Value<String> updatedLocalAtUtc = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TasksCompanion(
                accountId: accountId,
                taskListId: taskListId,
                id: id,
                kind: kind,
                etag: etag,
                title: title,
                updatedUtc: updatedUtc,
                selfLink: selfLink,
                parent: parent,
                position: position,
                notes: notes,
                status: status,
                dueUtc: dueUtc,
                completedUtc: completedUtc,
                providerStatus: providerStatus,
                bodyContent: bodyContent,
                bodyContentType: bodyContentType,
                microsoftDueDateTime: microsoftDueDateTime,
                microsoftDueTimeZone: microsoftDueTimeZone,
                microsoftStartDateTime: microsoftStartDateTime,
                microsoftStartTimeZone: microsoftStartTimeZone,
                microsoftReminderDateTime: microsoftReminderDateTime,
                microsoftReminderTimeZone: microsoftReminderTimeZone,
                microsoftIsReminderOn: microsoftIsReminderOn,
                microsoftCompletedDateTime: microsoftCompletedDateTime,
                microsoftCompletedTimeZone: microsoftCompletedTimeZone,
                recurrenceJson: recurrenceJson,
                importance: importance,
                categoriesJson: categoriesJson,
                hasAttachments: hasAttachments,
                providerMetadataJson: providerMetadataJson,
                deleted: deleted,
                hidden: hidden,
                linksJson: linksJson,
                webViewLink: webViewLink,
                assignmentInfoJson: assignmentInfoJson,
                rawJson: rawJson,
                serverMissing: serverMissing,
                localDirty: localDirty,
                pendingDelete: pendingDelete,
                pendingMove: pendingMove,
                localCreated: localCreated,
                syncBaseUpdatedUtc: syncBaseUpdatedUtc,
                lastSyncedAtUtc: lastSyncedAtUtc,
                createdLocalAtUtc: createdLocalAtUtc,
                updatedLocalAtUtc: updatedLocalAtUtc,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String accountId,
                required String taskListId,
                required String id,
                Value<String?> kind = const Value.absent(),
                Value<String?> etag = const Value.absent(),
                required String title,
                Value<String?> updatedUtc = const Value.absent(),
                Value<String?> selfLink = const Value.absent(),
                Value<String?> parent = const Value.absent(),
                Value<String?> position = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<String?> status = const Value.absent(),
                Value<String?> dueUtc = const Value.absent(),
                Value<String?> completedUtc = const Value.absent(),
                Value<String?> providerStatus = const Value.absent(),
                Value<String?> bodyContent = const Value.absent(),
                Value<String?> bodyContentType = const Value.absent(),
                Value<String?> microsoftDueDateTime = const Value.absent(),
                Value<String?> microsoftDueTimeZone = const Value.absent(),
                Value<String?> microsoftStartDateTime = const Value.absent(),
                Value<String?> microsoftStartTimeZone = const Value.absent(),
                Value<String?> microsoftReminderDateTime = const Value.absent(),
                Value<String?> microsoftReminderTimeZone = const Value.absent(),
                Value<bool?> microsoftIsReminderOn = const Value.absent(),
                Value<String?> microsoftCompletedDateTime =
                    const Value.absent(),
                Value<String?> microsoftCompletedTimeZone =
                    const Value.absent(),
                Value<String?> recurrenceJson = const Value.absent(),
                Value<String?> importance = const Value.absent(),
                Value<String?> categoriesJson = const Value.absent(),
                Value<bool?> hasAttachments = const Value.absent(),
                Value<String?> providerMetadataJson = const Value.absent(),
                Value<bool?> deleted = const Value.absent(),
                Value<bool?> hidden = const Value.absent(),
                Value<String?> linksJson = const Value.absent(),
                Value<String?> webViewLink = const Value.absent(),
                Value<String?> assignmentInfoJson = const Value.absent(),
                required String rawJson,
                Value<bool> serverMissing = const Value.absent(),
                Value<bool> localDirty = const Value.absent(),
                Value<bool> pendingDelete = const Value.absent(),
                Value<bool> pendingMove = const Value.absent(),
                Value<bool> localCreated = const Value.absent(),
                Value<String?> syncBaseUpdatedUtc = const Value.absent(),
                Value<String?> lastSyncedAtUtc = const Value.absent(),
                required String createdLocalAtUtc,
                required String updatedLocalAtUtc,
                Value<int> rowid = const Value.absent(),
              }) => TasksCompanion.insert(
                accountId: accountId,
                taskListId: taskListId,
                id: id,
                kind: kind,
                etag: etag,
                title: title,
                updatedUtc: updatedUtc,
                selfLink: selfLink,
                parent: parent,
                position: position,
                notes: notes,
                status: status,
                dueUtc: dueUtc,
                completedUtc: completedUtc,
                providerStatus: providerStatus,
                bodyContent: bodyContent,
                bodyContentType: bodyContentType,
                microsoftDueDateTime: microsoftDueDateTime,
                microsoftDueTimeZone: microsoftDueTimeZone,
                microsoftStartDateTime: microsoftStartDateTime,
                microsoftStartTimeZone: microsoftStartTimeZone,
                microsoftReminderDateTime: microsoftReminderDateTime,
                microsoftReminderTimeZone: microsoftReminderTimeZone,
                microsoftIsReminderOn: microsoftIsReminderOn,
                microsoftCompletedDateTime: microsoftCompletedDateTime,
                microsoftCompletedTimeZone: microsoftCompletedTimeZone,
                recurrenceJson: recurrenceJson,
                importance: importance,
                categoriesJson: categoriesJson,
                hasAttachments: hasAttachments,
                providerMetadataJson: providerMetadataJson,
                deleted: deleted,
                hidden: hidden,
                linksJson: linksJson,
                webViewLink: webViewLink,
                assignmentInfoJson: assignmentInfoJson,
                rawJson: rawJson,
                serverMissing: serverMissing,
                localDirty: localDirty,
                pendingDelete: pendingDelete,
                pendingMove: pendingMove,
                localCreated: localCreated,
                syncBaseUpdatedUtc: syncBaseUpdatedUtc,
                lastSyncedAtUtc: lastSyncedAtUtc,
                createdLocalAtUtc: createdLocalAtUtc,
                updatedLocalAtUtc: updatedLocalAtUtc,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) =>
                    (e.readTable(table), $$TasksTableReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback: ({accountId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (accountId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.accountId,
                                referencedTable: $$TasksTableReferences
                                    ._accountIdTable(db),
                                referencedColumn: $$TasksTableReferences
                                    ._accountIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$TasksTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TasksTable,
      Task,
      $$TasksTableFilterComposer,
      $$TasksTableOrderingComposer,
      $$TasksTableAnnotationComposer,
      $$TasksTableCreateCompanionBuilder,
      $$TasksTableUpdateCompanionBuilder,
      (Task, $$TasksTableReferences),
      Task,
      PrefetchHooks Function({bool accountId})
    >;
typedef $$PendingOpsTableCreateCompanionBuilder =
    PendingOpsCompanion Function({
      required String id,
      required String accountId,
      Value<String?> provider,
      required String entityType,
      required String operation,
      Value<String?> operationType,
      Value<String?> taskListId,
      Value<String?> taskId,
      Value<String?> calendarSourceId,
      Value<String?> providerCalendarId,
      Value<String?> eventId,
      Value<String?> localTempId,
      Value<String?> dependsOnOpId,
      required String requestJson,
      Value<String?> baselineUpdatedUtc,
      Value<String?> baselineRawJson,
      Value<int> attemptCount,
      Value<String?> nextAttemptAtUtc,
      Value<String?> lastErrorCode,
      Value<String?> lastErrorMessage,
      Value<String> state,
      Value<String?> lastError,
      required String createdAtUtc,
      required String updatedAtUtc,
      Value<int> rowid,
    });
typedef $$PendingOpsTableUpdateCompanionBuilder =
    PendingOpsCompanion Function({
      Value<String> id,
      Value<String> accountId,
      Value<String?> provider,
      Value<String> entityType,
      Value<String> operation,
      Value<String?> operationType,
      Value<String?> taskListId,
      Value<String?> taskId,
      Value<String?> calendarSourceId,
      Value<String?> providerCalendarId,
      Value<String?> eventId,
      Value<String?> localTempId,
      Value<String?> dependsOnOpId,
      Value<String> requestJson,
      Value<String?> baselineUpdatedUtc,
      Value<String?> baselineRawJson,
      Value<int> attemptCount,
      Value<String?> nextAttemptAtUtc,
      Value<String?> lastErrorCode,
      Value<String?> lastErrorMessage,
      Value<String> state,
      Value<String?> lastError,
      Value<String> createdAtUtc,
      Value<String> updatedAtUtc,
      Value<int> rowid,
    });

final class $$PendingOpsTableReferences
    extends BaseReferences<_$AppDatabase, $PendingOpsTable, PendingOp> {
  $$PendingOpsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $AccountsTable _accountIdTable(_$AppDatabase db) =>
      db.accounts.createAlias(
        $_aliasNameGenerator(db.pendingOps.accountId, db.accounts.id),
      );

  $$AccountsTableProcessedTableManager get accountId {
    final $_column = $_itemColumn<String>('account_id')!;

    final manager = $$AccountsTableTableManager(
      $_db,
      $_db.accounts,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_accountIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$PendingOpsTableFilterComposer
    extends Composer<_$AppDatabase, $PendingOpsTable> {
  $$PendingOpsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get provider => $composableBuilder(
    column: $table.provider,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get operation => $composableBuilder(
    column: $table.operation,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get operationType => $composableBuilder(
    column: $table.operationType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get taskListId => $composableBuilder(
    column: $table.taskListId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get taskId => $composableBuilder(
    column: $table.taskId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get calendarSourceId => $composableBuilder(
    column: $table.calendarSourceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get providerCalendarId => $composableBuilder(
    column: $table.providerCalendarId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get eventId => $composableBuilder(
    column: $table.eventId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get localTempId => $composableBuilder(
    column: $table.localTempId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dependsOnOpId => $composableBuilder(
    column: $table.dependsOnOpId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get requestJson => $composableBuilder(
    column: $table.requestJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get baselineUpdatedUtc => $composableBuilder(
    column: $table.baselineUpdatedUtc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get baselineRawJson => $composableBuilder(
    column: $table.baselineRawJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get attemptCount => $composableBuilder(
    column: $table.attemptCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get nextAttemptAtUtc => $composableBuilder(
    column: $table.nextAttemptAtUtc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastErrorCode => $composableBuilder(
    column: $table.lastErrorCode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastErrorMessage => $composableBuilder(
    column: $table.lastErrorMessage,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdAtUtc => $composableBuilder(
    column: $table.createdAtUtc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get updatedAtUtc => $composableBuilder(
    column: $table.updatedAtUtc,
    builder: (column) => ColumnFilters(column),
  );

  $$AccountsTableFilterComposer get accountId {
    final $$AccountsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.accountId,
      referencedTable: $db.accounts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AccountsTableFilterComposer(
            $db: $db,
            $table: $db.accounts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PendingOpsTableOrderingComposer
    extends Composer<_$AppDatabase, $PendingOpsTable> {
  $$PendingOpsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get provider => $composableBuilder(
    column: $table.provider,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get operation => $composableBuilder(
    column: $table.operation,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get operationType => $composableBuilder(
    column: $table.operationType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get taskListId => $composableBuilder(
    column: $table.taskListId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get taskId => $composableBuilder(
    column: $table.taskId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get calendarSourceId => $composableBuilder(
    column: $table.calendarSourceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get providerCalendarId => $composableBuilder(
    column: $table.providerCalendarId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get eventId => $composableBuilder(
    column: $table.eventId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get localTempId => $composableBuilder(
    column: $table.localTempId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dependsOnOpId => $composableBuilder(
    column: $table.dependsOnOpId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get requestJson => $composableBuilder(
    column: $table.requestJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get baselineUpdatedUtc => $composableBuilder(
    column: $table.baselineUpdatedUtc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get baselineRawJson => $composableBuilder(
    column: $table.baselineRawJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get attemptCount => $composableBuilder(
    column: $table.attemptCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get nextAttemptAtUtc => $composableBuilder(
    column: $table.nextAttemptAtUtc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastErrorCode => $composableBuilder(
    column: $table.lastErrorCode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastErrorMessage => $composableBuilder(
    column: $table.lastErrorMessage,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdAtUtc => $composableBuilder(
    column: $table.createdAtUtc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get updatedAtUtc => $composableBuilder(
    column: $table.updatedAtUtc,
    builder: (column) => ColumnOrderings(column),
  );

  $$AccountsTableOrderingComposer get accountId {
    final $$AccountsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.accountId,
      referencedTable: $db.accounts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AccountsTableOrderingComposer(
            $db: $db,
            $table: $db.accounts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PendingOpsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PendingOpsTable> {
  $$PendingOpsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get provider =>
      $composableBuilder(column: $table.provider, builder: (column) => column);

  GeneratedColumn<String> get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get operation =>
      $composableBuilder(column: $table.operation, builder: (column) => column);

  GeneratedColumn<String> get operationType => $composableBuilder(
    column: $table.operationType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get taskListId => $composableBuilder(
    column: $table.taskListId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get taskId =>
      $composableBuilder(column: $table.taskId, builder: (column) => column);

  GeneratedColumn<String> get calendarSourceId => $composableBuilder(
    column: $table.calendarSourceId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get providerCalendarId => $composableBuilder(
    column: $table.providerCalendarId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get eventId =>
      $composableBuilder(column: $table.eventId, builder: (column) => column);

  GeneratedColumn<String> get localTempId => $composableBuilder(
    column: $table.localTempId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get dependsOnOpId => $composableBuilder(
    column: $table.dependsOnOpId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get requestJson => $composableBuilder(
    column: $table.requestJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get baselineUpdatedUtc => $composableBuilder(
    column: $table.baselineUpdatedUtc,
    builder: (column) => column,
  );

  GeneratedColumn<String> get baselineRawJson => $composableBuilder(
    column: $table.baselineRawJson,
    builder: (column) => column,
  );

  GeneratedColumn<int> get attemptCount => $composableBuilder(
    column: $table.attemptCount,
    builder: (column) => column,
  );

  GeneratedColumn<String> get nextAttemptAtUtc => $composableBuilder(
    column: $table.nextAttemptAtUtc,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lastErrorCode => $composableBuilder(
    column: $table.lastErrorCode,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lastErrorMessage => $composableBuilder(
    column: $table.lastErrorMessage,
    builder: (column) => column,
  );

  GeneratedColumn<String> get state =>
      $composableBuilder(column: $table.state, builder: (column) => column);

  GeneratedColumn<String> get lastError =>
      $composableBuilder(column: $table.lastError, builder: (column) => column);

  GeneratedColumn<String> get createdAtUtc => $composableBuilder(
    column: $table.createdAtUtc,
    builder: (column) => column,
  );

  GeneratedColumn<String> get updatedAtUtc => $composableBuilder(
    column: $table.updatedAtUtc,
    builder: (column) => column,
  );

  $$AccountsTableAnnotationComposer get accountId {
    final $$AccountsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.accountId,
      referencedTable: $db.accounts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AccountsTableAnnotationComposer(
            $db: $db,
            $table: $db.accounts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PendingOpsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PendingOpsTable,
          PendingOp,
          $$PendingOpsTableFilterComposer,
          $$PendingOpsTableOrderingComposer,
          $$PendingOpsTableAnnotationComposer,
          $$PendingOpsTableCreateCompanionBuilder,
          $$PendingOpsTableUpdateCompanionBuilder,
          (PendingOp, $$PendingOpsTableReferences),
          PendingOp,
          PrefetchHooks Function({bool accountId})
        > {
  $$PendingOpsTableTableManager(_$AppDatabase db, $PendingOpsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PendingOpsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PendingOpsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PendingOpsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> accountId = const Value.absent(),
                Value<String?> provider = const Value.absent(),
                Value<String> entityType = const Value.absent(),
                Value<String> operation = const Value.absent(),
                Value<String?> operationType = const Value.absent(),
                Value<String?> taskListId = const Value.absent(),
                Value<String?> taskId = const Value.absent(),
                Value<String?> calendarSourceId = const Value.absent(),
                Value<String?> providerCalendarId = const Value.absent(),
                Value<String?> eventId = const Value.absent(),
                Value<String?> localTempId = const Value.absent(),
                Value<String?> dependsOnOpId = const Value.absent(),
                Value<String> requestJson = const Value.absent(),
                Value<String?> baselineUpdatedUtc = const Value.absent(),
                Value<String?> baselineRawJson = const Value.absent(),
                Value<int> attemptCount = const Value.absent(),
                Value<String?> nextAttemptAtUtc = const Value.absent(),
                Value<String?> lastErrorCode = const Value.absent(),
                Value<String?> lastErrorMessage = const Value.absent(),
                Value<String> state = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
                Value<String> createdAtUtc = const Value.absent(),
                Value<String> updatedAtUtc = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PendingOpsCompanion(
                id: id,
                accountId: accountId,
                provider: provider,
                entityType: entityType,
                operation: operation,
                operationType: operationType,
                taskListId: taskListId,
                taskId: taskId,
                calendarSourceId: calendarSourceId,
                providerCalendarId: providerCalendarId,
                eventId: eventId,
                localTempId: localTempId,
                dependsOnOpId: dependsOnOpId,
                requestJson: requestJson,
                baselineUpdatedUtc: baselineUpdatedUtc,
                baselineRawJson: baselineRawJson,
                attemptCount: attemptCount,
                nextAttemptAtUtc: nextAttemptAtUtc,
                lastErrorCode: lastErrorCode,
                lastErrorMessage: lastErrorMessage,
                state: state,
                lastError: lastError,
                createdAtUtc: createdAtUtc,
                updatedAtUtc: updatedAtUtc,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String accountId,
                Value<String?> provider = const Value.absent(),
                required String entityType,
                required String operation,
                Value<String?> operationType = const Value.absent(),
                Value<String?> taskListId = const Value.absent(),
                Value<String?> taskId = const Value.absent(),
                Value<String?> calendarSourceId = const Value.absent(),
                Value<String?> providerCalendarId = const Value.absent(),
                Value<String?> eventId = const Value.absent(),
                Value<String?> localTempId = const Value.absent(),
                Value<String?> dependsOnOpId = const Value.absent(),
                required String requestJson,
                Value<String?> baselineUpdatedUtc = const Value.absent(),
                Value<String?> baselineRawJson = const Value.absent(),
                Value<int> attemptCount = const Value.absent(),
                Value<String?> nextAttemptAtUtc = const Value.absent(),
                Value<String?> lastErrorCode = const Value.absent(),
                Value<String?> lastErrorMessage = const Value.absent(),
                Value<String> state = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
                required String createdAtUtc,
                required String updatedAtUtc,
                Value<int> rowid = const Value.absent(),
              }) => PendingOpsCompanion.insert(
                id: id,
                accountId: accountId,
                provider: provider,
                entityType: entityType,
                operation: operation,
                operationType: operationType,
                taskListId: taskListId,
                taskId: taskId,
                calendarSourceId: calendarSourceId,
                providerCalendarId: providerCalendarId,
                eventId: eventId,
                localTempId: localTempId,
                dependsOnOpId: dependsOnOpId,
                requestJson: requestJson,
                baselineUpdatedUtc: baselineUpdatedUtc,
                baselineRawJson: baselineRawJson,
                attemptCount: attemptCount,
                nextAttemptAtUtc: nextAttemptAtUtc,
                lastErrorCode: lastErrorCode,
                lastErrorMessage: lastErrorMessage,
                state: state,
                lastError: lastError,
                createdAtUtc: createdAtUtc,
                updatedAtUtc: updatedAtUtc,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$PendingOpsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({accountId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (accountId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.accountId,
                                referencedTable: $$PendingOpsTableReferences
                                    ._accountIdTable(db),
                                referencedColumn: $$PendingOpsTableReferences
                                    ._accountIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$PendingOpsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PendingOpsTable,
      PendingOp,
      $$PendingOpsTableFilterComposer,
      $$PendingOpsTableOrderingComposer,
      $$PendingOpsTableAnnotationComposer,
      $$PendingOpsTableCreateCompanionBuilder,
      $$PendingOpsTableUpdateCompanionBuilder,
      (PendingOp, $$PendingOpsTableReferences),
      PendingOp,
      PrefetchHooks Function({bool accountId})
    >;
typedef $$SyncRunsTableCreateCompanionBuilder =
    SyncRunsCompanion Function({
      required String id,
      required String accountId,
      Value<String?> provider,
      required String mode,
      required String startedAtUtc,
      Value<String?> finishedAtUtc,
      required String status,
      Value<int> taskListsSeen,
      Value<int> tasksSeen,
      Value<int> pendingOpsApplied,
      Value<String?> errorCode,
      Value<String?> errorMessage,
      Value<int> rowid,
    });
typedef $$SyncRunsTableUpdateCompanionBuilder =
    SyncRunsCompanion Function({
      Value<String> id,
      Value<String> accountId,
      Value<String?> provider,
      Value<String> mode,
      Value<String> startedAtUtc,
      Value<String?> finishedAtUtc,
      Value<String> status,
      Value<int> taskListsSeen,
      Value<int> tasksSeen,
      Value<int> pendingOpsApplied,
      Value<String?> errorCode,
      Value<String?> errorMessage,
      Value<int> rowid,
    });

final class $$SyncRunsTableReferences
    extends BaseReferences<_$AppDatabase, $SyncRunsTable, SyncRun> {
  $$SyncRunsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $AccountsTable _accountIdTable(_$AppDatabase db) => db.accounts
      .createAlias($_aliasNameGenerator(db.syncRuns.accountId, db.accounts.id));

  $$AccountsTableProcessedTableManager get accountId {
    final $_column = $_itemColumn<String>('account_id')!;

    final manager = $$AccountsTableTableManager(
      $_db,
      $_db.accounts,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_accountIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$SyncRunsTableFilterComposer
    extends Composer<_$AppDatabase, $SyncRunsTable> {
  $$SyncRunsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get provider => $composableBuilder(
    column: $table.provider,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mode => $composableBuilder(
    column: $table.mode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get startedAtUtc => $composableBuilder(
    column: $table.startedAtUtc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get finishedAtUtc => $composableBuilder(
    column: $table.finishedAtUtc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get taskListsSeen => $composableBuilder(
    column: $table.taskListsSeen,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get tasksSeen => $composableBuilder(
    column: $table.tasksSeen,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get pendingOpsApplied => $composableBuilder(
    column: $table.pendingOpsApplied,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get errorCode => $composableBuilder(
    column: $table.errorCode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get errorMessage => $composableBuilder(
    column: $table.errorMessage,
    builder: (column) => ColumnFilters(column),
  );

  $$AccountsTableFilterComposer get accountId {
    final $$AccountsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.accountId,
      referencedTable: $db.accounts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AccountsTableFilterComposer(
            $db: $db,
            $table: $db.accounts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SyncRunsTableOrderingComposer
    extends Composer<_$AppDatabase, $SyncRunsTable> {
  $$SyncRunsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get provider => $composableBuilder(
    column: $table.provider,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mode => $composableBuilder(
    column: $table.mode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get startedAtUtc => $composableBuilder(
    column: $table.startedAtUtc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get finishedAtUtc => $composableBuilder(
    column: $table.finishedAtUtc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get taskListsSeen => $composableBuilder(
    column: $table.taskListsSeen,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get tasksSeen => $composableBuilder(
    column: $table.tasksSeen,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get pendingOpsApplied => $composableBuilder(
    column: $table.pendingOpsApplied,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get errorCode => $composableBuilder(
    column: $table.errorCode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get errorMessage => $composableBuilder(
    column: $table.errorMessage,
    builder: (column) => ColumnOrderings(column),
  );

  $$AccountsTableOrderingComposer get accountId {
    final $$AccountsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.accountId,
      referencedTable: $db.accounts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AccountsTableOrderingComposer(
            $db: $db,
            $table: $db.accounts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SyncRunsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SyncRunsTable> {
  $$SyncRunsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get provider =>
      $composableBuilder(column: $table.provider, builder: (column) => column);

  GeneratedColumn<String> get mode =>
      $composableBuilder(column: $table.mode, builder: (column) => column);

  GeneratedColumn<String> get startedAtUtc => $composableBuilder(
    column: $table.startedAtUtc,
    builder: (column) => column,
  );

  GeneratedColumn<String> get finishedAtUtc => $composableBuilder(
    column: $table.finishedAtUtc,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<int> get taskListsSeen => $composableBuilder(
    column: $table.taskListsSeen,
    builder: (column) => column,
  );

  GeneratedColumn<int> get tasksSeen =>
      $composableBuilder(column: $table.tasksSeen, builder: (column) => column);

  GeneratedColumn<int> get pendingOpsApplied => $composableBuilder(
    column: $table.pendingOpsApplied,
    builder: (column) => column,
  );

  GeneratedColumn<String> get errorCode =>
      $composableBuilder(column: $table.errorCode, builder: (column) => column);

  GeneratedColumn<String> get errorMessage => $composableBuilder(
    column: $table.errorMessage,
    builder: (column) => column,
  );

  $$AccountsTableAnnotationComposer get accountId {
    final $$AccountsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.accountId,
      referencedTable: $db.accounts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AccountsTableAnnotationComposer(
            $db: $db,
            $table: $db.accounts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SyncRunsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SyncRunsTable,
          SyncRun,
          $$SyncRunsTableFilterComposer,
          $$SyncRunsTableOrderingComposer,
          $$SyncRunsTableAnnotationComposer,
          $$SyncRunsTableCreateCompanionBuilder,
          $$SyncRunsTableUpdateCompanionBuilder,
          (SyncRun, $$SyncRunsTableReferences),
          SyncRun,
          PrefetchHooks Function({bool accountId})
        > {
  $$SyncRunsTableTableManager(_$AppDatabase db, $SyncRunsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncRunsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncRunsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncRunsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> accountId = const Value.absent(),
                Value<String?> provider = const Value.absent(),
                Value<String> mode = const Value.absent(),
                Value<String> startedAtUtc = const Value.absent(),
                Value<String?> finishedAtUtc = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<int> taskListsSeen = const Value.absent(),
                Value<int> tasksSeen = const Value.absent(),
                Value<int> pendingOpsApplied = const Value.absent(),
                Value<String?> errorCode = const Value.absent(),
                Value<String?> errorMessage = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SyncRunsCompanion(
                id: id,
                accountId: accountId,
                provider: provider,
                mode: mode,
                startedAtUtc: startedAtUtc,
                finishedAtUtc: finishedAtUtc,
                status: status,
                taskListsSeen: taskListsSeen,
                tasksSeen: tasksSeen,
                pendingOpsApplied: pendingOpsApplied,
                errorCode: errorCode,
                errorMessage: errorMessage,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String accountId,
                Value<String?> provider = const Value.absent(),
                required String mode,
                required String startedAtUtc,
                Value<String?> finishedAtUtc = const Value.absent(),
                required String status,
                Value<int> taskListsSeen = const Value.absent(),
                Value<int> tasksSeen = const Value.absent(),
                Value<int> pendingOpsApplied = const Value.absent(),
                Value<String?> errorCode = const Value.absent(),
                Value<String?> errorMessage = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SyncRunsCompanion.insert(
                id: id,
                accountId: accountId,
                provider: provider,
                mode: mode,
                startedAtUtc: startedAtUtc,
                finishedAtUtc: finishedAtUtc,
                status: status,
                taskListsSeen: taskListsSeen,
                tasksSeen: tasksSeen,
                pendingOpsApplied: pendingOpsApplied,
                errorCode: errorCode,
                errorMessage: errorMessage,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$SyncRunsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({accountId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (accountId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.accountId,
                                referencedTable: $$SyncRunsTableReferences
                                    ._accountIdTable(db),
                                referencedColumn: $$SyncRunsTableReferences
                                    ._accountIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$SyncRunsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SyncRunsTable,
      SyncRun,
      $$SyncRunsTableFilterComposer,
      $$SyncRunsTableOrderingComposer,
      $$SyncRunsTableAnnotationComposer,
      $$SyncRunsTableCreateCompanionBuilder,
      $$SyncRunsTableUpdateCompanionBuilder,
      (SyncRun, $$SyncRunsTableReferences),
      SyncRun,
      PrefetchHooks Function({bool accountId})
    >;
typedef $$CalendarSourcesTableCreateCompanionBuilder =
    CalendarSourcesCompanion Function({
      required String id,
      required String accountId,
      required String provider,
      required String providerCalendarId,
      required String summary,
      Value<String?> description,
      Value<bool> primaryCalendar,
      Value<bool> selected,
      Value<bool> hidden,
      Value<bool> readOnly,
      Value<String?> backgroundColor,
      Value<String?> foregroundColor,
      Value<String?> colorId,
      Value<String?> timeZone,
      Value<String?> accessRole,
      Value<bool> isDeleted,
      Value<String?> rawJson,
      required int createdAtLocal,
      required int updatedAtLocal,
      Value<int> rowid,
    });
typedef $$CalendarSourcesTableUpdateCompanionBuilder =
    CalendarSourcesCompanion Function({
      Value<String> id,
      Value<String> accountId,
      Value<String> provider,
      Value<String> providerCalendarId,
      Value<String> summary,
      Value<String?> description,
      Value<bool> primaryCalendar,
      Value<bool> selected,
      Value<bool> hidden,
      Value<bool> readOnly,
      Value<String?> backgroundColor,
      Value<String?> foregroundColor,
      Value<String?> colorId,
      Value<String?> timeZone,
      Value<String?> accessRole,
      Value<bool> isDeleted,
      Value<String?> rawJson,
      Value<int> createdAtLocal,
      Value<int> updatedAtLocal,
      Value<int> rowid,
    });

final class $$CalendarSourcesTableReferences
    extends
        BaseReferences<_$AppDatabase, $CalendarSourcesTable, CalendarSource> {
  $$CalendarSourcesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $AccountsTable _accountIdTable(_$AppDatabase db) =>
      db.accounts.createAlias(
        $_aliasNameGenerator(db.calendarSources.accountId, db.accounts.id),
      );

  $$AccountsTableProcessedTableManager get accountId {
    final $_column = $_itemColumn<String>('account_id')!;

    final manager = $$AccountsTableTableManager(
      $_db,
      $_db.accounts,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_accountIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$CalendarEventsTable, List<CalendarEvent>>
  _calendarEventsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.calendarEvents,
    aliasName: $_aliasNameGenerator(
      db.calendarSources.id,
      db.calendarEvents.calendarSourceId,
    ),
  );

  $$CalendarEventsTableProcessedTableManager get calendarEventsRefs {
    final manager = $$CalendarEventsTableTableManager($_db, $_db.calendarEvents)
        .filter(
          (f) => f.calendarSourceId.id.sqlEquals($_itemColumn<String>('id')!),
        );

    final cache = $_typedResult.readTableOrNull(_calendarEventsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$CalendarSyncStatesTable, List<CalendarSyncState>>
  _calendarSyncStatesRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.calendarSyncStates,
        aliasName: $_aliasNameGenerator(
          db.calendarSources.id,
          db.calendarSyncStates.calendarSourceId,
        ),
      );

  $$CalendarSyncStatesTableProcessedTableManager get calendarSyncStatesRefs {
    final manager =
        $$CalendarSyncStatesTableTableManager(
          $_db,
          $_db.calendarSyncStates,
        ).filter(
          (f) => f.calendarSourceId.id.sqlEquals($_itemColumn<String>('id')!),
        );

    final cache = $_typedResult.readTableOrNull(
      _calendarSyncStatesRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$CalendarSourcesTableFilterComposer
    extends Composer<_$AppDatabase, $CalendarSourcesTable> {
  $$CalendarSourcesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get provider => $composableBuilder(
    column: $table.provider,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get providerCalendarId => $composableBuilder(
    column: $table.providerCalendarId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get summary => $composableBuilder(
    column: $table.summary,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get primaryCalendar => $composableBuilder(
    column: $table.primaryCalendar,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get selected => $composableBuilder(
    column: $table.selected,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get hidden => $composableBuilder(
    column: $table.hidden,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get readOnly => $composableBuilder(
    column: $table.readOnly,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get backgroundColor => $composableBuilder(
    column: $table.backgroundColor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get foregroundColor => $composableBuilder(
    column: $table.foregroundColor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get colorId => $composableBuilder(
    column: $table.colorId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get timeZone => $composableBuilder(
    column: $table.timeZone,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get accessRole => $composableBuilder(
    column: $table.accessRole,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get rawJson => $composableBuilder(
    column: $table.rawJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAtLocal => $composableBuilder(
    column: $table.createdAtLocal,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAtLocal => $composableBuilder(
    column: $table.updatedAtLocal,
    builder: (column) => ColumnFilters(column),
  );

  $$AccountsTableFilterComposer get accountId {
    final $$AccountsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.accountId,
      referencedTable: $db.accounts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AccountsTableFilterComposer(
            $db: $db,
            $table: $db.accounts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> calendarEventsRefs(
    Expression<bool> Function($$CalendarEventsTableFilterComposer f) f,
  ) {
    final $$CalendarEventsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.calendarEvents,
      getReferencedColumn: (t) => t.calendarSourceId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CalendarEventsTableFilterComposer(
            $db: $db,
            $table: $db.calendarEvents,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> calendarSyncStatesRefs(
    Expression<bool> Function($$CalendarSyncStatesTableFilterComposer f) f,
  ) {
    final $$CalendarSyncStatesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.calendarSyncStates,
      getReferencedColumn: (t) => t.calendarSourceId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CalendarSyncStatesTableFilterComposer(
            $db: $db,
            $table: $db.calendarSyncStates,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$CalendarSourcesTableOrderingComposer
    extends Composer<_$AppDatabase, $CalendarSourcesTable> {
  $$CalendarSourcesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get provider => $composableBuilder(
    column: $table.provider,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get providerCalendarId => $composableBuilder(
    column: $table.providerCalendarId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get summary => $composableBuilder(
    column: $table.summary,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get primaryCalendar => $composableBuilder(
    column: $table.primaryCalendar,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get selected => $composableBuilder(
    column: $table.selected,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get hidden => $composableBuilder(
    column: $table.hidden,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get readOnly => $composableBuilder(
    column: $table.readOnly,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get backgroundColor => $composableBuilder(
    column: $table.backgroundColor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get foregroundColor => $composableBuilder(
    column: $table.foregroundColor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get colorId => $composableBuilder(
    column: $table.colorId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get timeZone => $composableBuilder(
    column: $table.timeZone,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get accessRole => $composableBuilder(
    column: $table.accessRole,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get rawJson => $composableBuilder(
    column: $table.rawJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAtLocal => $composableBuilder(
    column: $table.createdAtLocal,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAtLocal => $composableBuilder(
    column: $table.updatedAtLocal,
    builder: (column) => ColumnOrderings(column),
  );

  $$AccountsTableOrderingComposer get accountId {
    final $$AccountsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.accountId,
      referencedTable: $db.accounts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AccountsTableOrderingComposer(
            $db: $db,
            $table: $db.accounts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CalendarSourcesTableAnnotationComposer
    extends Composer<_$AppDatabase, $CalendarSourcesTable> {
  $$CalendarSourcesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get provider =>
      $composableBuilder(column: $table.provider, builder: (column) => column);

  GeneratedColumn<String> get providerCalendarId => $composableBuilder(
    column: $table.providerCalendarId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get summary =>
      $composableBuilder(column: $table.summary, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get primaryCalendar => $composableBuilder(
    column: $table.primaryCalendar,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get selected =>
      $composableBuilder(column: $table.selected, builder: (column) => column);

  GeneratedColumn<bool> get hidden =>
      $composableBuilder(column: $table.hidden, builder: (column) => column);

  GeneratedColumn<bool> get readOnly =>
      $composableBuilder(column: $table.readOnly, builder: (column) => column);

  GeneratedColumn<String> get backgroundColor => $composableBuilder(
    column: $table.backgroundColor,
    builder: (column) => column,
  );

  GeneratedColumn<String> get foregroundColor => $composableBuilder(
    column: $table.foregroundColor,
    builder: (column) => column,
  );

  GeneratedColumn<String> get colorId =>
      $composableBuilder(column: $table.colorId, builder: (column) => column);

  GeneratedColumn<String> get timeZone =>
      $composableBuilder(column: $table.timeZone, builder: (column) => column);

  GeneratedColumn<String> get accessRole => $composableBuilder(
    column: $table.accessRole,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isDeleted =>
      $composableBuilder(column: $table.isDeleted, builder: (column) => column);

  GeneratedColumn<String> get rawJson =>
      $composableBuilder(column: $table.rawJson, builder: (column) => column);

  GeneratedColumn<int> get createdAtLocal => $composableBuilder(
    column: $table.createdAtLocal,
    builder: (column) => column,
  );

  GeneratedColumn<int> get updatedAtLocal => $composableBuilder(
    column: $table.updatedAtLocal,
    builder: (column) => column,
  );

  $$AccountsTableAnnotationComposer get accountId {
    final $$AccountsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.accountId,
      referencedTable: $db.accounts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AccountsTableAnnotationComposer(
            $db: $db,
            $table: $db.accounts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> calendarEventsRefs<T extends Object>(
    Expression<T> Function($$CalendarEventsTableAnnotationComposer a) f,
  ) {
    final $$CalendarEventsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.calendarEvents,
      getReferencedColumn: (t) => t.calendarSourceId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CalendarEventsTableAnnotationComposer(
            $db: $db,
            $table: $db.calendarEvents,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> calendarSyncStatesRefs<T extends Object>(
    Expression<T> Function($$CalendarSyncStatesTableAnnotationComposer a) f,
  ) {
    final $$CalendarSyncStatesTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.calendarSyncStates,
          getReferencedColumn: (t) => t.calendarSourceId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$CalendarSyncStatesTableAnnotationComposer(
                $db: $db,
                $table: $db.calendarSyncStates,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$CalendarSourcesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CalendarSourcesTable,
          CalendarSource,
          $$CalendarSourcesTableFilterComposer,
          $$CalendarSourcesTableOrderingComposer,
          $$CalendarSourcesTableAnnotationComposer,
          $$CalendarSourcesTableCreateCompanionBuilder,
          $$CalendarSourcesTableUpdateCompanionBuilder,
          (CalendarSource, $$CalendarSourcesTableReferences),
          CalendarSource,
          PrefetchHooks Function({
            bool accountId,
            bool calendarEventsRefs,
            bool calendarSyncStatesRefs,
          })
        > {
  $$CalendarSourcesTableTableManager(
    _$AppDatabase db,
    $CalendarSourcesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CalendarSourcesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CalendarSourcesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CalendarSourcesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> accountId = const Value.absent(),
                Value<String> provider = const Value.absent(),
                Value<String> providerCalendarId = const Value.absent(),
                Value<String> summary = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<bool> primaryCalendar = const Value.absent(),
                Value<bool> selected = const Value.absent(),
                Value<bool> hidden = const Value.absent(),
                Value<bool> readOnly = const Value.absent(),
                Value<String?> backgroundColor = const Value.absent(),
                Value<String?> foregroundColor = const Value.absent(),
                Value<String?> colorId = const Value.absent(),
                Value<String?> timeZone = const Value.absent(),
                Value<String?> accessRole = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
                Value<String?> rawJson = const Value.absent(),
                Value<int> createdAtLocal = const Value.absent(),
                Value<int> updatedAtLocal = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CalendarSourcesCompanion(
                id: id,
                accountId: accountId,
                provider: provider,
                providerCalendarId: providerCalendarId,
                summary: summary,
                description: description,
                primaryCalendar: primaryCalendar,
                selected: selected,
                hidden: hidden,
                readOnly: readOnly,
                backgroundColor: backgroundColor,
                foregroundColor: foregroundColor,
                colorId: colorId,
                timeZone: timeZone,
                accessRole: accessRole,
                isDeleted: isDeleted,
                rawJson: rawJson,
                createdAtLocal: createdAtLocal,
                updatedAtLocal: updatedAtLocal,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String accountId,
                required String provider,
                required String providerCalendarId,
                required String summary,
                Value<String?> description = const Value.absent(),
                Value<bool> primaryCalendar = const Value.absent(),
                Value<bool> selected = const Value.absent(),
                Value<bool> hidden = const Value.absent(),
                Value<bool> readOnly = const Value.absent(),
                Value<String?> backgroundColor = const Value.absent(),
                Value<String?> foregroundColor = const Value.absent(),
                Value<String?> colorId = const Value.absent(),
                Value<String?> timeZone = const Value.absent(),
                Value<String?> accessRole = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
                Value<String?> rawJson = const Value.absent(),
                required int createdAtLocal,
                required int updatedAtLocal,
                Value<int> rowid = const Value.absent(),
              }) => CalendarSourcesCompanion.insert(
                id: id,
                accountId: accountId,
                provider: provider,
                providerCalendarId: providerCalendarId,
                summary: summary,
                description: description,
                primaryCalendar: primaryCalendar,
                selected: selected,
                hidden: hidden,
                readOnly: readOnly,
                backgroundColor: backgroundColor,
                foregroundColor: foregroundColor,
                colorId: colorId,
                timeZone: timeZone,
                accessRole: accessRole,
                isDeleted: isDeleted,
                rawJson: rawJson,
                createdAtLocal: createdAtLocal,
                updatedAtLocal: updatedAtLocal,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$CalendarSourcesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                accountId = false,
                calendarEventsRefs = false,
                calendarSyncStatesRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (calendarEventsRefs) db.calendarEvents,
                    if (calendarSyncStatesRefs) db.calendarSyncStates,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (accountId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.accountId,
                                    referencedTable:
                                        $$CalendarSourcesTableReferences
                                            ._accountIdTable(db),
                                    referencedColumn:
                                        $$CalendarSourcesTableReferences
                                            ._accountIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (calendarEventsRefs)
                        await $_getPrefetchedData<
                          CalendarSource,
                          $CalendarSourcesTable,
                          CalendarEvent
                        >(
                          currentTable: table,
                          referencedTable: $$CalendarSourcesTableReferences
                              ._calendarEventsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$CalendarSourcesTableReferences(
                                db,
                                table,
                                p0,
                              ).calendarEventsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.calendarSourceId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (calendarSyncStatesRefs)
                        await $_getPrefetchedData<
                          CalendarSource,
                          $CalendarSourcesTable,
                          CalendarSyncState
                        >(
                          currentTable: table,
                          referencedTable: $$CalendarSourcesTableReferences
                              ._calendarSyncStatesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$CalendarSourcesTableReferences(
                                db,
                                table,
                                p0,
                              ).calendarSyncStatesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.calendarSourceId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$CalendarSourcesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CalendarSourcesTable,
      CalendarSource,
      $$CalendarSourcesTableFilterComposer,
      $$CalendarSourcesTableOrderingComposer,
      $$CalendarSourcesTableAnnotationComposer,
      $$CalendarSourcesTableCreateCompanionBuilder,
      $$CalendarSourcesTableUpdateCompanionBuilder,
      (CalendarSource, $$CalendarSourcesTableReferences),
      CalendarSource,
      PrefetchHooks Function({
        bool accountId,
        bool calendarEventsRefs,
        bool calendarSyncStatesRefs,
      })
    >;
typedef $$CalendarEventsTableCreateCompanionBuilder =
    CalendarEventsCompanion Function({
      required String id,
      required String accountId,
      required String calendarSourceId,
      required String provider,
      required String providerCalendarId,
      required String providerEventId,
      Value<String?> providerRecurringEventId,
      Value<String?> providerOriginalStartKey,
      Value<String?> etagOrChangeKey,
      Value<String?> status,
      required String title,
      Value<String?> description,
      Value<String?> location,
      Value<bool> allDay,
      Value<String?> startDate,
      Value<String?> startDateTime,
      Value<String?> startTimeZone,
      Value<String?> endDate,
      Value<String?> endDateTime,
      Value<String?> endTimeZone,
      Value<String?> recurrenceJson,
      Value<String?> remindersJson,
      Value<String?> attendeesJson,
      Value<String?> categoriesJson,
      Value<String?> organizerJson,
      Value<String?> creatorJson,
      Value<String?> colorId,
      Value<String?> colorHex,
      Value<String?> visibility,
      Value<String?> transparencyOrShowAs,
      Value<String?> eventType,
      Value<String?> webLink,
      Value<String?> conferenceJson,
      Value<String?> attachmentsJson,
      Value<bool> isCancelled,
      Value<bool> isDeleted,
      Value<String?> rawJson,
      Value<String?> createdAtServer,
      Value<String?> updatedAtServer,
      required int createdAtLocal,
      required int updatedAtLocal,
      Value<String> syncStatus,
      Value<String?> baselineRawJson,
      Value<int> rowid,
    });
typedef $$CalendarEventsTableUpdateCompanionBuilder =
    CalendarEventsCompanion Function({
      Value<String> id,
      Value<String> accountId,
      Value<String> calendarSourceId,
      Value<String> provider,
      Value<String> providerCalendarId,
      Value<String> providerEventId,
      Value<String?> providerRecurringEventId,
      Value<String?> providerOriginalStartKey,
      Value<String?> etagOrChangeKey,
      Value<String?> status,
      Value<String> title,
      Value<String?> description,
      Value<String?> location,
      Value<bool> allDay,
      Value<String?> startDate,
      Value<String?> startDateTime,
      Value<String?> startTimeZone,
      Value<String?> endDate,
      Value<String?> endDateTime,
      Value<String?> endTimeZone,
      Value<String?> recurrenceJson,
      Value<String?> remindersJson,
      Value<String?> attendeesJson,
      Value<String?> categoriesJson,
      Value<String?> organizerJson,
      Value<String?> creatorJson,
      Value<String?> colorId,
      Value<String?> colorHex,
      Value<String?> visibility,
      Value<String?> transparencyOrShowAs,
      Value<String?> eventType,
      Value<String?> webLink,
      Value<String?> conferenceJson,
      Value<String?> attachmentsJson,
      Value<bool> isCancelled,
      Value<bool> isDeleted,
      Value<String?> rawJson,
      Value<String?> createdAtServer,
      Value<String?> updatedAtServer,
      Value<int> createdAtLocal,
      Value<int> updatedAtLocal,
      Value<String> syncStatus,
      Value<String?> baselineRawJson,
      Value<int> rowid,
    });

final class $$CalendarEventsTableReferences
    extends BaseReferences<_$AppDatabase, $CalendarEventsTable, CalendarEvent> {
  $$CalendarEventsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $AccountsTable _accountIdTable(_$AppDatabase db) =>
      db.accounts.createAlias(
        $_aliasNameGenerator(db.calendarEvents.accountId, db.accounts.id),
      );

  $$AccountsTableProcessedTableManager get accountId {
    final $_column = $_itemColumn<String>('account_id')!;

    final manager = $$AccountsTableTableManager(
      $_db,
      $_db.accounts,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_accountIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $CalendarSourcesTable _calendarSourceIdTable(_$AppDatabase db) =>
      db.calendarSources.createAlias(
        $_aliasNameGenerator(
          db.calendarEvents.calendarSourceId,
          db.calendarSources.id,
        ),
      );

  $$CalendarSourcesTableProcessedTableManager get calendarSourceId {
    final $_column = $_itemColumn<String>('calendar_source_id')!;

    final manager = $$CalendarSourcesTableTableManager(
      $_db,
      $_db.calendarSources,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_calendarSourceIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<
    $CalendarEventAttendeesTable,
    List<CalendarEventAttendee>
  >
  _calendarEventAttendeesRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.calendarEventAttendees,
        aliasName: $_aliasNameGenerator(
          db.calendarEvents.id,
          db.calendarEventAttendees.calendarEventId,
        ),
      );

  $$CalendarEventAttendeesTableProcessedTableManager
  get calendarEventAttendeesRefs {
    final manager =
        $$CalendarEventAttendeesTableTableManager(
          $_db,
          $_db.calendarEventAttendees,
        ).filter(
          (f) => f.calendarEventId.id.sqlEquals($_itemColumn<String>('id')!),
        );

    final cache = $_typedResult.readTableOrNull(
      _calendarEventAttendeesRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<
    $CalendarEventRemindersTable,
    List<CalendarEventReminder>
  >
  _calendarEventRemindersRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.calendarEventReminders,
        aliasName: $_aliasNameGenerator(
          db.calendarEvents.id,
          db.calendarEventReminders.calendarEventId,
        ),
      );

  $$CalendarEventRemindersTableProcessedTableManager
  get calendarEventRemindersRefs {
    final manager =
        $$CalendarEventRemindersTableTableManager(
          $_db,
          $_db.calendarEventReminders,
        ).filter(
          (f) => f.calendarEventId.id.sqlEquals($_itemColumn<String>('id')!),
        );

    final cache = $_typedResult.readTableOrNull(
      _calendarEventRemindersRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$CalendarEventsTableFilterComposer
    extends Composer<_$AppDatabase, $CalendarEventsTable> {
  $$CalendarEventsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get provider => $composableBuilder(
    column: $table.provider,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get providerCalendarId => $composableBuilder(
    column: $table.providerCalendarId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get providerEventId => $composableBuilder(
    column: $table.providerEventId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get providerRecurringEventId => $composableBuilder(
    column: $table.providerRecurringEventId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get providerOriginalStartKey => $composableBuilder(
    column: $table.providerOriginalStartKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get etagOrChangeKey => $composableBuilder(
    column: $table.etagOrChangeKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get location => $composableBuilder(
    column: $table.location,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get allDay => $composableBuilder(
    column: $table.allDay,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get startDate => $composableBuilder(
    column: $table.startDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get startDateTime => $composableBuilder(
    column: $table.startDateTime,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get startTimeZone => $composableBuilder(
    column: $table.startTimeZone,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get endDate => $composableBuilder(
    column: $table.endDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get endDateTime => $composableBuilder(
    column: $table.endDateTime,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get endTimeZone => $composableBuilder(
    column: $table.endTimeZone,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get recurrenceJson => $composableBuilder(
    column: $table.recurrenceJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get remindersJson => $composableBuilder(
    column: $table.remindersJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get attendeesJson => $composableBuilder(
    column: $table.attendeesJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get categoriesJson => $composableBuilder(
    column: $table.categoriesJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get organizerJson => $composableBuilder(
    column: $table.organizerJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get creatorJson => $composableBuilder(
    column: $table.creatorJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get colorId => $composableBuilder(
    column: $table.colorId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get colorHex => $composableBuilder(
    column: $table.colorHex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get visibility => $composableBuilder(
    column: $table.visibility,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get transparencyOrShowAs => $composableBuilder(
    column: $table.transparencyOrShowAs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get eventType => $composableBuilder(
    column: $table.eventType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get webLink => $composableBuilder(
    column: $table.webLink,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get conferenceJson => $composableBuilder(
    column: $table.conferenceJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get attachmentsJson => $composableBuilder(
    column: $table.attachmentsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isCancelled => $composableBuilder(
    column: $table.isCancelled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get rawJson => $composableBuilder(
    column: $table.rawJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdAtServer => $composableBuilder(
    column: $table.createdAtServer,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get updatedAtServer => $composableBuilder(
    column: $table.updatedAtServer,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAtLocal => $composableBuilder(
    column: $table.createdAtLocal,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAtLocal => $composableBuilder(
    column: $table.updatedAtLocal,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get baselineRawJson => $composableBuilder(
    column: $table.baselineRawJson,
    builder: (column) => ColumnFilters(column),
  );

  $$AccountsTableFilterComposer get accountId {
    final $$AccountsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.accountId,
      referencedTable: $db.accounts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AccountsTableFilterComposer(
            $db: $db,
            $table: $db.accounts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$CalendarSourcesTableFilterComposer get calendarSourceId {
    final $$CalendarSourcesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.calendarSourceId,
      referencedTable: $db.calendarSources,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CalendarSourcesTableFilterComposer(
            $db: $db,
            $table: $db.calendarSources,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> calendarEventAttendeesRefs(
    Expression<bool> Function($$CalendarEventAttendeesTableFilterComposer f) f,
  ) {
    final $$CalendarEventAttendeesTableFilterComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.calendarEventAttendees,
          getReferencedColumn: (t) => t.calendarEventId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$CalendarEventAttendeesTableFilterComposer(
                $db: $db,
                $table: $db.calendarEventAttendees,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<bool> calendarEventRemindersRefs(
    Expression<bool> Function($$CalendarEventRemindersTableFilterComposer f) f,
  ) {
    final $$CalendarEventRemindersTableFilterComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.calendarEventReminders,
          getReferencedColumn: (t) => t.calendarEventId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$CalendarEventRemindersTableFilterComposer(
                $db: $db,
                $table: $db.calendarEventReminders,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$CalendarEventsTableOrderingComposer
    extends Composer<_$AppDatabase, $CalendarEventsTable> {
  $$CalendarEventsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get provider => $composableBuilder(
    column: $table.provider,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get providerCalendarId => $composableBuilder(
    column: $table.providerCalendarId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get providerEventId => $composableBuilder(
    column: $table.providerEventId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get providerRecurringEventId => $composableBuilder(
    column: $table.providerRecurringEventId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get providerOriginalStartKey => $composableBuilder(
    column: $table.providerOriginalStartKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get etagOrChangeKey => $composableBuilder(
    column: $table.etagOrChangeKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get location => $composableBuilder(
    column: $table.location,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get allDay => $composableBuilder(
    column: $table.allDay,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get startDate => $composableBuilder(
    column: $table.startDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get startDateTime => $composableBuilder(
    column: $table.startDateTime,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get startTimeZone => $composableBuilder(
    column: $table.startTimeZone,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get endDate => $composableBuilder(
    column: $table.endDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get endDateTime => $composableBuilder(
    column: $table.endDateTime,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get endTimeZone => $composableBuilder(
    column: $table.endTimeZone,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get recurrenceJson => $composableBuilder(
    column: $table.recurrenceJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get remindersJson => $composableBuilder(
    column: $table.remindersJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get attendeesJson => $composableBuilder(
    column: $table.attendeesJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get categoriesJson => $composableBuilder(
    column: $table.categoriesJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get organizerJson => $composableBuilder(
    column: $table.organizerJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get creatorJson => $composableBuilder(
    column: $table.creatorJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get colorId => $composableBuilder(
    column: $table.colorId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get colorHex => $composableBuilder(
    column: $table.colorHex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get visibility => $composableBuilder(
    column: $table.visibility,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get transparencyOrShowAs => $composableBuilder(
    column: $table.transparencyOrShowAs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get eventType => $composableBuilder(
    column: $table.eventType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get webLink => $composableBuilder(
    column: $table.webLink,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get conferenceJson => $composableBuilder(
    column: $table.conferenceJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get attachmentsJson => $composableBuilder(
    column: $table.attachmentsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isCancelled => $composableBuilder(
    column: $table.isCancelled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get rawJson => $composableBuilder(
    column: $table.rawJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdAtServer => $composableBuilder(
    column: $table.createdAtServer,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get updatedAtServer => $composableBuilder(
    column: $table.updatedAtServer,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAtLocal => $composableBuilder(
    column: $table.createdAtLocal,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAtLocal => $composableBuilder(
    column: $table.updatedAtLocal,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get baselineRawJson => $composableBuilder(
    column: $table.baselineRawJson,
    builder: (column) => ColumnOrderings(column),
  );

  $$AccountsTableOrderingComposer get accountId {
    final $$AccountsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.accountId,
      referencedTable: $db.accounts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AccountsTableOrderingComposer(
            $db: $db,
            $table: $db.accounts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$CalendarSourcesTableOrderingComposer get calendarSourceId {
    final $$CalendarSourcesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.calendarSourceId,
      referencedTable: $db.calendarSources,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CalendarSourcesTableOrderingComposer(
            $db: $db,
            $table: $db.calendarSources,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CalendarEventsTableAnnotationComposer
    extends Composer<_$AppDatabase, $CalendarEventsTable> {
  $$CalendarEventsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get provider =>
      $composableBuilder(column: $table.provider, builder: (column) => column);

  GeneratedColumn<String> get providerCalendarId => $composableBuilder(
    column: $table.providerCalendarId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get providerEventId => $composableBuilder(
    column: $table.providerEventId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get providerRecurringEventId => $composableBuilder(
    column: $table.providerRecurringEventId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get providerOriginalStartKey => $composableBuilder(
    column: $table.providerOriginalStartKey,
    builder: (column) => column,
  );

  GeneratedColumn<String> get etagOrChangeKey => $composableBuilder(
    column: $table.etagOrChangeKey,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<String> get location =>
      $composableBuilder(column: $table.location, builder: (column) => column);

  GeneratedColumn<bool> get allDay =>
      $composableBuilder(column: $table.allDay, builder: (column) => column);

  GeneratedColumn<String> get startDate =>
      $composableBuilder(column: $table.startDate, builder: (column) => column);

  GeneratedColumn<String> get startDateTime => $composableBuilder(
    column: $table.startDateTime,
    builder: (column) => column,
  );

  GeneratedColumn<String> get startTimeZone => $composableBuilder(
    column: $table.startTimeZone,
    builder: (column) => column,
  );

  GeneratedColumn<String> get endDate =>
      $composableBuilder(column: $table.endDate, builder: (column) => column);

  GeneratedColumn<String> get endDateTime => $composableBuilder(
    column: $table.endDateTime,
    builder: (column) => column,
  );

  GeneratedColumn<String> get endTimeZone => $composableBuilder(
    column: $table.endTimeZone,
    builder: (column) => column,
  );

  GeneratedColumn<String> get recurrenceJson => $composableBuilder(
    column: $table.recurrenceJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get remindersJson => $composableBuilder(
    column: $table.remindersJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get attendeesJson => $composableBuilder(
    column: $table.attendeesJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get categoriesJson => $composableBuilder(
    column: $table.categoriesJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get organizerJson => $composableBuilder(
    column: $table.organizerJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get creatorJson => $composableBuilder(
    column: $table.creatorJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get colorId =>
      $composableBuilder(column: $table.colorId, builder: (column) => column);

  GeneratedColumn<String> get colorHex =>
      $composableBuilder(column: $table.colorHex, builder: (column) => column);

  GeneratedColumn<String> get visibility => $composableBuilder(
    column: $table.visibility,
    builder: (column) => column,
  );

  GeneratedColumn<String> get transparencyOrShowAs => $composableBuilder(
    column: $table.transparencyOrShowAs,
    builder: (column) => column,
  );

  GeneratedColumn<String> get eventType =>
      $composableBuilder(column: $table.eventType, builder: (column) => column);

  GeneratedColumn<String> get webLink =>
      $composableBuilder(column: $table.webLink, builder: (column) => column);

  GeneratedColumn<String> get conferenceJson => $composableBuilder(
    column: $table.conferenceJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get attachmentsJson => $composableBuilder(
    column: $table.attachmentsJson,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isCancelled => $composableBuilder(
    column: $table.isCancelled,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isDeleted =>
      $composableBuilder(column: $table.isDeleted, builder: (column) => column);

  GeneratedColumn<String> get rawJson =>
      $composableBuilder(column: $table.rawJson, builder: (column) => column);

  GeneratedColumn<String> get createdAtServer => $composableBuilder(
    column: $table.createdAtServer,
    builder: (column) => column,
  );

  GeneratedColumn<String> get updatedAtServer => $composableBuilder(
    column: $table.updatedAtServer,
    builder: (column) => column,
  );

  GeneratedColumn<int> get createdAtLocal => $composableBuilder(
    column: $table.createdAtLocal,
    builder: (column) => column,
  );

  GeneratedColumn<int> get updatedAtLocal => $composableBuilder(
    column: $table.updatedAtLocal,
    builder: (column) => column,
  );

  GeneratedColumn<String> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => column,
  );

  GeneratedColumn<String> get baselineRawJson => $composableBuilder(
    column: $table.baselineRawJson,
    builder: (column) => column,
  );

  $$AccountsTableAnnotationComposer get accountId {
    final $$AccountsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.accountId,
      referencedTable: $db.accounts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AccountsTableAnnotationComposer(
            $db: $db,
            $table: $db.accounts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$CalendarSourcesTableAnnotationComposer get calendarSourceId {
    final $$CalendarSourcesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.calendarSourceId,
      referencedTable: $db.calendarSources,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CalendarSourcesTableAnnotationComposer(
            $db: $db,
            $table: $db.calendarSources,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> calendarEventAttendeesRefs<T extends Object>(
    Expression<T> Function($$CalendarEventAttendeesTableAnnotationComposer a) f,
  ) {
    final $$CalendarEventAttendeesTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.calendarEventAttendees,
          getReferencedColumn: (t) => t.calendarEventId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$CalendarEventAttendeesTableAnnotationComposer(
                $db: $db,
                $table: $db.calendarEventAttendees,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<T> calendarEventRemindersRefs<T extends Object>(
    Expression<T> Function($$CalendarEventRemindersTableAnnotationComposer a) f,
  ) {
    final $$CalendarEventRemindersTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.calendarEventReminders,
          getReferencedColumn: (t) => t.calendarEventId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$CalendarEventRemindersTableAnnotationComposer(
                $db: $db,
                $table: $db.calendarEventReminders,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$CalendarEventsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CalendarEventsTable,
          CalendarEvent,
          $$CalendarEventsTableFilterComposer,
          $$CalendarEventsTableOrderingComposer,
          $$CalendarEventsTableAnnotationComposer,
          $$CalendarEventsTableCreateCompanionBuilder,
          $$CalendarEventsTableUpdateCompanionBuilder,
          (CalendarEvent, $$CalendarEventsTableReferences),
          CalendarEvent,
          PrefetchHooks Function({
            bool accountId,
            bool calendarSourceId,
            bool calendarEventAttendeesRefs,
            bool calendarEventRemindersRefs,
          })
        > {
  $$CalendarEventsTableTableManager(
    _$AppDatabase db,
    $CalendarEventsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CalendarEventsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CalendarEventsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CalendarEventsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> accountId = const Value.absent(),
                Value<String> calendarSourceId = const Value.absent(),
                Value<String> provider = const Value.absent(),
                Value<String> providerCalendarId = const Value.absent(),
                Value<String> providerEventId = const Value.absent(),
                Value<String?> providerRecurringEventId = const Value.absent(),
                Value<String?> providerOriginalStartKey = const Value.absent(),
                Value<String?> etagOrChangeKey = const Value.absent(),
                Value<String?> status = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<String?> location = const Value.absent(),
                Value<bool> allDay = const Value.absent(),
                Value<String?> startDate = const Value.absent(),
                Value<String?> startDateTime = const Value.absent(),
                Value<String?> startTimeZone = const Value.absent(),
                Value<String?> endDate = const Value.absent(),
                Value<String?> endDateTime = const Value.absent(),
                Value<String?> endTimeZone = const Value.absent(),
                Value<String?> recurrenceJson = const Value.absent(),
                Value<String?> remindersJson = const Value.absent(),
                Value<String?> attendeesJson = const Value.absent(),
                Value<String?> categoriesJson = const Value.absent(),
                Value<String?> organizerJson = const Value.absent(),
                Value<String?> creatorJson = const Value.absent(),
                Value<String?> colorId = const Value.absent(),
                Value<String?> colorHex = const Value.absent(),
                Value<String?> visibility = const Value.absent(),
                Value<String?> transparencyOrShowAs = const Value.absent(),
                Value<String?> eventType = const Value.absent(),
                Value<String?> webLink = const Value.absent(),
                Value<String?> conferenceJson = const Value.absent(),
                Value<String?> attachmentsJson = const Value.absent(),
                Value<bool> isCancelled = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
                Value<String?> rawJson = const Value.absent(),
                Value<String?> createdAtServer = const Value.absent(),
                Value<String?> updatedAtServer = const Value.absent(),
                Value<int> createdAtLocal = const Value.absent(),
                Value<int> updatedAtLocal = const Value.absent(),
                Value<String> syncStatus = const Value.absent(),
                Value<String?> baselineRawJson = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CalendarEventsCompanion(
                id: id,
                accountId: accountId,
                calendarSourceId: calendarSourceId,
                provider: provider,
                providerCalendarId: providerCalendarId,
                providerEventId: providerEventId,
                providerRecurringEventId: providerRecurringEventId,
                providerOriginalStartKey: providerOriginalStartKey,
                etagOrChangeKey: etagOrChangeKey,
                status: status,
                title: title,
                description: description,
                location: location,
                allDay: allDay,
                startDate: startDate,
                startDateTime: startDateTime,
                startTimeZone: startTimeZone,
                endDate: endDate,
                endDateTime: endDateTime,
                endTimeZone: endTimeZone,
                recurrenceJson: recurrenceJson,
                remindersJson: remindersJson,
                attendeesJson: attendeesJson,
                categoriesJson: categoriesJson,
                organizerJson: organizerJson,
                creatorJson: creatorJson,
                colorId: colorId,
                colorHex: colorHex,
                visibility: visibility,
                transparencyOrShowAs: transparencyOrShowAs,
                eventType: eventType,
                webLink: webLink,
                conferenceJson: conferenceJson,
                attachmentsJson: attachmentsJson,
                isCancelled: isCancelled,
                isDeleted: isDeleted,
                rawJson: rawJson,
                createdAtServer: createdAtServer,
                updatedAtServer: updatedAtServer,
                createdAtLocal: createdAtLocal,
                updatedAtLocal: updatedAtLocal,
                syncStatus: syncStatus,
                baselineRawJson: baselineRawJson,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String accountId,
                required String calendarSourceId,
                required String provider,
                required String providerCalendarId,
                required String providerEventId,
                Value<String?> providerRecurringEventId = const Value.absent(),
                Value<String?> providerOriginalStartKey = const Value.absent(),
                Value<String?> etagOrChangeKey = const Value.absent(),
                Value<String?> status = const Value.absent(),
                required String title,
                Value<String?> description = const Value.absent(),
                Value<String?> location = const Value.absent(),
                Value<bool> allDay = const Value.absent(),
                Value<String?> startDate = const Value.absent(),
                Value<String?> startDateTime = const Value.absent(),
                Value<String?> startTimeZone = const Value.absent(),
                Value<String?> endDate = const Value.absent(),
                Value<String?> endDateTime = const Value.absent(),
                Value<String?> endTimeZone = const Value.absent(),
                Value<String?> recurrenceJson = const Value.absent(),
                Value<String?> remindersJson = const Value.absent(),
                Value<String?> attendeesJson = const Value.absent(),
                Value<String?> categoriesJson = const Value.absent(),
                Value<String?> organizerJson = const Value.absent(),
                Value<String?> creatorJson = const Value.absent(),
                Value<String?> colorId = const Value.absent(),
                Value<String?> colorHex = const Value.absent(),
                Value<String?> visibility = const Value.absent(),
                Value<String?> transparencyOrShowAs = const Value.absent(),
                Value<String?> eventType = const Value.absent(),
                Value<String?> webLink = const Value.absent(),
                Value<String?> conferenceJson = const Value.absent(),
                Value<String?> attachmentsJson = const Value.absent(),
                Value<bool> isCancelled = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
                Value<String?> rawJson = const Value.absent(),
                Value<String?> createdAtServer = const Value.absent(),
                Value<String?> updatedAtServer = const Value.absent(),
                required int createdAtLocal,
                required int updatedAtLocal,
                Value<String> syncStatus = const Value.absent(),
                Value<String?> baselineRawJson = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CalendarEventsCompanion.insert(
                id: id,
                accountId: accountId,
                calendarSourceId: calendarSourceId,
                provider: provider,
                providerCalendarId: providerCalendarId,
                providerEventId: providerEventId,
                providerRecurringEventId: providerRecurringEventId,
                providerOriginalStartKey: providerOriginalStartKey,
                etagOrChangeKey: etagOrChangeKey,
                status: status,
                title: title,
                description: description,
                location: location,
                allDay: allDay,
                startDate: startDate,
                startDateTime: startDateTime,
                startTimeZone: startTimeZone,
                endDate: endDate,
                endDateTime: endDateTime,
                endTimeZone: endTimeZone,
                recurrenceJson: recurrenceJson,
                remindersJson: remindersJson,
                attendeesJson: attendeesJson,
                categoriesJson: categoriesJson,
                organizerJson: organizerJson,
                creatorJson: creatorJson,
                colorId: colorId,
                colorHex: colorHex,
                visibility: visibility,
                transparencyOrShowAs: transparencyOrShowAs,
                eventType: eventType,
                webLink: webLink,
                conferenceJson: conferenceJson,
                attachmentsJson: attachmentsJson,
                isCancelled: isCancelled,
                isDeleted: isDeleted,
                rawJson: rawJson,
                createdAtServer: createdAtServer,
                updatedAtServer: updatedAtServer,
                createdAtLocal: createdAtLocal,
                updatedAtLocal: updatedAtLocal,
                syncStatus: syncStatus,
                baselineRawJson: baselineRawJson,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$CalendarEventsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                accountId = false,
                calendarSourceId = false,
                calendarEventAttendeesRefs = false,
                calendarEventRemindersRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (calendarEventAttendeesRefs) db.calendarEventAttendees,
                    if (calendarEventRemindersRefs) db.calendarEventReminders,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (accountId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.accountId,
                                    referencedTable:
                                        $$CalendarEventsTableReferences
                                            ._accountIdTable(db),
                                    referencedColumn:
                                        $$CalendarEventsTableReferences
                                            ._accountIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }
                        if (calendarSourceId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.calendarSourceId,
                                    referencedTable:
                                        $$CalendarEventsTableReferences
                                            ._calendarSourceIdTable(db),
                                    referencedColumn:
                                        $$CalendarEventsTableReferences
                                            ._calendarSourceIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (calendarEventAttendeesRefs)
                        await $_getPrefetchedData<
                          CalendarEvent,
                          $CalendarEventsTable,
                          CalendarEventAttendee
                        >(
                          currentTable: table,
                          referencedTable: $$CalendarEventsTableReferences
                              ._calendarEventAttendeesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$CalendarEventsTableReferences(
                                db,
                                table,
                                p0,
                              ).calendarEventAttendeesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.calendarEventId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (calendarEventRemindersRefs)
                        await $_getPrefetchedData<
                          CalendarEvent,
                          $CalendarEventsTable,
                          CalendarEventReminder
                        >(
                          currentTable: table,
                          referencedTable: $$CalendarEventsTableReferences
                              ._calendarEventRemindersRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$CalendarEventsTableReferences(
                                db,
                                table,
                                p0,
                              ).calendarEventRemindersRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.calendarEventId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$CalendarEventsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CalendarEventsTable,
      CalendarEvent,
      $$CalendarEventsTableFilterComposer,
      $$CalendarEventsTableOrderingComposer,
      $$CalendarEventsTableAnnotationComposer,
      $$CalendarEventsTableCreateCompanionBuilder,
      $$CalendarEventsTableUpdateCompanionBuilder,
      (CalendarEvent, $$CalendarEventsTableReferences),
      CalendarEvent,
      PrefetchHooks Function({
        bool accountId,
        bool calendarSourceId,
        bool calendarEventAttendeesRefs,
        bool calendarEventRemindersRefs,
      })
    >;
typedef $$CalendarEventAttendeesTableCreateCompanionBuilder =
    CalendarEventAttendeesCompanion Function({
      required String id,
      required String calendarEventId,
      required String email,
      Value<String?> displayName,
      Value<String?> responseStatus,
      Value<bool> optional,
      Value<bool> organizer,
      Value<bool> self,
      Value<String?> rawJson,
      Value<int> rowid,
    });
typedef $$CalendarEventAttendeesTableUpdateCompanionBuilder =
    CalendarEventAttendeesCompanion Function({
      Value<String> id,
      Value<String> calendarEventId,
      Value<String> email,
      Value<String?> displayName,
      Value<String?> responseStatus,
      Value<bool> optional,
      Value<bool> organizer,
      Value<bool> self,
      Value<String?> rawJson,
      Value<int> rowid,
    });

final class $$CalendarEventAttendeesTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $CalendarEventAttendeesTable,
          CalendarEventAttendee
        > {
  $$CalendarEventAttendeesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $CalendarEventsTable _calendarEventIdTable(_$AppDatabase db) =>
      db.calendarEvents.createAlias(
        $_aliasNameGenerator(
          db.calendarEventAttendees.calendarEventId,
          db.calendarEvents.id,
        ),
      );

  $$CalendarEventsTableProcessedTableManager get calendarEventId {
    final $_column = $_itemColumn<String>('calendar_event_id')!;

    final manager = $$CalendarEventsTableTableManager(
      $_db,
      $_db.calendarEvents,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_calendarEventIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$CalendarEventAttendeesTableFilterComposer
    extends Composer<_$AppDatabase, $CalendarEventAttendeesTable> {
  $$CalendarEventAttendeesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get email => $composableBuilder(
    column: $table.email,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get responseStatus => $composableBuilder(
    column: $table.responseStatus,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get optional => $composableBuilder(
    column: $table.optional,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get organizer => $composableBuilder(
    column: $table.organizer,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get self => $composableBuilder(
    column: $table.self,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get rawJson => $composableBuilder(
    column: $table.rawJson,
    builder: (column) => ColumnFilters(column),
  );

  $$CalendarEventsTableFilterComposer get calendarEventId {
    final $$CalendarEventsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.calendarEventId,
      referencedTable: $db.calendarEvents,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CalendarEventsTableFilterComposer(
            $db: $db,
            $table: $db.calendarEvents,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CalendarEventAttendeesTableOrderingComposer
    extends Composer<_$AppDatabase, $CalendarEventAttendeesTable> {
  $$CalendarEventAttendeesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get email => $composableBuilder(
    column: $table.email,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get responseStatus => $composableBuilder(
    column: $table.responseStatus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get optional => $composableBuilder(
    column: $table.optional,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get organizer => $composableBuilder(
    column: $table.organizer,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get self => $composableBuilder(
    column: $table.self,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get rawJson => $composableBuilder(
    column: $table.rawJson,
    builder: (column) => ColumnOrderings(column),
  );

  $$CalendarEventsTableOrderingComposer get calendarEventId {
    final $$CalendarEventsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.calendarEventId,
      referencedTable: $db.calendarEvents,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CalendarEventsTableOrderingComposer(
            $db: $db,
            $table: $db.calendarEvents,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CalendarEventAttendeesTableAnnotationComposer
    extends Composer<_$AppDatabase, $CalendarEventAttendeesTable> {
  $$CalendarEventAttendeesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get email =>
      $composableBuilder(column: $table.email, builder: (column) => column);

  GeneratedColumn<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get responseStatus => $composableBuilder(
    column: $table.responseStatus,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get optional =>
      $composableBuilder(column: $table.optional, builder: (column) => column);

  GeneratedColumn<bool> get organizer =>
      $composableBuilder(column: $table.organizer, builder: (column) => column);

  GeneratedColumn<bool> get self =>
      $composableBuilder(column: $table.self, builder: (column) => column);

  GeneratedColumn<String> get rawJson =>
      $composableBuilder(column: $table.rawJson, builder: (column) => column);

  $$CalendarEventsTableAnnotationComposer get calendarEventId {
    final $$CalendarEventsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.calendarEventId,
      referencedTable: $db.calendarEvents,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CalendarEventsTableAnnotationComposer(
            $db: $db,
            $table: $db.calendarEvents,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CalendarEventAttendeesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CalendarEventAttendeesTable,
          CalendarEventAttendee,
          $$CalendarEventAttendeesTableFilterComposer,
          $$CalendarEventAttendeesTableOrderingComposer,
          $$CalendarEventAttendeesTableAnnotationComposer,
          $$CalendarEventAttendeesTableCreateCompanionBuilder,
          $$CalendarEventAttendeesTableUpdateCompanionBuilder,
          (CalendarEventAttendee, $$CalendarEventAttendeesTableReferences),
          CalendarEventAttendee,
          PrefetchHooks Function({bool calendarEventId})
        > {
  $$CalendarEventAttendeesTableTableManager(
    _$AppDatabase db,
    $CalendarEventAttendeesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CalendarEventAttendeesTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$CalendarEventAttendeesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$CalendarEventAttendeesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> calendarEventId = const Value.absent(),
                Value<String> email = const Value.absent(),
                Value<String?> displayName = const Value.absent(),
                Value<String?> responseStatus = const Value.absent(),
                Value<bool> optional = const Value.absent(),
                Value<bool> organizer = const Value.absent(),
                Value<bool> self = const Value.absent(),
                Value<String?> rawJson = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CalendarEventAttendeesCompanion(
                id: id,
                calendarEventId: calendarEventId,
                email: email,
                displayName: displayName,
                responseStatus: responseStatus,
                optional: optional,
                organizer: organizer,
                self: self,
                rawJson: rawJson,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String calendarEventId,
                required String email,
                Value<String?> displayName = const Value.absent(),
                Value<String?> responseStatus = const Value.absent(),
                Value<bool> optional = const Value.absent(),
                Value<bool> organizer = const Value.absent(),
                Value<bool> self = const Value.absent(),
                Value<String?> rawJson = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CalendarEventAttendeesCompanion.insert(
                id: id,
                calendarEventId: calendarEventId,
                email: email,
                displayName: displayName,
                responseStatus: responseStatus,
                optional: optional,
                organizer: organizer,
                self: self,
                rawJson: rawJson,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$CalendarEventAttendeesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({calendarEventId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (calendarEventId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.calendarEventId,
                                referencedTable:
                                    $$CalendarEventAttendeesTableReferences
                                        ._calendarEventIdTable(db),
                                referencedColumn:
                                    $$CalendarEventAttendeesTableReferences
                                        ._calendarEventIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$CalendarEventAttendeesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CalendarEventAttendeesTable,
      CalendarEventAttendee,
      $$CalendarEventAttendeesTableFilterComposer,
      $$CalendarEventAttendeesTableOrderingComposer,
      $$CalendarEventAttendeesTableAnnotationComposer,
      $$CalendarEventAttendeesTableCreateCompanionBuilder,
      $$CalendarEventAttendeesTableUpdateCompanionBuilder,
      (CalendarEventAttendee, $$CalendarEventAttendeesTableReferences),
      CalendarEventAttendee,
      PrefetchHooks Function({bool calendarEventId})
    >;
typedef $$CalendarEventRemindersTableCreateCompanionBuilder =
    CalendarEventRemindersCompanion Function({
      required String id,
      required String calendarEventId,
      required String provider,
      Value<String?> method,
      Value<int?> minutesBefore,
      Value<String?> absoluteTime,
      Value<bool> enabled,
      Value<String?> rawJson,
      Value<int> rowid,
    });
typedef $$CalendarEventRemindersTableUpdateCompanionBuilder =
    CalendarEventRemindersCompanion Function({
      Value<String> id,
      Value<String> calendarEventId,
      Value<String> provider,
      Value<String?> method,
      Value<int?> minutesBefore,
      Value<String?> absoluteTime,
      Value<bool> enabled,
      Value<String?> rawJson,
      Value<int> rowid,
    });

final class $$CalendarEventRemindersTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $CalendarEventRemindersTable,
          CalendarEventReminder
        > {
  $$CalendarEventRemindersTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $CalendarEventsTable _calendarEventIdTable(_$AppDatabase db) =>
      db.calendarEvents.createAlias(
        $_aliasNameGenerator(
          db.calendarEventReminders.calendarEventId,
          db.calendarEvents.id,
        ),
      );

  $$CalendarEventsTableProcessedTableManager get calendarEventId {
    final $_column = $_itemColumn<String>('calendar_event_id')!;

    final manager = $$CalendarEventsTableTableManager(
      $_db,
      $_db.calendarEvents,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_calendarEventIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$CalendarEventRemindersTableFilterComposer
    extends Composer<_$AppDatabase, $CalendarEventRemindersTable> {
  $$CalendarEventRemindersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get provider => $composableBuilder(
    column: $table.provider,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get method => $composableBuilder(
    column: $table.method,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get minutesBefore => $composableBuilder(
    column: $table.minutesBefore,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get absoluteTime => $composableBuilder(
    column: $table.absoluteTime,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get enabled => $composableBuilder(
    column: $table.enabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get rawJson => $composableBuilder(
    column: $table.rawJson,
    builder: (column) => ColumnFilters(column),
  );

  $$CalendarEventsTableFilterComposer get calendarEventId {
    final $$CalendarEventsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.calendarEventId,
      referencedTable: $db.calendarEvents,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CalendarEventsTableFilterComposer(
            $db: $db,
            $table: $db.calendarEvents,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CalendarEventRemindersTableOrderingComposer
    extends Composer<_$AppDatabase, $CalendarEventRemindersTable> {
  $$CalendarEventRemindersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get provider => $composableBuilder(
    column: $table.provider,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get method => $composableBuilder(
    column: $table.method,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get minutesBefore => $composableBuilder(
    column: $table.minutesBefore,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get absoluteTime => $composableBuilder(
    column: $table.absoluteTime,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get enabled => $composableBuilder(
    column: $table.enabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get rawJson => $composableBuilder(
    column: $table.rawJson,
    builder: (column) => ColumnOrderings(column),
  );

  $$CalendarEventsTableOrderingComposer get calendarEventId {
    final $$CalendarEventsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.calendarEventId,
      referencedTable: $db.calendarEvents,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CalendarEventsTableOrderingComposer(
            $db: $db,
            $table: $db.calendarEvents,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CalendarEventRemindersTableAnnotationComposer
    extends Composer<_$AppDatabase, $CalendarEventRemindersTable> {
  $$CalendarEventRemindersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get provider =>
      $composableBuilder(column: $table.provider, builder: (column) => column);

  GeneratedColumn<String> get method =>
      $composableBuilder(column: $table.method, builder: (column) => column);

  GeneratedColumn<int> get minutesBefore => $composableBuilder(
    column: $table.minutesBefore,
    builder: (column) => column,
  );

  GeneratedColumn<String> get absoluteTime => $composableBuilder(
    column: $table.absoluteTime,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get enabled =>
      $composableBuilder(column: $table.enabled, builder: (column) => column);

  GeneratedColumn<String> get rawJson =>
      $composableBuilder(column: $table.rawJson, builder: (column) => column);

  $$CalendarEventsTableAnnotationComposer get calendarEventId {
    final $$CalendarEventsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.calendarEventId,
      referencedTable: $db.calendarEvents,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CalendarEventsTableAnnotationComposer(
            $db: $db,
            $table: $db.calendarEvents,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CalendarEventRemindersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CalendarEventRemindersTable,
          CalendarEventReminder,
          $$CalendarEventRemindersTableFilterComposer,
          $$CalendarEventRemindersTableOrderingComposer,
          $$CalendarEventRemindersTableAnnotationComposer,
          $$CalendarEventRemindersTableCreateCompanionBuilder,
          $$CalendarEventRemindersTableUpdateCompanionBuilder,
          (CalendarEventReminder, $$CalendarEventRemindersTableReferences),
          CalendarEventReminder,
          PrefetchHooks Function({bool calendarEventId})
        > {
  $$CalendarEventRemindersTableTableManager(
    _$AppDatabase db,
    $CalendarEventRemindersTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CalendarEventRemindersTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$CalendarEventRemindersTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$CalendarEventRemindersTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> calendarEventId = const Value.absent(),
                Value<String> provider = const Value.absent(),
                Value<String?> method = const Value.absent(),
                Value<int?> minutesBefore = const Value.absent(),
                Value<String?> absoluteTime = const Value.absent(),
                Value<bool> enabled = const Value.absent(),
                Value<String?> rawJson = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CalendarEventRemindersCompanion(
                id: id,
                calendarEventId: calendarEventId,
                provider: provider,
                method: method,
                minutesBefore: minutesBefore,
                absoluteTime: absoluteTime,
                enabled: enabled,
                rawJson: rawJson,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String calendarEventId,
                required String provider,
                Value<String?> method = const Value.absent(),
                Value<int?> minutesBefore = const Value.absent(),
                Value<String?> absoluteTime = const Value.absent(),
                Value<bool> enabled = const Value.absent(),
                Value<String?> rawJson = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CalendarEventRemindersCompanion.insert(
                id: id,
                calendarEventId: calendarEventId,
                provider: provider,
                method: method,
                minutesBefore: minutesBefore,
                absoluteTime: absoluteTime,
                enabled: enabled,
                rawJson: rawJson,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$CalendarEventRemindersTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({calendarEventId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (calendarEventId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.calendarEventId,
                                referencedTable:
                                    $$CalendarEventRemindersTableReferences
                                        ._calendarEventIdTable(db),
                                referencedColumn:
                                    $$CalendarEventRemindersTableReferences
                                        ._calendarEventIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$CalendarEventRemindersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CalendarEventRemindersTable,
      CalendarEventReminder,
      $$CalendarEventRemindersTableFilterComposer,
      $$CalendarEventRemindersTableOrderingComposer,
      $$CalendarEventRemindersTableAnnotationComposer,
      $$CalendarEventRemindersTableCreateCompanionBuilder,
      $$CalendarEventRemindersTableUpdateCompanionBuilder,
      (CalendarEventReminder, $$CalendarEventRemindersTableReferences),
      CalendarEventReminder,
      PrefetchHooks Function({bool calendarEventId})
    >;
typedef $$CalendarSyncStatesTableCreateCompanionBuilder =
    CalendarSyncStatesCompanion Function({
      required String id,
      required String accountId,
      Value<String?> calendarSourceId,
      required String provider,
      required String syncKind,
      Value<String?> rangeStart,
      Value<String?> rangeEnd,
      Value<String?> googleSyncToken,
      Value<String?> microsoftDeltaLink,
      Value<int?> lastFullSyncAt,
      Value<int?> lastIncrementalSyncAt,
      Value<String?> lastError,
      Value<String?> rawStateJson,
      Value<int> rowid,
    });
typedef $$CalendarSyncStatesTableUpdateCompanionBuilder =
    CalendarSyncStatesCompanion Function({
      Value<String> id,
      Value<String> accountId,
      Value<String?> calendarSourceId,
      Value<String> provider,
      Value<String> syncKind,
      Value<String?> rangeStart,
      Value<String?> rangeEnd,
      Value<String?> googleSyncToken,
      Value<String?> microsoftDeltaLink,
      Value<int?> lastFullSyncAt,
      Value<int?> lastIncrementalSyncAt,
      Value<String?> lastError,
      Value<String?> rawStateJson,
      Value<int> rowid,
    });

final class $$CalendarSyncStatesTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $CalendarSyncStatesTable,
          CalendarSyncState
        > {
  $$CalendarSyncStatesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $AccountsTable _accountIdTable(_$AppDatabase db) =>
      db.accounts.createAlias(
        $_aliasNameGenerator(db.calendarSyncStates.accountId, db.accounts.id),
      );

  $$AccountsTableProcessedTableManager get accountId {
    final $_column = $_itemColumn<String>('account_id')!;

    final manager = $$AccountsTableTableManager(
      $_db,
      $_db.accounts,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_accountIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $CalendarSourcesTable _calendarSourceIdTable(_$AppDatabase db) =>
      db.calendarSources.createAlias(
        $_aliasNameGenerator(
          db.calendarSyncStates.calendarSourceId,
          db.calendarSources.id,
        ),
      );

  $$CalendarSourcesTableProcessedTableManager? get calendarSourceId {
    final $_column = $_itemColumn<String>('calendar_source_id');
    if ($_column == null) return null;
    final manager = $$CalendarSourcesTableTableManager(
      $_db,
      $_db.calendarSources,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_calendarSourceIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$CalendarSyncStatesTableFilterComposer
    extends Composer<_$AppDatabase, $CalendarSyncStatesTable> {
  $$CalendarSyncStatesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get provider => $composableBuilder(
    column: $table.provider,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get syncKind => $composableBuilder(
    column: $table.syncKind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get rangeStart => $composableBuilder(
    column: $table.rangeStart,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get rangeEnd => $composableBuilder(
    column: $table.rangeEnd,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get googleSyncToken => $composableBuilder(
    column: $table.googleSyncToken,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get microsoftDeltaLink => $composableBuilder(
    column: $table.microsoftDeltaLink,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastFullSyncAt => $composableBuilder(
    column: $table.lastFullSyncAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastIncrementalSyncAt => $composableBuilder(
    column: $table.lastIncrementalSyncAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get rawStateJson => $composableBuilder(
    column: $table.rawStateJson,
    builder: (column) => ColumnFilters(column),
  );

  $$AccountsTableFilterComposer get accountId {
    final $$AccountsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.accountId,
      referencedTable: $db.accounts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AccountsTableFilterComposer(
            $db: $db,
            $table: $db.accounts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$CalendarSourcesTableFilterComposer get calendarSourceId {
    final $$CalendarSourcesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.calendarSourceId,
      referencedTable: $db.calendarSources,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CalendarSourcesTableFilterComposer(
            $db: $db,
            $table: $db.calendarSources,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CalendarSyncStatesTableOrderingComposer
    extends Composer<_$AppDatabase, $CalendarSyncStatesTable> {
  $$CalendarSyncStatesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get provider => $composableBuilder(
    column: $table.provider,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get syncKind => $composableBuilder(
    column: $table.syncKind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get rangeStart => $composableBuilder(
    column: $table.rangeStart,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get rangeEnd => $composableBuilder(
    column: $table.rangeEnd,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get googleSyncToken => $composableBuilder(
    column: $table.googleSyncToken,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get microsoftDeltaLink => $composableBuilder(
    column: $table.microsoftDeltaLink,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastFullSyncAt => $composableBuilder(
    column: $table.lastFullSyncAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastIncrementalSyncAt => $composableBuilder(
    column: $table.lastIncrementalSyncAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get rawStateJson => $composableBuilder(
    column: $table.rawStateJson,
    builder: (column) => ColumnOrderings(column),
  );

  $$AccountsTableOrderingComposer get accountId {
    final $$AccountsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.accountId,
      referencedTable: $db.accounts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AccountsTableOrderingComposer(
            $db: $db,
            $table: $db.accounts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$CalendarSourcesTableOrderingComposer get calendarSourceId {
    final $$CalendarSourcesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.calendarSourceId,
      referencedTable: $db.calendarSources,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CalendarSourcesTableOrderingComposer(
            $db: $db,
            $table: $db.calendarSources,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CalendarSyncStatesTableAnnotationComposer
    extends Composer<_$AppDatabase, $CalendarSyncStatesTable> {
  $$CalendarSyncStatesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get provider =>
      $composableBuilder(column: $table.provider, builder: (column) => column);

  GeneratedColumn<String> get syncKind =>
      $composableBuilder(column: $table.syncKind, builder: (column) => column);

  GeneratedColumn<String> get rangeStart => $composableBuilder(
    column: $table.rangeStart,
    builder: (column) => column,
  );

  GeneratedColumn<String> get rangeEnd =>
      $composableBuilder(column: $table.rangeEnd, builder: (column) => column);

  GeneratedColumn<String> get googleSyncToken => $composableBuilder(
    column: $table.googleSyncToken,
    builder: (column) => column,
  );

  GeneratedColumn<String> get microsoftDeltaLink => $composableBuilder(
    column: $table.microsoftDeltaLink,
    builder: (column) => column,
  );

  GeneratedColumn<int> get lastFullSyncAt => $composableBuilder(
    column: $table.lastFullSyncAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get lastIncrementalSyncAt => $composableBuilder(
    column: $table.lastIncrementalSyncAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lastError =>
      $composableBuilder(column: $table.lastError, builder: (column) => column);

  GeneratedColumn<String> get rawStateJson => $composableBuilder(
    column: $table.rawStateJson,
    builder: (column) => column,
  );

  $$AccountsTableAnnotationComposer get accountId {
    final $$AccountsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.accountId,
      referencedTable: $db.accounts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AccountsTableAnnotationComposer(
            $db: $db,
            $table: $db.accounts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$CalendarSourcesTableAnnotationComposer get calendarSourceId {
    final $$CalendarSourcesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.calendarSourceId,
      referencedTable: $db.calendarSources,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CalendarSourcesTableAnnotationComposer(
            $db: $db,
            $table: $db.calendarSources,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CalendarSyncStatesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CalendarSyncStatesTable,
          CalendarSyncState,
          $$CalendarSyncStatesTableFilterComposer,
          $$CalendarSyncStatesTableOrderingComposer,
          $$CalendarSyncStatesTableAnnotationComposer,
          $$CalendarSyncStatesTableCreateCompanionBuilder,
          $$CalendarSyncStatesTableUpdateCompanionBuilder,
          (CalendarSyncState, $$CalendarSyncStatesTableReferences),
          CalendarSyncState,
          PrefetchHooks Function({bool accountId, bool calendarSourceId})
        > {
  $$CalendarSyncStatesTableTableManager(
    _$AppDatabase db,
    $CalendarSyncStatesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CalendarSyncStatesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CalendarSyncStatesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CalendarSyncStatesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> accountId = const Value.absent(),
                Value<String?> calendarSourceId = const Value.absent(),
                Value<String> provider = const Value.absent(),
                Value<String> syncKind = const Value.absent(),
                Value<String?> rangeStart = const Value.absent(),
                Value<String?> rangeEnd = const Value.absent(),
                Value<String?> googleSyncToken = const Value.absent(),
                Value<String?> microsoftDeltaLink = const Value.absent(),
                Value<int?> lastFullSyncAt = const Value.absent(),
                Value<int?> lastIncrementalSyncAt = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
                Value<String?> rawStateJson = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CalendarSyncStatesCompanion(
                id: id,
                accountId: accountId,
                calendarSourceId: calendarSourceId,
                provider: provider,
                syncKind: syncKind,
                rangeStart: rangeStart,
                rangeEnd: rangeEnd,
                googleSyncToken: googleSyncToken,
                microsoftDeltaLink: microsoftDeltaLink,
                lastFullSyncAt: lastFullSyncAt,
                lastIncrementalSyncAt: lastIncrementalSyncAt,
                lastError: lastError,
                rawStateJson: rawStateJson,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String accountId,
                Value<String?> calendarSourceId = const Value.absent(),
                required String provider,
                required String syncKind,
                Value<String?> rangeStart = const Value.absent(),
                Value<String?> rangeEnd = const Value.absent(),
                Value<String?> googleSyncToken = const Value.absent(),
                Value<String?> microsoftDeltaLink = const Value.absent(),
                Value<int?> lastFullSyncAt = const Value.absent(),
                Value<int?> lastIncrementalSyncAt = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
                Value<String?> rawStateJson = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CalendarSyncStatesCompanion.insert(
                id: id,
                accountId: accountId,
                calendarSourceId: calendarSourceId,
                provider: provider,
                syncKind: syncKind,
                rangeStart: rangeStart,
                rangeEnd: rangeEnd,
                googleSyncToken: googleSyncToken,
                microsoftDeltaLink: microsoftDeltaLink,
                lastFullSyncAt: lastFullSyncAt,
                lastIncrementalSyncAt: lastIncrementalSyncAt,
                lastError: lastError,
                rawStateJson: rawStateJson,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$CalendarSyncStatesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({accountId = false, calendarSourceId = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (accountId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.accountId,
                                    referencedTable:
                                        $$CalendarSyncStatesTableReferences
                                            ._accountIdTable(db),
                                    referencedColumn:
                                        $$CalendarSyncStatesTableReferences
                                            ._accountIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }
                        if (calendarSourceId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.calendarSourceId,
                                    referencedTable:
                                        $$CalendarSyncStatesTableReferences
                                            ._calendarSourceIdTable(db),
                                    referencedColumn:
                                        $$CalendarSyncStatesTableReferences
                                            ._calendarSourceIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [];
                  },
                );
              },
        ),
      );
}

typedef $$CalendarSyncStatesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CalendarSyncStatesTable,
      CalendarSyncState,
      $$CalendarSyncStatesTableFilterComposer,
      $$CalendarSyncStatesTableOrderingComposer,
      $$CalendarSyncStatesTableAnnotationComposer,
      $$CalendarSyncStatesTableCreateCompanionBuilder,
      $$CalendarSyncStatesTableUpdateCompanionBuilder,
      (CalendarSyncState, $$CalendarSyncStatesTableReferences),
      CalendarSyncState,
      PrefetchHooks Function({bool accountId, bool calendarSourceId})
    >;
typedef $$CalendarColorsTableCreateCompanionBuilder =
    CalendarColorsCompanion Function({
      required String provider,
      required String colorType,
      required String colorId,
      required String background,
      Value<String?> foreground,
      Value<String?> rawJson,
      Value<int> rowid,
    });
typedef $$CalendarColorsTableUpdateCompanionBuilder =
    CalendarColorsCompanion Function({
      Value<String> provider,
      Value<String> colorType,
      Value<String> colorId,
      Value<String> background,
      Value<String?> foreground,
      Value<String?> rawJson,
      Value<int> rowid,
    });

class $$CalendarColorsTableFilterComposer
    extends Composer<_$AppDatabase, $CalendarColorsTable> {
  $$CalendarColorsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get provider => $composableBuilder(
    column: $table.provider,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get colorType => $composableBuilder(
    column: $table.colorType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get colorId => $composableBuilder(
    column: $table.colorId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get background => $composableBuilder(
    column: $table.background,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get foreground => $composableBuilder(
    column: $table.foreground,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get rawJson => $composableBuilder(
    column: $table.rawJson,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CalendarColorsTableOrderingComposer
    extends Composer<_$AppDatabase, $CalendarColorsTable> {
  $$CalendarColorsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get provider => $composableBuilder(
    column: $table.provider,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get colorType => $composableBuilder(
    column: $table.colorType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get colorId => $composableBuilder(
    column: $table.colorId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get background => $composableBuilder(
    column: $table.background,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get foreground => $composableBuilder(
    column: $table.foreground,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get rawJson => $composableBuilder(
    column: $table.rawJson,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CalendarColorsTableAnnotationComposer
    extends Composer<_$AppDatabase, $CalendarColorsTable> {
  $$CalendarColorsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get provider =>
      $composableBuilder(column: $table.provider, builder: (column) => column);

  GeneratedColumn<String> get colorType =>
      $composableBuilder(column: $table.colorType, builder: (column) => column);

  GeneratedColumn<String> get colorId =>
      $composableBuilder(column: $table.colorId, builder: (column) => column);

  GeneratedColumn<String> get background => $composableBuilder(
    column: $table.background,
    builder: (column) => column,
  );

  GeneratedColumn<String> get foreground => $composableBuilder(
    column: $table.foreground,
    builder: (column) => column,
  );

  GeneratedColumn<String> get rawJson =>
      $composableBuilder(column: $table.rawJson, builder: (column) => column);
}

class $$CalendarColorsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CalendarColorsTable,
          CalendarColor,
          $$CalendarColorsTableFilterComposer,
          $$CalendarColorsTableOrderingComposer,
          $$CalendarColorsTableAnnotationComposer,
          $$CalendarColorsTableCreateCompanionBuilder,
          $$CalendarColorsTableUpdateCompanionBuilder,
          (
            CalendarColor,
            BaseReferences<_$AppDatabase, $CalendarColorsTable, CalendarColor>,
          ),
          CalendarColor,
          PrefetchHooks Function()
        > {
  $$CalendarColorsTableTableManager(
    _$AppDatabase db,
    $CalendarColorsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CalendarColorsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CalendarColorsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CalendarColorsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> provider = const Value.absent(),
                Value<String> colorType = const Value.absent(),
                Value<String> colorId = const Value.absent(),
                Value<String> background = const Value.absent(),
                Value<String?> foreground = const Value.absent(),
                Value<String?> rawJson = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CalendarColorsCompanion(
                provider: provider,
                colorType: colorType,
                colorId: colorId,
                background: background,
                foreground: foreground,
                rawJson: rawJson,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String provider,
                required String colorType,
                required String colorId,
                required String background,
                Value<String?> foreground = const Value.absent(),
                Value<String?> rawJson = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CalendarColorsCompanion.insert(
                provider: provider,
                colorType: colorType,
                colorId: colorId,
                background: background,
                foreground: foreground,
                rawJson: rawJson,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CalendarColorsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CalendarColorsTable,
      CalendarColor,
      $$CalendarColorsTableFilterComposer,
      $$CalendarColorsTableOrderingComposer,
      $$CalendarColorsTableAnnotationComposer,
      $$CalendarColorsTableCreateCompanionBuilder,
      $$CalendarColorsTableUpdateCompanionBuilder,
      (
        CalendarColor,
        BaseReferences<_$AppDatabase, $CalendarColorsTable, CalendarColor>,
      ),
      CalendarColor,
      PrefetchHooks Function()
    >;
typedef $$ScheduleItemOverridesTableCreateCompanionBuilder =
    ScheduleItemOverridesCompanion Function({
      required String id,
      required String accountId,
      required String sourceType,
      required String sourceId,
      required String overrideJson,
      required int createdAtLocal,
      required int updatedAtLocal,
      Value<int> rowid,
    });
typedef $$ScheduleItemOverridesTableUpdateCompanionBuilder =
    ScheduleItemOverridesCompanion Function({
      Value<String> id,
      Value<String> accountId,
      Value<String> sourceType,
      Value<String> sourceId,
      Value<String> overrideJson,
      Value<int> createdAtLocal,
      Value<int> updatedAtLocal,
      Value<int> rowid,
    });

final class $$ScheduleItemOverridesTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $ScheduleItemOverridesTable,
          ScheduleItemOverride
        > {
  $$ScheduleItemOverridesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $AccountsTable _accountIdTable(_$AppDatabase db) =>
      db.accounts.createAlias(
        $_aliasNameGenerator(
          db.scheduleItemOverrides.accountId,
          db.accounts.id,
        ),
      );

  $$AccountsTableProcessedTableManager get accountId {
    final $_column = $_itemColumn<String>('account_id')!;

    final manager = $$AccountsTableTableManager(
      $_db,
      $_db.accounts,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_accountIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$ScheduleItemOverridesTableFilterComposer
    extends Composer<_$AppDatabase, $ScheduleItemOverridesTable> {
  $$ScheduleItemOverridesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceType => $composableBuilder(
    column: $table.sourceType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceId => $composableBuilder(
    column: $table.sourceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get overrideJson => $composableBuilder(
    column: $table.overrideJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAtLocal => $composableBuilder(
    column: $table.createdAtLocal,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAtLocal => $composableBuilder(
    column: $table.updatedAtLocal,
    builder: (column) => ColumnFilters(column),
  );

  $$AccountsTableFilterComposer get accountId {
    final $$AccountsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.accountId,
      referencedTable: $db.accounts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AccountsTableFilterComposer(
            $db: $db,
            $table: $db.accounts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ScheduleItemOverridesTableOrderingComposer
    extends Composer<_$AppDatabase, $ScheduleItemOverridesTable> {
  $$ScheduleItemOverridesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceType => $composableBuilder(
    column: $table.sourceType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceId => $composableBuilder(
    column: $table.sourceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get overrideJson => $composableBuilder(
    column: $table.overrideJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAtLocal => $composableBuilder(
    column: $table.createdAtLocal,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAtLocal => $composableBuilder(
    column: $table.updatedAtLocal,
    builder: (column) => ColumnOrderings(column),
  );

  $$AccountsTableOrderingComposer get accountId {
    final $$AccountsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.accountId,
      referencedTable: $db.accounts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AccountsTableOrderingComposer(
            $db: $db,
            $table: $db.accounts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ScheduleItemOverridesTableAnnotationComposer
    extends Composer<_$AppDatabase, $ScheduleItemOverridesTable> {
  $$ScheduleItemOverridesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get sourceType => $composableBuilder(
    column: $table.sourceType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sourceId =>
      $composableBuilder(column: $table.sourceId, builder: (column) => column);

  GeneratedColumn<String> get overrideJson => $composableBuilder(
    column: $table.overrideJson,
    builder: (column) => column,
  );

  GeneratedColumn<int> get createdAtLocal => $composableBuilder(
    column: $table.createdAtLocal,
    builder: (column) => column,
  );

  GeneratedColumn<int> get updatedAtLocal => $composableBuilder(
    column: $table.updatedAtLocal,
    builder: (column) => column,
  );

  $$AccountsTableAnnotationComposer get accountId {
    final $$AccountsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.accountId,
      referencedTable: $db.accounts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AccountsTableAnnotationComposer(
            $db: $db,
            $table: $db.accounts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ScheduleItemOverridesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ScheduleItemOverridesTable,
          ScheduleItemOverride,
          $$ScheduleItemOverridesTableFilterComposer,
          $$ScheduleItemOverridesTableOrderingComposer,
          $$ScheduleItemOverridesTableAnnotationComposer,
          $$ScheduleItemOverridesTableCreateCompanionBuilder,
          $$ScheduleItemOverridesTableUpdateCompanionBuilder,
          (ScheduleItemOverride, $$ScheduleItemOverridesTableReferences),
          ScheduleItemOverride,
          PrefetchHooks Function({bool accountId})
        > {
  $$ScheduleItemOverridesTableTableManager(
    _$AppDatabase db,
    $ScheduleItemOverridesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ScheduleItemOverridesTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$ScheduleItemOverridesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$ScheduleItemOverridesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> accountId = const Value.absent(),
                Value<String> sourceType = const Value.absent(),
                Value<String> sourceId = const Value.absent(),
                Value<String> overrideJson = const Value.absent(),
                Value<int> createdAtLocal = const Value.absent(),
                Value<int> updatedAtLocal = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ScheduleItemOverridesCompanion(
                id: id,
                accountId: accountId,
                sourceType: sourceType,
                sourceId: sourceId,
                overrideJson: overrideJson,
                createdAtLocal: createdAtLocal,
                updatedAtLocal: updatedAtLocal,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String accountId,
                required String sourceType,
                required String sourceId,
                required String overrideJson,
                required int createdAtLocal,
                required int updatedAtLocal,
                Value<int> rowid = const Value.absent(),
              }) => ScheduleItemOverridesCompanion.insert(
                id: id,
                accountId: accountId,
                sourceType: sourceType,
                sourceId: sourceId,
                overrideJson: overrideJson,
                createdAtLocal: createdAtLocal,
                updatedAtLocal: updatedAtLocal,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$ScheduleItemOverridesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({accountId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (accountId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.accountId,
                                referencedTable:
                                    $$ScheduleItemOverridesTableReferences
                                        ._accountIdTable(db),
                                referencedColumn:
                                    $$ScheduleItemOverridesTableReferences
                                        ._accountIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$ScheduleItemOverridesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ScheduleItemOverridesTable,
      ScheduleItemOverride,
      $$ScheduleItemOverridesTableFilterComposer,
      $$ScheduleItemOverridesTableOrderingComposer,
      $$ScheduleItemOverridesTableAnnotationComposer,
      $$ScheduleItemOverridesTableCreateCompanionBuilder,
      $$ScheduleItemOverridesTableUpdateCompanionBuilder,
      (ScheduleItemOverride, $$ScheduleItemOverridesTableReferences),
      ScheduleItemOverride,
      PrefetchHooks Function({bool accountId})
    >;
typedef $$NotificationScheduleTableCreateCompanionBuilder =
    NotificationScheduleCompanion Function({
      required String id,
      required String accountId,
      required String sourceType,
      required String sourceId,
      required int scheduledAtUtc,
      required String title,
      Value<String?> body,
      Value<int?> sentAtUtc,
      Value<int?> dismissedAtUtc,
      Value<int?> snoozedUntilUtc,
      required int createdAtLocal,
      required int updatedAtLocal,
      Value<int> rowid,
    });
typedef $$NotificationScheduleTableUpdateCompanionBuilder =
    NotificationScheduleCompanion Function({
      Value<String> id,
      Value<String> accountId,
      Value<String> sourceType,
      Value<String> sourceId,
      Value<int> scheduledAtUtc,
      Value<String> title,
      Value<String?> body,
      Value<int?> sentAtUtc,
      Value<int?> dismissedAtUtc,
      Value<int?> snoozedUntilUtc,
      Value<int> createdAtLocal,
      Value<int> updatedAtLocal,
      Value<int> rowid,
    });

final class $$NotificationScheduleTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $NotificationScheduleTable,
          NotificationScheduleData
        > {
  $$NotificationScheduleTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $AccountsTable _accountIdTable(_$AppDatabase db) =>
      db.accounts.createAlias(
        $_aliasNameGenerator(db.notificationSchedule.accountId, db.accounts.id),
      );

  $$AccountsTableProcessedTableManager get accountId {
    final $_column = $_itemColumn<String>('account_id')!;

    final manager = $$AccountsTableTableManager(
      $_db,
      $_db.accounts,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_accountIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$NotificationScheduleTableFilterComposer
    extends Composer<_$AppDatabase, $NotificationScheduleTable> {
  $$NotificationScheduleTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceType => $composableBuilder(
    column: $table.sourceType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceId => $composableBuilder(
    column: $table.sourceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get scheduledAtUtc => $composableBuilder(
    column: $table.scheduledAtUtc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sentAtUtc => $composableBuilder(
    column: $table.sentAtUtc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get dismissedAtUtc => $composableBuilder(
    column: $table.dismissedAtUtc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get snoozedUntilUtc => $composableBuilder(
    column: $table.snoozedUntilUtc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAtLocal => $composableBuilder(
    column: $table.createdAtLocal,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAtLocal => $composableBuilder(
    column: $table.updatedAtLocal,
    builder: (column) => ColumnFilters(column),
  );

  $$AccountsTableFilterComposer get accountId {
    final $$AccountsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.accountId,
      referencedTable: $db.accounts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AccountsTableFilterComposer(
            $db: $db,
            $table: $db.accounts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$NotificationScheduleTableOrderingComposer
    extends Composer<_$AppDatabase, $NotificationScheduleTable> {
  $$NotificationScheduleTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceType => $composableBuilder(
    column: $table.sourceType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceId => $composableBuilder(
    column: $table.sourceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get scheduledAtUtc => $composableBuilder(
    column: $table.scheduledAtUtc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sentAtUtc => $composableBuilder(
    column: $table.sentAtUtc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get dismissedAtUtc => $composableBuilder(
    column: $table.dismissedAtUtc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get snoozedUntilUtc => $composableBuilder(
    column: $table.snoozedUntilUtc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAtLocal => $composableBuilder(
    column: $table.createdAtLocal,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAtLocal => $composableBuilder(
    column: $table.updatedAtLocal,
    builder: (column) => ColumnOrderings(column),
  );

  $$AccountsTableOrderingComposer get accountId {
    final $$AccountsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.accountId,
      referencedTable: $db.accounts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AccountsTableOrderingComposer(
            $db: $db,
            $table: $db.accounts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$NotificationScheduleTableAnnotationComposer
    extends Composer<_$AppDatabase, $NotificationScheduleTable> {
  $$NotificationScheduleTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get sourceType => $composableBuilder(
    column: $table.sourceType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sourceId =>
      $composableBuilder(column: $table.sourceId, builder: (column) => column);

  GeneratedColumn<int> get scheduledAtUtc => $composableBuilder(
    column: $table.scheduledAtUtc,
    builder: (column) => column,
  );

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get body =>
      $composableBuilder(column: $table.body, builder: (column) => column);

  GeneratedColumn<int> get sentAtUtc =>
      $composableBuilder(column: $table.sentAtUtc, builder: (column) => column);

  GeneratedColumn<int> get dismissedAtUtc => $composableBuilder(
    column: $table.dismissedAtUtc,
    builder: (column) => column,
  );

  GeneratedColumn<int> get snoozedUntilUtc => $composableBuilder(
    column: $table.snoozedUntilUtc,
    builder: (column) => column,
  );

  GeneratedColumn<int> get createdAtLocal => $composableBuilder(
    column: $table.createdAtLocal,
    builder: (column) => column,
  );

  GeneratedColumn<int> get updatedAtLocal => $composableBuilder(
    column: $table.updatedAtLocal,
    builder: (column) => column,
  );

  $$AccountsTableAnnotationComposer get accountId {
    final $$AccountsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.accountId,
      referencedTable: $db.accounts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AccountsTableAnnotationComposer(
            $db: $db,
            $table: $db.accounts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$NotificationScheduleTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $NotificationScheduleTable,
          NotificationScheduleData,
          $$NotificationScheduleTableFilterComposer,
          $$NotificationScheduleTableOrderingComposer,
          $$NotificationScheduleTableAnnotationComposer,
          $$NotificationScheduleTableCreateCompanionBuilder,
          $$NotificationScheduleTableUpdateCompanionBuilder,
          (NotificationScheduleData, $$NotificationScheduleTableReferences),
          NotificationScheduleData,
          PrefetchHooks Function({bool accountId})
        > {
  $$NotificationScheduleTableTableManager(
    _$AppDatabase db,
    $NotificationScheduleTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$NotificationScheduleTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$NotificationScheduleTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$NotificationScheduleTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> accountId = const Value.absent(),
                Value<String> sourceType = const Value.absent(),
                Value<String> sourceId = const Value.absent(),
                Value<int> scheduledAtUtc = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String?> body = const Value.absent(),
                Value<int?> sentAtUtc = const Value.absent(),
                Value<int?> dismissedAtUtc = const Value.absent(),
                Value<int?> snoozedUntilUtc = const Value.absent(),
                Value<int> createdAtLocal = const Value.absent(),
                Value<int> updatedAtLocal = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => NotificationScheduleCompanion(
                id: id,
                accountId: accountId,
                sourceType: sourceType,
                sourceId: sourceId,
                scheduledAtUtc: scheduledAtUtc,
                title: title,
                body: body,
                sentAtUtc: sentAtUtc,
                dismissedAtUtc: dismissedAtUtc,
                snoozedUntilUtc: snoozedUntilUtc,
                createdAtLocal: createdAtLocal,
                updatedAtLocal: updatedAtLocal,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String accountId,
                required String sourceType,
                required String sourceId,
                required int scheduledAtUtc,
                required String title,
                Value<String?> body = const Value.absent(),
                Value<int?> sentAtUtc = const Value.absent(),
                Value<int?> dismissedAtUtc = const Value.absent(),
                Value<int?> snoozedUntilUtc = const Value.absent(),
                required int createdAtLocal,
                required int updatedAtLocal,
                Value<int> rowid = const Value.absent(),
              }) => NotificationScheduleCompanion.insert(
                id: id,
                accountId: accountId,
                sourceType: sourceType,
                sourceId: sourceId,
                scheduledAtUtc: scheduledAtUtc,
                title: title,
                body: body,
                sentAtUtc: sentAtUtc,
                dismissedAtUtc: dismissedAtUtc,
                snoozedUntilUtc: snoozedUntilUtc,
                createdAtLocal: createdAtLocal,
                updatedAtLocal: updatedAtLocal,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$NotificationScheduleTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({accountId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (accountId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.accountId,
                                referencedTable:
                                    $$NotificationScheduleTableReferences
                                        ._accountIdTable(db),
                                referencedColumn:
                                    $$NotificationScheduleTableReferences
                                        ._accountIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$NotificationScheduleTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $NotificationScheduleTable,
      NotificationScheduleData,
      $$NotificationScheduleTableFilterComposer,
      $$NotificationScheduleTableOrderingComposer,
      $$NotificationScheduleTableAnnotationComposer,
      $$NotificationScheduleTableCreateCompanionBuilder,
      $$NotificationScheduleTableUpdateCompanionBuilder,
      (NotificationScheduleData, $$NotificationScheduleTableReferences),
      NotificationScheduleData,
      PrefetchHooks Function({bool accountId})
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$AccountsTableTableManager get accounts =>
      $$AccountsTableTableManager(_db, _db.accounts);
  $$TaskListsTableTableManager get taskLists =>
      $$TaskListsTableTableManager(_db, _db.taskLists);
  $$TasksTableTableManager get tasks =>
      $$TasksTableTableManager(_db, _db.tasks);
  $$PendingOpsTableTableManager get pendingOps =>
      $$PendingOpsTableTableManager(_db, _db.pendingOps);
  $$SyncRunsTableTableManager get syncRuns =>
      $$SyncRunsTableTableManager(_db, _db.syncRuns);
  $$CalendarSourcesTableTableManager get calendarSources =>
      $$CalendarSourcesTableTableManager(_db, _db.calendarSources);
  $$CalendarEventsTableTableManager get calendarEvents =>
      $$CalendarEventsTableTableManager(_db, _db.calendarEvents);
  $$CalendarEventAttendeesTableTableManager get calendarEventAttendees =>
      $$CalendarEventAttendeesTableTableManager(
        _db,
        _db.calendarEventAttendees,
      );
  $$CalendarEventRemindersTableTableManager get calendarEventReminders =>
      $$CalendarEventRemindersTableTableManager(
        _db,
        _db.calendarEventReminders,
      );
  $$CalendarSyncStatesTableTableManager get calendarSyncStates =>
      $$CalendarSyncStatesTableTableManager(_db, _db.calendarSyncStates);
  $$CalendarColorsTableTableManager get calendarColors =>
      $$CalendarColorsTableTableManager(_db, _db.calendarColors);
  $$ScheduleItemOverridesTableTableManager get scheduleItemOverrides =>
      $$ScheduleItemOverridesTableTableManager(_db, _db.scheduleItemOverrides);
  $$NotificationScheduleTableTableManager get notificationSchedule =>
      $$NotificationScheduleTableTableManager(_db, _db.notificationSchedule);
}

mixin _$TaskListsDaoMixin on DatabaseAccessor<AppDatabase> {
  $AccountsTable get accounts => attachedDatabase.accounts;
  $TaskListsTable get taskLists => attachedDatabase.taskLists;
  TaskListsDaoManager get managers => TaskListsDaoManager(this);
}

class TaskListsDaoManager {
  final _$TaskListsDaoMixin _db;
  TaskListsDaoManager(this._db);
  $$AccountsTableTableManager get accounts =>
      $$AccountsTableTableManager(_db.attachedDatabase, _db.accounts);
  $$TaskListsTableTableManager get taskLists =>
      $$TaskListsTableTableManager(_db.attachedDatabase, _db.taskLists);
}

mixin _$TasksDaoMixin on DatabaseAccessor<AppDatabase> {
  $AccountsTable get accounts => attachedDatabase.accounts;
  $TaskListsTable get taskLists => attachedDatabase.taskLists;
  $TasksTable get tasks => attachedDatabase.tasks;
  TasksDaoManager get managers => TasksDaoManager(this);
}

class TasksDaoManager {
  final _$TasksDaoMixin _db;
  TasksDaoManager(this._db);
  $$AccountsTableTableManager get accounts =>
      $$AccountsTableTableManager(_db.attachedDatabase, _db.accounts);
  $$TaskListsTableTableManager get taskLists =>
      $$TaskListsTableTableManager(_db.attachedDatabase, _db.taskLists);
  $$TasksTableTableManager get tasks =>
      $$TasksTableTableManager(_db.attachedDatabase, _db.tasks);
}

mixin _$PendingOpsDaoMixin on DatabaseAccessor<AppDatabase> {
  $AccountsTable get accounts => attachedDatabase.accounts;
  $PendingOpsTable get pendingOps => attachedDatabase.pendingOps;
  PendingOpsDaoManager get managers => PendingOpsDaoManager(this);
}

class PendingOpsDaoManager {
  final _$PendingOpsDaoMixin _db;
  PendingOpsDaoManager(this._db);
  $$AccountsTableTableManager get accounts =>
      $$AccountsTableTableManager(_db.attachedDatabase, _db.accounts);
  $$PendingOpsTableTableManager get pendingOps =>
      $$PendingOpsTableTableManager(_db.attachedDatabase, _db.pendingOps);
}

mixin _$SyncRunsDaoMixin on DatabaseAccessor<AppDatabase> {
  $AccountsTable get accounts => attachedDatabase.accounts;
  $SyncRunsTable get syncRuns => attachedDatabase.syncRuns;
  SyncRunsDaoManager get managers => SyncRunsDaoManager(this);
}

class SyncRunsDaoManager {
  final _$SyncRunsDaoMixin _db;
  SyncRunsDaoManager(this._db);
  $$AccountsTableTableManager get accounts =>
      $$AccountsTableTableManager(_db.attachedDatabase, _db.accounts);
  $$SyncRunsTableTableManager get syncRuns =>
      $$SyncRunsTableTableManager(_db.attachedDatabase, _db.syncRuns);
}

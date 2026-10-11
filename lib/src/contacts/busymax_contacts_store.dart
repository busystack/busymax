import 'dart:async';
import 'dart:convert';

import 'package:busystack_contacts/busystack_contacts.dart';
import 'package:drift/drift.dart';

import '../db/app_database.dart';

final class BusyMaxContactSelection {
  const BusyMaxContactSelection({
    required this.accountIds,
    required this.sourceKeys,
  });

  final Set<String> accountIds;
  final Set<String> sourceKeys;
}

/// Contacts storage inside BusyMax's existing Drift database. The application
/// owns the database; closing this adapter drains only contacts work and never
/// closes calendar or task persistence.
final class BusyMaxContactsStore implements ContactsStore {
  BusyMaxContactsStore(this.database);

  final AppDatabase database;
  final StreamController<void> _changes = StreamController<void>.broadcast();
  final Set<Future<Object?>> _active = <Future<Object?>>{};
  Future<void>? _closeFuture;
  bool _closing = false;

  @override
  Stream<void> get changes => _changes.stream;

  @override
  Future<T> read<T>(
    Future<T> Function(ContactsReadTransaction transaction) action,
  ) => _run(action, writable: false);

  @override
  Future<T> write<T>(
    Future<T> Function(ContactsWriteTransaction transaction) action,
  ) => _run(action, writable: true);

  Future<T> _run<T, Transaction extends ContactsReadTransaction>(
    Future<T> Function(Transaction transaction) action, {
    required bool writable,
  }) {
    return _track(
      () => database.transaction(() async {
        final transaction = _BusyMaxContactsTransaction(database, writable);
        try {
          return await action(transaction as Transaction);
        } finally {
          transaction.active = false;
        }
      }),
      notify: writable,
    );
  }

  // The returned operation retains its failure for the caller. The separate
  // completion gate observes it only to let shutdown drain every operation.
  Future<T> _track<T>(Future<T> Function() action, {bool notify = false}) {
    if (_closing) return Future<T>.error(StateError('Contacts store closed'));
    final done = Zone.root.run(Completer<void>.new);
    _active.add(done.future);
    final operation = Future<T>.sync(() async {
      try {
        final value = await action();
        if (notify && !_closing) _changes.add(null);
        return value;
      } finally {
        _active.remove(done.future);
        done.complete();
      }
    });
    // Observe failure for owned cleanup; the returned future still fails.
    unawaited(
      operation.then<void>(
        (_) {},
        onError: (Object error, StackTrace stack) {},
      ),
    );
    return operation;
  }

  @override
  Future<void> close() {
    final existing = _closeFuture;
    if (existing != null) return existing;
    _closing = true;
    return _closeFuture = () async {
      while (_active.isNotEmpty) {
        await Future.wait<Object?>(_active.toList());
      }
      await _changes.close();
    }();
  }

  Future<void> saveLinkedAccount({
    required ContactAccount account,
    required String busyMaxAccountId,
    required bool reuseAuthorization,
  }) => _track(
    () => database.transaction(
      () => persistLinkedAccount(
        account: account,
        busyMaxAccountId: busyMaxAccountId,
        reuseAuthorization: reuseAuthorization,
      ),
    ),
    notify: true,
  );

  /// Writes through the caller's current Drift transaction. Authorization
  /// upgrades use this so credentials, their generation and the contacts link
  /// either commit together or all roll back.
  Future<void> persistLinkedAccount({
    required ContactAccount account,
    required String busyMaxAccountId,
    required bool reuseAuthorization,
  }) async {
    if (_closing) throw StateError('Contacts store closed');
    final transaction = _BusyMaxContactsTransaction(database, true);
    try {
      await transaction.putAccount(account);
      await database.customStatement(
        '''
INSERT INTO bm_contact_account_links(
  contact_account_id, busymax_account_id, reuse_authorization
) VALUES (?, ?, ?)
ON CONFLICT(contact_account_id) DO UPDATE SET
  busymax_account_id = excluded.busymax_account_id,
  reuse_authorization = excluded.reuse_authorization
''',
        <Object?>[account.id, busyMaxAccountId, reuseAuthorization ? 1 : 0],
      );
    } finally {
      transaction.active = false;
    }
  }

  /// Removes a linked contacts account through the caller's current Drift
  /// transaction (the parent-account removal transaction in production).
  Future<void> persistRemoveAccount(String accountId) async {
    if (_closing) throw StateError('Contacts store closed');
    final transaction = _BusyMaxContactsTransaction(database, true);
    try {
      await transaction.removeAccount(accountId);
    } finally {
      transaction.active = false;
    }
  }

  void contactConfigurationChanged() {
    if (!_closing) _changes.add(null);
  }

  Future<String?> linkedBusyMaxAccount(String contactAccountId) =>
      _track(() async {
        final row = await database
            .customSelect(
              'SELECT busymax_account_id FROM bm_contact_account_links '
              'WHERE contact_account_id = ?',
              variables: <Variable<Object>>[Variable<String>(contactAccountId)],
            )
            .getSingleOrNull();
        return row?.readNullable<String>('busymax_account_id');
      });

  Future<List<String>> linkedContactAccounts(String busyMaxAccountId) => _track(
    () async =>
        (await database
                .customSelect(
                  'SELECT contact_account_id FROM bm_contact_account_links '
                  'WHERE busymax_account_id = ? ORDER BY contact_account_id',
                  variables: <Variable<Object>>[
                    Variable<String>(busyMaxAccountId),
                  ],
                )
                .get())
            .map((row) => row.read<String>('contact_account_id'))
            .toList(growable: false),
  );

  Future<void> setSourceEnabled(String sourceKey, {required bool enabled}) =>
      _track(
        () => database.transaction(
          () => database.customStatement(
            '''
INSERT INTO bm_contact_source_preferences(source_key, enabled) VALUES (?, ?)
ON CONFLICT(source_key) DO UPDATE SET enabled = excluded.enabled
''',
            <Object?>[sourceKey, enabled ? 1 : 0],
          ),
        ),
        notify: true,
      );

  Future<bool> sourceEnabled(String sourceKey) => _track(() async {
    final row = await database
        .customSelect(
          'SELECT enabled FROM bm_contact_source_preferences '
          'WHERE source_key = ?',
          variables: <Variable<Object>>[Variable<String>(sourceKey)],
        )
        .getSingleOrNull();
    return row == null || row.read<int>('enabled') != 0;
  });

  /// Returns every enabled source by default. When [busyMaxAccountId] is set,
  /// linked OAuth contacts are selected together with independent contacts-only
  /// sources, which are intentionally available to the whole event editor.
  Future<BusyMaxContactSelection> selection({String? busyMaxAccountId}) =>
      _track(() async {
        final rows = await database
            .customSelect(
              '''
SELECT a.data AS account_data, s.source_key,
       l.busymax_account_id,
       COALESCE(p.enabled, 1) AS source_enabled
  FROM bm_contact_accounts a
  JOIN bm_contact_sources s ON s.account_id = a.id
  LEFT JOIN bm_contact_account_links l ON l.contact_account_id = a.id
  LEFT JOIN bm_contact_source_preferences p ON p.source_key = s.source_key
 WHERE (? IS NULL OR l.busymax_account_id IS NULL OR l.busymax_account_id = ?)
 ORDER BY a.id, s.source_key
''',
              variables: <Variable<Object>>[
                Variable<String>(busyMaxAccountId),
                Variable<String>(busyMaxAccountId),
              ],
            )
            .get();
        final accountIds = <String>{};
        final sourceKeys = <String>{};
        for (final row in rows) {
          if (row.read<int>('source_enabled') == 0) continue;
          final account = ContactAccount.fromJson(
            (jsonDecode(row.read<String>('account_data')) as Map)
                .cast<String, dynamic>(),
          );
          if (!account.enabled) continue;
          accountIds.add(account.id);
          sourceKeys.add(row.read<String>('source_key'));
        }
        return BusyMaxContactSelection(
          accountIds: Set<String>.unmodifiable(accountIds),
          sourceKeys: Set<String>.unmodifiable(sourceKeys),
        );
      });
}

final class _BusyMaxContactsTransaction implements ContactsWriteTransaction {
  _BusyMaxContactsTransaction(this.database, this.writable);

  final AppDatabase database;
  final bool writable;
  bool active = true;

  void _check({bool write = false}) {
    if (!active || write && !writable) {
      throw StateError('Invalid contacts transaction access');
    }
  }

  Future<List<T>> _list<T>(
    String sql,
    T Function(Map<String, dynamic>) decode, [
    List<Variable<Object>> variables = const <Variable<Object>>[],
  ]) async {
    _check();
    final rows = await database.customSelect(sql, variables: variables).get();
    _check();
    return rows
        .map(
          (row) => decode(
            (jsonDecode(row.read<String>('data')) as Map)
                .cast<String, dynamic>(),
          ),
        )
        .toList(growable: false);
  }

  Future<T?> _one<T>(
    String table,
    String column,
    String id,
    T Function(Map<String, dynamic>) decode,
  ) async {
    final rows = await _list<T>(
      'SELECT data FROM $table WHERE $column = ?',
      decode,
      <Variable<Object>>[Variable<String>(id)],
    );
    return rows.firstOrNull;
  }

  @override
  Future<List<ContactAccount>> accounts() => _list<ContactAccount>(
    'SELECT data FROM bm_contact_accounts ORDER BY id',
    ContactAccount.fromJson,
  );

  @override
  Future<ContactAccount?> account(String id) => _one<ContactAccount>(
    'bm_contact_accounts',
    'id',
    id,
    ContactAccount.fromJson,
  );

  @override
  Future<List<ContactSource>> sources({String? accountId}) =>
      _list<ContactSource>(
        'SELECT data FROM bm_contact_sources'
        '${accountId == null ? '' : ' WHERE account_id = ?'} '
        'ORDER BY source_key',
        ContactSource.fromJson,
        accountId == null
            ? const <Variable<Object>>[]
            : <Variable<Object>>[Variable<String>(accountId)],
      );

  @override
  Future<ContactSource?> source(String key) => _one<ContactSource>(
    'bm_contact_sources',
    'source_key',
    key,
    ContactSource.fromJson,
  );

  @override
  Future<ContactRecord?> contact(ContactIdentity identity) =>
      _one<ContactRecord>(
        'bm_contact_records',
        'identity_key',
        identity.key,
        contactRecordFromJson,
      );

  ({String sql, List<Variable<Object>> variables}) _filter(
    String? accountId,
    String? sourceKey,
    String query,
  ) {
    final clauses = <String>[];
    final variables = <Variable<Object>>[];
    if (accountId != null) {
      clauses.add('account_id = ?');
      variables.add(Variable<String>(accountId));
    }
    if (sourceKey != null) {
      clauses.add('source_key = ?');
      variables.add(Variable<String>(sourceKey));
    }
    final needle = query.trim().toLowerCase();
    if (needle.isNotEmpty) {
      clauses.add("lower(search_text) LIKE ? ESCAPE '\\'");
      variables.add(
        Variable<String>(
          '%${needle.replaceAll(r'\', r'\\').replaceAll('%', r'\%').replaceAll('_', r'\_')}%',
        ),
      );
    }
    return (
      sql: clauses.isEmpty ? '' : ' WHERE ${clauses.join(' AND ')}',
      variables: variables,
    );
  }

  void _validateBounds(String query, int limit, int offset) {
    if (query.length > 1024 || limit < 0 || limit > 1000 || offset < 0) {
      throw ArgumentError('Bounded contacts query required');
    }
  }

  @override
  Future<List<ContactRecord>> contacts({
    String? accountId,
    String? sourceKey,
    String query = '',
    int limit = 100,
    int offset = 0,
  }) {
    _validateBounds(query, limit, offset);
    final filter = _filter(accountId, sourceKey, query);
    return _list<ContactRecord>(
      'SELECT data FROM bm_contact_records${filter.sql} '
      'ORDER BY name COLLATE NOCASE, identity_key LIMIT ? OFFSET ?',
      contactRecordFromJson,
      <Variable<Object>>[
        ...filter.variables,
        Variable<int>(limit),
        Variable<int>(offset),
      ],
    );
  }

  @override
  Future<List<ContactProjection>> projections({
    String? accountId,
    String? sourceKey,
    String query = '',
    int limit = 100,
    int offset = 0,
  }) {
    _validateBounds(query, limit, offset);
    final filter = _filter(accountId, sourceKey, query);
    return _list<ContactProjection>(
      'SELECT projection AS data FROM bm_contact_records${filter.sql} '
      'ORDER BY name COLLATE NOCASE, identity_key LIMIT ? OFFSET ?',
      ContactProjection.fromJson,
      <Variable<Object>>[
        ...filter.variables,
        Variable<int>(limit),
        Variable<int>(offset),
      ],
    );
  }

  @override
  Future<int> count({
    String? accountId,
    String? sourceKey,
    String query = '',
  }) async {
    _validateBounds(query, 0, 0);
    _check();
    final filter = _filter(accountId, sourceKey, query);
    final row = await database
        .customSelect(
          'SELECT count(*) AS total FROM bm_contact_records${filter.sql}',
          variables: filter.variables,
        )
        .getSingle();
    _check();
    return row.read<int>('total');
  }

  @override
  Future<List<ContactMutation>> mutations({
    String? accountId,
    String? sourceKey,
  }) {
    final clauses = <String>[];
    final variables = <Variable<Object>>[];
    if (accountId != null) {
      clauses.add('account_id = ?');
      variables.add(Variable<String>(accountId));
    }
    if (sourceKey != null) {
      clauses.add('source_key = ?');
      variables.add(Variable<String>(sourceKey));
    }
    return _list<ContactMutation>(
      'SELECT data FROM bm_contact_mutations'
      '${clauses.isEmpty ? '' : ' WHERE ${clauses.join(' AND ')}'} '
      'ORDER BY id',
      ContactMutation.fromJson,
      variables,
    );
  }

  @override
  Future<ContactSyncState?> syncState(String sourceKey) =>
      _one<ContactSyncState>(
        'bm_contact_sync_states',
        'source_key',
        sourceKey,
        ContactSyncState.fromJson,
      );

  @override
  Future<List<ContactDraft>> drafts() => _list<ContactDraft>(
    'SELECT data FROM bm_contact_drafts ORDER BY id',
    ContactDraft.fromJson,
  );

  Future<void> _put(
    String table,
    Map<String, Object?> columns,
    String keyColumn,
  ) async {
    _check(write: true);
    final keys = columns.keys.toList(growable: false);
    await database.customStatement(
      'INSERT INTO $table(${keys.join(',')}) '
      'VALUES(${List<String>.filled(keys.length, '?').join(',')}) '
      'ON CONFLICT($keyColumn) DO UPDATE SET '
      '${keys.where((key) => key != keyColumn).map((key) => '$key=excluded.$key').join(',')}',
      columns.values.toList(growable: false),
    );
    _check(write: true);
  }

  @override
  Future<void> putAccount(ContactAccount account) => _put(
    'bm_contact_accounts',
    <String, Object?>{'id': account.id, 'data': jsonEncode(account.toJson())},
    'id',
  );

  @override
  Future<void> putSource(ContactSource source) =>
      _put('bm_contact_sources', <String, Object?>{
        'source_key': source.key,
        'account_id': source.accountId,
        'data': jsonEncode(source.toJson()),
      }, 'source_key');

  @override
  Future<void> putContact(ContactRecord contact, {String? seenScan}) async {
    final projection = contact.projection;
    await _put('bm_contact_records', <String, Object?>{
      'identity_key': contact.identity.key,
      'account_id': contact.identity.accountId,
      'source_key': jsonEncode(<String>[
        contact.identity.accountId,
        contact.identity.provider.name,
        contact.identity.sourceId,
      ]),
      'name': projection.displayName,
      'search_text': projection.searchText,
      'data': jsonEncode(contact.toJson()),
      'projection': jsonEncode(<String, Object?>{
        ...projection.toJson(),
        'notes': '',
        'addresses': <Object?>[],
        'dates': <Object?>[],
        'urls': <Object?>[],
        'photo': projection.photo == null
            ? null
            : <String, Object?>{
                ...projection.photo!.toJson(),
                'embedded': null,
              },
      }),
      'seen_scan': seenScan,
    }, 'identity_key');
  }

  @override
  Future<void> deleteContact(ContactIdentity identity) => _delete(
    'DELETE FROM bm_contact_records WHERE identity_key = ?',
    <Object?>[identity.key],
  );

  @override
  Future<void> pruneUnseen(
    String sourceKey,
    String scanId,
    Set<String> protectedIdentities,
  ) async {
    _check(write: true);
    final rows = await database
        .customSelect(
          'SELECT identity_key FROM bm_contact_records '
          'WHERE source_key = ? AND (seen_scan IS NULL OR seen_scan <> ?)',
          variables: <Variable<Object>>[
            Variable<String>(sourceKey),
            Variable<String>(scanId),
          ],
        )
        .get();
    for (final row in rows) {
      final id = row.read<String>('identity_key');
      if (!protectedIdentities.contains(id)) {
        await _delete(
          'DELETE FROM bm_contact_records WHERE identity_key = ?',
          <Object?>[id],
        );
      }
    }
  }

  @override
  Future<void> putMutation(ContactMutation mutation) =>
      _put('bm_contact_mutations', <String, Object?>{
        'id': mutation.id,
        'account_id': mutation.accountId,
        'source_key': mutation.sourceKey,
        'data': jsonEncode(mutation.toJson()),
      }, 'id');

  @override
  Future<void> deleteMutation(String id) =>
      _delete('DELETE FROM bm_contact_mutations WHERE id = ?', <Object?>[id]);

  @override
  Future<void> putSyncState(ContactSyncState state) =>
      _put('bm_contact_sync_states', <String, Object?>{
        'source_key': state.sourceKey,
        'data': jsonEncode(state.toJson()),
      }, 'source_key');

  @override
  Future<void> putDraft(ContactDraft draft) =>
      _put('bm_contact_drafts', <String, Object?>{
        'id': draft.id,
        'source_key': draft.sourceKey,
        'data': jsonEncode(draft.toJson()),
      }, 'id');

  @override
  Future<void> deleteDraft(String id) =>
      _delete('DELETE FROM bm_contact_drafts WHERE id = ?', <Object?>[id]);

  @override
  Future<void> removeAccount(String id) =>
      _delete('DELETE FROM bm_contact_accounts WHERE id = ?', <Object?>[id]);

  @override
  Future<void> removeSource(String key) async {
    await _delete(
      'DELETE FROM bm_contact_mutations WHERE source_key = ?',
      <Object?>[key],
    );
    await _delete(
      'DELETE FROM bm_contact_sources WHERE source_key = ?',
      <Object?>[key],
    );
  }

  Future<void> _delete(String sql, List<Object?> variables) async {
    _check(write: true);
    await database.customStatement(sql, variables);
    _check(write: true);
  }
}

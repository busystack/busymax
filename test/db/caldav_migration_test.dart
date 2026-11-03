import 'dart:io';

import 'package:busymax/src/db/app_database.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart' show Value;

import '../support/persistence_test_directory.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

void main() {
  for (final interrupted in [false, true]) {
    test(
      'schema 23 upgrade preserves creation states and unique index; interrupted=$interrupted',
      () async {
        final directory = await createPersistenceTestDirectory(
          'busymax-v23-creation-',
        );
        addTearDown(() => directory.delete(recursive: true));
        final file = File('${directory.path}/qa.sqlite');
        var db = AppDatabase(NativeDatabase(file));
        await db
            .into(db.accounts)
            .insert(
              AccountsCompanion.insert(
                id: 'caldav',
                provider: 'caldav',
                authority: 'https://example.test/',
                providerAccountId: 'alice',
                credentialKind: 'caldav_password',
                createdAtUtc: 'now',
                updatedAtUtc: 'now',
              ),
            );
        await db.customStatement(
          'INSERT INTO authorization_generations VALUES (?,?)',
          ['caldav', 9],
        );
        for (final state in ['prepared', 'dispatched', 'rejected']) {
          await db
              .into(db.davCollectionCreations)
              .insert(
                DavCollectionCreationsCompanion.insert(
                  id: state,
                  accountId: 'caldav',
                  authority: 'https://example.test/',
                  homeUri: 'https://example.test/home/',
                  targetUri: 'https://example.test/home/$state/',
                  displayName: state,
                  componentsJson: '["VEVENT"]',
                  state: Value(state),
                  createdAtUtc: 'now',
                ),
              );
        }
        await db.close();
        var raw = sqlite.sqlite3.open(file.path);
        for (final column in [
          'last_error_kind',
          'last_error_code',
          'last_error_status',
        ]) {
          raw.execute(
            'ALTER TABLE dav_collection_creations DROP COLUMN $column',
          );
        }
        raw.execute('PRAGMA user_version = 23');
        final index = raw
            .select(
              "SELECT sql FROM sqlite_master WHERE name='idx_dav_creation_pending_name'",
            )
            .single['sql'];
        final before = raw
            .select('SELECT * FROM dav_collection_creations ORDER BY id')
            .map((r) => Map<String, Object?>.from(r))
            .toList();
        raw.close();
        db = interrupted
            ? _InterruptedDatabase(NativeDatabase(file))
            : AppDatabase(NativeDatabase(file));
        if (interrupted) {
          await expectLater(db.select(db.accounts).get(), throwsStateError);
          await db.close();
          raw = sqlite.sqlite3.open(file.path);
          expect(raw.select('PRAGMA user_version').single.values.single, 23);
          expect(
            raw
                .select('PRAGMA table_info(dav_collection_creations)')
                .map((r) => r['name']),
            isNot(contains('last_error_code')),
          );
          expect(
            raw
                .select('SELECT * FROM dav_collection_creations ORDER BY id')
                .map((r) => Map<String, Object?>.from(r))
                .toList(),
            before,
          );
          raw.close();
          db = AppDatabase(NativeDatabase(file));
        }
        final rows = await db.select(db.davCollectionCreations).get();
        expect(rows.map((r) => r.state).toSet(), {
          'prepared',
          'dispatched',
          'rejected',
        });
        expect(
          rows.every(
            (r) =>
                r.lastErrorCode == null &&
                r.lastErrorKind == null &&
                r.lastErrorStatus == null,
          ),
          isTrue,
        );
        expect(
          (await db.select(db.authorizationGenerations).getSingle()).generation,
          9,
        );
        expect(
          (await db
                  .customSelect(
                    "SELECT sql FROM sqlite_master WHERE name='idx_dav_creation_pending_name'",
                  )
                  .getSingle())
              .data['sql'],
          index,
        );
        for (final original in before) {
          final row =
              (await db
                      .customSelect('SELECT * FROM dav_collection_creations')
                      .get())
                  .singleWhere((r) => r.data['id'] == original['id']);
          for (final entry in original.entries) {
            expect(row.data[entry.key], entry.value);
          }
        }
        expect(
          await db.customSelect('PRAGMA foreign_key_check').get(),
          isEmpty,
        );
        expect(
          (await db.customSelect('PRAGMA user_version').getSingle())
              .data['user_version'],
          24,
        );
        await db.close();
      },
    );
  }
  for (final interrupted in [false, true]) {
    test(
      'schema 22 collection-journal upgrade preserves account and rolls back atomically: $interrupted',
      () async {
        final directory = await Directory.systemTemp.createTemp(
          'busymax-v22-creation-',
        );
        addTearDown(() => directory.delete(recursive: true));
        final file = File('${directory.path}/qa.sqlite');
        var db = AppDatabase(NativeDatabase(file));
        await db
            .into(db.accounts)
            .insert(
              AccountsCompanion.insert(
                id: 'caldav',
                provider: 'caldav',
                authority: 'https://example.test/',
                providerAccountId: 'alice',
                credentialKind: 'caldav_password',
                createdAtUtc: 'now',
                updatedAtUtc: 'now',
              ),
            );
        await db.customStatement(
          'INSERT INTO authorization_generations VALUES (?, ?)',
          ['caldav', 9],
        );
        await db.close();
        final raw = sqlite.sqlite3.open(file.path);
        // The journal is the only schema-23 addition. Remove it to reproduce the
        // exact preceding schema, retaining its existing accounts and generation.
        raw.execute('DROP TABLE dav_collection_creations');
        raw.execute('PRAGMA user_version = 22');
        raw.close();
        db = interrupted
            ? _InterruptedDatabase(NativeDatabase(file))
            : AppDatabase(NativeDatabase(file));
        if (interrupted) {
          await expectLater(db.select(db.accounts).get(), throwsStateError);
          await db.close();
          final check = sqlite.sqlite3.open(file.path);
          expect(check.select('PRAGMA user_version').single.values.single, 22);
          expect(
            check.select(
              "SELECT name FROM sqlite_master WHERE name='dav_collection_creations'",
            ),
            isEmpty,
          );
          expect(
            check
                .select('SELECT generation FROM authorization_generations')
                .single
                .values
                .single,
            9,
          );
          check.close();
          db = AppDatabase(NativeDatabase(file));
        }
        expect((await db.select(db.accounts).getSingle()).provider, 'caldav');
        expect(
          (await db.select(db.authorizationGenerations).getSingle()).generation,
          9,
        );
        expect(await db.select(db.davCollectionCreations).get(), isEmpty);
        expect(
          (await db.customSelect('PRAGMA user_version').getSingle())
              .data['user_version'],
          24,
        );
        expect(
          await db.customSelect('PRAGMA foreign_key_check').get(),
          isEmpty,
        );
        await db.close();
      },
    );
  }
  for (final failure in [false, true]) {
    test(
      'actual v0.4.0 schema 21 ${failure ? 'rolls back interrupted upgrade' : 'preserves every row on upgrade'}',
      () async {
        final directory = await Directory.systemTemp.createTemp(
          'busymax-caldav-migration-',
        );
        addTearDown(() => directory.delete(recursive: true));
        final file = File('${directory.path}/busymax.sqlite');
        final raw = sqlite.sqlite3.open(file.path);
        raw.execute(
          File('test/fixtures/schema_v21_v040.sql').readAsStringSync(),
        );
        const now = '2026-11-02T00:00:00Z';
        for (final pair in {
          'google': 'oauth',
          'microsoft': 'oauth',
          'apple_icloud': 'apple_app_specific_password',
          'nextcloud': 'nextcloud_app_password',
          'webcal': 'webcal_subscription',
        }.entries) {
          raw.execute(
            'INSERT INTO accounts(id,provider,authority,provider_account_id,credential_kind,created_at_utc,updated_at_utc,auth_state) VALUES (?,?,?,?,?,?,?,?)',
            [
              pair.key,
              pair.key,
              'https://example.test/${pair.key}',
              'user',
              pair.value,
              now,
              now,
              'signed_in',
            ],
          );
          raw.execute('INSERT INTO authorization_generations VALUES (?,?)', [
            pair.key,
            7,
          ]);
          raw.execute('INSERT INTO account_authorizations VALUES (?,?,?)', [
            pair.key,
            7,
            '{"fixture":true}',
          ]);
          raw.execute(
            'INSERT INTO pending_ops(id,account_id,entity_type,operation,request_json,created_at_utc,updated_at_utc) VALUES (?,?,?,?,?,?,?)',
            [
              'pending-${pair.key}',
              pair.key,
              'event',
              'update',
              '{"preserve":true}',
              now,
              now,
            ],
          );
        }
        raw.execute(
          'INSERT INTO dav_account_services(account_id,canonical_service_uri,canonical_origin,principal_href,calendar_home_href,discovered_at_utc) VALUES (?,?,?,?,?,?)',
          [
            'nextcloud',
            'https://example.test/dav/',
            'https://example.test',
            'https://example.test/principals/user/',
            'https://example.test/calendars/user/',
            now,
          ],
        );
        raw.execute(
          'INSERT INTO dav_collections(id,account_id,href_key,request_uri,display_name,created_at_utc,updated_at_utc,sync_token) VALUES (?,?,?,?,?,?,?,?)',
          [
            'collection',
            'nextcloud',
            '/calendars/user/events/',
            'https://example.test/calendars/user/events/',
            'Cached calendar',
            now,
            now,
            'sync-baseline',
          ],
        );
        raw.execute(
          'INSERT INTO dav_objects(id,account_id,collection_id,href_key,request_uri,raw_ics_body,raw_body_hash,first_seen_at_utc,last_fetched_at_utc,last_changed_at_utc,etag) VALUES (?,?,?,?,?,?,?,?,?,?,?)',
          [
            'object',
            'nextcloud',
            'collection',
            '/calendars/user/events/opaque%2Fid.ics',
            'https://example.test/calendars/user/events/opaque%2Fid.ics',
            'BEGIN:VCALENDAR\r\nEND:VCALENDAR\r\n',
            'hash',
            now,
            now,
            now,
            '"etag"',
          ],
        );
        raw.execute('INSERT INTO bm_contact_accounts VALUES (?,?)', [
          'contacts',
          '{}',
        ]);
        raw.execute('INSERT INTO bm_contact_account_links VALUES (?,?,?)', [
          'contacts',
          'nextcloud',
          1,
        ]);
        final tables = raw
            .select(
              "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'",
            )
            .map((r) => r['name'] as String)
            .toList();
        final before = {
          for (final table in tables)
            table: raw
                .select('SELECT * FROM "$table"')
                .map((r) => Map<String, Object?>.from(r))
                .toList(),
        };
        expect(raw.select('PRAGMA foreign_key_check'), isEmpty);
        raw.close();
        var db = failure
            ? _InterruptedDatabase(NativeDatabase(file))
            : AppDatabase(NativeDatabase(file));
        if (failure) {
          await expectLater(
            db.customSelect('SELECT 1').get(),
            throwsStateError,
          );
          await db.close();
          final rolledBack = sqlite.sqlite3.open(file.path);
          expect(
            rolledBack.select('PRAGMA user_version').single.values.single,
            21,
          );
          for (final table in tables) {
            expect(
              rolledBack
                  .select('SELECT * FROM "$table"')
                  .map((r) => Map<String, Object?>.from(r))
                  .toList(),
              before[table],
              reason: table,
            );
          }
          rolledBack.close();
          db = AppDatabase(NativeDatabase(file));
        }
        expect(
          (await db.customSelect('PRAGMA user_version').getSingle())
              .data['user_version'],
          24,
        );
        for (final table in tables) {
          expect(
            (await db.customSelect('SELECT * FROM "$table"').get())
                .map((r) => r.data)
                .toList(),
            before[table],
            reason: table,
          );
        }
        await db.customStatement(
          'INSERT INTO accounts(id,provider,authority,provider_account_id,credential_kind,created_at_utc,updated_at_utc) VALUES (?,?,?,?,?,?,?)',
          [
            'caldav',
            'caldav',
            'https://example.test/dav/',
            'user',
            'caldav_password',
            now,
            now,
          ],
        );
        await expectLater(
          db.customStatement(
            'UPDATE accounts SET credential_kind = ? WHERE id = ?',
            ['nextcloud_app_password', 'caldav'],
          ),
          throwsA(anything),
        );
        expect(
          await db.customSelect('PRAGMA foreign_key_check').get(),
          isEmpty,
        );
        await db.close();
        db = AppDatabase(NativeDatabase(file));
        expect(await db.select(db.accounts).get(), hasLength(6));
        await db.close();
      },
    );
  }
}

class _InterruptedDatabase extends AppDatabase {
  _InterruptedDatabase(super.executor);

  @override
  Future<void> customStatement(String statement, [List<Object?>? args]) async {
    if (statement == 'PRAGMA user_version = 24') {
      throw StateError('Interrupted before commit');
    }
    await super.customStatement(statement, args);
  }
}

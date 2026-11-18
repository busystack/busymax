import 'dart:io';

import 'package:busymax/src/db/app_database.dart';
import 'package:busymax/src/db/creation_receipt_store.dart';
import 'package:busymax/src/db/migrations.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

import '../support/persistence_test_directory.dart';

void main() {
  test(
    'schema 25 gains creation receipts without losing existing data',
    () async {
      final directory = await createPersistenceTestDirectory('busymax-v25-');
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/app.sqlite');
      final original = AppDatabase(NativeDatabase(file));
      await original.into(original.accounts).insert(_account('existing'));
      await original.close();

      final previous = sqlite.sqlite3.open(file.path);
      previous.execute('DROP TABLE creation_receipts');
      previous.execute('PRAGMA user_version = 25');
      previous.close();

      final upgraded = AppDatabase(NativeDatabase(file));
      addTearDown(upgraded.close);
      final version = await upgraded
          .customSelect('PRAGMA user_version')
          .getSingle();
      expect(version.data['user_version'], latestSchemaVersion);
      expect(
        (await upgraded.select(upgraded.accounts).getSingle()).id,
        'existing',
      );
      expect(await upgraded.select(upgraded.creationReceipts).get(), isEmpty);
    },
  );

  test(
    'a creation receipt and its mutation commit or roll back together',
    () async {
      final db = AppDatabase.memoryForTests();
      addTearDown(db.close);
      final store = CreationReceiptStore(db);
      const kind = CreationKind.task;
      const id = 'one-draft';

      await expectLater(
        store.createOnce(
          kind: kind,
          id: id,
          create: () async {
            await db.into(db.accounts).insert(_account('attempt'));
            throw StateError('Creation failed');
          },
        ),
        throwsStateError,
      );
      expect(await db.select(db.accounts).get(), isEmpty);
      expect(await db.select(db.creationReceipts).get(), isEmpty);

      var writes = 0;
      Future<String> create() async {
        final resultId = 'created-${++writes}';
        await db.into(db.accounts).insert(_account(resultId));
        return resultId;
      }

      final attempts = await Future.wait([
        store.createOnce(kind: kind, id: id, create: create),
        store.createOnce(kind: kind, id: id, create: create),
      ]);
      expect(
        attempts.map((attempt) => attempt.resultId),
        everyElement('created-1'),
      );
      expect(attempts.where((attempt) => attempt.created), hasLength(1));
      expect(await store.hasCommitted(kind, id), isTrue);

      final distinct = await store.createOnce(
        kind: kind,
        id: 'another-draft',
        create: create,
      );
      expect(distinct, (resultId: 'created-2', created: true));
      expect(await db.select(db.accounts).get(), hasLength(2));
    },
  );
}

AccountsCompanion _account(String id) => AccountsCompanion.insert(
  id: id,
  provider: 'google',
  authority: 'https://accounts.google.com',
  providerAccountId: id,
  credentialKind: 'oauth',
  createdAtUtc: 'now',
  updatedAtUtc: 'now',
);

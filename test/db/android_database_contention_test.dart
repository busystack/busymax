import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:busymax/src/db/app_database.dart';
import 'package:busymax/src/db/native_database_connection.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/persistence_test_directory.dart';

void main() {
  test('independent Android connections wait for real writers and retain journal mode', () async {
    final directory = await createPersistenceTestDirectory(
      'android-contention-',
    );
    final file = File('${directory.path}/test.sqlite');
    final databases = <AppDatabase>[];
    addTearDown(() async {
      for (final db in databases.reversed) {
        await db.close();
      }
      await directory.delete(recursive: true);
    });
    Future<AppDatabase> open() async {
      final db = AppDatabase(await openNativeDatabase(file, android: true));
      databases.add(db);
      await db.customSelect('SELECT 1').get();
      return db;
    }

    final first = await open();
    await first.customStatement(
      'CREATE TABLE qa_writes(owner TEXT PRIMARY KEY, value INTEGER NOT NULL)',
    );
    final second = await open();
    final reader = await open();
    expect(
      (await reader.customSelect('PRAGMA journal_mode').getSingle())
          .data
          .values
          .single,
      'delete',
    );
    expect(
      (await reader.customSelect('PRAGMA busy_timeout').getSingle())
          .data
          .values
          .single,
      0,
      reason:
          'The explicit monotonic handler replaces SQLite’s built-in timeout.',
    );
    final holding = Completer<void>();
    final release = Completer<void>();
    final writer = first.transaction(() async {
      await first.customStatement("INSERT INTO qa_writes VALUES('one', 1)");
      holding.complete();
      await release.future;
    });
    await holding.future;
    var callbacks = 0;
    final competing = second.transaction(() async {
      callbacks++;
      await second.customStatement("INSERT INTO qa_writes VALUES('two', 2)");
    });
    // Reads remain possible while the other connection holds RESERVED. The
    // waiting writer runs in a different native executor isolate, so the first
    // writer can actually finish; this is not a mocked SQLite response.
    expect(
      (await reader.customSelect('SELECT * FROM qa_writes').get()),
      isEmpty,
    );
    await Future<void>.delayed(const Duration(milliseconds: 150));
    release.complete();
    await Future.wait([writer, competing]);
    expect(
      callbacks,
      1,
      reason: 'A lock wait must never replay a Dart callback.',
    );
    expect(
      (await reader
              .customSelect('SELECT * FROM qa_writes ORDER BY owner')
              .get())
          .map((r) => r.data),
      [
        {'owner': 'one', 'value': 1},
        {'owner': 'two', 'value': 2},
      ],
    );
  });

  test(
    'commit waits for an independent reader without replaying the writer',
    () async {
      final directory = await createPersistenceTestDirectory('android-commit-');
      final file = File('${directory.path}/test.sqlite');
      final writer = AppDatabase(await openNativeDatabase(file, android: true));
      final reader = AppDatabase(await openNativeDatabase(file, android: true));
      addTearDown(() async {
        await reader.close();
        await writer.close();
        await directory.delete(recursive: true);
      });
      await writer.customStatement('CREATE TABLE qa_writes(value INTEGER)');
      await reader.customStatement('BEGIN DEFERRED');
      await reader.customSelect('SELECT * FROM qa_writes').get();
      final committing = Completer<void>();
      var callbacks = 0;
      final update = writer.transaction(() async {
        callbacks++;
        await writer.customStatement('INSERT INTO qa_writes VALUES(1)');
        committing.complete();
      });
      await committing.future;
      await Future<void>.delayed(const Duration(milliseconds: 150));
      await reader.customStatement('COMMIT');
      await update;
      expect(callbacks, 1);
      expect(
        (await reader.customSelect('SELECT * FROM qa_writes').get())
            .single
            .data,
        {'value': 1},
      );
    },
  );

  test(
    'native trace flushes typed errors without SQL or private payloads',
    () async {
      final directory = await createPersistenceTestDirectory('android-trace-');
      final db = AppDatabase(
        await openNativeDatabase(
          File('${directory.path}/test.sqlite'),
          android: true,
          trace: true,
        ),
      );
      var closed = false;
      addTearDown(() async {
        if (!closed) await db.close();
        await directory.delete(recursive: true);
      });
      const privatePayload =
          'never-persist-this-private-payload-in-diagnostics';
      await db.customStatement('CREATE TABLE qa_secret(payload TEXT)');
      await db.transaction(() async {
        await db.customStatement('INSERT INTO qa_secret VALUES (?)', [
          privatePayload,
        ]);
      });
      await expectLater(
        db.customSelect('SELECT * FROM missing_qa_table').get(),
        throwsA(predicate((e) => e.toString().contains('SqliteException(1)'))),
      );
      await db.close();
      closed = true;
      final files = await directory
          .list(recursive: true)
          .where(
            (f) => f is File && f.uri.pathSegments.last == 'operations.jsonl',
          )
          .cast<File>()
          .toList();
      expect(files, hasLength(1));
      final text = await files.single.readAsString();
      expect(text, isNot(contains(privatePayload)));
      expect(text, isNot(contains('qa_secret')));
      expect(text, isNot(contains('missing_qa_table')));
      final events = text
          .split('\n')
          .where((s) => s.isNotEmpty)
          .map((s) => jsonDecode(s) as Map)
          .toList();
      expect(
        events.map((e) => e['operation']),
        containsAll(['begin', 'custom', 'commit']),
      );
      final failure = events.singleWhere((e) => e['failed'] == true);
      expect(failure['errorType'], isNotEmpty);
      expect(failure['cancelled'], isFalse);
      expect(failure['sqliteResultCode'], 1);
      expect(failure['sqliteExtendedResultCode'], 1);
    },
  );

  test(
    'bounded lock exhaustion fails once and a subsequent operation recovers',
    () async {
      final directory = await createPersistenceTestDirectory(
        'android-busy-bound-',
      );
      final file = File('${directory.path}/test.sqlite');
      final first = AppDatabase(await openNativeDatabase(file, android: true));
      final second = AppDatabase(await openNativeDatabase(file, android: true));
      addTearDown(() async {
        await second.close();
        await first.close();
        await directory.delete(recursive: true);
      });
      await first.customStatement('CREATE TABLE qa_writes(value INTEGER)');
      await second.customSelect('SELECT 1').get();
      final holding = Completer<void>(), release = Completer<void>();
      final writer = first.transaction(() async {
        await first.customStatement('INSERT INTO qa_writes VALUES(1)');
        holding.complete();
        await release.future;
      });
      await holding.future;
      final watch = Stopwatch()..start();
      var callbacks = 0;
      try {
        await expectLater(
          second.transaction(() async {
            callbacks++;
            await second.customStatement('INSERT INTO qa_writes VALUES(2)');
          }),
          throwsA(
            predicate((e) => e.toString().contains('SqliteException(5)')),
          ),
        );
        expect(watch.elapsed, greaterThanOrEqualTo(const Duration(seconds: 4)));
        expect(watch.elapsed, lessThan(const Duration(seconds: 8)));
        expect(
          callbacks,
          0,
          reason: 'The callback must not run before BEGIN acquires its lock.',
        );
      } finally {
        release.complete();
        await writer;
      }
      await second.customStatement('INSERT INTO qa_writes VALUES(3)');
      expect(
        (await second
                .customSelect('SELECT value FROM qa_writes ORDER BY value')
                .get())
            .map((r) => r.read<int>('value')),
        [1, 3],
      );
    },
  );
}

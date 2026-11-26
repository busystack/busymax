import 'dart:io';

import 'package:busymax/src/dav/ical/dav_native_export.dart';
import 'package:busymax/src/db/app_database.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  test('schema 26 cached journal receives identity without replacing bytes or ETag', () async {
    final directory = await Directory.systemTemp.createTemp(
      'busymax-v26-journal-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/journal.db');
    var database = AppDatabase(NativeDatabase(file));
    const now = '2026-11-26T00:00:00Z';
    const raw =
        'BEGIN:VCALENDAR\r\nVERSION:2.0\r\nPRODID:-//BusyMax fixture//EN\r\n'
        'BEGIN:VJOURNAL\r\nUID:fixture-uid\r\nDTSTAMP:20261126T000000Z\r\n'
        'DESCRIPTION;LANGUAGE=en:First\r\nDESCRIPTION;LANGUAGE=fr:Deux\r\n'
        'END:VJOURNAL\r\nEND:VCALENDAR\r\n';
    await database
        .into(database.accounts)
        .insert(
          AccountsCompanion.insert(
            id: 'account',
            provider: 'caldav',
            authority: 'https://example.invalid/',
            providerAccountId: 'fixture',
            credentialKind: 'caldav_password',
            createdAtUtc: now,
            updatedAtUtc: now,
          ),
        );
    await database
        .into(database.davCollections)
        .insert(
          DavCollectionsCompanion.insert(
            id: 'collection',
            accountId: 'account',
            hrefKey: '/dav/mixed/',
            requestUri: 'https://example.invalid/dav/mixed/',
            displayName: 'Mixed',
            supportedComponentMask: const Value(9),
            syncToken: const Value('existing-token'),
            eventsSelected: const Value(false),
            currentUserPrivilegesJson: const Value('["{DAV:}all"]'),
            createdAtUtc: now,
            updatedAtUtc: now,
          ),
        );
    await database
        .into(database.davObjects)
        .insert(
          DavObjectsCompanion.insert(
            id: 'journal-object',
            accountId: 'account',
            collectionId: 'collection',
            hrefKey: '/dav/mixed/not-the-uid.ics',
            requestUri: 'https://example.invalid/dav/mixed/not-the-uid.ics',
            rawIcsBody: raw,
            rawBodyHash: 'legacy-hash',
            etag: const Value('"old-etag"'),
            dominantComponentType: const Value('VJOURNAL'),
            baselineGeneration: const Value(7),
            firstSeenAtUtc: now,
            lastFetchedAtUtc: now,
            lastChangedAtUtc: now,
          ),
        );
    await database.close();
    final old = sqlite3.open(file.path);
    for (final sql in [
      'DROP TABLE dav_journal_entries',
      'ALTER TABLE accounts DROP COLUMN journals_enabled',
      'ALTER TABLE dav_collections DROP COLUMN journal_projection_enabled',
      'ALTER TABLE dav_collections DROP COLUMN journals_selected',
      'ALTER TABLE dav_collections DROP COLUMN journal_inventory_complete',
      'PRAGMA user_version = 26',
    ]) {
      old.execute(sql);
    }
    old.close();
    database = AppDatabase(NativeDatabase(file));
    addTearDown(database.close);
    final resource = await database.select(database.davObjects).getSingle();
    expect(resource.primaryUid, 'fixture-uid');
    expect(resource.componentMask, 8);
    expect(resource.parserVersion, 2);
    expect(resource.rawIcsBody, raw);
    expect(resource.etag, '"old-etag"');
    expect(resource.baselineGeneration, 7);
    final collection = await database
        .select(database.davCollections)
        .getSingle();
    expect(collection.syncToken, 'existing-token');
    expect(collection.eventsSelected, isFalse);
    expect(collection.journalInventoryComplete, isFalse);
    final entry = await database.select(database.davJournalEntries).getSingle();
    expect(entry.searchText, contains('deux'));
    expect(entry.startKind, isNull);
    expect(
      (await database.select(database.davObjectComponents).getSingle()).uid,
      'fixture-uid',
    );
    expect(
      (await DavNativeExportService(
        database,
      ).collection('account', 'collection')).single.rawIcs,
      raw,
    );
    expect(
      await database.customSelect('PRAGMA foreign_key_check').get(),
      isEmpty,
    );
  });
}

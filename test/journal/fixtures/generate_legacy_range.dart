import 'dart:io';

import 'package:busymax/src/dav/ical/ical_document.dart';
import 'package:busymax/src/dav/mutation/dav_mutation_patch.dart';
import 'package:busymax/src/dav/storage/dav_object_repository.dart';
import 'package:busymax/src/db/app_database.dart';
import 'package:busymax/src/journal/journal_repository.dart';
import 'package:busymax/src/providers/busy_provider.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'generate a legacy pending journal with two recurrence exceptions',
    () async {
      final path = Platform.environment['BUSYMAX_LEGACY_JOURNAL_FIXTURE']!;
      final file = File(path);
      final creating =
          Platform.environment['BUSYMAX_LEGACY_JOURNAL_CREATE'] == '1';
      expect(file.existsSync(), isFalse);
      final db = AppDatabase(NativeDatabase(file));
      addTearDown(db.close);
      const now = '2026-11-26T00:00:00Z';
      await db
          .into(db.accounts)
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
      await db
          .into(db.davCollections)
          .insert(
            DavCollectionsCompanion.insert(
              id: 'source',
              accountId: 'account',
              hrefKey: '/journals/',
              requestUri: 'https://example.invalid/journals/',
              displayName: 'Journals',
              supportedComponentMask: const Value(8),
              journalProjectionEnabled: const Value(true),
              currentUserPrivilegesJson: const Value('["{DAV:}all"]'),
              journalInventoryComplete: const Value(true),
              createdAtUtc: now,
              updatedAtUtc: now,
            ),
          );
      final objects = DavObjectRepository(database: db);
      for (final (uid, lines) in [
        (
          'legacy',
          [
            'BEGIN:VJOURNAL',
            'UID:legacy',
            'DTSTAMP:20261126T000000Z',
            'DTSTART;VALUE=DATE:20261126',
            'RRULE:FREQ=DAILY;COUNT=5',
            'SUMMARY:Series',
            'END:VJOURNAL',
            'BEGIN:VJOURNAL',
            'UID:legacy',
            'DTSTAMP:20261126T000000Z',
            'RECURRENCE-ID;VALUE=DATE:20261127',
            'DTSTART;VALUE=DATE:20261128',
            'SUMMARY:Original detached entry',
            'END:VJOURNAL',
          ],
        ),
        (
          'sibling',
          [
            'BEGIN:VJOURNAL',
            'UID:sibling',
            'DTSTAMP:20261126T000000Z',
            'SUMMARY:Unaffected sibling',
            'END:VJOURNAL',
          ],
        ),
      ]) {
        if (creating && uid == 'legacy') continue;
        final raw = [
          'BEGIN:VCALENDAR',
          'VERSION:2.0',
          'PRODID:-//BusyMax//Legacy QA fixture//EN',
          ...lines,
          'END:VCALENDAR',
          '',
        ].join('\r\n');
        await objects.commitConfirmedMutation(
          accountId: 'account',
          collectionId: 'source',
          provider: BusyProvider.caldav,
          canonicalObject: DavPreparedObject.parse(
            hrefKey: '/journals/$uid.ics',
            requestUri: Uri.parse('https://example.invalid/journals/$uid.ics'),
            etag: '"baseline-$uid"',
            contentType: 'text/calendar',
            rawIcsBody: raw,
          ),
          completedAtUtc: DateTime.parse(now),
        );
      }
      final repository = JournalRepository(
        db,
        nowUtc: () => DateTime.utc(2026, 11, 27),
      );
      if (creating) {
        final start = IcalDocument.parse(
          'BEGIN:VCALENDAR\r\nBEGIN:VJOURNAL\r\n'
          'DTSTART;VALUE=DATE:20261126\r\nRRULE:FREQ=DAILY;COUNT=5\r\n'
          'END:VJOURNAL\r\nEND:VCALENDAR\r\n',
        ).calendarComponents.single;
        await repository.create(
          (await db.select(db.davCollections).get()).single,
          title: 'Series',
          start: start.firstProperty('DTSTART'),
          details: [start.firstProperty('RRULE')!],
        );
      }
      final entry = (await repository.watchEntries().first).singleWhere(
        (row) => row.uid != 'sibling' && row.recurrenceIdKey == null,
      );
      if (creating) {
        final initial = await repository.read(entry);
        final occurrence = repository
            .occurrences(initial, DateTime.utc(2026, 11))
            .singleWhere((row) => row.recurrenceId.rawValue == '20261127');
        await repository.editOccurrence(
          repository.inspectOccurrence(
            initial,
            occurrence,
            thisAndFuture: false,
          ),
          [DavPatchOperation.setText('SUMMARY', 'Original detached entry')],
        );
      }
      final saved = await repository.read(entry);
      final moved = repository
          .occurrences(saved, DateTime.utc(2026, 11))
          .singleWhere((row) => row.recurrenceId.rawValue == '20261127');
      await repository.editOccurrence(
        repository.inspectOccurrence(saved, moved, thisAndFuture: true),
        [DavPatchOperation.setText('SUMMARY', 'Offline future edit')],
      );
      final pending = (await db.select(db.pendingOps).get()).single;
      expect(pending.operationType, creating ? 'dav.create' : 'dav.update');
      expect(pending.state, 'pending');
      final local = await repository.read(entry);
      expect(local.effectiveRawIcs, contains('SUMMARY:Offline future edit'));
      expect(
        local.effectiveRawIcs,
        contains('SUMMARY:Original detached entry'),
      );
    },
  );
}

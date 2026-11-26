import 'package:busymax/src/dav/ical/dav_native_export.dart';
import 'package:busymax/src/dav/ical/dav_native_import.dart';
import 'package:busymax/src/dav/ical/ical_document.dart';
import 'package:busymax/src/db/app_database.dart';
import 'package:busymax/src/journal/journal_repository.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';

String message(
  String method,
  int sequence,
  List<String> lines, {
  String address = 'journal@example.invalid',
}) => [
  'BEGIN:VCALENDAR',
  'VERSION:2.0',
  'PRODID:-//BusyMax iTIP fixture//EN',
  'METHOD:$method',
  'BEGIN:VJOURNAL',
  'UID:journal-itip-fixture',
  'DTSTAMP:20261126T00000${sequence}Z',
  'ORGANIZER:mailto:$address',
  'SEQUENCE:$sequence',
  ...lines,
  'END:VJOURNAL',
  'END:VCALENDAR',
  '',
].join('\r\n');

void main() {
  test('reviewed journal PUBLISH, ADD and scoped CANCEL queue ordinary resource mutations', () async {
    final db = AppDatabase.memoryForTests();
    addTearDown(db.close);
    await db
        .into(db.accounts)
        .insert(
          AccountsCompanion.insert(
            id: 'account',
            provider: 'caldav',
            authority: 'https://example.invalid/',
            providerAccountId: 'qa',
            credentialKind: 'caldav_password',
            createdAtUtc: 'now',
            updatedAtUtc: 'now',
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
            createdAtUtc: 'now',
            updatedAtUtc: 'now',
          ),
        );
    final repository = JournalRepository(db);
    final importer = DavNativeImportService(db);
    Future<NativeImportItemStatus> apply(String raw) async =>
        (await importer.import(
          accountId: 'account',
          collectionId: 'source',
          preview: NextcloudNativeImportPreview.parse(IcalDocument.parse(raw)),
        )).single.status;
    Future<String> exported() async => (await DavNativeExportService(
      db,
    ).collection('account', 'source')).single.rawIcs;
    const fields = [
      'DTSTART:20261126T090000Z',
      'DESCRIPTION:Original body',
      'RRULE:FREQ=DAILY;COUNT=3',
    ];
    final publish = message('PUBLISH', 0, fields);
    final preview = NextcloudNativeImportPreview.parse(
      IcalDocument.parse(publish),
    );
    expect(preview.isJournalMessage, isTrue);
    expect(await repository.watchEntries().first, isEmpty);
    expect(await apply(publish), NativeImportItemStatus.queued);
    expect(await apply(publish), NativeImportItemStatus.duplicate);
    expect(
      await apply(message('PUBLISH', 1, [...fields, 'SUMMARY:Revision'])),
      NativeImportItemStatus.queued,
    );
    expect(await apply(publish), NativeImportItemStatus.duplicate);
    final add = message('ADD', 2, [
      'DTSTART:20261130T090000Z',
      'DESCRIPTION:Additional item',
    ]);
    expect(await apply(add), NativeImportItemStatus.queued);
    expect(await apply(add), NativeImportItemStatus.duplicate);
    final beforeRejected = await exported();
    expect(
      await apply(
        message('CANCEL', 3, [
          'RECURRENCE-ID:20261127T090000Z',
        ], address: 'unknown@example.invalid'),
      ),
      NativeImportItemStatus.failed,
    );
    expect(await exported(), beforeRejected);
    final cancel = message('CANCEL', 3, ['RECURRENCE-ID:20261127T090000Z']);
    expect(await apply(cancel), NativeImportItemStatus.queued);
    expect(await apply(cancel), NativeImportItemStatus.duplicate);
    final raw = await exported();
    expect(raw, contains('DESCRIPTION:Additional item'));
    expect(raw, contains('DESCRIPTION:Original body'));
    final entries = await repository.watchEntries().first;
    final master = await repository.read(
      entries.singleWhere((e) => e.recurrenceIdKey == null),
    );
    final rows = repository.occurrences(master, DateTime.utc(2026, 11));
    expect(rows.map((r) => (r.recurrenceId.rawValue, r.isCancelled)), [
      ('20261126T090000Z', false),
      ('20261127T090000Z', true),
      ('20261128T090000Z', false),
      ('20261130T090000Z', false),
    ]);
    final future = message('CANCEL', 4, [
      'RECURRENCE-ID;RANGE=THISANDFUTURE:20261128T090000Z',
    ]);
    expect(await apply(future), NativeImportItemStatus.queued);
    expect(await apply(future), NativeImportItemStatus.duplicate);
    final ranged = await repository.read(master.entry);
    expect(
      repository
          .occurrences(ranged, DateTime.utc(2026, 11))
          .map((r) => r.isCancelled),
      [false, true, true, true],
    );
    expect(
      await apply(message('CANCEL', 5, const [])),
      NativeImportItemStatus.queued,
    );
    final cancelled = await repository.read(master.entry);
    expect(
      repository
          .occurrences(cancelled, DateTime.utc(2026, 11))
          .map((r) => r.isCancelled),
      everyElement(isTrue),
    );
    expect(await exported(), isNot(contains('METHOD:')));
    expect(
      (await db.select(db.pendingOps).get()).single.operationType,
      'dav.create',
    );
  });
}

import 'package:busymax/src/dav/ical/dav_native_export.dart';
import 'package:busymax/src/dav/ical/dav_native_import.dart';
import 'package:busymax/src/dav/ical/ical_document.dart';
import 'package:busymax/src/dav/ical/ical_recurrence.dart';
import 'package:busymax/src/dav/ical/ical_semantics.dart';
import 'package:busymax/src/dav/ical/ical_timezone.dart';
import 'package:busymax/src/db/app_database.dart';
import 'package:busymax/src/journal/journal_itip.dart';
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
  test('range continuation uses the next unoccupied DATE from the recurrence set', () {
    final original = message('PUBLISH', 0, [
      'DTSTART;VALUE=DATE:20261126',
      'RRULE:FREQ=DAILY;COUNT=4',
      'EXDATE;VALUE=DATE:20261129',
      'RDATE;VALUE=DATE:20261202',
      'DESCRIPTION:Master',
    ]);
    String override(
      String id,
      String start,
      String body, {
      bool range = false,
    }) => message('PUBLISH', 1, [
      'RECURRENCE-ID;VALUE=DATE${range ? ';RANGE=THISANDFUTURE' : ''}:$id',
      'DTSTART;VALUE=DATE:$start',
      'DESCRIPTION:$body',
    ]).split('BEGIN:VJOURNAL').last.split('END:VCALENDAR').first;
    final baseline = original
        .replaceFirst('METHOD:PUBLISH\r\n', '')
        .replaceFirst(
          'END:VCALENDAR',
          'BEGIN:VJOURNAL${override('20261127', '20261128', 'Range', range: true)}'
              'BEGIN:VJOURNAL${override('20261128', '20261128', 'Existing override')}'
              'END:VCALENDAR',
        );
    final cancel = JournalMessage.parse(
      IcalDocument.parse(
        message('CANCEL', 2, ['RECURRENCE-ID;VALUE=DATE:20261127']),
      ),
    );
    final raw = cancel.update(baseline)!;
    final rows = IcalRecurrenceExpander().expand(
      IcalSemanticDocument.parse(raw),
      rangeStartUtc: DateTime.utc(2026, 11, 26),
      rangeEndUtc: DateTime.utc(2026, 12, 5),
    );
    expect(
      rows.map(
        (r) => (
          r.recurrenceId.rawValue,
          r.start.rawValue,
          r.description,
          r.isCancelled,
        ),
      ),
      unorderedEquals([
        ('20261126', '20261126', 'Master', false),
        ('20261127', '20261128', 'Range', true),
        ('20261128', '20261128', 'Existing override', false),
        ('20261202', '20261203', 'Range', false),
      ]),
    );
    expect(raw, contains('RRULE:FREQ=DAILY;COUNT=4\r\n'));
    expect(raw, contains('EXDATE;VALUE=DATE:20261129\r\n'));
    expect(raw, contains('RDATE;VALUE=DATE:20261202\r\n'));
  });

  for (final useZone in [false, true]) {
    test(
      'range continuation retains civil time across a gap with ${useZone ? 'TZID' : 'floating'} dates',
      () {
        final params = useZone ? ';TZID=QA/Transitions' : '';
        const zone =
            'BEGIN:VTIMEZONE\r\nTZID:QA/Transitions\r\n'
            'BEGIN:STANDARD\r\nDTSTART:20251102T020000\r\nTZOFFSETFROM:-0700\r\nTZOFFSETTO:-0800\r\nEND:STANDARD\r\n'
            'BEGIN:DAYLIGHT\r\nDTSTART:20260308T020000\r\nTZOFFSETFROM:-0800\r\nTZOFFSETTO:-0700\r\nEND:DAYLIGHT\r\n'
            'END:VTIMEZONE\r\n';
        String declareZone(String raw) => useZone
            ? raw.replaceFirst('BEGIN:VJOURNAL', '${zone}BEGIN:VJOURNAL')
            : raw;
        final range = message('PUBLISH', 1, [
          'RECURRENCE-ID$params;RANGE=THISANDFUTURE:20260307T013000',
          'DTSTART$params:20260307T023000',
          'DESCRIPTION:Range',
        ]).split('BEGIN:VJOURNAL').last.split('END:VCALENDAR').first;
        final baseline = declareZone(
          message('PUBLISH', 0, [
                'DTSTART$params:20260306T013000',
                'RRULE:FREQ=DAILY;COUNT=5',
                'DESCRIPTION:Master',
              ])
              .replaceFirst('METHOD:PUBLISH\r\n', '')
              .replaceFirst(
                'END:VCALENDAR',
                'BEGIN:VJOURNAL${range}END:VCALENDAR',
              ),
        );
        final cancel = JournalMessage.parse(
          IcalDocument.parse(
            declareZone(
              message('CANCEL', 2, ['RECURRENCE-ID$params:20260307T013000']),
            ),
          ),
        );
        final candidate = IcalSemanticDocument.parse(cancel.update(baseline)!);
        final rows = IcalRecurrenceExpander().expand(
          candidate,
          rangeStartUtc: DateTime.utc(2026, 3, 6),
          rangeEndUtc: DateTime.utc(2026, 3, 12),
        );
        expect(rows.map((row) => row.start.rawValue), [
          '20260306T013000',
          '20260307T023000',
          '20260308T023000',
          '20260309T023000',
          '20260310T023000',
        ]);
        expect(rows.map((row) => row.isCancelled), [
          false,
          true,
          false,
          false,
          false,
        ]);
        expect(rows.map((row) => row.description), [
          'Master',
          'Range',
          'Range',
          'Range',
          'Range',
        ]);
        if (useZone) {
          final resolver = IcalTimeZoneResolver.fromDocument(candidate);
          expect(
            resolver.toUtc(rows[2].start),
            DateTime.utc(2026, 3, 8, 10, 30),
          );
          expect(
            resolver.toUtc(rows[3].start),
            DateTime.utc(2026, 3, 9, 9, 30),
          );
        }
      },
    );
  }

  test(
    'single iTIP cancellation at a range anchor preserves later journals',
    () {
      const organizer = 'ORGANIZER:mailto:journal@example.invalid';
      final baseline = [
        'BEGIN:VCALENDAR',
        'VERSION:2.0',
        'PRODID:-//BusyMax iTIP fixture//EN',
        'BEGIN:VJOURNAL',
        'UID:journal-itip-fixture',
        organizer,
        'DTSTAMP:20261125T000000Z',
        'SEQUENCE:0',
        'DTSTART:20261126T090000Z',
        'RRULE:FREQ=DAILY;COUNT=5',
        'SUMMARY:Original series',
        'DESCRIPTION:Original body',
        'STATUS:FINAL',
        'END:VJOURNAL',
        'BEGIN:VJOURNAL',
        'UID:journal-itip-fixture',
        organizer,
        'DTSTAMP:20261126T000000Z',
        'SEQUENCE:1',
        'RECURRENCE-ID;RANGE=THISANDFUTURE:20261127T090000Z',
        'DTSTART:20261127T110000Z',
        'SUMMARY:Later series',
        'DESCRIPTION:Later body',
        'STATUS:FINAL',
        'END:VJOURNAL',
        'END:VCALENDAR',
        '',
      ].join('\r\n');
      final cancel = JournalMessage.parse(
        IcalDocument.parse(
          message('CANCEL', 2, [
            'RECURRENCE-ID:20261127T090000Z',
            'STATUS:CANCELLED',
          ]),
        ),
      );
      final raw = cancel.update(baseline)!;
      final rows = IcalRecurrenceExpander().expand(
        IcalSemanticDocument.parse(raw),
        rangeStartUtc: DateTime.utc(2026, 11, 26),
        rangeEndUtc: DateTime.utc(2026, 12),
      );
      expect(
        rows.map(
          (row) => (
            row.recurrenceId.rawValue,
            row.start.rawValue,
            row.summary,
            row.description,
            row.isCancelled,
          ),
        ),
        [
          (
            '20261126T090000Z',
            '20261126T090000Z',
            'Original series',
            'Original body',
            false,
          ),
          (
            '20261127T090000Z',
            '20261127T110000Z',
            'Later series',
            'Later body',
            true,
          ),
          (
            '20261128T090000Z',
            '20261128T110000Z',
            'Later series',
            'Later body',
            false,
          ),
          (
            '20261129T090000Z',
            '20261129T110000Z',
            'Later series',
            'Later body',
            false,
          ),
          (
            '20261130T090000Z',
            '20261130T110000Z',
            'Later series',
            'Later body',
            false,
          ),
        ],
      );
      expect(raw, isNot(contains('METHOD:')));
      expect(cancel.update(raw), isNull);

      final anchorOnly = message('CANCEL', 3, [
        'RECURRENCE-ID:20261127T090000Z',
      ]);
      final inside = message('CANCEL', 3, ['RECURRENCE-ID:20261128T090000Z']);
      final combined = IcalDocument.parse(anchorOnly);
      combined.root.children.add(
        IcalDocument.parse(inside).calendarComponents.single.deepCopy(),
      );
      combined.root.structurallyDirty = true;
      final multiple = JournalMessage.parse(combined);
      final afterMultiple = multiple.update(baseline)!;
      expect(multiple.update(afterMultiple), isNull);
      final multipleRows = IcalRecurrenceExpander().expand(
        IcalSemanticDocument.parse(afterMultiple),
        rangeStartUtc: DateTime.utc(2026, 11, 26),
        rangeEndUtc: DateTime.utc(2026, 12),
      );
      expect(multipleRows.map((row) => (row.start.rawValue, row.isCancelled)), [
        ('20261126T090000Z', false),
        ('20261127T110000Z', true),
        ('20261128T110000Z', true),
        ('20261129T110000Z', false),
        ('20261130T110000Z', false),
      ]);
      final publish = JournalMessage.parse(
        IcalDocument.parse(
          message('PUBLISH', 2, [
            'RECURRENCE-ID:20261127T090000Z',
            'DTSTART:20261127T080000Z',
            'DESCRIPTION:New anchor body',
          ]),
        ),
      );
      final published = IcalRecurrenceExpander().expand(
        IcalSemanticDocument.parse(publish.update(baseline)!),
        rangeStartUtc: DateTime.utc(2026, 11, 26),
        rangeEndUtc: DateTime.utc(2026, 12),
      );
      expect(published.map((row) => (row.start.rawValue, row.description)), [
        ('20261126T090000Z', 'Original body'),
        ('20261127T080000Z', 'New anchor body'),
        ('20261128T110000Z', 'Later body'),
        ('20261129T110000Z', 'Later body'),
        ('20261130T110000Z', 'Later body'),
      ]);
    },
  );

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
      'RECURRENCE-ID;RANGE=THISANDFUTURE:20261127T090000Z',
    ]);
    expect(await apply(future), NativeImportItemStatus.queued);
    expect(await apply(future), NativeImportItemStatus.duplicate);
    final atOriginalPosition = IcalDocument.parse(await exported())
        .calendarComponents
        .map((component) => component.firstProperty('RECURRENCE-ID'))
        .where((id) => id?.rawValue == '20261127T090000Z')
        .single;
    expect(atOriginalPosition!.parameterValue('RANGE'), 'THISANDFUTURE');
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

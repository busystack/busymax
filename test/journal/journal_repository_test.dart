import 'package:busymax/src/dav/dav_errors.dart';
import 'package:busymax/src/dav/ical/dav_native_export.dart';
import 'package:busymax/src/dav/ical/ical_attachments.dart';
import 'package:busymax/src/dav/ical/ical_document.dart';
import 'package:busymax/src/dav/mutation/dav_conflict_analyzer.dart';
import 'package:busymax/src/dav/mutation/dav_mutation_patch.dart';
import 'package:busymax/src/db/app_database.dart';
import 'package:busymax/src/journal/journal_repository.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';

const bodyOne = 'DESCRIPTION;LANGUAGE=en:First';
const bodyTwo =
    'DESCRIPTION;LANGUAGE=fr;ALTREP="https://example.invalid/body":Deux';

String journal(List<String> descriptions) => [
  'BEGIN:VCALENDAR',
  'VERSION:2.0',
  'PRODID:-//BusyMax//QA//EN',
  'BEGIN:VJOURNAL',
  'UID:journal-fixture',
  'DTSTAMP:20261125T080000Z',
  ...descriptions,
  'X-JOURNAL;X-PARAM="a,b":retained',
  'END:VJOURNAL',
  'END:VCALENDAR',
  '',
].join('\r\n');

void main() {
  test('offline create, edit, search, effective export and delete use one resource', () async {
    final db = AppDatabase.memoryForTests();
    addTearDown(db.close);
    await db
        .into(db.accounts)
        .insert(
          AccountsCompanion.insert(
            id: 'account',
            provider: 'caldav',
            authority: 'https://example.invalid/',
            providerAccountId: 'fixture',
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
            hrefKey: '/dav/journal/',
            requestUri: 'https://example.invalid/dav/journal/',
            displayName: 'Journal',
            supportedComponentMask: const Value(8),
            currentUserPrivilegesJson: const Value('["{DAV:}all"]'),
            journalProjectionEnabled: const Value(true),
            createdAtUtc: 'now',
            updatedAtUtc: 'now',
          ),
        );
    final repository = JournalRepository(db);
    final sources = await repository.watchSources().first;
    await repository.create(
      sources.single,
      descriptions: [
        const DavRawPropertyValue(value: 'First'),
        const DavRawPropertyValue(
          value: 'Deux',
          parameters: [
            IcalParameter(name: 'LANGUAGE', values: ['fr'], wasQuoted: false),
          ],
        ),
      ],
      attachments: [
        const DavRawPropertyValue(value: 'https://example.invalid/reference'),
        const DavRawPropertyValue(
          value: 'AAD/',
          parameters: [
            IcalParameter(name: 'VALUE', values: ['BINARY'], wasQuoted: false),
            IcalParameter(
              name: 'ENCODING',
              values: ['BASE64'],
              wasQuoted: false,
            ),
          ],
        ),
      ],
    );
    final entry =
        (await repository
                .watchEntries(
                  search: 'deux',
                  dateFilter: JournalDateFilter.undated,
                )
                .first)
            .single;
    final initial = await repository.read(entry);
    expect(initial.component.title, isNull);
    expect(initial.component.start, isNull);
    expect(initial.component.descriptions.map((p) => p.rawValue), [
      'First',
      'Deux',
    ]);
    final attachments = readIcalAttachmentProperties(
      initial.component.component.propertiesNamed('ATTACH').toList(),
    );
    expect(attachments.first.uri, 'https://example.invalid/reference');
    expect(attachments.last.decode(), [0, 0, 255]);
    await repository.edit(initial, [
      DavPatchOperation.setText('SUMMARY', 'Example'),
    ]);
    final edited =
        (await repository.watchEntries(search: 'example').first).single;
    final pending = (await db.select(db.pendingOps).get()).single;
    expect(pending.entityType, 'journal');
    expect(pending.operationType, 'dav.create');
    expect(pending.eventId, isNull);
    expect(pending.taskId, isNull);
    final exported = (await DavNativeExportService(
      db,
    ).collection('account', 'source')).single;
    expect(exported.rawIcs, contains('DESCRIPTION;LANGUAGE=fr:Deux'));
    expect(exported.rawIcs, contains('SUMMARY:Example'));
    expect(
      exported.rawIcs,
      contains('ATTACH;VALUE=BINARY;ENCODING=BASE64:AAD/'),
    );
    expect(exported.uid, initial.entry.uid);
    await repository.edit(await repository.read(edited), [
      DavPatchOperation.replaceRepeatedRaw('ATTACH', [
        DavRawPropertyValue(
          value: attachments.last.rawValue,
          parameters: attachments.last.parameters,
        ),
      ]),
    ]);
    final retained = await repository.read(edited);
    expect(
      retained.effectiveRawIcs,
      isNot(contains('example.invalid/reference')),
    );
    expect(
      retained.effectiveRawIcs,
      contains('ATTACH;VALUE=BINARY;ENCODING=BASE64:AAD/'),
    );
    await repository.deleteResource(retained);
    expect(await repository.watchEntries().first, isEmpty);
    expect(await db.select(db.pendingOps).get(), isEmpty);

    final start = IcalDocument.parse(journal(['DTSTART;VALUE=DATE:20261126']))
        .calendarComponents
        .single
        .firstProperty('DTSTART')!;
    await repository.create(
      sources.single,
      start: start,
      frequency: JournalFrequency.daily,
    );
    final repeating = await repository.read(
      (await repository.watchEntries().first).single,
    );
    expect(repeating.effectiveRawIcs, contains('RRULE:FREQ=DAILY'));
    expect(
      repository
          .occurrences(repeating, DateTime.utc(2026, 11))
          .map((occurrence) => occurrence.start.rawValue),
      ['20261126', '20261127', '20261128', '20261129', '20261130'],
    );
  });

  test('title edit retains raw description lines and opaque extensions', () {
    const review =
        'BEGIN:VSTATUS\r\nSTATUS:FINAL\r\nCOMMENT:Reviewed\r\nEND:VSTATUS';
    final original = journal([bodyOne, bodyTwo, 'STATUS:FINAL', review]);
    final patch = DavMutationPatch(
      target: const IcalComponentKey(
        componentType: 'VJOURNAL',
        uid: 'journal-fixture',
      ),
      scope: DavMutationScope.recurrenceMaster,
      operations: [DavPatchOperation.setText('SUMMARY', 'Edited')],
    );
    final result = patch.applyTo(original, nowUtc: DateTime.utc(2026));
    expect(result, contains('$bodyOne\r\n$bodyTwo\r\n'));
    expect(result, contains('X-JOURNAL;X-PARAM="a,b":retained'));
    expect(result, contains('SUMMARY:Edited'));
    expect(result, contains(review));
    final removeStatus = DavMutationPatch(
      target: patch.target,
      scope: patch.scope,
      operations: [DavPatchOperation.setRaw('STATUS', null)],
    );
    expect(
      () => removeStatus.applyTo(original, nowUtc: DateTime.utc(2026)),
      throwsA(isA<DavException>()),
    );
  });

  test('typed journal mutation rejects derived changes and unsafe date conversions', () {
    const target = IcalComponentKey(
      componentType: 'VJOURNAL',
      uid: 'journal-fixture',
    );
    final now = DateTime.utc(2026, 11, 26);
    String apply(String raw, DavPatchOperation operation) =>
        DavMutationPatch.fromJsonString(
          DavMutationPatch(
            target: target,
            scope: DavMutationScope.recurrenceMaster,
            operations: [operation],
          ).toJsonString(),
        ).applyTo(raw, nowUtc: now);

    final derived = journal([
      'SUMMARY;DERIVED=TRUE:Source title',
      'STATUS;DERIVED=TRUE:FINAL',
      'DTSTART;VALUE=DATE;DERIVED=TRUE:20261126',
      'DESCRIPTION;DERIVED=TRUE:Source description',
      'ATTACH;DERIVED=TRUE:https://example.invalid/file',
    ]);
    expect(
      apply(derived, DavPatchOperation.setText('COMMENT', 'Unrelated')),
      contains('COMMENT:Unrelated'),
    );
    for (final operation in [
      DavPatchOperation.setText('SUMMARY', 'New title'),
      DavPatchOperation.setRaw('STATUS', 'DRAFT', preserveParameters: true),
      DavPatchOperation.setRaw('DTSTART', '20261127', preserveParameters: true),
      DavPatchOperation.replaceRepeatedRaw('DESCRIPTION', const []),
      DavPatchOperation.replaceRepeatedRaw('ATTACH', const []),
    ]) {
      expect(
        () => apply(derived, operation),
        throwsA(
          isA<DavException>().having(
            (e) => e.code,
            'code',
            'IcalDerivedJournalProperty',
          ),
        ),
      );
    }

    final dated =
        journal([
          'DTSTART;VALUE=DATE:20261126',
          'RRULE:FREQ=DAILY;UNTIL=20261130',
          'EXDATE;VALUE=DATE:20261127',
        ]).replaceFirst(
          'END:VCALENDAR\r\n',
          'BEGIN:VJOURNAL\r\nUID:journal-fixture\r\nDTSTAMP:20261125T080000Z\r\n'
              'RECURRENCE-ID;VALUE=DATE:20261128\r\nDTSTART;VALUE=DATE:20261129\r\n'
              'END:VJOURNAL\r\nEND:VCALENDAR\r\n',
        );
    expect(
      apply(dated, DavPatchOperation.setText('SUMMARY', 'Valid edit')),
      contains('RECURRENCE-ID;VALUE=DATE:20261128'),
    );
    expect(
      () =>
          apply(dated, DavPatchOperation.setRaw('DTSTART', '20261126T090000Z')),
      throwsA(
        isA<DavException>().having(
          (e) => e.code,
          'code',
          'IcalJournalRecurrenceDateMismatch',
        ),
      ),
    );
  });

  test('reordered remote descriptions prevent automatic body merge', () {
    final original = journal([bodyOne, bodyTwo]);
    final patch = DavMutationPatch(
      target: const IcalComponentKey(
        componentType: 'VJOURNAL',
        uid: 'journal-fixture',
      ),
      scope: DavMutationScope.recurrenceMaster,
      operations: [
        DavPatchOperation.replaceRepeatedRaw('DESCRIPTION', [
          const DavRawPropertyValue(value: 'changed'),
        ]),
      ],
    );
    final result = const DavConflictAnalyzer().analyzeUpdate(
      baselineRawIcs: original,
      currentRemoteRawIcs: journal([bodyTwo, bodyOne]),
      localPatch: patch,
      nowUtc: DateTime.utc(2026),
    );
    expect(result.outcome, DavConflictOutcome.conflict);
    expect(result.remoteChangedProperties, {'DESCRIPTION'});
  });
}

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
  });

  test('title edit retains raw description lines and opaque extensions', () {
    final original = journal([bodyOne, bodyTwo]);
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

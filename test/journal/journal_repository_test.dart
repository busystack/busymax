import 'package:busymax/src/dav/dav_errors.dart';
import 'package:busymax/src/dav/ical/dav_native_export.dart';
import 'package:busymax/src/dav/ical/dav_native_import.dart';
import 'package:busymax/src/dav/ical/ical_attachments.dart';
import 'package:busymax/src/dav/ical/ical_document.dart';
import 'package:busymax/src/dav/mutation/dav_conflict_analyzer.dart';
import 'package:busymax/src/dav/mutation/dav_mutation_patch.dart';
import 'package:busymax/src/db/app_database.dart';
import 'package:busymax/src/journal/journal_repository.dart';
import 'package:busymax/src/journal/presentation/journal_component_editor.dart';
import 'package:busymax/src/journal/presentation/journal_property_editor.dart';
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
  test('journal references use the original collection for UIDs and exact hrefs for URIs', () async {
    final db = AppDatabase.memoryForTests();
    addTearDown(db.close);
    for (final account in ['first', 'second']) {
      await db
          .into(db.accounts)
          .insert(
            AccountsCompanion.insert(
              id: account,
              provider: 'caldav',
              authority: 'https://example.invalid/',
              providerAccountId: account,
              credentialKind: 'caldav_password',
              createdAtUtc: 'now',
              updatedAtUtc: 'now',
            ),
          );
    }
    for (final (id, account) in [
      ('home', 'first'),
      ('nearby', 'first'),
      ('outside', 'second'),
    ]) {
      await db
          .into(db.davCollections)
          .insert(
            DavCollectionsCompanion.insert(
              id: id,
              accountId: account,
              hrefKey: '/$id/',
              requestUri: 'https://example.invalid/$id/',
              displayName: id,
              supportedComponentMask: const Value(8),
              journalProjectionEnabled: const Value(true),
              currentUserPrivilegesJson: const Value('["{DAV:}all"]'),
              createdAtUtc: 'now',
              updatedAtUtc: 'now',
            ),
          );
    }
    Future<void> add(
      String account,
      String collection,
      String uid,
      List<String> lines,
    ) async {
      final raw = journal(lines)
          .replaceFirst('UID:journal-fixture', 'UID:$uid');
      expect(
        (await DavNativeImportService(db).import(
          accountId: account,
          collectionId: collection,
          preview: NextcloudNativeImportPreview.parse(IcalDocument.parse(raw)),
        )).single.status,
        NativeImportItemStatus.queued,
      );
    }

    await add('first', 'home', 'shared-uid', ['SUMMARY:Local target']);
    await add('first', 'nearby', 'shared-uid', ['SUMMARY:Other collection']);
    await add('first', 'nearby', 'uri-target', ['SUMMARY:URI target']);
    await add('second', 'outside', 'shared-uid', ['SUMMARY:Other account']);
    final objects = await db.select(db.davObjects).get();
    final uri = objects
        .singleWhere((row) => row.primaryUid == 'uri-target')
        .requestUri;
    final unrelated = objects
        .singleWhere((row) => row.collectionId == 'outside')
        .requestUri;
    await add('first', 'home', 'origin', [
      'SUMMARY:Origin',
      'LINK;VALUE=UID:shared-uid',
      'LINK;VALUE=UID:uri-target',
      'LINK;VALUE=URI:$uri',
      'LINK;VALUE=URI:$unrelated',
      'LINK;VALUE=XML-REFERENCE:https://example.invalid/linked.xml#xpointer(id(\'item\'))',
    ]);
    final repository = JournalRepository(db);
    final origin = await repository.read(
      (await repository.watchEntries().first).singleWhere(
        (entry) => entry.uid == 'origin',
      ),
    );
    expect(
      (await repository.relatedJournals(origin)).map((entry) => entry.title),
      unorderedEquals(['Local target', 'URI target']),
    );
    final storedLinks = origin.component.component.propertiesNamed('LINK');
    expect(storedLinks.map((p) => p.rawValue), contains(unrelated));
    expect(
      storedLinks.map((p) => p.parameterValue('VALUE')),
      contains('XML-REFERENCE'),
    );
  });

  test('nested journal authoring survives JSON drafts and durable patches', () {
    final raw = journal([
      'STATUS:FINAL',
      'BEGIN:PARTICIPANT',
      'UID:participant-1',
      'PARTICIPANT-TYPE:CONTACT',
      'SUMMARY;LANGUAGE=fr:First',
      'X-EXTENSION;X-PARAM="a,b":original',
      ' folded tail',
      'STATUS:FINAL',
      'BEGIN:VSTATUS',
      'STATUS:FINAL',
      'COMMENT;DERIVED=TRUE:Read only',
      'END:VSTATUS',
      'END:PARTICIPANT',
    ]);
    final original = IcalDocument.parse(raw).calendarComponents.single;
    final participant = JournalChildDraft(original.components.single, () {});
    addTearDown(participant.dispose);
    participant.fields
            .singleWhere((field) => field.name == 'SUMMARY')
            .value
            .text =
        'Second';
    final location = JournalChildDraft.create('VLOCATION', () {});
    participant.children.add(location);
    final summary = participant.fields.singleWhere(
      (field) => field.name == 'SUMMARY',
    );
    final unfinished = JournalParameterDraft.fromText(
      () {},
      '  ',
      'a\nb',
      true,
    );
    summary.parameters.add(unfinished);
    final reopened = JournalChildDraft.fromDraftJson(
      participant.toDraftJson(),
      () {},
    );
    addTearDown(reopened.dispose);
    final reopenedParameter = reopened.fields
        .singleWhere((field) => field.name == 'SUMMARY')
        .parameters
        .last;
    expect(reopenedParameter.name.text, '  ');
    expect(reopenedParameter.value.text, 'a\nb');
    expect(reopenedParameter.quoted, isTrue);
    expect(() => reopened.toComponent(validate: true), throwsFormatException);
    reopenedParameter.name.text = 'X-CUSTOM';
    final patch = DavMutationPatch(
      target: const IcalComponentKey(
        componentType: 'VJOURNAL',
        uid: 'journal-fixture',
      ),
      scope: DavMutationScope.object,
      operations: [
        DavPatchOperation.replaceJournalChildren([
          reopened.toComponent(validate: true),
        ]),
      ],
    );
    final effective = DavMutationPatch.fromJsonString(patch.toJsonString())
        .applyTo(raw, nowUtc: DateTime.utc(2026, 11, 26));
    expect(effective, contains('SUMMARY;LANGUAGE=fr;X-CUSTOM="a","b":Second'));
    expect(
      effective,
      contains('X-EXTENSION;X-PARAM="a,b":original\r\n folded tail'),
    );
    expect(effective, contains('COMMENT;DERIVED=TRUE:Read only'));
    final children = IcalDocument.parse(effective)
        .calendarComponents
        .single
        .components
        .single
        .components;
    expect(children.map((child) => child.name), ['VSTATUS', 'VLOCATION']);
    expect(
      children.last.firstProperty('UID')?.rawValue,
      endsWith('@busymax.local'),
    );
  });

  test('unrelated nested siblings can shift without changing derived status properties', () {
    const removable = [
      'BEGIN:VSTATUS',
      'STATUS:FINAL',
      'COMMENT:Removable',
      'END:VSTATUS',
    ];
    const protected = [
      'BEGIN:VSTATUS',
      'STATUS:FINAL',
      'COMMENT;DERIVED=TRUE:Retain this',
      'END:VSTATUS',
    ];
    for (final nested in [false, true]) {
      final raw = journal([
        'STATUS:FINAL',
        if (nested) ...[
          'BEGIN:PARTICIPANT',
          'UID:participant',
          'PARTICIPANT-TYPE:CONTACT',
          'STATUS:FINAL',
        ],
        ...removable,
        ...protected,
        if (nested) 'END:PARTICIPANT',
      ]);
      final component = IcalDocument.parse(raw).calendarComponents.single;
      final parent = nested ? component.components.single : component;
      final ordinary = parent.components.first;
      final derived = parent.components.last;
      String apply() {
        final patch = DavMutationPatch(
          target: const IcalComponentKey(
            componentType: 'VJOURNAL',
            uid: 'journal-fixture',
          ),
          scope: DavMutationScope.object,
          operations: [
            DavPatchOperation.replaceJournalChildren(component.components),
          ],
        );
        return DavMutationPatch.fromJsonString(patch.toJsonString())
            .applyTo(raw, nowUtc: DateTime.utc(2026, 11, 26));
      }

      parent.children.remove(ordinary);
      expect(apply(), isNot(contains('COMMENT:Removable')));
      parent.children.add(ordinary);
      expect(
        apply().indexOf('COMMENT:Removable'),
        greaterThan(apply().indexOf('Retain this')),
      );
      derived.firstProperty('COMMENT')!
        ..rawValue = 'Changed'
        ..isDirty = true;
      expect(
        apply,
        throwsA(
          isA<DavException>().having(
            (error) => error.code,
            'code',
            'IcalDerivedJournalProperty',
          ),
        ),
      );
    }
  });

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
    final month = DateTime.utc(2026, 11);
    final originals = repository.occurrences(repeating, month);
    final single = repository.inspectOccurrence(
      repeating,
      originals[1],
      thisAndFuture: false,
    );
    await repository.editOccurrence(single, [
      DavPatchOperation.setText('SUMMARY', 'Moved note'),
      DavPatchOperation.setRaw('DTSTART', '20261128', preserveParameters: true),
    ]);
    final moved = await repository.read(repeating.entry);
    final movedRow = repository
        .occurrences(moved, month)
        .singleWhere((item) => item.recurrenceId.rawValue == '20261127');
    expect(movedRow.start.rawValue, '20261128');
    expect(movedRow.summary, 'Moved note');
    expect(
      moved.effectiveRawIcs,
      contains('RECURRENCE-ID;VALUE=DATE:20261127'),
    );
    await repository.deleteOccurrence(
      repository.inspectOccurrence(moved, movedRow, thisAndFuture: false),
    );
    final deleted = await repository.read(repeating.entry);
    expect(deleted.effectiveRawIcs, contains('EXDATE;VALUE=DATE:20261127'));
    final dated = repository.occurrences(deleted, month);
    expect(dated.map((row) => row.recurrenceId.rawValue), [
      '20261126',
      '20261128',
      '20261129',
      '20261130',
    ]);
    await repository.cancelOccurrenceRange(
      repository.inspectOccurrence(deleted, dated[2], thisAndFuture: true),
    );
    final ranged = await repository.read(repeating.entry);
    expect(
      repository.occurrences(ranged, month).map((row) => row.isCancelled),
      [false, false, true, true],
    );
    expect(
      ranged.effectiveRawIcs,
      contains('RECURRENCE-ID;VALUE=DATE;RANGE=THISANDFUTURE:20261129'),
    );
    await repository.deleteOccurrenceRange(
      repository.inspectOccurrence(
        ranged,
        repository.occurrences(ranged, month)[2],
        thisAndFuture: true,
      ),
    );
    final trimmed = await repository.read(repeating.entry);
    expect(trimmed.effectiveRawIcs, contains('RRULE:FREQ=DAILY;COUNT=3'));
    expect(trimmed.effectiveRawIcs, contains('EXDATE;VALUE=DATE:20261127'));
    expect(trimmed.effectiveRawIcs, isNot(contains('RANGE=THISANDFUTURE')));
    expect(
      repository
          .occurrences(trimmed, month)
          .map((row) => row.recurrenceId.rawValue),
      ['20261126', '20261128'],
    );
    expect(ranged.effectiveRawIcs, isNot(contains('DTEND')));
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

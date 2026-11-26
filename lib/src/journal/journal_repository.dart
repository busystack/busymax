import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../dav/dav_errors.dart';
import '../dav/ical/ical_document.dart';
import '../dav/ical/ical_recurrence.dart';
import '../dav/ical/ical_semantics.dart';
import '../dav/ical/ical_timezone.dart';
import '../dav/mutation/dav_conditional_mutation_service.dart';
import '../dav/mutation/dav_mutation_patch.dart';
import '../dav/mutation/dav_pending_operation_selection.dart';
import '../dav/mutation/dav_pending_operations.dart';
import '../dav/storage/dav_collection_capabilities.dart';
import '../dav/storage/dav_object_repository.dart';
import '../db/app_database.dart';
import '../providers/busy_provider.dart';
import 'journal_component.dart';

enum JournalDateFilter { all, dated, undated }

enum JournalFrequency { daily, weekly, monthly, yearly }

final class JournalSnapshot {
  const JournalSnapshot({
    required this.entry,
    required this.collection,
    required this.component,
    required this.effectiveRawIcs,
  });

  final DavJournalEntry entry;
  final DavCollection collection;
  final JournalComponent component;
  final String effectiveRawIcs;

  IcalComponentKey get key => IcalComponentKey(
    componentType: 'VJOURNAL',
    uid: entry.uid,
    recurrenceIdKey: entry.recurrenceIdKey,
  );
}

final class JournalOccurrenceDraft {
  const JournalOccurrenceDraft(this.entry, this.component, this.thisAndFuture);

  final JournalSnapshot entry;
  final JournalSnapshot component;
  final bool thisAndFuture;
}

final class JournalRepository {
  JournalRepository(this.database, {DateTime Function()? nowUtc})
    : _queue = DavPendingOperationQueue(database: database),
      _objects = DavObjectRepository(database: database),
      _nowUtc = nowUtc ?? DateTime.now;

  final AppDatabase database;
  final DavPendingOperationQueue _queue;
  final DavObjectRepository _objects;
  final DateTime Function() _nowUtc;

  Future<DavJournalDraft?> readDraft(String id) => (database.select(
    database.davJournalDrafts,
  )..where((draft) => draft.id.equals(id))).getSingleOrNull();

  Future<void> saveDraft({
    required String id,
    required String collectionId,
    required String? baselineDigest,
    required String contentJson,
  }) => database
      .into(database.davJournalDrafts)
      .insertOnConflictUpdate(
        DavJournalDraftsCompanion.insert(
          id: id,
          collectionId: collectionId,
          baselineDigest: Value(baselineDigest),
          contentJson: contentJson,
        ),
      );

  Future<void> discardDraft(String id) => (database.delete(
    database.davJournalDrafts,
  )..where((draft) => draft.id.equals(id))).go();

  Future<bool> hasDrafts(String collectionId) async =>
      (await (database.select(database.davJournalDrafts)
                ..where((draft) => draft.collectionId.equals(collectionId))
                ..limit(1))
              .get())
          .isNotEmpty;

  Stream<List<DavCollection>> watchSources() {
    final accounts = database.accounts;
    final sources = database.davCollections;
    final query =
        database.select(sources).join([
            innerJoin(accounts, accounts.id.equalsExp(sources.accountId)),
          ])
          ..where(
            accounts.journalsEnabled &
                sources.journalProjectionEnabled &
                sources.deleted.not() &
                sources.serverMissing.not(),
          )
          ..orderBy([
            OrderingTerm.asc(sources.displayName),
            OrderingTerm.asc(sources.id),
          ]);
    return query.watch().map(
      (rows) =>
          rows.map((row) => row.readTable(sources)).toList(growable: false),
    );
  }

  Stream<List<DavJournalEntry>> watchEntries({
    String? collectionId,
    String search = '',
    JournalDateFilter dateFilter = JournalDateFilter.all,
    int limit = 100,
    int offset = 0,
  }) {
    final entries = database.davJournalEntries;
    final collections = database.davCollections;
    final accounts = database.accounts;
    final pending = database.pendingOps;
    final pendingDeletes = database.selectOnly(pending)
      ..addColumns([pending.davObjectId])
      ..where(
        pending.davObjectId.equalsExp(entries.davObjectId) &
            pending.operationType.equals('dav.delete') &
            pending.state.isIn(davUnresolvedPendingStates) &
            pending.state.equals('conflict').not() &
            pending.state.equals('permission_blocked').not(),
      );
    final term = search.trim().toLowerCase();
    final query =
        database.select(entries).join([
            innerJoin(
              collections,
              collections.id.equalsExp(entries.collectionId),
            ),
            innerJoin(accounts, accounts.id.equalsExp(entries.accountId)),
          ])
          ..where(
            accounts.journalsEnabled &
                collections.journalProjectionEnabled &
                collections.journalsSelected &
                collections.deleted.not() &
                collections.serverMissing.not() &
                notExistsQuery(pendingDeletes) &
                (collectionId == null
                    ? const Constant(true)
                    : entries.collectionId.equals(collectionId)) &
                (term.isEmpty
                    ? const Constant(true)
                    : entries.searchText.contains(term)) &
                (switch (dateFilter) {
                  JournalDateFilter.all => const Constant(true),
                  JournalDateFilter.dated => entries.startValue.isNotNull(),
                  JournalDateFilter.undated => entries.startValue.isNull(),
                }),
          )
          ..orderBy([
            OrderingTerm.desc(entries.startValue),
            OrderingTerm.asc(entries.componentId),
          ])
          ..limit(limit, offset: offset);
    return query.watch().map(
      (rows) =>
          rows.map((row) => row.readTable(entries)).toList(growable: false),
    );
  }

  Stream<PendingOp?> watchPending(String objectId) =>
      (database.select(database.pendingOps)
            ..where(
              (r) =>
                  r.davObjectId.equals(objectId) &
                  r.entityType.equals('journal') &
                  r.state.isIn(davUnresolvedPendingStates),
            )
            ..orderBy([(r) => OrderingTerm.desc(r.createdAtUtc)])
            ..limit(1))
          .watchSingleOrNull();

  Stream<DavConflictSnapshot?> watchConflict(String id) =>
      (database.select(database.davConflictSnapshots)
            ..where((row) => row.id.equals(id) & row.resolvedAtUtc.isNull()))
          .watchSingleOrNull();

  Future<JournalSnapshot> read(DavJournalEntry entry) =>
      database.transaction(() async {
        final collection = await _source(entry.accountId, entry.collectionId);
        final raw = await _queue.exportRawIcsForObject(
          accountId: entry.accountId,
          collectionId: entry.collectionId,
          objectId: entry.davObjectId,
        );
        final component = IcalDocumentPatcher(IcalDocument.parse(raw))
            .requireComponent(
              IcalComponentKey(
                componentType: 'VJOURNAL',
                uid: entry.uid,
                recurrenceIdKey: entry.recurrenceIdKey,
              ),
            );
        return JournalSnapshot(
          entry: entry,
          collection: collection,
          component: JournalComponent(component),
          effectiveRawIcs: raw,
        );
      });

  Future<void> create(
    DavCollection source, {
    String? title,
    String? status,
    IcalProperty? start,
    List<DavRawPropertyValue> descriptions = const [],
    List<DavRawPropertyValue> attachments = const [],
    List<IcalProperty> details = const [],
    List<IcalComponent> children = const [],
    JournalFrequency? frequency,
  }) {
    if (frequency != null && parseIcalTemporal(start) == null) {
      throw const DavException(
        kind: DavErrorKind.invalidCalendarData,
        code: 'IcalJournalRecurrenceNeedsStart',
        safeMessage: 'A repeating journal needs a date.',
      );
    }
    final uid = '${const Uuid().v4()}@busymax.local';
    final timestamp = _revisionTime(_nowUtc());
    final component = IcalComponent(
      name: 'VJOURNAL',
      originalBeginLine: 'BEGIN:VJOURNAL',
      originalEndLine: 'END:VJOURNAL',
      structurallyDirty: true,
      children: [
        _property('UID', uid),
        _property('DTSTAMP', timestamp),
        if (title != null) _property('SUMMARY', encodeIcalText(title)),
        if (status != null) _property('STATUS', status),
        if (start != null) start.deepCopy(),
        if (frequency != null &&
            details.every((property) => property.name != 'RRULE'))
          _property('RRULE', 'FREQ=${frequency.name.toUpperCase()}'),
        ...details.map((property) => property.deepCopy()),
        for (final description in descriptions)
          _property('DESCRIPTION', description.value, description.parameters),
        for (final attachment in attachments)
          _property('ATTACH', attachment.value, attachment.parameters),
        ...children.map((child) => child.deepCopy()),
      ],
    );
    return _createRaw(
      source,
      uid,
      IcalDocument.create(components: [component]).serialize(),
    );
  }

  List<IcalOccurrence> occurrences(JournalSnapshot snapshot, DateTime month) =>
      IcalRecurrenceExpander().expand(
        IcalSemanticDocument.parse(snapshot.effectiveRawIcs),
        rangeStartUtc: DateTime.utc(month.year, month.month),
        rangeEndUtc: DateTime.utc(month.year, month.month + 1),
      );

  JournalOccurrenceDraft inspectOccurrence(
    JournalSnapshot source,
    IcalOccurrence occurrence, {
    required bool thisAndFuture,
  }) {
    if (!thisAndFuture &&
        occurrence.override?.recurrenceRange == 'THISANDFUTURE') {
      throw const DavException(
        kind: DavErrorKind.unsupportedComponent,
        code: 'IcalJournalOccurrenceRangeRequired',
        safeMessage: 'This entry starts a range of changes. Choose this and future occurrences.',
      );
    }
    final component = occurrence.effectiveComponent.documentComponent
        .deepCopy();
    final original = occurrence.override?.documentComponent;
    component.children.removeWhere(
      (node) =>
          node is IcalProperty &&
          const {
            'RRULE',
            'RDATE',
            'EXDATE',
            'RECURRENCE-ID',
            'DTSTART',
          }.contains(node.name),
    );
    final id = _occurrenceDate(
      'RECURRENCE-ID',
      occurrence.recurrenceId,
      previous: original?.firstProperty('RECURRENCE-ID'),
      thisAndFuture: thisAndFuture,
    );
    component.children.add(id);
    component.children.add(
      _occurrenceDate(
        'DTSTART',
        occurrence.start,
        previous: original?.firstProperty('DTSTART'),
      ),
    );
    component.structurallyDirty = true;
    return JournalOccurrenceDraft(
      source,
      JournalSnapshot(
        entry: source.entry.copyWith(
          recurrenceIdKey: Value(icalRecurrenceIdKey(id)),
        ),
        collection: source.collection,
        component: JournalComponent(component),
        effectiveRawIcs: source.effectiveRawIcs,
      ),
      thisAndFuture,
    );
  }

  Future<void> editOccurrence(
    JournalOccurrenceDraft draft,
    List<DavPatchOperation> operations,
  ) => database.transaction(() async {
    if (operations.isEmpty) return;
    await _checkForLocalChange(draft.entry);
    final target = draft.component.key;
    final document = IcalDocument.parse(draft.entry.effectiveRawIcs);
    final existing = document.calendarComponents.any(
      (c) =>
          c.name == 'VJOURNAL' &&
          icalRecurrenceIdKey(c.firstProperty('RECURRENCE-ID')) ==
              target.recurrenceIdKey,
    );
    final patch = DavMutationPatch(
      target: target,
      scope: DavMutationScope.occurrence,
      operations: [
        if (existing) DavPatchOperation.removeComponent(),
        DavPatchOperation.addComponent(draft.component.component.component),
        ...operations,
        DavPatchOperation.reviseJournal(_nowUtc()),
      ],
    );
    await _queueEdit(draft.entry.entry, patch);
  });

  Future<void> deleteOccurrence(JournalOccurrenceDraft draft) =>
      database.transaction(() async {
        if (draft.thisAndFuture) {
          throw ArgumentError('A single occurrence is required.');
        }
        await _checkForLocalChange(draft.entry);
        final selection = draft.component.key;
        final document = IcalDocument.parse(draft.entry.effectiveRawIcs);
        final patcher = IcalDocumentPatcher(document);
        final entries = document.calendarComponents.where(
          (node) => node.name == 'VJOURNAL',
        );
        final master = entries
            .where((entry) => entry.firstProperty('RECURRENCE-ID') == null)
            .firstOrNull;
        if (master == null && entries.length == 1) {
          await deleteResource(draft.entry);
          return;
        }
        if (entries.any(
          (entry) =>
              icalRecurrenceIdKey(entry.firstProperty('RECURRENCE-ID')) ==
              selection.recurrenceIdKey,
        )) {
          patcher.removeComponent(selection);
        }
        if (master != null) {
          final identity = draft.component.component.component.firstProperty(
            'RECURRENCE-ID',
          )!;
          master.children.add(
            _property(
              'EXDATE',
              identity.rawValue,
              identity.parameters
                  .where((p) => p.name == 'VALUE' || p.name == 'TZID')
                  .toList(),
            ),
          );
          master.structurallyDirty = true;
        }
        final base = master == null
            ? draft.entry.key
            : IcalComponentKey(componentType: 'VJOURNAL', uid: selection.uid);
        await _queueEdit(
          draft.entry.entry,
          DavMutationPatch(
            target: base,
            scope: DavMutationScope.occurrence,
            operations: [
              DavPatchOperation.replaceJournalResource(document.serialize()),
              if (master != null) DavPatchOperation.reviseJournal(_nowUtc()),
            ],
          ),
        );
      });

  Future<void> cancelOccurrenceRange(JournalOccurrenceDraft draft) =>
      database.transaction(() async {
        if (!draft.thisAndFuture) {
          throw ArgumentError('A recurrence range is required.');
        }
        await _checkForLocalChange(draft.entry);
        final base = IcalSemanticDocument.parse(draft.entry.effectiveRawIcs);
        final resolver = IcalTimeZoneResolver.fromDocument(base);
        final selection = draft.component.key;
        final component = draft.component.component.component;
        final first = resolver.toUtc(
          parseIcalTemporal(component.firstProperty('RECURRENCE-ID'))!,
        );
        final existing = base.components.any(
          (c) => c.recurrenceIdKey == selection.recurrenceIdKey,
        );
        final stamp = _nowUtc();
        DavPatchOperation cancel() => DavPatchOperation.setRaw(
          'STATUS',
          'CANCELLED',
          preserveParameters: true,
        );
        final candidate = DavMutationPatch(
          target: selection,
          scope: DavMutationScope.occurrence,
          operations: [
            if (existing) DavPatchOperation.removeComponent(),
            DavPatchOperation.addComponent(component),
            cancel(),
            DavPatchOperation.reviseJournal(stamp),
          ],
        ).applyTo(draft.entry.effectiveRawIcs, nowUtc: stamp);
        final result = IcalDocument.parse(candidate);
        for (final sibling in result.calendarComponents.where(
          (c) => c.name == 'VJOURNAL',
        )) {
          final identity = parseIcalTemporal(
            sibling.firstProperty('RECURRENCE-ID'),
          );
          if (identity == null || !resolver.toUtc(identity).isAfter(first)) {
            continue;
          }
          for (final name in const ['STATUS', 'DTSTAMP', 'LAST-MODIFIED']) {
            final property = sibling.firstProperty(name);
            if (name == 'STATUS' && property == null) {
              sibling.children.add(_property('STATUS', 'CANCELLED'));
              sibling.structurallyDirty = true;
            } else if (property != null &&
                (name == 'STATUS' || !isDerivedJournalProperty(property))) {
              property
                ..rawValue = name == 'STATUS'
                    ? 'CANCELLED'
                    : _revisionTime(stamp)
                ..isDirty = true;
            }
          }
        }
        await _queueEdit(
          draft.entry.entry,
          DavMutationPatch(
            target: draft.entry.key,
            scope: DavMutationScope.object,
            operations: [
              DavPatchOperation.replaceJournalResource(result.serialize()),
            ],
          ),
        );
      });

  Future<void> deleteOccurrenceRange(
    JournalOccurrenceDraft draft,
  ) => database.transaction(() async {
    if (!draft.thisAndFuture) {
      throw ArgumentError('A recurrence range is required.');
    }
    await _checkForLocalChange(draft.entry);
    final raw = draft.entry.effectiveRawIcs;
    final document = IcalDocument.parse(raw);
    final semantic = IcalSemanticDocument.fromDocument(document);
    final resolver = IcalTimeZoneResolver.fromDocument(semantic);
    final identity = draft.component.component.component.firstProperty(
      'RECURRENCE-ID',
    )!;
    final cutoff = parseIcalTemporal(identity)!;
    bool before(IcalTemporalValue time) {
      if (time.kind == cutoff.kind && time.timeZoneId == cutoff.timeZoneId) {
        return time.rawValue.compareTo(cutoff.rawValue) < 0;
      }
      return resolver.toUtc(time).isBefore(resolver.toUtc(cutoff));
    }

    final master = semantic.components
        .where((item) => item.recurrenceId == null)
        .firstOrNull;
    document.root.children.removeWhere((node) {
      if (node is! IcalComponent || node.name != 'VJOURNAL') return false;
      final date = parseIcalTemporal(node.firstProperty('RECURRENCE-ID'));
      return date != null && !before(date);
    });
    if (master != null) {
      final component = master.documentComponent;
      final rules = component.propertiesNamed('RRULE').toList();
      if (rules.length > 1) {
        throw const DavException(
          kind: DavErrorKind.unsupportedComponent,
          code: 'IcalJournalUndefinedRecurrence',
          safeMessage: 'This series has multiple recurrence rules. Use a single rule before deleting a range.',
        );
      }
      final anchor = master.start!;
      final keepAnchor = before(anchor);
      if (rules.isNotEmpty) {
        final rule = rules.single;
        var count = 0;
        if (keepAnchor) {
          final ruleMaster = component.deepCopy();
          ruleMaster.children.removeWhere(
            (node) =>
                node is IcalProperty &&
                const {'RDATE', 'EXDATE'}.contains(node.name),
          );
          final ruleDocument = IcalSemanticDocument.fromDocument(
            IcalDocument.create(
              components: [ruleMaster, ...semantic.timeZones],
            ),
          );
          count = IcalRecurrenceExpander()
              .expand(
                ruleDocument,
                rangeStartUtc: resolver
                    .toUtc(anchor)
                    .subtract(const Duration(days: 2)),
                rangeEndUtc: resolver
                    .toUtc(cutoff)
                    .add(const Duration(days: 2)),
              )
              .where((occurrence) => before(occurrence.recurrenceId))
              .length;
        }
        if (count <= 1) {
          component.children.remove(rule);
        } else {
          rule
            ..rawValue = [
              ...rule.rawValue
                  .split(';')
                  .where(
                    (part) =>
                        !part.toUpperCase().startsWith('COUNT=') &&
                        !part.toUpperCase().startsWith('UNTIL='),
                  ),
              'COUNT=$count',
            ].join(';')
            ..isDirty = true;
        }
      }
      for (final property
          in component.properties
              .where((node) => const {'RDATE', 'EXDATE'}.contains(node.name))
              .toList()) {
        final values = property.rawValue.split(',');
        final retained = values.where((value) {
          final start = _property(
            property.name,
            value.split('/').first,
            property.parameters
                .where(
                  (parameter) =>
                      parameter.name != 'VALUE' ||
                      parameter.values.firstOrNull?.toUpperCase() != 'PERIOD',
                )
                .toList(),
          );
          final date = parseIcalTemporal(start);
          if (date == null) {
            throw const DavException(
              kind: DavErrorKind.invalidCalendarData,
              code: 'IcalInvalidJournalRecurrenceDate',
              safeMessage:
                  'Repair an invalid recurrence date before deleting a range.',
            );
          }
          return before(date);
        }).toList();
        if (retained.isEmpty) {
          component.children.remove(property);
        } else if (retained.length != values.length) {
          property
            ..rawValue = retained.join(',')
            ..isDirty = true;
        }
      }
      if (!keepAnchor) {
        final hasHistory =
            component.propertiesNamed('RDATE').isNotEmpty ||
            document.calendarComponents
                    .where((c) => c.name == 'VJOURNAL')
                    .length >
                1;
        if (hasHistory) {
          component.children.add(_occurrenceDate('EXDATE', anchor));
        } else {
          document.root.children.remove(component);
        }
      }
    }
    if (!document.calendarComponents.any((c) => c.name == 'VJOURNAL')) {
      await deleteResource(draft.entry);
      return;
    }
    document.root.structurallyDirty = true;
    await _queueEdit(
      draft.entry.entry,
      DavMutationPatch(
        target: master == null
            ? draft.entry.key
            : IcalComponentKey(
                componentType: 'VJOURNAL',
                uid: draft.entry.entry.uid,
              ),
        scope: DavMutationScope.occurrence,
        operations: [
          DavPatchOperation.replaceJournalResource(document.serialize()),
          if (master != null) DavPatchOperation.reviseJournal(_nowUtc()),
        ],
      ),
    );
  });

  Future<void> duplicate(JournalSnapshot snapshot) {
    final uid = '${const Uuid().v4()}@busymax.local';
    final document = IcalDocument.parse(snapshot.effectiveRawIcs);
    final timestamp = _revisionTime(_nowUtc());
    for (final component in document.calendarComponents.where(
      (c) => c.name == 'VJOURNAL',
    )) {
      component.firstProperty('UID')!
        ..rawValue = uid
        ..isDirty = true;
      for (final name in const [
        'DTSTAMP',
        'CREATED',
        'LAST-MODIFIED',
        'SEQUENCE',
      ]) {
        final property = component.firstProperty(name);
        if (property != null) {
          property
            ..rawValue = name == 'SEQUENCE' ? '0' : timestamp
            ..isDirty = true;
        }
      }
    }
    return _createRaw(snapshot.collection, uid, document.serialize());
  }

  Future<void> _createRaw(DavCollection source, String uid, String raw) =>
      database.transaction(() async {
        final collection = await _source(source.accountId, source.id);
        final member = '${const Uuid().v4()}.ics';
        final target = Uri.parse(
          collection.requestUri.endsWith('/')
              ? collection.requestUri
              : '${collection.requestUri}/',
        ).resolve(member);
        final complete = completeIcalTimeZones(raw);
        final id = await _objects.projectPendingImport(
          accountId: source.accountId,
          collectionId: source.id,
          nowUtc: DateTime.now().toUtc(),
          object: DavPreparedObject.parse(
            hrefKey: target.path,
            requestUri: target,
            etag: null,
            contentType: 'text/calendar',
            rawIcsBody: complete,
          ),
        );
        await _queue.enqueueCreate(
          accountId: source.accountId,
          collectionId: source.id,
          localObjectId: id,
          object: DavNewObject(
            uid: uid,
            initialMemberName: member,
            rawIcs: complete,
            componentType: 'VJOURNAL',
          ),
        );
      });

  Future<void> edit(
    JournalSnapshot editing,
    List<DavPatchOperation> operations,
  ) => database.transaction(() async {
    if (operations.isEmpty) return;
    final entry = editing.entry;
    await _checkForLocalChange(editing);
    final account = await (database.select(
      database.accounts,
    )..where((r) => r.id.equals(entry.accountId))).getSingle();
    final now = _nowUtc().toUtc();
    final scope = entry.recurrenceIdKey == null
        ? DavMutationScope.recurrenceMaster
        : DavMutationScope.recurrenceException;
    final changes = DavMutationPatch(
      target: editing.key,
      scope: scope,
      operations: operations,
    );
    final edited = changes.applyTo(editing.effectiveRawIcs, nowUtc: now);
    if (edited == editing.effectiveRawIcs) return;
    final previous = editing.component.component;
    final updated = IcalDocumentPatcher(IcalDocument.parse(edited))
        .requireComponent(editing.key);
    final organizer =
        previous.firstProperty('ORGANIZER')?.rawValue ??
        updated.firstProperty('ORGANIZER')?.rawValue;
    final sequence = previous.firstProperty('SEQUENCE');
    final significant = changedIcalProperties(previous, updated).any(
      const {
        'DTSTART',
        'RRULE',
        'RDATE',
        'EXDATE',
        'STATUS',
        'ORGANIZER',
        'ATTENDEE',
      }.contains,
    );
    var advanceSequence = false;
    if (significant &&
        organizer != null &&
        !isDerivedJournalProperty(sequence)) {
      final service =
          await (database.select(database.davAccountServices)
                ..where((row) => row.accountId.equals(entry.accountId)))
              .getSingleOrNull();
      final addresses =
          jsonDecode(service?.calendarUserAddressesJson ?? '[]') as List;
      advanceSequence = addresses.contains(organizer);
    }
    final patch = DavMutationPatch(
      target: editing.key,
      scope: scope,
      operations: [
        ...operations,
        if (advanceSequence)
          DavPatchOperation.setRaw(
            'SEQUENCE',
            '${(int.tryParse(sequence?.rawValue ?? '') ?? 0) + 1}',
            preserveParameters: true,
          ),
        DavPatchOperation.reviseJournal(now),
      ],
    );
    await _queueEdit(
      entry,
      patch,
      provider: BusyProviderCodec.requireStorageValue(account.provider),
    );
  });

  Future<void> _queueEdit(
    DavJournalEntry entry,
    DavMutationPatch patch, {
    BusyProvider? provider,
  }) async {
    final account = provider == null
        ? await (database.select(
            database.accounts,
          )..where((r) => r.id.equals(entry.accountId))).getSingle()
        : null;
    await _queue.enqueueUpdate(
      accountId: entry.accountId,
      collectionId: entry.collectionId,
      objectId: entry.davObjectId,
      patch: patch,
    );
    final raw = await _queue.exportRawIcsForObject(
      accountId: entry.accountId,
      collectionId: entry.collectionId,
      objectId: entry.davObjectId,
    );
    await _objects.projectLocalMutationCandidate(
      accountId: entry.accountId,
      collectionId: entry.collectionId,
      objectId: entry.davObjectId,
      provider:
          provider ?? BusyProviderCodec.requireStorageValue(account!.provider),
      candidateRawIcs: raw,
    );
  }

  Future<void> deleteResource(JournalSnapshot editing) =>
      database.transaction(() async {
        final entry = editing.entry;
        await _checkForLocalChange(editing);
        await _queue.enqueueDelete(
          accountId: entry.accountId,
          collectionId: entry.collectionId,
          objectId: entry.davObjectId,
          target: editing.key,
        );
      });

  Future<void> move(JournalSnapshot editing, DavCollection destination) =>
      database.transaction(() async {
        await _checkForLocalChange(editing);
        final document = IcalDocument.parse(editing.effectiveRawIcs);
        bool hasCollectionReference(IcalComponent component) =>
            component.properties.any((property) {
              final type = property.parameterValue('VALUE')?.toUpperCase();
              return (property.name == 'LINK' && type == 'UID') ||
                  property.name == 'RELATED-TO' &&
                      (type == null || type == 'UID');
            }) ||
            component.components.any(hasCollectionReference);
        if (document.calendarComponents.any(hasCollectionReference)) {
          throw const DavException(
            kind: DavErrorKind.unsupportedComponent,
            code: 'IcalJournalCollectionReference',
            safeMessage: 'This journal links to entries by UID. Use collection-independent links before moving it.',
          );
        }
        await _queue.enqueueMove(
          accountId: editing.entry.accountId,
          sourceCollectionId: editing.entry.collectionId,
          destinationAccountId: destination.accountId,
          destinationCollectionId: destination.id,
          objectId: editing.entry.davObjectId,
          target: editing.key,
        );
      });

  Future<void> _checkForLocalChange(JournalSnapshot editing) async {
    final current = await read(editing.entry);
    if (current.effectiveRawIcs != editing.effectiveRawIcs) {
      throw const DavException(
        kind: DavErrorKind.conflict,
        code: 'DavJournalChangedWhileEditing',
        safeMessage: 'The journal changed after the editor opened.',
      );
    }
  }

  Future<DavCollection> _source(String accountId, String id) async {
    final source =
        await (database.select(database.davCollections)..where(
              (r) =>
                  r.accountId.equals(accountId) &
                  r.id.equals(id) &
                  r.journalProjectionEnabled &
                  r.deleted.not() &
                  r.serverMissing.not(),
            ))
            .getSingle();
    if (!collectionCapabilitiesFromStored(source).canRead) {
      throw const DavException(
        kind: DavErrorKind.authorization,
        code: 'DavJournalSourceUnavailable',
        safeMessage: 'This journal source is unavailable.',
      );
    }
    return source;
  }
}

IcalProperty _property(
  String name,
  String value, [
  List<IcalParameter> parameters = const [],
]) => IcalProperty(
  group: null,
  name: name,
  parameters: parameters,
  rawValue: value,
  originalPhysicalLines: const [],
  isDirty: true,
);

String _revisionTime(DateTime time) =>
    '${time.toUtc().toIso8601String().split('.').first.replaceAll(RegExp('[-:]'), '')}Z';

IcalProperty _occurrenceDate(
  String name,
  IcalTemporalValue time, {
  IcalProperty? previous,
  bool thisAndFuture = false,
}) => IcalProperty(
  group: previous?.group,
  name: name,
  rawValue: time.rawValue,
  parameters: [
    for (final parameter in previous?.parameters ?? const <IcalParameter>[])
      if (!const {'VALUE', 'TZID', 'RANGE'}.contains(parameter.name)) parameter,
    if (time.isDate)
      const IcalParameter(name: 'VALUE', values: ['DATE'], wasQuoted: false),
    if (time.timeZoneId case final zone?)
      IcalParameter(name: 'TZID', values: [zone], wasQuoted: false),
    if (thisAndFuture)
      const IcalParameter(
        name: 'RANGE',
        values: ['THISANDFUTURE'],
        wasQuoted: false,
      ),
  ],
  originalPhysicalLines: const [],
  isDirty: true,
);

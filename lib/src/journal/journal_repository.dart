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
import 'journal_date_conversion.dart';
import 'journal_itip.dart';

enum JournalDateFilter { all, dated, undated }

enum JournalFrequency { daily, weekly, monthly, yearly }

final class JournalSnapshot {
  const JournalSnapshot({
    required this.entry,
    required this.collection,
    required this.component,
    required this.effectiveRawIcs,
    this.pendingRecovery,
  });

  final DavJournalEntry entry;
  final DavCollection collection;
  final JournalComponent component;
  final String effectiveRawIcs;
  final DavJournalPendingRecovery? pendingRecovery;

  IcalComponentKey get key => IcalComponentKey(
    componentType: 'VJOURNAL',
    uid: entry.uid,
    recurrenceIdKey: entry.recurrenceIdKey,
  );
}

final class JournalOccurrenceDraft {
  const JournalOccurrenceDraft(
    this.entry,
    this.component,
    this.thisAndFuture,
    this.originalException,
  );

  final JournalSnapshot entry;
  final JournalSnapshot component;
  final bool thisAndFuture;
  final IcalComponentKey? originalException;
}

sealed class JournalLinkTarget {
  const JournalLinkTarget();
}

final class LinkedJournal extends JournalLinkTarget {
  const LinkedJournal(this.entry);
  final DavJournalEntry entry;
}

final class LinkedEvent extends JournalLinkTarget {
  const LinkedEvent(this.event);
  final CalendarEvent event;
}

final class LinkedTask extends JournalLinkTarget {
  const LinkedTask(this.task);
  final Task task;
}

final class LinkedXml extends JournalLinkTarget {
  const LinkedXml(this.uri);
  final Uri uri;
}

final class UnresolvedJournalLink extends JournalLinkTarget {
  const UnresolvedJournalLink(this.valueType, this.value);

  final String valueType;
  final String value;
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

  Stream<DavJournalDraft?> watchDraft(String id) => (database.select(
    database.davJournalDrafts,
  )..where((draft) => draft.id.equals(id))).watchSingleOrNull();

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

  /// Copies editor state to the new-entry editor, leaving the original draft
  /// independently recoverable. The user reviews the copy before saving.
  Future<DavCollection> prepareDraftRecovery(
    DavCollection source,
    String content,
  ) => database.transaction(() async {
    final live = await _source(source.accountId, source.id);
    if (!live.journalInventoryComplete ||
        !collectionCapabilitiesFromStored(live).canAttemptCreateJournal) {
      throw const DavException(
        kind: DavErrorKind.authorization,
        code: 'DavJournalRecoveryDestinationUnavailable',
        safeMessage: 'Refresh a writable journal collection before recovering the draft.',
      );
    }
    final id = 'new:${source.id}';
    if (await readDraft(id) != null) {
      throw const DavException(
        kind: DavErrorKind.conflict,
        code: 'DavExistingNewJournalDraft',
        safeMessage: 'Save or discard the existing new-entry draft before recovering this one.',
      );
    }
    await saveDraft(
      id: id,
      collectionId: live.id,
      baselineDigest: null,
      contentJson: content,
    );
    return live;
  });

  Future<bool> hasDrafts(String collectionId) async =>
      (await (database.select(database.davJournalDrafts)
                ..where((draft) => draft.collectionId.equals(collectionId))
                ..limit(1))
              .get())
          .isNotEmpty;

  Stream<List<DavCollection>> watchSources() =>
      _sourcesQuery().watch().map(_readSources);

  Future<List<DavCollection>> listSources() =>
      _sourcesQuery().get().then(_readSources);

  List<DavCollection> _readSources(List<TypedResult> rows) => [
    for (final row in rows) row.readTable(database.davCollections),
  ];

  Selectable<TypedResult> _sourcesQuery() {
    final accounts = database.accounts;
    final sources = database.davCollections;
    return database.select(sources).join([
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
  }

  Stream<List<DavJournalEntry>> watchEntries({
    String? collectionId,
    String search = '',
    JournalDateFilter dateFilter = JournalDateFilter.all,
    int limit = 100,
    int offset = 0,
  }) => _entriesQuery(
    collectionIds: collectionId == null ? null : {collectionId},
    search: search,
    dateFilter: dateFilter,
    limit: limit,
    offset: offset,
  ).watch().map(_projectedEntries);

  Future<List<DavJournalEntry>> listEntries({Set<String>? collectionIds}) =>
      _entriesQuery(collectionIds: collectionIds).get().then(_projectedEntries);

  List<DavJournalEntry> _projectedEntries(List<TypedResult> rows) => rows
      .map((row) => row.readTable(database.davJournalEntries))
      .toList(growable: false);

  Selectable<TypedResult> _entriesQuery({
    Set<String>? collectionIds,
    String search = '',
    JournalDateFilter dateFilter = JournalDateFilter.all,
    int? limit,
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
                (collectionIds == null
                    ? const Constant(true)
                    : entries.collectionId.isIn(collectionIds)) &
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
          ]);
    if (limit != null) query.limit(limit, offset: offset);
    return query;
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

  Future<List<DavJournalEntry>> relatedJournals(JournalSnapshot origin) async =>
      (await relatedEntries(origin))
          .whereType<LinkedJournal>()
          .map((match) => match.entry)
          .toList();

  /// Looks up references only in the originating account. UID links
  /// are collection-local. External and ambiguous references remain intact.
  Future<List<JournalLinkTarget>> relatedEntries(JournalSnapshot origin) async {
    await _source(origin.entry.accountId, origin.entry.collectionId);
    final uids = <String>{};
    final uris = <String, Set<String>>{};
    final xml = <Uri>{};
    final references = <(String, String)>{};
    for (final property in origin.component.component.properties) {
      if (property.name != 'LINK' && property.name != 'RELATED-TO') continue;
      final relation = property.parameterValue('RELTYPE')?.toUpperCase();
      if (const {'REFID', 'CONCEPT'}.contains(relation)) continue;
      final type = property.parameterValue('VALUE')?.toUpperCase();
      if (type == 'UID' ||
          (property.name == 'RELATED-TO' && (type == null || type == 'TEXT'))) {
        final uid = property.decodedTextValue;
        uids.add(uid);
        references.add(('UID', uid));
      } else if (type == 'URI' || type == 'XML-REFERENCE') {
        references.add((type!, property.rawValue));
        final uri = Uri.tryParse(property.rawValue);
        if (uri != null &&
            uri.hasAuthority &&
            const {'https', 'http'}.contains(uri.scheme) &&
            uri.userInfo.isEmpty) {
          if (type == 'XML-REFERENCE' && uri.hasFragment) {
            xml.add(uri);
            references.remove((type, property.rawValue));
          } else if (type == 'URI' && !uri.hasFragment && !uri.hasQuery) {
            uris.putIfAbsent(uri.toString(), () => {}).add(property.rawValue);
          }
        }
      }
    }
    final targets = <JournalLinkTarget>[for (final uri in xml) LinkedXml(uri)];
    List<JournalLinkTarget> includeUnresolved() => [
      ...targets,
      for (final (type, value) in references)
        UnresolvedJournalLink(type, value),
    ];
    if (uids.isEmpty && uris.isEmpty) return includeUnresolved();
    final objects = database.davObjects;
    final collections = database.davCollections;
    final query =
        database.select(objects).join([
          innerJoin(
            collections,
            collections.id.equalsExp(objects.collectionId),
          ),
        ])..where(
          objects.accountId.equals(origin.entry.accountId) &
              objects.serverDeleted.not() &
              collections.deleted.not() &
              collections.serverMissing.not() &
              ((objects.collectionId.equals(origin.entry.collectionId) &
                      objects.primaryUid.isIn(uids)) |
                  objects.requestUri.isIn(uris.keys)),
        );
    final candidates = <String, DavObject>{};
    final uidMatches = <String, List<String>>{};
    final uriMatches = <String, List<String>>{};
    for (final row in await query.get()) {
      if (!collectionCapabilitiesFromStored(row.readTable(collections))
          .canRead) {
        continue;
      }
      final object = row.readTable(objects);
      candidates[object.id] = object;
      if (object.collectionId == origin.entry.collectionId) {
        uidMatches
            .putIfAbsent(object.primaryUid ?? '', () => [])
            .add(object.id);
      }
      uriMatches.putIfAbsent(object.requestUri, () => []).add(object.id);
    }
    final ids = {
      for (final uid in uids)
        if (uidMatches[uid] case [final id]) id,
      for (final uri in uris.keys)
        if (uriMatches[uri] case [final id]) id,
    }..remove(origin.entry.davObjectId);
    if (ids.isEmpty) return includeUnresolved();
    final removed =
        await (database.select(database.pendingOps)..where(
              (row) =>
                  row.davObjectId.isIn(ids) &
                  row.operationType.equals('dav.delete') &
                  row.state.isIn(davUnresolvedPendingStates) &
                  row.state.isNotIn(const ['conflict', 'permission_blocked']),
            ))
            .get();
    ids.removeAll(removed.map((row) => row.davObjectId));
    if (ids.isEmpty) return includeUnresolved();
    final account = await (database.select(
      database.accounts,
    )..where((row) => row.id.equals(origin.entry.accountId))).getSingle();
    final journalRows = database.davJournalEntries;
    final components =
        await (database.select(journalRows).join([
              innerJoin(
                collections,
                collections.id.equalsExp(journalRows.collectionId),
              ),
            ])..where(
              journalRows.davObjectId.isIn(ids) &
                  collections.journalsSelected &
                  collections.journalProjectionEnabled,
            ))
            .map((row) => row.readTable(journalRows))
            .get();
    final eventRows = database.calendarEvents;
    final sources = database.calendarSources;
    final events = account.calendarsEnabled
        ? await (database.select(eventRows).join([
                innerJoin(
                  sources,
                  sources.id.equalsExp(eventRows.calendarSourceId),
                ),
              ])..where(
                eventRows.davObjectId.isIn(ids) &
                    eventRows.isDeleted.not() &
                    eventRows.isCancelled.not() &
                    sources.selected &
                    sources.hidden.not() &
                    sources.isDeleted.not(),
              ))
              .map((row) => row.readTable(eventRows))
              .get()
        : const <CalendarEvent>[];
    final taskRows = database.tasks;
    final lists = database.taskLists;
    final tasks = account.tasksEnabled
        ? await (database.select(taskRows).join([
                innerJoin(
                  lists,
                  lists.id.equalsExp(taskRows.taskListId) &
                      lists.accountId.equalsExp(taskRows.accountId),
                ),
                innerJoin(
                  collections,
                  collections.id.equalsExp(taskRows.davCollectionId),
                ),
              ])..where(
                taskRows.davObjectId.isIn(ids) &
                    taskRows.pendingDelete.not() &
                    lists.serverMissing.not() &
                    lists.pendingDelete.not() &
                    collections.tasksSelected,
              ))
              .map((row) => row.readTable(taskRows))
              .get()
        : const <Task>[];
    for (final id in ids) {
      final target = switch (candidates[id]?.dominantComponentType) {
        'VJOURNAL' => [
          if (_uniqueLink(
                components.where((row) => row.davObjectId == id).toList(),
                (row) => row.recurrenceIdKey == null,
              )
              case final journal?)
            LinkedJournal(journal),
        ],
        'VEVENT' => [
          if (_uniqueLink(
                events.where((row) => row.davObjectId == id).toList(),
                (row) =>
                    row.providerRecurringEventId == null &&
                    row.recurrenceIdKey == null,
              )
              case final event?)
            LinkedEvent(event),
        ],
        'VTODO' => [
          if (_uniqueLink(
                tasks.where((row) => row.davObjectId == id).toList(),
                (row) => row.recurrenceIdKey == null,
              )
              case final task?)
            LinkedTask(task),
        ],
        _ => <JournalLinkTarget>[],
      }.singleOrNull;
      if (target == null) continue;
      targets.add(target);
      final object = candidates[id]!;
      if (object.primaryUid case final uid?
          when uidMatches[uid]?.singleOrNull == id) {
        references.remove(('UID', uid));
      }
      final href = object.requestUri;
      if (uriMatches[href]?.singleOrNull == id) {
        for (final value in uris[href] ?? const <String>{}) {
          references.remove(('URI', value));
        }
      }
    }
    return includeUnresolved();
  }

  T? _uniqueLink<T>(List<T> candidates, bool Function(T) master) =>
      candidates.where(master).singleOrNull ?? candidates.singleOrNull;

  Stream<DavConflictSnapshot?> watchConflict(String id) =>
      (database.select(database.davConflictSnapshots)
            ..where((row) => row.id.equals(id) & row.resolvedAtUtc.isNull()))
          .watchSingleOrNull();

  Future<JournalSnapshot> read(DavJournalEntry entry) =>
      database.transaction(() async {
        final collection = await _source(entry.accountId, entry.collectionId);
        String raw;
        DavJournalPendingRecovery? recovery;
        try {
          raw = await _queue.exportRawIcsForObject(
            accountId: entry.accountId,
            collectionId: entry.collectionId,
            objectId: entry.davObjectId,
          );
        } on DavException catch (error) {
          if (error.code != duplicateJournalPositionCode) rethrow;
          recovery = await _queue.journalRecoveryForObject(
            accountId: entry.accountId,
            collectionId: entry.collectionId,
            objectId: entry.davObjectId,
          );
          if (recovery == null) {
            throw const DavException(
              kind: DavErrorKind.authorization,
              code: 'DavJournalRecoveryRequiresFullAccess',
              safeMessage: 'Refresh a source with write access to review the retained journal update.',
            );
          }
          final object = await (database.select(
            database.davObjects,
          )..where((row) => row.id.equals(entry.davObjectId))).getSingle();
          raw = object.rawIcsBody;
        }
        final components = IcalSemanticDocument.parse(raw).components;
        final component = components
            .where(
              (item) =>
                  item.recurrenceIdKey == entry.recurrenceIdKey &&
                  item.uid == entry.uid,
            )
            .firstOrNull
            ?.documentComponent;
        if (component == null && recovery == null) {
          throw const DavException(
            kind: DavErrorKind.invalidCalendarData,
            code: 'DavJournalComponentMissing',
            safeMessage: 'The journal occurrence is no longer available.',
          );
        }
        return JournalSnapshot(
          entry: entry,
          collection: collection,
          component: JournalComponent(
            component ?? components.first.documentComponent,
          ),
          effectiveRawIcs: raw,
          pendingRecovery: recovery,
        );
      });

  Future<void> repairPendingUpdate(
    DavJournalPendingRecovery recovery,
    Map<String?, int> selectedComponents,
  ) async {
    final document = IcalSemanticDocument.parse(recovery.invalidCandidate);
    final positions = DavJournalPendingRecovery.competingComponents(document);
    for (final group in positions.entries) {
      final selected = selectedComponents[group.key];
      if (selected == null || selected < 0 || selected >= group.value.length) {
        throw const DavException(
          kind: DavErrorKind.invalidCalendarData,
          code: 'DavJournalRecoveryChoiceRequired',
          safeMessage: 'Choose one journal component for each original position before reapplying.',
        );
      }
      for (final (index, component) in group.value.indexed) {
        if (index != selected) {
          document.document.root.children.remove(component.documentComponent);
        }
      }
    }
    document.document.root.structurallyDirty = true;
    await _queue.replaceRecoveredJournal(
      reviewed: recovery,
      rawIcs: document.document.serialize(),
    );
  }

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
      occurrence.override == null
          ? null
          : IcalComponentKey(
              componentType: 'VJOURNAL',
              uid: source.entry.uid,
              recurrenceIdKey: occurrence.override!.recurrenceIdKey,
            ),
    );
  }

  Future<void> editOccurrence(
    JournalOccurrenceDraft draft,
    List<DavPatchOperation> operations,
  ) => database.transaction(() async {
    if (operations.isEmpty) return;
    await _checkForLocalChange(draft.entry);
    final target = draft.component.key;
    final component = draft.component.component.component;
    final changes = [
      if (draft.originalException case final original?)
        DavPatchOperation.removeComponent(componentKey: original),
      DavPatchOperation.addComponent(component),
      ...operations,
    ];
    final stamp = _nowUtc();
    final candidate = DavMutationPatch(
      target: target,
      scope: DavMutationScope.occurrence,
      operations: changes,
    ).applyTo(draft.entry.effectiveRawIcs, nowUtc: stamp);
    final document = IcalDocument.parse(candidate);
    final updated = IcalDocumentPatcher(document).requireComponent(target);
    if (semanticComponentHash(component) == semanticComponentHash(updated)) {
      return;
    }
    final original = IcalSemanticDocument.parse(draft.entry.effectiveRawIcs);
    final master = original.components
        .where((item) => item.recurrenceId == null)
        .firstOrNull
        ?.documentComponent;
    final continuation = _continueDisplacedRange(draft, original, document);
    final revision = await _revisionOperations(
      draft.entry.entry.accountId,
      component,
      updated,
      stamp,
      master: master,
      recurrenceChanged:
          draft.originalException?.recurrenceIdKey != target.recurrenceIdKey,
    );
    await _queueEdit(
      draft.entry.entry,
      DavMutationPatch(
        target: target,
        scope: DavMutationScope.occurrence,
        operations: [
          ...changes,
          if (continuation != null)
            DavPatchOperation.addComponent(continuation),
          ...revision,
        ],
      ),
    );
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
        if (draft.originalException case final original?) {
          patcher.removeComponent(original);
        }
        final previousMaster = master?.deepCopy();
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
        _continueDisplacedRange(
          draft,
          IcalSemanticDocument.parse(draft.entry.effectiveRawIcs),
          document,
        );
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
              if (previousMaster != null && master != null)
                ...await _revisionOperations(
                  draft.entry.entry.accountId,
                  previousMaster,
                  master,
                  _nowUtc(),
                ),
            ],
          ),
        );
      });

  IcalComponent? _continueDisplacedRange(
    JournalOccurrenceDraft draft,
    IcalSemanticDocument original,
    IcalDocument result,
  ) {
    if (draft.thisAndFuture || draft.originalException == null) return null;
    final range = original.components
        .where(
          (entry) =>
              entry.recurrenceRange == 'THISANDFUTURE' &&
              entry.recurrenceIdKey == draft.originalException!.recurrenceIdKey,
        )
        .firstOrNull;
    return range == null
        ? null
        : continueJournalRange(result, range, original.components);
  }

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
        final stamp = _nowUtc();
        final master = base.components
            .where((entry) => entry.recurrenceId == null)
            .firstOrNull
            ?.documentComponent;
        final selectedChanges =
            draft.originalException?.recurrenceIdKey !=
                selection.recurrenceIdKey ||
            component.firstProperty('STATUS')?.rawValue != 'CANCELLED';
        final candidate = selectedChanges
            ? DavMutationPatch(
                target: selection,
                scope: DavMutationScope.occurrence,
                operations: [
                  if (draft.originalException case final original?)
                    DavPatchOperation.removeComponent(componentKey: original),
                  DavPatchOperation.addComponent(component),
                  DavPatchOperation.setRaw(
                    'STATUS',
                    'CANCELLED',
                    preserveParameters: true,
                  ),
                  ...await _revisionOperations(
                    draft.entry.entry.accountId,
                    component,
                    component,
                    stamp,
                    recurrenceChanged: true,
                    master: master,
                  ),
                ],
              ).applyTo(draft.entry.effectiveRawIcs, nowUtc: stamp)
            : draft.entry.effectiveRawIcs;
        final result = IcalDocument.parse(candidate);
        for (final sibling in result.calendarComponents.where(
          (c) => c.name == 'VJOURNAL',
        )) {
          final identity = parseIcalTemporal(
            sibling.firstProperty('RECURRENCE-ID'),
          );
          if (identity == null ||
              !resolver.toUtc(identity).isAfter(first) ||
              sibling.firstProperty('STATUS')?.rawValue == 'CANCELLED') {
            continue;
          }
          final revision = await _revisionOperations(
            draft.entry.entry.accountId,
            sibling,
            sibling,
            stamp,
            recurrenceChanged: true,
            master: master,
          );
          final changes = {
            'STATUS': 'CANCELLED',
            'DTSTAMP': _revisionTime(stamp),
            if (sibling.firstProperty('LAST-MODIFIED') != null)
              'LAST-MODIFIED': _revisionTime(stamp),
            for (final op in revision)
              if (op.propertyName == 'SEQUENCE') 'SEQUENCE': op.value!,
          };
          for (final change in changes.entries) {
            final property = sibling.firstProperty(change.key);
            if (property == null) {
              sibling.children.add(_property(change.key, change.value));
              sibling.structurallyDirty = true;
            } else if (change.key == 'STATUS' ||
                !isDerivedJournalProperty(property)) {
              property
                ..rawValue = change.value
                ..isDirty = true;
            }
          }
        }
        final cancelled = result.serialize();
        if (cancelled == draft.entry.effectiveRawIcs) return;
        await _queueEdit(
          draft.entry.entry,
          DavMutationPatch(
            target: draft.entry.key,
            scope: DavMutationScope.object,
            operations: [DavPatchOperation.replaceJournalResource(cancelled)],
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
    final previousMaster = master?.documentComponent.deepCopy();
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
          if (previousMaster != null && master != null)
            ...await _revisionOperations(
              draft.entry.entry.accountId,
              previousMaster,
              master.documentComponent,
              _nowUtc(),
              recurrenceChanged: true,
            ),
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
    final previous = editing.component.component;
    final originalStart = editing.component.start;
    var requestedOperations = operations;
    final dateChange = operations
        .where(
          (item) =>
              item.type == DavPatchOperationType.setRaw &&
              item.propertyName == 'DTSTART',
        )
        .lastOrNull;
    if (entry.recurrenceIdKey == null &&
        originalStart != null &&
        dateChange?.value != null &&
        !dateChange!.preserveParameters) {
      final oldStart = previous.firstProperty('DTSTART')!;
      final newStart = IcalProperty(
        group: oldStart.group,
        name: 'DTSTART',
        rawValue: dateChange.value!,
        isDirty: true,
        originalPhysicalLines: const [],
        parameters: dateChange.parameters,
      );
      final next = parseIcalTemporal(newStart);
      if (next != null &&
          (next.kind != originalStart.kind ||
              next.timeZoneId != originalStart.timeZoneId) &&
          (previous.properties.any(
                (item) =>
                    const {'RRULE', 'RDATE', 'EXDATE'}.contains(item.name),
              ) ||
              IcalSemanticDocument.parse(editing.effectiveRawIcs)
                      .components
                      .length >
                  1)) {
        if (operations.any(
          (item) => const {
            DavPatchOperationType.addComponent,
            DavPatchOperationType.removeComponent,
            DavPatchOperationType.replaceJournalResource,
          }.contains(item.type),
        )) {
          throw const DavException(
            kind: DavErrorKind.invalidCalendarData,
            code: 'IcalJournalDateConversionUnavailable',
            safeMessage: 'Convert the journal date mode separately from changes to its occurrence set.',
          );
        }
        final converted = convertJournalSeriesDate(
          editing.effectiveRawIcs,
          originalStart,
          newStart,
        );
        requestedOperations = [
          DavPatchOperation.replaceJournalResource(converted),
          ...operations.where((item) => item.propertyName != 'DTSTART'),
        ];
      }
    }
    final scope = !identical(requestedOperations, operations)
        ? DavMutationScope.object
        : entry.recurrenceIdKey == null
        ? DavMutationScope.recurrenceMaster
        : DavMutationScope.recurrenceException;
    final changes = DavMutationPatch(
      target: editing.key,
      scope: scope,
      operations: requestedOperations,
    );
    final edited = changes.applyTo(editing.effectiveRawIcs, nowUtc: now);
    if (edited == editing.effectiveRawIcs) return;
    if (scope == DavMutationScope.object) {
      final original = IcalSemanticDocument.parse(editing.effectiveRawIcs);
      final converted = IcalSemanticDocument.parse(edited);
      // Conversion traverses the original component order. Detached IDs may
      // have changed lexical form, so the old keys cannot address the result.
      final patcher = IcalDocumentPatcher(converted.document);
      final addresses = await _journalOrganizerAddresses(entry.accountId);
      for (final (index, component) in converted.components.indexed) {
        final before = original.components[index].documentComponent;
        final after = component.documentComponent;
        if (changedIcalProperties(before, after).isEmpty &&
            component.recurrenceId != null) {
          continue;
        }
        final sequence = await _nextJournalSequence(
          entry.accountId,
          before,
          after,
          master: component.recurrenceId == null ? null : previous,
          addresses: addresses,
        );
        if (sequence != null) {
          patcher.replaceComponentSingletonRaw(
            after,
            'SEQUENCE',
            sequence,
            preserveParameters: true,
          );
        }
        reviseJournalTimestamps(patcher, after, _revisionTime(now));
      }
      await _queueEdit(
        entry,
        DavMutationPatch(
          target: editing.key,
          scope: scope,
          operations: [
            DavPatchOperation.replaceJournalResource(
              patcher.document.serialize(),
            ),
          ],
        ),
        provider: BusyProviderCodec.requireStorageValue(account.provider),
      );
      return;
    }
    final updated = IcalDocumentPatcher(IcalDocument.parse(edited))
        .requireComponent(editing.key);
    final revision = await _revisionOperations(
      entry.accountId,
      previous,
      updated,
      now,
    );
    final patch = DavMutationPatch(
      target: editing.key,
      scope: scope,
      operations: [...requestedOperations, ...revision],
    );
    await _queueEdit(
      entry,
      patch,
      provider: BusyProviderCodec.requireStorageValue(account.provider),
    );
  });

  Future<List<DavPatchOperation>> _revisionOperations(
    String accountId,
    IcalComponent previous,
    IcalComponent updated,
    DateTime stamp, {
    bool recurrenceChanged = false,
    IcalComponent? master,
  }) async {
    final sequence = await _nextJournalSequence(
      accountId,
      previous,
      updated,
      recurrenceChanged: recurrenceChanged,
      master: master,
    );
    return [
      if (sequence != null)
        DavPatchOperation.setRaw(
          'SEQUENCE',
          sequence,
          preserveParameters: true,
        ),
      DavPatchOperation.reviseJournal(stamp),
    ];
  }

  Future<List<Object?>> _journalOrganizerAddresses(String accountId) async {
    final service = await (database.select(
      database.davAccountServices,
    )..where((row) => row.accountId.equals(accountId))).getSingleOrNull();
    return jsonDecode(service?.calendarUserAddressesJson ?? '[]') as List;
  }

  Future<String?> _nextJournalSequence(
    String accountId,
    IcalComponent previous,
    IcalComponent updated, {
    bool recurrenceChanged = false,
    IcalComponent? master,
    List<Object?>? addresses,
  }) async {
    final organizer =
        previous.firstProperty('ORGANIZER')?.rawValue ??
        updated.firstProperty('ORGANIZER')?.rawValue ??
        master?.firstProperty('ORGANIZER')?.rawValue;
    final sequence = previous.firstProperty('SEQUENCE');
    final significant =
        recurrenceChanged ||
        changedIcalProperties(previous, updated).any(
          const {
            'DTSTART',
            'RRULE',
            'RDATE',
            'EXDATE',
            'RECURRENCE-ID',
            'STATUS',
            'ORGANIZER',
            'ATTENDEE',
          }.contains,
        );
    if (!significant ||
        organizer == null ||
        isDerivedJournalProperty(sequence) ||
        !(addresses ?? await _journalOrganizerAddresses(accountId)).contains(
          organizer,
        )) {
      return null;
    }
    final previousSequence =
        int.tryParse(
          sequence?.rawValue ??
              master?.firstProperty('SEQUENCE')?.rawValue ??
              '',
        ) ??
        0;
    return '${previousSequence + 1}';
  }

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
    if (current.pendingRecovery != null ||
        current.effectiveRawIcs != editing.effectiveRawIcs) {
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

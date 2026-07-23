import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../calendar_providers/calendar_mutation.dart';
import '../../../calendar_providers/calendar_sync_dto.dart';
import '../../../db/app_database.dart';
import '../../notifications/notification_schedule_service.dart';
import '../../../task_providers/task_provider.dart';
import '../presentation/event_editor_draft.dart';

class CalendarSourceEntity {
  const CalendarSourceEntity({
    required this.id,
    required this.accountId,
    required this.provider,
    required this.providerCalendarId,
    required this.summary,
    required this.selected,
    required this.hidden,
    required this.readOnly,
    required this.isDeleted,
    this.description,
    this.backgroundColor,
    this.foregroundColor,
    this.colorId,
    this.timeZone,
    this.accessRole,
  });

  factory CalendarSourceEntity.fromRow(CalendarSource row) {
    return CalendarSourceEntity(
      id: row.id,
      accountId: row.accountId,
      provider: TaskProviderParsing.fromStorageValue(row.provider),
      providerCalendarId: row.providerCalendarId,
      summary: row.summary,
      selected: row.selected,
      hidden: row.hidden,
      readOnly: row.readOnly,
      isDeleted: row.isDeleted,
      description: row.description,
      backgroundColor: row.backgroundColor,
      foregroundColor: row.foregroundColor,
      colorId: row.colorId,
      timeZone: row.timeZone,
      accessRole: row.accessRole,
    );
  }

  final String id;
  final String accountId;
  final BusyProvider provider;
  final String providerCalendarId;
  final String summary;
  final bool selected;
  final bool hidden;
  final bool readOnly;
  final bool isDeleted;
  final String? description;
  final String? backgroundColor;
  final String? foregroundColor;
  final String? colorId;
  final String? timeZone;
  final String? accessRole;

  CalendarSourceCapabilities get capabilities =>
      CalendarSourceCapabilities.fromSource(this);
}

/// The event operations currently permitted by a calendar source.
///
/// Keeping this policy with the source model gives every presentation surface
/// and mutation entry point the same answer. Visibility is deliberately not a
/// write capability: a hidden calendar can still own an event that is opened
/// from a notification or deep link.
class CalendarSourceCapabilities {
  const CalendarSourceCapabilities({
    required this.canCreateEvents,
    required this.canEditEvents,
    required this.canDeleteEvents,
  });

  factory CalendarSourceCapabilities.fromSource(CalendarSourceEntity source) {
    final writable = !source.readOnly && !source.isDeleted;
    return CalendarSourceCapabilities(
      canCreateEvents: writable,
      canEditEvents: writable,
      canDeleteEvents: writable,
    );
  }

  static const unavailable = CalendarSourceCapabilities(
    canCreateEvents: false,
    canEditEvents: false,
    canDeleteEvents: false,
  );

  final bool canCreateEvents;
  final bool canEditEvents;
  final bool canDeleteEvents;
}

enum CalendarMutationOperation {
  createEvent,
  editEvent,
  deleteEvent,
  renameCalendar,
  deleteCalendar,
}

class CalendarMutationNotAllowed implements Exception {
  const CalendarMutationNotAllowed({
    required this.operation,
    required this.sourceId,
  });

  final CalendarMutationOperation operation;
  final String sourceId;

  @override
  String toString() {
    return 'CalendarMutationNotAllowed(${operation.name}, source: $sourceId)';
  }
}

List<CalendarSourceEntity> writableCalendarSources(
  Iterable<CalendarSourceEntity> sources,
) {
  return [
    for (final source in sources)
      if (source.capabilities.canCreateEvents) source,
  ];
}

class CalendarRepository {
  CalendarRepository({
    required AppDatabase database,
    DateTime Function()? now,
    String? localTimeZone,
    Future<void> Function()? onNotificationScheduleChanged,
  }) : _database = database,
       _now = now ?? DateTime.now,
       _localTimeZone = localTimeZone,
       _onNotificationScheduleChanged = onNotificationScheduleChanged;

  final AppDatabase _database;
  final DateTime Function() _now;
  final String? _localTimeZone;
  final Future<void> Function()? _onNotificationScheduleChanged;

  Stream<List<CalendarSourceEntity>> watchSourcesForAccounts(
    List<String> accountIds,
  ) {
    if (accountIds.isEmpty) {
      return Stream.value(const []);
    }
    final query = _database.select(_database.calendarSources)
      ..where(
        (row) => row.accountId.isIn(accountIds) & row.isDeleted.equals(false),
      )
      ..orderBy([
        (row) => OrderingTerm.asc(row.accountId),
        (row) => OrderingTerm.asc(row.summary),
      ]);
    return query.watch().map(
      (rows) => rows.map(CalendarSourceEntity.fromRow).toList(),
    );
  }

  Future<List<CalendarSourceEntity>> listVisibleSources(
    List<String> accountIds,
  ) async {
    if (accountIds.isEmpty) {
      return const [];
    }
    final query = _database.select(_database.calendarSources)
      ..where(
        (row) =>
            row.accountId.isIn(accountIds) &
            row.selected.equals(true) &
            row.hidden.equals(false) &
            row.isDeleted.equals(false),
      );
    final rows = await query.get();
    return rows.map(CalendarSourceEntity.fromRow).toList();
  }

  Future<void> setSourceSelected(String sourceId, bool selected) async {
    final source = await (_database.select(
      _database.calendarSources,
    )..where((row) => row.id.equals(sourceId))).getSingle();
    await (_database.update(
      _database.calendarSources,
    )..where((row) => row.id.equals(sourceId))).write(
      CalendarSourcesCompanion(
        selected: Value(selected),
        updatedAtLocal: Value(_now().millisecondsSinceEpoch),
      ),
    );
    await _notificationScheduleService().rebuildUpcomingEventNotifications(
      source.accountId,
    );
    await _onNotificationScheduleChanged?.call();
  }

  Future<void> renameLocalSource(String sourceId, String summary) async {
    final source = await (_database.select(
      _database.calendarSources,
    )..where((row) => row.id.equals(sourceId))).getSingle();
    _requireWritableSource(
      source,
      operation: CalendarMutationOperation.renameCalendar,
    );
    final now = _now().millisecondsSinceEpoch;
    final nowUtc = DateTime.now().toUtc().toIso8601String();
    await _database.transaction(() async {
      await (_database.update(
        _database.calendarSources,
      )..where((row) => row.id.equals(sourceId))).write(
        CalendarSourcesCompanion(
          summary: Value(summary),
          updatedAtLocal: Value(now),
        ),
      );
      await _database.pendingOpsDao.enqueue(
        PendingOpsCompanion.insert(
          id: const Uuid().v4(),
          accountId: source.accountId,
          provider: Value(source.provider),
          entityType: 'calendar',
          operation: 'patch',
          operationType: const Value('calendar.patch'),
          calendarSourceId: Value(source.id),
          providerCalendarId: Value(source.providerCalendarId),
          requestJson: jsonEncode({'summary': summary}),
          baselineRawJson: Value(source.rawJson),
          createdAtUtc: nowUtc,
          updatedAtUtc: nowUtc,
        ),
      );
    });
  }

  Future<void> deleteLocalSource(String sourceId) async {
    final source = await (_database.select(
      _database.calendarSources,
    )..where((row) => row.id.equals(sourceId))).getSingle();
    _requireWritableSource(
      source,
      operation: CalendarMutationOperation.deleteCalendar,
    );
    final now = _now().millisecondsSinceEpoch;
    final nowUtc = DateTime.now().toUtc().toIso8601String();
    await _database.transaction(() async {
      await (_database.update(
        _database.calendarSources,
      )..where((row) => row.id.equals(sourceId))).write(
        CalendarSourcesCompanion(
          isDeleted: const Value(true),
          hidden: const Value(true),
          updatedAtLocal: Value(now),
        ),
      );
      await _database.pendingOpsDao.enqueue(
        PendingOpsCompanion.insert(
          id: const Uuid().v4(),
          accountId: source.accountId,
          provider: Value(source.provider),
          entityType: 'calendar',
          operation: 'delete',
          operationType: const Value('calendar.delete'),
          calendarSourceId: Value(source.id),
          providerCalendarId: Value(source.providerCalendarId),
          requestJson: '{}',
          baselineRawJson: Value(source.rawJson),
          createdAtUtc: nowUtc,
          updatedAtUtc: nowUtc,
        ),
      );
    });
    await _notificationScheduleService().rebuildUpcomingEventNotifications(
      source.accountId,
    );
    await _onNotificationScheduleChanged?.call();
  }

  Future<void> upsertSource({
    required String accountId,
    required CalendarSourceDto source,
  }) async {
    final now = _now().millisecondsSinceEpoch;
    final id = sourceId(
      accountId: accountId,
      provider: source.provider,
      providerCalendarId: source.providerCalendarId,
    );
    await _database.transaction(() async {
      final existing = await (_database.select(
        _database.calendarSources,
      )..where((row) => row.id.equals(id))).getSingleOrNull();
      final isDeleted = (existing?.isDeleted ?? false) || source.isDeleted;
      await _database
          .into(_database.calendarSources)
          .insertOnConflictUpdate(
            CalendarSourcesCompanion.insert(
              id: id,
              accountId: accountId,
              provider: source.provider.storageValue,
              providerCalendarId: source.providerCalendarId,
              summary: source.summary,
              description: Value(source.description),
              primaryCalendar: Value(source.primaryCalendar),
              selected: Value(existing?.selected ?? source.selected),
              hidden: Value(isDeleted || source.hidden),
              readOnly: Value(source.readOnly),
              backgroundColor: Value(source.backgroundColor),
              foregroundColor: Value(source.foregroundColor),
              colorId: Value(source.colorId),
              timeZone: Value(source.timeZone),
              accessRole: Value(source.accessRole),
              isDeleted: Value(isDeleted),
              rawJson: Value(jsonEncode(source.rawJson)),
              createdAtLocal: existing?.createdAtLocal ?? now,
              updatedAtLocal: now,
            ),
          );
    });
  }

  /// Stores a provider event.
  ///
  /// Pull syncs must preserve local optimistic state while an event is dirty or
  /// has an outstanding mutation. Mutation acknowledgements remain
  /// authoritative so they can transition the row back to `synced`.
  Future<void> upsertEvent({
    required String accountId,
    required CalendarEventDto event,
    bool preservePendingLocalChanges = false,
  }) async {
    final now = _now().millisecondsSinceEpoch;
    final calendarSourceId = sourceId(
      accountId: accountId,
      provider: event.provider,
      providerCalendarId: event.providerCalendarId,
    );
    final id = eventId(
      accountId: accountId,
      provider: event.provider,
      providerCalendarId: event.providerCalendarId,
      providerEventId: event.providerEventId,
      providerOriginalStartKey: event.providerOriginalStartKey,
    );
    final eventRow = CalendarEventsCompanion.insert(
      id: id,
      accountId: accountId,
      calendarSourceId: calendarSourceId,
      provider: event.provider.storageValue,
      providerCalendarId: event.providerCalendarId,
      providerEventId: event.providerEventId,
      providerRecurringEventId: Value(event.providerRecurringEventId),
      providerOriginalStartKey: Value(event.providerOriginalStartKey),
      etagOrChangeKey: Value(event.etagOrChangeKey),
      status: Value(event.status),
      title: event.title,
      description: Value(event.description),
      location: Value(event.location),
      allDay: Value(event.allDay),
      startDate: Value(event.startDate),
      startDateTime: Value(event.startDateTime),
      startTimeZone: Value(event.startTimeZone),
      endDate: Value(event.endDate),
      endDateTime: Value(event.endDateTime),
      endTimeZone: Value(event.endTimeZone),
      recurrenceJson: Value(_json(event.recurrenceJson)),
      remindersJson: Value(_json(event.remindersJson)),
      attendeesJson: Value(_json(event.attendeesJson)),
      categoriesJson: Value(_json(event.categoriesJson)),
      organizerJson: Value(_json(event.organizerJson)),
      creatorJson: Value(_json(event.creatorJson)),
      colorId: Value(event.colorId),
      colorHex: Value(event.colorHex),
      visibility: Value(event.visibility),
      transparencyOrShowAs: Value(event.transparencyOrShowAs),
      eventType: Value(event.eventType),
      webLink: Value(event.webLink),
      conferenceJson: Value(_json(event.conferenceJson)),
      attachmentsJson: Value(_json(event.attachmentsJson)),
      isCancelled: Value(event.isCancelled),
      isDeleted: Value(event.isDeleted),
      rawJson: Value(jsonEncode(event.rawJson)),
      createdAtServer: Value(event.createdAtServer),
      updatedAtServer: Value(event.updatedAtServer),
      createdAtLocal: now,
      updatedAtLocal: now,
      syncStatus: const Value('synced'),
      baselineRawJson: Value(jsonEncode(event.rawJson)),
    );
    if (!preservePendingLocalChanges) {
      await _database
          .into(_database.calendarEvents)
          .insertOnConflictUpdate(eventRow);
      return;
    }

    await _database.transaction(() async {
      final localEvent = await (_database.select(
        _database.calendarEvents,
      )..where((row) => row.id.equals(id))).getSingleOrNull();
      if (localEvent != null) {
        if (localEvent.syncStatus != 'synced') {
          return;
        }
        final pendingMutation =
            await (_database.select(_database.pendingOps)
                  ..where(
                    (row) =>
                        row.accountId.equals(accountId) &
                        row.entityType.equals('event') &
                        row.eventId.equals(id),
                  )
                  ..limit(1))
                .getSingleOrNull();
        if (pendingMutation != null) {
          return;
        }
      }
      await _database
          .into(_database.calendarEvents)
          .insertOnConflictUpdate(eventRow);
    });
  }

  Future<void> saveSyncState({
    required String accountId,
    required BusyProvider provider,
    required String syncKind,
    String? calendarSourceId,
    String? rangeStart,
    String? rangeEnd,
    String? googleSyncToken,
    String? microsoftDeltaLink,
    bool full = false,
    String? lastError,
    String? rawStateJson,
  }) async {
    final id = syncStateId(
      accountId: accountId,
      provider: provider,
      syncKind: syncKind,
      calendarSourceId: calendarSourceId,
    );
    final now = _now().millisecondsSinceEpoch;
    await _database.transaction(() async {
      // Older releases keyed state by exact range bounds. Remove those rows
      // before inserting the stable scope key; the legacy unique index still
      // includes the range columns.
      await (_database.delete(_database.calendarSyncStates)..where((row) {
            final sameSource = calendarSourceId == null
                ? row.calendarSourceId.isNull()
                : row.calendarSourceId.equals(calendarSourceId);
            return row.accountId.equals(accountId) &
                row.provider.equals(provider.storageValue) &
                row.syncKind.equals(syncKind) &
                sameSource &
                row.id.equals(id).not();
          }))
          .go();
      await _database
          .into(_database.calendarSyncStates)
          .insertOnConflictUpdate(
            CalendarSyncStatesCompanion.insert(
              id: id,
              accountId: accountId,
              calendarSourceId: Value(calendarSourceId),
              provider: provider.storageValue,
              syncKind: syncKind,
              rangeStart: Value(rangeStart),
              rangeEnd: Value(rangeEnd),
              googleSyncToken: Value(googleSyncToken),
              microsoftDeltaLink: Value(microsoftDeltaLink),
              lastFullSyncAt: full ? Value(now) : const Value.absent(),
              lastIncrementalSyncAt: full ? const Value.absent() : Value(now),
              lastError: Value(lastError),
              rawStateJson: Value(rawStateJson),
            ),
          );
    });
  }

  Future<void> createLocalEvent(EventEditorDraft draft) async {
    final source = await (_database.select(
      _database.calendarSources,
    )..where((row) => row.id.equals(draft.sourceId))).getSingle();
    _requireWritableSource(
      source,
      operation: CalendarMutationOperation.createEvent,
    );
    if (source.accountId != draft.accountId ||
        source.providerCalendarId != draft.providerCalendarId) {
      throw CalendarMutationNotAllowed(
        operation: CalendarMutationOperation.createEvent,
        sourceId: source.id,
      );
    }
    final now = _now().millisecondsSinceEpoch;
    final provider = TaskProviderParsing.fromStorageValue(source.provider);
    final localEventId = 'local:${const Uuid().v4()}';
    final startTimeZone = _effectiveStartTimeZone(
      draft,
      source.timeZone,
      _localTimeZone,
    );
    final endTimeZone = _effectiveEndTimeZone(
      draft,
      source.timeZone,
      startTimeZone,
      _localTimeZone,
    );
    final id = eventId(
      accountId: draft.accountId,
      provider: provider,
      providerCalendarId: draft.providerCalendarId,
      providerEventId: localEventId,
    );
    final requestJson = jsonEncode(
      _eventRequest(
        draft,
        provider,
        isCreate: true,
        startTimeZone: startTimeZone,
        endTimeZone: endTimeZone,
      ),
    );
    await _database.transaction(() async {
      await _database
          .into(_database.calendarEvents)
          .insert(
            CalendarEventsCompanion.insert(
              id: id,
              accountId: draft.accountId,
              calendarSourceId: draft.sourceId,
              provider: source.provider,
              providerCalendarId: draft.providerCalendarId,
              providerEventId: localEventId,
              title: draft.title.trim(),
              description: Value(draft.description),
              location: Value(draft.location),
              allDay: Value(draft.allDay),
              startDate: Value(draft.allDay ? _date(draft.start) : null),
              startDateTime: Value(
                draft.allDay ? null : draft.start?.toIso8601String(),
              ),
              startTimeZone: Value(startTimeZone),
              endDate: Value(draft.allDay ? _date(draft.end) : null),
              endDateTime: Value(
                draft.allDay ? null : draft.end?.toIso8601String(),
              ),
              endTimeZone: Value(endTimeZone),
              recurrenceJson: Value(_json(draft.recurrence)),
              remindersJson: Value(_json(draft.reminders)),
              attendeesJson: Value(_json(_attendeesJson(draft, provider))),
              categoriesJson: Value(_json(_categoriesJson(draft, provider))),
              colorId: Value(draft.colorId),
              visibility: Value(draft.visibilityOrSensitivity),
              transparencyOrShowAs: Value(draft.showAs),
              conferenceJson: Value(_json(draft.conference)),
              createdAtLocal: now,
              updatedAtLocal: now,
              syncStatus: const Value('pending'),
              rawJson: const Value('{}'),
              baselineRawJson: const Value('{}'),
            ),
          );
      await _database
          .into(_database.pendingOps)
          .insert(
            PendingOpsCompanion.insert(
              id: const Uuid().v4(),
              accountId: draft.accountId,
              provider: Value(source.provider),
              entityType: 'event',
              operation: 'create',
              operationType: const Value('event.create'),
              calendarSourceId: Value(draft.sourceId),
              providerCalendarId: Value(draft.providerCalendarId),
              eventId: Value(id),
              localTempId: Value(localEventId),
              requestJson: requestJson,
              createdAtUtc: DateTime.now().toUtc().toIso8601String(),
              updatedAtUtc: DateTime.now().toUtc().toIso8601String(),
            ),
          );
    });
    await _notificationScheduleService().rebuildUpcomingEventNotifications(
      draft.accountId,
    );
    await _onNotificationScheduleChanged?.call();
  }

  Future<void> updateLocalEvent(EventEditorDraft draft) async {
    final eventId = draft.eventId;
    if (eventId == null) {
      return createLocalEvent(draft);
    }
    final source = await (_database.select(
      _database.calendarSources,
    )..where((row) => row.id.equals(draft.sourceId))).getSingle();
    final existing = await (_database.select(
      _database.calendarEvents,
    )..where((row) => row.id.equals(eventId))).getSingle();
    _requireWritableSource(
      source,
      operation: CalendarMutationOperation.editEvent,
    );
    final sourceChanged =
        draft.accountId != existing.accountId ||
        draft.sourceId != existing.calendarSourceId ||
        draft.providerCalendarId != existing.providerCalendarId ||
        source.accountId != existing.accountId ||
        source.provider != existing.provider ||
        source.providerCalendarId != existing.providerCalendarId;
    if (sourceChanged) {
      throw UnsupportedError(
        'Moving an existing event to another calendar or account is not '
        'supported.',
      );
    }
    if (draft.recurrenceChanged && existing.providerRecurringEventId != null) {
      throw UnsupportedError(
        'Editing a recurring series from an individual occurrence is not '
        'supported.',
      );
    }
    final now = _now().millisecondsSinceEpoch;
    final provider = TaskProviderParsing.fromStorageValue(source.provider);
    final startTimeZone = _effectiveStartTimeZone(
      draft,
      source.timeZone,
      _localTimeZone,
    );
    final endTimeZone = _effectiveEndTimeZone(
      draft,
      source.timeZone,
      startTimeZone,
      _localTimeZone,
    );
    final requestJson = jsonEncode(
      _eventRequest(
        draft,
        provider,
        isCreate: false,
        startTimeZone: startTimeZone,
        endTimeZone: endTimeZone,
      ),
    );
    await _database.transaction(() async {
      final predecessor = await _latestPendingEventEdit(
        accountId: draft.accountId,
        eventId: eventId,
      );
      await (_database.update(
        _database.calendarEvents,
      )..where((row) => row.id.equals(eventId))).write(
        CalendarEventsCompanion(
          accountId: Value(draft.accountId),
          calendarSourceId: Value(draft.sourceId),
          provider: Value(source.provider),
          providerCalendarId: Value(draft.providerCalendarId),
          title: Value(draft.title.trim()),
          description: Value(draft.description),
          location: Value(draft.location),
          allDay: Value(draft.allDay),
          startDate: Value(draft.allDay ? _date(draft.start) : null),
          startDateTime: Value(
            draft.allDay ? null : draft.start?.toIso8601String(),
          ),
          startTimeZone: Value(startTimeZone),
          endDate: Value(draft.allDay ? _date(draft.end) : null),
          endDateTime: Value(
            draft.allDay ? null : draft.end?.toIso8601String(),
          ),
          endTimeZone: Value(endTimeZone),
          recurrenceJson: draft.recurrenceChanged
              ? Value(_json(draft.recurrence))
              : const Value.absent(),
          remindersJson: Value(_json(draft.reminders)),
          attendeesJson: draft.attendeesChanged
              ? Value(_json(_attendeesJson(draft, provider)))
              : const Value.absent(),
          categoriesJson: draft.categoriesChanged
              ? Value(_json(_categoriesJson(draft, provider)))
              : const Value.absent(),
          colorId: Value(draft.colorId),
          visibility: Value(draft.visibilityOrSensitivity),
          transparencyOrShowAs: Value(draft.showAs),
          conferenceJson: Value(_json(draft.conference)),
          updatedAtLocal: Value(now),
          syncStatus: const Value('pending'),
        ),
      );
      await _database
          .into(_database.pendingOps)
          .insert(
            PendingOpsCompanion.insert(
              id: const Uuid().v4(),
              accountId: draft.accountId,
              provider: Value(source.provider),
              entityType: 'event',
              operation: 'patch',
              operationType: const Value('event.patch'),
              calendarSourceId: Value(draft.sourceId),
              providerCalendarId: Value(draft.providerCalendarId),
              eventId: Value(eventId),
              dependsOnOpId: Value(predecessor?.id),
              requestJson: requestJson,
              baselineUpdatedUtc: Value(existing.updatedAtServer),
              baselineRawJson: Value(existing.baselineRawJson),
              createdAtUtc: DateTime.now().toUtc().toIso8601String(),
              updatedAtUtc: DateTime.now().toUtc().toIso8601String(),
            ),
          );
    });
    await _notificationScheduleService().rebuildUpcomingEventNotifications(
      draft.accountId,
    );
    await _onNotificationScheduleChanged?.call();
  }

  Future<PendingOp?> _latestPendingEventEdit({
    required String accountId,
    required String eventId,
  }) async {
    final query = _database.select(_database.pendingOps)
      ..where(
        (row) =>
            row.accountId.equals(accountId) &
            row.entityType.equals('event') &
            row.eventId.equals(eventId) &
            (row.operationType.equals('event.patch') |
                (row.operationType.isNull() & row.operation.equals('patch'))),
      )
      ..orderBy([
        (row) => OrderingTerm.desc(row.createdAtUtc),
        (row) => OrderingTerm.desc(row.updatedAtUtc),
      ]);
    final edits = await query.get();
    final predecessorIds = {
      for (final edit in edits)
        if (edit.dependsOnOpId != null) edit.dependsOnOpId!,
    };
    for (final edit in edits) {
      if (!predecessorIds.contains(edit.id)) {
        return edit;
      }
    }
    return edits.isEmpty ? null : edits.first;
  }

  Future<String> deleteLocalEvent(String eventId) async {
    final existing = await (_database.select(
      _database.calendarEvents,
    )..where((row) => row.id.equals(eventId))).getSingle();
    final source = await (_database.select(
      _database.calendarSources,
    )..where((row) => row.id.equals(existing.calendarSourceId))).getSingle();
    _requireWritableSource(
      source,
      operation: CalendarMutationOperation.deleteEvent,
    );
    final now = _now().millisecondsSinceEpoch;
    await _database.transaction(() async {
      await (_database.update(
        _database.calendarEvents,
      )..where((row) => row.id.equals(eventId))).write(
        CalendarEventsCompanion(
          isDeleted: const Value(true),
          syncStatus: const Value('pending'),
          updatedAtLocal: Value(now),
        ),
      );
      await _database
          .into(_database.pendingOps)
          .insert(
            PendingOpsCompanion.insert(
              id: const Uuid().v4(),
              accountId: existing.accountId,
              provider: Value(existing.provider),
              entityType: 'event',
              operation: 'delete',
              operationType: const Value('event.delete'),
              calendarSourceId: Value(existing.calendarSourceId),
              providerCalendarId: Value(existing.providerCalendarId),
              eventId: Value(existing.id),
              requestJson: '{}',
              baselineUpdatedUtc: Value(existing.updatedAtServer),
              baselineRawJson: Value(existing.baselineRawJson),
              createdAtUtc: DateTime.now().toUtc().toIso8601String(),
              updatedAtUtc: DateTime.now().toUtc().toIso8601String(),
            ),
          );
    });
    await _notificationScheduleService().rebuildUpcomingEventNotifications(
      existing.accountId,
    );
    await _onNotificationScheduleChanged?.call();
    return existing.accountId;
  }

  NotificationScheduleService _notificationScheduleService() {
    return NotificationScheduleService(
      database: _database,
      nowUtc: () => _now().toUtc(),
    );
  }

  Future<void> markMissingEventsDeleted({
    required String accountId,
    required BusyProvider provider,
    required String providerCalendarId,
    required DateTime rangeStart,
    required DateTime rangeEnd,
    required Set<String> returnedLocalEventIds,
  }) async {
    final source = sourceId(
      accountId: accountId,
      provider: provider,
      providerCalendarId: providerCalendarId,
    );
    final rows =
        await (_database.select(_database.calendarEvents)..where(
              (row) =>
                  row.accountId.equals(accountId) &
                  row.calendarSourceId.equals(source) &
                  row.isDeleted.equals(false),
            ))
            .get();
    final now = _now().millisecondsSinceEpoch;
    for (final row in rows) {
      if (returnedLocalEventIds.contains(row.id) ||
          row.syncStatus != 'synced') {
        continue;
      }
      final start = row.allDay
          ? _parseDate(row.startDate)
          : DateTime.tryParse(row.startDateTime ?? '');
      final end = row.allDay
          ? _parseDate(row.endDate)
          : DateTime.tryParse(row.endDateTime ?? '');
      if (!_intersects(rangeStart, rangeEnd, start, end)) {
        continue;
      }
      await (_database.update(
        _database.calendarEvents,
      )..where((table) => table.id.equals(row.id))).write(
        CalendarEventsCompanion(
          isDeleted: const Value(true),
          syncStatus: const Value('synced'),
          updatedAtLocal: Value(now),
        ),
      );
    }
  }

  Future<void> markGoogleRecurringMastersDeleted({
    required String accountId,
    required String providerCalendarId,
    required Set<String> providerRecurringEventIds,
  }) async {
    if (providerRecurringEventIds.isEmpty) {
      return;
    }
    final source = sourceId(
      accountId: accountId,
      provider: TaskProvider.google,
      providerCalendarId: providerCalendarId,
    );
    await (_database.update(_database.calendarEvents)..where(
          (row) =>
              row.accountId.equals(accountId) &
              row.calendarSourceId.equals(source) &
              row.provider.equals(TaskProvider.google.storageValue) &
              row.providerEventId.isIn(providerRecurringEventIds) &
              row.providerRecurringEventId.isNull() &
              row.syncStatus.equals('synced') &
              row.isDeleted.equals(false),
        ))
        .write(
          CalendarEventsCompanion(
            isDeleted: const Value(true),
            syncStatus: const Value('synced'),
            updatedAtLocal: Value(_now().millisecondsSinceEpoch),
          ),
        );
  }

  Future<CalendarSyncState?> syncState({
    required String accountId,
    required BusyProvider provider,
    required String syncKind,
    String? calendarSourceId,
  }) {
    final id = syncStateId(
      accountId: accountId,
      provider: provider,
      syncKind: syncKind,
      calendarSourceId: calendarSourceId,
    );
    return (_database.select(
      _database.calendarSyncStates,
    )..where((row) => row.id.equals(id))).getSingleOrNull();
  }

  static String syncStateId({
    required String accountId,
    required BusyProvider provider,
    required String syncKind,
    String? calendarSourceId,
  }) {
    return [
      accountId,
      provider.storageValue,
      syncKind,
      calendarSourceId ?? 'account',
    ].join('|');
  }

  static String sourceId({
    required String accountId,
    required BusyProvider provider,
    required String providerCalendarId,
  }) {
    return '$accountId|${provider.storageValue}|$providerCalendarId';
  }

  static String eventId({
    required String accountId,
    required BusyProvider provider,
    required String providerCalendarId,
    required String providerEventId,
    String? providerOriginalStartKey,
  }) {
    return [
      accountId,
      provider.storageValue,
      providerCalendarId,
      providerEventId,
      providerOriginalStartKey ?? '',
    ].join('|');
  }
}

void _requireWritableSource(
  CalendarSource source, {
  required CalendarMutationOperation operation,
}) {
  if (!source.readOnly && !source.isDeleted) {
    return;
  }
  throw CalendarMutationNotAllowed(operation: operation, sourceId: source.id);
}

String? _json(Object? value) => value == null ? null : jsonEncode(value);

Map<String, Object?> _eventRequest(
  EventEditorDraft draft,
  BusyProvider provider, {
  required bool isCreate,
  String? startTimeZone,
  String? endTimeZone,
}) {
  final attendees = _attendeesJson(draft, provider);
  final clearFields = <String>[
    if (!isCreate && draft.recurrenceChanged && draft.recurrence == null)
      calendarEventRecurrenceField,
    if (!isCreate && draft.attendeesChanged && attendees == null)
      calendarEventAttendeesField,
  ];
  return {
    'title': draft.title.trim(),
    'description': draft.description,
    'descriptionContentType': draft.descriptionContentType,
    'descriptionHtml': draft.descriptionHtml,
    'location': draft.location,
    'allDay': draft.allDay,
    'start': draft.start?.toIso8601String(),
    'end': draft.end?.toIso8601String(),
    'startTimeZone': startTimeZone,
    'endTimeZone': endTimeZone,
    if (isCreate || draft.recurrenceChanged)
      calendarEventRecurrenceField: draft.recurrence,
    'remindersJson': draft.reminders,
    if (isCreate || draft.attendeesChanged)
      calendarEventAttendeesField: attendees,
    'colorId': draft.colorId,
    if (isCreate || draft.categoriesChanged)
      'categoriesJson': _categoriesJson(draft, provider),
    'visibility': provider == TaskProvider.google
        ? draft.visibilityOrSensitivity
        : null,
    'sensitivity': provider == TaskProvider.microsoft
        ? draft.visibilityOrSensitivity
        : null,
    'transparencyOrShowAs': draft.showAs,
    'importance': draft.importance,
    'conferenceJson': draft.conference,
    'responseRequested': draft.responseRequested,
    'hideAttendees': draft.hideAttendees,
    'allowNewTimeProposals': draft.allowNewTimeProposals,
    if (clearFields.isNotEmpty) calendarEventClearFieldsKey: clearFields,
  };
}

String? _effectiveStartTimeZone(
  EventEditorDraft draft,
  String? sourceTimeZone,
  String? localTimeZone,
) {
  if (draft.allDay) {
    return null;
  }
  return _effectiveTimedEventZone(
    explicitTimeZone: draft.startTimeZone,
    sourceTimeZone: sourceTimeZone,
    localTimeZone: localTimeZone,
  );
}

String? _effectiveEndTimeZone(
  EventEditorDraft draft,
  String? sourceTimeZone,
  String? startTimeZone,
  String? localTimeZone,
) {
  if (draft.allDay) {
    return null;
  }
  final explicit = _nonBlank(draft.endTimeZone);
  if (explicit != null && !_isUtcTimeZone(explicit)) {
    return explicit;
  }
  return _nonBlank(startTimeZone) ??
      _nonBlank(localTimeZone) ??
      explicit ??
      _nonBlank(sourceTimeZone) ??
      'UTC';
}

String _effectiveTimedEventZone({
  required String? explicitTimeZone,
  required String? sourceTimeZone,
  required String? localTimeZone,
}) {
  final explicit = _nonBlank(explicitTimeZone);
  if (explicit != null && !_isUtcTimeZone(explicit)) {
    return explicit;
  }
  return _nonBlank(localTimeZone) ??
      explicit ??
      _nonBlank(sourceTimeZone) ??
      'UTC';
}

bool _isUtcTimeZone(String value) {
  final normalized = value.trim().toLowerCase();
  return normalized == 'utc' ||
      normalized == 'etc/utc' ||
      normalized == 'gmt' ||
      normalized == 'etc/gmt';
}

String? _nonBlank(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}

Object? _attendeesJson(EventEditorDraft draft, BusyProvider provider) {
  if (draft.attendees.isEmpty) {
    return null;
  }
  return [
    for (final attendee in draft.attendees)
      provider == TaskProvider.microsoft
          ? attendee.toMicrosoftJson()
          : attendee.toGoogleJson(),
  ];
}

Object? _categoriesJson(EventEditorDraft draft, BusyProvider provider) {
  if (provider != TaskProvider.microsoft) {
    return null;
  }
  return draft.categories;
}

String? _date(DateTime? value) {
  if (value == null) {
    return null;
  }
  return '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
}

DateTime? _parseDate(String? value) {
  if (value == null || value.length < 10) {
    return null;
  }
  return DateTime.tryParse(value.substring(0, 10));
}

bool _intersects(
  DateTime rangeStart,
  DateTime rangeEnd,
  DateTime? start,
  DateTime? end,
) {
  if (start == null) {
    return false;
  }
  final effectiveEnd = end ?? start.add(const Duration(minutes: 1));
  return effectiveEnd.isAfter(rangeStart) && start.isBefore(rangeEnd);
}

import 'dart:convert';

import 'package:busymax/src/providers/busy_provider.dart';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../calendar_providers/calendar_mutation.dart';
import '../../../calendar_providers/calendar_sync_dto.dart';
import '../../../dav/ical/ical_document.dart';
import '../../../dav/ical/ical_semantics.dart';
import '../../../dav/mutation/dav_mutation_patch.dart';
import '../../../dav/mutation/dav_pending_operations.dart';
import '../../../dav/mutation/dav_projection_mutations.dart';
import '../../../dav/storage/dav_object_repository.dart';
import '../../../db/app_database.dart';
import '../../notifications/notification_schedule_service.dart';
import '../presentation/event_editor_draft.dart';
import 'calendar_event_detail.dart';

class CalendarSourceEntity {
  const CalendarSourceEntity({
    required this.id,
    required this.accountId,
    required this.provider,
    required this.providerCalendarId,
    required this.summary,
    required this.selected,
    this.remindersEnabled = true,
    required this.hidden,
    required this.readOnly,
    required this.isDeleted,
    this.primaryCalendar = false,
    this.description,
    this.backgroundColor,
    this.foregroundColor,
    this.colorId,
    this.timeZone,
    this.accessRole,
    this.davCollectionId,
    this.allowedConferenceSolutions = const [],
  });

  factory CalendarSourceEntity.fromRow(CalendarSource row) {
    return CalendarSourceEntity(
      id: row.id,
      accountId: row.accountId,
      provider: BusyProviderCodec.requireStorageValue(row.provider),
      providerCalendarId: row.providerCalendarId,
      summary: row.summary,
      selected: row.selected,
      remindersEnabled: row.remindersEnabled,
      hidden: row.hidden,
      readOnly: row.readOnly,
      isDeleted: row.isDeleted,
      primaryCalendar: row.primaryCalendar,
      description: row.description,
      backgroundColor: row.backgroundColor,
      foregroundColor: row.foregroundColor,
      colorId: row.colorId,
      timeZone: row.timeZone,
      accessRole: row.accessRole,
      davCollectionId: row.davCollectionId,
      allowedConferenceSolutions: _conferenceSolutions(row.rawJson),
    );
  }

  final String id;
  final String accountId;
  final BusyProvider provider;
  final String providerCalendarId;
  final String summary;
  final bool selected;
  final bool remindersEnabled;
  final bool hidden;
  final bool readOnly;
  final bool isDeleted;
  final bool primaryCalendar;
  final String? description;
  final String? backgroundColor;
  final String? foregroundColor;
  final String? colorId;
  final String? timeZone;
  final String? accessRole;
  final String? davCollectionId;
  final List<String> allowedConferenceSolutions;

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

  Future<CalendarEventDetail?> loadEventDetail(String eventId) async {
    final row = await (_database.select(
      _database.calendarEvents,
    )..where((event) => event.id.equals(eventId))).getSingleOrNull();
    return row == null ? null : CalendarEventDetail.fromRow(row);
  }

  Future<void> setSourceSelected(String sourceId, bool selected) async {
    await (_database.update(
      _database.calendarSources,
    )..where((row) => row.id.equals(sourceId))).write(
      CalendarSourcesCompanion(
        selected: Value(selected),
        updatedAtLocal: Value(_now().millisecondsSinceEpoch),
      ),
    );
  }

  Future<void> setSourceRemindersEnabled(String sourceId, bool enabled) async {
    final source = await (_database.select(
      _database.calendarSources,
    )..where((row) => row.id.equals(sourceId))).getSingle();
    await (_database.update(
      _database.calendarSources,
    )..where((row) => row.id.equals(sourceId))).write(
      CalendarSourcesCompanion(
        remindersEnabled: Value(enabled),
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
              remindersEnabled: Value(existing?.remindersEnabled ?? true),
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
    required String cursorKind,
    required String cursorValue,
    bool full = false,
    String? lastError,
    String? stateJson,
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
      await (_database.delete(_database.syncCursors)..where((row) {
            final sameSource = calendarSourceId == null
                ? row.projectionSourceId.isNull()
                : row.projectionSourceId.equals(calendarSourceId);
            return row.accountId.equals(accountId) &
                row.provider.equals(provider.storageValue) &
                row.syncScopeKind.equals(syncKind) &
                sameSource &
                row.id.equals(id).not();
          }))
          .go();
      await _database
          .into(_database.syncCursors)
          .insertOnConflictUpdate(
            SyncCursorsCompanion.insert(
              id: id,
              accountId: accountId,
              projectionSourceId: Value(calendarSourceId),
              provider: provider.storageValue,
              transport: 'rest',
              syncScopeKind: syncKind,
              cursorKind: cursorKind,
              cursorValue: cursorValue,
              rangeStart: Value(rangeStart),
              rangeEnd: Value(rangeEnd),
              baselineGeneration: Value(full ? now : 0),
              lastCompleteSyncAt: Value(now),
              lastFailureCode: Value(lastError),
              stateJson: Value(stateJson),
            ),
          );
    });
  }

  Future<void> createLocalEvent(
    EventEditorDraft draft, {
    CalendarGuestUpdatePolicy guestUpdatePolicy =
        CalendarGuestUpdatePolicy.send,
  }) async {
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
    if (source.davCollectionId != null) {
      return _createLocalDavEvent(source, draft);
    }
    final now = _now().millisecondsSinceEpoch;
    final provider = BusyProviderCodec.requireStorageValue(source.provider);
    final conferenceRequest = _conferenceRequest(draft, provider);
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
        conference: conferenceRequest,
        guestUpdatePolicy: guestUpdatePolicy,
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
              attendeesJson: Value(_json(_localAttendeesJson(draft, provider))),
              categoriesJson: Value(_json(_categoriesJson(draft, provider))),
              organizerJson: Value(
                _json(_optimisticOrganizer(draft, provider)),
              ),
              colorId: Value(draft.colorId),
              visibility: Value(draft.visibilityOrSensitivity),
              transparencyOrShowAs: Value(draft.showAs),
              conferenceJson: Value(
                _json(conferenceRequest ?? draft.conference),
              ),
              createdAtLocal: now,
              updatedAtLocal: now,
              syncStatus: const Value('pending'),
              rawJson: Value(jsonEncode(_optimisticEventRaw(draft, provider))),
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

  Future<void> updateLocalEvent(
    EventEditorDraft draft, {
    CalendarGuestUpdatePolicy guestUpdatePolicy =
        CalendarGuestUpdatePolicy.send,
  }) async {
    final eventId = draft.eventId;
    if (eventId == null) {
      return createLocalEvent(draft, guestUpdatePolicy: guestUpdatePolicy);
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
    if (source.davCollectionId != null) {
      return _updateLocalDavEvent(source, existing, draft);
    }
    if (draft.recurrenceChanged && existing.providerRecurringEventId != null) {
      throw UnsupportedError(
        'Editing a recurring series from an individual occurrence is not '
        'supported.',
      );
    }
    final now = _now().millisecondsSinceEpoch;
    final provider = BusyProviderCodec.requireStorageValue(source.provider);
    final conferenceRequest = _conferenceRequest(draft, provider);
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
        conference: conferenceRequest,
        guestUpdatePolicy: guestUpdatePolicy,
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
              ? Value(_json(_localAttendeesJson(draft, provider)))
              : const Value.absent(),
          categoriesJson: draft.categoriesChanged
              ? Value(_json(_categoriesJson(draft, provider)))
              : const Value.absent(),
          colorId: Value(draft.colorId),
          visibility: Value(draft.visibilityOrSensitivity),
          transparencyOrShowAs: Value(draft.showAs),
          conferenceJson: Value(_json(conferenceRequest ?? draft.conference)),
          organizerJson: Value(
            _json(
              _optimisticOrganizer(
                draft,
                provider,
                existingJson: existing.organizerJson,
              ),
            ),
          ),
          rawJson: Value(
            jsonEncode(
              _optimisticEventRaw(
                draft,
                provider,
                existingJson: existing.rawJson,
              ),
            ),
          ),
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

  Future<String> deleteLocalEvent(
    String eventId, {
    RecurringEventMutationScope? recurringScope,
    CalendarGuestUpdatePolicy guestUpdatePolicy =
        CalendarGuestUpdatePolicy.send,
  }) async {
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
    if (source.davCollectionId != null) {
      return _deleteLocalDavEvent(
        source,
        existing,
        recurringScope: recurringScope,
      );
    }
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
              requestJson: jsonEncode({
                calendarEventGuestUpdatePolicyKey: guestUpdatePolicy.name,
              }),
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

  Future<String> respondToLocalEvent(
    String eventId,
    CalendarInvitationResponse response, {
    bool sendResponse = true,
  }) async {
    final existing = await (_database.select(
      _database.calendarEvents,
    )..where((row) => row.id.equals(eventId))).getSingle();
    final provider = BusyProviderCodec.requireStorageValue(existing.provider);
    if (provider != BusyProvider.google && provider != BusyProvider.microsoft) {
      throw UnsupportedError(
        '${provider.displayName} invitation responses are not supported.',
      );
    }
    if (existing.isDeleted || existing.isCancelled) {
      throw StateError('A deleted or cancelled event cannot be answered.');
    }

    final attendees = _jsonMapList(existing.attendeesJson);
    final attendeeEmail = provider == BusyProvider.google
        ? _googleSelfAttendeeEmail(attendees)
        : null;
    if (provider == BusyProvider.google && attendeeEmail == null) {
      throw StateError(
        'The Google event does not identify the signed-in attendee.',
      );
    }

    final now = _now().millisecondsSinceEpoch;
    final raw = _jsonMap(existing.rawJson);
    final updatedAttendees = provider == BusyProvider.google
        ? _withGoogleSelfResponse(attendees, response)
        : attendees;
    final updatedRaw = provider == BusyProvider.microsoft
        ? _withMicrosoftResponse(raw, response)
        : raw;
    final predecessor = await _latestPendingEventEdit(
      accountId: existing.accountId,
      eventId: eventId,
    );
    await _database.transaction(() async {
      await (_database.delete(_database.pendingOps)..where(
            (row) =>
                row.accountId.equals(existing.accountId) &
                row.eventId.equals(eventId) &
                row.operationType.equals('event.respond'),
          ))
          .go();
      await (_database.update(
        _database.calendarEvents,
      )..where((row) => row.id.equals(eventId))).write(
        CalendarEventsCompanion(
          attendeesJson: provider == BusyProvider.google
              ? Value(jsonEncode(updatedAttendees))
              : const Value.absent(),
          rawJson: provider == BusyProvider.microsoft
              ? Value(jsonEncode(updatedRaw))
              : const Value.absent(),
          updatedAtLocal: Value(now),
          syncStatus: const Value('pending'),
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
              operation: 'respond',
              operationType: const Value('event.respond'),
              calendarSourceId: Value(existing.calendarSourceId),
              providerCalendarId: Value(existing.providerCalendarId),
              eventId: Value(existing.id),
              dependsOnOpId: Value(predecessor?.id),
              requestJson: jsonEncode({
                'response': response.name,
                if (attendeeEmail != null) 'attendeeEmail': attendeeEmail,
                'sendResponse': sendResponse,
              }),
              createdAtUtc: DateTime.now().toUtc().toIso8601String(),
              updatedAtUtc: DateTime.now().toUtc().toIso8601String(),
            ),
          );
    });
    return existing.accountId;
  }

  Future<void> _createLocalDavEvent(
    CalendarSource source,
    EventEditorDraft draft,
  ) async {
    _requireDavSchedulingUnchanged(draft, creating: true);
    final start = draft.start;
    final end = draft.end;
    final collectionId = source.davCollectionId;
    if (start == null ||
        end == null ||
        collectionId == null ||
        !draft.canSave) {
      throw ArgumentError(
        'A valid DAV event range and collection are required.',
      );
    }
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
    final object = buildDavEventObject(
      _davEventInput(
        draft,
        start: start,
        end: end,
        startTimeZone: startTimeZone,
        endTimeZone: endTimeZone,
      ),
      nowUtc: () => _now().toUtc(),
    );
    final projectionId = 'dav-local-event-${const Uuid().v4()}';
    final now = _now();
    final nowMillis = now.millisecondsSinceEpoch;
    final projectionJson = jsonEncode({
      'transport': 'caldav',
      'uid': object.uid,
      'localPendingCreate': true,
    });
    await _database.transaction(() async {
      await _database
          .into(_database.calendarEvents)
          .insert(
            CalendarEventsCompanion.insert(
              id: projectionId,
              accountId: draft.accountId,
              calendarSourceId: source.id,
              provider: source.provider,
              providerCalendarId: source.providerCalendarId,
              providerEventId: object.uid,
              davCollectionId: Value(collectionId),
              icalUid: Value(object.uid),
              occurrenceKey: Value(object.uid),
              providerRecurringEventId: Value(
                _hasDavRecurrence(draft.recurrence) ? object.uid : null,
              ),
              title: draft.title.trim(),
              description: Value(draft.description),
              location: Value(draft.location),
              allDay: Value(draft.allDay),
              startDate: Value(draft.allDay ? _date(start) : null),
              startDateTime: Value(
                draft.allDay ? null : start.toIso8601String(),
              ),
              startTimeZone: Value(startTimeZone),
              endDate: Value(draft.allDay ? _date(end) : null),
              endDateTime: Value(draft.allDay ? null : end.toIso8601String()),
              endTimeZone: Value(endTimeZone),
              recurrenceJson: Value(_json(draft.recurrence)),
              remindersJson: Value(_json(draft.reminders)),
              attendeesJson: const Value(null),
              categoriesJson: Value(_json(draft.categories)),
              visibility: Value(draft.visibilityOrSensitivity),
              transparencyOrShowAs: Value(draft.showAs),
              isDeleted: const Value(false),
              rawJson: Value(projectionJson),
              baselineRawJson: Value(projectionJson),
              createdAtLocal: nowMillis,
              updatedAtLocal: nowMillis,
              syncStatus: const Value('pending'),
            ),
          );
      await DavPendingOperationQueue(
        database: _database,
        nowUtc: () => _now().toUtc(),
      ).enqueueCreate(
        accountId: draft.accountId,
        collectionId: collectionId,
        object: object,
        localProjectionId: projectionId,
      );
    });
    await _notificationScheduleService().rebuildUpcomingEventNotifications(
      draft.accountId,
    );
    await _onNotificationScheduleChanged?.call();
  }

  Future<void> _updateLocalDavEvent(
    CalendarSource source,
    CalendarEvent existing,
    EventEditorDraft draft,
  ) async {
    _requireDavSchedulingUnchanged(draft, creating: false);
    final collectionId = source.davCollectionId;
    final uid = existing.icalUid;
    final start = draft.start;
    final end = draft.end;
    if (collectionId == null || uid == null || start == null || end == null) {
      throw StateError('The DAV event projection is incomplete.');
    }
    final recurring = existing.providerRecurringEventId != null;
    final recurringScope = draft.recurringMutationScope;
    if (recurring &&
        (recurringScope == null ||
            recurringScope == RecurringEventMutationScope.thisAndFuture)) {
      throw UnsupportedError(
        'A supported recurring-event editing scope is required.',
      );
    }
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
    var input = _davEventInput(
      draft,
      start: start,
      end: end,
      startTimeZone: startTimeZone,
      endTimeZone: endTimeZone,
    );
    final target = IcalComponentKey(
      componentType: 'VEVENT',
      uid: uid,
      recurrenceIdKey: existing.recurrenceIdKey,
    );
    final queue = DavPendingOperationQueue(
      database: _database,
      nowUtc: () => _now().toUtc(),
    );
    DavMutationPatch? patch;
    late final String baselineRawIcs;
    final objectId = existing.davObjectId;
    if (objectId == null) {
      final create = await _pendingDavCreateForProjection(existing.id);
      if (create == null) {
        throw StateError('The pending DAV event create is unavailable.');
      }
      baselineRawIcs = _pendingCreateRawIcs(create);
    } else {
      baselineRawIcs = await queue.editableRawIcsForObject(
        accountId: existing.accountId,
        collectionId: collectionId,
        objectId: objectId,
      );
    }
    if (recurringScope == RecurringEventMutationScope.entireSeries) {
      input = _seriesDavEventInput(
        baselineRawIcs: baselineRawIcs,
        uid: uid,
        existing: existing,
        desired: input,
      );
      patch = buildDavEventUpdatePatch(
        target: IcalComponentKey(componentType: 'VEVENT', uid: uid),
        baselineRawIcs: baselineRawIcs,
        input: input,
      );
    } else if (recurringScope == RecurringEventMutationScope.singleOccurrence &&
        existing.recurrenceIdKey == null) {
      final occurrenceKey = existing.occurrenceKey;
      if (occurrenceKey == null || objectId == null) {
        throw UnsupportedError(
          'One-occurrence editing requires a synchronized occurrence.',
        );
      }
      patch = buildDavEventOccurrenceExceptionPatch(
        uid: uid,
        occurrenceKey: occurrenceKey,
        baselineRawIcs: baselineRawIcs,
        input: input,
        nowUtc: () => _now().toUtc(),
      );
    } else {
      patch = buildDavEventUpdatePatch(
        target: target,
        baselineRawIcs: baselineRawIcs,
        input: input,
      );
    }
    if (patch == null) return;
    final candidate = patch.applyTo(baselineRawIcs, nowUtc: _now().toUtc());

    await _database.transaction(() async {
      if (objectId == null) {
        final updated = await queue.updateUnsentCreate(
          accountId: existing.accountId,
          collectionId: collectionId,
          localProjectionId: existing.id,
          patch: patch!,
        );
        if (!updated) {
          throw StateError(
            'The pending DAV event create is no longer editable.',
          );
        }
      } else {
        await queue.enqueueUpdate(
          accountId: existing.accountId,
          collectionId: collectionId,
          objectId: objectId,
          patch: patch!,
        );
      }
      if (objectId == null) {
        await _writeDavEventProjection(
          existing.id,
          draft,
          startTimeZone: startTimeZone,
          endTimeZone: endTimeZone,
        );
      } else {
        await DavObjectRepository(
          database: _database,
        ).projectLocalMutationCandidate(
          accountId: existing.accountId,
          collectionId: collectionId,
          provider: BusyProviderCodec.requireStorageValue(source.provider),
          objectId: objectId,
          candidateRawIcs: candidate,
          projectedAtUtc: _now().toUtc(),
        );
      }
    });
    await _notificationScheduleService().rebuildUpcomingEventNotifications(
      existing.accountId,
    );
    await _onNotificationScheduleChanged?.call();
  }

  Future<String> _deleteLocalDavEvent(
    CalendarSource source,
    CalendarEvent existing, {
    RecurringEventMutationScope? recurringScope,
  }) async {
    final collectionId = source.davCollectionId;
    final uid = existing.icalUid;
    if (collectionId == null || uid == null) {
      throw StateError('The DAV event projection is incomplete.');
    }
    final recurring = existing.providerRecurringEventId != null;
    if (recurring &&
        (recurringScope == null ||
            recurringScope == RecurringEventMutationScope.thisAndFuture)) {
      throw UnsupportedError(
        'A supported recurring-event deletion scope is required.',
      );
    }
    final queue = DavPendingOperationQueue(
      database: _database,
      nowUtc: () => _now().toUtc(),
    );
    final objectId = existing.davObjectId;
    await _database.transaction(() async {
      if (objectId == null) {
        if (recurringScope == RecurringEventMutationScope.singleOccurrence) {
          throw UnsupportedError(
            'One-occurrence deletion requires a synchronized occurrence.',
          );
        }
        final cancelled = await queue.cancelUnsentCreate(
          accountId: existing.accountId,
          collectionId: collectionId,
          localProjectionId: existing.id,
        );
        if (!cancelled) {
          throw StateError(
            'The DAV event create may already be in progress and cannot be '
            'cancelled locally.',
          );
        }
        await (_database.delete(
          _database.calendarEvents,
        )..where((row) => row.id.equals(existing.id))).go();
        return;
      }

      final object = await (_database.select(
        _database.davObjects,
      )..where((row) => row.id.equals(objectId))).getSingleOrNull();
      if (object == null || object.collectionId != collectionId) {
        throw StateError('The DAV event baseline is unavailable.');
      }
      final provider = BusyProviderCodec.requireStorageValue(source.provider);
      if (recurringScope == RecurringEventMutationScope.singleOccurrence) {
        final occurrenceKey = existing.occurrenceKey;
        if (occurrenceKey == null) {
          throw StateError('The DAV occurrence identity is unavailable.');
        }
        final editableRawIcs = await queue.editableRawIcsForObject(
          accountId: existing.accountId,
          collectionId: collectionId,
          objectId: objectId,
        );
        final patch = buildDavEventOccurrenceCancellationPatch(
          uid: uid,
          occurrenceKey: occurrenceKey,
          baselineRawIcs: editableRawIcs,
          nowUtc: () => _now().toUtc(),
        );
        final candidate = patch.applyTo(editableRawIcs, nowUtc: _now().toUtc());
        await queue.enqueueUpdate(
          accountId: existing.accountId,
          collectionId: collectionId,
          objectId: objectId,
          patch: patch,
        );
        await DavObjectRepository(
          database: _database,
        ).projectLocalMutationCandidate(
          accountId: existing.accountId,
          collectionId: collectionId,
          provider: provider,
          objectId: objectId,
          candidateRawIcs: candidate,
          projectedAtUtc: _now().toUtc(),
        );
        return;
      }

      final semantic = IcalSemanticDocument.parse(object.rawIcsBody);
      final targets = <IcalComponentKey>[
        for (final component in semantic.components)
          if (component.componentType == 'VEVENT' &&
              component.uid == uid &&
              (recurringScope == RecurringEventMutationScope.entireSeries ||
                  component.recurrenceIdKey == existing.recurrenceIdKey))
            IcalComponentKey(
              componentType: component.componentType,
              uid: uid,
              recurrenceIdKey: component.recurrenceIdKey,
            ),
      ];
      if (targets.isEmpty) {
        throw StateError('The DAV event component is unavailable.');
      }
      final targetIdentities = targets.map(_icalComponentIdentity).toSet();
      final targetDocumentComponents = {
        for (final component in semantic.components)
          if (targetIdentities.contains(
            _icalComponentIdentity(
              IcalComponentKey(
                componentType: component.componentType,
                uid: component.uid!,
                recurrenceIdKey: component.recurrenceIdKey,
              ),
            ),
          ))
            component.documentComponent,
      };
      final hasUntargetedCalendarComponent = semantic
          .document
          .calendarComponents
          .any(
            (component) =>
                component.name != 'VTIMEZONE' &&
                !targetDocumentComponents.contains(component),
          );
      if (!hasUntargetedCalendarComponent) {
        await queue.enqueueDelete(
          accountId: existing.accountId,
          collectionId: collectionId,
          objectId: objectId,
          target: targets.first,
          scope: recurring
              ? DavMutationScope.recurrenceMaster
              : DavMutationScope.object,
        );
        await (_database.update(
          _database.calendarEvents,
        )..where((row) => row.davObjectId.equals(objectId))).write(
          CalendarEventsCompanion(
            isDeleted: const Value(true),
            syncStatus: const Value('pending'),
            updatedAtLocal: Value(_now().millisecondsSinceEpoch),
          ),
        );
        return;
      }
      final patch = buildDavComponentRemovalPatch(
        targets: targets,
        scope: recurring
            ? DavMutationScope.recurrenceMaster
            : DavMutationScope.object,
      );
      final candidate = patch.applyTo(
        object.rawIcsBody,
        nowUtc: _now().toUtc(),
      );
      await queue.enqueueUpdate(
        accountId: existing.accountId,
        collectionId: collectionId,
        objectId: objectId,
        patch: patch,
      );
      await DavObjectRepository(
        database: _database,
      ).projectLocalMutationCandidate(
        accountId: existing.accountId,
        collectionId: collectionId,
        provider: provider,
        objectId: objectId,
        candidateRawIcs: candidate,
        projectedAtUtc: _now().toUtc(),
      );
    });
    await _notificationScheduleService().rebuildUpcomingEventNotifications(
      existing.accountId,
    );
    await _onNotificationScheduleChanged?.call();
    return existing.accountId;
  }

  Future<PendingOp?> _pendingDavCreateForProjection(String projectionId) {
    return (_database.select(_database.pendingOps)
          ..where(
            (row) =>
                row.eventId.equals(projectionId) &
                row.operationType.equals('dav.create') &
                row.state.equals('pending') &
                row.attemptCount.equals(0),
          )
          ..limit(1))
        .getSingleOrNull();
  }

  Future<void> _writeDavEventProjection(
    String eventId,
    EventEditorDraft draft, {
    required String? startTimeZone,
    required String? endTimeZone,
  }) {
    return (_database.update(
      _database.calendarEvents,
    )..where((row) => row.id.equals(eventId))).write(
      CalendarEventsCompanion(
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
        endDateTime: Value(draft.allDay ? null : draft.end?.toIso8601String()),
        endTimeZone: Value(endTimeZone),
        recurrenceJson: draft.recurrenceChanged
            ? Value(_json(draft.recurrence))
            : const Value.absent(),
        remindersJson: Value(_json(draft.reminders)),
        categoriesJson: draft.categoriesChanged
            ? Value(_json(draft.categories))
            : const Value.absent(),
        visibility: Value(draft.visibilityOrSensitivity),
        transparencyOrShowAs: Value(draft.showAs),
        updatedAtLocal: Value(_now().millisecondsSinceEpoch),
        syncStatus: const Value('pending'),
      ),
    );
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
      provider: BusyProvider.google,
      providerCalendarId: providerCalendarId,
    );
    await (_database.update(_database.calendarEvents)..where(
          (row) =>
              row.accountId.equals(accountId) &
              row.calendarSourceId.equals(source) &
              row.provider.equals(BusyProvider.google.storageValue) &
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

  Future<SyncCursor?> syncState({
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
      _database.syncCursors,
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

void _requireDavSchedulingUnchanged(
  EventEditorDraft draft, {
  required bool creating,
}) {
  final changesAttendees = creating
      ? draft.attendees.isNotEmpty
      : draft.attendeesChanged;
  if (changesAttendees ||
      draft.createConference ||
      (creating && draft.conference != null)) {
    throw UnsupportedError(
      'DAV attendee and scheduling mutations are disabled until scheduling '
      'inbox/outbox interoperability is available.',
    );
  }
}

DavEventMutationInput _davEventInput(
  EventEditorDraft draft, {
  required DateTime start,
  required DateTime end,
  required String? startTimeZone,
  required String? endTimeZone,
}) {
  return DavEventMutationInput(
    title: draft.title,
    allDay: draft.allDay,
    start: start,
    end: end,
    startTimeZone: startTimeZone,
    endTimeZone: endTimeZone,
    description: draft.description,
    location: draft.location,
    recurrence: draft.recurrence,
    recurrenceChanged: draft.recurrenceChanged,
    reminders: draft.reminders,
    categories: draft.categories,
    categoriesChanged: draft.categoriesChanged,
    classification: draft.visibilityOrSensitivity,
    transparency: draft.showAs,
  );
}

DavEventMutationInput _seriesDavEventInput({
  required String baselineRawIcs,
  required String uid,
  required CalendarEvent existing,
  required DavEventMutationInput desired,
}) {
  final semantic = IcalSemanticDocument.parse(baselineRawIcs);
  final masters = semantic.components.where(
    (component) =>
        component.componentType == 'VEVENT' &&
        component.uid == uid &&
        component.recurrenceIdKey == null,
  );
  if (masters.length != 1 || masters.single.start == null) {
    throw StateError('The DAV recurrence master is unavailable.');
  }
  final master = masters.single;
  final masterStart = _editableIcalTemporal(master.start!);
  final masterEnd = master.end == null
      ? masterStart.add(master.duration?.duration ?? const Duration(hours: 1))
      : _editableIcalTemporal(master.end!);
  final projectedStart = DateTime.tryParse(
    existing.allDay ? existing.startDate ?? '' : existing.startDateTime ?? '',
  );
  final projectedEnd = DateTime.tryParse(
    existing.allDay ? existing.endDate ?? '' : existing.endDateTime ?? '',
  );
  if (projectedStart == null || projectedEnd == null) {
    throw StateError('The DAV occurrence projection is incomplete.');
  }
  final startChanged = desired.start != projectedStart;
  final endChanged = desired.end != projectedEnd;
  final allDayChanged = desired.allDay != existing.allDay;
  final seriesStart = startChanged
      ? masterStart.add(desired.start.difference(projectedStart))
      : masterStart;
  final seriesEnd = endChanged
      ? masterEnd.add(desired.end.difference(projectedEnd))
      : masterEnd;
  final masterTimeZone = _icalTimeZone(master.start!);
  final masterEndTimeZone = master.end == null
      ? masterTimeZone
      : _icalTimeZone(master.end!);
  return DavEventMutationInput(
    title: desired.title != existing.title
        ? desired.title
        : master.summary ?? '',
    allDay: allDayChanged ? desired.allDay : master.start!.isDate,
    start: seriesStart,
    end: seriesEnd,
    startTimeZone: startChanged || allDayChanged
        ? desired.startTimeZone
        : masterTimeZone,
    endTimeZone: endChanged || allDayChanged
        ? desired.endTimeZone
        : masterEndTimeZone,
    description: (desired.description ?? '') != (existing.description ?? '')
        ? desired.description
        : master.description,
    location: (desired.location ?? '') != (existing.location ?? '')
        ? desired.location
        : master.location,
    recurrence: desired.recurrence,
    recurrenceChanged: desired.recurrenceChanged,
    reminders: desired.reminders,
    categories: desired.categories,
    categoriesChanged: desired.categoriesChanged,
    classification:
        (desired.classification ?? '') != (existing.visibility ?? '')
        ? desired.classification
        : master.classification,
    transparency:
        (desired.transparency ?? '') != (existing.transparencyOrShowAs ?? '')
        ? desired.transparency
        : master.transparency,
  );
}

DateTime _editableIcalTemporal(IcalTemporalValue value) {
  final wall = value.localValue;
  if (value.kind == IcalTemporalKind.utcDateTime) return wall.toUtc();
  return DateTime(
    wall.year,
    wall.month,
    wall.day,
    wall.hour,
    wall.minute,
    wall.second,
  );
}

String? _icalTimeZone(IcalTemporalValue value) => switch (value.kind) {
  IcalTemporalKind.utcDateTime => 'UTC',
  IcalTemporalKind.tzidDateTime => value.timeZoneId,
  IcalTemporalKind.date || IcalTemporalKind.floatingDateTime => null,
};

String _icalComponentIdentity(IcalComponentKey key) =>
    '${key.componentType.toUpperCase()}\u0000${key.uid}\u0000'
    '${key.recurrenceIdKey ?? ''}';

bool _hasDavRecurrence(Object? recurrence) {
  if (recurrence is List) return recurrence.isNotEmpty;
  if (recurrence is Map && recurrence['rules'] is List) {
    return (recurrence['rules']! as List).isNotEmpty;
  }
  return false;
}

String _pendingCreateRawIcs(PendingOp operation) {
  try {
    final decoded = jsonDecode(operation.requestJson);
    if (decoded is Map && decoded['rawIcs'] is String) {
      return decoded['rawIcs']! as String;
    }
  } on FormatException {
    // Invalid pending payloads use the same local-state error.
  }
  throw StateError('The pending DAV event body is invalid.');
}

String? _json(Object? value) => value == null ? null : jsonEncode(value);

Map<String, Object?> _eventRequest(
  EventEditorDraft draft,
  BusyProvider provider, {
  required bool isCreate,
  String? startTimeZone,
  String? endTimeZone,
  Object? conference,
  required CalendarGuestUpdatePolicy guestUpdatePolicy,
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
    'visibility': provider == BusyProvider.google
        ? draft.visibilityOrSensitivity
        : null,
    'sensitivity': provider == BusyProvider.microsoft
        ? draft.visibilityOrSensitivity
        : null,
    'transparencyOrShowAs': draft.showAs,
    'importance': draft.importance,
    if (conference != null) 'conferenceJson': conference,
    'responseRequested': draft.responseRequested,
    'hideAttendees': draft.hideAttendees,
    'allowNewTimeProposals': draft.allowNewTimeProposals,
    calendarEventGuestUpdatePolicyKey: guestUpdatePolicy.name,
    if (clearFields.isNotEmpty) calendarEventClearFieldsKey: clearFields,
  };
}

Object? _conferenceRequest(EventEditorDraft draft, BusyProvider provider) {
  if (!draft.createConference) return null;
  return switch (provider) {
    BusyProvider.google => {
      'createRequest': {
        'requestId': const Uuid().v4(),
        'conferenceSolutionKey': {'type': 'hangoutsMeet'},
      },
    },
    BusyProvider.microsoft => 'teamsForBusiness',
    BusyProvider.appleICloud || BusyProvider.nextcloud => null,
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
      provider == BusyProvider.microsoft
          ? attendee.toMicrosoftJson()
          : attendee.toGoogleJson(),
  ];
}

Object? _localAttendeesJson(EventEditorDraft draft, BusyProvider provider) {
  if (draft.attendees.isEmpty) return null;
  return [
    for (final attendee in draft.attendees)
      if (provider == BusyProvider.microsoft)
        {
          ...attendee.toMicrosoftJson(),
          if (attendee.responseStatus case final response?
              when response.isNotEmpty)
            'status': {'response': response},
        }
      else
        {
          ...attendee.toGoogleJson(),
          if (attendee.self) 'self': true,
          if (attendee.organizer) 'organizer': true,
        },
  ];
}

Map<String, Object?>? _optimisticOrganizer(
  EventEditorDraft draft,
  BusyProvider provider, {
  String? existingJson,
}) {
  final existing = _jsonMap(existingJson);
  if (provider != BusyProvider.google || draft.isOrganizer == null) {
    return existing.isEmpty ? null : existing;
  }
  return {...existing, 'self': draft.isOrganizer};
}

Map<String, Object?> _optimisticEventRaw(
  EventEditorDraft draft,
  BusyProvider provider, {
  String? existingJson,
}) {
  final raw = {..._jsonMap(existingJson)};
  switch (provider) {
    case BusyProvider.google:
      if (draft.hideAttendees case final hidden?) {
        raw['guestsCanSeeOtherGuests'] = !hidden;
      }
    case BusyProvider.microsoft:
      if (draft.importance case final importance?) {
        raw['importance'] = importance;
      }
      if (draft.responseRequested case final requested?) {
        raw['responseRequested'] = requested;
      }
      if (draft.hideAttendees case final hidden?) {
        raw['hideAttendees'] = hidden;
      }
      if (draft.allowNewTimeProposals case final allowed?) {
        raw['allowNewTimeProposals'] = allowed;
      }
      if (draft.isOrganizer case final organizer?) {
        raw['isOrganizer'] = organizer;
      }
    case BusyProvider.appleICloud:
    case BusyProvider.nextcloud:
      break;
  }
  return raw;
}

List<Map<String, Object?>> _jsonMapList(String? value) {
  if (value == null || value.isEmpty) return const [];
  try {
    final decoded = jsonDecode(value);
    if (decoded is! List) return const [];
    return [
      for (final item in decoded)
        if (item is Map) Map<String, Object?>.from(item),
    ];
  } on FormatException {
    return const [];
  }
}

Map<String, Object?> _jsonMap(String? value) {
  if (value == null || value.isEmpty) return const {};
  try {
    final decoded = jsonDecode(value);
    return decoded is Map ? Map<String, Object?>.from(decoded) : const {};
  } on FormatException {
    return const {};
  }
}

List<String> _conferenceSolutions(String? rawJson) {
  final raw = _jsonMap(rawJson);
  final allowed = raw['allowedOnlineMeetingProviders'];
  final conferenceProperties = raw['conferenceProperties'];
  final googleAllowed = conferenceProperties is Map
      ? conferenceProperties['allowedConferenceSolutionTypes']
      : null;
  final providers = <String>{
    if (allowed is List)
      for (final value in allowed)
        if (value != null && value.toString().trim().isNotEmpty)
          value.toString().trim(),
    if (googleAllowed is List)
      for (final value in googleAllowed)
        if (value != null && value.toString().trim().isNotEmpty)
          value.toString().trim(),
    if (raw['defaultOnlineMeetingProvider'] case final value?
        when value.toString().trim().isNotEmpty)
      value.toString().trim(),
  };
  return providers.toList(growable: false);
}

String? _googleSelfAttendeeEmail(List<Map<String, Object?>> attendees) {
  for (final attendee in attendees) {
    if (attendee['self'] != true) continue;
    final email = attendee['email']?.toString().trim();
    if (email != null && email.isNotEmpty) return email;
  }
  return null;
}

List<Map<String, Object?>> _withGoogleSelfResponse(
  List<Map<String, Object?>> attendees,
  CalendarInvitationResponse response,
) {
  final status = switch (response) {
    CalendarInvitationResponse.accept => 'accepted',
    CalendarInvitationResponse.tentative => 'tentative',
    CalendarInvitationResponse.decline => 'declined',
  };
  return [
    for (final attendee in attendees)
      attendee['self'] == true
          ? {...attendee, 'responseStatus': status}
          : attendee,
  ];
}

Map<String, Object?> _withMicrosoftResponse(
  Map<String, Object?> raw,
  CalendarInvitationResponse response,
) {
  final current = raw['responseStatus'];
  final responseStatus = current is Map
      ? Map<String, Object?>.from(current)
      : <String, Object?>{};
  responseStatus['response'] = switch (response) {
    CalendarInvitationResponse.accept => 'accepted',
    CalendarInvitationResponse.tentative => 'tentativelyAccepted',
    CalendarInvitationResponse.decline => 'declined',
  };
  return {...raw, 'responseStatus': responseStatus};
}

Object? _categoriesJson(EventEditorDraft draft, BusyProvider provider) {
  if (provider != BusyProvider.microsoft) {
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

import 'dart:convert';

import 'package:busymax/src/providers/busy_provider.dart';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../calendar_providers/calendar_mutation.dart';
import '../../../calendar_providers/calendar_colors.dart';
import '../../../calendar_providers/calendar_provider_capabilities.dart';
import '../../../calendar_providers/calendar_sync_dto.dart';
import '../../../core/time/provider_date_time.dart';
import '../../../dav/ical/ical_document.dart';
import '../../../dav/ical/ical_semantics.dart';
import '../../../dav/mutation/dav_mutation_patch.dart';
import '../../../dav/mutation/dav_pending_operations.dart';
import '../../../dav/mutation/dav_projection_mutations.dart';
import '../../../dav/storage/dav_object_repository.dart';
import '../../../db/app_database.dart';
import '../../notifications/notification_schedule_service.dart';
import '../../recurrence/domain/event_recurrence_codec.dart';
import '../domain/event_move_policy.dart';
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
    this.dataOwner,
    this.isRemovable,
    this.authenticatedAccountEmail,
    this.pendingCreate = false,
    this.davCollectionId,
    this.allowedConferenceSolutions = const [],
  });

  factory CalendarSourceEntity.fromRow(
    CalendarSource row, {
    String? authenticatedAccountEmail,
    bool pendingCreate = false,
  }) {
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
      dataOwner: row.dataOwner,
      isRemovable: row.isRemovable,
      authenticatedAccountEmail: authenticatedAccountEmail,
      pendingCreate: pendingCreate,
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
  final String? dataOwner;
  final bool? isRemovable;
  final String? authenticatedAccountEmail;
  final bool pendingCreate;
  final String? davCollectionId;
  final List<String> allowedConferenceSolutions;

  CalendarSourceCapabilities get capabilities =>
      CalendarSourceCapabilities.fromSource(this);

  bool get isCurrentGoogleDataOwner {
    if (provider != BusyProvider.google) return false;
    final owner = dataOwner?.trim().toLowerCase();
    final identity = authenticatedAccountEmail?.trim().toLowerCase();
    return owner != null &&
        owner.isNotEmpty &&
        identity != null &&
        identity.isNotEmpty &&
        owner == identity;
  }

  bool get hasAuthenticatedGoogleIdentity =>
      provider == BusyProvider.google &&
      authenticatedAccountEmail?.trim().isNotEmpty == true;
}

enum CalendarRenameMode { unavailable, global, personal }

enum CalendarRemovalMode { unavailable, delete, removeFromList }

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
    required this.canRenameCalendar,
    required this.canDeleteCalendar,
    required this.canChangeCalendarColor,
    required this.renameMode,
    required this.removalMode,
  });

  factory CalendarSourceCapabilities.fromSource(CalendarSourceEntity source) {
    final available = !source.isDeleted;
    final writable = !source.readOnly && available;
    final management = calendarManagementCapabilities(source.provider);
    final renameMode = switch (source.provider) {
      BusyProvider.google || BusyProvider.microsoft
          when available && source.pendingCreate =>
        CalendarRenameMode.global,
      BusyProvider.google when available =>
        source.primaryCalendar || source.isCurrentGoogleDataOwner
            ? CalendarRenameMode.global
            : CalendarRenameMode.personal,
      BusyProvider.microsoft when writable => CalendarRenameMode.global,
      _ => CalendarRenameMode.unavailable,
    };
    final removalMode = switch (source.provider) {
      BusyProvider.google || BusyProvider.microsoft
          when available && source.pendingCreate =>
        CalendarRemovalMode.delete,
      BusyProvider.google
          when available &&
              !source.primaryCalendar &&
              source.isCurrentGoogleDataOwner =>
        CalendarRemovalMode.delete,
      BusyProvider.google
          when available &&
              !source.primaryCalendar &&
              source.hasAuthenticatedGoogleIdentity &&
              source.dataOwner?.trim().isNotEmpty == true =>
        CalendarRemovalMode.removeFromList,
      BusyProvider.microsoft
          when available &&
              !source.primaryCalendar &&
              source.isRemovable == true =>
        CalendarRemovalMode.delete,
      _ => CalendarRemovalMode.unavailable,
    };
    return CalendarSourceCapabilities(
      canCreateEvents: writable,
      canEditEvents: writable,
      canDeleteEvents: writable,
      canRenameCalendar:
          management.supportsRename &&
          renameMode != CalendarRenameMode.unavailable,
      canDeleteCalendar:
          management.supportsDelete &&
          removalMode == CalendarRemovalMode.delete,
      canChangeCalendarColor:
          management.supportsColor &&
          (source.provider == BusyProvider.google ? available : writable),
      renameMode: renameMode,
      removalMode: removalMode,
    );
  }

  static const unavailable = CalendarSourceCapabilities(
    canCreateEvents: false,
    canEditEvents: false,
    canDeleteEvents: false,
    canRenameCalendar: false,
    canDeleteCalendar: false,
    canChangeCalendarColor: false,
    renameMode: CalendarRenameMode.unavailable,
    removalMode: CalendarRemovalMode.unavailable,
  );

  final bool canCreateEvents;
  final bool canEditEvents;
  final bool canDeleteEvents;
  final bool canRenameCalendar;
  final bool canDeleteCalendar;
  final bool canChangeCalendarColor;
  final CalendarRenameMode renameMode;
  final CalendarRemovalMode removalMode;

  bool get canRemoveCalendar => removalMode != CalendarRemovalMode.unavailable;
}

enum CalendarMutationOperation {
  createCalendar,
  createEvent,
  editEvent,
  moveEvent,
  deleteEvent,
  renameCalendar,
  changeCalendarColor,
  deleteCalendar,
  removeCalendar,
}

class CalendarMutationNotAllowed implements Exception {
  const CalendarMutationNotAllowed({
    required this.operation,
    required this.sourceId,
    this.reason = CalendarMutationDenialReason.capability,
  });

  final CalendarMutationOperation operation;
  final String sourceId;
  final CalendarMutationDenialReason reason;

  @override
  String toString() {
    return 'CalendarMutationNotAllowed('
        '${operation.name}, source: $sourceId, reason: ${reason.name})';
  }
}

enum CalendarMutationDenialReason {
  capability,
  pendingChanges,
  destinationPendingCreate,
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
    final query = _database.select(_database.calendarSources).join([
      innerJoin(
        _database.accounts,
        _database.accounts.id.equalsExp(_database.calendarSources.accountId),
      ),
      leftOuterJoin(
        _database.pendingOps,
        _database.pendingOps.calendarSourceId.equalsExp(
              _database.calendarSources.id,
            ) &
            _database.pendingOps.operationType.equals('calendar.create') &
            _database.pendingOps.state.equals('pending'),
      ),
    ]);
    query.where(
      _database.calendarSources.accountId.isIn(accountIds) &
          _database.calendarSources.isDeleted.equals(false),
    );
    query.orderBy([
      OrderingTerm.asc(_database.calendarSources.accountId),
      OrderingTerm.asc(_database.calendarSources.summary),
    ]);
    return query.watch().map(
      (rows) => [
        for (final result in rows)
          CalendarSourceEntity.fromRow(
            result.readTable(_database.calendarSources),
            authenticatedAccountEmail: result
                .readTable(_database.accounts)
                .email,
            pendingCreate: result.readTableOrNull(_database.pendingOps) != null,
          ),
      ],
    );
  }

  Future<List<CalendarSourceEntity>> listVisibleSources(
    List<String> accountIds,
  ) async {
    if (accountIds.isEmpty) {
      return const [];
    }
    final query = _database.select(_database.calendarSources).join([
      innerJoin(
        _database.accounts,
        _database.accounts.id.equalsExp(_database.calendarSources.accountId),
      ),
      leftOuterJoin(
        _database.pendingOps,
        _database.pendingOps.calendarSourceId.equalsExp(
              _database.calendarSources.id,
            ) &
            _database.pendingOps.operationType.equals('calendar.create') &
            _database.pendingOps.state.equals('pending'),
      ),
    ]);
    query.where(
      _database.calendarSources.accountId.isIn(accountIds) &
          _database.calendarSources.selected.equals(true) &
          _database.calendarSources.hidden.equals(false) &
          _database.calendarSources.isDeleted.equals(false),
    );
    final rows = await query.get();
    return [
      for (final result in rows)
        CalendarSourceEntity.fromRow(
          result.readTable(_database.calendarSources),
          authenticatedAccountEmail: result.readTable(_database.accounts).email,
          pendingCreate: result.readTableOrNull(_database.pendingOps) != null,
        ),
    ];
  }

  Future<CalendarEventDetail?> loadEventDetail(String eventId) async {
    final row = await (_database.select(
      _database.calendarEvents,
    )..where((event) => event.id.equals(eventId))).getSingleOrNull();
    return row == null ? null : CalendarEventDetail.fromRow(row);
  }

  Future<CalendarSourceEntity> _sourceEntity(CalendarSource source) async {
    final account = await (_database.select(
      _database.accounts,
    )..where((row) => row.id.equals(source.accountId))).getSingle();
    return CalendarSourceEntity.fromRow(
      source,
      authenticatedAccountEmail: account.email,
      pendingCreate: await _pendingCalendarCreate(source.id) != null,
    );
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

  Future<String> createLocalSource({
    required String accountId,
    required String summary,
  }) async {
    final title = summary.trim();
    if (title.isEmpty) {
      throw ArgumentError.value(summary, 'summary', 'Calendar title is empty.');
    }
    final account = await (_database.select(
      _database.accounts,
    )..where((row) => row.id.equals(accountId))).getSingle();
    final provider = BusyProviderCodec.requireStorageValue(account.provider);
    if (!calendarManagementCapabilities(provider).supportsCreate) {
      throw CalendarMutationNotAllowed(
        operation: CalendarMutationOperation.createCalendar,
        sourceId: accountId,
      );
    }

    final uuid = const Uuid();
    final providerCalendarId = 'local:${uuid.v4()}';
    final id = sourceId(
      accountId: accountId,
      provider: provider,
      providerCalendarId: providerCalendarId,
    );
    final operationId = uuid.v4();
    final now = _now();
    final nowUtc = now.toUtc().toIso8601String();
    await _database.transaction(() async {
      await _database
          .into(_database.calendarSources)
          .insert(
            CalendarSourcesCompanion.insert(
              id: id,
              accountId: accountId,
              provider: provider.storageValue,
              providerCalendarId: providerCalendarId,
              summary: title,
              rawJson: Value(
                jsonEncode({
                  'id': providerCalendarId,
                  'summary': title,
                  '_localCreated': true,
                }),
              ),
              createdAtLocal: now.millisecondsSinceEpoch,
              updatedAtLocal: now.millisecondsSinceEpoch,
            ),
          );
      await _database.pendingOpsDao.enqueue(
        PendingOpsCompanion.insert(
          id: operationId,
          accountId: accountId,
          provider: Value(provider.storageValue),
          entityType: 'calendar',
          operation: 'create',
          operationType: const Value('calendar.create'),
          calendarSourceId: Value(id),
          providerCalendarId: Value(providerCalendarId),
          localTempId: Value(providerCalendarId),
          requestJson: jsonEncode({'summary': title}),
          createdAtUtc: nowUtc,
          updatedAtUtc: nowUtc,
        ),
      );
    });
    return id;
  }

  Future<void> renameLocalSource(String sourceId, String summary) async {
    final source = await (_database.select(
      _database.calendarSources,
    )..where((row) => row.id.equals(sourceId))).getSingle();
    final entity = await _sourceEntity(source);
    _requireCalendarSourceCapability(
      source,
      operation: CalendarMutationOperation.renameCalendar,
      allowed: entity.capabilities.canRenameCalendar,
    );
    final title = summary.trim();
    if (title.isEmpty) {
      throw ArgumentError.value(summary, 'summary', 'Calendar title is empty.');
    }
    final now = _now();
    final nowUtc = now.toUtc().toIso8601String();
    final createOp = await _pendingCalendarCreate(source.id);
    await _database.transaction(() async {
      await (_database.update(
        _database.calendarSources,
      )..where((row) => row.id.equals(sourceId))).write(
        CalendarSourcesCompanion(
          summary: Value(title),
          updatedAtLocal: Value(now.millisecondsSinceEpoch),
        ),
      );
      if (createOp != null) {
        final request = _calendarPendingRequest(createOp)..['summary'] = title;
        await (_database.update(
          _database.pendingOps,
        )..where((row) => row.id.equals(createOp.id))).write(
          PendingOpsCompanion(
            requestJson: Value(jsonEncode(request)),
            updatedAtUtc: Value(nowUtc),
          ),
        );
      } else {
        await _enqueueOrMergeCalendarPatch(
          source,
          request: {
            'summary': title,
            calendarMutationScopeKey:
                entity.capabilities.renameMode == CalendarRenameMode.personal
                ? calendarMutationScopePersonal
                : calendarMutationScopeGlobal,
          },
          nowUtc: nowUtc,
        );
      }
    });
  }

  Future<void> setSourceColor(
    String sourceId,
    CalendarColorChoice choice,
  ) async {
    final source = await (_database.select(
      _database.calendarSources,
    )..where((row) => row.id.equals(sourceId))).getSingle();
    final entity = await _sourceEntity(source);
    _requireCalendarSourceCapability(
      source,
      operation: CalendarMutationOperation.changeCalendarColor,
      allowed: entity.capabilities.canChangeCalendarColor,
    );
    final supportedChoice = calendarColorChoices(entity.provider).any(
      (candidate) =>
          candidate.providerValue == choice.providerValue &&
          candidate.backgroundColor.toLowerCase() ==
              choice.backgroundColor.toLowerCase(),
    );
    if (!supportedChoice) {
      throw ArgumentError.value(
        choice.providerValue,
        'choice',
        'Unsupported calendar color.',
      );
    }

    final now = _now();
    final nowUtc = now.toUtc().toIso8601String();
    final createOp = await _pendingCalendarCreate(source.id);
    final foregroundColor = calendarColorForegroundHex(choice.backgroundColor);
    final request = switch (entity.provider) {
      BusyProvider.google => <String, Object?>{
        'backgroundColor': choice.backgroundColor,
        'foregroundColor': foregroundColor,
        calendarMutationScopeKey: calendarMutationScopePersonal,
      },
      BusyProvider.microsoft => <String, Object?>{
        'colorId': choice.providerValue,
      },
      BusyProvider.appleICloud || BusyProvider.nextcloud => throw StateError(
        'DAV calendar colors are not mutable.',
      ),
    };
    await _database.transaction(() async {
      await (_database.update(
        _database.calendarSources,
      )..where((row) => row.id.equals(sourceId))).write(
        CalendarSourcesCompanion(
          backgroundColor: Value(choice.backgroundColor),
          foregroundColor: entity.provider == BusyProvider.google
              ? Value(foregroundColor)
              : const Value.absent(),
          colorId: Value(
            entity.provider == BusyProvider.microsoft
                ? choice.providerValue
                : null,
          ),
          updatedAtLocal: Value(now.millisecondsSinceEpoch),
        ),
      );
      await _enqueueOrMergeCalendarPatch(
        source,
        request: request,
        nowUtc: nowUtc,
        dependsOnOpId: createOp?.id,
      );
    });
  }

  Future<void> deleteLocalSource(String sourceId) async {
    final source = await (_database.select(
      _database.calendarSources,
    )..where((row) => row.id.equals(sourceId))).getSingle();
    final entity = await _sourceEntity(source);
    final removalMode = entity.capabilities.removalMode;
    final createOp = await _pendingCalendarCreate(source.id);
    _requireCalendarSourceCapability(
      source,
      operation: removalMode == CalendarRemovalMode.removeFromList
          ? CalendarMutationOperation.removeCalendar
          : CalendarMutationOperation.deleteCalendar,
      allowed: createOp != null || entity.capabilities.canRemoveCalendar,
    );
    final now = _now();
    final nowUtc = now.toUtc().toIso8601String();
    await _database.transaction(() async {
      if (createOp != null) {
        await (_database.delete(_database.pendingOps)..where(
              (row) =>
                  row.accountId.equals(source.accountId) &
                  row.calendarSourceId.equals(source.id),
            ))
            .go();
        await (_database.delete(
          _database.calendarSources,
        )..where((row) => row.id.equals(sourceId))).go();
        return;
      }
      if ((await _pendingCalendarWork(source.id)).isNotEmpty) {
        throw CalendarMutationNotAllowed(
          operation: removalMode == CalendarRemovalMode.removeFromList
              ? CalendarMutationOperation.removeCalendar
              : CalendarMutationOperation.deleteCalendar,
          sourceId: source.id,
          reason: CalendarMutationDenialReason.pendingChanges,
        );
      }
      await (_database.update(
        _database.calendarSources,
      )..where((row) => row.id.equals(sourceId))).write(
        CalendarSourcesCompanion(
          isDeleted: const Value(true),
          hidden: const Value(true),
          updatedAtLocal: Value(now.millisecondsSinceEpoch),
        ),
      );
      await _database.pendingOpsDao.enqueue(
        PendingOpsCompanion.insert(
          id: const Uuid().v4(),
          accountId: source.accountId,
          provider: Value(source.provider),
          entityType: 'calendar',
          operation: removalMode == CalendarRemovalMode.removeFromList
              ? 'remove'
              : 'delete',
          operationType: Value(
            removalMode == CalendarRemovalMode.removeFromList
                ? 'calendar.remove'
                : 'calendar.delete',
          ),
          calendarSourceId: Value(source.id),
          providerCalendarId: Value(source.providerCalendarId),
          requestJson: jsonEncode({
            calendarRemovalPreviousHiddenKey: source.hidden,
          }),
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
      final preservePendingRemoval =
          existing != null && await _hasActiveCalendarRemoval(existing.id);
      final isDeleted = preservePendingRemoval || source.isDeleted;
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
              dataOwner: Value(source.dataOwner),
              isRemovable: Value(source.isRemovable),
              isDeleted: Value(isDeleted),
              rawJson: Value(jsonEncode(source.rawJson)),
              createdAtLocal: existing?.createdAtLocal ?? now,
              updatedAtLocal: now,
            ),
          );
    });
  }

  Future<void> restoreSourceAfterRemovalFailure(PendingOp op) async {
    final operationType =
        op.operationType ?? '${op.entityType}.${op.operation}';
    if (operationType != 'calendar.delete' &&
        operationType != 'calendar.remove') {
      return;
    }
    final sourceId = op.calendarSourceId;
    if (sourceId == null) return;
    final source = await (_database.select(
      _database.calendarSources,
    )..where((row) => row.id.equals(sourceId))).getSingleOrNull();
    if (source == null || !source.isDeleted) return;
    await (_database.update(
      _database.calendarSources,
    )..where((row) => row.id.equals(sourceId))).write(
      CalendarSourcesCompanion(
        isDeleted: const Value(false),
        hidden: Value(_calendarRemovalPreviousHidden(op)),
        updatedAtLocal: Value(_now().millisecondsSinceEpoch),
      ),
    );
  }

  Future<void> discardPendingCalendarCreation(PendingOp op) async {
    if (_calendarOperationType(op) != 'calendar.create') return;
    final sourceId = op.calendarSourceId;
    if (sourceId == null) return;
    await _database.transaction(() async {
      final accountOperations = await (_database.select(
        _database.pendingOps,
      )..where((row) => row.accountId.equals(op.accountId))).get();
      final discardedIds = <String>{op.id};
      var changed = true;
      while (changed) {
        changed = false;
        for (final operation in accountOperations) {
          if (discardedIds.contains(operation.id) ||
              (operation.calendarSourceId != sourceId &&
                  !discardedIds.contains(operation.dependsOnOpId))) {
            continue;
          }
          discardedIds.add(operation.id);
          changed = true;
        }
      }
      for (final operationId in discardedIds) {
        await _database.pendingOpsDao.deleteOp(operationId);
      }
      await (_database.delete(
        _database.calendarSources,
      )..where((row) => row.id.equals(sourceId))).go();
    });
    await _notificationScheduleService().rebuildUpcomingEventNotifications(
      op.accountId,
    );
    await _onNotificationScheduleChanged?.call();
  }

  Future<void> restoreSourceAfterPatchDiscard(PendingOp op) async {
    if (_calendarOperationType(op) != 'calendar.patch') return;
    final sourceId = op.calendarSourceId;
    if (sourceId == null) return;
    final source = await (_database.select(
      _database.calendarSources,
    )..where((row) => row.id.equals(sourceId))).getSingleOrNull();
    if (source == null) return;
    final request = _jsonMap(op.requestJson);
    final previous = _jsonObjectMap(request[calendarPatchPreviousValuesKey]);
    final baseline = _jsonMap(op.baselineRawJson);
    final changesSummary = request.containsKey('summary');
    final changesColor =
        request.containsKey('backgroundColor') ||
        request.containsKey('foregroundColor') ||
        request.containsKey('colorId');
    if (!changesSummary && !changesColor) return;
    final provider = BusyProviderCodec.requireStorageValue(source.provider);
    final baselineSummary = switch (provider) {
      BusyProvider.google =>
        baseline['summaryOverride']?.toString().trim().isNotEmpty == true
            ? baseline['summaryOverride']!.toString()
            : baseline['summary']?.toString(),
      BusyProvider.microsoft => baseline['name']?.toString(),
      BusyProvider.appleICloud || BusyProvider.nextcloud => null,
    };
    final baselineColorId = switch (provider) {
      BusyProvider.google => baseline['colorId']?.toString(),
      BusyProvider.microsoft => baseline['color']?.toString(),
      BusyProvider.appleICloud || BusyProvider.nextcloud => null,
    };
    final baselineBackground = switch (provider) {
      BusyProvider.google => baseline['backgroundColor']?.toString(),
      BusyProvider.microsoft => calendarSourceBackgroundColorHex(
        provider: provider,
        backgroundColor: baseline['hexColor']?.toString(),
        colorId: baselineColorId,
      ),
      BusyProvider.appleICloud || BusyProvider.nextcloud => null,
    };
    await (_database.update(
      _database.calendarSources,
    )..where((row) => row.id.equals(sourceId))).write(
      CalendarSourcesCompanion(
        summary: changesSummary
            ? Value(
                previous['summary']?.toString() ??
                    baselineSummary ??
                    source.summary,
              )
            : const Value.absent(),
        backgroundColor: changesColor
            ? Value(
                previous.containsKey('backgroundColor')
                    ? previous['backgroundColor']?.toString()
                    : baselineBackground,
              )
            : const Value.absent(),
        foregroundColor: changesColor
            ? Value(
                previous.containsKey('foregroundColor')
                    ? previous['foregroundColor']?.toString()
                    : baseline['foregroundColor']?.toString(),
              )
            : const Value.absent(),
        colorId: changesColor
            ? Value(
                previous.containsKey('colorId')
                    ? previous['colorId']?.toString()
                    : baselineColorId,
              )
            : const Value.absent(),
        updatedAtLocal: Value(_now().millisecondsSinceEpoch),
      ),
    );
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

  Future<String> createLocalEvent(
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
    final calendarCreateOp = await _pendingCalendarCreate(source.id);
    final now = _now().millisecondsSinceEpoch;
    final provider = BusyProviderCodec.requireStorageValue(source.provider);
    final conferenceRequest = _conferenceRequest(draft, provider);
    final localEventId = 'local:${const Uuid().v4()}';
    final operationId = const Uuid().v4();
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
              id: operationId,
              accountId: draft.accountId,
              provider: Value(source.provider),
              entityType: 'event',
              operation: 'create',
              operationType: const Value('event.create'),
              calendarSourceId: Value(draft.sourceId),
              providerCalendarId: Value(draft.providerCalendarId),
              eventId: Value(id),
              localTempId: Value(localEventId),
              dependsOnOpId: Value(calendarCreateOp?.id),
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
    return operationId;
  }

  Future<void> updateLocalEvent(
    EventEditorDraft draft, {
    CalendarGuestUpdatePolicy guestUpdatePolicy =
        CalendarGuestUpdatePolicy.send,
  }) async {
    final eventId = draft.eventId;
    if (eventId == null) {
      await createLocalEvent(draft, guestUpdatePolicy: guestUpdatePolicy);
      return;
    }
    final source = await (_database.select(
      _database.calendarSources,
    )..where((row) => row.id.equals(draft.sourceId))).getSingle();
    final existing = await (_database.select(
      _database.calendarEvents,
    )..where((row) => row.id.equals(eventId))).getSingle();
    final originalSource = await (_database.select(
      _database.calendarSources,
    )..where((row) => row.id.equals(existing.calendarSourceId))).getSingle();
    _requireFullEventEditingAllowed(existing);
    _requireAttendeeManagementAllowed(existing, draft);
    final editBaseline = _eventEditBaseline(draft, existing);
    _requireWritableSource(
      source,
      operation: CalendarMutationOperation.editEvent,
    );
    if (source.accountId != draft.accountId ||
        source.providerCalendarId != draft.providerCalendarId) {
      throw CalendarMutationNotAllowed(
        operation: CalendarMutationOperation.editEvent,
        sourceId: source.id,
      );
    }
    final sourceChanged =
        draft.accountId != existing.accountId ||
        draft.sourceId != existing.calendarSourceId ||
        draft.providerCalendarId != existing.providerCalendarId;
    if (sourceChanged) {
      _requireWritableSource(
        originalSource,
        operation: CalendarMutationOperation.deleteEvent,
      );
      return _moveLocalEvent(
        originalSource: originalSource,
        destinationSource: source,
        existing: existing,
        draft: draft,
        guestUpdatePolicy: guestUpdatePolicy,
      );
    }
    if (source.provider != existing.provider ||
        source.accountId != existing.accountId ||
        source.providerCalendarId != existing.providerCalendarId) {
      throw CalendarMutationNotAllowed(
        operation: CalendarMutationOperation.editEvent,
        sourceId: source.id,
      );
    }
    if (source.davCollectionId != null) {
      return _updateLocalDavEvent(source, existing, draft);
    }
    final provider = BusyProviderCodec.requireStorageValue(source.provider);
    final recurringOccurrence = existing.providerRecurringEventId != null;
    final recurringScope = draft.recurringMutationScope;
    if (recurringOccurrence && recurringScope == null) {
      throw UnsupportedError('A recurring-event editing scope is required.');
    }
    if (recurringScope == RecurringEventMutationScope.thisAndFuture &&
        provider != BusyProvider.google) {
      throw UnsupportedError(
        '${provider.displayName} does not expose a documented '
        'this-and-following mutation through this API.',
      );
    }
    if (recurringScope == RecurringEventMutationScope.thisAndFuture &&
        !_googleEventCanSplit(existing)) {
      throw UnsupportedError(
        'This Google series contains event-type or conference data that '
        'cannot be split safely.',
      );
    }
    if (draft.recurrenceChanged && recurringOccurrence) {
      throw UnsupportedError(
        'Editing a recurring series from an individual occurrence is not '
        'supported.',
      );
    }
    final now = _now().millisecondsSinceEpoch;
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
    final seriesMutation =
        recurringScope == RecurringEventMutationScope.entireSeries ||
        recurringScope == RecurringEventMutationScope.thisAndFuture;
    final request = _eventDeltaRequest(
      draft,
      editBaseline,
      provider,
      startTimeZone: startTimeZone,
      endTimeZone: endTimeZone,
      conference: conferenceRequest,
      guestUpdatePolicy: guestUpdatePolicy,
    );
    if (!_eventRequestHasMutation(request)) {
      return;
    }
    if (recurringOccurrence) {
      request[calendarEventRecurringScopeKey] = recurringScope!.name;
      if (seriesMutation) {
        request[calendarEventTargetProviderIdKey] =
            existing.providerRecurringEventId;
        request[calendarEventOriginalStartKey] =
            existing.providerOriginalStartKey ?? _storedEventStart(existing);
        request[calendarEventOriginalEndKey] = _storedEventEnd(existing);
      }
    }
    final requestJson = jsonEncode(request);
    await _database.transaction(() async {
      final predecessor = await _latestPendingEventEdit(
        accountId: draft.accountId,
        eventId: eventId,
      );
      final projection = _eventPatchProjection(
        draft: draft,
        existing: existing,
        provider: provider,
        request: request,
        startTimeZone: startTimeZone,
        endTimeZone: endTimeZone,
        conference: conferenceRequest,
        now: now,
      );
      if (seriesMutation) {
        await _writeCloudSeriesProjection(
          existing: existing,
          draft: draft,
          scope: recurringScope!,
          provider: provider,
          conference: conferenceRequest,
          startTimeZone: startTimeZone,
          endTimeZone: endTimeZone,
          now: now,
        );
      } else {
        await (_database.update(
          _database.calendarEvents,
        )..where((row) => row.id.equals(eventId))).write(projection);
      }
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
              baselineUpdatedUtc: seriesMutation
                  ? const Value(null)
                  : Value(editBaseline.updatedAtServer),
              baselineRawJson: seriesMutation
                  ? const Value(null)
                  : Value(_eventDetailBaselineRawJson(editBaseline)),
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

  Future<void> _moveLocalEvent({
    required CalendarSource originalSource,
    required CalendarSource destinationSource,
    required CalendarEvent existing,
    required EventEditorDraft draft,
    required CalendarGuestUpdatePolicy guestUpdatePolicy,
  }) async {
    if (await _pendingCalendarCreate(destinationSource.id) != null) {
      throw CalendarMutationNotAllowed(
        operation: CalendarMutationOperation.moveEvent,
        sourceId: destinationSource.id,
        reason: CalendarMutationDenialReason.destinationPendingCreate,
      );
    }
    final sourceProvider = BusyProviderCodec.requireStorageValue(
      originalSource.provider,
    );
    final destinationProvider = BusyProviderCodec.requireStorageValue(
      destinationSource.provider,
    );
    final recurring = existing.providerRecurringEventId != null;
    final scope = draft.recurringMutationScope;
    if (recurring && scope == null) {
      throw UnsupportedError('A recurring-event movement scope is required.');
    }
    if (scope == RecurringEventMutationScope.thisAndFuture) {
      throw UnsupportedError(
        'This and following events cannot be moved safely. Move this event or '
        'the entire series.',
      );
    }
    await _requireEventReadyToMove(existing);

    final strategy = calendarEventMoveStrategy(
      sourceAccountId: originalSource.accountId,
      sourceId: originalSource.id,
      sourceProviderCalendarId: originalSource.providerCalendarId,
      sourceProvider: sourceProvider,
      sourceDavCollectionId: originalSource.davCollectionId,
      destinationAccountId: destinationSource.accountId,
      destinationId: destinationSource.id,
      destinationProviderCalendarId: destinationSource.providerCalendarId,
      destinationProvider: destinationProvider,
      destinationDavCollectionId: destinationSource.davCollectionId,
      eventType: existing.eventType,
      recurring: recurring,
      recurringScope: scope,
    );
    switch (strategy) {
      case CalendarEventMoveStrategy.none:
        throw StateError('The destination calendar is unchanged.');
      case CalendarEventMoveStrategy.googleNative:
        await _moveLocalGoogleEvent(
          originalSource: originalSource,
          destinationSource: destinationSource,
          existing: existing,
          draft: draft,
          guestUpdatePolicy: guestUpdatePolicy,
        );
      case CalendarEventMoveStrategy.davNative:
        await _moveLocalDavEvent(
          originalSource: originalSource,
          destinationSource: destinationSource,
          existing: existing,
          draft: draft,
        );
      case CalendarEventMoveStrategy.copyThenDelete:
        await _copyThenDeleteLocalEvent(
          originalSource: originalSource,
          destinationSource: destinationSource,
          existing: existing,
          draft: draft,
          sourceProvider: sourceProvider,
          destinationProvider: destinationProvider,
          guestUpdatePolicy: guestUpdatePolicy,
        );
    }
  }

  Future<void> _requireEventReadyToMove(CalendarEvent existing) async {
    final pending =
        await (_database.select(_database.pendingOps)
              ..where(
                (row) =>
                    row.entityType.equals('event') &
                    row.eventId.equals(existing.id),
              )
              ..limit(1))
            .getSingleOrNull();
    if (existing.syncStatus != 'synced' || pending != null) {
      throw StateError(
        'Wait for this event to finish synchronizing before moving it.',
      );
    }
  }

  Future<void> _moveLocalGoogleEvent({
    required CalendarSource originalSource,
    required CalendarSource destinationSource,
    required CalendarEvent existing,
    required EventEditorDraft draft,
    required CalendarGuestUpdatePolicy guestUpdatePolicy,
  }) async {
    final recurring = existing.providerRecurringEventId != null;
    final scope = draft.recurringMutationScope;
    final provider = BusyProvider.google;
    final startTimeZone = _effectiveStartTimeZone(
      draft,
      destinationSource.timeZone,
      _localTimeZone,
    );
    final endTimeZone = _effectiveEndTimeZone(
      draft,
      destinationSource.timeZone,
      startTimeZone,
      _localTimeZone,
    );
    final conferenceRequest = _conferenceRequest(draft, provider);
    final seriesMutation =
        recurring && scope == RecurringEventMutationScope.entireSeries;
    final patchRequest = _eventDeltaRequest(
      draft,
      _eventEditBaseline(draft, existing),
      provider,
      startTimeZone: startTimeZone,
      endTimeZone: endTimeZone,
      conference: conferenceRequest,
      guestUpdatePolicy: guestUpdatePolicy,
    );
    final targetProviderEventId = seriesMutation
        ? existing.providerRecurringEventId!
        : existing.providerEventId;
    if (seriesMutation) {
      patchRequest[calendarEventRecurringScopeKey] = scope!.name;
      patchRequest[calendarEventTargetProviderIdKey] = targetProviderEventId;
      patchRequest[calendarEventOriginalStartKey] =
          existing.providerOriginalStartKey ?? _storedEventStart(existing);
      patchRequest[calendarEventOriginalEndKey] = _storedEventEnd(existing);
    }
    final moveOperationId = const Uuid().v4();
    final patchOperationId = const Uuid().v4();
    final nowUtc = DateTime.now().toUtc().toIso8601String();
    final patchCreatedAtUtc = DateTime.parse(
      nowUtc,
    ).add(const Duration(microseconds: 1)).toIso8601String();
    final now = _now().millisecondsSinceEpoch;
    await _database.transaction(() async {
      if (seriesMutation && _eventRequestHasMutation(patchRequest)) {
        await _writeCloudSeriesProjection(
          existing: existing,
          draft: draft,
          scope: scope!,
          provider: provider,
          conference: conferenceRequest,
          startTimeZone: startTimeZone,
          endTimeZone: endTimeZone,
          now: now,
        );
      } else {
        await (_database.update(
          _database.calendarEvents,
        )..where((row) => row.id.equals(existing.id))).write(
          CalendarEventsCompanion(
            syncStatus: const Value('pending'),
            updatedAtLocal: Value(now),
          ),
        );
      }
      await _database
          .into(_database.pendingOps)
          .insert(
            PendingOpsCompanion.insert(
              id: moveOperationId,
              accountId: existing.accountId,
              provider: Value(existing.provider),
              entityType: 'event',
              operation: 'move',
              operationType: const Value('event.move'),
              calendarSourceId: Value(originalSource.id),
              providerCalendarId: Value(originalSource.providerCalendarId),
              eventId: Value(existing.id),
              requestJson: jsonEncode({
                calendarEventDestinationCalendarIdKey:
                    destinationSource.providerCalendarId,
                calendarEventDestinationSourceIdKey: destinationSource.id,
                calendarEventTargetProviderIdKey: targetProviderEventId,
                calendarEventGuestUpdatePolicyKey: guestUpdatePolicy.name,
                if (seriesMutation)
                  calendarEventRecurringScopeKey:
                      RecurringEventMutationScope.entireSeries.name,
              }),
              baselineUpdatedUtc: seriesMutation
                  ? const Value(null)
                  : Value(existing.updatedAtServer),
              baselineRawJson: seriesMutation
                  ? const Value(null)
                  : Value(existing.baselineRawJson),
              createdAtUtc: nowUtc,
              updatedAtUtc: nowUtc,
            ),
          );
      if (_eventRequestHasMutation(patchRequest)) {
        await _database
            .into(_database.pendingOps)
            .insert(
              PendingOpsCompanion.insert(
                id: patchOperationId,
                accountId: existing.accountId,
                provider: Value(destinationSource.provider),
                entityType: 'event',
                operation: 'patch',
                operationType: const Value('event.patch'),
                calendarSourceId: Value(destinationSource.id),
                providerCalendarId: Value(destinationSource.providerCalendarId),
                eventId: Value(existing.id),
                dependsOnOpId: Value(moveOperationId),
                requestJson: jsonEncode(patchRequest),
                createdAtUtc: patchCreatedAtUtc,
                updatedAtUtc: patchCreatedAtUtc,
              ),
            );
      }
    });
    await _rebuildEventNotificationsFor({existing.accountId});
  }

  Future<void> _moveLocalDavEvent({
    required CalendarSource originalSource,
    required CalendarSource destinationSource,
    required CalendarEvent existing,
    required EventEditorDraft draft,
  }) async {
    _requireDavSchedulingUnchanged(draft, creating: false);
    final sourceCollectionId = originalSource.davCollectionId;
    final destinationCollectionId = destinationSource.davCollectionId;
    final objectId = existing.davObjectId;
    final uid = existing.icalUid;
    final start = draft.start;
    final end = draft.end;
    if (sourceCollectionId == null ||
        destinationCollectionId == null ||
        objectId == null ||
        uid == null ||
        start == null ||
        end == null) {
      throw StateError('The DAV event is not ready to move.');
    }
    final queue = DavPendingOperationQueue(
      database: _database,
      nowUtc: () => _now().toUtc(),
    );
    final baselineRawIcs = await queue.editableRawIcsForObject(
      accountId: existing.accountId,
      collectionId: sourceCollectionId,
      objectId: objectId,
    );
    final recurring = existing.providerRecurringEventId != null;
    final target = IcalComponentKey(
      componentType: 'VEVENT',
      uid: uid,
      recurrenceIdKey: recurring ? null : existing.recurrenceIdKey,
    );
    final startTimeZone = _effectiveStartTimeZone(
      draft,
      destinationSource.timeZone,
      _localTimeZone,
    );
    final endTimeZone = _effectiveEndTimeZone(
      draft,
      destinationSource.timeZone,
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
    if (recurring) {
      input = _seriesDavEventInput(
        baselineRawIcs: baselineRawIcs,
        uid: uid,
        existing: existing,
        desired: input,
      );
    }
    final patch = buildDavEventUpdatePatch(
      target: target,
      baselineRawIcs: baselineRawIcs,
      input: input,
    );
    final candidate =
        patch?.applyTo(baselineRawIcs, nowUtc: _now().toUtc()) ??
        baselineRawIcs;
    await _database.transaction(() async {
      await queue.enqueueMove(
        accountId: existing.accountId,
        sourceCollectionId: sourceCollectionId,
        destinationCollectionId: destinationCollectionId,
        objectId: objectId,
        target: target,
        localProjectionId: existing.id,
        postMovePatch: patch,
      );
      await DavObjectRepository(
        database: _database,
      ).projectLocalMutationCandidate(
        accountId: existing.accountId,
        collectionId: sourceCollectionId,
        provider: BusyProviderCodec.requireStorageValue(
          originalSource.provider,
        ),
        objectId: objectId,
        candidateRawIcs: candidate,
        projectedAtUtc: _now().toUtc(),
      );
      await (_database.update(_database.calendarEvents)..where(
            (row) =>
                row.accountId.equals(existing.accountId) &
                row.davObjectId.equals(objectId),
          ))
          .write(
            CalendarEventsCompanion(
              calendarSourceId: Value(destinationSource.id),
              providerCalendarId: Value(destinationSource.providerCalendarId),
              davCollectionId: Value(destinationCollectionId),
              syncStatus: const Value('pending'),
              updatedAtLocal: Value(_now().millisecondsSinceEpoch),
            ),
          );
    });
    await _rebuildEventNotificationsFor({existing.accountId});
  }

  Future<void> _copyThenDeleteLocalEvent({
    required CalendarSource originalSource,
    required CalendarSource destinationSource,
    required CalendarEvent existing,
    required EventEditorDraft draft,
    required BusyProvider sourceProvider,
    required BusyProvider destinationProvider,
    required CalendarGuestUpdatePolicy guestUpdatePolicy,
  }) async {
    final copyDraft = _eventCopyDraft(
      draft,
      existing: existing,
      sourceProvider: sourceProvider,
      destinationProvider: destinationProvider,
    );
    final createOperationId = await createLocalEvent(
      copyDraft,
      guestUpdatePolicy: guestUpdatePolicy,
    );
    try {
      if (originalSource.davCollectionId != null) {
        await _queueDavEventDeletionAfterCopy(
          source: originalSource,
          existing: existing,
          recurringScope: draft.recurringMutationScope,
          dependsOnOperationId: createOperationId,
        );
      } else {
        await _queueCloudEventDeletionAfterCopy(
          existing: existing,
          recurringScope: draft.recurringMutationScope,
          guestUpdatePolicy: guestUpdatePolicy,
          dependsOnOperationId: createOperationId,
        );
      }
    } on Object {
      await _discardQueuedEventCreate(createOperationId);
      await _rebuildEventNotificationsFor({destinationSource.accountId});
      rethrow;
    }
    await (_database.update(
      _database.calendarEvents,
    )..where((row) => row.id.equals(existing.id))).write(
      CalendarEventsCompanion(
        syncStatus: const Value('pending'),
        updatedAtLocal: Value(_now().millisecondsSinceEpoch),
      ),
    );
    await _rebuildEventNotificationsFor({
      originalSource.accountId,
      destinationSource.accountId,
    });
  }

  EventEditorDraft _eventCopyDraft(
    EventEditorDraft draft, {
    required CalendarEvent existing,
    required BusyProvider sourceProvider,
    required BusyProvider destinationProvider,
  }) {
    final recurring = existing.providerRecurringEventId != null;
    final scope = draft.recurringMutationScope;
    Object? recurrence = draft.recurrence;
    if (recurring && scope == RecurringEventMutationScope.singleOccurrence) {
      recurrence = null;
    } else if (recurrence != null && sourceProvider != destinationProvider) {
      final sourceRule = EventRecurrenceCodec.decode(
        sourceProvider,
        recurrence,
        baseDate: draft.start,
      );
      if (sourceRule.isSupported && sourceRule.repeats) {
        if (!EventRecurrenceCodec.canEncode(destinationProvider, sourceRule)) {
          throw UnsupportedError(
            '${destinationProvider.displayName} cannot represent this '
            'recurrence rule.',
          );
        }
        recurrence = EventRecurrenceCodec.encode(
          destinationProvider,
          sourceRule,
          baseDate: draft.start ?? DateTime.now(),
          allDay: draft.allDay,
          timeZone: draft.startTimeZone,
        );
      } else {
        final destinationRule = EventRecurrenceCodec.decode(
          destinationProvider,
          recurrence,
          baseDate: draft.start,
        );
        if (!destinationRule.isSupported || !destinationRule.repeats) {
          throw UnsupportedError(
            '${destinationProvider.displayName} cannot represent this '
            'recurrence rule.',
          );
        }
      }
    }
    if (recurring && scope == RecurringEventMutationScope.entireSeries) {
      final rule = EventRecurrenceCodec.decode(
        destinationProvider,
        recurrence,
        baseDate: draft.start,
      );
      if (!rule.isSupported || !rule.repeats) {
        throw UnsupportedError(
          'The recurrence rule is unavailable. Move one occurrence instead.',
        );
      }
    }
    final attendees =
        destinationProvider == BusyProvider.appleICloud ||
            destinationProvider == BusyProvider.nextcloud
        ? const <EventAttendeeDraft>[]
        : [
            for (final attendee in draft.attendees)
              if (!attendee.self && !attendee.organizer)
                EventAttendeeDraft(
                  email: attendee.email,
                  displayName: attendee.displayName,
                  optional: attendee.optional,
                ),
          ];
    final sameProviderAccount =
        sourceProvider == destinationProvider &&
        existing.accountId == draft.accountId;
    return EventEditorDraft(
      accountId: draft.accountId,
      sourceId: draft.sourceId,
      providerCalendarId: draft.providerCalendarId,
      title: draft.title,
      allDay: draft.allDay,
      start: draft.start,
      end: draft.end,
      startTimeZone: draft.startTimeZone,
      endTimeZone: draft.endTimeZone,
      location: draft.location,
      description: draft.description,
      descriptionContentType: destinationProvider == BusyProvider.microsoft
          ? draft.descriptionContentType
          : null,
      descriptionHtml: destinationProvider == BusyProvider.microsoft
          ? draft.descriptionHtml
          : null,
      recurrence: recurrence,
      recurrenceChanged: true,
      reminders: sourceProvider == destinationProvider
          ? draft.reminders
          : _eventRemindersForProvider(draft.reminders, destinationProvider),
      remindersChanged: true,
      attendees: attendees,
      attendeesChanged: true,
      importance: destinationProvider == BusyProvider.microsoft
          ? draft.importance
          : null,
      showAs: _eventShowAsForProvider(draft.showAs, destinationProvider),
      visibilityOrSensitivity: _eventVisibilityForProvider(
        draft.visibilityOrSensitivity,
        destinationProvider,
      ),
      colorId: sameProviderAccount ? draft.colorId : null,
      categories: destinationProvider == BusyProvider.google
          ? const []
          : draft.categories,
      categoriesChanged: true,
      responseRequested: destinationProvider == BusyProvider.microsoft
          ? draft.responseRequested
          : null,
      hideAttendees:
          destinationProvider == BusyProvider.google ||
              destinationProvider == BusyProvider.microsoft
          ? draft.hideAttendees
          : null,
      allowNewTimeProposals: destinationProvider == BusyProvider.microsoft
          ? draft.allowNewTimeProposals
          : null,
      isOrganizer: true,
    );
  }

  Future<void> _queueCloudEventDeletionAfterCopy({
    required CalendarEvent existing,
    required RecurringEventMutationScope? recurringScope,
    required CalendarGuestUpdatePolicy guestUpdatePolicy,
    required String dependsOnOperationId,
  }) async {
    final series = recurringScope == RecurringEventMutationScope.entireSeries;
    final request = <String, Object?>{
      calendarEventGuestUpdatePolicyKey: guestUpdatePolicy.name,
      calendarEventCopyConfirmationRequiredKey: true,
      if (recurringScope != null)
        calendarEventRecurringScopeKey: recurringScope.name,
      if (series) ...{
        calendarEventTargetProviderIdKey: existing.providerRecurringEventId,
        calendarEventOriginalStartKey:
            existing.providerOriginalStartKey ?? _storedEventStart(existing),
        calendarEventOriginalEndKey: _storedEventEnd(existing),
      },
    };
    final now = DateTime.now().toUtc().toIso8601String();
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
            dependsOnOpId: Value(dependsOnOperationId),
            requestJson: jsonEncode(request),
            baselineUpdatedUtc: series
                ? const Value(null)
                : Value(existing.updatedAtServer),
            baselineRawJson: series
                ? const Value(null)
                : Value(existing.baselineRawJson),
            createdAtUtc: now,
            updatedAtUtc: now,
          ),
        );
  }

  Future<void> _queueDavEventDeletionAfterCopy({
    required CalendarSource source,
    required CalendarEvent existing,
    required RecurringEventMutationScope? recurringScope,
    required String dependsOnOperationId,
  }) async {
    final collectionId = source.davCollectionId;
    final objectId = existing.davObjectId;
    final uid = existing.icalUid;
    if (collectionId == null || objectId == null || uid == null) {
      throw StateError('The DAV event baseline is unavailable.');
    }
    final queue = DavPendingOperationQueue(
      database: _database,
      nowUtc: () => _now().toUtc(),
    );
    if (recurringScope == RecurringEventMutationScope.singleOccurrence) {
      final occurrenceKey = existing.occurrenceKey;
      if (occurrenceKey == null) {
        throw StateError('The DAV occurrence identity is unavailable.');
      }
      final raw = await queue.editableRawIcsForObject(
        accountId: existing.accountId,
        collectionId: collectionId,
        objectId: objectId,
      );
      final operationId = await queue.enqueueUpdate(
        accountId: existing.accountId,
        collectionId: collectionId,
        objectId: objectId,
        patch: buildDavEventOccurrenceCancellationPatch(
          uid: uid,
          occurrenceKey: occurrenceKey,
          baselineRawIcs: raw,
          thisAndFuture: false,
          nowUtc: () => _now().toUtc(),
        ),
        dependsOnOperationId: dependsOnOperationId,
      );
      await _requireCopyConfirmation(operationId);
      return;
    }
    final object = await (_database.select(
      _database.davObjects,
    )..where((row) => row.id.equals(objectId))).getSingle();
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
    final identities = targets.map(_icalComponentIdentity).toSet();
    final documents = {
      for (final component in semantic.components)
        if (identities.contains(
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
    final hasOtherComponent = semantic.document.calendarComponents.any(
      (component) =>
          component.name != 'VTIMEZONE' && !documents.contains(component),
    );
    if (!hasOtherComponent) {
      final operationId = await queue.enqueueDelete(
        accountId: existing.accountId,
        collectionId: collectionId,
        objectId: objectId,
        target: targets.first,
        scope: recurringScope == RecurringEventMutationScope.entireSeries
            ? DavMutationScope.recurrenceMaster
            : DavMutationScope.object,
        dependsOnOperationId: dependsOnOperationId,
      );
      await _requireCopyConfirmation(operationId);
      return;
    }
    final operationId = await queue.enqueueUpdate(
      accountId: existing.accountId,
      collectionId: collectionId,
      objectId: objectId,
      patch: buildDavComponentRemovalPatch(
        targets: targets,
        scope: recurringScope == RecurringEventMutationScope.entireSeries
            ? DavMutationScope.recurrenceMaster
            : DavMutationScope.object,
      ),
      dependsOnOperationId: dependsOnOperationId,
    );
    await _requireCopyConfirmation(operationId);
  }

  Future<void> _requireCopyConfirmation(String operationId) async {
    final operation = await (_database.select(
      _database.pendingOps,
    )..where((row) => row.id.equals(operationId))).getSingle();
    final request = _jsonMap(operation.requestJson)
      ..[calendarEventCopyConfirmationRequiredKey] = true;
    await (_database.update(_database.pendingOps)
          ..where((row) => row.id.equals(operationId)))
        .write(PendingOpsCompanion(requestJson: Value(jsonEncode(request))));
  }

  Future<void> _discardQueuedEventCreate(String operationId) async {
    final operation = await (_database.select(
      _database.pendingOps,
    )..where((row) => row.id.equals(operationId))).getSingleOrNull();
    if (operation == null || operation.attemptCount != 0) return;
    await _database.transaction(() async {
      await _database.pendingOpsDao.deleteOp(operationId);
      final eventId = operation.eventId;
      if (eventId != null) {
        await (_database.delete(
          _database.calendarEvents,
        )..where((row) => row.id.equals(eventId))).go();
      }
    });
  }

  Future<void> _rebuildEventNotificationsFor(Set<String> accountIds) async {
    for (final accountId in accountIds) {
      await _notificationScheduleService().rebuildUpcomingEventNotifications(
        accountId,
      );
    }
    await _onNotificationScheduleChanged?.call();
  }

  Future<void> _writeCloudSeriesProjection({
    required CalendarEvent existing,
    required EventEditorDraft draft,
    required RecurringEventMutationScope scope,
    required BusyProvider provider,
    required Object? conference,
    required String? startTimeZone,
    required String? endTimeZone,
    required int now,
  }) async {
    final recurringEventId = existing.providerRecurringEventId;
    if (recurringEventId == null) {
      throw StateError('The recurring event identifier is unavailable.');
    }
    final rows =
        await (_database.select(_database.calendarEvents)..where(
              (row) =>
                  row.accountId.equals(existing.accountId) &
                  row.provider.equals(existing.provider) &
                  row.providerCalendarId.equals(existing.providerCalendarId) &
                  row.providerRecurringEventId.equals(recurringEventId) &
                  row.isDeleted.equals(false),
            ))
            .get();
    final existingStart = _storedEventStartDateTime(existing);
    final existingEnd = _storedEventEndDateTime(existing);
    final startChanged =
        draft.allDay != existing.allDay || draft.start != existingStart;
    final endChanged =
        draft.allDay != existing.allDay || draft.end != existingEnd;
    final startDelta =
        startChanged && draft.start != null && existingStart != null
        ? draft.start!.difference(existingStart)
        : Duration.zero;
    final endDelta = endChanged && draft.end != null && existingEnd != null
        ? draft.end!.difference(existingEnd)
        : Duration.zero;
    final raw = _jsonMap(existing.rawJson);
    final descriptionChanged =
        (draft.description ?? '') != (existing.description ?? '');
    final locationChanged = (draft.location ?? '') != (existing.location ?? '');
    final remindersChanged = !_sameJsonValue(
      _decodeStoredJson(existing.remindersJson),
      draft.reminders,
    );
    final colorChanged = draft.colorId != existing.colorId;
    final visibilityChanged =
        draft.visibilityOrSensitivity != existing.visibility;
    final showAsChanged = draft.showAs != existing.transparencyOrShowAs;
    final importanceChanged = draft.importance != raw['importance']?.toString();
    final responseRequestedChanged =
        draft.responseRequested != raw['responseRequested'];
    final hideAttendeesChanged = provider == BusyProvider.google
        ? draft.hideAttendees !=
              (raw['guestsCanSeeOtherGuests'] is bool
                  ? !(raw['guestsCanSeeOtherGuests'] as bool)
                  : null)
        : draft.hideAttendees != raw['hideAttendees'];
    final newTimeProposalsChanged =
        draft.allowNewTimeProposals != raw['allowNewTimeProposals'];
    final rawChanged =
        importanceChanged ||
        responseRequestedChanged ||
        hideAttendeesChanged ||
        newTimeProposalsChanged;

    for (final row in rows) {
      if (!_seriesRowInScope(row, existing, scope)) continue;
      final rowStart = _storedEventStartDateTime(row);
      final rowEnd = _storedEventEndDateTime(row);
      final shiftedStart = startChanged && rowStart != null
          ? rowStart.add(startDelta)
          : rowStart;
      final shiftedEnd = endChanged && rowEnd != null
          ? rowEnd.add(endDelta)
          : rowEnd;
      final companion = CalendarEventsCompanion(
        title: draft.title.trim() != existing.title
            ? Value(draft.title.trim())
            : const Value.absent(),
        description: descriptionChanged
            ? Value(draft.description)
            : const Value.absent(),
        location: locationChanged
            ? Value(draft.location)
            : const Value.absent(),
        allDay: startChanged || endChanged
            ? Value(draft.allDay)
            : const Value.absent(),
        startDate: startChanged
            ? Value(draft.allDay ? _date(shiftedStart) : null)
            : const Value.absent(),
        startDateTime: startChanged
            ? Value(draft.allDay ? null : shiftedStart?.toIso8601String())
            : const Value.absent(),
        startTimeZone:
            startChanged || draft.startTimeZone != existing.startTimeZone
            ? Value(draft.allDay ? null : startTimeZone)
            : const Value.absent(),
        endDate: endChanged
            ? Value(draft.allDay ? _date(shiftedEnd) : null)
            : const Value.absent(),
        endDateTime: endChanged
            ? Value(draft.allDay ? null : shiftedEnd?.toIso8601String())
            : const Value.absent(),
        endTimeZone: endChanged || draft.endTimeZone != existing.endTimeZone
            ? Value(draft.allDay ? null : endTimeZone)
            : const Value.absent(),
        remindersJson: remindersChanged
            ? Value(_json(draft.reminders))
            : const Value.absent(),
        attendeesJson: draft.attendeesChanged
            ? Value(_json(_localAttendeesJson(draft, provider)))
            : const Value.absent(),
        categoriesJson: draft.categoriesChanged
            ? Value(_json(_categoriesJson(draft, provider)))
            : const Value.absent(),
        colorId: colorChanged ? Value(draft.colorId) : const Value.absent(),
        visibility: visibilityChanged
            ? Value(draft.visibilityOrSensitivity)
            : const Value.absent(),
        transparencyOrShowAs: showAsChanged
            ? Value(draft.showAs)
            : const Value.absent(),
        conferenceJson: conference != null
            ? Value(_json(conference))
            : const Value.absent(),
        rawJson: rawChanged
            ? Value(
                jsonEncode(
                  _optimisticEventRaw(
                    draft,
                    provider,
                    existingJson: row.rawJson,
                  ),
                ),
              )
            : const Value.absent(),
        updatedAtLocal: Value(now),
        syncStatus: const Value('pending'),
      );
      await (_database.update(
        _database.calendarEvents,
      )..where((table) => table.id.equals(row.id))).write(companion);
    }
  }

  Future<void> _markCloudSeriesDeleted({
    required CalendarEvent existing,
    required RecurringEventMutationScope scope,
    required int now,
  }) async {
    final recurringEventId = existing.providerRecurringEventId;
    if (recurringEventId == null) {
      throw StateError('The recurring event identifier is unavailable.');
    }
    final rows =
        await (_database.select(_database.calendarEvents)..where(
              (row) =>
                  row.accountId.equals(existing.accountId) &
                  row.provider.equals(existing.provider) &
                  row.providerCalendarId.equals(existing.providerCalendarId) &
                  row.providerRecurringEventId.equals(recurringEventId) &
                  row.isDeleted.equals(false),
            ))
            .get();
    for (final row in rows) {
      if (!_seriesRowInScope(row, existing, scope)) continue;
      await (_database.update(
        _database.calendarEvents,
      )..where((table) => table.id.equals(row.id))).write(
        CalendarEventsCompanion(
          isDeleted: const Value(true),
          syncStatus: const Value('pending'),
          updatedAtLocal: Value(now),
        ),
      );
    }
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
    final provider = BusyProviderCodec.requireStorageValue(existing.provider);
    final recurringOccurrence = existing.providerRecurringEventId != null;
    if (recurringOccurrence && recurringScope == null) {
      throw UnsupportedError('A recurring-event deletion scope is required.');
    }
    if (recurringScope == RecurringEventMutationScope.thisAndFuture &&
        provider != BusyProvider.google) {
      throw UnsupportedError(
        '${provider.displayName} does not expose a documented '
        'this-and-following mutation through this API.',
      );
    }
    final seriesMutation =
        recurringScope == RecurringEventMutationScope.entireSeries ||
        recurringScope == RecurringEventMutationScope.thisAndFuture;
    final request = <String, Object?>{
      calendarEventGuestUpdatePolicyKey: guestUpdatePolicy.name,
      if (recurringScope != null)
        calendarEventRecurringScopeKey: recurringScope.name,
      if (seriesMutation) ...{
        calendarEventTargetProviderIdKey: existing.providerRecurringEventId,
        calendarEventOriginalStartKey:
            existing.providerOriginalStartKey ?? _storedEventStart(existing),
        calendarEventOriginalEndKey: _storedEventEnd(existing),
      },
    };
    final now = _now().millisecondsSinceEpoch;
    await _database.transaction(() async {
      if (seriesMutation) {
        await _markCloudSeriesDeleted(
          existing: existing,
          scope: recurringScope!,
          now: now,
        );
      } else {
        await (_database.update(
          _database.calendarEvents,
        )..where((row) => row.id.equals(eventId))).write(
          CalendarEventsCompanion(
            isDeleted: const Value(true),
            syncStatus: const Value('pending'),
            updatedAtLocal: Value(now),
          ),
        );
      }
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
              requestJson: jsonEncode(request),
              baselineUpdatedUtc: seriesMutation
                  ? const Value(null)
                  : Value(existing.updatedAtServer),
              baselineRawJson: seriesMutation
                  ? const Value(null)
                  : Value(existing.baselineRawJson),
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

  Future<String> _createLocalDavEvent(
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
    late final String operationId;
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
      operationId =
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
    return operationId;
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
    if (recurring && recurringScope == null) {
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
    } else if (recurringScope == RecurringEventMutationScope.thisAndFuture ||
        (recurringScope == RecurringEventMutationScope.singleOccurrence &&
            existing.recurrenceIdKey == null)) {
      final occurrenceKey = existing.occurrenceKey;
      if (occurrenceKey == null || objectId == null) {
        throw UnsupportedError(
          'Occurrence editing requires a synchronized occurrence.',
        );
      }
      patch = buildDavEventOccurrenceExceptionPatch(
        uid: uid,
        occurrenceKey: occurrenceKey,
        baselineRawIcs: baselineRawIcs,
        input: input,
        thisAndFuture:
            recurringScope == RecurringEventMutationScope.thisAndFuture,
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
    if (recurring && recurringScope == null) {
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
        if (recurringScope == RecurringEventMutationScope.singleOccurrence ||
            recurringScope == RecurringEventMutationScope.thisAndFuture) {
          throw UnsupportedError(
            'Occurrence deletion requires a synchronized occurrence.',
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
      if (recurringScope == RecurringEventMutationScope.singleOccurrence ||
          recurringScope == RecurringEventMutationScope.thisAndFuture) {
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
          thisAndFuture:
              recurringScope == RecurringEventMutationScope.thisAndFuture,
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

  Future<PendingOp?> _pendingCalendarCreate(String sourceId) {
    return (_database.select(_database.pendingOps)
          ..where(
            (row) =>
                row.calendarSourceId.equals(sourceId) &
                row.operationType.equals('calendar.create') &
                row.state.equals('pending'),
          )
          ..limit(1))
        .getSingleOrNull();
  }

  Future<List<PendingOp>> _pendingCalendarWork(String sourceId) {
    return (_database.select(_database.pendingOps)..where(
          (row) =>
              row.calendarSourceId.equals(sourceId) &
              row.state.equals('pending'),
        ))
        .get();
  }

  Future<bool> _hasActiveCalendarRemoval(String sourceId) async {
    final operations =
        await (_database.select(_database.pendingOps)..where(
              (row) =>
                  row.calendarSourceId.equals(sourceId) &
                  (row.operationType.equals('calendar.delete') |
                      row.operationType.equals('calendar.remove')) &
                  row.state.equals('pending'),
            ))
            .get();
    return operations.any(
      (operation) =>
          operation.nextAttemptAtUtc?.startsWith('9999-12-31') != true,
    );
  }

  Future<void> _enqueueOrMergeCalendarPatch(
    CalendarSource source, {
    required Map<String, Object?> request,
    required String nowUtc,
    String? dependsOnOpId,
  }) async {
    final queuedRequest = _calendarPatchRequestWithPreviousValues(
      source,
      request,
    );
    final requestedScope =
        queuedRequest[calendarMutationScopeKey]?.toString() ??
        calendarMutationScopeGlobal;
    final candidates =
        await (_database.select(_database.pendingOps)
              ..where(
                (row) =>
                    row.calendarSourceId.equals(source.id) &
                    row.operationType.equals('calendar.patch') &
                    row.state.equals('pending') &
                    row.attemptCount.equals(0),
              )
              ..orderBy([(row) => OrderingTerm.asc(row.createdAtUtc)]))
            .get();
    PendingOp? existing;
    for (final candidate in candidates) {
      final candidateScope =
          _calendarPendingRequest(
            candidate,
          )[calendarMutationScopeKey]?.toString() ??
          calendarMutationScopeGlobal;
      if (candidateScope == requestedScope) {
        existing = candidate;
        break;
      }
    }
    if (existing != null) {
      final existingOp = existing;
      final existingRequest = _calendarPendingRequest(existingOp);
      final existingPrevious = _jsonObjectMap(
        existingRequest[calendarPatchPreviousValuesKey],
      );
      final queuedPrevious = _jsonObjectMap(
        queuedRequest[calendarPatchPreviousValuesKey],
      );
      final merged = existingRequest..addAll(queuedRequest);
      merged[calendarPatchPreviousValuesKey] = {
        ...queuedPrevious,
        ...existingPrevious,
      };
      await (_database.update(
        _database.pendingOps,
      )..where((row) => row.id.equals(existingOp.id))).write(
        PendingOpsCompanion(
          requestJson: Value(jsonEncode(merged)),
          dependsOnOpId: Value(existingOp.dependsOnOpId ?? dependsOnOpId),
          updatedAtUtc: Value(nowUtc),
        ),
      );
      return;
    }
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
        dependsOnOpId: Value(dependsOnOpId),
        requestJson: jsonEncode(queuedRequest),
        baselineRawJson: Value(source.rawJson),
        createdAtUtc: nowUtc,
        updatedAtUtc: nowUtc,
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

void _requireFullEventEditingAllowed(CalendarEvent event) {
  final provider = BusyProviderCodec.requireStorageValue(event.provider);
  if (provider != BusyProvider.google) return;
  final raw = _jsonMap(event.rawJson);
  final organizer = _jsonMap(event.organizerJson);
  final allowed =
      raw['locked'] != true &&
      (organizer['self'] == true || raw['guestsCanModify'] == true);
  if (allowed) return;
  throw CalendarMutationNotAllowed(
    operation: CalendarMutationOperation.editEvent,
    sourceId: event.calendarSourceId,
  );
}

void _requireAttendeeManagementAllowed(
  CalendarEvent event,
  EventEditorDraft draft,
) {
  if (!draft.attendeesChanged) return;
  final provider = BusyProviderCodec.requireStorageValue(event.provider);
  if (provider != BusyProvider.google) return;
  final raw = _jsonMap(event.rawJson);
  final organizer = _jsonMap(event.organizerJson);
  final allowed =
      organizer['self'] == true || raw['guestsCanInviteOthers'] != false;
  if (allowed) return;
  throw CalendarMutationNotAllowed(
    operation: CalendarMutationOperation.editEvent,
    sourceId: event.calendarSourceId,
  );
}

void _requireCalendarSourceCapability(
  CalendarSource source, {
  required CalendarMutationOperation operation,
  required bool allowed,
}) {
  if (allowed) {
    return;
  }
  throw CalendarMutationNotAllowed(operation: operation, sourceId: source.id);
}

Map<String, Object?> _calendarPendingRequest(PendingOp op) {
  final decoded = jsonDecode(op.requestJson);
  if (decoded is! Map) {
    return <String, Object?>{};
  }
  return decoded.cast<String, Object?>();
}

String _calendarOperationType(PendingOp op) {
  return op.operationType ?? '${op.entityType}.${op.operation}';
}

Map<String, Object?> _calendarPatchRequestWithPreviousValues(
  CalendarSource source,
  Map<String, Object?> request,
) {
  final queued = <String, Object?>{...request};
  final previous = <String, Object?>{};
  if (request.containsKey('summary')) {
    previous['summary'] = source.summary;
  }
  if (request.containsKey('backgroundColor') ||
      request.containsKey('foregroundColor') ||
      request.containsKey('colorId')) {
    previous['backgroundColor'] = source.backgroundColor;
    previous['foregroundColor'] = source.foregroundColor;
    previous['colorId'] = source.colorId;
  }
  if (previous.isNotEmpty) {
    queued[calendarPatchPreviousValuesKey] = previous;
  }
  return queued;
}

bool _calendarRemovalPreviousHidden(PendingOp op) {
  final requestValue = _jsonMap(
    op.requestJson,
  )[calendarRemovalPreviousHiddenKey];
  if (requestValue is bool) return requestValue;
  final baselineValue = _jsonMap(op.baselineRawJson)['hidden'];
  return baselineValue is bool ? baselineValue : false;
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
    remindersChanged: draft.remindersChanged,
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

CalendarEventDetail _eventEditBaseline(
  EventEditorDraft draft,
  CalendarEvent existing,
) {
  final original = draft.originalDetail;
  if (original != null && original.id == existing.id) {
    return original;
  }
  return CalendarEventDetail.fromRow(existing);
}

String? _eventDetailBaselineRawJson(CalendarEventDetail detail) {
  final baseline = detail.baselineRaw ?? detail.raw;
  return baseline == null ? null : jsonEncode(baseline);
}

DateTime? _eventDetailStartDateTime(CalendarEventDetail detail) {
  return providerDateTimeAsWallTime(
    detail.allDay ? detail.startDate : detail.startDateTime,
    detail.startTimeZone,
  );
}

DateTime? _eventDetailEndDateTime(CalendarEventDetail detail) {
  return providerDateTimeAsWallTime(
    detail.allDay ? detail.endDate : detail.endDateTime,
    detail.endTimeZone,
  );
}

CalendarEventsCompanion _eventPatchProjection({
  required EventEditorDraft draft,
  required CalendarEvent existing,
  required BusyProvider provider,
  required Map<String, Object?> request,
  required String? startTimeZone,
  required String? endTimeZone,
  required Object? conference,
  required int now,
}) {
  final rangeChanged = request.containsKey('allDay');
  final rawChanged = switch (provider) {
    BusyProvider.google => request.containsKey('hideAttendees'),
    BusyProvider.microsoft =>
      request.containsKey('importance') ||
          request.containsKey('responseRequested') ||
          request.containsKey('hideAttendees') ||
          request.containsKey('allowNewTimeProposals'),
    BusyProvider.appleICloud || BusyProvider.nextcloud => false,
  };
  return CalendarEventsCompanion(
    title: request.containsKey('title')
        ? Value(draft.title.trim())
        : const Value.absent(),
    description: request.containsKey('description')
        ? Value(draft.description)
        : const Value.absent(),
    location: request.containsKey('location')
        ? Value(draft.location)
        : const Value.absent(),
    allDay: rangeChanged ? Value(draft.allDay) : const Value.absent(),
    startDate: rangeChanged
        ? Value(draft.allDay ? _date(draft.start) : null)
        : const Value.absent(),
    startDateTime: rangeChanged
        ? Value(draft.allDay ? null : draft.start?.toIso8601String())
        : const Value.absent(),
    startTimeZone: rangeChanged ? Value(startTimeZone) : const Value.absent(),
    endDate: rangeChanged
        ? Value(draft.allDay ? _date(draft.end) : null)
        : const Value.absent(),
    endDateTime: rangeChanged
        ? Value(draft.allDay ? null : draft.end?.toIso8601String())
        : const Value.absent(),
    endTimeZone: rangeChanged ? Value(endTimeZone) : const Value.absent(),
    recurrenceJson: request.containsKey(calendarEventRecurrenceField)
        ? Value(_json(draft.recurrence))
        : const Value.absent(),
    remindersJson: request.containsKey('remindersJson')
        ? Value(_json(draft.reminders))
        : const Value.absent(),
    attendeesJson: request.containsKey(calendarEventAttendeesField)
        ? Value(_json(_localAttendeesJson(draft, provider)))
        : const Value.absent(),
    categoriesJson: request.containsKey('categoriesJson')
        ? Value(_json(_categoriesJson(draft, provider)))
        : const Value.absent(),
    colorId: request.containsKey('colorId')
        ? Value(draft.colorId)
        : const Value.absent(),
    visibility:
        request.containsKey('visibility') || request.containsKey('sensitivity')
        ? Value(draft.visibilityOrSensitivity)
        : const Value.absent(),
    transparencyOrShowAs: request.containsKey('transparencyOrShowAs')
        ? Value(draft.showAs)
        : const Value.absent(),
    conferenceJson: request.containsKey('conferenceJson')
        ? Value(_json(conference))
        : const Value.absent(),
    rawJson: rawChanged
        ? Value(
            jsonEncode(
              _optimisticEventRawForPatch(
                draft,
                provider,
                request: request,
                existingJson: existing.rawJson,
              ),
            ),
          )
        : const Value.absent(),
    updatedAtLocal: Value(now),
    syncStatus: const Value('pending'),
  );
}

Map<String, Object?> _eventDeltaRequest(
  EventEditorDraft draft,
  CalendarEventDetail original,
  BusyProvider provider, {
  required String? startTimeZone,
  required String? endTimeZone,
  required Object? conference,
  required CalendarGuestUpdatePolicy guestUpdatePolicy,
}) {
  final full = _eventRequest(
    draft,
    provider,
    isCreate: false,
    startTimeZone: startTimeZone,
    endTimeZone: endTimeZone,
    conference: conference,
    guestUpdatePolicy: guestUpdatePolicy,
  );
  final result = <String, Object?>{
    calendarEventGuestUpdatePolicyKey: guestUpdatePolicy.name,
  };
  void copy(String key) {
    if (full.containsKey(key)) result[key] = full[key];
  }

  if (draft.title.trim() != original.title) copy('title');
  if ((draft.description ?? '') != (original.description ?? '')) {
    result['description'] = draft.description ?? '';
    copy('descriptionContentType');
    copy('descriptionHtml');
  }
  if ((draft.location ?? '') != (original.location ?? '')) {
    result['location'] = draft.location ?? '';
  }
  final rangeChanged =
      draft.allDay != original.allDay ||
      draft.start != _eventDetailStartDateTime(original) ||
      draft.end != _eventDetailEndDateTime(original) ||
      draft.startTimeZone != original.startTimeZone ||
      draft.endTimeZone != original.endTimeZone;
  if (rangeChanged) {
    copy('allDay');
    copy('start');
    copy('end');
    copy('startTimeZone');
    copy('endTimeZone');
  }
  if (draft.recurrenceChanged) copy(calendarEventRecurrenceField);
  if (!_sameJsonValue(original.reminders, draft.reminders)) {
    copy('remindersJson');
  }
  if (draft.attendeesChanged) copy(calendarEventAttendeesField);
  if (draft.colorId != original.colorId) copy('colorId');
  if (draft.categoriesChanged) copy('categoriesJson');
  if (draft.visibilityOrSensitivity != original.visibility) {
    copy(provider == BusyProvider.google ? 'visibility' : 'sensitivity');
  }
  if (draft.showAs != original.transparencyOrShowAs) {
    copy('transparencyOrShowAs');
  }
  final raw = _jsonObjectMap(original.raw);
  if (draft.importance != raw['importance']?.toString()) copy('importance');
  if (conference != null) copy('conferenceJson');
  if (draft.responseRequested != raw['responseRequested']) {
    copy('responseRequested');
  }
  final existingHidden = provider == BusyProvider.google
      ? raw['guestsCanSeeOtherGuests'] is bool
            ? !(raw['guestsCanSeeOtherGuests'] as bool)
            : null
      : raw['hideAttendees'];
  if (draft.hideAttendees != existingHidden) copy('hideAttendees');
  if (draft.allowNewTimeProposals != raw['allowNewTimeProposals']) {
    copy('allowNewTimeProposals');
  }
  final clearFields = <String>{
    for (final value in full[calendarEventClearFieldsKey] as List? ?? const [])
      value.toString(),
  }..removeWhere((field) => !result.containsKey(field));
  if (clearFields.isNotEmpty) {
    result[calendarEventClearFieldsKey] = clearFields.toList();
  }
  return result;
}

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
  return explicit ??
      _nonBlank(startTimeZone) ??
      _nonBlank(localTimeZone) ??
      _nonBlank(sourceTimeZone) ??
      'UTC';
}

String _effectiveTimedEventZone({
  required String? explicitTimeZone,
  required String? sourceTimeZone,
  required String? localTimeZone,
}) {
  final explicit = _nonBlank(explicitTimeZone);
  return explicit ??
      _nonBlank(localTimeZone) ??
      _nonBlank(sourceTimeZone) ??
      'UTC';
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

Map<String, Object?> _optimisticEventRawForPatch(
  EventEditorDraft draft,
  BusyProvider provider, {
  required Map<String, Object?> request,
  String? existingJson,
}) {
  final raw = {..._jsonMap(existingJson)};
  switch (provider) {
    case BusyProvider.google:
      if (request.containsKey('hideAttendees')) {
        final hidden = draft.hideAttendees;
        if (hidden == null) {
          raw.remove('guestsCanSeeOtherGuests');
        } else {
          raw['guestsCanSeeOtherGuests'] = !hidden;
        }
      }
    case BusyProvider.microsoft:
      _setOrRemoveRawField(
        raw,
        request: request,
        key: 'importance',
        value: draft.importance,
      );
      _setOrRemoveRawField(
        raw,
        request: request,
        key: 'responseRequested',
        value: draft.responseRequested,
      );
      _setOrRemoveRawField(
        raw,
        request: request,
        key: 'hideAttendees',
        value: draft.hideAttendees,
      );
      _setOrRemoveRawField(
        raw,
        request: request,
        key: 'allowNewTimeProposals',
        value: draft.allowNewTimeProposals,
      );
    case BusyProvider.appleICloud:
    case BusyProvider.nextcloud:
      break;
  }
  return raw;
}

void _setOrRemoveRawField(
  Map<String, Object?> raw, {
  required Map<String, Object?> request,
  required String key,
  required Object? value,
}) {
  if (!request.containsKey(key)) return;
  if (value == null) {
    raw.remove(key);
  } else {
    raw[key] = value;
  }
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

Map<String, Object?> _jsonObjectMap(Object? value) {
  return value is Map ? Map<String, Object?>.from(value) : const {};
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

String? _storedEventStart(CalendarEvent event) =>
    event.allDay ? event.startDate : event.startDateTime;

String? _storedEventEnd(CalendarEvent event) =>
    event.allDay ? event.endDate : event.endDateTime;

DateTime? _storedEventStartDateTime(CalendarEvent event) =>
    providerDateTimeAsWallTime(_storedEventStart(event), event.startTimeZone);

DateTime? _storedEventEndDateTime(CalendarEvent event) =>
    providerDateTimeAsWallTime(_storedEventEnd(event), event.endTimeZone);

bool _seriesRowInScope(
  CalendarEvent row,
  CalendarEvent target,
  RecurringEventMutationScope scope,
) {
  if (scope == RecurringEventMutationScope.entireSeries) return true;
  if (scope != RecurringEventMutationScope.thisAndFuture) {
    return row.id == target.id;
  }
  final targetStart = _seriesOriginalStart(target);
  final rowStart = _seriesOriginalStart(row);
  if (targetStart == null || rowStart == null) return row.id == target.id;
  return !rowStart.isBefore(targetStart);
}

bool _googleEventCanSplit(CalendarEvent event) {
  final eventType = event.eventType;
  if (eventType != null && eventType.isNotEmpty && eventType != 'default') {
    return false;
  }
  final conference = _decodeStoredJson(event.conferenceJson);
  if (conference == null) return true;
  if (conference is! Map || conference.isEmpty) return conference is Map;
  final solution = conference['conferenceSolution'];
  final key = solution is Map ? solution['key'] : null;
  return key is Map && key['type']?.toString() == 'hangoutsMeet';
}

DateTime? _seriesOriginalStart(CalendarEvent event) {
  return DateTime.tryParse(event.providerOriginalStartKey ?? '') ??
      _storedEventStartDateTime(event);
}

Object? _decodeStoredJson(String? value) {
  if (value == null || value.isEmpty) return null;
  try {
    return jsonDecode(value);
  } on FormatException {
    return null;
  }
}

bool _sameJsonValue(Object? left, Object? right) {
  return jsonEncode(_normalizedJson(left)) ==
      jsonEncode(_normalizedJson(right));
}

bool _eventRequestHasMutation(Map<String, Object?> request) {
  const metadata = {
    calendarEventGuestUpdatePolicyKey,
    calendarEventRecurringScopeKey,
    calendarEventTargetProviderIdKey,
    calendarEventOriginalStartKey,
    calendarEventOriginalEndKey,
    calendarEventDestinationCalendarIdKey,
    calendarEventDestinationSourceIdKey,
  };
  return request.entries.any(
    (entry) =>
        !metadata.contains(entry.key) &&
        (entry.value != null || entry.key == calendarEventClearFieldsKey),
  );
}

Object _eventRemindersForProvider(Object? reminders, BusyProvider provider) {
  final minutes = <int>[];
  if (reminders is Map) {
    final map = reminders.cast<Object?, Object?>();
    final single = map['reminderMinutesBeforeStart'];
    if (single is int && single > 0) minutes.add(single);
    final overrides = map['overrides'];
    if (overrides is List) {
      for (final override in overrides) {
        if (override is! Map) continue;
        final value = override['minutes'];
        if (value is int && value > 0 && !minutes.contains(value)) {
          minutes.add(value);
        }
      }
    }
    final davMinutes = map['minutes'];
    if (davMinutes is List) {
      for (final value in davMinutes.whereType<int>()) {
        if (value > 0 && !minutes.contains(value)) minutes.add(value);
      }
    }
  }
  if (provider == BusyProvider.microsoft) {
    return minutes.isEmpty
        ? const {'isReminderOn': false}
        : {'isReminderOn': true, 'reminderMinutesBeforeStart': minutes.first};
  }
  return {
    'useDefault': false,
    'overrides': [
      for (final value in minutes) {'method': 'popup', 'minutes': value},
    ],
  };
}

String _eventShowAsForProvider(String? value, BusyProvider provider) {
  if (provider == BusyProvider.microsoft) {
    return switch (value) {
      'free' || 'tentative' || 'busy' || 'oof' || 'workingElsewhere' => value!,
      'transparent' => 'free',
      _ => 'busy',
    };
  }
  return switch (value) {
    'opaque' || 'transparent' => value!,
    'free' => 'transparent',
    _ => 'opaque',
  };
}

String _eventVisibilityForProvider(String? value, BusyProvider provider) {
  if (provider == BusyProvider.microsoft) {
    return switch (value) {
      'normal' || 'personal' || 'private' || 'confidential' => value!,
      _ => 'normal',
    };
  }
  return switch (value) {
    'default' || 'public' || 'private' || 'confidential' => value!,
    'personal' => 'private',
    _ => 'default',
  };
}

Object? _normalizedJson(Object? value) {
  if (value is Map) {
    final entries = value.entries.toList()
      ..sort(
        (left, right) => left.key.toString().compareTo(right.key.toString()),
      );
    return {
      for (final entry in entries)
        entry.key.toString(): _normalizedJson(entry.value),
    };
  }
  if (value is List) {
    return [for (final item in value) _normalizedJson(item)];
  }
  return value;
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

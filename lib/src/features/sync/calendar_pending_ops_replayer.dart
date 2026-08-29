import 'dart:convert';
import 'dart:math';

import 'package:drift/drift.dart';

import '../../calendar_providers/calendar_mutation.dart';
import '../../calendar_providers/calendar_description.dart';
import '../../calendar_providers/calendar_sync_dto.dart';
import '../../calendar_providers/cloud_calendar_client.dart';
import '../../core/time/provider_date_time.dart';
import '../../db/app_database.dart';
import '../../google_calendar/google_calendar_errors.dart';
import '../../google_calendar/google_calendar_mapper.dart';
import '../../microsoft_calendar/microsoft_calendar_errors.dart';
import 'package:busymax/src/providers/busy_provider.dart';
import '../calendar/data/calendar_repository.dart';
import '../recurrence/domain/event_recurrence_codec.dart';
import '../recurrence/domain/recurrence_rule.dart';

class CalendarPendingOpsReplayer {
  CalendarPendingOpsReplayer({
    required AppDatabase database,
    required CloudCalendarClient client,
    required String accountId,
    DateTime Function()? nowUtc,
    Future<void> Function(String summary)? onConflictBlocked,
    Random? random,
  }) : _database = database,
       _client = client,
       _accountId = accountId,
       _nowUtc = nowUtc ?? (() => DateTime.now().toUtc()),
       _onConflictBlocked = onConflictBlocked,
       _random = random ?? Random.secure(),
       _repository = CalendarRepository(database: database, now: nowUtc);

  final AppDatabase _database;
  final CloudCalendarClient _client;
  final String _accountId;
  final DateTime Function() _nowUtc;
  final Future<void> Function(String summary)? _onConflictBlocked;
  final Random _random;
  final CalendarRepository _repository;

  Future<int> replayDueOps() async {
    final dueOps = await _database.pendingOpsDao.pendingOpsForReplay(
      _accountId,
      _nowUtc(),
    );
    final ops = [
      ...dueOps,
      ...await _recoverableBlockedOps(dueOps.map((op) => op.id).toSet()),
    ];
    var applied = 0;

    for (final originalOp in ops) {
      final op = await _readOp(originalOp.id);
      if (op == null || !_isCalendarOp(op)) {
        continue;
      }
      if (op.dependsOnOpId != null && await _opExists(op.dependsOnOpId!)) {
        continue;
      }
      if (_copyConfirmationMissing(op)) {
        await _blockOp(
          op,
          'event_copy_not_confirmed',
          'The destination event was not confirmed, so the original was kept.',
        );
        continue;
      }

      try {
        await _replay(op);
        await _database.pendingOpsDao.deleteOp(op.id);
        applied += 1;
      } on GoogleCalendarApiError catch (error) {
        if (_isSuccessfulMissingDelete(op, error.statusCode)) {
          await _applyDeleteSideEffect(op);
          await _database.pendingOpsDao.deleteOp(op.id);
          applied += 1;
        } else if (_isRetryableStatus(error.statusCode)) {
          await _scheduleRetry(op, error.code, error.message);
        } else {
          await _blockOp(op, error.code, error.message);
        }
      } on MicrosoftCalendarApiError catch (error) {
        if (_isSuccessfulMissingDelete(op, error.statusCode)) {
          await _applyDeleteSideEffect(op);
          await _database.pendingOpsDao.deleteOp(op.id);
          applied += 1;
        } else if (_isRetryableStatus(error.statusCode)) {
          await _scheduleRetry(op, error.code, error.message);
        } else {
          await _blockOp(op, error.code, error.message);
        }
      } on _PendingOpBlocked {
        continue;
      } on Object catch (error) {
        await _scheduleRetry(
          op,
          error.runtimeType.toString(),
          error.toString(),
        );
      }
    }

    return applied;
  }

  Future<void> _replay(PendingOp op) async {
    switch (_operationType(op)) {
      case 'event.create':
        await _createEvent(op);
      case 'event.patch':
        await _patchEvent(op);
      case 'event.delete':
        await _deleteEvent(op);
      case 'event.respond':
        await _respondToEvent(op);
      case 'event.move':
        await _moveEvent(op);
      case 'calendar.patch':
        await _patchCalendar(op);
      case 'calendar.delete':
        await _deleteCalendar(op);
      case 'calendar.create':
        await _createCalendar(op);
      default:
        await _blockOp(op, 'unknown_calendar_operation', _operationType(op));
        throw const _PendingOpBlocked();
    }
  }

  Future<List<PendingOp>> _recoverableBlockedOps(Set<String> excludeIds) async {
    final query = _database.select(_database.pendingOps)
      ..where(
        (row) =>
            row.accountId.equals(_accountId) &
            row.nextAttemptAtUtc.isBiggerOrEqualValue('9999-12-31'),
      )
      ..orderBy([(row) => OrderingTerm.asc(row.createdAtUtc)]);
    final rows = await query.get();
    return rows
        .where(
          (op) =>
              !excludeIds.contains(op.id) &&
              (_wasBlockedByTaskReplay(op) ||
                  _isMissingTimeZoneCreateFailure(op)),
        )
        .toList();
  }

  bool _wasBlockedByTaskReplay(PendingOp op) {
    return _isCalendarOp(op) && op.lastErrorCode == 'unknown_operation';
  }

  bool _isMissingTimeZoneCreateFailure(PendingOp op) {
    return op.provider == BusyProvider.google.storageValue &&
        op.entityType == 'event' &&
        op.operationType == 'event.create' &&
        op.lastErrorCode == 'GoogleCalendarApiError' &&
        (op.lastErrorMessage?.startsWith('Missing time zone definition') ??
            false);
  }

  Future<void> _patchCalendar(PendingOp op) async {
    final providerCalendarId = _require(op.providerCalendarId, 'calendarId');
    final source = await _client.updateCalendar(
      providerCalendarId,
      _calendarMutation(_request(op)),
    );
    await _repository.upsertSource(accountId: _accountId, source: source);
  }

  Future<void> _createCalendar(PendingOp op) async {
    if (!_client.capabilities.supportsCreateCalendar) {
      await _blockOp(op, 'unsupported_calendar_operation', _operationType(op));
      throw const _PendingOpBlocked();
    }
    final source = await _client.createCalendar(
      _calendarMutation(_request(op)),
    );
    await _replaceLocalCalendar(op, source);
  }

  Future<void> _deleteCalendar(PendingOp op) async {
    final providerCalendarId = _require(op.providerCalendarId, 'calendarId');
    await _client.deleteCalendar(providerCalendarId);
    await _applyDeleteSideEffect(op);
  }

  Future<void> _createEvent(PendingOp op) async {
    final providerCalendarId = _require(op.providerCalendarId, 'calendarId');
    final request = _request(op);
    final event = await _client.createEvent(
      calendarId: providerCalendarId,
      mutation: _eventMutation(
        request,
        fallbackTimeZone: await _fallbackTimeZone(op),
      ),
      guestUpdatePolicy: _guestUpdatePolicy(request),
    );
    await _replaceLocalEvent(op, event);
  }

  Future<void> _patchEvent(PendingOp op) async {
    final providerCalendarId = _require(op.providerCalendarId, 'calendarId');
    final local = await _localEvent(op);
    final request = _request(op);
    final recurringScope = request[calendarEventRecurringScopeKey]?.toString();
    if (recurringScope == 'thisAndFuture') {
      await _patchGoogleFollowingEvents(op, local: local, request: request);
      return;
    }
    final providerEventId = await _providerEventId(op, local);
    await _ensureNoEventConflict(op, local, request);
    var mutationRequest = request;
    if (recurringScope == 'entireSeries') {
      final resolved = request[_seriesResolvedRequestKey];
      if (resolved is Map) {
        mutationRequest = resolved.cast<String, Object?>();
      } else {
        final master = await _client.getEvent(
          calendarId: providerCalendarId,
          eventId: providerEventId,
        );
        mutationRequest = _seriesRequestForMaster(
          request,
          master,
          provider: _client.provider,
        );
        request[_seriesResolvedRequestKey] = mutationRequest;
        await (_database.update(
          _database.pendingOps,
        )..where((row) => row.id.equals(op.id))).write(
          PendingOpsCompanion(
            requestJson: Value(jsonEncode(request)),
            updatedAtUtc: Value(_nowUtc().toIso8601String()),
          ),
        );
      }
    }
    final event = await _client.updateEvent(
      calendarId: providerCalendarId,
      eventId: providerEventId,
      mutation: _eventMutation(
        mutationRequest,
        fallbackTimeZone: await _fallbackTimeZone(op, local: local),
      ),
      guestUpdatePolicy: _guestUpdatePolicy(request),
    );
    if (recurringScope == 'entireSeries') {
      await _repository.upsertEvent(accountId: _accountId, event: event);
      await _markRecurringRowsSynced(local);
      return;
    }
    await _database.transaction(() async {
      final hasDependent = await _rebaseDependentEventEdits(op, event);
      if (hasDependent) {
        return;
      }
      await _repository.upsertEvent(accountId: _accountId, event: event);
    });
  }

  Future<bool> _rebaseDependentEventEdits(
    PendingOp completedOp,
    CalendarEventDto serverEvent,
  ) async {
    final dependents =
        await (_database.select(_database.pendingOps)..where(
              (row) =>
                  row.accountId.equals(_accountId) &
                  row.dependsOnOpId.equals(completedOp.id),
            ))
            .get();
    if (dependents.isEmpty) {
      return false;
    }

    final acknowledgedFields = _eventMutationFields(_request(completedOp));
    final serverSnapshot = _semanticSnapshot(
      _client.provider,
      serverEvent.rawJson,
    );
    for (final dependent in dependents) {
      final baseline = _eventBaselineSnapshot(
        _client.provider,
        dependent.baselineRawJson ?? '{}',
      );
      // Keep the original timestamp and untouched fields so a provider edit to
      // a different field is still detected by the dependent operation.
      for (final field in acknowledgedFields) {
        baseline[field] = serverSnapshot[field];
      }
      await (_database.update(
        _database.pendingOps,
      )..where((row) => row.id.equals(dependent.id))).write(
        PendingOpsCompanion(
          baselineRawJson: Value(
            jsonEncode({_eventSemanticBaselineKey: baseline}),
          ),
          updatedAtUtc: Value(_nowUtc().toIso8601String()),
        ),
      );
    }
    return true;
  }

  Future<void> _deleteEvent(PendingOp op) async {
    final providerCalendarId = _require(op.providerCalendarId, 'calendarId');
    final local = await _localEvent(op);
    final request = _request(op);
    if (request[calendarEventRecurringScopeKey]?.toString() ==
        'thisAndFuture') {
      await _deleteGoogleFollowingEvents(op, local: local, request: request);
      await _applyDeleteSideEffect(op);
      return;
    }
    final providerEventId = await _providerEventId(op, local);
    await _ensureEventUnchanged(op, local, 'delete');
    await _client.deleteEvent(
      calendarId: providerCalendarId,
      eventId: providerEventId,
      guestUpdatePolicy: _guestUpdatePolicy(request),
    );
    await _applyDeleteSideEffect(op);
  }

  Future<void> _moveEvent(PendingOp op) async {
    if (_client.provider != BusyProvider.google) {
      await _blockOp(
        op,
        'unsupported_calendar_operation',
        'Native event movement is only available for Google Calendar.',
      );
      throw const _PendingOpBlocked();
    }
    final sourceCalendarId = _require(
      op.providerCalendarId,
      'sourceCalendarId',
    );
    final request = _request(op);
    final destinationCalendarId = _require(
      request[calendarEventDestinationCalendarIdKey]?.toString(),
      'destinationCalendarId',
    );
    final local = await _localEvent(op);
    final providerEventId = await _providerEventId(op, local);
    await _ensureEventUnchanged(op, local, 'move');
    final event = await _client.moveEvent(
      sourceCalendarId: sourceCalendarId,
      eventId: providerEventId,
      destinationCalendarId: destinationCalendarId,
      guestUpdatePolicy: _guestUpdatePolicy(request),
    );
    await _replaceLocalEvent(op, event);
  }

  Future<void> _respondToEvent(PendingOp op) async {
    final providerCalendarId = _require(op.providerCalendarId, 'calendarId');
    final local = await _localEvent(op);
    final providerEventId = await _providerEventId(op, local);
    final request = _request(op);
    final response = _invitationResponse(request['response']);
    final event = await _client.respondToEvent(
      calendarId: providerCalendarId,
      eventId: providerEventId,
      response: response,
      attendeeEmail: request['attendeeEmail']?.toString(),
      sendResponse: request['sendResponse'] != false,
    );
    if (event != null) {
      await _repository.upsertEvent(accountId: _accountId, event: event);
      return;
    }
    final otherPending =
        await (_database.select(_database.pendingOps)..where(
              (row) =>
                  row.accountId.equals(_accountId) &
                  row.eventId.equals(local.id) &
                  row.id.equals(op.id).not(),
            ))
            .get();
    if (otherPending.isEmpty) {
      await (_database.update(
        _database.calendarEvents,
      )..where((row) => row.id.equals(local.id))).write(
        CalendarEventsCompanion(
          syncStatus: const Value('synced'),
          updatedAtLocal: Value(_nowUtc().millisecondsSinceEpoch),
        ),
      );
    }
  }

  Future<void> _patchGoogleFollowingEvents(
    PendingOp op, {
    required CalendarEvent local,
    required Map<String, Object?> request,
  }) async {
    if (_client.provider != BusyProvider.google) {
      await _blockOp(
        op,
        'unsupported_recurring_scope',
        'This-and-following edits are not supported by this provider API.',
      );
      throw const _PendingOpBlocked();
    }
    final calendarId = _require(op.providerCalendarId, 'calendarId');
    final masterId = _require(
      request[calendarEventTargetProviderIdKey]?.toString(),
      'recurringEventId',
    );
    final currentMaster = await _client.getEvent(
      calendarId: calendarId,
      eventId: masterId,
    );
    final snapshotValue = request[_googleSplitMasterRawKey];
    late final CalendarEventDto originalMaster;
    if (snapshotValue is Map) {
      originalMaster = googleCalendarEventFromJson(
        calendarId,
        snapshotValue.cast<String, Object?>(),
      );
    } else {
      originalMaster = currentMaster;
      request[_googleSplitMasterRawKey] = originalMaster.rawJson;
      await (_database.update(
        _database.pendingOps,
      )..where((row) => row.id.equals(op.id))).write(
        PendingOpsCompanion(
          requestJson: Value(jsonEncode(request)),
          updatedAtUtc: Value(_nowUtc().toIso8601String()),
        ),
      );
    }
    final targetStart = _requiredDateTime(
      request[calendarEventOriginalStartKey],
      calendarEventOriginalStartKey,
    );
    final masterStart = _dtoStart(originalMaster);
    if (masterStart == null) {
      throw StateError('The recurring master start is unavailable.');
    }
    if (_sameOccurrenceStart(
      masterStart,
      targetStart,
      allDay: originalMaster.allDay,
    )) {
      final mutationRequest = _seriesRequestForMaster(
        request,
        originalMaster,
        provider: _client.provider,
      );
      await _client.updateEvent(
        calendarId: calendarId,
        eventId: masterId,
        mutation: _eventMutation(
          mutationRequest,
          fallbackTimeZone: await _fallbackTimeZone(op, local: local),
        ),
        guestUpdatePolicy: _guestUpdatePolicy(request),
      );
      await _markRecurringRowsSynced(local);
      return;
    }

    final rule = EventRecurrenceCodec.decode(
      BusyProvider.google,
      originalMaster.recurrenceJson,
      baseDate: masterStart,
    );
    if (!rule.isSupported || !rule.repeats) {
      await _blockOp(
        op,
        'unsupported_recurrence_rule',
        'The Google recurrence rule cannot be split without data loss.',
      );
      throw const _PendingOpBlocked();
    }
    final trimmedRule = _trimRuleBefore(
      rule,
      targetStart,
      allDay: originalMaster.allDay,
    );
    final trimmedRecurrence = EventRecurrenceCodec.encode(
      BusyProvider.google,
      trimmedRule,
      baseDate: masterStart,
      allDay: originalMaster.allDay,
      timeZone: originalMaster.startTimeZone,
      original: originalMaster.recurrenceJson,
    );
    final followingRule = await _followingGoogleRule(
      rule,
      calendarId: calendarId,
      masterId: masterId,
      masterStart: masterStart,
      targetStart: targetStart,
    );

    await _client.updateEvent(
      calendarId: calendarId,
      eventId: masterId,
      mutation: CalendarEventMutation(recurrence: trimmedRecurrence),
      guestUpdatePolicy: _guestUpdatePolicy(request),
    );

    final splitRequest = {
      ..._semanticSnapshot(BusyProvider.google, originalMaster.rawJson),
      for (final entry in request.entries)
        if (!_eventRequestMetadataFields.contains(entry.key))
          entry.key: entry.value,
      'allDay': request.containsKey('allDay')
          ? request['allDay']
          : local.allDay,
      'start': request.containsKey('start')
          ? request['start']
          : _localStart(local),
      'end': request.containsKey('end') ? request['end'] : _localEnd(local),
      'startTimeZone': request.containsKey('startTimeZone')
          ? request['startTimeZone']
          : local.startTimeZone,
      'endTimeZone': request.containsKey('endTimeZone')
          ? request['endTimeZone']
          : local.endTimeZone,
    };
    final splitStart = _requiredDateTime(splitRequest['start'], 'start');
    splitRequest[calendarEventRecurrenceField] = EventRecurrenceCodec.encode(
      BusyProvider.google,
      followingRule,
      baseDate: splitStart,
      allDay: splitRequest['allDay'] == true,
      timeZone: splitRequest['startTimeZone']?.toString(),
      original: originalMaster.recurrenceJson,
    );
    if (_newGoogleMeetRequest(originalMaster.rawJson, op.id)
        case final conference?) {
      splitRequest['conferenceJson'] = conference;
    } else {
      splitRequest.remove('conferenceJson');
    }
    final providerRaw = {...originalMaster.rawJson}..remove('conferenceData');
    final splitEventId = op.id.replaceAll('-', '').toLowerCase();
    try {
      await _client.createEvent(
        calendarId: calendarId,
        mutation: _eventMutation(
          splitRequest,
          fallbackTimeZone: await _fallbackTimeZone(op, local: local),
          providerEventId: splitEventId,
          providerRaw: providerRaw,
        ),
        guestUpdatePolicy: _guestUpdatePolicy(request),
      );
    } on GoogleCalendarApiError catch (error) {
      if (error.statusCode != 409) rethrow;
      await _client.getEvent(calendarId: calendarId, eventId: splitEventId);
    }
    await _markRecurringRowsSynced(local);
  }

  Future<void> _deleteGoogleFollowingEvents(
    PendingOp op, {
    required CalendarEvent local,
    required Map<String, Object?> request,
  }) async {
    if (_client.provider != BusyProvider.google) {
      await _blockOp(
        op,
        'unsupported_recurring_scope',
        'This-and-following deletion is not supported by this provider API.',
      );
      throw const _PendingOpBlocked();
    }
    final calendarId = _require(op.providerCalendarId, 'calendarId');
    final masterId = _require(
      request[calendarEventTargetProviderIdKey]?.toString(),
      'recurringEventId',
    );
    final master = await _client.getEvent(
      calendarId: calendarId,
      eventId: masterId,
    );
    final masterStart = _dtoStart(master);
    if (masterStart == null) {
      throw StateError('The recurring master start is unavailable.');
    }
    final targetStart = _requiredDateTime(
      request[calendarEventOriginalStartKey],
      calendarEventOriginalStartKey,
    );
    if (_sameOccurrenceStart(masterStart, targetStart, allDay: master.allDay)) {
      await _client.deleteEvent(
        calendarId: calendarId,
        eventId: masterId,
        guestUpdatePolicy: _guestUpdatePolicy(request),
      );
      await _markRecurringRowsSynced(local);
      return;
    }
    final rule = EventRecurrenceCodec.decode(
      BusyProvider.google,
      master.recurrenceJson,
      baseDate: masterStart,
    );
    if (!rule.isSupported || !rule.repeats) {
      await _blockOp(
        op,
        'unsupported_recurrence_rule',
        'The Google recurrence rule cannot be trimmed without data loss.',
      );
      throw const _PendingOpBlocked();
    }
    final trimmedRule = _trimRuleBefore(
      rule,
      targetStart,
      allDay: master.allDay,
    );
    await _client.updateEvent(
      calendarId: calendarId,
      eventId: masterId,
      mutation: CalendarEventMutation(
        recurrence: EventRecurrenceCodec.encode(
          BusyProvider.google,
          trimmedRule,
          baseDate: masterStart,
          allDay: master.allDay,
          timeZone: master.startTimeZone,
          original: master.recurrenceJson,
        ),
      ),
      guestUpdatePolicy: _guestUpdatePolicy(request),
    );
    await _markRecurringRowsSynced(local);
  }

  Future<RecurrenceRule> _followingGoogleRule(
    RecurrenceRule rule, {
    required String calendarId,
    required String masterId,
    required DateTime masterStart,
    required DateTime targetStart,
  }) async {
    final count = rule.count;
    if (count == null) return rule;
    final instances = await _client.listEventInstances(
      calendarId: calendarId,
      recurringEventId: masterId,
      rangeStart: masterStart.subtract(const Duration(days: 1)),
      rangeEnd: targetStart.add(const Duration(days: 1)),
    );
    final before = instances.where((instance) {
      final original = DateTime.tryParse(
        instance.providerOriginalStartKey ?? '',
      );
      return original != null && original.isBefore(targetStart);
    }).length;
    final remaining = count - before;
    if (remaining < 1) {
      throw StateError('The target occurrence is outside the recurrence.');
    }
    return rule.copyWith(count: remaining, untilRaw: null);
  }

  Future<void> _markRecurringRowsSynced(CalendarEvent local) async {
    final recurringEventId = local.providerRecurringEventId;
    if (recurringEventId == null) return;
    await (_database.update(_database.calendarEvents)..where(
          (row) =>
              row.accountId.equals(local.accountId) &
              row.provider.equals(local.provider) &
              row.providerCalendarId.equals(local.providerCalendarId) &
              row.providerRecurringEventId.equals(recurringEventId) &
              row.syncStatus.equals('pending'),
        ))
        .write(
          CalendarEventsCompanion(
            syncStatus: const Value('synced'),
            updatedAtLocal: Value(_nowUtc().millisecondsSinceEpoch),
          ),
        );
  }

  Future<void> _replaceLocalEvent(
    PendingOp op,
    CalendarEventDto serverEvent,
  ) async {
    final tempEventId = op.eventId;
    final tempProviderEventId = op.localTempId;
    final serverEventId = CalendarRepository.eventId(
      accountId: _accountId,
      provider: serverEvent.provider,
      providerCalendarId: serverEvent.providerCalendarId,
      providerEventId: serverEvent.providerEventId,
      providerOriginalStartKey: serverEvent.providerOriginalStartKey,
    );

    await _database.transaction(() async {
      await _repository.upsertEvent(accountId: _accountId, event: serverEvent);
      await _removeMovedSeriesSourceRows(op);
      await _confirmDependentCopyDeletes(op, serverEventId);
      if (tempEventId != null && tempEventId != serverEventId) {
        await (_database.delete(
          _database.calendarEvents,
        )..where((row) => row.id.equals(tempEventId))).go();
        await _database.customStatement(
          'UPDATE pending_ops SET event_id = ? WHERE account_id = ? '
          'AND event_id = ?',
          [serverEventId, _accountId, tempEventId],
        );
      }
      if (tempProviderEventId != null &&
          tempProviderEventId != serverEvent.providerEventId) {
        await _database.customStatement(
          'UPDATE pending_ops SET local_temp_id = ? WHERE account_id = ? '
          'AND local_temp_id = ?',
          [serverEvent.providerEventId, _accountId, tempProviderEventId],
        );
      }
    });
  }

  Future<void> _replaceLocalCalendar(
    PendingOp op,
    CalendarSourceDto serverSource,
  ) async {
    final temporarySourceId = op.calendarSourceId;
    final temporaryProviderCalendarId = op.localTempId ?? op.providerCalendarId;
    final localSource = temporarySourceId == null
        ? null
        : await (_database.select(_database.calendarSources)
                ..where((row) => row.id.equals(temporarySourceId)))
              .getSingleOrNull();
    final serverSourceId = CalendarRepository.sourceId(
      accountId: _accountId,
      provider: serverSource.provider,
      providerCalendarId: serverSource.providerCalendarId,
    );

    await _database.transaction(() async {
      await _repository.upsertSource(
        accountId: _accountId,
        source: serverSource,
      );
      if (localSource != null) {
        await (_database.update(
          _database.calendarSources,
        )..where((row) => row.id.equals(serverSourceId))).write(
          CalendarSourcesCompanion(
            selected: Value(localSource.selected),
            remindersEnabled: Value(localSource.remindersEnabled),
            hidden: Value(localSource.hidden),
            backgroundColor: Value(localSource.backgroundColor),
            foregroundColor: Value(localSource.foregroundColor),
            colorId: Value(localSource.colorId),
            createdAtLocal: Value(localSource.createdAtLocal),
            updatedAtLocal: Value(_nowUtc().millisecondsSinceEpoch),
          ),
        );
      }
      if (temporarySourceId != null && temporarySourceId != serverSourceId) {
        await _database.customStatement(
          'UPDATE calendar_events SET calendar_source_id = ?, '
          'provider_calendar_id = ? WHERE account_id = ? '
          'AND calendar_source_id = ?',
          [
            serverSourceId,
            serverSource.providerCalendarId,
            _accountId,
            temporarySourceId,
          ],
        );
        await _database.customStatement(
          'UPDATE pending_ops SET calendar_source_id = ?, '
          'provider_calendar_id = ? WHERE account_id = ? '
          'AND calendar_source_id = ?',
          [
            serverSourceId,
            serverSource.providerCalendarId,
            _accountId,
            temporarySourceId,
          ],
        );
      }
      if (temporaryProviderCalendarId != null &&
          temporaryProviderCalendarId != serverSource.providerCalendarId) {
        await _database.customStatement(
          'UPDATE pending_ops SET provider_calendar_id = ? '
          'WHERE account_id = ? AND provider_calendar_id = ?',
          [
            serverSource.providerCalendarId,
            _accountId,
            temporaryProviderCalendarId,
          ],
        );
        await _database.customStatement(
          'UPDATE pending_ops SET local_temp_id = ? '
          'WHERE account_id = ? AND local_temp_id = ?',
          [
            serverSource.providerCalendarId,
            _accountId,
            temporaryProviderCalendarId,
          ],
        );
      }
      await _rewriteCalendarPendingReferences(
        oldSourceId: temporarySourceId,
        newSourceId: serverSourceId,
        oldProviderCalendarId: temporaryProviderCalendarId,
        newProviderCalendarId: serverSource.providerCalendarId,
      );
      if (temporarySourceId != null && temporarySourceId != serverSourceId) {
        await (_database.delete(
          _database.calendarSources,
        )..where((row) => row.id.equals(temporarySourceId))).go();
      }
    });
  }

  Future<void> _rewriteCalendarPendingReferences({
    required String? oldSourceId,
    required String newSourceId,
    required String? oldProviderCalendarId,
    required String newProviderCalendarId,
  }) async {
    final ops = await (_database.select(
      _database.pendingOps,
    )..where((row) => row.accountId.equals(_accountId))).get();
    for (final pending in ops) {
      Object? rewritten = _request(pending);
      if (oldSourceId != null && oldSourceId != newSourceId) {
        rewritten = _replaceCalendarReference(
          rewritten,
          oldSourceId,
          newSourceId,
        );
      }
      if (oldProviderCalendarId != null &&
          oldProviderCalendarId != newProviderCalendarId) {
        rewritten = _replaceCalendarReference(
          rewritten,
          oldProviderCalendarId,
          newProviderCalendarId,
        );
      }
      final requestJson = jsonEncode(rewritten);
      if (requestJson == pending.requestJson) continue;
      await (_database.update(_database.pendingOps)
            ..where((row) => row.id.equals(pending.id)))
          .write(PendingOpsCompanion(requestJson: Value(requestJson)));
    }
  }

  Future<void> _removeMovedSeriesSourceRows(PendingOp op) async {
    if (_operationType(op) != 'event.move') return;
    final request = _request(op);
    if (request[calendarEventRecurringScopeKey]?.toString() != 'entireSeries') {
      return;
    }
    final recurringEventId = request[calendarEventTargetProviderIdKey]
        ?.toString()
        .trim();
    final sourceCalendarId = op.providerCalendarId;
    if (recurringEventId == null ||
        recurringEventId.isEmpty ||
        sourceCalendarId == null) {
      return;
    }
    await (_database.delete(_database.calendarEvents)..where(
          (row) =>
              row.accountId.equals(_accountId) &
              row.provider.equals(
                op.provider ?? _client.provider.storageValue,
              ) &
              row.providerCalendarId.equals(sourceCalendarId) &
              (row.providerEventId.equals(recurringEventId) |
                  row.providerRecurringEventId.equals(recurringEventId)),
        ))
        .go();
  }

  Future<void> _confirmDependentCopyDeletes(
    PendingOp completedCreate,
    String destinationEventId,
  ) async {
    if (_operationType(completedCreate) != 'event.create') return;
    final dependents = await (_database.select(
      _database.pendingOps,
    )..where((row) => row.dependsOnOpId.equals(completedCreate.id))).get();
    for (final dependent in dependents) {
      final request = _request(dependent);
      if (request[calendarEventCopyConfirmationRequiredKey] != true) continue;
      request[calendarEventCopyConfirmedKey] = true;
      request[calendarEventCopyDestinationEventIdKey] = destinationEventId;
      await (_database.update(_database.pendingOps)
            ..where((row) => row.id.equals(dependent.id)))
          .write(PendingOpsCompanion(requestJson: Value(jsonEncode(request))));
    }
  }

  Future<void> _applyDeleteSideEffect(PendingOp op) async {
    final eventId = op.eventId;
    if (eventId == null) {
      final sourceId = op.calendarSourceId;
      if (_operationType(op) == 'calendar.delete' && sourceId != null) {
        await (_database.update(
          _database.calendarSources,
        )..where((row) => row.id.equals(sourceId))).write(
          CalendarSourcesCompanion(
            isDeleted: const Value(true),
            hidden: const Value(true),
            updatedAtLocal: Value(DateTime.now().millisecondsSinceEpoch),
          ),
        );
      }
      return;
    }
    final request = _request(op);
    final scope = request[calendarEventRecurringScopeKey]?.toString();
    if (scope == 'entireSeries' || scope == 'thisAndFuture') {
      final local = await (_database.select(
        _database.calendarEvents,
      )..where((row) => row.id.equals(eventId))).getSingleOrNull();
      final recurringEventId = local?.providerRecurringEventId;
      if (local != null && recurringEventId != null) {
        await (_database.update(_database.calendarEvents)..where((row) {
              var predicate =
                  row.accountId.equals(local.accountId) &
                  row.provider.equals(local.provider) &
                  row.providerCalendarId.equals(local.providerCalendarId) &
                  (row.providerRecurringEventId.equals(recurringEventId) |
                      (scope == 'entireSeries'
                          ? row.providerEventId.equals(recurringEventId)
                          : const Constant(false)));
              if (scope == 'thisAndFuture') {
                predicate &= row.isDeleted.equals(true);
              }
              return predicate;
            }))
            .write(
              CalendarEventsCompanion(
                isDeleted: const Value(true),
                syncStatus: const Value('synced'),
                updatedAtLocal: Value(DateTime.now().millisecondsSinceEpoch),
              ),
            );
        return;
      }
    }
    await (_database.update(
      _database.calendarEvents,
    )..where((row) => row.id.equals(eventId))).write(
      CalendarEventsCompanion(
        isDeleted: const Value(true),
        syncStatus: const Value('synced'),
        updatedAtLocal: Value(DateTime.now().millisecondsSinceEpoch),
      ),
    );
  }

  Future<void> _ensureNoEventConflict(
    PendingOp op,
    CalendarEvent local,
    Map<String, Object?> request,
  ) async {
    final baselineUpdatedUtc = _parseUtc(op.baselineUpdatedUtc);
    if (baselineUpdatedUtc == null) {
      return;
    }
    final current = await _client.getEvent(
      calendarId: op.providerCalendarId ?? local.providerCalendarId,
      eventId: await _providerEventId(op, local),
    );
    final currentUpdatedUtc = _parseUtc(current.updatedAtServer);
    if (currentUpdatedUtc == null ||
        !currentUpdatedUtc.isAfter(baselineUpdatedUtc)) {
      return;
    }
    final baseline = _eventBaselineSnapshot(
      _client.provider,
      op.baselineRawJson ?? local.baselineRawJson ?? '{}',
    );
    final remote = _semanticSnapshot(_client.provider, current.rawJson);
    final changed = _changedSemanticFields(request, baseline, remote);
    if (changed.isEmpty) {
      return;
    }
    await _blockConflict(
      op,
      'Remote event changed fields: ${changed.toList()..sort()}',
    );
  }

  Future<void> _ensureEventUnchanged(
    PendingOp op,
    CalendarEvent local,
    String action,
  ) async {
    final baselineUpdatedUtc = _parseUtc(op.baselineUpdatedUtc);
    if (baselineUpdatedUtc == null) {
      return;
    }
    final current = await _client.getEvent(
      calendarId: op.providerCalendarId ?? local.providerCalendarId,
      eventId: await _providerEventId(op, local),
    );
    final currentUpdatedUtc = _parseUtc(current.updatedAtServer);
    if (currentUpdatedUtc != null &&
        currentUpdatedUtc.isAfter(baselineUpdatedUtc)) {
      await _blockConflict(
        op,
        'Remote event changed since local $action was queued.',
      );
    }
  }

  Set<String> _changedSemanticFields(
    Map<String, Object?> request,
    Map<String, Object?> baseline,
    Map<String, Object?> remote,
  ) {
    final changed = <String>{};
    for (final key in _eventMutationFields(request)) {
      if (!_deepEquals(baseline[key], remote[key])) {
        changed.add(key);
      }
    }
    return changed;
  }

  Set<String> _eventMutationFields(Map<String, Object?> request) {
    final clearFields = _eventClearFields(request);
    const metadataFields = {
      calendarEventClearFieldsKey,
      calendarEventGuestUpdatePolicyKey,
      calendarEventRecurringScopeKey,
      calendarEventTargetProviderIdKey,
      calendarEventOriginalStartKey,
      calendarEventOriginalEndKey,
      calendarEventDestinationCalendarIdKey,
      calendarEventDestinationSourceIdKey,
      calendarEventCopyConfirmationRequiredKey,
      calendarEventCopyConfirmedKey,
      calendarEventCopyDestinationEventIdKey,
      _googleSplitMasterRawKey,
      _seriesResolvedRequestKey,
    };
    return {
      for (final entry in request.entries)
        if (!metadataFields.contains(entry.key) &&
            (entry.value != null || clearFields.contains(entry.key)))
          entry.key,
    };
  }

  Map<String, Object?> _eventBaselineSnapshot(
    BusyProvider provider,
    String encodedBaseline,
  ) {
    final raw = _jsonObject(encodedBaseline);
    final semantic = raw[_eventSemanticBaselineKey];
    if (semantic is Map) {
      return semantic.cast<String, Object?>();
    }
    return _semanticSnapshot(provider, raw);
  }

  Map<String, Object?> _semanticSnapshot(
    BusyProvider provider,
    Map<String, Object?> raw,
  ) {
    if (provider == BusyProvider.google) {
      final start = _mapValue(raw['start']);
      final end = _mapValue(raw['end']);
      return {
        'title': raw['summary'],
        'description': raw['description'],
        'location': raw['location'],
        'allDay': start['date'] != null,
        'start': start['dateTime'] ?? start['date'],
        'end': end['dateTime'] ?? end['date'],
        'startTimeZone': start['timeZone'],
        'endTimeZone': end['timeZone'],
        'recurrenceJson': raw['recurrence'],
        'remindersJson': raw['reminders'],
        'attendeesJson': raw['attendees'],
        'colorId': raw['colorId'],
        'visibility': raw['visibility'],
        'transparencyOrShowAs': raw['transparency'],
        'conferenceJson': raw['conferenceData'],
        'hideAttendees': raw['guestsCanSeeOtherGuests'] == false,
      };
    }

    final start = _mapValue(raw['start']);
    final end = _mapValue(raw['end']);
    final location = _mapValue(raw['location']);
    final body = _mapValue(raw['body']);
    final bodyContent = body['content']?.toString();
    final bodyContentType = body['contentType']?.toString();
    return {
      'title': raw['subject'],
      'description': calendarDescriptionDocumentFromBody(
        content: bodyContent,
        contentType: bodyContentType,
      ).text,
      'descriptionContentType': bodyContentType,
      if (isHtmlContentType(bodyContentType)) 'descriptionHtml': bodyContent,
      'location': location['displayName'],
      'allDay': raw['isAllDay'],
      'start': start['dateTime'],
      'end': end['dateTime'],
      'startTimeZone': start['timeZone'],
      'endTimeZone': end['timeZone'],
      'recurrenceJson': raw['recurrence'],
      'remindersJson': {
        'isReminderOn': raw['isReminderOn'],
        'reminderMinutesBeforeStart': raw['reminderMinutesBeforeStart'],
      },
      'attendeesJson': raw['attendees'],
      'categoriesJson': raw['categories'],
      'importance': raw['importance'],
      'sensitivity': raw['sensitivity'],
      'transparencyOrShowAs': raw['showAs'],
      'conferenceJson': raw['onlineMeeting'],
      'responseRequested': raw['responseRequested'],
      'hideAttendees': raw['hideAttendees'],
      'allowNewTimeProposals': raw['allowNewTimeProposals'],
    };
  }

  CalendarEventMutation _eventMutation(
    Map<String, Object?> request, {
    String? fallbackTimeZone,
    String? providerEventId,
    Map<String, Object?>? providerRaw,
  }) {
    final clearFields = _eventClearFields(request);
    final allDay = request['allDay'] == true;
    final start = request['start']?.toString();
    final end = request['end']?.toString();
    final hasStartMutation = request.containsKey('start');
    final hasEndMutation = request.containsKey('end');
    final startTimeZone = allDay || !hasStartMutation
        ? null
        : _nonBlank(request['startTimeZone']?.toString()) ??
              _nonBlank(fallbackTimeZone) ??
              'UTC';
    final endTimeZone = allDay || !hasEndMutation
        ? null
        : _nonBlank(request['endTimeZone']?.toString()) ??
              startTimeZone ??
              _nonBlank(fallbackTimeZone) ??
              'UTC';
    return CalendarEventMutation(
      title: request['title']?.toString(),
      description: request['description']?.toString(),
      descriptionContentType: request['descriptionContentType']?.toString(),
      descriptionHtml: request['descriptionHtml']?.toString(),
      location: request['location']?.toString(),
      allDay: request['allDay'] as bool?,
      startDate: allDay ? _dateFromIso(start) : null,
      startDateTime: allDay ? null : start,
      startTimeZone: startTimeZone,
      endDate: allDay ? _dateFromIso(end) : null,
      endDateTime: allDay ? null : end,
      endTimeZone: endTimeZone,
      recurrence: request['recurrenceJson'],
      clearRecurrence: clearFields.contains(calendarEventRecurrenceField),
      reminders: request['remindersJson'],
      attendees: request['attendeesJson'],
      clearAttendees: clearFields.contains(calendarEventAttendeesField),
      colorId: request['colorId']?.toString(),
      visibility:
          request['visibility']?.toString() ??
          request['sensitivity']?.toString(),
      transparencyOrShowAs: request['transparencyOrShowAs']?.toString(),
      conference: request['conferenceJson'],
      categories: _stringList(request['categoriesJson']),
      importance: request['importance']?.toString(),
      sensitivity: request['sensitivity']?.toString(),
      responseRequested: request['responseRequested'] as bool?,
      hideAttendees: request['hideAttendees'] as bool?,
      allowNewTimeProposals: request['allowNewTimeProposals'] as bool?,
      providerEventId: providerEventId,
      providerRaw: providerRaw,
    );
  }

  Set<String> _eventClearFields(Map<String, Object?> request) {
    final value = request[calendarEventClearFieldsKey];
    if (value is! List) {
      return const {};
    }
    return {for (final field in value) field.toString()};
  }

  CalendarGuestUpdatePolicy _guestUpdatePolicy(Map<String, Object?> request) {
    return switch (request[calendarEventGuestUpdatePolicyKey]?.toString()) {
      'doNotSend' => CalendarGuestUpdatePolicy.doNotSend,
      _ => CalendarGuestUpdatePolicy.send,
    };
  }

  CalendarInvitationResponse _invitationResponse(Object? value) {
    return switch (value?.toString()) {
      'accept' => CalendarInvitationResponse.accept,
      'tentative' => CalendarInvitationResponse.tentative,
      'decline' => CalendarInvitationResponse.decline,
      _ => throw StateError('Invalid pending invitation response.'),
    };
  }

  Future<String?> _fallbackTimeZone(
    PendingOp op, {
    CalendarEvent? local,
  }) async {
    final sourceId = op.calendarSourceId;
    if (sourceId != null) {
      final source = await (_database.select(
        _database.calendarSources,
      )..where((row) => row.id.equals(sourceId))).getSingleOrNull();
      final sourceTimeZone = _nonBlank(source?.timeZone);
      if (sourceTimeZone != null) {
        return sourceTimeZone;
      }
    }
    final event =
        local ??
        (op.eventId == null
            ? null
            : await (_database.select(
                _database.calendarEvents,
              )..where((row) => row.id.equals(op.eventId!))).getSingleOrNull());
    return _nonBlank(event?.startTimeZone) ?? _nonBlank(event?.endTimeZone);
  }

  CalendarMutation _calendarMutation(Map<String, Object?> request) {
    return CalendarMutation(
      summary: request['summary']?.toString(),
      description: request['description']?.toString(),
      timeZone: request['timeZone']?.toString(),
      backgroundColor: request['backgroundColor']?.toString(),
      foregroundColor: request['foregroundColor']?.toString(),
      colorId: request['colorId']?.toString(),
    );
  }

  Future<CalendarEvent> _localEvent(PendingOp op) async {
    final eventId = _require(op.eventId, 'eventId');
    final local = await (_database.select(
      _database.calendarEvents,
    )..where((row) => row.id.equals(eventId))).getSingleOrNull();
    if (local == null) {
      await _blockOp(op, 'missing_local_event', eventId);
      throw const _PendingOpBlocked();
    }
    return local;
  }

  Future<String> _providerEventId(PendingOp op, CalendarEvent local) async {
    final target = _request(
      op,
    )[calendarEventTargetProviderIdKey]?.toString().trim();
    if (target != null && target.isNotEmpty) return target;
    if (local.providerEventId.startsWith('local:')) {
      await _blockOp(
        op,
        'event_not_created',
        'Local event has not been created remotely yet.',
      );
      throw const _PendingOpBlocked();
    }
    return local.providerEventId;
  }

  bool _isCalendarOp(PendingOp op) {
    final type = op.operationType;
    return op.entityType == 'event' ||
        op.entityType == 'calendar' ||
        (type != null &&
            (type.startsWith('event.') || type.startsWith('calendar.')));
  }

  String _operationType(PendingOp op) {
    final type = op.operationType;
    if (type != null && type.isNotEmpty) {
      return type;
    }
    if (op.entityType == 'event' || op.entityType == 'calendar') {
      return '${op.entityType}.${op.operation}';
    }
    return op.operation;
  }

  bool _isSuccessfulMissingDelete(PendingOp op, int statusCode) {
    return statusCode == 404 &&
        (_operationType(op) == 'event.delete' ||
            _operationType(op) == 'calendar.delete');
  }

  bool _isRetryableStatus(int statusCode) {
    return statusCode == 429 || statusCode >= 500;
  }

  Future<void> _scheduleRetry(
    PendingOp op,
    String errorCode,
    String errorMessage,
  ) {
    final nextAttempt = _nextAttempt(op.attemptCount);
    return _database.pendingOpsDao.updateAttempt(
      id: op.id,
      attemptCount: op.attemptCount + 1,
      nextAttemptAtUtc: nextAttempt,
      lastErrorCode: errorCode,
      lastErrorMessage: errorMessage,
    );
  }

  Future<void> _blockOp(PendingOp op, String errorCode, String errorMessage) {
    return _database.pendingOpsDao.updateAttempt(
      id: op.id,
      attemptCount: op.attemptCount + 1,
      nextAttemptAtUtc: DateTime.utc(9999, 12, 31),
      lastErrorCode: errorCode,
      lastErrorMessage: errorMessage,
    );
  }

  Future<void> _blockConflict(PendingOp op, String message) async {
    await _blockOp(op, 'conflict', message);
    await _onConflictBlocked?.call(message);
    throw const _PendingOpBlocked();
  }

  DateTime _nextAttempt(int attemptCount) {
    final baseSeconds = min(pow(2, attemptCount).toInt(), 300);
    final jitterMs = _random.nextInt(max(baseSeconds * 500, 1));
    return _nowUtc().add(
      Duration(seconds: baseSeconds, milliseconds: jitterMs),
    );
  }

  Future<bool> _opExists(String id) async {
    return _readOp(id).then((op) => op != null);
  }

  bool _copyConfirmationMissing(PendingOp op) {
    final request = _request(op);
    return request[calendarEventCopyConfirmationRequiredKey] == true &&
        request[calendarEventCopyConfirmedKey] != true;
  }

  Future<PendingOp?> _readOp(String id) async {
    return (_database.select(
      _database.pendingOps,
    )..where((row) => row.id.equals(id))).getSingleOrNull();
  }

  Map<String, Object?> _request(PendingOp op) {
    return (jsonDecode(op.requestJson) as Map).cast<String, Object?>();
  }

  Map<String, Object?> _jsonObject(String rawJson) {
    return (jsonDecode(rawJson) as Map).cast<String, Object?>();
  }

  DateTime? _parseUtc(String? value) {
    if (value == null || value.isEmpty) {
      return null;
    }
    return DateTime.tryParse(value)?.toUtc();
  }

  String _require(String? value, String name) {
    if (value == null || value.isEmpty) {
      throw StateError('Missing $name for calendar pending operation.');
    }
    return value;
  }
}

Object? _replaceCalendarReference(
  Object? value,
  String oldValue,
  String newValue,
) {
  if (value is String) {
    return value == oldValue ? newValue : value;
  }
  if (value is List) {
    return [
      for (final item in value)
        _replaceCalendarReference(item, oldValue, newValue),
    ];
  }
  if (value is Map) {
    return {
      for (final entry in value.entries)
        entry.key.toString(): _replaceCalendarReference(
          entry.value,
          oldValue,
          newValue,
        ),
    };
  }
  return value;
}

class _PendingOpBlocked {
  const _PendingOpBlocked();
}

const _googleSplitMasterRawKey = '_googleSplitMasterRaw';
const _seriesResolvedRequestKey = '_seriesResolvedRequest';

const _eventRequestMetadataFields = {
  calendarEventClearFieldsKey,
  calendarEventGuestUpdatePolicyKey,
  calendarEventRecurringScopeKey,
  calendarEventTargetProviderIdKey,
  calendarEventOriginalStartKey,
  calendarEventOriginalEndKey,
  _googleSplitMasterRawKey,
  _seriesResolvedRequestKey,
};

Map<String, Object?> _seriesRequestForMaster(
  Map<String, Object?> request,
  CalendarEventDto master, {
  required BusyProvider provider,
}) {
  final result = {...request};
  if (request.containsKey('start')) {
    final timeZone = request['startTimeZone']?.toString();
    final masterStart = providerDateTimeAsWallTime(
      master.allDay ? master.startDate : master.startDateTime,
      master.startTimeZone,
    );
    final originalStart = providerDateTimeAsWallTime(
      request[calendarEventOriginalStartKey]?.toString(),
      timeZone,
    );
    final desiredStart = DateTime.tryParse(request['start']?.toString() ?? '');
    if (masterStart == null || originalStart == null || desiredStart == null) {
      throw StateError('The recurring series start could not be adjusted.');
    }
    result['start'] = _naiveWallTime(masterStart)
        .add(
          _naiveWallTime(
            desiredStart,
          ).difference(_naiveWallTime(originalStart)),
        )
        .toIso8601String();
  }
  if (request.containsKey('end')) {
    final timeZone = request['endTimeZone']?.toString();
    final masterEnd = providerDateTimeAsWallTime(
      master.allDay ? master.endDate : master.endDateTime,
      master.endTimeZone,
    );
    final originalEnd = providerDateTimeAsWallTime(
      request[calendarEventOriginalEndKey]?.toString(),
      timeZone,
    );
    final desiredEnd = DateTime.tryParse(request['end']?.toString() ?? '');
    if (masterEnd == null || originalEnd == null || desiredEnd == null) {
      throw StateError('The recurring series end could not be adjusted.');
    }
    result['end'] = _naiveWallTime(masterEnd)
        .add(_naiveWallTime(desiredEnd).difference(_naiveWallTime(originalEnd)))
        .toIso8601String();
  }
  if (request.containsKey('start') && master.recurrenceJson != null) {
    final adjustedStart = DateTime.tryParse(result['start']?.toString() ?? '');
    if (adjustedStart == null) {
      throw StateError('The recurring series start could not be adjusted.');
    }
    result[calendarEventRecurrenceField] = _reanchorSeriesRecurrence(
      provider,
      master.recurrenceJson!,
      originalStart: providerDateTimeAsWallTime(
        master.allDay ? master.startDate : master.startDateTime,
        master.startTimeZone,
      ),
      adjustedStart: adjustedStart,
      allDay: request['allDay'] as bool? ?? master.allDay,
      originalTimeZone: master.startTimeZone,
      adjustedTimeZone:
          request['startTimeZone']?.toString() ?? master.startTimeZone,
    );
  }
  return result;
}

Object _reanchorSeriesRecurrence(
  BusyProvider provider,
  Object original, {
  required DateTime? originalStart,
  required DateTime adjustedStart,
  required bool allDay,
  required String? originalTimeZone,
  required String? adjustedTimeZone,
}) {
  final rule = EventRecurrenceCodec.decode(
    provider,
    original,
    baseDate: originalStart,
  );
  if (rule.isSupported && rule.repeats) {
    final untilDate = rule.untilDateFor(timeZone: originalTimeZone);
    final adjustedRule = untilDate == null
        ? rule
        : rule.withUntilDate(
            untilDate,
            allDay: allDay,
            baseDate: adjustedStart,
            timeZone: adjustedTimeZone,
          );
    return EventRecurrenceCodec.encode(
      provider,
      adjustedRule,
      baseDate: adjustedStart,
      allDay: allDay,
      timeZone: adjustedTimeZone,
      original: original,
    )!;
  }
  if (provider == BusyProvider.microsoft && original is Map) {
    final recurrence = Map<String, Object?>.from(original);
    final originalRange = recurrence['range'];
    if (originalRange is Map) {
      recurrence['range'] = {
        ...Map<String, Object?>.from(originalRange),
        'startDate': _isoDate(adjustedStart),
      };
    }
    return recurrence;
  }
  return original;
}

String _isoDate(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-'
    '${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')}';

DateTime _naiveWallTime(DateTime value) => DateTime(
  value.year,
  value.month,
  value.day,
  value.hour,
  value.minute,
  value.second,
  value.millisecond,
  value.microsecond,
);

DateTime _requiredDateTime(Object? value, String field) {
  final parsed = DateTime.tryParse(value?.toString() ?? '');
  if (parsed == null) throw StateError('Missing or invalid $field.');
  return parsed;
}

DateTime? _dtoStart(CalendarEventDto event) => DateTime.tryParse(
  event.allDay ? event.startDate ?? '' : event.startDateTime ?? '',
);

bool _sameOccurrenceStart(
  DateTime left,
  DateTime right, {
  required bool allDay,
}) {
  if (!allDay) return left.toUtc() == right.toUtc();
  return left.year == right.year &&
      left.month == right.month &&
      left.day == right.day;
}

RecurrenceRule _trimRuleBefore(
  RecurrenceRule rule,
  DateTime targetStart, {
  required bool allDay,
}) {
  if (allDay) {
    final previousDate = DateTime(
      targetStart.year,
      targetStart.month,
      targetStart.day - 1,
    );
    return rule.copyWith(count: null, untilRaw: _basicIcalDate(previousDate));
  }
  final until = targetStart.toUtc().subtract(const Duration(seconds: 1));
  return rule.copyWith(count: null, untilRaw: _utcIcalDateTime(until));
}

String _basicIcalDate(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}'
    '${value.month.toString().padLeft(2, '0')}'
    '${value.day.toString().padLeft(2, '0')}';

String _utcIcalDateTime(DateTime value) {
  final utc = value.toUtc();
  return '${_basicIcalDate(utc)}T'
      '${utc.hour.toString().padLeft(2, '0')}'
      '${utc.minute.toString().padLeft(2, '0')}'
      '${utc.second.toString().padLeft(2, '0')}Z';
}

Object? _newGoogleMeetRequest(Map<String, Object?> raw, String requestId) {
  final conference = raw['conferenceData'];
  if (conference is! Map) return null;
  final solution = conference['conferenceSolution'];
  final key = solution is Map ? solution['key'] : null;
  final type = key is Map ? key['type']?.toString() : null;
  if (type != 'hangoutsMeet') return null;
  return {
    'createRequest': {
      'requestId': requestId,
      'conferenceSolutionKey': {'type': 'hangoutsMeet'},
    },
  };
}

String? _localStart(CalendarEvent event) =>
    event.allDay ? event.startDate : event.startDateTime;

String? _localEnd(CalendarEvent event) =>
    event.allDay ? event.endDate : event.endDateTime;

const _eventSemanticBaselineKey = '__busymaxSemanticBaseline';

Map<String, Object?> _mapValue(Object? value) {
  if (value is Map<String, Object?>) {
    return value;
  }
  if (value is Map) {
    return value.cast<String, Object?>();
  }
  return const {};
}

String? _dateFromIso(String? value) {
  if (value == null || value.length < 10) {
    return null;
  }
  return value.substring(0, 10);
}

String? _nonBlank(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}

List<String>? _stringList(Object? value) {
  if (value is! List) {
    return null;
  }
  return [for (final item in value) item.toString()];
}

bool _deepEquals(Object? first, Object? second) {
  return jsonEncode(_normalize(first)) == jsonEncode(_normalize(second));
}

Object? _normalize(Object? value) {
  if (value is Map) {
    final entries = value.entries.toList()
      ..sort((a, b) => a.key.toString().compareTo(b.key.toString()));
    return {
      for (final entry in entries)
        entry.key.toString(): _normalize(entry.value),
    };
  }
  if (value is List) {
    return [for (final item in value) _normalize(item)];
  }
  return value;
}

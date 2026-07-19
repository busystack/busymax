import 'dart:convert';
import 'dart:math';

import 'package:drift/drift.dart';

import '../../calendar_providers/calendar_mutation.dart';
import '../../calendar_providers/calendar_description.dart';
import '../../calendar_providers/calendar_sync_dto.dart';
import '../../calendar_providers/cloud_calendar_client.dart';
import '../../db/app_database.dart';
import '../../google_calendar/google_calendar_errors.dart';
import '../../microsoft_calendar/microsoft_calendar_errors.dart';
import '../../task_providers/task_provider.dart';
import '../calendar/data/calendar_repository.dart';

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
      case 'calendar.patch':
        await _patchCalendar(op);
      case 'calendar.delete':
        await _deleteCalendar(op);
      case 'event.move':
      case 'calendar.create':
        await _blockOp(
          op,
          'unsupported_calendar_operation',
          _operationType(op),
        );
        throw const _PendingOpBlocked();
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
    return op.provider == TaskProvider.google.storageValue &&
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
    );
    await _replaceLocalEvent(op, event);
  }

  Future<void> _patchEvent(PendingOp op) async {
    final providerCalendarId = _require(op.providerCalendarId, 'calendarId');
    final local = await _localEvent(op);
    final providerEventId = await _providerEventId(op, local);
    final request = _request(op);
    await _ensureNoEventConflict(op, local, request);
    final event = await _client.updateEvent(
      calendarId: providerCalendarId,
      eventId: providerEventId,
      mutation: _eventMutation(
        request,
        fallbackTimeZone: await _fallbackTimeZone(op, local: local),
      ),
    );
    await _repository.upsertEvent(accountId: _accountId, event: event);
  }

  Future<void> _deleteEvent(PendingOp op) async {
    final providerCalendarId = _require(op.providerCalendarId, 'calendarId');
    final local = await _localEvent(op);
    final providerEventId = await _providerEventId(op, local);
    await _ensureEventUnchanged(op, local, 'delete');
    await _client.deleteEvent(
      calendarId: providerCalendarId,
      eventId: providerEventId,
    );
    await _applyDeleteSideEffect(op);
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
      calendarId: local.providerCalendarId,
      eventId: await _providerEventId(op, local),
    );
    final currentUpdatedUtc = _parseUtc(current.updatedAtServer);
    if (currentUpdatedUtc == null ||
        !currentUpdatedUtc.isAfter(baselineUpdatedUtc)) {
      return;
    }
    final baseline = _semanticSnapshot(
      _client.provider,
      _jsonObject(op.baselineRawJson ?? local.baselineRawJson ?? '{}'),
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
      calendarId: local.providerCalendarId,
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
    for (final entry in request.entries) {
      if (entry.value == null) {
        continue;
      }
      final key = entry.key;
      if (!_deepEquals(baseline[key], remote[key])) {
        changed.add(key);
      }
    }
    return changed;
  }

  Map<String, Object?> _semanticSnapshot(
    BusyProvider provider,
    Map<String, Object?> raw,
  ) {
    if (provider == TaskProvider.google) {
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
    };
  }

  CalendarEventMutation _eventMutation(
    Map<String, Object?> request, {
    String? fallbackTimeZone,
  }) {
    final allDay = request['allDay'] == true;
    final start = request['start']?.toString();
    final end = request['end']?.toString();
    final startTimeZone = allDay
        ? null
        : _nonBlank(request['startTimeZone']?.toString()) ??
              _nonBlank(fallbackTimeZone) ??
              'UTC';
    final endTimeZone = allDay
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
      reminders: request['remindersJson'],
      attendees: request['attendeesJson'],
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
    );
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

class _PendingOpBlocked {
  const _PendingOpBlocked();
}

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

import 'dart:convert';

import '../../calendar_providers/cloud_calendar_client.dart';
import '../../calendar_providers/calendar_sync_dto.dart';
import '../../db/app_database.dart';
import '../../core/time/stored_temporal_projection.dart';
import '../../google_calendar/google_calendar_errors.dart';
import '../../microsoft_calendar/microsoft_calendar_errors.dart';
import '../../microsoft_calendar/microsoft_calendar_api_client.dart';
import '../../microsoft_calendar/microsoft_shared_calendar_address.dart';
import 'package:drift/drift.dart';
import 'package:busymax/src/providers/busy_provider.dart';
import '../calendar/data/calendar_repository.dart';
import '../notifications/notification_schedule_service.dart';
import 'calendar_pending_ops_replayer.dart';
import 'collection_id_replacement.dart';

// Google sync tokens are bound to their request shape. Bump this marker when
// changing token-compatible event-list parameters so old cursors are rebased.
const _googleExpandedEventsSyncState = '{"singleEvents":true,"version":1}';

class CalendarSyncEngine {
  CalendarSyncEngine({
    required AppDatabase database,
    required CloudCalendarClient client,
    required String accountId,
    DateTime Function()? nowUtc,
    Future<void> Function(String summary)? onConflictBlocked,
    CollectionIdReplacement? onCalendarSourceIdReplaced,
    Future<void> Function()? onNotificationScheduleChanged,
  }) : _repository = CalendarRepository(database: database, now: nowUtc),
       _database = database,
       _client = client,
       _accountId = accountId,
       _onConflictBlocked = onConflictBlocked,
       _onCalendarSourceIdReplaced = onCalendarSourceIdReplaced,
       _onNotificationScheduleChanged = onNotificationScheduleChanged,
       _nowUtc = nowUtc ?? (() => DateTime.now().toUtc());

  final AppDatabase _database;
  final CalendarRepository _repository;
  final CloudCalendarClient _client;
  final String _accountId;
  final Future<void> Function(String summary)? _onConflictBlocked;
  final CollectionIdReplacement? _onCalendarSourceIdReplaced;
  final Future<void> Function()? _onNotificationScheduleChanged;
  final DateTime Function() _nowUtc;

  BusyProvider get provider => _client.provider;

  /// Retrieves one additional month as an independent snapshot. Range reads
  /// must never consume or replace the baseline events cursor.
  Future<void> retrieveMonth(DateTime month, {Set<String>? sourceIds}) async {
    if (sourceIds != null && sourceIds.isEmpty) return;
    final start = DateTime.utc(month.year, month.month);
    final end = DateTime.utc(month.year, month.month + 1);
    final query = _database.select(_database.calendarSources)
      ..where(
        (row) =>
            row.accountId.equals(_accountId) &
            row.provider.equals(provider.storageValue) &
            row.isDeleted.equals(false),
      );
    if (sourceIds == null) {
      query.where(
        (row) => row.selected.equals(true) & row.hidden.equals(false),
      );
    } else {
      query.where((row) => row.id.isIn(sourceIds));
    }
    final sources = await query.get();
    try {
      for (final source in sources) {
        // Both clients finish pagination before returning. A failed later page
        // therefore cannot turn a partial response into an empty snapshot.
        final events = await _client.listEvents(
          calendarId: source.providerCalendarId,
          rangeStart: start,
          rangeEnd: end,
        );
        final recurringIds = <String>{
          for (final event in events)
            if (event.providerRecurringEventId case final id?) id,
        };
        final existingInstances =
            await (_database.select(_database.calendarEvents)..where(
                  (row) =>
                      row.calendarSourceId.equals(source.id) &
                      row.providerRecurringEventId.isNotNull(),
                ))
                .get();
        recurringIds.addAll(
          existingInstances
              .where((row) {
                return storedCalendarEventOverlapsUtcRange(row, start, end);
              })
              .map((row) => row.providerRecurringEventId!),
        );
        final instances = <CalendarEventDto>[];
        final masters = <CalendarEventDto>[];
        for (final id in recurringIds) {
          try {
            instances.addAll(
              await _client.listEventInstances(
                calendarId: source.providerCalendarId,
                recurringEventId: id,
                rangeStart: start,
                rangeEnd: end,
              ),
            );
            masters.add(
              await _client.getEvent(
                calendarId: source.providerCalendarId,
                eventId: id,
              ),
            );
          } on GoogleCalendarApiError catch (error) {
            if (error.statusCode != 404 && error.statusCode != 410) rethrow;
          } on MicrosoftCalendarApiError catch (error) {
            if (error.statusCode != 404 && error.statusCode != 410) rethrow;
          }
        }
        final returnedIds = <String>{};
        for (final event in [...events, ...instances]) {
          await _repository.upsertEvent(
            accountId: _accountId,
            event: event,
            preservePendingLocalChanges: true,
          );
          returnedIds.add(
            CalendarRepository.eventId(
              accountId: _accountId,
              provider: event.provider,
              providerCalendarId: event.providerCalendarId,
              providerEventId: event.providerEventId,
              providerOriginalStartKey: event.providerOriginalStartKey,
            ),
          );
        }
        for (final master in masters) {
          await _repository.upsertEvent(
            accountId: _accountId,
            event: master,
            preservePendingLocalChanges: true,
          );
        }
        await _repository.markExpandedRecurringMastersDeleted(
          accountId: _accountId,
          provider: provider,
          providerCalendarId: source.providerCalendarId,
          providerRecurringEventIds: recurringIds,
        );
        await _repository.markMissingEventsDeleted(
          accountId: _accountId,
          provider: provider,
          providerCalendarId: source.providerCalendarId,
          rangeStart: start,
          rangeEnd: end,
          returnedLocalEventIds: returnedIds,
        );
        await _repository.saveSyncState(
          accountId: _accountId,
          provider: provider,
          syncKind: 'events_range_${start.year}_${start.month}',
          calendarSourceId: source.id,
          rangeStart: start.toIso8601String(),
          rangeEnd: end.toIso8601String(),
          cursorKind: 'snapshot_generation',
          cursorValue: '0',
          full: true,
        );
      }
    } finally {
      await NotificationScheduleService(
        database: _database,
        nowUtc: _nowUtc,
      ).rebuildUpcomingEventNotifications(_accountId);
      await _onNotificationScheduleChanged?.call();
    }
  }

  Future<void> fullSync() async {
    try {
      await _replayPendingOps();
      final calendars = await _refreshCalendarSources();

      final window = _calendarSyncWindow(_nowUtc());
      for (final calendar in calendars.where((source) => !source.isDeleted)) {
        await _syncCalendarRange(
          providerCalendarId: calendar.providerCalendarId,
          primaryCalendar: calendar.primaryCalendar,
          rangeStart: window.start,
          rangeEnd: window.end,
          full: true,
        );
      }
    } finally {
      // Earlier pages and pending operations may already have committed.
      await NotificationScheduleService(
        database: _database,
        nowUtc: _nowUtc,
      ).rebuildUpcomingEventNotifications(_accountId);
      await _onNotificationScheduleChanged?.call();
    }
  }

  Future<void> incrementalSync() async {
    try {
      await _replayPendingOps();
      final calendars = await _refreshCalendarSources();

      final window = _calendarSyncWindow(_nowUtc());
      final rangeStartValue = window.start.toIso8601String();
      final rangeEndValue = window.end.toIso8601String();
      for (final calendar in calendars.where((source) => !source.isDeleted)) {
        final sourceId = CalendarRepository.sourceId(
          accountId: _accountId,
          provider: provider,
          providerCalendarId: calendar.providerCalendarId,
        );
        final state = await _repository.syncState(
          accountId: _accountId,
          provider: provider,
          syncKind: 'events',
          calendarSourceId: sourceId,
        );
        final rangeMatches =
            state?.rangeStart == rangeStartValue &&
            state?.rangeEnd == rangeEndValue;
        final expectedCursorKind = provider == BusyProvider.google
            ? 'google_sync_token'
            : 'microsoft_delta_link';
        final savedCursor = state?.cursorKind == expectedCursorKind
            ? state?.cursorValue
            : null;
        final supportsIncrementalCursor =
            provider == BusyProvider.google || calendar.primaryCalendar;
        final syncOptionsMatch =
            provider != BusyProvider.google ||
            state?.stateJson == _googleExpandedEventsSyncState;
        final tokenOrLink =
            supportsIncrementalCursor &&
                rangeMatches &&
                syncOptionsMatch &&
                savedCursor?.isNotEmpty == true
            ? savedCursor
            : null;
        final requiresSnapshot =
            tokenOrLink == null ||
            (provider == BusyProvider.microsoft && !calendar.primaryCalendar);
        await _syncCalendarRange(
          providerCalendarId: calendar.providerCalendarId,
          primaryCalendar: calendar.primaryCalendar,
          rangeStart: window.start,
          rangeEnd: window.end,
          tokenOrLink: tokenOrLink,
          full: requiresSnapshot,
        );
      }
    } finally {
      // Earlier pages and pending operations may already have committed.
      await NotificationScheduleService(
        database: _database,
        nowUtc: _nowUtc,
      ).rebuildUpcomingEventNotifications(_accountId);
      await _onNotificationScheduleChanged?.call();
    }
  }

  Future<List<CalendarSourceDto>> _refreshCalendarSources() async {
    // listCalendars() returns only after every page has been retrieved, so an
    // absent cloud calendar can be treated as a provider-side deletion.
    final calendars = await _client.listCalendars();
    if (_client case final MicrosoftCalendarApiClient microsoftClient) {
      final opened =
          await (_database.select(_database.calendarSources)..where(
                (row) =>
                    row.accountId.equals(_accountId) &
                    row.provider.equals(BusyProvider.microsoft.storageValue),
              ))
              .get();
      for (final source in opened) {
        final address = MicrosoftSharedPrimaryCalendarAddress.parse(
          source.providerCalendarId,
        );
        if (address == null) continue;
        try {
          calendars.add(
            await microsoftClient.getSharedPrimaryCalendar(address.owner),
          );
        } on MicrosoftCalendarApiError catch (error) {
          if (error.statusCode != 403 && error.statusCode != 404) rethrow;
          // Explicit owner-context denial is not an empty calendar. Keep its
          // cached source, but remove write actions until access is restored.
          final oldMetadata = jsonDecode(source.rawJson ?? '{}');
          await (_database.update(
            _database.calendarSources,
          )..where((row) => row.id.equals(source.id))).write(
            CalendarSourcesCompanion(
              readOnly: const Value(true),
              accessRole: const Value('unavailable'),
              rawJson: Value(
                jsonEncode({
                  if (oldMetadata is Map)
                    ...oldMetadata.cast<String, Object?>(),
                  '_busymaxOwnerAccessUnavailable': true,
                }),
              ),
            ),
          );
        }
      }
    }
    for (final calendar in calendars) {
      await _repository.upsertSource(accountId: _accountId, source: calendar);
    }
    if (provider == BusyProvider.google || provider == BusyProvider.microsoft) {
      await _repository.reconcileProviderSourceSnapshot(
        accountId: _accountId,
        provider: provider,
        activeProviderCalendarIds: {
          for (final calendar in calendars)
            if (!calendar.isDeleted) calendar.providerCalendarId,
        },
      );
    }
    return calendars;
  }

  Future<void> _syncCalendarRange({
    required String providerCalendarId,
    required bool primaryCalendar,
    required DateTime rangeStart,
    required DateTime rangeEnd,
    String? tokenOrLink,
    bool full = false,
  }) async {
    var page = await _client.syncEvents(
      calendarId: providerCalendarId,
      rangeStart: rangeStart,
      rangeEnd: rangeEnd,
      syncTokenOrDeltaLink: tokenOrLink,
      primaryCalendar: primaryCalendar,
    );
    var restartedFromExpiredCursor = false;
    if (page.requiresFullSync) {
      page = await _client.syncEvents(
        calendarId: providerCalendarId,
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
        primaryCalendar: primaryCalendar,
      );
      full = true;
      restartedFromExpiredCursor = true;
    }
    final returnedLocalEventIds = <String>{};
    final expandedRecurringMasterIds = <String>{};
    while (true) {
      for (final event in page.events) {
        await _repository.upsertEvent(
          accountId: _accountId,
          event: event,
          preservePendingLocalChanges: true,
        );
        final recurringMasterId = event.providerRecurringEventId;
        if ((provider == BusyProvider.google ||
                provider == BusyProvider.microsoft) &&
            recurringMasterId != null &&
            recurringMasterId.isNotEmpty) {
          expandedRecurringMasterIds.add(recurringMasterId);
        }
        returnedLocalEventIds.add(
          CalendarRepository.eventId(
            accountId: _accountId,
            provider: event.provider,
            providerCalendarId: event.providerCalendarId,
            providerEventId: event.providerEventId,
            providerOriginalStartKey: event.providerOriginalStartKey,
          ),
        );
      }
      if (page.events.isNotEmpty) {
        // Events from this page are already committed. Reconcile before any
        // later page or calendar request so earlier alarms become due now.
        await NotificationScheduleService(
          database: _database,
          nowUtc: _nowUtc,
        ).rebuildUpcomingEventNotifications(_accountId);
        await _onNotificationScheduleChanged?.call();
      }
      final next = page.nextPageTokenOrUrl;
      if (next == null || next.isEmpty) {
        break;
      }
      final nextPage = await _client.syncEvents(
        calendarId: providerCalendarId,
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
        syncTokenOrDeltaLink: provider == BusyProvider.google
            ? tokenOrLink
            : next,
        primaryCalendar: primaryCalendar,
      );
      if (nextPage.requiresFullSync) {
        if (restartedFromExpiredCursor) {
          throw StateError('Calendar sync baseline could not be established.');
        }
        page = await _client.syncEvents(
          calendarId: providerCalendarId,
          rangeStart: rangeStart,
          rangeEnd: rangeEnd,
          primaryCalendar: primaryCalendar,
        );
        returnedLocalEventIds.clear();
        expandedRecurringMasterIds.clear();
        full = true;
        restartedFromExpiredCursor = true;
        continue;
      }
      page = nextPage;
      if (provider == BusyProvider.google && page.nextPageTokenOrUrl == next) {
        break;
      }
    }

    if (provider == BusyProvider.google || provider == BusyProvider.microsoft) {
      // Expanded Google synchronization and Microsoft calendar views return
      // instances but omit their recurring masters. Retain the authoritative
      // master snapshots separately so later whole-series mutations have a
      // real conflict baseline instead of borrowing one from an occurrence.
      for (final recurringMasterId in expandedRecurringMasterIds) {
        final master = await _client.getEvent(
          calendarId: providerCalendarId,
          eventId: recurringMasterId,
        );
        await _repository.upsertEvent(
          accountId: _accountId,
          event: master,
          preservePendingLocalChanges: true,
        );
      }
      await _repository.markExpandedRecurringMastersDeleted(
        accountId: _accountId,
        provider: provider,
        providerCalendarId: providerCalendarId,
        providerRecurringEventIds: expandedRecurringMasterIds,
      );
    }

    final sourceId = CalendarRepository.sourceId(
      accountId: _accountId,
      provider: provider,
      providerCalendarId: providerCalendarId,
    );
    final completedCursor = page.nextSyncTokenOrDeltaLink;
    await _repository.saveSyncState(
      accountId: _accountId,
      provider: provider,
      syncKind: 'events',
      calendarSourceId: sourceId,
      rangeStart: rangeStart.toIso8601String(),
      rangeEnd: rangeEnd.toIso8601String(),
      cursorKind: completedCursor == null
          ? 'snapshot_generation'
          : provider == BusyProvider.google
          ? 'google_sync_token'
          : 'microsoft_delta_link',
      cursorValue: completedCursor ?? '0',
      full: full,
      stateJson: provider == BusyProvider.google
          ? _googleExpandedEventsSyncState
          : null,
    );
    if (full) {
      await _repository.markMissingEventsDeleted(
        accountId: _accountId,
        provider: provider,
        providerCalendarId: providerCalendarId,
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
        returnedLocalEventIds: returnedLocalEventIds,
      );
    }
  }

  Future<int> _replayPendingOps() {
    return CalendarPendingOpsReplayer(
      database: _database,
      client: _client,
      accountId: _accountId,
      nowUtc: _nowUtc,
      onConflictBlocked: _onConflictBlocked,
      onCalendarSourceIdReplaced: _onCalendarSourceIdReplaced,
    ).replayDueOps();
  }
}

({DateTime start, DateTime end}) _calendarSyncWindow(DateTime now) {
  final utc = now.toUtc();
  // Provider cursors are tied to their initial bounds. Keep those bounds fixed
  // within a month, then establish a fresh baseline as the horizon advances.
  return (
    start: DateTime.utc(utc.year - 1, utc.month),
    end: DateTime.utc(utc.year + 2, utc.month + 1),
  );
}

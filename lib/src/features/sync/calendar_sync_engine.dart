import '../../calendar_providers/cloud_calendar_client.dart';
import '../../db/app_database.dart';
import '../../task_providers/task_provider.dart';
import '../calendar/data/calendar_repository.dart';
import '../notifications/notification_schedule_service.dart';
import 'calendar_pending_ops_replayer.dart';

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
    Future<void> Function()? onNotificationScheduleChanged,
  }) : _repository = CalendarRepository(database: database, now: nowUtc),
       _database = database,
       _client = client,
       _accountId = accountId,
       _onConflictBlocked = onConflictBlocked,
       _onNotificationScheduleChanged = onNotificationScheduleChanged,
       _nowUtc = nowUtc ?? (() => DateTime.now().toUtc());

  final AppDatabase _database;
  final CalendarRepository _repository;
  final CloudCalendarClient _client;
  final String _accountId;
  final Future<void> Function(String summary)? _onConflictBlocked;
  final Future<void> Function()? _onNotificationScheduleChanged;
  final DateTime Function() _nowUtc;

  BusyProvider get provider => _client.provider;

  Future<void> fullSync() async {
    await _replayPendingOps();
    final calendars = await _client.listCalendars();
    for (final calendar in calendars) {
      await _repository.upsertSource(accountId: _accountId, source: calendar);
    }

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
    await NotificationScheduleService(
      database: _database,
      nowUtc: _nowUtc,
    ).rebuildUpcomingEventNotifications(_accountId);
    await _onNotificationScheduleChanged?.call();
  }

  Future<void> incrementalSync() async {
    await _replayPendingOps();
    final calendars = await _client.listCalendars();
    for (final calendar in calendars) {
      await _repository.upsertSource(accountId: _accountId, source: calendar);
    }

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
      final savedCursor = provider == TaskProvider.google
          ? state?.googleSyncToken
          : state?.microsoftDeltaLink;
      final supportsIncrementalCursor =
          provider == TaskProvider.google || calendar.primaryCalendar;
      final syncOptionsMatch =
          provider != TaskProvider.google ||
          state?.rawStateJson == _googleExpandedEventsSyncState;
      final tokenOrLink =
          supportsIncrementalCursor &&
              rangeMatches &&
              syncOptionsMatch &&
              savedCursor?.isNotEmpty == true
          ? savedCursor
          : null;
      final requiresSnapshot =
          tokenOrLink == null ||
          (provider == TaskProvider.microsoft && !calendar.primaryCalendar);
      await _syncCalendarRange(
        providerCalendarId: calendar.providerCalendarId,
        primaryCalendar: calendar.primaryCalendar,
        rangeStart: window.start,
        rangeEnd: window.end,
        tokenOrLink: tokenOrLink,
        full: requiresSnapshot,
      );
    }
    await NotificationScheduleService(
      database: _database,
      nowUtc: _nowUtc,
    ).rebuildUpcomingEventNotifications(_accountId);
    await _onNotificationScheduleChanged?.call();
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
        if (provider == TaskProvider.google &&
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
      final next = page.nextPageTokenOrUrl;
      if (next == null || next.isEmpty) {
        break;
      }
      final nextPage = await _client.syncEvents(
        calendarId: providerCalendarId,
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
        syncTokenOrDeltaLink: provider == TaskProvider.google
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
      if (provider == TaskProvider.google && page.nextPageTokenOrUrl == next) {
        break;
      }
    }

    if (provider == TaskProvider.google) {
      await _repository.markGoogleRecurringMastersDeleted(
        accountId: _accountId,
        providerCalendarId: providerCalendarId,
        providerRecurringEventIds: expandedRecurringMasterIds,
      );
    }

    final sourceId = CalendarRepository.sourceId(
      accountId: _accountId,
      provider: provider,
      providerCalendarId: providerCalendarId,
    );
    await _repository.saveSyncState(
      accountId: _accountId,
      provider: provider,
      syncKind: 'events',
      calendarSourceId: sourceId,
      rangeStart: rangeStart.toIso8601String(),
      rangeEnd: rangeEnd.toIso8601String(),
      googleSyncToken: provider == TaskProvider.google
          ? page.nextSyncTokenOrDeltaLink
          : null,
      microsoftDeltaLink: provider == TaskProvider.microsoft
          ? page.nextSyncTokenOrDeltaLink
          : null,
      full: full,
      rawStateJson: provider == TaskProvider.google
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

import '../../calendar_providers/cloud_calendar_client.dart';
import '../../db/app_database.dart';
import '../../task_providers/task_provider.dart';
import '../calendar/data/calendar_repository.dart';
import '../notifications/notification_schedule_service.dart';
import 'calendar_pending_ops_replayer.dart';

class CalendarSyncEngine {
  CalendarSyncEngine({
    required AppDatabase database,
    required CloudCalendarClient client,
    required String accountId,
    DateTime Function()? nowUtc,
    Future<void> Function(String summary)? onConflictBlocked,
  }) : _repository = CalendarRepository(database: database, now: nowUtc),
       _database = database,
       _client = client,
       _accountId = accountId,
       _onConflictBlocked = onConflictBlocked,
       _nowUtc = nowUtc ?? (() => DateTime.now().toUtc());

  final AppDatabase _database;
  final CalendarRepository _repository;
  final CloudCalendarClient _client;
  final String _accountId;
  final Future<void> Function(String summary)? _onConflictBlocked;
  final DateTime Function() _nowUtc;

  BusyProvider get provider => _client.provider;

  Future<void> fullSync() async {
    await _replayPendingOps();
    final calendars = await _client.listCalendars();
    for (final calendar in calendars) {
      await _repository.upsertSource(accountId: _accountId, source: calendar);
    }

    final now = _nowUtc();
    final rangeStart = now.subtract(const Duration(days: 365));
    final rangeEnd = now.add(const Duration(days: 365 * 2));
    for (final calendar in calendars.where((source) => !source.isDeleted)) {
      await _syncCalendarRange(
        providerCalendarId: calendar.providerCalendarId,
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
        full: true,
      );
    }
    await NotificationScheduleService(
      database: _database,
      nowUtc: _nowUtc,
    ).rebuildUpcomingEventNotifications(_accountId);
  }

  Future<void> incrementalSync() async {
    await _replayPendingOps();
    final calendars = await _client.listCalendars();
    for (final calendar in calendars) {
      await _repository.upsertSource(accountId: _accountId, source: calendar);
    }

    final now = _nowUtc();
    final rangeStart = now.subtract(const Duration(days: 365));
    final rangeEnd = now.add(const Duration(days: 365 * 2));
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
        rangeStart: rangeStart.toIso8601String(),
        rangeEnd: rangeEnd.toIso8601String(),
      );
      await _syncCalendarRange(
        providerCalendarId: calendar.providerCalendarId,
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
        tokenOrLink: provider == TaskProvider.google
            ? state?.googleSyncToken
            : state?.microsoftDeltaLink,
      );
    }
    await NotificationScheduleService(
      database: _database,
      nowUtc: _nowUtc,
    ).rebuildUpcomingEventNotifications(_accountId);
  }

  Future<void> _syncCalendarRange({
    required String providerCalendarId,
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
    );
    if (page.requiresFullSync) {
      page = await _client.syncEvents(
        calendarId: providerCalendarId,
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
      );
      full = true;
    }
    final returnedLocalEventIds = <String>{};
    while (true) {
      for (final event in page.events) {
        await _repository.upsertEvent(accountId: _accountId, event: event);
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
      page = await _client.syncEvents(
        calendarId: providerCalendarId,
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
        syncTokenOrDeltaLink: provider == TaskProvider.google
            ? tokenOrLink
            : next,
      );
      if (provider == TaskProvider.google && page.nextPageTokenOrUrl == next) {
        break;
      }
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

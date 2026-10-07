import 'dart:async';

import 'package:drift/drift.dart';

import '../../db/app_database.dart';
import '../../features/accounts/data/accounts_repository.dart';
import '../../providers/busy_provider.dart';
import 'calendar_sync_engine.dart';

/// Bounded, independently persisted range snapshots for cloud calendars.
/// Concurrent overlapping views share each source/month request.
final class CloudCalendarRangeCoverageService {
  CloudCalendarRangeCoverageService({
    required AppDatabase database,
    required CalendarMonthRetriever retrieveMonth,
    DateTime Function()? nowUtc,
  }) : _database = database,
       _retrieveMonth = retrieveMonth,
       _nowUtc = nowUtc ?? (() => DateTime.now().toUtc());

  final AppDatabase _database;
  final CalendarMonthRetriever _retrieveMonth;
  final DateTime Function() _nowUtc;
  final Map<String, Future<void>> _inFlight = {};

  /// Returns false if any month could not be verified. Cached events remain
  /// available in that case, but a caller must not present an empty range as
  /// an authoritative empty result.
  Future<bool> ensureRange(
    DateTime start,
    DateTime end, {
    Set<String> accountIds = const {},
    Set<String> sourceIds = const {},
    bool sourceFilterActive = false,
  }) async {
    final from = start.toUtc();
    final until = end.toUtc();
    if (!until.isAfter(from)) return false;
    if (sourceFilterActive && sourceIds.isEmpty) return true;
    final accountQuery = _database.select(_database.accounts)
      ..where((row) => row.calendarsEnabled.equals(true));
    if (accountIds.isNotEmpty) {
      accountQuery.where((row) => row.id.isIn(accountIds));
    }
    final accounts = await accountQuery.get();
    final requested =
        <
          ({
            String accountId,
            BusyProvider provider,
            String sourceId,
            bool online,
          })
        >[];
    for (final account in accounts) {
      final provider = BusyProviderCodec.parseStorageValue(
        account.provider,
      ).provider;
      if (provider != BusyProvider.google &&
          provider != BusyProvider.microsoft) {
        continue;
      }
      final sourceQuery = _database.select(_database.calendarSources)
        ..where(
          (row) =>
              row.accountId.equals(account.id) &
              row.provider.equals(provider!.storageValue) &
              row.isDeleted.equals(false),
        );
      if (sourceFilterActive) {
        sourceQuery.where((row) => row.id.isIn(sourceIds));
      } else {
        sourceQuery.where(
          (row) => row.selected.equals(true) & row.hidden.equals(false),
        );
      }
      for (final source in await sourceQuery.get()) {
        requested.add((
          accountId: account.id,
          provider: provider!,
          sourceId: source.id,
          online: account.authState == accountAuthStateSignedIn,
        ));
      }
    }
    var complete = true;
    for (
      var month = DateTime.utc(from.year, from.month);
      month.isBefore(until);
      month = DateTime.utc(month.year, month.month + 1)
    ) {
      final results = await Future.wait([
        for (final source in requested) _ensureSourceMonth(source, month),
      ]);
      if (results.contains(false)) complete = false;
    }
    return complete;
  }

  Future<bool> _ensureSourceMonth(
    ({String accountId, BusyProvider provider, String sourceId, bool online})
    source,
    DateTime month,
  ) async {
    final scope = 'events_range_${month.year}_${month.month}';
    Future<SyncCursor?> state() =>
        (_database.select(_database.syncCursors)..where(
              (row) =>
                  row.accountId.equals(source.accountId) &
                  row.projectionSourceId.equals(source.sourceId) &
                  row.syncScopeKind.equals(scope),
            ))
            .getSingleOrNull();
    bool fresh(SyncCursor? cursor) =>
        cursor?.lastCompleteSyncAt != null &&
        _nowUtc().millisecondsSinceEpoch - cursor!.lastCompleteSyncAt! <
            const Duration(minutes: 5).inMilliseconds;
    if (fresh(await state())) return true;
    if (!source.online) return false;
    final key =
        '${source.accountId}|${source.sourceId}|${month.year}|${month.month}';
    final running = _inFlight[key] ??= _retrieveMonth(
      source.accountId,
      source.provider,
      month,
      sourceIds: {source.sourceId},
    );
    try {
      await running;
      return fresh(await state());
    } on Object {
      return false;
    } finally {
      if (identical(_inFlight[key], running)) _inFlight.remove(key);
    }
  }
}

import 'dart:async';

import 'package:drift/drift.dart';

import '../../db/app_database.dart';
import '../../features/accounts/data/accounts_repository.dart';
import '../../providers/busy_provider.dart';
import 'calendar_sync_engine.dart';

/// Bounded, independently persisted range snapshots for cloud calendars.
/// Concurrent overlapping views share each account/month request.
final class CloudCalendarRangeCoverageService {
  CloudCalendarRangeCoverageService({
    required AppDatabase database,
    required CalendarSyncEngine Function(String, BusyProvider) engineForAccount,
    DateTime Function()? nowUtc,
  }) : _database = database,
       _engineForAccount = engineForAccount,
       _nowUtc = nowUtc ?? (() => DateTime.now().toUtc());

  final AppDatabase _database;
  final CalendarSyncEngine Function(String, BusyProvider) _engineForAccount;
  final DateTime Function() _nowUtc;
  final Map<String, Future<void>> _inFlight = {};

  /// Returns false if any month could not be verified. Cached events remain
  /// available in that case, but a caller must not present an empty range as
  /// an authoritative empty result.
  Future<bool> ensureRange(DateTime start, DateTime end) async {
    final from = start.toUtc();
    final until = end.toUtc();
    if (!until.isAfter(from)) return false;
    final accounts = await _database.select(_database.accounts).get();
    var complete = true;
    for (final account in accounts) {
      final provider = BusyProviderCodec.parseStorageValue(
        account.provider,
      ).provider;
      if (provider != BusyProvider.google &&
          provider != BusyProvider.microsoft) {
        continue;
      }
      final sources =
          await (_database.select(_database.calendarSources)..where(
                (row) =>
                    row.accountId.equals(account.id) &
                    row.selected.equals(true) &
                    row.hidden.equals(false) &
                    row.isDeleted.equals(false),
              ))
              .get();
      if (sources.isEmpty) continue;
      for (
        var month = DateTime.utc(from.year, from.month);
        month.isBefore(until);
        month = DateTime.utc(month.year, month.month + 1)
      ) {
        final scope = 'events_range_${month.year}_${month.month}';
        final states = await Future.wait([
          for (final source in sources)
            (_database.select(_database.syncCursors)..where(
                  (row) =>
                      row.accountId.equals(account.id) &
                      row.projectionSourceId.equals(source.id) &
                      row.syncScopeKind.equals(scope),
                ))
                .getSingleOrNull(),
        ]);
        final fresh = states.every(
          (state) =>
              state?.lastCompleteSyncAt != null &&
              _nowUtc().millisecondsSinceEpoch - state!.lastCompleteSyncAt! <
                  const Duration(minutes: 5).inMilliseconds,
        );
        if (fresh) continue;
        if (account.authState != accountAuthStateSignedIn) {
          complete = false;
          continue;
        }
        final key = '${account.id}|${month.year}|${month.month}';
        final running = _inFlight[key] ??= _engineForAccount(
          account.id,
          provider!,
        ).retrieveMonth(month);
        try {
          await running;
        } on Object {
          complete = false;
        } finally {
          if (identical(_inFlight[key], running)) _inFlight.remove(key);
        }
      }
    }
    return complete;
  }
}

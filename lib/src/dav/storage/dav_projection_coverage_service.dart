import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';

import '../../db/app_database.dart';
import '../../providers/busy_provider.dart';
import 'dav_object_repository.dart';

/// Expands the local DAV event projection when the calendar UI asks for dates
/// outside the cached occurrence horizon.  This only reads retained calendar
/// objects; it neither contacts the server nor changes the DAV sync cursor.
final class DavProjectionCoverageService {
  DavProjectionCoverageService({
    required AppDatabase database,
    DavObjectRepository? objectRepository,
    DateTime Function()? nowUtc,
  }) : _database = database,
       _objectRepository =
           objectRepository ?? DavObjectRepository(database: database),
       _nowUtc = nowUtc ?? (() => DateTime.now().toUtc());

  final AppDatabase _database;
  final DavObjectRepository _objectRepository;
  final DateTime Function() _nowUtc;
  final Map<String, Future<void>> _queuedCollections = {};

  Future<void> ensureProjectionCoverage({
    required DateTime rangeStartUtc,
    required DateTime rangeEndUtc,
  }) async {
    final requestedStart = rangeStartUtc.toUtc();
    final requestedEnd = rangeEndUtc.toUtc();
    if (!requestedEnd.isAfter(requestedStart)) return;

    final collections =
        await (_database.select(_database.davCollections)..where(
              (row) =>
                  row.eventProjectionEnabled.equals(true) &
                  row.eventsSelected.equals(true) &
                  row.deleted.equals(false) &
                  row.serverMissing.equals(false),
            ))
            .get();
    if (collections.isEmpty) return;
    final accountIds = collections
        .map((collection) => collection.accountId)
        .toSet();
    final accounts = await (_database.select(
      _database.accounts,
    )..where((row) => row.id.isIn(accountIds))).get();
    final providersByAccount = <String, BusyProvider>{
      for (final account in accounts)
        if (BusyProviderCodec.parseStorageValue(account.provider)
            case SupportedBusyProvider(:final value))
          account.id: value,
    };

    await Future.wait([
      for (final collection in collections)
        if (switch (providersByAccount[collection.accountId]) {
          BusyProvider.nextcloud || BusyProvider.appleICloud => true,
          _ => false,
        })
          _queueCollection(
            collectionId: collection.id,
            accountId: collection.accountId,
            provider: providersByAccount[collection.accountId]!,
            requestedStart: requestedStart,
            requestedEnd: requestedEnd,
          ),
    ]);
  }

  Future<void> _queueCollection({
    required String collectionId,
    required String accountId,
    required BusyProvider provider,
    required DateTime requestedStart,
    required DateTime requestedEnd,
  }) {
    final previous = _queuedCollections[collectionId];
    final queued = _continueAfter(
      previous,
      () => _ensureCollection(
        collectionId: collectionId,
        accountId: accountId,
        provider: provider,
        requestedStart: requestedStart,
        requestedEnd: requestedEnd,
      ),
    );
    _queuedCollections[collectionId] = queued;
    return queued.whenComplete(() {
      if (identical(_queuedCollections[collectionId], queued)) {
        _queuedCollections.remove(collectionId);
      }
    });
  }

  Future<void> _continueAfter(
    Future<void>? previous,
    Future<void> Function() next,
  ) async {
    if (previous != null) {
      try {
        await previous;
      } catch (_) {
        // A later navigation attempt should still be able to reproject.
      }
    }
    await next();
  }

  Future<void> _ensureCollection({
    required String collectionId,
    required String accountId,
    required BusyProvider provider,
    required DateTime requestedStart,
    required DateTime requestedEnd,
  }) async {
    final cursor = await _objectRepository.cursor(collectionId);
    if (_covers(cursor?.stateJson, requestedStart, requestedEnd)) return;
    final coverage = _coverageWindow(requestedStart, requestedEnd);
    await _objectRepository.reprojectCollectionFromStored(
      accountId: accountId,
      collectionId: collectionId,
      provider: provider,
      projectionRangeStartUtc: coverage.start,
      projectionRangeEndUtc: coverage.end,
      completedAtUtc: _nowUtc(),
    );
  }
}

bool _covers(
  String? stateJson,
  DateTime requestedStart,
  DateTime requestedEnd,
) {
  if (stateJson == null || stateJson.isEmpty) return false;
  try {
    final decoded = jsonDecode(stateJson);
    if (decoded is! Map) return false;
    if (decoded['projectionVersion'] != davProjectionVersion) return false;
    final start = DateTime.tryParse(
      decoded['projectionRangeStartUtc']?.toString() ?? '',
    )?.toUtc();
    final end = DateTime.tryParse(
      decoded['projectionRangeEndUtc']?.toString() ?? '',
    )?.toUtc();
    return start != null &&
        end != null &&
        !requestedStart.isBefore(start) &&
        !requestedEnd.isAfter(end);
  } on FormatException {
    return false;
  }
}

({DateTime start, DateTime end}) _coverageWindow(
  DateTime requestedStart,
  DateTime requestedEnd,
) {
  // Keep the ordinary three-year local horizon, but move it with navigation
  // instead of permanently anchoring it to application startup.
  final start = DateTime.utc(
    requestedStart.year - 1,
    requestedStart.month,
    requestedStart.day,
    requestedStart.hour,
    requestedStart.minute,
    requestedStart.second,
  );
  final end = DateTime.utc(
    requestedEnd.year + 2,
    requestedEnd.month,
    requestedEnd.day,
    requestedEnd.hour,
    requestedEnd.minute,
    requestedEnd.second,
  );
  return (start: start, end: end);
}

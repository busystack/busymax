import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../db/app_database.dart';
import '../domain/geographic_point.dart';
import '../domain/location_result.dart';

const googleSeriesLocationResolutionKind = 'googleSeries';

/// Preserves coordinates already associated with an exact saved item snapshot.
/// Never touches owners, pending operations, notifications, or sync timestamps.
final class LocationResolutionRepository {
  const LocationResolutionRepository(this.database);
  final AppDatabase database;
  Expression<bool> _owner(
    $LocationResolutionsTable row,
    LocationItemIdentity item,
  ) =>
      row.kind.equals(item.kind.name) &
      row.accountId.equals(item.accountId) &
      row.sourceId.equals(item.sourceId) &
      row.itemId.equals(item.itemId);
  Future<LocationResult?> load(
    LocationItemIdentity item,
    String location,
  ) async {
    final row = await (database.select(
      database.locationResolutions,
    )..where((r) => _owner(r, item))).getSingleOrNull();
    if (row != null) {
      if (row.locationText != location || !await _current(item, location)) {
        return null;
      }
      return _selection(row);
    }
    return item.kind == LocationItemKind.event
        ? _loadGoogleSeries(item, location)
        : null;
  }

  Future<LocationResult?> _loadGoogleSeries(
    LocationItemIdentity item,
    String location,
  ) async {
    final event =
        await (database.select(database.calendarEvents)..where(
              (row) =>
                  row.id.equals(item.itemId) &
                  row.accountId.equals(item.accountId) &
                  row.calendarSourceId.equals(item.sourceId) &
                  row.provider.equals('google') &
                  row.providerRecurringEventId.isNotNull() &
                  row.isDeleted.equals(false) &
                  row.isCancelled.equals(false),
            ))
            .getSingleOrNull();
    final providerSeriesId = event?.providerRecurringEventId;
    if (event == null ||
        providerSeriesId == null ||
        (event.location ?? '') != location) {
      return null;
    }
    final row =
        await (database.select(database.locationResolutions)..where(
              (stored) =>
                  stored.kind.equals(googleSeriesLocationResolutionKind) &
                  stored.accountId.equals(item.accountId) &
                  stored.sourceId.equals(item.sourceId) &
                  stored.itemId.equals(providerSeriesId),
            ))
            .getSingleOrNull();
    if (row == null || row.locationText != location) return null;
    return _selection(row);
  }

  Future<void> apply(
    LocationItemIdentity item,
    String location,
    LocationChange change,
  ) async {
    if (!change.changed) return;
    await database.transaction(() async {
      if (!await _current(item, location)) return;
      await (database.delete(
        database.locationResolutions,
      )..where((r) => _owner(r, item))).go();
      if (change.selection case final selection?) {
        if (!await _current(item, location)) return;
        await database
            .into(database.locationResolutions)
            .insertOnConflictUpdate(
              LocationResolutionsCompanion.insert(
                kind: item.kind.name,
                accountId: item.accountId,
                sourceId: item.sourceId,
                itemId: item.itemId,
                locationText: location,
                label: selection.label,
                latitude: selection.point.latitude,
                longitude: selection.point.longitude,
                source: selection.source,
                attribution: selection.attribution,
              ),
            );
      }
    });
  }

  Future<bool> _current(LocationItemIdentity item, String location) async {
    if (item.kind == LocationItemKind.event) {
      final row =
          await (database.select(database.calendarEvents)..where(
                (r) =>
                    r.id.equals(item.itemId) &
                    r.accountId.equals(item.accountId) &
                    r.calendarSourceId.equals(item.sourceId) &
                    r.isDeleted.equals(false),
              ))
              .getSingleOrNull();
      return row != null && (row.location ?? '') == location;
    }
    final row =
        await (database.select(database.tasks)..where(
              (r) =>
                  r.id.equals(item.itemId) &
                  r.accountId.equals(item.accountId) &
                  r.taskListId.equals(item.sourceId) &
                  r.pendingDelete.equals(false),
            ))
            .getSingleOrNull();
    return row != null && (row.taskLocation ?? '') == location;
  }

  /// Called after the replacement row exists and before its predecessor is
  /// deleted. The latest replacement location must still match the snapshot.
  Future<void> transfer(
    LocationItemIdentity from,
    LocationItemIdentity to,
  ) async {
    final old = await (database.select(
      database.locationResolutions,
    )..where((r) => _owner(r, from))).getSingleOrNull();
    if (old == null) return;
    final result = await load(from, old.locationText);
    if (result != null) {
      await apply(to, old.locationText, LocationChange.replace(result));
    }
  }

  /// Promotes an exact supplemental point on a synchronized Google master to
  /// provider-series identity before the display-only master is retired.
  Future<void> reconcileGoogleSeriesMaster(CalendarEvent master) async {
    if (master.provider != 'google' ||
        master.providerRecurringEventId != null) {
      return;
    }
    final providerSeriesId = master.providerEventId;
    final seriesOwner = _googleSeriesOwner(
      accountId: master.accountId,
      sourceId: master.calendarSourceId,
      providerSeriesId: providerSeriesId,
    );
    final existing = await (database.select(
      database.locationResolutions,
    )..where(seriesOwner)).getSingleOrNull();
    if (master.isDeleted ||
        master.isCancelled ||
        master.recurrenceJson == null) {
      if (existing != null) {
        await (database.delete(
          database.locationResolutions,
        )..where(seriesOwner)).go();
      }
      return;
    }
    final location = master.location ?? '';
    final exact = await load(
      LocationItemIdentity(
        kind: LocationItemKind.event,
        accountId: master.accountId,
        sourceId: master.calendarSourceId,
        itemId: master.id,
      ),
      location,
    );
    if (exact == null) {
      if (existing != null && existing.locationText != location) {
        await (database.delete(
          database.locationResolutions,
        )..where(seriesOwner)).go();
      }
      return;
    }
    await database
        .into(database.locationResolutions)
        .insertOnConflictUpdate(
          LocationResolutionsCompanion.insert(
            kind: googleSeriesLocationResolutionKind,
            accountId: master.accountId,
            sourceId: master.calendarSourceId,
            itemId: providerSeriesId,
            locationText: location,
            label: exact.label,
            latitude: exact.point.latitude,
            longitude: exact.point.longitude,
            source: exact.source,
            attribution: exact.attribution,
          ),
        );
  }

  Future<void> transferGoogleSeriesSource({
    required String fromAccountId,
    required String fromSourceId,
    required String fromProviderSeriesId,
    required String toAccountId,
    required String toSourceId,
    required String toProviderSeriesId,
  }) async {
    final fromOwner = _googleSeriesOwner(
      accountId: fromAccountId,
      sourceId: fromSourceId,
      providerSeriesId: fromProviderSeriesId,
    );
    final existing = await (database.select(
      database.locationResolutions,
    )..where(fromOwner)).getSingleOrNull();
    if (existing == null) return;
    await database
        .into(database.locationResolutions)
        .insertOnConflictUpdate(
          LocationResolutionsCompanion.insert(
            kind: googleSeriesLocationResolutionKind,
            accountId: toAccountId,
            sourceId: toSourceId,
            itemId: toProviderSeriesId,
            locationText: existing.locationText,
            label: existing.label,
            latitude: existing.latitude,
            longitude: existing.longitude,
            source: existing.source,
            attribution: existing.attribution,
          ),
        );
    if (fromAccountId != toAccountId ||
        fromSourceId != toSourceId ||
        fromProviderSeriesId != toProviderSeriesId) {
      await (database.delete(
        database.locationResolutions,
      )..where(fromOwner)).go();
    }
  }

  /// Copies a supplemental point when a provider split leaves both series
  /// alive. The saved location snapshot must match the server-confirmed new
  /// series location; the original series remains its own owner.
  Future<void> copyGoogleSeriesSource({
    required String accountId,
    required String sourceId,
    required String fromProviderSeriesId,
    required String toProviderSeriesId,
    required String expectedLocation,
  }) async {
    final existing =
        await (database.select(database.locationResolutions)..where(
              _googleSeriesOwner(
                accountId: accountId,
                sourceId: sourceId,
                providerSeriesId: fromProviderSeriesId,
              ),
            ))
            .getSingleOrNull();
    if (existing == null || existing.locationText != expectedLocation) return;
    await database
        .into(database.locationResolutions)
        .insertOnConflictUpdate(
          LocationResolutionsCompanion.insert(
            kind: googleSeriesLocationResolutionKind,
            accountId: accountId,
            sourceId: sourceId,
            itemId: toProviderSeriesId,
            locationText: existing.locationText,
            label: existing.label,
            latitude: existing.latitude,
            longitude: existing.longitude,
            source: existing.source,
            attribution: existing.attribution,
          ),
        );
  }

  /// Invalidates a series point only after the provider confirms that the
  /// series now has a different effective location.
  Future<void> removeGoogleSeriesSourceUnlessLocationMatches({
    required String accountId,
    required String sourceId,
    required String providerSeriesId,
    required String expectedLocation,
  }) =>
      (database.delete(database.locationResolutions)..where(
            (row) =>
                _googleSeriesOwner(
                  accountId: accountId,
                  sourceId: sourceId,
                  providerSeriesId: providerSeriesId,
                )(row) &
                row.locationText.equals(expectedLocation).not(),
          ))
          .go();

  Future<void> removeGoogleSeriesSource({
    required String accountId,
    required String sourceId,
    required String providerSeriesId,
  }) =>
      (database.delete(database.locationResolutions)..where(
            _googleSeriesOwner(
              accountId: accountId,
              sourceId: sourceId,
              providerSeriesId: providerSeriesId,
            ),
          ))
          .go();

  Future<void> removeGoogleSeriesSourcesForCalendar({
    required String accountId,
    required String sourceId,
  }) =>
      (database.delete(database.locationResolutions)..where(
            (row) =>
                row.kind.equals(googleSeriesLocationResolutionKind) &
                row.accountId.equals(accountId) &
                row.sourceId.equals(sourceId),
          ))
          .go();

  Expression<bool> Function($LocationResolutionsTable) _googleSeriesOwner({
    required String accountId,
    required String sourceId,
    required String providerSeriesId,
  }) =>
      (row) =>
          row.kind.equals(googleSeriesLocationResolutionKind) &
          row.accountId.equals(accountId) &
          row.sourceId.equals(sourceId) &
          row.itemId.equals(providerSeriesId);

  Future<List<RememberedLocationSnapshot>> capture({
    required String accountId,
    String? davObjectId,
    String? eventSourceId,
  }) async {
    final davScope = davObjectId?.trim();
    final sourceScope = eventSourceId?.trim();
    if ((davScope == null || davScope.isEmpty) ==
        (sourceScope == null || sourceScope.isEmpty)) {
      throw ArgumentError(
        'Exactly one nonempty DAV object or event source is required.',
      );
    }
    final snapshots = <RememberedLocationSnapshot>[];
    final resolutions = database.locationResolutions;
    final events = database.calendarEvents;
    final eventQuery = database.select(resolutions).join([
      innerJoin(
        events,
        events.id.equalsExp(resolutions.itemId) &
            events.accountId.equalsExp(resolutions.accountId) &
            events.calendarSourceId.equalsExp(resolutions.sourceId),
      ),
    ]);
    eventQuery.where(
      resolutions.kind.equals(LocationItemKind.event.name) &
          resolutions.accountId.equals(accountId) &
          events.accountId.equals(accountId) &
          events.isDeleted.equals(false) &
          (davScope != null
              ? events.davObjectId.equals(davScope)
              : events.calendarSourceId.equals(sourceScope!)),
    );
    for (final joined in await eventQuery.get()) {
      final stored = joined.readTable(resolutions);
      final event = joined.readTable(events);
      if (stored.locationText != (event.location ?? '')) continue;
      final selection = _selection(stored);
      if (selection == null) continue;
      snapshots.add(
        RememberedLocationSnapshot(
          LocationItemIdentity(
            kind: LocationItemKind.event,
            accountId: event.accountId,
            sourceId: event.calendarSourceId,
            itemId: event.id,
          ),
          stored.locationText,
          selection,
          event.icalUid,
          event.providerRecurringEventId == null
              ? event.recurrenceIdKey
              : event.occurrenceKey,
          projectionAnchorUtc: _eventProjectionAnchorUtc(event),
        ),
      );
    }
    if (davScope != null) {
      final tasks = database.tasks;
      final taskQuery = database.select(resolutions).join([
        innerJoin(
          tasks,
          tasks.id.equalsExp(resolutions.itemId) &
              tasks.accountId.equalsExp(resolutions.accountId) &
              tasks.taskListId.equalsExp(resolutions.sourceId),
        ),
      ]);
      taskQuery.where(
        resolutions.kind.equals(LocationItemKind.task.name) &
            resolutions.accountId.equals(accountId) &
            tasks.accountId.equals(accountId) &
            tasks.davObjectId.equals(davScope) &
            tasks.pendingDelete.equals(false),
      );
      for (final joined in await taskQuery.get()) {
        final stored = joined.readTable(resolutions);
        final task = joined.readTable(tasks);
        if (stored.locationText != (task.taskLocation ?? '')) continue;
        final selection = _selection(stored);
        if (selection == null) continue;
        snapshots.add(
          RememberedLocationSnapshot(
            LocationItemIdentity(
              kind: LocationItemKind.task,
              accountId: task.accountId,
              sourceId: task.taskListId,
              itemId: task.id,
            ),
            stored.locationText,
            selection,
            task.icalUid,
            task.recurrenceIdKey,
          ),
        );
      }
    }
    return snapshots;
  }

  DateTime? _eventProjectionAnchorUtc(CalendarEvent event) {
    final raw = event.rawJson;
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          final startUtc = decoded['startUtc'];
          if (startUtc is String) {
            final parsed = DateTime.tryParse(startUtc);
            if (parsed != null) return parsed.toUtc();
          }
        }
      } on FormatException {
        // Fall through to the projected storage value.
      }
    }
    final stored = event.startDateTime ?? event.startDate;
    if (stored == null || stored.isEmpty) return null;
    final parsed = DateTime.tryParse(stored);
    if (parsed == null) return null;
    if (parsed.isUtc) return parsed.toUtc();
    // Floating and all-day values have no absolute instant. Treat their wall
    // value as UTC; the replacement range adds a full-day safety margin.
    return DateTime.utc(
      parsed.year,
      parsed.month,
      parsed.day,
      parsed.hour,
      parsed.minute,
      parsed.second,
      parsed.millisecond,
      parsed.microsecond,
    );
  }

  Future<void> restore(
    List<RememberedLocationSnapshot> snapshots, {
    required String accountId,
    required String sourceId,
    String? davObjectId,
  }) async {
    if (accountId.trim().isEmpty || sourceId.trim().isEmpty) {
      throw ArgumentError(
        'A nonempty destination account and source are required.',
      );
    }
    if (snapshots.isEmpty) return;
    final eventSnapshots = snapshots
        .where((saved) => saved.item.kind == LocationItemKind.event)
        .toList();
    if (eventSnapshots.isNotEmpty) {
      final rows =
          await (database.select(database.calendarEvents)..where(
                (r) =>
                    r.accountId.equals(accountId) &
                    r.calendarSourceId.equals(sourceId) &
                    r.isDeleted.equals(false) &
                    (davObjectId == null
                        ? const Constant(true)
                        : r.davObjectId.equals(davObjectId)),
              ))
              .get();
      for (final saved in eventSnapshots) {
        final exact =
            saved.item.accountId == accountId && saved.item.sourceId == sourceId
            ? rows.where((row) => row.id == saved.item.itemId).toList()
            : const <CalendarEvent>[];
        final stable = saved.uid == null
            ? const <CalendarEvent>[]
            : rows
                  .where(
                    (row) =>
                        row.icalUid == saved.uid &&
                        (row.providerRecurringEventId == null
                                ? row.recurrenceIdKey
                                : row.occurrenceKey) ==
                            saved.occurrence,
                  )
                  .toList();
        final matches = exact.isNotEmpty ? exact : stable;
        if (matches.length != 1) continue;
        final row = matches.single;
        await apply(
          LocationItemIdentity(
            kind: LocationItemKind.event,
            accountId: row.accountId,
            sourceId: row.calendarSourceId,
            itemId: row.id,
          ),
          saved.location,
          LocationChange.replace(saved.selection),
        );
      }
    }
    final taskSnapshots = snapshots
        .where((saved) => saved.item.kind == LocationItemKind.task)
        .toList();
    if (taskSnapshots.isNotEmpty) {
      final rows =
          await (database.select(database.tasks)..where(
                (r) =>
                    r.accountId.equals(accountId) &
                    r.taskListId.equals(sourceId) &
                    r.pendingDelete.equals(false) &
                    (davObjectId == null
                        ? const Constant(true)
                        : r.davObjectId.equals(davObjectId)),
              ))
              .get();
      for (final saved in taskSnapshots) {
        final exact =
            saved.item.accountId == accountId && saved.item.sourceId == sourceId
            ? rows.where((row) => row.id == saved.item.itemId).toList()
            : const <Task>[];
        final stable = saved.uid == null
            ? const <Task>[]
            : rows
                  .where(
                    (row) =>
                        row.icalUid == saved.uid &&
                        row.recurrenceIdKey == saved.occurrence,
                  )
                  .toList();
        final matches = exact.isNotEmpty ? exact : stable;
        if (matches.length != 1) continue;
        final row = matches.single;
        await apply(
          LocationItemIdentity(
            kind: LocationItemKind.task,
            accountId: row.accountId,
            sourceId: row.taskListId,
            itemId: row.id,
          ),
          saved.location,
          LocationChange.replace(saved.selection),
        );
      }
    }
  }

  LocationResult? _selection(LocationResolution row) {
    final point = GeographicPoint.tryParse(
      latitude: row.latitude,
      longitude: row.longitude,
    );
    return point == null
        ? null
        : LocationResult(
            label: row.label,
            point: point,
            source: row.source,
            attribution: row.attribution,
          );
  }
}

final class RememberedLocationSnapshot {
  const RememberedLocationSnapshot(
    this.item,
    this.location,
    this.selection,
    this.uid,
    this.occurrence, {
    this.projectionAnchorUtc,
  });
  final LocationItemIdentity item;
  final String location;
  final LocationResult selection;
  final String? uid;
  final String? occurrence;
  final DateTime? projectionAnchorUtc;
}

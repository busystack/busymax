import 'package:drift/drift.dart';

import '../../../db/app_database.dart';
import '../domain/geographic_point.dart';
import '../domain/location_result.dart';

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
    if (row == null ||
        row.locationText != location ||
        !await _current(item, location)) {
      return null;
    }
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

  Future<List<RememberedLocationSnapshot>> capture({
    String? davObjectId,
    String? eventSourceId,
  }) async {
    final snapshots = <RememberedLocationSnapshot>[];
    for (final event
        in await (database.select(database.calendarEvents)..where(
              (r) => davObjectId != null
                  ? r.davObjectId.equals(davObjectId)
                  : r.calendarSourceId.equals(eventSourceId!),
            ))
            .get()) {
      final item = LocationItemIdentity(
        kind: LocationItemKind.event,
        accountId: event.accountId,
        sourceId: event.calendarSourceId,
        itemId: event.id,
      );
      final selection = await load(item, event.location ?? '');
      if (selection != null) {
        snapshots.add(
          RememberedLocationSnapshot(
            item,
            event.location ?? '',
            selection,
            event.icalUid,
            event.providerRecurringEventId == null ? null : event.occurrenceKey,
          ),
        );
      }
    }
    if (davObjectId != null) {
      for (final task in await (database.select(
        database.tasks,
      )..where((r) => r.davObjectId.equals(davObjectId))).get()) {
        final item = LocationItemIdentity(
          kind: LocationItemKind.task,
          accountId: task.accountId,
          sourceId: task.taskListId,
          itemId: task.id,
        );
        final selection = await load(item, task.taskLocation ?? '');
        if (selection != null) {
          snapshots.add(
            RememberedLocationSnapshot(
              item,
              task.taskLocation ?? '',
              selection,
              task.icalUid,
              task.recurrenceIdKey,
            ),
          );
        }
      }
    }
    return snapshots;
  }

  Future<void> restore(
    List<RememberedLocationSnapshot> snapshots, {
    String? accountId,
    String? sourceId,
  }) async {
    for (final saved in snapshots) {
      final owner = saved.item;
      if (owner.kind == LocationItemKind.event) {
        final rows =
            await (database.select(database.calendarEvents)..where(
                  (r) =>
                      r.accountId.equals(accountId ?? owner.accountId) &
                      r.calendarSourceId.equals(sourceId ?? owner.sourceId) &
                      r.isDeleted.equals(false),
                ))
                .get();
        for (final row in rows) {
          if (row.id == owner.itemId ||
              (saved.uid != null &&
                  row.icalUid == saved.uid &&
                  (row.providerRecurringEventId == null
                          ? null
                          : row.occurrenceKey) ==
                      saved.occurrence)) {
            await apply(
              LocationItemIdentity(
                kind: owner.kind,
                accountId: row.accountId,
                sourceId: row.calendarSourceId,
                itemId: row.id,
              ),
              saved.location,
              LocationChange.replace(saved.selection),
            );
          }
        }
      } else {
        final rows =
            await (database.select(database.tasks)..where(
                  (r) =>
                      r.accountId.equals(accountId ?? owner.accountId) &
                      r.taskListId.equals(sourceId ?? owner.sourceId) &
                      r.pendingDelete.equals(false),
                ))
                .get();
        for (final row in rows) {
          if (row.id == owner.itemId ||
              (saved.uid != null &&
                  row.icalUid == saved.uid &&
                  row.recurrenceIdKey == saved.occurrence)) {
            await apply(
              LocationItemIdentity(
                kind: owner.kind,
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
    }
  }
}

final class RememberedLocationSnapshot {
  const RememberedLocationSnapshot(
    this.item,
    this.location,
    this.selection,
    this.uid,
    this.occurrence,
  );
  final LocationItemIdentity item;
  final String location;
  final LocationResult selection;
  final String? uid;
  final String? occurrence;
}

import 'dart:convert';

import 'package:drift/drift.dart';

import '../dav/ical/ical_recurrence.dart';
import '../dav/ical/ical_semantics.dart';
import '../features/maps/domain/geographic_point.dart';
import 'app_database.dart';

Future<void> migrateLocationData(Migrator migrator, AppDatabase db) async {
  // Older migrations may already rebuild a table using today's definition.
  for (final table in ['calendar_events', 'tasks']) {
    final columns = await db.customSelect('PRAGMA table_info($table)').get();
    for (final name in ['location_latitude', 'location_longitude']) {
      if (!columns.any((row) => row.read<String>('name') == name)) {
        await db.customStatement('ALTER TABLE $table ADD COLUMN $name REAL NULL');
      }
    }
  }
  await migrator.createTable(db.locationResolutions);
  // Reproject only native values. This never geocodes or changes sync state.
  final documents = {for (final row in await db.select(db.davObjects).get()) row.id: row.rawIcsBody};
  final feeds = {for (final row in await db.select(db.webCalSubscriptions).get()) row.calendarSourceId: row.snapshotIcsBody};
  for (final row in await db.select(db.calendarEvents).get()) {
    GeographicPoint? point;
    try {
      final raw = jsonDecode(row.rawJson ?? '{}');
      if (row.provider == 'microsoft' && raw is Map && raw['location'] is Map) {
        point = GeographicPoint.fromJson((raw['location'] as Map)['coordinates']);
      } else {
        point = _icalPoint(documents[row.davObjectId] ?? feeds[row.calendarSourceId], row.icalUid, row.recurrenceIdKey, row.occurrenceKey);
      }
    } on Object { /* Malformed location data must not reject its owner. */ }
    await (db.update(db.calendarEvents)..where((r) => r.id.equals(row.id))).write(CalendarEventsCompanion(locationLatitude: Value(point?.latitude), locationLongitude: Value(point?.longitude)));
  }
  for (final row in await db.select(db.tasks).get()) {
    final point = _icalPoint(documents[row.davObjectId], row.icalUid, row.recurrenceIdKey, row.recurrenceIdKey);
    await (db.update(db.tasks)..where((r) => r.accountId.equals(row.accountId) & r.taskListId.equals(row.taskListId) & r.id.equals(row.id))).write(TasksCompanion(locationLatitude: Value(point?.latitude), locationLongitude: Value(point?.longitude)));
  }
}

GeographicPoint? _icalPoint(String? text, String? uid, String? recurrence, String? occurrence) {
  if (text == null) return null;
  try {
    final components = IcalSemanticDocument.parse(text).components.where((c) => c.uid == uid).toList();
    IcalSemanticComponent? master, exact, inherited;
    for (final c in components) {
      if (c.recurrenceIdKey == null) master = c;
      if (recurrence != null && c.recurrenceIdKey == recurrence) exact = c;
      if (occurrence != null && c.recurrenceRange == 'THISANDFUTURE' && c.recurrenceIdKey != null && c.recurrenceIdKey!.compareTo(occurrence) <= 0 && (inherited == null || c.recurrenceIdKey!.compareTo(inherited.recurrenceIdKey!) > 0)) inherited = c;
    }
    return effectiveIcalLocationPoint([exact, inherited, master]);
  } on Object { return null; }
}

/// SQLite guards all update paths, including sync and account/list deletion.
/// Reprojection and replacement flows explicitly transfer valid associations.
Future<void> createLocationLifecycleTriggers(AppDatabase db) async {
  for (final (kind, table, source, location, deleted) in [
    ('event', 'calendar_events', 'calendar_source_id', 'location', 'is_deleted'),
    ('task', 'tasks', 'task_list_id', 'task_location', 'pending_delete'),
  ]) {
    final owner = "kind = '$kind' AND account_id = OLD.account_id AND source_id = OLD.$source AND item_id = OLD.id";
    await db.customStatement('CREATE TRIGGER IF NOT EXISTS location_${kind}_delete AFTER DELETE ON $table BEGIN DELETE FROM location_resolutions WHERE $owner; END');
    await db.customStatement('CREATE TRIGGER IF NOT EXISTS location_${kind}_invalidate AFTER UPDATE OF $location, $deleted ON $table WHEN NEW.$location IS NOT OLD.$location OR NEW.$deleted = 1 BEGIN DELETE FROM location_resolutions WHERE $owner; END');
    await db.customStatement('CREATE TRIGGER IF NOT EXISTS location_${kind}_identity AFTER UPDATE OF id, account_id, $source ON $table BEGIN UPDATE OR REPLACE location_resolutions SET account_id = NEW.account_id, source_id = NEW.$source, item_id = NEW.id WHERE $owner; END');
  }
}

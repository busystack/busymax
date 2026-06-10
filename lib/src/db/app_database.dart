import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'migrations.dart';
import 'tables.dart';

part 'app_database.g.dart';
part 'daos/pending_ops_dao.dart';
part 'daos/sync_runs_dao.dart';
part 'daos/task_lists_dao.dart';
part 'daos/tasks_dao.dart';

@DriftDatabase(
  tables: [
    Accounts,
    TaskLists,
    Tasks,
    PendingOps,
    SyncRuns,
    CalendarSources,
    CalendarEvents,
    CalendarEventAttendees,
    CalendarEventReminders,
    CalendarSyncStates,
    CalendarColors,
    ScheduleItemOverrides,
    NotificationSchedule,
  ],
  daos: [TaskListsDao, TasksDao, PendingOpsDao, SyncRunsDao],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  factory AppDatabase.open() => AppDatabase(openBusyMaxDatabase());

  @override
  int get schemaVersion => latestSchemaVersion;

  @override
  MigrationStrategy get migration => busyMaxMigrationStrategy(this);
}

LazyDatabase openBusyMaxDatabase() {
  return LazyDatabase(() async {
    final dir = await getApplicationSupportDirectory();
    final file = File(p.join(dir.path, 'busymax.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}

import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';

import 'native_database_connection.dart';

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
    OAuthTransitionAccounts,
    AccountAuthorizations,
    AuthorizationCommits,
    AuthorizationGenerations,
    DomainSyncSchedules,
    DavAccountServices,
    DavCollectionCreations,
    DavCollectionCreationAcknowledgments,
    DavCollections,
    DavObjects,
    DavObjectComponents,
    DavConflictSnapshots,
    TaskLists,
    Tasks,
    PendingOps,
    SyncRuns,
    CalendarSources,
    CalendarEvents,
    IcalImportReceipts,
    WebCalSubscriptions,
    CalendarEventAttendees,
    CalendarEventReminders,
    SyncCursors,
    CalendarColors,
    ScheduleItemOverrides,
    NotificationSchedule,
    AndroidNotificationMappings,
    AndroidDailySummarySchedules,
    NotificationIssues,
    DailySummaryHistory,
    LocationResolutions,
  ],
  daos: [TaskListsDao, TasksDao, PendingOpsDao, SyncRunsDao],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor, {this.notificationSynchronization});

  /// Lock order on Android: account/authorization lease, notification gate,
  /// then a SQLite transaction. Callers finish data transactions before asking
  /// for a notification rebuild. Other platforms retain their existing path.
  final Future<T> Function<T>(Future<T> Function())?
  notificationSynchronization;

  Future<T> synchronizeNotifications<T>(Future<T> Function() operation) =>
      notificationSynchronization?.call<T>(operation) ?? operation();

  factory AppDatabase.open({
    Future<T> Function<T>(Future<T> Function())? notificationSynchronization,
  }) => AppDatabase(
    openBusyMaxDatabase(),
    notificationSynchronization: notificationSynchronization,
  );

  factory AppDatabase.memoryForTests() => AppDatabase(
    DatabaseConnection(
      NativeDatabase.memory(),
      closeStreamsSynchronously: true,
    ),
  );

  @override
  int get schemaVersion => latestSchemaVersion;

  @override
  MigrationStrategy get migration => busyMaxMigrationStrategy(this);
}

LazyDatabase openBusyMaxDatabase() {
  return LazyDatabase(() async {
    final dir = await getApplicationSupportDirectory();
    final file = File(p.join(dir.path, 'busymax.sqlite'));
    return openNativeDatabase(file, android: Platform.isAndroid);
  });
}

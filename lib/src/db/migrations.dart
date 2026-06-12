import 'package:drift/drift.dart';

import 'app_database.dart';

const latestSchemaVersion = 5;

MigrationStrategy busyMaxMigrationStrategy(AppDatabase database) {
  return MigrationStrategy(
    onCreate: (migrator) async {
      await migrator.createAll();
      await _createIndexes(database);
    },
    onUpgrade: (migrator, from, to) async {
      if (from < 2 && await _hasTable(database, 'pending_ops')) {
        await migrator.addColumn(
          database.pendingOps,
          database.pendingOps.baselineRawJson,
        );
      }
      if (from < 3) {
        await _addV3Columns(migrator, database);
      }
      if (from < 4) {
        await _addV4CalendarTables(migrator, database);
      }
      if (from >= 4 && from < 5) {
        await _addV5CalendarEventCategories(migrator, database);
      }
      await _createIndexes(database);
    },
    beforeOpen: (details) async {
      await database.customStatement('PRAGMA foreign_keys = ON');
    },
  );
}

Future<void> _addV4CalendarTables(
  Migrator migrator,
  AppDatabase database,
) async {
  if (await _hasTable(database, 'accounts')) {
    await migrator.addColumn(
      database.accounts,
      database.accounts.calendarsEnabled,
    );
    await migrator.addColumn(database.accounts, database.accounts.tasksEnabled);
  }
  if (await _hasTable(database, 'pending_ops')) {
    await migrator.addColumn(
      database.pendingOps,
      database.pendingOps.operationType,
    );
    await migrator.addColumn(
      database.pendingOps,
      database.pendingOps.calendarSourceId,
    );
    await migrator.addColumn(
      database.pendingOps,
      database.pendingOps.providerCalendarId,
    );
    await migrator.addColumn(database.pendingOps, database.pendingOps.eventId);
    await migrator.addColumn(database.pendingOps, database.pendingOps.state);
    await migrator.addColumn(
      database.pendingOps,
      database.pendingOps.lastError,
    );
  }
  await migrator.createTable(database.calendarSources);
  await migrator.createTable(database.calendarEvents);
  await migrator.createTable(database.calendarEventAttendees);
  await migrator.createTable(database.calendarEventReminders);
  await migrator.createTable(database.calendarSyncStates);
  await migrator.createTable(database.calendarColors);
  await migrator.createTable(database.scheduleItemOverrides);
  await migrator.createTable(database.notificationSchedule);
}

Future<void> _addV5CalendarEventCategories(
  Migrator migrator,
  AppDatabase database,
) async {
  if (await _hasTable(database, 'calendar_events')) {
    await migrator.addColumn(
      database.calendarEvents,
      database.calendarEvents.categoriesJson,
    );
  }
}

Future<void> _addV3Columns(Migrator migrator, AppDatabase database) async {
  if (await _hasTable(database, 'accounts')) {
    await migrator.addColumn(database.accounts, database.accounts.provider);
    await migrator.addColumn(
      database.accounts,
      database.accounts.providerAccountId,
    );
    await migrator.addColumn(database.accounts, database.accounts.email);
    await migrator.addColumn(database.accounts, database.accounts.tenantId);
    await migrator.addColumn(
      database.accounts,
      database.accounts.accountAvatarUrl,
    );
    await migrator.addColumn(
      database.accounts,
      database.accounts.providerMetadataJson,
    );
  }

  if (await _hasTable(database, 'task_lists')) {
    await migrator.addColumn(
      database.taskLists,
      database.taskLists.providerListKind,
    );
    await migrator.addColumn(database.taskLists, database.taskLists.isOwner);
    await migrator.addColumn(database.taskLists, database.taskLists.isShared);
    await migrator.addColumn(database.taskLists, database.taskLists.deltaLink);
    await migrator.addColumn(
      database.taskLists,
      database.taskLists.providerMetadataJson,
    );
  }

  if (await _hasTable(database, 'tasks')) {
    await migrator.addColumn(database.tasks, database.tasks.providerStatus);
    await migrator.addColumn(database.tasks, database.tasks.bodyContent);
    await migrator.addColumn(database.tasks, database.tasks.bodyContentType);
    await migrator.addColumn(
      database.tasks,
      database.tasks.microsoftDueDateTime,
    );
    await migrator.addColumn(
      database.tasks,
      database.tasks.microsoftDueTimeZone,
    );
    await migrator.addColumn(
      database.tasks,
      database.tasks.microsoftStartDateTime,
    );
    await migrator.addColumn(
      database.tasks,
      database.tasks.microsoftStartTimeZone,
    );
    await migrator.addColumn(
      database.tasks,
      database.tasks.microsoftReminderDateTime,
    );
    await migrator.addColumn(
      database.tasks,
      database.tasks.microsoftReminderTimeZone,
    );
    await migrator.addColumn(
      database.tasks,
      database.tasks.microsoftIsReminderOn,
    );
    await migrator.addColumn(
      database.tasks,
      database.tasks.microsoftCompletedDateTime,
    );
    await migrator.addColumn(
      database.tasks,
      database.tasks.microsoftCompletedTimeZone,
    );
    await migrator.addColumn(database.tasks, database.tasks.recurrenceJson);
    await migrator.addColumn(database.tasks, database.tasks.importance);
    await migrator.addColumn(database.tasks, database.tasks.categoriesJson);
    await migrator.addColumn(database.tasks, database.tasks.hasAttachments);
    await migrator.addColumn(
      database.tasks,
      database.tasks.providerMetadataJson,
    );
  }

  if (await _hasTable(database, 'pending_ops')) {
    await migrator.addColumn(database.pendingOps, database.pendingOps.provider);
  }
  if (await _hasTable(database, 'sync_runs')) {
    await migrator.addColumn(database.syncRuns, database.syncRuns.provider);
  }
}

Future<void> _createIndexes(AppDatabase database) async {
  if (await _hasTable(database, 'accounts')) {
    await database.customStatement(
      'CREATE INDEX IF NOT EXISTS idx_accounts_provider '
      'ON accounts(provider)',
    );
    await database.customStatement(
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_accounts_provider_account '
      'ON accounts(provider, provider_account_id) '
      'WHERE provider_account_id IS NOT NULL',
    );
  }
  if (await _hasTable(database, 'task_lists')) {
    await database.customStatement(
      'CREATE INDEX IF NOT EXISTS idx_task_lists_account_title '
      'ON task_lists(account_id, title COLLATE NOCASE)',
    );
    await database.customStatement(
      'CREATE INDEX IF NOT EXISTS idx_task_lists_dirty '
      'ON task_lists(account_id, local_dirty, pending_delete)',
    );
  }
  if (await _hasTable(database, 'tasks')) {
    await database.customStatement(
      'CREATE INDEX IF NOT EXISTS idx_tasks_list_order '
      'ON tasks(account_id, task_list_id, parent, position)',
    );
    await database.customStatement(
      'CREATE INDEX IF NOT EXISTS idx_tasks_status_due '
      'ON tasks(account_id, task_list_id, status, due_utc)',
    );
    await database.customStatement(
      'CREATE INDEX IF NOT EXISTS idx_tasks_dirty '
      'ON tasks(account_id, local_dirty, pending_delete, pending_move)',
    );
    await database.customStatement(
      'CREATE INDEX IF NOT EXISTS idx_tasks_updated '
      'ON tasks(account_id, task_list_id, updated_utc)',
    );
  }
  if (await _hasTable(database, 'calendar_sources')) {
    await database.customStatement(
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_calendar_sources_provider_id '
      'ON calendar_sources(account_id, provider, provider_calendar_id)',
    );
    await database.customStatement(
      'CREATE INDEX IF NOT EXISTS idx_calendar_sources_visible '
      'ON calendar_sources(account_id, selected, hidden, is_deleted)',
    );
  }
  if (await _hasTable(database, 'calendar_events')) {
    await database.customStatement(
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_calendar_events_provider_id '
      'ON calendar_events(account_id, provider, provider_calendar_id, '
      'provider_event_id, provider_original_start_key)',
    );
    await database.customStatement(
      'CREATE INDEX IF NOT EXISTS idx_calendar_events_range '
      'ON calendar_events(account_id, calendar_source_id, all_day, '
      'start_date, start_date_time, end_date, end_date_time)',
    );
    await database.customStatement(
      'CREATE INDEX IF NOT EXISTS idx_calendar_events_dirty '
      'ON calendar_events(account_id, sync_status, is_deleted)',
    );
  }
  if (await _hasTable(database, 'calendar_sync_states')) {
    await database.customStatement(
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_calendar_sync_states_scope '
      'ON calendar_sync_states(account_id, provider, sync_kind, '
      'calendar_source_id, range_start, range_end)',
    );
  }
  if (await _hasTable(database, 'notification_schedule')) {
    await database.customStatement(
      'CREATE INDEX IF NOT EXISTS idx_notification_schedule_due '
      'ON notification_schedule(scheduled_at_utc, sent_at_utc, '
      'dismissed_at_utc, snoozed_until_utc)',
    );
  }
}

Future<bool> _hasTable(AppDatabase database, String tableName) async {
  final row = await database
      .customSelect(
        "SELECT name FROM sqlite_master WHERE type = 'table' AND name = ?",
        variables: [Variable<String>(tableName)],
      )
      .getSingleOrNull();
  return row != null;
}

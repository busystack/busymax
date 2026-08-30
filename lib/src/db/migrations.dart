import 'package:drift/drift.dart';

import 'app_database.dart';

const latestSchemaVersion = 13;

/// A recoverable, non-secret diagnostic raised when an on-disk schema cannot
/// be migrated without guessing remote identity or losing synchronized data.
final class BusyMaxMigrationException implements Exception {
  const BusyMaxMigrationException(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => 'BusyMaxMigrationException($code: $message)';
}

MigrationStrategy busyMaxMigrationStrategy(AppDatabase database) {
  return MigrationStrategy(
    onCreate: (migrator) async {
      await migrator.createAll();
      await _createIndexes(database);
      await _verifyForeignKeys(database);
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
      if (from < 6) {
        await _migrateToV6(migrator, database);
      }
      if (from < 7) {
        await _migrateToV7(migrator, database);
      }
      if (from < 8) {
        await _migrateToV8(migrator, database);
      }
      if (from < 9) {
        await _migrateToV9(migrator, database);
      }
      if (from < 10) {
        await _migrateToV10(migrator, database);
      }
      if (from < 11) {
        await _migrateToV11(migrator, database);
      }
      if (from < 12) {
        await _migrateToV12(migrator, database);
      }
      if (from < 13) {
        await _migrateToV13(migrator, database);
      }
      await _createIndexes(database);
      await _verifyForeignKeys(database);
    },
    beforeOpen: (details) async {
      await database.customStatement('PRAGMA foreign_keys = ON');
    },
  );
}

Future<void> _migrateToV13(Migrator migrator, AppDatabase database) async {
  await _verifyAccountIdentity(database);
  await migrator.alterTable(TableMigration(database.accounts));
  if (await _hasTable(database, 'web_cal_subscriptions')) {
    for (final column in [
      database.webCalSubscriptions.projectionRangeStartUtc,
      database.webCalSubscriptions.projectionRangeEndUtc,
    ]) {
      await _addColumnIfMissing(
        migrator,
        database,
        database.webCalSubscriptions,
        column,
      );
    }
  }
}

Future<void> _migrateToV12(Migrator migrator, AppDatabase database) async {
  await _addColumnIfMissing(
    migrator,
    database,
    database.taskLists,
    database.taskLists.remindersEnabled,
  );
}

Future<void> _migrateToV11(Migrator migrator, AppDatabase database) async {
  // Rebuild Accounts so SQLite adopts the extended provider and credential
  // constraints while preserving every existing row and identifier.
  await migrator.alterTable(TableMigration(database.accounts));
  await migrator.createTable(database.icalImportReceipts);
  await migrator.createTable(database.webCalSubscriptions);
}

Future<void> _migrateToV10(Migrator migrator, AppDatabase database) async {
  for (final column in [
    database.calendarSources.dataOwner,
    database.calendarSources.isRemovable,
  ]) {
    await _addColumnIfMissing(
      migrator,
      database,
      database.calendarSources,
      column,
    );
  }
}

Future<void> _migrateToV9(Migrator migrator, AppDatabase database) async {
  await _addColumnIfMissing(
    migrator,
    database,
    database.calendarSources,
    database.calendarSources.remindersEnabled,
  );
}

Future<void> _migrateToV8(Migrator migrator, AppDatabase database) async {
  await _addColumnIfMissing(
    migrator,
    database,
    database.tasks,
    database.tasks.microsoftChecklistItemsJson,
  );
}

Future<void> _migrateToV7(Migrator migrator, AppDatabase database) async {
  if (!await _hasTable(database, 'tasks')) return;
  for (final column in [
    database.tasks.taskLocation,
    database.tasks.taskUrl,
    database.tasks.taskClassification,
    database.tasks.taskPinned,
    database.tasks.taskHideSubtasks,
    database.tasks.taskHideCompletedSubtasks,
    database.tasks.taskAlarmsJson,
  ]) {
    await _addColumnIfMissing(migrator, database, database.tasks, column);
  }
}

Future<void> _migrateToV6(Migrator migrator, AppDatabase database) async {
  final preservedCounts = await _capturePreservedCounts(database);
  await _validateLegacyProviderValues(database);

  // The v5 index is intentionally removed before Drift's table rebuild so it
  // cannot be recreated against the new authority-aware account identity.
  await database.customStatement(
    'DROP INDEX IF EXISTS idx_accounts_provider_account',
  );
  await migrator.alterTable(
    TableMigration(
      database.accounts,
      newColumns: [
        database.accounts.authority,
        database.accounts.credentialKind,
        database.accounts.providerProfileVersion,
      ],
      columnTransformer: {
        database.accounts.provider: const CustomExpression<String>('provider'),
        database.accounts.authority: const CustomExpression<String>(
          'CASE provider '
          "WHEN 'google' THEN 'https://accounts.google.com' "
          "WHEN 'microsoft' THEN 'https://login.microsoftonline.com/' || "
          "lower(COALESCE(NULLIF(trim(tenant_id), ''), 'common')) "
          'END',
        ),
        database.accounts.providerAccountId: const CustomExpression<String>(
          "COALESCE(NULLIF(trim(provider_account_id), ''), id)",
        ),
        database.accounts.credentialKind: const CustomExpression<String>(
          "'oauth'",
        ),
        database.accounts.providerProfileVersion: const CustomExpression<int>(
          '1',
        ),
      },
    ),
  );

  await migrator.createTable(database.davAccountServices);
  await migrator.createTable(database.davCollections);
  await migrator.createTable(database.davObjects);
  await migrator.createTable(database.davObjectComponents);
  await migrator.createTable(database.davConflictSnapshots);

  await _addProjectionLinks(migrator, database);
  await _addDavPendingOperationColumns(migrator, database);
  await _migrateGenericCursors(migrator, database);

  await _verifyPreservedCounts(database, preservedCounts);
  await _verifyAccountIdentity(database);
}

Future<void> _addProjectionLinks(
  Migrator migrator,
  AppDatabase database,
) async {
  await _addColumnIfMissing(
    migrator,
    database,
    database.taskLists,
    database.taskLists.davCollectionId,
  );
  for (final column in [
    database.tasks.davCollectionId,
    database.tasks.davObjectId,
    database.tasks.davComponentId,
    database.tasks.icalUid,
    database.tasks.recurrenceIdKey,
    database.tasks.icalPriority,
    database.tasks.percentComplete,
    database.tasks.parentUid,
    database.tasks.sortOrder,
    database.tasks.providerExtensionProjectionJson,
    database.tasks.projectionVersion,
  ]) {
    await _addColumnIfMissing(migrator, database, database.tasks, column);
  }
  await _addColumnIfMissing(
    migrator,
    database,
    database.calendarSources,
    database.calendarSources.davCollectionId,
  );
  for (final column in [
    database.calendarEvents.davCollectionId,
    database.calendarEvents.davObjectId,
    database.calendarEvents.davComponentId,
    database.calendarEvents.icalUid,
    database.calendarEvents.recurrenceIdKey,
    database.calendarEvents.occurrenceKey,
    database.calendarEvents.projectionVersion,
  ]) {
    await _addColumnIfMissing(
      migrator,
      database,
      database.calendarEvents,
      column,
    );
  }
}

Future<void> _addDavPendingOperationColumns(
  Migrator migrator,
  AppDatabase database,
) async {
  for (final column in [
    database.pendingOps.davCollectionId,
    database.pendingOps.davCollectionHref,
    database.pendingOps.davObjectId,
    database.pendingOps.davMemberHref,
    database.pendingOps.baselineEtag,
    database.pendingOps.baselineRawIcs,
    database.pendingOps.mutationPatchJson,
    database.pendingOps.mutationPatchSchemaVersion,
    database.pendingOps.targetComponentKey,
    database.pendingOps.mutationScope,
    database.pendingOps.destinationCollectionId,
    database.pendingOps.destinationCollectionHref,
    database.pendingOps.destinationMemberHref,
    database.pendingOps.conflictState,
    database.pendingOps.conflictSnapshotId,
    database.pendingOps.retryClassification,
  ]) {
    await _addColumnIfMissing(migrator, database, database.pendingOps, column);
  }
}

Future<void> _migrateGenericCursors(
  Migrator migrator,
  AppDatabase database,
) async {
  await migrator.createTable(database.syncCursors);
  if (!await _hasTable(database, 'calendar_sync_states')) {
    return;
  }

  await database.customStatement('''
    INSERT INTO sync_cursors (
      id,
      account_id,
      projection_source_id,
      provider,
      transport,
      sync_scope_kind,
      dav_collection_id,
      cursor_kind,
      cursor_value,
      range_start,
      range_end,
      baseline_generation,
      in_progress_cursor,
      in_progress_generation,
      last_complete_sync_at,
      last_failure_code,
      state_schema_version,
      state_json
    )
    SELECT
      id,
      account_id,
      calendar_source_id,
      provider,
      'rest',
      sync_kind,
      NULL,
      CASE provider
        WHEN 'google' THEN
          CASE WHEN google_sync_token IS NULL
            THEN 'snapshot_generation' ELSE 'google_sync_token' END
        WHEN 'microsoft' THEN
          CASE WHEN microsoft_delta_link IS NULL
            THEN 'snapshot_generation' ELSE 'microsoft_delta_link' END
      END,
      COALESCE(google_sync_token, microsoft_delta_link, '0'),
      range_start,
      range_end,
      0,
      NULL,
      NULL,
      CASE
        WHEN last_incremental_sync_at IS NULL THEN last_full_sync_at
        WHEN last_full_sync_at IS NULL THEN last_incremental_sync_at
        WHEN last_incremental_sync_at >= last_full_sync_at
          THEN last_incremental_sync_at
        ELSE last_full_sync_at
      END,
      last_error,
      1,
      raw_state_json
    FROM calendar_sync_states
  ''');
  await migrator.deleteTable('calendar_sync_states');
}

Future<void> _validateLegacyProviderValues(AppDatabase database) async {
  const providerColumns = <(String, String, bool)>[
    ('accounts', 'provider', false),
    ('pending_ops', 'provider', true),
    ('sync_runs', 'provider', true),
    ('calendar_sources', 'provider', false),
    ('calendar_events', 'provider', false),
    ('calendar_event_reminders', 'provider', false),
    ('calendar_colors', 'provider', false),
    ('calendar_sync_states', 'provider', false),
  ];
  for (final (table, column, nullable) in providerColumns) {
    if (!await _hasTable(database, table) ||
        !await _hasColumn(database, table, column)) {
      continue;
    }
    final rows = await database
        .customSelect(
          'SELECT DISTINCT "$column" AS provider_value FROM "$table"',
        )
        .get();
    for (final row in rows) {
      final value = row.readNullable<String>('provider_value');
      if (nullable && value == null) {
        continue;
      }
      if (value != 'google' && value != 'microsoft') {
        throw BusyMaxMigrationException(
          'unsupported_provider_value',
          'Schema 5 contains an unsupported provider value in $table.',
        );
      }
    }
  }
}

Future<Map<String, int>> _capturePreservedCounts(AppDatabase database) async {
  const tables = [
    'accounts',
    'task_lists',
    'tasks',
    'pending_ops',
    'sync_runs',
    'calendar_sources',
    'calendar_events',
    'calendar_event_attendees',
    'calendar_event_reminders',
    'calendar_colors',
    'schedule_item_overrides',
    'notification_schedule',
  ];
  final counts = <String, int>{};
  for (final table in tables) {
    if (await _hasTable(database, table)) {
      counts[table] = await _tableCount(database, table);
    }
  }
  if (await _hasTable(database, 'calendar_sync_states')) {
    counts['sync_cursors'] = await _tableCount(
      database,
      'calendar_sync_states',
    );
  }
  return counts;
}

Future<void> _verifyPreservedCounts(
  AppDatabase database,
  Map<String, int> expected,
) async {
  for (final entry in expected.entries) {
    final actual = await _tableCount(database, entry.key);
    if (actual != entry.value) {
      throw BusyMaxMigrationException(
        'row_count_invariant_failed',
        'Migration row-count invariant failed for ${entry.key}.',
      );
    }
  }
}

Future<void> _verifyAccountIdentity(AppDatabase database) async {
  final invalid = await database.customSelect('''
    SELECT id FROM accounts
    WHERE provider NOT IN (
            'google', 'microsoft', 'apple_icloud', 'nextcloud', 'webcal'
          )
       OR trim(authority) = ''
       OR trim(provider_account_id) = ''
       OR NOT (
         (provider IN ('google', 'microsoft') AND credential_kind = 'oauth')
         OR (provider = 'apple_icloud' AND
             credential_kind = 'apple_app_specific_password')
         OR (provider = 'nextcloud' AND
             credential_kind = 'nextcloud_app_password')
         OR (provider = 'webcal' AND
             credential_kind = 'webcal_subscription')
       )
    LIMIT 1
  ''').getSingleOrNull();
  if (invalid != null) {
    throw const BusyMaxMigrationException(
      'account_identity_invariant_failed',
      'An account could not be assigned a strict remote identity.',
    );
  }

  final duplicate = await database.customSelect('''
    SELECT provider, authority, provider_account_id
    FROM accounts
    GROUP BY provider, authority, provider_account_id
    HAVING count(*) > 1
    LIMIT 1
  ''').getSingleOrNull();
  if (duplicate != null) {
    throw const BusyMaxMigrationException(
      'duplicate_remote_account_identity',
      'Multiple accounts map to the same provider authority and account ID.',
    );
  }
}

Future<void> _verifyForeignKeys(AppDatabase database) async {
  final violations = await database
      .customSelect('PRAGMA foreign_key_check')
      .get();
  if (violations.isNotEmpty) {
    throw const BusyMaxMigrationException(
      'foreign_key_check_failed',
      'The migrated database contains invalid foreign-key references.',
    );
  }
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
  await database.customStatement(_legacyCalendarSyncStatesSql);
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
    // These statements deliberately recreate the historical nullable/defaulted
    // v3 shape. The v6 table rebuild below then validates and tightens it.
    await database.customStatement(
      "ALTER TABLE accounts ADD COLUMN provider TEXT NOT NULL DEFAULT 'google'",
    );
    await database.customStatement(
      'ALTER TABLE accounts ADD COLUMN provider_account_id TEXT NULL',
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
    for (final column in [
      database.tasks.providerStatus,
      database.tasks.bodyContent,
      database.tasks.bodyContentType,
      database.tasks.microsoftDueDateTime,
      database.tasks.microsoftDueTimeZone,
      database.tasks.microsoftStartDateTime,
      database.tasks.microsoftStartTimeZone,
      database.tasks.microsoftReminderDateTime,
      database.tasks.microsoftReminderTimeZone,
      database.tasks.microsoftIsReminderOn,
      database.tasks.microsoftCompletedDateTime,
      database.tasks.microsoftCompletedTimeZone,
      database.tasks.recurrenceJson,
      database.tasks.importance,
      database.tasks.categoriesJson,
      database.tasks.hasAttachments,
      database.tasks.providerMetadataJson,
    ]) {
      await migrator.addColumn(database.tasks, column);
    }
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
    if (await _hasColumn(database, 'accounts', 'authority')) {
      await database.customStatement(
        'CREATE UNIQUE INDEX IF NOT EXISTS idx_accounts_remote_identity '
        'ON accounts(provider, authority, provider_account_id)',
      );
    }
  }
  if (await _hasTable(database, 'dav_collections')) {
    await database.customStatement(
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_dav_collections_href '
      'ON dav_collections(account_id, href_key)',
    );
    await database.customStatement(
      'CREATE INDEX IF NOT EXISTS idx_dav_collections_sync '
      'ON dav_collections(account_id, deleted, server_missing, last_sync_at_utc)',
    );
  }
  if (await _hasTable(database, 'dav_objects')) {
    await database.customStatement(
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_dav_objects_href '
      'ON dav_objects(collection_id, href_key)',
    );
    await database.customStatement(
      'CREATE INDEX IF NOT EXISTS idx_dav_objects_projection '
      'ON dav_objects(collection_id, server_deleted, parser_version, '
      'last_parse_status)',
    );
  }
  if (await _hasTable(database, 'dav_object_components')) {
    await database.customStatement(
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_dav_components_logical_key '
      'ON dav_object_components(dav_object_id, component_type, uid, '
      "IFNULL(recurrence_id_key, ''))",
    );
    await database.customStatement(
      'CREATE INDEX IF NOT EXISTS idx_dav_components_uid '
      'ON dav_object_components(component_type, uid, recurrence_id_key)',
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
    if (await _hasColumn(database, 'task_lists', 'dav_collection_id')) {
      await database.customStatement(
        'CREATE INDEX IF NOT EXISTS idx_task_lists_dav_collection '
        'ON task_lists(dav_collection_id)',
      );
    }
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
    if (await _hasColumn(database, 'tasks', 'dav_object_id')) {
      await database.customStatement(
        'CREATE INDEX IF NOT EXISTS idx_tasks_dav_component '
        'ON tasks(dav_object_id, dav_component_id, recurrence_id_key)',
      );
    }
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
    if (await _hasColumn(database, 'calendar_sources', 'dav_collection_id')) {
      await database.customStatement(
        'CREATE INDEX IF NOT EXISTS idx_calendar_sources_dav_collection '
        'ON calendar_sources(dav_collection_id)',
      );
    }
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
    if (await _hasColumn(database, 'calendar_events', 'dav_object_id')) {
      await database.customStatement(
        'CREATE INDEX IF NOT EXISTS idx_calendar_events_dav_occurrence '
        'ON calendar_events(dav_object_id, dav_component_id, occurrence_key)',
      );
    }
  }
  if (await _hasTable(database, 'sync_cursors')) {
    await database.customStatement(
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_sync_cursors_scope '
      'ON sync_cursors(account_id, provider, transport, sync_scope_kind, '
      "IFNULL(dav_collection_id, ''), IFNULL(projection_source_id, ''), "
      "cursor_kind, IFNULL(range_start, ''), IFNULL(range_end, ''))",
    );
  }
  if (await _hasTable(database, 'pending_ops') &&
      await _hasColumn(database, 'pending_ops', 'dav_collection_id')) {
    await database.customStatement(
      'CREATE INDEX IF NOT EXISTS idx_pending_ops_dav_replay '
      'ON pending_ops(account_id, dav_collection_id, state, '
      'next_attempt_at_utc, created_at_utc)',
    );
  }
  if (await _hasTable(database, 'notification_schedule')) {
    await database.customStatement(
      'CREATE INDEX IF NOT EXISTS idx_notification_schedule_due '
      'ON notification_schedule(scheduled_at_utc, sent_at_utc, '
      'dismissed_at_utc, snoozed_until_utc)',
    );
  }
  if (await _hasTable(database, 'web_cal_subscriptions')) {
    await database.customStatement(
      'CREATE INDEX IF NOT EXISTS idx_webcal_subscriptions_due '
      'ON web_cal_subscriptions(next_refresh_at_utc)',
    );
  }
}

Future<void> _addColumnIfMissing(
  Migrator migrator,
  AppDatabase database,
  TableInfo table,
  GeneratedColumn column,
) async {
  if (!await _hasTable(database, table.actualTableName)) {
    return;
  }
  if (!await _hasColumn(database, table.actualTableName, column.$name)) {
    await migrator.addColumn(table, column);
  }
}

Future<int> _tableCount(AppDatabase database, String tableName) async {
  final row = await database
      .customSelect('SELECT count(*) AS row_count FROM "$tableName"')
      .getSingle();
  return row.read<int>('row_count');
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

Future<bool> _hasColumn(
  AppDatabase database,
  String tableName,
  String columnName,
) async {
  final rows = await database
      .customSelect('PRAGMA table_info("$tableName")')
      .get();
  return rows.any((row) => row.read<String>('name') == columnName);
}

const _legacyCalendarSyncStatesSql = '''
  CREATE TABLE calendar_sync_states (
    id TEXT NOT NULL PRIMARY KEY,
    account_id TEXT NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
    calendar_source_id TEXT NULL REFERENCES calendar_sources(id)
      ON DELETE CASCADE,
    provider TEXT NOT NULL,
    sync_kind TEXT NOT NULL,
    range_start TEXT NULL,
    range_end TEXT NULL,
    google_sync_token TEXT NULL,
    microsoft_delta_link TEXT NULL,
    last_full_sync_at INTEGER NULL,
    last_incremental_sync_at INTEGER NULL,
    last_error TEXT NULL,
    raw_state_json TEXT NULL
  )
''';

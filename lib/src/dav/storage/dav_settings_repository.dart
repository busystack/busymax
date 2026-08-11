import 'dart:convert';

import 'package:drift/drift.dart';

import '../../db/app_database.dart';
import '../../features/accounts/domain/account_connection_state.dart';
import '../../features/tasks/domain/task_capabilities.dart';
import '../../providers/busy_provider.dart';
import '../../providers/provider_capabilities.dart';
import 'dav_collection_capabilities.dart';

final class DavCollectionSettingsEntity {
  const DavCollectionSettingsEntity({
    required this.id,
    required this.accountId,
    required this.provider,
    required this.accountLabel,
    required this.accountAuthority,
    required this.connectionState,
    required this.name,
    required this.color,
    required this.readOnly,
    required this.shared,
    required this.supportsEvents,
    required this.supportsTasks,
    required this.eventsSelected,
    required this.tasksSelected,
    required this.lastSyncAtUtc,
    required this.syncErrorCode,
    required this.capabilities,
  });

  final String id;
  final String accountId;
  final BusyProvider provider;
  final String accountLabel;
  final String accountAuthority;
  final AccountConnectionState connectionState;
  final String name;
  final String? color;
  final bool readOnly;
  final bool shared;
  final bool supportsEvents;
  final bool supportsTasks;
  final bool eventsSelected;
  final bool tasksSelected;
  final DateTime? lastSyncAtUtc;
  final String? syncErrorCode;
  final CollectionCapabilities capabilities;

  TaskCollectionCapabilities get taskCapabilities {
    if (!supportsTasks) return noTaskCollectionCapabilities;
    final base = nextcloudTaskCollectionCapabilities;
    return TaskCollectionCapabilities(
      supportsDueDate: base.supportsDueDate,
      supportsDueTime: base.supportsDueTime,
      supportsStartDateTime: base.supportsStartDateTime,
      supportsReminderDateTime: base.supportsReminderDateTime,
      supportsRecurrence: base.supportsRecurrence,
      supportsImportance: base.supportsImportance,
      supportsCategories: base.supportsCategories,
      supportsTaskHierarchy: base.supportsTaskHierarchy,
      supportsTaskReparenting:
          base.supportsTaskReparenting && capabilities.canUpdateTask,
      supportsCrossListMove:
          base.supportsCrossListMove && capabilities.canDeleteTask,
      supportsClearCompleted:
          base.supportsClearCompleted && capabilities.canDeleteTask,
      supportsHiddenTasks: false,
      supportsAssignedTasks: false,
      supportsListRename:
          base.supportsListRename && capabilities.canWriteProperties,
      supportsListDelete:
          base.supportsListDelete && (!capabilities.isReadOnly || shared),
      canCreateTasks: capabilities.canCreateTask,
      canUpdateTasks: capabilities.canUpdateTask,
      canDeleteTasks: capabilities.canDeleteTask,
      supportsIcalPriority: base.supportsIcalPriority,
      supportsPercentComplete: base.supportsPercentComplete,
      supportsTaskStatus: base.supportsTaskStatus,
      supportsCompletedDateTime: base.supportsCompletedDateTime,
      supportsLocation: base.supportsLocation,
      supportsUrl: base.supportsUrl,
      supportsClassification: base.supportsClassification,
      supportsMultipleReminders: base.supportsMultipleReminders,
      supportsAdvancedRecurrence: base.supportsAdvancedRecurrence,
      supportsPinning: base.supportsPinning,
      supportsSubtaskVisibility: base.supportsSubtaskVisibility,
      supportsDuplicate: base.supportsDuplicate,
      supportsNativeExport: base.supportsNativeExport,
      canUpdateClassification: !shared,
    );
  }
}

/// Manages local visibility for discovered DAV collections.
final class DavSettingsRepository {
  DavSettingsRepository({
    required AppDatabase database,
    Future<void> Function(String accountId)? onVisibilityChanged,
  }) : _database = database,
       _onVisibilityChanged = onVisibilityChanged;

  final AppDatabase _database;
  final Future<void> Function(String)? _onVisibilityChanged;

  Stream<List<DavCollectionSettingsEntity>> watchCollections() {
    final query =
        _database.select(_database.davCollections).join([
            innerJoin(
              _database.accounts,
              _database.accounts.id.equalsExp(
                _database.davCollections.accountId,
              ),
            ),
            leftOuterJoin(
              _database.davAccountServices,
              _database.davAccountServices.accountId.equalsExp(
                _database.davCollections.accountId,
              ),
            ),
            leftOuterJoin(
              _database.syncCursors,
              _database.syncCursors.davCollectionId.equalsExp(
                    _database.davCollections.id,
                  ) &
                  _database.syncCursors.transport.equals('caldav'),
            ),
          ])
          ..where(
            _database.davCollections.deleted.equals(false) &
                _database.davCollections.serverMissing.equals(false) &
                _database.accounts.provider.isIn(const [
                  'apple_icloud',
                  'nextcloud',
                ]),
          )
          ..orderBy([
            OrderingTerm.asc(_database.accounts.provider),
            OrderingTerm.asc(_database.accounts.displayName),
            OrderingTerm.asc(_database.davCollections.sortOrder),
            OrderingTerm.asc(_database.davCollections.displayName),
          ]);
    return query.watch().map((rows) {
      return [
        for (final row in rows)
          _fromRow(
            row.readTable(_database.davCollections),
            row.readTable(_database.accounts),
            row.readTableOrNull(_database.davAccountServices),
            row.readTableOrNull(_database.syncCursors),
          ),
      ];
    });
  }

  Future<DavCollectionSettingsEntity?> collectionByTaskListId(
    String accountId,
    String taskListId,
  ) async {
    final list =
        await (_database.select(_database.taskLists)..where(
              (row) =>
                  row.accountId.equals(accountId) & row.id.equals(taskListId),
            ))
            .getSingleOrNull();
    if (list?.davCollectionId == null) return null;
    return collectionById(list!.davCollectionId!);
  }

  Future<DavCollectionSettingsEntity?> collectionById(String id) async {
    final collection = await (_database.select(
      _database.davCollections,
    )..where((row) => row.id.equals(id))).getSingleOrNull();
    if (collection == null || collection.deleted || collection.serverMissing) {
      return null;
    }
    final account = await (_database.select(
      _database.accounts,
    )..where((row) => row.id.equals(collection.accountId))).getSingle();
    final service =
        await (_database.select(_database.davAccountServices)
              ..where((row) => row.accountId.equals(collection.accountId)))
            .getSingleOrNull();
    final cursor =
        await (_database.select(_database.syncCursors)..where(
              (row) =>
                  row.davCollectionId.equals(collection.id) &
                  row.transport.equals('caldav'),
            ))
            .getSingleOrNull();
    return _fromRow(collection, account, service, cursor);
  }

  Future<void> setEventsSelected(String collectionId, bool selected) async {
    final collection = await _requiredCollection(collectionId);
    if (!collection.eventProjectionEnabled) return;
    await _database.transaction(() async {
      await (_database.update(
        _database.davCollections,
      )..where((row) => row.id.equals(collectionId))).write(
        DavCollectionsCompanion(
          eventsSelected: Value(selected),
          updatedAtUtc: Value(DateTime.now().toUtc().toIso8601String()),
        ),
      );
      await (_database.update(
        _database.calendarSources,
      )..where((row) => row.davCollectionId.equals(collectionId))).write(
        CalendarSourcesCompanion(
          selected: Value(selected),
          updatedAtLocal: Value(DateTime.now().millisecondsSinceEpoch),
        ),
      );
    });
    await _onVisibilityChanged?.call(collection.accountId);
  }

  Future<void> setTasksSelected(String collectionId, bool selected) async {
    final collection = await _requiredCollection(collectionId);
    if (!collection.taskProjectionEnabled) return;
    await (_database.update(
      _database.davCollections,
    )..where((row) => row.id.equals(collectionId))).write(
      DavCollectionsCompanion(
        tasksSelected: Value(selected),
        updatedAtUtc: Value(DateTime.now().toUtc().toIso8601String()),
      ),
    );
    await _onVisibilityChanged?.call(collection.accountId);
  }

  Future<DavCollection> _requiredCollection(String id) {
    return (_database.select(_database.davCollections)..where(
          (row) =>
              row.id.equals(id) &
              row.deleted.equals(false) &
              row.serverMissing.equals(false),
        ))
        .getSingle();
  }
}

DavCollectionSettingsEntity _fromRow(
  DavCollection collection,
  Account account,
  DavAccountService? service,
  SyncCursor? cursor,
) {
  final capabilities = collectionCapabilitiesFromStored(collection);
  final provider = BusyProviderCodec.requireStorageValue(account.provider);
  final label = _accountLabel(account, provider);
  return DavCollectionSettingsEntity(
    id: collection.id,
    accountId: account.id,
    provider: provider,
    accountLabel: label,
    accountAuthority: account.authority,
    connectionState: AccountConnectionStateCodec.parse(account.authState),
    name: collection.displayName,
    color: collection.color,
    readOnly: capabilities.isReadOnly,
    shared: _isShared(collection, service),
    supportsEvents: capabilities.supportsEvents,
    supportsTasks: capabilities.supportsTasks,
    eventsSelected: collection.eventsSelected,
    tasksSelected: collection.tasksSelected,
    lastSyncAtUtc: DateTime.tryParse(collection.lastSyncAtUtc ?? '')?.toUtc(),
    syncErrorCode: cursor?.lastFailureCode ?? service?.lastDiscoveryErrorCode,
    capabilities: capabilities,
  );
}

String _accountLabel(Account account, BusyProvider provider) {
  final display = account.displayName?.trim();
  if (display != null && display.isNotEmpty) return display;
  final email = account.email?.trim();
  if (email != null && email.isNotEmpty) return email;
  return provider.displayName;
}

bool _isShared(DavCollection collection, DavAccountService? service) {
  try {
    final metadata = jsonDecode(collection.safeDisplayMetadataJson ?? '{}');
    if (metadata is Map && metadata['shared'] is bool) {
      return metadata['shared']! as bool;
    }
  } on FormatException {
    // Owner/principal comparison below remains a safe fallback.
  }
  final owner = _hrefPath(collection.ownerHref);
  final principal = _hrefPath(service?.principalHref);
  return owner != null && principal != null && owner != principal;
}

String? _hrefPath(String? source) {
  if (source == null || source.trim().isEmpty) return null;
  final uri = Uri.tryParse(source.trim());
  if (uri == null) return null;
  var path = uri.path;
  while (path.length > 1 && path.endsWith('/')) {
    path = path.substring(0, path.length - 1);
  }
  return path;
}

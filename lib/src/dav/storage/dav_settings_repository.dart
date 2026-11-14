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
    this.canRemoveCollection = false,
    this.ownership = DavCollectionOwnership.unknown,
    this.collectionRemovalPermissionKnown = true,
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
  final DavCollectionOwnership ownership;
  final bool supportsEvents;
  final bool supportsTasks;
  final bool eventsSelected;
  final bool tasksSelected;
  final DateTime? lastSyncAtUtc;
  final String? syncErrorCode;
  final CollectionCapabilities capabilities;
  final bool canRemoveCollection;
  final bool collectionRemovalPermissionKnown;

  TaskCollectionCapabilities get taskCapabilities {
    if (!supportsTasks) return noTaskCollectionCapabilities;
    final base = provider == BusyProvider.caldav
        ? caldavTaskCollectionCapabilities
        : nextcloudTaskCollectionCapabilities;
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
          base.supportsTaskReparenting && capabilities.canAttemptUpdateTask,
      supportsCrossListMove:
          base.supportsCrossListMove &&
          capabilities.canAttemptDeleteTask &&
          (provider != BusyProvider.caldav || capabilities.supportsMove),
      supportsClearCompleted:
          base.supportsClearCompleted && capabilities.canAttemptDeleteTask,
      supportsHiddenTasks: false,
      supportsAssignedTasks: false,
      supportsListRename:
          base.supportsListRename &&
          (capabilities.canWriteProperties ||
              provider == BusyProvider.caldav &&
                  !capabilities.permissionsKnown),
      supportsListDelete:
          base.supportsListDelete &&
          (provider != BusyProvider.caldav ||
              ownership == DavCollectionOwnership.owned) &&
          (canRemoveCollection ||
              provider == BusyProvider.caldav &&
                  !collectionRemovalPermissionKnown),
      canCreateTasks: capabilities.canAttemptCreateTask,
      canUpdateTasks: capabilities.canAttemptUpdateTask,
      canDeleteTasks: capabilities.canAttemptDeleteTask,
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
      supportsSharing: base.supportsSharing && capabilities.allowsItemMutations,
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
                  'caldav',
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
  ) => watchCollectionByTaskListId(accountId, taskListId).first;

  Stream<DavCollectionSettingsEntity?> watchCollectionByTaskListId(
    String accountId,
    String taskListId,
  ) {
    final query =
        _database.select(_database.davCollections).join([
          innerJoin(
            _database.taskLists,
            _database.taskLists.davCollectionId.equalsExp(
                  _database.davCollections.id,
                ) &
                _database.taskLists.accountId.equalsExp(
                  _database.davCollections.accountId,
                ),
          ),
          innerJoin(
            _database.accounts,
            _database.accounts.id.equalsExp(_database.davCollections.accountId),
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
        ])..where(
          _database.taskLists.accountId.equals(accountId) &
              _database.taskLists.id.equals(taskListId) &
              _database.davCollections.deleted.equals(false) &
              _database.davCollections.serverMissing.equals(false),
        );
    return query.watchSingleOrNull().map(
      (row) => row == null
          ? null
          : _fromRow(
              row.readTable(_database.davCollections),
              row.readTable(_database.accounts),
              row.readTableOrNull(_database.davAccountServices),
              row.readTableOrNull(_database.syncCursors),
            ),
    );
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
  final ownership = davCollectionOwnership(collection, service);
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
    shared: provider == BusyProvider.caldav
        ? ownership == DavCollectionOwnership.shared
        : davCollectionIsShared(collection, service),
    ownership: ownership,
    supportsEvents: collection.eventProjectionEnabled,
    supportsTasks: collection.taskProjectionEnabled,
    eventsSelected: collection.eventsSelected,
    tasksSelected: collection.tasksSelected,
    lastSyncAtUtc: DateTime.tryParse(collection.lastSyncAtUtc ?? '')?.toUtc(),
    syncErrorCode: cursor?.lastFailureCode ?? service?.lastDiscoveryErrorCode,
    capabilities: capabilities,
    canRemoveCollection:
        _parentAllowsRemoval(collection) &&
        (provider != BusyProvider.caldav ||
            ownership == DavCollectionOwnership.owned),
    collectionRemovalPermissionKnown:
        provider != BusyProvider.caldav ||
        (jsonDecode(collection.safeDisplayMetadataJson ?? '{}')
                as Map)['parentPrivilegesKnown'] ==
            'true',
  );
}

bool _parentAllowsRemoval(DavCollection collection) {
  try {
    final metadata = jsonDecode(collection.safeDisplayMetadataJson ?? '{}');
    final privileges = metadata is Map ? metadata['parentPrivileges'] : null;
    return privileges is List &&
        privileges.any(
          (value) =>
              value == '{DAV:}all' ||
              value == '{DAV:}write' ||
              value == '{DAV:}unbind',
        );
  } on FormatException {
    return false;
  }
}

String _accountLabel(Account account, BusyProvider provider) {
  final display = account.displayName?.trim();
  if (display != null && display.isNotEmpty) return display;
  final email = account.email?.trim();
  if (email != null && email.isNotEmpty) return email;
  return provider.displayName;
}

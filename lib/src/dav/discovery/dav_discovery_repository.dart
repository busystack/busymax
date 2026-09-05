import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../db/app_database.dart';
import '../../providers/busy_provider.dart';
import '../dav_provider_profile.dart';
import 'dav_discovery_models.dart';

final class DavDiscoveryRepository {
  DavDiscoveryRepository({
    required AppDatabase database,
    String Function()? idFactory,
  }) : _database = database,
       _idFactory = idFactory ?? const Uuid().v4;

  final AppDatabase _database;
  final String Function() _idFactory;

  /// Returns whether discovery changed a notification-enabled projection.
  Future<bool> commitSuccessfulInventory(DavDiscoveryResult result) {
    return _database.transaction(() async {
      final notificationProjectionsBefore =
          await _notificationEnabledProjectionKeys(result.accountId);
      final service = result.service;
      await _database
          .into(_database.davAccountServices)
          .insertOnConflictUpdate(
            DavAccountServicesCompanion.insert(
              accountId: result.accountId,
              canonicalServiceUri: service.canonicalServiceUri.toString(),
              canonicalOrigin: service.canonicalOrigin.toString(),
              principalHref: Value(service.principalHref.toString()),
              calendarHomeHref: Value(service.calendarHomeHref.toString()),
              calendarUserAddressesJson: Value(
                jsonEncode(
                  service.calendarUserAddresses
                      .map((address) => address.toString())
                      .toList(growable: false),
                ),
              ),
              scheduleInboxHref: Value(service.scheduleInboxHref?.toString()),
              scheduleOutboxHref: Value(service.scheduleOutboxHref?.toString()),
              capabilitiesJson: Value(
                jsonEncode({
                  'hasPrincipal': service.capabilities.hasPrincipal,
                  'hasCalendarHome': service.capabilities.hasCalendarHome,
                  'hasSchedulingInbox': service.capabilities.hasSchedulingInbox,
                  'hasSchedulingOutbox':
                      service.capabilities.hasSchedulingOutbox,
                  'supportedReports':
                      service.capabilities.supportedReports.toList()..sort(),
                  'serverFeatures': service.capabilities.serverFeatures.toList()
                    ..sort(),
                }),
              ),
              capabilitiesSchemaVersion: const Value(
                davCapabilitiesSchemaVersion,
              ),
              providerProfileVersion: Value(service.providerProfileVersion),
              discoveredAtUtc: service.discoveredAtUtc.toIso8601String(),
              lastValidatedAtUtc: Value(
                service.lastValidatedAtUtc.toIso8601String(),
              ),
              lastDiscoveryErrorCode: const Value(null),
            ),
          );

      final returnedIds = <String>[];
      for (final discovered in result.collections) {
        final existing =
            await (_database.select(_database.davCollections)..where(
                  (row) =>
                      row.accountId.equals(result.accountId) &
                      row.hrefKey.equals(discovered.hrefKey),
                ))
                .getSingleOrNull();
        final id = existing?.id ?? _idFactory();
        returnedIds.add(id);
        final now = service.discoveredAtUtc.toIso8601String();
        await _database
            .into(_database.davCollections)
            .insertOnConflictUpdate(
              DavCollectionsCompanion.insert(
                id: id,
                accountId: result.accountId,
                hrefKey: discovered.hrefKey,
                requestUri: discovered.requestUri.toString(),
                displayName: discovered.displayName,
                description: Value(discovered.description),
                resourceTypesJson: Value(
                  jsonEncode(discovered.resourceTypes.toList()..sort()),
                ),
                supportedComponentMask: Value(
                  discovered.supportedComponentMask,
                ),
                supportedCalendarDataJson: Value(
                  jsonEncode(discovered.supportedCalendarData),
                ),
                supportedReportsJson: Value(
                  jsonEncode(discovered.supportedReports.toList()..sort()),
                ),
                currentUserPrivilegesJson: Value(
                  jsonEncode(discovered.currentUserPrivileges.toList()..sort()),
                ),
                ownerHref: Value(discovered.ownerHref),
                safeDisplayMetadataJson: Value(
                  discovered.safeDisplayMetadata.isEmpty
                      ? null
                      : jsonEncode(discovered.safeDisplayMetadata),
                ),
                color: Value(discovered.color),
                sortOrder: Value(discovered.sortOrder),
                calendarTimeZone: Value(discovered.calendarTimeZone),
                calendarTimeZoneId: Value(discovered.calendarTimeZoneId),
                scheduleTransparency: Value(discovered.scheduleTransparency),
                maximumResourceSize: Value(discovered.maximumResourceSize),
                maximumInstances: Value(discovered.maximumInstances),
                syncToken: Value(discovered.syncToken),
                ctag: Value(discovered.ctag),
                readOnly: Value(discovered.capabilities.isReadOnly),
                eventProjectionEnabled: Value(
                  discovered.eventProjectionEnabled,
                ),
                taskProjectionEnabled: Value(discovered.taskProjectionEnabled),
                eventsSelected: Value(existing?.eventsSelected ?? true),
                tasksSelected: Value(existing?.tasksSelected ?? true),
                serverMissing: const Value(false),
                deleted: const Value(false),
                lastInventoryAtUtc: Value(now),
                lastSyncAtUtc: Value(existing?.lastSyncAtUtc),
                parserVersion: Value(existing?.parserVersion ?? 1),
                projectionVersion: Value(existing?.projectionVersion ?? 1),
                createdAtUtc: existing?.createdAtUtc ?? now,
                updatedAtUtc: now,
              ),
            );
        await _upsertProjections(
          result: result,
          collectionId: id,
          collection: discovered,
          now: service.discoveredAtUtc,
          existing: existing,
        );
      }

      final missingQuery = _database.update(_database.davCollections)
        ..where((row) {
          final sameAccount = row.accountId.equals(result.accountId);
          return returnedIds.isEmpty
              ? sameAccount
              : sameAccount & row.id.isNotIn(returnedIds);
        });
      await missingQuery.write(
        DavCollectionsCompanion(
          serverMissing: const Value(true),
          updatedAtUtc: Value(service.discoveredAtUtc.toIso8601String()),
        ),
      );
      await _markMissingProjections(result.accountId, returnedIds);
      await (_database.update(
        _database.accounts,
      )..where((row) => row.id.equals(result.accountId))).write(
        AccountsCompanion(
          providerProfileVersion: const Value(davProviderProfileVersion),
          updatedAtUtc: Value(service.discoveredAtUtc.toIso8601String()),
        ),
      );
      final notificationProjectionsAfter =
          await _notificationEnabledProjectionKeys(result.accountId);
      return !_sameProjectionKeys(
        notificationProjectionsBefore,
        notificationProjectionsAfter,
      );
    });
  }

  Future<Set<String>> _notificationEnabledProjectionKeys(
    String accountId,
  ) async {
    final eventSources =
        await (_database.select(_database.calendarSources)..where(
              (row) =>
                  row.accountId.equals(accountId) &
                  row.davCollectionId.isNotNull() &
                  row.remindersEnabled.equals(true) &
                  row.isDeleted.equals(false),
            ))
            .get();
    final taskLists =
        await (_database.select(_database.taskLists)..where(
              (row) =>
                  row.accountId.equals(accountId) &
                  row.davCollectionId.isNotNull() &
                  row.remindersEnabled.equals(true) &
                  row.pendingDelete.equals(false) &
                  row.serverMissing.equals(false),
            ))
            .get();
    return {
      for (final source in eventSources) 'event:${source.id}',
      for (final list in taskLists) 'task:${list.id}',
    };
  }

  Future<void> recordDiscoveryFailure(String accountId, String code) async {
    final existing = await (_database.select(
      _database.davAccountServices,
    )..where((row) => row.accountId.equals(accountId))).getSingleOrNull();
    if (existing == null) return;
    await (_database.update(
      _database.davAccountServices,
    )..where((row) => row.accountId.equals(accountId))).write(
      DavAccountServicesCompanion(lastDiscoveryErrorCode: Value(code)),
    );
  }

  Future<void> _upsertProjections({
    required DavDiscoveryResult result,
    required String collectionId,
    required DavCollectionDiscovery collection,
    required DateTime now,
    required DavCollection? existing,
  }) async {
    final nowText = now.toUtc().toIso8601String();
    final nowEpoch = now.toUtc().millisecondsSinceEpoch;
    final calendarSourceId = 'dav-calendar-$collectionId';
    if (collection.eventProjectionEnabled) {
      final existingSource = await (_database.select(
        _database.calendarSources,
      )..where((row) => row.id.equals(calendarSourceId))).getSingleOrNull();
      await _database
          .into(_database.calendarSources)
          .insertOnConflictUpdate(
            CalendarSourcesCompanion.insert(
              id: calendarSourceId,
              accountId: result.accountId,
              provider: result.provider.storageValue,
              providerCalendarId: collection.hrefKey,
              davCollectionId: Value(collectionId),
              summary: collection.displayName,
              description: Value(collection.description),
              selected: Value(
                existingSource?.selected ?? existing?.eventsSelected ?? true,
              ),
              remindersEnabled: Value(existingSource?.remindersEnabled ?? true),
              hidden: const Value(false),
              readOnly: Value(collection.capabilities.isReadOnly),
              backgroundColor: Value(collection.color),
              timeZone: Value(collection.calendarTimeZoneId),
              accessRole: Value(
                collection.capabilities.isReadOnly ? 'reader' : 'writer',
              ),
              isDeleted: const Value(false),
              rawJson: Value(_projectionMetadata(collection)),
              createdAtLocal: existingSource?.createdAtLocal ?? nowEpoch,
              updatedAtLocal: nowEpoch,
            ),
          );
    } else {
      await (_database.update(
        _database.calendarSources,
      )..where((row) => row.davCollectionId.equals(collectionId))).write(
        CalendarSourcesCompanion(
          hidden: const Value(true),
          isDeleted: const Value(true),
          updatedAtLocal: Value(nowEpoch),
        ),
      );
    }

    final taskListId = 'dav-task-list-$collectionId';
    if (collection.taskProjectionEnabled) {
      final shared = _differentPrincipal(
        collection.ownerHref,
        result.service.principalHref.toString(),
      );
      await _database
          .into(_database.taskLists)
          .insertOnConflictUpdate(
            TaskListsCompanion.insert(
              accountId: result.accountId,
              id: taskListId,
              davCollectionId: Value(collectionId),
              title: collection.displayName,
              rawJson: _projectionMetadata(collection),
              isOwner: Value(!shared),
              isShared: Value(shared),
              serverMissing: const Value(false),
              createdLocalAtUtc: existing?.createdAtUtc ?? nowText,
              updatedLocalAtUtc: nowText,
            ),
          );
    } else {
      await (_database.update(
        _database.taskLists,
      )..where((row) => row.davCollectionId.equals(collectionId))).write(
        TaskListsCompanion(
          serverMissing: const Value(true),
          updatedLocalAtUtc: Value(nowText),
        ),
      );
    }
  }

  Future<void> _markMissingProjections(
    String accountId,
    List<String> returnedCollectionIds,
  ) async {
    Expression<bool> missingCollection(Expression<String> column) =>
        returnedCollectionIds.isEmpty
        ? column.isNotNull()
        : column.isNotNull() & column.isNotIn(returnedCollectionIds);
    await (_database.update(_database.calendarSources)..where(
          (row) =>
              row.accountId.equals(accountId) &
              missingCollection(row.davCollectionId),
        ))
        .write(
          const CalendarSourcesCompanion(
            hidden: Value(true),
            isDeleted: Value(true),
          ),
        );
    await (_database.update(_database.taskLists)..where(
          (row) =>
              row.accountId.equals(accountId) &
              missingCollection(row.davCollectionId),
        ))
        .write(const TaskListsCompanion(serverMissing: Value(true)));
  }
}

bool _sameProjectionKeys(Set<String> left, Set<String> right) =>
    left.length == right.length && left.containsAll(right);

String _projectionMetadata(DavCollectionDiscovery collection) => jsonEncode({
  'transport': 'caldav',
  'hrefKey': collection.hrefKey,
  'kind': collection.kind.name,
  'supportedComponentMask': collection.supportedComponentMask,
  'readOnly': collection.capabilities.isReadOnly,
});

bool _differentPrincipal(String? ownerHref, String principalHref) {
  String? path(String? value) {
    final uri = Uri.tryParse(value ?? '');
    if (uri == null || uri.path.isEmpty) return null;
    var result = uri.path;
    while (result.length > 1 && result.endsWith('/')) {
      result = result.substring(0, result.length - 1);
    }
    return result;
  }

  final owner = path(ownerHref);
  final principal = path(principalHref);
  return owner != null && principal != null && owner != principal;
}

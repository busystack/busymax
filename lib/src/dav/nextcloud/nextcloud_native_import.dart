import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../db/app_database.dart';
import '../dav_errors.dart';
import '../ical/ical_document.dart';
import '../ical/ical_semantics.dart';
import '../mutation/dav_conditional_mutation_service.dart';
import '../mutation/dav_pending_operations.dart';
import '../storage/dav_collection_capabilities.dart';
import '../storage/dav_object_repository.dart';

enum NativeImportDuplicates { skip, newCopies }

enum NativeImportItemStatus { queued, duplicate, unsupported, failed }

final class NativeImportItemResult {
  const NativeImportItemResult(
    this.uid,
    this.componentType,
    this.status, [
    this.code,
  ]);
  final String uid;
  final String componentType;
  final NativeImportItemStatus status;
  final String? code;
}

/// A resource is one component type and one UID recurrence set. Original
/// calendar properties, embedded zones and unknown fields remain authoritative.
final class NativeImportResource {
  const NativeImportResource(this.uid, this.componentType, this.rawIcs);
  final String uid;
  final String componentType;
  final String rawIcs;
}

final class NextcloudNativeImportPreview {
  const NextcloudNativeImportPreview(
    this.resources,
    this.rejected,
    this.schedulingMethod,
  );
  final List<NativeImportResource> resources;
  final List<NativeImportItemResult> rejected;
  final String? schedulingMethod;

  factory NextcloudNativeImportPreview.parse(IcalDocument document) {
    final groups = <(String, String), List<IcalComponent>>{};
    final rejected = <NativeImportItemResult>[];
    for (final component in document.calendarComponents) {
      if (component.name == 'VTIMEZONE') continue;
      final uid = component.firstProperty('UID')?.rawValue.trim() ?? '';
      if (!{'VEVENT', 'VTODO'}.contains(component.name) || uid.isEmpty) {
        rejected.add(
          NativeImportItemResult(
            uid,
            component.name,
            NativeImportItemStatus.unsupported,
            'IcalUnsupportedResource',
          ),
        );
        continue;
      }
      groups.putIfAbsent((component.name, uid), () => []).add(component);
    }
    final resources = <NativeImportResource>[];
    for (final entry in groups.entries) {
      final (type, uid) = entry.key;
      try {
        // Work on a private document so preview normalization cannot change
        // the conversion/import path used by another destination provider.
        final resource = IcalDocument.parse(document.serialize());
        resource.root.children.removeWhere(
          (node) => node is IcalComponent && node.name != 'VTIMEZONE',
        );
        resource.root.children.addAll(entry.value.map((c) => c.deepCopy()));
        resource.root.children.removeWhere(
          (node) => node is IcalProperty && node.name == 'METHOD',
        );
        resource.root.structurallyDirty = true;
        final raw = resource.serialize();
        final semantic = IcalSemanticDocument.parse(raw);
        final identities = <String>{};
        if (semantic.components.where((c) => c.recurrenceId == null).length !=
                1 ||
            semantic.components.any(
              (c) => !identities.add(c.recurrenceIdKey ?? 'master'),
            )) {
          throw const DavException(
            kind: DavErrorKind.invalidCalendarData,
            code: 'IcalInvalidRecurrenceSet',
            safeMessage:
                'A recurrence set must have one master and distinct exceptions.',
          );
        }
        resources.add(NativeImportResource(uid, type, raw));
      } on DavException catch (error) {
        rejected.add(
          NativeImportItemResult(
            uid,
            type,
            NativeImportItemStatus.unsupported,
            error.code,
          ),
        );
      }
    }
    return NextcloudNativeImportPreview(
      List.unmodifiable(resources),
      List.unmodifiable(rejected),
      document.root.firstProperty('METHOD')?.rawValue,
    );
  }
}

final class NextcloudNativeImportService {
  NextcloudNativeImportService(
    this.database, {
    String Function()? idFactory,
    DateTime Function()? nowUtc,
  }) : _idFactory = idFactory ?? const Uuid().v4,
       _nowUtc = nowUtc ?? (() => DateTime.now().toUtc());
  final AppDatabase database;
  final String Function() _idFactory;
  final DateTime Function() _nowUtc;

  Future<List<NativeImportItemResult>> import({
    required String accountId,
    required String collectionId,
    required NextcloudNativeImportPreview preview,
    NativeImportDuplicates duplicates = NativeImportDuplicates.skip,
    bool normalizeSchedulingMethod = false,
  }) async {
    if (preview.schedulingMethod != null && !normalizeSchedulingMethod) {
      throw const DavException(
        kind: DavErrorKind.unsupportedComponent,
        code: 'IcalSchedulingNormalizationRequired',
        safeMessage:
            'Review importing this scheduling message as stored calendar data.',
      );
    }
    final replacements = {
      if (duplicates == NativeImportDuplicates.newCopies)
        for (final resource in preview.resources)
          (resource.componentType, resource.uid):
              '${_idFactory()}@busymax.local',
    };
    final results = <NativeImportItemResult>[...preview.rejected];
    final resourcesByTaskUid = {
      for (final r in preview.resources)
        if (r.componentType == 'VTODO') r.uid: r,
    };
    final ordered = <NativeImportResource>[];
    final visited = <String>{}, visiting = <String>{}, invalid = <String>{};
    void visit(NativeImportResource resource) {
      if (resource.componentType != 'VTODO') {
        ordered.add(resource);
        return;
      }
      if (visited.contains(resource.uid)) return;
      if (!visiting.add(resource.uid)) {
        invalid.addAll(visiting);
        return;
      }
      for (final parent in _nativeImportParents(resource)) {
        final related = resourcesByTaskUid[parent];
        if (related != null) visit(related);
        if (invalid.contains(parent)) invalid.add(resource.uid);
      }
      visiting.remove(resource.uid);
      visited.add(resource.uid);
      ordered.add(resource);
    }

    for (final resource in preview.resources) {
      visit(resource);
    }
    final taskOutcomes = <String, NativeImportItemStatus>{};
    final parentOperations = <String, String>{};
    for (final resource in ordered) {
      String? queuedOperation;
      try {
        final result = await database.transaction(() async {
          final parents = _nativeImportParents(resource);
          if (invalid.contains(resource.uid) ||
              parents.length > 1 ||
              parents.any(
                (p) =>
                    taskOutcomes.containsKey(p) &&
                    taskOutcomes[p] != NativeImportItemStatus.queued &&
                    taskOutcomes[p] != NativeImportItemStatus.duplicate,
              )) {
            return NativeImportItemResult(
              resource.uid,
              resource.componentType,
              NativeImportItemStatus.failed,
              'IcalImportParentUnavailable',
            );
          }
          final collection =
              await (database.select(database.davCollections)..where(
                    (r) =>
                        r.id.equals(collectionId) &
                        r.accountId.equals(accountId),
                  ))
                  .getSingle();
          for (final parent in parents.where(
            (p) => !resourcesByTaskUid.containsKey(p),
          )) {
            final known =
                await (database.select(database.davObjects)..where(
                      (r) =>
                          r.accountId.equals(accountId) &
                          r.collectionId.equals(collectionId) &
                          r.primaryUid.equals(parent) &
                          r.serverDeleted.equals(false),
                    ))
                    .get();
            if (!known.any(
              (r) => IcalSemanticDocument.parse(
                r.rawIcsBody,
              ).components.any((c) => c.componentType == 'VTODO'),
            )) {
              return NativeImportItemResult(
                resource.uid,
                resource.componentType,
                NativeImportItemStatus.failed,
                'IcalImportParentUnavailable',
              );
            }
          }
          final account = await (database.select(
            database.accounts,
          )..where((r) => r.id.equals(accountId))).getSingle();
          final caps = collectionCapabilitiesFromStored(collection);
          if (account.provider != 'nextcloud' ||
              !(resource.componentType == 'VEVENT'
                  ? caps.canCreateEvent
                  : caps.canCreateTask)) {
            return NativeImportItemResult(
              resource.uid,
              resource.componentType,
              NativeImportItemStatus.unsupported,
              'DavImportDestinationDenied',
            );
          }
          final uid =
              replacements[(resource.componentType, resource.uid)] ??
              resource.uid;
          final existing =
              await (database.select(database.davObjects)..where(
                    (r) =>
                        r.accountId.equals(accountId) &
                        r.collectionId.equals(collectionId) &
                        r.primaryUid.equals(uid) &
                        r.serverDeleted.equals(false),
                  ))
                  .get();
          final pending =
              await (database.select(database.pendingOps)..where(
                    (r) =>
                        r.accountId.equals(accountId) &
                        r.davCollectionId.equals(collectionId) &
                        r.operationType.equals('dav.create'),
                  ))
                  .get();
          if (existing.isNotEmpty ||
              pending.any(
                (op) => (jsonDecode(op.requestJson) as Map)['uid'] == uid,
              )) {
            return NativeImportItemResult(
              resource.uid,
              resource.componentType,
              NativeImportItemStatus.duplicate,
            );
          }
          final document = IcalDocument.parse(resource.rawIcs);
          if (duplicates == NativeImportDuplicates.newCopies) {
            for (final component in document.calendarComponents.where(
              (c) => c.name == resource.componentType,
            )) {
              final property = component.firstProperty('UID')!;
              property.rawValue = uid;
              property.isDirty = true;
              if (resource.componentType == 'VTODO') {
                for (final relation in component.propertiesNamed(
                  'RELATED-TO',
                )) {
                  final replacement =
                      replacements[('VTODO', relation.decodedTextValue)];
                  if (replacement != null) {
                    relation.rawValue = encodeIcalText(replacement);
                    relation.isDirty = true;
                  }
                }
              }
            }
          }
          final object = DavNewObject(
            uid: uid,
            initialMemberName: '${_idFactory()}.ics',
            rawIcs: document.serialize(),
            componentType: resource.componentType,
            suppressScheduling: true,
          );
          final target = Uri.parse(
            collection.requestUri.endsWith('/')
                ? collection.requestUri
                : '${collection.requestUri}/',
          ).resolve(object.initialMemberName);
          final repository = DavObjectRepository(database: database);
          final localObjectId = await repository.projectPendingImport(
            accountId: accountId,
            collectionId: collectionId,
            object: DavPreparedObject.parse(
              hrefKey: target.path,
              requestUri: target,
              etag: null,
              contentType: 'text/calendar',
              rawIcsBody: object.rawIcs,
            ),
            nowUtc: _nowUtc(),
          );
          queuedOperation =
              await DavPendingOperationQueue(
                database: database,
                nowUtc: _nowUtc,
              ).enqueueCreate(
                accountId: accountId,
                collectionId: collectionId,
                object: object,
                localObjectId: localObjectId,
                dependsOnOperationId: parents
                    .map((p) => parentOperations[p])
                    .whereType<String>()
                    .firstOrNull,
              );
          return NativeImportItemResult(
            uid,
            resource.componentType,
            NativeImportItemStatus.queued,
          );
        });
        results.add(result);
        if (resource.componentType == 'VTODO') {
          taskOutcomes[resource.uid] = result.status;
          if (queuedOperation != null &&
              result.status == NativeImportItemStatus.queued) {
            parentOperations[resource.uid] = queuedOperation!;
          }
        }
      } on Object catch (error) {
        if (resource.componentType == 'VTODO') {
          taskOutcomes[resource.uid] = NativeImportItemStatus.failed;
        }
        results.add(
          NativeImportItemResult(
            resource.uid,
            resource.componentType,
            NativeImportItemStatus.failed,
            error is DavException ? error.code : 'IcalLocalImportFailed',
          ),
        );
      }
    }
    return List.unmodifiable(results);
  }
}

Set<String> _nativeImportParents(NativeImportResource resource) =>
    resource.componentType != 'VTODO'
    ? {}
    : {
        for (final component in IcalDocument.parse(
          resource.rawIcs,
        ).calendarComponents.where((c) => c.name == 'VTODO'))
          for (final relation in component.propertiesNamed('RELATED-TO'))
            if ((relation.parameterValue('RELTYPE') ?? 'PARENT')
                    .toUpperCase() ==
                'PARENT')
              relation.decodedTextValue,
      };

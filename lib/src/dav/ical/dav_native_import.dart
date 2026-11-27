import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../db/app_database.dart';
import '../../journal/journal_component.dart';
import '../../journal/journal_itip.dart';
import '../../providers/busy_provider.dart';
import '../dav_errors.dart';
import '../ical/ical_document.dart';
import '../ical/ical_semantics.dart';
import '../mutation/dav_conditional_mutation_service.dart';
import '../mutation/dav_mutation_patch.dart';
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
    this.safeMessage,
    this.operationId,
  ]);
  final String uid;
  final String componentType;
  final NativeImportItemStatus status;
  final String? code;
  final String? safeMessage;
  final String? operationId;
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
  bool get hasAttendees =>
      resources.any((resource) => icalHasAttendees(resource.rawIcs));
  bool get isJournalMessage =>
      schedulingMethod != null &&
      resources.isNotEmpty &&
      resources.every((r) => r.componentType == 'VJOURNAL');

  factory NextcloudNativeImportPreview.parse(IcalDocument document) {
    final groups = <(String, String), List<IcalComponent>>{};
    final rejected = <NativeImportItemResult>[];
    for (final component in document.calendarComponents) {
      if (component.name == 'VTIMEZONE') continue;
      final uid = component.firstProperty('UID')?.rawValue.trim() ?? '';
      if (!const {'VEVENT', 'VTODO', 'VJOURNAL'}.contains(component.name) ||
          uid.isEmpty) {
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
        if (type != 'VJOURNAL') {
          resource.root.children.removeWhere(
            (node) => node is IcalProperty && node.name == 'METHOD',
          );
        }
        resource.root.structurallyDirty = true;
        final raw = resource.serialize();
        final semantic = IcalSemanticDocument.parse(raw);
        final identities = <String>{};
        final masters = semantic.components
            .where((c) => c.recurrenceId == null)
            .length;
        if ((type == 'VJOURNAL' ? masters > 1 : masters != 1) ||
            semantic.components.any(
              (c) => !identities.add(c.recurrenceIdKey ?? 'master'),
            )) {
          throw const DavException(
            kind: DavErrorKind.invalidCalendarData,
            code: 'IcalInvalidRecurrenceSet',
            safeMessage: 'A recurrence set must have one master and distinct exceptions.',
          );
        }
        if (type == 'VJOURNAL' &&
            resource.root.firstProperty('METHOD') != null) {
          if (groups.keys.any((key) => key.$1 != 'VJOURNAL') ||
              (resource.root.firstProperty('METHOD')?.rawValue.toUpperCase() ==
                      'CANCEL' &&
                  groups.length != 1)) {
            throw const DavException(
              kind: DavErrorKind.invalidCalendarData,
              code: 'IcalInvalidJournalMessage',
              safeMessage:
                  'The journal message contains incompatible components.',
            );
          }
          JournalMessage.parse(resource);
        } else {
          JournalComponent.validateAuthored(semantic);
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

final class DavNativeImportService {
  DavNativeImportService(
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
    bool allowScheduling = false,
  }) async {
    if (preview.schedulingMethod != null &&
        !preview.isJournalMessage &&
        !normalizeSchedulingMethod) {
      throw const DavException(
        kind: DavErrorKind.unsupportedComponent,
        code: 'IcalSchedulingNormalizationRequired',
        safeMessage:
            'Review importing this scheduling message as stored calendar data.',
      );
    }
    if (!allowScheduling && preview.hasAttendees) {
      final account = await (database.select(
        database.accounts,
      )..where((r) => r.id.equals(accountId))).getSingle();
      if (account.provider == 'caldav') {
        throw const DavException(
          kind: DavErrorKind.unsupportedComponent,
          code: 'IcalSchedulingConsentRequired',
          safeMessage: 'This CalDAV server may send invitations or meeting updates. Review the import before continuing.',
        );
      }
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
              (r) =>
                  IcalSemanticDocument.parse(r.rawIcsBody).components
                      .any((c) => c.componentType == 'VTODO'),
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
          final message =
              resource.componentType == 'VJOURNAL' && preview.isJournalMessage
              ? JournalMessage.parse(IcalDocument.parse(resource.rawIcs))
              : null;
          final canCreate = switch (resource.componentType) {
            'VEVENT' => caps.canAttemptCreateEvent,
            'VTODO' => caps.canAttemptCreateTask,
            'VJOURNAL' =>
              account.journalsEnabled && caps.canAttemptCreateJournal,
            _ => false,
          };
          if (!const {'nextcloud', 'caldav'}.contains(account.provider) ||
              (!canCreate &&
                  !(message != null &&
                      account.journalsEnabled &&
                      caps.canAttemptUpdateJournal))) {
            return NativeImportItemResult(
              resource.uid,
              resource.componentType,
              NativeImportItemStatus.unsupported,
              'DavImportDestinationDenied',
            );
          }
          final uid = message != null
              ? resource.uid
              : replacements[(resource.componentType, resource.uid)] ??
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
          if (message != null && existing.isNotEmpty) {
            if (existing.length != 1) {
              throw StateError('Ambiguous journal resource');
            }
            final current = existing.single;
            final queue = DavPendingOperationQueue(
              database: database,
              nowUtc: _nowUtc,
            );
            final effective = await queue.exportRawIcsForObject(
              accountId: accountId,
              collectionId: collectionId,
              objectId: current.id,
            );
            final candidate = message.update(effective);
            if (candidate == null) {
              return NativeImportItemResult(
                uid,
                'VJOURNAL',
                NativeImportItemStatus.duplicate,
              );
            }
            final semantic = IcalSemanticDocument.parse(effective);
            final target =
                semantic.components
                    .where((c) => c.recurrenceIdKey == null)
                    .firstOrNull ??
                semantic.components.first;
            final operationId = await queue.enqueueUpdate(
              accountId: accountId,
              collectionId: collectionId,
              objectId: current.id,
              patch: DavMutationPatch(
                target: IcalComponentKey(
                  componentType: 'VJOURNAL',
                  uid: uid,
                  recurrenceIdKey: target.recurrenceIdKey,
                ),
                scope: DavMutationScope.object,
                operations: [
                  DavPatchOperation.replaceJournalResource(candidate),
                ],
              ),
            );
            await DavObjectRepository(
              database: database,
            ).projectLocalMutationCandidate(
              accountId: accountId,
              collectionId: collectionId,
              objectId: current.id,
              provider: BusyProviderCodec.requireStorageValue(account.provider),
              candidateRawIcs: candidate,
            );
            return NativeImportItemResult(
              uid,
              'VJOURNAL',
              NativeImportItemStatus.queued,
              null,
              null,
              operationId,
            );
          }
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
          if (!canCreate) {
            return NativeImportItemResult(
              uid,
              resource.componentType,
              NativeImportItemStatus.unsupported,
              'DavImportDestinationDenied',
            );
          }
          final document = IcalDocument.parse(
            message?.initialResource() ?? resource.rawIcs,
          );
          if (message == null &&
              duplicates == NativeImportDuplicates.newCopies) {
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
            suppressScheduling:
                account.provider == 'nextcloud' &&
                resource.componentType != 'VJOURNAL',
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
                allowScheduling: allowScheduling,
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
            null,
            null,
            queuedOperation,
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
            error is DavException ? error.safeMessage : null,
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

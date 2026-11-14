import 'package:busymax/src/dav/ical/ical_document.dart';
import 'package:busymax/src/dav/mutation/dav_mutation_patch.dart';
import 'package:busymax/src/dav/mutation/dav_pending_operations.dart';
import 'package:busymax/src/dav/storage/dav_object_repository.dart';
import 'package:busymax/src/db/app_database.dart';
import 'package:busymax/src/providers/busy_provider.dart';
import 'package:drift/drift.dart';

const _collectionHref = '/calendars/work/';
const _eventHref = '${_collectionHref}event.ics';
String conflictResource(String component, {bool attendees = true}) =>
    'BEGIN:VCALENDAR\r\nVERSION:2.0\r\nPRODID:-//BusyMax QA//EN\r\n'
    'BEGIN:$component\r\nUID:event@example.test\r\nDTSTART:20260911T090000Z\r\n'
    '${component == 'VEVENT' ? 'DTEND' : 'DUE'}:20260911T100000Z\r\n'
    'SUMMARY:Baseline\r\nRRULE:FREQ=DAILY;COUNT=3\r\nX-KEEP:opaque\r\n'
    '${attendees ? 'ORGANIZER:mailto:owner@example.invalid\r\nATTENDEE:mailto:guest@example.invalid\r\n' : ''}'
    'END:$component\r\nBEGIN:$component\r\nUID:event@example.test\r\n'
    'RECURRENCE-ID:20260912T090000Z\r\nDTSTART:20260912T110000Z\r\n'
    '${component == 'VEVENT' ? 'DTEND' : 'DUE'}:20260912T120000Z\r\n'
    'SUMMARY:Exception\r\nEND:$component\r\nEND:VCALENDAR\r\n';

Future<void> seedSchedulingConflict(
  AppDatabase database, {
  String component = 'VEVENT',
  bool attendees = true,
}) async {
  final baseline = conflictResource(component, attendees: attendees);
  final remote = baseline.replaceAll('Baseline', 'Remote title');
  const now = '2026-09-10T12:00:00.000Z';
  await database
      .into(database.accounts)
      .insert(
        AccountsCompanion.insert(
          id: 'account',
          provider: BusyProvider.caldav.storageValue,
          authority: 'https://cloud.example.test',
          providerAccountId: 'alex',
          credentialKind: 'caldav_password',
          authState: const Value('signed_in'),
          createdAtUtc: now,
          updatedAtUtc: now,
        ),
      );
  await database
      .into(database.davCollections)
      .insert(
        DavCollectionsCompanion.insert(
          id: 'collection',
          accountId: 'account',
          hrefKey: _collectionHref,
          requestUri: 'https://cloud.example.test$_collectionHref',
          displayName: 'Work',
          supportedComponentMask: Value(component == 'VEVENT' ? 1 : 2),
          currentUserPrivilegesJson: const Value(
            '["{DAV:}read","{DAV:}write"]',
          ),
          readOnly: const Value(false),
          eventProjectionEnabled: const Value(true),
          taskProjectionEnabled: const Value(false),
          createdAtUtc: now,
          updatedAtUtc: now,
        ),
      );
  await database
      .into(database.calendarSources)
      .insert(
        CalendarSourcesCompanion.insert(
          id: 'dav-calendar-collection',
          accountId: 'account',
          provider: BusyProvider.caldav.storageValue,
          providerCalendarId: _collectionHref,
          davCollectionId: const Value('collection'),
          summary: 'Work',
          createdAtLocal: 0,
          updatedAtLocal: 0,
        ),
      );
  final repository = DavObjectRepository(
    database: database,
    idFactory: () => 'object',
  );
  await repository.commitConfirmedMutation(
    accountId: 'account',
    collectionId: 'collection',
    provider: BusyProvider.caldav,
    canonicalObject: DavPreparedObject.parse(
      hrefKey: _eventHref,
      requestUri: Uri.parse('https://cloud.example.test$_eventHref'),
      etag: '"baseline"',
      contentType: 'text/calendar',
      rawIcsBody: baseline,
    ),
    completedAtUtc: DateTime.parse(now),
  );
  await DavPendingOperationQueue(
    database: database,
    idFactory: () => 'pending',
    nowUtc: () => DateTime.parse(now),
  ).enqueueUpdate(
    accountId: 'account',
    collectionId: 'collection',
    objectId: 'object',
    patch: DavMutationPatch(
      target: IcalComponentKey(
        componentType: component,
        uid: 'event@example.test',
      ),
      scope: DavMutationScope.object,
      operations: [DavPatchOperation.setText('SUMMARY', 'Local title')],
    ),
  );
  final operation = await database.pendingOpsDao.getOp('pending');
  await database
      .into(database.davConflictSnapshots)
      .insert(
        DavConflictSnapshotsCompanion.insert(
          id: 'conflict',
          accountId: 'account',
          davCollectionId: const Value('collection'),
          davObjectId: const Value('object'),
          baselineEtag: const Value('"baseline"'),
          baselineRawIcs: baseline,
          localCandidateRawIcs: DavMutationPatch.fromJsonString(
            operation!.mutationPatchJson!,
          ).applyTo(baseline, nowUtc: DateTime.parse(now)),
          remoteEtag: const Value('"remote"'),
          remoteRawIcs: remote,
          conflictCode: 'DavConflictOverlappingProperties',
          createdAtUtc: now,
        ),
      );
  await (database.update(
    database.pendingOps,
  )..where((row) => row.id.equals('pending'))).write(
    const PendingOpsCompanion(
      state: Value('conflict'),
      conflictState: Value('unresolved'),
      conflictSnapshotId: Value('conflict'),
      retryClassification: Value('manual_conflict_resolution'),
    ),
  );
}

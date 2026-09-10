import 'package:busymax/l10n/generated/app_localizations.dart';
import 'package:busymax/src/app/app_bootstrap.dart';
import 'package:busymax/src/dav/ical/ical_document.dart';
import 'package:busymax/src/dav/mutation/dav_conflict_repository.dart';
import 'package:busymax/src/dav/mutation/dav_mutation_patch.dart';
import 'package:busymax/src/dav/mutation/dav_pending_operations.dart';
import 'package:busymax/src/dav/storage/dav_object_repository.dart';
import 'package:busymax/src/db/app_database.dart';
import 'package:busymax/src/features/sync/account_sync_operations.dart';
import 'package:busymax/src/providers/busy_provider.dart';
import 'package:busymax/src/ui/windows/windows_diagnostics_dialog.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final testCase in const [
    (
      resolution: DavConflictResolution.keepServer,
      actionKey: 'windows-keep-server-version',
    ),
    (
      resolution: DavConflictResolution.reapplyLocal,
      actionKey: 'windows-reapply-local-change',
    ),
    (
      resolution: DavConflictResolution.duplicateLocal,
      actionKey: 'windows-duplicate-local-item',
    ),
  ]) {
    testWidgets(
      'Windows reviews, cancels, then resolves ${testCase.resolution.name}',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final database = AppDatabase(NativeDatabase.memory());
        addTearDown(database.close);
        final sync = _RecordingSyncOperations();
        await _seedConflict(database);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              databaseProvider.overrideWithValue(database),
              accountSyncOperationsProvider.overrideWithValue(sync),
            ],
            child: const FluentApp(
              localizationsDelegates: [AppLocalizations.delegate],
              supportedLocales: AppLocalizations.supportedLocales,
              home: ScaffoldPage(
                content: WindowsDavConflictReview(accountId: 'account'),
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        final review = find.byKey(
          const ValueKey('windows-review-dav-conflict-conflict'),
        );
        expect(review, findsOneWidget);
        await tester.tap(review);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(
          find.byKey(const ValueKey('windows-keep-server-version')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('windows-reapply-local-change')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('windows-duplicate-local-item')),
          findsOneWidget,
        );

        await tester.tap(
          find.byKey(const ValueKey('windows-cancel-dav-conflict')),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(await database.pendingOpsDao.getOp('pending'), isNotNull);
        expect(
          (await database.select(database.davConflictSnapshots).getSingle())
              .resolvedAtUtc,
          isNull,
        );
        expect(sync.calls, isEmpty);

        await tester.tap(review);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        await tester.tap(find.byKey(ValueKey(testCase.actionKey)));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(sync.calls, ['account']);
        final snapshot = await database
            .select(database.davConflictSnapshots)
            .getSingle();
        expect(snapshot.resolvedAtUtc, isNotNull);
        expect(snapshot.resolution, testCase.resolution.name);
        switch (testCase.resolution) {
          case DavConflictResolution.keepServer:
            expect(await database.pendingOpsDao.getOp('pending'), isNull);
            expect(
              (await database.select(database.davObjects).getSingle())
                  .rawIcsBody,
              _remote,
            );
          case DavConflictResolution.reapplyLocal:
            final pending = await database.pendingOpsDao.getOp('pending');
            expect(pending?.state, 'pending');
            expect(pending?.baselineEtag, '"remote"');
            expect(pending?.baselineRawIcs, _remote);
          case DavConflictResolution.duplicateLocal:
            final pending = await database.select(database.pendingOps).get();
            expect(pending, hasLength(1));
            expect(pending.single.operationType, 'dav.create');
        }
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(milliseconds: 1));
        await tester.pump(const Duration(milliseconds: 1));
      },
    );
  }
}

Future<void> _seedConflict(AppDatabase database) async {
  const now = '2026-09-10T12:00:00.000Z';
  await database
      .into(database.accounts)
      .insert(
        AccountsCompanion.insert(
          id: 'account',
          provider: BusyProvider.nextcloud.storageValue,
          authority: 'https://cloud.example.test',
          providerAccountId: 'alex',
          credentialKind: 'nextcloud_app_password',
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
          supportedComponentMask: const Value(1),
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
          provider: BusyProvider.nextcloud.storageValue,
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
    provider: BusyProvider.nextcloud,
    canonicalObject: DavPreparedObject.parse(
      hrefKey: _eventHref,
      requestUri: Uri.parse('https://cloud.example.test$_eventHref'),
      etag: '"baseline"',
      contentType: 'text/calendar',
      rawIcsBody: _baseline,
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
      target: const IcalComponentKey(
        componentType: 'VEVENT',
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
          baselineRawIcs: _baseline,
          localCandidateRawIcs: DavMutationPatch.fromJsonString(
            operation!.mutationPatchJson!,
          ).applyTo(_baseline, nowUtc: DateTime.parse(now)),
          remoteEtag: const Value('"remote"'),
          remoteRawIcs: _remote,
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

final class _RecordingSyncOperations implements AccountSyncOperations {
  final calls = <String>[];

  @override
  Future<void> syncAccount(String accountId, {required bool full}) async {
    calls.add(accountId);
  }

  @override
  Future<void> syncCalendar(String accountId, {required bool full}) async {}

  @override
  Future<void> syncTasks(String accountId, {required bool full}) async {}
}

const _collectionHref = '/remote.php/dav/calendars/alex/work/';
const _eventHref = '${_collectionHref}event.ics';
const _baseline = '''BEGIN:VCALENDAR\r
VERSION:2.0\r
PRODID:-//BusyMax Test//EN\r
BEGIN:VEVENT\r
UID:event@example.test\r
DTSTART:20260911T090000Z\r
DTEND:20260911T100000Z\r
SUMMARY:Baseline\r
END:VEVENT\r
END:VCALENDAR\r
''';
const _remote = '''BEGIN:VCALENDAR\r
VERSION:2.0\r
PRODID:-//BusyMax Test//EN\r
BEGIN:VEVENT\r
UID:event@example.test\r
DTSTART:20260911T090000Z\r
DTEND:20260911T100000Z\r
SUMMARY:Remote title\r
END:VEVENT\r
END:VCALENDAR\r
''';

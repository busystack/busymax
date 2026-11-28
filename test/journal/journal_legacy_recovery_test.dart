import 'dart:convert';
import 'dart:io';

import 'package:busymax/src/dav/dav_errors.dart';
import 'package:busymax/src/dav/dav_provider_profile.dart';
import 'package:busymax/src/dav/http/dav_http_transport.dart';
import 'package:busymax/src/dav/ical/dav_native_export.dart';
import 'package:busymax/src/dav/ical/ical_semantics.dart';
import 'package:busymax/src/dav/mutation/dav_conditional_mutation_service.dart';
import 'package:busymax/src/dav/mutation/dav_pending_operations.dart';
import 'package:busymax/src/dav/nextcloud/nextcloud_collection_controller.dart';
import 'package:busymax/src/dav/storage/dav_object_repository.dart';
import 'package:busymax/src/db/app_database.dart';
import 'package:busymax/src/features/sync/pending_op_resolution_service.dart';
import 'package:busymax/src/features/sync/domain_sync_schedule.dart';
import 'package:busymax/src/features/sync/sync_request.dart';
import 'package:busymax/src/journal/journal_component.dart';
import 'package:busymax/src/journal/journal_repository.dart';
import 'package:busymax/src/providers/busy_provider.dart';
import 'package:busymax/src/ui/common/schedule/native_collection_export.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../dav/nextcloud/nextcloud_admin_fixture.dart';

void main() {
  for (final creating in [false, true]) {
    for (final attempt in [false, true]) {
      test(
        'Diagnostics discards a quarantined journal ${creating ? 'create' : 'update'} with attempted=$attempt',
        () async {
          final directory = await Directory.systemTemp.createTemp(
            'journal-discard',
          );
          addTearDown(() => directory.delete(recursive: true));
          final file = File('${directory.path}/journal.db');
          await file.writeAsBytes(
            gzip.decode(
              File(
                'test/journal/fixtures/${creating ? 'legacy-create-range-v28.sqlite.gz' : 'legacy-range-v28.sqlite.gz'}',
              ).readAsBytesSync(),
            ),
          );
          final db = AppDatabase(NativeDatabase(file));
          addTearDown(db.close);
          final journals = JournalRepository(db);
          final original = await db.select(db.pendingOps).getSingle();
          final entries = await journals.watchEntries().first;
          final originalObject = entries.firstWhere(
            (entry) => entry.davObjectId == original.davObjectId,
          );
          final sibling = entries.singleWhere(
            (entry) => entry.uid == 'sibling',
          );
          final siblingRaw = (await journals.read(sibling)).effectiveRawIcs;
          await db
              .update(db.accounts)
              .write(const AccountsCompanion(authState: Value('signed_in')));
          final selected = db.update(db.pendingOps)
            ..where((row) => row.id.equals(original.id));
          if (attempt) {
            await selected.write(
              PendingOpsCompanion(
                state: const Value('in_progress'),
                // An interrupted first dispatch can still have a zero count.
                attemptCount: Value(creating ? 0 : 1),
              ),
            );
          }
          final source = await db.select(db.davCollections).getSingle();
          await journals.create(source, title: 'Dependent journal');
          final dependent = await (db.select(
            db.pendingOps,
          )..where((row) => row.id.isNotValue(original.id))).getSingle();
          final linked = db.update(db.pendingOps)
            ..where((row) => row.id.equals(dependent.id));
          await linked.write(
            PendingOpsCompanion(dependsOnOpId: Value(original.id)),
          );
          await journals.create(source, title: 'Independent journal');
          final independent =
              await (db.select(db.pendingOps)..where(
                    (row) => row.id.isNotIn([original.id, dependent.id]),
                  ))
                  .getSingle();

          final requests = <String>[];
          var remoteMatches = !attempt;
          final authority = Uri.parse('https://example.invalid/');
          final client = MockClient((request) async {
            requests.add(request.method);
            expect(request.method, 'GET');
            expect(request.url.path, original.davMemberHref);
            if (remoteMatches && creating) return http.Response('', 404);
            return http.Response(
              remoteMatches
                  ? original.baselineRawIcs!.replaceAll('\r\n', '\n')
                  : siblingRaw,
              200,
              headers: {
                'etag': original.baselineEtag ?? '"unknown-create"',
                'content-type': 'text/calendar',
              },
            );
          });
          final transport = DavHttpTransport(
            client: client,
            profile: davProviderProfile(
              BusyProvider.caldav,
              caldavServer: authority,
            ),
            accountAuthority: authority,
          );
          final replayer = DavPendingOperationsReplayer(
            database: db,
            accountId: 'account',
            serviceFactory: ({required account, required collection}) async =>
                DavConditionalMutationService(
                  remoteClient: DavMutationHttpClient(
                    transport: transport,
                    accountId: account.id,
                    collectionId: collection.id,
                    credential: DavBasicCredential(
                      username: 'fixture',
                      password: 'fixture',
                    ),
                  ),
                ),
          );
          Future<void> replaySelected() async {
            final result = await replayer.replayDueOperations(
              operationIds: {original.id},
            );
            expect(result.appliedCount, 0);
          }

          var replayDuringSync = true;
          final diagnostics = PendingOpResolutionService(
            database: db,
            accountId: 'account',
            syncCalendar: () async {},
            syncTasks: () async =>
                fail('Journal recovery must not sync tasks.'),
            syncJournal: (scope) async {
              expect(scope, davCollectionSyncScope('account', source.id));
              if (replayDuringSync) await replaySelected();
              return SyncOutcome((
                scope: scope,
                origin: SyncTrigger.manual,
                strategy: SyncStrategy.ordinary,
              ), SyncDisposition.completed);
            },
          );
          await replaySelected();
          expect(requests, attempt ? ['GET'] : isEmpty);
          final parked = (await db.pendingOpsDao.getOp(original.id))!;
          expect(parked.state, 'failed');
          expect(parked.lastErrorCode, duplicateJournalPositionCode);
          if (attempt) {
            expect(parked.retryClassification, 'permanent');
            await expectLater(
              diagnostics.discard(original.id),
              throwsStateError,
            );
            expect(await db.pendingOpsDao.getOp(original.id), parked);
            remoteMatches = true;
            replayDuringSync = false;
            await expectLater(
              diagnostics.retryNow(original.id),
              throwsStateError,
            );
            await expectLater(
              diagnostics.discard(original.id),
              throwsStateError,
            );
            replayDuringSync = true;
            await diagnostics.retryNow(original.id);
          }
          final quarantined = (await db.pendingOpsDao.getOp(original.id))!;
          expect(
            quarantined.retryClassification,
            attempt
                ? 'journal_recovery_reconciled'
                : 'journal_recovery_reviewable',
          );
          expect(isDavCreateLocallyEditable(quarantined), isFalse);
          await linked.write(
            const PendingOpsCompanion(
              retryClassification: Value('manual_retry'),
            ),
          );
          await expectLater(diagnostics.discard(original.id), throwsStateError);
          expect(await db.pendingOpsDao.getOp(original.id), quarantined);
          await linked.write(
            PendingOpsCompanion(
              retryClassification: Value(dependent.retryClassification),
            ),
          );
          await diagnostics.discard(original.id);

          expect(requests, attempt ? ['GET', 'GET'] : isEmpty);
          expect(await db.select(db.pendingOps).get(), [independent]);
          final remaining = await journals.watchEntries().first;
          expect(
            remaining.map((entry) => entry.title),
            isNot(contains('Dependent journal')),
          );
          expect(
            remaining.map((entry) => entry.title),
            contains('Independent journal'),
          );
          expect((await journals.read(sibling)).effectiveRawIcs, siblingRaw);
          final affected = remaining.where(
            (entry) => entry.davObjectId == originalObject.davObjectId,
          );
          if (creating) {
            expect(affected, isEmpty);
            expect(
              await (db.select(db.davObjects)
                    ..where((row) => row.id.equals(original.davObjectId!)))
                  .getSingleOrNull(),
              isNull,
            );
          } else {
            expect(
              affected.map((entry) => entry.title),
              unorderedEquals(['Series', 'Original detached entry']),
            );
            final master = affected.singleWhere(
              (entry) => entry.recurrenceIdKey == null,
            );
            final restored = await journals.read(master);
            expect(restored.pendingRecovery, isNull);
            expect(restored.effectiveRawIcs, original.baselineRawIcs);
          }
        },
      );
      test(
        'a former release journal ${creating ? 'create' : 'update'} with attempted=$attempt is recoverable',
        () async {
          final directory = await Directory.systemTemp.createTemp(
            'journal-recovery',
          );
          addTearDown(() => directory.delete(recursive: true));
          final file = File('${directory.path}/journal.db');
          await file.writeAsBytes(
            gzip.decode(
              File(
                'test/journal/fixtures/${creating ? 'legacy-create-range-v28.sqlite.gz' : 'legacy-range-v28.sqlite.gz'}',
              ).readAsBytesSync(),
            ),
          );
          var db = AppDatabase(NativeDatabase(file));
          addTearDown(() => db.close());
          var repository = JournalRepository(db);
          final entries = await repository.watchEntries().first;
          final selected = entries.singleWhere(
            (entry) => entry.uid != 'sibling' && entry.recurrenceIdKey == null,
          );
          final snapshot = await repository.read(selected);
          expect(snapshot.component.title, 'Series');
          final recovery = snapshot.pendingRecovery!;
          final operation = (await db.select(db.pendingOps).get()).single;
          expect(operation.state, 'pending');
          final bundle = jsonDecode(jsonEncode(recovery.toJson())) as Map;
          expect(bundle['requestJson'], operation.requestJson);
          expect(
            bundle['operationType'],
            creating ? 'dav.create' : 'dav.update',
          );
          if (creating) {
            expect(
              (jsonDecode(operation.requestJson) as Map)['rawIcs'],
              recovery.invalidCandidate,
            );
            expect(operation.baselineEtag, isNull);
          }
          expect(bundle['mutationPatchJson'], operation.mutationPatchJson);
          expect(bundle['baselineIcs'], operation.baselineRawIcs);
          expect(bundle['invalidCandidateIcs'], recovery.invalidCandidate);
          expect(
            recovery.invalidCandidate,
            contains('SUMMARY:Offline future edit'),
          );
          expect(
            recovery.invalidCandidate,
            contains('SUMMARY:Original detached entry'),
          );
          final detached = IcalSemanticDocument.parse(recovery.invalidCandidate)
              .components
              .where((item) => item.recurrenceId != null)
              .toList();
          expect(detached.map((item) => item.recurrenceId!.rawValue), [
            '20261127',
            '20261127',
          ]);
          final exported = await DavNativeExportService(db)
              .collectionForReview('account', 'source');
          expect(exported.resources.map((entry) => entry.uid), ['sibling']);
          expect(exported.pendingJournalRecoveries.single.toJson(), bundle);
          final source = db.update(db.davCollections)
            ..where((row) => row.id.equals('source'));
          await source.write(
            const DavCollectionsCompanion(
              journalInventoryComplete: Value(false),
            ),
          );
          await expectLater(
            repository.read(selected),
            throwsA(
              isA<DavException>().having(
                (error) => error.code,
                'code',
                'DavJournalRecoveryRequiresFullAccess',
              ),
            ),
          );
          final restricted = await DavNativeExportService(db)
              .collectionForReview('account', 'source');
          expect(restricted.excludedJournalCount, 1);
          expect(restricted.pendingJournalRecoveries, isEmpty);
          expect(restricted.resources.map((entry) => entry.uid), ['sibling']);
          await source.write(
            const DavCollectionsCompanion(
              journalInventoryComplete: Value(true),
            ),
          );

          await (db.update(db.accounts)
                ..where((row) => row.id.equals('account')))
              .write(const AccountsCompanion(authState: Value('signed_in')));
          if (attempt) {
            await (db.update(
              db.pendingOps,
            )..where((row) => row.id.equals(operation.id))).write(
              PendingOpsCompanion(
                state: const Value('in_progress'),
                retryClassification: const Value('transient'),
                // A crash during the first dispatch can leave the count at 0.
                attemptCount: Value(creating ? 0 : 1),
              ),
            );
          }
          await repository.create(
            snapshot.collection,
            title: 'Dependent operation',
          );
          await (db.update(db.pendingOps)
                ..where((row) => row.id.isNotValue(operation.id)))
              .write(PendingOpsCompanion(dependsOnOpId: Value(operation.id)));
          final uri = Uri.parse('https://example.invalid/');
          final requests = <String>[];
          var saved = '';
          var appearedOnServer = attempt;
          final client = MockClient((request) async {
            expect(request.url.path, operation.davMemberHref);
            requests.add(request.method);
            if (request.method == 'PUT') {
              if (creating) {
                expect(request.headers['if-none-match'], '*');
              } else {
                expect(request.headers['if-match'], operation.baselineEtag);
              }
              saved = request.body;
              return http.Response('', creating ? 201 : 204);
            }
            expect(request.method, 'GET');
            if (appearedOnServer) {
              return http.Response(
                recovery.invalidCandidate,
                200,
                headers: {
                  'etag': '"attempted"',
                  'content-type': 'text/calendar',
                },
              );
            }
            if (saved.isEmpty) {
              return creating
                  ? http.Response('', 404)
                  : http.Response(
                      operation.baselineRawIcs!,
                      200,
                      headers: {
                        'etag': operation.baselineEtag!,
                        'content-type': 'text/calendar',
                      },
                    );
            }
            return http.Response(
              saved,
              200,
              headers: {
                'etag': '"new-legacy"',
                'content-type': 'text/calendar',
              },
            );
          });
          final transport = DavHttpTransport(
            client: client,
            profile: davProviderProfile(BusyProvider.caldav, caldavServer: uri),
            accountAuthority: uri,
          );
          Future<DavReplaySummary> replay() => DavPendingOperationsReplayer(
            database: db,
            accountId: 'account',
            serviceFactory: ({required account, required collection}) async =>
                DavConditionalMutationService(
                  remoteClient: DavMutationHttpClient(
                    transport: transport,
                    accountId: account.id,
                    collectionId: collection.id,
                    credential: DavBasicCredential(
                      username: 'fixture',
                      password: 'fixture',
                    ),
                  ),
                ),
          ).replayDueOperations(operationIds: {operation.id});
          expect((await replay()).appliedCount, 0);
          expect(requests, attempt ? ['GET'] : isEmpty);
          await db.close();

          db = AppDatabase(NativeDatabase(file));
          repository = JournalRepository(db);
          var reopened = (await repository.read(selected)).pendingRecovery!;
          expect(
            reopened.operation.lastErrorCode,
            duplicateJournalPositionCode,
          );
          expect(reopened.operation.state, 'failed');
          expect(reopened.invalidCandidate, recovery.invalidCandidate);
          expect(
            reopened.operation.mutationPatchJson,
            operation.mutationPatchJson,
          );
          expect(reopened.operation.requestJson, operation.requestJson);
          await expectLater(
            repository.repairPendingUpdate(reopened, {}),
            throwsA(isA<Exception>()),
          );
          final range = detached.singleWhere(
            (item) => item.recurrenceRange != null,
          );
          if (attempt) {
            expect(reopened.canReplace, isFalse);
            final choice = {
              journalRecurrencePosition(range.recurrenceId): detached.indexOf(
                range,
              ),
            };
            await expectLater(
              repository.repairPendingUpdate(reopened, choice),
              throwsA(isA<DavException>()),
            );
            expect(reopened.canCheckServer, isTrue);
            appearedOnServer = false;
            await DavPendingOperationQueue(database: db).retryBlockedOperation(
              accountId: 'account',
              operationId: operation.id,
            );
            expect((await replay()).appliedCount, 0);
            expect(requests, ['GET', 'GET']);
            reopened = (await repository.read(selected)).pendingRecovery!;
            expect(reopened.canReplace, isTrue);
            expect(reopened.operation.attemptCount, creating ? 0 : 1);
          }
          await repository.repairPendingUpdate(reopened, {
            journalRecurrencePosition(range.recurrenceId): detached.indexOf(
              range,
            ),
          });
          final repaired = await repository.read(selected);
          expect(repaired.pendingRecovery, isNull);
          expect(
            repaired.effectiveRawIcs,
            contains('SUMMARY:Offline future edit'),
          );
          expect(
            repaired.effectiveRawIcs,
            isNot(contains('SUMMARY:Original detached entry')),
          );
          final operations = await db.select(db.pendingOps).get();
          expect(
            operations.singleWhere((op) => op.id == operation.id).state,
            'pending',
          );
          expect(
            operations.singleWhere((op) => op.id != operation.id).dependsOnOpId,
            operation.id,
          );
          expect((await replay()).appliedCount, 1);
          expect(
            requests,
            attempt ? ['GET', 'GET', 'GET', 'PUT', 'GET'] : ['PUT', 'GET'],
          );
          expect(saved, repaired.effectiveRawIcs);
          final remaining = (await db.select(db.pendingOps).get()).single;
          expect(remaining.operationType, 'dav.create');
        },
      );
    }
  }

  test(
    'a historical journal move candidate is quarantined before dispatch',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'journal-move-recovery',
      );
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/journal.db');
      await file.writeAsBytes(
        gzip.decode(
          File('test/journal/fixtures/legacy-range-v28.sqlite.gz')
              .readAsBytesSync(),
        ),
      );
      final db = AppDatabase(NativeDatabase(file));
      addTearDown(db.close);
      await db
          .update(db.accounts)
          .write(const AccountsCompanion(authState: Value('signed_in')));
      await db
          .update(db.pendingOps)
          .write(
            const PendingOpsCompanion(
              operation: Value('dav_move'),
              operationType: Value('dav.move'),
              requestJson: Value('{"isEvent":false}'),
            ),
          );
      final replayer = DavPendingOperationsReplayer(
        database: db,
        accountId: 'account',
        serviceFactory: ({required account, required collection}) async =>
            throw TestFailure(
              'Invalid journal move reached the mutation service.',
            ),
      );
      expect((await replayer.replayDueOperations()).appliedCount, 0);
      final blocked = await db.select(db.pendingOps).getSingle();
      expect(blocked.state, 'failed');
      expect(blocked.lastErrorCode, duplicateJournalPositionCode);
      final repository = JournalRepository(db);
      final selected = (await repository.watchEntries().first).singleWhere(
        (entry) => entry.uid == 'legacy' && entry.recurrenceIdKey == null,
      );
      final recovery = (await repository.read(selected)).pendingRecovery!;
      expect(recovery.canReplace, isFalse);
      expect(recovery.toJson()['operationType'], 'dav.move');
      expect(
        recovery.invalidCandidate,
        contains('SUMMARY:Offline future edit'),
      );
    },
  );

  test('the Nextcloud controller exports valid siblings and a separate recovery bundle', () async {
    final directory = await Directory.systemTemp.createTemp('journal-export');
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/journal.db');
    await file.writeAsBytes(
      gzip.decode(
        File('test/journal/fixtures/legacy-create-range-v28.sqlite.gz')
            .readAsBytesSync(),
      ),
    );
    final db = AppDatabase(NativeDatabase(file));
    addTearDown(db.close);
    await db
        .update(db.accounts)
        .write(
          const AccountsCompanion(
            provider: Value('nextcloud'),
            credentialKind: Value('nextcloud_app_password'),
          ),
        );
    await db
        .update(db.davCollections)
        .write(const DavCollectionsCompanion(supportedComponentMask: Value(9)));
    const event =
        'BEGIN:VCALENDAR\r\nVERSION:2.0\r\nPRODID:-//Fixture//EN\r\n'
        'BEGIN:VEVENT\r\nUID:control\r\nDTSTAMP:20261125T080000Z\r\n'
        'DTSTART:20261126T090000Z\r\nSUMMARY:Event control\r\n'
        'END:VEVENT\r\nEND:VCALENDAR\r\n';
    await DavObjectRepository(database: db).commitConfirmedMutation(
      accountId: 'account',
      collectionId: 'source',
      provider: BusyProvider.nextcloud,
      canonicalObject: DavPreparedObject.parse(
        hrefKey: '/journals/control.ics',
        requestUri: Uri.parse('https://example.invalid/journals/control.ics'),
        etag: '"control"',
        contentType: 'text/calendar',
        rawIcsBody: event,
      ),
      completedAtUtc: DateTime.utc(2026, 11, 26),
    );
    final operation = (await db.select(db.pendingOps).get()).single;
    final api = NextcloudAdminFixture(database: db);
    final controller = NextcloudCollectionController(api.sharing, 'source');
    addTearDown(controller.dispose);
    Future<Directory> save({required bool exportRecovery}) async {
      String? path;
      await controller.exportTo((snapshot) async {
        expect(snapshot.excludedJournalCount, 1);
        expect(
          snapshot.resources.map((resource) => resource.uid),
          unorderedEquals(['control', 'sibling']),
        );
        expect(
          snapshot.pendingJournalRecoveries,
          exportRecovery ? hasLength(1) : isEmpty,
        );
        path = await exportDavCollectionWithDirectoryDialog(
          snapshot,
          chooseDirectory: () async => directory.path,
        );
      });
      expect(controller.error, isNull);
      return Directory(path!);
    }

    final exported = await save(exportRecovery: true);
    final files = exported.listSync().whereType<File>().toList();
    final calendars = files.where((file) => file.path.endsWith('.ics'));
    expect(
      calendars.map(
        (file) =>
            IcalSemanticDocument.parse(file.readAsStringSync()).primaryUid,
      ),
      unorderedEquals(['control', 'sibling']),
    );
    final recovery = jsonDecode(
      files
          .singleWhere((file) => file.path.endsWith('/journal-recovery-1.json'))
          .readAsStringSync(),
    ) as Map;
    expect(recovery['requestJson'], operation.requestJson);
    expect(
      recovery['invalidCandidateIcs'],
      (jsonDecode(operation.requestJson) as Map)['rawIcs'],
    );
    await expectLater(
      DavNativeExportService(db).collection('account', 'source'),
      throwsStateError,
    );
    await db
        .update(db.davCollections)
        .write(
          const DavCollectionsCompanion(journalInventoryComplete: Value(false)),
        );
    final restricted = await save(exportRecovery: false);
    expect(
      restricted.listSync().where((file) => file.path.endsWith('.json')),
      isEmpty,
    );
    expect(api.requests, isEmpty);
  });
}

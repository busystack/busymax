import 'dart:convert';
import 'dart:io';

import 'package:busymax/src/dav/dav_provider_profile.dart';
import 'package:busymax/src/dav/http/dav_http_transport.dart';
import 'package:busymax/src/dav/ical/dav_native_export.dart';
import 'package:busymax/src/dav/ical/ical_semantics.dart';
import 'package:busymax/src/dav/mutation/dav_conditional_mutation_service.dart';
import 'package:busymax/src/dav/mutation/dav_pending_operations.dart';
import 'package:busymax/src/db/app_database.dart';
import 'package:busymax/src/journal/journal_component.dart';
import 'package:busymax/src/journal/journal_repository.dart';
import 'package:busymax/src/providers/busy_provider.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test(
    'a former release journal update is still readable and exportable',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'journal-recovery',
      );
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/journal.db');
      await file.writeAsBytes(
        gzip.decode(
          File('test/journal/fixtures/legacy-range-v28.sqlite.gz')
              .readAsBytesSync(),
        ),
      );
      var db = AppDatabase(NativeDatabase(file));
      addTearDown(() => db.close());
      var repository = JournalRepository(db);
      final entries = await repository.watchEntries().first;
      final selected = entries.singleWhere(
        (entry) => entry.uid == 'legacy' && entry.recurrenceIdKey == null,
      );
      final snapshot = await repository.read(selected);
      expect(snapshot.component.title, 'Series');
      final recovery = snapshot.pendingRecovery!;
      final operation = (await db.select(db.pendingOps).get()).single;
      expect(operation.state, 'pending');
      final bundle = jsonDecode(jsonEncode(recovery.toJson())) as Map;
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

      await (db.update(db.accounts)..where((row) => row.id.equals('account')))
          .write(const AccountsCompanion(authState: Value('signed_in')));
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
      final client = MockClient((request) async {
        expect(request.url.path, '/journals/legacy.ics');
        requests.add(request.method);
        if (request.method == 'PUT') {
          expect(request.headers['if-match'], operation.baselineEtag);
          saved = request.body;
          return http.Response('', 204);
        }
        expect(request.method, 'GET');
        return http.Response(
          saved,
          200,
          headers: {'etag': '"new-legacy"', 'content-type': 'text/calendar'},
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
      expect(requests, isEmpty);
      await db.close();

      db = AppDatabase(NativeDatabase(file));
      repository = JournalRepository(db);
      final reopened = (await repository.read(selected)).pendingRecovery!;
      expect(reopened.operation.lastErrorCode, duplicateJournalPositionCode);
      expect(reopened.operation.state, 'failed');
      expect(reopened.invalidCandidate, recovery.invalidCandidate);
      expect(reopened.operation.mutationPatchJson, operation.mutationPatchJson);
      await expectLater(
        repository.repairPendingUpdate(reopened, {}),
        throwsA(isA<Exception>()),
      );
      final range = detached.singleWhere(
        (item) => item.recurrenceRange != null,
      );
      await repository.repairPendingUpdate(reopened, {
        journalRecurrencePosition(range.recurrenceId): detached.indexOf(range),
      });
      final repaired = await repository.read(selected);
      expect(repaired.pendingRecovery, isNull);
      expect(repaired.effectiveRawIcs, contains('SUMMARY:Offline future edit'));
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
      expect(requests, ['PUT', 'GET']);
      expect(saved, repaired.effectiveRawIcs);
      final remaining = (await db.select(db.pendingOps).get()).single;
      expect(remaining.operationType, 'dav.create');
    },
  );
}

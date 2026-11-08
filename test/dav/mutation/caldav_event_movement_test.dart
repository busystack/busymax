import 'package:busymax/src/dav/sync/dav_account_sync_engine.dart';

import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';

import '../../support/persistence_test_directory.dart';

import 'package:busymax/src/dav/dav_provider_profile.dart';
import 'package:busymax/src/dav/http/dav_http_transport.dart';
import 'package:busymax/src/dav/mutation/dav_conditional_mutation_service.dart';
import 'package:busymax/src/dav/mutation/dav_pending_operations.dart';
import 'package:busymax/src/dav/storage/dav_object_repository.dart';
import 'package:busymax/src/db/app_database.dart';
import 'package:busymax/src/features/calendar/data/calendar_repository.dart';
import 'package:busymax/src/features/calendar/presentation/event_editor_draft.dart';
import 'package:busymax/src/providers/busy_provider.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  late _Fixture f;
  Directory? transferDirectory;
  setUp(() {
    f = _Fixture();
  });
  tearDown(() async {
    await f.db.close();
    await transferDirectory?.delete(recursive: true);
    transferDirectory = null;
  });

  test('transfer restarts after PUT and after confirmation without losing the source or duplicating the copy', () async {
    await f.db.close();
    transferDirectory = await createPersistenceTestDirectory(
      'busymax-transfer-',
    );
    final file = File('${transferDirectory!.path}/state.sqlite');
    f = _Fixture(database: AppDatabase(NativeDatabase(file)));
    await f.seed(crossAccount: true, differentServer: true, meeting: false);
    await f.move();
    f.failReadback = true;
    expect((await f.replay(f.destinationAccount)).appliedCount, 0);
    expect(f.resources[f.sourceUri.toString()], f.raw);
    await f.reopen(file);
    f.failReadback = false;
    f.now = f.now.add(const Duration(days: 1));
    expect((await f.replay(f.destinationAccount)).appliedCount, 1);
    expect(f.methods.where((m) => m == 'PUT'), hasLength(1));
    expect(f.resources[f.sourceUri.toString()], f.raw);
    await f.reopen(file);
    expect((await f.replay('source')).appliedCount, 1);
    expect(f.methods.where((m) => m == 'DELETE'), hasLength(1));
    expect(f.resources.values.single, f.raw);
  });

  test(
    'transfer accepts known server metadata normalization before deletion',
    () async {
      await f.seed(crossAccount: true, differentServer: true, meeting: false);
      await f.move();
      f.transformCreate = (raw) => raw.replaceFirst(
        'END:VEVENT',
        'LAST-MODIFIED:20261108T000000Z\r\nSEQUENCE:2\r\nEND:VEVENT',
      );
      expect((await f.replay(f.destinationAccount)).appliedCount, 1);
      expect((await f.replay('source')).appliedCount, 1);
      expect(f.methods.where((m) => m == 'DELETE'), hasLength(1));
      expect(f.resources.values.single, contains('X-EXCEPTION:keep'));
      expect(f.resources.values.single, contains('DESCRIPTION:Custom'));
    },
  );
  for (final crossAccount in [false, true]) {
    for (final organizer in [false, true]) {
      test(
        'native MOVE preserves complete ${organizer ? 'organizer' : 'attendee'} series, cross-account=$crossAccount',
        () async {
          await f.seed(crossAccount: crossAccount, organizer: organizer);
          final sources = await f.repository.listVisibleSources(
            {'source', f.destinationAccount}.toList(),
          );
          expect(
            sources.map((source) => source.davSchedulingPrincipal).toSet(),
            {Uri.parse('https://dav.example.test/principals/user')},
          );
          await f.move();
          final op = await f.db.select(f.db.pendingOps).getSingle();
          expect(op.operationType, 'dav.move');
          expect(
            jsonDecode(op.requestJson)['destinationAccountId'],
            f.destinationAccount,
          );
          final replay = await f.replay('source');
          expect(replay.appliedCount, 1);
          final notificationAccounts = <String>[];
          await rebuildDavAffectedAccountNotifications(
            database: f.db,
            accountId: 'source',
            affectedObjectIds: replay.affectedObjectIds,
            rebuild: (id, _) async => notificationAccounts.add(id),
          );
          expect(notificationAccounts.toSet(), {
            'source',
            f.destinationAccount,
          });
          expect(f.methods, ['MOVE', 'GET']);
          expect(f.resources.values.single, f.raw);
          expect(f.schedulingMessages, 0);
          final destination = await f.objects.liveObjects('destination');
          expect(destination.single.rawIcsBody, f.raw);
          expect(destination.single.accountId, f.destinationAccount);
          expect(await f.objects.liveObjects('original'), isEmpty);
          final rows = await f.db.select(f.db.calendarEvents).get();
          expect(
            rows
                .where((row) => !row.isDeleted)
                .every((row) => row.accountId == f.destinationAccount),
            isTrue,
          );
          expect(await f.db.select(f.db.pendingOps).get(), isEmpty);
        },
      );
    }
  }

  for (final status in [403, 405, 501]) {
    test('MOVE rejection $status never falls back to PUT/DELETE', () async {
      await f.seed(crossAccount: true);
      f.moveStatus = status;
      await f.move();
      expect((await f.replay('source')).appliedCount, 0);
      expect(f.methods, ['MOVE']);
      expect(f.resources.keys, [f.sourceUri.toString()]);
      final op = await f.db.select(f.db.pendingOps).getSingle();
      expect(op.state, status == 403 ? 'permission_blocked' : 'failed');
      expect(f.schedulingMessages, 0);
    });
  }

  for (final problem in [
    'unsupported',
    'source-denied',
    'destination-denied',
  ]) {
    test('$problem is rejected before queueing a native move', () async {
      await f.seed();
      await (f.db.update(f.db.davCollections)..where(
            (r) => r.id.equals(
              problem == 'destination-denied' ? 'destination' : 'original',
            ),
          ))
          .write(
            DavCollectionsCompanion(
              safeDisplayMetadataJson: problem == 'unsupported'
                  ? const Value('{"supportsMove":"false"}')
                  : const Value.absent(),
              currentUserPrivilegesJson: problem == 'unsupported'
                  ? const Value.absent()
                  : const Value('["{DAV:}read"]'),
            ),
          );
      await expectLater(f.move(), throwsA(isA<Object>()));
      expect(await f.db.select(f.db.pendingOps).get(), isEmpty);
      expect(f.methods, isEmpty);
    });
  }

  for (final problem in [
    'different-principal',
    'different-server',
    'unknown-owner',
    'exception-only-meeting',
  ]) {
    test('$problem meeting requires explicit scheduling transfer', () async {
      await f.seed(
        crossAccount: true,
        differentServer: problem == 'different-server',
        exceptionOnlyMeeting: problem == 'exception-only-meeting',
      );
      await (f.db.update(
        f.db.davCollections,
      )..where((r) => r.id.equals('destination'))).write(
        DavCollectionsCompanion(
          ownerHref: Value(
            problem == 'unknown-owner' ? null : '/principals/other/',
          ),
        ),
      );
      await expectLater(f.move(), throwsA(isA<Object>()));
      expect(await f.db.select(f.db.pendingOps).get(), isEmpty);
      expect(f.methods, isEmpty);
      expect(f.resources.values.single, f.raw);
    });
  }

  test(
    'rediscovered scheduling identity is checked again before replay',
    () async {
      await f.seed(crossAccount: true);
      await f.move();
      await (f.db.update(
        f.db.davCollections,
      )..where((r) => r.id.equals('destination'))).write(
        const DavCollectionsCompanion(ownerHref: Value('/principals/other/')),
      );
      expect((await f.replay('source')).appliedCount, 0);
      expect(f.methods, isEmpty);
      expect(f.resources.values.single, f.raw);
    },
  );

  test(
    'interrupted destination readback reconciles without repeating MOVE',
    () async {
      await f.seed(crossAccount: true);
      await f.move();
      f.failReadback = true;
      expect((await f.replay('source')).appliedCount, 0);
      expect(f.methods.where((m) => m == 'MOVE'), hasLength(1));
      final pending = await f.db.select(f.db.pendingOps).getSingle();
      expect(isDavPartiallyCompletedMove(pending), isTrue);
      f.failReadback = false;
      f.now = f.now.add(const Duration(days: 1));
      expect((await f.replay('source')).appliedCount, 1);
      expect(f.methods.where((m) => m == 'MOVE'), hasLength(1));
      expect(f.methods.where((m) => m == 'PUT' || m == 'DELETE'), isEmpty);
      expect(
        (await f.objects.liveObjects('destination')).single.rawIcsBody,
        f.raw,
      );
    },
  );

  test(
    'revoked MOVE support after queueing causes no network writes',
    () async {
      await f.seed();
      await f.move();
      await (f.db.update(
        f.db.davCollections,
      )..where((r) => r.id.equals('original'))).write(
        const DavCollectionsCompanion(
          safeDisplayMetadataJson: Value('{"supportsMove":"false"}'),
        ),
      );
      expect((await f.replay('source')).appliedCount, 0);
      expect(f.methods, isEmpty);
    },
  );

  test('lost MOVE response reconciles a cross-account meeting without replaying MOVE', () async {
    await f.seed(crossAccount: true);
    await f.move();
    f.loseMoveResponse = true;
    expect((await f.replay('source')).appliedCount, 1);
    expect(f.methods.where((m) => m == 'MOVE'), hasLength(1));
    expect(f.methods.where((m) => m == 'PUT' || m == 'DELETE'), isEmpty);
    expect(
      (await f.objects.liveObjects('destination')).single.rawIcsBody,
      f.raw,
    );
  });

  for (final crossAccount in [false, true]) {
    test(
      'meeting move cannot change the calendar owner, cross-account=$crossAccount',
      () async {
        await f.seed(crossAccount: crossAccount);
        await (f.db.update(
          f.db.davCollections,
        )..where((r) => r.id.equals('destination'))).write(
          const DavCollectionsCompanion(ownerHref: Value('/principals/other/')),
        );
        await expectLater(f.move(), throwsA(isA<Object>()));
        expect(f.methods, isEmpty);
        expect(await f.db.select(f.db.pendingOps).get(), isEmpty);
      },
    );
  }

  test('destination account replacement invalidates a queued MOVE', () async {
    await f.seed(crossAccount: true);
    await f.move();
    await (f.db.update(
      f.db.accounts,
    )..where((r) => r.id.equals(f.destinationAccount))).write(
      const AccountsCompanion(
        authority: Value('https://replacement.example.test/'),
      ),
    );
    expect((await f.replay('source')).appliedCount, 0);
    expect(f.methods, isEmpty);
  });

  for (final exception in [false, true]) {
    test(
      'personal occurrence transfer preserves effective raw fields, exception=$exception',
      () async {
        await f.seed(crossAccount: true, differentServer: true, meeting: false);
        if (exception) {
          f.eventId = (await f.db.select(f.db.calendarEvents).get())
              .firstWhere((r) => r.title == 'Exception')
              .id;
        }
        await f.move(scope: RecurringEventMutationScope.singleOccurrence);
        final create = (await f.db.select(f.db.pendingOps).get()).singleWhere(
          (op) => op.operationType == 'dav.create',
        );
        final copied = jsonDecode(create.requestJson)['rawIcs'] as String;
        expect(copied, contains('UID:meeting'));
        expect(copied, contains('X-CALENDAR:retained'));
        expect(copied, contains('X-EVENT;X-PARAM=retained:keep'));
        expect(copied, contains('DESCRIPTION:Custom\r\nX-ALARM:keep'));
        expect(copied, isNot(contains('RECURRENCE-ID')));
        expect(copied, isNot(contains('RRULE')));
        expect('BEGIN:VEVENT'.allMatches(copied), hasLength(1));
        if (exception) expect(copied, contains('X-EXCEPTION:keep'));
        expect((await f.replay(f.destinationAccount)).appliedCount, 1);
        expect((await f.replay('source')).appliedCount, 1);
        expect(f.methods.where((m) => m == 'MOVE' || m == 'DELETE'), isEmpty);
        expect(
          f.resources[f.sourceUri.toString()],
          contains('STATUS:CANCELLED'),
        );
      },
    );
  }

  for (final loss in [
    'description',
    'alarm',
    'rrule',
    'exception',
    'extension',
  ]) {
    test(
      'personal transfer retains original after $loss loss with scheduling enabled',
      () async {
        await f.seed(crossAccount: true, differentServer: true, meeting: false);
        await f.move();
        f.transformCreate = (raw) => switch (loss) {
          'description' => raw.replaceFirst('DESCRIPTION:Custom\r\n', ''),
          'alarm' => raw.replaceFirst(
            RegExp(r'BEGIN:VALARM[\s\S]*?END:VALARM\r\n'),
            '',
          ),
          'rrule' => raw.replaceFirst('RRULE:FREQ=DAILY;COUNT=2\r\n', ''),
          'exception' => raw.replaceFirst(
            RegExp(
              r'BEGIN:VEVENT\r\nUID:meeting\r\nRECURRENCE-ID:[\s\S]*?END:VEVENT\r\n',
            ),
            '',
          ),
          _ => raw.replaceFirst('X-EXCEPTION:keep', 'X-EXCEPTION:lost'),
        };
        expect((await f.replay(f.destinationAccount)).conflictCount, 1);
        expect((await f.replay('source')).appliedCount, 0);
        // A fresh replayer must also preserve the durable dependency barrier.
        f.now = f.now.add(const Duration(days: 1));
        expect((await f.replay('source')).appliedCount, 0);
        expect(f.methods.where((m) => m == 'DELETE'), isEmpty);
        expect(f.resources[f.sourceUri.toString()], f.raw);
      },
    );
  }

  for (final failCopy in [false, true]) {
    test(
      'personal cross-server transfer preserves raw series and confirms copy before deletion, failure=$failCopy',
      () async {
        await f.seed(crossAccount: true, differentServer: true, meeting: false);
        await f.move();
        final ops = await f.db.select(f.db.pendingOps).get();
        final create = ops.singleWhere(
          (op) => op.operationType == 'dav.create',
        );
        final deletion = ops.singleWhere(
          (op) => op.operationType == 'dav.delete',
        );
        expect(jsonDecode(create.requestJson)['rawIcs'], f.raw);
        expect(deletion.dependsOnOpId, create.id);
        expect((await f.replay('source')).appliedCount, 0);
        expect(f.methods, isEmpty);
        f.failCreate = failCopy;
        expect(
          (await f.replay(f.destinationAccount)).appliedCount,
          failCopy ? 0 : 1,
        );
        expect((await f.replay('source')).appliedCount, failCopy ? 0 : 1);
        expect(f.methods.where((m) => m == 'MOVE'), isEmpty);
        expect(
          f.methods.where((m) => m == 'DELETE'),
          hasLength(failCopy ? 0 : 1),
        );
        if (failCopy) {
          expect(f.resources[f.sourceUri.toString()], f.raw);
        } else {
          expect(f.resources.values.single, f.raw);
          expect(
            (await f.objects.liveObjects('destination')).single.rawIcsBody,
            f.raw,
          );
          expect(await f.db.select(f.db.pendingOps).get(), isEmpty);
        }
      },
    );
  }
}

class _Fixture {
  _Fixture({AppDatabase? database})
    : db = database ?? AppDatabase.memoryForTests();
  AppDatabase db;
  late DavObjectRepository objects = DavObjectRepository(database: db);
  late CalendarRepository repository = CalendarRepository(
    database: db,
    localTimeZone: 'UTC',
    now: () => now,
  );
  var now = DateTime.utc(2026, 11, 5);
  var destinationAccount = 'source';
  final sourceUri = Uri.parse('https://dav.example.test/original/event.ics');
  late Uri destinationUri;
  late String raw;
  late String eventId;
  final resources = <String, String>{};
  final methods = <String>[];
  var moveStatus = 201;
  var failReadback = false,
      failCreate = false,
      loseMoveResponse = false,
      corruptCreate = false;
  String Function(String)? transformCreate;
  var schedulingMessages = 0;

  Future<void> reopen(File file) async {
    await db.close();
    db = AppDatabase(NativeDatabase(file));
    objects = DavObjectRepository(database: db);
    repository = CalendarRepository(
      database: db,
      localTimeZone: 'UTC',
      now: () => now,
    );
  }

  Future<void> seed({
    bool crossAccount = false,
    bool differentServer = false,
    bool organizer = true,
    bool meeting = true,
    bool exceptionOnlyMeeting = false,
  }) async {
    destinationAccount = crossAccount ? 'other-account' : 'source';
    final origin = differentServer
        ? 'https://other.example.test'
        : 'https://dav.example.test';
    destinationUri = Uri.parse('$origin/destination/event.ics');
    for (final id in {'source', destinationAccount}) {
      await db
          .into(db.accounts)
          .insert(
            AccountsCompanion.insert(
              id: id,
              provider: 'caldav',
              authority: id == 'source'
                  ? 'https://dav.example.test/'
                  : '$origin/',
              providerAccountId: 'user-$id',
              credentialKind: 'caldav_password',
              authState: const Value('signed_in'),
              createdAtUtc: now.toIso8601String(),
              updatedAtUtc: now.toIso8601String(),
            ),
          );
    }
    for (final (id, account, uri) in [
      ('original', 'source', sourceUri.resolve('.')),
      ('destination', destinationAccount, destinationUri.resolve('.')),
    ]) {
      await db
          .into(db.davCollections)
          .insert(
            DavCollectionsCompanion.insert(
              id: id,
              accountId: account,
              hrefKey: uri.path,
              requestUri: uri.toString(),
              displayName: id,
              ownerHref: const Value('/principals/user/'),
              supportedComponentMask: const Value(1),
              currentUserPrivilegesJson: const Value(
                '["{DAV:}read","{DAV:}write"]',
              ),
              safeDisplayMetadataJson: const Value('{"supportsMove":"true"}'),
              readOnly: const Value(false),
              eventProjectionEnabled: const Value(true),
              createdAtUtc: now.toIso8601String(),
              updatedAtUtc: now.toIso8601String(),
            ),
          );
      await db
          .into(db.calendarSources)
          .insert(
            CalendarSourcesCompanion.insert(
              id: 'dav-calendar-$id',
              accountId: account,
              provider: 'caldav',
              providerCalendarId: uri.path,
              davCollectionId: Value(id),
              summary: id,
              createdAtLocal: 0,
              updatedAtLocal: 0,
            ),
          );
    }
    final scheduling = meeting
        ? 'ORGANIZER:mailto:${organizer ? 'user' : 'host'}@example.test\r\nATTENDEE;PARTSTAT=ACCEPTED;X-CUSTOM=retained:mailto:${organizer ? 'guest' : 'user'}@example.test\r\n'
        : '';
    raw =
        'BEGIN:VCALENDAR\r\nVERSION:2.0\r\nX-CALENDAR:retained\r\nBEGIN:VEVENT\r\nUID:meeting\r\nDTSTART:20261110T090000Z\r\nDTEND:20261110T100000Z\r\nSUMMARY:Move me\r\nRRULE:FREQ=DAILY;COUNT=2\r\nX-EVENT;X-PARAM=retained:keep\r\n${exceptionOnlyMeeting ? '' : scheduling}BEGIN:VALARM\r\nACTION:DISPLAY\r\nTRIGGER:-PT0M\r\nDESCRIPTION:Custom\r\nX-ALARM:keep\r\nEND:VALARM\r\nEND:VEVENT\r\nBEGIN:VEVENT\r\nUID:meeting\r\nRECURRENCE-ID:20261111T090000Z\r\nDTSTART:20261111T110000Z\r\nDTEND:20261111T120000Z\r\nSUMMARY:Exception\r\n${scheduling}X-EXCEPTION:keep\r\nEND:VEVENT\r\nEND:VCALENDAR\r\n';
    resources[sourceUri.toString()] = raw;
    final prepared = DavPreparedObject.parse(
      hrefKey: sourceUri.path,
      requestUri: sourceUri,
      etag: '"one"',
      contentType: 'text/calendar',
      rawIcsBody: raw,
    );
    await objects.commit(
      DavCollectionCommit(
        accountId: 'source',
        collectionId: 'original',
        provider: BusyProvider.caldav,
        objects: [prepared],
        deletedHrefKeys: const {},
        completeMembership: true,
        membershipHrefKeys: {sourceUri.path},
        finalCursorKind: 'dav_sync_token',
        finalCursorValue: 'one',
        baselineGeneration: 1,
        completedAtUtc: now,
        projectionRangeStartUtc: DateTime.utc(2026),
        projectionRangeEndUtc: DateTime.utc(2027),
      ),
    );
    eventId = (await db.select(db.calendarEvents).get())
        .firstWhere((row) => row.title == 'Move me')
        .id;
  }

  Future<void> move({
    RecurringEventMutationScope scope =
        RecurringEventMutationScope.entireSeries,
  }) async {
    final detail = (await repository.loadEventDetail(eventId))!;
    await repository.updateLocalEvent(
      EventEditorDraft.fromEventDetail(detail).copyWith(
        accountId: destinationAccount,
        sourceId: 'dav-calendar-destination',
        providerCalendarId: '/destination/',
        recurringMutationScope: scope,
      ),
    );
  }

  Future<DavReplaySummary> replay(
    String accountId,
  ) => DavPendingOperationsReplayer(
    database: db,
    accountId: accountId,
    objectRepository: objects,
    nowUtc: () => now,
    serviceFactory: ({required account, required collection}) async =>
        DavConditionalMutationService(
          nowUtc: () => now,
          implicitScheduling: true,
          remoteClient: DavMutationHttpClient(
            transport: DavHttpTransport(
              client: MockClient((request) async {
                methods.add(request.method);
                if (request.method == 'MOVE') {
                  expect(request.headers['overwrite'], 'F');
                  expect(request.headers['if-match'], '"one"');
                  if (moveStatus >= 400) return http.Response('', moveStatus);
                  resources[request.headers['destination']!] = resources.remove(
                    request.url.toString(),
                  )!;
                  if (loseMoveResponse) {
                    throw http.ClientException(
                      'Synthetic interrupted MOVE response',
                    );
                  }
                  return http.Response('', moveStatus);
                }
                if (request.method == 'PUT') {
                  if (raw.contains('ORGANIZER:')) schedulingMessages++;
                  if (failCreate) return http.Response('', 403);
                  if (request.headers['if-none-match'] != null) {
                    expect(request.headers['if-none-match'], '*');
                  } else {
                    expect(request.headers['if-match'], '"one"');
                  }
                  resources[request.url.toString()] = transformCreate != null
                      ? transformCreate!(request.body)
                      : corruptCreate
                      ? request.body.replaceFirst(
                          'X-EXCEPTION:keep',
                          'X-EXCEPTION:lost',
                        )
                      : request.body;
                  return http.Response('', 201, headers: {'etag': '"two"'});
                }
                if (request.method == 'DELETE') {
                  if (raw.contains('ORGANIZER:')) schedulingMessages++;
                  resources.remove(request.url.toString());
                  return http.Response('', 204);
                }
                expect(request.method, 'GET');
                if (failReadback) return http.Response('', 503);
                final value = resources[request.url.toString()];
                return http.Response(
                  value ?? '',
                  value == null ? 404 : 200,
                  headers: {'etag': '"two"', 'content-type': 'text/calendar'},
                );
              }),
              profile: davProviderProfile(
                BusyProvider.caldav,
                caldavServer: Uri.parse(account.authority),
              ),
              accountAuthority: Uri.parse(account.authority),
            ),
            accountId: accountId,
            collectionId: collection.id,
            credential: DavBasicCredential(
              username: 'user',
              password: 'synthetic',
            ),
          ),
        ),
  ).replayDueOperations();
}

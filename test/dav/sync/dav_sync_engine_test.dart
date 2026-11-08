import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:busymax/src/dav/dav_provider_profile.dart';

import 'package:busymax/src/dav/dav_errors.dart';
import 'package:busymax/src/dav/http/dav_http_transport.dart';
import 'package:busymax/src/dav/ical/ical_document.dart';
import 'package:busymax/src/dav/mutation/dav_mutation_patch.dart';
import 'package:busymax/src/dav/mutation/dav_pending_operations.dart';
import 'package:busymax/src/dav/storage/dav_object_repository.dart';
import 'package:busymax/src/dav/storage/dav_projection_coverage_service.dart';
import 'package:busymax/src/dav/sync/dav_collection_remote_client.dart';
import 'package:busymax/src/dav/sync/dav_sync_engine.dart';
import 'package:busymax/src/db/app_database.dart';
import 'package:busymax/src/providers/busy_provider.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/persistence_test_directory.dart';

void main() {
  late AppDatabase database;
  late DavObjectRepository repository;
  var nextId = 0;
  Directory? fixtureDirectory;

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    repository = DavObjectRepository(
      database: database,
      idFactory: () => 'id-${nextId += 1}',
    );
  });

  tearDown(() async {
    // Own the currently open connection, including replacements after reopening.
    // addTearDown runs before regular tearDown, so directory removal belongs here.
    await database.close();
    final directory = fixtureDirectory;
    fixtureDirectory = null;
    if (directory != null) {
      await directory.delete(recursive: true);
      expect(await directory.exists(), isFalse);
    }
  });

  for (final scenario in [
    'resource404',
    'property404-get200',
    'property404-get404',
    'property404-get403',
    'property404-network',
    'missing-data',
    'missing-etag',
    'omitted',
    'identical-duplicate',
    'contradictory-duplicate',
    'cancelled',
    'malformed-get',
    'get-without-etag',
  ]) {
    test('multiget $scenario preserves durable state unless reconciled', () async {
      await database.close();
      final directory = await createPersistenceTestDirectory(
        'busymax-multiget-',
      );
      fixtureDirectory = directory;
      final file = File('${directory.path}/fixture.sqlite');
      database = AppDatabase(NativeDatabase(file));
      repository = DavObjectRepository(database: database);
      await _seedCollection(database, syncCollection: true);
      await _runInitial(database, repository, {
        'event.ics': ('"e1"', _event('event', 'Cached event')),
        'task.ics': (
          '"t1"',
          _event(
            'task',
            'Cached task',
          ).replaceAll('VEVENT', 'VTODO').replaceAll('DTEND', 'DUE'),
        ),
      }, token: 'urn:stable');
      final object = (await repository.liveObjects('collection'))
          .singleWhere((o) => o.hrefKey.endsWith('/task.ics'));
      await DavPendingOperationQueue(database: database).enqueueUpdate(
        accountId: 'account',
        collectionId: 'collection',
        objectId: object.id,
        patch: DavMutationPatch(
          target: IcalComponentKey(
            componentType: 'VTODO',
            uid: object.primaryUid!,
          ),
          scope: DavMutationScope.object,
          operations: [DavPatchOperation.setText('SUMMARY', 'Pending edit')],
        ),
      );
      final before = <String, List<Map<String, Object?>>>{};
      for (final table in [
        'dav_objects',
        'calendar_events',
        'tasks',
        'pending_ops',
      ]) {
        before[table] =
            (await database
                    .customSelect('SELECT * FROM $table ORDER BY id')
                    .get())
                .map((r) => r.data)
                .toList();
      }
      final token = DavCancellationToken();
      final requests = <String>[];
      final live =
          '<d:response><d:href>${_href('event.ics')}</d:href>'
          '<d:propstat><d:prop><d:getetag>"e2"</d:getetag>'
          '<c:calendar-data>${_event('event', 'Updated event')}</c:calendar-data>'
          '</d:prop><d:status>HTTP/1.1 200 OK</d:status></d:propstat></d:response>';
      final missing =
          '<d:response><d:href>${_href('event.ics')}</d:href>'
          '<d:status>HTTP/1.1 404 Not Found</d:status></d:response>';
      final property404 =
          '<d:response><d:href>${_href('event.ics')}</d:href>'
          '<d:propstat><d:prop><d:getetag/><c:calendar-data/></d:prop>'
          '<d:status>HTTP/1.1 404 Not Found</d:status></d:propstat></d:response>';
      final client = MockClient((request) async {
        requests.add(request.method);
        if (request.method == 'GET') {
          if (scenario == 'cancelled') token.cancel();
          if (scenario == 'property404-network') {
            throw http.ClientException('synthetic network failure');
          }
          if (scenario == 'property404-get403') return http.Response('', 403);
          if (scenario == 'property404-get404') return http.Response('', 404);
          return http.Response(
            scenario == 'malformed-get'
                ? 'not a calendar'
                : _event('event', 'Updated event'),
            200,
            headers: {
              if (scenario != 'get-without-etag') 'etag': '"e2"',
              'content-type': 'text/calendar',
            },
          );
        }
        if (request.body.contains('sync-collection')) {
          return http.Response(
            _wireSync(_wireChanged('event.ics', '"e2"'), 'urn:next'),
            207,
          );
        }
        final contents = switch (scenario) {
          'resource404' => missing,
          'omitted' => '',
          'missing-data' => live.replaceFirst(
            RegExp(r'<c:calendar-data>[\s\S]*?</c:calendar-data>'),
            '',
          ),
          'missing-etag' => live.replaceFirst(
            '<d:getetag>"e2"</d:getetag>',
            '',
          ),
          'identical-duplicate' => live + live,
          'contradictory-duplicate' => live + missing,
          _ => property404,
        };
        return http.Response(
          '<d:multistatus xmlns:d="DAV:" xmlns:c="urn:ietf:params:xml:ns:caldav">$contents</d:multistatus>',
          207,
        );
      });
      addTearDown(client.close);
      final authority = Uri.parse('https://cloud.example.test/');
      final profile = davProviderProfile(
        BusyProvider.nextcloud,
        nextcloudServer: authority,
      );
      final remote = DavCollectionHttpClient(
        transport: DavHttpTransport(
          client: client,
          profile: profile,
          accountAuthority: authority,
          limits: const DavTransportLimits(maximumReadAttempts: 1),
        ),
        profile: profile,
        accountAuthority: authority,
        accountId: 'account',
        collectionId: 'collection',
        collectionUri: authority.resolve(_href('')),
        credential: DavBasicCredential(username: 'qa', password: 'synthetic'),
      );
      final resolved = [
        'resource404',
        'property404-get200',
        'property404-get404',
        'missing-data',
        'missing-etag',
        'omitted',
      ].contains(scenario);
      final run = _engine(database, repository, remote).synchronize(
        correlationId: 'multiget-reconcile',
        cancellationToken: token,
      );
      if (resolved) {
        await run;
      } else {
        await expectLater(run, throwsA(isA<DavException>()));
      }
      await database.close();
      database = AppDatabase(NativeDatabase(file));
      repository = DavObjectRepository(database: database);
      for (final table in [
        'pending_ops',
        'tasks',
        if (!resolved) 'dav_objects',
        if (!resolved) 'calendar_events',
      ]) {
        expect(
          (await database
                  .customSelect('SELECT * FROM $table ORDER BY id')
                  .get())
              .map((r) => r.data),
          before[table],
          reason: table,
        );
      }
      final cursor = (await repository.cursor('collection'))!;
      expect(cursor.cursorValue, resolved ? 'urn:next' : 'urn:stable');
      expect(cursor.baselineGeneration, resolved ? 2 : 1);
      expect(cursor.inProgressCursor, isNull);
      final event = (await repository.objectByHref(
        'collection',
        _href('event.ics'),
      ))!;
      final deleted = ['resource404', 'property404-get404'].contains(scenario);
      expect(event.serverDeleted, deleted);
      expect(event.etag, resolved && !deleted ? '"e2"' : '"e1"');
      expect(
        (await database.select(database.calendarEvents).get()).map(
          (r) => r.title,
        ),
        deleted ? isEmpty : [resolved ? 'Updated event' : 'Cached event'],
      );
      expect(
        requests.where((m) => m == 'GET').length,
        [
              'resource404',
              'identical-duplicate',
              'contradictory-duplicate',
            ].contains(scenario)
            ? 0
            : 1,
      );
    });
  }

  for (final mode in ['initial', 'incremental', 'invalid-token rebaseline']) {
    for (final failure in [
      'member507',
      'missing-token',
      'repeated-token',
      'cycle',
      'interrupted',
      'page-limit',
      'none',
    ]) {
      test(
        'wire pagination $mode / $failure preserves membership, content, ETags and cursor',
        () async {
          await _seedCollection(database, syncCollection: true);
          await _runInitial(database, repository, {
            'a.ics': ('"a1"', _event('a', 'A old')),
            'b.ics': ('"b1"', _event('b', 'B old')),
          }, token: 'urn:test:old');
          if (mode == 'initial') {
            await database.delete(database.syncCursors).go();
          }
          await database
              .update(database.davCollections)
              .write(
                DavCollectionsCompanion(
                  supportedReportsJson: Value(
                    jsonEncode(['{DAV:}sync-collection']),
                  ),
                ),
              );
          final before = await repository.liveObjects('collection');
          final expectedCursor = mode == 'initial' ? '0' : 'urn:test:old';
          final requestedTokens = <String>[];
          final client = MockClient((request) async {
            if (request.method == 'GET') {
              final name = _name(request.url.path);
              expect(name, isNot('b.ics'));
              return http.Response(
                _event(
                  name == 'a.ics' ? 'a' : 'c',
                  name == 'a.ics' ? 'A newest' : 'C',
                ),
                200,
                headers: {
                  'etag': name == 'a.ics' ? '"a3"' : '"c1"',
                  'content-type': 'text/calendar',
                },
              );
            }
            expect(request.method, 'REPORT');
            expect(request.headers['depth'], '0');
            final token = RegExp(r'<d:sync-token>(.*?)</d:sync-token>')
                .firstMatch(request.body)!
                .group(1)!;
            requestedTokens.add(token);
            if (mode == 'invalid-token rebaseline' && token == 'urn:test:old') {
              return http.Response(
                '<d:error xmlns:d="DAV:"><d:valid-sync-token/></d:error>',
                403,
              );
            }
            if (token == expectedCursor || token.isEmpty) {
              return http.Response(
                _wireSync(
                  _wireChanged('a.ics', '"a2"') + _wireLimit(),
                  'urn:test:page1',
                ),
                207,
              );
            }
            // No partial page, continuation token, or tombstone may have reached
            // the durable object baseline while a subsequent page is pending.
            expect(
              (await repository.cursor('collection'))?.cursorValue,
              expectedCursor,
            );
            expect(
              (await repository.liveObjects('collection'))
                  .map((o) => (o.hrefKey, o.etag, o.rawIcsBody)),
              before.map((o) => (o.hrefKey, o.etag, o.rawIcsBody)),
            );
            if (failure == 'interrupted') {
              throw http.ClientException('page interrupted');
            }
            if (failure == 'member507') {
              return http.Response(
                _wireSync(
                  '<d:response><d:href>${_href('b.ics')}</d:href><d:status>HTTP/1.1 507 Insufficient Storage</d:status></d:response>',
                  'urn:test:final',
                ),
                207,
              );
            }
            if (failure == 'missing-token') {
              return http.Response(_wireSync(_wireLimit(), null), 207);
            }
            if (failure == 'repeated-token') {
              return http.Response(
                _wireSync(_wireLimit(), 'urn:test:page1'),
                207,
              );
            }
            if (failure == 'cycle') {
              return http.Response(
                _wireSync(
                  _wireLimit(),
                  token == 'urn:test:page1'
                      ? 'urn:test:page2'
                      : 'urn:test:page1',
                ),
                207,
              );
            }
            expect(token, 'urn:test:page1');
            return http.Response(
              _wireSync(
                '${_wireChanged('a.ics', '"a3"')}${_wireChanged('c.ics', '"c1"')}<d:response><d:href>${_href('b.ics')}</d:href><d:status>HTTP/1.1 404 Not Found</d:status></d:response>',
                'urn:test:final',
              ),
              207,
            );
          });
          addTearDown(client.close);
          final authority = Uri.parse('https://cloud.example.test/');
          final profile = davProviderProfile(
            BusyProvider.nextcloud,
            nextcloudServer: authority,
          );
          final remote = DavCollectionHttpClient(
            transport: DavHttpTransport(
              client: client,
              profile: profile,
              accountAuthority: authority,
              limits: const DavTransportLimits(maximumReadAttempts: 1),
            ),
            profile: profile,
            accountAuthority: authority,
            accountId: 'account',
            collectionId: 'collection',
            collectionUri: authority.resolve(_href('')),
            credential: DavBasicCredential(
              username: 'alex',
              password: 'synthetic',
            ),
          );
          final engine = _engine(
            database,
            repository,
            remote,
            limits: DavSyncLimits(
              maximumSyncPages: failure == 'page-limit' ? 1 : 1000,
            ),
          );
          if (failure == 'none') {
            final result = await engine.synchronize(
              correlationId: 'wire-pages',
            );
            expect(result.pages, 2);
            expect(result.initialOrRebaseline, mode != 'incremental');
            final live = await repository.liveObjects('collection');
            expect(live.map((o) => _name(o.hrefKey)).toSet(), {
              'a.ics',
              'c.ics',
            });
            expect(
              live.singleWhere((o) => o.hrefKey.endsWith('/a.ics')).etag,
              '"a3"',
            );
            expect(
              live.singleWhere((o) => o.hrefKey.endsWith('/a.ics')).rawIcsBody,
              contains('SUMMARY:A newest'),
            );
            expect(
              (await repository.objectByHref(
                'collection',
                _href('b.ics'),
              ))!.serverDeleted,
              isTrue,
            );
            expect(
              (await repository.cursor('collection'))!.cursorValue,
              'urn:test:final',
            );
            expect(
              (await repository.cursor('collection'))!.inProgressCursor,
              isNull,
            );
          } else {
            await expectLater(
              engine.synchronize(correlationId: 'wire-pages'),
              throwsA(isA<DavException>()),
            );
            final after = await repository.liveObjects('collection');
            expect(
              after.map((o) => (o.hrefKey, o.etag, o.rawIcsBody)),
              before.map((o) => (o.hrefKey, o.etag, o.rawIcsBody)),
            );
            expect(after.every((o) => !o.serverDeleted), isTrue);
            expect(
              (await repository.cursor('collection'))?.cursorValue,
              expectedCursor,
            );
            expect(
              (await repository.cursor('collection'))?.inProgressCursor,
              isNot('urn:test:page1'),
            );
            expect(
              (await database.select(database.calendarEvents).get())
                  .map((e) => e.title)
                  .toSet(),
              {'A old', 'B old'},
            );
          }
          if (mode == 'invalid-token rebaseline') {
            expect(requestedTokens.take(2), ['urn:test:old', '']);
          }
        },
      );
    }
  }
  test(
    'initial empty-token sync follows 507 pages and persists only final token',
    () async {
      await _seedCollection(database, syncCollection: true);
      final remote = _FakeRemoteClient(
        sync: (token) async => switch (token) {
          '' => DavSyncPage(
            changedMembers: [_member('a.ics', '"a1"')],
            deletedHrefKeys: const {},
            nextSyncToken: 'intermediate-secret-token',
            truncated: true,
          ),
          'intermediate-secret-token' => DavSyncPage(
            changedMembers: [_member('b.ics', '"b1"')],
            deletedHrefKeys: const {},
            nextSyncToken: 'final-token',
            truncated: false,
          ),
          _ => throw StateError('unexpected token'),
        },
        fetch: (members) async => [
          for (final member in members)
            _fetched(member, _event(member.hrefKey, member.hrefKey)),
        ],
      );
      var notificationCalls = 0;
      final engine = _engine(
        database,
        repository,
        remote,
        onNotifications: (_) async => notificationCalls += 1,
      );

      final result = await engine.synchronize(correlationId: 'initial');

      expect(remote.requestedTokens, ['', 'intermediate-secret-token']);
      expect(result.pages, 2);
      expect(result.initialOrRebaseline, isTrue);
      expect(result.finalCursorValue, 'final-token');
      expect(await database.select(database.davObjects).get(), hasLength(2));
      final cursor = await database.select(database.syncCursors).getSingle();
      expect(cursor.cursorValue, 'final-token');
      expect(cursor.inProgressCursor, isNull);
      expect(cursor.inProgressGeneration, isNull);
      expect(notificationCalls, 1);
    },
  );

  test(
    'incremental sync applies add, change, and deletion atomically',
    () async {
      await _seedCollection(database, syncCollection: true);
      await _runInitial(database, repository, {
        'a.ics': ('"a1"', _event('a', 'A')),
        'b.ics': ('"b1"', _event('b', 'B')),
      }, token: 'baseline-token');
      final remote = _FakeRemoteClient(
        sync: (token) async {
          expect(token, 'baseline-token');
          return DavSyncPage(
            changedMembers: [
              _member('a.ics', '"a2"'),
              _member('c.ics', '"c1"'),
            ],
            deletedHrefKeys: {_href('b.ics')},
            nextSyncToken: 'next-token',
            truncated: false,
          );
        },
        fetch: (members) async => [
          for (final member in members)
            _fetched(
              member,
              member.hrefKey.endsWith('a.ics')
                  ? _event('a', 'A changed')
                  : _event('c', 'C'),
            ),
        ],
      );

      final result = await _engine(
        database,
        repository,
        remote,
      ).synchronize(correlationId: 'incremental');

      expect(result.initialOrRebaseline, isFalse);
      final objects = await database.select(database.davObjects).get();
      expect(objects, hasLength(3));
      expect(
        objects
            .singleWhere((object) => object.hrefKey == _href('b.ics'))
            .serverDeleted,
        isTrue,
      );
      expect(
        objects
            .singleWhere((object) => object.hrefKey == _href('a.ics'))
            .rawIcsBody,
        contains('A changed'),
      );
      expect(
        (await database.select(database.calendarEvents).get())
            .map((event) => event.title)
            .toSet(),
        {'A changed', 'C'},
      );
      expect(
        (await database.select(database.syncCursors).getSingle()).cursorValue,
        'next-token',
      );
    },
  );

  test(
    'failure in a later multiget batch keeps baseline and cursor intact',
    () async {
      await _seedCollection(database, syncCollection: true);
      await _runInitial(database, repository, {
        'old.ics': ('"old"', _event('old', 'Old')),
      }, token: 'old-token');
      var fetchCalls = 0;
      final remote = _FakeRemoteClient(
        sync: (_) async => DavSyncPage(
          changedMembers: [
            _member('new-a.ics', '"a"'),
            _member('new-b.ics', '"b"'),
          ],
          deletedHrefKeys: const {},
          nextSyncToken: 'must-not-commit',
          truncated: false,
        ),
        fetch: (members) async {
          fetchCalls += 1;
          if (fetchCalls == 2) {
            throw const DavException(
              kind: DavErrorKind.server,
              code: 'InjectedLaterBatchFailure',
              safeMessage: 'Injected failure.',
            );
          }
          return [_fetched(members.single, _event('new-a', 'New A'))];
        },
      );
      final engine = _engine(
        database,
        repository,
        remote,
        limits: const DavSyncLimits(maximumMembersPerMultiget: 1),
      );

      await expectLater(
        engine.synchronize(correlationId: 'batch-failure'),
        throwsA(isA<DavException>()),
      );

      expect(fetchCalls, 2);
      expect(
        (await database.select(database.davObjects).get()).map(
          (object) => object.hrefKey,
        ),
        [_href('old.ics')],
      );
      final cursor = await database.select(database.syncCursors).getSingle();
      expect(cursor.cursorValue, 'old-token');
      expect(cursor.lastFailureCode, 'InjectedLaterBatchFailure');
      expect(cursor.inProgressGeneration, isNull);
    },
  );

  test(
    'changed member that disappears during multiget becomes a deletion',
    () async {
      await _seedCollection(database, syncCollection: true);
      await _runInitial(database, repository, {
        'a.ics': ('"a1"', _event('a', 'A')),
      }, token: 'old-token');
      final remote = _FakeRemoteClient(
        sync: (_) async => DavSyncPage(
          changedMembers: [_member('a.ics', '"a2"')],
          deletedHrefKeys: const {},
          nextSyncToken: 'new-token',
          truncated: false,
        ),
        fetch: (members) async => [
          DavFetchedMember.missing(
            hrefKey: members.single.hrefKey,
            requestUri: members.single.requestUri,
          ),
        ],
      );

      await _engine(
        database,
        repository,
        remote,
      ).synchronize(correlationId: 'race');

      expect(
        (await database.select(database.davObjects).getSingle()).serverDeleted,
        isTrue,
      );
      expect(await database.select(database.calendarEvents).get(), isEmpty);
      expect(
        (await database.select(database.syncCursors).getSingle()).cursorValue,
        'new-token',
      );
    },
  );

  test(
    'invalid token safely rebaselines without erasing the prior baseline first',
    () async {
      await _seedCollection(database, syncCollection: true);
      await _runInitial(database, repository, {
        'old.ics': ('"old"', _event('old', 'Old')),
      }, token: 'expired-token');
      final remote = _FakeRemoteClient(
        sync: (token) async {
          if (token == 'expired-token') {
            throw const DavException(
              kind: DavErrorKind.invalidSyncToken,
              code: 'DavSyncTokenInvalid',
              safeMessage: 'Expired.',
            );
          }
          expect(token, '');
          expect(
            (await database.select(database.davObjects).getSingle()).rawIcsBody,
            contains('Old'),
          );
          expect(
            (await database.select(database.syncCursors).getSingle())
                .cursorValue,
            'expired-token',
          );
          return DavSyncPage(
            changedMembers: [_member('replacement.ics', '"replacement"')],
            deletedHrefKeys: const {},
            nextSyncToken: 'replacement-token',
            truncated: false,
          );
        },
        fetch: (members) async => [
          _fetched(members.single, _event('replacement', 'Replacement')),
        ],
      );

      final result = await _engine(
        database,
        repository,
        remote,
      ).synchronize(correlationId: 'rebaseline');

      expect(remote.requestedTokens, ['expired-token', '']);
      expect(result.initialOrRebaseline, isTrue);
      final objects = await database.select(database.davObjects).get();
      expect(
        objects
            .singleWhere((object) => object.hrefKey == _href('old.ics'))
            .serverDeleted,
        isTrue,
      );
      expect(
        objects
            .singleWhere((object) => object.hrefKey == _href('replacement.ics'))
            .serverDeleted,
        isFalse,
      );
    },
  );

  for (final invalid in [
    'empty',
    'collection-failure',
    'malformed-member',
    'duplicate',
    'missing-home',
  ]) {
    test(
      'PROPFIND $invalid preserves cached events, tasks, queue and baseline across reopen',
      () async {
        await database.close();
        final directory = await createPersistenceTestDirectory(
          'busymax-inventory-',
        );
        fixtureDirectory = directory;
        final file = File('${directory.path}/fixture.sqlite');
        database = AppDatabase(NativeDatabase(file));
        repository = DavObjectRepository(database: database);
        await _seedCollection(database, syncCollection: true);
        await _runInitial(database, repository, {
          'event.ics': ('"e1"', _event('event', 'Cached event')),
          'task.ics': (
            '"t1"',
            _event(
              'task',
              'Cached task',
            ).replaceAll('VEVENT', 'VTODO').replaceAll('DTEND', 'DUE'),
          ),
        }, token: 'urn:stable');
        final object = (await repository.liveObjects('collection')).first;
        await DavPendingOperationQueue(database: database).enqueueUpdate(
          accountId: 'account',
          collectionId: 'collection',
          objectId: object.id,
          patch: DavMutationPatch(
            target: IcalComponentKey(
              componentType: 'VEVENT',
              uid: object.primaryUid!,
            ),
            scope: DavMutationScope.object,
            operations: [DavPatchOperation.setText('SUMMARY', 'Pending edit')],
          ),
        );
        await database
            .update(database.davCollections)
            .write(
              const DavCollectionsCompanion(supportedReportsJson: Value('[]')),
            );
        final objects = await database
            .customSelect('SELECT * FROM dav_objects ORDER BY id')
            .get();
        final events = await database
            .customSelect('SELECT * FROM calendar_events ORDER BY id')
            .get();
        final tasks = await database
            .customSelect('SELECT * FROM tasks ORDER BY id')
            .get();
        final pending = await database
            .customSelect('SELECT * FROM pending_ops ORDER BY id')
            .get();
        final self = _wireChanged('', '"collection"');
        final member = _wireChanged('event.ics', '"e1"');
        var broken = true;
        final remote = DavCollectionHttpClient(
          transport: DavHttpTransport(
            client: MockClient((request) async {
              expect(request.method, 'PROPFIND');
              final contents = !broken
                  ? self.replaceFirst('200 OK', '404 Not Found')
                  : switch (invalid) {
                      'empty' => '',
                      'collection-failure' =>
                        '<d:response><d:href>${_href('')}</d:href><d:status>HTTP/1.1 403 Forbidden</d:status></d:response>',
                      'malformed-member' =>
                        self +
                            member.replaceFirst(
                              '<d:getetag>"e1"</d:getetag>',
                              '',
                            ),
                      'duplicate' => self + member + member,
                      _ => member,
                    };
              return http.Response(_wireSync(contents, null), 207);
            }),
            profile: davProviderProfile(
              BusyProvider.nextcloud,
              nextcloudServer: Uri.parse('https://cloud.example.test'),
            ),
            accountAuthority: Uri.parse('https://cloud.example.test'),
          ),
          profile: davProviderProfile(
            BusyProvider.nextcloud,
            nextcloudServer: Uri.parse('https://cloud.example.test'),
          ),
          accountAuthority: Uri.parse('https://cloud.example.test'),
          accountId: 'account',
          collectionId: 'collection',
          collectionUri: Uri.parse('https://cloud.example.test${_href('')}'),
          credential: DavBasicCredential(username: 'qa', password: 'synthetic'),
        );
        await expectLater(
          _engine(
            database,
            repository,
            remote,
          ).synchronize(correlationId: 'invalid-inventory'),
          throwsA(isA<DavException>()),
        );
        await database.close();
        database = AppDatabase(NativeDatabase(file));
        repository = DavObjectRepository(database: database);
        for (final item in [
          ('dav_objects', objects),
          ('calendar_events', events),
          ('tasks', tasks),
          ('pending_ops', pending),
        ]) {
          expect(
            (await database
                    .customSelect('SELECT * FROM ${item.$1} ORDER BY id')
                    .get())
                .map((r) => r.data),
            item.$2.map((r) => r.data),
          );
        }
        expect(
          (await repository.cursor('collection'))!.cursorValue,
          'urn:stable',
        );
        expect((await repository.cursor('collection'))!.baselineGeneration, 1);
        expect(
          (await repository.cursor('collection'))!.inProgressCursor,
          isNull,
        );
        broken = false;
        await _engine(
          database,
          repository,
          remote,
        ).synchronize(correlationId: 'valid-empty');
        expect(
          (await database.select(database.pendingOps).get()).map((r) => r.id),
          pending.map((r) => r.data['id']),
        );
        expect(
          (await repository.cursor('collection'))!.cursorKind,
          'snapshot_generation',
        );
      },
    );
  }

  test(
    'fallback inventory performs a complete ETag diff and snapshot cursor',
    () async {
      await _seedCollection(database, syncCollection: false);
      var inventory = {
        'a.ics': ('"a1"', _event('a', 'A')),
        'b.ics': ('"b1"', _event('b', 'B')),
      };
      final fetchedNames = <String>[];
      final remote = _FakeRemoteClient(
        inventory: () async => DavMemberInventory(
          members: [
            for (final entry in inventory.entries)
              _member(entry.key, entry.value.$1),
          ],
        ),
        fetch: (members) async => [
          for (final member in members)
            _fetched(
              member,
              inventory[_name(member.hrefKey)]!.$2,
              onFetched: fetchedNames.add,
            ),
        ],
      );
      final engine = _engine(database, repository, remote);

      final first = await engine.synchronize(correlationId: 'fallback-1');
      expect(first.finalCursorKind, 'snapshot_generation');
      expect(fetchedNames.toSet(), {'a.ics', 'b.ics'});
      fetchedNames.clear();
      inventory = {
        'a.ics': ('"a1"', _event('a', 'A')),
        'c.ics': ('"c1"', _event('c', 'C')),
      };

      await engine.synchronize(correlationId: 'fallback-2');

      expect(fetchedNames, ['c.ics']);
      final objects = await database.select(database.davObjects).get();
      expect(
        objects
            .singleWhere((object) => object.hrefKey == _href('b.ics'))
            .serverDeleted,
        isTrue,
      );
      expect(
        (await database.select(database.syncCursors).getSingle()).cursorKind,
        'snapshot_generation',
      );
    },
  );

  test(
    'malformed fetched resource aborts promotion and records safe failure',
    () async {
      await _seedCollection(database, syncCollection: true);
      final remote = _FakeRemoteClient(
        sync: (_) async => DavSyncPage(
          changedMembers: [_member('bad.ics', '"bad"')],
          deletedHrefKeys: const {},
          nextSyncToken: 'bad-token',
          truncated: false,
        ),
        fetch: (members) async => [
          _fetched(members.single, 'not iCalendar user content'),
        ],
      );

      await expectLater(
        _engine(
          database,
          repository,
          remote,
        ).synchronize(correlationId: 'malformed'),
        throwsA(
          isA<DavException>().having(
            (error) => error.kind,
            'kind',
            DavErrorKind.invalidCalendarData,
          ),
        ),
      );

      expect(await database.select(database.davObjects).get(), isEmpty);
      final cursor = await database.select(database.syncCursors).getSingle();
      expect(cursor.cursorValue, '0');
      expect(cursor.lastFailureCode, isNot(contains('not iCalendar')));
    },
  );

  test(
    'sync reprojects a conflicted series before claiming current coverage',
    () async {
      await _seedCollection(database, syncCollection: true);
      final baseline = _ongoingWeeklyEvent;
      await _runInitial(database, repository, {
        'weekly.ics': ('"weekly"', baseline),
      }, token: 'baseline-token');
      final object = await database.select(database.davObjects).getSingle();
      final patch = DavMutationPatch(
        target: const IcalComponentKey(
          componentType: 'VEVENT',
          uid: 'ongoing-weekly@example.test',
        ),
        scope: DavMutationScope.recurrenceMaster,
        operations: [
          DavPatchOperation.setRaw('DTSTART', '20260803T110000Z'),
          DavPatchOperation.setRaw('DTEND', '20260803T120000Z'),
        ],
      );
      await DavPendingOperationQueue(
        database: database,
        idFactory: () => 'pending-series-edit',
        nowUtc: () => DateTime.utc(2026, 8, 8, 12),
      ).enqueueUpdate(
        accountId: 'account',
        collectionId: 'collection',
        objectId: object.id,
        patch: patch,
      );
      await repository.projectLocalMutationCandidate(
        accountId: 'account',
        collectionId: 'collection',
        provider: BusyProvider.nextcloud,
        objectId: object.id,
        candidateRawIcs: patch.applyTo(
          baseline,
          nowUtc: DateTime.utc(2026, 8, 8, 12),
        ),
        projectedAtUtc: DateTime.utc(2026, 8, 8, 12),
      );
      await DavProjectionCoverageService(
        database: database,
        objectRepository: repository,
        nowUtc: () => DateTime.utc(2026, 8, 8, 12),
      ).ensureProjectionCoverage(
        rangeStartUtc: DateTime.utc(2030, 1),
        rangeEndUtc: DateTime.utc(2030, 2),
      );
      final futureEvents =
          (await database.select(database.calendarEvents).get())
              .where(
                (event) => event.startDateTime?.startsWith('2030-01') ?? false,
              )
              .toList();
      expect(futureEvents, isNotEmpty);
      expect(
        futureEvents.every(
          (event) =>
              event.startDateTime!.contains('T11:00:00') &&
              event.syncStatus == 'pending',
        ),
        isTrue,
      );

      await database
          .update(database.pendingOps)
          .write(const PendingOpsCompanion(state: Value('conflict')));
      final operationBeforeSync = await database
          .select(database.pendingOps)
          .getSingle();
      final remote = _FakeRemoteClient(
        sync: (token) async {
          expect(token, 'baseline-token');
          return const DavSyncPage(
            changedMembers: [],
            deletedHrefKeys: {},
            nextSyncToken: 'next-token',
            truncated: false,
          );
        },
        fetch: (_) async => const [],
      );

      await _engine(
        database,
        repository,
        remote,
      ).synchronize(correlationId: 'pending-force-reprojection');

      final currentEvents =
          (await database.select(database.calendarEvents).get())
              .where(
                (event) => event.startDateTime?.startsWith('2026-08') ?? false,
              )
              .toList();
      expect(currentEvents, isNotEmpty);
      expect(
        currentEvents.every(
          (event) =>
              event.startDateTime!.contains('T11:00:00') &&
              event.syncStatus == 'conflict',
        ),
        isTrue,
      );
      final currentCount = currentEvents.length;
      await DavProjectionCoverageService(
        database: database,
        objectRepository: repository,
        nowUtc: () => DateTime.utc(2026, 8, 8, 12),
      ).ensureProjectionCoverage(
        rangeStartUtc: DateTime.utc(2026, 8),
        rangeEndUtc: DateTime.utc(2026, 9),
      );

      final eventsAfterReturn =
          (await database.select(database.calendarEvents).get())
              .where(
                (event) => event.startDateTime?.startsWith('2026-08') ?? false,
              )
              .toList();
      expect(eventsAfterReturn, hasLength(currentCount));
      expect(
        eventsAfterReturn.every((event) => event.syncStatus == 'conflict'),
        isTrue,
      );
      expect(
        await database.select(database.pendingOps).getSingle(),
        operationBeforeSync,
      );
      final objectAfter = await database
          .select(database.davObjects)
          .getSingle();
      expect(objectAfter.rawIcsBody, baseline);
      expect(objectAfter.etag, '"weekly"');
      final cursor = await database.select(database.syncCursors).getSingle();
      expect(cursor.cursorValue, 'next-token');
      expect(
        cursor.stateJson,
        contains('"projectionVersion":$davProjectionVersion'),
      );
    },
  );
}

final class _FakeRemoteClient implements DavCollectionRemoteClient {
  _FakeRemoteClient({this.sync, this.inventory, required this.fetch});

  final Future<DavSyncPage> Function(String token)? sync;
  final Future<DavMemberInventory> Function()? inventory;
  final Future<List<DavFetchedMember>> Function(List<DavRemoteMember>) fetch;
  final List<String> requestedTokens = [];

  @override
  Future<List<DavFetchedMember>> fetchMembers(
    List<DavRemoteMember> members, {
    required String correlationId,
    required bool useCalendarMultiget,
    DavCancellationToken? cancellationToken,
  }) => fetch(members);

  @override
  Future<DavMemberInventory> listMemberEtags({
    required String correlationId,
    DavCancellationToken? cancellationToken,
  }) => inventory!();

  @override
  Future<DavSyncPage> syncCollectionPage({
    required String syncToken,
    required String correlationId,
    DavCancellationToken? cancellationToken,
  }) {
    requestedTokens.add(syncToken);
    return sync!(syncToken);
  }
}

DavSyncEngine _engine(
  AppDatabase database,
  DavObjectRepository repository,
  DavCollectionRemoteClient remote, {
  DavSyncLimits limits = const DavSyncLimits(),
  Future<void> Function(String)? onNotifications,
}) => DavSyncEngine(
  database: database,
  objectRepository: repository,
  remoteClient: remote,
  accountId: 'account',
  collectionId: 'collection',
  provider: BusyProvider.nextcloud,
  limits: limits,
  nowUtc: () => DateTime.utc(2026, 8, 8, 12),
  onNotificationsNeedRebuild: onNotifications,
);

Future<void> _runInitial(
  AppDatabase database,
  DavObjectRepository repository,
  Map<String, (String, String)> members, {
  required String token,
}) async {
  final remote = _FakeRemoteClient(
    sync: (_) async => DavSyncPage(
      changedMembers: [
        for (final entry in members.entries) _member(entry.key, entry.value.$1),
      ],
      deletedHrefKeys: const {},
      nextSyncToken: token,
      truncated: false,
    ),
    fetch: (requested) async => [
      for (final member in requested)
        _fetched(member, members[_name(member.hrefKey)]!.$2),
    ],
  );
  await _engine(
    database,
    repository,
    remote,
  ).synchronize(correlationId: 'seed');
}

DavRemoteMember _member(String name, String etag) => DavRemoteMember(
  hrefKey: _href(name),
  requestUri: Uri.parse('https://cloud.example.test${_href(name)}'),
  etag: etag,
);

DavFetchedMember _fetched(
  DavRemoteMember member,
  String body, {
  void Function(String)? onFetched,
}) {
  onFetched?.call(_name(member.hrefKey));
  return DavFetchedMember.live(
    hrefKey: member.hrefKey,
    requestUri: member.requestUri,
    etag: member.etag,
    contentType: 'text/calendar; charset=utf-8',
    rawIcsBody: body,
  );
}

String _href(String name) => '/remote.php/dav/calendars/alex/work/$name';

String _name(String href) => href.split('/').last;

String _event(String uid, String summary) =>
    '''BEGIN:VCALENDAR\r
VERSION:2.0\r
PRODID:-//BusyMax Test//EN\r
BEGIN:VEVENT\r
UID:$uid@example.test\r
DTSTART:20260808T090000Z\r
DTEND:20260808T100000Z\r
SUMMARY:$summary\r
END:VEVENT\r
END:VCALENDAR\r
''';

const _ongoingWeeklyEvent = '''BEGIN:VCALENDAR\r
VERSION:2.0\r
PRODID:-//BusyMax Test//EN\r
BEGIN:VEVENT\r
UID:ongoing-weekly@example.test\r
DTSTART:20260803T090000Z\r
DTEND:20260803T100000Z\r
RRULE:FREQ=WEEKLY\r
SUMMARY:Ongoing weekly\r
END:VEVENT\r
END:VCALENDAR\r
''';

Future<void> _seedCollection(
  AppDatabase database, {
  required bool syncCollection,
}) async {
  const now = '2026-08-08T12:00:00.000Z';
  await database
      .into(database.accounts)
      .insert(
        AccountsCompanion.insert(
          id: 'account',
          provider: 'nextcloud',
          authority: 'https://cloud.example.test',
          providerAccountId: 'alex',
          credentialKind: 'nextcloud_app_password',
          authState: const Value('signed_in'),
          createdAtUtc: now,
          updatedAtUtc: now,
        ),
      );
  final reports = [
    if (syncCollection) '{DAV:}sync-collection',
    '{urn:ietf:params:xml:ns:caldav}calendar-multiget',
  ];
  const collectionHref = '/remote.php/dav/calendars/alex/work/';
  await database
      .into(database.davCollections)
      .insert(
        DavCollectionsCompanion.insert(
          id: 'collection',
          accountId: 'account',
          hrefKey: collectionHref,
          requestUri: 'https://cloud.example.test$collectionHref',
          displayName: 'Work',
          supportedReportsJson: Value(jsonEncode(reports)),
          supportedComponentMask: const Value(3),
          currentUserPrivilegesJson: Value(jsonEncode(['{DAV:}write'])),
          readOnly: const Value(false),
          eventProjectionEnabled: const Value(true),
          taskProjectionEnabled: const Value(true),
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
          provider: 'nextcloud',
          providerCalendarId: collectionHref,
          davCollectionId: const Value('collection'),
          summary: 'Work',
          createdAtLocal: DateTime.parse(now).millisecondsSinceEpoch,
          updatedAtLocal: DateTime.parse(now).millisecondsSinceEpoch,
        ),
      );
  await database
      .into(database.taskLists)
      .insert(
        TaskListsCompanion.insert(
          accountId: 'account',
          id: 'dav-task-list-collection',
          davCollectionId: const Value('collection'),
          title: 'Work',
          rawJson: '{}',
          createdLocalAtUtc: now,
          updatedLocalAtUtc: now,
        ),
      );
}

String _wireSync(String responses, String? token) =>
    '<d:multistatus xmlns:d="DAV:">$responses${token == null ? '' : '<d:sync-token>$token</d:sync-token>'}</d:multistatus>';
String _wireChanged(String name, String etag) =>
    '<d:response><d:href>${_href(name)}</d:href><d:propstat><d:prop><d:getetag>$etag</d:getetag></d:prop><d:status>HTTP/1.1 200 OK</d:status></d:propstat></d:response>';
String _wireLimit() =>
    '<d:response><d:href>${_href('')}</d:href><d:status>HTTP/1.1 507 Insufficient Storage</d:status></d:response>';

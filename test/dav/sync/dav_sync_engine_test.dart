import 'dart:convert';

import 'package:busymax/src/dav/dav_errors.dart';
import 'package:busymax/src/dav/http/dav_http_transport.dart';
import 'package:busymax/src/dav/storage/dav_object_repository.dart';
import 'package:busymax/src/dav/sync/dav_collection_remote_client.dart';
import 'package:busymax/src/dav/sync/dav_sync_engine.dart';
import 'package:busymax/src/db/app_database.dart';
import 'package:busymax/src/providers/busy_provider.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late DavObjectRepository repository;
  var nextId = 0;

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    repository = DavObjectRepository(
      database: database,
      idFactory: () => 'id-${nextId += 1}',
    );
  });

  tearDown(() => database.close());

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

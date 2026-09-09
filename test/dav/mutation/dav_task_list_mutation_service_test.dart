import 'dart:io';

import 'package:busymax/src/core/secrets/secret_store.dart';
import 'package:busymax/src/dav/dav_errors.dart';
import 'package:busymax/src/dav/discovery/dav_discovery_models.dart';
import 'package:busymax/src/dav/mutation/dav_task_list_mutation_service.dart';
import 'package:busymax/src/db/app_database.dart';
import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  late AppDatabase database;
  late InMemorySecretStore secrets;

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    secrets = InMemorySecretStore();
    await _seedAccount(database, secrets);
  });

  tearDown(() => database.close());

  test('collection member naming matches cdav-library token rules', () {
    final home = Uri.parse(
      'https://cloud.example.test/remote.php/dav/calendars/alex/',
    );

    expect(
      nextcloudCollectionMemberName(
        ' Résumé   List ',
        homeUri: home,
        existingCollectionUris: const [],
      ),
      'rsum-list',
    );
    expect(
      nextcloudCollectionMemberName(
        'Work',
        homeUri: home,
        existingCollectionUris: [
          home.resolve('work/'),
          home.resolve('work-1/'),
        ],
      ),
      'work-2',
    );
    expect(
      nextcloudCollectionMemberName(
        '---',
        homeUri: home,
        existingCollectionUris: const [],
      ),
      '-',
    );
  });

  test(
    'create sends the exact VTODO extended MKCOL shape and refreshes',
    () async {
      late http.Request request;
      var refreshes = 0;
      final service = _service(
        database,
        secrets,
        MockClient((incoming) async {
          request = incoming;
          return http.Response('', HttpStatus.created);
        }),
        refresh: () async => refreshes += 1,
      );

      await service.createTaskList('Project Tasks');

      expect(request.method, 'MKCOL');
      expect(request.url.path, endsWith('/project-tasks'));
      expect(request.headers['content-type'], contains('application/xml'));
      expect(request.body, contains('<d:mkcol'));
      expect(
        request.body,
        contains('<d:resourcetype><d:collection/><c:calendar/>'),
      );
      expect(request.body, contains('<d:displayname>Project Tasks'));
      expect(
        request.body,
        contains('<a:calendar-color>$nextcloudDefaultTaskListColor'),
      );
      expect(request.body, contains('<o:calendar-enabled>1'));
      expect(request.body, contains('<c:comp name="VTODO"/>'));
      expect(refreshes, 1);
    },
  );

  test('create enforces network availability before DAV transport', () async {
    var requests = 0;
    var networkChecks = 0;
    final service = DavTaskListMutationService(
      database: database,
      secretStore: secrets,
      httpClient: MockClient((_) async {
        requests += 1;
        return http.Response('', HttpStatus.created);
      }),
      accountId: 'account',
      refreshAfterMutation: () async {},
      requireNetwork: () async {
        networkChecks += 1;
        throw const _OfflineTestException();
      },
    );

    await expectLater(
      service.createTaskList('Offline'),
      throwsA(isA<_OfflineTestException>()),
    );
    expect(networkChecks, 1);
    expect(requests, 0);
  });

  test('a lost MKCOL response is reconciled by a matching PROPFIND', () async {
    var requests = 0;
    var refreshes = 0;
    final service = _service(
      database,
      secrets,
      MockClient((request) async {
        requests += 1;
        if (request.method == 'MKCOL') {
          throw const SocketException('connection closed after commit');
        }
        expect(request.method, 'PROPFIND');
        expect(request.headers['depth'], '0');
        return http.Response(_createdCollectionMultistatus('Recovered'), 207);
      }),
      refresh: () async => refreshes += 1,
    );

    await service.createTaskList('Recovered');

    expect(requests, 2);
    expect(refreshes, 1);
  });

  test('rename requires write-properties and validates multistatus', () async {
    await _seedCollection(database, privileges: const ['{DAV:}write']);
    late http.Request request;
    var refreshes = 0;
    final service = _service(
      database,
      secrets,
      MockClient((incoming) async {
        if (incoming.method == 'PROPFIND') return _adminProbe(incoming);
        request = incoming;
        return http.Response(_successfulProppatch, 207);
      }),
      refresh: () async => refreshes += 1,
    );

    await service.renameTaskList('collection', 'Home & Family');

    expect(request.method, 'PROPPATCH');
    expect(request.url.path, endsWith('/tasks/'));
    expect(request.body, contains('<d:propertyupdate'));
    expect(request.body, contains('Home &amp; Family'));
    expect(refreshes, 1);
  });

  test('rename surfaces a failed PROPPATCH property status', () async {
    await _seedCollection(database, privileges: const ['{DAV:}write']);
    var refreshes = 0;
    final service = _service(
      database,
      secrets,
      MockClient(
        (request) async => request.method == 'PROPFIND'
            ? _adminProbe(request)
            : http.Response(_forbiddenProppatch, 207),
      ),
      refresh: () async => refreshes += 1,
    );

    await expectLater(
      service.renameTaskList('collection', 'Rejected'),
      throwsA(
        isA<DavException>()
            .having((error) => error.kind, 'kind', DavErrorKind.authorization)
            .having((error) => error.statusCode, 'statusCode', 403),
      ),
    );
    expect(refreshes, 0);
  });

  test('read-only shared collection can be unshared with DELETE', () async {
    await _seedCollection(
      database,
      ownerHref: '/remote.php/dav/principals/users/bob/',
      privileges: const ['{DAV:}read'],
      readOnly: true,
    );
    late http.Request request;
    var refreshes = 0;
    final service = _service(
      database,
      secrets,
      MockClient((incoming) async {
        if (incoming.method == 'PROPFIND') {
          return _adminProbe(incoming, shared: true);
        }
        request = incoming;
        return http.Response('', HttpStatus.noContent);
      }),
      refresh: () async => refreshes += 1,
    );

    await service.deleteTaskList('collection');

    expect(request.method, 'DELETE');
    expect(refreshes, 1);
  });

  test(
    'task-list deletion entry point rejects an incoming task move',
    () async {
      await _seedCollection(
        database,
        id: 'source-collection',
        member: 'source-tasks',
        privileges: const ['{DAV:}write'],
      );
      await _seedCollection(database, privileges: const ['{DAV:}write']);
      await database
          .into(database.pendingOps)
          .insert(
            PendingOpsCompanion.insert(
              id: 'incoming-task-move',
              accountId: 'account',
              provider: const Value('nextcloud'),
              entityType: 'task',
              operation: 'move',
              operationType: const Value('task.move'),
              davCollectionId: const Value('source-collection'),
              destinationCollectionId: const Value('collection'),
              requestJson: '{}',
              createdAtUtc: '2026-08-09T12:00:00.000Z',
              updatedAtUtc: '2026-08-09T12:00:00.000Z',
            ),
          );
      var deletes = 0;
      final service = _service(
        database,
        secrets,
        MockClient((request) async {
          if (request.method == 'PROPFIND') return _adminProbe(request);
          if (request.method == 'DELETE') deletes += 1;
          return http.Response('', HttpStatus.noContent);
        }),
      );

      await expectLater(
        service.deleteTaskList('collection'),
        throwsA(
          isA<DavException>().having(
            (error) => error.code,
            'code',
            'DavCollectionHasPendingChanges',
          ),
        ),
      );
      expect(deletes, 0);
    },
  );

  test('parent unbind denial prevents collection DELETE', () async {
    await _seedCollection(
      database,
      privileges: const ['{DAV:}read'],
      readOnly: true,
    );
    var requests = 0;
    final service = _service(
      database,
      secrets,
      MockClient((request) async {
        if (request.method == 'PROPFIND') {
          return _adminProbe(request, parentWritable: false);
        }
        requests += 1;
        return http.Response('', HttpStatus.noContent);
      }),
    );

    await expectLater(
      service.deleteTaskList('collection'),
      throwsA(
        isA<DavException>().having(
          (error) => error.code,
          'code',
          'DavCollectionRemovalDenied',
        ),
      ),
    );
    expect(requests, 0);
  });
}

http.Response _adminProbe(
  http.Request request, {
  bool shared = false,
  bool parentWritable = true,
}) => http.Response(
  '<d:multistatus xmlns:d="DAV:" xmlns:c="urn:ietf:params:xml:ns:caldav"><d:response><d:href>${request.url.path}</d:href><d:propstat><d:prop><d:resourcetype><d:collection/><c:calendar/></d:resourcetype><d:owner><d:href>/remote.php/dav/principals/users/${shared ? 'bob' : 'alex'}/</d:href></d:owner><d:current-user-privilege-set><d:privilege><d:read/></d:privilege><d:privilege><d:write-properties/></d:privilege>${parentWritable ? '<d:privilege><d:unbind/></d:privilege>' : ''}</d:current-user-privilege-set></d:prop><d:status>HTTP/1.1 200 OK</d:status></d:propstat></d:response></d:multistatus>',
  207,
);

DavTaskListMutationService _service(
  AppDatabase database,
  SecretStore secrets,
  http.Client client, {
  Future<void> Function()? refresh,
}) {
  var correlation = 0;
  return DavTaskListMutationService(
    database: database,
    secretStore: secrets,
    httpClient: client,
    accountId: 'account',
    refreshAfterMutation: refresh ?? () async {},
    correlationIdFactory: () => 'correlation-${correlation += 1}',
  );
}

Future<void> _seedAccount(
  AppDatabase database,
  InMemorySecretStore secrets,
) async {
  const now = '2026-08-09T12:00:00.000Z';
  await database
      .into(database.accounts)
      .insert(
        AccountsCompanion.insert(
          id: 'account',
          provider: 'nextcloud',
          authority: 'https://cloud.example.test',
          providerAccountId: 'alex',
          credentialKind: 'nextcloud_app_password',
          createdAtUtc: now,
          updatedAtUtc: now,
        ),
      );
  await database
      .into(database.davAccountServices)
      .insert(
        DavAccountServicesCompanion.insert(
          accountId: 'account',
          canonicalServiceUri: 'https://cloud.example.test/remote.php/dav/',
          canonicalOrigin: 'https://cloud.example.test',
          principalHref: const Value('/remote.php/dav/principals/users/alex/'),
          calendarHomeHref: const Value(
            'https://cloud.example.test/remote.php/dav/calendars/alex/',
          ),
          discoveredAtUtc: now,
        ),
      );
  await secrets.saveCredential(
    'account',
    NextcloudSecretRecord(
      canonicalServer: Uri.parse('https://cloud.example.test'),
      loginName: 'alex',
      appPassword: 'application-password',
    ),
  );
}

Future<void> _seedCollection(
  AppDatabase database, {
  String id = 'collection',
  String member = 'tasks',
  String ownerHref = '/remote.php/dav/principals/users/alex/',
  required List<String> privileges,
  bool readOnly = false,
}) async {
  const now = '2026-08-09T12:00:00.000Z';
  await database
      .into(database.davCollections)
      .insert(
        DavCollectionsCompanion.insert(
          id: id,
          accountId: 'account',
          hrefKey: '/remote.php/dav/calendars/alex/$member/',
          requestUri:
              'https://cloud.example.test/remote.php/dav/calendars/alex/$member/',
          displayName: 'Tasks',
          supportedComponentMask: const Value(davComponentTodo),
          currentUserPrivilegesJson: Value(_jsonStrings(privileges)),
          ownerHref: Value(ownerHref),
          readOnly: Value(readOnly),
          taskProjectionEnabled: const Value(true),
          createdAtUtc: now,
          updatedAtUtc: now,
        ),
      );
}

String _jsonStrings(List<String> values) =>
    '[${values.map((value) => '"$value"').join(',')}]';

String _createdCollectionMultistatus(String displayName) =>
    '<?xml version="1.0"?>'
    '<d:multistatus xmlns:d="DAV:" '
    'xmlns:c="urn:ietf:params:xml:ns:caldav">'
    '<d:response><d:href>/remote.php/dav/calendars/alex/recovered/</d:href>'
    '<d:propstat><d:prop>'
    '<d:resourcetype><d:collection/><c:calendar/></d:resourcetype>'
    '<d:displayname>$displayName</d:displayname>'
    '<c:supported-calendar-component-set><c:comp name="VTODO"/>'
    '</c:supported-calendar-component-set>'
    '</d:prop><d:status>HTTP/1.1 200 OK</d:status></d:propstat>'
    '</d:response></d:multistatus>';

const _successfulProppatch =
    '<?xml version="1.0"?>'
    '<d:multistatus xmlns:d="DAV:"><d:response>'
    '<d:href>/remote.php/dav/calendars/alex/tasks/</d:href>'
    '<d:propstat><d:prop><d:displayname/></d:prop>'
    '<d:status>HTTP/1.1 200 OK</d:status></d:propstat>'
    '</d:response></d:multistatus>';

const _forbiddenProppatch =
    '<?xml version="1.0"?>'
    '<d:multistatus xmlns:d="DAV:"><d:response>'
    '<d:href>/remote.php/dav/calendars/alex/tasks/</d:href>'
    '<d:propstat><d:prop><d:displayname/></d:prop>'
    '<d:status>HTTP/1.1 403 Forbidden</d:status></d:propstat>'
    '</d:response></d:multistatus>';

final class _OfflineTestException implements Exception {
  const _OfflineTestException();
}

import 'dart:io';

import 'package:busymax/src/core/secrets/secret_store.dart';
import 'package:busymax/src/dav/dav_errors.dart';
import 'package:busymax/src/dav/mutation/dav_calendar_collection_mutation_service.dart';
import 'package:busymax/src/dav/mutation/dav_collection_administration.dart';
import 'package:busymax/src/dav/mutation/dav_task_list_mutation_service.dart';
import 'package:busymax/src/db/app_database.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:xml/xml.dart';

const _id = '03dcaedb-314a-46e3-824b-760521fb400b';
const _home = 'https://example.test/home/';
const _target = '${_home}busymax-$_id/';

void main() {
  for (final component in ['VEVENT', 'VTODO']) {
    group(component, () {
      late _Fixture f;
      setUp(() async {
        f = await _Fixture.open(component);
      });
      tearDown(() => f.close());

      test(
        'fresh creation dispatches once and records a committed operation',
        () async {
          expect(
            await f.admin.create('Work', {component}),
            DavCollectionAdministrationOutcome.committed,
          );
          expect(f.writes, 1);
          final op = await f.database
              .select(f.database.davCollectionCreations)
              .getSingle();
          expect(op.state, 'committed');
          expect(op.id, _id);
          expect(op.targetUri, _target);
        },
      );

      test(
        'fresh matching pre-existing target is a conflict, never created',
        () async {
          f.remote = f.collectionXml;
          await expectLater(
            f.admin.create('Work', {component}),
            throwsA(
              isA<DavException>().having(
                (e) => e.code,
                'code',
                'DavCollectionNameConflict',
              ),
            ),
          );
          expect(f.writes, 0);
          expect(
            (await f.database
                    .select(f.database.davCollectionCreations)
                    .getSingle())
                .state,
            'rejected',
          );
        },
      );

      test(
        'advertised Extended MKCOL sets its required resource type',
        () async {
          f.extendedMkcol = true;
          expect(
            await f.admin.create('Work', {component}),
            DavCollectionAdministrationOutcome.committed,
          );
          expect(f.writes, 1);
        },
      );

      test('lost committed response reconciles this operation without another write', () async {
        f.loseResponse = true;
        expect(
          await f.admin.create('Work', {component}),
          DavCollectionAdministrationOutcome.reconciled,
        );
        expect(f.writes, 1);
        expect(
          await f.admin.resumeCreation(_id),
          DavCollectionAdministrationOutcome.reconciled,
        );
        expect(f.writes, 1);
      });

      test('interrupted dispatched operation survives database reopening and reconciles', () async {
        f.interrupt = true;
        await expectLater(
          f.admin.create('Work', {component}),
          throwsA(anything),
        );
        expect(
          (await f.database
                  .select(f.database.davCollectionCreations)
                  .getSingle())
              .state,
          'dispatched',
        );
        await f.reopen();
        expect(
          await f.admin.resumeCreation(_id),
          DavCollectionAdministrationOutcome.reconciled,
        );
        expect(f.writes, 1);
      });

      test(
        'retry of persisted pending operation checks absence before dispatch',
        () async {
          f.interrupt = true;
          f.commitBeforeInterrupt = false;
          await expectLater(
            f.admin.create('Work', {component}),
            throwsA(anything),
          );
          await f.reopen();
          f.interrupt = false;
          expect(
            await f.admin.resumeCreation(_id),
            DavCollectionAdministrationOutcome.committed,
          );
          expect(f.writes, 2);
          expect(f.preflightBeforeRetry, isTrue);
        },
      );

      test(
        'fresh request cannot adopt another pending operation by title',
        () async {
          f.interrupt = true;
          await expectLater(
            f.admin.create('Work', {component}),
            throwsA(anything),
          );
          await f.reopen();
          await expectLater(
            f.admin.create('Work', {component}),
            throwsA(
              isA<DavException>().having(
                (e) => e.code,
                'code',
                'DavCollectionCreationPending',
              ),
            ),
          );
          expect(f.writes, 1);
        },
      );

      test(
        'unknown or wrong-account operation ID cannot authorize recovery',
        () async {
          await expectLater(
            f.admin.resumeCreation(_id),
            throwsA(
              isA<DavException>().having((e) => e.statusCode, 'status', 404),
            ),
          );
          expect(f.writes, 0);
        },
      );

      test(
        'definitive namespace conflict cannot become successful recovery',
        () async {
          f.rejectionStatus = 409;
          await expectLater(
            f.admin.create('Work', {component}),
            throwsA(isA<DavException>()),
          );
          await f.reopen();
          await expectLater(
            f.admin.resumeCreation(_id),
            throwsA(
              isA<DavException>().having(
                (e) => e.code,
                'code',
                'DavCollectionNameConflict',
              ),
            ),
          );
          expect(f.writes, 1);
          expect(
            (await f.database
                    .select(f.database.davCollectionCreations)
                    .getSingle())
                .state,
            'rejected',
          );
        },
      );

      test('pending recovery rejects mismatched remote intent', () async {
        f.interrupt = true;
        await expectLater(
          f.admin.create('Work', {component}),
          throwsA(anything),
        );
        await f.reopen();
        f.remote = f.collectionXml.replaceFirst('Work', 'Unrelated');
        await expectLater(
          f.admin.resumeCreation(_id),
          throwsA(
            isA<DavException>().having(
              (e) => e.code,
              'code',
              'DavCollectionNameConflict',
            ),
          ),
        );
        expect(f.writes, 1);
      });

      test('another account cannot resume an existing operation ID', () async {
        await f.admin.create('Work', {component});
        final other = DavCollectionAdministration(
          database: f.database,
          secrets: f.secrets,
          client: f.client,
          accountId: 'other-account',
          refresh: () async {},
          requireNetwork: () async {},
        );
        await expectLater(
          other.resumeCreation(_id),
          throwsA(
            isA<DavException>().having((e) => e.statusCode, 'status', 404),
          ),
        );
        expect(f.writes, 1);
      });

      test(
        'account removal cascades pending creation without resurrection',
        () async {
          f.interrupt = true;
          await expectLater(
            f.admin.create('Work', {component}),
            throwsA(anything),
          );
          await f.database.delete(f.database.accounts).go();
          await f.reopen();
          await expectLater(
            f.admin.resumeCreation(_id),
            throwsA(isA<DavException>()),
          );
          expect(
            await f.database.select(f.database.davCollectionCreations).get(),
            isEmpty,
          );
          expect(f.writes, 1);
        },
      );

      test('calendar/task service never reports success for unrelated existing metadata', () async {
        await f.database
            .into(f.database.davCollections)
            .insert(
              DavCollectionsCompanion.insert(
                id: 'existing',
                accountId: 'qa',
                hrefKey: '/home/existing/',
                requestUri: '${_home}existing/',
                displayName: 'Work',
                createdAtUtc: 'now',
                updatedAtUtc: 'now',
                eventProjectionEnabled: const Value(true),
                taskProjectionEnabled: const Value(true),
              ),
            );
        if (component == 'VEVENT') {
          final service = DavCalendarCollectionMutationService(
            database: f.database,
            secretStore: f.secrets,
            httpClient: f.client,
            accountId: 'qa',
            refreshAfterMutation: () async {},
          );
          await expectLater(
            service.createEventCalendar('Work'),
            throwsA(isA<DavException>()),
          );
        } else {
          final service = DavTaskListMutationService(
            database: f.database,
            secretStore: f.secrets,
            httpClient: f.client,
            accountId: 'qa',
            refreshAfterMutation: () async {},
          );
          await expectLater(
            service.createTaskList('Work'),
            throwsA(isA<DavException>()),
          );
        }
        expect(f.writes, 0);
      });
    });
  }
}

class _Fixture {
  _Fixture(this.directory, this.component);
  final Directory directory;
  final String component;
  late AppDatabase database;
  final secrets = InMemorySecretStore();
  late final http.Client client = MockClient(handle);
  int writes = 0;
  int? rejectionStatus;
  bool loseResponse = false,
      interrupt = false,
      commitBeforeInterrupt = true,
      extendedMkcol = false;
  bool preflightBeforeRetry = false;
  String? remote;
  String get collectionXml =>
      '<d:resourcetype><d:collection/><c:calendar/></d:resourcetype><d:displayname>Work</d:displayname><c:supported-calendar-component-set><c:comp name="$component"/></c:supported-calendar-component-set>';
  DavCollectionAdministration get admin => DavCollectionAdministration(
    database: database,
    secrets: secrets,
    client: client,
    accountId: 'qa',
    refresh: () async {},
    requireNetwork: () async {},
    creationIdFactory: () => _id,
  );

  static Future<_Fixture> open(String component) async {
    final f = _Fixture(
      await Directory.systemTemp.createTemp('busymax-creation-'),
      component,
    );
    f.database = AppDatabase(
      NativeDatabase(File('${f.directory.path}/qa.sqlite')),
    );
    await f.database
        .into(f.database.accounts)
        .insert(
          AccountsCompanion.insert(
            id: 'qa',
            provider: 'caldav',
            authority: 'https://example.test/',
            providerAccountId: 'alice',
            credentialKind: 'caldav_password',
            createdAtUtc: 'now',
            updatedAtUtc: 'now',
          ),
        );
    await f.database
        .into(f.database.davAccountServices)
        .insert(
          DavAccountServicesCompanion.insert(
            accountId: 'qa',
            canonicalServiceUri: 'https://example.test/',
            canonicalOrigin: 'https://example.test',
            calendarHomeHref: const Value(_home),
            discoveredAtUtc: 'now',
          ),
        );
    await f.secrets.saveCredential(
      'qa',
      CalDavSecretRecord(
        serviceAuthority: Uri.parse('https://example.test/'),
        username: 'alice',
        password: 'test-password',
      ),
    );
    return f;
  }

  Future<http.Response> handle(http.Request request) async {
    if (interrupt &&
        writes > 0 &&
        request.method == 'PROPFIND' &&
        request.url.toString() == _target) {
      throw http.ClientException('reconciliation interrupted');
    }
    if (request.method == 'OPTIONS') {
      return http.Response(
        '',
        200,
        headers: extendedMkcol
            ? {'dav': '1, extended-mkcol', 'allow': 'MKCOL'}
            : {'dav': 'calendar-access', 'allow': 'MKCALENDAR'},
      );
    }
    if (request.method == 'MKCALENDAR' || request.method == 'MKCOL') {
      expect(request.method, extendedMkcol ? 'MKCOL' : 'MKCALENDAR');
      expect(
        (await database.select(database.davCollectionCreations).getSingle())
            .state,
        'dispatched',
      );
      expect(
        XmlDocument.parse(request.body).descendants.whereType<XmlElement>().any(
          (e) => e.name.local == 'comp' && e.getAttribute('name') == component,
        ),
        isTrue,
      );
      expect(request.body.contains('<d:resourcetype>'), extendedMkcol);
      writes++;
      if (rejectionStatus != null) {
        remote = collectionXml;
        return http.Response('', rejectionStatus!);
      }
      if (interrupt && !commitBeforeInterrupt) {
        throw StateError('interrupted before remote commit');
      }
      remote = collectionXml;
      if (interrupt) throw StateError('interrupted after remote commit');
      if (loseResponse) throw http.ClientException('response lost');
      return http.Response('', 201);
    }
    if (request.url.toString() == _target && writes > 0) {
      preflightBeforeRetry = true;
    }
    final properties = request.url.toString() == _home
        ? '<d:resourcetype><d:collection/></d:resourcetype><d:current-user-privilege-set><d:privilege><d:bind/></d:privilege></d:current-user-privilege-set>'
        : remote;
    if (properties == null) return http.Response('', 404);
    return http.Response(
      '<d:multistatus xmlns:d="DAV:" xmlns:c="urn:ietf:params:xml:ns:caldav"><d:response><d:href>${request.url}</d:href><d:propstat><d:prop>$properties</d:prop><d:status>HTTP/1.1 200 OK</d:status></d:propstat></d:response></d:multistatus>',
      207,
    );
  }

  Future<void> reopen() async {
    await database.close();
    database = AppDatabase(NativeDatabase(File('${directory.path}/qa.sqlite')));
    interrupt = false;
    preflightBeforeRetry = false;
  }

  Future<void> close() async {
    client.close();
    await database.close();
    await directory.delete(recursive: true);
  }
}

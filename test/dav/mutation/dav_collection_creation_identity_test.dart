import 'dart:io';
import 'dart:convert';

import 'package:busymax/src/core/secrets/secret_store.dart';
import 'package:busymax/src/dav/dav_errors.dart';
import 'package:busymax/src/dav/mutation/dav_calendar_collection_mutation_service.dart';
import 'package:busymax/src/dav/mutation/dav_collection_administration.dart';
import 'package:busymax/src/dav/mutation/dav_task_list_mutation_service.dart';
import 'package:busymax/src/db/app_database.dart';
import 'package:busymax/src/features/calendar/data/calendar_repository.dart';
import 'package:busymax/src/providers/busy_provider.dart';
import 'package:busymax/src/calendar_providers/calendar_colors.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:xml/xml.dart';

import '../../support/persistence_test_directory.dart';

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

      test('network failure before dispatch retains the prepared identity across restart', () async {
        f.optionsNetworkFailure = true;
        await expectLater(
          f.admin.create('Work', {component}),
          throwsA(
            isA<DavException>().having(
              (e) => e.kind,
              'network failure',
              DavErrorKind.network,
            ),
          ),
        );
        final prepared = await f.database
            .select(f.database.davCollectionCreations)
            .getSingle();
        expect(prepared.state, 'prepared');
        expect(prepared.lastErrorKind, 'network');
        expect(f.writes, 0);
        await f.reopen();
        f.optionsNetworkFailure = false;
        expect(
          await f.admin.resumeCreation(prepared.id),
          DavCollectionAdministrationOutcome.committed,
        );
        expect(f.writes, 1);
        expect(
          (await f.database
                  .select(f.database.davCollectionCreations)
                  .getSingle())
              .id,
          prepared.id,
        );
      });

      for (final denial in ['bind', 'method', 'http403']) {
        test(
          'definitive $denial rejection is durable and never retried',
          () async {
            f.bindDenied = denial == 'bind';
            f.unsupported = denial == 'method';
            f.rejectionStatus = denial == 'http403' ? 403 : null;
            await expectLater(
              f.admin.create('Work', {component}),
              throwsA(isA<DavException>()),
            );
            final row = await f.database
                .select(f.database.davCollectionCreations)
                .getSingle();
            expect(row.state, 'rejected');
            expect(row.lastErrorStatus, denial == 'method' ? 405 : 403);
            expect(
              row.lastErrorKind,
              denial == 'method' ? 'protocol' : 'authorization',
            );
            expect(f.writes, denial == 'http403' ? 1 : 0);
            expect(f.remote, isNull);
            final writes = f.writes;
            await f.reopen();
            await expectLater(
              f.admin.resumeCreation(_id),
              throwsA(
                isA<DavException>().having(
                  (e) => e.code,
                  'stored reason',
                  row.lastErrorCode,
                ),
              ),
            );
            expect(f.writes, writes);
          },
        );
      }
      test('prepared transient failure survives reopening and uses the same operation', () async {
        f.optionsStatus = 503;
        await expectLater(
          f.admin.create('Work', {component}),
          throwsA(isA<DavException>()),
        );
        var row = await f.database
            .select(f.database.davCollectionCreations)
            .getSingle();
        expect(row.state, 'prepared');
        expect(row.lastErrorStatus, 503);
        expect(f.writes, 0);
        await f.reopen();
        f.optionsStatus = 200;
        expect(
          await f.admin.resumeCreation(_id),
          DavCollectionAdministrationOutcome.committed,
        );
        row = await f.database
            .select(f.database.davCollectionCreations)
            .getSingle();
        expect(row.id, _id);
        expect(row.targetUri, _target);
        expect(row.state, 'committed');
        expect(row.lastErrorCode, isNull);
        expect(f.writes, 1);
      });
      test(
        'prepared intent can resume after process restart before any request',
        () async {
          await f.prepare();
          await f.reopen();
          expect(
            await f.admin.resumeCreation(_id),
            DavCollectionAdministrationOutcome.committed,
          );
          expect(f.writes, 1);
        },
      );
      test(
        'malformed prepared intent is rejected without a remote mutation',
        () async {
          await f.prepare(components: 'invalid-json');
          await expectLater(
            f.admin.resumeCreation(_id),
            throwsA(isA<DavException>()),
          );
          final row = await f.database
              .select(f.database.davCollectionCreations)
              .getSingle();
          expect(row.state, 'rejected');
          expect(row.lastErrorCode, 'DavCollectionCreationInvalid');
          expect(f.writes, 0);
        },
      );
      test('an already committed dispatched intent reconciles after bind is revoked', () async {
        f.interrupt = true;
        await expectLater(
          f.admin.create('Work', {component}),
          throwsA(isA<DavException>()),
        );
        await f.reopen();
        f.bindDenied = true;
        expect(
          await f.admin.resumeCreation(_id),
          DavCollectionAdministrationOutcome.reconciled,
        );
        expect(f.writes, 1);
      });
      test('credential failure before dispatch remains authentication, not rejection', () async {
        f.optionsStatus = 401;
        await expectLater(
          f.admin.create('Work', {component}),
          throwsA(
            isA<DavException>().having(
              (e) => e.kind,
              'kind',
              DavErrorKind.authentication,
            ),
          ),
        );
        expect(
          (await f.database
                  .select(f.database.davCollectionCreations)
                  .getSingle())
              .state,
          'prepared',
        );
        expect(f.writes, 0);
      });
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

      test('lost response and unavailable reconciliation retain the operation across restart', () async {
        f.loseResponse = true;
        f.reconciliationUnavailable = true;
        await expectLater(
          f.admin.create('Work', {component}),
          throwsA(
            isA<DavException>().having((e) => e.statusCode, 'status', 503),
          ),
        );
        expect(f.writes, 1);
        expect(f.unavailableProbes, 3);
        expect(
          DavCollectionAdministration.creationIsActive('qa', _id),
          isFalse,
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

      test('interrupted dispatched operation survives database reopening and reconciles', () async {
        f.interrupt = true;
        await expectLater(
          f.admin.create('Work', {component}),
          throwsA(
            isA<DavException>().having(
              (e) => e.kind,
              'kind',
              DavErrorKind.cancelled,
            ),
          ),
        );
        expect(f.interruptedProbes, 1);
        expect(
          DavCollectionAdministration.creationIsActive('qa', _id),
          isFalse,
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
            throwsA(
              isA<DavException>().having(
                (e) => e.kind,
                'kind',
                DavErrorKind.cancelled,
              ),
            ),
          );
          expect(f.interruptedProbes, 1);
          expect(
            DavCollectionAdministration.creationIsActive('qa', _id),
            isFalse,
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
            throwsA(
              isA<DavException>().having(
                (e) => e.kind,
                'kind',
                DavErrorKind.cancelled,
              ),
            ),
          );
          expect(f.interruptedProbes, 1);
          expect(
            DavCollectionAdministration.creationIsActive('qa', _id),
            isFalse,
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
                'DavCollectionCreationFailed',
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
          throwsA(
            isA<DavException>().having(
              (e) => e.kind,
              'kind',
              DavErrorKind.cancelled,
            ),
          ),
        );
        expect(f.interruptedProbes, 1);
        expect(
          DavCollectionAdministration.creationIsActive('qa', _id),
          isFalse,
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
            throwsA(
              isA<DavException>().having(
                (e) => e.kind,
                'kind',
                DavErrorKind.cancelled,
              ),
            ),
          );
          expect(f.interruptedProbes, 1);
          expect(
            DavCollectionAdministration.creationIsActive('qa', _id),
            isFalse,
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

      test(
        'committed calendar/task creation distinguishes a failed refresh',
        () async {
          if (component == 'VEVENT') {
            final result = await DavCalendarCollectionMutationService(
              database: f.database,
              secretStore: f.secrets,
              httpClient: f.client,
              accountId: 'qa',
              refreshAfterMutation: () async =>
                  throw StateError('refresh failed'),
            ).createEventCalendar('Work');
            expect(result.refreshPending, isTrue);
          } else {
            await expectLater(
              DavTaskListMutationService(
                database: f.database,
                secretStore: f.secrets,
                httpClient: f.client,
                accountId: 'qa',
                refreshAfterMutation: () async =>
                    throw StateError('refresh failed'),
              ).createTaskList('Work'),
              throwsA(isA<DavRefreshPending>()),
            );
          }
          expect(f.writes, 1);
          expect(f.remote, isNotNull);
          expect(
            (await f.database
                    .select(f.database.davCollectionCreations)
                    .getSingle())
                .state,
            'committed',
          );
        },
      );

      for (final action in ['rename', 'color', 'delete']) {
        test(
          '$action committed but refresh failed uses the neutral exception',
          () async {
            f.remote = f.collectionXml;
            f.refreshFails = true;
            await f.database
                .into(f.database.davCollections)
                .insert(
                  DavCollectionsCompanion.insert(
                    id: 'collection',
                    accountId: 'qa',
                    hrefKey: Uri.parse(_target).path,
                    requestUri: _target,
                    displayName: 'Work',
                    createdAtUtc: 'now',
                    updatedAtUtc: 'now',
                    safeDisplayMetadataJson: const Value(
                      '{"parentPrivilegesKnown":"false"}',
                    ),
                    supportedComponentMask: Value(
                      component == 'VEVENT' ? 1 : 2,
                    ),
                    eventProjectionEnabled: Value(component == 'VEVENT'),
                    taskProjectionEnabled: Value(component == 'VTODO'),
                  ),
                );
            Future<void> mutation;
            if (component == 'VEVENT') {
              await f.database
                  .into(f.database.calendarSources)
                  .insert(
                    CalendarSourcesCompanion.insert(
                      id: 'source',
                      accountId: 'qa',
                      provider: 'caldav',
                      providerCalendarId: _target,
                      davCollectionId: const Value('collection'),
                      summary: 'Work',
                      createdAtLocal: 0,
                      updatedAtLocal: 0,
                    ),
                  );
              final repository = CalendarRepository(
                database: f.database,
                genericCollections: (_) => f.admin,
              );
              mutation = switch (action) {
                'rename' => repository.renameLocalSource('source', 'Changed'),
                'color' => repository.setSourceColor(
                  'source',
                  calendarColorChoices(BusyProvider.caldav).first,
                ),
                _ => repository.deleteLocalSource('source'),
              };
            } else {
              final service = DavTaskListMutationService(
                database: f.database,
                secretStore: f.secrets,
                httpClient: f.client,
                accountId: 'qa',
                refreshAfterMutation: () async =>
                    throw StateError('refresh failed'),
              );
              mutation = switch (action) {
                'rename' => service.renameTaskList('collection', 'Changed'),
                'color' =>
                  service
                      .setTaskListMetadata('collection', color: '#123456')
                      .then((_) {}),
                _ => service.deleteTaskList('collection'),
              };
            }
            await expectLater(mutation, throwsA(isA<DavRefreshPending>()));
            expect(f.metadataWrites, 1);
            if (action == 'delete') {
              expect(f.remote, isNull);
            } else {
              expect(
                f.remote,
                contains(action == 'rename' ? 'Changed' : 'calendar-color'),
              );
            }
          },
        );
      }

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
  int metadataWrites = 0;
  bool refreshFails = false;
  bool optionsNetworkFailure = false;
  int writes = 0, interruptedProbes = 0, unavailableProbes = 0;
  int? rejectionStatus;
  int optionsStatus = 200;
  bool bindDenied = false, unsupported = false;
  bool loseResponse = false,
      interrupt = false,
      commitBeforeInterrupt = true,
      reconciliationUnavailable = false,
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
    refresh: () async {
      if (refreshFails) throw StateError('refresh failed');
    },
    requireNetwork: () async {},
    creationIdFactory: () => _id,
  );

  static Future<_Fixture> open(String component) async {
    final f = _Fixture(
      await createPersistenceTestDirectory('busymax-creation-'),
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
    if (reconciliationUnavailable &&
        writes > 0 &&
        request.method == 'PROPFIND' &&
        request.url.toString() == _target) {
      unavailableProbes++;
      return http.Response('', 503, headers: {'retry-after': '0'});
    }
    if (interrupt &&
        writes > 0 &&
        request.method == 'PROPFIND' &&
        request.url.toString() == _target) {
      // This fixture models a stopped process, which cannot keep retrying
      // network reads until test teardown. Network loss with reconciliation
      // remains covered separately by loseResponse and the real-server suite.
      interruptedProbes++;
      throw const DavException(
        kind: DavErrorKind.cancelled,
        code: 'TestProcessStopped',
        safeMessage: 'The simulated process stopped before reconciliation.',
      );
    }
    if (request.method == 'PROPPATCH') {
      metadataWrites++;
      final props = XmlDocument.parse(request.body).descendants
          .whereType<XmlElement>()
          .firstWhere((e) => e.name.local == 'prop');
      remote =
          '<d:resourcetype><d:collection/><c:calendar/></d:resourcetype>${props.children.join()}';
      return http.Response(
        '<d:multistatus xmlns:d="DAV:" xmlns:c="urn:ietf:params:xml:ns:caldav" xmlns:a="http://apple.com/ns/ical/"><d:response><d:href>${request.url}</d:href><d:propstat><d:prop>${props.children.join()}</d:prop><d:status>HTTP/1.1 200 OK</d:status></d:propstat></d:response></d:multistatus>',
        207,
      );
    }
    if (request.method == 'DELETE') {
      metadataWrites++;
      remote = null;
      return http.Response('', 204);
    }
    if (request.method == 'OPTIONS') {
      if (optionsNetworkFailure) {
        throw http.ClientException('Simulated pre-dispatch connection loss');
      }
      return http.Response(
        '',
        optionsStatus,
        headers: optionsStatus == 503
            ? {'retry-after': '0'}
            : unsupported
            ? {'dav': '1', 'allow': 'GET, PROPFIND'}
            : extendedMkcol
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
        if (const {405, 409, 412}.contains(rejectionStatus)) {
          remote = collectionXml;
        }
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
        ? '<d:resourcetype><d:collection/></d:resourcetype><d:current-user-privilege-set><d:privilege><d:${bindDenied ? 'read' : 'all'}/></d:privilege></d:current-user-privilege-set>'
        : remote;
    if (properties == null) return http.Response('', 404);
    return http.Response(
      '<d:multistatus xmlns:d="DAV:" xmlns:c="urn:ietf:params:xml:ns:caldav"><d:response><d:href>${request.url}</d:href><d:propstat><d:prop>$properties</d:prop><d:status>HTTP/1.1 200 OK</d:status></d:propstat></d:response></d:multistatus>',
      207,
    );
  }

  Future<int> prepare({String? components}) => database
      .into(database.davCollectionCreations)
      .insert(
        DavCollectionCreationsCompanion.insert(
          id: _id,
          accountId: 'qa',
          authority: 'https://example.test/',
          homeUri: _home,
          targetUri: _target,
          displayName: 'Work',
          componentsJson: components ?? jsonEncode([component]),
          createdAtUtc: 'now',
        ),
      );

  Future<void> reopen() async {
    await database.close();
    database = AppDatabase(NativeDatabase(File('${directory.path}/qa.sqlite')));
    interrupt = false;
    reconciliationUnavailable = false;
    preflightBeforeRetry = false;
  }

  Future<void> close() async {
    client.close();
    await database.close();
    await directory.delete(recursive: true);
  }
}

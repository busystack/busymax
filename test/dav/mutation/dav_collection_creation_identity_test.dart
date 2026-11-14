import 'dart:io';
import 'dart:convert';
import 'dart:isolate';

import 'package:busymax/src/core/auth/authorization_gate.dart';
import 'package:busymax/src/core/secrets/secret_store.dart';
import 'package:busymax/src/dav/dav_errors.dart';
import 'package:busymax/src/dav/xml/dav_xml.dart';
import 'package:busymax/src/dav/mutation/dav_calendar_collection_mutation_service.dart';
import 'package:busymax/src/dav/mutation/dav_collection_administration.dart';
import 'package:busymax/src/dav/mutation/dav_task_list_mutation_service.dart';
import 'package:busymax/src/dav/storage/dav_collection_creation_notices.dart';
import 'package:busymax/src/db/app_database.dart';
import 'package:busymax/src/db/native_database_connection.dart';
import 'package:busymax/src/features/calendar/data/calendar_repository.dart';
import 'package:busymax/src/features/sync/account_sync_operations.dart';
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
        'creation negotiates methods at its persisted reserved URL',
        () async {
          f.creationMethodsOnlyAtTarget = true;
          expect(
            await f.admin.create('Work', {component}),
            DavCollectionAdministrationOutcome.committed,
          );
          expect(f.writes, 1);
        },
      );

      for (final (headers, supported, extended) in [
        (<String, String>{}, true, false),
        ({'allow': 'GET, PROPFIND'}, false, false),
        ({'allow': ''}, false, false),
        ({'allow': 'MKCALENDAR'}, true, false),
        ({'allow': 'MKCOL', 'dav': 'extended-mkcol'}, true, true),
        ({'allow': 'MKCOL'}, false, false),
      ]) {
        test('target OPTIONS 405 respects Allow $headers', () async {
          f.creationMethodsOnlyAtTarget = true;
          f.targetOptionsUnavailable = true;
          f.targetOptionsStatus = 405;
          f.targetOptionsHeaders = headers;
          f.extendedMkcol = extended;
          if (supported) {
            expect(
              await f.admin.create('Work', {component}),
              DavCollectionAdministrationOutcome.committed,
            );
            expect(f.writes, 1);
          } else {
            await expectLater(
              f.admin.create('Work', {component}),
              throwsA(
                isA<DavException>().having(
                  (e) => e.code,
                  'code',
                  'DavCollectionCreationUnsupported',
                ),
              ),
            );
            expect(f.writes, 0);
            final rejected = await f.database
                .select(f.database.davCollectionCreations)
                .getSingle();
            expect(rejected.state, 'rejected');
            expect(rejected.lastErrorStatus, 405);
            await f.reopen();
            await expectLater(
              f.admin.resumeCreation(rejected.id),
              throwsA(isA<DavException>()),
            );
            expect(f.writes, 0);
          }
        });
      }
      for (final committed in [false, true]) {
        test(
          'target OPTIONS 405 Allow preserves uncertain operation recovery committed=$committed',
          () async {
            f.creationMethodsOnlyAtTarget = true;
            f.targetOptionsUnavailable = true;
            f.interrupt = true;
            f.commitBeforeInterrupt = committed;
            await expectLater(
              f.admin.create('Work', {component}),
              throwsA(isA<DavException>()),
            );
            expect(f.writes, 1);
            await f.reopen();
            f.interrupt = false;
            f.targetOptionsStatus = 405;
            f.targetOptionsHeaders = {'allow': 'GET, PROPFIND'};
            if (committed) {
              expect(
                await f.admin.resumeCreation(_id),
                DavCollectionAdministrationOutcome.reconciled,
              );
            } else {
              await expectLater(
                f.admin.resumeCreation(_id),
                throwsA(
                  isA<DavException>().having(
                    (e) => e.kind,
                    'unresolved prior dispatch',
                    DavErrorKind.unknownOutcome,
                  ),
                ),
              );
            }
            expect(f.writes, 1);
            final operation = await f.database
                .select(f.database.davCollectionCreations)
                .getSingle();
            expect(operation.id, _id);
            expect(operation.targetUri, _target);
            expect(operation.state, committed ? 'committed' : 'dispatched');
          },
        );
      }
      for (final denied in [false, true]) {
        test(
          'target OPTIONS 405 without Allow still requires explicit parent authorization denied=$denied',
          () async {
            f.creationMethodsOnlyAtTarget = true;
            f.targetOptionsUnavailable = true;
            f.targetOptionsStatus = 405;
            f.bindDenied = denied;
            f.parentPrivilegesUnknown = !denied;
            await expectLater(
              f.admin.create('Work', {component}),
              throwsA(isA<DavException>()),
            );
            expect(f.writes, 0);
          },
        );
      }
      test(
        'target OPTIONS 404 Allow does not establish creation refusal',
        () async {
          f.creationMethodsOnlyAtTarget = true;
          f.targetOptionsUnavailable = true;
          f.targetOptionsHeaders = {'allow': 'GET, PROPFIND'};
          expect(
            await f.admin.create('Work', {component}),
            DavCollectionAdministrationOutcome.committed,
          );
          expect(f.writes, 1);
        },
      );

      for (final scenario in [
        'fresh',
        'existing',
        'denied-parent',
        'unknown-parent',
        'malformed-parent',
        'nested-parent',
        'denied-target',
        'lost-response',
        'restart-committed',
        'restart-absent',
        'rejected',
        'rejected-method',
        'not-implemented',
        'restart-prepared',
      ]) {
        test(
          'unknown creation method with explicit persisted intent: $scenario',
          () async {
            f.creationMethodsOnlyAtTarget = true;
            f.targetOptionsUnavailable = true;
            f.bindDenied = scenario == 'denied-parent';
            f.parentPrivilegesUnknown = scenario == 'unknown-parent';
            f.malformedParentPrivileges = scenario == 'malformed-parent';
            f.nestedParentPrivileges = scenario == 'nested-parent';
            f.targetOptionsStatus = scenario == 'denied-target' ? 403 : 404;
            f.remote = scenario == 'existing' ? f.collectionXml : null;
            f.loseResponse = scenario == 'lost-response';
            f.interrupt =
                scenario == 'restart-committed' || scenario == 'restart-absent';
            f.commitBeforeInterrupt = scenario != 'restart-absent';
            f.rejectionStatus = switch (scenario) {
              'rejected' => 403,
              'rejected-method' => 405,
              'not-implemented' => 501,
              _ => null,
            };
            if (scenario == 'restart-prepared') {
              await f.prepare();
              await f.reopen();
              expect(
                await f.admin.resumeCreation(_id),
                DavCollectionAdministrationOutcome.committed,
              );
            } else if ([
              'existing',
              'denied-parent',
              'unknown-parent',
              'malformed-parent',
              'nested-parent',
              'denied-target',
              'rejected',
              'rejected-method',
              'not-implemented',
              'restart-committed',
              'restart-absent',
            ].contains(scenario)) {
              await expectLater(
                f.admin.create('Work', {component}),
                throwsA(isA<DavException>()),
              );
              final op = await f.database
                  .select(f.database.davCollectionCreations)
                  .getSingle();
              expect(op.targetUri, _target);
              await f.reopen();
              if (scenario.startsWith('restart-')) {
                expect(op.state, 'dispatched');
                f.interrupt = false;
                if (scenario == 'restart-committed') f.bindDenied = true;
                expect(
                  await f.admin.resumeCreation(_id),
                  scenario == 'restart-committed'
                      ? DavCollectionAdministrationOutcome.reconciled
                      : DavCollectionAdministrationOutcome.committed,
                );
                expect(f.writes, scenario == 'restart-committed' ? 1 : 2);
                expect(f.preflightBeforeRetry, isTrue);
              } else {
                expect(op.state, 'rejected');
                final writes = f.writes;
                await expectLater(
                  f.admin.resumeCreation(_id),
                  throwsA(isA<DavException>()),
                );
                expect(f.writes, writes);
                expect(
                  writes,
                  const {
                        'rejected',
                        'rejected-method',
                        'not-implemented',
                      }.contains(scenario)
                      ? 1
                      : 0,
                );
              }
            } else {
              expect(
                await f.admin.create('Work', {component}),
                scenario == 'lost-response'
                    ? DavCollectionAdministrationOutcome.reconciled
                    : DavCollectionAdministrationOutcome.committed,
              );
              expect(f.writes, 1);
            }
          },
        );
      }

      for (final propertyLevel in [false, true]) {
        test(
          'parent denial in HTTP 207 is rejected durably; properties=$propertyLevel',
          () async {
            f.parentDeniedPropertyLevel = propertyLevel;
            f.parentDenied = true;
            await expectLater(
              f.admin.create('Denied', {component}),
              throwsA(
                isA<DavException>().having((e) => e.statusCode, 'status', 403),
              ),
            );
            expect(f.writes, 0);
            final op = await f.database
                .select(f.database.davCollectionCreations)
                .getSingle();
            expect(op.state, 'rejected');
            expect(op.lastErrorStatus, 403);
            await f.reopen();
            await expectLater(
              f.admin.resumeCreation(op.id),
              throwsA(
                isA<DavException>().having(
                  (e) => e.statusCode,
                  'persisted denial',
                  403,
                ),
              ),
            );
            expect(f.writes, 0);
          },
        );
      }

      for (final extended in [false, true]) {
        for (final style in ['method', 'multistatus']) {
          test(
            'optional marker rejection safely retries same operation; MKCOL=$extended, style=$style',
            () async {
              f.extendedMkcol = extended;
              f.rejectMarker = true;
              f.markerResponseStyle = style;
              f.loseResponse = true;
              expect(
                await f.admin.create('Work', {component}),
                DavCollectionAdministrationOutcome.reconciled,
              );
              expect(f.creationMarkers, [true, false]);
              await f.reopen();
              expect(
                await f.admin.resumeCreation(_id),
                DavCollectionAdministrationOutcome.reconciled,
              );
              expect(f.writes, 2);
            },
          );
        }
        test(
          'marker-free commit survives a process interruption; MKCOL=$extended',
          () async {
            f.extendedMkcol = extended;
            f.rejectMarker = true;
            f.interruptAfterFallback = true;
            await expectLater(
              f.admin.create('Work', {component}),
              throwsA(isA<DavException>()),
            );
            expect(f.creationMarkers, [true, false]);
            await f.reopen();
            expect(
              await f.admin.resumeCreation(_id),
              DavCollectionAdministrationOutcome.reconciled,
            );
            expect(f.writes, 2);
          },
        );
        for (final reason in [
          'unrelated-property',
          'occupied-target',
          'unavailable-probe',
        ]) {
          test(
            'marker retry requires a specific rejection and confirmed absence: $reason; MKCOL=$extended',
            () async {
              f.extendedMkcol = extended;
              f.rejectMarker = true;
              if (reason == 'unrelated-property') {
                f.markerFailureProperty = 'c:supported-calendar-component-set';
              }
              if (reason == 'occupied-target') {
                f.markerRejectionRemote = f.collectionXml;
              }
              if (reason == 'unavailable-probe') f.markerReadUnavailable = true;
              await expectLater(
                f.admin.create('Work', {component}),
                throwsA(isA<DavException>()),
              );
              expect(f.creationMarkers, [true]);
              expect(f.writes, 1);
            },
          );
        }
      }

      for (final mode in [
        'partial',
        'malformed',
        'complete',
        'refresh-failure',
        'lost-deleted',
        'lost-survived',
      ]) {
        test(
          'DELETE $mode reconciles refresh without claiming a surviving collection committed',
          () async {
            f.remote = f.collectionXml;
            f.deleteMode = mode;
            f.refreshFails = mode == 'refresh-failure';
            await f.database
                .into(f.database.davCollections)
                .insert(
                  DavCollectionsCompanion.insert(
                    id: 'collection',
                    accountId: 'qa',
                    hrefKey: Uri.parse(_target).path,
                    requestUri: _target,
                    displayName: 'Work',
                    ownerHref: const Value('/principals/alice/'),
                    createdAtUtc: 'now',
                    updatedAtUtc: 'now',
                  ),
                );
            if (['partial', 'malformed', 'lost-survived'].contains(mode)) {
              await expectLater(
                f.admin.remove('collection'),
                throwsA(
                  isA<DavException>().having(
                    (e) => e.code,
                    'code',
                    mode == 'partial'
                        ? 'DavCollectionRemovalPartial'
                        : 'DavCollectionOutcomeUnknown',
                  ),
                ),
              );
            } else {
              expect(await f.admin.remove('collection'), switch (mode) {
                'refresh-failure' =>
                  DavCollectionAdministrationOutcome.refreshPending,
                'lost-deleted' => DavCollectionAdministrationOutcome.reconciled,
                _ => DavCollectionAdministrationOutcome.committed,
              });
            }
            expect(
              f.metadataWrites,
              1,
              reason: 'uncertain destructive operations are never replayed',
            );
            expect(f.refreshes, 1);
            if (['partial', 'malformed', 'lost-survived'].contains(mode)) {
              expect(f.remote, isNotNull);
              expect(
                (await f.database.select(f.database.davCollections).getSingle())
                    .serverMissing,
                isFalse,
              );
            }
          },
        );
      }

      for (final scenario in [
        'nested-parent-allows',
        'nested-parent-denies',
        'direct-unverified-parent',
        'direct-other-principal',
        'direct-overlapping-parent',
      ]) {
        test('collection administration uses verified immediate parent: $scenario', () async {
          const principal = 'https://example.test/principals/alice/';
          final direct = scenario.startsWith('direct');
          final target = Uri.parse(direct ? _home : '${_home}nested/calendar/');
          final parent = target.resolve('..');
          await f.database
              .update(f.database.davAccountServices)
              .write(
                DavAccountServicesCompanion(
                  principalHref: const Value(principal),
                  capabilitiesJson: Value(
                    jsonEncode({
                      'principalContexts': [
                        if (scenario == 'direct-overlapping-parent' ||
                            scenario == 'direct-other-principal')
                          {
                            'principalHref':
                                scenario == 'direct-other-principal'
                                ? 'https://example.test/principals/bob/'
                                : principal,
                            'calendarHomeHref': parent.toString(),
                          },
                      ],
                    }),
                  ),
                ),
              );
          await f.database
              .into(f.database.davCollections)
              .insert(
                DavCollectionsCompanion.insert(
                  id: 'parent-scope',
                  accountId: 'qa',
                  hrefKey: target.path,
                  requestUri: target.toString(),
                  displayName: 'Work',
                  ownerHref: const Value('/principals/alice/'),
                  safeDisplayMetadataJson: Value(
                    jsonEncode({
                      'calendarHomeHref': _home,
                      'principalHref': principal,
                    }),
                  ),
                  createdAtUtc: 'now',
                  updatedAtUtc: 'now',
                ),
              );
          var title = 'Work';
          final calls = <http.Request>[];
          final client = MockClient((request) async {
            calls.add(request);
            if (request.method == 'DELETE') return http.Response('', 204);
            if (request.method == 'PROPPATCH') title = 'Renamed';
            final denied = scenario == 'nested-parent-denies';
            final calendarProps = f.collectionXml.replaceFirst(
              '<d:displayname>Work</d:displayname>',
              '<d:displayname>$title</d:displayname>',
            );
            final props = request.url == target
                ? '$calendarProps<d:current-user-privilege-set><d:privilege><d:write-properties/></d:privilege></d:current-user-privilege-set>'
                : '<d:resourcetype><d:collection/></d:resourcetype><d:current-user-privilege-set><d:privilege><d:${request.url == parent ? (denied ? 'read' : 'unbind') : (denied ? 'unbind' : 'read')}/></d:privilege></d:current-user-privilege-set>';
            return http.Response(
              '<d:multistatus xmlns:d="DAV:" xmlns:c="urn:ietf:params:xml:ns:caldav"><d:response><d:href>${request.url}</d:href><d:propstat><d:prop>$props</d:prop><d:status>HTTP/1.1 200 OK</d:status></d:propstat></d:response></d:multistatus>',
              207,
            );
          });
          addTearDown(client.close);
          final admin = DavCollectionAdministration(
            database: f.database,
            secrets: f.secrets,
            client: client,
            accountId: 'qa',
            refresh: () async {},
            requireNetwork: () async {},
          );
          if (scenario == 'nested-parent-denies' ||
              scenario == 'direct-unverified-parent' ||
              scenario == 'direct-other-principal') {
            await expectLater(
              admin.remove('parent-scope'),
              throwsA(
                isA<DavException>().having(
                  (e) => e.statusCode,
                  'parent authorization',
                  403,
                ),
              ),
            );
            expect(calls.where((r) => r.method == 'DELETE'), isEmpty);
            if (direct) {
              expect(
                await admin.update('parent-scope', {
                  const DavPropertyName(davNamespace, 'displayname'): 'Renamed',
                }),
                DavCollectionAdministrationOutcome.committed,
              );
              expect(calls.where((r) => r.method == 'PROPPATCH'), hasLength(1));
            }
          } else {
            expect(
              await admin.remove('parent-scope'),
              DavCollectionAdministrationOutcome.committed,
            );
            expect(calls.where((r) => r.method == 'DELETE'), hasLength(1));
          }
          if (!direct || scenario == 'direct-overlapping-parent') {
            expect(
              calls.where((r) => r.method == 'PROPFIND' && r.url == parent),
              hasLength(1),
            );
          } else {
            expect(calls.where((r) => r.url == parent), isEmpty);
          }
        });
      }

      for (final owner in [
        null,
        '',
        '/principals/alice/',
        '/principals/bob/',
      ]) {
        test(
          'collection deletion requires confirmed ownership: $owner',
          () async {
            f.remote = f.collectionXml;
            await f.database
                .into(f.database.davCollections)
                .insert(
                  DavCollectionsCompanion.insert(
                    id: 'collection',
                    accountId: 'qa',
                    hrefKey: Uri.parse(_target).path,
                    requestUri: _target,
                    displayName: 'Work',
                    ownerHref: Value(owner),
                    createdAtUtc: 'now',
                    updatedAtUtc: 'now',
                  ),
                );
            if (owner == '/principals/alice/') {
              expect(
                await f.admin.remove('collection'),
                DavCollectionAdministrationOutcome.committed,
              );
              expect(f.metadataWrites, 1);
            } else {
              await expectLater(
                f.admin.remove('collection'),
                throwsA(isA<DavException>()),
              );
              expect(f.targetReads, 0);
              expect(f.metadataWrites, 0);
            }
          },
        );
      }
      for (final liveOwner in ['', '/principals/bob/']) {
        test(
          'live missing or changed ownership blocks a cached owned collection: $liveOwner',
          () async {
            await f.database
                .into(f.database.davCollections)
                .insert(
                  DavCollectionsCompanion.insert(
                    id: 'collection',
                    accountId: 'qa',
                    hrefKey: Uri.parse(_target).path,
                    requestUri: _target,
                    displayName: 'Work',
                    ownerHref: const Value('/principals/alice/'),
                    createdAtUtc: 'now',
                    updatedAtUtc: 'now',
                  ),
                );
            f.remote = f.collectionXml.replaceFirst(
              '<d:href>/principals/alice/</d:href>',
              liveOwner.isEmpty ? '' : '<d:href>$liveOwner</d:href>',
            );
            await expectLater(
              f.admin.remove('collection'),
              throwsA(isA<DavException>()),
            );
            expect(f.targetReads, 1);
            expect(f.metadataWrites, 0);
          },
        );
      }

      for (final marker in [_id, 'unrelated-operation', null]) {
        test(
          'normalized creation recovery requires its operation marker: $marker',
          () async {
            f.loseResponse = true;
            f.normalizedResponse =
                '<d:resourcetype><d:collection/><c:calendar/></d:resourcetype>'
                '<d:displayname>WORK</d:displayname>'
                '<c:supported-calendar-component-set><c:comp name="VEVENT"/><c:comp name="VTODO"/></c:supported-calendar-component-set>'
                '${marker == null ? '' : '<b:operation-id xmlns:b="https://busystack.com/ns/busymax">$marker</b:operation-id>'}';
            if (marker == _id) {
              expect(
                await f.admin.create('Work', {component}),
                DavCollectionAdministrationOutcome.reconciled,
              );
              await f.reopen();
              expect(
                await f.admin.resumeCreation(_id),
                DavCollectionAdministrationOutcome.reconciled,
              );
            } else {
              await expectLater(
                f.admin.create('Work', {component}),
                throwsA(isA<DavException>()),
              );
              await f.reopen();
              await expectLater(
                f.admin.resumeCreation(_id),
                throwsA(isA<DavException>()),
              );
            }
            expect(f.writes, 1);
          },
        );
      }

      test('matching marker cannot adopt a calendar missing the requested component', () async {
        f.loseResponse = true;
        f.normalizedResponse =
            '<d:resourcetype><d:collection/><c:calendar/></d:resourcetype>'
            '<d:displayname>WORK</d:displayname>'
            '<c:supported-calendar-component-set><c:comp name="VJOURNAL"/></c:supported-calendar-component-set>'
            '<b:operation-id xmlns:b="https://busystack.com/ns/busymax">$_id</b:operation-id>';
        await expectLater(
          f.admin.create('Work', {component}),
          throwsA(isA<DavException>()),
        );
        expect(f.writes, 1);
      });

      for (final scenario in [
        'writable',
        'readonly-parent',
        'unverified',
        'wrong-principal',
        'outside-home',
        'cross-origin',
      ]) {
        test('secondary home administration: $scenario', () async {
          const secondary = 'https://example.test/secondary/';
          const principal = 'https://example.test/principals/alice/';
          final home = scenario == 'cross-origin'
              ? 'https://untrusted.test/home/'
              : secondary;
          final target = scenario == 'outside-home'
              ? 'https://example.test/elsewhere/work/'
              : '${home}work/';
          await f.database
              .update(f.database.davAccountServices)
              .write(
                DavAccountServicesCompanion(
                  principalHref: const Value(principal),
                  capabilitiesJson: Value(
                    jsonEncode({
                      'principalContexts': [
                        if (scenario != 'unverified' &&
                            scenario != 'cross-origin')
                          {
                            'principalHref': principal,
                            'calendarHomeHref': secondary,
                          },
                      ],
                    }),
                  ),
                ),
              );
          await f.database
              .into(f.database.davCollections)
              .insert(
                DavCollectionsCompanion.insert(
                  id: 'secondary',
                  ownerHref: const Value('/principals/alice/'),
                  accountId: 'qa',
                  hrefKey: Uri.parse(target).path,
                  requestUri: target,
                  displayName: 'Work',
                  safeDisplayMetadataJson: Value(
                    jsonEncode({
                      'calendarHomeHref': home,
                      'principalHref': scenario == 'wrong-principal'
                          ? 'https://example.test/principals/other/'
                          : principal,
                    }),
                  ),
                  createdAtUtc: 'now',
                  updatedAtUtc: 'now',
                ),
              );
          final requests = <http.Request>[];
          final client = MockClient((request) async {
            requests.add(request);
            if (request.method == 'DELETE') return http.Response('', 204);
            final props = request.method == 'PROPPATCH'
                ? '<d:displayname>Renamed</d:displayname>'
                : request.url.toString() == secondary
                ? '<d:resourcetype><d:collection/></d:resourcetype><d:current-user-privilege-set><d:privilege><d:${scenario == 'readonly-parent' ? 'read' : 'unbind'}/></d:privilege></d:current-user-privilege-set>'
                : f.collectionXml;
            return http.Response(
              '<d:multistatus xmlns:d="DAV:" xmlns:c="urn:ietf:params:xml:ns:caldav"><d:response><d:href>${request.url}</d:href><d:propstat><d:prop>$props</d:prop><d:status>HTTP/1.1 200 OK</d:status></d:propstat></d:response></d:multistatus>',
              207,
            );
          });
          addTearDown(client.close);
          final admin = DavCollectionAdministration(
            database: f.database,
            secrets: f.secrets,
            client: client,
            accountId: 'qa',
            refresh: () async {},
            requireNetwork: () async {},
          );
          if ([
            'unverified',
            'wrong-principal',
            'outside-home',
            'cross-origin',
          ].contains(scenario)) {
            await expectLater(
              admin.update('secondary', {
                const DavPropertyName('DAV:', 'displayname'): 'Renamed',
              }),
              throwsA(isA<DavException>()),
            );
            await expectLater(
              admin.remove('secondary'),
              throwsA(isA<DavException>()),
            );
            expect(requests, isEmpty);
            return;
          }
          expect(
            await admin.update('secondary', {
              const DavPropertyName('DAV:', 'displayname'): 'Renamed',
            }),
            DavCollectionAdministrationOutcome.committed,
          );
          if (scenario == 'readonly-parent') {
            await expectLater(
              admin.remove('secondary'),
              throwsA(isA<DavException>()),
            );
            expect(requests.where((r) => r.method == 'DELETE'), isEmpty);
          } else {
            expect(
              await admin.remove('secondary'),
              DavCollectionAdministrationOutcome.committed,
            );
            expect(
              requests.where((r) => r.method == 'DELETE').single.url.toString(),
              target,
            );
          }
          expect(requests.any((r) => r.url.toString() == secondary), isTrue);
          expect(requests.any((r) => r.url.toString() == _home), isFalse);
        });
      }

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

      for (final denial in ['bind', 'method', 'http403', 'http507']) {
        test(
          'definitive $denial rejection is durable and never retried',
          () async {
            f.bindDenied = denial == 'bind';
            f.unsupported = denial == 'method';
            f.rejectionStatus = switch (denial) {
              'http403' => 403,
              'http507' => 507,
              _ => null,
            };
            await expectLater(
              f.admin.create('Work', {component}),
              throwsA(isA<DavException>()),
            );
            final row = await f.database
                .select(f.database.davCollectionCreations)
                .getSingle();
            expect(row.state, 'rejected');
            expect(
              row.lastErrorStatus,
              denial == 'method'
                  ? 405
                  : denial == 'http507'
                  ? 507
                  : 403,
            );
            expect(
              row.lastErrorKind,
              denial == 'method'
                  ? 'protocol'
                  : denial == 'http507'
                  ? 'server'
                  : 'authorization',
            );
            expect(f.writes, denial.startsWith('http') ? 1 : 0);
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

      test(
        'calendar-access alone does not advertise a creation method',
        () async {
          f.calendarAccessOnly = true;
          await expectLater(
            f.admin.create('Work', {component}),
            throwsA(
              isA<DavException>().having(
                (e) => e.code,
                'code',
                'DavCollectionCreationUnsupported',
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

      for (final (status, condition, kind, code) in [
        (403, '', DavErrorKind.authorization, 'DavCollectionPropertyRejected'),
        (409, '', DavErrorKind.conflict, 'DavCollectionPropertyRejected'),
        (423, '', DavErrorKind.protocol, 'DavCollectionPropertyRejected'),
        (507, '', DavErrorKind.server, 'DavCollectionPropertyRejected'),
        (
          403,
          '<c:supported-calendar-component/>',
          DavErrorKind.unsupportedComponent,
          'DavUnsupportedComponent',
        ),
        (
          403,
          '<d:cannot-modify-protected-property/>',
          DavErrorKind.protocol,
          'DavCollectionPropertyUnsupported',
        ),
      ]) {
        for (final resumed in [false, true]) {
          test('MKCALENDAR 207 $status $condition is durably rejected; resumed=$resumed', () async {
            if (resumed) {
              await f.prepare();
              await (f.database.update(f.database.davCollectionCreations))
                  .write(
                    const DavCollectionCreationsCompanion(
                      state: Value('dispatched'),
                    ),
                  );
            }
            f.rejectionStatus = 207;
            f.rejectionBody =
                '<d:multistatus xmlns:d="DAV:" xmlns:c="urn:ietf:params:xml:ns:caldav">'
                '<d:response><d:href>$_target</d:href>'
                '<d:propstat><d:prop><d:displayname/></d:prop><d:status>HTTP/1.1 424 Failed Dependency</d:status></d:propstat>'
                '<d:propstat><d:prop><c:supported-calendar-component-set/></d:prop><d:status>HTTP/1.1 $status Property Failure</d:status>'
                '${condition.isEmpty ? '' : '<d:error>$condition</d:error>'}</d:propstat>'
                '</d:response></d:multistatus>';
            final failure = isA<DavException>()
                .having((e) => e.statusCode, 'property status', status)
                .having((e) => e.kind, 'property kind', kind)
                .having((e) => e.code, 'property reason', code);
            await expectLater(
              resumed
                  ? f.admin.resumeCreation(_id)
                  : f.admin.create('Work', {component}),
              throwsA(failure),
            );
            final row = await f.database
                .select(f.database.davCollectionCreations)
                .getSingle();
            expect(row.state, 'rejected');
            expect(row.lastErrorStatus, status);
            expect(row.lastErrorKind, kind.name);
            expect(row.lastErrorCode, code);
            expect(f.writes, 1);
            expect(f.targetReads, 1); // Only the preflight; no reconciliation.
            expect(f.remote, isNull);
            await f.reopen();
            await expectLater(f.admin.resumeCreation(_id), throwsA(failure));
            expect(f.writes, 1);
            expect(f.targetReads, 1);
          });
        }
      }

      for (final body in [
        '<broken',
        '<d:multistatus xmlns:d="DAV:"/>',
        '<d:multistatus xmlns:d="DAV:"><d:response><d:href>$_target</d:href><d:propstat><d:prop><d:displayname/></d:prop><d:status>HTTP/1.1 200 OK</d:status></d:propstat></d:response></d:multistatus>',
        '<d:multistatus xmlns:d="DAV:"><d:response><d:href>${_home}unrelated/</d:href><d:propstat><d:prop><d:displayname/></d:prop><d:status>HTTP/1.1 403 Forbidden</d:status></d:propstat></d:response></d:multistatus>',
      ]) {
        test(
          'unusable 207 response keeps an uncertain creation pending: $body',
          () async {
            f.rejectionStatus = 207;
            f.rejectionBody = body;
            await expectLater(
              f.admin.create('Work', {component}),
              throwsA(
                isA<DavException>().having(
                  (e) => e.kind,
                  'kind',
                  DavErrorKind.unknownOutcome,
                ),
              ),
            );
            expect(
              (await f.database
                      .select(f.database.davCollectionCreations)
                      .getSingle())
                  .state,
              'dispatched',
            );
            expect(f.writes, 1);
          },
        );
      }

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

      for (final status in [403, 507]) {
        test(
          'interrupted creation then HTTP $status is durably rejected',
          () async {
            f.interrupt = true;
            f.commitBeforeInterrupt = false;
            await expectLater(
              f.admin.create('Work', {component}),
              throwsA(isA<DavException>()),
            );
            await f.reopen();
            f.rejectionStatus = status;
            final failure = isA<DavException>()
                .having((e) => e.statusCode, 'status', status)
                .having((e) => e.code, 'code', 'DavCollectionCreationFailed');
            await expectLater(f.admin.resumeCreation(_id), throwsA(failure));
            final row = await f.database
                .select(f.database.davCollectionCreations)
                .getSingle();
            expect(row.state, 'rejected');
            expect(row.lastErrorStatus, status);
            expect(f.remote, isNull);
            expect(f.writes, 2);
            await f.reopen();
            await expectLater(f.admin.resumeCreation(_id), throwsA(failure));
            expect(f.writes, 2);
            final notices = DavCollectionCreationNotices(f.database);
            expect(await notices.acknowledge('qa', _id), isTrue);
            expect(await notices.load('qa'), isEmpty);
          },
        );
      }

      for (final extended in [false, true]) {
        for (final status in [null, 403, 507]) {
          test(
            'independent runtimes recover one dispatched creation with one mutation; MKCOL=$extended, rejection=$status',
            () async {
              await f.prepare();
              await f.database
                  .update(f.database.davCollectionCreations)
                  .write(
                    const DavCollectionCreationsCompanion(
                      state: Value('dispatched'),
                    ),
                  );
              f.extendedMkcol = extended;
              f.rejectionStatus = status;
              final results = await _recoverConcurrently(f);
              expect(f.writes, 1);
              expect(
                results,
                status == null
                    ? unorderedEquals(['committed', 'reconciled'])
                    : everyElement('DavCollectionCreationFailed:$status'),
              );
              final row = await f.database
                  .select(f.database.davCollectionCreations)
                  .getSingle();
              expect(row.state, status == null ? 'committed' : 'rejected');
            },
          );
        }
      }

      for (final status in [403, 507]) {
        for (final observation in ['matching', 'conflicting', 'unavailable']) {
          test(
            'recovered HTTP $status verifies the original outcome: $observation',
            () async {
              await f.prepare();
              await f.database
                  .update(f.database.davCollectionCreations)
                  .write(
                    const DavCollectionCreationsCompanion(
                      state: Value('dispatched'),
                    ),
                  );
              f.rejectionStatus = status;
              f.remoteAfterRejection = switch (observation) {
                'matching' => f.collectionXml,
                'conflicting' => f.collectionXml.replaceFirst(
                  'Work',
                  'Unrelated',
                ),
                _ => null,
              };
              f.reconciliationUnavailable = observation == 'unavailable';
              if (observation == 'matching') {
                expect(
                  await f.admin.resumeCreation(_id),
                  DavCollectionAdministrationOutcome.reconciled,
                );
              } else {
                await expectLater(
                  f.admin.resumeCreation(_id),
                  throwsA(
                    isA<DavException>().having(
                      (e) => e.code,
                      'code',
                      observation == 'conflicting'
                          ? 'DavCollectionNameConflict'
                          : 'DavCollectionOutcomeUnknown',
                    ),
                  ),
                );
              }
              final row = await f.database
                  .select(f.database.davCollectionCreations)
                  .getSingle();
              expect(row.state, switch (observation) {
                'matching' => 'committed',
                'conflicting' => 'rejected',
                _ => 'dispatched',
              });
              expect(f.writes, 1);
              if (observation == 'unavailable') {
                await f.reopen();
                await expectLater(
                  f.admin.resumeCreation(_id),
                  throwsA(
                    isA<DavException>().having(
                      (e) => e.statusCode,
                      'status',
                      status,
                    ),
                  ),
                );
                expect(
                  (await f.database
                          .select(f.database.davCollectionCreations)
                          .getSingle())
                      .state,
                  'rejected',
                );
              }
            },
          );
        }
      }

      test('recovered unsupported-component HTTP 403 preserves the typed rejection', () async {
        await f.prepare();
        await f.database
            .update(f.database.davCollectionCreations)
            .write(
              const DavCollectionCreationsCompanion(state: Value('dispatched')),
            );
        f.rejectionStatus = 403;
        f.rejectionBody = '<d:error xmlns:d="DAV:" xmlns:c="urn:ietf:params:xml:ns:caldav"><c:supported-calendar-component/></d:error>';
        await expectLater(
          f.admin.resumeCreation(_id),
          throwsA(
            isA<DavException>().having(
              (e) => e.kind,
              'kind',
              DavErrorKind.unsupportedComponent,
            ),
          ),
        );
        final row = await f.database
            .select(f.database.davCollectionCreations)
            .getSingle();
        expect(row.state, 'rejected');
        expect(row.lastErrorCode, 'DavUnsupportedComponent');
      });

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
                    ownerHref: const Value('/principals/alice/'),
                    accountId: 'qa',
                    hrefKey: Uri.parse(_target).path,
                    requestUri: _target,
                    displayName: 'Work',
                    createdAtUtc: 'now',
                    updatedAtUtc: 'now',
                    safeDisplayMetadataJson: const Value(
                      '{"parentPrivilegesKnown":"false","principalHref":"/principals/alice/"}',
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
  int metadataWrites = 0, refreshes = 0;
  String? deleteMode;
  bool refreshFails = false;
  bool optionsNetworkFailure = false, creationMethodsOnlyAtTarget = false;
  bool targetOptionsUnavailable = false;
  int targetOptionsStatus = 404;
  Map<String, String> targetOptionsHeaders = const {};
  bool parentPrivilegesUnknown = false;
  bool malformedParentPrivileges = false, nestedParentPrivileges = false;
  int writes = 0, interruptedProbes = 0, unavailableProbes = 0;
  int targetReads = 0;
  String? rejectionBody;
  String? remoteAfterRejection;
  bool calendarAccessOnly = false;
  int? rejectionStatus;
  int optionsStatus = 200;
  bool bindDenied = false, unsupported = false;
  bool parentDenied = false, parentDeniedPropertyLevel = false;
  bool loseResponse = false,
      interrupt = false,
      commitBeforeInterrupt = true,
      reconciliationUnavailable = false,
      extendedMkcol = false;
  bool preflightBeforeRetry = false;
  String? remote;
  String? normalizedResponse;
  bool rejectMarker = false, interruptAfterFallback = false;
  String markerFailureProperty = 'b:operation-id';
  String markerResponseStyle = 'method';
  String? markerRejectionRemote;
  bool markerReadUnavailable = false;
  final creationMarkers = <bool>[];
  String get collectionXml =>
      '<d:owner><d:href>/principals/alice/</d:href></d:owner><d:resourcetype><d:collection/><c:calendar/></d:resourcetype><d:displayname>Work</d:displayname><c:supported-calendar-component-set><c:comp name="$component"/></c:supported-calendar-component-set>';
  DavCollectionAdministration get admin => DavCollectionAdministration(
    database: database,
    secrets: secrets,
    client: client,
    accountId: 'qa',
    refresh: () async {
      refreshes++;
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
            principalHref: const Value('/principals/alice/'),
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
    if (parentDenied &&
        request.method == 'PROPFIND' &&
        request.url.toString() == _home) {
      final denied = parentDeniedPropertyLevel
          ? '<d:propstat><d:prop><d:resourcetype/></d:prop><d:status>HTTP/1.1 403 Forbidden</d:status></d:propstat>'
          : '<d:status>HTTP/1.1 403 Forbidden</d:status>';
      return http.Response(
        '<d:multistatus xmlns:d="DAV:"><d:response><d:href>$_home</d:href>$denied</d:response></d:multistatus>',
        207,
      );
    }

    if (request.method == 'PROPFIND' && request.url.toString() == _target) {
      targetReads++;
    }
    if (markerReadUnavailable &&
        writes == 1 &&
        request.method == 'PROPFIND' &&
        request.url.toString() == _target) {
      return http.Response('', 503, headers: {'retry-after': '0'});
    }
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
      if (deleteMode == 'partial') {
        return http.Response(
          '<d:multistatus xmlns:d="DAV:"><d:response><d:href>${_target}locked.ics</d:href><d:status>HTTP/1.1 423 Locked</d:status></d:response></d:multistatus>',
          207,
        );
      }
      if (deleteMode == 'malformed') {
        return http.Response('<d:multistatus', 207);
      }
      if (deleteMode == 'lost-survived') {
        throw StateError('Lost DELETE response before commit');
      }
      remote = null;
      if (deleteMode == 'lost-deleted') {
        throw StateError('Lost DELETE response after commit');
      }
      return http.Response('', 204);
    }
    if (request.method == 'OPTIONS') {
      if (targetOptionsUnavailable && request.url.toString() == _target) {
        return http.Response(
          '',
          targetOptionsStatus,
          headers: targetOptionsHeaders,
        );
      }
      if (optionsNetworkFailure) {
        throw http.ClientException('Simulated pre-dispatch connection loss');
      }
      return http.Response(
        '',
        optionsStatus,
        headers: creationMethodsOnlyAtTarget && request.url.toString() == _home
            ? {'dav': 'calendar-access', 'allow': 'GET, PROPFIND'}
            : optionsStatus == 503
            ? {'retry-after': '0'}
            : calendarAccessOnly
            ? {'dav': 'calendar-access', 'allow': 'GET, PROPFIND'}
            : unsupported
            ? {'dav': '1', 'allow': 'GET, PROPFIND'}
            : extendedMkcol
            ? {'dav': '1, calendar-access, extended-mkcol', 'allow': 'MKCOL'}
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
      final hasMarker = request.body.contains('<b:operation-id>');
      creationMarkers.add(hasMarker);
      if (rejectMarker && hasMarker) {
        remote = markerRejectionRemote;
        final props =
            '<d:propstat><d:prop><$markerFailureProperty/></d:prop><d:status>HTTP/1.1 403 Forbidden</d:status></d:propstat>'
            '<d:propstat><d:prop><d:displayname/></d:prop><d:status>HTTP/1.1 424 Failed Dependency</d:status></d:propstat>';
        final root = extendedMkcol
            ? 'd:mkcol-response'
            : 'c:mkcalendar-response';
        final body = markerResponseStyle == 'method'
            ? '<$root xmlns:d="DAV:" xmlns:c="urn:ietf:params:xml:ns:caldav" xmlns:b="https://busystack.com/ns/busymax">$props</$root>'
            : '<d:multistatus xmlns:d="DAV:" xmlns:b="https://busystack.com/ns/busymax"><d:response><d:href>$_target</d:href>$props</d:response></d:multistatus>';
        return http.Response(body, extendedMkcol ? 403 : 207);
      }
      if (rejectionStatus != null) {
        if (remoteAfterRejection != null) {
          remote = remoteAfterRejection;
        } else if (const {405, 409, 412}.contains(rejectionStatus)) {
          remote = collectionXml;
        }
        return http.Response(rejectionBody ?? '', rejectionStatus!);
      }
      if (interrupt && !commitBeforeInterrupt) {
        throw StateError('interrupted before remote commit');
      }
      if (!rejectMarker) expect(request.body, contains('<b:operation-id>'));
      if (interruptAfterFallback && !hasMarker) interrupt = true;
      remote = normalizedResponse ?? collectionXml;
      if (interrupt) throw StateError('interrupted after remote commit');
      if (loseResponse) throw http.ClientException('response lost');
      return http.Response('', 201);
    }
    if (request.url.toString() == _target && writes > 0) {
      preflightBeforeRetry = true;
    }
    final properties = request.url.toString() == _home
        ? '<d:resourcetype><d:collection/></d:resourcetype>${parentPrivilegesUnknown
              ? ''
              : malformedParentPrivileges
              ? '<d:current-user-privilege-set><d:privilege><d:all/><d:read/></d:privilege></d:current-user-privilege-set>'
              : nestedParentPrivileges
              ? '<d:current-user-privilege-set><d:unrelated><d:bind/></d:unrelated></d:current-user-privilege-set>'
              : '<d:current-user-privilege-set><d:privilege><d:${bindDenied ? 'read' : 'all'}/></d:privilege></d:current-user-privilege-set>'}'
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

// Separate isolates have independent static maps and SQLite connections, just
// like foreground/headless engines. The port host models the native exclusive
// gate and a shared server; reads and mutation responses are deliberately slow.
Future<List<String>> _recoverConcurrently(_Fixture fixture) async {
  final control = ReceivePort();
  final gate = AuthorizationGate();
  final starters = <SendPort>[];
  final heldBy = <int>{};
  final failures = <Object>[];
  final subscription = control.listen((message) async {
    final (payload, reply) = message as (List<Object?>, SendPort);
    try {
      switch (payload[0]) {
        case 'start':
          starters.add(reply);
          if (starters.length == 2) {
            for (final starter in starters) {
              starter.send(null);
            }
          }
        case 'gate':
          final runtime = payload[1] as int;
          await gate.run(payload[2] as String, () async {
            heldBy.add(runtime);
            final release = ReceivePort();
            reply.send(release.sendPort);
            final (_, released) =
                await release.first as (List<Object?>, SendPort);
            heldBy.remove(runtime);
            released.send(null);
            release.close();
          });
        case 'http':
          final request = http.Request(
            payload[1] as String,
            Uri.parse(payload[2] as String),
          )..body = payload[3] as String;
          request.headers.addAll((payload[4] as Map).cast<String, String>());
          // Capture the server's state before delaying the response. Without
          // the shared gate both runtimes can observe the same absence.
          final response = await fixture.handle(request);
          await Future<void>.delayed(const Duration(milliseconds: 50));
          reply.send((response.statusCode, response.body, response.headers));
        case 'refresh':
          expect(
            heldBy,
            isNot(contains(payload[1])),
            reason: 'Refresh must run after releasing the creation lease.',
          );
          reply.send(null);
      }
    } catch (error) {
      failures.add(error);
      reply.send(error.toString());
    }
  });
  final databasePath = '${fixture.directory.path}/qa.sqlite';
  final port = control.sendPort;
  try {
    final results = await Future.wait([
      for (var runtime = 0; runtime < 2; runtime++)
        _startRecoveryRuntime(databasePath, port, runtime),
    ]).timeout(const Duration(seconds: 15));
    expect(failures, isEmpty);
    return results;
  } finally {
    await subscription.cancel();
    control.close();
  }
}

// Keep the spawned closure separate from the fixture's unsendable SQLite FFI
// objects; Dart closures can retain their entire enclosing context.
Future<String> _startRecoveryRuntime(String path, SendPort port, int runtime) =>
    Isolate.run(() => _recoverInRuntime(path, port, runtime));

Future<String> _recoverInRuntime(
  String databasePath,
  SendPort control,
  int runtime,
) async {
  final database = AppDatabase(
    NativeDatabase(File(databasePath), setup: configureAndroidDatabase),
  );
  final secrets = InMemorySecretStore();
  await secrets.saveCredential(
    'qa',
    CalDavSecretRecord(
      serviceAuthority: Uri.parse('https://example.test/'),
      username: 'alice',
      password: 'test-password',
    ),
  );
  final client = MockClient((request) async {
    final (status, body, headers) = await _runtimeRequest(control, [
      'http',
      request.method,
      request.url.toString(),
      request.body,
      request.headers,
    ]) as (int, String, Map<String, String>);
    return http.Response(body, status, headers: headers);
  });
  try {
    // Force both independent runtimes to be ready before either starts work.
    await _runtimeRequest(control, ['start']);
    final result = await DavCollectionAdministration(
      database: database,
      secrets: secrets,
      client: client,
      accountId: 'qa',
      creationGate: _RuntimeGate(control, runtime),
      requireNetwork: () async {},
      refresh: () async {
        await _runtimeRequest(control, ['refresh', runtime]);
      },
    ).resumeCreation(_id);
    return result.name;
  } on DavException catch (error) {
    return '${error.code}:${error.statusCode}';
  } finally {
    client.close();
    await database.close();
  }
}

Future<Object?> _runtimeRequest(SendPort port, List<Object?> payload) async {
  final reply = ReceivePort();
  try {
    port.send((payload, reply.sendPort));
    return await reply.first;
  } finally {
    reply.close();
  }
}

final class _RuntimeGate implements CrossEngineAccountGate {
  _RuntimeGate(this.control, this.runtime);
  final SendPort control;
  final int runtime;

  @override
  Future<T> run<T>(String key, Future<T> Function() operation) async {
    final release =
        await _runtimeRequest(control, ['gate', runtime, key]) as SendPort;
    try {
      return await operation();
    } finally {
      await _runtimeRequest(release, []);
    }
  }
}

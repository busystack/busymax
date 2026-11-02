import 'package:busymax/src/dav/dav_errors.dart';
import 'package:busymax/src/dav/http/dav_http_transport.dart';
import 'package:busymax/src/dav/nextcloud/nextcloud_dav_context.dart';
import 'package:busymax/src/dav/nextcloud/nextcloud_collection_service.dart';
import 'package:busymax/src/dav/discovery/dav_discovery_models.dart';
import 'package:busymax/src/dav/nextcloud/nextcloud_trash_service.dart';
import 'package:busymax/src/dav/xml/dav_xml.dart';
import 'package:busymax/src/db/app_database.dart';
import 'package:busymax/src/features/calendar/data/calendar_repository.dart';
import 'package:drift/drift.dart' hide isNull;
import 'package:flutter_test/flutter_test.dart';

import 'nextcloud_admin_fixture.dart';

void main() {
  late NextcloudAdminFixture fixture;
  setUp(() async {
    fixture = NextcloudAdminFixture();
    await fixture.seed();
  });
  tearDown(() => fixture.close());
  test('an existing account refreshes its capability schema without losing collections', () async {
    await fixture.database
        .update(fixture.database.davAccountServices)
        .write(
          const DavAccountServicesCompanion(
            capabilitiesSchemaVersion: Value(2),
          ),
        );
    var refreshed = 0;
    final service = NextcloudCollectionService(
      database: fixture.database,
      secrets: fixture.secrets,
      client: fixture.client,
      accountId: 'account',
      requireNetwork: () async {},
      refresh: () async {
        refreshed++;
        await fixture.database
            .update(fixture.database.davAccountServices)
            .write(
              const DavAccountServicesCompanion(
                capabilitiesSchemaVersion: Value(davCapabilitiesSchemaVersion),
              ),
            );
      },
    );
    final before = await fixture.database
        .select(fixture.database.davCollections)
        .get();
    await service.openContext();
    expect(refreshed, 1);
    expect(
      (await fixture.database.select(fixture.database.davCollections).get())
          .map((c) => c.id),
      before.map((c) => c.id),
    );
    await fixture.database
        .update(fixture.database.davAccountServices)
        .write(
          const DavAccountServicesCompanion(
            capabilitiesSchemaVersion: Value(2),
          ),
        );
    fixture.failRefresh = true;
    await expectLater(fixture.collections.openContext(), throwsStateError);
    expect(
      (await fixture.database.select(fixture.database.davCollections).get())
          .map((c) => c.id),
      before.map((c) => c.id),
    );
  });
  test(
    'content-read-only metadata uses DAV properties and no local queue',
    () async {
      final state = await fixture.collections.load('collection');
      expect(state.collection.readOnly, isTrue);
      expect(state.canWriteMetadata, isTrue);
      expect(state.mixed, isTrue);
      final result = await fixture.collections.update('collection', {
        const DavPropertyName(appleIcalNamespace, 'calendar-color'): '#123456',
        const DavPropertyName(appleIcalNamespace, 'calendar-order'): '8',
      });
      expect(result, NextcloudMutationOutcome.committed);
      expect(
        fixture.requests.where((r) => r.method == 'PROPPATCH'),
        hasLength(1),
      );
      expect(
        await fixture.database.select(fixture.database.pendingOps).get(),
        isEmpty,
      );
      expect(
        (await fixture.database.select(fixture.database.davCollections).get())
            .first
            .displayName,
        'Work',
      );
    },
  );
  test(
    'HTTP 207 is not success when a requested property failed or is absent',
    () async {
      fixture.failedProperty = 'calendar-color';
      await expectLater(
        fixture.collections.update('collection', {
          const DavPropertyName(appleIcalNamespace, 'calendar-color'):
              '#123456',
        }),
        throwsA(isA<DavException>().having((e) => e.statusCode, 'status', 403)),
      );
      fixture.failedProperty = null;
      fixture.omitPropertyResults = true;
      await expectLater(
        fixture.collections.update('collection', {
          const DavPropertyName(appleIcalNamespace, 'calendar-color'):
              '#123456',
        }),
        throwsA(
          isA<DavException>().having(
            (e) => e.code,
            'code',
            'DavPropertyUpdateIncomplete',
          ),
        ),
      );
      expect(fixture.refreshes, 0);
    },
  );
  test(
    'incomplete 207 accepts a rename only after exact property readback',
    () async {
      fixture.omitPropertyResults = true;

      expect(
        await fixture.collections.update('collection', {
          const DavPropertyName(davNamespace, 'displayname'): 'Renamed',
        }),
        NextcloudMutationOutcome.committed,
      );

      expect(fixture.displayName, 'Renamed');
      expect(fixture.refreshes, 1);
      expect(
        fixture.requests.where((request) => request.method == 'PROPPATCH'),
        hasLength(1),
      );
      expect(
        fixture.requests.where((request) => request.method == 'PROPFIND'),
        isNotEmpty,
      );
    },
  );
  test('incomplete 207 still rejects an unapplied rename', () async {
    fixture.omitPropertyResults = true;
    fixture.applyPropertyChanges = false;

    await expectLater(
      fixture.collections.update('collection', {
        const DavPropertyName(davNamespace, 'displayname'): 'Renamed',
      }),
      throwsA(
        isA<DavException>().having(
          (error) => error.code,
          'code',
          'DavPropertyUpdateIncomplete',
        ),
      ),
    );

    expect(fixture.displayName, 'Work');
    expect(fixture.refreshes, 0);
  });
  test(
    'confirmed metadata write followed by refresh failure is not retried',
    () async {
      fixture.failRefresh = true;
      expect(
        await fixture.collections.update('collection', {
          const DavPropertyName(davNamespace, 'displayname'): 'Renamed',
        }),
        NextcloudMutationOutcome.refreshPending,
      );
      expect(
        fixture.requests.where((r) => r.method == 'PROPPATCH'),
        hasLength(1),
      );
      expect(fixture.displayName, 'Renamed');
    },
  );
  test(
    'parent permissions control deletion independently of content ACLs',
    () async {
      fixture.denyParent = true;
      await expectLater(
        fixture.collections.remove('collection'),
        throwsA(
          isA<DavException>().having(
            (e) => e.kind,
            'kind',
            DavErrorKind.authorization,
          ),
        ),
      );
      expect(fixture.requests.where((r) => r.method == 'DELETE'), isEmpty);
      fixture.denyParent = false;
      await fixture.collections.remove('collection');
      final deletion = fixture.requests.singleWhere(
        (r) => r.method == 'DELETE',
      );
      expect(deletion.headers.containsKey('x-nc-caldav-no-trashbin'), isFalse);
    },
  );
  test(
    'incoming and source moves block mixed calendar/task collection deletion',
    () async {
      for (final (id, entityType, state, source, destination) in [
        ('event-incoming', 'event', 'pending', 'bin', 'collection'),
        ('task-incoming', 'task', 'retry', 'bin', 'collection'),
        ('event-source', 'event', 'failed', 'collection', 'bin'),
        ('task-source', 'task', 'auth_blocked', 'collection', 'bin'),
        ('task-conflict', 'task', 'conflict', 'bin', 'collection'),
      ]) {
        await fixture.database
            .into(fixture.database.pendingOps)
            .insert(
              PendingOpsCompanion.insert(
                id: id,
                accountId: 'account',
                provider: const Value('nextcloud'),
                entityType: entityType,
                operation: 'move',
                operationType: Value('$entityType.move'),
                davCollectionId: Value(source),
                destinationCollectionId: Value(destination),
                requestJson: '{}',
                state: Value(state),
                createdAtUtc: '2026-09-05T12:00:00Z',
                updatedAtUtc: '2026-09-05T12:00:00Z',
              ),
            );
      }

      await expectLater(
        fixture.collections.remove('collection'),
        throwsA(
          isA<DavException>().having(
            (error) => error.code,
            'code',
            'DavCollectionHasPendingChanges',
          ),
        ),
      );
      expect(fixture.requests.where((r) => r.method == 'DELETE'), isEmpty);
    },
  );
  test(
    'unrelated work does not block and supported discard enables deletion',
    () async {
      await fixture.database
          .into(fixture.database.accounts)
          .insert(
            AccountsCompanion.insert(
              id: 'other-account',
              provider: 'nextcloud',
              authority: 'https://other.example.test',
              providerAccountId: 'other',
              credentialKind: 'nextcloud_app_password',
              createdAtUtc: '2026-09-05T12:00:00Z',
              updatedAtUtc: '2026-09-05T12:00:00Z',
            ),
          );
      for (final (id, account, source, destination) in [
        ('other-account-op', 'other-account', 'bin', 'collection'),
        ('other-collection-op', 'account', 'bin', 'bin'),
      ]) {
        await fixture.database
            .into(fixture.database.pendingOps)
            .insert(
              PendingOpsCompanion.insert(
                id: id,
                accountId: account,
                provider: const Value('nextcloud'),
                entityType: 'event',
                operation: 'move',
                operationType: const Value('event.move'),
                davCollectionId: Value(source),
                destinationCollectionId: Value(destination),
                requestJson: '{}',
                createdAtUtc: '2026-09-05T12:00:00Z',
                updatedAtUtc: '2026-09-05T12:00:00Z',
              ),
            );
      }
      await fixture.database
          .into(fixture.database.pendingOps)
          .insert(
            PendingOpsCompanion.insert(
              id: 'relevant',
              accountId: 'account',
              provider: const Value('nextcloud'),
              entityType: 'task',
              operation: 'move',
              operationType: const Value('task.move'),
              davCollectionId: const Value('bin'),
              destinationCollectionId: const Value('collection'),
              requestJson: '{}',
              createdAtUtc: '2026-09-05T12:00:00Z',
              updatedAtUtc: '2026-09-05T12:00:00Z',
            ),
          );

      await expectLater(
        fixture.collections.remove('collection'),
        throwsA(isA<DavException>()),
      );
      await fixture.database.pendingOpsDao.deleteOp('relevant');

      expect(
        await fixture.collections.remove('collection'),
        NextcloudMutationOutcome.committed,
      );
      expect(fixture.requests.where((r) => r.method == 'DELETE'), hasLength(1));
    },
  );
  test('calendar removal entry point cannot bypass an incoming move', () async {
    await fixture.database
        .into(fixture.database.calendarSources)
        .insert(
          CalendarSourcesCompanion.insert(
            id: 'calendar-source',
            accountId: 'account',
            provider: 'nextcloud',
            providerCalendarId: 'work',
            davCollectionId: const Value('collection'),
            summary: 'Work',
            createdAtLocal: 1,
            updatedAtLocal: 1,
          ),
        );
    await fixture.database
        .into(fixture.database.pendingOps)
        .insert(
          PendingOpsCompanion.insert(
            id: 'incoming-calendar-move',
            accountId: 'account',
            provider: const Value('nextcloud'),
            entityType: 'event',
            operation: 'move',
            operationType: const Value('event.move'),
            davCollectionId: const Value('bin'),
            destinationCollectionId: const Value('collection'),
            requestJson: '{}',
            createdAtUtc: '2026-09-05T12:00:00Z',
            updatedAtUtc: '2026-09-05T12:00:00Z',
          ),
        );
    final repository = CalendarRepository(
      database: fixture.database,
      nextcloudCollections: (_) => fixture.collections,
    );

    await expectLater(
      repository.deleteLocalSource('calendar-source'),
      throwsA(
        isA<DavException>().having(
          (error) => error.code,
          'code',
          'DavCollectionHasPendingChanges',
        ),
      ),
    );
    expect(fixture.requests.where((r) => r.method == 'DELETE'), isEmpty);
  });
  test(
    'user and group sharing uses resolved principals and ownCloud DAV XML',
    () async {
      final recipients = await fixture.sharing.search('Bo & Team');
      expect(recipients, hasLength(2));
      expect(recipients.last.group, isTrue);
      for (final recipient in recipients) {
        await fixture.sharing.changeShare(
          'collection',
          recipient,
          writable: true,
        );
      }
      expect((await fixture.sharing.load('collection')).shares, hasLength(2));
      await fixture.sharing.changeShare(
        'collection',
        recipients.first,
        writable: false,
      );
      await fixture.sharing.changeShare(
        'collection',
        recipients.last,
        writable: null,
      );
      expect(fixture.shares, {'principal:principals/users/bob': false});
      final requests = fixture.requests.where((r) => r.method == 'POST');
      expect(requests.every((r) => r.body.startsWith('<oc:share')), isTrue);
      expect(requests.last.body, contains('<oc:remove>'));
      expect(requests.every((r) => !r.url.path.contains('/ocs/')), isTrue);
    },
  );
  test('federated calendar share uses local DAV remote-user principal', () async {
    const cloudId = 'alice@remote.example.test';
    const principal =
        'principal:principals/remote-users/YWxpY2VAcmVtb3RlLmV4YW1wbGUudGVzdA==';
    final recipient = (await fixture.sharing.search(cloudId)).single;
    expect(recipient.federated, isTrue);
    expect(recipient.group, isFalse);
    expect(recipient.href, principal);
    await fixture.sharing.changeShare('collection', recipient, writable: true);
    expect(fixture.shares[recipient.href], isTrue);
    final post = fixture.requests.singleWhere((r) => r.method == 'POST');
    expect(post.url.host, 'cloud.example.test');
    expect(post.url.path, NextcloudAdminFixture.collection);
    expect(post.body, contains('<d:href>$principal</d:href>'));
    expect(post.body, isNot(contains('%3D')));
    expect(
      fixture.requests.every(
        (request) => request.url.host == 'cloud.example.test',
      ),
      isTrue,
    );
  });

  test(
    'committed federated grant remains committed when refresh fails',
    () async {
      final recipient = (await fixture.sharing.search(
        'alex@remote.example.test',
      )).single;
      fixture.failRefresh = true;
      expect(
        await fixture.sharing.changeShare(
          'collection',
          recipient,
          writable: false,
        ),
        NextcloudMutationOutcome.refreshPending,
      );
      expect(fixture.shares[recipient.href], isFalse);
      expect(
        fixture.requests.where((request) => request.method == 'POST'),
        hasLength(1),
      );
    },
  );

  test('invalid federated identifiers cannot create a share', () async {
    for (final value in [
      'alex@http://remote.example.test',
      'alex@https://user:pass@remote.example.test',
      'alex@remote.example.test?token=secret',
      'alex@remote.example.test/../other',
    ]) {
      await expectLater(fixture.sharing.search(value), throwsFormatException);
    }
    expect(fixture.requests.where((r) => r.method == 'POST'), isEmpty);
  });
  test('oversized objects without component metadata stay discoverable and conditional', () async {
    fixture.trashDescriptionBytes = 20 * 1024 * 1024;
    final listing = await fixture.trash.list(includeContent: true);
    expect(listing.items, hasLength(2));
    expect(
      listing.items.map((i) => i.kind),
      everyElement(NextcloudTrashKind.unknownObject),
    );
    await fixture.trash.restore(listing.items.first);
    await fixture.trash.permanentlyDelete(listing.items.last);
    expect(
      fixture.requests.where((r) => r.body.contains('<c:calendar-data')),
      isEmpty,
    );
    expect(
      fixture.requests
          .where((r) => r.method == 'MOVE')
          .single
          .headers['if-match'],
      '"exact-trash-etag"',
    );
    expect(
      fixture.requests
          .where((r) => r.method == 'DELETE')
          .single
          .headers['if-match'],
      '"exact-trash-etag"',
    );
  });

  test('weak ETags cannot authorize metadata-only trash mutations', () async {
    fixture.trashEtag = 'W/"weak-trash-etag"';
    final item = (await fixture.trash.list(includeContent: true)).items.first;
    await expectLater(
      fixture.trash.permanentlyDelete(item),
      throwsA(
        isA<DavException>().having(
          (e) => e.code,
          'code',
          'DavTrashItemChanged',
        ),
      ),
    );
    expect(
      fixture.requests.where((r) => r.method == 'MOVE' || r.method == 'DELETE'),
      isEmpty,
    );
  });

  test(
    'cancelled trash loading stops before subsequent detail requests',
    () async {
      final token = DavCancellationToken();
      fixture.beforeResponse = (request) async {
        if (request.method == 'REPORT' &&
            request.body.contains('calendar-query')) {
          token.cancel();
        }
      };
      await expectLater(
        fixture.trash.list(cancellationToken: token),
        throwsA(
          isA<DavException>().having(
            (e) => e.kind,
            'kind',
            DavErrorKind.cancelled,
          ),
        ),
      );
      expect(
        fixture.requests.where((r) => r.body.contains('calendar-multiget')),
        isEmpty,
      );
    },
  );

  test(
    'missing multiget identities fail visibly instead of hiding trash',
    () async {
      fixture.beforeResponse = (request) async {
        if (request.method == 'REPORT' &&
            request.body.contains('calendar-multiget')) {
          fixture.restored.add('${NextcloudAdminFixture.bin}objects/41.ics');
        }
      };
      await expectLater(
        fixture.trash.list(includeContent: true),
        throwsA(
          isA<DavException>().having(
            (e) => e.code,
            'code',
            'DavTrashReadIncomplete',
          ),
        ),
      );
    },
  );

  test(
    'publishing rereads the server-selected URL and unpublishing removes it',
    () async {
      await fixture.sharing.setPublished('collection', true);
      expect(
        (await fixture.sharing.load('collection')).publishUrl.toString(),
        'https://cloud.example.test/published/server-selected',
      );
      await fixture.sharing.setPublished('collection', false);
      expect((await fixture.sharing.load('collection')).publishUrl, isNull);
    },
  );
  test('default large trash listing returns all metadata without downloading bodies', () async {
    fixture.trashObjectCount = 300;
    fixture.trashDescriptionBytes = 128 * 1024;
    final listing = await fixture.trash.list();
    expect(listing.items, hasLength(300));
    expect(listing.items.map((i) => i.href).toSet(), hasLength(300));
    expect(listing.items.every((i) => !i.contentLoaded), isTrue);
    expect(
      fixture.requests.where(
        (r) => r.method == 'GET' || r.body.contains('calendar-data'),
      ),
      isEmpty,
    );
    fixture.requests.clear();
    final selected = listing.items[1];
    final detail = await fixture.trash.details(selected);
    expect(detail.title, 'Deleted task');
    expect(detail.kind, NextcloudTrashKind.task);
    expect(detail.uid, 'trash-1');
    expect(detail.contentLoaded, isTrue);
    expect(listing.items[1].contentLoaded, isFalse);
    final get = fixture.requests.where((r) => r.method == 'GET').single;
    expect(get.url, selected.href);
    expect(get.headers['if-match'], selected.etag);
    await fixture.trash.restore(detail);
    expect(fixture.requests.where((r) => r.method == 'GET'), hasLength(1));
  });

  test('on-demand details reject changed and withdrawn snapshots', () async {
    final listing = await fixture.trash.list();
    final item = listing.items.first;
    fixture.trashEtag = '"changed"';
    await expectLater(
      fixture.trash.details(item),
      throwsA(isA<DavException>()),
    );
    fixture.trashEtag = item.etag!;
    fixture.restored.add(item.href.path);
    await expectLater(
      fixture.trash.details(item),
      throwsA(isA<DavException>()),
    );
    expect(listing.items, hasLength(2));
    expect(
      fixture.requests.where((r) => r.method == 'DELETE' || r.method == 'MOVE'),
      isEmpty,
    );
  });

  test(
    'on-demand details reject stale authorization and support cancellation',
    () async {
      final listing = await fixture.trash.list();
      final token = DavCancellationToken()..cancel();
      await expectLater(
        fixture.trash.details(listing.items.first, cancellationToken: token),
        throwsA(isA<DavException>()),
      );
      await fixture.database
          .into(fixture.database.authorizationGenerations)
          .insert(
            AuthorizationGenerationsCompanion.insert(
              accountId: 'account',
              generation: 1,
            ),
          );
      fixture.requests.clear();
      await expectLater(
        fixture.trash.details(listing.items.first),
        throwsA(isA<DavException>()),
      );
      expect(fixture.requests, isEmpty);
    },
  );

  test('large trash returns every identity with size-budgeted detail batches', () async {
    fixture.trashObjectCount = 300;
    fixture.trashDescriptionBytes = 128 * 1024;
    final listing = await fixture.trash.list(includeContent: true);
    expect(listing.items, hasLength(300));
    expect(listing.items.map((i) => i.href).toSet(), hasLength(300));
    expect(
      listing.items.where((i) => i.kind == NextcloudTrashKind.task),
      hasLength(150),
    );
    final reports = fixture.requests
        .where((r) => r.method == 'REPORT')
        .toList();
    expect(
      reports
          .where((r) => r.body.contains('calendar-query'))
          .every((r) => !r.body.contains('calendar-data')),
      isTrue,
    );
    final detail = reports
        .where((r) => r.body.contains('calendar-multiget'))
        .toList();
    expect(detail.length, greaterThan(10));
    expect(
      detail.every((r) => RegExp('<d:href>').allMatches(r.body).length <= 32),
      isTrue,
    );
    expect(detail.every((r) => r.body.contains('<c:calendar-data/>')), isTrue);
    // The old shape crosses the unchanged 16 MiB safety limit for the same data.
    final context = await fixture.collections.openContext();
    await expectLater(
      context.send(
        'REPORT',
        Uri.parse(
          '${NextcloudAdminFixture.origin}${NextcloudAdminFixture.bin}objects',
        ),
        headers: {'depth': '1'},
        xml: '<c:calendar-query xmlns:c="urn:ietf:params:xml:ns:caldav" xmlns:d="DAV:"><d:prop><c:calendar-data/></d:prop><c:filter><c:comp-filter name="VCALENDAR"><c:comp-filter name="VEVENT"/></c:comp-filter></c:filter></c:calendar-query>',
      ),
      throwsA(isA<DavException>()),
    );
  });

  test('trash queries events and tasks and restores the returned VTODO href', () async {
    final listing = await fixture.trash.list(includeContent: true);
    expect(listing.items, hasLength(2));
    final task = listing.items.singleWhere(
      (i) => i.kind == NextcloudTrashKind.task,
    );
    expect(task.href.path, endsWith('/objects/42.ics'));
    fixture.requests.clear();
    await fixture.trash.restore(task);
    expect(
      fixture.requests.where((r) => r.body.contains('calendar-data')),
      isEmpty,
      reason: 'Confirmation revalidates identity and ACL without fetching calendar bodies.',
    );
    final move = fixture.requests.singleWhere((r) => r.method == 'MOVE');
    expect(move.url, task.href);
    expect(
      move.headers['destination'],
      '${NextcloudAdminFixture.origin}${NextcloudAdminFixture.bin}restore/file',
    );
    expect(move.headers['if-match'], '"exact-trash-etag"');
    expect(move.headers['overwrite'], 'F');
    expect(move.headers['x-nc-caldav-no-trashbin'], isNull);
    expect(
      (await fixture.trash.list(includeContent: true)).items,
      hasLength(1),
    );
    expect(
      await fixture.database.select(fixture.database.pendingOps).get(),
      isEmpty,
    );
    expect(
      await fixture.database.select(fixture.database.calendarEvents).get(),
      isEmpty,
    );
    expect(
      await fixture.database.select(fixture.database.tasks).get(),
      isEmpty,
    );
  });
  test(
    'expired trash entries cannot produce a second restore request',
    () async {
      final task = (await fixture.trash.list(includeContent: true)).items.last;
      await fixture.trash.restore(task);
      await expectLater(
        fixture.trash.restore(task),
        throwsA(
          isA<DavException>().having(
            (e) => e.code,
            'code',
            'DavTrashItemExpired',
          ),
        ),
      );
      expect(fixture.requests.where((r) => r.method == 'MOVE'), hasLength(1));
    },
  );
  test('restoration cannot replay an older pending deletion over the restored task', () async {
    final item = (await fixture.trash.list(includeContent: true)).items.last;
    await fixture.database
        .into(fixture.database.pendingOps)
        .insert(
          PendingOpsCompanion.insert(
            id: 'offline-delete',
            accountId: 'account',
            provider: const Value('nextcloud'),
            entityType: 'task',
            operation: 'delete',
            operationType: const Value('task.delete'),
            davCollectionId: const Value('collection'),
            requestJson: '{}',
            createdAtUtc: '2026-09-05T12:00:00Z',
            updatedAtUtc: '2026-09-05T12:00:00Z',
          ),
        );
    await expectLater(
      fixture.trash.restore(item),
      throwsA(
        isA<DavException>().having(
          (e) => e.code,
          'pending work retained',
          'DavTrashHasPendingChanges',
        ),
      ),
    );
    expect(fixture.requests.where((r) => r.method == 'MOVE'), isEmpty);
    expect(
      (await fixture.database.select(fixture.database.pendingOps).get())
          .single
          .id,
      'offline-delete',
    );
  });
  test(
    'trash rechecks object permissions independently from the bin owner',
    () async {
      final item = (await fixture.trash.list(includeContent: true)).items.first;
      fixture.denyTrashObject = true;
      final listing = await fixture.trash.list(includeContent: true);
      expect(listing.retentionSeconds, 2592000);
      expect(
        listing.items.every((i) => !i.canRestore && !i.canPermanentlyDelete),
        isTrue,
      );
      await expectLater(
        fixture.trash.restore(item),
        throwsA(isA<DavException>().having((e) => e.statusCode, 'status', 403)),
      );
      expect(fixture.requests.where((r) => r.method == 'MOVE'), isEmpty);
    },
  );
  test(
    'deleted calendars and task lists use fresh inventory and returned hrefs',
    () async {
      for (final (component, kind) in [
        ('VEVENT', NextcloudTrashKind.calendar),
        ('VTODO', NextcloudTrashKind.taskList),
      ]) {
        fixture.deletedCollectionType = component;
        fixture.restored.clear();
        final item = (await fixture.trash.list(includeContent: true)).items
            .singleWhere((i) => i.kind == kind);
        await fixture.trash.restore(item);
        expect(
          fixture.requests.lastWhere((r) => r.method == 'MOVE').url,
          item.href,
        );
        await expectLater(
          fixture.trash.permanentlyDelete(item),
          throwsA(
            isA<DavException>().having((e) => e.statusCode, 'status', 410),
          ),
        );
      }
      expect(fixture.requests.where((r) => r.method == 'DELETE'), isEmpty);
    },
  );
  test(
    'permanent trash deletion is separately requested and conditional',
    () async {
      final item = (await fixture.trash.list(includeContent: true)).items.first;
      await fixture.trash.permanentlyDelete(item);
      final deletion = fixture.requests.singleWhere(
        (r) => r.method == 'DELETE',
      );
      expect(deletion.headers['if-match'], item.etag);
      expect(deletion.headers['x-nc-caldav-no-trashbin'], '1');
    },
  );
  for (final permanent in [false, true]) {
    test(
      'authorization replacement during trash refresh invalidates ${permanent ? 'permanent deletion' : 'restore'}',
      () async {
        final item = (await fixture.trash.list(includeContent: true))
            .items
            .first;
        fixture.beforeResponse = (_) async {
          fixture.beforeResponse = null;
          await fixture.database
              .into(fixture.database.authorizationGenerations)
              .insert(
                AuthorizationGenerationsCompanion.insert(
                  accountId: 'account',
                  generation: 1,
                ),
              );
        };
        await expectLater(
          permanent
              ? fixture.trash.permanentlyDelete(item)
              : fixture.trash.restore(item),
          throwsA(
            isA<DavException>().having(
              (e) => e.code,
              'code',
              'DavTrashIdentityChanged',
            ),
          ),
        );
        expect(
          fixture.requests.where(
            (r) => r.method == 'MOVE' || r.method == 'DELETE',
          ),
          isEmpty,
        );
      },
    );
  }
  for (final permanent in [false, true]) {
    test(
      'interrupted trash ${permanent ? 'deletion' : 'restore'} stays uncertain without repetition',
      () async {
        final item = (await fixture.trash.list(includeContent: true))
            .items
            .first;
        fixture.loseTrashMutationResponse = true;
        await expectLater(
          permanent
              ? fixture.trash.permanentlyDelete(item)
              : fixture.trash.restore(item),
          throwsA(
            isA<DavException>().having(
              (e) => e.kind,
              'uncertain outcome',
              DavErrorKind.unknownOutcome,
            ),
          ),
        );
        expect(fixture.refreshes, 1);
        expect(
          (await fixture.trash.list(includeContent: true)).items
              .where((i) => i.href == item.href),
          isEmpty,
        );
        await expectLater(
          permanent
              ? fixture.trash.permanentlyDelete(item)
              : fixture.trash.restore(item),
          throwsA(
            isA<DavException>().having((e) => e.statusCode, 'fresh state', 410),
          ),
        );
        expect(
          fixture.requests.where(
            (r) => r.method == (permanent ? 'DELETE' : 'MOVE'),
          ),
          hasLength(1),
        );
      },
    );
  }
  test(
    'trash rejects an active-calendar href returned in a trash report',
    () async {
      fixture.unexpectedTrashHref = true;
      await expectLater(
        fixture.trash.list(includeContent: true),
        throwsA(
          isA<DavException>().having(
            (e) => e.code,
            'code',
            'DavTrashUnexpectedHref',
          ),
        ),
      );
    },
  );
  test(
    'sharing checks multistatus failures and confirms the requested grant',
    () async {
      final recipient = (await fixture.sharing.search('Bob')).first;
      fixture.denySharing = true;
      await expectLater(
        fixture.sharing.changeShare('collection', recipient, writable: true),
        throwsA(isA<DavException>().having((e) => e.statusCode, 'status', 403)),
      );
      fixture.denySharing = false;
      fixture.ignoreSharing = true;
      await expectLater(
        fixture.sharing.changeShare('collection', recipient, writable: true),
        throwsA(
          isA<DavException>().having(
            (e) => e.code,
            'code',
            'DavCollectionOutcomeUnknown',
          ),
        ),
      );
    },
  );
}

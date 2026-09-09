import 'package:busymax/src/dav/dav_errors.dart';
import 'package:busymax/src/dav/nextcloud/nextcloud_dav_context.dart';
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
  test(
    'trash queries events and tasks and restores the returned VTODO href',
    () async {
      final listing = await fixture.trash.list();
      expect(listing.items, hasLength(2));
      final task = listing.items.singleWhere(
        (i) => i.kind == NextcloudTrashKind.task,
      );
      expect(task.href.path, endsWith('/objects/42.ics'));
      await fixture.trash.restore(task);
      final move = fixture.requests.singleWhere((r) => r.method == 'MOVE');
      expect(move.url, task.href);
      expect(
        move.headers['destination'],
        '${NextcloudAdminFixture.origin}${NextcloudAdminFixture.bin}restore/file',
      );
      expect(move.headers['if-match'], '"exact-trash-etag"');
      expect(move.headers['overwrite'], 'F');
      expect(move.headers['x-nc-caldav-no-trashbin'], isNull);
      expect((await fixture.trash.list()).items, hasLength(1));
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
    },
  );
  test(
    'expired trash entries cannot produce a second restore request',
    () async {
      final task = (await fixture.trash.list()).items.last;
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
  test(
    'trash rechecks object permissions independently from the bin owner',
    () async {
      final item = (await fixture.trash.list()).items.first;
      fixture.denyTrashObject = true;
      final listing = await fixture.trash.list();
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
        final item = (await fixture.trash.list()).items.singleWhere(
          (i) => i.kind == kind,
        );
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
      final item = (await fixture.trash.list()).items.first;
      await fixture.trash.permanentlyDelete(item);
      final deletion = fixture.requests.singleWhere(
        (r) => r.method == 'DELETE',
      );
      expect(deletion.headers['if-match'], item.etag);
      expect(deletion.headers['x-nc-caldav-no-trashbin'], '1');
    },
  );
  test(
    'trash rejects an active-calendar href returned in a trash report',
    () async {
      fixture.unexpectedTrashHref = true;
      await expectLater(
        fixture.trash.list(),
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

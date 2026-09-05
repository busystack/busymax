import 'package:busymax/src/dav/dav_errors.dart';
import 'package:busymax/src/dav/nextcloud/nextcloud_dav_context.dart';
import 'package:busymax/src/dav/nextcloud/nextcloud_trash_service.dart';
import 'package:busymax/src/dav/xml/dav_xml.dart';
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
}

import 'package:busymax/src/dav/nextcloud/nextcloud_scheduling_service.dart';
import 'package:busymax/src/db/app_database.dart';
import 'package:drift/drift.dart' hide isNull;
import 'package:flutter_test/flutter_test.dart';

import 'nextcloud_scheduling_fixture.dart';
import 'nextcloud_admin_fixture.dart';

void main() {
  late SchedulingFixture fixture;
  late NextcloudSchedulingService service;
  setUp(() async {
    fixture = SchedulingFixture();
    await fixture.seedScheduling();
    service = NextcloudSchedulingService(fixture.collections);
  });
  tearDown(() => fixture.close());
  Future<List<NextcloudFreeBusyResult>> query() => service.freeBusy(
    collectionId: 'collection',
    startUtc: DateTime.utc(2026, 9, 6, 9),
    endUtc: DateTime.utc(2026, 9, 6, 12),
    recipients: ['guest@example.test', 'unknown@example.test'],
  );

  test('availability uses the discovered outbox and reports missing recipients as unknown', () async {
    final results = await query();
    expect(results.first.availability, NextcloudAvailability.known);
    expect(
      results.first.intervals.single.startUtc,
      DateTime.utc(2026, 9, 6, 10),
    );
    expect(results.last.availability, NextcloudAvailability.unknown);
    final post = fixture.requests.singleWhere((r) => r.method == 'POST');
    expect(post.url.path, '${NextcloudAdminFixture.home}outbox/');
    expect(post.body, contains('BEGIN:VFREEBUSY'));
    expect(post.body, contains('ORGANIZER:mailto:alex@example.test'));
    expect(post.body, isNot(contains('BEGIN:VEVENT')));
    expect(
      await fixture.database.select(fixture.database.pendingOps).get(),
      isEmpty,
    );
    expect(
      await fixture.database.select(fixture.database.calendarEvents).get(),
      isEmpty,
    );
  });
  test(
    'denied, duplicate and malformed recipient results are not free',
    () async {
      fixture.requestStatus = '3.8;No authority';
      expect((await query()).first.availability, NextcloudAvailability.unknown);
      fixture.requestStatus = '2.0;Success';
      fixture.duplicate = true;
      expect((await query()).first.availability, NextcloudAvailability.unknown);
      fixture.duplicate = false;
      fixture.busyData = 'not calendar data';
      expect((await query()).first.availability, NextcloudAvailability.unknown);
    },
  );
  test(
    'free/busy fails closed when sending privileges are unavailable',
    () async {
      await fixture.seedPolicy(privileges: const []);
      await expectLater(query(), throwsException);
      expect(fixture.requests, isEmpty);
    },
  );
  test(
    'a genuine free interval is known while a denied recipient remains unknown',
    () async {
      fixture.busyData = fixture.busyData.replaceFirst(
        'FREEBUSY;FBTYPE=BUSY:20260906T100000Z/20260906T110000Z\n',
        '',
      );
      fixture.additionalFreeBusyResponses = '<c:response><c:recipient><d:href>mailto:unknown@example.test</d:href></c:recipient><c:request-status>3.8;Denied</c:request-status></c:response>';
      final results = await query();
      expect(results.first.availability, NextcloudAvailability.known);
      expect(results.first.intervals, isEmpty);
      expect(results.last.availability, NextcloudAvailability.unknown);
      expect(results.last.status, '3.8;Denied');
      fixture.duplicateFreeBusyStatus = true;
      expect((await query()).first.availability, NextcloudAvailability.unknown);
      fixture.duplicateFreeBusyStatus = false;
      fixture.ambiguousFreeBusyRecipient = true;
      expect(
        (await query()).every(
          (r) => r.availability == NextcloudAvailability.unknown,
        ),
        isTrue,
      );
    },
  );
  test(
    'malformed busy periods and a disabled outbox never become free',
    () async {
      fixture.busyData = fixture.busyData.replaceFirst(
        '/20260906T110000Z',
        '/20260906T110000',
      );
      expect((await query()).first.availability, NextcloudAvailability.unknown);
      fixture.freeBusyHttpStatus = 403;
      await expectLater(query(), throwsException);
    },
  );
  test(
    'a readable inbox does not grant permission to acknowledge messages',
    () async {
      await fixture.seedPolicy(inboxPrivileges: const {'{DAV:}read'});
      final message = (await service.inbox('collection')).single;
      expect(message.canAcknowledge, isFalse);
      await expectLater(
        service.acknowledge('collection', message),
        throwsException,
      );
      expect(fixture.requests.where((r) => r.method == 'DELETE'), isEmpty);
    },
  );
  test('unknown inbox permissions allow server-validated reads but no acknowledgement', () async {
    await fixture.seedPolicy(
      inboxPrivileges: const {},
      inboxPrivilegesKnown: false,
    );
    final message = (await service.inbox('collection')).single;
    expect(message.canAcknowledge, isFalse);
    await expectLater(
      service.acknowledge('collection', message),
      throwsException,
    );
    expect(fixture.requests.where((r) => r.method == 'DELETE'), isEmpty);
    fixture.failInbox = true;
    await expectLater(service.inbox('collection'), throwsException);
  });

  test(
    'explicitly denied inbox read is rejected before network access',
    () async {
      await fixture.seedPolicy(
        inboxPrivileges: const {},
        inboxPrivilegesKnown: true,
      );
      await expectLater(service.inbox('collection'), throwsException);
      expect(fixture.requests, isEmpty);
    },
  );

  test('authorization replacement during inbox refresh invalidates acknowledgement', () async {
    final message = (await service.inbox('collection')).single;
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
      service.acknowledge('collection', message),
      throwsException,
    );
    expect(fixture.acknowledged, isFalse);
    expect(fixture.requests.where((r) => r.method == 'DELETE'), isEmpty);
  });
  test('inbox acknowledgement deletes only the returned inbox href with its exact ETag', () async {
    await fixture.database
        .into(fixture.database.calendarSources)
        .insert(
          CalendarSourcesCompanion.insert(
            id: 'source',
            accountId: 'account',
            provider: 'nextcloud',
            providerCalendarId: NextcloudAdminFixture.collection,
            davCollectionId: const Value('collection'),
            summary: 'Work',
            createdAtLocal: 1,
            updatedAtLocal: 1,
          ),
        );
    await fixture.database
        .into(fixture.database.calendarEvents)
        .insert(
          CalendarEventsCompanion.insert(
            id: 'event',
            accountId: 'account',
            provider: 'nextcloud',
            providerCalendarId: NextcloudAdminFixture.collection,
            calendarSourceId: 'source',
            providerEventId: 'same-uid',
            icalUid: const Value('same-uid'),
            title: 'Stored event',
            createdAtLocal: 1,
            updatedAtLocal: 1,
          ),
        );
    final before = await fixture.database
        .select(fixture.database.calendarEvents)
        .getSingle();
    final messages = await service.inbox('collection');
    expect(messages.single.method, 'REQUEST');
    await service.acknowledge('collection', messages.single);
    final deletion = fixture.requests.singleWhere((r) => r.method == 'DELETE');
    expect(
      deletion.url.path,
      '${NextcloudAdminFixture.home}inbox/server-message.ics',
    );
    expect(deletion.headers['if-match'], '"message-1"');
    expect(
      await fixture.database
          .select(fixture.database.calendarEvents)
          .getSingle(),
      before,
    );
    expect(
      await fixture.database.select(fixture.database.pendingOps).get(),
      isEmpty,
    );
    expect(await service.inbox('collection'), isEmpty);
  });
  test(
    'changed inbox message is not acknowledged after confirmation',
    () async {
      final message = (await service.inbox('collection')).single;
      fixture.messageEtag = '"message-2"';
      await expectLater(
        service.acknowledge('collection', message),
        throwsException,
      );
      expect(fixture.requests.where((r) => r.method == 'DELETE'), isEmpty);
    },
  );
}

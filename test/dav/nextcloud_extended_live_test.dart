import 'dart:io';
import 'dart:convert';

import 'package:busymax/src/dav/dav_errors.dart';

import 'package:busymax/src/features/calendar/presentation/event_editor_draft.dart';
import 'package:busymax/src/dav/nextcloud/nextcloud_scheduling_mutations.dart';
import 'package:busymax/src/dav/ical/ical_document.dart' show IcalComponentKey;

import 'package:drift/drift.dart'
    show BooleanExpressionOperators, driftRuntimeOptions;
import 'package:busymax/src/dav/nextcloud/nextcloud_dav_context.dart';
import 'package:busymax/src/dav/nextcloud/nextcloud_federation_service.dart';
import 'package:busymax/src/dav/storage/dav_collection_capabilities.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:busymax/src/dav/nextcloud/nextcloud_trash_service.dart';
import 'package:busymax/src/dav/nextcloud/nextcloud_scheduling_service.dart';
import 'package:busymax/src/dav/nextcloud/nextcloud_sharing_service.dart';
import 'package:busymax/src/dav/mutation/dav_pending_operations.dart';
import 'package:busymax/src/dav/mutation/dav_conditional_mutation_service.dart';
import 'package:busymax/src/dav/nextcloud/nextcloud_scheduling_policy.dart';
import 'package:busymax/src/dav/nextcloud/nextcloud_meeting_mutations.dart';
import 'package:busymax/src/dav/mutation/dav_mutation_patch.dart';
import 'package:busymax/src/dav/ical/ical_semantics.dart';

import 'support/nextcloud_extended_fixture.dart';

const _enabledVariable = 'BUSYMAX_NEXTCLOUD_EXTENDED_LIVE';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  final enabled = Platform.environment[_enabledVariable] == '1';
  test(
    'real federation delivers and revokes access on an independent HTTPS peer',
    () async {
      final f = await NextcloudExtendedFixture.open();
      addTearDown(f.close);
      final peer = await NextcloudExtendedFixture.open(
        prefix: 'BUSYMAX_NEXTCLOUD_FEDERATION_LIVE',
      );
      addTearDown(peer.close);
      final imported = await f.importEvent();
      final sharing = NextcloudSharingService(f.collections);
      final cloudId =
          Platform.environment['BUSYMAX_NEXTCLOUD_FEDERATION_LIVE_CLOUD_ID'];
      if (cloudId == null || cloudId.isEmpty) {
        throw StateError(
          'Supply the canonical peer Cloud ID from occ user:info; do not construct it from a hostname.',
        );
      }
      final recipient = (await sharing.search(cloudId)).single;
      expect(recipient.federated, isTrue);
      await sharing.changeShare(f.collection.id, recipient, writable: false);
      final ownerGrant = (await sharing.load(f.collection.id)).shares
          .singleWhere((s) => s.recipient.href == recipient.href);
      expect(ownerGrant.recipient.federated, isTrue);
      final incoming = NextcloudFederationService(peer.collections);
      final invitation = (await incoming.pending()).singleWhere(
        (i) => i.displayName == f.title,
      );
      expect(invitation.remoteUrl, startsWith(f.authority.origin));
      // invite-accepted in the owner's serialization is not remote acceptance.
      expect(
        (await peer.database.select(peer.database.davCollections).get()).where(
          (c) => c.displayName == f.title,
        ),
        isEmpty,
      );
      await incoming.accept(invitation);
      expect(
        (await incoming.pending()).where((i) => i.id == invitation.id),
        isEmpty,
      );
      await _syncFederationPeer();
      await peer.synchronize();
      var shared =
          await (peer.database.select(peer.database.davCollections)..where(
                (r) =>
                    r.displayName.equals(f.title) &
                    r.serverMissing.equals(false),
              ))
              .getSingle();
      expect(shared.readOnly, isTrue);
      var received = await peer.meetingObject(f.uid);
      expect(received.rawIcsBody, contains(f.uid));
      expect(
        (await NextcloudSchedulingPolicy.load(peer.database, shared)).federated,
        isTrue,
      );
      expect(
        (await NextcloudSchedulingPolicy.load(peer.database, shared)).canInvite,
        isFalse,
      );
      await sharing.changeShare(f.collection.id, recipient, writable: true);
      await _syncFederationPeer();
      await peer.synchronize();
      shared = await (peer.database.select(
        peer.database.davCollections,
      )..where((r) => r.id.equals(shared.id))).getSingle();
      expect(collectionCapabilitiesFromStored(shared).canUpdateEvent, isTrue);
      received = await peer.meetingObject(f.uid);
      await DavPendingOperationQueue(database: peer.database).enqueueUpdate(
        accountId: peer.id,
        collectionId: shared.id,
        objectId: received.id,
        patch: DavMutationPatch(
          target: IcalComponentKey(componentType: 'VEVENT', uid: f.uid),
          scope: DavMutationScope.object,
          operations: [
            DavPatchOperation.setText('SUMMARY', '${f.title} remote write'),
          ],
        ),
      );
      await peer.synchronize();
      await f.synchronize();
      expect(
        (await f.meetingObject(f.uid)).rawIcsBody,
        contains('${f.title} remote write'),
      );
      await sharing.changeShare(f.collection.id, recipient, writable: false);
      await _syncFederationPeer();
      await peer.synchronize();
      shared = await (peer.database.select(
        peer.database.davCollections,
      )..where((r) => r.id.equals(shared.id))).getSingle();
      expect(collectionCapabilitiesFromStored(shared).canUpdateEvent, isFalse);
      received = await peer.meetingObject(f.uid);
      final denied = await (await peer.collections.openContext()).send(
        'PUT',
        Uri.parse(received.requestUri),
        xml: received.rawIcsBody,
        headers: {'content-type': 'text/calendar', 'if-match': received.etag!},
      );
      expect(denied.statusCode, anyOf(401, 403));
      await sharing.changeShare(f.collection.id, recipient, writable: true);
      await _syncFederationPeer();
      await peer.synchronize();
      received = await peer.meetingObject(f.uid);
      await sharing.changeShare(f.collection.id, recipient, writable: null);
      expect(
        (await sharing.load(f.collection.id)).shares
            .where((s) => s.recipient.href == recipient.href),
        isEmpty,
      );
      // The recipient still has a cached writable copy. A new write must
      // contact the origin and fail, even before that cache converges.
      final revoked = await (await peer.collections.openContext()).send(
        'PUT',
        Uri.parse(received.requestUri),
        xml: received.rawIcsBody,
        headers: {'content-type': 'text/calendar', 'if-match': received.etag!},
      );
      // The current server can wrap the origin's 401 as a recipient-side 500.
      // Prove origin denial independently with the same federation identity;
      // a generic 500 alone would not establish revocation.
      expect(
        await _originFederationStatus(
          invitation.id,
          cloudId,
          Uri.parse(imported.requestUri).pathSegments.last,
        ),
        401,
      );
      expect(revoked.statusCode, anyOf(401, 403, 404, 500));
      await _syncFederationPeer();
      await peer.synchronize();
      expect(
        (await (await peer.collections.openContext()).send(
          'GET',
          Uri.parse(received.requestUri),
        )).statusCode,
        anyOf(403, 404, 410),
      );
      expect(
        (await peer.database.select(peer.database.davCollections).get()).where(
          (c) => c.id == shared.id && !c.serverMissing,
        ),
        isEmpty,
      );
      expect(
        (await (await f.collections.openContext()).send(
          'GET',
          Uri.parse(imported.requestUri),
        )).statusCode,
        200,
      );
    },
    skip:
        enabled &&
            Platform.environment['BUSYMAX_NEXTCLOUD_FEDERATION_LIVE'] == '1'
        ? false
        : 'Needs two disposable, mutually reachable HTTPS Nextcloud instances.',
    timeout: const Timeout(Duration(minutes: 5)),
  );
  test(
    'real native import queues and commits through account-scoped HTTPS',
    () async {
      final f = await NextcloudExtendedFixture.open();
      addTearDown(f.close);
      final object = await f.importEvent();
      final response = await (await f.collections.openContext()).send(
        'GET',
        Uri.parse(object.requestUri),
      );
      expect(response.statusCode, 200);
      expect(response.bodyText, contains(f.uid));
    },
    skip: enabled
        ? false
        : 'Set $_enabledVariable=1 with disposable HTTPS live-fixture credentials.',
    timeout: const Timeout(Duration(minutes: 3)),
  );
  test(
    'real trash discovers, restores, and permanently removes its own imported object',
    () async {
      final f = await NextcloudExtendedFixture.open();
      addTearDown(f.close);
      final object = await f.importEvent();
      final context = await f.collections.openContext();
      expect(
        (await context.send('DELETE', Uri.parse(object.requestUri))).statusCode,
        204,
      );
      final trash = NextcloudTrashService(f.collections);
      final removed = (await trash.list()).items.singleWhere(
        (i) => i.title == f.title,
      );
      expect(await trash.restore(removed), isNotNull);
      expect(
        (await context.send('GET', Uri.parse(object.requestUri))).statusCode,
        200,
      );
      expect(
        (await context.send('DELETE', Uri.parse(object.requestUri))).statusCode,
        204,
      );
      final deleted = (await trash.list()).items.singleWhere(
        (i) => i.title == f.title,
      );
      await trash.permanentlyDelete(deleted);
      expect(
        (await trash.list()).items.where((i) => i.title == f.title),
        isEmpty,
      );
    },
    skip: enabled
        ? false
        : 'Set $_enabledVariable=1 with disposable HTTPS live-fixture credentials.',
    timeout: const Timeout(Duration(minutes: 3)),
  );
  for (final components in [
    const ['VTODO'],
    const ['VEVENT'],
    const ['VEVENT', 'VTODO'],
  ]) {
    test(
      'real trash restores identities in deleted ${components.join('/')} collections',
      () async {
        final f = await NextcloudExtendedFixture.open(components: components);
        addTearDown(f.close);
        final todo = components.contains('VTODO');
        final organizer = (await NextcloudSchedulingPolicy.load(
          f.database,
          f.collection,
        )).organizerAddress;
        String eventRaw(String uid, String title) =>
            'BEGIN:VCALENDAR\r\nVERSION:2.0\r\nPRODID:-//BusyMax QA//EN\r\n'
            'BEGIN:VEVENT\r\nUID:$uid\r\nDTSTAMP:20261101T000000Z\r\nSUMMARY:$title\r\n'
            'DTSTART;VALUE=DATE:20261105\r\nDTEND;VALUE=DATE:20261106\r\nRRULE:FREQ=DAILY;COUNT=2\r\n'
            'ORGANIZER;SCHEDULE-AGENT=NONE:$organizer\r\n'
            'ATTENDEE;PARTSTAT=TENTATIVE;SCHEDULE-AGENT=NONE:mailto:trash-guest@busymax.invalid\r\n'
            'X-BUSYMAX-QA:preserve-original\r\nEND:VEVENT\r\n'
            'BEGIN:VEVENT\r\nUID:$uid\r\nDTSTAMP:20261101T000000Z\r\nSUMMARY:$title exception\r\n'
            'RECURRENCE-ID;VALUE=DATE:20261106\r\nDTSTART;VALUE=DATE:20261107\r\nDTEND;VALUE=DATE:20261108\r\n'
            'ORGANIZER;SCHEDULE-AGENT=NONE:$organizer\r\n'
            'ATTENDEE;PARTSTAT=TENTATIVE;SCHEDULE-AGENT=NONE:mailto:trash-guest@busymax.invalid\r\n'
            'X-BUSYMAX-EXCEPTION:preserve-this-occurrence\r\nEND:VEVENT\r\nEND:VCALENDAR\r\n';
        final raw = todo
            ? 'BEGIN:VCALENDAR\r\nVERSION:2.0\r\nPRODID:-//BusyMax QA//EN\r\n'
                  'BEGIN:VTODO\r\nUID:${f.uid}\r\nDTSTAMP:20261101T000000Z\r\nSUMMARY:${f.title}\r\n'
                  'DUE;VALUE=DATE:20261105\r\nSTATUS:COMPLETED\r\nPERCENT-COMPLETE:100\r\nCOMPLETED:20261101T010000Z\r\n'
                  'X-BUSYMAX-QA:preserve-original\r\nEND:VTODO\r\nEND:VCALENDAR\r\n'
            : eventRaw(f.uid, f.title);
        final original = await f.importRaw(raw);
        final context = await f.collections.openContext();
        final originalWire = (await context.send(
          'GET',
          Uri.parse(original.requestUri),
        )).bodyText;
        final secondary = components.length == 2
            ? await f.importRaw(
                eventRaw('${f.uid}-event', '${f.title} event'),
                objectUid: '${f.uid}-event',
              )
            : null;
        final secondaryWire = secondary == null
            ? null
            : (await context.send(
                'GET',
                Uri.parse(secondary.requestUri),
              )).bodyText;
        expect(
          (await context.send(
            'DELETE',
            Uri.parse(original.requestUri),
          )).statusCode,
          204,
        );
        await f.synchronize();
        final trash = NextcloudTrashService(f.collections);
        final item = (await trash.list()).items.singleWhere(
          (i) => i.title == f.title,
        );
        expect(
          item.kind,
          todo ? NextcloudTrashKind.task : NextcloudTrashKind.event,
        );
        expect(await trash.restore(item), NextcloudMutationOutcome.committed);
        final restored = await (f.database.select(
          f.database.davObjects,
        )..where((r) => r.id.equals(original.id))).getSingle();
        expect(restored.primaryUid, f.uid);
        expect(restored.serverDeleted, isFalse);
        expect(restored.rawIcsBody, contains('X-BUSYMAX-QA:preserve-original'));
        if (todo) expect(restored.rawIcsBody, contains('PERCENT-COMPLETE:100'));
        expect(
          (await context.send('GET', Uri.parse(original.requestUri))).bodyText,
          originalWire,
        );
        await f.collections.remove(f.collection.id);
        final removedCollection = (await trash.list()).items.singleWhere(
          (i) => i.title == f.title,
        );
        expect(
          removedCollection.kind,
          components.length == 2
              ? NextcloudTrashKind.mixedCollection
              : todo
              ? NextcloudTrashKind.taskList
              : NextcloudTrashKind.calendar,
        );
        expect(
          await trash.restore(removedCollection),
          NextcloudMutationOutcome.committed,
        );
        final response = await (await f.collections.openContext()).send(
          'GET',
          Uri.parse(original.requestUri),
        );
        expect(response.statusCode, 200);
        expect(response.bodyText, originalWire);
        if (secondary != null) {
          final event = await (await f.collections.openContext()).send(
            'GET',
            Uri.parse(secondary.requestUri),
          );
          expect(event.statusCode, 200);
          expect(event.bodyText, secondaryWire);
          expect(
            event.bodyText,
            contains('X-BUSYMAX-EXCEPTION:preserve-this-occurrence'),
          );
        }
        await f.collections.remove(f.collection.id);
        final permanentlyRemoved = (await trash.list()).items.singleWhere(
          (i) => i.title == f.title,
        );
        expect(
          await trash.permanentlyDelete(permanentlyRemoved),
          NextcloudMutationOutcome.committed,
        );
        expect(
          (await trash.list()).items.where((i) => i.title == f.title),
          isEmpty,
        );
      },
      skip: enabled
          ? false
          : 'Needs disposable HTTPS live-fixture credentials.',
      timeout: const Timeout(Duration(minutes: 3)),
    );
  }
  test(
    'shared task trash honors read-only, changed permissions and stale handles',
    () async {
      final owner = await NextcloudExtendedFixture.open(
        components: const ['VTODO'],
      );
      addTearDown(owner.close);
      final guest = await NextcloudExtendedFixture.open(
        components: const ['VTODO'],
        username:
            Platform
                .environment['BUSYMAX_NEXTCLOUD_EXTENDED_LIVE_ATTENDEE_USERNAME'] ??
            'attendee',
      );
      addTearDown(guest.close);
      final raw =
          'BEGIN:VCALENDAR\r\nVERSION:2.0\r\nPRODID:-//BusyMax QA//EN\r\nBEGIN:VTODO\r\n'
          'UID:${owner.uid}\r\nDTSTAMP:20261101T000000Z\r\nSUMMARY:${owner.title}\r\nSTATUS:COMPLETED\r\n'
          'PERCENT-COMPLETE:100\r\nEND:VTODO\r\nEND:VCALENDAR\r\n';
      final original = await owner.importRaw(raw);
      final sharing = NextcloudSharingService(owner.collections);
      final recipient = (await sharing.search(guest.secret.loginName))
          .singleWhere(
            (r) =>
                !r.group &&
                (r.href.endsWith('/${guest.secret.loginName}') ||
                    r.href.endsWith('/${guest.secret.loginName}/')),
          );
      await sharing.changeShare(
        owner.collection.id,
        recipient,
        writable: false,
      );
      await guest.synchronize();
      final received =
          (await guest.database.select(guest.database.davObjects).get())
              .singleWhere(
                (o) => o.primaryUid == owner.uid && !o.serverDeleted,
              );
      final denied = await (await guest.collections.openContext()).send(
        'DELETE',
        Uri.parse(received.requestUri),
      );
      expect(denied.statusCode, anyOf(403, 404));
      expect(
        (await (await owner.collections.openContext()).send(
          'GET',
          Uri.parse(original.requestUri),
        )).statusCode,
        200,
        reason: 'The denied recipient deletion must leave the original task intact.',
      );
      await sharing.changeShare(owner.collection.id, recipient, writable: true);
      final context = await owner.collections.openContext();
      expect(
        (await context.send(
          'DELETE',
          Uri.parse(original.requestUri),
        )).statusCode,
        204,
      );
      final trash = NextcloudTrashService(guest.collections);
      var item = (await trash.list()).items.singleWhere(
        (i) => i.uid == owner.uid,
      );
      expect(item.canRestore, isTrue);
      await sharing.changeShare(
        owner.collection.id,
        recipient,
        writable: false,
      );
      await expectLater(
        trash.restore(item),
        throwsA(
          isA<DavException>().having(
            (e) => e.kind,
            'fresh permission',
            DavErrorKind.authorization,
          ),
        ),
      );
      await sharing.changeShare(owner.collection.id, recipient, writable: true);
      item = (await trash.list()).items.singleWhere((i) => i.uid == owner.uid);
      await trash.restore(item);
      await owner.synchronize();
      expect(
        (await owner.database.select(owner.database.davObjects).get())
            .singleWhere((o) => o.primaryUid == owner.uid && !o.serverDeleted)
            .id,
        original.id,
      );
      expect(
        (await context.send('GET', Uri.parse(original.requestUri))).bodyText,
        contains('PERCENT-COMPLETE:100'),
      );
      expect(
        (await context.send(
          'DELETE',
          Uri.parse(original.requestUri),
        )).statusCode,
        204,
      );
      final stale = (await trash.list()).items.singleWhere(
        (i) => i.uid == owner.uid,
      );
      final ownerTrash = NextcloudTrashService(owner.collections);
      await ownerTrash.restore(
        (await ownerTrash.list()).items.singleWhere((i) => i.uid == owner.uid),
      );
      await expectLater(
        trash.permanentlyDelete(stale),
        throwsA(
          isA<DavException>().having(
            (e) => e.statusCode,
            'already restored',
            410,
          ),
        ),
      );
      expect(
        (await context.send('GET', Uri.parse(original.requestUri))).statusCode,
        200,
      );
      await sharing.changeShare(owner.collection.id, recipient, writable: null);
    },
    skip: enabled ? false : 'Needs disposable HTTPS sharing accounts.',
    timeout: const Timeout(Duration(minutes: 5)),
  );
  for (final variant in ['timed', 'recurring-zone', 'all-day']) {
    test(
      'automatic scheduling delivers, replies, updates and cancels $variant meetings',
      () async {
        final owner = await NextcloudExtendedFixture.open();
        addTearDown(owner.close);
        final attendee = await NextcloudExtendedFixture.open(
          username:
              Platform
                  .environment['BUSYMAX_NEXTCLOUD_EXTENDED_LIVE_ATTENDEE_USERNAME'] ??
              'attendee',
        );
        addTearDown(attendee.close);
        final ownerPolicy = await NextcloudSchedulingPolicy.load(
          owner.database,
          owner.collection,
        );
        final attendeePolicy = await NextcloudSchedulingPolicy.load(
          attendee.database,
          attendee.collection,
        );
        final organizerAddress = ownerPolicy.organizerAddress!;
        final attendeeAddress = attendeePolicy.organizerAddress!;
        final time = switch (variant) {
          'all-day' =>
            'DTSTART;VALUE=DATE:20261105\r\nDTEND;VALUE=DATE:20261106',
          'recurring-zone' => 'DTSTART;TZID=America/Vancouver:20261105T100000\r\nDTEND;TZID=America/Vancouver:20261105T110000\r\nRRULE:FREQ=DAILY;COUNT=3',
          _ => 'DTSTART:20261105T180000Z\r\nDTEND:20261105T190000Z',
        };
        final raw =
            'BEGIN:VCALENDAR\r\nVERSION:2.0\r\nPRODID:-//BusyMax QA//EN\r\nBEGIN:VEVENT\r\n'
            'UID:${owner.uid}\r\nDTSTAMP:20261101T000000Z\r\nSEQUENCE:0\r\n$time\r\nSUMMARY:${owner.title}\r\n'
            'ORGANIZER:$organizerAddress\r\nATTENDEE;PARTSTAT=NEEDS-ACTION;RSVP=TRUE:$attendeeAddress\r\n'
            'X-BUSYMAX-QA:preserve-meeting\r\nEND:VEVENT\r\nEND:VCALENDAR\r\n';
        await DavPendingOperationQueue(database: owner.database).enqueueCreate(
          accountId: owner.id,
          collectionId: owner.collection.id,
          object: DavNewObject(
            uid: owner.uid,
            initialMemberName: '${owner.id}.ics',
            rawIcs: raw,
            componentType: 'VEVENT',
          ),
        );
        // No network is needed to queue. Only synchronization performs implicit
        // scheduling; BusyMax never sends a second invitation through an outbox.
        expect(
          await owner.database.select(owner.database.pendingOps).get(),
          hasLength(1),
        );
        await owner.synchronize();
        await attendee.synchronize();
        var received = await attendee.meetingObject(owner.uid);
        expect(received.rawIcsBody, contains('X-BUSYMAX-QA:preserve-meeting'));
        final inbox = NextcloudSchedulingService(attendee.collections);
        final messages = await inbox.inbox(attendee.collection.id);
        final invitation = messages
            .where((m) => m.rawIcs.contains(owner.uid))
            .firstOrNull;
        expect(
          invitation,
          isNotNull,
          reason: 'An actual scheduling REQUEST must arrive in the recipient inbox.',
        );
        await inbox.acknowledge(attendee.collection.id, invitation!);
        expect(
          (await inbox.inbox(attendee.collection.id))
              .where((m) => m.href == invitation.href),
          isEmpty,
        );
        expect(
          (await (await attendee.collections.openContext()).send(
            'GET',
            Uri.parse(received.requestUri),
          )).statusCode,
          200,
        );
        for (final status in ['ACCEPTED', 'TENTATIVE', 'DECLINED']) {
          received = await attendee.meetingObject(owner.uid);
          final collection = await (attendee.database.select(
            attendee.database.davCollections,
          )..where((r) => r.id.equals(received.collectionId))).getSingle();
          final policy = await NextcloudSchedulingPolicy.load(
            attendee.database,
            collection,
          );
          final patch = buildNextcloudResponsePatch(
            baselineRawIcs: received.rawIcsBody,
            uid: owner.uid,
            policy: policy,
            participationStatus: status,
            nowUtc: DateTime.now().toUtc(),
            entireSeries: true,
          );
          await DavPendingOperationQueue(database: attendee.database)
              .enqueueUpdate(
                accountId: attendee.id,
                collectionId: received.collectionId,
                objectId: received.id,
                patch: patch,
              );
          await attendee.synchronize();
          await owner.synchronize();
          final updated = IcalSemanticDocument.parse(
            (await owner.meetingObject(owner.uid)).rawIcsBody,
          );
          final guest = updated.components.first.documentComponent
              .propertiesNamed('ATTENDEE')
              .singleWhere(
                (p) => normalizeCalendarAddress(p.rawValue) == attendeeAddress,
              );
          expect(guest.parameterValue('PARTSTAT'), status);
          expect(
            updated.components.first.documentComponent
                .firstProperty('ORGANIZER')!
                .rawValue,
            organizerAddress,
          );
        }
        if (variant == 'recurring-zone') {
          received = await attendee.meetingObject(owner.uid);
          final calendar = await (attendee.database.select(
            attendee.database.davCollections,
          )..where((r) => r.id.equals(received.collectionId))).getSingle();
          final response = buildNextcloudResponsePatch(
            baselineRawIcs: received.rawIcsBody,
            uid: owner.uid,
            policy: await NextcloudSchedulingPolicy.load(
              attendee.database,
              calendar,
            ),
            participationStatus: 'TENTATIVE',
            nowUtc: DateTime.now().toUtc(),
            occurrenceKey: 'TZID=America/Vancouver:20261106T100000',
          );
          await DavPendingOperationQueue(database: attendee.database)
              .enqueueUpdate(
                accountId: attendee.id,
                collectionId: received.collectionId,
                objectId: received.id,
                patch: response,
              );
          await attendee.synchronize();
          await owner.synchronize();
          final reflected = IcalSemanticDocument.parse(
            (await owner.meetingObject(owner.uid)).rawIcsBody,
          );
          final exception = reflected.components.singleWhere(
            (c) => c.recurrenceId != null,
          );
          expect(
            exception.documentComponent
                .propertiesNamed('ATTENDEE')
                .single
                .parameterValue('PARTSTAT'),
            'TENTATIVE',
          );
          expect(
            reflected.components
                .singleWhere((c) => c.recurrenceId == null)
                .documentComponent
                .propertiesNamed('ATTENDEE')
                .single
                .parameterValue('PARTSTAT'),
            'DECLINED',
          );
          expect(
            exception.documentComponent.firstProperty('X-BUSYMAX-QA')!.rawValue,
            'preserve-meeting',
          );
        }
        var organized = await owner.meetingObject(owner.uid);
        final external = 'capture-${owner.id}@busymax.invalid';
        final guests = [
          EventAttendeeDraft(
            email: attendeeAddress.substring('mailto:'.length),
          ),
          EventAttendeeDraft(email: external),
        ];
        final update = DavMutationPatch(
          target: IcalComponentKey(componentType: 'VEVENT', uid: owner.uid),
          scope: DavMutationScope.recurrenceMaster,
          operations: [
            DavPatchOperation.setText('SUMMARY', '${owner.title} updated'),
            DavPatchOperation.replaceRepeatedRaw(
              'ATTENDEE',
              nextcloudAttendeeValues(
                guests,
                IcalSemanticDocument.parse(organized.rawIcsBody).components
                    .firstWhere((c) => c.recurrenceId == null)
                    .documentComponent,
              ),
            ),
            DavPatchOperation.setRaw('SEQUENCE', '1'),
            DavPatchOperation.setRaw('DTSTAMP', '20261101T010000Z'),
            if (variant == 'timed') ...[
              DavPatchOperation.setRaw('DTSTART', '20261105T200000Z'),
              DavPatchOperation.setRaw('DTEND', '20261105T210000Z'),
            ],
          ],
        );
        await DavPendingOperationQueue(database: owner.database).enqueueUpdate(
          accountId: owner.id,
          collectionId: organized.collectionId,
          objectId: organized.id,
          patch: nextcloudSeriesGuestPatch(
            initial: update,
            baselineRawIcs: organized.rawIcsBody,
            attendees: guests,
            nowUtc: DateTime.now().toUtc(),
            entireSeries: true,
          ),
        );
        await owner.synchronize();
        await attendee.synchronize();
        received = await attendee.meetingObject(owner.uid);
        expect(received.rawIcsBody, contains('${owner.title} updated'));
        if (variant == 'timed') {
          expect(received.rawIcsBody, contains('20261105T200000Z'));
        }
        expect(
          IcalSemanticDocument.parse(received.rawIcsBody).components
              .firstWhere((c) => c.recurrenceId == null)
              .documentComponent
              .propertiesNamed('ATTENDEE')
              .map((p) => normalizeCalendarAddress(p.rawValue)),
          contains('mailto:$external'),
        );
        organized = await owner.meetingObject(owner.uid);
        final remaining = [
          EventAttendeeDraft(
            email: attendeeAddress.substring('mailto:'.length),
          ),
        ];
        final removeGuest = DavMutationPatch(
          target: IcalComponentKey(componentType: 'VEVENT', uid: owner.uid),
          scope: DavMutationScope.recurrenceMaster,
          operations: [
            DavPatchOperation.replaceRepeatedRaw(
              'ATTENDEE',
              nextcloudAttendeeValues(
                remaining,
                IcalSemanticDocument.parse(organized.rawIcsBody).components
                    .firstWhere((c) => c.recurrenceId == null)
                    .documentComponent,
              ),
            ),
            DavPatchOperation.setRaw('SEQUENCE', '2'),
          ],
        );
        await DavPendingOperationQueue(database: owner.database).enqueueUpdate(
          accountId: owner.id,
          collectionId: organized.collectionId,
          objectId: organized.id,
          patch: nextcloudSeriesGuestPatch(
            initial: removeGuest,
            baselineRawIcs: organized.rawIcsBody,
            attendees: remaining,
            nowUtc: DateTime.now().toUtc(),
            entireSeries: true,
          ),
        );
        await owner.synchronize();
        await attendee.synchronize();
        received = await attendee.meetingObject(owner.uid);
        expect(received.rawIcsBody, isNot(contains(external)));
        organized = await owner.meetingObject(owner.uid);
        await DavPendingOperationQueue(database: owner.database).enqueueDelete(
          accountId: owner.id,
          collectionId: organized.collectionId,
          objectId: organized.id,
          target: IcalComponentKey(componentType: 'VEVENT', uid: owner.uid),
        );
        await owner.synchronize();
        await attendee.synchronize();
        final afterCancellation =
            await (await attendee.collections.openContext()).send(
              'GET',
              Uri.parse(received.requestUri),
            );
        expect(
          afterCancellation.statusCode == 404 ||
              (afterCancellation.statusCode == 200 &&
                  afterCancellation.bodyText.contains('STATUS:CANCELLED')),
          isTrue,
          reason: 'Cancellation must affect the recipient calendar, not just the organizer HTTP response.',
        );
        final mail = await _capturedSchedulingMail(owner.uid, external);
        expect(
          mail['REQUEST'],
          1,
          reason: 'One automatic invitation must reach local mail capture.',
        );
      },
      skip: enabled
          ? false
          : 'Needs two disposable scheduling accounts on HTTPS Nextcloud.',
      timeout: const Timeout(Duration(minutes: 5)),
    );
  }
  test(
    'external attendee removal delivers cancellation mail',
    () async {
      final owner = await NextcloudExtendedFixture.open();
      addTearDown(owner.close);
      final policy = await NextcloudSchedulingPolicy.load(
        owner.database,
        owner.collection,
      );
      final external = 'capture-${owner.id}@busymax.invalid';
      final raw =
          'BEGIN:VCALENDAR\r\nVERSION:2.0\r\nPRODID:-//BusyMax QA//EN\r\nBEGIN:VEVENT\r\n'
          'UID:${owner.uid}\r\nDTSTAMP:20261101T000000Z\r\nSEQUENCE:0\r\nSUMMARY:${owner.title}\r\n'
          'DTSTART:20261120T120000Z\r\nDTEND:20261120T130000Z\r\nORGANIZER:${policy.organizerAddress}\r\n'
          'ATTENDEE;PARTSTAT=NEEDS-ACTION:mailto:$external\r\nEND:VEVENT\r\nEND:VCALENDAR\r\n';
      final queue = DavPendingOperationQueue(database: owner.database);
      await queue.enqueueCreate(
        accountId: owner.id,
        collectionId: owner.collection.id,
        object: DavNewObject(
          uid: owner.uid,
          initialMemberName: '${owner.id}.ics',
          rawIcs: raw,
          componentType: 'VEVENT',
        ),
      );
      await owner.synchronize();
      final meeting = await owner.meetingObject(owner.uid);
      await queue.enqueueUpdate(
        accountId: owner.id,
        collectionId: meeting.collectionId,
        objectId: meeting.id,
        patch: DavMutationPatch(
          target: IcalComponentKey(componentType: 'VEVENT', uid: owner.uid),
          scope: DavMutationScope.object,
          operations: [
            DavPatchOperation.replaceRepeatedRaw('ATTENDEE', []),
            DavPatchOperation.setRaw('SEQUENCE', '1'),
          ],
        ),
      );
      await owner.synchronize();
      final mail = await _capturedSchedulingMail(owner.uid, external);
      expect(
        mail['REQUEST'],
        1,
        reason: 'SMTP and external invitations must work before diagnosing cancellation.',
      );
      // Compare raw conditional CalDAV writes, without the queue or patcher,
      // before attributing a delivery failure to server scheduling.
      final directUid = 'direct-${owner.uid}';
      final directAddress = 'direct-$external';
      final directUri = owner.created.resolve('direct-${owner.id}.ics');
      final context = await owner.collections.openContext();
      final directRaw = raw
          .replaceAll(owner.uid, directUid)
          .replaceAll(external, directAddress);
      expect(
        (await context.send(
          'PUT',
          directUri,
          xml: directRaw,
          headers: {'content-type': 'text/calendar', 'if-none-match': '*'},
        )).statusCode,
        201,
      );
      final before = await context.send('GET', directUri);
      expect(before.statusCode, 200);
      final unfolded = before.bodyText.replaceAll(RegExp(r'\r?\n[ \t]'), '');
      final removed = unfolded
          .split(RegExp(r'\r?\n'))
          .where((line) => !line.startsWith('ATTENDEE'))
          .join('\r\n')
          .replaceAll(RegExp(r'SEQUENCE:[0-9]+'), 'SEQUENCE:1');
      expect(
        (await context.send(
          'PUT',
          directUri,
          xml: removed,
          headers: {
            'content-type': 'text/calendar',
            'if-match': before.headers['etag']!,
            if (before.headers['schedule-tag'] case final tag?)
              'if-schedule-tag-match': tag,
          },
        )).statusCode,
        204,
      );
      final directMail = await _capturedSchedulingMail(
        directUid,
        directAddress,
      );
      expect(
        directMail['REQUEST'],
        1,
        reason: 'The minimal direct invitation must reach SMTP capture.',
      );
      expect(
        directMail['CANCEL'],
        mail['CANCEL'],
        reason: 'Compare actual delivery, not matching HTTP status codes.',
      );
      expect(
        mail['CANCEL'],
        1,
        reason: 'Both BusyMax and the minimal direct request require a server-generated cancellation.',
      );
    },
    skip: enabled
        ? false
        : 'Needs disposable HTTPS accounts and local mail capture.',
    timeout: const Timeout(Duration(minutes: 3)),
  );
  test(
    'administratively disabled free-busy stays unknown',
    () async {
      final f = await NextcloudExtendedFixture.open();
      addTearDown(f.close);
      final policy = await NextcloudSchedulingPolicy.load(
        f.database,
        f.collection,
      );
      try {
        final result = await NextcloudSchedulingService(f.collections).freeBusy(
          collectionId: f.collection.id,
          startUtc: DateTime.utc(2026, 11, 20, 12),
          endUtc: DateTime.utc(2026, 11, 20, 13),
          recipients: [policy.organizerAddress!],
        );
        expect(
          result.every((r) => r.availability == NextcloudAvailability.unknown),
          isTrue,
        );
      } on DavException catch (error) {
        expect(error.kind, DavErrorKind.authorization);
        expect(
          error.code == 'DavFreeBusyDenied' || error.statusCode == 403,
          isTrue,
        );
      }
    },
    skip:
        enabled &&
            Platform.environment['BUSYMAX_NEXTCLOUD_DISABLED_FREEBUSY_LIVE'] ==
                '1'
        ? false
        : 'Requires administrator-disabled free/busy on a disposable server.',
  );
  test(
    'disabled calendar retention is reported without inventing trash entries',
    () async {
      final f = await NextcloudExtendedFixture.open();
      addTearDown(f.close);
      final object = await f.importEvent();
      final context = await f.collections.openContext();
      expect(
        (await context.send('DELETE', Uri.parse(object.requestUri))).statusCode,
        204,
      );
      final listing = await NextcloudTrashService(f.collections).list();
      expect(listing.retentionSeconds, 0);
      expect(listing.items.where((i) => i.uid == f.uid), isEmpty);
      expect(
        (await context.send('GET', Uri.parse(object.requestUri))).statusCode,
        404,
      );
    },
    skip:
        enabled &&
            Platform.environment['BUSYMAX_NEXTCLOUD_DISABLED_RETENTION_LIVE'] ==
                '1'
        ? false
        : 'Requires disabled retention on a disposable server.',
  );
  test(
    'real scheduling free-busy and inbox use the scoped account client',
    () async {
      final f = await NextcloudExtendedFixture.open();
      addTearDown(f.close);
      final guest = await NextcloudExtendedFixture.open(
        username:
            Platform
                .environment['BUSYMAX_NEXTCLOUD_EXTENDED_LIVE_ATTENDEE_USERNAME'] ??
            'attendee',
      );
      addTearDown(guest.close);
      final address = (await NextcloudSchedulingPolicy.load(
        guest.database,
        guest.collection,
      )).organizerAddress!;
      await guest.importRaw(
        'BEGIN:VCALENDAR\r\nVERSION:2.0\r\nPRODID:-//BusyMax QA//EN\r\nBEGIN:VEVENT\r\n'
        'UID:${guest.uid}\r\nDTSTAMP:20261101T000000Z\r\nSUMMARY:${guest.title}\r\n'
        'DTSTART:20261120T120000Z\r\nDTEND:20261120T130000Z\r\nTRANSP:OPAQUE\r\nEND:VEVENT\r\nEND:VCALENDAR\r\n',
      );
      final scheduling = NextcloudSchedulingService(f.collections);
      final result = await scheduling.freeBusy(
        collectionId: f.collection.id,
        startUtc: DateTime.utc(2026, 11, 20, 11),
        endUtc: DateTime.utc(2026, 11, 20, 14),
        recipients: [address, 'mailto:missing-${f.id}@busymax.invalid'],
      );
      final known = result.singleWhere((r) => r.recipient == address);
      expect(known.availability, NextcloudAvailability.known);
      expect(
        known.intervals.any(
          (i) =>
              i.startUtc == DateTime.utc(2026, 11, 20, 12) &&
              i.endUtc == DateTime.utc(2026, 11, 20, 13),
        ),
        isTrue,
      );
      expect(
        result.singleWhere((r) => r.recipient != address).availability,
        NextcloudAvailability.unknown,
      );
      final free = await scheduling.freeBusy(
        collectionId: f.collection.id,
        startUtc: DateTime.utc(2026, 11, 20, 16),
        endUtc: DateTime.utc(2026, 11, 20, 17),
        recipients: [address],
      );
      expect(free.single.availability, NextcloudAvailability.known);
      expect(free.single.intervals, isEmpty);
      expect(
        await scheduling.inbox(f.collection.id),
        isA<List<NextcloudInboxMessage>>(),
      );
    },
    skip: enabled
        ? false
        : 'Set $_enabledVariable=1 with disposable HTTPS live-fixture credentials.',
    timeout: const Timeout(Duration(minutes: 3)),
  );
}

Future<void> _syncFederationPeer() async {
  final container =
      Platform.environment['BUSYMAX_NEXTCLOUD_FEDERATION_LIVE_CONTAINER'];
  if (container == null ||
      !RegExp(r'^busymax-qa-[a-zA-Z0-9-]+$').hasMatch(container)) {
    throw StateError(
      'Set the explicitly disposable busymax-qa peer container for official federation:sync-calendars execution.',
    );
  }
  final result = await Process.run('docker', [
    'exec',
    '-u',
    'www-data',
    container,
    'php',
    'occ',
    'federation:sync-calendars',
  ]);
  expect(
    result.exitCode,
    0,
    reason: 'The official peer federation synchronization must execute successfully.',
  );
}

Future<int> _originFederationStatus(
  int invitationId,
  String cloudId,
  String member,
) async {
  final container =
      Platform.environment['BUSYMAX_NEXTCLOUD_FEDERATION_LIVE_CONTAINER']!;
  if (!RegExp(r'^busymax-qa-[a-zA-Z0-9-]+$').hasMatch(container)) {
    throw StateError('Disposable peer required.');
  }
  // Minimal direct protocol comparison. The federation token stays inside its
  // owning server and is sent only to the origin recorded by that server.
  const script =
      r'''define("OC_CONSOLE", true); require "/var/www/html/lib/base.php";
$c=\OCP\Server::get(\OCA\DAV\CalDAV\Federation\FederatedCalendarMapper::class)->find((int)getenv("BUSYMAX_QA_INVITATION"));
$h=curl_init(rtrim($c->getRemoteUrl(),"/")."/".rawurlencode(getenv("BUSYMAX_QA_MEMBER")));
curl_setopt_array($h,[CURLOPT_RETURNTRANSFER=>true,CURLOPT_FOLLOWLOCATION=>false,CURLOPT_USERPWD=>base64_encode(getenv("BUSYMAX_QA_CLOUD_ID")).":".$c->getToken()]);
curl_exec($h); echo curl_getinfo($h,CURLINFO_RESPONSE_CODE);''';
  final result = await Process.run('docker', [
    'exec',
    '-u',
    'www-data',
    '-e',
    'BUSYMAX_QA_INVITATION=$invitationId',
    '-e',
    'BUSYMAX_QA_MEMBER=$member',
    '-e',
    'BUSYMAX_QA_CLOUD_ID=$cloudId',
    container,
    'php',
    '-r',
    script,
  ]);
  expect(result.exitCode, 0);
  return int.parse(result.stdout.toString().trim());
}

Future<Map<String, dynamic>> _capturedSchedulingMail(
  String uid,
  String recipient,
) async {
  final directory = Platform.environment['BUSYMAX_NEXTCLOUD_MAIL_CAPTURE_DIR'];
  if (directory == null) {
    throw StateError(
      'The opt-in scheduling test requires a local mail-capture directory.',
    );
  }
  const script = r'''import email,email.policy,email.utils,pathlib,json,sys
counts={"REQUEST":0,"CANCEL":0}
for path in list(pathlib.Path(sys.argv[1]).glob("mail-*.eml"))[-500:]:
 message=email.message_from_bytes(path.read_bytes(),policy=email.policy.default)
 recipients=[a.lower() for _,a in email.utils.getaddresses(message.get_all("To",[]))]
 if sys.argv[3].lower() not in recipients:continue
 for part in message.walk():
  if part.get_content_type() not in ("text/calendar","application/ics"):continue
  raw=(part.get_payload(decode=True) or b"").decode("utf8",errors="replace").replace("\r\n ","")
  if "UID:"+sys.argv[2] not in raw:continue
  for method in counts:
   if "METHOD:"+method in raw:counts[method]+=1
print(json.dumps(counts))''';
  final result = await Process.run('python3', [
    '-c',
    script,
    directory,
    uid,
    recipient,
  ]);
  expect(result.exitCode, 0);
  return Map<String, dynamic>.from(jsonDecode(result.stdout.toString()) as Map);
}

import 'dart:convert';
import 'dart:io';

import 'package:busymax/src/dav/dav_errors.dart';
import 'package:busymax/src/dav/ical/dav_native_import.dart';
import 'package:busymax/src/dav/ical/ical_document.dart';
import 'package:busymax/src/features/calendar/presentation/event_editor_draft.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xml/xml.dart';

import 'support/caldav_fixture.dart';

void main() {
  test(
    'Baikal VTODO duplication consent: independent inbox REQUEST readback after accepted copy',
    () async {
      final alice = CalDavFixture(
        Uri.parse('https://localhost:18444/dav.php/'),
      );
      final bob = CalDavFixture(Uri.parse('https://localhost:18444/dav.php/'));
      await alice.open();
      addTearDown(alice.close);
      await bob.open(username: 'bob');
      addTearDown(bob.close);
      final service = await alice.database
          .select(alice.database.davAccountServices)
          .getSingle();
      final attendeeService = await bob.database
          .select(bob.database.davAccountServices)
          .getSingle();
      String address(String encoded) => (jsonDecode(encoded) as List)
          .cast<String>()
          .firstWhere((v) => v.startsWith('mailto:'));
      final organizer = address(service.calendarUserAddressesJson),
          attendee = address(attendeeService.calendarUserAddressesJson);
      final inbox = Uri.parse(attendeeService.scheduleInboxHref!);
      final uid =
          'busymax-task-consent-${DateTime.now().microsecondsSinceEpoch}@example.invalid';
      final ownedUids = <String>{uid};
      addTearDown(() async {
        await alice.synchronize(full: true);
        for (final row
            in await alice.database.select(alice.database.davObjects).get()) {
          if (ownedUids.contains(row.primaryUid)) {
            await alice.independentRequest('DELETE', Uri.parse(row.requestUri));
          }
        }
        await bob.synchronize(full: true);
        for (final row
            in await bob.database.select(bob.database.davObjects).get()) {
          if (ownedUids.contains(row.primaryUid)) {
            await bob.independentRequest('DELETE', Uri.parse(row.requestUri));
          }
        }
        for (final entry in (await _inboxMessages(bob, inbox)).entries) {
          if (ownedUids.any(entry.value.contains)) {
            await bob.independentRequest('DELETE', entry.key);
          }
        }
      });
      final raw =
          'BEGIN:VCALENDAR\r\nVERSION:2.0\r\nPRODID:-//BusyMax//QA//EN\r\nBEGIN:VTODO\r\nUID:$uid\r\nDTSTAMP:20261107T000000Z\r\nDTSTART:20261203T120000Z\r\nDUE:20261203T130000Z\r\nSUMMARY:Disposable VTODO scheduling QA\r\nORGANIZER:$organizer\r\nATTENDEE;RSVP=TRUE:$attendee\r\nX-KEEP:opaque\r\nEND:VTODO\r\nEND:VCALENDAR\r\n';
      await alice.importResources(
        NextcloudNativeImportPreview.parse(IcalDocument.parse(raw)),
        allowScheduling: true,
      );
      await alice.synchronize();
      final stored =
          (await alice.database.select(alice.database.davObjects).get())
              .singleWhere((row) => row.primaryUid == uid);
      final readback = await alice.independentRequest(
        'GET',
        Uri.parse(stored.requestUri),
      );
      expect(readback.statusCode, 200);
      expect(readback.body, contains('BEGIN:VTODO'));
      expect(readback.body, contains('ATTENDEE'));
      expect(
        await alice.database.select(alice.database.pendingOps).get(),
        isEmpty,
      );
      final initialMessages = await _inboxMessages(bob, inbox);
      if (!initialMessages.values.any(
        (body) => body.contains(uid) && body.contains('METHOD:REQUEST'),
      )) {
        markTestSkipped(
          'This unmodified server did not demonstrate VTODO scheduling delivery; stored PUT is insufficient evidence.',
        );
        return;
      }
      final task = (await alice.database.select(alice.database.tasks).get())
          .singleWhere((r) => r.icalUid == uid);
      await expectLater(
        alice.tasks.duplicateTask(task.taskListId, task.id),
        throwsA(
          isA<DavException>().having(
            (e) => e.code,
            'code',
            'IcalSchedulingConsentRequired',
          ),
        ),
      );
      expect(
        await alice.database.select(alice.database.pendingOps).get(),
        isEmpty,
      );
      expect(
        (await _inboxMessages(bob, inbox)).keys.toSet(),
        initialMessages.keys.toSet(),
      );
      final id = await alice.tasks.duplicateTask(
        task.taskListId,
        task.id,
        allowScheduling: true,
      );
      final copy = (await alice.database.select(alice.database.tasks).get())
          .singleWhere((r) => r.id == id);
      ownedUids.add(copy.icalUid!);
      await alice.reopen();
      await alice.synchronize();
      expect(
        await alice.database.select(alice.database.pendingOps).get(),
        isEmpty,
      );
      expect(
        (await _inboxMessages(bob, inbox)).values.any(
          (body) =>
              body.contains(copy.icalUid!) &&
              body.contains('METHOD:REQUEST') &&
              body.contains('BEGIN:VTODO'),
        ),
        isTrue,
      );
      stdout.writeln(
        'Unmodified Baikal/sabre VTODO scheduling: rejected copy queued nothing; accepted copy delivered REQUEST to the isolated attendee inbox after restart.',
      );
    },
    skip: Platform.environment['BUSYMAX_CALDAV_LIVE'] != '1'
        ? 'Requires isolated Baikal fixture.'
        : false,
  );

  test(
    'Baikal implicit scheduling: no import before consent; consent delivers to local attendee',
    () async {
      final alice = CalDavFixture(
        Uri.parse('https://localhost:18444/dav.php/'),
      );
      final bob = CalDavFixture(Uri.parse('https://localhost:18444/dav.php/'));
      await alice.open();
      addTearDown(alice.close);
      await bob.open(username: 'bob');
      addTearDown(bob.close);
      final service = await alice.database
          .select(alice.database.davAccountServices)
          .getSingle();
      final attendeeService = await bob.database
          .select(bob.database.davAccountServices)
          .getSingle();
      String address(String value) => (jsonDecode(value) as List)
          .cast<String>()
          .firstWhere((s) => s.startsWith('mailto:'));
      final organizer = address(service.calendarUserAddressesJson);
      final attendee = address(attendeeService.calendarUserAddressesJson);
      final options = await alice.independentRequest('OPTIONS', alice.uri);
      expect(options.headers['dav'], contains('calendar-auto-schedule'));
      final inbox = Uri.parse(attendeeService.scheduleInboxHref!);
      Future<Map<Uri, String>> messages() async {
        final listing = await bob.independentRequest(
          'PROPFIND',
          inbox,
          headers: {'Depth': '1'},
          body: '<d:propfind xmlns:d="DAV:"><d:prop><d:getetag/></d:prop></d:propfind>',
        );
        expect(listing.statusCode, 207);
        final result = <Uri, String>{};
        for (final href in XmlDocument.parse(
          listing.body,
        ).findAllElements('href', namespaceUri: 'DAV:')) {
          final uri = inbox.resolve(href.innerText);
          if (uri.path == inbox.path) continue;
          final response = await bob.independentRequest('GET', uri);
          if (response.statusCode == 200) result[uri] = response.body;
        }
        return result;
      }

      final uid =
          'busymax-import-consent-${DateTime.now().microsecondsSinceEpoch}@example.invalid';
      final preview = NextcloudNativeImportPreview.parse(
        IcalDocument.parse(
          'BEGIN:VCALENDAR\r\nVERSION:2.0\r\nPRODID:-//BusyMax//QA//EN\r\nBEGIN:VEVENT\r\nUID:$uid\r\nDTSTAMP:20261103T000000Z\r\nDTSTART:20261203T120000Z\r\nDTEND:20261203T130000Z\r\nSUMMARY:Disposable import consent QA\r\nORGANIZER:$organizer\r\nATTENDEE;RSVP=TRUE:$attendee\r\nEND:VEVENT\r\nEND:VCALENDAR\r\n',
        ),
      );
      final before = await messages();
      addTearDown(() async {
        // Delete the synthetic organizer event first, then attendee copies and
        // inbox messages (including any cancellation generated by deletion).
        for (final row
            in await alice.database.select(alice.database.davObjects).get()) {
          if (row.primaryUid == uid) {
            await alice.independentRequest('DELETE', Uri.parse(row.requestUri));
          }
        }
        await bob.synchronize(full: true);
        for (final row
            in await bob.database.select(bob.database.davObjects).get()) {
          if (row.primaryUid == uid) {
            await bob.independentRequest('DELETE', Uri.parse(row.requestUri));
          }
        }
        for (final entry in (await messages()).entries) {
          if (entry.value.contains(uid)) {
            await bob.independentRequest('DELETE', entry.key);
          }
        }
      });
      await expectLater(
        alice.importResources(preview),
        throwsA(
          isA<DavException>().having(
            (e) => e.code,
            'code',
            'IcalSchedulingConsentRequired',
          ),
        ),
      );
      expect(
        await alice.database.select(alice.database.pendingOps).get(),
        isEmpty,
      );
      expect((await messages()).keys.toSet(), before.keys.toSet());
      final imported = await alice.importResources(
        preview,
        allowScheduling: true,
      );
      expect(imported.single.status, NativeImportItemStatus.queued);
      await alice.synchronize();
      expect(
        await alice.database.select(alice.database.pendingOps).get(),
        isEmpty,
      );
      final delivered = await messages();
      expect(
        delivered.values.any(
          (body) => body.contains(uid) && body.contains('METHOD:REQUEST'),
        ),
        isTrue,
      );
      await alice.reopen();
      final event =
          (await alice.database.select(alice.database.calendarEvents).get())
              .singleWhere(
                (event) => event.davCollectionId == alice.eventCollectionId,
              );
      final detail = (await alice.calendars.loadEventDetail(event.id))!;
      await alice.calendars.updateLocalEvent(
        EventEditorDraft.fromEventDetail(detail)
            .copyWith(title: 'Updated consent QA'),
      );
      await alice.synchronize();
      expect(
        await alice.database.select(alice.database.pendingOps).get(),
        isEmpty,
      );
      expect(
        (await messages()).values.any(
          (body) =>
              body.contains(uid) && body.contains('SUMMARY:Updated consent QA'),
        ),
        isTrue,
      );
      stdout.writeln(
        'Baikal calendar-auto-schedule: import blocked without consent; explicit consent delivered REQUEST to disposable local attendee inbox.',
      );
    },
    skip: Platform.environment['BUSYMAX_CALDAV_LIVE'] != '1'
        ? 'Requires isolated Baikal fixture.'
        : false,
  );
}

Future<Map<Uri, String>> _inboxMessages(
  CalDavFixture fixture,
  Uri inbox,
) async {
  final listing = await fixture.independentRequest(
    'PROPFIND',
    inbox,
    headers: {'Depth': '1'},
    body:
        '<d:propfind xmlns:d="DAV:"><d:prop><d:getetag/></d:prop></d:propfind>',
  );
  expect(listing.statusCode, 207);
  final messages = <Uri, String>{};
  for (final href in XmlDocument.parse(
    listing.body,
  ).findAllElements('href', namespaceUri: 'DAV:')) {
    final target = inbox.resolve(href.innerText);
    if (target.path == inbox.path) continue;
    final response = await fixture.independentRequest('GET', target);
    if (response.statusCode == 200) messages[target] = response.body;
  }
  return messages;
}

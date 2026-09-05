import 'package:busymax/src/dav/dav_errors.dart';
import 'package:busymax/src/dav/ical/ical_semantics.dart';
import 'package:busymax/src/dav/nextcloud/nextcloud_scheduling_policy.dart';
import 'package:busymax/src/dav/nextcloud/nextcloud_scheduling_mutations.dart';
import 'package:busymax/src/features/calendar/presentation/event_editor_draft.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  NextcloudSchedulingPolicy policy(
    String address, {
    bool invite = false,
    bool reply = false,
    bool federated = false,
  }) => NextcloudSchedulingPolicy(
    addresses: {address},
    outbox: Uri.parse('https://cloud.example.test/outbox/'),
    inbox: Uri.parse('https://cloud.example.test/inbox/'),
    principal: Uri.parse('https://cloud.example.test/principal/'),
    canInvite: invite,
    canReply: reply,
    canQueryFreeBusy: false,
    federated: federated,
  );
  test(
    'organizer and reply privileges are independent of object writability',
    () {
      final edited = _raw.replaceFirst('SUMMARY:Meeting', 'SUMMARY:Changed');
      expect(
        () => policy(
          'mailto:owner@example.test',
        ).validateChange(baseline: _raw, candidate: edited),
        throwsA(isA<DavException>()),
      );
      expect(
        () => policy(
          'mailto:owner@example.test',
          invite: true,
        ).validateChange(baseline: _raw, candidate: edited),
        returnsNormally,
      );
      expect(
        () => policy(
          'mailto:guest@example.test',
          reply: true,
        ).validateChange(baseline: _raw, candidate: edited),
        throwsA(isA<DavException>()),
      );
    },
  );
  test('attendee can change only its own participation parameters', () {
    final attendee = policy('mailto:guest@example.test', reply: true);
    final accepted = _raw.replaceFirst(
      'PARTSTAT=NEEDS-ACTION',
      'PARTSTAT=ACCEPTED',
    );
    expect(
      () => attendee.validateChange(baseline: _raw, candidate: accepted),
      returnsNormally,
    );
    expect(
      () => attendee.validateChange(
        baseline: _raw,
        candidate: accepted.replaceFirst('CN=Guest', 'CN=Another'),
      ),
      throwsA(isA<DavException>()),
    );
    expect(
      () => attendee.validateChange(
        baseline: _raw,
        candidate: accepted.replaceFirst('SEQUENCE:4', 'SEQUENCE:5'),
      ),
      throwsA(isA<DavException>()),
    );
  });
  test(
    'federated content is not blanket read-only but cannot promise invitations',
    () {
      final federated = policy('mailto:owner@example.test', federated: true);
      expect(
        () => federated.validateChange(
          baseline: _raw,
          candidate: _raw.replaceFirst('SUMMARY:Meeting', 'SUMMARY:Changed'),
        ),
        returnsNormally,
      );
      expect(
        () => federated.validateChange(
          baseline: _raw,
          candidate: _raw.replaceFirst(
            'mailto:guest@example.test',
            'mailto:new@example.test',
          ),
        ),
        throwsA(isA<DavException>()),
      );
    },
  );
  test(
    'attendee role changes preserve server parameters and participation',
    () {
      final baseline = IcalSemanticDocument.parse(
        _raw,
      ).components.single.documentComponent;
      final values = nextcloudAttendeeValues([
        const EventAttendeeDraft(
          email: 'guest@example.test',
          displayName: 'Guest',
          optional: true,
        ),
      ], baseline);
      expect(
        values.single.parameters.singleWhere((p) => p.name == 'ROLE').values,
        ['OPT-PARTICIPANT'],
      );
      expect(
        values.single.parameters
            .singleWhere((p) => p.name == 'PARTSTAT')
            .values,
        ['NEEDS-ACTION'],
      );
      expect(
        values.single.parameters.singleWhere((p) => p.name == 'X-TEST').values,
        ['keep'],
      );
    },
  );
  test(
    'calendar addresses and native participant labels are decoded, not login names',
    () {
      expect(
        normalizeCalendarAddress('mailto:GUEST%40example.test'),
        'mailto:guest@example.test',
      );
      final semantic = IcalSemanticDocument.parse(_raw);
      final draft = EventAttendeeDraft.fromJson(
        semantic.components.single.attendees.single,
      );
      expect(draft.email, 'guest@example.test');
      expect(draft.displayName, 'Guest');
      expect(draft.responseStatus, 'NEEDS-ACTION');
    },
  );
}

const _raw = '''BEGIN:VCALENDAR
VERSION:2.0
PRODID:-//QA//EN
BEGIN:VEVENT
UID:meeting
SEQUENCE:4
DTSTAMP:20260901T000000Z
DTSTART:20260906T100000Z
DTEND:20260906T110000Z
SUMMARY:Meeting
ORGANIZER:mailto:owner@example.test
ATTENDEE;CN=Guest;ROLE=REQ-PARTICIPANT;PARTSTAT=NEEDS-ACTION;X-TEST=keep:mailto:guest@example.test
END:VEVENT
END:VCALENDAR
''';

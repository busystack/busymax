import '../../features/calendar/presentation/event_editor_draft.dart';
import '../ical/ical_document.dart';
import '../ical/ical_semantics.dart';
import '../mutation/dav_mutation_patch.dart';
import 'nextcloud_scheduling_policy.dart';

List<DavRawPropertyValue> nextcloudAttendeeValues(
  List<EventAttendeeDraft> attendees,
  IcalComponent? baseline,
) {
  final existing = {
    for (final p
        in baseline?.propertiesNamed('ATTENDEE') ?? const <IcalProperty>[])
      normalizeCalendarAddress(p.rawValue): p,
  };
  final seen = <String>{};
  return [
    for (final attendee in attendees) _attendee(attendee, existing, seen),
  ];
}

DavRawPropertyValue _attendee(
  EventAttendeeDraft attendee,
  Map<String, IcalProperty> existing,
  Set<String> seen,
) {
  final email = attendee.email.trim();
  final address =
      existing.containsKey(normalizeCalendarAddress(email)) ||
          email.toLowerCase().startsWith('mailto:')
      ? email
      : 'mailto:$email';
  final key = normalizeCalendarAddress(address);
  if (!seen.add(key)) throw ArgumentError('Duplicate attendee address.');
  final before = existing[key];
  if (before == null &&
      !RegExp(r'^mailto:[^\s@<>]+@[^\s@<>]+$').hasMatch(address)) {
    throw ArgumentError('Invalid attendee address.');
  }
  final parameters = [...?before?.parameters];
  void set(String name, String? value) {
    parameters.removeWhere((p) => p.name == name);
    if (value != null && value.isNotEmpty) {
      parameters.add(
        IcalParameter(name: name, values: [value], wasQuoted: name == 'CN'),
      );
    }
  }

  if (before == null ||
      attendee.optional !=
          (before.parameterValue('ROLE') == 'OPT-PARTICIPANT')) {
    set('ROLE', attendee.optional ? 'OPT-PARTICIPANT' : 'REQ-PARTICIPANT');
  }
  if (attendee.displayName != before?.parameterValue('CN')) {
    set('CN', attendee.displayName);
  }
  if (before == null) {
    set('PARTSTAT', 'NEEDS-ACTION');
    set('RSVP', 'TRUE');
  }
  return DavRawPropertyValue(
    value: before?.rawValue ?? address,
    parameters: parameters,
  );
}

/// Freeze scheduling timestamps once, before queuing; never increment a
/// sequence just because alarms or other local presentation fields changed.
List<DavPatchOperation> nextcloudSchedulingStamps({
  required IcalSemanticComponent baseline,
  required Iterable<DavPatchOperation> changes,
  required DateTime nowUtc,
  required bool organizer,
}) {
  final names = {for (final change in changes) ...change.changedProperties};
  const meetingFields = {
    'SUMMARY',
    'DESCRIPTION',
    'LOCATION',
    'DTSTART',
    'DTEND',
    'DURATION',
    'ATTENDEE',
    'RRULE',
    'RDATE',
    'EXDATE',
    'STATUS',
    'RECURRENCE-ID',
  };
  if (!names.any(meetingFields.contains)) return const [];
  return [
    if (organizer)
      DavPatchOperation.setRaw('SEQUENCE', '${(baseline.sequence ?? 0) + 1}'),
    DavPatchOperation.setRaw('DTSTAMP', nextcloudIcalUtc(nowUtc)),
    DavPatchOperation.setRaw('LAST-MODIFIED', nextcloudIcalUtc(nowUtc)),
  ];
}

String nextcloudIcalUtc(DateTime value) {
  final utc = value.toUtc();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${utc.year.toString().padLeft(4, '0')}${two(utc.month)}${two(utc.day)}T${two(utc.hour)}${two(utc.minute)}${two(utc.second)}Z';
}

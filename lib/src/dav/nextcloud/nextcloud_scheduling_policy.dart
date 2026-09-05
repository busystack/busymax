import 'dart:convert';

import '../../db/app_database.dart';
import '../dav_errors.dart';
import '../discovery/dav_discovery_models.dart';
import '../ical/ical_document.dart';
import '../ical/ical_recurrence.dart';
import '../ical/ical_semantics.dart';
import '../ical/ical_timezone.dart';
import '../xml/dav_xml.dart';

/// Uses discovered calendar addresses and the selected principal/home context.
/// A login name is never treated as an organizer or attendee address.
final class NextcloudSchedulingPolicy {
  const NextcloudSchedulingPolicy({
    required this.addresses,
    required this.outbox,
    required this.inbox,
    required this.principal,
    required this.canInvite,
    required this.canReply,
    required this.canQueryFreeBusy,
    required this.federated,
  });
  final Set<String> addresses;
  final Uri? outbox;
  final Uri? inbox;
  final Uri? principal;
  final bool canInvite;
  final bool canReply;
  final bool canQueryFreeBusy;
  final bool federated;
  String? get organizerAddress =>
      addresses.where((a) => a.startsWith('mailto:')).firstOrNull;
  Map<String, Object?> get projection => {
    'calendarUserAddresses': addresses.toList(),
    'canInvite': canInvite,
    'canReply': canReply,
    'canQueryFreeBusy': canQueryFreeBusy,
    'federated': federated,
  };
  bool ownsAddress(String? address) =>
      address != null && addresses.contains(normalizeCalendarAddress(address));

  static Future<NextcloudSchedulingPolicy> load(
    AppDatabase database,
    DavCollection collection,
  ) async {
    final service =
        await (database.select(database.davAccountServices)
              ..where((r) => r.accountId.equals(collection.accountId)))
            .getSingleOrNull();
    return NextcloudSchedulingPolicy.fromStored(collection, service);
  }

  factory NextcloudSchedulingPolicy.fromStored(
    DavCollection collection,
    DavAccountService? service,
  ) {
    final metadata = _map(collection.safeDisplayMetadataJson);
    final capabilities = _map(service?.capabilitiesJson);
    final principalHref =
        metadata['principalHref']?.toString() ?? service?.principalHref;
    final homeHref =
        metadata['calendarHomeHref']?.toString() ?? service?.calendarHomeHref;
    final contexts = [
      for (final value
          in capabilities['principalContexts'] as List? ?? const [])
        if (value is Map)
          DavPrincipalContext.fromJson(Map<String, Object?>.from(value)),
    ];
    final context = contexts
        .where(
          (c) =>
              _samePath(c.principalHref.toString(), principalHref) &&
              _samePath(c.calendarHomeHref.toString(), homeHref),
        )
        .firstOrNull;
    final owner = Uri.tryParse(collection.ownerHref ?? '')?.path ?? '';
    // Stable Nextcloud returns principals/remote-users/<opaque id> for
    // federated owners. This identifies a returned identity; it never builds
    // an account or collection URL from a user name.
    final federated =
        metadata['federated'] == true ||
        owner.split('/').contains('remote-users');
    final features = (capabilities['serverFeatures'] as List? ?? const [])
        .whereType<String>()
        .toSet();
    final types = (jsonDecode(collection.resourceTypesJson) as List)
        .whereType<String>()
        .toSet();
    final supported =
        features.contains('calendar-auto-schedule') &&
        context != null &&
        !collection.deleted &&
        !collection.serverMissing &&
        !federated &&
        !types.contains('{http://calendarserver.org/ns/}subscribed') &&
        collection.eventProjectionEnabled;
    final privileges = context?.outboxPrivileges ?? const <String>{};
    bool send(String name) =>
        supported &&
        context.scheduleOutboxHref != null &&
        (privileges.contains('{DAV:}all') ||
            privileges.contains('{$caldavNamespace}schedule-send') ||
            privileges.contains('{$caldavNamespace}$name'));
    return NextcloudSchedulingPolicy(
      addresses: Set.unmodifiable(
        (context?.calendarUserAddresses ?? const <Uri>[]).map(
          (u) => normalizeCalendarAddress(u.toString()),
        ),
      ),
      outbox: context?.scheduleOutboxHref,
      inbox: context?.scheduleInboxHref,
      principal: context?.principalHref,
      canInvite: send('schedule-send-invite'),
      canReply: send('schedule-send-reply'),
      canQueryFreeBusy: send('schedule-send-freebusy'),
      federated: federated,
    );
  }

  void requireOrganizer(IcalSemanticDocument document) {
    final masters = document.components.where(
      (c) => c.componentType == 'VEVENT' && c.recurrenceId == null,
    );
    final organizer = masters.firstOrNull?.documentComponent
        .firstProperty('ORGANIZER')
        ?.rawValue;
    if (!canInvite || !ownsAddress(organizer)) {
      throw schedulingDenied('DavOrganizerSchedulingDenied');
    }
  }

  /// Validates the entire backing object, not merely the clicked projection.
  /// CalDAV performs implicit scheduling for ordinary PUT/DELETE too.
  void validateChange({
    String? baseline,
    String? candidate,
    bool silentImport = false,
  }) {
    if (silentImport) return;
    final before = baseline == null
        ? null
        : IcalSemanticDocument.parse(baseline);
    final after = candidate == null
        ? null
        : IcalSemanticDocument.parse(candidate);
    final events = [
      ...?before?.components,
      ...?after?.components,
    ].where((c) => c.componentType == 'VEVENT').toList();
    if (!events.any((c) => c.organizers.isNotEmpty && c.attendees.isNotEmpty)) {
      return;
    }
    if (federated) {
      // Content editing remains governed by its ACL. It must not promise an
      // invitation/reply operation that this server explicitly skips.
      if (candidate != null && _schedulingAddressesChanged(before, after)) {
        throw schedulingDenied('DavFederatedSchedulingUnsupported');
      }
      return;
    }
    final organizer = events
        .firstWhere((c) => c.organizers.isNotEmpty)
        .documentComponent
        .firstProperty('ORGANIZER')!
        .rawValue;
    if (ownsAddress(organizer)) {
      if (!canInvite) throw schedulingDenied('DavSendInviteDenied');
      if (events.any(
        (c) => c.organizers.any(
          (o) =>
              normalizeCalendarAddress(o['value'].toString()) !=
              normalizeCalendarAddress(organizer),
        ),
      )) {
        throw schedulingDenied('DavOrganizerIdentityChanged');
      }
      return;
    }
    if (!canReply ||
        !events.any(
          (c) => c.attendees.any((a) => ownsAddress(a['value']?.toString())),
        )) {
      throw schedulingDenied('DavSchedulingIdentityUnavailable');
    }
    if (candidate == null) {
      return; // An attendee removal is an implicit decline.
    }
    if (before == null) {
      throw schedulingDenied('DavAttendeeCannotCreateMeeting');
    }
    String zones(IcalSemanticDocument document) => IcalDocument.create(
      components: document.timeZones.map((z) => z.deepCopy()).toList(),
    ).serialize(canonicalizeUntouched: true);
    if (zones(before) != zones(after!)) {
      throw schedulingDenied('DavAttendeeCannotChangeMeeting');
    }
    final original = {
      for (final c in before.components) c.recurrenceIdKey ?? 'master': c,
    };
    final remaining = {
      for (final c in after.components) c.recurrenceIdKey ?? 'master',
    };
    if (!remaining.containsAll(original.keys)) {
      throw schedulingDenied('DavAttendeeCannotChangeMeeting');
    }
    for (final changed in after.components) {
      final current =
          original[changed.recurrenceIdKey ?? 'master'] ?? original['master'];
      if (current == null) {
        throw schedulingDenied('DavAttendeeCannotChangeMeeting');
      }
      // Detached attendee replies may carry a represented occurrence's dates,
      // but cannot rewrite organizer-controlled meeting data.
      final addedException = !original.containsKey(
        changed.recurrenceIdKey ?? 'master',
      );
      if (addedException && !_sameOccurrenceTiming(before, changed)) {
        throw schedulingDenied('DavAttendeeCannotChangeMeeting');
      }
      final allowed = {
        'ATTENDEE',
        'TRANSP',
        'DTSTAMP',
        'LAST-MODIFIED',
        if (addedException) ...{
          'DTSTART',
          'DTEND',
          'DURATION',
          'RECURRENCE-ID',
          'RRULE',
          'RDATE',
          'EXDATE',
        },
      };
      final left = _protectedProperties(current.documentComponent, allowed);
      final right = _protectedProperties(changed.documentComponent, allowed);
      if (left != right ||
          !_otherAttendeesUnchanged(
            current.documentComponent,
            changed.documentComponent,
          )) {
        throw schedulingDenied('DavAttendeeCannotChangeMeeting');
      }
    }
  }

  void validateMoveTo(
    NextcloudSchedulingPolicy destination,
    String baseline,
    String candidate,
  ) {
    final document = IcalSemanticDocument.parse(baseline);
    if (!document.components.any(
      (c) =>
          c.componentType == 'VEVENT' &&
          c.organizers.isNotEmpty &&
          c.attendees.isNotEmpty,
    )) {
      return;
    }
    if (principal == null ||
        destination.principal == null ||
        !_samePath(principal.toString(), destination.principal.toString()) ||
        addresses.intersection(destination.addresses).isEmpty ||
        federated != destination.federated) {
      throw schedulingDenied('DavMeetingMoveIdentityChanged');
    }
    // Native MOVE skips cancellation on stable Nextcloud/Sabre. Any following
    // timing/content PUT is checked under the same effective identity.
    validateChange(baseline: baseline, candidate: candidate);
    destination.validateChange(baseline: baseline, candidate: candidate);
  }

  bool _otherAttendeesUnchanged(IcalComponent before, IcalComponent after) {
    String protected(IcalProperty p) {
      final clone = p.deepCopy();
      if (ownsAddress(p.rawValue)) {
        clone.parameters.removeWhere(
          (p) => {'PARTSTAT', 'RSVP', 'SCHEDULE-STATUS'}.contains(p.name),
        );
      }
      return clone.serializeLogicalLine();
    }

    final a = before.propertiesNamed('ATTENDEE').map(protected).toList()
      ..sort();
    final b = after.propertiesNamed('ATTENDEE').map(protected).toList()..sort();
    return jsonEncode(a) == jsonEncode(b);
  }
}

bool _sameOccurrenceTiming(
  IcalSemanticDocument before,
  IcalSemanticComponent changed,
) {
  final id = changed.recurrenceId;
  if (id == null || changed.start == null || changed.end == null) return false;
  final resolver = IcalTimeZoneResolver.fromDocument(before);
  final instant = resolver.toUtc(id);
  final occurrences = IcalRecurrenceExpander().expand(
    before,
    rangeStartUtc: instant.subtract(const Duration(days: 2)),
    rangeEndUtc: instant.add(const Duration(days: 2)),
  );
  final expected = occurrences
      .where((o) => o.recurrenceId.recurrenceKey == id.recurrenceKey)
      .firstOrNull;
  return expected?.end != null &&
      resolver.toUtc(expected!.start) == resolver.toUtc(changed.start!) &&
      resolver.toUtc(expected.end!) == resolver.toUtc(changed.end!);
}

String normalizeCalendarAddress(String address) {
  final uri = Uri.tryParse(address.trim());
  try {
    return uri?.scheme.toLowerCase() == 'mailto'
        ? 'mailto:${Uri.decodeComponent(uri!.path).toLowerCase()}'
        : address.trim().toLowerCase();
  } on FormatException {
    return address.trim().toLowerCase();
  }
}

DavException schedulingDenied(String code) => DavException(
  kind: DavErrorKind.authorization,
  code: code,
  safeMessage:
      'The selected calendar or scheduling identity does not permit this meeting operation.',
);
Map<String, Object?> _map(String? source) {
  try {
    final value = jsonDecode(source ?? '{}');
    return value is Map ? Map<String, Object?>.from(value) : const {};
  } on FormatException {
    return const {};
  }
}

bool _samePath(String? a, String? b) =>
    a != null &&
    b != null &&
    Uri.parse(a).path.replaceFirst(RegExp(r'/+$'), '') ==
        Uri.parse(b).path.replaceFirst(RegExp(r'/+$'), '');
String _protectedProperties(IcalComponent component, Set<String> allowed) {
  final values =
      component.properties
          .where((p) => !allowed.contains(p.name))
          .map((p) => p.serializeLogicalLine())
          .toList()
        ..sort();
  return jsonEncode(values);
}

bool _schedulingAddressesChanged(
  IcalSemanticDocument? a,
  IcalSemanticDocument? b,
) {
  if (a == null || b == null) return true;
  String signature(IcalSemanticDocument document) => jsonEncode([
    for (final c in document.components)
      [c.recurrenceIdKey, c.organizers, c.attendees],
  ]);
  return signature(a) != signature(b);
}

import 'package:uuid/uuid.dart';
import 'package:xml/xml.dart';
import 'package:drift/drift.dart';

import '../../core/time/provider_date_time.dart';
import '../../db/app_database.dart';
import '../../features/calendar/presentation/event_editor_draft.dart';
import '../ical/ical_timezone.dart';
import '../mutation/dav_pending_operations.dart';
import '../ical/ical_document.dart';
import '../ical/ical_semantics.dart';
import '../http/dav_http_transport.dart';
import '../xml/dav_xml.dart';
import 'nextcloud_collection_service.dart';
import 'nextcloud_dav_context.dart';
import 'nextcloud_scheduling_mutations.dart';
import 'nextcloud_scheduling_policy.dart';

enum NextcloudAvailability { known, unknown }

final class NextcloudBusyInterval {
  const NextcloudBusyInterval(this.startUtc, this.endUtc, this.type);
  final DateTime startUtc;
  final DateTime endUtc;
  final String type;
}

final class NextcloudFreeBusyResult {
  const NextcloudFreeBusyResult(
    this.recipient,
    this.availability,
    this.intervals,
    this.status,
  );
  final String recipient;
  final NextcloudAvailability availability;
  final List<NextcloudBusyInterval> intervals;
  final String? status;
}

final class NextcloudInboxMessage {
  const NextcloudInboxMessage._(
    this.href,
    this.etag,
    this.rawIcs,
    this.method,
    this.title,
  );
  final Uri href;
  final String etag;
  final String rawIcs;
  final String? method;
  final String title;
}

/// Explicit outbox free/busy and inbox operations. Meeting writes themselves
/// continue to use implicit scheduling through the existing conditional queue.
final class NextcloudSchedulingService {
  NextcloudSchedulingService(this.collections);
  final NextcloudCollectionService collections;

  Future<List<NextcloudFreeBusyResult>> freeBusyForDraft({
    required String collectionId,
    required EventEditorDraft draft,
    required String fallbackTimeZone,
  }) async {
    final start = draft.start, end = draft.end;
    if (start == null || end == null) {
      throw ArgumentError('The event interval is required.');
    }
    final collection = await collections.requiredCollection(collectionId);
    if (collection.accountId != draft.accountId) {
      throw schedulingDenied('DavAvailabilityIdentityChanged');
    }
    IcalTimeZoneResolver? resolver;
    final objectId = draft.originalDetail?.davObjectId;
    if (objectId != null) {
      final raw = await DavPendingOperationQueue(database: collections.database)
          .exportRawIcsForObject(
            accountId: draft.accountId,
            collectionId: collectionId,
            objectId: objectId,
          );
      resolver = IcalTimeZoneResolver.fromDocument(
        IcalSemanticDocument.parse(raw),
      );
    }
    DateTime instant(DateTime wall, String? zone) {
      final effective =
          zone ?? collection.calendarTimeZoneId ?? fallbackTimeZone;
      if (resolver == null) return providerWallTimeToInstant(wall, effective);
      final raw = nextcloudIcalUtc(
        DateTime.utc(
          wall.year,
          wall.month,
          wall.day,
          wall.hour,
          wall.minute,
          wall.second,
        ),
      );
      final temporal = parseIcalTemporal(
        IcalProperty(
          group: null,
          name: 'DTSTART',
          parameters: [
            IcalParameter(name: 'TZID', values: [effective], wasQuoted: false),
          ],
          rawValue: raw.substring(0, raw.length - 1),
          originalPhysicalLines: const [],
        ),
      );
      if (temporal == null) throw ArgumentError('Invalid event time.');
      return resolver.toUtc(temporal);
    }

    return freeBusy(
      collectionId: collectionId,
      startUtc: instant(start, draft.startTimeZone),
      endUtc: instant(end, draft.endTimeZone ?? draft.startTimeZone),
      recipients: [
        for (final attendee in draft.attendees)
          if (!attendee.self && !attendee.organizer) attendee.email,
      ],
    );
  }

  Future<List<NextcloudFreeBusyResult>> freeBusy({
    required String collectionId,
    required DateTime startUtc,
    required DateTime endUtc,
    required List<String> recipients,
  }) async {
    if (!endUtc.isAfter(startUtc) ||
        endUtc.difference(startUtc) > const Duration(days: 31)) {
      throw ArgumentError('Invalid free/busy range.');
    }
    final addresses = recipients
        .map(
          (r) => normalizeCalendarAddress(
            r.startsWith('mailto:') ? r : 'mailto:$r',
          ),
        )
        .toSet();
    if (addresses.isEmpty ||
        addresses.length > 50 ||
        addresses.any(
          (a) => !RegExp(r'^mailto:[^\s@<>]+@[^\s@<>]+$').hasMatch(a),
        )) {
      throw ArgumentError('Invalid availability recipients.');
    }
    final context = await collections.openContext();
    final collection = await collections.requiredCollection(collectionId);
    final policy = await NextcloudSchedulingPolicy.load(
      collections.database,
      collection,
    );
    if (!policy.canQueryFreeBusy ||
        policy.organizerAddress == null ||
        policy.outbox == null) {
      throw schedulingDenied('DavFreeBusyDenied');
    }
    final target = context.resolve(policy.outbox.toString(), context.authority);
    final data = [
      'BEGIN:VCALENDAR',
      'VERSION:2.0',
      'PRODID:-//BusyMax//CalDAV Client//EN',
      'METHOD:REQUEST',
      'BEGIN:VFREEBUSY',
      'UID:${const Uuid().v4()}@busymax.local',
      'DTSTAMP:${nextcloudIcalUtc(DateTime.now())}',
      'DTSTART:${nextcloudIcalUtc(startUtc)}',
      'DTEND:${nextcloudIcalUtc(endUtc)}',
      'ORGANIZER:${policy.organizerAddress}',
      for (final address in addresses) 'ATTENDEE:$address',
      'END:VFREEBUSY',
      'END:VCALENDAR',
      '',
    ].join('\r\n');
    final response = await context.transport.send(
      DavRequest.icalendar(
        method: 'POST',
        uri: target,
        accountId: context.accountId,
        collectionId: collectionId,
        correlationId: const Uuid().v4(),
        body: data,
        headers: {
          'originator': policy.organizerAddress!,
          'recipient': addresses.join(', '),
        },
      ),
      credential: context.credential,
    );
    if (response.statusCode != 200) {
      throw nextcloudOperationError(response.statusCode, 'DavFreeBusyFailed');
    }
    final root = const DavXmlParser()
        .parseDocument(response.bodyBytes)
        .rootElement;
    if (root.name.local != 'schedule-response' ||
        root.namespaceUri != caldavNamespace) {
      throw nextcloudOperationError(502, 'DavFreeBusyMalformed');
    }
    final found = <String, NextcloudFreeBusyResult>{};
    for (final entry in root.childElements.where(
      (e) => e.name.local == 'response' && e.namespaceUri == caldavNamespace,
    )) {
      final recipient = entry.childElements
          .where(
            (e) =>
                e.name.local == 'recipient' &&
                e.namespaceUri == caldavNamespace,
          )
          .firstOrNull;
      final href = recipient?.descendants
          .whereType<XmlElement>()
          .where(
            (e) => e.name.local == 'href' && e.namespaceUri == davNamespace,
          )
          .firstOrNull
          ?.innerText;
      if (href == null) continue;
      final address = normalizeCalendarAddress(href);
      if (!addresses.contains(address)) continue;
      if (found.containsKey(address)) {
        found[address] = NextcloudFreeBusyResult(
          address,
          NextcloudAvailability.unknown,
          const [],
          null,
        );
        continue;
      }
      final status = entry.childElements
          .where(
            (e) =>
                e.name.local == 'request-status' &&
                e.namespaceUri == caldavNamespace,
          )
          .firstOrNull
          ?.innerText;
      final raw = entry.childElements
          .where(
            (e) =>
                e.name.local == 'calendar-data' &&
                e.namespaceUri == caldavNamespace,
          )
          .firstOrNull
          ?.innerText;
      final intervals = status?.startsWith('2.') == true && raw != null
          ? _busyIntervals(raw, startUtc, endUtc)
          : null;
      found[address] = NextcloudFreeBusyResult(
        address,
        intervals == null
            ? NextcloudAvailability.unknown
            : NextcloudAvailability.known,
        intervals ?? const [],
        status,
      );
    }
    return [
      for (final address in addresses)
        found[address] ??
            NextcloudFreeBusyResult(
              address,
              NextcloudAvailability.unknown,
              const [],
              null,
            ),
    ];
  }

  Future<List<NextcloudInboxMessage>> inbox(String collectionId) async {
    final context = await collections.openContext();
    final collection = await collections.requiredCollection(collectionId);
    final policy = await NextcloudSchedulingPolicy.load(
      collections.database,
      collection,
    );
    if (policy.inbox == null) throw schedulingDenied('DavInboxUnavailable');
    final inbox = context.resolve(policy.inbox.toString(), context.authority);
    final response = await context.propfind(
      inbox,
      '<d:getetag/><c:calendar-data/>',
      depth: '1',
    );
    final messages = <NextcloudInboxMessage>[];
    for (final entry in response.responses) {
      final href = context.resolve(entry.href, inbox);
      if (href.path == inbox.path) continue;
      final inboxPrefix = inbox.path.endsWith('/')
          ? inbox.path
          : '${inbox.path}/';
      if (!href.path.startsWith(inboxPrefix) ||
          (entry.statusCode ?? 200) >= 400) {
        throw nextcloudOperationError(502, 'DavInboxIncomplete');
      }
      var etag = entry.successfulProperty(davNamespace, 'getetag')?.text.trim();
      var raw = entry
          .successfulProperty(caldavNamespace, 'calendar-data')
          ?.text;
      if (raw == null) {
        final fetched = await context.send(
          'GET',
          href,
          headers: {'accept': 'text/calendar'},
        );
        if (fetched.statusCode != 200) {
          throw nextcloudOperationError(
            fetched.statusCode,
            'DavInboxReadFailed',
          );
        }
        raw = fetched.bodyText;
        etag = fetched.etag;
      }
      if (etag == null || etag.isEmpty) {
        throw nextcloudOperationError(502, 'DavInboxEtagMissing');
      }
      final document = IcalDocument.parse(raw);
      final title =
          document.calendarComponents
              .where((c) => c.name == 'VEVENT')
              .firstOrNull
              ?.firstProperty('SUMMARY')
              ?.decodedTextValue ??
          '';
      messages.add(
        NextcloudInboxMessage._(
          href,
          etag,
          raw,
          document.root.firstProperty('METHOD')?.rawValue,
          title,
        ),
      );
    }
    return List.unmodifiable(messages);
  }

  Future<List<NextcloudInboxMessage>> cachedInbox(String collectionId) async {
    final collection = await collections.requiredCollection(collectionId);
    final policy = await NextcloudSchedulingPolicy.load(
      collections.database,
      collection,
    );
    if (policy.inbox == null) return const [];
    final bins =
        await (collections.database.select(collections.database.davCollections)
              ..where(
                (r) =>
                    r.accountId.equals(collection.accountId) &
                    r.deleted.equals(false) &
                    r.serverMissing.equals(false),
              ))
            .get();
    final inbox = bins
        .where(
          (b) =>
              Uri.parse(b.requestUri).path.replaceFirst(RegExp(r'/+$'), '') ==
              policy.inbox!.path.replaceFirst(RegExp(r'/+$'), ''),
        )
        .firstOrNull;
    if (inbox == null) return const [];
    final objects =
        await (collections.database.select(collections.database.davObjects)
              ..where(
                (r) =>
                    r.accountId.equals(collection.accountId) &
                    r.collectionId.equals(inbox.id) &
                    r.serverDeleted.equals(false),
              ))
            .get();
    return [
      for (final object in objects)
        if (object.etag != null)
          _inboxMessage(
            Uri.parse(object.requestUri),
            object.etag!,
            object.rawIcsBody,
          ),
    ];
  }

  Future<void> acknowledge(
    String collectionId,
    NextcloudInboxMessage message,
  ) async {
    final current = (await inbox(
      collectionId,
    )).where((m) => m.href == message.href).firstOrNull;
    if (current == null) return;
    if (current.etag != message.etag) {
      throw nextcloudOperationError(412, 'DavInboxMessageChanged');
    }
    final context = await collections.openContext();
    // Only the discovered inbox member is deleted. No event projection or
    // calendar-object resource is touched by acknowledgement.
    final response = await context.send(
      'DELETE',
      current.href,
      headers: {'if-match': current.etag},
    );
    if (response.statusCode != 404 &&
        (response.statusCode < 200 || response.statusCode >= 300)) {
      throw nextcloudOperationError(
        response.statusCode,
        'DavInboxAcknowledgeFailed',
      );
    }
    // This only tombstones the acknowledged inbox resource, not another
    // collection's event with the same UID. Synchronization remains in charge
    // of the inbox checkpoint and subsequent reconciliation.
    await (collections.database.update(collections.database.davObjects)..where(
          (r) =>
              r.accountId.equals(context.accountId) &
              r.requestUri.equals(current.href.toString()),
        ))
        .write(const DavObjectsCompanion(serverDeleted: Value(true)));
  }
}

NextcloudInboxMessage _inboxMessage(Uri href, String etag, String raw) {
  final document = IcalDocument.parse(raw);
  return NextcloudInboxMessage._(
    href,
    etag,
    raw,
    document.root.firstProperty('METHOD')?.rawValue,
    document.calendarComponents
            .where((c) => c.name == 'VEVENT')
            .firstOrNull
            ?.firstProperty('SUMMARY')
            ?.decodedTextValue ??
        '',
  );
}

List<NextcloudBusyInterval>? _busyIntervals(
  String raw,
  DateTime rangeStart,
  DateTime rangeEnd,
) {
  try {
    final document = IcalDocument.parse(raw);
    final components = document.calendarComponents
        .where((c) => c.name == 'VFREEBUSY')
        .toList();
    if (components.isEmpty) return null;
    final result = <NextcloudBusyInterval>[];
    for (final component in components) {
      final start = parseIcalTemporal(component.firstProperty('DTSTART'));
      final end = parseIcalTemporal(component.firstProperty('DTEND'));
      if (start?.kind != IcalTemporalKind.utcDateTime ||
          end?.kind != IcalTemporalKind.utcDateTime ||
          start!.localValue.isAfter(rangeStart) ||
          end!.localValue.isBefore(rangeEnd)) {
        return null;
      }
      for (final property in component.propertiesNamed('FREEBUSY')) {
        for (final period in property.rawValue.split(',')) {
          final parts = period.split('/');
          if (parts.length != 2) return null;
          IcalTemporalValue? temporal(String value) => parseIcalTemporal(
            IcalProperty(
              group: null,
              name: 'DTSTART',
              parameters: const [],
              rawValue: value,
              originalPhysicalLines: const [],
            ),
          );
          final from = temporal(parts.first);
          if (from?.kind != IcalTemporalKind.utcDateTime) return null;
          final to = parts.last.startsWith('P')
              ? from!.localValue.add(parseIcalDuration(parts.last)!.duration)
              : temporal(parts.last)?.localValue;
          if (to == null || !to.isAfter(from!.localValue)) return null;
          final type = property.parameterValue('FBTYPE') ?? 'BUSY';
          if (type != 'FREE') {
            result.add(NextcloudBusyInterval(from.localValue, to, type));
          }
        }
      }
    }
    return List.unmodifiable(result);
  } on Object {
    return null;
  }
}

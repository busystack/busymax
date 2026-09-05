import 'dart:convert';

import '../../db/app_database.dart';
import '../../providers/provider_capabilities.dart';
import '../dav_errors.dart';
import '../discovery/dav_discovery_models.dart';

/// Rehydrates the effective capability object persisted during discovery.
///
/// Mutation entry points use this function immediately before queueing or
/// replaying work. That keeps ACL and component-set changes authoritative and
/// prevents presentation code from inferring write access from provider type.
CollectionCapabilities collectionCapabilitiesFromStored(
  DavCollection collection,
) {
  final privileges = _stringSet(collection.currentUserPrivilegesJson);
  final reports = _stringSet(collection.supportedReportsJson);
  final aggregateAll = privileges.contains('{DAV:}all');
  final aggregateWrite = aggregateAll || privileges.contains('{DAV:}write');
  final resourceTypes = _stringSet(collection.resourceTypesJson);
  final contentResource =
      !resourceTypes.any(
        (type) => const {
          '{http://calendarserver.org/ns/}subscribed',
          '{http://nextcloud.com/ns}trash-bin',
          '{http://nextcloud.com/ns}deleted-calendar',
          '{urn:ietf:params:xml:ns:caldav}schedule-inbox',
          '{urn:ietf:params:xml:ns:caldav}schedule-outbox',
        }.contains(type),
      ) &&
      !collection.deleted &&
      !collection.serverMissing;
  return CollectionCapabilities(
    canRead: aggregateAll || privileges.contains('{DAV:}read'),
    canReadPrivileges:
        privileges.contains('{DAV:}read-current-user-privilege-set') ||
        aggregateAll,
    canWriteContent:
        contentResource &&
        (aggregateWrite || privileges.contains('{DAV:}write-content')),
    canWriteProperties:
        (aggregateWrite || privileges.contains('{DAV:}write-properties')),
    canAddMembers:
        contentResource &&
        (aggregateWrite || privileges.contains('{DAV:}bind')),
    canDeleteMembers:
        contentResource &&
        (aggregateWrite || privileges.contains('{DAV:}unbind')),
    canReadFreeBusy:
        privileges.contains('{urn:ietf:params:xml:ns:caldav}read-free-busy') ||
        aggregateAll,
    canSendInvitations:
        aggregateAll ||
        privileges.contains('{urn:ietf:params:xml:ns:caldav}schedule-send') ||
        privileges.contains(
          '{urn:ietf:params:xml:ns:caldav}schedule-send-invite',
        ),
    canSendReplies:
        aggregateAll ||
        privileges.contains('{urn:ietf:params:xml:ns:caldav}schedule-send') ||
        privileges.contains(
          '{urn:ietf:params:xml:ns:caldav}schedule-send-reply',
        ),
    canSendFreeBusy:
        aggregateAll ||
        privileges.contains('{urn:ietf:params:xml:ns:caldav}schedule-send') ||
        privileges.contains(
          '{urn:ietf:params:xml:ns:caldav}schedule-send-freebusy',
        ),
    supportsEvents: collection.supportedComponentMask & davComponentEvent != 0,
    supportsTasks: collection.supportedComponentMask & davComponentTodo != 0,
    supportsSyncCollection: reports.contains('{DAV:}sync-collection'),
    supportsCalendarMultiget: reports.contains(
      '{urn:ietf:params:xml:ns:caldav}calendar-multiget',
    ),
    supportsCalendarQuery: reports.contains(
      '{urn:ietf:params:xml:ns:caldav}calendar-query',
    ),
    supportedCalendarData: _calendarData(collection.supportedCalendarDataJson),
    maximumResourceSize: collection.maximumResourceSize,
    maximumInstances: collection.maximumInstances,
  );
}

Map<String, Object?> davSourcePermissionProjection(DavCollection collection) {
  final capabilities = collectionCapabilitiesFromStored(collection);
  final metadata = jsonDecode(collection.safeDisplayMetadataJson ?? '{}');
  return {
    if (metadata is Map) ...metadata.cast<String, Object?>(),
    'canRead': capabilities.canRead,
    'canCreateEvents': capabilities.canCreateEvent,
    'canEditEvents': capabilities.canUpdateEvent,
    'canDeleteEvents': capabilities.canDeleteEvent,
    'canWriteProperties': capabilities.canWriteProperties,
    'supportedComponentMask': collection.supportedComponentMask,
    'resourceTypes': _stringSet(collection.resourceTypesJson).toList(),
    'ownerHref': collection.ownerHref,
  };
}

Set<String> _stringSet(String source) {
  try {
    final decoded = jsonDecode(source);
    if (decoded is! List || decoded.any((value) => value is! String)) {
      throw _invalidCapabilities();
    }
    return decoded.cast<String>().toSet();
  } on DavException {
    rethrow;
  } on Object {
    throw _invalidCapabilities();
  }
}

Set<String> _calendarData(String source) {
  try {
    final decoded = jsonDecode(source);
    if (decoded is! List) throw _invalidCapabilities();
    return {
      for (final value in decoded)
        if (value is String)
          value
        else if (value is Map && value['contentType'] is String)
          value['contentType']! as String
        else
          throw _invalidCapabilities(),
    };
  } on DavException {
    rethrow;
  } on Object {
    throw _invalidCapabilities();
  }
}

DavException _invalidCapabilities() => const DavException(
  kind: DavErrorKind.protocol,
  code: 'DavStoredCapabilitiesInvalid',
  safeMessage: 'Stored DAV collection capabilities were invalid.',
);

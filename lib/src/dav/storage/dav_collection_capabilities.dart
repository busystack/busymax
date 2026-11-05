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
  final decodedMetadata = jsonDecode(
    collection.safeDisplayMetadataJson ?? '{}',
  );
  final metadata = decodedMetadata is Map ? decodedMetadata : const {};
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
    allowsItemMutations: contentResource,
    supportsMove: contentResource && metadata['supportsMove'] == 'true',
    permissionsKnown:
        metadata['privilegesKnown'] == 'true' ||
        (metadata['privilegesKnown'] == null && privileges.isNotEmpty),
    canRead:
        aggregateAll ||
        privileges.contains('{DAV:}read') ||
        metadata['readAccessConfirmed'] == 'true',
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
    // These flags are projected by NextcloudSchedulingPolicy from the matching
    // principal's actual outbox. DAV:all on a calendar is not outbox authority.
    canSendInvitations: contentResource && metadata['canInvite'] == true,
    canSendReplies: contentResource && metadata['canReply'] == true,
    canSendFreeBusy: contentResource && metadata['canQueryFreeBusy'] == true,
    providerAllowsSchedulingMutation: metadata['calendarUserAddresses'] is List,
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
    'permissionsKnown': capabilities.permissionsKnown,
    'canAttemptCreateEvents': capabilities.canAttemptCreateEvent,
    'canAttemptEditEvents': capabilities.canAttemptUpdateEvent,
    'canAttemptDeleteEvents': capabilities.canAttemptDeleteEvent,
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

/// Used for destructive collection operations. Access through another principal
/// and missing ownership information never establish ownership.
enum DavCollectionOwnership { owned, shared, unknown }

DavCollectionOwnership davCollectionOwnershipFromHrefs({
  required String? ownerHref,
  required String? principalHref,
  bool shared = false,
  bool delegated = false,
}) {
  if (shared || delegated) return DavCollectionOwnership.shared;
  final owner = _hrefPath(ownerHref);
  final principal = _hrefPath(principalHref);
  if (owner == null || principal == null) return DavCollectionOwnership.unknown;
  final ownerUri = Uri.parse(ownerHref!.trim());
  final principalUri = Uri.parse(principalHref!.trim());
  if (ownerUri.hasAuthority &&
      principalUri.hasAuthority &&
      (ownerUri.scheme != principalUri.scheme ||
          ownerUri.host != principalUri.host ||
          ownerUri.port != principalUri.port)) {
    return DavCollectionOwnership.shared;
  }
  return owner == principal
      ? DavCollectionOwnership.owned
      : DavCollectionOwnership.shared;
}

DavCollectionOwnership davCollectionOwnership(
  DavCollection collection,
  DavAccountService? service,
) {
  final metadata = jsonDecode(collection.safeDisplayMetadataJson ?? '{}');
  return davCollectionOwnershipFromHrefs(
    ownerHref: collection.ownerHref,
    principalHref: service?.principalHref,
    shared: metadata is Map && metadata['shared'] == true,
    delegated: metadata is Map && metadata['delegated'] == true,
  );
}

bool davCollectionIsShared(
  DavCollection collection,
  DavAccountService? service,
) {
  String? effectivePrincipal = service?.principalHref;
  try {
    final metadata = jsonDecode(collection.safeDisplayMetadataJson ?? '{}');
    if (metadata is Map && metadata['principalHref'] is String) {
      effectivePrincipal = metadata['principalHref'] as String;
    }
    if (metadata is Map && metadata['shared'] is bool) {
      return metadata['shared']! as bool;
    }
  } on FormatException {
    // Owner/principal comparison below remains a safe fallback.
  }
  final owner = _hrefPath(collection.ownerHref);
  final principal = _hrefPath(effectivePrincipal);
  return owner != null && principal != null && owner != principal;
}

String? _hrefPath(String? source) {
  if (source == null || source.trim().isEmpty) return null;
  final uri = Uri.tryParse(source.trim());
  if (uri == null ||
      uri.path.isEmpty ||
      uri.hasQuery ||
      uri.hasFragment ||
      uri.userInfo.isNotEmpty) {
    return null;
  }
  var path = uri.path;
  while (path.length > 1 && path.endsWith('/')) {
    path = path.substring(0, path.length - 1);
  }
  return path;
}

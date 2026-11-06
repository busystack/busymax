import 'dart:convert';

import '../../db/app_database.dart';
import '../ical/ical_semantics.dart';
import '../nextcloud/nextcloud_scheduling_policy.dart';

/// Inspect every component, including detached exceptions. A projection of one
/// occurrence is not evidence that the complete resource is a personal event.
bool davResourceHasSchedulingIdentity(String rawIcs) =>
    IcalSemanticDocument.parse(rawIcs).components.any(
      (c) =>
          c.componentType == 'VEVENT' &&
          (c.organizers.isNotEmpty || c.attendees.isNotEmpty),
    );

bool sameDavOrigin(Uri a, Uri b) =>
    a.scheme == b.scheme &&
    a.host == b.host &&
    a.port == b.port &&
    a.userInfo.isEmpty &&
    b.userInfo.isEmpty;

/// DAV:owner identifies the scheduling user of a calendar (RFC 6638 section
/// 3.1). Account ids, login names, and matching email addresses do not prove
/// that two calendars have the same scheduling identity.
Future<bool> sameDavSchedulingIdentity(
  AppDatabase database,
  DavCollection source,
  DavCollection destination,
) async {
  final sourceUri = Uri.parse(source.requestUri);
  final destinationUri = Uri.parse(destination.requestUri);
  if (!sameDavOrigin(sourceUri, destinationUri)) return false;
  Future<Uri?> owner(DavCollection collection) async {
    final service =
        await (database.select(database.davAccountServices)
              ..where((r) => r.accountId.equals(collection.accountId)))
            .getSingleOrNull();
    return davSchedulingPrincipalForCollection(collection, service: service);
  }

  final sourceOwner = await owner(source);
  return sourceOwner != null && sourceOwner == await owner(destination);
}

Uri? davSchedulingPrincipalForCollection(
  DavCollection collection, {
  DavAccountService? service,
}) {
  if (service?.lastDiscoveryErrorCode != null) return null;
  final metadata = jsonDecode(collection.safeDisplayMetadataJson ?? '{}');
  // The principal/home context is used only when discovery has identified
  // that context for this calendar. Never infer ownership from a login.
  final href =
      collection.ownerHref ??
      (metadata is Map ? metadata['principalHref'] as String? : null);
  if (href == null || href.trim().isEmpty) return null;
  final resolved = Uri.parse(collection.requestUri).resolve(href);
  if (!sameDavOrigin(Uri.parse(collection.requestUri), resolved) ||
      resolved.hasQuery ||
      resolved.hasFragment) {
    return null;
  }
  return resolved.replace(path: resolved.path.replaceFirst(RegExp(r'/+$'), ''));
}

Future<void> validateDavEventNativeMove({
  required AppDatabase database,
  required DavCollection source,
  required DavCollection destination,
  required String baseline,
  required String candidate,
}) async {
  if (!sameDavOrigin(
    Uri.parse(source.requestUri),
    Uri.parse(destination.requestUri),
  )) {
    throw schedulingDenied('DavMoveDifferentServer');
  }
  if ((davResourceHasSchedulingIdentity(baseline) ||
          davResourceHasSchedulingIdentity(candidate)) &&
      !await sameDavSchedulingIdentity(database, source, destination)) {
    throw schedulingDenied('DavMeetingMoveIdentityChanged');
  }
}

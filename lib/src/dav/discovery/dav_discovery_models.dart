import '../../providers/busy_provider.dart';
import '../../providers/provider_capabilities.dart';

const davCapabilitiesSchemaVersion = 1;
const davComponentEvent = 1 << 0;
const davComponentTodo = 1 << 1;
const davComponentTimezone = 1 << 2;
const davComponentJournal = 1 << 3;
const davComponentFreeBusy = 1 << 4;

enum DavCollectionKind {
  writableEventCalendar,
  readOnlyEventCalendar,
  writableTaskList,
  readOnlyTaskList,
  mixedCalendar,
  subscribedCalendar,
  schedulingInbox,
  schedulingOutbox,
  notifications,
  unsupported,
}

final class DavServiceDiscovery {
  const DavServiceDiscovery({
    required this.canonicalServiceUri,
    required this.canonicalOrigin,
    required this.principalHref,
    required this.calendarHomeHref,
    required this.calendarUserAddresses,
    required this.scheduleInboxHref,
    required this.scheduleOutboxHref,
    required this.capabilities,
    required this.discoveredAtUtc,
    required this.lastValidatedAtUtc,
    required this.providerProfileVersion,
  });

  final Uri canonicalServiceUri;
  final Uri canonicalOrigin;
  final Uri principalHref;
  final Uri calendarHomeHref;
  final List<Uri> calendarUserAddresses;
  final Uri? scheduleInboxHref;
  final Uri? scheduleOutboxHref;
  final AccountServiceCapabilities capabilities;
  final DateTime discoveredAtUtc;
  final DateTime lastValidatedAtUtc;
  final int providerProfileVersion;
}

final class DavCollectionDiscovery {
  const DavCollectionDiscovery({
    required this.hrefKey,
    required this.requestUri,
    required this.displayName,
    required this.description,
    required this.resourceTypes,
    required this.supportedComponentMask,
    required this.supportedCalendarData,
    required this.supportedReports,
    required this.currentUserPrivileges,
    required this.ownerHref,
    required this.safeDisplayMetadata,
    required this.color,
    required this.sortOrder,
    required this.calendarTimeZone,
    required this.calendarTimeZoneId,
    required this.scheduleTransparency,
    required this.maximumResourceSize,
    required this.maximumInstances,
    required this.syncToken,
    required this.ctag,
    required this.capabilities,
    required this.kind,
    required this.eventProjectionEnabled,
    required this.taskProjectionEnabled,
  });

  final String hrefKey;
  final Uri requestUri;
  final String displayName;
  final String? description;
  final Set<String> resourceTypes;
  final int supportedComponentMask;
  final List<Map<String, String>> supportedCalendarData;
  final Set<String> supportedReports;
  final Set<String> currentUserPrivileges;
  final String? ownerHref;
  final Map<String, String> safeDisplayMetadata;
  final String? color;
  final int? sortOrder;
  final String? calendarTimeZone;
  final String? calendarTimeZoneId;
  final String? scheduleTransparency;
  final int? maximumResourceSize;
  final int? maximumInstances;
  final String? syncToken;
  final String? ctag;
  final CollectionCapabilities capabilities;
  final DavCollectionKind kind;
  final bool eventProjectionEnabled;
  final bool taskProjectionEnabled;
}

final class DavDiscoveryResult {
  const DavDiscoveryResult({
    required this.accountId,
    required this.provider,
    required this.service,
    required this.collections,
  });

  final String accountId;
  final BusyProvider provider;
  final DavServiceDiscovery service;
  final List<DavCollectionDiscovery> collections;
}

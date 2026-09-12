import '../../providers/busy_provider.dart';
import '../../providers/provider_capabilities.dart';

const davCapabilitiesSchemaVersion = 2;
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
  trashBin,
  deletedCalendar,
  unsupported,
}

/// Each discovered identity retains its own home and scheduling context.
/// Delegation never replaces the authenticated principal or invents a path.
final class DavPrincipalContext {
  const DavPrincipalContext({
    required this.principalHref,
    required this.calendarHomeHref,
    this.calendarUserAddresses = const [],
    this.scheduleInboxHref,
    this.scheduleOutboxHref,
    this.scheduleDefaultCalendarHref,
    this.homePrivileges = const {},
    this.outboxPrivileges = const {},
    this.delegated = false,
  });
  final Uri principalHref;
  final Uri calendarHomeHref;
  final List<Uri> calendarUserAddresses;
  final Uri? scheduleInboxHref;
  final Uri? scheduleOutboxHref;
  final Uri? scheduleDefaultCalendarHref;
  final Set<String> homePrivileges;
  final Set<String> outboxPrivileges;
  final bool delegated;
  Map<String, Object?> toJson() => {
    'principalHref': principalHref.toString(),
    'calendarHomeHref': calendarHomeHref.toString(),
    'calendarUserAddresses': calendarUserAddresses
        .map((v) => v.toString())
        .toList(),
    'scheduleInboxHref': scheduleInboxHref?.toString(),
    'scheduleOutboxHref': scheduleOutboxHref?.toString(),
    'scheduleDefaultCalendarHref': scheduleDefaultCalendarHref?.toString(),
    'homePrivileges': homePrivileges.toList()..sort(),
    'outboxPrivileges': outboxPrivileges.toList()..sort(),
    'delegated': delegated,
  };
  factory DavPrincipalContext.fromJson(Map<String, Object?> value) =>
      DavPrincipalContext(
        principalHref: Uri.parse(value['principalHref']! as String),
        calendarHomeHref: Uri.parse(value['calendarHomeHref']! as String),
        calendarUserAddresses: (value['calendarUserAddresses'] as List? ?? [])
            .cast<String>()
            .map(Uri.parse)
            .toList(),
        scheduleInboxHref: value['scheduleInboxHref'] is String
            ? Uri.parse(value['scheduleInboxHref']! as String)
            : null,
        scheduleOutboxHref: value['scheduleOutboxHref'] is String
            ? Uri.parse(value['scheduleOutboxHref']! as String)
            : null,
        scheduleDefaultCalendarHref:
            value['scheduleDefaultCalendarHref'] is String
            ? Uri.parse(value['scheduleDefaultCalendarHref']! as String)
            : null,
        homePrivileges: (value['homePrivileges'] as List? ?? [])
            .cast<String>()
            .toSet(),
        outboxPrivileges: (value['outboxPrivileges'] as List? ?? [])
            .cast<String>()
            .toSet(),
        delegated: value['delegated'] == true,
      );
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
    this.principalContexts = const [],
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
  final List<DavPrincipalContext> principalContexts;
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
    this.principalHref,
    this.calendarHomeHref,
    this.delegated = false,
    this.parentPrivileges = const {},
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
  final Uri? principalHref;
  final Uri? calendarHomeHref;
  final bool delegated;
  final Set<String> parentPrivileges;
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

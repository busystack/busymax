import 'busy_provider.dart';

enum ProviderAuthenticationMethod {
  oauth,
  appleAppSpecificPassword,
  nextcloudLoginFlowV2,
}

enum ProviderServiceType { calendar, tasks }

class ProviderProfileCapabilities {
  const ProviderProfileCapabilities({
    required this.provider,
    required this.authenticationMethod,
    required this.expectedServices,
    this.allowsGenericServer = false,
    this.allowsInsecureHttp = false,
    this.allowsCalendarCollectionMutations = false,
    this.allowsTaskCollectionMutations = false,
    this.allowsSchedulingMutations = false,
  });

  final BusyProvider provider;
  final ProviderAuthenticationMethod authenticationMethod;
  final Set<ProviderServiceType> expectedServices;
  final bool allowsGenericServer;
  final bool allowsInsecureHttp;
  final bool allowsCalendarCollectionMutations;
  final bool allowsTaskCollectionMutations;
  final bool allowsSchedulingMutations;
}

const providerProfiles = <BusyProvider, ProviderProfileCapabilities>{
  BusyProvider.google: ProviderProfileCapabilities(
    provider: BusyProvider.google,
    authenticationMethod: ProviderAuthenticationMethod.oauth,
    expectedServices: {ProviderServiceType.calendar, ProviderServiceType.tasks},
    allowsCalendarCollectionMutations: true,
    allowsTaskCollectionMutations: true,
  ),
  BusyProvider.microsoft: ProviderProfileCapabilities(
    provider: BusyProvider.microsoft,
    authenticationMethod: ProviderAuthenticationMethod.oauth,
    expectedServices: {ProviderServiceType.calendar, ProviderServiceType.tasks},
    allowsCalendarCollectionMutations: true,
    allowsTaskCollectionMutations: true,
  ),
  BusyProvider.appleICloud: ProviderProfileCapabilities(
    provider: BusyProvider.appleICloud,
    authenticationMethod: ProviderAuthenticationMethod.appleAppSpecificPassword,
    expectedServices: {ProviderServiceType.calendar},
  ),
  BusyProvider.nextcloud: ProviderProfileCapabilities(
    provider: BusyProvider.nextcloud,
    authenticationMethod: ProviderAuthenticationMethod.nextcloudLoginFlowV2,
    expectedServices: {ProviderServiceType.calendar, ProviderServiceType.tasks},
    allowsTaskCollectionMutations: true,
  ),
};

class AccountServiceCapabilities {
  const AccountServiceCapabilities({
    this.hasPrincipal = false,
    this.hasCalendarHome = false,
    this.hasSchedulingInbox = false,
    this.hasSchedulingOutbox = false,
    this.supportedReports = const {},
    this.serverFeatures = const {},
  });

  final bool hasPrincipal;
  final bool hasCalendarHome;
  final bool hasSchedulingInbox;
  final bool hasSchedulingOutbox;
  final Set<String> supportedReports;
  final Set<String> serverFeatures;
}

class CollectionCapabilities {
  const CollectionCapabilities({
    this.canRead = false,
    this.canReadPrivileges = false,
    this.canWriteContent = false,
    this.canWriteProperties = false,
    this.canAddMembers = false,
    this.canDeleteMembers = false,
    this.canReadFreeBusy = false,
    this.supportsEvents = false,
    this.supportsTasks = false,
    this.supportsSyncCollection = false,
    this.supportsCalendarMultiget = false,
    this.supportsCalendarQuery = false,
    this.supportedCalendarData = const {},
    this.maximumResourceSize,
    this.maximumInstances,
    this.providerAllowsCollectionMutation = false,
    this.providerAllowsSchedulingMutation = false,
  });

  final bool canRead;
  final bool canReadPrivileges;
  final bool canWriteContent;
  final bool canWriteProperties;
  final bool canAddMembers;
  final bool canDeleteMembers;
  final bool canReadFreeBusy;
  final bool supportsEvents;
  final bool supportsTasks;
  final bool supportsSyncCollection;
  final bool supportsCalendarMultiget;
  final bool supportsCalendarQuery;
  final Set<String> supportedCalendarData;
  final int? maximumResourceSize;
  final int? maximumInstances;
  final bool providerAllowsCollectionMutation;
  final bool providerAllowsSchedulingMutation;

  bool get isReadOnly => !canWriteContent;
  bool get canCreateEvent => supportsEvents && canWriteContent && canAddMembers;
  bool get canUpdateEvent => supportsEvents && canWriteContent;
  bool get canDeleteEvent =>
      supportsEvents && canWriteContent && canDeleteMembers;
  bool get canCreateTask => supportsTasks && canWriteContent && canAddMembers;
  bool get canUpdateTask => supportsTasks && canWriteContent;
  bool get canDeleteTask =>
      supportsTasks && canWriteContent && canDeleteMembers;
  bool get canMutateCollection =>
      providerAllowsCollectionMutation && canWriteProperties;
  bool get canSchedule =>
      providerAllowsSchedulingMutation && canWriteContent && canReadFreeBusy;
}

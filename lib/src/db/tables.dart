import 'package:drift/drift.dart';

class Accounts extends Table {
  TextColumn get id => text()();
  TextColumn get provider => text()();
  TextColumn get authority => text()();
  TextColumn get providerAccountId => text()();
  TextColumn get credentialKind => text()();
  IntColumn get providerProfileVersion =>
      integer().withDefault(const Constant(1))();
  TextColumn get displayName => text().nullable()();
  TextColumn get email => text().nullable()();
  TextColumn get tenantId => text().nullable()();
  TextColumn get accountAvatarUrl => text().nullable()();
  TextColumn get providerMetadataJson => text().nullable()();
  TextColumn get authState =>
      text().withDefault(const Constant('signed_out'))();
  BoolColumn get calendarsEnabled =>
      boolean().withDefault(const Constant(true))();
  BoolColumn get tasksEnabled => boolean().withDefault(const Constant(true))();
  TextColumn get grantedScopes => text().withDefault(const Constant(''))();
  TextColumn get createdAtUtc => text()();
  TextColumn get updatedAtUtc => text()();
  TextColumn get lastSuccessfulSyncAtUtc => text().nullable()();
  TextColumn get lastFullSyncAtUtc => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  List<String> get customConstraints => const [
    "CHECK (provider IN ('google', 'microsoft', 'apple_icloud', 'nextcloud', "
        "'webcal'))",
    "CHECK (credential_kind IN ('oauth', 'apple_app_specific_password', "
        "'nextcloud_app_password', 'webcal_subscription'))",
    "CHECK ((provider IN ('google', 'microsoft') AND credential_kind = 'oauth') "
        "OR (provider = 'apple_icloud' AND credential_kind = "
        "'apple_app_specific_password') "
        "OR (provider = 'nextcloud' AND credential_kind = "
        "'nextcloud_app_password') "
        "OR (provider = 'webcal' AND credential_kind = "
        "'webcal_subscription'))",
    'CHECK (length(trim(authority)) > 0)',
    'CHECK (length(trim(provider_account_id)) > 0)',
  ];
}

class DavAccountServices extends Table {
  TextColumn get accountId =>
      text().references(Accounts, #id, onDelete: KeyAction.cascade)();
  TextColumn get canonicalServiceUri => text()();
  TextColumn get canonicalOrigin => text()();
  TextColumn get principalHref => text().nullable()();
  TextColumn get calendarHomeHref => text().nullable()();
  TextColumn get calendarUserAddressesJson =>
      text().withDefault(const Constant('[]'))();
  TextColumn get scheduleInboxHref => text().nullable()();
  TextColumn get scheduleOutboxHref => text().nullable()();
  TextColumn get capabilitiesJson => text().withDefault(const Constant('{}'))();
  IntColumn get capabilitiesSchemaVersion =>
      integer().withDefault(const Constant(1))();
  IntColumn get providerProfileVersion =>
      integer().withDefault(const Constant(1))();
  TextColumn get discoveredAtUtc => text()();
  TextColumn get lastValidatedAtUtc => text().nullable()();
  TextColumn get lastDiscoveryErrorCode => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {accountId};
}

class DavCollections extends Table {
  TextColumn get id => text()();
  TextColumn get accountId =>
      text().references(Accounts, #id, onDelete: KeyAction.cascade)();
  TextColumn get hrefKey => text()();
  TextColumn get requestUri => text()();
  TextColumn get displayName => text()();
  TextColumn get description => text().nullable()();
  TextColumn get resourceTypesJson =>
      text().withDefault(const Constant('[]'))();
  IntColumn get supportedComponentMask =>
      integer().withDefault(const Constant(0))();
  TextColumn get supportedCalendarDataJson =>
      text().withDefault(const Constant('[]'))();
  TextColumn get supportedReportsJson =>
      text().withDefault(const Constant('[]'))();
  TextColumn get currentUserPrivilegesJson =>
      text().withDefault(const Constant('[]'))();
  TextColumn get ownerHref => text().nullable()();
  TextColumn get safeDisplayMetadataJson => text().nullable()();
  TextColumn get color => text().nullable()();
  IntColumn get sortOrder => integer().nullable()();
  TextColumn get calendarTimeZone => text().nullable()();
  TextColumn get calendarTimeZoneId => text().nullable()();
  TextColumn get scheduleTransparency => text().nullable()();
  IntColumn get maximumResourceSize => integer().nullable()();
  IntColumn get maximumInstances => integer().nullable()();
  TextColumn get syncToken => text().nullable()();
  TextColumn get ctag => text().nullable()();
  BoolColumn get readOnly => boolean().withDefault(const Constant(true))();
  BoolColumn get eventProjectionEnabled =>
      boolean().withDefault(const Constant(false))();
  BoolColumn get taskProjectionEnabled =>
      boolean().withDefault(const Constant(false))();
  BoolColumn get eventsSelected =>
      boolean().withDefault(const Constant(true))();
  BoolColumn get tasksSelected => boolean().withDefault(const Constant(true))();
  BoolColumn get serverMissing =>
      boolean().withDefault(const Constant(false))();
  BoolColumn get deleted => boolean().withDefault(const Constant(false))();
  TextColumn get lastInventoryAtUtc => text().nullable()();
  TextColumn get lastSyncAtUtc => text().nullable()();
  IntColumn get parserVersion => integer().withDefault(const Constant(1))();
  IntColumn get projectionVersion => integer().withDefault(const Constant(1))();
  TextColumn get createdAtUtc => text()();
  TextColumn get updatedAtUtc => text()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class DavObjects extends Table {
  TextColumn get id => text()();
  TextColumn get accountId =>
      text().references(Accounts, #id, onDelete: KeyAction.cascade)();
  TextColumn get collectionId =>
      text().references(DavCollections, #id, onDelete: KeyAction.cascade)();
  TextColumn get hrefKey => text()();
  TextColumn get requestUri => text()();
  TextColumn get etag => text().nullable()();
  TextColumn get contentType => text().nullable()();
  TextColumn get dominantComponentType => text().nullable()();
  IntColumn get componentMask => integer().withDefault(const Constant(0))();
  TextColumn get primaryUid => text().nullable()();
  TextColumn get rawIcsBody => text()();
  TextColumn get rawBodyHash => text()();
  TextColumn get semanticHash => text().nullable()();
  BoolColumn get serverDeleted =>
      boolean().withDefault(const Constant(false))();
  IntColumn get baselineGeneration =>
      integer().withDefault(const Constant(0))();
  TextColumn get firstSeenAtUtc => text()();
  TextColumn get lastFetchedAtUtc => text()();
  TextColumn get lastChangedAtUtc => text()();
  TextColumn get lastParseStatus =>
      text().withDefault(const Constant('unparsed'))();
  TextColumn get lastParseErrorCode => text().nullable()();
  IntColumn get parserVersion => integer().withDefault(const Constant(1))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class DavObjectComponents extends Table {
  TextColumn get id => text()();
  TextColumn get davObjectId =>
      text().references(DavObjects, #id, onDelete: KeyAction.cascade)();
  TextColumn get componentType => text()();
  TextColumn get uid => text()();
  TextColumn get recurrenceIdKey => text().nullable()();
  IntColumn get sequence => integer().nullable()();
  TextColumn get dtstampUtc => text().nullable()();
  TextColumn get lastModifiedUtc => text().nullable()();
  TextColumn get semanticHash => text()();
  IntColumn get parserProfileVersion =>
      integer().withDefault(const Constant(1))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class DavConflictSnapshots extends Table {
  TextColumn get id => text()();
  TextColumn get accountId =>
      text().references(Accounts, #id, onDelete: KeyAction.cascade)();
  TextColumn get davCollectionId => text().nullable().references(
    DavCollections,
    #id,
    onDelete: KeyAction.setNull,
  )();
  TextColumn get davObjectId => text().nullable().references(
    DavObjects,
    #id,
    onDelete: KeyAction.setNull,
  )();
  TextColumn get baselineEtag => text().nullable()();
  TextColumn get baselineRawIcs => text()();
  TextColumn get localCandidateRawIcs => text()();
  TextColumn get remoteEtag => text().nullable()();
  TextColumn get remoteRawIcs => text()();
  TextColumn get conflictCode => text()();
  TextColumn get createdAtUtc => text()();
  TextColumn get resolvedAtUtc => text().nullable()();
  TextColumn get resolution => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class TaskLists extends Table {
  TextColumn get accountId =>
      text().references(Accounts, #id, onDelete: KeyAction.cascade)();
  TextColumn get id => text()();
  TextColumn get davCollectionId => text().nullable().references(
    DavCollections,
    #id,
    onDelete: KeyAction.setNull,
  )();
  TextColumn get kind => text().nullable()();
  TextColumn get etag => text().nullable()();
  TextColumn get title => text()();
  TextColumn get updatedUtc => text().nullable()();
  TextColumn get selfLink => text().nullable()();
  TextColumn get rawJson => text()();
  TextColumn get providerListKind => text().nullable()();
  BoolColumn get isOwner => boolean().nullable()();
  BoolColumn get isShared => boolean().nullable()();
  TextColumn get deltaLink => text().nullable()();
  TextColumn get providerMetadataJson => text().nullable()();
  BoolColumn get serverMissing =>
      boolean().withDefault(const Constant(false))();
  BoolColumn get localDirty => boolean().withDefault(const Constant(false))();
  BoolColumn get pendingDelete =>
      boolean().withDefault(const Constant(false))();
  BoolColumn get remindersEnabled =>
      boolean().withDefault(const Constant(true))();
  TextColumn get lastSyncedAtUtc => text().nullable()();
  TextColumn get createdLocalAtUtc => text()();
  TextColumn get updatedLocalAtUtc => text()();

  @override
  Set<Column<Object>> get primaryKey => {accountId, id};
}

class Tasks extends Table {
  TextColumn get accountId =>
      text().references(Accounts, #id, onDelete: KeyAction.cascade)();
  TextColumn get taskListId => text()();
  TextColumn get id => text()();
  TextColumn get davCollectionId => text().nullable().references(
    DavCollections,
    #id,
    onDelete: KeyAction.setNull,
  )();
  TextColumn get davObjectId => text().nullable().references(
    DavObjects,
    #id,
    onDelete: KeyAction.setNull,
  )();
  TextColumn get davComponentId => text().nullable().references(
    DavObjectComponents,
    #id,
    onDelete: KeyAction.setNull,
  )();
  TextColumn get icalUid => text().nullable()();
  TextColumn get recurrenceIdKey => text().nullable()();
  IntColumn get icalPriority => integer().nullable()();
  IntColumn get percentComplete => integer().nullable()();
  TextColumn get taskLocation => text().nullable()();
  TextColumn get taskUrl => text().nullable()();
  TextColumn get taskClassification => text().nullable()();
  BoolColumn get taskPinned => boolean().nullable()();
  BoolColumn get taskHideSubtasks => boolean().nullable()();
  BoolColumn get taskHideCompletedSubtasks => boolean().nullable()();
  TextColumn get taskAlarmsJson => text().nullable()();
  TextColumn get parentUid => text().nullable()();
  IntColumn get sortOrder => integer().nullable()();
  TextColumn get providerExtensionProjectionJson => text().nullable()();
  IntColumn get projectionVersion => integer().withDefault(const Constant(1))();
  TextColumn get kind => text().nullable()();
  TextColumn get etag => text().nullable()();
  TextColumn get title => text()();
  TextColumn get updatedUtc => text().nullable()();
  TextColumn get selfLink => text().nullable()();
  TextColumn get parent => text().nullable()();
  TextColumn get position => text().nullable()();
  TextColumn get notes => text().nullable()();
  TextColumn get status => text().nullable()();
  TextColumn get dueUtc => text().nullable()();
  TextColumn get completedUtc => text().nullable()();
  TextColumn get providerStatus => text().nullable()();
  TextColumn get bodyContent => text().nullable()();
  TextColumn get bodyContentType => text().nullable()();
  TextColumn get microsoftDueDateTime => text().nullable()();
  TextColumn get microsoftDueTimeZone => text().nullable()();
  TextColumn get microsoftStartDateTime => text().nullable()();
  TextColumn get microsoftStartTimeZone => text().nullable()();
  TextColumn get microsoftReminderDateTime => text().nullable()();
  TextColumn get microsoftReminderTimeZone => text().nullable()();
  BoolColumn get microsoftIsReminderOn => boolean().nullable()();
  TextColumn get microsoftCompletedDateTime => text().nullable()();
  TextColumn get microsoftCompletedTimeZone => text().nullable()();
  TextColumn get microsoftChecklistItemsJson => text().nullable()();
  TextColumn get recurrenceJson => text().nullable()();
  TextColumn get importance => text().nullable()();
  TextColumn get categoriesJson => text().nullable()();
  BoolColumn get hasAttachments => boolean().nullable()();
  TextColumn get providerMetadataJson => text().nullable()();
  BoolColumn get deleted => boolean().nullable()();
  BoolColumn get hidden => boolean().nullable()();
  TextColumn get linksJson => text().nullable()();
  TextColumn get webViewLink => text().nullable()();
  TextColumn get assignmentInfoJson => text().nullable()();
  TextColumn get rawJson => text()();
  BoolColumn get serverMissing =>
      boolean().withDefault(const Constant(false))();
  BoolColumn get localDirty => boolean().withDefault(const Constant(false))();
  BoolColumn get pendingDelete =>
      boolean().withDefault(const Constant(false))();
  BoolColumn get pendingMove => boolean().withDefault(const Constant(false))();
  BoolColumn get localCreated => boolean().withDefault(const Constant(false))();
  TextColumn get syncBaseUpdatedUtc => text().nullable()();
  TextColumn get lastSyncedAtUtc => text().nullable()();
  TextColumn get createdLocalAtUtc => text()();
  TextColumn get updatedLocalAtUtc => text()();

  @override
  Set<Column<Object>> get primaryKey => {accountId, taskListId, id};

  @override
  List<String> get customConstraints => [
    'FOREIGN KEY(account_id, task_list_id) '
        'REFERENCES task_lists(account_id, id) ON DELETE CASCADE',
  ];
}

class PendingOps extends Table {
  TextColumn get id => text()();
  TextColumn get accountId =>
      text().references(Accounts, #id, onDelete: KeyAction.cascade)();
  TextColumn get provider => text().nullable()();
  TextColumn get entityType => text()();
  TextColumn get operation => text()();
  TextColumn get operationType => text().nullable()();
  TextColumn get taskListId => text().nullable()();
  TextColumn get taskId => text().nullable()();
  TextColumn get calendarSourceId => text().nullable()();
  TextColumn get providerCalendarId => text().nullable()();
  TextColumn get eventId => text().nullable()();
  TextColumn get davCollectionId => text().nullable().references(
    DavCollections,
    #id,
    onDelete: KeyAction.setNull,
  )();
  TextColumn get davCollectionHref => text().nullable()();
  TextColumn get davObjectId => text().nullable().references(
    DavObjects,
    #id,
    onDelete: KeyAction.setNull,
  )();
  TextColumn get davMemberHref => text().nullable()();
  TextColumn get baselineEtag => text().nullable()();
  TextColumn get baselineRawIcs => text().nullable()();
  TextColumn get mutationPatchJson => text().nullable()();
  IntColumn get mutationPatchSchemaVersion => integer().nullable()();
  TextColumn get targetComponentKey => text().nullable()();
  TextColumn get mutationScope => text().nullable()();
  TextColumn get destinationCollectionId => text().nullable().references(
    DavCollections,
    #id,
    onDelete: KeyAction.setNull,
  )();
  TextColumn get destinationCollectionHref => text().nullable()();
  TextColumn get destinationMemberHref => text().nullable()();
  TextColumn get conflictState => text().nullable()();
  TextColumn get conflictSnapshotId => text().nullable().references(
    DavConflictSnapshots,
    #id,
    onDelete: KeyAction.setNull,
  )();
  TextColumn get retryClassification => text().nullable()();
  TextColumn get localTempId => text().nullable()();
  TextColumn get dependsOnOpId => text().nullable()();
  TextColumn get requestJson => text()();
  TextColumn get baselineUpdatedUtc => text().nullable()();
  TextColumn get baselineRawJson => text().nullable()();
  IntColumn get attemptCount => integer().withDefault(const Constant(0))();
  TextColumn get nextAttemptAtUtc => text().nullable()();
  TextColumn get lastErrorCode => text().nullable()();
  TextColumn get lastErrorMessage => text().nullable()();
  TextColumn get state => text().withDefault(const Constant('pending'))();
  TextColumn get lastError => text().nullable()();
  TextColumn get createdAtUtc => text()();
  TextColumn get updatedAtUtc => text()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class CalendarSources extends Table {
  TextColumn get id => text()();
  TextColumn get accountId =>
      text().references(Accounts, #id, onDelete: KeyAction.cascade)();
  TextColumn get provider => text()();
  TextColumn get providerCalendarId => text()();
  TextColumn get davCollectionId => text().nullable().references(
    DavCollections,
    #id,
    onDelete: KeyAction.setNull,
  )();
  TextColumn get summary => text()();
  TextColumn get description => text().nullable()();
  BoolColumn get primaryCalendar =>
      boolean().withDefault(const Constant(false))();
  BoolColumn get selected => boolean().withDefault(const Constant(true))();
  BoolColumn get remindersEnabled =>
      boolean().withDefault(const Constant(true))();
  BoolColumn get hidden => boolean().withDefault(const Constant(false))();
  BoolColumn get readOnly => boolean().withDefault(const Constant(false))();
  TextColumn get backgroundColor => text().nullable()();
  TextColumn get foregroundColor => text().nullable()();
  TextColumn get colorId => text().nullable()();
  TextColumn get timeZone => text().nullable()();
  TextColumn get accessRole => text().nullable()();
  TextColumn get dataOwner => text().nullable()();
  BoolColumn get isRemovable => boolean().nullable()();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
  TextColumn get rawJson => text().nullable()();
  IntColumn get createdAtLocal => integer()();
  IntColumn get updatedAtLocal => integer()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class CalendarEvents extends Table {
  TextColumn get id => text()();
  TextColumn get accountId =>
      text().references(Accounts, #id, onDelete: KeyAction.cascade)();
  TextColumn get calendarSourceId =>
      text().references(CalendarSources, #id, onDelete: KeyAction.cascade)();
  TextColumn get provider => text()();
  TextColumn get providerCalendarId => text()();
  TextColumn get providerEventId => text()();
  TextColumn get davCollectionId => text().nullable().references(
    DavCollections,
    #id,
    onDelete: KeyAction.setNull,
  )();
  TextColumn get davObjectId => text().nullable().references(
    DavObjects,
    #id,
    onDelete: KeyAction.setNull,
  )();
  TextColumn get davComponentId => text().nullable().references(
    DavObjectComponents,
    #id,
    onDelete: KeyAction.setNull,
  )();
  TextColumn get icalUid => text().nullable()();
  TextColumn get recurrenceIdKey => text().nullable()();
  TextColumn get occurrenceKey => text().nullable()();
  IntColumn get projectionVersion => integer().withDefault(const Constant(1))();
  TextColumn get providerRecurringEventId => text().nullable()();
  TextColumn get providerOriginalStartKey => text().nullable()();
  TextColumn get etagOrChangeKey => text().nullable()();
  TextColumn get status => text().nullable()();
  TextColumn get title => text()();
  TextColumn get description => text().nullable()();
  TextColumn get location => text().nullable()();
  BoolColumn get allDay => boolean().withDefault(const Constant(false))();
  TextColumn get startDate => text().nullable()();
  TextColumn get startDateTime => text().nullable()();
  TextColumn get startTimeZone => text().nullable()();
  TextColumn get endDate => text().nullable()();
  TextColumn get endDateTime => text().nullable()();
  TextColumn get endTimeZone => text().nullable()();
  TextColumn get recurrenceJson => text().nullable()();
  TextColumn get remindersJson => text().nullable()();
  TextColumn get attendeesJson => text().nullable()();
  TextColumn get categoriesJson => text().nullable()();
  TextColumn get organizerJson => text().nullable()();
  TextColumn get creatorJson => text().nullable()();
  TextColumn get colorId => text().nullable()();
  TextColumn get colorHex => text().nullable()();
  TextColumn get visibility => text().nullable()();
  TextColumn get transparencyOrShowAs => text().nullable()();
  TextColumn get eventType => text().nullable()();
  TextColumn get webLink => text().nullable()();
  TextColumn get conferenceJson => text().nullable()();
  TextColumn get attachmentsJson => text().nullable()();
  BoolColumn get isCancelled => boolean().withDefault(const Constant(false))();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
  TextColumn get rawJson => text().nullable()();
  TextColumn get createdAtServer => text().nullable()();
  TextColumn get updatedAtServer => text().nullable()();
  IntColumn get createdAtLocal => integer()();
  IntColumn get updatedAtLocal => integer()();
  TextColumn get syncStatus => text().withDefault(const Constant('synced'))();
  TextColumn get baselineRawJson => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class IcalImportReceipts extends Table {
  TextColumn get calendarSourceId =>
      text().references(CalendarSources, #id, onDelete: KeyAction.cascade)();
  TextColumn get icalUid => text()();
  TextColumn get eventId => text().nullable()();
  TextColumn get importedAtUtc => text()();

  @override
  Set<Column<Object>> get primaryKey => {calendarSourceId, icalUid};
}

class WebCalSubscriptions extends Table {
  TextColumn get id => text()();
  TextColumn get accountId =>
      text().references(Accounts, #id, onDelete: KeyAction.cascade)();
  TextColumn get calendarSourceId =>
      text().references(CalendarSources, #id, onDelete: KeyAction.cascade)();
  TextColumn get feedFingerprint => text().unique()();
  TextColumn get safeOrigin => text()();
  TextColumn get validatorTargetFingerprint => text().nullable()();
  TextColumn get etag => text().nullable()();
  TextColumn get lastModified => text().nullable()();
  TextColumn get contentType => text().nullable()();
  TextColumn get snapshotIcsBody => text()();
  TextColumn get rawBodyHash => text()();
  TextColumn get semanticHash => text()();
  TextColumn get refreshMode => text()();
  IntColumn get serverRefreshIntervalSeconds => integer().nullable()();
  TextColumn get nextRefreshAtUtc => text()();
  TextColumn get lastCheckedAtUtc => text().nullable()();
  TextColumn get lastSuccessfulSyncAtUtc => text().nullable()();
  TextColumn get lastChangedAtUtc => text().nullable()();
  IntColumn get consecutiveFailureCount =>
      integer().withDefault(const Constant(0))();
  TextColumn get lastFailureCode => text().nullable()();
  IntColumn get lastFailureHttpStatus => integer().nullable()();
  IntColumn get generation => integer().withDefault(const Constant(1))();
  IntColumn get parserVersion => integer().withDefault(const Constant(1))();
  IntColumn get projectionVersion => integer().withDefault(const Constant(1))();
  TextColumn get projectionRangeStartUtc => text().nullable()();
  TextColumn get projectionRangeEndUtc => text().nullable()();
  TextColumn get createdAtUtc => text()();
  TextColumn get updatedAtUtc => text()();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {accountId},
    {calendarSourceId},
  ];
}

class CalendarEventAttendees extends Table {
  TextColumn get id => text()();
  TextColumn get calendarEventId =>
      text().references(CalendarEvents, #id, onDelete: KeyAction.cascade)();
  TextColumn get email => text()();
  TextColumn get displayName => text().nullable()();
  TextColumn get responseStatus => text().nullable()();
  BoolColumn get optional => boolean().withDefault(const Constant(false))();
  BoolColumn get organizer => boolean().withDefault(const Constant(false))();
  BoolColumn get self => boolean().withDefault(const Constant(false))();
  TextColumn get rawJson => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class CalendarEventReminders extends Table {
  TextColumn get id => text()();
  TextColumn get calendarEventId =>
      text().references(CalendarEvents, #id, onDelete: KeyAction.cascade)();
  TextColumn get provider => text()();
  TextColumn get method => text().nullable()();
  IntColumn get minutesBefore => integer().nullable()();
  TextColumn get absoluteTime => text().nullable()();
  BoolColumn get enabled => boolean().withDefault(const Constant(true))();
  TextColumn get rawJson => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class SyncCursors extends Table {
  TextColumn get id => text()();
  TextColumn get accountId =>
      text().references(Accounts, #id, onDelete: KeyAction.cascade)();
  TextColumn get projectionSourceId => text().nullable().references(
    CalendarSources,
    #id,
    onDelete: KeyAction.cascade,
  )();
  TextColumn get provider => text()();
  TextColumn get transport => text()();
  TextColumn get syncScopeKind => text()();
  TextColumn get davCollectionId => text().nullable().references(
    DavCollections,
    #id,
    onDelete: KeyAction.cascade,
  )();
  TextColumn get cursorKind => text()();
  TextColumn get cursorValue => text()();
  TextColumn get rangeStart => text().nullable()();
  TextColumn get rangeEnd => text().nullable()();
  IntColumn get baselineGeneration =>
      integer().withDefault(const Constant(0))();
  TextColumn get inProgressCursor => text().nullable()();
  IntColumn get inProgressGeneration => integer().nullable()();
  IntColumn get lastCompleteSyncAt => integer().nullable()();
  TextColumn get lastFailureCode => text().nullable()();
  IntColumn get stateSchemaVersion =>
      integer().withDefault(const Constant(1))();
  TextColumn get stateJson => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class CalendarColors extends Table {
  TextColumn get provider => text()();
  TextColumn get colorType => text()();
  TextColumn get colorId => text()();
  TextColumn get background => text()();
  TextColumn get foreground => text().nullable()();
  TextColumn get rawJson => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {provider, colorType, colorId};
}

class ScheduleItemOverrides extends Table {
  TextColumn get id => text()();
  TextColumn get accountId =>
      text().references(Accounts, #id, onDelete: KeyAction.cascade)();
  TextColumn get sourceType => text()();
  TextColumn get sourceId => text()();
  TextColumn get overrideJson => text()();
  IntColumn get createdAtLocal => integer()();
  IntColumn get updatedAtLocal => integer()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class NotificationSchedule extends Table {
  TextColumn get id => text()();
  TextColumn get accountId =>
      text().references(Accounts, #id, onDelete: KeyAction.cascade)();
  TextColumn get sourceType => text()();
  TextColumn get sourceId => text()();
  IntColumn get scheduledAtUtc => integer()();
  TextColumn get title => text()();
  TextColumn get body => text().nullable()();
  IntColumn get sentAtUtc => integer().nullable()();
  IntColumn get dismissedAtUtc => integer().nullable()();
  IntColumn get snoozedUntilUtc => integer().nullable()();
  IntColumn get createdAtLocal => integer()();
  IntColumn get updatedAtLocal => integer()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class SyncRuns extends Table {
  TextColumn get id => text()();
  TextColumn get accountId =>
      text().references(Accounts, #id, onDelete: KeyAction.cascade)();
  TextColumn get provider => text().nullable()();
  TextColumn get mode => text()();
  TextColumn get startedAtUtc => text()();
  TextColumn get finishedAtUtc => text().nullable()();
  TextColumn get status => text()();
  IntColumn get taskListsSeen => integer().withDefault(const Constant(0))();
  IntColumn get tasksSeen => integer().withDefault(const Constant(0))();
  IntColumn get pendingOpsApplied => integer().withDefault(const Constant(0))();
  TextColumn get errorCode => text().nullable()();
  TextColumn get errorMessage => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

import 'package:drift/drift.dart';

class Accounts extends Table {
  TextColumn get id => text()();
  TextColumn get provider => text().withDefault(const Constant('google'))();
  TextColumn get providerAccountId => text().nullable()();
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
}

class TaskLists extends Table {
  TextColumn get accountId =>
      text().references(Accounts, #id, onDelete: KeyAction.cascade)();
  TextColumn get id => text()();
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
  TextColumn get summary => text()();
  TextColumn get description => text().nullable()();
  BoolColumn get primaryCalendar =>
      boolean().withDefault(const Constant(false))();
  BoolColumn get selected => boolean().withDefault(const Constant(true))();
  BoolColumn get hidden => boolean().withDefault(const Constant(false))();
  BoolColumn get readOnly => boolean().withDefault(const Constant(false))();
  TextColumn get backgroundColor => text().nullable()();
  TextColumn get foregroundColor => text().nullable()();
  TextColumn get colorId => text().nullable()();
  TextColumn get timeZone => text().nullable()();
  TextColumn get accessRole => text().nullable()();
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

class CalendarSyncStates extends Table {
  TextColumn get id => text()();
  TextColumn get accountId =>
      text().references(Accounts, #id, onDelete: KeyAction.cascade)();
  TextColumn get calendarSourceId => text().nullable().references(
    CalendarSources,
    #id,
    onDelete: KeyAction.cascade,
  )();
  TextColumn get provider => text()();
  TextColumn get syncKind => text()();
  TextColumn get rangeStart => text().nullable()();
  TextColumn get rangeEnd => text().nullable()();
  TextColumn get googleSyncToken => text().nullable()();
  TextColumn get microsoftDeltaLink => text().nullable()();
  IntColumn get lastFullSyncAt => integer().nullable()();
  IntColumn get lastIncrementalSyncAt => integer().nullable()();
  TextColumn get lastError => text().nullable()();
  TextColumn get rawStateJson => text().nullable()();

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

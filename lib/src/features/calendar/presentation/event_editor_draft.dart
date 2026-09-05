import '../../../core/time/provider_date_time.dart';
import '../../../providers/busy_provider.dart';
import '../data/calendar_event_detail.dart';

enum RecurringEventMutationScope {
  entireSeries,
  singleOccurrence,
  thisAndFuture,
}

bool supportsThisAndFollowingEventMutation(BusyProvider provider) =>
    provider != BusyProvider.microsoft;

class EventAttendeeDraft {
  const EventAttendeeDraft({
    required this.email,
    this.displayName,
    this.optional = false,
    this.self = false,
    this.organizer = false,
    this.responseStatus,
  });

  factory EventAttendeeDraft.fromJson(Map<String, Object?> json) {
    final emailAddress = switch (json['emailAddress']) {
      final Map value => value.cast<String, Object?>(),
      _ => const <String, Object?>{},
    };
    final email = json['email']?.toString();
    final address =
        json['address']?.toString() ?? emailAddress['address']?.toString();
    return EventAttendeeDraft(
      email: (email == null || email.isEmpty) ? address ?? '' : email,
      displayName:
          json['displayName']?.toString() ??
          json['name']?.toString() ??
          emailAddress['name']?.toString(),
      optional:
          json['optional'] == true ||
          json['type']?.toString().toLowerCase() == 'optional',
      self: json['self'] == true,
      organizer: json['organizer'] == true,
      responseStatus:
          json['responseStatus']?.toString() ??
          switch (json['status']) {
            final Map value => value['response']?.toString(),
            _ => null,
          },
    );
  }

  final String email;
  final String? displayName;
  final bool optional;
  final bool self;
  final bool organizer;
  final String? responseStatus;

  Map<String, Object?> toGoogleJson() {
    return {
      'email': email,
      if (displayName != null && displayName!.isNotEmpty)
        'displayName': displayName,
      if (optional) 'optional': true,
      if (responseStatus != null && responseStatus!.isNotEmpty)
        'responseStatus': responseStatus,
    };
  }

  Map<String, Object?> toMicrosoftJson() {
    return {
      'emailAddress': {
        'address': email,
        if (displayName != null && displayName!.isNotEmpty) 'name': displayName,
      },
      'type': optional ? 'optional' : 'required',
    };
  }

  @override
  bool operator ==(Object other) {
    return other is EventAttendeeDraft &&
        other.email == email &&
        other.displayName == displayName &&
        other.optional == optional &&
        other.self == self &&
        other.organizer == organizer &&
        other.responseStatus == responseStatus;
  }

  @override
  int get hashCode => Object.hash(
    email,
    displayName,
    optional,
    self,
    organizer,
    responseStatus,
  );
}

class EventEditorDraft {
  const EventEditorDraft({
    required this.accountId,
    required this.sourceId,
    required this.providerCalendarId,
    required this.title,
    required this.allDay,
    this.eventId,
    this.originalDetail,
    this.providerRecurringEventId,
    this.eventType,
    this.recurringMutationScope,
    this.start,
    this.end,
    this.startTimeZone,
    this.endTimeZone,
    this.location,
    this.description,
    this.descriptionContentType,
    this.descriptionHtml,
    this.recurrence,
    this.recurrenceChanged = false,
    this.reminders,
    this.remindersChanged = false,
    this.attendees = const [],
    this.attendeesChanged = false,
    this.importance,
    this.showAs,
    this.visibilityOrSensitivity,
    this.colorId,
    this.categories = const [],
    this.categoriesChanged = false,
    this.createConference = false,
    this.conference,
    this.responseRequested,
    this.hideAttendees,
    this.allowNewTimeProposals,
    this.isOrganizer,
    this.canManageAttendees = true,
  });

  factory EventEditorDraft.newEvent({
    required String accountId,
    required String sourceId,
    required String providerCalendarId,
    required DateTime start,
    required DateTime end,
  }) {
    return EventEditorDraft(
      accountId: accountId,
      sourceId: sourceId,
      providerCalendarId: providerCalendarId,
      title: '',
      allDay: false,
      start: start,
      end: end,
      isOrganizer: true,
    );
  }

  factory EventEditorDraft.fromEventDetail(CalendarEventDetail detail) {
    final raw = _jsonMap(detail.raw);
    final organizer = _jsonMapOrNull(detail.organizer);
    final body = detail.provider == BusyProvider.microsoft
        ? _jsonMapOrNull(raw['body'])
        : null;
    final descriptionContentType = body?['contentType']?.toString();
    final descriptionHtml = descriptionContentType?.toLowerCase() == 'html'
        ? (body?['content']?.toString())
        : null;
    final isOrganizer = switch (detail.provider) {
      BusyProvider.google => _jsonBool(organizer?['self']),
      BusyProvider.microsoft => _jsonBool(raw['isOrganizer']),
      BusyProvider.appleICloud ||
      BusyProvider.nextcloud ||
      BusyProvider.webCal => null,
    };
    final hideAttendees = switch (detail.provider) {
      BusyProvider.google =>
        raw['guestsCanSeeOtherGuests'] is bool
            ? !(raw['guestsCanSeeOtherGuests'] as bool)
            : null,
      BusyProvider.microsoft => _jsonBool(raw['hideAttendees']),
      BusyProvider.appleICloud ||
      BusyProvider.nextcloud ||
      BusyProvider.webCal => null,
    };

    return EventEditorDraft.existing(
      eventId: detail.id,
      originalDetail: detail,
      accountId: detail.accountId,
      sourceId: detail.sourceId,
      providerCalendarId: detail.providerCalendarId,
      providerRecurringEventId: detail.providerRecurringEventId,
      eventType: detail.eventType,
      title: detail.title,
      allDay: detail.allDay,
      start: _eventEditorDateTime(
        allDay: detail.allDay,
        date: detail.startDate,
        dateTime: detail.startDateTime,
        timeZone: detail.startTimeZone,
      ),
      end: _eventEditorDateTime(
        allDay: detail.allDay,
        date: detail.endDate,
        dateTime: detail.endDateTime,
        timeZone: detail.endTimeZone,
      ),
      startTimeZone: detail.startTimeZone,
      endTimeZone: detail.endTimeZone,
      location: detail.location,
      description: detail.description,
      descriptionContentType: descriptionContentType,
      descriptionHtml: descriptionHtml,
      recurrence: detail.recurrence,
      reminders: detail.reminders,
      attendees: [
        for (final attendee in _jsonMapList(detail.attendees))
          EventAttendeeDraft.fromJson(attendee),
      ],
      importance: raw['importance']?.toString(),
      showAs: detail.transparencyOrShowAs,
      visibilityOrSensitivity: detail.visibility,
      colorId: detail.colorId,
      categories: _jsonStringList(detail.categories),
      conference: detail.conference,
      responseRequested: _jsonBool(raw['responseRequested']),
      hideAttendees: hideAttendees,
      allowNewTimeProposals: _jsonBool(raw['allowNewTimeProposals']),
      isOrganizer: isOrganizer,
      canManageAttendees:
          detail.provider != BusyProvider.google ||
          isOrganizer == true ||
          detail.guestsCanInviteOthers,
    );
  }

  factory EventEditorDraft.existing({
    required String eventId,
    CalendarEventDetail? originalDetail,
    required String accountId,
    required String sourceId,
    required String providerCalendarId,
    required String title,
    required bool allDay,
    DateTime? start,
    DateTime? end,
    String? location,
    String? providerRecurringEventId,
    String? eventType,
    RecurringEventMutationScope? recurringMutationScope,
    String? description,
    String? descriptionContentType,
    String? descriptionHtml,
    String? startTimeZone,
    String? endTimeZone,
    Object? recurrence,
    Object? reminders,
    List<EventAttendeeDraft> attendees = const [],
    String? importance,
    String? showAs,
    String? visibilityOrSensitivity,
    String? colorId,
    List<String> categories = const [],
    bool createConference = false,
    Object? conference,
    bool? responseRequested,
    bool? hideAttendees,
    bool? allowNewTimeProposals,
    bool? isOrganizer,
    bool canManageAttendees = true,
  }) {
    return EventEditorDraft(
      eventId: eventId,
      originalDetail: originalDetail,
      accountId: accountId,
      sourceId: sourceId,
      providerCalendarId: providerCalendarId,
      providerRecurringEventId: providerRecurringEventId,
      eventType: eventType,
      recurringMutationScope: recurringMutationScope,
      title: title,
      allDay: allDay,
      start: start,
      end: end,
      startTimeZone: startTimeZone,
      endTimeZone: endTimeZone,
      location: location,
      description: description,
      descriptionContentType: descriptionContentType,
      descriptionHtml: descriptionHtml,
      recurrence: recurrence,
      reminders: reminders,
      attendees: attendees,
      importance: importance,
      showAs: showAs,
      visibilityOrSensitivity: visibilityOrSensitivity,
      colorId: colorId,
      categories: categories,
      createConference: createConference,
      conference: conference,
      responseRequested: responseRequested,
      hideAttendees: hideAttendees,
      allowNewTimeProposals: allowNewTimeProposals,
      isOrganizer: isOrganizer,
      canManageAttendees: canManageAttendees,
    );
  }

  final String? eventId;
  final CalendarEventDetail? originalDetail;
  final String? providerRecurringEventId;
  final String? eventType;
  final RecurringEventMutationScope? recurringMutationScope;
  final String accountId;
  final String sourceId;
  final String providerCalendarId;
  final String title;
  final bool allDay;
  final DateTime? start;
  final DateTime? end;
  final String? startTimeZone;
  final String? endTimeZone;
  final String? location;
  final String? description;
  final String? descriptionContentType;
  final String? descriptionHtml;
  final Object? recurrence;

  /// True only after the editor deliberately changes the hydrated value.
  final bool recurrenceChanged;
  final Object? reminders;

  /// True only after the editor deliberately changes the hydrated value.
  final bool remindersChanged;
  final List<EventAttendeeDraft> attendees;

  /// True only after the editor deliberately changes the hydrated list.
  final bool attendeesChanged;
  final String? importance;
  final String? showAs;
  final String? visibilityOrSensitivity;
  final String? colorId;
  final List<String> categories;

  /// True only after the editor deliberately changes the hydrated list.
  final bool categoriesChanged;
  final bool createConference;
  final Object? conference;
  final bool? responseRequested;
  final bool? hideAttendees;
  final bool? allowNewTimeProposals;
  final bool? isOrganizer;
  final bool canManageAttendees;

  bool get canSave {
    final start = this.start;
    final end = this.end;
    if (title.trim().isEmpty || start == null || end == null) {
      return false;
    }
    if (!allDay) {
      return end.isAfter(start);
    }
    final startDate = DateTime.utc(start.year, start.month, start.day);
    final endDate = DateTime.utc(end.year, end.month, end.day);
    return endDate.isAfter(startDate);
  }

  EventEditorDraft copyWith({
    String? accountId,
    String? sourceId,
    String? providerCalendarId,
    String? title,
    bool? allDay,
    DateTime? start,
    DateTime? end,
    String? startTimeZone,
    String? endTimeZone,
    String? location,
    String? description,
    String? descriptionContentType,
    String? descriptionHtml,
    Object? recurrence,
    bool? recurrenceChanged,
    Object? reminders,
    bool? remindersChanged,
    List<EventAttendeeDraft>? attendees,
    bool? attendeesChanged,
    String? importance,
    String? showAs,
    String? visibilityOrSensitivity,
    String? colorId,
    List<String>? categories,
    bool? categoriesChanged,
    bool? createConference,
    Object? conference,
    bool? responseRequested,
    bool? hideAttendees,
    bool? allowNewTimeProposals,
    bool? isOrganizer,
    bool? canManageAttendees,
    RecurringEventMutationScope? recurringMutationScope,
    bool clearLocation = false,
    bool clearDescription = false,
    bool clearRecurrence = false,
    bool clearReminders = false,
    bool clearImportance = false,
    bool clearShowAs = false,
    bool clearVisibilityOrSensitivity = false,
    bool clearColorId = false,
    bool clearConference = false,
    bool clearRecurringMutationScope = false,
  }) {
    return EventEditorDraft(
      eventId: eventId,
      originalDetail: originalDetail,
      providerRecurringEventId: providerRecurringEventId,
      eventType: eventType,
      recurringMutationScope: clearRecurringMutationScope
          ? null
          : recurringMutationScope ?? this.recurringMutationScope,
      accountId: accountId ?? this.accountId,
      sourceId: sourceId ?? this.sourceId,
      providerCalendarId: providerCalendarId ?? this.providerCalendarId,
      title: title ?? this.title,
      allDay: allDay ?? this.allDay,
      start: start ?? this.start,
      end: end ?? this.end,
      startTimeZone: startTimeZone ?? this.startTimeZone,
      endTimeZone: endTimeZone ?? this.endTimeZone,
      location: clearLocation ? null : location ?? this.location,
      description: clearDescription ? null : description ?? this.description,
      descriptionContentType: clearDescription
          ? null
          : descriptionContentType ?? this.descriptionContentType,
      descriptionHtml: clearDescription
          ? null
          : descriptionHtml ?? this.descriptionHtml,
      recurrence: clearRecurrence ? null : recurrence ?? this.recurrence,
      recurrenceChanged:
          recurrenceChanged ??
          (this.recurrenceChanged || recurrence != null || clearRecurrence),
      reminders: clearReminders ? null : reminders ?? this.reminders,
      remindersChanged:
          remindersChanged ??
          (this.remindersChanged || reminders != null || clearReminders),
      attendees: attendees ?? this.attendees,
      attendeesChanged:
          attendeesChanged ?? (this.attendeesChanged || attendees != null),
      importance: clearImportance ? null : importance ?? this.importance,
      showAs: clearShowAs ? null : showAs ?? this.showAs,
      visibilityOrSensitivity: clearVisibilityOrSensitivity
          ? null
          : visibilityOrSensitivity ?? this.visibilityOrSensitivity,
      colorId: clearColorId ? null : colorId ?? this.colorId,
      categories: categories ?? this.categories,
      categoriesChanged:
          categoriesChanged ?? (this.categoriesChanged || categories != null),
      createConference: createConference ?? this.createConference,
      conference: clearConference ? null : conference ?? this.conference,
      responseRequested: responseRequested ?? this.responseRequested,
      hideAttendees: hideAttendees ?? this.hideAttendees,
      allowNewTimeProposals:
          allowNewTimeProposals ?? this.allowNewTimeProposals,
      isOrganizer: isOrganizer ?? this.isOrganizer,
      canManageAttendees: canManageAttendees ?? this.canManageAttendees,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is EventEditorDraft &&
        other.eventId == eventId &&
        other.originalDetail == originalDetail &&
        other.providerRecurringEventId == providerRecurringEventId &&
        other.eventType == eventType &&
        other.recurringMutationScope == recurringMutationScope &&
        other.accountId == accountId &&
        other.sourceId == sourceId &&
        other.providerCalendarId == providerCalendarId &&
        other.title == title &&
        other.allDay == allDay &&
        other.start == start &&
        other.end == end &&
        other.startTimeZone == startTimeZone &&
        other.endTimeZone == endTimeZone &&
        other.location == location &&
        other.description == description &&
        other.descriptionContentType == descriptionContentType &&
        other.descriptionHtml == descriptionHtml &&
        other.recurrence == recurrence &&
        other.recurrenceChanged == recurrenceChanged &&
        other.reminders == reminders &&
        other.remindersChanged == remindersChanged &&
        _listEquals(other.attendees, attendees) &&
        other.attendeesChanged == attendeesChanged &&
        other.importance == importance &&
        other.showAs == showAs &&
        other.visibilityOrSensitivity == visibilityOrSensitivity &&
        other.colorId == colorId &&
        _listEquals(other.categories, categories) &&
        other.categoriesChanged == categoriesChanged &&
        other.createConference == createConference &&
        other.conference == conference &&
        other.responseRequested == responseRequested &&
        other.hideAttendees == hideAttendees &&
        other.allowNewTimeProposals == allowNewTimeProposals &&
        other.isOrganizer == isOrganizer &&
        other.canManageAttendees == canManageAttendees;
  }

  @override
  int get hashCode => Object.hashAll([
    eventId,
    originalDetail,
    providerRecurringEventId,
    eventType,
    recurringMutationScope,
    accountId,
    sourceId,
    providerCalendarId,
    title,
    allDay,
    start,
    end,
    startTimeZone,
    endTimeZone,
    location,
    description,
    descriptionContentType,
    descriptionHtml,
    recurrence,
    recurrenceChanged,
    reminders,
    remindersChanged,
    Object.hashAll(attendees),
    attendeesChanged,
    importance,
    showAs,
    visibilityOrSensitivity,
    colorId,
    Object.hashAll(categories),
    categoriesChanged,
    createConference,
    conference,
    responseRequested,
    hideAttendees,
    allowNewTimeProposals,
    isOrganizer,
    canManageAttendees,
  ]);
}

bool _listEquals<T>(List<T> first, List<T> second) {
  if (identical(first, second)) {
    return true;
  }
  if (first.length != second.length) {
    return false;
  }
  for (var index = 0; index < first.length; index += 1) {
    if (first[index] != second[index]) {
      return false;
    }
  }
  return true;
}

DateTime? _eventEditorDateTime({
  required bool allDay,
  required String? date,
  required String? dateTime,
  required String? timeZone,
}) {
  final value = allDay ? date ?? dateTime : dateTime;
  if (value == null || value.isEmpty) return null;
  return providerDateTimeAsWallTime(value, timeZone);
}

Map<String, Object?> _jsonMap(Object? value) {
  return _jsonMapOrNull(value) ?? const {};
}

Map<String, Object?>? _jsonMapOrNull(Object? value) {
  return value is Map ? Map<String, Object?>.from(value) : null;
}

List<Map<String, Object?>> _jsonMapList(Object? value) {
  if (value is! List) return const [];
  return [
    for (final item in value)
      if (item is Map) Map<String, Object?>.from(item),
  ];
}

List<String> _jsonStringList(Object? value) {
  if (value is! List) return const [];
  return [
    for (final item in value)
      if (item != null && item.toString().trim().isNotEmpty)
        item.toString().trim(),
  ];
}

bool? _jsonBool(Object? value) => value is bool ? value : null;

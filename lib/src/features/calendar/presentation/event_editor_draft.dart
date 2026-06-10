class EventAttendeeDraft {
  const EventAttendeeDraft({
    required this.email,
    this.displayName,
    this.optional = false,
  });

  factory EventAttendeeDraft.fromJson(Map<String, Object?> json) {
    final email = json['email']?.toString();
    final address = json['address']?.toString();
    return EventAttendeeDraft(
      email: (email == null || email.isEmpty) ? address ?? '' : email,
      displayName: json['displayName']?.toString() ?? json['name']?.toString(),
      optional: json['optional'] == true,
    );
  }

  final String email;
  final String? displayName;
  final bool optional;

  Map<String, Object?> toGoogleJson() {
    return {
      'email': email,
      if (displayName != null && displayName!.isNotEmpty)
        'displayName': displayName,
      if (optional) 'optional': true,
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
        other.optional == optional;
  }

  @override
  int get hashCode => Object.hash(email, displayName, optional);
}

class EventEditorDraft {
  const EventEditorDraft({
    required this.accountId,
    required this.sourceId,
    required this.providerCalendarId,
    required this.title,
    required this.allDay,
    this.eventId,
    this.start,
    this.end,
    this.startTimeZone,
    this.endTimeZone,
    this.location,
    this.description,
    this.descriptionContentType,
    this.descriptionHtml,
    this.recurrence,
    this.reminders,
    this.attendees = const [],
    this.importance,
    this.showAs,
    this.visibilityOrSensitivity,
    this.colorId,
    this.categories = const [],
    this.createConference = false,
    this.conference,
    this.responseRequested,
    this.hideAttendees,
    this.allowNewTimeProposals,
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
    );
  }

  factory EventEditorDraft.existing({
    required String eventId,
    required String accountId,
    required String sourceId,
    required String providerCalendarId,
    required String title,
    required bool allDay,
    DateTime? start,
    DateTime? end,
    String? location,
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
  }) {
    return EventEditorDraft(
      eventId: eventId,
      accountId: accountId,
      sourceId: sourceId,
      providerCalendarId: providerCalendarId,
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
    );
  }

  final String? eventId;
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
  final Object? reminders;
  final List<EventAttendeeDraft> attendees;
  final String? importance;
  final String? showAs;
  final String? visibilityOrSensitivity;
  final String? colorId;
  final List<String> categories;
  final bool createConference;
  final Object? conference;
  final bool? responseRequested;
  final bool? hideAttendees;
  final bool? allowNewTimeProposals;

  bool get canSave => title.trim().isNotEmpty;

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
    Object? reminders,
    List<EventAttendeeDraft>? attendees,
    String? importance,
    String? showAs,
    String? visibilityOrSensitivity,
    String? colorId,
    List<String>? categories,
    bool? createConference,
    Object? conference,
    bool? responseRequested,
    bool? hideAttendees,
    bool? allowNewTimeProposals,
    bool clearLocation = false,
    bool clearDescription = false,
    bool clearRecurrence = false,
    bool clearReminders = false,
    bool clearImportance = false,
    bool clearShowAs = false,
    bool clearVisibilityOrSensitivity = false,
    bool clearColorId = false,
    bool clearConference = false,
  }) {
    return EventEditorDraft(
      eventId: eventId,
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
      reminders: clearReminders ? null : reminders ?? this.reminders,
      attendees: attendees ?? this.attendees,
      importance: clearImportance ? null : importance ?? this.importance,
      showAs: clearShowAs ? null : showAs ?? this.showAs,
      visibilityOrSensitivity: clearVisibilityOrSensitivity
          ? null
          : visibilityOrSensitivity ?? this.visibilityOrSensitivity,
      colorId: clearColorId ? null : colorId ?? this.colorId,
      categories: categories ?? this.categories,
      createConference: createConference ?? this.createConference,
      conference: clearConference ? null : conference ?? this.conference,
      responseRequested: responseRequested ?? this.responseRequested,
      hideAttendees: hideAttendees ?? this.hideAttendees,
      allowNewTimeProposals:
          allowNewTimeProposals ?? this.allowNewTimeProposals,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is EventEditorDraft &&
        other.eventId == eventId &&
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
        other.reminders == reminders &&
        _listEquals(other.attendees, attendees) &&
        other.importance == importance &&
        other.showAs == showAs &&
        other.visibilityOrSensitivity == visibilityOrSensitivity &&
        other.colorId == colorId &&
        _listEquals(other.categories, categories) &&
        other.createConference == createConference &&
        other.conference == conference &&
        other.responseRequested == responseRequested &&
        other.hideAttendees == hideAttendees &&
        other.allowNewTimeProposals == allowNewTimeProposals;
  }

  @override
  int get hashCode => Object.hashAll([
    eventId,
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
    reminders,
    Object.hashAll(attendees),
    importance,
    showAs,
    visibilityOrSensitivity,
    colorId,
    Object.hashAll(categories),
    createConference,
    conference,
    responseRequested,
    hideAttendees,
    allowNewTimeProposals,
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

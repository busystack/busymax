const googleStatusEventTypes = <String>[
  'focusTime',
  'outOfOffice',
  'workingLocation',
];

String? googleStatusPropertiesKey(String? eventType) => switch (eventType) {
  'focusTime' => 'focusTimeProperties',
  'outOfOffice' => 'outOfOfficeProperties',
  'workingLocation' => 'workingLocationProperties',
  _ => null,
};

Map<String, Object?> googleStatusPropertiesFromRaw(
  String? eventType,
  Object? raw,
) {
  final key = googleStatusPropertiesKey(eventType);
  if (key == null || raw is! Map || raw[key] is! Map) return const {};
  return Map<String, Object?>.from(raw[key] as Map);
}

Map<String, Object?> defaultGoogleStatusProperties(String eventType) =>
    switch (eventType) {
      'focusTime' => const {
        'autoDeclineMode': 'declineNone',
        'chatStatus': 'available',
      },
      'outOfOffice' => const {'autoDeclineMode': 'declineNone'},
      'workingLocation' => const {
        'type': 'homeOffice',
        'homeOffice': <String, Object?>{},
      },
      _ => const {},
    };

/// Validates the subset documented for Google primary-calendar status events.
/// Google remains authoritative for account eligibility, which it does not
/// expose as a stable capability flag.
void validateGoogleStatusEvent({
  required bool primaryCalendar,
  required String? eventType,
  required String? originalEventType,
  required bool allDay,
  required DateTime? start,
  required DateTime? end,
  required String? visibility,
  required String? transparency,
  required Map<String, Object?> properties,
}) {
  final type = eventType ?? 'default';
  final original = originalEventType ?? 'default';
  if (originalEventType != null && type != original) {
    throw UnsupportedError('Google event types cannot be changed in place.');
  }
  if (type == 'default') return;
  if (type == 'fromGmail' && original == 'fromGmail') return;
  if (!googleStatusEventTypes.contains(type)) {
    throw UnsupportedError('This Google event type cannot be created here.');
  }
  if (!primaryCalendar) {
    throw UnsupportedError(
      'Google status events require the primary calendar.',
    );
  }
  if (start == null || end == null || !end.isAfter(start)) {
    throw ArgumentError('A status event needs a valid start and end.');
  }
  if (type == 'workingLocation') {
    if (visibility != 'public' || transparency != 'transparent') {
      throw ArgumentError(
        'Working location must be public and show as available.',
      );
    }
    if (allDay &&
        DateTime.utc(end.year, end.month, end.day) !=
            DateTime.utc(start.year, start.month, start.day + 1)) {
      throw ArgumentError('All-day working location must span one day.');
    }
    final locationType = properties['type'];
    if (!const [
      'homeOffice',
      'officeLocation',
      'customLocation',
    ].contains(locationType)) {
      throw ArgumentError('Choose a supported working location.');
    }
    if (locationType == 'customLocation' || locationType == 'officeLocation') {
      final detail = properties[locationType];
      if (detail != null && detail is! Map) {
        throw ArgumentError('Working location details are invalid.');
      }
    }
    return;
  }
  if (allDay || transparency != 'opaque') {
    throw ArgumentError('Focus time and out of office must be timed and busy.');
  }
  final mode = properties['autoDeclineMode'];
  if (mode != null &&
      !const [
        'declineNone',
        'declineAllConflictingInvitations',
        'declineOnlyNewConflictingInvitations',
      ].contains(mode)) {
    throw ArgumentError('The auto-decline setting is invalid.');
  }
  if (type == 'focusTime') {
    final chatStatus = properties['chatStatus'];
    if (chatStatus != null &&
        !const ['available', 'doNotDisturb'].contains(chatStatus)) {
      throw ArgumentError('The chat status is invalid.');
    }
  }
}

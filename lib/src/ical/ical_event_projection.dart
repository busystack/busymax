import 'dart:convert';

import '../dav/dav_errors.dart';
import '../dav/ical/ical_document.dart';
import '../dav/ical/ical_recurrence.dart';
import '../dav/ical/ical_semantics.dart';
import '../dav/ical/ical_timezone.dart';
import 'ical_ingestion.dart';

const sharedIcalEventProjectionVersion = 1;

final class ProjectedIcalEvent {
  const ProjectedIcalEvent({
    required this.uid,
    required this.occurrenceKey,
    required this.recurrenceIdKey,
    required this.title,
    required this.description,
    required this.location,
    required this.allDay,
    required this.startDate,
    required this.startDateTime,
    required this.startTimeZone,
    required this.endDate,
    required this.endDateTime,
    required this.endTimeZone,
    required this.recurrenceJson,
    required this.remindersJson,
    required this.attendeesJson,
    required this.categoriesJson,
    required this.organizerJson,
    required this.visibility,
    required this.transparency,
    required this.status,
    required this.cancelled,
    required this.recurring,
    required this.webLink,
    required this.attachmentsJson,
    required this.createdAtServer,
    required this.updatedAtServer,
    required this.rawJson,
  });

  final String uid;
  final String occurrenceKey;
  final String? recurrenceIdKey;
  final String title;
  final String? description;
  final String? location;
  final bool allDay;
  final String? startDate;
  final String? startDateTime;
  final String? startTimeZone;
  final String? endDate;
  final String? endDateTime;
  final String? endTimeZone;
  final String recurrenceJson;
  final String remindersJson;
  final String attendeesJson;
  final String categoriesJson;
  final String? organizerJson;
  final String? visibility;
  final String? transparency;
  final String? status;
  final bool cancelled;
  final bool recurring;
  final String? webLink;
  final String attachmentsJson;
  final String? createdAtServer;
  final String? updatedAtServer;
  final String rawJson;
}

final class IcalEventProjector {
  IcalEventProjector({IcalRecurrenceExpander? recurrenceExpander})
    : _recurrenceExpander = recurrenceExpander ?? IcalRecurrenceExpander();

  final IcalRecurrenceExpander _recurrenceExpander;

  List<ProjectedIcalEvent> project(
    IcalRecurrenceSet set, {
    required DateTime rangeStartUtc,
    required DateTime rangeEndUtc,
    required String transport,
  }) {
    return projectSemantic(
      set.semantic,
      rangeStartUtc: rangeStartUtc,
      rangeEndUtc: rangeEndUtc,
      transport: transport,
    );
  }

  List<ProjectedIcalEvent> projectSemantic(
    IcalSemanticDocument semantic, {
    required DateTime rangeStartUtc,
    required DateTime rangeEndUtc,
    required String transport,
  }) {
    final occurrences = _recurrenceExpander.expand(
      semantic,
      rangeStartUtc: rangeStartUtc,
      rangeEndUtc: rangeEndUtc,
    );
    final resolver = IcalTimeZoneResolver.fromDocument(semantic);
    final recurringUids = {
      for (final component in semantic.components)
        if (component.recurrenceId != null ||
            component.recurrenceRules.isNotEmpty ||
            component.recurrenceDates.isNotEmpty ||
            component.exceptionDates.isNotEmpty)
          component.uid,
    };
    return [
      for (final occurrence in occurrences)
        _projectOccurrence(
          occurrence,
          resolver,
          transport,
          recurring: recurringUids.contains(occurrence.master.uid),
        ),
    ];
  }
}

ProjectedIcalEvent _projectOccurrence(
  IcalOccurrence occurrence,
  IcalTimeZoneResolver resolver,
  String transport, {
  required bool recurring,
}) {
  final component = occurrence.effectiveComponent;
  final master = occurrence.master;
  final identity = occurrence.identityComponent;
  final allDay = occurrence.start.kind == IcalTemporalKind.date;
  final attendees = component.attendees.isEmpty
      ? master.attendees
      : component.attendees;
  final organizers = component.organizers.isEmpty
      ? master.organizers
      : component.organizers;
  final categories = component.categories.isEmpty
      ? master.categories
      : component.categories;
  final alarms = component.alarms.isEmpty ? master.alarms : component.alarms;
  final startUtc = _resolvedUtc(occurrence.start, resolver);
  final endUtc = occurrence.end == null
      ? null
      : _resolvedUtc(occurrence.end!, resolver);
  final attachments = _propertyRawValues(component, 'ATTACH');
  final masterAttachments = _propertyRawValues(master, 'ATTACH');
  return ProjectedIcalEvent(
    uid: component.uid!,
    occurrenceKey: occurrence.occurrenceKey,
    recurrenceIdKey: identity.recurrenceIdKey,
    title: occurrence.summary ?? '',
    description: occurrence.description,
    location: occurrence.location,
    allDay: allDay,
    startDate: allDay ? _storageTemporal(occurrence.start) : null,
    startDateTime: allDay ? null : _storageTemporal(occurrence.start),
    startTimeZone: _timeZoneName(occurrence.start),
    endDate: allDay && occurrence.end != null
        ? _storageTemporal(occurrence.end!)
        : null,
    endDateTime: !allDay && occurrence.end != null
        ? _storageTemporal(occurrence.end!)
        : null,
    endTimeZone: occurrence.end == null ? null : _timeZoneName(occurrence.end!),
    recurrenceJson: jsonEncode({
      'rules': master.recurrenceRules,
      'dates': master.recurrenceDates,
      'excludedDates': master.exceptionDates,
    }),
    remindersJson: jsonEncode({
      'minutes': _eventReminderMinutes(alarms),
      'alarms': _alarmProjection(alarms),
    }),
    attendeesJson: jsonEncode(attendees),
    categoriesJson: jsonEncode(categories),
    organizerJson: organizers.isEmpty ? null : jsonEncode(organizers.first),
    visibility: component.classification ?? master.classification,
    transparency: component.transparency ?? master.transparency,
    status: component.status ?? master.status,
    cancelled: occurrence.isCancelled,
    recurring: recurring,
    webLink: _propertyRaw(component, 'URL') ?? _propertyRaw(master, 'URL'),
    attachmentsJson: jsonEncode(
      attachments.isEmpty ? masterAttachments : attachments,
    ),
    createdAtServer: _storageTemporalNullable(
      component.created ?? master.created,
    ),
    updatedAtServer: _storageTemporalNullable(
      component.lastModified ?? master.lastModified,
    ),
    rawJson: jsonEncode({
      'transport': transport,
      'uid': component.uid,
      'occurrenceKey': occurrence.occurrenceKey,
      'nativeStart': _temporalJson(occurrence.start),
      if (occurrence.end != null) 'nativeEnd': _temporalJson(occurrence.end!),
      if (startUtc != null) 'startUtc': startUtc.toIso8601String(),
      if (endUtc != null) 'endUtc': endUtc.toIso8601String(),
      if (transport == 'caldav')
        'extensionProperties': {
          ...master.extensionProperties,
          ...component.extensionProperties,
        },
    }),
  );
}

String? _storageTemporalNullable(IcalTemporalValue? value) =>
    value == null ? null : _storageTemporal(value);

String? _propertyRaw(IcalSemanticComponent component, String name) =>
    component.documentComponent.firstProperty(name)?.rawValue;

List<String> _propertyRawValues(IcalSemanticComponent component, String name) =>
    component.documentComponent
        .propertiesNamed(name)
        .map((property) => property.rawValue)
        .toList(growable: false);

String _storageTemporal(IcalTemporalValue value) {
  String two(int number) => number.toString().padLeft(2, '0');
  final wall = value.localValue;
  final date =
      '${wall.year.toString().padLeft(4, '0')}-'
      '${two(wall.month)}-${two(wall.day)}';
  if (value.kind == IcalTemporalKind.date) return date;
  if (value.kind == IcalTemporalKind.utcDateTime) {
    return icalTemporalToUtc(value).toIso8601String();
  }
  return '${date}T${two(wall.hour)}:${two(wall.minute)}:${two(wall.second)}';
}

String? _timeZoneName(IcalTemporalValue value) => switch (value.kind) {
  IcalTemporalKind.utcDateTime => 'UTC',
  IcalTemporalKind.tzidDateTime => value.timeZoneId,
  IcalTemporalKind.date || IcalTemporalKind.floatingDateTime => null,
};

DateTime? _resolvedUtc(IcalTemporalValue value, IcalTimeZoneResolver resolver) {
  return switch (value.kind) {
    IcalTemporalKind.utcDateTime || IcalTemporalKind.tzidDateTime =>
      icalTemporalToUtc(value, resolver: resolver),
    IcalTemporalKind.date || IcalTemporalKind.floatingDateTime => null,
  };
}

Map<String, Object?> _temporalJson(IcalTemporalValue value) => {
  'raw': value.rawValue,
  'kind': value.kind.name,
  if (value.timeZoneId != null) 'timeZoneId': value.timeZoneId,
};

List<Map<String, Object?>> _alarmProjection(List<IcalComponent> alarms) => [
  for (final alarm in alarms)
    {
      'properties': [
        for (final property in alarm.properties)
          {
            'name': property.name,
            'value': property.rawValue,
            if (property.parameters.isNotEmpty)
              'parameters': [
                for (final parameter in property.parameters)
                  {'name': parameter.name, 'values': parameter.values},
              ],
          },
      ],
    },
];

List<int> _eventReminderMinutes(List<IcalComponent> alarms) {
  final result = <int>[];
  for (final alarm in alarms) {
    final action = alarm.firstProperty('ACTION')?.rawValue.toUpperCase();
    if (action != 'DISPLAY' && action != 'AUDIO') continue;
    final trigger = alarm.firstProperty('TRIGGER');
    if (trigger == null ||
        trigger.parameterValue('RELATED')?.toUpperCase() == 'END') {
      continue;
    }
    try {
      final duration = parseIcalDuration(trigger.rawValue.toUpperCase());
      if (duration == null || !duration.negative) continue;
      final before = -duration.duration;
      if (before.inSeconds <= 0 || before.inSeconds % 60 != 0) continue;
      if (!result.contains(before.inMinutes)) result.add(before.inMinutes);
    } on DavException {
      // Unsupported trigger forms remain available in the alarm projection.
    }
  }
  return result;
}

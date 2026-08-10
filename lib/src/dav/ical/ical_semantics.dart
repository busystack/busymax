import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../dav_errors.dart';
import 'ical_document.dart';

enum IcalTemporalKind { date, floatingDateTime, utcDateTime, tzidDateTime }

final class IcalTemporalValue {
  const IcalTemporalValue({
    required this.rawValue,
    required this.kind,
    required this.localValue,
    required this.timeZoneId,
  });

  final String rawValue;
  final IcalTemporalKind kind;
  final DateTime localValue;
  final String? timeZoneId;

  bool get isDate => kind == IcalTemporalKind.date;

  String get recurrenceKey => switch (kind) {
    IcalTemporalKind.date => 'VALUE=DATE:$rawValue',
    IcalTemporalKind.tzidDateTime => 'TZID=$timeZoneId:$rawValue',
    IcalTemporalKind.utcDateTime => 'UTC:$rawValue',
    IcalTemporalKind.floatingDateTime => 'FLOATING:$rawValue',
  };
}

final class IcalDuration {
  const IcalDuration({
    required this.negative,
    required this.weeks,
    required this.days,
    required this.hours,
    required this.minutes,
    required this.seconds,
  });

  final bool negative;
  final int weeks;
  final int days;
  final int hours;
  final int minutes;
  final int seconds;

  Duration get duration {
    final value = Duration(
      days: weeks * 7 + days,
      hours: hours,
      minutes: minutes,
      seconds: seconds,
    );
    return negative ? -value : value;
  }
}

enum IcalTaskUiState { open, inProgress, completed, cancelled }

final class IcalSemanticComponent {
  IcalSemanticComponent._({
    required this.documentComponent,
    required this.componentType,
    required this.uid,
    required this.recurrenceIdKey,
    required this.recurrenceId,
    required this.summary,
    required this.description,
    required this.location,
    required this.url,
    required this.status,
    required this.classification,
    required this.transparency,
    required this.start,
    required this.end,
    required this.due,
    required this.completed,
    required this.duration,
    required this.sequence,
    required this.dtstamp,
    required this.created,
    required this.lastModified,
    required this.priority,
    required this.percentComplete,
    required this.parentUid,
    required this.sortOrder,
    required this.categories,
    required this.recurrenceRules,
    required this.recurrenceDates,
    required this.exceptionDates,
    required this.attendees,
    required this.organizers,
    required this.alarms,
    required this.extensionProperties,
    required this.semanticHash,
  });

  factory IcalSemanticComponent.fromDocumentComponent(IcalComponent component) {
    final type = component.name;
    final uidProperties = component
        .propertiesNamed('UID')
        .toList(growable: false);
    final uid = uidProperties.firstOrNull?.rawValue.trim();
    if ((type == 'VEVENT' || type == 'VTODO') &&
        (uid == null || uid.isEmpty || uidProperties.length != 1)) {
      throw const DavException(
        kind: DavErrorKind.invalidCalendarData,
        code: 'IcalCalendarObjectInvariantFailed',
        safeMessage: 'An event or task component must contain exactly one UID.',
      );
    }
    final status = _raw(component, 'STATUS')?.toUpperCase();
    final percent = _integer(component, 'PERCENT-COMPLETE');
    final completed = parseIcalTemporal(component.firstProperty('COMPLETED'));
    return IcalSemanticComponent._(
      documentComponent: component,
      componentType: type,
      uid: uid,
      recurrenceIdKey: icalRecurrenceIdKey(
        component.firstProperty('RECURRENCE-ID'),
      ),
      recurrenceId: parseIcalTemporal(component.firstProperty('RECURRENCE-ID')),
      summary: _text(component, 'SUMMARY'),
      description: _text(component, 'DESCRIPTION'),
      location: _text(component, 'LOCATION'),
      url: _raw(component, 'URL'),
      status: status,
      classification: _raw(component, 'CLASS'),
      transparency: _raw(component, 'TRANSP'),
      start: parseIcalTemporal(component.firstProperty('DTSTART')),
      end: parseIcalTemporal(component.firstProperty('DTEND')),
      due: parseIcalTemporal(component.firstProperty('DUE')),
      completed: completed,
      duration: parseIcalDuration(_raw(component, 'DURATION')),
      sequence: _integer(component, 'SEQUENCE'),
      dtstamp: parseIcalTemporal(component.firstProperty('DTSTAMP')),
      created: parseIcalTemporal(component.firstProperty('CREATED')),
      lastModified: parseIcalTemporal(component.firstProperty('LAST-MODIFIED')),
      priority: _integer(component, 'PRIORITY'),
      percentComplete: percent,
      parentUid: _parentUid(component),
      sortOrder: _integer(component, 'X-APPLE-SORT-ORDER'),
      categories: _categories(component),
      recurrenceRules: _rawValues(component, 'RRULE'),
      recurrenceDates: _rawValues(component, 'RDATE'),
      exceptionDates: _rawValues(component, 'EXDATE'),
      attendees: _structuredAddresses(component, 'ATTENDEE'),
      organizers: _structuredAddresses(component, 'ORGANIZER'),
      alarms: component.componentsNamed('VALARM').toList(growable: false),
      extensionProperties: _extensionProperties(component),
      semanticHash: semanticComponentHash(component),
    );
  }

  final IcalComponent documentComponent;
  final String componentType;
  final String? uid;
  final String? recurrenceIdKey;
  final IcalTemporalValue? recurrenceId;
  final String? summary;
  final String? description;
  final String? location;
  final String? url;
  final String? status;
  final String? classification;
  final String? transparency;
  final IcalTemporalValue? start;
  final IcalTemporalValue? end;
  final IcalTemporalValue? due;
  final IcalTemporalValue? completed;
  final IcalDuration? duration;
  final int? sequence;
  final IcalTemporalValue? dtstamp;
  final IcalTemporalValue? created;
  final IcalTemporalValue? lastModified;
  final int? priority;
  final int? percentComplete;
  final String? parentUid;
  final int? sortOrder;
  final List<String> categories;
  final List<String> recurrenceRules;
  final List<String> recurrenceDates;
  final List<String> exceptionDates;
  final List<Map<String, Object?>> attendees;
  final List<Map<String, Object?>> organizers;
  final List<IcalComponent> alarms;
  final Map<String, List<String>> extensionProperties;
  final String semanticHash;

  bool get isCancelled => status == 'CANCELLED';

  IcalTaskUiState get taskUiState {
    if (status == 'CANCELLED') {
      return IcalTaskUiState.cancelled;
    }
    if (status == 'COMPLETED' || completed != null) {
      return IcalTaskUiState.completed;
    }
    if (status == 'IN-PROCESS' ||
        (percentComplete != null &&
            percentComplete! > 0 &&
            percentComplete! < 100)) {
      return IcalTaskUiState.inProgress;
    }
    return IcalTaskUiState.open;
  }
}

int nextcloudTaskSortOrder(
  IcalSemanticComponent component, {
  IcalSemanticComponent? fallback,
}) {
  final explicit = component.sortOrder ?? fallback?.sortOrder;
  if (explicit != null) return explicit;
  final created = component.created ?? fallback?.created;
  if (created == null) return 0;
  return created.localValue.difference(DateTime.utc(2001, 1, 1)).inSeconds;
}

final class IcalComponentIndexEntry {
  const IcalComponentIndexEntry({
    required this.componentType,
    required this.uid,
    required this.recurrenceIdKey,
    required this.sequence,
    required this.dtstampUtc,
    required this.lastModifiedUtc,
    required this.semanticHash,
    required this.parserProfileVersion,
  });

  final String componentType;
  final String uid;
  final String? recurrenceIdKey;
  final int? sequence;
  final String? dtstampUtc;
  final String? lastModifiedUtc;
  final String semanticHash;
  final int parserProfileVersion;
}

final class IcalSemanticDocument {
  IcalSemanticDocument._({
    required this.document,
    required this.components,
    required this.timeZones,
    required this.semanticHash,
  });

  factory IcalSemanticDocument.parse(String rawIcs) {
    final document = IcalDocument.parse(rawIcs);
    final semanticComponents = <IcalSemanticComponent>[];
    final timeZones = <IcalComponent>[];
    for (final component in document.calendarComponents) {
      if (component.name == 'VEVENT' || component.name == 'VTODO') {
        semanticComponents.add(
          IcalSemanticComponent.fromDocumentComponent(component),
        );
      } else if (component.name == 'VTIMEZONE') {
        timeZones.add(component);
      }
    }
    final componentTypes = semanticComponents
        .map((component) => component.componentType)
        .toSet();
    final componentUids = semanticComponents
        .map((component) => component.uid)
        .whereType<String>()
        .toSet();
    final nonTimeZoneComponents = document.calendarComponents
        .where((component) => component.name != 'VTIMEZONE')
        .toList(growable: false);
    if (nonTimeZoneComponents.isEmpty ||
        (semanticComponents.isNotEmpty &&
            (componentTypes.length != 1 || componentUids.length != 1))) {
      throw const DavException(
        kind: DavErrorKind.invalidCalendarData,
        code: 'IcalCalendarObjectInvariantFailed',
        safeMessage:
            'A CalDAV object must contain one component type and one UID recurrence set.',
      );
    }
    return IcalSemanticDocument._(
      document: document,
      components: List.unmodifiable(semanticComponents),
      timeZones: List.unmodifiable(timeZones),
      semanticHash: semanticDocumentHash(document),
    );
  }

  final IcalDocument document;
  final List<IcalSemanticComponent> components;
  final List<IcalComponent> timeZones;
  final String semanticHash;

  /// The primary top-level component type retained by this raw resource.
  /// BusyMax projects VEVENT and VTODO components, but unsupported component
  /// types still remain valid raw synchronization content.
  String? get dominantComponentType {
    if (components.isNotEmpty) return components.first.componentType;
    for (final component in document.calendarComponents) {
      if (component.name != 'VTIMEZONE') return component.name;
    }
    return null;
  }

  int get componentMask {
    var mask = 0;
    if (components.any((component) => component.componentType == 'VEVENT')) {
      mask |= 1 << 0;
    }
    if (components.any((component) => component.componentType == 'VTODO')) {
      mask |= 1 << 1;
    }
    if (timeZones.isNotEmpty) mask |= 1 << 2;
    return mask;
  }

  String? get primaryUid {
    final uids = components
        .map((component) => component.uid)
        .whereType<String>()
        .toSet();
    return uids.length == 1 ? uids.single : null;
  }

  List<IcalComponentIndexEntry> buildIndex({int profileVersion = 1}) => [
    for (final component in components)
      IcalComponentIndexEntry(
        componentType: component.componentType,
        uid: component.uid!,
        recurrenceIdKey: component.recurrenceIdKey,
        sequence: component.sequence,
        dtstampUtc: _utcText(component.dtstamp),
        lastModifiedUtc: _utcText(component.lastModified),
        semanticHash: component.semanticHash,
        parserProfileVersion: profileVersion,
      ),
  ];
}

IcalTemporalValue? parseIcalTemporal(IcalProperty? property) {
  if (property == null || property.rawValue.trim().isEmpty) return null;
  final raw = property.rawValue.trim();
  final explicitDate =
      property.parameterValue('VALUE')?.toUpperCase() == 'DATE';
  final tzid = property.parameterValue('TZID');
  if (explicitDate || RegExp(r'^[0-9]{8}$').hasMatch(raw)) {
    final value = _parseDate(raw);
    return IcalTemporalValue(
      rawValue: raw,
      kind: IcalTemporalKind.date,
      localValue: value,
      timeZoneId: null,
    );
  }
  final utc = raw.endsWith('Z');
  final value = _parseDateTime(utc ? raw.substring(0, raw.length - 1) : raw);
  return IcalTemporalValue(
    rawValue: raw,
    kind: utc
        ? IcalTemporalKind.utcDateTime
        : tzid != null
        ? IcalTemporalKind.tzidDateTime
        : IcalTemporalKind.floatingDateTime,
    localValue: utc ? value.toUtc() : value,
    timeZoneId: tzid,
  );
}

IcalDuration? parseIcalDuration(String? source) {
  if (source == null || source.isEmpty) return null;
  final match = RegExp(
    r'^([+-])?P(?:(\d+)W)?(?:(\d+)D)?(?:T(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?)?$',
  ).firstMatch(source);
  if (match == null ||
      match.groups([2, 3, 4, 5, 6]).every((value) => value == null)) {
    throw const DavException(
      kind: DavErrorKind.invalidCalendarData,
      code: 'IcalInvalidDuration',
      safeMessage: 'An iCalendar component contained an invalid duration.',
    );
  }
  return IcalDuration(
    negative: match.group(1) == '-',
    weeks: int.tryParse(match.group(2) ?? '') ?? 0,
    days: int.tryParse(match.group(3) ?? '') ?? 0,
    hours: int.tryParse(match.group(4) ?? '') ?? 0,
    minutes: int.tryParse(match.group(5) ?? '') ?? 0,
    seconds: int.tryParse(match.group(6) ?? '') ?? 0,
  );
}

String semanticDocumentHash(IcalDocument document) =>
    sha256.convert(utf8.encode(_canonicalComponent(document.root))).toString();

String semanticComponentHash(IcalComponent component) =>
    sha256.convert(utf8.encode(_canonicalComponent(component))).toString();

Set<String> changedIcalProperties(
  IcalComponent baseline,
  IcalComponent current,
) {
  final names = {
    ...baseline.properties.map((property) => property.name),
    ...current.properties.map((property) => property.name),
  };
  return {
    for (final name in names)
      if (_canonicalProperties(baseline, name) !=
          _canonicalProperties(current, name))
        name,
  };
}

String _canonicalComponent(IcalComponent component) {
  final propertyLines =
      component.properties.map(_canonicalProperty).toList(growable: false)
        ..sort();
  final nested =
      component.components.map(_canonicalComponent).toList(growable: false)
        ..sort();
  return jsonEncode({
    'type': component.name,
    'properties': propertyLines,
    'components': nested,
  });
}

String _canonicalProperty(IcalProperty property) {
  final parameters = [
    for (final parameter in property.parameters)
      '${parameter.name}=${[...parameter.values]..sort()}',
  ]..sort();
  return '${property.group ?? ''}.${property.name};${parameters.join(';')}:'
      '${property.rawValue}';
}

String _canonicalProperties(IcalComponent component, String name) {
  final values =
      component.propertiesNamed(name).map(_canonicalProperty).toList()..sort();
  return values.join('\n');
}

DateTime _parseDate(String source) {
  if (!RegExp(r'^[0-9]{8}$').hasMatch(source)) {
    throw _invalidTemporal();
  }
  return _checkedDateTime(
    int.parse(source.substring(0, 4)),
    int.parse(source.substring(4, 6)),
    int.parse(source.substring(6, 8)),
  );
}

DateTime _parseDateTime(String source) {
  final match = RegExp(
    r'^(\d{4})(\d{2})(\d{2})T(\d{2})(\d{2})(\d{2})$',
  ).firstMatch(source);
  if (match == null) throw _invalidTemporal();
  return _checkedDateTime(
    int.parse(match.group(1)!),
    int.parse(match.group(2)!),
    int.parse(match.group(3)!),
    int.parse(match.group(4)!),
    int.parse(match.group(5)!),
    int.parse(match.group(6)!),
  );
}

DateTime _checkedDateTime(
  int year,
  int month,
  int day, [
  int hour = 0,
  int minute = 0,
  int second = 0,
]) {
  final value = DateTime.utc(year, month, day, hour, minute, second);
  if (value.year != year ||
      value.month != month ||
      value.day != day ||
      value.hour != hour ||
      value.minute != minute ||
      value.second != second) {
    throw _invalidTemporal();
  }
  return value;
}

DavException _invalidTemporal() => const DavException(
  kind: DavErrorKind.invalidCalendarData,
  code: 'IcalInvalidTemporalValue',
  safeMessage: 'An iCalendar component contained an invalid date or time.',
);

String? _raw(IcalComponent component, String name) =>
    component.firstProperty(name)?.rawValue;

String? _text(IcalComponent component, String name) =>
    component.firstProperty(name)?.decodedTextValue;

int? _integer(IcalComponent component, String name) {
  final value = _raw(component, name);
  if (value == null || value.isEmpty) return null;
  final parsed = int.tryParse(value);
  if (parsed == null) {
    throw const DavException(
      kind: DavErrorKind.invalidCalendarData,
      code: 'IcalInvalidIntegerValue',
      safeMessage: 'An iCalendar component contained an invalid integer.',
    );
  }
  return parsed;
}

List<String> _rawValues(IcalComponent component, String name) => component
    .propertiesNamed(name)
    .map((property) => property.rawValue)
    .toList(growable: false);

List<String> _categories(IcalComponent component) => [
  for (final property in component.propertiesNamed('CATEGORIES'))
    ..._splitEscaped(property.rawValue, ',').map(decodeIcalText),
];

String? _parentUid(IcalComponent component) {
  for (final relation in component.propertiesNamed('RELATED-TO')) {
    final relationType = relation.parameterValue('RELTYPE')?.toUpperCase();
    if (relationType == null || relationType == 'PARENT') {
      return relation.rawValue.trim().isEmpty ? null : relation.rawValue.trim();
    }
  }
  return null;
}

List<Map<String, Object?>> _structuredAddresses(
  IcalComponent component,
  String propertyName,
) => [
  for (final property in component.propertiesNamed(propertyName))
    {
      'value': property.rawValue,
      'parameters': [
        for (final parameter in property.parameters)
          {'name': parameter.name, 'values': parameter.values},
      ],
    },
];

Map<String, List<String>> _extensionProperties(IcalComponent component) {
  final result = <String, List<String>>{};
  for (final property in component.properties) {
    if (property.name.startsWith('X-')) {
      result.putIfAbsent(property.name, () => []).add(property.rawValue);
    }
  }
  return result;
}

List<String> _splitEscaped(String source, String separator) {
  final result = <String>[];
  var start = 0;
  var escaped = false;
  for (var index = 0; index < source.length; index += 1) {
    final value = source[index];
    if (escaped) {
      escaped = false;
    } else if (value == r'\') {
      escaped = true;
    } else if (value == separator) {
      result.add(source.substring(start, index));
      start = index + 1;
    }
  }
  result.add(source.substring(start));
  return result;
}

String? _utcText(IcalTemporalValue? value) {
  if (value == null || value.kind != IcalTemporalKind.utcDateTime) return null;
  return value.localValue.toUtc().toIso8601String();
}

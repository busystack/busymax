import 'dart:convert';

import 'package:collection/collection.dart';

import '../dav_errors.dart';
import 'ical_document.dart';
import 'ical_semantics.dart';

/// A lossless projection of one RFC 5545 VALARM attached to a VTODO.
///
/// Unknown properties are retained when a supported trigger is edited. This
/// is important for alarms created by another CalDAV client.
final class IcalTaskAlarm {
  IcalTaskAlarm._(this._properties);

  factory IcalTaskAlarm.fromComponent(IcalComponent component) {
    if (component.name != 'VALARM') throw _invalidAlarm();
    return IcalTaskAlarm._([
      for (final property in component.properties)
        _AlarmProperty(
          name: property.name,
          value: property.rawValue,
          parameters: [
            for (final parameter in property.parameters)
              IcalParameter(
                name: parameter.name,
                values: List.unmodifiable(parameter.values),
                wasQuoted: parameter.wasQuoted,
              ),
          ],
        ),
    ]);
  }

  factory IcalTaskAlarm.fromJson(Map<String, Object?> json) {
    final values = json['properties'];
    if (values is! List) throw _invalidAlarm();
    final properties = <_AlarmProperty>[];
    for (final value in values) {
      if (value is! Map) throw _invalidAlarm();
      final map = value.cast<Object?, Object?>();
      final name = map['name']?.toString().trim().toUpperCase();
      final rawValue = map['value'];
      if (name == null ||
          name.isEmpty ||
          rawValue is! String ||
          !_propertyName.hasMatch(name)) {
        throw _invalidAlarm();
      }
      final parameters = <IcalParameter>[];
      final rawParameters = map['parameters'];
      if (rawParameters != null) {
        if (rawParameters is! List) throw _invalidAlarm();
        for (final rawParameter in rawParameters) {
          if (rawParameter is! Map) throw _invalidAlarm();
          final parameter = rawParameter.cast<Object?, Object?>();
          final parameterName = parameter['name']
              ?.toString()
              .trim()
              .toUpperCase();
          final parameterValues = parameter['values'];
          if (parameterName == null ||
              !_propertyName.hasMatch(parameterName) ||
              parameterValues is! List) {
            throw _invalidAlarm();
          }
          parameters.add(
            IcalParameter(
              name: parameterName,
              values: [for (final item in parameterValues) item.toString()],
              wasQuoted: parameter['wasQuoted'] == true,
            ),
          );
        }
      }
      properties.add(
        _AlarmProperty(
          name: name,
          value: rawValue,
          parameters: List.unmodifiable(parameters),
        ),
      );
    }
    return IcalTaskAlarm._(List.unmodifiable(properties));
  }

  factory IcalTaskAlarm.displayAbsolute(
    DateTime value, {
    String description = 'This is a todo reminder.',
  }) => IcalTaskAlarm._([
    const _AlarmProperty(name: 'ACTION', value: 'DISPLAY'),
    _AlarmProperty(name: 'DESCRIPTION', value: encodeIcalText(description)),
    _AlarmProperty(
      name: 'TRIGGER',
      value: _utcIcal(value),
      parameters: const [
        IcalParameter(name: 'VALUE', values: ['DATE-TIME'], wasQuoted: false),
      ],
    ),
  ]);

  factory IcalTaskAlarm.displayRelative(
    Duration offset, {
    required bool relatedToDue,
    String description = 'This is a todo reminder.',
  }) => IcalTaskAlarm._([
    const _AlarmProperty(name: 'ACTION', value: 'DISPLAY'),
    _AlarmProperty(name: 'DESCRIPTION', value: encodeIcalText(description)),
    _AlarmProperty(
      name: 'TRIGGER',
      value: _duration(offset),
      parameters: [
        IcalParameter(
          name: 'RELATED',
          values: [relatedToDue ? 'END' : 'START'],
          wasQuoted: false,
        ),
      ],
    ),
  ]);

  final List<_AlarmProperty> _properties;

  String get action => _first('ACTION')?.value.toUpperCase() ?? '';
  String? get description => _first('DESCRIPTION')?.value;
  String get triggerRaw => _first('TRIGGER')?.value ?? '';

  bool get _hasSingleTrigger =>
      _properties.where((property) => property.name == 'TRIGGER').length == 1;

  bool get isAbsolute =>
      _hasSingleTrigger &&
      (_first('TRIGGER')!.parameter('VALUE')?.toUpperCase() == 'DATE-TIME' ||
          RegExp(r'^\d{8}T\d{6}Z$').hasMatch(triggerRaw));

  bool get isRelative {
    if (!_hasSingleTrigger || isAbsolute) return false;
    try {
      return parseIcalDuration(triggerRaw) != null;
    } on DavException {
      return false;
    }
  }

  bool get isRelatedToDue =>
      _hasSingleTrigger &&
      _first('TRIGGER')!.parameter('RELATED')?.toUpperCase() == 'END';

  Duration? get relativeOffset {
    if (!isRelative) return null;
    return parseIcalDuration(triggerRaw)?.duration;
  }

  DateTime? get absoluteUtc {
    if (!isAbsolute || !RegExp(r'^\d{8}T\d{6}Z$').hasMatch(triggerRaw)) {
      return null;
    }
    final value = triggerRaw;
    return DateTime.utc(
      int.parse(value.substring(0, 4)),
      int.parse(value.substring(4, 6)),
      int.parse(value.substring(6, 8)),
      int.parse(value.substring(9, 11)),
      int.parse(value.substring(11, 13)),
      int.parse(value.substring(13, 15)),
    );
  }

  bool get canEditTrigger => isRelative || absoluteUtc != null;

  bool canEditTriggerFor({required bool allDay}) {
    if (absoluteUtc != null) return true;
    final offset = relativeOffset;
    if (offset == null || isRelatedToDue) return false;
    if (!allDay && offset > Duration.zero) return false;
    if (allDay && offset > const Duration(days: 1)) return false;
    return true;
  }

  IcalTaskAlarm withAbsoluteTrigger(DateTime value) =>
      _withTrigger(_utcIcal(value), const [
        IcalParameter(name: 'VALUE', values: ['DATE-TIME'], wasQuoted: false),
      ]);

  IcalTaskAlarm withRelativeTrigger(
    Duration offset, {
    required bool relatedToDue,
  }) => _withTrigger(_duration(offset), [
    IcalParameter(
      name: 'RELATED',
      values: [relatedToDue ? 'END' : 'START'],
      wasQuoted: false,
    ),
  ]);

  IcalTaskAlarm _withTrigger(String value, List<IcalParameter> parameters) {
    final result = <_AlarmProperty>[];
    for (final property in _properties) {
      result.add(
        property.name == 'TRIGGER'
            ? _AlarmProperty(
                name: 'TRIGGER',
                value: value,
                parameters: List.unmodifiable(parameters),
              )
            : property,
      );
    }
    return IcalTaskAlarm._(List.unmodifiable(result));
  }

  IcalComponent toComponent() => IcalComponent(
    name: 'VALARM',
    children: [
      for (final property in _properties)
        IcalProperty(
          group: null,
          name: property.name,
          parameters: [
            for (final parameter in property.parameters)
              IcalParameter(
                name: parameter.name,
                values: List.of(parameter.values),
                wasQuoted: parameter.wasQuoted,
              ),
          ],
          rawValue: property.value,
          originalPhysicalLines: const [],
          isDirty: true,
        ),
    ],
    originalBeginLine: 'BEGIN:VALARM',
    originalEndLine: 'END:VALARM',
    structurallyDirty: true,
  );

  Map<String, Object?> toJson() => {
    'properties': [
      for (final property in _properties)
        {
          'name': property.name,
          'value': property.value,
          if (property.parameters.isNotEmpty)
            'parameters': [
              for (final parameter in property.parameters)
                {
                  'name': parameter.name,
                  'values': parameter.values,
                  if (parameter.wasQuoted) 'wasQuoted': true,
                },
            ],
        },
    ],
  };

  @override
  bool operator ==(Object other) =>
      other is IcalTaskAlarm &&
      const DeepCollectionEquality().equals(toJson(), other.toJson());

  @override
  int get hashCode => const DeepCollectionEquality().hash(toJson());

  _AlarmProperty? _first(String name) =>
      _properties.firstWhereOrNull((property) => property.name == name);
}

enum IcalAllDayAlarmUnit { days, weeks }

/// Editable representation of a relative alarm on an all-day task.
///
/// Nextcloud presents these alarms as a number of days or weeks before the
/// task, followed by a wall-clock time. The corresponding VALARM trigger is a
/// signed duration relative to the task's midnight boundary.
final class IcalAllDayAlarmOffset {
  const IcalAllDayAlarmOffset({
    required this.amount,
    required this.unit,
    required this.hour,
    required this.minute,
  });

  factory IcalAllDayAlarmOffset.fromDuration(Duration offset) {
    final signedSeconds = offset.inSeconds;
    final isBefore = signedSeconds < 0;
    final absoluteSeconds = signedSeconds.abs();
    final wholeDays = isBefore
        ? (absoluteSeconds + Duration.secondsPerDay - 1) ~/
              Duration.secondsPerDay
        : absoluteSeconds ~/ Duration.secondsPerDay;
    final timeSeconds = isBefore
        ? wholeDays * Duration.secondsPerDay - absoluteSeconds
        : absoluteSeconds % Duration.secondsPerDay;
    final useWeeks = wholeDays != 0 && wholeDays % 7 == 0;

    return IcalAllDayAlarmOffset(
      amount: useWeeks ? wholeDays ~/ 7 : wholeDays,
      unit: useWeeks ? IcalAllDayAlarmUnit.weeks : IcalAllDayAlarmUnit.days,
      hour: timeSeconds ~/ Duration.secondsPerHour,
      minute:
          (timeSeconds % Duration.secondsPerHour) ~/ Duration.secondsPerMinute,
    );
  }

  final int amount;
  final IcalAllDayAlarmUnit unit;
  final int hour;
  final int minute;

  Duration toDuration() {
    if (amount < 0 || hour < 0 || hour > 23 || minute < 0 || minute > 59) {
      throw ArgumentError('Invalid all-day reminder offset.');
    }
    final days = amount * (unit == IcalAllDayAlarmUnit.weeks ? 7 : 1);
    final timeSeconds =
        hour * Duration.secondsPerHour + minute * Duration.secondsPerMinute;
    return Duration(
      seconds: days == 0
          ? timeSeconds
          : timeSeconds - days * Duration.secondsPerDay,
    );
  }
}

List<IcalTaskAlarm> decodeIcalTaskAlarms(String? source) {
  if (source == null || source.isEmpty) return const [];
  try {
    final decoded = jsonDecode(source);
    if (decoded is! List) throw _invalidAlarm();
    return List.unmodifiable([
      for (final item in decoded)
        IcalTaskAlarm.fromJson((item as Map).cast<String, Object?>()),
    ]);
  } on DavException {
    rethrow;
  } on Object {
    throw _invalidAlarm();
  }
}

String encodeIcalTaskAlarms(List<IcalTaskAlarm> alarms) =>
    jsonEncode([for (final alarm in alarms) alarm.toJson()]);

final class _AlarmProperty {
  const _AlarmProperty({
    required this.name,
    required this.value,
    this.parameters = const [],
  });

  final String name;
  final String value;
  final List<IcalParameter> parameters;

  String? parameter(String name) {
    final upper = name.toUpperCase();
    return parameters
        .firstWhereOrNull((parameter) => parameter.name == upper)
        ?.values
        .firstOrNull;
  }
}

final _propertyName = RegExp(r'^[A-Z0-9-]+$');

String _duration(Duration value) {
  var seconds = value.inSeconds;
  final negative = seconds < 0;
  seconds = seconds.abs();
  final days = seconds ~/ Duration.secondsPerDay;
  seconds %= Duration.secondsPerDay;
  final hours = seconds ~/ Duration.secondsPerHour;
  seconds %= Duration.secondsPerHour;
  final minutes = seconds ~/ Duration.secondsPerMinute;
  seconds %= Duration.secondsPerMinute;
  final buffer = StringBuffer(negative ? '-P' : 'P');
  if (days != 0) buffer.write('${days}D');
  if (hours != 0 || minutes != 0 || seconds != 0 || days == 0) {
    buffer.write('T');
    if (hours != 0) buffer.write('${hours}H');
    if (minutes != 0) buffer.write('${minutes}M');
    if (seconds != 0 || (hours == 0 && minutes == 0)) {
      buffer.write('${seconds}S');
    }
  }
  return buffer.toString();
}

String _utcIcal(DateTime value) {
  final utc = value.toUtc();
  String two(int number) => number.toString().padLeft(2, '0');
  return '${utc.year.toString().padLeft(4, '0')}${two(utc.month)}'
      '${two(utc.day)}T${two(utc.hour)}${two(utc.minute)}${two(utc.second)}Z';
}

DavException _invalidAlarm() => const DavException(
  kind: DavErrorKind.invalidCalendarData,
  code: 'IcalTaskAlarmInvalid',
  safeMessage: 'A task reminder was invalid.',
);

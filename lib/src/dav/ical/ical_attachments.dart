import 'dart:convert';
import 'dart:typed_data';

import 'ical_document.dart';
import 'ical_semantics.dart';

// Match the existing decoded calendar-resource bound. Listing attachments never
// allocates decoded bodies; bytes are allocated only after an explicit Save.
const maximumIcalAttachmentBytes = 16 * 1024 * 1024;
const maximumIcalAttachments = 256;

enum IcalAttachmentKind { uri, binary }

/// A read-only view of one ATTACH. The cached resource is never rewritten.
final class IcalAttachment {
  IcalAttachment._(IcalProperty property, this.index, this.fromAlarm)
    : _property = property.deepCopy();

  final IcalProperty _property;
  final int index;
  final bool fromAlarm;

  IcalAttachmentKind get kind =>
      _property.parameterValue('VALUE')?.toUpperCase() == 'BINARY'
      ? IcalAttachmentKind.binary
      : IcalAttachmentKind.uri;

  String? parameterValue(String name) => _property.parameterValue(name);

  /// Includes unknown, repeated and RFC6868-decoded parameter values.
  List<IcalParameter> get parameters => [
    for (final parameter in _property.parameters)
      IcalParameter(
        name: parameter.name,
        values: List.unmodifiable(parameter.values),
        wasQuoted: parameter.wasQuoted,
      ),
  ];

  List<String> get originalPhysicalLines =>
      List.unmodifiable(_property.originalPhysicalLines);

  String get rawValue => _property.rawValue;

  String get mimeType {
    final value = parameterValue('FMTTYPE');
    return value != null && _mimeType.hasMatch(value)
        ? value
        : 'application/octet-stream';
  }

  String? get suggestedName =>
      parameterValue('FILENAME') ??
      parameterValue('X-FILENAME') ??
      parameterValue('X-NAME');

  String? get uri {
    if (kind != IcalAttachmentKind.uri || !_validParameters()) return null;
    return rawValue;
  }

  bool get canSave {
    if (kind != IcalAttachmentKind.binary || !_validParameters()) return false;
    return _binaryLength(rawValue) != null;
  }

  Uint8List decode() {
    if (!canSave) throw const FormatException('Invalid inline attachment.');
    return base64.decode(rawValue);
  }

  bool _validParameters() {
    for (final name in ['VALUE', 'ENCODING', 'FMTTYPE']) {
      final parameters = _property.parametersNamed(name).toList();
      if (parameters.length > 1 ||
          (parameters.isNotEmpty && parameters.single.values.length != 1)) {
        return false;
      }
    }
    final value = parameterValue('VALUE')?.toUpperCase();
    final encoding = parameterValue('ENCODING')?.toUpperCase();
    final format = parameterValue('FMTTYPE');
    if (format != null && !_mimeType.hasMatch(format)) return false;
    return kind == IcalAttachmentKind.binary
        ? value == 'BINARY' && encoding == 'BASE64'
        : (value == null || value == 'URI') && encoding == null;
  }
}

final _mimeType = RegExp(
  r"^[A-Za-z0-9!#$%&'*+.^_`|~-]{1,127}/[A-Za-z0-9!#$%&'*+.^_`|~-]{1,127}$",
);

/// Strict RFC4648 base64, including padding and unused pad bits. Dart's decoder
/// additionally accepts normalized URL/percent encodings; ATTACH must not.
int? _binaryLength(String value) {
  final length = value.length;
  if (length % 4 != 0 || length > ((maximumIcalAttachmentBytes + 2) ~/ 3) * 4) {
    return null;
  }
  if (length == 0) return 0;
  final padding = value.endsWith('==')
      ? 2
      : value.endsWith('=')
      ? 1
      : 0;
  final size = length ~/ 4 * 3 - padding;
  if (size > maximumIcalAttachmentBytes) return null;
  var last = 0;
  for (var index = 0; index < length - padding; index++) {
    final unit = value.codeUnitAt(index);
    last = switch (unit) {
      >= 65 && <= 90 => unit - 65,
      >= 97 && <= 122 => unit - 97 + 26,
      >= 48 && <= 57 => unit - 48 + 52,
      43 => 62,
      47 => 63,
      _ => -1,
    };
    if (last < 0) return null;
  }
  if ((padding == 2 && (last & 15) != 0) || (padding == 1 && (last & 3) != 0)) {
    return null;
  }
  return size;
}

/// Selects the same master/detached/range attachment source as event projection.
/// Unspecified attachments on an exception inherit the master's list. No
/// recurrence rules, temporal values, or resource bytes are changed here.
List<IcalAttachment> readIcalAttachments(
  String source,
  IcalComponentKey target, {
  String? occurrenceKey,
}) {
  if (source.length > maximumIcalAttachmentBytes ||
      utf8.encode(source).length > maximumIcalAttachmentBytes) {
    throw const FormatException('The calendar resource exceeds the limit.');
  }
  final document = IcalDocument.parse(source);
  final selector = IcalDocumentPatcher(document);
  var component = selector.requireComponent(target);
  final master = target.recurrenceIdKey == null
      ? component
      : selector.requireComponent(
          IcalComponentKey(
            componentType: target.componentType,
            uid: target.uid,
          ),
        );
  if (target.recurrenceIdKey == null && occurrenceKey != null) {
    final anchor = parseIcalTemporal(
      master.firstProperty('DTSTART') ?? master.firstProperty('DUE'),
    );
    if (anchor != null) {
      final position = _occurrencePosition(occurrenceKey, anchor);
      DateTime? latest;
      for (final candidate in document.calendarComponents) {
        if (candidate.name != target.componentType.toUpperCase() ||
            candidate.firstProperty('UID')?.rawValue != target.uid) {
          continue;
        }
        final property = candidate.firstProperty('RECURRENCE-ID');
        if (property?.parameterValue('RANGE')?.toUpperCase() !=
            'THISANDFUTURE') {
          continue;
        }
        final value = parseIcalTemporal(property)!;
        if (value.kind != anchor.kind ||
            value.timeZoneId != anchor.timeZoneId) {
          throw const FormatException('Inconsistent recurrence identity.');
        }
        if (!value.localValue.isAfter(position) &&
            (latest == null || value.localValue.isAfter(latest))) {
          latest = value.localValue;
          component = candidate;
        }
      }
    }
  }
  var properties = component.propertiesNamed('ATTACH');
  if (properties.isEmpty && component != master) {
    properties = master.propertiesNamed('ATTACH');
  }
  final result = <IcalAttachment>[];
  void append(IcalProperty property, {bool fromAlarm = false}) {
    if (result.length == maximumIcalAttachments) {
      throw const FormatException('Too many calendar attachments.');
    }
    result.add(IcalAttachment._(property, result.length, fromAlarm));
  }

  for (final property in properties) {
    append(property);
  }
  // Preserve the existing projection's alarm inheritance. This only exposes
  // the attachment bytes/references; it never executes or plays an alarm.
  final alarmSource =
      component.name == 'VTODO' && component.componentsNamed('VALARM').isEmpty
      ? master
      : component;
  for (final alarm in alarmSource.componentsNamed('VALARM')) {
    for (final property in alarm.propertiesNamed('ATTACH')) {
      append(property, fromAlarm: true);
    }
  }
  return List.unmodifiable(result);
}

DateTime _occurrencePosition(String key, IcalTemporalValue anchor) {
  final prefix = switch (anchor.kind) {
    IcalTemporalKind.date => 'DATE:',
    IcalTemporalKind.floatingDateTime => 'FLOATING:',
    IcalTemporalKind.utcDateTime => 'UTC:',
    IcalTemporalKind.tzidDateTime => 'TZID=${anchor.timeZoneId}:',
  };
  final position = key.startsWith(prefix)
      ? DateTime.tryParse(key.substring(prefix.length))
      : null;
  if (position == null) {
    throw const FormatException('The occurrence identity is unavailable.');
  }
  return anchor.kind == IcalTemporalKind.utcDateTime
      ? position.toUtc()
      : DateTime.utc(
          position.year,
          position.month,
          position.day,
          position.hour,
          position.minute,
          position.second,
          position.millisecond,
          position.microsecond,
        );
}

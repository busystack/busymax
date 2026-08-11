import 'dart:convert';

import '../dav_errors.dart';

const icalDocumentParserVersion = 1;

final class IcalParameter {
  const IcalParameter({
    required this.name,
    required this.values,
    required this.wasQuoted,
  });

  final String name;
  final List<String> values;
  final bool wasQuoted;

  IcalParameter copyWith({List<String>? values, bool? wasQuoted}) =>
      IcalParameter(
        name: name,
        values: values ?? this.values,
        wasQuoted: wasQuoted ?? this.wasQuoted,
      );
}

sealed class IcalNode {
  bool get isDirty;
  IcalNode deepCopy();
}

final class IcalProperty extends IcalNode {
  IcalProperty({
    required this.group,
    required this.name,
    required this.parameters,
    required this.rawValue,
    required this.originalPhysicalLines,
    this.isDirty = false,
  });

  final String? group;
  final String name;
  final List<IcalParameter> parameters;
  String rawValue;
  final List<String> originalPhysicalLines;

  @override
  bool isDirty;

  String? parameterValue(String name) {
    final upper = name.toUpperCase();
    for (final parameter in parameters) {
      if (parameter.name == upper && parameter.values.isNotEmpty) {
        return parameter.values.first;
      }
    }
    return null;
  }

  Iterable<IcalParameter> parametersNamed(String name) {
    final upper = name.toUpperCase();
    return parameters.where((parameter) => parameter.name == upper);
  }

  String get decodedTextValue => decodeIcalText(rawValue);

  @override
  IcalProperty deepCopy() => IcalProperty(
    group: group,
    name: name,
    parameters: [
      for (final parameter in parameters)
        IcalParameter(
          name: parameter.name,
          values: List.of(parameter.values),
          wasQuoted: parameter.wasQuoted,
        ),
    ],
    rawValue: rawValue,
    originalPhysicalLines: List.of(originalPhysicalLines),
    isDirty: isDirty,
  );

  String serializeLogicalLine() {
    final buffer = StringBuffer();
    if (group != null) {
      buffer
        ..write(group)
        ..write('.');
    }
    buffer.write(name);
    for (final parameter in parameters) {
      buffer
        ..write(';')
        ..write(parameter.name)
        ..write('=');
      for (var index = 0; index < parameter.values.length; index += 1) {
        if (index > 0) buffer.write(',');
        final value = parameter.values[index];
        final quote = parameter.wasQuoted || _parameterNeedsQuotes(value);
        if (quote) buffer.write('"');
        buffer.write(_escapeParameterValue(value));
        if (quote) buffer.write('"');
      }
    }
    buffer
      ..write(':')
      ..write(rawValue);
    return buffer.toString();
  }
}

final class IcalComponent extends IcalNode {
  IcalComponent({
    required this.name,
    required this.children,
    required this.originalBeginLine,
    required this.originalEndLine,
    this.structurallyDirty = false,
  });

  final String name;
  final List<IcalNode> children;
  final String originalBeginLine;
  final String originalEndLine;
  bool structurallyDirty;

  @override
  bool get isDirty =>
      structurallyDirty || children.any((child) => child.isDirty);

  Iterable<IcalProperty> get properties => children.whereType<IcalProperty>();
  Iterable<IcalComponent> get components => children.whereType<IcalComponent>();

  Iterable<IcalProperty> propertiesNamed(String name) {
    final upper = name.toUpperCase();
    return properties.where((property) => property.name == upper);
  }

  IcalProperty? firstProperty(String name) => propertiesNamed(name).firstOrNull;

  Iterable<IcalComponent> componentsNamed(String name) {
    final upper = name.toUpperCase();
    return components.where((component) => component.name == upper);
  }

  @override
  IcalComponent deepCopy() => IcalComponent(
    name: name,
    children: [for (final child in children) child.deepCopy()],
    originalBeginLine: originalBeginLine,
    originalEndLine: originalEndLine,
    structurallyDirty: structurallyDirty,
  );
}

final class IcalDocument {
  IcalDocument._({required this.root, required this.originalSource});

  factory IcalDocument.create({
    required List<IcalComponent> components,
    String productIdentifier = '-//BusyMax//CalDAV Client//EN',
  }) {
    IcalProperty property(String name, String value) => IcalProperty(
      group: null,
      name: name,
      parameters: const [],
      rawValue: value,
      originalPhysicalLines: const [],
      isDirty: true,
    );
    return IcalDocument._(
      root: IcalComponent(
        name: 'VCALENDAR',
        children: [
          property('PRODID', productIdentifier),
          property('VERSION', '2.0'),
          property('CALSCALE', 'GREGORIAN'),
          ...components,
        ],
        originalBeginLine: 'BEGIN:VCALENDAR',
        originalEndLine: 'END:VCALENDAR',
        structurallyDirty: true,
      ),
      originalSource: '',
    );
  }

  factory IcalDocument.parse(
    String source, {
    int maximumUnfoldedLineBytes = 1024 * 1024,
    int maximumComponents = 10000,
    int maximumProperties = 200000,
  }) {
    if (source.isEmpty) {
      throw _icalError('IcalEmptyDocument', 'The iCalendar resource is empty.');
    }
    final logicalLines = _unfoldLines(
      source,
      maximumUnfoldedLineBytes: maximumUnfoldedLineBytes,
    );
    final stack = <IcalComponent>[];
    IcalComponent? root;
    var components = 0;
    var properties = 0;
    for (final line in logicalLines) {
      final parsed = _parseProperty(line);
      if (parsed.name == 'BEGIN') {
        final name = parsed.rawValue.trim().toUpperCase();
        if (!_validToken(name)) {
          throw _icalError(
            'IcalInvalidComponentName',
            'The iCalendar resource contains an invalid component name.',
          );
        }
        components += 1;
        if (components > maximumComponents) {
          throw _icalError(
            'IcalComponentLimitExceeded',
            'The iCalendar resource contains too many components.',
          );
        }
        final component = IcalComponent(
          name: name,
          children: [],
          originalBeginLine: line.logical,
          originalEndLine: 'END:$name',
        );
        if (stack.isEmpty) {
          if (root != null) {
            throw _icalError(
              'IcalMultipleRoots',
              'The iCalendar resource contains multiple root components.',
            );
          }
          root = component;
        } else {
          stack.last.children.add(component);
        }
        stack.add(component);
        continue;
      }
      if (parsed.name == 'END') {
        final name = parsed.rawValue.trim().toUpperCase();
        if (stack.isEmpty || stack.last.name != name) {
          throw _icalError(
            'IcalMismatchedComponentEnd',
            'The iCalendar resource contains mismatched component boundaries.',
          );
        }
        final ended = stack.removeLast();
        ended.structurallyDirty = false;
        // Preserve the original spelling/folding of the END line.
        ended._setOriginalEndLineForParse(line.logical);
        continue;
      }
      if (stack.isEmpty) {
        throw _icalError(
          'IcalPropertyOutsideComponent',
          'The iCalendar resource contains data outside a component.',
        );
      }
      properties += 1;
      if (properties > maximumProperties) {
        throw _icalError(
          'IcalPropertyLimitExceeded',
          'The iCalendar resource contains too many properties.',
        );
      }
      stack.last.children.add(parsed);
    }
    if (stack.isNotEmpty || root == null) {
      throw _icalError(
        'IcalUnclosedComponent',
        'The iCalendar resource contains an unclosed component.',
      );
    }
    if (root.name != 'VCALENDAR') {
      throw _icalError(
        'IcalExpectedVcalendar',
        'The calendar object resource is not a VCALENDAR.',
      );
    }
    return IcalDocument._(root: root, originalSource: source);
  }

  final IcalComponent root;
  final String originalSource;

  bool get isDirty => root.isDirty;

  Iterable<IcalComponent> get calendarComponents => root.components;

  IcalDocument deepCopy() =>
      IcalDocument._(root: root.deepCopy(), originalSource: originalSource);

  String serialize({bool canonicalizeUntouched = false}) {
    if (!isDirty && !canonicalizeUntouched) {
      return originalSource;
    }
    final output = StringBuffer();
    void writeComponent(IcalComponent component) {
      output
        ..write(_foldContentLine('BEGIN:${component.name}'))
        ..write('\r\n');
      for (final child in component.children) {
        switch (child) {
          case final IcalProperty property:
            if (!property.isDirty && !canonicalizeUntouched) {
              final logical = property.originalPhysicalLines.isEmpty
                  ? property.serializeLogicalLine()
                  : _unfoldPhysicalLines(property.originalPhysicalLines);
              output
                ..write(_foldContentLine(logical))
                ..write('\r\n');
            } else {
              output
                ..write(_foldContentLine(property.serializeLogicalLine()))
                ..write('\r\n');
            }
          case final IcalComponent nested:
            writeComponent(nested);
        }
      }
      output
        ..write(_foldContentLine('END:${component.name}'))
        ..write('\r\n');
    }

    writeComponent(root);
    return output.toString();
  }
}

String _unfoldPhysicalLines(List<String> physicalLines) {
  final output = StringBuffer(physicalLines.first);
  for (final line in physicalLines.skip(1)) {
    output.write(
      line.startsWith(' ') || line.startsWith('\t') ? line.substring(1) : line,
    );
  }
  return output.toString();
}

extension on IcalComponent {
  void _setOriginalEndLineForParse(String value) {
    // `originalEndLine` is intentionally informational. Components serialize
    // canonical BEGIN/END markers after mutation, while an untouched document
    // returns the byte-for-byte original source. No state update is required.
    if (value.isEmpty) {
      throw StateError('An END content line cannot be empty.');
    }
  }
}

final class IcalComponentKey {
  const IcalComponentKey({
    required this.componentType,
    required this.uid,
    this.recurrenceIdKey,
  });

  final String componentType;
  final String uid;
  final String? recurrenceIdKey;
}

final class IcalDocumentPatcher {
  IcalDocumentPatcher(this.document);

  final IcalDocument document;

  IcalComponent requireComponent(IcalComponentKey key) {
    final matches = document.calendarComponents
        .where((component) {
          if (component.name != key.componentType.toUpperCase()) return false;
          if (component.firstProperty('UID')?.rawValue != key.uid) return false;
          return icalRecurrenceIdKey(
                component.firstProperty('RECURRENCE-ID'),
              ) ==
              key.recurrenceIdKey;
        })
        .toList(growable: false);
    if (matches.length != 1) {
      throw _icalError(
        'IcalTargetComponentAmbiguous',
        'The requested iCalendar component could not be identified uniquely.',
      );
    }
    return matches.single;
  }

  void replaceSingletonRaw(
    IcalComponentKey key,
    String propertyName,
    String? rawValue, {
    List<IcalParameter> parameters = const [],
  }) {
    final component = requireComponent(key);
    _replaceSingleton(
      component,
      propertyName,
      rawValue,
      parameters: parameters,
    );
  }

  void replaceSingletonText(
    IcalComponentKey key,
    String propertyName,
    String? value,
  ) {
    replaceSingletonRaw(
      key,
      propertyName,
      value == null ? null : encodeIcalText(value),
    );
  }

  void replaceRepeatedRaw(
    IcalComponentKey key,
    String propertyName,
    List<({String value, List<IcalParameter> parameters})> values,
  ) {
    final component = requireComponent(key);
    final upper = _validatePropertyName(propertyName);
    final indexes = <int>[];
    for (var index = 0; index < component.children.length; index += 1) {
      final node = component.children[index];
      if (node is IcalProperty && node.name == upper) indexes.add(index);
    }
    final insertionIndex = indexes.firstOrNull ?? component.children.length;
    component.children.removeWhere(
      (node) => node is IcalProperty && node.name == upper,
    );
    component.children.insertAll(
      insertionIndex,
      values.map(
        (entry) => IcalProperty(
          group: null,
          name: upper,
          parameters: List.of(entry.parameters),
          rawValue: entry.value,
          originalPhysicalLines: const [],
          isDirty: true,
        ),
      ),
    );
    component.structurallyDirty = true;
  }

  void addComponent(IcalComponent component) {
    document.root.children.add(component);
    document.root.structurallyDirty = true;
  }

  void removeComponent(IcalComponentKey key) {
    final component = requireComponent(key);
    document.root.children.remove(component);
    document.root.structurallyDirty = true;
  }

  void _replaceSingleton(
    IcalComponent component,
    String propertyName,
    String? rawValue, {
    required List<IcalParameter> parameters,
  }) {
    final upper = _validatePropertyName(propertyName);
    final indexes = <int>[];
    for (var index = 0; index < component.children.length; index += 1) {
      final child = component.children[index];
      if (child is IcalProperty && child.name == upper) indexes.add(index);
    }
    if (rawValue == null) {
      if (indexes.isNotEmpty) {
        component.children.removeWhere(
          (node) => node is IcalProperty && node.name == upper,
        );
        component.structurallyDirty = true;
      }
      return;
    }
    final replacement = IcalProperty(
      group: null,
      name: upper,
      parameters: List.of(parameters),
      rawValue: rawValue,
      originalPhysicalLines: const [],
      isDirty: true,
    );
    if (indexes.isEmpty) {
      final endOfIdentity = component.children.lastIndexWhere(
        (node) =>
            node is IcalProperty &&
            const {
              'UID',
              'RECURRENCE-ID',
              'DTSTAMP',
              'SEQUENCE',
            }.contains(node.name),
      );
      component.children.insert(endOfIdentity + 1, replacement);
    } else {
      component.children[indexes.first] = replacement;
      for (final index in indexes.skip(1).toList().reversed) {
        component.children.removeAt(index);
      }
    }
    component.structurallyDirty = true;
  }
}

String? icalRecurrenceIdKey(IcalProperty? property) {
  if (property == null) return null;
  final valueKind = property.parameterValue('VALUE')?.toUpperCase();
  final tzid = property.parameterValue('TZID');
  final range = property.parameterValue('RANGE')?.toUpperCase();
  return [
    if (valueKind != null) 'VALUE=$valueKind',
    if (tzid != null) 'TZID=$tzid',
    if (range != null) 'RANGE=$range',
    property.rawValue,
  ].join(':');
}

String decodeIcalText(String source) {
  final output = StringBuffer();
  for (var index = 0; index < source.length; index += 1) {
    final character = source[index];
    if (character != r'\' || index + 1 >= source.length) {
      output.write(character);
      continue;
    }
    final escaped = source[index += 1];
    output.write(switch (escaped) {
      'n' || 'N' => '\n',
      ',' => ',',
      ';' => ';',
      r'\' => r'\',
      _ => escaped,
    });
  }
  return output.toString();
}

String encodeIcalText(String source) => source
    .replaceAll(r'\', r'\\')
    .replaceAll('\r\n', r'\n')
    .replaceAll('\r', r'\n')
    .replaceAll('\n', r'\n')
    .replaceAll(';', r'\;')
    .replaceAll(',', r'\,');

final class _UnfoldedLine {
  const _UnfoldedLine({required this.logical, required this.physical});

  final String logical;
  final List<String> physical;
}

List<_UnfoldedLine> _unfoldLines(
  String source, {
  required int maximumUnfoldedLineBytes,
}) {
  final physicalLines = source.split(RegExp(r'\r\n|\n|\r'));
  if (physicalLines.isNotEmpty && physicalLines.last.isEmpty) {
    physicalLines.removeLast();
  }
  final result = <_UnfoldedLine>[];
  for (final physical in physicalLines) {
    if ((physical.startsWith(' ') || physical.startsWith('\t')) &&
        result.isNotEmpty) {
      final previous = result.removeLast();
      final logical = '${previous.logical}${physical.substring(1)}';
      _checkLineLength(logical, maximumUnfoldedLineBytes);
      result.add(
        _UnfoldedLine(
          logical: logical,
          physical: [...previous.physical, physical],
        ),
      );
    } else {
      _checkLineLength(physical, maximumUnfoldedLineBytes);
      result.add(_UnfoldedLine(logical: physical, physical: [physical]));
    }
  }
  return result;
}

void _checkLineLength(String value, int maximumBytes) {
  if (utf8.encode(value).length > maximumBytes) {
    throw _icalError(
      'IcalContentLineLimitExceeded',
      'An iCalendar content line exceeded the configured size limit.',
    );
  }
}

IcalProperty _parseProperty(_UnfoldedLine source) {
  final colon = _findUnquoted(source.logical, ':');
  if (colon <= 0) {
    throw _icalError(
      'IcalMalformedContentLine',
      'The iCalendar resource contains a malformed content line.',
    );
  }
  final prefix = source.logical.substring(0, colon);
  final rawValue = source.logical.substring(colon + 1);
  final segments = _splitUnquoted(prefix, ';');
  final namePart = segments.removeAt(0);
  final dot = namePart.indexOf('.');
  final group = dot < 0 ? null : namePart.substring(0, dot);
  final name = (dot < 0 ? namePart : namePart.substring(dot + 1)).toUpperCase();
  if (!_validToken(name) || (group != null && !_validToken(group))) {
    throw _icalError(
      'IcalInvalidPropertyName',
      'The iCalendar resource contains an invalid property name.',
    );
  }
  final parameters = <IcalParameter>[];
  for (final segment in segments) {
    final equals = _findUnquoted(segment, '=');
    if (equals <= 0) {
      throw _icalError(
        'IcalMalformedParameter',
        'The iCalendar resource contains a malformed property parameter.',
      );
    }
    final parameterName = segment.substring(0, equals).toUpperCase();
    if (!_validToken(parameterName)) {
      throw _icalError(
        'IcalInvalidParameterName',
        'The iCalendar resource contains an invalid parameter name.',
      );
    }
    final rawParameterValue = segment.substring(equals + 1);
    final quoted =
        rawParameterValue.length >= 2 &&
        rawParameterValue.startsWith('"') &&
        rawParameterValue.endsWith('"');
    final unquoted = quoted
        ? rawParameterValue.substring(1, rawParameterValue.length - 1)
        : rawParameterValue;
    parameters.add(
      IcalParameter(
        name: parameterName,
        values: quoted
            ? [_unescapeParameterValue(unquoted)]
            : _splitUnquoted(
                unquoted,
                ',',
              ).map(_unescapeParameterValue).toList(growable: false),
        wasQuoted: quoted,
      ),
    );
  }
  return IcalProperty(
    group: group,
    name: name,
    parameters: parameters,
    rawValue: rawValue,
    originalPhysicalLines: source.physical,
  );
}

int _findUnquoted(String source, String character) {
  var quoted = false;
  var escaped = false;
  for (var index = 0; index < source.length; index += 1) {
    final value = source[index];
    if (escaped) {
      escaped = false;
      continue;
    }
    if (value == r'\') {
      escaped = true;
      continue;
    }
    if (value == '"') {
      quoted = !quoted;
      continue;
    }
    if (!quoted && value == character) return index;
  }
  return -1;
}

List<String> _splitUnquoted(String source, String separator) {
  final result = <String>[];
  var start = 0;
  var quoted = false;
  var escaped = false;
  for (var index = 0; index < source.length; index += 1) {
    final value = source[index];
    if (escaped) {
      escaped = false;
      continue;
    }
    if (value == r'\') {
      escaped = true;
      continue;
    }
    if (value == '"') {
      quoted = !quoted;
    } else if (!quoted && value == separator) {
      result.add(source.substring(start, index));
      start = index + 1;
    }
  }
  if (quoted) {
    throw _icalError(
      'IcalUnclosedParameterQuote',
      'The iCalendar resource contains an unclosed parameter quote.',
    );
  }
  result.add(source.substring(start));
  return result;
}

String _foldContentLine(String logical) {
  final runes = logical.runes.toList(growable: false);
  final lines = <String>[];
  var current = StringBuffer();
  var currentBytes = 0;
  var limit = 75;
  for (final rune in runes) {
    final value = String.fromCharCode(rune);
    final bytes = utf8.encode(value).length;
    if (currentBytes + bytes > limit && currentBytes > 0) {
      lines.add(current.toString());
      current = StringBuffer();
      currentBytes = 0;
      limit = 74;
    }
    current.write(value);
    currentBytes += bytes;
  }
  lines.add(current.toString());
  return lines.join('\r\n ');
}

String _escapeParameterValue(String value) =>
    value.replaceAll('^', '^^').replaceAll('\n', '^n').replaceAll('"', "^'");

String _unescapeParameterValue(String value) {
  final output = StringBuffer();
  for (var index = 0; index < value.length; index += 1) {
    if (value[index] != '^' || index + 1 >= value.length) {
      output.write(value[index]);
      continue;
    }
    final escaped = value[index += 1];
    output.write(switch (escaped) {
      '^' => '^',
      'n' || 'N' => '\n',
      "'" => '"',
      _ => '^$escaped',
    });
  }
  return output.toString();
}

bool _parameterNeedsQuotes(String value) =>
    value.isEmpty || value.contains(RegExp(r'[:;,]')) || value.trim() != value;

String _validatePropertyName(String value) {
  final upper = value.toUpperCase();
  if (!_validToken(upper)) {
    throw ArgumentError.value(value, 'propertyName', 'Invalid iCalendar name.');
  }
  return upper;
}

bool _validToken(String value) =>
    value.isNotEmpty && RegExp(r'^[A-Za-z0-9-]+$').hasMatch(value);

DavException _icalError(String code, String safeMessage) => DavException(
  kind: DavErrorKind.invalidCalendarData,
  code: code,
  safeMessage: safeMessage,
);

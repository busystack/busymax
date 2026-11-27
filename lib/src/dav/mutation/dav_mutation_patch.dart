import '../ical/ical_timezone.dart';

import 'dart:convert';

import '../../journal/journal_component.dart';
import '../dav_errors.dart';
import '../ical/ical_document.dart';
import '../ical/ical_semantics.dart';

const davMutationPatchSchemaVersion = 1;

enum DavMutationScope {
  object,
  recurrenceMaster,
  recurrenceException,
  occurrence,
  collection,
}

enum DavPatchOperationType {
  setText,
  setRaw,
  replaceRepeatedRaw,
  setTaskProgress,
  setTaskParent,
  replaceAlarm,
  addComponent,
  removeComponent,
  reviseJournal,
  replaceJournalResource,
  replaceJournalChildren,
}

final class DavRawPropertyValue {
  const DavRawPropertyValue({
    required this.value,
    this.parameters = const [],
    this.group,
  });

  final String value;
  final List<IcalParameter> parameters;
  final String? group;

  Map<String, Object?> toJson() => {
    'value': value,
    if (group != null) 'group': group,
    'parameters': [
      for (final parameter in parameters)
        {
          'name': parameter.name,
          'values': parameter.values,
          'wasQuoted': parameter.wasQuoted,
        },
    ],
  };

  factory DavRawPropertyValue.fromJson(Map<String, Object?> json) =>
      DavRawPropertyValue(
        value: _requiredStringAllowEmpty(json, 'value'),
        parameters: _parameters(json['parameters']),
        group: json['group'] as String?,
      );
}

final class DavPatchOperation {
  const DavPatchOperation._({
    required this.type,
    required this.propertyName,
    this.value,
    this.values = const [],
    this.parameters = const [],
    this.preserveParameters = false,
    this.percentComplete,
    this.completedAtUtc,
    this.alarmIndex,
    this.alarm,
    this.component,
    this.componentKey,
  });

  factory DavPatchOperation.setText(String propertyName, String? value) =>
      DavPatchOperation._(
        type: DavPatchOperationType.setText,
        propertyName: _validatedEditableProperty(propertyName),
        value: value,
      );

  factory DavPatchOperation.setRaw(
    String propertyName,
    String? value, {
    List<IcalParameter> parameters = const [],
    bool preserveParameters = false,
  }) => DavPatchOperation._(
    type: DavPatchOperationType.setRaw,
    propertyName: _validatedEditableProperty(propertyName),
    value: value,
    parameters: List.unmodifiable(parameters),
    preserveParameters: preserveParameters,
  );

  factory DavPatchOperation.replaceRepeatedRaw(
    String propertyName,
    List<DavRawPropertyValue> values,
  ) => DavPatchOperation._(
    type: DavPatchOperationType.replaceRepeatedRaw,
    propertyName: _validatedEditableProperty(propertyName),
    values: List.unmodifiable(values),
  );

  factory DavPatchOperation.setTaskProgress(
    int percentComplete, {
    DateTime? completedAtUtc,
  }) {
    if (percentComplete < 0 || percentComplete > 100) {
      throw ArgumentError.value(percentComplete, 'percentComplete');
    }
    return DavPatchOperation._(
      type: DavPatchOperationType.setTaskProgress,
      propertyName: 'TASK-PROGRESS',
      percentComplete: percentComplete,
      completedAtUtc: completedAtUtc?.toUtc(),
    );
  }

  factory DavPatchOperation.setTaskParent(String? parentUid) =>
      DavPatchOperation._(
        type: DavPatchOperationType.setTaskParent,
        propertyName: 'RELATED-TO',
        value: parentUid?.trim(),
      );

  factory DavPatchOperation.replaceAlarm({
    required int alarmIndex,
    IcalComponent? alarm,
  }) {
    if (alarmIndex < 0 || (alarm != null && alarm.name != 'VALARM')) {
      throw ArgumentError('The alarm patch target is invalid.');
    }
    return DavPatchOperation._(
      type: DavPatchOperationType.replaceAlarm,
      propertyName: 'VALARM',
      alarmIndex: alarmIndex,
      alarm: alarm?.deepCopy(),
    );
  }

  factory DavPatchOperation.addComponent(IcalComponent component) {
    if (!const {'VEVENT', 'VTODO', 'VJOURNAL'}.contains(component.name)) {
      throw ArgumentError('Unsupported calendar component.');
    }
    return DavPatchOperation._(
      type: DavPatchOperationType.addComponent,
      propertyName: 'COMPONENT-SET',
      component: component.deepCopy(),
    );
  }

  factory DavPatchOperation.removeComponent({IcalComponentKey? componentKey}) =>
      DavPatchOperation._(
        type: DavPatchOperationType.removeComponent,
        propertyName: 'COMPONENT-SET',
        componentKey: componentKey,
      );

  factory DavPatchOperation.reviseJournal(DateTime revision) =>
      DavPatchOperation._(
        type: DavPatchOperationType.reviseJournal,
        propertyName: 'DTSTAMP',
        value: _utcIcal(revision),
      );

  factory DavPatchOperation.replaceJournalResource(String rawIcs) =>
      DavPatchOperation._(
        type: DavPatchOperationType.replaceJournalResource,
        propertyName: 'COMPONENT-SET',
        value: rawIcs,
      );

  factory DavPatchOperation.replaceJournalChildren(
    Iterable<IcalComponent> children,
  ) => DavPatchOperation._(
    type: DavPatchOperationType.replaceJournalChildren,
    propertyName: 'COMPONENT-SET',
    component: IcalComponent(
      name: 'VJOURNAL',
      originalBeginLine: 'BEGIN:VJOURNAL',
      originalEndLine: 'END:VJOURNAL',
      children: children.map((child) => child.deepCopy()).toList(),
    ),
  );

  factory DavPatchOperation.fromJson(Map<String, Object?> json) {
    final typeName = _requiredString(json, 'type');
    final type = DavPatchOperationType.values
        .where((value) => value.name == typeName)
        .firstOrNull;
    if (type == null) throw _invalidPatch();
    final propertyName = _requiredString(json, 'propertyName');
    return switch (type) {
      DavPatchOperationType.setText => DavPatchOperation.setText(
        propertyName,
        json['value'] as String?,
      ),
      DavPatchOperationType.setRaw => DavPatchOperation.setRaw(
        propertyName,
        json['value'] as String?,
        parameters: _parameters(json['parameters']),
        preserveParameters: json['preserveParameters'] == true,
      ),
      DavPatchOperationType.replaceRepeatedRaw =>
        DavPatchOperation.replaceRepeatedRaw(
          propertyName,
          _mapList(json['values'])
              .map(DavRawPropertyValue.fromJson)
              .toList(growable: false),
        ),
      DavPatchOperationType.setTaskProgress =>
        DavPatchOperation.setTaskProgress(
          _requiredInteger(json, 'percentComplete'),
          completedAtUtc: _optionalDateTime(json, 'completedAtUtc'),
        ),
      DavPatchOperationType.setTaskParent => DavPatchOperation.setTaskParent(
        json['value'] as String?,
      ),
      DavPatchOperationType.replaceAlarm => DavPatchOperation.replaceAlarm(
        alarmIndex: _requiredInteger(json, 'alarmIndex'),
        alarm: json['alarm'] == null
            ? null
            : _componentFromJson(_requiredMap(json, 'alarm')),
      ),
      DavPatchOperationType.addComponent => DavPatchOperation.addComponent(
        _componentFromJson(_requiredMap(json, 'component')),
      ),
      DavPatchOperationType.removeComponent =>
        DavPatchOperation.removeComponent(
          componentKey: json['componentKey'] == null
              ? null
              : _componentKeyFromJson(_requiredMap(json, 'componentKey')),
        ),
      DavPatchOperationType.reviseJournal => DavPatchOperation._(
        type: type,
        propertyName: 'DTSTAMP',
        value: _requiredString(json, 'value'),
      ),
      DavPatchOperationType.replaceJournalResource =>
        DavPatchOperation.replaceJournalResource(
          _requiredString(json, 'value'),
        ),
      DavPatchOperationType.replaceJournalChildren =>
        DavPatchOperation.replaceJournalChildren(
          _componentFromJson(_requiredMap(json, 'component')).components,
        ),
    };
  }

  final DavPatchOperationType type;
  final String propertyName;
  final String? value;
  final List<DavRawPropertyValue> values;
  final List<IcalParameter> parameters;
  final bool preserveParameters;
  final int? percentComplete;
  final DateTime? completedAtUtc;
  final int? alarmIndex;
  final IcalComponent? alarm;
  final IcalComponent? component;
  final IcalComponentKey? componentKey;

  Set<String> get changedProperties => switch (type) {
    DavPatchOperationType.setTaskProgress => {
      'STATUS',
      'PERCENT-COMPLETE',
      'COMPLETED',
    },
    DavPatchOperationType.replaceAlarm => {'VALARM'},
    DavPatchOperationType.addComponent ||
    DavPatchOperationType.removeComponent ||
    DavPatchOperationType.replaceJournalChildren ||
    DavPatchOperationType.replaceJournalResource => {'COMPONENT-SET'},
    DavPatchOperationType.reviseJournal => const {},
    _ => {propertyName},
  };

  Map<String, Object?> toJson() => {
    'type': type.name,
    'propertyName': propertyName,
    if (value != null) 'value': value,
    if (preserveParameters) 'preserveParameters': true,
    if (parameters.isNotEmpty)
      'parameters': [
        for (final parameter in parameters)
          {
            'name': parameter.name,
            'values': parameter.values,
            'wasQuoted': parameter.wasQuoted,
          },
      ],
    if (type == DavPatchOperationType.replaceRepeatedRaw)
      'values': [for (final value in values) value.toJson()],
    if (percentComplete != null) 'percentComplete': percentComplete,
    if (completedAtUtc != null)
      'completedAtUtc': completedAtUtc!.toUtc().toIso8601String(),
    if (alarmIndex != null) 'alarmIndex': alarmIndex,
    if (alarm != null) 'alarm': _componentToJson(alarm!),
    if (component != null)
      'component': _componentToJson(
        component!,
        keepLines: component!.name == 'VJOURNAL',
      ),
    if (componentKey != null)
      'componentKey': _componentKeyToJson(componentKey!),
  };
}

final class DavMutationPatch {
  DavMutationPatch({
    required this.target,
    required this.scope,
    required List<DavPatchOperation> operations,
    this.schemaVersion = davMutationPatchSchemaVersion,
  }) : operations = List.unmodifiable(operations) {
    if (schemaVersion != davMutationPatchSchemaVersion || operations.isEmpty) {
      throw _invalidPatch();
    }
  }

  factory DavMutationPatch.fromJsonString(String source) {
    try {
      final decoded = jsonDecode(source);
      if (decoded is! Map) throw _invalidPatch();
      final json = decoded.cast<String, Object?>();
      final version = _requiredInteger(json, 'schemaVersion');
      final scopeName = _requiredString(json, 'scope');
      final scope = DavMutationScope.values
          .where((value) => value.name == scopeName)
          .firstOrNull;
      if (scope == null) throw _invalidPatch();
      final targetJson = _requiredMap(json, 'target');
      return DavMutationPatch(
        schemaVersion: version,
        scope: scope,
        target: IcalComponentKey(
          componentType: _requiredString(targetJson, 'componentType'),
          uid: _requiredString(targetJson, 'uid'),
          recurrenceIdKey: targetJson['recurrenceIdKey'] as String?,
        ),
        operations: _mapList(json['operations'])
            .map(DavPatchOperation.fromJson)
            .toList(growable: false),
      );
    } on DavException {
      rethrow;
    } on Object {
      throw _invalidPatch();
    }
  }

  final int schemaVersion;
  final IcalComponentKey target;
  final DavMutationScope scope;
  final List<DavPatchOperation> operations;

  Set<String> get changedProperties => {
    for (final operation in operations) ...operation.changedProperties,
  };

  bool get isBroadRecurrenceMutation => changedProperties.any(
    const {
      'UID',
      'DTSTART',
      'RRULE',
      'RDATE',
      'EXDATE',
      'RECURRENCE-ID',
      'COMPONENT-SET',
    }.contains,
  );

  /// Freezes replay-sensitive values (currently completion timestamps) when
  /// the operation is enqueued. Replaying after a restart must produce the
  /// same candidate representation.
  DavMutationPatch materialize(DateTime nowUtc) {
    var changed = false;
    final materialized = <DavPatchOperation>[];
    for (final operation in operations) {
      if (operation.type == DavPatchOperationType.setTaskProgress &&
          operation.percentComplete == 100 &&
          operation.completedAtUtc == null) {
        changed = true;
        materialized.add(
          DavPatchOperation.setTaskProgress(
            100,
            completedAtUtc: nowUtc.toUtc(),
          ),
        );
      } else {
        materialized.add(operation);
      }
    }
    return changed
        ? DavMutationPatch(
            target: target,
            scope: scope,
            operations: materialized,
            schemaVersion: schemaVersion,
          )
        : this;
  }

  String toJsonString() => jsonEncode({
    'schemaVersion': schemaVersion,
    'scope': scope.name,
    'target': {
      'componentType': target.componentType,
      'uid': target.uid,
      if (target.recurrenceIdKey != null)
        'recurrenceIdKey': target.recurrenceIdKey,
    },
    'operations': [for (final operation in operations) operation.toJson()],
  });

  String applyTo(String rawIcs, {required DateTime nowUtc}) =>
      _applyTo(rawIcs, nowUtc: nowUtc, validateJournal: true);

  /// Renders historical journal intent for review. The resulting bytes may
  /// be invalid and must never be dispatched or exported as a calendar.
  String renderJournalRecovery(String rawIcs, {required DateTime nowUtc}) {
    if (target.componentType != 'VJOURNAL') throw _invalidPatch();
    return _applyTo(rawIcs, nowUtc: nowUtc, validateJournal: false);
  }

  String _applyTo(
    String rawIcs, {
    required DateTime nowUtc,
    required bool validateJournal,
  }) {
    var document = IcalDocument.parse(rawIcs);
    var patcher = IcalDocumentPatcher(document);
    final isJournal = target.componentType.toUpperCase() == 'VJOURNAL';
    final protected = isJournal ? _derivedJournalProperties(document) : null;
    for (final operation in operations) {
      switch (operation.type) {
        case DavPatchOperationType.setText:
          patcher.replaceSingletonText(
            target,
            operation.propertyName,
            operation.value,
            preserveParameters: isJournal,
          );
        case DavPatchOperationType.setRaw:
          patcher.replaceSingletonRaw(
            target,
            operation.propertyName,
            operation.value,
            parameters: operation.parameters,
            preserveParameters: operation.preserveParameters,
          );
        case DavPatchOperationType.replaceRepeatedRaw:
          patcher.replaceRepeatedRaw(
            target,
            operation.propertyName,
            [
              for (final value in operation.values)
                (value: value.value, parameters: value.parameters),
            ],
            groups: [for (final value in operation.values) value.group],
          );
        case DavPatchOperationType.setTaskProgress:
          _applyTaskProgress(
            patcher,
            target,
            operation.percentComplete!,
            operation.completedAtUtc ?? nowUtc,
          );
        case DavPatchOperationType.setTaskParent:
          _applyTaskParent(patcher, target, operation.value);
        case DavPatchOperationType.replaceAlarm:
          _applyAlarmPatch(
            patcher.requireComponent(target),
            operation.alarmIndex!,
            operation.alarm,
          );
        case DavPatchOperationType.addComponent:
          patcher.addComponent(operation.component!.deepCopy());
        case DavPatchOperationType.removeComponent:
          patcher.removeComponent(operation.componentKey ?? target);
        case DavPatchOperationType.replaceJournalChildren:
          if (!isJournal) throw _invalidPatch();
          final component = patcher.requireComponent(target);
          final children = operation.component!.components.iterator;
          final nodes = <IcalNode>[
            for (final node in component.children)
              if (node is! IcalComponent)
                node
              else if (children.moveNext())
                children.current.deepCopy(),
          ];
          while (children.moveNext()) {
            nodes.add(children.current.deepCopy());
          }
          component.children
            ..clear()
            ..addAll(nodes);
          component.structurallyDirty = true;
        case DavPatchOperationType.reviseJournal:
          if (!isJournal) throw _invalidPatch();
          reviseJournalTimestamps(
            patcher,
            patcher.requireComponent(target),
            operation.value!,
          );
        case DavPatchOperationType.replaceJournalResource:
          if (!isJournal) throw _invalidPatch();
          patcher.requireComponent(target);
          document = IcalDocument.parse(operation.value!);
          if (document.calendarComponents.any(
                (c) =>
                    c.name != 'VTIMEZONE' &&
                    (c.name != 'VJOURNAL' ||
                        c.firstProperty('UID')?.rawValue != target.uid),
              ) ||
              !document.calendarComponents.any((c) => c.name == 'VJOURNAL')) {
            throw _invalidPatch();
          }
          patcher = IcalDocumentPatcher(document);
      }
    }
    if (protected != null) {
      final updated = _derivedJournalProperties(document);
      if (protected.entries.any(
        (entry) => (updated[entry.key] ?? 0) < entry.value,
      )) {
        throw const DavException(
          kind: DavErrorKind.invalidCalendarData,
          code: 'IcalDerivedJournalProperty',
          safeMessage:
              'A derived journal field can only be changed at its source.',
        );
      }
    }
    final serialized = document.serialize();
    final semantic = IcalSemanticDocument.parse(serialized);
    final complete = completeIcalTimeZones(serialized);
    if (validateJournal && semantic.dominantComponentType == 'VJOURNAL') {
      JournalComponent.validateAuthored(
        complete == serialized
            ? semantic
            : IcalSemanticDocument.parse(complete),
      );
    }
    return complete;
  }
}

void reviseJournalTimestamps(
  IcalDocumentPatcher patcher,
  IcalComponent component,
  String timestamp,
) {
  for (final name in const ['DTSTAMP', 'LAST-MODIFIED']) {
    final property = component.firstProperty(name);
    if ((name == 'DTSTAMP' || property != null) &&
        !isDerivedJournalProperty(property)) {
      patcher.replaceComponentSingletonRaw(
        component,
        name,
        timestamp,
        preserveParameters: true,
      );
    }
  }
}

Map<String, int> _derivedJournalProperties(IcalDocument document) {
  final lines = <String, int>{};
  void collect(IcalComponent component, String path) {
    for (final property in component.properties.where(
      isDerivedJournalProperty,
    )) {
      final key = '$path\u0000${property.serializeLogicalLine()}';
      lines.update(key, (count) => count + 1, ifAbsent: () => 1);
    }
    for (final child in component.components) {
      final uid = child.firstProperty('UID')?.rawValue;
      // UID-less status records can shift when unrelated siblings change.
      // Preserve the protected property groups and their multiplicities.
      final derived =
          child.properties
              .where(isDerivedJournalProperty)
              .map((property) => property.serializeLogicalLine())
              .toList()
            ..sort();
      final identity = jsonEncode(uid ?? derived);
      collect(child, '$path\u0000${child.name}\u0000$identity');
    }
  }

  for (final component in document.calendarComponents) {
    if (component.name != 'VJOURNAL') continue;
    final uid = component.firstProperty('UID')?.rawValue;
    final id = journalRecurrencePosition(
      parseIcalTemporal(component.firstProperty('RECURRENCE-ID')),
    );
    collect(component, '$uid\u0000$id');
  }
  return lines;
}

void _applyTaskProgress(
  IcalDocumentPatcher patcher,
  IcalComponentKey target,
  int percent,
  DateTime nowUtc,
) {
  if (target.componentType.toUpperCase() != 'VTODO') throw _invalidPatch();
  if (percent == 100) {
    patcher
      ..replaceSingletonRaw(target, 'STATUS', 'COMPLETED')
      ..replaceSingletonRaw(target, 'PERCENT-COMPLETE', '100')
      ..replaceSingletonRaw(target, 'COMPLETED', _utcIcal(nowUtc));
  } else if (percent == 0) {
    patcher
      ..replaceSingletonRaw(target, 'STATUS', 'NEEDS-ACTION')
      ..replaceSingletonRaw(target, 'PERCENT-COMPLETE', null)
      ..replaceSingletonRaw(target, 'COMPLETED', null);
  } else {
    patcher
      ..replaceSingletonRaw(target, 'STATUS', 'IN-PROCESS')
      ..replaceSingletonRaw(target, 'PERCENT-COMPLETE', '$percent')
      ..replaceSingletonRaw(target, 'COMPLETED', null);
  }
}

void _applyTaskParent(
  IcalDocumentPatcher patcher,
  IcalComponentKey target,
  String? parentUid,
) {
  if (target.componentType.toUpperCase() != 'VTODO' ||
      parentUid == target.uid) {
    throw _invalidPatch();
  }
  final component = patcher.requireComponent(target);
  final retained = <DavRawPropertyValue>[];
  for (final property in component.propertiesNamed('RELATED-TO')) {
    final relationType = property.parameterValue('RELTYPE')?.toUpperCase();
    if (relationType == null || relationType == 'PARENT') continue;
    retained.add(
      DavRawPropertyValue(
        value: property.rawValue,
        parameters: property.parameters,
      ),
    );
  }
  if (parentUid != null && parentUid.isNotEmpty) {
    retained.add(
      DavRawPropertyValue(
        value: parentUid,
        parameters: const [
          IcalParameter(name: 'RELTYPE', values: ['PARENT'], wasQuoted: false),
        ],
      ),
    );
  }
  patcher.replaceRepeatedRaw(target, 'RELATED-TO', [
    for (final value in retained)
      (value: value.value, parameters: value.parameters),
  ]);
}

void _applyAlarmPatch(
  IcalComponent component,
  int alarmIndex,
  IcalComponent? alarm,
) {
  final childIndexes = <int>[];
  for (var index = 0; index < component.children.length; index += 1) {
    final child = component.children[index];
    if (child is IcalComponent && child.name == 'VALARM') {
      childIndexes.add(index);
    }
  }
  if (alarmIndex > childIndexes.length) throw _invalidPatch();
  if (alarmIndex == childIndexes.length) {
    if (alarm == null) throw _invalidPatch();
    component.children.add(alarm.deepCopy());
  } else if (alarm == null) {
    component.children.removeAt(childIndexes[alarmIndex]);
  } else {
    component.children[childIndexes[alarmIndex]] = alarm.deepCopy();
  }
  component.structurallyDirty = true;
}

String _utcIcal(DateTime value) {
  final utc = value.toUtc();
  String two(int number) => number.toString().padLeft(2, '0');
  return '${utc.year.toString().padLeft(4, '0')}${two(utc.month)}'
      '${two(utc.day)}T${two(utc.hour)}${two(utc.minute)}${two(utc.second)}Z';
}

const _editableProperties = {
  'SUMMARY',
  'ORGANIZER',
  'ATTENDEE',
  'DESCRIPTION',
  'ATTACH',
  'COMMENT',
  'CONTACT',
  'REQUEST-STATUS',
  'COLOR',
  'IMAGE',
  'STYLED-DESCRIPTION',
  'STRUCTURED-DATA',
  'LINK',
  'CONCEPT',
  'REFID',
  'X-ALT-DESC',
  'LOCATION',
  'GEO',
  'DTSTART',
  'DTEND',
  'DUE',
  'DURATION',
  'STATUS',
  'CLASS',
  'TRANSP',
  'URL',
  'PRIORITY',
  'PERCENT-COMPLETE',
  'COMPLETED',
  'CATEGORIES',
  'RELATED-TO',
  'RECURRENCE-ID',
  'RRULE',
  'RDATE',
  'EXDATE',
  'SEQUENCE',
  'CREATED',
  'DTSTAMP',
  'LAST-MODIFIED',
  'X-APPLE-SORT-ORDER',
  'X-PINNED',
  'X-OC-HIDESUBTASKS',
  'X-OC-HIDECOMPLETEDSUBTASKS',
};

String _validatedEditableProperty(String value) {
  final upper = value.toUpperCase();
  if (!_editableProperties.contains(upper)) throw _invalidPatch();
  return upper;
}

Map<String, Object?> _componentToJson(
  IcalComponent component, {
  bool keepLines = false,
}) => {
  'name': component.name,
  'children': [
    for (final child in component.children)
      switch (child) {
        final IcalProperty property => {
          'node': 'property',
          'name': property.name,
          if (property.group != null) 'group': property.group,
          'value': property.rawValue,
          if (keepLines &&
              !property.isDirty &&
              property.originalPhysicalLines.isNotEmpty)
            'lines': property.originalPhysicalLines,
          'parameters': [
            for (final parameter in property.parameters)
              {
                'name': parameter.name,
                'values': parameter.values,
                'wasQuoted': parameter.wasQuoted,
              },
          ],
        },
        final IcalComponent nested => {
          'node': 'component',
          'component': _componentToJson(nested, keepLines: keepLines),
        },
      },
  ],
};

Map<String, Object?> _componentKeyToJson(IcalComponentKey key) => {
  'componentType': key.componentType.toUpperCase(),
  'uid': key.uid,
  if (key.recurrenceIdKey != null) 'recurrenceIdKey': key.recurrenceIdKey,
};

IcalComponentKey _componentKeyFromJson(Map<String, Object?> json) =>
    IcalComponentKey(
      componentType: _requiredString(json, 'componentType'),
      uid: _requiredString(json, 'uid'),
      recurrenceIdKey: json['recurrenceIdKey'] as String?,
    );

IcalComponent _componentFromJson(Map<String, Object?> json) {
  final name = _requiredString(json, 'name').toUpperCase();
  if (!const {
    'VALARM',
    'VEVENT',
    'VTODO',
    'VJOURNAL',
    'PARTICIPANT',
    'VLOCATION',
    'VRESOURCE',
    'VSTATUS',
  }.contains(name)) {
    throw _invalidPatch();
  }
  final children = <IcalNode>[];
  for (final child in _mapList(json['children'])) {
    final node = _requiredString(child, 'node');
    if (node == 'property') {
      final property = IcalProperty(
        group: child['group'] as String?,
        name: _requiredString(child, 'name').toUpperCase(),
        parameters: _parameters(child['parameters']),
        // Empty values are meaningful in iCalendar. In particular, an
        // explicit empty LOCATION on a recurrence exception prevents the
        // master value from being inherited.
        rawValue: _requiredStringAllowEmpty(child, 'value'),
        originalPhysicalLines: const [],
        isDirty: true,
      );
      final lines = child['lines'];
      if (lines == null) {
        children.add(property);
      } else {
        final original = _stringList(lines);
        if (original.isEmpty ||
            original.any(
              (line) => line.contains('\r') || line.contains('\n'),
            )) {
          throw _invalidPatch();
        }
        final restored = IcalDocument.parse(
          'BEGIN:VCALENDAR\r\nBEGIN:$name\r\n'
          '${original.join('\r\n')}\r\nEND:$name\r\nEND:VCALENDAR\r\n',
        );
        final parsed = restored.calendarComponents.single.children.single;
        if (parsed is! IcalProperty ||
            parsed.serializeLogicalLine() != property.serializeLogicalLine()) {
          throw _invalidPatch();
        }
        children.add(parsed);
      }
    } else if (node == 'component' && name != 'VALARM') {
      final nested = _componentFromJson(_requiredMap(child, 'component'));
      final permitted = switch (name) {
        'VJOURNAL' => const {
          'PARTICIPANT',
          'VLOCATION',
          'VRESOURCE',
          'VSTATUS',
        }.contains(nested.name),
        'PARTICIPANT' => const {
          'VLOCATION',
          'VRESOURCE',
          'VSTATUS',
        }.contains(nested.name),
        'VEVENT' || 'VTODO' => nested.name == 'VALARM',
        _ => false,
      };
      if (!permitted) throw _invalidPatch();
      children.add(nested);
    } else {
      throw _invalidPatch();
    }
  }
  return IcalComponent(
    name: name,
    children: children,
    originalBeginLine: 'BEGIN:$name',
    originalEndLine: 'END:$name',
    structurallyDirty: true,
  );
}

List<IcalParameter> _parameters(Object? source) {
  if (source == null) return const [];
  return [
    for (final json in _mapList(source))
      IcalParameter(
        name: _requiredString(json, 'name').toUpperCase(),
        values: _stringList(json['values']),
        wasQuoted: json['wasQuoted'] == true,
      ),
  ];
}

List<Map<String, Object?>> _mapList(Object? value) {
  if (value is! List) throw _invalidPatch();
  return [
    for (final entry in value)
      if (entry is Map)
        entry.cast<String, Object?>()
      else
        throw _invalidPatch(),
  ];
}

Map<String, Object?> _requiredMap(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! Map) throw _invalidPatch();
  return value.cast<String, Object?>();
}

String _requiredString(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! String || value.isEmpty) throw _invalidPatch();
  return value;
}

String _requiredStringAllowEmpty(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! String) throw _invalidPatch();
  return value;
}

int _requiredInteger(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! int) throw _invalidPatch();
  return value;
}

DateTime? _optionalDateTime(Map<String, Object?> json, String key) {
  final source = json[key];
  if (source == null) return null;
  if (source is! String) throw _invalidPatch();
  final value = DateTime.tryParse(source);
  if (value == null || !value.isUtc) throw _invalidPatch();
  return value;
}

List<String> _stringList(Object? source) {
  if (source is! List || source.any((value) => value is! String)) {
    throw _invalidPatch();
  }
  return source.cast<String>();
}

DavException _invalidPatch() => const DavException(
  kind: DavErrorKind.invalidCalendarData,
  code: 'DavMutationPatchInvalid',
  safeMessage: 'A pending calendar mutation patch was invalid.',
);

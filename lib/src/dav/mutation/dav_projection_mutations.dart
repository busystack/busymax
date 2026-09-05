import '../dav_errors.dart';
import '../ical/ical_document.dart';
import '../ical/ical_recurrence.dart';
import '../ical/ical_semantics.dart';
import '../ical/ical_task_alarm.dart';
import 'dav_conditional_mutation_service.dart';
import 'dav_mutation_patch.dart';

final class DavEventMutationInput {
  const DavEventMutationInput({
    required this.title,
    required this.allDay,
    required this.start,
    required this.end,
    this.startTimeZone,
    this.endTimeZone,
    this.description,
    this.location,
    this.recurrence,
    this.recurrenceChanged = false,
    this.reminders,
    this.remindersChanged = false,
    this.categories = const [],
    this.categoriesChanged = false,
    this.classification,
    this.transparency,
  });

  final String title;
  final bool allDay;
  final DateTime start;
  final DateTime end;
  final String? startTimeZone;
  final String? endTimeZone;
  final String? description;
  final String? location;
  final Object? recurrence;
  final bool recurrenceChanged;
  final Object? reminders;
  final bool remindersChanged;
  final List<String> categories;
  final bool categoriesChanged;
  final String? classification;
  final String? transparency;
}

DavNewObject buildDavEventObject(
  DavEventMutationInput input, {
  String Function()? idFactory,
  DateTime Function()? nowUtc,
}) {
  final start = _eventTemporal(
    input.start,
    allDay: input.allDay,
    timeZone: input.startTimeZone,
  );
  final end = _eventTemporal(
    input.end,
    allDay: input.allDay,
    timeZone: input.endTimeZone ?? input.startTimeZone,
  );
  final factory = DavNewObjectFactory(idFactory: idFactory, nowUtc: nowUtc);
  final initial = factory.event(
    summary: input.title.trim(),
    startRaw: start.value,
    startParameters: start.parameters,
    endRaw: end.value,
    endParameters: end.parameters,
    description: _nonEmpty(input.description),
    location: _nonEmpty(input.location),
  );
  final operations = <DavPatchOperation>[
    if (_classification(input.classification) case final value?)
      DavPatchOperation.setRaw('CLASS', value),
    if (_transparency(input.transparency) case final value?)
      DavPatchOperation.setRaw('TRANSP', value),
    if (input.categories.isNotEmpty)
      DavPatchOperation.setRaw('CATEGORIES', _categories(input.categories)),
    ..._recurrenceOperations(input.recurrence),
    ..._eventAlarmOperations(input.reminders, startIndex: 0),
  ];
  if (operations.isEmpty) return initial;
  final patch = DavMutationPatch(
    target: IcalComponentKey(componentType: 'VEVENT', uid: initial.uid),
    scope: DavMutationScope.object,
    operations: operations,
  );
  return DavNewObject(
    uid: initial.uid,
    initialMemberName: initial.initialMemberName,
    rawIcs: patch.applyTo(
      initial.rawIcs,
      nowUtc: (nowUtc ?? (() => DateTime.now().toUtc()))(),
    ),
    componentType: initial.componentType,
  );
}

DavMutationPatch? buildDavEventUpdatePatch({
  required IcalComponentKey target,
  required String baselineRawIcs,
  required DavEventMutationInput input,
}) {
  final semantic = IcalSemanticDocument.parse(baselineRawIcs);
  final current = semantic.components.firstWhere(
    (component) =>
        component.componentType == target.componentType &&
        component.uid == target.uid &&
        component.recurrenceIdKey == target.recurrenceIdKey,
  );
  final operations = <DavPatchOperation>[];
  if ((current.summary ?? '') != input.title.trim()) {
    operations.add(DavPatchOperation.setText('SUMMARY', input.title.trim()));
  }
  if ((current.description ?? '') != (input.description ?? '')) {
    operations.add(
      DavPatchOperation.setText('DESCRIPTION', _nonEmpty(input.description)),
    );
  }
  if ((current.location ?? '') != (input.location ?? '')) {
    operations.add(
      DavPatchOperation.setText('LOCATION', _nonEmpty(input.location)),
    );
  }
  final start = _eventTemporal(
    input.start,
    allDay: input.allDay,
    timeZone: input.startTimeZone,
  );
  final end = _eventTemporal(
    input.end,
    allDay: input.allDay,
    timeZone: input.endTimeZone ?? input.startTimeZone,
  );
  if (!_sameTemporal(current.start, start)) {
    operations.add(
      DavPatchOperation.setRaw(
        'DTSTART',
        start.value,
        parameters: start.parameters,
      ),
    );
  }
  if (!_sameTemporal(current.end, end) || current.duration != null) {
    operations
      ..add(
        DavPatchOperation.setRaw(
          'DTEND',
          end.value,
          parameters: end.parameters,
        ),
      )
      ..add(DavPatchOperation.setRaw('DURATION', null));
  }
  final classification = _classification(input.classification);
  if ((current.classification ?? '') != (classification ?? '')) {
    operations.add(DavPatchOperation.setRaw('CLASS', classification));
  }
  final transparency = _transparency(input.transparency);
  if ((current.transparency ?? '') != (transparency ?? '')) {
    operations.add(DavPatchOperation.setRaw('TRANSP', transparency));
  }
  if (input.categoriesChanged) {
    operations.add(
      DavPatchOperation.setRaw(
        'CATEGORIES',
        input.categories.isEmpty ? null : _categories(input.categories),
      ),
    );
  }
  if (input.recurrenceChanged) {
    operations.addAll(_recurrenceOperations(input.recurrence));
  }
  if (input.remindersChanged) {
    operations.addAll(_eventAlarmUpdateOperations(current, input.reminders));
  }
  if (operations.isEmpty) return null;
  return DavMutationPatch(
    target: target,
    scope: target.recurrenceIdKey == null
        ? DavMutationScope.recurrenceMaster
        : DavMutationScope.recurrenceException,
    operations: operations,
  );
}

/// Creates a detached exception for one generated occurrence while retaining
/// the master, sibling exceptions, VTIMEZONEs, alarms, and unknown content in
/// the same calendar-object resource.
DavMutationPatch buildDavEventOccurrenceExceptionPatch({
  required String uid,
  required String occurrenceKey,
  required String baselineRawIcs,
  required DavEventMutationInput input,
  bool thisAndFuture = false,
  DateTime Function()? nowUtc,
}) {
  final semantic = IcalSemanticDocument.parse(baselineRawIcs);
  final master = semantic.components.where(
    (component) =>
        component.componentType == 'VEVENT' &&
        component.uid == uid &&
        component.recurrenceIdKey == null,
  );
  if (master.length != 1) throw _invalidMutation();
  final recurrence = _recurrenceIdentity(occurrenceKey);
  final existing = semantic.components.where(
    (component) =>
        component.componentType == 'VEVENT' &&
        component.uid == uid &&
        _recurrenceValueKey(component) == recurrence.key,
  );
  if (existing.length > 1 || (existing.isNotEmpty && !thisAndFuture)) {
    throw _invalidMutation();
  }
  if (existing.isNotEmpty) {
    final current = existing.single;
    final target = IcalComponentKey(
      componentType: 'VEVENT',
      uid: uid,
      recurrenceIdKey: current.recurrenceIdKey,
    );
    final update = buildDavEventUpdatePatch(
      target: target,
      baselineRawIcs: baselineRawIcs,
      input: input,
    );
    final recurrenceProperty = current.documentComponent.firstProperty(
      'RECURRENCE-ID',
    );
    if (recurrenceProperty == null) throw _invalidMutation();
    return DavMutationPatch(
      target: target,
      scope: DavMutationScope.occurrence,
      operations: [
        ...?update?.operations,
        if (current.recurrenceRange != 'THISANDFUTURE')
          DavPatchOperation.setRaw(
            'RECURRENCE-ID',
            recurrenceProperty.rawValue,
            parameters: _withThisAndFuture(recurrenceProperty.parameters),
          ),
      ],
    );
  }
  final timestamp = (nowUtc ?? (() => DateTime.now().toUtc()))().toUtc();
  final start = _eventTemporal(
    input.start,
    allDay: input.allDay,
    timeZone: input.startTimeZone,
  );
  final end = _eventTemporal(
    input.end,
    allDay: input.allDay,
    timeZone: input.endTimeZone ?? input.startTimeZone,
  );
  final sequence = master.single.sequence;
  final component = IcalComponent(
    name: 'VEVENT',
    children: [
      _property('UID', uid),
      _property(
        'RECURRENCE-ID',
        recurrence.raw,
        parameters: thisAndFuture
            ? _withThisAndFuture(recurrence.parameters)
            : recurrence.parameters,
      ),
      _property('DTSTAMP', _utcIcal(timestamp)),
      if (sequence != null) _property('SEQUENCE', '${sequence + 1}'),
      _property('DTSTART', start.value, parameters: start.parameters),
      _property('DTEND', end.value, parameters: end.parameters),
      _property('SUMMARY', encodeIcalText(input.title.trim())),
      if (_nonEmpty(input.description) case final description?)
        _property('DESCRIPTION', encodeIcalText(description)),
      if (_nonEmpty(input.location) case final location?)
        _property('LOCATION', encodeIcalText(location)),
      if (_classification(input.classification) case final value?)
        _property('CLASS', value),
      if (_transparency(input.transparency) case final value?)
        _property('TRANSP', value),
      if (input.categories.isNotEmpty)
        _property('CATEGORIES', _categories(input.categories)),
      ..._eventAlarmComponents(input.reminders),
    ],
    originalBeginLine: 'BEGIN:VEVENT',
    originalEndLine: 'END:VEVENT',
    structurallyDirty: true,
  );
  return DavMutationPatch(
    target: IcalComponentKey(
      componentType: 'VEVENT',
      uid: uid,
      recurrenceIdKey: recurrence.key,
    ),
    scope: DavMutationScope.occurrence,
    operations: [DavPatchOperation.addComponent(component)],
  );
}

/// Cancels exactly one generated or overridden recurrence instance. A new
/// detached exception is added when necessary; existing exceptions are
/// patched in place.
DavMutationPatch buildDavEventOccurrenceCancellationPatch({
  required String uid,
  required String occurrenceKey,
  required String baselineRawIcs,
  bool thisAndFuture = false,
  DateTime Function()? nowUtc,
}) {
  final semantic = IcalSemanticDocument.parse(baselineRawIcs);
  final recurrence = _recurrenceIdentity(occurrenceKey);
  final existing = semantic.components.where(
    (component) =>
        component.componentType == 'VEVENT' &&
        component.uid == uid &&
        _recurrenceValueKey(component) == recurrence.key,
  );
  final target = IcalComponentKey(
    componentType: 'VEVENT',
    uid: uid,
    recurrenceIdKey: recurrence.key,
  );
  if (existing.length > 1) throw _invalidMutation();
  if (existing.length == 1) {
    final component = existing.single;
    final recurrenceProperty = component.documentComponent.firstProperty(
      'RECURRENCE-ID',
    );
    if (recurrenceProperty == null) throw _invalidMutation();
    return DavMutationPatch(
      target: IcalComponentKey(
        componentType: 'VEVENT',
        uid: uid,
        recurrenceIdKey: component.recurrenceIdKey,
      ),
      scope: DavMutationScope.occurrence,
      operations: [
        DavPatchOperation.setRaw('STATUS', 'CANCELLED'),
        if (thisAndFuture && component.recurrenceRange != 'THISANDFUTURE')
          DavPatchOperation.setRaw(
            'RECURRENCE-ID',
            recurrenceProperty.rawValue,
            parameters: _withThisAndFuture(recurrenceProperty.parameters),
          ),
      ],
    );
  }
  final master = semantic.components.where(
    (component) =>
        component.componentType == 'VEVENT' &&
        component.uid == uid &&
        component.recurrenceIdKey == null,
  );
  if (master.length != 1) throw _invalidMutation();
  final timestamp = (nowUtc ?? (() => DateTime.now().toUtc()))().toUtc();
  final sequence = master.single.sequence;
  final component = IcalComponent(
    name: 'VEVENT',
    children: [
      _property('UID', uid),
      _property(
        'RECURRENCE-ID',
        recurrence.raw,
        parameters: thisAndFuture
            ? _withThisAndFuture(recurrence.parameters)
            : recurrence.parameters,
      ),
      _property('DTSTAMP', _utcIcal(timestamp)),
      if (sequence != null) _property('SEQUENCE', '${sequence + 1}'),
      _property('DTSTART', recurrence.raw, parameters: recurrence.parameters),
      _property('STATUS', 'CANCELLED'),
    ],
    originalBeginLine: 'BEGIN:VEVENT',
    originalEndLine: 'END:VEVENT',
    structurallyDirty: true,
  );
  return DavMutationPatch(
    target: target,
    scope: DavMutationScope.occurrence,
    operations: [DavPatchOperation.addComponent(component)],
  );
}

DavMutationPatch buildDavComponentRemovalPatch({
  required List<IcalComponentKey> targets,
  required DavMutationScope scope,
}) {
  if (targets.isEmpty) throw _invalidMutation();
  return DavMutationPatch(
    target: targets.first,
    scope: scope,
    operations: [
      for (final target in targets)
        DavPatchOperation.removeComponent(componentKey: target),
    ],
  );
}

DavNewObject buildDavTaskObject(
  Map<String, Object?> fields, {
  String? parentUid,
  String Function()? idFactory,
  DateTime Function()? nowUtc,
}) {
  final factory = DavNewObjectFactory(idFactory: idFactory, nowUtc: nowUtc);
  final due = _taskTemporal(fields, prefix: 'Due');
  final initial = factory.task(
    summary: fields['title']?.toString().trim() ?? '',
    description: _nonEmpty(fields['notes']?.toString()),
    dueRaw: due?.value,
    dueParameters: due?.parameters ?? const [],
  );
  final target = IcalComponentKey(componentType: 'VTODO', uid: initial.uid);
  final initialComponent = IcalSemanticDocument.parse(
    initial.rawIcs,
  ).components.single;
  final operations = <DavPatchOperation>[
    if (_taskTemporal(fields, prefix: 'Start') case final start?)
      DavPatchOperation.setRaw(
        'DTSTART',
        start.value,
        parameters: start.parameters,
      ),
    if (fields['categories'] case final List values when values.isNotEmpty)
      DavPatchOperation.setRaw(
        'CATEGORIES',
        _categories(values.map((value) => value.toString())),
      ),
    if (_taskPriority(fields) case final priority?)
      DavPatchOperation.setRaw('PRIORITY', '$priority'),
    if (fields.containsKey('location'))
      DavPatchOperation.setText(
        'LOCATION',
        _nonEmpty(fields['location']?.toString()),
      ),
    if (fields.containsKey('taskUrl'))
      DavPatchOperation.setRaw('URL', _taskUrl(fields['taskUrl'])),
    if (fields.containsKey('taskClassification'))
      DavPatchOperation.setRaw(
        'CLASS',
        _classification(fields['taskClassification']?.toString()),
      ),
    if (fields.containsKey('taskPinned'))
      DavPatchOperation.setRaw(
        'X-PINNED',
        fields['taskPinned'] == true ? 'true' : null,
      ),
    if (fields.containsKey('taskHideSubtasks'))
      DavPatchOperation.setRaw(
        'X-OC-HIDESUBTASKS',
        fields['taskHideSubtasks'] == true ? '1' : '0',
      ),
    if (fields.containsKey('taskHideCompletedSubtasks'))
      DavPatchOperation.setRaw(
        'X-OC-HIDECOMPLETEDSUBTASKS',
        fields['taskHideCompletedSubtasks'] == true ? '1' : '0',
      ),
    if (fields['sortOrder'] is int)
      DavPatchOperation.setRaw('X-APPLE-SORT-ORDER', '${fields['sortOrder']}'),
    if (parentUid != null) DavPatchOperation.setTaskParent(parentUid),
    ..._taskStateOperations(fields, current: initialComponent),
    ..._taskRecurrenceOperations(fields['recurrence']),
    if (fields.containsKey('taskAlarms'))
      ..._taskAlarmOperations(initialComponent, fields['taskAlarms'])
    else if (_taskReminder(fields) case final alarm?)
      DavPatchOperation.replaceAlarm(alarmIndex: 0, alarm: alarm),
  ];
  if (operations.isEmpty) return initial;
  final patch = DavMutationPatch(
    target: target,
    scope: DavMutationScope.object,
    operations: operations,
  );
  return DavNewObject(
    uid: initial.uid,
    initialMemberName: initial.initialMemberName,
    rawIcs: patch.applyTo(
      initial.rawIcs,
      nowUtc: (nowUtc ?? (() => DateTime.now().toUtc()))(),
    ),
    componentType: initial.componentType,
  );
}

DavMutationPatch? buildDavTaskUpdatePatch({
  required IcalComponentKey target,
  required String baselineRawIcs,
  required Map<String, Object?> fields,
  String? parentUid,
  DateTime Function()? nowUtc,
}) {
  final semantic = IcalSemanticDocument.parse(baselineRawIcs);
  final component = semantic.components.firstWhere(
    (candidate) =>
        candidate.componentType == target.componentType &&
        candidate.uid == target.uid &&
        candidate.recurrenceIdKey == target.recurrenceIdKey,
  );
  final operations = <DavPatchOperation>[];
  if (fields.containsKey('title')) {
    operations.add(
      DavPatchOperation.setText(
        'SUMMARY',
        fields['title']?.toString().trim() ?? '',
      ),
    );
  }
  if (fields.containsKey('notes')) {
    operations
      ..add(
        DavPatchOperation.setText(
          'DESCRIPTION',
          _nonEmpty(fields['notes']?.toString()),
        ),
      )
      ..add(DavPatchOperation.setRaw('X-ALT-DESC', null));
  }
  if (_containsTaskTemporal(fields, prefix: 'Due')) {
    final due = _taskTemporal(fields, prefix: 'Due');
    operations.add(
      DavPatchOperation.setRaw(
        'DUE',
        due?.value,
        parameters: due?.parameters ?? const [],
      ),
    );
  }
  if (_containsTaskTemporal(fields, prefix: 'Start')) {
    final start = _taskTemporal(fields, prefix: 'Start');
    operations.add(
      DavPatchOperation.setRaw(
        'DTSTART',
        start?.value,
        parameters: start?.parameters ?? const [],
      ),
    );
  }
  operations.addAll(_taskStateOperations(fields, current: component));
  if (fields.containsKey('importance') || fields.containsKey('icalPriority')) {
    final priority = _taskPriority(fields);
    operations.add(
      DavPatchOperation.setRaw(
        'PRIORITY',
        priority == null ? null : '$priority',
      ),
    );
  }
  if (fields.containsKey('location')) {
    operations.add(
      DavPatchOperation.setText(
        'LOCATION',
        _nonEmpty(fields['location']?.toString()),
      ),
    );
  }
  if (fields.containsKey('taskUrl')) {
    operations.add(
      DavPatchOperation.setRaw('URL', _taskUrl(fields['taskUrl'])),
    );
  }
  if (fields.containsKey('taskClassification')) {
    operations.add(
      DavPatchOperation.setRaw(
        'CLASS',
        _classification(fields['taskClassification']?.toString()),
      ),
    );
  }
  if (fields.containsKey('taskPinned')) {
    operations.add(
      DavPatchOperation.setRaw(
        'X-PINNED',
        fields['taskPinned'] == true ? 'true' : null,
      ),
    );
  }
  if (fields.containsKey('taskHideSubtasks')) {
    operations.add(
      DavPatchOperation.setRaw(
        'X-OC-HIDESUBTASKS',
        fields['taskHideSubtasks'] == true ? '1' : '0',
      ),
    );
  }
  if (fields.containsKey('taskHideCompletedSubtasks')) {
    operations.add(
      DavPatchOperation.setRaw(
        'X-OC-HIDECOMPLETEDSUBTASKS',
        fields['taskHideCompletedSubtasks'] == true ? '1' : '0',
      ),
    );
  }
  if (fields.containsKey('sortOrder')) {
    final value = fields['sortOrder'];
    if (value != null && value is! int) throw _invalidMutation();
    operations.add(
      DavPatchOperation.setRaw(
        'X-APPLE-SORT-ORDER',
        value == null ? null : '$value',
      ),
    );
  }
  if (fields.containsKey('categories')) {
    final values = switch (fields['categories']) {
      final List values => values.map((value) => value.toString()).toList(),
      _ => const <String>[],
    };
    operations.add(_taskCategoriesOperation(component, values));
  }
  if (fields.containsKey('parentUid')) {
    operations.add(DavPatchOperation.setTaskParent(parentUid));
  }
  if (fields.containsKey('recurrence')) {
    operations.addAll(_taskRecurrenceOperations(fields['recurrence']));
  }
  if (fields.containsKey('taskAlarms')) {
    operations.addAll(_taskAlarmOperations(component, fields['taskAlarms']));
  } else if (fields.containsKey('microsoftIsReminderOn') ||
      fields.containsKey('microsoftReminderDateTime')) {
    final editableAlarm = _editableTaskDisplayAlarm(component);
    final desired = _taskReminder(fields);
    if (desired != null || editableAlarm.index != null) {
      operations.add(
        DavPatchOperation.replaceAlarm(
          alarmIndex: editableAlarm.index ?? component.alarms.length,
          alarm: desired,
        ),
      );
    }
  }
  if (operations.isEmpty) return null;
  final timestamp = _utcIcal(
    (nowUtc ?? (() => DateTime.now().toUtc()))().toUtc(),
  );
  operations
    ..add(DavPatchOperation.setRaw('LAST-MODIFIED', timestamp))
    ..add(DavPatchOperation.setRaw('DTSTAMP', timestamp));
  return DavMutationPatch(
    target: target,
    scope: target.recurrenceIdKey == null
        ? DavMutationScope.recurrenceMaster
        : DavMutationScope.recurrenceException,
    operations: operations,
  );
}

/// Completes the current instance of a recurring VTODO while retaining an
/// open master for the next instance.
///
/// This follows the recurring-completion lifecycle used by Nextcloud Tasks:
/// a completed detached instance is recorded with RECURRENCE-ID, the first
/// RRULE advances the master's DUE or DTSTART, the start/due distance is
/// retained, and a COUNT limit is decremented. All components remain in the
/// same RFC 5545 calendar-object resource so the mutation is conditional and
/// atomic from the client's perspective.
DavMutationPatch buildDavRecurringTaskCompletionPatch({
  required IcalComponentKey target,
  required String baselineRawIcs,
  DateTime? completedAtUtc,
  DateTime Function()? nowUtc,
}) {
  if (target.componentType.toUpperCase() != 'VTODO' ||
      target.recurrenceIdKey != null) {
    throw _invalidMutation();
  }
  final semantic = IcalSemanticDocument.parse(baselineRawIcs);
  final masters = semantic.components
      .where(
        (component) =>
            component.componentType == 'VTODO' &&
            component.uid == target.uid &&
            component.recurrenceId == null,
      )
      .toList(growable: false);
  if (masters.length != 1) throw _invalidMutation();
  final master = masters.single;
  if (master.recurrenceRules.isEmpty) throw _invalidMutation();
  final instance = master.due ?? master.start;
  if (instance == null) {
    return DavMutationPatch(
      target: target,
      scope: DavMutationScope.recurrenceMaster,
      operations: [
        DavPatchOperation.setTaskProgress(100, completedAtUtc: completedAtUtc),
      ],
    );
  }

  final recurrenceId = _nextcloudDetachedTemporal(instance);
  if (semantic.components.any(
    (component) =>
        component.componentType == 'VTODO' &&
        component.uid == target.uid &&
        component.recurrenceIdKey == recurrenceId.key,
  )) {
    throw _invalidMutation();
  }

  final now = (nowUtc ?? (() => DateTime.now().toUtc()))().toUtc();
  final timestamp = _utcIcal(now);
  final completionTimestamp = _utcIcal((completedAtUtc ?? now).toUtc());
  final detachedDue = master.due == null
      ? null
      : _nextcloudDetachedTemporal(master.due!, forceDate: instance.isDate);
  final detachedStart = master.start == null
      ? null
      : _nextcloudDetachedTemporal(master.start!, forceDate: instance.isDate);
  final exception = IcalComponent(
    name: 'VTODO',
    children: [
      _property('UID', target.uid),
      _property(
        'RECURRENCE-ID',
        recurrenceId.raw,
        parameters: recurrenceId.parameters,
      ),
      _property('SUMMARY', encodeIcalText(master.summary ?? '')),
      if (_nonEmpty(master.description) case final description?)
        _property('DESCRIPTION', encodeIcalText(description)),
      if (_nonEmpty(master.location) case final location?)
        _property('LOCATION', encodeIcalText(location)),
      if (_nonEmpty(master.url) case final url?) _property('URL', url),
      if (master.priority case final priority?)
        _property('PRIORITY', '$priority'),
      _property('CLASS', master.classification ?? 'PUBLIC'),
      _property('STATUS', 'COMPLETED'),
      _property('PERCENT-COMPLETE', '100'),
      _property('COMPLETED', completionTimestamp),
      if (detachedDue case final due?)
        _property('DUE', due.raw, parameters: due.parameters),
      if (detachedStart case final start?)
        _property('DTSTART', start.raw, parameters: start.parameters),
      _property('CREATED', timestamp),
      _property('LAST-MODIFIED', timestamp),
      _property('DTSTAMP', timestamp),
    ],
    originalBeginLine: 'BEGIN:VTODO',
    originalEndLine: 'END:VTODO',
    structurallyDirty: true,
  );
  final operations = <DavPatchOperation>[
    DavPatchOperation.addComponent(exception),
  ];

  final firstRule = master.recurrenceRules.first;
  final count = _rruleCount(firstRule);
  if (count != null && count <= 1) {
    operations
      ..add(
        DavPatchOperation.setTaskProgress(
          100,
          completedAtUtc: completedAtUtc ?? now,
        ),
      )
      ..add(DavPatchOperation.setRaw('LAST-MODIFIED', timestamp))
      ..add(DavPatchOperation.setRaw('DTSTAMP', timestamp));
    return DavMutationPatch(
      target: target,
      scope: DavMutationScope.recurrenceMaster,
      operations: operations,
    );
  }

  final iterationStart = _nextcloudRecurrenceIterationTemporal(instance);
  final next = IcalRecurrenceExpander().nextTaskOccurrence(
    semantic,
    current: iterationStart,
    recurrenceRule: firstRule,
  );
  if (next == null) {
    return DavMutationPatch(
      target: target,
      scope: DavMutationScope.recurrenceMaster,
      operations: operations,
    );
  }

  final nextMaster = _nextcloudAdvancedTemporal(next, allDay: instance.isDate);
  if (master.due != null) {
    operations.add(
      DavPatchOperation.setRaw(
        'DUE',
        nextMaster.value,
        parameters: nextMaster.parameters,
      ),
    );
    final start = master.start;
    if (start != null) {
      final offset = master.due!.localValue.difference(start.localValue);
      final nextStart = _nextcloudAdvancedTemporal(
        IcalTemporalValue(
          rawValue: '',
          kind: next.kind,
          localValue: next.localValue.subtract(offset),
          timeZoneId: null,
        ),
        allDay: instance.isDate,
      );
      operations.add(
        DavPatchOperation.setRaw(
          'DTSTART',
          nextStart.value,
          parameters: nextStart.parameters,
        ),
      );
    }
  } else {
    operations.add(
      DavPatchOperation.setRaw(
        'DTSTART',
        nextMaster.value,
        parameters: nextMaster.parameters,
      ),
    );
  }
  operations
    ..add(DavPatchOperation.setRaw('PERCENT-COMPLETE', null))
    ..add(DavPatchOperation.setRaw('COMPLETED', null))
    ..add(DavPatchOperation.setRaw('STATUS', null));
  if (count != null) {
    final rules = master.documentComponent
        .propertiesNamed('RRULE')
        .toList(growable: false);
    operations.add(
      DavPatchOperation.replaceRepeatedRaw('RRULE', [
        for (var index = 0; index < rules.length; index += 1)
          DavRawPropertyValue(
            value: index == 0
                ? _replaceRruleCount(rules[index].rawValue, count - 1)
                : rules[index].rawValue,
            parameters: rules[index].parameters,
          ),
      ]),
    );
  }
  operations
    ..add(DavPatchOperation.setRaw('LAST-MODIFIED', timestamp))
    ..add(DavPatchOperation.setRaw('DTSTAMP', timestamp));
  return DavMutationPatch(
    target: target,
    scope: DavMutationScope.recurrenceMaster,
    operations: operations,
  );
}

List<int> reminderMinutes(Object? reminders) {
  if (reminders is! Map) return const [];
  final map = reminders.cast<Object?, Object?>();
  final values = <int>[];
  if (map['reminderMinutesBeforeStart'] is int) {
    values.add(map['reminderMinutesBeforeStart']! as int);
  }
  if (map['overrides'] is List) {
    for (final value in map['overrides']! as List) {
      if (value is Map && value['minutes'] is int) {
        values.add(value['minutes']! as int);
      }
    }
  }
  if (map['minutes'] is List) {
    values.addAll((map['minutes']! as List).whereType<int>());
  }
  return values.where((value) => value >= 0).toSet().toList()..sort();
}

typedef _RawTemporal = ({String value, List<IcalParameter> parameters});

_RawTemporal _eventTemporal(
  DateTime value, {
  required bool allDay,
  required String? timeZone,
}) {
  if (allDay) {
    return (
      value: _date(value),
      parameters: const [
        IcalParameter(name: 'VALUE', values: ['DATE'], wasQuoted: false),
      ],
    );
  }
  return _dateTimeTemporal(value, timeZone);
}

_RawTemporal _dateTimeTemporal(DateTime value, String? timeZone) {
  final zone = timeZone?.trim();
  if (value.isUtc) {
    return (value: _utcIcal(value), parameters: const []);
  }
  if (_isUtcZone(zone)) {
    return (value: '${_localIcal(value)}Z', parameters: const []);
  }
  return (
    value: _localIcal(value),
    parameters: zone == null || zone.isEmpty
        ? const []
        : [
            IcalParameter(name: 'TZID', values: [zone], wasQuoted: false),
          ],
  );
}

_RawTemporal? _taskTemporal(
  Map<String, Object?> fields, {
  required String prefix,
}) {
  final dateTimeKey = 'microsoft${prefix}DateTime';
  final zoneKey = 'microsoft${prefix}TimeZone';
  final dateTimeValue = fields[dateTimeKey];
  final map = dateTimeValue is Map
      ? dateTimeValue.cast<Object?, Object?>()
      : null;
  final text = map?['dateTime']?.toString() ?? dateTimeValue?.toString();
  final zone = fields[zoneKey]?.toString() ?? map?['timeZone']?.toString();
  if (text != null && text.isNotEmpty) {
    final parsed = DateTime.tryParse(text);
    if (parsed == null) throw _invalidMutation();
    if (!text.contains('T')) {
      return (
        value: _date(parsed),
        parameters: const [
          IcalParameter(name: 'VALUE', values: ['DATE'], wasQuoted: false),
        ],
      );
    }
    return _dateTimeTemporal(parsed, zone);
  }
  if (prefix == 'Due') {
    final due = fields['due'];
    if (due == null) return null;
    final parsed = due is DateTime ? due : DateTime.tryParse(due.toString());
    if (parsed == null) throw _invalidMutation();
    return (
      value: _date(parsed),
      parameters: const [
        IcalParameter(name: 'VALUE', values: ['DATE'], wasQuoted: false),
      ],
    );
  }
  return null;
}

bool _containsTaskTemporal(
  Map<String, Object?> fields, {
  required String prefix,
}) =>
    fields.containsKey('microsoft${prefix}DateTime') ||
    fields.containsKey('microsoft${prefix}TimeZone') ||
    (prefix == 'Due' && fields.containsKey('due'));

List<DavPatchOperation> _recurrenceOperations(Object? recurrence) {
  final rules = <String>[];
  if (recurrence is List) {
    rules.addAll(recurrence.map((value) => value.toString()));
  } else if (recurrence is Map && recurrence['rules'] is List) {
    rules.addAll(
      (recurrence['rules']! as List).map((value) => value.toString()),
    );
  }
  return [
    DavPatchOperation.replaceRepeatedRaw('RRULE', [
      for (final rule in rules)
        DavRawPropertyValue(value: rule.replaceFirst(RegExp(r'^RRULE:'), '')),
    ]),
  ];
}

List<DavPatchOperation> _taskRecurrenceOperations(Object? recurrence) {
  if (recurrence == null) return _recurrenceOperations(null);
  if (recurrence is Map && recurrence['pattern'] is Map) {
    return _recurrenceOperations([_graphRecurrenceToRrule(recurrence)]);
  }
  return _recurrenceOperations(recurrence);
}

String _graphRecurrenceToRrule(Map recurrence) {
  final pattern = recurrence['pattern'];
  if (pattern is! Map) throw _invalidMutation();
  final type = pattern['type']?.toString();
  final frequency = switch (type) {
    'daily' => 'DAILY',
    'weekly' => 'WEEKLY',
    'absoluteMonthly' => 'MONTHLY',
    'absoluteYearly' => 'YEARLY',
    _ => throw _invalidMutation(),
  };
  final parts = <String>[
    'FREQ=$frequency',
    'INTERVAL=${pattern['interval'] is int ? pattern['interval'] : 1}',
  ];
  if (type == 'weekly' && pattern['daysOfWeek'] is List) {
    final days = <String>[
      for (final value in pattern['daysOfWeek'] as List)
        switch (value.toString().toLowerCase()) {
          'monday' => 'MO',
          'tuesday' => 'TU',
          'wednesday' => 'WE',
          'thursday' => 'TH',
          'friday' => 'FR',
          'saturday' => 'SA',
          'sunday' => 'SU',
          _ => throw _invalidMutation(),
        },
    ];
    if (days.isNotEmpty) parts.add('BYDAY=${days.join(',')}');
  }
  if (type == 'absoluteMonthly' && pattern['dayOfMonth'] is int) {
    parts.add('BYMONTHDAY=${pattern['dayOfMonth']}');
  }
  if (type == 'absoluteYearly') {
    if (pattern['month'] is int) parts.add('BYMONTH=${pattern['month']}');
    if (pattern['dayOfMonth'] is int) {
      parts.add('BYMONTHDAY=${pattern['dayOfMonth']}');
    }
  }
  return parts.join(';');
}

List<DavPatchOperation> _eventAlarmOperations(
  Object? reminders, {
  required int startIndex,
}) {
  final alarms = _eventAlarmComponents(reminders);
  return [
    for (var index = 0; index < alarms.length; index += 1)
      DavPatchOperation.replaceAlarm(
        alarmIndex: startIndex + index,
        alarm: alarms[index],
      ),
  ];
}

List<DavPatchOperation> _eventAlarmUpdateOperations(
  IcalSemanticComponent current,
  Object? reminders,
) {
  final projected = _projectedEventAlarms(reminders);
  if (projected != null) {
    return [
      for (
        var index = 0;
        index < current.alarms.length && index < projected.length;
        index += 1
      )
        DavPatchOperation.replaceAlarm(
          alarmIndex: index,
          alarm: projected[index],
        ),
      for (
        var index = current.alarms.length - 1;
        index >= projected.length;
        index -= 1
      )
        DavPatchOperation.replaceAlarm(alarmIndex: index, alarm: null),
      for (
        var index = current.alarms.length;
        index < projected.length;
        index += 1
      )
        DavPatchOperation.replaceAlarm(
          alarmIndex: index,
          alarm: projected[index],
        ),
    ];
  }

  final desiredReminders = reminderMinutes(reminders);
  final editableAlarms = _editableDisplayAlarms(current);
  final currentReminders = [for (final alarm in editableAlarms) alarm.minutes];
  if (_sameIntegers(currentReminders, desiredReminders)) return const [];
  return [
    for (
      var index = 0;
      index < editableAlarms.length && index < desiredReminders.length;
      index += 1
    )
      DavPatchOperation.replaceAlarm(
        alarmIndex: editableAlarms[index].index,
        alarm: _displayAlarm(desiredReminders[index]),
      ),
    for (
      var index = editableAlarms.length - 1;
      index >= desiredReminders.length;
      index -= 1
    )
      DavPatchOperation.replaceAlarm(
        alarmIndex: editableAlarms[index].index,
        alarm: null,
      ),
    for (
      var index = editableAlarms.length;
      index < desiredReminders.length;
      index += 1
    )
      DavPatchOperation.replaceAlarm(
        alarmIndex: current.alarms.length + index - editableAlarms.length,
        alarm: _displayAlarm(desiredReminders[index]),
      ),
  ];
}

List<IcalComponent> _eventAlarmComponents(Object? reminders) {
  return _projectedEventAlarms(reminders) ??
      [
        for (final minutes in reminderMinutes(reminders))
          _displayAlarm(minutes),
      ];
}

List<IcalComponent>? _projectedEventAlarms(Object? reminders) {
  if (reminders is! Map || !reminders.containsKey('alarms')) return null;
  final values = reminders['alarms'];
  if (values is! List) throw _invalidMutation();
  return [
    for (final value in values)
      if (value is Map)
        IcalTaskAlarm.fromJson(value.cast<String, Object?>()).toComponent()
      else
        throw _invalidMutation(),
  ];
}

IcalComponent _displayAlarm(int minutes) => IcalComponent(
  name: 'VALARM',
  children: [
    _property('ACTION', 'DISPLAY'),
    _property('DESCRIPTION', 'Reminder'),
    _property('TRIGGER', '-PT${minutes}M'),
  ],
  originalBeginLine: 'BEGIN:VALARM',
  originalEndLine: 'END:VALARM',
  structurallyDirty: true,
);

List<({int index, int minutes})> _editableDisplayAlarms(
  IcalSemanticComponent component,
) {
  final result = <({int index, int minutes})>[];
  for (var index = 0; index < component.alarms.length; index += 1) {
    final alarm = component.alarms[index];
    if (alarm.firstProperty('ACTION')?.rawValue.toUpperCase() != 'DISPLAY') {
      continue;
    }
    final trigger = alarm.firstProperty('TRIGGER')?.rawValue.toUpperCase();
    final match = trigger == null
        ? null
        : RegExp(r'^-PT([0-9]+)M$').firstMatch(trigger);
    if (match != null) {
      result.add((index: index, minutes: int.parse(match.group(1)!)));
    }
  }
  return result;
}

({int? index, List<int> minutes}) _editableTaskDisplayAlarm(
  IcalSemanticComponent component,
) {
  for (var index = 0; index < component.alarms.length; index += 1) {
    final alarm = component.alarms[index];
    if (alarm.firstProperty('ACTION')?.rawValue.toUpperCase() != 'DISPLAY') {
      continue;
    }
    final trigger = alarm.firstProperty('TRIGGER')?.rawValue.toUpperCase();
    if (trigger == null) continue;
    try {
      if (parseIcalDuration(trigger) != null) {
        return (index: index, minutes: const []);
      }
    } on DavException {
      // It may be an absolute trigger.
    }
    if (RegExp(r'^\d{8}T\d{6}Z$').hasMatch(trigger)) {
      return (index: index, minutes: const []);
    }
  }
  return (index: null, minutes: const []);
}

IcalComponent? _taskReminder(Map<String, Object?> fields) {
  if (fields['microsoftIsReminderOn'] == false) return null;
  final value = fields['microsoftReminderDateTime'];
  if (value == null) return null;
  final map = value is Map ? value.cast<Object?, Object?>() : null;
  final text = map?['dateTime']?.toString() ?? value.toString();
  final parsed = DateTime.tryParse(text);
  if (parsed == null) throw _invalidMutation();
  // RFC 5545 absolute TRIGGER values are UTC DATE-TIME values. Inputs without
  // an offset are treated as local wall time; conversion through DateTime is
  // deterministic for the desktop's current zone and never rewrites an
  // untouched imported alarm.
  final trigger = _utcIcal(parsed.isUtc ? parsed : parsed.toUtc());
  return IcalComponent(
    name: 'VALARM',
    children: [
      _property('ACTION', 'DISPLAY'),
      _property('DESCRIPTION', 'Reminder'),
      _property(
        'TRIGGER',
        trigger,
        parameters: const [
          IcalParameter(name: 'VALUE', values: ['DATE-TIME'], wasQuoted: false),
        ],
      ),
    ],
    originalBeginLine: 'BEGIN:VALARM',
    originalEndLine: 'END:VALARM',
    structurallyDirty: true,
  );
}

List<DavPatchOperation> _taskStateOperations(
  Map<String, Object?> fields, {
  required IcalSemanticComponent current,
}) {
  final hasStatus =
      fields.containsKey('taskStatus') || fields.containsKey('status');
  final hasPercent = fields.containsKey('percentComplete');
  final hasCompleted = fields.containsKey('completedAtUtc');
  if (!hasStatus && !hasPercent && !hasCompleted) return const [];

  DateTime? completedAt;
  if (hasCompleted && fields['completedAtUtc'] != null) {
    completedAt = DateTime.tryParse(fields['completedAtUtc'].toString());
    if (completedAt == null) throw _invalidMutation();
  }
  if (completedAt != null) {
    return [
      DavPatchOperation.setTaskProgress(
        100,
        completedAtUtc: completedAt.toUtc(),
      ),
    ];
  }
  if (hasPercent) {
    final raw = fields['percentComplete'];
    if (raw is! int || raw < 0 || raw > 100) throw _invalidMutation();
    return [DavPatchOperation.setTaskProgress(raw)];
  }

  if (hasStatus) {
    final rawStatus = fields.containsKey('taskStatus')
        ? fields['taskStatus']
        : fields['status'];
    final status = _normalizedTaskStatus(rawStatus);
    final percent = current.percentComplete ?? 0;
    return switch (status) {
      'COMPLETED' => [DavPatchOperation.setTaskProgress(100)],
      'IN-PROCESS' => [
        DavPatchOperation.setTaskProgress(
          percent == 100
              ? 99
              : percent == 0
              ? 1
              : percent,
        ),
      ],
      'NEEDS-ACTION' || null => [
        DavPatchOperation.setRaw('STATUS', status),
        DavPatchOperation.setRaw('COMPLETED', null),
        if (percent == 100) DavPatchOperation.setRaw('PERCENT-COMPLETE', '99'),
      ],
      'CANCELLED' => [DavPatchOperation.setRaw('STATUS', 'CANCELLED')],
      _ => throw _invalidMutation(),
    };
  }

  if (hasCompleted) {
    if ((current.percentComplete ?? 0) == 100) {
      return [DavPatchOperation.setTaskProgress(99)];
    }
    return [DavPatchOperation.setRaw('COMPLETED', null)];
  }
  return const [];
}

String? _normalizedTaskStatus(Object? value) {
  if (value == null) return null;
  return switch (value.toString().trim().toUpperCase()) {
    'COMPLETED' => 'COMPLETED',
    'INPROCESS' || 'IN-PROCESS' => 'IN-PROCESS',
    'NEEDSACTION' || 'NEEDS-ACTION' => 'NEEDS-ACTION',
    'CANCELLED' || 'CANCELED' => 'CANCELLED',
    _ => throw _invalidMutation(),
  };
}

int? _taskPriority(Map<String, Object?> fields) {
  if (fields.containsKey('icalPriority')) {
    final value = fields['icalPriority'];
    if (value == null) return null;
    if (value is! int || value < 0 || value > 9) throw _invalidMutation();
    return value == 0 ? null : value;
  }
  return switch (fields['importance']?.toString()) {
    'high' => 1,
    'low' => 9,
    'normal' || null => null,
    _ => throw _invalidMutation(),
  };
}

String? _taskUrl(Object? value) {
  final text = value?.toString().trim();
  if (text == null || text.isEmpty) return null;
  final uri = Uri.tryParse(text);
  if (text.contains('\r') ||
      text.contains('\n') ||
      uri == null ||
      !uri.hasScheme) {
    throw _invalidMutation();
  }
  return text;
}

List<DavPatchOperation> _taskAlarmOperations(
  IcalSemanticComponent component,
  Object? value,
) {
  if (value is! List) throw _invalidMutation();
  final desired = <IcalTaskAlarm>[];
  try {
    for (final item in value) {
      if (item is! Map) throw _invalidMutation();
      desired.add(IcalTaskAlarm.fromJson(item.cast<String, Object?>()));
    }
  } on DavException {
    rethrow;
  } on Object {
    throw _invalidMutation();
  }
  final existing = [
    for (final alarm in component.alarms) IcalTaskAlarm.fromComponent(alarm),
  ];
  final operations = <DavPatchOperation>[];
  final sharedLength = existing.length < desired.length
      ? existing.length
      : desired.length;
  for (var index = 0; index < sharedLength; index += 1) {
    if (existing[index] != desired[index]) {
      operations.add(
        DavPatchOperation.replaceAlarm(
          alarmIndex: index,
          alarm: desired[index].toComponent(),
        ),
      );
    }
  }
  for (var index = existing.length - 1; index >= desired.length; index -= 1) {
    operations.add(DavPatchOperation.replaceAlarm(alarmIndex: index));
  }
  for (var index = existing.length; index < desired.length; index += 1) {
    operations.add(
      DavPatchOperation.replaceAlarm(
        alarmIndex: index,
        alarm: desired[index].toComponent(),
      ),
    );
  }
  return operations;
}

String? _classification(String? value) => switch (value?.toUpperCase()) {
  'PUBLIC' || 'PRIVATE' || 'CONFIDENTIAL' => value!.toUpperCase(),
  'DEFAULT' || 'NORMAL' || null || '' => null,
  _ => null,
};

String? _transparency(String? value) => switch (value?.toUpperCase()) {
  'TRANSPARENT' || 'FREE' => 'TRANSPARENT',
  'OPAQUE' || 'BUSY' || 'TENTATIVE' || 'OOF' || 'WORKINGELSEWHERE' => 'OPAQUE',
  null || '' => null,
  _ => null,
};

String _categories(Iterable<String> values) => values
    .map((value) => encodeIcalText(value.trim()))
    .where((value) => value.isNotEmpty)
    .join(',');

DavPatchOperation _taskCategoriesOperation(
  IcalSemanticComponent component,
  List<String> desired,
) {
  final properties = component.documentComponent
      .propertiesNamed('CATEGORIES')
      .toList(growable: false);
  if (desired.isEmpty) {
    return DavPatchOperation.replaceRepeatedRaw('CATEGORIES', const []);
  }
  if (properties.length <= 1) {
    return DavPatchOperation.replaceRepeatedRaw('CATEGORIES', [
      DavRawPropertyValue(
        value: _categories(desired),
        parameters: properties.firstOrNull?.parameters ?? const [],
      ),
    ]);
  }

  final current = component.categories;
  final remove = current.where((value) => !desired.contains(value)).toSet();
  final add = desired.where((value) => !current.contains(value)).toList();
  final retained = <({List<String> values, List<IcalParameter> parameters})>[];
  for (final property in properties) {
    final values = _categoryValues(
      property,
    ).where((value) => !remove.contains(value)).toList();
    if (values.isNotEmpty) {
      retained.add((values: values, parameters: property.parameters));
    }
  }
  if (retained.isEmpty) {
    retained.add((values: [...desired], parameters: const []));
  } else {
    retained.first.values.addAll(add);
  }
  return DavPatchOperation.replaceRepeatedRaw('CATEGORIES', [
    for (final property in retained)
      DavRawPropertyValue(
        value: _categories(property.values),
        parameters: property.parameters,
      ),
  ]);
}

List<String> _categoryValues(IcalProperty property) => _splitEscapedValues(
  property.rawValue,
).map(decodeIcalText).where((value) => value.isNotEmpty).toList();

List<String> _splitEscapedValues(String source) {
  final values = <String>[];
  var start = 0;
  var escaped = false;
  for (var index = 0; index < source.length; index += 1) {
    final value = source[index];
    if (escaped) {
      escaped = false;
    } else if (value == r'\') {
      escaped = true;
    } else if (value == ',') {
      values.add(source.substring(start, index));
      start = index + 1;
    }
  }
  values.add(source.substring(start));
  return values;
}

bool _sameTemporal(IcalTemporalValue? current, _RawTemporal desired) {
  if (current == null || current.rawValue != desired.value) return false;
  final desiredKind = desired.parameters
      .where((parameter) => parameter.name == 'VALUE')
      .firstOrNull
      ?.values
      .firstOrNull;
  final desiredZone = desired.parameters
      .where((parameter) => parameter.name == 'TZID')
      .firstOrNull
      ?.values
      .firstOrNull;
  return (desiredKind == 'DATE') == current.isDate &&
      desiredZone == current.timeZoneId;
}

bool _sameIntegers(List<int> left, List<int> right) {
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index += 1) {
    if (left[index] != right[index]) return false;
  }
  return true;
}

IcalProperty _property(
  String name,
  String value, {
  List<IcalParameter> parameters = const [],
}) => IcalProperty(
  group: null,
  name: name,
  parameters: parameters,
  rawValue: value,
  originalPhysicalLines: const [],
  isDirty: true,
);

String? _nonEmpty(String? source) {
  final value = source?.trim();
  return value == null || value.isEmpty ? null : source;
}

bool _isUtcZone(String? zone) =>
    zone == 'UTC' || zone == 'Etc/UTC' || zone == 'GMT' || zone == 'Etc/GMT';

String _date(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}'
    '${value.month.toString().padLeft(2, '0')}'
    '${value.day.toString().padLeft(2, '0')}';

String _localIcal(DateTime value) =>
    '${_date(value)}T${value.hour.toString().padLeft(2, '0')}'
    '${value.minute.toString().padLeft(2, '0')}'
    '${value.second.toString().padLeft(2, '0')}';

String _utcIcal(DateTime value) => '${_localIcal(value.toUtc())}Z';

_RecurrenceIdentity _nextcloudDetachedTemporal(
  IcalTemporalValue source, {
  bool? forceDate,
}) {
  final isDate = forceDate ?? source.isDate;
  final wall = source.kind == IcalTemporalKind.utcDateTime && !isDate
      ? source.localValue.toLocal()
      : source.localValue;
  final raw = isDate ? _date(wall) : _localIcal(wall);
  final parameters = isDate
      ? const [
          IcalParameter(name: 'VALUE', values: ['DATE'], wasQuoted: false),
        ]
      : const <IcalParameter>[];
  final property = IcalProperty(
    group: null,
    name: 'RECURRENCE-ID',
    parameters: parameters,
    rawValue: raw,
    originalPhysicalLines: const [],
    isDirty: true,
  );
  final key = icalRecurrenceIdKey(property);
  if (key == null) throw _invalidMutation();
  return (raw: raw, parameters: parameters, key: key);
}

IcalTemporalValue _nextcloudRecurrenceIterationTemporal(
  IcalTemporalValue source,
) {
  final detached = _nextcloudDetachedTemporal(source);
  final parsed = parseIcalTemporal(
    IcalProperty(
      group: null,
      name: 'DTSTART',
      parameters: detached.parameters,
      rawValue: detached.raw,
      originalPhysicalLines: const [],
    ),
  );
  if (parsed == null) throw _invalidMutation();
  return parsed;
}

_RawTemporal _nextcloudAdvancedTemporal(
  IcalTemporalValue source, {
  required bool allDay,
}) {
  final wall = source.localValue;
  if (allDay) {
    return (
      value: _date(wall),
      parameters: const [
        IcalParameter(name: 'VALUE', values: ['DATE'], wasQuoted: false),
      ],
    );
  }
  final local = DateTime(
    wall.year,
    wall.month,
    wall.day,
    wall.hour,
    wall.minute,
    wall.second,
  );
  return (value: _utcIcal(local.toUtc()), parameters: const []);
}

int? _rruleCount(String rule) {
  for (final segment in rule.split(';')) {
    final separator = segment.indexOf('=');
    if (separator <= 0) continue;
    if (segment.substring(0, separator).toUpperCase() != 'COUNT') continue;
    final count = int.tryParse(segment.substring(separator + 1));
    if (count == null || count < 1) throw _invalidMutation();
    return count;
  }
  return null;
}

String _replaceRruleCount(String rule, int count) {
  if (count < 1) throw _invalidMutation();
  var replaced = false;
  final result = [
    for (final segment in rule.split(';'))
      if (segment.split('=').first.toUpperCase() == 'COUNT')
        (() {
          if (replaced) throw _invalidMutation();
          replaced = true;
          return '${segment.substring(0, segment.indexOf('='))}=$count';
        })()
      else
        segment,
  ];
  if (!replaced) throw _invalidMutation();
  return result.join(';');
}

_RecurrenceIdentity _recurrenceIdentity(String occurrenceKey) {
  String raw;
  List<IcalParameter> parameters;
  if (occurrenceKey.startsWith('DATE:')) {
    raw = occurrenceKey.substring('DATE:'.length);
    parameters = const [
      IcalParameter(name: 'VALUE', values: ['DATE'], wasQuoted: false),
    ];
  } else if (occurrenceKey.startsWith('FLOATING:')) {
    raw = occurrenceKey.substring('FLOATING:'.length);
    parameters = const [];
  } else if (occurrenceKey.startsWith('UTC:')) {
    final instant = DateTime.tryParse(occurrenceKey.substring('UTC:'.length));
    if (instant == null) throw _invalidMutation();
    raw = _utcIcal(instant);
    parameters = const [];
  } else if (occurrenceKey.startsWith('TZID=')) {
    final separator = occurrenceKey.indexOf(':', 'TZID='.length);
    if (separator <= 'TZID='.length || separator == occurrenceKey.length - 1) {
      throw _invalidMutation();
    }
    final timeZone = occurrenceKey.substring('TZID='.length, separator);
    raw = occurrenceKey.substring(separator + 1);
    parameters = [
      IcalParameter(name: 'TZID', values: [timeZone], wasQuoted: false),
    ];
  } else {
    throw _invalidMutation();
  }
  final property = IcalProperty(
    group: null,
    name: 'RECURRENCE-ID',
    parameters: parameters,
    rawValue: raw,
    originalPhysicalLines: const [],
    isDirty: true,
  );
  final key = icalRecurrenceIdKey(property);
  if (key == null) throw _invalidMutation();
  return (raw: raw, parameters: parameters, key: key);
}

String? _recurrenceValueKey(IcalSemanticComponent component) {
  final property = component.documentComponent.firstProperty('RECURRENCE-ID');
  if (property == null) return null;
  return icalRecurrenceIdKey(
    IcalProperty(
      group: property.group,
      name: property.name,
      parameters: [
        for (final parameter in property.parameters)
          if (parameter.name.toUpperCase() != 'RANGE') parameter,
      ],
      rawValue: property.rawValue,
      originalPhysicalLines: const [],
    ),
  );
}

List<IcalParameter> _withThisAndFuture(List<IcalParameter> parameters) => [
  for (final parameter in parameters)
    if (parameter.name.toUpperCase() != 'RANGE') parameter,
  const IcalParameter(
    name: 'RANGE',
    values: ['THISANDFUTURE'],
    wasQuoted: false,
  ),
];

typedef _RecurrenceIdentity = ({
  String raw,
  List<IcalParameter> parameters,
  String key,
});

DavException _invalidMutation() => const DavException(
  kind: DavErrorKind.invalidCalendarData,
  code: 'DavProjectionMutationInvalid',
  safeMessage: 'The calendar or task edit could not be represented safely.',
);

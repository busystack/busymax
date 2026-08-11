import 'package:busymax/src/dav/ical/ical_document.dart';
import 'package:busymax/src/dav/ical/ical_semantics.dart';
import 'package:busymax/src/dav/mutation/dav_conflict_analyzer.dart';
import 'package:busymax/src/dav/mutation/dav_mutation_patch.dart';
import 'package:busymax/src/dav/mutation/dav_projection_mutations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const target = IcalComponentKey(
    componentType: 'VEVENT',
    uid: 'event@example.test',
  );

  test(
    'patch codec is versioned and narrow edits preserve unknown content',
    () {
      final patch = DavMutationPatch(
        target: target,
        scope: DavMutationScope.recurrenceMaster,
        operations: [
          DavPatchOperation.setText('SUMMARY', 'Updated, title'),
          DavPatchOperation.replaceRepeatedRaw('CATEGORIES', const [
            DavRawPropertyValue(value: r'One\, retained'),
            DavRawPropertyValue(value: 'Two'),
          ]),
        ],
      );
      final decoded = DavMutationPatch.fromJsonString(patch.toJsonString());
      final result = decoded.applyTo(
        _baselineEvent,
        nowUtc: DateTime.utc(2026, 8, 8, 12),
      );
      final semantic = IcalSemanticDocument.parse(result);
      final master = semantic.components.first;

      expect(decoded.schemaVersion, davMutationPatchSchemaVersion);
      expect(master.summary, 'Updated, title');
      expect(master.categories, ['One, retained', 'Two']);
      expect(result, contains('X-UNKNOWN;X-PARAM="a,b":keep-me'));
      expect(result, contains('BEGIN:VTIMEZONE'));
      expect('BEGIN:VALARM'.allMatches(result), hasLength(2));
      expect(result, contains('RECURRENCE-ID;TZID=America/Vancouver'));
    },
  );

  test(
    'task progress patch writes coherent complete, reopen, and partial states',
    () {
      const taskTarget = IcalComponentKey(
        componentType: 'VTODO',
        uid: 'task@example.test',
      );
      String apply(int percent) => DavMutationPatch(
        target: taskTarget,
        scope: DavMutationScope.object,
        operations: [DavPatchOperation.setTaskProgress(percent)],
      ).applyTo(_task, nowUtc: DateTime.utc(2026, 8, 8, 12, 34, 56));

      final completed = IcalSemanticDocument.parse(
        apply(100),
      ).components.single;
      expect(completed.status, 'COMPLETED');
      expect(completed.percentComplete, 100);
      expect(completed.completed?.rawValue, '20260808T123456Z');

      final reopened = IcalSemanticDocument.parse(apply(0)).components.single;
      expect(reopened.status, 'NEEDS-ACTION');
      expect(reopened.percentComplete, isNull);
      expect(reopened.completed, isNull);

      final partial = IcalSemanticDocument.parse(apply(55)).components.single;
      expect(partial.status, 'IN-PROCESS');
      expect(partial.percentComplete, 55);
      expect(partial.completed, isNull);
    },
  );

  test('parent patch preserves non-parent relationships', () {
    const taskTarget = IcalComponentKey(
      componentType: 'VTODO',
      uid: 'task@example.test',
    );
    final result = DavMutationPatch(
      target: taskTarget,
      scope: DavMutationScope.object,
      operations: [DavPatchOperation.setTaskParent('new-parent')],
    ).applyTo(_task, nowUtc: DateTime.utc(2026, 8, 8));
    final component = IcalSemanticDocument.parse(result).components.single;

    expect(component.parentUid, 'new-parent');
    expect(result, contains('RELATED-TO;RELTYPE=CHILD:child-uid'));
    expect(result, contains('RELATED-TO;RELTYPE=SIBLING:sibling-uid'));
    expect(result, isNot(contains('RELATED-TO:old-parent')));
  });

  test('editing one alarm preserves unsupported sibling alarms', () {
    final replacement = IcalComponent(
      name: 'VALARM',
      children: [
        _property('ACTION', 'DISPLAY'),
        _property('TRIGGER', '-PT45M'),
        _property('DESCRIPTION', 'Changed'),
      ],
      originalBeginLine: 'BEGIN:VALARM',
      originalEndLine: 'END:VALARM',
      structurallyDirty: true,
    );
    final result = DavMutationPatch(
      target: target,
      scope: DavMutationScope.recurrenceMaster,
      operations: [
        DavPatchOperation.replaceAlarm(alarmIndex: 0, alarm: replacement),
      ],
    ).applyTo(_baselineEvent, nowUtc: DateTime.utc(2026, 8, 8));

    expect('BEGIN:VALARM'.allMatches(result), hasLength(2));
    expect(result, contains('TRIGGER:-PT45M'));
    expect(result, contains('ACTION:AUDIO'));
    expect(result, contains('X-ALARM-UNKNOWN:keep'));
  });

  test('UTC task dates preserve the entered wall-clock value', () {
    final object = buildDavTaskObject(
      const {
        'title': 'UTC task',
        'microsoftDueDateTime': {
          'dateTime': '2026-08-09T09:30:00',
          'timeZone': 'UTC',
        },
        'microsoftDueTimeZone': 'UTC',
      },
      idFactory: () => 'utc-task',
      nowUtc: () => DateTime.utc(2026, 8, 8),
    );

    final task = IcalSemanticDocument.parse(object.rawIcs).components.single;
    expect(task.due?.rawValue, '20260809T093000Z');
    expect(task.due?.kind, IcalTemporalKind.utcDateTime);
  });

  test('task category edits retain multiple property parameters', () {
    const baseline = '''BEGIN:VCALENDAR\r
VERSION:2.0\r
BEGIN:VTODO\r
UID:categories@example.test\r
SUMMARY:Categories\r
CATEGORIES;LANGUAGE=en:One,Two\r
CATEGORIES;X-KEEP=yes:Three\r
END:VTODO\r
END:VCALENDAR\r
''';
    final patch = buildDavTaskUpdatePatch(
      target: const IcalComponentKey(
        componentType: 'VTODO',
        uid: 'categories@example.test',
      ),
      baselineRawIcs: baseline,
      fields: const {
        'categories': ['Two', 'Three', 'Four'],
      },
    );

    final result = patch!.applyTo(baseline, nowUtc: DateTime.utc(2026, 8, 8));
    expect(result, contains('CATEGORIES;LANGUAGE=en:Two,Four'));
    expect(result, contains('CATEGORIES;X-KEEP=yes:Three'));
    expect(IcalSemanticDocument.parse(result).components.single.categories, [
      'Two',
      'Four',
      'Three',
    ]);
  });

  test('task reminder update replaces DISPLAY and preserves AUDIO sibling', () {
    const baseline = '''BEGIN:VCALENDAR\r
VERSION:2.0\r
BEGIN:VTODO\r
UID:task-alarm@example.test\r
DTSTART:20260809T090000Z\r
DUE:20260809T100000Z\r
SUMMARY:Task with alarms\r
BEGIN:VALARM\r
ACTION:DISPLAY\r
DESCRIPTION:Imported reminder\r
TRIGGER;VALUE=DATE-TIME:20260809T080000Z\r
END:VALARM\r
BEGIN:VALARM\r
ACTION:AUDIO\r
TRIGGER:-PT5M\r
ATTACH:Glass\r
X-ALARM-KEEP:opaque\r
END:VALARM\r
END:VTODO\r
END:VCALENDAR\r
''';
    final patch = buildDavTaskUpdatePatch(
      target: const IcalComponentKey(
        componentType: 'VTODO',
        uid: 'task-alarm@example.test',
      ),
      baselineRawIcs: baseline,
      fields: const {
        'microsoftIsReminderOn': true,
        'microsoftReminderDateTime': {
          'dateTime': '2026-08-09T07:30:00Z',
          'timeZone': 'UTC',
        },
      },
    );

    final result = patch!.applyTo(baseline, nowUtc: DateTime.utc(2026, 8, 8));
    expect('BEGIN:VALARM'.allMatches(result), hasLength(2));
    expect(result, contains('TRIGGER;VALUE=DATE-TIME:20260809T073000Z'));
    expect(result, isNot(contains('20260809T080000Z')));
    expect(result, contains('ACTION:AUDIO'));
    expect(result, contains('ATTACH:Glass'));
    expect(result, contains('X-ALARM-KEEP:opaque'));
  });

  test(
    'recurring task completion records an exception and advances the master',
    () {
      final patch = buildDavRecurringTaskCompletionPatch(
        target: const IcalComponentKey(
          componentType: 'VTODO',
          uid: 'recurring-task@example.test',
        ),
        baselineRawIcs: _recurringTask,
        completedAtUtc: DateTime.utc(2026, 8, 9, 17, 30),
        nowUtc: () => DateTime.utc(2026, 8, 9, 18),
      );
      final result = patch.applyTo(
        _recurringTask,
        nowUtc: DateTime.utc(2026, 8, 9, 18),
      );
      final semantic = IcalSemanticDocument.parse(result);
      final master = semantic.components.singleWhere(
        (component) => component.recurrenceId == null,
      );
      final exception = semantic.components.singleWhere(
        (component) => component.recurrenceId != null,
      );

      expect(master.start?.rawValue, '20260810');
      expect(master.due?.rawValue, '20260811');
      expect(master.recurrenceRules, ['FREQ=DAILY;COUNT=2']);
      expect(master.status, isNull);
      expect(master.percentComplete, isNull);
      expect(master.completed, isNull);
      expect(master.lastModified?.rawValue, '20260809T180000Z');
      expect(master.dtstamp?.rawValue, '20260809T180000Z');

      expect(exception.recurrenceIdKey, 'VALUE=DATE:20260810');
      expect(exception.start?.rawValue, '20260809');
      expect(exception.due?.rawValue, '20260810');
      expect(exception.summary, 'Recurring task');
      expect(exception.description, 'Retained details');
      expect(exception.location, 'Vancouver');
      expect(exception.url, 'https://cloud.example.test/task/1');
      expect(exception.priority, 4);
      expect(exception.classification, 'PUBLIC');
      expect(exception.status, 'COMPLETED');
      expect(exception.percentComplete, 100);
      expect(exception.completed?.rawValue, '20260809T173000Z');
      expect(result, contains('X-UNKNOWN:keep-me'));
      expect(result, contains('BEGIN:VALARM'));
    },
  );

  test('last COUNT occurrence completes both exception and master', () {
    final baseline = _recurringTask.replaceFirst('COUNT=3', 'COUNT=1');
    final result = buildDavRecurringTaskCompletionPatch(
      target: const IcalComponentKey(
        componentType: 'VTODO',
        uid: 'recurring-task@example.test',
      ),
      baselineRawIcs: baseline,
      nowUtc: () => DateTime.utc(2026, 8, 9, 18),
    ).applyTo(baseline, nowUtc: DateTime.utc(2026, 8, 9, 18));
    final components = IcalSemanticDocument.parse(result).components;
    final master = components.singleWhere(
      (component) => component.recurrenceId == null,
    );

    expect(components, hasLength(2));
    expect(master.due?.rawValue, '20260810');
    expect(master.recurrenceRules, ['FREQ=DAILY;COUNT=1']);
    expect(master.status, 'COMPLETED');
    expect(master.percentComplete, 100);
    expect(master.completed?.rawValue, '20260809T180000Z');
  });

  test('an exhausted UNTIL rule retains the master and records history', () {
    final baseline = _recurringTask.replaceFirst(
      'FREQ=DAILY;COUNT=3',
      'FREQ=DAILY;UNTIL=20260810',
    );
    final result = buildDavRecurringTaskCompletionPatch(
      target: const IcalComponentKey(
        componentType: 'VTODO',
        uid: 'recurring-task@example.test',
      ),
      baselineRawIcs: baseline,
      nowUtc: () => DateTime.utc(2026, 8, 9, 18),
    ).applyTo(baseline, nowUtc: DateTime.utc(2026, 8, 9, 18));
    final components = IcalSemanticDocument.parse(result).components;
    final master = components.singleWhere(
      (component) => component.recurrenceId == null,
    );

    expect(components, hasLength(2));
    expect(master.due?.rawValue, '20260810');
    expect(master.start?.rawValue, '20260809');
    expect(master.status, isNull);
    expect(master.recurrenceRules, ['FREQ=DAILY;UNTIL=20260810']);
  });

  test(
    'component add and remove round-trip without replacing the resource',
    () {
      final exception = IcalComponent(
        name: 'VEVENT',
        children: [
          _property('UID', 'event@example.test'),
          _property('DTSTAMP', '20260808T120000Z'),
          _property('RECURRENCE-ID', '20260817T090000'),
          _property('DTSTART', '20260817T130000'),
          _property('DTEND', '20260817T140000'),
          _property('SUMMARY', 'Added exception'),
        ],
        originalBeginLine: 'BEGIN:VEVENT',
        originalEndLine: 'END:VEVENT',
        structurallyDirty: true,
      );
      final add = DavMutationPatch(
        target: const IcalComponentKey(
          componentType: 'VEVENT',
          uid: 'event@example.test',
          recurrenceIdKey: '20260817T090000',
        ),
        scope: DavMutationScope.occurrence,
        operations: [DavPatchOperation.addComponent(exception)],
      );
      final decoded = DavMutationPatch.fromJsonString(add.toJsonString());
      final added = decoded.applyTo(
        _baselineEvent,
        nowUtc: DateTime.utc(2026, 8, 8),
      );

      expect('BEGIN:VEVENT'.allMatches(added), hasLength(3));
      expect(added, contains('SUMMARY:Added exception'));
      expect(added, contains('X-UNKNOWN;X-PARAM="a,b":keep-me'));
      expect(decoded.changedProperties, {'COMPONENT-SET'});

      final removed = DavMutationPatch(
        target: const IcalComponentKey(
          componentType: 'VEVENT',
          uid: 'event@example.test',
          recurrenceIdKey: 'TZID=America/Vancouver:20260810T090000',
        ),
        scope: DavMutationScope.recurrenceException,
        operations: [DavPatchOperation.removeComponent()],
      ).applyTo(_baselineEvent, nowUtc: DateTime.utc(2026, 8, 8));
      expect('BEGIN:VEVENT'.allMatches(removed), hasLength(1));
      expect(removed, contains('BEGIN:VTIMEZONE'));
      expect(removed, contains('X-UNKNOWN;X-PARAM="a,b":keep-me'));
    },
  );

  test('component-set mutation conflicts with any semantic remote edit', () {
    final patch = DavMutationPatch(
      target: const IcalComponentKey(
        componentType: 'VEVENT',
        uid: 'event@example.test',
        recurrenceIdKey: '20260817T090000',
      ),
      scope: DavMutationScope.occurrence,
      operations: [
        DavPatchOperation.addComponent(
          IcalComponent(
            name: 'VEVENT',
            children: [
              _property('UID', 'event@example.test'),
              _property('RECURRENCE-ID', '20260817T090000'),
              _property('DTSTART', '20260817T090000'),
              _property('DTEND', '20260817T100000'),
            ],
            originalBeginLine: 'BEGIN:VEVENT',
            originalEndLine: 'END:VEVENT',
            structurallyDirty: true,
          ),
        ),
      ],
    );

    final result = const DavConflictAnalyzer().analyzeUpdate(
      baselineRawIcs: _baselineEvent,
      currentRemoteRawIcs: _baselineEvent.replaceFirst(
        'LOCATION:Room one',
        'LOCATION:Remote room',
      ),
      localPatch: patch,
      nowUtc: DateTime.utc(2026, 8, 8),
    );
    expect(result.outcome, DavConflictOutcome.conflict);
    expect(result.conflictCode, 'DavConflictBroadRecurrenceChange');
  });

  test('one-occurrence edit adds an in-resource detached exception', () {
    final patch = buildDavEventOccurrenceExceptionPatch(
      uid: 'event@example.test',
      occurrenceKey: 'TZID=America/Vancouver:20260817T090000',
      baselineRawIcs: _baselineEvent,
      input: DavEventMutationInput(
        title: 'Only this occurrence',
        allDay: false,
        start: DateTime(2026, 8, 17, 14),
        end: DateTime(2026, 8, 17, 15),
        startTimeZone: 'America/Vancouver',
        endTimeZone: 'America/Vancouver',
        reminders: const {
          'overrides': [
            {'minutes': 15},
            {'minutes': 45},
          ],
        },
      ),
      nowUtc: () => DateTime.utc(2026, 8, 8, 12),
    );
    final candidate = patch.applyTo(
      _baselineEvent,
      nowUtc: DateTime.utc(2026, 8, 8, 12),
    );
    final semantic = IcalSemanticDocument.parse(candidate);
    final added = semantic.components.singleWhere(
      (component) =>
          component.recurrenceIdKey == 'TZID=America/Vancouver:20260817T090000',
    );

    expect(patch.scope, DavMutationScope.occurrence);
    expect(added.summary, 'Only this occurrence');
    expect(added.start?.rawValue, '20260817T140000');
    expect(added.alarms, hasLength(2));
    expect(candidate, contains('RRULE:FREQ=WEEKLY;COUNT=2'));
    expect(candidate, contains('X-UNKNOWN;X-PARAM="a,b":keep-me'));
  });

  test('one-occurrence delete creates or updates a cancelled exception', () {
    final generated = buildDavEventOccurrenceCancellationPatch(
      uid: 'event@example.test',
      occurrenceKey: 'TZID=America/Vancouver:20260817T090000',
      baselineRawIcs: _baselineEvent,
      nowUtc: () => DateTime.utc(2026, 8, 8, 12),
    ).applyTo(_baselineEvent, nowUtc: DateTime.utc(2026, 8, 8, 12));
    expect(generated, contains('STATUS:CANCELLED'));
    expect('BEGIN:VEVENT'.allMatches(generated), hasLength(3));

    final existing = buildDavEventOccurrenceCancellationPatch(
      uid: 'event@example.test',
      occurrenceKey: 'TZID=America/Vancouver:20260810T090000',
      baselineRawIcs: _baselineEvent,
    ).applyTo(_baselineEvent, nowUtc: DateTime.utc(2026, 8, 8, 12));
    final exception = IcalSemanticDocument.parse(
      existing,
    ).components.singleWhere((component) => component.recurrenceIdKey != null);
    expect(exception.status, 'CANCELLED');
    expect('BEGIN:VEVENT'.allMatches(existing), hasLength(2));
  });

  test(
    'three-way merge applies disjoint local change to current server body',
    () {
      final remote = _baselineEvent.replaceFirst(
        'LOCATION:Room one',
        'LOCATION:Room two',
      );
      final patch = DavMutationPatch(
        target: target,
        scope: DavMutationScope.recurrenceMaster,
        operations: [DavPatchOperation.setText('SUMMARY', 'Local summary')],
      );

      final result = const DavConflictAnalyzer().analyzeUpdate(
        baselineRawIcs: _baselineEvent,
        currentRemoteRawIcs: remote,
        localPatch: patch,
        nowUtc: DateTime.utc(2026, 8, 8),
      );

      expect(result.outcome, DavConflictOutcome.autoMerged);
      expect(result.remoteChangedProperties, {'LOCATION'});
      expect(result.mergedRawIcs, contains('SUMMARY:Local summary'));
      expect(result.mergedRawIcs, contains('LOCATION:Room two'));
      expect(result.mergedRawIcs, contains('X-UNKNOWN'));
    },
  );

  test(
    'same-property and broad recurrence edits become explicit conflicts',
    () {
      final summaryPatch = DavMutationPatch(
        target: target,
        scope: DavMutationScope.recurrenceMaster,
        operations: [DavPatchOperation.setText('SUMMARY', 'Local')],
      );
      final sameProperty = const DavConflictAnalyzer().analyzeUpdate(
        baselineRawIcs: _baselineEvent,
        currentRemoteRawIcs: _baselineEvent.replaceFirst(
          'SUMMARY:Baseline',
          'SUMMARY:Remote',
        ),
        localPatch: summaryPatch,
        nowUtc: DateTime.utc(2026, 8, 8),
      );
      expect(sameProperty.outcome, DavConflictOutcome.conflict);
      expect(sameProperty.conflictCode, 'DavConflictOverlappingProperties');

      final recurrencePatch = DavMutationPatch(
        target: target,
        scope: DavMutationScope.recurrenceMaster,
        operations: [DavPatchOperation.setRaw('RRULE', 'FREQ=DAILY;COUNT=5')],
      );
      final broad = const DavConflictAnalyzer().analyzeUpdate(
        baselineRawIcs: _baselineEvent,
        currentRemoteRawIcs: _baselineEvent.replaceFirst(
          'DESCRIPTION:Baseline details',
          'DESCRIPTION:Remote details',
        ),
        localPatch: recurrencePatch,
        nowUtc: DateTime.utc(2026, 8, 8),
      );
      expect(broad.outcome, DavConflictOutcome.conflict);
      expect(broad.conflictCode, 'DavConflictBroadRecurrenceChange');
    },
  );

  test(
    'exception-set change and stale delete cannot be silently overwritten',
    () {
      final local = DavMutationPatch(
        target: target,
        scope: DavMutationScope.recurrenceMaster,
        operations: [DavPatchOperation.setText('SUMMARY', 'Local')],
      );
      final addedException = _baselineEvent.replaceFirst(
        'END:VCALENDAR',
        '''BEGIN:VEVENT\r
UID:event@example.test\r
RECURRENCE-ID;TZID=America/Vancouver:20260817T090000\r
DTSTART;TZID=America/Vancouver:20260817T120000\r
DTEND;TZID=America/Vancouver:20260817T130000\r
SUMMARY:New exception\r
END:VEVENT\r
END:VCALENDAR''',
      );
      final recurrenceSet = const DavConflictAnalyzer().analyzeUpdate(
        baselineRawIcs: _baselineEvent,
        currentRemoteRawIcs: addedException,
        localPatch: local,
        nowUtc: DateTime.utc(2026, 8, 8),
      );
      expect(recurrenceSet.outcome, DavConflictOutcome.conflict);
      expect(recurrenceSet.remoteChangedProperties, {'RECURRENCE-SET'});

      final staleDelete = const DavConflictAnalyzer().analyzeDelete(
        baselineRawIcs: _baselineEvent,
        currentRemoteRawIcs: _baselineEvent.replaceFirst(
          'LOCATION:Room one',
          'LOCATION:Remote room',
        ),
      );
      expect(staleDelete.outcome, DavConflictOutcome.conflict);
      expect(staleDelete.conflictCode, 'DavConflictStaleDelete');
    },
  );

  test('server folding canonicalization is not treated as a conflict', () {
    final folded = _baselineEvent.replaceFirst(
      'DESCRIPTION:Baseline details',
      'DESCRIPTION:Baseline\r\n  details',
    );
    final patch = DavMutationPatch(
      target: target,
      scope: DavMutationScope.recurrenceMaster,
      operations: [DavPatchOperation.setText('SUMMARY', 'Local')],
    );
    final result = const DavConflictAnalyzer().analyzeUpdate(
      baselineRawIcs: _baselineEvent,
      currentRemoteRawIcs: folded,
      localPatch: patch,
      nowUtc: DateTime.utc(2026, 8, 8),
    );

    expect(result.outcome, DavConflictOutcome.remoteUnchanged);
    expect(result.mergedRawIcs, contains('SUMMARY:Local'));
  });
}

IcalProperty _property(String name, String value) => IcalProperty(
  group: null,
  name: name,
  parameters: const [],
  rawValue: value,
  originalPhysicalLines: const [],
  isDirty: true,
);

const _baselineEvent = '''BEGIN:VCALENDAR\r
VERSION:2.0\r
PRODID:-//BusyMax Test//EN\r
BEGIN:VTIMEZONE\r
TZID:America/Vancouver\r
X-LIC-LOCATION:America/Vancouver\r
END:VTIMEZONE\r
BEGIN:VEVENT\r
UID:event@example.test\r
DTSTART;TZID=America/Vancouver:20260803T090000\r
DTEND;TZID=America/Vancouver:20260803T100000\r
RRULE:FREQ=WEEKLY;COUNT=2\r
SUMMARY:Baseline\r
DESCRIPTION:Baseline details\r
LOCATION:Room one\r
CATEGORIES:One\r
X-UNKNOWN;X-PARAM="a,b":keep-me\r
BEGIN:VALARM\r
ACTION:DISPLAY\r
TRIGGER:-PT15M\r
DESCRIPTION:Reminder\r
END:VALARM\r
BEGIN:VALARM\r
ACTION:AUDIO\r
TRIGGER:-PT5M\r
X-ALARM-UNKNOWN:keep\r
END:VALARM\r
END:VEVENT\r
BEGIN:VEVENT\r
UID:event@example.test\r
RECURRENCE-ID;TZID=America/Vancouver:20260810T090000\r
DTSTART;TZID=America/Vancouver:20260810T110000\r
DTEND;TZID=America/Vancouver:20260810T120000\r
SUMMARY:Moved\r
END:VEVENT\r
END:VCALENDAR\r
''';

const _task = '''BEGIN:VCALENDAR\r
VERSION:2.0\r
PRODID:-//Nextcloud Tasks//EN\r
BEGIN:VTODO\r
UID:task@example.test\r
SUMMARY:Task\r
STATUS:IN-PROCESS\r
PERCENT-COMPLETE:25\r
COMPLETED:20260801T120000Z\r
RELATED-TO:old-parent\r
RELATED-TO;RELTYPE=CHILD:child-uid\r
RELATED-TO;RELTYPE=SIBLING:sibling-uid\r
X-PINNED:1\r
END:VTODO\r
END:VCALENDAR\r
''';

const _recurringTask = '''BEGIN:VCALENDAR\r
VERSION:2.0\r
PRODID:-//Nextcloud Tasks//EN\r
BEGIN:VTODO\r
UID:recurring-task@example.test\r
DTSTAMP:20260801T120000Z\r
DTSTART;VALUE=DATE:20260809\r
DUE;VALUE=DATE:20260810\r
RRULE:FREQ=DAILY;COUNT=3\r
SUMMARY:Recurring task\r
DESCRIPTION:Retained details\r
LOCATION:Vancouver\r
URL:https://cloud.example.test/task/1\r
PRIORITY:4\r
X-UNKNOWN:keep-me\r
BEGIN:VALARM\r
ACTION:DISPLAY\r
DESCRIPTION:This is a todo reminder.\r
TRIGGER;RELATED=END:-PT1H\r
END:VALARM\r
END:VTODO\r
END:VCALENDAR\r
''';

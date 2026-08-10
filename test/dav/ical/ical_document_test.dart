import 'dart:convert';

import 'package:busymax/src/dav/dav_errors.dart';
import 'package:busymax/src/dav/ical/ical_document.dart';
import 'package:busymax/src/dav/ical/ical_semantics.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('untouched parsing returns the exact original resource', () {
    final source = _complexEvent.replaceAll('\r\n', '\n');
    final document = IcalDocument.parse(source);

    expect(document.serialize(), source);
    expect(document.isDirty, isFalse);
  });

  test(
    'patching one property preserves recurrence set and unknown content',
    () {
      final semantic = IcalSemanticDocument.parse(_complexEvent);
      final document = semantic.document;
      final master = semantic.components.singleWhere(
        (component) => component.recurrenceIdKey == null,
      );
      expect(master.summary, 'Résumé planning 📅');
      expect(master.start?.kind, IcalTemporalKind.tzidDateTime);
      expect(master.start?.timeZoneId, 'America/Vancouver');
      expect(master.recurrenceRules, ['FREQ=WEEKLY;COUNT=4;BYDAY=MO']);
      expect(master.recurrenceDates, ['20260818T090000']);
      expect(master.exceptionDates, ['20260811T090000']);
      expect(master.alarms, hasLength(2));
      expect(master.extensionProperties['X-BUSYMAX-FUTURE'], ['opaque:value']);
      expect(semantic.timeZones, hasLength(1));
      expect(semantic.buildIndex(), hasLength(2));

      final attendee = master.documentComponent.firstProperty('ATTENDEE')!;
      expect(attendee.parametersNamed('X-ROLE'), hasLength(2));
      expect(attendee.parameterValue('CN'), 'Doe, Jane: Lead; West');

      IcalDocumentPatcher(document).replaceSingletonText(
        const IcalComponentKey(
          componentType: 'VEVENT',
          uid: 'event-uid@example.test',
        ),
        'SUMMARY',
        'Updated résumé with a very long multi-byte title 📅📅📅📅📅📅📅📅📅📅',
      );
      final serialized = document.serialize();
      final reparsed = IcalSemanticDocument.parse(serialized);

      expect(serialized, contains('X-IANA-UNKNOWN;VALUE=TEXT:keep-me'));
      expect(serialized, contains('X-BUSYMAX-FUTURE:opaque:value'));
      expect(serialized, contains('BEGIN:VTIMEZONE'));
      expect('BEGIN:VALARM'.allMatches(serialized), hasLength(2));
      expect(serialized, contains('RECURRENCE-ID;TZID=America/Vancouver'));
      expect(serialized, contains('X-ROLE=PRIMARY;X-ROLE=SECONDARY'));
      expect(serialized, contains('CN="Doe, Jane: Lead; West"'));
      expect(reparsed.components, hasLength(2));
      expect(
        reparsed.components
            .singleWhere((component) => component.recurrenceIdKey == null)
            .summary,
        startsWith('Updated résumé'),
      );
      for (final line
          in serialized.split('\r\n').where((line) => line.isNotEmpty)) {
        expect(utf8.encode(line).length, lessThanOrEqualTo(75), reason: line);
      }
    },
  );

  test('repeated replacements do not remove unrelated repeated properties', () {
    final semantic = IcalSemanticDocument.parse(_complexEvent);
    final patcher = IcalDocumentPatcher(semantic.document);
    const key = IcalComponentKey(
      componentType: 'VEVENT',
      uid: 'event-uid@example.test',
    );
    patcher.replaceRepeatedRaw(key, 'CATEGORIES', [
      (value: r'Updated\, category', parameters: const []),
      (value: 'Second', parameters: const []),
    ]);
    patcher.replaceSingletonText(key, 'LOCATION', null);
    final result = IcalSemanticDocument.parse(semantic.document.serialize());
    final master = result.components.first;

    expect(master.categories, ['Updated, category', 'Second']);
    expect(master.location, equals(null));
    expect(master.attendees, hasLength(1));
    expect(master.alarms, hasLength(2));
  });

  test('all-day values remain dates with exclusive DTEND', () {
    final component = IcalSemanticDocument.parse(
      _allDayEvent,
    ).components.single;

    expect(component.start?.kind, IcalTemporalKind.date);
    expect(component.start?.rawValue, '20260808');
    expect(component.end?.kind, IcalTemporalKind.date);
    expect(component.end?.rawValue, '20260810');
  });

  test(
    'VTODO semantics preserve hierarchy, priority, progress, and extensions',
    () {
      final semantic = IcalSemanticDocument.parse(_taskResource);
      final task = semantic.components.single;

      expect(task.componentType, 'VTODO');
      expect(task.parentUid, 'parent-uid');
      expect(task.priority, 7);
      expect(task.sortOrder, 42);
      expect(task.percentComplete, 50);
      expect(task.taskUiState, IcalTaskUiState.inProgress);
      expect(task.extensionProperties['X-PINNED'], ['1']);
      expect(task.extensionProperties['X-OC-HIDESUBTASKS'], ['1']);
      expect(
        task.documentComponent.propertiesNamed('RELATED-TO'),
        hasLength(3),
      );
      expect(semantic.document.serialize(), _taskResource);
    },
  );

  test('percent complete alone does not close a Nextcloud task', () {
    final semantic = IcalSemanticDocument.parse('''BEGIN:VCALENDAR\r
VERSION:2.0\r
BEGIN:VTODO\r
UID:percent-only@example.test\r
SUMMARY:Percent only\r
PERCENT-COMPLETE:100\r
END:VTODO\r
END:VCALENDAR\r
''');

    expect(semantic.components.single.taskUiState, IcalTaskUiState.open);
  });

  test('semantic hashes ignore folding and property ordering', () {
    final first = IcalSemanticDocument.parse(_allDayEvent);
    final second = IcalSemanticDocument.parse('''BEGIN:VCALENDAR\r
VERSION:2.0\r
PRODID:-//BusyMax Test//EN\r
BEGIN:VEVENT\r
SUMMARY:All-day event\r
DTEND;VALUE=DATE:20260810\r
UID:all-day@example.test\r
DTSTART;VALUE=DATE:20260808\r
DTSTAMP:20260801T120000Z\r
END:VEVENT\r
END:VCALENDAR\r
''');

    expect(first.semanticHash, second.semanticHash);
  });

  test('rejects malformed structures, invalid dates, and mixed UIDs', () {
    expect(
      () => IcalDocument.parse('BEGIN:VCALENDAR\r\nEND:VEVENT\r\n'),
      throwsA(isA<DavException>()),
    );
    expect(
      () => IcalSemanticDocument.parse(
        _allDayEvent.replaceFirst('20260808', '20261340'),
      ),
      throwsA(
        isA<DavException>().having(
          (error) => error.code,
          'code',
          'IcalInvalidTemporalValue',
        ),
      ),
    );
    expect(
      () => IcalSemanticDocument.parse(
        _complexEvent.replaceFirst(
          'RECURRENCE-ID;TZID=America/Vancouver:20260818T090000',
          'UID:different@example.test\r\n'
              'RECURRENCE-ID;TZID=America/Vancouver:20260818T090000',
        ),
      ),
      throwsA(
        isA<DavException>().having(
          (error) => error.code,
          'code',
          'IcalCalendarObjectInvariantFailed',
        ),
      ),
    );
  });

  test('new resources include valid framing and text escaping', () {
    final component = IcalComponent(
      name: 'VTODO',
      children: [
        _property('UID', 'new-task@example.test'),
        _property('DTSTAMP', '20260808T120000Z'),
        _property('SUMMARY', encodeIcalText('One, two; three\nnext')),
      ],
      originalBeginLine: 'BEGIN:VTODO',
      originalEndLine: 'END:VTODO',
      structurallyDirty: true,
    );
    final document = IcalDocument.create(components: [component]);
    final serialized = document.serialize();
    final parsed = IcalSemanticDocument.parse(serialized).components.single;

    expect(serialized, startsWith('BEGIN:VCALENDAR\r\n'));
    expect(serialized, endsWith('END:VCALENDAR\r\n'));
    expect(serialized, contains('VERSION:2.0'));
    expect(parsed.summary, 'One, two; three\nnext');
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

const _complexEvent = '''BEGIN:VCALENDAR\r
PRODID:-//BusyMax Test//EN\r
VERSION:2.0\r
X-WR-CALNAME:Preserve this\r
BEGIN:VTIMEZONE\r
TZID:America/Vancouver\r
X-LIC-LOCATION:America/Vancouver\r
BEGIN:STANDARD\r
DTSTART:19701101T020000\r
TZOFFSETFROM:-0700\r
TZOFFSETTO:-0800\r
RRULE:FREQ=YEARLY;BYMONTH=11;BYDAY=1SU\r
END:STANDARD\r
END:VTIMEZONE\r
BEGIN:VEVENT\r
UID:event-uid@example.test\r
DTSTAMP:20260801T120000Z\r
SEQUENCE:3\r
DTSTART;TZID=America/Vancouver:20260804T090000\r
DTEND;TZID=America/Vancouver:20260804T100000\r
SUMMARY:Résumé planning 📅\r
DESCRIPTION:Line one\\nLine two\\, retained\r
LOCATION:Office\r
RRULE:FREQ=WEEKLY;COUNT=4;BYDAY=MO\r
RDATE;TZID=America/Vancouver:20260818T090000\r
EXDATE;TZID=America/Vancouver:20260811T090000\r
CATEGORIES:Planning,Team\r
ATTENDEE;X-ROLE=PRIMARY;X-ROLE=SECONDARY;CN="Doe, Jane: Lead; West":mailto:jane@example.test\r
ORGANIZER;CN=Alex:mailto:alex@example.test\r
X-IANA-UNKNOWN;VALUE=TEXT:keep-me\r
X-BUSYMAX-FUTURE:opaque:value\r
BEGIN:VALARM\r
ACTION:DISPLAY\r
TRIGGER:-PT15M\r
DESCRIPTION:Reminder\r
END:VALARM\r
BEGIN:VALARM\r
ACTION:AUDIO\r
TRIGGER:-PT5M\r
ATTACH;VALUE=URI:Basso\r
END:VALARM\r
END:VEVENT\r
BEGIN:VEVENT\r
UID:event-uid@example.test\r
RECURRENCE-ID;TZID=America/Vancouver:20260818T090000\r
DTSTAMP:20260802T120000Z\r
DTSTART;TZID=America/Vancouver:20260818T110000\r
DTEND;TZID=America/Vancouver:20260818T120000\r
SUMMARY:Moved occurrence\r
X-EXCEPTION-UNKNOWN:retain\r
END:VEVENT\r
END:VCALENDAR\r
''';

const _allDayEvent = '''BEGIN:VCALENDAR\r
PRODID:-//BusyMax Test//EN\r
VERSION:2.0\r
BEGIN:VEVENT\r
UID:all-day@example.test\r
DTSTAMP:20260801T120000Z\r
DTSTART;VALUE=DATE:20260808\r
DTEND;VALUE=DATE:20260810\r
SUMMARY:All-day event\r
END:VEVENT\r
END:VCALENDAR\r
''';

const _taskResource = '''BEGIN:VCALENDAR\r
PRODID:-//Nextcloud Tasks//EN\r
VERSION:2.0\r
BEGIN:VTODO\r
UID:task-uid\r
DTSTAMP:20260808T120000Z\r
SUMMARY:Task title\r
DESCRIPTION:Keep details\r
DTSTART;TZID=America/Vancouver:20260808T090000\r
DUE;TZID=America/Vancouver:20260809T170000\r
STATUS:IN-PROCESS\r
PERCENT-COMPLETE:50\r
PRIORITY:7\r
RELATED-TO:parent-uid\r
RELATED-TO;RELTYPE=CHILD:child-uid\r
RELATED-TO;RELTYPE=SIBLING:sibling-uid\r
X-APPLE-SORT-ORDER:42\r
X-PINNED:1\r
X-OC-HIDESUBTASKS:1\r
X-OC-HIDECOMPLETEDSUBTASKS:0\r
BEGIN:VALARM\r
ACTION:DISPLAY\r
TRIGGER:-PT30M\r
END:VALARM\r
END:VTODO\r
END:VCALENDAR\r
''';

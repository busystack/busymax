import 'package:busymax/src/dav/ical/ical_document.dart';
import 'package:busymax/src/dav/ical/ical_task_alarm.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('relative DISPLAY alarm uses the RFC 5545 due-date relation', () {
    final alarm = IcalTaskAlarm.displayRelative(
      const Duration(hours: -2),
      relatedToDue: true,
    );
    final component = alarm.toComponent();

    expect(alarm.action, 'DISPLAY');
    expect(alarm.isRelative, isTrue);
    expect(alarm.isRelatedToDue, isTrue);
    expect(alarm.relativeOffset, const Duration(hours: -2));
    expect(component.firstProperty('TRIGGER')?.rawValue, '-PT2H');
    expect(
      component.firstProperty('TRIGGER')?.parameterValue('RELATED'),
      'END',
    );
    expect(
      component.firstProperty('DESCRIPTION')?.decodedTextValue,
      'This is a todo reminder.',
    );
  });

  test('absolute DISPLAY alarm is stored as a UTC DATE-TIME', () {
    final alarm = IcalTaskAlarm.displayAbsolute(
      DateTime.parse('2026-08-09T10:15:30-07:00'),
    );

    expect(alarm.isAbsolute, isTrue);
    expect(alarm.absoluteUtc, DateTime.utc(2026, 8, 9, 17, 15, 30));
    expect(alarm.triggerRaw, '20260809T171530Z');
    expect(alarm.canEditTrigger, isTrue);
    expect(alarm.canEditTriggerFor(allDay: false), isTrue);
  });

  test('matches Nextcloud relative-alarm editing restrictions', () {
    final beforeStart = IcalTaskAlarm.displayRelative(
      const Duration(minutes: -10),
      relatedToDue: false,
    );
    final afterStart = IcalTaskAlarm.displayRelative(
      const Duration(hours: 9),
      relatedToDue: false,
    );
    final afterStartNextDay = IcalTaskAlarm.displayRelative(
      const Duration(hours: 25),
      relatedToDue: false,
    );
    final beforeDue = IcalTaskAlarm.displayRelative(
      const Duration(minutes: -10),
      relatedToDue: true,
    );

    expect(beforeStart.canEditTriggerFor(allDay: false), isTrue);
    expect(afterStart.canEditTriggerFor(allDay: false), isFalse);
    expect(afterStart.canEditTriggerFor(allDay: true), isTrue);
    expect(afterStartNextDay.canEditTriggerFor(allDay: true), isFalse);
    expect(beforeDue.canEditTriggerFor(allDay: false), isFalse);
    expect(beforeDue.canEditTriggerFor(allDay: true), isFalse);
  });

  test(
    'unsupported alarm properties survive JSON and component round trips',
    () {
      final imported = IcalTaskAlarm.fromComponent(
        IcalComponent(
          name: 'VALARM',
          children: [
            _property('ACTION', 'AUDIO'),
            _property('TRIGGER', '-PT5M'),
            _property(
              'ATTACH',
              'https://cloud.example.test/chime.ogg',
              parameters: const [
                IcalParameter(
                  name: 'FMTTYPE',
                  values: ['audio/ogg'],
                  wasQuoted: false,
                ),
              ],
            ),
            _property('X-NEXTCLOUD-UNKNOWN', 'opaque'),
          ],
          originalBeginLine: 'BEGIN:VALARM',
          originalEndLine: 'END:VALARM',
        ),
      );
      final decoded = decodeIcalTaskAlarms(encodeIcalTaskAlarms([imported]));
      final component = decoded.single.toComponent();

      expect(decoded.single, imported);
      expect(component.firstProperty('ACTION')?.rawValue, 'AUDIO');
      expect(
        component.firstProperty('ATTACH')?.parameterValue('FMTTYPE'),
        'audio/ogg',
      );
      expect(
        component.firstProperty('X-NEXTCLOUD-UNKNOWN')?.rawValue,
        'opaque',
      );
    },
  );

  test('malformed imported trigger remains visible but is not editable', () {
    final alarm = IcalTaskAlarm.fromComponent(
      IcalComponent(
        name: 'VALARM',
        children: [_property('ACTION', 'EMAIL'), _property('TRIGGER', 'bad')],
        originalBeginLine: 'BEGIN:VALARM',
        originalEndLine: 'END:VALARM',
      ),
    );
    final decoded = decodeIcalTaskAlarms(encodeIcalTaskAlarms([alarm])).single;

    expect(decoded.triggerRaw, 'bad');
    expect(decoded.isRelative, isFalse);
    expect(decoded.isAbsolute, isFalse);
    expect(decoded.canEditTrigger, isFalse);
  });

  test('reads an RFC alarm repetition pair', () {
    final alarm = IcalTaskAlarm.fromComponent(
      IcalComponent(
        name: 'VALARM',
        children: [
          _property('ACTION', 'AUDIO'),
          _property('TRIGGER', '-PT15M'),
          _property('REPEAT', '2'),
          _property('DURATION', 'PT5M'),
        ],
        originalBeginLine: 'BEGIN:VALARM',
        originalEndLine: 'END:VALARM',
      ),
    );

    expect(alarm.repeatCount, 2);
    expect(alarm.repeatInterval, const Duration(minutes: 5));
  });

  test('all-day reminder offsets round-trip through day and time fields', () {
    const samples = [
      Duration(hours: 9),
      Duration(hours: -15),
      Duration(hours: -39),
      Duration(hours: -159),
      Duration(days: -1),
      Duration.zero,
    ];

    for (final sample in samples) {
      final fields = IcalAllDayAlarmOffset.fromDuration(sample);
      expect(fields.toDuration(), sample, reason: '$sample');
    }

    final week = IcalAllDayAlarmOffset.fromDuration(
      const Duration(hours: -159),
    );
    expect(week.amount, 1);
    expect(week.unit, IcalAllDayAlarmUnit.weeks);
    expect(week.hour, 9);
    expect(week.minute, 0);
  });
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
);

import 'package:busymax/src/features/recurrence/domain/recurrence_rule.dart';
import 'package:busymax/src/app/app_bootstrap.dart';
import 'package:busymax/src/dav/ical/ical_recurrence.dart';
import 'package:busymax/src/dav/ical/ical_semantics.dart';
import 'package:busymax/src/features/recurrence/presentation/recurrence_editor.dart';
import 'package:busymax/src/features/tasks/data/tasks_repository.dart';
import 'package:busymax/src/features/tasks/domain/task_capabilities.dart';
import 'package:busymax/src/features/tasks/presentation/ical_task_fields_editor.dart';
import 'package:busymax/src/features/tasks/presentation/task_details_draft.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../test_localized_app.dart';

void main() {
  testWidgets('a late recurrence picker Save cannot mutate a busy task draft', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    const task = TaskEntity(
      accountId: 'nextcloud:test',
      taskListId: 'list',
      id: 'task',
      title: 'Task',
      davCollectionId: 'collection',
      microsoftDueDateTime: '2026-08-08T09:00:00',
      microsoftDueTimeZone: 'UTC',
      recurrenceJson: '{"rules":["FREQ=DAILY;UNTIL=20260810T090000Z"],"dates":[],"excludedDates":[]}',
      localDirty: false,
      pendingDelete: false,
      pendingMove: false,
      rawJson: '{}',
      updatedLocalAtUtc: '',
    );
    var enabled = true;
    late StateSetter updateHost;
    TaskDetailsDraft? changed;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [localTimeZoneProvider.overrideWithValue('UTC')],
        child: localizedTestApp(
          child: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                updateHost = setState;
                return SingleChildScrollView(
                  child: IcalTaskFieldsEditor(
                    draft: TaskDetailsDraft.fromTask(task, 'UTC'),
                    capabilities: nextcloudTaskCollectionCapabilities,
                    enabled: enabled,
                    onChanged: (value) => changed = value,
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
    final recurrence = find.byKey(const ValueKey('ical-task-recurrence'));
    await tester.ensureVisible(recurrence);
    await tester.tap(recurrence);
    await tester.pumpAndSettle();
    final dateField = find.byWidgetPredicate(
      (widget) =>
          widget is TextField && widget.decoration?.labelText == 'On date',
    );
    await tester.ensureVisible(dateField);
    await tester.tap(dateField);
    await tester.pumpAndSettle();
    await tester.tap(find.text('12'));
    await tester.pumpAndSettle();
    updateHost(() => enabled = false);
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(changed, isNull);
    expect(find.byType(RecurrenceEditorDialog), findsNothing);
  });

  for (final reference in [
    (
      due: '2026-08-08T09:00:00',
      start: '2026-08-07T08:00:00',
      zone: 'UTC',
      allDay: false,
      floating: false,
      until: '20260812T090000Z',
    ),
    (
      due: '2026-08-08T09:00:00',
      start: null,
      zone: null,
      allDay: false,
      floating: true,
      until: '20260812T090000',
    ),
    (
      due: null,
      start: '2026-08-08T09:30:00',
      zone: 'America/Vancouver',
      allDay: false,
      floating: false,
      until: '20260812T163000Z',
    ),
    (
      due: '2026-08-08',
      start: null,
      zone: null,
      allDay: true,
      floating: false,
      until: '20260812',
    ),
  ]) {
    testWidgets(
      'task recurrence deadline keeps full reference ${reference.until}',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(1000, 1000));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final task = TaskEntity(
          accountId: 'nextcloud:test',
          taskListId: 'list',
          id: 'task',
          title: 'Task',
          davCollectionId: 'collection',
          icalUid: 'task',
          microsoftDueDateTime: reference.due,
          dueUtc: reference.due ?? reference.start,
          microsoftDueTimeZone: reference.zone,
          microsoftStartDateTime: reference.start,
          microsoftStartTimeZone: reference.zone,
          recurrenceJson:
              '{"rules":["FREQ=DAILY;UNTIL=${reference.allDay
                  ? '20260810'
                  : reference.floating
                  ? '20260810T090000'
                  : '20260810T090000Z'}"],"dates":[],"excludedDates":[]}',
          localDirty: false,
          pendingDelete: false,
          pendingMove: false,
          rawJson: '{}',
          updatedLocalAtUtc: '',
        );
        TaskDetailsDraft? changed;
        await tester.pumpWidget(
          ProviderScope(
            overrides: [localTimeZoneProvider.overrideWithValue('UTC')],
            child: localizedTestApp(
              child: Scaffold(
                body: SingleChildScrollView(
                  child: IcalTaskFieldsEditor(
                    draft: TaskDetailsDraft.fromTask(task, 'UTC'),
                    capabilities: nextcloudTaskCollectionCapabilities,
                    enabled: true,
                    onChanged: (value) => changed = value,
                  ),
                ),
              ),
            ),
          ),
        );
        final recurrence = find.byKey(const ValueKey('ical-task-recurrence'));
        await tester.ensureVisible(recurrence);
        await tester.tap(recurrence);
        await tester.pumpAndSettle();
        final dialog = tester.widget<RecurrenceEditorDialog>(
          find.byType(RecurrenceEditorDialog),
        );
        expect(dialog.baseDate.hour, reference.allDay ? 0 : 9);
        expect(
          dialog.baseDate.minute,
          reference.start == '2026-08-08T09:30:00' ? 30 : 0,
        );
        expect(dialog.baseDate.day, 8);
        expect(dialog.allDay, reference.allDay);
        expect(dialog.floating, reference.floating);
        expect(dialog.timeZone, reference.zone);
        final dateField = find.byWidgetPredicate(
          (widget) =>
              widget is TextField && widget.decoration?.labelText == 'On date',
        );
        await tester.ensureVisible(dateField);
        await tester.tap(dateField);
        await tester.pumpAndSettle();
        await tester.tap(find.text('12'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Save'));
        await tester.pumpAndSettle();
        final saved = RecurrenceRule.fromJson(changed?.recurrenceJson);
        expect(saved.untilRaw, reference.until);
        if (reference.until == '20260812T090000Z') {
          final resource = [
            'BEGIN:VCALENDAR',
            'VERSION:2.0',
            'BEGIN:VTODO',
            'UID:task',
            'DTSTAMP:20260808T000000Z',
            'DTSTART:20260808T090000Z',
            'RRULE:${saved.toRrule()}',
            'END:VTODO',
            'END:VCALENDAR',
            '',
          ].join('\r\n');
          final occurrences = IcalRecurrenceExpander().expand(
            IcalSemanticDocument.parse(resource),
            rangeStartUtc: DateTime.utc(2026, 8, 8),
            rangeEndUtc: DateTime.utc(2026, 8, 13),
          );
          expect(
            occurrences.map((occurrence) => occurrence.recurrenceId.rawValue),
            [
              for (var day = 8; day <= 12; day += 1)
                '202608${day.toString().padLeft(2, '0')}T090000Z',
            ],
          );
        }
      },
    );
  }
}

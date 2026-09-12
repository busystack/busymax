import 'package:busymax/src/features/tasks/data/tasks_repository.dart';
import 'package:busymax/src/features/tasks/presentation/task_details_draft.dart';
import 'package:busymax/src/features/tasks/domain/task_capabilities.dart';
import 'package:busymax/src/features/maps/domain/geographic_point.dart';
import 'package:busymax/src/features/maps/domain/location_result.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('named provider wall fields stay together outside the host zone', () {
    final task = _microsoftTask(
      due: '2026-06-06T14:30:00',
      dueZone: 'America/Vancouver',
      start: '2026-06-04T07:00:00',
      startZone: 'Pacific Standard Time',
      reminder: '2026-06-05T09:15:00',
      reminderZone: 'America/Vancouver',
    );

    final draft = TaskDetailsDraft.fromTask(task, 'Asia/Kathmandu');

    expect(draft.dueDate, '2026-06-06');
    expect(draft.microsoftDueTime, '14:30');
    expect(draft.microsoftDueTimeZone, 'America/Vancouver');
    expect(draft.microsoftStartDate, '2026-06-04');
    expect(draft.microsoftStartTime, '07:00');
    expect(draft.microsoftStartTimeZone, 'Pacific Standard Time');
    expect(draft.microsoftReminderDate, '2026-06-05');
    expect(draft.microsoftReminderTime, '09:15');
    expect(draft.microsoftReminderTimeZone, 'America/Vancouver');
    expect(
      draft.toPatch(
        task,
        microsoftTaskCollectionCapabilities,
        localTimeZone: 'Asia/Kathmandu',
      ),
      isEmpty,
    );
  });

  test('UTC and offset values convert into the supplied editor zone', () {
    final utcTask = _microsoftTask(
      due: '2026-06-08T20:45:00',
      dueZone: 'UTC',
      start: '2026-06-08T23:30:00-07:00',
      startZone: 'Pacific Standard Time',
      reminder: '2026-06-08T18:15:00Z',
      reminderZone: 'UTC',
    );

    final kathmandu = TaskDetailsDraft.fromTask(utcTask, 'Asia/Kathmandu');

    expect(kathmandu.dueDate, '2026-06-09');
    expect(kathmandu.microsoftDueTime, '02:30');
    expect(kathmandu.microsoftDueTimeZone, 'Asia/Kathmandu');
    expect(kathmandu.microsoftStartDate, '2026-06-09');
    expect(kathmandu.microsoftStartTime, '12:15');
    expect(kathmandu.microsoftStartTimeZone, 'Asia/Kathmandu');
    expect(kathmandu.microsoftReminderDate, '2026-06-09');
    expect(kathmandu.microsoftReminderTime, '00:00');
    expect(kathmandu.microsoftReminderTimeZone, 'Asia/Kathmandu');
    expect(
      kathmandu.toPatch(
        utcTask,
        microsoftTaskCollectionCapabilities,
        localTimeZone: 'Asia/Kathmandu',
      ),
      isEmpty,
    );
  });

  test('date and timezone edits serialize the coherent editor value', () {
    final task = _microsoftTask(
      due: '2026-06-06T14:30:00',
      dueZone: 'America/Vancouver',
      start: '2026-06-04T07:00:00',
      startZone: 'America/Vancouver',
    );
    final initial = TaskDetailsDraft.fromTask(task, 'UTC');

    expect(
      initial
          .copyWith(title: 'Renamed')
          .toPatch(
            task,
            microsoftTaskCollectionCapabilities,
            localTimeZone: 'UTC',
          ),
      {'title': 'Renamed'},
    );

    final changedDate = initial.copyWith(dueDate: '2026-06-07');
    expect(
      changedDate.toPatch(
        task,
        microsoftTaskCollectionCapabilities,
        localTimeZone: 'UTC',
      )['microsoftDueDateTime'],
      {'dateTime': '2026-06-07T14:30:00', 'timeZone': 'America/Vancouver'},
    );

    final changedZone = initial.copyWith(
      microsoftStartTimeZone: 'America/Toronto',
    );
    expect(
      changedZone.toPatch(
        task,
        microsoftTaskCollectionCapabilities,
        localTimeZone: 'UTC',
      ),
      containsPair('microsoftStartTimeZone', 'America/Toronto'),
    );
  });

  test('timed due date comes from the same converted instant as its clock', () {
    final task = _microsoftTask(
      due: '2026-06-08T01:30:00Z',
      dueZone: 'UTC',
      start: '2026-06-07T23:00:00Z',
      startZone: 'UTC',
      dueUtc: '2026-06-08',
    );

    final draft = TaskDetailsDraft.fromTask(task, 'America/Vancouver');

    expect(draft.dueDate, '2026-06-07');
    expect(draft.microsoftDueTime, '18:30');
    expect(draft.microsoftDueTimeZone, 'America/Vancouver');
    expect(
      draft.toPatch(
        task,
        microsoftTaskCollectionCapabilities,
        localTimeZone: 'America/Vancouver',
      ),
      isEmpty,
    );
  });

  test('date-only due values stay date-only', () {
    final task = _microsoftTask(
      due: '2026-06-08',
      dueZone: 'Pacific Standard Time',
      start: '2026-06-08',
      startZone: 'Pacific Standard Time',
    );

    final draft = TaskDetailsDraft.fromTask(task, 'Asia/Kathmandu');

    expect(draft.dueDate, '2026-06-08');
    expect(draft.microsoftDueTime, isNull);
    expect(draft.microsoftStartDate, '2026-06-08');
    expect(draft.microsoftStartTime, isNull);
    expect(
      draft.toPatch(
        task,
        microsoftTaskCollectionCapabilities,
        localTimeZone: 'Asia/Kathmandu',
      ),
      isEmpty,
    );
  });

  test('provider wall fields survive a daylight-saving gap unchanged', () {
    final task = _microsoftTask(
      due: '2026-03-08T02:30:00',
      dueZone: 'America/Vancouver',
      start: '2026-03-08T01:30:00',
      startZone: 'America/Vancouver',
    );

    final draft = TaskDetailsDraft.fromTask(task, 'Asia/Tokyo');

    expect(draft.dueDate, '2026-03-08');
    expect(draft.microsoftDueTime, '02:30');
    expect(draft.microsoftDueTimeZone, 'America/Vancouver');
    expect(
      draft.toPatch(
        task,
        microsoftTaskCollectionCapabilities,
        localTimeZone: 'Asia/Tokyo',
      ),
      isEmpty,
    );
  });

  test('Windows zones drive schedule validation and reminder references', () {
    final task = _microsoftTask(
      due: '2026-06-08T12:00:00',
      dueZone: 'Eastern Standard Time',
      start: '2026-06-08T10:00:00',
      startZone: 'Pacific Standard Time',
    );

    final draft = TaskDetailsDraft.fromTask(task, 'Asia/Kathmandu');

    expect(draft.scheduleIssue, TaskScheduleIssue.dueBeforeStart);
    expect(
      draft.reminderReferenceUtc(due: true, localTimeZone: 'Asia/Kathmandu'),
      DateTime.utc(2026, 6, 8, 16),
    );
    expect(
      draft.reminderReferenceUtc(due: false, localTimeZone: 'Asia/Kathmandu'),
      DateTime.utc(2026, 6, 8, 17),
    );
  });

  test('Microsoft UTC reminder opens as local time without dirty draft', () {
    final task = TaskEntity(
      accountId: 'account',
      taskListId: 'inbox',
      id: 'task-1',
      title: 'File report',
      status: 'needsAction',
      microsoftIsReminderOn: true,
      microsoftReminderDateTime: '2026-06-12T13:02:00',
      microsoftReminderTimeZone: 'UTC',
      localDirty: false,
      pendingDelete: false,
      pendingMove: false,
      rawJson: '{}',
      updatedLocalAtUtc: '2026-06-12T00:00:00.000Z',
    );
    final draft = TaskDetailsDraft.fromTask(task, 'America/Vancouver');

    expect(draft.microsoftReminderDate, '2026-06-12');
    expect(draft.microsoftReminderTime, '06:02');
    expect(draft.microsoftReminderTimeZone, 'America/Vancouver');
    expect(
      draft.toPatch(
        task,
        microsoftTaskCollectionCapabilities,
        localTimeZone: 'America/Vancouver',
      ),
      isEmpty,
    );
  });

  test('schedule reports a due date before the start date', () {
    final draft = TaskDetailsDraft.fromTask(
      _task(due: '2026-08-09', start: '2026-08-10'),
      'America/Vancouver',
    );

    expect(draft.scheduleIssue, TaskScheduleIssue.dueBeforeStart);
  });

  test('schedule accepts the same all-day start and due date', () {
    final draft = TaskDetailsDraft.fromTask(
      _task(due: '2026-08-10', start: '2026-08-10'),
      'America/Vancouver',
    );

    expect(draft.scheduleIssue, TaskScheduleIssue.none);
  });

  test('schedule reports mixed all-day and timed values', () {
    final draft = TaskDetailsDraft.fromTask(
      _task(due: '2026-08-10', start: '2026-08-10T09:00:00'),
      'America/Vancouver',
    );

    expect(draft.scheduleIssue, TaskScheduleIssue.mixedTimeModes);
  });

  test('opening a located task preserves its point without dirty state', () {
    final point = GeographicPoint(latitude: 0, longitude: -123);
    final task = _taskWithLocation('Hall', point);
    final draft = TaskDetailsDraft.fromTask(task, 'UTC');

    expect(draft.location, 'Hall');
    expect(draft.locationPoint, point);
    expect(draft.locationChange, const LocationChange.unchanged());
    expect(
      draft.toPatch(
        task,
        nextcloudTaskCollectionCapabilities,
        localTimeZone: 'UTC',
      ),
      isEmpty,
    );
  });

  test('same-label imported point remains a saved creation change', () {
    final task = _taskWithLocation(
      'Hall',
      GeographicPoint(latitude: 1, longitude: 2),
    );
    final selection = LocationResult(
      label: 'Hall',
      point: GeographicPoint(latitude: 3, longitude: 4),
    );
    final draft = TaskDetailsDraft.fromTask(
      task,
      'UTC',
    ).copyWith(locationChange: LocationChange.replace(selection));

    expect(draft.effectiveLocationPoint, selection.point);
    expect(
      draft.toPatch(
        task,
        nextcloudTaskCollectionCapabilities,
        localTimeZone: 'UTC',
      )['locationPoint'],
      selection.point.toJson(),
    );
    expect(
      draft
          .toCreateInput(
            nextcloudTaskCollectionCapabilities,
            localTimeZone: 'UTC',
          )
          .locationChange,
      LocationChange.replace(selection),
    );
  });

  test('unrelated copies preserve an explicit coordinate payload', () {
    final selection = LocationResult(
      label: 'Resolved address',
      point: GeographicPoint(latitude: 49.28, longitude: -123.12),
      source: 'ical',
    );
    final imported = TaskDetailsDraft.fromTask(
      _taskWithLocation('Head office', null),
      'UTC',
    ).copyWith(locationChange: LocationChange.replace(selection));

    final prepared = imported.copyWith(
      title: 'Prepared copy',
      taskListId: 'destination',
    );

    expect(prepared.location, 'Head office');
    expect(prepared.locationChange, LocationChange.replace(selection));
    expect(prepared.effectiveLocationPoint, selection.point);
  });

  test(
    'typing or clearing after selection explicitly invalidates its point',
    () {
      final selection = LocationResult(
        label: 'Hall',
        point: GeographicPoint(latitude: 3, longitude: 4),
      );
      final selected = TaskDetailsDraft.fromTask(
        _taskWithLocation('Hall', null),
        'UTC',
      ).copyWith(locationChange: LocationChange.replace(selection));

      final typed = selected.copyWith(location: 'Meeting room 3');
      expect(typed.location, 'Meeting room 3');
      expect(typed.locationChange, const LocationChange.clear());
      expect(typed.effectiveLocationPoint, isNull);

      final cleared = selected.copyWith(
        location: '',
        locationChange: const LocationChange.clear(),
      );
      expect(cleared.location, '');
      expect(cleared.effectiveLocationPoint, isNull);
    },
  );

  test(
    'restoring the original location restores coordinates and clean state',
    () {
      final point = GeographicPoint(latitude: 49.2827, longitude: -123.1207);
      final task = _taskWithLocation('Harbour Centre', point);
      final initial = TaskDetailsDraft.fromTask(task, 'UTC');

      final changed = initial.copyWith(location: 'Meeting room 3');
      final restored = changed.copyWith(location: 'Harbour Centre');

      expect(changed.locationChange, const LocationChange.clear());
      expect(changed.effectiveLocationPoint, isNull);
      expect(restored.locationChange, const LocationChange.unchanged());
      expect(restored.effectiveLocationPoint, point);
      expect(
        restored.toPatch(
          task,
          nextcloudTaskCollectionCapabilities,
          localTimeZone: 'UTC',
        ),
        isEmpty,
      );
    },
  );
}

TaskEntity _taskWithLocation(String location, GeographicPoint? point) =>
    TaskEntity(
      accountId: 'account',
      taskListId: 'inbox',
      id: 'task-location',
      title: 'Task',
      status: 'needsAction',
      taskLocation: location,
      locationPoint: point,
      localDirty: false,
      pendingDelete: false,
      pendingMove: false,
      rawJson: '{}',
      updatedLocalAtUtc: '2026-08-09T00:00:00.000Z',
    );

TaskEntity _task({required String due, required String start}) {
  return TaskEntity(
    accountId: 'account',
    taskListId: 'inbox',
    id: 'task-1',
    title: 'Task',
    status: 'needsAction',
    dueUtc: due.substring(0, 10),
    microsoftDueDateTime: due,
    microsoftDueTimeZone: 'America/Vancouver',
    microsoftStartDateTime: start,
    microsoftStartTimeZone: 'America/Vancouver',
    localDirty: false,
    pendingDelete: false,
    pendingMove: false,
    rawJson: '{}',
    updatedLocalAtUtc: '2026-08-09T00:00:00.000Z',
  );
}

TaskEntity _microsoftTask({
  required String due,
  required String dueZone,
  required String start,
  required String startZone,
  String? reminder,
  String? reminderZone,
  String? dueUtc,
}) => TaskEntity(
  accountId: 'microsoft:account',
  taskListId: 'inbox',
  id: 'task-time',
  title: 'Task',
  status: 'needsAction',
  dueUtc: dueUtc ?? due.substring(0, 10),
  microsoftDueDateTime: due,
  microsoftDueTimeZone: dueZone,
  microsoftStartDateTime: start,
  microsoftStartTimeZone: startZone,
  microsoftIsReminderOn: reminder != null,
  microsoftReminderDateTime: reminder,
  microsoftReminderTimeZone: reminderZone,
  localDirty: false,
  pendingDelete: false,
  pendingMove: false,
  rawJson: '{}',
  updatedLocalAtUtc: '2026-06-01T00:00:00.000Z',
);

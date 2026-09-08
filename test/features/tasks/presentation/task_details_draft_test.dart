import 'package:busymax/src/features/tasks/data/tasks_repository.dart';
import 'package:busymax/src/features/tasks/presentation/task_details_draft.dart';
import 'package:busymax/src/features/tasks/domain/task_capabilities.dart';
import 'package:busymax/src/features/maps/domain/geographic_point.dart';
import 'package:busymax/src/features/maps/domain/location_result.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
    final localReminder = DateTime.utc(2026, 6, 12, 13, 2).toLocal();

    final draft = TaskDetailsDraft.fromTask(task, 'America/Vancouver');

    expect(draft.microsoftReminderDate, _dateOnly(localReminder));
    expect(draft.microsoftReminderTime, _timeOnly(localReminder));
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

  test('same-label pin replacement remains a saved creation change', () {
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

String _dateOnly(DateTime value) {
  return '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
}

String _timeOnly(DateTime value) {
  return '${value.hour.toString().padLeft(2, '0')}:'
      '${value.minute.toString().padLeft(2, '0')}';
}

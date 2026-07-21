import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_bootstrap.dart';
import '../../../platform/main_window_command_client.dart';
import '../../../schedule/schedule_item.dart';
import '../../calendar/data/calendar_repository.dart';
import '../../calendar/presentation/event_editor_draft.dart';
import '../../tasks/data/tasks_repository.dart';
import 'compact_agenda_data.dart';

final compactAgendaControllerProvider = Provider<CompactAgendaController>((
  ref,
) {
  return CompactAgendaController(ref);
});

class CompactAgendaController {
  const CompactAgendaController(this._ref);

  final Ref _ref;

  Future<void> createTask({
    required String accountId,
    required String taskListId,
    required TaskCreateInput input,
  }) async {
    final repository = TasksRepository(
      database: _ref.read(databaseProvider),
      accountId: accountId,
    );
    await repository.createTask(taskListId, input);

    await _requestTaskSync(accountId);

    _ref.invalidate(compactAgendaDataProvider);
    _ref.invalidate(compactAgendaDataForQueryProvider);
  }

  Future<void> saveEvent(EventEditorDraft draft) async {
    final repository = CalendarRepository(
      database: _ref.read(databaseProvider),
      localTimeZone: _ref.read(localTimeZoneProvider),
    );
    await repository.updateLocalEvent(draft);
    await _requestCalendarSync(draft.accountId);

    _ref.invalidate(compactAgendaDataProvider);
    _ref.invalidate(compactAgendaDataForQueryProvider);
  }

  Future<void> deleteEvent(String eventId) async {
    final repository = CalendarRepository(
      database: _ref.read(databaseProvider),
      localTimeZone: _ref.read(localTimeZoneProvider),
    );
    final accountId = await repository.deleteLocalEvent(eventId);
    await _requestCalendarSync(accountId);

    _ref.invalidate(compactAgendaDataProvider);
    _ref.invalidate(compactAgendaDataForQueryProvider);
  }

  Future<void> deleteTask(TaskScheduleItem item) async {
    final repository = TasksRepository(
      database: _ref.read(databaseProvider),
      accountId: item.accountId,
    );
    await repository.deleteTask(item.sourceId, item.id);
    await _requestTaskSync(item.accountId);

    _ref.invalidate(compactAgendaDataProvider);
    _ref.invalidate(compactAgendaDataForQueryProvider);
  }

  Future<void> taskMutated(String accountId) async {
    await _requestTaskSync(accountId);
    _ref.invalidate(compactAgendaDataProvider);
    _ref.invalidate(compactAgendaDataForQueryProvider);
  }

  Future<void> setTaskCompleted(TaskScheduleItem item, bool completed) async {
    final fields = <String, Object?>{
      'status': completed ? 'completed' : 'needsAction',
      'completed': completed ? DateTime.now().toUtc().toIso8601String() : null,
    };

    final repository = TasksRepository(
      database: _ref.read(databaseProvider),
      accountId: item.accountId,
    );
    await repository.patchTask(item.sourceId, item.id, TaskPatchInput(fields));

    await _requestTaskSync(item.accountId);

    _ref.invalidate(compactAgendaDataProvider);
    _ref.invalidate(compactAgendaDataForQueryProvider);
  }

  Future<void> _requestTaskSync(String accountId) async {
    try {
      await const MainWindowCommandClient().requestTaskSync(accountId);
    } on Object {
      // The pending operation remains queued and will sync when the main engine
      // is available.
    }
  }

  Future<void> _requestCalendarSync(String accountId) async {
    try {
      await const MainWindowCommandClient().requestCalendarSync(accountId);
    } on Object {
      // The pending operation remains queued and will sync when the main engine
      // is available.
    }
  }
}

String compactAgendaTaskMutationKey(TaskScheduleItem item) {
  return '${item.accountId}:${item.sourceId}:${item.id}';
}

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_bootstrap.dart';
import '../../../platform/main_window_command_client.dart';
import '../../../schedule/schedule_item.dart';
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

  Future<void> setTaskCompleted(
    TaskScheduleItem item,
    bool completed,
  ) async {
    final fields = <String, Object?>{
      'status': completed ? 'completed' : 'needsAction',
      'completed': completed ? DateTime.now().toUtc().toIso8601String() : null,
    };

    final repository = TasksRepository(
      database: _ref.read(databaseProvider),
      accountId: item.accountId,
    );
    await repository.patchTask(item.sourceId, item.id, TaskPatchInput(fields));

    try {
      await const MainWindowCommandClient().requestTaskSync(item.accountId);
    } on Object {
      // The pending operation remains queued and will sync when the main engine
      // is available.
    }

    _ref.invalidate(compactAgendaDataProvider);
  }
}

String compactAgendaTaskMutationKey(TaskScheduleItem item) {
  return '${item.accountId}:${item.sourceId}:${item.id}';
}

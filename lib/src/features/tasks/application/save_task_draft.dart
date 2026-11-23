import '../../maps/domain/location_result.dart';
import '../data/tasks_repository.dart';

const _completionFields = {
  'status',
  'completed',
  'taskStatus',
  'percentComplete',
  'completedAtUtc',
};

TaskPatchInput taskDraftPatch(
  Map<String, Object?> fields, {
  required TaskEntity? observedTask,
  LocationChange locationChange = const LocationChange.unchanged(),
  bool? completionIntent,
}) => TaskPatchInput(
  fields,
  locationChange: locationChange,
  observedTask: observedTask,
  completionIntent: completionIntent,
  observedOccurrenceKey:
      completionIntent != null || fields.keys.any(_completionFields.contains)
      ? observedTask?.occurrenceKey
      : null,
);

/// Keeps a successful patch when a subsequent move cannot be committed.
Future<void> saveTaskDraftChanges({
  required TasksRepository repository,
  required String sourceListId,
  required String taskId,
  required String destinationListId,
  required TaskPatchInput patch,
}) async {
  final hasPatch = patch.fields.isNotEmpty || patch.locationChange.changed;
  if (hasPatch) await repository.patchTask(sourceListId, taskId, patch);
  if (sourceListId == destinationListId) return;

  try {
    await repository.moveTask(
      TaskMoveInput(
        sourceTaskListId: sourceListId,
        taskId: taskId,
        destinationTaskListId: destinationListId,
      ),
    );
  } on Object catch (error) {
    if (hasPatch) {
      final committed = await repository.readTask(sourceListId, taskId);
      if (committed != null) throw TaskSavePartialException(committed, error);
    }
    rethrow;
  }
}

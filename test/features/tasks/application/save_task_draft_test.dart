import 'package:busymax/src/features/tasks/application/save_task_draft.dart';
import 'package:busymax/src/features/tasks/data/tasks_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _Repository extends Mock implements TasksRepository {}

void main() {
  test('a committed patch survives a rejected move', () async {
    final repository = _Repository();
    final moveFailure = StateError('destination missing');
    const committed = TaskEntity(
      accountId: 'account',
      taskListId: 'source',
      id: 'task',
      title: 'Edited title',
      localDirty: true,
      pendingDelete: false,
      pendingMove: false,
      rawJson: '{}',
      updatedLocalAtUtc: '2026-11-17T00:00:00Z',
    );
    final patch = taskDraftPatch({
      'title': committed.title,
    }, observedTask: null);
    registerFallbackValue(
      const TaskMoveInput(sourceTaskListId: 'source', taskId: 'fallback'),
    );
    when(() => repository.patchTask('source', 'task', patch))
        .thenAnswer((_) async {});
    when(() => repository.moveTask(any())).thenThrow(moveFailure);
    when(() => repository.readTask('source', 'task'))
        .thenAnswer((_) async => committed);

    await expectLater(
      saveTaskDraftChanges(
        repository: repository,
        sourceListId: 'source',
        taskId: 'task',
        destinationListId: 'target',
        patch: patch,
      ),
      throwsA(
        isA<TaskSavePartialException>()
            .having(
              (error) => error.committedTask,
              'committed task',
              same(committed),
            )
            .having((error) => error.cause, 'move failure', same(moveFailure)),
      ),
    );
    verify(() => repository.patchTask('source', 'task', patch)).called(1);
  });
}

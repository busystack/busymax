import 'package:busymax/src/db/app_database.dart';
import 'package:busymax/src/schedule/schedule_agenda_query.dart';
import 'package:busymax/src/schedule/schedule_filters.dart';
import 'package:busymax/src/schedule/schedule_item.dart';
import 'package:busymax/src/schedule/schedule_range.dart';
import 'package:busymax/src/schedule/schedule_repository.dart';
import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/schedule_parity_fixture.dart';

void main() {
  test(
    'Agenda pages old overdue and undated tasks independently of future days',
    () async {
      final db = AppDatabase.memoryForTests();
      addTearDown(db.close);
      await seedScheduleParityFixture(db);
      final today = DateTime.now();
      for (var i = 0; i < 12; i++) {
        for (final dated in [true, false]) {
          await db.tasksDao.upsertTask(
            TasksCompanion.insert(
              accountId: 'google:populated',
              taskListId: 'visible-list',
              id: '${dated ? 'overdue' : 'undated'}-$i',
              title: '${dated ? 'overdue' : 'undated'} $i',
              dueUtc: Value(dated ? '2001-01-01' : null),
              status: const Value('needsAction'),
              rawJson: '{}',
              createdLocalAtUtc: '2026-01-01T00:00:00Z',
              updatedLocalAtUtc: '2026-01-01T00:00:00Z',
            ),
          );
        }
      }
      final repo = ScheduleRepository(db);
      Future<ScheduleAgendaPage> page(int limit, int days) =>
          queryScheduleAgenda(
            repo,
            range: ScheduleRange.days(today, count: days),
            sourceIds: {'calendar'},
            taskListKeys: {
              const ScheduleTaskListKey(
                accountId: 'google:populated',
                taskListId: 'visible-list',
              ),
            },
            overdueLimit: limit,
            noDateLimit: limit,
          );
      final first = await page(8, 30);
      expect(first.hasMoreOverdueTasks, isTrue);
      expect(first.hasMoreNoDateTasks, isTrue);
      expect(
        first.items.whereType<TaskScheduleItem>().where(
          (t) => t.id.startsWith('overdue-'),
        ),
        hasLength(8),
      );
      expect(
        first.items.whereType<TaskScheduleItem>().where(
          (t) => t.id.startsWith('undated-'),
        ),
        hasLength(8),
      );
      final second = await page(16, 60);
      expect(second.hasMoreOverdueTasks, isFalse);
      expect(second.hasMoreNoDateTasks, isFalse);
      expect(
        second.items.whereType<TaskScheduleItem>().where(
          (t) => t.id.startsWith('overdue-'),
        ),
        hasLength(12),
      );
      expect(
        second.items.whereType<TaskScheduleItem>().where(
          (t) => t.id.startsWith('undated-'),
        ),
        hasLength(12),
      );
      expect(
        second.items.where(
          (i) => i.id == 'hidden-task' || i.id == 'hidden-event',
        ),
        isEmpty,
      );
    },
  );
}

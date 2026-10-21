import 'dart:io';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:busymax/src/microsoft_todo/api/microsoft_todo_api_client.dart';
import 'package:busymax/src/microsoft_todo/api/microsoft_todo_task_remote_client.dart';
import 'package:busymax/src/features/tasks/data/tasks_repository.dart';

import 'package:busymax/src/db/app_database.dart';
import 'package:busymax/src/features/task_lists/data/task_lists_repository.dart';
import 'package:busymax/src/schedule/schedule_filters.dart';
import 'package:busymax/src/schedule/schedule_item.dart';
import 'package:busymax/src/schedule/schedule_projection.dart';
import 'package:busymax/src/schedule/schedule_range.dart';
import 'package:busymax/src/schedule/schedule_repository.dart';
import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/process_time_zone.dart';

void main() {
  group('native task schedule projection', () {
    late AppDatabase database;
    late ProcessTimeZone zone;
    setUp(() async {
      zone = ProcessTimeZone()..set('UTC');
      database = AppDatabase.memoryForTests();
      for (final account in ['a', 'b']) {
        await database
            .into(database.accounts)
            .insert(
              AccountsCompanion.insert(
                id: account,
                provider: 'microsoft',
                authority: 'https://login.microsoftonline.com/common',
                providerAccountId: account,
                credentialKind: 'oauth',
                authState: const Value('signed_in'),
                createdAtUtc: '',
                updatedAtUtc: '',
              ),
            );
        for (final list in ['one', 'two']) {
          await database.taskListsDao.upsertTaskList(
            TaskListsCompanion.insert(
              accountId: account,
              id: list,
              title: list,
              rawJson: '{}',
              createdLocalAtUtc: '',
              updatedLocalAtUtc: '',
            ),
          );
        }
      }
    });
    tearDown(() async {
      await database.close();
      zone.restore();
    });

    Future<void> task({
      String account = 'a',
      String list = 'one',
      String id = 'task',
      String? start,
      String? due,
      String? timeZone,
    }) async {
      final wire = {
        'id': id,
        'title': '$account/$list',
        'status': 'notStarted',
        if (start != null)
          'startDateTime': {'dateTime': start, 'timeZone': timeZone},
        if (due != null) 'dueDateTime': {'dateTime': due, 'timeZone': timeZone},
      };
      final adapter = MicrosoftTodoTaskRemoteClient(
        client: MicrosoftTodoRestApiClient(
          httpClient: MockClient(
            (request) async => http.Response(jsonEncode(wire), 200),
          ),
          baseUri: Uri.parse('https://graph.microsoft.com/v1.0'),
          authorizationHeaderProvider: () async => 'Bearer qa',
        ),
        defaultTimeZone: 'UTC',
      );
      final dto = await adapter.getTask(taskListId: list, taskId: id);
      await database.tasksDao.upsertTask(taskFromDto(account, list, dto, ''));
    }

    test('unfiltered All Tasks hides a pending-deleted populated list with account isolation', () async {
      await task();
      await task(list: 'two');
      await task(account: 'b');
      await TaskListsRepository(
        database: database,
        accountId: 'a',
      ).deleteTaskList('one');
      final items = await ScheduleRepository(database).listItems(
        range: ScheduleRange.day(DateTime(2026, 7, 1)),
        filters: const ScheduleFilters(showNoDateTasks: true),
      );
      expect(
        items.whereType<TaskScheduleItem>().map(
          (item) => '${item.accountId}/${item.sourceId}',
        ),
        unorderedEquals(['a/two', 'b/one']),
      );
      expect(await database.select(database.tasks).get(), hasLength(3));
      expect(
        (await database.select(database.pendingOps).getSingle()).operation,
        'delete_task_list',
      );
    });

    for (final dueOnly in [false, true]) {
      for (final example in [
        (
          '2026-07-01T09:00:00',
          'America/Vancouver',
          DateTime.utc(2026, 7, 1, 16),
        ),
        (
          '2026-07-01T09:00:00',
          'Pacific Standard Time',
          DateTime.utc(2026, 7, 1, 16),
        ),
        (
          '2026-07-01T09:00:00+02:00',
          'America/Vancouver',
          DateTime.utc(2026, 7, 1, 7),
        ),
        (
          '2026-07-01T23:00:00',
          'America/Vancouver',
          DateTime.utc(2026, 7, 2, 6),
        ),
        ('2026-07-01', 'America/Vancouver', DateTime.utc(2026, 7, 1)),
      ]) {
        test(
          'Microsoft ${dueOnly ? 'due fallback' : 'start'} resolves ${example.$1} ${example.$2}',
          () async {
            await task(
              start: dueOnly ? null : example.$1,
              due: dueOnly ? example.$1 : null,
              timeZone: example.$2,
            );
            final items = await ScheduleRepository(database)
                .listItems(range: ScheduleRange.day(example.$3.toLocal()));
            final item = items.single as TaskScheduleItem;
            expect(item.start?.toUtc(), example.$3);
            if (dueOnly) expect(item.due?.toUtc(), example.$3);
          },
        );
      }
    }

    for (final day in [
      DateTime(2026, 3, 8),
      DateTime(2026, 7, 1),
      DateTime(2026, 11, 1),
    ]) {
      test('loaded multi-day all-day tasks end at civil midnight on $day', () async {
        zone.set('America/Vancouver');
        final localDay = DateTime(day.year, day.month, day.day);
        final nextDay = DateTime(day.year, day.month, day.day + 1);
        final date =
            '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
        await task(due: date);
        final items = await ScheduleRepository(database).listItems(
          range: ScheduleRange(
            start: localDay,
            end: DateTime(day.year, day.month, day.day + 7),
          ),
        );
        expect(items.single.start, localDay);
        expect(items.single.end, nextDay);
        expect(ScheduleProjection.itemsForDay(items, localDay), hasLength(1));
        expect(ScheduleProjection.itemsForDay(items, nextDay), isEmpty);
      });
    }
  }, skip: !(Platform.isLinux || Platform.isMacOS));
}

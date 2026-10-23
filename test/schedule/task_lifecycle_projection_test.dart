import 'dart:convert';
import 'dart:io';

import 'package:busymax/src/dav/storage/dav_object_repository.dart';
import 'package:busymax/src/db/app_database.dart';
import 'package:busymax/src/features/schedule/presentation/schedule_agenda_view.dart';
import 'package:busymax/src/features/sync/pending_ops_replayer.dart';
import 'package:busymax/src/features/tasks/data/tasks_repository.dart';
import 'package:busymax/src/features/tasks/domain/task_remote_client.dart';
import 'package:busymax/src/features/tasks/domain/task_remote_models.dart';
import 'package:busymax/src/microsoft_todo/api/microsoft_todo_api_client.dart';
import 'package:busymax/src/microsoft_todo/api/microsoft_todo_task_remote_client.dart';
import 'package:busymax/src/providers/busy_provider.dart';
import 'package:busymax/src/schedule/schedule_filters.dart';
import 'package:busymax/src/schedule/schedule_item.dart';
import 'package:busymax/src/schedule/schedule_range.dart';
import 'package:busymax/src/schedule/schedule_repository.dart';
import 'package:busymax/src/schedule/schedule_search_match.dart';
import 'package:busymax/src/schedule/schedule_sorting.dart';
import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../support/persistence_test_directory.dart';
import '../support/process_time_zone.dart';
import '../test_localized_app.dart';

void main() {
  late AppDatabase database;
  ProcessTimeZone? zone;

  setUpAll(initializeDateFormatting);
  setUp(() async {
    if (Platform.isLinux || Platform.isMacOS) {
      zone = ProcessTimeZone()..set('UTC');
    }
    database = AppDatabase.memoryForTests();
    await _seedAccount(database, 'google', 'google');
    await _seedList(database, 'google', 'one');
  });
  tearDown(() async {
    await database.close();
    zone?.restore();
    zone = null;
  });

  for (final child in [false, true]) {
    testWidgets(
      'F17 rendered Move to top ${child ? 'promotes a child' : 'orders root siblings'} after acknowledgment and restart',
      (tester) async {
        _largeSurface(tester);
        final directory = (await tester.runAsync(
          () => createPersistenceTestDirectory('busymax-rendered-task-order-'),
        ))!;
        final file = File('${directory.path}/tasks.sqlite');
        final previousWarning =
            driftRuntimeOptions.dontWarnAboutMultipleDatabases;
        driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
        var disk = AppDatabase(NativeDatabase(file));
        final remote = _OrderingRemote();
        try {
          await tester.runAsync(() async {
            await _seedAccount(disk, 'google', 'google');
            await _seedList(disk, 'google', 'one');
            for (final task in [
              _googleTask('alpha', 'Alpha', '0001'),
              _googleTask(
                'zulu',
                'Zulu',
                '0002',
                parent: child ? 'parent' : null,
              ),
              if (child) _googleTask('parent', 'Parent', '0003'),
            ]) {
              remote.tasks[task.id] = task;
              await disk.tasksDao.upsertTask(
                taskFromDto('google', 'one', task, _now),
              );
            }
          });
          var items = (await tester.runAsync(
            () => ScheduleRepository(disk).listAllTasks(),
          ))!;
          await _pumpAgenda(tester, items, DateTime(2026, 7, 2));
          expect(
            tester.getTopLeft(find.text('Alpha')).dy,
            lessThan(tester.getTopLeft(find.text('Zulu')).dy),
          );
          await tester.runAsync(() async {
            await TasksRepository(database: disk, accountId: 'google').moveTask(
              const TaskMoveInput(sourceTaskListId: 'one', taskId: 'zulu'),
            );
            expect(
              await PendingOpsReplayer(
                database: disk,
                apiClient: remote,
                accountId: 'google',
                nowUtc: () => DateTime.utc(2026, 7, 2),
              ).replayDueOps(),
              1,
            );
          });
          expect(remote.moves, ['zulu:null:null']);
          expect(remote.tasks['zulu']!.parent, isNull);
          items = (await tester.runAsync(
            () => ScheduleRepository(disk).listAllTasks(),
          ))!;
          expect(
            items.map((task) => task.id),
            child ? ['zulu', 'alpha', 'parent'] : ['zulu', 'alpha'],
          );
          expect(items.first.hierarchyDepth, 0);
          await _pumpAgenda(tester, items, DateTime(2026, 7, 2));
          expect(
            tester.getTopLeft(find.text('Zulu')).dy,
            lessThan(tester.getTopLeft(find.text('Alpha')).dy),
          );
          await tester.runAsync(() async {
            await disk.close();
            disk = AppDatabase(NativeDatabase(file));
          });
          items = (await tester.runAsync(
            () => ScheduleRepository(disk).listAllTasks(),
          ))!;
          await _pumpAgenda(tester, items, DateTime(2026, 7, 2));
          expect(
            tester.getTopLeft(find.text('Zulu')).dy,
            lessThan(tester.getTopLeft(find.text('Alpha')).dy),
          );
          expect(
            await tester.runAsync(() => disk.select(disk.pendingOps).get()),
            isEmpty,
          );
        } finally {
          await tester.pumpWidget(const SizedBox());
          await tester.runAsync(() async {
            await disk.close();
            await directory.delete(recursive: true);
          });
          driftRuntimeOptions.dontWarnAboutMultipleDatabases = previousWarning;
        }
      },
    );
  }

  testWidgets(
    'F17 imported DAV numeric sibling order is rendered numerically',
    (tester) async {
      _largeSurface(tester);
      await tester.runAsync(() async {
        await _seedDav(database);
        await _importDav(database, [
          _davTask('parent', 'DAV parent', const ['X-APPLE-SORT-ORDER:1']),
          _davTask('ten', 'Alpha ten', const [
            'RELATED-TO:parent',
            'X-APPLE-SORT-ORDER:10',
          ]),
          _davTask('two', 'Zulu two', const [
            'RELATED-TO:parent',
            'X-APPLE-SORT-ORDER:2',
          ]),
        ]);
      });
      final items = (await tester.runAsync(
        () => ScheduleRepository(database).listAllTasks(),
      ))!;
      expect(items.map((task) => task.title), [
        'DAV parent',
        'Zulu two',
        'Alpha ten',
      ]);
      expect(items.map((task) => task.sortOrder), [1, 2, 10]);
      await _pumpAgenda(tester, items, DateTime(2026, 7, 2));
      expect(
        tester.getTopLeft(find.text('Zulu two')).dy,
        lessThan(tester.getTopLeft(find.text('Alpha ten')).dy),
      );
    },
  );

  test('F17 ordering remains transitive across account/list/parent scopes and calendar chronology', () async {
    await _seedList(database, 'google', 'two');
    await _seedAccount(database, 'other', 'google');
    await _seedList(database, 'other', 'one');
    for (final task in [
      _googleTask('a', 'Zulu', '0001'),
      _googleTask('b', 'Alpha', '0002'),
      _googleTask('child', 'Child', '0000', parent: 'a'),
    ]) {
      await database.tasksDao.upsertTask(
        taskFromDto('google', 'one', task, _now),
      );
    }
    await database.tasksDao.upsertTask(
      taskFromDto('google', 'two', _googleTask('c', 'Bravo', '0000'), _now),
    );
    await database.tasksDao.upsertTask(
      taskFromDto('other', 'one', _googleTask('d', 'Charlie', '0000'), _now),
    );
    final tasks = await ScheduleRepository(database).listAllTasks();
    expect(
      tasks.map((task) => '${task.accountId}/${task.sourceId}/${task.id}'),
      [
        'google/one/a',
        'google/one/child',
        'google/one/b',
        'google/two/c',
        'other/one/d',
      ],
    );
    for (final a in tasks) {
      for (final b in tasks) {
        expect(
          compareScheduleItems(a, b).sign,
          -compareScheduleItems(b, a).sign,
        );
        for (final c in tasks) {
          if (compareScheduleItems(a, b) <= 0 &&
              compareScheduleItems(b, c) <= 0) {
            expect(compareScheduleItems(a, c), lessThanOrEqualTo(0));
          }
        }
      }
    }
    final early = CalendarScheduleItem(
      id: 'early',
      accountId: 'other',
      provider: BusyProvider.google,
      sourceId: 'calendar',
      providerCalendarId: 'calendar',
      title: 'Zulu event',
      allDay: false,
      start: DateTime(2026, 7, 1, 9),
    );
    final late = CalendarScheduleItem(
      id: 'late',
      accountId: 'google',
      provider: BusyProvider.google,
      sourceId: 'calendar',
      providerCalendarId: 'calendar',
      title: 'Alpha event',
      allDay: false,
      start: DateTime(2026, 7, 1, 10),
    );
    expect(([late, early]..sort(compareScheduleItems)).map((item) => item.id), [
      'early',
      'late',
    ]);
  });

  testWidgets(
    'F18 overdue pagination, agenda and search use actual deadline and preserve start placement',
    (tester) async {
      _largeSurface(tester);
      await tester.runAsync(() async {
        await _seedAccount(database, 'microsoft', 'microsoft');
        await _seedList(database, 'microsoft', 'work');
        await _microsoftTask(
          database,
          'future',
          'Future deadline',
          start: '2026-07-01',
          due: '2026-07-09',
        );
        await _microsoftTask(
          database,
          'start-only',
          'Start only',
          start: '2026-07-01',
        );
        await _microsoftTask(
          database,
          'expired',
          'Expired deadline',
          start: '2026-07-01',
          due: '2026-07-01',
        );
        await _microsoftTask(
          database,
          'zone-expired',
          'Zoned expired',
          start: '2026-07-01',
          due: '2026-07-01T15:00:00',
          timeZone: 'America/Vancouver',
        );
        await _microsoftTask(
          database,
          'zone-boundary',
          'Zoned boundary',
          start: '2026-07-01',
          due: '2026-07-01T23:30:00',
          timeZone: 'America/Vancouver',
        );
      });
      final reference = DateTime(2026, 7, 2);
      final repository = ScheduleRepository(database);
      final all = (await tester.runAsync(repository.listAllTasks))!;
      expect(
        all.firstWhere((task) => task.id == 'zone-boundary').due!.toUtc(),
        DateTime.utc(2026, 7, 2, 6, 30),
      );
      final expectedOverdue = {
        'expired',
        if (DateTime.utc(2026, 7, 1, 22).toLocal().isBefore(reference))
          'zone-expired',
        if (DateTime.utc(2026, 7, 2, 6, 30).toLocal().isBefore(reference))
          'zone-boundary',
      };
      final firstPage = (await tester.runAsync(
        () => repository.listOverdueTasks(before: reference, limit: 1),
      ))!;
      expect(firstPage.items, hasLength(1));
      expect(firstPage.hasMore, expectedOverdue.length > 1);
      final complete = (await tester.runAsync(
        () => repository.listOverdueTasks(before: reference, limit: 20),
      ))!;
      expect(complete.items.map((task) => task.id).toSet(), expectedOverdue);
      expect(complete.hasMore, isFalse);
      final search = ScheduleFilters(
        ignoreDateRange: true,
        includeCalendarEvents: false,
        taskDueState: ScheduleTaskDueState.overdue,
        referenceDate: reference,
      );
      expect(
        all
            .where(
              (item) => matchesScheduleFilters(
                item,
                search,
                range: ScheduleRange.day(reference),
              ),
            )
            .map((item) => item.id)
            .toSet(),
        expectedOverdue,
      );
      await _pumpAgenda(tester, all, reference);
      expect(find.text('Expired deadline'), findsOneWidget);
      expect(find.text('Future deadline'), findsNothing);
      expect(find.text('Start only'), findsNothing);
      expect(find.text('Overdue'), findsOneWidget);
      for (final task in all) {
        expect(task.start, DateTime(2026, 7, 1));
      }
      await _pumpAgenda(tester, all, DateTime(2026, 7, 1));
      expect(find.text('Future deadline'), findsOneWidget);
      expect(find.text('Start only'), findsOneWidget);
      expect(find.text('Overdue'), findsNothing);
    },
  );

  testWidgets(
    'F19 imported and locally cancelled tasks remain explicit in All and reopen through the existing transition',
    (tester) async {
      _largeSurface(tester);
      late String importedId;
      await tester.runAsync(() async {
        await _seedDav(database);
        await _importDav(database, [
          _davTask('cancelled', 'Imported cancelled', const [
            'STATUS:CANCELLED',
            'PERCENT-COMPLETE:0',
            'DUE;VALUE=DATE:20260701',
          ]),
        ]);
        importedId = (await database.select(database.tasks).getSingle()).id;
        final tasks = TasksRepository(
          database: database,
          accountId: 'dav',
          nowUtc: () => DateTime.utc(2026, 7, 2),
        );
        final localId = await tasks.createTask(
          'dav-task-list-dav-collection',
          const TaskCreateInput(title: 'Local cancelled'),
        );
        await tasks.patchTask(
          'dav-task-list-dav-collection',
          localId,
          const TaskPatchInput({'taskStatus': 'CANCELLED'}),
        );
      });
      final repository = ScheduleRepository(database);
      var all = (await tester.runAsync(repository.listAllTasks))!;
      expect(all, hasLength(2));
      expect(
        all.every(
          (task) => task.cancelled && !task.completed && !task.actionable,
        ),
        isTrue,
      );
      expect(
        await tester.runAsync(
          () => repository.listAllTasks(
            filters: const ScheduleFilters(
              taskCompletion: ScheduleTaskCompletion.open,
              showNoDateTasks: true,
            ),
          ),
        ),
        isEmpty,
      );
      expect(
        await tester.runAsync(
          () => repository.listAllTasks(
            filters: const ScheduleFilters(
              taskCompletion: ScheduleTaskCompletion.completed,
              showNoDateTasks: true,
            ),
          ),
        ),
        isEmpty,
      );
      expect(
        (await tester.runAsync(
          () => repository.listOverdueTasks(
            before: DateTime(2026, 7, 2),
            limit: 1,
          ),
        ))!.items,
        isEmpty,
      );
      await _pumpAgenda(tester, all, DateTime(2026, 7, 1));
      expect(find.text('Imported cancelled'), findsOneWidget);
      expect(find.text('Local cancelled'), findsOneWidget);
      expect(find.textContaining('Cancelled'), findsNWidgets(2));
      await tester.runAsync(
        () =>
            TasksRepository(
              database: database,
              accountId: 'dav',
              nowUtc: () => DateTime.utc(2026, 7, 2),
            ).patchTask(
              'dav-task-list-dav-collection',
              importedId,
              TaskPatchInput.completion(false),
            ),
      );
      all = (await tester.runAsync(repository.listAllTasks))!;
      final reopened = all.singleWhere((task) => task.id == importedId);
      expect(reopened.actionable, isTrue);
      expect(reopened.cancelled, isFalse);
      final open = (await tester.runAsync(
        () => repository.listAllTasks(
          filters: const ScheduleFilters(
            taskCompletion: ScheduleTaskCompletion.open,
            showNoDateTasks: true,
          ),
        ),
      ))!;
      expect(open.map((task) => task.id), [importedId]);
      expect(
        (await tester.runAsync(
          () => repository.listOverdueTasks(
            before: DateTime(2026, 7, 2),
            limit: 1,
          ),
        ))!.items.single.id,
        importedId,
      );
      await _pumpAgenda(tester, all, DateTime(2026, 7, 1));
      expect(find.textContaining('Cancelled'), findsOneWidget);
    },
  );
}

const _now = '2026-07-01T00:00:00.000Z';

void _largeSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _pumpAgenda(
  WidgetTester tester,
  List<ScheduleItem> items,
  DateTime day,
) async {
  await tester.pumpWidget(
    localizedTestApp(
      child: Scaffold(
        body: ScheduleAgendaView(
          range: ScheduleRange.day(day),
          items: items,
          onItemSelected: (_, _, [_]) {},
          onTaskCompletionChanged: (_, _) {},
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _seedAccount(AppDatabase database, String id, String provider) =>
    database
        .into(database.accounts)
        .insert(
          AccountsCompanion.insert(
            id: id,
            provider: provider,
            authority: 'https://qa.example.test',
            providerAccountId: id,
            credentialKind: provider == 'nextcloud'
                ? 'nextcloud_app_password'
                : 'oauth',
            authState: const Value('signed_in'),
            createdAtUtc: _now,
            updatedAtUtc: _now,
          ),
        );

Future<void> _seedList(AppDatabase database, String account, String id) =>
    database.taskListsDao.upsertTaskList(
      TaskListsCompanion.insert(
        accountId: account,
        id: id,
        title: id,
        rawJson: '{}',
        createdLocalAtUtc: _now,
        updatedLocalAtUtc: _now,
      ),
    );

TaskDto _googleTask(
  String id,
  String title,
  String position, {
  String? parent,
}) => TaskDto.fromJson({
  'id': id,
  'title': title,
  'position': position,
  'status': 'needsAction',
  'updated': _now,
  if (parent != null) 'parent': parent,
});

class _OrderingRemote implements TaskRemoteClient {
  final tasks = <String, TaskDto>{};
  final moves = <String>[];
  @override
  Future<TaskDto> getTask({
    required String taskListId,
    required String taskId,
  }) async => tasks[taskId]!;
  @override
  Future<TaskDto> moveTask({
    required String sourceTaskListId,
    required String taskId,
    String? parentTaskId,
    String? previousSiblingTaskId,
    String? destinationTaskListId,
  }) async {
    moves.add('$taskId:$parentTaskId:$previousSiblingTaskId');
    final raw = {
      ...tasks[taskId]!.rawJson,
      'position': '0000',
      'updated': '2026-07-02T01:00:00.000Z',
    };
    if (parentTaskId == null) {
      raw.remove('parent');
    } else {
      raw['parent'] = parentTaskId;
    }
    return tasks[taskId] = TaskDto.fromJson(raw);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> _microsoftTask(
  AppDatabase database,
  String id,
  String title, {
  String? start,
  String? due,
  String timeZone = 'UTC',
}) async {
  final wire = {
    'id': id,
    'title': title,
    'status': 'notStarted',
    'lastModifiedDateTime': _now,
    if (start != null)
      'startDateTime': {'dateTime': start, 'timeZone': timeZone},
    if (due != null) 'dueDateTime': {'dateTime': due, 'timeZone': timeZone},
  };
  final adapter = MicrosoftTodoTaskRemoteClient(
    client: MicrosoftTodoRestApiClient(
      httpClient: MockClient((_) async => http.Response(jsonEncode(wire), 200)),
      authorizationHeaderProvider: () async => 'Bearer qa',
      baseUri: Uri.parse('https://graph.microsoft.com/v1.0'),
    ),
    defaultTimeZone: 'UTC',
  );
  final task = await adapter.getTask(taskListId: 'work', taskId: id);
  await database.tasksDao.upsertTask(
    taskFromDto('microsoft', 'work', task, _now),
  );
}

Future<void> _seedDav(AppDatabase database) async {
  await _seedAccount(database, 'dav', 'nextcloud');
  await database
      .into(database.davCollections)
      .insert(
        DavCollectionsCompanion.insert(
          id: 'dav-collection',
          accountId: 'dav',
          hrefKey: '/tasks/',
          requestUri: 'https://qa.example.test/tasks/',
          displayName: 'DAV Tasks',
          supportedComponentMask: const Value(2),
          currentUserPrivilegesJson: Value(
            jsonEncode(['{DAV:}read', '{DAV:}write']),
          ),
          readOnly: const Value(false),
          taskProjectionEnabled: const Value(true),
          tasksSelected: const Value(true),
          createdAtUtc: _now,
          updatedAtUtc: _now,
        ),
      );
  await database.taskListsDao.upsertTaskList(
    TaskListsCompanion.insert(
      accountId: 'dav',
      id: 'dav-task-list-dav-collection',
      title: 'DAV Tasks',
      davCollectionId: const Value('dav-collection'),
      rawJson: '{}',
      createdLocalAtUtc: _now,
      updatedLocalAtUtc: _now,
    ),
  );
}

DavPreparedObject _davTask(String uid, String title, List<String> fields) =>
    DavPreparedObject.parse(
      hrefKey: '/tasks/$uid.ics',
      requestUri: Uri.parse('https://qa.example.test/tasks/$uid.ics'),
      etag: '"qa-$uid"',
      contentType: 'text/calendar',
      rawIcsBody: [
        'BEGIN:VCALENDAR',
        'VERSION:2.0',
        'PRODID:-//BusyMax QA//EN',
        'BEGIN:VTODO',
        'UID:$uid',
        'SUMMARY:$title',
        'DTSTAMP:20260701T000000Z',
        ...fields,
        'END:VTODO',
        'END:VCALENDAR',
        '',
      ].join('\r\n'),
    );

Future<void> _importDav(
  AppDatabase database,
  List<DavPreparedObject> objects,
) async {
  await DavObjectRepository(database: database).commit(
    DavCollectionCommit(
      accountId: 'dav',
      collectionId: 'dav-collection',
      provider: BusyProvider.nextcloud,
      objects: objects,
      deletedHrefKeys: const {},
      completeMembership: true,
      membershipHrefKeys: {for (final object in objects) object.hrefKey},
      finalCursorKind: 'dav_sync_token',
      finalCursorValue: 'qa-token',
      baselineGeneration: 1,
      completedAtUtc: DateTime.utc(2026, 7, 1),
      projectionRangeStartUtc: DateTime.utc(2026),
      projectionRangeEndUtc: DateTime.utc(2027),
    ),
  );
}

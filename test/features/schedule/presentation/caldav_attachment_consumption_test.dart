import 'package:busymax/src/app/app_bootstrap.dart';
import 'package:busymax/src/dav/storage/dav_object_repository.dart';
import 'package:busymax/src/db/app_database.dart';
import 'package:busymax/src/features/schedule/presentation/schedule_item_details_popover.dart';
import 'package:busymax/src/features/task_lists/data/task_lists_repository.dart';
import 'package:busymax/src/features/tasks/data/tasks_repository.dart';
import 'package:busymax/src/features/tasks/domain/task_capabilities.dart';
import 'package:busymax/src/features/tasks/presentation/task_details_editor.dart';
import 'package:busymax/src/providers/busy_provider.dart';
import 'package:busymax/src/schedule/schedule_item.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../test_localized_app.dart';

void main() {
  testWidgets('CalDAV event exposes inline attachment content for saving', (
    tester,
  ) async {
    final db = await tester.runAsync(() => attachmentDatabase('VEVENT'));
    addTearDown(db!.close);
    final event = (await tester.runAsync(
      () => db.select(db.calendarEvents).getSingle(),
    ))!;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: localizedTestApp(
          child: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showScheduleItemDetailsPopover(
                  context: context,
                  anchorContext: context,
                  item: CalendarScheduleItem(
                    id: event.id,
                    accountId: 'account',
                    provider: BusyProvider.caldav,
                    sourceId: 'dav-calendar-collection',
                    providerCalendarId: '/calendar/',
                    providerEventId: event.providerEventId,
                    title: 'Attached event',
                    allDay: false,
                    attachmentsLoaded: true,
                  ),
                ),
                child: const Text('Details'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Details'));
    await tester.pumpAndSettle();
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();
    expect(find.text('Save inline.bin'), findsOneWidget);
    expect(find.text('application/octet-stream'), findsOneWidget);
  });

  testWidgets('CalDAV task editor exposes both HTTP and HTTPS attachments', (
    tester,
  ) async {
    final db = await tester.runAsync(() => attachmentDatabase('VTODO'));
    addTearDown(db!.close);
    final task = TaskEntity.fromRow(
      (await tester.runAsync(() => db.select(db.tasks).getSingle()))!,
    );
    tester.view.physicalSize = const Size(1100, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: localizedTestApp(
          child: Scaffold(
            body: TaskDetailsEditor(
              task: task,
              provider: BusyProvider.caldav,
              taskLists: const [
                TaskListEntity(
                  accountId: 'account',
                  id: 'dav-task-list-collection',
                  title: 'Tasks',
                  localDirty: false,
                  pendingDelete: false,
                  rawJson: '{}',
                ),
              ],
              capabilities: caldavTaskCollectionCapabilities,
              localTimeZone: 'UTC',
              accountLabel: 'Account',
              onRefresh: () {},
              onSave: (_, _) async {},
              onCreateSubtask: (_) async {},
              onMoveToTop: () {},
              onDelete: () async {},
              onCancel: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();
    expect(find.text('http.bin'), findsOneWidget);
    expect(find.text('https.bin'), findsOneWidget);
    expect(find.text('Save inline.bin'), findsOneWidget);
  });
}

Future<AppDatabase> attachmentDatabase(String kind) async {
  final db = AppDatabase.memoryForTests();
  const now = '2026-11-10T00:00:00.000Z';
  await db
      .into(db.accounts)
      .insert(
        AccountsCompanion.insert(
          id: 'account',
          provider: 'caldav',
          authority: 'https://dav.example.test/',
          providerAccountId: 'qa',
          credentialKind: 'caldav_password',
          authState: const Value('signed_in'),
          createdAtUtc: now,
          updatedAtUtc: now,
        ),
      );
  await db
      .into(db.davCollections)
      .insert(
        DavCollectionsCompanion.insert(
          id: 'collection',
          accountId: 'account',
          hrefKey: '/calendar/',
          requestUri: 'https://dav.example.test/calendar/',
          displayName: 'Attachments',
          supportedComponentMask: const Value(3),
          eventProjectionEnabled: const Value(true),
          taskProjectionEnabled: const Value(true),
          createdAtUtc: now,
          updatedAtUtc: now,
        ),
      );
  await db
      .into(db.calendarSources)
      .insert(
        CalendarSourcesCompanion.insert(
          id: 'dav-calendar-collection',
          accountId: 'account',
          provider: 'caldav',
          providerCalendarId: '/calendar/',
          davCollectionId: const Value('collection'),
          summary: 'Attachments',
          createdAtLocal: 0,
          updatedAtLocal: 0,
        ),
      );
  await db
      .into(db.taskLists)
      .insert(
        TaskListsCompanion.insert(
          accountId: 'account',
          id: 'dav-task-list-collection',
          title: 'Tasks',
          davCollectionId: const Value('collection'),
          rawJson: '{}',
          createdLocalAtUtc: now,
          updatedLocalAtUtc: now,
        ),
      );
  final raw =
      'BEGIN:VCALENDAR\r\nVERSION:2.0\r\nPRODID:-//Attachment test//EN\r\n'
      'BEGIN:$kind\r\nUID:attached\r\nDTSTAMP:20261110T000000Z\r\n'
      '${kind == 'VEVENT' ? 'DTSTART:20261110T090000\r\nDTEND:20261110T100000\r\n' : 'DURATION:PT1H\r\nSTATUS:PENDING\r\n'}'
      'SUMMARY:Attached object\r\n'
      'ATTACH;FMTTYPE=application/octet-stream;ENCODING=BASE64;VALUE=BINARY;FILENAME=inline.bin:AAECAw==\r\n'
      'ATTACH:http://files.example.test/http.bin\r\n'
      'ATTACH:https://files.example.test/https.bin\r\n'
      'X-OPAQUE;X-PARAM=one^nTwo:preserve café\r\nEND:$kind\r\nEND:VCALENDAR\r\n';
  final object = DavPreparedObject.parse(
    hrefKey: '/calendar/attached.ics',
    requestUri: Uri.parse('https://dav.example.test/calendar/attached.ics'),
    etag: '"one"',
    contentType: 'text/calendar',
    rawIcsBody: raw,
  );
  await DavObjectRepository(database: db).commit(
    DavCollectionCommit(
      accountId: 'account',
      collectionId: 'collection',
      provider: BusyProvider.caldav,
      objects: [object],
      deletedHrefKeys: const {},
      completeMembership: true,
      membershipHrefKeys: {object.hrefKey},
      finalCursorKind: 'dav_sync_token',
      finalCursorValue: 'one',
      baselineGeneration: 1,
      completedAtUtc: DateTime.utc(2026, 11, 10),
      projectionRangeStartUtc: DateTime.utc(2026),
      projectionRangeEndUtc: DateTime.utc(2027),
    ),
  );
  return db;
}

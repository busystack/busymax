import 'dart:async';

import 'package:busymax/l10n/generated/app_localizations.dart';
import 'package:busymax/src/android/presentation/android_tasks_screen.dart';
import 'package:busymax/src/app/app_bootstrap.dart';
import 'package:busymax/src/config/build_config.dart';
import 'package:busymax/src/dav/storage/dav_object_repository.dart';
import 'package:busymax/src/db/app_database.dart';
import 'package:busymax/src/features/tasks/data/tasks_repository.dart';
import 'package:busymax/src/features/tasks/domain/task_capabilities.dart';
import 'package:busymax/src/features/tasks/presentation/task_details_pane.dart';
import 'package:busymax/src/providers/busy_provider.dart';
import 'package:busymax/src/schedule/schedule_item.dart';
import 'package:busymax/src/ui/windows/windows_task_details_dialog.dart';
import 'package:drift/drift.dart' show Value;
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/contacts_fixture.dart';
import '../support/memory_settings_store.dart';
import '../test_localized_app.dart';
import 'contacts_settings_routes_test.dart' show settle, complete;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      const MethodChannel('yaru_window'),
      (_) async => <String, Object?>{},
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('yaru_window/events'),
      (_) async => null,
    );
  });
  for (final platform in ['Linux', 'Windows', 'Android']) {
    testWidgets(
      '$platform production task duplication requires a decision before queueing',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 2400);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final f = ContactsFixture(AppDatabase.memoryForTests());
        final db = f.database;
        const stamp = '2026-11-07T00:00:00Z';
        await db
            .into(db.accounts)
            .insert(
              AccountsCompanion.insert(
                id: 'qa',
                provider: 'caldav',
                authority: 'https://example.test/',
                providerAccountId: 'qa',
                credentialKind: 'caldav_password',
                authState: const Value('signed_in'),
                createdAtUtc: stamp,
                updatedAtUtc: stamp,
              ),
            );
        await db
            .into(db.davCollections)
            .insert(
              DavCollectionsCompanion.insert(
                id: 'collection',
                accountId: 'qa',
                hrefKey: '/calendars/tasks/',
                requestUri: 'https://example.test/calendars/tasks/',
                displayName: 'Tasks',
                supportedComponentMask: const Value(2),
                taskProjectionEnabled: const Value(true),
                readOnly: const Value(false),
                currentUserPrivilegesJson: const Value('["{DAV:}all"]'),
                createdAtUtc: stamp,
                updatedAtUtc: stamp,
              ),
            );
        await db
            .into(db.taskLists)
            .insert(
              TaskListsCompanion.insert(
                accountId: 'qa',
                id: 'dav-task-list-collection',
                davCollectionId: const Value('collection'),
                title: 'Tasks',
                rawJson: '{}',
                createdLocalAtUtc: stamp,
                updatedLocalAtUtc: stamp,
              ),
            );
        const raw =
            'BEGIN:VCALENDAR\r\nVERSION:2.0\r\nPRODID:-//BusyMax//QA//EN\r\nBEGIN:VTODO\r\nUID:consent@example.invalid\r\nSUMMARY:Attendee task\r\n'
            'ORGANIZER:mailto:organizer@example.invalid\r\nATTENDEE:mailto:recipient@example.invalid\r\nEND:VTODO\r\nEND:VCALENDAR\r\n';
        await DavObjectRepository(database: db).commit(
          DavCollectionCommit(
            accountId: 'qa',
            collectionId: 'collection',
            provider: BusyProvider.caldav,
            objects: [
              DavPreparedObject.parse(
                hrefKey: '/calendars/tasks/task.ics',
                requestUri: Uri.parse(
                  'https://example.test/calendars/tasks/task.ics',
                ),
                etag: '"one"',
                contentType: 'text/calendar',
                rawIcsBody: raw,
              ),
            ],
            deletedHrefKeys: const {},
            completeMembership: true,
            membershipHrefKeys: const {'/calendars/tasks/task.ics'},
            finalCursorKind: 'snapshot_generation',
            finalCursorValue: 'one',
            baselineGeneration: 1,
            projectionRangeStartUtc: DateTime.utc(2026),
            projectionRangeEndUtc: DateTime.utc(2027),
            completedAtUtc: DateTime.utc(2026, 11, 7),
          ),
        );
        final row = await db.select(db.tasks).getSingle();
        final task = TaskEntity.fromRow(row);
        final repository = TasksRepository(database: db, accountId: 'qa');
        final container = ProviderContainer(
          overrides: [
            databaseProvider.overrideWithValue(db),
            busyMaxContactsControllerProvider.overrideWithValue(f.controller),
            tasksRepositoryForAccountProvider.overrideWith(
              (ref, id) => repository,
            ),
            davTaskCollectionCapabilitiesProvider.overrideWith(
              (ref, key) => Stream.value(caldavTaskCollectionCapabilities),
            ),
            initialAppSettingsProvider.overrideWithValue(
              AppSettings.defaults(),
            ),
            localSettingsStoreProvider.overrideWithValue(MemorySettingsStore()),
            if (platform == 'Android')
              buildConfigProvider.overrideWithValue(BuildConfig.forAndroid()),
          ],
        );
        addTearDown(() async {
          await tester.pumpWidget(const SizedBox.shrink());
          container.dispose();
          await complete(tester, f.close);
        });
        final editor = platform == 'Android'
            ? AndroidTaskEditor(
                accountId: 'qa',
                provider: BusyProvider.caldav,
                task: task,
              )
            : TaskDetailsPane(
                accountId: 'qa',
                taskListId: task.taskListId,
                taskId: task.id,
              );
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: platform == 'Windows'
                ? fluent.FluentApp(
                    localizationsDelegates: const [AppLocalizations.delegate],
                    supportedLocales: AppLocalizations.supportedLocales,
                    home: Consumer(
                      builder: (context, ref, _) => fluent.Button(
                        child: const Text('Open task'),
                        onPressed: () => unawaited(
                          showWindowsTaskDetailsDialog(
                            context,
                            ref,
                            TaskScheduleItem(
                              id: task.id,
                              accountId: 'qa',
                              provider: BusyProvider.caldav,
                              sourceId: task.taskListId,
                              title: task.title,
                              completed: false,
                              allDay: true,
                            ),
                          ),
                        ),
                      ),
                    ),
                  )
                : localizedTestApp(child: Scaffold(body: editor)),
          ),
        );
        await settle(tester);
        if (platform == 'Windows') {
          await tester.tap(find.text('Open task'));
          await settle(tester);
        }
        Future<void> duplicate() async {
          final action = find.text('Duplicate task').first;
          await tester.ensureVisible(action);
          await tester.tap(action);
          for (
            var attempt = 0;
            attempt < 40 &&
                find
                    .textContaining('may cause the CalDAV server')
                    .evaluate()
                    .isEmpty;
            attempt++
          ) {
            await tester.pump(const Duration(milliseconds: 20));
            await tester.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 20)),
            );
          }
          await tester.pump(const Duration(milliseconds: 400));
        }

        await duplicate();
        expect(
          find.textContaining('may cause the CalDAV server'),
          findsOneWidget,
        );
        expect(
          await complete(tester, () => db.select(db.pendingOps).get()),
          isEmpty,
        );
        await tester.tap(find.text('Cancel').last);
        await settle(tester);
        expect(
          await complete(tester, () => db.select(db.pendingOps).get()),
          isEmpty,
        );
        await duplicate();
        await tester.tap(find.text('Duplicate task').last);
        await settle(tester);
        expect(
          await complete(tester, () => db.select(db.pendingOps).get()),
          hasLength(1),
          reason: find
              .byType(Text)
              .evaluate()
              .map((e) => (e.widget as Text).data)
              .whereType<String>()
              .join(' | '),
        );
      },
    );
  }
}

import 'package:flutter/services.dart';
import 'package:busymax/src/schedule/schedule_event_rescheduling.dart';

import 'dart:async';
import 'dart:convert';

import 'package:busymax/l10n/generated/app_localizations.dart';
import 'package:busymax/l10n/generated/app_localizations_en.dart';
import 'package:busymax/src/android/presentation/android_schedule_screen.dart';
import 'package:busymax/src/app/app_bootstrap.dart';
import 'package:busymax/src/calendar_providers/calendar_sync_dto.dart';
import 'package:busymax/src/db/app_database.dart';
import 'package:busymax/src/features/calendar/data/calendar_repository.dart';
import 'package:busymax/src/features/calendar/presentation/event_editor.dart';
import 'package:busymax/src/features/calendar/presentation/event_editor_draft.dart';
import 'package:busymax/src/providers/busy_provider.dart';
import 'package:busymax/src/schedule/schedule_filters.dart';
import 'package:busymax/src/schedule/schedule_item.dart';
import 'package:busymax/src/schedule/schedule_range.dart';
import 'package:busymax/src/schedule/schedule_repository.dart';
import 'package:busymax/src/ui/windows/windows_event_editor_dialog.dart';
import 'package:drift/drift.dart' show Value;
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter/material.dart';
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
      (call) async => call.method == 'state' ? <String, Object?>{} : null,
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('yaru_window/events'),
      (_) async => null,
    );
  });
  tearDown(() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      const MethodChannel('yaru_window'),
      null,
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('yaru_window/events'),
      null,
    );
  });
  for (final platform in ['Linux', 'Windows', 'Android']) {
    for (final (implicit, participants) in [
      (true, true),
      (false, true),
      (true, false),
    ]) {
      testWidgets(
        '$platform explains implicit meeting updates; capability=$implicit, attendees=$participants',
        (tester) async {
          tester.view.physicalSize = const Size(1100, 1200);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final f = ContactsFixture(AppDatabase.memoryForTests());
          final db = f.database;
          await tester.runAsync(() async {
            await db
                .into(db.accounts)
                .insert(
                  AccountsCompanion.insert(
                    id: 'account',
                    provider: 'caldav',
                    providerAccountId: 'me',
                    authState: const Value('signed_in'),
                    authority: 'https://calendar.test/',
                    credentialKind: 'caldav_password',
                    createdAtUtc: 'now',
                    updatedAtUtc: 'now',
                  ),
                );
            await db
                .into(db.davAccountServices)
                .insert(
                  DavAccountServicesCompanion.insert(
                    accountId: 'account',
                    canonicalServiceUri: 'https://calendar.test/',
                    canonicalOrigin: 'https://calendar.test',
                    capabilitiesJson: Value(
                      jsonEncode({
                        'serverFeatures': [
                          if (implicit) 'calendar-auto-schedule',
                        ],
                      }),
                    ),
                    discoveredAtUtc: 'now',
                  ),
                );
            await db
                .into(db.davCollections)
                .insert(
                  DavCollectionsCompanion.insert(
                    id: 'collection',
                    accountId: 'account',
                    hrefKey: '/calendar-homes/events/',
                    requestUri: 'https://calendar.test/calendar-homes/events/',
                    displayName: 'Calendar',
                    supportedComponentMask: const Value(1),
                    eventProjectionEnabled: const Value(true),
                    currentUserPrivilegesJson: const Value(
                      '["{DAV:}read","{DAV:}write"]',
                    ),
                    createdAtUtc: 'now',
                    updatedAtUtc: 'now',
                  ),
                );
            await db
                .into(db.calendarSources)
                .insert(
                  CalendarSourcesCompanion.insert(
                    id: 'account|caldav|/calendar-homes/events/',
                    accountId: 'account',
                    provider: 'caldav',
                    providerCalendarId: '/calendar-homes/events/',
                    summary: 'Calendar',
                    davCollectionId: const Value('collection'),
                    createdAtLocal: 0,
                    updatedAtLocal: 0,
                  ),
                );
          });
          final repository = CalendarRepository(database: db);
          await tester.runAsync(
            () => repository.upsertEvent(
              accountId: 'account',
              event: CalendarEventDto(
                provider: BusyProvider.caldav,
                providerCalendarId: '/calendar-homes/events/',
                providerEventId: 'event',
                title: 'Imported meeting',
                allDay: false,
                startDateTime: '2026-10-10T12:00:00Z',
                endDateTime: '2026-10-10T13:00:00Z',
                attendeesJson: [
                  if (participants) {'email': 'guest@example.test'},
                ],
              ),
            ),
          );
          final row = await tester.runAsync(
            () => db.select(db.calendarEvents).getSingle(),
          );
          await tester.runAsync(
            () => db
                .update(db.calendarEvents)
                .write(
                  const CalendarEventsCompanion(
                    davCollectionId: Value('collection'),
                  ),
                ),
          );
          final sources = (await tester.runAsync(
            () => repository.listVisibleSources(['account']),
          ))!;
          expect(sources.single.usesImplicitScheduling, implicit);
          final items = await tester.runAsync(
            () => ScheduleRepository(db).listItems(
              range: ScheduleRange.day(DateTime(2026, 10, 10)),
              filters: const ScheduleFilters(includeTasks: false),
            ),
          );
          expect(
            (items!.single as CalendarScheduleItem).mayNotifyParticipants,
            implicit && participants,
          );
          final detail = (await tester.runAsync(
            () => repository.loadEventDetail(row!.id),
          ))!;
          final draft = EventEditorDraft.fromEventDetail(detail);
          if (platform == 'Linux' && implicit && participants) {
            var asked = false;
            final item = items.single as CalendarScheduleItem;
            final result = await tester.runAsync(
              () =>
                  ScheduleReschedulingCoordinator(
                    repository: repository,
                    chooseScope: (_, _) async => null,
                    chooseGuestUpdates: (_) async {
                      asked = true;
                      return null;
                    },
                    requestSync: (_) async =>
                        fail('A cancelled notice must not synchronize'),
                  ).commit(
                    ScheduleRescheduleRequest(
                      item: item,
                      interval: ScheduleInterval(
                        item.start!.add(const Duration(hours: 1)),
                        item.end!.add(const Duration(hours: 1)),
                      ),
                    ),
                  ),
            );
            expect(asked, isTrue);
            expect(result, ScheduleRescheduleResult.cancelled);
          }
          final container = ProviderContainer(
            overrides: [
              databaseProvider.overrideWithValue(db),
              calendarRepositoryProvider.overrideWithValue(repository),
              busyMaxContactsControllerProvider.overrideWithValue(f.controller),
              initialAppSettingsProvider.overrideWithValue(
                AppSettings.defaults(),
              ),
              localSettingsStoreProvider.overrideWithValue(
                MemorySettingsStore(),
              ),
            ],
          );
          addTearDown(() async {
            await tester.pumpWidget(const SizedBox.shrink());
            container.dispose();
            await complete(tester, f.close);
          });
          final editor = AndroidEventEditor(draft: draft, sources: sources);
          await tester.pumpWidget(
            UncontrolledProviderScope(
              container: container,
              child: platform == 'Windows'
                  ? fluent.FluentApp(
                      localizationsDelegates: const [AppLocalizations.delegate],
                      supportedLocales: AppLocalizations.supportedLocales,
                      home: fluent.ScaffoldPage(
                        content: Consumer(
                          builder: (context, ref, _) => fluent.Button(
                            onPressed: () => unawaited(
                              showWindowsEventEditorDialog(
                                context,
                                ref,
                                eventId: row!.id,
                              ),
                            ),
                            child: const Text('Open'),
                          ),
                        ),
                      ),
                    )
                  : localizedTestApp(
                      child: platform == 'Linux'
                          ? Scaffold(
                              body: Builder(
                                builder: (context) => TextButton(
                                  onPressed: () => unawaited(
                                    showBusyMaxEventEditorDialog(
                                      context,
                                      initialDraft: draft,
                                      sources: sources,
                                      accounts: const [],
                                    ),
                                  ),
                                  child: const Text('Open'),
                                ),
                              ),
                            )
                          : editor,
                    ),
            ),
          );
          if (platform != 'Android') await tester.tap(find.text('Open'));
          await settle(tester);
          expect(
            find.text(AppLocalizationsEn().caldavSchedulingWarning),
            implicit && participants ? findsOneWidget : findsNothing,
          );
          expect(tester.takeException(), isNull);
          if (platform == 'Linux' && implicit && participants) {
            final delete = find.text(AppLocalizationsEn().deleteEvent);
            await tester.scrollUntilVisible(
              delete,
              500,
              scrollable: find.byType(Scrollable).first,
            );
            await tester.tap(delete);
            await tester.pumpAndSettle();
            expect(find.text('Notify guests?'), findsOneWidget);
            await tester.tap(find.text('Cancel').last);
            await tester.pumpAndSettle();
            expect(
              await complete(tester, () => db.select(db.pendingOps).get()),
              isEmpty,
            );
          }
          if (platform == 'Android' && implicit && participants) {
            final delete = find.text(AppLocalizationsEn().deleteEvent);
            await tester.scrollUntilVisible(
              delete,
              500,
              scrollable: find.byType(Scrollable).first,
            );
            await tester.ensureVisible(delete);
            await tester.tap(delete);
            await tester.pumpAndSettle();
            expect(
              find.descendant(
                of: find.byType(AlertDialog),
                matching: find.textContaining(
                  AppLocalizationsEn().caldavSchedulingWarning,
                ),
              ),
              findsOneWidget,
            );
            await tester.tap(find.widgetWithText(TextButton, 'Cancel').last);
            await tester.pumpAndSettle();
            expect(
              await complete(tester, () => db.select(db.pendingOps).get()),
              isEmpty,
            );
          }
        },
      );
    }
  }
}

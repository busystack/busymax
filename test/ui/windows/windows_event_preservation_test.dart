import 'dart:convert';
import 'package:busymax/src/calendar_providers/calendar_mutation.dart';
import 'package:busymax/l10n/generated/app_localizations.dart';
import 'package:busymax/src/app/app_bootstrap.dart';
import 'package:busymax/src/calendar_providers/calendar_sync_dto.dart';
import 'package:busymax/src/core/time/provider_date_time.dart';
import 'package:busymax/src/db/app_database.dart';
import 'package:busymax/src/features/accounts/data/accounts_repository.dart';
import 'package:busymax/src/features/calendar/data/calendar_repository.dart';
import 'package:busymax/src/providers/busy_provider.dart';
import 'package:busymax/src/microsoft_calendar/microsoft_calendar_api_client.dart';
import 'package:busymax/src/microsoft_calendar/microsoft_calendar_models.dart';
import 'package:busymax/src/google_calendar/google_calendar_models.dart';
import 'package:busymax/src/ui/windows/windows_event_editor_dialog.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  testWidgets('B Windows synced occurrence hides Repeat but retains scope', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 1200);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await db.close();
    });
    await db
        .into(db.accounts)
        .insert(
          AccountsCompanion.insert(
            id: 'account',
            provider: 'google',
            authority: 'https://accounts.google.com',
            providerAccountId: 'me@example.test',
            credentialKind: 'oauth',
            authState: const Value('signed_in'),
            createdAtUtc: _now,
            updatedAtUtc: _now,
          ),
        );
    final repository = CalendarRepository(database: db);
    await repository.upsertSource(
      accountId: 'account',
      source: const CalendarSourceDto(
        provider: BusyProvider.google,
        providerCalendarId: 'calendar',
        summary: 'Calendar',
        accessRole: 'writer',
      ),
    );
    await repository.upsertEvent(
      accountId: 'account',
      event: const CalendarEventDto(
        provider: BusyProvider.google,
        providerCalendarId: 'calendar',
        providerEventId: 'occurrence',
        providerRecurringEventId: 'master',
        providerOriginalStartKey: '2026-08-03T09:00:00Z',
        title: 'Occurrence',
        startDateTime: '2026-08-03T09:00:00Z',
        endDateTime: '2026-08-03T10:00:00Z',
        rawJson: {
          'id': 'occurrence',
          'recurringEventId': 'master',
          'originalStartTime': {'dateTime': '2026-08-03T09:00:00Z'},
        },
      ),
    );
    final eventId = (await db.select(db.calendarEvents).getSingle()).id;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          accountsRepositoryProvider.overrideWithValue(
            AccountsRepository(database: db),
          ),
          calendarRepositoryProvider.overrideWithValue(repository),
          localTimeZoneProvider.overrideWithValue('UTC'),
        ],
        child: FluentApp(
          localizationsDelegates: const [AppLocalizations.delegate],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Consumer(
            builder: (context, ref, _) => Button(
              onPressed: () =>
                  showWindowsEventEditorDialog(context, ref, eventId: eventId),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.runAsync(() async {
      await tester.tap(find.text('Open'));
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pumpAndSettle();
    expect(find.text('Repeat'), findsNothing);
    await tester.runAsync(() async {
      await tester.tap(find.widgetWithText(FilledButton, 'Save').last);
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    for (
      var i = 0;
      i < 30 &&
          find
              .text(
                'Choose whether this change applies to the entire series, only this occurrence, or this and following events.',
              )
              .evaluate()
              .isEmpty;
      i++
    ) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    expect(
      find.text(
        'Choose whether this change applies to the entire series, only this occurrence, or this and following events.',
      ),
      findsWidgets,
    );
  });

  testWidgets('Windows Microsoft category choice retains unknown assignments', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 1200);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await db.close();
    });
    final repository = CalendarRepository(database: db);
    await db
        .into(db.accounts)
        .insert(
          AccountsCompanion.insert(
            id: 'microsoft-account',
            provider: 'microsoft',
            authority: 'https://login.microsoftonline.com/common',
            providerAccountId: 'owner@example.test',
            credentialKind: 'oauth',
            authState: const Value('signed_in'),
            createdAtUtc: _now,
            updatedAtUtc: _now,
          ),
        );
    await repository.upsertSource(
      accountId: 'microsoft-account',
      source: const CalendarSourceDto(
        provider: BusyProvider.microsoft,
        providerCalendarId: 'calendar',
        summary: 'Work',
        accessRole: 'writer',
      ),
    );
    await repository.upsertEvent(
      accountId: 'microsoft-account',
      event: const CalendarEventDto(
        provider: BusyProvider.microsoft,
        providerCalendarId: 'calendar',
        providerEventId: 'event',
        title: 'Planning',
        startDateTime: '2026-06-08T09:00:00',
        startTimeZone: 'UTC',
        endDateTime: '2026-06-08T10:00:00',
        endTimeZone: 'UTC',
        categoriesJson: ['Unknown'],
      ),
    );
    final eventId = (await db.select(db.calendarEvents).getSingle()).id;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          accountsRepositoryProvider.overrideWithValue(
            AccountsRepository(database: db),
          ),
          calendarRepositoryProvider.overrideWithValue(repository),
          localTimeZoneProvider.overrideWithValue('UTC'),
          microsoftMasterCategoriesProvider.overrideWith(
            (ref, accountId) async => [
              const MicrosoftMasterCategory(
                id: 'category-1',
                displayName: 'Work',
                color: 'preset7',
              ),
            ],
          ),
        ],
        child: FluentApp(
          localizationsDelegates: const [AppLocalizations.delegate],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Consumer(
            builder: (context, ref, _) => Button(
              onPressed: () =>
                  showWindowsEventEditorDialog(context, ref, eventId: eventId),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.runAsync(() async {
      await tester.tap(find.text('Open'));
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Work').last);
    await tester.pumpAndSettle();
    final choice = find.widgetWithText(ToggleButton, 'Work');
    await tester.tap(choice);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Save').last);
    await tester.pumpAndSettle();
    final request =
        jsonDecode((await db.select(db.pendingOps).getSingle()).requestJson)
            as Map;
    expect(request['categoriesJson'], ['Unknown', 'Work']);
  });

  testWidgets(
    'Windows primary Google editor queues a native working location',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1200, 1200);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        await db.close();
      });
      final repository = CalendarRepository(database: db);
      await db
          .into(db.accounts)
          .insert(
            AccountsCompanion.insert(
              id: 'google-account',
              provider: 'google',
              authority: 'https://accounts.google.com',
              providerAccountId: 'owner@example.com',
              email: const Value('owner@example.com'),
              credentialKind: 'oauth',
              authState: const Value('signed_in'),
              createdAtUtc: _now,
              updatedAtUtc: _now,
            ),
          );
      await repository.upsertSource(
        accountId: 'google-account',
        source: const CalendarSourceDto(
          provider: BusyProvider.google,
          providerCalendarId: 'primary',
          summary: 'Primary',
          primaryCalendar: true,
          accessRole: 'owner',
        ),
      );
      final source = (await db.select(db.calendarSources).get()).single;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            accountsRepositoryProvider.overrideWithValue(
              AccountsRepository(database: db),
            ),
            calendarRepositoryProvider.overrideWithValue(repository),
            localTimeZoneProvider.overrideWithValue('UTC'),
            googleEventLabelsForCalendarProvider.overrideWith(
              (ref, key) async => const [],
            ),
          ],
          child: FluentApp(
            localizationsDelegates: const [AppLocalizations.delegate],
            supportedLocales: AppLocalizations.supportedLocales,
            home: Consumer(
              builder: (context, ref, _) => Button(
                onPressed: () => showWindowsEventEditorDialog(
                  context,
                  ref,
                  initialStart: DateTime.utc(2026, 6, 8, 9),
                  initialAccountId: 'google-account',
                  initialSourceId: source.id,
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.runAsync(() async {
        await tester.tap(find.text('Open'));
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextBox).first, 'Working from home');
      final type = find.byKey(const Key('windows-google-event-type'));
      await tester.ensureVisible(type);
      tester.widget<ComboBox<String>>(type).onChanged?.call('workingLocation');
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Create').last);
      await tester.pumpAndSettle();
      final request =
          jsonDecode((await db.select(db.pendingOps).getSingle()).requestJson)
              as Map;
      expect(request['eventType'], 'workingLocation');
      expect((request['googleStatusProperties'] as Map)['type'], 'homeOffice');
    },
  );

  testWidgets('Windows event editor queues selected Google label', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 1200);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await db.close();
    });
    final repository = CalendarRepository(database: db);
    await db
        .into(db.accounts)
        .insert(
          AccountsCompanion.insert(
            id: 'google-account',
            provider: 'google',
            authority: 'https://accounts.google.com',
            providerAccountId: 'owner@example.com',
            email: const Value('owner@example.com'),
            credentialKind: 'oauth',
            authState: const Value('signed_in'),
            createdAtUtc: _now,
            updatedAtUtc: _now,
          ),
        );
    await repository.upsertSource(
      accountId: 'google-account',
      source: const CalendarSourceDto(
        provider: BusyProvider.google,
        providerCalendarId: 'calendar',
        summary: 'Work',
        accessRole: 'owner',
      ),
    );
    await repository.upsertEvent(
      accountId: 'google-account',
      event: const CalendarEventDto(
        provider: BusyProvider.google,
        providerCalendarId: 'calendar',
        providerEventId: 'event',
        title: 'Planning',
        startDateTime: '2026-06-08T09:00:00Z',
        endDateTime: '2026-06-08T10:00:00Z',
        organizerJson: {'self': true},
        rawJson: {
          'id': 'event',
          'organizer': {'self': true},
        },
      ),
    );
    final eventId = (await db.select(db.calendarEvents).getSingle()).id;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          accountsRepositoryProvider.overrideWithValue(
            AccountsRepository(database: db),
          ),
          calendarRepositoryProvider.overrideWithValue(repository),
          localTimeZoneProvider.overrideWithValue('UTC'),
          googleEventLabelsForCalendarProvider.overrideWith(
            (ref, key) async => [
              const GoogleEventLabel(
                id: 'label-1',
                name: 'Project',
                backgroundColor: '#336699',
              ),
            ],
          ),
        ],
        child: FluentApp(
          localizationsDelegates: const [AppLocalizations.delegate],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Consumer(
            builder: (context, ref, _) => Button(
              onPressed: () =>
                  showWindowsEventEditorDialog(context, ref, eventId: eventId),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.runAsync(() async {
      await tester.tap(find.text('Open'));
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pumpAndSettle();
    final selector = find.byKey(const Key('windows-event-label'));
    await tester.ensureVisible(selector);
    await tester.pumpAndSettle();
    tester.widget<ComboBox<String>>(selector).onChanged?.call('label-1');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(Button, 'Cancel').last);
    await tester.pumpAndSettle();
    expect(find.text('Discard changes?'), findsOneWidget);
    await tester.tap(find.widgetWithText(Button, 'Cancel').last);
    await tester.pumpAndSettle();
    tester.widget<ComboBox<String>>(selector).onChanged?.call('');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(Button, 'Cancel').last);
    await tester.pumpAndSettle();
    expect(find.text('Discard changes?'), findsNothing);
    expect(selector, findsNothing);
    await tester.runAsync(() async {
      await tester.tap(find.text('Open'));
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pumpAndSettle();
    final reopenedSelector = find.byKey(const Key('windows-event-label'));
    await tester.ensureVisible(reopenedSelector);
    tester
        .widget<ComboBox<String>>(reopenedSelector)
        .onChanged
        ?.call('label-1');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Save').last);
    await tester.pumpAndSettle();
    final operation = await db.select(db.pendingOps).getSingle();
    expect(jsonDecode(operation.requestJson)['eventLabelId'], 'label-1');
  });

  testWidgets(
    'Windows Microsoft editor opens guest availability without saving',
    (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        await db.close();
      });
      final repository = CalendarRepository(database: db);
      await db
          .into(db.accounts)
          .insert(
            AccountsCompanion.insert(
              id: 'microsoft-account',
              provider: 'microsoft',
              authority: 'https://login.microsoftonline.com/common',
              providerAccountId: 'me@example.test',
              email: const Value('me@example.test'),
              tenantId: const Value('11111111-2222-4333-8444-555555555555'),
              credentialKind: 'oauth',
              authState: const Value('signed_in'),
              createdAtUtc: _now,
              updatedAtUtc: _now,
            ),
          );
      await repository.upsertSource(
        accountId: 'microsoft-account',
        source: const CalendarSourceDto(
          provider: BusyProvider.microsoft,
          providerCalendarId: 'calendar',
          summary: 'Work',
          dataOwner: 'me@example.test',
        ),
      );
      await repository.upsertEvent(
        accountId: 'microsoft-account',
        event: const CalendarEventDto(
          provider: BusyProvider.microsoft,
          providerCalendarId: 'calendar',
          providerEventId: 'event',
          title: 'Planning',
          startDateTime: '2026-06-08T09:00:00',
          startTimeZone: 'America/Los_Angeles',
          endDateTime: '2026-06-08T10:00:00',
          endTimeZone: 'America/Los_Angeles',
          attendeesJson: [
            {
              'emailAddress': {'address': 'guest@example.test'},
              'type': 'required',
            },
          ],
          updatedAtServer: _now,
        ),
      );
      final event = await db.select(db.calendarEvents).getSingle();
      var requests = 0;
      Map<String, Object?>? scheduleRequest;
      final client = MicrosoftCalendarApiClient(
        httpClient: MockClient((request) async {
          requests++;
          expect(request.url.path, '/v1.0/me/calendar/getSchedule');
          scheduleRequest = (jsonDecode(request.body) as Map)
              .cast<String, Object?>();
          return http.Response(
            '{"value":[{"scheduleId":"guest@example.test","scheduleItems":[]}]}',
            200,
          );
        }),
        baseUri: Uri.parse('https://graph.microsoft.com/v1.0'),
        responseTimeZone: 'UTC',
        accountTenantId: '11111111-2222-4333-8444-555555555555',
        authorizationHeaderProvider: () async => 'Bearer test-token',
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            accountsRepositoryProvider.overrideWithValue(
              AccountsRepository(database: db),
            ),
            calendarRepositoryProvider.overrideWithValue(repository),
            localTimeZoneProvider.overrideWithValue('UTC'),
            calendarRemoteApiClientForAccountProvider(
              'microsoft-account',
            ).overrideWithValue(client),
          ],
          child: FluentApp(
            localizationsDelegates: const [AppLocalizations.delegate],
            supportedLocales: AppLocalizations.supportedLocales,
            home: Consumer(
              builder: (context, ref, _) => Button(
                onPressed: () => showWindowsEventEditorDialog(
                  context,
                  ref,
                  eventId: event.id,
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.runAsync(() async {
        await tester.tap(find.text('Open'));
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pumpAndSettle();
      final action = find.text('Check guest availability');
      expect(action, findsOneWidget);
      await tester.ensureVisible(action);
      await tester.tap(action);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('windows-cloud-availability-dialog')),
        findsOneWidget,
      );
      expect(
        find.text('No busy periods reported for this interval'),
        findsOneWidget,
      );
      expect(requests, 1);
      expect(
        (scheduleRequest?['startTime'] as Map)['dateTime'],
        '2026-06-08T16:00:00.000',
      );
      expect(
        (scheduleRequest?['endTime'] as Map)['dateTime'],
        '2026-06-08T17:00:00.000',
      );
      expect(await db.select(db.pendingOps).get(), isEmpty);
      // Drain Drift's deferred stream-close timer while the test clock is
      // still active, after the editor's provider scope is disposed.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 1));
    },
  );

  for (final scenario in [
    'title only',
    'compatible move',
    'switch and return',
    'description dismissal',
  ]) {
    testWidgets(
      '$scenario retains endpoint zones, recurrence, reminders and personal fields',
      (tester) async {
        final db = AppDatabase(NativeDatabase.memory());
        addTearDown(() async {
          await tester.pumpWidget(const SizedBox.shrink());
          await db.close();
        });
        final repository = CalendarRepository(database: db);
        await db
            .into(db.accounts)
            .insert(
              AccountsCompanion.insert(
                id: 'account',
                provider: 'google',
                authority: 'https://accounts.google.com',
                providerAccountId: 'me@example.test',
                email: const Value('me@example.test'),
                credentialKind: 'oauth',
                authState: const Value('signed_in'),
                createdAtUtc: _now,
                updatedAtUtc: _now,
              ),
            );
        for (final id in ['original', 'destination']) {
          await repository.upsertSource(
            accountId: 'account',
            source: CalendarSourceDto(
              provider: BusyProvider.google,
              providerCalendarId: id,
              summary: id,
              timeZone: 'Europe/London',
              dataOwner: 'me@example.test',
            ),
          );
        }
        await repository.upsertEvent(
          accountId: 'account',
          event: const CalendarEventDto(
            provider: BusyProvider.google,
            providerCalendarId: 'original',
            providerEventId: 'event',
            organizerJson: {'self': true},
            title: 'Flight',
            startDateTime: '2026-01-12T12:05:17',
            startTimeZone: 'Asia/Tokyo',
            endDateTime: '2026-01-12T01:05:33',
            endTimeZone: 'America/Los_Angeles',
            recurrenceJson: ['RRULE:FREQ=WEEKLY;BYDAY=MO'],
            remindersJson: {
              'useDefault': false,
              'overrides': [
                {'method': 'popup', 'minutes': 10},
                {'method': 'email', 'minutes': 30},
              ],
            },
            visibility: 'private',
            transparencyOrShowAs: 'transparent',
            conferenceJson: {'conferenceId': 'meeting'},
            updatedAtServer: _now,
            rawJson: {'id': 'event', 'guestsCanSeeOtherGuests': false},
          ),
        );
        final before = await db.select(db.calendarEvents).getSingle();
        bool? saved;
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              databaseProvider.overrideWithValue(db),
              accountsRepositoryProvider.overrideWithValue(
                AccountsRepository(database: db),
              ),
              calendarRepositoryProvider.overrideWithValue(repository),
              localTimeZoneProvider.overrideWithValue('UTC'),
            ],
            child: FluentApp(
              localizationsDelegates: const [AppLocalizations.delegate],
              supportedLocales: AppLocalizations.supportedLocales,
              home: Consumer(
                builder: (context, ref, _) => Button(
                  onPressed: () async =>
                      saved = await showWindowsEventEditorDialog(
                        context,
                        ref,
                        eventId: before.id,
                      ),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        );
        await tester.runAsync(() async {
          await tester.tap(find.text('Open'));
          await Future<void>.delayed(const Duration(milliseconds: 50));
        });
        for (
          var i = 0;
          i < 60 && find.byType(ContentDialog).evaluate().isEmpty;
          i++
        ) {
          await tester.pump(const Duration(milliseconds: 20));
        }
        await tester.pumpAndSettle();
        expect(
          find.text('Asia/Tokyo'),
          findsOneWidget,
          reason: tester
              .widgetList<Text>(find.byType(Text))
              .map((t) => t.data)
              .join(' | '),
        );
        expect(find.text('America/Los_Angeles'), findsOneWidget);
        if (scenario == 'description dismissal') {
          final description = find.byWidgetPredicate(
            (widget) => widget is TextBox && widget.maxLines == 4,
          );
          await tester.ensureVisible(description);
          await tester.enterText(description, 'Keep this description');
          await tester.pump();
          await tester.binding.handlePopRoute();
          await tester.pumpAndSettle();
          expect(find.text('Discard changes?'), findsOneWidget);
          await tester.tap(find.widgetWithText(Button, 'Cancel').last);
          await tester.pumpAndSettle();
          expect(find.text('Discard changes?'), findsNothing);
          expect(
            tester.widget<TextBox>(description).controller!.text,
            'Keep this description',
          );
          expect(find.byType(ContentDialog), findsOneWidget);
          expect(await db.select(db.pendingOps).get(), isEmpty);
          expect(tester.takeException(), isNull);
          return;
        }
        if (scenario != 'title only') {
          await tester.tap(find.byType(ComboBox<CalendarSourceEntity>));
          await tester.pumpAndSettle();
          await tester.tap(
            find.text('Google · me@example.test · destination').last,
          );
          await tester.pumpAndSettle();
          if (scenario == 'switch and return') {
            await tester.tap(find.byType(ComboBox<CalendarSourceEntity>));
            await tester.pumpAndSettle();
            await tester.tap(
              find.text('Google · me@example.test · original').last,
            );
            await tester.pumpAndSettle();
          }
        }
        await tester.enterText(find.byType(TextBox).first, 'Renamed flight');
        await tester.pump();
        await tester.runAsync(() async {
          await tester.tap(find.widgetWithText(FilledButton, 'Save').last);
          await Future<void>.delayed(const Duration(milliseconds: 50));
        });
        for (var i = 0; i < 60 && saved == null; i++) {
          await tester.pump(const Duration(milliseconds: 20));
        }
        await tester.pumpAndSettle();
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 30)),
        );
        expect(
          saved,
          isTrue,
          reason: tester
              .widgetList<Text>(find.byType(Text))
              .map((t) => t.data)
              .join(' | '),
        );
        final after = await db.select(db.calendarEvents).getSingle();
        expect(after.title, 'Renamed flight');
        expect(after.startTimeZone, before.startTimeZone);
        expect(after.endTimeZone, before.endTimeZone);
        expect(
          providerDateTimeAsUtcInstant(
            after.startDateTime,
            after.startTimeZone,
          ),
          providerDateTimeAsUtcInstant(
            before.startDateTime,
            before.startTimeZone,
          ),
        );
        expect(
          providerDateTimeAsUtcInstant(after.endDateTime, after.endTimeZone),
          providerDateTimeAsUtcInstant(before.endDateTime, before.endTimeZone),
        );
        expect(after.recurrenceJson, before.recurrenceJson);
        expect(after.remindersJson, before.remindersJson);
        expect(after.visibility, before.visibility);
        expect(after.transparencyOrShowAs, before.transparencyOrShowAs);
        expect(after.conferenceJson, before.conferenceJson);
        // Google retains source identity until the remote move succeeds. The
        // dependent patch must keep all existing properties and the title edit.
        final operations = await db.select(db.pendingOps).get();
        final patch =
            jsonDecode(
                  operations
                      .singleWhere((op) => op.operation == 'patch')
                      .requestJson,
                )
                as Map;
        expect(patch['title'], 'Renamed flight');
        expect(patch.keys, isNot(contains('start')));
        expect(patch.keys, isNot(contains('end')));
        expect(patch.keys, isNot(contains('remindersJson')));
        if (scenario == 'compatible move') {
          final move =
              jsonDecode(
                    operations
                        .singleWhere((op) => op.operation == 'move')
                        .requestJson,
                  )
                  as Map;
          expect(move[calendarEventDestinationCalendarIdKey], 'destination');
        } else {
          expect(operations.where((op) => op.operation == 'move'), isEmpty);
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}

const _now = '2026-01-12T00:00:00Z';

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
import 'package:busymax/src/ui/windows/windows_event_editor_dialog.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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

import 'package:busymax/l10n/generated/app_localizations.dart';
import 'package:busymax/src/app/app_bootstrap.dart';
import 'package:busymax/src/calendar_providers/calendar_sync_dto.dart';
import 'package:busymax/src/core/time/provider_date_time.dart';
import 'package:busymax/src/db/app_database.dart';
import 'package:busymax/src/features/accounts/data/accounts_repository.dart';
import 'package:busymax/src/features/calendar/data/calendar_repository.dart';
import 'package:busymax/src/features/maps/domain/geographic_point.dart';
import 'package:busymax/src/providers/busy_provider.dart';
import 'package:busymax/src/schedule/schedule_event_rescheduling.dart';
import 'package:busymax/src/ui/windows/windows_event_editor_dialog.dart';
import 'package:drift/native.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final save in [false, true]) {
    testWidgets(
      'Windows midnight range editor ${save ? 'saves exact interval' : 'cancels without creating'}',
      (tester) async {
        final database = AppDatabase(NativeDatabase.memory());
        addTearDown(database.close);
        final repository = CalendarRepository(database: database);
        await database
            .into(database.accounts)
            .insert(
              AccountsCompanion.insert(
                id: 'account',
                provider: 'google',
                authority: 'https://accounts.google.com',
                providerAccountId: 'me@example.com',
                credentialKind: 'oauth',
                createdAtUtc: '2026-01-12T00:00:00Z',
                updatedAtUtc: '2026-01-12T00:00:00Z',
              ),
            );
        await repository.upsertSource(
          accountId: 'account',
          source: const CalendarSourceDto(
            provider: BusyProvider.google,
            providerCalendarId: 'calendar',
            summary: 'Calendar',
            timeZone: 'Asia/Tokyo',
            dataOwner: 'me@example.com',
          ),
        );
        final interval = ScheduleInterval(
          DateTime.utc(2026, 1, 12),
          DateTime.utc(2026, 1, 12, 0, 45),
        );
        bool? result;
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              databaseProvider.overrideWithValue(database),
              accountsRepositoryProvider.overrideWithValue(_Accounts(database)),
              calendarRepositoryProvider.overrideWithValue(
                _CalendarRepository(
                  database,
                  await repository.listVisibleSources(['account']),
                ),
              ),
              localTimeZoneProvider.overrideWithValue('UTC'),
            ],
            child: FluentApp(
              localizationsDelegates: const [AppLocalizations.delegate],
              supportedLocales: AppLocalizations.supportedLocales,
              home: Consumer(
                builder: (context, ref, _) => Button(
                  onPressed: () async {
                    result = await showWindowsEventEditorDialog(
                      context,
                      ref,
                      initialInterval: interval,
                    );
                  },
                  child: const Text('Open range'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open range'));
        for (
          var i = 0;
          i < 10 && find.byType(ContentDialog).evaluate().isEmpty;
          i++
        ) {
          await tester.pump(const Duration(milliseconds: 20));
        }
        await tester.pumpAndSettle();
        expect(find.byType(ContentDialog), findsOneWidget);
        expect(
          find.byKey(const ValueKey('windows-event-location-field')),
          findsOneWidget,
        );
        expect(find.text('Show on map'), findsNothing);
        final pickers = tester
            .widgetList<TimePicker>(find.byType(TimePicker))
            .toList();
        expect(pickers[0].selected!.hour, 0);
        expect(pickers[0].selected!.minute, 0);
        expect(pickers[1].selected!.hour, 0);
        expect(pickers[1].selected!.minute, 45);
        expect(await database.select(database.calendarEvents).get(), isEmpty);
        if (save) {
          await tester.enterText(
            find.byType(TextBox).first,
            'Midnight interval',
          );
          await tester.enterText(
            find.byKey(const ValueKey('windows-event-location-field')),
            'Meeting room 3',
          );
          await tester.pump();
        }
        await tester.tap(find.text(save ? 'Create' : 'Cancel').last);
        for (var i = 0; i < 20 && result == null; i++) {
          await tester.pump(const Duration(milliseconds: 20));
        }
        await tester.pumpAndSettle();
        expect(result, save);
        final rows = await database.select(database.calendarEvents).get();
        expect(rows, hasLength(save ? 1 : 0));
        if (save) {
          expect(rows.single.location, 'Meeting room 3');
          expect(
            providerDateTimeAsUtcInstant(
              rows.single.startDateTime,
              rows.single.startTimeZone,
            ),
            interval.start.toUtc(),
          );
          expect(
            providerDateTimeAsUtcInstant(
              rows.single.endDateTime,
              rows.single.endTimeZone,
            ),
            interval.end.toUtc(),
          );
        }
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      },
    );
  }

  testWidgets(
    'title-only Windows save preserves exact location and native point',
    (tester) async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final repository = CalendarRepository(database: database);
      await database
          .into(database.accounts)
          .insert(
            AccountsCompanion.insert(
              id: 'account',
              provider: 'microsoft',
              authority: 'https://login.microsoftonline.com/common',
              providerAccountId: 'me@example.com',
              credentialKind: 'oauth',
              createdAtUtc: '2026-01-12T00:00:00Z',
              updatedAtUtc: '2026-01-12T00:00:00Z',
            ),
          );
      await repository.upsertSource(
        accountId: 'account',
        source: const CalendarSourceDto(
          provider: BusyProvider.microsoft,
          providerCalendarId: 'calendar',
          summary: 'Calendar',
          dataOwner: 'me@example.com',
        ),
      );
      final point = GeographicPoint(latitude: 49.28, longitude: -123.12);
      await repository.upsertEvent(
        accountId: 'account',
        event: CalendarEventDto(
          provider: BusyProvider.microsoft,
          providerCalendarId: 'calendar',
          providerEventId: 'event',
          title: 'Original title',
          location: '  Head office  ',
          locationPoint: point,
          startDateTime: '2026-01-12T10:00:00Z',
          endDateTime: '2026-01-12T11:00:00Z',
          updatedAtServer: '2026-01-12T00:00:00Z',
          rawJson: {
            'id': 'event',
            'subject': 'Original title',
            'location': {
              'displayName': '  Head office  ',
              'coordinates': {'latitude': 49.28, 'longitude': -123.12},
            },
          },
        ),
      );
      final sources = await repository.listVisibleSources(['account']);
      final eventId = CalendarRepository.eventId(
        accountId: 'account',
        provider: BusyProvider.microsoft,
        providerCalendarId: 'calendar',
        providerEventId: 'event',
      );
      bool? result;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(database),
            accountsRepositoryProvider.overrideWithValue(
              _Accounts(database, provider: BusyProvider.microsoft),
            ),
            calendarRepositoryProvider.overrideWithValue(
              _CalendarRepository(database, sources),
            ),
            localTimeZoneProvider.overrideWithValue('UTC'),
          ],
          child: FluentApp(
            localizationsDelegates: const [AppLocalizations.delegate],
            supportedLocales: AppLocalizations.supportedLocales,
            home: Consumer(
              builder: (context, ref, _) => Button(
                onPressed: () async {
                  result = await showWindowsEventEditorDialog(
                    context,
                    ref,
                    eventId: eventId,
                  );
                },
                child: const Text('Open event'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open event'));
      for (
        var i = 0;
        i < 10 && find.byType(ContentDialog).evaluate().isEmpty;
        i++
      ) {
        await tester.pump(const Duration(milliseconds: 20));
      }
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextBox).first, 'Renamed');
      await tester.tap(find.text('Save').last);
      for (var i = 0; i < 20 && result == null; i++) {
        await tester.pump(const Duration(milliseconds: 20));
      }
      await tester.pumpAndSettle();

      expect(result, isTrue);
      final event = await (database.select(
        database.calendarEvents,
      )..where((row) => row.id.equals(eventId))).getSingle();
      expect(event.title, 'Renamed');
      expect(event.location, '  Head office  ');
      expect(event.locationLatitude, point.latitude);
      expect(event.locationLongitude, point.longitude);
      final operation = await database.select(database.pendingOps).getSingle();
      expect(operation.requestJson, isNot(contains('location')));
    },
  );
}

class _Accounts extends AccountsRepository {
  _Accounts(AppDatabase database, {this.provider = BusyProvider.google})
    : super(database: database);

  final BusyProvider provider;

  @override
  Stream<List<AccountEntity>> watchAccounts() => Stream.value([
    AccountEntity(
      id: 'account',
      provider: provider,
      authority: 'https://accounts.google.com',
      providerAccountId: 'me@example.com',
      authState: accountAuthStateSignedIn,
    ),
  ]);
}

class _CalendarRepository extends CalendarRepository {
  _CalendarRepository(AppDatabase database, this.sources)
    : super(database: database);
  final List<CalendarSourceEntity> sources;
  @override
  Stream<List<CalendarSourceEntity>> watchSourcesForAccounts(
    List<String> accountIds,
  ) => Stream.value(sources);
}

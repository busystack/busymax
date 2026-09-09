import 'dart:convert';

import 'package:busymax/l10n/generated/app_localizations.dart';
import 'package:busymax/src/app/app_bootstrap.dart';
import 'package:busymax/src/app/busymax_design.dart';
import 'package:busymax/src/db/app_database.dart';
import 'package:busymax/src/features/accounts/data/accounts_repository.dart';
import 'package:busymax/src/features/calendar/data/calendar_repository.dart';
import 'package:busymax/src/features/maps/application/external_location_launcher.dart';
import 'package:busymax/src/features/maps/data/location_resolution_repository.dart';
import 'package:busymax/src/features/schedule/application/saved_schedule_location.dart';
import 'package:busymax/src/features/schedule/presentation/schedule_workspace.dart';
import 'package:busymax/src/features/schedule/presentation/schedule_event_block.dart';
import 'package:busymax/src/ical/ical_import_service.dart';
import 'package:busymax/src/platform/linux_header_bar_provider.dart';
import 'package:busymax/src/platform/linux_header_bar_service.dart';
import 'package:busymax/src/providers/busy_provider.dart';
import 'package:busymax/src/schedule/schedule_repository.dart';
import 'package:busymax/src/schedule/schedule_range.dart';
import 'package:busymax/src/schedule/schedule_scope.dart';
import 'package:busymax/src/ui/windows/windows_schedule_page.dart';
import 'package:drift/drift.dart' show Value;
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../support/memory_settings_store.dart';
import '../../../test_localized_app.dart';

void main() {
  testWidgets(
    'GEO-only Google import opens its remembered point on both desktops without writes',
    (tester) async {
      tester.view
        ..devicePixelRatio = 1
        ..physicalSize = const Size(1500, 900);
      addTearDown(tester.view.reset);

      final harness = await _importGeoOnlyGoogleEvent();
      addTearDown(harness.database.close);
      final item = (await ScheduleRepository(
        harness.database,
      ).listItems(range: ScheduleRange.week(DateTime.now()))).single;
      final resolved = await resolveSavedScheduleLocation(
        item: item,
        repository: LocationResolutionRepository(harness.database),
      );
      expect(resolved?.kind, ExternalLocationDestinationKind.coordinates);
      expect(resolved?.point?.directionsValue, '0.0,-123.12');
      final before = await _databaseSnapshot(harness.database);

      final linuxCalls = <({Uri uri, LaunchMode mode})>[];
      final linuxLauncher = ExternalLocationLauncher(
        platform: () => ExternalLocationPlatform.linux,
        linuxLauncher: (uri, {mode = LaunchMode.platformDefault}) async {
          linuxCalls.add((uri: uri, mode: mode));
          return true;
        },
      );
      final headerBar = LinuxHeaderBarService(isLinux: false);
      addTearDown(headerBar.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: _providerOverrides(harness, headerBar: headerBar),
          child: localizedTestApp(
            child: ScheduleWorkspace(
              initialScope: ScheduleScope.events,
              externalLocationLauncher: linuxLauncher,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final linuxEvent = find.byType(ScheduleEventBlock);
      expect(linuxEvent, findsOneWidget);
      tester
          .widget<ScheduleEventBlock>(linuxEvent)
          .onTap!
          .call(tester.element(linuxEvent));
      await tester.pumpAndSettle();
      expect(find.byType(BusyMaxContentPopoverSurface), findsOneWidget);
      expect(find.byKey(const ValueKey('saved-location-open')), findsOneWidget);
      expect(find.text('Show on map'), findsOneWidget);
      expect(find.text('0.0,-123.12'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('saved-location-open')));
      await tester.pumpAndSettle();
      expect(linuxCalls.map((call) => call.uri.toString()), [
        'geo:0.0,-123.12',
      ]);
      expect(linuxCalls.single.mode, LaunchMode.externalApplication);
      expect(await _databaseSnapshot(harness.database), before);

      final windowsCalls = <({Uri uri, LaunchMode mode})>[];
      final windowsLauncher = ExternalLocationLauncher(
        platform: () => ExternalLocationPlatform.windows,
        launcher: (uri, {mode = LaunchMode.platformDefault}) async {
          windowsCalls.add((uri: uri, mode: mode));
          return true;
        },
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: _providerOverrides(harness, headerBar: headerBar),
          child: fluent.FluentApp(
            theme: fluent.FluentThemeData(),
            localizationsDelegates: const [AppLocalizations.delegate],
            supportedLocales: AppLocalizations.supportedLocales,
            home: WindowsSchedulePage(
              externalLocationLauncher: windowsLauncher,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final windowsEventButton = find.ancestor(
        of: find.text(_title),
        matching: find.byType(fluent.Button),
      );
      expect(windowsEventButton, findsOneWidget);
      tester.widget<fluent.Button>(windowsEventButton).onPressed!();
      await tester.pumpAndSettle();
      expect(find.byType(fluent.ContentDialog), findsOneWidget);
      expect(
        find.byKey(const ValueKey('windows-saved-location-open')),
        findsOneWidget,
      );
      expect(find.text('Show on map'), findsOneWidget);
      expect(find.text('0.0,-123.12'), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey('windows-saved-location-open')),
      );
      await tester.pumpAndSettle();
      expect(windowsCalls, hasLength(1));
      expect(windowsCalls.single.mode, LaunchMode.externalApplication);
      expect(windowsCalls.single.uri.scheme, 'https');
      expect(windowsCalls.single.uri.path, '/maps/search/');
      expect(windowsCalls.single.uri.queryParameters, {
        'api': '1',
        'query': '0.0,-123.12',
      });
      expect(await _databaseSnapshot(harness.database), before);

      await harness.database.delete(harness.database.locationResolutions).go();
      final withoutDestination = await _databaseSnapshot(harness.database);

      await tester.pumpWidget(
        ProviderScope(
          overrides: _providerOverrides(harness, headerBar: headerBar),
          child: localizedTestApp(
            child: ScheduleWorkspace(
              initialScope: ScheduleScope.events,
              externalLocationLauncher: linuxLauncher,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final linuxEventWithoutDestination = find.byType(ScheduleEventBlock);
      tester
          .widget<ScheduleEventBlock>(linuxEventWithoutDestination)
          .onTap!
          .call(tester.element(linuxEventWithoutDestination));
      await tester.pumpAndSettle();
      expect(find.byType(BusyMaxContentPopoverSurface), findsOneWidget);
      expect(find.byKey(const ValueKey('saved-location-open')), findsNothing);
      expect(linuxCalls, hasLength(1));
      expect(await _databaseSnapshot(harness.database), withoutDestination);

      await tester.pumpWidget(
        ProviderScope(
          overrides: _providerOverrides(harness, headerBar: headerBar),
          child: fluent.FluentApp(
            theme: fluent.FluentThemeData(),
            localizationsDelegates: const [AppLocalizations.delegate],
            supportedLocales: AppLocalizations.supportedLocales,
            home: WindowsSchedulePage(
              externalLocationLauncher: windowsLauncher,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final windowsEventWithoutDestination = find.ancestor(
        of: find.text(_title),
        matching: find.byType(fluent.Button),
      );
      tester.widget<fluent.Button>(windowsEventWithoutDestination).onPressed!();
      await tester.pumpAndSettle();
      expect(find.byType(fluent.ContentDialog), findsOneWidget);
      expect(
        find.byKey(const ValueKey('windows-saved-location-open')),
        findsNothing,
      );
      expect(windowsCalls, hasLength(1));
      expect(await _databaseSnapshot(harness.database), withoutDestination);
    },
  );
}

List<Override> _providerOverrides(
  _ImportHarness harness, {
  LinuxHeaderBarService? headerBar,
}) => [
  databaseProvider.overrideWithValue(harness.database),
  calendarRepositoryProvider.overrideWithValue(harness.calendarRepository),
  scheduleRepositoryProvider.overrideWithValue(
    ScheduleRepository(harness.database),
  ),
  accountsStreamProvider.overrideWith((ref) => Stream.value([harness.account])),
  activeAccountProvider.overrideWithValue(_accountId),
  localTimeZoneProvider.overrideWithValue('UTC'),
  localSettingsStoreProvider.overrideWithValue(MemorySettingsStore()),
  initialAppSettingsProvider.overrideWithValue(AppSettings.defaults()),
  if (headerBar != null)
    linuxHeaderBarServiceProvider.overrideWithValue(headerBar),
];

Future<_ImportHarness> _importGeoOnlyGoogleEvent() async {
  final database = AppDatabase.memoryForTests();
  final now = DateTime.now();
  final start = DateTime(now.year, now.month, now.day, 12).toUtc();
  final end = start.add(const Duration(hours: 1));
  final timestamp = now.toUtc().toIso8601String();
  await database
      .into(database.accounts)
      .insert(
        AccountsCompanion.insert(
          id: _accountId,
          provider: BusyProvider.google.storageValue,
          authority: 'https://accounts.google.com',
          providerAccountId: 'geo-only@example.test',
          credentialKind: 'oauth',
          email: const Value('geo-only@example.test'),
          authState: const Value(accountAuthStateSignedIn),
          calendarsEnabled: const Value(true),
          tasksEnabled: const Value(false),
          grantedScopes: const Value(''),
          createdAtUtc: timestamp,
          updatedAtUtc: timestamp,
        ),
      );
  await database
      .into(database.calendarSources)
      .insert(
        CalendarSourcesCompanion.insert(
          id: _sourceId,
          accountId: _accountId,
          provider: BusyProvider.google.storageValue,
          providerCalendarId: 'primary',
          summary: 'Imported calendar',
          accessRole: const Value('owner'),
          createdAtLocal: 1,
          updatedAtLocal: 1,
        ),
      );
  final calendarRepository = CalendarRepository(
    database: database,
    now: () => now.toUtc(),
    onNotificationScheduleChanged: () async {},
  );
  final importService = IcalImportService(
    database: database,
    calendarRepository: calendarRepository,
  );
  final preview = importService.parsePreview(
    utf8.encode('''BEGIN:VCALENDAR\r
VERSION:2.0\r
PRODID:-//BusyMax Remembered Coordinate Test//EN\r
BEGIN:VEVENT\r
UID:geo-only-interface-test\r
DTSTART:${_icalUtc(start)}\r
DTEND:${_icalUtc(end)}\r
SUMMARY:$_title\r
GEO:0;-123.12\r
END:VEVENT\r
END:VCALENDAR\r
'''),
  );
  final report = await importService.importPreview(
    preview: preview,
    destination: (await importService.writableDestinations()).single,
  );
  expect(report.queued, 1);
  final event = await database.select(database.calendarEvents).getSingle();
  expect(event.location, isNull);
  expect(event.locationLatitude, isNull);
  expect(event.locationLongitude, isNull);
  final resolution = await database
      .select(database.locationResolutions)
      .getSingle();
  expect(resolution.locationText, '');
  expect(resolution.latitude, 0);
  expect(resolution.longitude, -123.12);
  return _ImportHarness(
    database: database,
    calendarRepository: calendarRepository,
    account: const AccountEntity(
      id: _accountId,
      provider: BusyProvider.google,
      authority: 'https://accounts.google.com',
      providerAccountId: 'geo-only@example.test',
      authState: accountAuthStateSignedIn,
      email: 'geo-only@example.test',
      tasksEnabled: false,
    ),
  );
}

String _icalUtc(DateTime value) {
  final utc = value.toUtc();
  String two(int part) => part.toString().padLeft(2, '0');
  return '${utc.year}${two(utc.month)}${two(utc.day)}T'
      '${two(utc.hour)}${two(utc.minute)}${two(utc.second)}Z';
}

Future<Map<String, Object?>> _databaseSnapshot(AppDatabase database) async => {
  'accounts': [
    for (final row in await database.select(database.accounts).get())
      row.toJson(),
  ],
  'sources': [
    for (final row in await database.select(database.calendarSources).get())
      row.toJson(),
  ],
  'events': [
    for (final row in await database.select(database.calendarEvents).get())
      row.toJson(),
  ],
  'resolutions': [
    for (final row in await database.select(database.locationResolutions).get())
      row.toJson(),
  ],
  'pendingOperations': [
    for (final row in await database.select(database.pendingOps).get())
      row.toJson(),
  ],
  'importReceipts': [
    for (final row in await database.select(database.icalImportReceipts).get())
      row.toJson(),
  ],
  'attendees': [
    for (final row
        in await database.select(database.calendarEventAttendees).get())
      row.toJson(),
  ],
  'reminders': [
    for (final row
        in await database.select(database.calendarEventReminders).get())
      row.toJson(),
  ],
  'notifications': [
    for (final row
        in await database.select(database.notificationSchedule).get())
      row.toJson(),
  ],
};

final class _ImportHarness {
  const _ImportHarness({
    required this.database,
    required this.calendarRepository,
    required this.account,
  });

  final AppDatabase database;
  final CalendarRepository calendarRepository;
  final AccountEntity account;
}

const _accountId = 'google:geo-only-interface';
const _sourceId = 'google:geo-only-calendar';
const _title = 'Coordinate-only imported event';

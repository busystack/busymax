import 'package:busymax/src/calendar_providers/calendar_sync_dto.dart';
import 'package:busymax/src/db/app_database.dart';
import 'package:busymax/src/features/calendar/data/calendar_repository.dart';
import 'package:busymax/src/features/maps/data/location_resolution_repository.dart';
import 'package:busymax/src/features/maps/application/external_location_launcher.dart';
import 'package:busymax/src/features/maps/application/location_destination_resolver.dart';
import 'package:busymax/src/features/maps/domain/geographic_point.dart';
import 'package:busymax/src/features/maps/domain/location_result.dart';
import 'package:busymax/src/providers/busy_provider.dart';
import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:url_launcher/url_launcher.dart';

void main() {
  late AppDatabase database;
  late CalendarRepository calendars;

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    calendars = CalendarRepository(database: database);
    await _account(database, 'account-a');
    await _account(database, 'account-b');
    await _source(calendars, 'account-a', 'provider-a', 'Calendar A');
    await _source(calendars, 'account-b', 'provider-b', 'Calendar B');
    await _event(calendars, 'account-a', 'provider-a', 'event-a', 'Hall');
    await _event(calendars, 'account-b', 'provider-b', 'event-b', 'Hall');
  });

  tearDown(() => database.close());

  test(
    'survives repository restart and remains isolated by complete identity',
    () async {
      final first = LocationResolutionRepository(database);
      final identity = _identity(
        account: 'account-a',
        source: _sourceId('account-a', 'provider-a'),
        event: _eventId('account-a', 'provider-a', 'event-a'),
      );
      await first.apply(identity, 'Hall', LocationChange.replace(_selection));

      final reopened = LocationResolutionRepository(database);
      expect(await reopened.load(identity, 'Hall'), _matchesStoredSelection);
      expect(await reopened.load(identity, 'Different snapshot'), isNull);
      expect(
        await reopened.load(
          _identity(
            account: 'account-b',
            source: _sourceId('account-b', 'provider-b'),
            event: _eventId('account-b', 'provider-b', 'event-b'),
          ),
          'Hall',
        ),
        isNull,
      );
    },
  );

  test(
    'saved resolver applies link, native, remembered, then text priority',
    () async {
      final identity = _identity(
        account: 'account-a',
        source: _sourceId('account-a', 'provider-a'),
        event: _eventId('account-a', 'provider-a', 'event-a'),
      );
      final repository = LocationResolutionRepository(database);
      await repository.apply(
        identity,
        'Hall',
        LocationChange.replace(_selection),
      );
      final resolver = LocationDestinationResolver(repository);
      final native = GeographicPoint(latitude: -1, longitude: 0);

      final link = await resolver.resolveSaved(
        location: 'https://intranet/room?q=A%26B#floor',
        nativePoint: native,
        identity: identity,
      );
      expect(link?.kind, ExternalLocationDestinationKind.link);
      expect(link?.link?.fragment, 'floor');

      final providerPoint = await resolver.resolveSaved(
        location: 'Hall',
        nativePoint: native,
        identity: identity,
      );
      expect(providerPoint?.kind, ExternalLocationDestinationKind.coordinates);
      expect(providerPoint?.point, native);

      final remembered = await resolver.resolveSaved(
        location: 'Hall',
        identity: identity,
      );
      expect(remembered?.point, _selection.point);

      final text = await resolver.resolveSaved(location: 'Unresolved room');
      expect(text?.kind, ExternalLocationDestinationKind.text);
      expect(text?.text, 'Unresolved room');
      expect(await resolver.resolveSaved(location: '   '), isNull);
    },
  );

  test(
    'resolving and opening a saved location performs no database writes',
    () async {
      final identity = _identity(
        account: 'account-a',
        source: _sourceId('account-a', 'provider-a'),
        event: _eventId('account-a', 'provider-a', 'event-a'),
      );
      final repository = LocationResolutionRepository(database);
      await repository.apply(
        identity,
        'Hall',
        LocationChange.replace(_selection),
      );
      final eventsBefore = await database.select(database.calendarEvents).get();
      final resolutionsBefore = await database
          .select(database.locationResolutions)
          .get();
      final pendingBefore = await database.select(database.pendingOps).get();
      final launched = <Uri>[];

      final destination = await LocationDestinationResolver(
        repository,
      ).resolveSaved(location: 'Hall', identity: identity);
      final result = await ExternalLocationLauncher(
        platform: () => ExternalLocationPlatform.windows,
        launcher: (uri, {mode = LaunchMode.platformDefault}) async {
          launched.add(uri);
          return true;
        },
      ).open(destination);

      expect(result, ExternalLocationLaunchResult.opened);
      expect(launched, hasLength(1));
      expect(
        await database.select(database.calendarEvents).get(),
        eventsBefore,
      );
      expect(
        await database.select(database.locationResolutions).get(),
        resolutionsBefore,
      );
      expect(await database.select(database.pendingOps).get(), pendingBefore);
    },
  );

  test('remembered provenance remains explicit after restart', () async {
    final identity = _identity(
      account: 'account-a',
      source: _sourceId('account-a', 'provider-a'),
      event: _eventId('account-a', 'provider-a', 'event-a'),
    );
    final coarse = LocationResult(
      label: 'Vancouver, BC, Canada',
      point: GeographicPoint(latitude: 49.2827, longitude: -123.1207),
      source: 'legacy-provider',
      attribution: 'City result attribution',
    );
    await LocationResolutionRepository(
      database,
    ).apply(identity, 'Hall', LocationChange.replace(coarse));

    final remembered = await LocationResolutionRepository(
      database,
    ).load(identity, 'Hall');

    expect(remembered?.source, 'legacy-provider');
    expect(remembered?.attribution, 'City result attribution');
  });

  test('late result is rejected after location text changes', () async {
    final repository = LocationResolutionRepository(database);
    final identity = _identity(
      account: 'account-a',
      source: _sourceId('account-a', 'provider-a'),
      event: _eventId('account-a', 'provider-a', 'event-a'),
    );
    await (database.update(database.calendarEvents)
          ..where((row) => row.id.equals(identity.itemId)))
        .write(const CalendarEventsCompanion(location: Value('New hall')));

    await repository.apply(
      identity,
      'Hall',
      LocationChange.replace(_selection),
    );
    expect(await repository.load(identity, 'Hall'), isNull);
  });

  test('location changes and deletion invalidate remembered data', () async {
    final repository = LocationResolutionRepository(database);
    final identity = _identity(
      account: 'account-a',
      source: _sourceId('account-a', 'provider-a'),
      event: _eventId('account-a', 'provider-a', 'event-a'),
    );
    await repository.apply(
      identity,
      'Hall',
      LocationChange.replace(_selection),
    );
    await (database.update(database.calendarEvents)
          ..where((row) => row.id.equals(identity.itemId)))
        .write(const CalendarEventsCompanion(location: Value('Other')));
    expect(await database.select(database.locationResolutions).get(), isEmpty);

    await (database.update(database.calendarEvents)
          ..where((row) => row.id.equals(identity.itemId)))
        .write(const CalendarEventsCompanion(location: Value('Hall')));
    await repository.apply(
      identity,
      'Hall',
      LocationChange.replace(_selection),
    );
    await (database.delete(
      database.calendarEvents,
    )..where((row) => row.id.equals(identity.itemId))).go();
    expect(await database.select(database.locationResolutions).get(), isEmpty);
  });

  test(
    'identity reconciliation follows the owner without text matching others',
    () async {
      final repository = LocationResolutionRepository(database);
      final old = _identity(
        account: 'account-a',
        source: _sourceId('account-a', 'provider-a'),
        event: _eventId('account-a', 'provider-a', 'event-a'),
      );
      await repository.apply(old, 'Hall', LocationChange.replace(_selection));
      const newId = 'provider-reconciled-event-id';
      await (database.update(database.calendarEvents)
            ..where((row) => row.id.equals(old.itemId)))
          .write(const CalendarEventsCompanion(id: Value(newId)));

      final replacement = LocationItemIdentity(
        kind: LocationItemKind.event,
        accountId: old.accountId,
        sourceId: old.sourceId,
        itemId: newId,
      );
      expect(await repository.load(old, 'Hall'), isNull);
      expect(
        await repository.load(replacement, 'Hall'),
        _matchesStoredSelection,
      );
    },
  );

  test(
    'supports a coordinate-only owner without inventing location text',
    () async {
      final identity = _identity(
        account: 'account-a',
        source: _sourceId('account-a', 'provider-a'),
        event: _eventId('account-a', 'provider-a', 'event-a'),
      );
      await (database.update(database.calendarEvents)
            ..where((row) => row.id.equals(identity.itemId)))
          .write(const CalendarEventsCompanion(location: Value('')));
      final repository = LocationResolutionRepository(database);
      await repository.apply(identity, '', LocationChange.replace(_selection));

      expect(await repository.load(identity, ''), _matchesStoredSelection);
    },
  );
}

final _selection = LocationResult(
  label: 'Resolved Hall',
  point: GeographicPoint(latitude: 0, longitude: -123.25),
  source: 'geoapify',
  attribution: 'Geoapify attribution',
);

final _matchesStoredSelection = isA<LocationResult>()
    .having((result) => result.label, 'label', _selection.label)
    .having((result) => result.point, 'point', _selection.point)
    .having((result) => result.source, 'source', _selection.source)
    .having(
      (result) => result.attribution,
      'attribution',
      _selection.attribution,
    );

LocationItemIdentity _identity({
  required String account,
  required String source,
  required String event,
}) => LocationItemIdentity(
  kind: LocationItemKind.event,
  accountId: account,
  sourceId: source,
  itemId: event,
);

String _sourceId(String account, String providerCalendarId) =>
    CalendarRepository.sourceId(
      accountId: account,
      provider: BusyProvider.google,
      providerCalendarId: providerCalendarId,
    );

String _eventId(String account, String providerCalendarId, String event) =>
    CalendarRepository.eventId(
      accountId: account,
      provider: BusyProvider.google,
      providerCalendarId: providerCalendarId,
      providerEventId: event,
    );

Future<void> _account(AppDatabase database, String id) => database
    .into(database.accounts)
    .insert(
      AccountsCompanion.insert(
        id: id,
        provider: 'google',
        authority: 'https://accounts.google.com',
        providerAccountId: id,
        credentialKind: 'oauth',
        authState: const Value('signed_in'),
        grantedScopes: const Value(''),
        createdAtUtc: '2026-09-01T00:00:00.000Z',
        updatedAtUtc: '2026-09-01T00:00:00.000Z',
      ),
    );

Future<void> _source(
  CalendarRepository repository,
  String account,
  String providerCalendarId,
  String title,
) => repository.upsertSource(
  accountId: account,
  source: CalendarSourceDto(
    provider: BusyProvider.google,
    providerCalendarId: providerCalendarId,
    summary: title,
  ),
);

Future<void> _event(
  CalendarRepository repository,
  String account,
  String providerCalendarId,
  String providerEventId,
  String location,
) => repository.upsertEvent(
  accountId: account,
  event: CalendarEventDto(
    provider: BusyProvider.google,
    providerCalendarId: providerCalendarId,
    providerEventId: providerEventId,
    title: 'Event',
    location: location,
    startDateTime: '2026-09-01T10:00:00.000Z',
    endDateTime: '2026-09-01T11:00:00.000Z',
    updatedAtServer: '2026-09-01T00:00:00.000Z',
    rawJson: {'id': providerEventId, 'location': location},
  ),
);

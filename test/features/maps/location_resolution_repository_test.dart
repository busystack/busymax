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

  test(
    'capture starts from sparse supplemental rows and is account scoped',
    () async {
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
      await _event(
        calendars,
        'account-a',
        'provider-a',
        'event-without-supplement',
        'Hall',
      );

      final captured = await repository.capture(
        accountId: 'account-a',
        eventSourceId: identity.sourceId,
      );
      final otherAccount = await repository.capture(
        accountId: 'account-b',
        eventSourceId: _sourceId('account-b', 'provider-b'),
      );

      expect(captured, hasLength(1));
      expect(captured.single.item, identity);
      expect(captured.single.selection, _matchesStoredSelection);
      expect(otherAccount, isEmpty);
    },
  );

  test('capture rejects absent and ambiguous scopes', () async {
    final repository = LocationResolutionRepository(database);

    await expectLater(
      repository.capture(accountId: 'account-a'),
      throwsArgumentError,
    );
    await expectLater(
      repository.capture(
        accountId: 'account-a',
        davObjectId: 'object',
        eventSourceId: _sourceId('account-a', 'provider-a'),
      ),
      throwsArgumentError,
    );
  });

  test(
    'restore follows one stable iCalendar identity and keeps provenance',
    () async {
      final repository = LocationResolutionRepository(database);
      final sourceId = _sourceId('account-a', 'provider-a');
      final old = _identity(
        account: 'account-a',
        source: sourceId,
        event: _eventId('account-a', 'provider-a', 'event-a'),
      );
      await (database.update(database.calendarEvents)
            ..where((row) => row.id.equals(old.itemId)))
          .write(const CalendarEventsCompanion(icalUid: Value('uid-1')));
      await repository.apply(old, 'Hall', LocationChange.replace(_selection));
      final captured = await repository.capture(
        accountId: 'account-a',
        eventSourceId: sourceId,
      );
      await (database.delete(
        database.calendarEvents,
      )..where((row) => row.id.equals(old.itemId))).go();
      await _event(calendars, 'account-a', 'provider-a', 'replacement', 'Hall');
      final replacement = _identity(
        account: 'account-a',
        source: sourceId,
        event: _eventId('account-a', 'provider-a', 'replacement'),
      );
      await (database.update(database.calendarEvents)
            ..where((row) => row.id.equals(replacement.itemId)))
          .write(const CalendarEventsCompanion(icalUid: Value('uid-1')));

      await repository.restore(
        captured,
        accountId: 'account-a',
        sourceId: sourceId,
      );

      expect(
        await repository.load(replacement, 'Hall'),
        _matchesStoredSelection,
      );
      expect(await repository.load(old, 'Hall'), isNull);
    },
  );

  test('restore rejects a changed location snapshot', () async {
    final repository = LocationResolutionRepository(database);
    final sourceId = _sourceId('account-a', 'provider-a');
    final old = _identity(
      account: 'account-a',
      source: sourceId,
      event: _eventId('account-a', 'provider-a', 'event-a'),
    );
    await (database.update(database.calendarEvents)
          ..where((row) => row.id.equals(old.itemId)))
        .write(const CalendarEventsCompanion(icalUid: Value('uid-changed')));
    await repository.apply(old, 'Hall', LocationChange.replace(_selection));
    final captured = await repository.capture(
      accountId: 'account-a',
      eventSourceId: sourceId,
    );
    await (database.delete(
      database.calendarEvents,
    )..where((row) => row.id.equals(old.itemId))).go();
    await _event(
      calendars,
      'account-a',
      'provider-a',
      'replacement',
      'Different hall',
    );
    final replacement = _identity(
      account: 'account-a',
      source: sourceId,
      event: _eventId('account-a', 'provider-a', 'replacement'),
    );
    await (database.update(database.calendarEvents)
          ..where((row) => row.id.equals(replacement.itemId)))
        .write(const CalendarEventsCompanion(icalUid: Value('uid-changed')));

    await repository.restore(
      captured,
      accountId: 'account-a',
      sourceId: sourceId,
    );

    expect(await repository.load(replacement, 'Different hall'), isNull);
    expect(await database.select(database.locationResolutions).get(), isEmpty);
  });

  test(
    'restore does not match replacement owners through null identity',
    () async {
      final repository = LocationResolutionRepository(database);
      final sourceId = _sourceId('account-a', 'provider-a');
      final old = _identity(
        account: 'account-a',
        source: sourceId,
        event: _eventId('account-a', 'provider-a', 'event-a'),
      );
      await repository.apply(old, 'Hall', LocationChange.replace(_selection));
      final captured = await repository.capture(
        accountId: 'account-a',
        eventSourceId: sourceId,
      );
      await (database.delete(
        database.calendarEvents,
      )..where((row) => row.id.equals(old.itemId))).go();
      await _event(calendars, 'account-a', 'provider-a', 'replacement', 'Hall');
      final replacement = _identity(
        account: 'account-a',
        source: sourceId,
        event: _eventId('account-a', 'provider-a', 'replacement'),
      );

      await repository.restore(
        captured,
        accountId: 'account-a',
        sourceId: sourceId,
      );

      expect(await repository.load(replacement, 'Hall'), isNull);
      expect(
        await database.select(database.locationResolutions).get(),
        isEmpty,
      );
    },
  );

  test('DAV task supplement follows one replacement task owner', () async {
    await _davScope(database);
    const old = LocationItemIdentity(
      kind: LocationItemKind.task,
      accountId: 'dav-account',
      sourceId: 'dav-task-list',
      itemId: 'old-task',
    );
    await _task(
      database,
      id: old.itemId,
      uid: 'task-uid',
      location: 'Head office',
    );
    final repository = LocationResolutionRepository(database);
    final imported = LocationResult(
      label: '123 Resolved Avenue',
      point: GeographicPoint(latitude: 48.42, longitude: -123.36),
      source: 'legacy-import',
      attribution: 'Original import attribution',
    );
    await repository.apply(
      old,
      'Head office',
      LocationChange.replace(imported),
    );

    final captured = await repository.capture(
      accountId: 'dav-account',
      davObjectId: 'dav-object',
    );
    await (database.delete(
      database.tasks,
    )..where((row) => row.id.equals(old.itemId))).go();
    await _task(
      database,
      id: 'replacement-task',
      uid: 'task-uid',
      location: 'Head office',
    );
    await repository.restore(
      captured,
      accountId: 'dav-account',
      sourceId: 'dav-task-list',
      davObjectId: 'dav-object',
    );

    const replacement = LocationItemIdentity(
      kind: LocationItemKind.task,
      accountId: 'dav-account',
      sourceId: 'dav-task-list',
      itemId: 'replacement-task',
    );
    expect(await repository.load(replacement, 'Head office'), imported);
    final rows = await database.select(database.locationResolutions).get();
    expect(rows, hasLength(1));
    expect(rows.single.itemId, replacement.itemId);
  });

  test(
    'recurrence restore keeps supplements on their exact occurrence',
    () async {
      final repository = LocationResolutionRepository(database);
      final sourceId = _sourceId('account-a', 'provider-a');
      final first = _identity(
        account: 'account-a',
        source: sourceId,
        event: _eventId('account-a', 'provider-a', 'event-a'),
      );
      await _event(
        calendars,
        'account-a',
        'provider-a',
        'event-second',
        'Hall',
      );
      final second = _identity(
        account: 'account-a',
        source: sourceId,
        event: _eventId('account-a', 'provider-a', 'event-second'),
      );
      await _makeOccurrence(database, first.itemId, '20260901T100000Z');
      await _makeOccurrence(database, second.itemId, '20260908T100000Z');
      final firstPoint = LocationResult(
        label: 'First occurrence',
        point: GeographicPoint(latitude: 1, longitude: 2),
        source: 'existing',
      );
      final secondPoint = LocationResult(
        label: 'Second occurrence',
        point: GeographicPoint(latitude: 3, longitude: 4),
        source: 'existing',
      );
      await repository.apply(first, 'Hall', LocationChange.replace(firstPoint));
      await repository.apply(
        second,
        'Hall',
        LocationChange.replace(secondPoint),
      );
      final captured = await repository.capture(
        accountId: 'account-a',
        eventSourceId: sourceId,
      );
      await (database.delete(
        database.calendarEvents,
      )..where((row) => row.id.isIn([first.itemId, second.itemId]))).go();
      await _event(
        calendars,
        'account-a',
        'provider-a',
        'replacement-first',
        'Hall',
      );
      await _event(
        calendars,
        'account-a',
        'provider-a',
        'replacement-second',
        'Hall',
      );
      final replacementFirst = _identity(
        account: 'account-a',
        source: sourceId,
        event: _eventId('account-a', 'provider-a', 'replacement-first'),
      );
      final replacementSecond = _identity(
        account: 'account-a',
        source: sourceId,
        event: _eventId('account-a', 'provider-a', 'replacement-second'),
      );
      await _makeOccurrence(
        database,
        replacementFirst.itemId,
        '20260901T100000Z',
      );
      await _makeOccurrence(
        database,
        replacementSecond.itemId,
        '20260908T100000Z',
      );

      await repository.restore(
        captured,
        accountId: 'account-a',
        sourceId: sourceId,
      );

      expect(await repository.load(replacementFirst, 'Hall'), firstPoint);
      expect(await repository.load(replacementSecond, 'Hall'), secondPoint);
    },
  );

  test(
    'Google series source is scoped and respects occurrence exceptions',
    () async {
      const providerSeriesId = 'imported-series';
      await calendars.upsertEvent(
        accountId: 'account-a',
        event: const CalendarEventDto(
          provider: BusyProvider.google,
          providerCalendarId: 'provider-a',
          providerEventId: providerSeriesId,
          title: 'Imported series',
          location: 'Hall',
          startDateTime: '2026-09-01T10:00:00.000Z',
          endDateTime: '2026-09-01T11:00:00.000Z',
          recurrenceJson: ['RRULE:FREQ=WEEKLY'],
        ),
      );
      final masterId = _eventId('account-a', 'provider-a', providerSeriesId);
      final repository = LocationResolutionRepository(database);
      await repository.apply(
        _identity(
          account: 'account-a',
          source: _sourceId('account-a', 'provider-a'),
          event: masterId,
        ),
        'Hall',
        LocationChange.replace(_selection),
      );
      final master = await (database.select(
        database.calendarEvents,
      )..where((row) => row.id.equals(masterId))).getSingle();
      await repository.reconcileGoogleSeriesMaster(master);

      Future<LocationItemIdentity> occurrence({
        required String account,
        required String calendar,
        required String id,
        required String location,
        bool cancelled = false,
        String start = '2026-09-08T10:00:00.000Z',
        String originalStart = '2026-09-08T10:00:00.000Z',
      }) async {
        await calendars.upsertEvent(
          accountId: account,
          event: CalendarEventDto(
            provider: BusyProvider.google,
            providerCalendarId: calendar,
            providerEventId: id,
            providerRecurringEventId: providerSeriesId,
            providerOriginalStartKey: originalStart,
            title: 'Occurrence',
            location: location,
            startDateTime: start,
            endDateTime: DateTime.parse(
              start,
            ).add(const Duration(hours: 1)).toIso8601String(),
            isCancelled: cancelled,
          ),
        );
        return _identity(
          account: account,
          source: _sourceId(account, calendar),
          event: CalendarRepository.eventId(
            accountId: account,
            provider: BusyProvider.google,
            providerCalendarId: calendar,
            providerEventId: id,
            providerOriginalStartKey: originalStart,
          ),
        );
      }

      final normal = await occurrence(
        account: 'account-a',
        calendar: 'provider-a',
        id: 'normal',
        location: 'Hall',
      );
      final moved = await occurrence(
        account: 'account-a',
        calendar: 'provider-a',
        id: 'moved',
        location: 'Hall',
        start: '2026-09-10T10:00:00.000Z',
        originalStart: '2026-09-15T10:00:00.000Z',
      );
      final changed = await occurrence(
        account: 'account-a',
        calendar: 'provider-a',
        id: 'changed',
        location: 'Other hall',
      );
      final cleared = await occurrence(
        account: 'account-a',
        calendar: 'provider-a',
        id: 'cleared',
        location: '',
      );
      final cancelled = await occurrence(
        account: 'account-a',
        calendar: 'provider-a',
        id: 'cancelled',
        location: 'Hall',
        cancelled: true,
      );
      final otherAccount = await occurrence(
        account: 'account-b',
        calendar: 'provider-b',
        id: 'other-account',
        location: 'Hall',
      );
      final exact = await occurrence(
        account: 'account-a',
        calendar: 'provider-a',
        id: 'exact',
        location: 'Hall',
      );
      final exactSelection = LocationResult(
        label: 'Occurrence exception',
        point: GeographicPoint(latitude: 1, longitude: 2),
        source: 'ical-exception',
      );
      await repository.apply(
        exact,
        'Hall',
        LocationChange.replace(exactSelection),
      );

      expect(await repository.load(normal, 'Hall'), _matchesStoredSelection);
      expect(await repository.load(moved, 'Hall'), _matchesStoredSelection);
      expect(await repository.load(changed, 'Other hall'), isNull);
      expect(await repository.load(cleared, ''), isNull);
      expect(await repository.load(cancelled, 'Hall'), isNull);
      expect(await repository.load(otherAccount, 'Hall'), isNull);
      expect(await repository.load(exact, 'Hall'), exactSelection);

      await (database.update(database.calendarEvents)
            ..where((row) => row.id.equals(masterId)))
          .write(const CalendarEventsCompanion(isDeleted: Value(true)));
      expect(await repository.load(normal, 'Hall'), _matchesStoredSelection);

      await calendars.upsertEvent(
        accountId: 'account-a',
        event: const CalendarEventDto(
          provider: BusyProvider.google,
          providerCalendarId: 'provider-a',
          providerEventId: providerSeriesId,
          title: 'Deleted series',
          location: 'Hall',
          isDeleted: true,
        ),
      );
      expect(await repository.load(normal, 'Hall'), isNull);
    },
  );

  test('coordinate-only Google series remains reachable', () async {
    const providerSeriesId = 'coordinate-only-series';
    await calendars.upsertEvent(
      accountId: 'account-a',
      event: const CalendarEventDto(
        provider: BusyProvider.google,
        providerCalendarId: 'provider-a',
        providerEventId: providerSeriesId,
        title: 'Coordinate-only import',
        location: '',
        startDateTime: '2026-09-01T10:00:00.000Z',
        endDateTime: '2026-09-01T11:00:00.000Z',
        recurrenceJson: ['RRULE:FREQ=WEEKLY'],
      ),
    );
    final masterId = _eventId('account-a', 'provider-a', providerSeriesId);
    final repository = LocationResolutionRepository(database);
    await repository.apply(
      _identity(
        account: 'account-a',
        source: _sourceId('account-a', 'provider-a'),
        event: masterId,
      ),
      '',
      LocationChange.replace(_selection),
    );
    await repository.reconcileGoogleSeriesMaster(
      await (database.select(
        database.calendarEvents,
      )..where((row) => row.id.equals(masterId))).getSingle(),
    );
    await calendars.upsertEvent(
      accountId: 'account-a',
      event: const CalendarEventDto(
        provider: BusyProvider.google,
        providerCalendarId: 'provider-a',
        providerEventId: 'coordinate-only-occurrence',
        providerRecurringEventId: providerSeriesId,
        providerOriginalStartKey: '2026-09-08T10:00:00.000Z',
        title: 'Coordinate-only occurrence',
        location: '',
        startDateTime: '2026-09-08T10:00:00.000Z',
        endDateTime: '2026-09-08T11:00:00.000Z',
      ),
    );
    final occurrence = _identity(
      account: 'account-a',
      source: _sourceId('account-a', 'provider-a'),
      event: CalendarRepository.eventId(
        accountId: 'account-a',
        provider: BusyProvider.google,
        providerCalendarId: 'provider-a',
        providerEventId: 'coordinate-only-occurrence',
        providerOriginalStartKey: '2026-09-08T10:00:00.000Z',
      ),
    );

    final destination = await LocationDestinationResolver(
      repository,
    ).resolveSaved(location: '', identity: occurrence);

    expect(destination?.point, _selection.point);
  });

  test('provider-deleted Google calendar removes series metadata', () async {
    final sourceId = _sourceId('account-a', 'provider-a');
    await database
        .into(database.locationResolutions)
        .insert(
          LocationResolutionsCompanion.insert(
            kind: googleSeriesLocationResolutionKind,
            accountId: 'account-a',
            sourceId: sourceId,
            itemId: 'series-to-remove',
            locationText: 'Hall',
            label: _selection.label,
            latitude: _selection.point.latitude,
            longitude: _selection.point.longitude,
            source: _selection.source,
            attribution: _selection.attribution,
          ),
        );

    await calendars.upsertSource(
      accountId: 'account-a',
      source: const CalendarSourceDto(
        provider: BusyProvider.google,
        providerCalendarId: 'provider-a',
        summary: 'Deleted remotely',
        isDeleted: true,
      ),
    );

    expect(
      await (database.select(database.locationResolutions)..where(
            (row) => row.kind.equals(googleSeriesLocationResolutionKind),
          ))
          .get(),
      isEmpty,
    );
  });
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

Future<void> _davScope(AppDatabase database) async {
  const now = '2026-09-01T00:00:00.000Z';
  await database
      .into(database.accounts)
      .insert(
        AccountsCompanion.insert(
          id: 'dav-account',
          provider: 'nextcloud',
          authority: 'https://cloud.example.test',
          providerAccountId: 'alex',
          credentialKind: 'nextcloud_app_password',
          authState: const Value('signed_in'),
          createdAtUtc: now,
          updatedAtUtc: now,
        ),
      );
  await database
      .into(database.davCollections)
      .insert(
        DavCollectionsCompanion.insert(
          id: 'dav-collection',
          accountId: 'dav-account',
          hrefKey: '/calendars/alex/tasks/',
          requestUri: 'https://cloud.example.test/calendars/alex/tasks/',
          displayName: 'Tasks',
          supportedComponentMask: const Value(2),
          currentUserPrivilegesJson: const Value('["{DAV:}write"]'),
          readOnly: const Value(false),
          taskProjectionEnabled: const Value(true),
          createdAtUtc: now,
          updatedAtUtc: now,
        ),
      );
  await database.taskListsDao.upsertTaskList(
    TaskListsCompanion.insert(
      accountId: 'dav-account',
      id: 'dav-task-list',
      davCollectionId: const Value('dav-collection'),
      title: 'Tasks',
      rawJson: '{}',
      createdLocalAtUtc: now,
      updatedLocalAtUtc: now,
    ),
  );
  await database
      .into(database.davObjects)
      .insert(
        DavObjectsCompanion.insert(
          id: 'dav-object',
          accountId: 'dav-account',
          collectionId: 'dav-collection',
          hrefKey: '/calendars/alex/tasks/task.ics',
          requestUri:
              'https://cloud.example.test/calendars/alex/tasks/task.ics',
          rawIcsBody: 'BEGIN:VCALENDAR\r\nEND:VCALENDAR\r\n',
          rawBodyHash: 'hash',
          firstSeenAtUtc: now,
          lastFetchedAtUtc: now,
          lastChangedAtUtc: now,
        ),
      );
}

Future<void> _task(
  AppDatabase database, {
  required String id,
  required String uid,
  required String location,
}) => database.tasksDao.upsertTask(
  TasksCompanion.insert(
    accountId: 'dav-account',
    taskListId: 'dav-task-list',
    id: id,
    davCollectionId: const Value('dav-collection'),
    davObjectId: const Value('dav-object'),
    icalUid: Value(uid),
    taskLocation: Value(location),
    title: 'Task',
    rawJson: '{}',
    createdLocalAtUtc: '2026-09-01T00:00:00.000Z',
    updatedLocalAtUtc: '2026-09-01T00:00:00.000Z',
  ),
);

Future<void> _makeOccurrence(
  AppDatabase database,
  String eventId,
  String occurrence,
) =>
    (database.update(
      database.calendarEvents,
    )..where((row) => row.id.equals(eventId))).write(
      CalendarEventsCompanion(
        icalUid: const Value('series-uid'),
        providerRecurringEventId: const Value('series-master'),
        occurrenceKey: Value(occurrence),
      ),
    );

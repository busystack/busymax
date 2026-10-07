import 'dart:async';
import 'dart:convert';

import 'package:busymax/src/app/app_bootstrap.dart';
import 'package:busymax/src/calendar_providers/calendar_provider_capabilities.dart';
import 'package:busymax/src/calendar_providers/calendar_sync_dto.dart';
import 'package:busymax/src/calendar_providers/cloud_calendar_client.dart';
import 'package:busymax/src/core/auth/authorization_attempt.dart';
import 'package:busymax/src/db/app_database.dart';
import 'package:busymax/src/features/calendar/data/calendar_repository.dart';
import 'package:busymax/src/features/calendar/data/microsoft_shared_calendar_service.dart';
import 'package:busymax/src/features/connectivity/network_connectivity_service.dart';
import 'package:busymax/src/features/notifications/notification_reconciler.dart';
import 'package:busymax/src/features/sync/account_sync_operations.dart';
import 'package:busymax/src/features/sync/calendar_sync_engine.dart';
import 'package:busymax/src/microsoft_calendar/microsoft_calendar_api_client.dart';
import 'package:busymax/src/microsoft_calendar/microsoft_shared_calendar_address.dart';
import 'package:busymax/src/microsoft_todo/oauth/microsoft_oauth_service.dart';
import 'package:busymax/src/providers/busy_provider.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test(
    'range retrieval completes before a newer baseline sync imports events',
    () async {
      final fixture = await _Fixture.create();
      addTearDown(fixture.dispose);
      fixture.client.holdRange = true;

      final coverage = fixture.container.read(
        cloudCalendarRangeCoverageServiceProvider,
      );
      final range = fixture.track(
        coverage.ensureRange(fixture.month, fixture.nextMonth),
      );
      await fixture.client.rangeStarted.future.timeout(
        const Duration(seconds: 2),
      );
      final sync = fixture.track(
        fixture.container
            .read(accountSyncOperationsProvider)
            .syncCalendar(_accountId, full: true),
      );
      await _waitFor(() => fixture.gate.accountIds.length == 2);
      final baselineStartedBeforeRangeCompleted =
          fixture.client.syncStarted.isCompleted;

      fixture.client.releaseRange.complete();
      expect(await range, isTrue);
      await sync;

      expect(baselineStartedBeforeRangeCompleted, isFalse);
      expect(fixture.gate.accountIds, [_accountId, _accountId]);
      final events = await fixture.database
          .select(fixture.database.calendarEvents)
          .get();
      expect(events, hasLength(1));
      expect(
        events.single.providerEventId,
        fixture.client.event.providerEventId,
      );
      expect(events.single.isDeleted, isFalse);
    },
  );

  test('range retrieval waits for an in-flight baseline sync', () async {
    final fixture = await _Fixture.create();
    addTearDown(fixture.dispose);
    fixture.client.holdSync = true;
    fixture.client.rangeEvents = [fixture.client.event];

    final sync = fixture.track(
      fixture.container
          .read(accountSyncOperationsProvider)
          .syncCalendar(_accountId, full: true),
    );
    await fixture.client.syncStarted.future.timeout(const Duration(seconds: 2));
    final range = fixture.track(
      fixture.container
          .read(cloudCalendarRangeCoverageServiceProvider)
          .ensureRange(fixture.month, fixture.nextMonth),
    );
    await _waitFor(() => fixture.gate.accountIds.length == 2);
    final rangeStartedBeforeBaselineCompleted =
        fixture.client.rangeStarted.isCompleted;

    fixture.client.releaseSync.complete();
    await sync;
    expect(await range, isTrue);

    expect(rangeStartedBeforeBaselineCompleted, isFalse);
    expect(fixture.gate.accountIds, [_accountId, _accountId]);
    final events = await fixture.database
        .select(fixture.database.calendarEvents)
        .get();
    expect(events, hasLength(1));
    expect(events.single.isDeleted, isFalse);
  });

  test(
    'disabling calendars while range retrieval is queued prevents a fetch',
    () async {
      final fixture = await _Fixture.create();
      addTearDown(fixture.dispose);
      final coordinator = fixture.container.read(
        accountSyncCoordinatorProvider,
      );
      final block = Completer<void>();
      addTearDown(() {
        if (!block.isCompleted) block.complete();
      });
      final blocked = fixture.track(
        coordinator.run(_accountId, () => block.future),
      );

      final range = fixture.track(
        fixture.container
            .read(cloudCalendarRangeCoverageServiceProvider)
            .ensureRange(fixture.month, fixture.nextMonth),
      );
      await _waitFor(() => fixture.gate.accountIds.isNotEmpty);
      await (fixture.database.update(fixture.database.accounts)
            ..where((row) => row.id.equals(_accountId)))
          .write(const AccountsCompanion(calendarsEnabled: Value(false)));
      block.complete();
      await blocked;
      await range;

      expect(fixture.client.rangeCalendarIds, isEmpty);
      expect(
        await fixture.database.select(fixture.database.syncCursors).get(),
        isEmpty,
      );
    },
  );

  test(
    'opening a Microsoft shared calendar coordinates its initial range with sync',
    () async {
      final authorization = _SharedCalendarAuthorization();
      final discoveryHttp = MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.pathSegments, [
          'v1.0',
          'users',
          'owner@example.com',
          'calendar',
        ]);
        return http.Response(
          jsonEncode({
            'id': 'owner-calendar',
            'name': 'Owner calendar',
            'canEdit': true,
          }),
          200,
        );
      });
      addTearDown(discoveryHttp.close);
      final discovery = MicrosoftCalendarApiClient(
        httpClient: discoveryHttp,
        baseUri: Uri.parse('https://graph.microsoft.com/v1.0'),
        responseTimeZone: 'UTC',
      );
      final fixture = await _Fixture.create(
        provider: BusyProvider.microsoft,
        authorization: authorization,
        discovery: discovery,
      );
      addTearDown(fixture.dispose);
      fixture.client.holdSync = true;

      final sync = fixture.track(
        fixture.container
            .read(accountSyncOperationsProvider)
            .syncCalendar(_accountId, full: true),
      );
      await fixture.client.syncStarted.future.timeout(
        const Duration(seconds: 2),
      );
      final opening = fixture.track(
        fixture.container
            .read(microsoftSharedCalendarServiceProvider)
            .openPrimaryCalendar(
              accountId: _accountId,
              owner: 'owner@example.com',
            ),
      );
      await _waitFor(() => fixture.gate.accountIds.length == 2);
      final rangeStartedBeforeBaselineCompleted =
          fixture.client.rangeStarted.isCompleted;

      fixture.client.releaseSync.complete();
      await sync;
      final result = await opening;

      expect(result.outcome, MicrosoftSharedCalendarOpenOutcome.ready);
      expect(authorization.accounts, [_accountId]);
      expect(rangeStartedBeforeBaselineCompleted, isFalse);
      expect(fixture.gate.accountIds, [_accountId, _accountId]);
      final sharedId = const MicrosoftSharedPrimaryCalendarAddress(
        owner: 'owner@example.com',
        graphCalendarId: 'owner-calendar',
      ).sourceCalendarId;
      expect(fixture.client.rangeCalendarIds, [sharedId]);
      expect(
        result.sourceId,
        CalendarRepository.sourceId(
          accountId: _accountId,
          provider: BusyProvider.microsoft,
          providerCalendarId: sharedId,
        ),
      );
    },
  );
}

const _accountId = 'account';

final class _Fixture {
  _Fixture({
    required this.database,
    required this.container,
    required this.monitor,
    required this.client,
    required this.gate,
    required this.month,
  });

  final AppDatabase database;
  final ProviderContainer container;
  final NetworkConnectivityMonitor monitor;
  final _HeldCalendarClient client;
  final _RecordingAccountGate gate;
  final DateTime month;
  final List<Future<void>> _pending = [];

  DateTime get nextMonth => DateTime.utc(month.year, month.month + 1);

  static Future<_Fixture> create({
    BusyProvider provider = BusyProvider.google,
    _SharedCalendarAuthorization? authorization,
    MicrosoftCalendarApiClient? discovery,
  }) async {
    final database = AppDatabase(NativeDatabase.memory());
    final now = DateTime.now().toUtc();
    final month = DateTime.utc(now.year, now.month);
    await database
        .into(database.accounts)
        .insert(
          AccountsCompanion.insert(
            id: _accountId,
            provider: provider.storageValue,
            authority: provider == BusyProvider.microsoft
                ? 'https://login.microsoftonline.com/common'
                : 'https://accounts.google.com',
            providerAccountId: _accountId,
            credentialKind: 'oauth',
            authState: const Value('signed_in'),
            createdAtUtc: now.toIso8601String(),
            updatedAtUtc: now.toIso8601String(),
          ),
        );
    final source = CalendarSourceDto(
      provider: provider,
      providerCalendarId: 'calendar',
      summary: 'Calendar',
    );
    await CalendarRepository(
      database: database,
    ).upsertSource(accountId: _accountId, source: source);
    final client = _HeldCalendarClient(
      source: source,
      event: CalendarEventDto(
        provider: provider,
        providerCalendarId: source.providerCalendarId,
        providerEventId: 'new-event',
        title: 'New event',
        startDateTime: DateTime.utc(
          month.year,
          month.month,
          15,
          10,
        ).toIso8601String(),
        endDateTime: DateTime.utc(
          month.year,
          month.month,
          15,
          11,
        ).toIso8601String(),
      ),
    );
    final monitor = NetworkConnectivityMonitor.withoutPlatformObservation();
    final gate = _RecordingAccountGate();
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(database),
        localTimeZoneProvider.overrideWithValue('UTC'),
        networkConnectivityMonitorProvider.overrideWithValue(monitor),
        crossEngineAccountGateProvider.overrideWithValue(gate),
        notificationReconcilerProvider.overrideWithValue(
          CallbackNotificationReconciler(() async {}),
        ),
        calendarSyncEngineForAccountFactoryProvider.overrideWithValue(
          (accountId, _) => CalendarSyncEngine(
            database: database,
            client: client,
            accountId: accountId,
            nowUtc: () => now,
          ),
        ),
        if (authorization != null)
          applicationMicrosoftOAuthServiceProvider.overrideWithValue(
            authorization,
          ),
        if (discovery != null)
          microsoftCalendarApiClientForAccountProvider(
            _accountId,
          ).overrideWithValue(discovery),
      ],
    );
    return _Fixture(
      database: database,
      container: container,
      monitor: monitor,
      client: client,
      gate: gate,
      month: month,
    );
  }

  Future<T> track<T>(Future<T> operation) {
    _pending.add(
      operation.then<void>((_) {}, onError: (Object _, StackTrace _) {}),
    );
    return operation;
  }

  Future<void> dispose() async {
    if (!client.releaseRange.isCompleted) client.releaseRange.complete();
    if (!client.releaseSync.isCompleted) client.releaseSync.complete();
    await Future.wait(_pending).timeout(const Duration(seconds: 5));
    container.dispose();
    await monitor.dispose();
    await database.close();
  }
}

/// Intentionally leaves in-process serialization to the production coordinator.
final class _RecordingAccountGate implements CrossEngineAccountGate {
  final List<String> accountIds = [];

  @override
  Future<T> run<T>(String accountId, Future<T> Function() operation) {
    accountIds.add(accountId);
    return operation();
  }
}

final class _HeldCalendarClient implements CloudCalendarClient {
  _HeldCalendarClient({required this.source, required this.event});

  final CalendarSourceDto source;
  final CalendarEventDto event;
  final rangeStarted = Completer<void>();
  final syncStarted = Completer<void>();
  final releaseRange = Completer<void>();
  final releaseSync = Completer<void>();
  final List<String> rangeCalendarIds = [];
  List<CalendarEventDto> rangeEvents = [];
  bool holdRange = false;
  bool holdSync = false;

  @override
  BusyProvider get provider => source.provider;

  @override
  CalendarProviderCapabilities get capabilities =>
      provider == BusyProvider.google
      ? googleCalendarProviderCapabilities
      : microsoftCalendarProviderCapabilities;

  @override
  Future<List<CalendarSourceDto>> listCalendars() async => [source];

  @override
  Future<List<CalendarEventDto>> listEvents({
    required String calendarId,
    required DateTime rangeStart,
    required DateTime rangeEnd,
    String? pageTokenOrUrl,
  }) async {
    rangeCalendarIds.add(calendarId);
    if (!rangeStarted.isCompleted) rangeStarted.complete();
    if (holdRange) await releaseRange.future;
    return rangeEvents;
  }

  @override
  Future<CalendarSyncPageDto> syncEvents({
    required String calendarId,
    required DateTime rangeStart,
    required DateTime rangeEnd,
    String? syncTokenOrDeltaLink,
    bool primaryCalendar = false,
  }) async {
    if (!syncStarted.isCompleted) syncStarted.complete();
    if (holdSync) await releaseSync.future;
    return CalendarSyncPageDto(
      events: [event],
      nextSyncTokenOrDeltaLink: 'cursor',
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Unexpected calendar request: ${invocation.memberName}');
}

final class _SharedCalendarAuthorization
    implements MicrosoftOAuthGateway, MicrosoftSharedCalendarAuthorization {
  final List<String> accounts = [];

  @override
  Future<void> authorizeSharedCalendarAccess(
    String accountId, {
    AuthorizationCancellation? cancellation,
  }) async {
    accounts.add(accountId);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw StateError(
    'Unexpected authorization request: ${invocation.memberName}',
  );
}

Future<void> _waitFor(bool Function() condition) async {
  final deadline = DateTime.now().add(const Duration(seconds: 2));
  while (!condition() && DateTime.now().isBefore(deadline)) {
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  expect(
    condition(),
    isTrue,
    reason: 'Account operation did not reach the gate.',
  );
}

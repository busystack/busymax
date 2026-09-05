import 'package:busymax/src/dav/http/dav_http_transport.dart';
import 'package:busymax/src/dav/mutation/dav_calendar_collection_mutation_service.dart';
import 'package:busymax/src/db/app_database.dart';
import 'package:busymax/src/features/accounts/data/accounts_repository.dart';
import 'package:busymax/src/features/calendar/data/calendar_collection_creation_service.dart';
import 'package:busymax/src/features/calendar/data/calendar_repository.dart';
import 'package:busymax/src/providers/busy_provider.dart';
import 'package:drift/drift.dart' hide isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late _FakeDavCalendarClient davClient;
  late List<String> syncRequests;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    davClient = _FakeDavCalendarClient();
    syncRequests = [];
  });

  tearDown(() => database.close());

  for (final provider in [BusyProvider.google, BusyProvider.microsoft]) {
    test('${provider.displayName} preserves cloud pending creation', () async {
      await _seedAccount(database, provider);
      final result = await _service(
        database,
        davClient,
        syncRequests,
      ).createCalendar(accountId: 'account', title: 'Projects');

      expect(result.outcome, CalendarCollectionCreationOutcome.queued);
      expect(result.localSourceId, isNotNull);
      final source = await database
          .select(database.calendarSources)
          .getSingle();
      expect(source.providerCalendarId, startsWith('local:'));
      final operation = await database.select(database.pendingOps).getSingle();
      expect(operation.operationType, 'calendar.create');
      expect(operation.accountId, 'account');
      expect(syncRequests, ['account']);
      expect(davClient.titles, isEmpty);
    });
  }

  test(
    'Nextcloud uses DAV without a local source or pending operation',
    () async {
      await _seedAccount(database, BusyProvider.nextcloud);
      final result = await _service(
        database,
        davClient,
        syncRequests,
      ).createCalendar(accountId: 'account', title: 'Nextcloud calendar');

      expect(result.outcome, CalendarCollectionCreationOutcome.created);
      expect(davClient.titles, ['Nextcloud calendar']);
      expect(await database.select(database.calendarSources).get(), isEmpty);
      expect(await database.select(database.pendingOps).get(), isEmpty);
      expect(syncRequests, isEmpty);
    },
  );

  test('maps a successful remote creation with pending refresh', () async {
    await _seedAccount(database, BusyProvider.nextcloud);
    davClient.result = const DavCalendarCollectionCreationResult(
      DavCalendarCollectionCreationStatus.createdRefreshPending,
    );

    final result = await _service(
      database,
      davClient,
      syncRequests,
    ).createCalendar(accountId: 'account', title: 'Remote');

    expect(
      result.outcome,
      CalendarCollectionCreationOutcome.createdRefreshPending,
    );
  });

  for (final provider in [BusyProvider.appleICloud, BusyProvider.webCal]) {
    test('${provider.displayName} is rejected before local mutation', () async {
      await _seedAccount(database, provider);

      await expectLater(
        _service(
          database,
          davClient,
          syncRequests,
        ).createCalendar(accountId: 'account', title: 'Unsupported'),
        throwsA(isA<CalendarCollectionCreationException>()),
      );
      expect(await database.select(database.calendarSources).get(), isEmpty);
      expect(await database.select(database.pendingOps).get(), isEmpty);
      expect(davClient.titles, isEmpty);
      expect(syncRequests, isEmpty);
    });
  }

  test('disabled calendar service rejects before local mutation', () async {
    await _seedAccount(database, BusyProvider.google, calendarsEnabled: false);

    await expectLater(
      _service(
        database,
        davClient,
        syncRequests,
      ).createCalendar(accountId: 'account', title: 'Disabled'),
      throwsA(isA<CalendarCollectionCreationException>()),
    );
    expect(await database.select(database.pendingOps).get(), isEmpty);
  });

  test('cloud repository defensively rejects Nextcloud', () async {
    await _seedAccount(database, BusyProvider.nextcloud);

    await expectLater(
      CalendarRepository(
        database: database,
      ).createLocalSource(accountId: 'account', summary: 'Wrong route'),
      throwsA(isA<CalendarMutationNotAllowed>()),
    );
    expect(await database.select(database.pendingOps).get(), isEmpty);
  });
}

CalendarCollectionCreationService _service(
  AppDatabase database,
  _FakeDavCalendarClient davClient,
  List<String> syncRequests,
) => CalendarCollectionCreationService(
  accountsRepository: AccountsRepository(database: database),
  calendarRepository: CalendarRepository(
    database: database,
    now: () => DateTime.utc(2026, 8, 29, 12),
  ),
  davClientForAccount: (_) => davClient,
  requestCloudSynchronization: syncRequests.add,
);

Future<void> _seedAccount(
  AppDatabase database,
  BusyProvider provider, {
  bool calendarsEnabled = true,
}) async {
  const now = '2026-08-29T12:00:00.000Z';
  await database
      .into(database.accounts)
      .insert(
        AccountsCompanion.insert(
          id: 'account',
          provider: provider.storageValue,
          authority: 'https://example.test',
          providerAccountId: 'identity',
          credentialKind: provider == BusyProvider.webCal
              ? 'webcal_subscription'
              : provider == BusyProvider.nextcloud
              ? 'nextcloud_app_password'
              : provider == BusyProvider.appleICloud
              ? 'apple_app_specific_password'
              : 'oauth',
          authState: const Value(accountAuthStateSignedIn),
          calendarsEnabled: Value(calendarsEnabled),
          tasksEnabled: Value(provider != BusyProvider.webCal),
          createdAtUtc: now,
          updatedAtUtc: now,
        ),
      );
}

final class _FakeDavCalendarClient
    implements DavCalendarCollectionMutationClient {
  final titles = <String>[];
  DavCalendarCollectionCreationResult result =
      const DavCalendarCollectionCreationResult(
        DavCalendarCollectionCreationStatus.created,
      );

  @override
  Future<DavCalendarCollectionCreationResult> createEventCalendar(
    String title, {
    DavCancellationToken? cancellationToken,
  }) async {
    titles.add(title);
    return result;
  }
}

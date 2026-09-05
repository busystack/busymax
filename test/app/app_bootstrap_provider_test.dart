import 'dart:async';

import 'package:busymax/src/core/secrets/secret_store.dart';
import 'package:busymax/src/dav/dav_provider_profile.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:busymax/src/app/app_bootstrap.dart';
import 'package:busymax/src/config/build_config.dart';
import 'package:busymax/src/db/app_database.dart';
import 'package:busymax/src/features/accounts/data/accounts_repository.dart';
import 'package:busymax/src/features/auth/data/auth_repository.dart';
import 'package:busymax/src/features/notifications/notification_scheduler.dart';
import 'package:busymax/src/features/tasks/domain/task_capabilities.dart';
import 'package:busymax/src/google_tasks/api/google_tasks_api_surface.dart';
import 'package:busymax/src/core/auth/oauth_models.dart';
import 'package:busymax/src/google_tasks/oauth/oauth_service.dart';
import 'package:busymax/src/providers/busy_provider.dart';
import 'package:drift/drift.dart' show Value;
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('repositories are not created without an active account', () async {
    final database = AppDatabase(NativeDatabase.memory());
    final container = _container(
      database: database,
      oAuth: _FakeOAuthGateway(),
    );
    addTearDown(() async {
      container.dispose();
      await database.close();
    });

    await container.read(authSessionControllerProvider.notifier).load();

    expect(container.read(activeAccountProvider), isNull);
    expect(container.read(taskListsRepositoryProvider), isNull);
    expect(container.read(tasksRepositoryProvider), isNull);
    expect(
      container.read(selectedAccountCapabilitiesProvider),
      noTaskCollectionCapabilities,
    );
  });

  test('repositories are created after session sign-in', () async {
    final database = AppDatabase(NativeDatabase.memory());
    final container = _container(
      database: database,
      oAuth: _FakeOAuthGateway(),
    );
    addTearDown(() async {
      container.dispose();
      await database.close();
    });

    await container.read(authSessionControllerProvider.notifier).signIn();

    expect(container.read(activeAccountProvider), 'account-1');
    expect(container.read(taskListsRepositoryProvider), isNotNull);
    expect(container.read(tasksRepositoryProvider), isNotNull);
  });

  test('sign-in starts initial sync without circular provider reads', () async {
    final database = AppDatabase(NativeDatabase.memory());
    final syncCalls = <_SyncCall>[];
    final container = _container(
      database: database,
      oAuth: _FakeOAuthGateway(),
      signedInSyncRunner: (accountId, initial) async {
        syncCalls.add(_SyncCall(accountId, initial));
      },
    );
    addTearDown(() async {
      container.dispose();
      await database.close();
    });

    final controller = container.read(authSessionControllerProvider.notifier);
    await controller.load();
    await _flushAsync();

    await controller.signIn();
    await _flushAsync();

    final state = container.read(authSessionControllerProvider);
    expect(state.status, AuthSessionStatus.signedIn);
    expect(state.accountId, 'account-1');
    expect(syncCalls, hasLength(1));
    expect(syncCalls.single.accountId, 'account-1');
    expect(syncCalls.single.initial, isTrue);
  });

  test(
    'loaded session starts incremental sync without circular provider reads',
    () async {
      final database = AppDatabase(NativeDatabase.memory());
      await _seedSignedInGoogleAccount(database);
      final syncStarted = Completer<void>();
      final syncCalls = <_SyncCall>[];
      final container = _container(
        database: database,
        oAuth: _FakeOAuthGateway(),
        signedInSyncRunner: (accountId, initial) async {
          syncCalls.add(_SyncCall(accountId, initial));
          if (!syncStarted.isCompleted) {
            syncStarted.complete();
          }
        },
      );
      addTearDown(() async {
        container.dispose();
        await database.close();
      });

      container.read(authSessionControllerProvider);
      await syncStarted.future.timeout(const Duration(seconds: 1));
      await _flushAsync();

      final state = container.read(authSessionControllerProvider);
      expect(state.status, AuthSessionStatus.signedIn);
      expect(syncCalls, hasLength(1));
      expect(syncCalls.single.accountId, 'account-1');
      expect(syncCalls.single.initial, isFalse);
    },
  );

  test('sign-in keeps signed-in state when sync runner fails', () async {
    final database = AppDatabase(NativeDatabase.memory());
    var syncCalls = 0;
    final container = _container(
      database: database,
      oAuth: _FakeOAuthGateway(),
      signedInSyncRunner: (accountId, initial) async {
        syncCalls += 1;
        throw StateError('sync failed');
      },
    );
    addTearDown(() async {
      container.dispose();
      await database.close();
    });

    Object? zoneError;
    await runZonedGuarded<Future<void>>(
      () async {
        final controller = container.read(
          authSessionControllerProvider.notifier,
        );
        await controller.load();
        await _flushAsync();

        await controller.signIn();
        await _flushAsync();
      },
      (error, _) {
        zoneError = error;
      },
    );

    final state = container.read(authSessionControllerProvider);
    expect(zoneError, isNull);
    expect(syncCalls, 1);
    expect(state.status, AuthSessionStatus.signedIn);
    expect(state.accountId, 'account-1');
  });

  test(
    'loaded session preserves cached account when startup sync needs reconnect',
    () async {
      final database = AppDatabase(NativeDatabase.memory());
      await _seedSignedInGoogleAccount(database);
      final syncStarted = Completer<void>();
      final container = _container(
        database: database,
        oAuth: _FakeOAuthGateway(),
        signedInSyncRunner: (accountId, initial) async {
          if (!syncStarted.isCompleted) {
            syncStarted.complete();
          }
          throw const OAuthException(
            'OAuthMissingToken',
            'No OAuth token is available for this account.',
          );
        },
      );
      addTearDown(() async {
        container.dispose();
        await database.close();
      });

      Object? zoneError;
      await runZonedGuarded<Future<void>>(
        () async {
          container.read(authSessionControllerProvider);
          await syncStarted.future.timeout(const Duration(seconds: 1));
          await _flushAsync();
          await _flushAsync();
        },
        (error, _) {
          zoneError = error;
        },
      );

      final state = container.read(authSessionControllerProvider);
      final account = await database.select(database.accounts).getSingle();
      expect(zoneError, isNull);
      expect(state.status, AuthSessionStatus.signedIn);
      expect(state.accountId, 'account-1');
      expect(account.authState, accountAuthStateReauthRequired);
    },
  );

  test(
    'production DAV sync rebuilds schedules before checking notifications',
    () async {
      final database = AppDatabase(NativeDatabase.memory());
      final secrets = InMemorySecretStore();
      await _seedNextcloudNotificationAccount(database, secrets);
      final eventStartUtc = DateTime.now().toUtc().add(const Duration(days: 2));
      var syncReports = 0;
      final client = MockClient((request) async {
        if (request.method == 'REPORT' &&
            request.body.contains('sync-collection')) {
          syncReports += 1;
          if (syncReports == 1) {
            return http.Response(
              _davSyncResponse(token: 'token-1', etag: '"v1"'),
              207,
            );
          }
          return http.Response(
            _davSyncResponse(token: 'token-2', deleted: true),
            207,
          );
        }
        if (request.method == 'REPORT' &&
            request.body.contains('calendar-multiget')) {
          return http.Response(_davMultigetResponse(eventStartUtc), 207);
        }
        fail('Unexpected ${request.method} ${request.url}');
      });
      final scheduler = _TrackingNotificationScheduler(database);
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(database),
          secretStoreProvider.overrideWithValue(secrets),
          baseHttpClientProvider.overrideWithValue(client),
          notificationSchedulerProvider.overrideWithValue(scheduler),
        ],
      );
      addTearDown(() async {
        container.dispose();
        client.close();
        await database.close();
      });

      await container
          .read(davAccountSyncEngineFactoryProvider)('nextcloud-account')
          .synchronize();

      expect(syncReports, 1);
      final objects = await database.select(database.davObjects).get();
      expect(objects, hasLength(1));
      expect(objects.single.lastParseStatus, 'parsed');
      final events = await database.select(database.calendarEvents).get();
      expect(events, hasLength(1));
      expect(events.single.remindersJson, contains('DISPLAY'));
      var schedules = await database
          .select(database.notificationSchedule)
          .get();
      expect(schedules, hasLength(1));
      expect(schedules.single.sourceType, 'event');
      expect(schedules.single.title, 'Remote reminder');
      expect(scheduler.scheduleCountsAtCheck, [1]);

      await container
          .read(davAccountSyncEngineFactoryProvider)('nextcloud-account')
          .synchronize();

      schedules = await database.select(database.notificationSchedule).get();
      expect(schedules, isEmpty);
      expect(scheduler.scheduleCountsAtCheck, [1, 0]);
    },
  );
}

const _nextcloudCollectionHref = '/cloud/remote.php/dav/calendars/alex/work/';
const _nextcloudEventHref = '${_nextcloudCollectionHref}reminder.ics';

Future<void> _seedNextcloudNotificationAccount(
  AppDatabase database,
  InMemorySecretStore secrets,
) async {
  final now = DateTime.now().toUtc();
  final timestamp = now.toIso8601String();
  await database
      .into(database.accounts)
      .insert(
        AccountsCompanion.insert(
          id: 'nextcloud-account',
          provider: 'nextcloud',
          authority: 'https://cloud.example.test/cloud',
          providerAccountId: 'alex',
          credentialKind: 'nextcloud_app_password',
          authState: const Value('signed_in'),
          createdAtUtc: timestamp,
          updatedAtUtc: timestamp,
        ),
      );
  await secrets.saveCredential(
    'nextcloud-account',
    NextcloudSecretRecord(
      canonicalServer: Uri.parse('https://cloud.example.test/cloud'),
      loginName: 'alex',
      appPassword: 'secret-app-password',
    ),
  );
  await database
      .into(database.davAccountServices)
      .insert(
        DavAccountServicesCompanion.insert(
          accountId: 'nextcloud-account',
          providerProfileVersion: const Value(davProviderProfileVersion),
          canonicalServiceUri:
              'https://cloud.example.test/cloud/remote.php/dav/',
          canonicalOrigin: 'https://cloud.example.test',
          principalHref: const Value(
            'https://cloud.example.test/cloud/remote.php/dav/principals/users/alex/',
          ),
          calendarHomeHref: const Value(
            'https://cloud.example.test/cloud/remote.php/dav/calendars/alex/',
          ),
          capabilitiesJson: const Value(
            '{"hasPrincipal":true,"hasCalendarHome":true}',
          ),
          discoveredAtUtc: timestamp,
          lastValidatedAtUtc: Value(timestamp),
        ),
      );
  await database
      .into(database.davCollections)
      .insert(
        DavCollectionsCompanion.insert(
          id: 'nextcloud-collection',
          accountId: 'nextcloud-account',
          hrefKey: _nextcloudCollectionHref,
          requestUri: 'https://cloud.example.test$_nextcloudCollectionHref',
          displayName: 'Work',
          supportedComponentMask: const Value(1),
          supportedReportsJson: const Value(
            '["{DAV:}sync-collection",'
            '"{urn:ietf:params:xml:ns:caldav}calendar-multiget"]',
          ),
          currentUserPrivilegesJson: const Value(
            '["{DAV:}read","{DAV:}write"]',
          ),
          readOnly: const Value(false),
          eventProjectionEnabled: const Value(true),
          lastInventoryAtUtc: Value(timestamp),
          createdAtUtc: timestamp,
          updatedAtUtc: timestamp,
        ),
      );
  await database
      .into(database.calendarSources)
      .insert(
        CalendarSourcesCompanion.insert(
          id: 'dav-calendar-nextcloud-collection',
          accountId: 'nextcloud-account',
          provider: 'nextcloud',
          providerCalendarId: _nextcloudCollectionHref,
          davCollectionId: const Value('nextcloud-collection'),
          summary: 'Work',
          createdAtLocal: now.millisecondsSinceEpoch,
          updatedAtLocal: now.millisecondsSinceEpoch,
        ),
      );
}

String _davSyncResponse({
  required String token,
  String? etag,
  bool deleted = false,
}) =>
    '''<?xml version="1.0" encoding="utf-8"?>
<d:multistatus xmlns:d="DAV:">
  ${etag == null && !deleted ? '' : '''<d:response>
    <d:href>$_nextcloudEventHref</d:href>
    ${deleted ? '<d:status>HTTP/1.1 404 Not Found</d:status>' : '''<d:propstat><d:prop><d:getetag>$etag</d:getetag></d:prop>
      <d:status>HTTP/1.1 200 OK</d:status></d:propstat>'''}
  </d:response>'''}
  <d:sync-token>$token</d:sync-token>
</d:multistatus>''';

String _davMultigetResponse(DateTime eventStartUtc) {
  final start = _icalUtc(eventStartUtc);
  final end = _icalUtc(eventStartUtc.add(const Duration(hours: 1)));
  return '''<?xml version="1.0" encoding="utf-8"?>
<d:multistatus xmlns:d="DAV:" xmlns:c="urn:ietf:params:xml:ns:caldav">
  <d:response>
    <d:href>$_nextcloudEventHref</d:href>
    <d:propstat><d:prop>
      <d:getetag>"v1"</d:getetag>
      <c:calendar-data content-type="text/calendar"><![CDATA[BEGIN:VCALENDAR
VERSION:2.0
PRODID:-//BusyMax Test//EN
BEGIN:VEVENT
UID:reminder@example.test
DTSTART:$start
DTEND:$end
SUMMARY:Remote reminder
BEGIN:VALARM
ACTION:DISPLAY
TRIGGER:-PT15M
DESCRIPTION:Reminder
END:VALARM
END:VEVENT
END:VCALENDAR
]]></c:calendar-data>
    </d:prop><d:status>HTTP/1.1 200 OK</d:status></d:propstat>
  </d:response>
</d:multistatus>''';
}

String _icalUtc(DateTime value) {
  final utc = value.toUtc();
  String twoDigits(int part) => part.toString().padLeft(2, '0');
  return '${utc.year.toString().padLeft(4, '0')}'
      '${twoDigits(utc.month)}${twoDigits(utc.day)}T'
      '${twoDigits(utc.hour)}${twoDigits(utc.minute)}'
      '${twoDigits(utc.second)}Z';
}

final class _TrackingNotificationScheduler implements NotificationScheduler {
  _TrackingNotificationScheduler(this.database);

  final AppDatabase database;
  final List<int> scheduleCountsAtCheck = [];

  @override
  Future<void> checkNow() async {
    scheduleCountsAtCheck.add(
      await database
          .select(database.notificationSchedule)
          .get()
          .then((rows) => rows.length),
    );
  }

  @override
  Future<void> handleActivation({
    required String notificationScheduleId,
    required String action,
  }) async {}

  @override
  void start() {}

  @override
  void stop() {}
}

Future<void> _seedSignedInGoogleAccount(AppDatabase database) {
  return AccountsRepository(
    database: database,
    nowUtc: () => DateTime.utc(2026, 6, 4),
  ).upsertSignedInAccount(
    id: 'account-1',
    provider: BusyProvider.google,
    grantedScopes: googleBusyMaxOAuthScopes.join(' '),
  );
}

ProviderContainer _container({
  required AppDatabase database,
  required _FakeOAuthGateway oAuth,
  SignedInSyncRunner? signedInSyncRunner,
}) {
  return ProviderContainer(
    overrides: [
      buildConfigProvider.overrideWithValue(_configuredBuildConfig),
      databaseProvider.overrideWithValue(database),
      authRepositoryProvider.overrideWithValue(
        AuthRepository(
          oAuth: oAuth,
          database: database,
          nowUtc: () => DateTime.utc(2026, 6, 4),
        ),
      ),
      signedInSyncRunnerProvider.overrideWithValue(
        signedInSyncRunner ?? (accountId, initial) async {},
      ),
    ],
  );
}

Future<void> _flushAsync() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

class _SyncCall {
  const _SyncCall(this.accountId, this.initial);

  final String accountId;
  final bool initial;
}

class _FakeOAuthGateway implements OAuthGateway {
  String? activeId;

  @override
  Future<String?> get activeAccountId async => activeId;

  @override
  Future<void> cancelSignIn() async {}

  @override
  Future<OAuthTokenSet?> readActiveTokenSet() async {
    if (activeId == null) {
      return null;
    }
    return _tokenSet();
  }

  @override
  Future<GoogleUserInfo?> fetchUserInfo(OAuthTokenSet tokenSet) async => null;

  @override
  Future<OAuthTokenSet> refreshActiveToken() async => _tokenSet();

  @override
  Future<void> revokeAndSignOutAccount(String accountId) async {
    if (activeId == accountId) {
      activeId = null;
    }
  }

  @override
  Future<void> revokeAuthorization(String accountId) async {}

  @override
  Future<void> clearLocalSession({String? accountId}) async {
    activeId = null;
  }

  @override
  Future<OAuthSignInResult> signIn({String? loginHint}) async {
    activeId = 'account-1';
    return OAuthSignInResult(accountId: 'account-1', tokenSet: _tokenSet());
  }
}

OAuthTokenSet _tokenSet() {
  return OAuthTokenSet(
    accessToken: 'access',
    refreshToken: 'refresh',
    expiresAtUtc: DateTime.utc(2026, 6, 4, 1),
    tokenType: 'Bearer',
    scopes: Set<String>.of(googleBusyMaxOAuthScopes),
  );
}

const _configuredBuildConfig = BuildConfig(
  googleOAuthClientId: 'client-id',
  googleOAuthClientSecret: '',
  googleApiBaseUrl: 'https://www.googleapis.com',
  oauthAuthorizationEndpoint: 'https://accounts.google.com/o/oauth2/v2/auth',
  oauthTokenEndpoint: 'https://oauth2.googleapis.com/token',
  oauthRevocationEndpoint: 'https://oauth2.googleapis.com/revoke',
);

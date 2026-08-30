import 'dart:io';

import 'package:busymax/src/core/secrets/secret_store.dart';
import 'package:busymax/src/dav/dav_errors.dart';
import 'package:busymax/src/dav/discovery/dav_discovery_models.dart';
import 'package:busymax/src/dav/http/dav_http_transport.dart';
import 'package:busymax/src/dav/mutation/dav_calendar_collection_mutation_service.dart';
import 'package:busymax/src/db/app_database.dart';
import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  late AppDatabase database;
  late InMemorySecretStore secrets;

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    secrets = InMemorySecretStore();
    await _seedNextcloudAccount(database, secrets);
  });

  tearDown(() => database.close());

  test('sends an event-only MKCALENDAR beneath the calendar home', () async {
    late http.Request request;
    var refreshes = 0;
    final service = _service(
      database,
      secrets,
      MockClient((incoming) async {
        request = incoming;
        return http.Response('', HttpStatus.created);
      }),
      refresh: () async => refreshes += 1,
    );

    final result = await service.createEventCalendar('Work & Travel');

    expect(result.refreshPending, isFalse);
    expect(request.method, 'MKCALENDAR');
    expect(
      request.url.toString(),
      'https://cloud.example.test/remote.php/dav/calendars/alex/work-travel/',
    );
    expect(request.headers['content-type'], 'application/xml; charset=utf-8');
    expect(request.body, contains('<c:mkcalendar'));
    expect(request.body, contains('<d:displayname>Work &amp; Travel'));
    expect(RegExp('name="VEVENT"').allMatches(request.body), hasLength(1));
    expect(request.body, isNot(contains('VTODO')));
    expect(refreshes, 1);
    expect(await database.select(database.calendarSources).get(), isEmpty);
    expect(await database.select(database.pendingOps).get(), isEmpty);
  });

  test('uses one MKCALENDAR attempt and never falls back to MKCOL', () async {
    final methods = <String>[];
    final service = _service(
      database,
      secrets,
      MockClient((request) async {
        methods.add(request.method);
        return http.Response('', HttpStatus.methodNotAllowed);
      }),
    );

    await expectLater(
      service.createEventCalendar('Unsupported'),
      throwsA(
        isA<DavException>().having(
          (error) => error.code,
          'code',
          'DavMkcalendarUnsupported',
        ),
      ),
    );
    expect(methods, ['MKCALENDAR']);
  });

  for (final statusAndExpectation in <(int, DavErrorKind, String)>[
    (401, DavErrorKind.authentication, 'DavAuthRejected'),
    (403, DavErrorKind.authorization, 'DavCalendarParentNotWritable'),
    (409, DavErrorKind.conflict, 'DavCalendarCollectionConflict'),
  ]) {
    test('maps HTTP ${statusAndExpectation.$1} to a safe DAV error', () async {
      final service = _service(
        database,
        secrets,
        MockClient(
          (_) async => http.Response(
            '<html>private response</html>',
            statusAndExpectation.$1,
          ),
        ),
      );

      await expectLater(
        service.createEventCalendar('Rejected'),
        throwsA(
          isA<DavException>()
              .having((error) => error.kind, 'kind', statusAndExpectation.$2)
              .having((error) => error.code, 'code', statusAndExpectation.$3)
              .having(
                (error) => error.toString(),
                'diagnostic',
                isNot(contains('private response')),
              ),
        ),
      );
    });
  }

  test(
    'reconciles an ambiguous connection failure with an exact probe',
    () async {
      final methods = <String>[];
      var refreshes = 0;
      final service = _service(
        database,
        secrets,
        MockClient((request) async {
          methods.add(request.method);
          if (request.method == 'MKCALENDAR') {
            throw const SocketException('connection closed after commit');
          }
          expect(request.headers['depth'], '0');
          expect(request.url.path, endsWith('/recovered/'));
          return http.Response(_createdEventCalendar('Recovered'), 207);
        }),
        refresh: () async => refreshes += 1,
      );

      await service.createEventCalendar('Recovered');

      expect(methods, ['MKCALENDAR', 'PROPFIND']);
      expect(refreshes, 1);
    },
  );

  test(
    'preserves an ambiguous failure when the probe does not match',
    () async {
      var refreshes = 0;
      final service = _service(
        database,
        secrets,
        MockClient((request) async {
          if (request.method == 'MKCALENDAR') {
            throw const SocketException('connection closed after request');
          }
          return http.Response(_createdEventCalendar('Different'), 207);
        }),
        refresh: () async => refreshes += 1,
      );

      await expectLater(
        service.createEventCalendar('Expected'),
        throwsA(
          isA<DavException>().having(
            (error) => error.kind,
            'kind',
            DavErrorKind.network,
          ),
        ),
      );
      expect(refreshes, 0);
    },
  );

  test(
    'malformed ambiguous-outcome probe preserves the original failure',
    () async {
      final service = _service(
        database,
        secrets,
        MockClient((request) async {
          if (request.method == 'MKCALENDAR') {
            throw const SocketException('connection closed after request');
          }
          return http.Response('<not-dav>', HttpStatus.multiStatus);
        }),
      );

      await expectLater(
        service.createEventCalendar('Malformed probe'),
        throwsA(
          isA<DavException>()
              .having((error) => error.kind, 'kind', DavErrorKind.network)
              .having((error) => error.code, 'code', 'DavNetworkFailure'),
        ),
      );
    },
  );

  test('transport timeout does not retry MKCALENDAR', () async {
    var mkcalendarRequests = 0;
    final service = _service(
      database,
      secrets,
      MockClient((request) async {
        if (request.method == 'MKCALENDAR') mkcalendarRequests += 1;
        await Future<void>.delayed(const Duration(milliseconds: 40));
        return http.Response('', HttpStatus.serviceUnavailable);
      }),
      transportLimits: const DavTransportLimits(
        connectTimeout: Duration(milliseconds: 5),
        responseTimeout: Duration(milliseconds: 5),
        operationTimeout: Duration(milliseconds: 50),
      ),
    );

    await expectLater(
      service.createEventCalendar('Timeout'),
      throwsA(
        isA<DavException>().having(
          (error) => error.kind,
          'kind',
          DavErrorKind.timeout,
        ),
      ),
    );
    expect(mkcalendarRequests, 1);
  });

  test('only 201 Created is accepted as direct success', () async {
    final service = _service(
      database,
      secrets,
      MockClient((_) async => http.Response('', HttpStatus.noContent)),
    );

    await expectLater(
      service.createEventCalendar('Unexpected success status'),
      throwsA(
        isA<DavException>().having(
          (error) => error.code,
          'code',
          'DavCalendarCollectionCreationRejected',
        ),
      ),
    );
  });

  test('reports created with refresh pending after remote success', () async {
    final service = _service(
      database,
      secrets,
      MockClient((_) async => http.Response('', HttpStatus.created)),
      refresh: () async => throw StateError('sync unavailable'),
    );

    final result = await service.createEventCalendar('Created remotely');

    expect(
      result.status,
      DavCalendarCollectionCreationStatus.createdRefreshPending,
    );
  });

  test(
    'rejects duplicate event-calendar display names before transport',
    () async {
      await _seedEventCollection(database, displayName: 'Work');
      var requests = 0;
      final service = _service(
        database,
        secrets,
        MockClient((_) async {
          requests += 1;
          return http.Response('', HttpStatus.created);
        }),
      );

      await expectLater(
        service.createEventCalendar('Work'),
        throwsA(
          isA<DavException>().having(
            (error) => error.code,
            'code',
            'DavCalendarNameConflict',
          ),
        ),
      );
      expect(requests, 0);
    },
  );

  test('rejects a missing calendar home before transport', () async {
    await database.delete(database.davAccountServices).go();
    var requests = 0;
    final service = _service(
      database,
      secrets,
      MockClient((_) async {
        requests += 1;
        return http.Response('', HttpStatus.created);
      }),
    );

    await expectLater(
      service.createEventCalendar('Work'),
      throwsA(
        isA<DavException>().having(
          (error) => error.code,
          'code',
          'DavCalendarHomeUnavailable',
        ),
      ),
    );
    expect(requests, 0);
  });

  test(
    'rejects invalid credentials and a mismatched canonical server',
    () async {
      await secrets.saveCredential(
        'account',
        NextcloudSecretRecord(
          canonicalServer: Uri.parse('https://different.example.test'),
          loginName: 'alex',
          appPassword: 'secret',
        ),
      );
      final service = _service(
        database,
        secrets,
        MockClient((_) async => http.Response('', HttpStatus.created)),
      );

      await expectLater(
        service.createEventCalendar('Work'),
        throwsA(
          isA<DavException>().having(
            (error) => error.code,
            'code',
            'DavCredentialsRevoked',
          ),
        ),
      );
    },
  );

  test('rejects a cross-origin calendar home before transport', () async {
    await database
        .update(database.davAccountServices)
        .write(
          const DavAccountServicesCompanion(
            calendarHomeHref: Value(
              'https://evil.example.test/remote.php/dav/calendars/alex/',
            ),
          ),
        );
    var requests = 0;
    final service = _service(
      database,
      secrets,
      MockClient((_) async {
        requests += 1;
        return http.Response('', HttpStatus.created);
      }),
    );

    await expectLater(
      service.createEventCalendar('Work'),
      throwsA(
        isA<DavException>().having(
          (error) => error.code,
          'code',
          'DavCalendarMutationContextInvalid',
        ),
      ),
    );
    expect(requests, 0);
  });

  test('enforces offline state before context or transport work', () async {
    var networkChecks = 0;
    var requests = 0;
    final service = _service(
      database,
      secrets,
      MockClient((_) async {
        requests += 1;
        return http.Response('', HttpStatus.created);
      }),
      requireNetwork: () async {
        networkChecks += 1;
        throw const _OfflineTestException();
      },
    );

    await expectLater(
      service.createEventCalendar('Offline'),
      throwsA(isA<_OfflineTestException>()),
    );
    expect(networkChecks, 1);
    expect(requests, 0);
  });

  test('honors cancellation without probing or refreshing', () async {
    final token = DavCancellationToken()..cancel();
    var requests = 0;
    var refreshes = 0;
    final service = _service(
      database,
      secrets,
      MockClient((_) async {
        requests += 1;
        return http.Response('', HttpStatus.created);
      }),
      refresh: () async => refreshes += 1,
    );

    await expectLater(
      service.createEventCalendar('Cancelled', cancellationToken: token),
      throwsA(
        isA<DavException>().having(
          (error) => error.kind,
          'kind',
          DavErrorKind.cancelled,
        ),
      ),
    );
    expect(requests, 0);
    expect(refreshes, 0);
  });
}

DavCalendarCollectionMutationService _service(
  AppDatabase database,
  SecretStore secrets,
  http.Client client, {
  Future<void> Function()? refresh,
  Future<void> Function()? requireNetwork,
  DavTransportLimits transportLimits = const DavTransportLimits(),
}) {
  var correlation = 0;
  return DavCalendarCollectionMutationService(
    database: database,
    secretStore: secrets,
    httpClient: client,
    accountId: 'account',
    refreshAfterMutation: refresh ?? () async {},
    requireNetwork: requireNetwork,
    transportLimits: transportLimits,
    correlationIdFactory: () => 'correlation-${correlation += 1}',
  );
}

Future<void> _seedNextcloudAccount(
  AppDatabase database,
  InMemorySecretStore secrets,
) async {
  const now = '2026-08-29T12:00:00.000Z';
  await database
      .into(database.accounts)
      .insert(
        AccountsCompanion.insert(
          id: 'account',
          provider: 'nextcloud',
          authority: 'https://cloud.example.test',
          providerAccountId: 'alex',
          credentialKind: 'nextcloud_app_password',
          createdAtUtc: now,
          updatedAtUtc: now,
        ),
      );
  await database
      .into(database.davAccountServices)
      .insert(
        DavAccountServicesCompanion.insert(
          accountId: 'account',
          canonicalServiceUri: 'https://cloud.example.test/remote.php/dav/',
          canonicalOrigin: 'https://cloud.example.test',
          principalHref: const Value('/remote.php/dav/principals/users/alex/'),
          calendarHomeHref: const Value(
            'https://cloud.example.test/remote.php/dav/calendars/alex/',
          ),
          discoveredAtUtc: now,
        ),
      );
  await secrets.saveCredential(
    'account',
    NextcloudSecretRecord(
      canonicalServer: Uri.parse('https://cloud.example.test'),
      loginName: 'alex',
      appPassword: 'application-password',
    ),
  );
}

Future<void> _seedEventCollection(
  AppDatabase database, {
  required String displayName,
}) async {
  const now = '2026-08-29T12:00:00.000Z';
  await database
      .into(database.davCollections)
      .insert(
        DavCollectionsCompanion.insert(
          id: 'calendar',
          accountId: 'account',
          hrefKey: '/remote.php/dav/calendars/alex/work/',
          requestUri:
              'https://cloud.example.test/remote.php/dav/calendars/alex/work/',
          displayName: displayName,
          supportedComponentMask: const Value(davComponentEvent),
          eventProjectionEnabled: const Value(true),
          createdAtUtc: now,
          updatedAtUtc: now,
        ),
      );
}

String _createdEventCalendar(String displayName) =>
    '<?xml version="1.0"?>'
    '<d:multistatus xmlns:d="DAV:" '
    'xmlns:c="urn:ietf:params:xml:ns:caldav">'
    '<d:response><d:href>/remote.php/dav/calendars/alex/recovered/</d:href>'
    '<d:propstat><d:prop>'
    '<d:resourcetype><d:collection/><c:calendar/></d:resourcetype>'
    '<d:displayname>$displayName</d:displayname>'
    '<c:supported-calendar-component-set><c:comp name="VEVENT"/>'
    '</c:supported-calendar-component-set>'
    '</d:prop><d:status>HTTP/1.1 200 OK</d:status></d:propstat>'
    '</d:response></d:multistatus>';

final class _OfflineTestException implements Exception {
  const _OfflineTestException();
}

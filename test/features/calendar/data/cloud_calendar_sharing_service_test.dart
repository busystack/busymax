import 'dart:async';
import 'dart:convert';

import 'package:busymax/src/features/calendar/data/calendar_repository.dart';
import 'package:busymax/src/app/busymax_design.dart';
import 'package:busymax/src/features/calendar/data/cloud_calendar_sharing_service.dart';
import 'package:busymax/src/android/presentation/android_cloud_calendar_sharing_content.dart';
import 'package:busymax/src/core/http/request_dispatch_exception.dart';
import 'package:busymax/src/features/connectivity/network_connectivity_service.dart';
import 'package:busymax/src/features/calendar/presentation/cloud_calendar_sharing_content.dart'
    as linux;
import 'package:busymax/src/google_calendar/google_calendar_api_client.dart';
import 'package:busymax/src/google_calendar/google_calendar_errors.dart';
import 'package:busymax/src/microsoft_calendar/microsoft_calendar_api_client.dart';
import 'package:busymax/src/providers/busy_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../../../test_localized_app.dart';

void main() {
  const googleSource = CalendarSourceEntity(
    id: 'source',
    accountId: 'account',
    provider: BusyProvider.google,
    providerCalendarId: 'calendar@example.com',
    summary: 'Calendar',
    selected: true,
    hidden: false,
    readOnly: false,
    isDeleted: false,
    accessRole: 'owner',
  );

  test('only actual manageable source roles expose cloud sharing', () {
    expect(CloudCalendarSharingService.canManageSource(googleSource), isTrue);
    expect(
      CloudCalendarSharingService.canManageSource(
        const CalendarSourceEntity(
          id: 'reader',
          accountId: 'account',
          provider: BusyProvider.google,
          providerCalendarId: 'shared',
          summary: 'Shared',
          selected: true,
          hidden: false,
          readOnly: false,
          isDeleted: false,
          accessRole: 'writer',
        ),
      ),
      isFalse,
    );
  });

  test(
    'pre-dispatch add failure leaves sharing usable without reconciliation',
    () async {
      const source = CalendarSourceEntity(
        id: 'unsent-add-source',
        accountId: 'unsent-add-account',
        provider: BusyProvider.google,
        providerCalendarId: 'unsent-add-calendar',
        summary: 'Calendar',
        selected: true,
        hidden: false,
        readOnly: false,
        isDeleted: false,
        accessRole: 'owner',
      );
      var offline = false;
      var providerMutations = 0;
      final client = GoogleCalendarApiClient(
        httpClient: ConnectivityAwareHttpClient(
          inner: MockClient((request) async {
            if (request.method == 'GET') {
              return http.Response(jsonEncode({'items': <Object>[]}), 200);
            }
            providerMutations++;
            return http.Response(
              jsonEncode({
                'id': 'grant-unsent',
                'role': 'reader',
                'scope': {'type': 'user', 'value': 'friend@example.com'},
              }),
              200,
            );
          }),
          requireNetwork: () async {
            if (offline) throw const NetworkUnavailableException();
          },
        ),
        baseUri: Uri.parse('https://www.googleapis.com'),
      );
      final service = CloudCalendarSharingService(
        source: source,
        google: client,
      );
      expect((await service.load()).grants, isEmpty);
      offline = true;
      await expectLater(
        service.add(recipient: 'friend@example.com', role: 'reader'),
        throwsA(isA<RequestNotDispatchedException>()),
      );
      expect(providerMutations, 0);
      expect(service.hasUnresolvedOutcome, isFalse);
      offline = false;
      expect((await service.load()).outcomeUnknown, isFalse);
      await service.add(recipient: 'friend@example.com', role: 'reader');
      expect(providerMutations, 1);
    },
  );

  for (final provider in [BusyProvider.google, BusyProvider.microsoft]) {
    for (final operation in ['add', 'change', 'revoke']) {
      test(
        '$provider $operation known-unsent mutation preserves grant state',
        () async {
          final google = provider == BusyProvider.google;
          final initialRole = google ? 'reader' : 'read';
          final changedRole = google ? 'writer' : 'write';
          final source = CalendarSourceEntity(
            id: 'unsent-$provider-$operation',
            accountId: 'unsent-account-$provider-$operation',
            provider: provider,
            providerCalendarId: 'unsent-calendar-$provider-$operation',
            summary: 'Calendar',
            selected: true,
            hidden: false,
            readOnly: false,
            isDeleted: false,
            accessRole: 'owner',
            primaryCalendar: !google,
          );
          String? remoteRole = operation == 'add' ? null : initialRole;
          var offline = false;
          var providerMutations = 0;
          final guardedHttp = ConnectivityAwareHttpClient(
            inner: MockClient((request) async {
              if (request.method == 'GET') {
                return http.Response(
                  jsonEncode(
                    google
                        ? {
                            'items': remoteRole == null
                                ? <Object>[]
                                : [
                                    {
                                      'id': 'unsent-grant',
                                      'role': remoteRole,
                                      'scope': {
                                        'type': 'user',
                                        'value': 'friend@example.com',
                                      },
                                    },
                                  ],
                          }
                        : {
                            'value': remoteRole == null
                                ? <Object>[]
                                : [
                                    {
                                      'id': 'unsent-grant',
                                      'role': remoteRole,
                                      'allowedRoles': ['read', 'write'],
                                      'isRemovable': true,
                                      'emailAddress': {
                                        'address': 'friend@example.com',
                                      },
                                    },
                                  ],
                          },
                  ),
                  200,
                );
              }
              providerMutations++;
              remoteRole = switch (operation) {
                'add' => initialRole,
                'change' => changedRole,
                _ => null,
              };
              if (request.method == 'DELETE') return http.Response('', 204);
              return http.Response(
                jsonEncode(
                  google
                      ? {
                          'id': 'unsent-grant',
                          'role': remoteRole,
                          'scope': {
                            'type': 'user',
                            'value': 'friend@example.com',
                          },
                        }
                      : {
                          'id': 'unsent-grant',
                          'role': remoteRole,
                          'allowedRoles': ['read', 'write'],
                          'isRemovable': true,
                          'emailAddress': {'address': 'friend@example.com'},
                        },
                ),
                request.method == 'POST' ? 201 : 200,
              );
            }),
            requireNetwork: () async {
              if (offline) throw const NetworkUnavailableException();
            },
          );
          CloudCalendarSharingService create() => CloudCalendarSharingService(
            source: source,
            google: google
                ? GoogleCalendarApiClient(
                    httpClient: guardedHttp,
                    baseUri: Uri.parse('https://www.googleapis.com'),
                  )
                : null,
            microsoft: google
                ? null
                : MicrosoftCalendarApiClient(
                    httpClient: guardedHttp,
                    baseUri: Uri.parse('https://graph.microsoft.com/v1.0'),
                    responseTimeZone: 'UTC',
                    accountTenantId: 'tenant',
                  ),
          );
          final service = create();
          final initial = await service.load();
          expect(initial.grants.singleOrNull?.role, remoteRole);
          Future<CloudCalendarShareSnapshot> mutate(
            CloudCalendarSharingService target,
            CloudCalendarShareSnapshot snapshot,
          ) => switch (operation) {
            'add' => target.add(
              recipient: 'friend@example.com',
              role: initialRole,
            ),
            'change' => target.change(snapshot.grants.single, changedRole),
            _ => target.revoke(snapshot.grants.single),
          };
          offline = true;
          await expectLater(
            mutate(service, initial),
            throwsA(isA<RequestNotDispatchedException>()),
          );
          expect(providerMutations, 0);
          expect(remoteRole, operation == 'add' ? null : initialRole);
          expect(service.hasUnresolvedOutcome, isFalse);
          offline = false;
          final reopened = create();
          final baseline = await reopened.load();
          expect(baseline.outcomeUnknown, isFalse);
          expect(baseline.grants.singleOrNull?.role, remoteRole);
          final committed = await mutate(reopened, baseline);
          expect(committed.outcomeUnknown, isFalse);
          expect(providerMutations, 1);
          expect(committed.grants.singleOrNull?.role, remoteRole);
        },
      );
    }
  }

  test('acknowledged Google grant survives failed follow-up refresh', () async {
    var listCalls = 0;
    var postCalls = 0;
    final service = CloudCalendarSharingService(
      source: googleSource,
      google: GoogleCalendarApiClient(
        httpClient: MockClient((request) async {
          if (request.method == 'GET') {
            listCalls++;
            return listCalls == 1
                ? http.Response(jsonEncode({'items': <Object>[]}), 200)
                : http.Response('temporary failure', 503);
          }
          if (request.method == 'POST') {
            postCalls++;
            expect(jsonDecode(request.body), {
              'role': 'reader',
              'scope': {'type': 'user', 'value': 'friend@example.com'},
            });
            return http.Response(
              jsonEncode({
                'id': 'user:friend@example.com',
                'role': 'reader',
                'scope': {'type': 'user', 'value': 'friend@example.com'},
              }),
              200,
            );
          }
          fail('Unexpected request: ${request.method} ${request.url}');
        }),
        baseUri: Uri.parse('https://www.googleapis.com'),
      ),
    );
    expect((await service.load()).grants, isEmpty);
    final result = await service.add(
      recipient: 'friend@example.com',
      role: 'reader',
    );
    expect(result.refreshError, isNotNull);
    expect(result.grants.single.recipient, 'friend@example.com');
    expect(postCalls, 1);
  });

  test(
    'lost Google add response reconciles committed grant without retry',
    () async {
      var committed = false;
      var posts = 0;
      var gets = 0;
      final service = CloudCalendarSharingService(
        source: googleSource,
        google: GoogleCalendarApiClient(
          httpClient: MockClient((request) async {
            if (request.method == 'GET') {
              gets++;
              return http.Response(
                jsonEncode({
                  'items': committed
                      ? [
                          {
                            'id': 'user:friend@example.com',
                            'role': 'reader',
                            'scope': {
                              'type': 'user',
                              'value': 'friend@example.com',
                            },
                          },
                        ]
                      : <Object>[],
                }),
                200,
              );
            }
            if (request.method == 'POST') {
              posts++;
              committed = true;
              throw http.ClientException('response lost');
            }
            fail('Unexpected request');
          }),
          baseUri: Uri.parse('https://www.googleapis.com'),
        ),
      );
      await service.load();
      final result = await service.add(
        recipient: 'friend@example.com',
        role: 'reader',
      );
      expect(result.grants.single.recipient, 'friend@example.com');
      expect(posts, 1);
      expect(gets, 2);
    },
  );

  for (final provider in [BusyProvider.google, BusyProvider.microsoft]) {
    for (final kind in ['add', 'change', 'revoke']) {
      test(
        '$provider lost $kind response reconciles the targeted grant',
        () async {
          final google = provider == BusyProvider.google;
          final beforeRole = google ? 'reader' : 'read';
          final afterRole = google ? 'writer' : 'write';
          final source = CalendarSourceEntity(
            id: '$provider-$kind',
            accountId: 'account-$provider-$kind',
            provider: provider,
            providerCalendarId: 'calendar-$provider-$kind',
            summary: 'Calendar',
            selected: true,
            hidden: false,
            readOnly: false,
            isDeleted: false,
            accessRole: 'owner',
            primaryCalendar: !google,
          );
          String? remoteRole = kind == 'add' ? null : beforeRole;
          var mutations = 0;
          var reads = 0;
          Map<String, Object?> googleGrant() => {
            'id': 'grant-1',
            'role': remoteRole,
            'scope': {'type': 'user', 'value': 'friend@example.com'},
          };
          Map<String, Object?> microsoftGrant() => {
            'id': 'grant-1',
            'role': remoteRole,
            'allowedRoles': ['read', 'write'],
            'isRemovable': true,
            'emailAddress': {'address': 'friend@example.com'},
          };
          final httpClient = MockClient((request) async {
            if (request.method == 'GET') {
              reads++;
              return http.Response(
                jsonEncode(
                  google
                      ? {
                          'items': remoteRole == null
                              ? <Object>[]
                              : [googleGrant()],
                        }
                      : {
                          'value': remoteRole == null
                              ? <Object>[]
                              : [microsoftGrant()],
                        },
                ),
                200,
              );
            }
            mutations++;
            remoteRole = kind == 'revoke'
                ? null
                : kind == 'change'
                ? afterRole
                : beforeRole;
            throw http.ClientException('committed but response lost');
          });
          final service = CloudCalendarSharingService(
            source: source,
            google: google
                ? GoogleCalendarApiClient(
                    httpClient: httpClient,
                    baseUri: Uri.parse('https://www.googleapis.com'),
                  )
                : null,
            microsoft: google
                ? null
                : MicrosoftCalendarApiClient(
                    httpClient: httpClient,
                    baseUri: Uri.parse('https://graph.microsoft.com/v1.0'),
                    responseTimeZone: 'UTC',
                    accountTenantId: 'tenant',
                  ),
          );
          final baseline = await service.load();
          final result = switch (kind) {
            'add' => await service.add(
              recipient: 'friend@example.com',
              role: beforeRole,
            ),
            'change' => await service.change(baseline.grants.single, afterRole),
            _ => await service.revoke(baseline.grants.single),
          };
          expect(result.outcomeUnknown, isFalse);
          expect(result.grants.singleOrNull?.role, remoteRole);
          expect(mutations, 1);
          expect(reads, 2);
          expect(service.hasUnresolvedOutcome, isFalse);
        },
      );
    }
  }

  test(
    'failed and malformed reconciliation stays gated across reopened service',
    () async {
      final source = const CalendarSourceEntity(
        id: 'uncertain-source',
        accountId: 'uncertain-account',
        provider: BusyProvider.google,
        providerCalendarId: 'uncertain-calendar',
        summary: 'Calendar',
        selected: true,
        hidden: false,
        readOnly: false,
        isDeleted: false,
        accessRole: 'owner',
      );
      var committed = false;
      var malformed = false;
      var failed = false;
      var posts = 0;
      final client = GoogleCalendarApiClient(
        httpClient: MockClient((request) async {
          if (request.method == 'GET') {
            if (failed) return http.Response('unavailable', 503);
            if (malformed) return http.Response('{}', 200);
            return http.Response(
              jsonEncode({
                'items': committed
                    ? [
                        {
                          'id': 'grant-uncertain',
                          'role': 'reader',
                          'scope': {
                            'type': 'user',
                            'value': 'friend@example.com',
                          },
                        },
                      ]
                    : <Object>[],
              }),
              200,
            );
          }
          posts++;
          committed = true;
          failed = true;
          throw http.ClientException('response lost');
        }),
        baseUri: Uri.parse('https://www.googleapis.com'),
      );
      CloudCalendarSharingService create() =>
          CloudCalendarSharingService(source: source, google: client);
      final service = create();
      await service.load();
      final uncertain = await service.add(
        recipient: 'friend@example.com',
        role: 'reader',
      );
      expect(uncertain.outcomeUnknown, isTrue);
      expect(uncertain.refreshError, isNotNull);
      await expectLater(
        service.add(recipient: 'other@example.com', role: 'reader'),
        throwsStateError,
      );
      final reopened = create();
      expect((await reopened.load()).outcomeUnknown, isTrue);
      failed = false;
      malformed = true;
      expect((await reopened.load()).outcomeUnknown, isTrue);
      expect(posts, 1);
      malformed = false;
      final recovered = await reopened.load();
      expect(recovered.outcomeUnknown, isFalse);
      expect(recovered.grants.single.id, 'grant-uncertain');
      expect(reopened.hasUnresolvedOutcome, isFalse);
      expect(posts, 1);
    },
  );

  test(
    'partial ACL listing and source switch cannot release uncertain intent',
    () async {
      const sourceA = CalendarSourceEntity(
        id: 'partial-a',
        accountId: 'partial-account',
        provider: BusyProvider.google,
        providerCalendarId: 'partial-calendar-a',
        summary: 'A',
        selected: true,
        hidden: false,
        readOnly: false,
        isDeleted: false,
        accessRole: 'owner',
      );
      const sourceB = CalendarSourceEntity(
        id: 'partial-b',
        accountId: 'partial-account',
        provider: BusyProvider.google,
        providerCalendarId: 'partial-calendar-b',
        summary: 'B',
        selected: true,
        hidden: false,
        readOnly: false,
        isDeleted: false,
        accessRole: 'owner',
      );
      var committed = false;
      var secondPageFails = true;
      var posts = 0;
      final client = GoogleCalendarApiClient(
        httpClient: MockClient((request) async {
          if (request.method == 'POST') {
            posts++;
            committed = true;
            throw http.ClientException('response lost');
          }
          if (request.url.path.contains('partial-calendar-b')) {
            return http.Response(jsonEncode({'items': <Object>[]}), 200);
          }
          if (!committed) {
            return http.Response(jsonEncode({'items': <Object>[]}), 200);
          }
          if (request.url.queryParameters['pageToken'] == 'second') {
            if (secondPageFails) return http.Response('later page failed', 503);
            return http.Response(
              jsonEncode({
                'items': [
                  {
                    'id': 'partial-grant',
                    'role': 'reader',
                    'scope': {'type': 'user', 'value': 'friend@example.com'},
                  },
                ],
              }),
              200,
            );
          }
          return http.Response(
            jsonEncode({'items': <Object>[], 'nextPageToken': 'second'}),
            200,
          );
        }),
        baseUri: Uri.parse('https://www.googleapis.com'),
      );
      CloudCalendarSharingService forSource(CalendarSourceEntity source) =>
          CloudCalendarSharingService(source: source, google: client);
      final first = forSource(sourceA);
      await first.load();
      final uncertain = await first.add(
        recipient: 'friend@example.com',
        role: 'reader',
      );
      expect(uncertain.outcomeUnknown, isTrue);
      expect(uncertain.refreshError, isNotNull);
      final other = forSource(sourceB);
      expect((await other.load()).outcomeUnknown, isFalse);
      final reopened = forSource(sourceA);
      expect((await reopened.load()).outcomeUnknown, isTrue);
      await expectLater(
        reopened.add(recipient: 'friend@example.com', role: 'reader'),
        throwsStateError,
      );
      expect(posts, 1);
      secondPageFails = false;
      expect((await reopened.load()).outcomeUnknown, isFalse);
      expect(posts, 1);
    },
  );

  test(
    'unexpected remote sharing role remains unresolved, not rewritten',
    () async {
      const source = CalendarSourceEntity(
        id: 'unexpected-source',
        accountId: 'unexpected-account',
        provider: BusyProvider.google,
        providerCalendarId: 'unexpected-calendar',
        summary: 'Calendar',
        selected: true,
        hidden: false,
        readOnly: false,
        isDeleted: false,
        accessRole: 'owner',
      );
      var role = 'reader';
      var patches = 0;
      final client = GoogleCalendarApiClient(
        httpClient: MockClient((request) async {
          if (request.method == 'GET') {
            return http.Response(
              jsonEncode({
                'items': [
                  {
                    'id': 'grant',
                    'role': role,
                    'scope': {'type': 'user', 'value': 'friend@example.com'},
                  },
                ],
              }),
              200,
            );
          }
          patches++;
          role = 'freeBusyReader';
          throw http.ClientException('response lost');
        }),
        baseUri: Uri.parse('https://www.googleapis.com'),
      );
      final service = CloudCalendarSharingService(
        source: source,
        google: client,
      );
      final grant = (await service.load()).grants.single;
      final result = await service.change(grant, 'writer');
      expect(result.outcomeUnknown, isTrue);
      expect(result.grants.single.role, 'freeBusyReader');
      await expectLater(service.revoke(grant), throwsStateError);
      expect(patches, 1);
      role = 'writer';
      expect((await service.load()).outcomeUnknown, isFalse);
    },
  );

  test('definitive sharing rejection restores the mutation gate', () async {
    const source = CalendarSourceEntity(
      id: 'rejected-source',
      accountId: 'rejected-account',
      provider: BusyProvider.google,
      providerCalendarId: 'rejected-calendar',
      summary: 'Calendar',
      selected: true,
      hidden: false,
      readOnly: false,
      isDeleted: false,
      accessRole: 'owner',
    );
    var posts = 0;
    final service = CloudCalendarSharingService(
      source: source,
      google: GoogleCalendarApiClient(
        httpClient: MockClient((request) async {
          if (request.method == 'GET') {
            return http.Response(jsonEncode({'items': <Object>[]}), 200);
          }
          posts++;
          return http.Response('denied', 403);
        }),
        baseUri: Uri.parse('https://www.googleapis.com'),
      ),
    );
    await service.load();
    await expectLater(
      service.add(recipient: 'friend@example.com', role: 'reader'),
      throwsA(isA<GoogleCalendarApiError>()),
    );
    expect(service.hasUnresolvedOutcome, isFalse);
    expect(posts, 1);
  });

  test('Microsoft immutable grants cannot be changed or revoked', () async {
    final service = CloudCalendarSharingService(
      source: const CalendarSourceEntity(
        id: 'primary',
        accountId: 'account',
        provider: BusyProvider.microsoft,
        providerCalendarId: 'primary-id',
        summary: 'Calendar',
        selected: true,
        hidden: false,
        readOnly: false,
        isDeleted: false,
        primaryCalendar: true,
      ),
      microsoft: MicrosoftCalendarApiClient(
        httpClient: MockClient(
          (request) async => http.Response(
            jsonEncode({
              'value': [
                {
                  'id': 'owner',
                  'role': 'owner',
                  'allowedRoles': ['owner'],
                  'isRemovable': false,
                  'emailAddress': {'address': 'owner@example.com'},
                },
              ],
            }),
            200,
          ),
        ),
        baseUri: Uri.parse('https://graph.microsoft.com/v1.0'),
        responseTimeZone: 'UTC',
        accountTenantId: 'tenant',
      ),
    );
    final grant = (await service.load()).grants.single;
    expect(grant.canChange, isFalse);
    expect(grant.canRevoke, isFalse);
    await expectLater(service.change(grant, 'read'), throwsArgumentError);
    await expectLater(service.revoke(grant), throwsArgumentError);
  });

  testWidgets('native sharing content exposes add and refresh-failure retry', (
    tester,
  ) async {
    var gets = 0;
    var posts = 0;
    final client = GoogleCalendarApiClient(
      httpClient: MockClient((request) async {
        if (request.method == 'GET') {
          gets++;
          if (gets == 2) return http.Response('try again', 503);
          return http.Response(
            jsonEncode({
              'items': gets == 1
                  ? <Object>[]
                  : [
                      {
                        'id': 'grant',
                        'role': 'reader',
                        'scope': {
                          'type': 'user',
                          'value': 'friend@example.com',
                        },
                      },
                    ],
            }),
            200,
          );
        }
        if (request.method == 'POST') {
          posts++;
          return http.Response(
            jsonEncode({
              'id': 'grant',
              'role': 'reader',
              'scope': {'type': 'user', 'value': 'friend@example.com'},
            }),
            200,
          );
        }
        fail('Unexpected request');
      }),
      baseUri: Uri.parse('https://www.googleapis.com'),
    );
    await tester.pumpWidget(
      ProviderScope(
        child: localizedTestApp(
          child: Scaffold(
            body: CloudCalendarSharingContent(
              sources: const [googleSource],
              serviceFactory: (source) =>
                  CloudCalendarSharingService(source: source, google: client),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('calendar-sharing-recipient')),
      'friend@example.com',
    );
    await tester.tap(find.byKey(const Key('calendar-sharing-new-role-source')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Read all details').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('calendar-sharing-add')));
    await tester.pumpAndSettle();
    expect(posts, 1);
    expect(find.text('friend@example.com'), findsWidgets);
    expect(
      tester
          .widget<TextButton>(find.byKey(const Key('calendar-sharing-add')))
          .onPressed,
      isNull,
    );
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(gets, 3);
    expect(
      tester
          .widget<TextButton>(find.byKey(const Key('calendar-sharing-add')))
          .onPressed,
      isNotNull,
    );
  });

  for (final android in [false, true]) {
    testWidgets(
      '${android ? 'Android' : 'Linux'} known-unsent sharing add restores mutation controls',
      (tester) async {
        final source = CalendarSourceEntity(
          id: 'native-unsent-$android',
          accountId: 'native-unsent-account-$android',
          provider: BusyProvider.google,
          providerCalendarId: 'native-unsent-calendar-$android',
          summary: 'Calendar',
          selected: true,
          hidden: false,
          readOnly: false,
          isDeleted: false,
          accessRole: 'owner',
        );
        final preflight = Completer<void>();
        var blockDispatch = false;
        var providerMutations = 0;
        final client = GoogleCalendarApiClient(
          httpClient: ConnectivityAwareHttpClient(
            inner: MockClient((request) async {
              if (request.method == 'GET') {
                return http.Response(
                  jsonEncode({
                    'items': [
                      {
                        'id': 'existing-grant',
                        'role': 'reader',
                        'scope': {
                          'type': 'user',
                          'value': 'existing@example.com',
                        },
                      },
                      if (providerMutations > 0)
                        {
                          'id': 'new-grant',
                          'role': 'freeBusyReader',
                          'scope': {
                            'type': 'user',
                            'value': 'friend@example.com',
                          },
                        },
                    ],
                  }),
                  200,
                );
              }
              providerMutations++;
              return http.Response(
                jsonEncode({
                  'id': 'new-grant',
                  'role': 'freeBusyReader',
                  'scope': {'type': 'user', 'value': 'friend@example.com'},
                }),
                200,
              );
            }),
            requireNetwork: () async {
              if (blockDispatch) {
                await preflight.future;
                throw const NetworkUnavailableException();
              }
            },
          ),
          baseUri: Uri.parse('https://www.googleapis.com'),
        );
        Widget content() => android
            ? CloudCalendarSharingContent(
                sources: [source],
                serviceFactory: (s) =>
                    CloudCalendarSharingService(source: s, google: client),
              )
            : linux.CloudCalendarSharingContent(
                sources: [source],
                serviceFactory: (s) =>
                    CloudCalendarSharingService(source: s, google: client),
              );
        VoidCallback? addAction() => switch (tester.widget(
          find.byKey(const Key('calendar-sharing-add')),
        )) {
          TextButton button => button.onPressed,
          FilledButton button => button.onPressed,
          _ => throw StateError('Unexpected native Add control.'),
        };
        bool roleEnabled() {
          final grant = find.byKey(
            const Key('calendar-sharing-grant-existing-grant'),
          );
          return android
              ? tester
                    .widget<PopupMenuButton<String>>(
                      find.descendant(
                        of: grant,
                        matching: find.byType(PopupMenuButton<String>),
                      ),
                    )
                    .enabled
              : tester
                    .widget<BusyMaxMenuButton<String>>(
                      find.descendant(
                        of: grant,
                        matching: find.byType(BusyMaxMenuButton<String>),
                      ),
                    )
                    .enabled;
        }

        bool revokeEnabled() {
          final grant = find.byKey(
            const Key('calendar-sharing-grant-existing-grant'),
          );
          return android
              ? tester
                        .widget<IconButton>(
                          find.ancestor(
                            of: find.descendant(
                              of: grant,
                              matching: find.byIcon(
                                Icons.person_remove_outlined,
                              ),
                            ),
                            matching: find.byType(IconButton),
                          ),
                        )
                        .onPressed !=
                    null
              : tester
                        .widget<FilledButton>(
                          find.descendant(
                            of: grant,
                            matching: find.byType(FilledButton),
                          ),
                        )
                        .onPressed !=
                    null;
        }

        await tester.pumpWidget(
          ProviderScope(
            child: localizedTestApp(child: Scaffold(body: content())),
          ),
        );
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const Key('calendar-sharing-recipient')),
          'friend@example.com',
        );
        blockDispatch = true;
        await tester.tap(find.byKey(const Key('calendar-sharing-add')));
        await tester.pump();
        expect(addAction(), isNull);
        expect(providerMutations, 0);
        preflight.complete();
        for (var i = 0; i < 4; i++) {
          await tester.pump();
        }
        expect(
          find.textContaining('NetworkUnavailableException'),
          findsOneWidget,
        );
        expect(addAction(), isNotNull);
        expect(roleEnabled(), isTrue);
        expect(revokeEnabled(), isTrue);
        expect(providerMutations, 0);
        await tester.pumpWidget(const SizedBox());
        blockDispatch = false;
        await tester.pumpWidget(
          ProviderScope(
            child: localizedTestApp(child: Scaffold(body: content())),
          ),
        );
        await tester.pumpAndSettle();
        expect(addAction(), isNotNull);
        await tester.enterText(
          find.byKey(const Key('calendar-sharing-recipient')),
          'friend@example.com',
        );
        await tester.tap(find.byKey(const Key('calendar-sharing-add')));
        await tester.pumpAndSettle();
        expect(providerMutations, 1);
      },
    );

    testWidgets(
      '${android ? 'Android' : 'Linux'} sharing remains read-only after lost response and recovers on Refresh',
      (tester) async {
        final source = CalendarSourceEntity(
          id: 'native-uncertain-$android',
          accountId: 'native-account-$android',
          provider: BusyProvider.google,
          providerCalendarId: 'native-calendar-$android',
          summary: 'Calendar',
          selected: true,
          hidden: false,
          readOnly: false,
          isDeleted: false,
          accessRole: 'owner',
        );
        var posts = 0;
        var failReads = true;
        final heldRead = Completer<http.Response>();
        final client = GoogleCalendarApiClient(
          httpClient: MockClient((request) async {
            if (request.method == 'GET') {
              if (posts == 0) {
                return http.Response(jsonEncode({'items': <Object>[]}), 200);
              }
              if (failReads) return heldRead.future;
              return http.Response(
                jsonEncode({
                  'items': [
                    {
                      'id': 'native-grant',
                      'role': 'freeBusyReader',
                      'scope': {'type': 'user', 'value': 'friend@example.com'},
                    },
                  ],
                }),
                200,
              );
            }
            posts++;
            throw http.ClientException('response lost');
          }),
          baseUri: Uri.parse('https://www.googleapis.com'),
        );
        Widget content() => android
            ? CloudCalendarSharingContent(
                sources: [source],
                serviceFactory: (s) =>
                    CloudCalendarSharingService(source: s, google: client),
              )
            : linux.CloudCalendarSharingContent(
                sources: [source],
                serviceFactory: (s) =>
                    CloudCalendarSharingService(source: s, google: client),
              );
        VoidCallback? addAction() => switch (tester.widget(
          find.byKey(const Key('calendar-sharing-add')),
        )) {
          TextButton button => button.onPressed,
          FilledButton button => button.onPressed,
          _ => throw StateError('Unexpected native Add control.'),
        };
        await tester.pumpWidget(
          ProviderScope(
            child: localizedTestApp(child: Scaffold(body: content())),
          ),
        );
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const Key('calendar-sharing-recipient')),
          'friend@example.com',
        );
        await tester.tap(find.byKey(const Key('calendar-sharing-add')));
        for (var i = 0; i < 4; i++) {
          await tester.pump();
        }
        expect(posts, 1);
        expect(addAction(), isNull);
        heldRead.complete(http.Response('unavailable', 503));
        for (var i = 0; i < 4; i++) {
          await tester.pump();
        }
        expect(addAction(), isNull);
        expect(find.text('Retry'), findsOneWidget);
        // Recreating the native content must not discard the account/calendar gate.
        await tester.pumpWidget(const SizedBox());
        await tester.pumpWidget(
          ProviderScope(
            child: localizedTestApp(child: Scaffold(body: content())),
          ),
        );
        for (var i = 0; i < 5; i++) {
          await tester.pump();
        }
        expect(addAction(), isNull);
        failReads = false;
        await tester.tap(find.text('Retry'));
        await tester.pumpAndSettle();
        expect(posts, 1);
        expect(addAction(), isNotNull);
      },
    );
  }

  testWidgets(
    'Linux sharing content adds an explicit grant through native controls',
    (tester) async {
      final requests = <http.Request>[];
      final client = GoogleCalendarApiClient(
        httpClient: MockClient((request) async {
          requests.add(request);
          if (request.method == 'GET') {
            return http.Response(jsonEncode({'items': <Object>[]}), 200);
          }
          if (request.method == 'POST') {
            return http.Response(
              jsonEncode({
                'id': 'reader',
                'role': 'reader',
                'scope': {'type': 'user', 'value': 'friend@example.com'},
              }),
              200,
            );
          }
          fail('Unexpected request');
        }),
        baseUri: Uri.parse('https://www.googleapis.com'),
      );
      await tester.pumpWidget(
        ProviderScope(
          child: localizedTestApp(
            child: Scaffold(
              body: linux.CloudCalendarSharingContent(
                sources: const [googleSource],
                serviceFactory: (source) =>
                    CloudCalendarSharingService(source: source, google: client),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('calendar-sharing-recipient')),
        'friend@example.com',
      );
      tester
          .widget<BusyMaxMenuButton<String>>(
            find.byKey(const Key('calendar-sharing-new-role-source')),
          )
          .onSelected('reader');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('calendar-sharing-add')));
      await tester.pumpAndSettle();
      final post = requests.singleWhere((request) => request.method == 'POST');
      expect(jsonDecode(post.body), {
        'role': 'reader',
        'scope': {'type': 'user', 'value': 'friend@example.com'},
      });
    },
  );
}

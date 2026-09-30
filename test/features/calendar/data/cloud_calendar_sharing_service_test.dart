import 'dart:convert';

import 'package:busymax/src/features/calendar/data/calendar_repository.dart';
import 'package:busymax/src/app/busymax_design.dart';
import 'package:busymax/src/features/calendar/data/cloud_calendar_sharing_service.dart';
import 'package:busymax/src/android/presentation/android_cloud_calendar_sharing_content.dart';
import 'package:busymax/src/features/calendar/presentation/cloud_calendar_sharing_content.dart'
    as linux;
import 'package:busymax/src/google_calendar/google_calendar_api_client.dart';
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

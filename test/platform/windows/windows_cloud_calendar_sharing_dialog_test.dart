import 'dart:async';
import 'dart:convert';

import 'package:busymax/l10n/generated/app_localizations.dart';
import 'package:busymax/src/features/calendar/data/calendar_repository.dart';
import 'package:busymax/src/features/calendar/data/cloud_calendar_sharing_service.dart';
import 'package:busymax/src/features/connectivity/network_connectivity_service.dart';
import 'package:busymax/src/microsoft_calendar/microsoft_calendar_api_client.dart';
import 'package:busymax/src/providers/busy_provider.dart';
import 'package:busymax/src/ui/windows/windows_cloud_calendar_sharing_dialog.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  testWidgets('Windows known-unsent sharing add restores mutation controls', (
    tester,
  ) async {
    const source = CalendarSourceEntity(
      id: 'windows-unsent',
      accountId: 'windows-unsent-account',
      provider: BusyProvider.microsoft,
      providerCalendarId: 'windows-unsent-calendar',
      summary: 'My calendar',
      selected: true,
      hidden: false,
      readOnly: false,
      isDeleted: false,
      primaryCalendar: true,
    );
    final preflight = Completer<void>();
    var blockDispatch = false;
    var providerMutations = 0;
    final client = MicrosoftCalendarApiClient(
      httpClient: ConnectivityAwareHttpClient(
        inner: MockClient((request) async {
          if (request.method == 'GET') {
            return http.Response(
              jsonEncode({
                'value': [
                  {
                    'id': 'existing-grant',
                    'role': 'read',
                    'allowedRoles': ['read', 'write'],
                    'isRemovable': true,
                    'emailAddress': {'address': 'existing@example.com'},
                  },
                  if (providerMutations > 0)
                    {
                      'id': 'new-grant',
                      'role': 'freeBusyRead',
                      'allowedRoles': ['freeBusyRead', 'read'],
                      'isRemovable': true,
                      'emailAddress': {'address': 'friend@example.com'},
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
              'role': 'freeBusyRead',
              'allowedRoles': ['freeBusyRead', 'read'],
              'isRemovable': true,
              'emailAddress': {'address': 'friend@example.com'},
            }),
            201,
          );
        }),
        requireNetwork: () async {
          if (blockDispatch) {
            await preflight.future;
            throw const NetworkUnavailableException();
          }
        },
      ),
      baseUri: Uri.parse('https://graph.microsoft.com/v1.0'),
      responseTimeZone: 'UTC',
      accountTenantId: 'tenant',
    );
    await tester.pumpWidget(
      ProviderScope(
        child: FluentApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Button(
              onPressed: () => showWindowsCloudCalendarSharingDialog(
                context,
                sources: const [source],
                serviceFactory: (s) =>
                    CloudCalendarSharingService(source: s, microsoft: client),
              ),
              child: const Text('Open sharing'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open sharing'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('windows-sharing-recipient')),
      'friend@example.com',
    );
    await tester.ensureVisible(find.byKey(const Key('windows-sharing-add')));
    await tester.pumpAndSettle();
    blockDispatch = true;
    await tester.tap(find.byKey(const Key('windows-sharing-add')));
    await tester.pump();
    expect(providerMutations, 0);
    expect(
      tester
          .widget<Button>(find.byKey(const Key('windows-sharing-add')))
          .onPressed,
      isNull,
    );
    preflight.complete();
    for (var i = 0; i < 4; i++) {
      await tester.pump();
    }
    expect(find.textContaining('NetworkUnavailableException'), findsOneWidget);
    expect(
      tester
          .widget<Button>(find.byKey(const Key('windows-sharing-add')))
          .onPressed,
      isNotNull,
    );
    final existing = find.byKey(
      const Key('windows-sharing-grant-existing-grant'),
    );
    expect(
      tester
          .widget<Button>(
            find.ancestor(
              of: find.descendant(
                of: existing,
                matching: find.text('Revoke access'),
              ),
              matching: find.byType(Button),
            ),
          )
          .onPressed,
      isNotNull,
    );
    final roleButton = tester.widget<DropDownButton>(
      find.descendant(of: existing, matching: find.byType(DropDownButton)),
    );
    expect((roleButton.items.first as MenuFlyoutItem).onPressed, isNotNull);
    expect(providerMutations, 0);
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    blockDispatch = false;
    await tester.tap(find.text('Open sharing'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<Button>(find.byKey(const Key('windows-sharing-add')))
          .onPressed,
      isNotNull,
    );
    await tester.enterText(
      find.byKey(const Key('windows-sharing-recipient')),
      'friend@example.com',
    );
    await tester.ensureVisible(find.byKey(const Key('windows-sharing-add')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('windows-sharing-add')));
    await tester.pumpAndSettle();
    expect(providerMutations, 1);
  });

  testWidgets(
    'Windows lost sharing response keeps Add blocked across reopening',
    (tester) async {
      const source = CalendarSourceEntity(
        id: 'windows-uncertain',
        accountId: 'windows-uncertain-account',
        provider: BusyProvider.microsoft,
        providerCalendarId: 'primary-uncertain',
        summary: 'My calendar',
        selected: true,
        hidden: false,
        readOnly: false,
        isDeleted: false,
        primaryCalendar: true,
      );
      var posts = 0;
      var failed = true;
      final heldRead = Completer<http.Response>();
      final client = MicrosoftCalendarApiClient(
        httpClient: MockClient((request) async {
          if (request.method == 'GET') {
            if (posts == 0) {
              return http.Response(jsonEncode({'value': <Object>[]}), 200);
            }
            if (failed) return heldRead.future;
            return http.Response(
              jsonEncode({
                'value': [
                  {
                    'id': 'grant-windows',
                    'role': 'freeBusyRead',
                    'allowedRoles': ['freeBusyRead', 'read'],
                    'isRemovable': true,
                    'emailAddress': {'address': 'friend@example.com'},
                  },
                ],
              }),
              200,
            );
          }
          posts++;
          throw http.ClientException('response lost');
        }),
        baseUri: Uri.parse('https://graph.microsoft.com/v1.0'),
        responseTimeZone: 'UTC',
        accountTenantId: 'tenant',
      );
      await tester.pumpWidget(
        ProviderScope(
          child: FluentApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Builder(
              builder: (context) => Button(
                onPressed: () => showWindowsCloudCalendarSharingDialog(
                  context,
                  sources: const [source],
                  serviceFactory: (s) =>
                      CloudCalendarSharingService(source: s, microsoft: client),
                ),
                child: const Text('Open sharing'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open sharing'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('windows-sharing-recipient')),
        'friend@example.com',
      );
      await tester.ensureVisible(find.byKey(const Key('windows-sharing-add')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('windows-sharing-add')));
      for (var i = 0; i < 4; i++) {
        await tester.pump();
      }
      expect(posts, 1);
      expect(
        tester
            .widget<Button>(find.byKey(const Key('windows-sharing-add')))
            .onPressed,
        isNull,
      );
      heldRead.complete(http.Response('unavailable', 503));
      for (var i = 0; i < 4; i++) {
        await tester.pump();
      }
      expect(
        tester
            .widget<Button>(find.byKey(const Key('windows-sharing-add')))
            .onPressed,
        isNull,
      );
      expect(find.text('Retry'), findsOneWidget);
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open sharing'));
      for (var i = 0; i < 5; i++) {
        await tester.pump();
      }
      expect(
        tester
            .widget<Button>(find.byKey(const Key('windows-sharing-add')))
            .onPressed,
        isNull,
      );
      failed = false;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(posts, 1);
      expect(
        tester
            .widget<Button>(find.byKey(const Key('windows-sharing-add')))
            .onPressed,
        isNotNull,
      );
      await tester.pump(const Duration(milliseconds: 200));
    },
  );

  testWidgets('Windows sharing dialog adds a grant through Graph', (
    tester,
  ) async {
    const source = CalendarSourceEntity(
      id: 'primary',
      accountId: 'account',
      provider: BusyProvider.microsoft,
      providerCalendarId: 'primary',
      summary: 'My calendar',
      selected: true,
      hidden: false,
      readOnly: false,
      isDeleted: false,
      primaryCalendar: true,
    );
    var posts = 0;
    var listed = false;
    final client = MicrosoftCalendarApiClient(
      httpClient: MockClient((request) async {
        if (request.method == 'GET') {
          return http.Response(
            jsonEncode({
              'value': listed
                  ? [
                      {
                        'id': 'grant',
                        'role': 'freeBusyRead',
                        'allowedRoles': ['freeBusyRead', 'read'],
                        'isRemovable': true,
                        'emailAddress': {'address': 'friend@example.com'},
                      },
                    ]
                  : <Object>[],
            }),
            200,
          );
        }
        if (request.method == 'POST') {
          posts++;
          expect(jsonDecode(request.body), {
            'emailAddress': {'address': 'friend@example.com'},
            'role': 'freeBusyRead',
          });
          listed = true;
          return http.Response(
            jsonEncode({
              'id': 'grant',
              'role': 'freeBusyRead',
              'allowedRoles': ['freeBusyRead', 'read'],
              'isRemovable': true,
              'emailAddress': {'address': 'friend@example.com'},
            }),
            200,
          );
        }
        fail('Unexpected request: ${request.method}');
      }),
      baseUri: Uri.parse('https://graph.microsoft.com/v1.0'),
      responseTimeZone: 'UTC',
      accountTenantId: 'tenant',
    );
    await tester.pumpWidget(
      ProviderScope(
        child: FluentApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Button(
              onPressed: () => showWindowsCloudCalendarSharingDialog(
                context,
                sources: const [source],
                serviceFactory: (source) => CloudCalendarSharingService(
                  source: source,
                  microsoft: client,
                ),
              ),
              child: const Text('Open sharing'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open sharing'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('windows-sharing-recipient')),
      'friend@example.com',
    );
    await tester.ensureVisible(find.byKey(const Key('windows-sharing-add')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('windows-sharing-add')));
    await tester.pumpAndSettle();
    expect(posts, 1);
    expect(find.text('friend@example.com'), findsOneWidget);
  });
}

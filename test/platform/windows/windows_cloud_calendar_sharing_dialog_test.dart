import 'dart:convert';

import 'package:busymax/l10n/generated/app_localizations.dart';
import 'package:busymax/src/features/calendar/data/calendar_repository.dart';
import 'package:busymax/src/features/calendar/data/cloud_calendar_sharing_service.dart';
import 'package:busymax/src/microsoft_calendar/microsoft_calendar_api_client.dart';
import 'package:busymax/src/providers/busy_provider.dart';
import 'package:busymax/src/ui/windows/windows_cloud_calendar_sharing_dialog.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
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

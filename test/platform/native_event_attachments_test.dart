import 'dart:convert';

import 'package:busymax/l10n/generated/app_localizations.dart';
import 'package:busymax/src/android/presentation/android_event_attachments_dialog.dart';
import 'package:busymax/src/app/app_bootstrap.dart';
import 'package:busymax/src/features/schedule/presentation/linux_event_attachments_dialog.dart';
import 'package:busymax/src/microsoft_calendar/microsoft_calendar_api_client.dart';
import 'package:busymax/src/providers/busy_provider.dart';
import 'package:busymax/src/schedule/schedule_item.dart';
import 'package:busymax/src/ui/windows/windows_event_attachments_dialog.dart';
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../test_localized_app.dart';

const _event = CalendarScheduleItem(
  id: 'local-event',
  accountId: 'microsoft:a',
  provider: BusyProvider.microsoft,
  sourceId: 'local-calendar',
  providerCalendarId: 'remote-calendar',
  providerEventId: 'remote-event',
  title: 'Planning',
  allDay: false,
);

void main() {
  for (final platform in ['Linux', 'Windows', 'Android']) {
    testWidgets('$platform event attachment dialog loads only when opened', (
      tester,
    ) async {
      var requests = 0;
      final client = MicrosoftCalendarApiClient(
        httpClient: MockClient((request) async {
          requests++;
          expect(
            request.url.path,
            '/v1.0/me/calendars/remote-calendar/events/remote-event/attachments',
          );
          return http.Response(
            jsonEncode({
              'value': [
                {
                  'id': 'file',
                  'name': 'Agenda.pdf',
                  'size': 4,
                  '@odata.type': '#microsoft.graph.fileAttachment',
                },
              ],
            }),
            200,
          );
        }),
        baseUri: Uri.parse('https://graph.microsoft.com/v1.0'),
        responseTimeZone: 'UTC',
      );
      final launcher = Builder(
        builder: (context) => platform == 'Windows'
            ? fluent.Button(
                onPressed: () =>
                    showWindowsEventAttachmentsDialog(context, _event),
                child: const fluent.Text('Open attachments'),
              )
            : TextButton(
                onPressed: () => platform == 'Android'
                    ? showAndroidEventAttachmentsDialog(context, _event)
                    : showLinuxEventAttachmentsDialog(context, _event),
                child: const Text('Open attachments'),
              ),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            microsoftCalendarApiClientForAccountProvider(
              'microsoft:a',
            ).overrideWithValue(client),
          ],
          child: platform == 'Windows'
              ? fluent.FluentApp(
                  localizationsDelegates: const [AppLocalizations.delegate],
                  supportedLocales: AppLocalizations.supportedLocales,
                  home: launcher,
                )
              : localizedTestApp(child: Scaffold(body: launcher)),
        ),
      );
      expect(requests, 0);
      await tester.tap(find.text('Open attachments'));
      await tester.pumpAndSettle();
      expect(requests, 1);
      expect(find.text('Agenda.pdf'), findsOneWidget);
      expect(find.text('4 B'), findsOneWidget);
    });

    testWidgets('$platform removes a Microsoft attachment only after confirmation', (
      tester,
    ) async {
      var deletes = 0;
      final client = MicrosoftCalendarApiClient(
        httpClient: MockClient((request) async {
          if (request.method == 'DELETE') {
            deletes++;
            expect(
              request.url.path,
              '/v1.0/me/calendars/remote-calendar/events/remote-event/attachments/file',
            );
            return http.Response('', 204);
          }
          return http.Response(
            jsonEncode({
              'value': deletes == 0
                  ? [
                      {
                        'id': 'file',
                        'name': 'Agenda.pdf',
                        'size': 4,
                        '@odata.type': '#microsoft.graph.fileAttachment',
                      },
                    ]
                  : <Object>[],
            }),
            200,
          );
        }),
        baseUri: Uri.parse('https://graph.microsoft.com/v1.0'),
        responseTimeZone: 'UTC',
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            microsoftCalendarApiClientForAccountProvider(
              'microsoft:a',
            ).overrideWithValue(client),
          ],
          child: platform == 'Windows'
              ? fluent.FluentApp(
                  localizationsDelegates: const [AppLocalizations.delegate],
                  supportedLocales: AppLocalizations.supportedLocales,
                  home: fluent.Button(
                    onPressed: () => showWindowsEventAttachmentsDialog(
                      tester.element(find.byType(fluent.Button).first),
                      _event,
                    ),
                    child: const fluent.Text('Open attachments'),
                  ),
                )
              : localizedTestApp(
                  child: Scaffold(
                    body: Builder(
                      builder: (context) => TextButton(
                        onPressed: () => platform == 'Android'
                            ? showAndroidEventAttachmentsDialog(context, _event)
                            : showLinuxEventAttachmentsDialog(context, _event),
                        child: const Text('Open attachments'),
                      ),
                    ),
                  ),
                ),
        ),
      );
      await tester.tap(find.text('Open attachments'));
      await tester.pumpAndSettle();
      if (platform == 'Android') {
        await tester.tap(find.byTooltip('Delete').last);
      } else {
        await tester.tap(find.text('Delete').last);
      }
      await tester.pumpAndSettle();
      expect(deletes, 0);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(deletes, 0);
      if (platform == 'Android') {
        await tester.tap(find.byTooltip('Delete').last);
      } else {
        await tester.tap(find.text('Delete').last);
      }
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete').last);
      await tester.pumpAndSettle();
      expect(deletes, 1);
    });
  }
}

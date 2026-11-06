import 'package:busymax/l10n/generated/app_localizations.dart';
import 'package:busymax/src/dav/auth/caldav_credential_input.dart';
import 'package:busymax/src/dav/auth/dav_account_dialogs.dart';
import 'package:busymax/src/ui/windows/windows_dav_account_dialogs.dart';
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../test_localized_app.dart';

void main() {
  for (final windows in [false, true]) {
    testWidgets(
      '${windows ? 'Windows' : 'Material'} CalDAV validates HTTPS and retains exact credentials',
      (tester) async {
        late BuildContext host;
        final home = Builder(
          builder: (context) {
            host = context;
            return const SizedBox();
          },
        );
        await tester.pumpWidget(
          windows
              ? fluent.FluentApp(
                  localizationsDelegates:
                      AppLocalizations.localizationsDelegates,
                  supportedLocales: AppLocalizations.supportedLocales,
                  home: home,
                )
              : localizedTestApp(child: home),
        );
        Future<CalDavCredentialInput?> open({String? server, String? user}) =>
            windows
            ? showWindowsCalDavCredentialDialog(
                host,
                fixedServer: server,
                fixedUsername: user,
              )
            : showCalDavCredentialDialog(
                host,
                fixedServer: server,
                fixedUsername: user,
              );
        final pending = open();
        await tester.pumpAndSettle();
        final server = find.byKey(const Key('caldav-server-field'));
        final user = find.byKey(const Key('caldav-username-field'));
        final password = find.byKey(const Key('caldav-password-field'));
        await tester.enterText(server, 'http://calendar.example.test/');
        await tester.enterText(user, 'ExactUser');
        await tester.enterText(password, ' exact password ');
        await tester.tap(find.text('Connect'));
        await tester.pumpAndSettle();
        expect(server, findsOneWidget);
        expect(
          find.text(AppLocalizations.of(host).caldavInvalidServerUrl),
          findsOneWidget,
        );
        const endpoint = 'https://calendar.example.test:8443/install/a%2Fb/';
        await tester.enterText(server, endpoint);
        await tester.tap(find.text('Connect'));
        await tester.pumpAndSettle();
        final accepted = (await pending)!;
        expect(accepted.serverUrl, endpoint);
        expect(accepted.username, 'ExactUser');
        expect(accepted.password, ' exact password ');
        expect(accepted.toString(), isNot(contains('exact password')));
        final reconnect = open(server: endpoint, user: 'ExactUser');
        await tester.pumpAndSettle();
        final serverEditor = tester.widget<EditableText>(
          find.descendant(of: server, matching: find.byType(EditableText)),
        );
        expect(serverEditor.readOnly, isTrue);
        expect(serverEditor.controller.text, endpoint);
        expect(
          tester
              .widget<EditableText>(
                find.descendant(
                  of: password,
                  matching: find.byType(EditableText),
                ),
              )
              .obscureText,
          isTrue,
        );
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        expect(await reconnect, isNull);
        expect(tester.takeException(), isNull);
      },
    );
  }
}

import 'package:busymax/src/app/busymax_design.dart';
import 'package:busymax/src/app/busymax_yaru_theme.dart';
import 'package:busymax/src/dav/auth/dav_account_dialogs.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yaru/yaru.dart';

import '../../test_localized_app.dart';

void main() {
  testWidgets('Nextcloud form explains and accepts a copied CalDAV address', (
    tester,
  ) async {
    final hostContext = await _pumpHost(tester);

    final result = showNextcloudServerDialog(hostContext);
    await tester.pumpAndSettle();

    expect(find.byType(BusyMaxDialogShell), findsOneWidget);
    expect(find.byType(BusyMaxGroupedList), findsOneWidget);
    expect(find.byType(YaruListTile), findsOneWidget);
    final field = tester.widget<TextField>(
      find.byKey(const Key('nextcloud-server-field')),
    );
    expect(field.decoration?.labelText, 'Nextcloud server or CalDAV address');
    expect(
      field.decoration?.hintText,
      'https://cloud.example.com/remote.php/dav',
    );
    expect(
      find.text(
        'Enter your Nextcloud server URL, or paste the primary CalDAV address '
        'copied from Nextcloud.',
      ),
      findsOneWidget,
    );
    expect(field.decoration?.helperText, isNull);
    expect(field.decoration?.border, InputBorder.none);
    expect(field.decoration?.filled, isFalse);
    final serverHelp = tester.widget<Text>(
      find.text(
        'Enter your Nextcloud server URL, or paste the primary CalDAV address '
        'copied from Nextcloud.',
      ),
    );
    final authorizationHelp = tester.widget<Text>(
      find.text(
        'BusyMax will open your browser. Approve access there, then return to '
        'BusyMax.',
      ),
    );
    expect(serverHelp.style, authorizationHelp.style);

    const copiedAddress = ' https://cloud.example.test/remote.php/dav ';
    await tester.enterText(
      find.byKey(const Key('nextcloud-server-field')),
      copiedAddress,
    );
    await tester.tap(find.text('Connect'));
    await tester.pumpAndSettle();

    expect(await result, copiedAddress.trim());
  });

  testWidgets('Nextcloud validates keyboard submission, prefill, and cancel', (
    tester,
  ) async {
    final hostContext = await _pumpHost(tester);
    final result = showNextcloudServerDialog(
      hostContext,
      initialServer: 'https://cloud.example.test',
    );
    await tester.pumpAndSettle();

    final finder = find.byKey(const Key('nextcloud-server-field'));
    expect(
      tester.widget<TextField>(finder).controller!.text,
      'https://cloud.example.test',
    );
    await tester.enterText(finder, '   ');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(finder, findsOneWidget);
    expect(tester.widget<TextField>(finder).decoration?.errorText, isNotEmpty);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(await result, isNull);
  });

  testWidgets(
    'Apple form preserves reconnect focus, validation, and redaction',
    (tester) async {
      final hostContext = await _pumpHost(tester);
      final result = showAppleICloudCredentialDialog(
        hostContext,
        fixedEmail: 'person@example.test',
      );
      await tester.pumpAndSettle();

      expect(find.byType(BusyMaxGroupedList), findsOneWidget);
      expect(find.byType(YaruListTile), findsNWidgets(2));
      final emailFinder = find.byKey(const Key('apple-account-email-field'));
      final passwordFinder = find.byKey(
        const Key('apple-app-specific-password-field'),
      );
      final email = tester.widget<TextField>(emailFinder);
      final password = tester.widget<TextField>(passwordFinder);
      expect(email.readOnly, isTrue);
      expect(email.controller!.text, 'person@example.test');
      expect(email.autofocus, isFalse);
      expect(password.autofocus, isTrue);
      expect(password.obscureText, isTrue);
      expect(password.enableSuggestions, isFalse);
      expect(password.autocorrect, isFalse);
      expect(password.decoration?.border, InputBorder.none);
      await tester.tap(find.text('Connect'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(passwordFinder).decoration?.errorText,
        isNotEmpty,
      );

      await tester.enterText(passwordFinder, ' app-password ');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      final input = await result;
      expect(input?.email, 'person@example.test');
      expect(input?.password, 'app-password');
      expect(input.toString(), contains('[REDACTED]'));
      expect(input.toString(), isNot(contains('app-password')));
    },
  );

  testWidgets('account form remains usable in a narrow dark RTL window', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(420, 520));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final hostContext = await _pumpHost(
      tester,
      locale: const Locale('ar'),
      brightness: Brightness.dark,
      textScaler: const TextScaler.linear(1.4),
    );
    final result = showNextcloudServerDialog(hostContext);
    await tester.pumpAndSettle();

    expect(
      Directionality.of(tester.element(find.byType(BusyMaxDialogShell))),
      TextDirection.rtl,
    );
    expect(find.byType(BusyMaxGroupedList), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('إلغاء'));
    await tester.pumpAndSettle();
    expect(await result, isNull);
  });
}

Future<BuildContext> _pumpHost(
  WidgetTester tester, {
  Locale locale = const Locale('en'),
  Brightness brightness = Brightness.light,
  TextScaler? textScaler,
}) async {
  late BuildContext hostContext;
  await tester.pumpWidget(
    localizedTestApp(
      locale: locale,
      textScaler: textScaler,
      theme: BusyMaxYaruTheme.build(
        brightness: brightness,
        accentColor: YaruColors.orange,
      ),
      child: Builder(
        builder: (context) {
          hostContext = context;
          return const SizedBox.shrink();
        },
      ),
    ),
  );
  return hostContext;
}

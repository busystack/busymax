import 'dart:io';

import 'package:busymax/src/app/busymax_about_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_localized_app.dart';

void main() {
  testWidgets('about dialog shows app identity and app links', (tester) async {
    await tester.pumpWidget(
      localizedTestApp(child: const BusyMaxAboutDialog()),
    );

    expect(find.text('BusyMax'), findsOneWidget);
    expect(find.text('ToDo and Calendar'), findsOneWidget);
    expect(find.text('Website'), findsOneWidget);
    expect(find.text('Send feedback'), findsOneWidget);
    expect(find.text('Report an issue'), findsOneWidget);
    expect(find.byIcon(Icons.close), findsOneWidget);
    expect(find.text('Close'), findsNothing);
  });

  test('about links point to BusyStack repository', () {
    final source = File(
      'lib/src/app/busymax_about_dialog.dart',
    ).readAsStringSync();

    expect(source, contains('https://github.com/busystack/busymax'));
    expect(source, contains('https://github.com/busystack/busymax/issues'));
    expect(source, isNot(contains('https://github.com/albertgee/busymax')));
  });

  test('about dialog uses native headerbar dimming and Yaru close button', () {
    final source = File(
      'lib/src/app/busymax_about_dialog.dart',
    ).readAsStringSync();
    final dialogs = File('lib/src/app/busymax_dialogs.dart').readAsStringSync();

    expect(source, contains('showBusyMaxModalDialog'));
    expect(source, contains('headerBarService: headerBarService'));
    expect(dialogs, contains('acquireBusyMaxModalBarrier'));
    expect(dialogs, contains('releaseBusyMaxModalBarrier'));
    expect(dialogs, contains('setModalBarrierVisible(true)'));
    expect(dialogs, contains('setModalBarrierVisible(false)'));
    expect(source, isNot(contains('barrierColor: Colors.transparent')));
    expect(source, contains('YaruIconButton('));
    expect(source, isNot(contains('BusyMaxDialogCloseButton')));
  });

  test('about logo renders the PNG asset, not the launcher SVG', () {
    final source = File(
      'lib/src/app/busymax_about_dialog.dart',
    ).readAsStringSync();
    final pubspec = File('pubspec.yaml').readAsStringSync();

    expect(source, contains('Image.asset'));
    expect(source, contains('assets/branding/busymax-logo.png'));
    expect(source, isNot(contains('assets/branding/busymax-logo.svg')));
    expect(source, isNot(contains('Image.memory')));
    expect(pubspec, contains('assets/branding/busymax-logo.png'));
    expect(source, isNot(contains('YaruIcons.calendar')));
  });
}

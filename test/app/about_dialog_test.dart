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

  test(
    'about dialog uses native headerbar dimming and circular close button',
    () {
      final source = File(
        'lib/src/app/busymax_about_dialog.dart',
      ).readAsStringSync();
      final design = File('lib/src/app/busymax_design.dart').readAsStringSync();

      expect(source, contains('setModalBarrierVisible(true)'));
      expect(source, contains('setModalBarrierVisible(false)'));
      expect(source, isNot(contains('barrierColor: Colors.transparent')));
      expect(source, contains('BusyMaxDialogCloseButton'));
      expect(design, contains('CircleBorder()'));
      expect(design, contains('color: surfaceColors.control'));
      expect(design, contains('BusyMaxSizes.aboutCloseButton'));
      expect(design, contains('BusyMaxSizes.iconSm'));
    },
  );

  test('about logo does not depend on AssetManifest.bin', () {
    final source = File(
      'lib/src/app/busymax_about_dialog.dart',
    ).readAsStringSync();

    expect(source, isNot(contains('Image.asset')));
    expect(source, contains('rootBundle.load'));
    expect(source, contains('_loadLogoFileBytes'));
    expect(source, contains("p.join(executableDir, 'data', 'flutter_assets'"));
    expect(source, isNot(contains('YaruIcons.calendar')));
  });
}

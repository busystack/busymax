import 'dart:io';

import 'package:busymax/src/app/busymax_about_dialog.dart';
import 'package:busymax/src/app/busymax_design.dart';
import 'package:busymax/src/app/busymax_yaru_theme.dart';
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

  for (final (brightness, dialogColor, popoverColor) in const [
    (Brightness.light, Color(0xFFFAFAFA), Color(0xFFFAFAFA)),
    (Brightness.dark, Color(0xFF3E3E3E), Color(0xFF3E3E3E)),
  ]) {
    testWidgets('about dialog keeps grouped content distinct in $brightness', (
      tester,
    ) async {
      final theme = BusyMaxYaruTheme.build(
        brightness: brightness,
        accentColor: const Color(0xFF3584E4),
      );
      final colors = theme.extension<BusyMaxSurfaceColors>()!;

      await tester.pumpWidget(
        localizedTestApp(theme: theme, child: const BusyMaxAboutDialog()),
      );

      final dialogMaterials = tester.widgetList<Material>(
        find.descendant(
          of: find.byType(Dialog),
          matching: find.byType(Material),
        ),
      );
      final groupedMaterial = tester.widget<Material>(
        find.descendant(
          of: find.byType(BusyMaxGroupedSurface),
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is Material && widget.elevation == BusyMaxElevation.card,
          ),
        ),
      );
      final expectedGroupedColor = Color.alphaBlend(
        colors.groupedSurface,
        colors.dialog,
      );

      expect(colors.dialog, dialogColor);
      expect(colors.popover, popoverColor);
      expect(colors.dialog, isNot(colors.sidebar));
      expect(
        dialogMaterials.any((material) => material.color == dialogColor),
        isTrue,
      );
      expect(
        groupedMaterial.color?.toARGB32(),
        expectedGroupedColor.toARGB32(),
      );
      expect(groupedMaterial.color, isNot(dialogColor));
      if (brightness == Brightness.dark) {
        expect(
          groupedMaterial.color?.toARGB32(),
          isNot(colors.card.toARGB32()),
        );
        expect(
          groupedMaterial.color!.computeLuminance(),
          greaterThan(colors.dialog.computeLuminance()),
        );
      }
    });
  }

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

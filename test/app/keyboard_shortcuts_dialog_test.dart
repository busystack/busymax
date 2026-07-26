import 'dart:io';

import 'package:busymax/src/app/busymax_design.dart';
import 'package:busymax/src/app/busymax_keyboard_shortcuts_dialog.dart';
import 'package:busymax/src/app/busymax_yaru_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_localized_app.dart';

void main() {
  testWidgets('keyboard shortcuts dialog shows shortcut reference', (
    tester,
  ) async {
    await tester.pumpWidget(
      localizedTestApp(child: const BusyMaxKeyboardShortcutsDialog()),
    );

    expect(find.text('Keyboard Shortcuts'), findsNWidgets(2));
    expect(find.text('General'), findsOneWidget);
    expect(find.text('Navigation'), findsOneWidget);
    expect(find.text('View'), findsOneWidget);
    expect(find.text('Create and Edit'), findsOneWidget);
    expect(find.text('Task editing'), findsOneWidget);
    expect(find.text('Compact agenda'), findsOneWidget);
    expect(find.text('Ctrl+/'), findsOneWidget);
    expect(find.text('Ctrl+,'), findsOneWidget);
    expect(find.text('Ctrl+F'), findsOneWidget);
    expect(find.text('Ctrl+N'), findsOneWidget);
    expect(find.text('Shift+Right'), findsOneWidget);
    expect(find.text('Shift+Left'), findsOneWidget);
    expect(find.text('T'), findsOneWidget);
    expect(find.text('Shift+T'), findsOneWidget);
    expect(find.text('E'), findsOneWidget);
    expect(find.text('1 / D'), findsOneWidget);
    expect(find.text('2 / W'), findsOneWidget);
    expect(find.text('3 / M'), findsOneWidget);
    expect(find.text('4 / Y'), findsOneWidget);
    expect(find.text('0 / A'), findsOneWidget);
    expect(find.text('Ctrl+S'), findsOneWidget);
    expect(find.text('Backspace / Delete'), findsOneWidget);
    expect(find.text('Ctrl+R'), findsOneWidget);
    expect(find.text('Esc'), findsNWidgets(2));
    expect(find.byIcon(Icons.close), findsWidgets);
    expect(find.text('Close'), findsNothing);
  });

  for (final brightness in Brightness.values) {
    testWidgets(
      'keyboard shortcut groups resolve the contextual $brightness dialog card',
      (tester) async {
        final theme = BusyMaxYaruTheme.build(
          brightness: brightness,
          accentColor: const Color(0xFFE95420),
        );
        final colors = theme.extension<BusyMaxSurfaceColors>()!;
        final expectedGroupedColor = Color.alphaBlend(
          colors.groupedSurface,
          colors.dialog,
        );
        final expectedDialogSide = BorderSide(color: colors.dialogOutline);

        await tester.pumpWidget(
          localizedTestApp(
            theme: theme,
            child: const BusyMaxKeyboardShortcutsDialog(),
          ),
        );

        final groupedMaterials = tester
            .widgetList<Material>(
              find.descendant(
                of: find.byType(BusyMaxGroupedSurface),
                matching: find.byType(Material),
              ),
            )
            .where((material) => material.elevation == BusyMaxElevation.card)
            .toList();

        expect(groupedMaterials, hasLength(6));
        expect(
          groupedMaterials.every(
            (material) =>
                material.color?.toARGB32() == expectedGroupedColor.toARGB32(),
          ),
          isTrue,
        );
        final dialog = tester.widget<Dialog>(find.byType(Dialog));
        final dialogShape =
            (dialog.shape ?? theme.dialogTheme.shape)!
                as RoundedRectangleBorder;
        expect(dialogShape.side, expectedDialogSide);
        expect(dialogShape.side.color, isNot(colors.floatingBorder));
        if (brightness == Brightness.dark) {
          expect(
            expectedGroupedColor.toARGB32(),
            isNot(colors.card.toARGB32()),
          );
          expect(
            expectedGroupedColor.computeLuminance(),
            greaterThan(colors.dialog.computeLuminance()),
          );
        }
      },
    );
  }

  test('keyboard shortcuts are available from native headerbar menu', () {
    final app = File('lib/src/app/busymax_app.dart').readAsStringSync();
    final service = File(
      'lib/src/platform/linux_header_bar_service.dart',
    ).readAsStringSync();
    final shortcuts = File(
      'lib/src/app/busymax_shortcuts.dart',
    ).readAsStringSync();
    final native = File('linux/runner/my_application.cc').readAsStringSync();

    expect(app, contains('keyboardShortcuts: l10n.keyboardShortcuts'));
    expect(app, contains('BusyMaxShortcutActivators.keyboardShortcuts'));
    expect(shortcuts, contains('LogicalKeyboardKey.slash'));
    expect(shortcuts, contains('LogicalKeyboardKey.comma'));
    expect(service, contains('keyboardShortcuts'));
    expect(native, contains('"Keyboard Shortcuts"'));
    expect(native, contains('"keyboardShortcuts"'));
  });
}

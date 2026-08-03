import 'dart:io';

import 'package:busymax/src/app/busymax_design.dart';
import 'package:busymax/src/app/busymax_dialog_identity.dart';
import 'package:busymax/src/app/busymax_keyboard_shortcuts_dialog.dart';
import 'package:busymax/src/app/busymax_yaru_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yaru/yaru.dart';

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
    expect(find.text('Compact agenda'), findsNothing);
    expect(find.text('Ctrl+Alt+K'), findsOneWidget);
    expect(find.text('Ctrl+Alt+S'), findsOneWidget);
    expect(find.text('Ctrl+F'), findsOneWidget);
    expect(find.text('F9'), findsOneWidget);
    expect(find.text('Ctrl+N'), findsNothing);
    expect(find.text('Shift+Right'), findsOneWidget);
    expect(find.text('Shift+Left'), findsOneWidget);
    expect(find.text('T'), findsOneWidget);
    expect(find.text('Shift+T'), findsOneWidget);
    expect(find.text('E'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('4'), findsOneWidget);
    expect(find.text('5'), findsOneWidget);
    expect(find.text('0'), findsNothing);
    expect(find.text('Ctrl+S'), findsOneWidget);
    expect(find.text('Backspace / Delete'), findsOneWidget);
    expect(find.text('Ctrl+R'), findsNothing);
    expect(find.text('Esc'), findsOneWidget);
    expect(find.byIcon(Icons.close), findsWidgets);
    expect(find.byType(YaruDialogTitleBar), findsOneWidget);
    expect(find.byType(YaruWindowControl), findsOneWidget);
    expect(find.text('Close'), findsNothing);

    final identity = find.byType(BusyMaxDialogIdentity);
    final title = tester.widget<Text>(
      find.descendant(of: identity, matching: find.text('Keyboard Shortcuts')),
    );
    final hero = tester.widget<Icon>(
      find.descendant(
        of: identity,
        matching: find.byIcon(YaruIcons.keyboard_shortcuts),
      ),
    );
    expect(identity, findsOneWidget);
    expect(hero.size, BusyMaxDialogIdentity.visualExtent);
    expect(title.style?.fontWeight, BusyMaxDialogIdentity.titleWeight);

    final titleBar = tester.widget<YaruDialogTitleBar>(
      find.byType(YaruDialogTitleBar),
    );
    final closeButton = tester.widget<YaruWindowControl>(
      find.byType(YaruWindowControl),
    );
    expect(titleBar.isActive, isTrue);
    expect(titleBar.border, BorderSide.none);
    expect(closeButton.type, YaruWindowControlType.close);
    expect(
      tester.getSize(find.byType(YaruWindowControl)),
      const Size.square(kYaruWindowControlSize),
    );

    final badgeEnds = [
      'Ctrl+Alt+K',
      'Ctrl+Alt+S',
      'Ctrl+F',
      'F9',
    ].map((label) => tester.getTopRight(find.text(label)).dx).toList();
    expect(badgeEnds.every((end) => end == badgeEnds.first), isTrue);
  });

  for (final textScale in [1.0, 2.0]) {
    testWidgets('keyboard shortcuts remain scrollable in a short window at '
        '${textScale}x text', (tester) async {
      tester.view
        ..devicePixelRatio = 1
        ..physicalSize = const Size(480, 320);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        localizedTestApp(
          textScaler: TextScaler.linear(textScale),
          child: const BusyMaxKeyboardShortcutsDialog(),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(
        tester.widget<Dialog>(find.byType(Dialog)).clipBehavior,
        Clip.antiAlias,
      );
      final scrollView = find.byType(SingleChildScrollView);
      final closeButton = find.byType(YaruWindowControl);
      expect(scrollView, findsOneWidget);
      expect(closeButton.hitTestable(), findsOneWidget);
      final closePosition = tester.getTopLeft(closeButton);

      await tester.scrollUntilVisible(
        find.text('Agenda view'),
        400,
        scrollable: find.byType(Scrollable),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Agenda view').hitTestable(), findsOneWidget);
      expect(closeButton.hitTestable(), findsOneWidget);
      expect(tester.getTopLeft(closeButton), closePosition);
    });
  }

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
            .where(
              (material) =>
                  material.color?.toARGB32() == expectedGroupedColor.toARGB32(),
            )
            .toList();
        final groupedCards = tester
            .widgetList<Card>(
              find.descendant(
                of: find.byType(BusyMaxGroupedSurface),
                matching: find.byType(Card),
              ),
            )
            .toList();

        expect(groupedMaterials, hasLength(5));
        expect(
          groupedMaterials.every(
            (material) =>
                material.color?.toARGB32() == expectedGroupedColor.toARGB32(),
          ),
          isTrue,
        );
        expect(
          groupedMaterials.every(
            (material) => material.elevation == theme.cardTheme.elevation,
          ),
          isTrue,
        );
        expect(groupedCards, hasLength(5));
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
    expect(shortcuts, contains('LogicalKeyboardKey.keyK'));
    expect(shortcuts, contains('LogicalKeyboardKey.keyS'));
    expect(shortcuts, contains('LogicalKeyboardKey.f9'));
    expect(service, contains('keyboardShortcuts'));
    expect(native, contains('"Keyboard Shortcuts"'));
    expect(native, contains('"keyboardShortcuts"'));
  });
}

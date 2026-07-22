import 'package:busymax/src/app/busymax_design.dart';
import 'package:busymax/src/app/busymax_yaru_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yaru/yaru.dart';

void main() {
  for (final brightness in Brightness.values) {
    testWidgets(
      'grouped list uses the semantic $brightness surface and Yaru rows',
      (tester) async {
        final theme = BusyMaxYaruTheme.build(
          brightness: brightness,
          accentColor: const Color(0xFF3584E4),
        );
        final colors = theme.extension<BusyMaxSurfaceColors>()!;

        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: Scaffold(
              body: BusyMaxGroupedList(
                filled: true,
                children: [
                  BusyMaxActionRow(title: 'Calendar', onTap: () {}),
                  const BusyMaxSwitchRow(
                    title: 'Notifications',
                    value: true,
                    onChanged: _ignoreBool,
                  ),
                ],
              ),
            ),
          ),
        );

        final groupedSurface = find.byType(BusyMaxGroupedSurface);
        expect(groupedSurface, findsOneWidget);
        final materialSurface = tester.widget<Material>(
          find.descendant(
            of: groupedSurface,
            matching: find.byWidgetPredicate(
              (widget) =>
                  widget is Material && widget.color == colors.groupedSurface,
            ),
          ),
        );
        expect(materialSurface.elevation, BusyMaxElevation.surface);
        expect(materialSurface.shadowColor, theme.colorScheme.shadow);
        final shape = materialSurface.shape! as RoundedRectangleBorder;
        expect(shape.side.color, colors.subtleBorder);
        expect(
          find.descendant(
            of: groupedSurface,
            matching: find.byType(YaruListTile),
          ),
          findsNWidgets(2),
        );

        final materialLayers = tester.widgetList<Material>(
          find.descendant(of: groupedSurface, matching: find.byType(Material)),
        );
        expect(
          materialLayers.where((material) => material.color == colors.control),
          isEmpty,
        );
      },
    );
  }

  testWidgets('action row distinguishes keyboard and pointer activation', (
    tester,
  ) async {
    final activations = <Offset?>[];
    await tester.pumpWidget(
      _testApp(
        BusyMaxActionRow(
          title: 'Calendar',
          onActivated: (_, globalPosition) {
            activations.add(globalPosition);
          },
        ),
      ),
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();

    expect(activations, [isNull]);

    final pointerPosition = tester.getCenter(find.text('Calendar'));
    await tester.tapAt(pointerPosition);
    await tester.pump();

    expect(activations, [isNull, pointerPosition]);

    final tile = tester.widget<YaruListTile>(
      find.descendant(
        of: find.byType(BusyMaxActionRow),
        matching: find.byType(YaruListTile),
      ),
    );
    tile.onTap!();

    expect(activations, [isNull, pointerPosition, isNull]);
  });

  testWidgets('nested checkbox does not activate its action row', (
    tester,
  ) async {
    final activations = <Offset?>[];
    var completionChanges = 0;
    await tester.pumpWidget(
      _testApp(
        BusyMaxActionRow(
          title: 'Prepare release',
          trailing: YaruCheckbox(
            value: false,
            onChanged: (_) => completionChanges += 1,
          ),
          onActivated: (_, globalPosition) {
            activations.add(globalPosition);
          },
        ),
      ),
    );

    await tester.tap(find.byType(YaruCheckbox));
    await tester.pump();

    expect(completionChanges, 1);
    expect(activations, isEmpty);

    final tile = tester.widget<YaruListTile>(
      find.descendant(
        of: find.byType(BusyMaxActionRow),
        matching: find.byType(YaruListTile),
      ),
    );
    tile.onTap!();

    expect(activations, [isNull]);
  });

  testWidgets('disabled combo row cannot open or receive keyboard focus', (
    tester,
  ) async {
    final selected = <String>[];
    await tester.pumpWidget(
      _testApp(
        BusyMaxComboRow<String>(
          title: 'Calendar',
          values: const ['Personal', 'Work'],
          selected: 'Personal',
          labelFor: (value) => value,
          onSelected: selected.add,
          enabled: false,
        ),
      ),
    );

    final combo = find.byType(BusyMaxComboRow<String>);
    final trigger = find.descendant(
      of: combo,
      matching: find.byType(OutlinedButton),
    );
    expect(trigger, findsOneWidget);

    await tester.tap(trigger, warnIfMissed: false);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    expect(find.byType(MenuItemButton), findsNothing);
    expect(selected, isEmpty);
    final disabledSemantics = tester.widget<Semantics>(
      find.descendant(
        of: combo,
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is Semantics && widget.properties.label == 'Calendar',
        ),
      ),
    );
    expect(disabledSemantics.properties.button, isTrue);
    expect(disabledSemantics.properties.enabled, isFalse);
    expect(disabledSemantics.properties.value, 'Personal');
  });

  testWidgets('switch row exposes one merged toggle interaction', (
    tester,
  ) async {
    final values = <bool>[];
    await tester.pumpWidget(
      _testApp(
        BusyMaxSwitchRow(
          title: 'Notifications',
          value: true,
          onChanged: values.add,
        ),
      ),
    );
    final semanticsHandle = tester.ensureSemantics();

    expect(
      find.descendant(
        of: find.byType(BusyMaxSwitchRow),
        matching: find.byType(MergeSemantics),
      ),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel('Notifications'), findsOneWidget);

    await tester.tap(find.text('Notifications'));
    await tester.pump();
    expect(values, [isFalse]);

    await tester.tap(find.byType(YaruSwitch));
    await tester.pump();
    expect(values, [isFalse, isFalse]);
    semanticsHandle.dispose();
  });
}

void _ignoreBool(bool value) {}

Widget _testApp(Widget child) {
  return MaterialApp(
    theme: BusyMaxYaruTheme.build(
      brightness: Brightness.light,
      accentColor: const Color(0xFF3584E4),
    ),
    home: Scaffold(
      body: Center(child: SizedBox(width: 480, child: child)),
    ),
  );
}

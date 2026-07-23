import 'package:busymax/src/app/busymax_design.dart';
import 'package:busymax/src/app/busymax_yaru_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yaru/yaru.dart';

import '../test_localized_app.dart';

void main() {
  testWidgets('BusyMaxMenuButton opens, closes, and reopens with entries', (
    tester,
  ) async {
    String? selected;
    final theme = BusyMaxYaruTheme.build(
      brightness: Brightness.dark,
      accentColor: BusyMaxLinuxPalette.ubuntuOrangeAccent,
    );

    await tester.pumpWidget(
      localizedTestApp(
        child: Theme(
          data: theme,
          child: Scaffold(
            body: Center(
              child: BusyMaxMenuButton<String>(
                tooltip: 'Options',
                onSelected: (value) => selected = value,
                entries: const [
                  BusyMaxMenuEntry(
                    value: 'refresh',
                    label: 'Refresh calendar',
                    icon: YaruIcons.refresh,
                  ),
                  BusyMaxMenuEntry(
                    value: 'open',
                    label: 'Open in provider',
                    icon: Icons.open_in_browser_outlined,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byTooltip('Options'));
    await tester.pumpAndSettle();

    expect(find.text('Refresh calendar'), findsOneWidget);
    expect(find.text('Open in provider'), findsOneWidget);
    final colors = theme.extension<BusyMaxSurfaceColors>()!;
    final anchor = tester.widget<MenuAnchor>(find.byType(MenuAnchor));
    expect(anchor.style?.backgroundColor?.resolve(const {}), colors.popover);
    expect(
      anchor.style?.elevation?.resolve(const {}),
      theme.menuTheme.style?.elevation?.resolve(const {}),
    );
    expect(
      anchor.style?.shape?.resolve(const {}),
      theme.menuTheme.style?.shape?.resolve(const {}),
    );
    expect(
      tester
          .widgetList<Material>(find.byType(Material))
          .where((material) => material.color == colors.popover),
      isNotEmpty,
    );
    for (final item in tester.widgetList<MenuItemButton>(
      find.byType(MenuItemButton),
    )) {
      expect(
        item.style?.minimumSize?.resolve(const {}),
        theme.menuButtonTheme.style?.minimumSize?.resolve(const {}),
      );
      expect(
        item.style?.maximumSize?.resolve(const {}),
        theme.menuButtonTheme.style?.maximumSize?.resolve(const {}),
      );
    }

    await tester.tap(find.byTooltip('Options'));
    await tester.pumpAndSettle();

    expect(find.text('Refresh calendar'), findsNothing);

    await tester.tap(find.byTooltip('Options'));
    await tester.pumpAndSettle();

    expect(find.text('Refresh calendar'), findsOneWidget);
    expect(find.text('Open in provider'), findsOneWidget);

    await tester.tap(find.text('Open in provider'));
    await tester.pumpAndSettle();

    expect(selected, 'open');
    expect(find.text('Open in provider'), findsNothing);
  });
}

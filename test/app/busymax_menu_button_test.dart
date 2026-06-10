import 'package:busymax/src/app/busymax_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yaru/yaru.dart';

import '../test_localized_app.dart';

void main() {
  testWidgets('BusyMaxMenuButton opens, closes, and reopens with entries', (
    tester,
  ) async {
    String? selected;

    await tester.pumpWidget(
      localizedTestApp(
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
    );

    await tester.tap(find.byTooltip('Options'));
    await tester.pumpAndSettle();

    expect(find.text('Refresh calendar'), findsOneWidget);
    expect(find.text('Open in provider'), findsOneWidget);

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

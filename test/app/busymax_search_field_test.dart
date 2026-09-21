import 'dart:io';

import 'package:busymax/src/app/busymax_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yaru/yaru.dart';

void main() {
  testWidgets('BusyMax search delegates visuals and interaction to Yaru', (
    tester,
  ) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    final changes = <String>[];
    var clearCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 420,
              child: BusyMaxSearchField(
                controller: controller,
                hintText: 'Search',
                onChanged: changes.add,
                onClear: () => clearCount += 1,
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.byType(YaruSearchField), findsOneWidget);
    final context = tester.element(find.byType(BusyMaxSearchField));
    final field = tester.widget<YaruSearchField>(find.byType(YaruSearchField));
    expect(field.style, YaruSearchFieldStyle.filled);
    expect(field.height, kYaruTitleBarItemHeight);
    expect(field.radius, const Radius.circular(kYaruTitleBarItemHeight));
    expect(tester.getSize(find.byType(BusyMaxSearchField)).width, 420);
    expect(
      tester.getSize(find.byType(BusyMaxSearchField)).height,
      kYaruTitleBarItemHeight,
    );
    expect(
      tester.getSize(find.byType(YaruSearchField)).height,
      kYaruTitleBarItemHeight,
    );
    expect(
      tester.getSize(find.byType(TextField)).height,
      kYaruTitleBarItemHeight,
    );
    expect(
      field.clearIconSemanticLabel,
      MaterialLocalizations.of(context).clearButtonTooltip,
    );

    await tester.enterText(find.byType(TextField), 'planning');
    await tester.pump();
    expect(changes, contains('planning'));
    expect(
      tester.getSize(find.byType(BusyMaxSearchField)).height,
      kYaruTitleBarItemHeight,
    );
    expect(
      tester.getSize(find.byType(YaruSearchField)).height,
      kYaruTitleBarItemHeight,
    );
    expect(
      tester.getSize(find.byType(TextField)).height,
      kYaruTitleBarItemHeight,
    );

    await tester.tap(find.byIcon(YaruIcons.edit_clear));
    await tester.pump();
    expect(controller.text, isEmpty);
    expect(clearCount, 1);
  });

  test('generic search keeps Yaru while the Linux header owns its shell', () {
    final design = File('lib/src/app/busymax_design.dart').readAsStringSync();
    final schedule = File(
      'lib/src/features/schedule/presentation/schedule_workspace.dart',
    ).readAsStringSync();
    final toolbar = File(
      'lib/src/features/schedule/presentation/schedule_toolbar.dart',
    ).readAsStringSync();
    final linuxHeader = File(
      'lib/src/app/linux/linux_header_style.dart',
    ).readAsStringSync();

    expect(design, contains('class BusyMaxSearchField'));
    expect(RegExp(r'YaruSearchField\(').allMatches(design), hasLength(1));
    expect(
      linuxHeader,
      contains('class BusyMaxLinuxHeaderSearchField extends StatefulWidget'),
    );
    expect(linuxHeader, isNot(contains('BusyMaxSearchField(')));
    expect(toolbar, contains('BusyMaxLinuxHeaderSearchField('));
    expect(schedule, isNot(contains('class _ScheduleSearchField')));
    expect(schedule, isNot(contains('YaruSearchField(')));
    expect(toolbar, isNot(contains('YaruSearchField(')));
    expect(linuxHeader, isNot(contains('YaruSearchField(')));
  });
}

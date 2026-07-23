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
      field.clearIconSemanticLabel,
      MaterialLocalizations.of(context).clearButtonTooltip,
    );

    await tester.enterText(find.byType(TextField), 'planning');
    await tester.pump();
    expect(changes, contains('planning'));

    await tester.tap(find.byIcon(YaruIcons.edit_clear));
    await tester.pump();
    expect(controller.text, isEmpty);
    expect(clearCount, 1);
  });

  test('search consumers use only the shared Yaru adapter', () {
    final design = File('lib/src/app/busymax_design.dart').readAsStringSync();
    final schedule = File(
      'lib/src/features/schedule/presentation/schedule_workspace.dart',
    ).readAsStringSync();

    expect(design, contains('class BusyMaxSearchField'));
    expect(RegExp(r'YaruSearchField\(').allMatches(design), hasLength(1));
    expect(schedule, contains('BusyMaxSearchField('));
    expect(schedule, isNot(contains('class _ScheduleSearchField')));
    expect(schedule, isNot(contains('YaruSearchField(')));
  });
}

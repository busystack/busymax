import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../tool/linux_header_comparison.dart';

void main() {
  testWidgets('production Linux headers match the reviewed fixture', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 310);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const LinuxHeaderComparisonFixture());
    await tester.pumpAndSettle();
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer();
    await mouse.moveTo(
      tester.getCenter(find.byKey(const ValueKey('schedule-refresh-button'))),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(LinuxHeaderComparisonFixture),
      matchesGoldenFile('goldens/linux_header_reviewed.png'),
    );
  });
}

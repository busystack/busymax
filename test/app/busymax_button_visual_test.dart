import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/linux_button_comparison.dart';

void main() {
  testWidgets('production Linux buttons match the reviewed fixture', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1100, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const LinuxButtonComparisonFixture());
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(LinuxButtonComparisonFixture),
      matchesGoldenFile('goldens/linux_buttons_reviewed.png'),
    );
  });
}

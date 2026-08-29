import 'package:busymax/src/calendar_providers/calendar_colors.dart';
import 'package:busymax/src/features/calendar/presentation/calendar_color_dialog.dart';
import 'package:busymax/src/platform/linux_header_bar_service.dart';
import 'package:busymax/src/providers/busy_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../test_localized_app.dart';

void main() {
  testWidgets('Google calendar color dialog returns the selected RGB color', (
    tester,
  ) async {
    final headerBarService = LinuxHeaderBarService(isLinux: false);
    addTearDown(headerBarService.dispose);
    Future<CalendarColorChoice?>? result;
    await tester.pumpWidget(
      localizedTestApp(
        child: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () {
                result = showCalendarColorDialog(
                  context,
                  provider: BusyProvider.google,
                  currentBackgroundColor: '#3584e4',
                  currentColorId: null,
                  headerBarService: headerBarService,
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.text('Calendar color'), findsOneWidget);

    await tester.tap(find.byTooltip('Color 2'));
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final choice = await result;
    expect(choice!.backgroundColor, '#1c71d8');
  });
}

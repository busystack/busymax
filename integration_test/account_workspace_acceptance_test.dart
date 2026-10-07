import 'dart:io';
import 'dart:ui' as ui;

import 'package:busymax/main_linux.dart' as app;
import 'package:busymax/src/app/app_bootstrap.dart';
import 'package:busymax/src/features/schedule/presentation/schedule_sidebar.dart';
import 'package:busymax/src/features/schedule/presentation/schedule_workspace.dart';
import 'package:busymax/src/features/settings/presentation/settings_screen.dart';
import 'package:busymax/src/schedule/schedule_view_mode.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

// Explicitly opt in with an isolated XDG data directory. Never opens the user's DB.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final output = Platform.environment['BUSYMAX_ACCEPTANCE_ROOT'];
  testWidgets(
    'native empty workspace, Accounts, cancellation and normal navigation',
    (tester) async {
      expect(output, isNotNull);
      expect(Platform.environment['XDG_DATA_HOME'], '$output/data');
      await tester.runAsync(() => app.main(const []));
      debugPrint('Native acceptance: app initialized');
      await tester.pumpAndSettle();
      expect(find.byType(ScheduleWorkspace), findsOneWidget);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(ScheduleWorkspace)),
      );
      expect(await container.read(accountsStreamProvider.future), isEmpty);
      final settings = container.read(appSettingsControllerProvider.notifier);
      await tester.runAsync(
        () => settings.setThemeModePreference(BusyMaxThemeModePreference.light),
      );
      await tester.pumpAndSettle();
      debugPrint('Native acceptance: capturing frame');
      await _capture(tester, '$output/native-light-week.png');
      for (final mode in ScheduleViewMode.values) {
        await tester.sendKeyEvent(switch (mode) {
          ScheduleViewMode.day => LogicalKeyboardKey.digit1,
          ScheduleViewMode.week => LogicalKeyboardKey.digit2,
          ScheduleViewMode.month => LogicalKeyboardKey.digit3,
          ScheduleViewMode.year => LogicalKeyboardKey.digit4,
          ScheduleViewMode.agenda => LogicalKeyboardKey.digit5,
        });
        await tester.pumpAndSettle();
        expect(
          container.read(appSettingsControllerProvider).scheduleViewMode,
          mode,
        );
        expect(find.text('Add account'), findsOneWidget);
        debugPrint('Native acceptance: capturing frame');
        await _capture(tester, '$output/native-${mode.name}.png');
      }
      await tester.runAsync(
        () => settings.setScheduleViewMode(ScheduleViewMode.week),
      );
      await tester.pumpAndSettle();
      final workspace = tester.state(find.byType(ScheduleWorkspace));
      final originalDate = tester
          .widget<ScheduleSidebar>(find.byType(ScheduleSidebar))
          .selectedDate;
      await _navigatePeriod(tester, LogicalKeyboardKey.arrowRight);
      final nextDate = tester
          .widget<ScheduleSidebar>(find.byType(ScheduleSidebar))
          .selectedDate;
      expect(nextDate, DateUtils.addDaysToDate(originalDate, 7));
      await _navigatePeriod(tester, LogicalKeyboardKey.arrowLeft);
      expect(
        tester
            .widget<ScheduleSidebar>(find.byType(ScheduleSidebar))
            .selectedDate,
        originalDate,
      );
      await _navigatePeriod(tester, LogicalKeyboardKey.arrowRight);
      Focus.of(tester.element(find.text('Add account'))).requestFocus();
      await tester.pumpAndSettle();
      debugPrint('Native acceptance: capturing frame');
      await _capture(tester, '$output/native-keyboard-focus.png');
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.byType(SettingsScreen), findsOneWidget);
      for (final title in [
        'Add Google account',
        'Add Microsoft account',
        'Add Apple iCloud Calendar account',
        'Add Nextcloud account',
        'Add calendar subscription',
      ]) {
        expect(find.text(title), findsOneWidget);
      }
      debugPrint('Native acceptance: capturing frame');
      await _capture(tester, '$output/native-accounts.png');
      for (final title in [
        'Add Google account',
        'Add Microsoft account',
        'Add Apple iCloud Calendar account',
        'Add Nextcloud account',
        'Add calendar subscription',
      ]) {
        await tester.ensureVisible(find.text(title));
        await tester.tap(find.text(title));
        await tester.pumpAndSettle();
        debugPrint('Native acceptance: capturing frame');
        await _capture(
          tester,
          '$output/native-cancel-${title.split(' ')[1]}.png',
        );
        await tester.tap(find.text('Cancel').last);
        await tester.pumpAndSettle();
        expect(find.byType(SettingsScreen), findsOneWidget);
      }
      await _back(tester);
      expect(find.byType(ScheduleWorkspace), findsOneWidget);
      expect(tester.state(find.byType(ScheduleWorkspace)), same(workspace));
      expect(
        tester
            .widget<ScheduleSidebar>(find.byType(ScheduleSidebar))
            .selectedDate,
        nextDate,
      );
      await tester.runAsync(
        () => settings.setThemeModePreference(BusyMaxThemeModePreference.dark),
      );
      await tester.pumpAndSettle();
      debugPrint('Native acceptance: capturing frame');
      await _capture(tester, '$output/native-dark-week.png');
      await tester.sendKeyEvent(LogicalKeyboardKey.f9);
      await tester.pumpAndSettle();
      expect(find.byType(ScheduleSidebar).hitTestable(), findsNothing);
      await _settingsShortcut(tester);
      expect(find.byType(SettingsScreen), findsOneWidget);
      await _back(tester);
      expect(find.byType(ScheduleWorkspace), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.f9);
      await tester.pumpAndSettle();
      // Native window remains visible; test viewport exercises the responsive layout.
      await tester.binding.setSurfaceSize(const Size(640, 740));
      await tester.pumpAndSettle();
      expect(find.byType(ScheduleSidebar).hitTestable(), findsNothing);
      await _settingsShortcut(tester);
      expect(find.byType(SettingsScreen), findsOneWidget);
      debugPrint('Native acceptance: capturing frame');
      await _capture(tester, '$output/native-narrow-settings.png');
      await _back(tester);
      await tester.binding.setSurfaceSize(null);
      tester.platformDispatcher.textScaleFactorTestValue = 1.5;
      await tester.pumpAndSettle();
      expect(find.text('Add account').hitTestable(), findsOneWidget);
      debugPrint('Native acceptance: capturing frame');
      await _capture(tester, '$output/native-enlarged-text.png');
      expect(tester.takeException(), isNull);
      tester.platformDispatcher.clearTextScaleFactorTestValue();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 1));
    },
    skip: output == null,
  );
}

Future<void> _navigatePeriod(
  WidgetTester tester,
  LogicalKeyboardKey direction,
) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
  await tester.sendKeyEvent(direction);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
  await tester.pumpAndSettle();
}

Future<void> _back(WidgetTester tester) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
  await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
  await tester.pumpAndSettle();
}

Future<void> _settingsShortcut(WidgetTester tester) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
  await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
  await tester.sendKeyEvent(LogicalKeyboardKey.keyS);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
  await tester.pumpAndSettle();
}

Future<void> _capture(WidgetTester tester, String path) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byType(RepaintBoundary).first,
  );
  final picture = await boundary.toImage();
  try {
    final bytes = await picture.toByteData(format: ui.ImageByteFormat.png);
    await File(path).writeAsBytes(bytes!.buffer.asUint8List());
  } finally {
    picture.dispose();
  }
}

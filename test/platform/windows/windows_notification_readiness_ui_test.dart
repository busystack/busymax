import 'package:busymax/l10n/generated/app_localizations.dart';
import 'package:busymax/src/features/notifications/desktop_notification_backend.dart';
import 'package:busymax/src/ui/windows/windows_settings_page.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final allowed in [true, false, null]) {
    testWidgets('packaged notification permission is reported as $allowed', (
      tester,
    ) async {
      await tester.pumpWidget(
        FluentApp(
          localizationsDelegates: const [AppLocalizations.delegate],
          supportedLocales: AppLocalizations.supportedLocales,
          home: WindowsNotificationReadinessInfoBar(
            readiness: DesktopNotificationReadiness(
              DesktopNotificationReadinessState.available,
              permissionGranted: allowed,
            ),
          ),
        ),
      );
      expect(
        find.text(
          allowed == true
              ? 'System settings allow BusyMax notifications.'
              : allowed == false
              ? 'System notification settings are blocking BusyMax. Your reminders are saved.'
              : 'Notification delivery status is unavailable. Review system settings.',
        ),
        findsOneWidget,
      );
      expect(find.text('System'), findsOneWidget);
    });
  }
  for (final testCase
      in <({DesktopNotificationReadiness readiness, String message})>[
        (
          readiness: const DesktopNotificationReadiness(
            DesktopNotificationReadinessState.unavailableUnpackaged,
          ),
          message: 'This unpackaged development run cannot use Windows notifications. Install the test-signed MSIX to test reminders.',
        ),
        (
          readiness: const DesktopNotificationReadiness(
            DesktopNotificationReadinessState.failedInstalledPackage,
          ),
          message: 'BusyMax could not initialize Windows notifications. Reminders will not appear until this installation problem is resolved.',
        ),
      ]) {
    testWidgets(
      'notification failure is visible: ${testCase.readiness.state}',
      (tester) async {
        await tester.pumpWidget(
          FluentApp(
            localizationsDelegates: const [AppLocalizations.delegate],
            supportedLocales: AppLocalizations.supportedLocales,
            home: WindowsNotificationReadinessInfoBar(
              readiness: testCase.readiness,
            ),
          ),
        );

        expect(
          find.text('Windows notifications are unavailable'),
          findsOneWidget,
        );
        expect(find.text(testCase.message), findsOneWidget);
        expect(find.byType(InfoBar), findsOneWidget);
      },
    );
  }
}

import 'package:busymax/l10n/generated/app_localizations.dart';
import 'package:busymax/src/calendar_providers/calendar_mutation.dart';
import 'package:busymax/src/providers/busy_provider.dart';
import 'package:busymax/src/ui/windows/windows_guest_update_dialog.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Google guest update dialog returns do-not-send', (tester) async {
    CalendarGuestUpdatePolicy? result;
    await tester.pumpWidget(
      _Harness(
        onOpen: (context) async {
          result = await showWindowsGuestUpdateDialog(
            context,
            provider: BusyProvider.google,
            action: WindowsGuestUpdateAction.save,
          );
        },
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.text('Notify guests?'), findsOneWidget);

    await tester.tap(find.text('Don’t send'));
    await tester.pumpAndSettle();
    expect(result, CalendarGuestUpdatePolicy.doNotSend);
  });

  testWidgets('Microsoft guest deletion cannot suppress cancellation', (
    tester,
  ) async {
    CalendarGuestUpdatePolicy? result;
    await tester.pumpWidget(
      _Harness(
        onOpen: (context) async {
          result = await showWindowsGuestUpdateDialog(
            context,
            provider: BusyProvider.microsoft,
            action: WindowsGuestUpdateAction.delete,
          );
        },
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.text('Delete meeting?'), findsOneWidget);
    expect(find.text('Don’t send'), findsNothing);

    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(result, CalendarGuestUpdatePolicy.send);
  });
}

class _Harness extends StatelessWidget {
  const _Harness({required this.onOpen});

  final Future<void> Function(BuildContext context) onOpen;

  @override
  Widget build(BuildContext context) {
    return FluentApp(
      localizationsDelegates: const [AppLocalizations.delegate],
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => Center(
          child: Button(
            onPressed: () => onOpen(context),
            child: const Text('Open'),
          ),
        ),
      ),
    );
  }
}

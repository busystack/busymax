import 'package:busymax/src/android/presentation/android_event_actions.dart';
import 'package:busymax/src/calendar_providers/calendar_mutation.dart';
import 'package:busymax/src/providers/busy_provider.dart';
import 'package:busymax/src/ui/common/flutter_material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../test_localized_app.dart';

void main() {
  for (final provider in [
    BusyProvider.google,
    BusyProvider.microsoft,
    BusyProvider.nextcloud,
    BusyProvider.caldav,
  ]) {
    for (final deleting in [false, true]) {
      testWidgets(
        '$provider guest decision preserves supported policy, delete=$deleting',
        (tester) async {
          CalendarGuestUpdatePolicy? result;
          await tester.pumpWidget(
            localizedTestApp(
              child: Builder(
                builder: (context) => Scaffold(
                  body: TextButton(
                    onPressed: () async {
                      result = await showAndroidGuestDeliveryDialog(
                        context,
                        provider: provider,
                        deleting: deleting,
                      );
                    },
                    child: const Text('Decide'),
                  ),
                ),
              ),
            ),
          );
          await tester.tap(find.text('Decide'));
          await tester.pumpAndSettle();
          if (provider == BusyProvider.google) {
            expect(find.text('Don’t send'), findsOneWidget);
            await tester.tap(find.text('Don’t send'));
            await tester.pumpAndSettle();
            expect(result, CalendarGuestUpdatePolicy.doNotSend);
          } else {
            expect(find.text('Don’t send'), findsNothing);
            await tester.tap(find.byType(FilledButton));
            await tester.pumpAndSettle();
            expect(result, CalendarGuestUpdatePolicy.send);
          }
        },
      );
    }
  }
}

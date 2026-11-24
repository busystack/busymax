import 'package:busymax/src/android/presentation/android_nextcloud_collection_screen.dart';
import 'package:busymax/src/app/app_bootstrap.dart';
import 'package:busymax/src/ui/common/flutter_material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../dav/nextcloud/nextcloud_admin_fixture.dart';
import '../../test_localized_app.dart';

void main() {
  testWidgets(
    'failed metadata Save retries the edited values without reloading',
    (tester) async {
      final fixture = NextcloudAdminFixture();
      await tester.runAsync(fixture.seed);
      addTearDown(fixture.close);
      Future<void> pumpUntil(bool Function() done) async {
        for (var attempt = 0; attempt < 100 && !done(); attempt++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 10)),
          );
          await tester.pump(const Duration(milliseconds: 20));
        }
        expect(done(), isTrue);
      }

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            nextcloudSharingServiceProvider('account')
                .overrideWithValue(fixture.sharing),
          ],
          child: localizedTestApp(
            child: const AndroidNextcloudCollectionScreen(
              accountId: 'account',
              collectionId: 'collection',
            ),
          ),
        ),
      );
      final title = find.widgetWithText(TextFormField, 'Title');
      await pumpUntil(() => title.evaluate().isNotEmpty);
      await tester.enterText(title, 'Unsaved collection name');
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Calendar color'),
        '#102030',
      );
      fixture.failedProperty = 'calendar-color';
      await tester.tap(find.widgetWithText(TextButton, 'Save'));
      await pumpUntil(() => find.text('Retry').evaluate().isNotEmpty);
      expect(find.text('Unsaved collection name'), findsOneWidget);
      expect(find.text('#102030'), findsOneWidget);
      final firstWrite = fixture.requests.singleWhere(
        (request) => request.method == 'PROPPATCH',
      );
      expect(firstWrite.body, contains('Unsaved collection name'));
      expect(firstWrite.body, contains('#102030'));

      fixture.failedProperty = null;
      await tester.tap(find.widgetWithText(TextButton, 'Retry'));
      await pumpUntil(
        () =>
            find.text('Retry').evaluate().isEmpty &&
            find.byType(LinearProgressIndicator).evaluate().isEmpty,
      );
      final writes = fixture.requests
          .where((request) => request.method == 'PROPPATCH')
          .toList();
      expect(writes, hasLength(2));
      expect(writes.last.body, firstWrite.body);
      expect(fixture.displayName, 'Unsaved collection name');
      expect(find.text('#102030'), findsOneWidget);
      expect(
        tester
            .widget<TextButton>(find.widgetWithText(TextButton, 'Save'))
            .onPressed,
        isNull,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    },
  );
}

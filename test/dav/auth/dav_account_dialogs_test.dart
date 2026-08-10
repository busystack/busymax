import 'package:busymax/src/dav/auth/dav_account_dialogs.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../test_localized_app.dart';

void main() {
  testWidgets('Nextcloud form explains and accepts a copied CalDAV address', (
    tester,
  ) async {
    late BuildContext hostContext;
    await tester.pumpWidget(
      localizedTestApp(
        child: Builder(
          builder: (context) {
            hostContext = context;
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    final result = showNextcloudServerDialog(hostContext);
    await tester.pumpAndSettle();

    final field = tester.widget<TextField>(
      find.byKey(const Key('nextcloud-server-field')),
    );
    expect(field.decoration?.labelText, 'Nextcloud server or CalDAV address');
    expect(
      field.decoration?.hintText,
      'https://cloud.example.com/remote.php/dav',
    );
    expect(
      field.decoration?.helperText,
      'Enter your Nextcloud server URL, or paste the primary CalDAV address '
      'copied from Nextcloud.',
    );
    expect(field.decoration?.helperMaxLines, 2);

    const copiedAddress = 'https://cloud.example.test/remote.php/dav';
    await tester.enterText(
      find.byKey(const Key('nextcloud-server-field')),
      copiedAddress,
    );
    await tester.tap(find.text('Connect'));
    await tester.pumpAndSettle();

    expect(await result, copiedAddress);
  });
}

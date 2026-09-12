import 'package:busymax/l10n/generated/app_localizations.dart';
import 'package:busymax/src/app/app_bootstrap.dart';
import 'package:busymax/src/dav/presentation/nextcloud_collection_dialog.dart';
import 'package:busymax/src/ui/windows/windows_nextcloud_dialogs.dart';
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/memory_settings_store.dart';
import 'nextcloud_admin_fixture.dart';

void main() {
  for (final windows in [false, true]) {
    final platform = windows ? 'Windows' : 'Linux';
    testWidgets(
      '$platform can save metadata on a content-read-only collection',
      (tester) async {
        final fixture = NextcloudAdminFixture();
        await tester.runAsync(fixture.seed);
        addTearDown(fixture.close);
        await _pump(tester, fixture, windows);
        final title = find.byKey(const ValueKey('nextcloud-displayname'));
        expect(title, findsOneWidget);
        if (windows) {
          expect(tester.widget<fluent.TextBox>(title).enabled, isTrue);
          expect(find.byType(AlertDialog), findsNothing);
        } else {
          expect(tester.widget<TextField>(title).enabled, isTrue);
          expect(find.byType(fluent.ContentDialog), findsNothing);
        }
        expect(fixture.requests.where((r) => r.method == 'PROPPATCH'), isEmpty);
        await tester.enterText(title, 'New name');
        await tester.pump();
        await tester.tap(find.text('Save'));
        await _settle(tester);
        expect(fixture.displayName, 'New name');
        expect(
          fixture.requests.where((r) => r.method == 'PROPPATCH'),
          hasLength(1),
        );
        expect(
          await tester.runAsync(
            () => fixture.database.select(fixture.database.pendingOps).get(),
          ),
          isEmpty,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
    testWidgets('$platform cancels dirty metadata without a DAV write', (
      tester,
    ) async {
      final fixture = NextcloudAdminFixture();
      await tester.runAsync(fixture.seed);
      addTearDown(fixture.close);
      await _pump(tester, fixture, windows);
      await tester.enterText(
        find.byKey(const ValueKey('nextcloud-displayname')),
        'Discard me',
      );
      await tester.pump();
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Discard').last);
      await tester.pumpAndSettle();
      expect(fixture.requests.where((r) => r.method == 'PROPPATCH'), isEmpty);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump(const Duration(milliseconds: 100));
  }
  await tester.pumpAndSettle();
}

Future<void> _pump(
  WidgetTester tester,
  NextcloudAdminFixture fixture,
  bool windows,
) async {
  await tester.binding.setSurfaceSize(const Size(1000, 850));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final home = Builder(
    builder: (context) => Center(
      child: windows
          ? fluent.Button(
              onPressed: () => showWindowsNextcloudCollectionDialog(
                context,
                accountId: 'account',
                collectionId: 'collection',
              ),
              child: const Text('Open'),
            )
          : TextButton(
              onPressed: () => showLinuxNextcloudCollectionDialog(
                context,
                accountId: 'account',
                collectionId: 'collection',
              ),
              child: const Text('Open'),
            ),
    ),
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        localSettingsStoreProvider.overrideWithValue(MemorySettingsStore()),
        nextcloudSharingServiceProvider(
          'account',
        ).overrideWithValue(fixture.sharing),
      ],
      child: windows
          ? fluent.FluentApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: home,
            )
          : MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(body: home),
            ),
    ),
  );
  await tester.tap(find.text('Open'));
  await _settle(tester);
}

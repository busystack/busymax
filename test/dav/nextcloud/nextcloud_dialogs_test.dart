import 'package:busymax/l10n/generated/app_localizations.dart';
import 'package:busymax/src/app/app_bootstrap.dart';
import 'package:busymax/src/app/busymax_design.dart';
import 'package:busymax/src/app/busymax_yaru_theme.dart';
import 'package:busymax/src/dav/presentation/nextcloud_collection_dialog.dart';
import 'package:busymax/src/ui/windows/windows_nextcloud_dialogs.dart';
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yaru/yaru.dart';

import '../../support/memory_settings_store.dart';
import '../../test_localized_app.dart';
import 'nextcloud_admin_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('yaru_window'),
          (call) async => call.method == 'state' ? <String, Object?>{} : null,
        );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('yaru_window/events'),
          (call) async => null,
        );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('yaru_window'), null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('yaru_window/events'),
          null,
        );
  });

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
          expect(find.byType(BusyMaxDialogShell), findsOneWidget);
          expect(find.byType(BusyMaxGroupedList), findsWidgets);
          expect(find.byType(AlertDialog), findsNothing);
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
        if (!windows) {
          expect(
            find.byKey(const ValueKey('nextcloud-collection-dialog')),
            findsOneWidget,
          );
        }
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

  testWidgets('nested collection confirmation keeps the parent modal active', (
    tester,
  ) async {
    final fixture = NextcloudAdminFixture();
    await tester.runAsync(fixture.seed);
    addTearDown(fixture.close);
    await _pump(tester, fixture, false);

    await tester.enterText(
      find.byKey(const ValueKey('nextcloud-displayname')),
      'Unsaved',
    );
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    expect(find.byType(BusyMaxConfirmDialog), findsOneWidget);
    expect(find.byType(AnimatedModalBarrier), findsWidgets);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('nextcloud-collection-dialog')),
      findsOneWidget,
    );
    expect(find.byType(BusyMaxConfirmDialog), findsNothing);

    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Discard').last);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('nextcloud-collection-dialog')),
      findsNothing,
    );
    expect(find.byType(AnimatedModalBarrier), findsNothing);
    expect(
      fixture.requests.where((request) => request.method == 'PROPPATCH'),
      isEmpty,
    );
  });

  testWidgets('trash uses shared rows and confirms permanent deletion', (
    tester,
  ) async {
    final fixture = NextcloudAdminFixture();
    await tester.runAsync(fixture.seed);
    addTearDown(fixture.close);
    await _pumpTrash(tester, fixture);

    expect(find.byType(BusyMaxDialogShell), findsOneWidget);
    expect(find.byType(BusyMaxGroupedList), findsOneWidget);
    expect(find.text('Deleted event'), findsOneWidget);
    expect(find.text('Deleted task'), findsOneWidget);
    expect(find.textContaining('30'), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);

    final deleteActions = find.widgetWithText(
      BusyMaxActionRow,
      'Permanently delete',
    );
    await tester.tap(deleteActions.first);
    await tester.pumpAndSettle();
    var confirmation = find.byType(BusyMaxConfirmDialog);
    expect(confirmation, findsOneWidget);
    expect(
      find.descendant(
        of: confirmation,
        matching: find.textContaining('Deleted event'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: confirmation,
        matching: find.textContaining('Deleted task'),
      ),
      findsNothing,
    );
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(
      fixture.requests.where((request) => request.method == 'DELETE'),
      isEmpty,
    );

    await tester.tap(deleteActions.last);
    await tester.pumpAndSettle();
    confirmation = find.byType(BusyMaxConfirmDialog);
    expect(
      find.descendant(
        of: confirmation,
        matching: find.textContaining('Deleted task'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: confirmation,
        matching: find.textContaining('Deleted event'),
      ),
      findsNothing,
    );
    await tester.tap(
      find.descendant(
        of: confirmation,
        matching: find.widgetWithText(ElevatedButton, 'Permanently delete'),
      ),
    );
    for (var attempt = 0; attempt < 20; attempt++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump(const Duration(milliseconds: 100));
      if (fixture.requests.any((request) => request.method == 'DELETE') &&
          find.byType(YaruCircularProgressIndicator).evaluate().isEmpty) {
        break;
      }
    }
    final deletes = fixture.requests
        .where((request) => request.method == 'DELETE')
        .toList();
    expect(deletes, hasLength(1));
    expect(deletes.single.url.path, endsWith('/objects/42.ics'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('trash disables operations denied by the server', (tester) async {
    final fixture = NextcloudAdminFixture()..denyTrashObject = true;
    await tester.runAsync(fixture.seed);
    addTearDown(fixture.close);
    await _pumpTrash(tester, fixture);

    final restore = tester.widget<BusyMaxActionRow>(
      find.widgetWithText(BusyMaxActionRow, 'Restore').first,
    );
    final delete = tester.widget<BusyMaxActionRow>(
      find.widgetWithText(BusyMaxActionRow, 'Permanently delete').first,
    );
    expect(restore.enabled, isFalse);
    expect(delete.enabled, isFalse);
  });

  testWidgets('collection dialog scrolls in a narrow enlarged RTL window', (
    tester,
  ) async {
    final fixture = NextcloudAdminFixture();
    await tester.runAsync(fixture.seed);
    addTearDown(fixture.close);
    await _pump(
      tester,
      fixture,
      false,
      size: const Size(430, 420),
      brightness: Brightness.dark,
      locale: const Locale('ar'),
      textScaler: const TextScaler.linear(1.5),
    );

    final dialog = find.byKey(const ValueKey('nextcloud-collection-dialog'));
    expect(dialog, findsOneWidget);
    expect(Directionality.of(tester.element(dialog)), TextDirection.rtl);
    expect(
      find.descendant(of: dialog, matching: find.byType(SingleChildScrollView)),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
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
  bool windows, {
  Size size = const Size(1000, 850),
  Brightness brightness = Brightness.light,
  Locale locale = const Locale('en'),
  TextScaler? textScaler,
}) async {
  await tester.binding.setSurfaceSize(size);
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
          : localizedTestApp(
              locale: locale,
              textScaler: textScaler,
              theme: BusyMaxYaruTheme.build(
                brightness: brightness,
                accentColor: YaruColors.orange,
              ),
              child: Scaffold(body: home),
            ),
    ),
  );
  await tester.tap(find.text('Open'));
  await _settle(tester);
}

Future<void> _pumpTrash(
  WidgetTester tester,
  NextcloudAdminFixture fixture,
) async {
  await tester.binding.setSurfaceSize(const Size(760, 700));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        localSettingsStoreProvider.overrideWithValue(MemorySettingsStore()),
        nextcloudTrashServiceProvider(
          'account',
        ).overrideWithValue(fixture.trash),
      ],
      child: localizedTestApp(
        theme: BusyMaxYaruTheme.build(
          brightness: Brightness.dark,
          accentColor: YaruColors.orange,
        ),
        child: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: BusyMaxPushButton.standard(
                onPressed: () => showLinuxNextcloudTrashDialog(
                  context,
                  accountId: 'account',
                ),
                child: const Text('Open trash'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open trash'));
  await _settle(tester);
}

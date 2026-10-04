import 'package:busymax/src/core/secrets/secret_store.dart';
import 'dart:async';

import 'package:busymax/l10n/generated/app_localizations.dart';
import 'package:busymax/src/app/app_bootstrap.dart';
import 'package:busymax/src/app/windows/windows_busymax_app.dart';
import 'package:busymax/src/db/app_database.dart';
import 'package:busymax/src/providers/busy_provider.dart';
import 'package:busymax/src/schedule/schedule_view_mode.dart';
import 'package:busymax/src/ui/windows/windows_schedule_day_week_view.dart';
import 'package:busymax/src/ui/windows/windows_schedule_page.dart';
import 'package:busymax/src/ui/windows/windows_schedule_source_pane.dart';
import 'package:busymax/src/ui/windows/windows_settings_page.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../support/fake_autostart_service.dart';
import '../../support/memory_settings_store.dart';

void main() {
  for (final width in [1200.0, 720.0]) {
    testWidgets('Windows empty startup and Accounts targeting at width $width', (
      tester,
    ) async {
      final container = await _pumpRoutedApp(tester, width: width);
      expect(container.read(authSessionControllerProvider).isSignedIn, isFalse);
      expect(find.byType(WindowsSchedulePage), findsOneWidget);
      expect(find.byType(WindowsScheduleDayWeekView), findsOneWidget);
      if (width < 1000) {
        expect(
          find.byType(WindowsScheduleSourcePane).hitTestable(),
          findsNothing,
        );
        final button = tester
            .widget<CommandBar>(find.byType(CommandBar))
            .primaryItems
            .whereType<CommandBarButton>()
            .firstWhere(
              (item) =>
                  item.label is Text &&
                  [
                    'Show sidebar panel',
                    'Filters',
                  ].contains((item.label as Text).data),
            );
        button.onPressed!();
        await tester.pumpAndSettle();
        expect(find.byType(ContentDialog), findsOneWidget);
      }
      expect(find.text('Add account').hitTestable(), findsOneWidget);
      await tester.tap(find.text('Add account').hitTestable());
      await tester.pumpAndSettle();
      expect(find.byType(ContentDialog), findsNothing);
      expect(find.byType(WindowsSettingsPage), findsOneWidget);
      final uri = GoRouterState.of(
        tester.element(find.byType(WindowsSettingsPage)),
      ).uri;
      expect(uri.path, '/settings');
      expect(uri.queryParameters['page'], 'accounts');
      expect(windowsAppRouter.canPop(), isTrue);
      for (final title in [
        'Add Google account',
        'Add Microsoft account',
        'Add Apple iCloud Calendar account',
        'Add Nextcloud account',
      ]) {
        expect(find.text(title).hitTestable(), findsOneWidget);
        final row = tester.widget<ListTile>(
          find.ancestor(of: find.text(title), matching: find.byType(ListTile)),
        );
        expect(row.onPressed, isNotNull);
        if (title == 'Add Google account') {
          expect(row.focusNode!.hasFocus, isTrue);
        }
      }
      // Cancel each local setup dialog before any credentials or authorization.
      for (final title in [
        'Add Google account',
        'Add Microsoft account',
        'Add Apple iCloud Calendar account',
        'Add Nextcloud account',
      ]) {
        await tester.ensureVisible(find.text(title));
        await tester.tap(find.text(title));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(tester.takeException(), isNull, reason: 'Opening $title');
        expect(find.byType(ContentDialog), findsOneWidget);
        await tester.tap(find.text('Cancel').last);
        await tester.pumpAndSettle();
        expect(find.byType(WindowsSettingsPage), findsOneWidget);
      }
      await tester.scrollUntilVisible(
        find.text('Add calendar subscription'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Add calendar subscription'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'Subscription dialog');
      expect(find.byType(ContentDialog), findsOneWidget);
      await tester.tap(find.text('Cancel').last);
      await tester.pumpAndSettle();
      windowsAppRouter.pop();
      await tester.pumpAndSettle();
      expect(find.byType(WindowsSchedulePage), findsOneWidget);
      expect(
        container.read(appSettingsControllerProvider).scheduleViewMode,
        ScheduleViewMode.week,
      );
    });
  }

  testWidgets('Windows empty calendar creation shortcuts do not open editors', (
    tester,
  ) async {
    await _pumpRoutedApp(tester);
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.keyE);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyT);
    await tester.pumpAndSettle();
    expect(find.byType(ContentDialog), findsNothing);
    expect(find.byType(WindowsScheduleDayWeekView), findsOneWidget);
    expect(find.text('Add account'), findsOneWidget);
  });

  testWidgets(
    'Windows final-account removal leaves Settings and empty calendar',
    (tester) async {
      final container = await _pumpRoutedApp(tester);
      await tester.runAsync(
        () => container
            .read(accountsRepositoryProvider)
            .upsertSignedInAccount(
              id: 'google:last',
              provider: BusyProvider.google,
              authority: 'https://accounts.google.com',
              providerAccountId: 'last',
              grantedScopes: '',
              displayName: 'Last account',
            ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Add account'), findsNothing);
      unawaited(windowsAppRouter.push<void>('/settings?page=accounts'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Last account'),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      final accountRow = find.ancestor(
        of: find.text('Last account'),
        matching: find.byType(ListTile),
      );
      await tester.tap(
        find.descendant(of: accountRow, matching: find.byType(DropDownButton)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove account…').last);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'Removal dialog layout');
      await tester.tap(find.text('Remove account').last);
      await tester.pumpAndSettle();
      expect(find.byType(WindowsSettingsPage), findsOneWidget);
      expect(container.read(selectedAccountIdProvider), isNull);
      expect(
        find.byType(ContentDialog),
        findsNothing,
        reason: tester
            .widgetList<Text>(find.byType(Text))
            .map((w) => w.data)
            .join(' | '),
      );
      expect(
        (await tester.runAsync(
          () =>
              container.read(accountsRepositoryProvider).listVisibleAccounts(),
        ))!,
        isEmpty,
      );
      await tester.pumpAndSettle();
      expect(
        find.byType(ContentDialog),
        findsNothing,
        reason: tester
            .widgetList<Text>(find.byType(Text))
            .map((w) => w.data)
            .join(' | '),
      );
      windowsAppRouter.go('/schedule');
      await tester.pumpAndSettle();
      expect(
        find.byType(WindowsScheduleDayWeekView),
        findsOneWidget,
        reason:
            'mode=${container.read(appSettingsControllerProvider).scheduleViewMode}, route=${windowsAppRouter.state.uri}, texts=${tester.widgetList<Text>(find.byType(Text)).map((w) => w.data).join(' | ')}',
      );
      expect(find.text('Add account'), findsOneWidget);
    },
  );
}

Future<ProviderContainer> _pumpRoutedApp(
  WidgetTester tester, {
  double width = 1200,
}) async {
  final database = AppDatabase.memoryForTests();
  addTearDown(database.close);
  tester.view
    ..devicePixelRatio = 1
    ..physicalSize = Size(width, 950);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(database),
        secretStoreProvider.overrideWithValue(InMemorySecretStore()),
        localSettingsStoreProvider.overrideWithValue(MemorySettingsStore()),
        localTimeZoneProvider.overrideWithValue('UTC'),
        desktopAutostartServiceProvider.overrideWithValue(
          FakeAutostartService(),
        ),
        signedInSyncRunnerProvider.overrideWithValue((_, _) async {}),
      ],
      child: FluentApp.router(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: windowsAppRouter,
      ),
    ),
  );
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });
  windowsAppRouter.go('/');
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(
    tester.element(find.byType(WindowsSchedulePage)),
  );
}

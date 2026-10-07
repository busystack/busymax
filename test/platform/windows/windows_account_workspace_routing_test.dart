import '../../support/desktop_connection_fixture.dart';
import '../../support/native_registration_reader_fixture.dart';
import 'package:busymax/src/core/auth/oauth_registration.dart';
import 'package:busymax/src/core/auth/registration_file_reader.dart';
import 'package:busymax/src/core/secrets/secret_store.dart';
import 'dart:async';
import 'dart:convert';
import 'package:busymax/src/webcal/webcal_http_client.dart';
import 'package:busymax/src/webcal/webcal_subscription_service.dart';

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
  late RegistrationFileReader reader;
  setUpAll(() async {
    reader = await buildNativeRegistrationReader();
  });
  for (final choice in [
    (BusyProvider.google, DesktopConnectionMethod.busyMax),
    (BusyProvider.google, DesktopConnectionMethod.googleWorkspace),
    (BusyProvider.google, DesktopConnectionMethod.custom),
    (BusyProvider.microsoft, DesktopConnectionMethod.busyMax),
    (BusyProvider.microsoft, DesktopConnectionMethod.custom),
  ]) {
    testWidgets('Windows Settings connects ${choice.$1} through ${choice.$2}', (
      tester,
    ) async {
      final (provider, method) = choice;
      final fixture = DesktopConnectionFixture(
        AppDatabase.memoryForTests(),
        reader,
      );
      addTearDown(fixture.staging.dispose);
      await _pumpRoutedApp(
        tester,
        initialLocation: '/settings?page=accounts',
        connections: fixture,
      );
      await tester.ensureVisible(
        find.text('Add ${provider.displayName} account'),
      );
      await tester.tap(find.text('Add ${provider.displayName} account'));
      await _pumpConnectionPage(tester);
      expect(find.text('Recommended'), findsNothing);
      expect(
        find.text(
          'On the Google permissions screen, select both Calendar and Tasks permissions.',
        ),
        provider == BusyProvider.google ? findsOneWidget : findsNothing,
      );
      expect(
        find.byKey(const ValueKey('registration-authorize')),
        findsNothing,
      );
      if (method == DesktopConnectionMethod.busyMax) {
        await tester.tap(find.byKey(const ValueKey('registration-busymax')));
      } else {
        await tester.tap(
          find.byKey(
            ValueKey(
              'registration-${method == DesktopConnectionMethod.googleWorkspace ? 'workspace' : 'custom'}',
            ),
          ),
        );
        await _pumpConnectionPage(tester);
        await tester.tap(find.byKey(const ValueKey('registration-guide')));
        await _pumpConnectionPage(tester);
        expect(find.byType(ContentDialog), findsOneWidget);
        expect(
          find.byKey(const ValueKey('registration-authorize')),
          findsNothing,
        );
        await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
        await _pumpConnectionPage(tester);
        expect(
          GoRouterState.of(
            tester.element(find.byType(WindowsSettingsPage)),
          ).uri.path,
          '/settings',
        );
        expect(
          find.byKey(const ValueKey('registration-configuration-dialog')),
          findsOneWidget,
        );
        if (provider == BusyProvider.google) {
          await tester.runAsync(() async {
            await (tester
                    .widget<Button>(
                      find.byKey(const ValueKey('registration-import')),
                    )
                    .onPressed
                as dynamic)();
          });
        } else {
          await tester.enterText(
            find.byKey(const ValueKey('registration-client-id')),
            '33333333-3333-3333-3333-333333333333',
          );
        }
        await _pumpConnectionPage(tester);
        await tester.tap(find.byKey(const ValueKey('registration-authorize')));
      }
      final id = '${provider.storageValue}:fixture-user';
      for (var i = 0; i < 40; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await _pumpConnectionPage(tester);
        if (await tester.runAsync(() => fixture.secrets.readCredential(id)) !=
            null) {
          break;
        }
      }
      final record =
          await tester.runAsync(() => fixture.secrets.readCredential(id))
              as BoundOAuthSecretRecord;
      expect(
        record.registration.summary().origin,
        method == DesktopConnectionMethod.busyMax
            ? RegistrationOrigin.busyMaxManaged
            : RegistrationOrigin.userProvided,
      );
      expect(fixture.flow.clients.single, record.registration.clientId);
      expect(find.byType(ContentDialog), findsNothing);
      expect(find.byType(WindowsSettingsPage), findsOneWidget);
      if (method == DesktopConnectionMethod.custom) {
        await _pumpConnectionPage(tester);
        await tester.ensureVisible(find.text('Connect'));
        await tester.tap(find.text('Connect'));
        await _pumpConnectionPage(tester);
        expect(find.byType(ContentDialog), findsNothing);
        for (var i = 0; i < 40; i++) {
          await _pumpConnectionPage(tester);
          if (await tester.runAsync(() => fixture.persistence.generation(id)) ==
              2) {
            break;
          }
        }
        expect(fixture.flow.clients, [
          record.registration.clientId,
          record.registration.clientId,
        ]);
        await tester.ensureVisible(find.text('Replace registration'));
        await tester.tap(find.text('Replace registration'));
        await _pumpConnectionPage(tester);
        expect(
          find.byKey(const ValueKey('registration-methods-dialog')),
          findsOneWidget,
        );
        await tester.tap(find.byKey(const ValueKey('registration-close')));
        await _pumpConnectionPage(tester);
        expect(fixture.flow.clients, hasLength(2));
        expect(
          await tester.runAsync(() => fixture.persistence.generation(id)),
          2,
        );
        await tester.tap(find.text('Replace registration'));
        await _pumpConnectionPage(tester);
        await tester.tap(find.byKey(const ValueKey('registration-busymax')));
        for (var i = 0; i < 40; i++) {
          await _pumpConnectionPage(tester);
          if (await tester.runAsync(() => fixture.persistence.generation(id)) ==
              3) {
            break;
          }
        }
        final replaced =
            await tester.runAsync(() => fixture.secrets.readCredential(id))
                as BoundOAuthSecretRecord;
        expect(replaced.generation, 3);
        expect(replaced.subject, record.subject);
        expect(
          replaced.registration.summary().origin,
          RegistrationOrigin.busyMaxManaged,
        );
        expect(fixture.flow.clients.last, replaced.registration.clientId);
        expect(
          await tester.runAsync(
            () => (fixture.database.select(fixture.database.accounts)).get(),
          ),
          hasLength(1),
        );
        expect(find.byType(WindowsSettingsPage), findsOneWidget);
      }
    });
  }

  for (final initialLocation in ['/', '/schedule']) {
    for (final width in [1200.0, 720.0]) {
      testWidgets(
        'Windows empty startup $initialLocation and Accounts targeting at width $width',
        (tester) async {
          final container = await _pumpRoutedApp(
            tester,
            width: width,
            initialLocation: initialLocation,
          );
          final workspace = tester.state(find.byType(WindowsSchedulePage));
          final selectedDate = await _navigateCalendar(tester);
          expect(
            container.read(authSessionControllerProvider).isSignedIn,
            isFalse,
          );
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
            'Add Nextcloud account',
            'Add Google account',
            'Add Microsoft account',
            'Add Apple iCloud Calendar account',
          ]) {
            expect(find.text(title).hitTestable(), findsOneWidget);
            final row = tester.widget<ListTile>(
              find.ancestor(
                of: find.text(title),
                matching: find.byType(ListTile),
              ),
            );
            expect(row.onPressed, isNotNull);
            if (title == 'Add Nextcloud account') {
              expect(row.focusNode!.hasFocus, isTrue);
            }
          }
          expect(
            tester.getTopLeft(find.text('Add Nextcloud account')).dy,
            lessThan(tester.getTopLeft(find.text('Add Google account')).dy),
          );
          // Cancel each local setup dialog before any credentials or authorization.
          for (final title in [
            'Add Nextcloud account',
            'Add Google account',
            'Add Microsoft account',
            'Add Apple iCloud Calendar account',
          ]) {
            await tester.ensureVisible(find.text(title));
            await tester.tap(find.text(title));
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 300));
            expect(tester.takeException(), isNull, reason: 'Opening $title');
            expect(find.byType(ContentDialog), findsOneWidget);
            if (title == 'Add Nextcloud account') {
              expect(find.text('Set up Nextcloud'), findsOneWidget);
              expect(find.text('Connect Nextcloud'), findsNothing);
            }
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
          if (initialLocation == '/schedule' && width == 720) {
            await _backShortcut(tester);
          } else {
            await tester.tap(
              find.byKey(const ValueKey('windows-settings-back')),
            );
            await tester.pumpAndSettle();
          }
          expect(find.byType(WindowsSchedulePage), findsOneWidget);
          expect(
            container.read(appSettingsControllerProvider).scheduleViewMode,
            ScheduleViewMode.day,
          );
          expect(
            tester.state(find.byType(WindowsSchedulePage)),
            same(workspace),
          );
          final planner = tester.widget<WindowsScheduleDayWeekView>(
            find.byType(WindowsScheduleDayWeekView),
          );
          expect(planner.daysShowed, 1);
          expect(planner.initialDate, selectedDate);
        },
      );
    }
  }

  testWidgets('Windows empty calendar creation shortcuts do not open editors', (
    tester,
  ) async {
    await _pumpRoutedApp(tester);
    final eventButton = tester.widget<IconButton>(
      find.byKey(const ValueKey('windows-new-event')),
    );
    expect(eventButton.onPressed, isNull);
    await tester.tap(find.byTooltip('See more'));
    await tester.pumpAndSettle();
    final taskButton = tester.widget<FlyoutListTile>(
      find.ancestor(
        of: find.text('New task'),
        matching: find.byType(FlyoutListTile),
      ),
    );
    expect(taskButton.onPressed, isNull);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    Focus.of(
      tester.element(
        find.descendant(
          of: find.byType(WindowsSchedulePage),
          matching: find.byType(ScaffoldPage),
        ),
      ),
    ).requestFocus();
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
      final workspace = tester.state(find.byType(WindowsSchedulePage));
      final selectedDate = await _navigateCalendar(tester);
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
      await tester.tap(find.byKey(const ValueKey('windows-settings-back')));
      await tester.pumpAndSettle();
      expect(
        find.byType(WindowsScheduleDayWeekView),
        findsOneWidget,
        reason:
            'mode=${container.read(appSettingsControllerProvider).scheduleViewMode}, route=${windowsAppRouter.state.uri}, texts=${tester.widgetList<Text>(find.byType(Text)).map((w) => w.data).join(' | ')}',
      );
      expect(find.text('Add account'), findsOneWidget);
      expect(tester.state(find.byType(WindowsSchedulePage)), same(workspace));
      final planner = tester.widget<WindowsScheduleDayWeekView>(
        find.byType(WindowsScheduleDayWeekView),
      );
      expect(planner.initialDate, selectedDate);
      expect(planner.daysShowed, 1);
    },
  );
  testWidgets(
    'Windows final subscription removal preserves Settings Back history',
    (tester) async {
      final container = await _pumpRoutedApp(tester, withSubscription: true);
      final workspace = tester.state(find.byType(WindowsSchedulePage));
      final selectedDate = await _navigateCalendar(tester);
      expect(find.text('Add account'), findsOneWidget);
      await tester.tap(find.text('Add account'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Last subscription'),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      final row = find.ancestor(
        of: find.text('Last subscription'),
        matching: find.byType(ListTile),
      );
      await tester.tap(
        find.descendant(of: row, matching: find.byType(DropDownButton)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Unsubscribe').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Unsubscribe').last);
      await tester.pumpAndSettle();
      expect(find.byType(WindowsSettingsPage), findsOneWidget);
      expect(
        (await tester.runAsync(() {
          final database = container.read(databaseProvider);
          return database.select(database.accounts).get();
        }))!,
        isEmpty,
      );
      expect(
        find.byKey(const ValueKey('windows-settings-back')).hitTestable(),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('windows-settings-back')));
      await tester.pumpAndSettle();
      expect(tester.state(find.byType(WindowsSchedulePage)), same(workspace));
      final planner = tester.widget<WindowsScheduleDayWeekView>(
        find.byType(WindowsScheduleDayWeekView),
      );
      expect(planner.initialDate, selectedDate);
      expect(planner.daysShowed, 1);
      expect(find.text('Add account'), findsOneWidget);
    },
  );
  testWidgets('direct Windows Settings has no fabricated Back history', (
    tester,
  ) async {
    await _pumpRoutedApp(tester, initialLocation: '/settings?page=accounts');
    expect(windowsAppRouter.canPop(), isFalse);
    expect(find.byKey(const ValueKey('windows-settings-back')), findsNothing);
    await _backShortcut(tester);
    expect(find.byType(WindowsSettingsPage), findsOneWidget);
    expect(windowsAppRouter.state.uri.toString(), '/settings?page=accounts');
    expect(windowsAppRouter.canPop(), isFalse);
  });
}

// Settings shows a progress ring while it owns setup. Let modal animations and
// real database replies progress without waiting for that ring to stop.
Future<void> _pumpConnectionPage(WidgetTester tester) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 20)),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump();
}

Future<ProviderContainer> _pumpRoutedApp(
  WidgetTester tester, {
  double width = 1200,
  String initialLocation = '/',
  bool withSubscription = false,
  DesktopConnectionFixture? connections,
}) async {
  final database = connections?.database ?? AppDatabase.memoryForTests();
  final secrets = connections?.secrets ?? InMemorySecretStore();
  final subscriptions = WebCalSubscriptionService(
    database: database,
    secretStore: secrets,
    httpTransport: _SubscriptionTransport(),
  );
  if (withSubscription) {
    await tester.runAsync(
      () => subscriptions.addSubscription(
        subscriptionUrl: 'https://calendar.example.test/fixture.ics',
        localName: 'Last subscription',
      ),
    );
  }
  addTearDown(database.close);
  tester.view
    ..devicePixelRatio = 1
    ..physicalSize = Size(width, 950);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        if (connections != null) ...[
          buildConfigProvider.overrideWithValue(connections.config),
          registrationStagingProvider.overrideWithValue(connections.staging),
          applicationOAuthGatewayProvider.overrideWithValue(connections.google),
          applicationMicrosoftOAuthServiceProvider.overrideWithValue(
            connections.microsoft,
          ),
          authorizationPersistenceProvider.overrideWithValue(
            connections.persistence,
          ),
        ],
        databaseProvider.overrideWithValue(database),
        secretStoreProvider.overrideWithValue(secrets),
        webCalSubscriptionServiceProvider.overrideWithValue(subscriptions),
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
  windowsAppRouter.go(initialLocation);
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(
    tester.element(
      find.byType(
        initialLocation.startsWith('/settings')
            ? WindowsSettingsPage
            : WindowsSchedulePage,
      ),
    ),
  );
}

Future<DateTime> _navigateCalendar(WidgetTester tester) async {
  await tester.tap(find.widgetWithText(DropDownButton, 'Week'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Day').last);
  await tester.pumpAndSettle();
  final l10n = AppLocalizations.of(
    tester.element(find.byType(WindowsSchedulePage)),
  );
  await tester.tap(find.byTooltip(l10n.shortcutNextPeriodDescription));
  await tester.pumpAndSettle();
  await tester.tap(find.byTooltip(l10n.shortcutNextPeriodDescription));
  await tester.pumpAndSettle();
  final planner = tester.widget<WindowsScheduleDayWeekView>(
    find.byType(WindowsScheduleDayWeekView),
  );
  expect(planner.daysShowed, 1);
  final today = DateTime.now();
  expect(
    planner.initialDate,
    isNot(DateTime(today.year, today.month, today.day)),
  );
  return planner.initialDate;
}

final class _SubscriptionTransport implements WebCalHttpTransport {
  @override
  Future<WebCalHttpResponse> get(
    Uri uri, {
    WebCalHttpValidators validators = const WebCalHttpValidators(),
    Uri? validatorTarget,
  }) async => WebCalHttpResponse(
    statusCode: 200,
    finalUri: uri,
    body: Uint8List.fromList(
      utf8.encode(
        'BEGIN:VCALENDAR\r\nVERSION:2.0\r\nPRODID:-//BusyMax Fixture//EN\r\nBEGIN:VEVENT\r\nUID:fixture\r\nDTSTAMP:20261004T000000Z\r\nDTSTART:20301004T090000Z\r\nDTEND:20301004T100000Z\r\nSUMMARY:Controlled subscription\r\nEND:VEVENT\r\nEND:VCALENDAR\r\n',
      ),
    ),
    etag: null,
    lastModified: null,
    contentType: 'text/calendar',
    conditionalRequestSent: false,
  );
}

Future<void> _backShortcut(WidgetTester tester) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
  await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
  await tester.pumpAndSettle();
}

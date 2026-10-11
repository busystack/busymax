import 'dart:convert';

import 'package:http/http.dart' as http;

import '../support/dav_contacts_fixture.dart';

import 'package:busymax/l10n/generated/app_localizations.dart';
import 'package:busymax/src/app/app_bootstrap.dart';
import 'package:busymax/src/android/presentation/android_settings_screen.dart';
import 'package:busymax/src/config/build_config.dart';
import 'package:busymax/src/android/android_notifications.dart';
import 'package:busymax/src/features/notifications/notification_reconciler.dart';
import 'package:busymax/src/db/app_database.dart';
import 'package:busymax/src/providers/busy_provider.dart';
import 'package:busymax/src/ui/windows/windows_settings_page.dart';
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/contacts_fixture.dart';
import '../support/memory_settings_store.dart';
import '../test_localized_app.dart';

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
  }
  await tester.pumpAndSettle();
}

Future<T> complete<T>(WidgetTester tester, Future<T> Function() action) async {
  T? value;
  Object? error;
  StackTrace? stack;
  var done = false;
  action().then(
    (result) {
      value = result;
      done = true;
    },
    onError: (Object cause, StackTrace trace) {
      error = cause;
      stack = trace;
      done = true;
    },
  );
  for (var i = 0; i < 150 && !done; i++) {
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
  }
  expect(done, isTrue, reason: 'The real route operation must complete');
  if (error != null) Error.throwWithStackTrace(error!, stack!);
  return value as T;
}

Future<void> contactActionsReady(WidgetTester tester, bool windows) async {
  bool ready() {
    final actions = find.ancestor(
      of: find.text('Remove').first,
      matching: windows ? find.byType(fluent.Button) : find.byType(TextButton),
    );
    if (actions.evaluate().isEmpty) return false;
    return (tester.widget(actions.first) as dynamic).onPressed != null;
  }

  for (var i = 0; i < 150 && !ready(); i++) {
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
  }
  expect(
    ready(),
    isTrue,
    reason: 'Native contact actions must settle after the owned enrollment and binding finish',
  );
}

void main() {
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('dev.fluttercommunity.plus/connectivity_status'),
          (_) async => null,
        );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('dev.fluttercommunity.plus/connectivity'),
          (_) async => ['wifi'],
        );
  });
  for (final windows in [true, false]) {
    for (final nextcloud in [false, true]) {
      testWidgets(
        '${windows ? 'Windows' : 'Android'} Settings completes independent ${nextcloud ? 'Nextcloud' : 'CardDAV'} setup, editing mode and cancellation',
        (tester) async {
          tester.view.physicalSize = const Size(1600, 2200);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final f = ContactsFixture(
            AppDatabase.memoryForTests(),
            realDav: true,
          );
          final dav = DavFixture();
          f.respondDav = (request) async {
            if (request.url.path.endsWith('/index.php/login/v2')) {
              return http.Response(
                jsonEncode({
                  'login': server.resolve('login').toString(),
                  'poll': {
                    'token': 'fixture',
                    'endpoint': server.resolve('poll').toString(),
                  },
                }),
                200,
                headers: {'content-type': 'application/json'},
              );
            }
            if (request.url.path.endsWith('/poll')) {
              return http.Response(
                jsonEncode({
                  'server': server.toString(),
                  'loginName': 'actual-user',
                  'appPassword': 'fixture',
                }),
                200,
                headers: {'content-type': 'application/json'},
              );
            }
            return dav.respond(request);
          };
          final container = ProviderContainer(
            overrides: [
              databaseProvider.overrideWithValue(f.database),
              busyMaxContactsControllerProvider.overrideWithValue(f.controller),
              localSettingsStoreProvider.overrideWithValue(
                MemorySettingsStore(),
              ),
              initialAppSettingsProvider.overrideWithValue(
                AppSettings.defaults(),
              ),
              accountManagementStreamProvider.overrideWith(
                (ref) => Stream.value(const []),
              ),
              calendarSourcesStreamProvider.overrideWith(
                (ref) => Stream.value(const []),
              ),
              scheduleTaskListsProvider.overrideWith((ref) async => const []),
              webCalSubscriptionsProvider.overrideWith(
                (ref) => Stream.value(const []),
              ),
              davConflictsStreamProvider.overrideWith(
                (ref) => Stream.value(const []),
              ),
              if (!windows)
                buildConfigProvider.overrideWithValue(BuildConfig.forAndroid()),
              if (!windows)
                androidNotificationServiceProvider.overrideWithValue(
                  AndroidNotificationService(
                    database: f.database,
                    settings: AppSettings.defaults,
                  ),
                ),
              notificationReconcilerProvider.overrideWithValue(
                CallbackNotificationReconciler(() async {}),
              ),
            ],
          );
          addTearDown(() async {
            await tester.pumpWidget(const SizedBox());
            await complete(tester, f.controller.close);
            container.dispose();
            await tester.runAsync(f.database.close);
          });
          await tester.pumpWidget(
            UncontrolledProviderScope(
              container: container,
              child: windows
                  ? const fluent.FluentApp(
                      localizationsDelegates: [AppLocalizations.delegate],
                      supportedLocales: AppLocalizations.supportedLocales,
                      home: WindowsSettingsPage(),
                    )
                  : localizedTestApp(child: const AndroidSettingsScreen()),
            ),
          );
          await settle(tester);
          final add = find.text(
            nextcloud ? 'Add Nextcloud contacts' : 'Add CardDAV contacts',
          );
          await tester.ensureVisible(add);
          await tester.tap(add);
          await tester.pump(const Duration(milliseconds: 400));
          await tester.tap(find.text('Cancel').last);
          await settle(tester);
          expect(
            await complete(
              tester,
              () => f.controller.store.read((tx) => tx.accounts()),
            ),
            isEmpty,
          );
          await tester.tap(add);
          await tester.pump(const Duration(milliseconds: 400));
          final fields = windows
              ? find.byType(fluent.TextBox)
              : find.byType(TextField);
          await tester.enterText(fields.at(0), 'Independent fixture');
          await tester.enterText(fields.at(1), server.toString());
          if (!nextcloud) {
            await tester.enterText(fields.at(2), 'actual-user');
            await tester.enterText(fields.at(3), 'fixture');
          }
          final enrolled = f.store.changes
              .asyncMap((_) => f.store.read((tx) => tx.count()))
              .firstWhere((count) => count > 0);
          await tester.tap(find.text('Connect').last);
          await complete(tester, () => enrolled);
          await settle(tester);
          final account = (await complete(
            tester,
            () => f.controller.store.read((tx) => tx.accounts()),
          )).single;
          await complete(
            tester,
            () => f.controller.synchronizeAccount(account.id),
          );
          await settle(tester);
          expect(account.grantedScopes, contains('carddav:read'));
          expect(
            await complete(
              tester,
              () => f.controller.suggestAttendees(
                'one',
                busyMaxAccountId: 'calendar-owner',
              ),
            ),
            isNotEmpty,
          );
          final setting = (await complete(
            tester,
            f.controller.sourceSettings,
          )).first;
          final toggle = find.byKey(
            ValueKey('contacts-source:${setting.source.key}'),
          );
          await tester.ensureVisible(toggle);
          await tester.tap(toggle);
          await settle(tester);
          expect(
            (await complete(tester, f.controller.sourceSettings)).first.enabled,
            isFalse,
          );
          expect(
            (await complete(
              tester,
              () => f.controller.store.read((tx) => tx.account(account.id)),
            ))!.enabled,
            isTrue,
          );
          await tester.ensureVisible(find.text('Enable contact editing').first);
          await tester.pumpAndSettle();
          final upgraded = f.store.changes
              .asyncMap((_) => f.store.read((tx) => tx.account(account.id)))
              .firstWhere(
                (a) => a?.grantedScopes.contains('carddav:write') == true,
              );
          await tester.tap(find.text('Enable contact editing').first);
          await complete(tester, () => upgraded);
          await contactActionsReady(tester, windows);
          await complete(
            tester,
            () => f.controller.synchronizeAccount(account.id),
          );
          await settle(tester);
          expect(
            (await complete(
              tester,
              () => f.controller.store.read((tx) => tx.account(account.id)),
            ))!.grantedScopes,
            contains('carddav:write'),
          );
          await tester.ensureVisible(find.text('Remove').first);
          await tester.pumpAndSettle();
          await tester.tap(find.text('Remove').first);
          await settle(tester);
          expect(
            await complete(
              tester,
              () => f.controller.store.read((tx) => tx.accounts()),
            ),
            isEmpty,
          );
          expect(f.davSecrets, isEmpty);
          await tester.pumpWidget(const SizedBox());
          await tester.pumpAndSettle();
          await complete(tester, f.controller.close);
          container.dispose();
        },
      );
    }
  }
  for (final windows in [true, false]) {
    for (final provider in [BusyProvider.google, BusyProvider.microsoft]) {
      testWidgets(
        '${windows ? 'Windows' : 'Android'} Settings enrolls $provider, upgrades, selects and removes',
        (tester) async {
          tester.view.physicalSize = const Size(1600, 2000);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final fixture = ContactsFixture(AppDatabase.memoryForTests());
          await tester.runAsync(() => fixture.addParent(provider));
          final parents = await tester.runAsync(
            () => fixture.accounts.accountById(provider.name),
          );
          final container = ProviderContainer(
            overrides: [
              databaseProvider.overrideWithValue(fixture.database),
              signedInSyncRunnerProvider.overrideWithValue((_, _) async {}),
              allAccountsSyncRunnerProvider.overrideWithValue(() async {}),
              notificationReconcilerProvider.overrideWithValue(
                CallbackNotificationReconciler(() async {}),
              ),
              if (!windows)
                androidNotificationServiceProvider.overrideWithValue(
                  AndroidNotificationService(
                    database: fixture.database,
                    settings: AppSettings.defaults,
                  ),
                ),
              busyMaxContactsControllerProvider.overrideWithValue(
                fixture.controller,
              ),
              localSettingsStoreProvider.overrideWithValue(
                MemorySettingsStore(),
              ),
              initialAppSettingsProvider.overrideWithValue(
                AppSettings.defaults(),
              ),
              if (!windows)
                buildConfigProvider.overrideWithValue(BuildConfig.forAndroid()),
              accountManagementStreamProvider.overrideWith(
                (ref) => Stream.value([parents!]),
              ),
              calendarSourcesStreamProvider.overrideWith(
                (ref) => Stream.value(const []),
              ),
              scheduleTaskListsProvider.overrideWith((ref) async => const []),
              webCalSubscriptionsProvider.overrideWith(
                (ref) => Stream.value(const []),
              ),
              davConflictsStreamProvider.overrideWith(
                (ref) => Stream.value(const []),
              ),
            ],
          );
          addTearDown(() async {
            await tester.pumpWidget(const SizedBox());
            container.dispose();
            await complete(tester, fixture.controller.close);
            await tester.runAsync(fixture.database.close);
          });
          await tester.pumpWidget(
            UncontrolledProviderScope(
              container: container,
              child: windows
                  ? const fluent.FluentApp(
                      localizationsDelegates: [AppLocalizations.delegate],
                      supportedLocales: AppLocalizations.supportedLocales,
                      home: WindowsSettingsPage(),
                    )
                  : localizedTestApp(child: const AndroidSettingsScreen()),
            ),
          );
          await settle(tester);
          expect(
            find.text(
              'Use cached contacts from this account when adding event guests.',
            ),
            findsOneWidget,
          );
          await tester.ensureVisible(
            find.text('Enable contact suggestions').first,
          );
          await tester.tap(find.text('Enable contact suggestions').first);
          await settle(tester);
          final id = 'contacts:${provider.name}';
          await complete(
            tester,
            () => fixture.controller.synchronizeAccount(id),
          );
          await settle(tester);
          expect(find.textContaining('Read-only'), findsWidgets);
          expect(
            await complete(
              tester,
              () => fixture.controller.suggestAttendees(
                'ada',
                busyMaxAccountId: provider.name,
              ),
            ),
            hasLength(1),
          );
          // Select the exact source by its provider-discovered name.
          final settings = (await complete(
            tester,
            fixture.controller.sourceSettings,
          ));
          final sourceText = find.byKey(
            ValueKey('contacts-source:${settings.single.source.key}'),
          );
          expect(sourceText, findsOneWidget);
          await tester.ensureVisible(sourceText);
          await tester.tap(sourceText);
          await settle(tester);
          expect(
            (await complete(
              tester,
              fixture.controller.sourceSettings,
            )).single.enabled,
            isFalse,
          );
          expect(
            await complete(
              tester,
              () => fixture.controller.suggestAttendees(
                'ada',
                busyMaxAccountId: provider.name,
              ),
            ),
            isEmpty,
          );
          await tester.tap(sourceText);
          await settle(tester);
          await tester.ensureVisible(find.text('Enable contact editing').first);
          await tester.pumpAndSettle();
          await tester.tap(find.text('Enable contact editing').first);
          await settle(tester);
          expect(find.textContaining('Read and write access'), findsWidgets);
          await tester.ensureVisible(find.text('Remove').first);
          await tester.pumpAndSettle();
          await tester.tap(find.text('Remove').first);
          await settle(tester);
          expect(
            await complete(
              tester,
              () => fixture.controller.suggestAttendees(
                'ada',
                busyMaxAccountId: provider.name,
              ),
            ),
            isEmpty,
          );
          expect(
            await complete(
              tester,
              () => fixture.store.read((tx) => tx.account(id)),
            ),
            isNull,
          );
          await tester.pumpWidget(const SizedBox());
          await complete(tester, fixture.controller.close);
          container.dispose();
        },
      );
    }
  }
}

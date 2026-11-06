import 'package:busymax/l10n/generated/app_localizations.dart';
import 'package:busymax/src/android/android_notifications.dart';
import 'package:busymax/src/android/presentation/android_settings_screen.dart';
import 'package:busymax/src/app/app_bootstrap.dart';
import 'package:busymax/src/config/build_config.dart';
import 'package:busymax/src/core/secrets/secret_store.dart';
import 'package:busymax/src/db/app_database.dart';
import 'package:busymax/src/features/accounts/data/accounts_repository.dart';
import 'package:busymax/src/features/notifications/notification_reconciler.dart';
import 'package:busymax/src/features/connectivity/network_connectivity_service.dart';
import 'package:busymax/src/features/settings/presentation/settings_screen.dart';
import 'package:busymax/src/ui/windows/windows_settings_page.dart';
import 'package:drift/drift.dart' show Value;

import 'dart:convert';

import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../../../platform/contacts_settings_routes_test.dart' show settle;
import '../../../support/contacts_fixture.dart';
import '../../../support/fake_autostart_service.dart';
import '../../../support/memory_settings_store.dart';
import '../../../test_localized_app.dart';

void main() {
  for (final platform in ['linux', 'android', 'windows']) {
    for (final availability in ['unknown', 'unsupported', 'available']) {
      testWidgets(
        '$platform federation control requires confirmed capability: $availability',
        (tester) async {
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = const Size(1200, 2000);
          addTearDown(tester.view.resetDevicePixelRatio);
          addTearDown(tester.view.resetPhysicalSize);
          final db = AppDatabase.memoryForTests();
          addTearDown(db.close);
          final contacts = ContactsFixture(db);
          await db
              .into(db.accounts)
              .insert(
                AccountsCompanion.insert(
                  id: 'account',
                  provider: 'nextcloud',
                  providerAccountId: 'alice',
                  authority: 'https://cloud.example.test',
                  credentialKind: 'nextcloud_app_password',
                  displayName: const Value('Nextcloud account'),
                  authState: const Value('signed_in'),
                  providerMetadataJson: Value(
                    jsonEncode({
                      if (availability != 'unknown')
                        'federation': {
                          'available': availability == 'available',
                          'generation': 0,
                          if (availability == 'available') 'count': 0,
                        },
                    }),
                  ),
                  createdAtUtc: 'now',
                  updatedAtUtc: 'now',
                ),
              );
          final account = (await AccountsRepository(database: db)
              .accountById('account'))!;
          var requests = 0;
          final client = MockClient((_) async {
            requests++;
            return http.Response('', 503);
          });
          final container = ProviderContainer(
            overrides: [
              databaseProvider.overrideWithValue(db),
              secretStoreProvider.overrideWithValue(InMemorySecretStore()),
              baseHttpClientProvider.overrideWithValue(client),
              busyMaxContactsControllerProvider.overrideWithValue(
                contacts.controller,
              ),
              desktopAutostartServiceProvider.overrideWithValue(
                FakeAutostartService(),
              ),
              initialAppSettingsProvider.overrideWithValue(
                AppSettings.defaults(),
              ),
              localSettingsStoreProvider.overrideWithValue(
                MemorySettingsStore(),
              ),
              networkAvailabilityProvider.overrideWith(
                (ref) => Stream.value(NetworkAvailability.offline),
              ),
              networkConnectivityMonitorProvider.overrideWith((ref) {
                final monitor =
                    NetworkConnectivityMonitor.withoutPlatformObservation();
                ref.onDispose(monitor.dispose);
                return monitor;
              }),
              accountsStreamProvider.overrideWith(
                (ref) => Stream.value([account]),
              ),
              accountManagementStreamProvider.overrideWith(
                (ref) => Stream.value([account]),
              ),
              calendarSourcesStreamProvider.overrideWith(
                (ref) => Stream.value(const []),
              ),
              davCollectionsStreamProvider.overrideWith(
                (ref) => Stream.value(const []),
              ),
              scheduleTaskListsProvider.overrideWith((ref) async => const []),
              webCalSubscriptionsProvider.overrideWith(
                (ref) => Stream.value(const []),
              ),
              davConflictsStreamProvider.overrideWith(
                (ref) => Stream.value(const []),
              ),
              notificationReconcilerProvider.overrideWithValue(
                CallbackNotificationReconciler(() async {}),
              ),
              if (platform == 'android') ...[
                buildConfigProvider.overrideWithValue(BuildConfig.forAndroid()),
                androidNotificationServiceProvider.overrideWithValue(
                  AndroidNotificationService(
                    database: db,
                    settings: AppSettings.defaults,
                  ),
                ),
              ],
            ],
          );
          addTearDown(() async {
            await tester.pumpWidget(const SizedBox.shrink());
            container.dispose();
            client.close();
            await tester.runAsync(contacts.close);
          });
          await tester.pumpWidget(
            UncontrolledProviderScope(
              container: container,
              child: platform == 'windows'
                  ? const fluent.FluentApp(
                      localizationsDelegates: [AppLocalizations.delegate],
                      supportedLocales: AppLocalizations.supportedLocales,
                      home: WindowsSettingsPage(initialPage: 'accounts'),
                    )
                  : localizedTestApp(
                      child: platform == 'linux'
                          ? const SettingsScreen(
                              initialPage: SettingsPage.accounts,
                            )
                          : const AndroidSettingsScreen(),
                    ),
            ),
          );
          await settle(tester);
          if (platform == 'linux') {
            final entry = find.byKey(const ValueKey('account-entry-account'));
            await tester.ensureVisible(entry);
            await tester.tap(entry);
            await settle(tester);
          } else if (platform == 'windows') {
            final row = find.ancestor(
              of: find.text('Nextcloud account'),
              matching: find.byType(fluent.ListTile),
            );
            await tester.ensureVisible(row);
            final menu = find.descendant(
              of: row,
              matching: find.byType(fluent.DropDownButton),
            );
            await tester.tap(menu);
            await settle(tester);
          }
          final invitations = find.text(
            '${AppLocalizations.of(tester.element(find.byType(platform == 'windows'
                ? WindowsSettingsPage
                : platform == 'linux'
                ? SettingsScreen
                : AndroidSettingsScreen))).nextcloudFederationInvitations} (0)',
          );
          if (platform == 'android' && availability == 'available') {
            await tester.scrollUntilVisible(
              invitations,
              300,
              scrollable: find.byType(Scrollable).first,
            );
          }
          expect(
            invitations,
            availability == 'available' ? findsOneWidget : findsNothing,
          );
          expect(requests, 0);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}

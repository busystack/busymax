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
import 'package:busymax/src/features/settings/presentation/account_collection_creation_feedback.dart';
import 'package:busymax/src/features/settings/presentation/settings_screen.dart';
import 'package:busymax/src/ui/windows/windows_settings_page.dart';
import 'package:drift/drift.dart' show Value;
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
    for (final rejected in [true, false]) {
      testWidgets(
        '$platform settings restores offline notices with empty activity; rejected=$rejected',
        (tester) async {
          tester.view.physicalSize = const Size(1400, 2200);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final db = AppDatabase.memoryForTests();
          final contacts = ContactsFixture(db);
          for (final id in ['account', 'other']) {
            await db
                .into(db.accounts)
                .insert(
                  AccountsCompanion.insert(
                    id: id,
                    provider: 'caldav',
                    providerAccountId: id,
                    authority: 'https://example.test/',
                    credentialKind: 'caldav_password',
                    displayName: Value(
                      id == 'account' ? 'Offline account' : 'Other account',
                    ),
                    authState: const Value('signed_in'),
                    createdAtUtc: '2026-11-04T00:00:00Z',
                    updatedAtUtc: '2026-11-04T00:00:00Z',
                  ),
                );
            if (id == 'other' || rejected) {
              await db
                  .into(db.davCollectionCreations)
                  .insert(
                    DavCollectionCreationsCompanion.insert(
                      id: 'creation-$id',
                      accountId: id,
                      authority: 'https://example.test/',
                      homeUri: 'https://example.test/calendars/',
                      targetUri: 'https://example.test/calendars/creation-$id/',
                      displayName: id == 'account'
                          ? 'Requested collection'
                          : 'Other account rejection',
                      componentsJson: '["VEVENT"]',
                      state: const Value('rejected'),
                      lastErrorKind: const Value('authorization'),
                      lastErrorCode: const Value('DavPermissionDenied'),
                      lastErrorStatus: const Value(403),
                      createdAtUtc: '2026-11-04T00:00:00Z',
                    ),
                  );
            }
          }
          final account = (await AccountsRepository(database: db)
              .accountById('account'))!;
          var requests = 0;
          final client = MockClient((_) async {
            requests++;
            throw http.ClientException('offline');
          });
          final container = ProviderContainer(
            overrides: [
              databaseProvider.overrideWithValue(db),
              secretStoreProvider.overrideWithValue(InMemorySecretStore()),
              baseHttpClientProvider.overrideWithValue(client),
              networkAvailabilityProvider.overrideWith(
                (ref) => Stream.value(NetworkAvailability.offline),
              ),
              networkConnectivityMonitorProvider.overrideWith((ref) {
                final monitor =
                    NetworkConnectivityMonitor.withoutPlatformObservation();
                ref.onDispose(monitor.dispose);
                return monitor;
              }),
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
          final activity = container.read(accountSyncActivityProvider);
          await expectLater(
            activity.run(
              'account',
              'dav',
              () async => throw http.ClientException('offline'),
            ),
            throwsA(isA<http.ClientException>()),
          );
          expect(activity.collectionCreationFailures('account'), isEmpty);
          Widget host() => UncontrolledProviderScope(
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
          );
          await tester.pumpWidget(host());
          await settle(tester);
          if (platform == 'linux') {
            final entry = find.byKey(const ValueKey('account-entry-account'));
            await tester.ensureVisible(entry);
            await tester.tap(entry);
            await settle(tester);
          }
          // Do not read the persisted provider here: the actual settings parent
          // must start its subscription despite the empty in-memory collection.
          expect(
            find.byType(AccountCollectionCreationFeedback),
            rejected ? findsOneWidget : findsNothing,
          );
          expect(
            find.text('Requested collection'),
            rejected ? findsOneWidget : findsNothing,
          );
          expect(find.text('Other account rejection'), findsNothing);
          expect(activity.collectionCreationFailures('account'), isEmpty);
          if (rejected) {
            final dismiss = find.byKey(
              const ValueKey((
                'dismiss-collection-creation',
                'account',
                'creation-account',
              )),
            );
            await tester.ensureVisible(dismiss);
            await settle(tester);
            await tester.tap(dismiss.hitTestable());
            await settle(tester);
            expect(find.text('Requested collection'), findsNothing);
            expect(
              find.byType(AccountCollectionCreationFeedback),
              findsNothing,
            );
            expect(
              (await db.select(db.davCollectionCreations).get()).every(
                (op) => op.state == 'rejected',
              ),
              isTrue,
            );
            // Acknowledgment is persisted locally; the rejected operation
            // remains in the journal without requiring a network operation.
            expect(
              await container
                  .read(davCollectionCreationNoticesProvider)
                  .load('account'),
              isEmpty,
            );
          }
          expect(requests, 0);
          expect(contacts.requests, isEmpty);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}

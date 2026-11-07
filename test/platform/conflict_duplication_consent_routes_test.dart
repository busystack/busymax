import 'package:busymax/l10n/generated/app_localizations.dart';
import 'package:busymax/src/app/app_bootstrap.dart';
import 'package:busymax/src/android/presentation/android_settings_screen.dart';
import 'package:busymax/src/config/build_config.dart';
import 'package:busymax/src/android/android_notifications.dart';
import 'package:busymax/src/features/notifications/notification_reconciler.dart';
import 'package:busymax/src/db/app_database.dart';
import 'package:busymax/src/dav/mutation/dav_conflict_repository.dart';
import 'package:busymax/src/features/settings/presentation/settings_screen.dart';
import 'package:busymax/src/ui/windows/windows_diagnostics_dialog.dart';
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/contacts_fixture.dart';
import '../support/dav_conflict_fixture.dart';
import '../support/memory_settings_store.dart';
import '../test_localized_app.dart';
import 'contacts_settings_routes_test.dart' show settle, complete;

void main() {
  setUp(() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    for (final channel in ['yaru_window', 'yaru_window/events']) {
      messenger.setMockMethodCallHandler(
        MethodChannel(channel),
        (_) async => <String, Object?>{},
      );
    }
  });
  for (final platform in ['Linux', 'Windows', 'Android']) {
    for (final component in ['VEVENT', 'VTODO']) {
      testWidgets(
        '$platform production $component conflict duplication cancel then approve',
        (tester) async {
          tester.view.physicalSize = const Size(1400, 2400);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final fixture = ContactsFixture(AppDatabase.memoryForTests());
          final db = fixture.database;
          await seedSchedulingConflict(db, component: component);
          final syncCalls = <String>[];
          final container = ProviderContainer(
            overrides: [
              databaseProvider.overrideWithValue(db),
              notificationReconcilerProvider.overrideWithValue(
                CallbackNotificationReconciler(() async {}),
              ),
              if (platform == 'Android')
                androidNotificationServiceProvider.overrideWithValue(
                  AndroidNotificationService(
                    database: db,
                    settings: AppSettings.defaults,
                  ),
                ),
              busyMaxContactsControllerProvider.overrideWithValue(
                fixture.controller,
              ),
              initialAppSettingsProvider.overrideWithValue(
                AppSettings.defaults(),
              ),
              localSettingsStoreProvider.overrideWithValue(
                MemorySettingsStore(),
              ),
              signedInSyncRunnerProvider.overrideWithValue((id, full) async {
                syncCalls.add(id);
              }),
              if (platform == 'Android')
                buildConfigProvider.overrideWithValue(BuildConfig.forAndroid()),
            ],
          );
          addTearDown(() async {
            await tester.pumpWidget(const SizedBox.shrink());
            container.dispose();
            await complete(tester, fixture.close);
          });
          final screen = platform == 'Android'
              ? const AndroidSettingsScreen(
                  notificationConflicts: true,
                  notificationAccountId: 'account',
                )
              : const SettingsScreen(initialPage: SettingsPage.diagnostics);
          await tester.pumpWidget(
            UncontrolledProviderScope(
              container: container,
              child: platform == 'Windows'
                  ? const fluent.FluentApp(
                      localizationsDelegates: [AppLocalizations.delegate],
                      supportedLocales: AppLocalizations.supportedLocales,
                      home: fluent.ScaffoldPage(
                        content: WindowsDavConflictReview(accountId: 'account'),
                      ),
                    )
                  : localizedTestApp(child: screen),
            ),
          );
          await settle(tester);
          Future<void> duplicate() async {
            if (platform == 'Windows') {
              await tester.tap(
                find.byKey(
                  const ValueKey('windows-review-dav-conflict-conflict'),
                ),
              );
              await settle(tester);
            } else if (platform == 'Android') {
              await tester.tap(find.text('Local title').first);
              await settle(tester);
            }
            final button = find.text('Duplicate as new item').last;
            await tester.ensureVisible(button);
            await tester.tap(button);
            await settle(tester);
          }

          await duplicate();
          expect(
            find.textContaining('This item contains attendees.'),
            findsOneWidget,
          );
          final before = await complete(
            tester,
            () => db.select(db.pendingOps).get(),
          );
          expect(before.single.state, 'conflict');
          expect(syncCalls, isEmpty);
          await tester.tap(find.text('Cancel').last);
          await settle(tester);
          expect(
            await complete(tester, () => db.select(db.pendingOps).get()),
            before,
          );
          expect(
            await complete(
              tester,
              () => DavConflictRepository(database: db).watchUnresolved().first,
            ),
            hasLength(1),
          );
          await duplicate();
          await tester.tap(find.text('Duplicate as new item').last);
          await settle(tester);
          final after = await complete(
            tester,
            () => db.select(db.pendingOps).get(),
          );
          expect(after.single.operationType, 'dav.create');
          expect(
            after.single.requestJson,
            contains('"schedulingConsent":true'),
          );
          expect(syncCalls, ['account']);
          expect(
            await complete(
              tester,
              () => DavConflictRepository(database: db).watchUnresolved().first,
            ),
            isEmpty,
          );
        },
      );
    }
  }
}

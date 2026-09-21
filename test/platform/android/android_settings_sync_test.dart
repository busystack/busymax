import 'package:busymax/src/android/presentation/android_settings_screen.dart';
import 'package:busymax/src/android/android_notifications.dart';
import 'package:busymax/src/app/app_bootstrap.dart';
import 'package:busymax/src/config/build_config.dart';
import 'package:busymax/src/core/auth/oauth_models.dart';
import 'package:busymax/src/core/http/request_dispatch_exception.dart';
import 'package:busymax/src/db/app_database.dart';
import 'package:busymax/src/features/accounts/data/accounts_repository.dart';
import 'package:busymax/src/features/notifications/notification_reconciler.dart';
import 'package:busymax/src/providers/busy_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/memory_settings_store.dart';
import '../../test_localized_app.dart';

void main() {
  testWidgets('eligible Android account exposes actionable Sync', (
    tester,
  ) async {
    final calls = <String>[];
    final harness = await _pumpAndroidSettings(
      tester,
      signedInSyncRunner: (accountId, initial) async => calls.add(accountId),
    );
    addTearDown(harness.dispose);

    await _openAccountMenu(tester);
    expect(_popupValues(tester), contains('sync'));
    await tester.tap(_popupEntry('sync'));
    await tester.pumpAndSettle();

    expect(calls, ['google:g']);
  });

  testWidgets('reconnect-required Android account offers reconnect, not Sync', (
    tester,
  ) async {
    final calls = <String>[];
    final harness = await _pumpAndroidSettings(
      tester,
      reconnectRequired: true,
      signedInSyncRunner: (accountId, initial) async => calls.add(accountId),
    );
    addTearDown(harness.dispose);

    await _openAccountMenu(tester);

    expect(_popupValues(tester), isNot(contains('sync')));
    expect(_popupValues(tester), contains('reconnect'));
    expect(calls, isEmpty);
  });

  testWidgets('Android account Sync re-reads eligibility before dispatch', (
    tester,
  ) async {
    final calls = <String>[];
    final harness = await _pumpAndroidSettings(
      tester,
      signedInSyncRunner: (accountId, initial) async => calls.add(accountId),
    );
    addTearDown(harness.dispose);

    await _openAccountMenu(tester);
    expect(_popupEntry('sync'), findsOneWidget);
    await harness.accounts.markReconnectRequired('google:g');
    await tester.tap(_popupEntry('sync'));
    await tester.pumpAndSettle();

    expect(calls, isEmpty);
    expect(
      find.text('Sync failed: This account needs to be reconnected.'),
      findsOneWidget,
    );
  });

  testWidgets(
    'Android account Sync hides wrapped OAuth implementation details',
    (tester) async {
      const failure = KnownUnsentRequestException(
        kind: RequestPreDispatchFailureKind.authentication,
        cause: OAuthRefreshException(
          'OAuthRefreshFailed',
          'raw provider description refresh_token=android-test-secret',
          statusCode: 400,
          oauthError: 'invalid_grant',
          oauthErrorDescription: 'provider description [REDACTED]',
        ),
      );
      final harness = await _pumpAndroidSettings(
        tester,
        signedInSyncRunner: (accountId, initial) async => throw failure,
      );
      addTearDown(harness.dispose);

      await _openAccountMenu(tester);
      await tester.tap(_popupEntry('sync'));
      await tester.pumpAndSettle();

      expect(
        find.text('Sync failed: This account needs to be reconnected.'),
        findsOneWidget,
      );
      expect(find.textContaining('KnownUnsentRequestException'), findsNothing);
      expect(find.textContaining('OAuthRefreshException'), findsNothing);
      expect(find.textContaining('provider description'), findsNothing);
      expect(find.textContaining('android-test-secret'), findsNothing);
    },
  );

  testWidgets('Android Sync All uses the canonical safe failure message', (
    tester,
  ) async {
    const failure = KnownUnsentRequestException(
      kind: RequestPreDispatchFailureKind.authentication,
      cause: OAuthRefreshException(
        'OAuthRefreshFailed',
        'InternalOAuthException sync-all-secret',
        statusCode: 400,
        oauthError: 'invalid_grant',
      ),
    );
    final harness = await _pumpAndroidSettings(
      tester,
      allAccountsSyncRunner: () async => throw failure,
    );
    addTearDown(harness.dispose);
    final syncAll = find.widgetWithText(ListTile, 'Sync');
    await tester.scrollUntilVisible(
      syncAll,
      500,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(syncAll);
    await tester.pumpAndSettle();

    await tester.tap(syncAll);
    await tester.pumpAndSettle();

    expect(
      find.text('Sync failed: This account needs to be reconnected.'),
      findsOneWidget,
    );
    expect(find.textContaining('KnownUnsentRequestException'), findsNothing);
    expect(find.textContaining('InternalOAuthException'), findsNothing);
    expect(find.textContaining('sync-all-secret'), findsNothing);
  });
}

Future<_AndroidSettingsHarness> _pumpAndroidSettings(
  WidgetTester tester, {
  bool reconnectRequired = false,
  SignedInSyncRunner? signedInSyncRunner,
  AllAccountsSyncRunner? allAccountsSyncRunner,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(1000, 1800);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  final database = AppDatabase.memoryForTests();
  final accounts = AccountsRepository(database: database);
  await accounts.upsertSignedInAccount(
    id: 'google:g',
    provider: BusyProvider.google,
    grantedScopes: 'tasks calendar',
    displayName: 'Google User',
  );
  if (reconnectRequired) {
    await accounts.markReconnectRequired('google:g');
  }
  final container = ProviderContainer(
    overrides: [
      buildConfigProvider.overrideWithValue(BuildConfig.forAndroid()),
      databaseProvider.overrideWithValue(database),
      initialAppSettingsProvider.overrideWithValue(AppSettings.defaults()),
      localSettingsStoreProvider.overrideWithValue(MemorySettingsStore()),
      calendarSourcesStreamProvider.overrideWith(
        (ref) => Stream.value(const []),
      ),
      scheduleTaskListsProvider.overrideWith((ref) async => const []),
      webCalSubscriptionsProvider.overrideWith((ref) => Stream.value(const [])),
      davConflictsStreamProvider.overrideWith((ref) => Stream.value(const [])),
      signedInSyncRunnerProvider.overrideWithValue(
        signedInSyncRunner ?? (accountId, initial) async {},
      ),
      allAccountsSyncRunnerProvider.overrideWithValue(
        allAccountsSyncRunner ?? () async {},
      ),
      notificationReconcilerProvider.overrideWithValue(
        CallbackNotificationReconciler(() async {}),
      ),
      androidNotificationServiceProvider.overrideWithValue(
        AndroidNotificationService(
          database: database,
          settings: AppSettings.defaults,
        ),
      ),
    ],
  );
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: localizedTestApp(child: const AndroidSettingsScreen()),
    ),
  );
  await tester.pumpAndSettle();
  return _AndroidSettingsHarness(tester, container, database, accounts);
}

Future<void> _openAccountMenu(WidgetTester tester) async {
  await tester.tap(find.byType(PopupMenuButton<String>).first);
  await tester.pumpAndSettle();
}

List<String?> _popupValues(WidgetTester tester) => tester
    .widgetList<PopupMenuItem<String>>(find.byType(PopupMenuItem<String>))
    .map((item) => item.value)
    .toList();

Finder _popupEntry(String value) => find.byWidgetPredicate(
  (widget) => widget is PopupMenuItem<String> && widget.value == value,
);

final class _AndroidSettingsHarness {
  const _AndroidSettingsHarness(
    this.tester,
    this.container,
    this.database,
    this.accounts,
  );

  final WidgetTester tester;
  final ProviderContainer container;
  final AppDatabase database;
  final AccountsRepository accounts;

  Future<void> dispose() async {
    await tester.pumpWidget(const SizedBox.shrink());
    container.dispose();
    await database.close();
  }
}

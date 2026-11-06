import 'package:busymax/src/features/calendar/data/calendar_repository.dart';
import 'package:busymax/src/features/task_lists/data/task_lists_repository.dart';
import 'package:busymax/src/features/tasks/domain/task_capabilities.dart';
import 'package:busymax/src/features/calendar/data/calendar_collection_creation_service.dart';
import 'package:busymax/l10n/generated/app_localizations_en.dart';
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
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/memory_settings_store.dart';
import '../../test_localized_app.dart';

void main() {
  for (final (provider, caps, sharing) in [
    (BusyProvider.caldav, caldavTaskCollectionCapabilities, false),
    (BusyProvider.caldav, nextcloudTaskCollectionCapabilities, false),
    (BusyProvider.nextcloud, nextcloudTaskCollectionCapabilities, true),
    (BusyProvider.nextcloud, caldavTaskCollectionCapabilities, false),
  ]) {
    testWidgets(
      '$provider task settings separate sharing from export; sharing=$sharing, support=${caps.supportsSharing}',
      (tester) async {
        final harness = await _pumpAndroidSettings(
          tester,
          provider: provider,
          authority: 'https://cloud.example.test/',
          taskCapabilities: caps,
          lists: const [
            TaskListEntity(
              accountId: 'google:g',
              id: 'tasks',
              title: 'Review tasks',
              davCollectionId: 'tasks',
              localDirty: false,
              pendingDelete: false,
              rawJson: '{}',
            ),
          ],
        );
        addTearDown(harness.dispose);
        final row = find.widgetWithText(ListTile, 'Review tasks');
        await tester.scrollUntilVisible(
          row,
          400,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.tap(row);
        await tester.pumpAndSettle();
        expect(find.widgetWithText(ListTile, 'Export'), findsOneWidget);
        expect(
          find.widgetWithText(ListTile, 'Sharing'),
          sharing ? findsOneWidget : findsNothing,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
  for (final provider in [BusyProvider.caldav, BusyProvider.nextcloud]) {
    testWidgets(
      '$provider calendar settings expose native export with provider-specific sharing and scheduling',
      (tester) async {
        final harness = await _pumpAndroidSettings(
          tester,
          provider: provider,
          authority: 'https://cloud.example.test/',
          sources: [
            CalendarSourceEntity(
              id: 'calendar',
              accountId: 'google:g',
              provider: provider,
              providerCalendarId: '/calendar/',
              davCollectionId: 'calendar',
              summary: 'Review calendar',
              selected: true,
              hidden: false,
              readOnly: true,
              isDeleted: false,
            ),
          ],
        );
        addTearDown(harness.dispose);
        final row = find.widgetWithText(ListTile, 'Review calendar');
        await tester.scrollUntilVisible(
          row,
          400,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.tap(row);
        await tester.pumpAndSettle();
        expect(find.widgetWithText(ListTile, 'Export'), findsOneWidget);
        expect(
          find.widgetWithText(ListTile, 'Sharing'),
          provider == BusyProvider.nextcloud ? findsOneWidget : findsNothing,
        );
        expect(
          find.byIcon(Icons.inbox_outlined),
          provider == BusyProvider.nextcloud ? findsOneWidget : findsNothing,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final provider in [BusyProvider.caldav, BusyProvider.nextcloud]) {
    testWidgets(
      '$provider retained local account recovers denial, approval and revocation from Sync',
      (tester) async {
        const platform = MethodChannel('io.busystack.busymax/android');
        var granted = false, approveRequest = false;
        final platformCalls = <String>[];
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(platform, (call) async {
              platformCalls.add(call.method);
              if (call.method == 'hasLocalNetworkAccess') return granted;
              if (call.method == 'requestLocalNetworkAccess') {
                granted = approveRequest;
                return granted;
              }
              return null;
            });
        addTearDown(
          () => TestDefaultBinaryMessengerBinding
              .instance
              .defaultBinaryMessenger
              .setMockMethodCallHandler(platform, null),
        );
        final syncs = <String>[];
        final harness = await _pumpAndroidSettings(
          tester,
          provider: provider,
          authority: 'https://192.168.1.20/',
          signedInSyncRunner: (id, _) async => syncs.add(id),
        );
        addTearDown(harness.dispose);
        Future<void> sync() async {
          await _openAccountMenu(tester);
          await tester.tap(_popupEntry('sync'));
          await tester.pumpAndSettle();
        }

        await sync();
        expect(syncs, isEmpty);
        expect(
          find.text(AppLocalizationsEn().localNetworkAccessRecovery),
          findsOneWidget,
        );
        await tester.tap(find.widgetWithText(TextButton, 'Cancel').last);
        await tester.pumpAndSettle();
        approveRequest = true;
        await sync();
        expect(syncs, ['google:g']);
        // A later revocation must be rechecked, including a permanently denied
        // runtime prompt. System settings supplies a recovery path in that case.
        granted = false;
        approveRequest = false;
        await sync();
        expect(syncs, ['google:g']);
        await tester.tap(find.widgetWithText(FilledButton, 'Settings').last);
        await tester.pumpAndSettle();
        expect(
          platformCalls.where((m) => m == 'requestLocalNetworkAccess'),
          hasLength(3),
        );
        expect(platformCalls, contains('openAppSettings'));
        granted = true;
        await sync();
        expect(syncs, ['google:g', 'google:g']);
        final account = await harness.accounts.accountById('google:g');
        expect(account!.isSyncEligible, isTrue);
        expect(
          account.authority,
          provider == BusyProvider.nextcloud
              ? 'https://192.168.1.20'
              : 'https://192.168.1.20/',
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'Sync all skips only a denied DAV account and synchronizes unrelated accounts',
    (tester) async {
      const platform = MethodChannel('io.busystack.busymax/android');
      var granted = false, syncs = 0;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            platform,
            (call) async =>
                call.method == 'hasLocalNetworkAccess' ||
                    call.method == 'requestLocalNetworkAccess'
                ? granted
                : null,
          );
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(platform, null),
      );
      final syncedAccounts = <String>[];
      final harness = await _pumpAndroidSettings(
        tester,
        provider: BusyProvider.caldav,
        authority: 'https://192.168.1.20/',
        signedInSyncRunner: (id, full) async {
          expectSync(full, isFalse);
          syncedAccounts.add(id);
        },
        allAccountsSyncRunner: () async {
          syncs++;
        },
      );
      addTearDown(harness.dispose);
      for (final (id, provider, authority) in [
        ('google:public', BusyProvider.google, null),
        ('dav:public', BusyProvider.nextcloud, 'https://203.0.113.20/'),
        ('microsoft:public', BusyProvider.microsoft, null),
      ]) {
        await harness.accounts.upsertSignedInAccount(
          id: id,
          provider: provider,
          authority: authority,
          grantedScopes: 'calendar tasks',
        );
      }
      await tester.pumpAndSettle();
      final action = find.widgetWithText(ListTile, 'Sync');
      await tester.scrollUntilVisible(
        action,
        500,
        scrollable: find.byType(Scrollable).first,
      );
      tester.widget<ListTile>(action).onTap!();
      // Sync all remains busy while the permission recovery dialog is open.
      for (
        var i = 0;
        i < 10 && find.byType(AlertDialog).evaluate().isEmpty;
        i++
      ) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(syncs, 0);
      await tester.tap(find.widgetWithText(TextButton, 'Cancel').last);
      await tester.pumpAndSettle();
      expect(syncedAccounts, [
        'google:public',
        'microsoft:public',
        'dav:public',
      ]);
      expect(syncs, 0);
      granted = true;
      tester.widget<ListTile>(action).onTap!();
      await tester.pumpAndSettle();
      expect(syncs, 1);
    },
  );

  testWidgets(
    'CalDAV calendar creation with a failed refresh is shown as saved without retry',
    (tester) async {
      final creator = _PendingCreator();
      final harness = await _pumpAndroidSettings(
        tester,
        provider: BusyProvider.caldav,
        creator: creator,
      );
      addTearDown(harness.dispose);
      final row = find.widgetWithText(ListTile, 'New calendar');
      await tester.scrollUntilVisible(
        row,
        500,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(row);
      await tester.tap(row);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Work');
      await tester.tap(find.text('Save').last);
      await tester.pumpAndSettle();
      expect(creator.calls, 1);
      expect(find.text(AppLocalizationsEn().davRefreshPending), findsOneWidget);
      expect(find.textContaining('saved on Nextcloud'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'blocked notification System action opens app settings separately from precision',
    (tester) async {
      const platform = MethodChannel('io.busystack.busymax/android');
      final calls = <String>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(platform, (call) async {
            calls.add(call.method);
            return null;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(platform, null),
      );
      final harness = await _pumpAndroidSettings(tester);
      addTearDown(harness.dispose);
      harness.container
          .read(androidNotificationServiceProvider)
          .readiness
          .value = const AndroidNotificationReadiness(
        initialized: true,
        notificationsAllowed: false,
        remindersAllowed: true,
        summariesAllowed: true,
        statusAllowed: true,
        exactAlarms: false,
      );
      await tester.pump();
      final row = find.byWidgetPredicate(
        (widget) =>
            widget is ListTile &&
            widget.title is Text &&
            (widget.title! as Text).data == 'Notifications' &&
            widget.trailing is TextButton,
      );
      await tester.scrollUntilVisible(
        row,
        500,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(row);
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: row,
          matching: find.widgetWithText(TextButton, 'System'),
        ),
      );
      await tester.pumpAndSettle();
      expect(calls, contains('openNotificationSettings'));
      const precision =
          'Exact alarm access is unavailable. Android may deliver reminders later.';
      expect(
        find.descendant(of: row, matching: find.text(precision)),
        findsNothing,
      );
      expect(
        find.descendant(
          of: find.widgetWithText(ListTile, 'Reminders'),
          matching: find.text(precision),
        ),
        findsOneWidget,
      );
    },
  );
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

    expect(
      find.textContaining('This account needs to be reconnected'),
      findsWidgets,
    );
    expect(find.textContaining('reauth_required'), findsNothing);

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
  BusyProvider provider = BusyProvider.google,
  String? authority,
  CalendarCollectionCreator? creator,
  List<CalendarSourceEntity> sources = const [],
  List<TaskListEntity> lists = const [],
  TaskCollectionCapabilities? taskCapabilities,
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
    provider: provider,
    authority:
        authority ??
        (provider == BusyProvider.caldav ? 'https://example.test/' : null),
    grantedScopes: 'tasks calendar',
    displayName: 'Google User',
  );
  if (reconnectRequired) {
    await accounts.markReconnectRequired('google:g');
  }
  final container = ProviderContainer(
    overrides: [
      if (creator != null)
        calendarCollectionCreationServiceProvider.overrideWithValue(creator),
      buildConfigProvider.overrideWithValue(BuildConfig.forAndroid()),
      databaseProvider.overrideWithValue(database),
      initialAppSettingsProvider.overrideWithValue(AppSettings.defaults()),
      localSettingsStoreProvider.overrideWithValue(MemorySettingsStore()),
      calendarSourcesStreamProvider.overrideWith(
        (ref) => Stream.value(sources),
      ),
      scheduleTaskListsProvider.overrideWith((ref) async => lists),
      if (taskCapabilities != null)
        davTaskCollectionCapabilitiesProvider.overrideWith(
          (ref, key) => Stream.value(taskCapabilities),
        ),
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

final class _PendingCreator implements CalendarCollectionCreator {
  int calls = 0;
  @override
  Future<CalendarCollectionCreationResult> createCalendar({
    required String accountId,
    required String title,
  }) async {
    calls++;
    return const CalendarCollectionCreationResult(
      outcome: CalendarCollectionCreationOutcome.createdRefreshPending,
    );
  }
}

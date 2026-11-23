import 'package:busymax/src/features/sync/sync_request.dart';
import 'package:busymax/src/features/sync/domain_sync_schedule.dart';

import 'dart:async';

import 'package:busymax/src/android/presentation/android_schedule_screen.dart';
import 'package:busymax/src/features/connectivity/network_connectivity_service.dart';
import 'package:busymax/src/schedule/schedule_sidebar_sources.dart';
import 'package:busymax/src/dav/dav_errors.dart';
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
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/memory_settings_store.dart';
import '../../test_localized_app.dart';

void main() {
  testWidgets(
    'Android overview and detail retain verified history after a partial refresh',
    verifyAndroidAccountRefreshStatus,
  );

  testWidgets(
    'Android settings delete explains partial deletion and retains the collection',
    (tester) async {
      final source = CalendarSourceEntity(
        id: 'partial-calendar',
        accountId: 'google:g',
        provider: BusyProvider.caldav,
        providerCalendarId: 'partial-calendar',
        davCollectionId: 'partial-calendar',
        summary: 'Surviving collection',
        selected: true,
        hidden: false,
        readOnly: false,
        isDeleted: false,
        davEffectivePermissions: const {
          'ownerHref': 'https://example.test/principals/qa/',
          'principalHref': 'https://example.test/principals/qa/',
          'parentPrivileges': ['{DAV:}unbind'],
        },
      );
      final repository = _PartialRemovalRepository();
      final harness = await _pumpAndroidSettings(
        tester,
        provider: BusyProvider.caldav,
        sources: [source],
        calendarRepository: repository,
        workspaceSources: true,
      );
      addTearDown(harness.dispose);
      final row = find.widgetWithText(ListTile, 'Surviving collection');
      await tester.scrollUntilVisible(
        row,
        400,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(
        find.descendant(of: row, matching: find.byTooltip('Options')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ListTile, 'Delete'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Delete').last);
      await tester.pumpAndSettle();
      expect(repository.calls, 1);
      expect(
        find.textContaining(AppLocalizationsEn().davCollectionRemovalPartial),
        findsOneWidget,
      );
      expect(find.text('Surviving collection'), findsOneWidget);
    },
  );

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
          workspaceSources: true,
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
        await tester.tap(
          find.descendant(of: row, matching: find.byTooltip('Options')),
        );
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
          workspaceSources: true,
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
        await tester.tap(
          find.descendant(of: row, matching: find.byTooltip('Options')),
        );
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
          manualSyncRunner: (request) async =>
              syncs.add(request.scope.accountId!),
        );
        addTearDown(harness.dispose);
        Future<void> sync() async {
          await tester.tap(
            find.byKey(const ValueKey('account-recovery-google:g')),
          );
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
          .setMockMethodCallHandler(platform, (call) async {
            if (call.method == 'requiresLocalNetworkAccess') {
              return (call.arguments as Map)['host'] == '192.168.1.20';
            }
            if (call.method == 'hasLocalNetworkAccess' ||
                call.method == 'requestLocalNetworkAccess') {
              return granted;
            }
            return null;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(platform, null),
      );
      final syncedAccounts = <String>[];
      final strategies = <SyncStrategy>[];
      final harness = await _pumpAndroidSettings(
        tester,
        category: AndroidSettingsCategory.accounts,
        openAccount: false,
        provider: BusyProvider.caldav,
        authority: 'https://192.168.1.20/',
        manualSyncRunner: (request) async {
          strategies.add(request.strategy);
          if (request.scope == allSyncScope) {
            syncs++;
          } else {
            syncedAccounts.add(request.scope.accountId!);
          }
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
      final action = find.widgetWithText(ListTile, 'Refresh all');
      await tester.scrollUntilVisible(
        action,
        500,
        scrollable: find.byType(Scrollable).first,
      );
      tester.widget<ListTile>(action).onTap!();
      // Permission recovery remains available for the blocked account.
      for (
        var i = 0;
        i < 10 && find.byType(AlertDialog).evaluate().isEmpty;
        i++
      ) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(syncs, 0);
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Cancel'),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        syncedAccounts,
        unorderedEquals(['google:public', 'microsoft:public', 'dav:public']),
      );
      expect(syncs, 0);
      granted = true;
      tester.widget<ListTile>(action).onTap!();
      await tester.pumpAndSettle();
      expect(syncs, 1);
      expect(strategies, everyElement(SyncStrategy.ordinary));
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
      final harness = await _pumpAndroidSettings(
        tester,
        category: AndroidSettingsCategory.notifications,
      );
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
      manualSyncRunner: (request) async => calls.add(request.scope.accountId!),
    );
    addTearDown(harness.dispose);

    await tester.tap(find.byKey(const ValueKey('account-recovery-google:g')));
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
      manualSyncRunner: (request) async => calls.add(request.scope.accountId!),
    );
    addTearDown(harness.dispose);

    expect(
      find.textContaining('This account needs to be reconnected'),
      findsWidgets,
    );
    expect(find.textContaining('reauth_required'), findsNothing);

    expect(
      tester
          .widget<ListTile>(
            find.byKey(const ValueKey('account-recovery-google:g')),
          )
          .title,
      isA<Text>().having(
        (t) => t.data,
        'recovery label',
        'Reconnect this account',
      ),
    );
    expect(calls, isEmpty);
  });

  testWidgets('Android account Sync re-reads eligibility before dispatch', (
    tester,
  ) async {
    final calls = <String>[];
    final harness = await _pumpAndroidSettings(
      tester,
      manualSyncRunner: (request) async => calls.add(request.scope.accountId!),
    );
    addTearDown(harness.dispose);

    final action = tester
        .widget<ListTile>(
          find.byKey(const ValueKey('account-recovery-google:g')),
        )
        .onTap!;
    await harness.accounts.markReconnectRequired('google:g');
    action();
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
        manualSyncRunner: (request) async => throw failure,
      );
      addTearDown(harness.dispose);

      await tester.tap(find.byKey(const ValueKey('account-recovery-google:g')));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Your Google account needs to be reconnected to resume calendar and task synchronization.',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('KnownUnsentRequestException'), findsNothing);
      expect(find.textContaining('OAuthRefreshException'), findsNothing);
      expect(find.textContaining('provider description'), findsNothing);
      expect(find.textContaining('android-test-secret'), findsNothing);
    },
  );

  testWidgets(
    'Force full resync explicitly requests every eligible account in full',
    (tester) async {
      final calls = <SyncRequest>[];
      final harness = await _pumpAndroidSettings(
        tester,
        category: AndroidSettingsCategory.diagnostics,
        manualSyncRunner: (request) async => calls.add(request),
      );
      addTearDown(harness.dispose);
      final action = find.widgetWithText(ListTile, 'Force full resync');
      await tester.scrollUntilVisible(
        action,
        400,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(action);
      await tester.pumpAndSettle();
      expect(calls.single.scope, allSyncScope);
      expect(calls.single.strategy, SyncStrategy.fullRecovery);
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
      category: AndroidSettingsCategory.accounts,
      openAccount: false,
      manualSyncRunner: (request) async => throw failure,
    );
    addTearDown(harness.dispose);
    final syncAll = find.widgetWithText(ListTile, 'Refresh all');
    await tester.scrollUntilVisible(
      syncAll,
      500,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(syncAll);
    await tester.pumpAndSettle();

    await tester.tap(syncAll);
    await tester.pumpAndSettle();

    // The shared failure is inspectable through the same command.
    await tester.tap(syncAll);
    await tester.pumpAndSettle();
    expect(
      find.text(AppLocalizationsEn().accountReconnectRequired),
      findsOneWidget,
    );
    expect(find.text('Retry'), findsOneWidget);
    expect(find.textContaining('KnownUnsentRequestException'), findsNothing);
    expect(find.textContaining('InternalOAuthException'), findsNothing);
    expect(find.textContaining('sync-all-secret'), findsNothing);
  });
}

Future<void> verifyAndroidAccountRefreshStatus(
  WidgetTester tester, {
  bool useDeviceViewport = false,
}) async {
  final harness = await _pumpAndroidSettings(
    tester,
    openAccount: false,
    useDeviceViewport: useDeviceViewport,
  );
  addTearDown(harness.dispose);
  final l10n = AppLocalizationsEn();
  const id = 'google:g';
  final activity = harness.container.read(accountSyncActivityProvider);
  final request = (
    scope: accountSyncScope(id),
    origin: SyncTrigger.manual,
    strategy: SyncStrategy.ordinary,
  );
  Future<void> record(SyncOutcome outcome) async {
    await activity.request(request, (start) => start(() async => outcome));
    await tester.pumpAndSettle();
  }

  final entry = find.byKey(const ValueKey('account-entry-google:g'));
  await tester.scrollUntilVisible(
    entry,
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
  expect(find.textContaining(l10n.syncNotYetRefreshed), findsOneWidget);
  final database = harness.database;
  await database
      .into(database.domainSyncSchedules)
      .insert(
        DomainSyncSchedulesCompanion.insert(
          accountId: id,
          domain: accountRefreshHistoryKey,
          lastSuccessfulPullUtc: const Value('2026-06-01T12:00:00.000Z'),
        ),
      );
  await tester.pumpAndSettle();
  final verified = find.textContaining('Last refreshed');
  expect(verified, findsOneWidget);
  final verifiedLabel = tester.widget<Text>(verified).data!;
  final verifiedText = verifiedLabel.substring(
    verifiedLabel.indexOf('Last refreshed'),
  );

  await database
      .into(database.pendingOps)
      .insert(
        PendingOpsCompanion.insert(
          id: 'queued-task',
          accountId: id,
          entityType: 'task',
          operation: 'update',
          requestJson: '{}',
          createdAtUtc: '2026-06-02T12:00:00.000Z',
          updatedAtUtc: '2026-06-02T12:00:00.000Z',
        ),
      );
  final calendar = (
    kind: SyncScopeKind.calendar,
    accountId: id,
    resourceId: null,
  );
  final tasks = (kind: SyncScopeKind.tasks, accountId: id, resourceId: null);
  await record(
    SyncOutcome(
      request,
      SyncDisposition.partial,
      children: [
        SyncOutcome((
          scope: calendar,
          origin: request.origin,
          strategy: request.strategy,
        ), SyncDisposition.completed),
        SyncOutcome((
          scope: tasks,
          origin: request.origin,
          strategy: request.strategy,
        ), SyncDisposition.deferred),
      ],
    ),
  );
  expect(activity.accountNeedsAttention(id), isTrue);
  expect(activity.accountHasFailure(id), isFalse);
  final partial = find.textContaining(l10n.syncPartiallyCompleted);
  expect(partial, findsOneWidget);
  expect(tester.widget<Text>(partial).data, contains(verifiedText));
  expect(tester.widget<Text>(partial).data, contains(l10n.syncPendingChanges));

  await tester.tap(entry);
  await tester.pumpAndSettle();
  expect(partial, findsOneWidget);
  expect(tester.widget<Text>(partial).data, contains(verifiedText));
  expect(tester.widget<Text>(partial).data, contains(l10n.syncPendingChanges));

  await record(
    SyncOutcome(
      request,
      SyncDisposition.deferred,
      error: DomainCooldownException(
        SyncDomain.tasks,
        DateTime.utc(2026, 6, 2),
      ),
    ),
  );
  expect(activity.accountHasFailure(id), isFalse);
  expect(find.textContaining(l10n.syncDeferred), findsOneWidget);
  expect(find.textContaining(l10n.syncPendingChanges), findsOneWidget);
  expect(verified, findsOneWidget);

  await record(
    SyncOutcome(request, SyncDisposition.failed, error: StateError('broken')),
  );
  expect(activity.accountHasFailure(id), isTrue);
  expect(find.textContaining(l10n.accountSyncProblem), findsOneWidget);
  expect(verified, findsOneWidget);

  final release = Completer<SyncOutcome>();
  final refresh = activity.request(
    request,
    (start) => start(() => release.future),
  );
  await tester.pump();
  expect(find.textContaining(l10n.traySyncing), findsOneWidget);
  await database.delete(database.pendingOps).go();
  release.complete(SyncOutcome(request, SyncDisposition.completed));
  await refresh;
  await tester.pumpAndSettle();
  expect(find.textContaining(l10n.syncPendingChanges), findsNothing);
  expect(find.textContaining(l10n.accountSyncProblem), findsNothing);
  expect(find.byType(SnackBar), findsNothing);
  expect(verified, findsOneWidget);
}

Future<_AndroidSettingsHarness> _pumpAndroidSettings(
  WidgetTester tester, {
  AndroidSettingsCategory category = AndroidSettingsCategory.accounts,
  BusyProvider provider = BusyProvider.google,
  String? authority,
  CalendarCollectionCreator? creator,
  CalendarRepository? calendarRepository,
  List<CalendarSourceEntity> sources = const [],
  List<TaskListEntity> lists = const [],
  TaskCollectionCapabilities? taskCapabilities,
  bool reconnectRequired = false,
  bool workspaceSources = false,
  bool openAccount = true,
  SignedInSyncRunner? signedInSyncRunner,
  Future<void> Function(SyncRequest)? manualSyncRunner,
  AllAccountsSyncRunner? allAccountsSyncRunner,
  bool useDeviceViewport = false,
}) async {
  if (!useDeviceViewport) {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1000, 1800);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
  }
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
      networkAvailabilityProvider.overrideWith(
        (ref) => Stream.value(NetworkAvailability.unknown),
      ),
      networkConnectivityMonitorProvider.overrideWith((ref) {
        final monitor = NetworkConnectivityMonitor.withoutPlatformObservation();
        ref.onDispose(() => unawaited(monitor.dispose()));
        return monitor;
      }),
      if (calendarRepository != null)
        calendarRepositoryProvider.overrideWithValue(calendarRepository),
      if (creator != null)
        calendarCollectionCreationServiceProvider.overrideWithValue(creator),
      buildConfigProvider.overrideWithValue(BuildConfig.forAndroid()),
      databaseProvider.overrideWithValue(database),
      if (workspaceSources) ...[
        sidebarCalendarSourcesProvider.overrideWith(
          (ref, id) => Stream.value(sources),
        ),
        sidebarTaskListsProvider.overrideWith((ref, id) => Stream.value(lists)),
      ],
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
      if (manualSyncRunner != null)
        manualSyncRunnerProvider.overrideWith(
          (ref) => (scope, {strategy = SyncStrategy.ordinary}) {
            final request = (
              scope: scope,
              origin: SyncTrigger.manual,
              strategy: strategy,
            );
            return ref
                .read(accountSyncActivityProvider.notifier)
                .request(
                  request,
                  (start) => start(() async {
                    try {
                      await manualSyncRunner(request);
                      return SyncOutcome(request, SyncDisposition.completed);
                    } on Object catch (error) {
                      return SyncOutcome(
                        request,
                        SyncDisposition.failed,
                        error: error,
                      );
                    }
                  }),
                );
          },
        ),
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
      child: localizedTestApp(
        child: workspaceSources
            ? const AndroidScheduleScreen()
            : AndroidSettingsScreen(category: category),
      ),
    ),
  );
  await tester.pumpAndSettle();
  if (openAccount &&
      !workspaceSources &&
      category == AndroidSettingsCategory.accounts) {
    await tester.tap(find.byKey(const ValueKey('account-entry-google:g')));
    await tester.pumpAndSettle();
  }
  return _AndroidSettingsHarness(tester, container, database, accounts);
}

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

final class _PartialRemovalRepository implements CalendarRepository {
  int calls = 0;
  @override
  Future<void> deleteLocalSource(String id) async {
    calls++;
    throw const DavException(
      kind: DavErrorKind.conflict,
      code: 'DavCollectionRemovalPartial',
      safeMessage: 'fixture',
    );
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

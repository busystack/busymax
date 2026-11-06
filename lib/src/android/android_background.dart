import '../features/notifications/notification_schedule_service.dart';
import '../features/notifications/notification_reconciler.dart';
import '../features/notifications/operational_notification_coordinator.dart';
import '../features/sync/domain_sync_schedule.dart';
import '../core/auth/registration_staging.dart';

import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'dart:isolate';
import 'dart:ui';

import 'package:busymax_android_platform/busymax_android_platform.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:workmanager/workmanager.dart';

import '../app/app_bootstrap.dart';
import '../config/build_config.dart';
import '../core/secrets/secret_store.dart';
import '../db/app_database.dart';
import 'android_account_gate.dart';
import 'android_notification_gate.dart';
import 'android_runtime_resources.dart';
import 'android_authorization.dart';
import 'android_notifications.dart';
import 'android_settings_store.dart';
import 'android_time_zone.dart';

void _startupTrace(String stage) {
  if (!const bool.fromEnvironment('BUSYMAX_SQLITE_TRACE')) return;
  try {
    // ignore: avoid_print
    print(
      'BUSYMAX_RUNTIME ${jsonEncode({'pid': pid, 'isolate': developer.Service.getIsolateId(Isolate.current), 'stage': stage, 'utcMicros': DateTime.now().toUtc().microsecondsSinceEpoch})}',
    );
  } catch (_) {
    // Diagnostic output must not affect initialization or cleanup.
  }
}

const busyMaxPeriodicSyncUniqueName = 'busymax.periodic-sync.v1';
const busyMaxPeriodicSyncTaskName = 'busymax.sync-and-reconcile';
const busyMaxImmediateSyncUniqueName = 'busymax.immediate-sync.v1';
const busyMaxNotificationRefillUniqueName = 'busymax.notification-refill.v1';
const busyMaxNotificationRefillTaskName = 'busymax.reconcile-notifications';

@pragma('vm:entry-point')
void busyMaxWorkmanagerDispatcher() {
  Workmanager().executeTask(
    (taskName, inputData) async {
      if (taskName != busyMaxPeriodicSyncTaskName &&
          taskName != busyMaxNotificationRefillTaskName) {
        return true;
      }
      WidgetsFlutterBinding.ensureInitialized();
      DartPluginRegistrant.ensureInitialized();
      _startupTrace('worker-entry:$taskName');
      final runtime = await AndroidHeadlessRuntime.create();
      _startupTrace('worker-created:$taskName');
      var succeeded = true;
      Object? failure;
      try {
        if (taskName == busyMaxPeriodicSyncTaskName) {
          try {
            await withSyncTrigger(
              SyncTrigger.background,
              () => runtime.container.read(allAccountsSyncRunnerProvider)(),
            );
          } on Object {
            // Provider-specific failures are persisted by the shared engines.
            succeeded = false;
          }
        }
        // Local reminders must still refill while offline and after a failed
        // provider synchronization.
        try {
          await runtime.notifications.reconcile();
          await BusyMaxAndroidPlatform.instance.notifyDataChanged();
        } on Object {
          succeeded = false;
        }
        return succeeded;
      } catch (error) {
        failure = error;
        rethrow;
      } finally {
        await runtime.dispose(preserveFailure: failure != null);
      }
    },
    onTaskStopped: (taskName, stopReason) async {
      // Dart finally blocks are not guaranteed when Android destroys the
      // worker engine. Release engine-owned native semaphores explicitly.
      await BusyMaxAndroidPlatform.instance.releaseOwnedAccountGates();
    },
  );
}

Future<void> configureBusyMaxWorkmanager() async {
  final workmanager = Workmanager();
  await workmanager.initialize(busyMaxWorkmanagerDispatcher);
  await workmanager.registerPeriodicTask(
    busyMaxPeriodicSyncUniqueName,
    busyMaxPeriodicSyncTaskName,
    frequency: const Duration(minutes: 15),
    flexInterval: const Duration(minutes: 5),
    constraints: Constraints(
      networkType: NetworkType.connected,
      requiresBatteryNotLow: true,
      requiresStorageNotLow: true,
    ),
    existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
    backoffPolicy: BackoffPolicy.exponential,
    backoffPolicyDelay: const Duration(minutes: 10),
    tag: 'busymax-sync',
  );
  await workmanager.registerPeriodicTask(
    busyMaxNotificationRefillUniqueName,
    busyMaxNotificationRefillTaskName,
    frequency: const Duration(minutes: 15),
    flexInterval: const Duration(minutes: 5),
    constraints: Constraints(
      requiresBatteryNotLow: true,
      requiresStorageNotLow: true,
    ),
    existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
    backoffPolicy: BackoffPolicy.exponential,
    backoffPolicyDelay: const Duration(minutes: 10),
    tag: 'busymax-notification-refill',
  );
}

Future<void> enqueueImmediateBusyMaxSync() => Workmanager().registerOneOffTask(
  busyMaxImmediateSyncUniqueName,
  busyMaxPeriodicSyncTaskName,
  constraints: Constraints(networkType: NetworkType.connected),
  existingWorkPolicy: ExistingWorkPolicy.replace,
  backoffPolicy: BackoffPolicy.exponential,
  backoffPolicyDelay: const Duration(minutes: 10),
  tag: 'busymax-sync',
);

final class AndroidHeadlessRuntime {
  AndroidHeadlessRuntime._({
    required this.container,
    required this.database,
    required this.notifications,
    required AndroidRuntimeResources resources,
  }) : _resources = resources;

  static Future<AndroidHeadlessRuntime> create({
    // Native acceptance needs root-scoped transport overrides: a nested scope
    // cannot safely replace dependencies of existing database-backed providers.
    List<Override> Function(AppDatabase database)? overridesForTesting,
    AppDatabase Function()? databaseForTesting,
    http.Client Function()? httpClientForTesting,
    AndroidNotificationBackend? notificationBackendForTesting,
    LocalSettingsStore? settingsForTesting,
    Future<void> Function(ProviderContainer)? afterObservationForTesting,
  }) async {
    final platform = BusyMaxAndroidPlatform.instance;
    const storage = FlutterSecureStorage(
      aOptions: AndroidOptions(resetOnError: false),
    );
    final settingsStore = AndroidSettingsStore(
      platform: platform,
      store: settingsForTesting,
    );
    _startupTrace('settings');
    final settings = AppSettings.fromJson(await settingsStore.load());
    final timeZoneId = await platform.currentTimeZoneId();
    final uses24Hour = await platform.uses24HourFormat();
    final resources = AndroidRuntimeResources();
    try {
      final notificationGate = AndroidNotificationGate(platform);
      final database = resources.own(
        databaseForTesting?.call() ??
            AppDatabase.open(notificationSynchronization: notificationGate.run),
        (database) => database.close(),
      );
      final client = resources.own(
        httpClientForTesting?.call() ?? http.Client(),
        (client) => client.close(),
      );
      final registrations = resources.own(
        RegistrationStaging(BuildConfig.forAndroid()),
        (registrations) => registrations.dispose(),
      );
      final broker = AndroidAuthorizationBroker(
        platform: platform,
        httpClient: client,
        secretStore: SecureSecretStore(storage),
        config: BuildConfig.forAndroid(),
        database: database,
        registrations: registrations,
      );
      _startupTrace('recovery');
      await broker.persistence!.recover();
      _startupTrace('recovered');
      late ProviderContainer container;
      final notifications = resources.own(
        AndroidNotificationService(
          database: database,
          settings: () => container.read(appSettingsControllerProvider),
          policyStore: settingsStore,
          platform: platform,
          backend: notificationBackendForTesting,
          gate: notificationGate,
        ),
        (notifications) => notifications.dispose(),
      );
      _startupTrace('native-initialize');
      await notifications.initialize(timeZoneId: timeZoneId);
      _startupTrace('native-initialized');
      container = resources.own(
        ProviderContainer(
          overrides: [
            buildConfigProvider.overrideWithValue(BuildConfig.forAndroid()),
            databaseProvider.overrideWithValue(database),
            secureStorageProvider.overrideWithValue(storage),
            initialAppSettingsProvider.overrideWithValue(settings),
            localSettingsStoreProvider.overrideWithValue(settingsStore),
            localTimeZoneSourceProvider.overrideWithValue(
              AndroidLocalTimeZoneSource(platform),
            ),
            androidLocalTimeZoneStateProvider.overrideWith((ref) => timeZoneId),
            androidSystemUses24HourProvider.overrideWith((ref) => uses24Hour),
            applicationOAuthGatewayProvider.overrideWithValue(broker),
            applicationMicrosoftOAuthServiceProvider.overrideWithValue(broker),
            accountTokenBrokerProvider.overrideWithValue(broker),
            authorizationPersistenceProvider.overrideWithValue(
              broker.persistence!,
            ),
            registrationStagingProvider.overrideWithValue(registrations),
            crossEngineAccountGateProvider.overrideWithValue(
              AndroidCrossEngineAccountGate(platform),
            ),
            notificationReconcilerProvider.overrideWithValue(
              CallbackNotificationReconciler(() async {
                await notifications.reconcile();
                await container
                    .read(operationalNotificationCoordinatorProvider)
                    .reconcile();
              }),
            ),
            androidNotificationServiceProvider.overrideWithValue(notifications),
            operationalNotificationTransportProvider.overrideWithValue(
              OperationalNotificationTransport(
                deliver: notifications.deliverOperationalIssue,
                cancel: notifications.cancelOperationalIssue,
                synchronize: notifications.synchronize,
                readSettings: notifications.currentSettings,
              ),
            ),
            ...?overridesForTesting?.call(database),
          ],
        ),
        (container) => container.dispose(),
      );
      // First observe native posts from the previous process. Rebuilding an
      // unsent database row before that observation could expire an alarm Android
      // already delivered while BusyMax was stopped, invalidating its actions.
      _startupTrace('notification-gate-wait');
      await notifications.synchronize(() async {
        _startupTrace('native-observation');
        await notifications.reconcile();
        _startupTrace('native-observed');
        await afterObservationForTesting?.call(container);
        final schedules = NotificationScheduleService(
          database: database,
          preserveLifecycle: true,
        );
        _startupTrace('schedule-rebuild');
        for (final account in await database.select(database.accounts).get()) {
          await schedules.rebuildUpcomingNotifications(account.id);
        }
      });
      _startupTrace('schedule-rebuilt');
      container.read(operationalNotificationCoordinatorProvider).start();
      return AndroidHeadlessRuntime._(
        container: container,
        database: database,
        notifications: notifications,
        resources: resources,
      );
    } catch (error) {
      _startupTrace('failed:${error.runtimeType}');
      await resources.close(preserveFailure: true);
      rethrow;
    }
  }

  final ProviderContainer container;
  final AppDatabase database;
  final AndroidNotificationService notifications;
  final AndroidRuntimeResources _resources;

  Future<void> dispose({bool preserveFailure = false}) =>
      _resources.close(preserveFailure: preserveFailure);
}

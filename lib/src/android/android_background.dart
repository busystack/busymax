import 'dart:async';
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
import '../l10n/app_locale.dart';
import '../../l10n/generated/app_localizations.dart';
import 'android_account_gate.dart';
import 'android_authorization.dart';
import 'android_notifications.dart';
import 'android_time_zone.dart';

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
      final runtime = await AndroidHeadlessRuntime.create();
      var succeeded = true;
      try {
        if (taskName == busyMaxPeriodicSyncTaskName) {
          try {
            await runtime.container.read(allAccountsSyncRunnerProvider)();
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
      } finally {
        await runtime.dispose();
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
    required http.Client httpClient,
  }) : _httpClient = httpClient;

  static Future<AndroidHeadlessRuntime> create() async {
    final platform = BusyMaxAndroidPlatform.instance;
    const storage = FlutterSecureStorage(
      aOptions: AndroidOptions(resetOnError: true),
    );
    final settings = await loadInitialAppSettings(
      const JsonFileLocalSettingsStore(),
    );
    final timeZoneId = await platform.currentTimeZoneId();
    final uses24Hour = await platform.uses24HourFormat();
    final database = AppDatabase.open();
    final client = http.Client();
    final broker = AndroidAuthorizationBroker(
      platform: platform,
      httpClient: client,
      secretStore: SecureSecretStore(storage),
      config: BuildConfig.forAndroid(),
    );
    late ProviderContainer container;
    final notifications = AndroidNotificationService(
      database: database,
      settings: () => container.read(appSettingsControllerProvider),
      platform: platform,
      strings: () {
        final current = container.read(appSettingsControllerProvider);
        final locale =
            current.locale ??
            resolveBusyMaxLocales(
              PlatformDispatcher.instance.locales,
              busyMaxSupportedLocales,
            );
        final l10n = lookupAppLocalizations(locale);
        return AndroidNotificationStrings(
          channelName: l10n.reminderGroup,
          channelDescription: '${l10n.eventReminders} · ${l10n.taskReminders}',
          statusChannelName: l10n.sync,
          statusChannelDescription: l10n.syncConflicts,
          privateTitle: 'BusyMax',
          open: l10n.notificationOpenAction,
          snooze: l10n.notificationSnoozeAction,
          dismiss: l10n.notificationDismissAction,
          syncFailureTitle: l10n.syncFailureNotificationTitle,
          syncFailureBody: l10n.davTemporarilyUnavailable,
          conflictTitle: l10n.conflictNotificationTitle,
          dueTodayTitle: l10n.dueTodayNotificationTitle,
          dueTodayBody: l10n.dueTodayNotificationBody,
        );
      },
    );
    await notifications.initialize(timeZoneId: timeZoneId);
    container = ProviderContainer(
      overrides: [
        buildConfigProvider.overrideWithValue(BuildConfig.forAndroid()),
        databaseProvider.overrideWithValue(database),
        secureStorageProvider.overrideWithValue(storage),
        initialAppSettingsProvider.overrideWithValue(settings),
        localTimeZoneSourceProvider.overrideWithValue(
          AndroidLocalTimeZoneSource(platform),
        ),
        androidLocalTimeZoneStateProvider.overrideWith((ref) => timeZoneId),
        androidSystemUses24HourProvider.overrideWith((ref) => uses24Hour),
        applicationOAuthGatewayProvider.overrideWithValue(broker),
        applicationMicrosoftOAuthServiceProvider.overrideWithValue(broker),
        accountTokenBrokerProvider.overrideWithValue(broker),
        crossEngineAccountGateProvider.overrideWithValue(
          AndroidCrossEngineAccountGate(platform),
        ),
        notificationReconcilerProvider.overrideWithValue(notifications),
        androidNotificationServiceProvider.overrideWithValue(notifications),
        operationalNotificationReporterProvider.overrideWithValue(
          notifications,
        ),
      ],
    );
    return AndroidHeadlessRuntime._(
      container: container,
      database: database,
      notifications: notifications,
      httpClient: client,
    );
  }

  final ProviderContainer container;
  final AppDatabase database;
  final AndroidNotificationService notifications;
  final http.Client _httpClient;

  Future<void> dispose() async {
    container.dispose();
    _httpClient.close();
    await database.close();
  }
}

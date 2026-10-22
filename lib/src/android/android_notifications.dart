import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../l10n/generated/app_localizations.dart';
import '../l10n/locale_resolution.dart';
import '../core/http/request_dispatch_exception.dart';
import '../features/sync/sync_failure_notification_policy.dart';
import '../features/notifications/reminder_delivery_policy.dart';
import '../features/notifications/reminder_presentation.dart';
import '../features/notifications/desktop_notification_service.dart'
    show ReminderDeliveryResult, ReminderDeliveryStatus;
import '../features/notifications/notification_schedule_service.dart';
import '../features/notifications/daily_summary_policy.dart';

import 'package:busymax_android_platform/busymax_android_platform.dart';
import 'package:crypto/crypto.dart';
import 'package:uuid/uuid.dart';
import 'package:drift/drift.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../app/app_settings.dart';
import '../db/app_database.dart';
import '../features/accounts/data/accounts_repository.dart';
import '../features/notifications/notification_reconciler.dart';
import 'android_notification_gate.dart';
import 'android_settings_store.dart';

const androidReminderChannelId = 'busymax_reminders_v1';
const androidSummaryChannelId = 'busymax_summaries_v1';
const androidStatusChannelId = 'busymax_status_v1';
const androidNotificationActionOpen = 'busymax.open';
const androidNotificationActionSnooze = 'busymax.snooze';
const androidNotificationActionDismiss = 'busymax.dismiss';
const _maximumScheduledAlarms = 256;
const _schedulingHorizon = Duration(days: 90);

final class AndroidNotificationReadiness {
  const AndroidNotificationReadiness({
    this.initialized = false,
    this.notificationsAllowed,
    this.remindersAllowed,
    this.summariesAllowed,
    this.statusAllowed,
    this.exactAlarms = false,
    this.failed = false,
  });
  final bool initialized;
  final bool? notificationsAllowed;
  final bool? remindersAllowed;
  final bool? summariesAllowed;
  final bool? statusAllowed;
  final bool exactAlarms;
  final bool failed;
  bool get remindersReady =>
      initialized &&
      !failed &&
      notificationsAllowed == true &&
      remindersAllowed == true;
}

final androidNotificationServiceProvider = Provider<AndroidNotificationService>(
  (ref) => throw UnsupportedError(
    'AndroidNotificationService must be supplied by the Android runtime.',
  ),
);

/// Testable boundary between reminder policy/database reconciliation and the
/// process-global notifications plugin.
abstract interface class AndroidNotificationBackend {
  Future<bool?> initialize({
    required InitializationSettings settings,
    DidReceiveNotificationResponseCallback? onDidReceiveNotificationResponse,
    DidReceiveBackgroundNotificationResponseCallback?
    onDidReceiveBackgroundNotificationResponse,
  });

  Future<NotificationAppLaunchDetails?> getNotificationAppLaunchDetails();
  Future<List<PendingNotificationRequest>> pendingNotificationRequests();
  Future<List<ActiveNotification>> getActiveNotifications();
  Future<void> cancel({required int id});
  Future<void> show({
    required int id,
    String? title,
    String? body,
    required NotificationDetails notificationDetails,
    String? payload,
  });
  Future<void> zonedSchedule({
    required int id,
    String? title,
    String? body,
    required tz.TZDateTime scheduledDate,
    required NotificationDetails notificationDetails,
    required AndroidScheduleMode androidScheduleMode,
    String? payload,
  });
  Future<bool> requestNotificationPermission();
  Future<bool> requestExactAlarmPermission();
  Future<bool> canScheduleExactly();
}

final class FlutterAndroidNotificationBackend
    implements AndroidNotificationBackend {
  FlutterAndroidNotificationBackend([FlutterLocalNotificationsPlugin? plugin])
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;

  AndroidFlutterLocalNotificationsPlugin? get _android => _plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  @override
  Future<bool?> initialize({
    required InitializationSettings settings,
    DidReceiveNotificationResponseCallback? onDidReceiveNotificationResponse,
    DidReceiveBackgroundNotificationResponseCallback?
    onDidReceiveBackgroundNotificationResponse,
  }) => _plugin.initialize(
    settings: settings,
    onDidReceiveNotificationResponse: onDidReceiveNotificationResponse,
    onDidReceiveBackgroundNotificationResponse:
        onDidReceiveBackgroundNotificationResponse,
  );

  @override
  Future<NotificationAppLaunchDetails?> getNotificationAppLaunchDetails() =>
      _plugin.getNotificationAppLaunchDetails();

  @override
  Future<List<PendingNotificationRequest>> pendingNotificationRequests() =>
      _plugin.pendingNotificationRequests();

  @override
  Future<List<ActiveNotification>> getActiveNotifications() =>
      _plugin.getActiveNotifications();

  @override
  Future<void> cancel({required int id}) => _plugin.cancel(id: id);

  @override
  Future<void> show({
    required int id,
    String? title,
    String? body,
    required NotificationDetails notificationDetails,
    String? payload,
  }) => _plugin.show(
    id: id,
    title: title,
    body: body,
    notificationDetails: notificationDetails,
    payload: payload,
  );

  @override
  Future<void> zonedSchedule({
    required int id,
    String? title,
    String? body,
    required tz.TZDateTime scheduledDate,
    required NotificationDetails notificationDetails,
    required AndroidScheduleMode androidScheduleMode,
    String? payload,
  }) async {
    try {
      await _plugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: scheduledDate,
        notificationDetails: notificationDetails,
        androidScheduleMode: androidScheduleMode,
        payload: payload,
      );
    } on ArgumentError catch (error) {
      // The pinned plugin validates the instant before invoking Android. A
      // database/native round trip can cross it. Source relevance is checked
      // by the caller around this operation; deliver that eligible occurrence
      // immediately instead of losing it to the plugin's future-only guard.
      if (error.name != 'scheduledDate' ||
          scheduledDate.isAfter(DateTime.now())) {
        rethrow;
      }
      await show(
        id: id,
        title: title,
        body: body,
        notificationDetails: notificationDetails,
        payload: payload,
      );
    }
  }

  @override
  Future<bool> requestNotificationPermission() async =>
      await _android?.requestNotificationsPermission() ?? true;

  @override
  Future<bool> requestExactAlarmPermission() async =>
      await _android?.requestExactAlarmsPermission() ?? false;

  @override
  Future<bool> canScheduleExactly() async =>
      await _android?.canScheduleExactNotifications() ?? false;
}

@pragma('vm:entry-point')
Future<void> busyMaxNotificationBackgroundResponse(
  NotificationResponse response,
) async {
  final payload = _AndroidReminderPayload.tryParse(response.payload);
  if (payload == null ||
      !const {'event', 'task'}.contains(payload.sourceType) ||
      !const {
        androidNotificationActionSnooze,
        androidNotificationActionDismiss,
      }.contains(response.actionId)) {
    return;
  }
  final platform = BusyMaxAndroidPlatform.instance;
  final lease = await platform.acquireAccountGate('__notifications__');
  final database = AppDatabase.open();
  var changed = false;
  try {
    changed = await applyAndroidReminderAction(
      database: database,
      activation: _publicActivation(payload)!,
      actionId: response.actionId!,
      nowUtc: DateTime.now().toUtc(),
    );
  } finally {
    await database.close();
    await platform.releaseAccountGate(lease);
  }
  if (changed) {
    final store = AndroidSettingsStore(platform: platform);
    final settings = AppSettings.fromJson(await store.load());
    final reconcileDatabase = AppDatabase.open();
    final service = AndroidNotificationService(
      database: reconcileDatabase,
      settings: () => settings,
      policyStore: store,
      platform: platform,
    );
    try {
      await service.initialize(timeZoneId: await platform.currentTimeZoneId());
      await service.reconcile();
      await platform.notifyDataChanged();
    } finally {
      await reconcileDatabase.close();
    }
  }
}

/// The same conditional mutation is used after process termination and by
/// foreground actions. The persisted generation is authoritative after a local
/// source ID is replaced; payload source IDs never select a different item.
Future<bool> applyAndroidReminderAction({
  required AppDatabase database,
  required AndroidReminderActivation activation,
  required String actionId,
  required DateTime nowUtc,
}) => database.transaction(() async {
  if (!const {
    androidNotificationActionSnooze,
    androidNotificationActionDismiss,
  }.contains(actionId)) {
    return false;
  }
  final row =
      await (database.select(database.notificationSchedule)..where(
            (table) =>
                table.id.equals(activation.scheduleId) &
                table.generation.equals(activation.generation) &
                table.accountId.equals(activation.accountId) &
                table.sourceType.equals(activation.sourceType) &
                table.dismissedAtUtc.isNull() &
                table.expiredAtUtc.isNull(),
          ))
          .getSingleOrNull();
  if (row == null ||
      !await NotificationScheduleService(
        database: database,
        nowUtc: () => nowUtc,
      ).validateAndReconcileReminder(row)) {
    return false;
  }
  final now = nowUtc.millisecondsSinceEpoch;
  final update = actionId == androidNotificationActionSnooze
      ? NotificationScheduleCompanion(
          generation: Value(const Uuid().v4()),
          snoozedUntilUtc: Value(
            now + defaultReminderSnoozeDuration.inMilliseconds,
          ),
          sentAtUtc: const Value(null),
          deferredUntilUtc: const Value(null),
          updatedAtLocal: Value(now),
        )
      : NotificationScheduleCompanion(
          dismissedAtUtc: Value(now),
          snoozedUntilUtc: const Value(null),
          deferredUntilUtc: const Value(null),
          updatedAtLocal: Value(now),
        );
  return await (database.update(database.notificationSchedule)..where(
            (table) =>
                table.id.equals(row.id) &
                table.generation.equals(row.generation) &
                table.dismissedAtUtc.isNull() &
                table.expiredAtUtc.isNull(),
          ))
          .write(update) !=
      0;
});

final class AndroidReminderActivation {
  const AndroidReminderActivation({
    required this.scheduleId,
    required this.generation,
    required this.sourceType,
    required this.accountId,
    required this.itemId,
  });

  final String scheduleId;
  final String generation;
  final String sourceType;
  final String accountId;
  final String itemId;
}

final class AndroidNotificationStrings {
  const AndroidNotificationStrings({
    this.channelName = 'Reminders',
    this.channelDescription = 'Calendar event and task reminders',
    this.statusChannelName = 'Synchronization',
    this.statusChannelDescription = 'Synchronization status and conflicts',
    this.privateTitle = 'BusyMax reminder',
    this.open = 'Open',
    this.snooze = 'Snooze 10 minutes',
    this.dismiss = 'Dismiss',
    this.reconnectRequired =
        'Reconnect this account to resume synchronization.',
    this.permissionChanged =
        'Server permissions changed. Pending edits are paused.',
    this.unsupportedProvider = 'This server is not supported.',
    this.temporarilyUnavailable = 'This account is temporarily unavailable.',
    this.syncFailureTitle = 'BusyMax sync issue',
    this.syncFailureBody = 'Open BusyMax to review the account status.',
    this.conflictTitle = 'BusyMax sync conflict',
    this.dueTodayTitle = 'Tasks due today',
    this.dueTodayBody = _defaultDueTodayBody,
  });

  factory AndroidNotificationStrings.forSettings(AppSettings settings) {
    final locale =
        settings.locale ??
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
      privateTitle: l10n.reminders,
      open: l10n.notificationOpenAction,
      snooze: l10n.notificationSnoozeAction,
      dismiss: l10n.notificationDismissAction,
      syncFailureTitle: l10n.syncFailureNotificationTitle,
      syncFailureBody: l10n.davTemporarilyUnavailable,
      reconnectRequired: l10n.davReauthenticationRequired,
      permissionChanged: l10n.davPermissionChanged,
      unsupportedProvider: l10n.davUnsupportedServer,
      temporarilyUnavailable: l10n.davTemporarilyUnavailable,
      conflictTitle: l10n.conflictNotificationTitle,
      dueTodayTitle:
          '${l10n.dueTodayNotificationTitle} · ${l10n.dailySummaryScope}',
      dueTodayBody: l10n.dueTodayNotificationBody,
    );
  }

  final String reconnectRequired;
  final String permissionChanged;
  final String unsupportedProvider;
  final String temporarilyUnavailable;
  final String channelName;
  final String channelDescription;
  final String statusChannelName;
  final String statusChannelDescription;
  final String privateTitle;
  final String open;
  final String snooze;
  final String dismiss;
  final String syncFailureTitle;
  final String syncFailureBody;
  final String conflictTitle;
  final String dueTodayTitle;
  final String Function(int count) dueTodayBody;
}

final class AndroidNotificationService
    implements NotificationReconciler, OperationalNotificationReporter {
  AndroidNotificationService({
    required AppDatabase database,
    required AppSettings Function() settings,
    LocalSettingsStore? policyStore,
    BusyMaxAndroidPlatform? platform,
    AndroidNotificationStrings Function()? strings,
    FlutterLocalNotificationsPlugin? plugin,
    AndroidNotificationBackend? backend,
    Future<bool> Function()? exactAlarmCapability,
    DateTime Function()? now,
  }) : _database = database,
       _settingsReader = settings,
       _policyStore = policyStore,
       _platform = platform ?? BusyMaxAndroidPlatform.instance,
       _stringsOverride = strings,
       _notifications = backend ?? FlutterAndroidNotificationBackend(plugin),
       _exactAlarmCapability = exactAlarmCapability,
       _now = now ?? DateTime.now;

  final DateTime Function() _now;
  final AppDatabase _database;
  final AppSettings Function() _settingsReader;
  final LocalSettingsStore? _policyStore;
  AppSettings? _currentPolicy;
  final BusyMaxAndroidPlatform _platform;
  final AndroidNotificationStrings Function()? _stringsOverride;
  final AndroidNotificationBackend _notifications;
  final Future<bool> Function()? _exactAlarmCapability;
  AppSettings _settings() => _currentPolicy ?? _settingsReader();
  AndroidNotificationStrings _strings() =>
      _stringsOverride?.call() ??
      AndroidNotificationStrings.forSettings(_settings());

  /// A container's snapshot is not authoritative in a different Flutter engine.
  /// Read failures abort delivery; they never fall back to Normal details.
  Future<AppSettings> currentSettings() async =>
      _currentPolicy = _policyStore == null
      ? _settingsReader()
      : AppSettings.fromJson(await _policyStore.load());

  Future<void> synchronize(Future<void> Function() operation) =>
      AndroidNotificationGate(_platform).run(operation);

  Future<bool> _policyStillCurrent(
    AppSettings snapshot, {
    int? nativeId,
  }) async {
    try {
      return _policyFingerprint(await currentSettings()) ==
          _policyFingerprint(snapshot);
    } on Object {
      if (nativeId != null) await _notifications.cancel(id: nativeId);
      rethrow;
    }
  }

  String _policyFingerprint(AppSettings settings) => jsonEncode([
    settings.notifyEventReminders,
    settings.notifyTaskReminders,
    settings.notifyDueToday,
    settings.notifySyncFailures,
    settings.notifyConflicts,
    settings.notificationDetailLevel.name,
    settings.localeTag,
    settings.timeFormatPreference.name,
    settings.dueTodayNotificationTime,
    settings.quietHoursEnabled,
    settings.quietHoursStart,
    settings.quietHoursEnd,
  ]);

  final StreamController<AndroidReminderActivation> _activations =
      StreamController<AndroidReminderActivation>.broadcast(sync: true);
  AndroidReminderActivation? _initialActivation;
  bool _initialized = false;
  bool _reconciling = false;
  bool _reconcileAgain = false;
  String _precisionDiagnostic = 'Alarm precision has not been checked.';

  String get precisionDiagnostic => _precisionDiagnostic;
  final readiness = ValueNotifier<AndroidNotificationReadiness>(
    const AndroidNotificationReadiness(),
  );

  Future<void> refreshReadiness() async {
    try {
      final capabilities = await _platform.notificationCapabilities();
      readiness.value = AndroidNotificationReadiness(
        initialized: _initialized,
        notificationsAllowed: capabilities['notifications'] as bool?,
        remindersAllowed: capabilities['reminders'] as bool?,
        summariesAllowed: capabilities['summaries'] as bool?,
        statusAllowed: capabilities['status'] as bool?,
        exactAlarms: await canScheduleExactly(),
      );
    } on Object {
      readiness.value = AndroidNotificationReadiness(
        initialized: _initialized,
        failed: true,
      );
    }
  }

  Stream<AndroidReminderActivation> get activations => _activations.stream;

  AndroidReminderActivation? takeInitialActivation() {
    final value = _initialActivation;
    _initialActivation = null;
    return value;
  }

  Future<void> initialize({required String timeZoneId}) async {
    if (_initialized) {
      updateTimeZone(timeZoneId);
      return;
    }
    tz_data.initializeTimeZones();
    updateTimeZone(timeZoneId);
    final initialized = await _notifications.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('ic_notification'),
      ),
      onDidReceiveNotificationResponse: _foregroundResponse,
      onDidReceiveBackgroundNotificationResponse:
          busyMaxNotificationBackgroundResponse,
    );
    final launch = await _notifications.getNotificationAppLaunchDetails();
    if (launch?.didNotificationLaunchApp ?? false) {
      _initialActivation = _publicActivation(
        _AndroidReminderPayload.tryParse(launch?.notificationResponse?.payload),
      );
    }
    _initialized = initialized == true;
    await refreshReadiness();
  }

  void updateTimeZone(String timeZoneId) {
    try {
      tz.setLocalLocation(tz.getLocation(timeZoneId));
    } on tz.LocationNotFoundException {
      tz.setLocalLocation(tz.UTC);
    }
  }

  Future<bool> requestNotificationPermission() async {
    final granted = await _notifications.requestNotificationPermission();
    await refreshReadiness();
    return granted;
  }

  Future<bool> requestExactAlarmPermission() async {
    return _notifications.requestExactAlarmPermission();
  }

  Future<bool> canScheduleExactly() async {
    final override = _exactAlarmCapability;
    if (override != null) return override();
    return _notifications.canScheduleExactly();
  }

  final Set<String> _submittedIssues = {};

  @override
  Future<void> notifySyncFailure(Object error, {String? accountId}) async {
    final disposition = syncFailureNotificationDisposition(error);
    if (disposition == SyncFailureNotificationDisposition.suppressed) return;
    accountId ??= switch (error) {
      AuthorizationScopedFailure(:final accountId) => accountId,
      AuthorizationScopedOAuthException(:final accountId) => accountId,
      _ => null,
    };
    final key = '$accountId:${disposition.name}';
    if (_submittedIssues.contains(key)) return;
    final result = await deliverOperationalIssue(
      'sync-failure',
      accountId,
      disposition.name,
      1,
    );
    if (result.status == ReminderDeliveryStatus.delivered) {
      _submittedIssues.add(key);
    }
  }

  @override
  Future<void> notifyConflict(String summary) async {
    await deliverOperationalIssue('conflict', null, 'conflict', 1);
  }

  Future<int?> _issueNativeId(String id, {bool allocate = false}) =>
      _database.transaction(() async {
        final issue = await (_database.select(
          _database.notificationIssues,
        )..where((row) => row.id.equals(id))).getSingleOrNull();
        if (issue?.nativeId != null) return issue!.nativeId;
        if (!allocate) return null;
        final used = {
          for (final row
              in await _database.select(_database.notificationIssues).get())
            if (row.nativeId != null) row.nativeId!,
          for (final row
              in await _database
                  .select(_database.androidNotificationMappings)
                  .get())
            row.platformId,
          0x425901,
          0x425902,
          0x425903,
        };
        final nativeId = allocateAndroidNotificationId(id, used);
        if (issue != null) {
          await (_database.update(_database.notificationIssues)
                ..where((row) => row.id.equals(id)))
              .write(NotificationIssuesCompanion(nativeId: Value(nativeId)));
        }
        return nativeId;
      });

  Future<bool> cancelOperationalIssue(String id) =>
      AndroidNotificationGate(_platform).run(() => _cancelOperationalIssue(id));

  Future<bool> _cancelOperationalIssue(String id) async {
    final nativeId = await _issueNativeId(id);
    if (nativeId == null) return true;
    try {
      await _notifications.cancel(id: nativeId);
      return true;
    } on Object {
      return false;
    }
  }

  Future<ReminderDeliveryResult> deliverOperationalIssue(
    String kind,
    String? accountId,
    String revision,
    int count,
  ) => AndroidNotificationGate(_platform)
      .run(() => _deliverOperationalIssue(kind, accountId, revision, count));

  Future<ReminderDeliveryResult> _deliverOperationalIssue(
    String kind,
    String? accountId,
    String revision,
    int count,
  ) async {
    final settings = await currentSettings();
    if (kind == 'conflict'
        ? !settings.notifyConflicts
        : !settings.notifySyncFailures) {
      return const ReminderDeliveryResult.disabled();
    }
    final now = _now().toUtc();
    if (readiness.value.notificationsAllowed == false ||
        readiness.value.statusAllowed == false) {
      return ReminderDeliveryResult.failed(now.add(const Duration(minutes: 1)));
    }
    final quietEnd = applyAndroidQuietHours(
      now.millisecondsSinceEpoch,
      settings,
    );
    if (quietEnd > now.millisecondsSinceEpoch) {
      return ReminderDeliveryResult.deferred(
        DateTime.fromMillisecondsSinceEpoch(quietEnd, isUtc: true),
      );
    }
    final strings = _strings();
    final l10n = lookupAppLocalizations(
      settings.locale ??
          resolveBusyMaxLocales(
            PlatformDispatcher.instance.locales,
            busyMaxSupportedLocales,
          ),
    );
    final message = kind == 'conflict'
        ? l10n.blockedPendingOperations
        : switch (revision.split(':').first) {
            'reconnectRequired' => strings.reconnectRequired,
            'permissionChanged' => strings.permissionChanged,
            'unsupportedProvider' => strings.unsupportedProvider,
            _ => strings.temporarilyUnavailable,
          };
    final stableId = accountId == null ? kind : '$kind|$accountId';
    try {
      final id = await _issueNativeId(stableId, allocate: true);
      if (!await _policyStillCurrent(settings)) {
        return ReminderDeliveryResult.failed(
          _now().toUtc().add(const Duration(minutes: 1)),
        );
      }
      // The pinned Android adapter exposes active IDs, not their Dart payload.
      // A changed revision first retains cleanupPending and withdraws the old
      // ID. Thus an active ID for this unchanged, unsubmitted revision is an
      // observed submission after interrupted persistence, not a new alert.
      final active = await _notifications.getActiveNotifications();
      final issue = await (_database.select(
        _database.notificationIssues,
      )..where((row) => row.id.equals(stableId))).getSingleOrNull();
      if (issue?.revision == revision &&
          !issue!.cleanupPending &&
          active.any((post) => post.id == id)) {
        return const ReminderDeliveryResult.delivered();
      }
      await _showStatus(
        id: id!,
        title: kind == 'conflict'
            ? strings.conflictTitle
            : strings.syncFailureTitle,
        body:
            settings.notificationDetailLevel == NotificationDetailLevel.private
            ? null
            : message,
        payload: _AndroidReminderPayload(
          scheduleId: stableId,
          generation: 'issue',
          sourceType: kind,
          accountId: accountId ?? 'all',
          sourceId: accountId ?? 'all',
        ).encode(),
      );
      if (!await _policyStillCurrent(settings, nativeId: id)) {
        await _notifications.cancel(id: id);
      }
      return const ReminderDeliveryResult.delivered();
    } on Object {
      return ReminderDeliveryResult.failed(now.add(const Duration(minutes: 1)));
    }
  }

  Future<void> _showStatus({
    required int id,
    required String title,
    required String? body,
    required String payload,
  }) async {
    if (!_initialized) throw StateError('Notifications are not initialized.');
    final strings = _strings();
    await _notifications.show(
      id: id,
      title: title,
      body: body,
      payload: payload,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          androidStatusChannelId,
          strings.statusChannelName,
          channelDescription: strings.statusChannelDescription,
          importance: Importance.defaultImportance,
          onlyAlertOnce: true,
          priority: Priority.defaultPriority,
          visibility:
              _settings().notificationDetailLevel ==
                  NotificationDetailLevel.private
              ? NotificationVisibility.private
              : NotificationVisibility.public,
        ),
      ),
    );
  }

  @override
  Future<void> reconcile() async {
    if (!_initialized) return;
    if (_reconciling) {
      _reconcileAgain = true;
      return;
    }
    _reconciling = true;
    try {
      await synchronize(() async {
        do {
          _reconcileAgain = false;
          await _reconcileOnce();
        } while (_reconcileAgain);
      });
    } on Object {
      final status = readiness.value;
      readiness.value = AndroidNotificationReadiness(
        initialized: _initialized,
        notificationsAllowed: status.notificationsAllowed,
        remindersAllowed: status.remindersAllowed,
        summariesAllowed: status.summariesAllowed,
        statusAllowed: status.statusAllowed,
        exactAlarms: status.exactAlarms,
        failed: true,
      );
      rethrow;
    } finally {
      _reconciling = false;
    }
  }

  Future<void> _reconcileOnce() async {
    final now = _now().toUtc();
    final horizon = now.add(_schedulingHorizon).millisecondsSinceEpoch;
    final nowMillis = now.millisecondsSinceEpoch;
    final eligibleAccounts = {
      for (final account in await _database.select(_database.accounts).get())
        if (accountLocalReminderEligibleStates.contains(account.authState))
          account.id,
    };
    final settings = await currentSettings();
    final localized = _strings();
    await _platform.prepareNotificationChannels(
      reminders: localized.channelName,
      summaries: localized.dueTodayTitle,
      status: localized.statusChannelName,
    );
    await refreshReadiness();
    final mappings = await _database
        .select(_database.androidNotificationMappings)
        .get();
    final mappingByScheduleId = {
      for (final mapping in mappings) mapping.scheduleId: mapping,
    };
    final pendingIds = {
      for (final request in await _notifications.pendingNotificationRequests())
        request.id,
    };
    var activeStateKnown = true;
    Set<int> activeIds;
    try {
      activeIds = {
        for (final notification
            in await _notifications.getActiveNotifications())
          if (notification.id case final id?) id,
      };
    } on Object {
      // Losing visibility into posted notifications must not make a routine
      // reconciliation dismiss them. Source/generation invalidation below is
      // still authoritative and will cancel an obsolete registration.
      activeStateKnown = false;
      activeIds = const {};
    }
    final exact = await canScheduleExactly();
    final rows =
        await (_database.select(_database.notificationSchedule)..where(
              (table) =>
                  table.expiredAtUtc.isNull() & table.dismissedAtUtc.isNull(),
            ))
            .get();
    final considered = rows.toList();
    rows.clear();
    for (final candidate in considered) {
      var row = candidate;
      final known = mappingByScheduleId[row.id];
      if (known?.generation == row.generation &&
          (activeIds.contains(known!.platformId) ||
              !activeStateKnown &&
                  !_isPendingReplacement(known.state) &&
                  !pendingIds.contains(known.platformId) &&
                  applyAndroidQuietHours(_effectiveAt(row), settings) <=
                      nowMillis) &&
          row.sentAtUtc == null) {
        await (_database.update(_database.notificationSchedule)..where(
              (table) =>
                  table.id.equals(row.id) &
                  table.generation.equals(row.generation),
            ))
            .write(NotificationScheduleCompanion(sentAtUtc: Value(nowMillis)));
        row = row.copyWith(sentAtUtc: Value(nowMillis));
      }
      // Observe delivery before withdrawing an account's registrations. An
      // authentication change can precede the next foreground reconciliation;
      // recovery must not recreate a post Android already displayed.
      if (!eligibleAccounts.contains(row.accountId) ||
          (row.sourceType == 'event' && !settings.notifyEventReminders) ||
          (row.sourceType == 'task' && !settings.notifyTaskReminders) ||
          !const {'event', 'task'}.contains(row.sourceType)) {
        continue;
      }
      final sources = NotificationScheduleService(
        database: _database,
        nowUtc: () => _now().toUtc(),
      );
      if (!await sources.isReminderSourceEligible(row)) {
        await sources.validateAndReconcileReminder(row);
        final refreshed = await (_database.select(
          _database.notificationSchedule,
        )..where((table) => table.id.equals(row.id))).getSingleOrNull();
        if (refreshed != null &&
            (refreshed.generation != row.generation ||
                refreshed.scheduledAtUtc != row.scheduledAtUtc)) {
          _reconcileAgain = true;
        }
        continue;
      }
      final effectiveAt = applyAndroidQuietHours(_effectiveAt(row), settings);
      if (row.sentAtUtc == null &&
          row.snoozedUntilUtc == null &&
          row.expiresAtUtc != null &&
          (effectiveAt >= row.expiresAtUtc! || reminderHasExpired(row, now))) {
        await (_database.update(
          _database.notificationSchedule,
        )..where((table) => table.id.equals(row.id))).write(
          NotificationScheduleCompanion(expiredAtUtc: Value(nowMillis)),
        );
        continue;
      }
      final mapping = mappingByScheduleId[row.id];
      final mappingMatchesGeneration = mapping?.generation == row.generation;
      final remainsPending =
          mappingMatchesGeneration && pendingIds.contains(mapping!.platformId);
      final remainsDisplayed =
          mappingMatchesGeneration &&
          (activeIds.contains(mapping!.platformId) ||
              (!activeStateKnown &&
                  !_isPendingReplacement(mapping.state) &&
                  !remainsPending &&
                  effectiveAt <= nowMillis));
      if (mappingMatchesGeneration &&
          mapping!.state != 'blocked' &&
          !mapping.state.startsWith('registering:') &&
          !_isPendingReplacement(mapping.state) &&
          effectiveAt <= nowMillis &&
          !remainsPending &&
          !remainsDisplayed &&
          activeStateKnown &&
          readiness.value.notificationsAllowed != false &&
          readiness.value.remindersAllowed != false) {
        await (_database.update(_database.notificationSchedule)..where(
              (table) =>
                  table.id.equals(row.id) &
                  table.generation.equals(row.generation),
            ))
            .write(
              NotificationScheduleCompanion(dismissedAtUtc: Value(nowMillis)),
            );
        continue;
      }
      if (row.sentAtUtc != null && !remainsDisplayed) continue;
      if (shouldKeepAndroidReminder(
        effectiveAt: effectiveAt,
        now: nowMillis,
        horizon: horizon,
        remainsPending: remainsPending,
        remainsDisplayed: remainsDisplayed,
        eligibleForCatchUp: !reminderHasExpired(row, now),
      )) {
        rows.add(row);
      }
    }
    rows.sort(
      (a, b) => applyAndroidQuietHours(
        _effectiveAt(a),
        settings,
      ).compareTo(applyAndroidQuietHours(_effectiveAt(b), settings)),
    );
    final desired = rows.take(_maximumScheduledAlarms).toList();
    final desiredIds = {for (final row in desired) row.id};

    for (final mapping in mappings) {
      if (!desiredIds.contains(mapping.scheduleId)) {
        // Persist the withdrawal decision before awaiting Android. If policy or
        // source eligibility changes again after a failed cancel, this exact
        // post still needs cleanup; re-enabling must not erase that decision.
        if (!mapping.state.startsWith('withdrawing:')) {
          await (_database.update(_database.androidNotificationMappings)..where(
                (row) =>
                    row.scheduleId.equals(mapping.scheduleId) &
                    row.generation.equals(mapping.generation),
              ))
              .write(
                AndroidNotificationMappingsCompanion(
                  state: Value('withdrawing:${mapping.state}'),
                ),
              );
        }
        await _notifications.cancel(id: mapping.platformId);
        await (_database.delete(
          _database.androidNotificationMappings,
        )..where((table) => table.scheduleId.equals(mapping.scheduleId))).go();
      }
    }

    _precisionDiagnostic = exact ? 'Exact reminder alarms are enabled.' : 'Exact alarm access is unavailable; reminders use Android inexact scheduling.';
    if (rows.length > _maximumScheduledAlarms) {
      _precisionDiagnostic =
          '$_precisionDiagnostic ${rows.length - _maximumScheduledAlarms} later reminders are waiting for scheduling capacity.';
    }
    final activeMappings = {
      for (final mapping
          in await _database
              .select(_database.androidNotificationMappings)
              .get())
        mapping.scheduleId: mapping,
    };
    final usedIds = {
      0x425901,
      0x425902,
      0x425903,
      for (final mapping in activeMappings.values) mapping.platformId,
      for (final issue
          in await _database.select(_database.notificationIssues).get())
        if (issue.nativeId != null) issue.nativeId!,
    };
    final strings = _strings();
    for (final row in desired) {
      if (!await NotificationScheduleService(
        database: _database,
        nowUtc: () => _now().toUtc(),
      ).validateAndReconcileReminder(row)) {
        final previous = activeMappings[row.id];
        if (previous != null) {
          await _notifications.cancel(id: previous.platformId);
        }
        _reconcileAgain = true;
        continue;
      }
      final effectiveAt = applyAndroidQuietHours(_effectiveAt(row), settings);
      final presentation = await reminderPresentation(_database, row, settings);
      final title =
          settings.notificationDetailLevel == NotificationDetailLevel.private
          ? strings.privateTitle
          : presentation.title;
      final body =
          settings.notificationDetailLevel == NotificationDetailLevel.private
          ? null
          : presentation.body;
      final registrationState = androidNotificationRegistrationState(
        settings: settings,
        exact: exact,
        title: title,
        body: body,
        actionLabels: [strings.open, strings.snooze, strings.dismiss],
      );
      var mapping = activeMappings[row.id];
      final sameGeneration = mapping?.generation == row.generation;
      final displayed =
          sameGeneration &&
          (activeIds.contains(mapping!.platformId) ||
              (!activeStateKnown &&
                  !_isPendingReplacement(mapping.state) &&
                  !pendingIds.contains(mapping.platformId) &&
                  effectiveAt <= nowMillis));
      final unchangedPending =
          mapping != null &&
          sameGeneration &&
          mapping.scheduledAtUtc == effectiveAt &&
          mapping.state == registrationState &&
          pendingIds.contains(mapping.platformId);
      if (displayed) {
        await (_database.update(_database.notificationSchedule)..where(
              (table) =>
                  table.id.equals(row.id) &
                  table.generation.equals(row.generation),
            ))
            .write(
              NotificationScheduleCompanion(
                sentAtUtc: Value(row.sentAtUtc ?? nowMillis),
              ),
            );
        if ((settings.notificationDetailLevel ==
                    NotificationDetailLevel.private &&
                !mapping.state.startsWith('scheduled:v3:private:')) ||
            mapping.state.startsWith('withdrawing:')) {
          await (_database.update(
            _database.androidNotificationMappings,
          )..where((table) => table.scheduleId.equals(row.id))).write(
            AndroidNotificationMappingsCompanion(
              state: Value('withdrawing:$registrationState'),
            ),
          );
          // Withdrawing is silent and also safe when active-state inspection
          // failed. Keep identity and lifecycle until cancellation succeeds.
          await _notifications.cancel(id: mapping.platformId);
          await (_database.update(
            _database.androidNotificationMappings,
          )..where((table) => table.scheduleId.equals(row.id))).write(
            AndroidNotificationMappingsCompanion(
              state: Value(registrationState),
            ),
          );
        }
        continue;
      }
      if (readiness.value.notificationsAllowed == false ||
          readiness.value.remindersAllowed == false) {
        if (mapping != null) {
          // Native readiness is reported separately. Blocking must not erase
          // the fact that we canceled an unfired alarm for replacement.
          if (!_isPendingReplacement(mapping.state)) {
            await (_database.update(
              _database.androidNotificationMappings,
            )..where((table) => table.scheduleId.equals(row.id))).write(
              const AndroidNotificationMappingsCompanion(
                state: Value('blocked'),
              ),
            );
          }
          await _notifications.cancel(id: mapping.platformId);
        }
        continue;
      }
      if (unchangedPending) continue;
      if (mapping != null) {
        if (await _nativeRegistrationStillPending(mapping.platformId)) {
          await _markPendingReplacement(row, mapping.state);
        }
        await _notifications.cancel(id: mapping.platformId);
      }
      final platformId =
          mapping?.platformId ?? allocateAndroidNotificationId(row.id, usedIds);
      usedIds.add(platformId);
      final payload = _AndroidReminderPayload(
        scheduleId: row.id,
        generation: row.generation,
        sourceType: row.sourceType,
        accountId: row.accountId,
        sourceId: row.sourceId,
      ).encode();
      final registrationNow = _now().toUtc();
      final scheduledAt = effectiveAt <= registrationNow.millisecondsSinceEpoch
          ? registrationNow
                .add(const Duration(seconds: 1))
                .millisecondsSinceEpoch
          : effectiveAt;
      if (!await _policyStillCurrent(settings)) {
        _reconcileAgain = true;
        return;
      }
      await _database
          .into(_database.androidNotificationMappings)
          .insertOnConflictUpdate(
            AndroidNotificationMappingsCompanion.insert(
              scheduleId: row.id,
              generation: row.generation,
              platformId: platformId,
              scheduledAtUtc: effectiveAt,
              state: Value('registering:$registrationState'),
              updatedAtUtc: now.millisecondsSinceEpoch,
            ),
          );
      await _notifications.zonedSchedule(
        id: platformId,
        title: title,
        body: body,
        scheduledDate: tz.TZDateTime.fromMillisecondsSinceEpoch(
          tz.local,
          scheduledAt,
        ),
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            androidReminderChannelId,
            strings.channelName,
            channelDescription: strings.channelDescription,
            importance: Importance.high,
            priority: Priority.high,
            category: AndroidNotificationCategory.reminder,
            visibility:
                settings.notificationDetailLevel ==
                    NotificationDetailLevel.private
                ? NotificationVisibility.private
                : NotificationVisibility.public,
            actions: androidReminderNotificationActions(strings),
            onlyAlertOnce: true,
            silent:
                mapping != null &&
                settings.notificationDetailLevel ==
                    NotificationDetailLevel.private &&
                !mapping.state.contains(':private:') &&
                effectiveAt <= nowMillis,
          ),
        ),
        androidScheduleMode: exact
            ? AndroidScheduleMode.exactAllowWhileIdle
            : AndroidScheduleMode.inexactAllowWhileIdle,
        payload: payload,
      );
      final currentPolicy = await _policyStillCurrent(
        settings,
        nativeId: platformId,
      );
      final current =
          await (_database.select(_database.notificationSchedule)..where(
                (table) =>
                    table.id.equals(row.id) &
                    table.generation.equals(row.generation) &
                    table.dismissedAtUtc.isNull() &
                    table.expiredAtUtc.isNull(),
              ))
              .getSingleOrNull();
      if (current == null ||
          !await NotificationScheduleService(
            database: _database,
            nowUtc: () => _now().toUtc(),
          ).validateAndReconcileReminder(current) ||
          !currentPolicy) {
        final due = effectiveAt <= _now().millisecondsSinceEpoch;
        final pendingRegistration =
            current != null &&
            await _nativeRegistrationStillPending(platformId);
        if (pendingRegistration) {
          await _markPendingReplacement(row, registrationState);
        }
        await _notifications.cancel(id: platformId);
        if (due && current != null && !pendingRegistration) {
          await (_database.update(_database.notificationSchedule)..where(
                (table) =>
                    table.id.equals(row.id) &
                    table.generation.equals(row.generation),
              ))
              .write(
                NotificationScheduleCompanion(
                  sentAtUtc: Value(_now().millisecondsSinceEpoch),
                ),
              );
        }
        _reconcileAgain = true;
      } else {
        await (_database.update(_database.androidNotificationMappings)..where(
              (table) =>
                  table.scheduleId.equals(row.id) &
                  table.generation.equals(row.generation),
            ))
            .write(
              AndroidNotificationMappingsCompanion(
                state: Value(registrationState),
              ),
            );
      }
    }
    await _reconcileDailySummary(
      settings: settings,
      eligibleAccounts: eligibleAccounts,
      exact: exact,
      pendingIds: pendingIds,
      activeIds: activeIds,
      activeStateKnown: activeStateKnown,
    );
  }

  // Withdrawal adds a cleanup obligation around the same known-pending alarm.
  // Its wrapper must not turn our cancellation into delivery/dismissal evidence.
  bool _isPendingReplacement(String state) =>
      state.startsWith('replacing:') ||
      state.startsWith('withdrawing:replacing:');

  Future<void> _markPendingReplacement(
    NotificationScheduleData row,
    String previousState,
  ) async {
    // Persist before cancellation: a retry or another runtime must distinguish
    // our withdrawal of a positively observed pending alarm from a delivered
    // or possibly dismissed post when native history cannot be inspected.
    if (_isPendingReplacement(previousState)) return;
    await (_database.update(_database.androidNotificationMappings)..where(
          (mapping) =>
              mapping.scheduleId.equals(row.id) &
              mapping.generation.equals(row.generation),
        ))
        .write(
          AndroidNotificationMappingsCompanion(
            state: Value('replacing:$previousState'),
          ),
        );
  }

  Future<bool> _nativeRegistrationStillPending(int id) async {
    try {
      final pending = await _notifications.pendingNotificationRequests();
      if (!pending.any((request) => request.id == id)) return false;
      try {
        final active = await _notifications.getActiveNotifications();
        if (active.any((post) => post.id == id)) return false;
      } on Object {
        // A known pending inexact alarm is not evidence of delivery, even if
        // native history is unavailable. Its private replacement stays pending.
      }
      return true;
    } on Object {
      // Without pending-state evidence, keep the existing conservative policy:
      // withdraw the known ID and do not revive a possibly consumed due post.
      return false;
    }
  }

  Future<void> _reconcileDailySummary({
    required AppSettings settings,
    required Set<String> eligibleAccounts,
    required bool exact,
    required Set<int> pendingIds,
    required Set<int> activeIds,
    bool activeStateKnown = true,
  }) async {
    const id = 0x425903;
    final now = tz.TZDateTime.from(_now(), tz.local);
    final localDate = notificationLocalDate(now);
    final records = await _database
        .select(_database.androidDailySummarySchedules)
        .get();
    final current = records
        .where((row) => row.localDate == localDate)
        .firstOrNull;
    for (final old in records.where(
      (row) => row.localDate != localDate && row.state != 'consumed',
    )) {
      await _notifications.cancel(id: old.platformId);
      await (_database.update(
        _database.androidDailySummarySchedules,
      )..where((row) => row.localDate.equals(old.localDate))).write(
        const AndroidDailySummarySchedulesCompanion(state: Value('consumed')),
      );
    }
    final pending = pendingIds.contains(id);
    final displayed = activeIds.contains(id);
    Future<void> consume() async {
      if (current != null) {
        await (_database.update(
          _database.androidDailySummarySchedules,
        )..where((row) => row.localDate.equals(localDate))).write(
          const AndroidDailySummarySchedulesCompanion(
            state: Value('withdrawing'),
          ),
        );
      }
      await _notifications.cancel(id: id);
      if (current != null) {
        await (_database.update(
          _database.androidDailySummarySchedules,
        )..where((row) => row.localDate.equals(localDate))).write(
          const AndroidDailySummarySchedulesCompanion(state: Value('consumed')),
        );
      }
    }

    if (!settings.notifyDueToday || eligibleAccounts.isEmpty) {
      if (current != null) await consume();
      return;
    }
    if (current?.state == 'withdrawing') {
      await consume();
      return;
    }
    if (current?.state == 'consumed') return;
    final count = (await notificationTasksDueOn(_database, now)).length;
    if (count == 0) {
      if (current != null) {
        if (displayed ||
            (!pending &&
                current.scheduledAtUtc <= now.millisecondsSinceEpoch)) {
          await consume();
        } else {
          await _notifications.cancel(id: id);
          await (_database.delete(
            _database.androidDailySummarySchedules,
          )..where((row) => row.localDate.equals(localDate))).go();
        }
      }
      return;
    }
    final strings = _strings();
    final title = strings.dueTodayTitle;
    final body =
        settings.notificationDetailLevel == NotificationDetailLevel.private
        ? null
        : strings.dueTodayBody(count);
    final state =
        '${androidNotificationRegistrationState(settings: settings, exact: exact, title: title, body: body, actionLabels: [strings.open])}:${settings.dueTodayNotificationTime}:${settings.quietHoursEnabled}:${settings.quietHoursStart}:${settings.quietHoursEnd}:${tz.local.name}';
    final generation = 'due-today:$localDate';
    final payload = _AndroidReminderPayload(
      scheduleId: generation,
      generation: generation,
      sourceType: 'summary',
      accountId: 'all',
      sourceId: localDate,
    ).encode();
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        androidSummaryChannelId,
        strings.dueTodayTitle,
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
        visibility:
            settings.notificationDetailLevel == NotificationDetailLevel.private
            ? NotificationVisibility.private
            : NotificationVisibility.public,
        actions: [androidOpenNotificationAction(strings)],
        onlyAlertOnce: true,
        silent: displayed,
        playSound: !displayed,
        enableVibration: !displayed,
      ),
    );
    if (displayed) {
      if (current != null &&
          (current.taskCount != count || current.state != state)) {
        if (!await _policyStillCurrent(settings)) {
          _reconcileAgain = true;
          return;
        }
        await _notifications.show(
          id: id,
          title: title,
          body: body,
          notificationDetails: details,
          payload: payload,
        );
        if (!await _policyStillCurrent(settings, nativeId: id)) {
          await _notifications.cancel(id: id);
          _reconcileAgain = true;
        }
        await (_database.update(
          _database.androidDailySummarySchedules,
        )..where((row) => row.localDate.equals(localDate))).write(
          AndroidDailySummarySchedulesCompanion(
            taskCount: Value(count),
            state: Value(state),
          ),
        );
      }
      return;
    }
    if (current != null &&
        !pending &&
        current.scheduledAtUtc <= now.millisecondsSinceEpoch) {
      // Could be a dismissal, including when active-state inspection is unknown.
      // Never recreate it. Privacy cleanup uses its known ID even under uncertainty.
      if (settings.notificationDetailLevel == NotificationDetailLevel.private ||
          activeStateKnown) {
        await consume();
      }
      return;
    }
    if (readiness.value.notificationsAllowed == false ||
        readiness.value.summariesAllowed == false) {
      return;
    }
    if (current != null &&
        pending &&
        current.taskCount == count &&
        current.state == state) {
      return;
    }
    final parts = settings.dueTodayNotificationTime.split(':');
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      int.parse(parts[0]),
      int.parse(parts[1]),
    );
    if (!scheduled.isAfter(now)) {
      scheduled = now.add(const Duration(seconds: 5));
    }
    final scheduledAt = applyAndroidQuietHours(
      scheduled.millisecondsSinceEpoch,
      settings,
    );
    final release = tz.TZDateTime.fromMillisecondsSinceEpoch(
      tz.local,
      scheduledAt,
    );
    if (notificationLocalDate(release) != localDate) return;
    if (current != null) await _notifications.cancel(id: id);
    // Persist before awaiting native work so a concurrent privacy edit, dismissal
    // or a failed registration retains a known cleanup identity.
    await _database
        .into(_database.androidDailySummarySchedules)
        .insertOnConflictUpdate(
          AndroidDailySummarySchedulesCompanion.insert(
            localDate: localDate,
            platformId: id,
            generation: generation,
            scheduledAtUtc: scheduledAt,
            taskCount: count,
            state: Value(state),
            updatedAtUtc: now.millisecondsSinceEpoch,
          ),
        );
    try {
      if (!await _policyStillCurrent(settings)) {
        _reconcileAgain = true;
        return;
      }
      await _notifications.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: tz.TZDateTime.fromMillisecondsSinceEpoch(
          tz.local,
          scheduledAt,
        ),
        notificationDetails: details,
        androidScheduleMode: exact
            ? AndroidScheduleMode.exactAllowWhileIdle
            : AndroidScheduleMode.inexactAllowWhileIdle,
        payload: payload,
      );
      if (!await _policyStillCurrent(settings, nativeId: id)) {
        await _notifications.cancel(id: id);
        _reconcileAgain = true;
      }
    } on Object {
      await _notifications.cancel(id: id);
      await (_database.delete(
        _database.androidDailySummarySchedules,
      )..where((row) => row.localDate.equals(localDate))).go();
      rethrow;
    }
  }

  Future<void> _foregroundResponse(NotificationResponse response) async {
    if (response.actionId != null &&
        !const {
          androidNotificationActionOpen,
          androidNotificationActionSnooze,
          androidNotificationActionDismiss,
        }.contains(response.actionId)) {
      return;
    }
    if (response.actionId == androidNotificationActionSnooze ||
        response.actionId == androidNotificationActionDismiss) {
      final payload = parseAndroidReminderActivation(response.payload);
      if (payload == null) return;
      final lease = await _platform.acquireAccountGate('__notifications__');
      try {
        await applyAndroidReminderAction(
          database: _database,
          activation: payload,
          actionId: response.actionId!,
          nowUtc: _now().toUtc(),
        );
      } finally {
        await _platform.releaseAccountGate(lease);
      }
      await reconcile();
      return;
    }
    final activation = _publicActivation(
      _AndroidReminderPayload.tryParse(response.payload),
    );
    if (activation != null) _activations.add(activation);
  }
}

String _defaultDueTodayBody(int count) => '$count tasks are due today.';

AndroidReminderActivation? _publicActivation(_AndroidReminderPayload? payload) {
  if (payload == null) return null;
  return AndroidReminderActivation(
    scheduleId: payload.scheduleId,
    generation: payload.generation,
    sourceType: payload.sourceType,
    accountId: payload.accountId,
    itemId: payload.sourceId,
  );
}

int applyAndroidQuietHours(int epochMillis, AppSettings settings) {
  if (!settings.quietHoursEnabled) return epochMillis;
  final start = _minutesOfDay(settings.quietHoursStart);
  final end = _minutesOfDay(settings.quietHoursEnd);
  if (start == null || end == null || start == end) return epochMillis;
  final local = tz.TZDateTime.fromMillisecondsSinceEpoch(tz.local, epochMillis);
  final current = local.hour * 60 + local.minute;
  final quiet = start < end
      ? current >= start && current < end
      : current >= start || current < end;
  if (!quiet) return epochMillis;
  var dayOffset = 0;
  if (start > end && current >= start) dayOffset = 1;
  return tz.TZDateTime(
    tz.local,
    local.year,
    local.month,
    local.day + dayOffset,
    end ~/ 60,
    end % 60,
  ).millisecondsSinceEpoch;
}

/// Fingerprint of platform-visible scheduling choices that are not represented
/// by a reminder generation. A changed fingerprint must replace the existing
/// Android registration even when the source reminder itself did not change.
String androidNotificationRegistrationState({
  required AppSettings settings,
  required bool exact,
  String? title,
  String? body,
  List<String>? actionLabels,
}) {
  final contentHash = sha256.convert(
    utf8.encode(
      jsonEncode([title, body, if (actionLabels != null) actionLabels]),
    ),
  );
  return 'scheduled:v3:${settings.notificationDetailLevel.name}:'
      '${exact ? 'exact' : 'inexact'}:$contentHash';
}

AndroidNotificationAction androidOpenNotificationAction(
  AndroidNotificationStrings strings,
) => AndroidNotificationAction(
  androidNotificationActionOpen,
  strings.open,
  showsUserInterface: true,
);

List<AndroidNotificationAction> androidReminderNotificationActions(
  AndroidNotificationStrings strings,
) => [
  androidOpenNotificationAction(strings),
  AndroidNotificationAction(
    androidNotificationActionSnooze,
    strings.snooze,
    cancelNotification: true,
  ),
  AndroidNotificationAction(
    androidNotificationActionDismiss,
    strings.dismiss,
    cancelNotification: true,
  ),
];

bool shouldKeepAndroidReminder({
  required int effectiveAt,
  required int now,
  required int horizon,
  required bool remainsPending,
  bool remainsDisplayed = false,
  bool eligibleForCatchUp = false,
}) =>
    effectiveAt <= horizon &&
    (effectiveAt > now ||
        remainsPending ||
        remainsDisplayed ||
        eligibleForCatchUp);

int? _minutesOfDay(String value) {
  final parts = value.split(':');
  if (parts.length != 2) return null;
  final hour = int.tryParse(parts[0]);
  final minute = int.tryParse(parts[1]);
  if (hour == null ||
      minute == null ||
      hour < 0 ||
      hour > 23 ||
      minute < 0 ||
      minute > 59) {
    return null;
  }
  return hour * 60 + minute;
}

int _effectiveAt(NotificationScheduleData row) =>
    row.snoozedUntilUtc ?? row.scheduledAtUtc;

int allocateAndroidNotificationId(String value, Set<int> used) {
  var hash = 0x811c9dc5;
  for (final byte in utf8.encode(value)) {
    hash = ((hash ^ byte) * 0x01000193) & 0x7fffffff;
  }
  if (hash == 0) hash = 1;
  while (used.contains(hash)) {
    hash = hash == 0x7fffffff ? 1 : hash + 1;
  }
  return hash;
}

AndroidReminderActivation? parseAndroidReminderActivation(String? payload) =>
    _publicActivation(_AndroidReminderPayload.tryParse(payload));

final class _AndroidReminderPayload {
  const _AndroidReminderPayload({
    required this.scheduleId,
    required this.generation,
    required this.sourceType,
    required this.accountId,
    required this.sourceId,
  });

  static _AndroidReminderPayload? tryParse(String? value) {
    if (value == null || value.length > 2048) return null;
    try {
      final json = jsonDecode(value);
      if (json is! Map) return null;
      final map = json.cast<String, Object?>();
      final fields = ['schedule', 'generation', 'type', 'account', 'source'];
      if (map['v'] != 1 ||
          map.length != 6 ||
          fields.any(
            (key) =>
                map[key] is! String ||
                (map[key] as String).trim().isEmpty ||
                (map[key] as String).length > 1024,
          ) ||
          !const {
            'event',
            'task',
            'summary',
            'sync-failure',
            'conflict',
          }.contains(map['type'])) {
        return null;
      }
      return _AndroidReminderPayload(
        scheduleId: map['schedule']!.toString(),
        generation: map['generation']!.toString(),
        sourceType: map['type']!.toString(),
        accountId: map['account']!.toString(),
        sourceId: map['source']!.toString(),
      );
    } on Object {
      return null;
    }
  }

  final String scheduleId;
  final String generation;
  final String sourceType;
  final String accountId;
  final String sourceId;

  String encode() => jsonEncode({
    'v': 1,
    'schedule': scheduleId,
    'generation': generation,
    'type': sourceType,
    'account': accountId,
    'source': sourceId,
  });
}

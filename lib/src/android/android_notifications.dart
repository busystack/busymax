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
    final settings = await loadInitialAppSettings(
      const JsonFileLocalSettingsStore(),
    );
    final reconcileDatabase = AppDatabase.open();
    final service = AndroidNotificationService(
      database: reconcileDatabase,
      settings: () => settings,
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
    BusyMaxAndroidPlatform? platform,
    AndroidNotificationStrings Function()? strings,
    FlutterLocalNotificationsPlugin? plugin,
    AndroidNotificationBackend? backend,
    Future<bool> Function()? exactAlarmCapability,
    DateTime Function()? now,
  }) : _database = database,
       _settings = settings,
       _platform = platform ?? BusyMaxAndroidPlatform.instance,
       _strings =
           strings ??
           (() => AndroidNotificationStrings.forSettings(settings())),
       _notifications = backend ?? FlutterAndroidNotificationBackend(plugin),
       _exactAlarmCapability = exactAlarmCapability,
       _now = now ?? DateTime.now;

  final DateTime Function() _now;
  final AppDatabase _database;
  final AppSettings Function() _settings;
  final BusyMaxAndroidPlatform _platform;
  final AndroidNotificationStrings Function() _strings;
  final AndroidNotificationBackend _notifications;
  final Future<bool> Function()? _exactAlarmCapability;
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
    } on ArgumentError {
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

  Future<int?> _issueNativeId(String id, {bool allocate = false}) async {
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
  }

  Future<bool> cancelOperationalIssue(String id) async {
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
  ) async {
    final settings = _settings();
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
        : switch (revision) {
            'reconnectRequired' => strings.reconnectRequired,
            'permissionChanged' => strings.permissionChanged,
            'unsupportedProvider' => strings.unsupportedProvider,
            _ => strings.temporarilyUnavailable,
          };
    final stableId = accountId == null ? kind : '$kind|$accountId';
    try {
      final id = await _issueNativeId(stableId, allocate: true);
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
      if (_settings().notificationDetailLevel !=
              settings.notificationDetailLevel ||
          (kind == 'conflict'
              ? !_settings().notifyConflicts
              : !_settings().notifySyncFailures)) {
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
    String? lease;
    try {
      lease = await _platform.acquireAccountGate('__notifications__');
      do {
        _reconcileAgain = false;
        await _reconcileOnce();
      } while (_reconcileAgain);
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
      if (lease != null) await _platform.releaseAccountGate(lease);
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
    final settings = _settings();
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
                  !remainsPending &&
                  effectiveAt <= nowMillis));
      if (mappingMatchesGeneration &&
          mapping!.state != 'blocked' &&
          !mapping.state.startsWith('registering:') &&
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
      for (final mapping in activeMappings.values) mapping.platformId,
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
          await (_database.update(
            _database.androidNotificationMappings,
          )..where((table) => table.scheduleId.equals(row.id))).write(
            const AndroidNotificationMappingsCompanion(state: Value('blocked')),
          );
          await _notifications.cancel(id: mapping.platformId);
        }
        continue;
      }
      if (unchangedPending) continue;
      if (mapping != null) {
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
          _settings().notificationDetailLevel !=
              settings.notificationDetailLevel ||
          (row.sourceType == 'event'
              ? !_settings().notifyEventReminders
              : !_settings().notifyTaskReminders)) {
        await _notifications.cancel(id: platformId);
        if (effectiveAt <= _now().millisecondsSinceEpoch && current != null) {
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
        await _notifications.show(
          id: id,
          title: title,
          body: body,
          notificationDetails: details,
          payload: payload,
        );
        if (_settings().notificationDetailLevel !=
            settings.notificationDetailLevel) {
          await _notifications.cancel(id: id);
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
      if (_settings().notificationDetailLevel !=
              settings.notificationDetailLevel ||
          !_settings().notifyDueToday) {
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

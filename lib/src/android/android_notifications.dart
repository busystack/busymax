import 'dart:async';
import 'dart:convert';

import 'package:busymax_android_platform/busymax_android_platform.dart';
import 'package:drift/drift.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../app/app_settings.dart';
import '../core/time/stored_temporal_projection.dart';
import '../db/app_database.dart';
import '../features/accounts/data/accounts_repository.dart';
import '../features/notifications/notification_reconciler.dart';

const androidReminderChannelId = 'busymax_reminders_v1';
const androidStatusChannelId = 'busymax_status_v1';
const androidNotificationActionOpen = 'busymax.open';
const androidNotificationActionSnooze = 'busymax.snooze';
const androidNotificationActionDismiss = 'busymax.dismiss';
const _maximumScheduledAlarms = 256;
const _schedulingHorizon = Duration(days: 90);

final androidNotificationServiceProvider = Provider<AndroidNotificationService>(
  (ref) => throw UnsupportedError(
    'AndroidNotificationService must be supplied by the Android runtime.',
  ),
);

@pragma('vm:entry-point')
Future<void> busyMaxNotificationBackgroundResponse(
  NotificationResponse response,
) async {
  final payload = _AndroidReminderPayload.tryParse(response.payload);
  if (payload == null ||
      response.actionId == null ||
      response.actionId == androidNotificationActionOpen) {
    return;
  }
  final platform = BusyMaxAndroidPlatform.instance;
  final lease = await platform.acquireAccountGate('__notifications__');
  final database = AppDatabase.open();
  var changed = false;
  try {
    final row = await (database.select(
      database.notificationSchedule,
    )..where((table) => table.id.equals(payload.scheduleId))).getSingleOrNull();
    if (row == null || row.generation != payload.generation) return;
    final account = await (database.select(
      database.accounts,
    )..where((table) => table.id.equals(payload.accountId))).getSingleOrNull();
    if (account == null) return;
    final itemExists = switch (payload.sourceType) {
      'event' =>
        await (database.select(database.calendarEvents)..where(
                  (table) =>
                      table.accountId.equals(payload.accountId) &
                      table.id.equals(payload.sourceId) &
                      table.isDeleted.equals(false),
                ))
                .getSingleOrNull() !=
            null,
      'task' =>
        await (database.select(database.tasks)..where(
                  (table) =>
                      table.accountId.equals(payload.accountId) &
                      table.id.equals(payload.sourceId) &
                      table.pendingDelete.equals(false),
                ))
                .getSingleOrNull() !=
            null,
      _ => false,
    };
    if (!itemExists) return;
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    final update = switch (response.actionId) {
      androidNotificationActionSnooze => NotificationScheduleCompanion(
        generation: Value('${row.generation}:snooze:$now'),
        snoozedUntilUtc: Value(
          DateTime.now()
              .toUtc()
              .add(const Duration(minutes: 10))
              .millisecondsSinceEpoch,
        ),
        sentAtUtc: const Value(null),
        updatedAtLocal: Value(now),
      ),
      androidNotificationActionDismiss => NotificationScheduleCompanion(
        dismissedAtUtc: Value(now),
        updatedAtLocal: Value(now),
      ),
      _ => null,
    };
    if (update != null) {
      await (database.update(database.notificationSchedule)..where(
            (table) =>
                table.id.equals(payload.scheduleId) &
                table.generation.equals(payload.generation),
          ))
          .write(update);
      await (database.delete(
        database.androidNotificationMappings,
      )..where((table) => table.scheduleId.equals(payload.scheduleId))).go();
      changed = true;
    }
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
    this.snooze = 'Snooze',
    this.dismiss = 'Dismiss',
    this.syncFailureTitle = 'BusyMax sync issue',
    this.syncFailureBody = 'Open BusyMax to review the account status.',
    this.conflictTitle = 'BusyMax sync conflict',
    this.dueTodayTitle = 'Tasks due today',
    this.dueTodayBody = _defaultDueTodayBody,
  });

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
  }) : _database = database,
       _settings = settings,
       _platform = platform ?? BusyMaxAndroidPlatform.instance,
       _strings = strings ?? _defaultStrings,
       _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final AppDatabase _database;
  final AppSettings Function() _settings;
  final BusyMaxAndroidPlatform _platform;
  final AndroidNotificationStrings Function() _strings;
  final FlutterLocalNotificationsPlugin _plugin;
  final StreamController<AndroidReminderActivation> _activations =
      StreamController<AndroidReminderActivation>.broadcast(sync: true);
  AndroidReminderActivation? _initialActivation;
  bool _initialized = false;
  bool _reconciling = false;
  bool _reconcileAgain = false;
  String _precisionDiagnostic = 'Alarm precision has not been checked.';

  String get precisionDiagnostic => _precisionDiagnostic;
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
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('ic_notification'),
      ),
      onDidReceiveNotificationResponse: _foregroundResponse,
      onDidReceiveBackgroundNotificationResponse:
          busyMaxNotificationBackgroundResponse,
    );
    final launch = await _plugin.getNotificationAppLaunchDetails();
    if (launch?.didNotificationLaunchApp ?? false) {
      _initialActivation = _publicActivation(
        _AndroidReminderPayload.tryParse(launch?.notificationResponse?.payload),
      );
    }
    _initialized = true;
  }

  void updateTimeZone(String timeZoneId) {
    try {
      tz.setLocalLocation(tz.getLocation(timeZoneId));
    } on ArgumentError {
      tz.setLocalLocation(tz.UTC);
    }
  }

  Future<bool> requestNotificationPermission() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    return await android?.requestNotificationsPermission() ?? true;
  }

  Future<bool> requestExactAlarmPermission() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    return await android?.requestExactAlarmsPermission() ?? false;
  }

  Future<bool> canScheduleExactly() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    return await android?.canScheduleExactNotifications() ?? false;
  }

  @override
  Future<void> notifySyncFailure(Object error) async {
    final settings = _settings();
    if (!settings.notifySyncFailures || _isQuietNow(settings)) return;
    final strings = _strings();
    await _showStatus(
      id: 0x425901,
      title: strings.syncFailureTitle,
      body: strings.syncFailureBody,
    );
  }

  @override
  Future<void> notifyConflict(String summary) async {
    final settings = _settings();
    if (!settings.notifyConflicts || _isQuietNow(settings)) return;
    final strings = _strings();
    await _showStatus(
      id: 0x425902,
      title: strings.conflictTitle,
      body: settings.notificationDetailLevel == NotificationDetailLevel.private
          ? null
          : summary,
    );
  }

  Future<void> _showStatus({
    required int id,
    required String title,
    required String? body,
  }) async {
    if (!_initialized) return;
    final strings = _strings();
    await _plugin.show(
      id: id,
      title: title,
      body: body,
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
    } finally {
      if (lease != null) await _platform.releaseAccountGate(lease);
      _reconciling = false;
    }
  }

  Future<void> _reconcileOnce() async {
    final now = DateTime.now().toUtc();
    final horizon = now.add(_schedulingHorizon).millisecondsSinceEpoch;
    final eligibleAccounts = {
      for (final account in await _database.select(_database.accounts).get())
        if (accountLocalReminderEligibleStates.contains(account.authState))
          account.id,
    };
    final settings = _settings();
    final rows =
        await (_database.select(_database.notificationSchedule)..where(
              (table) =>
                  table.accountId.isIn(eligibleAccounts) &
                  table.sentAtUtc.isNull() &
                  table.dismissedAtUtc.isNull() &
                  table.scheduledAtUtc.isSmallerOrEqualValue(horizon),
            ))
            .get();
    rows.removeWhere(
      (row) =>
          (row.sourceType == 'event' && !settings.notifyEventReminders) ||
          (row.sourceType == 'task' && !settings.notifyTaskReminders) ||
          !const {'event', 'task'}.contains(row.sourceType) ||
          _effectiveAt(row) <= now.millisecondsSinceEpoch,
    );
    rows.sort((a, b) => _effectiveAt(a).compareTo(_effectiveAt(b)));
    final desired = rows.take(_maximumScheduledAlarms).toList();
    final desiredIds = {for (final row in desired) row.id};
    final mappings = await _database
        .select(_database.androidNotificationMappings)
        .get();
    final pendingIds = {
      for (final request in await _plugin.pendingNotificationRequests())
        request.id,
    };

    for (final mapping in mappings) {
      if (!desiredIds.contains(mapping.scheduleId)) {
        await _plugin.cancel(id: mapping.platformId);
        await (_database.delete(
          _database.androidNotificationMappings,
        )..where((table) => table.scheduleId.equals(mapping.scheduleId))).go();
      }
    }

    final exact = await canScheduleExactly();
    _precisionDiagnostic = exact
        ? 'Exact reminder alarms are enabled.'
        : 'Exact alarm access is unavailable; reminders use Android inexact scheduling.';
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
    for (final row in desired) {
      final effectiveAt = applyAndroidQuietHours(_effectiveAt(row), settings);
      var mapping = activeMappings[row.id];
      final unchanged =
          mapping != null &&
          mapping.generation == row.generation &&
          mapping.scheduledAtUtc == effectiveAt &&
          pendingIds.contains(mapping.platformId);
      if (unchanged) continue;
      if (mapping != null) await _plugin.cancel(id: mapping.platformId);
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
      final strings = _strings();
      await _plugin.zonedSchedule(
        id: platformId,
        title:
            settings.notificationDetailLevel == NotificationDetailLevel.private
            ? strings.privateTitle
            : row.title,
        body:
            settings.notificationDetailLevel == NotificationDetailLevel.private
            ? null
            : row.body,
        scheduledDate: tz.TZDateTime.fromMillisecondsSinceEpoch(
          tz.local,
          effectiveAt,
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
            actions: <AndroidNotificationAction>[
              AndroidNotificationAction(
                androidNotificationActionOpen,
                strings.open,
              ),
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
            ],
          ),
        ),
        androidScheduleMode: exact
            ? AndroidScheduleMode.exactAllowWhileIdle
            : AndroidScheduleMode.inexactAllowWhileIdle,
        payload: payload,
      );
      await _database
          .into(_database.androidNotificationMappings)
          .insertOnConflictUpdate(
            AndroidNotificationMappingsCompanion.insert(
              scheduleId: row.id,
              generation: row.generation,
              platformId: platformId,
              scheduledAtUtc: effectiveAt,
              updatedAtUtc: now.millisecondsSinceEpoch,
            ),
          );
    }
    await _reconcileDailySummary(
      settings: settings,
      eligibleAccounts: eligibleAccounts,
      exact: exact,
      pendingIds: pendingIds,
    );
  }

  Future<void> _reconcileDailySummary({
    required AppSettings settings,
    required Set<String> eligibleAccounts,
    required bool exact,
    required Set<int> pendingIds,
  }) async {
    const platformId = 0x425903;
    final existing = await _database
        .select(_database.androidDailySummarySchedules)
        .get();
    if (!settings.notifyDueToday || eligibleAccounts.isEmpty) {
      await _plugin.cancel(id: platformId);
      await _database.delete(_database.androidDailySummarySchedules).go();
      return;
    }
    final now = tz.TZDateTime.now(tz.local);
    final localDate =
        '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    for (final row in existing.where((row) => row.localDate != localDate)) {
      await _plugin.cancel(id: row.platformId);
      await (_database.delete(
        _database.androidDailySummarySchedules,
      )..where((table) => table.localDate.equals(row.localDate))).go();
    }
    final activeListKeys = {
      for (final list
          in await (_database.select(_database.taskLists)..where(
                (table) =>
                    table.accountId.isIn(eligibleAccounts) &
                    table.pendingDelete.equals(false) &
                    table.serverMissing.equals(false),
              ))
              .get())
        '${list.accountId}\u0000${list.id}',
    };
    final tasks = activeListKeys.isEmpty
        ? const <Task>[]
        : await (_database.select(_database.tasks)..where(
                (table) =>
                    table.accountId.isIn(eligibleAccounts) &
                    table.pendingDelete.equals(false) &
                    (table.deleted.isNull() | table.deleted.equals(false)) &
                    (table.hidden.isNull() | table.hidden.equals(false)),
              ))
              .get();
    final count = tasks.where((task) {
      if (!activeListKeys.contains(
        '${task.accountId}\u0000${task.taskListId}',
      )) {
        return false;
      }
      if (task.status == 'completed' || task.status == 'cancelled') {
        return false;
      }
      final due = taskDueAsLocal(task);
      return due != null &&
          due.year == now.year &&
          due.month == now.month &&
          due.day == now.day;
    }).length;
    if (count == 0) {
      await _plugin.cancel(id: platformId);
      await (_database.delete(
        _database.androidDailySummarySchedules,
      )..where((table) => table.localDate.equals(localDate))).go();
      return;
    }
    final current = existing
        .where((row) => row.localDate == localDate)
        .firstOrNull;
    if (current != null &&
        current.scheduledAtUtc <= DateTime.now().millisecondsSinceEpoch) {
      // Android does not report ordinary display delivery. Keeping this
      // registration prevents a false delivery claim and duplicate summary.
      return;
    }
    var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, 9);
    if (!scheduled.isAfter(now)) {
      scheduled = now.add(const Duration(seconds: 10));
    }
    final scheduledAt = applyAndroidQuietHours(
      scheduled.millisecondsSinceEpoch,
      settings,
    );
    final unchanged =
        current != null &&
        current.taskCount == count &&
        current.scheduledAtUtc == scheduledAt &&
        pendingIds.contains(platformId);
    if (unchanged) return;
    if (current != null) await _plugin.cancel(id: platformId);
    final generation = '$localDate:$count:$scheduledAt';
    final strings = _strings();
    await _plugin.zonedSchedule(
      id: platformId,
      title: strings.dueTodayTitle,
      body: settings.notificationDetailLevel == NotificationDetailLevel.private
          ? null
          : strings.dueTodayBody(count),
      scheduledDate: tz.TZDateTime.fromMillisecondsSinceEpoch(
        tz.local,
        scheduledAt,
      ),
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          androidReminderChannelId,
          strings.channelName,
          channelDescription: strings.channelDescription,
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          visibility:
              settings.notificationDetailLevel ==
                  NotificationDetailLevel.private
              ? NotificationVisibility.private
              : NotificationVisibility.public,
          actions: <AndroidNotificationAction>[
            AndroidNotificationAction(
              androidNotificationActionOpen,
              strings.open,
            ),
          ],
        ),
      ),
      androidScheduleMode: exact
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle,
      payload: _AndroidReminderPayload(
        scheduleId: 'due-today:$localDate',
        generation: generation,
        sourceType: 'summary',
        accountId: 'all',
        sourceId: localDate,
      ).encode(),
    );
    await _database
        .into(_database.androidDailySummarySchedules)
        .insertOnConflictUpdate(
          AndroidDailySummarySchedulesCompanion.insert(
            localDate: localDate,
            platformId: platformId,
            generation: generation,
            scheduledAtUtc: scheduledAt,
            taskCount: count,
            updatedAtUtc: DateTime.now().millisecondsSinceEpoch,
          ),
        );
  }

  Future<void> _foregroundResponse(NotificationResponse response) async {
    if (response.actionId == androidNotificationActionSnooze ||
        response.actionId == androidNotificationActionDismiss) {
      await busyMaxNotificationBackgroundResponse(response);
      await reconcile();
      return;
    }
    final activation = _publicActivation(
      _AndroidReminderPayload.tryParse(response.payload),
    );
    if (activation != null) _activations.add(activation);
  }
}

AndroidNotificationStrings _defaultStrings() =>
    const AndroidNotificationStrings();

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

bool _isQuietNow(AppSettings settings) {
  final now = DateTime.now().millisecondsSinceEpoch;
  return applyAndroidQuietHours(now, settings) != now;
}

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
      if (fields.any((key) => (map[key]?.toString().trim().isEmpty ?? true))) {
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

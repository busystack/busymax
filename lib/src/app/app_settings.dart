import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../schedule/schedule_view_mode.dart';

enum BusyMaxThemeFamily { yaru }

enum BusyMaxThemeModePreference { system, light, dark }

enum NotificationDetailLevel { private, normal }

const defaultScheduleDayStartMinute = 7 * 60;
const defaultScheduleDayEndMinute = 22 * 60;

extension BusyMaxThemeModePreferenceX on BusyMaxThemeModePreference {
  ThemeMode get themeMode {
    return switch (this) {
      BusyMaxThemeModePreference.system => ThemeMode.system,
      BusyMaxThemeModePreference.light => ThemeMode.light,
      BusyMaxThemeModePreference.dark => ThemeMode.dark,
    };
  }
}

class AppSettings {
  const AppSettings({
    required this.themeFamily,
    required this.themeModePreference,
    required this.notifySyncFailures,
    required this.notifyConflicts,
    required this.notifyDueToday,
    required this.notifyEventReminders,
    required this.notifyTaskReminders,
    required this.runInBackgroundWhenClosed,
    required this.showTrayIcon,
    required this.startMinimizedToTray,
    required this.quitExitsCompletely,
    required this.notificationDetailLevel,
    required this.quietHoursEnabled,
    required this.quietHoursStart,
    required this.quietHoursEnd,
    required this.redactTaskContentInDiagnostics,
    required this.lastDueTodayNotificationDate,
    required this.taskListScheduleVisibility,
    required this.scheduleViewMode,
    required this.scheduleDayStartMinute,
    required this.scheduleDayEndMinute,
  });

  factory AppSettings.defaults() {
    return const AppSettings(
      themeFamily: BusyMaxThemeFamily.yaru,
      themeModePreference: BusyMaxThemeModePreference.system,
      notifySyncFailures: true,
      notifyConflicts: true,
      notifyDueToday: false,
      notifyEventReminders: true,
      notifyTaskReminders: true,
      runInBackgroundWhenClosed: true,
      showTrayIcon: true,
      startMinimizedToTray: false,
      quitExitsCompletely: true,
      notificationDetailLevel: NotificationDetailLevel.normal,
      quietHoursEnabled: false,
      quietHoursStart: '22:00',
      quietHoursEnd: '07:00',
      redactTaskContentInDiagnostics: true,
      lastDueTodayNotificationDate: null,
      taskListScheduleVisibility: <String, bool>{},
      scheduleViewMode: ScheduleViewMode.week,
      scheduleDayStartMinute: defaultScheduleDayStartMinute,
      scheduleDayEndMinute: defaultScheduleDayEndMinute,
    );
  }

  factory AppSettings.fromJson(Map<String, Object?> json) {
    final defaults = AppSettings.defaults();
    final dayStart = _minuteOfDay(
      json['scheduleDayStartMinute'],
      defaults.scheduleDayStartMinute,
    );
    final dayEnd = _minuteOfDay(
      json['scheduleDayEndMinute'],
      defaults.scheduleDayEndMinute,
      allowEndOfDay: true,
    );
    final (
      scheduleDayStartMinute,
      scheduleDayEndMinute,
    ) = _validScheduleDayRange(
      startMinute: dayStart,
      endMinute: dayEnd,
      fallbackStart: defaults.scheduleDayStartMinute,
      fallbackEnd: defaults.scheduleDayEndMinute,
    );
    final notificationDetailLevel =
        _enumFromNameOrNull(
          NotificationDetailLevel.values,
          json['notificationDetailLevel'],
        ) ??
        switch (json['detailedNotifications']) {
          true => NotificationDetailLevel.normal,
          false => NotificationDetailLevel.private,
          _ => defaults.notificationDetailLevel,
        };
    var quietHoursStart = _normalizedTimeOfDay(
      json['quietHoursStart'],
      defaults.quietHoursStart,
    );
    var quietHoursEnd = _normalizedTimeOfDay(
      json['quietHoursEnd'],
      defaults.quietHoursEnd,
    );
    if (quietHoursStart == quietHoursEnd) {
      quietHoursStart = defaults.quietHoursStart;
      quietHoursEnd = defaults.quietHoursEnd;
    }
    final runInBackgroundWhenClosed =
        json['runInBackgroundWhenClosed'] as bool? ??
        defaults.runInBackgroundWhenClosed;
    final startMinimizedToTray =
        json['startMinimizedToTray'] as bool? ?? defaults.startMinimizedToTray;
    final showTrayIcon =
        (json['showTrayIcon'] as bool? ?? defaults.showTrayIcon) ||
        runInBackgroundWhenClosed ||
        startMinimizedToTray;
    return AppSettings(
      themeFamily: _enumFromName(
        BusyMaxThemeFamily.values,
        json['themeFamily'],
        defaults.themeFamily,
      ),
      themeModePreference: _enumFromName(
        BusyMaxThemeModePreference.values,
        json['themeModePreference'],
        defaults.themeModePreference,
      ),
      notifySyncFailures:
          json['notifySyncFailures'] as bool? ?? defaults.notifySyncFailures,
      notifyConflicts:
          json['notifyConflicts'] as bool? ?? defaults.notifyConflicts,
      notifyDueToday:
          json['notifyDueToday'] as bool? ?? defaults.notifyDueToday,
      notifyEventReminders:
          json['notifyEventReminders'] as bool? ??
          defaults.notifyEventReminders,
      notifyTaskReminders:
          json['notifyTaskReminders'] as bool? ?? defaults.notifyTaskReminders,
      runInBackgroundWhenClosed: runInBackgroundWhenClosed,
      showTrayIcon: showTrayIcon,
      startMinimizedToTray: startMinimizedToTray,
      quitExitsCompletely:
          json['quitExitsCompletely'] as bool? ?? defaults.quitExitsCompletely,
      notificationDetailLevel: notificationDetailLevel,
      quietHoursEnabled:
          json['quietHoursEnabled'] as bool? ?? defaults.quietHoursEnabled,
      quietHoursStart: quietHoursStart,
      quietHoursEnd: quietHoursEnd,
      redactTaskContentInDiagnostics:
          json['redactTaskContentInDiagnostics'] as bool? ??
          defaults.redactTaskContentInDiagnostics,
      lastDueTodayNotificationDate: json['lastDueTodayNotificationDate']
          ?.toString(),
      taskListScheduleVisibility: _boolMap(json['taskListScheduleVisibility']),
      scheduleViewMode: _enumFromName(
        ScheduleViewMode.values,
        json['scheduleViewMode'],
        defaults.scheduleViewMode,
      ),
      scheduleDayStartMinute: scheduleDayStartMinute,
      scheduleDayEndMinute: scheduleDayEndMinute,
    );
  }

  final BusyMaxThemeFamily themeFamily;
  final BusyMaxThemeModePreference themeModePreference;
  final bool notifySyncFailures;
  final bool notifyConflicts;
  final bool notifyDueToday;
  final bool notifyEventReminders;
  final bool notifyTaskReminders;
  final bool runInBackgroundWhenClosed;
  final bool showTrayIcon;
  final bool startMinimizedToTray;
  final bool quitExitsCompletely;
  final NotificationDetailLevel notificationDetailLevel;
  final bool quietHoursEnabled;
  final String quietHoursStart;
  final String quietHoursEnd;
  final bool redactTaskContentInDiagnostics;
  final String? lastDueTodayNotificationDate;
  final Map<String, bool> taskListScheduleVisibility;
  final ScheduleViewMode scheduleViewMode;
  final int scheduleDayStartMinute;
  final int scheduleDayEndMinute;

  ThemeMode get themeMode => themeModePreference.themeMode;

  Map<String, Object?> toJson() {
    return {
      'themeFamily': themeFamily.name,
      'themeModePreference': themeModePreference.name,
      'notifySyncFailures': notifySyncFailures,
      'notifyConflicts': notifyConflicts,
      'notifyDueToday': notifyDueToday,
      'notifyEventReminders': notifyEventReminders,
      'notifyTaskReminders': notifyTaskReminders,
      'runInBackgroundWhenClosed': runInBackgroundWhenClosed,
      'showTrayIcon': showTrayIcon,
      'startMinimizedToTray': startMinimizedToTray,
      'quitExitsCompletely': quitExitsCompletely,
      'notificationDetailLevel': notificationDetailLevel.name,
      'quietHoursEnabled': quietHoursEnabled,
      'quietHoursStart': quietHoursStart,
      'quietHoursEnd': quietHoursEnd,
      'redactTaskContentInDiagnostics': redactTaskContentInDiagnostics,
      'lastDueTodayNotificationDate': lastDueTodayNotificationDate,
      'taskListScheduleVisibility': taskListScheduleVisibility,
      'scheduleViewMode': scheduleViewMode.name,
      'scheduleDayStartMinute': scheduleDayStartMinute,
      'scheduleDayEndMinute': scheduleDayEndMinute,
    };
  }

  AppSettings copyWith({
    BusyMaxThemeFamily? themeFamily,
    BusyMaxThemeModePreference? themeModePreference,
    bool? notifySyncFailures,
    bool? notifyConflicts,
    bool? notifyDueToday,
    bool? notifyEventReminders,
    bool? notifyTaskReminders,
    bool? runInBackgroundWhenClosed,
    bool? showTrayIcon,
    bool? startMinimizedToTray,
    bool? quitExitsCompletely,
    NotificationDetailLevel? notificationDetailLevel,
    bool? quietHoursEnabled,
    String? quietHoursStart,
    String? quietHoursEnd,
    bool? redactTaskContentInDiagnostics,
    String? lastDueTodayNotificationDate,
    Map<String, bool>? taskListScheduleVisibility,
    ScheduleViewMode? scheduleViewMode,
    int? scheduleDayStartMinute,
    int? scheduleDayEndMinute,
    bool clearLastDueTodayNotificationDate = false,
  }) {
    final (
      resolvedScheduleDayStartMinute,
      resolvedScheduleDayEndMinute,
    ) = _validScheduleDayRange(
      startMinute: scheduleDayStartMinute ?? this.scheduleDayStartMinute,
      endMinute: scheduleDayEndMinute ?? this.scheduleDayEndMinute,
      fallbackStart: this.scheduleDayStartMinute,
      fallbackEnd: this.scheduleDayEndMinute,
    );
    return AppSettings(
      themeFamily: themeFamily ?? this.themeFamily,
      themeModePreference: themeModePreference ?? this.themeModePreference,
      notifySyncFailures: notifySyncFailures ?? this.notifySyncFailures,
      notifyConflicts: notifyConflicts ?? this.notifyConflicts,
      notifyDueToday: notifyDueToday ?? this.notifyDueToday,
      notifyEventReminders: notifyEventReminders ?? this.notifyEventReminders,
      notifyTaskReminders: notifyTaskReminders ?? this.notifyTaskReminders,
      runInBackgroundWhenClosed:
          runInBackgroundWhenClosed ?? this.runInBackgroundWhenClosed,
      showTrayIcon: showTrayIcon ?? this.showTrayIcon,
      startMinimizedToTray: startMinimizedToTray ?? this.startMinimizedToTray,
      quitExitsCompletely: quitExitsCompletely ?? this.quitExitsCompletely,
      notificationDetailLevel:
          notificationDetailLevel ?? this.notificationDetailLevel,
      quietHoursEnabled: quietHoursEnabled ?? this.quietHoursEnabled,
      quietHoursStart: quietHoursStart ?? this.quietHoursStart,
      quietHoursEnd: quietHoursEnd ?? this.quietHoursEnd,
      redactTaskContentInDiagnostics:
          redactTaskContentInDiagnostics ?? this.redactTaskContentInDiagnostics,
      lastDueTodayNotificationDate: clearLastDueTodayNotificationDate
          ? null
          : lastDueTodayNotificationDate ?? this.lastDueTodayNotificationDate,
      taskListScheduleVisibility:
          taskListScheduleVisibility ?? this.taskListScheduleVisibility,
      scheduleViewMode: scheduleViewMode ?? this.scheduleViewMode,
      scheduleDayStartMinute: resolvedScheduleDayStartMinute,
      scheduleDayEndMinute: resolvedScheduleDayEndMinute,
    );
  }

  bool isTaskListVisibleInSchedule(String accountId, String taskListId) {
    return taskListScheduleVisibility[_taskListVisibilityKey(
          accountId,
          taskListId,
        )] ??
        true;
  }
}

abstract class LocalSettingsStore {
  Future<Map<String, Object?>> load();
  Future<void> save(Map<String, Object?> json);
}

class JsonFileLocalSettingsStore implements LocalSettingsStore {
  const JsonFileLocalSettingsStore();

  @override
  Future<Map<String, Object?>> load() async {
    final file = await _settingsFile();
    if (!await file.exists()) {
      return <String, Object?>{};
    }
    final content = await file.readAsString();
    if (content.trim().isEmpty) {
      return <String, Object?>{};
    }
    return (jsonDecode(content) as Map).cast<String, Object?>();
  }

  @override
  Future<void> save(Map<String, Object?> json) async {
    final file = await _settingsFile();
    await file.parent.create(recursive: true);
    await file.writeAsString(jsonEncode(json));
  }

  Future<File> _settingsFile() async {
    final directory = await getApplicationSupportDirectory();
    return File(p.join(directory.path, 'settings.json'));
  }
}

typedef _AppSettingsMutation = AppSettings Function(AppSettings current);

class AppSettingsController extends StateNotifier<AppSettings> {
  AppSettingsController(this._store, {AppSettings? initialSettings})
    : super(initialSettings ?? AppSettings.defaults()) {
    _persistenceState = state;
    if (initialSettings == null) {
      _loadFuture = _load();
    } else {
      _loadComplete = true;
      _loadFuture = Future<void>.value();
    }
    _writeTail = _loadFuture;
  }

  final LocalSettingsStore _store;
  final List<_AppSettingsMutation> _mutationsDuringLoad =
      <_AppSettingsMutation>[];
  late AppSettings _persistenceState;
  late final Future<void> _loadFuture;
  late Future<void> _writeTail;
  var _loadComplete = false;
  var _disposed = false;

  Future<void> get ready => _loadFuture;

  Future<void> setThemeModePreference(BusyMaxThemeModePreference preference) {
    return _mutate(
      (current) => current.copyWith(themeModePreference: preference),
    );
  }

  Future<void> setScheduleViewMode(ScheduleViewMode mode) {
    return _mutate((current) => current.copyWith(scheduleViewMode: mode));
  }

  Future<void> setScheduleDayStartMinute(int minute) {
    return _mutate((current) {
      final start = _minuteOfDay(minute, current.scheduleDayStartMinute);
      final end = start >= current.scheduleDayEndMinute
          ? math.min(start + 60, 24 * 60)
          : current.scheduleDayEndMinute;
      return current.copyWith(
        scheduleDayStartMinute: start,
        scheduleDayEndMinute: end,
      );
    });
  }

  Future<void> setScheduleDayEndMinute(int minute) {
    return _mutate((current) {
      final end = _minuteOfDay(
        minute,
        current.scheduleDayEndMinute,
        allowEndOfDay: true,
      );
      final start = end <= current.scheduleDayStartMinute
          ? math.max(end - 60, 0)
          : current.scheduleDayStartMinute;
      return current.copyWith(
        scheduleDayStartMinute: start,
        scheduleDayEndMinute: end,
      );
    });
  }

  Future<void> setNotifySyncFailures(bool enabled) {
    return _mutate((current) => current.copyWith(notifySyncFailures: enabled));
  }

  Future<void> setNotifyConflicts(bool enabled) {
    return _mutate((current) => current.copyWith(notifyConflicts: enabled));
  }

  Future<void> setNotifyDueToday(bool enabled) {
    return _mutate((current) => current.copyWith(notifyDueToday: enabled));
  }

  Future<void> setNotifyEventReminders(bool enabled) {
    return _mutate(
      (current) => current.copyWith(notifyEventReminders: enabled),
    );
  }

  Future<void> setNotifyTaskReminders(bool enabled) {
    return _mutate((current) => current.copyWith(notifyTaskReminders: enabled));
  }

  Future<void> setRunInBackgroundWhenClosed(bool enabled) {
    return _mutate(
      (current) => current.copyWith(
        runInBackgroundWhenClosed: enabled,
        showTrayIcon: enabled ? true : current.showTrayIcon,
      ),
    );
  }

  Future<void> setShowTrayIcon(bool enabled) {
    return _mutate(
      (current) => current.copyWith(
        showTrayIcon: enabled,
        runInBackgroundWhenClosed: enabled
            ? current.runInBackgroundWhenClosed
            : false,
        startMinimizedToTray: enabled ? current.startMinimizedToTray : false,
      ),
    );
  }

  Future<void> setStartMinimizedToTray(bool enabled) {
    return _mutate(
      (current) => current.copyWith(
        startMinimizedToTray: enabled,
        showTrayIcon: enabled ? true : current.showTrayIcon,
      ),
    );
  }

  Future<void> setQuitExitsCompletely(bool enabled) {
    return _mutate((current) => current.copyWith(quitExitsCompletely: enabled));
  }

  Future<void> setNotificationDetailLevel(NotificationDetailLevel level) {
    return _mutate(
      (current) => current.copyWith(notificationDetailLevel: level),
    );
  }

  Future<void> setQuietHoursEnabled(bool enabled) {
    return _mutate((current) => current.copyWith(quietHoursEnabled: enabled));
  }

  Future<void> setQuietHoursStart(String time) {
    return _mutate((current) {
      final normalized = _normalizedTimeOfDay(time, current.quietHoursStart);
      if (normalized == current.quietHoursEnd) {
        return current;
      }
      return current.copyWith(quietHoursStart: normalized);
    });
  }

  Future<void> setQuietHoursEnd(String time) {
    return _mutate((current) {
      final normalized = _normalizedTimeOfDay(time, current.quietHoursEnd);
      if (normalized == current.quietHoursStart) {
        return current;
      }
      return current.copyWith(quietHoursEnd: normalized);
    });
  }

  Future<void> setRedactTaskContentInDiagnostics(bool enabled) {
    return _mutate(
      (current) => current.copyWith(redactTaskContentInDiagnostics: enabled),
    );
  }

  Future<void> markDueTodayNotified(String date) {
    return _mutate(
      (current) => current.copyWith(lastDueTodayNotificationDate: date),
    );
  }

  Future<void> setTaskListVisibleInSchedule({
    required String accountId,
    required String taskListId,
    required bool visible,
  }) {
    return _mutate((current) {
      final next = Map<String, bool>.from(current.taskListScheduleVisibility)
        ..[_taskListVisibilityKey(accountId, taskListId)] = visible;
      return current.copyWith(taskListScheduleVisibility: next);
    });
  }

  Future<void> _load() async {
    final loaded = await loadInitialAppSettings(_store);

    _persistenceState = loaded;
    var merged = loaded;
    for (final mutation in _mutationsDuringLoad) {
      merged = mutation(merged);
    }
    _mutationsDuringLoad.clear();
    _loadComplete = true;
    if (!_disposed) {
      state = merged;
    }
  }

  Future<void> _mutate(_AppSettingsMutation mutation) {
    final next = mutation(state);
    if (!_loadComplete) {
      _mutationsDuringLoad.add(mutation);
    }

    final previousWrite = _writeTail;
    final write = _persistAfter(previousWrite, mutation);
    _writeTail = write;
    state = next;
    return write;
  }

  Future<void> _persistAfter(
    Future<void> previousWrite,
    _AppSettingsMutation mutation,
  ) async {
    await previousWrite;
    final next = mutation(_persistenceState);
    _persistenceState = next;
    try {
      await _store.save(next.toJson());
    } on Object {
      // Keep the in-memory preference even when local persistence is unavailable.
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

class BusyMaxThemeController {
  const BusyMaxThemeController(this._settingsController);

  final AppSettingsController _settingsController;

  Future<void> setThemeMode(BusyMaxThemeModePreference preference) {
    return _settingsController.setThemeModePreference(preference);
  }
}

final localSettingsStoreProvider = Provider<LocalSettingsStore>(
  (ref) => const JsonFileLocalSettingsStore(),
);

final initialAppSettingsProvider = Provider<AppSettings?>((ref) => null);

final appSettingsControllerProvider =
    StateNotifierProvider<AppSettingsController, AppSettings>((ref) {
      return AppSettingsController(
        ref.watch(localSettingsStoreProvider),
        initialSettings: ref.watch(initialAppSettingsProvider),
      );
    });

final busyMaxThemeControllerProvider = Provider<BusyMaxThemeController>((ref) {
  return BusyMaxThemeController(
    ref.watch(appSettingsControllerProvider.notifier),
  );
});

Future<AppSettings> loadInitialAppSettings(LocalSettingsStore store) async {
  try {
    return AppSettings.fromJson(await store.load());
  } on Object {
    return AppSettings.defaults();
  }
}

T _enumFromName<T extends Enum>(List<T> values, Object? name, T fallback) {
  return _enumFromNameOrNull(values, name) ?? fallback;
}

T? _enumFromNameOrNull<T extends Enum>(List<T> values, Object? name) {
  if (name == null) {
    return null;
  }
  for (final value in values) {
    if (value.name == name.toString()) {
      return value;
    }
  }
  return null;
}

String _normalizedTimeOfDay(Object? value, String fallback) {
  final parts = value?.toString().trim().split(':') ?? const <String>[];
  if (parts.length != 2) {
    return fallback;
  }
  final hour = int.tryParse(parts[0]);
  final minute = int.tryParse(parts[1]);
  if (hour == null ||
      minute == null ||
      hour < 0 ||
      hour > 23 ||
      minute < 0 ||
      minute > 59) {
    return fallback;
  }
  return '${hour.toString().padLeft(2, '0')}:'
      '${minute.toString().padLeft(2, '0')}';
}

int _minuteOfDay(Object? value, int fallback, {bool allowEndOfDay = false}) {
  final minute = switch (value) {
    int() => value,
    String() => int.tryParse(value) ?? fallback,
    _ => fallback,
  };
  final max = allowEndOfDay ? 24 * 60 : 24 * 60 - 1;
  if (minute < 0 || minute > max) {
    return fallback;
  }
  return minute;
}

(int, int) _validScheduleDayRange({
  required int startMinute,
  required int endMinute,
  required int fallbackStart,
  required int fallbackEnd,
}) {
  if (startMinute < 0 ||
      startMinute >= 24 * 60 ||
      endMinute <= 0 ||
      endMinute > 24 * 60 ||
      endMinute <= startMinute) {
    return (fallbackStart, fallbackEnd);
  }
  return (startMinute, endMinute);
}

Map<String, bool> _boolMap(Object? value) {
  if (value is! Map) {
    return <String, bool>{};
  }
  return value.map((key, value) {
    return MapEntry(key.toString(), value == true);
  });
}

String _taskListVisibilityKey(String accountId, String taskListId) {
  return '$accountId::$taskListId';
}

import 'dart:async';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../schedule/schedule_filters.dart';
import '../schedule/schedule_search_criteria.dart';

@visibleForTesting
const linuxScheduleSearchFilterChannelName =
    'busymax/native_schedule_search_filters';

@immutable
final class LinuxScheduleSearchFilterLabels {
  const LinuxScheduleSearchFilterLabels({
    required this.searchFilters,
    required this.type,
    required this.all,
    required this.events,
    required this.tasks,
    required this.date,
    required this.anyDate,
    required this.today,
    required this.tomorrow,
    required this.thisWeek,
    required this.customRange,
    required this.startDate,
    required this.endDate,
    required this.taskStatus,
    required this.open,
    required this.completed,
    required this.taskDue,
    required this.anyDueState,
    required this.overdue,
    required this.noDueDate,
    required this.person,
    required this.location,
    required this.sources,
    required this.clearFilters,
    required this.noSources,
    required this.close,
    required this.cancel,
    required this.ok,
  });

  final String searchFilters;
  final String type;
  final String all;
  final String events;
  final String tasks;
  final String date;
  final String anyDate;
  final String today;
  final String tomorrow;
  final String thisWeek;
  final String customRange;
  final String startDate;
  final String endDate;
  final String taskStatus;
  final String open;
  final String completed;
  final String taskDue;
  final String anyDueState;
  final String overdue;
  final String noDueDate;
  final String person;
  final String location;
  final String sources;
  final String clearFilters;
  final String noSources;
  final String close;
  final String cancel;
  final String ok;

  Map<String, String> toJson() => <String, String>{
    'searchFilters': searchFilters,
    'type': type,
    'all': all,
    'events': events,
    'tasks': tasks,
    'date': date,
    'anyDate': anyDate,
    'today': today,
    'tomorrow': tomorrow,
    'thisWeek': thisWeek,
    'customRange': customRange,
    'startDate': startDate,
    'endDate': endDate,
    'taskStatus': taskStatus,
    'open': open,
    'completed': completed,
    'taskDue': taskDue,
    'anyDueState': anyDueState,
    'overdue': overdue,
    'noDueDate': noDueDate,
    'person': person,
    'location': location,
    'sources': sources,
    'clearFilters': clearFilters,
    'noSources': noSources,
    'close': close,
    'cancel': cancel,
    'ok': ok,
  };
}

@immutable
final class LinuxScheduleSearchFilterAccount {
  const LinuxScheduleSearchFilterAccount({
    required this.id,
    required this.label,
  });

  final String id;
  final String label;

  Map<String, String> toJson() => <String, String>{'id': id, 'label': label};
}

@immutable
final class LinuxScheduleSearchFilterCalendarSource {
  const LinuxScheduleSearchFilterCalendarSource({
    required this.id,
    required this.accountId,
    required this.title,
    required this.selected,
  });

  final String id;
  final String accountId;
  final String title;
  final bool selected;

  Map<String, Object> toJson() => <String, Object>{
    'id': id,
    'accountId': accountId,
    'title': title,
    'selected': selected,
  };
}

@immutable
final class LinuxScheduleSearchFilterTaskList {
  const LinuxScheduleSearchFilterTaskList({
    required this.accountId,
    required this.taskListId,
    required this.title,
    required this.selected,
  });

  final String accountId;
  final String taskListId;
  final String title;
  final bool selected;

  Map<String, Object> toJson() => <String, Object>{
    'accountId': accountId,
    'taskListId': taskListId,
    'title': title,
    'selected': selected,
  };
}

@immutable
final class LinuxScheduleSearchFilterState {
  const LinuxScheduleSearchFilterState({
    required this.active,
    required this.sidebarVisible,
    required this.sidebarWidth,
    required this.criteria,
    required this.labels,
    required this.accounts,
    required this.calendarSources,
    required this.taskLists,
  });

  static const int schemaVersion = 1;

  final bool active;
  final bool sidebarVisible;
  final double sidebarWidth;
  final ScheduleSearchCriteria? criteria;
  final LinuxScheduleSearchFilterLabels labels;
  final List<LinuxScheduleSearchFilterAccount> accounts;
  final List<LinuxScheduleSearchFilterCalendarSource> calendarSources;
  final List<LinuxScheduleSearchFilterTaskList> taskLists;

  Map<String, Object?> toJson() => <String, Object?>{
    'schemaVersion': schemaVersion,
    'active': active,
    'sidebarVisible': sidebarVisible,
    'sidebarWidth': sidebarWidth,
    'criteria': criteria == null ? null : _criteriaToJson(criteria!),
    'labels': labels.toJson(),
    'accounts': [for (final account in accounts) account.toJson()],
    'calendarSources': [for (final source in calendarSources) source.toJson()],
    'taskLists': [for (final taskList in taskLists) taskList.toJson()],
  };

  static Map<String, Object?> _criteriaToJson(
    ScheduleSearchCriteria criteria,
  ) => <String, Object?>{
    'type': criteria.type.name,
    'date': criteria.date.name,
    'taskCompletion': criteria.taskCompletion.name,
    'taskDueState': criteria.taskDueState.name,
    'person': criteria.person,
    'location': criteria.location,
    'customStart': _encodeDate(criteria.customStart),
    'customEnd': _encodeDate(criteria.customEnd),
    'referenceDate': _encodeDate(criteria.referenceDate),
    'firstWeekday': criteria.firstWeekday,
    'sourceIds': criteria.sourceIds.toList()..sort(),
    'taskListKeys':
        [
          for (final key in criteria.taskListKeys)
            <String, String>{
              'accountId': key.accountId,
              'taskListId': key.taskListId,
            },
        ]..sort((a, b) {
          final account = a['accountId']!.compareTo(b['accountId']!);
          return account != 0
              ? account
              : a['taskListId']!.compareTo(b['taskListId']!);
        }),
  };
}

String? _encodeDate(DateTime? value) {
  if (value == null) return null;
  String two(int part) => part.toString().padLeft(2, '0');
  return '${value.year.toString().padLeft(4, '0')}-${two(value.month)}-${two(value.day)}';
}

sealed class LinuxScheduleSearchFilterEvent {
  const LinuxScheduleSearchFilterEvent();
}

final class LinuxScheduleSearchTypeChanged
    extends LinuxScheduleSearchFilterEvent {
  const LinuxScheduleSearchTypeChanged(this.value);
  final ScheduleSearchType value;
}

final class LinuxScheduleSearchDateChanged
    extends LinuxScheduleSearchFilterEvent {
  const LinuxScheduleSearchDateChanged(this.value);
  final ScheduleSearchDate value;
}

final class LinuxScheduleSearchTaskCompletionChanged
    extends LinuxScheduleSearchFilterEvent {
  const LinuxScheduleSearchTaskCompletionChanged(this.value);
  final ScheduleTaskCompletion value;
}

final class LinuxScheduleSearchTaskDueStateChanged
    extends LinuxScheduleSearchFilterEvent {
  const LinuxScheduleSearchTaskDueStateChanged(this.value);
  final ScheduleTaskDueState value;
}

final class LinuxScheduleSearchPersonChanged
    extends LinuxScheduleSearchFilterEvent {
  const LinuxScheduleSearchPersonChanged(this.value);
  final String value;
}

final class LinuxScheduleSearchLocationChanged
    extends LinuxScheduleSearchFilterEvent {
  const LinuxScheduleSearchLocationChanged(this.value);
  final String value;
}

final class LinuxScheduleSearchCustomStartChanged
    extends LinuxScheduleSearchFilterEvent {
  const LinuxScheduleSearchCustomStartChanged(this.value);
  final DateTime value;
}

final class LinuxScheduleSearchCustomEndChanged
    extends LinuxScheduleSearchFilterEvent {
  const LinuxScheduleSearchCustomEndChanged(this.value);
  final DateTime value;
}

final class LinuxScheduleSearchCalendarSourceToggled
    extends LinuxScheduleSearchFilterEvent {
  const LinuxScheduleSearchCalendarSourceToggled({
    required this.sourceId,
    required this.selected,
  });
  final String sourceId;
  final bool selected;
}

final class LinuxScheduleSearchTaskListToggled
    extends LinuxScheduleSearchFilterEvent {
  const LinuxScheduleSearchTaskListToggled({
    required this.key,
    required this.selected,
  });
  final ScheduleTaskListKey key;
  final bool selected;
}

final class LinuxScheduleSearchClearRequested
    extends LinuxScheduleSearchFilterEvent {
  const LinuxScheduleSearchClearRequested();
}

final class LinuxScheduleSearchDismissRequested
    extends LinuxScheduleSearchFilterEvent {
  const LinuxScheduleSearchDismissRequested();
}

class LinuxScheduleSearchFilterService {
  LinuxScheduleSearchFilterService({
    MethodChannel channel = const MethodChannel(
      linuxScheduleSearchFilterChannelName,
    ),
    bool? isLinux,
  }) : _channel = channel,
       _isLinux = isLinux ?? Platform.isLinux;

  final MethodChannel _channel;
  final bool _isLinux;
  final List<LinuxScheduleSearchFilterSession> _sessions = [];
  Future<void>? _initialization;
  bool _available = false;
  bool _disposed = false;
  Map<String, Object?>? _appliedState;

  bool get isAvailable => _available;

  LinuxScheduleSearchFilterSession claimSession() {
    if (_disposed) {
      throw StateError('Cannot claim a session from a disposed service.');
    }
    final session = LinuxScheduleSearchFilterSession._(this);
    _sessions.add(session);
    return session;
  }

  Future<void> initialize() => _initialization ??= _initialize();

  Future<void> _initialize() async {
    if (_disposed) return;
    _channel.setMethodCallHandler(handleNativeMethodCall);
    if (!_isLinux) return;
    try {
      _available = await _channel.invokeMethod<bool>('initialize') ?? false;
    } on MissingPluginException {
      _available = false;
    } on PlatformException {
      _available = false;
    }
  }

  LinuxScheduleSearchFilterSession? get _activeSession =>
      _sessions.isEmpty ? null : _sessions.last;

  bool _isCurrent(LinuxScheduleSearchFilterSession session) =>
      identical(session, _activeSession);

  Future<void> _applyState(
    LinuxScheduleSearchFilterState state, {
    bool force = false,
  }) async {
    final serialized = state.toJson();
    if (!force &&
        const DeepCollectionEquality().equals(_appliedState, serialized)) {
      return;
    }
    _appliedState = serialized;
    await _invokeVoid('setState', serialized);
  }

  Future<bool> _showModal(LinuxScheduleSearchFilterSession session) async {
    if (!_available || !_isCurrent(session)) return false;
    try {
      return await _channel.invokeMethod<bool>('showModal') ?? false;
    } on MissingPluginException {
      _available = false;
    } on PlatformException {
      _available = false;
    }
    return false;
  }

  Future<void> _hideModal(LinuxScheduleSearchFilterSession session) async {
    if (!_available || !_isCurrent(session)) return;
    await _invokeVoid('hideModal');
  }

  Future<void> _invokeVoid(String method, [Object? arguments]) async {
    if (_disposed || !_available) return;
    try {
      await _channel.invokeMethod<void>(method, arguments);
    } on MissingPluginException {
      _available = false;
    } on PlatformException {
      _available = false;
    }
  }

  @visibleForTesting
  Future<void> handleNativeMethodCall(MethodCall call) async {
    if (_disposed || !_available) return;
    final event = _eventFor(call);
    if (event != null) _activeSession?._dispatch(event);
  }

  LinuxScheduleSearchFilterEvent? _eventFor(MethodCall call) {
    try {
      return switch ((call.method, call.arguments)) {
        ('typeChanged', final String value) => LinuxScheduleSearchTypeChanged(
          ScheduleSearchType.values.byName(value),
        ),
        ('dateChanged', final String value) => LinuxScheduleSearchDateChanged(
          ScheduleSearchDate.values.byName(value),
        ),
        ('taskCompletionChanged', final String value) =>
          LinuxScheduleSearchTaskCompletionChanged(
            ScheduleTaskCompletion.values.byName(value),
          ),
        ('taskDueStateChanged', final String value) =>
          LinuxScheduleSearchTaskDueStateChanged(
            ScheduleTaskDueState.values.byName(value),
          ),
        ('personChanged', final String value) =>
          LinuxScheduleSearchPersonChanged(value),
        ('locationChanged', final String value) =>
          LinuxScheduleSearchLocationChanged(value),
        ('customStartChanged', final String value) =>
          LinuxScheduleSearchCustomStartChanged(DateTime.parse(value)),
        ('customEndChanged', final String value) =>
          LinuxScheduleSearchCustomEndChanged(DateTime.parse(value)),
        ('calendarSourceToggled', final Map<Object?, Object?> value)
            when value['sourceId'] is String && value['selected'] is bool =>
          LinuxScheduleSearchCalendarSourceToggled(
            sourceId: value['sourceId']! as String,
            selected: value['selected']! as bool,
          ),
        ('taskListToggled', final Map<Object?, Object?> value)
            when value['accountId'] is String &&
                value['taskListId'] is String &&
                value['selected'] is bool =>
          LinuxScheduleSearchTaskListToggled(
            key: ScheduleTaskListKey(
              accountId: value['accountId']! as String,
              taskListId: value['taskListId']! as String,
            ),
            selected: value['selected']! as bool,
          ),
        ('clearFilters', _) => const LinuxScheduleSearchClearRequested(),
        ('dismissSearch', _) => const LinuxScheduleSearchDismissRequested(),
        _ => null,
      };
    } on ArgumentError {
      return null;
    } on FormatException {
      return null;
    }
  }

  void _release(LinuxScheduleSearchFilterSession session) {
    final wasCurrent = _isCurrent(session);
    _sessions.remove(session);
    if (!wasCurrent) return;
    final current = _activeSession;
    if (current != null) {
      unawaited(current._restore());
    } else {
      _appliedState = null;
      unawaited(_invokeVoid('hide'));
    }
  }

  void dispose() {
    if (_disposed) return;
    if (_available) unawaited(_invokeVoid('hide'));
    _disposed = true;
    _available = false;
    for (final session in _sessions.toList()) {
      session._disposeFromService();
    }
    _sessions.clear();
    _channel.setMethodCallHandler(null);
  }
}

class LinuxScheduleSearchFilterSession {
  LinuxScheduleSearchFilterSession._(this._service);

  final LinuxScheduleSearchFilterService _service;
  final StreamController<LinuxScheduleSearchFilterEvent> _events =
      StreamController<LinuxScheduleSearchFilterEvent>.broadcast();
  LinuxScheduleSearchFilterState? _state;
  int _revision = 0;
  bool _disposed = false;

  bool get isCurrent => !_disposed && _service._isCurrent(this);
  bool get isAvailable => !_disposed && _service.isAvailable;
  Stream<LinuxScheduleSearchFilterEvent> get events => _events.stream;

  Future<void> initialize() => _service.initialize();

  Future<void> updateState(
    LinuxScheduleSearchFilterState state, {
    bool force = false,
  }) async {
    if (_disposed) return;
    _state = state;
    final revision = ++_revision;
    await initialize();
    if (!isCurrent || revision != _revision) return;
    await _service._applyState(state, force: force);
  }

  Future<bool> showModal() async {
    if (_disposed) return false;
    await initialize();
    if (!isCurrent) return false;
    final state = _state;
    if (state != null) await _service._applyState(state, force: true);
    return _service._showModal(this);
  }

  Future<void> hideModal() => _service._hideModal(this);

  Future<void> _restore() async {
    await initialize();
    final state = _state;
    if (!isCurrent || state == null) return;
    await _service._applyState(state, force: true);
  }

  void _dispatch(LinuxScheduleSearchFilterEvent event) {
    if (isCurrent && !_events.isClosed) _events.add(event);
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _service._release(this);
    unawaited(_events.close());
  }

  void _disposeFromService() {
    if (_disposed) return;
    _disposed = true;
    unawaited(_events.close());
  }
}

final linuxScheduleSearchFilterServiceProvider =
    Provider<LinuxScheduleSearchFilterService>((ref) {
      final service = LinuxScheduleSearchFilterService();
      ref.onDispose(service.dispose);
      return service;
    });

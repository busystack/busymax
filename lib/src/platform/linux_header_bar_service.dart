import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../schedule/schedule_view_mode.dart';

enum BusyMaxHeaderBarAction {
  back,
  continueSetup,
  sidebarToggle,
  today,
  previous,
  next,
  viewModeDay,
  viewModeWeek,
  viewModeMonth,
  viewModeYear,
  viewModeAgenda,
  search,
  createEvent,
  createTask,
  refresh,
  settings,
  keyboardShortcuts,
  aboutBusyMax,
}

sealed class BusyMaxHeaderBarSearchEvent {
  const BusyMaxHeaderBarSearchEvent();
}

@immutable
final class BusyMaxHeaderBarSearchQueryChanged
    extends BusyMaxHeaderBarSearchEvent {
  const BusyMaxHeaderBarSearchQueryChanged(this.query);

  final String query;
}

@immutable
final class BusyMaxHeaderBarSearchFocusChanged
    extends BusyMaxHeaderBarSearchEvent {
  const BusyMaxHeaderBarSearchFocusChanged(this.focused);

  final bool focused;
}

@immutable
final class BusyMaxHeaderBarSearchCleared extends BusyMaxHeaderBarSearchEvent {
  const BusyMaxHeaderBarSearchCleared();
}

@immutable
final class BusyMaxHeaderBarSearchEscapePressed
    extends BusyMaxHeaderBarSearchEvent {
  const BusyMaxHeaderBarSearchEscapePressed();
}

@immutable
class BusyMaxHeaderBarLabels {
  const BusyMaxHeaderBarLabels({
    required this.today,
    required this.day,
    required this.week,
    required this.month,
    required this.year,
    required this.agenda,
    required this.search,
    required this.create,
    required this.createEvent,
    required this.createTask,
    required this.refresh,
    required this.menu,
    required this.previous,
    required this.next,
    required this.sidebar,
    required this.back,
    required this.settings,
    required this.keyboardShortcuts,
    required this.aboutBusyMax,
  });

  final String today;
  final String day;
  final String week;
  final String month;
  final String year;
  final String agenda;
  final String search;
  final String create;
  final String createEvent;
  final String createTask;
  final String refresh;
  final String menu;
  final String previous;
  final String next;
  final String sidebar;
  final String back;
  final String settings;
  final String keyboardShortcuts;
  final String aboutBusyMax;

  Map<String, String> toJson() {
    return {
      'today': today,
      'day': day,
      'week': week,
      'month': month,
      'year': year,
      'agenda': agenda,
      'search': search,
      'create': create,
      'createEvent': createEvent,
      'createTask': createTask,
      'refresh': refresh,
      'menu': menu,
      'previous': previous,
      'next': next,
      'sidebar': sidebar,
      'back': back,
      'settings': settings,
      'keyboardShortcuts': keyboardShortcuts,
      'aboutBusyMax': aboutBusyMax,
    };
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is BusyMaxHeaderBarLabels &&
            today == other.today &&
            day == other.day &&
            week == other.week &&
            month == other.month &&
            year == other.year &&
            agenda == other.agenda &&
            search == other.search &&
            create == other.create &&
            createEvent == other.createEvent &&
            createTask == other.createTask &&
            refresh == other.refresh &&
            menu == other.menu &&
            previous == other.previous &&
            next == other.next &&
            sidebar == other.sidebar &&
            back == other.back &&
            settings == other.settings &&
            keyboardShortcuts == other.keyboardShortcuts &&
            aboutBusyMax == other.aboutBusyMax;
  }

  @override
  int get hashCode => Object.hash(
    today,
    day,
    week,
    month,
    year,
    agenda,
    search,
    create,
    createEvent,
    createTask,
    refresh,
    menu,
    previous,
    next,
    sidebar,
    back,
    settings,
    keyboardShortcuts,
    aboutBusyMax,
  );
}

@immutable
class BusyMaxHeaderBarTheme {
  const BusyMaxHeaderBarTheme({
    required this.preferDark,
    required this.windowBackgroundColor,
    required this.backgroundColor,
    required this.sidebarBackgroundColor,
    required this.foregroundColor,
    required this.sidebarBorderColor,
    required this.modalBarrierColor,
  });

  final bool preferDark;
  final Color windowBackgroundColor;
  final Color backgroundColor;
  final Color sidebarBackgroundColor;
  final Color foregroundColor;
  final Color sidebarBorderColor;
  final Color modalBarrierColor;

  Map<String, Object> toJson() {
    return <String, Object>{
      'preferDark': preferDark,
      'windowBackgroundColor': busyMaxCssColor(windowBackgroundColor),
      'backgroundColor': busyMaxCssColor(backgroundColor),
      'sidebarBackgroundColor': busyMaxCssColor(sidebarBackgroundColor),
      'foregroundColor': busyMaxCssColor(foregroundColor),
      'sidebarBorderColor': busyMaxCssColor(sidebarBorderColor),
      'modalBarrierColor': busyMaxCssColor(modalBarrierColor),
    };
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is BusyMaxHeaderBarTheme &&
            other.preferDark == preferDark &&
            other.windowBackgroundColor == windowBackgroundColor &&
            other.backgroundColor == backgroundColor &&
            other.sidebarBackgroundColor == sidebarBackgroundColor &&
            other.foregroundColor == foregroundColor &&
            other.sidebarBorderColor == sidebarBorderColor &&
            other.modalBarrierColor == modalBarrierColor;
  }

  @override
  int get hashCode => Object.hash(
    preferDark,
    windowBackgroundColor,
    backgroundColor,
    sidebarBackgroundColor,
    foregroundColor,
    sidebarBorderColor,
    modalBarrierColor,
  );
}

/// The complete, screen-owned presentation state of the native header bar.
///
/// Configuration that is shared across screens, such as localized labels,
/// theme colors, and sidebar width, is intentionally managed separately.
@immutable
class BusyMaxHeaderBarState {
  const BusyMaxHeaderBarState({
    required this.title,
    required this.viewMode,
    required this.canRefresh,
    required this.canCreateEvent,
    required this.canCreateTask,
    required this.searchActive,
    required this.searchQuery,
    required this.canShowSidebar,
    required this.sidebarVisible,
    required this.navigationVisible,
    required this.scheduleControlsVisible,
    required this.backVisible,
  });

  static const int schemaVersion = 3;

  final String title;
  final ScheduleViewMode viewMode;
  final bool canRefresh;
  final bool canCreateEvent;
  final bool canCreateTask;
  final bool searchActive;
  final String searchQuery;

  bool get canCreate => canCreateEvent || canCreateTask;

  /// Whether the current layout can present a sidebar.
  ///
  /// This is distinct from [sidebarVisible], which represents the user's
  /// current expanded/collapsed choice when a sidebar can be presented.
  final bool canShowSidebar;
  final bool sidebarVisible;
  final bool navigationVisible;
  final bool scheduleControlsVisible;
  final bool backVisible;

  Map<String, Object> toJson() {
    return <String, Object>{
      'schemaVersion': schemaVersion,
      'title': title,
      'viewMode': viewMode.name,
      'canRefresh': canRefresh,
      'canCreateEvent': canCreateEvent,
      'canCreateTask': canCreateTask,
      'searchActive': searchActive,
      'searchQuery': searchQuery,
      'canShowSidebar': canShowSidebar,
      'sidebarVisible': sidebarVisible,
      'navigationVisible': navigationVisible,
      'scheduleControlsVisible': scheduleControlsVisible,
      'backVisible': backVisible,
    };
  }

  BusyMaxHeaderBarState copyWith({
    String? title,
    ScheduleViewMode? viewMode,
    bool? canRefresh,
    bool? canCreateEvent,
    bool? canCreateTask,
    bool? searchActive,
    String? searchQuery,
    bool? canShowSidebar,
    bool? sidebarVisible,
    bool? navigationVisible,
    bool? scheduleControlsVisible,
    bool? backVisible,
  }) {
    return BusyMaxHeaderBarState(
      title: title ?? this.title,
      viewMode: viewMode ?? this.viewMode,
      canRefresh: canRefresh ?? this.canRefresh,
      canCreateEvent: canCreateEvent ?? this.canCreateEvent,
      canCreateTask: canCreateTask ?? this.canCreateTask,
      searchActive: searchActive ?? this.searchActive,
      searchQuery: searchQuery ?? this.searchQuery,
      canShowSidebar: canShowSidebar ?? this.canShowSidebar,
      sidebarVisible: sidebarVisible ?? this.sidebarVisible,
      navigationVisible: navigationVisible ?? this.navigationVisible,
      scheduleControlsVisible:
          scheduleControlsVisible ?? this.scheduleControlsVisible,
      backVisible: backVisible ?? this.backVisible,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is BusyMaxHeaderBarState &&
            title == other.title &&
            viewMode == other.viewMode &&
            canRefresh == other.canRefresh &&
            canCreateEvent == other.canCreateEvent &&
            canCreateTask == other.canCreateTask &&
            searchActive == other.searchActive &&
            searchQuery == other.searchQuery &&
            canShowSidebar == other.canShowSidebar &&
            sidebarVisible == other.sidebarVisible &&
            navigationVisible == other.navigationVisible &&
            scheduleControlsVisible == other.scheduleControlsVisible &&
            backVisible == other.backVisible;
  }

  @override
  int get hashCode => Object.hash(
    title,
    viewMode,
    canRefresh,
    canCreateEvent,
    canCreateTask,
    searchActive,
    searchQuery,
    canShowSidebar,
    sidebarVisible,
    navigationVisible,
    scheduleControlsVisible,
    backVisible,
  );
}

class LinuxHeaderBarService {
  LinuxHeaderBarService({
    MethodChannel channel = const MethodChannel(
      'io.busystack.busymax/headerbar',
    ),
    bool? isLinux,
  }) : _channel = channel,
       _isLinux = isLinux ?? Platform.isLinux;

  final MethodChannel _channel;
  final bool _isLinux;
  final _sessions = <LinuxHeaderBarSession>[];

  Future<void>? _initialization;
  bool _available = false;
  bool _disposed = false;
  _BusyMaxOnboardingControlsState? _onboardingControls;
  bool? _modalBarrierVisible;
  double? _sidebarWidth;
  BusyMaxHeaderBarLabels? _labels;
  BusyMaxHeaderBarTheme? _theme;
  BusyMaxHeaderBarState? _state;

  bool get isAvailable => _available;

  /// Returns a route-owned session for native header state and actions.
  ///
  /// Claiming a new session immediately supersedes the previous one. This is
  /// important during route transitions, when the outgoing screen remains
  /// mounted and can still receive asynchronous rebuilds.
  LinuxHeaderBarSession claimSession() {
    if (_disposed) {
      throw StateError('Cannot claim a session from a disposed service.');
    }
    final session = LinuxHeaderBarSession._(this);
    _sessions.add(session);
    return session;
  }

  /// Initializes the native bridge once and shares the in-flight result.
  Future<void> initialize() {
    return _initialization ??= _initialize();
  }

  Future<void> _initialize() async {
    if (_disposed) {
      return;
    }
    _channel.setMethodCallHandler(handleNativeMethodCall);
    if (!_isLinux) {
      _available = false;
      return;
    }
    try {
      final available =
          await _channel.invokeMethod<bool>('initialize') ?? false;
      if (!_disposed) {
        _available = available;
      }
    } on MissingPluginException {
      if (!_disposed) {
        _available = false;
      }
    } on PlatformException {
      if (!_disposed) {
        _available = false;
      }
    }
  }

  /// Applies all screen-owned header state in one native transaction.
  ///
  /// Equal state is not sent twice. Session ownership is checked before this
  /// method is called so inactive routes cannot mutate the native-state cache.
  Future<void> _applyState(
    BusyMaxHeaderBarState state, {
    bool force = false,
  }) async {
    if (!_available) {
      return;
    }
    if (!force && _state == state) {
      return;
    }
    _state = state;
    await _invokeIfAvailable('setState', state.toJson());
  }

  Future<void> setLocalizedLabels(BusyMaxHeaderBarLabels labels) async {
    if (!_available) {
      return;
    }
    if (_labels == labels) {
      return;
    }
    _labels = labels;
    await _invokeIfAvailable('setLocalizedLabels', labels.toJson());
  }

  Future<void> setSidebarWidth(double value) async {
    if (!_available) {
      return;
    }
    if (_sidebarWidth == value) {
      return;
    }
    _sidebarWidth = value;
    await _invokeIfAvailable('setSidebarWidth', value);
  }

  Future<void> _setOnboardingControls({
    required bool visible,
    required bool canGoBack,
    required bool canContinue,
    required String backLabel,
    required String continueLabel,
    bool force = false,
  }) async {
    if (!_available) {
      return;
    }
    final state = _BusyMaxOnboardingControlsState(
      visible: visible,
      canGoBack: canGoBack,
      canContinue: canContinue,
      backLabel: backLabel,
      continueLabel: continueLabel,
    );
    if (!force && _onboardingControls == state) {
      return;
    }
    _onboardingControls = state;
    await _invokeIfAvailable('setOnboardingControls', state.toJson());
  }

  LinuxHeaderBarSession? get _activeSession {
    return _sessions.isEmpty ? null : _sessions.last;
  }

  bool _isCurrentSession(LinuxHeaderBarSession session) {
    return identical(_activeSession, session);
  }

  void _releaseSession(LinuxHeaderBarSession session) {
    final wasActive = _isCurrentSession(session);
    _sessions.remove(session);
    if (wasActive) {
      final activeSession = _activeSession;
      if (activeSession != null) {
        unawaited(activeSession._restore());
      }
    }
  }

  Future<void> setModalBarrierVisible(bool value) async {
    if (!_available) {
      return;
    }
    if (_modalBarrierVisible == value) {
      return;
    }
    _modalBarrierVisible = value;
    await _invokeIfAvailable('setModalBarrierVisible', value);
  }

  Future<void> setTheme(BusyMaxHeaderBarTheme theme) async {
    if (!_available) {
      return;
    }
    if (_theme == theme) {
      return;
    }
    _theme = theme;
    await _invokeIfAvailable('setTheme', theme.toJson());
  }

  @visibleForTesting
  Future<dynamic> handleNativeMethodCall(MethodCall call) async {
    final searchEvent = _searchEventForCall(call);
    if (searchEvent != null) {
      _activeSession?._dispatchSearchEvent(searchEvent);
      return null;
    }
    final action = _actionForMethod(call.method);
    if (action != null) {
      _activeSession?._dispatch(action);
    }
    return null;
  }

  Future<void> _invokeIfAvailable(String method, Object? arguments) async {
    if (_disposed || !_available) {
      return;
    }
    try {
      await _channel.invokeMethod<void>(method, arguments);
    } on MissingPluginException {
      _available = false;
    } on PlatformException {
      _available = false;
    }
  }

  Future<bool> _showCreateMenu(LinuxHeaderBarSession session) async {
    if (_disposed || !_available || !_isCurrentSession(session)) {
      return false;
    }
    try {
      return await _channel.invokeMethod<bool>('showCreateMenu') ?? false;
    } on MissingPluginException {
      _available = false;
    } on PlatformException {
      _available = false;
    }
    return false;
  }

  Future<bool> _focusSearch(LinuxHeaderBarSession session) async {
    if (_disposed || !_available || !_isCurrentSession(session)) {
      return false;
    }
    try {
      return await _channel.invokeMethod<bool>('focusSearch') ?? false;
    } on MissingPluginException {
      _available = false;
    } on PlatformException {
      _available = false;
    }
    return false;
  }

  BusyMaxHeaderBarSearchEvent? _searchEventForCall(MethodCall call) {
    return switch ((call.method, call.arguments)) {
      ('searchQueryChanged', final String query) =>
        BusyMaxHeaderBarSearchQueryChanged(query),
      ('searchFocusChanged', final bool focused) =>
        BusyMaxHeaderBarSearchFocusChanged(focused),
      ('searchCleared', _) => const BusyMaxHeaderBarSearchCleared(),
      ('searchEscapePressed', _) => const BusyMaxHeaderBarSearchEscapePressed(),
      _ => null,
    };
  }

  BusyMaxHeaderBarAction? _actionForMethod(String method) {
    return switch (method) {
      'back' => BusyMaxHeaderBarAction.back,
      'continueSetup' => BusyMaxHeaderBarAction.continueSetup,
      'sidebarToggle' => BusyMaxHeaderBarAction.sidebarToggle,
      'today' => BusyMaxHeaderBarAction.today,
      'previous' => BusyMaxHeaderBarAction.previous,
      'next' => BusyMaxHeaderBarAction.next,
      'viewModeDay' => BusyMaxHeaderBarAction.viewModeDay,
      'viewModeWeek' => BusyMaxHeaderBarAction.viewModeWeek,
      'viewModeMonth' => BusyMaxHeaderBarAction.viewModeMonth,
      'viewModeYear' => BusyMaxHeaderBarAction.viewModeYear,
      'viewModeAgenda' => BusyMaxHeaderBarAction.viewModeAgenda,
      'search' => BusyMaxHeaderBarAction.search,
      'createEvent' => BusyMaxHeaderBarAction.createEvent,
      'createTask' => BusyMaxHeaderBarAction.createTask,
      'refresh' => BusyMaxHeaderBarAction.refresh,
      'settings' => BusyMaxHeaderBarAction.settings,
      'keyboardShortcuts' => BusyMaxHeaderBarAction.keyboardShortcuts,
      'aboutBusyMax' => BusyMaxHeaderBarAction.aboutBusyMax,
      _ => null,
    };
  }

  void dispose() {
    if (_disposed) {
      return;
    }
    _disposed = true;
    _available = false;
    for (final session in _sessions.toList()) {
      session._disposeFromService();
    }
    _sessions.clear();
    _channel.setMethodCallHandler(null);
  }
}

/// Exclusive route-level access to native header state and actions.
///
/// Global concerns such as theme, labels, and modal barriers remain on
/// [LinuxHeaderBarService]. Route presentation state goes through this session
/// so that a transitioning-out screen cannot overwrite its successor.
class LinuxHeaderBarSession {
  LinuxHeaderBarSession._(this._service);

  final LinuxHeaderBarService _service;
  final _actions = StreamController<BusyMaxHeaderBarAction>.broadcast();
  final _searchEvents =
      StreamController<BusyMaxHeaderBarSearchEvent>.broadcast();
  bool _disposed = false;
  BusyMaxHeaderBarState? _state;
  int _stateRevision = 0;
  _BusyMaxOnboardingControlsState? _onboardingControls;
  int _onboardingRevision = 0;

  bool get isCurrent => !_disposed && _service._isCurrentSession(this);

  bool get isAvailable => !_disposed && _service.isAvailable;

  Stream<BusyMaxHeaderBarAction> get actions => _actions.stream;

  Stream<BusyMaxHeaderBarSearchEvent> get searchEvents => _searchEvents.stream;

  Future<void> initialize() => _service.initialize();

  Future<void> updateState(
    BusyMaxHeaderBarState state, {
    bool force = false,
  }) async {
    if (_disposed) {
      return;
    }
    _state = state;
    final revision = ++_stateRevision;
    await initialize();
    if (!isCurrent || revision != _stateRevision) {
      return;
    }
    await _service._applyState(state, force: force);
  }

  /// Opens the route-owned native Create popover when it is available.
  ///
  /// The current-session check prevents an outgoing route from opening UI in
  /// a header that has already been claimed by its successor.
  Future<bool> showCreateMenu() async {
    if (_disposed) {
      return false;
    }
    await initialize();
    if (!isCurrent) {
      return false;
    }
    return _service._showCreateMenu(this);
  }

  /// Focuses the route-owned native search entry when it is active.
  Future<bool> focusSearch() async {
    if (_disposed) {
      return false;
    }
    await initialize();
    if (!isCurrent) {
      return false;
    }
    return _service._focusSearch(this);
  }

  Future<void> setOnboardingControls({
    required bool visible,
    required bool canGoBack,
    required bool canContinue,
    required String backLabel,
    required String continueLabel,
    bool force = false,
  }) async {
    if (_disposed) {
      return;
    }
    final state = _BusyMaxOnboardingControlsState(
      visible: visible,
      canGoBack: canGoBack,
      canContinue: canContinue,
      backLabel: backLabel,
      continueLabel: continueLabel,
    );
    _onboardingControls = state;
    final revision = ++_onboardingRevision;
    await initialize();
    if (!isCurrent || revision != _onboardingRevision) {
      return;
    }
    await _service._setOnboardingControls(
      visible: state.visible,
      canGoBack: state.canGoBack,
      canContinue: state.canContinue,
      backLabel: state.backLabel,
      continueLabel: state.continueLabel,
      force: force,
    );
  }

  Future<void> _restore() async {
    await initialize();
    if (!isCurrent) {
      return;
    }
    final state = _state;
    if (state != null) {
      await _service._applyState(state, force: true);
    }
    if (!isCurrent) {
      return;
    }
    final onboardingControls = _onboardingControls;
    if (onboardingControls != null) {
      await _service._setOnboardingControls(
        visible: onboardingControls.visible,
        canGoBack: onboardingControls.canGoBack,
        canContinue: onboardingControls.canContinue,
        backLabel: onboardingControls.backLabel,
        continueLabel: onboardingControls.continueLabel,
        force: true,
      );
    }
  }

  void _dispatch(BusyMaxHeaderBarAction action) {
    if (isCurrent && !_actions.isClosed) {
      _actions.add(action);
    }
  }

  void _dispatchSearchEvent(BusyMaxHeaderBarSearchEvent event) {
    if (isCurrent && !_searchEvents.isClosed) {
      _searchEvents.add(event);
    }
  }

  void dispose() {
    if (_disposed) {
      return;
    }
    _disposed = true;
    _service._releaseSession(this);
    unawaited(_actions.close());
    unawaited(_searchEvents.close());
  }

  void _disposeFromService() {
    if (_disposed) {
      return;
    }
    _disposed = true;
    unawaited(_actions.close());
    unawaited(_searchEvents.close());
  }
}

@immutable
class _BusyMaxOnboardingControlsState {
  const _BusyMaxOnboardingControlsState({
    required this.visible,
    required this.canGoBack,
    required this.canContinue,
    required this.backLabel,
    required this.continueLabel,
  });

  final bool visible;
  final bool canGoBack;
  final bool canContinue;
  final String backLabel;
  final String continueLabel;

  Map<String, Object?> toJson() {
    return {
      'visible': visible,
      'canGoBack': canGoBack,
      'canContinue': canContinue,
      'backLabel': backLabel,
      'continueLabel': continueLabel,
    };
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is _BusyMaxOnboardingControlsState &&
            visible == other.visible &&
            canGoBack == other.canGoBack &&
            canContinue == other.canContinue &&
            backLabel == other.backLabel &&
            continueLabel == other.continueLabel;
  }

  @override
  int get hashCode =>
      Object.hash(visible, canGoBack, canContinue, backLabel, continueLabel);
}

@visibleForTesting
String busyMaxCssColor(Color color) {
  final rgb = color.toARGB32() & 0x00ffffff;
  if (color.a >= 1) {
    return '#${rgb.toRadixString(16).padLeft(6, '0').toUpperCase()}';
  }
  final red = (rgb >> 16) & 0xff;
  final green = (rgb >> 8) & 0xff;
  final blue = rgb & 0xff;
  return 'rgba($red,$green,$blue,${color.a.toStringAsFixed(2)})';
}

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
  create,
  refresh,
  settings,
  keyboardShortcuts,
  aboutBusyMax,
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
    required this.mutedForegroundColor,
    required this.disabledForegroundColor,
    required this.controlColor,
    required this.controlHoverColor,
    required this.controlActiveColor,
    required this.accentColor,
    required this.accentForegroundColor,
    required this.popoverBackgroundColor,
    required this.borderColor,
    required this.shadeColor,
    required this.modalBarrierColor,
  });

  final bool preferDark;
  final Color windowBackgroundColor;
  final Color backgroundColor;
  final Color sidebarBackgroundColor;
  final Color foregroundColor;
  final Color mutedForegroundColor;
  final Color disabledForegroundColor;
  final Color controlColor;
  final Color controlHoverColor;
  final Color controlActiveColor;
  final Color accentColor;
  final Color accentForegroundColor;
  final Color popoverBackgroundColor;
  final Color borderColor;
  final Color shadeColor;
  final Color modalBarrierColor;

  Map<String, Object> toJson() {
    return <String, Object>{
      'preferDark': preferDark,
      'windowBackgroundColor': busyMaxCssColor(windowBackgroundColor),
      'backgroundColor': busyMaxCssColor(backgroundColor),
      'sidebarBackgroundColor': busyMaxCssColor(sidebarBackgroundColor),
      'foregroundColor': busyMaxCssColor(foregroundColor),
      'mutedForegroundColor': busyMaxCssColor(mutedForegroundColor),
      'disabledForegroundColor': busyMaxCssColor(disabledForegroundColor),
      'controlColor': busyMaxCssColor(controlColor),
      'controlHoverColor': busyMaxCssColor(controlHoverColor),
      'controlActiveColor': busyMaxCssColor(controlActiveColor),
      'accentColor': busyMaxCssColor(accentColor),
      'accentForegroundColor': busyMaxCssColor(accentForegroundColor),
      'popoverBackgroundColor': busyMaxCssColor(popoverBackgroundColor),
      'borderColor': busyMaxCssColor(borderColor),
      'shadeColor': busyMaxCssColor(shadeColor),
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
            other.mutedForegroundColor == mutedForegroundColor &&
            other.disabledForegroundColor == disabledForegroundColor &&
            other.controlColor == controlColor &&
            other.controlHoverColor == controlHoverColor &&
            other.controlActiveColor == controlActiveColor &&
            other.accentColor == accentColor &&
            other.accentForegroundColor == accentForegroundColor &&
            other.popoverBackgroundColor == popoverBackgroundColor &&
            other.borderColor == borderColor &&
            other.shadeColor == shadeColor &&
            other.modalBarrierColor == modalBarrierColor;
  }

  @override
  int get hashCode => Object.hash(
    preferDark,
    windowBackgroundColor,
    backgroundColor,
    sidebarBackgroundColor,
    foregroundColor,
    mutedForegroundColor,
    disabledForegroundColor,
    controlColor,
    controlHoverColor,
    controlActiveColor,
    accentColor,
    accentForegroundColor,
    popoverBackgroundColor,
    borderColor,
    shadeColor,
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
    required this.canCreate,
    required this.searchActive,
    required this.canShowSidebar,
    required this.sidebarVisible,
    required this.navigationVisible,
    required this.scheduleControlsVisible,
    required this.backVisible,
  });

  static const int schemaVersion = 1;

  final String title;
  final ScheduleViewMode viewMode;
  final bool canRefresh;
  final bool canCreate;
  final bool searchActive;

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
      'canCreate': canCreate,
      'searchActive': searchActive,
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
    bool? canCreate,
    bool? searchActive,
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
      canCreate: canCreate ?? this.canCreate,
      searchActive: searchActive ?? this.searchActive,
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
            canCreate == other.canCreate &&
            searchActive == other.searchActive &&
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
    canCreate,
    searchActive,
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
  final _actions = StreamController<BusyMaxHeaderBarAction>.broadcast();

  bool _initialized = false;
  bool _available = false;
  String? _titleRange;
  ScheduleViewMode? _viewMode;
  bool? _canRefresh;
  bool? _canCreate;
  bool? _searchActive;
  bool? _canShowSidebar;
  bool? _sidebarVisible;
  bool? _navigationVisible;
  bool? _scheduleControlsVisible;
  bool? _backVisible;
  _BusyMaxOnboardingControlsState? _onboardingControls;
  bool? _modalBarrierVisible;
  double? _sidebarWidth;
  BusyMaxHeaderBarLabels? _labels;
  BusyMaxHeaderBarTheme? _theme;
  BusyMaxHeaderBarState? _state;

  bool get isAvailable => _available;

  Stream<BusyMaxHeaderBarAction> get actions => _actions.stream;

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }
    _initialized = true;
    _channel.setMethodCallHandler(handleNativeMethodCall);
    if (!_isLinux) {
      _available = false;
      return;
    }
    try {
      _available = await _channel.invokeMethod<bool>('initialize') ?? false;
    } on MissingPluginException {
      _available = false;
    }
  }

  /// Applies all screen-owned header state in one native transaction.
  ///
  /// Equal state is not sent twice. Set [force] when the native widgets may
  /// have been recreated independently of this service instance.
  Future<void> updateState(
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
    _titleRange = state.title;
    _viewMode = state.viewMode;
    _canRefresh = state.canRefresh;
    _canCreate = state.canCreate;
    _searchActive = state.searchActive;
    _canShowSidebar = state.canShowSidebar;
    _sidebarVisible = state.sidebarVisible;
    _navigationVisible = state.navigationVisible;
    _scheduleControlsVisible = state.scheduleControlsVisible;
    _backVisible = state.backVisible;
    await _invokeIfAvailable('setState', state.toJson());
  }

  Future<void> setTitleRange(String value) async {
    if (!_available) {
      return;
    }
    if (_titleRange == value) {
      return;
    }
    _state = null;
    _titleRange = value;
    await _invokeIfAvailable('setTitleRange', value);
  }

  Future<void> setViewMode(ScheduleViewMode mode) async {
    if (!_available) {
      return;
    }
    if (_viewMode == mode) {
      return;
    }
    _state = null;
    _viewMode = mode;
    await _invokeIfAvailable('setViewMode', mode.name);
  }

  Future<void> setCanRefresh(bool value) async {
    if (!_available) {
      return;
    }
    if (_canRefresh == value) {
      return;
    }
    _state = null;
    _canRefresh = value;
    await _invokeIfAvailable('setCanRefresh', value);
  }

  Future<void> setCanCreate(bool value) async {
    if (!_available) {
      return;
    }
    if (_canCreate == value) {
      return;
    }
    _state = null;
    _canCreate = value;
    await _invokeIfAvailable('setCanCreate', value);
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

  Future<void> setSearchActive(bool value) async {
    if (!_available) {
      return;
    }
    if (_searchActive == value) {
      return;
    }
    _state = null;
    _searchActive = value;
    await _invokeIfAvailable('setSearchActive', value);
  }

  /// Sets whether the current layout can present a sidebar.
  ///
  /// Prefer [updateState] for screen transitions. This compatibility method
  /// exists for callers that have not migrated to the atomic state contract.
  Future<void> setCanShowSidebar(bool value) async {
    if (!_available) {
      return;
    }
    if (_canShowSidebar == value) {
      return;
    }
    _state = null;
    _canShowSidebar = value;
    await _invokeIfAvailable('setCanShowSidebar', value);
  }

  Future<void> setSidebarVisible(bool value) async {
    if (!_available) {
      return;
    }
    final restoresSidebarAvailability = value && _canShowSidebar == false;
    if (_sidebarVisible == value && !restoresSidebarAvailability) {
      return;
    }
    _state = null;
    if (value) {
      // Preserve the legacy contract: requesting a visible sidebar also makes
      // its native toggle available. Atomic callers should set both fields.
      _canShowSidebar = true;
    }
    _sidebarVisible = value;
    await _invokeIfAvailable('setSidebarVisible', value);
  }

  Future<void> setNavigationVisible(bool value) async {
    if (!_available) {
      return;
    }
    if (_navigationVisible == value) {
      return;
    }
    _state = null;
    _navigationVisible = value;
    await _invokeIfAvailable('setNavigationVisible', value);
  }

  Future<void> setScheduleControlsVisible(bool value) async {
    if (!_available) {
      return;
    }
    if (_scheduleControlsVisible == value) {
      return;
    }
    _state = null;
    _scheduleControlsVisible = value;
    await _invokeIfAvailable('setScheduleControlsVisible', value);
  }

  Future<void> setBackVisible(bool value) async {
    if (!_available) {
      return;
    }
    if (_backVisible == value) {
      return;
    }
    _state = null;
    _backVisible = value;
    await _invokeIfAvailable('setBackVisible', value);
  }

  Future<void> setOnboardingControls({
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
    final action = _actionForMethod(call.method);
    if (action != null && !_actions.isClosed) {
      _actions.add(action);
    }
    return null;
  }

  Future<void> _invokeIfAvailable(String method, Object? arguments) async {
    if (!_available) {
      return;
    }
    try {
      await _channel.invokeMethod<void>(method, arguments);
    } on MissingPluginException {
      _available = false;
    }
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
      'create' => BusyMaxHeaderBarAction.create,
      'refresh' => BusyMaxHeaderBarAction.refresh,
      'settings' => BusyMaxHeaderBarAction.settings,
      'keyboardShortcuts' => BusyMaxHeaderBarAction.keyboardShortcuts,
      'aboutBusyMax' => BusyMaxHeaderBarAction.aboutBusyMax,
      _ => null,
    };
  }

  void dispose() {
    _channel.setMethodCallHandler(null);
    unawaited(_actions.close());
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

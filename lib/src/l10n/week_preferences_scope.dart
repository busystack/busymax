import 'dart:async';

import 'package:flutter/widgets.dart';

import 'first_day_of_week.dart';
import 'l10n.dart';
import 'localized_formatters.dart';

export 'first_day_of_week.dart';

/// Injectable boundary for platform-specific regional settings.
abstract interface class BusyMaxSystemFirstWeekdaySource {
  Future<int?> read();

  Stream<void> get changes;

  void dispose();
}

abstract base class BusyMaxSystemFirstWeekdaySourceBase
    implements BusyMaxSystemFirstWeekdaySource {
  const BusyMaxSystemFirstWeekdaySourceBase();

  @override
  Stream<void> get changes => const Stream<void>.empty();

  @override
  void dispose() {}
}

/// Application-lifetime owner of native refreshes and lifecycle observation.
class BusyMaxSystemFirstWeekdayController extends ValueNotifier<int?>
    with WidgetsBindingObserver {
  BusyMaxSystemFirstWeekdayController(this._source) : super(null) {
    WidgetsBinding.instance.addObserver(this);
    _subscription = _source.changes.listen(
      (_) => unawaited(refresh()),
      onError: (Object _) {},
    );
    unawaited(refresh());
  }

  final BusyMaxSystemFirstWeekdaySource _source;
  StreamSubscription<void>? _subscription;
  var _refreshSequence = 0;
  var _disposed = false;

  Future<void> refresh() async {
    final sequence = ++_refreshSequence;
    int? result;
    try {
      result = await _source.read();
    } on Object {
      result = null;
    }
    if (_disposed || sequence != _refreshSequence) return;
    value = isValidBusyMaxWeekday(result) ? result : null;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(refresh());
  }

  @override
  void didChangeLocales(List<Locale>? locales) => unawaited(refresh());

  @override
  void dispose() {
    _disposed = true;
    _refreshSequence++;
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_subscription?.cancel());
    _source.dispose();
    super.dispose();
  }
}

/// Place above the navigator so routes and overlays share one effective value.
class BusyMaxWeekPreferencesScope extends InheritedWidget {
  const BusyMaxWeekPreferencesScope({
    required this.preference,
    required this.systemWeekday,
    required this.platformLocaleTag,
    required super.child,
    super.key,
  });

  final BusyMaxFirstDayOfWeekPreference preference;
  final int? systemWeekday;
  final String? platformLocaleTag;

  int get firstWeekday => resolveBusyMaxFirstWeekday(
    preference: preference,
    systemWeekday: systemWeekday,
    platformLocaleTag: platformLocaleTag,
  );

  static BusyMaxWeekPreferencesScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<BusyMaxWeekPreferencesScope>();

  static BusyMaxWeekPreferencesScope of(BuildContext context) {
    final scope = maybeOf(context);
    return scope ??
        BusyMaxWeekPreferencesScope(
          preference: BusyMaxFirstDayOfWeekPreference.system,
          systemWeekday: null,
          platformLocaleTag: WidgetsBinding.instance.platformDispatcher.locale
              .toLanguageTag(),
          child: const SizedBox.shrink(),
        );
  }

  static int firstWeekdayOf(BuildContext context) => of(context).firstWeekday;

  @override
  bool updateShouldNotify(BusyMaxWeekPreferencesScope oldWidget) =>
      oldWidget.preference != preference ||
      oldWidget.systemWeekday != systemWeekday ||
      oldWidget.platformLocaleTag != platformLocaleTag;
}

String busyMaxFirstDayOfWeekPreferenceLabel(
  BuildContext context,
  BusyMaxFirstDayOfWeekPreference preference,
) {
  final effective =
      preference.weekday ?? BusyMaxWeekPreferencesScope.firstWeekdayOf(context);
  final locale = Localizations.localeOf(context).toLanguageTag();
  final weekday = localizedWeekdayLabel(
    locale,
    DateTime(2026, DateTime.january, 5 + effective - DateTime.monday),
  );
  return preference == BusyMaxFirstDayOfWeekPreference.system
      ? context.l10n.systemDefaultResolved(weekday)
      : weekday;
}

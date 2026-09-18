import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

final _busyMaxDateSymbols = dateTimeSymbolMap();

/// The device-local BusyMax calendar-column preference.
///
/// Enum names are persisted, so they must remain stable.
enum BusyMaxFirstDayOfWeekPreference {
  system,
  monday,
  tuesday,
  wednesday,
  thursday,
  friday,
  saturday,
  sunday;

  int? get weekday => switch (this) {
    system => null,
    monday => DateTime.monday,
    tuesday => DateTime.tuesday,
    wednesday => DateTime.wednesday,
    thursday => DateTime.thursday,
    friday => DateTime.friday,
    saturday => DateTime.saturday,
    sunday => DateTime.sunday,
  };
}

bool isValidBusyMaxWeekday(int? value) =>
    value != null && value >= DateTime.monday && value <= DateTime.sunday;

/// Resolves a saved preference without involving BusyMax's translation locale.
///
/// [platformLocaleTag] must describe the platform formatting locale. A native
/// result wins over locale data because it can include an OS-level override.
int resolveBusyMaxFirstWeekday({
  required BusyMaxFirstDayOfWeekPreference preference,
  required int? systemWeekday,
  required String? platformLocaleTag,
}) {
  final explicit = preference.weekday;
  if (explicit != null) return explicit;
  if (isValidBusyMaxWeekday(systemWeekday)) return systemWeekday!;
  return busyMaxFirstWeekdayFromLocale(platformLocaleTag) ?? DateTime.monday;
}

/// Reads a Unicode `fw` override and then CLDR data supplied by `intl`.
int? busyMaxFirstWeekdayFromLocale(String? localeTag) {
  final trimmed = localeTag?.trim();
  if (trimmed == null || trimmed.isEmpty) return null;

  final override = _unicodeFirstWeekday(trimmed);
  if (override != null) return override;

  final withoutExtensions = trimmed.split(RegExp('[-_]u[-_]')).first;
  final canonical = Intl.canonicalizedLocale(withoutExtensions);
  final symbols = _busyMaxDateSymbols;
  final parts = canonical.split('_');
  final candidates = <String>[
    canonical,
    if (parts.length >= 3) '${parts[0]}_${parts.last}',
    if (parts.length >= 2) parts.first,
  ];
  for (final candidate in candidates) {
    final firstFromMonday = symbols[candidate]?.FIRSTDAYOFWEEK;
    if (firstFromMonday != null &&
        firstFromMonday >= 0 &&
        firstFromMonday < DateTime.daysPerWeek) {
      return firstFromMonday + DateTime.monday;
    }
  }
  return null;
}

int? _unicodeFirstWeekday(String localeTag) {
  final parts = localeTag.toLowerCase().split(RegExp('[-_]'));
  final unicode = parts.indexOf('u');
  if (unicode < 0) return null;
  for (var index = unicode + 1; index + 1 < parts.length; index++) {
    if (parts[index] != 'fw') continue;
    return switch (parts[index + 1]) {
      'mon' => DateTime.monday,
      'tue' => DateTime.tuesday,
      'wed' => DateTime.wednesday,
      'thu' => DateTime.thursday,
      'fri' => DateTime.friday,
      'sat' => DateTime.saturday,
      'sun' => DateTime.sunday,
      _ => null,
    };
  }
  return null;
}

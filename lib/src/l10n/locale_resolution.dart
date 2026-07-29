import 'package:flutter/widgets.dart';

const _traditionalChineseRegions = {'HK', 'MO', 'TW'};
const _simplifiedChineseRegions = {'CN', 'MY', 'SG'};

Locale resolveBusyMaxLocale(
  Locale? requestedLocale,
  Iterable<Locale> supportedLocales,
) {
  final supported = supportedLocales.toList(growable: false);
  final english =
      _firstMatching(supported, (locale) => locale.languageCode == 'en') ??
      (supported.isNotEmpty ? supported.first : const Locale('en'));

  if (requestedLocale == null) {
    return english;
  }

  final exact = _firstMatching(
    supported,
    (locale) => locale == requestedLocale,
  );
  if (exact != null) {
    return exact;
  }

  if (requestedLocale.languageCode == 'zh') {
    final scriptCode =
        requestedLocale.scriptCode ??
        _chineseScriptForRegion(requestedLocale.countryCode);
    if (scriptCode != null) {
      final scriptMatch = _firstMatching(
        supported,
        (locale) =>
            locale.languageCode == 'zh' && locale.scriptCode == scriptCode,
      );
      if (scriptMatch != null) {
        return scriptMatch;
      }
    }
  }

  return _firstMatching(
        supported,
        (locale) =>
            locale.languageCode == requestedLocale.languageCode &&
            locale.scriptCode == null &&
            locale.countryCode == null,
      ) ??
      _firstMatching(
        supported,
        (locale) => locale.languageCode == requestedLocale.languageCode,
      ) ??
      english;
}

String? _chineseScriptForRegion(String? countryCode) {
  final normalized = countryCode?.toUpperCase();
  if (_traditionalChineseRegions.contains(normalized)) {
    return 'Hant';
  }
  if (_simplifiedChineseRegions.contains(normalized)) {
    return 'Hans';
  }
  return null;
}

Locale? _firstMatching(
  Iterable<Locale> locales,
  bool Function(Locale locale) predicate,
) {
  for (final locale in locales) {
    if (predicate(locale)) {
      return locale;
    }
  }
  return null;
}

import 'package:flutter/widgets.dart';

import '../../l10n/generated/app_localizations.dart';

/// A locale that can be selected explicitly in BusyMax.
///
/// Language names are endonyms on purpose: users should be able to find their
/// language even when the rest of the application is currently unreadable.
class BusyMaxLocaleOption {
  const BusyMaxLocaleOption({required this.locale, required this.endonym});

  final Locale locale;
  final String endonym;

  String get tag => locale.toLanguageTag();
}

const busyMaxLocaleOptions = <BusyMaxLocaleOption>[
  BusyMaxLocaleOption(locale: Locale('ar'), endonym: 'العربية'),
  BusyMaxLocaleOption(locale: Locale('de'), endonym: 'Deutsch'),
  BusyMaxLocaleOption(locale: Locale('en'), endonym: 'English'),
  BusyMaxLocaleOption(locale: Locale('es'), endonym: 'Español'),
  BusyMaxLocaleOption(locale: Locale('et'), endonym: 'Eesti'),
  BusyMaxLocaleOption(locale: Locale('fa'), endonym: 'فارسی'),
  BusyMaxLocaleOption(locale: Locale('fi'), endonym: 'Suomi'),
  BusyMaxLocaleOption(locale: Locale('fr'), endonym: 'Français'),
  BusyMaxLocaleOption(locale: Locale('hi'), endonym: 'हिन्दी'),
  BusyMaxLocaleOption(locale: Locale('it'), endonym: 'Italiano'),
  BusyMaxLocaleOption(locale: Locale('ja'), endonym: '日本語'),
  BusyMaxLocaleOption(locale: Locale('ko'), endonym: '한국어'),
  BusyMaxLocaleOption(locale: Locale('pt', 'PT'), endonym: 'Português'),
  BusyMaxLocaleOption(locale: Locale('ru'), endonym: 'Русский'),
  BusyMaxLocaleOption(locale: Locale('vi'), endonym: 'Tiếng Việt'),
  BusyMaxLocaleOption(
    locale: Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans'),
    endonym: '简体中文',
  ),
  BusyMaxLocaleOption(
    locale: Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
    endonym: '繁體中文',
  ),
];

/// Locales exposed by BusyMax after removing generator-only fallbacks.
///
/// Flutter's localization generator requires a base `pt` catalog before it
/// will generate `pt_PT`. BusyMax deliberately exposes only European
/// Portuguese so generic Portuguese and Brazilian Portuguese are not silently
/// resolved to the pt-PT catalog.
final busyMaxSupportedLocales = AppLocalizations.supportedLocales
    .where(
      (locale) => locale.languageCode != 'pt' || locale.countryCode == 'PT',
    )
    .toList(growable: false);

const _traditionalChineseRegions = {'HK', 'MO', 'TW'};
const _simplifiedChineseRegions = {'CN', 'MY', 'SG'};

Locale? busyMaxLocaleFromTag(String? tag) {
  final normalized = normalizeBusyMaxLocaleTag(tag);
  if (normalized == null) {
    return null;
  }
  for (final option in busyMaxLocaleOptions) {
    if (option.tag == normalized) {
      return option.locale;
    }
  }
  return null;
}

String? normalizeBusyMaxLocaleTag(String? tag) {
  final trimmed = tag?.trim();
  if (trimmed == null || trimmed.isEmpty) {
    return null;
  }

  final parsed = _parseLocaleTag(trimmed);
  if (parsed == null) {
    return null;
  }
  final normalized = _normalizeChineseLocale(parsed);
  for (final option in busyMaxLocaleOptions) {
    if (option.locale == normalized) {
      return option.tag;
    }
  }

  // Stored regional variants such as en-CA use the app's base translation.
  for (final option in busyMaxLocaleOptions) {
    if (option.locale.languageCode == normalized.languageCode &&
        option.locale.scriptCode == null &&
        option.locale.countryCode == null) {
      return option.tag;
    }
  }
  return null;
}

String busyMaxLocaleEndonym(String tag) {
  final normalized = normalizeBusyMaxLocaleTag(tag);
  for (final option in busyMaxLocaleOptions) {
    if (option.tag == normalized) {
      return option.endonym;
    }
  }
  return tag;
}

/// Resolves the complete platform language preference list.
///
/// Flutter's generated locale list is alphabetical, which would otherwise
/// make Arabic the fallback for an unsupported system language. Reordering the
/// supported list keeps English as the deliberate fallback while retaining
/// Flutter's exact/script/region/language preference algorithm.
Locale resolveBusyMaxLocales(
  List<Locale>? requestedLocales,
  Iterable<Locale> supportedLocales,
) {
  final supported = supportedLocales.toList(growable: false);
  if (supported.isEmpty) {
    return const Locale('en');
  }

  final english = supported.cast<Locale?>().firstWhere(
    (locale) => locale?.languageCode == 'en',
    orElse: () => null,
  );
  final orderedSupported = <Locale>[
    if (english != null) english,
    for (final locale in supported)
      if (locale != english) locale,
  ];
  final normalizedRequested = requestedLocales
      ?.map(_normalizeChineseLocale)
      .where(
        (locale) => locale.languageCode != 'pt' || locale.countryCode == 'PT',
      )
      .toList(growable: false);
  return basicLocaleListResolution(normalizedRequested, orderedSupported);
}

Locale resolveBusyMaxLocale(
  Locale? requestedLocale,
  Iterable<Locale> supportedLocales,
) {
  return resolveBusyMaxLocales(
    requestedLocale == null ? null : [requestedLocale],
    supportedLocales,
  );
}

Locale _normalizeChineseLocale(Locale locale) {
  if (locale.languageCode.toLowerCase() != 'zh' || locale.scriptCode != null) {
    return locale;
  }
  final region = locale.countryCode?.toUpperCase();
  if (_traditionalChineseRegions.contains(region)) {
    return Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant');
  }
  if (_simplifiedChineseRegions.contains(region)) {
    return Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans');
  }
  return locale;
}

Locale? _parseLocaleTag(String tag) {
  final parts = tag.replaceAll('_', '-').split('-');
  if (parts.isEmpty || !RegExp(r'^[A-Za-z]{2,3}$').hasMatch(parts.first)) {
    return null;
  }

  final languageCode = parts.first.toLowerCase();
  String? scriptCode;
  String? countryCode;
  for (final part in parts.skip(1)) {
    if (scriptCode == null && RegExp(r'^[A-Za-z]{4}$').hasMatch(part)) {
      scriptCode =
          '${part.substring(0, 1).toUpperCase()}'
          '${part.substring(1).toLowerCase()}';
      continue;
    }
    if (countryCode == null &&
        RegExp(r'^(?:[A-Za-z]{2}|[0-9]{3})$').hasMatch(part)) {
      countryCode = part.toUpperCase();
      continue;
    }
    return null;
  }
  return Locale.fromSubtags(
    languageCode: languageCode,
    scriptCode: scriptCode,
    countryCode: countryCode,
  );
}
